#!/usr/bin/env python3
# app/servidor.py — o backend da página de configuração do MeowSystem.
#
# É UMA PONTE ENTRE UMA PÁGINA LOCAL E A CLI QUE JÁ EXISTE, e a diferença
# importa em cada decisão abaixo: ele não decide nada sobre o tema, não sabe o
# que é um flavor, não conhece uma única chave pelo nome.
#
# A tentação óbvia era escrever aqui uma lista das ~90 chaves com rótulo, tipo e
# ajuda bonitinhos.
#
# Python tem `re.sub` e seria uma linha.
#
# O plano inicial era confortável e ERRADO: "o backend não tem tty, então todo
# `sudo` falha sozinho e nada privilegiado roda daqui".
#
#     $ sudo -n -v ; echo $?
#     0
#     $ sudo -n -l | grep timestamp
#     ... timestamp_type=global, timestamp_timeout=60
#
# A superfície de rede é pequena de propósito: escuta só em 127.0.0.1, em porta
# efêmera; todo pedido traz o token da sessão (`hmac.compare_digest`); `Host` e
# `Origin` são conferidos (DNS rebinding e site de fora); e nenhum comando vem
# da página como texto, só `id` de um dicionário fechado.
#
# O cache global do sudo (acima) deixa um clique rodar o install.sh com root sem
# perguntar. Por isso a ação que atravessa sudo é marcada, avisada antes e
# pede confirmação; nenhuma senha é pedida, lida ou guardada aqui.
"""Backend local do painel de configuração visual do MeowSystem."""

import base64
import datetime
import functools
import hashlib
import hmac
import html
import json
import os
import queue
import re
import secrets
import select
import struct
import shlex
import signal
import shutil
import subprocess
import sys
import tempfile
import threading
import time
# A folha da oficina roda SEIS conversores de uma vez: em série eram 1,42 s
# medidos, e o servidor é `ThreadingHTTPServer`, então a rota ocupada não
# tranca as outras.
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs, quote

# --- 1. onde está o repositório ---------------------------------------------
# Mesma pergunta que o `bin/meow` responde em quatro passos, e aqui bastam dois:
# este arquivo mora DENTRO do clone (`app/servidor.py`), então o diretório acima
# é a raiz.
def _raiz_valida(caminho):
    return bool(caminho) and os.path.isfile(os.path.join(caminho, "lib", "comum.sh")) \
        and os.path.isfile(os.path.join(caminho, "install.sh"))


def _resolver_raiz():
    candidato = os.environ.get("MEOW_RAIZ", "")
    if _raiz_valida(candidato):
        return os.path.realpath(candidato)
    aqui = os.path.dirname(os.path.realpath(__file__))
    acima = os.path.dirname(aqui)
    if _raiz_valida(acima):
        return acima
    return None


RAIZ = _resolver_raiz()
if RAIZ is None:
    sys.stderr.write("servidor.py: não achei o repositório do MeowSystem.\n")
    sys.stderr.write("             aponte com: MEOW_RAIZ=/caminho/do/clone\n")
    sys.exit(3)

PAGINA = os.path.join(RAIZ, "app", "pagina")
# O mapa dos jogos que ficam fora do lançador.
MAPA_JOGOS = os.path.join(RAIZ, "assets", "apps", "jogos-fora.map")
ICONES_DO_MOTOR = os.path.join(RAIZ, "packs", "meowsystem", "icones")


def _glifo_do_motor(nome):
    """O glifo de traço do pack-base: `apps/` ou `biblioteca/` (as três pastas são planas desde a P96)."""
    for pasta in ("apps", "biblioteca", "sistema"):
        cand = os.path.join(ICONES_DO_MOTOR, pasta, nome + ".svg")
        if os.path.isfile(cand):
            return cand
    return os.path.join(ICONES_DO_MOTOR, "apps", nome + ".svg")
CONF_PADRAO = os.environ.get("MEOW_CONF_PADRAO") or os.path.join(RAIZ, "meow.conf.exemplo")
CONF = os.environ.get("MEOW_CONF") or os.path.expanduser("~/.config/meow/meow.conf")
_PALETA = None


def paleta_canonica():
    """O arquivo de paleta que vale agora, ou '' quando não dá para saber.

    VAZIO É RESPOSTA, E ELA JÁ TEM TRATAMENTO
        Sem `scripts/pack.py` o painel não sabe qual é o pack padrão — e
        inventar `packs/catppuccin/` aqui seria a segunda verdade sobre o nome
        do pack padrão, que é exatamente o que a P13 veio acabar. O `''` cai no
        `except OSError` do `_paleta_dados`, que já devolve `flavors: {}`, e a
        página sai com "paleta ilegível — a página cai no tema do navegador".
        É a mesma degradação que ela já tinha quando o arquivo não existia.
    """
    global _PALETA
    _ponte_em_dia()
    if _PALETA is None:
        mod = modulo_pack()
        _PALETA = (mod.paleta_do_pack_ativo() if mod
                   else os.environ.get("MEOW_PALETA") or "")
    return _PALETA


# A PONTE DO PAINEL ACOMPANHA O meow.conf
#
# Um `stat` por consulta é o preço; o `conf_exportada` (a ponte em bash, a mesma
# do `run.sh`) só roda quando o meow.conf mudou desde a última vez.
_PONTE_TRAVA = threading.Lock()
_PONTE_VISTA = {"iniciada": False, "relogio": None}


def _ponte_em_dia():
    # A TRAVA FICA FECHADA DURANTE A RELEITURA, e não só na conta do relógio: a
    # página pede `/api/packs` e `/api/esquema` juntas logo depois de um
    # trabalho, e a segunda, achando o relógio já anotado pela primeira, leria a
    # ponte VELHA enquanto a nova ainda estava a caminho — o cartão diria um
    # pack no ar e a aba Ícones outro.
    global _PALETA
    try:
        relogio = os.stat(CONF).st_mtime_ns
    except OSError:
        relogio = None
    with _PONTE_TRAVA:
        if _PONTE_VISTA["iniciada"] and relogio == _PONTE_VISTA["relogio"]:
            return
        primeira = not _PONTE_VISTA["iniciada"]
        _PONTE_VISTA.update(iniciada=True, relogio=relogio)
        if primeira:
            return
        conf = conf_exportada()
        if conf is None:
            return
        for nome in ("MEOW_PALETA", "MEOW_PACK_DIR", "MEOW_PALETA_DA_PONTE"):
            if conf.get(nome):
                os.environ[nome] = conf[nome]
            else:
                os.environ.pop(nome, None)
        _PALETA = None
        _PALETA_CACHE.clear()


FOLHAS = os.path.join(RAIZ, "docs", "folhas")
# O mesmo diretório que `MEOW_ESTADO` do `lib/comum.sh` — e ele vem por ambiente
# quando o `run.sh` é quem chama, para as duas metades nunca discordarem sobre
# onde mora o `app.pid`.
ESTADO = os.environ.get("MEOW_ESTADO") or os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "meowsystem",
)

TOKEN = secrets.token_urlsafe(32)

# A CSP de toda resposta `image/*` — ver "TODA IMAGEM SAI COMO DOCUMENTO QUE NÃO
# RODA NADA", no `_responder`.
CSP_DE_IMAGEM = "default-src 'none'; style-src 'unsafe-inline'; sandbox"


# Numa leitura só: 233 bashes e 149 adoções, com a mesma resposta — e o
# comentário do `_vestigio_de_pack` já dizia que a leitura "é cacheada pelo
# próprio `valores_brutos`", que não cacheava nada.
#
# Fora de uma leitura (`_numa_leitura`) as funções marcadas perguntam como
# sempre; dentro dela, a primeira resposta vale até a leitura acabar.
_LEITURA = threading.local()


def _uma_vez_por_leitura(funcao):
    """Marca uma pergunta à máquina cuja resposta não muda dentro de uma leitura.

    A lista, o dicionário ou o conjunto que volta é uma CÓPIA da guardada: a
    lista de temas vira as `opcoes` de mais de uma chave, e quem acrescentasse
    uma opção a uma delas a acrescentaria em todas."""
    @functools.wraps(funcao)
    def embrulho(*args):
        memoria = getattr(_LEITURA, "memoria", None)
        if memoria is None:
            return funcao(*args)
        chave = (funcao.__name__,) + tuple(tuple(a) if isinstance(a, list) else a
                                           for a in args)
        if chave not in memoria:
            memoria[chave] = funcao(*args)
        resposta = memoria[chave]
        return type(resposta)(resposta) if isinstance(resposta, (list, dict, set)) else resposta
    return embrulho


def _numa_leitura(funcao):
    """Liga a memória do `_uma_vez_por_leitura` enquanto `funcao` roda; uma
    leitura de dentro de outra (o `ler_esquema` do `_dados_esquema`) usa a da
    de fora."""
    @functools.wraps(funcao)
    def embrulho(*args, **kwargs):
        if getattr(_LEITURA, "memoria", None) is not None:
            return funcao(*args, **kwargs)
        _LEITURA.memoria = {}
        try:
            return funcao(*args, **kwargs)
        finally:
            _LEITURA.memoria = None
    return embrulho


# --- 2. o esquema, lido do meow.conf.exemplo --------------------------------
# As quatro regras abaixo são a tradução literal do `wiz_ler_esquema`,
# `wiz_valor_da_linha`, `wiz_comentario_da_linha` e `wiz_opcoes` do `bin/meow`.

RE_CHAVE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=")
# O token de uma lista de opções: exatamente o `[!A-Za-z0-9_.:+-]` do bash, ao
# contrário. Uma frase em prosa com uma barra no meio não é uma lista de opções,
# e é por isso que UM token inválido descarta a LINHA inteira.
RE_TOKEN_OPCAO = re.compile(r"^[A-Za-z0-9_.:+-]+$")
# Uma faixa numérica declarada no comentário: `1000–6500 K`, `80..900`, `0.0 a 1.0`.
# É REGRA, não lista de chaves: qualquer chave nova cujo comentário declare uma
# faixa ganha o controle deslizante sozinha, sem ninguém vir aqui acrescentá-la.
RE_FAIXA = re.compile(
    r"(?<![\w.])(\d+(?:[.,]\d+)?)\s*(?:\.\.|–|—|-|\ba\b|\bà\b)\s*(\d+(?:[.,]\d+)?)(?![\w.])"
)


def _valor_da_linha(linha):
    """O valor CRU, como está escrito no arquivo — sem expandir `$HOME`."""
    resto = linha.split("=", 1)[1] if "=" in linha else ""
    if resto.startswith('"'):
        return resto[1:].split('"', 1)[0]
    if resto.startswith("'"):
        return resto[1:].split("'", 1)[0]
    # Sem aspas: o valor vai até o primeiro branco ou `#`.
    return re.split(r"[\s#]", resto, 1)[0]


def _comentario_da_linha(linha):
    """O comentário que mora na MESMA linha da chave (`RAIO="8"  # corner_radii`)."""
    resto = linha.split("=", 1)[1] if "=" in linha else ""
    if resto.startswith('"'):
        cauda = resto[1:].split('"', 1)
        cauda = cauda[1] if len(cauda) > 1 else ""
    elif resto.startswith("'"):
        cauda = resto[1:].split("'", 1)
        cauda = cauda[1] if len(cauda) > 1 else ""
    else:
        cauda = linha
    if "#" in cauda:
        return cauda.split("#", 1)[1].strip()
    return ""


def _e_linha_de_opcoes(linha):
    """A linha é só uma lista `a | b | c`, e nada mais?

    Serve para TIRAR essa linha da frase curta. Sem isto, o cartão do `FLAVOR`
    mostrava, embaixo dos quatro botões `mocha` `macchiato` `frappe` `latte`, a
    frase "...se a combinação não existir. mocha | macchiato | frappe | latte" —
    repetindo em texto o que o controle logo acima já é. Visto na tela em
    01/09/2026, junto com o `ACCENT`, que repetia as doze cores.
    """
    texto = linha.lstrip("#").strip()
    if "|" not in texto:
        return False
    # O corte no `(` é o MESMO que o `_opcoes` faz, e ter os dois discordando era
    # um defeito: o `MODO` era reconhecido como lista lá (porque o `_opcoes` corta)
    # e como prosa aqui (porque este não cortava), então a linha virava opções NO
    # CONTROLE e continuava aparecendo como frase EMBAIXO dele.
    texto = texto.split("(", 1)[0]
    return all(RE_TOKEN_OPCAO.match(t.strip()) for t in texto.split("|") if t.strip())


_PADROES_EXEMPLO = {}


def _padrao_do_exemplo(chave):
    """O valor de fábrica da chave, lido do `meow.conf.exemplo`. Com cache: esta
    função é chamada uma vez por chave em cada leitura do esquema."""
    if not _PADROES_EXEMPLO:
        try:
            with open(os.path.join(RAIZ, "meow.conf.exemplo"), encoding="utf-8") as fh:
                for linha in fh:
                    if RE_CHAVE.match(linha):
                        nome = linha.split("=", 1)[0].strip()
                        _PADROES_EXEMPLO[nome] = _valor_da_linha(linha)
        except OSError:
            _PADROES_EXEMPLO["__vazio__"] = ""
    return _PADROES_EXEMPLO.get(chave, "")


def _opcoes(chave, ajuda, inline):
    """A primeira linha, da ajuda ou do comentário de linha, que seja `a | b | c`.

    ESTA FUNÇÃO LÊ SÓ O TEXTO, E É POR ISSO QUE ELA EXISTE SEPARADA
        Ela é a metade que o `wiz_opcoes` do `bin/meow` também implementa, e o
        `tests/app.sh` compara as duas chave a chave. Tudo que sai do DISCO —
        os gatos do acervo, os temas de ícone instalados, os ponteiros que o
        `cursor.sh` resolve — mora em `_opcoes_do_disco`, uma camada acima, que
        é da página e o bash não precisa conhecer.

        Até 01/09/2026 havia aqui um `if chave in ("LOGO", "LOGO_DIA", ...)`: a
        ÚNICA lista fixa de chaves do arquivo, e o `tests/app.sh` carregava a
        exceção correspondente para as mesmas quatro. Ela saiu porque a regra
        que a substituiu é derivada do CONTEÚDO (o comentário cita
        `packs/meowsystem/mascote/`) e por isso pega sozinha a quinta chave que nascer assim
        — que é a armadilha nº 3 deste projeto, e ela já cobrou duas vezes.
    """
    for linha in (ajuda.splitlines() + [inline]):
        if "|" not in linha:
            continue
        texto = linha.lstrip("#")
        texto = texto.split("(", 1)[0]
        tokens = [t.strip() for t in texto.split("|")]
        if not tokens or any(not RE_TOKEN_OPCAO.match(t) for t in tokens):
            continue
        return tokens
    tabela = _opcoes_da_lista_indentada(ajuda)
    #   `FASTFETCH_LOGO_MODO` traz `espelho | hora | fixo` e nasce `espelho` — é
    #   dele. As duas chaves logo abaixo (`_DIA`, `_NOITE`) herdam o mesmo
    #   comentário porque não têm um próprio, e nascem VAZIAS: ganhariam três
    #   botões de modo para escolher um NOME DE GATO.
    #   O padrão é lido aqui dentro, e não recebido de quem chama, porque o
    #   `tests/app.sh` compara ESTA função com o `wiz_opcoes` do bash — as duas
    #   precisam decidir sozinhas, com a mesma informação.
    if tabela and _padrao_do_exemplo(chave) not in tabela:
        return []
    return tabela


# A SEGUNDA FORMA DE LISTAR OPÇÕES NESTE ARQUIVO — e ela era invisível para a
# página, quando ela apontou:
#
# "Como o gato do dock e do terminal são escolhidos e tá escrito horas.
#
# O `LOGO_MODO` TEM três opções, e o `meow.conf.exemplo` as lista — mas numa
# tabela indentada, não em `a | b | c`:
#
#   #   hora     (padrão) LOGO_NOITE de noite, LOGO_DIA de dia...
#   #   rotacao  gira pelo acervo ao encerrar a sessão...
#   #   fixo     LOGO= vence sempre; nada gira, nada segue relógio.
RE_OPCAO_TABELA = re.compile(r"^#(\s{2,})([a-z][a-z0-9_-]{1,14})\s{2,}\S")


def _opcoes_da_lista_indentada(ajuda):
    melhor = []
    atual = []
    recuo = None
    for linha in ajuda.splitlines():
        m = RE_OPCAO_TABELA.match(linha.rstrip())
        if m and (recuo is None or len(m.group(1)) == recuo):
            recuo = len(m.group(1))
            atual.append(m.group(2))
            continue
        # Uma linha de continuação (mais indentada) não quebra a tabela: as
        # explicações deste arquivo costumam ocupar duas linhas.
        if atual and linha.startswith("#") and recuo and \
                len(linha) > 1 and len(linha[1:]) - len(linha[1:].lstrip()) > recuo:
            continue
        if len(atual) > len(melhor):
            melhor = atual
        atual = []
        recuo = None
    if len(atual) > len(melhor):
        melhor = atual
    return melhor if len(melhor) >= 3 else []


def _e_tabela(chave, ajuda, inline):
    """As opções vieram da tabela indentada (e não de uma linha `a | b | c`)?"""
    for linha in (ajuda.splitlines() + [inline]):
        if "|" in linha:
            texto = linha.lstrip("#").split("(", 1)[0]
            tokens = [x.strip() for x in texto.split("|")]
            if tokens and all(RE_TOKEN_OPCAO.match(x) for x in tokens if x):
                return False
    return bool(_opcoes_da_lista_indentada(ajuda))


# Havia aqui, uma lista de quatro nomes de chave — as do gato — e ela era a
# única lista fixa do arquivo.
#
# A regra passa a ser a mesma do resto do arquivo: perguntar ao CONTEÚDO.
#
# A GUARDA É O VALOR DE FÁBRICA, e é ela que faz uma regra de texto largo não
# atropelar as vizinhas.
FONTES_DO_DISCO = (
    (re.compile(r"packs/\w+/mascote/"), "gatos", False),
    (re.compile(r"[íi]cones?\b", re.I), "temas_icones", True),
    (re.compile(r"ponteiro|cursor", re.I), "cursores", True),
)

# "Vazio = herda LOGO_DIA": uma chave que declara herdar outra oferece as MESMAS
# opções que a outra oferece.
RE_HERDA = re.compile(r"herda\s+([A-Z][A-Z0-9_]{2,})")


def _disco_detalhe(ajuda, inline, padrao):
    """(lista, é_cerca) — as opções que saem de uma pasta, e se elas proíbem."""
    texto = ajuda + "\n" + inline
    for gatilho, provedor, cerca in FONTES_DO_DISCO:
        if not gatilho.search(texto):
            continue
        lista = PROVEDORES[provedor]()
        if padrao and padrao in lista:
            return (lista, cerca)
    # A herança declarada só vale para chave que NASCE VAZIA: é a forma que o
    # arquivo usa para dizer "sem valor, quem manda é a outra". Quem tem valor
    # próprio já foi decidido no laço acima.
    alvo = RE_HERDA.search(texto)
    if not padrao and alvo:
        padrao_alvo = _padrao_do_exemplo(alvo.group(1))
        if padrao_alvo:
            for _gatilho, provedor, cerca in FONTES_DO_DISCO:
                lista = PROVEDORES[provedor]()
                if padrao_alvo in lista:
                    return (lista, cerca)
    return ([], False)


def _opcoes_do_disco(ajuda, inline, padrao):
    """As opções que saem de uma pasta, quando o comentário aponta para uma."""
    return _disco_detalhe(ajuda, inline, padrao)[0]


def _opcoes_finais(chave, ajuda, inline, padrao, herdada=False):
    """As opções que a página oferece, com dois ajustes sobre o que o texto diz.

    1. `vazio` NÃO É UM VALOR, É A AUSÊNCIA DELE
       Três chaves documentam `nao | sim | vazio (= não toca)`. Lido ao pé da
       letra, o `vazio` vira mais um token, e um clique nele gravaria
       `RELOGIO_SEGUNDOS="vazio"` — que não é `sim`, não é `nao`, e cairia no
       `*)` de qualquer `case` do projeto sem nada avisar. Ele sai da lista e
       vira o terceiro estado do controle, que é o que a prosa quer dizer.

    2. UM VALOR `sim`/`nao` JÁ DECLARA O TIPO DELE
       Visto na tela em 01/09/2026: o `LOGO_ROTACAO` nasceu como CAMPO DE TEXTO
       LIVRE com a palavra `nao` dentro, ao lado de vizinhos com dois botões. O
       comentário dele explica a chave em prosa e nunca escreve `sim | nao` —
       então não havia lista para achar. Digitar a resposta de uma pergunta de
       sim ou não é a pior forma possível de respondê-la, e ainda deixa passar
       `não` com til, que o `case` do shell não casa.

       A regra olha o VALOR DE FÁBRICA: se ele é exatamente `sim` ou `nao`, a
       chave é binária — o arquivo está dizendo isso, mesmo sem listar. Vale para
       nove chaves hoje, e vale sozinha para a próxima que nascer assim.

    3. E O DISCO VENCE O TEXTO, quando o comentário aponta para uma pasta
       Ver `_opcoes_do_disco`. Vem primeiro porque é mais específico: o texto do
       `LOGO_MODO` descreve TRÊS MODOS e as duas chaves coladas nele querem um
       NOME DE GATO — quem sabe a diferença é a pasta, não a frase.
    """
    do_disco = _opcoes_do_disco(ajuda, inline, padrao)
    if do_disco:
        return do_disco
    opcoes = [o for o in _opcoes(chave, ajuda, inline) if o != "vazio"]
    # `FASTFETCH_LOGO_MODO` traz a tabela `espelho / hora / fixo` e nasce
    # `espelho` — a tabela é dele.
    if opcoes and (padrao or "") not in opcoes and _e_tabela(chave, ajuda, inline):
        return []
    if not opcoes and padrao in ("sim", "nao"):
        return ["sim", "nao"]
    return opcoes


RE_DURACAO = re.compile(r"^\d+(?:[.,]\d+)?[smhd]$")


# Isto é uma lista, e listas envelhecem — mas esta descreve uma RELAÇÃO entre
# chaves que só existe dentro dos scripts (`logo.sh:113-119` e `:432-449`), e
# não há como derivá-la do texto do `meow.conf.exemplo` sem inventar.
DOMINIOS = {
    "LOGO_ROTACAO": {
        "chave": "LOGO_MODO",
        "quando": lambda v: bool(v) and v != "rotacao",
        "porque": "Ela só liga a rotação quando o mascote é escolhido girando — "
                  "hoje não tem efeito nenhum.",
    },
    "LOGO": {
        "chave": "LOGO_MODO",
        "quando": lambda v: v == "hora",
        "porque": "Por horário quem escolhe são os mascotes de dia e de noite; "
                  "esta só entra quando um daqueles dois não está na lista.",
    },
    # A MARGEM QUE O COMPOSITOR JOGA FORA.
    "FORMA_MARGEM_PAINEL": {
        "chave": "FORMA_PAINEL_SOLTO",
        "quando": lambda v: v == "nao",
        "porque": "A margem só é desenhada quando o painel está solto da "
                  "borda: assim, o compositor descarta este número calado.",
    },
    "FORMA_MARGEM_DOCK": {
        "chave": "FORMA_DOCK_SOLTO",
        "quando": lambda v: v == "nao",
        "porque": "A margem só é desenhada quando a dock está solta da "
                  "borda: assim, o compositor descarta este número calado.",
    },
    "FASTFETCH_LOGO_GATO": {
        "chave": "FASTFETCH_LOGO_MODO",
        "quando": lambda v: bool(v) and v != "fixo",
        # A ajuda afirmava o contrário do comportamento de fábrica.
        "porque": "Ela só vale com a escolha em \u201cfixo\u201d. Em "
                  "\u201chora\u201d o terminal segue o mascote do dock; em "
                  "\u201cespelho\u201d ele mostra o OUTRO.",
    },
    # O `CURSOR_VERSAO` é o release que o `cursor.sh` pede no ÚLTIMO degrau
    # dele, quando baixa o tema pelo nome (`_cursor_url`).
    "CURSOR_VERSAO": {
        "chave": "CURSOR",
        "quando": lambda v: _ponteiro_vem_do_pack(v),
        "porque": "O ponteiro escolhido vem do pack no ar, que fixa a origem "
                  "dele: esta versão só vale para o ponteiro que o MeowSystem "
                  "baixa pelo nome.",
    },
}


def _valor_vivo(chave):
    """O valor que a chave tem NA MÁQUINA agora (o conf dela, ou o exemplo)."""
    return (valores_brutos() or {}).get(chave, "")


# O estado que o applet do modo de leitura guarda, chave a chave. A ligação é
# derivada do NOME (`LEITURA_TEMPERATURA` -> `leitura_temperatura`), e não uma
# lista: a próxima chave dessa família nasce coberta.
COSMIC_DIR = os.environ.get("MEOW_COSMIC_DIR") or os.path.expanduser("~/.config/cosmic")
CONF_COMP = os.path.join(COSMIC_DIR, "com.system76.CosmicComp", "v1")

# Os números eram constantes do `app.js`, porque as chaves de forma nascem
# VAZIAS — e vazio, nelas, é "não toca": o que vale é o que o COSMIC já tem no
# disco.
#
# A TABELA É A LEITURA INVERSA DO QUE OS SCRIPTS ESCREVEM, e cada grupo diz de
# qual: `forma.sh` (aplicar_barra, aplicar_tamanhos), `vidro.sh`, `relogio.sh` e
# `janelas.sh`.
_BARRAS = (("PAINEL", "com.system76.CosmicPanel.Panel/v1/"),
           ("DOCK", "com.system76.CosmicPanel.Dock/v1/"))
_DEGRAU = r"(XS|S|M|L|XL)"


def _cosmic_ler(relativo):
    try:
        with open(os.path.join(COSMIC_DIR, relativo), encoding="utf-8") as fh:
            return fh.read().strip()
    except OSError:
        return None


def _sim_nao(bruto, invertido=False):
    if bruto not in ("true", "false"):
        return None
    return "sim" if (bruto == "true") != invertido else "nao"


def _numero_cru(bruto):
    return bruto if re.match(r"^-?\d+(\.\d+)?$", bruto) else None


def _degrau_proprio(bruto):
    """`Some(L)` -> "L". `None` é "herda o tamanho geral": não há valor próprio
    a mostrar, e o desenho já sabe herdar."""
    m = re.match(r"^Some\(%s\)$" % _DEGRAU, bruto)
    return m.group(1) if m else None


def _ala(qual):
    """`size_wings` é a tupla `Some((inicial, final))` — ver `meow_painel_wings`."""
    forma = r"^Some\(\((None|Some\(%s\)),\s*(None|Some\(%s\))\)\)$" % (_DEGRAU, _DEGRAU)

    def ler(bruto):
        m = re.match(forma, bruto)
        return (m.group(2) if qual == 0 else m.group(4)) if m else None
    return ler


NA_MAQUINA = {
    # relogio.sh
    "RELOGIO_SEGUNDOS": ("com.system76.CosmicAppletTime/v1/show_seconds", _sim_nao),
    # janelas.sh
    "JANELAS_TILING": ("com.system76.CosmicComp/v1/autotile", _sim_nao),
    "JANELAS_TILING_ESCOPO": ("com.system76.CosmicComp/v1/autotile_behavior",
                              {"Global": "global", "PerWorkspace": "workspace"}.get),
}
for _suf, _pasta in _BARRAS:
    NA_MAQUINA.update({
        # forma.sh, aplicar_barra — ilha e expand_to_edges têm o sinal trocado
        "FORMA_%s_SOLTO" % _suf: (_pasta + "anchor_gap", _sim_nao),
        "FORMA_%s_ILHA" % _suf: (_pasta + "expand_to_edges",
                                 lambda bruto: _sim_nao(bruto, invertido=True)),
        "FORMA_MARGEM_" + _suf: (_pasta + "margin", _numero_cru),
        "FORMA_RAIO_" + _suf: (_pasta + "border_radius", _numero_cru),
        "FORMA_ESPACO_" + _suf: (_pasta + "spacing", _numero_cru),
        "FORMA_RECHEIO_" + _suf: (_pasta + "padding", _numero_cru),
        # forma.sh, aplicar_tamanhos
        "FORMA_CENTRO_" + _suf: (_pasta + "size_center", _degrau_proprio),
        "FORMA_ALA_INICIAL_" + _suf: (_pasta + "size_wings", _ala(0)),
        "FORMA_ALA_FINAL_" + _suf: (_pasta + "size_wings", _ala(1)),
        # vidro.sh
        "VIDRO_OPACIDADE_" + _suf: (_pasta + "opacity", _numero_cru),
    })


# O `leitura.sh` escreve `leitura_temperatura = 0` quando o modo de leitura não
# está esquentando a tela — fora do horário, ou com o deslizante no neutro —, e
# nunca o 6500, porque o `is_noop()` do compositor só pula o passe do shader com
# o zero (o bloco da conta, no `leitura.sh`).
_LEITURA_ZERO_DESLIGA = ("LEITURA_TEMPERATURA", "LEITURA_TEXTURA")


def _leitura_desligada(chave, valor):
    if chave not in _LEITURA_ZERO_DESLIGA:
        return False
    try:
        return float(valor.strip()) == 0
    except ValueError:
        return False


# O lugar de cada uma é o que o `scripts/leitura.sh` lê (`LEITURA_K_*`): o ponto
# dos sliders no ESTADO do applet, a agenda e o horário no CosmicComp.
_LEITURA_NO_APPLET = {
    "LEITURA_TEMPERATURA": ("estado", "ultima_temperatura"),
    "LEITURA_TEXTURA": ("estado", "ultima_textura"),
    "LEITURA_AGENDA": ("cosmic", "com.system76.CosmicComp/v1/leitura_agenda"),
    "LEITURA_HORARIO_INICIO": ("cosmic", "com.system76.CosmicComp/v1/leitura_hora_inicio"),
    "LEITURA_HORARIO_FIM": ("cosmic", "com.system76.CosmicComp/v1/leitura_hora_fim"),
}


def _leitura_no_applet(chave):
    """O valor que o applet guarda para a chave, já no vocabulário do meow.conf,
    ou None quando ele não guarda (ou guarda o que o `leitura.sh` recusaria)."""
    onde = _LEITURA_NO_APPLET.get(chave)
    if not onde:
        return None
    tipo, nome = onde
    if tipo == "estado":
        base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
        try:
            with open(os.path.join(base, "cosmic", "com.meowsystem.AppletLeitura", "v1", nome),
                      encoding="utf-8") as fh:
                bruto = fh.read().strip()
        except OSError:
            return None
    else:
        bruto = (_cosmic_ler(nome) or "").strip().strip('"')
    # Os mesmos portões do `_leitura_resolver_alvo` e do `_leitura_uma_ponta`:
    # o que o relógio ignora, a página também ignora.
    if chave == "LEITURA_TEMPERATURA":
        return bruto if bruto.isdigit() and 1000 <= int(bruto) <= 6500 else None
    if chave == "LEITURA_TEXTURA":
        try:
            return bruto if 0 <= float(bruto) <= 1 and re.fullmatch(r"[\d.]+", bruto) else None
        except ValueError:
            return None
    if chave == "LEITURA_AGENDA":
        return {"true": "sim", "false": "nao", "Some(true)": "sim", "Some(false)": "nao"}.get(bruto)
    m = re.fullmatch(r"([01]?\d|2[0-3]):([0-5]\d)", bruto)
    return "%02d:%s" % (int(m.group(1)), m.group(2)) if m else None


def _valendo_agora(chave):
    if chave == "LOGO_MODO":
        # Com `LOGO_MODO=""` o `logo.sh` lê `rotacao` (com `LOGO_ROTACAO="sim"`)
        # ou `hora`, e a moldura «Gato do dock» procurava o modo vazio e não
        # mostrava gato nenhum.
        return _modo_do_gato() or None
    if chave.startswith("LEITURA_"):
        return _leitura_no_applet(chave)
    if chave == "AREAS_NOMES":
        # Vazio é «as áreas são suas», e mesmo assim elas existem e têm nome e
        # ordem: a página as desenha como estão, a traço, e o primeiro gesto
        # de arrastar ou renomear parte delas.
        return ", ".join(_areas_alfinetadas()) or None
    if chave == "VIDRO_AO_MAXIMIZAR":
        # Uma chave para as duas barras (o `vidro.sh` grava as duas): só há
        # resposta quando elas concordam.
        lidos = {_sim_nao(_cosmic_ler(pasta + "keep_style_on_maximize") or "")
                 for _suf, pasta in _BARRAS}
        return lidos.pop() if len(lidos) == 1 else None
    regra = NA_MAQUINA.get(chave)
    if not regra:
        return None
    arquivo, traduzir = regra
    bruto = _cosmic_ler(arquivo)
    return traduzir(bruto) if bruto else None


def _noite_do_applet():
    """{"ini": "HH:MM", "fim": "HH:MM"} quando o applet do modo de leitura
    guarda as DUAS pontas da janela no CosmicComp; senão None.

    O SEGUNDO DEGRAU DA NOITE DO GATO — 10/10/2026, P77 (achado 25). O
    `meow_noite_janela` (lib/noite.sh) responde, nesta ordem: `NOITE_*`, a
    janela do applet, `WALLPAPER_NOITE_*`, 18:00–07:00. A página sabe ler três
    dos quatro degraus no meow.conf, e o do applet mora fora dele: é este campo.
    As duas pontas, e não uma, porque é assim que o `meow_noite_janela` as
    aceita — uma ponta só cai no degrau seguinte inteiro."""
    pontas = []
    for chave in ("leitura_hora_inicio", "leitura_hora_fim"):
        bruto = (_cosmic_ler("com.system76.CosmicComp/v1/" + chave) or "").strip().strip('"')
        if not re.fullmatch(r"([01]?\d|2[0-3]):[0-5]\d", bruto):
            return None
        h, m = bruto.split(":")
        pontas.append("%02d:%s" % (int(h), m))
    return {"ini": pontas[0], "fim": pontas[1]}


def _titulo_de(chave):
    """O título escrito da chave, ou o nome dela quando não houver.

    Lê o `# @ ` do bloco sem montar o esquema inteiro: `_dominada_por` roda
    DENTRO do `ler_esquema`, e chamá-lo de volta seria recursão."""
    try:
        with open(CONF_PADRAO, encoding="utf-8") as fh:
            titulo = ""
            for linha in fh:
                if linha.startswith("# @ "):
                    titulo = linha[4:].strip()
                elif linha.startswith(chave + "="):
                    return titulo or chave
                elif not linha.strip():
                    titulo = titulo
    except OSError:
        pass
    return chave


# --- o scripts/pack.py, carregado por caminho --------------------------------
#
# A lista das raízes de busca de pack estava digitada em QUATRO lugares —
# `scripts/pack.py:raizes()`, duas vezes no `lib/comum.sh` e uma aqui.
#
# Quem manda é o `scripts/pack.py`, porque é ele quem abre o `pack.json`.
#
# POR QUE POR CAMINHO, E NÃO COM `sys.path.insert` Pôr `scripts/` no `sys.path`
# deste processo colocaria os outros 40 módulos de lá na frente da biblioteca
# padrão para sempre, por causa de um.
_PACK_MOD = None


def modulo_pack():
    """O `scripts/pack.py` como módulo, ou None se ele não puder ser carregado.

    None é resposta, não exceção: o painel tem de subir numa árvore onde alguém
    apagou o `scripts/`, e cada chamador decide o que fazer sem o pack.
    """
    global _PACK_MOD
    if _PACK_MOD is None:
        import importlib.util
        alvo = os.path.join(RAIZ, "scripts", "pack.py")
        try:
            spec = importlib.util.spec_from_file_location("meow_pack", alvo)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            _PACK_MOD = mod
        except Exception:
            _PACK_MOD = False
    return _PACK_MOD or None


def _packs_no_disco():
    """Os ids de theme pack que existem, lidos do disco. [2026-09-18]

    Do DISCO e não de uma lista escrita aqui: uma lista de nomes envelhece no dia
    em que alguém publicar o terceiro pack, e é exatamente o defeito que o
    formato de pack existe para não ter (ver docs/PACKS.md).

    AS RAÍZES SAEM DO `pack.py` DESDE 21/09/2026 — ver `modulo_pack`, acima. A
    lista de três diretórios estava digitada aqui também, e uma cópia que
    discorda some um pack da tela sem dizer nada.
    """
    achados = set()
    mod = modulo_pack()
    if not mod:
        return achados
    for base in mod.raizes():
        if not base or not os.path.isdir(base):
            continue
        for nome in os.listdir(base):
            # O pack-base é acervo e não se veste: não tem cartão.
            if os.path.isfile(os.path.join(base, nome, "pack.json")) \
                    and not (hasattr(mod, "eh_base") and mod.eh_base(os.path.join(base, nome))):
                achados.add(nome)
    return achados


# A VITRINE DOS PACKS
#
# O cartão de pack da Home: capa, nome, autor, a frase curta, as etiquetas, a
# linha "próprio / herdado" e, para quem abrir, a história inteira.
#
# Um `pack.json` de terceiro pode estar malformado de jeitos que o `validar` não
# previu (um `"paleta": "x"` estoura AttributeError antes de virar Recusa).
#
# A história (`vitrine.descricao`) é Markdown de terceiro e viaja crua no JSON: a
# página só a monta por `textContent`, porque carrega o token de sessão.
def _pack_no_ar():
    """O id do pack que veste a máquina agora, ou '' sem `scripts/pack.py`."""
    _ponte_em_dia()
    dir_pack = os.environ.get("MEOW_PACK_DIR") or ""
    if dir_pack:
        return os.path.basename(dir_pack.rstrip("/"))
    mod = modulo_pack()
    return mod.PACK_PADRAO if mod else ""


def _flavor_do_conf(valores):
    """O FLAVOR do conf, e vazio vale o `flavor_padrao` do pack no ar.

    O FLAVOR VAZIO NÃO É O MOCHA — 09/10/2026, P74 item 7 (T1). Quatro rotas da
    página (a marca, o `/paleta.css`, a página exportada e o acento) caíam em
    `or "mocha"`: com o Dracula no ar e `FLAVOR=""` (vazio vale o padrão do pack,
    a regra do `meow_flavor` do lib/comum.sh), a página se vestia de Catppuccin.
    O `mocha` fica só como a última reserva, sem `scripts/pack.py` nenhum."""
    flavor = valores.get("FLAVOR") or ""
    if flavor:
        return flavor
    mod = modulo_pack()
    no_ar = _pack_no_ar()
    return str((mod.campo(no_ar, "paleta.flavor_padrao") if mod and no_ar else "") or "mocha")


def vocabulario_do_pack():
    """O `vocabulario` do pack no ar (scripts/pack.py), ou None. [P10]

    None é resposta: sem ele a aba Ícones volta a desenhar os controles como o
    `meow.conf.exemplo` os descreve, e um pack que não valida não derruba a
    página que existe justamente para consertá-lo."""
    mod = modulo_pack()
    ident = _pack_no_ar()
    if not mod or not ident:
        return None
    try:
        return mod.vocabulario(ident)
    except Exception:
        return None


# None é "este pack não mora na casa dela" — o que vem com o MeowSystem —, e o
# cartão não ganha botão nenhum.
def _remocao_do_cartao(mod, ident, conf):
    try:
        casa, motivo = mod.remocao(ident, conf.get("PACK") or "", conf.get("FLAVOR") or "")
    except Exception:
        return None
    if not casa:
        return None
    return {"pode": not motivo, "motivo": motivo or ""}


def _packs_removiveis():
    """Os ids que o `pack_remover` aceita — a cerca do argumento. [P53]"""
    mod = modulo_pack()
    if not mod:
        return []
    conf = valores_efetivos(["PACK", "FLAVOR"])
    return [i for i in sorted(_packs_no_disco())
            if (_remocao_do_cartao(mod, i, conf) or {}).get("pode")]


def packs_com_vitrine():
    """Os packs no disco, cada um com a vitrine que declara — o `/api/packs`."""
    mod = modulo_pack()
    if not mod:
        return []
    no_ar = _pack_no_ar()
    conf = valores_efetivos(["PACK", "FLAVOR"])
    saida = []
    for ident in sorted(_packs_no_disco()):
        try:
            p, dados, dir_pack = mod.validar(ident, silencioso=True)
        except Exception as erro:
            # `valido` falso tira o «Usar este» do cartão: o `meow pack usar`
            # recusaria este pack pelo mesmo motivo, e um botão que só leva a
            # uma recusa ensina a desconfiar dos outros.
            saida.append({"id": ident, "nome": ident, "problemas": [str(erro)],
                          "no_ar": ident == no_ar, "valido": False,
                          "remover": _remocao_do_cartao(mod, ident, conf)})
            continue
        vit, problemas = mod.vitrine(p, dir_pack)
        # O `vocabulario` sobe a herança e valida o dono dela; um dono quebrado
        # não pode sumir com o cartão deste pack — ele perde só o `info`.
        try:
            vocab = mod.vocabulario(ident)
        except Exception:
            vocab = {"flavors": [], "categorias": []}
        # Desde a a3ee4a6 o motor não confere o logo, e a vitrine só confere o
        # campo: um logo com `<script>` passaria pelas duas.
        flavor = (p.get("paleta") or {}).get("flavor_padrao") or next(iter(dados["flavors"]))
        if vit["capa"]:
            try:
                mod.logo(ident, flavor)
            except Exception as erro:
                problemas.append(str(erro))
                vit["capa"] = None
        texto = ""
        if vit["descricao"]:
            try:
                with open(vit["descricao"], encoding="utf-8", errors="replace") as fh:
                    texto = fh.read()
            except OSError:
                texto = ""
        # Os hex já passaram pelo `#RRGGBB` do `validar`, então vão direto para
        # o `style` sem outra peneira.
        cores = dados["flavors"].get(flavor) or {}
        base_url = "/pack-vitrine?id=" + quote(ident, safe="")
        saida.append({
            "id": ident,
            "nome": p.get("nome") or ident,
            "autor": p.get("autor") or "",
            "capa": (base_url + "&arte=capa") if vit["capa"] else "",
            "descricao_curta": vit["descricao_curta"],
            "descricao": texto,
            "tags": vit["tags"],
            "capturas": [base_url + "&arte=%d" % i for i in range(len(vit["capturas"]))],
            "site": vit["site"] or "",
            "origem": mod.resumo_de_origem(p),
            # Um pack feito de CSV pode ter o flavor claro DERIVADO, e o
            # cartão tem de dizer — ao lado da linha de herança, que já diz
            # que o resto vem de outro pack.
            "claros_derivados": [{"flavor": c, "de": e}
                                 for c, e in mod.claros_derivados(dados).items()],
            "amostra": [cores[s] for s in mod.SLOTS if s in cores],
            "problemas": problemas,
            # `no_ar` é o anel de acento do cartão e o que tira dele o «Usar
            # este».
            "no_ar": ident == no_ar,
            "valido": True,
            "flavors": vocab["flavors"],
            "categorias": vocab["categorias"],
            "remover": _remocao_do_cartao(mod, ident, conf),
        })
    return saida


def arte_da_vitrine(ident, arte):
    """(bytes, tipo) da capa ou de uma captura que o pack DECLAROU — ou None.

    O PEDIDO NÃO TRAZ CAMINHO NENHUM. `arte` é `capa` ou o número de uma
    captura; quem transforma isso em arquivo é a vitrine que o próprio pack
    declarou, já conferida pelo `pack.vitrine()` (dentro do pack pelo
    `realpath`, extensão certa, arquivo existindo). A rota `/previa?tipo=
    arquivo` precisou de uma cerca de pastas porque recebe caminho; esta não
    tem porta para cercar. E o `ident` só vale se for um pack que a varredura
    achou — o `achar` também aceita CAMINHO, e esta rota não é lugar para isso.
    """
    mod = modulo_pack()
    if not mod or ident not in _packs_no_disco():
        return None
    try:
        p, dados, dir_pack = mod.validar(ident, silencioso=True)
    except Exception:
        return None
    vit, _problemas = mod.vitrine(p, dir_pack)
    if arte == "capa":
        # O flavor é o padrão do pack, o mesmo da tira fina que o cartão põe
        # embaixo: a cara e a amostra falam do mesmo flavor.
        if not vit["capa"]:
            return None
        flavor = (p.get("paleta") or {}).get("flavor_padrao") or next(iter(dados["flavors"]))
        try:
            return mod.logo(ident, flavor).encode("utf-8"), "image/svg+xml"
        except Exception:
            return None
    elif re.fullmatch(r"[0-9]+", arte or "") and int(arte) < len(vit["capturas"]):
        alvo = vit["capturas"][int(arte)]
    else:
        return None
    if not alvo:
        return None
    tipo = {".svg": "image/svg+xml", ".png": "image/png", ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg"}.get(os.path.splitext(alvo)[1].lower())
    try:
        with open(alvo, "rb") as fh:
            return fh.read(), tipo
    except OSError:
        return None


# Não é regra derivada do comentário, e é de propósito: as três dizem coisas
# diferentes (uma lista de flavors de um acervo, um rótulo, um molde de dois
# campos), e uma regra que as juntasse precisaria de três exceções.
#
# O QUE NÃO MUDA: a cerca do `validar_valor`.

# Onde o `construir_pastas.sh` procura as cores do papirus-folders, com o mesmo
# `MEOW_CAT_FOLDERS` por cima. As duas pontas leem o mesmo diretório; o que a
# página oferece é o que aquele script vai achar.
_PAPIRUS_FOLDERS = os.environ.get("MEOW_CAT_FOLDERS") or os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
    "meowsystem", "upstream", "papirus-folders")
_RE_COR_DE_PASTA = re.compile(r"^folder-cat-([a-z0-9]+)-([a-z0-9]+)-documents\.svg$")


def _cores_de_pasta():
    """{variante: {cores}} que o papirus-folders deste disco traz."""
    achadas = {}
    try:
        nomes = os.listdir(os.path.join(_PAPIRUS_FOLDERS, "src", "64x64", "places"))
    except OSError:
        return achadas
    for nome in nomes:
        m = _RE_COR_DE_PASTA.match(nome)
        if m:
            achadas.setdefault(m.group(1), set()).add(m.group(2))
    return achadas


# O `NOME_TEMA_ICONES` do meow.conf no ambiente, só durante a pergunta à regra
# da base de ícones — ver o bloco 7, logo abaixo.
_NOME_DO_TEMA_TRAVA = threading.Lock()


def _com_o_vocabulario_do_pack(esquema, vocab, efetivos):
    """Reescreve, no esquema QUE VAI PARA A PÁGINA, o que é vocabulário do pack."""
    if not vocab:
        return
    por_chave = {i["chave"]: i for i in esquema}
    nome_pack = vocab["nome"]

    # 1. «Variante dos ícones de arquivo» — os flavors do acervo de mimetype que
    #    o pack no ar alcança, com o nome do dono quando é herdado. Ver o
    #    `vocabulario` do scripts/pack.py para o porquê de o Dracula oferecer um
    #    só: é o que ele declara em `icones.mimetypes.flavor`.
    item = por_chave.get("ICONES_FLAVOR")
    mt = vocab.get("mimetypes")
    if item and mt:
        herdado = (" (herdado do %s)" % mt["nome_de"]) if mt["herdado"] else ""
        oferta = [o for o in item["opcoes"] if o in mt["flavors"]]
        oferta += [f for f in mt["flavors"] if f not in oferta]
        agora = item.get("valor") or ""
        if agora and "$" not in agora and agora not in oferta:
            oferta.append(agora)
        item["opcoes"] = oferta
        # O nome próprio é o de qualquer flavor (`Macchiato`), sem inventar o
        # dono.
        item["rotulos"] = {f: (mt["nomes"].get(f) or f[:1].upper() + f[1:]) + herdado
                           for f in oferta}
        # Com o conf de fábrica e o Dracula no ar o cartão dizia «Vale como:
        # dracula» — o `"$FLAVOR"` expandido —, e o `icones_mimetypes.sh` não
        # vestia nada, porque dracula não tem acervo.
        try:
            item["efetivo"] = modulo_pack().flavor_de_icones(
                vocab["id"], efetivos.get("ICONES_FLAVOR"), efetivos.get("FLAVOR"))
        except Exception:
            pass

    # 2. «Pack de ícones Dracula nos aplicativos» — o ajuste liga os desenhos de
    #    aplicativo DO PACK NO AR (`icones.apps`), seja ele qual for. O nome de
    #    um pack no rótulo mentia para todos os outros; a frase diz de qual pack
    #    eles vêm hoje.
    item = por_chave.get("ICONES_DRACULA")
    if item:
        item["titulo"] = "Ícones do pack nos aplicativos"
        ap = vocab.get("apps")
        if ap and ap["herdado"]:
            item["frase"] = ("Os desenhos de aplicativo que o pack «%s» herda do «%s», "
                             "vestindo o lançador." % (nome_pack, ap["nome_de"]))
        elif ap:
            item["frase"] = ("Os desenhos de aplicativo do pack «%s», vestindo o lançador."
                             % nome_pack)
        else:
            item["frase"] = ("O pack «%s» não traz desenhos de aplicativo: com ele no ar, "
                             "este ajuste não tem o que vestir." % nome_pack)

    item = por_chave.get("ICONES_PASTAS")
    if item:
        cores_de = _cores_de_pasta()
        nomes = {f["id"]: f["nome"] for f in vocab["flavors"]}
        # DO ESCURO PARA O CLARO, pela luminância do `base` de cada flavor: é a
        # ordem de «Cor e tela» e da variante dos ícones de arquivo logo ao
        # lado, e a paleta.json guarda os flavors na ordem de quem a escreveu.
        mod = modulo_pack()
        ibase = mod.SLOTS.index("base") if mod else 0
        luz = (lambda f: mod._luminancia(f["cores"][ibase])) if mod else (lambda f: 0.0)
        variantes = [{"valor": "${FLAVOR}", "rotulo": "Acompanha o tema"}]
        # Eram só os que o papirus-folders traz, e com o Dracula no ar a lista
        # ficava vazia: ele só tem os quatro do Catppuccin.
        if cores_de:
            variantes += [{"valor": f["id"], "rotulo": f["nome"]}
                          for f in sorted(vocab["flavors"], key=luz)]
        todas = set().union(*cores_de.values()) if cores_de else set()
        # Sem o papirus-folders no disco a lista de cores são os catorze slots
        # cromáticos da paleta, que é exatamente o que ele traz quando chega; a
        # etapa das pastas se pula sozinha até lá, e a página diz isso.
        ordem = [s for s in (_paleta_dados().get("ordem_canonica") or [])[:14]]
        # O valor gravado continua sendo o slot. Um flavor que o pack no ar não
        # tem (escrito à mão) fica com o slot, que é o nome que ele sempre teve.
        achado = re.match(r"^cat-(.+)-([^-]+)$", efetivos.get("ICONES_PASTAS") or "")
        fl_pastas = achado.group(1) if achado else (efetivos.get("FLAVOR") or "")
        do_fl = next((f for f in vocab["flavors"] if f["id"] == fl_pastas), None)
        nome_da_cor = (_nomes_de_cor(dict(zip(mod.SLOTS[:14], do_fl["cores"])))
                       if do_fl and mod else {})
        cores = [{"valor": "${ACCENT}", "rotulo": "Acompanha o destaque"}]
        cores += [{"valor": c, "rotulo": (nome_da_cor[c][:1].upper() + nome_da_cor[c][1:])
                                         if nome_da_cor.get(c) else c.capitalize()}
                  for c in ordem if (c in todas or not todas)]
        flavor_no_ar = efetivos.get("FLAVOR") or ""
        item["frase"] = ("A variante e a cor das pastas comuns. «Acompanha» repinta "
                         "sozinho quando o tema ou o destaque mudam.")
        item["molde_pastas"] = {
            "variantes": variantes,
            "cores": cores,
            "sem_upstream": not cores_de,
            # O `construir_pastas.sh` cai na variante escura que ele tem e avisa
            # no log; a página diz o mesmo antes, com o nome do flavor.
            "fora_do_papirus": (nomes.get(flavor_no_ar) or flavor_no_ar)
                               if cores_de and flavor_no_ar not in cores_de
                               and flavor_no_ar not in nomes else "",
        }

    item = por_chave.get("FLAVOR")
    mod = modulo_pack()
    if item and mod and vocab["flavors"]:
        ibase = mod.SLOTS.index("base")
        flavors = sorted(vocab["flavors"], key=lambda f: mod._luminancia(f["cores"][ibase]))
        oferta = [f["id"] for f in flavors]
        agora = item.get("valor") or ""
        if agora and "$" not in agora and agora not in oferta:
            oferta.append(agora)
        item["opcoes"] = oferta
        item["rotulos"] = {f["id"]: f["nome"] + (" (derivado)" if f.get("derivado") else "")
                           for f in flavors}
        item["frase"] = ("As variantes do pack «%s», do escuro ao claro. Vale com "
                         "qualquer cor de destaque." % nome_pack)
        item["previa"] = _tipo_de_previa(item["chave"], oferta, item.get("faixa"),
                                         item.get("padrao"))

    item = por_chave.get("PACK")
    if item and mod:
        oferta = sorted(_packs_no_disco())
        agora = item.get("valor") or ""
        if agora and "$" not in agora and agora not in oferta:
            oferta.append(agora)
        item["opcoes"] = oferta
        item["rotulos"] = {i: (mod.campo(i, "nome") or i) for i in oferta}

    # O cartão dizia «Do Catppuccin» e «a que o Catppuccin escolheu» com o
    # Dracula no ar.
    item = por_chave.get("TERMINAL_CURSOR")
    if item:
        item["frase"] = "A cor de destaque, ou a que o tema «%s» escolhe." % nome_pack
        item["rotulos"] = {"accent": "Cor de destaque", "port": "Do tema «%s»" % nome_pack}

    # O `_base_escolhida` cede o `<NOME_TEMA_ICONES>-Base` pelo nome que o shell
    # exporta do meow.conf, e o painel nunca leu o conf para o ambiente: com um
    # nome próprio, a regra aqui cedia o `MeowSystem-Icons-Base`, que numa casa
    # assim nem existe, e tomava a base do pack por um tema escolhido à mão.
    item = por_chave.get("ICONES_BASE") or {}
    if mod:
        with _NOME_DO_TEMA_TRAVA:
            antes = os.environ.get("NOME_TEMA_ICONES")
            os.environ["NOME_TEMA_ICONES"] = efetivos.get("NOME_TEMA_ICONES") or ""
            try:
                quem, tema, decl = mod.base_que_vale(vocab["id"], efetivos.get("ICONES_BASE"))
                nossa = (efetivos.get("NOME_TEMA_ICONES") or "MeowSystem-Icons") + "-Base"
                candidatos = [""] + list(item.get("opcoes") or []) + [item.get("valor") or ""]
                cede = sorted({c for c in candidatos if not mod._base_escolhida(c)})
                _q, tema_cedido, decl_cedida = mod.base_que_vale(vocab["id"], "")
            except Exception:
                quem = None
            finally:
                if antes is None:
                    os.environ.pop("NOME_TEMA_ICONES", None)
                else:
                    os.environ["NOME_TEMA_ICONES"] = antes
        if quem:
            dono = mod.campo(decl_cedida["pack"], "nome") if decl_cedida else ""
            vocab["base_de_icones"] = {"vale": nossa if decl_cedida else tema_cedido,
                                       "de": dono or "", "cede": cede}
        if quem == "pack":
            dono = mod.campo(decl["pack"], "nome") or decl["pack"]
            item["efetivo"] = nossa
            item["rotulos"] = dict(item.get("rotulos") or {},
                                   **{nossa: "%s, a base do pack «%s»" % (nossa, dono)})

    # Os botões da «Cor de destaque» se apresentavam ao leitor de tela como
    # `mauve`, `sapphire`, `maroon` — os nomes que o Catppuccin dá às cores DELE
    # —, com o Dracula no ar, onde o `maroon` é um vermelho claro (#FF6E6E) e o
    # `blue` um azul acinzentado.
    if mod:
        ibase = mod.SLOTS.index("base")
        for f in vocab["flavors"]:
            f["nomes_de_cor"] = dict(_nomes_de_cor(dict(zip(mod.SLOTS[:14], f["cores"]))),
                                     **_NOMES_DAS_NEUTRAS)
            f["luz"] = round(mod._luminancia(f["cores"][ibase]), 4)

    # O desenho lia `ICONES_FLAVOR` cru, e o de fábrica é `"$FLAVOR"`: fora da
    # lista, a legenda dizia «o valor de ICONES_FLAVOR não é um dos aceitos» com
    # qualquer pack no ar.
    it_flavor = por_chave.get("ICONES_FLAVOR")
    if vocab.get("mimetypes") and it_flavor and it_flavor.get("efetivo"):
        vocab["mimetypes"]["efetivo"] = it_flavor["efetivo"]


# O teto de cada faixa.
_MATIZES = ((15, "vermelho"), (40, "laranja"), (70, "amarelo"), (160, "verde"),
            (185, "verde-água"), (200, "ciano"), (250, "azul"), (290, "roxo"),
            (335, "rosa"), (361, "vermelho"))
_MAIS_CLARO = ("", " claro", " mais claro")

# O `_nomes_de_cor` nomeia só as catorze cromáticas, e as doze neutras ficavam
# com o slot: a grade das cores da música, no Painel e dock, lia «Roxo» e
# «Verde» e, logo ao lado, «Surface2», «Overlay0», «Mantle», «Crust».
_NOMES_DAS_NEUTRAS = {
    "text": "texto", "subtext1": "texto secundário 1", "subtext0": "texto secundário 0",
    "overlay2": "sobreposição 2", "overlay1": "sobreposição 1", "overlay0": "sobreposição 0",
    "surface2": "superfície 2", "surface1": "superfície 1", "surface0": "superfície 0",
    "base": "fundo", "mantle": "fundo secundário", "crust": "fundo terciário",
}


def _nomes_de_cor(cores):
    """{slot: nome em português} para as cores de UM flavor, sem repetir nome.

    Duas cores do mesmo matiz — o `red` e o `maroon` do Dracula, o `blue` e o
    `lavender` do Catppuccin — ganham o mesmo nome de faixa, e o leitor de tela
    leria dois «vermelho» lado a lado. Dentro de uma faixa elas se distinguem
    pela claridade, da mais escura para a mais clara; a partir da quarta, pela
    ordem. O resultado é o mesmo para a mesma paleta, sempre.
    """
    import colorsys
    faixas = {}
    for slot, hexcor in cores.items():
        try:
            r, g, b = (int(hexcor[i:i + 2], 16) / 255 for i in (1, 3, 5))
        except (TypeError, ValueError):
            continue
        h, luz, sat = colorsys.rgb_to_hls(r, g, b)
        if luz >= 0.9:
            nome = "quase branco"
        elif sat < 0.2:
            nome = "cinza"
        else:
            nome = next(n for teto, n in _MATIZES if h * 360 < teto)
            if nome == "vermelho" and luz >= 0.8:
                nome = "rosa"
        faixas.setdefault(nome, []).append((luz, slot))
    saida = {}
    for nome, lista in faixas.items():
        for i, (_luz, slot) in enumerate(sorted(lista)):
            saida[slot] = nome + (_MAIS_CLARO[i] if i < len(_MAIS_CLARO) else " %d" % (i + 1))
    return saida


def _flavors_dos_packs():
    """Os flavors que algum pack deste disco tem — a cerca da «Variante do tema». [P31]

    A OFERTA É O PACK NO AR; A CERCA É O DISCO INTEIRO, e a diferença é de
    propósito. Cercar pelo pack no ar faria o `/api/definir` recusar
    `FLAVOR="dracula"` com o Catppuccin no ar — e um `.conf` importado com
    `PACK="dracula"` e `FLAVOR="dracula"` entraria pela metade, o pack trocado e
    o flavor recusado. O que o shell não saberia ler é um flavor que NENHUM pack
    tem; é esse que a cerca recusa. Um pack quebrado não entra na conta, e não
    derruba a dos outros.
    """
    mod = modulo_pack()
    saida = []
    if not mod:
        return saida
    for ident in sorted(_packs_no_disco()):
        try:
            _p, dados, _d = mod.validar(ident, silencioso=True)
        except Exception:
            continue
        saida += [f for f in dados["flavors"] if f not in saida]
    return saida


def _vestigio_de_pack(chave):
    """None, ou o aviso de que o valor cita um pack que já não é o adotado.

    O DEFEITO QUE ISTO CONTA — medido numa auditoria de QA em 18/09/2026
        Sair do Dracula para o Catppuccin Mocha exigia seis controles em três
        páginas, e nada na tela ligava um ao outro. Trocando só a «Variante do
        tema» para `mocha`, ficavam para trás `ICONES_BASE="Dracula-Icones"` e
        `ICONES_DRACULA="sim"` — e o desktop saía metade Catppuccin, metade
        Dracula, sem uma palavra dizendo por quê.

    POR QUE NÃO É `dominada_por`
        `dominada_por` afirma que a chave está ANULADA por outra. Aqui é o
        oposto: estas chaves estão valendo, e é assim que tem de ser — o
        meow.conf vence o pack, e quem mora na máquina decide (docs/PACKS.md,
        "Quem vence"). O aviso não corrige nada sozinho; só conta que o valor
        vem de um pack que não é o que está adotado agora.
    """
    # O valor sai de `valores_brutos()`, como `_dominada_por` faz: em
    # `ler_esquema` não há um `brutos` no escopo, e cada campo do item chama a
    # sua própria fonte. A leitura é cacheada pelo próprio `valores_brutos`.
    valor = (valores_brutos() or {}).get(chave, "")
    if not valor:
        return None
    packs = _packs_no_disco()
    if not packs:
        return None
    # O pack adotado: a chave PACK, ou o FLAVOR quando ela não existe — a mesma
    # adoção por convenção de meow_pack_dir() em lib/comum.sh.
    vals = valores_efetivos(["PACK", "FLAVOR"])
    adotado = (vals.get("PACK") or vals.get("FLAVOR") or "").strip().lower()
    # A linha acima é `PACK or FLAVOR`, e com o meow.conf DE FÁBRICA
    # (`PACK=""`, `FLAVOR="mocha"`) o `adotado` vira "mocha".
    #
    # O conserto anterior tratava só o ramo do Dracula, que é o caso raro.
    if adotado and adotado not in packs:
        mod = modulo_pack()
        dir_sabor = _pack_do_sabor(mod, adotado) if mod else None
        if dir_sabor:
            adotado = os.path.basename(dir_sabor.rstrip("/")).lower()
    alvo = valor.strip().lower()
    for pack in packs:
        if pack == adotado:
            continue
        # O pack padrão leva o nome do produto (P96): «meowsystem» num caminho ou num nome
        # de tema é o MeowSystem, não um vestígio do pack. O que denuncia o valor dele é o
        # nome de antes, «catppuccin» (os apelidos do pack.py).
        mod_p = modulo_pack()
        apelidos = [a for a, d in (getattr(mod_p, "APELIDOS", {}) or {}).items() if d == pack]
        nomes = apelidos if pack == getattr(mod_p, "PACK_BASE", "meowsystem") else [pack] + apelidos
        if any(n in alvo for n in nomes):
            # Mandar a pessoa desconfiar do valor certo, e prometer tela
            # misturada onde não há mistura, é pior que não avisar nada.
            if _declarado_pelo_pack(adotado, alvo):
                return None
            return {"pack": pack, "adotado": adotado or "(o padrão)",
                    "porque": ("Este valor é do pack «%s», e o adotado agora é «%s». "
                               "Ele continua valendo — o seu meow.conf vence o pack —, "
                               "mas o resultado na tela fica misturado." % (pack, adotado or "o padrão"))}
    return None


def _pack_do_sabor(mod, sabor):
    """O diretório do pack que declara este SABOR na paleta — ou `None`.

    Existe por causa de uma linha do chamador: `adotado = PACK or FLAVOR`. Com
    a chave `PACK` vazia — que é o padrão de fábrica — o que chega aqui é o
    nome do sabor, e nenhum pack se chama "mocha". Ver o bloco de 22/09/2026
    em `_declarado_pelo_pack`.
    """
    alvo = (sabor or "").strip().lower()
    if not alvo:
        return None
    for raiz in (mod.raizes() if hasattr(mod, "raizes") else []):
        try:
            nomes = sorted(os.listdir(raiz))
        except OSError:
            continue
        for nome in nomes:
            d = os.path.join(raiz, nome)
            pj = os.path.join(d, "pack.json")
            if not os.path.isfile(pj):
                continue
            try:
                with open(pj, encoding="utf-8") as fh:
                    no = json.load(fh)
                arq = (no.get("paleta") or {}).get("arquivo") or "paleta.json"
                with open(os.path.join(d, arq), encoding="utf-8") as fh:
                    pal = json.load(fh)
            except (OSError, ValueError):
                continue
            if alvo in {f.lower() for f in (pal.get("flavors") or {})}:
                return d
    return None


def _declarado_pelo_pack(adotado, alvo):
    """True quando o PRÓPRIO pack adotado declara este valor no pack.json.

    POR QUE A COMPARAÇÃO É POR IGUALDADE, E NÃO POR SUBSTRING
        O laço acima pergunta "o nome de outro pack aparece dentro do valor?",
        que é uma rede larga de propósito — `ICONES_BASE="Dracula-Icones"` tem
        de cair nela. Aqui a pergunta é o oposto: "este valor, inteiro, é uma
        receita do pack adotado?". Substring devolveria verdadeiro para
        qualquer valor que por acaso aparecesse dentro de uma prosa do
        pack.json, e o aviso sumiria onde deve aparecer.

    AS CHAVES `_` FICAM DE FORA PORQUE SÃO COMENTÁRIO
        `_nota`, `_nota_heranca` e companhia são a prosa do formato (ver
        docs/PACKS.md). Um valor citado dentro de uma nota não é declaração —
        é explicação de por que ele NÃO se usa, às vezes.
    """
    mod = modulo_pack()
    if not mod or not adotado:
        return False
    dir_pack = mod.achar(adotado)
    if not dir_pack:
        return False
    try:
        with open(os.path.join(dir_pack, "pack.json"), encoding="utf-8") as fh:
            no = json.load(fh)
    except (OSError, ValueError):
        return False
    pilha = [no]
    while pilha:
        atual = pilha.pop()
        if isinstance(atual, dict):
            pilha.extend(v for k, v in atual.items() if not k.startswith("_"))
        elif isinstance(atual, list):
            pilha.extend(atual)
        elif isinstance(atual, str) and atual.strip().lower() == alvo:
            return True
    return False


# As escolhas de ícone do painel moram com quem usa, ao lado do meow.conf: usar o
# programa não suja o repositório, e levar para o pack é gesto explícito.
def _mapa_de_escolhas_do_usuario():
    mod = modulo_pack()
    if mod and hasattr(mod, "arquivo_de_escolhas"):
        return mod.arquivo_de_escolhas()
    return os.path.join(os.path.dirname(CONF), "icones-escolhidos.map")


def _mapa_de_traco_do_usuario():
    return (os.environ.get("MEOW_ICONES_TRACO")
            or os.path.join(os.path.dirname(CONF), "icones-traco.map"))


#   decisão 15). O «Usar» da oficina gravava o retoque, o construído e a linha
#   `<app>:mao:<cor>` dentro do clone (`assets/icones/`). Os três vão para a
#   casa, no mesmo molde do `icones-escolhidos.map`:
#     · `icones-convertidos.map`, ao lado do meow.conf, no formato do
#       `apps-convertidos.map` — lido depois dele pelo `construir_convertidos.sh`
#       e pelo `icones_apps_arcticons.sh`, e vence o app que os dois nomeiam;
#     · `~/.local/share/meowsystem/retoques/` e `convertidos-apps/`, o retoque e
#       o construído. O repositório só os recebe por gesto explícito.
def _mapa_de_convertidos_do_usuario():
    return (os.environ.get("MEOW_ICONES_CONVERTIDOS")
            or os.path.join(os.path.dirname(CONF), "icones-convertidos.map"))


def _oficina_do_usuario(*partes):
    xdg = os.environ.get("XDG_DATA_HOME") or os.path.join(os.path.expanduser("~"), ".local", "share")
    return os.path.join(xdg, "meowsystem", *partes)


def _gravar_escolha(caminho, chave, linha, separador):
    """Troca (ou tira, com `linha` None) a linha de `chave` em `caminho`.

    O resto do arquivo sobrevive, como nos mapas do repositório: é a pessoa
    quem pode ter escrito ali à mão. Devolve True quando havia linha da chave.
    Grava por arquivo temporário e `rename`, para uma página fechada no meio
    não deixar o arquivo pela metade."""
    try:
        with open(caminho, "r", encoding="utf-8") as fh:
            linhas = fh.read().split("\n")
    except FileNotFoundError:
        linhas = []
    if linhas and linhas[-1] == "":
        linhas.pop()

    def da_chave(l):
        util = l.split("#", 1)[0]
        return util.split(separador, 1)[0].strip() == chave and separador in util

    havia = any(da_chave(l) for l in linhas)
    linhas = [l for l in linhas if not da_chave(l)]
    if linha is not None:
        linhas.append(linha)
    os.makedirs(os.path.dirname(caminho) or ".", exist_ok=True)
    tmp = caminho + ".meow-tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write("\n".join(linhas) + ("\n" if linhas else ""))
    os.replace(tmp, caminho)
    return havia


@_uma_vez_por_leitura
def _pack_adotado():
    """O id do pack no ar, ou '' sem `scripts/pack.py`. [23/09/2026]

    A oficina (sprint P26) precisa dele para dizer se o desenho de um pack é do
    pack que está no ar, e a lista de ponteiros (`_ponteiro_do_pack`) para
    saber de que pack é o ponteiro que o `cursor.sh` instalaria.

    A CONTA NÃO É FEITA AQUI DESDE A P35 — 23/09/2026
        Era: a chave PACK, ou o FLAVOR traduzido para o pack que o declara. O
        `meow_pack_dir` do shell fazia outra — só pelo NOME do FLAVOR —, e com
        `PACK=""` e `FLAVOR="alucard"` este lado dizia `dracula` enquanto a
        máquina vestia o padrão. Agora os dois perguntam ao `adocao` do
        `scripts/pack.py`, e o `tests/pack.sh` roda os dois no mesmo HOME de
        brinquedo e compara. O padrão sai com o id dele, e não vazio: é ele que
        veste a máquina quando ninguém escolheu outro.
    """
    mod = modulo_pack()
    if not mod:
        return ""
    vals = valores_efetivos(["PACK", "FLAVOR"])
    return mod.adocao(vals.get("PACK") or "", vals.get("FLAVOR") or "")[0]


def _enumerar(itens):
    """'a', 'a e b', 'a, b e c' — a enumeração do português, para frase de tela."""
    itens = [i for i in itens if i]
    if len(itens) <= 1:
        return "".join(itens)
    return ", ".join(itens[:-1]) + " e " + itens[-1]


def _dominada_por(chave):
    regra = DOMINIOS.get(chave)
    if not regra:
        return None
    valor = _valor_vivo(regra["chave"])
    if not regra["quando"](valor):
        return None
    # O TÍTULO VAI JUNTO, e é o que a página mostra.
    return {"chave": regra["chave"], "titulo": _titulo_de(regra["chave"]),
            "valor": valor, "porque": regra["porque"]}


def _opcoes_fechadas(chave, ajuda, inline, padrao):
    """As opções que valem como CERCA na hora de escrever — e só essas.

    A DIFERENÇA ENTRE SUGERIR E PROIBIR, E ELA IMPORTA NA ESCRITA
        Uma lista que veio do TEXTO é fechada: o `case` do shell do outro lado
        só conhece aqueles valores, e `MODO="gigante"` cai no `*)` calado. Uma
        lista que veio do DISCO é aberta: ela é o acervo de hoje, e o arquivo
        diz isso com todas as letras — `FASTFETCH_LOGO_GATO` documenta que
        "qualquer outro valor é tratado como caminho de um SVG seu", e o acervo
        de gatos cresce quando ela solta um arquivo na pasta.

        Tratar as duas igual faria o `/api/definir` recusar um caminho de SVG
        que o `fastfetch_logo.sh` aceita — a página proibindo o que a CLI
        permite, que é o pior lado para errar.

        Quem decide de que lado cada acervo está é a terceira coluna de
        `FONTES_DO_DISCO`, e o motivo está escrito lá: o que ESTA página sabe
        encher é aberto; o que tem de já estar instalado no sistema é cerca.
    """
    lista, cerca = _disco_detalhe(ajuda, inline, padrao)
    if lista:
        return lista if cerca else []
    opcoes = _opcoes_finais(chave, ajuda, inline, padrao)

    if opcoes and all(RE_DURACAO.match(o) for o in opcoes):
        return []
    return opcoes


# Nenhuma chave deste arquivo diz "sou um inteiro". O que ela diz é `="40"`,
# `="0.85"`, `="1d"` — e isso já é a declaração inteira, escrita no lugar onde
# ninguém esquece de atualizá-la.
FORMAS_NUMERO = (
    ("inteiro", re.compile(r"^\d+$"), "um número inteiro (0, 12, 40)"),
    ("decimal", re.compile(r"^\d*[.,]\d+$"), "um número com ponto decimal (0.85)"),
    ("duracao", re.compile(r"^\d+[smhd]$"), "uma duração: número + s/m/h/d (30m, 1d)"),
)
RE_HORARIO_VALOR = re.compile(r"^([01]?\d|2[0-3]):[0-5]\d$")


def _forma_de_numero(padrao):
    """`inteiro`, `decimal`, `duracao` — ou vazio, quando o padrão não é número."""
    for nome, forma, _explica in FORMAS_NUMERO:
        if forma.match(padrao or ""):
            return nome
    return ""


def _vazio_vale(inline):
    """O número que a chave vazia vale, quando o comentário da linha o declara
    no formato `(vazio = 7)`; senão None.

    O «COMO ESTÁ» SEM NÚMERO — 10/10/2026, P77 (achado 25). «O tema claro
    começa às» nasce vazio, e vazio ali não é «não toca»: o `modo_desejado`
    do `bin/meow` lê `${MODO_AUTO_CLARO_DE:-7}`. O deslizante desenhava a alça
    no 0 e dizia só «como está», e o relógio da página não tinha como saber
    que o claro começa às 7. O arquivo já escreve o número ao lado da linha;
    só se aceita número, porque `(vazio = não toca)` é o outro contrato, o do
    terceiro estado, e não um valor."""
    m = re.search(r"\(vazio\s*=\s*(-?\d+(?:\.\d+)?)\s*\)", inline or "")
    return m.group(1) if m else None


def _faixa(ajuda, inline):
    """(minimo, maximo, passo) quando o comentário declara uma faixa numérica.

    SÓ O COMENTÁRIO DE LINHA E O PRIMEIRO PARÁGRAFO — 01/09/2026
        A varredura começou lendo o bloco inteiro, e o `WALLPAPER_LIMIAR_LUZ`
        provou por que isso não pode ser: a faixa dele é 0 a 1, mas quinze linhas
        abaixo o comentário conta a MEDIÇÃO que escolheu o corte — "o trecho
        vazio mais largo dentro do vale vai de 0,3605 a 0,3818". A página
        desenhava um controle deslizante de 0,3605 a 0,3818, e o pior é que
        parecia certo: o valor dela, 0,37, cai dentro. Ela sairia daqui achando
        que o limiar não pode passar de 0,38.

        A prosa de medição é a alma deste arquivo e não vai sair dele. Quem tem
        de mudar é a leitura: uma faixa que governa um controle é declarada de
        cara — no comentário da linha ou na primeira frase —, nunca enterrada
        no meio da demonstração.
    """
    paragrafos = _paragrafos(ajuda)
    # A ORDEM DA BUSCA É O COMENTÁRIO DE LINHA, DEPOIS O ÚLTIMO PARÁGRAFO,
    # DEPOIS O PRIMEIRO — e ela sai de como este arquivo é escrito, não de
    # gosto: `LEITURA_TEMPERATURA` declara `1000–6500 K` no comentário de linha,
    # `MIDIA_LARGURA` declara `80..900` na última linha antes da chave, e o
    # resto abre o bloco com a definição.
    candidatos = [inline]
    if paragrafos:
        candidatos.append(paragrafos[-1])
        candidatos.append(paragrafos[0])
    for linha in candidatos:
        achado = RE_FAIXA.search(linha or "")
        if not achado:
            continue
        a, b = achado.group(1).replace(",", "."), achado.group(2).replace(",", ".")
        try:
            lo, hi = float(a), float(b)
        except ValueError:
            continue
        if hi <= lo:
            continue
        fracionario = "." in a or "." in b
        # Uma faixa de dois dígitos costuma ser um horário ou uma data no meio
        # da prosa, não um controle. O piso de amplitude tira o falso positivo
        # sem precisar de lista de exceção.
        if not fracionario and hi - lo < 10:
            continue
        passo = 0.01 if fracionario else 1
        return (lo, hi, passo)
    return None


# Palavras que convivem com uma faixa: valores especiais que o script trata
# antes de olhar o número. Hoje é uma só, e ela está escrita no arquivo que a
# declara ("a palavra `auto` devolve a escala do painel").
_PALAVRAS_COM_FAIXA = ("auto",)


def _faixa_confere(faixa, padrao):
    """A faixa só vale se o PRÓPRIO PADRÃO DA CHAVE couber nela.

    É a conferência que dispensa uma lista de exceções, e ela pegou dois falsos
    positivos que nenhuma outra regra pegava:

        JANELAS_TILING  padrão "sim"   faixa lida (177, 190)
        LEITURA_AGENDA  padrão "sim"   faixa lida (0.0, 1.0)

    Os dois números do primeiro são o intervalo de LINHAS de `tiling/mod.rs`
    citado na medição (`:177-190`); os do segundo são a faixa da chave VIZINHA,
    a `leitura_textura`, mencionada na explicação. Uma chave cujo valor de
    fábrica é a palavra `sim` não tem controle deslizante — e é o arquivo quem
    diz isso, sem ninguém precisar vir aqui listar exceção.

    Chave que nasce vazia passa: não há padrão com que discordar, e são
    justamente as `FORMA_*`, cuja faixa legítima ninguém declarou.
    """
    if faixa is None:
        return None
    if padrao == "":
        return faixa
    try:
        valor = float(padrao.replace(",", "."))
    except ValueError:
        # `MIDIA_FONTE` nasce `auto` e o arquivo crava, com todas as letras, "A
        # UNIDADE É PIXEL, E A FAIXA VAI DE 6 A 48".
        return faixa if padrao in _PALAVRAS_COM_FAIXA else None
    return faixa if faixa[0] <= valor <= faixa[1] else None


def _e_titulo(linha):
    """Uma linha em CAIXA ALTA. O `meow.conf.exemplo` usa isso como TÍTULO.

    O PARÊNTESE SAI ANTES DA CONTA, E ISSO É MEDIÇÃO
        `AS JANELAS LADO A LADO (o "fibonacci")` tem 22 letras maiúsculas e 12
        minúsculas — 0,65, abaixo do corte — e por isso era lido como título de
        ASSUNTO, não de bloco. O efeito na página era um item de navegação
        chamado "AS JANELAS LADO A LADO" no mesmo nível de "Aparência" e
        "Ícones", levando junto as dez chaves do modo de leitura. O parêntese
        neste arquivo é sempre um aparte em voz baixa (`(novo em 01/09/2026)`,
        `(o "fibonacci")`); tirá-lo antes de contar é ler o título de verdade.
    """
    limpa = re.sub(r"\([^)]*\)", "", linha)
    letras = [c for c in limpa if c.isalpha()]
    if not letras:
        return False
    return sum(1 for c in letras if c.isupper()) / len(letras) > 0.7


def _paragrafos(ajuda):
    """O bloco de comentário partido em parágrafos, com as linhas RECOLADAS.

    ISTO NÃO É COSMÉTICA, É O QUE FAZ A FRASE TERMINAR — 01/09/2026
        A primeira versão pegava a primeira LINHA do comentário, e o resultado na
        tela era `Qual variante do Catppuccin. Só vale o que tem captura em`:
        cortado no meio, porque o arquivo é escrito em 79 colunas e a frase segue
        na linha de baixo. O comentário deste projeto é prosa quebrada por
        largura, não por sentido — então quem lê tem de recolar antes de cortar.
    """
    saida, atual = [], []
    for bruta in ajuda.splitlines():
        linha = bruta.lstrip("#").rstrip()
        # Um `#` sozinho, ou uma régua de traços, separa parágrafos.
        if not linha.strip() or set(linha.strip()) <= {"-", "="}:
            if atual:
                saida.append(" ".join(atual))
                atual = []
            continue
        atual.append(linha.strip())
    if atual:
        saida.append(" ".join(atual))
    return saida


def _so_com_app(ajuda):
    """Os ids da marca `[so-com-app id1 id2 …]` do comentário, ou lista vazia.
    Ver o campo `so_com_app` do esquema."""
    m = re.search(r"\[so-com-app ([^\]]+)\]", ajuda or "")
    return m.group(1).split() if m else []


def _frase_curta(ajuda, inline):
    """A frase que aparece embaixo do controle, sem a pessoa abrir nada.

    O `meow.conf.exemplo` é comentado em PROSA LONGA, e ela é a documentação
    deste projeto — mas jogar quinze linhas sob cada controle faria uma página
    ilegível. A regra tem três passos: recolar as linhas em parágrafos, pular os
    que são TÍTULO (o arquivo grita em caixa alta o tempo todo: `A OPACIDADE DO
    FUNDO É SUA, E POR ISSO...`), e cortar o primeiro parágrafo que sobrar no fim
    de uma FRASE, não no meio de uma palavra.

    Quando não sobra parágrafo nenhum, o comentário de linha vira a frase — é o
    caso das chaves cuja única ajuda é `# sim | nao`. O bloco inteiro continua a
    um clique de distância na página, então ninguém fica sem a explicação longa.
    """
    # A lista de opções sai ANTES de os parágrafos serem montados: ela costuma
    # estar colada na última linha do bloco, sem branco antes, e entraria no
    # meio da frase se fosse filtrada depois.
    limpas = []
    for l in ajuda.splitlines():
        if not _e_linha_de_opcoes(l):
            limpas.append(l)
            continue
        aparte = re.search(r"\(([^)]*)\)", l)
        if aparte and len(aparte.group(1)) > 8:
            limpas.append("# " + aparte.group(1).strip())
    for paragrafo in _paragrafos("\n".join(limpas)):
        texto = paragrafo.replace("[essencial]", "").strip()
        if not texto or len(texto) < 12:
            continue
        # Um título que tenha frase colada depois (`A TEXTURA DE PAPEL: 0.0 é
        # nenhuma...`) não é descartado: só se descarta o parágrafo cuja
        # PRIMEIRA oração inteira é grito.
        primeira = re.split(r"(?<=[.:!?])\s", texto, 1)[0]
        if _e_titulo(primeira) and len(primeira) > 20:
            resto = texto[len(primeira):].strip()
            if len(resto) < 12:
                continue
            texto = resto
        if len(texto) <= 200:
            return texto
        # Corte no fim de frase, e só se ele cair depois da metade — um `.` numa
        # abreviação logo no começo devolveria um pedaço inútil.
        corte = texto.rfind(". ", 0, 200)
        return texto[:corte + 1] if corte > 90 else texto[:197].rstrip() + "…"
    # O comentário de linha é o último recurso — mas não quando ele é a própria
    # lista de opções.
    return "" if _e_linha_de_opcoes(inline) else inline


def _capturas_no_disco():
    """Os nomes das capturas de tema que existem — `mocha-mauve`, `latte-mauve`…

    A página usa para avisar ANTES: `FLAVOR` × `ACCENT` dão 48 combinações e só
    as capturadas instalam. Sem isto ela escolhia, salvava, rodava o instalador
    e só então levava o não. (E o `bin/meow` lia isso de `state/tema/`, um
    caminho que a reorganização deixou para trás — corrigido no mesmo dia.)

    QUEM DIZ ONDE ELAS MORAM É O `pack.py` — 22/09/2026
        A P14 desceu cada captura para dentro do pack dono dela e deixou só a
        `original` no motor. Este `listdir` cravado devolveria UMA captura num
        repositório inteiro, e a página avisaria "não há captura para
        mocha-mauve" com a captura no disco — o mesmo defeito de `state/tema/`
        que o parágrafo acima conta, três casas de mudança depois.

        Sem o `pack.py` (o painel tem de subir numa árvore quebrada, ver
        `modulo_pack`), cai no motor: é pouco, e é honesto.
    """
    mod = modulo_pack()
    if mod is not None:
        try:
            return mod.capturas()
        except Exception:
            pass
    pasta = os.path.join(RAIZ, "assets", "temas", "capturados")
    try:
        return sorted(n for n in os.listdir(pasta)
                      if os.path.isdir(os.path.join(pasta, n)))
    except OSError:
        return []


@_numa_leitura
def ler_esquema():
    """Ordem, seção, ajuda e opções de cada chave — direto do meow.conf.exemplo."""
    itens = []
    vistas = {}
    bloco = []
    secao = ""
    subsecao = ""
    colada = False          # a linha anterior era uma chave, sem branco no meio
    try:
        with open(CONF_PADRAO, "r", encoding="utf-8") as fh:
            linhas = fh.read().splitlines()
    except OSError:
        return []

    for linha in linhas:
        if linha.startswith("# --- "):
            # `# --- Aparência ------` -> `Aparência`. O corte no primeiro `-`
            # é o mesmo do bash, e é o que tira a régua de traços do título.
            nome = linha[len("# --- "):].split("-", 1)[0].strip()
            colada = False
            if nome:
                # Os seis títulos de assunto estão em Capitulares (`Aparência`,
                # `Ícones`, `Wallpaper`, `Apps`, `Automação`, `Terminal`); os
                # outros treze estão em CAIXA ALTA (`A FORMA DO PAINEL E DO
                # DOCK`).
                if _e_titulo(nome):
                    subsecao = nome
                else:
                    secao = nome
                    subsecao = ""
            bloco = []
            continue
        if linha.startswith("#"):
            bloco.append(linha)
            continue
        if not linha.strip():
            bloco = []
            colada = False
            continue
        achado = RE_CHAVE.match(linha)
        if not achado:
            bloco = []
            colada = False
            continue
        chave = achado.group(1)

        titulo_escrito = frase_escrita = ""
        resto = []
        for l in bloco:
            if l.startswith("# @ "):
                titulo_escrito = l[4:].strip()
            elif l.startswith("# > "):
                frase_escrita = l[4:].strip()
            else:
                resto.append(l)
        bloco = resto
        ajuda = "\n".join(bloco)
        inline = _comentario_da_linha(linha)

        #   Dezoito das 95 chaves ficavam sem UMA palavra de ajuda, e não é
        #   descuido do arquivo: ele escreve os pares e as famílias sob um
        #   comentário só, coladas, sem linha em branco no meio —
        #       NOITE_INICIO=""
        #       NOITE_FIM=""
        #   e as oito `FORMA_*`, e as duas `VIDRO_OPACIDADE_*`, e o
        #   `MIDIA_COR_TITULO`/`MIDIA_COR_ARTISTA`. O bloco explica as duas (ou as
        #   oito) de uma vez, porque é uma decisão só.
        herdada = False
        ajuda_de = ""
        if not bloco and colada and itens:
            ajuda = itens[-1]["ajuda"]
            herdada = True
            # Saber que a explicação é herdada não basta: o balão `?` mostrava
            # o texto inteiro sem uma palavra dizendo de onde ele vinha, e em
            # "Dia e noite" isso dá QUATRO balões repetindo blocos alheios — o
            # de `WALLPAPER_NOITE_FIM` abre com um parágrafo sobre uma captura
            # de 23:57 e o carrossel.
            ajuda_de = itens[-1]["ajuda_de"] or itens[-1]["chave"]
        colada = True
        item = {
            "chave": chave,
            "secao": secao,
            "subsecao": subsecao,
            "ajuda": ajuda,
            "inline": inline,
            # O título escrito vence o derivado; a página faz a mesma escolha na
            # ordem `titulo` -> `titulo_irmas` -> derivação.
            "titulo": titulo_escrito,
            "frase": frase_escrita or _frase_curta(ajuda, inline),
            "padrao": _valor_da_linha(linha),
            # O DE FÁBRICA QUE O PACK NO AR ESCOLHE, quando ele escolhe — ver
            #   `_padrao_do_pack`. É o que o «Restaurar ao padrão» grava.
            "padrao_do_pack": _padrao_do_pack(chave),
            # `vazio` NÃO É UM VALOR, É A AUSÊNCIA DELE — e escrevê-lo seria um bug
            #   Três chaves documentam `nao | sim | vazio (= não toca)`. Lido ao pé
            #   da letra, o `vazio` vira mais um token da lista, e um clique nele
            #   gravaria `RELOGIO_SEGUNDOS="vazio"` — que não é `sim`, não é `nao`,
            #   e cairia no `*)` de qualquer `case` do projeto sem nada avisar.
            #   Aqui ele sai da lista de opções e vira o terceiro estado do
            #   controle, que é o que a prosa do arquivo quer dizer.
            "opcoes": _opcoes_finais(chave, ajuda, inline, _valor_da_linha(linha), herdada),
            "faixa": _faixa_confere(_faixa(ajuda, inline), _valor_da_linha(linha)),
            # O QUE O VAZIO VALE, quando o arquivo o diz — ver `_vazio_vale`.
            "vazio_vale": _vazio_vale(inline),
            # As duas horas do tema claro são um número de 0 a 23 (o
            # `modo_desejado` do `bin/meow` compara horas inteiras), e a página
            # as desenhava num deslizante pontilhado ao lado das outras duas
            # linhas de «Dia e noite», que são seletor de hora.
            "hora_cheia": bool(re.search(r"\bhora cheia\b", inline or "")),
            # A forma do número, quando há uma. Sai do VALOR DE FÁBRICA, que é
            # onde o arquivo já a declara sem precisar de uma palavra a mais —
            # ver `FORMAS_NUMERO`.
            "tipo_numero": _forma_de_numero(_valor_da_linha(linha)),
            # Que prévia visual esta chave merece. Deduzido do conteúdo dela —
            # ver `_tipo_de_previa`, que explica por que não há lista aqui.
            "previa": _tipo_de_previa(
                chave,
                _opcoes_finais(chave, ajuda, inline, _valor_da_linha(linha), herdada),
                _faixa_confere(_faixa(ajuda, inline), _valor_da_linha(linha)),
                _valor_da_linha(linha)),
            # QUAL CHAVE ESTÁ ANULANDO ESTA, se alguma. A página não tinha como
            # saber: quem lê a conf dela é este arquivo.
            "dominada_por": _dominada_por(chave),
            # O valor cita um pack que já não é o adotado? Ver _vestigio_de_pack.
            "vestigio_de_pack": _vestigio_de_pack(chave),
            # O QUE ESTÁ VALENDO AGORA, quando não é o conf que manda.
            "valendo_agora": _valendo_agora(chave),
            # E QUANDO A MÁQUINA DIZ "DESLIGADO" — ver `_leitura_desligada`.
            "desligado_agora": chave in _LEITURA_ZERO_DESLIGA and _leitura_desligada(
                chave, (_cosmic_ler("com.system76.CosmicComp/v1/" + chave.lower())
                        or "").strip('"')),
            "ajuda_herdada": herdada,
            # A CHAVE dona do bloco, não o título dela: quem sabe titular um
            # cartão é a página (`tituloDoCartao`), que já deriva o título de
            # quem não tem `# @ ` escrito.
            "ajuda_de": ajuda_de,
            "essencial": "[essencial]" in ajuda,
            # A página os recolhe num «⋯» no fim da página; o controle continua
            # lá, gravando a mesma chave.
            "avancado": "[avancado]" in ajuda,
            # `[so-com-app id1 id2]` diz que o ajuste só faz sentido onde um
            # destes `.desktop` existe — a logo própria do Hefesto era um
            # cartão de fábrica para todo mundo, e só quem tem o Hefesto tem o
            # que trocar.
            "so_com_app": _so_com_app(ajuda),
            # Lista separada por vírgula: a regra é o que o comentário DIZ, não
            # uma lista de nomes de chave.
            "lista": bool(re.search(r"separad[ao]s? por v[ií]rgula|v[ií]rgula[- ]separad", ajuda, re.I)),
            "lista_pathsep": bool(re.search(r"separados por `?:`?", ajuda)),
            # Lista de IDs de `.desktop`: as fichas ganham o nome e o ícone do
            # programa no `_dados_esquema`. A mesma regra das duas de cima — o
            # que o comentário DIZ, e não um nome de chave.
            "ids_de_desktop": bool(re.search(r"\bIDs? d[oe] `\.desktop`", ajuda)),
            # Horário: o comentário declara `HH:MM`, OU o valor já é um horário.
            "horario": ("HH:MM" in (ajuda + inline)
                        or bool(re.fullmatch(r"\d{1,2}:\d{2}", _valor_da_linha(linha)))
                        # Chave que nasce VAZIA e cujo comentário cita um
                        # horário literal LOGO NA ABERTURA: são a NOITE_INICIO e
                        # a NOITE_FIM, que falam em "18:00-07:00" no meio da
                        # frase e nunca escrevem `HH:MM`.
                        or (_valor_da_linha(linha) == ""
                            and bool(re.search(r"\b\d{1,2}:\d{2}\b",
                                               (_paragrafos(ajuda) or [""])[0])))),
            # "vazio = não toca" é um TERCEIRO estado, e o arquivo o declara com
            # todas as letras em nove blocos.
            "aceita_vazio": bool(
                re.search(r"[Vv]azio\s*\(?\s*=|[Vv]azio\s+significa|nascem vazias|nasce vazia"
                          r"|VAZIO\s*=|não toca", ajuda + inline)
                or "vazio" in _opcoes(chave, ajuda, inline)
                # Uma chave cujo PADRÃO no exemplo já é vazio aceita vazio por
                # definição — não há como argumentar contra o próprio arquivo.
                or _valor_da_linha(linha) == ""
            ),
        }
        if chave in vistas:
            # Chave repetida entra UMA vez, como no wizard: perguntar duas vezes a
            # mesma coisa é oferecer a chance de se contradizer.
            itens[vistas[chave]] = item
        else:
            vistas[chave] = len(itens)
            itens.append(item)
        bloco = []
    return itens


# --- 3. os valores dela ------------------------------------------------------
def _pasta_do_mascote():
    """A pasta `mascote/` do pack no ar (pela herança), ou a do pack-base."""
    mod = modulo_pack()
    if mod and hasattr(mod, "pasta_do_mascote"):
        return mod.pasta_do_mascote(_pack_adotado() or None)
    return os.path.join(RAIZ, "packs", "meowsystem", "mascote")


def _gatos():
    """O acervo `mascote/` do pack no ar, que é a configuração — soltou um .svg, entrou."""
    pasta = _pasta_do_mascote()
    try:
        nomes = sorted(
            os.path.splitext(f)[0] for f in os.listdir(pasta)
            if f.endswith(".svg") and not f.endswith("-symbolic.svg")
        )
    except OSError:
        return []
    return nomes


def _capturas():
    """Os temas prontos que «Trocar de tema» oferece — e o servidor aceita.

    A MESMA FONTE DO `meow tema` — 24/09/2026, sprint P48 (achado 30)
        Esta função listava `assets/temas/capturados/` direto, e desde que as
        capturas desceram para dentro dos packs (P14/P27) ali só sobrou a
        `original`: a ação oferecia UMA opção, pré-selecionada, e era
        justamente a que não devia. Quem sabe quais capturas o pack no ar
        alcança é o `pack.py capturas`, que o `meow tema` já usa — é o
        `_capturas_no_disco`, logo acima, que o aviso do FLAVOR × ACCENT já
        consultava. Uma regra só, dos dois lados.

    A `original` FICA DE FORA, E É A SEGUNDA METADE DO ACHADO
        Ela é o tema de fábrica da máquina onde foi tirada (a linha `origem:`
        do captura.txt dela diz de qual casa), não um tema de pack. Aplicada
        noutra máquina, troca o tema da pessoa pelo de outra e apaga as chaves
        que não tem. O `meow tema original` recusa numa máquina estranha pela
        mesma guarda do `meow desfazer` (`guarda_original`, no bin/meow); aqui
        ela nem aparece: o caminho de volta do painel é o «Voltar ao tema de
        antes», que passa por aquela guarda.
    """
    _ponte_em_dia()
    return [n for n in _capturas_no_disco() if n != "original"]


# O aviso do FLAVOR × ACCENT só conhecia as capturas FOTOGRAFADAS, e com o
# Dracula isso é uma: o `dracula-mauve`.
_APLICAM_CACHE = {}


def _acentos_que_aplicam(esquema):
    item = next((i for i in esquema if i.get("chave") == "ACCENT"), None)
    acentos = [str(a) for a in (item or {}).get("opcoes") or []]
    mod = modulo_pack()
    if mod is None:
        return {}
    chave = [os.environ.get("MEOW_PACK_DIR", ""), os.environ.get("MEOW_PALETA", ""),
             ",".join(acentos)]
    try:
        chave.append(os.stat(mod.paleta_do_pack_ativo()).st_mtime_ns)
        for nome in mod.capturas():
            dir_cap = mod.captura(nome) or ""
            chave.append((nome, os.stat(os.path.join(dir_cap, "captura.txt")).st_mtime_ns
                          if os.path.isfile(os.path.join(dir_cap, "captura.txt")) else 0))
    except Exception:
        # Um pack de terceiro malformado não derruba o esquema inteiro: sem a
        # resposta, o cartão cai no aviso de antes (só as fotografadas).
        return {}
    chave = repr(chave)
    if chave not in _APLICAM_CACHE:
        try:
            r = subprocess.run(
                [sys.executable, os.path.join(RAIZ, "scripts", "derivar_acento.py"),
                 "--aplicam", ",".join(acentos)],
                cwd=RAIZ, capture_output=True, text=True, timeout=60)
            resposta = json.loads(r.stdout) if r.returncode == 0 else {}
        except (OSError, ValueError, subprocess.SubprocessError):
            return {}
        # A RESPOSTA VOLTA PELA VARIÁVEL, E NÃO PELO DICIONÁRIO: desde que o
        # `_aquecer` (no `main`) faz esta conta numa thread ao subir, o
        # primeiro `/api/esquema` pode fazê-la ao mesmo tempo; reler do
        # dicionário depois do `clear()` da outra thread daria `KeyError`.
        _APLICAM_CACHE.clear()
        _APLICAM_CACHE[chave] = resposta
        return resposta
    return _APLICAM_CACHE.get(chave, {})


# --- 3b. os acervos que moram no DISCO, e não no texto -----------------------
#
# O `_gatos()` acima é o modelo: a lista não está escrita em lugar nenhum, ela É
# a pasta.
#
# A ORDEM É A DA BUSCA DO XDG, e ela não é decoração: `~/.local/share/icons`
# vence `/usr/share/icons` para o mesmo nome, que é o que faz um tema instalado
# por ela mascarar o do sistema.
RAIZES_ICONES = ("~/.local/share/icons", "~/.icons", "/usr/share/icons")

# As duas linhas do `index.theme` que a especificação de ícones do freedesktop
# define, e que separam um tema de ícone de um tema de cursor ou de uma pasta de
# reserva. Ver `_temas_de_icones`, que explica o que cada uma tirou da lista.
RE_TEMA_PASTAS = re.compile(r"^\s*Directories\s*=\s*\S", re.I)
RE_TEMA_ESCONDIDO = re.compile(r"^\s*Hidden\s*=\s*true\s*$", re.I)


def _dirs_de_icones():
    """(nome, caminho) de todo diretório visível na busca de ícones do XDG."""
    for raiz in RAIZES_ICONES:
        caminho = os.path.expanduser(raiz)
        try:
            nomes = sorted(os.listdir(caminho))
        except OSError:
            continue
        for nome in nomes:
            completo = os.path.join(caminho, nome)
            if os.path.isdir(completo):
                yield nome, completo


@_uma_vez_por_leitura
def _temas_de_icones():
    """Os temas de ícones INSTALADOS — o que `ICONES_BASE` pode de fato herdar.

    O CRITÉRIO É O `index.theme`, E NÃO O NOME DA PASTA
        `/usr/share/icons` desta máquina tem 22 diretórios e nem todos são tema
        (`locolor` não tem `index.theme`; há até `.png` solto lá dentro). O
        arquivo `index.theme` é o que o GTK e o COSMIC procuram para decidir que
        aquilo é um tema — usar o mesmo teste é a única forma de a lista da
        página e a lista de quem desenha a tela serem a mesma lista.

    E DENTRO DELE, DUAS LINHAS QUE A ESPECIFICAÇÃO JÁ ESCREVEU PARA NÓS
        Só o `index.theme` não basta, e a primeira versão desta função provou:
        a lista saiu com `default` e `catppuccin-mocha-light-cursors` dentro —
        os dois são temas de CURSOR, e herdá-los como base de ícone daria uma
        árvore sem um ícone de aplicativo. O que os separa está no próprio
        arquivo, e é da especificação de ícones do freedesktop:

          Directories=   um tema de ícone é OBRIGADO a declarar as pastas de
                         tamanho que ele oferece. Tema de cursor não tem
                         nenhuma, e o `default` escrito pelo `cursor.sh` só tem
                         `Inherits=`. Medido nos oito casos de borda desta
                         máquina, é o corte exato.
          Hidden=true    é a palavra da própria especificação para "não ofereça
                         este numa lista de escolha". Tira o `hicolor` (a
                         hierarquia de reserva) e o `pop-os-branding` (logos do
                         sistema) — os dois apareciam na lista e escolher
                         qualquer um deixaria a máquina sem ícone.

        Tentei antes um teste mais óbvio — "tem uma pasta `apps/` dentro?" — e
        ele ERRA: `ePapirus` e `Papirus-Light` montam as pastas por link
        simbólico, então um `find` sem seguir links os declarava vazios e
        justamente os dois Papirus, que são a base natural aqui, sumiam da
        lista. A metadados se pergunta pelos metadados.

    O TEMA QUE NÓS CONSTRUÍMOS SAI DA LISTA, E ISSO É O QUE SEPARA DUAS CHAVES
        `NOME_TEMA_ICONES` e `ICONES_BASE` moram coladas no `meow.conf.exemplo`,
        sob UM comentário só — então a `ICONES_BASE` herda o bloco da vizinha e
        nenhuma regra de texto consegue distingui-las. O que as distingue é o
        sentido: `NOME_TEMA_ICONES` é o nome que este projeto CRIA (e que numa
        máquina limpa ainda não existe), e `ICONES_BASE` é um tema de terceiro
        que ele HERDA. Tirar o nosso da lista resolve os dois de uma vez: a base
        não pode ser o próprio tema (seria um `Inherits` em laço), e a chave que
        nomeia o nosso tema deixa de casar com a lista e continua texto livre,
        que é o certo — ela batiza uma pasta que ainda vai nascer.

        O nome sai da conf (exemplo + a dela, a última vence), nunca chumbado:
        renomear o tema move a exclusão junto.
    """
    nosso = valores_brutos().get("NOME_TEMA_ICONES", "")
    fora = set()
    for nome, caminho in _dirs_de_icones():
        if nome == nosso or nome in fora:
            continue
        try:
            with open(os.path.join(caminho, "index.theme"), "r",
                      encoding="utf-8", errors="replace") as fh:
                linhas = fh.read().splitlines()
        except OSError:
            continue
        if any(RE_TEMA_ESCONDIDO.match(l) for l in linhas):
            continue
        if any(RE_TEMA_PASTAS.match(l) for l in linhas):
            fora.add(nome)
    return sorted(fora)


# O sufixo que o `scripts/cursor.sh:189` acrescenta SEMPRE:
#     _cursor_nome_tema() { printf '%s-cursors' "$1"; }
SUFIXO_CURSOR = "-cursors"


# A pergunta "que pasta este valor abre?" estava escrita DUAS vezes neste
# arquivo, e as duas cópias envelheceram em datas diferentes: `_temas_de_cursor`
# aprendeu que o nome EXATO vence a convenção (foi o que trouxe o
# `Dracula-Cursor` para a lista) e `_prev_cursores` continuou montando
# `<valor>-cursors` sempre.
#
# Não era verdade duas vezes, e as duas custaram caro:
def _cursor_pastas_do_valor(valor, do_pack=None):
    """As pastas que o `cursor.sh` aceita para este valor, na ordem do XDG.

    `do_pack` é o `_ponteiro_do_pack()` já perguntado: quem percorre muitos
    valores pergunta UMA vez e passa, porque a pergunta roda o `bash` do conf.
    """
    raizes = [os.path.expanduser(raiz) for raiz in RAIZES_ICONES]
    # `_cursor_nome_tema`: o nome exato vence a convenção, e para vencer basta
    # o diretório existir — quem cobra o `cursors/` dentro é o passo seguinte.
    if any(os.path.isdir(os.path.join(raiz, valor)) for raiz in raizes):
        nome = valor
    else:
        nome = valor + SUFIXO_CURSOR
    # `_cursor_instalado`: a raiz que serve é a que tem `<nome>/cursors`.
    pastas = [os.path.join(raiz, nome) for raiz in raizes
              if os.path.isdir(os.path.join(raiz, nome, "cursors"))]
    # `_cursor_do_pack`: o valor é o do pack, e o nome não foi sequestrado.
    if (do_pack and do_pack.get("valor") == valor and nome == valor + SUFIXO_CURSOR
            and os.path.isdir(os.path.join(do_pack.get("dir") or "", "cursors"))):
        pastas.append(do_pack["dir"])
    return pastas


def _ponteiro_do_pack():
    """O ponteiro próprio do pack no ar, COMO O `cursor.sh` O VÊ — dict ou None.

    É O `_pack_adotado()`, LÁ EM CIMA, DESDE A P35 — 23/09/2026
        Até aqui esta função repetia a conta do `meow_pack_dir` (lib/comum.sh)
        à mão, e dizia por quê: o `_pack_adotado` traduzia o sabor para o pack
        que o declara e o shell não, então com `FLAVOR="alucard"` e `PACK=""`
        a tela ofereceria um ponteiro que o script não acha. Era a terceira
        cópia da mesma regra, escrita para não discordar da segunda. A regra
        agora é uma só, o `adocao` do `scripts/pack.py`, e o shell e o
        `_pack_adotado` perguntam a ela — a lista do painel continua sendo a do
        script, agora por construção.
    """
    mod = modulo_pack()
    if not mod or not hasattr(mod, "ponteiro"):
        return None
    try:
        return mod.ponteiro(_pack_adotado() or mod.dir_padrao())
    except Exception:
        return None


def _padrao_do_pack(chave):
    """O valor de fábrica que o PACK no ar escolhe para `chave`, ou None.

    O PONTEIRO DE FÁBRICA É O DO PACK — 10/10/2026, conferência da P79. A
    decisão 10 pôs o «Restaurar ao padrão» a gravar o de fábrica, e o de fábrica
    do `CURSOR` no exemplo é o `catppuccin-mocha-light`: com o Dracula no ar, o
    botão nascia sobre o `Dracula-Cursor` e gravava o ponteiro do OUTRO pack —
    o mesmo resto que a troca de pack (item 4) acabou de ensinar a levar junto.
    A régua é a do `migrar_conf.py` (`vestigios`): o ponteiro que o pack traz,
    ou, sem um, o do exemplo. Só o `CURSOR` tem essa forma hoje."""
    if chave != "CURSOR":
        return None
    return (_ponteiro_do_pack() or {}).get("valor") or None


def _ponteiro_vem_do_pack(valor):
    """True quando o CURSOR escolhido é o ponteiro que o pack no ar traz. [P51]"""
    do_pack = _ponteiro_do_pack() if valor else None
    return bool(do_pack) and do_pack.get("valor") == valor


@_uma_vez_por_leitura
def _temas_de_cursor():
    """Os valores que a chave `CURSOR` aceita — nem um a mais que isso.

    O QUE A PÁGINA OFERECIA, E O QUE ACONTECIA AO CLICAR — medido em 01/09/2026
        A lista anterior era "todo diretório com uma pasta `cursors/` dentro",
        mais um apelido curto como SEGUNDA opção clicável. Nesta máquina isso
        dava quatro botões, e só um deles funcionava:

            catppuccin-mocha-light-cursors  -> procura `…-cursors-cursors`  ✗
            catppuccin-mocha-light          -> procura `…-light-cursors`    ✓
            Adwaita                         -> procura `Adwaita-cursors`    ✗
            Pop                             -> procura `Pop-cursors`        ✗

        Os três com ✗ não dão erro na tela: o `cursor.sh` conclui que o tema não
        está instalado e vai BAIXAR `<valor>-cursors.zip` do release fixado do
        `catppuccin/cursors` — que para `Adwaita` não existe. Ou seja, um clique
        num ponteiro que ela tem instalado tentava a rede e falhava.

    A REGRA DE 01/09, DERIVADA DO SCRIPT E DO DISCO — o parágrafo seguinte
    conta o dia em que ela caiu
        O `cursor.sh` resolvia `<valor>-cursors/cursors/` nas três raízes de
        ícone (`_cursor_instalado`, cursor.sh:302). Então o valor válido era o
        nome do diretório MENOS o sufixo — e um diretório que não terminasse em
        `-cursors` não era escolhível por esta chave, por mais que tivesse
        ponteiros dentro. Nada de lista fixa, e isso não mudou: instale outro
        tema `<x>-cursors` e ele aparece.

        `set` e não lista: o mesmo tema pode estar em duas raízes, e oferecer o
        mesmo nome duas vezes é o defeito que esta função veio consertar.

    A PREMISSA DE 01/09 CAIU EM 15/09, E ESTA LISTA SEGUIA NELA
        O texto acima diz que um diretório sem `-cursors` "simplesmente não é
        escolhível por esta chave". Era verdade enquanto `_cursor_dir_tema`
        montava o caminho SEMPRE por convenção. Em 15/09 o `cursor.sh` ganhou
        `_cursor_dir_exato`: se existe pasta com o nome EXATO em alguma raiz,
        ela é o tema, e só sem isso vale a convenção. Foi o que fez
        `CURSOR="Dracula-Cursor"` funcionar — o tema instala `Dracula-Cursor`,
        sem `-s` e sem sufixo.

        A lista não acompanhou: o `Dracula-Cursor` estava instalado nas DUAS
        raízes, o `meow.conf` já apontava para ele, e a tela oferecia só o
        Catppuccin. Quem olhasse a interface concluiria que o ponteiro do tema
        não tinha sido trazido.

        Agora a regra é a mesma dos dois lados: entra quem o `cursor.sh` sabe
        resolver — por nome exato OU por convenção. A diferença é que isso é
        consequência da regra, não de um filtro de texto que envelheceu.

    E O ADWAITA ENTROU — ESTE DOCSTRING DIZIA QUE NÃO, ATÉ 21/09/2026
        O parágrafo acima terminava, até hoje, afirmando duas vezes que "o
        Adwaita continua fora, pelo motivo de sempre: escolhê-lo faria o script
        procurar `Adwaita-cursors`, não achar, e tentar baixar da rede". Era o
        texto de 01/09 sobrevivendo à mudança de 15/09 — o MESMO defeito que
        esta função já cometeu uma vez ("A lista não acompanhou"), só que agora
        no comentário em vez do código, que é como ele volta.

        Medido em 21/09, chamando esta função: `['Adwaita', 'Dracula-Cursor',
        'Pop', 'catppuccin-mocha-light']`. Adwaita e Pop estão na lista desde
        15/09, e escolhê-los NÃO toca a rede: o `_cursor_instalado` acha
        `/usr/share/icons/Adwaita` e `/usr/share/icons/Pop` pelo nome exato,
        com `cursors/` dentro — rodado com as funções do próprio script.

    E O `cursor.sh listar` FICOU PARA TRÁS ATÉ A P35 — 23/09/2026
        O script que aplica continuava listando só as pastas `-cursors`: nesta
        máquina, `catppuccin-mocha-light` contra os quatro daqui, e fora da
        lista dele o `Dracula-Cursor` que o meow.conf usa. Agora ele propõe e
        peneira como esta função — cada pasta com `cursors/` propõe um valor, e
        a resolução decide —, ordena como o `sorted()` daqui, e o pack do
        ponteiro sai da mesma adoção (`_ponteiro_do_pack`). O `tests/pack.sh`
        roda os dois no mesmo HOME de brinquedo e compara a lista inteira, na
        ordem.
    """
    fora = set()
    do_pack = _ponteiro_do_pack()
    # O PONTEIRO DO PACK PROPÕE O VALOR DELE, ANTES DE ESTAR NO DISCO. Ele
    # não está em diretório de ícone nenhum até a primeira instalação, e a
    # varredura abaixo nunca o veria. A peneira é a mesma.
    if do_pack and _cursor_pastas_do_valor(do_pack["valor"], do_pack):
        fora.add(do_pack["valor"])
    for nome, caminho in _dirs_de_icones():
        if not os.path.isdir(os.path.join(caminho, "cursors")):
            continue
        # Convenção do Catppuccin: a pasta `<x>-cursors` propõe o valor `<x>`
        # (o `aplicar` acrescenta o sufixo de volta). Pasta sem sufixo propõe o
        # próprio nome,.
        valor = nome[: -len(SUFIXO_CURSOR)] if nome.endswith(SUFIXO_CURSOR) else nome
        if _cursor_pastas_do_valor(valor, do_pack):
            fora.add(valor)
    return sorted(fora)


def _paredes_ativas():
    """Os CAMINHOS das imagens em `ativos/` — é o que `wallpaper banir` recebe.

    `cmd_banir` (wallpaper.sh:1602) começa com `[ -f "$img" ]`: o argumento dele
    é um arquivo, não um nome. E tem de ser o de `ativos/`, não o do link duro em
    `ativos-noite/` ou `ativos-dia/` — banir pelo link move só o link e deixa o
    original girando, que é um banimento pela metade e mudo.
    """
    base = os.path.join(_wallpaper_base(), "ativos")
    try:
        nomes = sorted(os.listdir(base))
    except OSError:
        return []
    return [os.path.join(base, n) for n in nomes
            if os.path.splitext(n)[1].lower() in EXT_RASTER
            and os.path.isfile(os.path.join(base, n))]


def _paredes_favoritas():
    """Os NOMES das imagens em `favoritos/` — é o que `wallpaper desfavoritar`
    recebe (P79, 10/10/2026). Nome, e não caminho, como as banidas."""
    base = os.path.join(_wallpaper_base(), "favoritos")
    try:
        nomes = sorted(os.listdir(base))
    except OSError:
        return []
    return [n for n in nomes if os.path.splitext(n)[1].lower() in EXT_RASTER
            and os.path.isfile(os.path.join(base, n))]


def _paredes_banidas():
    """Os NOMES das imagens em `banidos/` — é o que `wallpaper desbanir` recebe.

    Aqui é o oposto do `banir`, e é o próprio script quem diz: `cmd_desbanir`
    faz `basename` no que recebe e procura em `banidos/`, dizendo em voz alta
    "o nome é o do ARQUIVO, sem caminho". São 255 nesta máquina, e nenhuma foi
    apagada — banir move, nunca remove.
    """
    base = os.path.join(_wallpaper_base(), "banidos")
    try:
        nomes = sorted(os.listdir(base))
    except OSError:
        return []
    return [n for n in nomes
            if os.path.splitext(n)[1].lower() in EXT_RASTER
            and os.path.isfile(os.path.join(base, n))]


# A tabela é a do `scripts/migrar_conf.py` (`RENOMEADAS`), lida de lá por
# caminho, pelo mesmo motivo e do mesmo jeito que o `modulo_pack`: uma
# segunda tabela aqui discordaria da primeira no dia da segunda troca.
_MIGRAR_MOD = None


def chaves_renomeadas():
    """{antigo: novo}, ou {} se o `migrar_conf.py` não puder ser carregado."""
    global _MIGRAR_MOD
    if _MIGRAR_MOD is None:
        import importlib.util
        alvo = os.path.join(RAIZ, "scripts", "migrar_conf.py")
        try:
            spec = importlib.util.spec_from_file_location("meow_migrar_conf", alvo)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            _MIGRAR_MOD = mod
        except Exception:
            _MIGRAR_MOD = False
    return dict(getattr(_MIGRAR_MOD, "RENOMEADAS", None) or {})


def _nome_antigo_valendo():
    """{novo: antigo} das chaves que o meow.conf só tem pelo nome antigo."""
    nomes = set()
    try:
        with open(CONF, "r", encoding="utf-8") as fh:
            for linha in fh:
                linha = linha.strip()
                if linha.startswith("export "):
                    linha = linha[len("export "):]
                achado = RE_CHAVE.match(linha)
                if achado:
                    nomes.add(achado.group(1))
    except OSError:
        return {}
    return {novo: antigo for antigo, novo in chaves_renomeadas().items()
            if antigo in nomes and novo not in nomes}


@_uma_vez_por_leitura
def valores_brutos():
    """O valor CRU de cada chave no meow.conf dela, caindo no exemplo quando falta.

    Cru, e não expandido, pelo motivo que o `wiz_bruto` do `bin/meow` explica:
    `ICONES_PASTAS="cat-${FLAVOR}-${ACCENT}"` vale JUSTAMENTE por não estar
    expandido, e gravar a expansão congelaria a chave no flavor de hoje.
    """
    valores = {}
    for arquivo in (CONF_PADRAO, CONF):     # o dela por último: ela vence
        try:
            with open(arquivo, "r", encoding="utf-8") as fh:
                for linha in fh:
                    linha = linha.strip()
                    if linha.startswith("export "):
                        linha = linha[len("export "):]
                    achado = RE_CHAVE.match(linha)
                    if achado:
                        # A ÚLTIMA atribuição vence, que é o que o `.` do shell faz.
                        valores[achado.group(1)] = _valor_da_linha(linha)
        except OSError:
            continue
    # O valor de quem só tem o nome antigo aparece pelo novo — ver acima.
    for novo, antigo in _nome_antigo_valendo().items():
        valores[novo] = valores.get(antigo, "")
    return valores


@_uma_vez_por_leitura
def valores_efetivos(chaves):
    """O valor DEPOIS de o shell expandir — é o que os scripts de fato recebem.

    Uma chamada só ao bash, com `set -a` em volta do `.`, que é exatamente o que
    o `carregar_conf` do `bin/meow` e o `etapa_conf_ler` do `install.sh` fazem.
    Reimplementar a expansão de `${FLAVOR}` em Python seria a segunda verdade
    sobre o valor de uma chave, e ela discordaria no primeiro caso esquisito.
    """
    if not chaves:
        return {}
    # O nome antigo vai junto na pergunta, e a resposta dele volta pelo novo —
    # mesma regra do `valores_brutos`.
    antigos = {n: a for n, a in _nome_antigo_valendo().items() if n in chaves}
    programa = (
        'set -a\n'
        '[ -f "$1" ] && . "$1"\n'
        '[ -f "$2" ] && . "$2"\n'
        'set +a\n'
        'shift 2\n'
        'for k in "$@"; do printf "%s=%s\\0" "$k" "${!k-}"; done\n'
    )
    try:
        saida = subprocess.run(
            ["bash", "-c", programa, "_", CONF_PADRAO, CONF, *chaves, *antigos.values()],
            capture_output=True, timeout=20,
        ).stdout.decode("utf-8", "replace")
    except (OSError, subprocess.SubprocessError):
        return {}
    fora = {}
    for pedaco in saida.split("\0"):
        if "=" in pedaco:
            k, v = pedaco.split("=", 1)
            fora[k] = v
    for novo, antigo in antigos.items():
        fora[novo] = fora.pop(antigo, fora.get(novo, ""))
    return fora


def conf_exportada(fonte=None):
    """As chaves do meow.conf como um script as recebe do `bin/meow`, ou None.

    `fonte` é o arquivo a ler; vazio quer dizer "o dela, ou o exemplo quando ela
    ainda não tem um". Quem passa outro é o ensaio do «Salvar e aplicar», que lê
    a CÓPIA descartável com as escolhas pendentes dentro (ver `_conf_de_ensaio`).
    Sem este parâmetro o ensaio resolveria a ponte (MEOW_PALETA/MEOW_PACK_DIR) a
    partir do PACK/FLAVOR do disco enquanto o `install.sh` lia os da cópia — o
    par incoerente que o bloco "A PONTE VEM JUNTO" abaixo existe para matar,
    entrando de novo pela porta do ensaio.

    A CONF VAI JUNTO COM O TRABALHO — 13/09/2026
      Os trabalhos do painel herdavam o ambiente do servidor e mais nada. Para o
      `install.sh` e o `bin/meow` isso não pesa — os dois leem o meow.conf
      sozinhos —, mas as ações que chamam um script de `scripts/` direto rodavam
      com o padrão de cada chave. Medido pela interface: «Usar este ícone» rodou
      o `icones_apps_arcticons.sh` sem `ICONES_COR_MARCA`, doze ícones da máquina
      dela voltaram à cor de categoria, o painel foi reciclado para mostrá-los, e
      a gaveta disse "os ícones novos já estão na dock e no menu".

      A leitura é a do `carregar_conf` (bin/meow) e a do `etapa_conf_ler`
      (install.sh): UM arquivo — o dela, ou o exemplo quando ele não existe —,
      com `set -a` em volta do `.`, e os quatro padrões que os dois dão depois.
      Os nomes saem do próprio arquivo: uma lista escrita aqui seria a armadilha
      nº 3 de novo, a lista que alguém esquece de estender.

      None quer dizer "não consegui ler", e aí o trabalho NÃO roda: rodar com as
      chaves no padrão é exatamente o defeito que esta função existe para curar.

    A PONTE VEM JUNTO, E PELO MESMO MOTIVO — 22/09/2026
      O `app/run.sh` chama o `meow_ponte_python` na SUBIDA do servidor, e o
      `_ambiente_do_painel` é `dict(os.environ, ...)`: sem as linhas abaixo, todo
      trabalho herdava o `MEOW_PALETA` do INSTANTE DA SUBIDA. Esta função já
      relia FLAVOR e PACK do conf fresco e não mexia na paleta — então trocar o
      FLAVOR na tela e clicar «Instalar tudo» mandava o `install.sh` com FLAVOR
      novo e paleta velha. Medido no dia: a paleta saindo do `catppuccin.json`
      embutido com o `MEOW_PACK_DIR` apontando para `packs/dracula`, o
      `gerar_temas.py` morrendo em "flavor 'dracula' desconhecido", o
      `etapa_gerar` caindo em FALHOS e o instalador seguindo — a «metade Nord,
      metade Catppuccin» que a P20 existe para matar, entrando pela porta do
      painel.

      QUEM RESOLVE É A MESMA FUNÇÃO DE SEMPRE, e não uma segunda cópia em
      Python: o bash abaixo carrega o `lib/comum.sh` DEPOIS do `.` do conf, de
      modo que a ponte vê o PACK/FLAVOR recém-lidos. Uma resolução escrita aqui
      seria a armadilha nº 3 de novo — duas versões da mesma regra, e a que
      discordasse não daria erro.

      QUANDO A PONTE RECUSA, O QUE SAI VAZIO É SÓ O QUE ELA MESMA PÔS — e o
      trabalho RODA assim mesmo. Vazio é o mesmo sinal que "ninguém exportou": o
      shell cai no `meow_paleta` e o Python no embutido. Devolver None aqui
      travaria o painel inteiro — inclusive o «Desfazer» e o «Conferir a
      máquina» — por causa de um arquivo de cor, que é o oposto do que o
      `install.sh` decidiu ao pôr a ponte depois do desinstalar.

      Um `MEOW_PALETA` que seja DA PESSOA atravessa intacto, mesmo quebrado: ele
      é a escolha dela, e quem tem de recusá-lo, nomeando o arquivo, é o
      `install.sh` — no log que ela está olhando, e não aqui, calado.
    """
    fonte = fonte or (CONF if os.path.isfile(CONF) else CONF_PADRAO)
    nomes = []
    try:
        with open(fonte, "r", encoding="utf-8") as fh:
            for linha in fh:
                linha = linha.strip()
                if linha.startswith("export "):
                    linha = linha[len("export "):]
                achado = RE_CHAVE.match(linha)
                if achado and achado.group(1) not in nomes:
                    nomes.append(achado.group(1))
    except OSError:
        return None
    # O `$2` é a RAIZ.
    programa = (
        'set -a\n'
        '. "$1" || exit 2\n'
        'set +a\n'
        'export MEOW_RAIZ="$2"\n'
        '. "$MEOW_RAIZ/lib/comum.sh" >/dev/null 2>&1 || true\n'
        'FLAVOR="$(meow_flavor 2>/dev/null)"; ACCENT="${ACCENT:-mauve}"\n'
        'meow_pastas_do_molde 2>/dev/null || true\n'
        'MODO="${MODO:-escuro}"; LOGO="${LOGO:-$FLAVOR}"\n'
        'if ! meow_ponte_python >/dev/null 2>&1; then\n'
        '  if [ "${MEOW_PALETA:-}" = "${MEOW_PALETA_DA_PONTE:-}" ]; then\n'
        '    MEOW_PALETA=""; MEOW_PACK_DIR=""; MEOW_PALETA_DA_PONTE=""\n'
        '  fi\n'
        'fi\n'
        'shift 2\n'
        'for k in "$@"; do printf "%s=%s\\0" "$k" "${!k-}"; done\n'
    )
    # As três da ponte vão na MESMA lista de nomes: o `${!k-}` do laço acima as
    # colhe como colhe qualquer chave do conf, e o chamador as recebe já prontas
    # para o `ambiente.update(conf)`.
    da_ponte = ["MEOW_PALETA", "MEOW_PACK_DIR", "MEOW_PALETA_DA_PONTE"]
    try:
        feito = subprocess.run(
            ["bash", "-c", programa, "_", fonte, RAIZ,
             *nomes, "FLAVOR", "ACCENT", "MODO", "LOGO", *da_ponte],
            capture_output=True, timeout=20,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if feito.returncode != 0:
        return None
    fora = {}
    for pedaco in feito.stdout.decode("utf-8", "replace").split("\0"):
        if "=" in pedaco:
            k, v = pedaco.split("=", 1)
            fora[k] = v
    return fora


# --- A CERCA CONTRA SUBSTITUIÇÃO DE COMANDO [2026-09-18] ---------------------
#
# Deixava passar `$( )`, crase e `${ }`. E o meow.conf é SOURCEADO com `set -a;
# . conf` por install.sh:145 e bin/meow:174 — então um valor gravado assim:
#
# não é texto: é comando que roda no próximo `meow ativar`, no `install.sh` que
# o próprio botão «Salvar e aplicar» dispara, ou no doctor das 05:00.
#
#   A expansão de variável é FEATURE DECLARADA, e o projeto pede que ela seja
#   usada. meow.conf.exemplo:478 diz, na ajuda que a pessoa lê na tela:
#       "Deixe escrito com ${FLAVOR} e ${ACCENT} para acompanhar o tema sozinho."
#   e a linha 945 tem WALLPAPER_BASE="$HOME/.local/share/backgrounds/meowsystem".
#   Recusar `$` quebraria as duas e tiraria uma funcionalidade documentada.
_VAR_SIMPLES = re.compile(r"\$(?:\{[A-Za-z_][A-Za-z0-9_]*\}|[A-Za-z_][A-Za-z0-9_]*)")


def expansao_perigosa(valor):
    """A frase da recusa quando o valor executaria comando no `source`; None quando não.

    Devolve frase, e não booleano, porque quem chama imprime a frase na tela — e
    uma recusa que não diz o que fazer é uma recusa que a pessoa contorna
    editando o arquivo à mão, que é pior.
    """
    if "`" in valor:
        return ("o valor não pode ter crase: no meow.conf ela vira execução de "
                "comando. Para o texto de uma cor ou de um nome, tire as crases.")
    # Consome toda expansão de variável BEM formada; o que sobrar de `$` é suspeito.
    resto = _VAR_SIMPLES.sub("", valor)
    if "$" in resto:
        return ("o valor só aceita `$NOME` ou `${NOME}` — as outras formas de `$` "
                "(como `$(...)`) viram execução de comando quando o meow.conf é lido.")
    return None


# O 32 da régua é o teto de quando o compositor ainda media pela caixa do frame
# anterior (`altura/2`), e não o de hoje.
#
# O TETO É UMA CONTA SÓ, E ELA MORA NO `lib/painel.sh`: é a que o `forma.sh`
# usa para cortar.
_TETO_CACHE = {"quando": 0.0, "valor": None}
_BARRA_DO_RAIO = {"FORMA_RAIO_PAINEL": "Panel", "FORMA_RAIO_DOCK": "Dock"}


def teto_do_raio():
    """O que o `lib/painel.sh` diz agora: {"Panel": n, "Dock": n,
    "compositor": "clampa"|"pendente"|"sem", "experimental": bool}.

    A barra que não tem pasta no COSMIC não entra (uma casa sem painel não tem
    teto a dizer). Falhar a pergunta devolve {}: sem teto conhecido, a página
    desenha a régua do exemplo, como antes."""
    agora = time.time()
    if _TETO_CACHE["valor"] is not None and agora - _TETO_CACHE["quando"] < 30:
        return _TETO_CACHE["valor"]
    fonte = CONF if os.path.isfile(CONF) else CONF_PADRAO
    programa = (
        'set -a; . "$2"; set +a\n'
        '. "$1/lib/comum.sh"; . "$1/lib/painel.sh"\n'
        'printf "experimental\\t%s\\n" "${FORMA_RAIO_EXPERIMENTAL-}"\n'
        'for b in Panel Dock; do\n'
        '  d="$MEOW_PAINEL_BASE/com.system76.CosmicPanel.$b/v1"\n'
        '  [ -d "$d" ] || continue\n'
        '  t="$(meow_painel_teto "$d" 2>/dev/null)" || continue\n'
        '  printf "%s\\t%s\\n" "$b" "$t"\n'
        'done\n'
        'if meow_painel_compositor_clampa; then printf "compositor\\tclampa\\n"\n'
        'elif meow_painel_patch_pendente; then printf "compositor\\tpendente\\n"\n'
        'else printf "compositor\\tsem\\n"; fi\n'
    )
    valor = {}
    try:
        saida = subprocess.run(["bash", "-c", programa, "_", RAIZ, fonte],
                               capture_output=True, timeout=10,
                               env=_ambiente_do_painel()).stdout.decode("utf-8", "replace")
    except (OSError, subprocess.SubprocessError):
        saida = ""
    for linha in saida.splitlines():
        nome, _, v = linha.partition("\t")
        if nome in ("Panel", "Dock") and v.isdigit():
            valor[nome] = int(v)
        elif nome == "compositor" and v in ("clampa", "pendente", "sem"):
            valor["compositor"] = v
        elif nome == "experimental":
            valor["experimental"] = v in ("sim", "true", "1")
    if "compositor" not in valor:
        valor = {}
    _TETO_CACHE["quando"], _TETO_CACHE["valor"] = agora, valor
    return valor


def teto_da_chave(chave):
    """O teto de UMA chave de raio, em dado: {"valor", "trava", "motivo"}, ou
    None quando a chave não é de raio ou a barra não tem teto conhecido."""
    barra = _BARRA_DO_RAIO.get(chave)
    medida = teto_do_raio() if barra else {}
    if not barra or barra not in medida:
        return None
    t = medida[barra]
    acima = ("qualquer canto arredondado" if t == 0
             else "um canto acima de %d px" % t)
    if medida["compositor"] == "clampa":
        return {"valor": None, "trava": False, "estado": "clampa",
                "motivo": "o compositor desta sessão corta o excesso sozinho, "
                          "e o raio é todo seu"}
    if medida.get("experimental"):
        return {"valor": t, "trava": False, "estado": "experimental",
                "motivo": "modo experimental ligado (FORMA_RAIO_EXPERIMENTAL): "
                          "%s pode derrubar painel e dock juntos" % acima}
    if medida["compositor"] == "pendente":
        porque = ("o patch do raio já está instalado, mas só vale no próximo "
                  "login; até lá, %s derruba painel e dock juntos" % acima)
    else:
        porque = ("o compositor desta sessão não tem o patch do raio, e %s "
                  "derruba painel e dock juntos" % acima)
    # O `estado` é para a página escolher o selo sem ler a frase: a frase
    # vira balão curto, e o porquê inteiro continua aqui e na recusa.
    return {"valor": t, "trava": True, "motivo": porque, "estado": medida["compositor"]}


def validar_valor(item, valor):
    """None quando o valor cabe na chave; a frase da recusa quando não cabe.

    POR QUE ISTO EXISTE — 01/09/2026
        `/api/definir` conferia só o NOME da chave: se ela estava no esquema,
        o valor ia para o disco fosse ele qual fosse. A auditoria mediu quatro
        no navegador, todos aceitos sem uma palavra na tela:

            FORMA_RAIO_PAINEL="banana"     ESCALA_TELA="gigante"
            BACKUPS_MANTIDOS="abc"         VIDRO_OPACIDADE_PAINEL="999"

        O estrago não aparece aqui: aparece de madrugada, quando o
        `meow doctor --consertar` das 05:00 tropeça no valor e erra todo dia, ou
        na hora em que o `escala.sh` sai com erro e ninguém liga o erro ao
        clique de três dias antes. Um valor que o outro lado não sabe ler tem de
        ser recusado no momento em que foi digitado, com a frase que diz o que
        se esperava.

    E A CERCA É O PRÓPRIO ESQUEMA, NUNCA UMA TABELA À PARTE
        Tudo que ela confere já estava sendo lido do `meow.conf.exemplo` para
        desenhar o controle: as opções, a faixa, o horário, a forma do número.
        Quem desenha um deslizante de 1000 a 6500 já sabe recusar 9000 — só
        faltava perguntar. Chave nova ganha a cerca junto com o controle, no
        mesmo dia, sem ninguém vir aqui.

    O VAZIO PASSA SEMPRE, e é decisão, não esquecimento: vazio é a forma que
    este projeto inteiro usa para dizer "não mexa" (`${VAR:-}` em todo script), e
    recusá-lo tiraria dela o gesto de desistir de uma chave. Onde vazio não faz
    sentido, quem reclama é o script, com a mensagem dele.
    """
    if valor == "":
        return None

    fechadas = _opcoes_fechadas(item["chave"], item["ajuda"], item["inline"],
                                item["padrao"])
    if item["chave"] == "FLAVOR" and fechadas:
        fechadas = _flavors_dos_packs() or fechadas
    # O «THEME PACK» CERCA PELOS PACKS DO DISCO: é o que a página passou a
    # oferecer (bloco 5 do `_com_o_vocabulario_do_pack`). Um id que não existe
    # não é recusado por ninguém lá adiante: o `adocao` veste o padrão, calado.
    if item["chave"] == "PACK":
        fechadas = sorted(_packs_no_disco()) or fechadas
    if fechadas and valor not in fechadas:
        return "%s aceita %s" % (item["chave"], " | ".join(fechadas))

    # Quando a lista era de durações, ela virou sugestão lá em cima — e o que
    # confere aqui é a FORMA: número mais unidade. `10m` passa, `banana` não.
    if (not fechadas and item["opcoes"]
            and all(RE_DURACAO.match(o) for o in item["opcoes"])):
        if not RE_DURACAO.match(valor):
            return ("%s é uma duração: número e unidade (30s, 5m, 2h, 1d)"
                    % item["chave"])
        return None

    if item["horario"] and not RE_HORARIO_VALOR.match(valor):
        return "%s é um horário no formato HH:MM (07:30)" % item["chave"]

    if item["faixa"]:
        lo, hi, _passo = item["faixa"]
        # Medido do jeito mais direto que existe: exportei o `meow.conf` DELA
        # pela própria página e reimportei o MESMO arquivo. A página propunha o
        # que este validador respondia com 400.
        if valor == item["padrao"] and valor in _PALAVRAS_COM_FAIXA:
            return None
        try:
            n = float(valor.replace(",", "."))
        except ValueError:
            return "%s é um número entre %s e %s" % (item["chave"], lo, hi)
        if not (lo <= n <= hi):
            return "%s vai de %s a %s — %s está fora" % (item["chave"], lo, hi, valor)
        # Gravar o que vai ser cortado é gravar como se valesse.
        teto = teto_da_chave(item["chave"])
        if teto and teto["trava"] and n > teto["valor"]:
            return "o teto agora é %d px: %s" % (teto["valor"], teto["motivo"])
        return None

    # A cerca contra substituição de comando vale para TODA chave, e fica aqui
    # de propósito: `/api/definir`, `/api/salvar` e `importar_conf` passam por
    # `validar_valor`, então uma cerca só cobre as três portas.
    perigo = expansao_perigosa(valor)
    if perigo:
        return "%s: %s" % (item["chave"], perigo)

    # A forma do número só vale quando não há lista nem faixa dizendo mais.
    if item["tipo_numero"]:
        for nome, forma, explica in FORMAS_NUMERO:
            if nome == item["tipo_numero"]:
                if not forma.match(valor):
                    return "%s espera %s" % (item["chave"], explica)
                break
    return None


# Até aqui a página mandava `seco` e este arquivo punha `MEOW_DRY_RUN=1` no
# ambiente de quem grava e de quem roda.
PONTAS_DA_NOITE = ("NOITE_INICIO", "NOITE_FIM")


def pontas_da_noite_soltas(escolhas, brutos=None):
    """A queixa (uma por ponta escrita) quando `escolhas` deixa a noite com uma
    ponta só; lista vazia quando ela fica com as duas ou com nenhuma."""
    if not any(c in escolhas for c in PONTAS_DA_NOITE):
        return []
    final = dict(valores_brutos() if brutos is None else brutos)
    final.update(escolhas)
    cheias = [c for c in PONTAS_DA_NOITE if str(final.get(c, "")).strip()]
    if len(cheias) != 1:
        return []
    return [{"chave": cheias[0],
             "erro": "a noite pede as duas pontas, começo e fim, ou nenhuma"}]


def _ambiente_do_painel(seco=False):
    ambiente = dict(os.environ, MEOW_RAIZ=RAIZ)
    ambiente.pop("MEOW_DRY_RUN", None)
    if seco:
        ambiente["MEOW_DRY_RUN"] = "1"
    return ambiente


def definir_varias(pares, conf=None):
    """Grava várias chaves pelo `meow_conf_definir`, num processo só.

    Devolve `[(chave, rc, saída)]` na ordem pedida: 0 já estava · 1 escreveu ·
    2 falhou. Um nome ou um valor recusado não chega ao bash — e aí NADA é
    gravado: metade das escolhas no disco seria pior que nenhuma.

    `conf` é um meow.conf OUTRO que não o dela, e vira `MEOW_CONF` para o bash —
    o mesmo override que o `lib/comum.sh:608` e o `install.sh:70` já respeitam.
    Quem usa é o ensaio do «Salvar e aplicar», que grava as escolhas numa CÓPIA
    descartável. A gravação é feita POR AQUI, e não por um `printf` no fim do
    arquivo, justamente porque é a mesma função que o Salvar de verdade vai
    chamar depois: um ensaio que escrevesse a chave de um jeito e a gravação de
    outro responderia sobre um arquivo que nunca vai existir.

    UM BASH PARA TODAS, E NÃO UM POR CHAVE — 13/09/2026
      Cada gravação custava 0,45 s (medido em 06/09: sobe um bash, carrega o
      `lib/comum.sh`, reescreve os 55 KB do conf), e o Salvar fazia uma por
      escolha, em fila, antes de começar a aplicar. Aqui a lib carrega uma vez e
      as escritas saem em sequência no MESMO processo, pela MESMA função; o que
      deixa de se multiplicar é só o custo de subir o bash."""
    for chave, valor in pares:
        if not RE_CHAVE.match(chave + "="):
            return [(chave, 2, "nome de chave inválido")]
        # `#` e `"` no valor quebrariam a linha do conf — é a mesma recusa que o
        # wizard já faz, e o cabeçalho de `lib/comum.sh` explica o limite: a
        # função parte a linha no primeiro `#`, então um valor com `#` viraria
        # comentário.
        if '"' in valor or "#" in valor or "\n" in valor:
            return [(chave, 2, 'o valor não pode conter aspas, `#` nem quebra de linha')]
        # Defesa em profundidade: `validar_valor` já barra isto antes de chegar
        # aqui, mas esta é a última porta antes do disco, e quem escrever um
        # caminho novo até ela não deve conseguir furar a cerca por esquecimento.
        perigo = expansao_perigosa(valor)
        if perigo:
            return [(chave, 2, perigo)]
    if not pares:
        return []
    # O código de cada escrita sai numa linha-marca própria, logo depois do que
    # a função imprimiu: é o que permite dizer QUAL chave recusou sem rodar um
    # bash por chave.
    programa = ('. "$1/lib/comum.sh"; shift; '
                'while [ $# -ge 2 ]; do '
                'meow_conf_definir "$1" "$2"; r=$?; '
                'printf "\\n@@meow-rc %s %s\\n" "$1" "$r"; '
                'shift 2; done')
    argv = ["bash", "-c", programa, "_", RAIZ]
    for chave, valor in pares:
        argv += [chave, valor]
    ambiente = _ambiente_do_painel()
    if conf:
        ambiente["MEOW_CONF"] = conf
        # `conf` só existe no caminho do ensaio: é a cópia descartável de
        # `_conf_de_ensaio`.
        #
        # Era o caso, e a cura é esta linha: o estado vai para a MESMA pasta
        # descartável, e morre com ela.
        ambiente["MEOW_ESTADO"] = os.path.dirname(conf)
    try:
        proc = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              timeout=30 + 5 * len(pares), env=ambiente)
    except (OSError, subprocess.SubprocessError) as erro:
        return [(chave, 2, str(erro)) for chave, _valor in pares]
    saida = proc.stdout.decode("utf-8", "replace")
    achados, trecho = {}, []
    for linha in saida.split("\n"):
        partes = linha.split(" ")
        if len(partes) == 3 and partes[0] == "@@meow-rc" and partes[2].isdigit():
            achados[partes[1]] = (int(partes[2]), "\n".join(trecho).strip())
            trecho = []
        else:
            trecho.append(linha)
    sem_resposta = (2, saida.strip() or "o bash saiu sem dizer o que gravou")
    return [(chave,) + achados.get(chave, sem_resposta) for chave, _valor in pares]


def definir(chave, valor):
    """Grava UMA chave pelo `meow_conf_definir` do projeto. 0 já estava · 1 escreveu."""
    _chave, rc, saida = definir_varias([(chave, valor)])[0]
    return (rc, saida)


# `MEOW_CONF` é o override de sempre, e ele já é respeitado em todo lugar que
# importa: `install.sh:70`, `lib/comum.sh:608` (e por tabela todo script de
# `scripts/` que sourceia a lib), `bin/meow:116` e o `scripts/gerar_temas.py`.
#
# O meow.conf é o retrato da máquina dela — um `/tmp/xxx.conf` legível por
# qualquer conta seria um vazamento novo criado por um botão que promete não
# escrever nada.
def _conf_de_ensaio(pares):
    """Uma cópia descartável do meow.conf com `pares` dentro. Devolve (dir, erro).

    Quem apaga o diretório é o `Trabalho` quando o ensaio termina (o
    `ao_terminar` do `iniciar`) — deixá-lo para o fim do processo faria o painel
    acumular um retrato da máquina dela por clique em «Ver sem mudar»."""
    fonte = CONF if os.path.isfile(CONF) else CONF_PADRAO
    try:
        pasta = tempfile.mkdtemp(prefix="meow-ensaio-")
        destino = os.path.join(pasta, "meow.conf")
        shutil.copyfile(fonte, destino)
    except OSError as erro:
        return (None, "não consegui preparar o ensaio: %s" % erro)
    for chave, rc, saida in definir_varias(pares, conf=destino):
        if rc == 2:
            shutil.rmtree(pasta, ignore_errors=True)
            return (None, "%s: %s" % (chave, saida or "não consegui gravar no ensaio"))
    return (pasta, None)


# --- 4. a paleta vira CSS ----------------------------------------------------
# NENHUM HEX VIVE DENTRO DE SCRIPT — é a regra do README, e ela vale para uma
# folha de estilo tanto quanto para um `.sh`.
#
# O caminho não é nomeado aqui: quem responde é `paleta_canonica()`, e o
# cabeçalho dela conta por quê.
_PALETA_CACHE = {}


def _paleta_dados():
    """A paleta inteira, lida uma vez. É a fonte de verdade de cor do projeto.

    "Uma vez" POR meow.conf, desde 23/09/2026: o `_ponte_em_dia` esvazia este
    cache quando o conf muda — é o que faz o «Usar este» da Home repintar a
    página com o pack novo em vez de manter a paleta da subida."""
    _ponte_em_dia()
    if not _PALETA_CACHE:
        try:
            with open(paleta_canonica(), "r", encoding="utf-8") as fh:
                _PALETA_CACHE.update(json.load(fh))
        except (OSError, ValueError):
            _PALETA_CACHE["flavors"] = {}
    return _PALETA_CACHE


def logo_do_painel(flavor, accent):
    """O SVG da marca, no sabor da página e na cor do acento dela.

    Devolve `bytes`, ou `None` quando o acervo autoral não está no disco — o
    que acontece antes do primeiro `install.sh`, e é um 404 honesto, não um
    erro: a página inteira funciona sem a marca."""
    dados = _paleta_dados()
    flavors = dados.get("flavors", {})
    # Era `flavors.get("mocha")`: um flavor do Catppuccin cravado na queda de
    # uma função que lê a paleta do pack no ar.
    mod = modulo_pack()
    no_ar = _pack_no_ar()
    padrao = ((mod.campo(no_ar, "paleta.flavor_padrao") if mod and no_ar else "")
              or next(iter(flavors), ""))
    cores = flavors.get(flavor) or flavors.get(padrao) or {}
    if accent not in cores:
        accent = "mauve" if "mauve" in cores else next(iter(cores), "")
    tinta = cores.get(accent) or ""

    # Eram dois `os.path.join(RAIZ, "assets", "icones", "autorais", ...)`
    # cravados.
    #
    # Quem resolve é o `acervo` do scripts/pack.py, pela mesma porta que a
    # etiqueta de pack desta página já usa (ver `modulo_pack`): ele sobe pack ->
    # herança -> motor e enxerga as três raízes.
    #
    # Antes ela cobria o flavor sem desenho dentro de um acervo só.
    def _marca(nome_flavor):
        if not mod or not nome_flavor:
            return ""
        return mod.acervo("icones.autorais.desenhos",
                          "meowsystem-painel-%s.svg" % nome_flavor) or ""

    arquivo = (_marca(flavor) or _marca(padrao)
               or _marca(mod.campo(mod.PACK_PADRAO, "paleta.flavor_padrao") if mod else ""))
    if not arquivo or not os.path.isfile(arquivo):
        return None
    with open(arquivo, "r", encoding="utf-8") as fh:
        bruto = fh.read()
    if not tinta:
        return bruto.encode("utf-8")
    # SÓ O ATRIBUTO `stroke` COM VALOR HEXADECIMAL, e nada mais: o desenho é de
    # traço (`fill="none"`), então o stroke é a cor inteira dele.
    return re.sub(r'stroke="#[0-9A-Fa-f]{3,8}"',
                  'stroke="%s"' % tinta, bruto).encode("utf-8")


def _areas_alfinetadas():
    """Os nomes das áreas alfinetadas, na ordem, sem o espaço-figura.

    Lê o `pinned_workspaces` direto em vez de chamar o `areas.sh`: um provedor
    roda a cada pintura da página, e um subprocesso por pintura é caro para
    responder "quais nomes existem". O arquivo é RON, mas o que se quer daqui é
    só a sequência de `name:` — e para isso a leitura por expressão basta e não
    escreve nada.

    O ESPAÇO-FIGURA SAI. O nome no disco é `\u2007Meow\u2007` — a folga que ela
    escolheu em 30/08 para a pastilha da barra não ficar apertada. Ela é
    decoração de largura, não parte do nome, e um menu que a mostrasse pediria
    para escolher entre "Meow" e " Meow " sem dizer a diferença.
    """
    caminho = os.path.expanduser(
        "~/.config/cosmic/com.system76.CosmicComp/v1/pinned_workspaces")
    try:
        with open(caminho, "r", encoding="utf-8", errors="replace") as fh:
            bruto = fh.read()
    except OSError:
        return []
    fora = []
    for m in re.finditer(r'name:\s*Some\(\s*"((?:[^"\\]|\\.)*)"\s*\)', bruto):
        nome = m.group(1).replace("\\u{2007}", "").replace("\u2007", "").strip()
        if nome:
            fora.append(nome)
    return fora


def paleta_css(flavor, accent):
    dados = _paleta_dados()
    flavors = dados.get("flavors", {})
    if not flavors:
        return "/* paleta ilegível — a página cai no tema do navegador */\n"
    # SEM FLAVOR CONHECIDO, O PRIMEIRO DO PACK NO AR — e não o "mocha", que é
    # nome de flavor do Catppuccin: com o Dracula no ar ele não existe, e a
    # página saía sem cor nenhuma.
    cores = flavors.get(flavor) or next(iter(flavors.values()), {})
    if accent not in cores:
        accent = "mauve" if "mauve" in cores else next(iter(cores), "")
    claro = flavor in dados.get("claros", [])
    linhas = [
        # O CSS diz de ONDE a cor veio. Com a paleta trocável, cravar o nome
        # aqui faria o arquivo gerado mentir sobre a própria procedência.
        f"/* Gerado por app/servidor.py a partir de "
        f"{os.path.relpath(paleta_canonica(), RAIZ)}.",
        "   Não edite: a fonte é a paleta, e ela é a única verdade de cor. */",
        ":root {",
        f"  color-scheme: {'light' if claro else 'dark'};",
    ]
    for nome, hexa in cores.items():
        linhas.append(f"  --{nome}: {hexa};")
    linhas.append(f"  --accent: var(--{accent});")
    # OS QUATRO FUNDOS DE TESTE, e eles não são decoração: são os quatro fundos
    # REAIS sobre os quais um ícone aparece nesta máquina.
    #
    # Os dois primeiros saem direto da paleta.
    #
    # Eram `--fundo-mocha` e `--fundo-latte`, lidos por NOME de flavor.
    #
    # PACK SEM CLARO AINDA TEM FUNDO CLARO: o `text` do escuro.
    #
    # Quem os renomear lá apaga as duas linhas aqui.
    mod = modulo_pack()
    luz = (lambda h: mod._luminancia(h)) if mod and hasattr(mod, "_luminancia") else (lambda h: 0.0)
    claros_do_pack = [f for f in (dados.get("claros", []) or []) if f in flavors]
    escuros = [f for f in flavors if f not in claros_do_pack]
    escuro = min(escuros, key=lambda f: luz(flavors[f].get("base", "#000000"))) if escuros else None
    claro_do_pack = max(claros_do_pack, key=lambda f: luz(flavors[f].get("base", "#000000"))) \
        if claros_do_pack else None
    base_escura = (flavors[escuro] if escuro else cores).get("base", "")
    base_clara = (flavors[claro_do_pack].get("base", "") if claro_do_pack
                  else (flavors[escuro] if escuro else cores).get("text", ""))
    linhas.append("  --fundo-escuro: %s;" % base_escura)
    linhas.append("  --fundo-claro: %s;" % base_clara)
    linhas.append("  --fundo-mocha: var(--fundo-escuro);")
    linhas.append("  --fundo-latte: var(--fundo-claro);")
    linhas.append("  --fundo-vidro-escuro: color-mix(in srgb, var(--base) 83%, var(--text));")
    linhas.append("  --fundo-vidro-claro: color-mix(in srgb, var(--surface1) 55%, var(--mauve));")
    linhas.append(f"  --accent-nome: '{accent}';")
    linhas.append("}")
    return "\n".join(linhas) + "\n"


def _flavor_no_modo(flavor, modo):
    """O flavor que a página veste: no MODO claro, o primeiro claro do PACK NO AR.

    UMA FUNÇÃO, E NÃO TRÊS CÓPIAS — 23/09/2026, P34. A P10 ensinou três
    lugares a vestir o claro do pack no ar em vez do "latte" cravado — o
    `/paleta.css`, a marca do painel e a página exportada —, e a linha do
    "primeiro claro, ou o flavor pedido" nasceu copiada nos três. O porquê da
    regra está no `/paleta.css`, que foi onde ela nasceu. Um quarto lugar
    copiaria o vizinho mais próximo, e uma mudança na regra teria de achar os
    três; agora quem precisa pergunta aqui.

    Pack sem claro declarado devolve o flavor pedido: não há claro para onde ir.

    NO MODO ESCURO, UM FLAVOR CLARO VESTE O ESCURO DO PACK — 25/09/2026, P59
      Com FLAVOR=alucard e MODO=escuro a página se vestia de claro e o desktop
      ficava escuro. Quem escolhe o lado que a tela mostra é o `is_dark`, e quem
      o escreve é o MODO, e só ele (a `etapa_modo`, o `meow tema claro|escuro`,
      e o `aplicar_tema.sh` cede o `is_dark` do Mode a eles): o FLAVOR escolhe a
      captura, e a captura traz as duas árvores. A de um flavor claro leva no
      escuro o do pack — o `flavor_padrao` (a Dark do `latte-mauve` é o Mocha;
      a derivada do alucard, o dracula), ou o primeiro escuro da paleta quando
      o padrão é claro. É a mesma regra do `par_do_outro_lado` do
      scripts/derivar_flavor.py, que monta a captura; o tests/variante.sh, na
      seção 7, confere que os dois respondem igual. O automático continua no
      FLAVOR: ali o relógio alterna, e a página não o acompanha."""
    claros = _paleta_dados().get("claros") or []
    if modo == "claro":
        return claros[0] if claros else flavor
    if modo != "escuro" or flavor not in claros:
        return flavor
    flavors = _paleta_dados().get("flavors") or {}
    mod = modulo_pack()
    no_ar = _pack_no_ar()
    padrao = (mod.campo(no_ar, "paleta.flavor_padrao") if mod and no_ar else "") or ""
    if padrao in flavors and padrao not in claros:
        return padrao
    escuros = [f for f in flavors if f not in claros]
    return escuros[0] if escuros else flavor


def _lados_do_pack():
    """{flavor: {"claro": ..., "escuro": ...}} — o que o `_flavor_no_modo` veste
    em cada lado, para cada flavor do pack no ar. A prévia de «Cor e tela» o
    recebe pelo esquema (`pack.lados`) e desenha o que a página vai vestir, em
    vez de repetir a regra em JavaScript. [P59]

    O COSMIC VESTE O MESMO FLAVOR DESDE A P63 — a revisão da P59 (25/09/2026)
    mediu a foto `dracula-mauve` trazendo na Light o Latte do Catppuccin
    (`name: "catppuccin-latte"`, a receita igual à do latte-mauve), e com
    FLAVOR=dracula e MODO=claro a tela mostrava o latte enquanto a página e a
    prévia diziam alucard. A P63 fez a sprint própria: a Light das capturas do
    Dracula sai do alucard, derivada (`lado_do_par`, no
    scripts/derivar_flavor.py), e a foto diz `name: "dracula-alucard"`. [Até a
    P67 esta docstring dava a Light do Latte no presente, e a sprint como
    pendente.]"""
    return {f: {m: _flavor_no_modo(f, m) for m in ("claro", "escuro")}
            for f in (_paleta_dados().get("flavors") or {})}


# Um pack de terceiro ainda pode ter um que não se deriva — sem foto de lado
# nenhum, ou com a base que não se reproduz —, e aí o instalador pula a etapa do
# tema e o COSMIC fica como estava.
_SEM_TEMA_CACHE = {}


def _variante_sem_tema(flavor, accent):
    """True só quando o par não tem captura e não se deriva."""
    _ponte_em_dia()
    mod = modulo_pack()
    if mod is None:
        return False
    par = "%s-%s" % (flavor, accent)
    try:
        if mod.captura(par):
            return False
        chave = [os.environ.get("MEOW_PACK_DIR", ""), os.environ.get("MEOW_PALETA", ""), par,
                 os.stat(mod.paleta_do_pack_ativo()).st_mtime_ns]
        for nome in mod.capturas():
            txt = os.path.join(mod.captura(nome) or "", "captura.txt")
            chave.append((nome, os.stat(txt).st_mtime_ns if os.path.isfile(txt) else 0))
    except Exception:
        return False
    chave = repr(chave)
    if chave not in _SEM_TEMA_CACHE:
        try:
            r = subprocess.run(
                [sys.executable, os.path.join(RAIZ, "scripts", "derivar_acento.py"),
                 "--conferir", par],
                cwd=RAIZ, capture_output=True, text=True, timeout=60)
        except (OSError, subprocess.SubprocessError):
            return False
        _SEM_TEMA_CACHE.clear()
        _SEM_TEMA_CACHE[chave] = r.returncode == 3
    return _SEM_TEMA_CACHE[chave]


def _flavor_na_tela():
    """O flavor que o COSMIC mostra agora: o nome da paleta da árvore que o
    `is_dark` escolhe (`dracula-alucard`, `catppuccin-mocha`), quando ele termina
    num flavor do pack no ar. None quando não dá para saber."""
    escuro = _cosmic_ler("com.system76.CosmicTheme.Mode/v1/is_dark")
    if escuro not in ("true", "false"):
        return None
    arvore = "Dark" if escuro == "true" else "Light"
    bruto = _cosmic_ler("com.system76.CosmicTheme.%s.Builder/v2/palette" % arvore) or ""
    m = re.search(r'\bname:\s*"([^"]*)"', bruto)
    if not m:
        return None
    for f in (_paleta_dados().get("flavors") or {}):
        if m.group(1) == f or m.group(1).endswith("-" + f):
            return f
    return None


def _acento_na_tela(flavor):
    """O acento que o COSMIC mostra agora, dito como cor do `flavor`: o `accent`
    da receita da árvore que o `is_dark` escolhe (`Some("#CBA6F7FF")`), achado
    pelo hex entre as cores do flavor na paleta do pack no ar. None quando não
    dá para saber — sem a receita, com `None` nela, ou com uma cor que o flavor
    não tem. É o irmão do `_flavor_na_tela`, pela mesma porta. [P59, revisão]"""
    escuro = _cosmic_ler("com.system76.CosmicTheme.Mode/v1/is_dark")
    if escuro not in ("true", "false"):
        return None
    arvore = "Dark" if escuro == "true" else "Light"
    bruto = _cosmic_ler("com.system76.CosmicTheme.%s.Builder/v2/accent" % arvore) or ""
    m = re.match(r'^Some\(\s*"(#[0-9A-Fa-f]{6})', bruto)
    if not m:
        return None
    cores = (_paleta_dados().get("flavors") or {}).get(flavor) or {}
    return next((slot for slot, hexa in cores.items()
                 if str(hexa).upper() == m.group(1).upper()), None)


def _flavor_da_pagina(flavor, valores):
    """O flavor que `/paleta.css`, a marca e a página exportada vestem: o do
    `_flavor_no_modo`, menos para a variante sem tema — aí o que a tela mostra,
    e sem isso o padrão do pack no modo. Ver o bloco acima. O acento que vai
    junto é o do `_acento_da_pagina`."""
    modo = valores.get("MODO")
    if not _variante_sem_tema(flavor, valores.get("ACCENT") or "mauve"):
        return _flavor_no_modo(flavor, modo)
    na_tela = _flavor_na_tela()
    if na_tela:
        return na_tela
    mod = modulo_pack()
    no_ar = _pack_no_ar()
    padrao = (mod.campo(no_ar, "paleta.flavor_padrao") if mod and no_ar else "") or flavor
    return _flavor_no_modo(padrao, modo)


def _acento_da_pagina(flavor, valores):
    """O acento que vai com o `flavor` do `_flavor_da_pagina`: o do conf, menos
    para a variante sem tema — aí o que a tela mostra (`_acento_na_tela`), e sem
    isso o mauve, o padrão de sempre do ACCENT (`${ACCENT:-mauve}`).

    O ACENTO DA VARIANTE SEM TEMA NÃO É O DO CONF — 25/09/2026, revisão da P59
      O `_flavor_da_pagina` trocava só o flavor. Numa casa de brinquedo com o
      Catppuccin sem foto escura, FLAVOR=frappe ACCENT=pink e o COSMIC em
      mocha-mauve, o `/paleta.css` servia `--base #1E1E2E --accent var(--pink)`:
      o fundo da tela com o acento do conf, que ninguém aplicou — quem escreve
      acento no COSMIC é o aplicar_tema.sh, e a etapa tema se pula nesse caso.
      A prévia de «Cor e tela» pinta a variante sem tema com o `--accent` da
      página, e desenhava um destaque rosa dizendo «Uma tela na cor de agora».
      O pink é a metade da variante que não aplicou, e a página não se veste
      dela nem pela metade. O `tests/variante.sh` (seção 8) pergunta à rota."""
    accent = valores.get("ACCENT") or "mauve"
    if not _variante_sem_tema(_flavor_do_conf(valores), accent):
        return accent
    return _acento_na_tela(flavor) or "mauve"


# --- 5. as ações -------------------------------------------------------------
# A página manda um `id`; o `id` é chave deste dicionário; o que roda é o `argv`
# daqui.
#
# `arg` nomeia um PROVEDOR de valores válidos, e o valor que a página mandar é
# conferido contra a lista que o provedor monta DO DISCO.
# É a fronteira de segurança do arquivo: texto do navegador nunca vira comando
# (não há `shell=True` aqui), e `id` desconhecido é recusado antes de qualquer processo.
PROVEDORES = {
    "capturas": _capturas,
    "gatos": _gatos,
    "modos": lambda: ["claro", "escuro", "auto"],
    "temas_icones": _temas_de_icones,
    "cursores": _temas_de_cursor,
    "areas": _areas_alfinetadas,
    "paredes_ativas": _paredes_ativas,
    "paredes_banidas": _paredes_banidas,
    "paredes_favoritas": lambda: _paredes_favoritas(),
    # Os theme packs do disco — o argumento do «Usar este» da Home. A varredura
    # é a mesma do `/api/packs`, então o cartão só oferece o que esta cerca
    # aceita.
    "packs": lambda: sorted(_packs_no_disco()),
    # O argumento do «Remover»: só o que a `remocao` deixa sair. É a mesma
    # conta que acende o botão no cartão.
    "packs_removiveis": _packs_removiveis,
    # O argumento dos dois botões da pendência de tema de terceiro: os apps que
    # têm essa pendência na Home agora. Ver `SUFIXO_TEMA_DE_TERCEIRO`.
    "apps_de_terceiro": lambda: sorted({_app_da_pendencia(p["id"]) for p in pendencias()} - {""}),
    # O argumento do «Instalar <extensão>» da pendência do VS Code: as extensões
    # que o pack IMPORTADO no ar pede. Pack do repositório dá lista vazia, e com
    # ela nenhum botão e nenhum argumento aceito.
    "extensoes_de_terceiro": lambda: _extensoes_de_terceiro(),
    # O argumento do «Era escolha minha»: o caminho que o `wallpaper.sh`
    # devolveu e deixou na pendência. Ver `PENDENCIA_PAREDE`.
    "fontes_revertidas": lambda: _fontes_revertidas(),
    # O argumento do «Restaurar»: as ações cuja última execução se desfaz.
    "restauros": lambda: sorted(restauros()),
    # O argumento do interruptor de um jogo do Heroic: os instalados agora.
    "jogos_heroic": lambda: sorted(j["id"] for j in jogos_do_heroic()),
}


def _meow(*args):
    return [os.path.join(RAIZ, "bin", "meow"), *args]


# A caixa de confirmar, o «ver comando» e o topo da gaveta imprimiam o `argv`
# com o caminho absoluto do clone na frente: «Usar este pack» mostrava
# `/home/<usuário>/Desenvolvimento/MeowSystem/bin/meow pack usar catppuccin`.
def _casas():
    """A casa de quem roda, como o ambiente a diz e como o disco a resolve.

    As duas, porque um caminho pode chegar por qualquer uma delas: o `RAIZ`
    deste arquivo passa pelo `realpath`, e o `$HOME` que os scripts expandem
    não. Uma casa `/` não é casa: trocá-la por `~` comeria o sistema inteiro.
    """
    casa = os.path.expanduser("~")
    return [c for c in dict.fromkeys((casa, os.path.realpath(casa)))
            if c and c != os.sep]


def _na_casa(caminho):
    """(casa, resto) quando `caminho` é a casa ou mora nela; senão None."""
    for casa in _casas():
        if caminho == casa or caminho.startswith(casa + os.sep):
            return casa, caminho[len(casa):]
    return None


def comando_na_tela(argv):
    """O comando como a pessoa o digitaria num terminal — ver o bloco acima."""
    meow = os.path.join(RAIZ, "bin", "meow")
    partes = []
    for p in argv:
        casa = _na_casa(p)
        if p == meow:
            partes.append("meow")
        elif p.startswith(RAIZ + os.sep):
            partes.append(shlex.quote("./" + p[len(RAIZ) + 1:]))
        elif casa:
            # O `~` fica FORA das aspas, senão o shell não o expande; só o
            # resto é citado, e `~/'Minhas Imagens'/x.jpg` é um caminho válido.
            resto = casa[1].lstrip(os.sep)
            partes.append("~/" + shlex.quote(resto) if resto else "~")
        else:
            partes.append(shlex.quote(p))
    return " ".join(partes)


def texto_na_tela(texto):
    """Um texto qualquer (uma linha da gaveta) com a casa trocada por `~`.

    A borda dos dois lados é o que impede a casa `/home/<nome>` de comer o
    começo de `/home/<nome>zinho`, e um `x/home/<nome>` de virar `x~`: a casa
    só casa inteira.

    ENTRE ASPAS, O `~` SAI PARA FORA DELAS — 24/09/2026, revisão da P52. O
    shell só expande o `~` que não está citado, e os scripts imprimem comando
    para colar com o caminho entre aspas: o `wallpaper.sh` imprime
    `meow wallpaper permitir "$fonte_atual"`, e três scripts de ícone imprimem
    `rm '$cache'`. Com a troca crua, a gaveta passou a mostrar
    `permitir "~/Imagens/…"`; colado, o argumento chegava como `~/Imagens/…`
    literal, o `readlink -m` do `cmd_permitir` o resolvia contra a pasta de onde
    se colou (`/tmp/~/Imagens/…`), a autorização gravada nunca casava com nada,
    e o carrossel seguia desfazendo o papel de parede — o comando funcionava
    antes da P52. Então a aspa que abre colada na casa pula para depois do
    `~/`: `"<casa>/Imagens/x y.jpeg"` vira `~/"Imagens/x y.jpeg"`, a mesma
    forma do `comando_na_tela` logo acima, e a casa citada inteira (`"<casa>"`)
    vira `~` sem aspas. Uma frase com o caminho entre aspas lê um pouco torto
    (`não achei ~/'x.zip'`) e continua certa; o contrário — um comando que lê
    bonito e não cola — era o defeito.
    """
    for casa in _casas():
        borda = r"(?<![\w/.~-])"
        texto = re.sub(borda + r"([\"'])" + re.escape(casa) + r"(?:(/)|\1)",
                       lambda m: "~/" + m.group(1) if m.group(2) else "~", texto)
        texto = re.sub(borda + re.escape(casa) + r"(?![\w.-])", "~", texto)
    return texto


def sem_casa_nem_raiz(valor, outras=()):
    """Os dados da página exportada sem a casa e sem o caminho do clone.

    POR QUE — 24/09/2026, P52 (achado 22). «Esta tela num arquivo» embute o
    esquema inteiro em JSON, e ele saía com 709 textos carregando caminho
    absoluto: o `meow.conf`, a raiz do repositório, o valor efetivo de cada
    chave com `$HOME`, a origem de cada imagem do acervo — e mais 83 URLs de
    prévia com o mesmo caminho, só que em `%2Fhome%2F<usuário>`. Uma página
    feita para mandar a quem vai redesenhar levava o nome de usuário e o mapa
    da máquina.

    O QUE VIRA O QUÊ: o que mora no clone fica relativo a ele
    (`docs/folhas/…`, `meow.conf.exemplo`), e a raiz sozinha fica vazia — o
    `semRaiz` do `app.js` lê vazio como "não há o que tirar". O que mora na
    casa vira `~/…`. As duas trocas valem também na forma de URL, e nas CHAVES
    dos dicionários: o mapa `imagens` é indexado pela mesma URL que a ficha do
    aplicativo carrega, e trocar só um dos lados apagaria a imagem da página.

    `data:` fica como está: é imagem em base64, e um acaso de bytes que
    parecesse caminho seria corrompido, não protegido.

    `outras` são pares (caminho, rótulo) de pastas fora da casa e do clone que
    o próprio `meow.conf` aponta — ver `_exportar_pagina`. Cada uma vira o
    rótulo, com a mesma borda da casa.
    """
    if isinstance(valor, dict):
        return {sem_casa_nem_raiz(k, outras): sem_casa_nem_raiz(v, outras)
                for k, v in valor.items()}
    if isinstance(valor, list):
        return [sem_casa_nem_raiz(v, outras) for v in valor]
    if not isinstance(valor, str) or valor.startswith("data:"):
        return valor
    for forma in (str, lambda s: quote(s, safe="")):
        raiz = forma(RAIZ)
        valor = "" if valor == raiz else valor.replace(forma(RAIZ + "/"), "")
        for casa in _casas():
            valor = re.sub(r"(?<![\w/.~-])" + re.escape(forma(casa)) + r"(?![\w.-])",
                           "~", valor)
        for caminho, rotulo in outras:
            valor = re.sub(r"(?<![\w/.~-])" + re.escape(forma(caminho)) + r"(?![\w.-])",
                           lambda _m, r=forma(rotulo): r, valor)
    return valor


# O título sozinho não conta nada — "Automação" não diz a ninguém que ali moram
# os vigias e os relógios que reaplicam o tema.
#
# A `docs/folhas/folha-menu-do-painel.html` pôs a contradição na mesa e ela
# aprovou: são nove linhas curtas, e o problema que elas resolvem é exatamente o
# que ela levantou.
DESCRICAO_SECAO = {
    #   Eram nove frases para dezenove abas, e as subabas herdavam a do pai:
    #   três abas abriam com a mesma linha. Com o menu num nível só e uma página
    #   por assunto, a lista passa a ter uma frase por página, e o
    #   `|| d[g.secaoPai]` que o `app.js` usava para tapar o buraco saiu.
    "Cor e tela": "A variante do pack, a cor de destaque, o lado a lado e o ponteiro.",
    "Áreas de trabalho": "O nome e a ordem das áreas, e o encaixe de janelas em cada uma.",
    "Logo do sistema": "A logo que aparece no menu de lançamento, na dock e no terminal.",
    "Ícones": "O tema de ícones que o projeto constrói, e o desenho de cada programa.",
    "Painel e dock": "Forma, tamanho, vidro e a música que aparece no painel.",
    "Papel de parede": "A coleção, a pasta que gira, e como a imagem ocupa a tela.",
    "Dia e noite": "A que horas a noite começa, e o que ela troca sozinha.",
    "Modo de leitura": "A tela quente à noite: a temperatura, a textura e o horário.",
    "Terminal": "A paleta do terminal, a cor do cursor, e o prompt do zsh.",
    "Lançadores e jogos": "Quais programas o projeto veste, e quais jogos aparecem.",
    "Manutenção": "O que se reaplica sozinho, quantos backups ficam, e quanto ele fala.",
    # As duas páginas sem chave do meow.conf. Elas e a Manutenção formam o bloco
    # "Sistema", e quem decide isso é o `BLOCO_DA_SECAO`, logo abaixo.
    "Instalação": "Instalar, conferir, consertar, desfazer, e ver o que está no ar.",
    "Atualização": "O Pop!_OS em dia, e o que a atualização desfez do MeowSystem.",
}


# Antes, o `app.js` decidia sozinho por uma pergunta que PARECIA equivalente:
# "esta seção tem chave do meow.conf?". Sim virava "Assuntos", não virava
# máquina.
#
# Ausente da tabela = "Tópicos".
BLOCO_DA_SECAO = {
    "Manutenção": "Sistema",
    "Instalação": "Sistema",
    "Atualização": "Sistema",
}


# `/usr/local/lib/meowsystem/ponte_root.sh` é o braço root do projeto, liberado
# sem senha por `/etc/sudoers.d/49-meowsystem-ponte`. O painel não a chama: quem
# chama são os scripts.
#
# `sudo -n` é barato mas não é de graça, e o esquema é lido a cada pintura da
# página.
_PELA_PONTE = frozenset({"sistema_atualizar", "sistema_limpar"})
_PONTE_CAMINHO = "/usr/local/lib/meowsystem/ponte_root.sh"
_ponte_cache = {"quando": 0.0, "vale": False}


def _ponte_viva():
    agora = time.time()
    if agora - _ponte_cache["quando"] < 30:
        return _ponte_cache["vale"]
    vale = False
    if os.access(_PONTE_CAMINHO, os.X_OK):
        try:
            vale = subprocess.run(["sudo", "-n", _PONTE_CAMINHO, "estado"],
                                  capture_output=True, timeout=5).returncode == 0
        except (OSError, subprocess.SubprocessError):
            vale = False
    _ponte_cache["quando"] = agora
    _ponte_cache["vale"] = vale
    return vale


# Até aqui a pastilha do fim da gaveta saía SÓ do código de saída, com uma
# ressalva de quem escreve: 0 era "já estava certo" (ou "mexeu e aplicou" com
# linha `~~`), 1 era "mexeu e consertou".
#
# Botão nenhum tem rótulo de fim escrito à mão.
#
# O ENSAIO É UMA NATUREZA DA EXECUÇÃO, E NÃO DA AÇÃO: um `seco` de qualquer
# ação não escreveu nada, e o fim dele fala do que MUDARIA.
NATUREZAS = {
    # só lê: `meow status`, `meow log`, a lista de temas prontos
    "mostrar":   {"0": ("ok", "mostrou"),
                  "1": ("correndo", "há divergências")},
    # só lê, e a pergunta é "está como deveria?": o doctor, `meow apps`
    "conferir":  {"0": ("ok", "tudo confere"),
                  "1": ("correndo", "há divergências")},
    # O 0 COM `~~` DO CONSERTO É O QUE ELE NÃO CONSERTA: a tabela do doctor
    # mostrou a divergência, o laço a pulou (sem conserto automático, escolha
    # sua, falta dependência), e nada foi escrito.
    "consertar": {"0": ("ok", "nada a consertar"),
                  "0~": ("correndo", "divergências sem conserto"),
                  "1": ("ok", "consertou")},
    # aplica o que está no meow.conf: `apps aplicar`, reconstruir os ícones
    "aplicar":   {"0": ("ok", "já estava certo"),
                  "0~": ("ok", "mexeu e aplicou"),
                  "1": ("ok", "mexeu e aplicou")},
    # Aplicou o resto, e não aplicou tudo.
    "instalar":  {"0": ("ok", "já estava certo"),
                  "0~": ("ok", "mexeu e aplicou"),
                  "1": ("correndo", "aplicou, com pendência")},
    # troca o que está no ar por outra escolha: a próxima imagem, o tema
    "trocar":    {"0": ("ok", "já estava assim"),
                  "0~": ("ok", "trocou"),
                  "1": ("ok", "trocou")},
    # grava uma decisão que vale depois: as áreas (no próximo login), o lado
    # de uma imagem, o «Manter o meu tema»
    "gravar":    {"0": ("ok", "já estava assim"),
                  "0~": ("ok", "gravou"),
                  "1": ("ok", "gravou")},
    "tirar":     {"0": ("ok", "nada a tirar"),
                  "0~": ("ok", "tirou"),
                  "1": ("ok", "tirou")},
    "devolver":  {"0": ("ok", "nada a devolver"),
                  "0~": ("ok", "devolveu"),
                  "1": ("ok", "devolveu")},
    # baixa da internet e instala: o starship, a coleção, o tema do Spotify
    "baixar":    {"0": ("ok", "já estava aqui"),
                  "0~": ("ok", "baixou e instalou"),
                  "1": ("ok", "baixou e instalou")},
    "atualizar": {"0": ("ok", "já estava em dia"),
                  "0~": ("ok", "atualizou"),
                  "1": ("ok", "atualizou")},
    # «Ouvir o som» toca e não escreve: o 0 dele é ter tocado.
    "tocar":     {"0": ("ok", "tocou")},
    # O RECICLO SÓ ACONTECE COM LINHA `~~`: o `painel.sh reciclar` sai 0 também
    # quando não há painel desta casa de pé, e aí não reciclou nada.
    "reciclar":  {"0": ("ok", "nada a recarregar"),
                  "0~": ("ok", "recarregou")},
    "ensaio":    {"0": ("ok", "nada mudaria"),
                  "0~": ("correndo", "mudaria"),
                  "1": ("correndo", "mudaria")},
}
_FIM_PULADO = {"3": ("pula", "pulado"), "4": ("pula", "pulado")}


def fim_da_acao(acao_id, seco=False):
    """A tabela do fim de UM trabalho: código (ou `0~`) -> [classe, frase]."""
    natureza = "ensaio" if seco else ACOES[acao_id]["natureza"]
    return {k: list(v) for k, v in dict(_FIM_PULADO, **NATUREZAS[natureza]).items()}


# «Pôr um gato no dock» com a Coquinha, no modo Hora, respondeu «JÁ ESTAVA
# CERTO — logo já no lugar: morcego-dia», e o dock ficou igual (medido).
#
# É O MESMO REMÉDIO DO «Tirar uma área»
@_uma_vez_por_leitura
def _modo_do_gato():
    """O modo EFETIVO do gato do dock (`hora`, `rotacao`, `fixo`), ou "".

    Quem responde é o `logo.sh modo`, que existe para ninguém reimplementar a
    regra de compatibilidade `LOGO_ROTACAO` -> `LOGO_MODO`: dois donos da mesma
    regra é o defeito que o comentário dele já conta. O conf lido é o do
    `carregar_conf` — o dela, ou o exemplo quando ela não tem um —, e só ele:
    somar o exemplo por baixo poria o `LOGO_MODO="hora"` de fábrica na frente de
    quem só escreveu `LOGO_ROTACAO="sim"`. Medido: 9 ms."""
    fonte = CONF if os.path.isfile(CONF) else CONF_PADRAO
    programa = 'set -a; . "$1"; set +a; exec "$2" modo'
    try:
        r = subprocess.run(["bash", "-c", programa, "_", fonte,
                            os.path.join(RAIZ, "scripts", "logo.sh")],
                           capture_output=True, timeout=10, env=_ambiente_do_painel())
    except (OSError, subprocess.SubprocessError):
        return ""
    return r.stdout.decode("utf-8", "replace").strip() if r.returncode == 0 else ""


@_uma_vez_por_leitura
def _gato_no_dock():
    """O gato que está NO BOTÃO DO DOCK agora, ou "" quando não há um.

    O RETRATO DA INÍCIO LIA A CHAVE, E NÃO O DOCK — 25/09/2026, validação final
    no painel de verdade. Às 03:28, com o morcego-noite no dock (modo `hora`),
    ele dizia «Logo Coquinha, escolhida pelo relógio»: a `LOGO` é a do modo
    `fixo`, e no `hora` quem põe o gato é o relógio. É a classe do achado 46,
    que a P54 consertou no `meow status` perguntando ao `logo.sh no-dock` — o
    dono único da pergunta, que o espelho do terminal também usa. A página
    pergunta ao mesmo dono, pelo caminho do `_modo_do_gato` logo acima: o conf
    do `carregar_conf`, e o seco junto, porque o `no-dock` só lê."""
    fonte = CONF if os.path.isfile(CONF) else CONF_PADRAO
    programa = 'set -a; . "$1"; set +a; exec "$2" no-dock'
    try:
        r = subprocess.run(["bash", "-c", programa, "_", fonte,
                            os.path.join(RAIZ, "scripts", "logo.sh")],
                           capture_output=True, timeout=10,
                           env=dict(_ambiente_do_painel(), MEOW_DRY_RUN="1"))
    except (OSError, subprocess.SubprocessError):
        return ""
    return r.stdout.decode("utf-8", "replace").strip() if r.returncode == 0 else ""


def _gato_so_nos_modos(vale_em, pede):
    """A condição dos dois botões do gato: sem efeito fora dos modos `vale_em`.

    Modo que não se soube ler não apaga nada: um botão apagado por engano é
    pior que um botão que responde «já estava assim»."""
    def medir():
        modo = _modo_do_gato()
        if not modo or modo in vale_em:
            return None
        return {"chave": "LOGO_MODO", "vale": modo, "pede": pede}
    return medir


def _areas_sem_alfinete():
    """«Gravar as áreas» sem área fixada: a ordem é «Criar a primeira área»."""
    if _areas_alfinetadas():
        return None
    return {"antes": "areas_alfinetar_primeira",
            "porque": "nenhuma área está fixada, e é de uma fixada que as "
                      "outras herdam o monitor"}


def comeca_como_svg(dados):
    """O arquivo começa como XML de SVG? Lê só os primeiros 4 KB.

    É o `.png` que na verdade é SVG (ver "O ARQUIVO DIZ O QUE ELE É", na rota
    `/previa?tipo=arquivo`). LEITOR LINEAR, E NÃO EXPRESSÃO REGULAR — revisão
    de segurança da P80: a primeira versão era uma regex com `.*?` dentro de
    um grupo repetido, e um arquivo de acervo (de um pack importado) com 4 KB
    de `<!--` sem fecho a fazia voltar atrás de forma explosiva, travando a
    thread do servidor. Aqui cada passo pula um pedaço com `find` e anda para
    a frente, nunca para trás; o laço tem teto."""
    cabeca = dados[:4096]
    if cabeca.startswith(b"\xef\xbb\xbf"):
        cabeca = cabeca[3:]
    i = 0
    for _ in range(64):
        while i < len(cabeca) and cabeca[i:i + 1].isspace():
            i += 1
        for abre, fecha in ((b"<?xml", b"?>"), (b"<!--", b"-->"), (b"<!DOCTYPE", b">")):
            if cabeca.startswith(abre, i):
                fim = cabeca.find(fecha, i + len(abre))
                if fim < 0:
                    return False
                i = fim + len(fecha)
                break
        else:
            seguinte = cabeca[i + 4:i + 5]
            return cabeca.startswith(b"<svg", i) and (seguinte == b">" or seguinte.isspace())
    return False


def _areas_ja_alfinetadas():
    """«Criar a primeira área» com área fixada: já está feito, e o passo
    seguinte é «Gravar as áreas».

    QA de uso real da P80 (10/10/2026), na casa copiada da pessoa: duas áreas
    fixadas («Tirar uma área» oferecia as duas) e «Criar a primeira área» aceso
    ao lado, na mesma aba. O verbo do `areas.sh` sai em 0 sem escrever nada
    quando já há área (o bloco "E ELE NÃO ESCREVE POR CIMA DE ALFINETE
    NENHUM", lá) — o botão só podia não fazer nada. É o espelho do
    `_areas_sem_alfinete`: lá o «Gravar» espera o «Criar»; aqui o «Criar» já
    foi, e aponta o «Gravar»."""
    if not _areas_alfinetadas():
        return None
    return {"feito": "areas_aplicar",
            "porque": "há área fixada nesta máquina"}


def _starship_ja_instalado():
    """«Instalar o starship» com ele já instalado: o botão não tem o que fazer.

    15/10/2026, P82 (item 2; decisão 14). O botão ficava aceso com o starship
    em `~/.cargo/bin`, que é onde o `cargo install starship` o põe. Os lugares
    são os do `_prompt_onde_starship` (scripts/prompt.sh): o PATH, o
    `~/.local/bin` (onde o nosso botão o põe) e o `~/.cargo/bin`."""
    casa = os.path.expanduser("~")
    for lugar in (shutil.which("starship"),
                  os.path.join(casa, ".local", "bin", "starship"),
                  os.path.join(casa, ".cargo", "bin", "starship")):
        if lugar and os.path.isfile(lugar) and os.access(lugar, os.X_OK):
            return {"porque": "o starship já está instalado"}
    return None


def indisponivel(acao_id):
    """O motivo de a ação não ter efeito agora (um dicionário), ou None."""
    medir = ACOES[acao_id].get("indisponivel")
    return medir() if medir else None


ACOES = {
    # --- o ciclo de vida -----------------------------------------------------
    # É o `meow pack usar`, e não um `/api/definir` de PACK e FLAVOR seguido do
    # instalador, por dois motivos: quem decide o flavor e recusa um pack que
    # não valida é o `pack.py`, e o ensaio precisa ser o da TROCA — o verbo
    # grava as duas chaves numa cópia do conf quando roda seco (ver o `usar` do
    # bin/meow).
    "pack_usar": {
        "rotulo": "Usar este pack",
        "grupo": "Instalação",
        "natureza": "instalar",
        "argv": _meow("pack", "usar", "@ARG@"), "arg": "packs",
        "escreve": True, "sudo": True, "confirma": True, "rede": True,
        "oculta": True,
        "ajuda": "Grava o pack e a variante dele no meow.conf e roda o "
                 "instalador: a máquina inteira troca de tema.",
    },
    # É o `meow pack remover`, e quem decide o que pode sair é a `remocao` do
    # scripts/pack.py — a mesma conta que acende o botão no cartão e que cerca o
    # argumento (`packs_removiveis`).
    "pack_remover": {
        "rotulo": "Remover este pack",
        "grupo": "Instalação",
        "natureza": "tirar",
        "argv": _meow("pack", "remover", "@ARG@"), "arg": "packs_removiveis",
        "escreve": True, "sudo": False, "confirma": True, "destrutivo": True,
        "oculta": True,
        "ajuda": "Tira da sua casa de packs um pack que você importou. O tema no "
                 "ar não muda; para tê-lo de novo, importe o arquivo dele outra vez.",
    },
    "instalar": {
        "rotulo": "Instalar tudo",
        "grupo": "Instalação",
        "natureza": "instalar",
        "argv": [os.path.join(RAIZ, "install.sh")],
        "escreve": True, "sudo": True, "confirma": True, "rede": True,
        "ajuda": "Passa {as_etapas}. Rodar de novo numa máquina já pronta "
                 "não escreve um byte.",
    },
    # --- som ----------------------------------------------------------------
    # Duas ações, e a de OUVIR é a que importa na tela: escolher um timbre sem
    # poder ouvi-lo é escolher no escuro.
    "som_ouvir": {
        "rotulo": "Ouvir o som",
        "grupo": "Manutenção",
        "natureza": "tocar",
        "argv": [os.path.join(RAIZ, "scripts", "som.sh"), "ouvir"],
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "Toca o som de volume que está instalado agora. Se não houver o "
                 "nosso, toca o de fábrica — assim dá para comparar os dois.",
    },
    "som_aplicar": {
        "rotulo": "Regravar o som",
        "grupo": "Manutenção",
        "natureza": "aplicar",
        "argv": [os.path.join(RAIZ, "scripts", "som.sh"), "aplicar"],
        "escreve": True, "sudo": False, "confirma": False,
        # Medidas as 50 frases fixas daqui, esta era a só que passava (230). As
        # duas palavras que saíram não carregavam nada: «do SEU meow.conf»
        "ajuda": "Gera o som de novo a partir do timbre do pack ativo e do "
                 "meow.conf. Vale na próxima mudança de volume — nada a reiniciar. "
                 "Com «Som ao mudar o volume» em não, este botão faz o contrário: "
                 "devolve o som de fábrica.",
    },
    "doctor": {
        "rotulo": "Conferir a máquina",
        "grupo": "Instalação",
        "natureza": "conferir",
        "argv": _meow("doctor"),
        "escreve": False, "sudo": False, "confirma": False,
        # A Instalação tem um botão só, o que confere e conserta (o doctor
        # corrige); este fica para quem pergunta pelo id.
        "oculta": True,
        # Com divergência o doctor termina em «rode: meow doctor
        # --consertar»: um comando para quem está diante de um botão.
        "conserta_com": "doctor_consertar",
        "ajuda": "Faz {as_conferencias} e lista o que está fora do lugar. "
                 "Não escreve nada.",
    },
    "doctor_consertar": {
        "rotulo": "Conferir e consertar",
        "grupo": "Instalação",
        "natureza": "consertar",
        "argv": _meow("doctor", "--consertar"),
        # A ação dizia `rede: False`, e o gate reprovava 10 vezes («tentou
        # baixar sem declarar rede»).
        "escreve": True, "sudo": False, "confirma": False, "rede": True,
        "ajuda": "Confere e aplica só o que falhou — o mesmo que o "
                 "agendamento faz sozinho.",
    },
    "status": {
        "rotulo": "O que está no ar agora",
        "grupo": "Instalação",
        "natureza": "mostrar",
        "argv": _meow("status"),
        "escreve": False, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Variante, cor de destaque, tema, ícones e papel de parede.",
    },
    "desinstalar": {
        "rotulo": "Desinstalar o MeowSystem",
        "grupo": "Instalação",
        "natureza": "tirar",
        "argv": [os.path.join(RAIZ, "install.sh"), "--uninstall"],
        # `sudo` verdadeiro: a remoção atravessa sudo (o hook de apt do lançador e a
        # ponte root), e declarar falso faria o painel prometer que não pede senha.
        "escreve": True, "sudo": True, "confirma": True, "destrutivo": True,
        "ajuda": "Tira o tema, os ícones e os agendamentos. Não apaga "
                 "backups nem a coleção de imagens.",
    },
    "log": {
        "rotulo": "As últimas 50 linhas do registro",
        "grupo": "Instalação",
        "natureza": "mostrar",
        "argv": _meow("log"),
        "escreve": False, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "O que este projeto escreveu, e quando.",
    },

    # --- a nova versão da máquina --------------------------------------------
    #
    # O comando dela já existia e é uma linha; o que faltava era a SEGUNDA
    # METADE.
    "sistema_ver": {
        "rotulo": "O que a atualização mudaria",
        "grupo": "Atualização",
        "natureza": "mostrar",
        "bloco": "Sistema",
        "argv": [os.path.join(RAIZ, "scripts", "atualizar_sistema.sh"), "ver"],
        "escreve": False, "sudo": False, "confirma": False,
        # O par «ver / aplicar»: ver o `par` do `jogos_heroic`.
        "par": "sistema_atualizar",
        # Era `crates` traduzido ao pé da letra, e a tradução é pior que o
        # original: quem não programa lê "caixas" e procura uma caixa.
        "ajuda": "Os pacotes com versão nova e os programas em Rust "
                 "desatualizados. Não escreve e não pede senha, mas consulta "
                 "o índice do crates.io para saber o que está velho.",
    },
    "sistema_atualizar": {
        "rotulo": "Atualizar a máquina inteira",
        "grupo": "Atualização",
        "natureza": "atualizar",
        "bloco": "Sistema",
        "argv": [os.path.join(RAIZ, "scripts", "atualizar_sistema.sh"), "aplicar"],
        "escreve": True, "sudo": True, "confirma": True, "rede": True,
        # `doctor` é o nome do subcomando no terminal; na tela essa mesma coisa
        # já se chama "Conferir a máquina", e ter dois nomes para um botão é a
        # tela pedindo desconfiança.
        "ajuda": "Atualiza apt, flatpak e cargo, e logo depois faz a conferência "
                 "— que diz o que a atualização desfez do MeowSystem. Demora, e o "
                 "apt mantém os arquivos de configuração que já estão no disco.",
    },
    "sistema_limpar": {
        "rotulo": "Limpar o que sobrou",
        "grupo": "Atualização",
        "natureza": "tirar",
        "bloco": "Sistema",
        "argv": [os.path.join(RAIZ, "scripts", "atualizar_sistema.sh"), "limpar"],
        "escreve": True, "sudo": True, "confirma": True,
        # "CACHE DE DOWNLOAD" -> "os pacotes que o apt já baixou". Cache é
        # palavra de quem programa; o que sai do disco é um monte de arquivo
        # baixado, e dizer isso é mais curto E mais claro.
        "ajuda": "Pacotes órfãos e os pacotes que o apt já baixou. Diz quantos "
                 "megabytes saíram.",
    },
    # --- tema ----------------------------------------------------------------
    "tema": {
        "rotulo": "Temas prontos nesta máquina",
        "grupo": "Cor e tela",
        "natureza": "mostrar",
        "argv": _meow("tema"),
        "escreve": False, "sudo": False, "confirma": False,
        # "Alvo" é palavra de quem escreveu o instalador (o alvo de uma etapa);
        # quem lê a tela escolheu um tema.
        "ajuda": "O tema que você escolheu, o que está mesmo aplicado, e os "
                 "temas prontos que existem.",
    },
    "tema_aplicar": {
        "rotulo": "Trocar de tema",
        "grupo": "Cor e tela",
        "natureza": "trocar",
        "argv": _meow("tema", "@ARG@"), "arg": "capturas",
        # «⋯» de ações técnicas: a moldura do tema, logo acima, já é o
        # gesto de trocar.
        "tecnica": True,
        "escreve": True, "sudo": False, "confirma": False,
        # "POR CÓPIA DE ARQUIVO" era o COMO, e o como não muda nenhuma decisão
        # dela; "captura" saiu pelo motivo da linha de cima.
        "ajuda": "Aplica o tema escolhido, guardando o anterior antes.",
    },
    "tema_modo": {
        "rotulo": "Passar para claro ou escuro",
        "grupo": "Cor e tela",
        "natureza": "trocar",
        "argv": _meow("tema", "@ARG@"), "arg": "modos",
        # «⋯» de ações técnicas: a moldura do tema, logo acima, já é o
        # gesto de trocar.
        "tecnica": True,
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "São o mesmo tema com um interruptor, por isso trocar não "
                 "pisca a interface.",
    },
    # O «Restaurar» de toda ação que escreve: repõe o estado de antes da última
    # execução dela (`restauros`). O argumento é o id da ação; a pasta, o
    # `iniciar` acha.
    "restaurar": {
        "rotulo": "Restaurar",
        "grupo": "Instalação",
        "natureza": "devolver",
        "argv": _meow("restaurar", "@ARG@"), "arg": "restauros",
        "escreve": True, "sudo": False, "confirma": False,
        "oculta": True,
        "ajuda": "Volta ao estado de antes da última vez que esta ação rodou.",
    },
    "desfazer": {
        "rotulo": "Voltar ao tema de antes",
        "grupo": "Instalação",
        "natureza": "devolver",
        "argv": _meow("desfazer"),
        "escreve": True, "sudo": False, "confirma": True, "destrutivo": True,
        "ajuda": "Devolve o COSMIC ao backup feito antes da instalação.",
        # `MEOW_SIM=1` só aqui, e só porque a página já perguntou: o `cmd_desfazer`
        # pede confirmação num `read`, e sem tty ele ficaria esperando para sempre
        # um ENTER que ninguém vai dar.
        "ambiente": {"MEOW_SIM": "1"},
    },
    # --- ícones e gato -------------------------------------------------------
    "icones": {
        "rotulo": "Tema de ícones instalado",
        "grupo": "Ícones",
        "natureza": "mostrar",
        "argv": _meow("icones"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "Qual está selecionado e quantos arquivos ele tem.",
    },
    "icones_reconstruir": {
        "rotulo": "Reconstruir o tema de ícones",
        "grupo": "Ícones",
        "natureza": "aplicar",
        "argv": _meow("icones", "reconstruir"),
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "É o que faz uma troca de variante dos ícones aparecer na "
                 "tela.",
    },
    # O `icones_reconstruir` acima roda `construir_icones.sh` e
    # `construir_pastas.sh` — e NENHUM dos dois toca em `48x48/apps`, que é o
    # diretório dos desenhos em traço.
    "icones_traco": {
        "rotulo": "Pôr os desenhos em traço na tela",
        "grupo": "Ícones",
        "natureza": "aplicar",
        "argv": [os.path.join(RAIZ, "scripts", "icones_apps_arcticons.sh")],
        "escreve": True, "sudo": False, "confirma": False,
        # É a pasta interna do tema de ícones (a convenção hicolor), e saber o
        # nome dela não muda nada para quem clica; o comentário do código, logo
        # acima, continua dizendo qual diretório este script é dono, que é onde
        # a informação serve.
        "ajuda": "Põe no tema os desenhos que os dois acervos de traço trazem "
                 "— é o passo que faz um desenho salvo aqui aparecer.",
    },
    # O «Usar este ícone» com um desenho do pack grava a linha no `apps.map` do
    # pack no ar, e quem põe aquele mapa no tema é o `icones_apps_dracula.sh`,
    # e não o script do traço.
    "icones_pack": {
        "rotulo": "Pôr os desenhos do pack na tela",
        "grupo": "Ícones",
        "natureza": "aplicar",
        "argv": [os.path.join(RAIZ, "scripts", "icones_apps_dracula.sh")],
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Põe no tema os desenhos que o mapa do pack no ar escolhe — é o "
                 "passo que faz um desenho do pack escolhido aqui aparecer.",
    },
    "logo_listar": {
        "rotulo": "Qual mascote está no ar, e por quê",
        "grupo": "Logo do sistema",
        "natureza": "mostrar",
        "argv": _meow("logo", "listar"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "A lista, o mascote em vigor, e qual regra o escolheu.",
    },
    "logo_trocar": {
        "rotulo": "Pôr um mascote no dock",
        "grupo": "Logo do sistema",
        "natureza": "trocar",
        "argv": _meow("logo", "@ARG@"), "arg": "gatos",
        "escreve": True, "sudo": False, "confirma": False,
        # Nela o `logo.sh` guarda o gato do acervo que já está no ar (senão
        # cada `install.sh` desfaria o giro), e o `LOGO` é só o ponto de
        # partida, como o meow.conf.exemplo diz: medido numa casa de brinquedo,
        # com o botão aceso, `rotacao, LOGO=mimir` respondeu «logo já no lugar:
        # morcego-dia», rc 0.
        "indisponivel": _gato_so_nos_modos(("fixo",), "fixo"),
        # Dizia que, por horário, "o relógio devolve o gato dele na virada
        # seguinte".
        "ajuda": "Põe no dock o mascote escolhido, e ele fica. Quando o mascote segue "
                 "o relógio ou gira sozinho, este botão fica apagado e diz onde "
                 "mudar.",
    },
    "logo_girar": {
        "rotulo": "Passar ao próximo mascote",
        "grupo": "Logo do sistema",
        "natureza": "trocar",
        "argv": _meow("logo", "girar"),
        "escreve": True, "sudo": False, "confirma": False,
        # O MESMO APAGAR DO «Pôr um gato no dock».
        "indisponivel": _gato_so_nos_modos(("rotacao",), "rotacao"),
        "ajuda": "Só tem efeito quando o mascote está girando; fora disso o "
                 "botão fica apagado e diz onde mudar.",
    },
    # --- papel de parede -----------------------------------------------------
    "wallpaper": {
        "rotulo": "O carrossel agora",
        "grupo": "Papel de parede",
        "natureza": "mostrar",
        "argv": _meow("wallpaper"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "Pasta, quantas imagens, intervalo, ordem, e se há imagem "
                 "fixada.",
    },
    "wallpaper_proximo": {
        "rotulo": "Próxima imagem",
        "grupo": "Papel de parede",
        "natureza": "trocar",
        "argv": _meow("wallpaper", "proximo"),
        "escreve": True, "sudo": False, "confirma": False,
        # Esta ação é uma das quatro que o cabeçalho da Início oferece como
        # botão, e ali a ajuda vira balão.
        "ajuda": "Avança e fixa a imagem pelo tempo de "
                 "\"Quanto tempo dura a imagem escolhida\".",
    },
    "wallpaper_anterior": {
        "rotulo": "Imagem anterior",
        "grupo": "Papel de parede",
        "natureza": "trocar",
        "argv": _meow("wallpaper", "anterior"),
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "Volta uma imagem, com a mesma fixação.",
    },
    "wallpaper_carrossel": {
        "rotulo": "Voltar a girar",
        "grupo": "Papel de parede",
        "natureza": "trocar",
        "argv": _meow("wallpaper", "carrossel"),
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "Solta a imagem fixada agora, sem esperar o tempo acabar.",
    },
    "wallpaper_aplicar": {
        "rotulo": "Reaplicar as regras do carrossel",
        "grupo": "Papel de parede",
        "natureza": "aplicar",
        "argv": _meow("wallpaper", "aplicar"),
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "Reescreve o estado do papel de parede a partir dos "
                 "ajustes.",
    },
    # É o caso de uso mais visual da página inteira — ver a foto e recusá-la — e
    # ele morria em silêncio, sem torrada, sem erro, sem nada.
    #
    # `oculta` porque elas NÃO SÃO CARTÃO na aba "Fazer": o argumento delas é
    # uma imagem, e escolher imagem é o que a galeria já faz com miniatura.
    "wallpaper_banir": {
        "rotulo": "Tirar esta imagem do carrossel",
        "grupo": "Papel de parede",
        "natureza": "tirar",
        "argv": _meow("wallpaper", "banir", "@ARG@"), "arg": "paredes_ativas",
        "escreve": True, "sudo": False, "confirma": False,
        "destrutivo": True, "oculta": True,
        "ajuda": "Ela sai da pasta que gira e vai para a de banidas. Nada é "
                 "apagado. O “Devolver” da lista de recusadas desfaz.",
    },
    # Até aqui não HAVIA como discordar: `ativos-dia/` e `ativos-noite/` eram
    # separadas só pela luminância medida (`-colorspace Gray` + `%[fx:mean]`
    # contra `WALLPAPER_LIMIAR_LUZ`).
    #
    # São TRÊS ações e não uma com três opções: cada uma é um botão na ficha da
    # imagem, e a ficha não tem espaço para um seletor.
    "wallpaper_usar": {
        "rotulo": "Usar esta imagem agora",
        "grupo": "Papel de parede",
        "natureza": "trocar",
        "argv": _meow("wallpaper", "usar", "@ARG@"), "arg": "paredes_ativas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        # Referência a botão só ajuda se o botão se chamar assim.
        "ajuda": "Fixa esta imagem como o papel de parede de agora. Quanto tempo "
                 "dura é «Quanto tempo dura a imagem escolhida» — com 0, até "
                 "«Voltar a girar».",
    },
    # A galeria tinha a aba «Favoritos» e nenhuma imagem oferecia o gesto.
    # `oculta` pelo motivo das outras desta ficha: o argumento é uma imagem, e
    # quem a escolhe é a galeria.
    "wallpaper_permitir": {
        "rotulo": "Manter a imagem que eu pus",
        "grupo": "Papel de parede",
        "natureza": "gravar",
        "argv": _meow("wallpaper", "permitir", "@ARG@"), "arg": "fontes_revertidas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Autoriza a imagem que você pôs: o carrossel para de devolvê-la.",
    },
    # O «DEIXAR ASSIM». A outra resposta da mesma pendência: tira o cartão
    # sem autorizar a imagem. `oculta` pelo mesmo motivo do «Era escolha
    # minha»: quem o oferece é a pendência.
    "wallpaper_dispensar": {
        "rotulo": "Deixar assim",
        "grupo": "Papel de parede",
        "natureza": "gravar",
        "argv": _meow("wallpaper", "dispensar"),
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "A imagem devolvida fica como está, e o aviso sai da Início.",
    },
    "wallpaper_favoritar": {
        "rotulo": "Guardar nas favoritas",
        "grupo": "Papel de parede",
        "natureza": "gravar",
        "argv": _meow("wallpaper", "favoritar", "@ARG@"), "arg": "paredes_ativas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Guarda uma cópia nas favoritas; a imagem segue girando.",
    },
    "wallpaper_desfavoritar": {
        "rotulo": "Tirar das favoritas",
        "grupo": "Papel de parede",
        "natureza": "tirar",
        "argv": _meow("wallpaper", "desfavoritar", "@ARG@"), "arg": "paredes_favoritas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Tira a cópia das favoritas; a imagem do carrossel fica.",
    },
    "wallpaper_dia": {
        "rotulo": "Guardar esta imagem para o dia",
        "grupo": "Papel de parede",
        "natureza": "gravar",
        "argv": _meow("wallpaper", "lado", "@ARG@", "dia"), "arg": "paredes_ativas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Ela passa a girar só de dia, mesmo que a medição a ache escura. "
                 "O “Deixar a medição decidir” desfaz.",
    },
    "wallpaper_noite": {
        "rotulo": "Guardar esta imagem para a noite",
        "grupo": "Papel de parede",
        "natureza": "gravar",
        "argv": _meow("wallpaper", "lado", "@ARG@", "noite"), "arg": "paredes_ativas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Ela passa a girar só de noite, mesmo que a medição a ache clara. "
                 "O “Deixar a medição decidir” desfaz.",
    },
    "wallpaper_lado_auto": {
        "rotulo": "Deixar a medição decidir",
        "grupo": "Papel de parede",
        "natureza": "gravar",
        "argv": _meow("wallpaper", "lado", "@ARG@", "auto"), "arg": "paredes_ativas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        # Uma palavra por conceito.
        "ajuda": "Tira a escolha e deixa o brilho medido da imagem decidir.",
    },
    # São dois, e o terceiro ("III") saiu e não volta — decisão dela,
    # confirmada.
    "areas_ver": {
        "rotulo": "As áreas de agora",
        "grupo": "Áreas de trabalho",
        "natureza": "mostrar",
        "argv": _meow("areas", "estado"),
        "escreve": False, "sudo": False, "confirma": False,
        # O `id` SAIU DA FRASE. Ele continua na SAÍDA do comando, que é onde
        # serve para alguma coisa; prometê-lo no rótulo obrigava a saber o que
        # é um id de área para entender o que o botão mostra.
        "ajuda": "Nome, ordem e encaixe de cada área. Não escreve nada.",
    },
    "areas_aplicar": {
        "rotulo": "Gravar as áreas",
        "grupo": "Áreas de trabalho",
        "natureza": "gravar",
        "argv": _meow("areas", "aplicar"),
        "escreve": True, "sudo": False, "confirma": False,
        # Sem área fixada ele sai PULADO e manda a um «Resolver» que não está
        # nesta aba. A ordem passa a ser da tela: apagado, com o nome do
        # botão que vem antes. Ver `_areas_sem_alfinete`.
        "indisponivel": _areas_sem_alfinete,
        # Nenhum outro texto desta página grita, e o aviso não fica mais fraco
        # em caixa baixa: quem o lê está com o dedo no botão.
        "ajuda": "Vale no próximo início de sessão: o cosmic-comp lê esse arquivo "
                 "uma vez, ao iniciar. Nada muda no painel agora, e isso não é defeito.",
    },
    # O PRIMEIRO ALFINETE É a ação para onde a pendência
    # `areas-sem-alfinete` aponta: sem nenhuma área fixada o `Gravar as
    # áreas` não tinha de onde herdar o monitor e parava.
    "areas_alfinetar_primeira": {
        "rotulo": "Criar a primeira área",
        "grupo": "Áreas de trabalho",
        "natureza": "gravar",
        "argv": _meow("areas", "alfinetar-primeira"),
        "escreve": True, "sudo": False, "confirma": True,
        "indisponivel": _areas_ja_alfinetadas,
        "ajuda": "Cria a primeira área fixada no monitor que está ligado agora, "
                 "com o primeiro nome da sua lista. Vale no próximo início de sessão.",
    },
    "areas_reverter": {
        "rotulo": "Voltar as áreas de antes",
        "grupo": "Áreas de trabalho",
        "natureza": "devolver",
        "argv": _meow("areas", "reverter"),
        "escreve": True, "sudo": False, "confirma": True,
        "ajuda": "Devolve o arquivo como estava antes da primeira gravação daqui.",
    },
    "areas_desalfinetar": {
        "rotulo": "Tirar uma área",
        "grupo": "Áreas de trabalho",
        "natureza": "tirar",
        "argv": _meow("areas", "desalfinetar", "@ARG@"), "arg": "areas",
        "escreve": True, "sudo": False, "confirma": True, "destrutivo": True,
        # O ALFINETE É O QUE SEGURA A ÁREA: sem ele o cosmic-comp a destrói
        # assim que ela esvazia. Não é "esconder", é apagar — daí `destrutivo` e
        # a confirmação.
        "ajuda": "Apaga a área: o nome some e o COSMIC a destrói quando ela esvaziar.",
        "ambiente": {"MEOW_SIM": "1"},
    },
    "wallpaper_desbanir": {
        "rotulo": "Devolver uma imagem tirada",
        "grupo": "Papel de parede",
        "natureza": "devolver",
        "argv": _meow("wallpaper", "desbanir", "@ARG@"), "arg": "paredes_banidas",
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Volta para a pasta que gira e sai da lista de banidas — as "
                 "duas metades.",
    },
    "wallpaper_semear": {
        "rotulo": "Baixar a coleção curada",
        "grupo": "Papel de parede",
        "natureza": "baixar",
        "argv": _meow("wallpaper", "semear"),
        "escreve": True, "sudo": False, "confirma": True, "rede": True,
        "ajuda": "Reconstrói a coleção a partir da lista de fontes. Usa rede "
                 "e pode demorar. As imagens que você tirou continuam fora.",
    },
    # --- painel, janelas, leitura --------------------------------------------
    "painel_estado": {
        # O rótulo repetia o nome da aba em que ele já está ("Painel e dock:")
        # e gastava a metade que sobrava numa palavra de oficina.
        "rotulo": "Como estão o painel e a dock",
        "grupo": "Painel e dock",
        "natureza": "mostrar",
        "argv": _meow("painel", "estado"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "O estado do painel, da dock e do serviço que cuida dos dois.",
    },
    "painel_teto": {
        "rotulo": "Até quanto o canto pode arredondar",
        "grupo": "Painel e dock",
        "natureza": "mostrar",
        "argv": _meow("painel", "teto"),
        "escreve": False, "sudo": False, "confirma": False,
        # "TETO DERIVADO" SAIU. "Derivado" só diz alguma coisa a quem já sabe
        # que o teto sai de uma conta; escrito por extenso, a frase ensina a
        # conta em vez de nomeá-la.
        "ajuda": "A conta inteira: a altura de verdade, o teto que sai dela, e "
                 "se o compositor corta o excesso em vez de derrubar o painel.",
    },
    "painel_reciclar": {
        "rotulo": "Recarregar o painel",
        "grupo": "Painel e dock",
        "natureza": "reciclar",
        "argv": _meow("painel", "reciclar"),
        "escreve": True, "sudo": False, "confirma": False,
        # "sem esperar o próximo login" virou "na hora" — a espera que se evita
        # é a do login, mas quem lê o balão quer saber é quando vê o gato.
        "ajuda": "O painel pisca uns 2 s. É o que faz um mascote novo "
                 "aparecer na hora.",
    },
    # A receita `curl | sh` que o `scripts/prompt.sh` imprimia virou este
    # botão.
    "prompt_instalar_starship": {
        "rotulo": "Instalar o starship",
        "grupo": "Terminal",
        "natureza": "baixar",
        "argv": [os.path.join(RAIZ, "scripts", "prompt.sh"), "instalar-starship"],
        "escreve": True, "sudo": False, "confirma": True, "rede": True,
        "indisponivel": _starship_ja_instalado,
        "ajuda": "Baixa o starship de starship.rs para ~/.local/bin, sem sudo. "
                 "Ele não está no apt do Pop!_OS, e é ele que desenha o prompt.",
    },
    "leitura": {
        "rotulo": "Modo de leitura agora",
        "grupo": "Modo de leitura",
        "natureza": "mostrar",
        "argv": _meow("leitura"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "Que degrau o relógio pede, o que a tela mostra, e se o "
                 "compositor sabe ler os dois números.",
    },
    "leitura_aplicar": {
        "rotulo": "Aplicar o degrau desta hora",
        "grupo": "Modo de leitura",
        "natureza": "aplicar",
        "argv": _meow("leitura", "aplicar"),
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "Põe agora o que o agendamento poria sozinho.",
    },
    "leitura_remover": {
        "rotulo": "Desligar o modo de leitura",
        "grupo": "Modo de leitura",
        "natureza": "tirar",
        "argv": _meow("leitura", "remover"),
        "escreve": True, "sudo": False, "confirma": True,
        "ajuda": "Zera temperatura e textura, e desarma o agendamento.",
    },
    "files_menu": {
        "rotulo": "Menu da área de trabalho",
        "grupo": "Papel de parede",
        "natureza": "mostrar",
        "argv": _meow("files-menu"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "Os dois itens de papel de parede no botão direito.",
    },
    # É para onde aponta a pendência `files-menu-build` quando o auto-build
    # esgota as tentativas ou a última falha: antes disso a linha só carrega o
    # estado (`construindo`) e não tem botão, porque não há o que clicar
    # enquanto a unit trabalha.
    "files_menu_build": {
        "rotulo": "Construir o menu da área de trabalho",
        "grupo": "Papel de parede",
        "natureza": "baixar",
        "argv": _meow("files-menu", "build"),
        "escreve": True, "sudo": False, "confirma": True, "rede": True,
        "ajuda": "Compila a versão instalada do cosmic-files com os dois itens "
                 "de papel de parede. Baixa o fonte e leva minutos.",
    },
    # --- aplicativos ---------------------------------------------------------
    "apps": {
        # Módulo é como o `bin/meow` organiza o próprio código; na tela ele
        # nomeava uma coluna que quem lê não tem como interpretar.
        "rotulo": "Quais programas estão vestidos",
        "grupo": "Lançadores e jogos",
        "natureza": "conferir",
        "argv": _meow("apps"),
        "escreve": False, "sudo": False, "confirma": False,
        "ajuda": "Um por linha: se está instalado, e se o tema já foi aplicado.",
    },
    "apps_aplicar": {
        "rotulo": "Vestir os programas agora",
        "grupo": "Lançadores e jogos",
        "natureza": "aplicar",
        "argv": _meow("apps", "aplicar"),
        "escreve": True, "sudo": False, "confirma": False,
        "ajuda": "Aplica o tema em todos os programas marcados que estiverem "
                 "instalados. Programa ausente fica pendente, e nunca "
                 "derruba o resto.",
    },
    # Os dois botões da pendência `<app>-tema-de-terceiro`.
    "apps_tema_do_pack": {
        "rotulo": "Trocar pelo tema do pack",
        "grupo": "Lançadores e jogos",
        "natureza": "trocar",
        "argv": _meow("apps", "aplicar", "@ARG@"), "arg": "apps_de_terceiro",
        "ambiente": {"MEOW_TEMA_DE_TERCEIRO": "trocar"},
        "escreve": True, "sudo": False, "confirma": True, "destrutivo": True,
        "oculta": True,
        "ajuda": "Troca o tema que o programa tem agora pelo do pack no ar.",
    },
    "apps_manter_o_meu": {
        "rotulo": "Manter o meu tema",
        "grupo": "Lançadores e jogos",
        "natureza": "gravar",
        "argv": _meow("apps", "aplicar", "@ARG@"), "arg": "apps_de_terceiro",
        "ambiente": {"MEOW_TEMA_DE_TERCEIRO": "manter"},
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "O tema de agora fica, e o MeowSystem para de perguntar "
                 "enquanto o programa estiver nele.",
    },
    # Só o pack do `packs/` do repositório instala extensão sozinho; o importado
    # pede, e o módulo deixa a pendência `vscode-extensao-de-terceiro`.
    "vscode_instalar_extensao": {
        "rotulo": "Instalar a extensão do VS Code",
        "grupo": "Lançadores e jogos",
        "natureza": "baixar",
        "argv": _meow("apps", "aplicar", "vscode"), "arg": "extensoes_de_terceiro",
        "ambiente": {"MEOW_VSCODE_EXTENSAO": "@ARG@"},
        "escreve": True, "sudo": False, "confirma": True, "rede": True,
        "oculta": True,
        "ajuda": "Instala no VS Code, da loja oficial e pelo id do botão, a extensão "
                 "que o pack importado pede. Extensão é código que roda a cada "
                 "abertura do editor.",
    },
    # É a ação para onde a pendência `spicetify-tema-ausente` aponta.
    "spotify_baixar_tema": {
        "rotulo": "Baixar o tema do Spotify",
        "grupo": "Lançadores e jogos",
        "natureza": "baixar",
        "argv": _meow("apps", "aplicar", "spotify"),
        "escreve": True, "sudo": False, "confirma": True, "rede": True,
        "ajuda": "Baixa o tema catppuccin do spicetify de um commit fixo do "
                 "repositório público e veste o Spotify em seguida.",
    },
    # --- os jogos da Steam ---------------------------------------------------
    # `confirma` é True no aplicar porque uma linha `apagar` no mapa manda o
    # script remover os arquivos do jogo.
    "jogos": {
        "rotulo": "Ver o que mudaria nos jogos",
        "grupo": "Lançadores e jogos",
        "natureza": "conferir",
        "argv": [os.path.join(RAIZ, "scripts", "jogos_steam.sh"), "--conferir"],
        "escreve": False, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Lista atalho a criar, atalho a remover e arquivo a apagar. "
                 "Não escreve nada.",
    },
    "jogos_aplicar": {
        "rotulo": "Arrumar os jogos no lançador",
        "grupo": "Lançadores e jogos",
        "natureza": "aplicar",
        "argv": [os.path.join(RAIZ, "scripts", "jogos_steam.sh")],
        "escreve": True, "sudo": False, "confirma": True, "destrutivo": True,
        "oculta": True,
        "ajuda": "Põe um atalho por jogo instalado e tira o dos que saíram. "
                 "Jogo marcado para apagar tem a pasta removida — uma vez "
                 "só, e nunca com a Steam aberta.",
    },
    # --- os jogos do Heroic --------------------------------------------------
    # Estas DUAS aparecem no menu, ao contrário das da Steam: não há uma tela
    # "Jogos do Heroic" com a grade de capas, então não há nome repetido a
    # evitar.
    "jogos_heroic": {
        "rotulo": "Ver o que mudaria nos jogos do Heroic",
        "grupo": "Lançadores e jogos",
        "natureza": "conferir",
        "argv": [os.path.join(RAIZ, "scripts", "jogos_heroic.sh"), "--conferir"],
        "escreve": False, "sudo": False, "confirma": False,
        # O ver ficava aberto e o aplicar ia para o «⋯» de ações técnicas: dois
        # lugares para uma decisão só.
        "par": "jogos_heroic_aplicar",
        "ajuda": "Lista atalho a criar e atalho a remover. Não escreve nada.",
    },
    "jogos_heroic_aplicar": {
        "rotulo": "Pôr os jogos do Heroic no lançador",
        "grupo": "Lançadores e jogos",
        "natureza": "aplicar",
        "argv": [os.path.join(RAIZ, "scripts", "jogos_heroic.sh"), "--aplicar"],
        "escreve": True, "sudo": False, "confirma": False,
        # O cartão mora na seção dos jogos, ao lado das capas.
        "oculta": True,
        "ajuda": "Um atalho por jogo instalado no Heroic, com a capa que ele "
                 "já baixou. Some o do jogo desinstalado.",
    },
    # Os dois lados do interruptor «no lançador» de um jogo do Heroic: o script
    # grava a lista e arruma o lançador na mesma passada.
    "jogos_heroic_tirar": {
        "rotulo": "Tirar o jogo do Heroic do lançador",
        "grupo": "Lançadores e jogos",
        "natureza": "tirar",
        "argv": [os.path.join(RAIZ, "scripts", "jogos_heroic.sh"), "--aplicar"],
        "arg": "jogos_heroic", "ambiente": {"MEOW_HEROIC_TIRAR": "@ARG@"},
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "O cartão do jogo sai do lançador; o jogo continua no Heroic.",
    },
    "jogos_heroic_por": {
        "rotulo": "Pôr o jogo do Heroic no lançador",
        "grupo": "Lançadores e jogos",
        "natureza": "aplicar",
        "argv": [os.path.join(RAIZ, "scripts", "jogos_heroic.sh"), "--aplicar"],
        "arg": "jogos_heroic", "ambiente": {"MEOW_HEROIC_POR": "@ARG@"},
        "escreve": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "O cartão do jogo volta ao lançador.",
    },
}


# --- 5b. AS PRÉVIAS: ver o efeito antes de escolher --------------------------
#
# Sem as imagens fica difícil."
#
# Para uma chave como `LOG_NIVEL` isso basta; para `LOGO_DIA`, `FLAVOR` ou um
# papel de parede, é pedir que ela decida no escuro e descubra o efeito DEPOIS
# de aplicar.
#
# imagens somando 134 MB nesta máquina — a maior tem 7,1 MB.
CACHE = os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
    "meowsystem", "painel",
)

# `svg` é servido COMO ESTÁ, sem conversão nenhuma, e isso não é preguiça: o
# navegador desenha SVG melhor do que o `rsvg-convert` desenharia para ele, em
# qualquer tamanho, e sem gerar arquivo.
EXT_DIRETAS = {".svg"}
EXT_RASTER = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".avif"}


def _cursor_para_rgba(caminho, tamanho_alvo=48):
    """Decodifica um arquivo XCursor e devolve (largura, altura, bytes RGBA).

    POR QUE ESTE DECODIFICADOR EXISTE
        O `CURSOR` é a chave cujo comentário no `meow.conf.exemplo` avisa, com
        medição, que O NOME MENTE SOBRE A COR: em `catppuccin-mocha-mauve` é o
        CORPO que recebe o accent e o contorno que recebe a Base, o oposto do
        que se espera — e por isso o `latte-mauve`, escolhido em 25/08/2026 sob
        a premissa de que "só o Latte tem corpo claro", é justamente o pior sobre
        papel de parede escuro. Uma chave assim é a que MAIS precisa de prévia.
        Aquela medição foi feita "decodificando o XCursor" à mão, uma vez, e o
        resultado virou uma tabela no comentário; aqui o mesmo trabalho vira
        imagem, toda vez, do arquivo que está instalado.

        Medido em 01/09/2026: o ImageMagick desta máquina NÃO lê XCursor
        (`no decode delegate for this image format`), e o `xcur2png` não está
        instalada. O formato, porém, é simples e está documentado — e são 30
        linhas.

    O FORMATO, resumido: cabeçalho `Xcur` + tamanho do cabeçalho + versão +
    número de entradas; depois uma tabela em que cada entrada é
    (tipo, subtipo, posição). Imagem é tipo `0xfffd0002`, e o subtipo é o
    TAMANHO NOMINAL em pixels. No bloco da imagem vêm largura, altura, os dois
    pontos quentes, o atraso (é cursor animado) e então largura×altura inteiros
    de 32 bits em ARGB little-endian — ou seja, os bytes na ordem B, G, R, A.
    """
    with open(caminho, "rb") as fh:
        dados = fh.read()
    if len(dados) < 16 or dados[:4] != b"Xcur":
        return None
    cab, _versao, n = struct.unpack_from("<III", dados, 4)
    melhor = None
    for i in range(n):
        base = cab + i * 12
        if base + 12 > len(dados):
            break
        tipo, subtipo, pos = struct.unpack_from("<III", dados, base)
        if tipo != 0xFFFD0002:
            continue
        # O tamanho mais próximo do alvo, preferindo o que não é maior — um
        # cursor de 96 px reduzido a 48 fica mole; o de 48 é nítido.
        peso = (0 if subtipo <= tamanho_alvo else 1, abs(subtipo - tamanho_alvo))
        if melhor is None or peso < melhor[0]:
            melhor = (peso, pos)
    if melhor is None:
        return None

    pos = melhor[1]
    if pos + 36 > len(dados):
        return None
    # cabeçalho do bloco: tamanho, tipo, subtipo, versão, largura, altura, xhot,
    # yhot, delay — nove inteiros de 32 bits.
    _t, _tipo, _sub, _v, larg, alt, _xh, _yh, _atraso = struct.unpack_from("<9I", dados, pos)
    if not (0 < larg <= 512 and 0 < alt <= 512):
        return None
    inicio = pos + 36
    fim = inicio + larg * alt * 4
    if fim > len(dados):
        return None

    # ARGB little-endian -> os bytes vêm B,G,R,A. E o alfa é PRÉ-MULTIPLICADO
    # (é o que a spec do XCursor manda), então desfazê-lo é o que evita a borda
    # escura que apareceria em toda silhueta.
    cru = dados[inicio:fim]
    saida = bytearray(len(cru))
    for i in range(0, len(cru), 4):
        b, g, r, a = cru[i], cru[i + 1], cru[i + 2], cru[i + 3]
        if a and a != 255:
            r = min(255, r * 255 // a)
            g = min(255, g * 255 // a)
            b = min(255, b * 255 // a)
        saida[i], saida[i + 1], saida[i + 2], saida[i + 3] = r, g, b, a
    return (larg, alt, bytes(saida))


# --- os provedores: cada um lista o que existe NO DISCO agora ----------------
def _prev_gatos():
    pasta = _pasta_do_mascote()
    fora = []
    for nome in _gatos():
        caminho = os.path.join(pasta, nome + ".svg")
        if os.path.isfile(caminho):
            fora.append({"id": nome, "rotulo": nome, "origem": caminho, "grupo": "acervo"})
    return fora


def _wallpaper_base():
    base = valores_efetivos(["WALLPAPER_BASE"]).get("WALLPAPER_BASE") or ""
    return base or os.path.expanduser("~/.local/share/backgrounds/meowsystem")


# Os cinco grupos do acervo e a pasta de cada um.
GRUPOS_PAREDE = (("ativos", "ativos"), ("noite", "ativos-noite"),
                 ("dia", "ativos-dia"), ("favoritos", "favoritos"),
                 ("banidos", "banidos"))


# O `lado.tsv` guarda a ESCOLHA: quem não está lá é separado pela luminância.
#
# Ele seria um botão que não faz nada em quase todos os casos, e um botão assim
# ensina a não confiar nos outros.
_LADO_CACHE = {"mapa": {}, "marca": None}


def _lado_caminho():
    estado = os.path.join(
        os.environ.get("MEOW_ESTADO")
        or os.path.join(os.path.expanduser("~"), ".local", "state", "meowsystem"),
        "papeis-de-parede")
    if os.path.isdir(estado):
        return os.path.join(estado, "lado.tsv")
    return os.path.join(RAIZ, "packs", "meowsystem", "wallpapers", "lado.tsv.padrao")


def _lado_escrito():
    caminho = _lado_caminho()
    try:
        marca = os.path.getmtime(caminho)
    except OSError:
        _LADO_CACHE["mapa"], _LADO_CACHE["marca"] = {}, None
        return {}
    # O CAMINHO ENTRA NA MARCA porque ele passou a variar (estado ou `.padrao`),
    # e o `cp -p` da semeadura PRESERVA o mtime: sem o caminho, a troca de um
    # pelo outro seria invisível para este cache.
    marca = (caminho, marca)
    if _LADO_CACHE["marca"] == marca:
        return _LADO_CACHE["mapa"]
    mapa = {}
    try:
        with open(caminho, "r", encoding="utf-8", errors="replace") as fh:
            for linha in fh:
                linha = linha.strip()
                if not linha or linha.startswith("#"):
                    continue
                partes = linha.split("\t")
                if len(partes) == 2 and partes[1] in ("dia", "noite"):
                    mapa[partes[0]] = partes[1]
    except OSError:
        mapa = {}
    _LADO_CACHE["mapa"], _LADO_CACHE["marca"] = mapa, marca
    return mapa


def _prev_paredes():
    """Os cinco grupos do acervo. `banidos/` entra porque desbanir é um clique."""
    base = _wallpaper_base()
    escolhas = _lado_escrito()
    fora = []
    for grupo, pasta in GRUPOS_PAREDE:
        caminho = os.path.join(base, pasta)
        try:
            nomes = sorted(os.listdir(caminho))
        except OSError:
            continue
        for nome in nomes:
            arq = os.path.join(caminho, nome)
            if os.path.splitext(nome)[1].lower() not in EXT_RASTER:
                continue
            if not os.path.isfile(arq):
                continue
            # O id carrega o grupo porque o MESMO nome existe em `ativos/` e em
            # `ativos-noite/` — são link duro para o mesmo arquivo, e sem o
            # prefixo um id apontaria para dois lugares.
            # Banir é `mv` do caminho recebido: pelo link duro de `ativos-noite/` sairia só o
            # link, e a imagem de `ativos/` seguiria girando. Por isso `banir` é o canônico.
            canonico = os.path.join(base, "ativos", nome)
            fora.append({"id": grupo + "/" + nome, "rotulo": nome,
                         "origem": arq, "grupo": grupo,
                         # `""` quando a medição é que decide — é o caso comum,
                         # e é o que faz o botão de desfazer não aparecer.
                         "lado": escolhas.get(nome, ""),
                         "favorito": os.path.isfile(os.path.join(base, "favoritos", nome)),
                         "banir": canonico if os.path.isfile(canonico) else ""})
    return fora


def _prev_icones():
    """Os ícones do tema que está INSTALADO — não os do repositório.

    A diferença é a lição de `lib/comum.sh`: "está instalado?" e "está na tela
    dela?" são perguntas diferentes. O que vale mostrar é o que o lançador
    desenha agora, que é o conteúdo de `~/.local/share/icons/<tema>/`.
    """
    tema = valores_efetivos(["NOME_TEMA_ICONES"]).get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
    raiz = os.path.join(os.path.expanduser("~/.local/share/icons"), os.path.basename(tema))
    fora, vistos = [], set()
    for sub in ("48x48/apps", "scalable/apps", "64x64/apps"):
        pasta = os.path.join(raiz, sub)
        try:
            nomes = sorted(os.listdir(pasta))
        except OSError:
            continue
        for nome in nomes:
            base, ext = os.path.splitext(nome)
            if ext.lower() not in EXT_DIRETAS | EXT_RASTER or base in vistos:
                continue
            vistos.add(base)
            fora.append({"id": base, "rotulo": base,
                         "origem": os.path.join(pasta, nome), "grupo": sub})
    return fora


@_uma_vez_por_leitura
def _prev_cursores():
    """Um item por ponteiro que a chave `CURSOR` de fato SABE escolher.

    O QUE ESTA FUNÇÃO DESENHAVA ANTES, E O QUE ISSO CUSTAVA — 01/09/2026
        Ela enumerava todo diretório com uma pasta `cursors/` dentro e ainda
        acrescentava um apelido curto como SEGUNDA opção clicável. Na tela isso
        virava quatro ponteiros, dos quais TRÊS gravavam um valor que o
        `scripts/cursor.sh` não resolve — e dois deles eram o mesmo cursor com
        nomes diferentes, um funcionando e o outro não. A conta está em
        `_temas_de_cursor`, que agora é a única a decidir quem entra.

        O apelido não some: ele vira o CAMINHO por onde se acha o arquivo (o
        valor `catppuccin-mocha-light` mora em `catppuccin-mocha-light-cursors`),
        que era o problema legítimo que ele veio resolver. O que ele deixa de
        ser é uma opção a mais para clicar.

    O PARÁGRAFO QUE ESTAVA AQUI DESCREVIA UM MUNDO DE 01/09 — 21/09/2026
        Ele dizia: "diretório que não termine em `-cursors` — Adwaita, Pop,
        breeze — fica de fora da lista, e isso não é perda: escolhê-los NUNCA
        funcionou". Deixou de ser verdade em 15/09, quando o `cursor.sh` ganhou
        o `_cursor_dir_exato` e o `_temas_de_cursor` passou a aceitar nome
        exato. O texto seguia descrevendo o mundo que a irmã dele já tinha
        mudado — e o código abaixo dele também: montava `<valor>-cursors`
        sempre. Medido nesta máquina, em 21/09: `_temas_de_cursor` devolvia
        QUATRO valores e esta função desenhava UM. `Adwaita`, `Pop` e
        `Dracula-Cursor` viravam botão sem desenho.

        E foi medido ANTES de mexer aqui que mostrá-los não promete um clique
        que quebra: `_cursor_instalado` (cursor.sh:302) acha os três no disco
        pelo nome exato, então escolher qualquer um deles aplica sem tocar a
        rede. Prévia de ponteiro que quebrasse ao ser clicado seria pior que
        prévia nenhuma.

    A REGRA, HOJE, É A DO `_cursor_pastas_do_valor`
        Nome exato primeiro, convenção `<valor>-cursors` depois, e `cursors/`
        dentro exigido nos dois casos — a mesma função que o `_temas_de_cursor`
        consulta, para que a lista de botões e a lista de desenhos não tenham
        mais como divergir. Um tema listado sem ponteiro decodificável não vira
        item aqui; o cartão dele fica sem prévia, e a página desenha a silhueta
        de um ponteiro em traço (o `controleImagem`, em app.js), porque cartão
        vazio é indistinguível de cartão quebrado.
    """
    fora = []
    do_pack = _ponteiro_do_pack()
    for valor in _temas_de_cursor():
        alvo = None
        # Não basta a PRIMEIRA raiz que tem `<nome>/cursors`: ela pode ter a
        # pasta e não ter ponteiro decodificável dentro.
        for pasta_tema in _cursor_pastas_do_valor(valor, do_pack):
            # `default` é o nome canônico e `left_ptr` o histórico; um costuma
            # ser link simbólico para o outro, e qualquer um serve.
            for cand in ("left_ptr", "default"):
                caminho = os.path.join(pasta_tema, "cursors", cand)
                if os.path.isfile(caminho):
                    alvo = os.path.realpath(caminho)
                    break
            if alvo:
                break
        if alvo:
            fora.append({"id": valor, "rotulo": valor, "origem": alvo,
                         "grupo": "cursor"})
    return fora


def _tipo_de_previa(chave, opcoes, faixa, padrao):
    """Que prévia visual esta chave merece — DEDUZIDO, nunca listado.

    A tentação era escrever aqui um dicionário `{"FLAVOR": "flavor", "LOGO":
    "gato", ...}`. Seria a quarta lista de chaves do projeto, e a armadilha nº 3
    já cobrou duas vezes no `bin/meow`: lista fixa é lista que alguém esquece, e
    o sintoma seria uma chave nova nascendo sem prévia justamente na página que
    existe para ter prévia.

    Então a pergunta é feita ao CONTEÚDO da chave, não ao nome dela:

      - as opções são os gatos que existem em `packs/meowsystem/mascote/`?  -> desenho do gato
      - as opções são os flavors da paleta?                     -> amostra do flavor
      - as opções são nomes de cor do Catppuccin?               -> bolinha da cor
      - o valor é um tema de cursor que está instalado?         -> o ponteiro de verdade
      - a faixa declarada vai de ~1000 a ~6500?                 -> é Kelvin, simula a tela
      - a faixa vai de 0 a 1 e a chave é de textura?            -> simula o papel

    Chave nova que caia em qualquer um desses padrões ganha prévia sozinha. E
    quando NENHUM casa, a resposta é `""` — e a página diz, em uma linha, que
    aquela opção não tem prévia honesta, em vez de deixar um retângulo vazio.

    O ÚNICO PREFIXO QUE ENTRA AQUI é `FORMA_`/`VIDRO_`, e ele não é uma lista de
    chaves: é a convenção de nomes que o próprio `meow.conf.exemplo` usa para as
    dezoito chaves que descrevem a GEOMETRIA das barras. Elas não têm imagem
    para mostrar — o que existe é a barra desenhada na própria página, nos
    valores escolhidos, que é mais honesto que um print porque acompanha o
    controle deslizante ao vivo.
    """
    if opcoes:
        conjunto = set(opcoes)
        gatos = set(_gatos())
        if gatos and conjunto <= gatos:
            return "gato"
        paleta = _paleta_dados()
        flavors = set(paleta.get("flavors", {}))
        if flavors and conjunto <= flavors:
            return "flavor"
        cores = set(paleta.get("ordem_canonica") or [])
        if cores and conjunto <= cores:
            return "cor"
    # UMA COR PODE SER DECLARADA SEM LISTA, e duas chaves fazem isso: o
    # `MIDIA_COR_TITULO` e o `MIDIA_COR_ARTISTA` dizem em prosa "vale qualquer
    # nome da paleta" e listam os nomes separados por vírgula, que não é o
    # formato `a | b | c` que vira lista de opções. Sem esta regra elas ficavam
    # como campo de texto onde ela teria de digitar `lavender` de cabeça — numa
    # página cujo motivo de existir é escolher cor olhando.
    if not opcoes and padrao in set(_paleta_dados().get("ordem_canonica") or []):
        return "cor"
    if chave.startswith("FORMA_") or chave.startswith("VIDRO_"):
        return "barra"
    # `AREAS_FOLGA` é a lista das áreas que ganham o espaço-figura.
    if chave == "AREAS_FOLGA":
        return "areas"
    # Era decidida pela FAIXA: "1000 a 6500" virava kelvin, "0.0 a 1.0" virava
    # textura.
    #
    # Contadas hoje, QUATRO chaves declaram uma dessas duas faixas, e só duas
    # são do modo de leitura; as outras são a opacidade do vidro do painel e da
    # dock, que herdariam o mesmo desenho errado assim que ganhassem um valor.
    if chave.startswith("LEITURA_") and faixa:
        lo, hi = faixa[0], faixa[1]
        if lo <= 2000 and 5000 <= hi <= 10000:
            return "kelvin"
        if lo == 0 and hi == 1:
            return "textura"
    # Um tema de cursor instalado no disco: a resposta vem do disco, e por isso
    # ela continua certa no dia em que o acervo mudar de nome.
    if padrao and any(c["id"] == padrao for c in _prev_cursores()):
        return "cursor"
    return ""


PREVIA_FONTES = {
    "gato": _prev_gatos,
    "parede": _prev_paredes,
    "icone": _prev_icones,
    "cursor": _prev_cursores,
}
# Os grupos que um tipo TEM, mesmo os vazios. Só o papel de parede se divide em
# grupos fixos (as cinco pastas do acervo); os outros descobrem o grupo item a
# item.
PREVIA_GRUPOS = {"parede": [g for g, _pasta in GRUPOS_PAREDE]}
# A largura da miniatura, por tipo. O papel de parede é o único que precisa ser
# grande o bastante para ela reconhecer a foto; o resto é ícone e cabe pequeno.
PREVIA_LARGURA = {"parede": 320, "gato": 0, "icone": 0, "cursor": 96}


def _previa_chave(item, tipo):
    """A identidade da prévia inclui mtime e tamanho — é o que a faz não envelhecer."""
    try:
        st = os.stat(item["origem"])
    except OSError:
        return None
    cru = "%s|%s|%s|%s" % (item["origem"], st.st_mtime_ns, st.st_size,
                           PREVIA_LARGURA.get(tipo, 0))
    return hashlib.sha1(cru.encode("utf-8")).hexdigest()


def _previa_destino(item, tipo):
    chave = _previa_chave(item, tipo)
    if chave is None:
        return None
    ext = ".png" if tipo == "cursor" else ".webp"
    return os.path.join(CACHE, tipo, chave + ext)


def _previa_direta(item):
    """Serve o arquivo como está — vale para SVG, que o navegador desenha melhor."""
    return os.path.splitext(item["origem"])[1].lower() in EXT_DIRETAS


def _previa_pronta(item, tipo):
    if _previa_direta(item):
        return True
    destino = _previa_destino(item, tipo)
    return bool(destino) and os.path.isfile(destino)


def _gerar_previa(item, tipo):
    """Converte de verdade. Roda SEMPRE num operário, nunca na thread do pedido."""
    destino = _previa_destino(item, tipo)
    if destino is None or os.path.isfile(destino):
        return
    os.makedirs(os.path.dirname(destino), exist_ok=True)
    # Escreve num temporário e renomeia: sem isso, uma página que pedisse a
    # imagem no meio da conversão receberia um arquivo pela metade — e o
    # navegador guardaria ESSE como a miniatura.
    tmp = destino + ".parcial"
    try:
        if tipo == "cursor":
            desenho = _cursor_para_rgba(item["origem"], PREVIA_LARGURA["cursor"])
            if not desenho:
                return
            larg, alt, rgba = desenho
            subprocess.run(
                ["convert", "-size", "%dx%d" % (larg, alt), "-depth", "8",
                 "rgba:-", "-background", "none",
                 "-resize", "%dx%d>" % (PREVIA_LARGURA["cursor"], PREVIA_LARGURA["cursor"]),
                 "png:" + tmp],
                input=rgba, capture_output=True, timeout=30, check=True,
            )
        else:
            largura = PREVIA_LARGURA.get(tipo, 320) or 320
            subprocess.run(
                ["convert", "-auto-orient", "-thumbnail", "%dx" % largura,
                 "-quality", "82", item["origem"], "webp:" + tmp],
                capture_output=True, timeout=60, check=True,
            )
        os.replace(tmp, destino)
    except (OSError, subprocess.SubprocessError):
        try:
            os.unlink(tmp)
        except OSError:
            pass


# --- os operários -----------------------------------------------------------
# TRÊS, e o número tem motivo: o `convert` é limitado por CPU e a máquina tem
# núcleos de sobra, mas subir isso a dez faria a conversão das 46 miniaturas
# disputar CPU com o `./install.sh` que ela pode ter disparado na mesma página.
PREVIA_FILA = queue.Queue()
PREVIA_ANDANDO = set()
PREVIA_TRAVA = threading.Lock()


def _operario():
    while True:
        item, tipo, chave = PREVIA_FILA.get()
        try:
            _gerar_previa(item, tipo)
        finally:
            with PREVIA_TRAVA:
                PREVIA_ANDANDO.discard(chave)
            PREVIA_FILA.task_done()


def _enfileirar(item, tipo):
    chave = _previa_chave(item, tipo)
    if chave is None:
        return
    with PREVIA_TRAVA:
        if chave in PREVIA_ANDANDO:
            return
        PREVIA_ANDANDO.add(chave)
    PREVIA_FILA.put((item, tipo, chave))


def previas(tipo, grupo=None):
    """A lista do tipo pedido, já dizendo o que está pronto, e enfileirando o resto."""
    fonte = PREVIA_FONTES.get(tipo)
    if fonte is None:
        return None
    itens = fonte()
    if tipo == "parede":
        itens = [i for i in itens if not (i["grupo"] == "banidos" and i["banir"])]
    contagens = {g: 0 for g in PREVIA_GRUPOS.get(tipo, ())}
    for i in itens:
        contagens[i["grupo"]] = contagens.get(i["grupo"], 0) + 1
    total = len(itens)
    if grupo:
        itens = [i for i in itens if i["grupo"] == grupo]
    fora, faltam = [], 0
    for item in itens:
        pronta = _previa_pronta(item, tipo)
        if not pronta:
            faltam += 1
            _enfileirar(item, tipo)
        saida = {
            "id": item["id"], "rotulo": item["rotulo"], "grupo": item["grupo"],
            "pronta": pronta, "origem": item["origem"],
            "url": "/previa?tipo=%s&id=%s" % (tipo, quote(item["id"], safe="")),
        }
        # O comentário aqui já prometia isso ("a próxima fonte que precisar de
        # um campo próprio o ganha sem ninguém vir aqui") e a linha abaixo dele
        # nomeava `banir`, um campo só.
        #
        # O preço foi o desfazer.
        #
        # O contrato de saída são estes cinco campos; tudo que a fonte
        # acrescentar além deles é dela e passa.
        for extra, quanto in item.items():
            if extra not in ("id", "rotulo", "origem", "grupo", "url"):
                saida[extra] = quanto
        fora.append(saida)
    return {"tipo": tipo, "itens": fora, "faltam": faltam,
            "contagens": contagens, "total": total}


def previa_bytes(tipo, ident):
    """Os bytes da prévia, ou None. O `id` é conferido contra o disco, sempre."""
    fonte = PREVIA_FONTES.get(tipo)
    if fonte is None:
        return None
    item = next((i for i in fonte() if i["id"] == ident), None)
    if item is None:
        return None            # id que não existe no disco não vira caminho
    if _previa_direta(item):
        try:
            with open(item["origem"], "rb") as fh:
                return (fh.read(), "image/svg+xml")
        except OSError:
            return None
    destino = _previa_destino(item, tipo)
    if not destino or not os.path.isfile(destino):
        _enfileirar(item, tipo)
        return None
    try:
        with open(destino, "rb") as fh:
            return (fh.read(), "image/png" if tipo == "cursor" else "image/webp")
    except OSError:
        return None


# O `.html` é uma FOTOGRAFIA da página — ele sai para ser redesenhado lá fora, e
# o que volta de lá é desenho, não configuração.
#
# Exportar JSON seria mais fácil de escrever e pior de usar: o `meow.conf` é o
# que ela já sabe ler, o que o `meow configurar` escreve e o que o `. conf` do
# shell carrega.

def _carimbo():
    """AAAAMMDD-HHMM, o mesmo formato de nome que os backups do projeto usam."""
    return time.strftime("%Y%m%d-%H%M")


def exportar_conf():
    """(texto, nome_do_arquivo) — as configurações dela, prontas para guardar.

    Quando o `meow.conf` existe, o que sai é ELE, inteiro: os comentários que
    ela escreveu, o alinhamento das colunas e a ordem das linhas sobrevivem. Sem
    o arquivo (primeira instalação), o conteúdo é montado do esquema, com o
    valor em vigor de cada chave — o que é a mesma coisa, só que sem história.
    """
    linhas_cabecalho = [
        "# meow.conf — exportado pelo painel do MeowSystem em %s"
        % time.strftime("%d/%m/%Y às %H:%M"),
        "#",
        "# Este arquivo é um meow.conf inteiro e válido. Para restaurar, use o",
        "# botão Importar do painel (que grava chave a chave, validando cada uma)",
        "# ou copie-o por cima de ~/.config/meow/meow.conf e rode `meow aplicar`.",
        "#",
    ]
    try:
        with open(CONF, "r", encoding="utf-8") as fh:
            corpo = fh.read()
        # O corpo continua byte a byte — ele é o arquivo da pessoa, e o que ela
        # escreveu nele é dela para levar.
        linhas_cabecalho.append("# Origem: %s" % texto_na_tela(CONF))
    except OSError:
        # Sem arquivo dela ainda: o conteúdo sai do esquema, na ordem do exemplo.
        esquema = ler_esquema()
        brutos = valores_brutos()
        partes, secao = [], None
        for item in esquema:
            if item.get("secao") != secao:
                secao = item.get("secao")
                partes.append("\n# --- %s" % (secao or "Outras"))
            partes.append('%s="%s"' % (item["chave"], brutos.get(item["chave"], "")))
        corpo = "\n".join(partes) + "\n"
        linhas_cabecalho.append(
            "# Origem: o catálogo (%s ainda não existia nesta máquina)"
            % texto_na_tela(CONF))
    return ("\n".join(linhas_cabecalho) + "\n\n" + corpo,
            "meow-%s.conf" % _carimbo())


def importar_conf(texto):
    """Lê um meow.conf exportado e devolve o que MUDARIA. Não escreve um byte.

    ELE NÃO GRAVA, E A MEDIÇÃO É O MOTIVO
        A primeira versão gravava chave a chave aqui dentro. Cronometrado nesta
        máquina: `definir()` leva 0,45 s por chave, porque cada chamada sobe um
        bash, carrega o `lib/comum.sh` e reescreve os 55 KB do `meow.conf`
        inteiro. Noventa e seis chaves são QUARENTA E TRÊS SEGUNDOS de página
        parada, sem barra de progresso e sem como cancelar — para uma operação
        que ela dispara por engano ao escolher o arquivo errado.

        Então a importação faz o que a página inteira já faz desde 01/09: ela
        ENCENA. Cada chave aceita entra em `MUDANCAS`, o banner acende com "N
        esperando", e quem escreve é o `Salvar e aplicar` de sempre — o mesmo
        botão, a mesma peneira, o mesmo instalador em seguida. Importar deixa
        de ser um caminho de escrita paralelo (que teria de reimplementar a
        peneira, a idempotência e o aplicar) e vira o que é: um jeito de
        preencher a tela.

        Efeito colateral bom: dá para ver o que veio ANTES de aceitar, e
        Descartar desfaz tudo com um clique.

    AS DUAS PENEIRAS SÃO AS MESMAS DO CLIQUE
        `ler_esquema()` diz se a chave existe no catálogo; `validar_valor()` diz
        se o valor cabe nela. O que não passa é recusado com a frase, e o resto
        entra: um arquivo com uma linha estragada traz as outras noventa e
        cinco, em vez de não trazer nada.

        E o parser não é novo: `RE_CHAVE` + `_valor_da_linha` são os mesmos que
        o `valores_brutos()` usa para ler o conf dela. Um segundo entendedor de
        `CHAVE="valor"` neste arquivo discordaria do primeiro no primeiro caso
        esquisito.
    """
    esquema = {i["chave"]: i for i in ler_esquema()}
    brutos = valores_brutos()
    relatorio = {"mudam": [], "iguais": [], "recusadas": [], "desconhecidas": []}

    # A ÚLTIMA ATRIBUIÇÃO VENCE, como no `.` do shell.
    pares = {}
    for linha in texto.split("\n"):
        crua = linha.strip()
        if crua.startswith("export "):
            crua = crua[len("export "):]
        achado = RE_CHAVE.match(crua)
        if achado:
            pares[achado.group(1)] = _valor_da_linha(crua)
    # UM.conf EXPORTADO ANTES DE UMA TROCA DE NOME traz a chave pelo nome
    # antigo, e ela entra pelo novo — sem isso ela cairia em "desconhecidas" e o
    # valor ficaria para trás. Com os dois no arquivo, o novo vence.
    for antigo, novo in chaves_renomeadas().items():
        if antigo in pares:
            valor = pares.pop(antigo)
            pares.setdefault(novo, valor)

    for chave, valor in pares.items():
        item = esquema.get(chave)
        if item is None:
            relatorio["desconhecidas"].append(chave)
            continue
        queixa = validar_valor(item, valor)
        if queixa:
            relatorio["recusadas"].append(
                {"chave": chave, "valor": valor, "erro": queixa})
        elif brutos.get(chave, "") == valor:
            # Já está assim no disco. Encená-la faria o banner mentir sobre
            # quantas coisas esperam — e o `Salvar` gastaria 0,45 s para gravar
            # o que já estava lá.
            relatorio["iguais"].append(chave)
        else:
            relatorio["mudam"].append(
                {"chave": chave, "valor": valor, "de": brutos.get(chave, "")})

    # As chaves do catálogo que o arquivo NÃO trazia. Não são erro — um arquivo
    # de uma versão anterior do projeto é exatamente isso — mas ela tem de saber
    # que elas ficaram como estavam, e não voltaram ao padrão.
    relatorio["ausentes"] = [c for c in esquema if c not in pares]
    return relatorio


# «Cores», «Fusão» e «Aparo» são o vocabulário do conversor, não o dela —
# números que só quem leu o `converter_icone.py` sabe mexer.
# O número é preso ANTES da conta (0…10 dá `--k` de 2 a 12): um `--k 900` de um
# POST forjado seria um processo de minutos dentro do servidor.
def _parametros_de(detalhe, suavidade, cheia=False, fracas=0, minimo=0):
    """(argv para o subprocess, string canônica para o campo 4 do mapa)."""
    def _regua(v, padrao):
        try:
            return max(0, min(10, int(v)))
        except (TypeError, ValueError):
            return padrao
    d = _regua(detalhe, 6)
    s = _regua(suavidade, 2)
    f = _regua(fracas, 0)
    m = _regua(minimo, 0)
    k = 2 + d                        # 2 … 12
    funde = 100 - 8 * d              # 100 … 20
    tol = round(0.4 + 0.3 * s, 1)    # 0,4 … 3,4
    argv = ["--k", str(k), "--funde", str(funde), "--tol", "%g" % tol]
    # A ORDEM DAS BANDEIRAS É PARTE DO CONTRATO: a string tem de casar com o
    # `_RE_PARAMETROS_DESENHO` abaixo, que lê UMA forma só.
    if f:
        argv += ["--peso-fronteira", str(40 + 3 * f)]      # 43 … 70
    if m:
        argv += ["--min-traco", "%g" % round(3.2 + 0.8 * m, 1)]   # 4 … 11,2
    if cheia:
        argv.append("--cheia")
    return argv, " ".join(argv)


# A CERCA DAS RÉGUAS É MAIS APERTADA QUE A DOS TRÊS NÚMEROS, e é de propósito.
#
# `--k 2` é mais barato que `--k 3`, não mais caro: o piso guardava contra o
# teto, e prendeu o chão sem querer.
_RE_PARAMETROS_DESENHO = re.compile(
    r"^--k (\d{1,2}) --funde (\d{1,3}) --tol (\d{1,2}(?:\.\d)?)"
    r"(?: --peso-fronteira (\d{1,3}))?"
    r"(?: --min-traco (\d{1,2}(?:\.\d)?))?"
    r"( --cheia)?$")


def _parametros_relidos(texto):
    """A string do campo 4 do mapa de volta a argv — RECONSTRUÍDA, nunca partida.

    O `salvar` reconverte para decidir se o desenho ainda é o da linha, e os
    parâmetros dessa reconversão vêm do cliente. Partir a string em espaços e
    entregar os pedaços ao `subprocess` deixaria o navegador escolher bandeira
    do conversor (`--lw 5` gravaria espessura no arquivo, que é justamente o que
    o `_conferir_dialeto` recusa). Então: casa contra UMA forma, lê os
    números, confere as faixas, e MONTA o argv do zero. Devolve None quando não
    reconhece — e quem não reconhece grava como retoque à mão, que é o desfecho
    seguro.

    A FAIXA DE CADA NÚMERO NOVO É CONFERIDA ANTES DE ELE VIRAR ARGUMENTO, a
    mesma disciplina dos três de cima. `--peso-fronteira` e `--min-traco` não
    são caros (os dois só DESCARTAM: menos classe, menos traço — nunca mais
    trabalho), então a cerca aqui não guarda contra processo de minutos; guarda
    contra a string do campo 4 virar uma linha de comando escrita pela página.
    O ZERO É RECUSADO DE PROPÓSITO: "desligado" tem uma grafia só, que é a
    ausência da bandeira — duas grafias para o mesmo estado fariam a mesma
    escolha gerar duas strings canônicas diferentes, e é exatamente isso que o
    cabeçalho do `_parametros_de` proíbe.
    """
    achado = _RE_PARAMETROS_DESENHO.match((texto or "").strip())
    if not achado:
        return None
    k, funde, tol = int(achado.group(1)), int(achado.group(2)), float(achado.group(3))
    if not (2 <= k <= 16 and 0 <= funde <= 120 and 0.2 <= tol <= 8.0):
        return None
    argv = ["--k", str(k), "--funde", str(funde), "--tol", "%g" % tol]
    if achado.group(4) is not None:
        peso = int(achado.group(4))
        if not (1 <= peso <= 120):
            return None
        argv += ["--peso-fronteira", str(peso)]
    if achado.group(5) is not None:
        minimo = float(achado.group(5))
        if not (0.1 <= minimo <= 24.0):
            return None
        argv += ["--min-traco", "%g" % minimo]
    if achado.group(6):
        argv.append("--cheia")
    return argv


# id, rótulo, detalhe, suavidade, cheia, fonte, linhas fracas, traço mínimo
#
# A folha é a arte que ela olhou e aprovou.
PRESETS_DESENHO = (
    ("fiel", "Fiel", 6, 2, False, "icone", 0, 0),
    ("limpo", "Limpo", 2, 6, False, "icone", 0, 0),
    ("silhueta", "Silhueta", 0, 4, False, "icone", 0, 0),
    ("detalhe", "Detalhe", 10, 1, False, "icone", 0, 0),
    ("cheia", "Área cheia", 4, 4, True, "icone", 0, 0),
    ("capa", "Da capa", 3, 5, False, "capa", 0, 0),
)

# O CACHE É POR (ORIGEM, MTIME, PARÂMETROS), e o `mtime` não é enfeite: sem ele
# um Papirus atualizado no `apt upgrade` continuaria desenhando a arte velha
# até o painel reiniciar, e o `salvar` gravaria `conversao` numa linha que o
# `construir_convertidos.sh` refaria diferente na primeira passagem.
_CACHE_DESENHO = {}
_CACHE_DESENHO_TETO = 64
_CACHE_DESENHO_TRAVA = threading.Lock()
_CONVERSOR_CHEIA = None
_CONVERSOR_CHEIA_TRAVA = threading.Lock()

# A página manda `acao: "editor"` e o desenho; QUEM decide em que arquivo isso
# cai é o servidor, a partir do `.desktop`, com o nome já preso ao
# `^[A-Za-z0-9._+-]{1,120}$` do `_nome_do_icone`.
#
# `~/.local/state/meowsystem/oficina/` é rascunho: o que ela abre no Boxy SVG
# pode voltar com `<defs>`, com metadado do editor, com hex — coisas que o
# `_conferir_dialeto` recusa.
_OFICINA_RASCUNHO = os.path.join(ESTADO, "oficina")

# O `_icone_na_tela` devolve o `Icon=` absoluto de um `.desktop` como o ícone do
# aplicativo (é o que a Steam e os instaladores de `/opt` fazem), e a cerca do
# `/previa?tipo=arquivo` só conhece as pastas de arte.
_ICONES_DECLARADOS = set()

# Não há "o comando que abre" vindo de lugar nenhum: são estes dois, nesta
# ordem, e o `shutil.which` escolhe o primeiro que existe.
_LANCADORES_SVG = (("xdg-open",), ("gio", "open"))
_EDITOR_SVG = None
_EDITOR_SVG_TRAVA = threading.Lock()


def _conversor_tem_cheia():
    """`--cheia` existe no conversor de hoje? Perguntado UMA vez, ao `--help`.

    A chave é da Sprint Q, que está sendo escrita ao lado desta. A oficina não
    espera por ela: sem a chave, o cartão «Área cheia» simplesmente não é
    oferecido, e a folha sai com um cartão a menos. Perguntar ao `--help` custa
    um processo por sessão e não presume versão nenhuma.
    """
    global _CONVERSOR_CHEIA
    with _CONVERSOR_CHEIA_TRAVA:
        if _CONVERSOR_CHEIA is None:
            _CONVERSOR_CHEIA = False
            conversor = os.path.join(RAIZ, "scripts", "converter_icone.py")
            if os.path.isfile(conversor):
                try:
                    r = subprocess.run([sys.executable, conversor, "--help"],
                                       capture_output=True, text=True, timeout=20)
                    _CONVERSOR_CHEIA = "--cheia" in ((r.stdout or "") + (r.stderr or ""))
                except (OSError, subprocess.SubprocessError):
                    _CONVERSOR_CHEIA = False
        return _CONVERSOR_CHEIA


def _nota_do_conversor(saida):
    """A contagem que o conversor imprime — E ELA SAI NO STDERR, medido em 09/09.

    O contrato desta sprint dizia `stdout`, e a rota de 08/09 lia `stdout`: a
    `nota` chegava VAZIA em toda resposta desde que a rota existe, e ninguém viu
    porque não havia onde ela aparecesse. `scripts/converter_icone.py` termina em
    `print(..., file=sys.stderr)`. A linha vem com o nome do arquivo na frente
    (`org.gimp.GIMP.svg: 4 classes (0 fita), 6 traços, 149 pontos`), que é ruído
    no balão de um cartão que já se chama pelo rótulo — sai o prefixo.
    """
    linhas = [l.strip() for l in (saida or "").splitlines() if l.strip()]
    if not linhas:
        return ""
    nota = linhas[-1]
    if ": " in nota:
        nota = nota.split(": ", 1)[1]
    return nota[:200]


def _converter_desenho(origem, argv_extra, texto_parametros):
    """Roda o conversor uma vez, com cache. Devolve (svg, nota, erro).

    Não levanta: quem chama é um operário de `ThreadPoolExecutor` e uma exceção
    lá dentro derrubaria a folha inteira por causa de uma variação.
    """
    try:
        mtime = os.path.getmtime(origem)
    except OSError:
        return "", "", "a arte de origem sumiu do disco"
    chave = (origem, mtime, texto_parametros)
    with _CACHE_DESENHO_TRAVA:
        achado = _CACHE_DESENHO.get(chave)
    if achado is not None:
        return achado[0], achado[1], ""
    conversor = os.path.join(RAIZ, "scripts", "converter_icone.py")
    if not os.path.isfile(conversor):
        return "", "", "falta scripts/converter_icone.py"
    saida = tempfile.NamedTemporaryFile(suffix=".svg", delete=False)
    saida.close()
    try:
        r = subprocess.run([sys.executable, conversor, origem, saida.name] + list(argv_extra),
                           capture_output=True, text=True, timeout=60)
        if r.returncode != 0:
            return "", "", ("o conversor recusou esta arte: %s"
                            % (r.stderr or "").strip()[:300])
        with open(saida.name, "r", encoding="utf-8") as fh:
            svg = fh.read()
    except (OSError, subprocess.SubprocessError) as e:
        return "", "", "o conversor falhou: %s" % e
    finally:
        try:
            os.unlink(saida.name)
        except OSError:
            pass
    nota = _nota_do_conversor(r.stderr)
    with _CACHE_DESENHO_TRAVA:
        _CACHE_DESENHO[chave] = (svg, nota)
        # `dict` guarda a ordem de inserção desde o 3.7: a primeira chave é a
        # mais antiga, e é ela que sai. Sessenta e quatro entradas cobrem uma
        # visita inteira a uma ficha sem deixar o painel virar depósito de SVG.
        while len(_CACHE_DESENHO) > _CACHE_DESENHO_TETO:
            _CACHE_DESENHO.pop(next(iter(_CACHE_DESENHO)))
    return svg, nota, ""


# --- 6. os trabalhos ---------------------------------------------------------
def _nome_no_appinfo(caminho, appid):
    """`appinfo › common › name` do `appid` no `appinfo.vdf` da Steam, ou "".

    O formato, versões 27 a 29 (as três que a Steam escreveu desde 2022):
      cabeçalho  u32 versão · u32 universo · [v29: i64 onde começa a tabela]
      entrada    u32 appid (0 = fim) · u32 tamanho do resto · u32 estado ·
                 u32 data · u64 token · 20 bytes sha1 · u32 número da mudança ·
                 [v28+: 20 bytes sha1 do binário] · KeyValues binário
      KeyValues  um byte de tipo (0 abre bloco, 1 texto, 2/3/4/6 quatro
                 bytes, 7/10 oito bytes, 8 fecha bloco), o nome da chave (na
                 v29, u32 índice na tabela; antes, texto terminado em zero) e
                 o valor.
    Usado só para NOMEAR uma decisão cujo manifesto já foi embora (P54).

    POR SALTO NO ARQUIVO, E NÃO UMA LEITURA DE 64 MB — 24/09/2026, revisão da
    P54. A primeira versão lia os primeiros 64 MB e andava na memória. Numa
    conta de biblioteca grande o `appinfo.vdf` passa disso, e a v29 guarda a
    tabela de nomes de chave NO FIM: o índice dela caía fora do que foi lido, o
    `struct.error` virava "" no chamador, e toda decisão sem manifesto voltava
    a «appid N» calada. Medido com um v29 de 73 MB montado à mão: a exceção
    saía até para o PRIMEIRO appid do arquivo. Agora só se leem o cabeçalho, a
    tabela (do índice até o fim, que é só ela) e a entrada do appid pedido; as
    outras são puladas por `seek`, sem teto de tamanho."""
    with open(caminho, "rb") as fh:
        cabeca = fh.read(16)
        if len(cabeca) < 8:
            return ""
        versao = struct.unpack_from("<I", cabeca, 0)[0]
        if versao not in (0x07564427, 0x07564428, 0x07564429):
            return ""
        pos, tabela = 8, None
        if versao == 0x07564429:
            inicio = struct.unpack_from("<q", cabeca, pos)[0]
            pos += 8
            fh.seek(inicio)
            final = fh.read()
            quantos = struct.unpack_from("<I", final, 0)[0]
            tabela = final[4:].split(b"\0", quantos)[:quantos]
        fixo = 4 + 4 + 8 + 20 + 4 + (20 if versao != 0x07564427 else 0)
        fh.seek(pos)
        while True:
            par = fh.read(8)
            if len(par) < 8:
                return ""
            este, tamanho = struct.unpack("<II", par)
            if este == 0:
                return ""
            if este != appid:
                fh.seek(tamanho, os.SEEK_CUR)
                continue
            dados = fh.read(tamanho)
            break
        p, fim, pilha = fixo, len(dados), []
        while p < fim:
            tipo = dados[p]
            p += 1
            if tipo == 8:
                if not pilha:
                    return ""
                pilha.pop()
                continue
            if tabela is not None:
                nome = tabela[struct.unpack_from("<I", dados, p)[0]]
                p += 4
            else:
                corte = dados.index(b"\0", p)
                nome, p = dados[p:corte], corte + 1
            if tipo == 0:
                pilha.append(nome.lower())
            elif tipo == 1:
                corte = dados.index(b"\0", p)
                valor, p = dados[p:corte], corte + 1
                if pilha == [b"appinfo", b"common"] and nome.lower() == b"name":
                    return valor.decode("utf-8", "replace").strip()
            elif tipo in (2, 3, 4, 6):
                p += 4
            elif tipo in (7, 10):
                p += 8
            else:
                return ""
        return ""


class Trabalho:
    """Um comando rodando, com a saída acumulada para a página buscar.

    POR QUE ACUMULAR EM VEZ DE TRANSMITIR (streaming)
        Um `text/event-stream` seria menos código e cairia junto com a aba: um
        F5 no meio de um `./install.sh` mataria o processo, ou o deixaria órfão
        escrevendo num socket morto. Guardar as linhas aqui faz a página poder
        fechar, recarregar e voltar a acompanhar o MESMO trabalho de onde parou —
        que é o comportamento que uma instalação de dezenas de etapas pede.
    """

    _seq = 0
    _trava = threading.Lock()

    def __init__(self, acao_id, argv, ambiente, rotulo, ao_terminar=None):
        with Trabalho._trava:
            Trabalho._seq += 1
            self.id = Trabalho._seq
        self.acao = acao_id
        self.rotulo = rotulo
        self.argv = argv
        # O que fazer quando o processo morrer, de qualquer jeito — fim normal,
        # `#parar`, ou o pai morrendo junto.
        self._ao_terminar = ao_terminar
        self.linhas = []
        self.rc = None
        self.comeco = time.time()
        self.fim = None
        self._lock = threading.Lock()
        self.proc = subprocess.Popen(
            argv,
            cwd=RAIZ,
            env=ambiente,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            # Grupo próprio: parar o trabalho tem de alcançar os FILHOS também.
            # O `install.sh` chama ~50 scripts, e matar só o pai deixaria o neto
            # escrevendo no disco depois de a página dizer "parado".
            start_new_session=True,
        )
        threading.Thread(target=self._ler, daemon=True).start()

    # O `fim` nascia quando o stdout fechava, e um neto que herde o stdout (o
    # `&` de um script) segura o cano aberto: o pai morria e o trabalho ficava
    # vivo para sempre.
    PRAZO_DO_CANO = 2.0

    def _bombear(self):
        try:
            for bruta in self.proc.stdout:
                linha = bruta.decode("utf-8", "replace").rstrip("\n")
                with self._lock:
                    self.linhas.append(linha)
        except (OSError, ValueError):
            pass

    def _ler(self):
        leitor = threading.Thread(target=self._bombear, daemon=True)
        leitor.start()
        rc = self.proc.wait()
        leitor.join(self.PRAZO_DO_CANO)
        self.rc = rc
        # ANTES do `fim`: quando a página ouve «acabou», o ponto de restauro desta
        # execução já está registrado. A falha dele não segura o desfecho.
        if self._ao_terminar is not None:
            try:
                self._ao_terminar()
            except Exception:
                pass
        self.fim = time.time()

    def desde(self, n):
        with self._lock:
            return list(self.linhas[n:]), len(self.linhas)

    # `proc.poll()`, e o `rc` e o `fim` só são gravados depois, pela thread
    # `_ler`.
    def vivo(self):
        return self.fim is None

    def parar(self):
        if not self.vivo():
            return False
        try:
            os.killpg(os.getpgid(self.proc.pid), signal.SIGTERM)
        except (OSError, ProcessLookupError):
            return False
        return True


TRABALHOS = {}
TRABALHO_ATUAL = None
TRABALHO_TRAVA = threading.Lock()

# O RESTAURAR: toda execução que escreve ganha uma pasta (`MEOW_BACKUPS`, ver
# lib/restauro.sh) com o estado de antes, e a última de cada ação fica para o
# «Restaurar» do cartão. Uma por ação: a de antes sai quando a nova chega.
RESTAUROS = os.path.join(ESTADO, "restauros")
_RESTAUROS_TRAVA = threading.Lock()


def _tem_tocados(pasta):
    try:
        return os.path.getsize(os.path.join(pasta, "tocados.tsv")) > 0
    except OSError:
        return False


def restauros():
    """{acao_id: pasta} das execuções que ainda se podem desfazer."""
    try:
        with open(os.path.join(RESTAUROS, "ultimos.json"), "r", encoding="utf-8") as fh:
            dados = json.load(fh)
    except (OSError, ValueError):
        return {}
    if not isinstance(dados, dict):
        return {}
    # A pasta tem de ser filha de `RESTAUROS`: o arquivo é texto no disco, e o
    # caminho dele vira argumento do `meow restaurar`.
    return {a: p for a, p in dados.items()
            if a in ACOES and isinstance(p, str)
            and os.path.dirname(os.path.realpath(p)) == os.path.realpath(RESTAUROS)
            and _tem_tocados(p)}


def _gravar_restauros(dados):
    os.makedirs(RESTAUROS, exist_ok=True)
    tmp = os.path.join(RESTAUROS, ".ultimos.json.tmp")
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(dados, fh, ensure_ascii=False, indent=1)
    os.replace(tmp, os.path.join(RESTAUROS, "ultimos.json"))


def _guardar_restauro(acao_id, pasta):
    with _RESTAUROS_TRAVA:
        dados = restauros()
        if not _tem_tocados(pasta):
            shutil.rmtree(pasta, ignore_errors=True)
            return
        velha = dados.get(acao_id)
        dados[acao_id] = pasta
        _gravar_restauros(dados)
        if velha and velha != pasta:
            shutil.rmtree(velha, ignore_errors=True)


def _esquecer_restauro(acao_id, pasta):
    with _RESTAUROS_TRAVA:
        dados = restauros()
        if dados.get(acao_id) == pasta:
            del dados[acao_id]
            _gravar_restauros(dados)
        shutil.rmtree(pasta, ignore_errors=True)


def _nome_de_arquivo(texto):
    """«Tirar uma área» -> `tirar-uma-area`: o nome do log guardado."""
    import unicodedata
    plano = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", plano.lower()).strip("-") or "acao"


def guardar_log(trabalho):
    """Grava a saída inteira de um trabalho em `logs/`; devolve o caminho."""
    pasta = os.path.join(ESTADO, "logs")
    os.makedirs(pasta, exist_ok=True)
    nome = "%s-%s.log" % (time.strftime("%Y-%m-%d-%H%M%S", time.localtime(trabalho.comeco)),
                          _nome_de_arquivo(trabalho.rotulo))
    linhas, _ = trabalho.desde(0)
    caminho = os.path.join(pasta, nome)
    with open(caminho, "w", encoding="utf-8") as fh:
        fh.write("# %s\n# %s\n# saiu %s\n\n" % (trabalho.rotulo, comando_na_tela(trabalho.argv), trabalho.rc))
        fh.write("\n".join(linhas) + "\n")
    return caminho


def escreve(acao):
    """Esta ação escreve na máquina dela?

    UM CAMPO POR AÇÃO, QUE ANTES SE CHAMAVA `seco` — 13/09/2026
        A resposta saía do `seco: True`, que marcava a ação que aceita
        `MEOW_DRY_RUN=1`; as duas coincidiam porque uma ação que nunca escreve
        não tem o que ensaiar. O ensaio saiu do painel (ver
        `_ambiente_do_painel`) e o campo trocou de nome em vez de sumir: a
        pergunta continua sendo feita pela tela, e continua havendo UMA
        verdade só por ação.

    E ELA É UMA PERGUNTA DIFERENTE DE "ACEITA SECO" — 01/09/2026
        A auditoria mediu na tela: os cartões que escrevem traziam só a pastilha
        "ACEITA SECO", que fala de uma CAPACIDADE DE SIMULAÇÃO, não de risco; os
        que só leem não traziam pastilha nenhuma. Ou seja, a única marca visível
        separava `doctor` de `doctor --consertar` falando de outro assunto. O
        servidor passa a dizer a palavra certa, e a página só precisa mostrá-la.
    """
    return bool(acao.get("escreve"))



# O `lib/comum.sh` ganhou o verbo `meow_pendencia_acionavel`: toda etapa que
# descobre um problema e sabe o conserto registra uma linha em
# `$MEOW_ESTADO/pendencias.tsv` em vez de imprimir uma receita de terminal.
#
# A linha guarda o comando como TEXTO, para a pessoa ver o que vai rodar.
ACAO_DA_PENDENCIA = {
    "areas-sem-alfinete": "areas_alfinetar_primeira",
    "starship-ausente": "prompt_instalar_starship",
    "spicetify-tema-ausente": "spotify_baixar_tema",
    "files-menu-build": "files_menu_build",
    # o rodapé do instalador mandava digitar «sudo -v &&./install.sh», e o
    # applet de leitura «LEITURA_COMPILAR=1 …/leitura_build.sh». Viraram
    # pendência, e o botão é o de quem faz.
    "instalar-com-root": "instalar",
    "flatpak-global-sistema": "instalar",
    "libreoffice-sistema": "instalar",
    "leitura-applet": "doctor_consertar",
}

# Quem grava é o próprio script, por um verbo dele — o painel não escreve
# arquivo de estado de outro módulo.
RECUSA_DA_PENDENCIA = {
    "starship-ausente": [os.path.join(RAIZ, "scripts", "prompt.sh"),
                         "nao-quero-starship"],
}

# A decisão tem dois lados, e cada um vira um botão, pela rota de qualquer
# botão: as ações `apps_tema_do_pack` e `apps_manter_o_meu`, com o app de
# argumento.
#
# PELO SUFIXO, E NÃO UMA LINHA POR APP NO `ACAO_DA_PENDENCIA`: o id nasce
# assim para todo módulo que chama aquela função — sete hoje —, e o próximo
# ganha os botões sem vir aqui.
SUFIXO_TEMA_DE_TERCEIRO = "-tema-de-terceiro"
ESCOLHA_TEMA_DE_TERCEIRO = (("apps_tema_do_pack", "Trocar pelo tema do pack"),
                            ("apps_manter_o_meu", "Manter o meu"))


# O id é o que o `scripts/temas-de-apps/vscode/manifesto.sh` registra; as
# extensões saem do pack no ar, e só quando ele NÃO mora no `packs/` do
# repositório — a mesma régua do módulo, com os links resolvidos.
PENDENCIA_EXTENSAO = "vscode-extensao-de-terceiro"

# Virou esta pendência, com o comando na linha; o botão «Era escolha
# minha» roda o mesmo `permitir`, com o caminho que o servidor tira do
# comando — e só ele (`fontes_revertidas`).
PENDENCIA_PAREDE = "wallpaper-fonte-revertida"
PREFIXO_PERMITIR = "meow wallpaper permitir "


def _fontes_revertidas():
    """Os caminhos que as pendências do papel de parede devolvido pedem."""
    return sorted({p["comando"][len(PREFIXO_PERMITIR):] for p in pendencias()
                   if p["id"] == PENDENCIA_PAREDE and p["comando"].startswith(PREFIXO_PERMITIR)
                   and len(p["comando"]) > len(PREFIXO_PERMITIR)})
RE_EXTENSAO = re.compile(r"^[A-Za-z0-9][A-Za-z0-9-]*\.[A-Za-z0-9][A-Za-z0-9-]*$")


def _extensoes_de_terceiro():
    """As extensões do VS Code que o pack importado no ar pede, ou []."""
    mod = modulo_pack()
    if not mod:
        return []
    vals = valores_efetivos(["PACK", "FLAVOR"])
    try:
        ident, dir_pack, _r = mod.adocao(vals.get("PACK") or "", vals.get("FLAVOR") or "")
        dir_pack = dir_pack or mod.achar(ident) or ""
    except Exception:
        return []
    do_repo = os.path.realpath(os.path.join(RAIZ, "packs"))
    if not dir_pack or os.path.realpath(dir_pack).startswith(do_repo + os.sep):
        return []
    fora = []
    for trilha in ("apps.vscode.origem.extensao", "apps.vscode-icones.origem.extensao"):
        try:
            quem, valor = mod.tema_de_app(trilha, ref=dir_pack)
        except Exception:
            continue
        if quem == ident and isinstance(valor, str) and RE_EXTENSAO.match(valor) \
                and valor not in fora:
            fora.append(valor)
    return fora


def _app_da_pendencia(ident):
    """O app de uma pendência `<app>-tema-de-terceiro`, ou ''."""
    if not ident.endswith(SUFIXO_TEMA_DE_TERCEIRO):
        return ""
    app = ident[:-len(SUFIXO_TEMA_DE_TERCEIRO)]
    if not re.match(r"^[a-z0-9][a-z0-9-]*$", app):
        return ""
    modulo = os.path.join(RAIZ, "scripts", "temas-de-apps", app, "manifesto.sh")
    return app if os.path.isfile(modulo) else ""


# As duas eram nomes de tela escritos à mão num script, e nome escrito à mão é o
# que envelhece no primeiro renome.
#
# Um cartão se pergunta pela CHAVE, e a resposta sai do mesmo lugar de onde a
# página tira o cartão: o título escrito no `meow.conf.exemplo` (o `# @`), com a
# troca que o pack no ar faz (`_com_o_vocabulario_do_pack`), e a seção, que é a
# aba.
ABA_INICIO = "Início"


def onde_na_tela(ident):
    """Onde um lugar do painel mora, pela tabela que o define, ou "":

    «rótulo», na aba Grupo — de uma ação, ou da ação de uma pendência;
    «um» ou «outro», na aba Início — dos botões da pendência de tema de terceiro;
    «título», na aba Seção — do cartão de uma chave do meow.conf;
    na aba Início — para `inicio`, a aba que abre o painel."""
    acao = ACOES.get(ident) or ACOES.get(ACAO_DA_PENDENCIA.get(ident, ""))
    if acao:
        return "" if acao.get("oculta") else "«%s», na aba %s" % (acao["rotulo"], acao["grupo"])
    if _app_da_pendencia(ident):
        return "%s, na aba %s" % (" ou ".join("«%s»" % r for _a, r in ESCOLHA_TEMA_DE_TERCEIRO),
                                  ABA_INICIO)
    if ident == PENDENCIA_EXTENSAO:
        return "«Instalar», na aba %s" % ABA_INICIO
    if ident == PENDENCIA_PAREDE:
        return "«Era escolha minha», na aba %s" % ABA_INICIO
    if ident == "inicio":
        return "na aba %s" % ABA_INICIO
    esquema = ler_esquema()
    item = next((i for i in esquema if i["chave"] == ident), None)
    if not item:
        return ""
    _com_o_vocabulario_do_pack(esquema, vocabulario_do_pack(), {})
    if not item.get("titulo") or not item.get("secao"):
        return ""
    return "«%s», na aba %s" % (item["titulo"], item["secao"])


PENDENCIAS = os.path.join(ESTADO, "pendencias.tsv")


def pendencias():
    """As linhas do pendencias.tsv, na ordem em que foram registradas.

    ARQUIVO AUSENTE É LISTA VAZIA, e não erro: numa máquina onde nada pendeu
    ele nunca foi criado. A Home não desenha o bloco quando a lista é vazia —
    um bloco "3 coisas esperam um clique" com zero linhas é a caixa vazia que
    a auditoria de 01/09 já tinha cobrado em outra aba.
    """
    fora = []
    try:
        with open(PENDENCIAS, "r", encoding="utf-8") as fh:
            for linha in fh:
                # `split` com limite: a frase e o comando podem ter qualquer
                # coisa MENOS tabulação, que o `meow_pendencia_acionavel` já
                # troca por espaço na hora de escrever.
                campos = linha.rstrip("\n").split("\t")
                if len(campos) != 5 or not campos[0]:
                    continue
                ident, etapa, frase, comando, quando = campos
                # A tabela acima diz o que o "Resolver" dispara; o campo
                # `comando` da LINHA diz se aquela passagem tinha conserto.
                acao = ACAO_DA_PENDENCIA.get(ident, "") if comando else ""
                # Quando o conserto dela se declara «já feito»
                if acao and (indisponivel(acao) or {}).get("feito"):
                    continue
                app = _app_da_pendencia(ident) if comando else ""
                escolha = [{"acao": a, "argumento": app, "rotulo": r}
                           for a, r in ESCOLHA_TEMA_DE_TERCEIRO] if app else []
                nome = ""
                # Um botão por extensão que o pack importado pede, com o selo
                # de rede da ação; a lista vazia (o pack já é do repositório)
                # não desenha botão nenhum.
                if ident == PENDENCIA_PAREDE and comando.startswith(PREFIXO_PERMITIR):
                    escolha = [{"acao": "wallpaper_permitir", "rotulo": "Era escolha minha",
                                "argumento": comando[len(PREFIXO_PERMITIR):]},
                               {"acao": "wallpaper_dispensar", "rotulo": "Deixar assim",
                                "argumento": ""}]
                    nome = "Papel de parede devolvido"
                if ident == PENDENCIA_EXTENSAO and comando:
                    escolha = [{"acao": "vscode_instalar_extensao", "argumento": e,
                                "rotulo": "Instalar " + e} for e in _extensoes_de_terceiro()]
                    nome = "VS Code: extensão de pack importado"
                # O `files-menu-build` nasce sem comando enquanto a unidade
                # compila, e sem `acao` a Início caía no nome da etapa:
                # «Files_menu.sh», o nome de um arquivo.
                if not nome and not acao:
                    nome = ACOES.get(ACAO_DA_PENDENCIA.get(ident, ""), {}).get("rotulo", "")
                rede = any(ACOES.get(a, {}).get("rede") for a in [acao] + [e["acao"] for e in escolha])
                fora.append({
                    "id": ident, "etapa": etapa, "frase": frase,
                    "comando": comando, "quando": quando,
                    "acao": acao,
                    # Os dois lados da decisão, na ordem da frase.
                    "escolha": escolha,
                    "nome": nome,
                    "recusavel": ident in RECUSA_DA_PENDENCIA,
                    # O rótulo que os cartões de ação já usam. Sai da própria
                    # ação, e não de uma segunda lista aqui: duas verdades sobre
                    # o mesmo botão é como a pastilha "ACEITA SECO" mentiu antes.
                    "rede": bool(rede),
                })
    except OSError:
        return []
    return fora

# ponto único do que a máquina não conserta sozinha: a sentinela do apt e o
# patch obrigatório que não entra gravam por `meow_precisa_de_gente`, e a Início
# desenha UM cartão.
PRECISA_DE_GENTE = os.path.join(ESTADO, "precisa-de-gente.tsv")


def precisa_de_gente():
    """As linhas do precisa-de-gente.tsv: [{id, nome, desde, porque}]. Ausente é lista vazia."""
    fora = []
    try:
        with open(PRECISA_DE_GENTE, "r", encoding="utf-8") as fh:
            for linha in fh:
                campos = linha.rstrip("\n").split("\t")
                if len(campos) != 4 or not campos[0] or not campos[1]:
                    continue
                fora.append(dict(zip(("id", "nome", "desde", "porque"), campos)))
    except OSError:
        return []
    return fora


def _trabalho_json(trabalho, acao_id, seco=False):
    """O que a página precisa para abrir a gaveta de um trabalho que começou.

    `escreve` vai junto porque é ele que decide, no fim, se a página relê a
    máquina e esvazia a bandeja de pendentes. Até a P50 (24/09/2026) servia
    também para traduzir o código de saída — o 1 de quem escreve era
    "consertei", o de quem só lê era "há divergências", ver o `/api/rodar` —;
    hoje a frase do fim vem pronta em `fim`, pela natureza da ação.

    `seco` É UM CAMPO À PARTE, E NÃO UM `escreve: False` — 22/09/2026, P8
      A tentação era dizer que um ensaio "não escreve" e reaproveitar o campo
      que já existe. Seriam duas verdades diferentes no mesmo lugar: `escreve`
      fala da AÇÃO (o `instalar` escreve, sempre), e `seco` fala desta
      EXECUÇÃO. A página precisa das duas — a primeira para saber se relê a
      máquina, a segunda para pintar o cabeçalho amarelo e para NÃO limpar a
      bandeja de pendentes no fim. Fundi-las faria um ensaio do instalador
      terminar com a pastilha "já estava certo" e a bandeja vazia, que é a
      mentira que esta sprint veio matar. (Desde a P50 a pastilha não
      depende mais de nenhuma das duas: a do ensaio é a da natureza `ensaio`,
      que o `fim_da_acao` escolhe. A bandeja continua dependendo.)
    """
    # O topo da gaveta mostra o comando como a pessoa o digitaria, e não o
    # `argv` cru com o caminho do clone — ver `comando_na_tela`.
    return {"id": trabalho.id, "rotulo": trabalho.rotulo, "acao": acao_id,
            "escreve": escreve(ACOES[acao_id]),
            "seco": bool(seco),
            "conserta_com": ACOES[acao_id].get("conserta_com"),
            "fim": fim_da_acao(acao_id, seco)}


def _previa_dos_jogos(mapa):
    """O que a passagem dos jogos faria com `mapa` no lugar do mapa do disco.

    {"entram": [...], "saem": [...], "repetem": [...], "apagam": [...]}, cada
    item `{appid, nome}`; ou {"erro": ...}. `repetem` é o cartão duplicado ou de
    gerador antigo que a mesma passagem tira (revisão da P54). Quem responde é o `jogos_steam.sh --conferir`,
    rodado aqui sobre uma cópia, pelas linhas `@@jogo` que ele só imprime com
    `MEOW_JOGOS_RESUMO=1` — ver o bloco «O RESUMO PARA A CAIXA DO PAINEL» lá.
    A regra de quem entra e quem sai fica escrita num lugar só, e é o script.

    Espera, e não trabalho em fundo: a caixa não tem o que mostrar antes da
    resposta, e a passagem seca de uma biblioteca de trinta jogos é coisa de
    um ou dois segundos. O teto de 60 s é o de um disco externo lento; passado
    ele, a caixa diz que não deu para conferir, e a decisão continua possível."""
    conf = conf_exportada()
    if conf is None:
        return {"erro": "não consegui ler o meow.conf"}
    pasta = tempfile.mkdtemp(prefix="meow-jogos-")
    try:
        copia = os.path.join(pasta, "jogos-fora.map")
        with open(copia, "w", encoding="utf-8") as fh:
            fh.write(mapa)
        ambiente = _ambiente_do_painel(seco=True)
        ambiente.update(conf)
        ambiente.update(MEOW_JOGOS_FORA=copia, MEOW_JOGOS_RESUMO="1", NO_COLOR="1")
        proc = subprocess.run(
            [os.path.join(RAIZ, "scripts", "jogos_steam.sh"), "--conferir"],
            cwd=RAIZ, env=ambiente, stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
    except (OSError, subprocess.SubprocessError) as e:
        return {"erro": "não deu para conferir os jogos: %s" % e}
    finally:
        shutil.rmtree(pasta, ignore_errors=True)
    saida = {"entram": [], "saem": [], "repetem": [], "apagam": []}
    campo = {"entra": "entram", "sai": "saem", "repete": "repetem", "apaga": "apagam"}
    for linha in proc.stdout.decode("utf-8", "replace").splitlines():
        partes = linha.split(" ", 3)
        if len(partes) == 4 and partes[0] == "@@jogo" and partes[1] in campo \
                and partes[2].isdigit():
            saida[campo[partes[1]]].append({"appid": partes[2], "nome": partes[3].strip()})
    return saida


def jogos_do_heroic():
    """Os jogos instalados no Heroic: [{id, nome, url, no_lancador}]. Quem lê a
    biblioteca é o `jogos_heroic.sh --listar`; sem Heroic, lista vazia."""
    try:
        r = subprocess.run([os.path.join(RAIZ, "scripts", "jogos_heroic.sh"), "--listar"],
                           capture_output=True, timeout=30, env=_ambiente_do_painel(seco=True))
    except (OSError, subprocess.SubprocessError):
        return []
    fora = []
    capas = os.path.expanduser("~/.local/share/icons/hicolor/256x256/apps")
    for linha in r.stdout.decode("utf-8", "replace").splitlines():
        campos = linha.split("\t")
        if len(campos) != 4 or not campos[0].startswith("meow-heroic-"):
            continue
        capa = os.path.join(capas, campos[0] + ".png")
        fora.append({"id": campos[0], "nome": campos[1],
                     "url": ("/previa?tipo=arquivo&id=" + quote(capa, safe=""))
                            if os.path.isfile(capa) else "",
                     "no_lancador": campos[3] == "sim"})
    return fora


def _guardar_antes_py(pasta, caminho, conteudo):
    """O `meow_guardar_antes` para o que o servidor escreve antes do trabalho:
    `conteudo` é o arquivo como era (None: não existia)."""
    alvo = os.path.realpath(caminho)
    os.makedirs(pasta, exist_ok=True)
    if conteudo is None:
        linha = "%s\tnovo\n" % alvo
    else:
        copia = pasta + "/antes" + alvo
        os.makedirs(os.path.dirname(copia), exist_ok=True)
        with open(copia, "wb") as fh:
            fh.write(conteudo)
        linha = "%s\texistia\n" % alvo
    with open(os.path.join(pasta, "tocados.tsv"), "a", encoding="utf-8") as fh:
        fh.write(linha)


def iniciar(acao_id, argumento, confirmado=False, seco=False, pasta_de_ensaio=None,
            antes=None):
    """Começa uma ação. Devolve (trabalho, erro) — o erro pode ser um dicionário.

    `seco` roda com `MEOW_DRY_RUN=1` (ver `_ambiente_do_painel`): o motor já
    sabe ensaiar desde sempre (`meow_seco` em lib/comum.sh), e o que faltava
    era a tela poder pedir.

    `pasta_de_ensaio` é o diretório do `_conf_de_ensaio`: dentro dele mora um
    meow.conf DESCARTÁVEL, cópia do dela com as escolhas ainda não gravadas
    dentro. Ele vira `MEOW_CONF` para este trabalho e é apagado quando o
    trabalho termina. Existe porque o ensaio do «Salvar e aplicar» tem de
    responder sobre AS ESCOLHAS, e não sobre o conf do disco — ver o cabeçalho
    do `_conf_de_ensaio` para a medição de por que ambiente não servia."""
    global TRABALHO_ATUAL
    acao = ACOES.get(acao_id)
    if acao is None:
        return (None, "ação desconhecida")

    # O BOTÃO APAGADO TAMBÉM É TRANCA DO SERVIDOR. A página não o oferece;
    # um POST direto (ou uma página lida antes de a máquina mudar) ouve o
    # motivo, que o cartão diz com as palavras da tela.
    if indisponivel(acao_id):
        return (None, "«%s» não teria efeito agora — o cartão diz por quê"
                      % acao["rotulo"])

    # O campo `confirma` existe desde o primeiro dia e era só uma DICA: a
    # página perguntava se quisesse, e um POST direto (ou um botão que
    # esquecesse de perguntar) disparava `./install.sh` ou o `desfazer` na
    # mesma linha.
    #
    # O erro sai como DICIONÁRIO (e não frase) porque a página tem de poder
    # distinguir "preciso perguntar" de "deu errado" sem ler texto: um é uma
    # pergunta a fazer, o outro é uma torrada vermelha.
    if acao.get("confirma") and not confirmado:
        return (None, {
            "erro": "esta ação escreve na máquina e precisa de confirmação",
            "precisa_confirmar": True,
            "acao": acao_id,
            "rotulo": acao["rotulo"],
            "ajuda": _ajuda_do_pack(acao_id) or acao.get("ajuda", ""),
            "escreve": escreve(acao),
            "sudo": bool(acao.get("sudo")),
            "rede": bool(acao.get("rede")),
            "destrutivo": bool(acao.get("destrutivo")),
        })

    argv = list(acao["argv"])
    # O ARGUMENTO PODE IR PELO AMBIENTE: o gesto da extensão do VS Code roda
    # o verbo de sempre e diz QUAL extensão numa variável. A cerca é a mesma
    # — a lista do provedor —, e só o lugar do `@ARG@` muda.
    amb_acao = dict(acao.get("ambiente", {}))
    if "@ARG@" in argv or "@ARG@" in amb_acao.values():
        permitidos = PROVEDORES[acao["arg"]]()
        if argumento not in permitidos:
            return (None, "argumento fora da lista do disco: %r" % (argumento,))
        argv = [argumento if p == "@ARG@" else p for p in argv]
        amb_acao = {k: (argumento if v == "@ARG@" else v) for k, v in amb_acao.items()}
    elif argumento:
        return (None, "esta ação não recebe argumento")
    rotulo = acao["rotulo"]
    pasta_restauro = None
    if acao_id == "restaurar":
        pasta_restauro = restauros().get(argumento)
        if not pasta_restauro:
            return (None, "não há o que restaurar nessa ação")
        argv = [pasta_restauro if p == argumento else p for p in argv]
        rotulo = "Restaurar «%s»" % ACOES[argumento]["rotulo"]

    # Sem ela, a ação que chama um script de `scripts/` direto roda com cada
    # chave no padrão.
    conf_do_ensaio = os.path.join(pasta_de_ensaio, "meow.conf") if pasta_de_ensaio else None
    conf = conf_exportada(conf_do_ensaio)
    if conf is None:
        return (None, "não consegui ler o meow.conf — sem ele o trabalho rodaria "
                      "com cada chave no padrão, e por isso não roda")
    ambiente = _ambiente_do_painel(seco)
    ambiente.update(conf)
    ambiente.update(amb_acao)
    # DEPOIS do `ambiente` da ação, e de propósito: `MEOW_CONF` não é uma chave
    # do conf, é o ENDEREÇO dele.
    if conf_do_ensaio:
        ambiente["MEOW_CONF"] = conf_do_ensaio
        # O ensaio passa a ler os mesmos mapas.
        pasta_dela = os.path.dirname(CONF)
        ambiente.setdefault("MEOW_ICONES_ESCOLHAS",
                            _mapa_de_escolhas_do_usuario())
        ambiente.setdefault("MEOW_ICONES_TRACO",
                            os.path.join(pasta_dela, "icones-traco.map"))
        # E O MAPA DOS JOGOS, quando o ensaio é de uma decisão de jogo ainda não
        # gravada: o `jogos_steam.sh` lê o mapa por esta variável, e a cópia com
        # a decisão dentro mora na mesma pasta.
        mapa_do_ensaio = os.path.join(pasta_de_ensaio, "jogos-fora.map")
        if os.path.isfile(mapa_do_ensaio):
            ambiente["MEOW_JOGOS_FORA"] = mapa_do_ensaio
    # O `install.sh` cala o progresso quando NÃO há terminal (`[ ! -t 1 ]`), e é
    # a decisão certa lá — quase 600 linhas num journal não têm leitor.
    if ambiente.get("LOG_NIVEL", "") != "debug":
        ambiente["LOG_NIVEL"] = "info"
    # Cor de terminal não tem sentido em HTML, e os scripts já a desligam sozinhos
    # quando a saída é um cano (`[ -t 1 ]` em lib/comum.sh). `NO_COLOR` é o cinto:
    # um script de terceiro no meio do caminho pode não fazer esse teste.
    ambiente["NO_COLOR"] = "1"

    # O estado de antes vai para uma pasta desta execução; o «Restaurar» não
    # guarda o próprio antes (desfazer o desfazer é rodar a ação de novo).
    if escreve(acao) and not seco and acao_id != "restaurar":
        pasta_restauro = os.path.join(RESTAUROS, "%s-%s-%s" % (
            time.strftime("%Y%m%dT%H%M%S"), acao_id, secrets.token_hex(3)))
        ambiente["MEOW_BACKUPS"] = pasta_restauro
        for caminho, conteudo in (antes or {}).items():
            try:
                _guardar_antes_py(pasta_restauro, caminho, conteudo)
            except OSError:
                pass
    vivo = {}

    def ao_terminar():
        # A CÓPIA DO ENSAIO MORRE COM O TRABALHO, e não aqui: ele acabou de
        # nascer e vai sourcear aquele arquivo pelos próximos segundos.
        if pasta_de_ensaio:
            shutil.rmtree(pasta_de_ensaio, ignore_errors=True)
        t = vivo.get("t")
        if acao_id == "restaurar":
            if t is not None and t.rc in (0, 1):
                _esquecer_restauro(argumento, pasta_restauro)
        elif pasta_restauro:
            _guardar_restauro(acao_id, pasta_restauro)

    with TRABALHO_TRAVA:
        if TRABALHO_ATUAL is not None and TRABALHO_ATUAL.vivo():
            if acao_id != "restaurar" and pasta_restauro:
                shutil.rmtree(pasta_restauro, ignore_errors=True)
            return (None, "já há um trabalho correndo: %s" % TRABALHO_ATUAL.rotulo)
        try:
            trabalho = Trabalho(acao_id, argv, ambiente, rotulo, ao_terminar=ao_terminar)
        except OSError as erro:
            if acao_id != "restaurar" and pasta_restauro:
                shutil.rmtree(pasta_restauro, ignore_errors=True)
            return (None, str(erro))
        vivo["t"] = trabalho
        trabalho.pasta_restauro = pasta_restauro if acao_id != "restaurar" else None
        TRABALHOS[trabalho.id] = trabalho
        TRABALHO_ATUAL = trabalho
    return (trabalho, None)


# --- 7. o HTTP ---------------------------------------------------------------
TIPOS = {
    ".html": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".js": "text/javascript; charset=utf-8",
    ".svg": "image/svg+xml",
    ".json": "application/json; charset=utf-8",
}


# A decisão de ler do remoto FICA assim mesmo, porque o motivo dela nunca foi o
# sanitizador — é o parágrafo abaixo.
#
# Ler do remoto é mais certo, e não só mais seguro: num fork o item do menu
# passa a apontar para o fork de quem clonou, que é o repositório de quem está
# olhando a tela.
_medidas_cache = {"carimbo": None, "valor": None}


def _medidas_do_projeto():
    """Os dois números que a página diz em voz alta — CONTADOS do código, nunca
    escritos aqui.

    QUATRO LUGARES DIZIAM O MESMO NÚMERO E TRÊS ESTAVAM ERRADOS — 09/09/2026
      O desenho da aba «Instalação» abria com `const ETAPAS_DO_INSTALADOR = 52`
      e um comentário logo acima jurando *"os dois números são CONTADOS, não
      lembrados"*. Eram lembrados: o `install.sh` tinha 53 etapas e o
      `bin/meow`, 48 conferências. A ajuda dos botões dizia 52 e 46, o README
      dizia 47, e o `docs/SPRINTS.md` dizia 46 — cinco versões da mesma verdade,
      nenhuma conferida por ninguém.

      É a armadilha nº 3 do repositório com outra roupa. Onde ela aparece como
      *"toda lista fixa é uma lista que alguém vai esquecer"* — e por isso o
      catálogo de chaves é derivado do `meow.conf.exemplo` —, aqui ela aparece
      como TODO NÚMERO ESCRITO À MÃO É UM NÚMERO QUE ENVELHECE. A cura é a
      mesma: contar na hora, da mesma fonte que executa.

    DE ONDE SAI CADA UM
      `etapas`       o `local etapas=(…)` do `install.sh` — a lista que o `main`
                     percorre. Contar as funções `etapa_*` definidas no arquivo
                     daria um número MAIOR: existem funções de etapa que a lista
                     não chama (as do lançador entram por dentro de outra).
      `conferencias` o `VERIFICAVEIS=(…)` do `bin/meow` — a lista que o `doctor`
                     percorre. Conferido em 09/09/2026: ela tem exatamente os
                     mesmos 48 nomes das funções `chk_*` definidas no arquivo,
                     e nenhuma sobra dos dois lados.

    QUANDO NÃO DÁ PARA CONTAR, NÃO SE CHUTA
      Devolve `None` para o número que não conseguiu contar, e quem exibe tem de
      saber calar. Um número errado na tela é pior que nenhum: foi exatamente
      assim que os 52 sobreviveram a uma etapa nova sem ninguém notar.

    O cache é pelo (mtime, tamanho) dos dois arquivos, e não pelo relógio: a
    página relê o esquema a cada ação, e o `install.sh` pode ganhar uma etapa
    no meio da sessão — foi para esse caso que este número deixou de ser
    constante.
    """
    inst = os.path.join(RAIZ, "install.sh")
    cli = os.path.join(RAIZ, "bin", "meow")
    try:
        carimbo = tuple((os.path.getmtime(f), os.path.getsize(f))
                        for f in (inst, cli))
    except OSError:
        return {"etapas": None, "conferencias": None}
    if _medidas_cache["carimbo"] == carimbo:
        return _medidas_cache["valor"]

    def ler(caminho):
        try:
            with open(caminho, encoding="utf-8", errors="replace") as fh:
                return fh.read()
        except OSError:
            return ""

    etapas = None
    # A lista atravessa várias linhas e termina no primeiro `)` — por isso o
    # `[^)]*`, e não um `.*?` guloso que engoliria o resto do arquivo.
    m = re.search(r"^\s*local etapas=\(([^)]*)\)", ler(inst), re.M)
    if m:
        nomes = re.findall(r"\betapa_[a-z_0-9]+\b", m.group(1))
        if nomes:
            etapas = len(set(nomes))

    conferencias = None
    m = re.search(r"^VERIFICAVEIS=\(([^)]*)\)", ler(cli), re.M)
    if m:
        nomes = m.group(1).split()
        if nomes:
            conferencias = len(set(nomes))

    valor = {"etapas": etapas, "conferencias": conferencias}
    _medidas_cache["carimbo"] = carimbo
    _medidas_cache["valor"] = valor
    return valor


def _medidas_da_tela():
    """O tamanho geral de cada barra e a régua dos applets — lidos, não lembrados.

    O `app.js` desenhava a barra com duas cópias à mão: `TAMANHO_GERAL =
    {painel: "S", dock: "M"}` ("lidos do disco em 26/08/2026") e os cinco
    números do `meow_painel_T`. A primeira é a foto de um dia; a segunda, uma
    lista que o `lib/painel.sh` pode mudar sem avisar ninguém. É a mesma cura do
    `_medidas_do_projeto`: ler na hora, da fonte que a máquina usa. Sem cache —
    são dois arquivos de uma linha e um script de poucos KB. — 13/09/2026"""
    barra = {}
    for nome, (_suf, pasta) in zip(("painel", "dock"), _BARRAS):
        m = re.match(r"^(?:Some\()?%s\)?$" % _DEGRAU, _cosmic_ler(pasta + "size") or "")
        if m:
            barra[nome] = m.group(1)
    try:
        with open(os.path.join(RAIZ, "lib", "painel.sh"), encoding="utf-8") as fh:
            texto = fh.read()
    except OSError:
        texto = ""
    regua = {}
    corpo = re.search(r"^meow_painel_T\(\)\s*\{(.*?)^\}", texto, re.M | re.S)
    if corpo:
        for nome, px in re.findall(r"^\s*%s\)\s*printf '(\d+)'" % _DEGRAU, corpo.group(1), re.M):
            regua[nome] = int(px)
    return {"barra": barra, "tamanho_applet": regua}


def _com_medidas(texto, medidas):
    """Troca `{as_etapas}` e `{as_conferencias}` pela contagem de agora.

    O NÚMERO VEM COM O ARTIGO, e isso não é preciosismo: quando a contagem
    falha, o texto tem de continuar sendo uma frase em português. `as 53 etapas`
    vira `as etapas`, e a ajuda do botão perde o número em vez de ganhar um
    buraco (`as  etapas`) ou uma mentira (o último número que alguém lembrou).
    """
    n = (medidas or {}).get("etapas")
    texto = texto.replace("{as_etapas}", "as %d etapas" % n if n else "as etapas")
    n = (medidas or {}).get("conferencias")
    return texto.replace("{as_conferencias}",
                         "as %d conferências" % n if n else "as conferências")


def _ajuda_do_pack(acao_id):
    """A ajuda de uma ação cujo texto depende do pack no ar, ou ''.

    O TEMA DO SPOTIFY É O QUE O PACK DECLARA — 24/09/2026, P51 (achado 42)
        A ajuda dizia «Baixa o tema catppuccin do spicetify» com o Dracula no ar,
        e o Spotify já em Sleek/Dracula. Quem decide o tema e se há de onde
        baixá-lo é o `apps.spotify` do pack (o `_spot_tema_baixar` do módulo
        pergunta o mesmo ao `tema_de_app`): com `origem` o tema desce pinado;
        sem ela nada é baixado, e o módulo veste o Spotify com o tema que já
        estiver no spicetify. A frase diz qual dos dois, e de qual pack.
    """
    if acao_id != "spotify_baixar_tema":
        return ""
    mod = modulo_pack()
    ref = _pack_no_ar()
    if not mod or not ref:
        return ""
    try:
        _q, tema = mod.tema_de_app("apps.spotify.spicetify_tema", ref=ref)
        _q, repo = mod.tema_de_app("apps.spotify.origem.repo", ref=ref)
        nome = mod.campo(ref, "nome") or ref
    except Exception:
        return ""
    if not tema:
        return ""
    if repo:
        return ("Baixa o tema «%s» do spicetify de um commit fixo de %s e veste "
                "o Spotify em seguida." % (tema, repo))
    return ("O pack «%s» pede o tema «%s» do spicetify e não diz de onde baixá-lo: "
            "nada desce da internet, e o Spotify é vestido com o tema que já "
            "estiver no spicetify." % (nome, tema))


def _repositorio_no_ar():
    """A URL https do `origin`, ou "" quando não há remoto que sirva."""
    try:
        proc = subprocess.run(["git", "-C", RAIZ, "remote", "get-url", "origin"],
                              capture_output=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return ""
    if proc.returncode != 0:
        return ""
    url = proc.stdout.decode("utf-8", "replace").strip()
    if not url:
        return ""
    # `git@github.com-pessoal:dona/Projeto.git` ->
    # `https://github.com/dona/Projeto` O sufixo depois do host é apelido de
    # `~/.ssh/config`, e não host de verdade: esta máquina usa um para separar
    # duas contas.
    m = re.match(r"^(?:git@|ssh://git@)([^:/]+)[:/](.+?)(?:\.git)?/?$", url)
    if m:
        host = m.group(1).split("-", 1)[0] if "." in m.group(1) else m.group(1)
        return "https://%s/%s" % (host, m.group(2))
    m = re.match(r"^(https?://[^/]+/.+?)(?:\.git)?/?$", url)
    return m.group(1) if m else ""


def idiomas_da_sessao():
    """A cadeia de idioma da sessão, na ordem em que um `Name[…]` se procura.

    O NOME QUE O LANÇADOR MOSTRA — 24/09/2026, sprint P57 (item 3)
        As fichas do painel diziam o `Name=` cru — «COSMIC Settings»,
        «Camera» —, e o lançador do COSMIC, «Configurações» e «Câmera»: o
        `Name[pt_BR]`. Medido nesta máquina: 5 dos 49 `.desktop` visíveis têm
        um `Name[pt_BR]` diferente do `Name=`, e 2 dos 32 da lista de fábrica do
        «Quais programas o lançador esconde».

    A REGRA É A DA ESPECIFICAÇÃO (Desktop Entry, "Localized values for keys"):
        para `lang_PAÍS.CODIFICAÇÃO@MOD`, procura-se `lang_PAÍS@MOD`,
        `lang_PAÍS`, `lang@MOD` e `lang`, e sem nenhum vale a chave sem idioma;
        a codificação não entra. A cadeia é a do gettext e do GLib: a lista do
        `LANGUAGE`, e depois o primeiro que houver de `LC_ALL`, `LC_MESSAGES` e
        `LANG` — "C" e "POSIX" não têm tradução.

    O QUE FICA DE FORA: a tradução por catálogo (`X-Ubuntu-Gettext-Domain`),
        extensão do Ubuntu que a especificação não tem. Medido: o «Fonts» do
        `org.gnome.font-viewer` é desse tipo, e o catálogo pt_BR do domínio
        dele não está instalado nesta máquina — nem o de nenhum dos outros
        domínios que os `.desktop` daqui citam."""
    brutos = [v for v in os.environ.get("LANGUAGE", "").split(":") if v]
    brutos += [os.environ[n] for n in ("LC_ALL", "LC_MESSAGES", "LANG") if os.environ.get(n)][:1]
    fora = []
    for bruto in brutos:
        base, _arroba, modificador = bruto.partition("@")
        base = base.split(".", 1)[0]
        if base in ("", "C", "POSIX"):
            continue
        lingua, _sublinha, pais = base.partition("_")
        for v in ("%s_%s@%s" % (lingua, pais, modificador) if pais and modificador else "",
                  "%s_%s" % (lingua, pais) if pais else "",
                  "%s@%s" % (lingua, modificador) if modificador else "",
                  lingua):
            if v and v not in fora:
                fora.append(v)
    return fora


class Manipulador(BaseHTTPRequestHandler):
    server_version = "MeowSystem"
    sys_version = ""
    protocol_version = "HTTP/1.1"

    # O log padrão do http.server escreve uma linha por pedido no stderr, e o
    # `run.sh` mostra o stderr na tela dela. Uma página que faz uma sondagem a
    # cada 400 ms encheria o terminal de ruído em um minuto.
    def log_message(self, formato, *args):
        if os.environ.get("MEOW_APP_DEBUG") == "1":
            sys.stderr.write("  .. %s\n" % (formato % args))

    # --- as duas trancas ----------------------------------------------------
    def _host_confere(self):
        """DNS rebinding: o `Host` tem de ser o nosso, e não um domínio de fora."""
        host = (self.headers.get("Host") or "").strip()
        porta = self.server.server_address[1]
        return host in ("127.0.0.1:%d" % porta, "localhost:%d" % porta)

    def _origem_confere(self):
        origem = self.headers.get("Origin")
        if not origem:
            return True     # GET de página local não manda Origin
        porta = self.server.server_address[1]
        return origem in ("http://127.0.0.1:%d" % porta, "http://localhost:%d" % porta)

    # O token entra por três portas: o cabeçalho `X-Meow-Token`, o `?t=` da URL e o
    # cookie. Folha e script são pedidos que o navegador faz sozinho, sem cabeçalho
    # nosso; sem o cookie eles tomavam 403, calados.
    #
    # Havia um segundo defeito escondido atrás do primeiro, e pior: o `app.js`
    # apaga o `?t=` da barra de endereço no primeiro instante (um token no
    # histórico do navegador sobreviveria à sessão que o criou). O cookie
    # `SameSite=Strict` cobre o F5, e pedido de outro site não o carrega (CSRF).
    def _token_confere(self, consulta):
        for dado in (self.headers.get("X-Meow-Token") or "",
                     consulta.get("t", [""])[0],
                     self._cookie()):
            if dado and hmac.compare_digest(dado, TOKEN):
                return True
        return False

    def _cookie(self):
        """O valor de `meow_token` no cabeçalho Cookie, ou vazio."""
        bruto = self.headers.get("Cookie") or ""
        for pedaco in bruto.split(";"):
            nome, _, valor = pedaco.strip().partition("=")
            if nome == "meow_token":
                return valor
        return ""

    def _recusar(self, codigo, texto):
        corpo = texto.encode("utf-8")
        self.send_response(codigo)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(corpo)))
        self.end_headers()
        self.wfile.write(corpo)

    def _responder(self, corpo, tipo="application/json; charset=utf-8", codigo=200,
                   plantar_cookie=False, extras=None):
        if isinstance(corpo, str):
            corpo = corpo.encode("utf-8")
        self.send_response(codigo)
        self.send_header("Content-Type", tipo)
        self.send_header("Content-Length", str(len(corpo)))
        if plantar_cookie:
            # Sem `Expires`/`Max-Age`: é cookie de SESSÃO, e morre quando o
            # navegador fecha — que é mais ou menos quando este processo morre.
            # Sem `Secure` de propósito: a origem é `http://127.0.0.1`, e um cookie
            # `Secure` não seria gravado ali.
            self.send_header(
                "Set-Cookie",
                "meow_token=%s; Path=/; SameSite=Strict; HttpOnly" % TOKEN,
            )
        # A página é local e privada; nenhum cache intermediário faz sentido, e
        # um `esquema` cacheado mostraria o valor de antes da escrita.
        self.send_header("Cache-Control", "no-store")
        # Cinto: mesmo servindo só de 127.0.0.1, uma página que não pode ser
        # embutida em iframe alheio nem adivinhada por sniffing custa duas linhas.
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        # Os cabeçalhos que só uma resposta precisa — hoje, o
        # `Content-Disposition` dos dois botões de exportar.
        #
        # Um SVG é um documento: aberto DIRETO pela URL (e não por `<img>`), o
        # `<script>` e o `onload=` dele rodam na origem do painel, com o cookie
        # do token, e chamam qualquer `/api/` como se fossem a página.
        extras = dict(extras or {})
        if tipo.startswith("image/"):
            extras["Content-Security-Policy"] = CSP_DE_IMAGEM
        for nome, valor in extras.items():
            self.send_header(nome, valor)
        self.end_headers()
        self.wfile.write(corpo)

    def _json(self, dados, codigo=200):
        self._responder(json.dumps(dados, ensure_ascii=False), codigo=codigo)

    def _pulso(self):
        """A conexão que diz "a página está aberta" enquanto ela existir.

        Não carrega dado nenhum, e é de propósito: o que informa é o socket
        estar de pé. Fechada a janela, a escrita seguinte falha, o pulso cai e o
        `_vigia` sai. O `Connection: close` é obrigatório — em HTTP/1.1 uma
        resposta sem `Content-Length` só é legal assim.
        """
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        _pulso_entra()
        try:
            while True:
                # Comentário SSE (linha iniciada por ":"): o `EventSource` do
                # outro lado o descarta sem disparar evento nenhum, e ele serve
                # só para a escrita acontecer.
                self.wfile.write(b": meow\n\n")
                self.wfile.flush()
                # O `select` é quem enxerga a janela fechar. Um socket cujo
                # outro lado foi embora fica LEGÍVEL, e o `recv` devolve vazio:
                # é o fim-de-arquivo do TCP.
                pronto, _, _ = select.select([self.connection], [], [], PULSO_BATIDA)
                if pronto and not self.connection.recv(1):
                    break
        except (OSError, ValueError):
            pass
        finally:
            _pulso_sai()

    # --- rotas ---------------------------------------------------------------
    def _logo_do_painel(self):
        valores = valores_efetivos(["FLAVOR", "ACCENT", "MODO"])
        flavor = _flavor_do_conf(valores)
        flavor = _flavor_da_pagina(flavor, valores)
        return logo_do_painel(flavor, _acento_da_pagina(flavor, valores))

    def do_GET(self):
        alvo = urlparse(self.path)
        consulta = parse_qs(alvo.query)
        if not self._host_confere():
            return self._recusar(403, "Host inesperado")
        if not self._origem_confere():
            return self._recusar(403, "Origem inesperada")
        caminho = alvo.path

        if caminho in ("/", "/index.html"):
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            return self._servir_pagina()

        if caminho.startswith("/api/"):
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            # O pulso NÃO passa pelo `_api_get`: aquele roteador devolve JSON e
            # fecha, e este pedido é o contrário — fica aberto até a janela
            # sumir. Ver o bloco "O PAINEL MORRE COM A JANELA QUE O ABRIU".
            if caminho == "/api/pulso":
                return self._pulso()
            return self._api_get(caminho, consulta)

        if caminho == "/folha":
            # A rota mora AQUI, e não em `_api_get`: `/folha` não começa com
            # `/api/`, então lá ela nunca era alcançada — o roteador respondia
            # "não existe aqui" antes.
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            # AS FOLHAS SÃO PARA ABRIR, e não para copiar caminho.
            nome_folha = os.path.basename(consulta.get("id", [""])[0] or "")
            alvo_folha = os.path.realpath(os.path.join(FOLHAS, nome_folha))
            if (not alvo_folha.startswith(os.path.realpath(FOLHAS) + os.sep)
                    or not alvo_folha.endswith(".html")
                    or not os.path.isfile(alvo_folha)):
                return self._recusar(404, "não achei")
            try:
                with open(alvo_folha, "rb") as fh:
                    dados_folha = fh.read()
            except OSError:
                return self._recusar(404, "não achei")
            self.send_response(200)
            # `text/html` com CSP fechada: a folha é arquivo NOSSO, mas ela vem
            # de fora do fluxo normal da página e não tem por que rodar script.
            self.send_header("Content-Type", "text/html; charset=utf-8")
            # O que fica de fora é o que importa: nada de rede (`connect-src`
            # ausente herda `none`), nada de iframe, nada de formulário.
            self.send_header(
                "Content-Security-Policy",
                "default-src 'none'; img-src data: blob:; "
                "style-src 'unsafe-inline'; script-src 'unsafe-inline'; "
                "font-src data:")
            self.send_header("Content-Length", str(len(dados_folha)))
            self.end_headers()
            self.wfile.write(dados_folha)
            return None



        # Ter o gato dela ali é melhor de qualquer forma, e é de graça: o acervo
        # `packs/meowsystem/mascote/` já é a configuração deste projeto, e a chave `LOGO`
        # diz qual está no ar.
        #
        # A MARCA DO APLICATIVO NÃO É UM GATO DELA — é o ícone do `.desktop`.
        #
        # O `stroke` É TROCADO AQUI, e não no gerador.
        if caminho == "/logo.svg":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            corpo = self._logo_do_painel()
            if corpo is None:
                return self._recusar(404, "a logo autoral não está no acervo")
            return self._responder(corpo, tipo=TIPOS[".svg"])

        if caminho == "/gato.svg":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            nome = os.path.basename(valores_efetivos(["LOGO"]).get("LOGO") or "coquinha")
            arquivo = os.path.join(_pasta_do_mascote(), nome + ".svg")
            if not os.path.isfile(arquivo):
                gatos = _gatos()
                if not gatos:
                    return self._recusar(404, "não há mascote no acervo")
                arquivo = os.path.join(_pasta_do_mascote(), gatos[0] + ".svg")
            with open(arquivo, "rb") as fh:
                return self._responder(fh.read(), tipo=TIPOS[".svg"])

        # 404 igual para "não existe" e "não é seu", pela mesma razão da
        # `/previa`: resposta diferente vira sonda de existência de arquivo.
        #
        # Dentro de um `<img>` o navegador não roda script de SVG; aberto
        # direto, na aba, rodaria — e na MESMA origem do painel, com o cookie do
        # token.
        if caminho == "/pack-vitrine":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            achado = arte_da_vitrine(consulta.get("id", [""])[0],
                                     consulta.get("arte", [""])[0])
            if achado is None:
                return self._recusar(404, "não achei")
            corpo, tipo_mime = achado
            return self._responder(corpo, tipo=tipo_mime)

        if caminho == "/previa" and consulta.get("tipo", [""])[0] == "arquivo":
            # O TOKEN FALTAVA AQUI, e só aqui.
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            # SERVIR UM ARQUIVO POR CAMINHO É UMA PORTA, e ela tem cerca. Sem a
            # cerca, um GET forjado leria QUALQUER arquivo do disco
            # (`/previa?tipo=arquivo&id=/etc/shadow`).
            permitidos = set()
            for x in (os.path.join(RAIZ, "packs"),
                      os.path.expanduser("~/.local/share/icons"),
                      os.path.expanduser("~/.local/share/flatpak/exports/share/icons"),
                      "/usr/share/icons",
                      "/usr/share/pixmaps",
                      "/var/lib/flatpak/exports/share/icons",
                      os.path.expanduser("~/.local/share/Steam"),
                      os.path.expanduser("~/.steam")):
                if os.path.isdir(x):
                    permitidos.add(os.path.normpath(x))
                    permitidos.add(os.path.realpath(x))
            # Metade dos aplicativos desta máquina cai nesse caso.
            #
            # O que se aceita a mais é um link que o próprio sistema pôs DENTRO
            # de uma raiz permitida; plantar um lá exige já ser dono de
            # `/usr/share` ou da pasta de flatpak dela, e a peneira de extensão
            # continua de pé.
            #
            # A lista de raízes não cresce: o `normpath` do caminho pedido mata o `..`
            # (`/usr/share/icons/../../etc/shadow` vira `/etc/shadow`, que raiz nenhuma cobre).
            pedido = os.path.normpath(consulta.get("id", [""])[0] or "")
            alvo_arq = os.path.realpath(pedido)
            ok_pasta = any(pedido.startswith(p + os.sep) or alvo_arq.startswith(p + os.sep)
                           for p in permitidos) or pedido in _ICONES_DECLARADOS
            ext_arq = os.path.splitext(pedido)[1].lower()
            ext_alvo = os.path.splitext(alvo_arq)[1].lower()
            if ext_alvo != ext_arq or not os.path.isfile(alvo_arq):
                return self._recusar(404, "não achei")
            # O `.jpg` entrou com a seção "Jogos da Steam": a arte do
            # `appcache/librarycache` é JPEG, e sem ele a grade de jogos abriria
            # com 22 quadrados vazios.
            if not ok_pasta or ext_arq not in (".svg", ".png", ".jpg", ".jpeg"):
                return self._recusar(404, "não achei")
            try:
                with open(alvo_arq, "rb") as fh:
                    dados_arq = fh.read()
            except OSError:
                return self._recusar(404, "não achei")
            tipo_mime = {".svg": "image/svg+xml", ".png": "image/png",
                         ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}[ext_arq]
            # O `feitos-a-mao/obsidian.png` do pack Dracula é um SVG com nome de
            # PNG (veio assim do Dracula_OS-Theme, ver o PROCEDENCIA.md), e a
            # ficha de ícone o mostrava quebrado: o navegador recebia
            # `image/png` e não achava PNG nenhum.
            if ext_arq != ".svg" and comeca_como_svg(dados_arq):
                tipo_mime = "image/svg+xml"
            # Pela porta única em vez de cinco send_header à mão.
            return self._responder(dados_arq, tipo=tipo_mime)

        if caminho == "/previa":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            achado = previa_bytes(consulta.get("tipo", [""])[0],
                                  consulta.get("id", [""])[0])
            if achado is None:
                # 404 e não erro: a página trata isto como "ainda não pronta" e
                # volta a perguntar. O pedido JÁ enfileirou a conversão.
                return self._recusar(404, "prévia ainda não gerada")
            corpo, tipo_mime = achado
            return self._responder(corpo, tipo=tipo_mime)

        if caminho == "/paleta.css":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            valores = valores_efetivos(["FLAVOR", "ACCENT", "MODO"])
            flavor = _flavor_do_conf(valores)
            # O primeiro claro que o pack declara é o que o COSMIC veste nesse
            # modo.
            flavor = _flavor_da_pagina(flavor, valores)
            return self._responder(paleta_css(flavor, _acento_da_pagina(flavor, valores)),
                                   tipo="text/css; charset=utf-8")

        # Os estáticos da página. `os.path.basename` mata `../` na origem: nunca
        # se monta caminho com o que veio do pedido.
        nome = os.path.basename(caminho)
        raiz_ext = os.path.splitext(nome)[1]
        if raiz_ext in TIPOS and nome:
            arquivo = os.path.join(PAGINA, nome)
            if os.path.isfile(arquivo):
                if not self._token_confere(consulta):
                    return self._recusar(403, "token de sessão ausente ou errado")
                with open(arquivo, "rb") as fh:
                    return self._responder(fh.read(), tipo=TIPOS[raiz_ext])
        return self._recusar(404, "não existe aqui")

    # A página deixa de ser só um editor de texto do `meow.conf` e passa a
    # ALIMENTAR o repositório: o desenho novo, o papel de parede novo, o ícone
    # novo entram pela página e caem na pasta que já é a configuração deste
    # projeto ("soltou o arquivo, entrou").
    #
    # O destino não é escolhido pelo navegador: a página manda um `tipo` e o
    # servidor resolve a pasta (caminho no corpo deixaria um POST forjado escrever
    # em qualquer lugar). O nome é saneado até `[A-Za-z0-9._-]`, e `..` some junto.
    #
    # SVG passa pelo `normalizar_svg.py` antes do acervo. É o mesmo conserto que o
    # `logo.sh` faz: um desenho salvo no Boxy com `transform-origin` entra e não
    # aparece na tela, e o defeito é mudo.
    ACERVOS = {
        "gato": {
            "casa": "pasta_do_mascote",
            "extensoes": (".svg",),
            "normaliza": True,
            "depois": "o vigia põe o mascote novo no acervo em segundos",
        },
        "parede": {
            "pasta": ("packs", "meowsystem", "wallpapers", "ativos"),
            "extensoes": (".jpg", ".jpeg", ".png", ".webp"),
            "normaliza": False,
            "depois": "o carrossel passa a sortear a imagem nova",
        },
        "icone": {
            "casa": "pasta_de_enviados",
            "extensoes": (".svg",),
            "normaliza": True,
            "depois": "o desenho aparece na ficha de ícone, na pasta «enviados»",
        },
        # Os três acima são ACERVO: o arquivo fica em `assets/`, versionado, e é
        # dali que o instalador o leva para a máquina.
        #
        # A página continua sem mover nem apagar nada por conta própria, e a
        # capacidade não nasce presa ao navegador.
        "cursor": {
            "comando": ("cursor", "adicionar"),
            "extensoes": (".zip",),
            "depois": "escolha o tema novo em \"Tema do ponteiro\" e salve",
        },
        "fonte": {
            "comando": ("fontes", "adicionar"),
            "extensoes": (".zip", ".ttf", ".otf"),
            "depois": "a fonte já está registrada; escolha-a onde quiser usá-la",
        },
        "tema-icones": {
            "comando": ("icones", "adicionar"),
            "extensoes": (".zip",),
            "depois": "escolha o tema novo em «Tema de onde herdar» e reconstrua",
        },
    }

    def _acervo_por_comando(self, conf, nome, corpo):
        """Instala na MÁQUINA um pacote de terceiro, pelo comando da CLI.

        O arquivo enviado nunca toca o repositório: ele nasce e morre num
        diretório temporário. Se o comando falhar, não sobra nada — nem meio
        tema instalado, nem um `.zip` órfão em `assets/`."""
        import base64 as _b64
        import tempfile

        try:
            dados = _b64.b64decode(str(corpo.get("conteudo", "")), validate=True)
        except Exception:
            return self._json({"erro": "conteúdo não é base64"}, 400)
        if not dados:
            return self._json({"erro": "arquivo vazio"}, 400)
        # O teto do `_api_acervo` foi escolhido para UM desenho; um pacote
        # inteiro é outra ordem de grandeza.
        if len(dados) > 64 << 20:
            return self._json({"erro": "arquivo maior que 64 MB"}, 413)

        with tempfile.TemporaryDirectory(prefix="meow-envio-") as pasta:
            caminho = os.path.join(pasta, nome)
            try:
                with open(caminho, "wb") as fh:
                    fh.write(dados)
            except OSError as e:
                return self._json({"erro": "não consegui gravar: %s" % e}, 500)
            try:
                r = subprocess.run(_meow(*conf["comando"], caminho),
                                   capture_output=True, text=True, timeout=300)
            except Exception as e:
                return self._json({"erro": "não consegui rodar: %s" % e}, 500)

        # A saída do comando vai para uma torrada, que é tela: a casa sai como
        # `~`, pela mesma porta da gaveta — ver `texto_na_tela`.
        bruta = ((r.stdout or "") + (r.stderr or "")).strip()
        bruta = re.sub(r"(?<![\w/.~-])" + re.escape(RAIZ) + r"(?![\w.-])", ".", bruta)
        saida = texto_na_tela(bruta)
        # O CONTRATO DE IDEMPOTÊNCIA CHEGA INTEIRO À TELA: 0 é "já estava
        # assim", e isso não é erro nem é novidade — é a resposta certa para
        # quem enviou duas vezes o mesmo arquivo. Só 2 para cima é falha.
        if r.returncode >= 2:
            return self._json({"erro": saida or "o comando falhou", "rc": r.returncode}, 500)
        return self._json({
            "ok": True, "nome": nome, "rc": r.returncode, "log": saida,
            "depois": (conf["depois"] if r.returncode == 1
                       else "%s já estava instalado" % nome),
        })

    def _api_acervo(self, corpo):
        import base64 as _b64
        import re as _re

        tipo = str(corpo.get("tipo", ""))
        conf = self.ACERVOS.get(tipo)
        if not conf:
            return self._json({"erro": "acervo desconhecido"}, 400)

        nome = os.path.basename(str(corpo.get("nome", "")))
        nome = _re.sub(r"[^A-Za-z0-9._-]", "-", nome).lstrip(".-")[:80]
        if not nome:
            return self._json({"erro": "nome de arquivo vazio"}, 400)
        ext = os.path.splitext(nome)[1].lower()
        if ext not in conf["extensoes"]:
            return self._json(
                {"erro": "só aceito %s aqui" % ", ".join(conf["extensoes"])}, 400)

        if "comando" in conf:
            return self._acervo_por_comando(conf, nome, corpo)
        # A ARMADILHA DO NOME, que o `logo.sh` documenta: o applet do painel
        # achata em uma cor só qualquer arquivo cujo caminho contenha
        # `-symbolic.svg`. Um gato com esse sufixo viraria silhueta.
        if nome.endswith("-symbolic.svg"):
            return self._json({"erro": "nome terminado em -symbolic.svg vira silhueta"}, 400)

        try:
            dados = _b64.b64decode(str(corpo.get("conteudo", "")), validate=True)
        except Exception:
            return self._json({"erro": "conteúdo não é base64"}, 400)
        if not dados:
            return self._json({"erro": "arquivo vazio"}, 400)
        if len(dados) > 12 << 20:
            return self._json({"erro": "arquivo maior que 12 MB"}, 413)
        if ext == ".svg" and b"<svg" not in dados[:4096].lower():
            return self._json({"erro": "isso não parece um SVG"}, 400)

        if "casa" in conf:
            mod = modulo_pack()
            if not mod:
                return self._json({"erro": "não achei o scripts/pack.py"}, 500)
            destino_dir = getattr(mod, conf["casa"])()
        else:
            destino_dir = os.path.join(RAIZ, *conf["pasta"])
        try:
            os.makedirs(destino_dir, exist_ok=True)
        except OSError as e:
            return self._json({"erro": "não consegui criar %s: %s" % (destino_dir, e)}, 500)
        destino = os.path.join(destino_dir, nome)
        substituiu = os.path.exists(destino)

        # Escrita atômica: o `meow-assets.path` vigia esta pasta e acorda com a
        # escrita — ele não pode encontrar meio arquivo.
        tmp = destino + ".meow-parcial"
        try:
            with open(tmp, "wb") as fh:
                fh.write(dados)
            os.replace(tmp, destino)
        except OSError as e:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            return self._json({"erro": "não consegui gravar: %s" % e}, 500)

        normalizado = ""
        if conf["normaliza"]:
            script = os.path.join(RAIZ, "scripts", "normalizar_svg.py")
            if os.path.isfile(script):
                try:
                    r = subprocess.run([sys.executable, script, destino],
                                       capture_output=True, text=True, timeout=30)
                    normalizado = (r.stdout or "").strip()
                except Exception:
                    normalizado = ""

        # Iam — mas em silêncio e só depois: quem separa `ativos-dia/` de
        # `ativos-noite/` é o `wallpaper.sh`, pela luminância, na próxima vez
        # que o carrossel reaplica.
        #
        # A medida aqui é a MESMA do `wallpaper.sh` — `-colorspace Gray` antes
        # do `%[fx:mean]`, que é Rec.709 sobre a imagem inteira.
        grupo = self._grupo_de_luz(destino) if tipo == "parede" else None

        return self._json({
            "ok": True,
            "nome": nome,
            "destino": destino,
            "substituiu": substituiu,
            "normalizado": normalizado,
            "grupo": grupo,
            "depois": conf["depois"],
        })

    def _grupo_de_luz(self, caminho):
        """{"lado": "dia"|"noite", "luz": 0.21, "corte": 0.37} — ou None.

        None quando não há ImageMagick ou a medida falha: a imagem entrou no
        acervo do mesmo jeito, e a separação acontece na próxima passagem do
        carrossel. Dizer "não sei" é melhor que chutar um lado."""
        exe = shutil.which("magick") or shutil.which("convert")
        if not exe:
            return None
        try:
            r = subprocess.run(
                [exe, "-quiet", "-define", "jpeg:size=256x256", caminho + "[0]",
                 "-resize", "128x128", "-colorspace", "Gray",
                 "-format", "%[fx:mean]", "info:"],
                capture_output=True, text=True, timeout=20)
            luz = float((r.stdout or "").strip())
        except Exception:
            return None
        try:
            corte = float((valores_brutos() or {}).get("WALLPAPER_LIMIAR_LUZ") or 0.37)
        except (TypeError, ValueError):
            corte = 0.37
        if not 0 <= corte <= 1:
            corte = 0.37
        return {"lado": "dia" if luz >= corte else "noite",
                "luz": round(luz, 3), "corte": corte}

    # Aqui não temos isso.
    #
    # Trocar o ícone de um aplicativo hoje exige editar
    # `packs/meowsystem/icones/apps-arcticons.map` à mão, saber que o glifo tem
    # de existir em `packs/meowsystem/icones/apps/`, e rodar o
    # construtor.
    DIRS_DESKTOP = (
        ("/usr/share/applications", "sistema"),
        ("/usr/local/share/applications", "local"),
        ("~/.local/share/applications", "pessoal"),
        ("/var/lib/flatpak/exports/share/applications", "flatpak"),
        ("~/.local/share/flatpak/exports/share/applications", "flatpak"),
        ("/var/lib/snapd/desktop/applications", "snap"),
    )

    def _desktops(self):
        """Todo `.desktop` visível da máquina: id, nome, ícone declarado, origem.

        O nome é o que o lançador mostra: o `Name[…]` da cadeia de idioma da
        sessão, e o `Name=` só quando nenhum casa (P57, `idiomas_da_sessao`)."""
        vistos = {}
        idiomas = idiomas_da_sessao()
        for bruto, origem in self.DIRS_DESKTOP:
            pasta = os.path.expanduser(bruto)
            if not os.path.isdir(pasta):
                continue
            try:
                nomes = sorted(os.listdir(pasta))
            except OSError:
                continue
            for arq in nomes:
                if not arq.endswith(".desktop"):
                    continue
                ident = arq[: -len(".desktop")]
                caminho = os.path.join(pasta, arq)
                dados = {"id": ident, "nome": ident, "icone": "", "origem": origem,
                         "arquivo": caminho, "oculto": False, "categorias": "", "mime": ""}
                traduzidos = {}
                try:
                    with open(caminho, "r", encoding="utf-8", errors="replace") as fh:
                        em_entrada = False
                        for linha in fh:
                            linha = linha.strip()
                            if linha.startswith("["):
                                # Só a [Desktop Entry] principal conta: as ações
                                # extras ([Desktop Action …]) têm Name e Icon
                                # próprios e roubariam o nome do aplicativo.
                                em_entrada = linha == "[Desktop Entry]"
                                continue
                            if not em_entrada:
                                continue
                            if linha.startswith("Name=") and dados["nome"] == ident:
                                dados["nome"] = linha[5:].strip()
                            elif linha.startswith("Name["):
                                idioma, igual, valor = linha[5:].partition("]=")
                                if igual and valor.strip():
                                    traduzidos.setdefault(idioma, valor.strip())
                            elif linha.startswith("Icon="):
                                dados["icone"] = linha[5:].strip()
                            elif linha.startswith("Categories="):
                                dados["categorias"] = linha[11:].strip()
                            elif linha.startswith("MimeType="):
                                # Para o `_e_jogo` saber quem é loja.
                                dados["mime"] = linha[9:].strip()
                            elif linha.startswith(("NoDisplay=", "Hidden=")):
                                if linha.split("=", 1)[1].strip().lower() == "true":
                                    dados["oculto"] = True
                except OSError:
                    continue
                dados["nome"] = next((traduzidos[i] for i in idiomas if i in traduzidos),
                                     dados["nome"])
                # Quem vem depois vence: o `.desktop` da usuária sobrepõe o do
                # sistema, que é a mesma precedência que o lançador usa.
                vistos[ident] = dados
        return sorted(vistos.values(), key=lambda d: d["nome"].lower())

    def _mapa_convertidos(self):
        """As linhas ativas de `apps-convertidos.map`, por id de aplicativo.

        É UM LEITOR SEPARADO, E ISSO É DE PROPÓSITO — 08/09/2026
          A tentação era despejar estas linhas dentro do `_mapa_arcticons` e
          acabar com o assunto. Seria um defeito de três pontas: o painel de
          escolha preseleciona `mapa.glifo` na tira de glifos, e aqui o "glifo"
          é o NOME DO APLICATIVO — um nome que não existe no acervo Arcticons,
          então "Usar este ícone" sairia 404; o botão "Tirar do mapa" apareceria
          apontando para o mapa errado; e a asserção de repetição do
          `_api_app_icone` passaria a contar nomes de outro acervo.

          Dois acervos, dois leitores — a mesma disciplina que o
          `icones_apps_arcticons.sh` mantém do lado dos scripts, e pelo mesmo
          motivo: quem mistura os dois cria o defeito de "dois donos".

        O campo `mao` é o que a oficina precisa saber: uma linha `mao` promete
        um desenho em `retoques/`, e é essa que "Abrir o que já está salvo"
        encontra. As outras 25 têm origem chapada e podem ser revetorizadas."""
        fora = {}
        for caminho, meu in ((os.path.join(ICONES_DO_MOTOR, "apps-convertidos.map"), False),
                             (_mapa_de_convertidos_do_usuario(), True)):
            try:
                with open(caminho, "r", encoding="utf-8") as fh:
                    for linha in fh:
                        corte = linha.strip()
                        if not corte or corte.startswith("#"):
                            continue
                        campos = [c.strip() for c in corte.split(":")]
                        if len(campos) >= 3:
                            fora[campos[0]] = {"cor": campos[2], "mao": campos[1] == "mao", "meu": meu}
            except OSError:
                pass
        return fora

    def _mapa_dracula(self):
        """Os nomes de ícone que o pack autoral Dracula veste, por nome.

        POR QUE ELE PRECISA APARECER AQUI — 16/09/2026
          O `icones_apps_dracula.sh` escreve em `scalable/apps`, que VENCE o
          `48x48/apps` do Arcticons no resolvedor. Sem esta função a página
          mostrava a varinha do Dracula no Krita e escrevia `pink` embaixo, que
          é a cor do Arcticons — o desenho de um acervo com a etiqueta do
          outro. A regra da etiqueta é antiga e continua a mesma: ela diz o que
          está NA TELA, não o que está num mapa.
        """
        fora = set()
        # O mapa mudou de lugar quando o Dracula virou theme pack
        # (docs/PACKS.md).
        #
        # ADOÇÃO POR CONVENÇÃO, a mesma de meow_pack_dir() em lib/comum.sh: sem
        # a chave PACK, um FLAVOR que nomeie um pack existente adota esse pack.
        #
        # Ler `os.environ` aqui devolvia string vazia e o pack sumia da
        # etiqueta, calado.
        _pack = _pack_adotado()
        caminho = ""
        mod = modulo_pack()
        if mod:
            caminho = mod.acervo("icones.apps.mapa",
                                 motor=os.path.join("assets", "icones", "apps-dracula.map"),
                                 ref=_pack or None) or ""
        if not caminho:
            caminho = os.path.join(RAIZ, "assets", "icones", "apps-dracula.map")
        try:
            with open(caminho, "r", encoding="utf-8") as fh:
                for linha in fh:
                    corte = linha.split("#", 1)[0].strip()
                    if not corte or ":" not in corte:
                        continue
                    nome = corte.split(":", 1)[0].strip()
                    if nome:
                        fora.add(nome)
        except OSError:
            pass
        return fora

    # Aberta a do Warehouse, que tem desenho feito à mão no pack, a tela
    # oferecia converter e gerar em traço e dizia "já tem desenho convertido do
    # projeto".
    #
    # A oficina é onde se escolhe entre origens, e um desenho do Dracula é uma
    # origem para o Warehouse mesmo numa máquina vestida de Catppuccin — é a
    # pergunta "existe um desenho feito para este programa?".
    def _desenhos_de_pack(self):
        """nome-de-ícone -> [{pack, nome_pack, arquivo, ativo}] de todo pack no disco."""
        mod = modulo_pack()
        if not mod:
            return {}
        adotado = _pack_adotado()
        indice, vistos = {}, set()
        for base in mod.raizes():
            try:
                ids = sorted(os.listdir(base))
            except OSError:
                continue
            for pid in ids:
                dir_pack = os.path.join(base, pid)
                # A PRIMEIRA RAIZ VENCE, como no `achar`: um pack de mesmo id em
                # `~/.local/share/meowsystem/packs` esconde o do repositório.
                if pid in vistos or not os.path.isfile(os.path.join(dir_pack, "pack.json")):
                    continue
                vistos.add(pid)
                nome_pack = str(mod.campo(dir_pack, "nome", pid) or pid)
                pares = []
                desenhos = mod.campo(dir_pack, "icones.apps.desenhos")
                if isinstance(desenhos, str) and desenhos:
                    try:
                        pasta = mod.resolver_alvo(desenhos, dir_pack)
                    except mod.Recusa:
                        pasta = ""
                    if pasta and os.path.isdir(pasta):
                        pares += [(a[:-len(".svg")], os.path.join(pasta, a))
                                  for a in sorted(os.listdir(pasta)) if a.endswith(".svg")]
                mapa = mod.campo(dir_pack, "icones.apps.mapa")
                linhas = []
                if isinstance(mapa, str) and mapa:
                    try:
                        caminho_mapa = mod.resolver_alvo(mapa, dir_pack)
                        with open(caminho_mapa, "r", encoding="utf-8") as fh:
                            linhas = fh.read().splitlines()
                    except (mod.Recusa, OSError):
                        linhas = []
                for linha in linhas:
                    # O `#` é cortado ANTES do `:`, pela mesma razão do
                    # `icones_apps_dracula.sh`: o comentário de procedência
                    # depois do caminho não pode virar parte dele.
                    corte = linha.split("#", 1)[0].strip()
                    if ":" not in corte:
                        continue
                    nome, alvo = (c.strip() for c in corte.split(":", 1))
                    if not nome or not alvo:
                        continue
                    try:
                        pares.append((nome, mod.resolver_alvo(alvo, os.path.dirname(caminho_mapa))))
                    except mod.Recusa:
                        continue
                for nome, caminho in pares:
                    if not caminho.endswith(".svg") or not os.path.isfile(caminho):
                        continue
                    lista = indice.setdefault(nome, [])
                    if not any(c["arquivo"] == caminho for c in lista):
                        lista.append({"pack": pid, "nome_pack": nome_pack,
                                      "arquivo": caminho, "ativo": pid == adotado})
        return indice

    def _cartoes_do_pack(self, d, indice, atual, com_svg=False):
        """Os desenhos de pack deste aplicativo, e qual deles está NA TELA.

        "EM VIGOR" É MEDIDO, NÃO DEDUZIDO: o arquivo que o resolvedor acha hoje
        é comparado com o do pack. Deduzir de "o pack está no ar e a chave está
        ligada" responderia sobre o que DEVERIA estar lá, e a queixa de 21/09
        era justamente a tela não dizer o que ESTÁ. A comparação ignora a
        quebra de linha do fim porque o `meow_escrever` a normaliza ao
        instalar — é a mesma régua do `_dracula_remover`.
        """
        cartoes, vistos = [], set()
        for nome in (d.get("icone"), d.get("id")):
            for c in indice.get(nome or "", []):
                if c["arquivo"] not in vistos:
                    vistos.add(c["arquivo"])
                    cartoes.append(dict(c))
        if not cartoes:
            return []
        na_tela = None
        if atual and atual.endswith(".svg"):
            try:
                with open(atual, "r", encoding="utf-8", errors="replace") as fh:
                    na_tela = fh.read(400000).rstrip()
            except OSError:
                na_tela = None
        for c in cartoes:
            try:
                with open(c["arquivo"], "r", encoding="utf-8", errors="replace") as fh:
                    texto = fh.read(400000)
            except OSError:
                texto = ""
            c["em_vigor"] = bool(na_tela) and texto.rstrip() == na_tela
            if com_svg:
                c["svg"] = texto
        # O que está na tela primeiro, depois o do pack no ar: é a ordem em que a
        # oficina os mostra, e o primeiro é o que ela marca ao abrir.
        cartoes.sort(key=lambda c: (not c["em_vigor"], not c["ativo"], c["nome_pack"].lower()))
        return cartoes

    def _quem_veste(self, atual, nosso, cartoes, traco, mapa):
        """Quem está NA TELA deste aplicativo: {"tipo", "frase"}.

        A frase é o complemento de "<aplicativo> veste …", e é a mesma na trava
        da grade e no aviso da oficina — duas telas que dissessem coisas
        diferentes sobre o mesmo ícone seriam a página discordando de si mesma.
        `48x48/apps` é o diretório do traço (dono único: o
        `icones_apps_arcticons.sh`), e por isso é ele que separa a conversão e o
        glifo do Arcticons do resto do que é nosso.
        """
        for c in cartoes:
            if c.get("em_vigor"):
                return {"tipo": "pack", "frase": "o desenho do pack «%s»" % c["nome_pack"]}
        if not atual:
            return {"tipo": "nenhum", "frase": "nenhum ícone"}
        if nosso:
            if os.path.basename(os.path.dirname(os.path.dirname(atual))) == "48x48":
                if traco:
                    return {"tipo": "conversao", "frase": "a conversão em traço do projeto"}
                if mapa:
                    return {"tipo": "arcticons", "frase": "o glifo do Arcticons, em traço"}
            return {"tipo": "projeto", "frase": "um desenho do projeto"}
        return {"tipo": "fabrica", "frase": "o ícone de fábrica"}

    def _mapa_arcticons(self):
        """As linhas ativas de `apps-arcticons.map`, por id de aplicativo.

        A COR PASSA PELO `apps-marca.map` — 07/09/2026
          Pergunta dela: *"thunderbird tá certo?"*. Estava e não estava: o
          arquivo no disco dela é `#89B4FA`, que é o `blue` do mocha e é o que
          a marca do Thunderbird pede; a etiqueta na página dizia `sky`.

          A causa é precedência. O `icones_apps_arcticons.sh` lê as cores de
          categoria e, com `ICONES_COR_MARCA=sim`, deixa o `apps-marca.map`
          SOBRESCREVÊ-LAS — só para quem já tem arte, que é a regra do
          `_ler_mapa_marca`. Esta função lia só o primeiro mapa, então mostrava
          a cor que perdeu a disputa. Medido: erra em 2 dos 2 aplicativos que
          estão nos dois mapas — o Firefox dizia `blue` e é `peach`.

          A mesma regra, escrita do mesmo jeito, e só ela: repinta o que já
          está aqui, nunca acrescenta um nome que este mapa não conhece."""
        fora = {}
        # O `meu` diz que a linha é escolha do painel, e é o que acende o
        # «Desfazer a escolha no traço».
        for caminho, meu in ((os.path.join(ICONES_DO_MOTOR, "apps-arcticons.map"), False),
                             (_mapa_de_traco_do_usuario(), True)):
            try:
                with open(caminho, "r", encoding="utf-8") as fh:
                    for linha in fh:
                        corte = linha.strip()
                        if not corte or corte.startswith("#"):
                            continue
                        campos = [c.strip() for c in corte.split(":")]
                        if len(campos) >= 3:
                            # O caminho de antes das três pastas vale pelo de
                            # hoje.
                            mod = modulo_pack() if "/" in campos[1] else None
                            if mod and hasattr(mod, "caminho_de_hoje"):
                                campos[1] = mod.caminho_de_hoje(campos[1])
                            fora[campos[0]] = {"glifo": campos[1], "cor": campos[2],
                                               "alias": len(campos) > 3 and campos[3] == "alias",
                                               "meu": meu}
            except OSError:
                pass

        if _valor_vivo("ICONES_COR_MARCA") == "sim":
            marca = os.path.join(ICONES_DO_MOTOR, "apps-marca.map")
            try:
                with open(marca, "r", encoding="utf-8") as fh:
                    for linha in fh:
                        corte = linha.strip()
                        if not corte or corte.startswith("#"):
                            continue
                        campos = [c.strip() for c in corte.split(":")]
                        if len(campos) >= 2 and campos[0] in fora and campos[1]:
                            fora[campos[0]]["cor"] = campos[1]
                            fora[campos[0]]["pela_marca"] = True
            except OSError:
                pass
        return fora

    # Um quadrado vazio numa grade de 65 diz "está quebrado", e não "este ainda
    # não é nosso".
    TEMAS_DE_ICONE = ("", "hicolor", "Papirus-Dark", "Papirus", "Adwaita")
    TAMANHOS = ("scalable", "256x256", "128x128", "64x64", "48x48", "32x32", "24x24", "22x22")

    def _icone_na_tela(self, d, base_tema):
        """(caminho do ícone que aparece hoje, se é do nosso tema)."""
        nome = d["icone"] or d["id"]
        # 1. caminho absoluto no próprio `.desktop` — é o que a Steam faz.
        #    E o caminho vai para a lista do que a `/previa` serve (ver
        #    `_ICONES_DECLARADOS`): mandar a página mostrar um arquivo que a
        #    cerca recusa é desenhar um ícone quebrado.
        if nome.startswith("/") and os.path.isfile(nome):
            if os.path.splitext(nome)[1].lower() in (".svg", ".png", ".jpg", ".jpeg"):
                _ICONES_DECLARADOS.add(os.path.normpath(nome))
                return nome, False
        bases = [(base_tema, True)]
        for raiz_icones in (os.path.expanduser("~/.local/share/icons"),
                            "/usr/share/icons", "/var/lib/flatpak/exports/share/icons",
                            os.path.expanduser("~/.local/share/flatpak/exports/share/icons")):
            for tema in self.TEMAS_DE_ICONE:
                if not tema:
                    continue
                bases.append((os.path.join(raiz_icones, tema), False))
        for base, e_nosso in bases:
            for tam in self.TAMANHOS:
                for ext in (".svg", ".png"):
                    cand = os.path.join(base, tam, "apps", nome + ext)
                    if os.path.isfile(cand):
                        return cand, e_nosso
        for pix in ("/usr/share/pixmaps", os.path.expanduser("~/.local/share/pixmaps")):
            for ext in (".svg", ".png", ".xpm"):
                cand = os.path.join(pix, nome + ext)
                if os.path.isfile(cand) and ext != ".xpm":
                    return cand, False
        return "", False

    def _api_apps(self, consulta):
        return self._json(self._dados_apps(consulta))

    # A LISTA E A RESPOSTA SÃO COISAS DIFERENTES, desde que a página inteira
    # pode ser exportada num arquivo só.
    #
    # Eram duas perguntas diferentes na mesma página, e a de jogo era a que não
    # tinha resposta ali.
    #
    # O CRITÉRIO É O DO PRÓPRIO ARQUIVO, e não uma lista nossa.
    _RE_STEAM = re.compile(r"^(meow-steam-|steam_app_)\d+$")

    # dizia «Nenhum jogo instalado na Steam» e, logo abaixo, «2 jogos têm
    # atalho», com a própria Steam na grade como um dos dois.
    def _e_jogo(self, d):
        if self._RE_STEAM.match(d.get("id", "")):
            return True
        cats = [c.strip() for c in (d.get("categorias") or "").lower().split(";") if c.strip()]
        if "game" not in cats:
            return False
        loja = any(m.strip().startswith("x-scheme-handler/") for m in (d.get("mime") or "").split(";"))
        return not loja and "emulator" not in cats

    def _dados_apps(self, consulta):
        busca = (consulta.get("busca", [""])[0] or "").strip().lower()
        mapa = self._mapa_arcticons()
        traco = self._mapa_convertidos()
        # O terceiro acervo. Ele não traz cor — cada desenho já tem as suas —,
        # então é um conjunto de nomes, e não um dicionário.
        pack_dracula = self._mapa_dracula()
        tema = os.environ.get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
        base_tema = os.path.expanduser("~/.local/share/icons/%s" % tema)
        # O diretório que o pack ocupa. Perguntar "o arquivo na tela mora AQUI?"
        # é mais honesto que perguntar "a chave está ligada?": a chave pode ter
        # acabado de mudar e o instalador ainda não ter rodado.
        dir_pack = os.path.join(base_tema, "scalable", "apps")
        fora = []
        jogos = 0
        travas = self._travas_do_arcticons()
        # Os desenhos de TODO pack, por nome de ícone — é o que deixa a trava
        # dizer quem veste o aplicativo e que o pack é uma das alternativas.
        indice_pack = self._desenhos_de_pack()
        # Os nomes que outro dono do `scalable/apps` decide, lidos uma vez
        # para a grade inteira — ver `_donos_do_scalable`.
        donos_scalable = self._donos_do_scalable()
        # As escolhas de desenho do painel, por nome de ícone: o selo
        # «escolhido por você» da grade.
        mod = modulo_pack()
        escolhidos = ({n for _num, n, _a in mod.escolhas_do_painel()}
                      if mod and hasattr(mod, "escolhas_do_painel") else set())
        for d in self._desktops():
            if d["oculto"]:
                continue
            if self._e_jogo(d):
                # Ele não some do painel: some DAQUI, e reaparece inteiro na aba
                # "Lançadores e jogos".
                jogos += 1
                continue
            if busca and busca not in d["nome"].lower() and busca not in d["id"].lower():
                continue
            # O ícone que está NA TELA: o arquivo do tema instalado, se houver.
            # "está instalado?" e "está na tela dela?" são perguntas diferentes,
            # e esta página tem de responder a segunda.
            atual, nosso = self._icone_na_tela(d, base_tema)
            do_pack = self._cartoes_do_pack(d, indice_pack, atual)
            traco_app = traco.get(d["id"]) or traco.get(d["icone"])
            vigor = self._quem_veste(atual, nosso, do_pack, traco_app,
                                     mapa.get(d["id"]) or mapa.get(d["icone"]))
            fora.append({
                "id": d["id"], "nome": d["nome"], "icone": d["icone"],
                "origem": d["origem"], "nosso": nosso,
                "url": ("/previa?tipo=arquivo&id=" + quote(atual, safe="")) if atual else "",
                # `scalable/apps` ganha do `48x48/apps` no resolvedor; dizer a
                # cor do Arcticons debaixo de um desenho do Dracula seria a
                # página descrevendo um arquivo que ninguém está vendo.
                "dracula": bool(
                    atual and os.path.dirname(atual) == dir_pack
                    and (d["icone"] or d["id"]) in pack_dracula),
                "mapa": mapa.get(d["id"]) or mapa.get(d["icone"]) or None,
                "escolhido": bool(
                    atual and os.path.dirname(atual) == dir_pack
                    and ((d["icone"] or "") in escolhidos or d["id"] in escolhidos)),
                # O SEGUNDO ACERVO DE TRAÇO, num campo PRÓPRIO.
                "traco": traco.get(d["id"]) or traco.get(d["icone"]) or None,
                # A frase de por que um glifo do Arcticons não valeria aqui, ou
                # None — ver `_travas_do_arcticons`.
                "trava": self._motivo_da_trava(
                    travas, [d["id"], d["icone"]], d["nome"], vigor,
                    ["o desenho do pack «%s»" % c["nome_pack"]
                     for c in do_pack if not c["em_vigor"]]),
                # A frase de por que um desenho do PACK não valeria aqui, ou
                # None: outro dono do `scalable/apps`, ou um `Icon=` por
                # caminho.
                "trava_pack": self._trava_do_pack(d, d["nome"], donos_scalable, travas),
            })
        return {"apps": fora, "total": len(fora), "jogos": jogos}

    # Ela, depois de descobrir que o cartão do Mad King continuava no lançador
    # com o jogo sem licença: "veja se está integrado ao app meowsystem." Não
    # estava.
    #
    # A página NÃO apaga nada.

    def _steam_bibliotecas(self):
        """As pastas `steamapps` declaradas no `libraryfolders.vdf`, sem repetir.

        O `readlink -f` não é zelo: `~/.steam/steam` é symlink para
        `~/.steam/debian-installation`, que é EXATAMENTE o que o vdf grava. Sem
        canonicalizar, cada jogo apareceria DUAS vezes na grade — é a mesma
        armadilha que o `jogos_steam.sh` documenta no `bibliotecas()`.
        """
        raiz = os.path.expanduser("~/.steam/steam")
        brutos = [raiz]
        vdf = os.path.join(raiz, "steamapps", "libraryfolders.vdf")
        try:
            with open(vdf, "r", encoding="utf-8", errors="replace") as fh:
                for linha in fh:
                    achado = re.match(r'\s*"path"\s+"(.+)"\s*$', linha)
                    if achado:
                        brutos.append(achado.group(1))
        except OSError:
            pass
        vistas, fora = set(), []
        for b in brutos:
            real = os.path.realpath(os.path.expanduser(b))
            if real in vistas:
                continue
            vistas.add(real)
            if os.path.isdir(os.path.join(real, "steamapps")):
                fora.append(real)
        return fora

    def _capa_do_jogo(self, appid, vertical=False):
        """A arte vertical do `librarycache`, por BUSCA e não por caminho fixo.

        A Steam renomeou `library_600x900.jpg` para `library_capsule.jpg` e passou
        a enterrar cada arte numa subpasta com o hash do conteúdo. Procurar pelo
        NOME cobre os dois layouts. A ordem da lista é a ordem de preferência: a
        capa vertical primeiro, porque é a que tem a cara do jogo.
        """
        base = os.path.expanduser("~/.steam/steam/appcache/librarycache/%s" % appid)
        if not os.path.isdir(base):
            return ""
        procurados = ("library_capsule.jpg", "library_600x900.jpg")
        if not vertical:
            procurados += ("library_header.jpg", "header.jpg", "logo.png")
        achados = {}
        for dirpath, _, nomes in os.walk(base):
            for nome in nomes:
                if nome in procurados:
                    caminho = os.path.join(dirpath, nome)
                    try:
                        tam = os.path.getsize(caminho)
                    except OSError:
                        continue
                    # Sobra uma versão antiga ao lado da nova: o maior vence.
                    if tam > achados.get(nome, (0, ""))[0]:
                        achados[nome] = (tam, caminho)
        for nome in procurados:
            if nome in achados:
                return achados[nome][1]
        return ""

    def _mapa_jogos_fora(self):
        """As linhas ativas de `jogos-fora.map`: appid -> {acao, motivo}."""
        fora = {}
        try:
            with open(MAPA_JOGOS, "r", encoding="utf-8") as fh:
                for linha in fh:
                    corte = linha.strip()
                    if not corte or corte.startswith("#"):
                        continue
                    campos = [c.strip() for c in corte.split(":")]
                    if not campos or not campos[0].isdigit():
                        continue
                    if len(campos) > 1 and campos[1] in ("apagar", "esconder"):
                        acao, motivo = campos[1], ":".join(campos[2:]).strip()
                    else:
                        acao, motivo = "esconder", ":".join(campos[1:]).strip()
                    fora[campos[0]] = {"acao": acao, "motivo": motivo}
        except OSError:
            pass
        return fora

    def _jogos_ja_apagados(self):
        """Os appids cujo `apagar` JÁ disparou — o registro que torna a linha gasta.

        Mora no estado, e não no mapa: o mapa é versionado e a linha vale em
        qualquer máquina; "aqui, neste disco, já apaguei" é fato local. É o mesmo
        arquivo que o `jogos_steam.sh` escreve, lido aqui só para a página poder
        dizer, na etiqueta, que aquela linha não vai disparar de novo.
        """
        vistos = {}
        try:
            with open(os.path.join(ESTADO, "jogos-apagados"), "r", encoding="utf-8") as fh:
                for linha in fh:
                    campo = linha.split(None, 2)
                    if campo and campo[0].isdigit():
                        # `<appid> <data> <nome>`. O nome é o que sobra de um jogo
                        # cujo manifesto já foi embora — sem ele o cartão da
                        # página diria só o número.
                        vistos[campo[0]] = {
                            "data": campo[1] if len(campo) > 1 else "",
                            "nome": campo[2].strip() if len(campo) > 2 else "",
                        }
        except OSError:
            pass
        return vistos

    # O nome de um jogo vem do `appmanifest_<appid>.acf`, e é exatamente o que
    # some quando a decisão `apagar` dispara: o manifesto sai junto com a pasta.
    _APPINFO = os.path.expanduser("~/.steam/steam/appcache/appinfo.vdf")
    _NOMES_DA_STEAM = {}

    @classmethod
    def _nome_na_steam(cls, appid):
        try:
            carimbo = os.stat(cls._APPINFO).st_mtime_ns
        except OSError:
            return ""
        chave = (carimbo, str(appid))
        if chave not in cls._NOMES_DA_STEAM:
            try:
                cls._NOMES_DA_STEAM[chave] = _nome_no_appinfo(cls._APPINFO, int(appid))
            except (OSError, ValueError, IndexError, struct.error):
                cls._NOMES_DA_STEAM[chave] = ""
        return cls._NOMES_DA_STEAM[chave]

    def _api_jogos(self, consulta):
        return self._json(self._dados_jogos(consulta))

    # Mesma separação do `_dados_apps`, e pelo mesmo motivo.
    def _dados_jogos(self, consulta):
        busca = (consulta.get("busca", [""])[0] or "").strip().lower()
        mapa = self._mapa_jogos_fora()
        gastos = self._jogos_ja_apagados()
        apps_dir = os.path.expanduser("~/.local/share/applications")
        fora, vistos = [], set()

        for lib in self._steam_bibliotecas():
            steamapps = os.path.join(lib, "steamapps")
            try:
                nomes = sorted(os.listdir(steamapps))
            except OSError:
                continue
            for arq in nomes:
                achado = re.match(r"^appmanifest_(\d+)\.acf$", arq)
                if not achado:
                    continue
                appid = achado.group(1)
                if appid in vistos:
                    continue
                vistos.add(appid)
                nome, instalado_em = appid, ""
                try:
                    with open(os.path.join(steamapps, arq), "r",
                              encoding="utf-8", errors="replace") as fh:
                        texto = fh.read()
                    m_nome = re.search(r'"name"\s+"(.*)"', texto)
                    m_dir = re.search(r'"installdir"\s+"(.*)"', texto)
                    if m_nome:
                        nome = m_nome.group(1)
                    if m_dir and "/" not in m_dir.group(1):
                        alvo = os.path.join(steamapps, "common", m_dir.group(1))
                        if os.path.isdir(alvo):
                            instalado_em = alvo
                except OSError:
                    pass

                # O `_capa_do_jogo` cai para `header.jpg` e `logo.png` quando
                # não há capa vertical, e é isso que faz a grade ter arte para
                # todo mundo.
                capa = self._capa_do_jogo(appid)
                if not self._capa_do_jogo(appid, vertical=True):
                    continue
                if busca and busca not in nome.lower() and busca != appid:
                    continue

                linha = mapa.get(appid)
                fora.append({
                    "appid": appid,
                    "nome": nome,
                    "url": "/previa?tipo=arquivo&id=" + quote(capa, safe=""),
                    "cartao": os.path.isfile(
                        os.path.join(apps_dir, "meow-steam-%s.desktop" % appid)),
                    "acao": (linha or {}).get("acao", ""),
                    "motivo": (linha or {}).get("motivo", ""),
                    # `gasto` é o que faz a etiqueta dizer a verdade: a linha
                    # está no mapa, mas já disparou e não vai disparar de novo.
                    "gasto": appid in gastos,
                    "apagado_em": (gastos.get(appid) or {}).get("data", ""),
                    "no_disco": bool(instalado_em),
                })
        # AS LINHAS SEM MANIFESTO TAMBÉM APARECEM — senão a decisão dela some da
        # tela justamente depois de dar certo.
        conhecidos = {j["appid"] for j in fora}
        orfas = []
        for appid, linha in mapa.items():
            if appid in conhecidos:
                continue
            if busca and busca not in appid:
                continue
            registro = gastos.get(appid) or {}
            orfas.append({
                "appid": appid,
                # O registro primeiro (é o nome do manifesto, guardado antes de
                # apagá-lo); depois o cache da Steam; o número só quando ninguém
                # mais sabe.
                "nome": (registro.get("nome") or self._nome_na_steam(appid)
                         or "appid %s" % appid),
                "url": "", "cartao": False,
                "acao": linha["acao"], "motivo": linha["motivo"],
                "gasto": appid in gastos, "apagado_em": registro.get("data", ""),
                "no_disco": False, "sem_manifesto": True,
            })
        fora.sort(key=lambda j: j["nome"].lower())
        orfas.sort(key=lambda j: j["appid"])
        fora.extend(orfas)
        heroic = [] if busca else jogos_do_heroic()

        # Sumir de um lado sem aparecer no outro seria perder a capacidade, não
        # movê-la.
        tema = os.environ.get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
        base_tema = os.path.expanduser("~/.local/share/icons/%s" % tema)
        arcticons = self._mapa_arcticons()
        # O acervo de traço vale aqui pelo mesmo motivo que vale na aba de
        # ícones: os seis lançadores e emuladores moram nele, e sem esta linha a
        # grade os mostraria como "nosso", sem cor, e a oficina abriria na
        # primeira cor da paleta em vez de `mauve`.
        convertidos = self._mapa_convertidos()
        # A grade de Aplicativos já a mandava (`_dados_apps`); esta não, e a
        # página oferecia o «Usar este ícone» que o `_api_app_icone` recusa com
        # 409 para o mesmo aplicativo.
        travas = self._travas_do_arcticons()
        # Um jogo com o `Icon=` por caminho recebia o Dracula na ficha, e o
        # «Usar este ícone» ouvia 409 (medido pela revisão numa casa de
        # brinquedo).
        donos_scalable = self._donos_do_scalable()
        icones = []
        for d in self._desktops():
            if d["oculto"] or not self._e_jogo(d):
                continue
            if busca and busca not in d["nome"].lower() and busca not in d["id"].lower():
                continue
            atual, nosso = self._icone_na_tela(d, base_tema)
            icones.append({
                "id": d["id"], "nome": d["nome"], "icone": d["icone"],
                "origem": d["origem"], "nosso": nosso,
                "url": ("/previa?tipo=arquivo&id=" + quote(atual, safe="")) if atual else "",
                "mapa": arcticons.get(d["id"]) or arcticons.get(d["icone"]) or None,
                "traco": convertidos.get(d["id"]) or convertidos.get(d["icone"]) or None,
                "trava": self._motivo_da_trava(travas, [d["id"], d["icone"]], d["nome"]),
                "trava_pack": self._trava_do_pack(d, d["nome"], donos_scalable, travas),
            })
        return {"jogos": fora, "total": len(fora), "mapa": MAPA_JOGOS,
                "heroic": heroic, "apps": icones, "total_apps": len(icones)}

    def _api_jogo_fora(self, corpo):
        """Grava (ou tira) a linha de um jogo no `jogos-fora.map`.

        NÃO APAGA NADA. Quem apaga é o `scripts/jogos_steam.sh`, na passagem
        seguinte, com as guardas dele (Steam fechada, biblioteca montada, e o
        caminho vindo do `installdir` do manifesto, nunca deste mapa).

        DUAS PERGUNTAS ANTES DA GRAVAÇÃO — 24/09/2026, sprint P54 (decisão dos
        jogos). O mesmo pedido, com a mesma linha montada do mesmo jeito, e o
        mapa do disco intocado nas duas:
          · `previa: true` devolve o que a passagem faria com a decisão dentro
            (`_previa_dos_jogos`): quais atalhos entram, quais saem, e que
            pasta seria apagada. É o que a caixa de confirmar mostra;
          · `seco: true` roda a passagem inteira em ensaio sobre a mesma cópia
            e devolve o trabalho, para a gaveta — o «Ver sem mudar».
        Montar a linha num lugar e a cópia noutro faria a caixa prometer um
        mapa e o botão gravar outro.
        """
        appid = str(corpo.get("appid", "")).strip()
        acao = str(corpo.get("acao", "")).strip()
        motivo = " ".join(str(corpo.get("motivo", "")).split())
        remover = bool(corpo.get("remover"))
        if not appid.isdigit() or len(appid) > 12:
            return self._json({"erro": "appid inválido"}, 400)

        if not remover and acao not in ("esconder", "apagar"):
            return self._json({"erro": "ação tem de ser esconder ou apagar"}, 400)
        # O motivo entra num arquivo cujo separador é `:` e cujo comentário é
        # `#`.
        motivo = motivo.replace(":", " ").replace("#", " ").strip()
        if not motivo:
            motivo = "escolha feita no painel em %s" % datetime.date.today().isoformat()

        try:
            with open(MAPA_JOGOS, "r", encoding="utf-8") as fh:
                linhas = fh.read().split("\n")
        except OSError as e:
            return self._json({"erro": "não achei o mapa: %s" % e}, 500)

        def id_da_linha(l):
            corte = l.strip()
            if not corte or corte.startswith("#"):
                return None
            return corte.split(":")[0].strip()

        # O ARQUIVO INTEIRO SOBREVIVE — só a linha do jogo muda.
        novas = list(linhas)
        indice = next((i for i, l in enumerate(novas) if id_da_linha(l) == appid), None)
        so_pergunta = bool(corpo.get("previa") or corpo.get("seco"))

        if remover:
            if indice is None and not so_pergunta:
                return self._json({"ok": True, "removido": False, "appid": appid})
            if indice is not None:
                del novas[indice]
        else:
            nova = "%s:%s:%s" % (appid, acao, motivo)
            if indice is not None:
                novas[indice] = nova
            else:
                ultima = max((i for i, l in enumerate(novas) if id_da_linha(l)),
                             default=None)
                if ultima is None:
                    novas.append(nova)
                else:
                    novas.insert(ultima + 1, nova)
        if corpo.get("previa"):
            return self._json(_previa_dos_jogos("\n".join(novas)))
        if corpo.get("seco"):
            return self._ensaio_dos_jogos("\n".join(novas))
        try:
            with open(MAPA_JOGOS, "w", encoding="utf-8") as fh:
                fh.write("\n".join(novas))
        except OSError as e:
            return self._json({"erro": "não consegui gravar o mapa: %s" % e}, 500)
        return self._json({"ok": True, "appid": appid, "acao": "" if remover else acao,
                           "removido": remover,
                           "depois": "vale depois de \"Arrumar os jogos no lançador\""})

    def _ensaio_dos_jogos(self, mapa):
        """O «Ver sem mudar» da caixa dos jogos: a passagem, seca, sobre `mapa`.

        A cópia do mapa mora na pasta descartável do ensaio (`_conf_de_ensaio`,
        a mesma do «Salvar e aplicar»), e o `iniciar` a entrega ao script pelo
        `MEOW_JOGOS_FORA`. Quem apaga a pasta é o trabalho, quando termina."""
        pasta, erro = _conf_de_ensaio([])
        if erro:
            return self._json({"erro": erro}, 500)
        try:
            with open(os.path.join(pasta, "jogos-fora.map"), "w", encoding="utf-8") as fh:
                fh.write(mapa)
        except OSError as e:
            shutil.rmtree(pasta, ignore_errors=True)
            return self._json({"erro": "não consegui preparar o ensaio: %s" % e}, 500)
        trabalho, erro = iniciar("jogos_aplicar", "", confirmado=True, seco=True,
                                 pasta_de_ensaio=pasta)
        if erro:
            shutil.rmtree(pasta, ignore_errors=True)
            return self._json(erro if isinstance(erro, dict) else {"erro": erro}, 409)
        return self._json(_trabalho_json(trabalho, "jogos_aplicar", seco=True))

    # A busca da ficha (`_api_glifos`, logo abaixo) varria quatro pastas do
    # motor, e os 396 desenhos do Dracula — 72 em `apps/`, 295 na biblioteca, 22
    # autorais e 7 pastas — ficavam todos de fora.
    #
    # O molde é o do traço: o «Usar este ícone» grava a linha no
    # `apps-arcticons.map`, que é o mapa que o `icones_apps_arcticons.sh` lê, e
    # o resto do arquivo sobrevive.
    def _desenhos_do_pack_no_ar(self):
        """(pack, desenhos, aviso): o que a ficha de ícone oferece do pack no ar.

        `pack` é None quando o pack no ar não tem `apps.map` próprio. `aviso` é
        a frase de quando o mapa existe e a camada está desligada: o script não
        põe o mapa no tema, e a escolha ficaria gravada sem nunca aparecer.
        Cada desenho traz `glifo` (o nome que a busca casa), `desenho` (o
        caminho como a linha do mapa o escreve) e `caminho` (o arquivo).
        """
        mod = modulo_pack()
        ident = _pack_adotado() if mod else ""
        dir_pack = mod.achar(ident) if ident else None
        if not dir_pack:
            return None, [], ""

        def declarado(trilha):
            valor = mod.campo(dir_pack, trilha)
            if not isinstance(valor, str) or not valor:
                return ""
            try:
                return mod.resolver_alvo(valor, dir_pack)
            except mod.Recusa:
                return ""

        mapa = declarado("icones.apps.mapa")
        if not mapa or not os.path.isfile(mapa):
            return None, [], ""
        pack = {"id": ident, "nome": str(mod.campo(dir_pack, "nome", ident) or ident),
                "mapa": mapa}
        vals = valores_efetivos(["ICONES_DRACULA", "FLAVOR"])
        flavor = vals.get("FLAVOR") or str(mod.campo(dir_pack, "paleta.flavor_padrao", "") or "")
        base = os.path.dirname(mapa)
        desenhos = []
        # A ORDEM É A DA PERGUNTA: o que foi desenhado para um programa, depois a
        # coleção de onde se escolhe, depois os autorais do flavor em vigor.
        for pasta, fim in ((declarado("icones.apps.desenhos"), ".svg"),
                           (os.path.join(dir_pack, mod.PASTA_BIBLIOTECA), ".svg"),
                           (declarado("icones.autorais.desenhos"),
                            ("-%s.svg" % flavor) if flavor else "")):
            if not fim or not pasta or not os.path.isdir(pasta):
                continue
            for arq in sorted(os.listdir(pasta)):
                caminho = os.path.join(pasta, arq)
                # O NOME VIRA TEXTO DE MAPA: um `#` cortaria a linha, e uma quebra
                # a partiria em duas. Só entra o que o formato escreve inteiro,
                # e link nenhum — a regra que o `validar` já cobra da biblioteca.
                if (not arq.endswith(fim) or not re.match(r"^[A-Za-z0-9._+-]{1,200}$", arq)
                        or os.path.islink(caminho) or not os.path.isfile(caminho)):
                    continue
                desenho = os.path.relpath(caminho, base)
                if desenho.startswith(".."):
                    continue
                desenhos.append({"glifo": arq[:-len(fim)], "desenho": desenho,
                                 "caminho": caminho})
        aviso = ""
        # O título é o que o cartão tem na tela (o `_com_o_vocabulario_do_pack`
        # o reescreve), e o tests/seletor-do-pack.sh confere que os dois não se
        # separam.
        if (vals.get("ICONES_DRACULA") or "sim") == "nao":
            aviso = ("Os desenhos do pack «%s» aparecem nesta busca com «Ícones do pack "
                     "nos aplicativos» ligado." % pack["nome"])
        return pack, desenhos, aviso

    def _donos_do_scalable(self):
        """Os nomes de ícone que OUTRO script põe ou tira de `scalable/apps`.

        O DESENHO DO PACK NÃO PODE ENTRAR ONDE OUTRO DONO MANDA — 25/09/2026, P60
          O `scalable/apps` tem outros donos além do `icones_apps_dracula.sh`: o
          `completar_icones.sh` (os autorais da tabela `AUTORAL`, os apelidos do
          `APELIDO`, e os oito `com.system76.Cosmic*` do `RETIRADOS`, que ele
          APAGA para o traço do `48x48/apps` valer) e o `logo.sh` (os botões do
          dock, `BOTOES_DOCK`). A ficha oferece o pack para todo programa sem
          trava do traço, e o «Arquivos» é um deles: a linha no mapa do pack
          poria o desenho no tema, e a instalação seguinte o tiraria — e o
          doctor das 5h trocaria um pelo outro todo dia.
          O mapa do pack deixa esses nomes de fora por isso (o bloco "já têm
          arte autoral" do `apps.map` do Dracula). O resgate não está aqui: com
          a camada ligada, o `fontes` do pack.py dá a vez ao pack (P43).

        AS LISTAS SÃO LIDAS DOS SCRIPTS, como o `_travas_do_arcticons` lê a dos
        intocáveis: uma cópia aqui envelheceria primeiro.
        """
        donos = set()
        for script, listas in (("completar_icones.sh", ("AUTORAL", "RETIRADOS", "APELIDO")),
                               ("logo.sh", ("BOTOES_DOCK",))):
            try:
                with open(os.path.join(RAIZ, "scripts", script), "r", encoding="utf-8") as fh:
                    texto = fh.read()
            except OSError:
                continue
            for lista in listas:
                # Numa linha só, ou com o `)` que fecha no começo de uma linha: os
                # comentários de dentro das tabelas têm parênteses.
                achado = (re.search(r"^(?:declare -A )?%s=\(([^\n)]*)\)" % lista, texto, re.M)
                          or re.search(r"^(?:declare -A )?%s=\(\n(.*?)^\)" % lista, texto,
                                       re.M | re.S))
                if not achado:
                    continue
                for linha in achado.group(1).split("\n"):
                    linha = linha.split("#", 1)[0]
                    chaves = re.findall(r"\[([^\]]+)\]=", linha)
                    donos.update(chaves or linha.split())
        return donos

    def _trava_do_pack(self, d, rotulo, donos=None, travas=None):
        """A frase de por que um desenho do pack não valeria neste app, ou None."""
        icone = (d.get("icone") or "").strip()
        # Vale para o convertido, e só para ele.
        intocaveis, prefixos, curados, _convertidos = (
            self._travas_do_arcticons() if travas is None else travas)
        motivo = self._motivo_da_trava((intocaveis, prefixos, curados, ()),
                                       [d.get("id"), icone], rotulo)
        if motivo:
            return motivo
        # Elas vão para o balão do desenho na ficha, cujo teto é 80, e saíam
        # cortadas (com o nome do app dentro, passavam de 130). A ficha já é a
        # do app: o nome saiu da frase.
        if icone.startswith("/"):
            return "O lançador aponta o ícone por caminho de arquivo: o tema não vale aqui"
        donos = self._donos_do_scalable() if donos is None else donos
        if any(n in donos for n in (icone, d.get("id")) if n):
            return "O ícone deste app é de outro passo do MeowSystem; o do pack não duraria"
        return None

    def _escolher_do_pack(self, app, corpo):
        """O «Usar este ícone» com um desenho do pack no ar: a linha no mapa dele."""
        pedido = str(corpo.get("pack", "")).strip()
        desenho = str(corpo.get("desenho", "")).strip()
        pack, desenhos, aviso = self._desenhos_do_pack_no_ar()
        if not pack:
            return self._json({"erro": "o pack no ar não tem mapa de aplicativos: não há "
                                       "onde gravar um desenho dele"}, 409)
        if pack["id"] != pedido:
            return self._json({"erro": "o pack «%s» não está no ar — o que está é o «%s»"
                                       % (pedido, pack["nome"])}, 409)
        if aviso:
            return self._json({"erro": aviso}, 409)
        # O CAMINHO É DO SERVIDOR: o pedido só escolhe entre os que a busca
        # ofereceria, e um `desenho` forjado não vira linha de mapa.
        item = next((x for x in desenhos if x["desenho"] == desenho), None)
        if not item:
            return self._json({"erro": "não achei o desenho '%s' no pack «%s»"
                                       % (desenho, pack["nome"])}, 404)
        d = next((x for x in self._desktops() if x["id"] == app), None) or {"id": app}
        rotulo = d.get("nome") or app
        # A página não oferece o pack a quem tem outro dono; um POST direto ouve
        # o mesmo motivo.
        motivo = self._trava_do_pack(d, rotulo)
        if motivo:
            return self._json({"erro": motivo}, 409)
        # O NOME DA LINHA É O DO `Icon=` (ver `_nome_do_icone`): é ele que o
        # script escreve em `scalable/apps/<nome>.svg`, e é ele que o tema acha.
        nome = self._nome_do_icone(app)
        try:
            # O parser é o do pack.py, o mesmo do `fontes`: a linha que ele lê
            # como a do nome é a que se troca.
            linhas, ativas = self._mapa_do_pack(pack["mapa"])
        except OSError as e:
            return self._json({"erro": "não consegui ler o mapa do pack: %s" % e}, 500)
        numero = next((num for num, n, _alvo in ativas if n == nome), None)
        # A LINHA TROCADA VAI JUNTO: a do pack, ou a que uma escolha anterior do
        # painel já carregava.
        antes = ""
        if numero is not None:
            antes = self._escolha_do_painel(linhas[numero - 1])
            if antes is None:
                antes = linhas[numero - 1]
        # O COMENTÁRIO É A PROCEDÊNCIA, como em toda linha do mapa: quem o abrir
        # sabe que esta não veio do tema de origem.
        linha = "%s : %s   # %s — escolhido no painel%s" % (
            nome, desenho, re.sub(r"[\x00-\x1f#;]+", " ", rotulo).strip(),
            "; antes: " + antes if antes else "")
        # O ARQUIVO INTEIRO SOBREVIVE, como no `apps-arcticons.map`: o mapa do
        # Dracula tem 206 linhas de comentário, no cabeçalho e nos blocos.
        if numero is not None:
            linhas[numero - 1] = linha
        elif ativas:
            linhas.insert(ativas[-1][0], linha)
        else:
            linhas.insert(len(linhas) - 1 if linhas and not linhas[-1] else len(linhas), linha)
        try:
            with open(pack["mapa"], "w", encoding="utf-8") as fh:
                fh.write("\n".join(linhas))
        except OSError as e:
            return self._json({"erro": "não consegui gravar o mapa do pack: %s" % e}, 500)
        return self._json({"ok": True, "app": app, "pack": pack["id"],
                           "nome_pack": pack["nome"], "glifo": item["glifo"],
                           "desenho": desenho,
                           "depois": "vale depois de «%s»" % ACOES["icones_pack"]["rotulo"]})

    # Até aqui a escolha tomava o lugar da linha do pack e a linha sumia: não
    # havia o que devolver, e a escolha de um desenho do pack não tinha
    # desfazer.
    #
    # A linha trocada vai INTEIRA no comentário da escolha, depois de ";
    # antes:":
    #
    #   google-chrome : biblioteca/alien.svg   # Chrome — escolhido no painel; antes: google-chrome : apps/google-chrome.svg   # Google Chrome [alias-heuristico]
    _MARCA_DO_PAINEL = re.compile(r"^[^#]*#.*? — escolhido no painel(?:; antes: (.*))?$")

    def _escolha_do_painel(self, linha):
        """A linha que uma escolha do painel trocou ("" quando não trocou
        nenhuma), ou None quando `linha` não é escolha do painel."""
        achado = self._MARCA_DO_PAINEL.match(linha)
        return None if not achado else (achado.group(1) or "")

    def _mapa_do_pack(self, mapa):
        """(linhas, ativas) do `apps.map` de um pack: o arquivo inteiro, linha a
        linha — é ele que se grava de volta —, e as ativas como o `ler_mapa` do
        pack.py as lê, (número, nome, alvo). O OSError sobe: quem chama decide
        se ele é um 500 ou "não há escolha".

        UMA LEITURA SÓ — revisão da P64. Escolher, perguntar pela escolha e
        desfazê-la liam o mapa cada um do seu jeito, e é assim que três leitores
        do mesmo arquivo passam a achar linhas diferentes."""
        with open(mapa, "r", encoding="utf-8") as fh:
            linhas = fh.read().split("\n")
        return linhas, list(modulo_pack().ler_mapa(mapa))

    def _escolha_no_pack(self, pack, app):
        """{pack, nome_pack, desenho, antes} da escolha do painel para `app` no
        mapa do pack no ar, ou None. `antes` é o desenho que ela trocou, ou None
        quando o pack não tinha linha para o nome."""
        nome = self._nome_do_icone(app)
        try:
            linhas, ativas = self._mapa_do_pack(pack["mapa"])
        except OSError:
            return None
        for num, n, alvo in ativas:
            if n != nome:
                continue
            antes = self._escolha_do_painel(linhas[num - 1])
            if antes is None:
                return None
            return {"pack": pack["id"], "nome_pack": pack["nome"], "desenho": alvo,
                    "antes": antes.split("#", 1)[0].partition(":")[2].strip() or None}
        return None

    def _desfazer_do_pack(self, app, corpo):
        """O «Desfazer a escolha no pack»: a linha que a escolha trocou volta.

        A camada desligada não impede, nem trava nenhuma: tirar uma escolha
        sempre vale, como tirar a linha do traço. O pack do pedido tem de ser o
        do ar, pela razão do `_escolher_do_pack`: uma página de antes de uma
        troca de pack mexeria no mapa de um pack fora do ar."""
        pedido = str(corpo.get("pack", "")).strip()
        pack, _desenhos, _aviso = self._desenhos_do_pack_no_ar()
        if not pack:
            return self._json({"erro": "o pack no ar não tem mapa de aplicativos: não há "
                                       "escolha dele para desfazer"}, 409)
        if pack["id"] != pedido:
            return self._json({"erro": "o pack «%s» não está no ar — o que está é o «%s»"
                                       % (pedido, pack["nome"])}, 409)
        nome = self._nome_do_icone(app)
        try:
            linhas, ativas = self._mapa_do_pack(pack["mapa"])
        except OSError as e:
            return self._json({"erro": "não consegui ler o mapa do pack: %s" % e}, 500)
        numero = next((num for num, n, _alvo in ativas if n == nome), None)
        antes = self._escolha_do_painel(linhas[numero - 1]) if numero is not None else None
        if antes is None:
            return self._json({"ok": True, "removido": False, "app": app,
                               "fica": self._o_que_fica(app)})
        if antes:
            linhas[numero - 1] = antes
        else:
            del linhas[numero - 1]
        try:
            with open(pack["mapa"], "w", encoding="utf-8") as fh:
                fh.write("\n".join(linhas))
        except OSError as e:
            return self._json({"erro": "não consegui gravar o mapa do pack: %s" % e}, 500)
        fica = self._o_que_fica(app)
        return self._json({"ok": True, "removido": True, "app": app, "pack": pack["id"],
                           "nome_pack": pack["nome"], "fica": fica})

    def _o_que_fica(self, app):
        """{"tipo", "frase"}: o ícone que o aplicativo veste quando uma escolha
        sai, lido dos mapas que acabaram de ser gravados — P64.

        É A TORRADA QUE MENTIA: ela dizia «voltou para o ícone de fábrica»
        sempre, e o Chrome está no `apps-arcticons.map` E no `apps.map` do
        Dracula. Tirado o traço, o que fica na tela é o desenho do pack.

        A ORDEM É A DO TEMA. O mapa do pack no ar, com a camada ligada, põe o
        desenho em `scalable/apps`, que vence o `48x48/apps` do traço; no traço,
        o glifo do Arcticons e a conversão não convivem num nome (o
        `_conferir_gemeos` do script para o passo). O mapa do pack sobe a
        herança, como no `icones_apps_dracula.sh` — é o `acervo`, e não o mapa
        próprio que a ficha oferece. As frases são as do `_quem_veste`, com o
        nome do desenho quando há um: a torrada e a trava da grade falam do
        mesmo ícone, e não podem discordar.

        É PREVISÃO, E NÃO MEDIDA: o passo roda logo depois (`icones_traco`,
        `icones_pack`), e a grade relida mostra o que ficou de fato. Os donos
        do `scalable/apps` fora dos mapas desta ficha (o `completar_icones.sh`,
        o resgate) não entram na conta.

        A RESOLUÇÃO DO MAPA É A DO SCRIPT, E NÃO A DO `_mapa_dracula` — revisão
        da P64. A revisão apontou as duas como resoluções da mesma coisa com
        quedas diferentes, e são. Medido numa casa de brinquedo com `PACK=""` e
        `FLAVOR="alucard"` (o claro do Dracula): o `meow_pack_dir` + `acervo`
        do `icones_apps_dracula.sh` e o `_pack_adotado` + `acervo` daqui acham
        `packs/dracula/icones/apps.map`; o `_mapa_dracula`, que passa o FLAVOR
        cru como pack, não acha mapa nenhum (0 nomes). Quem prevê o que o
        script vai fazer pergunta como o script — e quem discorda é o
        `_mapa_dracula`, fora do território desta sprint.
        [P66, 25/09/2026: o `_mapa_dracula` passou a perguntar ao
        `_pack_adotado` também, e os três concordam.]"""
        d = next((x for x in self._desktops() if x["id"] == app), None) or {}
        mod = modulo_pack()
        # A ESCOLHA DO PAINEL VENCE TUDO: é a primeira pergunta.
        minha = self._minha_escolha(app)
        if minha:
            return {"tipo": "escolha", "frase": "o desenho «%s» que você escolheu" % minha["glifo"]}
        ident = _pack_adotado() if mod else ""
        if ident and (valores_efetivos(["ICONES_DRACULA"]).get("ICONES_DRACULA") or "sim") != "nao":
            mapa = mod.acervo("icones.apps.mapa", ref=ident) or ""
            nome = self._nome_do_icone(app)
            for _num, n, alvo in (mod.ler_mapa(mapa) if os.path.isfile(mapa) else ()):
                if n == nome:
                    dono = mod._pack_de(mapa)
                    nome_pack = str(mod.campo(dono, "nome", dono) or dono)
                    return {"tipo": "pack", "frase": "o desenho «%s» do pack «%s»"
                            % (os.path.splitext(os.path.basename(alvo))[0], nome_pack)}
        arcticons = self._mapa_arcticons()
        marca = arcticons.get(app) or arcticons.get(d.get("icone") or "")
        if marca:
            return {"tipo": "arcticons",
                    "frase": "o glifo «%s» do Arcticons, em traço" % marca["glifo"]}
        convertidos = self._mapa_convertidos()
        if convertidos.get(app) or convertidos.get(d.get("icone") or ""):
            return {"tipo": "conversao", "frase": "a conversão em traço do projeto"}
        return {"tipo": "fabrica", "frase": "o ícone de fábrica"}

    def _o_que_veste(self, app):
        """O arquivo que veste o aplicativo agora, como a ficha o escreve, ou None.

        15/10/2026, P82 (item 6). O `_escolha_no_pack` só responde quando a
        linha do mapa é uma escolha do painel: o Waterfox abria a ficha com o
        desenho do pack no ar sem marca nenhuma. A ordem é a do `_o_que_fica`,
        que é a do tema: a escolha de quem usa, a linha do mapa do pack no ar
        (com a camada ligada), e o traço (o glifo do Arcticons, depois a
        conversão). Arquivo que não existe não veste nada."""
        mod = modulo_pack()
        minha = self._minha_escolha(app)
        if minha:
            return minha["arquivo"]
        nome = self._nome_do_icone(app)
        ident = _pack_adotado() if mod else ""
        if ident and (valores_efetivos(["ICONES_DRACULA"]).get("ICONES_DRACULA") or "sim") != "nao":
            mapa = mod.acervo("icones.apps.mapa", ref=ident) or ""
            for _num, n, alvo in (mod.ler_mapa(mapa) if os.path.isfile(mapa) else ()):
                if n != nome:
                    continue
                try:
                    arq = mod.resolver_alvo(alvo, os.path.dirname(mapa))
                except mod.Recusa:
                    arq = ""
                if arq and os.path.isfile(arq):
                    return self._arquivo_na_ficha(arq)
        d = next((x for x in self._desktops() if x["id"] == app), None) or {}
        icones = ICONES_DO_MOTOR
        marca = self._mapa_arcticons().get(app) or self._mapa_arcticons().get(d.get("icone") or "")
        if marca:
            glifo = marca["glifo"]
            arq = (glifo if os.path.isabs(glifo) else os.path.join(RAIZ, glifo)) if "/" in glifo \
                else _glifo_do_motor(glifo)
            if os.path.isfile(arq):
                return self._arquivo_na_ficha(arq)
        conv = self._mapa_convertidos()
        if conv.get(app) or conv.get(d.get("icone") or ""):
            arq = os.path.join(icones, "apps", nome + ".svg")
            if os.path.isfile(arq):
                return self._arquivo_na_ficha(arq)
        return None

    # Independente do app que eu escolher, eu deveria acessar todas as imagens
    # disponíveis, não só as que mapeamos à mão.»
    #
    # (docs/pesquisas/2026-10-09-paridade-de-icones.md, seção 2) · um teto de 60
    # por lado (`limite = 60`), sem página seguinte: a busca vazia enchia os 60
    # do pack só com `apps/`, e os 295 da biblioteca nunca apareciam sem busca.
    @staticmethod
    def _sem_acento(texto):
        """O texto sem acento e em minúsculas — a régua da busca da ficha.

        «alienígena» tem de achar quem digita «alienigena», e o contrário."""
        import unicodedata
        return "".join(c for c in unicodedata.normalize("NFKD", str(texto or ""))
                       if not unicodedata.combining(c)).lower()

    def _acervo_da_ficha(self):
        """(grupos, itens) de tudo o que a ficha de ícone oferece.

        `grupos` é a lista ordenada das pastas, cada uma um dicionário com `id`,
        `acervo` (de quem é: o nome do pack, ou «MeowSystem»), `nome` (a pasta,
        como a tela a chama), `pack`, `no_ar`, `tipo` e `total`. `itens` traz um
        dicionário por arquivo, com o `grupo` (o id) e o `_texto` onde a busca
        procura. Os da pasta do pack no ar trazem `pack` e `desenho`, como na
        P60: é o que o «Levar para o pack» grava no mapa dele.
        """
        grupos, itens = [], []
        mod = modulo_pack()
        if not mod:
            return grupos, itens
        # A LISTA DE PASTAS É A DO `pack.py acervos_de_icone`: todos os packs,
        # cada um na sua pasta, e as do motor — ver o bloco "O ACERVO DA FICHA
        # DE ÍCONE, DECLARADO NUM LUGAR SÓ" de lá.
        pack, desenhos, _aviso = self._desenhos_do_pack_no_ar()
        do_mapa = {os.path.normpath(d["caminho"]): d for d in desenhos}
        textos, rotulos, do_nome = self._textos_da_busca(mod)
        nomes_de_app = self._nomes_de_app()
        # O `org.telegram.desktop` era «Telegram» na pasta do pack, que tem a
        # linha do apps.map, e «Desktop» nas três do motor, onde só sobrava o
        # nome do arquivo sem o domínio (o último pedaço de um id invertido é
        # muitas vezes genérico: `Client`, `Desktop`, `Browser`).
        for g in mod.acervos_de_icone(_pack_adotado()):
            arquivos = g.pop("arquivos")
            g["total"] = len(arquivos)
            grupos.append(g)
            for caminho in arquivos:
                nome = os.path.basename(caminho)
                glifo = os.path.splitext(nome)[0]
                # O RÓTULO É O QUE A PESSOA LÊ. Ver "O RÓTULO DA FICHA", logo
                # abaixo: o catálogo, o mapa, o `.desktop` e, sem nenhum, o
                # próprio nome sem número nem domínio.
                rotulo = (rotulos.get(os.path.normpath(caminho))
                          or nomes_de_app.get(glifo.lower()) or do_nome.get(glifo.lower())
                          or self._rotulo_do_nome(glifo))
                item = {"glifo": glifo, "rotulo": rotulo, "grupo": g["id"], "tipo": g["tipo"],
                        "caminho": caminho,
                        "_texto": self._sem_acento(" ".join(
                            [glifo, rotulo] + textos.get(os.path.normpath(caminho), [])))}
                # Raster não é fonte (o `meow_icones_derivados` do lib/icones.sh
                # recusa: de um PNG não sai vetor, flavor nem tamanho maior), e
                # a decisão 2 é que ele entre no pack agora e vire vetor num
                # lote conferido por RMSE.
                if g["tipo"] == "png":
                    item["trava"] = "Feito à mão em PNG: vale no tema quando ganhar a versão em vetor"
                no_mapa = do_mapa.get(os.path.normpath(caminho)) if pack else None
                if no_mapa:
                    item.update(pack=pack["id"], desenho=no_mapa["desenho"])
                itens.append(item)
        return grupos, itens

    # A busca casava só o NOME DO ARQUIVO, e o nome do arquivo é o nome de ícone
    # em inglês — só ajuda quem já sabe a resposta. É o nome de ícone em inglês,
    # e ele só ajuda quem já sabe a resposta.
    @staticmethod
    def _rotulo_do_nome(glifo):
        """O nome do arquivo sem número na frente nem domínio invertido."""
        # O ícone de um app instalado pelo Chrome se chama
        # `chrome-<id>-<perfil>`, com o id de 32 letras da extensão, e a
        # biblioteca do Dracula traz dois deles sem descrição no catálogo: o
        # rótulo saía «Chrome ieicmdpib…
        app_web = re.match(r"^(chrome|chromium|brave|msedge)-[a-p]{32}-\w+$", glifo, re.I)
        if app_web:
            return "App do " + {"msedge": "Edge"}.get(app_web.group(1).lower(),
                                                      app_web.group(1).capitalize())
        nome = re.sub(r"^\d+[-_.]+", "", glifo) or glifo
        partes = [p for p in nome.split(".") if p]
        if len(partes) >= 3 and " " not in nome:
            nome = partes[-1]
        nome = re.sub(r"(?<=[a-z])(?=[A-Z])", " ", nome)
        nome = re.sub(r"[-_.]+", " ", nome).strip() or glifo
        return nome[:1].upper() + nome[1:]

    @staticmethod
    def _rotulo_do_comentario(comentario):
        """«Waterfox — o Firefox do dracula-icons (circle)» dá «Waterfox»."""
        texto = re.sub(r"\[[^\]]*\]", "", comentario or "")
        return re.split(r"\s[—–-]\s|\s\(", texto, maxsplit=1)[0].strip()

    def _nomes_de_app(self):
        """{nome de ícone ou id, em minúsculas: o nome do app no lançador}."""
        nomes = {}
        for d in self._desktops():
            if not d.get("nome") or d["nome"] == d["id"]:
                continue
            for chave in (d.get("icone") or "", d["id"]):
                if chave and "/" not in chave:
                    nomes.setdefault(chave.lower(), d["nome"])
        return nomes

    def _textos_da_busca(self, mod):
        """({caminho normalizado: [textos]}, {caminho normalizado: rótulo},
        {nome do arquivo sem extensão, em minúsculas: nome do app}): o que a
        busca casa além do nome do arquivo, o rótulo que a ficha mostra, e o
        nome de app que as linhas dos mapas dão a cada nome de arquivo."""
        textos = {}
        rotulos = {}
        do_nome = {}
        nomes_de_app = self._nomes_de_app()

        def junta(caminho, *partes):
            textos.setdefault(os.path.normpath(caminho), []).extend(p for p in partes if p)

        mapas = set()
        for base in mod.raizes():
            try:
                ids = sorted(os.listdir(base))
            except OSError:
                continue
            for pid in ids:
                dir_pack = os.path.join(base, pid)
                if not os.path.isfile(os.path.join(dir_pack, "pack.json")):
                    continue
                mapa = mod.acervo("icones.apps.mapa", ref=dir_pack) or ""
                if mapa and os.path.isfile(mapa):
                    mapas.add(os.path.realpath(mapa))
        # O `catalog.json` ao lado dos desenhos dá o texto da busca (descrição
        # em português e etiquetas).
        vistas = set()
        for g in mod.acervos_de_icone() if hasattr(mod, "acervos_de_icone") else ():
            pasta_cat = os.path.normpath(g.get("pasta") or "")
            if not pasta_cat or pasta_cat in vistas:
                continue
            vistas.add(pasta_cat)
            com_rotulo = ":biblioteca" in g.get("id", "") or g.get("id", "").endswith(":feitos-a-mao")
            try:
                with open(os.path.join(pasta_cat, "catalog.json"), encoding="utf-8") as fh:
                    catalogo = json.load(fh)
            except (OSError, ValueError):
                continue
            for arq, ficha in (catalogo.items() if isinstance(catalogo, dict) else ()):
                if isinstance(ficha, dict):
                    etiquetas = ficha.get("tags") if isinstance(ficha.get("tags"), list) else []
                    descricao = str(ficha.get("descricao") or "").strip()
                    junta(os.path.join(pasta_cat, str(arq)), descricao,
                          *[str(t).replace("_", " ") for t in etiquetas])
                    if com_rotulo and descricao:
                        rotulos[os.path.normpath(os.path.join(pasta_cat, str(arq)))] = (
                            descricao[:1].upper() + descricao[1:])
        # O `apps-convertidos.map` não tem comentário no fim da linha (os
        # leitores dele cortam nos `:`), e o nome vem na linha de cima,
        # `# app: OBS Studio`.
        conv = os.path.join(ICONES_DO_MOTOR, "apps-convertidos.map")
        try:
            with open(conv, encoding="utf-8") as fh:
                linhas_conv = fh.read().split("\n")
        except OSError:
            linhas_conv = []
        for anterior, linha in zip([""] + linhas_conv, linhas_conv):
            nome_app = anterior[len("# app:"):].strip() if anterior.startswith("# app:") else ""
            nome = linha.split(":", 1)[0].strip()
            if nome_app and nome and not linha.startswith("#"):
                caminho = os.path.join(ICONES_DO_MOTOR, "apps", nome + ".svg")
                junta(caminho, nome_app)
                rotulos.setdefault(os.path.normpath(caminho), nome_app)
                do_nome.setdefault(nome.lower(), nome_app)
        for mapa in sorted(mapas):
            try:
                with open(mapa, encoding="utf-8") as fh:
                    linhas = fh.read().split("\n")
            except OSError:
                continue
            for linha in linhas:
                util, _sep, comentario = linha.partition("#")
                nome, sep, alvo = util.partition(":")
                if not sep or not nome.strip() or not alvo.strip():
                    continue
                try:
                    caminho = mod.resolver_alvo(alvo.strip(), os.path.dirname(mapa))
                except mod.Recusa:
                    continue
                junta(caminho, nome.strip(), comentario.strip())
                # O catálogo vence: a linha do mapa diz o app que o desenho
                # veste, e o catálogo diz o que o desenho É (biblioteca).
                rotulo = (self._rotulo_do_comentario(comentario)
                          or nomes_de_app.get(nome.strip().lower(), ""))
                if rotulo:
                    rotulos.setdefault(os.path.normpath(caminho), rotulo)
                    do_nome.setdefault(os.path.splitext(os.path.basename(caminho))[0].lower(), rotulo)
        return textos, rotulos, do_nome

    def _palpites_do_app(self, app):
        """Os textos que fazem um desenho ser «sugerido» para `app`: o id, o
        `Icon=` e o nome dele — inteiro e a 1ª palavra, o palpite que até a P73
        era o filtro de abertura."""
        if not app or not re.match(r"^[A-Za-z0-9._+-]{1,120}$", app):
            return []
        d = next((x for x in self._desktops() if x["id"] == app), None) or {"id": app}
        nome = self._sem_acento(d.get("nome") or "")
        palpites = {self._sem_acento(app), self._sem_acento(d.get("icone") or "")}
        if nome:
            palpites.add(nome)
            primeira = nome.split()[0]
            if len(primeira) >= 3:
                palpites.add(primeira)
        return [p for p in palpites if p and "/" not in p]

    def _api_glifos(self, consulta):
        """O acervo inteiro de desenhos que a ficha de ícone oferece, por pasta.

        Ver o bloco "A FICHA MOSTRA O ACERVO INTEIRO, EM PASTAS", acima. A busca
        filtra; sem busca, vem tudo. O `app` não filtra nada: ele marca os
        `sugerido`, e traz a `escolha` do painel para ele (P64).
        """
        busca = self._sem_acento((consulta.get("busca", [""])[0] or "").strip())
        app = (consulta.get("app", [""])[0] or "").strip()
        grupos, itens = self._acervo_da_ficha()
        palpites = self._palpites_do_app(app)
        achados = {}
        glifos = []
        for it in itens:
            if busca and busca not in it["_texto"]:
                continue
            achados[it["grupo"]] = achados.get(it["grupo"], 0) + 1
            # A MINIATURA DO PACK VEM PELA CERCA DO `/previa`, que não conhece
            # `packs/`: o arquivo entra no `_ICONES_DECLARADOS`, a porta dos
            # arquivos que o próprio servidor mandou a página mostrar.
            _ICONES_DECLARADOS.add(os.path.normpath(it["caminho"]))
            saida = {k: v for k, v in it.items() if not k.startswith("_") and k != "caminho"}
            saida["url"] = "/previa?tipo=arquivo&id=" + quote(it["caminho"], safe="")
            # O ARQUIVO É A IDENTIDADE DA ESCOLHA: é o que o «Usar este ícone»
            # manda de volta, e o que o `icones-escolhidos.map` guarda.
            saida["arquivo"] = self._arquivo_na_ficha(it["caminho"])
            saida["sugerido"] = any(p in it["_texto"] for p in palpites)
            glifos.append(saida)
        for g in grupos:
            g["achados"] = achados.get(g["id"], 0)
            g.pop("pasta", None)
        pack, _desenhos, aviso = self._desenhos_do_pack_no_ar()
        # A FICHA PERGUNTA POR APLICATIVO. O `pack` é o pack que a ficha pode
        # oferecer, e a `escolha` é a do painel para ESTE aplicativo no mapa do
        # pack, que acende o «Desfazer a escolha no pack».
        app_ok = bool(re.match(r"^[A-Za-z0-9._+-]{1,120}$", app))
        extra = {"aviso": aviso,
                 "pack": {"id": pack["id"], "nome": pack["nome"]} if pack and not aviso else None,
                 "escolha": (self._escolha_no_pack(pack, app) if pack and app_ok else None),
                 "minha": self._minha_escolha(app) if app_ok else None,
                 # O que veste o app agora: a ficha o marca.
                 "veste": self._o_que_veste(app) if app_ok else None}
        # `limitado` fica, sempre falso: é o campo que dizia «a lista foi
        # cortada», e nenhuma resposta corta mais.
        return self._json(dict({"grupos": grupos, "glifos": glifos, "limitado": False}, **extra))

    def _arquivo_na_ficha(self, caminho):
        """Como a ficha e as escolhas escrevem um arquivo: a partir da raiz do
        MeowSystem quando mora nela, e absoluto quando mora num pack de fora."""
        caminho = os.path.normpath(caminho)
        if caminho.startswith(RAIZ + os.sep):
            return os.path.relpath(caminho, RAIZ)
        return caminho

    def _item_da_ficha(self, arquivo):
        """O item da ficha cujo arquivo é `arquivo`, ou None. O pedido só escolhe
        entre o que a ficha ofereceria: um caminho forjado não vira escolha."""
        if not arquivo or not isinstance(arquivo, str):
            return None
        alvo = os.path.normpath(arquivo if os.path.isabs(arquivo) else os.path.join(RAIZ, arquivo))
        _grupos, itens = self._acervo_da_ficha()
        return next((it for it in itens if os.path.normpath(it["caminho"]) == alvo), None)

    def _minha_escolha(self, app):
        """{arquivo, glifo, grupo, pack, desenho} da escolha do painel para `app`
        no estado de quem usa, ou None. `pack`/`desenho` só vêm quando o desenho
        é do pack no ar: é o que o «Levar para o pack» grava."""
        mod = modulo_pack()
        if not mod or not hasattr(mod, "escolhas_do_painel"):
            return None
        nome = self._nome_do_icone(app)
        arq = next((a for _n, n, a in mod.escolhas_do_painel() if n == nome), None)
        if not arq:
            return None
        item = self._item_da_ficha(arq) or {}
        return {"arquivo": self._arquivo_na_ficha(arq),
                "glifo": os.path.splitext(os.path.basename(arq))[0],
                "grupo": item.get("grupo"), "pack": item.get("pack"),
                "desenho": item.get("desenho")}

    def _escolher_desenho(self, app, item):
        """O «Usar este ícone» com um desenho que entra como está: a linha no
        `icones-escolhidos.map` de quem usa (P73, I3). Nada no repositório."""
        if item.get("tipo") != "desenho":
            return self._json({"erro": "este desenho não entra como está no tema"}, 409)
        d = next((x for x in self._desktops() if x["id"] == app), None) or {"id": app}
        rotulo = d.get("nome") or app
        # A TRAVA DO PACK VALE PARA TODO DESENHO QUE VAI AO `scalable/apps`: é o
        # mesmo arquivo, de onde quer que o desenho venha.
        motivo = self._trava_do_pack(d, rotulo)
        if motivo:
            return self._json({"erro": motivo}, 409)
        nome = self._nome_do_icone(app)
        arquivo = self._arquivo_na_ficha(item["caminho"])
        linha = "%s : %s   # %s — escolhido no painel" % (
            nome, arquivo, re.sub(r"[\x00-\x1f#;]+", " ", rotulo).strip())
        try:
            _gravar_escolha(_mapa_de_escolhas_do_usuario(), nome, linha, ":")
        except OSError as e:
            return self._json({"erro": "não consegui guardar a escolha: %s" % e}, 500)
        return self._json({"ok": True, "app": app, "glifo": item["glifo"], "arquivo": arquivo,
                           "depois": "vale depois de «%s»" % ACOES["icones_pack"]["rotulo"]})

    def _api_app_icone(self, corpo):
        """Guarda a escolha dela no estado dela — e, por gesto, leva ao pack.

        ATÉ A P73 ESTA ROTA ESCREVIA NO REPOSITÓRIO: a linha do traço no
        `apps-arcticons.map` (com o glifo copiado do `upstream/` para
        `arcticons-apps/`) e a do pack no `apps.map` dele. É a regressão I3 —
        ver "AS ESCOLHAS DE ÍCONE DO PAINEL MORAM COM QUEM USA", no topo. Agora:
          · `arquivo` de desenho     → `icones-escolhidos.map` (quem usa);
          · `glifo` + `cor` (traço)  → `icones-traco.map` (quem usa);
          · `remover` + `escolha`    → tira a linha do primeiro;
          · `remover` sozinho        → tira a linha do segundo;
          · `pack` + `desenho`       → «Levar para o pack», o gesto explícito
                                       que grava no mapa do pack (o código da
                                       P60, `_escolher_do_pack`);
          · `pack` + `remover`       → desfaz o que foi levado (P64).
        """
        app = str(corpo.get("app", "")).strip()
        glifo = str(corpo.get("glifo", "")).strip()
        cor = str(corpo.get("cor", "")).strip()
        remover = bool(corpo.get("remover"))
        if not app or not re.match(r"^[A-Za-z0-9._+-]{1,120}$", app):
            return self._json({"erro": "aplicativo inválido"}, 400)

        if corpo.get("pack") and not remover:
            pack, _desenhos, _aviso = self._desenhos_do_pack_no_ar()
            resposta = self._escolher_do_pack(app, corpo)
            levada = pack and self._escolha_no_pack(pack, app)
            if levada and levada["desenho"] == str(corpo.get("desenho", "")).strip():
                try:
                    _gravar_escolha(_mapa_de_escolhas_do_usuario(), self._nome_do_icone(app),
                                    None, ":")
                except OSError:
                    pass
            return resposta
        # E O DESFAZER DELA.
        if corpo.get("pack"):
            return self._desfazer_do_pack(app, corpo)

        # DESFAZER A MINHA ESCOLHA DE DESENHO.
        if remover and corpo.get("escolha"):
            try:
                havia = _gravar_escolha(_mapa_de_escolhas_do_usuario(),
                                        self._nome_do_icone(app), None, ":")
            except OSError as e:
                return self._json({"erro": "não consegui tirar a escolha: %s" % e}, 500)
            return self._json({"ok": True, "removido": havia, "app": app,
                               "fica": self._o_que_fica(app)})

        item = None
        if corpo.get("arquivo") and not remover:
            item = self._item_da_ficha(str(corpo.get("arquivo")))
            if not item:
                return self._json({"erro": "não achei o desenho '%s' na ficha"
                                           % corpo.get("arquivo")}, 404)
            if item.get("tipo") != "traco":
                return self._escolher_desenho(app, item)

        # A página já não o oferece; o servidor recusa mesmo assim, porque um
        # POST direto gravaria a linha, e num app do acervo convertido ela
        # pararia o passo dos ícones de todo mundo.
        if not remover:
            d = next((x for x in self._desktops() if x["id"] == app), None) or {}
            motivo = self._motivo_da_trava(self._travas_do_arcticons(),
                                           [app, d.get("icone", "")], d.get("nome") or app)
            if motivo:
                return self._json({"erro": motivo}, 409)

        caminho = _mapa_de_traco_do_usuario()
        # O `fica` é o ícone que sobra, para a torrada não dizer «de fábrica»
        # com o desenho do pack na tela.
        if remover:
            try:
                havia = _gravar_escolha(caminho, app, None, ":")
            except OSError as e:
                return self._json({"erro": "não consegui tirar a escolha: %s" % e}, 500)
            return self._json({"ok": True, "removido": havia, "app": app,
                               "fica": self._o_que_fica(app)})

        # Até aqui um glifo fora de `arcticons-apps/` era COPIADO do
        # `upstream/` para lá: o repositório ganhava arquivo a cada escolha.
        trazer = os.path.join(ICONES_DO_MOTOR, "apps")
        if item:
            if os.path.dirname(os.path.normpath(item["caminho"])) == trazer:
                glifo = item["glifo"]
            else:
                glifo = self._arquivo_na_ficha(item["caminho"])
        if not re.match(r"^[a-z0-9._-]{1,60}$", glifo) and not (
                item and re.match(r"^(assets/icones|packs/[a-z0-9][a-z0-9-]*/icones)/"
                                  r"[A-Za-z0-9._+/-]{1,200}\.svg$", glifo)
                and "/../" not in "/" + glifo + "/"):
            return self._json({"erro": "glifo inválido"}, 400)
        cores = set((_paleta_dados().get("ordem") or []))
        if cores and cor not in cores:
            return self._json({"erro": "a cor tem de ser um nome da paleta"}, 400)
        if "/" not in glifo and not os.path.isfile(os.path.join(trazer, glifo + ".svg")):
            return self._json({"erro": "não achei o desenho '%s' no acervo" % glifo}, 404)

        # REPETIR GLIFO OU COR FAZ O GERADOR ESTOURAR, a menos que a linha diga
        # `alias` — está no cabeçalho do mapa.
        mapa = self._mapa_arcticons()
        repetido = any(m["glifo"] == glifo or m["cor"] == cor
                       for chave, m in mapa.items() if chave != app)
        linha = "%s:%s:%s%s" % (app, glifo, cor, ":alias" if repetido else "")
        try:
            _gravar_escolha(caminho, app, linha, ":")
        except OSError as e:
            return self._json({"erro": "não consegui guardar a escolha: %s" % e}, 500)
        # A última escolha é a que vale. O `tirou_escolha` avisa a página de que
        # o passo do pack também precisa rodar, para o desenho sair do tema.
        mod = modulo_pack()
        nome = self._nome_do_icone(app)
        tirou = bool(mod and hasattr(mod, "escolhas_do_painel")
                     and any(n == nome for _num, n, _a in mod.escolhas_do_painel()))
        if tirou:
            try:
                _gravar_escolha(_mapa_de_escolhas_do_usuario(), nome, None, ":")
            except OSError as e:
                return self._json({"erro": "guardei o traço, e não consegui tirar o desenho "
                                           "escolhido antes: %s" % e}, 500)
        return self._json({"ok": True, "app": app, "glifo": os.path.basename(glifo).rsplit(".svg", 1)[0],
                           "cor": cor, "alias": repetido, "trouxe_do_acervo": False,
                           "tirou_escolha": tirou,
                           "depois": "vale depois de \"Pôr os desenhos em traço na tela\""})

    # O `scripts/converter_icone.py` traça a arte chapada, e o
    # `construir_convertidos.sh` a instala.
    #
    # O `/api/app-icone` ao lado cobre o outro caminho — ESCOLHER um desenho
    # pronto do acervo Arcticons.
    #
    #   `vetorizar`  roda o conversor na arte de fábrica e DEVOLVE o SVG. Não
    #                escreve um byte — é uma sugestão, e ela pode recusar.
    #   `ler`        devolve o retoque que já existe, para ela editar de novo em
    #                vez de recomeçar do zero.
    #   `salvar`     grava o texto que ela aprovou em `retoques/<app>.svg` e a
    #                linha `<app>:mao:<cor>` no `apps-convertidos.map`.
    #
    # A recusa do SVG é do servidor: é aqui que a escrita mora, e é aqui que ela
    # tem de valer contra um POST forjado.
    # A recusa é do servidor, porque é aqui que a escrita mora e vale contra um POST
    # forjado: sem script, estilo nem referência externa, e sem `stroke-width` nem cor.
    _SVG_PROIBIDO = re.compile(
        r"<\s*(script|style|image|foreignObject|iframe|use)\b"
        r"|xlink:|href\s*=|\bon[a-z]+\s*=|url\s*\(|@import",
        re.I)

    def _arte_de_fabrica(self, d):
        """A arte CHAPADA do próprio aplicativo — a nossa nunca.

        Vetorizar a partir do nosso traço devolveria o contorno de um contorno:
        cada linha viraria duas, e o resultado seria um fantasma do desenho. Por
        isso o tema do projeto sai da busca, e só dele; o Papirus continua valendo
        como origem, que é de onde vieram 25 dos 33 convertidos que já existem.

        A ordem é a do TAMANHO, não a da pasta: o conversor rasteriza a 256 px
        para traçar, então uma origem de 512 dá contorno limpo e uma de 16 dá
        escada. Vetor vence tudo.
        """
        nome = d.get("icone") or d.get("id")
        if not nome:
            return ""
        if nome.startswith("/") and os.path.isfile(nome):
            return nome
        nosso = os.environ.get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
        raizes = [os.path.expanduser("~/.local/share/flatpak/exports/share/icons"),
                  "/var/lib/flatpak/exports/share/icons",
                  os.path.expanduser("~/.local/share/icons"),
                  "/usr/share/icons"]
        grandes = ("scalable", "512x512", "256x256", "128x128", "64x64", "48x48")
        candidatos = []
        for raiz in raizes:
            for tema in self.TEMAS_DE_ICONE:
                if not tema or tema == nosso:
                    continue
                for i, tam in enumerate(grandes):
                    for ext, peso in ((".svg", 0), (".png", 1)):
                        cand = os.path.join(raiz, tema, tam, "apps", nome + ext)
                        if os.path.isfile(cand):
                            candidatos.append(((0 if tam == "scalable" else 1), peso, i, cand))
        for pix in ("/usr/share/pixmaps", os.path.expanduser("~/.local/share/pixmaps")):
            for ext, peso in ((".svg", 0), (".png", 1)):
                cand = os.path.join(pix, nome + ext)
                if os.path.isfile(cand):
                    candidatos.append((2, peso, 9, cand))
        if not candidatos:
            return ""
        candidatos.sort()
        return candidatos[0][3]

    # O `.desktop` de um jogo se chama `meow-steam-1715980` e o `Icon=` dele diz
    # `steam_icon_1715980` — dois nomes, e só o SEGUNDO é procurado pelo tema.
    #
    # Gravar sob o id produzia `48x48/apps/meow-steam-1715980.svg`: um arquivo
    # correto, no diretório certo, que NINGUÉM procura.
    #
    # Nos aplicativos comuns os dois nomes são iguais e nada muda.
    def _nome_do_icone(self, app):
        d = next((x for x in self._desktops() if x["id"] == app), None)
        nome = ((d or {}).get("icone") or app).strip()
        # `Icon=` com caminho absoluto (a Steam faz isso) não serve como nome de
        # arquivo; nesse caso o id é o melhor que há, e o desenho vale para quem
        # olhar pelo id.
        if nome.startswith("/") or not re.match(r"^[A-Za-z0-9._+-]{1,120}$", nome):
            return app
        return nome

    def _caminho_retoque(self, app):
        """O retoque de quem usa (P82, item 5): é onde a oficina grava."""
        return _oficina_do_usuario("retoques", app + ".svg")

    def _retoque_do_projeto(self, app):
        """O retoque que veio com o clone (o do Gradia, por exemplo)."""
        return os.path.join(ICONES_DO_MOTOR, "apps", app + ".svg")

    def _vizinhos_do_dock(self):
        """Os dois vizinhos da tira: a PRIMEIRA e a ÚLTIMA linha de dados do
        `apps-arcticons.map`.

        São LIDOS do mapa, e não escritos aqui: a tira é uma amostra da dock
        dela, e uma amostra congelada num literal mentiria no dia em que ela
        trocasse o primeiro ícone do acervo. Hoje saem `btop` (maroon) e
        `dev.edfloreshz.CosmicTweaks` (lavender).
        """
        caminho = os.path.join(ICONES_DO_MOTOR, "apps-arcticons.map")
        linhas = []
        try:
            with open(caminho, "r", encoding="utf-8") as fh:
                for linha in fh:
                    corte = linha.strip()
                    if corte and not corte.startswith("#"):
                        linhas.append(corte)
        except OSError:
            return []
        saida = []
        for corte in ([linhas[0], linhas[-1]] if len(linhas) > 1 else linhas):
            campos = [c.strip() for c in corte.split(":")]
            if len(campos) < 3 or not re.match(r"^[A-Za-z0-9._+-]{1,120}$", campos[1]):
                continue
            arte = _glifo_do_motor(campos[1])
            try:
                with open(arte, "r", encoding="utf-8") as fh:
                    saida.append({"nome": campos[0], "cor": campos[2], "svg": fh.read()})
            except OSError:
                continue
        return saida

    def _modo_no_mapa(self, nome):
        """`mao`, `conversao` ou "" — o que o `apps-convertidos.map` diz deste ícone.

        O campo 2 é a origem: a palavra `mao` significa "nasce à mão em
        `retoques/`", e qualquer outra coisa é um caminho de arte chapada, isto
        é, uma linha que o `construir_convertidos.sh` sabe refazer sozinho.
        """
        for caminho in (_mapa_de_convertidos_do_usuario(),
                        os.path.join(ICONES_DO_MOTOR, "apps-convertidos.map")):
            try:
                with open(caminho, "r", encoding="utf-8") as fh:
                    for linha in fh:
                        corte = linha.strip()
                        if not corte or corte.startswith("#"):
                            continue
                        campos = [c.strip() for c in corte.split(":", 2)]
                        if campos[0] != nome or len(campos) < 2:
                            continue
                        return "mao" if campos[1] == "mao" else "conversao"
            except OSError:
                continue
        return ""

    def _salvo_do_app(self, nome):
        """O desenho que já está no repositório para este ícone, e de que espécie.

        O retoque à mão vem PRIMEIRO porque é o que vence: o `_desejado_de` do
        `construir_convertidos.sh` lê `retoques/<nome>.svg` e nem chama o
        conversor. Mostrar o construído havendo retoque seria mostrar a versão
        que perde.
        """
        conv = os.path.join(ICONES_DO_MOTOR, "apps")
        for caminho, palpite in ((self._caminho_retoque(nome), "mao"),
                                 (_oficina_do_usuario("convertidos-apps", nome + ".svg"), "conversao"),
                                 (self._retoque_do_projeto(nome), "mao"),
                                 (os.path.join(conv, nome + ".svg"), "conversao")):
            try:
                with open(caminho, "r", encoding="utf-8") as fh:
                    texto = fh.read()
            except OSError:
                continue
            return {"tem": True, "svg": texto,
                    "modo": self._modo_no_mapa(nome) or palpite}
        return {"tem": False, "svg": "", "modo": ""}

    def _tirar_retoque(self, nome):
        """Apaga `retoques/<nome>.svg` — a ÚNICA remoção desta rota.

        Sem ela, gravar `conversao` gravaria uma linha que não vale nada: o
        `_desejado_de` do construtor lê `retoques/` primeiro, e o retoque VELHO
        continuaria vencendo a conversão nova em toda passagem do
        `construir_convertidos.sh`. O desenho dela ficaria no disco sem nunca
        aparecer na tela — o pior desfecho, porque parece que funcionou.

        A cerca é dupla, que é o mínimo para um `unlink` dentro de um servidor
        HTTP: o `nome` já passou pelo `^[A-Za-z0-9._+-]{1,120}$` do
        `_nome_do_icone` (e ele é resolvido AQUI, a partir do `.desktop`, nunca
        recebido do cliente), e o alvo real tem de cair dentro da pasta
        `retoques/` depois do `realpath`.
        """
        pasta = os.path.realpath(_oficina_do_usuario("retoques"))
        alvo = os.path.realpath(self._caminho_retoque(nome))
        if not alvo.startswith(pasta + os.sep) or not os.path.isfile(alvo):
            return False
        try:
            os.unlink(alvo)
        except OSError:
            return False
        return True

    def _arte_da_capa(self, app):
        """A capa da biblioteca deste jogo da Steam, ou "" se ele não for um."""
        if not self._RE_STEAM.match(app):
            return ""
        return self._capa_do_jogo(re.sub(r"^\D+", "", app))

    def _editor_de_svg(self):
        """Quem esta máquina abre num `.svg`, perguntado UMA vez por sessão.

        Devolve `{"tem": bool, "nome": str}`. O nome é o que o lançador mostra
        do `.desktop` que o `xdg-mime` aponta (o do `_desktops`, P57) — nesta
        máquina, `com.boxy_svg.BoxySVG.desktop` -> "Boxy SVG".

        O NOME NÃO É ENFEITE, É A DIFERENÇA ENTRE UM BOTÃO E UMA APOSTA. «Abrir
        no editor» promete algo que só se descobre clicando; «Abrir no Boxy SVG»
        diz o que vai acontecer antes. E quando não há handler nenhum o botão
        não aparece — um botão que abre nada é pior que a caixa de texto que já
        estava ali.

        NADA AQUI É CRAVADO NUM APLICATIVO. `xdg-mime query default` é a
        pergunta que o sistema responde; se ela trocar o editor amanhã, o botão
        troca junto, sem uma linha nova.
        """
        global _EDITOR_SVG
        with _EDITOR_SVG_TRAVA:
            if _EDITOR_SVG is not None:
                return _EDITOR_SVG
            _EDITOR_SVG = {"tem": False, "nome": ""}
            if not any(shutil.which(l[0]) for l in _LANCADORES_SVG):
                return _EDITOR_SVG
            alvo = ""
            if shutil.which("xdg-mime"):
                try:
                    r = subprocess.run(["xdg-mime", "query", "default", "image/svg+xml"],
                                       capture_output=True, text=True, timeout=10)
                    alvo = (r.stdout or "").strip().split("\n")[0].strip()
                except (OSError, subprocess.SubprocessError):
                    alvo = ""
            if not alvo or not alvo.endswith(".desktop") or "/" in alvo:
                return _EDITOR_SVG
            # Aqui morava um leitor próprio do `Name=` cru, com este porquê:
            # "pegar a primeira [chave] que casasse daria o nome traduzido de um
            # aplicativo e o original de outro na mesma tela".
            ident = alvo[:-len(".desktop")]
            d = next((x for x in self._desktops() if x["id"] == ident), None)
            _EDITOR_SVG = {"tem": True, "nome": (d or {}).get("nome") or ident}
            return _EDITOR_SVG

    def _caminho_rascunho(self, nome):
        """`~/.local/state/meowsystem/oficina/<nome>.svg`, conferido.

        A cerca é a mesma do `_tirar_retoque`, e pelo mesmo motivo: este caminho
        vira argumento de um programa que a máquina escolhe. O `nome` já nasce
        preso ao `^[A-Za-z0-9._+-]{1,120}$` do `_nome_do_icone` — e mesmo assim
        o alvo real, depois do `realpath`, tem de cair dentro da pasta. Devolve
        "" quando não cai.
        """
        pasta = os.path.realpath(_OFICINA_RASCUNHO)
        alvo = os.path.realpath(os.path.join(_OFICINA_RASCUNHO, nome + ".svg"))
        if not alvo.startswith(pasta + os.sep):
            return ""
        return alvo

    def _api_app_desenho(self, corpo):
        """A oficina: a folha de variações, a vetorização por réguas, o gravar."""
        app = str(corpo.get("app", "")).strip()
        acao = str(corpo.get("acao", "vetorizar")).strip()
        if not app or not re.match(r"^[A-Za-z0-9._+-]{1,120}$", app):
            return self._json({"erro": "aplicativo inválido"}, 400)

        nome = self._nome_do_icone(app)

        # ------------------------------------------------------------------ ler
        if acao == "ler":
            alvo = self._caminho_retoque(nome)
            if not os.path.isfile(alvo):
                alvo = self._retoque_do_projeto(nome)
            if not os.path.isfile(alvo):
                return self._json({"ok": True, "svg": "", "tem": False})
            try:
                with open(alvo, "r", encoding="utf-8") as fh:
                    return self._json({"ok": True, "svg": fh.read(), "tem": True})
            except OSError as e:
                return self._json({"erro": "não consegui ler o desenho: %s" % e}, 500)

        # ---------------------------------------------------------- o editor dela
        #
        # `editor` grava o rascunho e chama o handler; `editor-ler` é a pergunta
        # "mudou?" que a página repete enquanto ela desenha lá fora.
        #
        # A pergunta é o `mtime`, não o conteúdo: `os.stat` custa nada e a
        # resposta só carrega o SVG no ciclo em que ele mudou de verdade.
        if acao in ("editor", "editor-ler"):
            alvo = self._caminho_rascunho(nome)
            if not alvo:
                return self._json({"erro": "não consegui montar o caminho do rascunho"}, 400)

            if acao == "editor-ler":
                try:
                    mtime = os.path.getmtime(alvo)
                except OSError:
                    return self._json({"ok": True, "tem": False, "mudou": False})
                try:
                    visto = float(corpo.get("mtime") or 0)
                except (TypeError, ValueError):
                    visto = 0.0
                # Com `>` a volta se perderia justamente no editor mais
                # cuidadoso.
                if abs(mtime - visto) < 0.0005:
                    return self._json({"ok": True, "tem": True, "mudou": False, "mtime": mtime})
                try:
                    with open(alvo, "r", encoding="utf-8", errors="replace") as fh:
                        texto = fh.read(200000)
                except OSError as e:
                    return self._json({"erro": "não consegui reler o rascunho: %s" % e}, 500)
                # O AVISO VEM JUNTO, e não no «Usar».
                return self._json({"ok": True, "tem": True, "mudou": True,
                                   "mtime": mtime, "svg": texto,
                                   "aviso": self._conferir_dialeto(texto)})

            editor = self._editor_de_svg()
            if not editor["tem"]:
                return self._json({"erro": "esta máquina não tem quem abra um SVG"}, 404)
            svg = str(corpo.get("svg", ""))
            erro = self._conferir_dialeto(svg)
            if erro:
                # A RECUSA NA IDA É A MESMA DO «USAR», e é de propósito: o que
                # sai daqui para um programa de fora é o mesmo texto que sairia
                # para o disco.
                return self._json({"erro": erro}, 400)
            try:
                os.makedirs(_OFICINA_RASCUNHO, exist_ok=True)
                with open(alvo, "w", encoding="utf-8") as fh:
                    fh.write(svg if svg.endswith("\n") else svg + "\n")
                mtime = os.path.getmtime(alvo)
            except OSError as e:
                return self._json({"erro": "não consegui gravar o rascunho: %s" % e}, 500)

            # Era o ensaio que parava aqui, depois de gravar o rascunho e antes
            # de abrir o editor, e era isso que deixava a suíte do navegador
            # passar por esta rota sem pôr um Inkscape na tela dela.
            if os.environ.get("MEOW_APP_SEM_JANELA") == "1":
                return self._json({"ok": True, "sem_janela": True, "caminho": alvo,
                                   "mtime": mtime, "editor": editor,
                                   "aviso": "Painel sem janela: o %s não foi aberto"
                                            % (editor["nome"] or "editor")})

            lancador = next((list(l) for l in _LANCADORES_SVG if shutil.which(l[0])), None)
            if not lancador:
                return self._json({"erro": "esta máquina não tem quem abra um SVG"}, 404)
            try:
                # O `argv` é lista, o único pedaço que não é constante é o
                # caminho que ESTE arquivo montou, e o processo é solto: um
                # editor demora minutos, e esperar por ele travaria a rota
                # (e, com ela, a página).
                subprocess.Popen(lancador + [alvo],
                                 stdin=subprocess.DEVNULL,
                                 stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL,
                                 start_new_session=True)
            except (OSError, subprocess.SubprocessError) as e:
                return self._json({"erro": "não consegui abrir o editor: %s" % e}, 500)
            return self._json({"ok": True, "caminho": alvo, "mtime": mtime,
                               "editor": editor})

        # ------------------------------------------------------------ variações
        # Até ontem eram um clique, um desenho, e para ver outro era mexer num
        # número e clicar de novo — quem não sabe o que o número faz não mexe, e
        # a oficina virava um botão só.
        #
        # As conversões vão para um `ThreadPoolExecutor`: em série foram 1,42 s
        # medidos para as seis do ícone, e a mais cara de todas é a capa de um
        # jogo da Steam, 2,38 s sozinha (460x215 de ilustração, 105 traços).
        if acao == "variacoes":
            d = next((x for x in self._desktops() if x["id"] == app), None)
            if not d:
                return self._json({"erro": "não achei o .desktop de %s" % app}, 404)
            origem = self._arte_de_fabrica(d)
            capa = self._arte_da_capa(app)
            tem_cheia = _conversor_tem_cheia()
            tarefas = []
            for pid, rotulo, det, sua, chei, fonte, frac, mini in PRESETS_DESENHO:
                if chei and not tem_cheia:
                    continue
                arte = capa if fonte == "capa" else origem
                if not arte:
                    continue
                argv, texto = _parametros_de(det, sua, chei, frac, mini)
                tarefas.append({"id": pid, "rotulo": rotulo, "detalhe": det,
                                "suavidade": sua, "cheia": chei, "fonte": fonte,
                                "fracas": frac, "minimo": mini,
                                "parametros": texto, "arte": arte, "argv": argv})
            variacoes = []
            if tarefas:
                with ThreadPoolExecutor(max_workers=6) as piscina:
                    futuros = [piscina.submit(_converter_desenho, t["arte"],
                                              t["argv"], t["parametros"])
                               for t in tarefas]
                    for t, futuro in zip(tarefas, futuros):
                        # UMA VARIAÇÃO QUE EXPLODE NÃO LEVA AS OUTRAS: o cartão
                        # sai apagado com a frase curta e a folha continua.
                        try:
                            svg, nota, erro = futuro.result()
                        except Exception as e:              # noqa: BLE001
                            svg, nota, erro = "", "", "o conversor falhou: %s" % e
                        cartao = {k: t[k] for k in ("id", "rotulo", "detalhe",
                                                    "suavidade", "cheia", "fonte",
                                                    "fracas", "minimo",
                                                    "parametros")}
                        if erro:
                            cartao["erro"] = erro
                        else:
                            cartao["svg"] = svg
                            cartao["nota"] = nota
                        variacoes.append(cartao)
            tema = os.environ.get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
            atual, nosso = self._icone_na_tela(
                d, os.path.expanduser("~/.local/share/icons/%s" % tema))
            do_pack = self._cartoes_do_pack(d, self._desenhos_de_pack(), atual, com_svg=True)
            traco = self._mapa_convertidos()
            arcticons = self._mapa_arcticons()
            vigor = self._quem_veste(atual, nosso, do_pack,
                                     traco.get(d["id"]) or traco.get(d["icone"]),
                                     arcticons.get(d["id"]) or arcticons.get(d["icone"]))
            return self._json({
                "ok": True, "nome": nome, "origem": origem,
                "original": ("/previa?tipo=arquivo&id=" + quote(origem, safe="")) if origem else "",
                "capa": ("/previa?tipo=arquivo&id=" + quote(capa, safe="")) if capa else "",
                "salvo": self._salvo_do_app(nome),
                "pack": do_pack,
                "em_vigor": vigor,
                "variacoes": variacoes,
                "vizinhos": self._vizinhos_do_dock(),
                # Quem abre um SVG aqui — para a página saber se desenha o botão
                # e com que nome. Sem handler o campo vem `{"tem": false}` e o
                # botão simplesmente não nasce.
                "editor": self._editor_de_svg(),
            })

        # ------------------------------------------------------------ vetorizar
        if acao == "vetorizar":
            d = next((x for x in self._desktops() if x["id"] == app), None)
            if not d:
                return self._json({"erro": "não achei o .desktop de %s" % app}, 404)
            # Um jogo da Steam tem DUAS artes, e elas dizem coisas diferentes: o
            # `steam_icon_<appid>.png` (o ícone, 256 px, uma marca) e a
            # `library_capsule.jpg` (a capa, ilustração inteira com o título
            # escrito).
            fonte = str(corpo.get("fonte", "icone")).strip()
            if fonte == "capa":
                origem = self._arte_da_capa(app)
                if not self._RE_STEAM.match(app):
                    return self._json({"erro": "só jogo da Steam tem capa"}, 400)
                if not origem:
                    return self._json({
                        "erro": "a Steam não guardou capa deste jogo — "
                                "abra a biblioteca dela uma vez e tente de novo"}, 404)
            elif fonte != "icone":
                return self._json({"erro": "fonte desconhecida: %s" % fonte}, 400)
            else:
                origem = self._arte_de_fabrica(d)
            if not origem:
                return self._json({
                    "erro": "não achei arte de fábrica para %s — este é o caso "
                            "de desenhar do zero na caixa abaixo" % app}, 404)

            # As réguas (`detalhe`/`suavidade`/ `fracas`/`minimo`) são o caminho
            # da tela e a cerca delas é o `_parametros_de`, que prende em 0…10
            # antes de fazer conta.
            if corpo.get("detalhe") not in (None, "") or corpo.get("suavidade") not in (None, ""):
                argv_extra, texto = _parametros_de(corpo.get("detalhe", 6),
                                                   corpo.get("suavidade", 2),
                                                   bool(corpo.get("cheia")),
                                                   corpo.get("fracas", 0),
                                                   corpo.get("minimo", 0))
            else:
                argv_extra, partes = [], []
                for chave, bandeira, menor, maior in (("k", "--k", 3, 16),
                                                      ("funde", "--funde", 0, 120),
                                                      ("tol", "--tol", 0.2, 8.0)):
                    if corpo.get(chave) in (None, ""):
                        continue
                    try:
                        v = float(corpo[chave])
                    except (TypeError, ValueError):
                        return self._json({"erro": "%s tem de ser número" % chave}, 400)
                    if not (menor <= v <= maior):
                        return self._json({"erro": "%s fora da faixa (%s a %s)"
                                                    % (chave, menor, maior)}, 400)
                    argv_extra += [bandeira, ("%g" % v)]
                    partes += [bandeira, ("%g" % v)]
                texto = " ".join(partes)
            svg, nota, erro = _converter_desenho(origem, argv_extra, texto)
            if erro:
                codigo = 422 if "recusou" in erro else 500
                return self._json({"erro": erro}, codigo)
            return self._json({"ok": True, "svg": svg, "origem": origem,
                               "nota": nota, "parametros": texto})

        # --------------------------------------------------------------- salvar
        if acao != "salvar":
            return self._json({"erro": "ação desconhecida: %s" % acao}, 400)

        svg = str(corpo.get("svg", ""))
        cor = str(corpo.get("cor", "")).strip()
        cores = set((_paleta_dados().get("ordem") or []))
        if cores and cor not in cores:
            return self._json({"erro": "a cor tem de ser um nome da paleta"}, 400)
        erro = self._conferir_dialeto(svg)
        if erro:
            return self._json({"erro": erro}, 400)

        # Uma linha `<nome>:<origem>:<cor>:<parâmetros>` é uma PROMESSA: o
        # `construir_convertidos.sh` vai refazer aquele desenho a partir da
        # origem, com aqueles botões, e esperar o mesmo arquivo.
        d = next((x for x in self._desktops() if x["id"] == app), None)
        fonte = str(corpo.get("fonte", "icone")).strip()
        argv_conv = _parametros_relidos(corpo.get("parametros"))
        texto_param = " ".join(argv_conv) if argv_conv else ""
        origem_arte = self._arte_de_fabrica(d) if d else ""
        # Medido ao exercitar a rota: o GIMP daqui não vem do Papirus, vem do
        # flatpak de usuária, em `/home/<usuário>/.local/share/flatpak/...`.
        #
        # O desenho é gravado do mesmo jeito; o que muda é a ESPÉCIE: retoque à
        # mão, que não promete nada a ninguém, em vez de uma linha regenerável
        # que só se regenera nesta casa.
        #
        # Origem dentro da casa não vira linha de mapa: o repositório é público (o caminho
        # levaria o nome de usuário) e o `_ler_mapa` não expande `~`.
        casa = os.path.realpath(os.path.expanduser("~")) + os.sep
        da_casa = bool(origem_arte) and os.path.realpath(origem_arte).startswith(casa)
        modo = "mao"
        if fonte == "icone" and argv_conv and origem_arte and not da_casa:
            # O cache da folha responde na hora quando o desenho veio de um
            # cartão — a chave é a mesma (origem, mtime, parâmetros).
            feito, _nota, erro_conv = _converter_desenho(origem_arte, argv_conv, texto_param)
            if not erro_conv and feito.rstrip() == svg.rstrip():
                modo = "conversao"

        conv = _oficina_do_usuario("convertidos-apps")
        tirou_retoque = False
        try:
            os.makedirs(conv, exist_ok=True)
            os.makedirs(_oficina_do_usuario("retoques"), exist_ok=True)
            if modo == "mao":
                with open(self._caminho_retoque(nome), "w", encoding="utf-8") as fh:
                    fh.write(svg if svg.endswith("\n") else svg + "\n")
            # O construído, no formato do `meow_escrever` — ver o cabeçalho.
            with open(os.path.join(conv, nome + ".svg"), "w", encoding="utf-8") as fh:
                fh.write(svg.rstrip("\n"))
        except OSError as e:
            return self._json({"erro": "não consegui gravar o desenho: %s" % e}, 500)
        if modo == "conversao":
            tirou_retoque = self._tirar_retoque(nome)

        erro = self._gravar_linha_convertidos(
            nome, cor, origem=(origem_arte if modo == "conversao" else "mao"),
            extra=(texto_param if modo == "conversao" else ""))
        if erro:
            return self._json({"erro": erro}, 500)
        saiu = self._tirar_do_mapa_arcticons(nome)
        return self._json({"ok": True, "app": app, "nome": nome, "cor": cor,
                           "modo": modo, "saiu_do_arcticons": saiu,
                           "tirou_retoque": tirou_retoque,
                           "depois": "vale depois de \"Pôr os desenhos em traço na tela\""})

    def _conferir_dialeto(self, svg):
        """A recusa é do servidor. Devolve a frase do erro, ou "" se passar."""
        texto = (svg or "").strip()
        if not texto:
            return "o desenho veio vazio"
        if len(texto) > 60000:
            return "o desenho passa de 60 000 caracteres — isto é um ícone, não um quadro"
        if not texto.startswith("<svg") or not texto.endswith("</svg>"):
            return "o texto tem de começar em <svg e terminar em </svg>"
        if 'viewBox="0 0 48 48"' not in texto:
            return 'falta viewBox="0 0 48 48" — é a caixa de todo o acervo'
        if "stroke-width" in texto:
            return ("tire o stroke-width: a espessura vem do TRACO do "
                    "icones_apps_arcticons.sh, e duplicá-la é XML inválido")
        if re.search(r"#[0-9A-Fa-f]{3,8}\b|rgba?\s*\(|hsla?\s*\(", texto):
            # A frase passa a nomear o controle em vez de apontar para um lado
            # da tela.
            return "tire a cor: ela vem da paleta, pelo campo «Cor»"
        if 'stroke="currentColor"' not in texto:
            return 'falta stroke="currentColor" — é assim que a cor entra'
        if 'fill="none"' not in texto:
            return 'falta fill="none" — o acervo é traço, não chapado'
        achado = self._SVG_PROIBIDO.search(texto)
        if achado:
            return "o desenho traz %s, que não entra num ícone" % achado.group(0)
        return ""

    def _gravar_linha_convertidos(self, app, cor, origem="mao", extra=""):
        """`<app>:<origem>:<cor>[:<parâmetros>]` no mapa — trocando a linha se existir.

        A ORIGEM VIROU PARÂMETRO EM 09/09/2026. Até ontem esta função só sabia
        escrever `mao`, porque o desenho vinha sempre da caixa de texto e não
        havia como saber de onde ele tinha nascido. Agora a oficina reconverte e
        compara (ver o `salvar`): quando o desenho é EXATAMENTE o que a origem
        chapada mais aqueles botões produzem, a linha guarda os quatro campos e
        o `construir_convertidos.sh` passa a saber refazê-lo sozinho — que é a
        diferença entre um ícone que acompanha uma atualização do Papirus e um
        que congela no dia em que foi salvo.
        """
        caminho = _mapa_de_convertidos_do_usuario()
        try:
            with open(caminho, "r", encoding="utf-8") as fh:
                linhas = fh.read().split("\n")
        except FileNotFoundError:
            linhas = ["# os desenhos da oficina do painel — o mesmo formato do apps-convertidos.map", ""]
        except OSError as e:
            return "não consegui ler o mapa dos convertidos: %s" % e
        linha = "%s:%s:%s" % (app, origem or "mao", cor)
        if extra:
            linha += ":" + extra

        def id_da_linha(l):
            corte = l.strip()
            if not corte or corte.startswith("#"):
                return None
            return corte.split(":")[0].strip()

        indice = next((i for i, l in enumerate(linhas) if id_da_linha(l) == app), None)
        if indice is not None:
            # A linha inteira é trocada, e não só a cor: o mesmo aplicativo pode
            # ter sido `mao` ontem e virar `conversao` hoje (ou o contrário, se
            # ela tirar um traço na lupa), e uma troca parcial deixaria os
            # parâmetros velhos ao lado do desenho novo.
            linhas[indice] = linha
        else:
            ultima = max((i for i, l in enumerate(linhas) if id_da_linha(l)), default=None)
            linhas.insert(ultima + 1 if ultima is not None else len(linhas), linha)
        try:
            os.makedirs(os.path.dirname(caminho), exist_ok=True)
            with open(caminho, "w", encoding="utf-8") as fh:
                fh.write("\n".join(linhas))
        except OSError as e:
            return "não consegui gravar o mapa: %s" % e
        return ""

    # Ler, conferir e desenhar uma declaração é do `scripts/pack.py`
    # (`ler_autoral`, `desenhar_autoral`, `autorais`), e é a mesma porta que o
    # `gerar_icones_autorais.py` usa — a prévia desta tela e o arquivo que o
    # gerador escreve saem da mesma função, e por isso não podem discordar.
    #
    # Escolher um papel repinta a prévia e não grava nada.
    def _api_autorais(self, corpo):
        mod = modulo_pack()
        if not mod:
            return self._json({"erro": "o painel não carregou o scripts/pack.py"}, 500)
        adotado = _pack_adotado()
        dir_pack = (mod.achar(adotado) if adotado else None) or mod.dir_padrao()
        id_pack = os.path.basename(dir_pack.rstrip("/"))
        nome_pack = str(mod.campo(dir_pack, "nome", id_pack) or id_pack)
        try:
            with open(os.path.join(dir_pack, mod.campo(dir_pack, "paleta.arquivo", "paleta.json")),
                      encoding="utf-8") as fh:
                paleta = json.load(fh)
        except (OSError, ValueError) as e:
            return self._json({"erro": "não consegui ler a paleta do pack: %s" % e}, 500)
        accent = (valores_efetivos(["ACCENT"]).get("ACCENT") or "mauve").strip()
        declarados = mod.autorais(dir_pack)
        acao = str(corpo.get("acao", "listar")).strip()

        if acao == "listar":
            desenhos = []
            for nome, (caminho, dono) in sorted(declarados.items()):
                item = {"nome": nome, "pack": dono, "herdado": dono != id_pack,
                        "nome_origem": str(mod.campo(dono, "nome", dono) or dono)}
                try:
                    item["papeis"] = mod.ler_autoral(caminho)["papeis"]
                except mod.Recusa as e:
                    # Uma declaração recusada APARECE, com o motivo: some-la da
                    # lista seria a tela dizendo que o desenho não existe.
                    item["erro"] = str(e)
                desenhos.append(item)
            return self._json({"ok": True, "pack": id_pack, "nome_pack": nome_pack,
                               "desenhos": desenhos, "accent": accent,
                               "cores": list(mod.SLOTS) + [mod.MARCA_ACCENT]})

        nome = str(corpo.get("nome", "")).strip()
        if nome not in declarados:
            return self._json({"erro": "o pack não declara um desenho chamado %s" % nome}, 404)
        caminho, dono = declarados[nome]
        try:
            decl = mod.ler_autoral(caminho)
        except mod.Recusa as e:
            return self._json({"erro": str(e)}, 422)

        # OS PAPÉIS QUE CHEGAM DA PÁGINA SÃO CONFERIDOS PELA MESMA CERCA: o mesmo
        # conjunto de papéis da declaração (nem um a mais, nem um a menos) e,
        # em cada lado, um nome da paleta ou `<accent>`.
        papeis = corpo.get("papeis")
        if papeis is not None:
            if not isinstance(papeis, dict) or set(papeis) != set(decl["papeis"]):
                return self._json({"erro": "os papéis têm de ser os do desenho: %s"
                                           % ", ".join(sorted(decl["papeis"]))}, 400)
            novos = {}
            for papel, par in papeis.items():
                par = par if isinstance(par, dict) else {}
                lados = {lado: str(par.get(lado, "")) for lado in ("escuro", "claro")}
                if any(v not in mod.SLOTS and v != mod.MARCA_ACCENT for v in lados.values()):
                    return self._json({"erro": "%s: a cor tem de ser um nome da paleta" % papel}, 400)
                novos[papel] = lados
            decl = dict(decl, papeis=novos)

        if acao == "previa":
            previas = []
            for flavor, cores in (paleta.get("flavors") or {}).items():
                try:
                    svg = mod.desenhar_autoral(decl, cores, flavor in (paleta.get("claros") or []),
                                               accent, {"titulo": nome})
                except mod.Recusa as e:
                    return self._json({"erro": str(e)}, 422)
                previas.append({"flavor": flavor, "svg": svg,
                                "fundos": [{"nome": k, "cor": cores.get(k, "")}
                                           for k in ("crust", "base", "overlay0", "text")]})
            return self._json({"ok": True, "previas": previas})

        if acao != "salvar":
            return self._json({"erro": "ação desconhecida: %s" % acao}, 400)

        try:
            pasta = mod.dir_acervo("icones.autorais.desenhos", ref=dir_pack,
                                   padrao=mod.PASTA_AUTORAIS)
        except mod.Recusa as e:
            return self._json({"erro": str(e)}, 422)
        # O ARQUIVO INTEIRO SOBREVIVE, e só o `papeis` muda — a mesma regra do
        # `_api_app_icone` para o mapa: as `_nota` são a história do desenho, e
        # editar a cor de alguém não é reescrever o porquê dele.
        try:
            with open(caminho, encoding="utf-8") as fh:
                bruto = json.load(fh)
        except (OSError, ValueError) as e:
            return self._json({"erro": "não consegui reler a declaração: %s" % e}, 500)
        bruto["papeis"] = decl["papeis"]
        destino = os.path.join(pasta, nome + ".json")
        try:
            os.makedirs(pasta, exist_ok=True)
            tmp = destino + ".tmp"
            with open(tmp, "w", encoding="utf-8") as fh:
                fh.write(json.dumps(bruto, ensure_ascii=False, indent=2) + "\n")
            os.replace(tmp, destino)
        except OSError as e:
            return self._json({"erro": "não consegui gravar no pack: %s" % e}, 500)

        # `MEOW_PACK_DIR` é o que faz ele desenhar em Dracula e escrever em
        # `packs/dracula/`; `MEOW_PALETA` sai porque é o passo 1 da precedência
        # e venceria o pack.
        ambiente = dict(os.environ)
        ambiente["MEOW_PACK_DIR"] = dir_pack
        ambiente.pop("MEOW_PALETA", None)
        try:
            r = subprocess.run([sys.executable, os.path.join(RAIZ, "scripts", "gerar_icones_autorais.py"),
                                "--accent", accent, "--saida", pasta],
                               env=ambiente, capture_output=True, text=True, timeout=60)
        except (OSError, subprocess.SubprocessError) as e:
            return self._json({"erro": "gravei o desenho, e o gerador não rodou: %s" % e}, 500)
        if r.returncode != 0:
            return self._json({"erro": "gravei o desenho, e o gerador recusou: %s"
                                       % (r.stderr or r.stdout).strip()[-400:]}, 500)

        # O Hefesto veste a logo que ela desenhou (`__LOGO_DELA__` no
        # `completar_icones.sh`; o `hefesto.json` conta por quê), e um desenho
        # declarado sem linha na tabela `AUTORAL` de lá nasce no pack e não
        # veste ícone nenhum.
        #
        # A pergunta é "algum SVG do tema tem a FORMA deste desenho?".
        def _forma(texto):
            texto = re.sub(r"<title>.*?</title>", "", texto, flags=re.S)
            return re.sub(r"#[0-9A-Fa-f]{3,8}\b", "#", texto).strip()
        formas = set()
        for flavor in (paleta.get("flavors") or {}):
            try:
                with open(os.path.join(pasta, "%s-%s.svg" % (nome, flavor)), encoding="utf-8") as fh:
                    formas.add(_forma(fh.read()))
            except OSError:
                continue
        tema = os.environ.get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
        alvo = os.path.expanduser("~/.local/share/icons/%s/scalable/apps" % tema)
        na_tela = []
        try:
            instalados = sorted(a for a in os.listdir(alvo) if a.endswith(".svg"))
        except OSError:
            instalados = []
        for arq in instalados:
            try:
                with open(os.path.join(alvo, arq), encoding="utf-8", errors="replace") as fh:
                    if _forma(fh.read(400000)) in formas:
                        na_tela.append(arq[:-len(".svg")])
            except OSError:
                continue
        return self._json({"ok": True, "pack": id_pack, "nome_pack": nome_pack,
                           "copiou": dono != id_pack, "na_tela": na_tela,
                           "arquivo": os.path.relpath(destino, dir_pack)})

    def _travas_do_arcticons(self):
        """O que faria o `icones_apps_arcticons.sh` pular uma linha nova do mapa.

        O BOTÃO QUE NÃO PODE VALER — 13/09/2026
          Medido pela interface: «Usar este ícone» no Hefesto gravou a linha, a
          torrada disse "Hefesto: steam em green", a gaveta disse "os ícones
          novos já estão na dock" — e a dock ficou igual. O script pula três
          casos, e nenhum deles chegava à tela:

            intocável  — a lista do script, pedido dela ("estes ficam como
                         estão, venha o que vier"); só a linha `mao` da oficina
                         passa por cima;
            curadoria  — a arte que ela escolheu no `curadoria.map` vence os
                         dois acervos de traço;
            convertido — o app já está no `apps-convertidos.map`, e um nome nos
                         DOIS mapas faz o `_conferir_gemeos` parar o passo
                         inteiro: nenhum ícone de ninguém seria posto.

          A lista dos intocáveis é LIDA do script, não copiada: duas listas
          seriam duas verdades, e a daqui envelheceria primeiro."""
        intocaveis, prefixos = set(), ()
        try:
            with open(os.path.join(RAIZ, "scripts", "icones_apps_arcticons.sh"),
                      "r", encoding="utf-8") as fh:
                texto = fh.read()
            achado = re.search(r"^INTOCAVEIS=\(([^)]*)\)", texto, re.M)
            if achado:
                intocaveis = set(achado.group(1).split())
            achado = re.search(r"^INTOCAVEIS_PREFIXO=\(([^)]*)\)", texto, re.M)
            if achado:
                prefixos = tuple(achado.group(1).split())
        except OSError:
            pass
        curados = set()
        try:
            with open(os.path.join(RAIZ, "assets", "icones", "curadoria.map"),
                      "r", encoding="utf-8") as fh:
                for linha in fh:
                    # A mesma leitura do `_ler_curadoria`: três campos por TAB, e
                    # a linha só conta com os três preenchidos.
                    campos = linha.rstrip("\n").split("\t", 2)
                    if (len(campos) == 3 and campos[0] and not campos[0].startswith("#")
                            and campos[1] and campos[2]):
                        curados.add(campos[0])
        except OSError:
            pass
        return intocaveis, prefixos, curados, self._mapa_convertidos()

    def _motivo_da_trava(self, travas, nomes, rotulo, vigor=None, do_pack=()):
        """A frase que diz por que um glifo do Arcticons não vale neste app, ou None.

        A FRASE DO CONVERTIDO MENTIA POR OMISSÃO — 23/09/2026, sprint P26
          Era "Warehouse já tem desenho convertido do projeto. O traço dele se
          troca na oficina «Gerar ícone», acima." Verdade sobre o MAPA, e falsa
          sobre a TELA: o Warehouse estava vestindo o desenho do pack Dracula,
          feito à mão — o `scalable/apps` vence o `48x48/apps` do traço —, e a
          frase não dizia isso nem que o desenho do pack era uma escolha.
          Agora ela diz quem veste o aplicativo (`vigor`, medido por
          `_quem_veste`) e quais são as alternativas, com os desenhos de pack
          que não estão na tela (`do_pack`) entre elas.

          SEM `vigor` A FRASE ANTIGA CONTINUA, e é de propósito: é o caso da
          recusa do `_api_app_icone`, que não mede a tela — e sobre o mapa ela
          continua sendo verdade.
        """
        intocaveis, prefixos, curados, convertidos = travas
        nomes = [n for n in nomes if n]
        if any(n in intocaveis or (prefixos and n.startswith(prefixos)) for n in nomes):
            return "Fica como está, por pedido seu; só a oficina «Gerar ícone» o troca"
        if any(n in curados for n in nomes):
            return "Usa a arte da sua curadoria, que vence este acervo"
        if any(n in convertidos for n in nomes):
            if not vigor:
                return ("%s já tem desenho convertido do projeto. O traço dele se "
                        "troca na oficina «Gerar ícone», acima." % rotulo)
            alternativas = list(do_pack)
            if vigor.get("tipo") != "conversao":
                alternativas.append("a conversão em traço do projeto")
            alternativas.append("novas variações a partir do original")
            return ("%s veste %s. %s na oficina «Gerar ícone», acima: %s."
                    % (rotulo, vigor["frase"],
                       "As alternativas estão" if len(alternativas) > 1 else "A alternativa está",
                       _enumerar(alternativas)))
        return None

    def _tirar_do_mapa_arcticons(self, app):
        """Um nome nos DOIS mapas faz o `_conferir_gemeos` estourar.

        Está no cabeçalho do `icones_apps_arcticons.sh`: dois acervos para o
        mesmo aplicativo é o defeito de "dois donos" com outra roupa, e o script
        morre em vez de escolher um vencedor calado. Quem desenhou à mão decidiu
        — o Arcticons sai, e o `48x48/apps` órfão some na varredura da mesma
        passagem, porque aquele script é dono único do diretório.

        [P82, 15/10/2026 (item 5): era o `apps-arcticons.map` do clone que
        perdia a linha. Agora o desenho da oficina mora no
        `icones-convertidos.map` de quem usa, que o script lê por último e que
        vence a linha do projeto; o que sai é a escolha de traço de quem usa
        (`icones-traco.map`), que é a outra escolha dela para o mesmo app.]
        """
        caminho = _mapa_de_traco_do_usuario()
        if not os.path.isfile(caminho):
            return False
        try:
            return bool(_gravar_escolha(caminho, app, None, ":"))
        except OSError:
            return False

    def do_POST(self):
        alvo = urlparse(self.path)
        consulta = parse_qs(alvo.query)
        if not self._host_confere():
            return self._recusar(403, "Host inesperado")
        if not self._origem_confere():
            return self._recusar(403, "Origem inesperada")
        if not self._token_confere(consulta):
            return self._recusar(403, "token de sessão ausente ou errado")
        tamanho = int(self.headers.get("Content-Length") or 0)
        # 1 MB bastava enquanto o POST só carregava chave e valor.
        #
        # Com o um terço que o base64 acrescenta, 20 MB de teto recusavam metade
        # do que ela tentaria enviar.
        #
        # 64 MB PARA O `.meowpack`
        teto = {"/api/acervo": 96 << 20,
                "/api/pack-importar": 64 << 20}.get(alvo.path, 1 << 20)
        if tamanho > teto:
            return self._recusar(413, "corpo grande demais")
        try:
            corpo = json.loads(self.rfile.read(tamanho).decode("utf-8") or "{}")
        except (ValueError, UnicodeDecodeError):
            return self._recusar(400, "corpo não é JSON")
        if not isinstance(corpo, dict):
            return self._recusar(400, "corpo não é um objeto")
        return self._api_post(alvo.path, corpo)

    # --- API -----------------------------------------------------------------
    def _servir_pagina(self):
        arquivo = os.path.join(PAGINA, "index.html")
        try:
            with open(arquivo, "r", encoding="utf-8") as fh:
                texto = fh.read()
        except OSError:
            return self._recusar(500, "não achei app/pagina/index.html")
        # O token entra na página UMA vez, aqui, e daí em diante vive só na
        # memória do JavaScript.
        texto = texto.replace("@TOKEN@", html.escape(TOKEN, quote=True))
        return self._responder(texto, tipo=TIPOS[".html"], plantar_cookie=True)

    def _api_get(self, caminho, consulta):
        if caminho == "/api/esquema":
            return self._json(self._dados_esquema())

        if caminho == "/api/pendencias":
            return self._json({"pendencias": pendencias()})

        if caminho == "/api/precisa-de-gente":
            return self._json({"itens": precisa_de_gente()})

        # Os packs com a vitrine — ver `packs_com_vitrine`.
        if caminho == "/api/packs":
            return self._json({"packs": packs_com_vitrine()})

        if caminho == "/api/apps":
            return self._api_apps(consulta)

        if caminho == "/api/glifos":
            return self._api_glifos(consulta)

        if caminho == "/api/jogos":
            return self._api_jogos(consulta)

        if caminho == "/api/previas":
            dados = previas(consulta.get("tipo", [""])[0],
                            consulta.get("grupo", [""])[0] or None)
            if dados is None:
                return self._json({"erro": "tipo de prévia desconhecido"}, 404)
            return self._json(dados)

        if caminho == "/api/trabalho":
            ident = consulta.get("id", [""])[0]
            desde = consulta.get("desde", ["0"])[0]
            try:
                trabalho = TRABALHOS[int(ident)]
                inicio = int(desde)
            except (KeyError, ValueError):
                return self._json({"erro": "trabalho desconhecido"}, 404)
            linhas, total = trabalho.desde(inicio)
            # Os scripts imprimem o caminho expandido, e alguns imprimem
            # COMANDO para colar ("rode: LEITURA_COMPILAR=1 /home/<usuário>/
            # …/leitura_build.sh", "meow wallpaper permitir /home/<usuário>/
            # …").
            linhas = [texto_na_tela(l) for l in linhas]
            pasta = getattr(trabalho, "pasta_restauro", None)
            return self._json({
                "id": trabalho.id, "rotulo": trabalho.rotulo,
                "linhas": linhas, "proximo": total,
                "vivo": trabalho.vivo(), "rc": trabalho.rc,
                "segundos": round((trabalho.fim or time.time()) - trabalho.comeco, 1),
                # Há o que desfazer desta execução: a janela mostra o «Restaurar».
                "restauravel": bool(pasta) and not trabalho.vivo() and _tem_tocados(pasta),
            })

        # LEVAR EMBORA — as duas saídas do botão "Exportar".
        if caminho == "/api/exportar/conf":
            texto, nome = exportar_conf()
            return self._baixar(texto, nome, "text/plain; charset=utf-8")

        if caminho == "/api/exportar/pagina":
            texto, nome = self._exportar_pagina()
            return self._baixar(texto, nome, TIPOS[".html"])

        # O PACK QUE VIAJA — ver `_api_pack_exportar`.
        if caminho == "/api/pack-exportar":
            return self._api_pack_exportar(consulta)

        return self._recusar(404, "não existe aqui")

    # O PACK QUE VIAJA
    #
    # QUEM EMPACOTA E QUEM INSTALA É O COMANDO DA CLI, pela regra do
    # `_acervo_por_comando`: "a capacidade não nasce presa ao navegador".
    def _api_pack_exportar(self, consulta):
        ident = consulta.get("id", [""])[0]
        mod = modulo_pack()
        # O `id` só vale se a varredura o achou — a cerca do `arte_da_vitrine`:
        # o `achar` do pack.py também aceita CAMINHO, e esta rota não é porta
        # para empacotar um diretório qualquer do disco.
        if not mod or ident not in _packs_no_disco():
            return self._json({"erro": "não conheço esse pack"}, 404)
        medir = consulta.get("medir", [""])[0] == "1"
        extra = ["--sem-imagens"] if consulta.get("imagens", [""])[0] == "nao" else []
        with tempfile.TemporaryDirectory(prefix="meow-exporta-") as pasta:
            saida = os.path.join(pasta, ident + ".meowpack")
            try:
                # `stdin` fechado: sem terminal do outro lado, o `exportar` não
                # pergunta — quem pergunta é a tela, pelo `medir`, e manda a
                # resposta no `imagens`.
                r = subprocess.run(_meow("pack", "exportar", ident, saida, *extra),
                                   capture_output=True, text=True, timeout=120,
                                   stdin=subprocess.DEVNULL,
                                   env=_ambiente_do_painel(seco=medir))
            except (OSError, subprocess.SubprocessError) as erro:
                return self._json({"erro": "não consegui rodar: %s" % erro}, 500)
            if r.returncode != 0 or not (medir or os.path.isfile(saida)):
                texto = (r.stderr or "").strip() or (r.stdout or "").strip()
                return self._json({"erro": texto or "o exportar falhou", "rc": r.returncode}, 400)
            if medir:
                # Os números saem da `medida` e o texto do `_mb`, os mesmos do
                # terminal: a tela e o `meow pack exportar` dizem o mesmo MB.
                m = mod.medir_exportacao(ident)
                m.update(tamanho=mod._mb(m["bytes"]),
                         tamanho_imagens=mod._mb(m["bytes_imagens"]),
                         tamanho_sem_imagens=mod._mb(m["bytes"] - m["bytes_imagens"]))
                # O `exportar` diz, com `!!`, que o pack herda de um pack que
                # não vem com o MeowSystem — quem importar precisa tê-lo.
                m["avisos"] = [linha.strip()[2:].strip()
                               for linha in (r.stderr or "").splitlines()
                               if linha.strip().startswith("!!")]
                return self._json(m)
            with open(saida, "rb") as fh:
                corpo = fh.read()
        return self._baixar(corpo, ident + ".meowpack", "application/zstd")

    def _api_pack_importar(self, corpo):
        mod = modulo_pack()
        if not mod:
            return self._json({"erro": "scripts/pack.py não carregou"}, 500)
        try:
            dados = base64.b64decode(str(corpo.get("conteudo", "")), validate=True)
        except Exception:
            return self._json({"erro": "conteúdo não é base64"}, 400)
        if not dados:
            return self._json({"erro": "o arquivo veio vazio"}, 400)
        confirmado = corpo.get("confirmado") is True
        # "O 'Importar um pack' aceita um .csv solto, não só um .meowpack." A
        # extensão do `nome` decide, como decidiu para quem o escolheu no
        # seletor.
        envio = os.path.basename(str(corpo.get("nome") or ""))
        de_csv = envio.lower().endswith(".csv")
        with tempfile.TemporaryDirectory(prefix="meow-importa-") as pasta:
            # MENOS NO CSV, que não tem onde trazer o id: ele sai do nome do
            # arquivo, pela `id_do_csv` do pack.py — a mesma que o `importar`
            # aplica.
            if de_csv:
                try:
                    mod.id_do_csv(envio)
                except mod.Recusa as erro:
                    return self._json({"erro": str(erro)}, 400)
                caminho = os.path.join(pasta, envio)
            else:
                caminho = os.path.join(pasta, "envio.meowpack")
            # O nome é de fora, e o disco pode recusá-lo (um NUL, 256 bytes):
            # isso é o arquivo dela, e volta como erro dela, não como 500.
            try:
                with open(caminho, "wb") as fh:
                    fh.write(dados)
            except (OSError, ValueError) as erro:
                return self._json({"erro": "não consegui receber %s: %s" % (envio, erro)}, 400)
            try:
                # O ensaio é o `MEOW_DRY_RUN` de sempre, que o `bin/meow` traduz
                # em `--seco`: a prévia e a instalação são o MESMO comando, e a
                # tela não tem como mostrar um pack que o terminal recusaria.
                r = subprocess.run(_meow("pack", "importar", caminho),
                                   capture_output=True, text=True, timeout=120,
                                   stdin=subprocess.DEVNULL,
                                   env=_ambiente_do_painel(seco=not confirmado))
            except (OSError, subprocess.SubprocessError) as erro:
                return self._json({"erro": "não consegui rodar: %s" % erro}, 500)
            if r.returncode != 0:
                # A recusa é o stderr: o stdout tem o `ok` da validação, e a
                # torrada que leva os dois diz "ok" e "recusado" na mesma frase.
                texto = (r.stderr or "").strip() or (r.stdout or "").strip()
                # As recusas do `importar` citam o caminho que ele recebeu, e
                # esse caminho é o temporário daqui: a torrada dizia
                # "/tmp/meow-importa-xrbbubgv/envio.meowpack: não é
                # um.meowpack", um nome que ela nunca viu e uma pasta que já não
                # existe quando ela lê.
                texto = texto.replace(caminho, envio or "o arquivo enviado")
                return self._json({"erro": texto or "o importar falhou", "rc": r.returncode}, 400)
            pack = mod.resumo_csv(caminho) if de_csv else mod.resumo_meowpack(caminho)
        nome = pack["nome"]
        if not confirmado:
            # O `resumo` é a frase de cima da caixa; o que o pack traz, item a
            # item, a página desenha do `pack` — a paleta não cabe numa frase.
            if de_csv:
                # O id vai junto porque saiu do nome do arquivo, e é por ele que
                # o pack aparece no meow.conf.
                resumo = ("Um pack novo, «%s», feito de %s: a paleta é a do CSV, e o resto "
                          "vem do %s pela herança. Ele entra como opção entre os packs — "
                          "nada do seu tema muda até você escolher usá-lo."
                          % (pack["id"], envio, pack["heranca"]))
            else:
                quantos = "{:,}".format(pack["arquivos"]).replace(",", ".")
                por = "Por %s. " % pack["autor"] if pack["autor"] else ""
                resumo = ("%s%s arquivo(s), %s. Ele entra como opção entre os packs — "
                          "nada do seu tema muda até você escolher usá-lo."
                          % (por, quantos, mod._mb(pack["bytes"])))
            # Era «Importar o Tinta De Teste?»: o nome solto depois do artigo
            # lia-se como frase, e o «De» maiúsculo vinha do id.
            return self._json({
                "precisa_confirmar": True,
                "titulo": "Importar o pack «%s»?" % nome,
                "resumo": resumo,
                "pack": pack,
            })
        return self._json({
            "instalado": True, "id": pack["id"], "pack": pack,
            "frase": "O %s entrou — ele aparece entre os packs, e usar é outro clique." % nome,
        })

    def _baixar(self, corpo, nome, tipo):
        """Uma resposta que o navegador GRAVA em vez de mostrar.

        O `Content-Disposition` é a única diferença para uma resposta comum, e
        por isso ele entra pelo `extras` do `_responder` em vez de por uma
        rotina própria: as quatro guardas de cabeçalho continuam valendo.

        E o NOME sai daqui, não do `app.js`: um `<a download="…">` no navegador
        também funcionaria, mas o nome carrega a data, e um arquivo de
        configuração com data errada é o tipo de coisa que só se descobre meses
        depois, na hora de restaurar.
        """
        return self._responder(
            corpo, tipo=tipo,
            # `filename` citado: o nome é montado aqui e só tem letra, número,
            # hífen e ponto, mas a citação é o que a especificação pede.
            extras={"Content-Disposition":
                    'attachment; filename="%s"' % nome.replace('"', "")})

    # O que sai daqui abre com dois cliques em qualquer máquina, sem Python,
    # sem servidor e sem o projeto instalado: as vinte e quatro abas, o menu
    # lateral, os cartões com os valores que estão no meow.conf dela agora, e
    # uma amostra das imagens de verdade (papéis de parede, ícones, capas).
    #
    # É o `app.js` DE VERDADE — o mesmo arquivo, sem uma linha diferente —
    # rodando contra dados congelados.
    AMOSTRA_POR_TIPO = {"parede": 30, "icone": 0, "cursor": 0, "gato": 0}
    AMOSTRA_APPS = 36
    AMOSTRA_JOGOS = 12
    TETO_IMAGEM = 160 << 10      # 160 KB por imagem
    TETO_TOTAL = 12 << 20        # 12 MB de imagens no arquivo todo

    def _svg_vazado(self):
        """O quadro que aparece onde a imagem não coube. Sem hex: a cor vem da
        paleta que já está na página, pelo `currentColor`."""
        return ("data:image/svg+xml;charset=utf-8," + quote(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
            '<rect x="1" y="1" width="46" height="46" rx="6" fill="none" '
            'stroke="currentColor" stroke-opacity=".35" stroke-dasharray="4 3"/>'
            '</svg>', safe=""))

    def _embutir(self, caminho, sacola, gasto):
        """(data_uri, novo_gasto) — o arquivo em base64, ou (None, gasto)."""
        try:
            tamanho = os.path.getsize(caminho)
        except OSError:
            return None, gasto
        if tamanho > self.TETO_IMAGEM or gasto + tamanho > self.TETO_TOTAL:
            return None, gasto
        try:
            with open(caminho, "rb") as fh:
                bruto = fh.read()
        except OSError:
            return None, gasto
        ext = os.path.splitext(caminho)[1].lower()
        mime = {".svg": "image/svg+xml", ".png": "image/png", ".jpg": "image/jpeg",
                ".jpeg": "image/jpeg", ".webp": "image/webp"}.get(ext)
        if mime is None:
            return None, gasto
        uri = "data:%s;base64,%s" % (mime, base64.b64encode(bruto).decode("ascii"))
        return uri, gasto + tamanho

    def _imagens_da_amostra(self, esquema, apps, jogos):
        """{url_original: data_uri} — o mapa que o prelúdio usa para trocar
        o `src` das imagens sem o `app.js` saber de nada."""
        mapa, gasto = {}, 0

        # A MARCA DO CABEÇALHO: ela não é prévia, é o rosto da página, e entra
        # sempre porque é pequena.
        corpo_logo = self._logo_do_painel()
        if corpo_logo:
            mapa["/logo.svg"] = "data:image/svg+xml;base64," + base64.b64encode(
                corpo_logo).decode("ascii")
            gasto += len(corpo_logo)

        # As prévias, tipo a tipo. `previas()` já enfileira o que falta gerar;
        # aqui só se lê o que JÁ está pronto — exportar não é hora de esperar
        # uma fila de miniaturas.
        for tipo, limite in self.AMOSTRA_POR_TIPO.items():
            dados = previas(tipo) or {}
            itens = dados.get("itens", [])
            if limite:
                itens = itens[:limite]
            for item in itens:
                if not item.get("pronta"):
                    continue
                bytes_e_tipo = previa_bytes(tipo, item["id"])
                if not bytes_e_tipo:
                    continue
                bruto, mime = bytes_e_tipo
                if len(bruto) > self.TETO_IMAGEM or gasto + len(bruto) > self.TETO_TOTAL:
                    continue
                mapa[item["url"]] = "data:%s;base64,%s" % (
                    mime, base64.b64encode(bruto).decode("ascii"))
                gasto += len(bruto)

        # Ícone de aplicativo e capa de jogo vêm por caminho de arquivo
        # (`/previa?tipo=arquivo&id=…`), e não pela fila de prévias.
        for lista, quantos in ((apps.get("apps", []), self.AMOSTRA_APPS),
                               (jogos.get("jogos", []), self.AMOSTRA_JOGOS)):
            entraram = 0
            for item in lista:
                if entraram >= quantos:
                    break
                url = item.get("url") or ""
                if not url or url in mapa:
                    continue
                consulta_img = parse_qs(urlparse(url).query)
                alvo = consulta_img.get("id", [""])[0]
                if not alvo:
                    continue
                uri, novo = self._embutir(alvo, mapa, gasto)
                if uri:
                    mapa[url] = uri
                    gasto = novo
                    entraram += 1
        return mapa, gasto

    def _exportar_pagina(self):
        """(html, nome_do_arquivo) — a página inteira, servida de um arquivo só."""
        esquema = self._dados_esquema()
        apps = self._dados_apps({})
        jogos = self._dados_jogos({})
        previas_congeladas = {}
        for tipo in PREVIA_FONTES:
            dados = previas(tipo) or {}
            previas_congeladas[tipo] = dados
            for grupo in PREVIA_GRUPOS.get(tipo, ()):
                previas_congeladas["%s/%s" % (tipo, grupo)] = previas(tipo, grupo) or {}
        imagens, gasto = self._imagens_da_amostra(esquema, apps, jogos)

        valores = valores_efetivos(["FLAVOR", "ACCENT", "MODO"])
        flavor = _flavor_do_conf(valores)
        flavor = _flavor_da_pagina(flavor, valores)
        paleta = paleta_css(flavor, _acento_da_pagina(flavor, valores))

        def ler(nome):
            try:
                with open(os.path.join(PAGINA, nome), "r", encoding="utf-8") as fh:
                    return fh.read()
            except OSError:
                return ""

        pagina = ler("index.html")
        # O corpo, sem o `<head>` (que é remontado abaixo com o CSS embutido) e
        # sem o token, que não existe fora do servidor.
        corpo = pagina
        if "<body" in corpo:
            corpo = corpo[corpo.index("<body"):]
        corpo = corpo.replace('data-token="@TOKEN@"', 'data-token="" data-standalone="1"')
        # Agora a lista de scripts é LIDA do `index.html`, na ordem em que ele
        # os declara, e é a mesma lista que volta embutida lá embaixo.
        scripts_da_pagina = re.findall(r'<script src="/([A-Za-z0-9_.-]+\.js)"></script>', corpo)
        corpo = re.sub(r'<script src="/[A-Za-z0-9_.-]+\.js"></script>', "", corpo)
        corpo = corpo.replace("</body>", "").replace("</html>", "")

        dados = {
            "esquema": esquema, "apps": apps, "jogos": jogos,
            "previas": previas_congeladas, "imagens": imagens,
            "exportado_em": time.strftime("%d/%m/%Y às %H:%M"),
            "maquina": {"flavor": flavor, "accent": valores.get("ACCENT") or "mauve",
                        "modo": valores.get("MODO") or ""},
            "amostra": {"imagens": len(imagens), "bytes": gasto},
        }
        # O `sem_casa_nem_raiz` logo abaixo só sabe da casa e do clone, e o
        # valor de uma chave com caminho aponta para onde a pessoa quiser.
        outras = []
        for item in esquema.get("chaves", []):
            if any(re.search(r"(?:^|[\s:=,])(?:/(?!/)|~(?:/|$)|\$\{?HOME\b)",
                             item.get(campo) or "")
                   for campo in ("valor", "efetivo")):
                efetivo = item.get("efetivo") or os.path.expandvars(item.get("valor") or "")
                for pedaco in efetivo.split(":"):
                    pedaco = os.path.expanduser(pedaco.strip()).rstrip(os.sep)
                    if not pedaco.startswith(os.sep) or pedaco.startswith("//"):
                        continue
                    for forma in dict.fromkeys((pedaco, os.path.realpath(pedaco))):
                        if forma != RAIZ and not _na_casa(forma) \
                                and not forma.startswith(RAIZ + os.sep):
                            outras.append((forma, "$" + item["chave"]))
                item["valor"] = item.get("padrao", "")
                item["efetivo"] = ""
        # A mais longa primeiro: uma pasta dentro de outra não pode ser comida
        # pela de fora antes de ter a vez.
        outras.sort(key=lambda par: -len(par[0]))
        # Sem a casa e sem o caminho do clone — ver `sem_casa_nem_raiz`.
        dados = sem_casa_nem_raiz(dados, outras)

        partes = [
            "<!DOCTYPE html>",
            "<!--",
            "  A PÁGINA DO MEOWSYSTEM, INTEIRA, NUM ARQUIVO SÓ.",
            "",
            "  Exportada em %s. Nada aqui fala com servidor nenhum: os dados" % dados["exportado_em"],
            "  estão congelados no <script id=\"meow-dados\"> lá embaixo, e as",
            "  imagens são uma amostra do acervo desta máquina (%d delas)." % len(imagens),
            "",
            "  PARA QUEM VAI REDESENHAR",
            "    O que volta para o projeto é o conteúdo de",
            "    <style id=\"folha-do-painel\"> — ele é o app/pagina/estilo.css",
            "    inteiro, e é copiado de volta sem tradução nenhuma. Mexa nele",
            "    à vontade.",
            "",
            "    O contrato são os NOMES DE CLASSE: .cartao, .trilho, .btn,",
            "    .pastilha, .gaveta e companhia são gerados por JavaScript e",
            "    também consumidos por ele. Mudar a aparência de uma classe é",
            "    grátis; renomear ou apagar uma classe quebra a página. Se o",
            "    desenho pedir estrutura nova, descreva a mudança em texto no",
            "    fim do arquivo, num comentário — é mais rápido de aplicar do",
            "    que adivinhar a intenção a partir do HTML.",
            "-->",
            '<html lang="pt-BR">',
            "<head>",
            '<meta charset="utf-8">',
            '<meta name="viewport" content="width=device-width, initial-scale=1">',
            "<title>MeowSystem — página para redesenho</title>",
            '<style id="paleta-do-painel">\n%s\n</style>' % paleta,
            # A FOLHA QUE VOLTA É ESTA, e o `id` é o contrato: quem redesenhar
            # mexe aqui dentro, e o que sair daqui é copiado de volta para o
            # `app/pagina/estilo.css` sem tradução nenhuma.
            '<style id="folha-do-painel">\n%s\n</style>' % ler("estilo.css"),
            '<style id="folha-do-standalone">\n%s\n</style>' % ler("standalone.css"),
            "</head>",
            corpo,
            # O `</` escapado: um `</script>` dentro do JSON fecharia a tag aqui
            # e derrubaria a página inteira.
            '<script id="meow-dados" type="application/json">%s</script>'
            % json.dumps(dados, ensure_ascii=False).replace("</", "<\\/"),
            "<script>\n%s\n</script>" % ler("standalone.js"),
        ] + [
            # Na MESMA ORDEM do `index.html`: os arquivos de prévia definem
            # `window.MEOW_PREVIAS` e o `app.js` o consome.
            "<script>\n%s\n</script>" % ler(nome) for nome in scripts_da_pagina
        ] + [
            "</body>",
            "</html>",
        ]
        return "\n".join(partes), "meowsystem-painel-%s.html" % _carimbo()

    @_numa_leitura
    def _dados_esquema(self):
        """O que a página inteira consome. Um dicionário só, e é ele que o
        `exportar_pagina` congela dentro do arquivo standalone."""
        esquema = ler_esquema()
        chaves = [i["chave"] for i in esquema]
        brutos = valores_brutos()
        efetivos = valores_efetivos(chaves)
        for item in esquema:
            item["valor"] = brutos.get(item["chave"], "")
            item["efetivo"] = efetivos.get(item["chave"], "")
            # Quando o applet guarda a chave, é o valor DELE que a máquina usa
            # (o meow.conf é o padrão de fábrica, `_leitura_resolver_alvo`), e é
            # ele que o cartão mostra como o valor da chave.
            if item["chave"] in _LEITURA_NO_APPLET and item.get("valendo_agora") is not None:
                item["valor_no_arquivo"] = item["valor"]
                item["valor"] = item["valendo_agora"]
                item["fonte"] = "applet"
        # O VOCABULÁRIO DO PACK NO AR. Depois dos valores, porque a
        # «Variante dos ícones de arquivo» mostra o de agora quando ele está
        # fora do que o pack oferece.
        vocab = vocabulario_do_pack()
        _com_o_vocabulario_do_pack(esquema, vocab, efetivos)
        # E o que cada flavor veste em cada lado, para a prévia de «Cor e tela»
        # desenhar o que a página vai vestir — o COSMIC nem sempre veste o
        # mesmo.
        if isinstance(vocab, dict):
            vocab["lados"] = _lados_do_pack()
        for item in esquema:
            teto = teto_da_chave(item["chave"])
            if teto:
                item["teto"] = teto
        # «Quais programas o lançador esconde» mostrava 32 ids crus —
        # `org.gnome.Evince`, `org.gnome.baobab`, `gnome-language-selector` —,
        # e a pergunta da chave é «quais PROGRAMAS»: quem lê um id reverso de
        # domínio não sabe que é o leitor de PDF.
        so_com = [i for i in esquema if i.get("so_com_app")]
        if so_com:
            desktops = {d["id"] for d in self._desktops()}
            for item in so_com:
                item["sem_programa"] = not any(ident in desktops for ident in item["so_com_app"])
        com_ids = [i for i in esquema if i.get("ids_de_desktop")]
        if com_ids:
            por_id = {d["id"]: d for d in self._desktops()}
            tema = os.environ.get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
            base_tema = os.path.expanduser("~/.local/share/icons/%s" % tema)
            for item in com_ids:
                citados = ",".join((item.get("valor") or "", item.get("padrao") or ""))
                programas = {}
                for ident in dict.fromkeys(x.strip() for x in citados.split(",")):
                    d = por_id.get(ident)
                    if not d:
                        continue
                    atual, _nosso = self._icone_na_tela(d, base_tema)
                    programas[ident] = {
                        "nome": d["nome"],
                        "icone": ("/previa?tipo=arquivo&id=" + quote(atual, safe=""))
                                 if atual else "",
                    }
                item["programas"] = programas
        medidas = dict(_medidas_do_projeto(), **_medidas_da_tela())
        restauros_agora = restauros()
        return {
            # `~/.config/meow/meow.conf`, e não o caminho com o nome de usuário:
            # a página só o mostra, no balão do resumo do topo.
            "conf": texto_na_tela(CONF),
            # A casa, para a página trocá-la por `~` nos balões de caminho — o
            # `comTil` do `app.js`. Na página exportada ela já sai como `~`
            # (ver `sem_casa_nem_raiz`), e o `comTil` não tem o que trocar.
            "casa": os.path.expanduser("~"),
            "conf_existe": os.path.isfile(CONF),
            "exemplo": CONF_PADRAO,
            "raiz": RAIZ,
            "chaves": esquema,
            # Para o item "Créditos" do menu — ver `_repositorio_no_ar`.
            "repositorio": _repositorio_no_ar(),
            # O gato que está no dock agora, do `logo.sh no-dock` — o retrato
            # da Início o diz, e não a `LOGO`, que é só a do modo fixo.
            "gato_no_dock": _gato_no_dock(),
            # A janela que o controle do modo de leitura guarda, quando guarda
            # as duas pontas — ver `_noite_do_applet`.
            "noite_do_applet": _noite_do_applet(),
            # Quais combinações de FLAVOR × ACCENT existem de verdade: a
            # página avisa ANTES de ela salvar uma que o instalador recusa.
            "capturas": _capturas_no_disco(),
            # E quais APLICAM, contando as que se derivam: é esta que o
            # cartão da cor de destaque consulta. Ver `_acentos_que_aplicam`.
            "acentos_que_aplicam": _acentos_que_aplicam(esquema),
            # `escreve` é DERIVADO (ver a função de mesmo nome), nunca digitado
            # por ação.
            #
            # Quem acabou de ligar a ponte não tem, na tela, nenhuma prova de
            # que ligá-la serviu para alguma coisa.
            "medidas": medidas,
            "acoes": [
                dict({c: x for c, x in v.items() if not callable(x)}, id=k,
                     ajuda=_com_medidas(_ajuda_do_pack(k) or v.get("ajuda", ""),
                                        medidas),
                     # O comando da TELA, e não o que roda: a página só o
                     # mostra (a linha do cartão, o «ver comando», a caixa de
                     # confirmar) e pede a ação pelo `id`.
                     argv=None,
                     escreve=escreve(v),
                     restauro=k in restauros_agora,
                     sudo=bool(v.get("sudo")) and not (
                         k in _PELA_PONTE and _ponte_viva()),
                     pela_ponte=bool(v.get("sudo")) and (
                         k in _PELA_PONTE and _ponte_viva()),
                     # O MOTIVO, e não a função que o mede: a medida roda
                     # aqui, a cada leitura, e a página só o diz.
                     indisponivel=indisponivel(k),
                     opcoes=([] if v.get("oculta")
                             else PROVEDORES[v["arg"]]() if "arg" in v else []))
                for k, v in ACOES.items()
            ],
            "ponte": _ponte_viva(),
            # O pack no ar, com as palavras dele: os flavors e os nomes que a
            # barra «Fundo» e os seletores da aba Ícones usam. Ver
            # `vocabulario_do_pack`.
            "pack": vocab,
            "folhas": self._folhas(),
            "descricoes": DESCRICAO_SECAO,
            "blocos": BLOCO_DA_SECAO,
            # O nome da aba que abre o painel, dito num lugar só: é o mesmo que
            # o `--onde inicio` dá aos scripts.
            "aba_inicio": ABA_INICIO,
            # A paleta inteira vai junto: as amostras de flavor e de cor são
            # desenhadas com ela, e uma segunda viagem ao servidor para 4x26
            # valores seria viagem à toa.
            "paleta": {
                "ordem": _paleta_dados().get("ordem_canonica", []),
                "claros": _paleta_dados().get("claros", []),
                "flavors": _paleta_dados().get("flavors", {}),
            },
        }

    def _api_post(self, caminho, corpo):
        if caminho == "/api/definir":
            chave = str(corpo.get("chave", ""))
            valor = str(corpo.get("valor", ""))
            # A chave tem de estar no esquema. Sem esta linha a página poderia
            # gravar QUALQUER nome no meow.conf dela — inclusive um que o `. conf`
            # do shell fosse executar como variável de outro projeto.
            item = next((i for i in ler_esquema() if i["chave"] == chave), None)
            if item is None:
                return self._json({"erro": "chave fora do meow.conf.exemplo"}, 400)
            # E O VALOR TAMBÉM, agora — ver `validar_valor`. 400 e não 409: é o
            # pedido que está errado, e a torrada de erro da página já sabe
            # mostrar a frase que vem aqui dentro.
            queixa = validar_valor(item, valor)
            if queixa:
                return self._json({"erro": queixa, "chave": chave, "valor": valor}, 400)
            # A ponta solta da noite é 409: o valor cabe na chave, e o que não
            # cabe é o par que ficaria no arquivo.
            soltas = pontas_da_noite_soltas({chave: valor})
            if soltas:
                return self._json({"erro": soltas[0]["erro"], "chave": chave,
                                   "valor": valor, "recusadas": soltas}, 409)
            rc, saida = definir(chave, valor)
            # A frase do `meow_conf_definir` vira torrada: a casa sai como `~`.
            return self._json({"rc": rc, "saida": texto_na_tela(saida),
                               "chave": chave, "valor": valor})

        # Fechar a caixa deixava tudo gravado e nada aplicado. A tranca existe
        # para o botão "Instalar tudo" de uma máquina crua; para quem escolheu e
        # apertou Salvar, o clique já é a resposta.
        if caminho == "/api/salvar":
            mudancas = corpo.get("mudancas") or {}
            if not isinstance(mudancas, dict):
                return self._json({"erro": "as escolhas chegaram num formato que não conheço"}, 400)
            esquema = {i["chave"]: i for i in ler_esquema()}
            pares, recusadas = [], []
            for chave, valor in mudancas.items():
                chave, valor = str(chave), str(valor)
                item = esquema.get(chave)
                queixa = ("fora do meow.conf.exemplo" if item is None
                          else validar_valor(item, valor))
                if queixa:
                    recusadas.append({"chave": chave, "erro": queixa})
                else:
                    pares.append((chave, valor))
            if recusadas:
                return self._json({"recusadas": recusadas}, 400)
            # O par da noite, sobre o arquivo como ficaria.
            soltas = pontas_da_noite_soltas(dict(pares))
            if soltas:
                return self._json({"recusadas": soltas}, 409)

            # Mandar a página chamar `rodar: instalar, seco` responderia sobre o
            # meow.conf do DISCO, que é justamente o que ainda não tem as 17
            # escolhas dentro: um ensaio que responde outra pergunta.
            #
            # "$fonte"`) como primeira coisa que faz, e atribuição crua de
            # arquivo sourceado sobrescreve o ambiente.
            if corpo.get("seco"):
                pasta, queixa = _conf_de_ensaio(pares)
                if queixa:
                    return self._json({"erro": queixa}, 500)
                trabalho, erro = iniciar("instalar", "", confirmado=True,
                                         seco=True, pasta_de_ensaio=pasta)
                if erro:
                    # Um «já há um trabalho correndo» a cada clique deixaria um
                    # retrato do meow.conf dela em `/tmp` por clique.
                    shutil.rmtree(pasta, ignore_errors=True)
                    return self._json(
                        {"erro": erro["erro"] if isinstance(erro, dict) else erro}, 409)
                return self._json({"trabalho": _trabalho_json(trabalho, "instalar", seco=True)})

            # O meow.conf de antes vai para o ponto de restauro do instalador: o
            # Restaurar desta passada devolve também as escolhas.
            try:
                with open(CONF, "rb") as fh:
                    conf_antes = fh.read()
            except OSError:
                conf_antes = None
            gravadas, iguais, falhas = [], [], []
            for chave, rc, saida in definir_varias(pares):
                if rc == 0:
                    iguais.append(chave)
                elif rc == 1:
                    gravadas.append(chave)
                else:
                    falhas.append({"chave": chave,
                                   "erro": texto_na_tela(saida) or "não consegui gravar"})
            if falhas:
                # Metade gravada é o pior estado, e ele não é escondido: a página
                # recebe o que entrou e o que não entrou, e o instalador NÃO roda.
                return self._json({"gravadas": gravadas, "iguais": iguais, "falhas": falhas,
                                   "erro": "nem tudo foi gravado, e nada foi aplicado"}, 500)

            resposta = {"gravadas": gravadas, "iguais": iguais}
            # Falhar aqui não derruba o salvar (o conf já está gravado): a frase
            # vai junto da resposta.
            leitura = [c for c, _v in pares if c in _LEITURA_NO_APPLET]
            if leitura:
                try:
                    feito = subprocess.run(_meow("leitura", "adotar", *leitura),
                                           capture_output=True, timeout=20,
                                           env=_ambiente_do_painel())
                    if feito.returncode not in (0, 1):
                        resposta["aviso"] = texto_na_tela(
                            feito.stdout.decode("utf-8", "replace")
                            + feito.stderr.decode("utf-8", "replace")).strip()
                except (OSError, subprocess.SubprocessError) as e:
                    resposta["aviso"] = "o controle do modo de leitura não foi atualizado: %s" % e
            trabalho, erro = iniciar("instalar", "", confirmado=True,
                                     antes={CONF: conf_antes} if gravadas else None)
            if erro:
                resposta["erro"] = erro["erro"] if isinstance(erro, dict) else erro
                return self._json(resposta, 409)
            resposta["trabalho"] = _trabalho_json(trabalho, "instalar")
            return self._json(resposta)

        if caminho == "/api/acervo":
            return self._api_acervo(corpo)

        if caminho == "/api/app-icone":
            return self._api_app_icone(corpo)

        if caminho == "/api/app-desenho":
            return self._api_app_desenho(corpo)

        if caminho == "/api/autorais":
            return self._api_autorais(corpo)

        if caminho == "/api/jogo-fora":
            return self._api_jogo_fora(corpo)

        if caminho == "/api/rodar":
            acao = str(corpo.get("acao", ""))
            argumento = str(corpo.get("argumento", "") or "")
            # `confirmado` é a resposta à pergunta que o servidor recusou fazer
            # sozinho.
            seco = bool(corpo.get("seco"))
            trabalho, erro = iniciar(acao, argumento,
                                     confirmado=bool(corpo.get("confirmado")),
                                     seco=seco)
            if erro:
                # O erro estruturado (a confirmação que falta) passa inteiro; o
                # erro de sempre continua sendo uma frase, como a página espera.
                return self._json(erro if isinstance(erro, dict) else {"erro": erro}, 409)
            # O CÓDIGO 1 QUER DIZER MAIS DE UMA COISA — visto na tela, quando um
            # `meow status` (que só lê) terminou com a pastilha "mexeu e
            # consertou".
            return self._json(_trabalho_json(trabalho, acao, seco=seco))

        # O `.meowpack` — ver `_api_pack_exportar`. Fora do "trazer de volta"
        # logo abaixo, e é de propósito: aquele só analisa, e este, com
        # `confirmado: true`, instala.
        if caminho == "/api/pack-importar":
            return self._api_pack_importar(corpo)

        # TRAZER DE VOLTA — só analisa e devolve o que mudaria; quem grava é o
        # `Salvar e aplicar` de sempre. O porquê está em `importar_conf`.
        if caminho == "/api/importar":
            texto = str(corpo.get("texto", ""))
            if not texto.strip():
                return self._json({"erro": "o arquivo veio vazio"}, 400)
            return self._json(importar_conf(texto))

        # A RECUSA é a outra metade da pergunta: sem ela o "não quero" não
        # existiria na tela, e a pendência voltaria amanhã. A tabela
        # `RECUSA_DA_PENDENCIA` é a cerca: id fora dela não tem recusa, e um POST
        # forjado não vira execução de nada.
        if caminho == "/api/pendencia-recusar":
            ident = str(corpo.get("id", ""))
            argv = RECUSA_DA_PENDENCIA.get(ident)
            if argv is None:
                return self._json({"erro": "esta pendência não aceita recusa"}, 404)
            # Sem o `meow.conf` de propósito: gravar a recusa não lê chave
            # nenhuma, só escreve um arquivo em `MEOW_ESTADO` — que já vem no
            # ambiente do painel.
            try:
                fim = subprocess.run(argv, capture_output=True, timeout=30,
                                     env=_ambiente_do_painel())
            except (OSError, subprocess.SubprocessError) as erro:
                return self._json({"erro": "não consegui gravar a recusa: %s" % erro}, 500)
            return self._json({"recusada": ident, "rc": fim.returncode})

        if caminho == "/api/parar":
            try:
                trabalho = TRABALHOS[int(corpo.get("id", -1))]
            except (KeyError, ValueError, TypeError):
                return self._json({"erro": "trabalho desconhecido"}, 404)
            return self._json({"parado": trabalho.parar()})

        # O «Guardar» da janela de resultado: o log inteiro vai para `logs/`.
        if caminho == "/api/guardar-log":
            try:
                trabalho = TRABALHOS[int(corpo.get("id", -1))]
            except (KeyError, ValueError, TypeError):
                return self._json({"erro": "trabalho desconhecido"}, 404)
            try:
                caminho_log = guardar_log(trabalho)
            except OSError as erro:
                return self._json({"erro": "não consegui guardar o log: %s" % erro}, 500)
            return self._json({"caminho": texto_na_tela(caminho_log)})
        return self._recusar(404, "não existe aqui")

    def _folhas(self):
        """As folhas visuais versionadas, lidas do índice de docs/folhas/."""
        try:
            nomes = sorted(f for f in os.listdir(FOLHAS) if f.endswith(".html"))
        except OSError:
            return []
        return [{"arquivo": n, "caminho": os.path.join(FOLHAS, n)} for n in nomes]


# O `.desktop` nascia com `Terminal=true` de propósito: a janela do terminal era
# o interruptor, e fechá-la derrubava o servidor.
#
#       app-cosmic-com.meowsystem.Painel-44306.scope: PID 44306 vanished before
#       we could move it to target cgroup … Failed with result 'resources'
#
# A saída óbvia era a página pingar `/api/vivo` de tantos em tantos segundos.
#
# Fechar a janela no meio de um `./install.sh` não pode virar meia instalação.
VIGIA_LIGADO = os.environ.get("MEOW_APP_VIGIA") == "1"
# Quanto tempo sem NENHUM pulso antes de sair. Oito segundos é folga larga para
# um F5 (que volta em menos de um) e curto o bastante para a porta não ficar
# aberta depois de ela fechar a janela.
VIGIA_CARENCIA = float(os.environ.get("MEOW_APP_CARENCIA") or 8)
# E se a página nunca abrir — navegador que não subiu, clique que se perdeu — o
# servidor não pode ficar de pé para sempre esperando ninguém.
VIGIA_ESPERA = float(os.environ.get("MEOW_APP_ESPERA") or 120)
# De quanto em quanto tempo o pulso escreve.
PULSO_BATIDA = 15.0

_PULSOS = {"abertos": 0, "houve": False, "zerou_em": None}
_PULSO_TRAVA = threading.Lock()


def _pulso_entra():
    with _PULSO_TRAVA:
        _PULSOS["abertos"] += 1
        _PULSOS["houve"] = True
        _PULSOS["zerou_em"] = None


def _pulso_sai():
    with _PULSO_TRAVA:
        _PULSOS["abertos"] = max(0, _PULSOS["abertos"] - 1)
        if _PULSOS["abertos"] == 0:
            _PULSOS["zerou_em"] = time.time()


def _ha_trabalho_vivo():
    return any(t.vivo() for t in list(TRABALHOS.values()))


def _vigia(servidor, comeco):
    """Sai quando a página que abriu este servidor some da tela."""
    while True:
        time.sleep(1.0)
        with _PULSO_TRAVA:
            abertos = _PULSOS["abertos"]
            houve = _PULSOS["houve"]
            zerou = _PULSOS["zerou_em"]
        agora = time.time()
        if not houve:
            if agora - comeco > VIGIA_ESPERA:
                motivo = "a página não abriu em %d s" % VIGIA_ESPERA
                break
            continue
        if abertos > 0 or zerou is None or agora - zerou < VIGIA_CARENCIA:
            continue
        # A ORDEM IMPORTA: só depois de decidir que a janela sumiu é que se
        # pergunta pelo trabalho. Perguntar antes faria o servidor ficar de pé
        # durante toda uma instalação com a página aberta, o que é o normal.
        if _ha_trabalho_vivo():
            continue
        motivo = "a janela foi fechada"
        break
    sys.stderr.write("painel: %s — encerrando.\n" % motivo)
    sys.stderr.flush()
    # De outra thread, que é a única forma suportada: o `serve_forever` está
    # bloqueado na thread principal e é ele quem tem de voltar.
    servidor.shutdown()


def _aquecer():
    """A conta mais cara do esquema frio, feita antes de a página pedir.

    A PRIMEIRA CARGA ESPERAVA O ESQUEMA FRIO — 10/10/2026, P77 (achado 22).
    Medido na casa de brinquedo: o primeiro `_dados_esquema` custa 1,0 s e os
    seguintes 0,15 s; 0,72 s daquele segundo é o `_acentos_que_aplicam`, que
    roda o `derivar_acento.py` num processo filho e guarda a resposta. Esta
    thread a faz ao subir, enquanto o navegador ainda abre: quando o pedido
    chega, a resposta já está guardada. Falhar aqui não muda nada — o pedido
    faz a conta como sempre fez."""
    try:
        _acentos_que_aplicam(ler_esquema())
    except Exception:
        pass


def main():
    # O esquema frio começa a aquecer antes de a URL sair — ver `_aquecer`.
    threading.Thread(target=_aquecer, daemon=True).start()
    # Os operários de prévia sobem ANTES do servidor: o primeiro `/api/previas`
    # pode chegar no mesmo segundo em que a página abre, e uma fila sem ninguém
    # do outro lado deixaria as miniaturas eternamente "gerando".
    for _ in range(3):
        threading.Thread(target=_operario, daemon=True).start()
    servidor = ThreadingHTTPServer(("127.0.0.1", 0), Manipulador)
    servidor.daemon_threads = True
    porta = servidor.server_address[1]
    if VIGIA_LIGADO:
        threading.Thread(target=_vigia, args=(servidor, time.time()),
                         daemon=True).start()
    # A ÚNICA saída em stdout, e ela é a interface com o `run.sh`: uma linha, a
    # URL inteira com o token. O `run.sh` a lê, abre o navegador nela e para de
    # olhar. Imprimir mais coisa aqui quebraria o `read` do outro lado.
    sys.stdout.write("http://127.0.0.1:%d/?t=%s\n" % (porta, TOKEN))
    sys.stdout.flush()
    try:
        servidor.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        # Um `./install.sh` sobrevivendo ao fechar da janela seria escrita no
        # disco dela sem ninguém olhando. Ao sair, todo trabalho vivo é parado.
        for trabalho in TRABALHOS.values():
            if trabalho.vivo():
                trabalho.parar()
        # O `app.pid` é do `run.sh`, e quem o apaga é o `--parar` dele.
        try:
            arquivo_pid = os.path.join(ESTADO, "app.pid")
            with open(arquivo_pid, "r", encoding="utf-8") as fh:
                if fh.read().strip() == str(os.getpid()):
                    os.unlink(arquivo_pid)
        except (OSError, ValueError):
            pass
        try:
            os.unlink(os.path.join(ESTADO, "paineis", "%d.pid" % os.getpid()))
        except OSError:
            pass
        servidor.server_close()


if __name__ == "__main__":
    # `--onde` não sobe servidor nenhum: responde e sai — ver `onde_na_tela`. A
    # linha de URL do `main` é a interface com o `run.sh`, e esta porta não
    # passa perto dela.
    # Com o número errado de argumentos também não sobe: quem pergunta onde fica um
    # botão não pediu servidor na casa real.
    if len(sys.argv) > 1 and sys.argv[1] == "--onde":
        if len(sys.argv) != 3:
            sys.stderr.write("uso: servidor.py --onde <ação, pendência, chave ou inicio>\n")
            sys.exit(2)
        frase = onde_na_tela(sys.argv[2])
        sys.stdout.write(frase + "\n" if frase else "")
        sys.exit(0 if frase else 1)
    main()

#!/usr/bin/env python3
# app/servidor.py — o backend da página de configuração do MeowSystem.
#
# ESTE ARQUIVO NÃO É UM SERVIDOR WEB. É UMA PONTE ENTRE UMA PÁGINA LOCAL E A CLI
# QUE JÁ EXISTE, e a diferença importa em cada decisão abaixo: ele não decide
# nada sobre o tema, não sabe o que é um flavor, não conhece uma única chave pelo
# nome. Tudo o que ele sabe fazer é (a) LER o `meow.conf.exemplo` e o
# `meow.conf` dela, (b) chamar `meow_conf_definir` para escrever, e (c) rodar
# comandos de uma lista fechada, mostrando a saída ao vivo.
#
# ─────────────────────────────────────────────────────────────────────────────
# POR QUE O CATÁLOGO É DERIVADO, E NUNCA DIGITADO — A ARMADILHA Nº 3
# ─────────────────────────────────────────────────────────────────────────────
# A tentação óbvia era escrever aqui uma lista das ~90 chaves com rótulo, tipo e
# ajuda bonitinhos. Seria a SEGUNDA lista de chaves do projeto, e o `bin/meow` já
# pagou essa conta duas vezes (11/08 e 25/08/2026): chave nova nasce morta,
# ninguém percebe, e o pior sintoma possível — a tela dizendo "confere" sobre
# algo que nunca foi conferido.
#
# Então o esquema sai do `meow.conf.exemplo`, com EXATAMENTE as mesmas regras que
# o `wiz_ler_esquema` do `bin/meow` usa (a ordem, a seção `# --- Nome`, o bloco de
# comentário colado acima da chave, o `[essencial]`, e o `a | b | c` do
# comentário virando lista de opções). Chave nova no exemplo aparece na página
# sozinha; chave que sair de lá some da página sozinha. Se as duas leituras
# divergirem um dia, é bug — e `tests/app.sh` compara as duas listas (nome, valor
# padrão e opções, chave a chave) justamente para que a divergência apareça no
# mesmo dia, e não meses depois. Em 01/09/2026 as 95 chaves leem igual dos dois
# lados; o teste recorta as funções do `bin/meow` VIVO com `sed`, então ele
# compara com o wizard de verdade, e não com uma cópia dele.
#
# ─────────────────────────────────────────────────────────────────────────────
# QUEM ESCREVE NO MEOW.CONF É O `meow_conf_definir`, EM BASH, SEMPRE
# ─────────────────────────────────────────────────────────────────────────────
# Python tem `re.sub` e seria uma linha. Seria também a terceira rotina de
# escrita na mesma chave — e o cabeçalho de `lib/comum.sh` conta o que aconteceu
# quando existiram duas: uma trocava a PRIMEIRA ocorrência enquanto o shell
# obedece a ÚLTIMA, e o `meow configurar` gravava `2h` mostrando o diff certo
# enquanto o valor em vigor continuava `1d`, sem nada acusar.
#
# Aqui a escrita é literalmente:
#     bash -c '. "$1/lib/comum.sh"; meow_conf_definir "$2" "$3"' _ RAIZ CHAVE VALOR
# Medido em 01/09/2026: devolve 0 quando a chave já estava com aquele valor e 1
# quando escreveu — o mesmo contrato de `meow_escrever`, que é o que a página usa
# para dizer "já estava assim" em vez de fingir que gravou.
#
# ─────────────────────────────────────────────────────────────────────────────
# A SUPERFÍCIE DE REDE, E POR QUE ELA É TÃO PEQUENA
# ─────────────────────────────────────────────────────────────────────────────
#   - escuta em 127.0.0.1 e em porta EFÊMERA (`porta 0`, o kernel escolhe). Não
#     há porta fixa para alguém adivinhar, e não há bind em 0.0.0.0 nenhum;
#   - todo pedido carrega um token de sessão sorteado a cada execução
#     (`secrets.token_urlsafe`), comparado com `hmac.compare_digest`;
#   - o cabeçalho `Host` é conferido contra o par (127.0.0.1|localhost):<porta>.
#     Sem isso, um site aberto noutra aba poderia resolver um domínio dele para
#     127.0.0.1 e falar com este processo (DNS rebinding) — o token já barraria,
#     mas duas trancas custam seis linhas;
#   - `Origin`, quando vem, tem de bater. Página local não manda `Origin` em GET;
#     um navegador atacante manda, e é justamente ele que queremos recusar;
#   - NENHUM comando vem da página como texto. A página manda um `id` de ação, e
#     o `id` é chave de um dicionário fechado aqui embaixo. O argumento, quando
#     existe, é conferido contra uma lista montada DO DISCO (as capturas que
#     existem, os gatos que existem) — nunca contra o que o navegador mandou.
#
# ─────────────────────────────────────────────────────────────────────────────
# O SUDO: O QUE FOI MEDIDO NESTA MÁQUINA EM 01/09/2026, E O QUE MUDOU POR CAUSA
# ─────────────────────────────────────────────────────────────────────────────
# O plano inicial era confortável e ERRADO: "o backend não tem tty, então todo
# `sudo` falha sozinho e nada privilegiado roda daqui". Medido:
#
#     $ sudo -n -v ; echo $?
#     0
#     $ sudo -n -l | grep timestamp
#     ... timestamp_type=global, timestamp_timeout=60
#
# `timestamp_type=global` quer dizer que o cache do sudo NÃO é por terminal: um
# `sudo` que ela digitou em QUALQUER janela nos últimos 60 minutos faz `sudo -n`
# devolver 0 aqui dentro, sem tty e sem perguntar nada. Ou seja, o `./install.sh`
# disparado por um clique nesta página PODE, sim, mexer em `/usr/share` — se a
# hora for aquela, e sem nada na tela avisando.
#
# Por isso as ações que podem atravessar o `sudo` são marcadas `sudo: True`, a
# página as mostra com o aviso ANTES do clique, e elas exigem uma confirmação
# escrita. Nenhuma senha é pedida, guardada, lida ou passada adiante em ponto
# nenhum deste arquivo — o que existe é o cache que já era dela, e o que muda é
# que agora está DITO.
#
# ─────────────────────────────────────────────────────────────────────────────
# UM TRABALHO POR VEZ, E O MOTIVO É O CADEADO
# ─────────────────────────────────────────────────────────────────────────────
# `meow doctor --consertar` e `./install.sh` pegam o `flock` de
# `~/.local/state/meowsystem/lock` (regra 10 do contrato). Dois cliques rápidos
# dariam "outro meow está rodando" com o culpado sendo a própria página. Então o
# servidor recusa começar um segundo trabalho enquanto o primeiro vive, e diz
# qual está correndo.
"""Backend local do painel de configuração visual do MeowSystem."""

import base64
import datetime
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
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs, quote

# --- 1. onde está o repositório ---------------------------------------------
# Mesma pergunta que o `bin/meow` responde em quatro passos, e aqui bastam dois:
# este arquivo mora DENTRO do clone (`app/servidor.py`), então o diretório acima
# é a raiz. `MEOW_RAIZ` continua vencendo, porque é o que os testes usam.
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
# O mapa dos jogos que ficam fora do lançador. Constante e não literal
# espalhado: as três funções da seção "Jogos" o leem e uma delas o escreve,
# e um caminho digitado três vezes é como duas delas passam a olhar
# arquivos diferentes no dia em que ele mudar de lugar.
MAPA_JOGOS = os.path.join(RAIZ, "assets", "icones", "jogos-fora.map")
CONF_PADRAO = os.environ.get("MEOW_CONF_PADRAO") or os.path.join(RAIZ, "meow.conf.exemplo")
CONF = os.environ.get("MEOW_CONF") or os.path.expanduser("~/.config/meow/meow.conf")
PALETA = os.path.join(RAIZ, "assets", "paleta", "catppuccin.json")
FOLHAS = os.path.join(RAIZ, "docs", "folhas")
# O mesmo diretório que `MEOW_ESTADO` do `lib/comum.sh` — e ele vem por ambiente
# quando o `run.sh` é quem chama, para as duas metades nunca discordarem sobre
# onde mora o `app.pid`.
ESTADO = os.environ.get("MEOW_ESTADO") or os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "meowsystem",
)

TOKEN = secrets.token_urlsafe(32)


# --- 2. o esquema, lido do meow.conf.exemplo --------------------------------
# As quatro regras abaixo são a tradução literal do `wiz_ler_esquema`,
# `wiz_valor_da_linha`, `wiz_comentario_da_linha` e `wiz_opcoes` do `bin/meow`.
# Onde o bash e o Python discordarem, o bash é que está certo: ele é quem a
# pessoa vê no terminal, e duas verdades sobre a mesma chave é o defeito que este
# projeto mais persegue.

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
        `assets/gatos/`) e por isso pega sozinha a quinta chave que nascer assim
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
    # A TABELA SÓ É DESTA CHAVE SE O VALOR DE FÁBRICA DELA ESTIVER NA TABELA.
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
# página até 01/09/2026, quando ela apontou:
#
#   "Como o gato do dock e do terminal são escolhidos e tá escrito horas. Cara,
#    era pra ter o que de opção ali? Se era pra ter opção pq não tem botões de
#    escolha?"
#
# O `LOGO_MODO` TEM três opções, e o `meow.conf.exemplo` as lista — mas numa
# tabela indentada, não em `a | b | c`:
#
#   #   hora     (padrão) LOGO_NOITE de noite, LOGO_DIA de dia...
#   #   rotacao  gira pelo acervo ao encerrar a sessão...
#   #   fixo     LOGO= vence sempre; nada gira, nada segue relógio.
#
# Como só a forma com barras era reconhecida, a chave caía em CAMPO DE TEXTO e
# ela tinha de digitar `hora` de cabeça — numa página cujo motivo de existir é
# não precisar decorar valor.
#
# A regra é derivada da FORMA, não de uma lista de chaves: três ou mais linhas
# seguidas do comentário, todas indentadas igual, todas começando por uma
# palavra curta em minúsculas seguida de dois ou mais espaços e uma explicação.
# Isso é uma tabela de opções em qualquer arquivo, e é assim que este projeto
# escreve as dele. Hoje pega `LOGO_MODO` e `FASTFETCH_LOGO_MODO`; amanhã pega a
# próxima que nascer com a mesma cara, sem ninguém vir aqui.
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


# A TERCEIRA FORMA DE LISTAR OPÇÕES: ELAS NÃO ESTÃO ESCRITAS, ELAS SÃO O DISCO
# ─────────────────────────────────────────────────────────────────────────────
# Havia aqui, até 01/09/2026, uma lista de quatro nomes de chave — as do gato —
# e ela era a única lista fixa do arquivo. A auditoria daquele dia mostrou o
# preço de a regra não ser geral: `ICONES_BASE` (um TEMA DE ÍCONES INSTALADO) e
# `CURSOR` (um PONTEIRO INSTALADO) caíam em campo de texto, e ela tinha de
# digitar de cabeça o nome de uma pasta — numa página cujo motivo de existir é
# não precisar decorar valor.
#
# A regra passa a ser a mesma do resto do arquivo: perguntar ao CONTEÚDO. O
# comentário da chave diz de onde os valores vêm ("o acervo é a pasta
# `assets/gatos/`", "o nome do tema de ícones", "o PONTEIRO"), e o gatilho é
# esse texto. Chave nova cujo comentário cite o mesmo acervo ganha os botões
# sozinha.
#
# A GUARDA É O VALOR DE FÁBRICA, e é ela que faz uma regra de texto largo não
# atropelar as vizinhas. Três exemplos medidos nesta árvore:
#
#   LOGO_ROTACAO   o bloco dele cita `assets/gatos/*.svg` (explica o acervo da
#                  rotação) e o padrão é `nao` — que não é gato nenhum. Fica de
#                  fora, e continua com os dois botões sim/não.
#   CURSOR_VERSAO  herda o bloco do `CURSOR`, que fala de ponteiro o tempo
#                  todo; o padrão é `v2.0.0`, que não é ponteiro instalado.
#   TERMINAL_CURSOR  a palavra "cursor" está no nome e no bloco; o padrão é
#                  `accent`, e a lista `accent | port` do texto continua valendo.
#
# É o MESMO critério que já governa a tabela indentada ("a tabela só é desta
# chave se o valor de fábrica dela estiver na tabela"), aplicado a uma lista que
# mora no disco em vez de no comentário.
#
# POR ISSO O GATILHO PODE SER LARGO, e é de propósito que ele seja: a palavra
# "ícone" aparece em dezenas de blocos deste arquivo, e o que decide não é ela —
# é o disco. Um gatilho estreito ("tema de ícones", exatamente assim) quebraria
# no dia em que alguém reescrevesse o comentário para dizer a mesma coisa com
# outras palavras, e o sintoma seria a chave voltando a ser campo de texto sem
# ninguém entender por quê. Largo + guarda apertada envelhece melhor que
# estreito + guarda apertada.
#
# A TERCEIRA COLUNA É "ESTA LISTA É UMA CERCA?", E ELA SEPARA DOIS ACERVOS QUE
# PARECEM IGUAIS
#   `assets/gatos/` é uma pasta que ESTA PÁGINA sabe encher: o botão "Adicionar
#   gato" manda um `.svg` para lá, e o próprio `meow.conf.exemplo` avisa que
#   "qualquer outro valor é tratado como caminho de um SVG seu". Recusar na
#   escrita um nome que ainda não está na pasta seria a página proibindo o que a
#   CLI aceita — o pior lado para errar.
#
#   Um tema de ícones e um ponteiro são o oposto: têm de JÁ estar instalados no
#   sistema, e esta página não instala nem um nem outro. Um valor que não esteja
#   lá não é "ainda não chegou", é erro — e o erro aparece longe daqui e mudo
#   (o `construir_pastas.sh:135` sai com SEM_DEPENDENCIA; o `cursor.sh` vai
#   tentar BAIXAR `<valor>-cursors.zip` e falhar). Aí a lista vira cerca, e o
#   `/api/definir` recusa na hora, com a frase que diz o que se esperava.
FONTES_DO_DISCO = (
    (re.compile(r"assets/gatos/"), "gatos", False),
    (re.compile(r"[íi]cones?\b", re.I), "temas_icones", True),
    (re.compile(r"ponteiro|cursor", re.I), "cursores", True),
)

# "Vazio = herda LOGO_DIA": uma chave que declara herdar outra oferece as MESMAS
# opções que a outra oferece. É o que devolve os botões de gato às
# `FASTFETCH_LOGO_DIA/NOITE`, cujo bloco de comentário é o da vizinha `_MODO` e
# por isso não cita acervo nenhum — quem cita é a chave de quem elas herdam.
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
    # A TABELA INDENTADA SÓ DESCREVE A CHAVE SE O VALOR DE FÁBRICA ESTIVER NELA.
    #   `FASTFETCH_LOGO_MODO` traz a tabela `espelho / hora / fixo` e nasce
    #   `espelho` — a tabela é dele. As duas chaves logo abaixo, `_DIA` e
    #   `_NOITE`, herdam aquele comentário porque não têm um próprio, e nascem
    #   VAZIAS: ganhavam três botões de modo para escolher um NOME DE GATO.
    #   Pego pelo `tests/app.sh`, que compara o que o painel lê com o que o
    #   wizard lê. O critério é o mesmo nos dois, e não depende de saber quem
    #   herdou o quê — só de olhar se o valor de fábrica é uma das opções.
    #   `padrao or ""` e não `padrao and ...`: as duas chaves do caso nascem
    #   VAZIAS, e uma condição que exige padrão preenchido as deixaria passar —
    #   que era exatamente o defeito.
    if opcoes and (padrao or "") not in opcoes and _e_tabela(chave, ajuda, inline):
        return []
    if not opcoes and padrao in ("sim", "nao"):
        return ["sim", "nao"]
    return opcoes


RE_DURACAO = re.compile(r"^\d+(?:[.,]\d+)?[smhd]$")


# AS CHAVES QUE ANULAM OUTRAS, DECLARADAS EM UM LUGAR SÓ.
#   Isto é uma lista, e listas envelhecem — mas esta descreve uma RELAÇÃO entre
#   chaves que só existe dentro dos scripts (`logo.sh:113-119` e `:432-449`), e
#   não há como derivá-la do texto do `meow.conf.exemplo` sem inventar. O que dá
#   para exigir é que ela seja pequena, explicada, e conferida: cada entrada diz
#   a condição em que a chave dominante vence, e o teste `tests/app.sh` confere
#   que as chaves citadas existem.
DOMINIOS = {
    "LOGO_ROTACAO": {
        "chave": "LOGO_MODO",
        "quando": lambda v: bool(v) and v != "rotacao",
        "porque": "Ela só liga a rotação quando o gato é escolhido girando — "
                  "hoje não tem efeito nenhum.",
    },
    "LOGO": {
        "chave": "LOGO_MODO",
        "quando": lambda v: v == "hora",
        "porque": "Por horário quem escolhe são os gatos de dia e de noite; "
                  "esta só entra quando um daqueles dois não está na lista.",
    },
    "FASTFETCH_LOGO_GATO": {
        "chave": "FASTFETCH_LOGO_MODO",
        "quando": lambda v: bool(v) and v != "fixo",
        "porque": "Ela só vale com a escolha em \u201cfixo\u201d; nos outros "
                  "modos o gato do terminal segue o do dock.",
    },
}


def _valor_vivo(chave):
    """O valor que a chave tem NA MÁQUINA agora (o conf dela, ou o exemplo)."""
    return (valores_brutos() or {}).get(chave, "")


# O estado que o applet do modo de leitura guarda, chave a chave. A ligação é
# derivada do NOME (`LEITURA_TEMPERATURA` -> `leitura_temperatura`), e não uma
# lista: a próxima chave dessa família nasce coberta.
CONF_COMP = os.path.expanduser("~/.config/cosmic/com.system76.CosmicComp/v1")


def _valendo_agora(chave):
    if not chave.startswith("LEITURA_"):
        return None
    arq = os.path.join(CONF_COMP, chave.lower())
    try:
        with open(arq, encoding="utf-8") as fh:
            valor = fh.read().strip().strip('"')
    except OSError:
        return None
    return valor or None


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


def _dominada_por(chave):
    regra = DOMINIOS.get(chave)
    if not regra:
        return None
    valor = _valor_vivo(regra["chave"])
    if not regra["quando"](valor):
        return None
    # O TÍTULO VAI JUNTO, e é o que a página mostra. O aviso dizia "Quem manda é
    # «LOGO_MODO»" — o nome da variável, que quem lê a tela não precisa saber e
    # que não aparece em lugar nenhum do menu para ela procurar. Agora diz "Quem
    # manda é «Como o gato é escolhido»", que é o cartão ao lado.
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

    # UMA LISTA DE DURAÇÕES É EXEMPLO, NÃO CERCA — e isso é regressão medida.
    #   `WALLPAPER_INTERVALO` traz `# 30s | 5m | 2h`, e a validação nova passou a
    #   recusar `10m`, `1h` e `45s`. Mas o `bin/meow` aceita qualquer duração
    #   (ele converte com `segundos_de`), e o `meow.conf` VIVO dela já tem
    #   `WALLPAPER_INTERVALO="5m"` ao lado de outras chaves com valores fora da
    #   lista. Três números com unidade não são um `case` do shell: são exemplos
    #   de escala. Um revisor pegou isto por HTTP, com 400 na cara.
    #   A regra é da FORMA: se TODOS os tokens são duração, a lista sugere e não
    #   proíbe — quem confere o valor é a forma de duração, logo abaixo.
    if opcoes and all(RE_DURACAO.match(o) for o in opcoes):
        return []
    return opcoes


# A FORMA DO NÚMERO, DECLARADA PELO PRÓPRIO VALOR DE FÁBRICA
# ─────────────────────────────────────────────────────────────────────────────
# Nenhuma chave deste arquivo diz "sou um inteiro". O que ela diz é `="40"`,
# `="0.85"`, `="1d"` — e isso já é a declaração inteira, escrita no lugar onde
# ninguém esquece de atualizá-la. É a mesma regra do `sim`/`nao` de
# `_opcoes_finais`, aplicada a número em vez de a booleano.
#
# Serve para duas coisas: dizer à página que controle desenhar, e dar ao
# `/api/definir` uma cerca (ver `validar_valor`) — porque até 01/09/2026 a
# palavra `abc` entrava em `BACKUPS_MANTIDOS` sem uma queixa, e quem descobria
# era o `meow doctor --consertar` das 05:00, todo dia, longe da tela.
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
    # DEPOIS O PRIMEIRO — e ela sai de como este arquivo é escrito, não de gosto:
    # `LEITURA_TEMPERATURA` declara `1000–6500 K` no comentário de linha,
    # `MIDIA_LARGURA` declara `80..900` na última linha antes da chave, e o resto
    # abre o bloco com a definição. O miolo é onde mora a prosa de medição, e é
    # de lá que vinham todos os falsos positivos.
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
        # Uma faixa de dois dígitos costuma ser um horário ou uma data no meio da
        # prosa ("de 10/08 a 11/08"), não um controle. O piso de amplitude tira o
        # falso positivo sem precisar de lista de exceção.
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
        # UMA PALAVRA COMO PADRÃO NÃO MATA A FAIXA QUANDO A PALAVRA É UMA DAS
        # OPÇÕES DECLARADAS — 02/09/2026.
        #   `MIDIA_FONTE` nasce `auto` e o arquivo crava, com todas as letras,
        #   "A UNIDADE É PIXEL, E A FAIXA VAI DE 6 A 48". Como `auto` não é
        #   número, a faixa era descartada, e a chave virava campo de texto sem
        #   cerca nenhuma: a validação mediu um `999` entrando calado.
        #   A guarda que existia continua valendo (o `sim` do `JANELAS_TILING`
        #   segue matando a faixa), porque ali a palavra NÃO é uma opção
        #   declarada — é só o valor de um interruptor.
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
    # estar colada na última linha do bloco, sem branco antes, e entraria no meio
    # da frase se fosse filtrada depois.
    #
    # O QUE ESTÁ NO PARÊNTESE FICA, E É O CASO DO `MODO`
    #   A linha dele é `# escuro | claro | auto   (auto alterna Mocha/Latte por
    #   horário)`, e o `MODO` não tem outra linha de comentário — jogá-la fora
    #   inteira deixaria o cartão sem uma palavra de explicação. Jogar a linha
    #   inteira NA frase era o outro extremo, e é o que estava na tela: três
    #   botões `escuro` `claro` `auto` e, logo abaixo, o texto "escuro | claro |
    #   auto" repetindo-os. O aparte entre parênteses é a única parte da linha
    #   que o controle não desenha — então é ela que sobrevive.
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
        # nenhuma...`) não é descartado: só se descarta o parágrafo cuja PRIMEIRA
        # oração inteira é grito. Senão perderíamos a ajuda de meia dúzia de
        # chaves cuja única explicação vem logo depois dos dois-pontos.
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
    # lista de opções. O `WALLPAPER_ORDEM` só tem `# aleatoria | alfabetica`, e
    # repeti-lo como frase embaixo dos dois botões `aleatoria` `alfabetica` é
    # dizer duas vezes a mesma coisa. Sem frase, o cartão fica com o nome, o
    # controle e o padrão, que já é a informação inteira.
    return "" if _e_linha_de_opcoes(inline) else inline


def _capturas_no_disco():
    """Os nomes das capturas de tema que existem — `mocha-mauve`, `latte-mauve`…

    A página usa para avisar ANTES: `FLAVOR` × `ACCENT` dão 48 combinações e só
    as capturadas instalam. Sem isto ela escolhia, salvava, rodava o instalador
    e só então levava o não. (E o `bin/meow` lia isso de `state/tema/`, um
    caminho que a reorganização deixou para trás — corrigido no mesmo dia.)
    """
    pasta = os.path.join(RAIZ, "assets", "temas", "capturados")
    try:
        return sorted(n for n in os.listdir(pasta)
                      if os.path.isdir(os.path.join(pasta, n)))
    except OSError:
        return []


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
                # DUAS ALTURAS DE TÍTULO, E O ARQUIVO JÁ AS DISTINGUE SOZINHO
                #   Os seis títulos de assunto estão em Capitulares (`Aparência`,
                #   `Ícones`, `Wallpaper`, `Apps`, `Automação`, `Terminal`); os
                #   outros treze estão em CAIXA ALTA (`A FORMA DO PAINEL E DO
                #   DOCK`). A convenção é do arquivo, não minha — e é o que
                #   permite uma navegação de seis itens em vez de dezenove.
                #
                #   O `wiz_ler_esquema` do bin/meow não faz esta distinção, e não
                #   precisa: o wizard é uma pergunta por vez, em fila, e um
                #   cabeçalho a mais na tela não atrapalha ninguém. Uma página
                #   tem de decidir onde a chave MORA, e aí a diferença conta.
                #
                #   Herdar a seção anterior quando só o subtítulo muda é o que faz
                #   `FORMA_*` continuar em "Wallpaper": o `# --- Wallpaper` está
                #   no arquivo ANTES do bloco da forma, e as chaves de wallpaper
                #   de verdade vêm bem depois. É a ordem do arquivo que está
                #   torta, não a leitura — e o subtítulo, que a página mostra,
                #   diz de qual assunto a chave é de fato.
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

        # AS DUAS MARCAS SAEM DO BLOCO ANTES DE QUALQUER OUTRA COISA — 06/09/2026
        #   `# @ ` é o título do controle e `# > ` é a frase de baixo. As duas
        #   são texto escrito, não derivado, e o porquê está no cabeçalho do
        #   `meow.conf.exemplo`.
        #
        #   ELAS TÊM DE SAIR ANTES DO `colada`, e isso não é ordem por acaso: a
        #   herança de comentário entre irmãs (`NOITE_INICIO`/`NOITE_FIM`, as
        #   dezoito `FORMA_*`) exige bloco VAZIO. Com as marcas dentro, o bloco
        #   nunca é vazio, a herança nunca dispara, e as irmãs perdem a
        #   explicação longa que dividem — a lacuna que 01/09/2026 fechou
        #   voltaria com outro nome.
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

        # CHAVE IRMÃ HERDA O COMENTÁRIO DA PRIMEIRA — 01/09/2026
        #   Dezoito das 95 chaves ficavam sem UMA palavra de ajuda, e não é
        #   descuido do arquivo: ele escreve os pares e as famílias sob um
        #   comentário só, coladas, sem linha em branco no meio —
        #       NOITE_INICIO=""
        #       NOITE_FIM=""
        #   e as oito `FORMA_*`, e as duas `VIDRO_OPACIDADE_*`, e o
        #   `MIDIA_COR_TITULO`/`MIDIA_COR_ARTISTA`. O bloco explica as duas (ou as
        #   oito) de uma vez, porque é uma decisão só.
        #
        #   O wizard do `bin/meow` tem a mesma lacuna e ela custa pouco lá: as
        #   perguntas vêm em fila, e quem acabou de ler a ajuda da irmã ainda a
        #   tem na tela. Numa página as chaves aparecem lado a lado e cada cartão
        #   se explica sozinho — ou não se explica.
        #
        #   "Colada" é literal: só herda a chave que vem IMEDIATAMENTE depois de
        #   outra, sem branco e sem comentário entre elas. Uma linha em branco no
        #   meio quebra a herança, que é exatamente o que o arquivo quer dizer
        #   quando põe uma.
        herdada = False
        if not bloco and colada and itens:
            ajuda = itens[-1]["ajuda"]
            herdada = True
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
            # `vazio` NÃO É UM VALOR, É A AUSÊNCIA DELE — e escrevê-lo seria um bug
            #   Três chaves documentam `nao | sim | vazio (= não toca)`. Lido ao pé
            #   da letra, o `vazio` vira mais um token da lista, e um clique nele
            #   gravaria `RELOGIO_SEGUNDOS="vazio"` — que não é `sim`, não é `nao`,
            #   e cairia no `*)` de qualquer `case` do projeto sem nada avisar.
            #   Aqui ele sai da lista de opções e vira o terceiro estado do
            #   controle, que é o que a prosa do arquivo quer dizer.
            "opcoes": _opcoes_finais(chave, ajuda, inline, _valor_da_linha(linha), herdada),
            "faixa": _faixa_confere(_faixa(ajuda, inline), _valor_da_linha(linha)),
            # A forma do número, quando há uma. Sai do VALOR DE FÁBRICA, que é
            # onde o arquivo já a declara sem precisar de uma palavra a mais —
            # ver `FORMAS_NUMERO`. É o que permite à página desenhar um campo
            # numérico em vez de um campo de texto, e ao `/api/definir` recusar
            # `abc` numa chave que conta backups.
            "tipo_numero": _forma_de_numero(_valor_da_linha(linha)),
            # Que prévia visual esta chave merece. Deduzido do conteúdo dela —
            # ver `_tipo_de_previa`, que explica por que não há lista aqui.
            "previa": _tipo_de_previa(
                chave,
                _opcoes_finais(chave, ajuda, inline, _valor_da_linha(linha), herdada),
                _faixa_confere(_faixa(ajuda, inline), _valor_da_linha(linha)),
                _valor_da_linha(linha)),
            # QUAL CHAVE ESTÁ ANULANDO ESTA, se alguma — 02/09/2026.
            #   A validação achou dois interruptores vivos e inertes:
            #   `LOGO_ROTACAO` (que só vale com `LOGO_MODO` vazio) e `LOGO`
            #   (que em `LOGO_MODO="hora"` perde para `LOGO_DIA`/`LOGO_NOITE`).
            #   A página não tinha como saber: quem lê a conf dela é este
            #   arquivo. O campo diz a chave que manda, o valor que ela tem
            #   HOJE, e a frase que explica — a página só desenha.
            "dominada_por": _dominada_por(chave),
            # O QUE ESTÁ VALENDO AGORA, quando não é o conf que manda.
            #   As chaves `LEITURA_*` são o padrão de FÁBRICA: quem decide o
            #   quanto é o que o applet guardou quando ela soltou o slider —
            #   está escrito no próprio meow.conf.exemplo, e o cartão mostrava
            #   o número do arquivo como se ele mandasse. A validação mediu:
            #   conf diz 3500, a máquina está em 4700.
            "valendo_agora": _valendo_agora(chave),
            "ajuda_herdada": herdada,
            "essencial": "[essencial]" in ajuda,
            # Lista separada por vírgula: a regra é o que o comentário DIZ, não uma
            # lista de nomes de chave. `APPS_ATIVOS` e `AUTOSTART_BLOQUEADOS` dizem
            # "vírgula-separado"/"separada por vírgula"; a `WALLPAPER_FONTES_DELA`
            # diz "separados por `:`", e por isso ela não cai aqui — o separador
            # dela é outro, e tratá-los como um só corromperia caminho com vírgula.
            "lista": bool(re.search(r"separad[ao]s? por v[ií]rgula|v[ií]rgula[- ]separad", ajuda, re.I)),
            "lista_pathsep": bool(re.search(r"separados por `?:`?", ajuda)),
            # Horário: o comentário declara `HH:MM`, OU o valor já é um horário.
            # As duas metades são precisas: `LEITURA_HORARIO_INICIO` diz `HH:MM`
            # no comentário e a `NOITE_INICIO` não diz (ela fala em "18:00-07:00"
            # no meio da prosa) — sem o teste do VALOR, aquelas duas nasceriam
            # como campo de texto livre e a página perderia justamente o controle
            # que evita ela digitar `18h`.
            "horario": ("HH:MM" in (ajuda + inline)
                        or bool(re.fullmatch(r"\d{1,2}:\d{2}", _valor_da_linha(linha)))
                        # Chave que nasce VAZIA e cujo comentário cita um horário
                        # literal LOGO NA ABERTURA: são a NOITE_INICIO e a
                        # NOITE_FIM, que falam em "18:00-07:00" no meio da frase e
                        # nunca escrevem `HH:MM`.
                        #
                        # O "logo na abertura" é o mesmo corte da faixa numérica, e
                        # pelo mesmo motivo medido: varrendo o bloco inteiro, as
                        # oito `FORMA_*` viravam campo de horário — o comentário
                        # delas conta que "o `meow doctor --consertar` roda sozinho
                        # às 05:00", e `05:00` é um horário como qualquer outro para
                        # uma expressão regular. Horário que é o VALOR da chave se
                        # anuncia na primeira frase; horário citado numa medição
                        # mora no meio do texto.
                        or (_valor_da_linha(linha) == ""
                            and bool(re.search(r"\b\d{1,2}:\d{2}\b",
                                               (_paragrafos(ajuda) or [""])[0])))),
            # "vazio = não toca" é um TERCEIRO estado, e o arquivo o declara com
            # todas as letras em nove blocos. Sem reconhecê-lo, a página ofereceria
            # sim/não onde existe sim/não/não-mexa — e apagar essa terceira opção
            # é exatamente como a opacidade do painel virou briga de três meses.
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
def _gatos():
    """O acervo `assets/gatos/`, que é a configuração — soltou um .svg, entrou."""
    pasta = os.path.join(RAIZ, "assets", "gatos")
    try:
        nomes = sorted(
            os.path.splitext(f)[0] for f in os.listdir(pasta)
            if f.endswith(".svg") and not f.endswith("-symbolic.svg")
        )
    except OSError:
        return []
    return nomes


def _capturas():
    """As capturas de tema que EXISTEM — é o que `meow tema <x>` aceita."""
    pasta = os.path.join(RAIZ, "assets", "temas", "capturados")
    try:
        return sorted(d for d in os.listdir(pasta)
                      if os.path.isdir(os.path.join(pasta, d)))
    except OSError:
        return []


# --- 3b. os acervos que moram no DISCO, e não no texto -----------------------
#
# O `_gatos()` acima é o modelo: a lista não está escrita em lugar nenhum, ela É
# a pasta. Os quatro provedores abaixo respondem à mesma pergunta para os temas
# de ícones, os ponteiros e as duas pastas de papel de parede — e nasceram
# porque a auditoria de 01/09/2026 mediu o preço de não os ter:
#
#   · `ICONES_BASE` era CAMPO DE TEXTO. Digitar `Nao-Existe-Nenhum` era aceito
#     sem uma palavra, e o `construir_pastas.sh:135` só reclamava depois, saindo
#     com SEM_DEPENDENCIA — longe da tela onde o erro foi cometido.
#   · `CURSOR` oferecia QUATRO ponteiros e três deles gravavam um valor que o
#     `scripts/cursor.sh` não resolve (medido abaixo, em `_temas_de_cursor`).
#   · os 46 botões "Banir" e os 255 "Devolver" da galeria chamavam ações que não
#     existiam, porque sem provedor não há como validar o argumento — e a
#     fronteira deste arquivo é justamente "argumento vem do disco, nunca do
#     navegador".
#
# A ORDEM É A DA BUSCA DO XDG, e ela não é decoração: `~/.local/share/icons`
# vence `/usr/share/icons` para o mesmo nome, que é o que faz um tema instalado
# por ela mascarar o do sistema. Quem lista tem de enxergar o mesmo que quem usa.
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

    A REGRA, DERIVADA DO SCRIPT E DO DISCO
        O `cursor.sh` resolve `<valor>-cursors/cursors/` nas três raízes de
        ícone (`_cursor_instalado`, cursor.sh:257). Então o valor válido é o
        nome do diretório MENOS o sufixo — e um diretório que não termine em
        `-cursors` simplesmente não é escolhível por esta chave, por mais que
        tenha ponteiros dentro. Nada de lista fixa: instale outro tema
        `<x>-cursors` e ele aparece; o Adwaita continua fora porque continua
        sem nome que o script saiba montar.

        `set` e não lista: o mesmo tema pode estar em duas raízes, e oferecer o
        mesmo nome duas vezes é o defeito que esta função veio consertar.
    """
    fora = set()
    for nome, caminho in _dirs_de_icones():
        if not nome.endswith(SUFIXO_CURSOR):
            continue
        if os.path.isdir(os.path.join(caminho, "cursors")):
            fora.add(nome[: -len(SUFIXO_CURSOR)])
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
    return valores


def valores_efetivos(chaves):
    """O valor DEPOIS de o shell expandir — é o que os scripts de fato recebem.

    Uma chamada só ao bash, com `set -a` em volta do `.`, que é exatamente o que
    o `carregar_conf` do `bin/meow` e o `etapa_conf_ler` do `install.sh` fazem.
    Reimplementar a expansão de `${FLAVOR}` em Python seria a segunda verdade
    sobre o valor de uma chave, e ela discordaria no primeiro caso esquisito.
    """
    if not chaves:
        return {}
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
            ["bash", "-c", programa, "_", CONF_PADRAO, CONF, *chaves],
            capture_output=True, timeout=20,
        ).stdout.decode("utf-8", "replace")
    except (OSError, subprocess.SubprocessError):
        return {}
    fora = {}
    for pedaco in saida.split("\0"):
        if "=" in pedaco:
            k, v = pedaco.split("=", 1)
            fora[k] = v
    return fora


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
        # A PALAVRA QUE CONVIVE COM A FAIXA TAMBÉM É UM VALOR — 06/09/2026
        #   Medido do jeito mais direto que existe: exportei o `meow.conf` DELA
        #   pela própria página e reimportei o MESMO arquivo. 95 chaves voltaram
        #   idênticas e UMA foi recusada — `MIDIA_FONTE="auto"`, o valor que
        #   está no conf dela agora e que a aba Automação oferece como botão
        #   "Auto", ao lado de "Escolher número". A página propunha o que este
        #   validador respondia com 400.
        #   A causa é uma decisão só, vista de dois lados. O `_faixa_confere`
        #   GUARDA a faixa quando o padrão é uma das `_PALAVRAS_COM_FAIXA` —
        #   sem isso `MIDIA_FONTE` viraria campo de texto livre e `999` entraria
        #   calado, que foi o defeito curado em 02/09. O controle de faixa do
        #   `app.js` desenha o botão dessa palavra a partir do valor de fábrica,
        #   porque é ali que o arquivo a diz. Faltava a outra metade: quem aceita
        #   a faixa POR CAUSA da palavra tem de aceitar a palavra.
        #   E só ela, de propósito: a comparação é com o padrão DESTA chave, não
        #   com a lista inteira. `LEITURA_TEMPERATURA` (1000–6500 K, padrão
        #   numérico) continua recusando `auto`, porque a tela dele não desenha
        #   esse botão — a cerca segue sendo exatamente o que a página oferece.
        if valor == item["padrao"] and valor in _PALAVRAS_COM_FAIXA:
            return None
        try:
            n = float(valor.replace(",", "."))
        except ValueError:
            return "%s é um número entre %s e %s" % (item["chave"], lo, hi)
        if not (lo <= n <= hi):
            return "%s vai de %s a %s — %s está fora" % (item["chave"], lo, hi, valor)
        return None

    # A forma do número só vale quando não há lista nem faixa dizendo mais.
    if item["tipo_numero"]:
        for nome, forma, explica in FORMAS_NUMERO:
            if nome == item["tipo_numero"]:
                if not forma.match(valor):
                    return "%s espera %s" % (item["chave"], explica)
                break
    return None


def definir(chave, valor, seco=False):
    """Grava a chave pelo `meow_conf_definir` do projeto. 0 já estava · 1 escreveu."""
    if not RE_CHAVE.match(chave + "="):
        return (2, "nome de chave inválido")
    # `#` e `"` no valor quebrariam a linha do conf — é a mesma recusa que o
    # wizard já faz, e o cabeçalho de `lib/comum.sh` explica o limite: a função
    # parte a linha no primeiro `#`, então um valor com `#` viraria comentário.
    if '"' in valor or "#" in valor or "\n" in valor:
        return (2, 'o valor não pode conter aspas, `#` nem quebra de linha')
    ambiente = dict(os.environ, MEOW_RAIZ=RAIZ)
    if seco:
        ambiente["MEOW_DRY_RUN"] = "1"
    else:
        ambiente.pop("MEOW_DRY_RUN", None)
    programa = '. "$1/lib/comum.sh"; meow_conf_definir "$2" "$3"'
    try:
        proc = subprocess.run(
            ["bash", "-c", programa, "_", RAIZ, chave, valor],
            capture_output=True, timeout=30, env=ambiente,
        )
    except (OSError, subprocess.SubprocessError) as erro:
        return (2, str(erro))
    saida = (proc.stdout + proc.stderr).decode("utf-8", "replace").strip()
    return (proc.returncode, saida)


# --- 4. a paleta vira CSS ----------------------------------------------------
# NENHUM HEX VIVE DENTRO DE SCRIPT — é a regra do README, e ela vale para uma
# folha de estilo tanto quanto para um `.sh`. O `estilo.css` desta página não tem
# uma única cor escrita: ele consome `var(--base)`, `var(--accent)` e companhia,
# e quem as define é este endpoint, lendo `assets/paleta/catppuccin.json` no
# flavor que o meow.conf dela manda. Trocar `FLAVOR="latte"` e recarregar veste a
# página inteira de claro, sem uma linha de CSS a mais.
_PALETA_CACHE = {}


def _paleta_dados():
    """A paleta inteira, lida uma vez. É a fonte de verdade de cor do projeto."""
    if not _PALETA_CACHE:
        try:
            with open(PALETA, "r", encoding="utf-8") as fh:
                _PALETA_CACHE.update(json.load(fh))
        except (OSError, ValueError):
            _PALETA_CACHE["flavors"] = {}
    return _PALETA_CACHE


def paleta_css(flavor, accent):
    dados = _paleta_dados()
    flavors = dados.get("flavors", {})
    if not flavors:
        return "/* paleta ilegível — a página cai no tema do navegador */\n"
    cores = flavors.get(flavor) or flavors.get("mocha") or {}
    if accent not in cores:
        accent = "mauve" if "mauve" in cores else next(iter(cores), "")
    claro = flavor in dados.get("claros", [])
    linhas = [
        "/* Gerado por app/servidor.py a partir de assets/paleta/catppuccin.json.",
        "   Não edite: a fonte é a paleta, e ela é a única verdade de cor. */",
        ":root {",
        f"  color-scheme: {'light' if claro else 'dark'};",
    ]
    for nome, hexa in cores.items():
        linhas.append(f"  --{nome}: {hexa};")
    linhas.append(f"  --accent: var(--{accent});")
    # OS QUATRO FUNDOS DE TESTE, e eles não são decoração: são os quatro fundos
    # REAIS sobre os quais um ícone aparece nesta máquina. As folhas visuais de
    # 08/2026 comparam ícone sobre exatamente estes quatro, e a razão está
    # escrita nelas — a dock é translúcida e o papel de parede gira, então o
    # fundo por trás de um ícone oscila SOZINHO entre o vidro escuro e o claro.
    # Um ícone que some num deles não está resolvido.
    #
    # Os dois primeiros saem direto da paleta. Os dois de vidro são DERIVADOS
    # dela, e não hex digitado: o escuro é a base puxada 17% para o texto, o que
    # reproduz o valor medido nas folhas com erro de 2/255; o claro é uma
    # aproximação da dock sobre papel de parede claro, e está declarado como
    # aproximação porque é isso que ele é.
    linhas.append("  --fundo-mocha: %s;" % (flavors.get("mocha", {}).get("base", "")))
    linhas.append("  --fundo-latte: %s;" % (flavors.get("latte", {}).get("base", "")))
    linhas.append("  --fundo-vidro-escuro: color-mix(in srgb, var(--base) 83%, var(--text));")
    linhas.append("  --fundo-vidro-claro: color-mix(in srgb, var(--surface1) 55%, var(--mauve));")
    linhas.append(f"  --accent-nome: '{accent}';")
    linhas.append("}")
    return "\n".join(linhas) + "\n"


# --- 5. as ações -------------------------------------------------------------
# UMA LISTA FECHADA, E ELA É A FRONTEIRA DE SEGURANÇA DESTE ARQUIVO.
# A página manda um `id`; o `id` é chave deste dicionário; o que roda é o `argv`
# daqui. Não existe caminho por onde texto do navegador vire comando — nem com
# `shell=True`, que não aparece uma vez neste arquivo.
#
# `arg` nomeia um PROVEDOR de valores válidos, e o valor que a página mandar é
# conferido contra a lista que o provedor monta DO DISCO. Um `id` de captura que
# não existe é recusado antes de qualquer processo nascer.
#
# ELE É TAMBÉM O CATÁLOGO DE OPÇÕES DA PÁGINA — 01/09/2026
#   O mesmo dicionário alimenta duas coisas que sempre foram a mesma pergunta
#   ("que valores existem AGORA no disco?"): o argumento de uma ação e as opções
#   de uma chave (ver `FONTES_DO_DISCO`). Tê-los em tabelas separadas seria
#   convidar a divergência entre o que a página OFERECE e o que o servidor
#   ACEITA — e a página oferecendo o que o servidor recusa é exatamente o
#   defeito que a auditoria mediu no `CURSOR`.
PROVEDORES = {
    "capturas": _capturas,
    "gatos": _gatos,
    "modos": lambda: ["claro", "escuro", "auto"],
    "temas_icones": _temas_de_icones,
    "cursores": _temas_de_cursor,
    "paredes_ativas": _paredes_ativas,
    "paredes_banidas": _paredes_banidas,
}


def _meow(*args):
    return [os.path.join(RAIZ, "bin", "meow"), *args]


# ============================================================================
# O QUE CADA SEÇÃO É, EM UMA LINHA — 02/09/2026
# ============================================================================
# Pedido dela: "deixar mais obvio o que é aquela seção". O título sozinho não
# conta nada — "Automação" não diz a ninguém que ali moram os vigias e os
# relógios que reaplicam o tema.
#
# ISTO ANDA CONTRA UMA REGRA DELA, E A FOLHA PERGUNTOU ANTES
#   Em 01/09 ela pediu "menos palavras na interface como um todo. a página fala
#   por si". A `docs/folhas/folha-menu-do-painel.html` pôs a contradição na mesa
#   e ela aprovou: são nove linhas curtas, e o problema que elas resolvem é
#   exatamente o que ela levantou. A regra continua valendo para o resto —
#   nenhuma dessas frases passa de uma linha, e nenhuma explica o óbvio.
#
# A CHAVE É O NOME DA SEÇÃO, e não um id: quem nomeia as seções é o
# `meow.conf.exemplo`, e inventar um segundo identificador aqui seria a segunda
# lista que discorda da primeira quando alguém renomear um título lá.
DESCRICAO_SECAO = {
    # UMA ENTRADA POR ASSUNTO — 06/09/2026
    #   Eram nove frases para dezenove abas, e as subabas herdavam a do pai:
    #   três abas abriam com a mesma linha. Com o menu num nível só e uma página
    #   por assunto, a lista passa a ter uma frase por página, e o
    #   `|| d[g.secaoPai]` que o `app.js` usava para tapar o buraco saiu.
    #
    #   A chave é o NOME DO ASSUNTO, e não um id: quem nomeia os assuntos é o
    #   `meow.conf.exemplo`, e inventar um segundo identificador aqui seria a
    #   segunda lista, a que discorda da primeira quando alguém renomear lá.
    "Cor e tema": "A variante do Catppuccin, a cor de destaque, e claro ou escuro.",
    "O gato": "Qual gato aparece no dock e no terminal, e quem escolhe.",
    "Ícones": "O tema de ícones que o projeto constrói, e o desenho de cada programa.",
    "Barra e dock": "Forma, tamanho, vidro e a música que aparece na barra.",
    "Janelas e tela": "O lado a lado automático, o tamanho de tudo, e o ponteiro.",
    "Papel de parede": "A coleção, a pasta que gira, e como a imagem ocupa a tela.",
    "Dia e noite": "O que muda quando a noite começa: o gato, o fundo e a tela.",
    "Terminal": "A paleta do terminal, a cor do cursor, e o prompt do zsh.",
    "Programas e jogos": "Quais programas o projeto veste, e quais jogos aparecem.",
    "Manutenção": "O que se reaplica sozinho, quantos backups ficam, e quanto ele fala.",
    # As duas páginas que não têm chave do meow.conf — o bloco "A máquina".
    "Instalar e conferir": "Instalar, conferir, consertar, desfazer, e ver o que está no ar.",
    "Atualizar o sistema": "O Pop!_OS em dia, e o que a atualização desfez do MeowSystem.",
}


ACOES = {
    # --- o ciclo de vida -----------------------------------------------------
    "instalar": {
        "rotulo": "Instalar tudo",
        "grupo": "Instalar e conferir",
        "argv": [os.path.join(RAIZ, "install.sh")],
        "seco": True, "sudo": True, "confirma": True, "rede": True,
        "ajuda": "Passa as 52 etapas. Rodar de novo numa máquina já pronta "
                 "não escreve um byte.",
    },
    "doctor": {
        "rotulo": "Conferir a máquina",
        "grupo": "Instalar e conferir",
        "argv": _meow("doctor"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Faz as 46 conferências e lista o que está fora do lugar. "
                 "Não escreve nada.",
    },
    "doctor_consertar": {
        "rotulo": "Consertar o que estiver fora",
        "grupo": "Instalar e conferir",
        "argv": _meow("doctor", "--consertar"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Confere e aplica só o que falhou — o mesmo que o "
                 "agendamento faz sozinho.",
    },
    "status": {
        "rotulo": "O que está no ar agora",
        "grupo": "Instalar e conferir",
        "argv": _meow("status"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Variante, cor de destaque, tema, ícones e papel de parede.",
    },
    "desinstalar": {
        "rotulo": "Desinstalar o MeowSystem",
        "grupo": "Instalar e conferir",
        "argv": [os.path.join(RAIZ, "install.sh"), "--uninstall"],
        "seco": True, "sudo": False, "confirma": True, "destrutivo": True,
        "ajuda": "Tira o tema, os ícones e os agendamentos. Não apaga "
                 "backups nem a coleção de imagens.",
    },
    "log": {
        "rotulo": "As últimas 50 linhas do registro",
        "grupo": "Instalar e conferir",
        "argv": _meow("log"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "O que este projeto escreveu, e quando.",
    },

    # --- a nova versão da máquina --------------------------------------------
    # PEDIDO DELA EM 06/09/2026: *"unificar o Instalar e Conferir com o Ver o
    # Estado e, no lugar de Ver o Estado, criarmos uma aba para buildarmos a
    # nova versão do SO… conferir a idempotência do app como um todo, se
    # sobreviveríamos a um [apt full-upgrade && topgrade && …], que é a ideia do
    # projeto também"*.
    #
    # O comando dela já existia e é uma linha; o que faltava era a SEGUNDA
    # METADE. Um `full-upgrade` troca o cosmic-comp, o cosmic-panel, o fastfetch
    # e o papirus — e cada troca dessas desfaz alguma coisa que este projeto
    # escreveu. O `scripts/atualizar_sistema.sh` gruda as duas: atualiza, e em
    # seguida roda o `doctor` para dizer o que a atualização desfez.
    "sistema_ver": {
        "rotulo": "O que a atualização mudaria",
        "grupo": "Atualizar o sistema",
        "bloco": "A nova versão",
        "argv": [os.path.join(RAIZ, "scripts", "atualizar_sistema.sh"), "ver"],
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Os pacotes com versão nova e as caixas de Rust desatualizadas. "
                 "Não escreve, não pede senha e não baixa nada.",
    },
    "sistema_atualizar": {
        "rotulo": "Atualizar a máquina inteira",
        "grupo": "Atualizar o sistema",
        "bloco": "A nova versão",
        "argv": [os.path.join(RAIZ, "scripts", "atualizar_sistema.sh"), "aplicar"],
        "seco": True, "sudo": True, "confirma": True, "rede": True,
        "ajuda": "apt, flatpak e cargo, e logo depois o doctor — que diz o que a "
                 "atualização desfez do MeowSystem. Demora, e o apt mantém os "
                 "arquivos de configuração que já estão no disco.",
    },
    "sistema_limpar": {
        "rotulo": "Limpar o que sobrou",
        "grupo": "Atualizar o sistema",
        "bloco": "A nova versão",
        "argv": [os.path.join(RAIZ, "scripts", "atualizar_sistema.sh"), "limpar"],
        "seco": True, "sudo": True, "confirma": True,
        "ajuda": "Pacotes órfãos e o cache de download do apt. Diz quantos "
                 "megabytes saíram.",
    },
    # --- tema ----------------------------------------------------------------
    "tema": {
        "rotulo": "Temas prontos nesta máquina",
        "grupo": "Cor e tema",
        "argv": _meow("tema"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "O tema alvo, o que está de fato aplicado, e as capturas "
                 "que existem.",
    },
    "tema_aplicar": {
        "rotulo": "Trocar de tema",
        "grupo": "Cor e tema",
        "argv": _meow("tema", "@ARG@"), "arg": "capturas",
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Aplica a captura escolhida por cópia de arquivo, guardando "
                 "a anterior antes.",
    },
    "tema_modo": {
        "rotulo": "Passar para claro ou escuro",
        "grupo": "Cor e tema",
        "argv": _meow("tema", "@ARG@"), "arg": "modos",
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "São o mesmo tema com um interruptor, por isso trocar não "
                 "pisca a interface.",
    },
    "desfazer": {
        "rotulo": "Voltar ao tema de antes",
        "grupo": "Instalar e conferir",
        "argv": _meow("desfazer"),
        "seco": True, "sudo": False, "confirma": True, "destrutivo": True,
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
        "argv": _meow("icones"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Qual está selecionado e quantos arquivos ele tem.",
    },
    "icones_reconstruir": {
        "rotulo": "Reconstruir o tema de ícones",
        "grupo": "Ícones",
        "argv": _meow("icones", "reconstruir"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "É o que faz uma troca de variante dos ícones aparecer na "
                 "tela.",
    },
    "logo_listar": {
        "rotulo": "Qual gato está no ar, e por quê",
        "grupo": "O gato",
        "argv": _meow("logo", "listar"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "A lista, o gato em vigor, e qual regra o escolheu.",
    },
    "logo_trocar": {
        "rotulo": "Pôr um gato no dock",
        "grupo": "O gato",
        "argv": _meow("logo", "@ARG@"), "arg": "gatos",
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Com a escolha por horário, o relógio devolve o gato dele "
                 "na virada seguinte. Para fixar, mude a escolha do gato "
                 "para “fixo”.",
    },
    "logo_girar": {
        "rotulo": "Passar ao próximo gato",
        "grupo": "O gato",
        "argv": _meow("logo", "girar"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Só tem efeito quando o gato está girando; fora disso o "
                 "comando avisa em vez de fingir.",
    },
    # --- papel de parede -----------------------------------------------------
    "wallpaper": {
        "rotulo": "O carrossel agora",
        "grupo": "Papel de parede",
        "argv": _meow("wallpaper"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Pasta, quantas imagens, intervalo, ordem, e se há imagem "
                 "fixada.",
    },
    "wallpaper_proximo": {
        "rotulo": "Próxima imagem",
        "grupo": "Papel de parede",
        "argv": _meow("wallpaper", "proximo"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Avança e fixa a imagem pelo tempo definido em \"Quanto "
                 "tempo dura a imagem escolhida\".",
    },
    "wallpaper_anterior": {
        "rotulo": "Imagem anterior",
        "grupo": "Papel de parede",
        "argv": _meow("wallpaper", "anterior"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Volta uma imagem, com a mesma fixação.",
    },
    "wallpaper_carrossel": {
        "rotulo": "Voltar a girar",
        "grupo": "Papel de parede",
        "argv": _meow("wallpaper", "carrossel"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Solta a imagem fixada agora, sem esperar o tempo acabar.",
    },
    "wallpaper_aplicar": {
        "rotulo": "Reaplicar as regras do carrossel",
        "grupo": "Papel de parede",
        "argv": _meow("wallpaper", "aplicar"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Reescreve o estado do papel de parede a partir dos "
                 "ajustes.",
    },
    # AS DUAS AÇÕES DA GALERIA, QUE FALTAVAM — 01/09/2026
    #
    # A auditoria contou, no navegador, 46 botões "Banir" e 255 "Devolver" que
    # não chamavam NADA: o `rodarNaGaleria` do `app.js` procura a ação por id,
    # não acha, e devolve calado (`if (!acao) return`). É o caso de uso mais
    # visual da página inteira — ver a foto e recusá-la — e ele morria em
    # silêncio, sem torrada, sem erro, sem nada.
    #
    # `oculta` porque elas NÃO SÃO CARTÃO na aba "Fazer": o argumento delas é
    # uma imagem, e escolher imagem é o que a galeria já faz com miniatura. Um
    # cartão com um `<select>` de 255 nomes de arquivo seria a pior forma
    # possível de perguntar "qual foto?" numa página que sabe desenhá-las.
    #
    # E `confirma` fica FALSO nas duas, de propósito: banir MOVE para `banidos/`
    # e o `desbanir` desfaz — o script diz isso na cara ("está em banidos/, não
    # foi apagada"). Uma pergunta de confirmação a cada miniatura, num gesto
    # reversível que ela vai repetir dezenas de vezes seguidas, é ruído; a
    # tranca aqui é o modo seco e o fato de o inverso existir e estar na tela.
    "wallpaper_banir": {
        "rotulo": "Tirar esta imagem do carrossel",
        "grupo": "Papel de parede",
        "argv": _meow("wallpaper", "banir", "@ARG@"), "arg": "paredes_ativas",
        "seco": True, "sudo": False, "confirma": False,
        "destrutivo": True, "oculta": True,
        "ajuda": "Ela sai da pasta que gira e vai para a de banidas. Nada é "
                 "apagado. O “Devolver” da lista de recusadas desfaz.",
    },
    "wallpaper_desbanir": {
        "rotulo": "Devolver uma imagem tirada",
        "grupo": "Papel de parede",
        "argv": _meow("wallpaper", "desbanir", "@ARG@"), "arg": "paredes_banidas",
        "seco": True, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Volta para a pasta que gira e sai da lista de banidas — as "
                 "duas metades.",
    },
    "wallpaper_semear": {
        "rotulo": "Baixar a coleção curada",
        "grupo": "Papel de parede",
        "argv": _meow("wallpaper", "semear"),
        "seco": True, "sudo": False, "confirma": True, "rede": True,
        "ajuda": "Reconstrói a coleção a partir da lista de fontes. Usa rede "
                 "e pode demorar. As imagens que você tirou continuam fora.",
    },
    # --- barra, janelas, leitura --------------------------------------------
    "painel_estado": {
        "rotulo": "Barra e dock: diagnóstico",
        "grupo": "Barra e dock",
        "argv": _meow("painel", "estado"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "O estado do painel, da dock, e do serviço que os "
                 "supervisiona.",
    },
    "painel_teto": {
        "rotulo": "Até quanto o canto pode arredondar",
        "grupo": "Barra e dock",
        "argv": _meow("painel", "teto"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "A conta inteira: altura real, teto derivado, e se o "
                 "compositor limita em vez de derrubar a barra.",
    },
    "painel_reciclar": {
        "rotulo": "Recarregar a barra",
        "grupo": "Barra e dock",
        "argv": _meow("painel", "reciclar"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "A barra pisca uns 2 s. É o que faz um gato novo aparecer "
                 "sem esperar o próximo login.",
    },
    "leitura": {
        "rotulo": "Modo de leitura agora",
        "grupo": "Dia e noite",
        "argv": _meow("leitura"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Que degrau o relógio pede, o que a tela mostra, e se o "
                 "compositor sabe ler os dois números.",
    },
    "leitura_aplicar": {
        "rotulo": "Aplicar o degrau desta hora",
        "grupo": "Dia e noite",
        "argv": _meow("leitura", "aplicar"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Põe agora o que o agendamento poria sozinho.",
    },
    "leitura_remover": {
        "rotulo": "Desligar o modo de leitura",
        "grupo": "Dia e noite",
        "argv": _meow("leitura", "remover"),
        "seco": True, "sudo": False, "confirma": True,
        "ajuda": "Zera temperatura e textura, e desarma o agendamento.",
    },
    "files_menu": {
        "rotulo": "Menu da área de trabalho",
        "grupo": "Papel de parede",
        "argv": _meow("files-menu"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Os dois itens de papel de parede no botão direito.",
    },
    # --- aplicativos ---------------------------------------------------------
    "apps": {
        "rotulo": "Programas: o que está vestido",
        "grupo": "Programas e jogos",
        "argv": _meow("apps"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Módulo, programa instalado, tema aplicado ou pendente.",
    },
    "apps_aplicar": {
        "rotulo": "Vestir os programas agora",
        "grupo": "Programas e jogos",
        "argv": _meow("apps", "aplicar"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Aplica o tema em todos os programas marcados que estiverem "
                 "instalados. Programa ausente fica pendente, e nunca "
                 "derruba o resto.",
    },
    # --- os jogos da Steam ---------------------------------------------------
    # `confirma` é True no aplicar porque uma linha `apagar` no mapa manda o
    # script remover os arquivos do jogo. A página grava a receita sem perguntar
    # nada — escrever num mapa se desfaz com um clique —, mas EXECUTAR é o
    # momento em que gigabytes saem do disco, e é aí que a pergunta cabe.
    # AS DUAS SÃO `oculta`, E O MOTIVO É NÃO TER DUAS ENTRADAS COM O MESMO NOME
    #   "Jogos da Steam" já é uma seção de "Ver e escolher" — a grade com as
    #   capas. Um grupo de ação com o mesmo nome poria dois botões idênticos no
    #   menu, e o `ABA` (que casa por nome) não saberia qual dos dois abrir. Como
    #   os papéis de parede já fazem: a ação mora DENTRO da tela a que pertence,
    #   e o menu tem uma linha só. O `montarGrupos` pula grupo em que toda ação é
    #   oculta, então nenhuma seção vazia sobra.
    "jogos": {
        "rotulo": "Ver o que mudaria nos jogos",
        "grupo": "Programas e jogos",
        "argv": [os.path.join(RAIZ, "scripts", "jogos_steam.sh"), "--conferir"],
        "seco": False, "sudo": False, "confirma": False, "oculta": True,
        "ajuda": "Lista atalho a criar, atalho a remover e arquivo a apagar. "
                 "Não escreve nada.",
    },
    "jogos_aplicar": {
        "rotulo": "Arrumar os jogos no lançador",
        "grupo": "Programas e jogos",
        "argv": [os.path.join(RAIZ, "scripts", "jogos_steam.sh")],
        "seco": True, "sudo": False, "confirma": True, "destrutivo": True,
        "oculta": True,
        "ajuda": "Põe um atalho por jogo instalado e tira o dos que saíram. "
                 "Jogo marcado para apagar tem a pasta removida — uma vez "
                 "só, e nunca com a Steam aberta.",
    },
}


# --- 5b. AS PRÉVIAS: ver o efeito antes de escolher --------------------------
#
# O PEDIDO DELA, EM 01/09/2026, E POR QUE ELE MUDA O DESENHO DA PÁGINA
#   "o que pega na página, precisamos ter imagens disponíveis pra cada
#    feature. pra facilitar a escolha. afinal é um app de modificação visual.
#    Sem as imagens fica difícil."
#
#   Está certa, e a primeira versão desta página estava errada: ela listava 95
#   chaves com o nome, o valor e uma frase de texto. Para uma chave como
#   `LOG_NIVEL` isso basta; para `LOGO_DIA`, `FLAVOR` ou um papel de parede, é
#   pedir que ela decida no escuro e descubra o efeito DEPOIS de aplicar. Num
#   projeto cuja única razão de existir é a aparência da tela, texto não é
#   documentação da escolha — é a ausência dela.
#
# DUAS REGRAS QUE VALEM PARA TODA PRÉVIA DAQUI
#
#   1. NADA DE IMAGEM CHUMBADA NO REPOSITÓRIO. Um print de "como fica o mocha"
#      guardado em `docs/` é uma verdade com data de validade: no dia em que a
#      arte mudar, ele continua ali dizendo a coisa antiga, e ninguém percebe —
#      é o mesmo defeito que este repositório já pagou com o README dizendo que
#      um patch estava no binário quando não estava (e depois o contrário). Toda
#      prévia aqui é gerada do ARQUIVO QUE ESTÁ INSTALADO AGORA, e a chave do
#      cache carrega o `mtime` e o tamanho da origem. Trocou o desenho do gato?
#      A miniatura antiga deixa de ser encontrada e uma nova nasce. Ninguém
#      precisa lembrar de nada.
#
#   2. A PÁGINA NÃO ESPERA CONVERSÃO. `assets/papeis-de-parede/ativos/` tem 46
#      imagens somando 134 MB nesta máquina — a maior tem 7,1 MB. Mandar o
#      original para o navegador seria absurdo, e converter as 46 antes de
#      desenhar a primeira faria a tela ficar branca por segundos. Então
#      `/api/previas` responde NA HORA com a lista e o que já está pronto,
#      enfileira o que falta para três operários em segundo plano, e a página
#      mostra um lugar-marcado e volta a perguntar. Medido em 01/09/2026:
#      `convert -auto-orient -thumbnail 320x -quality 82` leva 0,17 s e
#      transforma 7,1 MB em 5,0 KB — mil e quatrocentas vezes menor.
#
# O QUE NÃO TEM PRÉVIA HONESTA DIZ ISSO NA TELA, em uma linha, em vez de deixar
# um retângulo vazio. É a mesma disciplina do `meow logo girar`, que anuncia não
# ter efeito em vez de fingir que girou.
CACHE = os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
    "meowsystem", "painel",
)

# `svg` é servido COMO ESTÁ, sem conversão nenhuma, e isso não é preguiça: o
# navegador desenha SVG melhor do que o `rsvg-convert` desenharia para ele, em
# qualquer tamanho, e sem gerar arquivo. Dentro de um `<img>` o SVG é inerte —
# script não roda em contexto de imagem —, então servir o desenho do tema
# instalado é seguro.
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
    pasta = os.path.join(RAIZ, "assets", "gatos")
    fora = []
    for nome in _gatos():
        caminho = os.path.join(pasta, nome + ".svg")
        if os.path.isfile(caminho):
            fora.append({"id": nome, "rotulo": nome, "origem": caminho, "grupo": "acervo"})
    return fora


def _wallpaper_base():
    base = valores_efetivos(["WALLPAPER_BASE"]).get("WALLPAPER_BASE") or ""
    return base or os.path.expanduser("~/.local/share/backgrounds/meowsystem")


# Os cinco grupos do acervo e a pasta de cada um. Fica aqui fora porque as
# CONTAGENS precisam da lista mesmo quando a pasta está vazia: a sub-aba
# "Favoritos" não tem um arquivo nesta máquina, e sem isto ela ficava sem número
# nenhum na tela — indistinguível de uma aba que ainda não foi contada.
GRUPOS_PAREDE = (("ativos", "ativos"), ("noite", "ativos-noite"),
                 ("dia", "ativos-dia"), ("favoritos", "favoritos"),
                 ("banidos", "banidos"))


def _prev_paredes():
    """Os cinco grupos do acervo. `banidos/` entra porque desbanir é um clique."""
    base = _wallpaper_base()
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
            #
            # E É POR ISSO QUE `banir` VEM SEPARADO DE `origem` — 01/09/2026
            #   Banir é `mv`, e `mv` move O CAMINHO que recebe: banir pelo link
            #   duro de `ativos-noite/` tira a imagem da pasta da noite e deixa a
            #   de `ativos/` girando o dia inteiro — um banimento pela metade, e
            #   mudo. As sub-abas Noite e Dia são justamente onde ela repara que
            #   a imagem está clara demais, então o botão precisa existir lá; o
            #   que ele manda é o caminho canônico, o de `ativos/`.
            #   Vazio quando não há canônico (as recusadas, e um favorito que não
            #   esteja em `ativos/`): aí não há o que banir, e a página não deve
            #   desenhar o botão.
            canonico = os.path.join(base, "ativos", nome)
            fora.append({"id": grupo + "/" + nome, "rotulo": nome,
                         "origem": arq, "grupo": grupo,
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

    Diretório que não termine em `-cursors` — Adwaita, Pop, breeze — fica de
    fora da lista, e isso não é perda: escolhê-los NUNCA funcionou. O
    `cursor.sh` procuraria `Adwaita-cursors`, não acharia, e tentaria baixar
    `Adwaita-cursors.zip` do release do `catppuccin/cursors`, que não existe.
    """
    fora = []
    for valor in _temas_de_cursor():
        pasta_tema = valor + SUFIXO_CURSOR
        alvo = None
        for raiz in RAIZES_ICONES:
            pasta = os.path.join(os.path.expanduser(raiz), pasta_tema, "cursors")
            # `default` é o nome canônico e `left_ptr` o histórico; um costuma
            # ser link simbólico para o outro, e qualquer um serve.
            for cand in ("left_ptr", "default"):
                caminho = os.path.join(pasta, cand)
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

      - as opções são os gatos que existem em `assets/gatos/`?  -> desenho do gato
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
    if faixa:
        lo, hi = faixa[0], faixa[1]
        # A faixa do Kelvin visível é 1000–6500 e está escrita no arquivo. O
        # teste é largo de propósito: qualquer chave que declare uma faixa nessa
        # ordem de grandeza é temperatura de cor, e não há outra assim aqui.
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
# item. Serve às contagens de `previas()`, para uma pasta vazia mostrar 0 em vez
# de sumir da conta — ver o comentário lá.
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
# Três enche a fila do navegador (que abre ~6 conexões) sem tomar a máquina.
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
    # AS CONTAGENS SAEM ANTES DO FILTRO, E É DE PROPÓSITO — 01/09/2026
    #   As cinco sub-abas da galeria nasciam sem número: só ganhavam a conta
    #   depois de serem ABERTAS uma vez, porque a página só sabia o tamanho do
    #   grupo que tinha pedido. Ficava na tela "No carrossel 46 · Noite · Dia ·
    #   Favoritos · Recusadas" — quatro rótulos mudos ao lado de um com número,
    #   e nenhuma pista de que "Recusadas" guarda 255 imagens.
    #   Esta função já lê as cinco pastas em uma passada (o `fonte()` acima);
    #   contá-las custa um laço e responde a pergunta inteira de uma vez.
    #   Os grupos conhecidos entram ZERADOS antes da conta: uma pasta vazia tem
    #   de dizer "0", e não sumir. Sem isto, "Favoritos" — que não tem um
    #   arquivo nesta máquina — ficava sem número, exatamente igual a uma aba
    #   que ainda não tinha sido aberta.
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
        # O campo extra que só o papel de parede tem: o caminho que a ação de
        # banir aceita (ver `_prev_paredes`). Copiado por presença, e não por
        # nome de tipo — a próxima fonte que precisar de um campo próprio o
        # ganha sem ninguém vir aqui.
        if "banir" in item:
            saida["banir"] = item["banir"]
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


# ============================================================================
# 5b. LEVAR EMBORA, E TRAZER DE VOLTA
# ============================================================================
# Pedido dela em 06/09/2026: um botão de exportar ao lado do "Modo seco", com
# duas saídas — as configurações, e "o html standalone, mostrando todas as abas,
# com o menu lateral, de forma que eu pudesse mandar pra quem vai me ajudar a
# melhorar o layout" — e um de importar, que só traz as configurações de volta.
#
# POR QUE SÃO DUAS SAÍDAS E UMA ENTRADA, E NÃO DUAS DE CADA
#   O `.conf` é dado dela: sai e volta, e voltar é o que faz o backup valer.
#   O `.html` é uma FOTOGRAFIA da página — ele sai para ser redesenhado lá fora,
#   e o que volta de lá é desenho, não configuração. Um "importar página" que
#   sobrescrevesse o `app.js` com HTML de procedência desconhecida seria a
#   maior porta deste servidor, e ela não precisa existir: quem traduz o
#   desenho de volta lê o arquivo e mexe no código, com o diff na frente.
#
# O FORMATO DO `.conf` É O ARQUIVO DELA, E NÃO UM FORMATO NOVO
#   Exportar JSON seria mais fácil de escrever e pior de usar: o `meow.conf` é o
#   que ela já sabe ler, o que o `meow configurar` escreve e o que o `. conf` do
#   shell carrega. Um segundo formato para a mesma verdade é a armadilha nº 3
#   deste repositório de novo, com outra roupa.
#
#   Então a exportação é o arquivo dela, byte a byte, com um cabeçalho de
#   comentário na frente dizendo quando saiu e de onde. O cabeçalho é comentário
#   de shell: o arquivo continua sendo um `meow.conf` válido, e reimportá-lo
#   (ou copiá-lo por cima do original) funciona sem tirar nada.

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
        linhas_cabecalho.append("# Origem: %s" % CONF)
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
            "# Origem: o catálogo (%s ainda não existia nesta máquina)" % CONF)
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
        botão, o mesmo diálogo, o mesmo modo seco, o mesmo instalador em
        seguida. Importar deixa de ser um caminho de escrita paralelo (que
        teria de reimplementar o seco, a idempotência e o aviso de aplicar) e
        vira o que é: um jeito de preencher a tela.

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

    # A ÚLTIMA ATRIBUIÇÃO VENCE, como no `.` do shell. Um arquivo com a mesma
    # chave duas vezes tem de trazer o que o shell obedeceria, e não a primeira
    # linha que apareceu — é a divergência que o cabeçalho de `lib/comum.sh`
    # conta ter custado uma tarde.
    pares = {}
    for linha in texto.split("\n"):
        crua = linha.strip()
        if crua.startswith("export "):
            crua = crua[len("export "):]
        achado = RE_CHAVE.match(crua)
        if achado:
            pares[achado.group(1)] = _valor_da_linha(crua)

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


# --- 6. os trabalhos ---------------------------------------------------------
class Trabalho:
    """Um comando rodando, com a saída acumulada para a página buscar.

    POR QUE ACUMULAR EM VEZ DE TRANSMITIR (streaming)
        Um `text/event-stream` seria menos código e cairia junto com a aba: um
        F5 no meio de um `./install.sh` mataria o processo, ou o deixaria órfão
        escrevendo num socket morto. Guardar as linhas aqui faz a página poder
        fechar, recarregar e voltar a acompanhar o MESMO trabalho de onde parou —
        que é o comportamento que uma instalação de 49 etapas pede.
    """

    _seq = 0
    _trava = threading.Lock()

    def __init__(self, acao_id, argv, ambiente, rotulo):
        with Trabalho._trava:
            Trabalho._seq += 1
            self.id = Trabalho._seq
        self.acao = acao_id
        self.rotulo = rotulo
        self.argv = argv
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

    def _ler(self):
        try:
            for bruta in self.proc.stdout:
                linha = bruta.decode("utf-8", "replace").rstrip("\n")
                with self._lock:
                    self.linhas.append(linha)
        except (OSError, ValueError):
            pass
        self.rc = self.proc.wait()
        self.fim = time.time()

    def desde(self, n):
        with self._lock:
            return list(self.linhas[n:]), len(self.linhas)

    def vivo(self):
        return self.proc.poll() is None

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


def escreve(acao):
    """Esta ação escreve na máquina dela?

    A RESPOSTA SAI DO `seco`, E AS DUAS COINCIDEM POR UMA RAZÃO
        `seco: True` marca a ação que aceita `MEOW_DRY_RUN=1`, e uma ação que
        nunca escreve não tem o que prever — não haveria o que o seco calasse.
        Por isso não existe um campo `escreve` digitado à mão em cada entrada
        de `ACOES`: seria uma segunda verdade sobre a mesma ação, e o dia em que
        as duas discordassem a tela mostraria a errada.

    E ELA É UMA PERGUNTA DIFERENTE DE "ACEITA SECO" — 01/09/2026
        A auditoria mediu na tela: os cartões que escrevem traziam só a pastilha
        "ACEITA SECO", que fala de uma CAPACIDADE DE SIMULAÇÃO, não de risco; os
        que só leem não traziam pastilha nenhuma. Ou seja, a única marca visível
        separava `doctor` de `doctor --consertar` falando de outro assunto. O
        servidor passa a dizer a palavra certa, e a página só precisa mostrá-la.
    """
    return bool(acao.get("seco"))


def iniciar(acao_id, argumento, seco, confirmado=False):
    """Começa uma ação. Devolve (trabalho, erro) — o erro pode ser um dicionário."""
    global TRABALHO_ATUAL
    acao = ACOES.get(acao_id)
    if acao is None:
        return (None, "ação desconhecida")

    # O SECO EFETIVO NÃO É O QUE A PÁGINA PEDIU — 01/09/2026
    #   `MEOW_DRY_RUN=1` só é posto no ambiente quando a AÇÃO aceita seco (ver
    #   logo abaixo, e é assim desde sempre). Marcar a caixa "modo seco" numa
    #   ação que não o aceita não protege nada, e é esse valor — o efetivo, não
    #   o pedido — que decide se a confirmação é dispensável.
    seco_valendo = bool(seco and acao.get("seco"))

    # A CONFIRMAÇÃO É UMA TRANCA DO SERVIDOR, E NÃO UM COSTUME DA PÁGINA
    #   O campo `confirma` existe desde o primeiro dia e era só uma DICA: a
    #   página perguntava se quisesse, e um POST direto (ou um botão que
    #   esquecesse de perguntar) disparava `./install.sh` ou o `desfazer` na
    #   mesma linha. A auditoria de 01/09/2026 mediu a versão prática do
    #   problema — "o modo seco nasce desligado e treze ações que escrevem no
    #   sistema disparam de primeira" —, e a resposta certa não é a página
    #   lembrar de perguntar: é o servidor não obedecer sem a resposta.
    #
    #   No seco a tranca não se aplica, e isso não é folga: no seco NADA é
    #   escrito, e exigir confirmação para uma simulação ensinaria a confirmar
    #   sem ler, que é o oposto do que a tranca serve.
    #
    #   O erro sai como DICIONÁRIO (e não frase) porque a página tem de poder
    #   distinguir "preciso perguntar" de "deu errado" sem ler texto: um é uma
    #   pergunta a fazer, o outro é uma torrada vermelha.
    if acao.get("confirma") and not seco_valendo and not confirmado:
        return (None, {
            "erro": "esta ação escreve na máquina e precisa de confirmação",
            "precisa_confirmar": True,
            "acao": acao_id,
            "rotulo": acao["rotulo"],
            "ajuda": acao.get("ajuda", ""),
            "escreve": escreve(acao),
            "sudo": bool(acao.get("sudo")),
            "rede": bool(acao.get("rede")),
            "destrutivo": bool(acao.get("destrutivo")),
            "aceita_seco": bool(acao.get("seco")),
        })

    argv = list(acao["argv"])
    if "@ARG@" in argv:
        permitidos = PROVEDORES[acao["arg"]]()
        if argumento not in permitidos:
            return (None, "argumento fora da lista do disco: %r" % (argumento,))
        argv = [argumento if p == "@ARG@" else p for p in argv]
    elif argumento:
        return (None, "esta ação não recebe argumento")

    ambiente = dict(os.environ)
    ambiente["MEOW_RAIZ"] = RAIZ
    ambiente.update(acao.get("ambiente", {}))
    if seco_valendo:
        ambiente["MEOW_DRY_RUN"] = "1"
    else:
        ambiente.pop("MEOW_DRY_RUN", None)
    # O `install.sh` cala o progresso quando NÃO há terminal (`[ ! -t 1 ]`), e é
    # a decisão certa lá — quase 600 linhas num journal não têm leitor. Aqui há
    # leitora, e ela está olhando: sem esta linha a página mostraria um retângulo
    # quase vazio durante uma instalação inteira. Quem já escolheu `debug` no
    # meow.conf continua com `debug`; o resto sobe para `info`.
    if ambiente.get("LOG_NIVEL", "") != "debug":
        ambiente["LOG_NIVEL"] = "info"
    # Cor de terminal não tem sentido em HTML, e os scripts já a desligam sozinhos
    # quando a saída é um cano (`[ -t 1 ]` em lib/comum.sh). `NO_COLOR` é o cinto:
    # um script de terceiro no meio do caminho pode não fazer esse teste.
    ambiente["NO_COLOR"] = "1"

    with TRABALHO_TRAVA:
        if TRABALHO_ATUAL is not None and TRABALHO_ATUAL.vivo():
            return (None, "já há um trabalho correndo: %s" % TRABALHO_ATUAL.rotulo)
        try:
            trabalho = Trabalho(acao_id, argv, ambiente, acao["rotulo"])
        except OSError as erro:
            return (None, str(erro))
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

    # AS TRÊS PORTAS DO TOKEN, E POR QUE PRECISAM SER TRÊS — 01/09/2026
    #   A primeira versão aceitava só o cabeçalho `X-Meow-Token` e o `?t=` da
    #   URL, e a página nasceu QUEBRADA: sem estilo e parada em "carregando…".
    #   Vi na tela, não no código. O motivo é elementar depois de visto — um
    #   `<link rel="stylesheet" href="/estilo.css">` e um `<script src="/app.js">`
    #   são pedidos que o NAVEGADOR faz sozinho, e ele não tem como pôr um
    #   cabeçalho nosso neles. Os três subrecursos tomavam 403, calados.
    #
    #   Havia um segundo defeito escondido atrás do primeiro, e pior: o `app.js`
    #   apaga o `?t=` da barra de endereço no primeiro instante (um token no
    #   histórico do navegador sobreviveria à sessão que o criou). Com a URL
    #   limpa, um F5 daria 403 na própria página — o painel funcionaria uma vez
    #   e morreria no primeiro recarregamento.
    #
    #   O COOKIE resolve os dois de uma vez, e é o que ele existe para fazer:
    #   o navegador o manda em TODO pedido a esta origem, inclusive nos que
    #   ele mesmo inventa. `HttpOnly` (nem o nosso JS o lê), `SameSite=Strict`
    #   (nenhum pedido vindo de outro site o carrega, que é a defesa de CSRF) e
    #   sem `Expires` (morre quando o navegador fecha, como o processo).
    #
    #   O `?t=` continua valendo porque é como o cookie NASCE: o `run.sh` abre o
    #   navegador na URL com o token, e é essa primeira visita que o planta.
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
            # `Secure` fica de fora de propósito: a origem é `http://127.0.0.1`,
            # e um cookie `Secure` simplesmente não seria gravado ali.
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
        # `Content-Disposition` dos dois botões de exportar. Eles entram AQUI,
        # e não numa função de resposta paralela, porque as quatro guardas
        # acima têm de valer para toda resposta deste servidor: a segunda
        # rotina de resposta seria a segunda lista de cabeçalhos, e a primeira
        # coisa que ela esqueceria é justamente uma dessas quatro.
        for nome, valor in (extras or {}).items():
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
                # é o fim-de-arquivo do TCP. Enquanto ninguém fecha nada, ele
                # dorme os quinze segundos e não gasta nada.
                pronto, _, _ = select.select([self.connection], [], [], PULSO_BATIDA)
                if pronto and not self.connection.recv(1):
                    break
        except (OSError, ValueError):
            pass
        finally:
            _pulso_sai()

    # --- rotas ---------------------------------------------------------------
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
            # "não existe aqui" antes. Pego ao abrir a primeira folha no teste.
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            # AS FOLHAS SÃO PARA ABRIR, e não para copiar caminho.
            #   A auditoria mediu: "as 18 folhas são texto morto: nada é
            #   clicável, nada abre, e o caminho absoluto que a frase manda usar
            #   não é clicável". Servi-las daqui é o que torna a aba útil — e a
            #   cerca é a mesma dos outros arquivos: só o que está dentro de
            #   `docs/folhas/`, e só `.html`.
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
            # A CSP PRECISA DEIXAR A FOLHA DESENHAR.
            #   A primeira versão não declarava `script-src`, então o inline
            #   caía no `default-src 'none'` e TRÊS das dezoito folhas abriam em
            #   branco — as que desenham em canvas. Um revisor mediu e apontou.
            #   O que fica de fora é o que importa: nada de rede (`connect-src`
            #   ausente herda `none`), nada de iframe, nada de formulário. São
            #   arquivos do próprio repositório, servidos só para 127.0.0.1 com
            #   token de sessão — o risco que a CSP cobre aqui é a folha buscar
            #   algo fora, e isso continua barrado.
            self.send_header(
                "Content-Security-Policy",
                "default-src 'none'; img-src data: blob:; "
                "style-src 'unsafe-inline'; script-src 'unsafe-inline'; "
                "font-src data:")
            self.send_header("Content-Length", str(len(dados_folha)))
            self.end_headers()
            self.wfile.write(dados_folha)
            return None



        # O GATO DO CABEÇALHO É O GATO DE VERDADE, LIDO DO ACERVO
        #   A primeira versão punha um emoji de gato preto no HTML, e na tela dela saiu
        #   meia-boca: é uma sequência ZWJ (gato + junção + quadrado preto) que a
        #   fonte desta máquina não compõe, então aparecia um glifo genérico.
        #
        #   Ter o gato dela ali é melhor de qualquer forma, e é de graça: o acervo
        #   `assets/gatos/` já é a configuração deste projeto, e a chave `LOGO`
        #   diz qual está no ar. Soltou um `.svg` novo lá e recarregou a página —
        #   o cabeçalho segue, como todo o resto do MeowSystem segue.
        #
        #   `os.path.basename` sobre o nome vindo da CONF (não do pedido) é
        #   paranoia barata: um `LOGO="../../etc/passwd"` no meow.conf dela não
        #   passa daqui, e a extensão é cravada em `.svg`.
        if caminho == "/gato.svg":
            if not self._token_confere(consulta):
                return self._recusar(403, "token de sessão ausente ou errado")
            nome = os.path.basename(valores_efetivos(["LOGO"]).get("LOGO") or "coquinha")
            arquivo = os.path.join(RAIZ, "assets", "gatos", nome + ".svg")
            if not os.path.isfile(arquivo):
                gatos = _gatos()
                if not gatos:
                    return self._recusar(404, "não há gato no acervo")
                arquivo = os.path.join(RAIZ, "assets", "gatos", gatos[0] + ".svg")
            with open(arquivo, "rb") as fh:
                return self._responder(fh.read(), tipo=TIPOS[".svg"])

        if caminho == "/previa" and consulta.get("tipo", [""])[0] == "arquivo":
            # SERVIR UM ARQUIVO POR CAMINHO É UMA PORTA, e ela tem cerca.
            #   Sem a cerca, um GET forjado leria QUALQUER arquivo do disco
            #   (`/previa?tipo=arquivo&id=/etc/shadow`). Então: caminho real
            #   (resolvido, sem `..`), dentro de uma das duas árvores de arte
            #   que esta página tem motivo para mostrar, e só extensão de
            #   imagem. Fora disso é 404 — nem uma mensagem diferente, para não
            #   virar sonda de existência de arquivo.
            alvo_arq = os.path.realpath(consulta.get("id", [""])[0] or "")
            # A cerca acompanha a busca do `_icone_na_tela`: são as pastas de
            # ARTE da máquina, e nada mais. `/usr/share/pixmaps` entra porque é
            # de lá que vem o ícone de vários aplicativos antigos.
            permitidos = [os.path.realpath(x) for x in (
                os.path.join(RAIZ, "assets", "icones"),
                os.path.expanduser("~/.local/share/icons"),
                os.path.expanduser("~/.local/share/flatpak/exports/share/icons"),
                "/usr/share/icons",
                "/usr/share/pixmaps",
                "/var/lib/flatpak/exports/share/icons",
                os.path.expanduser("~/.local/share/Steam"),
                os.path.expanduser("~/.steam"),
            ) if os.path.isdir(x)]
            ok_pasta = any(alvo_arq.startswith(p + os.sep) for p in permitidos)
            ext_arq = os.path.splitext(alvo_arq)[1].lower()
            # O `.jpg` entrou em 02/09/2026 com a seção "Jogos da Steam": a arte
            # do `appcache/librarycache` é JPEG, e sem ele a grade de jogos
            # abriria com 22 quadrados vazios. A cerca NÃO muda — `~/.steam` já
            # estava na lista de pastas permitidas; o que muda é aceitar o
            # formato em que a Steam guarda a capa.
            if not ok_pasta or ext_arq not in (".svg", ".png", ".jpg", ".jpeg"):
                return self._recusar(404, "não achei")
            try:
                with open(alvo_arq, "rb") as fh:
                    dados_arq = fh.read()
            except OSError:
                return self._recusar(404, "não achei")
            tipo_mime = {".svg": "image/svg+xml", ".png": "image/png",
                         ".jpg": "image/jpeg", ".jpeg": "image/jpeg"}[ext_arq]
            self.send_response(200)
            self.send_header("Content-Type", tipo_mime)
            self.send_header("Content-Length", str(len(dados_arq)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(dados_arq)
            return None

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
            flavor = valores.get("FLAVOR") or "mocha"
            # MODO="claro" veste a página de Latte mesmo com FLAVOR escuro: o que
            # ela vê na tela é o tema CLARO, e um painel escuro no meio disso
            # seria a única janela fora do lugar.
            if valores.get("MODO") == "claro":
                flavor = "latte"
            return self._responder(paleta_css(flavor, valores.get("ACCENT") or "mauve"),
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

    # ========================================================================
    # ACRESCENTAR AO ACERVO DO REPOSITÓRIO — 01/09/2026
    # ========================================================================
    # Pedido dela, primeiro para os gatos e logo depois generalizado com as
    # palavras "é esse tipo de solução pra toda aba viu?", e antes disso:
    # "ela tem que integrar e atuar diretamente no repo local do user".
    #
    # A página deixa de ser só um editor de texto do `meow.conf` e passa a
    # ALIMENTAR o repositório: o desenho novo, o papel de parede novo, o ícone
    # novo entram pela página e caem na pasta que já é a configuração deste
    # projeto ("soltou o arquivo, entrou").
    #
    # O DESTINO NÃO É ESCOLHIDO PELO NAVEGADOR. A página manda um `tipo`
    # (`gato`, `parede`, `icone`) e o servidor resolve a pasta — se o caminho
    # viesse no corpo, um POST forjado escreveria em qualquer lugar do disco.
    # O nome é saneado até virar `[A-Za-z0-9._-]`, e `..` some junto.
    #
    # SVG PASSA PELO `normalizar_svg.py` ANTES DE ENCOSTAR NO ACERVO. É o mesmo
    # conserto que o `logo.sh` faz: um desenho salvo no Boxy com
    # `transform-origin` entra e não aparece na tela, e o defeito é mudo.
    ACERVOS = {
        "gato": {
            "pasta": ("assets", "gatos"),
            "extensoes": (".svg",),
            "normaliza": True,
            "depois": "o vigia põe o gato novo no acervo em segundos",
        },
        "parede": {
            "pasta": ("assets", "papeis-de-parede", "ativos"),
            "extensoes": (".jpg", ".jpeg", ".png", ".webp"),
            "normaliza": False,
            "depois": "o carrossel passa a sortear a imagem nova",
        },
        "icone": {
            "pasta": ("assets", "icones", "overrides"),
            "extensoes": (".svg",),
            "normaliza": True,
            "depois": "vale depois de \"Reconstruir o tema de ícones\"",
        },
    }

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
        # A ARMADILHA DO NOME, que o `logo.sh` documenta desde 05/08: o applet do
        # painel achata em uma cor só qualquer arquivo cujo caminho contenha
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

        # DE DIA OU DE NOITE? A RESPOSTA VAI NA HORA, E NÃO NA PRÓXIMA PASSAGEM.
        #   Pedido dela em 06/09/2026: *"como adicionamos os wallpapers pelo html
        #   e eles vão pra pasta correta"*. Iam — mas em silêncio e só depois:
        #   quem separa `ativos-dia/` de `ativos-noite/` é o `wallpaper.sh`, pela
        #   luminância, na próxima vez que o carrossel reaplica. Entre soltar o
        #   arquivo e descobrir de que lado ele caiu podiam passar cinco minutos,
        #   e nada na tela dizia qual lado seria.
        #
        #   A medida aqui é a MESMA do `wallpaper.sh` — `-colorspace Gray` antes
        #   do `%[fx:mean]`, que é Rec.709 sobre a imagem inteira. O atalho
        #   `%[fx:luminance]` mede o pixel (0,0), e o cabeçalho daquele arquivo
        #   registra a medição em que os dois discordaram em 0,16.
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

    # ========================================================================
    # OS APLICATIVOS, E O ÍCONE DE CADA UM — 01/09/2026
    # ========================================================================
    # Ela, olhando a aba de ícones: "naquela página de icones, cara, um dos html
    # antigas permitia escolher o icon pra substituir tal
    # programa. Aqui não temos isso. Ali tá travadasso. Todo e qualquer programa
    # com .desktop tinha que tá ali." E o princípio, logo depois: "permitir
    # facilidade do user. pra não depender de ajuda sempre."
    #
    # É o pedido mais importante desta página inteira. Trocar o ícone de um
    # aplicativo hoje exige editar `assets/icones/apps-arcticons.map` à mão,
    # saber que o glifo tem de existir em `assets/icones/arcticons-apps/`, e
    # rodar o construtor. Nada disso é conhecimento que ela deveria precisar ter
    # para dizer "quero outro desenho no Telegram".
    #
    # O QUE ESTA ROTA DEVOLVE: todo `.desktop` da máquina, com o ícone que está
    # NA TELA agora (o do tema instalado, não o do repositório) e a linha do
    # mapa quando existe. A escolha dela é gravada no MAPA DO REPOSITÓRIO — é o
    # que faz a decisão sobreviver a uma reinstalação, que é a regra desta casa:
    # a imagem não vai para o git, a receita vai.
    DIRS_DESKTOP = (
        ("/usr/share/applications", "sistema"),
        ("/usr/local/share/applications", "local"),
        ("~/.local/share/applications", "usuária"),
        ("/var/lib/flatpak/exports/share/applications", "flatpak"),
        ("~/.local/share/flatpak/exports/share/applications", "flatpak"),
        ("/var/lib/snapd/desktop/applications", "snap"),
    )

    def _desktops(self):
        """Todo `.desktop` visível da máquina: id, nome, ícone declarado, origem."""
        vistos = {}
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
                         "arquivo": caminho, "oculto": False}
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
                            elif linha.startswith("Icon="):
                                dados["icone"] = linha[5:].strip()
                            elif linha.startswith(("NoDisplay=", "Hidden=")):
                                if linha.split("=", 1)[1].strip().lower() == "true":
                                    dados["oculto"] = True
                except OSError:
                    continue
                # Quem vem depois vence: o `.desktop` da usuária sobrepõe o do
                # sistema, que é a mesma precedência que o lançador usa.
                vistos[ident] = dados
        return sorted(vistos.values(), key=lambda d: d["nome"].lower())

    def _mapa_arcticons(self):
        """As linhas ativas de `apps-arcticons.map`, por id de aplicativo."""
        fora = {}
        caminho = os.path.join(RAIZ, "assets", "icones", "apps-arcticons.map")
        try:
            with open(caminho, "r", encoding="utf-8") as fh:
                for linha in fh:
                    corte = linha.strip()
                    if not corte or corte.startswith("#"):
                        continue
                    campos = [c.strip() for c in corte.split(":")]
                    if len(campos) >= 3:
                        fora[campos[0]] = {"glifo": campos[1], "cor": campos[2],
                                           "alias": len(campos) > 3 and campos[3] == "alias"}
        except OSError:
            pass
        return fora

    # A ORDEM DE BUSCA É A MESMA QUE O LANÇADOR USA, e ela tem de ir até o fim:
    # a primeira versão só olhava o NOSSO tema, então os 24 jogos da Steam e
    # todo aplicativo que o MeowSystem ainda não veste apareciam como quadrado
    # vazio — como se não tivessem ícone, quando têm. Um quadrado vazio numa
    # grade de 65 diz "está quebrado", e não "este ainda não é nosso".
    TEMAS_DE_ICONE = ("", "hicolor", "Papirus-Dark", "Papirus", "Adwaita")
    TAMANHOS = ("scalable", "256x256", "128x128", "64x64", "48x48", "32x32", "24x24", "22x22")

    def _icone_na_tela(self, d, base_tema):
        """(caminho do ícone que aparece hoje, se é do nosso tema)."""
        nome = d["icone"] or d["id"]
        # 1. caminho absoluto no próprio `.desktop` — é o que a Steam faz.
        if nome.startswith("/") and os.path.isfile(nome):
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
    # pode ser exportada num arquivo só. Quem monta a resposta HTTP é o método
    # acima; este devolve o DADO, e é ele que o `exportar_pagina` congela.
    def _dados_apps(self, consulta):
        busca = (consulta.get("busca", [""])[0] or "").strip().lower()
        mapa = self._mapa_arcticons()
        tema = os.environ.get("NOME_TEMA_ICONES") or "MeowSystem-Icons"
        base_tema = os.path.expanduser("~/.local/share/icons/%s" % tema)
        fora = []
        for d in self._desktops():
            if d["oculto"]:
                continue
            if busca and busca not in d["nome"].lower() and busca not in d["id"].lower():
                continue
            # O ícone que está NA TELA: o arquivo do tema instalado, se houver.
            # "está instalado?" e "está na tela dela?" são perguntas diferentes,
            # e esta página tem de responder a segunda.
            atual, nosso = self._icone_na_tela(d, base_tema)
            fora.append({
                "id": d["id"], "nome": d["nome"], "icone": d["icone"],
                "origem": d["origem"], "nosso": nosso,
                "url": ("/previa?tipo=arquivo&id=" + quote(atual, safe="")) if atual else "",
                "mapa": mapa.get(d["id"]) or mapa.get(d["icone"]) or None,
            })
        return {"apps": fora, "total": len(fora)}

    # ========================================================================
    # OS JOGOS DA STEAM — 02/09/2026
    # ========================================================================
    # Ela, depois de descobrir que o cartão do Mad King continuava no lançador
    # com o jogo sem licença: "veja se está integrado ao app meowsystem." Não
    # estava. Tirar um jogo da tela — ou apagar 2,4 G de sobra — exigia editar
    # `assets/icones/jogos-fora.map` num editor de texto.
    #
    # O DESENHO É O MESMO DO ÍCONE POR APLICATIVO, E DE PROPÓSITO
    #   A página NÃO apaga nada. Ela grava a RECEITA no mapa do repositório, e
    #   quem age é o `scripts/jogos_steam.sh` na passagem seguinte. É a regra
    #   desta casa — a imagem não vai para o git, a receita vai — e tem um
    #   segundo efeito que importa mais: nenhum `rm -rf` mora dentro de um
    #   servidor HTTP. O botão que executa é o mesmo "Arrumar os jogos" da
    #   coluna de ações, que já passa pelo confirmar e pela gaveta de saída.

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

                # JOGO x FERRAMENTA PELA CAPA **VERTICAL**, e o "vertical" é o
                # que separa os dois — medido em 02/09/2026, na primeira versão
                # desta rota.
                #   O `_capa_do_jogo` cai para `header.jpg` e `logo.png` quando
                #   não há capa vertical, e é isso que faz a grade ter arte para
                #   todo mundo. Só que as nove ferramentas (Proton, runtimes)
                #   TÊM header e logo — então usar "tem alguma arte" como teste
                #   devolvia 31 itens onde o lançador mostra 22. O critério do
                #   `jogos_steam.sh` é estrito: `library_capsule.jpg` ou
                #   `library_600x900.jpg`, que 21 de 21 jogos têm e 0 de 9
                #   ferramentas tem.
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
        # AS LINHAS SEM MANIFESTO TAMBÉM APARECEM — senão a decisão dela some
        # da tela justamente depois de dar certo.
        #   O Mad King é o caso: a linha `apagar` disparou, o manifesto foi
        #   embora com os arquivos, e o laço acima — que corre sobre manifestos
        #   — deixaria de vê-lo. A linha continuaria no mapa, sem nenhum lugar na
        #   página onde ela pudesse lê-la ou tirá-la. Entram no fim da lista,
        #   marcadas, porque não são jogos que ela tem: são decisões que ela
        #   tomou.
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
                "nome": registro.get("nome") or "appid %s" % appid,
                "url": "", "cartao": False,
                "acao": linha["acao"], "motivo": linha["motivo"],
                "gasto": appid in gastos, "apagado_em": registro.get("data", ""),
                "no_disco": False, "sem_manifesto": True,
            })
        fora.sort(key=lambda j: j["nome"].lower())
        orfas.sort(key=lambda j: j["appid"])
        fora.extend(orfas)
        return {"jogos": fora, "total": len(fora), "mapa": MAPA_JOGOS}

    def _api_jogo_fora(self, corpo):
        """Grava (ou tira) a linha de um jogo no `jogos-fora.map`.

        NÃO APAGA NADA. Quem apaga é o `scripts/jogos_steam.sh`, na passagem
        seguinte, com as guardas dele (Steam fechada, biblioteca montada, e o
        caminho vindo do `installdir` do manifesto, nunca deste mapa).
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
        # `#`. Deixar os dois passarem faria a própria linha dela virar outra
        # coisa na leitura seguinte — a página não pode escrever um arquivo que
        # ela mesma não conseguiria reler.
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

        # O ARQUIVO INTEIRO SOBREVIVE — só a linha do jogo muda. O cabeçalho
        # deste mapa tem cinquenta linhas explicando cada decisão; reescrevê-lo
        # filtrando linhas seria apagar o motivo junto com a regra. Mesma
        # disciplina do `_api_app_icone`.
        novas = list(linhas)
        indice = next((i for i, l in enumerate(novas) if id_da_linha(l) == appid), None)

        if remover:
            if indice is None:
                return self._json({"ok": True, "removido": False, "appid": appid})
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
        try:
            with open(MAPA_JOGOS, "w", encoding="utf-8") as fh:
                fh.write("\n".join(novas))
        except OSError as e:
            return self._json({"erro": "não consegui gravar o mapa: %s" % e}, 500)
        return self._json({"ok": True, "appid": appid, "acao": "" if remover else acao,
                           "removido": remover,
                           "depois": "vale depois de \"Arrumar os jogos no lançador\""})

    def _api_glifos(self, consulta):
        """O acervo de desenhos que a página pode oferecer para um aplicativo.

        Dois lugares, e a diferença importa:
          · `arcticons-apps/` são os 39 já escolhidos e presentes no repositório;
          · `upstream/` é o pack Arcticons inteiro (21 mil), baixado uma vez.
        Escolher um do upstream COPIA o arquivo para `arcticons-apps/`, porque é
        de lá que o `icones_apps_arcticons.sh` lê — a página faz o que o
        comentário daquele script manda fazer à mão.
        """
        busca = (consulta.get("busca", [""])[0] or "").strip().lower()
        limite = 60
        fora, vistos = [], set()
        # O `upstream/` NÃO É O ARCTICONS — e eu supus que era.
        #   A validação mediu: "assets/icones/upstream/ contém papirus-folders,
        #   não Arcticons: 21.844 SVGs dos quais 21.000 são folder-cat-*.svg".
        #   Buscar "steam" devolvia um glifo do Steam e 56 PASTAS coloridas.
        #   Oferecer pasta como ícone de aplicativo é pior que não oferecer
        #   nada: ela escolheria uma, salvaria, e o lançador ficaria com uma
        #   pasta no lugar do programa.
        #   As fontes certas são os acervos de APLICATIVO do repositório, e é só
        #   isso que esta rota mostra agora.
        for pasta, grupo in (("arcticons-apps", "traço (Arcticons)"),
                             ("autorais", "desenho nosso"),
                             ("convertidos-apps", "convertido"),
                             ("catppuccin-apps", "Catppuccin")):
            raiz = os.path.join(RAIZ, "assets", "icones", pasta)
            if not os.path.isdir(raiz):
                continue
            for dirpath, _, nomes in os.walk(raiz):
                for nome in sorted(nomes):
                    if not nome.endswith(".svg"):
                        continue
                    glifo = nome[:-4]
                    if glifo in vistos:
                        continue
                    if busca and busca not in glifo.lower():
                        continue
                    vistos.add(glifo)
                    caminho = os.path.join(dirpath, nome)
                    fora.append({"glifo": glifo, "grupo": grupo,
                                 "url": "/previa?tipo=arquivo&id=" + quote(caminho, safe="")})
                    if len(fora) >= limite:
                        return self._json({"glifos": fora, "limitado": True})
        return self._json({"glifos": fora, "limitado": False})

    def _api_app_icone(self, corpo):
        """Grava a escolha dela no mapa do repositório — e traz o glifo junto."""
        import re as _re
        import shutil as _shutil

        app = str(corpo.get("app", "")).strip()
        glifo = str(corpo.get("glifo", "")).strip()
        cor = str(corpo.get("cor", "")).strip()
        remover = bool(corpo.get("remover"))
        if not app or not _re.match(r"^[A-Za-z0-9._+-]{1,120}$", app):
            return self._json({"erro": "aplicativo inválido"}, 400)

        caminho = os.path.join(RAIZ, "assets", "icones", "apps-arcticons.map")
        try:
            with open(caminho, "r", encoding="utf-8") as fh:
                linhas = fh.read().split("\n")
        except OSError as e:
            return self._json({"erro": "não achei o mapa: %s" % e}, 500)

        def id_da_linha(l):
            corte = l.strip()
            if not corte or corte.startswith("#"):
                return None
            return corte.split(":")[0].strip()

        # O ARQUIVO INTEIRO SOBREVIVE — só a linha do aplicativo muda.
        #   A primeira versão reescrevia o mapa filtrando as linhas em branco, e
        #   o `git diff` do teste mostrou o estrago: um arquivo de 350 linhas,
        #   com blocos de comentário que explicam cada decisão de cor, perdeu
        #   suas separações. Editar a configuração de alguém não é reformatar o
        #   arquivo dela.
        novas = list(linhas)
        indice = next((i for i, l in enumerate(novas) if id_da_linha(l) == app), None)
        if remover:
            if indice is None:
                return self._json({"ok": True, "removido": False, "app": app})
            del novas[indice]
            with open(caminho, "w", encoding="utf-8") as fh:
                fh.write("\n".join(novas))
            return self._json({"ok": True, "removido": True, "app": app})

        if not _re.match(r"^[a-z0-9._-]{1,60}$", glifo):
            return self._json({"erro": "glifo inválido"}, 400)
        cores = set((_paleta_dados().get("ordem") or []))
        if cores and cor not in cores:
            return self._json({"erro": "a cor tem de ser um nome da paleta"}, 400)

        # O GLIFO TEM DE EXISTIR EM `arcticons-apps/` — é de lá que o construtor
        # lê. Se ela escolheu um do acervo grande, ele vem junto: é isso que faz
        # a página "atuar no repositório" em vez de mandar recado.
        destino_glifo = os.path.join(RAIZ, "assets", "icones", "arcticons-apps", glifo + ".svg")
        copiou = False
        if not os.path.isfile(destino_glifo):
            achado = ""
            up = os.path.join(RAIZ, "assets", "icones", "upstream")
            for dirpath, _, nomes in os.walk(up):
                if glifo + ".svg" in nomes:
                    achado = os.path.join(dirpath, glifo + ".svg")
                    break
            if not achado:
                return self._json({"erro": "não achei o desenho '%s' no acervo" % glifo}, 404)
            try:
                _shutil.copy2(achado, destino_glifo)
                copiou = True
            except OSError as e:
                return self._json({"erro": "não consegui trazer o desenho: %s" % e}, 500)

        # REPETIR GLIFO OU COR FAZ O GERADOR ESTOURAR, a menos que a linha diga
        # `alias` — está no cabeçalho do mapa. A página não pode deixar ela cair
        # nessa armadilha, então detecta a repetição e grava o `alias` sozinha,
        # dizendo que fez isso.
        mapa = self._mapa_arcticons()
        repetido = any(m["glifo"] == glifo or m["cor"] == cor
                       for chave, m in mapa.items() if chave != app)
        linha = "%s:%s:%s%s" % (app, glifo, cor, ":alias" if repetido else "")

        if indice is not None:
            novas[indice] = linha
        else:
            # Entra junto das outras linhas ativas — depois da última — para o
            # arquivo continuar lendo como uma lista, e não como um comentário
            # com uma linha solta no fim.
            ultima = max((i for i, l in enumerate(novas) if id_da_linha(l)), default=None)
            if ultima is None:
                novas.append(linha)
            else:
                novas.insert(ultima + 1, linha)
        try:
            with open(caminho, "w", encoding="utf-8") as fh:
                fh.write("\n".join(novas))
        except OSError as e:
            return self._json({"erro": "não consegui gravar o mapa: %s" % e}, 500)
        return self._json({"ok": True, "app": app, "glifo": glifo, "cor": cor,
                           "alias": repetido, "trouxe_do_acervo": copiou,
                           "depois": "vale depois de \"Reconstruir o tema de ícones\""})

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
        # 1 MB bastava enquanto o POST só carregava chave e valor. Desde que a
        # página envia ARQUIVO para o acervo (um papel de parede tem 2 a 8 MB, e
        # base64 cresce um terço), o teto sobe — mas só para essa rota. As
        # outras continuam recusando corpo grande, que é o que impede um POST
        # forjado de encher a memória do servidor.
        teto = (20 << 20) if alvo.path == "/api/acervo" else (1 << 20)
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
        # memória do JavaScript. Ele não vai para localStorage (sobreviveria à
        # sessão, e o token não deve) nem fica na barra de endereço depois do
        # primeiro carregamento — o `app.js` o apaga da URL com `replaceState`.
        texto = texto.replace("@TOKEN@", html.escape(TOKEN, quote=True))
        return self._responder(texto, tipo=TIPOS[".html"], plantar_cookie=True)

    def _api_get(self, caminho, consulta):
        if caminho == "/api/esquema":
            return self._json(self._dados_esquema())

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
            return self._json({
                "id": trabalho.id, "rotulo": trabalho.rotulo,
                "linhas": linhas, "proximo": total,
                "vivo": trabalho.vivo(), "rc": trabalho.rc,
                "segundos": round((trabalho.fim or time.time()) - trabalho.comeco, 1),
            })

        # LEVAR EMBORA — as duas saídas do botão "Exportar".
        #   `.conf` é o arquivo dela, para guardar ou levar para outra máquina;
        #   `.html` é esta página inteira num arquivo só, para quem for
        #   redesenhar o layout poder mexer nela sem ter o projeto instalado.
        if caminho == "/api/exportar/conf":
            texto, nome = exportar_conf()
            return self._baixar(texto, nome, "text/plain; charset=utf-8")

        if caminho == "/api/exportar/pagina":
            texto, nome = self._exportar_pagina()
            return self._baixar(texto, nome, TIPOS[".html"])

        return self._recusar(404, "não existe aqui")

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

    # ========================================================================
    # A PÁGINA INTEIRA NUM ARQUIVO SÓ
    # ========================================================================
    # O que sai daqui abre com dois cliques em qualquer máquina, sem Python,
    # sem servidor e sem o projeto instalado: as vinte e quatro abas, o menu
    # lateral, os cartões com os valores que estão no meow.conf dela agora, e
    # uma amostra das imagens de verdade (papéis de parede, ícones, capas).
    #
    # COMO ELE FUNCIONA, EM UMA FRASE
    #   É o `app.js` DE VERDADE — o mesmo arquivo, sem uma linha diferente —
    #   rodando contra dados congelados. O que muda é um prelúdio de trinta
    #   linhas que troca o `fetch` por uma leitura do JSON embutido e o `src`
    #   das imagens pelo `data:` correspondente. Reescrever uma segunda versão
    #   da página para exportar seria criar a terceira cópia da mesma tela, e
    #   ela envelheceria em uma semana.
    #
    # O QUE ELE NÃO FAZ, E DIZ QUE NÃO FAZ
    #   Nada nele grava, roda ou apaga: sem servidor não há para onde mandar.
    #   Clicar em "Rodar" mostra o aviso em vez de fingir que rodou. É a mesma
    #   honestidade do modo seco, levada ao extremo.
    #
    # AS IMAGENS SÃO AMOSTRA, E O ARQUIVO DIZ ISSO
    #   O acervo tem 46 papéis no carrossel, 255 banidos, 64 ícones e 23 capas.
    #   Embutir tudo daria dezenas de megabytes num arquivo feito para ser
    #   mandado por mensagem. Entram as primeiras de cada tipo, com teto por
    #   imagem e teto total; o que não coube fica com o quadro vazado, que é
    #   informação e não defeito — o layout precisa saber desenhar a ausência.
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

        # O gato do cabeçalho: ele não é prévia, é o acervo, e é o rosto da
        # página. Entra sempre, e é pequeno.
        gato_svg = os.path.join(RAIZ, "assets", "gatos",
                                "%s.svg" % os.path.basename(
                                    (valores_efetivos(["LOGO"]) or {}).get("LOGO") or "coquinha"))
        uri, gasto = self._embutir(gato_svg, mapa, gasto)
        if uri:
            mapa["/gato.svg"] = uri

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
        flavor = valores.get("FLAVOR") or "mocha"
        if valores.get("MODO") == "claro":
            flavor = "latte"
        paleta = paleta_css(flavor, valores.get("ACCENT") or "mauve")

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
        corpo = re.sub(r'<script src="/app\.js"></script>', "", corpo)
        corpo = corpo.replace("</body>", "").replace("</html>", "")

        dados = {
            "esquema": esquema, "apps": apps, "jogos": jogos,
            "previas": previas_congeladas, "imagens": imagens,
            "exportado_em": time.strftime("%d/%m/%Y às %H:%M"),
            "maquina": {"flavor": flavor, "accent": valores.get("ACCENT") or "mauve",
                        "modo": valores.get("MODO") or ""},
            "amostra": {"imagens": len(imagens), "bytes": gasto},
        }

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
            # e derrubaria a página inteira. É o único escape que este bloco
            # precisa, e ele não muda o dado — `<\/` e `</` são a mesma string
            # depois do `JSON.parse`.
            '<script id="meow-dados" type="application/json">%s</script>'
            % json.dumps(dados, ensure_ascii=False).replace("</", "<\\/"),
            "<script>\n%s\n</script>" % ler("standalone.js"),
            "<script>\n%s\n</script>" % ler("app.js"),
            "</body>",
            "</html>",
        ]
        return "\n".join(partes), "meowsystem-painel-%s.html" % _carimbo()

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
        return {
            "conf": CONF,
            "conf_existe": os.path.isfile(CONF),
            "exemplo": CONF_PADRAO,
            "raiz": RAIZ,
            "chaves": esquema,
            # Quais combinações de FLAVOR × ACCENT existem de verdade: a
            # página avisa ANTES de ela salvar uma que o instalador recusa.
            "capturas": _capturas_no_disco(),
            # `escreve` é DERIVADO (ver a função de mesmo nome), nunca
            # digitado por ação. E as opções da ação `oculta` não vão: o
            # argumento dela é uma imagem escolhida na galeria, e mandar os
            # 255 nomes de `banidos/` em toda leitura do esquema seria peso
            # puro numa lista que ninguém vai ler como lista.
            "acoes": [
                dict(v, id=k,
                     argv=" ".join(shlex.quote(p) for p in v["argv"]),
                     escreve=escreve(v),
                     opcoes=([] if v.get("oculta")
                             else PROVEDORES[v["arg"]]() if "arg" in v else []))
                for k, v in ACOES.items()
            ],
            "folhas": self._folhas(),
            "descricoes": DESCRICAO_SECAO,
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
            seco = bool(corpo.get("seco"))
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
            rc, saida = definir(chave, valor, seco=seco)
            return self._json({"rc": rc, "saida": saida, "chave": chave, "valor": valor})

        if caminho == "/api/acervo":
            return self._api_acervo(corpo)

        if caminho == "/api/app-icone":
            return self._api_app_icone(corpo)

        if caminho == "/api/jogo-fora":
            return self._api_jogo_fora(corpo)

        if caminho == "/api/rodar":
            acao = str(corpo.get("acao", ""))
            argumento = str(corpo.get("argumento", "") or "")
            seco = bool(corpo.get("seco"))
            # `confirmado` é a resposta à pergunta que o servidor recusou fazer
            # sozinho. Ele não vem de um cabeçalho nem de um parâmetro de URL,
            # e sim do corpo do POST: é a página que tem de dizer, com todas as
            # letras, que perguntou e ouviu sim.
            trabalho, erro = iniciar(acao, argumento, seco,
                                     confirmado=bool(corpo.get("confirmado")))
            if erro:
                # O erro estruturado (a confirmação que falta) passa inteiro; o
                # erro de sempre continua sendo uma frase, como a página espera.
                return self._json(erro if isinstance(erro, dict) else {"erro": erro}, 409)
            # `escreve` vai junto porque o CÓDIGO 1 QUER DIZER DUAS COISAS, e a
            # página precisa saber qual — visto na tela em 01/09/2026, quando um
            # `meow status` (que só lê) terminou com a pastilha "mexeu e
            # consertou". O contrato do projeto é "1 = divergia e consertei" para
            # quem ESCREVE; para quem só olha — `status`, `doctor` sem
            # `--consertar`, `tema`, `apps`, `leitura` — o mesmo 1 quer dizer "há
            # divergências", e nada foi consertado.
            return self._json({"id": trabalho.id, "rotulo": trabalho.rotulo,
                               "comando": " ".join(shlex.quote(p) for p in trabalho.argv),
                               "seco": bool(seco and ACOES[acao].get("seco")),
                               "escreve": escreve(ACOES[acao])})

        # TRAZER DE VOLTA — só analisa e devolve o que mudaria; quem grava é o
        # `Salvar e aplicar` de sempre. O porquê está em `importar_conf`.
        if caminho == "/api/importar":
            texto = str(corpo.get("texto", ""))
            if not texto.strip():
                return self._json({"erro": "o arquivo veio vazio"}, 400)
            return self._json(importar_conf(texto))

        if caminho == "/api/parar":
            try:
                trabalho = TRABALHOS[int(corpo.get("id", -1))]
            except (KeyError, ValueError, TypeError):
                return self._json({"erro": "trabalho desconhecido"}, 404)
            return self._json({"parado": trabalho.parar()})
        return self._recusar(404, "não existe aqui")

    def _folhas(self):
        """As folhas visuais versionadas, lidas do índice de docs/folhas/."""
        try:
            nomes = sorted(f for f in os.listdir(FOLHAS) if f.endswith(".html"))
        except OSError:
            return []
        return [{"arquivo": n, "caminho": os.path.join(FOLHAS, n)} for n in nomes]


# ============================================================================
# O PAINEL MORRE COM A JANELA QUE O ABRIU — 02/09/2026
# ============================================================================
# Pedido dela, olhando o ícone do lançador não fazer o que devia: "era pra ele
# abrir o chrome e quando eu fechar ele via navegador ele ser finalizado".
#
# O QUE HAVIA ANTES, E POR QUE FALHAVA NESTA MÁQUINA
#   O `.desktop` nascia com `Terminal=true` de propósito: a janela do terminal
#   era o interruptor, e fechá-la derrubava o servidor. O journal de 02/09/2026
#   mostra no que isso deu — dois cliques dela, às 03:22:28 e às 03:22:44, e nos
#   dois a mesma linha:
#
#       app-cosmic-com.meowsystem.Painel-44306.scope: PID 44306 vanished before
#       we could move it to target cgroup … Failed with result 'resources'
#
#   O terminal do COSMIC é instância única: o processo que o lançador criou
#   conversou com a instância já aberta e saiu no mesmo instante — daí o
#   "vanished" — e o painel foi parar numa ABA do terminal DELA. O `app.pid`
#   gravado às 03:22:44.587, três décimos depois do clique, prova que o servidor
#   chegou a subir; ele morreu junto quando aquela aba fechou. Um interruptor
#   que ela não vê não é interruptor.
#
# O SINAL É UMA CONEXÃO ABERTA, E NÃO UMA BATIDA POR TEMPORIZADOR
#   A saída óbvia era a página pingar `/api/vivo` de tantos em tantos segundos.
#   Ela quebra justamente no navegador dela: o Chrome limita o temporizador de
#   uma aba oculta a uma vez por minuto e depois congela a aba inteira — trocar
#   de aba mataria o painel, e isso é pior que o defeito que estamos curando.
#
#   Então o sinal é uma conexão que fica ABERTA (`/api/pulso`, um
#   `text/event-stream` que só manda comentário). Ela não depende de
#   temporizador nenhum: some no instante em que a janela fecha, porque o socket
#   fecha com ela.
#
#   O `EventSource` reconecta sozinho, e é isso que faz o F5 não matar o painel:
#   a página recarrega, o pulso volta em menos de um segundo, e a CARÊNCIA
#   abaixo cobre o intervalo. Pelo mesmo motivo ela cobre a troca de papel de
#   parede que recarrega a página inteira.
#
# TRABALHO RODANDO ADIA A SAÍDA
#   Fechar a janela no meio de um `./install.sh` não pode virar meia instalação.
#   Enquanto houver trabalho vivo o servidor fica de pé, e sai quando ele
#   terminar — o `finally` do `main()` continua sendo a rede de baixo.
#
# NADA DISSO VALE QUANDO O PAINEL FOI SUBIDO PARA TESTE
#   O vigia só liga com `MEOW_APP_VIGIA=1`, que é o `run.sh` no modo normal quem
#   passa. O `--sem-abrir` de `tests/app-navegador.py` sobe um servidor SEM
#   página nenhuma e o derruba pelo terminal: com o vigia ligado, ele se mataria
#   sozinho no meio do teste.
VIGIA_LIGADO = os.environ.get("MEOW_APP_VIGIA") == "1"
# Quanto tempo sem NENHUM pulso antes de sair. Oito segundos é folga larga para
# um F5 (que volta em menos de um) e curto o bastante para a porta não ficar
# aberta depois de ela fechar a janela.
VIGIA_CARENCIA = float(os.environ.get("MEOW_APP_CARENCIA") or 8)
# E se a página nunca abrir — navegador que não subiu, clique que se perdeu — o
# servidor não pode ficar de pé para sempre esperando ninguém.
VIGIA_ESPERA = float(os.environ.get("MEOW_APP_ESPERA") or 120)
# De quanto em quanto tempo o pulso escreve. A escrita é a rede de baixo: quem
# descobre a janela fechada NA HORA é o `select` sobre o mesmo socket — fechada
# a aba, ele fica legível com fim-de-arquivo, e o pulso cai no mesmo segundo.
# Sem o `select`, a saída dependia da escrita seguinte e chegava a demorar os
# quinze segundos inteiros (medido em 02/09/2026, antes desta linha existir).
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


def main():
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
        # O `app.pid` é do `run.sh`, e quem o apaga é o `--parar` dele. Só que
        # desde 02/09/2026 o caminho normal de saída é ESTE — a janela fecha e o
        # servidor sai sozinho —, e um pid de processo morto ali faria o
        # `meow abrir --estado` responder pela última vez que alguém usou o
        # `--parar`. Apagar só se o número for o NOSSO: dois painéis abertos ao
        # mesmo tempo não podem se apagar um ao outro.
        try:
            arquivo_pid = os.path.join(ESTADO, "app.pid")
            with open(arquivo_pid, "r", encoding="utf-8") as fh:
                if fh.read().strip() == str(os.getpid()):
                    os.unlink(arquivo_pid)
        except (OSError, ValueError):
            pass
        servidor.server_close()


if __name__ == "__main__":
    main()

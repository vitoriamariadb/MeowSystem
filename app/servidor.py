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

import hashlib
import hmac
import html
import json
import os
import queue
import re
import secrets
import struct
import shlex
import signal
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
CONF_PADRAO = os.environ.get("MEOW_CONF_PADRAO") or os.path.join(RAIZ, "meow.conf.exemplo")
CONF = os.environ.get("MEOW_CONF") or os.path.expanduser("~/.config/meow/meow.conf")
PALETA = os.path.join(RAIZ, "assets", "paleta", "catppuccin.json")
FOLHAS = os.path.join(RAIZ, "docs", "folhas")

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


def _opcoes(chave, ajuda, inline):
    """A primeira linha, da ajuda ou do comentário de linha, que seja `a | b | c`.

    O `LOGO` é a única lida do DISCO, pelo mesmo motivo do `bin/meow`: as
    variantes são ARQUIVOS em `assets/gatos/`, e uma lista escrita aqui ficaria
    velha no dia em que ela desenhasse outro gato.
    """
    if chave in ("LOGO", "LOGO_DIA", "LOGO_NOITE", "FASTFETCH_LOGO_GATO"):
        gatos = _gatos()
        if gatos:
            return gatos
    for linha in (ajuda.splitlines() + [inline]):
        if "|" not in linha:
            continue
        texto = linha.lstrip("#")
        texto = texto.split("(", 1)[0]
        tokens = [t.strip() for t in texto.split("|")]
        if not tokens or any(not RE_TOKEN_OPCAO.match(t) for t in tokens):
            continue
        return tokens
    return []


def _opcoes_finais(chave, ajuda, inline, padrao):
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
    """
    opcoes = [o for o in _opcoes(chave, ajuda, inline) if o != "vazio"]
    if not opcoes and padrao in ("sim", "nao"):
        return ["sim", "nao"]
    return opcoes


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
        return None
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
            "frase": _frase_curta(ajuda, inline),
            "padrao": _valor_da_linha(linha),
            # `vazio` NÃO É UM VALOR, É A AUSÊNCIA DELE — e escrevê-lo seria um bug
            #   Três chaves documentam `nao | sim | vazio (= não toca)`. Lido ao pé
            #   da letra, o `vazio` vira mais um token da lista, e um clique nele
            #   gravaria `RELOGIO_SEGUNDOS="vazio"` — que não é `sim`, não é `nao`,
            #   e cairia no `*)` de qualquer `case` do projeto sem nada avisar.
            #   Aqui ele sai da lista de opções e vira o terceiro estado do
            #   controle, que é o que a prosa do arquivo quer dizer.
            "opcoes": _opcoes_finais(chave, ajuda, inline, _valor_da_linha(linha)),
            "faixa": _faixa_confere(_faixa(ajuda, inline), _valor_da_linha(linha)),
            # Que prévia visual esta chave merece. Deduzido do conteúdo dela —
            # ver `_tipo_de_previa`, que explica por que não há lista aqui.
            "previa": _tipo_de_previa(
                chave,
                _opcoes_finais(chave, ajuda, inline, _valor_da_linha(linha)),
                _faixa_confere(_faixa(ajuda, inline), _valor_da_linha(linha)),
                _valor_da_linha(linha)),
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
PROVEDORES = {
    "capturas": _capturas,
    "gatos": _gatos,
    "modos": lambda: ["claro", "escuro", "auto"],
}


def _meow(*args):
    return [os.path.join(RAIZ, "bin", "meow"), *args]


ACOES = {
    # --- o ciclo de vida -----------------------------------------------------
    "instalar": {
        "rotulo": "Instalar / reaplicar tudo",
        "grupo": "Ciclo de vida",
        "argv": [os.path.join(RAIZ, "install.sh")],
        "seco": True, "sudo": True, "confirma": True, "rede": True,
        "ajuda": "Roda as 49 etapas do install.sh. Idempotente: numa máquina já "
                 "vestida a segunda passagem não escreve um byte.",
    },
    "doctor": {
        "rotulo": "Conferir (doctor)",
        "grupo": "Ciclo de vida",
        "argv": _meow("doctor"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Roda as 42 conferências em seco e lista o que está fora do "
                 "lugar. Não escreve nada, nunca usa sudo e nunca baixa nada.",
    },
    "doctor_consertar": {
        "rotulo": "Consertar o que estiver fora",
        "grupo": "Ciclo de vida",
        "argv": _meow("doctor", "--consertar"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Confere e aplica só o que falhou. É o mesmo que o timer das 5h "
                 "faz sozinho.",
    },
    "status": {
        "rotulo": "Estado da máquina",
        "grupo": "Ciclo de vida",
        "argv": _meow("status"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Flavor, accent, tema ativo, ícones, papel de parede.",
    },
    "desinstalar": {
        "rotulo": "Desinstalar o MeowSystem",
        "grupo": "Ciclo de vida",
        "argv": [os.path.join(RAIZ, "install.sh"), "--uninstall"],
        "seco": True, "sudo": False, "confirma": True, "destrutivo": True,
        "ajuda": "Tira o tema, os ícones, as unidades e a CLI. NÃO apaga o clone, "
                 "nem os backups, nem o acervo de papel de parede.",
    },
    "log": {
        "rotulo": "Últimas 50 linhas do log",
        "grupo": "Ciclo de vida",
        "argv": _meow("log"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "O que este projeto escreveu, e quando.",
    },
    # --- tema ----------------------------------------------------------------
    "tema": {
        "rotulo": "Tema: estado e capturas",
        "grupo": "Tema e cor",
        "argv": _meow("tema"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "O tema alvo, o que está de fato aplicado e as capturas que existem.",
    },
    "tema_aplicar": {
        "rotulo": "Aplicar uma captura",
        "grupo": "Tema e cor",
        "argv": _meow("tema", "@ARG@"), "arg": "capturas",
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Aplica a captura por CÓPIA de arquivo, sem passar pela GUI. "
                 "Guarda a árvore anterior em backups/ antes.",
    },
    "tema_modo": {
        "rotulo": "Claro / escuro / automático",
        "grupo": "Tema e cor",
        "argv": _meow("tema", "@ARG@"), "arg": "modos",
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Claro e escuro são o MESMO tema com um interruptor — por isso "
                 "trocar não pisca a interface. Grava MODO no meow.conf.",
    },
    "desfazer": {
        "rotulo": "Devolver o tema de antes do MeowSystem",
        "grupo": "Tema e cor",
        "argv": _meow("desfazer"),
        "seco": True, "sudo": False, "confirma": True, "destrutivo": True,
        "ajuda": "Volta o COSMIC ao backup pré-instalação desta máquina.",
        # `MEOW_SIM=1` só aqui, e só porque a página já perguntou: o `cmd_desfazer`
        # pede confirmação num `read`, e sem tty ele ficaria esperando para sempre
        # um ENTER que ninguém vai dar.
        "ambiente": {"MEOW_SIM": "1"},
    },
    # --- ícones e gato -------------------------------------------------------
    "icones": {
        "rotulo": "Ícones: estado",
        "grupo": "Ícones e gato",
        "argv": _meow("icones"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Qual tema de ícones está selecionado e quantos arquivos tem.",
    },
    "icones_reconstruir": {
        "rotulo": "Reconstruir o tema de ícones",
        "grupo": "Ícones e gato",
        "argv": _meow("icones", "reconstruir"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Remonta MeowSystem-Icons e as pastas coloridas. É o que faz uma "
                 "troca de ICONES_FLAVOR aparecer na tela.",
    },
    "logo_listar": {
        "rotulo": "Gatos: quem está no ar, e por quê",
        "grupo": "Ícones e gato",
        "argv": _meow("logo", "listar"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "O acervo, o gato em vigor e qual regra o escolheu (fase e janela).",
    },
    "logo_trocar": {
        "rotulo": "Pôr um gato no dock",
        "grupo": "Ícones e gato",
        "argv": _meow("logo", "@ARG@"), "arg": "gatos",
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Troca o botão do dock. Com LOGO_MODO=\"hora\" o relógio devolve "
                 "o gato dele na virada seguinte — para fixar, use LOGO_MODO=\"fixo\".",
    },
    "logo_girar": {
        "rotulo": "Passar ao próximo gato",
        "grupo": "Ícones e gato",
        "argv": _meow("logo", "girar"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Só tem efeito com LOGO_MODO=\"rotacao\"; no padrão o comando diz "
                 "isso em vez de fingir que girou.",
    },
    # --- papel de parede -----------------------------------------------------
    "wallpaper": {
        "rotulo": "Carrossel: estado",
        "grupo": "Papel de parede",
        "argv": _meow("wallpaper"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Pasta, quantas imagens, intervalo, ordem e se há imagem fixada.",
    },
    "wallpaper_proximo": {
        "rotulo": "Próximo papel de parede",
        "grupo": "Papel de parede",
        "argv": _meow("wallpaper", "proximo"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Avança e FIXA a imagem por WALLPAPER_FIXO_TTL (30 min por padrão).",
    },
    "wallpaper_anterior": {
        "rotulo": "Papel de parede anterior",
        "grupo": "Papel de parede",
        "argv": _meow("wallpaper", "anterior"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Volta uma imagem, com a mesma fixação do `próximo`.",
    },
    "wallpaper_carrossel": {
        "rotulo": "Soltar a fixação (voltar a girar)",
        "grupo": "Papel de parede",
        "argv": _meow("wallpaper", "carrossel"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Devolve a rotação agora, sem esperar o TTL acabar.",
    },
    "wallpaper_aplicar": {
        "rotulo": "Reafirmar a rotação",
        "grupo": "Papel de parede",
        "argv": _meow("wallpaper", "aplicar"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Reescreve o estado do cosmic-bg a partir das chaves WALLPAPER_*.",
    },
    "wallpaper_semear": {
        "rotulo": "Semear o acervo (BAIXA DA REDE)",
        "grupo": "Papel de parede",
        "argv": _meow("wallpaper", "semear"),
        "seco": True, "sudo": False, "confirma": True, "rede": True,
        "ajuda": "Reconstrói o acervo a partir do commit pinado e do FONTES.tsv. "
                 "Usa rede e pode demorar; respeita o BANIDOS.txt.",
    },
    # --- barra, janelas, leitura --------------------------------------------
    "painel_estado": {
        "rotulo": "Barra: diagnóstico",
        "grupo": "Barra e janelas",
        "argv": _meow("painel", "estado"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "O estado do painel, da dock e do supervisor meow-painel.service.",
    },
    "painel_teto": {
        "rotulo": "Barra: o teto do raio de canto",
        "grupo": "Barra e janelas",
        "argv": _meow("painel", "teto"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "A conta inteira — altura real, teto derivado, e se o compositor "
                 "em execução clampa o raio em vez de derrubar a barra.",
    },
    "painel_reciclar": {
        "rotulo": "Fazer a barra reler a configuração",
        "grupo": "Barra e janelas",
        "argv": _meow("painel", "reciclar"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "A barra pisca ~2 s. É o que faz um gato novo aparecer no dock "
                 "sem esperar o próximo login.",
    },
    "leitura": {
        "rotulo": "Modo de leitura: estado",
        "grupo": "Barra e janelas",
        "argv": _meow("leitura"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Que degrau o relógio pede agora, o que a tela mostra, e se o "
                 "compositor em execução sabe ler os dois números.",
    },
    "leitura_aplicar": {
        "rotulo": "Aplicar o degrau da hora",
        "grupo": "Barra e janelas",
        "argv": _meow("leitura", "aplicar"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Põe agora o que o timer poria sozinho.",
    },
    "leitura_remover": {
        "rotulo": "Desligar o modo de leitura",
        "grupo": "Barra e janelas",
        "argv": _meow("leitura", "remover"),
        "seco": True, "sudo": False, "confirma": True,
        "ajuda": "Zera temperatura e textura e desarma o meow-leitura.timer.",
    },
    "files_menu": {
        "rotulo": "Menu da área de trabalho: estado",
        "grupo": "Barra e janelas",
        "argv": _meow("files-menu"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Os dois itens de papel de parede no botão direito da área de trabalho.",
    },
    # --- aplicativos ---------------------------------------------------------
    "apps": {
        "rotulo": "Aplicativos: tabela",
        "grupo": "Aplicativos",
        "argv": _meow("apps"),
        "seco": False, "sudo": False, "confirma": False,
        "ajuda": "Módulo, aplicativo instalado, tema aplicado ou pendente.",
    },
    "apps_aplicar": {
        "rotulo": "Tematizar os aplicativos",
        "grupo": "Aplicativos",
        "argv": _meow("apps", "aplicar"),
        "seco": True, "sudo": False, "confirma": False,
        "ajuda": "Aplica o tema em todos os módulos de APPS_ATIVOS que estiverem "
                 "instalados. App ausente vira pendente, nunca falha.",
    },
}


# --- 5b. AS PRÉVIAS: ver o efeito antes de escolher --------------------------
#
# O PEDIDO DELA, EM 01/09/2026, E POR QUE ELE MUDA O DESENHO DA PÁGINA
#   "o que pega na página do opus, precisamos ter imagens disponíveis pra cada
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


def _prev_paredes():
    """Os quatro grupos do acervo. `banidos/` entra porque desbanir é um clique."""
    base = _wallpaper_base()
    fora = []
    for grupo, pasta in (("ativos", "ativos"), ("noite", "ativos-noite"),
                         ("dia", "ativos-dia"), ("favoritos", "favoritos"),
                         ("banidos", "banidos")):
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
            fora.append({"id": grupo + "/" + nome, "rotulo": nome,
                         "origem": arq, "grupo": grupo})
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
    """Os temas de cursor disponíveis, desenhados do XCursor de verdade."""
    fora = []
    for raiz_busca in (os.path.expanduser("~/.local/share/icons"),
                       os.path.expanduser("~/.icons"), "/usr/share/icons"):
        try:
            temas = sorted(os.listdir(raiz_busca))
        except OSError:
            continue
        for tema in temas:
            pasta = os.path.join(raiz_busca, tema, "cursors")
            if not os.path.isdir(pasta):
                continue
            # `default` é o nome canônico e `left_ptr` o histórico; um costuma
            # ser link simbólico para o outro, e qualquer um serve.
            alvo = None
            for cand in ("left_ptr", "default"):
                caminho = os.path.join(pasta, cand)
                if os.path.isfile(caminho):
                    alvo = os.path.realpath(caminho)
                    break
            if not alvo:
                continue
            # O nome que a chave CURSOR usa é o do diretório do tema, e nesta
            # máquina o acervo Catppuccin instala com o sufixo `-cursors`. A
            # chave aceita os dois; o rótulo mostra o diretório real.
            if any(f["id"] == tema for f in fora):
                continue
            fora.append({"id": tema, "rotulo": tema, "origem": alvo, "grupo": "cursor"})
            # O NOME DA CHAVE E O NOME DA PASTA NÃO SÃO O MESMO, e ignorar isso
            # deixava a chave `CURSOR` sem prévia justamente na máquina dela.
            # O `meow.conf` traz `CURSOR="catppuccin-mocha-light"`; o acervo
            # instala em `catppuccin-mocha-light-cursors`. Os dois funcionam
            # porque quem resolve é o caminho de busca do XCursor, que casa o
            # diretório pelo nome do tema — mas para achar o ARQUIVO aqui é
            # preciso conhecer as duas grafias. O apelido custa três linhas e faz
            # a prévia aparecer para o valor que ela de fato tem escrito.
            if tema.endswith("-cursors"):
                curto = tema[: -len("-cursors")]
                if not any(f["id"] == curto for f in fora):
                    fora.append({"id": curto, "rotulo": curto, "origem": alvo,
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
    if grupo:
        itens = [i for i in itens if i["grupo"] == grupo]
    fora, faltam = [], 0
    for item in itens:
        pronta = _previa_pronta(item, tipo)
        if not pronta:
            faltam += 1
            _enfileirar(item, tipo)
        fora.append({
            "id": item["id"], "rotulo": item["rotulo"], "grupo": item["grupo"],
            "pronta": pronta, "origem": item["origem"],
            "url": "/previa?tipo=%s&id=%s" % (tipo, quote(item["id"], safe="")),
        })
    return {"tipo": tipo, "itens": fora, "faltam": faltam}


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


def iniciar(acao_id, argumento, seco):
    """Começa uma ação. Devolve (trabalho, erro)."""
    global TRABALHO_ATUAL
    acao = ACOES.get(acao_id)
    if acao is None:
        return (None, "ação desconhecida")

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
    if seco and acao.get("seco"):
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
                   plantar_cookie=False):
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
        self.end_headers()
        self.wfile.write(corpo)

    def _json(self, dados, codigo=200):
        self._responder(json.dumps(dados, ensure_ascii=False), codigo=codigo)

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
            return self._api_get(caminho, consulta)

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
        if tamanho > 1 << 20:
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
            esquema = ler_esquema()
            chaves = [i["chave"] for i in esquema]
            brutos = valores_brutos()
            efetivos = valores_efetivos(chaves)
            for item in esquema:
                item["valor"] = brutos.get(item["chave"], "")
                item["efetivo"] = efetivos.get(item["chave"], "")
            return self._json({
                "conf": CONF,
                "conf_existe": os.path.isfile(CONF),
                "exemplo": CONF_PADRAO,
                "raiz": RAIZ,
                "chaves": esquema,
                "acoes": [
                    dict(v, id=k,
                         argv=" ".join(shlex.quote(p) for p in v["argv"]),
                         opcoes=(PROVEDORES[v["arg"]]() if "arg" in v else []))
                    for k, v in ACOES.items()
                ],
                "folhas": self._folhas(),
                # A paleta inteira vai junto: as amostras de flavor e de cor são
                # desenhadas com ela, e uma segunda viagem ao servidor para 4x26
                # valores seria viagem à toa.
                "paleta": {
                    "ordem": _paleta_dados().get("ordem_canonica", []),
                    "claros": _paleta_dados().get("claros", []),
                    "flavors": _paleta_dados().get("flavors", {}),
                },
            })

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
        return self._recusar(404, "não existe aqui")

    def _api_post(self, caminho, corpo):
        if caminho == "/api/definir":
            chave = str(corpo.get("chave", ""))
            valor = str(corpo.get("valor", ""))
            seco = bool(corpo.get("seco"))
            # A chave tem de estar no esquema. Sem esta linha a página poderia
            # gravar QUALQUER nome no meow.conf dela — inclusive um que o `. conf`
            # do shell fosse executar como variável de outro projeto.
            if chave not in {i["chave"] for i in ler_esquema()}:
                return self._json({"erro": "chave fora do meow.conf.exemplo"}, 400)
            rc, saida = definir(chave, valor, seco=seco)
            return self._json({"rc": rc, "saida": saida, "chave": chave, "valor": valor})

        if caminho == "/api/rodar":
            acao = str(corpo.get("acao", ""))
            argumento = str(corpo.get("argumento", "") or "")
            seco = bool(corpo.get("seco"))
            trabalho, erro = iniciar(acao, argumento, seco)
            if erro:
                return self._json({"erro": erro}, 409)
            # `escreve` vai junto porque o CÓDIGO 1 QUER DIZER DUAS COISAS, e a
            # página precisa saber qual — visto na tela em 01/09/2026, quando um
            # `meow status` (que só lê) terminou com a pastilha "mexeu e
            # consertou". O contrato do projeto é "1 = divergia e consertei" para
            # quem ESCREVE; para quem só olha — `status`, `doctor` sem
            # `--consertar`, `tema`, `apps`, `leitura` — o mesmo 1 quer dizer "há
            # divergências", e nada foi consertado.
            #
            # A resposta sai do `seco`, e as duas coincidem por uma razão e não
            # por acaso: `seco` marca a ação que aceita `MEOW_DRY_RUN=1`, e uma
            # ação que nunca escreve não tem o que prever — não haveria o que o
            # seco calasse. Quem só lê tem `seco: False` nas 30 ações de hoje.
            return self._json({"id": trabalho.id, "rotulo": trabalho.rotulo,
                               "comando": " ".join(shlex.quote(p) for p in trabalho.argv),
                               "seco": seco, "escreve": bool(ACOES[acao].get("seco"))})

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


def main():
    # Os operários de prévia sobem ANTES do servidor: o primeiro `/api/previas`
    # pode chegar no mesmo segundo em que a página abre, e uma fila sem ninguém
    # do outro lado deixaria as miniaturas eternamente "gerando".
    for _ in range(3):
        threading.Thread(target=_operario, daemon=True).start()
    servidor = ThreadingHTTPServer(("127.0.0.1", 0), Manipulador)
    servidor.daemon_threads = True
    porta = servidor.server_address[1]
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
        servidor.server_close()


if __name__ == "__main__":
    main()

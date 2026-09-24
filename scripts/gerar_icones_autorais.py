#!/usr/bin/env python3
"""Desenha os ícones autorais do pack, a partir da paleta dele, por papel.

DE ONDE VEM CADA DESENHO — 23/09/2026, sprint P26
    Duas fontes, e as duas nascem por papel:

    · as DECLARAÇÕES do pack — cada `icones/autorais/<nome>.json` é um desenho
      (papéis e o SVG com lacunas `{papel}`), lido e conferido pelo
      `scripts/pack.py`, que é o único que entende o formato de pack. O pack
      alcança as dele e as que herda: o Dracula gera o FogStripper e o Hefesto
      a partir das declarações do Catppuccin, na paleta do Dracula;
    · os nove desenhos de `DESENHOS`, abaixo — o painel do MeowSystem e os oito
      `com.system76.Cosmic*` —, que continuam funções aqui.

    ATÉ ESTA DATA O CABEÇALHO DIZIA "os ícones dos DOIS aplicativos da Vitória:
    FogStripper, Hefesto", e o problema estava na frase: um gerador bom, que
    servia dois aplicativos NOMEADOS NO PYTHON. Um terceiro não entrava sem
    editar código. Os dois saíram daqui e viraram os dois primeiros `.json` de
    `packs/catppuccin/icones/autorais/` — e a história de cada desenho foi
    junto, nos campos `_nota` do arquivo dele: por que o FogStripper é um
    quadro meio foto, meio xadrez; por que o Hefesto é um controle e não a
    bigorna; e as razões de contraste do touchpad, que abrem o parágrafo sobre
    flavor claro logo abaixo. NENHUM BYTE DOS SVG GERADOS MUDOU: o `--conferir`
    passou nos 44 do Catppuccin e nos 22 do Dracula antes e depois.

    Um nome nas duas fontes é recusa, e alta: dois desenhos para o mesmo
    arquivo de saída seria o último a escrever vencendo calado.

O DESENHO NASCE DA PALETA — NENHUM HEX É DIGITADO AQUI
    Mesma regra e mesmo motivo do `gerar_gato.py`: SVG escrito à mão sai fora da
    paleta sem ninguém notar. Cada forma declara um PAPEL (`sujeito`, `tinta`,
    `xadrez_a`...) e o papel resolve para um nome Catppuccin. Ou o nome existe na
    paleta, ou o script morre alto.

OS PAPÉIS SÃO SENSÍVEIS A FLAVOR CLARO, E ISSO NÃO É DETALHE
    No Mocha `text` é claro e `crust` é quase preto; no Latte os dois se
    invertem. Descrever o desenho por papel faz o Latte se resolver sozinho — o
    corpo do controle continua contrastando com o fundo do lançador nos dois.
    O `touchpad` do Hefesto foi o único que NÃO se resolveu sozinho, e o
    motivo vale nos DOIS extremos: o accent fica quase invisível contra o
    `corpo`. As razões de contraste WCAG que mediram isso (1,47 no Latte, 1,40
    no Mocha, contra o mínimo de 3,0) e o contorno de `tinta` que resolveu os
    dois flavors de uma vez moram desde 23/09/2026 no `_nota_touchpad` de
    `packs/catppuccin/icones/autorais/hefesto.json`, ao lado do desenho que
    elas explicam. A cor que o script usa vem da paleta do PACK ATIVO, e não
    de um caminho escrito aqui.

OS OITO APLICATIVOS DO PRÓPRIO SISTEMA
    Arquivos, Terminal, Loja, Configurações, Editor, Monitor, Reprodutor e
    Captura — os `com.system76.Cosmic*`. Eles eram os únicos aplicativos que ela
    abre todo dia ainda vestidos de fábrica: os SVGs de `/usr/share/icons/hicolor`
    são teal e azul-marinho do Pop!_OS (`#00717C`, `#102A4C`, `#49BAC8`), cores
    que não existem em Catppuccin nenhum. No lançador dela isso lia como um bloco
    estrangeiro no meio do resto.

    CADA UM TEM SUA COR, E ISSO É DELIBERADO
    A tentação é pintar os oito no accent dela e chamar de coeso. A 48px o
    resultado é o oposto: oito manchas mauve do mesmo tamanho, e achar o Terminal
    vira leitura de legenda. A cor é o que o olho usa para pré-selecionar antes
    de ler a forma. Então cada um leva uma cor Catppuccin própria, escolhida pela
    convenção do ramo (terminal verde, mídia rosa, alerta/medição vermelho), e a
    coesão vem de três outras coisas: a mesma paleta, o mesmo peso de traço
    (~3px a 48px) e a mesma regra de silhueta cheia sem gradiente.

    A ÚNICA EXCEÇÃO É O GESTOR DE ARQUIVOS, que usa o ACCENT — porque as pastas
    dentro dele já são `cat-<flavor>-<accent>`, e um ícone azul abrindo uma
    janela de pastas mauve seria a única incoerência visível do conjunto.

    NENHUM DELES USA GRADIENTE, e o original usava. `linearGradient` a 48px não
    aparece como volume: aparece como sujeira de compressão. As formas aqui são
    chapadas, que é como o Papirus (a base de ícones desta máquina) desenha —
    o conjunto novo tinha de conviver com 27 ícones dele na mesma tela.

    TODOS LEVAM CONTORNO, E ISSO FOI UM ERRO CORRIGIDO NA TELA DELA
    A primeira versão confiou na cor sozinha. Funcionou enquanto o dock era
    quase opaco; quando ele foi para `opacity 0.05`, o fundo dos ícones virou o
    PAPEL DE PAREDE — que gira num carrossel e naquele dia era lilás claro. O
    Gestor de Arquivos sumiu por completo: medido na captura dela, a pasta mauve
    era `srgb(203,166,247)` e o dock atrás `srgb(196,159,215)`. Sete pontos de
    diferença em dois canais.

    Contraste WCAG contra aquele fundo, calculado da própria paleta (mínimo
    legível para forma grande = 3,0):

        mauve 1,11 · red 1,02 · sapphire 1,20 · lavender 1,26
        player/pink 1,48 · green 1,52 · teal 1,52 · yellow 1,78

    Os OITO reprovam, e não é coincidência: os accents do Mocha são claros por
    construção, feitos para viver sobre fundo escuro. Sobre um papel de parede
    claro não existe accent que se salve. Os dois que ainda liam — Terminal e
    Monitor — liam pela MOLDURA escura, não pela cor.

    Então a moldura virou regra: todo ícone carrega um contorno de `tinta`
    (`crust` no escuro, `base` no claro), e é ele que faz a silhueta existir
    contra qualquer fundo. Os números fecham nos dois flavors — mauve x crust
    dá 9,23 no Mocha, e mauve x base dá 4,09 no Latte, onde o mauve é escuro e
    quem clareia é o contorno. A lição já estava escrita no touchpad do
    Hefesto (hoje no `hefesto.json` do pack); ela só não tinha sido aplicada
    onde o fundo é variável.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from xml.sax.saxutils import escape

RAIZ = Path(__file__).resolve().parent.parent
# A PALETA VEM DA PORTA ÚNICA DO LADO PYTHON — 22/09/2026
# Eram três linhas repetidas em seis arquivos, e as seis terminavam no mesmo
# literal: `assets/paleta/catppuccin.json`. A P13 mudou esse arquivo de casa (é
# `packs/catppuccin/paleta.json`) e derrubou a isenção que o cabeçalho do
# `meow_paleta` dava a quem é Python: `pack.py` é VIZINHO deste arquivo, e
# `scripts/` já é o `sys.path[0]` de quem o roda — não há sys.path a atravessar.
# A ordem de precedência inteira mora em `pack.paleta_do_pack_ativo()`.
import pack  # noqa: E402  — vizinho de arquivo, e o RAIZ acima precede

PALETA = Path(pack.paleta_do_pack_ativo())

# ONDE OS DESENHOS NASCEM — QUEM DIZ É O PACK, DESDE 22/09/2026
#   Era `RAIZ / "assets" / "icones" / "autorais"`, e o preço dessa linha foi
#   medido: aquele diretório guardava 55 desenhos de DOIS packs misturados — 44
#   do Catppuccin e 11 do Dracula —, num nome (`autorais`) que diz que são do
#   projeto e não diz de QUEM. A paleta já vinha do pack ativo desde a linha
#   acima; só o destino é que continuava cravado, e por isso o Dracula regerava
#   os desenhos dele dentro do acervo do vizinho.
#
#   E O QUE ISSO DEIXAVA QUEBRADO ERA O FLAVOR CLARO. O `alucard` nasceu em
#   19/09/2026 e ficou com ZERO dos onze: no modo claro do Dracula estes ícones
#   caíam no `latte`, que é o claro do OUTRO pack. O laço lá embaixo sempre
#   soube gerá-los — ele varre `paleta["flavors"]`, e a paleta do Dracula
#   declara os dois — mas ninguém rodava o gerador com a paleta do Dracula
#   porque o destino era o mesmo monte para todo mundo.
#
#   `dir_acervo` e não `acervo`: quem ESCREVE precisa do caminho mesmo quando o
#   diretório ainda não existe, e num pack novo ele não existe. O `padrao`
#   cobre o pack que não declarou a categoria — ele escreve em casa, nunca no
#   acervo de quem ele herda.
DESTINO = Path(pack.dir_acervo("icones.autorais.desenhos",
                               padrao="icones/autorais/"))

# Papel -> (nome Catppuccin em flavor escuro, nome em flavor claro).
#
# OS PAPÉIS DO FOGSTRIPPER E DO HEFESTO SAÍRAM DAQUI — 23/09/2026, sprint P26.
#   `foto`, `sol`, `xadrez_a`, `xadrez_b`, `corpo`, `tinta` e `touchpad` eram de
#   dois desenhos só, e foram com eles para o `papeis` de cada `.json` em
#   `packs/catppuccin/icones/autorais/`, com os mesmos nomes de cor. Esta tabela
#   ficou sendo o vocabulário dos nove desenhos que ainda são função aqui.
PAPEIS = {
    # Os oito do sistema
    "vazio":    ("crust", "base"),          # a tela do terminal e do monitor
    "borda":    ("surface1", "overlay0"),   # contorno que separa do fundo
    "trilho":   ("surface2", "surface2"),   # o sulco dos deslizadores
    # O CONTORNO NÃO É O MESMO QUE `tinta`, e a diferença é o Latte.
    # `tinta` inverte (crust/base) porque no Hefesto ela é a MARCA impressa no
    # corpo do controle, e ali inverter é certo. Aqui ela é a SILHUETA, e uma
    # silhueta quase branca (o `base` do Latte) desaparece contra papel de parede
    # claro — o pior caso caía para 2,00. Com `text` no claro, o contorno é
    # escuro nos DOIS flavors e o pior caso sobe para 3,53 no lilás dela, 7,99
    # no branco e 3,87 no preto. Só o cinza-50%-exato fica em 2,02, e nesse
    # fundo nenhum tema de ícone do mundo passa: é o ponto equidistante de tudo.
    "contorno": ("crust", "text"),          # a silhueta, contra qualquer fundo
    # A FOLHA NÃO INVERTE, e essa foi a única coisa que o Latte reprovou.
    # A primeira versão usava ("text","text"), copiado do `corpo` do Hefesto —
    # e ali inverter é certo, porque um controle preto no claro e branco no
    # escuro continua sendo um controle. Uma FOLHA, não: no Latte ela virava
    # #4C4F69 e o ícone lia como quadro-negro, não como documento. Papel é claro
    # nos dois flavors; quem resolve o contraste contra o lançador claro é o
    # contorno em `borda`, do mesmo jeito que na moldura do Terminal.
    "folha":    ("text", "base"),           # a página do editor
}
# `sujeito` usa o ACCENT do tema — vem por parâmetro. Numa declaração, o mesmo
# acento entra pelo marcador `<accent>` no papel.

# Cor de identidade de cada aplicativo do sistema. `__ACCENT__` é o accent dela.
# Ver o cabeçalho: a cor é o que separa oito ícones do mesmo tamanho a 48px.
IDENTIDADE = {
    "cosmic-files":      "__ACCENT__",  # casa com as pastas cat-<flavor>-<accent>
    "cosmic-term":       "green",       # a convenção de terminal, em todo tema
    "cosmic-store":      "sapphire",    # loja: azul, e o único azul do conjunto
    "cosmic-settings":   "lavender",    # vizinho do accent sem competir com ele
    "cosmic-edit":       "yellow",      # texto/edição, como o lápis do Papirus
    "cosmic-monitor":    "red",         # medição e alerta
    "cosmic-player":     "pink",        # mídia
    "cosmic-screenshot": "teal",        # captura: o verde-água que sobrou livre
}


# O FOGSTRIPPER E O HEFESTO MORAVAM AQUI — `_xadrez`, `fogstripper`, `_CORPO` e
# `hefesto` — até 23/09/2026. Eles são os dois primeiros desenhos DECLARADOS:
# `packs/catppuccin/icones/autorais/{fogstripper,hefesto}.json`, cada um com a
# docstring que tinha aqui transformada em `_nota`. O SVG de cada um foi tirado
# destas funções com uma lacuna `{papel}` no lugar de cada cor, e por isso o
# arquivo gerado continua byte a byte o mesmo.


# --- os oito do sistema ------------------------------------------------------
# Todos partilham o mesmo esqueleto: `viewBox` de 48, formas chapadas, traço de
# ~3px onde há traço, e a cor de identidade em `c['marca']`. O que muda de um
# para outro é só a silhueta — que é o que o olho lê depois da cor.

def _moldura(c: dict) -> str:
    """A tela retangular do Terminal e do Monitor.

    Os dois são "uma superfície escura com conteúdo em cima", e desenhar a mesma
    moldura nos dois é o que os faz parecer irmãos no lançador. O contorno em
    `borda` existe pelo Latte: lá o `vazio` é quase branco e, sem ele, a moldura
    desapareceria contra o fundo claro do lançador.
    """
    return (f'<rect x="3.5" y="8.5" width="41" height="31" rx="4.5" '
            f'fill="{c["vazio"]}" stroke="{c["contorno"]}" stroke-width="2"/>')


def cosmic_files(c: dict) -> str:
    """Pasta. A silhueta mais reconhecível que existe — não há o que inventar.

    A aba é uma forma só com o corpo (um `path`, não dois `rect` empilhados):
    empilhados, a junção aparece como um degrau de meio pixel a 48px, e o degrau
    lê como defeito de renderização.
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Gestor de Arquivos">
  <title>{c['titulo']}</title>
  <path d="M7 10 h9.8 c1.3 0 2.5 0.6 3.2 1.7 L21.6 14.4 H41 c2.5 0 4.5 2 4.5 4.5 v14.8 c0 2.5 -2 4.5 -4.5 4.5 H7 c-2.5 0 -4.5 -2 -4.5 -4.5 V14.5 c0 -2.5 2 -4.5 4.5 -4.5 z"
        fill="{c['marca']}" stroke="{c['contorno']}" stroke-width="2" stroke-linejoin="round"/>
</svg>
"""


def cosmic_term(c: dict) -> str:
    """Terminal: o prompt `>` e o cursor. Sem barra de título.

    A barra de título estava na primeira versão e saiu: a 48px ela come 6px de
    altura útil e o `>` fica pequeno demais para ser lido como prompt.
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Terminal">
  <title>{c['titulo']}</title>
  {_moldura(c)}
  <path d="M11.5 18.5 L18.5 24 L11.5 29.5" fill="none" stroke="{c['marca']}"
        stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>
  <rect x="22" y="26.4" width="13" height="3.2" rx="1.6" fill="{c['marca']}"/>
</svg>
"""


def cosmic_store(c: dict) -> str:
    """Loja: sacola de compras. A alça é traço, o corpo é cheio.

    Um ícone de "caixa/pacote" foi testado antes e confunde com o Warehouse
    (gerenciador de Flatpak) que ela tem instalado — dois ícones de caixa no
    mesmo lançador é pior que um ícone menos original.
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Loja de Aplicativos">
  <title>{c['titulo']}</title>
  <path d="M17.6 19.5 v-4.8 c0 -3.5 2.9 -6.4 6.4 -6.4 c3.5 0 6.4 2.9 6.4 6.4 v4.8"
        fill="none" stroke="{c['contorno']}" stroke-width="5.4" stroke-linecap="round"/>
  <path d="M17.6 19.5 v-4.8 c0 -3.5 2.9 -6.4 6.4 -6.4 c3.5 0 6.4 2.9 6.4 6.4 v4.8"
        fill="none" stroke="{c['marca']}" stroke-width="3" stroke-linecap="round"/>
  <path d="M9 17 h30 l-2.3 20.9 c-0.2 1.9 -1.8 3.3 -3.7 3.3 H15 c-1.9 0 -3.5 -1.4 -3.7 -3.3 z"
        fill="{c['marca']}" stroke="{c['contorno']}" stroke-width="2" stroke-linejoin="round"/>
</svg>
"""


def cosmic_settings(c: dict) -> str:
    """Configurações: três deslizadores.

    A engrenagem é o desenho óbvio e foi descartada: a 48px os dentes viram
    serrilha, e o COSMIC já usa engrenagem no applet de energia — repetir a forma
    faria dois "botões de sistema" idênticos na mesma barra. Deslizador diz
    "ajustar", que é o que ela faz aqui, e sobrevive ao tamanho.
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Configurações">
  <title>{c['titulo']}</title>
  <g fill="{c['trilho']}" stroke="{c['contorno']}" stroke-width="1.6">
    <rect x="6.8" y="12" width="34.4" height="4" rx="2"/>
    <rect x="6.8" y="22" width="34.4" height="4" rx="2"/>
    <rect x="6.8" y="32" width="34.4" height="4" rx="2"/>
  </g>
  <g fill="{c['marca']}" stroke="{c['contorno']}" stroke-width="2">
    <circle cx="16" cy="14" r="5"/>
    <circle cx="32" cy="24" r="5"/>
    <circle cx="21" cy="34" r="5"/>
  </g>
</svg>
"""


def cosmic_edit(c: dict) -> str:
    """Editor de Texto: folha com o canto dobrado e três linhas escritas.

    O canto dobrado é o que impede a folha de ler como "retângulo branco". As
    linhas são três, não cinco: a 48px, cinco linhas de 2px com 2px de respiro
    viram um bloco cinza chapado.
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Editor de Texto">
  <title>{c['titulo']}</title>
  <path d="M11 5.3 h16.1 L39.2 17.4 V39.7 c0 2.2 -1.8 4 -4 4 H11 c-2.2 0 -4 -1.8 -4 -4 V9.3 c0 -2.2 1.8 -4 4 -4 z"
        fill="{c['folha']}" stroke="{c['contorno']}" stroke-width="2" stroke-linejoin="round"/>
  <path d="M27.1 5.3 L39.2 17.4 h-8.1 c-2.2 0 -4 -1.8 -4 -4 z" fill="{c['borda']}"/>
  <g fill="{c['marca']}">
    <rect x="13" y="22" width="21" height="3.2" rx="1.6"/>
    <rect x="13" y="29" width="21" height="3.2" rx="1.6"/>
    <rect x="13" y="36" width="13" height="3.2" rx="1.6"/>
  </g>
</svg>
"""


def cosmic_monitor(c: dict) -> str:
    """Monitor do Sistema: a linha de um gráfico dentro da mesma moldura do Terminal.

    O pico fica em x=30 e não no centro de propósito: uma linha simétrica lê como
    ornamento, uma assimétrica lê como MEDIÇÃO. É a mesma razão pela qual todo
    gráfico de verdade tem o pico fora do meio.
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Monitor do Sistema">
  <title>{c['titulo']}</title>
  {_moldura(c)}
  <path d="M9.5 30.5 L16.5 22.5 L22 27 L30 14.5 L38.5 23.5" fill="none"
        stroke="{c['marca']}" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
"""


def cosmic_player(c: dict) -> str:
    """Reprodutor: o triângulo de play, vazado num disco cheio.

    Vazado, e não um triângulo solto: o triângulo sozinho tem área pequena e some
    entre ícones cheios. O disco dá a mancha de cor que o olho acha primeiro.
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Reprodutor de Mídia">
  <title>{c['titulo']}</title>
  <circle cx="24" cy="24" r="19" fill="{c['marca']}" stroke="{c['contorno']}" stroke-width="2"/>
  <path d="M20 15.6 L33 24 L20 32.4 Z" fill="{c['vazio']}"/>
</svg>
"""


def cosmic_screenshot(c: dict) -> str:
    """Captura de Tela: os quatro cantos do enquadramento e a lente no meio.

    Os cantos são quatro traços separados, não um retângulo tracejado: tracejado
    a 48px vira pontilhado irregular, porque o traço não fecha nas quinas.
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Captura de Tela">
  <title>{c['titulo']}</title>
  <g fill="none" stroke="{c['contorno']}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round">
    <path d="M5.5 17 V10 c0 -2.5 2 -4.5 4.5 -4.5 h7"/>
    <path d="M31 5.5 h7 c2.5 0 4.5 2 4.5 4.5 v7"/>
    <path d="M42.5 31 v7 c0 2.5 -2 4.5 -4.5 4.5 h-7"/>
    <path d="M17 42.5 h-7 c-2.5 0 -4.5 -2 -4.5 -4.5 v-7"/>
  </g>
  <g fill="none" stroke="{c['marca']}" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M5.5 17 V10 c0 -2.5 2 -4.5 4.5 -4.5 h7"/>
    <path d="M31 5.5 h7 c2.5 0 4.5 2 4.5 4.5 v7"/>
    <path d="M42.5 31 v7 c0 2.5 -2 4.5 -4.5 4.5 h-7"/>
    <path d="M17 42.5 h-7 c-2.5 0 -4.5 -2 -4.5 -4.5 v-7"/>
  </g>
  <circle cx="24" cy="24" r="7.2" fill="{c['marca']}" stroke="{c['contorno']}" stroke-width="2"/>
</svg>
"""


def meowsystem_painel(c: dict) -> str:
    """O painel do MeowSystem: uma cabeça de gato, e ela é DE TRAÇO.

    O ÚNICO DESENHO DESTE ARQUIVO QUE NÃO É CHAPADO, E O MOTIVO É A FOLHA DELA
        Em 11/08/2026 ela definiu o estilo do projeto olhando o lançador — traço
        de linha fino, `fill:none`, `stroke` pastel — e o desenho cheio deste
        gerador é o que ficou FORA do padrão, não dentro. Um ícone novo escrito
        hoje não tem por que repetir o estilo que ela já reprovou; ele nasce no
        traço que os vizinhos dele usam.

        Não é conversão retroativa: os outros dez continuam como estão, cada um
        com a sua história. Este é novo, e novo se escreve no padrão de agora.

    A CABEÇA VEM DAS ORELHAS PARA BAIXO, NUM CAMINHO SÓ
        Três desenhos foram rasterizados a 48px e olhados lado a lado com o
        Terminal e os Arquivos que já moram na dock dela (02/09/2026):
          · elipse com as orelhas soltas por cima — as pontas encostam na elipse
            e o cruzamento vira um nó de dois traços no mesmo pixel;
          · a cabeça contínua, orelha-testa-orelha, e a mandíbula fechando por
            baixo — lê como gato à primeira vista, e é esta;
          · a mesma com um deslizador atravessando o queixo, para dizer
            "configurar" — a 48px o deslizador cortava o rosto e o ícone deixava
            de ler como qualquer uma das duas coisas.

        A palavra "MeowSystem" fica ao lado do ícone no lançador e na dock: o
        desenho não precisa dizer "configuração" também.

    O ACCENT É A COR, COMO NOS ARQUIVOS
        Este é o aplicativo do PRÓPRIO tema — a cor dele é a cor que ela
        escolheu, e muda junto quando ela troca o `ACCENT`.
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="MeowSystem">
  <title>{c['titulo']}</title>
  <g fill="none" stroke="{c['sujeito']}" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round">
    <path d="M9.6 22.4 8.2 7.4l11.6 6.2a16 16 0 0 1 8.4 0l11.6-6.2-1.4 15"/>
    <path d="M9.6 22.4a14.4 14.4 0 1 0 28.8 0"/>
    <path d="M18.6 25v3M29.4 25v3"/>
    <path d="M24 31v1.8l-2.6 1.6M24 32.8l2.6 1.6"/>
  </g>
</svg>
"""


DESENHOS = {
    "meowsystem-painel": meowsystem_painel,
    "cosmic-files": cosmic_files,
    "cosmic-term": cosmic_term,
    "cosmic-store": cosmic_store,
    "cosmic-settings": cosmic_settings,
    "cosmic-edit": cosmic_edit,
    "cosmic-monitor": cosmic_monitor,
    "cosmic-player": cosmic_player,
    "cosmic-screenshot": cosmic_screenshot,
}


def main() -> int:
    p = argparse.ArgumentParser(description="Desenha os ícones autorais a partir da paleta.")
    p.add_argument("--accent", default="mauve",
                   help="cor do sujeito e do <accent> das declarações (padrão: mauve)")
    p.add_argument("--saida", type=Path, default=DESTINO)
    p.add_argument("--conferir", action="store_true", help="não escreve; sai 1 se algo divergir")
    args = p.parse_args()

    if not PALETA.is_file():
        sys.exit(f"ERRO: {PALETA} não existe — a paleta canônica é obrigatória.")
    paleta = json.loads(PALETA.read_text())
    claros = paleta.get("claros", [])

    # AS DECLARAÇÕES SÃO LIDAS ANTES DE ESCREVER A PRIMEIRA LINHA — 23/09/2026
    #   Uma declaração recusada no meio do laço deixaria metade dos flavors
    #   regerados e a outra metade não. Conferir tudo primeiro faz o erro sair
    #   com o pack intacto, dizendo o arquivo e o que consertar — a frase é do
    #   `pack.ler_autoral`, que é quem conhece o formato.
    #
    #   `pack.autorais()` segue o mesmo pack que o `DESTINO` e a `PALETA`: o do
    #   `MEOW_PACK_DIR`, ou o padrão. Ele sobe a herança para LER; quem escreve
    #   continua sendo este pack, em casa.
    declarados = {}
    try:
        for nome, (caminho, _dono) in sorted(pack.autorais().items()):
            declarados[nome] = pack.ler_autoral(caminho)
    except pack.Recusa as e:
        sys.exit(f"ERRO: declaração de desenho autoral recusada — {e}")
    repetidos = sorted(set(declarados) & set(DESENHOS))
    if repetidos:
        sys.exit(f"ERRO: {', '.join(repetidos)} tem duas fontes — uma função neste script "
                 f"e um .json no pack. Um nome, um desenho: tire um dos dois.")

    if not args.conferir:
        args.saida.mkdir(parents=True, exist_ok=True)

    # O TÍTULO DIZ O PACK DONO DO FLAVOR — 23/09/2026, P34 (anotado na P16b)
    #   Era `Catppuccin <Flavor>` cravado nas duas fontes, do tempo em que o
    #   gerador só pintava o Catppuccin. Com a paleta do pack ativo, os onze do
    #   Dracula saíam «Catppuccin Dracula» e «Catppuccin Alucard», e um pack de
    #   CSV sairia «Catppuccin Meutema». O nome vem do `pack.json` do MESMO pack
    #   de onde vêm a paleta e o destino — o `MEOW_PACK_DIR`, ou o padrão —, e
    #   sem `nome` fica o nome do diretório.
    #   O FLAVOR QUE SE CHAMA COMO O PACK NÃO SE REPETE: o `dracula` do Dracula
    #   seria «Dracula Dracula», gagueira e não informação. E o nome é texto de
    #   quem fez o pack, então entra escapado — um «Tom & Jerry» não pode tirar
    #   o `<title>` do XML. O `{titulo}` de uma declaração não escapa nada, e
    #   por isso o escape é daqui.
    ref = pack._ref_ativa(None)
    nome_do_pack = str(pack.campo(ref, "nome") or os.path.basename(str(ref).rstrip("/")))

    def titulo_de(nome: str, flavor: str) -> str:
        variante = flavor.capitalize()
        dono = nome_do_pack if variante == nome_do_pack else f"{nome_do_pack} {variante}"
        return f"{nome} — {escape(dono)}"

    divergentes = []
    for flavor, cores in paleta["flavors"].items():
        if args.accent not in cores:
            sys.exit(f"ERRO: accent '{args.accent}' não existe na paleta.")
        claro = flavor in claros
        c = {papel: cores[nomes[1 if claro else 0]] for papel, nomes in PAPEIS.items()}
        c["sujeito"] = cores[args.accent]

        # As duas fontes numa fila só, e a fila devolve o TEXTO: daqui para baixo
        # o laço não sabe — nem precisa saber — se o desenho veio de uma função
        # ou de um `.json`. O `titulo` é do gerador nas duas.
        def fila():
            for nome, desenha in DESENHOS.items():
                # A cor de identidade dos oito do sistema. Quem não está na
                # tabela (o painel) não usa `marca` e não precisa de entrada.
                # Uma cor inventada aqui morreria alta, como toda cor neste
                # projeto: ou o nome existe na paleta, ou o KeyError estoura.
                identidade = IDENTIDADE.get(nome)
                if identidade is not None:
                    c["marca"] = cores[args.accent if identidade == "__ACCENT__" else identidade]
                c["titulo"] = titulo_de(nome, flavor)
                yield nome, desenha(c)
            for nome, decl in declarados.items():
                titulo = titulo_de(nome, flavor)
                try:
                    yield nome, pack.desenhar_autoral(decl, cores, claro, args.accent,
                                                      {"titulo": titulo})
                except pack.Recusa as e:
                    sys.exit(f"ERRO: {e}")

        for nome, conteudo in fila():
            destino = args.saida / f"{nome}-{flavor}.svg"

            if args.conferir:
                atual = destino.read_text() if destino.is_file() else None
                estado = "ok" if atual == conteudo else ("ausente" if atual is None else "divergente")
                if estado != "ok":
                    divergentes.append(destino.name)
                print(f"  {estado:11s} {destino.name}")
                continue

            # Temporário no MESMO diretório do destino: `replace` só é atômico
            # dentro de um sistema de arquivos, e o repo mora no Ápate enquanto
            # /tmp costuma ser outro.
            tmp = destino.with_suffix(".svg.tmp")
            tmp.write_text(conteudo)
            tmp.replace(destino)
            print(f"  gerado      {destino.name}")

    if args.conferir and divergentes:
        print(f"\n{len(divergentes)} arquivo(s) fora do esperado. Rode sem --conferir para regerar.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

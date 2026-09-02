#!/usr/bin/env python3
"""Desenha os ícones dos DOIS aplicativos da Vitória, a partir da paleta canônica.

    FogStripper  — removedor de fundo de imagens/vídeos (redes neurais locais)
    Hefesto      — gerenciador de DualSense para Linux

POR QUE ESTES DOIS, E SÓ ESTES
    Foram os únicos, entre os 187 `.desktop` da máquina (IDs únicos pela regra
    do XDG, 175 deles com `Icon=`), cujo ícone resolve APENAS num PNG
    rasterizado no fim da cadeia de temas (o `hicolor`). Todo o resto já cai no
    Papirus ou num tema irmão. A auditoria completa e permanente é do
    `scripts/auditar_icones.sh` — que este script NÃO chama, só aponta.

O DESENHO NASCE DA PALETA — NENHUM HEX É DIGITADO AQUI
    Mesma regra e mesmo motivo do `gerar_gato.py`: SVG escrito à mão sai fora da
    paleta sem ninguém notar. Cada forma declara um PAPEL (`sujeito`, `tinta`,
    `xadrez_a`...) e o papel resolve para um nome Catppuccin. Ou o nome existe na
    paleta, ou o script morre alto.

OS PAPÉIS SÃO SENSÍVEIS A FLAVOR CLARO, E ISSO NÃO É DETALHE
    No Mocha `text` é claro e `crust` é quase preto; no Latte os dois se
    invertem. Descrever o desenho por papel faz o Latte se resolver sozinho — o
    corpo do controle continua contrastando com o fundo do lançador nos dois.
    O `touchpad` foi o único que NÃO se resolveu sozinho, e o motivo vale nos
    DOIS extremos: o accent fica quase invisível contra o `corpo`, que é `text`.
    Razões de contraste WCAG, calculadas da própria paleta —
        Latte: mauve #8839EF x text #4C4F69 = 1,47
        Mocha: mauve #CBA6F7 x text #CDD6F4 = 1,40
    (o mínimo legível para forma grande é 3,0). Por isso o touchpad leva um
    contorno de `tinta`, e é o CONTORNO que faz a separação: tinta contra o
    corpo dá 7,06 no Latte e 12,97 no Mocha, e contra o próprio mauve dá 4,79 e
    9,23. No Mocha ele vira a moldura escura do touchpad real, no Latte a borda
    clara que o separa do corpo. Uma forma a mais que resolve os dois flavors de
    uma vez. Os números saem de `assets/paleta/catppuccin.json`, fórmula WCAG 2.x.

AS DUAS DECISÕES DE DESENHO QUE FORAM MEDIDAS A 48px, NÃO IMAGINADAS
    Os ícones são vistos a ~48px no lançador. Nesse tamanho:
    - O ícone atual do FogStripper (uma mão dissolvendo em partículas) vira um
      borrão: detalhe fino de dispersão não sobrevive a 48px. Aqui a ideia virou
      a linguagem universal do ramo — metade do quadro ainda com o fundo (com um
      sol, para ler como "foto"), metade já em xadrez de transparência, e o
      sujeito no meio das duas. A história inteira em quatro formas.
    - Uma primeira versão tinha uma linha rosa marcando a divisa. A 48px ela não
      lia como "borda do corte": lia como RISCO no ícone. Foi removida depois de
      olhar o PNG ampliado, não antes.

    O xadrez tem célula de ~5px de propósito. Abaixo de ~4px ele deixa de ler
    como xadrez e vira um cinza chapado com ruído — testado com célula de 10px
    (blocos grandes demais, não lê como transparência) e de 5px (lê).

O HEFESTO VIROU UM CONTROLE, E NÃO A BIGORNA DA MARCA
    O ícone que o repositório dele usa é martelo-e-bigorna (Hefesto, o ferreiro).
    Desenhei as duas versões e olhei a 48px: a bigorna lê como bigorna, mas não
    diz o que o programa FAZ, e o martelo vira um traço roxo solto. A silhueta de
    controle é inconfundível no mesmo tamanho, e o nome "Hefesto" continua ao
    lado do ícone no lançador — a referência ao ferreiro não se perde, ela só sai
    do desenho. Se ela preferir a bigorna, é trocar a função `hefesto()`.

    O touchpad central é o que faz o controle ser um DualSense e não um genérico.
    A barra de luz (o "U" ao redor do touchpad) ficou de fora: a 48px ela teria
    menos de 2px de espessura e viraria sujeira ao lado do touchpad.

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
    quem clareia é o contorno. A lição já estava escrita aqui em cima, no
    touchpad do Hefesto; ela só não tinha sido aplicada onde o fundo é variável.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PALETA = RAIZ / "assets" / "paleta" / "catppuccin.json"
DESTINO = RAIZ / "assets" / "icones" / "autorais"

# Papel -> (nome Catppuccin em flavor escuro, nome em flavor claro).
PAPEIS = {
    # FogStripper
    "foto":     ("overlay0", "overlay0"),   # o fundo que ainda não foi removido
    "sol":      ("peach", "peach"),         # marca o lado esquerdo como "foto"
    "xadrez_a": ("surface0", "surface0"),   # transparência: célula clara
    "xadrez_b": ("surface1", "surface1"),   # transparência: célula escura
    # Hefesto
    "corpo":    ("text", "text"),           # inverte sozinho entre Mocha e Latte
    "tinta":    ("crust", "base"),          # botões e analógicos, e o contorno
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
# `sujeito` (o busto) e `touchpad` usam o ACCENT do tema — vêm por parâmetro.

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


def _xadrez(x0: float, y0: float, w: float, h: float,
            colunas: int, linhas: int, a: str, b: str) -> str:
    """O tabuleiro de transparência, como retângulos.

    Retângulo por célula em vez de `<pattern>`: o `pattern` do SVG é suportado
    pelo rsvg, mas nem todo consumidor de ícone renderiza com uma engine SVG
    completa, e um ícone que some em UM lugar é pior do que 28 retângulos.
    """
    cw, ch = w / colunas, h / linhas
    return "".join(
        f'<rect x="{x0 + i * cw:.2f}" y="{y0 + j * ch:.2f}" '
        f'width="{cw:.2f}" height="{ch:.2f}" fill="{a if (i + j) % 2 == 0 else b}"/>'
        for i in range(colunas)
        for j in range(linhas)
    )


def fogstripper(c: dict) -> str:
    """Quadro de foto: fundo à esquerda, transparência à direita, sujeito no meio.

    O corte fica em x=24 (o meio exato do quadro de 48) e o busto é centrado nele
    de propósito: o sujeito atravessa a divisa, que é o que conta a história de
    "o fundo está sendo retirado DAQUELE sujeito".
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="FogStripper">
  <title>{c['titulo']}</title>
  <defs><clipPath id="quadro"><rect x="4" y="6" width="40" height="36" rx="7"/></clipPath></defs>
  <g clip-path="url(#quadro)">
    {_xadrez(24, 6, 20, 36, 4, 7, c['xadrez_a'], c['xadrez_b'])}
    <rect x="4" y="6" width="20" height="36" fill="{c['foto']}"/>
    <circle cx="11.5" cy="14" r="3.2" fill="{c['sol']}"/>
    <g fill="{c['sujeito']}">
      <circle cx="24" cy="19.6" r="5.6"/>
      <path d="M14.6 42 C14.6 33.6 18.8 29.8 24 29.8 C29.2 29.8 33.4 33.6 33.4 42 Z"/>
    </g>
  </g>
</svg>
"""


# A silhueta do controle. Ocupa x 5..43 e y 13..42 — quase o quadro inteiro,
# porque a 48px cada pixel de margem é presença perdida no lançador.
_CORPO = (
    "M18 13.4 h12 c6 0 9.6 3.8 10.7 9.4 l2.7 12.5 c0.9 4.2 -2.7 7.4 -6.2 5.8 "
    "l-7.1 -3.1 c-1.8 -0.8 -2.9 -1.2 -4.4 -1.2 h-5.4 c-1.5 0 -2.6 0.4 -4.4 1.2 "
    "l-7.1 3.1 c-3.5 1.6 -7.1 -1.6 -6.2 -5.8 l2.7 -12.5 c1.1 -5.6 4.7 -9.4 10.7 -9.4 z"
)


def hefesto(c: dict) -> str:
    """DualSense de frente: touchpad no accent, direcional, botões e analógicos.

    Os quatro botões têm raio 1,95 e os analógicos 3,5 — a 48px isso dá círculos
    de ~4px e ~7px. Foi o piso encontrado olhando o PNG ampliado: abaixo disso
    o conjunto vira quatro pontos indistintos e o controle perde o rosto.
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Hefesto DualSense4Unix">
  <title>{c['titulo']}</title>
  <path d="{_CORPO}" fill="{c['corpo']}"/>
  <rect x="19.2" y="17.2" width="9.6" height="6.4" rx="1.7"
        fill="{c['touchpad']}" stroke="{c['tinta']}" stroke-width="1.2"/>
  <g fill="{c['tinta']}">
    <rect x="10.4" y="22.0" width="8.0" height="2.9" rx="1.35"/>
    <rect x="12.95" y="19.45" width="2.9" height="8.0" rx="1.35"/>
    <circle cx="33.4" cy="20.6" r="1.95"/>
    <circle cx="37.2" cy="24.2" r="1.95"/>
    <circle cx="29.6" cy="24.2" r="1.95"/>
    <circle cx="33.4" cy="27.8" r="1.95"/>
    <circle cx="19.0" cy="31.6" r="3.5"/>
    <circle cx="29.0" cy="31.6" r="3.5"/>
  </g>
</svg>
"""


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


DESENHOS = {
    "fogstripper": fogstripper,
    "hefesto": hefesto,
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
    p.add_argument("--accent", default="mauve", help="cor do sujeito e do touchpad (padrão: mauve)")
    p.add_argument("--saida", type=Path, default=DESTINO)
    p.add_argument("--conferir", action="store_true", help="não escreve; sai 1 se algo divergir")
    args = p.parse_args()

    if not PALETA.is_file():
        sys.exit(f"ERRO: {PALETA} não existe — a paleta canônica é obrigatória.")
    paleta = json.loads(PALETA.read_text())
    claros = paleta.get("claros", [])

    if not args.conferir:
        args.saida.mkdir(parents=True, exist_ok=True)

    divergentes = []
    for flavor, cores in paleta["flavors"].items():
        if args.accent not in cores:
            sys.exit(f"ERRO: accent '{args.accent}' não existe na paleta.")
        claro = flavor in claros
        c = {papel: cores[nomes[1 if claro else 0]] for papel, nomes in PAPEIS.items()}
        c["sujeito"] = c["touchpad"] = cores[args.accent]

        for nome, desenha in DESENHOS.items():
            # A cor de identidade dos oito do sistema. Quem não está na tabela
            # (os dois aplicativos dela) não usa `marca` e não precisa de entrada.
            # Uma cor inventada aqui morreria alta, como toda cor neste projeto:
            # ou o nome existe na paleta, ou o KeyError estoura.
            identidade = IDENTIDADE.get(nome)
            if identidade is not None:
                c["marca"] = cores[args.accent if identidade == "__ACCENT__" else identidade]

            c["titulo"] = f"{nome} — Catppuccin {flavor.capitalize()}"
            conteudo = desenha(c)
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

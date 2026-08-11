#!/usr/bin/env python3
# folha_icones.py — a folha que ela olha ANTES de qualquer troca de ícone.
#
# POR QUE ESTE ARQUIVO EXISTE
#   Em 10/08/2026 ela pediu para UNIFICAR os ícones do lançador. Unificar exige
#   antes responder uma pergunta que é de GOSTO, não de técnica: unificar em
#   QUAL linguagem? Hoje os 41 aplicativos visíveis dela saem de cinco
#   procedências que desenham de jeitos incompatíveis — marca colorida em placa
#   (Catppuccin), traço de 1 px (Arcticons), os SVG do próprio COSMIC, os
#   desenhos dela, e o que sobrou herdado do Papirus. Escolher por ela seria
#   apagar decisão dela (o btop em `osmonitor/maroon`, a logo do Hefesto), e o
#   MEMORY.md do projeto é explícito: a folha visual vem antes do código.
#
#   Esta folha NÃO TOCA EM ÍCONE NENHUM. Ela só mostra o que já está na tela,
#   agrupado por procedência, para a pergunta ficar respondível de olho.
#
# POR QUE 48 E 128 PX, E POR QUE QUATRO FUNDOS
#   48 px é a caixa medida da dock (`icones_apps_arcticons.sh`, item 2 do
#   cabeçalho). 128 px é a grade do lançador, que é ONDE A QUEIXA NASCEU: é lá
#   que o traço de 1 px do Arcticons some e que o PNG de 24 px chega borrado.
#   Uma folha num tamanho só esconde metade do problema.
#
#   Os quatro fundos são os já medidos no cabeçalho de `icons/apps.map`: mocha
#   `#1e1e2e`, latte `#eff1f5`, e os dois tons do vidro da dock, `#3C3B50` e
#   `#826E92`. Um ícone que sobrevive no mocha e desaparece no vidro claro não
#   está resolvido — e isso só aparece trocando o fundo debaixo dele.
#
# POR QUE HTML STANDALONE, E NÃO PÁGINA PUBLICADA
#   Regra dela, dita em 10/08/2026: a folha é um arquivo no disco, que abre com
#   duplo clique, sem rede e sem conta. Por isso cada ícone entra embutido em
#   base64 — o arquivo continua valendo depois que o tema for reconstruído por
#   cima, que é justamente quando ela vai querer comparar o antes e o depois.
#
#   uso: scripts/folha_icones.py [saida.html]     (padrão: ~/Documentos/meow-icones-folha.html)

import base64
import configparser
import glob
import html
import json
import os
import sys

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk  # noqa: E402

HOME = os.path.expanduser('~')
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONF_TK = os.path.join(HOME, '.config/cosmic/com.system76.CosmicTk/v1/icon_theme')
TAMANHOS = (128, 48)          # 128 = grade do lançador · 48 = dock
FUNDOS = [
    ('mocha',       '#1e1e2e', 'o tema escuro dela'),
    ('latte',       '#eff1f5', 'o tema claro'),
    ('vidro médio', '#3C3B50', 'a dock sobre papel escuro'),
    ('vidro claro', '#826E92', 'a dock sobre papel claro'),
]

# ─────────────────────────────────────────────────────────────────────────────
# QUEM DESENHOU CADA UM: a procedência sai dos MAPAS do repo, não de palpite
#   Cada mapa é o contrato de um script: quem está no `apps.map` foi vestido
#   pelo `icones_apps.sh` com o acervo Catppuccin; quem está no
#   `apps-arcticons.map` foi vestido pelo `icones_apps_arcticons.sh`. Ler os
#   mapas em vez de adivinhar pelo arquivo é o que faz esta folha continuar
#   verdadeira quando um deles mudar.
# ─────────────────────────────────────────────────────────────────────────────
GRAMATICAS = [
    ('catppuccin', 'Catppuccin — a marca do app na paleta pastel',
     'Acervo de terceiro, PNG. É a marca de cada aplicativo redesenhada nas cores '
     'Catppuccin, cheia e sem contorno — a linguagem de mais peso visual. Os '
     'arquivos são do sabor <b>macchiato</b> num tema mocha: foi escolha sua, e '
     'continua sendo, mas é a única coisa aqui que destoa por cor e não por desenho.'),
    ('arcticons', 'Arcticons — traço de 1 px, uma cor só',
     'Acervo de terceiro, SVG monocromático. A cor de cada um foi escolhida por '
     'você. É a linguagem mais leve — e a que mais sofre em tamanho pequeno.'),
    ('autoral', 'Seus desenhos',
     'Feitos por você. Estão nos INTOCÁVEIS do `icones_apps.sh`: nenhum script '
     'do MeowSystem os substitui.'),
    ('cosmic', 'COSMIC — os SVG que vêm do sistema',
     'Desenhados pela System76 para os apps do próprio COSMIC. Já falam uma '
     'língua só entre si.'),
    ('herdado', 'Herdado — o que ninguém vestiu ainda',
     'Cai no Papirus-Dark ou no hicolor do app. É aqui que mora a maior parte '
     'do desalinho.'),
]


def carrega_mapa(nome):
    """`chave:destino[:cor]` — devolve só o conjunto de chaves."""
    caminho = os.path.join(RAIZ, 'icons', nome)
    chaves = set()
    if not os.path.exists(caminho):
        return chaves
    with open(caminho, encoding='utf-8') as fh:
        for linha in fh:
            linha = linha.strip()
            if not linha or linha.startswith('#'):
                continue
            chaves.add(linha.split(':')[0].strip())
    return chaves


def carrega_curadoria():
    """`chave<TAB>extensão<TAB>subdiretório` — escrito pelo importar_icones.sh."""
    caminho = os.path.join(RAIZ, 'icons', 'curadoria.map')
    chaves = set()
    if not os.path.exists(caminho):
        return chaves
    with open(caminho, encoding='utf-8') as fh:
        for linha in fh:
            if not linha.strip() or linha.startswith('#'):
                continue
            chaves.add(linha.split('\t')[0].strip())
    return chaves


INTOCAVEIS = {'fogstripper', 'hefesto-dualsense4unix',
              'com.vitoriamaria.HefestoDualsense4Unix'}

# ─────────────────────────────────────────────────────────────────────────────
# A PRÉVIA: como ficaria unificado — e por que só UM dos dois caminhos existe
#
#   Medido em 10/08/2026, e é este número que decide:
#     acervo Catppuccin local ........... 146 nomes · cobre 2 dos 16 herdados
#     índice Arcticons (api.iconify) .. 14.996 nomes · cobre 13 dos 16 herdados
#
#   Unificar em Catppuccin não é uma opção pior: é uma opção que NÃO EXISTE. O
#   acervo não tem os aplicativos dela — nem Flatseal, nem Foliate, nem Warehouse,
#   nem os oito do COSMIC. Uma unificação que deixa 25 de fora não unificou nada.
#
#   Então a prévia mostra o caminho que existe, com a amostra baixada em
#   `icons/previa-arcticons/`: os mesmos aplicativos, hoje e em Arcticons, lado a
#   lado, nos dois tamanhos. O que ela decide olhando isto não é "qual é mais
#   bonito no papel" — é se aceita trocar a marca colorida pelo traço.
# ─────────────────────────────────────────────────────────────────────────────
PREVIA_DIR = os.path.join(RAIZ, 'icons', 'previa-arcticons')
PREVIA = [
    # chave do .desktop            glifo no Arcticons   de onde ele vem hoje
    ('google-chrome',              'google-chrome',     'catppuccin'),
    ('com.spotify.Client',         'spotify',           'catppuccin'),
    ('steam',                      'steam',             'catppuccin'),
    ('com.discordapp.Discord',     'discord',           'catppuccin'),
    ('vscode',                     'code-editor',       'catppuccin'),
    ('com.system76.CosmicFiles',   'files',             'cosmic'),
    ('com.system76.CosmicSettings', 'settings',         'cosmic'),
    ('org.telegram.desktop',       'telegram',          'herdado'),
    ('org.gnome.Calculator',       'calculator',        'herdado'),
    ('thunderbird',                'thunderbird',       'herdado'),
    # `utorrent` estava aqui e saiu: é a MARCA do µTorrent, que é outro
    # aplicativo, de outra empresa. Pôr a marca de um concorrente no lugar do
    # qBittorrent é o caso que o `apps-arcticons.map` já recusou uma vez (o
    # `playstation-family` no Hefesto). `libretorrent` é o glifo genérico.
    ('org.qbittorrent.qBittorrent', 'libretorrent',     'herdado'),
    ('com.github.johnfactotum.Foliate', 'books',        'herdado'),
]


def apps_visiveis():
    """Os mesmos que o lançador mostra — a regra é a do auditar_icones.sh."""
    dirs = [os.path.join(HOME, '.local/share/applications'),
            '/usr/share/applications',
            os.path.join(HOME, '.local/share/flatpak/exports/share/applications'),
            '/var/lib/flatpak/exports/share/applications']
    vistos, ordem = {}, []
    for d in dirs:
        for f in sorted(glob.glob(os.path.join(d, '*.desktop'))):
            b = os.path.basename(f)
            if b in vistos:
                continue
            c = configparser.RawConfigParser(strict=False, interpolation=None)
            try:
                c.read(f, encoding='utf-8')
            except Exception:
                continue
            if not c.has_section('Desktop Entry'):
                continue
            g = c['Desktop Entry']
            if g.get('Type', 'Application') != 'Application':
                continue
            if g.get('NoDisplay', 'false').lower() == 'true':
                continue
            if g.get('Hidden', 'false').lower() == 'true':
                continue
            só = g.get('OnlyShowIn', '')
            não = g.get('NotShowIn', '')
            if só and 'COSMIC' not in só.upper():
                continue
            if não and 'COSMIC' in não.upper():
                continue
            icone = g.get('Icon', '')
            if not icone:
                continue
            vistos[b] = (f, icone, g.get('Name', b))
            ordem.append(b)
    return [(b, *vistos[b]) for b in ordem]


def embute(caminho):
    if not caminho or not os.path.exists(caminho):
        return None
    tipo = 'image/svg+xml' if caminho.endswith('.svg') else 'image/png'
    with open(caminho, 'rb') as fh:
        return f'data:{tipo};base64,' + base64.b64encode(fh.read()).decode('ascii')


def main():
    saida = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        HOME, 'Documentos', 'meow-icones-folha.html')

    tema = 'MeowSystem-Icons'
    if os.path.exists(CONF_TK):
        tema = open(CONF_TK, encoding='utf-8').read().strip().strip('"') or tema
    dir_tema = os.path.join(HOME, '.local/share/icons', tema)

    catppuccin = carrega_mapa('apps.map')
    arcticons = carrega_mapa('apps-arcticons.map')
    curados = carrega_curadoria()

    resolvedores = {}
    for tam in TAMANHOS:
        t = Gtk.IconTheme.new()
        t.set_custom_theme(tema)
        resolvedores[tam] = t

    itens = []
    for desktop, _arq, icone, nome in apps_visiveis():
        art = {}
        for tam in TAMANHOS:
            if icone.startswith('/'):
                art[tam] = icone if os.path.exists(icone) else None
            else:
                achado = resolvedores[tam].lookup_icon(icone, tam, 0)
                art[tam] = achado.get_filename() if achado else None
        if not any(art.values()):
            continue

        chave = desktop[:-len('.desktop')] if desktop.endswith('.desktop') else desktop
        if chave in curados or icone in curados:
            gram = 'autoral'
        elif icone in INTOCAVEIS or chave in INTOCAVEIS:
            gram = 'autoral'
        elif icone in arcticons or chave in arcticons:
            gram = 'arcticons'
        elif icone in catppuccin or chave in catppuccin:
            gram = 'catppuccin'
        elif icone.startswith('com.system76.'):
            gram = 'cosmic'
        else:
            gram = 'herdado'

        # Um `steam_icon_*` é capa de jogo baixada da Steam: não é linguagem
        # visual nenhuma, e listar 20 delas afogaria a folha. Ficam de fora,
        # pelo mesmo motivo que o `icones_apps.sh` as põe nos INTOCÁVEIS.
        if icone.startswith('steam_icon_') or chave.startswith('meow-steam-'):
            continue

        itens.append({
            'nome': nome, 'chave': chave, 'icone': icone, 'gramatica': gram,
            'caminho': art[TAMANHOS[0]] or art[TAMANHOS[1]],
            'no_tema': bool((art[TAMANHOS[0]] or '').startswith(dir_tema)),
            'arte': {str(t): embute(art[t]) for t in TAMANHOS},
            'formato': {str(t): (os.path.splitext(art[t])[1].lstrip('.') if art[t] else '')
                        for t in TAMANHOS},
        })

    itens.sort(key=lambda i: i['nome'].lower())
    por_gram = {g: [i for i in itens if i['gramatica'] == g] for g, _, _ in GRAMATICAS}
    por_chave = {i['chave']: i for i in itens}
    por_icone = {i['icone']: i for i in itens}

    # A prévia. O SVG do Arcticons vem em `currentColor`: aqui ele é pintado de
    # lavender (`#b4befe`), que é a cor neutra do Catppuccin — não é a escolha
    # final de cor, é só o que deixa o DESENHO visível para ela julgar. A cor de
    # cada ícone continua sendo decisão dela, um a um, como no `apps-arcticons.map`.
    linhas_previa = []
    for chave, glifo, origem in PREVIA:
        atual = por_chave.get(chave) or por_icone.get(chave)
        arq = os.path.join(PREVIA_DIR, f'{glifo}.svg')
        if not atual or not os.path.exists(arq):
            continue
        svg = open(arq, encoding='utf-8').read()
        svg = svg.replace('width="1em" height="1em"', 'width="100%" height="100%"')
        rotulo = {'catppuccin': 'Catppuccin', 'cosmic': 'COSMIC',
                  'herdado': 'herdado'}.get(origem, origem)
        linhas_previa.append(f'''
      <div class="troca">
        <div class="lado">
          <img src="{atual['arte'][str(TAMANHOS[0])] or ''}" alt="" width="96" height="96">
          <img class="mini" src="{atual['arte'][str(TAMANHOS[1])] or atual['arte'][str(TAMANHOS[0])] or ''}" alt="" width="36" height="36">
        </div>
        <span class="seta">→</span>
        <div class="lado arc">
          <span class="glifo g96">{svg}</span>
          <span class="glifo g36 mini">{svg}</span>
        </div>
        <div class="rotulos">
          <b>{html.escape(atual['nome'])}</b>
          <span class="chave">hoje: {rotulo} · depois: arcticons/{glifo}</span>
        </div>
      </div>''')

    partes = []
    for chave_g, titulo, explica in GRAMATICAS:
        lista = por_gram.get(chave_g, [])
        if not lista:
            continue
        cartoes = []
        for i in lista:
            g128 = i['arte'][str(TAMANHOS[0])] or ''
            g48 = i['arte'][str(TAMANHOS[1])] or g128
            f128 = i['formato'][str(TAMANHOS[0])]
            cartoes.append(f'''
      <figure class="cartao" title="{html.escape(i['caminho'] or '')}">
        <div class="par">
          <img class="grande" src="{g128}" alt="" width="128" height="128">
          <img class="pequeno" src="{g48}" alt="" width="48" height="48">
        </div>
        <figcaption>
          <b>{html.escape(i['nome'])}</b>
          <span class="chave">{html.escape(i['icone'])}</span>
          <span class="selo">{html.escape(f128 or '—')}</span>
        </figcaption>
      </figure>''')
        partes.append(f'''
    <section class="grupo">
      <header class="cabeca">
        <h2>{html.escape(titulo)}</h2>
        <span class="conta">{len(lista)}</span>
      </header>
      <p class="explica">{explica}</p>
      <div class="grade">{''.join(cartoes)}</div>
    </section>''')

    botoes = ''.join(
        f'<button class="fundo" data-cor="{cor}" data-nome="{html.escape(n)}"'
        f'{" aria-pressed=\"true\"" if idx == 0 else ""}>'
        f'<i style="background:{cor}"></i>{html.escape(n)}</button>'
        for idx, (n, cor, _d) in enumerate(FUNDOS))

    contagem = ' · '.join(f'{len(por_gram.get(g, []))} {t.split(" —")[0].lower()}'
                          for g, t, _ in GRAMATICAS if por_gram.get(g))

    doc = f'''<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MeowSystem — as linguagens dos ícones</title>
<style>
  :root {{
    --tinta:#cdd6f4; --fraco:#a6adc8; --linha:#313244; --caixa:#181825;
    --accent:#cba6f7; --papel:#1e1e2e;
  }}
  * {{ box-sizing:border-box }}
  body {{ margin:0; background:#11111b; color:var(--tinta);
    font:15px/1.55 "Inter","Cantarell",system-ui,sans-serif; }}
  .envelope {{ max-width:1180px; margin:0 auto; padding:40px 24px 80px }}
  h1 {{ font-size:30px; margin:.2em 0 .3em; letter-spacing:-.02em }}
  .olho {{ color:var(--accent); font-size:12px; letter-spacing:.14em;
    text-transform:uppercase; margin:0 }}
  .abre {{ color:var(--fraco); max-width:70ch; margin:0 0 28px }}
  .barra {{ position:sticky; top:0; z-index:5; display:flex; flex-wrap:wrap; gap:8px;
    align-items:center; padding:12px 0; margin-bottom:24px;
    background:#11111b; border-bottom:1px solid var(--linha) }}
  .barra b {{ font-weight:600; margin-right:6px; font-size:13px; color:var(--fraco) }}
  .fundo {{ display:inline-flex; align-items:center; gap:7px; cursor:pointer;
    background:var(--caixa); color:var(--tinta); border:1px solid var(--linha);
    border-radius:999px; padding:6px 13px 6px 8px; font:inherit; font-size:13px }}
  .fundo i {{ width:15px; height:15px; border-radius:50%;
    box-shadow:inset 0 0 0 1px rgba(255,255,255,.22) }}
  .fundo[aria-pressed="true"] {{ border-color:var(--accent); color:var(--accent) }}
  .grupo {{ margin:0 0 44px }}
  .cabeca {{ display:flex; align-items:baseline; gap:10px;
    border-bottom:1px solid var(--linha); padding-bottom:8px }}
  .cabeca h2 {{ font-size:19px; margin:0; font-weight:600 }}
  .conta {{ background:var(--caixa); border:1px solid var(--linha); color:var(--fraco);
    border-radius:999px; padding:1px 10px; font-size:12px }}
  .explica {{ color:var(--fraco); font-size:13.5px; max-width:74ch; margin:10px 0 18px }}
  .grade {{ display:grid; gap:14px;
    grid-template-columns:repeat(auto-fill,minmax(190px,1fr)) }}
  .cartao {{ margin:0; background:var(--papel); border:1px solid var(--linha);
    border-radius:14px; padding:16px 12px 12px; text-align:center;
    transition:background .18s }}
  .par {{ display:flex; align-items:flex-end; justify-content:center; gap:14px;
    min-height:132px }}
  .grande {{ width:128px; height:128px; object-fit:contain }}
  .pequeno {{ width:48px; height:48px; object-fit:contain }}
  figcaption {{ margin-top:12px; display:flex; flex-direction:column; gap:2px }}
  figcaption b {{ font-size:13.5px; font-weight:600 }}
  .chave {{ font:11.5px/1.4 ui-monospace,"JetBrains Mono",monospace; color:var(--fraco);
    overflow-wrap:anywhere }}
  .selo {{ font-size:10.5px; letter-spacing:.1em; text-transform:uppercase;
    color:var(--fraco); opacity:.7 }}
  .rodape {{ color:var(--fraco); font-size:13px; border-top:1px solid var(--linha);
    padding-top:18px; max-width:74ch }}
  .decide {{ border:1px solid var(--accent); border-radius:16px; padding:26px 24px;
    margin:0 0 44px; background:linear-gradient(180deg,rgba(203,166,247,.07),transparent) }}
  .decide h2 {{ margin:0 0 6px; font-size:21px }}
  .conta2 {{ display:flex; flex-wrap:wrap; gap:10px; margin:18px 0 24px }}
  .conta2 div {{ flex:1 1 260px; background:var(--caixa); border:1px solid var(--linha);
    border-radius:12px; padding:14px 16px }}
  .conta2 b {{ display:block; font-size:25px; font-weight:600; letter-spacing:-.02em }}
  .conta2 small {{ color:var(--fraco); font-size:12.5px; line-height:1.45; display:block;
    margin-top:3px }}
  .conta2 .ruim b {{ color:#f38ba8 }} .conta2 .bom b {{ color:#a6e3a1 }}
  .trocas {{ display:grid; gap:12px; grid-template-columns:repeat(auto-fill,minmax(300px,1fr)) }}
  .troca {{ display:grid; grid-template-columns:1fr auto 1fr; align-items:center;
    gap:8px; background:var(--papel); border:1px solid var(--linha);
    border-radius:12px; padding:16px 14px 12px; transition:background .18s }}
  .lado {{ display:flex; align-items:flex-end; justify-content:center; gap:7px }}
  .lado img, .lado .glifo {{ display:block }}
  .lado .mini {{ opacity:.95 }}
  .glifo {{ color:#b4befe }}
  .g96 {{ width:96px; height:96px }} .g36 {{ width:36px; height:36px }}
  .g96 svg, .g36 svg {{ width:100%; height:100% }}
  .seta {{ color:var(--fraco); text-align:center; font-size:15px }}
  /* O rótulo atravessa as três colunas: numa coluna própria de `1fr` ele
     colapsa e o texto sai letra por letra, na vertical (visto em teste). */
  .rotulos {{ grid-column:1 / -1; text-align:center; margin-top:12px;
    display:flex; flex-direction:column; gap:2px }}
  .rotulos b {{ font-size:13.5px }}
  @media (max-width:640px) {{ .grande {{ width:96px; height:96px }} .par {{ min-height:100px }} }}
</style></head>
<body>
<div class="envelope">
  <p class="olho">MeowSystem · lançador do COSMIC</p>
  <h1>As linguagens dos seus ícones</h1>
  <p class="abre">
    Os {len(itens)} aplicativos que aparecem no seu lançador hoje, agrupados por quem os
    desenhou. Cada um está em <b>128&nbsp;px</b> (o tamanho da grade do lançador) ao lado de
    <b>48&nbsp;px</b> (o tamanho da dock) — é a diferença entre os dois que mostra qual
    linguagem aguenta ficar pequena. Troque o fundo nos botões abaixo: um ícone que some
    no vidro da dock não está resolvido. <b>Esta página não muda nada no sistema.</b>
  </p>

  <div class="barra"><b>Fundo</b>{botoes}</div>

  <section class="decide">
    <h2>Unificar em quê — e por que só existe um caminho</h2>
    <p class="explica" style="margin-bottom:0">
      Unificar quer dizer pôr os {len(itens)} na mesma linguagem. Medi os dois acervos contra
      os aplicativos que você tem de verdade, e eles não empatam:
    </p>
    <div class="conta2">
      <div class="ruim">
        <b>2 de 16</b>
        <small>É quanto o acervo <b>Catppuccin</b> cobre dos seus 16 aplicativos ainda sem
        tema. Ele tem 146 nomes, e não tem Flatseal, Foliate, Warehouse, nem nenhum dos 8
        do COSMIC. Unificar aqui deixaria 25 de fora — ou seja, não unificaria.</small>
      </div>
      <div class="bom">
        <b>13 de 16</b>
        <small>É quanto o <b>Arcticons</b> cobre dos mesmos 16, com 14.996 nomes no índice.
        Só Flatseal, Gradia e Warehouse dão zero — esses três ficam no Papirus, porque um
        ícone errado é pior que um genérico.</small>
      </div>
    </div>
    <p class="explica">
      Então a pergunta real não é "qual das duas". É: <b>você aceita trocar a marca colorida
      pelo traço?</b> Abaixo, os mesmos aplicativos, hoje e depois. A cor lilás é só para o
      desenho aparecer — a cor final de cada um continua sendo escolha sua, uma a uma.
    </p>
    <div class="trocas">{''.join(linhas_previa)}</div>
  </section>

  {''.join(partes)}

  <p class="rodape">
    Contagem: {contagem}. A pergunta é uma só — <b>qual dessas linguagens vale para os
    {len(itens)}?</b> Depois que você responder, o resto é técnica: os mapas do repo
    (<code>icons/apps.map</code>, <code>icons/apps-arcticons.map</code>) passam a apontar
    todo mundo para o acervo escolhido, e seus desenhos continuam intocados.
    Para trocar um ícone específico à mão, a outra página é a
    <code>meow-icones-curadoria.html</code>.
  </p>
</div>
<script>
  const cartoes = document.querySelectorAll('.cartao');
  document.querySelectorAll('.fundo').forEach(b => b.addEventListener('click', () => {{
    document.querySelectorAll('.fundo').forEach(o => o.setAttribute('aria-pressed', o === b));
    cartoes.forEach(c => c.style.background = b.dataset.cor);
  }}));
</script>
</body></html>
'''

    os.makedirs(os.path.dirname(saida), exist_ok=True)
    with open(saida, 'w', encoding='utf-8') as fh:
        fh.write(doc)
    resumo = {g: len(por_gram.get(g, [])) for g, _, _ in GRAMATICAS}
    print(saida)
    print(json.dumps(resumo, ensure_ascii=False))


if __name__ == '__main__':
    main()

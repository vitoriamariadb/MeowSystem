#!/usr/bin/env python3
# folha_proposta.py — a folha de APROVAÇÃO da unificação em Arcticons.
#
# O QUE ELA DECIDIU EM 10/08/2026, E O QUE SOBROU PARA DECIDIR
#   Ela viu a folha `folha_icones.py`, aceitou trocar a marca colorida pelo
#   traço, e escolheu:
#     escopo   TODOS, inclusive os 8 do próprio COSMIC
#     cor      por CATEGORIA (6 cores), não uma a uma nem uma só
#     glifos   eu proponho, ela aprova AQUI antes de tocar no sistema
#     os 3 sem glifo honesto (Flatseal, Gradia, Warehouse) ficam no Papirus
#
#   Sobrou uma coisa: 22 dos 35 aplicativos NÃO TÊM a marca deles no pack, e o
#   glifo é uma INTERPRETAÇÃO minha do que o aplicativo faz (GIMP -> editor de
#   foto, File Roller -> zip). Interpretação é onde eu erro, e é exatamente o
#   que esta folha existe para ela conferir — cada cartão diz de onde veio a
#   escolha e por quê.
#
# POR QUE ESTA FOLHA É SEPARADA DA OUTRA
#   A `folha_icones.py` responde "unificar em quê?" e continua verdadeira depois
#   que a resposta for dada — é o retrato do que está na tela hoje. Esta responde
#   "estes 35 glifos servem?" e MORRE quando ela responder. Juntar as duas faria
#   a página do retrato mudar de assunto a cada decisão tomada.
#
#   uso: scripts/folha_proposta.py [saida.html]
#        (padrão: ~/Documentos/meow-icones-proposta.html)

import base64
import html
import json
import os
import sys

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk  # noqa: E402

HOME = os.path.expanduser('~')
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PREVIA_DIR = os.path.join(RAIZ, 'icons', 'previa-arcticons')
CONF_TK = os.path.join(HOME, '.config/cosmic/com.system76.CosmicTk/v1/icon_theme')

# A cor sai da paleta, nunca de um hex escrito aqui — regra do
# `assets/paleta/catppuccin.json` ("nenhum hex pode ser hardcoded em script").
CATEGORIAS = [
    ('navegador', 'blue',     'Navegadores'),
    ('rede',      'sky',      'Conversa e rede'),
    ('midia',     'green',    'Mídia'),
    ('criacao',   'pink',     'Criação e código'),
    ('leitura',   'peach',    'Leitura e notas'),
    ('sistema',   'lavender', 'Sistema'),
]

# (chave do `Icon=` · glifo no Arcticons · categoria · de onde veio a escolha)
#   'marca' = o pack tem o aplicativo pelo nome; não há interpretação minha.
PROPOSTA = [
    ('com.brave.Browser',        'brave',          'navegador', 'marca'),
    ('google-chrome',            'google-chrome',  'navegador', 'marca'),
    ('firefox',                  'firefox',        'navegador', 'marca'),
    ('com.discordapp.Discord',   'discord',        'rede',      'marca'),
    ('meow-whatsapp',            'whatsapp',       'rede',      'marca'),
    ('org.telegram.desktop',     'telegram',       'rede',      'marca'),
    ('thunderbird',              'thunderbird',    'rede',      'marca'),
    ('com.spotify.Client',       'spotify',        'midia',     'marca'),
    ('steam',                    'steam',          'midia',     'marca'),
    ('org.videolan.VLC',         'vlc',            'midia',     'marca'),
    ('io.github.shiftey.Desktop', 'github',        'criacao',   'marca'),
    ('org.kde.krita',            'krita',          'criacao',   'marca'),
    ('md.obsidian.Obsidian',     'obsidian',       'leitura',   'marca'),
    ('io.gitlab.theevilskeleton.Upscaler', 'upscaler', 'criacao', 'marca'),
    ('org.gnome.Calculator',     'calculator',     'sistema',   'marca'),
    ('org.gnome.Snapshot',       'camera',         'midia',     'marca'),

    ('org.gimp.GIMP',            'photo-editor',   'criacao',
     'O pack não tem a marca do GIMP. Escolhi pelo que ele é: editor de imagem.'),
    ('com.obsproject.Studio',    'screen-recorder', 'midia',
     'Sem marca no pack. O OBS grava a tela — é o uso, não o logo.'),
    ('vscode',                   'code-editor',    'criacao',
     'Sem marca no pack. Glifo genérico de editor de código.'),
    ('com.system76.CosmicFiles', 'files',          'sistema',
     'Gerenciador de arquivos.'),
    ('com.system76.CosmicTerm',  'terminal',       'sistema', 'Terminal.'),
    ('com.system76.CosmicSettings', 'settings',    'sistema',
     'Ajustes do sistema.'),
    ('com.system76.CosmicEdit',  'editor',         'criacao', 'Editor de texto.'),
    ('com.system76.CosmicStore', 'shopping',       'sistema',
     '"store" no pack é a loja de OUTRO app, e "shop" desenha a PALAVRA "shop" '
     'escrita — a 48 px vira borrão. "shopping" é a cesta, um desenho de verdade.'),
    ('com.system76.CosmicMonitor', 'osmonitor',    'sistema',
     'O MESMO glifo que você escolheu para o btop — os dois medem a máquina.'),
    ('com.system76.CosmicPlayer', 'player',        'midia',   'Toca mídia.'),
    ('com.system76.CosmicScreenshot', 'screenshots', 'sistema', 'Captura de tela.'),
    ('dev.edfloreshz.CosmicTweaks', 'equalizer',      'sistema',
     'A variante "settings-alt-1" era engrenagem igual à do Settings — a 48 px '
     'os dois ficavam indistinguíveis lado a lado. "equalizer" são três sliders, '
     'que é justamente o desenho que ele já usa hoje.'),
    ('org.gnome.gitlab.somas.Apostrophe', 'writer', 'criacao',
     'É editor de Markdown, mas o glifo "markdown" do pack é só um asterisco — '
     'não diz nada. "writer" desenha uma folha com texto e uma pena.'),
    ('org.bleachbit.BleachBit',  'cleaner',        'sistema',
     'Limpa disco. Glifo genérico de limpeza.'),
    ('com.boxy_svg.BoxySVG',     'vector',         'criacao',
     'Editor vetorial; o glifo é o nó de curva.'),
    ('org.gnome.FileRoller',     'compressor',     'sistema',
     '"zarchiver" e "rar" são MARCAS de outros apps; "zip" e "box" desenham a '
     'palavra escrita, ilegível a 48 px. "compressor" são duas setas apertando '
     'uma linha — é o que compactar É.'),
    ('com.github.johnfactotum.Foliate', 'books',   'leitura',
     'Leitor de ebook.'),
    ('net.davidotek.pupgui2',    'proton',         'sistema',
     'Proton é a camada de compatibilidade que ele instala — é o assunto dele, '
     'não marca de concorrente.'),
    ('org.qbittorrent.qBittorrent', 'libretorrent', 'rede',
     '"utorrent" seria a marca de um CONCORRENTE dele. Este desenha a rede '
     'ponto-a-ponto, que é o que ele faz.'),
]

JA_ESCOLHIDOS = [
    ('org.onlyoffice.desktopeditors', 'onlyoffice-documents', 'sapphire'),
    ('btop', 'osmonitor', 'maroon'),
    ('input-remapper', 'keymapper', 'sky'),
]
NO_PAPIRUS = [
    ('com.github.tchx84.Flatseal', 'Flatseal'),
    ('be.alexandervanhee.gradia', 'Gradia'),
    ('io.github.flattool.Warehouse', 'Warehouse'),
]


def paleta(flavor='mocha'):
    with open(os.path.join(RAIZ, 'palette', 'catppuccin.json'), encoding='utf-8') as fh:
        return json.load(fh)['flavors'][flavor]


def main():
    saida = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        HOME, 'Documentos', 'meow-icones-proposta.html')
    cores = paleta()
    tema = 'MeowSystem-Icons'
    if os.path.exists(CONF_TK):
        tema = open(CONF_TK, encoding='utf-8').read().strip().strip('"') or tema
    resolvedor = Gtk.IconTheme.new()
    resolvedor.set_custom_theme(tema)

    def atual(chave, tam=96):
        achado = resolvedor.lookup_icon(chave, tam, 0)
        if not achado or not achado.get_filename():
            return None
        caminho = achado.get_filename()
        tipo = 'image/svg+xml' if caminho.endswith('.svg') else 'image/png'
        with open(caminho, 'rb') as fh:
            return f'data:{tipo};base64,' + base64.b64encode(fh.read()).decode('ascii')

    def glifo(nome, cor_hex):
        arq = os.path.join(PREVIA_DIR, f'{nome}.svg')
        if not os.path.exists(arq):
            return None
        svg = open(arq, encoding='utf-8').read()
        # A cor entra aqui do mesmo jeito que o `icones_apps_arcticons.sh` a
        # instala: no lugar do literal `currentColor`. Assim a folha mostra o
        # arquivo exato que iria para o tema, e não uma aproximação.
        svg = svg.replace('currentColor', cor_hex)
        return svg.replace('width="1em" height="1em"', 'width="100%" height="100%"')

    secoes, n_marca, n_interp, faltando = [], 0, 0, []
    for cat, cor_nome, titulo in CATEGORIAS:
        hexa = cores[cor_nome]
        cartoes = []
        for chave, nome_glifo, categoria, porque in PROPOSTA:
            if categoria != cat:
                continue
            svg = glifo(nome_glifo, hexa)
            if not svg:
                faltando.append(nome_glifo)
                continue
            hoje = atual(chave)
            eh_marca = porque == 'marca'
            n_marca += eh_marca
            n_interp += not eh_marca
            selo = ('<span class="tag marca">marca do app</span>' if eh_marca
                    else '<span class="tag interp">escolha minha</span>')
            nota = '' if eh_marca else f'<p class="porque">{html.escape(porque)}</p>'
            img_hoje = (f'<img src="{hoje}" alt="" width="72" height="72">' if hoje
                        else '<span class="sem">sem ícone</span>')
            cartoes.append(f'''
        <figure class="cartao" data-glifo="{html.escape(nome_glifo)}">
          <div class="par">
            <span class="antes">{img_hoje}</span>
            <span class="seta">→</span>
            <span class="depois g72">{svg}</span>
            <span class="depois g28">{svg}</span>
          </div>
          <figcaption>
            <b>{html.escape(chave)}</b>
            <span class="chave">arcticons/{html.escape(nome_glifo)} · {cor_nome}</span>
            {selo}{nota}
          </figcaption>
        </figure>''')
        if cartoes:
            secoes.append(f'''
      <section class="grupo">
        <header class="cabeca">
          <h2><i style="background:{hexa}"></i>{html.escape(titulo)}</h2>
          <span class="conta">{len(cartoes)} · {cor_nome} {hexa}</span>
        </header>
        <div class="grade">{''.join(cartoes)}</div>
      </section>''')

    ja = ''.join(
        f'<li><b>{html.escape(c)}</b> → arcticons/{html.escape(g)} · <i>{cor}</i></li>'
        for c, g, cor in JA_ESCOLHIDOS)
    papirus = ''.join(f'<li><b>{html.escape(n)}</b> <span>{html.escape(c)}</span></li>'
                      for c, n in NO_PAPIRUS)

    doc = f'''<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MeowSystem — a proposta de unificação</title>
<style>
  :root {{ --tinta:#cdd6f4; --fraco:#a6adc8; --linha:#313244; --caixa:#181825;
    --accent:#cba6f7; --papel:#1e1e2e; }}
  * {{ box-sizing:border-box }}
  body {{ margin:0; background:#11111b; color:var(--tinta);
    font:15px/1.55 "Inter","Cantarell",system-ui,sans-serif }}
  .envelope {{ max-width:1180px; margin:0 auto; padding:40px 24px 80px }}
  h1 {{ font-size:30px; margin:.2em 0 .3em; letter-spacing:-.02em }}
  .olho {{ color:var(--accent); font-size:12px; letter-spacing:.14em;
    text-transform:uppercase; margin:0 }}
  .abre {{ color:var(--fraco); max-width:72ch; margin:0 0 24px }}
  .painel {{ display:flex; flex-wrap:wrap; gap:10px; margin:0 0 34px }}
  .painel div {{ flex:1 1 200px; background:var(--caixa); border:1px solid var(--linha);
    border-radius:12px; padding:13px 16px }}
  .painel b {{ display:block; font-size:24px; font-weight:600 }}
  .painel small {{ color:var(--fraco); font-size:12.5px }}
  .grupo {{ margin:0 0 40px }}
  .cabeca {{ display:flex; align-items:center; justify-content:space-between; gap:10px;
    border-bottom:1px solid var(--linha); padding-bottom:9px; margin-bottom:16px }}
  .cabeca h2 {{ font-size:18px; margin:0; font-weight:600; display:flex;
    align-items:center; gap:9px }}
  .cabeca h2 i {{ width:13px; height:13px; border-radius:50%; display:inline-block }}
  .conta {{ color:var(--fraco); font-size:12px;
    font-family:ui-monospace,"JetBrains Mono",monospace }}
  .grade {{ display:grid; gap:12px;
    grid-template-columns:repeat(auto-fill,minmax(268px,1fr)) }}
  .cartao {{ margin:0; background:var(--papel); border:1px solid var(--linha);
    border-radius:13px; padding:16px 15px 13px }}
  .par {{ display:flex; align-items:flex-end; justify-content:center; gap:11px;
    min-height:80px }}
  .antes img {{ display:block; opacity:.85 }}
  .sem {{ color:var(--fraco); font-size:11px; opacity:.6 }}
  .seta {{ color:var(--fraco) }}
  .g72 {{ width:72px; height:72px; display:block }}
  .g28 {{ width:28px; height:28px; display:block }}
  .g72 svg, .g28 svg {{ width:100%; height:100% }}
  figcaption {{ margin-top:13px; display:flex; flex-direction:column; gap:4px }}
  figcaption b {{ font-size:12.5px; font-weight:600; overflow-wrap:anywhere }}
  .chave {{ font:11px/1.4 ui-monospace,"JetBrains Mono",monospace; color:var(--fraco);
    overflow-wrap:anywhere }}
  .tag {{ align-self:flex-start; font-size:10.5px; letter-spacing:.06em;
    text-transform:uppercase; border-radius:999px; padding:2px 9px; margin-top:3px }}
  .marca {{ background:rgba(166,227,161,.13); color:#a6e3a1 }}
  .interp {{ background:rgba(250,179,135,.13); color:#fab387 }}
  .porque {{ color:var(--fraco); font-size:12px; margin:5px 0 0; line-height:1.45 }}
  .fecho {{ border:1px solid var(--linha); border-radius:14px; padding:20px 22px;
    background:var(--caixa); margin-top:8px }}
  .fecho h3 {{ margin:0 0 8px; font-size:15px }}
  .fecho ul {{ margin:0 0 18px; padding-left:20px; color:var(--fraco); font-size:13px }}
  .fecho li {{ margin:3px 0 }}
  .fecho code {{ background:#11111b; border:1px solid var(--linha); border-radius:5px;
    padding:2px 7px; font-size:12.5px }}
</style></head>
<body><div class="envelope">
  <p class="olho">MeowSystem · proposta de unificação</p>
  <h1>Os {len(PROPOSTA)} glifos — aprove ou troque</h1>
  <p class="abre">
    Cada cartão mostra o ícone de <b>hoje</b> à esquerda e o <b>Arcticons proposto</b> à
    direita, em 72&nbsp;px e em 28&nbsp;px, já <b>na cor final</b> da categoria. Os verdes
    são a marca do próprio aplicativo — não há o que discutir neles. Os laranjas são
    <b>escolha minha</b>, e cada um diz por quê: é aí que eu posso ter errado.
    <b>Nada foi aplicado no sistema.</b>
  </p>
  <div class="painel">
    <div><b>{n_marca}</b><small>são a marca do app — sem interpretação</small></div>
    <div><b>{n_interp}</b><small>são escolha minha — confira estes</small></div>
    <div><b>6</b><small>cores, uma por categoria</small></div>
    <div><b>3</b><small>ficam no Papirus, por decisão sua</small></div>
  </div>
  {''.join(secoes)}
  <div class="fecho">
    <h3>Fora desta folha, de propósito</h3>
    <ul>
      <li><b>Seus desenhos</b> — Hefesto e FogStripper: intocáveis, não entram.</li>
      <li><b>As capas dos jogos da Steam</b> — são arte da loja, não linguagem de ícone.</li>
      {ja}
      {papirus}
    </ul>
    <h3>Quando você aprovar</h3>
    <p class="porque" style="margin:0">
      Os 35 glifos vão para <code>assets/icones/arcticons-apps/</code> com a cor aplicada, as 35
      linhas entram em <code>assets/icones/apps-arcticons.map</code>, e
      <code>meow icones reconstruir</code> monta o tema. Reverter é apagar as linhas do
      mapa e rodar de novo — o acervo Catppuccin continua no repo, intacto.
    </p>
  </div>
</div></body></html>
'''
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    with open(saida, 'w', encoding='utf-8') as fh:
        fh.write(doc)
    print(saida)
    if faltando:
        print('SEM ARQUIVO em assets/icones/previa-arcticons/: ' + ', '.join(faltando),
              file=sys.stderr)
        return 1
    print(f'{n_marca} marca · {n_interp} escolha minha')
    return 0


if __name__ == '__main__':
    sys.exit(main())

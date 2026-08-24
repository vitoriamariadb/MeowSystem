#!/usr/bin/env python3
# folha_marcas.py — a folha de APROVAÇÃO da cor por MARCA.
#
# A PERGUNTA QUE ESTA FOLHA FAZ
#   Em 23/08/2026 ela disse, olhando o dock: *"a cor de alguns svgs tão
#   diferentes das logos originais. tipo a do wpp ou steam, chrome, coisa que
#   nas linhas ia facilitar nossa vida"*.
#
#   O pedido é só de COR. O traço continua traço, `fill:none` continua
#   `fill:none`, e a paleta continua sendo `palette/catppuccin.json` — nenhum hex
#   de fora entra no tema. O que muda é QUAL cor da paleta cada aplicativo veste.
#
# POR QUE ELA PRECISA DECIDIR, E NÃO EU
#   Porque isto DERRUBA uma escolha que foi dela. Em 10/08/2026, entre "uma cor
#   só", "por categoria" e "uma a uma", ela escolheu POR CATEGORIA. Cor por marca
#   é a terceira opção com outro nome. As duas não convivem, e a folha mostra o
#   custo com nome e sobrenome: a categoria "rede" (hoje `sky` inteira) se
#   reparte em quatro cores e deixa de existir.
#
# POR QUE ESTA FOLHA É SEPARADA DA `folha_proposta.py`
#   Aquela perguntou "estes 35 GLIFOS servem?" e já foi respondida — os glifos
#   estão no ar desde 10/08. Esta pergunta é sobre COR e não toca em desenho
#   nenhum. Juntar as duas faria uma página respondida mudar de assunto.
#
# O QUE ESTA FOLHA MOSTRA, E O QUE ELA NÃO INVENTA
#   Cada cartão põe lado a lado o arquivo EXATO de hoje e o arquivo EXATO que
#   seria instalado — mesma arte, mesmo `stroke-width`, só a cor trocada, do
#   mesmo jeito que o `icones_apps_arcticons.sh` troca (no literal
#   `currentColor`). Não é aproximação: é o arquivo.
#
#   O quadradinho de "marca" ao lado é a cor REAL do logo — cor de fora, posta
#   ali só para conferir a proximidade a olho. Ela NÃO entra no tema em lugar
#   nenhum; o que entra é sempre a chave da paleta.
#
#   uso: scripts/folha_marcas.py [saida.html]
#        (padrão: ~/Documentos/meow-icones-marcas.html)

import html
import json
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME = os.path.expanduser('~')

# ============================================================================
# AS CORES DE MARCA — medidas, e conferidas contra o hex oficial
# ============================================================================
#
# Estes hexes são de FORA e existem só para comparação visual nesta folha. A
# regra "nenhum hex hardcoded" vale para a cor do TEMA, que continua saindo de
# `palette/catppuccin.json` — aqui não há cor de tema nenhuma.
#
# `medido`  = a arte instalada NESTA máquina, rasterizada a 128 px e medida em
#             Oklab (bin de matiz de 30°, cor do bin dominante). Sempre a arte
#             do PRÓPRIO FORNECEDOR quando ela existe — o SVG do flatpak, o PNG
#             do `hicolor` do pacote. NUNCA o Papirus quando havia alternativa:
#             o Papirus é um redesenho na paleta DELE, não a marca.
# `oficial` = o hex publicado pela marca, conferido contra o medido. Onde os dois
#             caem na mesma cor Catppuccin, a linha entrou; onde discordam, não.
# `dom`     = dominância: a fatia do maior bin de matiz entre os pixels
#             cromáticos. É ela que decide se a marca TEM uma cor (≥ 60%) ou é
#             multicolor.
MARCAS = {
    'meow-whatsapp':              ('#25D366', '#31C03E', 1.00, 'ZapZap (flatpak)'),
    'steam':                      ('#66C0F4', '#136295', 0.93, 'hicolor do pacote'),
    'com.discordapp.Discord':     ('#5865F2', '#5764F2', 1.00, 'flatpak'),
    'org.telegram.desktop':       ('#26A5E4', '#2BA3DF', 0.99, 'flatpak'),
    'org.qbittorrent.qBittorrent': ('#2F67BA', '#356EBF', 1.00, 'flatpak'),
    'thunderbird':                ('#0A84FF', '#1480E3', 0.96, 'hicolor do pacote'),
    'firefox':                    ('#FF7139', '#FE7C1C', 0.39, 'Papirus (gradiente)'),
    'com.brave.Browser':          ('#FB542B', '#FF1F00', 0.99, 'flatpak'),
    'org.videolan.VLC':           ('#FF8800', '#FF8700', 0.94, 'Papirus'),
    'md.obsidian.Obsidian':       ('#7C3AED', '#6E3DD1', 0.96, 'flatpak'),
    'io.github.shiftey.Desktop':  ('#6E5494', '#8033A8', 1.00, 'Papirus'),
    'vscode':                     ('#007ACC', '#1EACF8', 0.97, 'Papirus'),
    'com.github.johnfactotum.Foliate': ('#00B4B4', '#23DED0', 1.00, 'hicolor do pacote'),
    'com.spotify.Client':         ('#1DB954', '#1DD75F', 0.98, 'flatpak'),
    'google-chrome':              ('#4285F4', '#2FA34F', 0.27, 'hicolor do pacote'),
}

# (app · cor de hoje · cor proposta · justificativa de UMA linha)
MUDAM = [
    ('meow-whatsapp', 'sky', 'green',
     'O WhatsApp é verde. O ciano de hoje não existe em lugar nenhum da marca — '
     'é a cor da categoria "rede", e é esta a divergência que você viu.'),
    ('steam', 'green', 'sapphire',
     'A Steam não tem verde nenhum. O azul da interface dela (#66C0F4) cai a 8° '
     'do sapphire; o navy do logo é escuro demais para virar traço no fundo escuro.'),
    ('com.discordapp.Discord', 'sky', 'lavender',
     'O blurple do Discord está a 3° do lavender — é o casamento mais exato da lista.'),
    ('org.telegram.desktop', 'sky', 'sapphire',
     'O azul do Telegram é mais fundo que o sky; sapphire é o vizinho a 8°.'),
    ('org.qbittorrent.qBittorrent', 'sky', 'blue',
     'O azul do qBittorrent está a 2° do blue. Hoje ele é sky por ser "rede".'),
    ('thunderbird', 'sky', 'blue',
     'O Thunderbird é azul de verdade (#0A84FF), a 4° do blue.'),
    ('firefox', 'blue', 'peach',
     'O Firefox é LARANJA. Hoje ele está azul porque "navegador = blue" — '
     'e azul é justamente a cor do concorrente dele.'),
    ('com.brave.Browser', 'blue', 'peach',
     'O Brave é laranja-vermelho. Alternativa a considerar: maroon, que fica a '
     '26° em vez de 18°, mas puxa mais para o vermelho do leão.'),
    ('org.videolan.VLC', 'green', 'peach',
     'O cone do VLC é laranja (#FF8800), a 4° do peach. Hoje é green por ser "mídia".'),
    ('md.obsidian.Obsidian', 'peach', 'mauve',
     'O Obsidian é roxo. Hoje está peach por ser "leitura" — e mauve é o seu accent.'),
    ('io.github.shiftey.Desktop', 'pink', 'mauve',
     'O roxo do GitHub Desktop está a 3° do mauve.'),
    ('vscode', 'pink', 'blue',
     'O VS Code é azul (#007ACC). Alternativa: sapphire, que é o que a arte '
     'instalada mede — os dois defendem-se.'),
    ('com.github.johnfactotum.Foliate', 'peach', 'teal',
     'O MAIS FRACO da lista: a capa teal cobre só 21% do ícone, abaixo do piso '
     'de 25% que eu mesmo pus. Deixe de fora sem dó se não convencer.'),
]

# (app · cor · motivo de NÃO mudar) — a lista que prova que a mudança é cirúrgica
FICAM = [
    ('google-chrome', 'blue', 'multicolor',
     'O azul oficial do Chrome (#4285F4) está a <b>0°</b> do blue do Catppuccin — '
     'não existe cor melhor na paleta, e é o miolo da logo, a parte que sobrevive '
     'quando a marca vira monocromática. Um Chrome de quatro cores foi TENTADO e é '
     'impossível sem redesenhar: os 8 <code>path</code> da conversão são contornos '
     'traçados, não as regiões de cor da logo — nenhum deles é "a pá vermelha".'),
    ('com.spotify.Client', 'green', 'já certo',
     'O verde do Spotify está a 6° do green. Já estava certo, por acaso feliz da '
     'categoria "mídia" — e é por isso que ele nunca te incomodou.'),
    ('org.gimp.GIMP', 'pink', 'acromático',
     'Medido: <b>2,1%</b> de pixels cromáticos. O Wilber é pardo. Pintar o GIMP '
     '"da cor da marca" seria inventar uma marca que não existe.'),
    ('com.obsproject.Studio', 'green', 'acromático',
     'Medido: <b>0,0%</b> de pixels cromáticos. O ícone do OBS é branco e cinza.'),
    ('org.kde.krita', 'pink', 'multicolor',
     'Dominância de <b>18%</b>: o borrão de tinta do Krita não tem uma cor, tem cinco.'),
    ('org.onlyoffice.desktopeditors', 'sapphire', 'escolha sua',
     'Você escolheu sapphire à mão em 08/08/2026 e eu não desfaço isso. Só para o '
     'registro: a marca do ONLYOFFICE é laranja (#FF6F3D) — se quiser, vira peach.'),
    ('btop', 'maroon', 'escolha sua', 'Cor que você escolheu à mão em 08/08/2026.'),
    ('input-remapper', 'sky', 'escolha sua', 'Cor que você escolheu à mão em 08/08/2026.'),
]

# Os que não têm marca nenhuma e por isso mantêm a cor de CATEGORIA — contados,
# não listados um a um: são o argumento de que a categoria continua servindo.
SEM_MARCA = [
    ('os nove <b>com.system76.Cosmic*</b> e o Tweaks', 'lavender',
     'lavender é a cor de SISTEMA. A System76 não escolheu lavender — nós escolhemos.'),
    ('<b>Calculadora</b>, <b>File Roller</b>, <b>Snapshot</b>', 'lavender / green',
     'apps do GNOME: o verde que o Papirus dá a eles é invenção do Papirus, não marca.'),
    ('<b>Flatseal</b>, <b>Warehouse</b>, <b>Gradia</b>', 'lavender / pink',
     'desenho à mão nosso — não há logo de origem de onde puxar cor.'),
    ('<b>BoxySVG</b>, <b>Upscaler</b>, <b>BleachBit</b>, <b>ProtonUp</b>, <b>Apostrophe</b>',
     'pink / lavender', 'glifo genérico do pack: não carregam marca de ninguém.'),
]


def paleta(flavor='mocha'):
    with open(os.path.join(RAIZ, 'palette', 'catppuccin.json'), encoding='utf-8') as fh:
        return json.load(fh)['flavors'][flavor]


def mapas():
    """nome -> caminho da arte, lido dos mesmos dois mapas que o instalador lê."""
    arte = {}
    for linha in open(os.path.join(RAIZ, 'icons', 'apps-arcticons.map'), encoding='utf-8'):
        linha = linha.strip()
        if not linha or linha.startswith('#'):
            continue
        c = linha.split(':')
        arte[c[0]] = os.path.join(RAIZ, 'icons', 'arcticons-apps', c[1] + '.svg')
    for linha in open(os.path.join(RAIZ, 'icons', 'apps-convertidos.map'), encoding='utf-8'):
        linha = linha.strip()
        if not linha or linha.startswith('#'):
            continue
        c = linha.split(':')
        arte[c[0]] = os.path.join(RAIZ, 'icons', 'convertidos-apps', c[0] + '.svg')
    return arte


def vestido(caminho, hexa):
    """O MESMO que `_vestido()` do icones_apps_arcticons.sh faz: stroke-width e
    o literal `currentColor` trocado pelo hex. Assim a folha mostra o arquivo
    que iria para o tema, e não um desenho parecido."""
    if not os.path.exists(caminho):
        return None
    svg = open(caminho, encoding='utf-8').read()
    if 'stroke-width' not in svg:
        for el in ('circle', 'rect', 'line', 'polyline', 'polygon', 'path', 'ellipse'):
            svg = svg.replace(f'<{el} ', f'<{el} stroke-width="1.75" ')
    svg = svg.replace('currentColor', hexa)
    return svg.replace('width="1em" height="1em"', 'width="100%" height="100%"')


def main():
    saida = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        HOME, 'Documentos', 'meow-icones-marcas.html')
    cores = paleta()
    arte = mapas()
    faltando = []

    def par(app, cor_a, cor_b):
        a = vestido(arte.get(app, ''), cores[cor_a])
        b = vestido(arte.get(app, ''), cores[cor_b])
        if not a or not b:
            faltando.append(app)
        return a, b

    cartoes = []
    for app, hoje, prop, porque in MUDAM:
        a, b = par(app, hoje, prop)
        if not a:
            continue
        of, med, dom, fonte = MARCAS.get(app, ('', '', 0, ''))
        selo = ('<span class="tag fraco">o mais fraco</span>'
                if app == 'com.github.johnfactotum.Foliate' else
                '<span class="tag forte">citado por você</span>'
                if app in ('meow-whatsapp', 'steam') else '')
        cartoes.append(f'''
    <figure class="cartao">
      <div class="par">
        <span class="lado">
          <span class="g72">{a}</span><span class="g48">{a}</span>
          <em>hoje · {hoje}</em>
        </span>
        <span class="seta">→</span>
        <span class="lado">
          <span class="g72">{b}</span><span class="g48">{b}</span>
          <em class="novo">{prop}</em>
        </span>
        <span class="marca">
          <i style="background:{of}"></i>
          <small>logo<br>{of}</small>
        </span>
      </div>
      <figcaption>
        <b>{html.escape(app)}</b>{selo}
        <span class="chave">{hoje} {cores[hoje]} → {prop} {cores[prop]} ·
          marca medida {med} · dominância {dom:.0%} · {html.escape(fonte)}</span>
        <p class="porque">{porque}</p>
      </figcaption>
    </figure>''')

    ficam = []
    for app, cor, tipo, porque in FICAM:
        a = vestido(arte.get(app, ''), cores[cor])
        if not a:
            continue
        ficam.append(f'''
    <figure class="cartao mantem">
      <div class="par">
        <span class="lado"><span class="g72">{a}</span><em>{cor}</em></span>
        <span class="fica">fica</span>
      </div>
      <figcaption>
        <b>{html.escape(app)}</b><span class="tag {'mult' if tipo == 'multicolor' else 'ok'}">{tipo}</span>
        <p class="porque">{porque}</p>
      </figcaption>
    </figure>''')

    sem = ''.join(
        f'<li><span>{q}</span> <i>{c}</i><br><small>{p}</small></li>'
        for q, c, p in SEM_MARCA)

    doc = f'''<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MeowSystem — a cor puxada da marca</title>
<style>
  :root {{ --tinta:#cdd6f4; --fraco:#a6adc8; --linha:#313244; --caixa:#181825;
    --accent:#cba6f7; --papel:#1e1e2e; }}
  * {{ box-sizing:border-box }}
  body {{ margin:0; background:#11111b; color:var(--tinta);
    font:15px/1.55 "Inter","Cantarell",system-ui,sans-serif }}
  .envelope {{ max-width:1180px; margin:0 auto; padding:40px 24px 80px }}
  h1 {{ font-size:30px; margin:.2em 0 .3em; letter-spacing:-.02em }}
  h2 {{ font-size:18px; margin:0; font-weight:600 }}
  .olho {{ color:var(--accent); font-size:12px; letter-spacing:.14em;
    text-transform:uppercase; margin:0 }}
  .abre {{ color:var(--fraco); max-width:74ch; margin:0 0 22px }}
  .abre b {{ color:var(--tinta) }}
  .alerta {{ border:1px solid #f9e2af44; background:#f9e2af0f; border-radius:13px;
    padding:17px 20px; margin:0 0 28px; max-width:74ch }}
  .alerta h3 {{ margin:0 0 7px; font-size:14.5px; color:#f9e2af }}
  .alerta p {{ margin:0 0 8px; color:var(--fraco); font-size:13.5px }}
  .alerta p:last-child {{ margin:0 }}
  .painel {{ display:flex; flex-wrap:wrap; gap:10px; margin:0 0 34px }}
  .painel div {{ flex:1 1 190px; background:var(--caixa); border:1px solid var(--linha);
    border-radius:12px; padding:13px 16px }}
  .painel b {{ display:block; font-size:24px; font-weight:600 }}
  .painel small {{ color:var(--fraco); font-size:12.5px }}
  .cabeca {{ display:flex; align-items:baseline; justify-content:space-between; gap:10px;
    border-bottom:1px solid var(--linha); padding-bottom:9px; margin:0 0 16px }}
  .conta {{ color:var(--fraco); font-size:12px;
    font-family:ui-monospace,"JetBrains Mono",monospace }}
  .grade {{ display:grid; gap:12px; margin-bottom:42px;
    grid-template-columns:repeat(auto-fill,minmax(330px,1fr)) }}
  .cartao {{ margin:0; background:var(--papel); border:1px solid var(--linha);
    border-radius:13px; padding:16px 15px 14px }}
  .par {{ display:flex; align-items:center; justify-content:center; gap:13px;
    min-height:86px }}
  .lado {{ display:flex; flex-direction:column; align-items:center; gap:5px }}
  .lado em {{ font:10.5px/1 ui-monospace,"JetBrains Mono",monospace; color:var(--fraco);
    font-style:normal; letter-spacing:.03em }}
  .lado em.novo {{ color:#a6e3a1 }}
  .g72 {{ width:66px; height:66px; display:block }}
  .g48 {{ width:30px; height:30px; display:block; opacity:.95 }}
  .g72 svg, .g48 svg {{ width:100%; height:100% }}
  .seta {{ color:var(--fraco); font-size:19px }}
  .marca {{ display:flex; flex-direction:column; align-items:center; gap:4px;
    padding-left:9px; border-left:1px dashed var(--linha); margin-left:3px }}
  .marca i {{ width:26px; height:26px; border-radius:7px; display:block }}
  .marca small {{ font:9.5px/1.25 ui-monospace,"JetBrains Mono",monospace;
    color:var(--fraco); text-align:center }}
  .fica {{ color:var(--fraco); font-size:11px; letter-spacing:.09em;
    text-transform:uppercase }}
  .mantem {{ opacity:.92 }}
  figcaption {{ margin-top:13px; display:flex; flex-direction:column; gap:4px }}
  figcaption b {{ font-size:12.5px; font-weight:600; overflow-wrap:anywhere }}
  .chave {{ font:10.5px/1.45 ui-monospace,"JetBrains Mono",monospace; color:var(--fraco);
    overflow-wrap:anywhere }}
  .tag {{ align-self:flex-start; font-size:10px; letter-spacing:.06em;
    text-transform:uppercase; border-radius:999px; padding:2px 9px; margin-top:2px }}
  .forte {{ background:rgba(203,166,247,.15); color:#cba6f7 }}
  .fraco {{ background:rgba(249,226,175,.13); color:#f9e2af }}
  .mult {{ background:rgba(137,180,250,.13); color:#89b4fa }}
  .ok {{ background:rgba(166,227,161,.12); color:#a6e3a1 }}
  .porque {{ color:var(--fraco); font-size:12.5px; margin:5px 0 0; line-height:1.5 }}
  .porque b {{ color:var(--tinta) }}
  code {{ background:#11111b; border:1px solid var(--linha); border-radius:5px;
    padding:1px 5px; font-size:11.5px }}
  .fecho {{ border:1px solid var(--linha); border-radius:14px; padding:20px 22px;
    background:var(--caixa) }}
  .fecho h3 {{ margin:0 0 9px; font-size:15px }}
  .fecho ul {{ margin:0 0 18px; padding-left:19px; color:var(--fraco); font-size:13px }}
  .fecho li {{ margin:7px 0 }}
  .fecho li i {{ color:#a6e3a1; font-style:normal;
    font-family:ui-monospace,"JetBrains Mono",monospace; font-size:12px }}
  .fecho li small {{ color:#7f849c; font-size:12px }}
  .custo {{ display:flex; flex-wrap:wrap; gap:7px; margin:10px 0 0 }}
  .custo span {{ font:11px/1 ui-monospace,"JetBrains Mono",monospace; padding:5px 9px;
    border:1px solid var(--linha); border-radius:7px; color:var(--fraco) }}
</style></head>
<body><div class="envelope">
  <p class="olho">MeowSystem · cor por marca · 23/08/2026</p>
  <h1>A cor do traço puxada da logo</h1>
  <p class="abre">
    Você disse: <b>"a cor de alguns svgs tão diferentes das logos originais.
    tipo a do wpp ou steam, chrome"</b>. Esta folha responde. O estilo
    <b>não muda</b> — traço fino, <code>fill:none</code>, cor da paleta
    Catppuccin. Muda só <b>qual</b> cor da paleta cada aplicativo recebe.
    Cada cartão mostra o arquivo exato de hoje e o arquivo exato que entraria,
    a 66 e a 30&nbsp;px, com a cor real do logo ao lado para conferir.
    <b>Nada foi aplicado no sistema.</b>
  </p>

  <div class="alerta">
    <h3>Antes de aprovar: isto desfaz uma escolha sua</h3>
    <p>Em <b>10/08/2026</b> eu te dei três opções — "uma cor só", "por categoria"
      e "uma a uma" — e você escolheu <b>por categoria</b>. Cor por marca é a
      terceira opção com outro nome. As duas não convivem.</p>
    <p>O custo tem nome: a categoria <b>"rede"</b>, que hoje é <code>sky</code>
      inteira, se reparte em quatro cores e deixa de existir como cor.</p>
    <div class="custo">
      <span>WhatsApp → green</span><span>Discord → lavender</span>
      <span>Telegram → sapphire</span><span>Thunderbird → blue</span>
      <span>qBittorrent → blue</span>
    </div>
  </div>

  <div class="painel">
    <div><b>{len(MUDAM)}</b><small>mudam de cor</small></div>
    <div><b>{41 - len(MUDAM)}</b><small>ficam como estão</small></div>
    <div><b>0</b><small>hex fora da paleta</small></div>
    <div><b>0</b><small>desenhos alterados</small></div>
  </div>

  <div class="cabeca">
    <h2>Os {len(MUDAM)} que mudam</h2>
    <span class="conta">cor de hoje → cor proposta · logo à direita</span>
  </div>
  <div class="grade">{''.join(cartoes)}</div>

  <div class="cabeca">
    <h2>Os que NÃO mudam — e por quê</h2>
    <span class="conta">a mudança é cirúrgica, não uma repintura</span>
  </div>
  <div class="grade">{''.join(ficam)}</div>

  <div class="fecho">
    <h3>Sem marca nenhuma: a categoria continua servindo</h3>
    <ul>{sem}</ul>
    <h3>Como isto liga — e como desliga</h3>
    <p class="porque" style="margin:0 0 10px">
      O código já está escrito e <b>desligado</b>. Ligar é uma linha no
      <code>~/.config/meow/meow.conf</code>:
      <code>ICONES_COR_MARCA="sim"</code>, e depois
      <code>meow icones</code>. Desligar é a mesma linha com <code>"nao"</code> —
      e desligar <b>desliga</b>: o instalador é dono único de
      <code>48x48/apps</code> e reescreve por conteúdo divergente, então a cor de
      categoria volta sozinha na passagem seguinte. Não fica resíduo.
    </p>
    <p class="porque" style="margin:0">
      Escolher só uma parte também vale: cada linha de
      <code>icons/apps-marca.map</code> é independente. Apagar a do Foliate, ou a
      do Brave, não afeta as outras.
    </p>
  </div>
</div></body></html>
'''
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    with open(saida, 'w', encoding='utf-8') as fh:
        fh.write(doc)
    print(saida)
    if faltando:
        print('SEM ARTE no acervo: ' + ', '.join(sorted(set(faltando))), file=sys.stderr)
        return 1
    print(f'{len(MUDAM)} mudam · {len(FICAM)} ficam com motivo · nada instalado')
    return 0


if __name__ == '__main__':
    sys.exit(main())

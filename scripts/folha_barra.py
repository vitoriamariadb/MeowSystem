#!/usr/bin/env python3
# folha_barra.py — a folha dos ícones da BARRA (applets + bandeja).
#
# A PERGUNTA DELA, EM 10/08/2026
#   Depois de unificar os 35 do lançador em Arcticons: "os ícones da tray e do
#   applet tão sincronizados também?" Não estavam. Medido: dos 30 ícones que os
#   applets da barra realmente pedem, 26 vinham do Papirus-Dark e 4 do `hicolor`.
#   ZERO do nosso tema. O `assets/icones/sistema.map` já é Arcticons, mas cobre os
#   `preferences-*-symbolic`, que são as PÁGINAS do app Ajustes — não a barra.
#
#   Ela escolheu trocar o que tivesse glifo e manter o resto. Esta folha existe
#   porque a medição feita DEPOIS dessa escolha mudou o que a escolha significa.
#
# O ACHADO QUE DERRUBA A TROCA: O ARCTICONS NÃO TEM VOCABULÁRIO DE ESTADO
#   O pack é de ícones de APLICATIVO Android. Ele tem 14.996 nomes e quase todos
#   são marcas. Buscando por substring o que faltava:
#
#     mute    -> só `mutereminder`, que é um app
#     bell    -> `taco-bell`, `mybell`, `bell-smart-home` — todos apps
#     power   -> `microsoft-powerpoint`, `chargemap`, `apowermirror` — apps
#     pause · logout · ethernet -> ZERO
#
#   Os oito nomes que "casaram" numa primeira contagem (volume, wifi, battery,
#   bluetooth, lock, moon, next, reboot) existem por acaso: são palavras curtas
#   que um app qualquer também usa. Nenhum é parte de um conjunto de estados.
#
#   E estado é o que a barra É. `audio-volume-high` e `audio-volume-muted` não
#   são dois ícones: são dois quadros do MESMO ícone. Vestir um e não o outro
#   faz o desenho trocar de linguagem no instante em que ela aperta mudo — que é
#   pior que a barra inteira numa linguagem só.
#
#   Resultado por família, medido: DEZ famílias, ZERO completas.
#     volume 3/4 · wifi 3/4 · energia 4/5 · bluetooth 2/3 · rede 1/2 · brilho 1/2
#     bateria 1/4 · notificação 1/3 · mídia 1/3 · microfone 0/2
#
# O QUE A FOLHA MOSTRA, ENTÃO
#   Os dois lados honestos, no tamanho real da barra (20 px, medido no
#   `icones_bandeja.sh`) e ampliado a 64 px para a vista: o Papirus symbolic de
#   hoje e o Arcticons onde ele existe — com o buraco marcado em vermelho onde
#   não existe. É para ela ver que o Papirus symbolic JÁ é traço fino
#   monocromático, e decidir se a diferença que sobra justifica o estrago.
#
#   uso: scripts/folha_barra.py [saida.html]
#        (padrão: ~/Documentos/meow-icones-barra.html)

import base64
import html
import os
import sys

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk  # noqa: E402

HOME = os.path.expanduser('~')
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONF_TK = os.path.join(HOME, '.config/cosmic/com.system76.CosmicTk/v1/icon_theme')
# Os glifos candidatos ficam FORA de `assets/icones/arcticons/`: nada aqui foi decidido,
# e um acervo é o que os scripts instalam. Ver `assets/icones/PROCEDENCIA.md`.
CAND = os.path.join(os.environ.get('MEOW_PREVIA_BARRA',
                    '/tmp/meow-trabalho'
                    'e4e8c324-c21e-476b-9f65-a21e0f4250f6/scratchpad/barra'))

# (família · [(ícone que o applet pede, glifo Arcticons ou None, o que é)])
FAMILIAS = [
    ('Volume', 'O applet troca de ícone conforme o nível — e quando você muta.', [
        ('audio-volume-high-symbolic',   'volume',  'alto'),
        ('audio-volume-medium-symbolic', 'volume',  'médio'),
        ('audio-volume-low-symbolic',    'volume',  'baixo'),
        ('audio-volume-muted-symbolic',  None,      'MUDO'),
    ]),
    ('Wi-Fi', 'Quatro quadros de intensidade, mais o desconectado.', [
        ('network-wireless-signal-excellent-symbolic', 'wifi', 'ótimo'),
        ('network-wireless-signal-good-symbolic',      'wifi', 'bom'),
        ('network-wireless-signal-weak-symbolic',      'wifi', 'fraco'),
        ('network-wireless-offline-symbolic',          None,   'OFFLINE'),
    ]),
    ('Bateria', 'O estado que mais muda no dia, e o único coberto é o cheio.', [
        ('battery-full-symbolic',     'battery', 'cheia'),
        ('battery-low-symbolic',      None,      'FRACA'),
        ('battery-caution-symbolic',  None,      'CRÍTICA'),
        ('battery-charging-symbolic', None,      'CARREGANDO'),
    ]),
    ('Energia', 'A melhor cobertura das oito — e ainda assim quebrada em dois estados.', [
        ('system-shutdown-symbolic',   'power',  'desligar'),
        ('system-lock-screen-symbolic', 'lock',  'bloquear'),
        ('system-suspend-symbolic',    'moon',   'suspender'),
        # `arcticons/reboot` foi descartado ao ser RASTERIZADO: o desenho não é
        # uma seta de reinício, é uma FIGURA HUMANA — a marca de algum app
        # chamado "reboot". É a quarta vez neste projeto que um nome certo
        # entrega um desenho errado (ver `markdown`, `shop`, `zip` no
        # `folha_proposta.py`). Conferir o nome no índice nunca basta.
        ('system-reboot-symbolic',     None,     'REINICIAR'),
        ('system-log-out-symbolic',    None,     'SAIR'),
    ]),
    ('Bluetooth', None, [
        ('cosmic-applet-bluetooth-active-symbolic',   'bluetooth', 'ligado'),
        ('cosmic-applet-bluetooth-disabled-symbolic', None,        'DESLIGADO'),
    ]),
    ('Notificações', None, [
        ('cosmic-applet-notification-symbolic',          'notifications', 'normal'),
        ('cosmic-applet-notification-new-symbolic',      None,            'TEM NOVA'),
        ('cosmic-applet-notification-disabled-symbolic', None,            'SILENCIADA'),
    ]),
    ('Rede com fio', None, [
        ('network-wired-symbolic',              'network', 'conectado'),
        ('network-wired-disconnected-symbolic', None,      'SEM CABO'),
    ]),
    ('Microfone', 'Nenhum dos dois existe no pack.', [
        ('microphone-sensitivity-high-symbolic',  None, 'ATIVO'),
        ('microphone-sensitivity-muted-symbolic', None, 'MUDO'),
    ]),
]


def main():
    saida = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        HOME, 'Documentos', 'meow-icones-barra.html')
    tema = 'MeowSystem-Icons'
    if os.path.exists(CONF_TK):
        tema = open(CONF_TK, encoding='utf-8').read().strip().strip('"') or tema
    t = Gtk.IconTheme.new()
    t.set_custom_theme(tema)

    def hoje(nome):
        # 20 px é o tamanho medido da barra (ver `scripts/icones_bandeja.sh`).
        i = t.lookup_icon(nome, 20, 0)
        f = i.get_filename() if i else None
        if not f or not os.path.exists(f):
            return None, None
        tipo = 'image/svg+xml' if f.endswith('.svg') else 'image/png'
        with open(f, 'rb') as fh:
            dado = f'data:{tipo};base64,' + base64.b64encode(fh.read()).decode('ascii')
        origem = ('Papirus' if 'Papirus' in f else
                  'MeowSystem' if 'MeowSystem' in f else
                  'hicolor' if 'hicolor' in f else '?')
        return dado, origem

    def glifo(nome):
        p = os.path.join(CAND, f'{nome}.svg')
        if not os.path.exists(p):
            return None
        svg = open(p, encoding='utf-8').read()
        return (svg.replace('currentColor', '#cdd6f4')
                   .replace('width="1em" height="1em"', 'width="100%" height="100%"'))

    secoes, n_ok, n_zero = [], 0, 0
    for fam, nota, itens in FAMILIAS:
        cel = []
        for pedido, cand, estado in itens:
            arte, origem = hoje(pedido)
            g = glifo(cand) if cand else None
            if g:
                n_ok += 1
                depois = (f'<span class="g64">{g}</span>'
                          f'<span class="g20">{g}</span>')
                selo = f'<span class="tag ok">arcticons/{html.escape(cand)}</span>'
            else:
                n_zero += 1
                depois = '<span class="buraco">sem glifo</span>'
                selo = '<span class="tag zero">fica no Papirus</span>'
            img = (f'<img class="i64" src="{arte}" alt="">'
                   f'<img class="i20" src="{arte}" alt="">') if arte else \
                  '<span class="buraco">—</span>'
            cel.append(f'''
        <div class="par{'' if g else ' quebra'}">
          <div class="col"><span class="rot">hoje · {html.escape(origem or "?")}</span>{img}</div>
          <span class="seta">→</span>
          <div class="col">{depois}</div>
          <div class="fim">
            <b>{html.escape(estado)}</b>
            <code>{html.escape(pedido)}</code>
            {selo}
          </div>
        </div>''')
        completa = all(c for _, c, _ in itens)
        marca = ('<span class="conta boa">completa</span>' if completa else
                 f'<span class="conta ruim">{sum(1 for _,c,_ in itens if c)}/{len(itens)}</span>')
        explica = f'<p class="explica">{html.escape(nota)}</p>' if nota else ''
        secoes.append(f'''
      <section class="grupo">
        <header class="cabeca"><h2>{html.escape(fam)}</h2>{marca}</header>
        {explica}
        <div class="lista">{''.join(cel)}</div>
      </section>''')

    doc = f'''<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MeowSystem — os ícones da barra</title>
<style>
  :root {{ --tinta:#cdd6f4; --fraco:#a6adc8; --linha:#313244; --caixa:#181825;
    --accent:#cba6f7; --papel:#1e1e2e; --vermelho:#f38ba8; --verde:#a6e3a1; }}
  * {{ box-sizing:border-box }}
  body {{ margin:0; background:#11111b; color:var(--tinta);
    font:15px/1.55 "Inter","Cantarell",system-ui,sans-serif }}
  .envelope {{ max-width:1000px; margin:0 auto; padding:40px 24px 80px }}
  h1 {{ font-size:29px; margin:.2em 0 .3em; letter-spacing:-.02em }}
  .olho {{ color:var(--accent); font-size:12px; letter-spacing:.14em;
    text-transform:uppercase; margin:0 }}
  .abre {{ color:var(--fraco); max-width:72ch; margin:0 0 22px }}
  .painel {{ display:flex; flex-wrap:wrap; gap:10px; margin:0 0 20px }}
  .painel div {{ flex:1 1 210px; background:var(--caixa); border:1px solid var(--linha);
    border-radius:12px; padding:13px 16px }}
  .painel b {{ display:block; font-size:24px; font-weight:600 }}
  .painel small {{ color:var(--fraco); font-size:12.5px }}
  .painel .r b {{ color:var(--vermelho) }} .painel .v b {{ color:var(--verde) }}
  .aviso {{ border:1px solid var(--vermelho); border-radius:14px; padding:18px 20px;
    background:rgba(243,139,168,.06); margin:0 0 34px; font-size:14px }}
  .aviso b {{ color:var(--vermelho) }}
  .aviso code {{ background:#11111b; border:1px solid var(--linha); border-radius:5px;
    padding:1px 6px; font-size:12.5px }}
  .grupo {{ margin:0 0 30px }}
  .cabeca {{ display:flex; align-items:center; justify-content:space-between;
    border-bottom:1px solid var(--linha); padding-bottom:8px; margin-bottom:12px }}
  .cabeca h2 {{ font-size:17px; margin:0; font-weight:600 }}
  .conta {{ font-size:12px; border-radius:999px; padding:2px 11px;
    font-family:ui-monospace,monospace }}
  .conta.boa {{ background:rgba(166,227,161,.14); color:var(--verde) }}
  .conta.ruim {{ background:rgba(243,139,168,.14); color:var(--vermelho) }}
  .explica {{ color:var(--fraco); font-size:13px; margin:0 0 14px }}
  .lista {{ display:flex; flex-direction:column; gap:8px }}
  .par {{ display:grid; grid-template-columns:auto 20px auto 1fr; align-items:center;
    gap:14px; background:var(--papel); border:1px solid var(--linha);
    border-radius:11px; padding:12px 16px }}
  .par.quebra {{ border-color:rgba(243,139,168,.4) }}
  .col {{ display:flex; align-items:center; gap:9px; min-width:104px }}
  .rot {{ font-size:10px; color:var(--fraco); opacity:.75; margin-right:2px }}
  .i64, .g64 {{ width:64px; height:64px; display:block }}
  .i20, .g20 {{ width:20px; height:20px; display:block }}
  .g64 svg, .g20 svg {{ width:100%; height:100% }}
  .i64, .i20 {{ filter:brightness(0) invert(88%) sepia(9%) saturate(700%) hue-rotate(190deg) }}
  .buraco {{ color:var(--vermelho); font-size:12px; font-style:italic; width:104px }}
  .seta {{ color:var(--fraco); text-align:center }}
  .fim {{ display:flex; flex-direction:column; gap:3px; min-width:0 }}
  .fim b {{ font-size:13px }}
  .fim code {{ font:11px/1.4 ui-monospace,monospace; color:var(--fraco);
    overflow-wrap:anywhere }}
  .tag {{ align-self:flex-start; font-size:10px; letter-spacing:.05em;
    text-transform:uppercase; border-radius:999px; padding:2px 9px; margin-top:2px }}
  .tag.ok {{ background:rgba(166,227,161,.13); color:var(--verde) }}
  .tag.zero {{ background:rgba(243,139,168,.13); color:var(--vermelho) }}
  .fecho {{ border-top:1px solid var(--linha); padding-top:18px; color:var(--fraco);
    font-size:13.5px; max-width:74ch }}
  @media (max-width:700px) {{ .par {{ grid-template-columns:1fr; }} .seta {{ display:none }} }}
</style></head>
<body><div class="envelope">
  <p class="olho">MeowSystem · barra do COSMIC</p>
  <h1>Os ícones da barra — e por que a troca não fecha</h1>
  <p class="abre">
    Cada linha é um ÍCONE DE ESTADO que os applets pedem. À esquerda o que está na sua
    barra hoje; à direita o que o Arcticons daria — ou o buraco, em vermelho, onde ele
    não tem nada. Os dois lados aparecem em 64&nbsp;px e no tamanho real da barra,
    <b>20&nbsp;px</b>. <b>Nada foi aplicado.</b>
  </p>
  <div class="painel">
    <div class="v"><b>{n_ok}</b><small>estados com glifo no Arcticons</small></div>
    <div class="r"><b>{n_zero}</b><small>estados sem glifo — ficariam no Papirus</small></div>
    <div class="r"><b>0</b><small>famílias completas, de 8 examinadas</small></div>
    <div class="r"><b>4</b><small>nomes certos que entregaram desenho errado</small></div>
  </div>

  <div class="aviso">
    <b>O motivo é a natureza do pack, e não dá para contornar.</b> O Arcticons é um acervo
    de ícones de <b>aplicativo Android</b>: 14.996 nomes, quase todos marcas. Ele não tem
    vocabulário de estado de sistema. Procurando o que falta, o que aparece são apps:
    <code>mute</code> → <code>mutereminder</code> · <code>bell</code> →
    <code>taco-bell</code> · <code>power</code> → <code>microsoft-powerpoint</code>.
    <code>pause</code>, <code>logout</code> e <code>ethernet</code> dão zero.
    Os nomes que casaram — <code>volume</code>, <code>wifi</code>, <code>battery</code> —
    existem por acaso, não como parte de um conjunto.<br><br>
    E estado é o que a barra <b>é</b>: <code>audio-volume-high</code> e
    <code>audio-volume-muted</code> não são dois ícones, são dois quadros do mesmo. Vestir
    um e não o outro faz o desenho <b>trocar de linguagem no instante em que você aperta
    mudo</b> — mais visível que a diferença que a troca queria corrigir.
  </div>

  {''.join(secoes)}

  <p class="fecho">
    Repare no lado esquerdo: o Papirus symbolic é <b>chapado</b> — silhueta preenchida,
    sem contorno. O Arcticons é o oposto: contorno de 1&nbsp;px, miolo vazado. Então a
    sua queixa tem fundamento — <b>são mesmo duas linguagens</b>, e não uma variação de
    peso. O que as iguala é só a cor, porque o COSMIC descarta a cor do arquivo e repinta
    tudo na cor de texto do tema (medido no <code>docs/COSMIC-THEMING.md</code> §4g).
    <br><br>
    A escolha, então, é entre <b>uma barra chapada e íntegra</b> e <b>uma barra vazada
    pela metade</b>: {n_ok} estados em contorno e {n_zero} chapados, alternando entre as
    duas linguagens conforme o volume, a bateria ou o sinal mudam. Não há terceira opção
    dentro do Arcticons — a folha acima é o acervo inteiro, não uma amostra.
  </p>
</div></body></html>
'''
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    with open(saida, 'w', encoding='utf-8') as fh:
        fh.write(doc)
    print(saida)
    print(f'{n_ok} com glifo · {n_zero} sem glifo')


if __name__ == '__main__':
    main()

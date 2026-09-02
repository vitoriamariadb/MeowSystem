#!/usr/bin/env bash
# icones_tray_zapzap.sh — o ícone da BANDEJA do ZapZap, e o motivo pelo qual ele
#                         voltava ao de fábrica sem ninguém pedir.
#
# ============================================================================
# A QUEIXA DELA, EM 23/08/2026
# ============================================================================
#
#   "ao atualizar o flatpak tipo zap zap, o tray, o icon que fica no applet,
#    voltaram aos originais. ao invés de respeitar o mesmo icon do wpp e afins"
#
# Está certa, e o repositório já tinha PREVISTO isto por escrito em 10/08 —
# `assets/icones/bandeja.map`, seção "O ZAPZAP FOI VESTIDO NA FONTE":
#
#   "Um `flatpak update com.rtosta.zapzap` devolve o arquivo de fábrica e o
#    ícone volta a destoar, SEM NADA ACUSANDO."
#
# Aconteceu. `flatpak history` diz a hora exata:
#
#   ago 20 03:30:35   pull          com.rtosta.zapzap  stable  user
#   ago 20 03:30:36   deploy update com.rtosta.zapzap  stable  user
#
# E o disco confirma que a manobra de 10/08 sumiu inteira. Medido hoje:
#
#   diff assets/icones/tray-terceiros/zapzap-tray_icon.py.original \
#        ~/.local/share/flatpak/app/com.rtosta.zapzap/…/tray_icon.py
#   -> IDÊNTICOS (o arquivo vivo é o de fábrica outra vez)
#   stat -> 2 links   (hardlink do OSTree INTACTO: nunca foi quebrado nesta
#                      árvore de deploy, porque esta árvore é nova)
#
# A previsão estava no papel e não havia gatilho nenhum para agir sobre ela.
# Este script é a metade "o que reaplicar"; o `systemd/meow-flatpak.path` é a
# metade "quando".
#
# ============================================================================
# O TEMA NÃO ALCANÇA ESTE ÍCONE — REMEDIDO NO D-BUS AO VIVO EM 23/08/2026
# ============================================================================
#
# O cabeçalho do `icones_bandeja.sh` afirmava, desde 08/08, que o ZapZap manda
# `IconPixmap` e por isso nenhum tema o alcança. A afirmação foi POSTA À PROVA
# hoje, contra o ZapZap 7.4.2, rodando o código de bandeja REAL do app (o
# `TrayIcon.getIcon()` dele, dentro do sandbox dele) e lendo as propriedades do
# item no `org.kde.StatusNotifierItem`:
#
#   Id                 'meow_probe_tray.py'
#   Title              'meow_probe_tray.py'
#   Category           'ApplicationStatus'
#   Status             'Active'
#   IconName           ''            <- VAZIO
#   IconThemePath      GDBus.Error:…UnknownProperty: a propriedade NEM EXISTE
#   IconPixmap         2 quadros: 22×22 e 64×64, 109.955 bytes de raster
#
# CONFIRMADA, E MAIS FORTE DO QUE ESTAVA ESCRITO. O cabeçalho antigo dizia que
# `IconThemePath` "se vier preenchido" vence o tema; no ZapZap ele não vem vazio,
# ele NÃO É EXPORTADO — o `QDBusTrayIcon` do Qt sequer publica essa propriedade.
# Com `IconName` vazio e dois rasters prontos dentro da mensagem, não há nome
# para o tema resolver. Nenhum arquivo em `MeowSystem-Icons/20x20/status/`
# alcança este ícone, hoje ou nunca.
#
# CONTRAPROVA NA MESMA SESSÃO, no item que estava vivo na barra dela:
#   qBittorrent  IconName=''  IconThemePath=''  IconPixmap=[(22,22,…)]
# Mesmo beco, e continua sendo os dois apps que o mapa já listava.
#
# COMO A MEDIÇÃO FOI FEITA SEM ABRIR O WHATSAPP DELA
#   Não se abriu o ZapZap. Rodou-se `python3` DENTRO do flatpak dele
#   (`flatpak run --command=python3 com.rtosta.zapzap`), importando o módulo real
#   `zapzap.assets.icons.tray_icon` e pendurando um `QSystemTrayIcon` com o ícone
#   que o app usaria. Duas tentativas, e a primeira ensina algo:
#
#     QT_QPA_PLATFORM=offscreen  -> isSystemTrayAvailable() = False, não registra
#     QT_QPA_PLATFORM=xcb (Xvfb) -> registra, e aí dá para ler as propriedades
#
#   O plano era prendê-lo num barramento privado (`dbus-daemon --address=…`) para
#   não encostar na barra dela. NÃO FUNCIONOU, e o motivo merece ficar escrito: o
#   `flatpak run` monta um `xdg-dbus-proxy` e REESCREVE `DBUS_SESSION_BUS_ADDRESS`
#   dentro do sandbox — o `--env=` foi ignorado e o item registrou-se no
#   barramento de sessão de verdade. Conferido depois: o item sumiu do
#   `RegisteredStatusNotifierItems` quando o processo morreu, e a barra dela
#   voltou a ter só o qBittorrent. Se alguém repetir isto, saiba que o item
#   APARECE na barra dela por alguns segundos.
#
# ============================================================================
# ENTÃO A SAÍDA É A MESMA DE 10/08: TROCAR O DESENHO NA FONTE DO APP
# ============================================================================
#
# O ZapZap não lê arquivo de ícone nenhum para a bandeja. Ele monta o SVG como
# uma STRING dentro do código e rasteriza:
#
#   zapzap/assets/icons/tray_icon.py
#     _SYMBOLIC = """…<path … fill: {color};" d="M 16.93…"/>…{notify}</svg>"""
#     def __build(svg_str) -> QIcon:
#         qimg = QImage.fromData(bytearray(svg_str,'utf-8'), 'SVG')
#         qpix = QPixmap.fromImage(qimg)
#         return QIcon(qpix.scaled(QSize(128, 128)))
#
# Um `QIcon` feito de PIXMAP viaja como `IconPixmap` — é a linha que fecha a
# medição acima. E é também a porta: a constante é editável.
#
# POR QUE A EDIÇÃO É ESTRUTURAL, E NÃO UM ARQUIVO INTEIRO POR CIMA
#   O `assets/icones/bandeja.map` avisa, com razão, que "se um dia o ZapZap mudar o
#   formato daquela constante, reaplicar às cegas pode QUEBRAR O APP — é código
#   Python sendo editado, não um PNG".
#
#   Copiar por cima um `tray_icon.py` guardado atenderia HOJE e quebraria no dia
#   em que o ZapZap acrescentasse um tema, um tamanho ou um campo — a versão
#   guardada apagaria o resto do arquivo junto. Por isso a manobra aqui:
#
#     1. acha o bloco `_SYMBOLIC = """ … """` por expressão regular;
#     2. RECUSA se não achar exatamente um;
#     3. RECUSA se o corpo não tiver `{color}` E `{notify}` — os dois campos de
#        `str.format` que o app preenche depois. Sem `{color}` morrem o
#        `symbolic_light`/`symbolic_dark`; sem `{notify}` morre o contador
#        vermelho de não-lidas. Preservá-los não é gentileza: é o que faz o
#        arquivo continuar sendo o que o resto do app espera;
#     4. troca SÓ o corpo daquele bloco, e deixa o arquivo inteiro em paz;
#     5. compila o resultado (`compile()`) antes de gravar. Um `SyntaxError`
#        aqui é o ZapZap que não abre mais — a checagem custa milissegundos e
#        é a diferença entre um ícone feio e um aplicativo morto.
#
#   Nada disso depende de conhecer a versão do ZapZap. Um `tray_icon.py` novo,
#   que ninguém nunca viu, é vestido do mesmo jeito desde que tenha a forma
#   acima; e se não tiver, o script SAI COM 3 E DIZ POR QUÊ, em vez de escrever.
#
# O `viewBox` CONTINUA `0 0 256 256`, E ISSO NÃO É PREGUIÇA
#   O glifo do Arcticons é numa grade de 48. Seria natural trocar o `viewBox`
#   junto — e quebraria o contador: `_DEFAULT_NOTIFICATION` desenha o balão
#   vermelho em coordenadas ABSOLUTAS daquela grade de 256
#   (`y="116.592" width="100.1" x="152.6" height="136.107"`), e é injetado no
#   `{notify}` DEPOIS, sem passar por transformação nenhuma. Mudar o `viewBox`
#   mandaria o contador para fora da tela. O glifo entra dentro de um
#   `<g transform="scale(5.3333333)">` — 256/48 — e o `{notify}` continua caindo
#   onde o app o desenha.
#
# O TRAÇO É 4, O NÚMERO DELA, NA GRADE DE 48
#   Mesmo número do `icones_bandeja.sh` e do `icones_tray_steam.sh`: 4 de 48 =
#   8,33% da caixa, em qualquer tamanho. Depois do `scale(5.3333)` isso vira
#   21,33 unidades na grade de 256 — a MESMA fração, que é o que importa; o
#   rasterizador não vê a grade, vê a proporção. A conta inteira e o porquê do 4
#   estão no cabeçalho do `icones_bandeja.sh`.
#
# O HARDLINK DO OSTREE TEM DE SER QUEBRADO, NÃO SOBRESCRITO
#   Medido hoje: `stat` do arquivo de fábrica devolve `2 links`. O segundo é o
#   objeto dentro do repositório OSTree do flatpak
#   (`~/.local/share/flatpak/repo/objects/…`). Escrever POR CIMA do inode
#   alteraria o objeto do repo — uma coisa que o flatpak considera imutável e
#   cujo checksum é o nome do próprio arquivo. O que este script faz é gravar um
#   temporário NO MESMO DIRETÓRIO e `mv -f` por cima: o `rename(2)` troca a
#   ENTRADA de diretório, o objeto do repo continua com o link dele, e a árvore
#   de deploy passa a ter arquivo próprio (`1 link`). O repo fica intacto.
#
# O `__pycache__` SAI JUNTO
#   Ao lado do arquivo há `__pycache__/tray_icon.cpython-313.pyc`. O Python
#   invalida `.pyc` por tamanho+mtime da fonte, e os dois mudam aqui — então na
#   prática ele já seria ignorado. O `.pyc` é removido mesmo assim porque a
#   instrução de DESFAZER do `assets/icones/bandeja.map` manda removê-lo, e deixar para
#   trás um arquivo compilado de um código que não existe mais é a espécie de
#   detalhe que custa uma tarde daqui a um ano. O `/app` é somente-leitura dentro
#   do sandbox: o ZapZap recompila em memória a cada abertura, o que para UM
#   arquivo pequeno não é custo mensurável.
#
# ============================================================================
# O DE FÁBRICA É GUARDADO ANTES DE TODA PRIMEIRA ESCRITA
# ============================================================================
#
#   ~/.local/state/meowsystem/zapzap/tray_icon.py.<commit>.fabrica
#
# Um por COMMIT de deploy — que é o diretório que o `flatpak update` troca. Assim
# o desfazer funciona mesmo para uma versão do ZapZap que este repositório nunca
# viu, e não depende do `assets/icones/tray-terceiros/zapzap-tray_icon.py.original`, que
# é a fotografia de UMA versão (a de 10/08, que por acaso é igual à de hoje).
#
# `--desfazer` põe o guardado de volta. É o que o `install.sh --uninstall` chama:
# deixar o flatpak dela vestido depois de desinstalar o MeowSystem seria a mesma
# falta que o `lib/desinstalar.sh` já corrige para o hook de apt — um efeito sem
# nada instalado que o explique.
#
# ============================================================================
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo
#   1 divergia e foi consertado (no seco: divergia)
#   2 erro
#   3 falta dependência — o ZapZap não está instalado, OU o `tray_icon.py` dele
#     mudou de forma e este script se recusa a adivinhar
# ============================================================================
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

APP_ID="${MEOW_TRAY_ZAPZAP_APP:-com.rtosta.zapzap}"
GLIFO="${MEOW_TRAY_ZAPZAP_GLIFO:-$RAIZ/assets/icones/arcticons/whatsapp.svg}"
TRACO="${MEOW_TRAY_ZAPZAP_TRACO:-4}"
GUARDA="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/zapzap"

MODO=aplicar
case "${1:-}" in
  --conferir) MODO=conferir ;;
  --desfazer) MODO=desfazer ;;
  ''|--aplicar) MODO=aplicar ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--desfazer]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && [ "$MODO" = aplicar ] && MODO=conferir

# --- onde o tray_icon.py mora ------------------------------------------------
# O caminho tem a VERSÃO DO PYTHON no meio (`lib/python3.13/`), e ela muda quando
# o runtime do flatpak muda de base. Fixar `python3.13` faria o script parar de
# achar o arquivo na próxima troca de runtime — calado, que é o pior modo de
# parar. O glob resolve, e mais de um resultado é motivo para desistir e falar.
_arquivo_alvo() {
  local loc achados=()
  loc="$(flatpak info --show-location "$APP_ID" 2>/dev/null)" || return 1
  [ -n "$loc" ] && [ -d "$loc" ] || return 1
  local f
  for f in "$loc"/files/lib/python3*/site-packages/zapzap/assets/icons/tray_icon.py; do
    [ -f "$f" ] && achados+=("$f")
  done
  [ "${#achados[@]}" = 1 ] || return 1
  printf '%s\n' "${achados[0]}"
}

# O identificador do deploy é o nome do diretório de commit — 64 hex que o
# `flatpak update` troca por outro. É o que faz o backup de fábrica ser "o de
# ANTES desta versão", e não um arquivo que se sobrescreve para sempre.
_commit_de() {
  local loc; loc="$(flatpak info --show-location "$APP_ID" 2>/dev/null)" || return 1
  basename "$loc"
}

# --- o corpo do SVG que queremos, montado do glifo ---------------------------
# Sai UMA linha de `<path …>` por elemento do glifo, já com o traço dela. O
# `_com_traco` é a mesma transformação do `icones_bandeja.sh` e do
# `icones_tray_steam.sh`: um `stroke-width` por elemento, nunca dois — duplicar
# invalida o XML e o rasterizador recusa o SVG inteiro, calado.
_com_traco() {
  if grep -q 'stroke-width' "$GLIFO"; then
    sed -E 's/stroke-width="[^"]*"/stroke-width="'"$TRACO"'"/g' "$GLIFO"
  else
    sed -E 's/<(circle|rect|line|polyline|polygon|path|ellipse) /<\1 stroke-width="'"$TRACO"'" /g' "$GLIFO"
  fi
}

_pronto() {
  if [ ! -f "$GLIFO" ]; then
    meow_pula "não existe $GLIFO — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! meow_tem flatpak; then
    meow_pula "sem flatpak nesta máquina — o ZapZap não tem como estar aqui"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  # POR DIRETÓRIO, NÃO POR `flatpak info` — E ISSO É CONSERTO DE 24/08/2026.
  # `flatpak info` cria um repositório ostree INTEIRO em ~/.local/share/flatpak
  # só por ter sido perguntado. `lib/comum.sh` documenta a armadilha desde
  # 10/08 e oferece o `meow_flatpak_tem` justamente para isto; este script era o
  # único chamador que ainda perguntava do jeito caro. O preço não era teórico:
  # `tests/seco.sh` — o canário que garante que `MEOW_DRY_RUN=1` não escreve
  # nada — reprovava com `./.local/share/flatpak/.changed` e
  # `./.local/share/flatpak/repo/config`, e reprovava para o projeto INTEIRO,
  # mascarando qualquer vazamento novo que aparecesse depois.
  #
  # As outras duas chamadas a `flatpak info --show-location` neste arquivo ficam
  # como estão: só se chega nelas DEPOIS desta porta, ou seja, num HOME onde o
  # ZapZap está instalado e o repositório já existe.
  if ! meow_flatpak_tem "$APP_ID"; then
    meow_pula "$APP_ID não está instalado — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- a cirurgia --------------------------------------------------------------
# Todo o trabalho de texto acontece aqui, em Python, porque é onde `compile()`
# mora — e `compile()` é a rede de segurança que separa "ícone feio" de
# "aplicativo que não abre". O shell só decide o que fazer com o veredito.
#
# Devolve na primeira linha um dos veredictos, e o resto é diagnóstico:
#   VESTIDO      o bloco já é exatamente o nosso
#   FABRICA      dá para vestir (achou o bloco, com {color} e {notify})
#   DESCONHECIDO a forma mudou; não se escreve nada
#   ERRO         não deu para ler/compilar
#
# Com `MEOW_ZZ_ESCREVER=1` ele também GRAVA (temporário no mesmo diretório +
# `mv -f`, que é o que quebra o hardlink do OSTree sem tocar no repo).
_cirurgia() {
  local alvo="$1" escrever="${2:-0}"
  MEOW_ZZ_TRACO="$TRACO" MEOW_ZZ_ESCREVER="$escrever" MEOW_ZZ_GUARDA="$GUARDA" \
  MEOW_ZZ_COMMIT="$(_commit_de || echo desconhecido)" \
  python3 - "$alvo" "$(_com_traco)" <<'PY'
import os, re, sys, tempfile, shutil

alvo   = sys.argv[1]
glifo  = sys.argv[2]           # o SVG do Arcticons, já com o stroke-width dela
escrever = os.environ.get('MEOW_ZZ_ESCREVER') == '1'
guarda   = os.environ.get('MEOW_ZZ_GUARDA', '')
commit   = os.environ.get('MEOW_ZZ_COMMIT', 'desconhecido')

try:
    atual = open(alvo, encoding='utf-8').read()
except OSError as e:
    print('ERRO'); print('não consegui ler %s: %s' % (alvo, e)); sys.exit(0)

# O glifo do Arcticons é um <svg …>…</svg> de uma linha. O que interessa é o
# MIOLO: os elementos de desenho. Tirar o invólucro é o que permite pô-lo dentro
# do <g transform="scale(…)"> sem aninhar um <svg> dentro de outro — que é legal
# em SVG 1.1 mas reinicia o sistema de coordenadas e ignoraria o scale.
miolo = re.sub(r'^.*?<svg[^>]*>', '', glifo, flags=re.S)
miolo = re.sub(r'</svg>\s*$', '', miolo, flags=re.S).strip()
# `currentColor` vira o campo que o app preenche: é ele que mantém vivos o
# `symbolic_light` (#ffffff) e o `symbolic_dark` (#241f31).
miolo = miolo.replace('currentColor', '{color}')

# 256/48. O contador de não-lidas continua sendo desenhado na grade de 256 pelo
# próprio app, FORA deste <g> — ver o cabeçalho.
NOSSO = (
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<svg viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg">\n'
    '  <!-- MeowSystem: glifo `whatsapp` do Arcticons (CC BY-SA 4.0), traco %s na\n'
    '       grade de 48, dentro de um scale(256/48). Reaplicado por\n'
    '       scripts/icones_tray_zapzap.sh apos todo flatpak update. -->\n'
    '  <g transform="scale(5.3333333)">\n'
    '    %s\n'
    '  </g>\n'
    '  {notify}\n'
    '</svg>\n'
) % (os.environ.get('MEOW_ZZ_TRACO', '4'), miolo)

# O bloco inteiro, do nome até as três aspas de fecho. `[^"]` no corpo não serve
# (o SVG tem aspas por toda parte); o critério é "até o próximo \"\"\"", que é o
# que o próprio Python usa para terminar a literal.
padrao = re.compile(r'(_SYMBOLIC\s*=\s*""")(.*?)(""")', re.S)
achados = padrao.findall(atual)
if len(achados) != 1:
    print('DESCONHECIDO')
    print('achei %d bloco(s) `_SYMBOLIC = \"\"\"…\"\"\"` em %s — esperava exatamente 1'
          % (len(achados), os.path.basename(alvo)))
    sys.exit(0)

corpo = achados[0][1]
if corpo == NOSSO:
    print('VESTIDO'); print('o bloco _SYMBOLIC ja e o glifo do Arcticons'); sys.exit(0)

faltando = [c for c in ('{color}', '{notify}') if c not in corpo]
if faltando:
    print('DESCONHECIDO')
    print('o bloco _SYMBOLIC nao tem %s — o ZapZap mudou o formato e eu nao vou '
          'adivinhar' % ' nem '.join(faltando))
    sys.exit(0)

novo = padrao.sub(lambda m: m.group(1) + NOSSO + m.group(3), atual, count=1)

# A REDE: um SyntaxError aqui e o ZapZap que nao abre mais.
try:
    compile(novo, alvo, 'exec')
except SyntaxError as e:
    print('ERRO'); print('o resultado nao compila (%s) — nada foi escrito' % e); sys.exit(0)

if not escrever:
    print('FABRICA'); print('o bloco _SYMBOLIC e o de fabrica e da para vestir'); sys.exit(0)

# O DE FABRICA VAI PARA O COFRE ANTES DA PRIMEIRA ESCRITA, e so na primeira:
# reescrever depois trocaria o original por uma copia do nosso proprio trabalho.
if guarda:
    try:
        os.makedirs(guarda, exist_ok=True)
        cofre = os.path.join(guarda, 'tray_icon.py.%s.fabrica' % commit)
        if not os.path.exists(cofre):
            shutil.copy2(alvo, cofre)
    except OSError as e:
        print('ERRO'); print('nao consegui guardar o de fabrica: %s' % e); sys.exit(0)

# Temporario NO MESMO DIRETORIO (mv entre sistemas de arquivos nao e atomico) e
# `mv -f` por cima: troca a ENTRADA de diretorio e quebra o hardlink do OSTree
# sem encostar no objeto do repositorio. Ver o cabecalho.
d = os.path.dirname(alvo)
try:
    fd, tmp = tempfile.mkstemp(prefix='.meow-zz-', dir=d)
    with os.fdopen(fd, 'w', encoding='utf-8') as f:
        f.write(novo)
    os.chmod(tmp, 0o644)
    os.replace(tmp, alvo)
except OSError as e:
    print('ERRO'); print('nao consegui escrever %s: %s' % (alvo, e)); sys.exit(0)

# O .pyc compilado do codigo que acabou de deixar de existir.
py = os.path.join(d, '__pycache__')
if os.path.isdir(py):
    for n in os.listdir(py):
        if n.startswith('tray_icon.') and n.endswith('.pyc'):
            try: os.remove(os.path.join(py, n))
            except OSError: pass

print('ESCRITO'); print('bloco _SYMBOLIC vestido e hardlink do OSTree quebrado')
PY
}

_veredito() {
  local alvo="$1" escrever="${2:-0}" saida
  saida="$(_cirurgia "$alvo" "$escrever")" || return 1
  printf '%s\n' "$saida"
}

# --- conferir ----------------------------------------------------------------
_conferir() {
  local alvo saida veredito motivo
  alvo="$(_arquivo_alvo)" || {
    meow_aviso "não achei o tray_icon.py dentro do deploy de $APP_ID"
    meow_info "  procurado em: \$(flatpak info --show-location $APP_ID)/files/lib/python3*/…"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  saida="$(_veredito "$alvo" 0)"
  veredito="$(printf '%s' "$saida" | head -n1)"
  motivo="$(printf '%s' "$saida" | tail -n +2)"

  case "$veredito" in
    VESTIDO)
      meow_ok "o ícone da bandeja do ZapZap segue vestido de Arcticons"
      return "$MEOW_OK" ;;
    FABRICA)
      meow_muda "o ícone da bandeja do ZapZap voltou ao de fábrica — um flatpak update o desfez"
      return "$MEOW_DIVERGENTE" ;;
    DESCONHECIDO)
      meow_aviso "o tray_icon.py do ZapZap mudou de forma: $motivo"
      meow_info "  compare com assets/icones/tray-terceiros/zapzap-tray_icon.py.original antes de repetir a manobra"
      return "$MEOW_SEM_DEPENDENCIA" ;;
    *)
      meow_erro "${motivo:-não consegui inspecionar $alvo}"
      return "$MEOW_ERRO" ;;
  esac
}

# --- aplicar -----------------------------------------------------------------
_aplicar() {
  local alvo saida veredito motivo
  alvo="$(_arquivo_alvo)" || {
    meow_aviso "não achei o tray_icon.py dentro do deploy de $APP_ID"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  saida="$(_veredito "$alvo" 1)"
  veredito="$(printf '%s' "$saida" | head -n1)"
  motivo="$(printf '%s' "$saida" | tail -n +2)"

  case "$veredito" in
    VESTIDO)
      meow_ok "o ícone da bandeja do ZapZap já estava vestido"
      return "$MEOW_OK" ;;
    ESCRITO)
      meow_muda "ícone da bandeja do ZapZap revestido de Arcticons"
      # A ESPERA É MAIOR QUE NO PAINEL, e vale repetir onde ela vai ler: o item
      # da bandeja nasce quando o APLICATIVO abre e publica o raster ali. Trocar
      # o desenho no disco não mexe num ZapZap já aberto.
      meow_info "  o desenho novo aparece quando o ZapZap for fechado e aberto de novo"
      # NÃO se chama `meow_manifesto_registrar` AQUI, e a razão é grave o
      # bastante para ficar escrita: o passo 4 do `lib/desinstalar.sh` anda pelo
      # manifesto e APAGA todo caminho que esteja dentro do `$HOME` e cujo sha256
      # ainda seja o nosso. Este arquivo está dentro do `$HOME`
      # (`~/.local/share/flatpak/app/…`), então registrá-lo faria o
      # `--uninstall` REMOVER o `tray_icon.py` do ZapZap — e um `from
      # zapzap.assets.icons.tray_icon import TrayIcon` sem arquivo é o app que
      # não abre mais. O manifesto é para arquivo NOSSO, que pode sumir; este é
      # arquivo de terceiro, que só pode VOLTAR AO DE FÁBRICA. Quem desfaz é o
      # `--desfazer`, com a cópia guardada, e é ele que o desinstalador chama.
      return "$MEOW_DIVERGENTE" ;;
    DESCONHECIDO)
      meow_aviso "o tray_icon.py do ZapZap mudou de forma: $motivo"
      meow_info "  nada foi escrito — é código Python, e vestir às cegas quebraria o app"
      meow_info "  compare com assets/icones/tray-terceiros/zapzap-tray_icon.py.original"
      return "$MEOW_SEM_DEPENDENCIA" ;;
    *)
      meow_erro "${motivo:-não consegui vestir $alvo}"
      return "$MEOW_ERRO" ;;
  esac
}

# --- desfazer ----------------------------------------------------------------
# Põe de volta o de fábrica GUARDADO deste deploy. Sem cofre para este commit não
# há o que fazer, e dizer isso é melhor que copiar a fotografia de 10/08 por cima
# de uma versão que ninguém conferiu.
_desfazer() {
  local alvo commit cofre
  alvo="$(_arquivo_alvo)" || { meow_pula "$APP_ID não está instalado — nada a desfazer"; return "$MEOW_OK"; }
  commit="$(_commit_de || echo desconhecido)"
  cofre="$GUARDA/tray_icon.py.$commit.fabrica"

  if [ ! -f "$cofre" ]; then
    meow_pula "sem cópia de fábrica guardada para este deploy — nada a desfazer"
    meow_info "  se quiser o de fábrica mesmo assim: flatpak update $APP_ID"
    return "$MEOW_OK"
  fi
  if cmp -s "$cofre" "$alvo"; then
    meow_ok "o tray_icon.py do ZapZap já é o de fábrica"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "devolveria o tray_icon.py de fábrica do ZapZap"
    return "$MEOW_DIVERGENTE"
  fi
  local tmp; tmp="$(mktemp -p "$(dirname "$alvo")" .meow-zz-XXXXXX)" || {
    meow_erro "não consegui criar temporário ao lado de $alvo"; return "$MEOW_ERRO"; }
  cat "$cofre" > "$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$alvo" || {
    rm -f "$tmp"; meow_erro "não consegui devolver o de fábrica"; return "$MEOW_ERRO"; }
  rm -f "$(dirname "$alvo")"/__pycache__/tray_icon.*.pyc 2>/dev/null
  meow_muda "tray_icon.py do ZapZap devolvido ao de fábrica"
  return "$MEOW_DIVERGENTE"
}

# --- porta -------------------------------------------------------------------
_pronto; rc=$?
[ "$rc" = "$MEOW_OK" ] || exit "$rc"

case "$MODO" in
  conferir) _conferir ;;
  aplicar)  _aplicar  ;;
  desfazer) _desfazer ;;
esac
exit $?

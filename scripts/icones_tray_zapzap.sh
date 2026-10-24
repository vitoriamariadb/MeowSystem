#!/usr/bin/env bash
# icones_tray_zapzap.sh — o ícone da BANDEJA do ZapZap, e o motivo pelo qual ele
#                         voltava ao de fábrica sem ninguém pedir.
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
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

APP_ID="${MEOW_TRAY_ZAPZAP_APP:-com.rtosta.zapzap}"
# P96: o glifo mora numa das três pastas planas do pack-base (uma cópia só, onde caiu)
GLIFO="${MEOW_TRAY_ZAPZAP_GLIFO:-}"
if [ -z "$GLIFO" ]; then
  for _p in sistema apps biblioteca; do
    GLIFO="$RAIZ/packs/meowsystem/icones/$_p/whatsapp.svg"; [ -f "$GLIFO" ] && break
  done
fi
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
# O caminho tem a VERSÃO DO PYTHON no meio (`lib/python3.13/`), e ela muda
# quando o runtime do flatpak muda de base.
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
# Sai UMA linha de `<path …>` por elemento do glifo, já com o traço dela.
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
  # `flatpak info` cria um repositório ostree INTEIRO em ~/.local/share/flatpak
  # só por ter sido perguntado.
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
# "aplicativo que não abre".
#
# Devolve na primeira linha um dos veredictos, e o resto é diagnóstico:
#   VESTIDO      o bloco já é exatamente o nosso
#   FABRICA      dá para vestir (achou o bloco, com {color} e {notify})
#   DESCONHECIDO a forma mudou; não se escreve nada
#   ERRO         não deu para ler/compilar
_cirurgia() {
  local alvo="$1" escrever="${2:-0}"
  MEOW_ZZ_TRACO="$TRACO" MEOW_ZZ_ESCREVER="$escrever" MEOW_ZZ_GUARDA="$GUARDA" \
  MEOW_ZZ_COMMIT="$(_commit_de || echo desconhecido)" \
  python3 -I - "$alvo" "$(_com_traco)" <<'PY'
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
      meow_info "  compare com assets/apps/tray-terceiros/zapzap-tray_icon.py.original antes de repetir a manobra"
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
      # manifesto e APAGA todo caminho que esteja dentro do `$HOME` e cujo
      # sha256 ainda seja o nosso.
      return "$MEOW_DIVERGENTE" ;;
    DESCONHECIDO)
      meow_aviso "o tray_icon.py do ZapZap mudou de forma: $motivo"
      meow_info "  nada foi escrito — é código Python, e vestir às cegas quebraria o app"
      meow_info "  compare com assets/apps/tray-terceiros/zapzap-tray_icon.py.original"
      return "$MEOW_SEM_DEPENDENCIA" ;;
    *)
      meow_erro "${motivo:-não consegui vestir $alvo}"
      return "$MEOW_ERRO" ;;
  esac
}

# --- desfazer ----------------------------------------------------------------
# Põe de volta o de fábrica GUARDADO deste deploy. Sem cofre para este commit
# não há o que fazer, e dizer isso é melhor que copiar a fotografia por cima de
# uma versão que ninguém conferiu.
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

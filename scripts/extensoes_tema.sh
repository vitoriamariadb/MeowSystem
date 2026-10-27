#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

PINOS="${EXTENSOES_PINOS:-$RAIZ/assets/extensoes}"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
RAIZ_TEMAS="$CONFIG/meowsystem/extensoes"

CONFERIR=0; REVERTER=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  --reverter) REVERTER=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--reverter]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && [ "$REVERTER" = 0 ] && CONFERIR=1

_flavor="$(meow_flavor)"
_paleta="$(meow_paleta)"
_acento="${ACCENT:-mauve}"

_cor() {
  python3 -I -c '
import json, sys
try:
    f = json.load(open(sys.argv[1]))["flavors"][sys.argv[2]]
except Exception:
    sys.exit(1)
for nome in sys.argv[3:]:
    v = f.get(nome)
    if isinstance(v, str) and v.startswith("#"):
        print(v.lower())
        sys.exit(0)
sys.exit(1)
' "$_paleta" "$_flavor" "$@" 2>/dev/null
}

_tema_do() {
  local tema="$1" texto base s0 s1 acento verde pessego
  texto="$(_cor text)" && base="$(_cor base)" && s0="$(_cor surface0)" && s1="$(_cor surface1)" || return 1
  acento="$(_cor "$_acento" mauve)" || return 1
  case "$tema" in
    io.github.meowsystem.Bandeja)
      printf 'tinta = %s\nfundo = %sf0\nborda = %s\ntexto = %s\ndestaque = %s\nacento = %s\n' \
        "$texto" "$base" "$s1" "$texto" "$s0" "$acento" ;;
    io.github.meowsystem.AjustesRapidos)
      verde="$(_cor green)" && pessego="$(_cor peach)" || return 1
      printf 'acento = %s\ndestaque = %s\nfundo = %s\nborda = %s\ntexto = %s\nbloco = %s\ntinta = %s\ncamera = %s\nmicrofone = %s\n' \
        "$acento" "$base" "$base" "$s1" "$texto" "$s0" "$texto" "$verde" "$pessego" ;;
    *) return 2 ;;
  esac
}

_temas_da_casa() {
  local f
  for f in "$PINOS"/*.pino; do
    [ -f "$f" ] || continue
    sed -n 's/^TEMA="\(.*\)"/\1/p' "$f" | head -1
  done
}

_instalado() {
  local tema="$1" f bin
  for f in "$PINOS"/*.pino; do
    grep -qx "TEMA=\"$tema\"" "$f" 2>/dev/null || continue
    bin="$(sed -n 's/^BIN="\(.*\)"/\1/p' "$f" | head -1)"
    [ -x "$HOME/.local/bin/$bin" ] && return 0
  done
  return 1
}

main() {
  local tema destino texto rc geral="$MEOW_OK" visto=0
  while IFS= read -r tema; do
    [ -n "$tema" ] || continue
    destino="$RAIZ_TEMAS/$tema/tema.conf"
    if [ "$REVERTER" = 1 ]; then
      if [ -e "$destino" ]; then
        meow_seco && { meow_muda "removeria $destino"; geral="$MEOW_DIVERGENTE"; continue; }
        rm -f "$destino"; rmdir "$RAIZ_TEMAS/$tema" 2>/dev/null
        meow_ok "o tema de $tema saiu"; geral="$MEOW_DIVERGENTE"
      fi
      continue
    fi
    _instalado "$tema" || continue
    visto=1
    texto="$(_tema_do "$tema")"; rc=$?
    if [ "$rc" != 0 ]; then
      meow_aviso "não montei o tema de $tema: a paleta de $_flavor não tem as cores que ele pede"
      geral="$MEOW_SEM_DEPENDENCIA"; continue
    fi
    if [ "$CONFERIR" = 1 ]; then
      if [ -f "$destino" ] && [ "$texto" = "$(cat "$destino")" ]; then
        meow_ok "o tema de $tema é o do pack ($_flavor)"
      else
        meow_muda "o tema de $tema não é o do pack em uso ($destino)"
        geral="$MEOW_DIVERGENTE"
      fi
      continue
    fi
    meow_escrever "$destino" "$texto" 644; rc=$?
    case $rc in
      0) meow_ok "o tema de $tema já era o do pack ($_flavor)" ;;
      1) meow_ok "o tema de $tema veio do pack ($_flavor); o applet relê ao abrir o popup"; geral="$MEOW_DIVERGENTE" ;;
      *) meow_erro "não consegui escrever $destino"; return "$MEOW_ERRO" ;;
    esac
  done < <(_temas_da_casa)
  if [ "$visto" = 0 ] && [ "$REVERTER" = 0 ]; then
    meow_pula "nenhuma extensão com tema está instalada"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$geral"
}

main

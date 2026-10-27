#!/usr/bin/env bash
set -uo pipefail

if [ -z "${MEOW_RAIZ:-}" ]; then
  MEOW_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
# shellcheck source=../lib/comum.sh
declare -F meow_ok >/dev/null 2>&1 || . "$MEOW_RAIZ/lib/comum.sh"

AP_GUARDA="${AP_GUARDA:-$MEOW_ESTADO/painel-libcosmic.tsv}"
AP_FALHAS="${AP_FALHAS:-$MEOW_ESTADO/applet-pino-falhas.tsv}"
AP_BASE="${AP_BASE:-$MEOW_ESTADO/applet-pino-base.tsv}"
AP_LOCK_PAINEL="${AP_LOCK_PAINEL:-}"
AP_SO_LER="${AP_SO_LER:-0}"
_ap_pode_gravar() { ! meow_seco && [ "$AP_SO_LER" != "1" ]; }

ap_rev_do_lock() {
  awk '/^name = "libcosmic"$/{f=1} f && /^source = /{sub(/.*#/,""); sub(/"$/,""); print; exit}' "$1" 2>/dev/null
}

ap_rev_painel() {
  local v rev
  if [ -n "$AP_LOCK_PAINEL" ]; then
    rev="$(ap_rev_do_lock "$AP_LOCK_PAINEL")"; [ -n "$rev" ] && { printf '%s' "$rev"; return 0; }
    return 1
  fi
  v="$(dpkg-query -W -f='${Version}' cosmic-panel 2>/dev/null)" || return 1
  [ -n "$v" ] || return 1
  rev="$(awk -F'\t' -v v="$v" '$1==v {print $2; exit}' "$AP_GUARDA" 2>/dev/null)"
  if [ -z "$rev" ]; then
    rev="$(meow_libcosmic_de cosmic-panel "$v")" || return 1
    _ap_pode_gravar && { mkdir -p "${AP_GUARDA%/*}" && printf '%s\t%s\n' "$v" "$rev" >> "$AP_GUARDA"; }
  fi
  printf '%s' "$rev"
}

ap_ja_falhou() { awk -F'\t' -v n="$1" -v r="$2" '$1==n && $2==r {achou=1} END {exit !achou}' "$AP_FALHAS" 2>/dev/null; }

_ap_base() { awk -F'\t' -v n="$1" '$1==n {b=$2"\t"$3} END {if (b!="") print b}' "$AP_BASE" 2>/dev/null; }

ap_registrar() {
  local tmp
  _ap_pode_gravar || return 0
  mkdir -p "${AP_BASE%/*}" || return 1
  tmp="$(mktemp -p "${AP_BASE%/*}" .base.XXXXXX)" || return 1
  { awk -F'\t' -v n="$1" '$1!=n' "$AP_BASE" 2>/dev/null; printf '%s\t%s\t%s\n' "$1" "$2" "$3"; } > "$tmp" && mv -f "$tmp" "$AP_BASE"
}

ap_alvo() {
  local painel base b_painel b_alvo
  painel="$(ap_rev_painel)" || { printf '%s' "$2"; return 0; }
  base="$(_ap_base "$1")"
  if [ -z "$base" ]; then
    ap_registrar "$1" "$painel" "$2"
    printf '%s' "$2"; return 0
  fi
  b_painel="${base%%$'\t'*}"; b_alvo="${base#*$'\t'}"
  if [ "$painel" = "$b_painel" ]; then
    printf '%s' "$b_alvo"
  elif [ "$painel" = "$2" ] || ap_ja_falhou "$1" "$painel"; then
    printf '%s' "$2"
  else
    printf '%s' "$painel"
  fi
}

ap_compilou() {
  local painel
  painel="$(ap_rev_painel)" || return 0
  ap_registrar "$1" "$painel" "$2"
}

ap_falhou() {
  _ap_pode_gravar || return 0
  ap_ja_falhou "$1" "$2" && return 0
  mkdir -p "${AP_FALHAS%/*}" && printf '%s\t%s\t%s\n' "$1" "$2" "$(date -Is)" >> "$AP_FALHAS"
}

_ap_conferir() {
  local painel nome pino alvo
  painel="$(ap_rev_painel)" || painel=""
  meow_info "libcosmic do cosmic-panel instalado: ${painel:-<não medido>}"
  while IFS='|' read -r nome pino; do
    [ -n "$pino" ] || continue
    alvo="$(ap_alvo "$nome" "$pino")"
    if [ "$alvo" = "$painel" ] && [ "$alvo" = "$pino" ]; then
      meow_ok "$nome: pinado no libcosmic do painel (${pino:0:7})"
    elif [ "$alvo" = "$painel" ]; then
      meow_info "$nome: o pino é ${pino:0:7} e o painel ${painel:0:7} — o próximo build segue o painel"
    else
      meow_aviso "$nome: segue o pino ${pino:0:7}$( [ -n "$painel" ] && ap_ja_falhou "$nome" "$painel" && printf ' (não compilou no %s do painel)' "${painel:0:7}")"
    fi
  done <<EOF
$(for f in "${EXTENSOES_PINOS:-$MEOW_RAIZ/assets/extensoes}"/*.pino; do
    [ -f "$f" ] && printf '%s|%s\n' "$(basename "$f" .pino)" "$(sed -n 's/^LIBCOSMIC="\(.*\)"/\1/p' "$f")"
  done)
EOF
  return "$MEOW_OK"
}

[ "${BASH_SOURCE[0]}" = "$0" ] || return 0

case "${1:-conferir}" in
  painel)   ap_rev_painel && printf '\n' ;;
  alvo)     [ $# -eq 3 ] || { meow_erro "uso: applet_pino.sh alvo <nome> <rev-do-pino>"; exit "$MEOW_ERRO"; }
            ap_alvo "$2" "$3"; printf '\n' ;;
  falhou)   [ $# -eq 3 ] || { meow_erro "uso: applet_pino.sh falhou <nome> <rev>"; exit "$MEOW_ERRO"; }
            ap_falhou "$2" "$3" ;;
  conferir) AP_SO_LER=1; _ap_conferir ;;
  *) meow_erro "uso: applet_pino.sh {painel|alvo <nome> <rev>|falhou <nome> <rev>|conferir}"; exit "$MEOW_ERRO" ;;
esac

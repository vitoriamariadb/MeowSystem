#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

SISTEMA="${MEOW_APLICATIVOS_SISTEMA:-/usr/share/applications}"
DADOS="${XDG_DATA_HOME:-$HOME/.local/share}"
APPS="$DADOS/applications"
MARCA="X-MeowSystem=ocultar"
MARCA_LUGAR="X-MeowSystem=ocultar-no-lugar"
CHAVES=(Type Name Exec TryExec Icon StartupWMClass MimeType)

MODO="aplicar"
case "${1:-}" in
  --conferir) MODO="conferir" ;;
  --reverter) MODO="reverter" ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--reverter]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && [ "$MODO" = "aplicar" ] && MODO="conferir"

ABAIXO=()
_abaixo() {
  local d dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" ja
  for d in "$DADOS/flatpak/exports/share" "${MEOW_APLICATIVOS_FLATPAK:-/var/lib/flatpak/exports/share}" ${dirs//:/ }; do
    d="$d/applications"
    [ "$d" = "$APPS" ] && continue
    for ja in ${ABAIXO[@]+"${ABAIXO[@]}"}; do [ "$ja" = "$d" ] && continue 2; done
    ABAIXO+=("$d")
  done
}
_abaixo

_original() {
  local d
  for d in "${ABAIXO[@]}"; do
    [ -f "$d/$1.desktop" ] && { printf '%s' "$d/$1.desktop"; return 0; }
  done
  return 1
}

_no_grupo() {
  L="$2" awk 'BEGIN { l = ENVIRON["L"] } /^\[/ { g = ($0 == "[Desktop Entry]") } g && $0 == l { achou = 1 } END { exit !achou }' "$1"
}

_sombra() {
  local c
  printf '[Desktop Entry]\n'
  for c in "${CHAVES[@]}"; do
    C="$c" awk 'BEGIN { c = ENVIRON["C"] "=" } /^\[/ { g = ($0 == "[Desktop Entry]") }
      g && index($0, c) == 1 { print; exit }' "$1"
  done
  printf 'NoDisplay=true\n%s\nX-MeowSystem-Origem=%s' "$MARCA" "$1"
}

_marcar_no_lugar() {
  local tmp
  meow_destino_permitido "$1" || return "$MEOW_ERRO"
  meow_guardar_antes "$1"
  tmp="$(mktemp "$1.meow.XXXXXX")" || return "$MEOW_ERRO"
  M="$MARCA_LUGAR" awk 'BEGIN { m = ENVIRON["M"] }
    $0 == "[Desktop Entry]" && !feito { print; print "NoDisplay=true"; print m; feito = 1; next } { print }' "$1" > "$tmp"
  chmod --reference="$1" "$tmp" 2>/dev/null
  mv -f "$tmp" "$1" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
}

_desmarcar() {
  local tmp
  meow_guardar_antes "$1"
  tmp="$(mktemp "$1.meow.XXXXXX")" || return "$MEOW_ERRO"
  M="$MARCA_LUGAR" awk 'BEGIN { m = ENVIRON["M"] }
    { l[NR] = $0 } END { for (i = 1; i <= NR; i++) { if (l[i] == "NoDisplay=true" && l[i+1] == m) { i++; continue } print l[i] } }' "$1" > "$tmp"
  chmod --reference="$1" "$tmp" 2>/dev/null
  mv -f "$tmp" "$1" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
}

declare -A QUER=()
if [ "$MODO" != "reverter" ] && [ "${LANCADOR_SISTEMA:-nao}" = "sim" ]; then
  while IFS= read -r id; do
    [ -n "$id" ] && QUER["$id"]=1
  done < <("$RAIZ/scripts/ocultar_apps.sh" --lista 2>/dev/null)
fi

mudou=0; sombras=0; marcados=0; ausentes=0

PENDENTES=()
_vai() {
  mudou=1
  { [ "$MODO" = "conferir" ] || meow_seco; } && { PENDENTES+=("$1"); return 1; }
  return 0
}

for id in "${!QUER[@]}"; do
  casa="$APPS/$id.desktop"
  [ -f "$SISTEMA/$id.desktop" ] && continue
  orig="$(_original "$id")" || orig=""
  if [ -f "$casa" ] && grep -qxF "$MARCA" "$casa"; then
    if [ -z "$orig" ]; then
      _vai "tiraria a sombra de $id (o aplicativo saiu)" && meow_guardar_antes "$casa" && rm -f "$casa"
      continue
    fi
    sombras=$((sombras + 1))
    [ "$(_sombra "$orig")" = "$(cat "$casa")" ] && continue
    _vai "refaria a sombra de $id (o original mudou)" && meow_escrever "$casa" "$(_sombra "$orig")" 644 >/dev/null
  elif [ -f "$casa" ]; then
    marcados=$((marcados + 1))
    _no_grupo "$casa" "NoDisplay=true" && continue
    _vai "esconderia $id (marca no próprio .desktop do home)" && _marcar_no_lugar "$casa"
  elif [ -n "$orig" ]; then
    sombras=$((sombras + 1))
    _vai "esconderia $id (sombra de $orig)" && meow_escrever "$casa" "$(_sombra "$orig")" 644 >/dev/null
  else
    ausentes=$((ausentes + 1))
  fi
done

devolvidos=0
if [ -d "$APPS" ]; then
  for arq in "$APPS"/*.desktop; do
    [ -f "$arq" ] || continue
    id="$(basename "$arq" .desktop)"
    [ -n "${QUER[$id]:-}" ] && [ ! -f "$SISTEMA/$id.desktop" ] && continue
    if grep -qxF "$MARCA" "$arq"; then
      devolvidos=$((devolvidos + 1))
      _vai "devolveria $id ao lançador" && meow_guardar_antes "$arq" && rm -f "$arq"
    elif grep -qxF "$MARCA_LUGAR" "$arq"; then
      devolvidos=$((devolvidos + 1))
      _vai "devolveria $id ao lançador" && _desmarcar "$arq"
    fi
  done
fi

if [ "$mudou" = 0 ]; then
  if [ "$MODO" != "reverter" ] && [ "${LANCADOR_SISTEMA:-nao}" != "sim" ]; then
    meow_pula 'LANCADOR_SISTEMA não é "sim" — o lançador fica como os aplicativos o entregam'
    exit "$MEOW_SEM_DEPENDENCIA"
  fi
  [ "$MODO" = "reverter" ] && { meow_ok "nenhuma sombra nem marca do ocultar no home"; exit "$MEOW_OK"; }
  meow_ok "fora de /usr/share, já escondidos: $sombras por sombra, $marcados no próprio home ($ausentes não instalados)"
  exit "$MEOW_OK"
fi
if [ "$MODO" = "conferir" ] || meow_seco; then
  meow_muda "${#PENDENTES[@]} aplicativo(s) fora de /usr/share a esconder ou devolver ao lançador"
  for l in "${PENDENTES[@]}"; do meow_info "  $l"; done
  exit "$MEOW_DIVERGENTE"
fi
meow_guardar_antes "$APPS/mimeinfo.cache"
meow_desktop_banco "$APPS"
meow_ok "lançador do home conforme ($devolvidos devolvido(s))"
exit "$MEOW_DIVERGENTE"

#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

SISTEMA="${MEOW_APLICATIVOS_SISTEMA:-/usr/share/applications}"

OCULTAR=(
  vim
  debian-xterm
  debian-uxterm
  qt5ct
  qt6ct
  display-im6.q16
  info
  im-config
  ibus-setup
  org.freedesktop.IBus.Setup
  org.gnome.font-viewer
  gnome-language-selector
  system-config-printer

  org.gnome.eog
  org.gnome.Evince
  org.gnome.baobab
  org.gnome.PowerStats
  org.gnome.seahorse.Application
  org.gnome.DiskUtility
  simple-scan
  yelp
  gucharmap

  nm-connection-editor
  repoman
  com.system76.Popsicle
  gparted
  nvidia-settings

  syncthing-start
  syncthing-ui
)

LANCADOR_OCULTAR="${LANCADOR_OCULTAR:-}"
LANCADOR_OCULTAR_FONTE="fábrica"
_da_conf=()
_fora=()
if [ -n "$LANCADOR_OCULTAR" ]; then
  while IFS= read -r _item; do
    _item="${_item#"${_item%%[![:space:]]*}"}"
    _item="${_item%"${_item##*[![:space:]]}"}"
    case "$_item" in
      -?*) _fora+=("${_item#-}") ;;
      ?*)  _da_conf+=("$_item") ;;
    esac
  done < <(printf '%s\n' "$LANCADOR_OCULTAR" | tr ',' '\n')
  if [ "${#_da_conf[@]}" -gt 0 ]; then
    OCULTAR=("${_da_conf[@]}")
    LANCADOR_OCULTAR_FONTE="meow.conf"
  fi
fi

_do_pack="$(meow_pack_dir)"
[ -n "$_do_pack" ] || _do_pack="$(meow_pack_padrao_dir 2>/dev/null || true)"
declare -A _ja=()
for _item in "${OCULTAR[@]}"; do _ja["$_item"]=1; done
while IFS= read -r _item; do
  [ -n "$_item" ] && [ -z "${_ja[$_item]:-}" ] || continue
  OCULTAR+=("$_item"); _ja["$_item"]=1
done < <(python3 "$RAIZ/scripts/pack.py" ocultar "$_do_pack" 2>/dev/null)
if [ "${#_fora[@]}" -gt 0 ]; then
  _resto=()
  for _item in "${OCULTAR[@]}"; do
    printf '%s\n' "${_fora[@]}" | grep -qxF -- "$_item" || _resto+=("$_item")
  done
  OCULTAR=(${_resto[@]+"${_resto[@]}"})
fi
unset _do_pack _ja _resto

if [ "${1:-}" = "--lista" ]; then
  printf '%s\n' ${OCULTAR[@]+"${OCULTAR[@]}"}
  exit "$MEOW_OK"
fi

MARCADOS="$MEOW_ESTADO/lancador-ocultos.txt"
_tem_marca() {
  awk 'ant == "[Desktop Entry]" && $0 == "NoDisplay=true" { achou = 1 } { ant = $0 } END { exit !achou }' "$1"
}
declare -A _meus=()
if [ -f "$MARCADOS" ]; then
  while IFS= read -r _item; do [ -n "$_item" ] && _meus["$_item"]=1; done < "$MARCADOS"
else
  for _item in "${OCULTAR[@]}"; do
    [ -f "$SISTEMA/$_item.desktop" ] && _tem_marca "$SISTEMA/$_item.desktop" && _meus["$_item"]=1
  done
fi

mudou=0
ausentes=0
sem_root=0

for app in "${OCULTAR[@]}"; do
  arq="$SISTEMA/$app.desktop"
  [ -f "$arq" ] || { ausentes=$((ausentes+1)); continue; }

  if grep -qE '^NoDisplay=true' "$arq" 2>/dev/null; then
    continue
  fi

  if meow_seco; then
    meow_muda "ocultaria $app"
    mudou=1
    continue
  fi

  if ! meow_desktop_pode "$arq"; then
    sem_root=$((sem_root+1))
    continue
  fi

  novo="$(awk '
    /^\[Desktop Entry\]/ && !feito { print; print "NoDisplay=true"; feito=1; next }
    { print }
  ' "$arq")"

  tmp="$(mktemp)"
  printf '%s\n' "$novo" > "$tmp"
  if ! meow_backup_sistema "$arq"; then
    meow_aviso "não consegui guardar cópia de $arq — não vou marcá-lo"
    rm -f "$tmp"
    continue
  fi
  if meow_desktop_escrever "$arq" "$tmp"; then
    mudou=1; _meus["$app"]=1
  else
    sem_root=$((sem_root+1))
  fi
  rm -f "$tmp"
done

declare -A _na_lista=()
for _item in "${OCULTAR[@]}"; do _na_lista["$_item"]=1; done
_devolver=(${_fora[@]+"${_fora[@]}"})
for _item in "${!_meus[@]}"; do
  [ -n "${_na_lista[$_item]:-}" ] && continue
  printf '%s\n' ${_fora[@]+"${_fora[@]}"} | grep -qxF -- "$_item" || _devolver+=("$_item")
done
devolvidos=0
for app in ${_devolver[@]+"${_devolver[@]}"}; do
  arq="$SISTEMA/$app.desktop"
  [ -f "$arq" ] || { [ -z "${_na_lista[$app]:-}" ] && unset '_meus[$app]'; continue; }
  _tem_marca "$arq" || { [ -z "${_na_lista[$app]:-}" ] && unset '_meus[$app]'; continue; }
  if meow_seco; then
    meow_muda "devolveria $app ao lançador"
    mudou=1
    continue
  fi
  if ! meow_desktop_pode "$arq"; then
    sem_root=$((sem_root+1))
    continue
  fi
  novo="$(awk 'ant == "[Desktop Entry]" && $0 == "NoDisplay=true" && !feito { feito = 1; ant = $0; next }
               { print; ant = $0 }' "$arq")"
  if ! meow_backup_sistema "$arq"; then
    meow_aviso "não consegui guardar cópia de $arq — não vou devolvê-lo"
    continue
  fi
  tmp="$(mktemp)"
  printf '%s\n' "$novo" > "$tmp"
  if meow_desktop_escrever "$arq" "$tmp"; then
    mudou=1; devolvidos=$((devolvidos+1)); unset '_meus[$app]'
  else
    sem_root=$((sem_root+1))
  fi
  rm -f "$tmp"
done
[ "$devolvidos" -gt 0 ] && meow_muda "$devolvidos aplicativo(s) de volta ao lançador"

if ! meow_seco; then
  mkdir -p "$MEOW_ESTADO" 2>/dev/null
  meow_escrever "$MARCADOS" "$(printf '%s\n' "${!_meus[@]}" | LC_ALL=C sort | sed '/^$/d')" 644 >/dev/null
fi

if [ "$sem_root" -gt 0 ]; then
  meow_aviso "$sem_root aplicativo(s) precisam de sudo para ocultar"
fi

if [ "$mudou" = "0" ]; then
  meow_ok "aplicativos de sistema já ocultos (${#OCULTAR[@]} na lista de $LANCADOR_OCULTAR_FONTE, $ausentes não instalados)"
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"

meow_desktop_banco "$SISTEMA"
meow_ok "aplicativos de sistema ocultos do lançador"
meow_info "vale no próximo início do lançador"
exit "$MEOW_DIVERGENTE"

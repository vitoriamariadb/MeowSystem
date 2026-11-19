#!/usr/bin/env bash
# MEOW-DOCK-SHIM-1

fabrica="${MEOW_SHIM_FABRICA:-/usr/bin/cosmic-app-list}"
casa="${MEOW_SHIM_CASA:-$HOME/.local/libexec/meow/dock}"
janela="${MEOW_SHIM_JANELA:-30}"
limite=2

ver="$(dpkg-query -W -f='${Version}' cosmic-applets 2>/dev/null)"
dir="$casa/$ver"
build="$dir/cosmic-app-list"
viva=""
for pid in $(pgrep -u "$(id -u)" -x cosmic-app-list 2>/dev/null); do
  exe="$(readlink "/proc/$pid/exe" 2>/dev/null)"
  case "$exe" in
    "$fabrica"|"$fabrica (deleted)") viva="$fabrica"; break ;;
    "$casa"/*/cosmic-app-list) [ -x "$exe" ] && { viva="$exe"; break; } ;;
  esac
done
case "$viva" in
  "") ;;
  "$fabrica") build="" ;;
  *) build="$viva"; dir="${viva%/*}" ;;
esac

usar_build=0
if [ -n "$ver" ] && [ -x "$build" ] && [ ! -e "$dir/ruim" ] && [ -s "$dir/marcadores" ]; then
  usar_build=1
  while read -r marca; do
    [ -z "$marca" ] || grep -a -q -- "$marca" "$build" 2>/dev/null || usar_build=0
  done < "$dir/marcadores"
  if [ "$usar_build" = "1" ] && ldd "$build" 2>/dev/null | grep -q 'not found'; then
    usar_build=0
  fi
fi

if [ "${MEOW_SHIM_SO_DIZER:-0}" = "1" ]; then
  if [ "$usar_build" = "1" ]; then printf '%s\n' "$build"; else printf '%s\n' "$fabrica"; fi
  exit 0
fi

if [ "$usar_build" = "1" ]; then
  n=0
  while read -r pid; do
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    kill -0 "$pid" 2>/dev/null || n=$((n + 1))
  done < <(cat "$dir/quedas" 2>/dev/null)
  if [ "$n" -ge "$limite" ]; then
    date -Is > "$dir/ruim" 2>/dev/null
    exec "$fabrica" "$@"
  fi
  { printf '%s\n' "$$" >> "$dir/quedas"; } 2>/dev/null || exec "$fabrica" "$@"
  grep -qx -- "$$" "$dir/quedas" 2>/dev/null || exec "$fabrica" "$@"
  (
    for fd in /proc/"$BASHPID"/fd/*; do
      fd="${fd##*/}"
      [ "$fd" -gt 2 ] 2>/dev/null && eval "exec $fd>&-" 2>/dev/null
    done
    exec /bin/sh -c 'sleep "$1"; kill -0 "$2" 2>/dev/null && rm -f "$3"' \
      meow-shim-vigia "$janela" "$$" "$dir/quedas" </dev/null >/dev/null 2>&1
  ) &
  exec "$build" "$@"
fi

exec "$fabrica" "$@"

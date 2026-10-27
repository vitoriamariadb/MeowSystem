#!/usr/bin/env bash
# MEOW-COSMIC-COMP-SHIM-1

fabrica="${MEOW_SHIM_FABRICA:-/usr/bin/cosmic-comp}"
casa="${MEOW_SHIM_CASA:-$HOME/.local/libexec/meow/cosmic-comp}"
janela="${MEOW_SHIM_JANELA:-30}"
limite=2

ver="$(dpkg-query -W -f='${Version}' cosmic-comp 2>/dev/null)"
dir="$casa/$ver"
build="$dir/cosmic-comp"

usar_build=0
if [ -n "$ver" ] && [ -x "$build" ] && [ ! -e "$dir/ruim" ] \
   && grep -q '^req [^ ]* [^ ]* presente$' "$dir/estado" 2>/dev/null; then
  usar_build=1
fi

if [ "${MEOW_SHIM_SO_DIZER:-0}" = "1" ]; then
  if [ "$usar_build" = "1" ]; then printf '%s\n' "$build"; else printf '%s\n' "$fabrica"; fi
  exit 0
fi

if [ "$usar_build" = "1" ]; then
  n="$(cat "$dir/quedas" 2>/dev/null)"
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -ge "$limite" ]; then
    date -Is > "$dir/ruim" 2>/dev/null
    exec "$fabrica" "$@"
  fi
  printf '%s\n' "$((n + 1))" > "$dir/quedas" 2>/dev/null
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

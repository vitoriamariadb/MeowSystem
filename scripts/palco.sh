#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PALCO_DIR="${PALCO_DIR:-/tmp/meow-palco-$(id -u)}"
PALCO_TELA="${PALCO_TELA:-1280x800}"
PALCO_ORIGEM="${PALCO_ORIGEM:-$HOME}"
PALCO_XWAYLAND="${PALCO_XWAYLAND:-1}"
PALCO_DCONF="${DCONF_PROFILE:-/usr/share/dconf/profile/cosmic}"
[ -r "$PALCO_DCONF" ] || PALCO_DCONF=""
COPIAS=(.config/gtk-3.0 .config/gtk-4.0 .config/cosmic .config/dconf .config/meow/meow.conf .icons .themes)

case "$PALCO_DIR" in
  */..|*/../*) printf 'palco: PALCO_DIR sem «..» (veio %s)\n' "$PALCO_DIR" >&2; exit 2 ;;
  /tmp/?*) ;;
  *) printf 'palco: PALCO_DIR tem de morar em /tmp (veio %s)\n' "$PALCO_DIR" >&2; exit 2 ;;
esac

RT="$PALCO_DIR/rt"
CASA="$PALCO_DIR/casa"
GRUPOS="$PALCO_DIR/grupos"
SEM_SISTEMA="unix:path=$RT/sem-sistema"

_erro() { printf 'palco: %s\n' "$*" >&2; exit 1; }

_membros() {
  ps -eo pid=,pgid= | awk -v g="$1" '$2 == g { print $1 }'
}

_marcados() {
  local p
  for p in /proc/[0-9]*; do
    [ -O "$p" ] || continue
    tr '\0' '\n' 2>/dev/null < "$p/environ" | grep -qxF "MEOW_PALCO=$PALCO_DIR" && printf '%s\n' "${p#/proc/}"
  done
}

_nossos() {
  local g m marcados
  marcados="$(_marcados)"
  {
    printf '%s\n' "$marcados"
    [ -s "$GRUPOS" ] && while read -r g; do
      [ -n "$g" ] || continue
      m="$(_membros "$g")"
      [ -n "$m" ] && grep -qxF -f <(printf '%s\n' "$m") <<< "$marcados" && printf '%s\n' "$m"
    done < "$GRUPOS"
  } | grep -x '[0-9][0-9]*' | grep -vx "$$" | sort -un
}

_vivo() {
  local w
  [ -s "$GRUPOS" ] && [ -s "$PALCO_DIR/wayland" ] && [ -s "$PALCO_DIR/barramento" ] || return 1
  w="$(cat "$PALCO_DIR/wayland")"
  [ -S "$RT/$w" ] && [ -n "$(_membros "$(sed -n 1p "$GRUPOS")")" ] && [ -n "$(_membros "$(sed -n 2p "$GRUPOS")")" ]
}

_compositor() {
  local c
  if [ -n "${PALCO_COMPOSITOR:-}" ]; then printf '%s\n' "$PALCO_COMPOSITOR"; return; fi
  c="$(command -v cosmic-comp 2>/dev/null)" || c=/usr/bin/cosmic-comp
  if grep -qs 'MEOW-COSMIC-COMP-SHIM' "$c"; then
    c="$(HOME="$PALCO_ORIGEM" MEOW_SHIM_SO_DIZER=1 "$c")"
  fi
  printf '%s\n' "$c"
}

_tela_livre() {
  local n
  for n in $(seq 90 199); do
    [ -e "/tmp/.X$n-lock" ] || [ -e "/tmp/.X11-unix/X$n" ] || { printf '%s\n' "$n"; return 0; }
  done
  return 1
}

_xwayland() {
  local l pid g
  g="$(sed -n 2p "$GRUPOS" 2>/dev/null)"
  [ -n "$g" ] || return 1
  for l in /tmp/.X[0-9]*-lock; do
    [ -f "$l" ] || continue
    pid="$(tr -dc '0-9' < "$l")"
    [ -n "$pid" ] && [ "$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')" = "$g" ] || continue
    l="${l#/tmp/.X}"
    printf ':%s\n' "${l%-lock}"
    return 0
  done
  return 1
}

_base() {
  BASE=(MEOW_PALCO="$PALCO_DIR" HOME="$CASA" XDG_RUNTIME_DIR="$RT"
        DBUS_SYSTEM_BUS_ADDRESS="$SEM_SISTEMA"
        XDG_DATA_DIRS="$PALCO_ORIGEM/.local/share:/usr/local/share:/usr/share"
        XDG_CURRENT_DESKTOP=COSMIC XDG_SESSION_TYPE=wayland
        PATH="$PATH" LANG="${LANG:-C.UTF-8}" USER="${USER:-$(id -un)}" LOGNAME="${LOGNAME:-$(id -un)}")
  [ -n "$PALCO_DCONF" ] && BASE+=(DCONF_PROFILE="$PALCO_DCONF")
  return 0
}

_ambiente() {
  local x
  _base
  AMBIENTE=("${BASE[@]}" WAYLAND_DISPLAY="$(cat "$PALCO_DIR/wayland")"
            DBUS_SESSION_BUS_ADDRESS="$(cat "$PALCO_DIR/barramento")")
  x="$(_xwayland)" && AMBIENTE+=(DISPLAY="$x")
}

_conferir() {
  local barramento wayland caminho real_bus
  barramento="$(cat "$PALCO_DIR/barramento" 2>/dev/null)"
  wayland="$(cat "$PALCO_DIR/wayland" 2>/dev/null)"
  real_bus="${PALCO_BUS_DELA:-${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}}"
  caminho="${barramento#unix:path=}"
  caminho="${caminho%%,*}"
  case "$barramento" in
    ''|"$real_bus"|*/run/user/*) _erro "recuso: o barramento do palco ($barramento) é o da sessão dela" ;;
  esac
  [ -S "$caminho" ] || _erro "recuso: o barramento do palco ($barramento) não existe"
  case "$wayland" in
    ''|*/*) _erro "recuso: a tela wayland do palco ($wayland) não é um nome de soquete" ;;
  esac
  [ -S "$RT/$wayland" ] || _erro "recuso: falta o soquete $RT/$wayland"
  [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -n "${WAYLAND_DISPLAY:-}" ] \
    && [ "$RT/$wayland" -ef "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ] \
    && _erro "recuso: a tela wayland do palco é a da sessão dela"
  return 0
}

_copiar() {
  local rel
  for rel in "$@"; do
    [ -e "$PALCO_ORIGEM/$rel" ] || continue
    mkdir -p "$CASA/$(dirname "$rel")"
    cp -rL --no-preserve=ownership "$PALCO_ORIGEM/$rel" "$CASA/$(dirname "$rel")/" 2>/dev/null
  done
  return 0
}

_dizer() {
  printf 'palco: tela=%s wayland=%s/%s barramento=%s\n' \
    "$(cat "$PALCO_DIR/tela")" "$RT" "$(cat "$PALCO_DIR/wayland")" "$(cat "$PALCO_DIR/barramento")"
}

_palco_dir() {
  [ -f "$PALCO_DIR/.palco" ]
}

_subir() {
  local comp n i w x="" xw=() ativ
  if _vivo; then _dizer; return 0; fi
  [ -d "$PALCO_DIR" ] && ! _palco_dir && [ -n "$(ls -A "$PALCO_DIR" 2>/dev/null)" ] \
    && _erro "recuso: $PALCO_DIR já existe e não é um palco"
  _descer
  command -v Xvfb >/dev/null || _erro "falta o Xvfb: sudo apt install xvfb"
  command -v dbus-run-session >/dev/null || _erro "falta o dbus-run-session: sudo apt install dbus-bin"
  comp="$(_compositor)"
  [ -x "$comp" ] || _erro "falta o compositor ($comp)"
  n="$(_tela_livre)" || _erro "nenhuma tela X livre entre :90 e :199"
  mkdir -p "$PALCO_DIR" && chmod 700 "$PALCO_DIR" && : > "$PALCO_DIR/.palco" || _erro "não consigo criar $PALCO_DIR"
  mkdir -p "$RT" "$CASA" && chmod 700 "$RT" "$CASA"
  _copiar "${COPIAS[@]}"
  : > "$GRUPOS"
  printf ':%s\n' "$n" > "$PALCO_DIR/tela"
  printf '%s\n' "$comp" > "$PALCO_DIR/compositor"
  setsid env -i MEOW_PALCO="$PALCO_DIR" PATH="$PATH" \
    Xvfb ":$n" -screen 0 "${PALCO_TELA}x24" -nolisten tcp </dev/null >"$PALCO_DIR/xvfb.log" 2>&1 &
  printf '%s\n' "$!" >> "$GRUPOS"
  for i in $(seq 100); do [ -S "/tmp/.X11-unix/X$n" ] && break; sleep 0.1; done
  [ -S "/tmp/.X11-unix/X$n" ] || { _descer; _erro "o Xvfb :$n não subiu ($(tail -n1 "$PALCO_DIR/xvfb.log" 2>/dev/null))"; }
  [ "$PALCO_XWAYLAND" = 1 ] || xw=(--no-xwayland)
  _base
  setsid env -i "${BASE[@]}" DISPLAY=":$n" COSMIC_BACKEND=winit \
    dbus-run-session -- /bin/sh -c 'printf "%s\n" "$DBUS_SESSION_BUS_ADDRESS" > "$1.novo" && mv "$1.novo" "$1"; shift; exec "$@"' \
    palco "$PALCO_DIR/barramento" "$comp" "${xw[@]}" </dev/null >"$PALCO_DIR/compositor.log" 2>&1 &
  printf '%s\n' "$!" >> "$GRUPOS"
  for i in $(seq 200); do
    w="$(find "$RT" -maxdepth 1 -type s -name 'wayland-[0-9]*' -printf '%f\n' 2>/dev/null | head -n1)"
    [ -n "$w" ] && [ -s "$PALCO_DIR/barramento" ] && break
    [ -n "$(_membros "$(sed -n 2p "$GRUPOS")")" ] || break
    sleep 0.1
  done
  if [ -z "$w" ] || [ ! -s "$PALCO_DIR/barramento" ]; then
    tail -n5 "$PALCO_DIR/compositor.log" >&2 2>/dev/null
    _descer
    _erro "o compositor ($comp) não abriu a tela wayland do palco"
  fi
  printf '%s\n' "$w" > "$PALCO_DIR/wayland"
  _conferir
  ativ=(WAYLAND_DISPLAY="$w")
  if [ "$PALCO_XWAYLAND" = 1 ]; then
    for i in $(seq 50); do x="$(_xwayland)" && break; sleep 0.1; done
    [ -n "$x" ] && ativ+=(DISPLAY="$x")
  fi
  env -i MEOW_PALCO="$PALCO_DIR" PATH="$PATH" DBUS_SESSION_BUS_ADDRESS="$(cat "$PALCO_DIR/barramento")" \
    dbus-update-activation-environment "${ativ[@]}" || { _descer; _erro "não consegui dar a tela do palco ao barramento do palco"; }
  _dizer
}

_dono_do_soquete() {
  ss -xlpn 2>/dev/null | awk -v s="$1" '$5 == s && match($0, /pid=[0-9]+/) { print substr($0, RSTART + 4, RLENGTH - 4); exit }'
}

_rodar_na_area() {
  local area="${1:-}" tela="" soquete pid areas
  local uso="uso: palco.sh rodar --area <nome> [--tela <saída>] <comando…>"
  case "$area" in ''|-*) _erro "$uso" ;; esac
  shift
  if [ "${1:-}" = --tela ]; then
    tela="${2:-}"
    case "$tela" in ''|-*) _erro "$uso" ;; esac
    shift 2
  fi
  [ "$#" -gt 0 ] || _erro "$uso"
  [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ] || _erro "recuso: rodar --area roda na sessão, e falta WAYLAND_DISPLAY ou XDG_RUNTIME_DIR"
  case "$WAYLAND_DISPLAY" in /*) soquete="$WAYLAND_DISPLAY" ;; *) soquete="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ;; esac
  [ -S "$soquete" ] || _erro "recuso: $soquete não é a tela wayland de uma sessão"
  pid="$(_dono_do_soquete "$soquete")"
  [ -n "$pid" ] || _erro "recuso: não achei o compositor de $soquete"
  grep -qaF 'AURORA-AREA-DO-CLIENTE' "/proc/$pid/exe" 2>/dev/null \
    || _erro "recuso: o compositor da sessão ($(readlink "/proc/$pid/exe")) não faz a janela nascer na área: ela abriria na área visível"
  areas="$(python3 "$RAIZ/scripts/appid_sonda.py" --areas 2>/dev/null | awk -F'\t' -v a="$area" '$1 == "area" && $2 == a { print $3 }')"
  [ -n "$areas" ] || _erro "recuso: a sessão não tem área «$area»"
  grep -q 'ativa' <<< "$areas" && _erro "recuso: a área «$area» é a que está na tela"
  if [ -n "$tela" ]; then
    MEOW_AREA="$area" MEOW_TELA="$tela" setsid "$@" </dev/null >/dev/null 2>&1 &
  else
    MEOW_AREA="$area" setsid "$@" </dev/null >/dev/null 2>&1 &
  fi
  printf '%s\n' "$!"
}

_rodar() {
  local log
  [ "${1:-}" = --area ] && { shift; _rodar_na_area "$@"; return; }
  [ "$#" -gt 0 ] || _erro "uso: palco.sh rodar <comando…>"
  _vivo || _subir >/dev/null || exit 1
  _conferir
  _ambiente
  log="$PALCO_DIR/rodar-$(date +%s%N).log"
  setsid env -i "${AMBIENTE[@]}" "$@" </dev/null >"$log" 2>&1 &
  printf '%s\n' "$!" >> "$GRUPOS"
  printf '%s\n' "$!"
}

_foto() {
  local saida="${1:-}" recorte="${2:-}"
  [ -n "$saida" ] || _erro "uso: palco.sh foto <saida.png> [LxA+X+Y]"
  _vivo || _erro "o palco não está de pé: palco.sh subir"
  command -v import >/dev/null || _erro "falta o import: sudo apt install imagemagick"
  if [ -n "$recorte" ]; then
    env -i PATH="$PATH" DISPLAY="$(cat "$PALCO_DIR/tela")" import -window root -crop "$recorte" +repage "$saida"
  else
    env -i PATH="$PATH" DISPLAY="$(cat "$PALCO_DIR/tela")" import -window root "$saida"
  fi
}

_janelas() {
  _vivo || _erro "o palco não está de pé: palco.sh subir"
  _conferir
  env -i HOME="$CASA" PATH="$PATH" XDG_RUNTIME_DIR="$RT" WAYLAND_DISPLAY="$(cat "$PALCO_DIR/wayland")" \
    python3 "$RAIZ/scripts/appid_sonda.py" --janelas
}

_areas() {
  _vivo || _erro "o palco não está de pé: palco.sh subir"
  _conferir
  env -i HOME="$CASA" PATH="$PATH" XDG_RUNTIME_DIR="$RT" WAYLAND_DISPLAY="$(cat "$PALCO_DIR/wayland")" \
    python3 "$RAIZ/scripts/appid_sonda.py" --areas
}

_descer() {
  local p i m resto telas
  _palco_dir || return 0
  telas="$(cat "$PALCO_DIR/tela" 2>/dev/null) $(_xwayland 2>/dev/null)"
  resto="$(_nossos)"
  [ -n "$resto" ] && kill -TERM $resto 2>/dev/null
  for i in $(seq 50); do
    resto="$(_nossos)"
    [ -z "$resto" ] && break
    sleep 0.1
  done
  [ -n "$resto" ] && kill -KILL $resto 2>/dev/null && sleep 0.2
  awk -v d="$PALCO_DIR/" 'index($2, d) == 1 { print $2 }' /proc/self/mounts | sort -r | while read -r m; do
    fusermount3 -u -z "$m" 2>/dev/null || fusermount -u -z "$m" 2>/dev/null
  done
  for p in $telas; do
    p="${p#:}"
    i="$(tr -dc '0-9' 2>/dev/null < "/tmp/.X$p-lock")"
    [ -n "$i" ] && kill -0 "$i" 2>/dev/null && continue
    rm -f "/tmp/.X$p-lock" "/tmp/.X11-unix/X$p" 2>/dev/null
  done
  rm -rf --one-file-system "$PALCO_DIR"
}

case "${1:-}" in
  subir)   _subir ;;
  rodar)   shift; _rodar "$@" ;;
  foto)    shift; _foto "$@" ;;
  janelas) _janelas ;;
  areas)   _areas ;;
  copiar)  shift; _vivo || _erro "o palco não está de pé: palco.sh subir"; _copiar "$@" ;;
  descer)  _descer ;;
  *) printf 'uso: palco.sh subir | rodar [--area <nome> [--tela <saída>]] <comando…> | foto <saida.png> [LxA+X+Y] | janelas | areas | copiar <caminho do HOME…> | descer\n' >&2
     exit 2 ;;
esac

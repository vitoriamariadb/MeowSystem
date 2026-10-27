#!/usr/bin/env bash

[ -n "${MEOW_PAINEL_SH_CARREGADO:-}" ] && return 0
MEOW_PAINEL_SH_CARREGADO=1

MEOW_PAINEL_BASE="${MEOW_PAINEL_BASE:-$(meow_cosmic_dir)}"
MEOW_PAINEL_COMP_BIN="${MEOW_PAINEL_COMP_BIN:-$(meow_cosmic_comp_disco)}"
MEOW_PAINEL_MARCA_RAIO="AURORA-COSMIC-RADIUS-PATCH"

meow_painel_T() {
  case "$1" in
    XS) printf '32' ;;
    S)  printf '40' ;;
    M)  printf '56' ;;
    L)  printf '64' ;;
    XL) printf '80' ;;
    Custom\(*\))
      local n="${1#Custom(}"; n="${n%)}"
      case "$n" in ''|*[!0-9]*) return 1 ;; esac
      [ "$n" -lt 16 ] && n=16
      printf '%s' $(( (n / 4) * 4 ))
      ;;
    *) return 1 ;;
  esac
}

_meow_painel_opt() {
  local v
  v="$(cat "$1" 2>/dev/null)" || return 1
  case "$v" in
    None|'') return 1 ;;
    Some\(*\)) v="${v#Some(}"; v="${v%)}"; printf '%s' "$v" ;;
    *) printf '%s' "$v" ;;
  esac
}

meow_painel_wings() {
  local v ini fim
  v="$(cat "$1" 2>/dev/null)" || return 1
  case "$v" in Some\(\(*\)\)) : ;; *) return 1 ;; esac
  v="${v#Some((}"; v="${v%))}"
  ini="${v%%,*}"; fim="${v#*,}"
  ini="${ini# }"; fim="${fim# }"
  case "$ini" in None) ini='' ;; Some\(*\)) ini="${ini#Some(}"; ini="${ini%)}" ;; esac
  case "$fim" in None) fim='' ;; Some\(*\)) fim="${fim#Some(}"; fim="${fim%)}" ;; esac
  printf '%s\t%s' "$ini" "$fim"
}

meow_painel_altura() {
  local dir="$1" size padding maior t ini fim w
  size="$(_meow_painel_opt "$dir/size")" || size="$(cat "$dir/size" 2>/dev/null)"
  [ -n "$size" ] || return 1
  padding="$(cat "$dir/padding" 2>/dev/null)"
  case "$padding" in ''|*[!0-9]*) return 1 ;; esac

  maior="$(meow_painel_T "$size")" || return 1

  if t="$(_meow_painel_opt "$dir/size_center")"; then
    t="$(meow_painel_T "$t")" && [ "$t" -gt "$maior" ] && maior="$t"
  fi
  if w="$(meow_painel_wings "$dir/size_wings")"; then
    ini="${w%%$'\t'*}"; fim="${w#*$'\t'}"
    if [ -n "$ini" ]; then t="$(meow_painel_T "$ini")" && [ "$t" -gt "$maior" ] && maior="$t"; fi
    if [ -n "$fim" ]; then t="$(meow_painel_T "$fim")" && [ "$t" -gt "$maior" ] && maior="$t"; fi
  fi

  printf '%s' $(( 2 * padding + maior ))
}

meow_painel_teto() {
  local h
  h="$(meow_painel_altura "$1")" || return 1
  meow_painel_compositor_clampa || { printf '0'; return 0; }
  printf '%s' $(( h / 2 ))
}

meow_painel_compositor_clampa() {
  local p
  p="$(pgrep -x cosmic-comp | head -1)"
  [ -n "$p" ] && [ -r "/proc/$p/exe" ] || return 1
  grep -aqs "$MEOW_PAINEL_MARCA_RAIO" "/proc/$p/exe"
}

meow_painel_patch_pendente() {
  meow_painel_compositor_clampa && return 1
  grep -aqs "$MEOW_PAINEL_MARCA_RAIO" "$MEOW_PAINEL_COMP_BIN"
}

MEOW_PAINEL_LISTA_NEGRA='PANEL_NOTIFICATIONS_FD DAEMON_NOTIFICATIONS_FD X_PRIVILEGED_WAYLAND_SOCKET'

meow_painel_ambiente_ok() {
  [ -n "${WAYLAND_DISPLAY:-}" ] && [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${WAYLAND_DISPLAY}" ]
}

meow_painel_achar_display() {
  local s d="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  for s in "$d"/wayland-[0-9]*; do
    case "$s" in *.lock) continue ;; esac
    [ -S "$s" ] || continue
    printf '%s' "${s##*/}"; return 0
  done
  return 1
}

meow_painel_fantasma() {
  local pid vida
  pid="$(pgrep -x cosmic-panel 2>/dev/null | head -1)"
  [ -n "$pid" ] || return 1

  vida="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')"
  case "$vida" in ''|*[!0-9]*) return 1 ;; esac
  [ "$vida" -ge 20 ] || return 1

  journalctl --user -b --no-pager _PID="$pid" 2>/dev/null \
    | grep -qiE 'failed to render|erroneous egl|protocol error|error 1 on object' \
    && return 0
  return 1
}

meow_painel_do_supervisor() {
  local ses p pai
  ses="$(pgrep -x cosmic-session | head -1)"
  [ -n "$ses" ] || return 1
  for p in $(meow_painel_desta_casa); do
    pai="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
    [ "$pai" = "$ses" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

meow_painel_desta_casa() {
  local p casa eu="${HOME%/}"
  for p in $(pgrep -u "$(id -u)" -x cosmic-panel 2>/dev/null); do
    casa="$(tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | sed -n 's/^HOME=//p' | head -n1)"
    [ -n "$casa" ] && [ "${casa%/}" = "$eu" ] && printf '%s\n' "$p"
  done
  return 0
}

meow_painel_nossos() {
  local ses p pai achou=1
  ses="$(pgrep -x cosmic-session | head -1)"
  for p in $(meow_painel_desta_casa); do
    pai="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
    [ -n "$ses" ] && [ "$pai" = "$ses" ] && continue
    printf '%s\n' "$p"; achou=0
  done
  return "$achou"
}

meow_painel_espera_supervisor() {
  local log ms
  log="$(journalctl --user -b -t cosmic-session --no-pager 2>/dev/null)"
  ms="$(printf '%s\n' "$log" \
    | grep -oE 'sleeping for [0-9]+ms before restarting process cosmic-panel' \
    | tail -1 | grep -oE '[0-9]+')"
  if [ -n "$ms" ]; then printf '%s\n' "$ms"; return 0; fi
  if printf '%s\n' "$log" | grep -i 'cosmic-panel' | grep -qi 'restart'; then
    printf 'nao-medida\n'
  fi
}

#!/usr/bin/env bash

meow_minutos_de_hora() {
  local v="${1:-}" h m
  v="${v%\"}"; v="${v#\"}"
  case "$v" in
    [0-9][0-9]:[0-9][0-9]|[0-9]:[0-9][0-9]) ;;
    *) return 1 ;;
  esac
  h="${v%%:*}"; m="${v##*:}"
  [ "$((10#$h))" -le 23 ] && [ "$((10#$m))" -le 59 ] || return 1
  printf '%s' "$(( 10#$h * 60 + 10#$m ))"
}

_meow_noite_cosmic() {
  local f; f="$(meow_cosmic_dir)/com.system76.CosmicComp/$(meow_cosmic_v com.system76.CosmicComp)/$1"
  [ -f "$f" ] || return 1
  local v; v="$(cat "$f" 2>/dev/null)" || return 1
  [ -n "$v" ] || return 1
  printf '%s' "$v"
}

meow_noite_janela() {
  local i f ini fim

  if i="${NOITE_INICIO:-}" && f="${NOITE_FIM:-}" && [ -n "$i" ] && [ -n "$f" ]; then
    if ini="$(meow_minutos_de_hora "$i")" && fim="$(meow_minutos_de_hora "$f")"; then
      printf '%s %s meow.conf' "$ini" "$fim"; return 0
    fi
  fi

  if i="$(_meow_noite_cosmic leitura_hora_inicio)" \
     && f="$(_meow_noite_cosmic leitura_hora_fim)"; then
    if ini="$(meow_minutos_de_hora "$i")" && fim="$(meow_minutos_de_hora "$f")"; then
      printf '%s %s applet-leitura' "$ini" "$fim"; return 0
    fi
  fi

  i="${WALLPAPER_NOITE_INICIO:-}"; f="${WALLPAPER_NOITE_FIM:-}"
  if [ -n "$i" ] && [ -n "$f" ]; then
    if ini="$(meow_minutos_de_hora "$i")" && fim="$(meow_minutos_de_hora "$f")"; then
      printf '%s %s meow.conf(WALLPAPER_NOITE_*)' "$ini" "$fim"; return 0
    fi
  fi

  printf '1080 420 padrão'
}

meow_e_noite() {
  local ini fim agora janela
  if [ "$#" -ge 2 ]; then
    ini="$1"; fim="$2"
  else
    janela="$(meow_noite_janela)"
    ini="${janela%% *}"; fim="${janela#* }"; fim="${fim%% *}"
  fi
  agora="$(meow_minutos_de_hora "$(date +%H:%M)")" || return 0
  [ "$ini" = "$fim" ] && return 0
  if [ "$ini" -gt "$fim" ]; then
    [ "$agora" -ge "$ini" ] || [ "$agora" -lt "$fim" ]
  else
    [ "$agora" -ge "$ini" ] && [ "$agora" -lt "$fim" ]
  fi
}

meow_fase_da_hora() { if meow_e_noite "$@"; then printf 'noite'; else printf 'dia'; fi; }

meow_hora_de_minutos() { printf '%02d:%02d' "$(( ${1:-0} / 60 ))" "$(( ${1:-0} % 60 ))"; }

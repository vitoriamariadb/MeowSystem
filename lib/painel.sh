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

MEOW_PAINEL_JANELA_STARTUP="${MEOW_PAINEL_JANELA_STARTUP:-300}"

meow_painel_sinal_notificacoes_sem_conexao() {
  journalctl --user -b --no-pager _PID="$1" 2>/dev/null \
    | grep -qE "Can't start notifications applet without a connection|Failed to connect to the notifications daemon"
}

meow_painel_sinal_applet_de_notificacoes_ausente() {
  local vida="$1"
  [ "$vida" -le "$MEOW_PAINEL_JANELA_STARTUP" ] || return 1
  grep -qs "CosmicAppletNotifications" \
    "$MEOW_PAINEL_BASE"/com.system76.CosmicPanel.Panel/v*/plugins_center \
    "$MEOW_PAINEL_BASE"/com.system76.CosmicPanel.Panel/v*/plugins_wings \
    "$MEOW_PAINEL_BASE"/com.system76.CosmicPanel.Dock/v*/plugins_center \
    "$MEOW_PAINEL_BASE"/com.system76.CosmicPanel.Dock/v*/plugins_wings || return 1
  ! pgrep -f '^(/[^ ]*/)?cosmic-applet-notifications( |$)' >/dev/null 2>&1
}

MEOW_PAINEL_ENXURRADA_DE_RAIO=20

meow_painel_sinal_render_com_enxurrada_de_raio() {
  local pid="$1" vida="$2" desde n
  desde="$(date -d "@$(( $(date +%s) - vida ))" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
  [ -n "$desde" ] || desde="$vida seconds ago"
  n="$(journalctl --user -b --since "$desde" --no-pager 2>/dev/null \
    | grep -cE 'cosmic_corner_radius_layer_v1|corner radius too large')"
  [ "${n:-0}" -ge "$MEOW_PAINEL_ENXURRADA_DE_RAIO" ] || return 1
  journalctl --user -b --no-pager _PID="$pid" 2>/dev/null \
    | grep -qiE 'failed to render|erroneous egl'
}

meow_painel_sinal_protocolo_na_sessao() {
  local vida="$1" desde
  desde="$(date -d "@$(( $(date +%s) - vida ))" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)"
  [ -n "$desde" ] || desde="$vida seconds ago"
  journalctl --user -b --since "$desde" --no-pager 2>/dev/null \
    | grep -qaE 'tried to grab after being mapped|xdg_(popup|surface|toplevel)#[0-9]+: error [0-9]+|wl_(surface|display)#[0-9]+: error [0-9]+'
}

meow_painel_fantasma() {
  local pid vida
  pid="$(pgrep -x cosmic-panel 2>/dev/null | head -1)"
  [ -n "$pid" ] || return 2

  vida="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')"
  case "$vida" in ''|*[!0-9]*) return 2 ;; esac
  [ "$vida" -ge 20 ] || return 2

  MEOW_PAINEL_SINAL="sinal 1, notificações sem conexão"
  meow_painel_sinal_notificacoes_sem_conexao "$pid" && return 0
  MEOW_PAINEL_SINAL="sinal 2, applet de notificações ausente"
  meow_painel_sinal_applet_de_notificacoes_ausente "$vida" && return 0
  MEOW_PAINEL_SINAL="sinal 3, render com enxurrada de raio"
  meow_painel_sinal_render_com_enxurrada_de_raio "$pid" "$vida" && return 0
  MEOW_PAINEL_SINAL="sinal 4, erro de protocolo na sessão"
  meow_painel_sinal_protocolo_na_sessao "$vida" && return 0
  MEOW_PAINEL_SINAL=""
  return 1
}

MEOW_PAINEL_RECICLAGENS_POR_BOOT=2

meow_painel_contador_do_boot() {
  printf '%s/meowsystem/painel-reciclagens' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
}

meow_painel_reciclagens_do_boot() {
  local n
  n="$(cat "$(meow_painel_contador_do_boot)" 2>/dev/null)"
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  printf '%s' "$n"
}

meow_painel_desistiu() {
  [ "$(meow_painel_reciclagens_do_boot)" -ge "$MEOW_PAINEL_RECICLAGENS_POR_BOOT" ]
}

meow_painel_gastar_reciclagem_do_boot() {
  local contador n
  contador="$(meow_painel_contador_do_boot)"
  n="$(meow_painel_reciclagens_do_boot)"
  if [ "$n" -lt "$MEOW_PAINEL_RECICLAGENS_POR_BOOT" ]; then
    mkdir -p "${contador%/*}" 2>/dev/null
    printf '%s' "$(( n + 1 ))" > "$contador"
    return 0
  fi
  [ -e "$contador.avisado" ] && return 2
  : > "$contador.avisado"
  meow_notificar "A barra não desenha" "Reiniciei $n vezes e desisti." critical
  return 1
}

meow_painel_zerar_reciclagens_do_boot() {
  local contador
  contador="$(meow_painel_contador_do_boot)"
  [ -e "$contador" ] || [ -e "$contador.avisado" ] || return 1
  rm -f "$contador" "$contador.avisado"
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

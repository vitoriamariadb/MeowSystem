#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

RELOGIO_SEGUNDOS="${RELOGIO_SEGUNDOS:-}"

RELOGIO_BASE="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}/com.system76.CosmicAppletTime/$(meow_cosmic_v com.system76.CosmicAppletTime)"
RELOGIO_ALVO="$RELOGIO_BASE/show_seconds"
RELOGIO_BINARIO="/usr/bin/cosmic-applet-time"

RELOGIO_ANTES="$MEOW_ESTADO/relogio/show_seconds.antes"

_relogio_bool() {
  case "$1" in
    sim|true|1)        printf 'true' ;;
    nao|não|false|0)   printf 'false' ;;
    *) return 1 ;;
  esac
}

_relogio_dependencia() {
  if [ ! -x "$RELOGIO_BINARIO" ] && [ ! -d "$RELOGIO_BASE" ]; then
    meow_pula "cosmic-applet-time não encontrado — nada a fazer com o relógio"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

_relogio_no_disco() {
  [ -f "$RELOGIO_ALVO" ] && cat "$RELOGIO_ALVO" 2>/dev/null || printf ''
}

_relogio_lembrar_antes() {
  meow_seco && return 0
  [ -f "$RELOGIO_ANTES" ] && return 0
  mkdir -p "$(dirname "$RELOGIO_ANTES")" 2>/dev/null || return 0
  printf '%s' "$(_relogio_no_disco)" > "$RELOGIO_ANTES" 2>/dev/null || true
  return 0
}

cmd_aplicar() {
  if [ -z "$RELOGIO_SEGUNDOS" ]; then
    meow_pula "RELOGIO_SEGUNDOS vazio — o relógio é seu, o botão da GUI manda"
    return "$MEOW_OK"
  fi
  _relogio_dependencia || return $?

  local valor
  valor="$(_relogio_bool "$RELOGIO_SEGUNDOS")" || {
    meow_erro "RELOGIO_SEGUNDOS='$RELOGIO_SEGUNDOS' — esperado sim ou nao"
    return "$MEOW_ERRO"
  }

  local atual; atual="$(_relogio_no_disco)"
  [ "$atual" = "$valor" ] || _relogio_lembrar_antes

  meow_escrever "$RELOGIO_ALVO" "$valor" 644
  local rc=$?
  case "$rc" in
    "$MEOW_ERRO")
      meow_erro "não consegui gravar $RELOGIO_ALVO"; return "$MEOW_ERRO" ;;
    "$MEOW_DIVERGENTE")
      if meow_seco; then
        meow_muda "gravaria show_seconds=$valor"
      else
        if [ "$valor" = "false" ]; then
          meow_muda "relógio SEM segundos (show_seconds=false)"
        else
          meow_muda "relógio COM segundos (show_seconds=true)"
        fi
        meow_info "vale na hora: medido em 25/08/2026, a topbar acompanha em menos de 2 s"
        meow_info "nada a reiniciar — o cosmic-panel NÃO é tocado por este script"
      fi ;;
    *)
      meow_ok "relógio já estava com show_seconds=$valor" ;;
  esac
  meow_registrar "relogio.sh aplicar valor=$valor rc=$rc"
  return "$rc"
}

cmd_conferir() {
  if [ -z "$RELOGIO_SEGUNDOS" ]; then
    meow_pula "RELOGIO_SEGUNDOS vazio — nada a conferir (o valor é seu)"
    return "$MEOW_OK"
  fi
  _relogio_dependencia || return $?

  local valor
  valor="$(_relogio_bool "$RELOGIO_SEGUNDOS")" || {
    meow_erro "RELOGIO_SEGUNDOS='$RELOGIO_SEGUNDOS' — esperado sim ou nao"
    return "$MEOW_ERRO"
  }

  local atual; atual="$(_relogio_no_disco)"
  if [ "$atual" = "$valor" ]; then
    meow_ok "relógio conforme (show_seconds=$valor)"
    return "$MEOW_OK"
  fi
  meow_muda "relógio divergente: disco='${atual:-<ausente>}', conf pede '$valor'"
  meow_aviso "o relógio tem controle na GUI (Ajustes → Data e hora)."
  meow_aviso "o valor do meow.conf manda: o doctor o devolve todo dia."
  local onde; onde="$(meow_onde_no_painel RELOGIO_SEGUNDOS)"
  [ -z "$onde" ] || meow_info "  o valor se escolhe em $onde"
  return "$MEOW_DIVERGENTE"
}

_relogio_col() { printf '%-24s' "$1"; }

cmd_estado() {
  _relogio_dependencia || return $?
  local k v
  for k in show_seconds military_time first_day_of_week show_weekday show_date_in_top_panel format_strftime; do
    if [ -f "$RELOGIO_BASE/$k" ]; then
      v="$(cat "$RELOGIO_BASE/$k" 2>/dev/null)"
      meow_info "$(_relogio_col "$k") = $v"
    else
      meow_pula "$(_relogio_col "$k") = <ausente: vale o Default do applet>"
    fi
  done
  meow_info "as duas 'ausente' que o binário conhece — show_weekday e"
  meow_info "show_date_in_top_panel — são decisão sua, e este script não as escreve."
  local pid; pid="$(pgrep -f 'cosmic-applet-time' 2>/dev/null | head -1)"
  if [ -n "$pid" ]; then
    meow_ok "cosmic-applet-time vivo (PID $pid) — ele relê a chave sozinho, em ~2 s"
  else
    meow_aviso "cosmic-applet-time NÃO está rodando — o relógio não está na topbar"
  fi
  return "$MEOW_OK"
}

cmd_remover() {
  _relogio_dependencia || return $?
  local devolver="true"
  if [ -f "$RELOGIO_ANTES" ]; then
    local guardado; guardado="$(cat "$RELOGIO_ANTES" 2>/dev/null)"
    case "$guardado" in true|false) devolver="$guardado" ;; esac
  fi

  meow_escrever "$RELOGIO_ALVO" "$devolver" 644
  local rc=$?
  case "$rc" in
    "$MEOW_ERRO") meow_erro "não consegui devolver $RELOGIO_ALVO"; return "$MEOW_ERRO" ;;
    "$MEOW_DIVERGENTE")
      meow_seco && meow_muda "devolveria show_seconds=$devolver" \
                || meow_muda "relógio devolvido: show_seconds=$devolver" ;;
    *) meow_ok "relógio já estava em show_seconds=$devolver" ;;
  esac
  meow_seco || rm -f "$RELOGIO_ANTES" 2>/dev/null
  meow_registrar "relogio.sh remover valor=$devolver rc=$rc"
  return "$rc"
}

case "${1:-aplicar}" in
  aplicar)  cmd_aplicar ;;
  conferir) cmd_conferir ;;
  estado)   cmd_estado ;;
  remover)  cmd_remover ;;
  *) meow_erro "uso: relogio.sh {aplicar|conferir|estado|remover}"; exit "$MEOW_ERRO" ;;
esac

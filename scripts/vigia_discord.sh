#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ORIGEM="$RAIZ/systemd"
DESTINO="$HOME/.config/systemd/user"
UNIDADES=(meow-discord.service meow-discord.path)
GATILHO="meow-discord.path"

VIGIA="${DISCORD_VENCORD:-sim}"

CONFERIR=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

_texto_de() { cat "$ORIGEM/$1" 2>/dev/null; }

_tem_systemd() {
  meow_tem systemctl && [ -d "/run/user/$(id -u)/systemd" ]
}

_ligado() {
  [ "$(systemctl --user is-enabled "$GATILHO" 2>/dev/null)" = "enabled" ] &&
  [ "$(systemctl --user is-active  "$GATILHO" 2>/dev/null)" = "active" ]
}

_desligar() {
  local u restos=0
  for u in "${UNIDADES[@]}"; do [ -f "$DESTINO/$u" ] && restos=$((restos + 1)); done

  if [ "$restos" = 0 ]; then
    meow_pula "vigia do Discord desligado (DISCORD_VENCORD=\"$VIGIA\")"
    return "$MEOW_OK"
  fi
  if [ "$CONFERIR" = 1 ]; then
    meow_muda "DISCORD_VENCORD=\"$VIGIA\" mas o vigia continua instalado — removeria $restos unidade(s)"
    return "$MEOW_DIVERGENTE"
  fi
  _tem_systemd && systemctl --user disable --now "$GATILHO" >/dev/null 2>&1
  for u in "${UNIDADES[@]}"; do rm -f "$DESTINO/$u"; done
  _tem_systemd && systemctl --user daemon-reload >/dev/null 2>&1
  meow_muda "DISCORD_VENCORD=\"$VIGIA\" — vigia do Discord desligado e removido"
  return "$MEOW_DIVERGENTE"
}

_pronto() {
  local u
  for u in "${UNIDADES[@]}"; do
    if [ ! -f "$ORIGEM/$u" ]; then
      meow_erro "falta $ORIGEM/$u — repositório incompleto"
      return "$MEOW_ERRO"
    fi
  done
  if [ ! -d "${XDG_CONFIG_HOME:-$HOME/.config}/discord" ]; then
    meow_pula "Discord oficial não instalado (ou nunca aberto) — nada a vigiar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _tem_systemd; then
    meow_aviso "não há systemd --user nesta sessão — o vigia do Discord fica de fora"
    meow_info "  o Vencord continua sendo reposto pelo meow-doctor.timer, às 5h"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

_conferir() {
  local u texto divergentes=0
  for u in "${UNIDADES[@]}"; do
    texto="$(_texto_de "$u")" || { meow_erro "não consegui ler $ORIGEM/$u"; return "$MEOW_ERRO"; }
    if [ ! -f "$DESTINO/$u" ] || [ "$texto" != "$(cat "$DESTINO/$u" 2>/dev/null)" ]; then
      divergentes=$((divergentes + 1))
    fi
  done

  if [ "$divergentes" != 0 ]; then
    meow_muda "vigia do Discord: $divergentes unidade(s) a instalar ou atualizar"
    return "$MEOW_DIVERGENTE"
  fi
  if [ "$(systemctl --user is-failed "$GATILHO" 2>/dev/null)" = "failed" ]; then
    meow_muda "o $GATILHO está FALHO — provavelmente estourou o StartLimit"
    meow_info "  o conserto faz 'systemctl --user reset-failed' e religa"
    return "$MEOW_DIVERGENTE"
  fi
  if ! _ligado; then
    meow_muda "as unidades estão no lugar, mas o $GATILHO não está ligado"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "vigiando o Discord — o app novo da atualização recebe o Vencord sozinho"
  return "$MEOW_OK"
}

_aplicar() {
  local u texto mudou=0 estado="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"

  if ! mkdir -p "$estado"; then
    meow_erro "não consegui criar $estado (é lá que fica o log do vigia)"
    return "$MEOW_ERRO"
  fi

  for u in "${UNIDADES[@]}"; do
    texto="$(_texto_de "$u")" || { meow_erro "não consegui ler $ORIGEM/$u"; return "$MEOW_ERRO"; }
    meow_escrever "$DESTINO/$u" "$texto" 644
    case $? in
      1) mudou=1 ;;
      2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;;
    esac
  done

  [ "$mudou" = 1 ] && systemctl --user daemon-reload

  if [ "$(systemctl --user is-failed "$GATILHO" 2>/dev/null)" = "failed" ]; then
    systemctl --user reset-failed "$GATILHO" meow-discord.service >/dev/null 2>&1
    mudou=1
  fi

  if ! _ligado; then
    if ! systemctl --user enable --now "$GATILHO" >/dev/null 2>&1; then
      meow_erro "não consegui ligar o $GATILHO"
      return "$MEOW_ERRO"
    fi
    mudou=1
  fi

  if [ ! -f "$estado/raiz" ]; then
    meow_aviso "o vigia está ligado, mas $estado/raiz ainda não existe"
    meow_info "  até ele aparecer, cada disparo é pulado (o journal diz o motivo)"
  fi

  if [ "$mudou" = 0 ]; then
    meow_ok "vigia do Discord já ligado"
    return "$MEOW_OK"
  fi
  meow_ok "vigia ligado: o Discord atualizou, o Vencord volta ao app novo em menos de um minuto"
  return "$MEOW_DIVERGENTE"
}

main() {
  [ "$VIGIA" = "sim" ] || { _desligar; return $?; }
  _pronto || return $?
  if [ "$CONFERIR" = 1 ]; then _conferir; else _aplicar; fi
}

main "$@"

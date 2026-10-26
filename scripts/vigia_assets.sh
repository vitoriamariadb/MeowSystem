#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

_pastas_vigiadas() {
  local dir sub
  for dir in "$(meow_pack_dir)" "$RAIZ/packs/meowsystem"; do
    [ -n "$dir" ] && [ -d "$dir" ] || continue
    for sub in mascote wallpapers temas-de-apps; do
      [ -d "$dir/$sub" ] && find "$dir/$sub" -type d | LC_ALL=C sort
    done
  done | awk '!visto[$0]++'
}
ACERVO="$(meow_mascote_dir)/"
ORIGEM="$RAIZ/systemd"
DESTINO="$HOME/.config/systemd/user"
UNIDADES=(meow-assets.service meow-assets.path)
GATILHO="meow-assets.path"

VIGIA="${ASSETS_VIGIA:-sim}"

CONFERIR=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  --unidade) ;;
  --disparo) ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

_texto_de() {
  local u="$1" texto
  texto="$(cat "$ORIGEM/$u" 2>/dev/null)" || return 1
  if [ "$u" = "$GATILHO" ]; then
    local linhas="" d
    while IFS= read -r d; do linhas+="PathModified=$d"$'\n'; done < <(_pastas_vigiadas)
    linhas="${linhas%$'\n'}"
    texto="${texto//PathModified=@ACERVO@/$linhas}"
  fi
  printf '%s' "$texto"
}

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
    meow_pula "vigia do acervo desligado (ASSETS_VIGIA=\"$VIGIA\")"
    return "$MEOW_OK"
  fi
  if [ "$CONFERIR" = 1 ]; then
    meow_muda "ASSETS_VIGIA=\"$VIGIA\" mas o vigia continua instalado — removeria $restos unidade(s)"
    return "$MEOW_DIVERGENTE"
  fi
  _tem_systemd && systemctl --user disable --now "$GATILHO" >/dev/null 2>&1
  for u in "${UNIDADES[@]}"; do rm -f "$DESTINO/$u"; done
  _tem_systemd && systemctl --user daemon-reload >/dev/null 2>&1
  meow_muda "ASSETS_VIGIA=\"$VIGIA\" — vigia do acervo desligado e removido"
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
  if [ -z "$(_pastas_vigiadas)" ]; then
    meow_pula "o pack no ar não tem mascote, papel de parede nem tema de app — nada a vigiar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _tem_systemd; then
    meow_aviso "não há systemd --user nesta sessão — o vigia do acervo fica de fora"
    meow_info "  o mascote novo continua entrando pelo relógio (meow-logo.timer)"
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
    meow_muda "vigia do acervo: $divergentes unidade(s) a instalar ou atualizar"
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
  meow_ok "vigiando o mascote, os papéis de parede e os temas de apps do pack — a mudança entra sem esperar o relógio"
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
    systemctl --user reset-failed "$GATILHO" meow-assets.service >/dev/null 2>&1
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
    meow_ok "vigia do pack já ligado sobre o mascote, os papéis de parede e os temas de apps"
    return "$MEOW_OK"
  fi
  meow_ok "vigia ligado: mudou um desenho do pack, o que sai dele se refaz na hora"
  meow_info "  o mascote novo aparece em segundos: dock (painel reciclado), terminal e menu"
  return "$MEOW_DIVERGENTE"
}

_disparo() {
  local rc pior=0
  "$RAIZ/scripts/logo.sh"; rc=$?; [ "$rc" = 1 ] && pior=1
  "$RAIZ/scripts/fastfetch_logo.sh" aplicar; rc=$?; [ "$rc" = 1 ] && pior=1
  "$RAIZ/scripts/wallpaper.sh" semear; rc=$?; [ "$rc" = 1 ] && pior=1
  if [ -n "${APPS_ATIVOS:-}" ]; then
    "$RAIZ/scripts/aplicar_apps.sh"; rc=$?; [ "$rc" = 1 ] && pior=1
  fi
  return "$pior"
}

main() {
  case "${1:-}" in
    --unidade) _texto_de "${2:-$GATILHO}"; return $? ;;
    --disparo) _disparo; return $? ;;
  esac
  [ "$VIGIA" = "sim" ] || { _desligar; return $?; }
  _pronto || return $?
  if [ "$CONFERIR" = 1 ]; then _conferir; else _aplicar; fi
}

main "$@"

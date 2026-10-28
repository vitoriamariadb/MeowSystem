#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

CONFERIR=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

pior=-1
_dobrar() {
  local rc="$1"
  case "$rc" in
    2) pior=2 ;;
    1) [ "$pior" = 2 ] || pior=1 ;;
    0) case "$pior" in 2|1) ;; *) pior=0 ;; esac ;;
    3) [ "$pior" = -1 ] && pior=3 ;;
    *) pior=2 ;;
  esac
}

_rodar() {
  local script="$1"; shift
  if [ ! -x "$RAIZ/scripts/$script" ]; then
    meow_aviso "falta $RAIZ/scripts/$script — repositório incompleto"
    _dobrar 2
    return
  fi
  local arg=--aplicar
  [ "$CONFERIR" = 1 ] && arg=--conferir
  set -- "$arg" "$@"
  ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    FLAVOR="${FLAVOR:-}" \
    ICONES_COR_MARCA="${ICONES_COR_MARCA:-nao}" \
    "$RAIZ/scripts/$script" "$@"
  _dobrar $?
}

_rodar icones_tray_zapzap.sh
_rodar icones_bandeja.sh
_rodar icones_apps_arcticons.sh

_rodar nomes_apps.sh --so-flatpak

_acao_ft=aplicar
[ "$CONFERIR" = 1 ] && _acao_ft=conferir
CURSOR="${CURSOR:-}" NOME_TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
  "$RAIZ/scripts/flatpak_tema.sh" "$_acao_ft" tudo
_dobrar $?

if [ -z "${APPS_ATIVOS:-}" ] && [ -f "$HOME/.config/meow/meow.conf" ]; then
  APPS_ATIVOS="$(sed -n 's/^[[:space:]]*APPS_ATIVOS=//p' "$HOME/.config/meow/meow.conf" \
                 | tail -n 1 | tr -d '"'\''')"
fi

_flatpak_apps=""
for _slug in zapzap spotify; do
  case ",${APPS_ATIVOS:-}," in
    *",$_slug,"*) _flatpak_apps="${_flatpak_apps:+$_flatpak_apps,}$_slug" ;;
  esac
done

if [ -n "$_flatpak_apps" ] && [ -x "$RAIZ/scripts/aplicar_apps.sh" ]; then
  _acao=aplicar
  [ "$CONFERIR" = 1 ] && _acao=conferir
  APPS_ATIVOS="$_flatpak_apps" "$RAIZ/scripts/aplicar_apps.sh" "$_acao"
  _dobrar $?
elif [ -n "$_flatpak_apps" ]; then
  meow_aviso "falta $RAIZ/scripts/aplicar_apps.sh — repositório incompleto"
  _dobrar 2
fi

case "$pior" in
  -1|3) exit "$MEOW_SEM_DEPENDENCIA" ;;
  *)    exit "$pior" ;;
esac

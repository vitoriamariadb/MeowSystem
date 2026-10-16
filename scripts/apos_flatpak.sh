#!/usr/bin/env bash
# apos_flatpak.sh — o braço do gatilho de flatpak: reaplica O QUE É DA BANDEJA
#                   depois de todo `flatpak install/update/uninstall`.
#
# Fonte-de-verdade: MeowSystem/scripts/apos_flatpak.sh
# Quem chama:       systemd/meow-flatpak.service, disparado pelo
#                   systemd/meow-flatpak.path
# Quem instala:     install.sh, `etapa_vigia_flatpak` (via scripts/vigia_flatpak.sh)
#
#   ago 20 03:30:36   deploy update   com.rtosta.zapzap   stable   user
#
# Havia a previsão e não havia o gatilho.
#
#   icones_tray_zapzap.sh   O flatpak update TROCA A ÁRVORE DE DEPLOY inteira —
#                           diretório de commit novo, arquivos novos, hardlinks
#                           novos do OSTree. Tudo que estava escrito lá dentro
#                           some. É o caso dela.
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

# A dobra. `pior` começa em -1 = "ninguém falou ainda", que é diferente de 0.
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
  # O que sobrar em "$@" vai JUNTO do verbo — é assim que o `nomes_apps.sh`
  # recebe o `--so-flatpak` sem precisar de um segundo executor aqui.
  set -- "$arg" "$@"
  # FLAVOR e ICONES_COR_MARCA so interessam ao `icones_apps_arcticons.sh`; passar
  # para todos e inofensivo (os outros ignoram) e evita um segundo `_rodar` so
  # para ele — dois caminhos de invocacao e o que se esquece de atualizar.
  ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    FLAVOR="${FLAVOR:-}" \
    ICONES_COR_MARCA="${ICONES_COR_MARCA:-nao}" \
    "$RAIZ/scripts/$script" "$@"
  _dobrar $?
}

_rodar icones_tray_zapzap.sh
_rodar icones_bandeja.sh
# POR QUE O LANCADOR TAMBEM ENTRA, se ele ja sobrevive ao update
#
# Medido com o resolvedor real (`Gtk.IconTheme.lookup_icon`, tema
# MeowSystem-Icons): um `flatpak update` NAO desfaz o icone do lancador.
#
#     org.telegram.desktop  48px -> .../MeowSystem-Icons/48x48/apps/…svg
#     meow-whatsapp         48px -> .../MeowSystem-Icons/48x48/apps/…svg
_rodar icones_apps_arcticons.sh

# O bloco acima trata do TEMA de ícones, que sobrevive ao update.
_rodar nomes_apps.sh --so-flatpak

# --- os módulos de app que moram na árvore do flatpak -----------------------
# `APPS_ATIVOS` é a lista dela, e a unidade do systemd não a exporta (ela
# exporta só FLAVOR/ACCENT/NOME_TEMA_ICONES/ICONES_COR_MARCA).
if [ -z "${APPS_ATIVOS:-}" ] && [ -f "$HOME/.config/meow/meow.conf" ]; then
  APPS_ATIVOS="$(sed -n 's/^[[:space:]]*APPS_ATIVOS=//p' "$HOME/.config/meow/meow.conf" \
                 | tail -n 1 | tr -d '"'\''')"
fi

# A interseção com a lista dela: um slug desligado no meow.conf continua
# desligado aqui. Sem isto, o gatilho tematizaria um app que ela mandou deixar em
# paz — e um gatilho que desobedece à configuração é pior que gatilho nenhum.
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

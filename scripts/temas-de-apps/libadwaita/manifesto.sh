#!/usr/bin/env bash

. "$MEOW_RAIZ/lib/tema_arquivo.sh"

_LA_AJUSTES="$MEOW_RAIZ/scripts/temas-de-apps/libadwaita/ajustes"

_la_destino() { printf '%s/.var/app/%s/config/gtk-4.0/gtk.css' "$HOME" "$1"; }

_la_desejado() {
  local ajuste="$_LA_AJUSTES/$1.modelo.css" extra
  [ -f "$ajuste" ] || { printf '%s' "$TARQ_BASE"; return 0; }
  extra="$(meow_tarq_montar "$ajuste")" || return 1
  printf '%s\n\n%s' "$TARQ_BASE" "$extra"
}

meow_app_instalado() {
  meow_tem flatpak && [ -n "$(meow_flatpak_apps_libadwaita | head -n 1)" ]
}

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_tem flatpak || { meow_app_sem "libadwaita: o flatpak não está instalado"; return; }
  _LA_APPS="$(meow_flatpak_apps_libadwaita)"
  [ -n "$_LA_APPS" ] || { meow_app_sem "libadwaita: nenhum app Flatpak libadwaita instalado"; return; }
  meow_tarq_detectar libadwaita libadwaita
}

_la_cada() {
  local acao="$1" id desejado rcs=()
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    desejado="$(_la_desejado "$id")" || { meow_erro "libadwaita: o ajuste de $id não montou"; rcs+=("$MEOW_ERRO"); continue; }
    "meow_tarq_${acao}_um" "libadwaita: $id" "$(_la_destino "$id")" "$desejado"; rcs+=($?)
  done <<< "$_LA_APPS"
  meow_tarq_somar "${rcs[@]}"
}

meow_app_conferir() {
  local rc
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _la_cada conferir; rc=$?
  [ "$rc" = "$MEOW_OK" ] && meow_ok "libadwaita: $(printf '%s\n' "$_LA_APPS" | wc -l) app(s) já no tema do pack ($TARQ_QUERO)"
  return "$rc"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente libadwaita; return; }
  _la_cada aplicar
}

meow_app_reverter() {
  local arq rcs=() achou=0
  for arq in "$HOME"/.var/app/*/config/gtk-4.0/gtk.css; do
    meow_tarq_nosso "$arq" || continue
    achou=1
    meow_tarq_reverter_um "libadwaita: $(basename "$(dirname "$(dirname "$(dirname "$arq")")")")" "$arq"; rcs+=($?)
  done
  [ "$achou" = 1 ] || { meow_ok "libadwaita: nenhum gtk.css do MeowSystem no disco — nada a desfazer"; return "$MEOW_OK"; }
  meow_tarq_somar "${rcs[@]}"
}

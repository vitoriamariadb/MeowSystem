#!/usr/bin/env bash

. "$MEOW_RAIZ/lib/tema_arquivo.sh"

_OBS_ID="com.obsproject.Studio"
_OBS_TEMA_ID="com.obsproject.Yami.MeowSystem"

_obs_pastas() {
  if meow_tem flatpak && meow_flatpak_tem "$_OBS_ID"; then
    printf '%s\n' "$HOME/.var/app/$_OBS_ID/config/obs-studio"
  fi
  if meow_tem obs; then
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/obs-studio"
  fi
}

_obs_desejado() {
  local dark=false
  case "$TARQ_BASE" in *"dark: 'dark'"*) dark=true ;; esac
  printf '%s' "$TARQ_BASE" | sed "s/dark: '[a-z]*'/dark: '$dark'/"
}

meow_app_instalado() { [ -n "$(_obs_pastas)" ]; }

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "obs: não está instalado"; return; }
  meow_tarq_detectar obs obs
}

_obs_cada() {
  local acao="$1" pasta rcs=() desejado
  desejado="$(_obs_desejado)"
  while IFS= read -r pasta; do
    [ -n "$pasta" ] || continue
    "meow_tarq_${acao}_um" "obs" "$pasta/themes/MeowSystem.ovt" "$desejado"; rcs+=($?)
    "meow_tarq_chave_${acao}" "obs" "$pasta/user.ini" Appearance Theme "$_OBS_TEMA_ID"; rcs+=($?)
  done < <(_obs_pastas)
  meow_tarq_somar "${rcs[@]}"
}

meow_app_conferir() {
  local rc
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _obs_cada conferir; rc=$?
  [ "$rc" = "$MEOW_OK" ] && meow_ok "obs: já está no tema do pack ($TARQ_QUERO)"
  return "$rc"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente obs; return; }
  _obs_cada aplicar
}

meow_app_reverter() {
  local pasta rcs=()
  while IFS= read -r pasta; do
    [ -n "$pasta" ] || continue
    meow_tarq_chave_reverter obs "$pasta/user.ini" Appearance Theme "$_OBS_TEMA_ID"; rcs+=($?)
    meow_tarq_reverter_um obs "$pasta/themes/MeowSystem.ovt"; rcs+=($?)
  done < <(_obs_pastas)
  [ "${#rcs[@]}" -gt 0 ] || { meow_ok "obs: não está instalado — nada a desfazer"; return "$MEOW_OK"; }
  meow_tarq_somar "${rcs[@]}"
  local soma=$?
  [ "$soma" = "$MEOW_DIVERGENTE" ] && meow_app_desligar obs
  return "$soma"
}

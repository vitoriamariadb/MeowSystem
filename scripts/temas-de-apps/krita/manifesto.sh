#!/usr/bin/env bash

. "$MEOW_RAIZ/lib/tema_arquivo.sh"

_KR_ID="org.kde.krita"
_KR_NOME="MeowSystem"

_kr_alvos() {
  if meow_tem flatpak && meow_flatpak_tem "$_KR_ID"; then
    printf '%s\t%s\n' "$HOME/.var/app/$_KR_ID/data/krita/color-schemes/$_KR_NOME.colors" "$HOME/.var/app/$_KR_ID/config/kritarc"
  fi
  if meow_tem krita; then
    printf '%s\t%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/krita/color-schemes/$_KR_NOME.colors" "${XDG_CONFIG_HOME:-$HOME/.config}/kritarc"
  fi
}

meow_app_instalado() { [ -n "$(_kr_alvos)" ]; }

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "krita: não está instalado"; return; }
  meow_tarq_detectar krita krita
}

_kr_cada() {
  local acao="$1" esquema rc rcs=()
  while IFS=$'\t' read -r esquema rc; do
    [ -n "$esquema" ] || continue
    "meow_tarq_${acao}_um" "krita" "$esquema" "$TARQ_BASE"; rcs+=($?)
    "meow_tarq_chave_${acao}" "krita" "$rc" theme Theme "$_KR_NOME"; rcs+=($?)
  done < <(_kr_alvos)
  meow_tarq_somar "${rcs[@]}"
}

meow_app_conferir() {
  local rc
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _kr_cada conferir; rc=$?
  [ "$rc" = "$MEOW_OK" ] && meow_ok "krita: já está no tema do pack ($TARQ_QUERO)"
  return "$rc"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente krita; return; }
  _kr_cada aplicar
}

meow_app_reverter() {
  local esquema rc rcs=()
  while IFS=$'\t' read -r esquema rc; do
    [ -n "$esquema" ] || continue
    meow_tarq_chave_reverter krita "$rc" theme Theme "$_KR_NOME"; rcs+=($?)
    meow_tarq_reverter_um krita "$esquema"; rcs+=($?)
  done < <(_kr_alvos)
  [ "${#rcs[@]}" -gt 0 ] || { meow_ok "krita: não está instalado — nada a desfazer"; return "$MEOW_OK"; }
  meow_tarq_somar "${rcs[@]}"
}

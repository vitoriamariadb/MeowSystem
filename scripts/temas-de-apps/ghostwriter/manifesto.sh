#!/usr/bin/env bash

. "$MEOW_RAIZ/scripts/lib/tema_arquivo.sh"

_GW_ID="org.kde.ghostwriter"
_GW_NOME="MeowSystem"

_gw_alvos() {
  if meow_tem flatpak && meow_flatpak_tem "$_GW_ID"; then
    printf '%s\t%s\n' "$HOME/.var/app/$_GW_ID/data/ghostwriter/themes/$_GW_NOME.json" "$HOME/.var/app/$_GW_ID/config/kde.org/ghostwriter.conf"
  fi
  if meow_tem ghostwriter; then
    printf '%s\t%s\n' "${XDG_DATA_HOME:-$HOME/.local/share}/ghostwriter/themes/$_GW_NOME.json" "${XDG_CONFIG_HOME:-$HOME/.config}/kde.org/ghostwriter.conf"
  fi
}

meow_app_instalado() { [ -n "$(_gw_alvos)" ]; }

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "ghostwriter: não está instalado"; return; }
  meow_tarq_detectar ghostwriter ghostwriter
}

_gw_escolha() {
  case "$(meow_tarq_ini pegar "$1" Style theme x)" in
    "$_GW_NOME") printf 'igual' ;;
    ""|Classic|"Classic Light") printf 'ausente' ;;
    *) printf 'alheio' ;;
  esac
}

_gw_escolha_conferir() {
  local conf="$1"
  case "$(_gw_escolha "$conf")" in
    igual) return "$MEOW_OK" ;;
    ausente) meow_muda "ghostwriter: theme=$_GW_NOME falta em $conf"; return "$MEOW_DIVERGENTE" ;;
    alheio) meow_pula "ghostwriter: $conf escolhe outro tema em theme — trocar é decisão sua"; return "$MEOW_SEM_DEPENDENCIA" ;;
  esac
}

_gw_escolha_aplicar() {
  local conf="$1" novo rc
  case "$(_gw_escolha "$conf")" in
    igual) return "$MEOW_OK" ;;
    alheio) meow_pula "ghostwriter: $conf escolhe outro tema em theme — trocar é decisão sua"; return "$MEOW_SEM_DEPENDENCIA" ;;
  esac
  novo="$(meow_tarq_ini por "$conf" Style theme "$_GW_NOME")" || { meow_erro "ghostwriter: não montei $conf"; return "$MEOW_ERRO"; }
  meow_tarq_escrever "$conf" "$novo"; rc=$?
  [ "$rc" = "$MEOW_ERRO" ] && { meow_erro "ghostwriter: falhou ao escrever $conf"; return "$MEOW_ERRO"; }
  return "$rc"
}

_gw_cada() {
  local acao="$1" tema conf rcs=()
  while IFS=$'\t' read -r tema conf; do
    [ -n "$tema" ] || continue
    "meow_tarq_${acao}_um" "ghostwriter" "$tema" "$TARQ_BASE"; rcs+=($?)
    [ "$(meow_tarq_estado "$tema" "$TARQ_BASE")" = alheio ] && continue
    "_gw_escolha_${acao}" "$conf"; rcs+=($?)
  done < <(_gw_alvos)
  meow_tarq_somar "${rcs[@]}"
}

meow_app_conferir() {
  local rc
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _gw_cada conferir; rc=$?
  [ "$rc" = "$MEOW_OK" ] && meow_ok "ghostwriter: já está no tema do pack ($TARQ_QUERO)"
  return "$rc"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente ghostwriter; return; }
  _gw_cada aplicar
}

meow_app_reverter() {
  local tema conf rcs=() soma
  while IFS=$'\t' read -r tema conf; do
    [ -n "$tema" ] || continue
    meow_tarq_chave_reverter ghostwriter "$conf" Style theme "$_GW_NOME"; rcs+=($?)
    meow_tarq_reverter_um ghostwriter "$tema"; rcs+=($?)
  done < <(_gw_alvos)
  [ "${#rcs[@]}" -gt 0 ] || { meow_ok "ghostwriter: não está instalado — nada a desfazer"; return "$MEOW_OK"; }
  meow_tarq_somar "${rcs[@]}"
  soma=$?
  [ "$soma" = "$MEOW_DIVERGENTE" ] && meow_app_desligar ghostwriter
  return "$soma"
}

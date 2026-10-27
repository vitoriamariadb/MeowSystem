#!/usr/bin/env bash

. "$MEOW_RAIZ/lib/tema_arquivo.sh"

_WF_ID="net.waterfox.waterfox"
_WF_PREF='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true); // meowsystem-tema'

_wf_raizes() {
  printf '%s\n' "$HOME/.waterfox"
  printf '%s\n' "$HOME/.var/app/$_WF_ID/.waterfox"
}

_wf_perfis() {
  local raiz ini
  while IFS= read -r raiz; do
    ini="$raiz/profiles.ini"
    [ -f "$ini" ] || continue
    awk -F= -v raiz="$raiz" '
      function fecha() { if (caminho != "") print (relativo == "0" ? caminho : raiz "/" caminho); caminho = ""; relativo = "1" }
      /^\[/ { fecha(); perfil = ($0 ~ /^\[Profile/); next }
      perfil && $1 == "Path" { caminho = substr($0, 6) }
      perfil && $1 == "IsRelative" { relativo = $2 }
      END { fecha() }' "$ini"
  done < <(_wf_raizes) | sort -u
}

meow_app_instalado() {
  { meow_tem flatpak && meow_flatpak_tem "$_WF_ID"; } || meow_tem waterfox || [ -n "$(_wf_perfis | head -n 1)" ]
}

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "waterfox: não está instalado"; return; }
  [ -n "$(_wf_perfis | head -n 1)" ] || { meow_app_sem "waterfox: nenhum perfil em profiles.ini ainda — abra o Waterfox uma vez"; return; }
  meow_tarq_detectar waterfox waterfox
}

_wf_pref_tem() { [ -f "$1/user.js" ] && grep -qF 'toolkit.legacyUserProfileCustomizations.stylesheets", true' "$1/user.js"; }

_wf_pref_conferir() {
  _wf_pref_tem "$1" && return "$MEOW_OK"
  meow_muda "waterfox: falta ligar o userChrome.css em $1/user.js"
  return "$MEOW_DIVERGENTE"
}

_wf_pref_aplicar() {
  local perfil="$1" atual="" rc
  _wf_pref_tem "$perfil" && return "$MEOW_OK"
  [ -f "$perfil/user.js" ] && atual="$(cat "$perfil/user.js")"
  meow_tarq_escrever "$perfil/user.js" "${atual:+$atual$'\n'}$_WF_PREF"; rc=$?
  [ "$rc" = "$MEOW_ERRO" ] && meow_erro "waterfox: falhou ao escrever $perfil/user.js"
  return "$rc"
}

_wf_pref_reverter() {
  local perfil="$1" novo
  [ -f "$perfil/user.js" ] && grep -qF "$_WF_PREF" "$perfil/user.js" || return "$MEOW_OK"
  if meow_seco; then meow_muda "waterfox: tiraria a linha do MeowSystem de $perfil/user.js"; return "$MEOW_DIVERGENTE"; fi
  novo="$(grep -vF "$_WF_PREF" "$perfil/user.js")"
  if [ -z "$novo" ]; then rm -f -- "$perfil/user.js"; else meow_tarq_escrever "$perfil/user.js" "$novo" >/dev/null; fi
  return "$MEOW_DIVERGENTE"
}

_wf_cada() {
  local acao="$1" perfil rcs=()
  while IFS= read -r perfil; do
    [ -n "$perfil" ] || continue
    "meow_tarq_${acao}_um" "waterfox" "$perfil/chrome/userChrome.css" "$TARQ_BASE"; rcs+=($?)
    "_wf_pref_${acao}" "$perfil"; rcs+=($?)
  done < <(_wf_perfis)
  meow_tarq_somar "${rcs[@]}"
}

meow_app_conferir() {
  local rc
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _wf_cada conferir; rc=$?
  [ "$rc" = "$MEOW_OK" ] && meow_ok "waterfox: já está no tema do pack ($TARQ_QUERO)"
  return "$rc"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente waterfox; return; }
  _wf_cada aplicar
}

meow_app_reverter() {
  local perfil rcs=()
  while IFS= read -r perfil; do
    [ -n "$perfil" ] || continue
    meow_tarq_reverter_um waterfox "$perfil/chrome/userChrome.css"; rcs+=($?)
    _wf_pref_reverter "$perfil"; rcs+=($?)
  done < <(_wf_perfis)
  [ "${#rcs[@]}" -gt 0 ] || { meow_ok "waterfox: nenhum perfil — nada a desfazer"; return "$MEOW_OK"; }
  meow_tarq_somar "${rcs[@]}"
}

#!/usr/bin/env bash

_TG_APP="org.telegram.desktop"
_TG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/temas-de-apps/telegram"
_TG_ARQ="$_TG_DIR/MeowSystem.tdesktop-theme"
_TG_MODELO_PY="$MEOW_RAIZ/scripts/temas-de-apps/modelo.py"

_tg_instalado() {
  meow_flatpak_tem "$_TG_APP" || meow_tem telegram-desktop || meow_tem Telegram \
    || [ -x /snap/bin/telegram-desktop ]
}

_tg_marca() {
  sed -n 's|^// meowsystem-tema: \([^ ]*\).*$|\1|p' "$1" 2>/dev/null | head -n 1
}

_tg_no_ar() {
  _TG_NO_AR=""; _TG_NOSSO=0
  [ -f "$_TG_ARQ" ] || return 0
  _TG_NO_AR="$(_tg_marca "$_TG_ARQ")"
  if [ -n "$_TG_NO_AR" ]; then _TG_NOSSO=1; else _TG_NO_AR="$_TG_ARQ"; fi
}

meow_app_instalado() { _tg_instalado; }

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "Telegram: não está instalado"; return; }
  meow_tem python3 || { meow_app_sem "Telegram: falta python3, que monta o tema com a paleta do pack"; return; }
  meow_app_tema_do_pack telegram.arquivo
  _TG_DE="$MEOW_APP_TEMA_PACK"
  [ -n "$MEOW_APP_TEMA" ] || { meow_app_sem "Telegram: o pack no ar não declara tema para o Telegram"; return; }
  _TG_QUERO="$_TG_DE/${FLAVOR:-}"
  _TG_DESEJADO="$(python3 "$_TG_MODELO_PY" "$MEOW_APP_TEMA" "$(meow_paleta)" "${FLAVOR:-}" "$_TG_DE" 2>&1)" \
    || { meow_app_sem "Telegram: o modelo do pack $_TG_DE não montou — $_TG_DESEJADO"; return; }
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _tg_no_ar
  if [ "$_TG_NOSSO" != 1 ]; then
    if [ -z "$_TG_NO_AR" ]; then
      meow_muda "Telegram: o tema do pack ainda não foi entregue ($_TG_ARQ)"
      return "$MEOW_DIVERGENTE"
    fi
    meow_pula "Telegram: há em $_TG_ARQ um arquivo que não veio daqui — não é tocado"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ "$(cat "$_TG_ARQ")" != "$_TG_DESEJADO" ]; then
    meow_muda "Telegram: o arquivo entregue é '$_TG_NO_AR', e o de agora é '$_TG_QUERO' (ou o modelo mudou)"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "Telegram: o tema do pack (do pack $_TG_DE) está entregue — $_TG_QUERO; aplicar é abri-lo no Telegram"
  return "$MEOW_OK"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente telegram; return; }
  _tg_no_ar
  if [ "$_TG_NOSSO" = 1 ]; then
    [ "$_TG_NO_AR" = "$_TG_QUERO" ] \
      || meow_muda "Telegram: o arquivo do MeowSystem estava em '$_TG_NO_AR' — passa a '$_TG_QUERO'"
  elif [ -z "$_TG_NO_AR" ]; then
    meow_pendencia_resolvida telegram-tema-de-terceiro
    meow_info "Telegram: o arquivo do tema do pack ainda não foi entregue — monto (do pack $_TG_DE)"
  else
    meow_app_tema_no_ar telegram "$_TG_NO_AR" "$_TG_QUERO" "$_TG_DE" pergunte
    [ $? = "$MEOW_DIVERGENTE" ] || return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_escrever "$_TG_ARQ" "$_TG_DESEJADO" 644
  case $? in
    0) meow_pendencia_resolvida telegram-tema-de-terceiro
       meow_ok "Telegram: o arquivo do tema do pack já está entregue (do pack $_TG_DE) — $_TG_QUERO"
       return "$MEOW_OK" ;;
    2) meow_erro "Telegram: falhou ao escrever $_TG_ARQ"; return "$MEOW_ERRO" ;;
  esac
  meow_seco && return "$MEOW_DIVERGENTE"
  meow_ok "Telegram: tema do pack montado em $_TG_ARQ"
  meow_info "o Telegram não aplica tema sozinho: abra esse arquivo nele (dois cliques no"
  meow_info "  arquivo, ou mande-o para as Mensagens Salvas e toque nele) e confirme a prévia"
  return "$MEOW_DIVERGENTE"
}

meow_app_reverter() {
  local marca; marca="$(_tg_marca "$_TG_ARQ")"
  if [ -z "$marca" ]; then
    meow_ok "Telegram: nenhum arquivo de tema do MeowSystem no disco — nada a desfazer"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "Telegram: tiraria $_TG_ARQ ($marca)"
    return "$MEOW_DIVERGENTE"
  fi
  rm -f -- "$_TG_ARQ" || { meow_erro "Telegram: não consegui tirar $_TG_ARQ"; return "$MEOW_ERRO"; }
  rmdir -- "$_TG_DIR" 2>/dev/null || true
  meow_ok "Telegram: o arquivo do tema do pack saiu"
  meow_info "se você aplicou o tema no Telegram, ele fica lá até você escolher outro nas configurações do app"
  meow_info "tire 'telegram' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}

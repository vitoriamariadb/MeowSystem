#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ORIGEM="$RAIZ/systemd"
DESTINO="$HOME/.config/systemd/user"
UNIDADES=(meow-derivados.service meow-derivados.path)
GATILHO="meow-derivados.path"

CONFERIR=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

_texto_de() {
  local u="$1" texto linhas
  texto="$(cat "$ORIGEM/$u" 2>/dev/null)" || return 1
  if [ "$u" = "$GATILHO" ]; then
    linhas="$("$RAIZ/scripts/derivados.sh" --pastas | sed -e 's/%/%%/g' -e 's/^/PathModified=/')"
    [ -n "$linhas" ] || return 1
    texto="$(awk -v linhas="$linhas" '$0 == "@VIGIADOS@" { print linhas; next } { print }' <<<"$texto")"
  fi
  printf '%s' "$texto"
}

_tem_systemd() { meow_tem systemctl && [ -d "/run/user/$(id -u)/systemd" ]; }
_ligado() {
  [ "$(systemctl --user is-enabled "$GATILHO" 2>/dev/null)" = "enabled" ] &&
  [ "$(systemctl --user is-active  "$GATILHO" 2>/dev/null)" = "active" ]
}

if ! _tem_systemd; then
  meow_pula "sem systemd --user nesta sessão — o vigia dos desenhos fica para o login"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

divergentes=0
for u in "${UNIDADES[@]}"; do
  texto="$(_texto_de "$u")" || { meow_erro "não consegui montar $u"; exit "$MEOW_ERRO"; }
  [ "$texto" = "$(cat "$DESTINO/$u" 2>/dev/null)" ] || divergentes=$((divergentes + 1))
done

if [ "$CONFERIR" = 1 ]; then
  if [ "$divergentes" != 0 ]; then
    meow_muda "vigia dos desenhos: $divergentes unidade(s) a instalar ou atualizar"; exit "$MEOW_DIVERGENTE"
  fi
  if [ "$(systemctl --user is-failed "$GATILHO" 2>/dev/null)" = "failed" ] || ! _ligado; then
    meow_muda "o $GATILHO não está ligado"; exit "$MEOW_DIVERGENTE"
  fi
  meow_ok "vigiando os desenhos dos packs — o tema se atualiza sozinho"
  exit "$MEOW_OK"
fi

mudou=0
for u in "${UNIDADES[@]}"; do
  texto="$(_texto_de "$u")" || { meow_erro "não consegui montar $u"; exit "$MEOW_ERRO"; }
  meow_escrever "$DESTINO/$u" "$texto" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "não consegui instalar $u"; exit "$MEOW_ERRO" ;; esac
done
[ "$mudou" = 1 ] && systemctl --user daemon-reload
if [ "$(systemctl --user is-failed "$GATILHO" 2>/dev/null)" = "failed" ]; then
  systemctl --user reset-failed "$GATILHO" meow-derivados.service >/dev/null 2>&1; mudou=1
fi
if [ "$mudou" = 1 ] && _ligado; then
  systemctl --user restart "$GATILHO" >/dev/null 2>&1
elif ! _ligado; then
  systemctl --user enable --now "$GATILHO" >/dev/null 2>&1 \
    || { meow_erro "não consegui ligar o $GATILHO"; exit "$MEOW_ERRO"; }
  mudou=1
fi
if [ "$mudou" = 1 ]; then
  meow_muda "vigia dos desenhos ligado: $(grep -c '^PathModified=' "$DESTINO/$GATILHO") pasta(s)"
  exit "$MEOW_DIVERGENTE"
fi
meow_ok "vigiando os desenhos dos packs — o tema se atualiza sozinho"
exit "$MEOW_OK"

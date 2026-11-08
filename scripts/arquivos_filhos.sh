#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

PASTA="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/app-com.system76.CosmicFiles@.service.d"
DROPIN="$PASTA/meowsystem-filhos-sobrevivem.conf"
TEXTO=$'[Service]\nKillMode=process'

CONFERIR=0
case "${1:-aplicar}" in
  --conferir|conferir) CONFERIR=1 ;;
  aplicar|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [aplicar|--conferir]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

if [ -f "$DROPIN" ] && [ "$(cat "$DROPIN")" = "$TEXTO" ]; then
  meow_ok "o que o Arquivos abre sobrevive quando ele fecha"
  exit "$MEOW_OK"
fi

if [ "$CONFERIR" = 1 ]; then
  meow_muda "escreveria $DROPIN (KillMode=process)"
  exit "$MEOW_DIVERGENTE"
fi

mkdir -p "$PASTA" || { meow_erro "não consegui criar $PASTA"; exit "$MEOW_ERRO"; }
printf '%s\n' "$TEXTO" > "$DROPIN" || { meow_erro "não consegui escrever $DROPIN"; exit "$MEOW_ERRO"; }
meow_manifesto_registrar "$DROPIN"
meow_tem systemctl && systemctl --user daemon-reload >/dev/null 2>&1
meow_ok "o que o Arquivos abre sobrevive quando ele fecha (vale no próximo Arquivos aberto)"
exit "$MEOW_DIVERGENTE"

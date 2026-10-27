#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
for b in sudo pkexec pkill cosmic-bg; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/desbanir.sh\\n" >&2\nexit 1\n' "$b" > "$FALSO/$b"
  chmod 755 "$FALSO/$b"
done

CASA="$T/casa"
BASE="$CASA/.local/share/backgrounds/meowsystem"
AT="$BASE/ativos"; BAN="$BASE/banidos"
mkdir -p "$AT" "$BAN" "$T/estado"
png() { printf '\x89PNG\r\n\x1a\n%s\n' "$2" > "$1"; }
png "$BAN/so-em-banidos.png" banida
png "$AT/de-fabrica.png" fabrica
png "$AT/outra.png" outra
LISTA="$T/BANIDOS.txt"
printf '# recusadas\nso-em-banidos.png\nde-fabrica.png\nsumida.png\n' > "$LISTA"

papel() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$T/estado" MEOW_IGNORA_DESKTOP=1 \
    WALLPAPER_BANIDOS="$LISTA" WALLPAPER_NOITE=nao "$@"
}
na_lista() { grep -qxF -- "$1" "$LISTA"; }

s1="$(papel bash "$RAIZ/scripts/wallpaper.sh" desbanir so-em-banidos.png 2>&1)"; rc1=$?
if [ "$rc1" != 2 ] && [ -f "$AT/so-em-banidos.png" ] && [ -f "$BAN/so-em-banidos.png" ] \
   && ! na_lista so-em-banidos.png; then
  ok "em banidos/: volta para ativos/, a cópia de banidos/ fica e o nome sai da lista"
else
  falha "o desbanir de banidos/ não devolveu a foto (rc=$rc1)" "$s1"
fi

s2="$(papel bash "$RAIZ/scripts/wallpaper.sh" desbanir de-fabrica.png 2>&1)"; rc2=$?
if [ "$rc2" != 2 ] && [ -f "$AT/de-fabrica.png" ] && [ ! -e "$BAN/de-fabrica.png" ] \
   && ! na_lista de-fabrica.png && na_lista sumida.png; then
  ok "só na lista, com a foto em ativos/: sai só a linha, e a foto fica onde está"
else
  falha "o desbanir da foto de fábrica recusou ou mexeu no que não devia (rc=$rc2)" "$s2
lista: $(cat "$LISTA")"
fi

antes="$(cat "$LISTA"; ls -1A "$AT" "$BAN")"
s3="$(papel bash "$RAIZ/scripts/wallpaper.sh" desbanir sumida.png 2>&1)"; rc3=$?
if [ "$rc3" = 2 ] && [ "$antes" = "$(cat "$LISTA"; ls -1A "$AT" "$BAN")" ] && [[ "$s3" == *"não achei"* ]]; then
  ok "em lugar nenhum: recusa, e nada muda"
else
  falha "o desbanir sem foto não recusou, ou mudou alguma coisa (rc=$rc3)" "$s3"
fi

[ "$falhas" = 0 ] || { printf '%d falha(s)\n' "$falhas" >&2; exit 1; }
printf 'desbanir: tudo ok\n'

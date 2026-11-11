#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }

printf '\ncarregar o lib/comum.sh sai 0 em todo modo, porque todo script faz «. comum.sh && …»\n'
for modo in "normal" "MEOW_SO_LE=1" "MEOW_DRY_RUN=1"; do
  extra=(); [ "$modo" = normal ] || extra=("$modo")
  env -i PATH="/usr/bin:/bin" HOME="$T" MEOW_RAIZ="$RAIZ" "${extra[@]}" bash -c '. "$MEOW_RAIZ/lib/comum.sh"' >/dev/null 2>&1; rc=$?
  [ "$rc" = 0 ] && ok "$modo: sai 0" || falha "$modo: o source saiu $rc"
done
[ -z "$(find "$T" -mindepth 1 -print -quit)" ] && ok "e nenhum modo escreve no HOME" || falha "o source escreveu no HOME: $(find "$T" -mindepth 1 | head -3)"

printf '\n'
[ "$falhas" = 0 ] && { printf 'comum-carrega-limpo: tudo verde\n'; exit 0; }
printf 'comum-carrega-limpo: %s falha(s)\n' "$falhas"; exit 1

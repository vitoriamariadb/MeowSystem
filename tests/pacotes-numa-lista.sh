#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }
LISTA="$RAIZ/assets/pacotes/sistema.tsv"

printf '\na lista de pacotes do sistema mora num arquivo só\n'
[ -s "$LISTA" ] && ok "assets/pacotes/sistema.tsv existe" || falha "falta assets/pacotes/sistema.tsv"
awk -F'\t' 'NF != 2 || $1 == "" || $2 == "" {exit 1}' "$LISTA" && ok "cada linha é comando e pacote" || falha "linha fora do formato comando<TAB>pacote"
grep -q 'assets/pacotes/sistema.tsv' "$RAIZ/install.sh" && ok "o install lê a lista" || falha "o install não lê a lista"
! grep -q 'NECESSARIOS' "$RAIZ/install.sh" && ok "e não guarda outra cópia dela" || falha "o install ainda tem a lista própria"
grep -q 'cut -f2 assets/pacotes/sistema.tsv' "$RAIZ/.github/workflows/testes.yml" && ok "o CI instala a mesma lista" || falha "o CI tem a lista dele"

printf '\no .deb depende de tudo o que a lista pede (a ponte, o tests/doctor-veredito.sh confere)\n'
depende="$(sed -n 's/^Depends: //p' "$RAIZ/packaging/deb/control" | tr -d ' ' | tr ',' '\n' | sed 's/(.*//')"
while IFS=$'\t' read -r _ p; do
  [ -n "$p" ] || continue
  grep -qx "$p" <<< "$depende" && ok "o .deb depende de $p" || falha "o .deb não depende de $p"
done < "$LISTA"

printf '\n'
[ "$falhas" = 0 ] && { printf 'pacotes-numa-lista: tudo verde\n'; exit 0; }
printf 'pacotes-numa-lista: %s falha(s)\n' "$falhas"; exit 1

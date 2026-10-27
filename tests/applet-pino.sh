#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

PINO="$(sed -n 's/^LIBCOSMIC="\(.*\)"/\1/p' "$RAIZ/assets/extensoes/leitura.pino")"
[ -n "$PINO" ] || { echo "applet-pino: não li o pino de assets/extensoes/leitura.pino"; exit 1; }
OUTRA="0000000000000000000000000000000000000abc"
lock_painel() { printf '[[package]]\nname = "libcosmic"\nversion = "1.0.0"\nsource = "git+https://github.com/pop-os/libcosmic#%s"\n' "$1" > "$T/painel.lock"; }

mkdir -p "$T/bin" "$T/lar"

AP() { HOME="$T/lar" MEOW_ESTADO="$T/lar/estado" AP_LOCK_PAINEL="$T/painel.lock" "$RAIZ/scripts/applet_pino.sh" "$@" 2>/dev/null; }

echo "== a regra do alvo"
lock_painel "$OUTRA"
igual "sem base, o painel fora do pino: o pino (adoção; ninguém recompila só porque a regra chegou)" "$(AP alvo leitura "$PINO")" "$PINO"
rm -rf "$T/lar/estado"
lock_painel "$PINO"
igual "sem base, painel no pino: o pino" "$(AP alvo leitura "$PINO")" "$PINO"
igual "idem para a mídia" "$(AP alvo now-playing "$PINO")" "$PINO"
lock_painel "$OUTRA"
igual "o painel andou depois da base: alvo é a do painel" "$(AP alvo leitura "$PINO")" "$OUTRA"
AP falhou leitura "$OUTRA"
igual "a do painel já falhou: alvo volta ao pino" "$(AP alvo leitura "$PINO")" "$PINO"
igual "a falha é por applet: a mídia segue o painel" "$(AP alvo now-playing "$PINO")" "$OUTRA"
rm -rf "$T/lar/estado"

echo "== conferir não escreve"
rm -rf "$T/lar2"; mkdir -p "$T/lar2"
HOME="$T/lar2" MEOW_ESTADO="$T/lar2/estado" AP_LOCK_PAINEL="$T/painel.lock" "$RAIZ/scripts/applet_pino.sh" conferir >/dev/null 2>&1
HOME="$T/lar2" PATH="$T/bin:$PATH" MEOW_ESTADO="$T/lar2/estado" AP_LOCK_PAINEL="$T/painel.lock" \
  MEOW_IGNORA_DESKTOP=1 EXTENSOES=now-playing,leitura "$RAIZ/scripts/extensoes_build.sh" --todas --conferir >/dev/null 2>&1
igual "o HOME de brinquedo continua vazio" "$(find "$T/lar2" -type f | wc -l)" 0

echo
if [ "$falhas" = 0 ]; then echo "applet-pino: tudo certo"; exit 0; fi
echo "applet-pino: $falhas falha(s)"; exit 1

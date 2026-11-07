#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

printf '{"flavors": {"mocha": {"mauve": "#cba6f7", "pink": "#f5c2e7"}}}' > "$T/paleta.json"
mkdir -p "$T/estado"

lido() {
  env -i PATH="/usr/bin:/bin" HOME="$T/casa" MEOW_COSMIC_DIR="$T/casa/.config/cosmic" MEOW_COSMIC_SISTEMA="$T/sistema" \
    MEOW_ESTADO="$T/estado" MEOW_RAIZ="$RAIZ" MEOW_PALETA="$T/paleta.json" PYTHONDONTWRITEBYTECODE=1 \
    python3 -I - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
print("flavor=%s" % servidor._flavor_na_tela())
print("acento=%s" % servidor._acento_na_tela("mocha"))
PY
}

semear() {
  rm -rf "$T/casa" "$T/sistema"
  local c="$T/casa/.config/cosmic"
  mkdir -p "$c/com.system76.CosmicTheme.Mode/$1" "$c/com.system76.CosmicTheme.Dark.Builder/$2"
  printf true > "$c/com.system76.CosmicTheme.Mode/$1/is_dark"
  printf '(name: "dracula-mocha")' > "$c/com.system76.CosmicTheme.Dark.Builder/$2/palette"
  printf 'Some("#CBA6F7")' > "$c/com.system76.CosmicTheme.Dark.Builder/$2/accent"
}

printf '\n--- o painel lê o esquema da versão que o sistema traz ---\n'
semear v2 v3
mkdir -p "$T/sistema/com.system76.CosmicTheme.Mode/v1" "$T/sistema/com.system76.CosmicTheme.Mode/v2" \
  "$T/sistema/com.system76.CosmicTheme.Dark.Builder/v1" "$T/sistema/com.system76.CosmicTheme.Dark.Builder/v2" \
  "$T/sistema/com.system76.CosmicTheme.Dark.Builder/v3"
saida="$(lido)"
grep -qx 'flavor=mocha' <<< "$saida" && ok "com Mode/v2 e Builder/v3 no sistema, o flavor sai da tela" || falha "flavor não veio de Mode/v2 e Builder/v3: $saida"
grep -qx 'acento=mauve' <<< "$saida" && ok "e o acento também" || falha "acento não veio de Builder/v3: $saida"

printf '\n--- sem o pacote do sistema, cada esquema cai no padrão dos escritores ---\n'
semear v1 v2
saida="$(lido)"
grep -qx 'flavor=mocha' <<< "$saida" && grep -qx 'acento=mauve' <<< "$saida" \
  && ok "sem pasta no sistema: Mode/v1 e Builder/v2" || falha "o padrão não foi Mode/v1 e Builder/v2: $saida"

printf '\n--- a versão antiga não vale quando a nova existe ---\n'
semear v2 v3
mkdir -p "$T/sistema/com.system76.CosmicTheme.Mode/v2" "$T/sistema/com.system76.CosmicTheme.Dark.Builder/v3"
c="$T/casa/.config/cosmic"
mkdir -p "$c/com.system76.CosmicTheme.Mode/v1" "$c/com.system76.CosmicTheme.Dark.Builder/v2"
printf false > "$c/com.system76.CosmicTheme.Mode/v1/is_dark"
printf '(name: "dracula-outra")' > "$c/com.system76.CosmicTheme.Dark.Builder/v2/palette"
saida="$(lido)"
grep -qx 'flavor=mocha' <<< "$saida" && ok "o v1 e o v2 velhos não atravessam o v2 e o v3 novos" || falha "leu a versão velha: $saida"

printf '\n'
[ "$falhas" -eq 0 ] || { printf '%d falha(s)\n' "$falhas" >&2; exit 1; }
printf 'passou: o painel lê o esquema do tema como os escritores\n'

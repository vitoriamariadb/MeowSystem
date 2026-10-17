#!/usr/bin/env bash
# tests/miudos-do-install.sh — os dois miúdos do install real de 17/10.
#
#   1. `meow compositor` que compilou e guardou o build sai 0: sucesso que
#      escreveu é sucesso (o 1 virava «falhou» na tela de quem rodou).
#   2. a linha `iconesapps` do doctor nunca sai vazia: com um pack que não usa
#      o acervo Catppuccin de aplicativos, o verificador diz isso.
#
# HOME, cache e fonte de brinquedo; dpkg-query, make, cargo e patch falsos (o
# make só cria o binário dentro do brinquedo); sudo recusa. Nada vai à rede.
#
# 0 = passou · 1 = falhou · 2 = erro deste teste
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT
falhas=0
reclamar() { printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas + 1)); }

mkdir -p "$TMP/falso" "$TMP/casa/.config/meow" "$TMP/cache/cosmic-comp-1.0~teste/src"
for c in sudo pkexec su apt apt-get curl wget; do
  printf '#!/bin/sh\nexit 1\n' > "$TMP/falso/$c"; chmod 755 "$TMP/falso/$c"
done
printf '#!/bin/sh\nprintf "1.0~teste"\n' > "$TMP/falso/dpkg-query"
printf '#!/bin/sh\nexit 0\n' > "$TMP/falso/cargo"
printf '#!/bin/sh\nexit 0\n' > "$TMP/falso/patch"
cat > "$TMP/falso/make" <<'FIM'
#!/bin/sh
mkdir -p target/release && printf 'binario de brinquedo\n' > target/release/cosmic-comp
FIM
chmod 755 "$TMP/falso/"*
fonte="$TMP/cache/cosmic-comp-1.0~teste"
printf '[package]\nname = "cosmic-comp"\n' > "$fonte/Cargo.toml"
printf 'all:\n\ttrue\n' > "$fonte/Makefile"
: > "$TMP/serie-vazia"

saida="$(env -i PATH="$TMP/falso:$PATH" HOME="$TMP/casa" NO_COLOR=1 \
  CP_CACHE="$TMP/cache" CP_SERIE="$TMP/serie-vazia" CP_GUARDA="$TMP/guarda" \
  CP_CASA="$TMP/casa/.local/libexec/meow/cosmic-comp" CP_SHIM="$TMP/casa/.local/bin/cosmic-comp" \
  bash "$RAIZ/scripts/compositor_patches.sh" compilar 2>&1)"; rc=$?
if [ ! -f "$TMP/casa/.local/libexec/meow/cosmic-comp/1.0~teste/cosmic-comp" ]; then
  reclamar "o build de brinquedo não foi guardado (o teste não prova nada)\n$saida"
elif [ "$rc" != "0" ]; then
  reclamar "o compositor compilou e guardou o build e saiu $rc (esperado 0)\n$saida"
else
  printf 'ok: compilou, guardou e saiu 0\n'
fi

printf 'PACK="dracula"\n' > "$TMP/casa/.config/meow/meow.conf"
saida="$(env -i PATH="$TMP/falso:$PATH" HOME="$TMP/casa" NO_COLOR=1 \
  MEOW_CONF="$TMP/casa/.config/meow/meow.conf" ICONES_TEMA=MeowSystem-Icons FLAVOR=dracula \
  bash "$RAIZ/scripts/icones_apps.sh" --conferir 2>&1)"; rc=$?
if [ -z "$(printf '%s' "$saida" | tr -d '[:space:]')" ]; then
  reclamar "com o Dracula no ar o verificador dos aplicativos Catppuccin saiu $rc sem uma palavra (a linha vazia do doctor)"
else
  printf 'ok: o verificador diz por que não confere: %s\n' "$(printf '%s' "$saida" | tail -1 | sed 's/^ *//')"
fi

[ "$falhas" = "0" ] || exit 1

#!/usr/bin/env bash
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

cp "$RAIZ/meow.conf.exemplo" "$TMP/casa/.config/meow/meow.conf"
sed -i 's/^PACK=.*/PACK="dracula"/; s/^FLAVOR=.*/FLAVOR="dracula"/' "$TMP/casa/.config/meow/meow.conf"
kill() { [ "${1:-}" = "-0" ] && { builtin kill "$@"; return; }; return 1; }
pkill() { return 1; }
killall() { return 1; }
export -f kill pkill killall
saida="$(env -u DBUS_SESSION_BUS_ADDRESS PATH="$TMP/falso:$PATH" HOME="$TMP/casa" NO_COLOR=1 \
  MEOW_RAIZ="$RAIZ" MEOW_PONTE="$TMP/sem-ponte" bash "$RAIZ/bin/meow" doctor 2>&1)"
vazias="$(printf '%s\n' "$saida" | grep -E '^  (ok|~~|--|!!|erro) +[a-z0-9_]+ *$')"
if ! grep -qE '^  [^ ]+ +arcticons ' <<< "$saida"; then
  reclamar "o doctor não chegou à linha arcticons (o teste não prova nada)\n$(printf '%s\n' "$saida" | tail -5)"
elif [ -n "$vazias" ]; then
  reclamar "linha do doctor sem texto:\n$vazias"
else
  printf 'ok: nenhuma linha do doctor sai vazia: %s\n' "$(printf '%s\n' "$saida" | grep -E '^  [^ ]+ +arcticons ' | sed 's/^ *//')"
fi

[ "$falhas" = "0" ] || exit 1

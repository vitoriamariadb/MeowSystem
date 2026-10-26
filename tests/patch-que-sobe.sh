#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

VER="1.0~teste"
mkdir -p "$T/bin" "$T/home/.config/meow" "$T/patches" "$T/guarda" "$T/cache"
for c in sudo pkexec su apt apt-get curl wget systemctl systemd-run pkill killall notify-send; do
  printf '#!/bin/sh\necho "recusado: %s $*" >> "%s/recusados"\nexit 1\n' "$c" "$T" > "$T/bin/$c"
  chmod 755 "$T/bin/$c"
done
cat > "$T/bin/dpkg-query" <<FIM
#!/bin/sh
case "\$*" in
  *Package*) printf 'cosmic-comp\t$VER\tinstalled\n' ;;
  *) printf '%s' "$VER" ;;
esac
FIM
printf '#!/bin/sh\nexit 0\n' > "$T/bin/cargo"
cat > "$T/bin/dpkg-source" <<FIM
#!/bin/sh
echo "dpkg-source \$*" >> "$T/log"
d="\$3"; mkdir -p "\$d/src"
printf '[package]\nname = "cosmic-comp"\n' > "\$d/Cargo.toml"
printf 'all:\n\ttrue\n' > "\$d/Makefile"
printf 'fn um() {}\nfn dois() {}\nfn tres() {}\n' > "\$d/src/a.rs"
FIM
cat > "$T/bin/make" <<'FIM'
#!/bin/sh
mkdir -p target/release && grep -rho 'MEOW-T-[0-9]*' src > target/release/cosmic-comp
FIM
chmod 755 "$T/bin/"*
: > "$T/guarda/cosmic-comp_$VER.dsc"
echo 'req t.patch MEOW-T' > "$T/patches/series"

fazer_patch() {
  cat > "$T/patches/t.patch" <<FIM
--- a/src/a.rs
+++ b/src/a.rs
@@ -1,3 +1,4 @@
 fn um() {}
+static M: &str = "MEOW-T-$1";
 fn dois() {}
 fn tres() {}
FIM
}

CASA="$T/home/.local/libexec/meow/cosmic-comp"
ESTADO="$T/home/.local/state/meowsystem"
FONTE="$T/cache/cosmic-comp-$VER"

echo "== 1. o garantir_builds refaz o build de marcador velho"
cat > "$T/compositor" <<FIM
#!/bin/sh
echo "compositor \$*" >> "$T/log"
exit 0
FIM
chmod 755 "$T/compositor"
gb() {
  env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR -u WAYLAND_DISPLAY \
    HOME="$T/home" PATH="$T/bin:$PATH" MEOW_RAIZ="$RAIZ" NO_COLOR=1 FILES_MENU=nao \
    MEOW_ESTADO="$ESTADO" MEOW_CONF="$T/home/.config/meow/meow.conf" \
    GB_COMPOSITOR="$T/compositor" CP_REPO="$T/patches" CP_SERIE="$T/patches/series" \
    "$RAIZ/scripts/garantir_builds.sh" "$@" > "$T/saida" 2>&1
}
compilou() { grep -c '^compositor compilar' "$T/log" 2>/dev/null || true; }
mkdir -p "$CASA/$VER"
printf '#!/bin/sh\n' > "$CASA/$VER/cosmic-comp"; chmod 755 "$CASA/$VER/cosmic-comp"
echo "req MEOW-T-1 t.patch presente" > "$CASA/$VER/estado"

fazer_patch 2
: > "$T/log"; gb
igual "o .patch subiu para -2 e o build tem -1: um build" "$(compilou)" 1

echo "req MEOW-T-2 t.patch presente" > "$CASA/$VER/estado"
: > "$T/log"; gb
igual "o build tem a versão que o .patch declara: nenhum build" "$(compilou)" 0

printf -- '--- a/src/a.rs\n+++ b/src/a.rs\n' > "$T/patches/t.patch"
echo "req MEOW-T-1 t.patch presente" > "$CASA/$VER/estado"
: > "$T/log"; gb
igual "o .patch não declara versão: o build que tem a base vale" "$(compilou)" 0

fazer_patch 2
printf 'req MEOW-U-1 u.patch presente\nreq MEOW-T t.patch ausente\n' > "$CASA/$VER/estado"
: > "$T/log"; gb
igual "o patch ausente do build não o refaz (sairia igual)" "$(compilou)" 0

echo "== 2. o compilar reextrai a árvore que tem a versão anterior"
rm -rf "$CASA/$VER"
fazer_patch 1
"$T/bin/dpkg-source" -x x "$FONTE"
(cd "$FONTE" && patch -p1 -s < "$T/patches/t.patch") || falha "o brinquedo não aplicou a v1"
fazer_patch 2
antes="$(sha256sum "$FONTE/src/a.rs")"
env -i PATH="$T/bin:$PATH" HOME="$T/home" NO_COLOR=1 MEOW_ESTADO="$ESTADO" \
  CP_REPO="$T/patches" CP_SERIE="$T/patches/series" CP_BIN="$T/nao-existe" \
  bash "$RAIZ/scripts/compositor_patches.sh" aplicar "$FONTE" > "$T/saida" 2>&1; rc=$?
[ "$rc" != 0 ] && ok "o aplicar recusa a árvore com a v1 (rc $rc)" || falha "o aplicar aceitou a árvore com a v1"
igual "e não escreve nela" "$(sha256sum "$FONTE/src/a.rs")" "$antes"
grep -q 'outra versão' "$T/saida" && ok "e diz que é outra versão" || falha "não disse outra versão: $(cat "$T/saida")"
comp() {
  env -i PATH="$T/bin:$PATH" HOME="$T/home" NO_COLOR=1 MEOW_ESTADO="$ESTADO" \
    CP_REPO="$T/patches" CP_SERIE="$T/patches/series" CP_CACHE="$T/cache" CP_GUARDA="$T/guarda" \
    CP_CASA="$CASA" CP_SHIM="$T/home/.local/bin/cosmic-comp" \
    bash "$RAIZ/scripts/compositor_patches.sh" compilar > "$T/saida" 2>&1
}
: > "$T/log"; comp; rc=$?
igual "compilou e guardou: 0" "$rc" 0
igual "o fonte foi reextraído do guardado" "$(grep -c '^dpkg-source -x' "$T/log")" 1
igual "o estado grava a versão nova" "$(cat "$CASA/$VER/estado" 2>/dev/null | grep -c '^req MEOW-T-2 t.patch presente$')" 1
igual "o binário só tem a versão nova" "$(sort -u "$CASA/$VER/cosmic-comp" 2>/dev/null | tr '\n' ' ')" "MEOW-T-2 "
[ "$rc" = 0 ] || sed 's/^/        /' "$T/saida"

: > "$T/log"; comp; rc=$?
igual "a segunda passagem sai 0" "$rc" 0
igual "e não reextrai" "$(grep -c '^dpkg-source' "$T/log")" 0

[ -s "$T/recusados" ] && falha "chamou o que recusa: $(cat "$T/recusados")"

echo
if [ "$falhas" = 0 ]; then echo "patch-que-sobe: tudo certo"; exit 0; fi
echo "patch-que-sobe: $falhas falha(s)"; exit 1

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1" "${3:-}"; fi; }

SIS="$T/sis"; FALSO="$T/falso"; BIN="$SIS/usr/bin/cosmic-comp"; INFO="$SIS/var/lib/dpkg/info"
mkdir -p "$SIS/usr/bin" "$INFO" "$FALSO"
printf 'o binário do pacote\n' > "$T/fabrica"
printf 'o binário remendado por outro\n' > "$T/remendado"
printf '%s  usr/bin/cosmic-comp\n' "$(md5sum < "$T/fabrica" | cut -d' ' -f1)" > "$INFO/cosmic-comp.md5sums"

cat > "$FALSO/dpkg-query" <<FIM
#!/bin/sh
[ -f "$T/sem-pacote" ] && exit 1
printf 'installed'
FIM
cat > "$FALSO/apt-get" <<FIM
#!/bin/sh
echo "apt-get \$*" >> "$T/apt.log"
[ -f "$T/apt-nao-conserta" ] || cp "$T/fabrica" "$BIN"
exit 0
FIM
printf '#!/bin/sh\nexit 0\n' > "$FALSO/logger"
chmod 755 "$FALSO"/*

PONTE="$T/ponte-brinquedo.sh"
sed -e "s#^export PATH=.*#export PATH=\"$FALSO:/usr/bin:/bin\"#" \
    -e "s#^COSMIC_COMP=.*#COSMIC_COMP=$BIN#" -e "s#^DPKG_INFO=.*#DPKG_INFO=$INFO#" \
    "$RAIZ/scripts/ponte_root.sh" > "$PONTE"
ponte() { env -i PATH=/usr/bin:/bin bash "$PONTE" "$@" > "$T/saida" 2>&1; }
apt_chamadas() { grep -c . "$T/apt.log" 2>/dev/null || true; }

printf '\n1. o de fábrica no lugar: nada a fazer\n'
cp "$T/fabrica" "$BIN"; : > "$T/apt.log"
ponte cosmic-comp-de-fabrica; rc=$?
confere "sai 0 sem chamar o apt" '[ "$rc" = 0 ] && [ "$(apt_chamadas)" = 0 ]' "$(cat "$T/saida")"

printf '\n2. o binário remendado volta ao do pacote\n'
cp "$T/remendado" "$BIN"; : > "$T/apt.log"
ponte cosmic-comp-de-fabrica; rc=$?
confere "sai 0 e diz reinstalado" '[ "$rc" = 0 ] && grep -qx reinstalado "$T/saida"' "$(cat "$T/saida")"
confere "pede ao apt só o cosmic-comp, reinstalado" '[ "$(cat "$T/apt.log")" = "apt-get install -y --reinstall cosmic-comp" ]' "$(cat "$T/apt.log")"
confere "e o binário bate com a soma do dpkg" 'cmp -s "$BIN" "$T/fabrica"'
: > "$T/apt.log"; ponte cosmic-comp-de-fabrica; rc=$?
confere "a segunda passada não chama o apt" '[ "$rc" = 0 ] && [ "$(apt_chamadas)" = 0 ]'

printf '\n3. o que não fecha diz o porquê\n'
cp "$T/remendado" "$BIN"; : > "$T/apt-nao-conserta"
ponte cosmic-comp-de-fabrica; rc=$?
confere "o apt que não devolve o binário: sai 2 e diz" '[ "$rc" = 2 ] && grep -q "ainda não bate com o pacote" "$T/saida"' "$(cat "$T/saida")"
rm -f "$T/apt-nao-conserta"
: > "$T/sem-pacote"; : > "$T/apt.log"
ponte cosmic-comp-de-fabrica; rc=$?
confere "sem o pacote instalado: sai 3, sem apt" '[ "$rc" = 3 ] && [ "$(apt_chamadas)" = 0 ]' "$(cat "$T/saida")"
rm -f "$T/sem-pacote"
mv "$INFO/cosmic-comp.md5sums" "$T/md5sums"
ponte cosmic-comp-de-fabrica; rc=$?
confere "sem a soma do dpkg: sai 4, sem apt" '[ "$rc" = 4 ] && [ "$(apt_chamadas)" = 0 ]' "$(cat "$T/saida")"
mv "$T/md5sums" "$INFO/cosmic-comp.md5sums"
ponte cosmic-comp-de-fabrica algo; rc=$?
confere "argumento é recusado" '[ "$rc" = 2 ] && [ "$(apt_chamadas)" = 0 ]'

printf '\n4. a regra do sudo libera o verbo, sem curinga\n'
env -i PATH=/usr/bin:/bin USER=teste bash "$PONTE" regra-sudo > "$T/regra" 2>&1
confere "o verbo está na regra" 'grep -qE "ponte_root.sh cosmic-comp-de-fabrica, \\\\$" "$T/regra"'
confere "e a regra segue sem curinga" '! grep -q "\*" <(grep -v "^#" "$T/regra")'

printf '\n5. o compositor_patches.sh reverter usa a ponte quando ela está de pé\n'
LIB="$T/lib"; mkdir -p "$LIB" "$T/casa"
cp "$PONTE" "$LIB/ponte_root.sh"; chmod 755 "$LIB/ponte_root.sh"
printf 'lar=%s\n' "$T/casa" > "$LIB/perfil"
cat > "$FALSO/sudo" <<FIM
#!/bin/sh
[ "\$1" = -n ] && shift
[ "\$1" = "$LIB/ponte_root.sh" ] || exit 1
echo "ponte \$2" >> "$T/ponte.log"
exec bash "\$@"
FIM
chmod 755 "$FALSO/sudo"
reverter() {
  env -i PATH="$FALSO:/usr/bin:/bin" HOME="$T/casa" NO_COLOR=1 MEOW_RAIZ="$RAIZ" MEOW_PONTE="${1:-$LIB/ponte_root.sh}" \
    CP_BIN="$BIN" CP_SHIM="$T/casa/.local/bin/cosmic-comp" bash "$RAIZ/scripts/compositor_patches.sh" reverter > "$T/saida" 2>&1
}
cp "$T/remendado" "$BIN"; : > "$T/apt.log"; : > "$T/ponte.log"
reverter; rc=$?
confere "o remendado volta ao do pacote: rc 1" '[ "$rc" = 1 ] && cmp -s "$BIN" "$T/fabrica"' "$(cat "$T/saida")"
confere "pela ponte, com o verbo cosmic-comp-de-fabrica" 'grep -qx "ponte cosmic-comp-de-fabrica" "$T/ponte.log"'
confere "e diz que voltou" 'grep -q "voltou ao binário do pacote cosmic-comp" "$T/saida"' "$(cat "$T/saida")"
: > "$T/apt.log"; reverter; rc=$?
confere "a segunda vez: rc 0, sem apt" '[ "$rc" = 0 ] && [ "$(apt_chamadas)" = 0 ] && grep -q "já é o binário do pacote" "$T/saida"' "$(cat "$T/saida")"
cp "$T/remendado" "$BIN"; : > "$T/apt.log"
reverter /nao/existe; rc=$?
confere "sem a ponte: não toca no binário e diz o caminho" '[ "$rc" = 0 ] && cmp -s "$BIN" "$T/remendado" && [ "$(apt_chamadas)" = 0 ]' "$(cat "$T/saida")"

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'ponte-cosmic-comp: tudo verde\n'; exit 0; fi
printf 'ponte-cosmic-comp: %s falha(s)\n' "$falhas"; exit 1

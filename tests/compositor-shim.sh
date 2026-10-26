#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
SHIM="$RAIZ/scripts/compositor_shim.sh"
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

mkdir -p "$T/bin" "$T/casa" "$T/home"
VER_INST="0.1~1791227611~24.04~41497b4"
printf '%s' "$VER_INST" > "$T/versao"
cat > "$T/bin/dpkg-query" <<FIM
#!/bin/sh
cat "$T/versao"
FIM
chmod 755 "$T/bin/dpkg-query"

cat > "$T/fabrica" <<'FIM'
#!/bin/sh
echo fabrica
FIM
chmod 755 "$T/fabrica"
fazer_build() {
  mkdir -p "$T/casa/$1"
  cat > "$T/casa/$1/cosmic-comp" <<'FIM'
#!/bin/sh
echo build
[ -n "${FICAR:-}" ] && sleep "$FICAR"
exit 0
FIM
  chmod 755 "$T/casa/$1/cosmic-comp"
  printf 'versao=%s\nreq AURORA-COSMIC-WS-PATCH-3.67 cosmic-comp-sem-workspace-vazio.patch presente\n' "$1" > "$T/casa/$1/estado"
}
rodar() { PATH="$T/bin:$PATH" MEOW_SHIM_FABRICA="$T/fabrica" MEOW_SHIM_CASA="$T/casa" \
          MEOW_SHIM_JANELA="${JANELA:-1}" HOME="$T/home" bash "$SHIM"; }

echo "== o shim escolhe"
igual "sem build: fábrica" "$(rodar)" fabrica

fazer_build "$VER_INST"
igual "versão igual: build" "$(rodar)" build
rm -f "$T/casa/$VER_INST/quedas"

printf '0.1~outra' > "$T/versao"
igual "versão diferente: fábrica" "$(rodar)" fabrica
printf '%s' "$VER_INST" > "$T/versao"

date -Is > "$T/casa/$VER_INST/ruim"
igual "build ruim: fábrica" "$(rodar)" fabrica
rm -f "$T/casa/$VER_INST/ruim"

sed -i 's/presente$/ausente/' "$T/casa/$VER_INST/estado"
igual "estado sem req presente: fábrica" "$(rodar)" fabrica
fazer_build "$VER_INST"

igual "só dizer: o caminho do build" "$(MEOW_SHIM_SO_DIZER=1 rodar)" "$T/casa/$VER_INST/cosmic-comp"
[ -e "$T/casa/$VER_INST/quedas" ] && falha "só dizer contou queda" || ok "só dizer não conta queda"

echo "== a guarda de queda"
igual "1º início: build" "$(rodar)" build; sleep 2
igual "2º início: build" "$(rodar)" build; sleep 2
igual "3º início, depois de duas quedas: fábrica" "$(rodar)" fabrica
[ -e "$T/casa/$VER_INST/ruim" ] && ok "o build ficou marcado ruim" || falha "o build não foi marcado ruim"
igual "4º início: continua fábrica até build novo" "$(rodar)" fabrica

fazer_build "$VER_INST"; rm -f "$T/casa/$VER_INST/ruim" "$T/casa/$VER_INST/quedas"
igual "sessão longa: build" "$(FICAR=3 rodar)" build
sleep 1
[ -e "$T/casa/$VER_INST/quedas" ] && falha "o contador ficou depois de uma sessão que passou da janela" \
  || ok "o contador zerou depois de uma sessão que passou da janela"

echo "== os verbos (HOME de brinquedo)"
CP() { HOME="$T/home" PATH="$T/bin:$PATH" CP_BIN="$T/fabrica" CP_CASA="$T/casa" \
       MEOW_ESTADO="$T/home/.local/state/meowsystem" MEOW_IGNORA_DESKTOP=1 \
       "$RAIZ/scripts/compositor_patches.sh" "$@" 2>&1; }
igual "qual, sem shim: fábrica" "$(CP qual)" "$T/fabrica"
CP ativar >/dev/null; rc=$?
igual "ativar escreve (1)" "$rc" 1
cmp -s "$SHIM" "$T/home/.local/bin/cosmic-comp" && ok "o shim foi instalado em ~/.local/bin" || falha "o shim não está em ~/.local/bin"
CP ativar >/dev/null; igual "ativar de novo não escreve (0)" "$?" 0
igual "qual, com shim e build: build" "$(CP qual)" "$T/casa/$VER_INST/cosmic-comp"
CP desativar >/dev/null; igual "desativar escreve (1)" "$?" 1
[ -e "$T/home/.local/bin/cosmic-comp" ] && falha "o shim ficou" || ok "o shim saiu"
CP desativar >/dev/null; igual "desativar de novo não escreve (0)" "$?" 0
echo "== a conferência com o shim e sem build (conferência da P76)"
CP ativar >/dev/null
printf '0.1~sem-build' > "$T/versao"
CP conferir >/dev/null; igual "sem build e sem degrau 4: 1 (o conserto compila)" "$?" 1
mkdir -p "$T/home/.local/state/meowsystem"
flock "$T/home/.local/state/meowsystem/builds.lock" sleep 3 & trava=$!
sleep 0.5
saida="$(CP conferir)"; rc=$?
igual "sem build, com um build em andamento: 0" "$rc" 0
grep -q '^ *!! *construindo' <<< "$saida" && ok "e diz «construindo», com aviso" || falha "não disse construindo: $saida"
kill "$trava" 2>/dev/null; wait "$trava" 2>/dev/null
mkdir -p "$T/home/.local/state/meowsystem/cosmic-comp"
printf '0.1~sem-build\t2026-10-09\tcosmic-comp-sem-workspace-vazio.patch:4 cosmic-comp-raio-clampado.patch:1\n' \
  > "$T/home/.local/state/meowsystem/cosmic-comp/matriz.tsv"
CP conferir >/dev/null; igual "sem build e com o degrau 4 na matriz: 1" "$?" 1
printf '%s' "$VER_INST" > "$T/versao"
CP desativar >/dev/null

printf '#!/bin/sh\necho alheio\n' > "$T/home/.local/bin/cosmic-comp"
CP ativar >/dev/null; igual "ativar recusa um cosmic-comp alheio (2)" "$?" 2
grep -q alheio "$T/home/.local/bin/cosmic-comp" && ok "o alheio ficou intocado" || falha "o alheio foi sobrescrito"

echo
if [ "$falhas" = 0 ]; then echo "compositor-shim: tudo certo"; exit 0; fi
echo "compositor-shim: $falhas falha(s)"; exit 1

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

PINO="$(awk '/^name = "libcosmic"$/{f=1} f && /^source = /{sub(/.*#/,""); sub(/"$/,""); print; exit}' "$RAIZ/src/applets/leitura/Cargo.lock")"
[ -n "$PINO" ] || { echo "applet-pino: não li o pino do Cargo.lock"; exit 1; }
OUTRA="0000000000000000000000000000000000000abc"
lock_painel() { printf '[[package]]\nname = "libcosmic"\nversion = "1.0.0"\nsource = "git+https://github.com/pop-os/libcosmic#%s"\n' "$1" > "$T/painel.lock"; }

mkdir -p "$T/bin" "$T/lar"
cat > "$T/bin/cargo" <<FIM
#!/bin/sh
m=""; prev=""
for a; do [ "\$prev" = "--manifest-path" ] && m="\$a"; prev="\$a"; done
echo "cargo \$1 \$m" >> "$T/cargo.log"
[ "\$1" = build ] || exit 0
case "\$m" in *receita-painel*) [ -f "$T/painel-falha" ] && exit 101 ;; esac
mkdir -p "\$CARGO_TARGET_DIR/release"
printf '#!/bin/sh\n# %s\n' "\$(grep -o 'rev = "[0-9a-f]*"' "\$m")" > "\$CARGO_TARGET_DIR/release/meow-applet-leitura"
chmod 755 "\$CARGO_TARGET_DIR/release/meow-applet-leitura"
FIM
chmod 755 "$T/bin/cargo"

AP() { HOME="$T/lar" MEOW_ESTADO="$T/lar/estado" AP_LOCK_PAINEL="$T/painel.lock" "$RAIZ/scripts/applet_pino.sh" "$@" 2>/dev/null; }

echo "== a regra do alvo"
lock_painel "$OUTRA"
igual "sem base, o painel fora do pino: o pino (adoção; ninguém recompila só porque a regra chegou)" "$(AP alvo leitura "$PINO")" "$PINO"
rm -rf "$T/lar/estado"
lock_painel "$PINO"
igual "sem base, painel no pino: o pino" "$(AP alvo leitura "$PINO")" "$PINO"
igual "idem para a mídia" "$(AP alvo midia "$PINO")" "$PINO"
lock_painel "$OUTRA"
igual "o painel andou depois da base: alvo é a do painel" "$(AP alvo leitura "$PINO")" "$OUTRA"
AP falhou leitura "$OUTRA"
igual "a do painel já falhou: alvo volta ao pino" "$(AP alvo leitura "$PINO")" "$PINO"
igual "a falha é por applet: a mídia segue o painel" "$(AP alvo midia "$PINO")" "$OUTRA"
rm -rf "$T/lar/estado"

echo "== o leitura_build.sh de ponta a ponta"
construir() {
  HOME="$T/lar" PATH="$T/bin:$PATH" MEOW_ESTADO="$T/lar/estado" AP_LOCK_PAINEL="$T/painel.lock" \
  LEITURA_COMPILAR=1 MEOW_IGNORA_DESKTOP=1 "$RAIZ/scripts/leitura_build.sh" --aplicar >/dev/null 2>&1
}
builds() { grep -c '^cargo build' "$T/cargo.log" 2>/dev/null || true; }

lock_painel "$PINO"; : > "$T/cargo.log"
construir
igual "painel no pino: um build" "$(builds)" 1
grep -q "src/applets/leitura/Cargo.toml" "$T/cargo.log" && ok "e ele é o da receita daqui" || falha "não foi a receita daqui: $(cat "$T/cargo.log")"
: > "$T/cargo.log"; construir
igual "segunda passagem: nenhum build" "$(builds)" 0

lock_painel "$OUTRA"; : > "$T/cargo.log"
construir
igual "o painel andou: um build" "$(builds)" 1
grep -q "receita-painel" "$T/cargo.log" && ok "na cópia com o libcosmic do painel" || falha "não foi na cópia: $(cat "$T/cargo.log")"
grep -q "$OUTRA" "$T/lar/.local/bin/meow-applet-leitura" && ok "o binário é o do libcosmic do painel" || falha "o binário instalado não é o do painel"
: > "$T/cargo.log"; construir
igual "e zero na passagem seguinte" "$(builds)" 0

OUTRA2="0000000000000000000000000000000000000def"
lock_painel "$OUTRA2"; touch "$T/painel-falha"; : > "$T/cargo.log"
construir
igual "o painel andou e não compila nele: dois builds (painel, depois pino)" "$(builds)" 2
grep -q "$PINO" "$T/lar/.local/bin/meow-applet-leitura" && ok "o binário voltou ao pino" || falha "o binário não voltou ao pino"
: > "$T/cargo.log"; construir
igual "e não tenta de novo na passagem seguinte" "$(builds)" 0

echo "== conferir não escreve"
rm -rf "$T/lar2"; mkdir -p "$T/lar2"
HOME="$T/lar2" MEOW_ESTADO="$T/lar2/estado" AP_LOCK_PAINEL="$T/painel.lock" "$RAIZ/scripts/applet_pino.sh" conferir >/dev/null 2>&1
HOME="$T/lar2" PATH="$T/bin:$PATH" MEOW_ESTADO="$T/lar2/estado" AP_LOCK_PAINEL="$T/painel.lock" \
  MEOW_IGNORA_DESKTOP=1 "$RAIZ/scripts/leitura_build.sh" --conferir >/dev/null 2>&1
igual "o HOME de brinquedo continua vazio" "$(find "$T/lar2" -type f | wc -l)" 0

echo
if [ "$falhas" = 0 ]; then echo "applet-pino: tudo certo"; exit 0; fi
echo "applet-pino: $falhas falha(s)"; exit 1

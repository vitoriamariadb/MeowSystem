#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

CASA_REAL="${SUITE_CASA_REAL:-$HOME}"
ARVORES="${EXTENSOES_ARVORES:-$CASA_REAL/.local/state/meowsystem/extensoes}"

mkdir -p "$T/bin"
for c in sudo pkexec su apt apt-get; do printf '#!/bin/sh\nexit 1\n' > "$T/bin/$c"; chmod 755 "$T/bin/$c"; done
cat > "$T/bin/cargo" <<'FIM'
#!/bin/sh
case "$1" in
  build)
    d="${CARGO_TARGET_DIR:-target}/release"
    mkdir -p "$d" && printf '#!/bin/sh\n' > "$d/$FAKE_BIN" && chmod 755 "$d/$FAKE_BIN" ;;
esac
exit 0
FIM
chmod 755 "$T/bin/cargo"

campo() { sed -n "s/^$2=\"\(.*\)\"/\1/p" "$1" | head -1; }

lista_instalada() {
  local raiz="$1" f
  [ -d "$raiz" ] || return 0
  while IFS= read -r f; do
    case "$f" in
      bin/*|share/applications/*) printf '%s\t-\n' "$f" ;;
      *) printf '%s\t%s\n' "$f" "$(sha256sum -- "$raiz/$f" | cut -d' ' -f1)" ;;
    esac
  done < <(cd "$raiz" && find bin share/applications share/metainfo share/icons -type f 2>/dev/null | sort)
}

clonar() {
  git clone -q --no-hardlinks "$1" "$2" 2>/dev/null && git -C "$2" checkout -q --detach "$3" 2>/dev/null
}

o_que_o_fork_instala() {
  local arvore="$1" commit="$2" bin="$3" s="$4" src="$4/fork" raiz=""
  mkdir -p "$s/casa"
  clonar "$arvore" "$src" "$commit" || return 1
  [ -f "$src/deps.sh" ] && printf '#!/bin/sh\nexit 0\n' > "$src/deps.sh"
  (cd "$src" && env -i PATH="$T/bin:$PATH" FAKE_BIN="$bin" cargo build --release) || return 1
  if [ -f "$src/justfile" ] && grep -q '^install-user' "$src/justfile"; then
    (cd "$src" && env -i PATH="$T/bin:$PATH" HOME="$s/casa" FAKE_BIN="$bin" just install-user >/dev/null 2>&1) || return 1
    raiz="$s/casa/.local"
  elif [ -f "$src/justfile" ] && grep -q '^install:' "$src/justfile"; then
    (cd "$src" && env -i PATH="$T/bin:$PATH" HOME="$s/casa" FAKE_BIN="$bin" just "rootdir=$s/raiz" install >/dev/null 2>&1) || return 1
    raiz="$s/raiz/usr"
  elif [ -f "$src/install.sh" ]; then
    (cd "$src" && env -i PATH="$T/bin:$PATH" HOME="$s/casa" FAKE_BIN="$bin" sh ./install.sh "$s/prefixo" >/dev/null 2>&1) || return 1
    raiz="$s/prefixo"
  else
    return 1
  fi
  lista_instalada "$raiz"
}

o_que_o_pino_instala() {
  local id="$1" arvore="$2" pinos="$3" s="$4" pino commit url bin libcosmic
  pino="$pinos/$id.pino"
  commit="$(campo "$pino" COMMIT)"; url="$(campo "$pino" URL)"; bin="$(campo "$pino" BIN)"; libcosmic="$(campo "$pino" LIBCOSMIC)"
  mkdir -p "$s/ours/.local/state/meowsystem/extensoes/$id"
  clonar "$arvore" "$s/ours/.local/state/meowsystem/extensoes/$id/src" "$commit" || return 1
  git -C "$s/ours/.local/state/meowsystem/extensoes/$id/src" remote set-url origin "$url"
  printf '[[package]]\nname = "libcosmic"\nsource = "git+https://github.com/pop-os/libcosmic#%s"\n' "$libcosmic" > "$s/painel.lock"
  env -i PATH="$T/bin:$PATH" HOME="$s/ours" NO_COLOR=1 USER=t FAKE_BIN="$bin" \
    XDG_DATA_HOME="$s/ours/.local/share" XDG_CONFIG_HOME="$s/ours/.config" \
    MEOW_ESTADO="$s/ours/.local/state/meowsystem" EXTENSOES_PINOS="$pinos" EXTENSOES_PERMITE_LOCAL=1 \
    EXTENSOES_COMPILAR=1 AP_LOCK_PAINEL="$s/painel.lock" \
    bash "$RAIZ/scripts/extensoes_build.sh" "$id" --aplicar >"$s/ours.log" 2>&1
  [ -x "$s/ours/.local/bin/$bin" ] || return 1
  lista_instalada "$s/ours/.local"
}

comparar() {
  local id="$1" arvore="$2" pinos="$3" s dele nosso commit bin
  DIFERENCA=""; N_ARQUIVOS=0
  s="$(mktemp -d -p "$T")"
  commit="$(campo "$pinos/$id.pino" COMMIT)"; bin="$(campo "$pinos/$id.pino" BIN)"
  dele="$(o_que_o_fork_instala "$arvore" "$commit" "$bin" "$s")" || { falha "$id: o install do fork não rodou"; return 1; }
  nosso="$(o_que_o_pino_instala "$id" "$arvore" "$pinos" "$s")" || { falha "$id: o build do pino não instalou ($(tail -3 "$s/ours.log" 2>/dev/null | tr '\n' ' '))"; return 1; }
  DIFERENCA="$(diff <(printf '%s\n' "$dele") <(printf '%s\n' "$nosso"))"
  N_ARQUIVOS="$(printf '%s\n' "$dele" | grep -c .)"
  [ -z "$DIFERENCA" ]
}

echo "== um fork falso: o que o install dele põe e o que o pino declara"
FK="$T/falso"; PF="$T/pinos-falso"; mkdir -p "$FK/data/icons/scalable/apps" "$PF"
(
  cd "$FK" && git init -q -b main . && git config user.email t@t && git config user.name t
  printf '[package]\nname = "x"\n' > Cargo.toml
  printf '[Desktop Entry]\nExec=@bindir@/meowsystem-teste\n' > data/io.github.teste.Fake.desktop.in
  printf '<svg xmlns="http://www.w3.org/2000/svg"/>\n' > data/icons/scalable/apps/io.github.teste.Fake.svg
  printf '<component/>\n' > data/io.github.teste.Fake.metainfo.xml
  cat > install.sh <<'FIM'
#!/bin/sh
set -e
prefix="${1:-$HOME/.local}"
id=io.github.teste.Fake
bin=meowsystem-teste
cargo build --release
install -Dm0755 "target/release/$bin" "$prefix/bin/$bin"
mkdir -p "$prefix/share/applications"
sed "s|@bindir@|$prefix/bin|" "data/$id.desktop.in" > "$prefix/share/applications/$id.desktop"
install -Dm0644 "data/$id.metainfo.xml" "$prefix/share/metainfo/$id.metainfo.xml"
install -Dm0644 "data/icons/scalable/apps/$id.svg" "$prefix/share/icons/hicolor/scalable/apps/$id.svg"
FIM
  git add -A && git -c core.hooksPath=/dev/null commit -q -m um
)
C_FALSO="$(git -C "$FK" rev-parse HEAD)"
pino_falso() {
  cat > "$PF/fake.pino" <<FIM
ORDEM=1
NOME="Fake"
URL="$FK"
COMMIT="$C_FALSO"
VERSAO="0.1.0"
LIBCOSMIC="1111111111111111111111111111111111111111"
APP_ID="io.github.teste.Fake"
BIN="meowsystem-teste"
DESKTOP="data/io.github.teste.Fake.desktop.in"
ICONES="data/icons:."
METAINFO="$1"
FIM
}
pino_falso "data/io.github.teste.Fake.metainfo.xml"
comparar fake "$FK" "$PF"; igual "fork falso: o pino declara tudo o que o install põe" "$?" 0
igual "e a lista tem o binário, a sombra, o metainfo e o ícone" "$N_ARQUIVOS" 4

pino_falso ""
comparar fake "$FK" "$PF"; rc=$?
igual "fork falso: sem METAINFO no pino, a comparação acende" "$rc" 1
grep -q 'metainfo' <<< "$DIFERENCA" && ok "e aponta o metainfo que falta" || falha "diferença sem metainfo: $DIFERENCA"

(
  cd "$FK" && printf '[Desktop Entry]\n' > data/extra.desktop.in
  sed -i 's|^install -Dm0644 "data/icons|install -Dm0644 data/extra.desktop.in "$prefix/share/applications/extra.desktop"\n&|' install.sh
  git add -A && git -c core.hooksPath=/dev/null commit -q -m dois
)
C_FALSO="$(git -C "$FK" rev-parse HEAD)"
pino_falso "data/io.github.teste.Fake.metainfo.xml"
comparar fake "$FK" "$PF"; rc=$?
igual "fork falso: um arquivo novo no install do fork acende" "$rc" 1
grep -q 'extra.desktop' <<< "$DIFERENCA" && ok "e aponta o arquivo novo" || falha "diferença sem o arquivo novo: $DIFERENCA"

echo "== os forks de verdade: o install deles contra o pino"
ids=()
for f in "$RAIZ"/assets/extensoes/*.pino; do
  [ -n "$(campo "$f" URL)" ] && ids+=("$(basename "$f" .pino)")
done
igual "nove pinos com URL" "${#ids[@]}" 9

faltam=()
for id in "${ids[@]}"; do [ -d "$ARVORES/$id/src/.git" ] || faltam+=("$id"); done
if [ "${#faltam[@]}" -gt 0 ]; then
  printf 'pulado: sem a árvore clonada de %s em %s (CI ou máquina sem os forks)\n' "${faltam[*]}" "$ARVORES"
elif ! command -v just >/dev/null 2>&1; then
  printf 'pulado: sem o just para rodar o install-user dos forks\n'
else
  for id in "${ids[@]}"; do
    comparar "$id" "$ARVORES/$id/src" "$RAIZ/assets/extensoes"; rc=$?
    if [ "$rc" = 0 ]; then ok "$id: o install do fork e o pino põem os mesmos $N_ARQUIVOS arquivos"
    elif [ -n "${DIFERENCA:-}" ]; then falha "$id: o install do fork e o pino divergem: $(printf '%s' "$DIFERENCA" | tr '\n' ' ')"; fi
  done
fi

[ "$falhas" = 0 ] && { echo "extensoes-install.sh: tudo verde"; exit 0; }
echo "extensoes-install.sh: $falhas falha(s)"; exit 1

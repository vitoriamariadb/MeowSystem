#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

mkdir -p "$T/bin" "$T/pinos"
for c in curl wget rustup sudo pkexec notify-send systemctl gsettings dconf busctl flatpak; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/recusas.log"\nexit 1\n' "$c" "$T" > "$T/bin/$c"; chmod 755 "$T/bin/$c"
done
GIT_REAL="$(command -v git)"
cat > "$T/bin/git" <<FIM
#!/bin/sh
case "\$*" in *http://*|*https://*|*ls-remote*) echo "git \$*" >> "$T/recusas.log"; exit 128 ;; esac
exec "$GIT_REAL" "\$@"
FIM
cat > "$T/bin/cargo" <<FIM
#!/bin/sh
echo "cargo \$*" >> "$T/cargo.log"
[ "\$1" = build ] || exit 0
echo "error: failed to get \\\`libcosmic\\\` as a dependency (sem rede)" >&2
exit 101
FIM
chmod 755 "$T/bin/git" "$T/bin/cargo"

REPO="$T/repo"
mkdir -p "$REPO/data"
( cd "$REPO" && "$GIT_REAL" init -q -b main . && "$GIT_REAL" config user.email t@t && "$GIT_REAL" config user.name t
  printf '[package]\nname = "fake"\nversion = "0.1.0"\n' > Cargo.toml
  printf '[Desktop Entry]\nName=Fake\nExec=@bindir@/meowsystem-fake\n' > data/fake.desktop.in
  "$GIT_REAL" add -A && "$GIT_REAL" -c core.hooksPath=/dev/null commit -q -m um )
pino() {
  cat > "$T/pinos/fake.pino" <<FIM
ORDEM=1
PADRAO=sim
NOME="Fake"
URL="$2"
COMMIT="$1"
VERSAO="0.1.0"
APP_ID="io.github.teste.Fake"
BIN="meowsystem-fake"
DESKTOP="data/fake.desktop.in"
FIM
}
C1="$("$GIT_REAL" -C "$REPO" rev-parse HEAD)"
pino "$C1" "$REPO"

H="$T/casa"
mkdir -p "$H/.config/meow"
cp "$RAIZ/meow.conf.exemplo" "$H/.config/meow/meow.conf"
doctor() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$H" USER=t NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
      XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" XDG_DATA_HOME="$H/.local/share" \
      EXTENSOES_PINOS="$T/pinos" EXTENSOES_PERMITE_LOCAL=1 AP_LOCK_PAINEL="$T/sem-painel.lock" \
      bash -c 'source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/bin/meow"); VERIFICAVEIS=(extensoes wallpaper); cmd_doctor "$@"' _ "$@" 2>&1
}
EB() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$H" USER=t NO_COLOR=1 \
      XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" MEOW_ESTADO="$H/.local/state/meowsystem" \
      EXTENSOES_PINOS="$T/pinos" EXTENSOES_PERMITE_LOCAL=1 AP_LOCK_PAINEL="$T/sem-painel.lock" \
      EXTENSOES_COMPILAR=1 bash "$RAIZ/scripts/extensoes_build.sh" "$@" 2>&1
}
retrato() {
  (cd "$H" && find . -type f ! -name meow.log ! -name '*.lock' ! -name lock -printf '%p %s %T@\n' | LC_ALL=C sort)
}
builds() { grep -c '^cargo build' "$T/cargo.log" 2>/dev/null || true; }
EST="$H/.local/state/meowsystem"

printf '\n1. o doctor numa casa sem rede, com o cargo que não baixa nada\n'
doctor --consertar > "$T/p1.txt"; rc1=$?
igual "a primeira passada tenta compilar uma vez" "$(builds)" 1
if [ -f "$EST/extensoes/fake/falhou" ]; then ok "e marca a falha com o que tentou"; else falha "e marca a falha com o que tentou"; fi
grep -q "^commit $C1$" "$EST/extensoes/fake/falhou" 2>/dev/null && ok "a marca guarda o commit do pino" || falha "a marca guarda o commit do pino"
antes="$(retrato)"
: > "$T/cargo.log"
doctor --consertar > "$T/p2.txt"; rc2=$?
igual "a segunda passada não compila" "$(builds)" 0
if [ "$antes" = "$(retrato)" ]; then ok "e não escreve arquivo nenhum na casa (nem pendencias.tsv, nem a semeadura do papel de parede)"
else falha "e não escreve arquivo nenhum na casa"; diff <(printf '%s\n' "$antes") <(retrato) | sed 's/^/       /'; fi
grep -q 'tenta de novo quando o pino' "$T/p2.txt" && ok "e diz quando volta a tentar" || falha "e diz quando volta a tentar"
igual "o rc da segunda é o da primeira" "$rc2" "$rc1"
doctor --consertar > "$T/p3.txt"
if [ "$antes" = "$(retrato)" ]; then ok "a terceira passada também não"; else falha "a terceira passada também não"; fi

printf '\n2. o gatilho novo volta a tentar\n'
: > "$T/cargo.log"
EB fake --aplicar >/dev/null
igual "o pedido dela na página (uma extensão só) tenta de novo" "$(builds)" 1
: > "$T/cargo.log"
EB --todas --aplicar >/dev/null
igual "e a passada seguinte do doctor, com o mesmo pino, não" "$(builds)" 0
( cd "$REPO" && echo dois > data/novo && "$GIT_REAL" add -A && "$GIT_REAL" -c core.hooksPath=/dev/null commit -q -m dois )
pino "$("$GIT_REAL" -C "$REPO" rev-parse HEAD)" "$REPO"
: > "$T/cargo.log"
EB --todas --aplicar >/dev/null
igual "o pino andou: a passada tenta de novo" "$(builds)" 1
: > "$T/cargo.log"
EB --todas --aplicar >/dev/null
igual "e para outra vez" "$(builds)" 0

printf '\n3. sem rede nem para clonar\n'
rm -rf "$EST/extensoes/fake"
pino "$C1" "https://example.invalid/fake.git"
EB --todas --aplicar >/dev/null; rc=$?
igual "o clone que falha é rc 3" "$rc" 3
antes="$(retrato)"
EB --todas --aplicar >/dev/null
if [ "$antes" = "$(retrato)" ]; then ok "a segunda tentativa não regrava o clone.log"; else falha "a segunda tentativa não regrava o clone.log"; diff <(printf '%s\n' "$antes") <(retrato) | sed 's/^/       /'; fi

printf '\n4. as pendências só mudam quando mudam\n'
PEND() {
  env -i PATH="/usr/bin:/bin" HOME="$H" MEOW_ESTADO="$EST" NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
    bash -c 'source "$MEOW_RAIZ/lib/comum.sh"; "$@"' _ "$@" >/dev/null 2>&1
}
PEND meow_pendencia_acionavel teste-x "uma frase" "meow doctor --consertar"
antes="$(retrato)"
PEND meow_pendencia_acionavel teste-x "uma frase" "meow doctor --consertar"
if [ "$antes" = "$(retrato)" ]; then ok "a mesma pendência de novo não regrava o arquivo"; else falha "a mesma pendência de novo não regrava o arquivo"; fi
PEND meow_pendencia_resolvida id-que-nao-esta
if [ "$antes" = "$(retrato)" ]; then ok "resolver o que não está lá não regrava"; else falha "resolver o que não está lá não regrava"; fi
PEND meow_pendencia_acionavel teste-x "outra frase" "meow doctor --consertar"
grep -q 'outra frase' "$EST/pendencias.tsv" && [ "$(grep -c '^teste-x' "$EST/pendencias.tsv")" = 1 ] \
  && ok "a frase nova troca a linha" || falha "a frase nova troca a linha"
PEND meow_pendencia_resolvida teste-x
! grep -q '^teste-x' "$EST/pendencias.tsv" && ok "e resolvida, sai" || falha "e resolvida, sai"

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'segunda-passada-sem-rede: tudo verde\n'; exit 0; fi
printf 'segunda-passada-sem-rede: %s falha(s)\n' "$falhas"; exit 1

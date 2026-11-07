#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v fuser >/dev/null 2>&1 || { printf 'pulado: sem fuser\n'; exit 0; }

T="$(mktemp -d)" || exit 2
filhos=()
trap 'kill "${filhos[@]}" 2>/dev/null; rm -rf "$T"' EXIT
falhas=0
ok() { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n%s\n' "$1" "${2:-}" >&2; falhas=$((falhas + 1)); }

ESTADO="$T/estado"; mkdir -p "$ESTADO" "$T/bin"
cp "$(command -v sleep)" "$T/bin/spotify"
travar() {
  env -i PATH="$PATH" HOME="$T" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$ESTADO" NO_COLOR=1 \
    bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 2; meow_travar; rc=$?; printf "rc=%s\n" "$rc"; [ "$rc" = 0 ] && sleep "${1:-0}"' _ "${1:-0}" 2>&1
}
rc_de() { printf '%s\n' "$1" | sed -n 's/^rc=//p' | tail -1; }

bash -c 'exec {f}>"$1/lock"; flock -n "$f" || exit 1; exec "$2" 60' _ "$ESTADO" "$T/bin/spotify" &
filhos+=("$!")
for _ in 1 2 3 4 5 6 7 8 9 10; do fuser "$ESTADO/lock" >/dev/null 2>&1 && break; sleep 0.2; done
preso="$(stat -c %i "$ESTADO/lock")"

s="$(travar)"
if [ "$(rc_de "$s")" = 0 ] && [ "$(stat -c %i "$ESTADO/lock")" != "$preso" ] \
   && printf '%s\n' "$s" | grep -q 'troquei o cadeado'; then
  ok "um app que herdou o cadeado não para o meow: o cadeado é trocado e o meow segue"
else
  falha "o meow parou num cadeado herdado por um app" "$s"
fi
if printf '%s\n' "$s" | grep -qE 'flock -u|rm -f|feche o app'; then
  falha "a saída do cadeado herdado manda digitar ou fechar o app" "$s"
else
  ok "a saída do cadeado herdado não manda digitar nada"
fi

travar 5 > "$T/primeiro" &
filhos+=("$!")
for _ in 1 2 3 4 5 6 7 8 9 10; do grep -q '^rc=0' "$T/primeiro" 2>/dev/null && break; sleep 0.2; done
s="$(travar)"
if [ "$(rc_de "$s")" != 0 ] && printf '%s\n' "$s" | grep -q 'outro meow'; then
  ok "com outro meow no cadeado, o segundo sai sem trocar nada"
else
  falha "o segundo meow passou por cima do primeiro" "$s"
fi

for c in sudo pkexec su apt apt-get pkill killall systemd-run notify-send just make; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/recusas.log"\nexit 1\n' "$c" "$T" > "$T/bin/$c"; chmod 755 "$T/bin/$c"
done
cp "$(command -v sleep)" "$T/bin/cargo"
semear() {
  CASA="$T/casa-$1"; E="$CASA/.local/state/meowsystem"; C="$CASA/.cache/meowsystem"
  mkdir -p "$E/extensoes/.target/release/deps" "$C/cosmic-comp/cosmic-comp-1.0/target/release" "$CASA/.config/meow"
  head -c 300000 /dev/zero > "$E/extensoes/.target/release/deps/libx-0000000000000001.rlib"
  head -c 300000 /dev/zero > "$C/cosmic-comp/cosmic-comp-1.0/target/release/f"
  : > "$E/builds.lock"; : > "$E/extensoes/.target/release/.cargo-lock"
  : > "$C/cosmic-comp/cosmic-comp-1.0/target/release/.cargo-lock"
  find "$E" "$C" -exec touch -d "3 hours ago" {} +
}
liberar() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$E" MEOW_CACHE="$C" MEOW_RAIZ="$RAIZ" \
    MEOW_CONF="$CASA/meow.conf" NO_COLOR=1 ESPACO_DISCO_USO_PCT=10 "$RAIZ/bin/meow" espaco liberar > "$T/saida" 2>&1
  s="$(cat "$T/saida")"
}
casa_liberar() {
  semear "$1"
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$E" bash -c '
    exec {f}>"$MEOW_ESTADO/lock"; flock -n "$f" || exit 1
    exec 9>>"$1"; flock 9
    exec "$2" 60' _ "$2" "$T/bin/cargo" >/dev/null 2>&1 </dev/null &
  filhos+=("$!")
  for _ in 1 2 3 4 5 6 7 8 9 10; do fuser "$E/lock" >/dev/null 2>&1 && break; sleep 0.2; done
  liberar
}
alvo_de() { [ -e "$T/casa-$1/.local/state/meowsystem/extensoes/.target/release/deps/libx-0000000000000001.rlib" ] && echo de-pe || echo cortado; }
comp_de() { [ -e "$T/casa-$1/.cache/meowsystem/cosmic-comp/cosmic-comp-1.0/target/release/f" ] && echo de-pe || echo cortado; }

casa_liberar builds "$T/casa-builds/.local/state/meowsystem/builds.lock"
if printf '%s\n' "$s" | grep -q 'troquei o cadeado' && [ "$(alvo_de builds)" = de-pe ] && [ "$(comp_de builds)" = de-pe ]; then
  ok "um build órfão que herdou o cadeado e segura o builds.lock não perde o corte: o Liberar nada tira"
else
  falha "o Liberar cortou sob um build órfão com o builds.lock" "$s"
fi
casa_liberar cargo "$T/casa-cargo/.cache/meowsystem/cosmic-comp/cosmic-comp-1.0/target/release/.cargo-lock"
if printf '%s\n' "$s" | grep -q 'troquei o cadeado' && [ "$(comp_de cargo)" = de-pe ] && [ "$(alvo_de cargo)" = cortado ]; then
  ok "um cargo órfão segura o .cargo-lock do alvo dele, e só o que ele constrói fica"
else
  falha "o Liberar cortou o alvo de um cargo órfão" "$s"
fi
casa_liberar alvo "$T/casa-alvo/.local/state/meowsystem/extensoes/.target/release/.cargo-lock"
if printf '%s\n' "$s" | grep -q 'troquei o cadeado' && [ "$(alvo_de alvo)" = de-pe ] && [ "$(comp_de alvo)" = cortado ]; then
  ok "o build dos applets, que não usa o builds.lock, fica de pé pelo .cargo-lock do alvo"
else
  falha "o Liberar cortou o alvo dos applets sob um cargo órfão" "$s"
fi

cp "$(command -v sleep)" "$T/just"
mkdir -p "$T/raiz/scripts"; cp -a "$RAIZ/bin" "$RAIZ/lib" "$T/raiz/"; : > "$T/raiz/install.sh"
printf '#!/bin/bash\n: > "%s"\nexec "%s" 60\n' "$T/receita-viva" "$T/just" > "$T/raiz/scripts/compositor_patches.sh"
chmod 755 "$T/raiz/scripts/compositor_patches.sh"
semear compositor
env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$E" MEOW_CACHE="$C" MEOW_RAIZ="$T/raiz" NO_COLOR=1 \
  "$T/raiz/bin/meow" compositor >/dev/null 2>&1 </dev/null &
disown "$!"
for _ in 1 2 3 4 5 6 7 8 9 10; do [ -e "$T/receita-viva" ] && break; sleep 0.2; done
sleep 0.2
orfao=""
for p in $(fuser "$E/lock" 2>/dev/null); do
  if [ "$(cat "/proc/$p/comm" 2>/dev/null)" = just ]; then orfao="$p"; filhos+=("$p"); else kill -9 "$p" 2>/dev/null; fi
done
sleep 0.2
liberar
if [ -n "$orfao" ] && [ -e "/proc/$orfao" ] && printf '%s\n' "$s" | grep -q 'troquei o cadeado' \
   && [ "$(comp_de compositor)" = de-pe ] && [ "$(alvo_de compositor)" = de-pe ]; then
  ok "meow compositor segura o builds.lock: a receita órfã, antes do cargo, não perde o fonte"
else
  falha "o Liberar cortou o fonte sob a receita órfã do meow compositor (órfão: ${orfao:-nenhum})" "$s"
fi
if [ ! -s "$T/recusas.log" ]; then
  ok "nenhum falso recusou chamada"
else
  falha "o Liberar chamou o que não devia" "$(cat "$T/recusas.log")"
fi

[ "$falhas" -eq 0 ] || { printf '\n%d falha(s)\n' "$falhas" >&2; exit 1; }
printf '\ntudo certo\n'

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

[ "$falhas" -eq 0 ] || { printf '\n%d falha(s)\n' "$falhas" >&2; exit 1; }
printf '\ntudo certo\n'

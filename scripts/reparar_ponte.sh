#!/bin/bash
set -euo pipefail
umask 077
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

R=""
BASE="$R/usr/local/lib/meowsystem"
RESERVA="$BASE/reserva"
SOMAS="$BASE/reserva.sha256"
PONTE="$BASE/ponte_root.sh"
REGRA="$R/etc/sudoers.d/49-meowsystem-ponte"

dizer() { printf 'reparar_ponte: %s\n' "$1"; }
anotar() { logger -t meowsystem-ponte -p auth.notice -- "reparo: $1" 2>/dev/null || true; }
sair() { dizer "$1"; anotar "$1"; exit "$2"; }

[ -d "$RESERVA" ] && [ -f "$SOMAS" ] || sair "sem reserva" 3

nomes="$(awk '{print $NF}' "$SOMAS" | sort | tr '\n' ' ')"
[ "$nomes" = "49-meowsystem-ponte ponte_root.sh " ] || sair "a lista da reserva não confere" 4
(cd "$RESERVA" && sha256sum --check --strict --quiet "$SOMAS") >/dev/null 2>&1 \
  || sair "a reserva não confere com o sha256" 4

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp "$RESERVA/49-meowsystem-ponte" "$TMP/regra"
chmod 0440 "$TMP/regra"
visudo -c -q -f "$TMP/regra" >/dev/null 2>&1 || sair "a regra da reserva não passa no visudo" 5

mudou=0
if ! cmp -s "$RESERVA/ponte_root.sh" "$PONTE"; then
  install -m 0755 "$RESERVA/ponte_root.sh" "$PONTE.novo" && mv -f "$PONTE.novo" "$PONTE" \
    || sair "não consegui repor $PONTE" 2
  mudou=1
fi
if ! cmp -s "$TMP/regra" "$REGRA"; then
  install -m 0440 "$TMP/regra" "$REGRA.novo" && mv -f "$REGRA.novo" "$REGRA" \
    || sair "não consegui repor $REGRA" 2
  mudou=1
fi

if [ "$mudou" = 1 ]; then
  anotar "ponte reposta da reserva"
  dizer "ponte reposta da reserva"
else
  dizer "a ponte já estava no lugar"
fi
exit 0

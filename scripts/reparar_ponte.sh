#!/bin/bash
# reparar_ponte.sh — repõe a ponte root e a regra de sudo a partir da reserva.
#
# Destino:      /usr/local/lib/meowsystem/reparar_ponte.sh  (0755, root:root)
# Quem roda:    meowsystem-ponte-reparo.service, como root, sem argumento
# Quem instala: install.sh, `etapa_ponte_root`, junto com a reserva
#
# A reserva é o que o install pôs ali com a senha. Este script não lê nada de
# quem o dispara: nem argumento, nem ambiente, nem arquivo do HOME ou do
# repositório. Por isso a ponte que mudou no repositório nunca vira root por
# aqui; ela só entra pelo install.
#
# CÓDIGOS DE SAÍDA: 0 repôs ou já estava · 2 erro · 3 sem reserva ·
#                   4 a reserva não confere com o sha256 · 5 a regra não passa no visudo
set -euo pipefail
umask 077
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# A raiz do sistema. Vazia de propósito: os testes trocam esta linha numa cópia.
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

# O sha256 tem de nomear as duas peças, e só elas: um nome a mais seria um
# caminho que este script não escolheu.
nomes="$(awk '{print $NF}' "$SOMAS" | sort | tr '\n' ' ')"
[ "$nomes" = "49-meowsystem-ponte ponte_root.sh " ] || sair "a lista da reserva não confere" 4
(cd "$RESERVA" && sha256sum --check --strict --quiet "$SOMAS") >/dev/null 2>&1 \
  || sair "a reserva não confere com o sha256" 4

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cp "$RESERVA/49-meowsystem-ponte" "$TMP/regra"
chmod 0440 "$TMP/regra"
visudo -c -q -f "$TMP/regra" >/dev/null 2>&1 || sair "a regra da reserva não passa no visudo" 5

# A ponte antes da regra. O nome com ponto é ignorado pelo sudo, e o `mv` troca
# de uma vez: não há instante com meia regra em /etc/sudoers.d.
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

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d -p "${TMPDIR:-/tmp}" meow-ffaltura.XXXXXX)" || exit 2
trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }
for f in python3 rsvg-convert convert; do
  command -v "$f" >/dev/null || { echo "fastfetch-altura: pulado — sem $f"; exit 0; }
done

CASA="$T/casa"; FALSO="$T/falso"
mkdir -p "$CASA/.config/meow" "$CASA/.config/fastfetch" "$FALSO"
for b in sudo pkexec su pkill; do
  printf '#!/bin/sh\nexit 1\n' > "$FALSO/$b"; chmod 755 "$FALSO/$b"
done
ALVO="$CASA/.local/share/meowsystem/fastfetch/coquinha.ansi"

aplicar() {
  env -i PATH="$FALSO:/usr/bin:/bin" HOME="$CASA" LANG=C.UTF-8 NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
    FASTFETCH_LOGO_MODO=fixo FASTFETCH_LOGO_GATO=coquinha FASTFETCH_LOGO_CONF=nao \
    FASTFETCH_LOGO_LINHAS=12 FASTFETCH_LOGO_COLUNAS="$1" \
    bash "$RAIZ/scripts/fastfetch_logo.sh" aplicar > "$T/saida" 2>&1
}
avisos() { grep -c '!!.*altura aparada' "$T/saida"; }
estado() { stat -c %Y.%s "$ALVO" 2>/dev/null || echo ausente; }

printf '1. a primeira passada apara, escreve e avisa\n'
aplicar 95
igual "o aviso de altura aparada sai uma vez" "$(avisos)" 1
[ -s "$ALVO" ] && ok "o logo foi escrito" || falha "o logo não foi escrito: $(cat "$T/saida")"
antes="$(estado)"; sleep 1

printf '2. a segunda passada não avisa nem escreve\n'
aplicar 95
igual "sem aviso de altura aparada" "$(avisos)" 0
igual "o logo não foi reescrito" "$(estado)" "$antes"
grep -qE '^ *ok .*12.*37|^ *ok .*altura' "$T/saida" && ok "a linha ok diz as duas alturas" || falha "falta a linha ok com as duas alturas: $(cat "$T/saida")"
sleep 1

printf '3. trocar as colunas avisa de novo, uma vez\n'
aplicar 60
igual "o aviso volta uma vez" "$(avisos)" 1

echo
if [ "$falhas" = 0 ]; then echo "fastfetch-altura: tudo certo"; exit 0; fi
echo "fastfetch-altura: $falhas falha(s)"; exit 1

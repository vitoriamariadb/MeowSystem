#!/usr/bin/env bash
# escala-kdl.sh — o `escala.sh` lê o `cosmic-randr list --kdl` (P76).
#
# Um `cosmic-randr` falso devolve um KDL fixo, com o formato medido nas versões
# 0.1.0 e 1.10 em 09/10/2026: uma saída em 1.25 a 59.951 Hz, uma em 1.00 a
# 144 Hz, e uma desligada. O `saidas()` do script tem de devolver as duas
# ligadas, uma linha cada, com a escala em fração, o modo corrente e o hz com
# três casas — e nada da desligada. Sem COSMIC, sem sessão, sem escrever.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
cat > "$T/bin/cosmic-randr" <<'FIM'
#!/bin/sh
[ "$1 $2" = "list --kdl" ] || exit 2
cat <<'KDL'
output "eDP-1" enabled=#true {
  description make="BOE" model="0x0B02"
  physical 340 190
  position 1920 0
  scale 1.25
  transform "normal"
  modes {
    mode 2560 1600 165000 preferred=#true
    mode 2560 1600 59951 current=#true
  }
}
output "HDMI-A-1" enabled=#true {
  scale 1.00
  modes {
    mode 1920 1080 144000 current=#true preferred=#true
    mode 1920 1080 60000
  }
}
output "DP-2" enabled=#false {
  scale 1.00
  modes {
    mode 1920 1080 60000 current=#true
  }
}
KDL
FIM
chmod 755 "$T/bin/cosmic-randr"
esperado="$(printf 'eDP-1\t1.25\t2560\t1600\t59.951\nHDMI-A-1\t1\t1920\t1080\t144.000')"
veio="$(PATH="$T/bin:$PATH" bash -c "source <(sed -n '/^saidas() {/,/^}/p' '$RAIZ/scripts/escala.sh'); saidas")"
if [ "$veio" = "$esperado" ]; then
  echo "  ok    as duas saídas ligadas, em fração, no modo corrente"
  echo; echo "escala-kdl: tudo certo"; exit 0
fi
echo "  FALHA esperado:"; printf '%s\n' "$esperado" | sed 's/^/        /'
echo "        veio:";     printf '%s\n' "$veio" | sed 's/^/        /'
echo; echo "escala-kdl: 1 falha(s)"; exit 1

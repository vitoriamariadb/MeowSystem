#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AFINA="$RAIZ/scripts/afinar_conversor.py"
MAPA="$RAIZ/packs/meowsystem/icones/apps-convertidos.map"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()   { printf 'ok: %s\n' "$1"; }
falha(){ printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas+1)); }

[ -f "$AFINA" ] || { printf 'pulado: sem scripts/afinar_conversor.py\n'; exit 0; }
for f in python3 rsvg-convert compare; do
  command -v "$f" >/dev/null || { printf 'pulado: falta %s\n' "$f"; exit 0; }
done
python3 -c 'import numpy' 2>/dev/null || { printf 'pulado: falta numpy\n'; exit 0; }
[ -f "/usr/share/icons/Papirus/64x64/apps/org.gnome.Calculator.svg" ] \
  || { printf 'pulado: o Papirus não está nesta máquina\n'; exit 0; }

antes="$(md5sum "$MAPA" | cut -d' ' -f1)"

python3 "$AFINA" --grade-teste --so org.gnome.Calculator --so org.gnome.FileRoller \
  --json >"$T/saida.json" 2>"$T/err"
rc=$?
[ "$rc" = 0 ] || [ "$rc" = 1 ] \
  || { falha "o afinador saiu com $rc: $(head -2 "$T/err")"; exit "$falhas"; }

depois="$(md5sum "$MAPA" | cut -d' ' -f1)"
[ "$antes" = "$depois" ] \
  && ok "sem --escrever o mapa não mudou um byte" \
  || falha "o mapa MUDOU sem --escrever — o afinador está decidindo sozinho"

metrica() { python3 -c '
import json,sys
d = json.load(open(sys.argv[1]))
for x in d["linhas"]:
    if x["nome"] == sys.argv[2]:
        print(x.get(sys.argv[3], ""))
        break
' "$T/saida.json" "$1" "$2"; }

forma="$(metrica org.gnome.Calculator forma)"
if [ -n "$forma" ] && [ "$forma" -le 138 ]; then
  ok "Calculadora: a proposta fica a $forma px de 2304 do padrão (teto 138)"
else
  falha "Calculadora: a proposta está a '${forma:-?}' px — a tranca de forma não mordeu"
fi
receita="$(metrica org.gnome.Calculator receita)"
case "$receita" in
  *"--k 2 "*) falha "Calculadora: a busca voltou a escolher --k 2, que é o nó" ;;
  *)          ok "Calculadora: a proposta não é o --k 2 que destruía o teclado" ;;
esac

escrito="$(metrica org.gnome.FileRoller escrito)"
[ -n "$escrito" ] \
  && ok "FileRoller: o afinador enxerga a receita escrita ('$escrito')" \
  || falha "FileRoller: o afinador não leu o campo 4 do mapa"
grep -q "^org.gnome.FileRoller:.*:--k 10 --funde 36 --tol 3.4$" "$MAPA" \
  && ok "FileRoller: a receita dela continua no mapa, intacta" \
  || falha "FileRoller: a receita dela saiu do mapa"

for nome in org.gnome.Calculator org.gnome.FileRoller; do
  r="$(metrica "$nome" receita)"
  if printf '%s' "$r" | grep -qE '^--k [0-9]{1,2} --funde [0-9]{1,3} --tol [0-9]{1,2}(\.[0-9])?( --peso-fronteira [0-9]{1,3})?( --min-traco [0-9]{1,2}(\.[0-9])?)?$'; then
    ok "$nome: a receita casa com a cerca do app"
  else
    falha "$nome: '$r' não casa com _RE_PARAMETROS_DESENHO — o app recusaria"
  fi
done

exit "$falhas"

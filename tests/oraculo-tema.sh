#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CAP="$RAIZ/packs/dracula/temas/capturados/dracula-mauve"
O="$RAIZ/tests/oraculo"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
comparar() { python3 "$RAIZ/scripts/oraculo_tema.py" comparar "$CAP" "$1" "$2"; }

for a in Dark Light; do
  s="$(comparar "$a" "$O/dracula-mauve-$a-5a8bd94.json")"; rc=$?
  [ "$rc" = 0 ] && ok "5a8bd94 $a: igual à cópia em Python" || falha "5a8bd94 $a diverge (rc $rc): $s"
done
s="$(comparar Dark "$O/dracula-mauve-Dark-d77e99f.json")"; rc=$?
[ "$rc" = 0 ] && ok "d77e99f Dark: igual (o Dracula escuro não muda)" || falha "d77e99f Dark diverge (rc $rc): $s"
s="$(comparar Light "$O/dracula-mauve-Light-d77e99f.json")"; rc=$?
if [ "$rc" = 1 ] && [ "$(printf '%s\n' "$s" | grep -c .)" = 1 ] && [[ "$s" == background.component.pressed:* ]]; then
  ok "d77e99f Light: só background.component.pressed difere (a regra do 1.9)"
else
  falha "d77e99f Light: esperado um campo, background.component.pressed (rc $rc): $s"
fi
sed 's/"pressed":"#6F707FE1"/"pressed":"#000000FF"/' "$O/dracula-mauve-Dark-d77e99f.json" > "$T/trocado.json"
s="$(comparar Dark "$T/trocado.json")"; rc=$?
[ "$rc" = 1 ] && [[ "$s" == *background.component.pressed* ]] && ok "uma cor trocada no JSON aparece" || falha "o comparador não viu a cor trocada (rc $rc)"

echo
if [ "$falhas" = 0 ]; then echo "oraculo-tema: tudo certo"; exit 0; fi
echo "oraculo-tema: $falhas falha(s)"; exit 1

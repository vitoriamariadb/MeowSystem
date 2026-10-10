#!/usr/bin/env bash
# oraculo-tema.sh — a cópia em Python da derivação do tema contra o `build()`
# de verdade do libcosmic (P76, `docs/pesquisas/2026-10-09-cosmic-vivo.md` §4.5).
#
# Sem cargo e sem rede: as saídas do oráculo moram em `tests/oraculo/` (ver o
# LEIA.md de lá). A prova que a pesquisa pede, sobre o dracula-mauve:
#   - na revisão do cosmic-settings instalado (d77e99f), as duas árvores saem
#     iguais à cópia em Python, campo a campo;
#   - na do 1.10 (5a8bd94), a Dark sai igual e a Light difere num campo só,
#     `background.component.pressed` — o que decide a hipótese do §2.4;
#   - e o comparador não é cego: uma cor trocada no JSON aparece.
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
  s="$(comparar "$a" "$O/dracula-mauve-$a-d77e99f.json")"; rc=$?
  [ "$rc" = 0 ] && ok "d77e99f $a: igual à cópia em Python" || falha "d77e99f $a diverge (rc $rc): $s"
done
s="$(comparar Dark "$O/dracula-mauve-Dark-5a8bd94.json")"; rc=$?
[ "$rc" = 0 ] && ok "5a8bd94 Dark: igual (o Dracula escuro não muda)" || falha "5a8bd94 Dark diverge (rc $rc): $s"
s="$(comparar Light "$O/dracula-mauve-Light-5a8bd94.json")"; rc=$?
if [ "$rc" = 1 ] && [ "$(printf '%s\n' "$s" | grep -c .)" = 1 ] && [[ "$s" == background.component.pressed:* ]]; then
  ok "5a8bd94 Light: só background.component.pressed difere"
else
  falha "5a8bd94 Light: esperado um campo, background.component.pressed (rc $rc): $s"
fi
sed 's/"pressed":"#6F707FE1"/"pressed":"#000000FF"/' "$O/dracula-mauve-Dark-d77e99f.json" > "$T/trocado.json"
s="$(comparar Dark "$T/trocado.json")"; rc=$?
[ "$rc" = 1 ] && [[ "$s" == *background.component.pressed* ]] && ok "uma cor trocada no JSON aparece" || falha "o comparador não viu a cor trocada (rc $rc)"

echo
if [ "$falhas" = 0 ]; then echo "oraculo-tema: tudo certo"; exit 0; fi
echo "oraculo-tema: $falhas falha(s)"; exit 1

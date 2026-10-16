#!/usr/bin/env bash
# oraculo-tema.sh — a cópia em Python da derivação do tema contra o `build()`
# de verdade do libcosmic (P76, `docs/pesquisas/2026-10-09-cosmic-vivo.md` §4.5).
#
# Sem cargo e sem rede: as saídas do oráculo moram em `tests/oraculo/` (ver o
# LEIA.md de lá). A prova, sobre o dracula-mauve:
#   - na revisão do cosmic-settings 1.10 (5a8bd94), que é o INSTALADO desde
#     15/10/2026, as duas árvores saem iguais à cópia em Python, campo a campo;
#   - na do 1.9 (d77e99f), a Dark sai igual e a Light difere num campo só,
#     `background.component.pressed` — o campo em que o 1.10 mudou a regra;
#   - e o comparador não é cego: uma cor trocada no JSON aparece.
#   [P82, 15/10/2026 (item 19; decisão 49): até aqui a cópia seguia o 1.9 e o
#   1.10 era quem diferia. O 1.10 está instalado, e a cópia passou a segui-lo.]
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

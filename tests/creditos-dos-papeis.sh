#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 3; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT

python3 "$RAIZ/scripts/creditos_dos_papeis.py" --conferir >"$T/real" 2>&1 \
  && ok "os CREDITOS.md do repositório estão em dia com os papeis.tsv dos packs" \
  || falha "rode scripts/creditos_dos_papeis.py: os créditos dos papéis estão fora de dia" "$(cat "$T/real")"

R="$T/raiz"; mkdir -p "$R/docs" "$R/packs/gotico/wallpapers/castelo"
for d in scripts dados; do ln -s "$RAIZ/$d" "$R/$d"; done
printf '# Créditos\n\n## Os papéis de parede\n\nAs fotos vêm de fora.\n\n## Os cursores\n\nDo Catppuccin.\n' > "$R/docs/CREDITOS.md"
printf '{"formato": 2, "id": "gotico", "nome": "Gótico", "licenca": "GPL-3.0-or-later"}\n' > "$R/packs/gotico/pack.json"
printf '# Créditos do pack Gótico\n\n## A paleta\n\nDo Dracula.\n' > "$R/packs/gotico/CREDITOS.md"
for f in castelo/castelo-dia castelo/castelo-noite vitral; do
  printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 3840 2160"><rect width="3840" height="2160"/></svg>\n' \
    > "$R/packs/gotico/wallpapers/$f.svg"
done
printf 'cena\tdia\tnoite\tlicenca\tdata\ncastelo\tcastelo/castelo-dia.svg\tcastelo/castelo-noite.svg\t\t2026-11-17\nvitral\tvitral.svg\t-\tCC0-1.0\t2026-11-18\n' \
  > "$R/packs/gotico/wallpapers/papeis.tsv"

python3 "$R/scripts/creditos_dos_papeis.py" "$R" >"$T/s1" 2>&1
P="$R/packs/gotico/CREDITOS.md"; D="$R/docs/CREDITOS.md"
linha="$(grep '^| Castelo |' "$P")"
[[ $linha == *'<img src="wallpapers/castelo/castelo-dia.svg" alt="Castelo, de dia"'* ]] \
  && [[ $linha == *'<img src="wallpapers/castelo/castelo-noite.svg" alt="Castelo, de noite"'* ]] \
  && [[ $linha == *'| Gótico | GPL-3.0-or-later | 17/11/2026 |' ]] \
  && ok "o CREDITOS.md do pack mostra o par lado a lado, com miniatura, cena, pack, licença e data" \
  || falha "a linha do castelo no CREDITOS.md do pack" "$(cat "$P")"
grep -q '^| Vitral | <img src="wallpapers/vitral.svg" alt="Vitral, de dia" width="200"> | — | Gótico | CC0-1.0 | 18/11/2026 |$' "$P" \
  && ok "papel sem par tem a noite vazia e a licença dele" || falha "a linha do vitral" "$(cat "$P")"
grep -q '<img src="../packs/gotico/wallpapers/castelo/castelo-noite.svg"' "$D" \
  && ok "docs/CREDITOS.md lista os papéis de todo pack, com o caminho até o pack" || falha "docs/CREDITOS.md" "$(cat "$D")"
grep -q '^As fotos vêm de fora\.$' "$D" && grep -q '^## Os cursores$' "$D" && grep -q '^Do Catppuccin\.$' "$D" \
  && ok "as outras seções ficam como estavam" || falha "o gerador comeu seção" "$(cat "$D")"
antes="$(sha256sum "$P" "$D")"
python3 "$R/scripts/creditos_dos_papeis.py" "$R" >"$T/s2" 2>&1
[ "$(sha256sum "$P" "$D")" = "$antes" ] && [ ! -s "$T/s2" ] && ok "a segunda passada não escreve nada" || falha "a segunda passada escreveu" "$(cat "$T/s2")"
python3 "$R/scripts/creditos_dos_papeis.py" --conferir "$R" >/dev/null 2>&1 && ok "e o conferir diz em dia" || falha "o conferir diverge depois de escrever"
printf 'cena\tdia\tnoite\tlicenca\tdata\ncastelo\tcastelo/castelo-dia.svg\tcastelo/castelo-noite.svg\t\t2026-11-19\n' > "$R/packs/gotico/wallpapers/papeis.tsv"
python3 "$R/scripts/creditos_dos_papeis.py" --conferir "$R" >/dev/null 2>&1 && falha "o conferir não viu a data nova" || ok "o conferir vê o papeis.tsv que mudou"
rm -f "$R/packs/gotico/wallpapers/papeis.tsv"
python3 "$R/scripts/creditos_dos_papeis.py" "$R" >/dev/null 2>&1
! grep -q 'Os papéis de parede desenhados' "$P" "$D" && grep -q '^## A paleta$' "$P" \
  && ok "sem papeis.tsv a seção sai e o resto fica" || falha "a seção ficou" "$(cat "$P")"

printf 'cena\tdia\tnoite\tlicenca\tdata\ncastelo\tcastelo/castelo-dia.svg\tcastelo/castelo-noite.svg\t\t2026-11-17\n' > "$R/packs/gotico/wallpapers/papeis.tsv"
env -i PATH="$PATH" HOME="$T/casa" LANG=C.UTF-8 MEOW_PACKS="$R/packs" PYTHONDONTWRITEBYTECODE=1 \
  python3 - "$RAIZ" "$R/packs/gotico" <<'PY' || falhas=$((falhas + 1))
import os
import sys
from urllib.parse import quote
sys.path.insert(0, os.path.join(sys.argv[1], "scripts", "app"))
import servidor
gotico = sys.argv[2]
papeis = [p for p in servidor._creditos_dos_papeis() if p["pack"] == "gotico"]
dia = os.path.join(gotico, "wallpapers", "castelo", "castelo-dia.svg")
noite = os.path.join(gotico, "wallpapers", "castelo", "castelo-noite.svg")
esperado = [{"cena": "castelo", "pack": "gotico", "nome_do_pack": "Gótico", "licenca": "GPL-3.0-or-later",
             "data": "2026-11-17", "dia": "/previa?tipo=arquivo&id=" + quote(dia, safe=""),
             "noite": "/previa?tipo=arquivo&id=" + quote(noite, safe="")}]
if papeis == esperado and {dia, noite} <= servidor._ICONES_DECLARADOS:
    print("ok: a página de créditos do painel recebe o par com as miniaturas liberadas")
else:
    print("FALHOU: créditos do painel: %r" % papeis, file=sys.stderr)
    sys.exit(1)
PY
grep -q 'creditosDosPapeis()' "$RAIZ/scripts/app/pagina/paginas.js" && grep -q '"/api/creditos-papeis"' "$RAIZ/scripts/app/servidor.py" \
  && ok "o passo Papel de parede mostra o bloco Autoria" || falha "o bloco Autoria não está na página"

if [ "$falhas" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$falhas" >&2
  exit 1
fi
exit 0

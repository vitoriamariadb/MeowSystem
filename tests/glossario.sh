#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$RAIZ" || exit 2
LEVA="docs/sprints/2026-11-10-a-casca-do-painel"
command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }
[ -f "$LEVA/GLOSSARIO.md" ] || { printf 'FALHOU: sem %s/GLOSSARIO.md\n' "$LEVA" >&2; exit 1; }

python3 -I - "$RAIZ" "$LEVA" <<'PY'
import re
import subprocess
import sys
from pathlib import Path

raiz, leva = Path(sys.argv[1]), sys.argv[2]
glossario = (raiz / leva / "GLOSSARIO.md").read_text(encoding="utf-8")

AINDA_NA_TELA_DE_OUTRO_BLOCO = set()
A_RESPOSTA_TROCOU_SO_O_OUTRO_TERMO_DA_LINHA = {"Próxima imagem"}
TERMOS_QUE_OUTRO_CONTROLE_USA = {
    "Voltar", "Conferir", "Ver", "Refazer", "Aplicar", "Registro", "Detalhe", "Girar", "Manter",
}

saida = subprocess.run([sys.executable, "-I", str(raiz / leva / "relatorios" / "textos_da_tela.py"), str(raiz)],
                       capture_output=True, text=True, check=True).stdout.splitlines()
na_tela = {}
for linha in saida[2:]:
    campos = linha.split("\t")
    na_tela.setdefault(campos[0].strip().casefold(), campos[-1])

trocados = []
for linha in glossario.splitlines():
    if not linha.startswith("|"):
        continue
    celulas = [c.strip() for c in linha.strip().strip("|").split("|")]
    if len(celulas) != 3 or celulas[0] in ("hoje", "---") or set(celulas[0]) <= {"-", " "}:
        continue
    hoje, proposto, resposta = celulas
    r = resposta.casefold()
    if r.startswith("fica") or (r.startswith("não") and "original" in r):
        continue
    termos = []
    for t in hoje.split(" · "):
        t = t.strip()
        if re.search(r"\(.*\)\s*$", t) or t.startswith("N ") or t.startswith("Botão direito"):
            continue
        termos.append(t)
    if any(t.casefold() in r for t in termos):
        continue
    trocados += termos

falhas = 0
for termo in ("Voltar a girar", "Aplicar agora"):
    onde = na_tela.get(termo.casefold())
    if onde:
        print(f"FALHOU: «{termo}» saiu da linha na P200 e voltou à tela ({onde})", file=sys.stderr)
        falhas += 1
for termo in trocados:
    if termo in AINDA_NA_TELA_DE_OUTRO_BLOCO or termo in TERMOS_QUE_OUTRO_CONTROLE_USA \
            or termo in A_RESPOSTA_TROCOU_SO_O_OUTRO_TERMO_DA_LINHA:
        continue
    onde = na_tela.get(termo.casefold())
    if onde:
        print(f"FALHOU: «{termo}» foi trocado no glossário e voltou à tela ({onde})", file=sys.stderr)
        falhas += 1

if len(trocados) < 100:
    print(f"FALHOU: o glossário rendeu só {len(trocados)} termos trocados; a leitura da tabela quebrou", file=sys.stderr)
    falhas += 1
if falhas:
    sys.exit(1)
print(f"ok: nenhum dos {len(trocados)} termos trocados do glossário voltou à tela")
PY

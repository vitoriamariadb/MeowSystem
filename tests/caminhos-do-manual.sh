#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v git >/dev/null 2>&1 || { printf 'pulado: sem git\n'; exit 0; }
git -C "$RAIZ" rev-parse --git-dir >/dev/null 2>&1 || {
  printf 'pulado: %s não é um clone git\n' "$RAIZ"; exit 0; }

printf 'o manual: todo caminho citado existe na árvore\n\n'

python3 -I - "$RAIZ" <<'PY'
import glob
import os
import re
import subprocess
import sys

raiz = sys.argv[1]
saida = subprocess.run(["git", "-C", raiz, "ls-files", "-z"], capture_output=True, check=True).stdout
versionados = [p for p in saida.decode().split("\0") if p]
raizes = {p.split("/", 1)[0] for p in versionados}

documentos = sorted(
    [p for p in versionados if re.fullmatch(r"docs/[^/]+\.md", p)]
    + [p for p in versionados if re.fullmatch(r"README[^/]*\.md", p)]
    + [p for p in ("AGENTS.md", "GSD.md") if p in versionados]
)

inicio = re.compile(r"^(?:%s)(?:[/:]|$)" % "|".join(re.escape(r) for r in sorted(raizes, key=len, reverse=True)))


def expandir_chaves(texto):
    achado = re.search(r"\{([^{}]*,[^{}]*)\}", texto)
    if not achado:
        return [texto]
    saida = []
    for opcao in achado.group(1).split(","):
        saida.extend(expandir_chaves(texto[: achado.start()] + opcao + texto[achado.end():]))
    return saida


def candidato(trecho):
    palavra = trecho.strip().split()[0] if trecho.strip() else ""
    if not inicio.match(palavra):
        return None
    palavra = re.split(r"…|\.\.\.", palavra)[0]
    palavra = re.sub(r"<[^>]*>", "*", palavra)
    palavra = re.sub(r"\$\{?[A-Za-z_][A-Za-z0-9_]*\}?", "*", palavra)
    palavra = re.sub(r":[^/]*$", "", palavra)
    palavra = palavra.rstrip(".,;)")
    return palavra or None


def existe(caminho):
    for variante in expandir_chaves(caminho):
        alvo = os.path.join(raiz, variante.rstrip("/"))
        if glob.glob(alvo):
            continue
        return False
    return True


mortos = []
total = 0
for doc in documentos:
    cerca = False
    with open(os.path.join(raiz, doc), encoding="utf-8") as arq:
        for numero, linha in enumerate(arq, 1):
            if linha.lstrip().startswith("```"):
                cerca = not cerca
                continue
            if cerca:
                continue
            for trecho in re.findall(r"`([^`\n]+)`", linha):
                caminho = candidato(trecho)
                if caminho is None:
                    continue
                total += 1
                if not existe(caminho):
                    mortos.append("%s:%d: %s" % (doc, numero, caminho))

if mortos:
    for m in mortos:
        print("  NÃO  " + m, file=sys.stderr)
    print("\n%d de %d caminhos citados não existem" % (len(mortos), total), file=sys.stderr)
    sys.exit(1)
print("  ok   %d caminhos citados em %d documentos, todos existem" % (total, len(documentos)))
PY

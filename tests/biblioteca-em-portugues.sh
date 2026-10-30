#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/casa" "$T/falso"
printf '#!/bin/sh\nprintf "sudo: recusado pelo tests/biblioteca-em-portugues.sh\\n" >&2\nexit 1\n' > "$T/falso/sudo"
chmod 755 "$T/falso/sudo"

env -i PATH="$T/falso:$PATH" HOME="$T/casa" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
  python3 - "$RAIZ" <<'PY'
import importlib.util
import json
import os
import re
import sys

raiz = sys.argv[1]
spec = importlib.util.spec_from_file_location("pack", os.path.join(raiz, "scripts", "pack.py"))
pack = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pack)
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor  # noqa: E402

painel = servidor.Manipulador.__new__(servidor.Manipulador)
painel._nomes_de_app = dict

INGLES = {
    "file", "folder", "open", "root", "books", "calculator", "camera", "browser", "music", "phone", "player",
    "network", "notifications", "search", "security", "star", "key", "lock", "rocket", "palette", "earth", "moon",
    "power", "workflow", "workflows", "todo", "config", "benchmark", "binary", "batch", "license", "contributing",
    "cleaner", "compressor", "recorder", "screen", "photo", "admin", "assets", "audio", "client", "command",
    "components", "connection", "constant", "content", "controllers", "core", "database", "debug", "dist", "docs",
    "download", "examples", "fonts", "functions", "images", "locales", "messages", "packages", "private",
    "public", "queue", "routes", "server", "shared", "styles", "templates", "temp", "tests", "themes", "types",
    "upload", "utils", "video", "animation", "audit", "coverage",
}
falhas = []


def confere(cond, frase, detalhe=""):
    print(("ok: " if cond else "FALHOU: ") + frase)
    if not cond:
        falhas.append(frase)
        if detalhe:
            print("    " + detalhe, file=sys.stderr)


for ident in ("meowsystem", "dracula"):
    pasta = os.path.join(raiz, "packs", ident, "icones", "biblioteca")
    svgs = sorted(a for a in os.listdir(pasta) if a.endswith(".svg"))
    try:
        with open(os.path.join(pasta, "catalog.json"), encoding="utf-8") as fh:
            catalogo = json.load(fh)
    except (OSError, ValueError):
        catalogo = {}
    sem = [a for a in svgs if not str((catalogo.get(a) or {}).get("descricao") or "").strip()]
    confere(bool(svgs) and not sem, f"{ident}: todo SVG da Biblioteca tem descrição no catálogo ({len(svgs)})",
            f"{len(sem)} sem: {sem[:8]}")

    ofertados = [i for i in pack.acervo_para_levar(None, "biblioteca", ident) if i["de"] == ident]
    confere(len(ofertados) == len(svgs),
            f"{ident}: o painel oferece os {len(svgs)} ícones da Biblioteca ({len(ofertados)})")
    ingleses = sorted({i["rotulo"] for i in ofertados
                       if INGLES & set(re.findall(r"[a-z]+", i["rotulo"].lower()))})
    confere(not ingleses, f"{ident}: nenhum rótulo da Biblioteca é palavra comum em inglês",
            f"{len(ingleses)}: {ingleses[:8]}")

GRAFIA = {
    ("meowsystem", "npm"): "npm", ("meowsystem", "pnpm"): "pnpm", ("meowsystem", "esbuild"): "esbuild",
    ("meowsystem", "macos"): "macOS", ("meowsystem", "webpack"): "webpack", ("meowsystem", "uv"): "uv",
    ("meowsystem", "mdbook"): "mdBook", ("meowsystem", "_folder"): "Pasta",
    ("dracula", "dbt"): "dbt, transformação de dados", ("dracula", "005-potion"): "Poção",
}
for ident in ("meowsystem", "dracula"):
    servidos = {i["nome"]: i["rotulo"] for i in pack.acervo_para_levar(None, "biblioteca", ident) if i["de"] == ident}
    erradas = [f"{nome}: {servidos.get(nome)!r} em vez de {certo!r}"
               for (de, nome), certo in GRAFIA.items() if de == ident and servidos.get(nome) != certo]
    confere(not erradas, f"{ident}: o rótulo da Biblioteca guarda a grafia da marca e sobe a letra da palavra comum",
            "; ".join(erradas))
    pasta = os.path.join(raiz, "packs", ident, "icones", "biblioteca")
    with open(os.path.join(pasta, "catalog.json"), encoding="utf-8") as fh:
        catalogo = json.load(fh)
    rotulos_da_busca = {os.path.basename(c): r for c, r in painel._textos_da_busca(pack)[1].items()
                        if os.path.dirname(c) == os.path.normpath(pasta)}
    divergem = sorted(a for a in catalogo
                      if a.endswith(".svg") and rotulos_da_busca.get(a) != servidos.get(a[:-4]))
    confere(not divergem, f"{ident}: a busca do painel e a aba Biblioteca dão o mesmo rótulo",
            f"{len(divergem)}: " + ", ".join(f"{a} {rotulos_da_busca.get(a)!r}/{servidos.get(a[:-4])!r}"
                                            for a in divergem[:6]))

if falhas:
    print("FALHOU: a Biblioteca não fala português", file=sys.stderr)
    sys.exit(1)
print("ok: a Biblioteca dos dois packs fala português")
PY

#!/usr/bin/env python3
"""Compara o produto do oráculo (o `build()` de verdade) com a cópia em Python.

    oraculo_tema.py comparar <dir-da-captura> <Dark|Light> <json-do-oraculo>
    oraculo_tema.py efeito <icones> <fonte> <mono> json <json-do-oraculo>...
    oraculo_tema.py efeito <icones> <fonte> <mono> disco <casa-do-tema>...

O JSON é a saída do `meow-oraculo-tema` (`src/oraculo-tema`) sobre a receita
`com.system76.CosmicTheme.<Árvore>.Builder` da captura, na versão que ela traz. A cópia em Python é
o `build()` do `scripts/derivar_flavor.py`, portado da revisão c003a58 do
libcosmic. Cada campo de cor que o Python calcula é procurado no JSON pelo
mesmo caminho (`background` + `component.pressed` -> `background.component.pressed`)
e comparado em hex, que é a grafia em que o COSMIC escreve no disco.

Sai 0 quando as duas derivações dão o mesmo tema; 1 com a lista do que
diverge, um campo por linha; 2 em erro. É o teste lado a lado que a pesquisa
pede (`git show 1b15ccb1^:docs/pesquisas/2026-10-09-cosmic-vivo.md` §4.5): divergência vira aviso,
e é ela que decide se a cópia em Python ainda é a derivação do COSMIC
instalado.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "scripts"))
import derivar_flavor as df  # noqa: E402
import derivar_acento as da  # noqa: E402


def _hex_json(v):
    if v is None:
        return None
    if isinstance(v, str):
        return v.upper()
    if isinstance(v, dict) and "red" in v:
        return da.para_hex((v["red"], v["green"], v["blue"], v["alpha"])).upper()
    return None


def _no_json(tema: dict, arq: str, caminho: str):
    no = tema.get(arq)
    for parte in caminho.split("."):
        if not isinstance(no, dict) or parte not in no:
            return None
        no = no[parte]
    return no


def comparar(captura: Path, arvore: str, json_oraculo: Path) -> list[str]:
    receita = df._ler_arvore(da.receita_da_captura(captura, arvore))
    if not receita:
        raise ValueError(f"a captura não tem a receita {arvore}.Builder")
    b = df.build(df.ler_receita(receita))
    tema = json.loads(json_oraculo.read_text(encoding="utf-8"))
    diverge = []
    for arq, cams in df._hex_do_build(b).items():
        for cam, hexa in sorted(cams.items()):
            valor = tema.get("shade") if arq == "shade" else _no_json(tema, arq, cam)
            atual = _hex_json(valor)
            if atual is None:
                diverge.append(f"{arq}.{cam}: o oráculo não tem este campo")
                continue
            if atual != hexa.upper():
                diverge.append(f"{arq}.{cam}: python {hexa} · oráculo {atual}")
    esperado = da.para_hex(b["accent_text"]) if b["accent_text"] else None
    atual = _hex_json(tema.get("accent_text"))
    if (esperado or "").upper() != (atual or ""):
        diverge.append(f"accent_text: python {esperado} · oráculo {atual}")
    return diverge


ICONES_PADRAO = "Cosmic"


def _familia(texto) -> str:
    if isinstance(texto, dict):
        return str(texto.get("family", ""))
    achou = re.search(r'family:\s*"([^"]*)"', texto or "")
    return achou.group(1) if achou else ""


def _campos_do_json(arq: Path) -> dict:
    tema = json.loads(arq.read_text(encoding="utf-8"))
    campos = {}
    for chave in ("icon_theme", "font", "mono_font"):
        if chave in tema:
            campos[chave] = tema[chave]
    return campos


def _campos_do_disco(casa: Path) -> dict:
    def ler(nome):
        try:
            return (casa / nome).read_text(encoding="utf-8").strip()
        except OSError:
            return None

    icone = ler("icon_theme")
    return {
        "icon_theme": icone.strip('"') if icone else ICONES_PADRAO,
        "font": ler("font") or "",
        "mono_font": ler("mono_font") or "",
    }


def efeito(icones: str, fonte: str, mono: str, campos_por_origem: list) -> list[str]:
    diverge = []
    for origem, campos in campos_por_origem:
        if "icon_theme" in campos and campos["icon_theme"] != icones:
            diverge.append(f"{origem}: icon_theme é '{campos['icon_theme']}', o pack pede '{icones}'")
        if fonte and "font" in campos and _familia(campos["font"]) != fonte:
            diverge.append(f"{origem}: font é '{_familia(campos['font'])}', a interface_font é '{fonte}'")
        if mono and "mono_font" in campos and _familia(campos["mono_font"]) != mono:
            diverge.append(f"{origem}: mono_font é '{_familia(campos['mono_font'])}', o pack pede '{mono}'")
    return diverge


def main_efeito(args: list[str]) -> int:
    if len(args) < 5 or args[3] not in ("json", "disco"):
        print(__doc__.strip().splitlines()[3], file=sys.stderr)
        return 2
    icones, fonte, mono, modo, origens = args[0], args[1], args[2], args[3], args[4:]
    try:
        if modo == "json":
            pares = [(Path(o).name, _campos_do_json(Path(o))) for o in origens]
        else:
            pares = [("/".join(Path(o).parts[-2:]), _campos_do_disco(Path(o))) for o in origens]
    except (OSError, ValueError) as e:
        print(f"erro: {e}", file=sys.stderr)
        return 2
    diverge = efeito(icones, fonte, mono, pares)
    for linha in diverge:
        print(linha)
    return 1 if diverge else 0


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "efeito":
        return main_efeito(sys.argv[2:])
    if len(sys.argv) != 5 or sys.argv[1] != "comparar" or sys.argv[3] not in ("Dark", "Light"):
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        return 2
    try:
        diverge = comparar(Path(sys.argv[2]), sys.argv[3], Path(sys.argv[4]))
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as e:
        print(f"erro: {e}", file=sys.stderr)
        return 2
    for linha in diverge:
        print(linha)
    return 1 if diverge else 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Compara o produto do oráculo (o `build()` de verdade) com a cópia em Python.

    oraculo_tema.py comparar <dir-da-captura> <Dark|Light> <json-do-oraculo>

O JSON é a saída do `meow-oraculo-tema` (`src/oraculo-tema`) sobre a receita
`com.system76.CosmicTheme.<Árvore>.Builder/v2` da captura. A cópia em Python é
o `build()` do `scripts/derivar_flavor.py`, portado da revisão c003a58 do
libcosmic. Cada campo de cor que o Python calcula é procurado no JSON pelo
mesmo caminho (`background` + `component.pressed` -> `background.component.pressed`)
e comparado em hex, que é a grafia em que o COSMIC escreve no disco.

Sai 0 quando as duas derivações dão o mesmo tema; 1 com a lista do que
diverge, um campo por linha; 2 em erro. É o teste lado a lado que a pesquisa
pede (`docs/pesquisas/2026-10-09-cosmic-vivo.md` §4.5): divergência vira aviso,
e é ela que decide se a cópia em Python ainda é a derivação do COSMIC
instalado.
"""
from __future__ import annotations

import json
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
    receita = df._ler_arvore(captura / f"com.system76.CosmicTheme.{arvore}.Builder" / "v2")
    if not receita:
        raise ValueError(f"a captura não tem a receita {arvore}.Builder/v2")
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


def main() -> int:
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

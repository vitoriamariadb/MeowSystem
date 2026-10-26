#!/usr/bin/env python3
import json
import re
import sys

MARCA = re.compile(r"\{\{([a-z0-9_]+)(?::([0-9a-fA-F]{2}|rgb))?\}\}")
RESTO = re.compile(r"\{\{[^{}]*\}\}")


def main(argv):
    so_nome = len(argv) == 4 and argv[1] == "--nome"
    if len(argv) != 5 and not so_nome:
        sys.stderr.write("uso: modelo.py <modelo> <paleta.json> <flavor> <pack>\n"
                         "     modelo.py --nome <paleta.json> <flavor>\n")
        return 2
    if so_nome:
        modelo, paleta, flavor, pack = None, argv[2], argv[3], ""
    else:
        _, modelo, paleta, flavor, pack = argv
    try:
        with open(paleta, encoding="utf-8") as fh:
            pal = json.load(fh)
        texto = ""
        if modelo is not None:
            with open(modelo, encoding="utf-8") as fh:
                texto = fh.read()
    except (OSError, ValueError) as e:
        sys.stderr.write(f"não consegui ler: {e}\n")
        return 2
    cores = (pal.get("flavors") or {}).get(flavor)
    if not isinstance(cores, dict):
        sys.stderr.write(f"flavor {flavor!r} não existe em {paleta}\n")
        return 2
    claro = flavor in (pal.get("claros") or [])
    extras = {
        "nome": (pal.get("nomes") or {}).get(flavor) or flavor,
        "flavor": flavor,
        "pack": pack,
        "tipo": "light" if claro else "dark",
        "tipo_inverso": "dark" if claro else "light",
    }
    if so_nome:
        print(extras["nome"])
        return 0
    faltou = []

    def trocar(m):
        papel, forma = m.group(1), m.group(2)
        if forma is None and papel in extras:
            return extras[papel]
        hexa = cores.get(papel)
        if not isinstance(hexa, str) or not re.fullmatch(r"#[0-9A-Fa-f]{6}", hexa):
            faltou.append(m.group(0))
            return m.group(0)
        if forma is None:
            return hexa
        if forma == "rgb":
            return ", ".join(str(int(hexa[i:i + 2], 16)) for i in (1, 3, 5))
        return hexa + forma

    saida = MARCA.sub(trocar, texto)
    faltou += [r for r in RESTO.findall(saida) if r not in faltou]
    if faltou:
        sys.stderr.write(f"{modelo}: papel que a paleta não tem: {', '.join(sorted(set(faltou)))}\n")
        return 2
    sys.stdout.write(saida)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

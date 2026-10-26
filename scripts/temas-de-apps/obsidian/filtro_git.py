#!/usr/bin/env python3
import json
import re
import subprocess
import sys

RE_TEMA = re.compile(r'("cssTheme"\s*:\s*)"((?:[^"\\]|\\.)*)"')


def _git(*args):
    r = subprocess.run(["git", *args], capture_output=True)
    return r.stdout.decode("utf-8", "replace") if r.returncode == 0 else None


def _trocar(texto, valor):
    if valor is None or not RE_TEMA.search(texto):
        return texto
    escrito = json.dumps(valor, ensure_ascii=False)
    return RE_TEMA.sub(lambda m: m.group(1) + escrito, texto, count=1)


def vestir(texto):
    tema = _git("config", "--get", "meow.obsidian-tema")
    return _trocar(texto, tema.rstrip("\n") if tema else None)


def limpar(texto, caminho):
    do_cofre = _git("cat-file", "blob", ":" + caminho) or _git("cat-file", "blob", "HEAD:" + caminho)
    if do_cofre is None:
        return texto
    achado = RE_TEMA.search(do_cofre)
    if not achado:
        return texto
    saida = _trocar(texto, json.loads('"' + achado.group(2) + '"'))
    if do_cofre.endswith("\n") and not saida.endswith("\n"):
        saida += "\n"
    elif not do_cofre.endswith("\n") and saida.endswith("\n"):
        saida = saida.rstrip("\n")
    return saida


def main(argv):
    texto = sys.stdin.buffer.read().decode("utf-8", "surrogateescape")
    if len(argv) == 2 and argv[1] == "vestir":
        saida = vestir(texto)
    elif len(argv) == 3 and argv[1] == "limpar":
        saida = limpar(texto, argv[2])
    else:
        sys.stderr.write("uso: filtro_git.py vestir | limpar <caminho>\n")
        sys.stdout.buffer.write(texto.encode("utf-8", "surrogateescape"))
        return 2
    sys.stdout.buffer.write(saida.encode("utf-8", "surrogateescape"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

#!/usr/bin/env python3

from __future__ import annotations

import argparse
import glob
import os
import re
import sys

COSMIC_DIR = os.environ.get("MEOW_COSMIC_DIR") or os.path.join(os.path.expanduser("~"), ".config", "cosmic")

ALPHA_OPACO = "FF"

MEOW_OK = 0
MEOW_DIVERGENTE = 1

RE_BASE = re.compile(r'base\s*:\s*"#([0-9A-Fa-f]{6})([0-9A-Fa-f]{2})?"')


def achar_base_raiz(texto: str):
    profundidade = 0
    em_string = False
    escapado = False
    i = 0
    n = len(texto)
    while i < n:
        c = texto[i]
        if em_string:
            if escapado:
                escapado = False
            elif c == "\\":
                escapado = True
            elif c == '"':
                em_string = False
            i += 1
            continue
        if c == '"':
            em_string = True
            i += 1
            continue
        if c == "(":
            profundidade += 1
            i += 1
            continue
        if c == ")":
            profundidade -= 1
            i += 1
            continue
        if profundidade == 1 and texto.startswith("base", i):
            anterior = texto[i - 1] if i > 0 else " "
            if not (anterior.isalnum() or anterior == "_"):
                m = RE_BASE.match(texto, i)
                if m:
                    return m
        i += 1
    return None


def ler(caminho: str):
    try:
        with open(caminho, "r", encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return None


def alpha_de(caminho: str):
    texto = ler(caminho)
    if texto is None:
        return None
    m = achar_base_raiz(texto)
    if not m:
        return None
    return (m.group(2) or ALPHA_OPACO).upper()


def escrever_alpha(caminho: str, alvo: str) -> bool:
    texto = ler(caminho)
    if texto is None:
        return False
    m = achar_base_raiz(texto)
    if not m:
        return False
    atual = (m.group(2) or ALPHA_OPACO).upper()
    if atual == alvo:
        return False
    novo = texto[: m.start()] + 'base: "#%s%s"' % (m.group(1), alvo) + texto[m.end() :]
    tmp = caminho + ".meow-tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(novo)
    try:
        st = os.stat(caminho)
        os.chmod(tmp, st.st_mode & 0o7777)
    except OSError:
        pass
    os.replace(tmp, caminho)
    return True


def temas():
    achados = []
    padrao = os.path.join(COSMIC_DIR, "com.system76.CosmicTheme.*", "v*")
    for caminho in sorted(glob.glob(padrao)):
        if ".Builder" in caminho or not os.path.isdir(caminho):
            continue
        if glob.glob(os.path.join(caminho, "transparent_*")):
            achados.append(caminho)
    return achados


def nome_curto(dir_tema: str) -> str:
    return os.path.basename(os.path.dirname(dir_tema)).replace("com.system76.CosmicTheme.", "")


def avisar_se_nativo(dirs) -> None:
    for dir_tema in dirs:
        for caminho in sorted(glob.glob(os.path.join(dir_tema, "*maxim*"))):
            print("  !!   o COSMIC criou %s" % os.path.basename(caminho))
            print("       a opção nativa (cosmic-panel#457) parece ter chegado —")
            print("       esta correção pode ser aposentada em favor da de fábrica")
            return


def frosted_windows_ligado(dir_tema: str) -> bool:
    texto = ler(os.path.join(dir_tema, "frosted_windows"))
    if texto is None:
        return True
    return texto.strip() == "true"


def pares(dir_tema: str):
    for origem in sorted(glob.glob(os.path.join(dir_tema, "transparent_*"))):
        destino = os.path.join(dir_tema, os.path.basename(origem)[len("transparent_") :])
        if os.path.isfile(destino):
            yield origem, destino


def alvo_de(origem: str, forcar_opaco: bool):
    return ALPHA_OPACO if forcar_opaco else alpha_de(origem)


def planejar(dirs, restaurar: bool):
    fora = []
    for dir_tema in dirs:
        forcar = restaurar or not frosted_windows_ligado(dir_tema)
        for origem, destino in pares(dir_tema):
            alvo = alvo_de(origem, forcar)
            atual = alpha_de(destino)
            if alvo is None or atual is None:
                continue
            if alvo != atual:
                fora.append((dir_tema, destino, atual, alvo))
    return fora


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Vidro fosco também na janela maximizada (COSMIC)")
    ap.add_argument("--conferir", action="store_true",
                    help="não escreve; sai 1 se houver divergência")
    ap.add_argument("--restaurar", action="store_true",
                    help="devolve o alpha de fábrica (FF)")
    args = ap.parse_args()

    dirs = temas()
    if not dirs:
        print("  --   nenhum tema COSMIC em disco — nada a fazer")
        return MEOW_OK

    avisar_se_nativo(dirs)
    fora = planejar(dirs, args.restaurar)

    if args.conferir:
        if not fora:
            print("  ok   vidro da janela maximizada: consistente")
            return MEOW_OK
        for dir_tema, destino, atual, alvo in fora:
            print("  !=   %s/%s: alpha %s, deveria ser %s"
                  % (nome_curto(dir_tema), os.path.basename(destino), atual, alvo))
        return MEOW_DIVERGENTE

    if not fora:
        print("  --   vidro da janela maximizada: nada a fazer")
        return MEOW_OK

    for dir_tema, destino, atual, alvo in fora:
        if escrever_alpha(destino, alvo):
            print("  ok   %s/%s: alpha %s -> %s"
                  % (nome_curto(dir_tema), os.path.basename(destino), atual, alvo))
    return MEOW_OK


if __name__ == "__main__":
    sys.exit(main())

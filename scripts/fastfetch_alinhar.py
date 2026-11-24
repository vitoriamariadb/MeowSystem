#!/usr/bin/env python3

import argparse
import os
import re
import sys

ESCAPE = re.compile(r"\x1b\[[0-9;?]*[a-zA-Z]")


def _inteiro(valor, padrao, nome):
    try:
        return max(int(str(valor).strip()), 0)
    except (TypeError, ValueError):
        print("meow-fetch: %s=%r não é número — usando %r"
              % (nome, valor, padrao), file=sys.stderr)
        return padrao


def _visivel(linha):
    return ESCAPE.sub("", linha)


def _cortar(linha, colunas):
    saida, contadas = [], 0
    for pedaco in ESCAPE.split(linha) if False else re.split(r"(\x1b\[[0-9;?]*[a-zA-Z])", linha):
        if not pedaco:
            continue
        if ESCAPE.fullmatch(pedaco):
            saida.append(pedaco)
            continue
        if contadas >= colunas:
            continue
        cabe = pedaco[: colunas - contadas]
        saida.append(cabe)
        contadas += len(cabe)
    return "".join(saida)


def _ler_gato(caminho):
    try:
        with open(os.path.expanduser(caminho), encoding="utf-8", errors="replace") as f:
            bruto = f.read()
    except OSError:
        return []
    linhas = bruto.rstrip("\n").split("\n")
    return linhas if any(_visivel(l).strip() for l in linhas) else []


TRACOS = set("-—–─━═_=")


def _e_separador(linha):
    v = _visivel(linha).strip()
    return len(v) >= 3 and set(v) <= TRACOS


_SGR = re.compile(r"\x1b\[([0-9;]*)m")


def _e_fundo(params):
    campos = [c for c in params.split(";")]
    i, resposta = 0, None
    while i < len(campos):
        c = campos[i] or "0"
        try:
            n = int(c)
        except ValueError:
            i += 1
            continue
        if n in (38, 48, 58):
            seguinte = campos[i + 1] if i + 1 < len(campos) else ""
            salto = 5 if seguinte == "2" else (3 if seguinte == "5" else 1)
            if n == 48:
                resposta = True
            i += salto
            continue
        if n == 0 or n == 49:
            resposta = False
        elif 40 <= n <= 47 or 100 <= n <= 107:
            resposta = True
        i += 1
    return resposta


def _largura_pintada(linha):
    fundo, coluna, ultima = False, 0, 0
    for pedaco in re.split(r"(\x1b\[[0-9;?]*[a-zA-Z])", linha):
        if not pedaco:
            continue
        m = _SGR.fullmatch(pedaco)
        if m is not None:
            r = _e_fundo(m.group(1))
            if r is not None:
                fundo = r
            continue
        if ESCAPE.fullmatch(pedaco):
            continue
        for ch in pedaco:
            coluna += 1
            if ch != " " or fundo:
                ultima = coluna
    return ultima


def _tem_tinta(linha):
    return _largura_pintada(linha) > 0


def _extremos(linhas):
    cheias = [i for i, l in enumerate(linhas) if _tem_tinta(l)]
    return (cheias[0], cheias[-1]) if cheias else (0, -1)


def _centralizar(gato, texto):
    gi, gf = _extremos(gato)
    ti, tf = _extremos(texto)
    if gf < gi or tf < ti:
        return 0, 0
    desvio = ((gi + gf) - (ti + tf)) // 2
    if desvio > 0:
        return 0, desvio
    return -desvio, 0


def colunas(desenho, texto, recuo, modo, passo):
    base = []
    for i in range(len(texto)):
        d = desenho[i] if i < len(desenho) else ""
        largura = _largura_pintada(d)
        base.append((largura + recuo) if largura else recuo)

    if modo == "reto":
        maior = max((c for c, t in zip(base, texto) if _visivel(t).strip()),
                    default=recuo)
        cols = [maior] * len(base)
    elif modo == "crescente":
        cols, teto = [], recuo
        for c in base:
            teto = max(teto, c)
            cols.append(teto)
    elif modo == "degraus":
        p = max(passo, 1)
        cols = [((c + p - 1) // p) * p for c in base]
    else:
        cols = list(base)

    for i, linha in enumerate(texto):
        if i and _e_separador(linha) and _visivel(texto[i - 1]).strip():
            junto = max(cols[i - 1], cols[i])
            cols[i - 1] = cols[i] = junto

    i = 0
    while i < len(texto):
        if _tem_tinta(texto[i]) and not _visivel(texto[i]).strip():
            j = i
            while j + 1 < len(texto) and _tem_tinta(texto[j + 1]) \
                    and not _visivel(texto[j + 1]).strip():
                j += 1
            if j > i:
                junto = max(cols[i:j + 1])
                for k in range(i, j + 1):
                    cols[k] = junto
            i = j + 1
        else:
            i += 1
    return cols


def compor(texto, gato, recuo, topo, modo="contorno", passo=4):
    if topo == "auto":
        antes_gato, antes_texto = _centralizar(gato, texto)
    else:
        antes_gato, antes_texto = max(int(topo), 0), 0
    desenho = [""] * antes_gato + gato
    texto = [""] * antes_texto + texto

    cols = colunas(desenho, texto, recuo, modo, passo)
    altura = max(len(desenho), len(texto))
    for i in range(altura):
        d = desenho[i] if i < len(desenho) else ""
        t = texto[i] if i < len(texto) else ""
        largura = _largura_pintada(d)
        alvo = cols[i] if i < len(cols) else recuo
        if largura:
            enche = max(alvo - largura, 0) if t else 0
            yield _cortar(d, largura) + "\x1b[0m" + " " * enche + t
        elif t:
            yield " " * alvo + t
        else:
            yield ""


def main():
    p = argparse.ArgumentParser(add_help=True, description=__doc__)
    p.add_argument("--gato", default="~/.local/share/meowsystem/fastfetch/gato.ansi")
    p.add_argument("--recuo", default="3",
                   help="colunas entre o fim do desenho e o começo do texto")
    p.add_argument("--topo", default="auto",
                   help='linhas em branco antes do desenho; "auto" centra os '
                        "dois blocos um no outro")
    p.add_argument("--modo", default="contorno",
                   choices=("contorno", "degraus", "crescente", "reto"),
                   help="como a borda esquerda do texto acompanha o desenho")
    p.add_argument("--passo", default="4",
                   help="o tamanho do degrau, quando --modo degraus")
    p.add_argument("--conferir", action="store_true",
                   help="não compõe; sai 0 se dá para compor, 4 se não dá")
    args = p.parse_args()
    topo = "auto" if str(args.topo).strip().lower() in ("auto", "") \
        else _inteiro(args.topo, "auto", "--topo")
    recuo = _inteiro(args.recuo, 3, "--recuo")
    passo = _inteiro(args.passo, 4, "--passo")

    gato = _ler_gato(args.gato)

    if args.conferir:
        if gato:
            print("logo ANSI legível (%d linhas)" % len(gato))
            return 0
        print("sem logo ANSI utilizável em %s" % args.gato, file=sys.stderr)
        return 4

    bruto = sys.stdin.read()
    if not gato:
        sys.stdout.write(bruto)
        return 0

    texto = bruto.rstrip("\n").split("\n")
    try:
        saida = "\n".join(compor(texto, gato, recuo, topo, args.modo, passo)) + "\n"
    except Exception as erro:
        print("meow-fetch: não consegui compor (%s) — saída sem gato"
              % type(erro).__name__, file=sys.stderr)
        sys.stdout.write(bruto)
        return 0
    sys.stdout.write(saida)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        os._exit(0)
    except KeyboardInterrupt:
        os._exit(130)

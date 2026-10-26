#!/usr/bin/env python3

import argparse
import hashlib
import json
import os
import re
import sys
import zipfile

RECEITA = "catppuccin-xpui-1"
SENTINELA = "/*! MeowSystem " + RECEITA
ASSINATURA = ".encore-dark-theme,.encore-dark-theme .encore-base-set{"
VERDES_ORIGINAIS = ("#1ed760", "#1db954")
ACENTOS = ("rosewater", "flamingo", "pink", "mauve", "red", "maroon", "peach",
           "yellow", "green", "teal", "sky", "sapphire", "blue", "lavender")


def cores_de_receita(paleta_path):
    with open(paleta_path, encoding="utf-8") as fh:
        flavors = json.load(fh)["flavors"]
    return {flavors[f][a].lower() for f in flavors for a in ACENTOS}


def _rgb(c):
    h = c.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _hex(t):
    return "#%02x%02x%02x" % tuple(max(0, min(255, int(round(v)))) for v in t)


def _mistura(a, b, t):
    ra, rb = _rgb(a), _rgb(b)
    return _hex(tuple(ra[i] + (rb[i] - ra[i]) * t for i in range(3)))


def _luminancia(c):
    def canal(v):
        v = v / 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = _rgb(c)
    return 0.2126 * canal(r) + 0.7152 * canal(g) + 0.0722 * canal(b)


def bloco(paleta_path, flavor, acento):
    with open(paleta_path, encoding="utf-8") as fh:
        cores = json.load(fh)["flavors"][flavor]

    c = cores.__getitem__
    A = c(acento)
    A_claro = _mistura(A, c("text"), 0.18)
    A_escuro = _mistura(A, c("crust"), 0.18)
    def sobre(cor):
        return c("crust") if _luminancia(cor) > 0.35 else c("base")

    def tinta(cor):
        return _mistura(c("base"), cor, 0.18)

    def conjunto(cor):
        s = sobre(cor)
        d = ["--background-base:%s" % cor,
             "--background-highlight:%s" % _mistura(cor, c("text"), 0.18),
             "--background-press:%s" % _mistura(cor, c("crust"), 0.18),
             "--background-elevated-base:%s" % _mistura(cor, c("text"), 0.18),
             "--background-elevated-highlight:%s" % _mistura(cor, c("text"), 0.18),
             "--background-elevated-press:%s" % _mistura(cor, c("crust"), 0.18),
             "--background-tinted-base:%s" % cor,
             "--background-tinted-highlight:%s" % cor,
             "--background-tinted-press:%s" % cor]
        for k in ("base", "subdued", "bright-accent", "negative", "warning",
                  "positive", "announcement"):
            d.append("--text-%s:%s" % (k, s))
        for k in ("base", "subdued", "bright-accent", "negative", "warning",
                  "positive", "announcement"):
            d.append("--essential-%s:%s" % (k, s))
        d.append("--decorative-base:%s" % s)
        d.append("--decorative-subdued:%s" % _mistura(cor, c("crust"), 0.18))
        return d

    def conjunto_discreto(cor):
        fundo = tinta(cor)
        d = ["--background-base:%s" % fundo,
             "--background-highlight:%s" % _mistura(fundo, cor, 0.15),
             "--background-press:%s" % _mistura(fundo, cor, 0.30),
             "--background-elevated-base:%s" % _mistura(fundo, cor, 0.15),
             "--background-elevated-highlight:%s" % _mistura(fundo, cor, 0.15),
             "--background-elevated-press:%s" % _mistura(fundo, cor, 0.30),
             "--background-tinted-base:%s" % fundo,
             "--background-tinted-highlight:%s" % fundo,
             "--background-tinted-press:%s" % fundo]
        for k in ("base", "subdued", "bright-accent", "negative", "warning",
                  "positive", "announcement"):
            d.append("--text-%s:%s" % (k, cor))
        for k in ("base", "subdued", "bright-accent", "negative", "warning",
                  "positive", "announcement"):
            d.append("--essential-%s:%s" % (k, cor))
        d.append("--decorative-base:%s" % cor)
        d.append("--decorative-subdued:%s" % _mistura(fundo, cor, 0.30))
        return d

    corpo = [
        "--background-base:%s" % c("base"),
        "--background-highlight:%s" % c("surface0"),
        "--background-press:%s" % c("surface1"),
        "--background-elevated-base:%s" % c("mantle"),
        "--background-elevated-highlight:%s" % c("surface0"),
        "--background-elevated-press:%s" % c("surface1"),
        "--text-base:%s" % c("text"),
        "--text-subdued:%s" % c("subtext0"),
        "--text-bright-accent:%s" % A,
        "--text-negative:%s" % c("red"),
        "--text-warning:%s" % c("yellow"),
        "--text-positive:%s" % c("green"),
        "--text-announcement:%s" % c("blue"),
        "--essential-base:%s" % c("text"),
        "--essential-subdued:%s" % c("overlay1"),
        "--essential-bright-accent:%s" % A,
        "--essential-negative:%s" % c("red"),
        "--essential-warning:%s" % c("yellow"),
        "--essential-positive:%s" % c("green"),
        "--essential-announcement:%s" % c("blue"),
        "--decorative-base:%s" % c("text"),
        "--decorative-subdued:%s" % c("surface0"),
    ]
    moldura = [
        "--background-base:%s" % c("crust"),
        "--background-highlight:%s" % c("mantle"),
        "--background-press:%s" % c("surface0"),
        "--background-elevated-base:%s" % c("mantle"),
        "--background-elevated-highlight:%s" % c("surface0"),
        "--background-elevated-press:%s" % c("crust"),
        "--text-base:%s" % c("text"),
        "--text-subdued:%s" % c("subtext0"),
        "--text-bright-accent:%s" % A,
        "--essential-base:%s" % c("text"),
        "--essential-subdued:%s" % c("overlay0"),
        "--essential-bright-accent:%s" % A,
        "--decorative-base:%s" % c("text"),
        "--decorative-subdued:%s" % c("surface0"),
    ]

    def par(nome):
        if nome:
            return ".encore-dark-theme %s,.encore-light-theme %s" % (nome, nome)
        return (".encore-dark-theme,.encore-dark-theme .encore-base-set,"
                ".encore-light-theme,.encore-light-theme .encore-base-set")

    regras = [
        (par(""), corpo),
        (par(".encore-app-frame-set") + "," + par(".encore-muted-accent-set"), moldura),
        (par(".encore-bright-accent-set") + "," + par(".encore-positive-set"), conjunto(A)),
        (par(".encore-negative-set"), conjunto(c("red"))),
        (par(".encore-warning-set"), conjunto(c("peach"))),
        (par(".encore-announcement-set"), conjunto(c("blue"))),
        (par(".encore-positive-subdued-set"), conjunto_discreto(c("green"))),
        (par(".encore-negative-subdued-set"), conjunto_discreto(c("red"))),
        (par(".encore-warning-subdued-set"), conjunto_discreto(c("peach"))),
        (par(".encore-announcement-subdued-set"), conjunto_discreto(c("blue"))),
    ]

    saida = ["%s flavor=%s accent=%s verde=%s */" % (SENTINELA, flavor, acento, A)]
    for sel, decls in regras:
        saida.append("%s{%s}" % (sel, ";".join(decls)))
    return "\n".join(saida) + "\n"


def _sem_bloco(texto):
    i = texto.find(SENTINELA)
    return texto if i < 0 else texto[:i]


def _verde_vigente(texto):
    m = re.search(re.escape(SENTINELA) + r"[^*]*?verde=(#[0-9a-fA-F]{6})", texto)
    return m.group(1) if m else None


def _bloco_aplicado(texto):
    i = texto.find(SENTINELA)
    return None if i < 0 else texto[i:]


def estado(spa, cores_receita=()):
    with zipfile.ZipFile(spa) as z:
        nomes = [n for n in z.namelist() if n.endswith(".css")]
        documentos = []
        aplicados = []
        verdes = 0
        verde_atual = ""
        limpos = {}
        for n in nomes:
            t = z.read(n).decode("utf-8", "replace")
            if ASSINATURA in t:
                documentos.append(n)
                b = _bloco_aplicado(t)
                aplicados.append(hashlib.sha256(b.encode()).hexdigest() if b else "")
                if b and not verde_atual:
                    v = _verde_vigente(t)
                    verde_atual = v or ""
            limpo = _sem_bloco(t).lower()
            for verde in VERDES_ORIGINAIS:
                verdes += limpo.count(verde)
            limpos[n] = limpo
    unico = aplicados[0] if aplicados and len(set(aplicados)) == 1 else ""
    sobras = 0
    if cores_receita:
        atual = (verde_atual or "").lower()
        for velho in set(cores_receita) - {atual}:
            for limpo in limpos.values():
                sobras += limpo.count(velho)
    print("documentos=%d" % len(documentos))
    print("bloco_sha=%s" % unico)
    print("verde_atual=%s" % verde_atual)
    print("verdes_originais=%d" % verdes)
    print("sobras_receita=%d" % sobras)
    return 0


def aplicar(spa, destino, texto_bloco, verde_novo, cores_receita):
    de = sorted((set(VERDES_ORIGINAIS) | set(cores_receita))
                - {verde_novo.lower()})
    with zipfile.ZipFile(spa) as z:
        entradas = z.infolist()
        nomes = [zi.filename for zi in entradas]
        dados = {}
        documentos = 0
        for zi in entradas:
            bruto = z.read(zi.filename)
            if not zi.filename.endswith(".css"):
                dados[zi.filename] = bruto
                continue
            t = bruto.decode("utf-8", "replace")
            t = _sem_bloco(t)
            for velho in de:
                t = re.sub(re.escape(velho), verde_novo, t, flags=re.IGNORECASE)
            if ASSINATURA in t:
                documentos += 1
                if texto_bloco:
                    if not t.endswith("\n"):
                        t += "\n"
                    t += texto_bloco
            dados[zi.filename] = t.encode("utf-8")

    if documentos == 0:
        sys.stderr.write(
            "xpui.py: nenhum CSS com a tabela de tokens do Encore "
            "(assinatura '%s'). O Spotify mudou o desenho do tema; "
            "nao escrevi nada.\n" % ASSINATURA)
        return 3

    tmp = destino + ".parcial"
    with zipfile.ZipFile(tmp, "w") as saida:
        for zi in entradas:
            novo = zipfile.ZipInfo(zi.filename, date_time=zi.date_time)
            novo.compress_type = zi.compress_type
            novo.external_attr = zi.external_attr
            novo.internal_attr = zi.internal_attr
            novo.create_system = zi.create_system
            saida.writestr(novo, dados[zi.filename])

    with zipfile.ZipFile(tmp) as z:
        if z.testzip() is not None:
            os.unlink(tmp)
            sys.stderr.write("xpui.py: o zip novo nao passou no teste de CRC\n")
            return 2
        if z.namelist() != nomes:
            os.unlink(tmp)
            sys.stderr.write("xpui.py: o zip novo perdeu ou trocou entradas\n")
            return 2
        for n in ("index.html", "xpui-snapshot.js"):
            if n in nomes and z.read(n) != dados[n]:
                os.unlink(tmp)
                sys.stderr.write("xpui.py: '%s' saiu diferente do esperado\n" % n)
                return 2
        sobras = 0
        for n in nomes:
            if n.endswith(".css"):
                baixo = _sem_bloco(
                    dados[n].decode("utf-8", "replace")).lower()
                for velho in de:
                    sobras += baixo.count(velho)
        if sobras:
            os.unlink(tmp)
            sys.stderr.write(
                "xpui.py: sobraram %d ocorrencias de acento anterior; "
                "nao entreguei o pacote\n" % sobras)
            return 2
    os.replace(tmp, destino)
    print("documentos=%d" % documentos)
    return 0


def main():
    p = argparse.ArgumentParser(add_help=True)
    sub = p.add_subparsers(dest="cmd", required=True)

    b = sub.add_parser("bloco")
    b.add_argument("--paleta", required=True)
    b.add_argument("--flavor", required=True)
    b.add_argument("--acento", required=True)

    e = sub.add_parser("estado")
    e.add_argument("spa")
    e.add_argument("--paleta", default=None)

    r = sub.add_parser("reverter")
    r.add_argument("spa")
    r.add_argument("destino")
    r.add_argument("--paleta", required=True)

    a = sub.add_parser("aplicar")
    a.add_argument("spa")
    a.add_argument("destino")
    a.add_argument("--paleta", required=True)
    a.add_argument("--flavor", required=True)
    a.add_argument("--acento", required=True)

    args = p.parse_args()
    try:
        if args.cmd == "bloco":
            sys.stdout.write(bloco(args.paleta, args.flavor, args.acento))
            return 0
        if args.cmd == "estado":
            return estado(args.spa,
                          cores_de_receita(args.paleta) if args.paleta else ())
        if args.cmd == "reverter":
            return aplicar(args.spa, args.destino, "", VERDES_ORIGINAIS[0],
                           cores_de_receita(args.paleta))
        texto = bloco(args.paleta, args.flavor, args.acento)
        with open(args.paleta, encoding="utf-8") as fh:
            verde = json.load(fh)["flavors"][args.flavor][args.acento]
        return aplicar(args.spa, args.destino, texto, verde,
                       cores_de_receita(args.paleta))
    except KeyError as erro:
        sys.stderr.write("xpui.py: chave ausente na paleta: %s\n" % erro)
        return 2
    except (OSError, zipfile.BadZipFile) as erro:
        sys.stderr.write("xpui.py: %s\n" % erro)
        return 2


if __name__ == "__main__":
    sys.exit(main())

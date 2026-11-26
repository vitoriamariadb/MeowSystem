#!/usr/bin/env python3
import re
import sys
import xml.etree.ElementTree as ET

FORMAS = {"svg", "g", "path", "circle", "rect", "ellipse", "line", "polyline", "polygon", "title", "desc"}
ATRIBUTOS_DE_TRACO = {
    "viewBox", "width", "height", "version", "role", "aria-label", "id", "transform", "opacity",
    "d", "points", "cx", "cy", "r", "rx", "ry", "x", "y", "x1", "y1", "x2", "y2",
    "fill", "fill-rule", "fill-opacity", "clip-rule",
    "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit",
    "stroke-opacity", "stroke-dasharray", "stroke-dashoffset",
}


def _local(nome):
    return nome.rsplit("}", 1)[-1]


def recusa(texto):
    if re.search(r"<!DOCTYPE|<!ENTITY", texto, flags=re.I):
        return "traz DOCTYPE ou ENTITY"
    try:
        arvore = ET.fromstring(texto)
    except ET.ParseError as e:
        return "não é SVG bem formado (%s)" % e
    for el in arvore.iter():
        if _local(el.tag) not in FORMAS:
            return "traz elemento que não é traçado: %s" % _local(el.tag)
        for nome, valor in el.attrib.items():
            if _local(nome) not in ATRIBUTOS_DE_TRACO:
                return "traz atributo que não é de traçado: %s" % _local(nome)
            if "url(" in valor.replace(" ", "").lower():
                return "o atributo %s aponta para fora do desenho" % _local(nome)
    return None


def main(argv):
    if len(argv) != 2:
        sys.stderr.write("uso: glifo_tracado.py <glifo.svg>\n")
        return 2
    try:
        with open(argv[1], encoding="utf-8") as fh:
            texto = fh.read()
    except (OSError, UnicodeDecodeError) as e:
        sys.stderr.write("não consegui ler %s: %s\n" % (argv[1], e))
        return 2
    motivo = recusa(texto)
    if motivo:
        sys.stderr.write("%s\n" % motivo)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

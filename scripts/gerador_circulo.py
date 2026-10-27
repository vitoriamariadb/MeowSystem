#!/usr/bin/env python3
import re
import sys

PALETA = {
    "disco": "#44475A",
    "disco-fundo": "#282A36",
    "disco-lua": "#383A4C",
    "aro": "#BD93F9",
    "verde": "#50FA7B",
    "lua": "#F1FA8C",
    "rosa": "#FF79C6",
    "ciano": "#8BE9FD",
    "texto": "#F8F8F2",
}

PRESETS = (
    ("disco", "Disco", {"disco": "#44475A", "aro": False, "tinta": "#50FA7B", "tamanho": 62, "fundo": True}),
    ("disco-aro", "Disco e aro", {"disco": "#282A36", "aro": True, "tinta": "#BD93F9", "tamanho": 58, "fundo": True}),
    ("lua", "Lua", {"disco": "#383A4C", "aro": False, "tinta": "#F1FA8C", "tamanho": 60, "fundo": True}),
    ("solto", "Glifo solto", {"disco": "#44475A", "aro": False, "tinta": "#50FA7B", "tamanho": 90, "fundo": False}),
    ("capa", "Da capa", {"disco": "#44475A", "aro": False, "tinta": "#FF79C6", "tamanho": 64, "fundo": True}),
)

RE_CAMINHO = re.compile(r"<path\b[^>]*?\bd=\"([^\"]+)\"", re.S)
RE_NUMERO = re.compile(r"-?\d+(?:\.\d+)?")
RE_HEX = re.compile(r"^#[0-9A-Fa-f]{6}$")
CENTRO, RAIO_DISCO, RAIO_ARO_INTERNO = 24.0, 22.6, 19.8


def caminhos_do_glifo(svg):
    achados = [d.strip() for d in RE_CAMINHO.findall(svg or "") if d.strip()]
    fechados = [d for d in achados if re.search(r"[Zz]\s*$", d)]
    if fechados:
        return fechados
    return [d + " Z" for d in achados]


def caixa(caminhos):
    xs, ys = [], []
    for d in caminhos:
        for trecho in re.findall(r"[MLCZmlcz][^MLCZmlcz]*", d):
            if trecho[0] in "Zz":
                continue
            nums = [float(n) for n in RE_NUMERO.findall(trecho)]
            xs += nums[0::2]
            ys += nums[1::2]
    if not xs or not ys:
        return None
    return min(xs), min(ys), max(xs), max(ys)


def _cor(valor, padrao):
    return valor if isinstance(valor, str) and RE_HEX.match(valor) else padrao


def gerar(glifo_svg, preset="disco", disco=None, aro=None, tinta=None, tamanho=None):
    base = next((p[2] for p in PRESETS if p[0] == preset), PRESETS[0][2])
    cor_disco = _cor(disco, base["disco"]).upper()
    cor_tinta = _cor(tinta, base["tinta"]).upper()
    com_aro = base["aro"] if aro is None else bool(aro)
    try:
        pct = max(40, min(100, int(tamanho if tamanho is not None else base["tamanho"])))
    except (TypeError, ValueError):
        pct = base["tamanho"]
    caminhos = caminhos_do_glifo(glifo_svg)
    partes = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">']
    if base["fundo"]:
        if com_aro:
            partes.append('<circle cx="24" cy="24" r="%g" fill="%s"/>' % (RAIO_DISCO, PALETA["aro"]))
            partes.append('<circle cx="24" cy="24" r="%g" fill="%s"/>' % (RAIO_ARO_INTERNO, cor_disco))
        else:
            partes.append('<circle cx="24" cy="24" r="%g" fill="%s"/>' % (RAIO_DISCO, cor_disco))
    elif com_aro:
        partes.append('<circle cx="24" cy="24" r="%g" fill="%s"/>' % (RAIO_DISCO, PALETA["aro"]))
        partes.append('<circle cx="24" cy="24" r="%g" fill="%s"/>' % (RAIO_ARO_INTERNO, cor_disco))
    ccx = caixa(caminhos)
    if ccx:
        x0, y0, x1, y1 = ccx
        largura, altura = max(x1 - x0, 0.01), max(y1 - y0, 0.01)
        lado = 2 * RAIO_DISCO * pct / 100.0
        escala = lado / max(largura, altura)
        dx = CENTRO - escala * (x0 + largura / 2.0)
        dy = CENTRO - escala * (y0 + altura / 2.0)
        partes.append('<path fill="%s" fill-rule="evenodd" transform="matrix(%.4f 0 0 %.4f %.3f %.3f)" d="%s"/>'
                      % (cor_tinta, escala, escala, dx, dy, " ".join(caminhos)))
    partes.append("</svg>")
    return "".join(partes)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(2)
    with open(sys.argv[1], encoding="utf-8") as fh:
        print(gerar(fh.read(), sys.argv[2] if len(sys.argv) > 2 else "disco"))

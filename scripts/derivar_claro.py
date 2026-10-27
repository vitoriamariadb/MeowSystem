#!/usr/bin/env python3
import colorsys
import os
import json
import sys

from pack import derivar_claro

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def hx2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def rgb2hx(r, g, b):
    return "#%02X%02X%02X" % tuple(max(0, min(255, round(c * 255))) for c in (r, g, b))


def lum(h):
    r, g, b = hx2rgb(h)
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def contraste(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def com_luminancia(hexa, alvo, sat_extra=0.0):
    h, s, v = colorsys.rgb_to_hsv(*hx2rgb(hexa))
    s = min(1.0, s + sat_extra)
    lo, hi = 0.0, 1.0
    for _ in range(40):
        mid = (lo + hi) / 2
        cand = rgb2hx(*colorsys.hsv_to_rgb(h, s, mid))
        if lum(cand) < alvo:
            lo = mid
        else:
            hi = mid
    return rgb2hx(*colorsys.hsv_to_rgb(h, s, (lo + hi) / 2))


def main():
    cat = json.load(open(f"{RAIZ}/packs/meowsystem/paleta.json"))
    pack = json.load(open(f"{RAIZ}/packs/dracula/paleta.json"))
    escuro = pack["flavors"]["dracula"]
    latte = cat["flavors"]["latte"]
    ordem = pack["ordem_canonica"]

    ACENTOS = {"rosewater", "flamingo", "pink", "mauve", "red", "maroon",
               "peach", "yellow", "green", "teal", "sky", "sapphire",
               "blue", "lavender"}

    claro = derivar_claro(escuro, latte)

    falhas = []
    c_text = contraste(claro["text"], claro["base"])
    if c_text < 7.0:
        falhas.append("text/base %.2f < 7.0 (AAA)" % c_text)
    for k in ordem:
        c = contraste(claro[k], claro["base"])
        ref = contraste(latte[k], latte["base"])
        if c < ref * 0.95:
            falhas.append("%s/base %.2f — o Latte faz %.2f no mesmo slot" % (k, c, ref))

    err = sys.stderr
    print("%-11s %-9s -> %-9s  contraste c/ base" % ("slot", "dracula", "claro"), file=err)
    for k in ordem:
        print("%-11s %-9s -> %-9s  %5.2f" % (k, escuro[k], claro[k],
                                             contraste(claro[k], claro["base"])), file=err)
    print(file=err)
    print("text/base  : %.2f   (Latte: %.2f)" % (c_text, contraste(latte["text"], latte["base"])),
          file=err)
    print("mauve/base : %.2f   (Latte: %.2f)" % (contraste(claro["mauve"], claro["base"]),
                                                 contraste(latte["mauve"], latte["base"])), file=err)
    if falhas:
        print("\nREPROVADO:", file=err)
        for f in falhas:
            print("  " + f, file=err)
        return 1
    print("\nAPROVADO — WCAG AAA no texto, AA em todos os acentos", file=err)
    print(json.dumps(claro, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())

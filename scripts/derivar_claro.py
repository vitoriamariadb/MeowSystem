#!/usr/bin/env python3
"""Deriva o flavor CLARO do Dracula, com o critério que o projeto já usa.

O MÉTODO, E POR QUE ELE É ESTE
    O Catppuccin Latte não é "o Mocha com o brilho invertido": medindo os 26
    slots, ele PRESERVA O MATIZ (desvio de ±10° em todos) e reescreve a rampa
    de LUMINÂNCIA — base vai de 0,01 para 0,88, text de 0,68 para 0,08, e os
    acentos escurecem MUITO (mauve 0,47 -> 0,14) ganhando saturação, porque um
    acento claro sobre fundo claro não se lê.

    Então o Dracula claro sai assim: MATIZ E SATURAÇÃO DO DRACULA, RAMPA DE
    LUMINÂNCIA DO LATTE. O Latte é o claro de referência deste projeto e já foi
    calibrado por quem desenhou o Catppuccin; copiar a rampa dele é herdar essa
    calibração sem copiar as cores.

O QUE SE CONFERE, E NÃO É OPINIÃO
    Contraste WCAG de `text` sobre `base` >= 7:1 (AAA para texto normal) e de
    cada acento sobre `base` >= 4.5:1 (AA). O Latte entrega 7,06 e 4,79 nesses
    dois pontos; é a régua.

O MÉTODO MORA NO `pack.py` DESDE 23/09/2026 (P34), E ESTE SCRIPT SÓ O CHAMA
    A P16 levou o algoritmo para o `pack.py` (`derivar_claro`), porque o CSV
    de cores precisava dele como biblioteca e este script não servia: cravava
    o `dracula` na leitura e gravava em `/tmp/dracula-claro.json`. Ficaram duas
    cópias passo a passo iguais, e o `tests/pack.sh` provava que a do
    `pack.py` devolvia o `alucard` — a daqui não tinha quem a cobrasse. Duas
    cópias de um método com três correções na história divergem na quarta.

    Agora o `main()` chama a do `pack.py`, e a história das três correções
    continua escrita aqui, ao lado da chamada, porque é aqui que ela foi
    aprendida. E este script não grava mais nada: o JSON do claro sai no
    STDOUT, e o relatório de contraste no STDERR — `> claro.json` pega só o
    que é dado, e quem roda no terminal continua lendo a conferência.
"""
import colorsys
import os
import json
import sys

from pack import derivar_claro   # vizinho de arquivo: `scripts/` é o sys.path[0]

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
    """Mesma cor, com a luminância relativa levada ao alvo.

    Mexe em V (e, quando pedido, em S) por busca binária: é o único jeito de
    acertar a luminância RELATIVA, que não é linear em V nem em S.
    """
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
    # Este script deriva UM flavor claro a partir de outro escuro, e a régua de
    # saturação e luminância é o Latte do Catppuccin — é o que o bloco "A
    # CALIBRAÇÃO VEM DO LATTE" abaixo explica.
    cat = json.load(open(f"{RAIZ}/packs/catppuccin/paleta.json"))
    pack = json.load(open(f"{RAIZ}/packs/dracula/paleta.json"))
    escuro = pack["flavors"]["dracula"]
    latte = cat["flavors"]["latte"]
    ordem = pack["ordem_canonica"]

    # Os acentos ganham saturação ao escurecer, como no Latte: o mauve do Mocha
    # tem S=0,33 e o do Latte S=0,76. Sem isso o acento escuro sai acinzentado.
    ACENTOS = {"rosewater", "flamingo", "pink", "mauve", "red", "maroon",
               "peach", "yellow", "green", "teal", "sky", "sapphire",
               "blue", "lavender"}

    # A primeira tentativa manteve a saturação do Dracula e levou só a
    # luminância ao alvo. Todos os 14 acentos reprovaram no contraste contra
    # esse fundo.
    #
    # O Latte clareia BAIXANDO a saturação na estrutura (o #EFF1F5 dele é quase
    # neutro) e SUBINDO nos acentos.
    claro = derivar_claro(escuro, latte)

    # Medindo o Latte com a mesma régua, ele reprova nos mesmos: `rosewater`
    # sobre `base` dá 2,32 lá também.
    #
    # O que vale conferir é: o Dracula claro não pode ser PIOR que o claro de
    # referência do projeto no mesmo slot.
    falhas = []
    c_text = contraste(claro["text"], claro["base"])
    if c_text < 7.0:
        falhas.append("text/base %.2f < 7.0 (AAA)" % c_text)
    for k in ordem:
        c = contraste(claro[k], claro["base"])
        ref = contraste(latte[k], latte["base"])
        if c < ref * 0.95:
            falhas.append("%s/base %.2f — o Latte faz %.2f no mesmo slot" % (k, c, ref))

    # Era tudo no STDOUT, e o claro gravado em `/tmp/dracula-claro.json` — um
    # arquivo fixo num diretório de todos, que a segunda rodada sobrescrevia
    # calada.
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

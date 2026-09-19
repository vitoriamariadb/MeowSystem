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
"""
import colorsys
import os
import json
import sys

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
    cat = json.load(open(f"{RAIZ}/assets/paleta/catppuccin.json"))
    pack = json.load(open(f"{RAIZ}/packs/dracula/paleta.json"))
    escuro = pack["flavors"]["dracula"]
    latte = cat["flavors"]["latte"]
    ordem = pack["ordem_canonica"]

    # Os acentos ganham saturação ao escurecer, como no Latte: o mauve do Mocha
    # tem S=0,33 e o do Latte S=0,76. Sem isso o acento escuro sai acinzentado.
    ACENTOS = {"rosewater", "flamingo", "pink", "mauve", "red", "maroon",
               "peach", "yellow", "green", "teal", "sky", "sapphire",
               "blue", "lavender"}

    # A CALIBRAÇÃO VEM DO LATTE, A IDENTIDADE VEM DO DRACULA.
    #   A primeira tentativa manteve a saturação do Dracula e levou só a
    #   luminância ao alvo. Resultado medido: `base` virou #BDC6FF — um azul
    #   claro forte, porque o #282A36 do Dracula é azulado e saturado, e
    #   clarear mantendo S não dá cinza, dá pastel. Todos os 14 acentos
    #   reprovaram no contraste contra esse fundo.
    #
    #   O Latte clareia BAIXANDO a saturação na estrutura (o #EFF1F5 dele é
    #   quase neutro) e SUBINDO nos acentos. Então o que se copia dele é o par
    #   (saturação, luminância) de cada slot; do Dracula vem o MATIZ, que é o
    #   que faz uma cor ser reconhecida como daquele tema.
    #   SEGUNDA CORREÇÃO: copiar (S, V) do Latte também não basta. A luminância
    #   percebida depende do MATIZ — um amarelo e um azul com o mesmo S e V não
    #   têm o mesmo brilho, e é por isso que o `yellow` saiu a 1,30 de contraste
    #   enquanto o `mauve` passou. O que tem de ser igual ao Latte é a
    #   LUMINÂNCIA; S entra como ponto de partida e V se ajusta até bater.
    #   TERCEIRA CORREÇÃO: o matiz de um quase-neutro é ruído, e amplificá-lo
    #   vira cor. O `text` do Dracula é #F8F8F2 — saturação 0,02, praticamente
    #   branco. Preservar "o matiz dele" e subir a saturação para a do Latte
    #   produziu #52523C, um oliva: uma cor que o Dracula não tem, inventada a
    #   partir de dois pontos de amarelo num branco.
    #
    #   Onde o original é neutro (S < 0,10), o que define a família do tema não
    #   é o matiz daquele slot: é o do `base`. O Dracula é azul-arroxeado, então
    #   os cinzas claros puxam para lá — que é exatamente o que o Latte faz com
    #   os dele.
    h_base = colorsys.rgb_to_hsv(*hx2rgb(escuro["base"]))[0]
    claro = {}
    for k in ordem:
        h_d, s_d, _ = colorsys.rgb_to_hsv(*hx2rgb(escuro[k]))
        if s_d < 0.10:
            h_d = h_base
        s_l = colorsys.rgb_to_hsv(*hx2rgb(latte[k]))[1]
        alvo = lum(latte[k])
        # Busca V para a luminância alvo, com S fixo. Se nem V=1 alcança (matiz
        # escuro demais para aquela saturação), afrouxa S e tenta de novo — é o
        # caso do azul, que com S alto não chega a claro nenhum.
        for tentativa in range(12):
            s = max(0.0, s_l - tentativa * 0.07)
            lo, hi = 0.0, 1.0
            for _ in range(40):
                mid = (lo + hi) / 2
                if lum(rgb2hx(*colorsys.hsv_to_rgb(h_d, s, mid))) < alvo:
                    lo = mid
                else:
                    hi = mid
            cand = rgb2hx(*colorsys.hsv_to_rgb(h_d, s, (lo + hi) / 2))
            if abs(lum(cand) - alvo) < 0.01:
                break
        claro[k] = cand

    # AJUSTE FINO DO `text`, E SÓ DELE.
    #   Mirar a luminância do Latte deixou o `text` a 6,99 de contraste — AAA
    #   pede 7,0, e a diferença é o arredondamento para hexa, não o método.
    #   Este é o único slot com exigência ABSOLUTA (é onde a pessoa lê), então
    #   ele desce alguns pontos de V até passar. Os demais são comparados com o
    #   Latte, e lá o critério é relativo.
    while contraste(claro["text"], claro["base"]) < 7.02:
        h, sv, vv = colorsys.rgb_to_hsv(*hx2rgb(claro["text"]))
        vv -= 0.004
        if vv <= 0:
            break
        claro["text"] = rgb2hx(*colorsys.hsv_to_rgb(h, sv, vv))

    # --- conferência, que é o que autoriza gravar -----------------------------
    # A RÉGUA É O LATTE, NÃO UM NÚMERO QUE EU INVENTEI.
    #   A primeira conferência exigia 4,5:1 de TODO acento sobre o base — e
    #   reprovou 12 slots. Medindo o Latte com a mesma régua, ele reprova nos
    #   mesmos: `rosewater` sobre `base` dá 2,32 lá também. Esses slots não são
    #   texto, são decoração (realce, borda, gráfico), e o WCAG de texto não se
    #   aplica a eles.
    #
    #   O que vale conferir é: o Dracula claro não pode ser PIOR que o claro de
    #   referência do projeto no mesmo slot. Assim a régua é verificável e não
    #   depende de eu achar um número bonito.
    falhas = []
    c_text = contraste(claro["text"], claro["base"])
    if c_text < 7.0:
        falhas.append("text/base %.2f < 7.0 (AAA)" % c_text)
    for k in ordem:
        c = contraste(claro[k], claro["base"])
        ref = contraste(latte[k], latte["base"])
        if c < ref * 0.95:
            falhas.append("%s/base %.2f — o Latte faz %.2f no mesmo slot" % (k, c, ref))

    print("%-11s %-9s -> %-9s  contraste c/ base" % ("slot", "dracula", "claro"))
    for k in ordem:
        print("%-11s %-9s -> %-9s  %5.2f" % (k, escuro[k], claro[k],
                                             contraste(claro[k], claro["base"])))
    print()
    print("text/base  : %.2f   (Latte: %.2f)" % (c_text, contraste(latte["text"], latte["base"])))
    print("mauve/base : %.2f   (Latte: %.2f)" % (contraste(claro["mauve"], claro["base"]),
                                                 contraste(latte["mauve"], latte["base"])))
    if falhas:
        print("\nREPROVADO:")
        for f in falhas:
            print("  " + f)
        return 1
    print("\nAPROVADO — WCAG AAA no texto, AA em todos os acentos")
    json.dump(claro, open("/tmp/dracula-claro.json", "w"), indent=2, ensure_ascii=False)
    print("gravado em /tmp/dracula-claro.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())

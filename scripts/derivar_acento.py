#!/usr/bin/env python3
"""Deriva a captura de um acento a partir da captura do mesmo flavor.

O DEFEITO QUE ESTE ARQUIVO FECHA — 24/09/2026, sprint P48 (achado 31)
    Com o Dracula no ar, «Cor de destaque» oferecia doze cores e só o mauve
    aplicava: só existe a captura `dracula-mauve`. Escolher pink gravava o conf,
    gerava o `.ron` e o instalador mandava importar o `.ron` na GUI e rodar
    `meow tema capturar dracula-pink` — passo manual, que a regra do projeto
    proíbe. Medido no desktop: o destaque continuava #BD93F9.

O QUE FOI MEDIDO ANTES DE ESCREVER UMA LINHA
    1. As duas capturas do mesmo flavor com acentos diferentes (`mocha-mauve` e
       `mocha-pink`) NÃO diferem só no acento. Diferem também em `neutral_tint`,
       `frosted`, `alpha_map`, `spacing`, `active_hint`, `corner_radii` e `gaps`
       da receita — foram tiradas com três semanas de distância, e a GUI dela
       mudou nesse meio. Comparar as duas não isola o que o acento pinta.
    2. Quem isola é o próprio COSMIC. O `ThemeBuilder::build()` do libcosmic
       (cosmic-theme/src/model/theme.rs, commit c003a58 de 29/08/2026, no
       ~/.cargo desta máquina) foi compilado num oráculo de bancada e rodado
       sobre a receita do `dracula-mauve`: com o mesmo acento ele reproduz
       BYTE A BYTE os 45 arquivos da `Dark/v2` capturada (só o `shade` sai em
       outra grafia, hex no lugar de floats). Com o pink, mudam exatamente os
       campos que o código fonte diz que o acento pinta — e nenhum outro:
         · `focus` e `selected_text` de todo componente;
         · `accent` e `accent_button` quase inteiros (base, borda, hover,
           pressed, selected, disabled, disabled_border, on_disabled — e, no
           botão, o `on`, que é a cor de texto por contraste);
         · `link_button` e `text_button`: on, divider e on_disabled;
         · `accent_text` e a própria receita (`<Árvore>.Builder/v2/accent`).
    3. Por isso a derivação é CIRÚRGICA: parte da captura do flavor e reescreve
       só esses campos, no lugar, sem reserializar nada. Tudo o que não é
       acento (o vidro, o raio, os gaps, a neutra) continua sendo o que a
       captura fotografou — inclusive o que o projeto escreveu nela depois.

A MATEMÁTICA É A DO LIBCOSMIC, EM f32, E ELA FOI CONFERIDA
    Os campos acima são funções do acento e de coisas que JÁ ESTÃO na captura
    (o `hovered` do botão é o `icon_button.hover`, que tem base transparente;
    a neutra do texto é o `accent.on`). Três deles precisam da escada Oklch do
    `steps.rs` do libcosmic: o `accent_button.on` e o `accent_text`. Ela está
    portada abaixo, operação por operação, com arredondamento para f32 a cada
    passo — o COSMIC faz tudo em f32, e sem isso um `.5` exato no fim da conta
    (o `on_disabled` do accent é metade do acento) sai para o lado errado.
    Conferido contra o oráculo, que roda o `build()` de verdade, em 24/09/2026:
    as quatro capturas de fábrica como base e os 14 acentos da paleta em cada
    uma. Das 42 derivações (dracula-mauve, mocha-pink e latte-mauve), nenhum
    campo saiu diferente do que o COSMIC escreve; as 14 do mocha-mauve foram
    recusadas pela guarda abaixo, como deviam.

A GUARDA: A CAPTURA TEM DE SE REPRODUZIR ANTES DE SER DERIVADA
    Antes de pintar o acento novo, a derivação pinta o ANTIGO por cima da
    própria captura e confere que nada mudou. Uma captura que não passa nisso
    é uma captura que o COSMIC não escreveria com a receita que ela diz ter —
    e derivar dela seria o tema híbrido que o docs/COSMIC-THEMING.md proíbe.
    Nesse caso nada se escreve, e a saída diz QUAL campo não fecha: é a
    "chave que não se deriva" que a sprint pediu para nomear.
"""
from __future__ import annotations

import argparse
import math
import os
import shutil
import struct
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "scripts"))
import pack  # noqa: E402
import gerar_tema_v1 as v1  # noqa: E402  — o parser RON e a geração da v1 são dele

# O que marca uma captura como DERIVADA, na linha `origem:` do captura.txt. É a
# linha que a `capturar_tema.sh` escreve com a casa de onde fotografou; aqui ela
# diz de qual captura veio, e é por ela que se sabe o que é seguro reescrever:
# uma captura de verdade (tirada da GUI) nunca é tocada por este arquivo.
MARCA = "derivada de "

# `.gitignore` DENTRO DA CAPTURA DERIVADA, E NÃO NA RAIZ DO REPOSITÓRIO
#   A captura derivada mora onde a `capturar_tema.sh` gravaria a mesma captura
#   (o `captura-destino` do pack.py), porque é lá que o `meow tema`, o
#   instalador e o painel a procuram. Só que ela é PRODUTO, como os `.ron` em
#   `$MEOW_ESTADO/temas/`, e o tests/git-limpo.sh cobra que usar o programa não
#   suje o clone. Um `*` na pasta dela esconde a pasta inteira do `git status`
#   — ela e o próprio `.gitignore` — sem regra nenhuma na raiz que precisasse
#   adivinhar quais `<flavor>-<acento>` são derivados e quais são fotografia.
#   Uma captura de verdade tirada por cima (`meow tema capturar`) apaga a pasta
#   inteira antes de gravar, e com ela o `.gitignore`: ela volta a aparecer no
#   git, que é onde uma fotografia deve ir.
IGNORAR = "*\n"

ARVORES = ("Dark", "Light")


# ===========================================================================
# 1. f32 — O COSMIC FAZ A CONTA EM PRECISÃO SIMPLES
# ===========================================================================
_F = struct.Struct("<f")


def f32(x: float) -> float:
    return _F.unpack(_F.pack(x))[0]


def _fma(a: float, b: float, c: float) -> float:
    """`mul_add` do Rust: a*b + c com UM arredondamento. O produto de dois f32
    cabe exato num f64, então só a soma arredonda antes da volta a f32."""
    return f32(a * b + c)


def _powf(x: float, y: float) -> float:
    return f32(math.pow(x, y))


def _cbrtf(x: float) -> float:
    return f32(math.copysign(abs(x) ** (1.0 / 3.0), x)) if not hasattr(math, "cbrt") \
        else f32(math.cbrt(x))


# As constantes são `T::from_f64(c)` no palette 0.7: o f64 arredondado a f32.
_K = {c: f32(c) for c in (
    0.04045, 1.0 / 12.92, 1.0 / 1.055, 0.055 / 1.055, 2.4,
    0.0031308, 12.92, 1.0 / 2.4, 1.055, 0.055,
    0.4122214708, 0.5363325363, 0.0514459929,
    0.2119034982, 0.6806995451, 0.1073969566,
    0.0883024619, 0.2817188376, 0.6299787005,
    0.2104542553, 0.7936177850, 0.0040720468,
    1.9779984951, 2.4285922050, 0.4505937099,
    0.0259040371, 0.7827717662, 0.8086757660,
    0.3963377774, 0.2158037573, 0.1055613458, 0.0638541728,
    0.0894841775, 1.2914855480,
    4.0767416621, 3.3077115913, 0.2309699292,
    -1.2684380046, 2.6097574011, 0.3413193965,
    -0.0041960863, 0.7034186147, 1.7076147010,
)}
_PI = f32(math.pi)
_GRAUS = f32(57.2957795130823208767981548141051703)     # f32::to_degrees
_RADIANOS = f32(_PI / f32(180.0))                        # f32::to_radians
_TOL = f32(0.00034526698)                                # almost::F32_TOLERANCE
_MIN_POS = 1.17549435e-38


def _para_linear(x: float) -> float:
    if x <= _K[0.04045]:
        return f32(_K[1.0 / 12.92] * x)
    return _powf(_fma(x, _K[1.0 / 1.055], _K[0.055 / 1.055]), _K[2.4])


def _de_linear(x: float) -> float:
    if x <= _K[0.0031308]:
        return f32(_K[12.92] * x)
    return _fma(_powf(x, _K[1.0 / 2.4]), _K[1.055], -_K[0.055])


def _lin3(c1, x, c2, y, c3, z, s2=1, s3=1):
    """((c1*x) ± (c2*y)) ± (c3*z), da esquerda para a direita, como o Rust
    avalia — cada operação arredonda. O sinal vem à parte porque o palette
    escreve `a - k*b`, e não `a + (-k)*b`, e as duas coisas não arredondam
    igual quando o k é constante positiva."""
    t = f32(c1 * x)
    t = f32(t + s2 * f32(c2 * y))
    return f32(t + s3 * f32(c3 * z))


def _para_oklab(rgb):
    r, g, b = (_para_linear(f32(c)) for c in rgb)
    k = _K
    l = _lin3(k[0.4122214708], r, k[0.5363325363], g, k[0.0514459929], b)
    m = _lin3(k[0.2119034982], r, k[0.6806995451], g, k[0.1073969566], b)
    s = _lin3(k[0.0883024619], r, k[0.2817188376], g, k[0.6299787005], b)
    l_, m_, s_ = _cbrtf(l), _cbrtf(m), _cbrtf(s)
    L = _lin3(k[0.2104542553], l_, k[0.7936177850], m_, k[0.0040720468], s_, 1, -1)
    A = _lin3(k[1.9779984951], l_, k[2.4285922050], m_, k[0.4505937099], s_, -1, 1)
    B = _lin3(k[0.0259040371], l_, k[0.7827717662], m_, k[0.8086757660], s_, 1, -1)
    return L, A, B


def _de_oklab(L, A, B):
    """Sem clamp — é o `from_color_unclamped` do palette."""
    k = _K
    l_ = f32(f32(L + f32(k[0.3963377774] * A)) + f32(k[0.2158037573] * B))
    m_ = f32(f32(L - f32(k[0.1055613458] * A)) - f32(k[0.0638541728] * B))
    s_ = f32(f32(L - f32(k[0.0894841775] * A)) - f32(k[1.2914855480] * B))
    l = f32(f32(l_ * l_) * l_)
    m = f32(f32(m_ * m_) * m_)
    s = f32(f32(s_ * s_) * s_)
    r = _lin3(k[4.0767416621], l, k[3.3077115913], m, k[0.2309699292], s, -1, 1)
    g = _lin3(k[-1.2684380046], l, k[2.6097574011], m, k[0.3413193965], s, 1, -1)
    b = _lin3(k[-0.0041960863], l, k[0.7034186147], m, k[1.7076147010], s, -1, 1)
    return _de_linear(r), _de_linear(g), _de_linear(b)


def _para_oklch(rgb):
    """`Oklcha::from_color` — com o clamp do L em [0, 1] no fim."""
    L, A, B = _para_oklab(rgb)
    croma = f32(math.hypot(A, B))
    matiz = f32(f32(_PI + f32(math.atan2(-B, -A))) * _GRAUS)
    return min(max(L, 0.0), 1.0), max(croma, 0.0), matiz


def _de_oklch(L, croma, matiz):
    rad = f32(matiz * _RADIANOS)
    seno, cosseno = f32(math.sin(rad)), f32(math.cos(rad))
    croma = max(croma, 0.0)
    return _de_oklab(L, f32(cosseno * croma), f32(seno * croma))


def _quase_igual(a: float, b: float) -> bool:
    escala = max(abs(a), abs(b))
    if escala <= _MIN_POS:
        escala = _MIN_POS
    return abs(f32(a - b)) < f32(_TOL * escala)


def _srgb_valido(c) -> bool:
    return all(_quase_igual(x, 1.0) or (0.0 <= x <= 1.0) for x in c)


def _prender(c):
    return tuple(min(max(x, 0.0), 1.0) for x in c)


def _oklch_para_srgb_perto(L, croma, matiz):
    """`oklch_to_srgba_nearest_chroma` do steps.rs, laço de 64 e tudo."""
    r_croma, l_croma = croma, 0.0
    novo = _de_oklch(L, croma, matiz)
    if _srgb_valido(novo):
        return _prender(novo)
    for _ in range(64):
        novo = _de_oklch(L, croma, matiz)
        if _srgb_valido(novo):
            l_croma = croma
            croma = f32(f32(croma + r_croma) / f32(2.0))
        else:
            r_croma = croma
            croma = f32(f32(croma + l_croma) / f32(2.0))
    return _prender(_de_oklch(L, croma, matiz))


def degraus(rgb, n: int):
    """`steps()`: a mesma matiz e o mesmo croma, do L=0 ao L=1."""
    _, croma, matiz = _para_oklch(rgb)
    return [_oklch_para_srgb_perto(f32(f32(float(i)) / f32(float(n - 1))), croma, matiz)
            for i in range(n)]


def _arred_rust(x: float) -> int:
    """`f32::round`: metade para longe do zero (o Python arredonda para o par)."""
    return int(math.floor(x + 0.5)) if x >= 0 else -int(math.floor(-x + 0.5))


def indice(rgb, n: int) -> int:
    """`color_index()`: o L do Oklch, em n degraus."""
    L = _para_oklch(rgb)[0]
    return min(max(_arred_rust(f32(L * f32(float(n)))), 0), n - 1)


def _indice_vizinho(base, passos, n, escuro):
    i = base + passos if escuro else base - passos
    return i if 0 <= i < n else None


def cor_de_superficie(base, passos, degr, escuro, reserva):
    escuro = escuro or base < 91
    i = _indice_vizinho(base, passos, len(degr), escuro)
    return degr[i] if i is not None else reserva


def cor_de_texto(base, degr, reserva, degr_tinta, alfa):
    """`get_text()` do steps.rs.

    O desvio é `((1. - alpha) * 100.0).round()` em f32: com 0,555, em f64 a
    conta dá 44,4999 e arredonda para 44; em f32 dá 44,5, e o Rust vai para 45.
    (25/09/2026, revisão da P58: aqui ela era em f64, e o `derivar_vidro.py`,
    que passa o alpha do nível, guardava uma cópia desta função com a conta em
    f32. O chamador deste arquivo passa 1,0, e aí o desvio é zero nos dois
    jeitos; a conta passou a ser uma só, e a cópia saiu.)"""
    if degr_tinta is not None:
        degr = degr_tinta
    extra = _arred_rust(f32(f32(1.0 - alfa) * f32(100.0))) if alfa < 1.0 else 0
    escuro = base < 60
    i = _indice_vizinho(base, 70 + extra, len(degr), escuro)
    if i is None:
        i = _indice_vizinho(base, 50 + extra, len(degr), escuro)
    if i is None:
        i = 99 if escuro else 0
    return degr[i] if i < len(degr) else reserva


def sobre(a, b):
    """`over()` do composite.rs, com a precedência que ele tem de fato: só a
    parcela do fundo é dividida pelo alpha resultante."""
    aa, ba = a[3], b[3]
    oa = min(max(f32(aa + f32(ba * f32(1.0 - aa))), 0.0), 1.0)

    def canal(x, y):
        t = f32(f32(f32(y * ba) * f32(1.0 - aa)) / oa) if oa else 0.0
        return min(max(f32(f32(x * aa) + t), 0.0), 1.0)
    return (canal(a[0], b[0]), canal(a[1], b[1]), canal(a[2], b[2]), oa)


def com_alfa(c, alfa):
    return (c[0], c[1], c[2], f32(alfa))


def _luma(c) -> float:
    r, g, b = (_para_linear(f32(x)) for x in c[:3])
    return 0.2126729 * r + 0.7151522 * g + 0.0721750 * b


def contraste(a, b) -> float:
    la, lb = _luma(a), _luma(b)
    alto, baixo = max(la, lb), min(la, lb)
    return (0.05 + alto) / (0.05 + baixo)


_1_255 = f32(1.0 / f32(255.0))


def de_hex(h: str):
    """`into_format::<f32>()` do palette para u8: k vezes o RECÍPROCO de 255 em
    f32 — e não k/255. Um ulp de diferença, e é o ulp que decide: medido no
    oráculo, 0xF9 vira 0.9764706492 (e não 0.9764705896), e a metade dele,
    vezes 255, cai acima de 124,5 — o `link_button.on_disabled` do Dracula é
    #5E4A7D por causa disso."""
    h = h.strip().strip('"').lstrip("#")
    if len(h) == 6:
        h += "FF"
    return tuple(f32(float(int(h[i:i + 2], 16)) * _1_255) for i in (0, 2, 4, 6))


def para_hex(c) -> str:
    """`into_format::<u8>()` do palette: x*255 em f32, arredondado para o par."""
    def u8(x):
        v = min(f32(x * 255.0), 255.0)
        return 0 if v <= 0 else int(round(v))
    return "#" + "".join("%02X" % u8(x) for x in c)


# ===========================================================================
# 2. O QUE O ACENTO PINTA — A LISTA É A DO theme.rs DO LIBCOSMIC
# ===========================================================================
# Todo componente leva o acento em `focus` e `selected_text`. Os arquivos que
# são `Container` o levam dentro de `component.`.
COMPONENTES = (
    "accent", "accent_button", "button", "destructive", "destructive_button",
    "icon_button", "link_button", "list_button", "success", "success_button",
    "text_button", "warning", "warning_button",
)
CONTAINERS = (
    "background", "primary", "secondary",
    "transparent_background", "transparent_primary", "transparent_secondary",
)


def _campos(txt: str) -> dict:
    return v1.achatar(v1.parse(txt))


def _cor(campos: dict, cam: str):
    tipo, valor, _ = campos[cam]
    if tipo != "cor":
        raise ValueError(cam)
    return de_hex(valor)


def cor_exata(txt: str):
    """A cor de um arquivo de receita SEM passar por 8 bits: hex vira u8/255 em
    f32, como o `into_format` do palette; float fica o float que está escrito
    (a `neutral_tint` do mocha-mauve foi gravada assim)."""
    no = v1.parse(txt)
    while no[0] in ("Some", "nomeado"):
        no = no[1] if no[0] == "Some" else no[1][1]
    if no[0] == "lit":
        return de_hex(no[1][0])
    if v1.e_cor(no):
        d = dict(no[1])
        return tuple(f32(float(d[k][1][0])) if k in d else 1.0
                     for k in ("red", "green", "blue", "alpha"))
    raise ValueError(f"não é cor: {txt.strip()[:40]}")


def pintar(produto: dict, receita: dict, acento_hex: str) -> tuple[dict, dict]:
    """Os valores novos de cada campo que o acento pinta, numa árvore.

    `produto` e `receita` são {chave: texto} de `<Árvore>/v2` e
    `<Árvore>.Builder/v2`. Devolve ({(arquivo, caminho): "#RRGGBBAA"},
    {arquivo: texto inteiro}) — o segundo para o que muda de FORMA (o
    `accent_text` passa de None a Some e volta) e não cabe numa troca no lugar.
    """
    A = de_hex(acento_hex)[:3] + (1.0,)
    ler = {k: _campos(t) for k, t in produto.items() if k in COMPONENTES + CONTAINERS}
    escuro = produto.get("is_dark", "true").strip() == "true"
    alto_contraste = produto.get("is_high_contrast", "false").strip() == "true"

    novo = {}
    for nome in COMPONENTES:
        for cam in ("focus", "selected_text"):
            novo[(nome, cam)] = A
    for nome in CONTAINERS:
        for cam in ("component.focus", "component.selected_text"):
            novo[(nome, cam)] = A

    # A ESCADA DA NEUTRA, EM f32, E NÃO O QUE A CAPTURA MOSTRA DELA
    #   O `hovered`/`pressed` dos botões e a neutra do `accent.on` são degraus da
    #   `neutral_tint` (control_steps_array no theme.rs). A captura mostra cada
    #   um arredondado a 8 bits — e 8 bits não bastam: medido no dracula-mauve, o
    #   `accent.on` sai `#000000` mas vale ~1e-5 em f32, e é essa sobra que leva
    #   o `on_disabled` (metade do acento) de 124,5 para 125. Com o valor da
    #   captura a conta dava #5E4A7C; o COSMIC grava #5E4A7D. Por isso a escada
    #   é refeita da receita, como o COSMIC a faz.
    cinza = receita.get("neutral_tint", "None").strip()
    if not cinza.startswith("Some"):
        raise ValueError("a receita não tem neutral_tint: os degraus da neutra saem da "
                         "paleta interna do COSMIC, que a captura não traz")
    controle = degraus(cor_exata(cinza)[:3], 11)
    if not escuro:
        controle.reverse()
    sobrevoo = com_alfa(controle[5], 0.2)
    aperto = com_alfa(controle[2], 0.5)
    metade = com_alfa(A, f32(A[3] * 0.5))

    def colorido(nome, texto_sobre):
        novo[(nome, "base")] = A
        novo[(nome, "border")] = A
        novo[(nome, "disabled")] = sobre(metade, A)
        novo[(nome, "disabled_border")] = metade
        novo[(nome, "hover")] = sobre(sobrevoo, A)
        novo[(nome, "selected")] = sobre(sobrevoo, A)
        novo[(nome, "pressed")] = sobre(aperto, A)
        novo[(nome, "on_disabled")] = texto_sobre

    # accent: `colored_component(accent, control[0], ...)`.
    colorido("accent", sobre(com_alfa(controle[0], 0.5), A))

    # accent_button: o `on` é texto por contraste, na escada da `text_tint` (ou,
    # sem ela, na da control[5]), no degrau que o L do acento pede.
    tinta = receita.get("text_tint", "None").strip()
    degr_tinta = degraus(cor_exata(tinta)[:3], 100) if tinta.startswith("Some") else None
    degr_c5 = degraus(controle[5][:3], 100)
    texto_botao = cor_de_texto(indice(A[:3], 100), degr_c5, degr_c5[0], degr_tinta, 1.0)
    texto_botao = tuple(texto_botao[:3]) + (1.0,)
    colorido("accent_button", com_alfa(texto_botao, 0.5))
    novo[("accent_button", "on")] = texto_botao

    # accent_text: só existe quando o acento não contrasta 4:1 com o fundo.
    prim = _cor(ler["primary"], "base")
    if escuro:
        fundo, reserva = prim, (1.0, 1.0, 1.0, 1.0)
    else:
        bg = _cor(ler["background"], "base")
        fundo = bg if _luma(bg) < _luma(prim) else prim
        reserva = (0.0, 0.0, 0.0, 1.0)
    texto_acento = None
    if contraste(fundo, A) < 4.0:
        degr = degraus(A[:3], 100)
        t = cor_de_superficie(indice(fundo[:3], 100), 60 if alto_contraste else 50,
                              degr, escuro, (1.0, 1.0, 1.0, 1.0))
        t = tuple(t[:3]) + (1.0,)
        texto_acento = reserva if contraste(fundo, t) < 4.0 else t
    no_texto = texto_acento or A
    for nome in ("link_button", "text_button"):
        novo[(nome, "on")] = no_texto
        novo[(nome, "divider")] = com_alfa(no_texto, 0.65 if alto_contraste else 0.2)
    # link_button: `over(on@0.5, base)` com base transparente; text_button: on_65.
    novo[("link_button", "on_disabled")] = sobre(com_alfa(no_texto, 0.5), (0.0, 0.0, 0.0, 0.0))
    novo[("text_button", "on_disabled")] = com_alfa(no_texto, 0.65)

    inteiros = {"accent_text": ('Some("%s")' % para_hex(texto_acento)) if texto_acento else "None"}
    return {k: para_hex(v) for k, v in novo.items()}, inteiros


def _trocar_no_lugar(texto: str, trocas: dict) -> str:
    """Troca, no texto RON, a cor de cada caminho — sem reserializar nada.

    Hex vira hex e float vira float: a grafia do arquivo é a que o COSMIC
    escreveu, e é ela que o `cmp` do aplicar_tema.sh compara."""
    campos = _campos(texto)
    plano = []
    for cam, hexa in trocas.items():
        if cam not in campos:
            raise ValueError(f"o campo {cam} não existe no arquivo")
        tipo, valor, no = campos[cam]
        if tipo != "cor":
            raise ValueError(f"o campo {cam} não é cor")
        if valor == hexa:
            continue
        if no[0] == "lit":
            _, ini, fim = no[1]
            plano.append((ini, fim, '"%s"' % hexa))
            continue
        canais = dict(no[1])
        for i, canal in enumerate(("red", "green", "blue", "alpha")):
            oct_ = int(hexa[1 + 2 * i:3 + 2 * i], 16)
            if canal not in canais:
                if oct_ != 255:
                    raise ValueError(f"o campo {cam} não tem alpha e o novo pede {hexa}")
                continue
            _, ini, fim = canais[canal][1]
            plano.append((ini, fim, v1.texto_float(oct_ / 255.0)))
    for ini, fim, txt in sorted(plano, reverse=True):
        texto = texto[:ini] + txt + texto[fim:]
    return texto


def _acento_da_receita(receita: dict) -> str:
    txt = receita.get("accent", "None").strip()
    if not txt.startswith("Some"):
        raise ValueError("a receita não declara accent")
    return _campos(txt)["."][1]


def derivar_arvore(base: Path, arvore: str, acento_hex: str) -> dict:
    """{caminho relativo: texto novo} de uma árvore, ou ValueError dizendo qual
    campo não se deriva. Só devolve o que muda."""
    prod_d = base / f"com.system76.CosmicTheme.{arvore}" / "v2"
    rec_d = base / f"com.system76.CosmicTheme.{arvore}.Builder" / "v2"
    produto = {p.name: p.read_text() for p in prod_d.iterdir() if p.is_file()}
    receita = {p.name: p.read_text() for p in rec_d.iterdir() if p.is_file()}
    faltam = [n for n in COMPONENTES + CONTAINERS + ("accent_text",) if n not in produto]
    if faltam or "accent" not in receita:
        raise ValueError(f"a {arvore}/v2 da captura não tem {', '.join(faltam) or 'a receita do accent'}")

    # A GUARDA: com o acento que ela já tem, a conta tem de dar a própria captura.
    antigo = _acento_da_receita(receita)
    mesmo, mesmo_int = pintar(produto, receita, antigo)
    nao_fecha = []
    for (arq, cam), hexa in sorted(mesmo.items()):
        atual = _campos(produto[arq])[cam][1]
        if atual != hexa:
            nao_fecha.append(f"{arvore}/v2/{arq} {cam} (capturado {atual}, a conta dá {hexa})")
    for arq, txt in mesmo_int.items():
        if _campos(produto[arq]) != _campos(txt) and produto[arq].strip() != txt:
            nao_fecha.append(f"{arvore}/v2/{arq} (capturado {produto[arq].strip()}, a conta dá {txt})")
    if nao_fecha:
        raise ValueError("a captura não se reproduz com o acento que ela mesma declara — "
                         + "; ".join(nao_fecha[:4])
                         + (f" (e mais {len(nao_fecha) - 4})" if len(nao_fecha) > 4 else ""))

    novos, inteiros = pintar(produto, receita, acento_hex)
    por_arquivo: dict = {}
    for (arq, cam), hexa in novos.items():
        por_arquivo.setdefault(arq, {})[cam] = hexa
    saida = {}
    for arq, trocas in por_arquivo.items():
        txt = _trocar_no_lugar(produto[arq], trocas)
        if txt != produto[arq]:
            saida[f"com.system76.CosmicTheme.{arvore}/v2/{arq}"] = txt
    for arq, txt in inteiros.items():
        if produto[arq].strip() != txt:
            saida[f"com.system76.CosmicTheme.{arvore}/v2/{arq}"] = txt
    rec = _trocar_no_lugar(receita["accent"], {".": acento_hex.upper()[:7] + "FF"})
    if rec != receita["accent"]:
        saida[f"com.system76.CosmicTheme.{arvore}.Builder/v2/accent"] = rec

    # A v1 sai da v2 NOVA pela mesma função do gerar_tema_v1.py, com a v1 da
    # própria captura como molde: o que ela não pinta (alpha, estrutura) fica.
    v1_d = base / f"com.system76.CosmicTheme.{arvore}" / "v1"
    for chave in v1.CONJUNTO:
        molde = v1_d / chave
        fonte_rel = f"com.system76.CosmicTheme.{arvore}/v2/{chave}"
        if not molde.is_file() or chave not in produto:
            continue
        fonte = saida.get(fonte_rel, produto[chave])
        txt, _ = v1.gerar_arquivo(molde.read_text(), fonte)
        if txt != molde.read_text():
            saida[f"com.system76.CosmicTheme.{arvore}/v1/{chave}"] = txt
    return saida


# ===========================================================================
# 3. A CAPTURA INTEIRA: DE ONDE SAI, ONDE MORA, E QUANDO SE REESCREVE
# ===========================================================================
def base_da(captura: Path) -> str | None:
    """De qual captura esta foi derivada — ou None, se ela é fotografia."""
    try:
        linhas = (captura / "captura.txt").read_text(encoding="utf-8").splitlines()
    except OSError:
        return None
    for linha in linhas:
        if linha.startswith("origem: " + MARCA):
            return linha[len("origem: " + MARCA):].split()[0]
    return None


def _paleta() -> dict:
    import json
    return json.loads(Path(pack.paleta_do_pack_ativo()).read_text(encoding="utf-8"))


def _separar(par: str):
    flavor, _, acento = par.partition("-")
    return flavor, acento


def plano(par: str, paleta: dict | None = None, _flavor: bool = True) -> dict:
    """O que se sabe de `<flavor>-<acento>` sem escrever nada.

    estado: `fotografia` (captura tirada da GUI: nada a fazer), `derivavel`
    (há base e a conta fecha), ou `nao` (e o `motivo` diz por quê, em
    português de tela). Com `derivavel` vêm `base`, `arvore`, `acento` e
    `arquivos` (o que muda em relação à base)."""
    paleta = paleta if paleta is not None else _paleta()
    flavor, nome_acento = _separar(par)
    saida = {"par": par, "estado": "nao", "motivo": "", "base": None}
    achada = pack.captura(par)
    if achada and not base_da(Path(achada)):
        saida["estado"] = "fotografia"
        return saida
    cores = (paleta.get("flavors") or {}).get(flavor)
    if not cores:
        saida["motivo"] = f"o pack no ar não tem o flavor {flavor!r}"
        return saida
    acento = cores.get(nome_acento)
    if not acento:
        saida["motivo"] = f"{nome_acento!r} não é uma cor do flavor {flavor}"
        return saida
    arvore = "Light" if flavor in (paleta.get("claros") or []) else "Dark"
    # A BASE É A PRIMEIRA FOTOGRAFIA DO FLAVOR QUE SE REPRODUZ, EM ORDEM
    #   A ordem alfabética é só para ser a mesma em toda máquina. O que decide é
    #   a guarda: o `mocha-mauve` desta árvore (25/08) NÃO se reproduz — o
    #   `accent_button.on` dele é #020202, e o COSMIC de hoje dá #01010F com a
    #   receita que ele traz —, então o mocha deriva do `mocha-pink`, que fecha.
    recusas = []
    for nome in pack.capturas():
        if nome == par or not nome.startswith(flavor + "-") or nome == "original":
            continue
        cand = Path(pack.captura(nome) or "")
        if not cand.is_dir() or base_da(cand):
            continue
        try:
            arquivos = derivar_arvore(cand, arvore, acento)
        except (ValueError, KeyError) as e:
            recusas.append(f"{nome}: {e}")
            continue
        except OSError as e:
            # Só o `strerror`: o texto inteiro de um OSError traz o caminho
            # absoluto, e esta frase vai para a tela e para a Início.
            recusas.append(f"{nome}: {e.strerror or type(e).__name__}")
            continue
        saida.update(estado="derivavel", base=nome, arvore=arvore, acento=acento,
                     dir_base=str(cand), arquivos=arquivos)
        # O OUTRO LADO É O DO PAR DO PACK, NO MESMO ACENTO — 25/09/2026, P63
        #   A árvore que não é a do flavor vinha da base, copiada, e a Light
        #   do dracula-mauve era o Latte do Catppuccin: o dracula-pink no claro
        #   era o Latte, com o acento mauve. Quando o par do pack nesse lado
        #   nunca foi fotografado (o alucard), o lado sai da derivação dele no
        #   acento pedido — o `lado_do_par` do derivar_flavor.py, o mesmo que
        #   pôs o alucard-mauve na foto do mauve. Par com foto (o latte), ou
        #   par que não se deriva: fica o da base, como até aqui.
        import derivar_flavor
        try:
            lado = derivar_flavor.lado_do_par(par, paleta)
        except ValueError:
            lado = None
        if lado:
            prefixos = (f"com.system76.CosmicTheme.{lado['arvore']}/",
                        f"com.system76.CosmicTheme.{lado['arvore']}.Builder/")
            conteudo = {}
            for arq in sorted(cand.rglob("*")):
                rel = arq.relative_to(cand).as_posix()
                if arq.is_file() and not rel.startswith(prefixos) \
                        and rel not in ("manifesto.sha256", "captura.txt", ".gitignore"):
                    conteudo[rel] = arq.read_bytes()
            conteudo.update(lado["conteudo"])
            nome_lado = "claro" if lado["arvore"] == "Light" else "escuro"
            saida.update(conteudo=conteudo, linha_do_lado=derivar_flavor.linha_do_lado(lado),
                         lado=f"o {nome_lado} é o do {lado['par']}")
        return saida
    if recusas:
        saida["motivo"] = ("nenhuma captura do " + flavor + " se reproduz para servir de base — "
                           + " | ".join(recusas))
    elif _flavor:
        # O FLAVOR SEM FOTOGRAFIA NENHUMA SE DERIVA DE OUTRO DO MESMO LADO —
        # 25/09/2026, sprint P59. Era aqui que o alucard, o frappe e o
        # macchiato paravam: «não há tema capturado». Quem sabe fazer é o
        # irmão `derivar_flavor.py` (o cabeçalho dele diz o que se mediu); a
        # fotografia do próprio flavor, quando existe, continua sendo a base e
        # nunca chega a este ramo. O `_flavor=False` é dele: o par do outro
        # lado é pedido a este `plano` sem voltar para lá, e um pack cujos dois
        # lados não têm foto não vira laço.
        import derivar_flavor
        return derivar_flavor.plano(par, paleta)
    else:
        saida["motivo"] = (f"não há tema capturado do {flavor} para derivar — "
                           f"sem ele, o vidro, a neutra e o fundo do COSMIC não têm de onde vir")
    return saida


def _conteudo(p: dict) -> dict:
    """{caminho relativo: bytes} da captura derivada inteira, sem o manifesto."""
    base = Path(p["dir_base"])
    arquivos = {}
    # A derivada de FLAVOR (P59) já chega inteira: ela junta duas capturas — a
    # base do mesmo lado e o par do pack no outro —, e copiar a base por baixo
    # deixaria sobrar arquivo do lado que foi trocado.
    if "conteudo" in p:
        arquivos.update(p["conteudo"])
    else:
        for arq in sorted(base.rglob("*")):
            if not arq.is_file():
                continue
            rel = arq.relative_to(base).as_posix()
            if rel in ("manifesto.sha256", "captura.txt", ".gitignore"):
                continue
            arquivos[rel] = arq.read_bytes()
    for rel, txt in p["arquivos"].items():
        arquivos[rel] = txt.encode("utf-8")
    # captura.txt SEM hora de agora: a derivação é função da base, e o arquivo
    # tem de sair igual byte a byte a cada passagem — senão toda conferência
    # acusaria diferença e o instalador reescreveria a pasta de hora em hora.
    quando = ""
    for linha in (base / "captura.txt").read_text(encoding="utf-8").splitlines():
        if linha.startswith("quando: "):
            quando = linha
    cabeca = [f"captura: {p['par']}", quando or "quando: (o da base)",
              f"origem: {MARCA}{p['base']} (scripts/derivar_acento.py)",
              f"arquivos: {len([r for r in arquivos if r.startswith('com.system76.')])}",
              f"acento: {p['acento']} na árvore {p['arvore']}"]
    if p.get("como"):
        cabeca.append(f"flavor: {p['como']}")
    if p.get("linha_do_lado"):
        cabeca.append(p["linha_do_lado"])
    arquivos["captura.txt"] = ("\n".join(cabeca) + "\n").encode("utf-8")
    arquivos[".gitignore"] = IGNORAR.encode("utf-8")
    return arquivos


def _no_disco(destino: Path) -> dict:
    fora = {}
    if destino.is_dir():
        for arq in destino.rglob("*"):
            if arq.is_file() and arq.name != "manifesto.sha256":
                fora[arq.relative_to(destino).as_posix()] = arq.read_bytes()
    return fora


def derivar(par: str, conferir: bool = False, paleta: dict | None = None) -> tuple[int, str]:
    """Garante a captura de `par`. (0, frase) já está; (1, frase) escreveu, ou
    escreveria no `conferir`; (3, frase) não se deriva, e a frase diz por quê.
    Os códigos são os do projeto (lib/comum.sh)."""
    p = plano(par, paleta)
    if p["estado"] == "fotografia":
        return 0, f"{par}: captura tirada da GUI, nada a derivar"
    if p["estado"] != "derivavel":
        return 3, f"{par}: não se deriva — {p['motivo']}"
    alvo = pack.captura_destino(par)
    if not alvo:
        return 3, f"{par}: o pack no ar não resolve onde gravar a captura"
    destino = Path(alvo)
    novo = _conteudo(p)
    if _no_disco(destino) == novo:
        return 0, f"{par}: derivada de {p['base']}, já confere"
    if destino.is_dir() and not base_da(destino):
        # Corrida com um `meow tema capturar`: a fotografia vence, sempre.
        return 0, f"{par}: captura tirada da GUI, nada a derivar"
    if conferir:
        if p.get("como"):
            return 1, f"{par}: derivaria de {p['base']} ({p['como']})"
        if p.get("lado"):
            return 1, (f"{par}: derivaria de {p['base']} ({len(p['arquivos'])} arquivo(s) do "
                       f"acento; {p['lado']})")
        return 1, f"{par}: derivaria de {p['base']} ({len(p['arquivos'])} arquivo(s) do acento)"
    # Escrita numa pasta irmã e troca por rename: quem ler no meio (o doctor,
    # o painel) vê a captura velha ou a nova, nunca uma pela metade.
    tmp = destino.with_name(f".{destino.name}.parcial.{os.getpid()}")
    velha = destino.with_name(f".{destino.name}.velha.{os.getpid()}")
    shutil.rmtree(tmp, ignore_errors=True)
    try:
        for rel, dado in novo.items():
            f = tmp / rel
            f.parent.mkdir(parents=True, exist_ok=True)
            f.write_bytes(dado)
        v1.refazer_manifesto(tmp)
        if destino.exists():
            destino.rename(velha)
        tmp.rename(destino)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
        shutil.rmtree(velha, ignore_errors=True)
    if p.get("como"):
        return 1, f"{par}: derivada de {p['base']} — {p['como']}"
    if p.get("lado"):
        return 1, (f"{par}: derivada de {p['base']} — {len(p['arquivos'])} arquivo(s) "
                   f"do acento, {p['lado']}, e o resto é o da base")
    return 1, (f"{par}: derivada de {p['base']} — {len(p['arquivos'])} arquivo(s) "
               f"do acento, o resto é o da base")


def pares_que_aplicam(flavors=None, acentos=None, paleta: dict | None = None) -> dict:
    """{flavor: {"acentos": [...], "base": nome|None, "motivo": frase}} — o que
    o cartão da cor de destaque precisa para oferecer só o que aplica.

    Uma fotografia aplica sempre; um par sem fotografia aplica se se deriva.
    A conta da guarda é feita UMA vez por flavor (é ela que escolhe a base) e
    vale para todos os acentos dele: a base não depende do acento."""
    paleta = paleta if paleta is not None else _paleta()
    fl = paleta.get("flavors") or {}
    saida = {}
    for flavor in (flavors or list(fl)):
        cores = fl.get(flavor) or {}
        nomes = [a for a in (acentos or list(cores)) if a in cores]
        ok, base, motivo = [], None, ""
        teste = None
        for a in nomes:
            achada = pack.captura(f"{flavor}-{a}")
            if achada and not base_da(Path(achada)):
                ok.append(a)
                continue
            if teste is None:
                teste = plano(f"{flavor}-{a}", paleta)
                base, motivo = teste.get("base"), teste.get("motivo", "")
            if teste["estado"] == "derivavel":
                ok.append(a)
        saida[flavor] = {"acentos": ok, "base": base, "motivo": motivo}
    return saida


def par_ativo() -> str | None:
    """FLAVOR-ACCENT de quem chamou: o ambiente (o install.sh e o bin/meow
    exportam o conf com `set -a`), e, sozinho na linha de comando, o conf."""
    fl, ac = os.environ.get("FLAVOR"), os.environ.get("ACCENT")
    if not (fl and ac):
        conf = Path(os.environ.get("MEOW_CONF") or Path.home() / ".config/meow/meow.conf")
        try:
            for linha in conf.read_text(encoding="utf-8", errors="replace").splitlines():
                linha = linha.strip()
                for chave in ("FLAVOR", "ACCENT"):
                    if linha.startswith(chave + "="):
                        valor = linha.split("=", 1)[1].split("#")[0].strip().strip("\"'")
                        if chave == "FLAVOR":
                            fl = fl or valor
                        else:
                            ac = ac or valor
        except OSError:
            pass
    return f"{fl}-{ac}" if fl and ac else None


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Deriva a captura de um acento a partir da captura do mesmo flavor.")
    ap.add_argument("pares", nargs="*", metavar="flavor-acento",
                    help="sem argumento: o FLAVOR-ACCENT do meow.conf")
    ap.add_argument("--conferir", action="store_true",
                    help="não escreve: sai 1 se derivaria, 0 se já está, 3 se não se deriva")
    ap.add_argument("--aplicam", metavar="ACENTOS", nargs="?", const="",
                    help="não escreve: imprime em JSON, por flavor do pack no ar, os acentos "
                         "que aplicam (fotografados ou deriváveis) e, quando nenhum aplica, "
                         "por quê. ACENTOS limita a lista (separados por vírgula)")
    args = ap.parse_args()
    if args.aplicam is not None:
        import json
        acentos = [a for a in args.aplicam.split(",") if a] or None
        print(json.dumps(pares_que_aplicam(acentos=acentos), ensure_ascii=False))
        return 0
    conferir = args.conferir or os.environ.get("MEOW_DRY_RUN", "0") == "1"
    pares = args.pares or [p for p in [par_ativo()] if p]
    codigos = []
    for par in pares:
        if "-" not in par or par.startswith(".") or "/" in par:
            print(f"ERRO: '{par}' não está no formato flavor-acento", file=sys.stderr)
            return 2
        rc, frase = derivar(par, conferir)
        print(f"  {frase}")
        codigos.append(rc)
    # 1 vence 3: "havia o que derivar" é a notícia que o instalador precisa
    # para rodar a geração; o 3 de um par é informação, não defeito.
    return 1 if 1 in codigos else (3 if 3 in codigos else 0)


if __name__ == "__main__":
    sys.exit(main())

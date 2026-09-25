#!/usr/bin/env python3
"""O vidro de uma captura, derivado do `alpha_map` que o COSMIC desta máquina tem.

O DEFEITO QUE ESTE ARQUIVO FECHA — 25/09/2026, sprint P58
    O `alpha_map` ao vivo, que o slider «Opacidade do vidro» gravou em 17/09,
    dá `very_high_2: 0.52615`, alpha 86. A captura `dracula-mauve` traz o mapa
    do dia da foto, `very_high_2: 0.66615`, alpha AA, e o
    `transparent_background` dela é `#383A4CAA`. O `frosted` é `VeryHigh2` nos
    dois. O `aplicar_tema.sh` deixa o `alpha_map` e o `frosted` da GUI (são as
    chaves dela) e copiava a cor da captura: na tela o vidro ficava em AA
    (67 %) com o nível escolhido pedindo 86 (52 %). E o doctor mandava
    reaplicar a captura que já estava aplicada — conselho circular.

O MAPA DO DESTINO É O SLIDER DELA, NÃO OUTRA VERSÃO DO COSMIC
    A primeira redação daqui (25/09) dizia que o mapa ao vivo era o de "um
    COSMIC atualizado em 17/09" e o da captura, "fotografia de outra versão".
    Não é, e a revisão da P58 mediu, no mesmo dia:
      · nenhum pacote do COSMIC mudou entre 11 e 21/09 (/var/log/dpkg.log): o
        cosmic-settings 1.7.0 entrou em 11/09 17:02 e o 1.9.0 em 21/09 16:49;
        em 17/09 o apt só trocou perl, sqlite, libsoup, libaom e gstreamer. O
        mapa ao vivo tem mtime 17/09 22:35:41 nas duas árvores: foi o 1.7.0;
      · ele é o `AlphaMap::default()` do libcosmic (0,90 a 0,60, o mesmo nos
        três checkouts do ~/.cargo) com `.offset(-0.12)`, os 14 níveis iguais
        em f32 — o que o slider grava: o `Message::Glass` do cosmic-settings
        (src/pages/desktop/appearance/mod.rs, igual no commit 3cb538f, o do
        pacote 1.7.0) parte do default e aplica o `offset`;
      · a captura é de 11/09 22:27, com esse mesmo 1.7.0. O mapa Dark dela é o
        `ALPHA_MAP` do gerar_temas.py, o default +0,02 que o `.ron` leva; o
        Light é o default -0,36.
    A regra fica, e o porquê é o do topo do `aplicar_tema.sh`: o `alpha_map` é
    uma preferência contínua dela (`CHAVES_DELA`), e a captura só guarda a
    posição do slider do dia em que foi tirada. Por isso a cor que carrega o
    vidro sai da receita que vai ficar no disco depois de aplicar: a da
    captura, com o `alpha_map` e o `frosted` que já estão no destino (que o
    `aplicar_tema.sh` não sobrescreve). Sem eles no destino (máquina nova), a
    captura grava os dela, e o vidro dela é o certo — nada muda.

QUAIS CAMPOS CARREGAM O VIDRO — MEDIDO NO ORÁCULO, NÃO SÓ LIDO
    O `ThemeBuilder::build()` do libcosmic (cosmic-theme/src/model/theme.rs, do
    commit c003a58 no ~/.cargo desta máquina) tira do `alpha_map[frosted]` o
    `container_alpha`, e dele o `actual_alpha` (o mesmo número, ou 1,0 se as
    quatro caixas de vidro — janelas, interface, painel, applets — estão
    desligadas). Varrido em 25/09/2026 no oráculo de bancada da P48 (o
    `build()` de verdade, compilado; ver o commit ea048f9), com as quatro
    capturas de pack, as duas árvores, os 14 níveis, três mapas (o de hoje, um
    baixo e um de bordas: 1,0, 0,995, 0,555, 0,005, 0) e as caixas como estão e
    todas desligadas: mudam EXATAMENTE os campos abaixo, e nenhum outro fora as
    próprias chaves da receita que o produto copia (`alpha_map`, `frosted`, as
    caixas):
      · `transparent_background`, `transparent_primary`, `transparent_secondary`:
        `base`, `divider`, `on`, e no `component` o `base`, `hover`, `pressed`,
        `selected`, `disabled`, `on`, `divider` e `on_disabled`;
      · `background`, `primary`, `secondary`: `on`, `divider`, e no `component`
        o `on`, `divider` e `on_disabled`;
      · `button` e `list_button`: `on`, `divider`, `on_disabled`.
    O segundo e o terceiro grupos são a razão de não bastar trocar dois dígitos
    de alpha: o `get_text()` do steps.rs anda `round((1 - alpha) * 100)` degraus
    a mais na escada do texto quando o fundo é translúcido, então outro alpha
    pode pôr o texto noutro degrau — e com ele os divisores. No `dracula-mauve`
    de hoje, de AA para 86, o texto fica no mesmo degrau e mudam só os dois
    `transparent_*` da Dark (e os três da Light, que vai de 49 para 86: cinco
    arquivos). O `mocha-pink`, fotografado em `VeryLow2` (D9) e
    aplicado aqui em `VeryHigh2` (86), tem o texto do background subindo de
    #F6F8FF para #FFFFFF: 18 arquivos, com a v1.
    O `primary` usa o `container_alpha` mesmo com as caixas desligadas; os
    outros, o `actual_alpha`. Está no código, e a varredura confirmou.

A MATEMÁTICA É A DO `derivar_acento.py`
    A escada Oklch, o `over()`, o `get_text()`, o `into_format` para u8 e a
    troca no lugar, todos em f32, já estão portados e conferidos lá (P48).
    Aqui se usam os mesmos, pelo nome. O que é só do vidro fica aqui: a escada
    que carrega alpha (`_escada`).
    (Revisão da P58, 25/09/2026: o `get_text()` com alpha morava aqui numa
    cópia, `_texto`, porque o `cor_de_texto` de lá fazia a conta do desvio em
    f64 — inofensivo lá, que só o chama com 1,0; com o vidro um `.5` no fim
    cai para o outro lado. A conta de lá passou a ser f32, e a cópia saiu. A
    varredura larga deste arquivo, antes e depois, deu as mesmas 1180
    respostas.)
    Conferido contra o oráculo em 25/09/2026: as quatro capturas de pack, as
    duas árvores, os 14 níveis de três mapas, com as caixas como estão e todas
    desligadas — 672 receitas, cada campo da lista acima igual ao que o
    `build()` escreve.
    E contra a GUI desta máquina: o backup do `aplicar_tema.sh` de 21/09 16:51
    guarda a Dark/v2 que o cosmic-settings 1.7.0 derivou da receita do
    `dracula-mauve` em 17/09 22:35:41, quando o slider gravou o mapa de hoje
    (o `cp -a` do backup preserva o mtime). Os 54 campos do vidro que a conta
    dá são os dela, um a um. Nessa gravação a GUI escreveu o mapa nas duas
    árvores e rederivou só a Dark: a Light/v2 ficou no alpha 49, com mtime de
    16/09.
    (A primeira redação atribuía essa derivação ao cosmic-settings 1.9.0,
    "entre 19 e 21/09". Não foi: o 1.9.0 entrou às 16:49 de 21/09, dois
    minutos antes do backup, e nenhuma derivação dele com este mapa está em
    disco — nos backups seguintes e no disco de hoje, o vidro da Dark/v2 é o
    das próprias capturas: AA, e o 8A do `mocha-mauve` em 24/09. Revisão da
    P58, 25/09/2026.)
    Fora do vidro a mesma receita não dá a captura: na derivação de 17/09 os
    degraus da neutra têm menos croma (a borda #A9BCF2 da captura sai
    #B7BCD7). Não é troca de versão — a captura é de 11/09 22:27 e nenhum
    pacote do COSMIC mudou até 21/09 —, e de onde a diferença vem não foi
    medido. Não é vidro; fica anotado.

A GUARDA É A DA P48, CAMPO A CAMPO
    Antes de pintar o vidro novo, a conta pinta o vidro DA PRÓPRIA CAPTURA e
    confere, em cada campo que vai mudar, que o valor fotografado é o que o
    `build()` dá. Um campo que não fecha é um campo que outra coisa escreveu (um
    COSMIC mais antigo, o ritual que copia alpha entre as paletas); trocá-lo
    seria o tema híbrido que o docs/COSMIC-THEMING.md proíbe. Nesse caso a
    árvore inteira fica com o vidro da captura — o comportamento de antes — e
    a frase diz qual campo não fecha.
    A guarda olha SÓ o campo que muda, e isso foi medido: três árvores trazem
    campos que não são o que o `build()` dá com o vidro delas — na Dark do
    `mocha-mauve`, o `divider` do background e o do secondary; na Light do
    `mocha-mauve` e na do `dracula-mauve`, esses dois e o `list_button`
    inteiro (`on`, `divider`, `on_disabled`). (Recontado na revisão da P58,
    25/09/2026: a primeira redação punha o `list_button` nas três e esquecia o
    `secondary`.) Com o mapa desta máquina esses campos não mudam (o texto fica
    no mesmo degrau), então ficam como a foto os tem, e os `transparent_*`,
    que fecham, recebem o vidro daqui. Exigir a árvore inteira recusaria as
    três, e o vidro delas ficaria errado sem que nada ficasse mais fiel por
    isso.
"""
from __future__ import annotations

import argparse
import functools
import os
import re
import shutil
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "scripts"))
import derivar_acento as ac  # noqa: E402  — a matemática f32 do libcosmic mora lá
import gerar_tema_v1 as v1  # noqa: E402  — o parser RON e a geração da v1 são dele

ARVORES = ("Dark", "Light")

# As quatro caixas de «Vidro fosco» em Aparência. Basta uma ligada para o
# `actual_alpha` ser o do nível; todas desligadas, ele é 1,0 (theme.rs).
CAIXAS = ("frosted_windows", "frosted_system_interface", "frosted_panel", "frosted_applets")

f32 = ac.f32
_ZERO = (0.0, 0.0, 0.0, 0.0)
_LIMIAR = f32(0.001)          # `base.alpha < 0.001` do Component::component


# ===========================================================================
# 1. A RECEITA: O NÍVEL, O MAPA E AS CORES DE ONDE O VIDRO SAI
# ===========================================================================
def _chave_do_nivel(nivel: str) -> str:
    """`VeryHigh2` -> `very_high_2`: o nome do campo do `AlphaMap` para cada
    variante do `BlurStrength` (a mesma conta do `_frosted_para_chave` do
    vidro.sh)."""
    return re.sub(r"(?<!^)(?=[A-Z0-9])", "_", nivel).lower()


def alfa_do_nivel(mapa: str, nivel: str) -> float:
    """O `AlphaMap::blurred_alpha(frosted)`, em f32.

    O motivo de não derivar vai para a tela do `aplicar_tema.sh`, e um nível
    que não é número punha lá o «could not convert string to float: 'abc'» do
    Python (revisão da P58, 25/09/2026). A frase é daqui."""
    nome = v1.achatar(v1.parse(nivel))["."][1]
    campos = v1.achatar(v1.parse(mapa))
    chave = _chave_do_nivel(nome)
    if chave not in campos:
        raise ValueError(f"o alpha_map não tem o nível {nome}")
    try:
        return f32(float(campos[chave][1]))
    except (TypeError, ValueError):
        raise ValueError(f"o alpha_map dá ao nível {nome} o valor {campos[chave][1]}, "
                         "que não é número") from None


def _cor(receita: dict, chave: str, obrigatoria: bool = False):
    """A cor de uma chave `Option` da receita, exata (sem passar por 8 bits),
    ou None. As obrigatórias são as que, ausentes, o COSMIC tira da paleta
    interna dele — que a captura não traz."""
    txt = receita.get(chave, "None").strip()
    if txt == "None":
        if obrigatoria:
            raise ValueError(f"a receita não tem {chave}: sem ele a cor sai da paleta "
                             "interna do COSMIC, que a captura não traz")
        return None
    return ac.cor_exata(txt)


# A ESCADA É O GROSSO DO CUSTO, E ELA SE REPETE — 25/09/2026, revisão da P58
#   A revisão mediu cada `aplicar_tema.sh` 0,15 a 0,2 s mais lento com a P58.
#   Fora os ~45 ms de partida do Python (o que custa a `original`, que para no
#   `bg_color`), o tempo é das escadas Oklch: o `pintar_vidro` roda duas vezes
#   por árvore (o vidro da captura, para a guarda, e o do destino), cada
#   passada sobe cinco escadas, e as cinco são as mesmas nas duas — a escada é
#   do RGB, o alpha só entra depois. Guardada pela cor, a segunda passada não
#   refaz nenhuma: medido, mediana de nove, o `derivar_vidro.py` foi de 170 a
#   200 ms por captura de pack para 115 a 130 ms, com as mesmas 1180 respostas
#   na varredura. A escada guardada é tupla: o `ctl.reverse()` do claro vira a
#   lista que o `_escada` monta a cada chamada, nunca a guardada.
@functools.lru_cache(maxsize=None)
def _degraus(rgb: tuple, n: int) -> tuple:
    return tuple(tuple(c[:3]) for c in ac.degraus(rgb, n))


def _escada(cor, n: int) -> list:
    """`steps()` de uma cor COM alpha. A conta é no Oklch, que não olha o
    alpha, e o `oklch_to_srgba_nearest_chroma` o devolve intacto: a escada do
    fundo translúcido é a do fundo, degrau a degrau, com outro alpha."""
    return [c + (cor[3],) for c in _degraus(tuple(cor[:3]), n)]


def _com_alfa(escada: list, alfa: float) -> list:
    return [c[:3] + (alfa,) for c in escada]


# ===========================================================================
# 2. O QUE O VIDRO PINTA — O build() DO theme.rs, SÓ NOS CAMPOS DA LISTA
# ===========================================================================
def pintar_vidro(produto: dict, receita: dict, alfa: float, alfa_real: float) -> dict:
    """{(arquivo, caminho): "#RRGGBBAA"} dos campos que carregam o vidro, com o
    `container_alpha` = `alfa` e o `actual_alpha` = `alfa_real`.

    Os nomes seguem o theme.rs para quem for conferir linha a linha. A ORDEM
    importa num ponto: o overlay de hover que os dois transparentes de baixo
    usam é o que o bloco do `secondary` deixou na variável (o Rust avalia os
    campos do `Theme { ... }` na ordem escrita, e o `secondary` vem antes)."""
    escuro = produto.get("is_dark", "true").strip() == "true"
    alto = produto.get("is_high_contrast", "false").strip() == "true"

    bg = _cor(receita, "bg_color", obrigatoria=True)
    cinza = _cor(receita, "neutral_tint", obrigatoria=True)
    tinta = _cor(receita, "text_tint")
    prim = _cor(receita, "primary_container_bg")
    sec = _cor(receita, "secondary_container_bg")

    # `neutral_tint` e `text_tint` são `Srgb` na receita: a escada sai opaca.
    ctl = _escada(cinza[:3] + (1.0,), 11)
    if not escuro:
        ctl.reverse()
    tinta_esc = _escada(tinta[:3] + (1.0,), 100) if tinta else None
    degr = _escada(bg, 100)
    i_bg = ac.indice(bg[:3], 100)

    # O `get_text()` com o alpha: anda mais degraus quanto mais translúcido o
    # fundo (a conta em f32 mora no derivar_acento.py).
    def texto(base, escada, a):
        return ac.cor_de_texto(base, escada, ctl[8], tinta_esc, a)

    def superficie(base, passos, escada, reserva, onde):
        cor = ac.cor_de_superficie(base, passos, escada, escuro, reserva)
        if cor is None:
            raise ValueError(f"o {onde} cai fora da escada e sairia da paleta interna do "
                             "COSMIC, que a captura não traz")
        return cor

    novo = {}

    def texto_do_componente(nome, pref, on):
        # Component::component: divider = on a 20 % (65 % em alto contraste),
        # on_disabled = on a 65 %.
        novo[(nome, pref + "on")] = on
        novo[(nome, pref + "divider")] = ac.com_alfa(on, 0.65 if alto else 0.2)
        novo[(nome, pref + "on_disabled")] = ac.com_alfa(on, 0.65)

    def componente_de_vidro(nome, base, on, sobrevoo, aperto):
        novo[(nome, "component.base")] = base
        if base[3] < _LIMIAR:
            hover, pressed = sobrevoo, aperto
        else:
            hover, pressed = ac.sobre(sobrevoo, base), ac.sobre(aperto, base)
        novo[(nome, "component.hover")] = hover
        novo[(nome, "component.selected")] = hover
        novo[(nome, "component.pressed")] = pressed
        novo[(nome, "component.disabled")] = base[:3] + (f32(base[3] * 0.5),)
        texto_do_componente(nome, "component.", on)

    def recipiente(nome, base, on, com_base=False):
        # Container::new: divider = over(on a 20 % (50 % em alto contraste), base).
        if com_base:
            novo[(nome, "base")] = base
        novo[(nome, "on")] = on
        novo[(nome, "divider")] = ac.sobre(ac.com_alfa(on, 0.5 if alto else 0.2), base)

    # background, button, list_button — o texto usa o actual_alpha.
    comp_bg = superficie(i_bg, 8, degr, None, "component do background")
    on_comp_bg = texto(ac.indice(comp_bg[:3], 100), degr, alfa_real)
    texto_do_componente("background", "component.", on_comp_bg)
    recipiente("background", bg, texto(i_bg, degr, alfa_real))
    texto_do_componente("button", "", on_comp_bg)
    texto_do_componente("list_button", "", on_comp_bg)

    # primary — o texto usa o container_alpha, com as caixas ligadas ou não.
    p = prim if prim is not None else superficie(i_bg, 5, degr, ctl[1], "primary")
    degr_p = _escada(p, 100)
    i_p = ac.indice(p[:3], 100)
    comp_p = superficie(i_p, 6, degr_p, ctl[3], "component do primary")
    texto_do_componente("primary", "component.", texto(ac.indice(comp_p[:3], 100), degr_p, alfa))
    recipiente("primary", p, texto(i_p, degr_p, alfa))

    # secondary — o texto na escada do FUNDO (a dele é `t_step_array`).
    s = sec if sec is not None else superficie(i_bg, 10, degr, ctl[2], "secondary")
    degr_s = _escada(s, 100)
    i_s = ac.indice(s[:3], 100)
    comp_s = superficie(i_s, 3, degr_s, ctl[4], "component do secondary")
    texto_do_componente("secondary", "component.", texto(ac.indice(comp_s[:3], 100), degr, alfa_real))
    recipiente("secondary", s, texto(i_s, degr, alfa_real))
    realce = ctl[10] if i_s < 91 else ctl[0]
    sobrevoo, aperto = ac.com_alfa(realce, 0.1), ac.com_alfa(realce, 0.2)

    # transparent_background — o fundo com o alpha do nível.
    tb = ac.com_alfa(bg, alfa)
    comp_tb = superficie(i_bg, 8, _com_alfa(degr, tb[3]), None, "component do transparent_background")
    componente_de_vidro("transparent_background", comp_tb,
                        texto(ac.indice(comp_tb[:3], 100), degr, alfa_real), sobrevoo, aperto)
    recipiente("transparent_background", tb, texto(i_bg, degr, alfa_real), com_base=True)

    # transparent_primary — alpha do nível + 0,3 (0,25 no claro), até 1; sem overlay.
    tp = ac.com_alfa(p, min(f32(alfa + f32(0.3 if escuro else 0.25)), 1.0))
    comp_tp = superficie(i_p, 6, _com_alfa(degr_p, tp[3]), ctl[3], "component do transparent_primary")
    componente_de_vidro("transparent_primary", comp_tp,
                        texto(ac.indice(comp_tp[:3], 100), degr, alfa_real), _ZERO, _ZERO)
    recipiente("transparent_primary", tp, texto(i_p, degr, alfa_real), com_base=True)

    # transparent_secondary — alpha do nível + 0,6 (0,5 no claro), até 1; o
    # texto na escada DELE, que o bloco sombreia com o mesmo nome.
    ts = ac.com_alfa(s, min(f32(alfa + f32(0.6 if escuro else 0.5)), 1.0))
    degr_ts = _com_alfa(degr_s, ts[3])
    comp_ts = superficie(i_s, 3, degr_ts, ctl[4], "component do transparent_secondary")
    componente_de_vidro("transparent_secondary", comp_ts,
                        texto(ac.indice(comp_ts[:3], 100), degr_ts, alfa_real), sobrevoo, aperto)
    recipiente("transparent_secondary", ts, texto(i_s, degr_ts, alfa_real), com_base=True)

    return {k: ac.para_hex(v) for k, v in novo.items()}


# ===========================================================================
# 3. UMA ÁRVORE: O QUE MUDA, A GUARDA, A TROCA NO LUGAR
# ===========================================================================
def _ler(arq: Path) -> str | None:
    try:
        return arq.read_text(encoding="utf-8")
    except OSError:
        return None


def _hex_alfa(a: float) -> str:
    return ac.para_hex((0.0, 0.0, 0.0, a))[-2:]


def derivar_arvore(captura: Path, cosmic: Path, arvore: str) -> tuple[dict, str]:
    """({caminho relativo: texto novo}, frase) do vidro de uma árvore com o
    `alpha_map` e o `frosted` do destino. ({}, "") quando nada muda; ValueError
    com o motivo quando a conta não fecha na captura."""
    prod_d = captura / f"com.system76.CosmicTheme.{arvore}" / "v2"
    rec_d = captura / f"com.system76.CosmicTheme.{arvore}.Builder" / "v2"
    if not (prod_d.is_dir() and rec_d.is_dir()):
        return {}, ""
    receita = {p.name: p.read_text(encoding="utf-8") for p in rec_d.iterdir() if p.is_file()}
    if "alpha_map" not in receita or "frosted" not in receita:
        return {}, ""
    destino = cosmic / f"com.system76.CosmicTheme.{arvore}.Builder" / "v2"
    mapa = _ler(destino / "alpha_map") or receita["alpha_map"]
    nivel = _ler(destino / "frosted") or receita["frosted"]
    alfa_cap = alfa_do_nivel(receita["alpha_map"], receita["frosted"])
    alfa = alfa_do_nivel(mapa, nivel)
    if alfa == alfa_cap:
        return {}, ""

    faltam = [c for c in CAIXAS if c not in receita]
    if faltam:
        raise ValueError(f"a receita {arvore} não diz {', '.join(faltam)}")
    ligado = any(receita[c].strip() == "true" for c in CAIXAS)
    produto = {p.name: p.read_text(encoding="utf-8") for p in prod_d.iterdir() if p.is_file()}
    antes = pintar_vidro(produto, receita, alfa_cap, alfa_cap if ligado else 1.0)
    depois = pintar_vidro(produto, receita, alfa, alfa if ligado else 1.0)
    muda = {k: v for k, v in depois.items() if v != antes[k] and k[0] in produto}

    # A GUARDA: cada campo que vai mudar tem de ser, na captura, o que o
    # build() dá com o vidro dela.
    nao_fecha = []
    for (arq, cam) in sorted(muda):
        atual = ac._campos(produto[arq]).get(cam)
        if atual is None or atual[1] != antes[(arq, cam)]:
            nao_fecha.append(f"{arvore}/v2/{arq} {cam} (capturado "
                             f"{atual[1] if atual else 'nada'}, a conta dá {antes[(arq, cam)]})")
    if nao_fecha:
        raise ValueError("o vidro da captura não se reproduz — " + "; ".join(nao_fecha[:3])
                         + (f" (e mais {len(nao_fecha) - 3})" if len(nao_fecha) > 3 else ""))

    por_arquivo: dict = {}
    for (arq, cam), hexa in muda.items():
        por_arquivo.setdefault(arq, {})[cam] = hexa
    saida = {}
    for arq, trocas in por_arquivo.items():
        saida[f"com.system76.CosmicTheme.{arvore}/v2/{arq}"] = ac._trocar_no_lugar(produto[arq], trocas)

    # A v1 é o RGB da v2 com o alpha do fóssil (gerar_tema_v1.py): um texto que
    # mudou de degrau muda lá também; o alpha, não.
    v1_d = captura / f"com.system76.CosmicTheme.{arvore}" / "v1"
    for chave in v1.CONJUNTO:
        fonte = saida.get(f"com.system76.CosmicTheme.{arvore}/v2/{chave}")
        molde = v1_d / chave
        if fonte is None or not molde.is_file():
            continue
        txt, _ = v1.gerar_arquivo(molde.read_text(encoding="utf-8"), fonte)
        if txt != molde.read_text(encoding="utf-8"):
            saida[f"com.system76.CosmicTheme.{arvore}/v1/{chave}"] = txt

    nome = v1.achatar(v1.parse(nivel))["."][1]
    return saida, (f"{arvore} '{nome}' = alpha {_hex_alfa(alfa)} do alpha_map deste COSMIC "
                   f"(a captura trazia {_hex_alfa(alfa_cap)})")


# ===========================================================================
# 4. A CAPTURA INTEIRA, VISTA DESTE COSMIC
# ===========================================================================
def _cosmic() -> Path:
    return Path(os.environ.get("MEOW_COSMIC_DIR") or Path.home() / ".config" / "cosmic")


def derivar(captura: Path, cosmic: Path) -> tuple[dict, list, list]:
    """({caminho relativo: texto}, frases do que mudou, frases do que não fecha)."""
    trocas, notas, recusas = {}, [], []
    for arvore in ARVORES:
        try:
            saida, nota = derivar_arvore(captura, cosmic, arvore)
        except (ValueError, KeyError, IndexError) as e:
            recusas.append(f"{arvore}: {e}")
            continue
        trocas.update(saida)
        if nota:
            notas.append(nota)
    return trocas, notas, recusas


def vista(captura: Path, destino: Path, cosmic: Path) -> tuple[int, str]:
    """Grava em `destino` a captura com o vidro deste COSMIC. Os códigos são os
    do projeto: 0 nada muda (a captura já traz este vidro; `destino` não é
    criado), 1 gravou, 3 não se deriva (e a frase diz por quê)."""
    trocas, notas, recusas = derivar(captura, cosmic)
    fica = ("; fica com o vidro da captura — " + " | ".join(recusas)) if recusas else ""
    if not trocas:
        if recusas:
            return 3, "vidro da captura, e não o deste COSMIC" + fica
        return 0, "a captura já traz o vidro deste COSMIC"
    # PELA METADE, NUNCA: a vista nasce ao lado e só ganha o nome no fim. O
    # `aplicar_tema.sh` REMOVE do COSMIC o que não está na captura que ele lê;
    # uma vista incompleta com o nome certo seria um `rm` no tema dela.
    parcial = destino.with_name(destino.name + ".parcial")
    shutil.rmtree(parcial, ignore_errors=True)
    shutil.copytree(captura, parcial, symlinks=True)
    for rel, txt in trocas.items():
        (parcial / rel).write_text(txt, encoding="utf-8")
    parcial.rename(destino)
    return 1, (f"vidro: {'; '.join(notas)} — {len(trocas)} arquivo(s) rederivados{fica}")


def alfa_aplicado(captura: Path, cosmic: Path) -> str | None:
    """O alpha (dois dígitos) do `Dark/v2/transparent_background` depois de
    aplicar a captura neste COSMIC — o que o `vidro.sh` compara com o nível."""
    rel = "com.system76.CosmicTheme.Dark/v2/transparent_background"
    try:
        texto = derivar_arvore(captura, cosmic, "Dark")[0].get(rel)
    except (ValueError, KeyError, IndexError):
        texto = None
    texto = texto or _ler(captura / rel)
    if texto is None:
        return None
    base = ac._campos(texto).get("base")
    return base[1][-2:] if base else None


def main() -> int:
    ap = argparse.ArgumentParser(
        description="O vidro de uma captura, derivado do alpha_map do COSMIC de MEOW_COSMIC_DIR.")
    ap.add_argument("captura", help="a pasta da captura")
    modo = ap.add_mutually_exclusive_group(required=True)
    modo.add_argument("--vista", metavar="DESTINO",
                      help="grava em DESTINO a captura com o vidro deste COSMIC: sai 0 se nada "
                           "muda (e não cria DESTINO), 1 se gravou, 3 se não se deriva")
    modo.add_argument("--alfa", action="store_true",
                      help="imprime o alpha do Dark/v2/transparent_background que a captura "
                           "grava ao ser aplicada aqui")
    args = ap.parse_args()
    captura = Path(args.captura)
    if not captura.is_dir():
        print(f"ERRO: '{captura}' não é uma captura", file=sys.stderr)
        return 2
    if args.alfa:
        try:
            a = alfa_aplicado(captura, _cosmic())
        except Exception as e:  # noqa: BLE001
            print(f"ERRO: {type(e).__name__}: {e}", file=sys.stderr)
            return 2
        if a is None:
            return 3
        print(a)
        return 0
    destino = Path(args.vista)
    if destino.exists():
        print(f"ERRO: '{destino}' já existe", file=sys.stderr)
        return 2
    # Exceção que escapa sai 1 no Python — e 1 aqui quer dizer "a vista está
    # pronta". Qualquer erro não previsto vira 2, o erro do projeto.
    try:
        rc, frase = vista(captura, destino, _cosmic())
    except Exception as e:  # noqa: BLE001
        print(f"ERRO: {type(e).__name__}: {e}", file=sys.stderr)
        return 2
    print(frase)
    return rc


if __name__ == "__main__":
    sys.exit(main())

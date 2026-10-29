#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import os
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "scripts"))
import pack  # noqa: E402
import gerar_tema_v1 as v1  # noqa: E402
import derivar_acento as da  # noqa: E402

MAPA = RAIZ / "assets" / "paleta" / "cosmic-map.json"

f32 = da.f32

CONTEINERES = da.CONTAINERS
COMPONENTES = da.COMPONENTES
DA_AURORA = ("background", "primary", "secondary")


class Escada:
    def __init__(self, cor, n):
        _, self.croma, self.matiz = da._para_oklch(cor[:3])
        self.alfa = cor[3] if len(cor) > 3 else 1.0
        self.n = n
        self._feitos = {}

    def __len__(self):
        return self.n

    def __getitem__(self, i):
        if i < 0 or i >= self.n:
            raise IndexError(i)
        if i not in self._feitos:
            L = f32(f32(float(i)) / f32(float(self.n - 1)))
            rgb = da._oklch_para_srgb_perto(L, self.croma, self.matiz)
            self._feitos[i] = tuple(rgb[:3]) + (min(max(self.alfa, 0.0), 1.0),)
        return self._feitos[i]


class Invertida:
    def __init__(self, escada):
        self.e = escada

    def __len__(self):
        return len(self.e)

    def __getitem__(self, i):
        if i < 0 or i >= len(self.e):
            raise IndexError(i)
        return self.e[len(self.e) - 1 - i]


def _indice(cor, n=100):
    return da.indice(cor[:3], n)


def _vizinho(base, passos, n, escuro):
    i = base + passos if escuro else base - passos
    return i if 0 <= i < n else None


def superficie(base, passos, escada, escuro, reserva):
    escuro = escuro or base < 91
    i = _vizinho(base, passos, len(escada), escuro)
    return escada[i] if i is not None else reserva


def texto(base, escada, reserva, tinta, alfa):
    if tinta is not None:
        escada = tinta
    extra = da._arred_rust(f32(f32(1.0 - alfa) * f32(100.0))) if alfa < 1.0 else 0
    escuro = base < 60
    i = _vizinho(base, 70 + extra, len(escada), escuro)
    if i is None:
        i = _vizinho(base, 50 + extra, len(escada), escuro)
    if i is None:
        i = 99 if escuro else 0
    return escada[i] if i < len(escada) else reserva


_M_RGB_XYZ = tuple(f32(x) for x in (
    0.4124564, 0.3575761, 0.1804375,
    0.2126729, 0.7151522, 0.0721750,
    0.0193339, 0.1191920, 0.9503041))
_M_XYZ_RGB = tuple(f32(x) for x in (
    3.2404542, -1.5371385, -0.4985314,
    -0.9692660, 1.8760108, 0.0415560,
    0.0556434, -0.2040259, 1.0572252))
_D65 = (f32(0.95047), f32(1.0), f32(1.08883))
_EPS_LAB = f32(f32(f32(6.0 / 29.0) * f32(6.0 / 29.0)) * f32(6.0 / 29.0))
_KAPPA_LAB = f32(841.0 / 108.0)
_DELTA = f32(4.0 / 29.0)
_EPS_XYZ = f32(6.0 / 29.0)
_KAPPA_XYZ = f32(108.0 / 841.0)
_R116 = f32(1.0 / f32(116.0))
_R500 = f32(1.0 / f32(500.0))
_R200 = f32(1.0 / f32(200.0))
_CROMA_MAX = f32(128.0)
_TRES_POR_CENTO = f32(f32(0.03) * _CROMA_MAX)


def _mat(m, v):
    x, y, z = v
    return (f32(f32(f32(m[0] * x) + f32(m[1] * y)) + f32(m[2] * z)),
            f32(f32(f32(m[3] * x) + f32(m[4] * y)) + f32(m[5] * z)),
            f32(f32(f32(m[6] * x) + f32(m[7] * y)) + f32(m[8] * z)))


def _cubo(c):
    return f32(f32(c * c) * c)


def _para_lch(cor):
    lin = tuple(da._para_linear(f32(c)) for c in cor[:3])
    xyz = _mat(_M_RGB_XYZ, lin)
    x, y, z = (f32(a / b) for a, b in zip(xyz, _D65))

    def conv(c):
        return da._cbrtf(c) if c > _EPS_LAB else f32(f32(_KAPPA_LAB * c) + _DELTA)
    x, y, z = conv(x), conv(y), conv(z)
    L = f32(f32(y * f32(116.0)) - f32(16.0))
    a = f32(f32(x - y) * f32(500.0))
    b = f32(f32(y - z) * f32(200.0))
    croma = f32(math.hypot(a, b))
    matiz = f32(f32(da._PI + f32(math.atan2(-b, -a))) * da._GRAUS)
    return min(max(L, 0.0), f32(100.0)), max(croma, 0.0), matiz


def _de_lch(L, croma, matiz):
    rad = f32(matiz * da._RADIANOS)
    seno, cosseno = f32(math.sin(rad)), f32(math.cos(rad))
    croma = max(croma, 0.0)
    a, b = f32(cosseno * croma), f32(seno * croma)
    y = f32(f32(L + f32(16.0)) * _R116)
    x = f32(y + f32(a * _R500))
    z = f32(y - f32(b * _R200))

    def conv(c):
        return _cubo(c) if c > _EPS_XYZ else f32(f32(c - _DELTA) * _KAPPA_XYZ)
    xyz = tuple(f32(conv(c) * w) for c, w in zip((x, y, z), _D65))
    lin = _mat(_M_XYZ_RGB, xyz)
    return tuple(min(max(da._de_linear(c), 0.0), 1.0) for c in lin)


def widget_pequeno(base, passos, escada, reserva):
    escuro = base <= 40 or (51 < base < 65)
    i = _vizinho(base, passos, len(escada), escuro)
    res = escada[i] if i is not None else reserva
    L, croma, matiz = _para_lch(res)
    if f32(croma / _CROMA_MAX) > f32(0.03):
        return _de_lch(L, _TRES_POR_CENTO, matiz) + (1.0,)
    return res


def _alfa(c, a):
    return (c[0], c[1], c[2], f32(a))


def _meio_alfa(c):
    return (c[0], c[1], c[2], f32(c[3] * f32(0.5)))


def componente(base, acento, sobre_ele, pairar, apertar, alto_contraste, borda):
    on_20 = _alfa(sobre_ele, 0.2)
    on_65 = _alfa(on_20, 0.65)
    transparente = base[3] < 0.001
    return {
        "base": base,
        "hover": pairar if transparente else da.sobre(pairar, base),
        "pressed": apertar if transparente else da.sobre(apertar, base),
        "selected": pairar if transparente else da.sobre(pairar, base),
        "selected_text": acento,
        "focus": acento,
        "divider": on_65 if alto_contraste else on_20,
        "on": sobre_ele,
        "disabled": _meio_alfa(base),
        "on_disabled": on_65,
        "border": borda,
        "disabled_border": _meio_alfa(borda),
    }


def colorido(base, neutra, acento, pairar, apertar):
    base_50 = _meio_alfa(base)
    return {
        "base": base,
        "hover": da.sobre(pairar, base),
        "pressed": da.sobre(apertar, base),
        "selected": da.sobre(pairar, base),
        "selected_text": acento,
        "divider": neutra,
        "on": neutra,
        "disabled": da.sobre(base_50, base),
        "on_disabled": da.sobre(_alfa(neutra, 0.5), base),
        "focus": acento,
        "border": base,
        "disabled_border": base_50,
    }


def botao(base, sobreposto, sobre_ele, acento, pairar, apertar):
    c = colorido(base, sobreposto, acento, pairar, apertar)
    c["on"] = sobre_ele
    c["on_disabled"] = _alfa(sobre_ele, 0.5)
    return c


def conteiner(comp, base, sobre_ele, pequeno, alto_contraste):
    return {
        "base": base,
        "component": comp,
        "divider": da.sobre(_alfa(sobre_ele, 0.5 if alto_contraste else 0.2), base),
        "on": sobre_ele,
        "small_widget": _alfa(pequeno, 0.25),
    }


def _snake(nome):
    saida = ""
    for i, ch in enumerate(nome):
        if ch.isupper() and i:
            saida += "_"
        elif ch.isdigit():
            saida += "_"
        saida += ch.lower()
    return saida


def _opcao_cor(txt, opaca=False):
    txt = txt.strip()
    if txt.startswith("None"):
        return None
    c = da.cor_exata(txt)
    return (c[0], c[1], c[2], 1.0) if opaca else c


def ler_receita(receita: dict) -> dict:
    pal_no = v1.parse(receita["palette"])
    if pal_no[0] != "nomeado":
        raise ValueError("a palette da receita não diz se é Dark ou Light")
    variante = pal_no[1][0]
    paleta = {}
    for cam, (tipo, valor, _no) in v1.achatar(pal_no).items():
        if tipo == "cor":
            paleta[cam] = da.de_hex(valor)
        elif cam == "name":
            paleta["name"] = valor.strip('"')
    mapa_alfa = {k: f32(float(v)) for k, (_t, v, _n) in v1.achatar(v1.parse(receita["alpha_map"])).items()}
    frosted = receita["frosted"].strip()
    booleano = lambda k: receita.get(k, "false").strip() == "true"  # noqa: E731
    return {
        "variante": variante,
        "escuro": variante in ("Dark", "HighContrastDark"),
        "alto_contraste": variante.startswith("HighContrast"),
        "paleta": paleta,
        "neutral_tint": _opcao_cor(receita.get("neutral_tint", "None"), opaca=True),
        "text_tint": _opcao_cor(receita.get("text_tint", "None"), opaca=True),
        "bg_color": _opcao_cor(receita.get("bg_color", "None")),
        "primary_container_bg": _opcao_cor(receita.get("primary_container_bg", "None")),
        "secondary_container_bg": _opcao_cor(receita.get("secondary_container_bg", "None")),
        "accent": _opcao_cor(receita.get("accent", "None"), opaca=True),
        "success": _opcao_cor(receita.get("success", "None"), opaca=True),
        "warning": _opcao_cor(receita.get("warning", "None"), opaca=True),
        "destructive": _opcao_cor(receita.get("destructive", "None"), opaca=True),
        "vidro": mapa_alfa[_snake(frosted)],
        "algum_vidro": any(booleano(k) for k in ("frosted_windows", "frosted_system_interface",
                                                   "frosted_panel", "frosted_applets")),
    }


def _opaca(c):
    return (c[0], c[1], c[2], 1.0)


def build(r: dict, regra_do_19=False) -> dict:
    escuro, hc, pal = r["escuro"], r["alto_contraste"], r["paleta"]
    vidro = r["vidro"]
    alfa_real = vidro if r["algum_vidro"] else 1.0

    acento = _opaca(r["accent"] or pal["accent_blue"])
    sucesso = _opaca(r["success"] or pal["bright_green"])
    aviso = _opaca(r["warning"] or pal["bright_orange"])
    perigo = _opaca(r["destructive"] or pal["bright_red"])

    tinta = Escada(r["text_tint"], 100) if r["text_tint"] is not None else None
    neutra = r["neutral_tint"]
    controle = Escada(neutra if neutra is not None else pal["neutral_2"], 11)
    if not escuro:
        controle = Invertida(controle)
    neutras = Escada(neutra if neutra is not None else (0.0, 0.0, 0.0, 1.0), 100)

    bg = r["bg_color"] if r["bg_color"] is not None else pal["gray_1"]
    escada = Escada(bg, 100)
    i_bg = _indice(bg)
    bg_vidro = _alfa(bg, vidro)
    escada_vidro = Escada(bg_vidro, 100)

    def sobrevoo(i):
        c = controle[10] if i < 91 else controle[0]
        return _alfa(c, 0.1), _alfa(c, 0.2)

    pairar_comp, apertar_comp = sobrevoo(i_bg)
    _pairar_fundo, apertar_fundo = sobrevoo(i_bg)
    fundo_botao = _alfa(controle[7], 0.25)
    pairar_botao, apertar_botao = _alfa(controle[5], 0.2), _alfa(controle[2], 0.5)

    comp_bg = superficie(i_bg, 8, escada, escuro, pal["neutral_2"])
    on_comp_bg = texto(_indice(comp_bg), escada, controle[8], tinta, alfa_real)
    comp_bg_vidro = superficie(i_bg, 8, escada_vidro, escuro, pal["neutral_2"])
    on_comp_bg_vidro = texto(_indice(comp_bg_vidro), escada, controle[8], tinta, alfa_real)

    fundo = r["primary_container_bg"]
    if fundo is None:
        fundo = superficie(i_bg, 5, escada, escuro, controle[1])
    esc_p = Escada(fundo, 100)
    i_p = _indice(fundo)
    comp_p = superficie(i_p, 6, esc_p, escuro, controle[3])
    pairar_comp, apertar_comp = sobrevoo(i_p)
    primary = conteiner(
        componente(comp_p, acento, texto(_indice(comp_p), esc_p, controle[8], tinta, vidro),
                   pairar_comp, apertar_comp, hc, controle[8]),
        fundo, texto(i_p, esc_p, controle[8], tinta, vidro),
        widget_pequeno(i_p, 5, neutras, controle[6]), hc)

    fundo = r["primary_container_bg"]
    if fundo is None:
        fundo = superficie(i_bg, 5, escada, escuro, controle[1])
    fundo = _alfa(fundo, min(f32(vidro + f32(0.3 if escuro else 0.25)), 1.0))
    esc_tp = Escada(fundo, 100)
    i_tp = _indice(fundo)
    comp_tp = superficie(i_tp, 6, esc_tp, escuro, controle[3])
    nada = (0.0, 0.0, 0.0, 0.0)
    transparent_primary = conteiner(
        componente(comp_tp, acento, texto(_indice(comp_tp), escada, controle[8], tinta, alfa_real),
                   nada, nada, hc, controle[8]),
        fundo, texto(i_tp, escada, controle[8], tinta, alfa_real),
        widget_pequeno(i_tp, 5, neutras, controle[6]), hc)

    base_p = primary["base"]
    if escuro:
        fundo_txt, reserva_txt = base_p, (1.0, 1.0, 1.0, 1.0)
    else:
        fundo_txt = bg if da._luma(bg) < da._luma(base_p) else base_p
        reserva_txt = (0.0, 0.0, 0.0, 1.0)
    acento_texto = None
    if da.contraste(fundo_txt, acento) < 4.0:
        t = superficie(_indice(fundo_txt), 60 if hc else 50, Escada(acento, 100), escuro,
                       (1.0, 1.0, 1.0, 1.0))
        acento_texto = reserva_txt if da.contraste(fundo_txt, t) < 4.0 else t

    produto = {}
    produto["background"] = conteiner(
        componente(comp_bg, acento, on_comp_bg, pairar_comp,
                   apertar_comp if regra_do_19 else apertar_fundo, hc, controle[8]),
        bg, texto(i_bg, escada, controle[8], tinta, alfa_real),
        widget_pequeno(i_bg, 5, neutras, controle[6]), hc)
    produto["primary"] = primary

    fundo = r["secondary_container_bg"]
    if fundo is None:
        fundo = superficie(i_bg, 10, escada, escuro, controle[2])
    esc_s = Escada(fundo, 100)
    i_s = _indice(fundo)
    comp_s = superficie(i_s, 3, esc_s, escuro, controle[4])
    pairar_comp, apertar_comp = sobrevoo(i_s)
    produto["secondary"] = conteiner(
        componente(comp_s, acento, texto(_indice(comp_s), escada, controle[8], tinta, alfa_real),
                   pairar_comp, apertar_comp, hc, controle[8]),
        fundo, texto(i_s, escada, controle[8], tinta, alfa_real),
        widget_pequeno(i_s, 5, neutras, controle[6]), hc)

    produto["accent"] = colorido(acento, controle[0], acento, pairar_botao, apertar_botao)
    esc_c5 = Escada(controle[5], 100)
    produto["accent_button"] = botao(
        acento, controle[1],
        texto(_indice(acento), esc_c5, esc_c5[0], tinta, 1.0),
        acento, pairar_botao, apertar_botao)
    produto["button"] = componente(fundo_botao, acento, on_comp_bg, pairar_botao, apertar_botao,
                                   hc, controle[8])
    produto["destructive"] = colorido(perigo, controle[0], acento, pairar_botao, apertar_botao)
    produto["destructive_button"] = botao(perigo, controle[1], controle[0], acento,
                                          pairar_botao, apertar_botao)
    produto["icon_button"] = componente(nada, acento, controle[8], pairar_botao, apertar_botao,
                                        hc, controle[8])
    link = componente(nada, acento, acento_texto or acento, nada, nada, hc, controle[8])
    link["on_disabled"] = da.sobre(_alfa(link["on"], 0.5), link["base"])
    produto["link_button"] = link
    produto["list_button"] = componente(nada, acento, on_comp_bg, nada, apertar_botao, hc, controle[8])
    produto["success"] = colorido(sucesso, controle[0], acento, pairar_botao, apertar_botao)
    produto["success_button"] = botao(sucesso, controle[1], controle[0], acento,
                                      pairar_botao, apertar_botao)
    produto["text_button"] = componente(nada, acento, acento_texto or acento, pairar_botao,
                                        apertar_botao, hc, controle[8])
    produto["warning"] = colorido(aviso, controle[0], acento, pairar_botao, apertar_botao)
    produto["warning_button"] = botao(aviso, controle[10], controle[0], acento,
                                      pairar_botao, apertar_botao)

    produto["transparent_background"] = conteiner(
        componente(comp_bg_vidro, acento, on_comp_bg_vidro, pairar_comp, apertar_comp, hc, controle[8]),
        bg_vidro, texto(i_bg, escada, controle[8], tinta, alfa_real),
        widget_pequeno(i_bg, 5, neutras, controle[6]), hc)
    produto["transparent_primary"] = transparent_primary

    fundo = r["secondary_container_bg"]
    if fundo is None:
        fundo = superficie(i_bg, 10, escada, escuro, controle[2])
    fundo = _alfa(fundo, min(f32(vidro + f32(0.6 if escuro else 0.5)), 1.0))
    esc_ts = Escada(fundo, 100)
    i_ts = _indice(fundo)
    comp_ts = superficie(i_ts, 3, esc_ts, escuro, controle[4])
    produto["transparent_secondary"] = conteiner(
        componente(comp_ts, acento, texto(_indice(comp_ts), esc_ts, controle[8], tinta, alfa_real),
                   pairar_comp, apertar_comp, hc, controle[8]),
        fundo, texto(i_ts, esc_ts, controle[8], tinta, alfa_real),
        widget_pequeno(i_ts, 5, neutras, controle[6]), hc)

    cores = {}
    for arq, valor in produto.items():
        caminhos = {}
        for k, v in valor.items():
            if isinstance(v, dict):
                for k2, v2 in v.items():
                    caminhos[f"component.{k2}"] = v2
            else:
                caminhos[k] = v
        cores[arq] = caminhos
    return {"cores": cores, "accent_text": acento_texto,
            "shade": (0.0, 0.0, 0.0, f32(0.32)) if escuro else (0.0, 0.0, 0.0, f32(0.08))}


def _mapa():
    return json.loads(MAPA.read_text(encoding="utf-8"))


def _trocar_literal(texto: str, caminho: str, novo: str) -> str:
    tipo, _valor, no = da._campos(texto)[caminho]
    if tipo != "lit" or no[0] != "lit":
        raise ValueError(f"o campo {caminho} não é um literal")
    _, ini, fim = no[1]
    return texto[:ini] + novo + texto[fim:]


def _trocar_paleta(texto: str, de: dict, para: dict, nome: str) -> str:
    campos = da._campos(texto)
    trocas = {}
    for slot, papel in _mapa()["palette"].items():
        if slot == "name":
            continue
        tipo, valor, _no = campos.get(slot, (None, None, None))
        if tipo != "cor":
            raise ValueError(f"a palette não tem {slot}")
        if valor.upper()[:7] != de[papel].upper():
            raise ValueError(f"palette.{slot} é {valor}, e o {papel} do flavor de origem é {de[papel]}")
        trocas[slot] = para[papel].upper() + valor.upper()[7:9]
    return _trocar_literal(da._trocar_no_lugar(texto, trocas), "name", '"%s"' % nome)


def trocar_receita(receita: dict, de: dict, acento_de: str, para: dict, acento_para: str,
                   nome: str) -> dict:
    mapa = _mapa()
    novos = {"palette": _trocar_paleta(receita["palette"], de, para, nome)}
    for campo, papel in mapa["topo"].items():
        txt = receita.get(campo, "None")
        if papel is None:
            if txt.strip() != "None":
                raise ValueError(f"{campo} é {txt.strip()[:40]}, e o mapa não o preenche")
            continue
        origem = acento_de if papel == "<accent>" else papel
        destino = acento_para if papel == "<accent>" else papel
        tipo, valor, _no = da._campos(txt).get(".", (None, None, None))
        if tipo != "cor" or valor.upper()[:7] != de[origem].upper():
            raise ValueError(f"{campo} é {txt.strip()[:40]}, e o {origem} do flavor de origem é {de[origem]}")
        novo = da._trocar_no_lugar(txt, {".": para[destino].upper() + valor.upper()[7:9]})
        if novo != txt:
            novos[campo] = novo
    return novos


def _hex_do_build(b: dict) -> dict:
    saida = {arq: {c: da.para_hex(v) for c, v in cams.items()} for arq, cams in b["cores"].items()}
    saida["shade"] = {".": da.para_hex(b["shade"])}
    return saida


def conferir_base(receita: dict, produto: dict, arvore: str):
    b = build(ler_receita(receita))
    b19 = _hex_do_build(build(ler_receita(receita), regra_do_19=True))
    nao_fecha = []
    for arq, cams in _hex_do_build(b).items():
        if arq not in produto:
            nao_fecha.append(f"{arvore}/v2/{arq} (ausente)")
            continue
        lidos = {c: v for c, (t, v, _n) in da._campos(produto[arq]).items() if t == "cor"}
        for cam, hexa in sorted(cams.items()):
            atual = lidos.get(cam, "")
            if arq in DA_AURORA and cam == "base":
                atual, hexa = atual[:7], hexa[:7]
            if (arq, cam) == ("background", "component.pressed") \
                    and atual.upper() == b19.get(arq, {}).get(cam, "").upper():
                continue
            if atual.upper() != hexa.upper():
                nao_fecha.append(f"{arvore}/v2/{arq} {cam} (capturado {atual}, a conta dá {hexa})")
    esperado = ('Some("%s")' % da.para_hex(b["accent_text"])) if b["accent_text"] else "None"
    if produto.get("accent_text", "").strip() != esperado:
        nao_fecha.append(f"{arvore}/v2/accent_text (capturado {produto.get('accent_text', '').strip()}, "
                         f"a conta dá {esperado})")
    if nao_fecha:
        raise ValueError("a captura não se reproduz com a receita que ela mesma traz — "
                         + "; ".join(nao_fecha[:3])
                         + (f" (e mais {len(nao_fecha) - 3})" if len(nao_fecha) > 3 else ""))


def escrever_produto(produto: dict, receita_nova: dict, b: dict) -> dict:
    saida = {}
    for arq, cams in _hex_do_build(b).items():
        txt = produto[arq]
        trocas = dict(cams)
        if arq in DA_AURORA:
            antigo = da._campos(txt)["base"][1]
            trocas["base"] = cams["base"][:7] + antigo.upper()[7:9]
        novo = da._trocar_no_lugar(txt, trocas)
        if novo != txt:
            saida[arq] = novo
    inteiros = {
        "accent_text": ('Some("%s")' % da.para_hex(b["accent_text"])) if b["accent_text"] else "None",
        "control_tint": receita_nova["neutral_tint"].strip(),
        "text_tint": receita_nova["text_tint"].strip(),
        "window_hint": receita_nova["window_hint"].strip(),
    }
    for arq, txt in inteiros.items():
        if arq in produto and produto[arq].strip() != txt:
            saida[arq] = txt
    nome = da._campos(receita_nova["palette"])["name"][1]
    if "name" in produto and produto["name"].strip() != nome:
        saida["name"] = nome
    if "palette" in produto:
        de = {c: v for c, (t, v, _n) in da._campos(produto["palette"]).items() if t == "cor"}
        para = {c: v for c, (t, v, _n) in da._campos(receita_nova["palette"]).items() if t == "cor"}
        trocas = {c: para[c] for c in de if c in para and para[c] != de[c]}
        novo = _trocar_literal(da._trocar_no_lugar(produto["palette"], trocas), "name", nome)
        if novo != produto["palette"]:
            saida["palette"] = novo
    return saida


def _ler_arvore(dir_: Path) -> dict:
    return {p.name: p.read_text(encoding="utf-8") for p in dir_.iterdir() if p.is_file()} \
        if dir_.is_dir() else {}


def derivar_lado(base: Path, arvore: str, de: dict, acento_de: str, para: dict, acento_para: str,
                 nome: str) -> dict:
    rec_d = base / f"com.system76.CosmicTheme.{arvore}.Builder" / "v2"
    prod_d = base / f"com.system76.CosmicTheme.{arvore}" / "v2"
    receita, produto = _ler_arvore(rec_d), _ler_arvore(prod_d)
    faltam = [n for n in ("palette", "alpha_map", "frosted") if n not in receita]
    faltam += [n for n in COMPONENTES + CONTEINERES + ("accent_text",) if n not in produto]
    if faltam:
        raise ValueError(f"a {arvore} da captura não tem {', '.join(faltam)}")
    conferir_base(receita, produto, arvore)
    trocas = trocar_receita(receita, de, acento_de, para, acento_para, nome)
    receita_nova = dict(receita, **trocas)
    novo = escrever_produto(produto, receita_nova, build(ler_receita(receita_nova)))
    saida = {f"com.system76.CosmicTheme.{arvore}.Builder/v2/{k}": v for k, v in trocas.items()}
    saida.update({f"com.system76.CosmicTheme.{arvore}/v2/{k}": v for k, v in novo.items()})
    v1_d = base / f"com.system76.CosmicTheme.{arvore}" / "v1"
    for chave in v1.CONJUNTO:
        molde = v1_d / chave
        if not molde.is_file() or chave not in produto:
            continue
        txt, _ = v1.gerar_arquivo(molde.read_text(encoding="utf-8"), novo.get(chave, produto[chave]))
        if txt != molde.read_text(encoding="utf-8"):
            saida[f"com.system76.CosmicTheme.{arvore}/v1/{chave}"] = txt
    return saida


def _pack_da_captura(captura: Path):
    d = captura.resolve()
    while d != d.parent:
        if (d / "pack.json").is_file():
            return d
        d = d.parent
    return None


def _paleta_do_pack(dir_pack) -> dict:
    try:
        arq = pack.campo(str(dir_pack), "paleta.arquivo", "paleta.json")
        alvo = (Path(dir_pack) / arq).resolve()
        if Path(dir_pack).resolve() not in alvo.parents:
            return {}
        return json.loads(alvo.read_text(encoding="utf-8"))
    except (OSError, ValueError, TypeError):
        return {}


def _lado(flavor: str, paleta: dict) -> str:
    return "Light" if flavor in (paleta.get("claros") or []) else "Dark"


def par_do_outro_lado(flavor: str, paleta: dict):
    flavors = paleta.get("flavors") or {}
    claros = [c for c in (paleta.get("claros") or []) if c in flavors]
    if flavor not in claros:
        return claros[0] if claros else None
    padrao = pack.campo(pack._ref_ativa(None), "paleta.flavor_padrao")
    if padrao in flavors and padrao not in claros:
        return padrao
    escuros = [f for f in flavors if f not in claros]
    return escuros[0] if escuros else None


def _nome_da_paleta(flavor: str) -> str:
    modelo = pack.campo(pack._ref_ativa(None), "cosmic.nome_da_paleta") \
        or _mapa()["palette"].get("name", "catppuccin-<flavor>")
    return modelo.replace("<flavor>", flavor)


def _outro_lado(par_do_par: str, outro: str, paleta: dict) -> dict:
    p = da.plano(par_do_par, paleta, _flavor=False)
    if p["estado"] == "nao":
        de_outro_flavor = plano(par_do_par, paleta, _com_par=False)
        if de_outro_flavor["estado"] == "derivavel":
            p = de_outro_flavor
    prefixos = (f"com.system76.CosmicTheme.{outro}/", f"com.system76.CosmicTheme.{outro}.Builder/")
    if p["estado"] == "fotografia":
        d = Path(pack.captura(par_do_par))
        return {a.relative_to(d).as_posix(): a.read_bytes() for a in sorted(d.rglob("*"))
                if a.is_file() and a.relative_to(d).as_posix().startswith(prefixos)}
    if p["estado"] == "derivavel":
        return {rel: dado for rel, dado in da._conteudo(p).items() if rel.startswith(prefixos)}
    raise ValueError(p["motivo"])


def plano(par: str, paleta: dict, _com_par: bool = True) -> dict:
    flavor, nome_acento = da._separar(par)
    saida = {"par": par, "estado": "nao", "motivo": "", "base": None}
    cores = (paleta.get("flavors") or {}).get(flavor) or {}
    arvore = _lado(flavor, paleta)
    outro = "Dark" if arvore == "Light" else "Light"
    lado_pt = "claro" if arvore == "Light" else "escuro"
    recusas, vistas = [], 0
    for nome in pack.capturas():
        if nome == pack.CAPTURA_DO_MOTOR or nome.startswith(flavor + "-"):
            continue
        cand = Path(pack.captura(nome) or "")
        if not cand.is_dir() or da.base_da(cand):
            continue
        dir_pack = _pack_da_captura(cand)
        pal_c = _paleta_do_pack(dir_pack) if dir_pack else {}
        fl_c, ac_c = da._separar(nome)
        cores_c = (pal_c.get("flavors") or {}).get(fl_c) or {}
        if ac_c not in cores_c or _lado(fl_c, pal_c) != arvore:
            continue
        vistas += 1
        try:
            arquivos = derivar_lado(cand, arvore, cores_c, ac_c, cores, nome_acento,
                                    _nome_da_paleta(flavor))
        except (ValueError, KeyError) as e:
            recusas.append(f"{nome}: {e}")
            continue
        except OSError as e:
            recusas.append(f"{nome}: {e.strerror or type(e).__name__}")
            continue
        break
    else:
        if recusas:
            saida["motivo"] = (f"nenhuma captura {lado_pt} se reproduz para servir de base ao "
                               f"{flavor} — " + " | ".join(recusas))
        else:
            saida["motivo"] = (f"não há tema capturado do {flavor}, nem de outro flavor {lado_pt} "
                               f"de onde derivá-lo — sem ele, o vidro, a neutra e o fundo do "
                               f"COSMIC não têm de onde vir")
        return saida

    parceiro = par_do_outro_lado(flavor, paleta) if _com_par else None
    como = f"o {fl_c} trocado slot a slot pelo {flavor}"
    lado_do_par = None
    if parceiro:
        par_do_par = f"{parceiro}-{nome_acento}"
        try:
            lado_do_par = _outro_lado(par_do_par, outro, paleta)
        except ValueError as e:
            saida["motivo"] = (f"o {'escuro' if outro == 'Dark' else 'claro'} do pack, {parceiro}, "
                               f"não tem tema: {e}")
            return saida
        como += f"; o {'escuro' if outro == 'Dark' else 'claro'} é o do {par_do_par}"
    conteudo = da.montar(cand, outro if parceiro else None, lado_do_par)
    for rel, txt in arquivos.items():
        conteudo[rel] = txt.encode("utf-8")
    saida.update(estado="derivavel", base=nome, arvore=arvore, acento=cores[nome_acento],
                 dir_base=str(cand), arquivos=arquivos, conteudo=conteudo, como=como,
                 flavor_da_base=fl_c, par_do_outro_lado=parceiro and f"{parceiro}-{nome_acento}")
    return saida


def lado_do_par(par: str, paleta: dict):
    flavor, nome_acento = da._separar(par)
    parceiro = par_do_outro_lado(flavor, paleta)
    if not parceiro:
        return None
    for nome in pack.capturas():
        achada = pack.captura(nome)
        if nome.startswith(parceiro + "-") and achada and not da.base_da(Path(achada)):
            return None
    p = plano(f"{parceiro}-{nome_acento}", paleta, _com_par=False)
    if p["estado"] != "derivavel":
        raise ValueError(p["motivo"])
    prefixos = (f"com.system76.CosmicTheme.{p['arvore']}/",
                f"com.system76.CosmicTheme.{p['arvore']}.Builder/")
    return {"par": f"{parceiro}-{nome_acento}", "arvore": p["arvore"], "base": p["base"],
            "conteudo": {rel: dado for rel, dado in p["conteudo"].items()
                         if rel.startswith(prefixos)}}


def linha_do_lado(lado: dict) -> str:
    nome = "claro" if lado["arvore"] == "Light" else "escuro"
    return f"{nome}: o do {lado['par']}, derivado de {lado['base']} (scripts/derivar_flavor.py)"


def refazer_foto(par: str, paleta: dict, conferir: bool = False) -> tuple[int, str]:
    achada = pack.captura(par)
    if not achada:
        return 3, f"{par}: não há captura com esse nome no pack no ar"
    cap = Path(achada)
    if da.base_da(cap):
        return 3, f"{par}: é derivada, e a derivada já nasce com o lado do par (derivar_acento.py)"
    try:
        lado = lado_do_par(par, paleta)
    except ValueError as e:
        return 3, f"{par}: o par do outro lado não se deriva — {e}"
    if lado is None:
        return 3, f"{par}: o outro lado fica o da foto (o pack não tem par nesse lado, ou o par tem foto)"
    nome = "claro" if lado["arvore"] == "Light" else "escuro"
    prefixos = (f"com.system76.CosmicTheme.{lado['arvore']}/",
                f"com.system76.CosmicTheme.{lado['arvore']}.Builder/")
    atual = {}
    for arq in cap.rglob("*"):
        rel = arq.relative_to(cap).as_posix()
        if arq.is_file() and rel.startswith(prefixos):
            atual[rel] = arq.read_bytes()
    novo = lado["conteudo"]
    total = sum(1 for a in cap.rglob("*") if a.is_file()
                and a.relative_to(cap).as_posix().startswith("com.system76.")) \
        - len(atual) + len(novo)
    ficha = cap / "captura.txt"
    linhas = []
    for linha in ficha.read_text(encoding="utf-8").splitlines():
        if linha.startswith(("claro: ", "escuro: ")):
            continue
        linhas.append(f"arquivos: {total}" if linha.startswith("arquivos: ") else linha)
    texto = "\n".join(linhas + [linha_do_lado(lado)]) + "\n"
    mudam = sorted(r for r in atual.keys() | novo.keys() if atual.get(r) != novo.get(r))
    if not mudam and ficha.read_text(encoding="utf-8") == texto:
        return 0, f"{par}: o {nome} já é o do {lado['par']}"
    if conferir:
        return 1, (f"{par}: poria o {nome} do {lado['par']} ({len(mudam)} arquivo(s) do "
                   f"{nome} mudam)")
    for rel in atual.keys() - novo.keys():
        (cap / rel).unlink()
    for rel, dado in novo.items():
        f = cap / rel
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_bytes(dado)
    ficha.write_text(texto, encoding="utf-8")
    v1.refazer_manifesto(cap)
    return 1, (f"{par}: o {nome} passou a ser o do {lado['par']}, derivado de {lado['base']} "
               f"— {len(mudam)} arquivo(s)")


def main() -> int:
    import argparse
    ap = argparse.ArgumentParser(
        description="Põe na captura fotografada o lado do par do pack, derivado "
                    "(o claro do dracula-mauve é o alucard-mauve).")
    ap.add_argument("pares", nargs="+", metavar="flavor-acento")
    ap.add_argument("--conferir", action="store_true",
                    help="não escreve: sai 1 se mudaria, 0 se já confere, 3 se não há o que pôr")
    args = ap.parse_args()
    conferir = args.conferir or os.environ.get("MEOW_DRY_RUN", "0") == "1"
    paleta = da._paleta()
    codigos = []
    for par in args.pares:
        if "-" not in par or par.startswith(".") or "/" in par:
            print(f"ERRO: '{par}' não está no formato flavor-acento", file=sys.stderr)
            return 2
        rc, frase = refazer_foto(par, paleta, conferir)
        print(f"  {frase}")
        codigos.append(rc)
    return 1 if 1 in codigos else (3 if 3 in codigos else 0)


if __name__ == "__main__":
    sys.exit(main())

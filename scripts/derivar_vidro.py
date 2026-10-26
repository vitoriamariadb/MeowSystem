#!/usr/bin/env python3
from __future__ import annotations

import argparse
import functools
import math
import os
import re
import shutil
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ / "scripts"))
import derivar_acento as ac  # noqa: E402
import gerar_tema_v1 as v1  # noqa: E402

ARVORES = ("Dark", "Light")

CAIXAS = ("frosted_windows", "frosted_system_interface", "frosted_panel", "frosted_applets")

f32 = ac.f32
_ZERO = (0.0, 0.0, 0.0, 0.0)
_LIMIAR = f32(0.001)


def _chave_do_nivel(nivel: str) -> str:
    return re.sub(r"(?<!^)(?=[A-Z0-9])", "_", nivel).lower()


def alfa_do_nivel(mapa: str, nivel: str) -> float:
    nome = v1.achatar(v1.parse(nivel))["."][1]
    campos = v1.achatar(v1.parse(mapa))
    chave = _chave_do_nivel(nome)
    if chave not in campos:
        raise ValueError(f"o alpha_map não tem o nível {nome}")
    try:
        alfa = f32(float(campos[chave][1]))
    except (TypeError, ValueError):
        alfa = math.nan
    if math.isnan(alfa):
        raise ValueError(f"o alpha_map dá ao nível {nome} o valor {campos[chave][1]}, "
                         "que não é número")
    return alfa


def _cor(receita: dict, chave: str, obrigatoria: bool = False):
    txt = receita.get(chave, "None").strip()
    if txt == "None":
        if obrigatoria:
            raise ValueError(f"a receita não tem {chave}: sem ele a cor sai da paleta "
                             "interna do COSMIC, que a captura não traz")
        return None
    return ac.cor_exata(txt)


@functools.lru_cache(maxsize=None)
def _degraus(rgb: tuple, n: int) -> tuple:
    return tuple(tuple(c[:3]) for c in ac.degraus(rgb, n))


def _escada(cor, n: int) -> list:
    return [c + (cor[3],) for c in _degraus(tuple(cor[:3]), n)]


def _com_alfa(escada: list, alfa: float) -> list:
    return [c[:3] + (alfa,) for c in escada]


def pintar_vidro(produto: dict, receita: dict, alfa: float, alfa_real: float) -> dict:
    escuro = produto.get("is_dark", "true").strip() == "true"
    alto = produto.get("is_high_contrast", "false").strip() == "true"

    bg = _cor(receita, "bg_color", obrigatoria=True)
    cinza = _cor(receita, "neutral_tint", obrigatoria=True)
    tinta = _cor(receita, "text_tint")
    prim = _cor(receita, "primary_container_bg")
    sec = _cor(receita, "secondary_container_bg")

    ctl = _escada(cinza[:3] + (1.0,), 11)
    if not escuro:
        ctl.reverse()
    tinta_esc = _escada(tinta[:3] + (1.0,), 100) if tinta else None
    degr = _escada(bg, 100)
    i_bg = ac.indice(bg[:3], 100)

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
        if com_base:
            novo[(nome, "base")] = base
        novo[(nome, "on")] = on
        novo[(nome, "divider")] = ac.sobre(ac.com_alfa(on, 0.5 if alto else 0.2), base)

    comp_bg = superficie(i_bg, 8, degr, None, "component do background")
    on_comp_bg = texto(ac.indice(comp_bg[:3], 100), degr, alfa_real)
    texto_do_componente("background", "component.", on_comp_bg)
    recipiente("background", bg, texto(i_bg, degr, alfa_real))
    texto_do_componente("button", "", on_comp_bg)
    texto_do_componente("list_button", "", on_comp_bg)

    p = prim if prim is not None else superficie(i_bg, 5, degr, ctl[1], "primary")
    degr_p = _escada(p, 100)
    i_p = ac.indice(p[:3], 100)
    comp_p = superficie(i_p, 6, degr_p, ctl[3], "component do primary")
    texto_do_componente("primary", "component.", texto(ac.indice(comp_p[:3], 100), degr_p, alfa))
    recipiente("primary", p, texto(i_p, degr_p, alfa))

    s = sec if sec is not None else superficie(i_bg, 10, degr, ctl[2], "secondary")
    degr_s = _escada(s, 100)
    i_s = ac.indice(s[:3], 100)
    comp_s = superficie(i_s, 3, degr_s, ctl[4], "component do secondary")
    texto_do_componente("secondary", "component.", texto(ac.indice(comp_s[:3], 100), degr, alfa_real))
    recipiente("secondary", s, texto(i_s, degr, alfa_real))
    realce = ctl[10] if i_s < 91 else ctl[0]
    sobrevoo, aperto = ac.com_alfa(realce, 0.1), ac.com_alfa(realce, 0.2)

    tb = ac.com_alfa(bg, alfa)
    comp_tb = superficie(i_bg, 8, _com_alfa(degr, tb[3]), None, "component do transparent_background")
    componente_de_vidro("transparent_background", comp_tb,
                        texto(ac.indice(comp_tb[:3], 100), degr, alfa_real), sobrevoo, aperto)
    recipiente("transparent_background", tb, texto(i_bg, degr, alfa_real), com_base=True)

    tp = ac.com_alfa(p, min(f32(alfa + f32(0.3 if escuro else 0.25)), 1.0))
    comp_tp = superficie(i_p, 6, _com_alfa(degr_p, tp[3]), ctl[3], "component do transparent_primary")
    componente_de_vidro("transparent_primary", comp_tp,
                        texto(ac.indice(comp_tp[:3], 100), degr, alfa_real), _ZERO, _ZERO)
    recipiente("transparent_primary", tp, texto(i_p, degr, alfa_real), com_base=True)

    ts = ac.com_alfa(s, min(f32(alfa + f32(0.6 if escuro else 0.5)), 1.0))
    degr_ts = _com_alfa(degr_s, ts[3])
    comp_ts = superficie(i_s, 3, degr_ts, ctl[4], "component do transparent_secondary")
    componente_de_vidro("transparent_secondary", comp_ts,
                        texto(ac.indice(comp_ts[:3], 100), degr_ts, alfa_real), sobrevoo, aperto)
    recipiente("transparent_secondary", ts, texto(i_s, degr_ts, alfa_real), com_base=True)

    return {k: ac.para_hex(v) for k, v in novo.items()}


def _ler(arq: Path) -> str | None:
    try:
        return arq.read_text(encoding="utf-8")
    except OSError:
        return None


def _hex_alfa(a: float) -> str:
    return ac.para_hex((0.0, 0.0, 0.0, a))[-2:]


def derivar_arvore(captura: Path, cosmic: Path, arvore: str) -> tuple[dict, str]:
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


def _cosmic() -> Path:
    return Path(os.environ.get("MEOW_COSMIC_DIR") or Path.home() / ".config" / "cosmic")


def derivar(captura: Path, cosmic: Path) -> tuple[dict, list, list]:
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
    trocas, notas, recusas = derivar(captura, cosmic)
    fica = ("; fica com o vidro da captura — " + " | ".join(recusas)) if recusas else ""
    if not trocas:
        if recusas:
            return 3, "vidro da captura, e não o deste COSMIC" + fica
        return 0, "a captura já traz o vidro deste COSMIC"
    parcial = destino.with_name(destino.name + ".parcial")
    shutil.rmtree(parcial, ignore_errors=True)
    shutil.copytree(captura, parcial, symlinks=True)
    for rel, txt in trocas.items():
        (parcial / rel).write_text(txt, encoding="utf-8")
    parcial.rename(destino)
    return 1, (f"vidro: {'; '.join(notas)} — {len(trocas)} arquivo(s) rederivados{fica}")


def alfa_aplicado(captura: Path, cosmic: Path) -> str | None:
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
    try:
        rc, frase = vista(captura, destino, _cosmic())
    except Exception as e:  # noqa: BLE001
        print(f"ERRO: {type(e).__name__}: {e}", file=sys.stderr)
        return 2
    print(frase)
    return rc


if __name__ == "__main__":
    sys.exit(main())

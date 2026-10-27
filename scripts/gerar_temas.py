#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
import pack  # noqa: E402

PALETA = Path(pack.paleta_do_pack_ativo())
MAPA = RAIZ / "assets" / "paleta" / "cosmic-map.json"

ESTADO = Path(os.environ.get("MEOW_ESTADO")
              or Path.home() / ".local" / "state" / "meowsystem")
DESTINO = ESTADO / "temas"

PACK_DIR = os.environ.get("MEOW_PACK_DIR") or ""


def _nome_da_paleta():
    if not PACK_DIR:
        return None
    return pack.campo(PACK_DIR, "cosmic.nome_da_paleta")


NOME_DA_PALETA = _nome_da_paleta()

ORDEM_PALETTE = [
    "name", "bright_red", "bright_green", "bright_orange", "gray_1", "gray_2",
    "neutral_0", "neutral_1", "neutral_2", "neutral_3", "neutral_4", "neutral_5",
    "neutral_6", "neutral_7", "neutral_8", "neutral_9", "neutral_10",
    "accent_blue", "accent_indigo", "accent_purple", "accent_pink", "accent_red",
    "accent_orange", "accent_yellow", "accent_green", "accent_warm_grey",
    "ext_warm_grey", "ext_orange", "ext_yellow", "ext_blue", "ext_purple",
    "ext_pink", "ext_indigo",
]

ALPHA_MAP = [
    ("extremely_low", "0.91999996"), ("extremely_low_2", "0.89691997"),
    ("very_low", "0.87385"), ("very_low_2", "0.85076"),
    ("low", "0.82769"), ("low_2", "0.80460995"),
    ("medium", "0.78154"), ("medium_2", "0.75846"),
    ("high", "0.73538"), ("high_2", "0.71230996"),
    ("very_high", "0.68022996"), ("very_high_2", "0.66615"),
    ("extremely_high", "0.64308"), ("extremely_high_2", "0.62"),
]

ESPACAMENTO = [
    ("space_none", 0), ("space_xxxs", 4), ("space_xxs", 8), ("space_xs", 12),
    ("space_s", 16), ("space_m", 24), ("space_l", 32), ("space_xl", 48),
    ("space_xxl", 64), ("space_xxxl", 128),
]


def carregar() -> tuple[dict, dict]:
    for arq in (PALETA, MAPA):
        if not arq.is_file():
            sys.exit(f"ERRO: {arq} não existe — a paleta canônica é obrigatória.")
    return json.loads(PALETA.read_text()), json.loads(MAPA.read_text())


def cor(paleta: dict, flavor: str, nome: str, alpha: str = "FF") -> str:
    try:
        return paleta["flavors"][flavor][nome] + alpha
    except KeyError:
        sys.exit(f"ERRO: cor '{nome}' não existe no flavor '{flavor}'.")


def gerar(flavor: str, accent: str, paleta: dict, mapa: dict) -> str:
    if flavor not in paleta["flavors"]:
        sys.exit(f"ERRO: flavor '{flavor}' desconhecido. Há: {', '.join(paleta['flavors'])}")
    if accent not in paleta["flavors"][flavor]:
        sys.exit(f"ERRO: accent '{accent}' não é uma cor do Catppuccin.")

    claro = flavor in paleta.get("claros", [])
    construtor = "Light" if claro else "Dark"
    alpha_bg = mapa["alpha"]["bg_color"]
    est = mapa["estrutura_preservada"]

    linhas = [
        f"// MeowSystem — {flavor.capitalize()} / accent {accent.capitalize()}",
        "// GERADO por scripts/gerar_temas.py a partir de assets/paleta/. Não edite à mão:",
        "// a próxima geração sobrescreve. Para mudar cor, mude a paleta ou o mapa.",
        "// Estrutura (raio, gaps, active_hint, frosted, alpha_map) é da Vitória e é preservada.",
        "// Importar em: Configurações > Área de trabalho > Aparência > Importar",
        "(",
        f"    palette: {construtor}((",
    ]

    for slot in ORDEM_PALETTE:
        nome = mapa["palette"][slot]
        if slot == "name":
            modelo = NOME_DA_PALETA or mapa["palette"].get("name", "catppuccin-<flavor>")
            linhas.append(f'        name: "{modelo.replace("<flavor>", flavor)}",')
        else:
            linhas.append(f'        {slot}: "{cor(paleta, flavor, nome)}",')
    linhas.append("    )),")

    linhas.append("    spacing: (")
    linhas += [f"        {k}: {v}," for k, v in ESPACAMENTO]
    linhas.append("    ),")

    r = est["corner_radii"]
    linhas.append("    corner_radii: (")
    for k in ("radius_0", "radius_xs", "radius_s", "radius_m", "radius_l", "radius_xl"):
        v = float(r[k])
        linhas.append(f"        {k}: ({v}, {v}, {v}, {v}),")
    linhas.append("    ),")

    def topo(slot: str, alpha: str = "FF") -> str:
        nome = mapa["topo"][slot]
        if nome is None:
            return "None"
        if nome == "<accent>":
            nome = accent
        return f'Some("{cor(paleta, flavor, nome, alpha)}")'

    linhas += [
        f"    neutral_tint: {topo('neutral_tint')},",
        f"    bg_color: {topo('bg_color', alpha_bg)},",
        f"    primary_container_bg: {topo('primary_container_bg')},",
        f"    secondary_container_bg: {topo('secondary_container_bg')},",
        f"    text_tint: {topo('text_tint')},",
        f"    accent: {topo('accent')},",
        f"    success: {topo('success')},",
        f"    warning: {topo('warning')},",
        f"    destructive: {topo('destructive')},",
        f"    frosted: {est['frosted']},",
        f"    gaps: ({est['gaps'][0]}, {est['gaps'][1]}),",
        f"    active_hint: {est['active_hint']},",
        f"    window_hint: {topo('window_hint')},",
        f"    frosted_windows: {str(est['frosted_windows']).lower()},",
        f"    frosted_system_interface: {str(est['frosted_system_interface']).lower()},",
        f"    frosted_panel: {str(est['frosted_panel']).lower()},",
        f"    frosted_applets: {str(est['frosted_applets']).lower()},",
        "    alpha_map: (",
    ]
    linhas += [f"        {k}: {v}," for k, v in ALPHA_MAP]
    linhas += ["    ),", ")", ""]
    return "\n".join(linhas)



def _combos_do_conf(paleta: dict) -> list[str]:
    conf = Path(os.environ.get("MEOW_CONF") or (Path.home() / ".config/meow/meow.conf"))
    flavor = accent = None
    if conf.is_file():
        for linha in conf.read_text(encoding="utf-8", errors="replace").splitlines():
            linha = linha.strip()
            for chave in ("FLAVOR", "ACCENT"):
                if linha.startswith(chave + "="):
                    valor = linha.split("=", 1)[1].split("#")[0].strip().strip('"\'')
                    if chave == "FLAVOR":
                        flavor = valor or None
                    else:
                        accent = valor or None
    if not flavor or not accent:
        return ["mocha-mauve", "mocha-pink", "latte-mauve"]
    if flavor not in paleta["flavors"]:
        flavor = (pack.campo(str(PALETA.parent), "paleta.flavor_padrao")
                  or next(iter(paleta["flavors"])))
    claros = paleta.get("claros") or []
    par_claro = [f"{c}-{accent}" for c in claros if c != flavor]
    return [f"{flavor}-{accent}"] + par_claro


def main() -> int:
    p = argparse.ArgumentParser(description="Gera os temas .ron a partir da paleta canônica.")
    p.add_argument("combos", nargs="*", metavar="flavor-accent",
                   help="ex.: mocha-mauve latte-mauve. Sem argumento, gera o conjunto padrão.")
    p.add_argument("--saida", type=Path, default=DESTINO)
    p.add_argument("--conferir", action="store_true",
                   help="não escreve: sai 1 se algum arquivo estiver diferente do que seria gerado")
    args = p.parse_args()

    paleta, mapa = carregar()
    combos = args.combos or _combos_do_conf(paleta)

    if not args.conferir:
        args.saida.mkdir(parents=True, exist_ok=True)
    divergentes = []
    ausentes = []
    for combo in combos:
        if "-" not in combo:
            sys.exit(f"ERRO: '{combo}' não está no formato flavor-accent.")
        flavor, accent = combo.split("-", 1)
        conteudo = gerar(flavor, accent, paleta, mapa)
        destino = args.saida / f"meowsystem-{combo}.ron"

        if args.conferir:
            atual = destino.read_text() if destino.is_file() else None
            estado = "ok" if atual == conteudo else ("ausente" if atual is None else "divergente")
            if estado == "ausente":
                ausentes.append(destino.name)
            elif estado == "divergente":
                divergentes.append(destino.name)
            print(f"  {estado:11s} {destino.name}")
            continue

        tmp = destino.with_suffix(".ron.tmp")
        tmp.write_text(conteudo)
        tmp.replace(destino)
        print(f"  gerado  {destino.name}  ({flavor} / {accent})")

    if args.conferir and divergentes:
        print(f"\n{len(divergentes)} arquivo(s) fora do esperado; a próxima passada que aplica os regera.")
        return 1
    if args.conferir and ausentes:
        print(f"\n{len(ausentes)} arquivo(s) ainda não gerados nesta máquina.")
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())

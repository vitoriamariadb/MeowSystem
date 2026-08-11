#!/usr/bin/env python3
"""Gera os temas .ron do COSMIC a partir da paleta canônica.

POR QUE ESTE SCRIPT EXISTE
    Nenhum hex pode viver dentro de script (regra 1 do contrato: estado desejado é
    declarado, não imperativo). Toda cor vem de `palette/catppuccin.json`, e o
    destino de cada cor vem de `palette/cosmic-map.json`. Trocar de flavor é
    trocar uma linha do meow.conf, nunca editar um tema à mão.

O QUE ELE NÃO DECIDE
    A estrutura do tema — raios, gaps, active_hint 4, frosted e o alpha_map de 14
    chaves — não é calculada aqui: sai inteira de `estrutura_preservada` no
    cosmic-map.json. Só a paleta é gerada.

    E ESSA ESTRUTURA NÃO É MAIS "A FOTO DE 04/08 QUE NINGUÉM TOCA"
    Ela era descrita aqui como "raio 8, gaps (0,5), frosted VeryLow2", herdada do
    "Estilo escuro.ron". Em 10/08/2026 esses três números foram revistos com ela:
    raios 0/4/8/16/32/160 (o padrão da libcosmic, que é o que devolve as PILULAS
    — com tudo em 8 não existe pilula em canto nenhum), gaps (12, 6) e frosted
    VeryHigh2. Este último não foi escolha nossa: a máquina JÁ estava em
    VeryHigh2 e o JSON dizia VeryLow2, então cada regeração do tema desfazia
    calado o slider dela. Alinhar a fonte ao vivo é o que impede a regressão.
    Quem fotografa o vivo de volta é `scripts/capturar_tema.sh`.

O ALPHA_MAP É COPIADO, NUNCA CALCULADO
    São 14 floats que o COSMIC exportou com a precisão dele (0.91999996 e não 0.92).
    Recalcular daria números "mais bonitos" e um diff eterno contra o que a GUI
    grava de volta. Copiar é o certo.

LATTE É CLARO, E ISSO MUDA UMA COISA SÓ
    O .ron declara `palette: Dark((...))` ou `Light((...))`. O resto do arquivo é
    idêntico — o COSMIC deriva o contraste sozinho a partir das cores. Errar esse
    construtor gera um tema que "não pega" sem dizer por quê.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PALETA = RAIZ / "palette" / "catppuccin.json"
MAPA = RAIZ / "palette" / "cosmic-map.json"
DESTINO = RAIZ / "themes"

# A ordem em que os slots aparecem no arquivo exportado pelo COSMIC. O parser RON
# não se importa com ordem, mas manter a do export deixa o `diff` legível contra o
# que a GUI grava de volta — e é assim que se descobre o que ela mudou.
ORDEM_PALETTE = [
    "name", "bright_red", "bright_green", "bright_orange", "gray_1", "gray_2",
    "neutral_0", "neutral_1", "neutral_2", "neutral_3", "neutral_4", "neutral_5",
    "neutral_6", "neutral_7", "neutral_8", "neutral_9", "neutral_10",
    "accent_blue", "accent_indigo", "accent_purple", "accent_pink", "accent_red",
    "accent_orange", "accent_yellow", "accent_green", "accent_warm_grey",
    "ext_warm_grey", "ext_orange", "ext_yellow", "ext_blue", "ext_purple",
    "ext_pink", "ext_indigo",
]

# Copiado do export da Vitória. Ver docstring: não recalcular.
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
    """Resolve um nome de cor Catppuccin para #RRGGBBAA."""
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
        f"// MeowSystem — Catppuccin {flavor.capitalize()} / accent {accent.capitalize()}",
        "// GERADO por scripts/gerar_temas.py a partir de palette/. Não edite à mão:",
        "// a próxima geração sobrescreve. Para mudar cor, mude a paleta ou o mapa.",
        "// Estrutura (raio, gaps, active_hint, frosted, alpha_map) é da Vitória e é preservada.",
        "// Importar em: Configurações > Área de trabalho > Aparência > Importar",
        "(",
        f"    palette: {construtor}((",
    ]

    for slot in ORDEM_PALETTE:
        nome = mapa["palette"][slot]
        if slot == "name":
            linhas.append(f'        name: "catppuccin-{flavor}",')
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


def main() -> int:
    p = argparse.ArgumentParser(description="Gera os temas .ron a partir da paleta canônica.")
    p.add_argument("combos", nargs="*", metavar="flavor-accent",
                   help="ex.: mocha-mauve latte-mauve. Sem argumento, gera o conjunto padrão.")
    p.add_argument("--saida", type=Path, default=DESTINO)
    p.add_argument("--conferir", action="store_true",
                   help="não escreve: sai 1 se algum arquivo estiver diferente do que seria gerado")
    args = p.parse_args()

    paleta, mapa = carregar()
    combos = args.combos or ["mocha-mauve", "mocha-pink", "latte-mauve"]

    args.saida.mkdir(parents=True, exist_ok=True)
    divergentes = []
    for combo in combos:
        if "-" not in combo:
            sys.exit(f"ERRO: '{combo}' não está no formato flavor-accent.")
        flavor, accent = combo.split("-", 1)
        conteudo = gerar(flavor, accent, paleta, mapa)
        destino = args.saida / f"meowsystem-{combo}.ron"

        if args.conferir:
            atual = destino.read_text() if destino.is_file() else None
            estado = "ok" if atual == conteudo else ("ausente" if atual is None else "divergente")
            if estado != "ok":
                divergentes.append(destino.name)
            print(f"  {estado:11s} {destino.name}")
            continue

        # Escrita atômica no MESMO diretório de destino: /mnt/Apate e $HOME são
        # sistemas de arquivos diferentes, e `mv` entre eles não é atômico.
        tmp = destino.with_suffix(".ron.tmp")
        tmp.write_text(conteudo)
        tmp.replace(destino)
        print(f"  gerado  {destino.name}  ({flavor} / {accent})")

    if args.conferir and divergentes:
        print(f"\n{len(divergentes)} arquivo(s) fora do esperado. Rode sem --conferir para regerar.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

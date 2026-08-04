#!/usr/bin/env python3
"""Gera o gato do MeowSystem em todos os flavors, a partir da paleta canônica.

POR QUE GERAR EM VEZ DE DESENHAR À MÃO
    Os SVGs feitos à mão saíram fora da paleta sem ninguém perceber: o
    `meow-latte.svg` original misturava verde do Latte (#40A02B), verde do MOCHA
    (#A6E3A1) e dois valores que não são Catppuccin nenhum (#F2B5DA, #FFFFFF).
    Um gato por flavor, escrito à mão, são 4 chances de errar em silêncio. Aqui a
    cor vem sempre de `palette/catppuccin.json`, então errar é impossível: ou o
    nome existe na paleta, ou o script falha alto.

OS PAPÉIS, NÃO AS CORES
    O desenho é descrito por PAPEL (`fundo`, `corpo`, `tinta`, `orelha`, `olho`),
    e cada papel resolve para um nome Catppuccin. Foi assim que o flavor claro
    passou a funcionar: no Mocha a tinta escura é `crust`, mas no Latte `crust` é
    quase branco — a tinta lá é `text`. Sem essa distinção, o Latte sairia com
    pupilas invisíveis, que é exatamente o tipo de erro que só aparece na tela.

DUAS VARIANTES, UMA INVERSÃO
    `cinza` é o gato claro sobre fundo escuro; `preto` inverte — gato escuro sobre
    fundo um degrau mais claro (`surface0`). Em flavor claro os dois se invertem
    de novo, e é por isso que o papel `corpo` do preto também é sensível a claro.

CUIDADO COM O NOME DO ARQUIVO
    Nunca gerar um arquivo terminado em `-symbolic.svg` para uso como logo do
    painel: o applet LogoMenu faz `.symbolic(path.contains("-symbolic.svg"))` e
    achata o desenho inteiro numa cor só. O símbolo monocromático existe, mas é
    para bandeja e ícone pequeno, gerado por `--simbolico`.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PALETA = RAIZ / "palette" / "catppuccin.json"
DESTINO = RAIZ / "assets"

# Papel -> nome de cor Catppuccin. O segundo valor vale nos flavors claros.
PAPEIS = {
    "cinza": {
        "fundo": ("crust", "crust"),
        "corpo": ("surface2", "surface2"),
        "tinta": ("crust", "text"),
    },
    "preto": {
        "fundo": ("surface0", "surface0"),
        "corpo": ("crust", "text"),
        "tinta": ("surface2", "surface2"),
    },
}
# Papéis que não mudam entre variantes.
COMUNS = {"orelha": "pink", "olho": "yellow", "brilho": "rosewater", "focinho": "pink"}


def gato(c: dict, accent: str) -> str:
    """Monta o SVG de 256x256. As coordenadas são o desenho original, preservado."""
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256" role="img" aria-label="MeowSystem cat logo">
  <title>{c['titulo']}</title>
  <circle cx="128" cy="128" r="128" fill="{c['fundo']}"></circle>
  <circle cx="128" cy="128" r="119" fill="none" stroke="{c['anel']}" stroke-width="5" opacity="0.85"></circle>
  <g fill="{c['corpo']}">
    <path d="M70 108 C60 78 66 54 78 50 C90 46 106 62 116 84 Z"></path>
    <path d="M186 108 C196 78 190 54 178 50 C166 46 150 62 140 84 Z"></path>
    <ellipse cx="128" cy="142" rx="83" ry="69"></ellipse>
  </g>
  <path d="M82 98 C77 79 80 64 86 62 C92 60 100 71 106 86 Z" fill="{c['orelha']}" opacity="0.95"></path>
  <path d="M174 98 C179 79 176 64 170 62 C164 60 156 71 150 86 Z" fill="{c['orelha']}" opacity="0.95"></path>
  <ellipse cx="72" cy="166" rx="15" ry="9" fill="{c['orelha']}" opacity="0.35"></ellipse>
  <ellipse cx="184" cy="166" rx="15" ry="9" fill="{c['orelha']}" opacity="0.35"></ellipse>
  <g opacity="0.45" stroke="{c['tinta']}" stroke-width="4" stroke-linecap="round" fill="none">
    <path d="M96 152 C80 148 66 146 52 148"></path>
    <path d="M96 164 C80 165 66 169 54 174"></path>
    <path d="M160 152 C176 148 190 146 204 148"></path>
    <path d="M160 164 C176 165 190 169 202 174"></path>
  </g>
  <circle cx="100" cy="138" r="20" fill="{c['olho']}"></circle>
  <circle cx="156" cy="138" r="20" fill="{c['olho']}"></circle>
  <circle cx="100" cy="139" r="10" fill="{c['tinta']}"></circle>
  <circle cx="156" cy="139" r="10" fill="{c['tinta']}"></circle>
  <circle cx="94" cy="132" r="5" fill="{c['brilho']}"></circle>
  <circle cx="150" cy="132" r="5" fill="{c['brilho']}"></circle>
  <path d="M121 169 C124 166 132 166 135 169 C135 175 131 179 128 179 C125 179 121 175 121 169 Z" fill="{c['focinho']}"></path>
  <g fill="none" stroke="{c['tinta']}" stroke-width="4" stroke-linecap="round" opacity="0.8">
    <path d="M128 180 C128 188 120 190 114 186"></path>
    <path d="M128 180 C128 188 136 190 142 186"></path>
  </g>
</svg>
"""


def simbolico() -> str:
    """Silhueta 16x16 monocromática (currentColor). Para bandeja e ícone pequeno."""
    return """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="16" height="16">
  <path fill="currentColor" d="M3.6 6.4C3 4.6 3.4 3.2 4.1 3c.7-.2 1.7.8 2.3 2.1a6.6 6.6 0 0 1 3.2 0C10.2 3.8 11.2 2.8 11.9 3c.7.2 1.1 1.6.5 3.4A4.6 4.6 0 0 1 13 9c0 2.2-2.2 4-5 4S3 11.2 3 9a4.6 4.6 0 0 1 .6-2.6Z"/>
  <circle cx="6.2" cy="8.6" r="1" fill="none"/>
</svg>
"""


def main() -> int:
    p = argparse.ArgumentParser(description="Gera o gato do MeowSystem a partir da paleta.")
    p.add_argument("--accent", default="mauve", help="cor do anel (padrão: mauve)")
    p.add_argument("--saida", type=Path, default=DESTINO)
    p.add_argument("--conferir", action="store_true", help="não escreve; sai 1 se algo divergir")
    args = p.parse_args()

    if not PALETA.is_file():
        sys.exit(f"ERRO: {PALETA} não existe — a paleta canônica é obrigatória.")
    paleta = json.loads(PALETA.read_text())
    claros = paleta.get("claros", [])

    args.saida.mkdir(parents=True, exist_ok=True)
    divergentes = []
    for flavor, cores in paleta["flavors"].items():
        claro = flavor in claros
        if args.accent not in cores:
            sys.exit(f"ERRO: accent '{args.accent}' não existe na paleta.")
        for variante, papeis in PAPEIS.items():
            c = {papel: cores[nomes[1 if claro else 0]] for papel, nomes in papeis.items()}
            c.update({papel: cores[nome] for papel, nome in COMUNS.items()})
            c["anel"] = cores[args.accent]
            rotulo = "cinza" if variante == "cinza" else "preto"
            c["titulo"] = f"MeowSystem — Catppuccin {flavor.capitalize()} · {rotulo}"

            nome = f"meow-{flavor}.svg" if variante == "cinza" else f"meow-{flavor}-preto.svg"
            destino = args.saida / nome
            conteudo = gato(c, args.accent)

            if args.conferir:
                atual = destino.read_text() if destino.is_file() else None
                estado = "ok" if atual == conteudo else ("ausente" if atual is None else "divergente")
                if estado != "ok":
                    divergentes.append(nome)
                print(f"  {estado:11s} {nome}")
                continue

            tmp = destino.with_suffix(".svg.tmp")
            tmp.write_text(conteudo)
            tmp.replace(destino)
            print(f"  gerado  {nome}")

    # O símbolo monocromático não depende de flavor — a cor vem de quem o desenha.
    dest_sim = args.saida / "meow-symbolic.svg"
    if args.conferir:
        atual = dest_sim.read_text() if dest_sim.is_file() else None
        estado = "ok" if atual == simbolico() else "divergente"
        if estado != "ok":
            divergentes.append(dest_sim.name)
        print(f"  {estado:11s} {dest_sim.name}")
    else:
        tmp = dest_sim.with_suffix(".svg.tmp")
        tmp.write_text(simbolico())
        tmp.replace(dest_sim)
        print(f"  gerado  {dest_sim.name}")

    if args.conferir and divergentes:
        print(f"\n{len(divergentes)} arquivo(s) fora do esperado. Rode sem --conferir para regerar.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

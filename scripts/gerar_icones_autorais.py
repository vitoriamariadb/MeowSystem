#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from xml.sax.saxutils import escape

RAIZ = Path(__file__).resolve().parent.parent
import pack  # noqa: E402

PALETA = Path(pack.paleta_do_pack_ativo())

DESTINO = Path(pack.dir_acervo("icones.autorais.desenhos",
                               padrao="icones/apps/"))

PAPEIS = {
    "vazio":    ("crust", "base"),
    "borda":    ("surface1", "overlay0"),
    "trilho":   ("surface2", "surface2"),
    "contorno": ("crust", "text"),
    "folha":    ("text", "base"),
}

IDENTIDADE = {
    "cosmic-files":      "__ACCENT__",
    "cosmic-term":       "green",
    "cosmic-store":      "sapphire",
    "cosmic-settings":   "lavender",
    "cosmic-edit":       "yellow",
    "cosmic-monitor":    "red",
    "cosmic-player":     "pink",
    "cosmic-screenshot": "teal",
}



def _moldura(c: dict) -> str:
    return (f'<rect x="3.5" y="8.5" width="41" height="31" rx="4.5" '
            f'fill="{c["vazio"]}" stroke="{c["contorno"]}" stroke-width="2"/>')


def cosmic_files(c: dict) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Gestor de Arquivos">
  <title>{c['titulo']}</title>
  <path d="M7 10 h9.8 c1.3 0 2.5 0.6 3.2 1.7 L21.6 14.4 H41 c2.5 0 4.5 2 4.5 4.5 v14.8 c0 2.5 -2 4.5 -4.5 4.5 H7 c-2.5 0 -4.5 -2 -4.5 -4.5 V14.5 c0 -2.5 2 -4.5 4.5 -4.5 z"
        fill="{c['marca']}" stroke="{c['contorno']}" stroke-width="2" stroke-linejoin="round"/>
</svg>
"""


def cosmic_term(c: dict) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Terminal">
  <title>{c['titulo']}</title>
  {_moldura(c)}
  <path d="M11.5 18.5 L18.5 24 L11.5 29.5" fill="none" stroke="{c['marca']}"
        stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>
  <rect x="22" y="26.4" width="13" height="3.2" rx="1.6" fill="{c['marca']}"/>
</svg>
"""


def cosmic_store(c: dict) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Loja de Aplicativos">
  <title>{c['titulo']}</title>
  <path d="M17.6 19.5 v-4.8 c0 -3.5 2.9 -6.4 6.4 -6.4 c3.5 0 6.4 2.9 6.4 6.4 v4.8"
        fill="none" stroke="{c['contorno']}" stroke-width="5.4" stroke-linecap="round"/>
  <path d="M17.6 19.5 v-4.8 c0 -3.5 2.9 -6.4 6.4 -6.4 c3.5 0 6.4 2.9 6.4 6.4 v4.8"
        fill="none" stroke="{c['marca']}" stroke-width="3" stroke-linecap="round"/>
  <path d="M9 17 h30 l-2.3 20.9 c-0.2 1.9 -1.8 3.3 -3.7 3.3 H15 c-1.9 0 -3.5 -1.4 -3.7 -3.3 z"
        fill="{c['marca']}" stroke="{c['contorno']}" stroke-width="2" stroke-linejoin="round"/>
</svg>
"""


def cosmic_settings(c: dict) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Configurações">
  <title>{c['titulo']}</title>
  <g fill="{c['trilho']}" stroke="{c['contorno']}" stroke-width="1.6">
    <rect x="6.8" y="12" width="34.4" height="4" rx="2"/>
    <rect x="6.8" y="22" width="34.4" height="4" rx="2"/>
    <rect x="6.8" y="32" width="34.4" height="4" rx="2"/>
  </g>
  <g fill="{c['marca']}" stroke="{c['contorno']}" stroke-width="2">
    <circle cx="16" cy="14" r="5"/>
    <circle cx="32" cy="24" r="5"/>
    <circle cx="21" cy="34" r="5"/>
  </g>
</svg>
"""


def cosmic_edit(c: dict) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Editor de Texto">
  <title>{c['titulo']}</title>
  <path d="M11 5.3 h16.1 L39.2 17.4 V39.7 c0 2.2 -1.8 4 -4 4 H11 c-2.2 0 -4 -1.8 -4 -4 V9.3 c0 -2.2 1.8 -4 4 -4 z"
        fill="{c['folha']}" stroke="{c['contorno']}" stroke-width="2" stroke-linejoin="round"/>
  <path d="M27.1 5.3 L39.2 17.4 h-8.1 c-2.2 0 -4 -1.8 -4 -4 z" fill="{c['borda']}"/>
  <g fill="{c['marca']}">
    <rect x="13" y="22" width="21" height="3.2" rx="1.6"/>
    <rect x="13" y="29" width="21" height="3.2" rx="1.6"/>
    <rect x="13" y="36" width="13" height="3.2" rx="1.6"/>
  </g>
</svg>
"""


def cosmic_monitor(c: dict) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Monitor do Sistema">
  <title>{c['titulo']}</title>
  {_moldura(c)}
  <path d="M9.5 30.5 L16.5 22.5 L22 27 L30 14.5 L38.5 23.5" fill="none"
        stroke="{c['marca']}" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
"""


def cosmic_player(c: dict) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Reprodutor de Mídia">
  <title>{c['titulo']}</title>
  <circle cx="24" cy="24" r="19" fill="{c['marca']}" stroke="{c['contorno']}" stroke-width="2"/>
  <path d="M20 15.6 L33 24 L20 32.4 Z" fill="{c['vazio']}"/>
</svg>
"""


def cosmic_screenshot(c: dict) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Captura de Tela">
  <title>{c['titulo']}</title>
  <g fill="none" stroke="{c['contorno']}" stroke-width="6" stroke-linecap="round" stroke-linejoin="round">
    <path d="M5.5 17 V10 c0 -2.5 2 -4.5 4.5 -4.5 h7"/>
    <path d="M31 5.5 h7 c2.5 0 4.5 2 4.5 4.5 v7"/>
    <path d="M42.5 31 v7 c0 2.5 -2 4.5 -4.5 4.5 h-7"/>
    <path d="M17 42.5 h-7 c-2.5 0 -4.5 -2 -4.5 -4.5 v-7"/>
  </g>
  <g fill="none" stroke="{c['marca']}" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round">
    <path d="M5.5 17 V10 c0 -2.5 2 -4.5 4.5 -4.5 h7"/>
    <path d="M31 5.5 h7 c2.5 0 4.5 2 4.5 4.5 v7"/>
    <path d="M42.5 31 v7 c0 2.5 -2 4.5 -4.5 4.5 h-7"/>
    <path d="M17 42.5 h-7 c-2.5 0 -4.5 -2 -4.5 -4.5 v-7"/>
  </g>
  <circle cx="24" cy="24" r="7.2" fill="{c['marca']}" stroke="{c['contorno']}" stroke-width="2"/>
</svg>
"""


def meowsystem_painel(c: dict) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="MeowSystem">
  <title>{c['titulo']}</title>
  <g fill="none" stroke="{c['sujeito']}" stroke-width="2.25" stroke-linecap="round" stroke-linejoin="round">
    <path d="M9.6 22.4 8.2 7.4l11.6 6.2a16 16 0 0 1 8.4 0l11.6-6.2-1.4 15"/>
    <path d="M9.6 22.4a14.4 14.4 0 1 0 28.8 0"/>
    <path d="M18.6 25v3M29.4 25v3"/>
    <path d="M24 31v1.8l-2.6 1.6M24 32.8l2.6 1.6"/>
  </g>
</svg>
"""


DESENHOS = {
    "meowsystem-painel": meowsystem_painel,
    "cosmic-files": cosmic_files,
    "cosmic-term": cosmic_term,
    "cosmic-store": cosmic_store,
    "cosmic-settings": cosmic_settings,
    "cosmic-edit": cosmic_edit,
    "cosmic-monitor": cosmic_monitor,
    "cosmic-player": cosmic_player,
    "cosmic-screenshot": cosmic_screenshot,
}


def main() -> int:
    p = argparse.ArgumentParser(description="Desenha os ícones autorais a partir da paleta.")
    p.add_argument("--accent", default="mauve",
                   help="cor do sujeito e do <accent> das declarações (padrão: mauve)")
    p.add_argument("--saida", type=Path, default=DESTINO)
    p.add_argument("--conferir", action="store_true", help="não escreve; sai 1 se algo divergir")
    args = p.parse_args()

    if not PALETA.is_file():
        sys.exit(f"ERRO: {PALETA} não existe — a paleta canônica é obrigatória.")
    paleta = json.loads(PALETA.read_text())
    claros = paleta.get("claros", [])

    declarados = {}
    try:
        for nome, (caminho, _dono) in sorted(pack.autorais().items()):
            declarados[nome] = pack.ler_autoral(caminho)
    except pack.Recusa as e:
        sys.exit(f"ERRO: declaração de desenho autoral recusada — {e}")
    repetidos = sorted(set(declarados) & set(DESENHOS))
    if repetidos:
        sys.exit(f"ERRO: {', '.join(repetidos)} tem duas fontes — uma função neste script "
                 f"e um .json no pack. Um nome, um desenho: tire um dos dois.")

    if not args.conferir:
        args.saida.mkdir(parents=True, exist_ok=True)

    ref = pack._ref_ativa(None)
    nome_do_pack = str(pack.campo(ref, "nome") or os.path.basename(str(ref).rstrip("/")))

    def titulo_de(nome: str, flavor: str) -> str:
        variante = flavor.capitalize()
        dono = nome_do_pack if variante == nome_do_pack else f"{nome_do_pack} {variante}"
        return f"{nome} — {escape(dono)}"

    divergentes = []
    for flavor, cores in paleta["flavors"].items():
        if args.accent not in cores:
            sys.exit(f"ERRO: accent '{args.accent}' não existe na paleta.")
        claro = flavor in claros
        c = {papel: cores[nomes[1 if claro else 0]] for papel, nomes in PAPEIS.items()}
        c["sujeito"] = cores[args.accent]

        def fila():
            for nome, desenha in DESENHOS.items():
                identidade = IDENTIDADE.get(nome)
                if identidade is not None:
                    c["marca"] = cores[args.accent if identidade == "__ACCENT__" else identidade]
                c["titulo"] = titulo_de(nome, flavor)
                yield nome, desenha(c)
            for nome, decl in declarados.items():
                titulo = titulo_de(nome, flavor)
                try:
                    yield nome, pack.desenhar_autoral(decl, cores, claro, args.accent,
                                                      {"titulo": titulo})
                except pack.Recusa as e:
                    sys.exit(f"ERRO: {e}")

        for nome, conteudo in fila():
            destino = args.saida / f"{nome}-{flavor}.svg"

            if args.conferir:
                atual = destino.read_text() if destino.is_file() else None
                estado = "ok" if atual == conteudo else ("ausente" if atual is None else "divergente")
                if estado != "ok":
                    divergentes.append(destino.name)
                print(f"  {estado:11s} {destino.name}")
                continue

            tmp = destino.with_suffix(".svg.tmp")
            tmp.write_text(conteudo)
            tmp.replace(destino)
            print(f"  gerado      {destino.name}")

    if args.conferir and divergentes:
        print(f"\n{len(divergentes)} arquivo(s) fora do esperado; a próxima passada que aplica os regera.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

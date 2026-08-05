#!/usr/bin/env python3
"""Desenha os ícones dos DOIS aplicativos da Vitória, a partir da paleta canônica.

    FogStripper  — removedor de fundo de imagens/vídeos (redes neurais locais)
    Hefesto      — gerenciador de DualSense para Linux

POR QUE ESTES DOIS, E SÓ ESTES
    Foram os únicos, entre os 187 `.desktop` da máquina (IDs únicos pela regra
    do XDG, 175 deles com `Icon=`), cujo ícone resolve APENAS num PNG
    rasterizado no fim da cadeia de temas (o `hicolor`). Todo o resto já cai no
    Papirus ou num tema irmão. A auditoria completa e permanente é do
    `scripts/auditar_icones.sh` — que este script NÃO chama, só aponta.

O DESENHO NASCE DA PALETA — NENHUM HEX É DIGITADO AQUI
    Mesma regra e mesmo motivo do `gerar_gato.py`: SVG escrito à mão sai fora da
    paleta sem ninguém notar. Cada forma declara um PAPEL (`sujeito`, `tinta`,
    `xadrez_a`...) e o papel resolve para um nome Catppuccin. Ou o nome existe na
    paleta, ou o script morre alto.

OS PAPÉIS SÃO SENSÍVEIS A FLAVOR CLARO, E ISSO NÃO É DETALHE
    No Mocha `text` é claro e `crust` é quase preto; no Latte os dois se
    invertem. Descrever o desenho por papel faz o Latte se resolver sozinho — o
    corpo do controle continua contrastando com o fundo do lançador nos dois.
    O `touchpad` foi o único que NÃO se resolveu sozinho, e o motivo vale nos
    DOIS extremos: o accent fica quase invisível contra o `corpo`, que é `text`.
    Razões de contraste WCAG, calculadas da própria paleta —
        Latte: mauve #8839EF x text #4C4F69 = 1,47
        Mocha: mauve #CBA6F7 x text #CDD6F4 = 1,40
    (o mínimo legível para forma grande é 3,0). Por isso o touchpad leva um
    contorno de `tinta`, e é o CONTORNO que faz a separação: tinta contra o
    corpo dá 7,06 no Latte e 12,97 no Mocha, e contra o próprio mauve dá 4,79 e
    9,23. No Mocha ele vira a moldura escura do touchpad real, no Latte a borda
    clara que o separa do corpo. Uma forma a mais que resolve os dois flavors de
    uma vez. Os números saem de `palette/catppuccin.json`, fórmula WCAG 2.x.

AS DUAS DECISÕES DE DESENHO QUE FORAM MEDIDAS A 48px, NÃO IMAGINADAS
    Os ícones são vistos a ~48px no lançador. Nesse tamanho:
    - O ícone atual do FogStripper (uma mão dissolvendo em partículas) vira um
      borrão: detalhe fino de dispersão não sobrevive a 48px. Aqui a ideia virou
      a linguagem universal do ramo — metade do quadro ainda com o fundo (com um
      sol, para ler como "foto"), metade já em xadrez de transparência, e o
      sujeito no meio das duas. A história inteira em quatro formas.
    - Uma primeira versão tinha uma linha rosa marcando a divisa. A 48px ela não
      lia como "borda do corte": lia como RISCO no ícone. Foi removida depois de
      olhar o PNG ampliado, não antes.

    O xadrez tem célula de ~5px de propósito. Abaixo de ~4px ele deixa de ler
    como xadrez e vira um cinza chapado com ruído — testado com célula de 10px
    (blocos grandes demais, não lê como transparência) e de 5px (lê).

O HEFESTO VIROU UM CONTROLE, E NÃO A BIGORNA DA MARCA
    O ícone que o repositório dele usa é martelo-e-bigorna (Hefesto, o ferreiro).
    Desenhei as duas versões e olhei a 48px: a bigorna lê como bigorna, mas não
    diz o que o programa FAZ, e o martelo vira um traço roxo solto. A silhueta de
    controle é inconfundível no mesmo tamanho, e o nome "Hefesto" continua ao
    lado do ícone no lançador — a referência ao ferreiro não se perde, ela só sai
    do desenho. Se ela preferir a bigorna, é trocar a função `hefesto()`.

    O touchpad central é o que faz o controle ser um DualSense e não um genérico.
    A barra de luz (o "U" ao redor do touchpad) ficou de fora: a 48px ela teria
    menos de 2px de espessura e viraria sujeira ao lado do touchpad.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
PALETA = RAIZ / "palette" / "catppuccin.json"
DESTINO = RAIZ / "src" / "icons" / "autorais"

# Papel -> (nome Catppuccin em flavor escuro, nome em flavor claro).
PAPEIS = {
    # FogStripper
    "foto":     ("overlay0", "overlay0"),   # o fundo que ainda não foi removido
    "sol":      ("peach", "peach"),         # marca o lado esquerdo como "foto"
    "xadrez_a": ("surface0", "surface0"),   # transparência: célula clara
    "xadrez_b": ("surface1", "surface1"),   # transparência: célula escura
    # Hefesto
    "corpo":    ("text", "text"),           # inverte sozinho entre Mocha e Latte
    "tinta":    ("crust", "base"),          # botões e analógicos, e o contorno
}
# `sujeito` (o busto) e `touchpad` usam o ACCENT do tema — vêm por parâmetro.


def _xadrez(x0: float, y0: float, w: float, h: float,
            colunas: int, linhas: int, a: str, b: str) -> str:
    """O tabuleiro de transparência, como retângulos.

    Retângulo por célula em vez de `<pattern>`: o `pattern` do SVG é suportado
    pelo rsvg, mas nem todo consumidor de ícone renderiza com uma engine SVG
    completa, e um ícone que some em UM lugar é pior do que 28 retângulos.
    """
    cw, ch = w / colunas, h / linhas
    return "".join(
        f'<rect x="{x0 + i * cw:.2f}" y="{y0 + j * ch:.2f}" '
        f'width="{cw:.2f}" height="{ch:.2f}" fill="{a if (i + j) % 2 == 0 else b}"/>'
        for i in range(colunas)
        for j in range(linhas)
    )


def fogstripper(c: dict) -> str:
    """Quadro de foto: fundo à esquerda, transparência à direita, sujeito no meio.

    O corte fica em x=24 (o meio exato do quadro de 48) e o busto é centrado nele
    de propósito: o sujeito atravessa a divisa, que é o que conta a história de
    "o fundo está sendo retirado DAQUELE sujeito".
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="FogStripper">
  <title>{c['titulo']}</title>
  <defs><clipPath id="quadro"><rect x="4" y="6" width="40" height="36" rx="7"/></clipPath></defs>
  <g clip-path="url(#quadro)">
    {_xadrez(24, 6, 20, 36, 4, 7, c['xadrez_a'], c['xadrez_b'])}
    <rect x="4" y="6" width="20" height="36" fill="{c['foto']}"/>
    <circle cx="11.5" cy="14" r="3.2" fill="{c['sol']}"/>
    <g fill="{c['sujeito']}">
      <circle cx="24" cy="19.6" r="5.6"/>
      <path d="M14.6 42 C14.6 33.6 18.8 29.8 24 29.8 C29.2 29.8 33.4 33.6 33.4 42 Z"/>
    </g>
  </g>
</svg>
"""


# A silhueta do controle. Ocupa x 5..43 e y 13..42 — quase o quadro inteiro,
# porque a 48px cada pixel de margem é presença perdida no lançador.
_CORPO = (
    "M18 13.4 h12 c6 0 9.6 3.8 10.7 9.4 l2.7 12.5 c0.9 4.2 -2.7 7.4 -6.2 5.8 "
    "l-7.1 -3.1 c-1.8 -0.8 -2.9 -1.2 -4.4 -1.2 h-5.4 c-1.5 0 -2.6 0.4 -4.4 1.2 "
    "l-7.1 3.1 c-3.5 1.6 -7.1 -1.6 -6.2 -5.8 l2.7 -12.5 c1.1 -5.6 4.7 -9.4 10.7 -9.4 z"
)


def hefesto(c: dict) -> str:
    """DualSense de frente: touchpad no accent, direcional, botões e analógicos.

    Os quatro botões têm raio 1,95 e os analógicos 3,5 — a 48px isso dá círculos
    de ~4px e ~7px. Foi o piso encontrado olhando o PNG ampliado: abaixo disso
    o conjunto vira quatro pontos indistintos e o controle perde o rosto.
    """
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" width="48" height="48" role="img" aria-label="Hefesto DualSense4Unix">
  <title>{c['titulo']}</title>
  <path d="{_CORPO}" fill="{c['corpo']}"/>
  <rect x="19.2" y="17.2" width="9.6" height="6.4" rx="1.7"
        fill="{c['touchpad']}" stroke="{c['tinta']}" stroke-width="1.2"/>
  <g fill="{c['tinta']}">
    <rect x="10.4" y="22.0" width="8.0" height="2.9" rx="1.35"/>
    <rect x="12.95" y="19.45" width="2.9" height="8.0" rx="1.35"/>
    <circle cx="33.4" cy="20.6" r="1.95"/>
    <circle cx="37.2" cy="24.2" r="1.95"/>
    <circle cx="29.6" cy="24.2" r="1.95"/>
    <circle cx="33.4" cy="27.8" r="1.95"/>
    <circle cx="19.0" cy="31.6" r="3.5"/>
    <circle cx="29.0" cy="31.6" r="3.5"/>
  </g>
</svg>
"""


DESENHOS = {"fogstripper": fogstripper, "hefesto": hefesto}


def main() -> int:
    p = argparse.ArgumentParser(description="Desenha os ícones autorais a partir da paleta.")
    p.add_argument("--accent", default="mauve", help="cor do sujeito e do touchpad (padrão: mauve)")
    p.add_argument("--saida", type=Path, default=DESTINO)
    p.add_argument("--conferir", action="store_true", help="não escreve; sai 1 se algo divergir")
    args = p.parse_args()

    if not PALETA.is_file():
        sys.exit(f"ERRO: {PALETA} não existe — a paleta canônica é obrigatória.")
    paleta = json.loads(PALETA.read_text())
    claros = paleta.get("claros", [])

    if not args.conferir:
        args.saida.mkdir(parents=True, exist_ok=True)

    divergentes = []
    for flavor, cores in paleta["flavors"].items():
        if args.accent not in cores:
            sys.exit(f"ERRO: accent '{args.accent}' não existe na paleta.")
        claro = flavor in claros
        c = {papel: cores[nomes[1 if claro else 0]] for papel, nomes in PAPEIS.items()}
        c["sujeito"] = c["touchpad"] = cores[args.accent]

        for nome, desenha in DESENHOS.items():
            c["titulo"] = f"{nome} — Catppuccin {flavor.capitalize()}"
            conteudo = desenha(c)
            destino = args.saida / f"{nome}-{flavor}.svg"

            if args.conferir:
                atual = destino.read_text() if destino.is_file() else None
                estado = "ok" if atual == conteudo else ("ausente" if atual is None else "divergente")
                if estado != "ok":
                    divergentes.append(destino.name)
                print(f"  {estado:11s} {destino.name}")
                continue

            # Temporário no MESMO diretório do destino: `replace` só é atômico
            # dentro de um sistema de arquivos, e o repo mora no Ápate enquanto
            # /tmp costuma ser outro.
            tmp = destino.with_suffix(".svg.tmp")
            tmp.write_text(conteudo)
            tmp.replace(destino)
            print(f"  gerado      {destino.name}")

    if args.conferir and divergentes:
        print(f"\n{len(divergentes)} arquivo(s) fora do esperado. Rode sem --conferir para regerar.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

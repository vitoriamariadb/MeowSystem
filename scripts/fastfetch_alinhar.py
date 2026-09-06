#!/usr/bin/env python3
# fastfetch_alinhar.py — o texto do fastfetch abraçando o contorno do gato.
#
# POR QUE ISTO EXISTE, E POR QUE NÃO PODE SER UMA CHAVE DO config.jsonc
#   Pedido dela em 06/09/2026, com setas desenhadas por cima de uma captura do
#   terminal: "escolher se as configs aparecem 3 espaços após a linha do svg
#   (alinhado à esquerda) ou se aparecem em formato tabular como está hoje".
#
#   As setas apontavam para lugares DIFERENTES em cada linha — curtas em cima
#   (onde o círculo do gato ainda é estreito), longas no meio (onde ele é
#   largo). Ou seja: o começo de cada linha de informação deveria seguir o
#   CONTORNO do desenho, e não uma coluna fixa.
#
#   O fastfetch não sabe fazer isso, e medi antes de escrever uma linha. Com
#   `--logo-type file-raw` e um logo cujas linhas têm larguras diferentes, o
#   fastfetch 2.61.0 imprime o desenho inteiro, sobe o cursor com `ESC[<n>A` e
#   emite, para CADA linha de módulo, um `ESC[<N>C` com o MESMO N — a largura
#   máxima do logo somada ao `padding.right`:
#
#       $ printf 'AA\nBBBBBBBBBB\nCCCC\nDDDDDDDDDDDDDDDD\nEE\n' > /tmp/t.ansi
#       $ fastfetch --logo-type file-raw --logo /tmp/t.ansi \
#           --logo-padding-right 3 --structure os:kernel:shell --pipe false | cat -A
#       …^[[1G^[[5A^[[m^[[19C…OS: …$
#                      ^[[19C…Kernel: …$      <- 16 + 3, igual em toda linha
#
#   19 é constante. Não há opção que mude isso: `--logo-width`,
#   `--logo-padding-*` e `--key-width` todos deslocam a MESMA coluna para todas
#   as linhas. O alinhamento tabular não é um padrão do fastfetch — é a única
#   coisa que ele sabe fazer. O contorno tem de ser composto por fora.
#
# ENTÃO O QUE ESTE ARQUIVO FAZ
#   Recebe a saída do fastfetch SEM logo (`--logo none`), lê o `gato.ansi` que o
#   `fastfetch_logo.sh` gerou, e costura as duas colunas linha a linha: a linha
#   do desenho tem o rabo de espaços cortado, e a linha de texto entra
#   `--recuo` colunas depois do último traço visível daquela linha.
#
#   O corte é o ponto delicado, e é por isso que ele não é um `rstrip()` seco: o
#   `.ansi` é feito de blocos coloridos, e cada bloco carrega um `ESC[38;2;r;g;b`
#   à frente. Cortar a string crua no meio de uma sequência de escape pintaria o
#   terminal inteiro da cor de um pixel do focinho. A função `_cortar` percorre
#   texto e escapes separadamente: conta só o que OCUPA coluna, e deixa passar
#   todo escape que encontrar pelo caminho.
#
# O ALINHAMENTO VERTICAL É O MESMO DO `padding.top`
#   `--topo N` empurra o DESENHO N linhas para baixo, que é o que o
#   `"padding": {"top": 6}` do config.jsonc dela faz hoje. As N primeiras linhas
#   de texto (o título, o separador e as duas ou três primeiras chaves) ficam
#   então acima do gato e começam na coluna 0 — exatamente o que as setas mais
#   compridas do desenho dela indicavam.
#
# O QUE ELE NÃO FAZ
#   Não chama o fastfetch (quem chama é o `meow-fetch`, que o `install.sh`
#   instala em ~/.local/bin), não lê o meow.conf, não escreve em disco e não
#   colore nada: as cores que saem daqui são as que entraram, do fastfetch e do
#   `.ansi`. Um filtro que repinta é um segundo dono da paleta, e este projeto
#   já pagou essa conta.
#
#   E ele NUNCA falha com pilha de erro na cara dela: um `gato.ansi` ausente,
#   ilegível ou vazio faz a saída do fastfetch passar INTACTA (o `--logo none`
#   já é uma tela válida). Um terminal que não abre porque o filtro do gato
#   quebrou seria um preço absurdo por um enfeite.
#
# USO
#   fastfetch --logo none --pipe false | fastfetch_alinhar.py \
#       --gato ~/.local/share/meowsystem/fastfetch/gato.ansi --recuo 3 --topo 6
#
#   --conferir  não imprime a composição: sai 0 se dá para compor (o .ansi está
#               lá e é legível) e 4 se não dá. É o que o `doctor` usa.

import argparse
import os
import re
import sys

# `[a-zA-Z]` no fim e não só `m`: além da cor (SGR), o fastfetch emite
# movimentação de cursor. Contar um `ESC[2K` como dois caracteres visíveis
# deslocaria a linha inteira.
ESCAPE = re.compile(r"\x1b\[[0-9;?]*[a-zA-Z]")


def _visivel(linha):
    """A linha como o olho a vê: sem os escapes, que não ocupam coluna."""
    return ESCAPE.sub("", linha)


def _cortar(linha, colunas):
    """A linha até `colunas` células, com TODOS os escapes preservados.

    Fatiar a string crua cortaria escapes no meio. Aqui o `re.split` com grupo
    de captura devolve texto e escape alternados; os escapes passam inteiros e
    sem custo, e só o texto é contado e aparado.
    """
    saida, contadas = [], 0
    for pedaco in ESCAPE.split(linha) if False else re.split(r"(\x1b\[[0-9;?]*[a-zA-Z])", linha):
        if not pedaco:
            continue
        if ESCAPE.fullmatch(pedaco):
            saida.append(pedaco)
            continue
        if contadas >= colunas:
            continue
        cabe = pedaco[: colunas - contadas]
        saida.append(cabe)
        contadas += len(cabe)
    return "".join(saida)


def _ler_gato(caminho):
    """As linhas do desenho, ou [] quando não há desenho utilizável.

    Devolver [] em vez de estourar é a decisão do cabeçalho: sem gato, a saída
    do fastfetch passa como está.
    """
    try:
        with open(os.path.expanduser(caminho), encoding="utf-8", errors="replace") as f:
            bruto = f.read()
    except OSError:
        return []
    linhas = bruto.rstrip("\n").split("\n")
    return linhas if any(_visivel(l).strip() for l in linhas) else []


def compor(texto, gato, recuo, topo):
    """As duas colunas costuradas. `texto` e `gato` são listas de linhas."""
    desenho = [""] * max(topo, 0) + gato
    altura = max(len(desenho), len(texto))
    for i in range(altura):
        d = desenho[i] if i < len(desenho) else ""
        t = texto[i] if i < len(texto) else ""
        largura = len(_visivel(d).rstrip())
        if largura:
            # O `ESC[0m` fecha a cor do último bloco do desenho. Sem ele o
            # branco da chave herdaria a cor do pixel em que o corte caiu.
            yield _cortar(d, largura) + "\x1b[0m" + " " * recuo + t
        elif t:
            # Linha sem desenho (o recuo do topo, ou o texto que passou da
            # altura do gato): o recuo continua valendo, senão o bloco de cima
            # e o de baixo começariam em colunas diferentes.
            yield " " * recuo + t
        else:
            yield ""


def main():
    p = argparse.ArgumentParser(add_help=True, description=__doc__)
    p.add_argument("--gato", default="~/.local/share/meowsystem/fastfetch/gato.ansi")
    p.add_argument("--recuo", type=int, default=3,
                   help="colunas entre o fim do desenho e o começo do texto")
    p.add_argument("--topo", type=int, default=6,
                   help="linhas em branco antes do desenho (o padding.top de hoje)")
    p.add_argument("--conferir", action="store_true",
                   help="não compõe; sai 0 se dá para compor, 4 se não dá")
    args = p.parse_args()

    gato = _ler_gato(args.gato)

    if args.conferir:
        if gato:
            print("logo ANSI legível (%d linhas)" % len(gato))
            return 0
        print("sem logo ANSI utilizável em %s" % args.gato, file=sys.stderr)
        return 4

    bruto = sys.stdin.read()
    if not gato:
        sys.stdout.write(bruto)
        return 0

    texto = bruto.rstrip("\n").split("\n")
    sys.stdout.write("\n".join(compor(texto, gato, max(args.recuo, 0), args.topo)) + "\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except BrokenPipeError:
        # `| head` fecha o cano. Morrer com rastreamento aqui sujaria o terminal
        # dela por causa de um enfeite.
        os._exit(0)
    except KeyboardInterrupt:
        os._exit(130)

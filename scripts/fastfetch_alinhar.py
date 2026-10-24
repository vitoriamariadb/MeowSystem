#!/usr/bin/env python3
# fastfetch_alinhar.py — o texto do fastfetch abraçando o contorno do mascote.
#
# As setas apontavam para lugares DIFERENTES em cada linha — curtas em cima
# (onde o círculo do mascote ainda é estreito), longas no meio (onde ele é largo).
# Ou seja: o começo de cada linha de informação deveria seguir o CONTORNO do
# desenho, e não uma coluna fixa.
#
# O fastfetch não sabe fazer isso, e medi antes de escrever uma linha.
#
#       $ printf 'AA\nBBBBBBBBBB\nCCCC\nDDDDDDDDDDDDDDDD\nEE\n' > /tmp/t.ansi
#       $ fastfetch --logo-type file-raw --logo /tmp/t.ansi \
#           --logo-padding-right 3 --structure os:kernel:shell --pipe false | cat -A
#       …^[[1G^[[5A^[[m^[[19C…OS: …$
#                      ^[[19C…Kernel: …$      <- 16 + 3, igual em toda linha
#
#   --conferir  não imprime a composição: sai 0 se dá para compor (o .ansi está
#               lá e é legível) e 4 se não dá. É o que o `doctor` usa.

# Nunca falha com pilha de erro: um `gato.ansi` ausente ou ilegível deixa a saída do
# fastfetch passar intacta — o terminal não pode deixar de abrir por um enfeite.
import argparse
import os
import re
import sys

# `[a-zA-Z]` no fim e não só `m`: além da cor (SGR), o fastfetch emite
# movimentação de cursor. Contar um `ESC[2K` como dois caracteres visíveis
# deslocaria a linha inteira.
ESCAPE = re.compile(r"\x1b\[[0-9;?]*[a-zA-Z]")


def _inteiro(valor, padrao, nome):
    """O valor como inteiro não negativo, ou `padrao` — e um aviso no stderr.

    O stderr não suja o cano: quem lê a saudação vê o texto, e quem for depurar
    vê o motivo."""
    try:
        return max(int(str(valor).strip()), 0)
    except (TypeError, ValueError):
        print("meow-fetch: %s=%r não é número — usando %r"
              % (nome, valor, padrao), file=sys.stderr)
        return padrao


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

    Devolver [] em vez de estourar é a decisão do cabeçalho: sem mascote, a saída
    do fastfetch passa como está.
    """
    try:
        with open(os.path.expanduser(caminho), encoding="utf-8", errors="replace") as f:
            bruto = f.read()
    except OSError:
        return []
    linhas = bruto.rstrip("\n").split("\n")
    return linhas if any(_visivel(l).strip() for l in linhas) else []


# O separador que o fastfetch imprime logo abaixo do título: uma linha inteira
# de traços, do mesmo comprimento do nome. Os caracteres cobrem o hífen comum e
# os traços de caixa que outros temas usam.
TRACOS = set("-—–─━═_=")


def _e_separador(linha):
    """A linha é a régua que fica embaixo do título?"""
    v = _visivel(linha).strip()
    return len(v) >= 3 and set(v) <= TRACOS


# --- o que é TINTA, e por que é uma função só ---------------------------------
# ESPAÇO COM COR DE FUNDO É PIXEL, e o gerador escreve exatamente isso: no
# `fastfetch_logo.sh`, célula opaca e uniforme cai em `melhor = 0`, o glifo é "
# " e a célula sai como `ESC[48;2;r;g;bm` + espaço.
#
# A tinta de fundo só valia na vertical: o `_tem_tinta` sabia que espaço pintado
# é pixel, e o `len(_visivel(d).rstrip())` que mede a largura tratava o mesmo
# espaço como enchimento.
_SGR = re.compile(r"\x1b\[([0-9;]*)m")


def _e_fundo(params):
    """A sequência SGR `params` liga cor de fundo? Anda pelos parâmetros.

    Devolve None quando a sequência não fala de fundo nenhum (para não desligar
    o que já estava ligado), True quando liga, False quando desliga."""
    campos = [c for c in params.split(";")]
    i, resposta = 0, None
    while i < len(campos):
        c = campos[i] or "0"
        try:
            n = int(c)
        except ValueError:
            i += 1
            continue
        if n in (38, 48, 58):
            # 2 = RGB (mais três), 5 = 256 cores (mais um). É por causa destes
            # argumentos de trás que a leitura por regex errava.
            seguinte = campos[i + 1] if i + 1 < len(campos) else ""
            salto = 5 if seguinte == "2" else (3 if seguinte == "5" else 1)
            if n == 48:
                resposta = True
            i += salto
            continue
        if n == 0 or n == 49:
            resposta = False
        elif 40 <= n <= 47 or 100 <= n <= 107:
            resposta = True
        i += 1
    return resposta


def _largura_pintada(linha):
    """A última coluna que a linha pinta, contando espaço com fundo ativo.

    Percorre acompanhando o estado do fundo: espaço com fundo conta como
    desenho, espaço sem fundo é enchimento e não conta."""
    fundo, coluna, ultima = False, 0, 0
    for pedaco in re.split(r"(\x1b\[[0-9;?]*[a-zA-Z])", linha):
        if not pedaco:
            continue
        m = _SGR.fullmatch(pedaco)
        if m is not None:
            r = _e_fundo(m.group(1))
            if r is not None:
                fundo = r
            continue
        if ESCAPE.fullmatch(pedaco):
            continue
        for ch in pedaco:
            coluna += 1
            if ch != " " or fundo:
                ultima = coluna
    return ultima


def _tem_tinta(linha):
    """A linha pinta alguma coisa na tela?

    Não basta perguntar por caractere visível: as duas últimas linhas que o
    fastfetch imprime são a paleta — espaços com cor de FUNDO. Elas são o
    rodapé do bloco e ocupam altura como qualquer outra, mas um `strip()` as
    considera vazias, e a centralização passava a alinhar um bloco duas linhas
    mais curto do que o que se vê.
    """
    return _largura_pintada(linha) > 0


def _extremos(linhas):
    """(primeira, última) linha que pinta alguma coisa. (0, -1) se não houver."""
    cheias = [i for i, l in enumerate(linhas) if _tem_tinta(l)]
    return (cheias[0], cheias[-1]) if cheias else (0, -1)


def _centralizar(gato, texto):
    """(quebras_antes_do_gato, quebras_antes_do_texto) para os dois blocos
    ficarem centrados um no outro.

    É o `--topo auto`, e ele existe porque ela mediu na tela em 06/09/2026: com
    o mascote em 32 linhas e o texto em 25, sobrava UMA linha de mascote acima da
    primeira informação e OITO abaixo da última — o desenho parecia escorregado
    para baixo.

    A CONTA É PELO CONTEÚDO VISÍVEL, E NÃO PELO NÚMERO DE LINHAS, e essa é a
    parte que a primeira versão errou. A saída do fastfetch termina com o
    `break` e os dois blocos de cor, e antes deles vem uma linha em branco:
    contando linhas cruas, texto e mascote deram 32 e 32, a sobra deu ZERO e nada
    se moveu — enquanto o olho via o bloco de informação acabar cinco linhas
    antes do mascote. Alinhar os CENTROS do que se vê resolve os dois casos de uma
    vez, e continua valendo quando ela acrescenta um módulo ou muda a altura do
    mascote.
    """
    gi, gf = _extremos(gato)
    ti, tf = _extremos(texto)
    if gf < gi or tf < ti:
        return 0, 0
    # A diferença entre os centros, em meias-linhas, para o arredondamento não
    # jogar tudo meio caractere para cima em toda composição.
    desvio = ((gi + gf) - (ti + tf)) // 2
    if desvio > 0:
        return 0, desvio            # o texto desce, o mascote começa no topo
    return -desvio, 0               # o mascote desce, o texto começa no topo


def colunas(desenho, texto, recuo, modo, passo):
    """A coluna em que CADA linha de texto começa.

    Os quatro modos são a mesma medida vista de quatro jeitos, e a diferença
    entre eles é só estética — por isso a escolha é dela, e por isso eles moram
    aqui juntos em vez de haver um só cravado no código:

      contorno   a coluna é o fim do desenho naquela linha. Cola no mascote, e é o
                 que ela pediu desenhando setas. Num desenho redondo e alto a
                 borda esquerda do texto vira uma escada de um em um caractere.
      degraus    o mesmo, arredondado para cima ao múltiplo de `passo`. Os
                 degraus passam a parecer decisão em vez de tremor.
      crescente  a coluna nunca DIMINUI: o texto acompanha o mascote enquanto ele
                 engorda e não volta quando ele afina. Tira a onda da metade de
                 baixo, que é onde o serrilhado mais aparece.
      reto       todas as linhas na mesma coluna — a maior que o desenho pede.
                 É o alinhamento do fastfetch, só que medido pelo trecho que o
                 texto de fato ocupa, e não pela largura total do logo.
    """
    base = []
    for i in range(len(texto)):
        d = desenho[i] if i < len(desenho) else ""
        largura = _largura_pintada(d)
        base.append((largura + recuo) if largura else recuo)

    if modo == "reto":
        maior = max((c for c, t in zip(base, texto) if _visivel(t).strip()),
                    default=recuo)
        cols = [maior] * len(base)
    elif modo == "crescente":
        cols, teto = [], recuo
        for c in base:
            teto = max(teto, c)
            cols.append(teto)
    elif modo == "degraus":
        p = max(passo, 1)
        cols = [((c + p - 1) // p) * p for c in base]
    else:
        cols = list(base)

    # O bloco de informação parecia começar no traço, com o nome órfão no canto
    # de cima.
    for i, linha in enumerate(texto):
        if i and _e_separador(linha) and _visivel(texto[i - 1]).strip():
            junto = max(cols[i - 1], cols[i])
            cols[i - 1] = cols[i] = junto

    # Ela são duas linhas de oito quadrados de cor, e o olho as lê como uma
    # grade: se começarem em colunas diferentes, a grade entorta.
    i = 0
    while i < len(texto):
        if _tem_tinta(texto[i]) and not _visivel(texto[i]).strip():
            j = i
            while j + 1 < len(texto) and _tem_tinta(texto[j + 1]) \
                    and not _visivel(texto[j + 1]).strip():
                j += 1
            if j > i:
                junto = max(cols[i:j + 1])
                for k in range(i, j + 1):
                    cols[k] = junto
            i = j + 1
        else:
            i += 1
    return cols


def compor(texto, gato, recuo, topo, modo="contorno", passo=4):
    """As duas colunas costuradas. `texto` e `gato` são listas de linhas."""
    if topo == "auto":
        antes_gato, antes_texto = _centralizar(gato, texto)
    else:
        antes_gato, antes_texto = max(int(topo), 0), 0
    desenho = [""] * antes_gato + gato
    texto = [""] * antes_texto + texto

    cols = colunas(desenho, texto, recuo, modo, passo)
    altura = max(len(desenho), len(texto))
    for i in range(altura):
        d = desenho[i] if i < len(desenho) else ""
        t = texto[i] if i < len(texto) else ""
        largura = _largura_pintada(d)
        alvo = cols[i] if i < len(cols) else recuo
        if largura:
            # O `ESC[0m` fecha a cor do último bloco do desenho. Sem ele o
            # branco da chave herdaria a cor do pixel em que o corte caiu.
            #
            # Ele estava em 1 contra um perigo que não se mede: `alvo` é sempre
            # `largura + recuo` e os três modos derivados só sobem, então `alvo
            # < largura` não acontece (varridos 4000 sorteios × 4 modos).
            enche = max(alvo - largura, 0) if t else 0
            yield _cortar(d, largura) + "\x1b[0m" + " " * enche + t
        elif t:
            yield " " * alvo + t
        else:
            yield ""


def main():
    p = argparse.ArgumentParser(add_help=True, description=__doc__)
    p.add_argument("--gato", default="~/.local/share/meowsystem/fastfetch/gato.ansi")
    # O cabeçalho promete que este filtro "NUNCA falha com pilha de erro na cara
    # dela", e o argparse quebrava a promessa: os valores vêm do meow.conf, que
    # é arquivo editado à mão, e um `type=int` sobre
    # `FASTFETCH_LOGO_RECUO="tres"` mata o processo ANTES de o stdin ser lido.
    p.add_argument("--recuo", default="3",
                   help="colunas entre o fim do desenho e o começo do texto")
    p.add_argument("--topo", default="auto",
                   help='linhas em branco antes do desenho; "auto" centra os '
                        "dois blocos um no outro")
    p.add_argument("--modo", default="contorno",
                   choices=("contorno", "degraus", "crescente", "reto"),
                   help="como a borda esquerda do texto acompanha o desenho")
    p.add_argument("--passo", default="4",
                   help="o tamanho do degrau, quando --modo degraus")
    p.add_argument("--conferir", action="store_true",
                   help="não compõe; sai 0 se dá para compor, 4 se não dá")
    args = p.parse_args()
    topo = "auto" if str(args.topo).strip().lower() in ("auto", "") \
        else _inteiro(args.topo, "auto", "--topo")
    recuo = _inteiro(args.recuo, 3, "--recuo")
    passo = _inteiro(args.passo, 4, "--passo")

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
    # Um terminal sem mascote é um contratempo; um terminal em branco com um
    # rastreamento é um defeito na cara dela.
    try:
        saida = "\n".join(compor(texto, gato, recuo, topo, args.modo, passo)) + "\n"
    except Exception as erro:
        print("meow-fetch: não consegui compor (%s) — saída sem gato"
              % type(erro).__name__, file=sys.stderr)
        sys.stdout.write(bruto)
        return 0
    sys.stdout.write(saida)
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

#!/usr/bin/env python3
"""afinar_conversor.py — o conversor escolhe os próprios botões, contra a faixa.

    ./scripts/afinar_conversor.py                 propõe, não escreve nada
    ./scripts/afinar_conversor.py --so org.gnome.Calculator
    ./scripts/afinar_conversor.py --fino          a grade inteira (mais lento)
    ./scripts/afinar_conversor.py --grade-teste   quatro jogos (o tests/ usa)
    ./scripts/afinar_conversor.py --escrever      grava o campo 4 do mapa
    ./scripts/afinar_conversor.py --json

    0 = nada a propor · 1 = há proposta diferente do que está no mapa
    2 = erro · 3 = falta dependência

O QUE ISTO SUBSTITUI
    Até 09/09/2026 os botões do conversor (`--k`, `--tol`, `--min-traco`,
    `--peso-fronteira`) eram escolhidos NO OLHO, um ícone por vez, olhando a
    lupa. Isso não escala, não se repete e não deixa prova: dois dias depois
    ninguém sabe por que aquele ícone tem `--k 8`.

    O acervo Arcticons que já está no repositório (39 glifos desenhados à mão
    por gente, no mesmo dialeto) dá a régua que faltava. Com ela, escolher botão
    deixa de ser gosto e vira busca: varre a grade, mede cada saída, e fica com
    a que cai mais dentro da faixa da mão. É o método da bancada de 09/09
    (`~/Documentos/meow-bancada-do-traco.html`) virado código.

A NOTA, E POR QUE ELA É ZERO DENTRO DA FAIXA
    Distância à faixa, não ao meio dela. Uma medida DENTRO de [mín, máx] custa
    zero — porque estar na cauda do que a mão faz não é defeito, é estar no
    dialeto. Só o que sai da faixa custa, e custa proporcional à largura dela,
    para que `pontos` (faixa de 6 a 67) e `margem` (de 1,72 a 11,68) pesem
    igual sem ninguém inventar peso.

    Consequência de desenho: a busca não empurra ninguém para a mediana do
    acervo. Ela para assim que entra. É o contrário de "otimizar até parecer
    Arcticons" — que produziria arte que copia, não arte que convive.

A TRANCA DE FIDELIDADE, E POR QUE ELA É OBRIGATÓRIA
    A nota mede A CANETA, e por isso pode ser enganada desenhando OUTRA COISA.
    Medido em 09/09/2026: na Calculadora a busca escolheu `--k 2`, que dá nota
    1,115 (a melhor da grade) e transforma os nove botões redondos num nó
    entrelaçado. Menos ponto, menos traço, nota boa, desenho destruído.

    Então todo candidato passa antes por uma tranca: rasterizado a 48 px sobre
    o mocha, ele tem de ficar a menos de `TETO_FORMA` pixels do que o PADRÃO
    desenha. É a mesma técnica e o MESMO número do `tests/conversor.sh` — 138 de
    2304, 6% da caixa — porque é a mesma pergunta: *só a linha mudou, ou a forma
    mudou junto?* Este afinador ajusta a caneta; trocar o desenho é outra coisa,
    e ela não pediu.

    O `-b '#1e1e2e'` NÃO É ENFEITE: em PNG com alfa o `compare -fuzz` acha zero
    diferença até entre ícones diferentes. Rasterizar sobre o mocha é o que faz
    a régua existir — está medido no cabeçalho daquele teste.

    Medido nas três da bancada, contra o padrão: as escolhas DELA ficam em 0, 4
    e 0; as propostas boas da busca em 4 e 28; o nó da Calculadora em 542. O
    teto de 138 aceita as boas e barra o nó, com folga dos dois lados.

O EMPATE VAI PARA A RECEITA MAIS CURTA
    Nota igual, ganha quem usa menos bandeira. Uma chave que não muda a nota é
    uma chave que alguém vai ler daqui a um mês e tentar entender. O padrão
    (`detalhe 6, suavidade 2`, sem `fracas` nem `mínimo`) é o piso do desempate,
    então um ícone só ganha campo 4 quando o campo 4 comprou alguma coisa.

O QUE ELE NÃO FAZ, E É O PONTO
    · Não converte para o tema. Não toca em `~/.local/share/icons`.
    · Não regera o acervo. Quem faz isso é o `construir_convertidos.sh`, e o
      `bin/meow` já diz por quê: *"reconverter trocaria arte que você aprovou
      por arte que ninguém viu"*.
    · Não sobrescreve receita que já está no mapa. Se a proposta diferir, ele
      MOSTRA as duas e devolve 1 — a que está escrita foi decisão de alguém, e
      uma busca automática não desfaz decisão em silêncio. `--refazer` é a
      chave explícita para isso.
    · Não olha linha `mao` nem ícone com retoque à mão: nesses o conversor não
      é quem desenha, e afinar botão dele seria afinar um botão que ninguém usa.
"""
import argparse
import itertools
import json
import os
import shutil
import subprocess
import sys
import tempfile
from multiprocessing import Pool

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(RAIZ, "scripts"))
try:
    from estilo_icone import faixa as derivar_faixa, medir
except ImportError:                                    # pragma: no cover
    print("falta scripts/estilo_icone.py", file=sys.stderr)
    sys.exit(3)

CONVERSOR = os.path.join(RAIZ, "scripts", "converter_icone.py")
ACERVO = os.path.join(RAIZ, "assets", "icones", "arcticons-apps")
MAPA = os.path.join(RAIZ, "assets", "icones", "apps-convertidos.map")
RETOQUES = os.path.join(RAIZ, "assets", "icones", "convertidos-apps", "retoques")

# AS MEDIDAS QUE ENTRAM NA NOTA, e `seg_min` fica DE FORA por medida: o acervo
# tem o idioma do pingo (`v 0.1` para um ponto), então o mínimo dele vai a zero
# e a faixa cobre tudo — uma medida que nunca reprova não separa candidato.
NOTADAS = ("pontos", "tracos", "seg_mediano", "margem", "curva_pct")

# O teto da tranca de fidelidade, em pixels de uma caixa de 48x48 (2304 px).
# Mesmo número do `tests/conversor.sh`, e pelo mesmo motivo. Ver o cabeçalho.
TETO_FORMA = 138
MOCHA = "#1e1e2e"

# As réguas são as DELA, 0…10, e a conta abaixo é copiada de `_parametros_de`
# do `app/servidor.py`. Se as duas divergirem, o número que ela achar na oficina
# deixa de valer aqui — e era esse casamento que fazia a bancada transferir.
GRADE_RAPIDA = {"detalhe": [0, 2, 4, 6, 8, 10], "suavidade": [0, 2, 4, 6, 8, 10],
                "fracas": [0, 5, 10], "minimo": [0, 4, 8]}
GRADE_FINA = {"detalhe": list(range(11)), "suavidade": list(range(11)),
              "fracas": [0, 3, 5, 7, 10], "minimo": [0, 2, 4, 6, 8, 10]}
# A grade do `tests/afinador.sh`: quatro jogos, e o que importa é que `detalhe 0`
# ESTÁ nela — é o `--k 2` que destruía a Calculadora. Uma grade de teste que não
# contivesse o candidato ruim não provaria que a tranca morde.
GRADE_TESTE = {"detalhe": [0, 6], "suavidade": [2], "fracas": [0], "minimo": [0]}
PADRAO = {"detalhe": 6, "suavidade": 2, "fracas": 0, "minimo": 0}


def argv_de(r):
    """As bandeiras de uma posição de régua. Zero é AUSÊNCIA, nunca `--x 0`."""
    a = ["--k", str(2 + r["detalhe"]), "--funde", str(100 - 8 * r["detalhe"]),
         "--tol", "%g" % round(0.4 + 0.3 * r["suavidade"], 1)]
    if r["fracas"]:
        a += ["--peso-fronteira", str(40 + 3 * r["fracas"])]
    if r["minimo"]:
        a += ["--min-traco", "%g" % round(3.2 + 0.8 * r["minimo"], 1)]
    return a


def nota_de(m, f):
    """Distância à faixa. Zero dentro; fora, em larguras de faixa."""
    if not m:
        return float("inf")
    total = 0.0
    for k in NOTADAS:
        lo, hi = f[k]["min"], f[k]["max"]
        largura = max(hi - lo, 1e-9)
        v = m[k]
        if v < lo:
            total += (lo - v) / largura
        elif v > hi:
            total += (v - hi) / largura
    return total


def _alvos():
    """As linhas do mapa que o conversor realmente desenha.

    `mao` e retoque saem: ali quem desenha é a mão, e o botão do conversor nem
    é chamado. Origem que sumiu da máquina também sai — não é erro, é que
    aquele aplicativo não está instalado aqui.
    """
    fora = []
    with open(MAPA, encoding="utf-8") as fh:
        for linha in fh:
            crua = linha.rstrip("\n")
            if not crua.strip() or crua.lstrip().startswith("#"):
                continue
            p = crua.split(":")
            if len(p) < 3:
                continue
            nome, origem = p[0], p[1]
            if origem == "mao" or os.path.exists(os.path.join(RETOQUES, nome + ".svg")):
                continue
            if not origem.startswith("/"):
                origem = os.path.join(RAIZ, origem)
            if not os.path.exists(origem):
                continue
            fora.append({"nome": nome, "origem": origem,
                         "escrito": ":".join(p[3:]).strip() if len(p) > 3 else ""})
    return fora


def _raster(svg, png):
    return subprocess.run(["rsvg-convert", "-w", "48", "-h", "48", "-b", MOCHA,
                           svg, "-o", png], capture_output=True).returncode == 0


def _distancia(a, b):
    """Pixels diferentes entre dois PNG de 48x48. -1 quando não deu para medir."""
    r = subprocess.run(["compare", "-metric", "AE", "-fuzz", "8%", a, b, "null:"],
                       capture_output=True, text=True)
    bruto = (r.stderr or r.stdout or "").strip().split()
    try:
        return int(float(bruto[0]))
    except (IndexError, ValueError):
        return -1


def _um(tarefa):
    alvo, grade, f = tarefa
    combos = [dict(zip(grade, v)) for v in itertools.product(*grade.values())]
    melhor = None
    barrados = 0
    with tempfile.TemporaryDirectory() as td:
        saida = os.path.join(td, "x.svg")
        cand = os.path.join(td, "x.png")
        ancora = os.path.join(td, "p.png")
        # A ÂNCORA É O PADRÃO, não a origem chapada: quem afina caneta compara
        # caneta com caneta. E é o padrão, não o que está escrito no mapa, para
        # que a régua seja a mesma para todo ícone e não dependa de quem já
        # ganhou um campo 4.
        base = os.path.join(td, "p.svg")
        if subprocess.run([sys.executable, CONVERSOR, alvo["origem"], base]
                          + argv_de(PADRAO), capture_output=True).returncode != 0 \
           or not _raster(base, ancora):
            return {"nome": alvo["nome"], "erro": "o padrão não converteu — sem âncora"}
        # PRIMEIRO A NOTA, DEPOIS A TRANCA — e a ordem é desempenho, não
        # semântica. Medir a caneta custa um `converter`; medir a forma custa
        # mais um `rsvg-convert` e um `compare`. Como a tranca só precisa
        # responder sobre QUEM IA GANHAR, ordenar por nota e descer a lista até
        # o primeiro que passa dá exatamente o mesmo vencedor por um terço do
        # trabalho. Rodar a tranca em toda a grade seria pagar 4.860 vezes por
        # uma resposta que se usa 15.
        fila = []
        for r in combos:
            a = argv_de(r)
            if subprocess.run([sys.executable, CONVERSOR, alvo["origem"], saida] + a,
                              capture_output=True).returncode != 0:
                continue
            n = nota_de(medir(saida), f)
            if n == float("inf"):
                continue
            # O EMPATE VAI PARA A RECEITA MAIS CURTA — e, empatando de novo, para
            # a que está mais perto do padrão. Sem isto a busca devolveria uma
            # bandeira diferente a cada rodada entre candidatos idênticos, e o
            # `git diff` do mapa viraria ruído.
            fila.append(((round(n, 6), len(a),
                          sum(abs(r[k] - PADRAO[k]) for k in PADRAO)),
                         dict(r), " ".join(a), n))
        fila.sort(key=lambda x: x[0])
        for peso, r, receita, n in fila:
            if subprocess.run([sys.executable, CONVERSOR, alvo["origem"], saida]
                              + receita.split(), capture_output=True).returncode != 0:
                continue
            if not _raster(saida, cand):
                continue
            d = _distancia(ancora, cand)
            if d < 0 or d > TETO_FORMA:
                barrados += 1
                continue
            melhor = (peso, r, receita, n, d)
            break
    if melhor is None:
        return {"nome": alvo["nome"],
                "erro": "a tranca de forma barrou os %d melhores da grade"
                        % barrados}
    _, reguas, receita, n, d = melhor
    padrao_argv = " ".join(argv_de(PADRAO))
    return {"nome": alvo["nome"], "reguas": reguas, "receita": receita,
            "nota": round(n, 3), "forma": d, "barrados": barrados,
            "escrito": alvo["escrito"], "e_padrao": receita == padrao_argv,
            "jogos": len(combos)}


def main():
    p = argparse.ArgumentParser(
        description="Escolhe os botões do conversor contra a faixa do acervo à mão.")
    p.add_argument("--so", action="append", default=[],
                   help="afina só este ícone (pode repetir)")
    p.add_argument("--fino", action="store_true", help="a grade inteira, 0..10")
    p.add_argument("--grade-teste", action="store_true",
                   help="quatro jogos, para o tests/afinador.sh")
    p.add_argument("--escrever", action="store_true",
                   help="grava a proposta no campo 4 de apps-convertidos.map")
    p.add_argument("--refazer", action="store_true",
                   help="com --escrever, também troca receita que já está escrita")
    p.add_argument("--json", action="store_true")
    p.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 4) - 2))
    a = p.parse_args()

    for f in (CONVERSOR, MAPA):
        if not os.path.exists(f):
            print("falta %s" % os.path.relpath(f, RAIZ), file=sys.stderr)
            return 3
    try:
        import numpy  # noqa: F401
    except ImportError:
        print("falta numpy — é ele que traça o contorno", file=sys.stderr)
        return 3
    for exe in ("rsvg-convert", "compare"):
        if not shutil.which(exe):
            print("falta %s — sem ele a tranca de forma não existe, e sem a "
                  "tranca a busca escolhe o desenho errado" % exe, file=sys.stderr)
            return 3
    f = derivar_faixa(ACERVO)
    if not f or f["n"] < 20:
        print("o acervo Arcticons não está aqui, ou é pequeno demais para "
              "servir de faixa", file=sys.stderr)
        return 3

    alvos = _alvos()
    if a.so:
        alvos = [x for x in alvos if x["nome"] in a.so]
    if not alvos:
        print("nenhuma origem alcançável nesta máquina", file=sys.stderr)
        return 3

    grade = GRADE_TESTE if a.grade_teste else (GRADE_FINA if a.fino else GRADE_RAPIDA)
    jogos = 1
    for v in grade.values():
        jogos *= len(v)
    if not a.json:
        print("faixa de %d glifos à mão · %d ícones × %d jogos = %d conversões"
              % (f["n"], len(alvos), jogos, len(alvos) * jogos), file=sys.stderr)

    with Pool(a.jobs) as pool:
        linhas = pool.map(_um, [(x, grade, f) for x in alvos])

    divergem = [x for x in linhas
                if not x.get("erro") and x["receita"] != (x["escrito"] or
                                                          " ".join(argv_de(PADRAO)))]
    if a.json:
        json.dump({"faixa_de": f["n"], "linhas": linhas}, sys.stdout,
                  ensure_ascii=False)
        print()
    else:
        print("%-38s %6s %6s  %s" % ("ícone", "nota", "forma", "receita proposta"))
        for x in sorted(linhas, key=lambda y: y.get("nota", 9e9), reverse=True):
            if x.get("erro"):
                print("%-38s %6s %6s  %s" % (x["nome"], "—", "—", x["erro"]))
                continue
            marca = " " if x["receita"] == (x["escrito"] or " ".join(argv_de(PADRAO))) else "*"
            print("%-38s %6.3f %6d %s %s"
                  % (x["nome"], x["nota"], x["forma"], marca,
                     "(o padrão)" if x["e_padrao"] else x["receita"]))
            if x["escrito"] and x["escrito"] != x["receita"]:
                print("%-38s %6s %6s   escrito no mapa: %s" % ("", "", "", x["escrito"]))
        print("\n%d de %d mudariam. '*' marca quem difere do que está no mapa."
              % (len(divergem), len(linhas)))

    if not a.escrever:
        if divergem and not a.json:
            print("nada foi escrito. Para gravar: --escrever", file=sys.stderr)
        return 1 if divergem else 0

    # ---------------------------------------------------------------- escrever
    with open(MAPA, encoding="utf-8") as fh:
        texto = fh.read()
    saiu = texto.split("\n")
    prop = {x["nome"]: x for x in linhas if not x.get("erro")}
    mexeu = 0
    for i, linha in enumerate(saiu):
        if not linha.strip() or linha.lstrip().startswith("#"):
            continue
        p4 = linha.split(":")
        x = prop.get(p4[0])
        if not x:
            continue
        escrito = ":".join(p4[3:]).strip() if len(p4) > 3 else ""
        if escrito and not a.refazer:
            continue                       # decisão de alguém: não se desfaz calado
        alvo = "" if x["e_padrao"] else x["receita"]
        if escrito == alvo:
            continue
        base = ":".join(p4[:3])
        saiu[i] = base + (":" + alvo if alvo else "")
        mexeu += 1
    if mexeu:
        with open(MAPA, "w", encoding="utf-8") as fh:
            fh.write("\n".join(saiu))
    print("%d linha(s) do mapa mudaram." % mexeu, file=sys.stderr)
    if mexeu:
        print("A ARTE NÃO MUDOU AINDA — o mapa é a receita, não o desenho.\n"
              "Para regerar o acervo:  ./scripts/construir_convertidos.sh",
              file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())

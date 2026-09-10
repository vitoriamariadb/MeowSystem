#!/usr/bin/env python3
"""estilo_icone.py — mede a CANETA de um SVG do acervo, não o desenho.

    ./scripts/estilo_icone.py arquivo.svg [...]        uma linha por arquivo
    ./scripts/estilo_icone.py --faixa assets/icones/arcticons-apps
    ./scripts/estilo_icone.py --json arquivo.svg

    0 = mediu · 2 = erro · 3 = falta dependência

POR QUE ISTO EXISTE, E QUAL PERGUNTA ELE RESPONDE
    Até 09/09/2026 a única régua da arte gerada era o olho — o meu, olhando a
    lupa da oficina, um ícone por vez. Isso deixa passar o defeito que não tem
    forma: a linha que treme porque foi desenhada com segmento de 0,19 px, o
    ícone que ocupa 41,7 de 48 e aparece maior que o vizinho na dock.

    O acervo Arcticons que já está no repositório (39 glifos, desenhados à mão
    por gente, no MESMO dialeto) é o gabarito que faltava: dá para medir o que
    a caneta deles faz e comparar com o que a nossa faz. Não é questão de
    gosto — é distribuição, e distribuição se mede.

O QUE ELE NÃO MEDE, E É DE PROPÓSITO
    Não mede se o desenho está certo. O compressor do Arcticons são duas setas
    apertando linhas; o nosso é o zíper que estava no Papirus. Os dois passam
    em qualquer métrica daqui, e o deles é melhor — porque decidiu o que a
    coisa SIGNIFICA, e isso um conversor não faz. Esta régua pega o tremido, o
    denso e o desenquadrado, que é o que ela consegue pegar.

AS MEDIDAS, E POR QUE CADA UMA
    · `tracos`        <path> de topo. É quanta linha solta o desenho tem.
    · `pontos`        vértices somados. Medido em 09/09: Arcticons 19, nosso 66.
    · `seg_min`       o MENOR segmento. Abaixo de ~1 px de 48 o olho não separa
                      dois vértices: o que sobra é tremido, e custa bytes.
    · `seg_mediano`   o passo típico da caneta. Metade do deles = o dobro do
                      detalhe que a grade de 48 aguenta.
    · `larg`/`alt`    a caixa que o desenho ocupa dentro dos 48.
    · `margem`        a menor folga até a borda. Arcticons: 4,5. Nosso: 3,16 —
                      e é por isso que o nosso aparece ~15% maior ao lado dele.
    · `curva_pct`     fração de comandos de curva. A Sprint Q comprou isto: era
                      18,2% no acervo antigo, é 64,1% na saída de hoje.

    Tudo é reduzido à grade de 48 pelo `viewBox`, então um SVG de 24 ou de 512
    entra na mesma régua sem ninguém converter nada à mão.
"""
import json
import math
import os
import re
import statistics
import sys

CMD = re.compile(r"([MmLlHhVvCcSsQqTtAaZz])([^MmLlHhVvCcSsQqTtAaZz]*)")
NUM = re.compile(r"-?\d*\.?\d+(?:[eE][-+]?\d+)?")
MEDIDAS = ("tracos", "pontos", "seg_min", "seg_mediano",
           "larg", "alt", "margem", "curva_pct")


def _percursos(texto):
    return re.findall(r'<path[^>]*\sd="([^"]*)"', texto)


def _vertices(d):
    """Vértices na ordem em que a caneta passa, mais a conta de curva e reta.

    O `Z` VOLTA PARA O `M`, e isso não é detalhe: sem devolver o ponto inicial,
    todo laço fechado ganha um segmento fantasma da última posição até o
    próximo `M`, e o `seg_min` de um ícone de dois laços vira lixo.
    """
    verts, curvas, retas, casas = [], 0, 0, []
    x = y = sx = sy = 0.0
    for cmd, resto in CMD.findall(d):
        cruas = NUM.findall(resto)
        n = [float(v) for v in cruas]
        casas += [len(v.split(".")[1]) if "." in v else 0 for v in cruas]
        rel, c = cmd.islower(), cmd.upper()
        if c == "M":
            for i in range(0, len(n) - 1, 2):
                x, y = (x + n[i], y + n[i + 1]) if rel else (n[i], n[i + 1])
                # `M` com vários pares: do segundo em diante é reta implícita —
                # é assim que o nosso conversor escreve polilinha, e ignorar
                # isso zeraria a conta de reta do acervo inteiro.
                if i == 0:
                    sx, sy = x, y
                else:
                    retas += 1
                verts.append((x, y))
        elif c == "L":
            for i in range(0, len(n) - 1, 2):
                x, y = (x + n[i], y + n[i + 1]) if rel else (n[i], n[i + 1])
                retas += 1
                verts.append((x, y))
        elif c in "HV":
            for v in n:
                if c == "H":
                    x = x + v if rel else v
                else:
                    y = y + v if rel else v
                retas += 1
                verts.append((x, y))
        elif c in "CSQT":
            passo = {"C": 6, "S": 4, "Q": 4, "T": 2}[c]
            for i in range(0, len(n) - passo + 1, passo):
                bx, by = n[i + passo - 2], n[i + passo - 1]
                x, y = (x + bx, y + by) if rel else (bx, by)
                curvas += 1
                verts.append((x, y))
        elif c == "A":
            for i in range(0, len(n) - 6, 7):
                bx, by = n[i + 5], n[i + 6]
                x, y = (x + bx, y + by) if rel else (bx, by)
                curvas += 1
                verts.append((x, y))
        elif c == "Z":
            # SÓ acrescenta o fechamento se a caneta ainda NÃO estiver no
            # ponto inicial. Um `Z` depois do vértice que já coincide com o
            # `M` cria um segmento de comprimento ~0 e derruba o `seg_min` do
            # acervo inteiro para perto de zero — medido em 09/09/2026: o p25
            # do Arcticons caiu de 1,12 para 0,35 por causa disso.
            if math.dist((x, y), (sx, sy)) > 1e-9:
                verts.append((sx, sy))
            x, y = sx, sy
    return verts, curvas, retas, casas


def _escala(texto):
    """48 dividido pela largura do viewBox — tudo é medido na grade da dock."""
    m = re.search(r'viewBox="([^"]+)"', texto)
    if not m:
        return 1.0
    p = [float(v) for v in NUM.findall(m.group(1))]
    return 48.0 / p[2] if len(p) >= 3 and p[2] else 1.0


def medir(caminho):
    """Devolve o dicionário de medidas, ou None se não houver `<path d=`."""
    try:
        texto = open(caminho, encoding="utf-8", errors="replace").read()
    except OSError:
        return None
    esc = _escala(texto)
    ds = _percursos(texto)
    if not ds:
        return None
    curvas = retas = 0
    casas, verts, segs = [], [], []
    for d in ds:
        v, c, r, k = _vertices(d)
        curvas += c
        retas += r
        casas += k
        v = [(a * esc, b * esc) for a, b in v]
        verts += v
        segs += [math.dist(v[i], v[i + 1]) for i in range(len(v) - 1)]
    if not verts:
        return None
    segs = [s for s in segs if s > 1e-9]
    xs = [a for a, _ in verts]
    ys = [b for _, b in verts]
    return {
        "arquivo": caminho,
        "tracos": len(ds),
        "pontos": len(verts),
        "curva_pct": round(100.0 * curvas / max(1, curvas + retas), 1),
        "casas": round(statistics.mean(casas), 2) if casas else 0.0,
        "seg_min": round(min(segs), 2) if segs else 0.0,
        "seg_mediano": round(statistics.median(segs), 2) if segs else 0.0,
        "larg": round(max(xs) - min(xs), 2),
        "alt": round(max(ys) - min(ys), 2),
        "margem": round(min(min(xs), min(ys), 48 - max(xs), 48 - max(ys)), 2),
    }


def _pct(valores, p):
    v = sorted(valores)
    if not v:
        return 0.0
    k = (len(v) - 1) * p / 100.0
    i = int(k)
    f = k - i
    return v[i] if i + 1 >= len(v) else v[i] * (1 - f) + v[i + 1] * f


def faixa(raiz):
    """A faixa DERIVADA de um acervo — nunca uma lista de números cravados.

    Armadilha nº 3 do projeto: toda lista fixa é uma lista que alguém vai
    esquecer. Se um glifo entrar ou sair de `arcticons-apps/`, a faixa anda
    sozinha, e o teste continua medindo o acervo que existe.
    """
    arqs = sorted(os.path.join(b, f)
                  for b, _, fs in os.walk(raiz) for f in fs if f.endswith(".svg"))
    linhas = [m for m in (medir(a) for a in arqs) if m]
    if not linhas:
        return None
    fora = {"n": len(linhas), "raiz": raiz}
    for k in MEDIDAS:
        v = [x[k] for x in linhas]
        fora[k] = {p: round(_pct(v, int(p[1:])), 2)
                   for p in ("p05", "p25", "p50", "p75", "p95")}
        # O `min`/`max` NÃO é enfeite do percentil: é a asserção que o teste
        # usa. Percentil responde "onde a mão costuma ficar"; min/max responde
        # "até onde a mão JÁ foi" — e sair disso é sair do dialeto, não ficar
        # na cauda dele. Medido em 09/09/2026, três conversões (Foliate,
        # ProtonUp, Apostrophe) têm margem 2,42: abaixo do p05 (2,50) e acima
        # do mínimo real do acervo (o firefox, 1,72). Uma régua no p05 estaria
        # vermelha por 8 centésimos, sem nada errado ter acontecido.
        fora[k]["min"] = round(min(v), 2)
        fora[k]["max"] = round(max(v), 2)
    return fora


def _tabela(linhas):
    print("%-40s %6s %6s %7s %7s %6s %6s %7s"
          % ("arquivo", "traços", "pontos", "seg_mín", "seg_med",
             "larg", "marg", "curva"))
    for m in linhas:
        print("%-40s %6d %6d %7.2f %7.2f %6.1f %6.2f %6.1f%%"
              % (os.path.basename(m["arquivo"])[:40], m["tracos"], m["pontos"],
                 m["seg_min"], m["seg_mediano"], m["larg"], m["margem"],
                 m["curva_pct"]))


def main(argv):
    quer_json = "--json" in argv
    argv = [a for a in argv if a != "--json"]
    if argv and argv[0] == "--faixa":
        if len(argv) < 2:
            print("uso: --faixa <diretório>", file=sys.stderr)
            return 2
        f = faixa(argv[1])
        if not f:
            print("nenhum SVG com <path d= em %s" % argv[1], file=sys.stderr)
            return 2
        if quer_json:
            json.dump(f, sys.stdout, ensure_ascii=False)
            print()
            return 0
        print("faixa de %d glifos em %s" % (f["n"], f["raiz"]))
        print("   %-12s %7s %7s %7s %7s %7s %7s %7s"
              % ("", "mín", "p05", "p25", "p50", "p75", "p95", "máx"))
        for k in MEDIDAS:
            print("   %-12s %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f"
                  % (k, f[k]["min"], f[k]["p05"], f[k]["p25"], f[k]["p50"],
                     f[k]["p75"], f[k]["p95"], f[k]["max"]))
        return 0
    alvos = []
    for a in argv:
        if os.path.isdir(a):
            alvos += sorted(os.path.join(b, f)
                            for b, _, fs in os.walk(a) for f in fs
                            if f.endswith(".svg"))
        else:
            alvos.append(a)
    if not alvos:
        print(__doc__.strip().split("\n\n")[1], file=sys.stderr)
        return 2
    linhas = [m for m in (medir(a) for a in alvos) if m]
    if quer_json:
        json.dump(linhas, sys.stdout, ensure_ascii=False)
        print()
    else:
        _tabela(linhas)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

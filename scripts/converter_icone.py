#!/usr/bin/env python3
"""converter_icone.py — transforma ícone CHAPADO (SVG ou PNG) em ARTE DE LINHA
no dialeto do Arcticons: viewBox 48, fill:none, stroke uniforme, sem preenchimento.

PARA QUE SERVE
    Responder com medida — não com opinião — à pergunta: "dá para converter o
    acervo que já temos em vez de desenhar 39 ícones à mão?". A resposta dela,
    olhando a folha em 11/08/2026, foi *"tão todos muito bons"*: o caminho é o
    conversor.

QUEM CHAMA ISTO
    `scripts/construir_convertidos.sh`, e SÓ ele — nunca o `install.sh`. A
    conversão não é etapa de instalação, é a ferramenta que GERA o acervo
    `assets/icones/convertidos-apps/`, que fica COMMITADO no repositório como o
    `assets/icones/arcticons-apps/`. Arte que ela aprovou numa folha tem de aparecer no
    `git diff`; arte gerada em tempo de instalação mudaria em silêncio no dia
    em que o Papirus fosse atualizado. Ver o cabeçalho daquele script.

    Este arquivo não faz NADA ao ser importado: tudo mora em funções e o
    `main()` só roda por `__main__`. Dá para `from converter_icone import
    converter` num experimento sem rasterizar coisa nenhuma.

O QUE ESTA MÁQUINA **NÃO** TEM (medido em 11/08/2026)
    potrace · inkscape · autotrace · PIL · cairosvg · scipy · skimage · cv2 ·
    shapely · picosvg · svgpathtools · lxml

    Ou seja: **não existe booleano vetorial nesta máquina**. Isso decide a
    arquitetura inteira, e é o achado técnico mais importante do estudo:

        A "Via 2" (unir os paths numa silhueta e traçar o perímetro) e a
        "Via 3" (rasterizar um PNG e vetorizar) COLAPSAM NO MESMO CÓDIGO
        assim que não há união booleana de paths. As duas viram: rasterize,
        ache regiões, trace fronteiras. A única diferença passa a ser a
        QUALIDADE DA MÁSCARA de entrada, não o algoritmo.

    O que existe e basta: `rsvg-convert` (SVG→PNG), `convert` (PNG→RGBA cru) e
    `numpy`. O traçador de contorno (marching squares) e o simplificador
    (Douglas–Peucker) estão escritos aqui, à mão, por isso.

POR QUE NÃO É SÓ A SILHUETA
    A silhueta sozinha do Terminal é um quadrado arredondado; a do Editor é um
    retângulo. Silhueta pura APAGA a identidade, que é justamente o achado da
    Sprint I. Então o traçado não é do contorno externo: é da **fronteira entre
    regiões de cor**. O `>_` do terminal e as ondas do Spotify são fronteiras
    internas, e é isso que sobrevive.

O PIPELINE, EM SETE PASSOS
    1. rasteriza a 256px com alfa (rsvg-convert p/ SVG, convert p/ PNG)
    2. quantiza em K cores — histograma se a arte é chapada, k-means se tem
       gradiente; funde cores vizinhas e DESCARTA cor de mistura (antialias).
       Alfa baixo vira a classe FUNDO.
    3. filtro de moda 2D (janela w) — mata cisco e alisa serrilhado; é o
       substituto vetorizado da abertura morfológica que o scipy faria
    4. COLAPSA CONTORNO: componente fino que embrulha outro some, e as duas
       vizinhas se encontram no eixo médio dele. É o que impede a linha dupla
       quando o original JÁ TEM contorno — o caso dos `assets/icones/autorais/`.
    5. traça a fronteira de cada classe com marching squares, com DEDUPE
       global de aresta: fronteira entre A e B é desenhada UMA vez, não duas
       (duas cópias simplificadas divergem e engrossam o traço)
    6. descarta polilinha curta demais (a medida é a do Douglas–Peucker)
    7. acha os CANTOS na cadeia crua, parte nela, alisa cada peça, guarda as
       retas como retas e ajusta Bézier no que sobrou — a seção «curvas»
    8. emite SVG viewBox 48, `fill:none stroke:currentColor stroke-width:1
       stroke-linecap:round stroke-linejoin:round`

    O passo 7 é de 09/09/2026 (Sprint Q) e é o único que mudou desde 11/08. Até
    ali a saída era só polilinha (`M x y x y …`), e a escada da grade de 256
    chegava inteira na tela — foi o que ela chamou de "pixelado" olhando a lupa
    da oficina. `--polilinha` devolve o comportamento antigo BYTE A BYTE, e é
    por isso que ele continua existindo: `retoques/org.gimp.GIMP.svg` é uma
    conversão retocada à mão, e a prova de qual parte é a mão depende disso.

A GRAMÁTICA DE SAÍDA NÃO FOI INVENTADA: FOI MEDIDA NOS 39 ARCTICONS
    viewBox `0 0 48 48` nos 39 · `stroke-width` AUSENTE nos 39 (o padrão SVG
    é 1, e a 48px de tela isso dá exatamente 1px) · `stroke-linecap="round"`
    e `stroke-linejoin="round"` nos 39 · `fill="none"` em 94 lugares contra
    13 `fill="currentColor"`, e esses 13 estão em apenas DOIS arquivos
    (`keymapper`, `osmonitor`) — ou seja, preenchimento é a exceção rara.
    Mediana de 4 subcaminhos por ícone (mínimo 1, máximo 16).
    Sair nesse dialeto é o que faz o `scripts/icones_apps_arcticons.sh`
    conseguir recolorir a saída sem uma linha nova.

O QUE FUNCIONA E O QUE NÃO (medido, 29 apps do lançador dela + 10 autorais)
    16/29 do Papirus saem prontos · 10/29 pedem retoque · 3/29 não têm
    conserto (Firefox, Krita, Thunderbird). Dos 10 autorais, 8 saem prontos.
    O que decide NÃO é PNG contra SVG — o Spotify convertido do PNG 512×512
    sai igual ao que veio do SVG. O que decide é o desenho original ser
    geométrico (sai) ou orgânico com formas sobrepostas (não sai): nesse
    caso a informação está no PREENCHIMENTO, não na fronteira, e tirar o
    preenchimento tira o desenho. Nenhum parâmetro conserta isso.

O QUE SOBROU DE FORA, E POR QUÊ (a leitura dela da folha, 11/08/2026)
    Dos 29 alvos medidos, CINCO não entram no acervo convertido — e nenhum
    deles fica sem ícone, porque todos já têm glifo Arcticons desenhado à mão:
      · firefox · org.kde.krita · thunderbird — raposa, camaleão e passarinho
        são ORGÂNICOS: a informação está no preenchimento, e tirá-lo tira o
        desenho. Nenhum parâmetro conserta.
      · com.boxy_svg.BoxySVG — a flor do meio vira uma bolha a 48px.
      · btop — a conversão é fiel, e o original é justamente o "B" na placa
        opaca de que ela reclamou em 08/08. Aqui o Arcticons já tinha vencido.
    E três NÃO passam por aqui apesar de estarem no mapa: Flatseal, Warehouse
    e Gradia têm desenho à mão em `assets/icones/convertidos-apps/retoques/`, que vence
    a conversão sempre — ver `construir_convertidos.sh`.

A GRAMÁTICA DE SAÍDA GANHOU `C`, `L` E `Z`, E OS DOIS LEITORES CONTINUAM LENDO
    Foi conferido antes de emitir, porque quebrar qualquer um dos dois só
    apareceria na tela dela:
      · `_vestido()` do `scripts/icones_apps_arcticons.sh` injeta a espessura
        procurando `<path ` COM ESPAÇO — a saída tem o espaço nas duas formas
        (`<path d=` e `<path fill="currentColor" d=`), e a injeção pega 3 de 3
        e 9 de 9 nos casos medidos;
      · `_conferir_dialeto()` do `app/servidor.py` exige viewBox 48,
        `fill="none"`, `stroke="currentColor"` e RECUSA `stroke-width` e cor —
        nada disso mudou, porque os comandos de path não são olhados por
        nenhuma das duas.

USO
    converter_icone.py ENTRADA.svg|png SAIDA.svg [--curvas|--polilinha]
                       [--cheia] [--json] [--cantos 60] [--k 6] [--tol N]
"""
from __future__ import annotations

import argparse
import json
import math
import os
import subprocess
import sys
import tempfile

import numpy as np

# ---------------------------------------------------------------- rasterizar

RES = 256          # resolução de trabalho. 5,3× o alvo de 48px — sobra de
                   # amostragem sem pagar o custo quadrático de 512.
ESCALA = 48.0 / RES


def rasterizar(caminho: str, res: int = RES) -> np.ndarray:
    """Devolve RGBA uint8 (res, res, 4). SVG passa pelo rsvg, PNG pelo convert."""
    ext = os.path.splitext(caminho)[1].lower()
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        png = tmp.name
    try:
        if ext == ".svg":
            subprocess.run(
                ["rsvg-convert", "-w", str(res), "-h", str(res), caminho, "-o", png],
                check=True, capture_output=True)
        else:
            # -background none preserva o alfa; o filtro Lanczos preserva a
            # borda dura do ícone chapado melhor que o default.
            subprocess.run(
                ["convert", caminho, "-background", "none", "-filter", "Lanczos",
                 "-resize", f"{res}x{res}!", png],
                check=True, capture_output=True)
        cru = subprocess.run(["convert", png, "-depth", "8", "RGBA:-"],
                             check=True, capture_output=True).stdout
        return np.frombuffer(cru, np.uint8).reshape(res, res, 4).copy()
    finally:
        os.unlink(png)


# ---------------------------------------------------------------- quantizar

def _luma(rgb: np.ndarray) -> np.ndarray:
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def _funde(centros: np.ndarray, dist: float) -> np.ndarray:
    """Funde centros a menos de `dist` em RGB (união-busca; k é minúsculo)."""
    pai = list(range(len(centros)))

    def raiz(i):
        while pai[i] != i:
            pai[i] = pai[pai[i]]
            i = pai[i]
        return i

    for i in range(len(centros)):
        for j in range(i + 1, len(centros)):
            if np.linalg.norm(centros[i] - centros[j]) < dist:
                pai[raiz(i)] = raiz(j)
    grupos = {}
    for i in range(len(centros)):
        grupos.setdefault(raiz(i), []).append(i)
    return np.stack([centros[g].mean(0) for g in grupos.values()]).astype(np.float32)


def quantizar(rgba: np.ndarray, k: int, funde: float) -> tuple[np.ndarray, np.ndarray]:
    """RGBA -> (rotulos int16, cores nx3). Rótulo 0 é sempre o FUNDO.

    DUAS ESTRATÉGIAS, ESCOLHIDAS PELO PRÓPRIO ARQUIVO — e isso não é firula.

    (a) ARTE CHAPADA (autorais, Papirus, a maioria dos PNG Catppuccin): o
        histograma de cor EXATA é curto — meia dúzia de cores cobrem quase
        tudo, e o resto é só antialias de borda. Aqui o k-means é ATIVAMENTE
        PIOR: ele aloca centros por VOLUME de pixel, então uma feição pequena
        (as três linhas de texto amarelas do `cosmic-edit`, 4% da área) fica
        sem centro e SOME. Medido: com k-means as linhas do editor
        desapareciam; com histograma, aparecem. Cor rara mas chapada é
        exatamente o que carrega identidade num ícone.

    (b) ARTE COM GRADIENTE (Chrome, Discord, boa parte do Papirus moderno): o
        histograma se espalha em milhares de tons e nenhum "cobre" nada. Aí
        cai no k-means, que é o certo para tom contínuo.

    O corte é medido, não votado: se as `k` cores mais frequentes cobrem ≥60%
    dos pixels opacos, é chapada.
    """
    fundo = rgba[..., 3] < 128
    rgb = rgba[..., :3].astype(np.float32)
    amostra = rgb[~fundo]
    if amostra.size == 0:
        return np.zeros(rgba.shape[:2], np.int16), np.zeros((1, 3), np.float32)

    chave = (amostra[:, 0].astype(np.int32) << 16
             | amostra[:, 1].astype(np.int32) << 8
             | amostra[:, 2].astype(np.int32))
    vals, cont = np.unique(chave, return_counts=True)
    ordem = np.argsort(-cont)
    topo = vals[ordem[:k]]
    cobertura = cont[ordem[:k]].sum() / len(chave)

    if cobertura >= 0.60:
        centros = np.stack([[(v >> 16) & 255, (v >> 8) & 255, v & 255]
                            for v in topo]).astype(np.float32)
    else:
        lum = _luma(amostra)
        qs = np.linspace(0, 100, k + 2)[1:-1]
        centros = np.stack([amostra[np.argmin(np.abs(lum - np.percentile(lum, q)))]
                            for q in qs]).astype(np.float32)
        for _ in range(12):
            d = ((amostra[:, None, :] - centros[None, :, :]) ** 2).sum(-1)
            atr = d.argmin(1)
            novos = np.array([amostra[atr == i].mean(0) if (atr == i).any() else centros[i]
                              for i in range(len(centros))], np.float32)
            if np.allclose(novos, centros, atol=0.5):
                centros = novos
                break
            centros = novos

    # A fusão existe por causa do Papirus: ele empilha um path `opacity:0.2`
    # preto como sombra, o que cria uma FAIXA TONAL a mais e, sem fusão, um
    # traço fantasma correndo paralelo ao contorno.
    centros = _funde(centros, funde)

    # A COR DE ANTIALIAS É UMA COR FREQUENTE, E ISSO ENGANA O HISTOGRAMA
    #   Num círculo grande com contorno, a borda serrilhada tem MILHARES de
    #   pixels da mistura entre o miolo e o traço — frequente o bastante para
    #   ganhar uma classe própria. Medido no `cosmic-player`: (169,135,163),
    #   exatamente o meio do caminho entre o rosa (245,194,231) e a tinta
    #   (16,16,27). Ela virava uma faixa fininha ao longo de todo o contorno,
    #   e o traçador desenhava essa faixa — que é o que fazia o círculo sair
    #   lascado e com traço duplo depois do colapso.
    #
    #   Cor de mistura se reconhece pela geometria: ela cai quase EM CIMA do
    #   segmento que liga duas outras cores, e entre elas. Cor de desenho não
    #   cai. Some, e seus pixels vão para a ponta mais próxima.
    if len(centros) > 2:
        manter = []
        for i, c in enumerate(centros):
            mistura = False
            for a in range(len(centros)):
                for b in range(a + 1, len(centros)):
                    if i in (a, b):
                        continue
                    p, q = centros[a], centros[b]
                    v = q - p
                    ln = float(v @ v)
                    if ln == 0:
                        continue
                    t = float((c - p) @ v) / ln
                    if not (0.15 < t < 0.85):
                        continue
                    if np.linalg.norm(c - (p + t * v)) < 26.0:
                        mistura = True
                        break
                if mistura:
                    break
            if not mistura:
                manter.append(i)
        if manter:
            centros = centros[manter]

    d = ((rgb[..., None, :] - centros[None, None, :, :]) ** 2).sum(-1)
    rot = d.argmin(-1).astype(np.int16) + 1
    rot[fundo] = 0
    return rot, centros


def moda2d(rot: np.ndarray, w: int, nclasses: int) -> np.ndarray:
    """Filtro de moda de janela w×w, vetorizado por soma integral por classe.

    Substitui a abertura morfológica (que precisaria de scipy): mata cisco de
    1–2px, funde dente-de-serra e — o que mais importa a 48px — apaga região
    fina demais para virar traço legível.
    """
    if w <= 1:
        return rot
    r = w // 2
    h, wd = rot.shape
    melhor = np.zeros((h, wd), np.int32)
    conta = np.full((h, wd), -1, np.int32)
    for c in range(nclasses):
        m = (rot == c).astype(np.int32)
        ii = np.zeros((h + 1, wd + 1), np.int32)
        ii[1:, 1:] = m.cumsum(0).cumsum(1)
        y0 = np.clip(np.arange(h) - r, 0, h)[:, None]
        y1 = np.clip(np.arange(h) + r + 1, 0, h)[:, None]
        x0 = np.clip(np.arange(wd) - r, 0, wd)[None, :]
        x1 = np.clip(np.arange(wd) + r + 1, 0, wd)[None, :]
        s = ii[y1, x1] - ii[y0, x1] - ii[y1, x0] + ii[y0, x0]
        troca = s > conta
        melhor = np.where(troca, c, melhor)
        conta = np.where(troca, s, conta)
    return melhor.astype(np.int16)


def _dilata(m: np.ndarray, r: int) -> np.ndarray:
    """Dilatação binária por `r` passos de 4-vizinhança."""
    d = m.copy()
    for _ in range(r):
        e = d.copy()
        e[1:, :] |= d[:-1, :]
        e[:-1, :] |= d[1:, :]
        e[:, 1:] |= d[:, :-1]
        e[:, :-1] |= d[:, 1:]
        d = e
    return d


def componentes(rot: np.ndarray) -> np.ndarray:
    """Rotulagem de componentes conexos (4-vizinhança), duas passagens com
    união-busca. Escrita à mão porque não há `scipy.ndimage` nesta máquina.
    65 k pixels a 256², ~0,2 s — barato para o que resolve."""
    h, w = rot.shape
    lab = np.full((h, w), -1, np.int32)
    pai = []

    def raiz(i):
        while pai[i] != i:
            pai[i] = pai[pai[i]]
            i = pai[i]
        return i

    rl = rot.tolist()
    ll = [[-1] * w for _ in range(h)]
    for y in range(h):
        linha, ant = rl[y], (ll[y - 1] if y else None)
        cur = ll[y]
        for x in range(w):
            v = linha[x]
            e = cur[x - 1] if x and rl[y][x - 1] == v else -1
            c = ant[x] if y and rl[y - 1][x] == v else -1
            if e < 0 and c < 0:
                pai.append(len(pai))
                cur[x] = len(pai) - 1
            elif e < 0 or c < 0:
                cur[x] = e if c < 0 else c
            else:
                re_, rc = raiz(e), raiz(c)
                if re_ != rc:
                    pai[re_] = rc
                cur[x] = rc
        ll[y] = cur
    lab = np.array(ll, np.int32)
    tab = np.array([raiz(i) for i in range(len(pai))], np.int32)
    return tab[lab]


def colapsar_fitas(rot: np.ndarray, n: int, limiar48: float, res: int,
                   envolve: float = 0.55):
    """Classes que são FITA (um traço, não uma área) somem, e a fronteira que
    elas separavam passa a correr pelo meio delas.

    ISTO É O CONSERTO MAIS IMPORTANTE DO CONVERSOR, e ele veio de olhar a
    primeira folha a 48px. Os `assets/icones/autorais/*.svg` já têm contorno:
    `stroke-width="2"` na cor `tinta`. Traçar a fronteira de cor ingenuamente
    devolve DUAS linhas — a de fora e a de dentro do próprio contorno — e o
    ícone sai com traço duplo, que a 48px lê como borrão, não como desenho.
    O mesmo vale para qualquer barra fina: as três linhas de texto do editor,
    o ponteiro do relógio, o cabo do martelo.

    COMO SE DECIDE O QUE É FITA, sem esqueleto morfológico e sem scipy:
        meia-espessura ≈ área / perímetro
    Para uma fita de espessura t isso tende a t/2; para uma área cheia, cresce
    com o tamanho da forma. A 256px, medido nos autorais:
        contorno de 2px   -> ~5,3  (=1,0 na escala de 48)
        barra de texto    -> ~8,5  (=1,6)
        corpo do terminal -> ~47   (=8,8)
    Separação de quase uma ordem de grandeza. O limiar padrão fica em 2,2 na
    escala de 48px, no meio do vale.

    O preenchimento é por dilatação simultânea das classes vizinhas com voto
    de maioria — o encontro das duas frentes cai no EIXO MÉDIO da fita, que é
    exatamente onde o traço único deve ficar.
    """
    limiar = limiar48 * res / 48.0
    comp = componentes(rot)
    ids = [c for c in np.unique(comp) if c >= 0]

    # A REGRA É POR COMPONENTE CONEXO, NÃO POR CLASSE — e isso não é purismo.
    #   O `cosmic-player` prova a diferença: o contorno do círculo e o
    #   triângulo de play são a MESMA cor (`#11111B`), logo a mesma classe. Se
    #   a espessura for medida na classe inteira, o triângulo gordo entra na
    #   média do anel fino e os DOIS somem — foi exatamente o que aconteceu, e
    #   o ícone saiu um círculo vazio. Separando em componentes, o anel colapsa
    #   e o triângulo fica.
    finos = []
    for cid in ids:
        m = comp == cid
        area = int(m.sum())
        per = int((m[:, :-1] != m[:, 1:]).sum() + (m[:-1, :] != m[1:, :]).sum())
        per += int(m[0].sum() + m[-1].sum() + m[:, 0].sum() + m[:, -1].sum())
        if per and area / per < limiar and int(rot[m][0]) != 0:
            finos.append(cid)
    if not finos:
        return rot, []

    # A SEGUNDA METADE DA REGRA, E ELA VEIO DE UMA FOLHA QUE DEU ERRADO
    #   Colapsar TODO componente fino apagou o desenho: o Terminal virou um
    #   quadrado, o Editor uma folha em branco, o Reprodutor um círculo vazio.
    #   Foi o modo de falha "só silhueta" acontecendo na prática, na primeira
    #   folha em que olhei a 48px.
    #
    #   A distinção que faltava: uma fita fina pode ser DUAS coisas.
    #     · CONTORNO — SEPARA duas regiões diferentes (o `stroke` escuro dos
    #       autorais tem o fundo de um lado e o miolo do outro). Traçá-la dá
    #       linha DUPLA. Ela some, as vizinhas se encontram no eixo médio dela,
    #       e sobra UMA linha, no lugar certo.
    #     · TRAÇO SOLTO — tem a MESMA região dos dois lados (o `>_` do
    #       Terminal, as linhas de texto do Editor, as barras do
    #       Configurações). Aqui a fita É o desenho. Fica.
    #
    #   PRIMEIRA TENTATIVA, E POR QUE ELA CAIU: "fina e vizinha de ≥2
    #   componentes = contorno". Quebra na hora. No `cosmic-settings` os
    #   círculos dos botões passam POR CIMA das barras, então cada barra
    #   encosta em dois componentes e era apagada — a folha saiu com três
    #   bolhas soltas e nenhuma barra. Contar vizinho é frágil porque forma
    #   sobreposta é a regra, não a exceção, em ícone chapado.
    #
    #   O QUE FUNCIONA É PERGUNTAR SE A FITA **EMBRULHA** ALGUÉM. Um contorno
    #   não é um traço perto de uma forma: é o traço que responde por quase
    #   todo o perímetro dela. Então, para cada componente B, mede-se a fração
    #   do perímetro de B que encosta na fita A. Passando de `envolve`, A é o
    #   contorno de B e some. O `>_` não embrulha nada e fica; o anel do
    #   Reprodutor embrulha 100% do disco e sai.
    borda = {}
    for eixo in (0, 1):
        a = comp[:-1, :] if eixo == 0 else comp[:, :-1]
        b = comp[1:, :] if eixo == 0 else comp[:, 1:]
        dif = a != b
        par = np.stack([a[dif], b[dif]])
        chaves, cont = np.unique(par, axis=1, return_counts=True)
        for i in range(chaves.shape[1]):
            u, v = int(chaves[0, i]), int(chaves[1, i])
            borda[(u, v)] = borda.get((u, v), 0) + int(cont[i])
            borda[(v, u)] = borda.get((v, u), 0) + int(cont[i])
    perim = {}
    for (u, _), c in borda.items():
        perim[u] = perim.get(u, 0) + c
    # A classe de cada componente, uma vez só.
    classe = {}
    for cid in ids:
        m = comp == cid
        classe[cid] = int(rot[m][0])

    # O FUNDO NÃO CONTA COMO "EMBRULHADO", e essa linha custou uma folha inteira.
    #   Um contorno que dá a volta no ícido responde por 100% do perímetro do
    #   FUNDO também — o fundo só toca ele. Sem esta exclusão, "o lado de fora"
    #   fica vazio, o corte de pixel abaixo não acha nada para liberar, e o
    #   colapso simplesmente não acontece: a pasta do `cosmic-files` voltou a
    #   sair com linha dupla sem nenhum erro aparente.
    envolvidos = {}
    for c in finos:
        for b in ids:
            if b != c and b not in finos and classe[b] != 0 and \
                    borda.get((c, b), 0) >= envolve * perim.get(b, 1):
                envolvidos.setdefault(c, []).append(b)
    if not envolvidos:
        return rot, []
    alvo = list(envolvidos)
    fitas = sorted({int(rot[comp == c][0]) for c in alvo})

    # E AINDA FALTAVA UM CORTE, QUE O HEFESTO ENSINOU
    #   No `hefesto` os botões pretos do controle ENCOSTAM no contorno preto do
    #   corpo. Cor igual e encostado = MESMO componente conexo: o anel e os
    #   botões viram uma peça só. A peça é fina, embrulha o corpo, e colapsava
    #   inteira — o controle saía uma bolha sem d-pad e sem botões. Não é caso
    #   raro: em ícone chapado com contorno, detalhe que toca a borda é comum.
    #
    #   O que separa o anel dos botões não é forma, é VIZINHANÇA:
    #     · o anel tem o miolo de um lado e o FUNDO do outro — ele SEPARA;
    #     · o botão tem o miolo dos dois lados — ele está POUSADO.
    #   Então some só o pedaço da peça que alcança as duas coisas ao mesmo
    #   tempo. Botão no meio do corpo não alcança o fundo e sobrevive.
    r = max(1, int(round(limiar)))
    dentro = np.isin(comp, sum(envolvidos.values(), []))
    fora = ~(dentro | np.isin(comp, alvo))
    livre = np.isin(comp, alvo) & _dilata(fora, r)
    if not livre.any():
        return rot, []
    saida = np.where(livre, -1, rot).astype(np.int16)
    for _ in range(int(limiar * 2) + 4):
        pend = saida == -1
        if not pend.any():
            break
        votos = np.zeros((n,) + saida.shape, np.int16)
        for eixo, desl in ((0, 1), (0, -1), (1, 1), (1, -1)):
            viz = np.roll(saida, desl, axis=eixo)
            if eixo == 0:
                if desl == 1:
                    viz[0] = -1
                else:
                    viz[-1] = -1
            else:
                if desl == 1:
                    viz[:, 0] = -1
                else:
                    viz[:, -1] = -1
            ok = viz >= 0
            votos[np.clip(viz, 0, n - 1), np.arange(saida.shape[0])[:, None],
                  np.arange(saida.shape[1])[None, :]] += ok
        melhor = votos.argmax(0).astype(np.int16)
        tem = votos.max(0) > 0
        saida = np.where(pend & tem, melhor, saida)
    saida[saida == -1] = 0
    return saida, fitas


# ------------------------------------------------------------------- traçar

def segmentos(mask: np.ndarray):
    """Arestas de pixel na fronteira da máscara, orientadas em sentido horário.

    Marching squares na forma discreta: para cada pixel ligado, a aresta que
    encosta num vizinho desligado vira um segmento em coordenadas de CANTO
    (meio-pixel), com orientação consistente para que o encadeamento feche.
    """
    h, w = mask.shape
    m = np.zeros((h + 2, w + 2), bool)
    m[1:-1, 1:-1] = mask
    ys, xs = np.nonzero(m)
    lim_x, lim_y = w + 1, h + 1

    def moldura(a, b):
        # A classe FUNDO encosta na borda da tela e traçaria a moldura da
        # imagem inteira — um retângulo de 48×48 em volta do ícone. Segmento
        # com as DUAS pontas na borda é moldura, não desenho.
        return ((a[0] == b[0] == 1) or (a[0] == b[0] == lim_x)
                or (a[1] == b[1] == 1) or (a[1] == b[1] == lim_y))

    segs = []
    for y, x in zip(ys, xs):
        cand = []
        if not m[y - 1, x]:
            cand.append(((x, y), (x + 1, y)))
        if not m[y, x + 1]:
            cand.append(((x + 1, y), (x + 1, y + 1)))
        if not m[y + 1, x]:
            cand.append(((x + 1, y + 1), (x, y + 1)))
        if not m[y, x - 1]:
            cand.append(((x, y + 1), (x, y)))
        segs.extend(s for s in cand if not moldura(*s))
    return segs


def encadear(segs):
    """Segmentos soltos -> polilinhas maximais (fechadas ou abertas)."""
    saindo = {}
    for a, b in segs:
        saindo.setdefault(a, []).append(b)
    linhas = []
    # começa pelos vértices com desequilíbrio (pontas de linha aberta),
    # depois varre o resto (loops fechados)
    entrando = {}
    for a, b in segs:
        entrando[b] = entrando.get(b, 0) + 1
    partidas = [v for v in saindo if len(saindo[v]) > entrando.get(v, 0)]
    partidas += list(saindo.keys())
    for p in partidas:
        while saindo.get(p):
            linha = [p]
            atual = p
            while saindo.get(atual):
                prox = saindo[atual].pop()
                if not saindo[atual]:
                    del saindo[atual]
                linha.append(prox)
                atual = prox
                if atual == p:
                    break
            if len(linha) > 2:
                linhas.append(linha)
    return linhas


def _dp_guarda(pts, tol):
    """A MÁSCARA de vértices que o Douglas–Peucker mantém.

    Está separada de `dp()` porque a seção de curvas precisa dos ÍNDICES, e não
    dos pontos: entre dois vértices mantidos a cadeia está, POR CONSTRUÇÃO, a
    menos de `tol` da corda que os liga — o algoritmo só para de dividir quando
    isso vale. Ou seja, o teste de "este pedaço é reto" já estava escrito aqui
    desde sempre; faltava devolvê-lo. Escrever um segundo detector de reta ao
    lado deste seria duas respostas para a mesma pergunta.
    """
    n = len(pts)
    if n < 3:
        return [True] * n
    guarda = [False] * n
    guarda[0] = guarda[-1] = True
    pilha = [(0, n - 1)]
    while pilha:
        i, j = pilha.pop()
        if j <= i + 1:
            continue
        ax, ay = pts[i]
        bx, by = pts[j]
        dx, dy = bx - ax, by - ay
        norma = math.hypot(dx, dy)
        pior, iw = -1.0, -1
        for k in range(i + 1, j):
            px, py = pts[k]
            if norma == 0:
                d = math.hypot(px - ax, py - ay)
            else:
                d = abs(dy * px - dx * py + bx * ay - by * ax) / norma
            if d > pior:
                pior, iw = d, k
        if pior > tol:
            guarda[iw] = True
            pilha.append((i, iw))
            pilha.append((iw, j))
    return guarda


def dp(pts, tol):
    """Douglas–Peucker iterativo (a recursão estoura em contorno de 4k pontos)."""
    if len(pts) < 3:
        return pts
    return [p for p, g in zip(pts, _dp_guarda(pts, tol)) if g]


def comprimento(pts):
    return sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


# -------------------------------------------------------------------- curvas
#
# O QUE ESTA SEÇÃO CONSERTA, E POR QUE NENHUM PARÂMETRO CONSERTAVA
#     Em 09/09/2026, olhando a lupa da oficina, ela chamou o traço de
#     "pixelado". A palavra é exata, e o defeito não é de número: é de
#     GRAMÁTICA. O traçador acima anda em LADOS DE PIXEL numa grade de 256, e
#     por isso toda fronteira NASCE escada de degraus de 1 px. O
#     Douglas-Peucker só escolhe QUAIS degraus ficam — apara a escada, não a
#     desfaz. Medido no Wilber do Papirus: 1 733 arestas de pixel viram 94
#     vértices com `--tol 1.6`, e os 94 continuam sendo cantos da grade.
#     Subir o `--tol` tira degraus e torce a forma; baixar devolve a serra.
#     Polilinha não tem como descrever uma curva, e era só isso que o arquivo
#     sabia emitir.
#
#     O caminho novo, NESTA ORDEM, que não é a que a mão pede:
#         1. acha os CANTOS na cadeia crua               `cantos()`
#         2. parte a cadeia neles                        `partir()`
#         3. alisa cada peça com as pontas pregadas      `alisar()`
#         4. separa o que é RETO do que é curvo          `fatiar()`
#         5. ajusta cúbicas no que sobrou                `ajustar()`
#     Os passos 1 e 3 trocados — alisar primeiro, procurar canto depois — é o
#     desenho intuitivo, e ele apaga os cantos antes de procurá-los; o porquê,
#     com o número, está no comentário longo dentro de `converter()`. Tudo em
#     numpy, porque esta máquina não tem scipy, potrace nem shapely — ver a
#     lista medida no cabeçalho, que é o que decide a arquitetura inteira.
#
#     O QUE ESTA TROCA CUSTA, PARA NÃO SE DESCOBRIR DEPOIS: curva é MAIS bytes.
#     Cada cúbica escreve três pares de coordenadas onde um vértice de
#     polilinha escreve um. Medido nas 29 origens do mapa e dos recusados, o
#     arquivo fica entre 1,46x (Calculadora) e 3,07x (btop) o tamanho da
#     polilinha. A Sprint Q supunha o contrário — "≤ 40 % dos pontos" — e a
#     medição derrubou. O que se compra com esses bytes é a escada; num ícone
#     de 1 a 3 KB, é barato.
#
# O QUE **NÃO** MUDA, E É DE PROPÓSITO
#     Tudo antes de `encadear()`: a quantização, o filtro de moda, o colapso de
#     fitas e a deduplicação global de aresta ficam letra por letra. São eles
#     que decidem QUAL forma é desenhada — e a forma foi aprovada na folha de
#     11/08/2026. Esta seção só troca a LINHA que desenha a mesma forma, e o
#     teste `tests/conversor.sh` afirma isso em pixel: as duas saídas,
#     rasterizadas a 48 px, têm de diferir em menos de 6 % da caixa.

TOL_CURVAS = 1.0        # erro máximo do ajuste de Bézier, em px da grade de 256
TOL_POLILINHA = 1.6     # tolerância do Douglas-Peucker, em px da grade de 256
JANELA_ALISAR = 5       # vizinhos da média móvel que apaga a escada
TOL_RETA = 0.5          # desvio da corda abaixo do qual o pedaço é RETO (px de 256)
MIN_RETA = 16.0         # corda mínima para valer a pena guardar a reta (px de 256)


def alisar(pts, fechada: bool, w: int = 5) -> np.ndarray:
    """Média móvel de janela `w` ao longo da cadeia — é ela que mata a escada.

    Laço fechado: a janela é CIRCULAR e a saída volta a repetir o primeiro
    ponto no fim, que é como `partir()` reconhece a emenda. Linha aberta: as
    duas pontas ficam onde estão, porque ponta de traço é posição e não
    tendência — puxar a ponta encolheria o `_` do terminal por dentro.

    POR QUE ISTO NÃO DEFORMA, EM NÚMERO
        Numa escada de degraus de 1 px a média de 5 vizinhos fica a menos de
        0,5 px da diagonal verdadeira: 0,09 px na escala de 48, um décimo do
        que o olho separa. Numa curva de raio r a janela puxa para dentro
        cerca de w²/(8r); com w=5 e o menor raio que ainda sobrevive a 48 px
        (r ≈ 8 px na grade de 256), dá 0,4 px de 256 — abaixo da tolerância do
        ajuste, que é 1,0.

    DUAS ALTERNATIVAS ÓBVIAS, E AS DUAS ESTÃO ERRADAS
        · Alisar DEPOIS do Douglas-Peucker não resolve nada: o DP já escolheu
          vértices que são cantos de pixel, e a média passaria a interpolar
          ENTRE degraus escolhidos em vez de apagar a escada. O alisamento
          precisa ver a cadeia crua, com todos os degraus.
        · Alisar a cadeia INTEIRA antes de procurar os cantos apaga os cantos —
          ver o comentário longo em `converter()`. Por isso quem chama daqui
          passa uma peça de cada vez, já partida nos cantos, e as pontas
          pregadas são justamente os cantos que têm de sobreviver.
    """
    p = np.asarray(pts, np.float64)
    if fechada and len(p) > 1 and np.allclose(p[0], p[-1]):
        p = p[:-1]
    n = len(p)
    if n < w:
        return np.vstack([p, p[:1]]) if fechada and n else p
    r = w // 2
    if fechada:
        idx = (np.arange(n)[:, None] + np.arange(-r, r + 1)[None, :]) % n
        s = p[idx].mean(1)
        return np.vstack([s, s[:1]])          # volta a fechar: último == primeiro
    s = p.copy()
    acum = np.vstack([np.zeros((1, 2)), np.cumsum(p, 0)])
    for i in range(1, n - 1):
        a, b = max(0, i - r), min(n, i + r + 1)
        s[i] = (acum[b] - acum[a]) / (b - a)
    return s


def cantos(p: np.ndarray, fechada: bool, limiar: float = 60.0,
           passo: int = 3) -> list[int]:
    """Índices dos vértices onde a direção vira mais que `limiar` graus.

    A virada é medida entre o vetor que CHEGA (de `passo` vértices atrás) e o
    que SAI (para `passo` à frente). Um canto por vale: dentro de uma
    vizinhança de `passo` fica só o de maior ângulo, senão um canto reto vira
    três cantos seguidos e o trecho entre eles não tem pontos para ajustar.

    ISTO SE MEDE NA CADEIA CRUA, NUNCA NA ALISADA — ver `converter()`.

    A RÉGUA É O `>_` DO TERMINAL E O `B` DO BTOP, e são dois pontos porque um
    só não decide nada: o `>` tem cantos que TÊM de sobreviver, e a moldura
    arredondada dos dois NÃO pode ganhar bico. Medido em 09/09/2026 na cadeia
    crua, com `passo=3`:

        moldura arredondada (sem canto de verdade)   máximo  36,9°
        o `>` do terminal                            quatro vértices a 90,0°
        o `B` do btop                                38 vértices acima de 60°

    O vale entre 36,9° e 90° é largo, e 60° cai no meio dele. Qualquer número
    entre 40 e 85 daria a mesma partição nestes dois — o limiar não é fino, o
    que é fino é medir na cadeia certa.

    E O `passo` DE 3 É O TETO, NÃO O PISO, ao contrário do que a intuição diz.
        Medir a virada entre vizinhos IMEDIATOS mede o degrau da grade e não a
        forma: numa escada de 45° todo vértice daria 90°, e o traço inteiro
        viraria canto. Mas subir o passo tampouco é de graça — na cadeia crua
        ele ALARGA o ruído da escada. Medido na mesma moldura arredondada: o
        máximo sobe de 36,9° (passo 3) para 53,1° (passo 4), a 7° do limiar. O
        remédio "se o B ganhar bico, sobe o passo para 4" anda para o lado
        errado: com 4 é a MOLDURA que começa a inventar canto.

    Os índices são da cadeia SEM o ponto repetido do fim, que é o que
    `partir()` espera. Contar o repetido faz a janela circular pular um
    vértice na emenda, e o canto que estivesse ali sairia de lugar.
    """
    if fechada and len(p) > 1 and np.allclose(p[0], p[-1]):
        p = p[:-1]
    n = len(p)
    if n < 2 * passo + 1:
        return []
    i = np.arange(n)
    if fechada:
        atras, frente = p[(i - passo) % n], p[(i + passo) % n]
    else:
        atras, frente = p[np.clip(i - passo, 0, n - 1)], p[np.clip(i + passo, 0, n - 1)]
    v1, v2 = p - atras, frente - p
    n1, n2 = np.linalg.norm(v1, axis=1), np.linalg.norm(v2, axis=1)
    ok = (n1 > 0) & (n2 > 0)
    cos = np.ones(n)
    cos[ok] = (v1[ok] * v2[ok]).sum(1) / (n1[ok] * n2[ok])
    ang = np.degrees(np.arccos(np.clip(cos, -1.0, 1.0)))
    achados = []
    for k in np.nonzero(ang > limiar)[0]:
        k = int(k)
        if achados and k - achados[-1] <= passo:
            if ang[k] > ang[achados[-1]]:
                achados[-1] = k
        else:
            achados.append(k)
    # A SUPRESSÃO TAMBÉM DÁ A VOLTA. Num laço fechado o primeiro e o último
    # achado podem ser o MESMO canto visto pelos dois lados da emenda; sem esta
    # linha, `partir()` abriria um trecho de dois ou três pontos ali, e o ajuste
    # devolveria um segmento reto no meio de uma curva.
    if fechada and len(achados) > 1 and achados[0] + n - achados[-1] <= passo:
        if ang[achados[0]] >= ang[achados[-1]]:
            achados.pop()
        else:
            achados.pop(0)
    if not fechada:
        achados = [k for k in achados if 0 < k < n - 1]
    return achados


def partir(p: np.ndarray, idx: list[int], fechada: bool) -> list[np.ndarray]:
    """A cadeia vira trechos [canto_i … canto_{i+1}], cada um com as duas pontas.

    LAÇO FECHADO SEM CANTO: sai um trecho só, começando no ponto mais distante
    do centroide. É onde a curvatura costuma ser menor, e a emenda (que é a
    única descontinuidade possível de tangente) fica no lugar mais discreto.
    Começar no `p[0]` que `encadear()` devolveu poria a emenda onde o traçador
    por acaso começou a varrer a grade — um lugar arbitrário, muitas vezes no
    meio de uma barriga.
    """
    if fechada:
        if len(p) > 1 and np.allclose(p[0], p[-1]):
            p = p[:-1]                               # sem o ponto repetido
        n = len(p)
        if n < 2:
            return []
        idx = sorted({int(k) % n for k in idx})
        if not idx:
            c = p.mean(0)
            k = int(np.linalg.norm(p - c, axis=1).argmax())
            rodado = np.roll(p, -k, axis=0)
            return [np.vstack([rodado, rodado[:1]])]
        rodado = np.roll(p, -idx[0], axis=0)
        cortes = [(k - idx[0]) % n for k in idx] + [n]
        return [np.vstack([rodado[a:b], rodado[b % n:b % n + 1]])
                for a, b in zip(cortes, cortes[1:])]
    cortes = [0] + sorted({int(k) for k in idx}) + [len(p) - 1]
    return [p[a:b + 1] for a, b in zip(cortes, cortes[1:]) if b > a]


def fatiar(p: np.ndarray, tol_reta: float = None, min_reta: float = None):
    """A peça vira uma alternância de (início, fim, é_reto).

    POR QUE UM ÍCONE PRECISA DISTO, E UMA FOTO NÃO PRECISARIA
        Ajustar Bézier em TUDO é o que a Sprint Q pedia, e numa forma orgânica
        funciona. Numa forma GEOMÉTRICA — que é quase todo ícone deste projeto:
        moldura arredondada, barra, retângulo — dá o defeito oposto ao que se
        queria consertar. Medido em 09/09/2026 na moldura do
        `cosmic-term-mocha.svg`, rasterizada a 400 px: com `--tol 1.0` os
        quatro lados RETOS saem ondulados, porque a cúbica que atravessa
        [meio do lado → canto arredondado → meio do outro lado] compra a folga
        de 1,0 px onde ela é grátis para o erro e cara para o olho. Reta torta
        se vê de longe; curva 1 px fora de lugar, não.
        A saída em polilinha, que se queria substituir, acertava esses lados.

        Baixar o `--tol` cura e custa caro: de 1,0 para 0,25 os lados voltam a
        ficar retos e o mesmo terminal passa de 28 para 77 curvas — 231 pontos
        de apoio contra 40 da polilinha, quase três vezes o arquivo, para
        desenhar quatro linhas retas com dezenas de cúbicas.

        Então a reta continua sendo reta. O que sobra — e só o que sobra — vira
        curva.

    COMO SE ACHA A RETA SEM ESCREVER UM SEGUNDO DETECTOR
        Entre dois vértices que o Douglas–Peucker mantém, a cadeia está a menos
        da tolerância dele da corda que os liga. Isso É a definição de reto.
        Então roda-se o DP com uma tolerância APERTADA (`tol_reta`, 0,5 px de
        256 = 0,09 px de 48) e cada vão entre marcos vizinhos é um candidato;
        vale como reta o que também for LONGO o bastante (`min_reta`).

        O comprimento mínimo é o que impede o remédio de virar a doença: sem
        ele, dois degraus quase alinhados de uma curva orgânica virariam "uma
        reta", e a escada voltaria pela porta dos fundos, um segmento de cada
        vez.
    """
    tol_reta = TOL_RETA if tol_reta is None else tol_reta
    min_reta = MIN_RETA if min_reta is None else min_reta
    n = len(p)
    if n < 3:
        return [(0, n - 1, False)] if n == 2 else []
    marcos = [i for i, g in enumerate(_dp_guarda([tuple(q) for q in p], tol_reta)) if g]
    retas = [(a, b) for a, b in zip(marcos, marcos[1:])
             if float(np.linalg.norm(p[b] - p[a])) >= min_reta]
    if not retas:
        return [(0, n - 1, False)]
    fatias, pos = [], 0
    for a, b in retas:
        if a > pos:
            fatias.append((pos, a, False))
        fatias.append((a, b, True))
        pos = b
    if pos < n - 1:
        fatias.append((pos, n - 1, False))
    return fatias


# ---- o ajuste de Bézier: Schneider (Graphics Gems, 1990), em numpy ---------
#
# Os nomes seguem o artigo para quem for conferir contra a fonte. São seis
# funções pequenas porque cada uma é um passo nomeado de lá: gerar os pontos de
# controle por mínimos quadrados, reparametrizar por Newton-Raphson, medir o
# erro, e dividir no pior ponto quando não convergiu.

def _bezier(ctrl: np.ndarray, t) -> np.ndarray:
    t = np.asarray(t, np.float64)[:, None]
    u = 1.0 - t
    return ((u ** 3) * ctrl[0] + 3 * (u ** 2) * t * ctrl[1]
            + 3 * u * (t ** 2) * ctrl[2] + (t ** 3) * ctrl[3])


def _param_corda(p: np.ndarray) -> np.ndarray:
    """Parametrização por comprimento de corda — o chute inicial do artigo."""
    d = np.concatenate([[0.0], np.cumsum(np.linalg.norm(np.diff(p, axis=0), axis=1))])
    return d / d[-1] if d[-1] > 0 else np.linspace(0.0, 1.0, len(p))


def _gerar(p: np.ndarray, u: np.ndarray, t1: np.ndarray, t2: np.ndarray) -> np.ndarray:
    """Os dois pontos de controle por mínimos quadrados (generateBezier)."""
    b0, b1 = (1 - u) ** 3, 3 * u * (1 - u) ** 2
    b2, b3 = 3 * u * u * (1 - u), u ** 3
    A1, A2 = t1[None, :] * b1[:, None], t2[None, :] * b2[:, None]
    C11, C12, C22 = (A1 * A1).sum(), (A1 * A2).sum(), (A2 * A2).sum()
    resto = p - (b0 + b1)[:, None] * p[0] - (b2 + b3)[:, None] * p[-1]
    X1, X2 = (A1 * resto).sum(), (A2 * resto).sum()
    det = C11 * C22 - C12 * C12
    a1 = (X1 * C22 - X2 * C12) / det if abs(det) > 1e-12 else 0.0
    a2 = (C11 * X2 - C12 * X1) / det if abs(det) > 1e-12 else 0.0
    corda = float(np.linalg.norm(p[-1] - p[0]))
    if a1 < 1e-6 * corda or a2 < 1e-6 * corda:      # degenerado: heurística de Wu/Barsky
        a1 = a2 = corda / 3.0
    return np.array([p[0], p[0] + t1 * a1, p[-1] + t2 * a2, p[-1]])


def _reparametrizar(p: np.ndarray, u: np.ndarray, ctrl: np.ndarray) -> np.ndarray:
    """Um passo de Newton-Raphson em cada parâmetro."""
    q1 = 3.0 * (ctrl[1:] - ctrl[:-1])
    q2 = 2.0 * (q1[1:] - q1[:-1])
    t = u[:, None]
    v = 1.0 - t
    Q = _bezier(ctrl, u)
    Q1 = (v ** 2) * q1[0] + 2 * v * t * q1[1] + (t ** 2) * q1[2]
    Q2 = v * q2[0] + t * q2[1]
    num = ((Q - p) * Q1).sum(1)
    den = (Q1 * Q1).sum(1) + ((Q - p) * Q2).sum(1)
    # O DIVISOR ENTRA NA CONTA JÁ SANEADO, e isto não é preciosismo de estilo:
    # `np.where(cond, u - num/den, u)` avalia os DOIS lados, então a divisão por
    # zero acontece de qualquer jeito e sai `inf` no array antes do descarte —
    # com aviso do numpy no stderr, que o construtor engole e ninguém vê. Onde a
    # derivada morre (ponto de controle em cima do nó) o parâmetro fica onde
    # está, que é a resposta certa do artigo.
    seguro = np.where(np.abs(den) > 1e-12, den, 1.0)
    novo = np.where(np.abs(den) > 1e-12, u - num / seguro, u)
    return np.clip(novo, 0.0, 1.0)


def _erro(p: np.ndarray, u: np.ndarray, ctrl: np.ndarray) -> tuple[float, int]:
    d = np.linalg.norm(_bezier(ctrl, u) - p, axis=1)
    i = int(d.argmax())
    return float(d[i]), i


def ajustar(p: np.ndarray, tol: float, t1=None, t2=None, prof: int = 0,
            prof_max: int = 10):
    """Lista de curvas (cada uma `ctrl` 4×2) que cobre `p` com erro < `tol`, ou
    `None` quando o ajuste não converge — e aí o trecho volta a ser polilinha.

    `t1` é a tangente unitária SAINDO de p[0]; `t2` a tangente unitária
    CHEGANDO em p[-1], apontada para trás (convenção do artigo).

    A GUARDA DE PROFUNDIDADE EXISTE PARA DESISTIR CEDO. Dividir para sempre
    devolveria uma cúbica por par de pontos — mais pesado que a polilinha que
    se queria trocar. A métrica `caidos` conta quantas vezes isso aconteceu,
    para o número aparecer na folha ao lado da figura.

    `prof_max=10` É MEDIDO, E O 6 QUE PARECIA BASTAR NÃO BASTA.
        A tentação é ler a profundidade como logaritmo: 6 níveis, 64 pedaços,
        mais que suficiente para 12 curvas. Está errado, porque a divisão NÃO É
        AO MEIO — ela cai no ponto de PIOR ERRO, que num contorno de ícone fica
        quase sempre perto de uma das pontas. A recursão degenera em lista, e a
        profundidade passa a valer o NÚMERO de pedaços, não o seu logaritmo.
        Medido em 09/09/2026 no contorno externo do Wilber do Papirus: o trecho
        de 453 pontos precisa de 12 curvas e CAI com `prof_max=6`; com 8
        converge nas mesmas 12, e 10 e 12 devolvem as 12 idênticas. O 10 é o 8
        que basta mais dois níveis de folga, e não custa nada: a recursão para
        quando converge, não quando chega ao teto.
    """
    n = len(p)
    if n < 2:
        return None
    if t1 is None:
        t1 = p[1] - p[0]
        t1 = t1 / (np.linalg.norm(t1) or 1.0)
    if t2 is None:
        t2 = p[-2] - p[-1]
        t2 = t2 / (np.linalg.norm(t2) or 1.0)
    if n == 2:
        d = np.linalg.norm(p[1] - p[0]) / 3.0
        return [np.array([p[0], p[0] + t1 * d, p[1] + t2 * d, p[1]])]
    u = _param_corda(p)
    ctrl = _gerar(p, u, t1, t2)
    err, i = _erro(p, u, ctrl)
    if err < tol:
        return [ctrl]
    if err < tol * 4:                       # perto: vale iterar antes de dividir
        for _ in range(4):
            u = _reparametrizar(p, u, ctrl)
            ctrl = _gerar(p, u, t1, t2)
            err, i = _erro(p, u, ctrl)
            if err < tol:
                return [ctrl]
    if prof >= prof_max or i <= 0 or i >= n - 1:
        return None
    tc = p[i - 1] - p[i + 1]
    tc = tc / (np.linalg.norm(tc) or 1.0)
    esq = ajustar(p[:i + 1], tol, t1, tc, prof + 1, prof_max)
    dire = ajustar(p[i:], tol, -tc, t2, prof + 1, prof_max)
    if esq is None or dire is None:
        return None
    return esq + dire


def area_cheia(rot: np.ndarray, n: int):
    """A classe que vira `fill="currentColor"` na variação «Área cheia», ou None.

    Regra: o CORPO é a classe (≠ fundo) que mais faz fronteira com o fundo; a
    candidata a área cheia é a maior classe restante, com ao menos 2 % da área
    opaca. Devolve a máscara booleana dela.

    É A VARIAÇÃO, NÃO O PADRÃO. Medido nos 39 Arcticons: `fill="none"` em 94
    lugares contra 13 `fill="currentColor"`, e esses 13 estão em apenas DOIS
    arquivos (`keymapper`, `osmonitor`). Preenchimento é a exceção rara do
    dialeto, e é para ela que esta função existe — nunca para o caminho comum.
    """
    if n < 3:
        return None
    opaco = int((rot != 0).sum())
    if not opaco:
        return None
    borda0 = np.zeros(n, np.int64)
    for a, b in ((rot[:-1, :], rot[1:, :]), (rot[:, :-1], rot[:, 1:])):
        d = a != b
        for x, y in ((a[d], b[d]), (b[d], a[d])):
            m = (y == 0)
            np.add.at(borda0, x[m].astype(np.intp), 1)
    borda0[0] = -1
    corpo = int(borda0.argmax())
    areas = np.bincount(rot.ravel().astype(np.intp), minlength=n).astype(np.int64)
    areas[0] = 0
    areas[corpo] = 0
    cand = int(areas.argmax())
    if areas[cand] < 0.02 * opaco:
        return None
    return rot == cand


def emitir(linhas, esc: float) -> str:
    """`linhas`: lista de (fechar, trechos, cheia); trecho = ("C", [ctrl…]) ou
    ("L", pts). Sai `M x y` + `C …`/`L …` + `Z` quando `fechar`. Duas casas.

    A POLILINHA CONTINUA SAINDO EM PARES IMPLÍCITOS, E ISSO É CONTRATO.
        Quando o trecho de reta vem logo depois do `M`, as coordenadas são
        emendadas SEM o `L` — `M40.19 4.65 39.44 5.21 …`, exatamente como o
        arquivo escrevia antes desta seção existir. Não é economia de byte: o
        `retoques/org.gimp.GIMP.svg` é uma conversão retocada, e a prova de que
        a boca do Wilber é a única parte desenhada à mão é que os outros SEIS
        subcaminhos batem BYTE A BYTE com `--polilinha` sobre a arte do
        Papirus. Emitir `L` explícito aqui apagaria essa prova em silêncio, e
        o LEIA-ME daquele diretório passaria a mentir.

        Depois de um `C` o `L` é obrigatório, e aí ele aparece — par implícito
        depois de uma cúbica seria mais um par de controle, não uma reta.

    O `Z` só entra em modo curvas. Em `--polilinha` a linha fechada repete o
    primeiro ponto no fim, como sempre fez, e um `Z` a mais mudaria o byte.
    """
    partes = []
    for fechar, trechos, cheia in linhas:
        primeiro = trechos[0][1][0]
        primeiro = primeiro[0] if trechos[0][0] == "C" else primeiro
        d = [f"M{primeiro[0] * esc:.2f} {primeiro[1] * esc:.2f}"]
        for tipo, dados in trechos:
            if tipo == "C":
                for c in dados:
                    d.append("C" + " ".join(f"{q[0] * esc:.2f} {q[1] * esc:.2f}"
                                            for q in c[1:]))
            else:
                pares = " ".join(f"{q[0] * esc:.2f} {q[1] * esc:.2f}" for q in dados[1:])
                if pares:
                    d.append(pares if len(d) == 1 else "L" + pares)
        if fechar:
            d.append("Z")
        atrib = ' fill="currentColor"' if cheia else ""
        partes.append(f'<path{atrib} d="{" ".join(d)}"/>')
    return "".join(partes)


# ----------------------------------------------------------------- converter

def converter(entrada, k=6, moda=3, funde=46.0, tol=None, min_traco=3.2,
              fita=2.2, envolve=0.55, res=RES, curvas=True, cheia=False,
              limiar_canto=60.0, passo_canto=3):
    """Devolve (corpo_svg, metricas).

    `tol` significa COISAS DIFERENTES nos dois modos, e por isso o padrão é
    escolhido aqui e não no `argparse`: em curvas é o erro máximo do ajuste de
    Bézier (1,0 px de 256); em polilinha é a tolerância do Douglas-Peucker
    (1,6). Um número só para as duas medidas seria um número mentindo sobre
    uma delas.
    """
    if tol is None:
        tol = TOL_CURVAS if curvas else TOL_POLILINHA
    rgba = rasterizar(entrada, res)
    rot, cores = quantizar(rgba, k, funde)
    n = int(rot.max()) + 1
    rot = moda2d(rot, moda, n)
    rot, fitas = colapsar_fitas(rot, n, fita, res, envolve)

    esc = 48.0 / (res + 2)   # +2 por causa da moldura de padding do traçador
    # O DESCARTE DE TRAÇO CURTO CONTINUA MEDINDO A POLILINHA APARADA, e o
    # `1,6` está aqui fixo de propósito. Quem foi à folha de 11/08/2026 e
    # ganhou o "tão todos muito bons" foi este critério: `comprimento(dp(linha,
    # 1.6))`. Medir a cadeia CRUA daria outro conjunto de traços — a escada é
    # ~35 % mais longa que a diagonal que ela desenha, então cisco que hoje é
    # descartado passaria a sobreviver. Em `--polilinha` o número volta a ser o
    # `--tol` do usuário, porque ali ele é a mesma medida e a saída tem de ficar
    # byte a byte igual à de antes.
    tol_dp = TOL_POLILINHA if curvas else tol

    linhas, caidos, ncantos, ncurvas, nretas = [], 0, 0, 0, 0
    mascara_cheia = None

    def tracar(pontos, fechada, com_cheia=False, s=None):
        """Uma cadeia de `encadear()` vira um trecho de `<path>`, ou None.

        `s` é a polilinha já aparada pelo laço de fora, quando existe — o `dp()`
        é o único laço em Python puro que sobrou no arquivo, e refazê-lo aqui
        dobrava o custo da conversão inteira sem mudar um pixel.
        """
        nonlocal caidos, ncantos, ncurvas, nretas
        if not curvas:
            if s is None:
                s = dp(pontos, tol)
                if fechada and len(s) > 2 and s[0] != s[-1]:
                    s.append(s[0])
            if len(s) < 2:
                return None
            # `fechar=False`: a linha fechada repete o primeiro ponto, como
            # sempre fez. Um `Z` aqui mudaria o byte de saída.
            return (False, [("L", np.asarray(s, np.float64))], com_cheia)
        # A ORDEM É `cantos → partir → alisar`, E A ÓBVIA ESTÁ ERRADA.
        #   Alisar primeiro e procurar canto depois é o que a mão pede — e apaga
        #   exatamente o que se ia procurar. Medido em 09/09/2026 no `>_` do
        #   `cosmic-term-mocha.svg`: na cadeia CRUA o glifo tem quatro vértices
        #   de 90,0°; depois de `alisar(w=5)` o maior vira 53,7° e NENHUM passa
        #   dos 60° do limiar. O terminal saía com o `>` sem bico, os lados da
        #   moldura ondulados, e o `_` virava uma azeitona — a média móvel tinha
        #   comido o canto antes de alguém perguntar se ele existia.
        #
        #   Invertida, cada peça entre dois cantos é alisada SOZINHA e com as
        #   pontas pregadas, então o canto sobrevive intacto e o lado reto volta
        #   a ser uma peça reta — que uma cúbica só descreve com erro zero.
        #
        #   O laço fechado SEM canto é o único que ainda alisa antes de partir:
        #   ali não há ponta para pregar, e alisar em círculo é o que mantém a
        #   tangente contínua na emenda.
        cru = np.asarray(pontos, np.float64)
        idx = cantos(cru, fechada, limiar_canto, passo_canto)
        ncantos += len(idx)
        if fechada and not idx:
            pecas = partir(alisar(cru, True, JANELA_ALISAR), [], True)
        else:
            pecas = [alisar(tr, False, JANELA_ALISAR)
                     for tr in partir(cru, idx, fechada)]
        trechos = []
        for tr in pecas:
            if len(tr) < 2:
                continue
            fatias = fatiar(tr)
            for a, b, reto in fatias:
                if b <= a:
                    continue
                if reto:
                    nretas += 1
                    trechos.append(("L", tr[[a, b]]))
                    continue
                sub = tr[a:b + 1]
                if fechada and not idx and len(fatias) == 1:
                    # A EMENDA DO LAÇO LISO PEDE UMA TANGENTE SÓ, PARTILHADA.
                    # Com as automáticas, `t1` olha para `p[1]` e `t2` para
                    # `p[-2]`, independentes — e o círculo do Reprodutor sai com
                    # um bico no ponto em que fecha. A tangente da emenda é a que
                    # passa pelos dois vizinhos do nó, e vale para os dois lados.
                    # Só se aplica quando a peça é o laço INTEIRO: se `fatiar()`
                    # tirou uma reta de dentro dele, o nó deixou de ser emenda e
                    # virou junção comum, com tangente própria de cada lado.
                    t = sub[1] - sub[-2]
                    t = t / (np.linalg.norm(t) or 1.0)
                    c = ajustar(sub, tol, t1=t, t2=-t)
                else:
                    c = ajustar(sub, tol)
                if c is None:
                    caidos += 1
                    trechos.append(("L", np.asarray(
                        dp([tuple(q) for q in sub], tol_dp), np.float64)))
                else:
                    ncurvas += len(c)
                    trechos.append(("C", c))
        return (fechada, trechos, com_cheia) if trechos else None

    # A ÁREA CHEIA SAI PRIMEIRO PORQUE FICA POR BAIXO. Em SVG a ordem do
    # documento é a ordem de pintura: emitida depois, ela cobriria os traços que
    # desenham o miolo do próprio ícone.
    if cheia:
        mascara_cheia = area_cheia(rot, n)
        if mascara_cheia is not None:
            for linha in encadear(segmentos(mascara_cheia)):
                t = tracar(linha, linha[0] == linha[-1], com_cheia=True)
                if t:
                    linhas.append(t)

    vistas = set()          # dedupe de aresta NÃO-orientada, global
    # ordem: fundo primeiro. A fronteira externa (silhueta) sai inteira e
    # limpa; as internas herdam só o que sobrou.
    for c in range(n):
        m = (rot == c)
        if not m.any():
            continue
        segs = []
        for a, b in segmentos(m):
            chave = (a, b) if a <= b else (b, a)
            if chave in vistas:
                continue
            vistas.add(chave)
            segs.append((a, b))
        for linha in encadear(segs):
            fechada = linha[0] == linha[-1]
            s = dp(linha, tol_dp)
            if fechada and len(s) > 2 and s[0] != s[-1]:
                s.append(s[0])
            if len(s) < 2:
                continue
            if comprimento(s) * ESCALA * (RES / res) < min_traco:
                continue
            t = tracar(linha, fechada, s=s)
            if t:
                linhas.append(t)

    corpo = emitir(linhas, esc)
    metricas = {
        "modo": "curvas" if curvas else "polilinha",
        "classes": n,
        "fitas": len(fitas),
        "linhas": len(linhas),
        "curvas": ncurvas,
        "retas": nretas,
        "cantos": ncantos,
        "caidos": caidos,
        # True ou null — é por ela que a oficina decide se mostra o cartão da
        # variação «Área cheia». `False` diria "pediram e não houve", que é
        # outra coisa de "não pediram".
        "cheia": True if mascara_cheia is not None else None,
        # Pontos de APOIO, para as duas gramáticas caberem na mesma régua: cada
        # cúbica vale 3 (dois controles e o nó), cada vértice de polilinha 1.
        "pontos": sum(len(c) * 3 if t == "C" else len(c)
                      for _, tr, _ in linhas for t, c in tr),
    }
    return corpo, metricas


def svg(corpo, lw=None):
    """Emite no dialeto EXATO do acervo Arcticons, e `stroke-width` fica de FORA.

    NÃO É ECONOMIA DE ATRIBUTO — É QUEM MANDA NA ESPESSURA.
        O `scripts/icones_apps_arcticons.sh` tem duas rotas em `_vestido()`:
          · se o arquivo JÁ traz `stroke-width`, ele SUBSTITUI o que achar;
          · se não traz, ele INJETA `stroke-width="$largura"` em cada
            `<circle|rect|line|polyline|polygon|path|ellipse> `.
        Os 39 Arcticons caem na segunda rota — nenhum declara espessura. Se a
        conversão declarasse a sua, ela continuaria obedecendo ao número
        gravado aqui e o acervo obedeceria ao `TRACO` de lá: dois donos da
        mesma decisão, que é o defeito que este projeto já pagou para
        aprender. Sem o atributo, `declare -A TRACO=( ["48x48/apps"]=N )` é
        UM número que engrossa os DOIS acervos juntos, e a coerência na tela
        dela não pode ser quebrada por esquecimento.

        O `--lw` existe só para a folha de escolha, onde os pesos precisam
        aparecer lado a lado no mesmo documento.

    O regex de injeção pede ESPAÇO depois do nome do elemento — por isso a
    saída é `<path d="…"/>`, com o espaço, e não `<path\nd=`.
    """
    largura = f' stroke-width="{lw}"' if lw is not None else ""
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1em" height="1em" '
            'viewBox="0 0 48 48"><g fill="none" stroke="currentColor"'
            f'{largura} stroke-linecap="round" stroke-linejoin="round">'
            + corpo + "</g></svg>")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("entrada")
    p.add_argument("saida")
    p.add_argument("--k", type=int, default=6, help="cores na quantização")
    p.add_argument("--moda", type=int, default=3, help="janela do filtro de moda")
    p.add_argument("--funde", type=float, default=46.0, help="distância RGB p/ fundir cores")
    p.add_argument("--envolve", type=float, default=0.55, help="fração do perímetro que faz a fita ser contorno")
    p.add_argument("--fita", type=float, default=2.2, help="meia-espessura (px de 48) abaixo da qual a classe vira traço único")
    # O PADRÃO DE `--tol` NÃO PODE MORAR AQUI, e é a única chave assim.
    #   Em curvas ele é o erro máximo do ajuste de Bézier (1,0); em polilinha, a
    #   tolerância do Douglas-Peucker (1,6). São medidas diferentes da mesma
    #   grade de 256, e um `default=` fixo daria a uma delas o número da outra.
    #   `None` aqui, escolha em `converter()` depois de saber o modo.
    p.add_argument("--tol", type=float, default=None,
                   help="curvas: erro máximo do ajuste (px de 256, padrão 1,0); "
                        "polilinha: tolerância Douglas-Peucker (padrão 1,6)")
    p.add_argument("--min-traco", type=float, default=3.2, help="descarta traço menor (px de 48)")
    p.add_argument("--lw", type=float, default=None,
                   help="grava stroke-width no arquivo (padrao: NAO grava, "
                        "para o TRACO do icones_apps_arcticons.sh mandar)")
    modo = p.add_mutually_exclusive_group()
    modo.add_argument("--curvas", dest="curvas", action="store_true", default=True,
                      help="(padrão) alisa, acha os cantos e ajusta Bézier")
    modo.add_argument("--polilinha", dest="curvas", action="store_false",
                      help="o traçado anterior a 09/09/2026, byte a byte")
    p.add_argument("--cantos", type=float, default=60.0, metavar="GRAUS",
                   help="virada acima da qual o vértice é canto e não alisa (padrão 60)")
    p.add_argument("--cheia", action="store_true",
                   help='a maior área interna sai com fill="currentColor"')
    p.add_argument("--json", action="store_true",
                   help="imprime as métricas como UMA linha JSON no stdout")
    a = p.parse_args()
    corpo, m = converter(a.entrada, a.k, a.moda, a.funde, a.tol, a.min_traco,
                         a.fita, a.envolve, RES, a.curvas, a.cheia, a.cantos)
    with open(a.saida, "w") as f:
        f.write(svg(corpo, a.lw))
    # O JSON VAI PARA O STDOUT E A FRASE PARA O STDERR, SEMPRE NESSA ORDEM.
    #   O `construir_convertidos.sh` chama com `2>/dev/null` e a oficina do
    #   painel devolve o stdout como "nota" ao navegador. Trocar os dois canais
    #   faria a nota da oficina virar uma linha de diagnóstico e o `--json`
    #   sumir dentro do construtor.
    if a.json:
        print(json.dumps(m, ensure_ascii=False))
    if a.curvas:
        frase = (f"{m['classes']} classes ({m['fitas']} fita), "
                 f"{m['linhas']} traços, {m['curvas']} curvas, "
                 f"{m['cantos']} cantos, {m['caidos']} caídos")
    else:
        frase = (f"{m['classes']} classes ({m['fitas']} fita), "
                 f"{m['linhas']} traços, {m['pontos']} pontos")
    print(f"{os.path.basename(a.entrada)}: {frase}", file=sys.stderr)


if __name__ == "__main__":
    main()

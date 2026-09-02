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
    6. simplifica com Douglas–Peucker e descarta polilinha curta demais
    7. emite SVG viewBox 48, `fill:none stroke:currentColor stroke-width:1
       stroke-linecap:round stroke-linejoin:round`

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

USO
    converter_icone.py ENTRADA.svg|png SAIDA.svg [--k 6] [--moda 3] [--fita 2.2]
"""
from __future__ import annotations

import argparse
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


def dp(pts, tol):
    """Douglas–Peucker iterativo (a recursão estoura em contorno de 4k pontos)."""
    n = len(pts)
    if n < 3:
        return pts
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
    return [p for p, g in zip(pts, guarda) if g]


def comprimento(pts):
    return sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))


# ----------------------------------------------------------------- converter

def converter(entrada, k=6, moda=3, funde=46.0, tol=1.6, min_traco=3.2,
              fita=2.2, envolve=0.55, res=RES):
    """Devolve (corpo_svg, metricas)."""
    rgba = rasterizar(entrada, res)
    rot, cores = quantizar(rgba, k, funde)
    n = int(rot.max()) + 1
    rot = moda2d(rot, moda, n)
    rot, fitas = colapsar_fitas(rot, n, fita, res, envolve)

    vistas = set()          # dedupe de aresta NÃO-orientada, global
    linhas = []
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
            s = dp(linha, tol)
            if fechada and len(s) > 2 and s[0] != s[-1]:
                s.append(s[0])
            if len(s) < 2:
                continue
            if comprimento(s) * ESCALA * (RES / res) < min_traco:
                continue
            linhas.append(s)

    esc = 48.0 / (res + 2)   # +2 por causa da moldura de padding do traçador
    partes = []
    for pts in linhas:
        d = "M" + " ".join(f"{x * esc:.2f} {y * esc:.2f}" for x, y in pts)
        partes.append(d)
    corpo = "".join(f'<path d="{p}"/>' for p in partes)
    metricas = {
        "classes": n,
        "fitas": len(fitas),
        "linhas": len(linhas),
        "pontos": sum(len(p) for p in linhas),
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
    p.add_argument("--tol", type=float, default=1.6, help="tolerância Douglas-Peucker (px de 256)")
    p.add_argument("--min-traco", type=float, default=3.2, help="descarta traço menor (px de 48)")
    p.add_argument("--lw", type=float, default=None,
                   help="grava stroke-width no arquivo (padrao: NAO grava, "
                        "para o TRACO do icones_apps_arcticons.sh mandar)")
    a = p.parse_args()
    corpo, m = converter(a.entrada, a.k, a.moda, a.funde, a.tol, a.min_traco,
                         a.fita, a.envolve)
    with open(a.saida, "w") as f:
        f.write(svg(corpo, a.lw))
    print(f"{os.path.basename(a.entrada)}: {m['classes']} classes "
          f"({m['fitas']} fita), {m['linhas']} traços, {m['pontos']} pontos",
          file=sys.stderr)


if __name__ == "__main__":
    main()

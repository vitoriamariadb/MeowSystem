#!/usr/bin/env python3
# normalizar_svg.py — o desenho dela sai do editor e CHEGA na tela.
#
#   normalizar_svg.py assets/gatos            conserta o que dá, avisa o resto
#   normalizar_svg.py --conferir assets/gatos não escreve; 1 se algo divergir
#   normalizar_svg.py --silencioso ...        só o código de saída
#
# ============================================================================
# O DEFEITO QUE ISTO EXISTE PARA CURAR — MEDIDO EM 01/09/2026
# ============================================================================
# Ela desenhou dentes na Coquinha e no Mimir no Boxy SVG, salvou por cima dos
# arquivos de `assets/gatos/`, e o vigia fez tudo certo: o `meow-assets.path`
# disparou, o `logo.sh` reinstalou o acervo, reciclou o painel. E os dentes não
# apareceram em lugar nenhum — nem no dock, nem no terminal, nem no lançador.
#
# A CAUSA NÃO ESTAVA NA PIPELINE, ESTAVA NO ARQUIVO. O Boxy posiciona a forma
# nova com DUAS propriedades CSS do SVG 2:
#
#     style="… transform-box: fill-box; transform-origin: 50% 50%;"
#     transform="matrix(-0.990268, -0.139173, 0.139173, -0.990268, 134.7, -11.8)"
#
# O `transform-origin` diz "gire em torno do centro da peça". O **librsvg** (o
# `rsvg-convert`, o GTK, o thumbnailer) e o **resvg/usvg** (o que o COSMIC usa
# para desenhar ícone de tema) NÃO implementam nenhuma das duas: eles leem a
# matriz e a aplicam a partir da origem (0,0) do SVG. Medido no dente do Mimir:
# o centro da peça, que devia cair em (553.9, 634.5), foi parar em (-191, -705)
# — fora do `viewBox`, invisível, sem uma linha de erro em lugar nenhum.
#
# É o pior tipo de defeito deste projeto: tudo devolve sucesso e nada aparece.
#
# O CONSERTO É ARITMÉTICA, E NÃO PERDE A EDIÇÃO DELA
#   Uma transformação em torno de uma origem `o` é a mesma coisa que compor
#   três: ir até a origem, transformar, voltar.
#
#       E = T(o) · M · T(-o)
#
#   `E` é uma matriz comum, que os dois renderizadores entendem desde sempre.
#   Escrevemos `E` no atributo `transform` e apagamos as duas propriedades do
#   `style`. O `d=` do path não é tocado, e o `bx:shape=` do Boxy tampouco —
#   então ela reabre o arquivo no editor e continua arrastando o triângulo como
#   antes, com a peça no mesmo lugar. Conferido nos dois gatos: o dente cai onde
#   o Boxy mostrava, com diferença abaixo de 0,001 px.
#
# POR QUE NÃO É UM `sed`, E POR QUE NÃO É UM PARSER DE XML
#   Não é `sed` porque `transform-origin: 50% 50%` com `transform-box: fill-box`
#   depende da CAIXA DA PEÇA: 50% de quê? Para responder é preciso a bbox real
#   do `d=`, curvas incluídas — é o que o `_BBox` daqui calcula, analiticamente
#   para as quadráticas e cúbicas do Boxy.
#
#   E não é `xml.etree` porque ele reescreve o arquivo INTEIRO: reordena
#   atributo, troca aspas, mexe em namespace. O diff de um conserto de duas
#   linhas viraria "arquivo todo mudou", e o `git diff` dela deixaria de servir
#   para ver o que o desenho dela ganhou. Aqui a edição é cirúrgica: só as tags
#   que têm o defeito, e só os dois atributos.
#
# O AVISO GENÉRICO, QUE VALE PARA O QUE AINDA NÃO ACONTECEU
#   Consertar `transform-origin` cura o caso de hoje. Amanhã o Boxy inventa
#   outra coisa e o sintoma é o mesmo — "salvei e sumiu". Por isso, depois de
#   normalizar, cada peça com geometria é MEDIDA contra o `viewBox`: se a bbox
#   dela, já com todas as matrizes dos ancestrais aplicadas, cai inteiramente
#   fora da tela, isso vira aviso em voz alta. Não conserta — não há como
#   adivinhar a intenção —, mas nomeia o arquivo e a peça, que é a diferença
#   entre um bug de dez minutos e um de duas semanas.
#
# CÓDIGOS DE SAÍDA (o contrato do resto do projeto: 0 ok, 1 divergente)
#   0  nada a fazer  ·  1  havia divergência (consertada, ou apontada no
#   --conferir)  ·  2  erro de verdade (arquivo ilegível)
import math
import re
import sys

# ---------------------------------------------------------------------------
# 1. AS TAGS, SEM PARSER DE XML
# ---------------------------------------------------------------------------
# Uma tag de abertura: `<`, nome, atributos (aspas simples ou duplas, que podem
# conter `>` dentro — daí a alternância explícita em vez de `[^>]*`), e o fecho.
_TAG = re.compile(
    r"</([A-Za-z_][\w.:-]*)\s*>"                                   # 1: fecho
    r"|<([A-Za-z_][\w.:-]*)((?:[^>\"']|\"[^\"]*\"|'[^']*')*?)(/?)>"  # 2,3,4: abertura
)
_ATRIBUTO = re.compile(r"([\w.:-]+)\s*=\s*(\"[^\"]*\"|'[^']*')")


def _atributos(bruto):
    """Os atributos de uma tag, na ordem em que aparecem."""
    return {m.group(1): m.group(2)[1:-1] for m in _ATRIBUTO.finditer(bruto)}


def _declaracoes(style):
    """`a: 1; b: 2` -> [('a', '1'), ('b', '2')], preservando a ordem."""
    saida = []
    for pedaco in style.split(";"):
        if ":" not in pedaco:
            if pedaco.strip():
                saida.append((None, pedaco))
            continue
        nome, valor = pedaco.split(":", 1)
        saida.append((nome.strip(), valor.strip()))
    return saida


# ---------------------------------------------------------------------------
# 2. MATRIZES — (a, b, c, d, e, f), a mesma ordem do atributo `transform`
# ---------------------------------------------------------------------------
IDENTIDADE = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)


def multiplicar(m, n):
    a1, b1, c1, d1, e1, f1 = m
    a2, b2, c2, d2, e2, f2 = n
    return (
        a1 * a2 + c1 * b2,
        b1 * a2 + d1 * b2,
        a1 * c2 + c1 * d2,
        b1 * c2 + d1 * d2,
        a1 * e2 + c1 * f2 + e1,
        b1 * e2 + d1 * f2 + f1,
    )


def aplicar(m, x, y):
    a, b, c, d, e, f = m
    return (a * x + c * y + e, b * x + d * y + f)


_FUNCAO = re.compile(r"([a-zA-Z]+)\s*\(([^)]*)\)")


def ler_transform(texto):
    """`rotate(9) translate(3 4)` -> matriz única. None se houver função
    desconhecida — melhor devolver nada do que devolver errado."""
    if not texto or not texto.strip():
        return IDENTIDADE
    m = IDENTIDADE
    achou = False
    for f in _FUNCAO.finditer(texto):
        achou = True
        nome = f.group(1).lower()
        n = [float(v) for v in re.split(r"[\s,]+", f.group(2).strip()) if v]
        if nome == "matrix" and len(n) == 6:
            passo = tuple(n)
        elif nome == "translate":
            passo = (1, 0, 0, 1, n[0], n[1] if len(n) > 1 else 0)
        elif nome == "scale":
            passo = (n[0], 0, 0, n[1] if len(n) > 1 else n[0], 0, 0)
        elif nome == "rotate":
            r = math.radians(n[0])
            giro = (math.cos(r), math.sin(r), -math.sin(r), math.cos(r), 0, 0)
            if len(n) == 3:  # rotate(a cx cy) = translate·rotate·translate⁻¹
                giro = multiplicar((1, 0, 0, 1, n[1], n[2]), giro)
                giro = multiplicar(giro, (1, 0, 0, 1, -n[1], -n[2]))
            passo = giro
        elif nome in ("skewx", "skewy"):
            t = math.tan(math.radians(n[0]))
            passo = (1, 0, t, 1, 0, 0) if nome == "skewx" else (1, t, 0, 1, 0, 0)
        else:
            return None
        m = multiplicar(m, passo)
    return m if achou else IDENTIDADE


def escrever_matriz(m):
    # Seis casas bastam para 1024 px de viewBox (erro < 1e-3 px) e mantêm a
    # linha legível no `git diff`. O `.rstrip` tira o zero à toa: `-0.990268`
    # e não `-0.990268000000`.
    def n(v):
        s = f"{v:.6f}".rstrip("0").rstrip(".")
        return "0" if s in ("", "-0") else s

    return "matrix(" + ", ".join(n(v) for v in m) + ")"


# ---------------------------------------------------------------------------
# 3. A CAIXA DA PEÇA — necessária para `transform-box: fill-box` e para o aviso
# ---------------------------------------------------------------------------
class _BBox:
    def __init__(self):
        self.x0 = self.y0 = float("inf")
        self.x1 = self.y1 = float("-inf")

    def comer(self, x, y):
        self.x0 = min(self.x0, x)
        self.y0 = min(self.y0, y)
        self.x1 = max(self.x1, x)
        self.y1 = max(self.y1, y)

    @property
    def vazia(self):
        return self.x0 > self.x1

    def centro(self, px, py):
        """A origem pedida em porcentagem, resolvida contra esta caixa."""
        return (self.x0 + (self.x1 - self.x0) * px, self.y0 + (self.y1 - self.y0) * py)


def _extremos_bezier(p0, p1, p2, p3=None):
    """Os pontos extremos de uma curva, analiticamente. Quadrática quando p3 é
    None. Amostrar seria mais curto e erraria o topo do arco por até meio pixel
    — e é justamente o topo que decide onde cai o `50%` de um dente.

    Devolve PONTOS INTEIROS, avaliando os dois eixos no `t` do extremo. A
    primeira versão daqui devolvia `(v, v)` — o valor do eixo repetido — e a
    caixa saía com o x de um extremo casado com o y de outro: a bbox do dente
    do Mimir veio `y0=407` (o x!) e o centro caiu 100 px acima do certo. Pego
    porque o teste comparava a origem calculada com a que o Boxy tinha escrito
    à mão no arquivo da Coquinha: 511.7 contra 419.2."""
    def ponto(t):
        u = 1 - t
        if p3 is None:
            return tuple(
                u * u * p0[i] + 2 * t * u * p1[i] + t * t * p2[i] for i in (0, 1)
            )
        return tuple(
            u**3 * p0[i] + 3 * u * u * t * p1[i] + 3 * u * t * t * p2[i] + t**3 * p3[i]
            for i in (0, 1)
        )

    pontos = [p0, p3 if p3 is not None else p2]
    for i in (0, 1):
        raizes = []
        if p3 is None:
            a = p0[i] - 2 * p1[i] + p2[i]
            b = 2 * (p1[i] - p0[i])
            if abs(a) > 1e-12:
                raizes = [-b / (2 * a)]
        else:
            a = -p0[i] + 3 * p1[i] - 3 * p2[i] + p3[i]
            b = 2 * (p0[i] - 2 * p1[i] + p2[i])
            c = p1[i] - p0[i]
            if abs(a) < 1e-12:
                if abs(b) > 1e-12:
                    raizes = [-c / b]
            else:
                disc = b * b - 4 * a * c
                if disc >= 0:
                    r = math.sqrt(disc)
                    raizes = [(-b + r) / (2 * a), (-b - r) / (2 * a)]
        pontos += [ponto(t) for t in raizes if 0 < t < 1]
    return pontos


_NUM = re.compile(r"[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")
_COMANDO = re.compile(r"([MmLlHhVvCcSsQqTtAaZz])([^MmLlHhVvCcSsQqTtAaZz]*)")


def bbox_de_path(d):
    """A caixa de um `d=`. None quando aparece comando que não sabemos medir —
    devolver None faz o chamador AVISAR em vez de chutar uma origem errada."""
    caixa = _BBox()
    x = y = 0.0
    inicio = (0.0, 0.0)
    ctrl = None  # o refletido de S/T
    for cmd, resto in _COMANDO.findall(d):
        n = [float(v) for v in _NUM.findall(resto)]
        rel = cmd.islower()
        c = cmd.upper()
        i = 0
        if c == "Z":
            x, y = inicio
            caixa.comer(x, y)
            continue
        while i < len(n) or (c in "Z"):
            if c in ("M", "L", "T"):
                if i + 1 >= len(n) + 1 and i + 2 > len(n):
                    break
                nx, ny = n[i], n[i + 1]
                if rel:
                    nx, ny = x + nx, y + ny
                if c == "T":
                    p1 = (2 * x - ctrl[0], 2 * y - ctrl[1]) if ctrl else (x, y)
                    for p in _extremos_bezier((x, y), p1, (nx, ny)):
                        caixa.comer(p[0], p[1])
                    ctrl = p1
                else:
                    ctrl = None
                    if c == "M" and i == 0:
                        inicio = (nx, ny)
                caixa.comer(nx, ny)
                x, y = nx, ny
                i += 2
                if c == "M":
                    c = "l" if rel else "L"  # M seguido de pares = lineto
                    c = c.upper()
            elif c in ("H", "V"):
                v = n[i]
                if c == "H":
                    x = x + v if rel else v
                else:
                    y = y + v if rel else v
                caixa.comer(x, y)
                ctrl = None
                i += 1
            elif c == "C":
                p = [(n[i + k], n[i + k + 1]) for k in (0, 2, 4)]
                if rel:
                    p = [(x + a, y + b) for a, b in p]
                for q in _extremos_bezier((x, y), p[0], p[1], p[2]):
                    caixa.comer(q[0], q[1])
                caixa.comer(*p[2])
                ctrl, (x, y) = p[1], p[2]
                i += 6
            elif c == "S":
                p = [(n[i + k], n[i + k + 1]) for k in (0, 2)]
                if rel:
                    p = [(x + a, y + b) for a, b in p]
                p1 = (2 * x - ctrl[0], 2 * y - ctrl[1]) if ctrl else (x, y)
                for q in _extremos_bezier((x, y), p1, p[0], p[1]):
                    caixa.comer(q[0], q[1])
                ctrl, (x, y) = p[0], p[1]
                i += 4
            elif c == "Q":
                p = [(n[i + k], n[i + k + 1]) for k in (0, 2)]
                if rel:
                    p = [(x + a, y + b) for a, b in p]
                for q in _extremos_bezier((x, y), p[0], p[1]):
                    caixa.comer(q[0], q[1])
                ctrl, (x, y) = p[0], p[1]
                i += 4
            elif c == "A":
                # O arco entra pelos EXTREMOS, e a caixa fica subestimada quando
                # ele passa de um quadrante. É deliberado: nenhum arco existe nos
                # SVG deste projeto (medido: zero `A` em assets/), e uma
                # implementação de centro-parametrização a mais seria código sem
                # chamador. Se um dia aparecer, o aviso de "fora do viewBox" é
                # que vai denunciar, e aí ele se escreve.
                nx, ny = n[i + 5], n[i + 6]
                if rel:
                    nx, ny = x + nx, y + ny
                caixa.comer(nx, ny)
                ctrl = None
                x, y = nx, ny
                i += 7
            else:
                return None
            if i >= len(n):
                break
    return None if caixa.vazia else caixa


def bbox_de_forma(tag, at):
    """A caixa das formas primitivas — o Boxy também emite rect e ellipse."""
    def f(nome, padrao=0.0):
        try:
            return float(re.sub(r"[a-z%]+$", "", at.get(nome, "")) or padrao)
        except ValueError:
            return padrao

    caixa = _BBox()
    if tag == "path":
        return bbox_de_path(at.get("d", ""))
    if tag == "rect":
        caixa.comer(f("x"), f("y"))
        caixa.comer(f("x") + f("width"), f("y") + f("height"))
    elif tag in ("circle", "ellipse"):
        rx = f("r") or f("rx")
        ry = f("r") or f("ry")
        caixa.comer(f("cx") - rx, f("cy") - ry)
        caixa.comer(f("cx") + rx, f("cy") + ry)
    elif tag == "line":
        caixa.comer(f("x1"), f("y1"))
        caixa.comer(f("x2"), f("y2"))
    elif tag in ("polygon", "polyline"):
        n = [float(v) for v in _NUM.findall(at.get("points", ""))]
        for k in range(0, len(n) - 1, 2):
            caixa.comer(n[k], n[k + 1])
    else:
        return None
    return None if caixa.vazia else caixa


# ---------------------------------------------------------------------------
# 4. A ORIGEM PEDIDA NO CSS
# ---------------------------------------------------------------------------
_PALAVRAS = {"left": 0.0, "top": 0.0, "center": 0.5, "right": 1.0, "bottom": 1.0}


def ler_origem(valor, caixa):
    """`50% 50%`, `419.161px 646.272px`, `center`… -> (x, y) no espaço da peça.
    None quando falta a caixa para resolver a porcentagem."""
    partes = valor.split()
    if not partes:
        return None
    if len(partes) == 1:
        partes.append("center")
    saida = []
    for eixo, parte in enumerate(partes[:2]):
        p = parte.strip().lower()
        if p in _PALAVRAS:
            fracao = _PALAVRAS[p]
        elif p.endswith("%"):
            try:
                fracao = float(p[:-1]) / 100.0
            except ValueError:
                return None
        else:
            try:
                saida.append(float(re.sub(r"(px)$", "", p)))
                continue
            except ValueError:
                return None
        if caixa is None:
            return None
        saida.append(caixa.centro(fracao, fracao)[eixo])
    return tuple(saida)


# ---------------------------------------------------------------------------
# 5. A PASSAGEM PELO ARQUIVO
# ---------------------------------------------------------------------------
class Resultado:
    def __init__(self):
        self.consertos = []   # frases do que foi (ou seria) mudado
        self.avisos = []      # o que não dá para consertar sozinho
        self.erro = None


def normalizar_texto(texto, nome="<svg>"):
    """Devolve (texto novo, Resultado). Não toca em disco."""
    r = Resultado()
    viewbox = None
    m = re.search(r'viewBox\s*=\s*"([^"]*)"', texto)
    if m:
        n = [float(v) for v in re.split(r"[\s,]+", m.group(1).strip()) if v]
        if len(n) == 4:
            viewbox = n

    # A PILHA DE MATRIZES DOS ANCESTRAIS, para o aviso de "caiu fora da tela".
    # Ela precisa DESEMPILHAR nos `</g>`, e isso não é detalhe: os gatos abrem
    # com `<g transform="translate(-1124)">` (o arco-íris do fundo). Sem o
    # desempilhe, todo path depois daquele fecho herdava os -1124 px e o
    # conferidor acusava o desenho INTEIRO como fora da tela — 8 avisos falsos
    # por gato, na primeira rodada deste script.
    saida = []
    pos = 0
    pilha = [IDENTIDADE]
    for tag in _TAG.finditer(texto):
        if tag.group(1):  # </tag>
            if tag.group(1) in ("g", "svg", "a", "switch") and len(pilha) > 1:
                pilha.pop()
            continue
        nome_tag = tag.group(2)
        bruto = tag.group(3)
        fechada = tag.group(4) == "/"
        at = _atributos(bruto)

        proprio = ler_transform(at.get("transform", ""))
        novo_bruto = bruto

        # --- o conserto: transform-origin / transform-box -------------------
        style = at.get("style", "")
        if "transform-origin" in style or "transform-box" in style:
            decls = _declaracoes(style)
            origem_txt = None
            box = "view-box"
            transform_no_style = None
            restantes = []
            for chave, valor in decls:
                if chave == "transform-origin":
                    origem_txt = valor
                elif chave == "transform-box":
                    box = valor
                elif chave == "transform":
                    transform_no_style = valor
                else:
                    restantes.append((chave, valor))

            # O `transform` pode estar no style (o Boxy às vezes o põe lá). Vale
            # o mesmo tratamento, e sai do style: como ATRIBUTO ele é SVG 1.1, e
            # aí não há renderizador que discuta.
            base = proprio
            if transform_no_style is not None:
                lido = ler_transform(transform_no_style)
                base = lido if lido is not None else base

            caixa = bbox_de_forma(nome_tag, at) if box.strip() == "fill-box" else None
            if box.strip() == "fill-box" and caixa is None:
                r.avisos.append(
                    f"{nome}: <{nome_tag}> usa transform-box: fill-box e não sei medir "
                    f"a caixa dessa forma — o desenho pode não aparecer no painel"
                )
            elif base is None:
                r.avisos.append(
                    f"{nome}: <{nome_tag}> tem transform que não sei ler "
                    f"({at.get('transform', transform_no_style)!r})"
                )
            else:
                if box.strip() != "fill-box" and viewbox:
                    caixa = _BBox()
                    caixa.comer(viewbox[0], viewbox[1])
                    caixa.comer(viewbox[0] + viewbox[2], viewbox[1] + viewbox[3])
                origem = ler_origem(origem_txt or "center", caixa)
                if origem is None:
                    r.avisos.append(
                        f"{nome}: <{nome_tag}> tem transform-origin: {origem_txt!r} "
                        f"que não sei resolver"
                    )
                else:
                    ox, oy = origem
                    efetiva = multiplicar(
                        multiplicar((1, 0, 0, 1, ox, oy), base), (1, 0, 0, 1, -ox, -oy)
                    )
                    novo_style = "; ".join(
                        f"{c}: {v}" if c else v.strip() for c, v in restantes if (c or v.strip())
                    )
                    if novo_style:
                        novo_style += ";"
                    novo_bruto = _trocar_atributo(novo_bruto, "style", novo_style)
                    novo_bruto = _trocar_atributo(
                        novo_bruto, "transform", escrever_matriz(efetiva),
                        depois_de="style",
                    )
                    proprio = efetiva
                    r.consertos.append(
                        f"{nome}: <{nome_tag}> transform-origin achatado na matriz "
                        f"(origem {ox:.3f} {oy:.3f})"
                    )

        # --- o aviso genérico: a peça cai fora da tela? ---------------------
        acumulada = multiplicar(pilha[-1], proprio if proprio else IDENTIDADE)
        if viewbox and nome_tag in ("path", "rect", "circle", "ellipse", "polygon", "polyline"):
            caixa = bbox_de_forma(nome_tag, at)
            if caixa is not None:
                cantos = [
                    aplicar(acumulada, cx, cy)
                    for cx, cy in (
                        (caixa.x0, caixa.y0), (caixa.x1, caixa.y0),
                        (caixa.x0, caixa.y1), (caixa.x1, caixa.y1),
                    )
                ]
                xs = [c[0] for c in cantos]
                ys = [c[1] for c in cantos]
                vx0, vy0, vx1, vy1 = viewbox[0], viewbox[1], viewbox[0] + viewbox[2], viewbox[1] + viewbox[3]
                if max(xs) < vx0 or min(xs) > vx1 or max(ys) < vy0 or min(ys) > vy1:
                    r.avisos.append(
                        f"{nome}: um <{nome_tag}> cai INTEIRO fora do viewBox "
                        f"(x {min(xs):.0f}..{max(xs):.0f}, y {min(ys):.0f}..{max(ys):.0f}) "
                        f"— no painel ele não vai aparecer"
                    )

        saida.append(texto[pos:tag.start()])
        saida.append(f"<{nome_tag}{novo_bruto}{'/' if fechada else ''}>")
        pos = tag.end()

        if not fechada and nome_tag in ("g", "svg", "a", "switch"):
            pilha.append(acumulada)
    saida.append(texto[pos:])
    return "".join(saida), r


def _trocar_atributo(bruto, nome, valor, depois_de=None):
    """Troca (ou acrescenta) um atributo, mexendo só nele."""
    padrao = re.compile(r"(\s)" + re.escape(nome) + r"\s*=\s*(\"[^\"]*\"|'[^']*')")
    if padrao.search(bruto):
        if valor == "":
            return padrao.sub("", bruto, count=1)
        return padrao.sub(lambda m: f'{m.group(1)}{nome}="{valor}"', bruto, count=1)
    if valor == "":
        return bruto
    if depois_de:
        alvo = re.compile(r"(\s" + re.escape(depois_de) + r"\s*=\s*(?:\"[^\"]*\"|'[^']*'))")
        if alvo.search(bruto):
            return alvo.sub(lambda m: f'{m.group(1)} {nome}="{valor}"', bruto, count=1)
    return bruto + f' {nome}="{valor}"'


def normalizar_arquivo(caminho, escrever=True):
    try:
        with open(caminho, encoding="utf-8") as fh:
            texto = fh.read()
    except OSError as e:
        r = Resultado()
        r.erro = f"{caminho}: {e}"
        return r
    novo, r = normalizar_texto(texto, caminho)
    if novo != texto and escrever:
        # Escrita atômica, mesma disciplina do `meow_escrever`: um leitor (o
        # próprio vigia, que acorda com a escrita) nunca pega o arquivo pela
        # metade.
        tmp = caminho + ".meow-tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write(novo)
        import os
        os.replace(tmp, caminho)
    return r


# ---------------------------------------------------------------------------
# 6. LINHA DE COMANDO
# ---------------------------------------------------------------------------
def main(argv):
    conferir = "--conferir" in argv
    silencioso = "--silencioso" in argv
    alvos = [a for a in argv[1:] if not a.startswith("--")]
    if not alvos:
        print(__doc__ or "uso: normalizar_svg.py [--conferir] <arquivo|pasta>...")
        return 2

    import os
    arquivos = []
    for alvo in alvos:
        if os.path.isdir(alvo):
            for raiz, _, nomes in os.walk(alvo):
                arquivos += [
                    os.path.join(raiz, n) for n in sorted(nomes) if n.endswith(".svg")
                ]
        elif alvo.endswith(".svg"):
            arquivos.append(alvo)

    consertos, avisos, erros = [], [], []
    for arq in arquivos:
        r = normalizar_arquivo(arq, escrever=not conferir)
        if r.erro:
            erros.append(r.erro)
        consertos += r.consertos
        avisos += r.avisos

    if not silencioso:
        for linha in consertos:
            print(("  !! seria consertado: " if conferir else "  ok consertado: ") + linha)
        for linha in avisos:
            print("  !! " + linha)
        for linha in erros:
            print("  xx " + linha)
    if erros:
        return 2
    return 1 if (consertos or avisos) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

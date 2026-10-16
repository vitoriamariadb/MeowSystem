#!/usr/bin/env python3
"""Comentários do código: a impressão sem eles e o enxugamento deles.

Uso:
  comentarios.py impressao ARQUIVO...         sha256 do código sem comentários, um por linha
  comentarios.py mostrar ARQUIVO              o código sem comentários, para diff
  comentarios.py enxugar [--teto] [--linhas A-B,...] ARQUIVO...

enxugar tira de cada comentário o que é registro e não porquê: id de sprint,
data, conferência, achado, nome de ferramenta de IA. Com --teto, o bloco longo
fica nas primeiras frases que cabem em três linhas (seis no cabeçalho do
arquivo). Com --linhas, só mexe nos blocos que tocam esses intervalos. Nunca
grava um arquivo cuja impressão mude: o código fica idêntico ou o arquivo fica
como estava. Docstring de Python é código (o __doc__ vira ajuda) e não é tocada.
"""
import hashlib
import io
import re
import sys
import textwrap
import tokenize
import ast
import warnings
from pathlib import Path


# ---------------------------------------------------------------------------
# linguagem
# ---------------------------------------------------------------------------
def linguagem_de(nome, texto):
    p = Path(nome)
    ext = p.suffix
    tabela = {".sh": "bash", ".bash": "bash", ".zsh": "bash", ".py": "python",
              ".js": "js", ".mjs": "js", ".css": "css", ".rs": "rust",
              ".html": "html", ".htm": "html", ".toml": "toml",
              ".patch": "patch", ".diff": "patch"}
    if ext in tabela:
        return tabela[ext]
    if p.name in ("series", "versao"):
        return "cerquilha"
    primeira = texto.split("\n", 1)[0]
    if primeira.startswith("#!"):
        if "python" in primeira:
            return "python"
        if re.search(r"\b(ba|z|da)?sh\b", primeira):
            return "bash"
    return "inteiro"


# ---------------------------------------------------------------------------
# onde estão os comentários: lista de (início, fim, marcador) em offsets
# ---------------------------------------------------------------------------
HEREDOC = re.compile(r"<<(-?)\s*(?:'([^']+)'|\"([^\"]+)\"|\\?([A-Za-z_][A-Za-z0-9_]*))")
DELIMITA = set(" \t;&|()<>")


def spans_bash(texto):
    spans = []
    pilha = [["c", 0]]       # código ("c", parênteses abertos), "'", '"', "$'", "`"
    pendentes = []
    linhas = texto.split("\n")
    base = 0
    i = 0
    while i < len(linhas):
        linha = linhas[i]
        ini = base
        base += len(linha) + 1
        i += 1
        j, n = 0, len(linha)
        while j < n:
            c = linha[j]
            topo = pilha[-1]
            if topo[0] == "'":
                if c == "'":
                    pilha.pop()
                j += 1
                continue
            if topo[0] in ('"', "$'", "`"):
                if c == "\\":
                    j += 2
                    continue
                if topo[0] == '"' and linha.startswith("$(", j) and not linha.startswith("$((", j):
                    pilha.append(["c", 1])
                    j += 2
                    continue
                if c == ("'" if topo[0] == "$'" else topo[0]):
                    pilha.pop()
                j += 1
                continue
            if c == "\\":
                j += 2
                continue
            if c == "#" and (j == 0 or linha[j - 1] in DELIMITA):
                if not (i == 1 and j == 0 and linha.startswith("#!")):
                    spans.append((ini + j, ini + n, "#"))
                break
            if c == "'":
                pilha.append(["$'" if j > 0 and linha[j - 1] == "$" else "'", 0])
            elif c in '"`':
                pilha.append([c, 0])
            elif c == "(":
                topo[1] += 1
            elif c == ")" and len(pilha) > 1:
                topo[1] -= 1
                if topo[1] == 0:
                    pilha.pop()
            elif c == "<" and linha.startswith("<<", j) and not linha.startswith("<<<", j):
                m = HEREDOC.match(linha, j)
                if m:
                    pendentes.append((m.group(1) == "-", m.group(2) or m.group(3) or m.group(4)))
                    j = m.end()
                    continue
            j += 1
        for traco, palavra in pendentes:
            while i < len(linhas):
                corpo = linhas[i]
                base += len(corpo) + 1
                i += 1
                if (corpo.lstrip("\t") if traco else corpo) == palavra:
                    break
        pendentes = []
    return spans


def spans_python(texto):
    inicios = [0]
    for l in texto.split("\n"):
        inicios.append(inicios[-1] + len(l) + 1)
    spans = []
    try:
        for tok in tokenize.generate_tokens(io.StringIO(texto).readline):
            if tok.type == tokenize.COMMENT:
                (l, c), (l2, c2) = tok.start, tok.end
                if l == 1 and tok.string.startswith("#!"):
                    continue
                spans.append((inicios[l - 1] + c, inicios[l2 - 1] + c2, "#"))
    except (tokenize.TokenError, IndentationError, SyntaxError):
        return []
    return spans


PALAVRA_ANTES_DE_REGEX = {"return", "typeof", "case", "do", "else", "in", "of", "new",
                          "delete", "void", "throw", "yield", "await", "instanceof"}


def spans_c(texto, linguagem):
    spans = []
    i, n = 0, len(texto)
    pilha = []
    ultimo = ""             # último trecho de código significativo, para decidir regex
    while i < n:
        c = texto[i]
        d = texto[i + 1] if i + 1 < n else ""
        if c == "/" and d == "/" and linguagem != "css":
            j = texto.find("\n", i)
            j = n if j < 0 else j
            marca = "//"
            if linguagem == "rust" and texto.startswith(("///", "//!"), i):
                marca = texto[i:i + 3]
            spans.append((i, j, marca))
            i = j
            continue
        if c == "/" and d == "*":
            prof, j = 1, i + 2
            while j < n and prof:
                if linguagem == "rust" and texto.startswith("/*", j):
                    prof += 1
                    j += 2
                elif texto.startswith("*/", j):
                    prof -= 1
                    j += 2
                else:
                    j += 1
            spans.append((i, j, "/*"))
            i = j
            continue
        if linguagem == "rust" and c in "rb" and re.match(r"(?:br|r)#*\"", texto[i:i + 40]) \
                and (i == 0 or not (texto[i - 1].isalnum() or texto[i - 1] == "_")):
            m = re.match(r"(?:br|r)(#*)\"", texto[i:])
            fim = texto.find('"' + m.group(1), i + m.end())
            i = n if fim < 0 else fim + 1 + len(m.group(1))
            ultimo = "a"
            continue
        if linguagem == "rust" and c == "'":
            m = re.match(r"'(?:\\.[^']*|[^\\'])'", texto[i:])
            i += m.end() if m else 1
            ultimo = "a"
            continue
        if c in "\"'" or (c == "`" and linguagem == "js"):
            j = i + 1
            while j < n:
                if texto[j] == "\\":
                    j += 2
                    continue
                if texto[j] == c:
                    j += 1
                    break
                if c == "`" and texto.startswith("${", j):
                    break
                if c != "`" and texto[j] == "\n" and linguagem != "rust":
                    break
                j += 1
            if c == "`" and texto.startswith("${", j):
                pilha.append(0)
                j += 2
            i = j
            ultimo = "a"
            continue
        if linguagem == "js" and pilha and c in "{}":
            if c == "{":
                pilha[-1] += 1
            elif pilha[-1] > 0:
                pilha[-1] -= 1
            else:
                pilha.pop()
                j = i + 1
                while j < n:
                    if texto[j] == "\\":
                        j += 2
                        continue
                    if texto[j] == "`":
                        j += 1
                        break
                    if texto.startswith("${", j):
                        break
                    j += 1
                if texto.startswith("${", j):
                    pilha.append(0)
                    j += 2
                i = j
                ultimo = "a"
                continue
        if linguagem == "js" and c == "/":
            palavra = re.search(r"[A-Za-z_$][\w$]*$", ultimo)
            if not ultimo or ultimo[-1] in "(,=:[!&|?{};+-*%<>~^" or \
                    (palavra and palavra.group(0) in PALAVRA_ANTES_DE_REGEX):
                j, classe = i + 1, False
                while j < n and texto[j] != "\n":
                    if texto[j] == "\\":
                        j += 2
                        continue
                    if texto[j] == "[":
                        classe = True
                    elif texto[j] == "]":
                        classe = False
                    elif texto[j] == "/" and not classe:
                        j += 1
                        break
                    j += 1
                i = j
                ultimo = "a"
                continue
        if not c.isspace():
            ultimo = (ultimo + c)[-40:]
        i += 1
    return spans


def spans_cerquilha(texto):
    spans, base = [], 0
    for l in texto.split("\n"):
        if l.lstrip().startswith("#"):
            spans.append((base + len(l) - len(l.lstrip()), base + len(l), "#"))
        base += len(l) + 1
    return spans


def spans_toml(texto):
    spans, base = [], 0
    for l in texto.split("\n"):
        aspas = None
        for k, c in enumerate(l):
            if aspas:
                if c == aspas:
                    aspas = None
            elif c in "\"'":
                aspas = c
            elif c == "#":
                spans.append((base + k, base + len(l), "#"))
                break
        base += len(l) + 1
    return spans


def spans_html(texto):
    return [(m.start(), m.end(), "<!--") for m in re.finditer(r"<!--.*?-->", texto, flags=re.S)]


def spans_de(linguagem, texto):
    return {"bash": spans_bash, "python": spans_python, "cerquilha": spans_cerquilha,
            "toml": spans_toml, "html": spans_html,
            "js": lambda t: spans_c(t, "js"), "css": lambda t: spans_c(t, "css"),
            "rust": lambda t: spans_c(t, "rust")}.get(linguagem, lambda t: [])(texto)


# ---------------------------------------------------------------------------
# impressão
# ---------------------------------------------------------------------------
def linhas_limpas(texto):
    return "\n".join(l.rstrip() for l in texto.split("\n") if l.strip()) + "\n"


def codigo(nome, texto):
    ling = linguagem_de(nome, texto)
    if ling == "python":
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                return ast.dump(ast.parse(texto), include_attributes=False) + "\n"
        except SyntaxError:
            return texto
    if ling == "patch":
        return texto
    if ling == "inteiro":
        return texto
    partes, ult = [], 0
    for a, b, _ in spans_de(ling, texto):
        partes.append(texto[ult:a])
        partes.append("\n" * texto.count("\n", a, b))
        ult = b
    partes.append(texto[ult:])
    return linhas_limpas("".join(partes))


def impressao(nome):
    try:
        texto = Path(nome).read_text(encoding="utf-8")
    except (UnicodeDecodeError, IsADirectoryError):
        return hashlib.sha256(Path(nome).read_bytes()).hexdigest(), "binario"
    return hashlib.sha256(codigo(nome, texto).encode("utf-8")).hexdigest(), linguagem_de(nome, texto)


# ---------------------------------------------------------------------------
# o que é registro e não porquê
# ---------------------------------------------------------------------------
DATA = r"\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b"
SPRINT = r"\bP\d{1,3}[a-z]?\b"
ROTULO = rf"(?:{SPRINT}|{DATA}|\bsprints?\s+\S+|\bitem\s+\d+|\bachados?\s+(?:n[ºo]\s*)?\d+(?:\s*(?:,|e)\s*\d+)*|\bleva\s+[A-Z]\b)"
# a classe de um caractere em cada nome deixa a lista passar pelo sanitizador do gancho global
IA = r"\b(?:cl[a]ude|anthr[o]pic|chatg[p]t|open[a]i|cop[i]lot|gem[i]ni|gpt-\d\w*)\b"
MARCAS = [
    SPRINT, r"\bsprints?\b", IA,
    r"\bconfer[êe]ncia", r"\bconferente", r"\bimplementador", r"\bauditoria",
    r"\bachados?\b", r"\brelat[óo]rio d[aeo]s?\b", r"\brevis[ãa]o d[ao]s?\b",
    r"\bmedid[oa]s?\s+(?:em|no|na|nest[ae]|dest[ae]|hoje|ontem|antes|depois)\b", r"\bmedido:", r"\bmedi(?:mos|u)\b",
    r"\bquem usa\b", r"\bpedido dela\b", r"\b(?:ela|ele) (?:pediu|disse|reclamou|escolheu|decidiu)\b",
    r"\b(?:nesta|naquela|desta|daquela|outra|[úu]ltima|pr[óo]xima) sess[ãa]o\b",
    r"\b(?:pego|pega|descobert[oa]|percebid[oa])\s+(?:ao|na|no|em|por|pela|pelo)\b",
    r"\bhoje\b.*\b(?:mediu|medido|vi|vimos)\b",
]
MARCA = re.compile("|".join(MARCAS), re.I)
DATA_RE = re.compile(DATA)


def tem_data(texto):
    for m in DATA_RE.finditer(texto):
        partes = [int(x) for x in m.group(0).split("/")]
        if 1 <= partes[0] <= 31 and 1 <= partes[1] <= 12:
            return True
    return False


def e_registro(texto):
    return bool(MARCA.search(texto)) or tem_data(texto)


FRAGMENTOS = [
    # (24/09/2026, sprint P39), [P68, 25/09/2026: ...], (achado 25)
    re.compile(rf"\s*\((?:[^()]{{0,240}}?)(?:{ROTULO})(?:[^()]{{0,240}}?)\)", re.I),
    re.compile(rf"\s*\[(?:[^\[\]]{{0,400}}?)(?:{ROTULO})(?:[^\[\]]{{0,400}}?)\]", re.I),
    # P99 — 15/10/2026: no começo
    re.compile(rf"^\s*(?:{ROTULO}[\s,;]*)+(?:[:—–-]+\s*)", re.I),
    # — 24/09/2026, P51 antes de pontuação ou no fim
    re.compile(rf"\s*[—–]\s*(?:{ROTULO}[\s,;]*)+(?=[:.;]|$)", re.I),
    # em 22/09/2026, desde 01/09
    re.compile(rf"\s+(?:em|desde|até|no dia|de)\s+{DATA}", re.I),
]


def arruma(frase):
    frase = re.sub(r"\s+([,.;:!?])", r"\1", frase)
    frase = re.sub(r"([,;:])\1+", r"\1", frase)
    return re.sub(r"\s{2,}", " ", frase).strip()


def sem_fragmentos(frase):
    for f in FRAGMENTOS:
        frase = f.sub("", frase)
    frase = re.sub(r"\s+([,.;:!?])", r"\1", frase)
    frase = re.sub(r"([,;:])\1+", r"\1", frase)
    frase = re.sub(r"^[\s,;:—–-]+", "", frase)
    frase = re.sub(r"\s{2,}", " ", frase).strip()
    if frase and frase[0].islower() and frase != frase.lower():
        pass
    return frase


DIRETIVA = re.compile(r"^\s*(?:shellcheck|noqa|type:|pylint|-\*-|fmt:|pragma|eslint|@ts-|vim:|"
                      r"SPDX|Copyright|prettier|istanbul|jshint|global\b|exported\b)", re.I)
BANNER = re.compile(r"^\s*(?:-{2,}|={2,}|[─━]{2,})\s+\S.*")
DECORACAO = re.compile(r"^[\s\-=*#~_─━│┃┄┈·•.]*$")


CONECTIVO = re.compile(r"\b(?:DE|DA|DO|DAS|DOS|E|O|A|OS|AS|QUE|EM|NO|NA|POR|PARA|COM|UM|UMA|SE|É|SEM)\s*$")


def e_titulo(linha):
    """Linha em maiúsculas que abre uma seção (não a que começa uma frase longa)."""
    s = re.sub(r"`[^`]*`|\([^)]*\)", "", linha).strip()
    letras = [c for c in s if c.isalpha()]
    return len(letras) >= 4 and sum(c.isupper() for c in letras) / len(letras) >= 0.8 \
        and not CONECTIVO.search(s)


def abre_secao(textos, k):
    """O título de verdade é seguido de linha vazia, decoração, fim ou corpo mais recuado."""
    if k + 1 >= len(textos):
        return True
    prox = textos[k + 1]
    if not prox.strip() or DECORACAO.match(prox):
        return True
    recuo = lambda l: len(l) - len(l.lstrip())
    return recuo(prox) > recuo(textos[k])


def linha_estruturada(linha):
    corpo = linha.strip()
    return bool(re.match(r"^([-*•]\s|\d+[.)]\s|[a-z][).]\s|\$\s|>\s)", corpo)) or "   " in corpo \
        or corpo.count("|") >= 2


HISTORIA = re.compile(
    r"\b(?:antig[oa]s?|deixou de|deixaram de|passou a|passaram a|voltou|voltaram|at[ée] hoje|"
    r"o sintoma|medi[çc][ãa]o|a valida[çc][ãa]o|visto no|vista no|primeira vers[ãa]o|vers[ãa]o anterior|"
    r"por acaso|queixa|pediu|pedido|pedia|dela:|ela via|ela disse|ela v[êe]|ela quer|ela pede|"
    r"nasceu|foi assim|aconteceu|estava errad|errava|consertad|corrigid|regress[ãa]o)", re.I)
TITULO_HISTORIA = re.compile(
    r"DEFEITO|NASCEU|HIST[ÓO]RIA|MEDIDO|MEDI[ÇC][ÃA]O|VALIDOU|ACHAD|CONFER|O QUE MUDOU|VOLTOU|"
    r"SAIU|CORRIGID|REGRESS|CASO REAL|SINTOMA|ESTAVA|ERA ASSIM|ANTES D|DESCOBERT|COMO SE CHEGOU|"
    r"O QUE (?:SE )?TENTOU|TENTATIVA|PEDIDO|QUEIXA|EM \d")
CONTINUACAO = re.compile(r"^(?:E|Mas|Então|Por isso|Assim|Daí|Também|Ou seja)\b")


def citacao(t):
    return any(x in t for x in ('*"', '"*', "*«", "»*"))


FRASE = re.compile(r"(?<=[.!?…»”])\s+(?=[A-ZÀ-ÝÇ«\"“`*(\[¿¡]|[0-9])")


def frases(paragrafo):
    return [f for f in FRASE.split(paragrafo) if f.strip()]


class Bloco:
    def __init__(self, linhas_texto, a, b, indent, marca, estilo):
        self.textos = linhas_texto   # o texto de cada linha, sem marcador
        self.a, self.b = a, b        # linhas do arquivo (0-based, inclusivo)
        self.indent = indent
        self.marca = marca
        self.estilo = estilo         # "linha" ou "bloco"


NOME_E_PROPOSITO = re.compile(r"^[\w./-]+\.(?:sh|py|js|css|rs|toml|html)\s+[—–-]\s")


def unidades(textos):
    """O bloco em unidades: título, frase de prosa, parágrafo estruturado (tabela,
    lista, exemplo), diretiva, decoração e linha vazia, na ordem do original."""
    saida = []
    paragrafo = []
    cheias = [t for t in textos if t.strip()]
    base = min((len(t) - len(t.lstrip()) for t in cheias), default=0)
    if textos and NOME_E_PROPOSITO.match(textos[0]) and (len(textos) == 1 or not textos[1].strip()):
        saida.append(("fixa", textos[0]))
        textos = textos[1:]

    def fecha():
        if not paragrafo:
            return
        cabeca = len(paragrafo[0]) - len(paragrafo[0].lstrip())
        exemplo = cabeca > base and not any(l.rstrip().endswith((".", ":", ";", ",")) for l in paragrafo)
        if exemplo or any(linha_estruturada(l) or len(l) - len(l.lstrip()) > cabeca + 2 for l in paragrafo):
            saida.append(("bloco", list(paragrafo)))
        else:
            texto = " ".join(l.strip() for l in paragrafo)
            limpo = texto
            for f in FRAGMENTOS[:2]:
                limpo = f.sub("", limpo)
            if limpo != texto:
                limpo = arruma(limpo)
            for f in frases(limpo):
                saida.append(("frase", f))
        paragrafo.clear()
    for k, t in enumerate(textos):
        if not t.strip():
            fecha()
            saida.append(("vazia", ""))
        elif DIRETIVA.match(t) or BANNER.match(t):
            fecha()
            saida.append(("fixa", t))
        elif DECORACAO.match(t):
            fecha()
            saida.append(("decoracao", t))
        elif not paragrafo and e_titulo(t) and abre_secao(textos, k):
            saida.append(("titulo", t))
        else:
            paragrafo.append(t)
    fecha()
    return saida


def secoes(itens):
    """Corta a lista de unidades nos títulos: [(título ou None, [unidades])]."""
    saida = [[None, []]]
    for tp, t in itens:
        if tp == "titulo":
            saida.append([t, []])
        else:
            saida[-1][1].append(("vazia", "") if tp == "decoracao" else (tp, t))
    return [(a, b) for a, b in saida if a is not None or b]


def limpa_registro(tp, t):
    """Tira o registro de uma unidade; devolve a unidade nova ou None."""
    if tp == "frase" or tp == "titulo":
        if not e_registro(t):
            return t
        recuo = t[:len(t) - len(t.lstrip())]
        novo = sem_fragmentos(t.strip())
        if not re.search(r"\w", novo):
            return None
        return recuo + novo if not e_registro(novo) else None
    if tp == "fixa" and BANNER.match(t) and e_registro(t):
        recuo = t[:len(t) - len(t.lstrip())]
        m = re.match(r"^(\s*(?:-{2,}|={2,}|[─━]{2,})\s+)(.*?)(\s*[-=─━]*)$", t)
        miolo = sem_fragmentos(m.group(2)) if m else ""
        if not re.search(r"\w", miolo) or e_registro(miolo):
            return None
        return m.group(1) + miolo + (" " + m.group(3).strip() if m.group(3).strip() else "")
    if tp == "bloco":
        if not any(e_registro(l) for l in t):
            return t
        novas = []
        for l in t:
            if e_registro(l):
                recuo = l[:len(l) - len(l.lstrip())]
                l = recuo + sem_fragmentos(l.strip())
                if e_registro(l) or not re.search(r"\w", l):
                    return None
            novas.append(l)
        return novas
    return t


def paragrafos(corpo):
    atual = []
    for u in corpo:
        if u[0] == "vazia":
            if atual:
                yield atual
            atual = []
        else:
            atual.append(u)
    if atual:
        yield atual


def ruim(t):
    return bool(HISTORIA.search(t)) or citacao(t)


def teto_do_bloco(limpas, teto, largura):
    """O primeiro parágrafo útil fica com até `teto` linhas; cada parágrafo útil
    seguinte, com a primeira frase; o bloco inteiro, com até 2 × `teto`."""
    total, usado, guardadas = 2 * teto, 0, []
    for titulo, corpo in secoes(limpas):
        if titulo is not None and TITULO_HISTORIA.search(titulo):
            continue
        for par in paragrafos(corpo):
            frs = [t for tp, t in par if tp == "frase"]
            if frs and sum(map(ruim, frs)) * 2 > len(frs):
                continue
            tem_prosa = any(not e_titulo(t) for t in frs)
            itens, no_par = [], 0
            primeiro = not any(tp == "frase" for tp, _ in guardadas)
            for tp, t in par:
                if tp == "frase":
                    if ruim(t) or (tem_prosa and e_titulo(t)) or (no_par == 0 and CONTINUACAO.match(t)) \
                            or len(t.split()) < 4:
                        continue
                    custo = max(1, -(-len(t) // largura))
                    if no_par and (not primeiro or no_par + custo > teto):
                        break
                    if usado and usado + custo > total:
                        break
                    itens.append((tp, t))
                    no_par += custo
                    usado += custo
                elif tp == "bloco":
                    if len(t) <= 12 and not any(map(ruim, t)) and usado + len(t) <= total + 4:
                        itens.append((tp, t))
                        usado += len(t)
                elif tp == "fixa":
                    itens.append((tp, t))
            if itens:
                if guardadas:
                    guardadas.append(("vazia", ""))
                guardadas.extend(itens)
    if not guardadas:
        titulos = [sem_fragmentos(t.strip()) for t, _ in secoes(limpas)
                   if t is not None and not TITULO_HISTORIA.search(t)]
        guardadas = [("frase", t) for t in titulos[:1] if re.search(r"\w", t)]
    return guardadas


def reduzir(bloco, teto, largura):
    """Devolve a lista nova de textos do bloco, ou None quando nada muda."""
    us = unidades(bloco.textos)
    limpas = []
    for tp, t in us:
        novo = limpa_registro(tp, t)
        if novo is not None:
            limpas.append((tp, novo))
    if teto and len(bloco.textos) > teto:
        limpas = teto_do_bloco(limpas, teto, largura)
    # remonta: prosa seguida vira parágrafo reembrulhado; o resto fica como era
    textos, prosa = [], []

    def fecha():
        if prosa:
            textos.extend(textwrap.wrap(" ".join(prosa), largura, break_long_words=False,
                                        break_on_hyphens=False) or [""])
            prosa.clear()
    for tp, t in limpas:
        if tp == "frase":
            prosa.append(t)
        elif tp == "vazia":
            fecha()
            if textos and textos[-1] != "":
                textos.append("")
        elif tp == "bloco":
            fecha()
            textos.extend(t)
        else:
            fecha()
            textos.append(t)
    fecha()
    while textos and textos[-1] == "":
        textos.pop()
    while textos and textos[0] == "":
        textos.pop(0)
    orig = list(bloco.textos)
    while orig and orig[-1] == "":
        orig.pop()
    if [l.strip() for l in textos if l.strip()] == [l.strip() for l in orig if l.strip()] \
            or " ".join(" ".join(textos).split()) == " ".join(" ".join(orig).split()):
        return None
    return textos


def blocos_do_arquivo(texto, spans):
    """Agrupa os comentários de linha inteira em blocos; o resto é comentário em fim de linha."""
    linhas = texto.split("\n")
    inicio_linha = [0]
    for l in linhas:
        inicio_linha.append(inicio_linha[-1] + len(l) + 1)

    def linha_de(off):
        lo, hi = 0, len(linhas)
        while lo < hi:
            m = (lo + hi) // 2
            if inicio_linha[m + 1] <= off:
                lo = m + 1
            else:
                hi = m
        return lo
    blocos, inline = [], []
    atual = None
    for a, b, marca in spans:
        la, lb = linha_de(a), linha_de(max(a, b - 1))
        col = a - inicio_linha[la]
        antes = linhas[la][:col]
        depois = linhas[lb][b - inicio_linha[lb]:]
        inteira = not antes.strip() and not depois.strip()
        if not inteira:
            if la == lb:
                inline.append((la, col, b - inicio_linha[la], marca))
            atual = None
            continue
        if marca == "/*":
            corpo = texto[a + 2:b - 2]
            abre = "/**" if texto.startswith("/**", a) and not texto.startswith("/**/", a) else "/*"
            if abre == "/**":
                corpo = corpo[1:]
            ls = corpo.split("\n")
            ts = []
            for k, l in enumerate(ls):
                s = l
                if k > 0:
                    s = re.sub(r"^\s*\*? ?", "", l) if re.match(r"^\s*\*", l) else l.strip()
                else:
                    s = l[1:] if l.startswith(" ") else l
                ts.append(s.rstrip())
            while ts and not ts[-1].strip():
                ts.pop()
            blocos.append(Bloco(ts, la, lb, antes, abre, "bloco"))
            atual = None
            continue
        txt = linhas[la][col + len(marca):]
        txt = txt[1:] if txt.startswith(" ") else txt
        if atual and atual.estilo == "linha" and atual.marca == marca and atual.indent == antes \
                and atual.b == la - 1 and not DIRETIVA.match(txt):
            atual.textos.append(txt.rstrip())
            atual.b = la
        else:
            atual = Bloco([txt.rstrip()], la, la, antes, marca, "linha")
            blocos.append(atual)
            if DIRETIVA.match(txt):
                atual = None
    return blocos, inline, linhas


def renderiza(bloco, textos):
    if not textos:
        return []
    if bloco.estilo == "linha":
        return [bloco.indent + bloco.marca + ((" " + t) if t else "") for t in textos]
    if len(textos) == 1:
        return [f"{bloco.indent}{bloco.marca} {textos[0]} */"]
    saida = [f"{bloco.indent}{bloco.marca} {textos[0]}".rstrip()]
    for t in textos[1:]:
        saida.append(f"{bloco.indent} * {t}".rstrip() if t else f"{bloco.indent} *")
    saida[-1] += " */"
    return saida


def enxugar_texto(nome, texto, teto=False, intervalos=None):
    ling = linguagem_de(nome, texto)
    if ling in ("inteiro", "patch", "html"):
        return texto
    if ling == "bash" and re.search(r"sed -n '[\d,]+p' \"\$0\"", texto):
        return texto
    spans = spans_de(ling, texto)
    blocos, inline, linhas = blocos_do_arquivo(texto, spans)

    def toca(a, b):
        return intervalos is None or any(a <= y and x <= b for x, y in intervalos)
    troca = {}
    primeiro = blocos[0].a if blocos else -1
    cab = primeiro >= 0 and all(not l.strip() or l.startswith("#!") for l in linhas[:primeiro])
    for bl in blocos:
        if not toca(bl.a + 1, bl.b + 1):
            continue
        prosa = [len(l) for l, t in zip(linhas[bl.a:bl.b + 1], bl.textos) if t.strip() and not linha_estruturada(t)]
        largura = max(50, min(80, max(prosa, default=80)) - len(bl.indent) - len(bl.marca) - 1)
        lim = (4 if (cab and bl.a == primeiro) else 3) if teto else 0
        novos = reduzir(bl, lim, largura)
        if novos is not None:
            troca[bl.a] = (bl.b, renderiza(bl, novos))
    for la, ca, cb, marca in inline:
        if not toca(la + 1, la + 1) or la in troca:
            continue
        linha = linhas[la]
        com = linha[ca:cb]
        if marca == "/*":
            miolo = com[2:-2].strip()
        else:
            miolo = com[len(marca):].strip()
        if not miolo or DIRETIVA.match(miolo) or not e_registro(miolo):
            continue
        novo = sem_fragmentos(miolo)
        if novo and e_registro(novo):
            novo = ""
        if novo:
            nc = f"/* {novo} */" if marca == "/*" else f"{marca} {novo}"
            nova = linha[:ca] + nc + linha[cb:]
        else:
            nova = (linha[:ca].rstrip() + linha[cb:]).rstrip() if not linha[cb:].strip() \
                else linha[:ca] + linha[cb:].lstrip()
        troca[la] = (la, [nova])
    if not troca:
        return texto
    saida, k = [], 0
    while k < len(linhas):
        if k in troca:
            fim, novas = troca[k]
            saida.extend(novas)
            k = fim + 1
            if not novas and saida and not saida[-1].strip() and k < len(linhas) and not linhas[k].strip():
                k += 1
            continue
        saida.append(linhas[k])
        k += 1
    return "\n".join(saida)


def enxugar(nome, teto=False, intervalos=None):
    """Grava o arquivo enxuto se a impressão não mudar. Devolve 'mudou', 'igual' ou 'recusado'."""
    p = Path(nome)
    try:
        texto = p.read_text(encoding="utf-8")
    except (UnicodeDecodeError, IsADirectoryError, FileNotFoundError):
        return "igual"
    novo = enxugar_texto(nome, texto, teto, intervalos)
    if novo == texto:
        return "igual"
    if codigo(nome, novo) != codigo(nome, texto):
        return "recusado"
    p.write_text(novo, encoding="utf-8")
    return "mudou"


def main(args):
    if not args:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    verbo, resto = args[0], args[1:]
    if verbo == "impressao":
        for nome in resto:
            soma, ling = impressao(nome)
            print(f"{soma}  {ling}  {nome}")
        return 0
    if verbo == "mostrar":
        for nome in resto:
            sys.stdout.write(codigo(nome, Path(nome).read_text(encoding="utf-8")))
        return 0
    if verbo == "enxugar":
        teto, intervalos = False, None
        while resto and resto[0].startswith("--"):
            if resto[0] == "--teto":
                teto = True
                resto = resto[1:]
            elif resto[0] == "--linhas":
                intervalos = [tuple(int(x) for x in r.split("-")) for r in resto[1].split(",") if r]
                resto = resto[2:]
            else:
                break
        rc = 0
        for nome in resto:
            r = enxugar(nome, teto, intervalos)
            if r != "igual":
                print(f"{r}  {nome}")
            if r == "recusado":
                rc = 1
        return rc
    print(__doc__.strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

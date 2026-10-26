#!/usr/bin/env python3
"""Comentários do código: a impressão sem eles e o corte deles.

Uso:
  comentarios.py impressao ARQUIVO...              sha256 do código sem comentários, um por linha
  comentarios.py mostrar ARQUIVO                   o código sem comentários, para diff
  comentarios.py zerar [--linhas A-B,...] ARQUIVO...
  comentarios.py conferir ARQUIVO...               lista quem ainda tem comentário, sem gravar

zerar tira todo comentário. Ficam o shebang, a licença (SPDX, Copyright), as
diretivas (shellcheck, noqa, type:, eslint, coding, compdef, OVERRIDE), a
marca que o código procura no arquivo (MEOW-...-N), o comentário condicional
do HTML, o cabeçalho que o script imprime de si com
sed -n 'A,Bp' "$0" e a docstring de módulo que o código lê por __doc__.
O modelo (*.modelo.*) é dado: o comentário dele vai para o app.
Com --linhas, só corta o que toca esses intervalos. Nunca grava um arquivo
cuja impressão mude: o código fica idêntico ou o arquivo fica como estava.
"""
import ast
import hashlib
import io
import re
import shutil
import subprocess
import sys
import tokenize
import warnings
from pathlib import Path


def linguagem_de(nome, texto):
    p = Path(nome)
    ext = p.suffix
    tabela = {".sh": "bash", ".bash": "bash", ".zsh": "bash", ".py": "python",
              ".js": "js", ".mjs": "js", ".rules": "js", ".jsonc": "js",
              ".css": "css", ".rs": "rust",
              ".html": "html", ".htm": "html", ".toml": "toml",
              ".service": "unidade", ".path": "unidade", ".timer": "unidade",
              ".socket": "unidade", ".target": "unidade",
              ".yml": "yaml", ".yaml": "yaml",
              ".patch": "patch", ".diff": "patch"}
    if ".modelo." in p.name:
        return "inteiro"
    if p.name in (".gitignore", ".gitattributes"):
        return "inicio"
    if ext in tabela:
        return tabela[ext]
    if p.name in ("series", "versao"):
        return "cerquilha"
    primeira = texto.split("\n", 1)[0]
    if primeira.startswith("#compdef"):
        return "bash"
    if primeira.startswith("#!"):
        if "python" in primeira:
            return "python"
        if re.search(r"\b(ba|z|da)?sh\b", primeira):
            return "bash"
    return "inteiro"


HEREDOC = re.compile(r"<<(-?)\s*(?:'([^']+)'|\"([^\"]+)\"|\\?([A-Za-z_][A-Za-z0-9_]*))")
DELIMITA = set(" \t;&|()<>")
PYTHON_NA_LINHA = re.compile(r"(?:^|[\s;&|(`])(?:\S*/)?python3?(?:\s|$)")


def spans_bash(texto):
    spans = []
    pilha = [["c", 0]]
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
            elif c == "<" and linha.startswith("<<<", j):
                j += 3
                continue
            elif c == "<" and linha.startswith("<<", j):
                m = HEREDOC.match(linha, j)
                if m:
                    citado = m.group(2) is not None or m.group(3) is not None
                    py = citado and m.group(1) != "-" and bool(PYTHON_NA_LINHA.search(linha[:j]))
                    pendentes.append((m.group(1) == "-", m.group(2) or m.group(3) or m.group(4), py))
                    j = m.end()
                    continue
            j += 1
        for traco, palavra, py in pendentes:
            corpo_ini = base
            while i < len(linhas):
                corpo = linhas[i]
                if (corpo.lstrip("\t") if traco else corpo) == palavra:
                    if py:
                        spans.extend((corpo_ini + a, corpo_ini + b, m)
                                     for a, b, m in spans_python(texto[corpo_ini:base]))
                    base += len(corpo) + 1
                    i += 1
                    break
                base += len(corpo) + 1
                i += 1
        pendentes = []
    return sorted(spans)


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


def spans_c(texto, linguagem, ini=0, fim=None):
    spans = []
    i, n = ini, len(texto) if fim is None else fim
    pilha = []
    ultimo = ""
    while i < n:
        c = texto[i]
        d = texto[i + 1] if i + 1 < n else ""
        if c == "/" and d == "/" and linguagem != "css":
            j = texto.find("\n", i, n)
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
            f = texto.find('"' + m.group(1), i + m.end())
            i = n if f < 0 else f + 1 + len(m.group(1))
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


def spans_inicio(texto):
    spans, base = [], 0
    for l in texto.split("\n"):
        if l.startswith("#"):
            spans.append((base, base + len(l), "#"))
        base += len(l) + 1
    return spans


def spans_unidade(texto):
    spans, base, continua = [], 0, False
    for l in texto.split("\n"):
        s = l.lstrip()
        if not continua and s[:1] in ("#", ";"):
            spans.append((base + len(l) - len(s), base + len(l), s[0]))
        else:
            continua = l.rstrip().endswith("\\")
        base += len(l) + 1
    return spans


def spans_yaml(texto):
    spans, base, bloco = [], 0, None
    for l in texto.split("\n"):
        s = l.lstrip()
        recuo = len(l) - len(s)
        if bloco is not None and (not s or recuo > bloco):
            base += len(l) + 1
            continue
        bloco = None
        if s.startswith("#"):
            spans.append((base + recuo, base + len(l), "#"))
        elif re.search(r"(?:^|:|-)\s*[|>][-+0-9]*\s*$", s):
            bloco = recuo
        base += len(l) + 1
    return spans


def spans_toml(texto):
    spans, i, n, aspas = [], 0, len(texto), None
    while i < n:
        c = texto[i]
        if aspas:
            if c == "\\" and aspas in ('"', '"""'):
                i += 2
                continue
            if texto.startswith(aspas, i):
                i += len(aspas)
                aspas = None
                continue
            i += 1
            continue
        if c in "\"'":
            aspas = c * 3 if texto.startswith(c * 3, i) else c
            i += len(aspas)
            continue
        if c == "#":
            j = texto.find("\n", i)
            j = n if j < 0 else j
            spans.append((i, j, "#"))
            i = j
            continue
        i += 1
    return spans


def spans_html(texto):
    spans = []
    i = 0
    abre = re.compile(r"<!--|<(script|style)\b[^>]*>", re.I)
    while True:
        m = abre.search(texto, i)
        if not m:
            break
        if m.group(0) == "<!--":
            f = texto.find("-->", m.end())
            f = len(texto) if f < 0 else f + 3
            spans.append((m.start(), f, "<!--"))
            i = f
            continue
        tag = m.group(1).lower()
        f = re.compile(rf"</{tag}\s*>", re.I).search(texto, m.end())
        f = len(texto) if not f else f.start()
        spans.extend(spans_c(texto, "js" if tag == "script" else "css", m.end(), f))
        i = f
    return spans


def spans_de(linguagem, texto):
    return {"bash": spans_bash, "python": spans_python, "cerquilha": spans_cerquilha,
            "inicio": spans_inicio, "unidade": spans_unidade, "yaml": spans_yaml,
            "toml": spans_toml, "html": spans_html,
            "js": lambda t: spans_c(t, "js"), "css": lambda t: spans_c(t, "css"),
            "rust": lambda t: spans_c(t, "rust")}.get(linguagem, lambda t: [])(texto)


DIRETIVA = re.compile(r"^\s*(?:shellcheck\s|(?i:noqa)\b|type:\s|pylint:|-\*-|fmt:\s|pragma:?\s|eslint|@ts-|"
                      r"vim?:|ex:|SPDX-|[Cc]opyright\b|©|\([Cc]\)\s+\d{4}|prettier-ignore|istanbul\s|jshint\b|jscs:|"
                      r"@license\b|@preserve\b|compdef\b|autoload\b|OVERRIDE\b|coding[:=]|MEOW(?:-[A-Z0-9]+)+-\d+\b)")
DIRETIVA_BLOCO_JS = re.compile(r"^\s*(?:global|exported)\s+\w")


def miolo(texto, a, b, marca):
    corpo = texto[a:b]
    if marca == "/*":
        return corpo[2:-2].lstrip("*!")
    if marca == "<!--":
        return corpo[4:-3]
    return corpo[len(marca):]


def linhas_de_ajuda(texto):
    saida = set()
    for m in re.finditer(r"sed -n '(\d+),(\d+)p' \"\$(?:0|\{BASH_SOURCE\[0\]\})\"", texto):
        saida.update(range(int(m.group(1)) - 1, int(m.group(2))))
    return saida


def mantem(ling, texto, a, b, marca, ajuda, linha):
    m = miolo(texto, a, b, marca)
    if DIRETIVA.match(m):
        return True
    if marca == "/*" and DIRETIVA_BLOCO_JS.match(m):
        return True
    if marca == "<!--" and (m.startswith("[if") or m.startswith("<![endif]") or m.endswith("<![endif]")):
        return True
    if ling == "bash" and linha in ajuda:
        return True
    return False


CURTA = re.compile(r"^#\s*(?:shellcheck(?:\s+\w+=\S+)+|noqa(?::\s*\w+(?:\s*,\s*\w+)*)?|OVERRIDE|MEOW(?:-[A-Z0-9]+)+-\d+\b)")


def diretiva_curta(comentario):
    m = CURTA.match(comentario)
    return m.group(0) if m else None


def doc_usada(arvore):
    modulo = any(isinstance(n, ast.Name) and n.id == "__doc__" for n in ast.walk(arvore))
    nomes = {n.value.id for n in ast.walk(arvore)
             if isinstance(n, ast.Attribute) and n.attr == "__doc__" and isinstance(n.value, ast.Name)}
    return modulo, nomes


def e_texto_solto(st):
    return isinstance(st, ast.Expr) and isinstance(st.value, ast.Constant) and isinstance(st.value.value, str)


CAMPOS = ("body", "orelse", "finalbody")


def textos_soltos(arvore):
    modulo, nomes = doc_usada(arvore)
    saida = []
    for no in ast.walk(arvore):
        for campo in CAMPOS:
            lista = getattr(no, campo, None)
            if not isinstance(lista, list) or not lista or not isinstance(lista[0], ast.stmt):
                continue
            fica_doc = (isinstance(no, ast.Module) and modulo) or \
                (isinstance(no, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) and no.name in nomes)
            sai = [k for k, st in enumerate(lista)
                   if e_texto_solto(st) and not (k == 0 and campo == "body" and fica_doc)]
            if sai:
                saida.append((lista, sai))
    return saida


def ast_sem_textos_soltos(texto):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        arvore = ast.parse(texto)
    for lista, sai in textos_soltos(arvore):
        resto = [st for k, st in enumerate(lista) if k not in sai]
        lista[:] = resto or [ast.Pass()]
    return ast.dump(arvore, include_attributes=False)


def fim_do_corte(texto, a, b):
    if a == 0 or texto[a - 1] in " \t\n":
        while b < len(texto) and texto[b] in " \t":
            b += 1
    return b


def linhas_limpas(texto):
    return "\n".join(l.rstrip() for l in texto.split("\n") if l.strip()) + "\n"


def codigo(nome, texto):
    ling = linguagem_de(nome, texto)
    if ling == "python":
        try:
            return ast_sem_textos_soltos(texto) + "\n"
        except SyntaxError:
            return texto
    if ling in ("patch", "inteiro"):
        return texto
    partes, ult = [], 0
    for a, b, _ in spans_de(ling, texto):
        b = fim_do_corte(texto, a, b)
        partes.append(texto[ult:a])
        partes.append("\n" * texto.count("\n", a, b))
        ult = b
    partes.append(texto[ult:])
    return linhas_limpas("".join(partes))


def canonico_bash(texto, zsh=False):
    exe = shutil.which("zsh" if zsh else "bash")
    if not exe:
        return None
    if zsh:
        prog = "__meow_f() {\n" + texto + "\n}\nfunctions __meow_f\n"
        cmd = [exe, "-f", "-s"]
    else:
        prog = "shopt -s extglob\n__meow_f() {\n" + texto + "\n}\ndeclare -f __meow_f\n"
        cmd = [exe, "--norc", "--noprofile", "-s"]
    try:
        r = subprocess.run(cmd, input=prog.encode("utf-8"), capture_output=True, timeout=60,
                           env={"PATH": "/nonexistent", "LC_ALL": "C.UTF-8"})
    except (OSError, subprocess.TimeoutExpired):
        return None
    if r.returncode != 0 or not r.stdout:
        return None
    return codigo("x.sh", r.stdout.decode("utf-8", "surrogateescape"))


def impressao(nome):
    try:
        texto = Path(nome).read_text(encoding="utf-8")
    except (UnicodeDecodeError, IsADirectoryError):
        return hashlib.sha256(Path(nome).read_bytes()).hexdigest(), "binario"
    return hashlib.sha256(codigo(nome, texto).encode("utf-8")).hexdigest(), linguagem_de(nome, texto)


def coluna(linha, bytes_):
    return len(linha.encode("utf-8")[:bytes_].decode("utf-8", "ignore"))


def zerar_texto(nome, texto, intervalos=None):
    ling = linguagem_de(nome, texto)
    if ling in ("inteiro", "patch"):
        return texto, None
    linhas = texto.split("\n")
    inicio = [0]
    for l in linhas:
        inicio.append(inicio[-1] + len(l) + 1)

    def linha_de(off):
        lo, hi = 0, len(linhas)
        while lo < hi:
            m = (lo + hi) // 2
            if inicio[m + 1] <= off:
                lo = m + 1
            else:
                hi = m
        return lo

    def toca(a, b):
        return intervalos is None or any(a <= y and x <= b for x, y in intervalos)
    ajuda = linhas_de_ajuda(texto) if ling == "bash" else set()
    cortes = []
    for a, b, marca in spans_de(ling, texto):
        la, lb = linha_de(a), linha_de(max(a, b - 1))
        if not toca(la + 1, lb + 1):
            continue
        if mantem(ling, texto, a, b, marca, ajuda, la):
            curto = diretiva_curta(texto[a:b]) if la not in ajuda else None
            if curto and curto != texto[a:b]:
                cortes.append((a, b, curto))
            continue
        antes = texto[inicio[la]:a]
        depois = texto[b:inicio[lb + 1] - 1] if lb + 1 < len(inicio) else texto[b:]
        if antes.strip() and depois.strip() and not antes[-1:].isspace() and not depois[:1].isspace():
            return texto, f"linha {la + 1}: o comentário cola dois pedaços de código"
        cortes.append((a, fim_do_corte(texto, a, b), ""))
    if ling == "python":
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                arvore = ast.parse(texto)
        except SyntaxError as e:
            return texto, f"não compila: {e.msg}"
        for lista, sai in textos_soltos(arvore):
            sobra = len(sai) == len(lista)
            for k in sai:
                st = lista[k]
                la, lb = st.lineno - 1, st.end_lineno - 1
                if not toca(la + 1, lb + 1):
                    sobra = False
                    continue
                ca, cb = coluna(linhas[la], st.col_offset), coluna(linhas[lb], st.end_col_offset)
                antes = linhas[la][:ca]
                depois = linhas[lb][cb:]
                if antes.strip() or (depois.strip() and not depois.strip().startswith("#")):
                    return texto, f"linha {la + 1}: a docstring divide a linha com código"
                a = inicio[la] + ca
                b = inicio[lb] + cb
                troca = "pass" if sobra and k == sai[0] else ""
                cortes.append((a, b, troca))
    if not cortes:
        return texto, None
    cortes.sort()
    MARCA = "\x00"
    partes, ult = [], 0
    for a, b, troca in cortes:
        if a < ult:
            continue
        partes.append(texto[ult:a])
        partes.append((troca or MARCA) + ("\n" + MARCA) * texto.count("\n", a, b))
        ult = b
    partes.append(texto[ult:])
    meio = "".join(partes).split("\n")
    saida = []
    for l in meio:
        if MARCA in l:
            limpa = l.replace(MARCA, "")
            if not limpa.strip():
                saida.append(None)
            else:
                saida.append(limpa.rstrip() if l.rstrip().endswith(MARCA) else limpa)
        else:
            saida.append(l)
    final = []
    k = 0
    while k < len(saida):
        if saida[k] is not None:
            final.append(saida[k])
            k += 1
            continue
        while k < len(saida) and saida[k] is None:
            k += 1
        seguinte_vazia = k < len(saida) and saida[k] is not None and not saida[k].strip()
        anterior_vazia = bool(final) and not final[-1].strip()
        if seguinte_vazia and (anterior_vazia or not final):
            k += 1
        elif anterior_vazia and k >= len(saida):
            final.pop()
    return "\n".join(final), None


FORA = re.compile(r"(?:^|/)(?:patches|upstream|vendor|Sleek)/|^packs/[^/]+/icones/|^docs/(?:sprints|historico)/|"
                  r"\.(?:patch|diff|svg|original)$|(?:^|/)(?:LICEN[CS]E|License)|(?:^|/)Cargo\.lock$")
GERADO = re.compile(r"\b(?:[Gg]erado|GERADO|@generated)\b|[Nn]ão edite")


def fora_do_corte(nome, texto):
    return bool(FORA.search(nome)) or bool(GERADO.search("\n".join(texto.split("\n", 3)[:3])))


def zerar(nome, intervalos=None, gravar=True):
    p = Path(nome)
    try:
        texto = p.read_text(encoding="utf-8")
    except (UnicodeDecodeError, IsADirectoryError, FileNotFoundError):
        return "igual"
    if fora_do_corte(nome, texto):
        return "igual"
    novo, motivo = zerar_texto(nome, texto, intervalos)
    if motivo:
        return f"recusado: {motivo}"
    if novo == texto:
        return "igual"
    if codigo(nome, novo) != codigo(nome, texto):
        return "recusado: a impressão mudaria"
    ling = linguagem_de(nome, texto)
    if ling == "bash":
        zsh = texto.startswith("#compdef") or nome.endswith(".zsh") or texto.split("\n", 1)[0].endswith("zsh")
        antes = canonico_bash(texto, zsh)
        if antes is not None and canonico_bash(novo, zsh) != antes:
            return "recusado: o shell relê o código diferente"
    if gravar:
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
    if verbo in ("zerar", "conferir"):
        intervalos = None
        if resto[:1] == ["--linhas"]:
            intervalos = [tuple(int(x) for x in r.split("-")) for r in resto[1].split(",") if r]
            resto = resto[2:]
        rc = 0
        for nome in resto:
            r = zerar(nome, intervalos, verbo == "zerar")
            if r == "igual":
                continue
            estado = r.split(":")[0]
            if verbo == "conferir" and estado == "mudou":
                estado = "comentario"
            print(f"{estado}  {nome}{r[len(r.split(':')[0]):]}")
            if verbo == "conferir" or estado == "recusado":
                rc = 1
        return rc
    print(__doc__.strip(), file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

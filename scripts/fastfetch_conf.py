#!/usr/bin/env python3
# fastfetch_conf.py — lê e escreve o config.jsonc do fastfetch: o módulo `title`
# e o bloco `logo` (fonte, tipo e padding).
#
# POR QUE ELE É UM ARQUIVO, E NÃO UM HEREDOC DENTRO DO `fastfetch_logo.sh`
# Porque o heredoc me custou o arquivo dela.
#
# { "type": { "type": "title", "format": "…" }, "format": "…" },
#
# O backup que a GUARDA 2 do `fastfetch_logo.sh` tira antes de toda escrita
# devolveu o arquivo intacto — é exatamente para isso que ela existe.
#
# Duas rotinas de varredura de JSONC em duas linguagens divergiriam de novo.
#
#   "title"                                   a forma curta, que era a dela
#   { "type": "title", "format": "…" }        a forma longa, com o formato

# Nenhuma função daqui cria chave no arquivo de ninguém: só ajusta as que já existem.
import json
import os
import re
import sys
import tempfile


# --- a máscara ---------------------------------------------------------------
def mascarar(bruto):
    """Cópia do MESMO comprimento com todo comentário virado espaço.

    O `\n` de um `//` fica de pé: apagá-lo juntaria duas linhas na máscara e
    deslocaria índice nenhum, mas confundiria qualquer busca ancorada em linha.
    """
    saida = list(bruto)
    i, n = 0, len(bruto)
    while i < n:
        c = bruto[i]
        if c == '"':
            i = _fim_da_string(bruto, i) + 1
        elif c == "/" and i + 1 < n and bruto[i + 1] == "/":
            while i < n and bruto[i] != "\n":
                saida[i] = " "
                i += 1
        elif c == "/" and i + 1 < n and bruto[i + 1] == "*":
            saida[i] = saida[i + 1] = " "
            i += 2
            while i < n and not (bruto[i] == "*" and i + 1 < n and bruto[i + 1] == "/"):
                if bruto[i] != "\n":
                    saida[i] = " "
                i += 1
            if i < n:
                saida[i] = " "
                if i + 1 < n:
                    saida[i + 1] = " "
                i += 2
        else:
            i += 1
    return "".join(saida)


def _sem_comentarios(bruto):
    """O texto pronto para o `json.loads`: comentário fora, vírgula solta fora."""
    limpo = mascarar(bruto)
    limpo = re.sub(r",(\s*[}\]])", r"\1", limpo)
    return limpo


def jsonc_valido(texto):
    """O resultado ainda é um JSONC que o fastfetch abre? Vale a leitura extra.

    O arquivo é de outro projeto e tem commit automático: gravar sem conferir é
    o caro. Um `{` desemparelhado dentro de um comentário já truncou este
    arquivo uma vez — a máscara cura a causa, isto pega a próxima."""
    try:
        json.loads(_sem_comentarios(texto))
        return True
    except Exception:
        return False


def _fim_da_string(texto, i):
    """O índice da aspas que FECHA a string que abre em `i`."""
    j = i + 1
    n = len(texto)
    while j < n:
        if texto[j] == "\\":
            j += 2
            continue
        if texto[j] == '"':
            return j
        j += 1
    return n - 1


def _bloco(mascara, abre):
    """O índice do `}` (ou `]`) que fecha o que abre em `abre`, ou None.

    Devolver None quando a profundidade nunca volta a zero é a diferença entre
    "não achei" e "vai até o fim do arquivo" — e a segunda hipótese, tomada como
    verdade, apagava do módulo até o último byte."""
    fecha = {"{": "}", "[": "]"}[mascara[abre]]
    prof, j, n = 0, abre, len(mascara)
    while j < n:
        c = mascara[j]
        if c == '"':
            j = _fim_da_string(mascara, j)
        elif c in "{[":
            prof += 1
        elif c in "}]":
            prof -= 1
            if prof == 0:
                return j if c == fecha else None
        j += 1
    return None


# --- o módulo `title` --------------------------------------------------------
def acha_title(bruto):
    """(inicio, fim, formato) do módulo `title`, ou None.

    `formato` é None quando o módulo está na forma curta.

    A VARREDURA CONTA CHAVES DE VERDADE, e não é frescura: o valor que se
    escreve ali é `{full-user-name} @ {host-name-colored}` — ele TEM chaves
    dentro. Um `\\{[^{}]*"type"\\s*:\\s*"title"[^{}]*\\}` (a primeira versão)
    para de casar assim que o formato entra, e o conferir da passagem seguinte
    deixa de reconhecer o que a passagem anterior escreveu: o `doctor` passaria
    a acusar divergência todo dia sobre um arquivo que está certo.

    E ela roda na MÁSCARA, não no texto cru — o porquê está no cabeçalho.
    """
    m_texto = mascarar(bruto)
    n = len(m_texto)
    fim_mods = None

    # O array `modules` delimita a busca, como sempre esteve escrito aqui e
    # nunca esteve feito: um `"title"` solto num comentário de cabeçalho, ou uma
    # string `"title"` dentro de outro módulo, não é o módulo dela.
    m_mods = re.search(r'"modules"\s*:\s*\[', m_texto)
    if m_mods:
        ini_mods = m_mods.end() - 1
        fim_mods = _bloco(m_texto, ini_mods)
    else:
        ini_mods = 0

    def dentro(i):
        return fim_mods is None or ini_mods <= i <= fim_mods

    for m in re.finditer(r'"type"\s*:\s*"title"', m_texto):
        if not dentro(m.start()):
            continue
        # Sobe até o `{` deste objeto. Chaves dentro de string não contam, e é
        # por isso que se anda para trás pulando strings inteiras.
        i, prof, abre = m.start() - 1, 0, None
        while i >= 0:
            c = m_texto[i]
            if c == '"':
                i -= 1
                while i >= 0:
                    if m_texto[i] == '"' and (i == 0 or m_texto[i - 1] != "\\"):
                        break
                    i -= 1
            elif c == "}":
                prof += 1
            elif c == "{":
                if prof == 0:
                    abre = i
                    break
                prof -= 1
            i -= 1
        # TRAVA DE SANIDADE: o `{` da raiz não é um módulo. Nenhuma passagem
        # deste código pode legitimamente trocar o arquivo inteiro, e é
        # exatamente isso que acontecia quando a subida não achava abertura.
        if abre is None or abre == 0 or not dentro(abre):
            continue
        j = _bloco(m_texto, abre)
        if j is None:
            continue
        corpo = bruto[abre:j + 1]
        f = re.search(r'"format"\s*:\s*"((?:[^"\\]|\\.)*)"', mascarar(corpo))
        formato = json.loads('"%s"' % f.group(1)) if f else ""
        return (abre, j + 1, formato)

    # Nenhum objeto: procura a forma curta DENTRO do array `modules`.
    trecho = m_texto[ini_mods:fim_mods + 1] if fim_mods is not None else m_texto
    curta = re.search(r'(^|[\[,\s])("title")\s*(?=,|\])', trecho)
    if not curta:
        return None
    base = ini_mods if fim_mods is not None else 0
    return (base + curta.start(2), base + curta.end(2), None)


def ler(caminho):
    bruto = open(caminho, encoding="utf-8").read()
    achado = acha_title(bruto)
    if achado is None:
        print('não achei o módulo "title" no config.jsonc', file=sys.stderr)
        return 2
    print(achado[2] or "")
    return 0


def escrever(caminho, querido):
    bruto = open(caminho, encoding="utf-8").read()
    achado = acha_title(bruto)
    if achado is None:
        print('não achei o módulo "title" no config.jsonc', file=sys.stderr)
        return 2
    ini, fim, formato = achado
    if (formato or "") == querido:
        return 0
    if formato is None and not querido:
        return 0

    # `json.dumps` de uma string só: é ele que escapa aspas, barras e acentos do
    # jeito que o JSON pede. Montar isso com `replace` seria a segunda rotina de
    # escape deste projeto, e a primeira a errar num caso esquisito.
    novo = ('{ "type": "title", "format": %s }' % json.dumps(querido, ensure_ascii=False)) \
        if querido else '"title"'
    saida = bruto[:ini] + novo + bruto[fim:]
    if saida == bruto:
        return 0
    if not _gravar(caminho, saida):
        return 2

    # RECONFERIR EM VEZ DE ASSUMIR — o mesmo que a `cmd_aplicar` já faz com o
    # `logo.source`. Quem anuncia "escrevi" para a pessoa é o shell, e ele
    # anunciava em cima do rc; o rc agora só é 1 se o disco concordar.
    de_volta = acha_title(open(caminho, encoding="utf-8").read())
    if de_volta is None or (de_volta[2] or "") != querido:
        print("escrevi e reli, e o título de volta não é o pedido", file=sys.stderr)
        return 2
    return 1


# --- o bloco `logo` ----------------------------------------------------------
def _acha_logo(bruto):
    """(inicio, fim) do objeto que é o VALOR da chave `logo`, ou None."""
    m_texto = mascarar(bruto)
    for m in re.finditer(r'"logo"\s*:\s*\{', m_texto):
        abre = m.end() - 1
        fim = _bloco(m_texto, abre)
        if fim is not None:
            return (abre, fim)
    return None


def _valor_de(m_texto, abre, fim, chave):
    """(inicio, fim) do VALOR de `chave` no primeiro nível do objeto, ou None."""
    prof, i, n = 0, abre, min(fim + 1, len(m_texto))
    while i < n:
        c = m_texto[i]
        if c == '"':
            j = _fim_da_string(m_texto, i)
            if prof == 1 and m_texto[i:j + 1] == '"%s"' % chave:
                k = j + 1
                while k < n and (m_texto[k].isspace() or m_texto[k] == ":"):
                    k += 1
                if k < n:
                    if m_texto[k] == '"':
                        return (k, _fim_da_string(m_texto, k) + 1)
                    m_num = re.match(r"-?\d+", m_texto[k:n])
                    if m_num:
                        return (k, k + m_num.end())
                return None
            i = j + 1
            continue
        if c in "{[":
            prof += 1
        elif c in "}]":
            prof -= 1
        i += 1
    return None


def ler_logo(caminho):
    bruto = open(caminho, encoding="utf-8").read()
    achado = _acha_logo(bruto)
    if achado is None:
        print('não achei a chave "logo" no config.jsonc', file=sys.stderr)
        return 2
    abre, fim = achado
    m_texto = mascarar(bruto)
    campos = []
    for chave in ("type", "source"):
        pos = _valor_de(m_texto, abre, fim, chave)
        campos.append(bruto[pos[0]:pos[1]].strip('"') if pos else "-")
    pad = _valor_de(m_texto, abre, fim, "padding")
    for chave in ("top", "right"):
        pos = None
        if pad is None:
            m_pad = re.search(r'"padding"\s*:\s*\{', m_texto[abre:fim + 1])
            if m_pad:
                p_abre = abre + m_pad.end() - 1
                p_fim = _bloco(m_texto, p_abre)
                if p_fim is not None:
                    pos = _valor_de(m_texto, p_abre, p_fim, chave)
        campos.append(bruto[pos[0]:pos[1]] if pos else "-")
    print("\t".join(campos))
    return 0


def escrever_logo(caminho, fonte, topo, recuo):
    bruto = open(caminho, encoding="utf-8").read()
    achado = _acha_logo(bruto)
    if achado is None:
        print('não achei a chave "logo" no config.jsonc', file=sys.stderr)
        return 2
    abre, fim = achado
    m_texto = mascarar(bruto)

    trocas = []
    pos = _valor_de(m_texto, abre, fim, "source")
    if pos is None:
        print('não achei logo.source dentro do bloco "logo"', file=sys.stderr)
        return 2
    trocas.append((pos, json.dumps(fonte, ensure_ascii=False)))
    pos = _valor_de(m_texto, abre, fim, "type")
    if pos:
        trocas.append((pos, '"file-raw"'))

    # O PADDING SÓ MUDA SE JÁ EXISTIR: esta função não cria chave no arquivo de
    # ninguém. E `auto` chega aqui como palavra — não é número, não mexe.
    m_pad = re.search(r'"padding"\s*:\s*\{', m_texto[abre:fim + 1])
    if m_pad:
        p_abre = abre + m_pad.end() - 1
        p_fim = _bloco(m_texto, p_abre)
        if p_fim is not None:
            for chave, valor in (("top", topo), ("right", recuo)):
                if not valor.lstrip("-").isdigit():
                    continue
                pos = _valor_de(m_texto, p_abre, p_fim, chave)
                if pos:
                    trocas.append((pos, valor))

    # De trás para a frente: mexer no começo primeiro deslocaria os índices do
    # que vem depois.
    saida = bruto
    for (ini, fim_t), novo in sorted(trocas, key=lambda t: -t[0][0]):
        saida = saida[:ini] + novo + saida[fim_t:]
    if saida == bruto:
        return 0
    if not _gravar(caminho, saida):
        return 2
    return 1


# --- a gravação, uma só ------------------------------------------------------
def _gravar(caminho, saida):
    """Confere que ainda é JSONC e troca o arquivo de uma vez. False = não deu.

    O temporário nasce no diretório de DESTINO, e o `os.replace` vira rename no
    mesmo sistema de arquivos. Aqui isso vale dobrado: o destino é alvo de um
    `git add` automático a cada dez minutos, e um arquivo pela metade seria
    commitado quebrado."""
    if not jsonc_valido(saida):
        print("o resultado não seria JSONC válido — não vou gravar", file=sys.stderr)
        return False
    real = os.path.realpath(caminho)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(real), prefix=".meow-ffc.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(saida)
        os.chmod(tmp, 0o644)
        os.replace(tmp, real)
    except Exception:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise
    return True


def main(argv):
    # TODA EXCEÇÃO VIRA 2, e é a diferença entre um aviso certo e uma mentira: o
    # Python que morre por conta própria sai com 1, e 1 é o código de "mudei" —
    # o shell anunciava "escrevi no config.jsonc da Aurora" com o arquivo
    # intacto.
    try:
        if len(argv) >= 3 and argv[1] == "ler-titulo":
            return ler(argv[2])
        if len(argv) >= 3 and argv[1] == "escrever-titulo":
            return escrever(argv[2], argv[3] if len(argv) > 3 else "")
        if len(argv) >= 3 and argv[1] == "ler-logo":
            return ler_logo(argv[2])
        if len(argv) >= 6 and argv[1] == "escrever-logo":
            return escrever_logo(argv[2], argv[3], argv[4], argv[5])
    except Exception as erro:
        print("%s: %s" % (type(erro).__name__, erro), file=sys.stderr)
        return 2
    print("uso: fastfetch_conf.py {ler-titulo|escrever-titulo|ler-logo|escrever-logo}"
          " <config.jsonc> [args]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

#!/usr/bin/env python3
# fastfetch_conf.py — lê e escreve o módulo `title` do config.jsonc do fastfetch.
#
# POR QUE ELE É UM ARQUIVO, E NÃO UM HEREDOC DENTRO DO `fastfetch_logo.sh`
#   Porque o heredoc me custou o arquivo dela. A primeira versão deste código
#   morava num `python3 - <<'PY'` no meio do shell, e para passar por lá cada
#   barra invertida do Python virava duas, cada aspas virava três. Ao trocar o
#   heredoc de aspas simples para sem aspas — para poder interpolar uma variável
#   — as CRASES dos comentários em português viraram substituição de comando, e
#   um `\{` mal escapado desalinhou a varredura de chaves. O resultado foi
#   gravado no `~/.config/fastfetch/config.jsonc`:
#
#       { "type": { "type": "title", "format": "…" }, "format": "…" },
#
#   O backup que a GUARDA 2 do `fastfetch_logo.sh` tira antes de toda escrita
#   devolveu o arquivo intacto — é exatamente para isso que ela existe. Mas o
#   defeito não foi de lógica: foi de CAMADA. Código que precisa contar aspas
#   não deve morar dentro de outra linguagem, e a correção certa não é escapar
#   melhor, é sair de lá.
#
# O QUE ELE FAZ, E O QUE NÃO FAZ
#   Só o módulo `title`. O `logo.source`, o `logo.type` e o `padding` continuam
#   no `fastfetch_logo.sh`, onde já estavam funcionando — mover código que
#   funciona é risco sem ganho.
#
#   Ele NÃO reserializa o JSON. Um `json.dump` mataria os comentários (o arquivo
#   é JSONC), a ordem das chaves e a indentação dela — e o arquivo vive num
#   repositório com commit automático a cada dez minutos, então o diff seria o
#   arquivo inteiro reescrito por causa de um enfeite. O que se faz aqui é
#   trocar UM intervalo de bytes.
#
# AS DUAS FORMAS DO MÓDULO, E POR QUE AS DUAS IMPORTAM
#   "title"                                   a forma curta, que era a dela
#   { "type": "title", "format": "…" }        a forma longa, com o formato
#
#   Ir da curta para a longa é pôr um título próprio; voltar é apagar a chave
#   `FASTFETCH_TITULO` do meow.conf. Nada aqui é de mão única.
#
# USO
#   fastfetch_conf.py ler-titulo    <config.jsonc>
#       imprime o formato em vigor. Sai 0 com formato, 0 com linha vazia quando
#       o módulo está na forma curta, e 2 quando não há módulo `title` nenhum.
#
#   fastfetch_conf.py escrever-titulo <config.jsonc> <formato>
#       põe o formato (ou volta à forma curta, com formato vazio).
#       Sai 0 quando não havia nada a mudar, 1 quando mudou, 2 quando não deu.

import json
import os
import re
import sys
import tempfile


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


def acha_title(bruto):
    """(inicio, fim, formato) do módulo `title`, ou None.

    `formato` é None quando o módulo está na forma curta.

    A VARREDURA CONTA CHAVES DE VERDADE, e não é frescura: o valor que se
    escreve ali é `{full-user-name} @ {host-name-colored}` — ele TEM chaves
    dentro. Um `\\{[^{}]*"type"\\s*:\\s*"title"[^{}]*\\}` (a primeira versão)
    para de casar assim que o formato entra, e o conferir da passagem seguinte
    deixa de reconhecer o que a passagem anterior escreveu: o `doctor` passaria
    a acusar divergência todo dia sobre um arquivo que está certo.
    """
    n = len(bruto)

    # 1. Onde há `"type": "title"` FORA de comentário e de string? A varredura
    #    de strings acontece de qualquer jeito abaixo; aqui basta achar o
    #    candidato e confirmar subindo até a chave que o abre.
    for m in re.finditer(r'"type"\s*:\s*"title"', bruto):
        # 2. Sobe até o `{` deste objeto. Chaves dentro de string não contam, e
        #    é por isso que se anda para trás pulando strings inteiras.
        i, prof, abre = m.start() - 1, 0, None
        while i >= 0:
            c = bruto[i]
            if c == '"':
                # o fim de uma string: anda até a aspas que a abriu
                i -= 1
                while i >= 0:
                    if bruto[i] == '"' and (i == 0 or bruto[i - 1] != "\\"):
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
        if abre is None:
            continue

        # 3. E desce até o `}` que o fecha.
        j, prof = abre, 0
        while j < n:
            c = bruto[j]
            if c == '"':
                j = _fim_da_string(bruto, j)
            elif c == "{":
                prof += 1
            elif c == "}":
                prof -= 1
                if prof == 0:
                    break
            j += 1
        corpo = bruto[abre:j + 1]
        f = re.search(r'"format"\s*:\s*"((?:[^"\\]|\\.)*)"', corpo)
        formato = json.loads('"%s"' % f.group(1)) if f else ""
        return (abre, j + 1, formato)

    # 4. Nenhum objeto: procura a forma curta dentro do array `modules`.
    curta = re.search(r'(^|[\[,\s])("title")\s*(?=,|\])', bruto)
    return (curta.start(2), curta.end(2), None) if curta else None


def ler(caminho):
    try:
        bruto = open(caminho, encoding="utf-8").read()
    except OSError as erro:
        print(erro, file=sys.stderr)
        return 2
    achado = acha_title(bruto)
    if achado is None:
        print("não achei o módulo \"title\" no config.jsonc", file=sys.stderr)
        return 2
    print(achado[2] or "")
    return 0


def escrever(caminho, querido):
    try:
        bruto = open(caminho, encoding="utf-8").read()
    except OSError as erro:
        print(erro, file=sys.stderr)
        return 2
    achado = acha_title(bruto)
    if achado is None:
        print("não achei o módulo \"title\" no config.jsonc", file=sys.stderr)
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

    # O temporário nasce no diretório de DESTINO, e o `os.replace` vira rename no
    # mesmo sistema de arquivos. Aqui isso vale dobrado: o destino é alvo de um
    # `git add` automático a cada dez minutos, e um arquivo pela metade seria
    # commitado quebrado.
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
    return 1


def main(argv):
    if len(argv) >= 3 and argv[1] == "ler-titulo":
        return ler(argv[2])
    if len(argv) >= 3 and argv[1] == "escrever-titulo":
        return escrever(argv[2], argv[3] if len(argv) > 3 else "")
    print("uso: fastfetch_conf.py {ler-titulo|escrever-titulo} <config.jsonc> [formato]",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))

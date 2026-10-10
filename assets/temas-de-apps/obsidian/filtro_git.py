#!/usr/bin/env python3
"""filtro_git.py — o tema do Obsidian desta máquina num cofre versionado em git.

P74 item 8 (T2 do 01-regressoes.md), 09/10/2026.

O DEFEITO, MEDIDO
    O cofre dela é um repositório git, e o `.obsidian/appearance.json` está nele,
    com `"cssTheme": "Catppuccin"` no HEAD. O módulo do Obsidian punha o tema do
    pack no ar no arquivo do disco, e qualquer operação de git que reescreve a
    árvore (um checkout, um stash, um pull da outra máquina) o devolvia ao do
    HEAD. O doctor.log tem dez trocas `cssTheme='Catppuccin' -> 'Dracula
    Official'`, de 28/09 a 09/10: o conserto refeito a cada passada, e nunca
    ficando. E o caminho inverso também brigava: um commit feito nesta máquina
    levaria o tema dela para o cofre de quem usa o outro.

A CURA É O GIT SABER QUE ESSE VALOR É DA MÁQUINA
    Um filtro de conteúdo (`gitattributes`, "filter"), declarado só no
    `.git/info/attributes` e no `.git/config` do cofre — nada versionado:
      vestir   (smudge, o que o git escreve no disco) põe no `cssTheme` o tema
               desta máquina, guardado em `git config meow.obsidian-tema`;
      limpar   (clean, o que o git guarda) devolve ao `cssTheme` o valor do
               índice (ou do HEAD), o do cofre.
    Assim todo checkout, stash ou pull escreve o tema desta máquina, e nenhum
    commit leva o tema dela para o cofre: o `git status` não vê mudança só de
    tema, e não há o que reverter.

SÓ O VALOR DO `cssTheme` MUDA, POR TEXTO
    O resto do arquivo passa byte a byte: reescrever o JSON inteiro trocaria a
    ordem e o espaçamento que o Obsidian usa, e o `git diff` acusaria o arquivo
    inteiro. O fim de linha final segue o do cofre, porque o módulo grava sem
    `\\n` (como o Obsidian) e o HEAD dela tem um.

Sem `meow.obsidian-tema`, ou sem `cssTheme` no conteúdo, o filtro devolve o que
recebeu: um filtro que falha não pode estragar o arquivo de ninguém.
"""
import json
import re
import subprocess
import sys

RE_TEMA = re.compile(r'("cssTheme"\s*:\s*)"((?:[^"\\]|\\.)*)"')


def _git(*args):
    r = subprocess.run(["git", *args], capture_output=True)
    return r.stdout.decode("utf-8", "replace") if r.returncode == 0 else None


def _trocar(texto, valor):
    if valor is None or not RE_TEMA.search(texto):
        return texto
    escrito = json.dumps(valor, ensure_ascii=False)
    return RE_TEMA.sub(lambda m: m.group(1) + escrito, texto, count=1)


def vestir(texto):
    tema = _git("config", "--get", "meow.obsidian-tema")
    return _trocar(texto, tema.rstrip("\n") if tema else None)


def limpar(texto, caminho):
    do_cofre = _git("cat-file", "blob", ":" + caminho) or _git("cat-file", "blob", "HEAD:" + caminho)
    if do_cofre is None:
        return texto
    achado = RE_TEMA.search(do_cofre)
    if not achado:
        return texto
    saida = _trocar(texto, json.loads('"' + achado.group(2) + '"'))
    # O fim do arquivo segue o do cofre: com ou sem a quebra de linha final.
    if do_cofre.endswith("\n") and not saida.endswith("\n"):
        saida += "\n"
    elif not do_cofre.endswith("\n") and saida.endswith("\n"):
        saida = saida.rstrip("\n")
    return saida


def main(argv):
    texto = sys.stdin.buffer.read().decode("utf-8", "surrogateescape")
    if len(argv) == 2 and argv[1] == "vestir":
        saida = vestir(texto)
    elif len(argv) == 3 and argv[1] == "limpar":
        saida = limpar(texto, argv[2])
    else:
        sys.stderr.write("uso: filtro_git.py vestir | limpar <caminho>\n")
        sys.stdout.buffer.write(texto.encode("utf-8", "surrogateescape"))
        return 2
    sys.stdout.buffer.write(saida.encode("utf-8", "surrogateescape"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

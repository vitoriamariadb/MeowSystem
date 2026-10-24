#!/usr/bin/env python3
"""modelo.py — o MODELO de tema de um aplicativo vira o tema, com as cores do pack.

POR QUE ELE EXISTE — 24/09/2026, sprint P42
    A P37 mediu o que o tema Dracula de antes aplicava e o MeowSystem nunca
    migrou: kitty, gnome-terminal, Telegram, Discord e OnlyOffice. Os temas de
    origem traziam a cor ESCRITA — 51 hex no do Telegram, 40 no do Discord, 36
    no do kitty (contados em 24/09/2026). Copiá-los assim seria cravar o flavor
    `dracula` em cinco arquivos: com o `alucard` (o claro do mesmo pack) no ar,
    os cinco continuariam escuros, e a divergência seria muda — a mesma que o
    `meow_paleta` (lib/comum.sh) existe para matar, um andar abaixo.

    Então o que mora no pack é um MODELO: o arquivo do aplicativo com o PAPEL da
    cor no lugar dela (`{{base}}`, `{{mauve}}`), e quem põe o hex é este script,
    na hora de aplicar, lendo a paleta do pack ATIVO no flavor da máquina. O
    `tests/temas-de-apps.sh` cobra que nenhum modelo traga hex escrito.

POR QUE UM ARQUIVO SÓ PARA OS CINCO MÓDULOS
    Os cinco fazem a mesma troca. Cinco cópias desta função seriam cinco
    dialetos do marcador no dia em que alguém corrigisse um deles — e o formato
    de pack já tem um dialeto só de marcador (`<flavor>`, em
    `cosmic.nome_da_paleta` e em `apps.*.esquema`), de propósito.

A GRAMÁTICA, INTEIRA
    {{papel}}       o hex do papel na paleta, como a paleta o escreve: #RRGGBB
    {{papel:AA}}    o mesmo com transparência, em dois hex: #RRGGBBAA — o
                    Telegram e o CSS do Discord aceitam; o OnlyOffice não, e
                    por isso existe a forma de baixo
    {{papel:rgb}}   os três canais em decimal, "r, g, b" — para `rgba(...)`
    {{nome}}        o nome do flavor para gente ler (`nomes` da paleta)
    {{flavor}}      o id do flavor           {{pack}}   o id do pack
    {{tipo}}        `light` se o flavor está em `claros`, senão `dark`
    {{tipo_inverso}} o contrário — o OnlyOffice pede o logotipo claro no escuro

    Papel que a paleta não tem é ERRO, e o arquivo não sai: um `{{azul}}`
    digitado errado viraria o texto literal dentro do tema do aplicativo, que o
    app leria como cor inválida e trocaria pela dele, calado.

USO
    modelo.py <modelo> <paleta.json> <flavor> <pack>    o tema, no stdout
    modelo.py --nome <paleta.json> <flavor>             só o {{nome}}, que é o
                                                        que a tela dos módulos diz
    0 = saiu · 2 = modelo, paleta ou flavor que não serve (motivo no stderr)
"""
import json
import re
import sys

MARCA = re.compile(r"\{\{([a-z0-9_]+)(?::([0-9a-fA-F]{2}|rgb))?\}\}")
# O que sobrar com cara de marcador depois da troca é marcador mal escrito
# (`{{base:8}}`, `{{ base }}`), e sai como erro pelo mesmo motivo do papel
# que falta: dentro do tema ele seria lido como cor inválida, calado.
RESTO = re.compile(r"\{\{[^{}]*\}\}")


def main(argv):
    so_nome = len(argv) == 4 and argv[1] == "--nome"
    if len(argv) != 5 and not so_nome:
        sys.stderr.write("uso: modelo.py <modelo> <paleta.json> <flavor> <pack>\n"
                         "     modelo.py --nome <paleta.json> <flavor>\n")
        return 2
    if so_nome:
        modelo, paleta, flavor, pack = None, argv[2], argv[3], ""
    else:
        _, modelo, paleta, flavor, pack = argv
    try:
        with open(paleta, encoding="utf-8") as fh:
            pal = json.load(fh)
        texto = ""
        if modelo is not None:
            with open(modelo, encoding="utf-8") as fh:
                texto = fh.read()
    except (OSError, ValueError) as e:
        sys.stderr.write(f"não consegui ler: {e}\n")
        return 2
    cores = (pal.get("flavors") or {}).get(flavor)
    if not isinstance(cores, dict):
        sys.stderr.write(f"flavor {flavor!r} não existe em {paleta}\n")
        return 2
    claro = flavor in (pal.get("claros") or [])
    extras = {
        "nome": (pal.get("nomes") or {}).get(flavor) or flavor,
        "flavor": flavor,
        "pack": pack,
        "tipo": "light" if claro else "dark",
        "tipo_inverso": "dark" if claro else "light",
    }
    if so_nome:
        print(extras["nome"])
        return 0
    faltou = []

    def trocar(m):
        papel, forma = m.group(1), m.group(2)
        if forma is None and papel in extras:
            return extras[papel]
        hexa = cores.get(papel)
        if not isinstance(hexa, str) or not re.fullmatch(r"#[0-9A-Fa-f]{6}", hexa):
            faltou.append(m.group(0))
            return m.group(0)
        if forma is None:
            return hexa
        if forma == "rgb":
            return ", ".join(str(int(hexa[i:i + 2], 16)) for i in (1, 3, 5))
        return hexa + forma

    saida = MARCA.sub(trocar, texto)
    faltou += [r for r in RESTO.findall(saida) if r not in faltou]
    if faltou:
        sys.stderr.write(f"{modelo}: papel que a paleta não tem: {', '.join(sorted(set(faltou)))}\n")
        return 2
    sys.stdout.write(saida)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

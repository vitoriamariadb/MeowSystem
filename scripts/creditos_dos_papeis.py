#!/usr/bin/env python3
import os
import sys

TITULO = "## Os papéis de parede desenhados"
LARGURA = 200


def _pack(raiz):
    sys.path.insert(0, os.path.join(raiz, "scripts"))
    import pack
    return pack


def _data(iso):
    return "/".join(reversed(iso.split("-"))) if iso else ""


def _celula(caminho, base, alt):
    if not caminho:
        return "—"
    rel = os.path.relpath(caminho, base).replace(os.sep, "/")
    return f'<img src="{rel}" alt="{alt}" width="{LARGURA}">'


def _tabela(papeis, base):
    linhas = ["| cena | dia | noite | pack | licença | data |", "|---|---|---|---|---|---|"]
    for p in papeis:
        cena = p["cena"][:1].upper() + p["cena"][1:]
        linhas.append("| %s | %s | %s | %s | %s | %s |" % (
            cena, _celula(p["dia"], base, f"{cena}, de dia"), _celula(p["noite"], base, f"{cena}, de noite"),
            p["nome_do_pack"], p["licenca"] or "—", _data(p["data"]) or "—"))
    return "\n".join(linhas)


def _com_secao(texto, corpo):
    linhas = texto.split("\n")
    try:
        ini = linhas.index(TITULO)
    except ValueError:
        ini = None
    if ini is not None:
        fim = next((i for i in range(ini + 1, len(linhas)) if linhas[i].startswith("## ")), len(linhas))
        antes, depois = linhas[:ini], linhas[fim:]
    else:
        antes, depois = linhas, []
    while antes and not antes[-1].strip():
        antes.pop()
    while depois and not depois[0].strip():
        depois.pop(0)
    partes = ["\n".join(antes)]
    if corpo:
        partes.append(TITULO + "\n\n" + corpo)
    if depois and any(l.strip() for l in depois):
        partes.append("\n".join(depois).rstrip("\n"))
    return "\n\n".join(p for p in partes if p) + "\n"


def desejados(raiz):
    pack = _pack(raiz)
    pasta_packs = os.path.join(raiz, "packs")
    todos = []
    saida = {}
    for pid in sorted(os.listdir(pasta_packs)):
        dir_pack = os.path.join(pasta_packs, pid)
        arq = os.path.join(dir_pack, "CREDITOS.md")
        if not os.path.isfile(os.path.join(dir_pack, "pack.json")) or not os.path.isfile(arq):
            continue
        nome = pack.campo(dir_pack, "nome", pid)
        licenca = pack.campo(dir_pack, "licenca", "")
        papeis = [dict(p, nome_do_pack=nome, licenca=p["licenca"] or licenca) for p in pack.papeis_de(dir_pack)]
        todos += papeis
        saida[arq] = _tabela(papeis, dir_pack) if papeis else ""
    geral = os.path.join(raiz, "docs", "CREDITOS.md")
    if os.path.isfile(geral):
        saida[geral] = _tabela(todos, os.path.dirname(geral)) if todos else ""
    return saida


def main(args):
    conferir = "--conferir" in args
    resto = [a for a in args if a != "--conferir"]
    raiz = os.path.abspath(resto[0]) if resto else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    mudados = []
    for arq, corpo in desejados(raiz).items():
        with open(arq, encoding="utf-8") as fh:
            antes = fh.read()
        depois = _com_secao(antes, corpo) if (corpo or TITULO in antes.split("\n")) else antes
        if depois == antes:
            continue
        mudados.append(os.path.relpath(arq, raiz))
        if not conferir:
            with open(arq + ".parcial", "w", encoding="utf-8") as fh:
                fh.write(depois)
            os.replace(arq + ".parcial", arq)
    for m in mudados:
        print(("fora de dia: " if conferir else "escrito: ") + m)
    return 1 if conferir and mudados else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

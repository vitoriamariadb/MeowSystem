#!/usr/bin/env python3
import glob
import os
import sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTRATO = os.path.join(RAIZ, "assets", "contratos", "nomes-de-sistema.tsv")
TEMAS = ("Papirus-Dark", "Papirus", "Cosmic", "Adwaita", "hicolor", "breeze-dark")
PROGRAMAS = ("cosmic-applets", "cosmic-osd", "cosmic-panel", "cosmic-notifications",
             "cosmic-settings", "cosmic-app-library", "cosmic-launcher")
GRUPOS = {"barra": "Barra e bandeja", "configuracoes": "Configurações", "botoes": "Botões e janelas"}
AJUDA = """uso: inventario_do_sistema.py medir | conferir | relatorio <saida.md>

  medir      lista os nomes de ícone simbólico que os programas do COSMIC pedem
  conferir   compara o que se mede agora com assets/contratos/nomes-de-sistema.tsv
  relatorio  escreve o relatório do contrato em <saida.md>"""


def contrato():
    linhas = []
    with open(CONTRATO, encoding="utf-8") as f:
        for linha in f:
            if linha.startswith("#") or not linha.strip():
                continue
            nome, contexto, grupo, rotulo, quem = linha.rstrip("\n").split("\t")
            linhas.append({"nome": nome, "contexto": contexto, "grupo": grupo,
                           "rotulo": rotulo, "quem": quem})
    return linhas


def _candidatos(icones):
    nomes = set()
    for tema in TEMAS:
        for _, _, arquivos in os.walk(os.path.join(icones, tema)):
            for arq in arquivos:
                nome = arq.rsplit(".", 1)[0]
                if nome.endswith("-symbolic"):
                    nomes.add(nome)
    return nomes


def medir(icones="/usr/share/icons", binarios="/usr/bin"):
    nomes = _candidatos(icones)
    quem = {}
    for prog in PROGRAMAS:
        caminho = os.path.join(binarios, prog)
        if not os.path.isfile(caminho):
            continue
        with open(caminho, "rb") as f:
            bloco = f.read().decode("latin1")
        achados = {n: bloco.count(n) for n in nomes if n in bloco}
        for nome, vezes in achados.items():
            dentro = sum(v * outro.count(nome) for outro, v in achados.items()
                         if outro != nome and nome in outro)
            if vezes > dentro:
                quem.setdefault(nome, []).append(prog.replace("cosmic-", ""))
    padrao = os.path.join(icones, "hicolor", "scalable", "status", "cosmic-applet-*-symbolic.svg")
    for arq in glob.glob(padrao):
        quem.setdefault(os.path.basename(arq)[:-4], []).append("hicolor")
    return quem


def conferir():
    medidos = medir()
    if not medidos:
        print("nada medido: os programas do COSMIC não estão nesta máquina")
        return 0
    escritos = {l["nome"] for l in contrato()}
    faltam = sorted(set(medidos) - escritos)
    for nome in faltam:
        print("o COSMIC pede e o contrato não tem: " + nome)
    print(f"{len(medidos)} medidos, {len(escritos)} no contrato, {len(faltam)} faltando")
    return 1 if faltam else 0


def relatorio(saida):
    linhas = contrato()
    partes = ["# Os nomes de sistema que o COSMIC pede", "",
              f"{len(linhas)} nomes, medidos com `scripts/inventario_do_sistema.py medir` "
              "nos programas do COSMIC (applets, osd, painel, notificações, configurações, "
              "biblioteca de apps, lançador) e nos `cosmic-applet-*` do hicolor. "
              "O contrato é `assets/contratos/nomes-de-sistema.tsv`.", ""]
    for chave, titulo in GRUPOS.items():
        grupo = [l for l in linhas if l["grupo"] == chave]
        partes += [f"## {titulo} ({len(grupo)})", "", "| nome | pasta | o que é | quem pede |",
                   "|---|---|---|---|"]
        partes += [f"| `{l['nome']}` | {l['contexto']} | {l['rotulo']} | {l['quem']} |"
                   for l in grupo]
        partes.append("")
    with open(saida, "w", encoding="utf-8") as f:
        f.write("\n".join(partes))
    print(f"{len(linhas)} nomes em {saida}")
    return 0


def main(args):
    if not args or args[0] in ("-h", "--help"):
        print(AJUDA)
        return 0 if args else 2
    verbo = args[0]
    if verbo == "medir":
        for nome, progs in sorted(medir().items()):
            print(nome + "\t" + ",".join(progs))
        return 0
    if verbo == "conferir":
        return conferir()
    if verbo == "relatorio" and len(args) == 2:
        return relatorio(args[1])
    print(AJUDA, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

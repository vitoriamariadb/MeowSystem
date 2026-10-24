#!/usr/bin/env python3
"""tests/migracao-do-painel.py — nada do painel de antes se perde no painel novo (P98).

Gera do código a tabela de migração (docs/design/2026-10-23/migracao.md):

  · cada chave do esquema do painel (o `ler_esquema` do app/servidor.py, que lê o
    meow.conf.exemplo), com a página de antes (a seção dela) e a de agora;
  · cada ação do servidor (`ACOES`), com o grupo de antes e a página de agora;
  · cada gesto da página de antes que fala com o servidor sem ser ação (as rotas
    da API que o app.js antigo chamava, mais o Exportar e os Créditos do topo).

A página de agora sai de app/pagina/lugares.js, lido no node. Reprova com uma
linha sem destino, com um lugar que aponta para chave ou ação que não existe, ou
com o .md diferente do que o código gera (rode com --escrever para regravar).

    tests/migracao-do-painel.py             confere
    tests/migracao-do-painel.py --escrever  regrava o .md

0 = passou · 1 = falhou · 3 = pulado (sem node)
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MD = os.path.join(RAIZ, "docs", "design", "2026-10-23", "migracao.md")

# Os gestos do painel de antes (app/pagina/app.js e index.html até a P97): cada
# rota da API que escreve ou baixa, e o que ela fazia na tela. É a lista fechada
# do que a página fazia além das ações do servidor; o painel novo tem de ter um
# gesto com lugar para cada uma (a coluna da direita é o id do gesto em
# lugares.js).
GESTOS_DE_ANTES = [
    ("POST /api/salvar", "Topo: Salvar e aplicar", "salvar"),
    ("Descartar (só na página)", "Topo: Descartar", "descartar"),
    ("POST /api/salvar e /api/rodar com seco", "Topo e caixa de confirmar: Ver sem mudar", "ensaio"),
    ("Busca (só na página)", "Topo: Buscar um ajuste ou uma ação", "busca"),
    ("GET /api/exportar/conf", "Topo: Exportar › Meus ajustes", "exportar-conf"),
    ("GET /api/exportar/pagina", "Topo: Exportar › Esta tela num arquivo", "exportar-pagina"),
    ("POST /api/importar", "Topo: Importar", "importar"),
    ("Link do repositório", "Menu: Créditos", "creditos"),
    ("POST /api/pack-importar", "Início: Importar um pack", "pack-importar"),
    ("POST /api/pack-importar (CSV)", "Início: pack de um .csv", "tema-criar"),
    ("GET /api/pack-exportar", "Início: Exportar o pack", "pack-exportar"),
    ("POST /api/acervo tipo gato", "Logo do sistema: Adicionar logo", "acervo:gato"),
    ("POST /api/acervo tipo parede", "Papel de parede: Adicionar imagem", "acervo:parede"),
    ("POST /api/acervo tipo icone", "Ícones: Adicionar ícone", "acervo:icone"),
    ("POST /api/acervo tipo cursor", "Cor e tela: Adicionar tema de ponteiro", "acervo:cursor"),
    ("POST /api/acervo tipo fonte", "Terminal: Adicionar fonte", "acervo:fonte"),
    ("POST /api/acervo tipo tema-icones", "Ícones: Adicionar tema de ícones", "acervo:tema-icones"),
    ("POST /api/app-icone", "Ícones: Usar este ícone, Levar para o pack, Desfazer", "app-icone"),
    ("POST /api/app-desenho", "Ícones: Gerar ícone (a oficina)", "app-desenho"),
    ("GET /api/glifos", "Ícones: Buscar desenho", "glifos"),
    ("POST /api/autorais", "Ícones: Desenhos autorais do pack", "autorais"),
    ("POST /api/jogo-fora", "Lançadores e jogos: o jogo no lançador", "jogo-fora"),
    ("POST /api/pendencia-recusar", "Início: Não, obrigado", "pendencia-recusar"),
    ("POST /api/parar", "Janela do trabalho: Parar", "parar"),
    ("POST /api/guardar-log", "Janela do trabalho: Guardar", "guardar-log"),
    ("Rodar de verdade (depois do ensaio)", "Janela do trabalho: Rodar de verdade", "ensaio-rodar"),
]

NOME_DA_PORTA = {"tema": "Tema", "criar": "Criar tema", "ajustes": "Ajustes", "cuidar": "Cuidar",
                 "topo": "Barra de cima", "janela": "Janela do trabalho"}


def onde(l):
    if l["porta"] in ("tema", "cuidar", "topo", "janela"):
        base = NOME_DA_PORTA[l["porta"]]
    else:
        base = "%s › %s" % (NOME_DA_PORTA[l["porta"]], l["pagina"])
    if l["mais"]:
        return base + " › Mais ajustes"
    if l["bloco"] and l["bloco"] not in (l["pagina"], base):
        return base + " › " + l["bloco"]
    return base


def inventario():
    js = ("const L = require(%s); process.stdout.write(JSON.stringify(L.inventarioDoPainel()));"
          % json.dumps(os.path.join(RAIZ, "app", "pagina", "lugares.js")))
    r = subprocess.run(["node", "-e", js], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise SystemExit("FALHOU: o node não leu lugares.js:\n" + r.stderr)
    return json.loads(r.stdout)


def servidor():
    """As chaves e as ações, lidas pelo próprio servidor numa casa de brinquedo."""
    casa = tempfile.mkdtemp(prefix="meow-migracao-")
    try:
        os.makedirs(os.path.join(casa, ".config", "meowsystem"))
        conf = os.path.join(casa, ".config", "meowsystem", "meow.conf")
        shutil.copyfile(os.path.join(RAIZ, "meow.conf.exemplo"), conf)
        codigo = (
            "import json, sys; sys.path.insert(0, sys.argv[1]); import servidor as s\n"
            "e = s.ler_esquema()\n"
            "print(json.dumps({'chaves': [[i['chave'], i.get('secao') or '', i.get('titulo') or ''] for i in e],\n"
            "  'acoes': [[k, v.get('grupo') or '', v.get('rotulo') or ''] for k, v in s.ACOES.items()],\n"
            "  'inventario': s.inventario_do_painel()}))\n")
        amb = {"PATH": os.environ.get("PATH", ""), "HOME": casa, "LANG": "C.UTF-8",
               "MEOW_CONF": conf, "MEOW_ESTADO": os.path.join(casa, "estado"),
               "MEOW_PONTE": os.path.join(casa, "sem-ponte")}
        r = subprocess.run([sys.executable, "-c", codigo, os.path.join(RAIZ, "app")],
                           capture_output=True, text=True, env=amb, timeout=120)
        if r.returncode != 0:
            raise SystemExit("FALHOU: o servidor não leu o esquema:\n" + r.stderr[-800:])
        return json.loads(r.stdout.strip().splitlines()[-1])
    finally:
        shutil.rmtree(casa, ignore_errors=True)


def gerar():
    inv = inventario()
    srv = servidor()
    falhas = []
    por = {}
    for l in inv:
        por.setdefault((l["tipo"], l["id"]), []).append(l)
    linhas = []
    linhas.append("# Migração do painel: de antes (P97) para o painel novo (P98)\n")
    linhas.append("Gerada por `tests/migracao-do-painel.py` a partir do código: as chaves e as ações do "
                  "`app/servidor.py`, e o lugar de cada uma no `app/pagina/lugares.js`. Não edite à mão; "
                  "rode o teste com `--escrever`.\n")
    chaves = srv["chaves"]
    acoes = srv["acoes"]
    sem = 0

    linhas.append("\n## Chaves do esquema (%d)\n" % len(chaves))
    linhas.append("| chave | antes | agora | nome na tela |")
    linhas.append("|---|---|---|---|")
    for chave, secao, titulo in chaves:
        lugares = por.get(("chave", chave), [])
        if not lugares:
            sem += 1
            falhas.append("chave sem destino: %s" % chave)
        agora = "; ".join(sorted({onde(l) for l in lugares})) or "**SEM DESTINO**"
        nome = "; ".join(sorted({l["rotulo"] for l in lugares}))
        linhas.append("| `%s` | %s | %s | %s |" % (chave, secao or "—", agora, nome))

    linhas.append("\n## Ações do servidor (%d)\n" % len(acoes))
    linhas.append("| ação | antes | agora | nome na tela |")
    linhas.append("|---|---|---|---|")
    for ident, grupo, rotulo in acoes:
        lugares = por.get(("acao", ident), [])
        if not lugares:
            sem += 1
            falhas.append("ação sem destino: %s" % ident)
        agora = "; ".join(sorted({onde(l) for l in lugares})) or "**SEM DESTINO**"
        nome = "; ".join(sorted({l["rotulo"] for l in lugares}))
        linhas.append("| `%s` | %s · «%s» | %s | %s |" % (ident, grupo or "—", rotulo, agora, nome))

    linhas.append("\n## Gestos da página (%d)\n" % len(GESTOS_DE_ANTES))
    linhas.append("| rota ou gesto | antes | agora | nome na tela |")
    linhas.append("|---|---|---|---|")
    for rota, antes, gesto in GESTOS_DE_ANTES:
        lugares = por.get(("gesto", gesto), [])
        if not lugares:
            sem += 1
            falhas.append("gesto sem destino: %s (%s)" % (gesto, rota))
        agora = "; ".join(sorted({onde(l) for l in lugares})) or "**SEM DESTINO**"
        nome = "; ".join(sorted({l["rotulo"] for l in lugares}))
        linhas.append("| %s | %s | %s | %s |" % (rota, antes, agora, nome))

    # O `--onde` do servidor lê o lugares.js sem node: a leitura dele tem de ser a do node.
    lido = [{k: v for k, v in l.items() if k != "botao"} for l in srv["inventario"]]
    if lido != inv:
        falhas.append("o inventario_do_painel do servidor não lê o lugares.js como o node (%d contra %d linhas)"
                      % (len(lido), len(inv)))

    # O caminho inverso: lugar que aponta para o que não existe é lixo na tela.
    ids_chave = {c[0] for c in chaves}
    ids_acao = {a[0] for a in acoes}
    for l in inv:
        if l["tipo"] == "chave" and l["id"] not in ids_chave:
            falhas.append("lugar de chave que não existe: %s" % l["id"])
        if l["tipo"] == "acao" and l["id"] not in ids_acao:
            falhas.append("lugar de ação que não existe: %s" % l["id"])

    linhas.append("\n## Conta\n")
    linhas.append("- %d chaves, %d ações e %d gestos; %d linha(s) sem destino."
                  % (len(chaves), len(acoes), len(GESTOS_DE_ANTES), sem))
    return "\n".join(linhas) + "\n", falhas, (len(chaves), len(acoes), len(GESTOS_DE_ANTES), sem)


def main():
    if not shutil.which("node"):
        print("pulado: sem node")
        return 3
    texto, falhas, (nc, na, ng, sem) = gerar()
    if "--escrever" in sys.argv:
        os.makedirs(os.path.dirname(MD), exist_ok=True)
        with open(MD, "w", encoding="utf-8") as fh:
            fh.write(texto)
        print("ok: %s regravado" % os.path.relpath(MD, RAIZ))
    else:
        try:
            atual = open(MD, encoding="utf-8").read()
        except OSError:
            atual = ""
        if atual != texto:
            falhas.append("%s não é o que o código gera (rode com --escrever)" % os.path.relpath(MD, RAIZ))
    for f in falhas:
        print("FALHOU: " + f, file=sys.stderr)
    if falhas:
        return 1
    print("ok: %d chaves, %d ações e %d gestos com lugar no painel novo; %d sem destino" % (nc, na, ng, sem))
    return 0


if __name__ == "__main__":
    sys.exit(main())

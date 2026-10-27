#!/usr/bin/env python3
import functools
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

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

def _node(expr):
    js = ("const L = require(%s); process.stdout.write(JSON.stringify(%s));"
          % (json.dumps(os.path.join(RAIZ, "app", "pagina", "lugares.js")), expr))
    r = subprocess.run(["node", "-e", js], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise SystemExit("FALHOU: o node não leu lugares.js:\n" + r.stderr)
    return json.loads(r.stdout)


@functools.lru_cache(maxsize=None)
def portas():
    return {p["id"]: p["nome"] for p in _node("L.PORTAS")}


def onde(l):
    nomes = portas()
    if l["porta"] in ("topo", "janela"):
        base = l["pagina"]
    elif l["porta"] in ("tema", "cuidar"):
        base = nomes[l["porta"]]
    else:
        base = "%s › %s" % (nomes[l["porta"]], l["pagina"])
    if l["bloco"] and l["bloco"] not in (l["pagina"], base):
        return base + " › " + l["bloco"]
    return base


def inventario():
    return _node("L.inventarioDoPainel()")


def servidor():
    casa = tempfile.mkdtemp(prefix="meow-migracao-")
    try:
        os.makedirs(os.path.join(casa, ".config", "meowsystem"))
        conf = os.path.join(casa, ".config", "meowsystem", "meow.conf")
        shutil.copyfile(os.path.join(RAIZ, "meow.conf.exemplo"), conf)
        codigo = (
            "import json, os, re, sys, tempfile; sys.path.insert(0, sys.argv[1]); import servidor as s\n"
            "e = s.ler_esquema()\n"
            "srv_inv = s.inventario_do_painel()\n"
            "pend = list(s.ACAO_DA_PENDENCIA) + [s.PENDENCIA_EXTENSAO, s.PENDENCIA_PAREDE,\n"
            "  'onlyoffice' + s.SUFIXO_TEMA_DE_TERCEIRO, 'inicio']\n"
            "onde = {i: s.onde_na_tela(i) for i in [c['chave'] for c in e] + list(s.ACOES) + pend}\n"
            "fonte = open(os.path.join(s.RAIZ, 'app', 'pagina', 'lugares.js'), encoding='utf-8').read()\n"
            "bloco = re.search(r'(?ms)^const PORTAS = .*?^];', fonte).group(0)\n"
            "copia = tempfile.mkdtemp(dir=os.environ['HOME']); os.makedirs(os.path.join(copia, 'app', 'pagina'))\n"
            "open(os.path.join(copia, 'app', 'pagina', 'lugares.js'), 'w', encoding='utf-8').write(\n"
            "  fonte.replace(bloco, re.sub(r'nome: \"([^\"]+)\"', r'nome: \"\\1 Nova\"', bloco)))\n"
            "s.RAIZ = copia; s._LUGARES.clear()\n"
            "renomeado = {i: s.onde_na_tela(i) for i in ('doctor_consertar', 'LANCADOR_SISTEMA', 'inicio',\n"
            "  'areas-sem-alfinete')}\n"
            "print(json.dumps({'chaves': [[i['chave'], i.get('secao') or '', i.get('titulo') or ''] for i in e],\n"
            "  'acoes': [[k, v.get('grupo') or '', v.get('rotulo') or ''] for k, v in s.ACOES.items()],\n"
            "  'onde': onde, 'pendencias': pend, 'renomeado': renomeado,\n"
            "  'escolhas': list(s.ESCOLHA_PAREDE) + list(s.ESCOLHA_TEMA_DE_TERCEIRO),\n"
            "  'inventario': srv_inv}))\n")
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
                  "`app/servidor.py`, e o lugar de cada uma no `app/pagina/lugares.js`.\n")
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

    lido = [{k: v for k, v in l.items() if k != "botao"} for l in srv["inventario"]]
    if lido != inv:
        falhas.append("o inventario_do_painel do servidor não lê o lugares.js como o node (%d contra %d linhas)"
                      % (len(lido), len(inv)))

    destinos = {onde(l) for l in inv} | {portas()["cuidar"]}
    for ident, frase in srv["onde"].items():
        if not frase:
            continue
        caminho = frase[3:] if frase.startswith("em ") else frase.split("», em ", 1)[-1]
        if caminho not in destinos:
            falhas.append("o --onde de %s aponta para %r, que não existe no lugares.js" % (ident, caminho))
        if ident in srv["pendencias"]:
            botoes = {l["botao"] for l in srv["inventario"]
                      if l["porta"] == "cuidar" and l.get("bloco") == "Pendências" and l.get("botao")}
            for citado in [x.split("»", 1)[0] for x in frase.split("«")[1:]]:
                if citado not in botoes | {"Resolver"}:
                    falhas.append("o --onde da pendência %s cita «%s», que não é botão de pendência no lugares.js"
                                  % (ident, citado))
            continue
        nomes = {x for l in srv["inventario"] if l["id"] == ident for x in (l["rotulo"], l["botao"]) if x}
        citado = frase.split("«", 1)[-1].split("»", 1)[0] if "«" in frase else ""
        if citado and citado not in nomes:
            falhas.append("o --onde de %s cita «%s», que não é rótulo nem botão no lugares.js" % (ident, citado))
    comum = open(os.path.join(RAIZ, "lib", "comum.sh"), encoding="utf-8").read()
    bloco = comum.split("\nmeow_onde_no_painel() {", 1)[0].rsplit("\n\n", 1)[-1]
    if re.search(r"\babas?\b", bloco, re.I):
        falhas.append("o comentário do meow_onde_no_painel (lib/comum.sh) ainda fala em aba")
    botao_de = {l["id"]: l.get("botao") for l in srv["inventario"]
                if l["porta"] == "cuidar" and l.get("bloco") == "Pendências"}
    for acao, rotulo in srv["escolhas"]:
        if botao_de.get(acao) != rotulo:
            falhas.append("a pendência desenha «%s» para %s, e o lugares.js diz «%s»"
                          % (rotulo, acao, botao_de.get(acao)))
    quer = {"doctor_consertar": "«Consertar a ponte», em Manter Nova › Estado",
            "LANCADOR_SISTEMA": "«Arrumar o lançador», em Definir Nova › Programas › Lançador",
            "inicio": "em Manter Nova", "areas-sem-alfinete": "«Resolver», em Manter Nova"}
    if srv["renomeado"] != quer:
        falhas.append("o --onde não lê o nome das portas do lugares.js (segunda tabela no servidor): %r"
                      % srv["renomeado"])

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
    for f in falhas:
        print("FALHOU: " + f, file=sys.stderr)
    if falhas:
        return 1
    print("ok: %d chaves, %d ações e %d gestos com lugar no painel novo; %d sem destino" % (nc, na, ng, sem))
    return 0


if __name__ == "__main__":
    sys.exit(main())

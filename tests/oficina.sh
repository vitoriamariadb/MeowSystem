#!/usr/bin/env bash
# Todo desenho de pack que veste um aplicativo DESTA máquina tem cartão na
# oficina daquele aplicativo. O teto é zero.
#
# A oficina do Warehouse, que tem desenho feito à mão no pack, oferecia
# converter e gerar em traço e dizia "já tem desenho convertido do projeto".
#
# Medido de novo, antes do conserto, pela MESMA porta que este teste usa: 18
# desenhos casam um `Icon=` desta máquina (17 pelo nome do arquivo, e o
# `guvcview.svg` pelo `apps.map`, que o põe na Câmera), e os 18 saíam sem
# cartão.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v python3 >/dev/null || { printf 'pulado: sem python3\n'; exit 3; }

MEOW_RAIZ="$RAIZ" python3 - "$RAIZ" <<'PY'
import os
import sys

raiz = sys.argv[1]
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor  # noqa: E402

mod = servidor.modulo_pack()
if not mod:
    print("FALHOU: o painel não carregou o scripts/pack.py", file=sys.stderr)
    sys.exit(1)

# A oficina de verdade, sem requisição HTTP em volta: `__new__` pula o
# construtor do BaseHTTPRequestHandler, que existe para ler um socket.
m = servidor.Manipulador.__new__(servidor.Manipulador)
resposta = {}
m._json = lambda dados, codigo=200: resposta.update(dados=dados, codigo=codigo)
servidor._converter_desenho = lambda *a, **k: ("", "", "conversão pulada no teste")

# --- o que casa: nome do arquivo, ou o que o apps.map aponta para ele --------
desenhos = {}     # caminho real do SVG -> nomes de ícone que ele veste
base_packs = os.path.join(raiz, "packs")
for pid in sorted(os.listdir(base_packs)):
    dir_pack = os.path.join(base_packs, pid)
    if not os.path.isfile(os.path.join(dir_pack, "pack.json")):
        continue
    dir_apps = mod.campo(dir_pack, "icones.apps.desenhos")
    if not isinstance(dir_apps, str):
        continue
    dir_apps = os.path.join(dir_pack, dir_apps)
    if not os.path.isdir(dir_apps):
        continue
    for arq in sorted(os.listdir(dir_apps)):
        if arq.endswith(".svg"):
            desenhos[os.path.realpath(os.path.join(dir_apps, arq))] = {arq[:-4]}
    mapa = mod.campo(dir_pack, "icones.apps.mapa")
    if not isinstance(mapa, str):
        continue
    caminho_mapa = os.path.join(dir_pack, mapa)
    try:
        linhas = open(caminho_mapa, encoding="utf-8").read().splitlines()
    except OSError:
        continue
    for linha in linhas:
        corte = linha.split("#", 1)[0].strip()
        if ":" not in corte:
            continue
        nome, alvo = (c.strip() for c in corte.split(":", 1))
        try:
            real = os.path.realpath(mod.resolver_alvo(alvo, os.path.dirname(caminho_mapa)))
        except mod.Recusa:
            continue
        if real in desenhos and nome:
            desenhos[real].add(nome)

maquina = m._desktops()
casam, sem_cartao = 0, []
for svg, nomes in sorted(desenhos.items()):
    apps = [d for d in maquina if (d["icone"] or d["id"]) in nomes or d["id"] in nomes]
    if not apps:
        continue
    casam += 1
    faltou = []
    for d in apps:
        resposta.clear()
        m._api_app_desenho({"app": d["id"], "acao": "variacoes"})
        cartoes = (resposta.get("dados") or {}).get("pack") or []
        if not any(os.path.realpath(c.get("arquivo") or "") == svg for c in cartoes):
            faltou.append(d["id"])
    if faltou:
        sem_cartao.append("%s  (oficina de %s)" % (os.path.relpath(svg, raiz), ", ".join(faltou[:3])
                                                     + (" e mais %d" % (len(faltou) - 3) if len(faltou) > 3 else "")))

print("%d desenho(s) de pack casam um Icon= desta máquina; %d sem cartão na oficina"
      % (casam, len(sem_cartao)))
if sem_cartao:
    print("FALHOU: desenho de pack que a oficina não mostra:", file=sys.stderr)
    for linha in sem_cartao:
        print("    " + linha, file=sys.stderr)
    sys.exit(1)
print("ok: todo desenho de pack que veste um aplicativo daqui aparece como cartão na oficina dele")

# --- A OFICINA DE AUTORAL LÊ O QUE SALVA — 23/09/2026, revisão da P26 --------
#   O modelo de pack do docs/PACKS.md declara só `"autorais": {"gerar": true}`,
#   sem `desenhos`. Para esse pack o «Salvar no pack» gravava em
#   `icones/autorais/` e o `pack.autorais()` não lia dali: a revisão salvou
#   `foto` em red num pack assim, a resposta disse ok, e a lista seguinte e o
#   SVG regerado continuaram em overlay0 — a torrada dizia «salvo no pack»
#   sobre uma edição perdida. As perguntas vão à MESMA rota que a página chama,
#   com um pack descartável no formato do modelo; o gerador escreve dentro dele
#   e em nenhum outro lugar.
#
#   E o `na_tela` de um desenho que nenhum ícone instalado tem sai vazio: é o
#   desenho declarado sem linha no `AUTORAL` do `completar_icones.sh`, que a
#   torrada prometia pôr na tela.
import json  # noqa: E402
import shutil  # noqa: E402
import tempfile  # noqa: E402

tmp = tempfile.mkdtemp(prefix="oficina-autoral-")
falhas = []
try:
    # O DESENHO HERDADO É DE UM PACK PAI DE BRINQUEDO — 15/10/2026, P82. Era o
    #   `fogstripper` do Catppuccin, e ele saiu dos packs (projeto pessoal,
    #   decisão 16). O caso continua o mesmo: o `terceiro` herda um desenho
    #   declarado, e salvar o copia para ele.
    dir_pai = os.path.join(tmp, "pai")
    os.makedirs(os.path.join(dir_pai, "icones", "autorais"))
    shutil.copy(os.path.join(raiz, "packs", "dracula", "paleta.json"), dir_pai)
    with open(os.path.join(dir_pai, "pack.json"), "w", encoding="utf-8") as fh:
        json.dump({"formato": 1, "id": "pai", "nome": "Pai", "heranca": "catppuccin",
                   "paleta": {"arquivo": "paleta.json"},
                   "icones": {"autorais": {"gerar": True}}}, fh)
    with open(os.path.join(dir_pai, "icones", "autorais", "emprestado.json"), "w", encoding="utf-8") as fh:
        json.dump({"papeis": {"foto": {"escuro": "overlay0", "claro": "overlay0"}},
                   "svg": ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">',
                           '  <title>{titulo}</title>',
                           '  <rect x="6" y="6" width="36" height="36" fill="{foto}"/>',
                           '</svg>']}, fh)
    os.environ["MEOW_PACKS"] = tmp
    dir_t = os.path.join(tmp, "terceiro")
    dir_aut = os.path.join(dir_t, "icones", "autorais")
    os.makedirs(dir_aut)
    shutil.copy(os.path.join(raiz, "packs", "dracula", "paleta.json"), dir_t)
    with open(os.path.join(dir_t, "pack.json"), "w", encoding="utf-8") as fh:
        json.dump({"formato": 1, "id": "terceiro", "nome": "Terceiro", "heranca": "pai",
                   "paleta": {"arquivo": "paleta.json"},
                   "icones": {"autorais": {"gerar": True}}}, fh)
    # Um triângulo: forma que nenhum tema instala, para o `na_tela` ter de ser vazio.
    with open(os.path.join(dir_aut, "meu-app.json"), "w", encoding="utf-8") as fh:
        json.dump({"papeis": {"fundo": {"escuro": "surface0", "claro": "surface0"}},
                   "svg": ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">',
                           '  <title>{titulo}</title>',
                           '  <path d="M4 4 L44 4 L24 44 Z" fill="{fundo}"/>',
                           '</svg>']}, fh)
    servidor._pack_adotado = lambda: dir_t

    def autoral(corpo):
        resposta.clear()
        m._api_autorais(corpo)
        return resposta.get("dados") or {}

    def lista():
        return {d["nome"]: d for d in autoral({"acao": "listar"}).get("desenhos", [])}

    with open(os.path.join(dir_t, "paleta.json"), encoding="utf-8") as fh:
        paleta = json.load(fh)
    escuro = next(f for f in paleta["flavors"] if f not in paleta.get("claros", []))
    vermelho = paleta["flavors"][escuro]["red"]

    antes = lista()
    if (antes.get("meu-app") or {}).get("pack") != "terceiro":
        falhas.append("meu-app.json está em icones/autorais/ e a lista não o mostra como do pack")

    # meu-app é do próprio pack; o emprestado é herdado do pai, e salvar o
    # copia — é o caso exato que a revisão reproduziu.
    for nome, papel in (("meu-app", "fundo"), ("emprestado", "foto")):
        papeis = dict((antes.get(nome) or {}).get("papeis") or {})
        if papel not in papeis:
            falhas.append("%s: a lista não trouxe o papel %s" % (nome, papel))
            continue
        papeis[papel] = {"escuro": "red", "claro": "red"}
        r = autoral({"acao": "salvar", "nome": nome, "papeis": papeis})
        if not r.get("ok"):
            falhas.append("%s: salvar recusou — %s" % (nome, r.get("erro")))
            continue
        if nome == "meu-app" and r.get("na_tela"):
            falhas.append("meu-app: nenhum ícone instalado tem esta forma, e a resposta diz "
                          "que está na tela como %s" % ", ".join(r["na_tela"]))
        depois = lista().get(nome) or {}
        lido = ((depois.get("papeis") or {}).get(papel) or {}).get("escuro")
        if depois.get("pack") != "terceiro" or lido != "red":
            falhas.append("%s: salvo com %s em red, e a lista seguinte lê %s do pack %s"
                          % (nome, papel, lido, depois.get("pack")))
        # A linha do SVG gerado que corresponde à lacuna: as linhas do `.json`
        # e as do arquivo andam juntas, porque o gerador só as junta por \n.
        with open(os.path.join(dir_aut, nome + ".json"), encoding="utf-8") as fh:
            linhas = json.load(fh)["svg"]
        i = next(k for k, linha in enumerate(linhas) if "{%s}" % papel in linha)
        with open(os.path.join(dir_aut, "%s-%s.svg" % (nome, escuro)), encoding="utf-8") as fh:
            gerado = fh.read().split("\n")
        if vermelho.lower() not in gerado[i].lower():
            falhas.append("%s: o SVG regerado não traz o red (%s) na linha de %s: %s"
                          % (nome, vermelho, papel, gerado[i].strip()))
finally:
    shutil.rmtree(tmp, ignore_errors=True)

if falhas:
    print("FALHOU: a oficina de autoral, num pack sem `desenhos`, não lê o que salva:",
          file=sys.stderr)
    for linha in falhas:
        print("    " + linha, file=sys.stderr)
    sys.exit(1)
print("ok: a oficina de autoral, num pack sem `desenhos`, lê o que salva "
      "(meu-app e a cópia do desenho herdado)")
PY

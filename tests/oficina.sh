#!/usr/bin/env bash
# Todo desenho de pack que veste um aplicativo DESTA máquina tem cartão na
# oficina daquele aplicativo. O teto é zero.
#
# A QUEIXA QUE ABRIU ISTO, 21/09/2026
#   *"você viu que os ícones do Dracula, todos os SVGs meus, não aparecem lá,
#   né?"* Os 18 desenhos de `packs/dracula/icones/apps/` estavam INSTALADOS —
#   18 de 18 conferidos contra `~/.local/share/icons/MeowSystem-Icons/` — e
#   invisíveis na tela onde se escolhe o ícone. A oficina do Warehouse, que tem
#   desenho feito à mão no pack, oferecia converter e gerar em traço e dizia
#   "já tem desenho convertido do projeto". Ela não sabia que o pack existia.
#
#   Medido de novo em 23/09/2026, antes do conserto, pela MESMA porta que este
#   teste usa: 18 desenhos casam um `Icon=` desta máquina (17 pelo nome do
#   arquivo, e o `guvcview.svg` pelo `apps.map`, que o põe na Câmera), e os 18
#   saíam sem cartão.
#
# A PERGUNTA É FEITA À OFICINA, NÃO A UMA CÓPIA DELA
#   O teste chama o `_api_app_desenho` com `acao: variacoes` — a mesma rota que
#   a página chama ao abrir a oficina — e lê a resposta. Uma função paralela
#   que "calculasse o que a oficina deveria mostrar" provaria que a função
#   paralela funciona, e o defeito de 21/09 era justamente a tela não saber.
#
#   O conversor é trocado por um que não converte: o cartão do pack não
#   depende de vetorizar nada, e sem a troca o teste custaria seis conversões
#   por aplicativo para conferir um campo que não passa por elas.
#
# O QUE CONTA COMO "VESTE UM APLICATIVO DESTA MÁQUINA"
#   Um SVG de `packs/<id>/icones/apps/` casa quando o nome dele, ou um nome que
#   o `apps.map` do pack aponta para ele, é o `Icon=` (ou o id) de algum
#   `.desktop` da máquina — inclusive os ocultos: `NoDisplay=true` tira o
#   programa do lançador, não tira o ícone do tema, e a rota os atende igual.
#   Numa máquina sem nenhum desses programas o teste confere zero e diz isso.
#
# POR QUE É DA LISTA `MAQUINA` DO `todos.sh`
#   A resposta depende dos programas instalados aqui. Numa máquina de CI ele
#   passaria conferindo nada — e um verde que não mediu nada é pior que um
#   teste que só roda onde tem o que medir.
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
PY

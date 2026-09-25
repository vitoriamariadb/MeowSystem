#!/usr/bin/env bash
# seletor-do-pack.sh — os desenhos do pack no ar na ficha de ícone, e onde a
# escolha de um deles mora. Sprint P60, 25/09/2026.
#
# A PERGUNTA QUE ABRIU ISTO
#   «Nosso pack de 300 icons aparece pro user pra que ele possa escolher um
#   deles pra substituir algum atual?» Não aparecia. A busca da ficha de ícone
#   (`_api_glifos`) varria quatro pastas do motor: na ficha do Chrome, «chrome»
#   dava uma opção só, o traço do Arcticons, e «alien» — um dos 295 desenhos da
#   biblioteca do Dracula — não dava nenhuma.
#
# O QUE ELE COBRA — a conferência da sprint, e as cercas em volta dela
#   1. Com o Dracula no ar e a camada ligada, «alien» acha o desenho da
#      biblioteca, num grupo com o nome do pack, com a miniatura liberada na
#      cerca do `/previa`; «chrome» acha o do Dracula E o do Arcticons.
#   2. Nenhum acervo de pack fora do ar: o grupo «Catppuccin» cravado saiu.
#   3. Escolher o alien para um programa grava a linha no `apps.map` do
#      Dracula, e só ela muda no arquivo; a ação que a ficha dispara em seguida
#      (`icones_pack`) o põe no tema instalado, com os bytes que a miniatura
#      mostrou; e o `--conferir` do passo sai 0 depois dela.
#   4. As recusas: o pack fora do ar, o desenho que a busca não ofereceria, o
#      nome que outro dono do `scalable/apps` decide, a camada desligada — com
#      a frase que aponta o cartão pelo título que ele tem na tela.
#   5. Trocar para o Catppuccin não carrega a escolha: a busca não oferece o
#      Dracula, o passo do pack tira do tema o que o Dracula tinha posto, o
#      Catppuccin não ganha arquivo nenhum — e a escolha volta com o Dracula.
#
# AS PERGUNTAS VÃO ÀS ROTAS DE VERDADE, no molde do tests/oficina.sh: o
#   `Manipulador` sem socket, com o `_json` capturado. O passo que põe no tema é
#   a AÇÃO (`iniciar`), com o meow.conf de brinquedo no ambiente — o mesmo
#   caminho que a página percorre depois do «Usar este ícone».
#
# O REPOSITÓRIO TAMBÉM É DE BRINQUEDO: a escolha é gravada no mapa do pack,
#   que mora dentro da raiz. O teste roda sobre uma cópia da árvore de trabalho
#   (o versionado e o novo, como o tests/app-completo.py), e o repositório de
#   verdade não é tocado por construção.
#
# PORTÁTIL: bash, git, tar e python3. Os `.desktop` são só os da casa de
#   brinquedo — a lista de pastas do servidor é trocada pela dela —, e nada
#   instalado na máquina entra na conta.
#
# CÓDIGOS DE SAÍDA (os do projeto)
#   0 = tudo cobrado passou · 1 = achados · 2 = erro deste teste · 3 = pulado.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 3; }
command -v git >/dev/null 2>&1 || { printf 'pulado: sem git para copiar a árvore\n'; exit 3; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
CASA="$T/casa"
mkdir -p "$T/raiz" "$CASA/.config/meow" "$CASA/.local/share/applications" \
         "$CASA/.local/state/meowsystem" \
         "$CASA/.local/share/icons/MeowSystem-Icons/scalable/apps" || exit 2

# A árvore de trabalho, versionada e nova. O `--ignore-failed-read` é para o
# arquivo apagado na árvore e ainda no índice, que não tem o que copiar.
( cd "$RAIZ" && git ls-files -z --cached --others --exclude-standard \
    | tar --null --ignore-failed-read -T - -cf - 2>/dev/null ) \
  | tar -C "$T/raiz" -xf - || { printf 'FALHOU: não consegui copiar a árvore\n' >&2; exit 2; }

# O meow.conf de brinquedo: o de fábrica, com o Dracula no ar e a camada dos
# desenhos de aplicativo ligada — a última atribuição vence, como no `.`.
cp "$T/raiz/meow.conf.exemplo" "$CASA/.config/meow/meow.conf" || exit 2
printf '\nPACK="dracula"\nFLAVOR="dracula"\nICONES_DRACULA="sim"\n' >> "$CASA/.config/meow/meow.conf"

# Três programas: um que o mapa do Dracula já veste (o nome é o `Icon=`), um
# que ele não conhece, e o «Arquivos», cujo ícone é de outro dono.
desktop() {   # desktop <arquivo> <Name> <Icon>
  printf '[Desktop Entry]\nName=%s\nExec=true\nIcon=%s\nTerminal=false\nType=Application\n' \
    "$2" "$3" > "$CASA/.local/share/applications/$1.desktop"
}
desktop google-chrome "Chrome de Brinquedo" google-chrome
desktop programa-de-brinquedo "Programa de Brinquedo" programa-de-brinquedo
desktop com.system76.CosmicFiles "Arquivos de Brinquedo" com.system76.CosmicFiles

env -u MEOW_PACK_DIR -u MEOW_PALETA -u MEOW_PALETA_DA_PONTE -u MEOW_PACKS \
    -u NOME_TEMA_ICONES -u PACK -u FLAVOR -u ICONES_DRACULA -u MEOW_SECO \
    MEOW_RAIZ="$T/raiz" HOME="$CASA" MEOW_CONF="$CASA/.config/meow/meow.conf" \
    XDG_CONFIG_HOME="$CASA/.config" XDG_DATA_HOME="$CASA/.local/share" \
    XDG_STATE_HOME="$CASA/.local/state" MEOW_ESTADO="$CASA/.local/state/meowsystem" \
    python3 - "$T/raiz" "$CASA" <<'PY'
import hashlib
import os
import re
import subprocess
import sys
import time
from urllib.parse import unquote

raiz, casa = sys.argv[1], sys.argv[2]
conf = os.environ["MEOW_CONF"]
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor  # noqa: E402

M = servidor.Manipulador
M.DIRS_DESKTOP = ((os.path.join(casa, ".local", "share", "applications"), "usuária"),)
m = M.__new__(M)
resposta = {}
m._json = lambda dados, codigo=200: resposta.update(dados=dados, codigo=codigo)

mapa = os.path.join(raiz, "packs", "dracula", "icones", "apps.map")
icones = os.path.join(raiz, "packs", "dracula", "icones")
alien = os.path.join(icones, "biblioteca", "alien.svg")
tema = os.path.join(casa, ".local", "share", "icons", "MeowSystem-Icons", "scalable", "apps")
falhas = []


def ok(frase):
    print("ok: " + frase)


def checa(cond, frase, detalhe=""):
    if cond:
        ok(frase)
    else:
        falhas.append(frase + (" — " + detalhe if detalhe else ""))
    return cond


def chamar(metodo, argumento):
    resposta.clear()
    metodo(argumento)
    return resposta.get("codigo"), resposta.get("dados") or {}


def glifos(busca):
    return chamar(m._api_glifos, {"busca": [busca]})[1]


def escolher(app, desenho, pack="dracula"):
    return chamar(m._api_app_icone, {"app": app, "pack": pack, "desenho": desenho})


def conf_com(**chaves):
    with open(conf, "a", encoding="utf-8") as fh:
        fh.write("".join('%s="%s"\n' % kv for kv in chaves.items()))


def texto(caminho):
    # `rstrip` porque o `meow_escrever` normaliza a quebra do fim — é a régua
    # do `_dracula_remover` e do tests/fonte-unica.sh.
    try:
        with open(caminho, encoding="utf-8") as fh:
            return fh.read().rstrip("\n")
    except OSError:
        return None


def passo_do_pack():
    """A ação que a ficha dispara depois de gravar, e o código dela."""
    trabalho, erro = servidor.iniciar("icones_pack", "")
    if erro:
        return None, str(erro)
    trabalho.proc.wait(timeout=120)
    teto = time.time() + 10
    while trabalho.rc is None and time.time() < teto:
        time.sleep(0.05)
    return trabalho.rc, "\n".join(trabalho.linhas)


def script(nome, verbo):
    """Um script de ícone com o meow.conf de brinquedo no ambiente, como o
    instalador o chama (`set -a` do conf)."""
    ambiente = dict(os.environ)
    ambiente.update({k: v for k, v in (servidor.conf_exportada() or {}).items()})
    r = subprocess.run([os.path.join(raiz, "scripts", nome), verbo],
                       env=ambiente, capture_output=True, text=True, timeout=120)
    return r.returncode, r.stdout + r.stderr


def conferir():
    return script("icones_apps_dracula.sh", "--conferir")


def do_dracula_no_tema():
    """Os nomes cujo arquivo no tema é o desenho que o mapa do Dracula dá a eles."""
    mod = servidor.modulo_pack()
    achados = []
    for _num, nome, alvo in mod.ler_mapa(mapa):
        try:
            desenho = mod.resolver_alvo(alvo, icones)
        except mod.Recusa:
            continue
        if texto(os.path.join(tema, nome + ".svg")) == texto(desenho) is not None:
            achados.append(nome)
    return achados


def arvore(caminho):
    soma = hashlib.sha256()
    for base, dirs, arqs in sorted(os.walk(caminho)):
        dirs.sort()
        for a in sorted(arqs):
            p = os.path.join(base, a)
            soma.update(p.encode())
            with open(p, "rb") as fh:
                soma.update(fh.read())
    return soma.hexdigest()


# --- 1. o que a busca oferece com o Dracula no ar ---------------------------
r = glifos("alien")
do_pack = [g for g in r.get("glifos", []) if g.get("pack")]
print("  «alien»: %d opção(ões) — %s" % (len(r.get("glifos", [])), ", ".join(
    "%s (%s)" % (g["glifo"], g["grupo"]) for g in r.get("glifos", [])) or "nenhuma"))
achado = next((g for g in do_pack if g["glifo"] == "alien"), None)
checa(achado and achado["grupo"] == "Dracula" and achado["desenho"] == "biblioteca/alien.svg",
      "«alien» acha o desenho da biblioteca do Dracula, no grupo com o nome do pack",
      repr(do_pack))
if achado:
    pedido = os.path.normpath(unquote(achado["url"].split("id=", 1)[1]))
    checa(pedido == os.path.normpath(alien) and pedido in servidor._ICONES_DECLARADOS,
          "a miniatura dele é o próprio arquivo do pack, liberado na cerca do /previa",
          pedido)

r = glifos("chrome")
print("  «chrome»: %d opção(ões) — %s" % (len(r.get("glifos", [])), ", ".join(
    "%s (%s)" % (g["glifo"], g["grupo"]) for g in r.get("glifos", []))))
grupos = {g["grupo"] for g in r.get("glifos", []) if g["glifo"] == "google-chrome"}
checa({"Dracula", "traço (Arcticons)"} <= grupos,
      "«chrome» oferece o google-chrome do Dracula e o do Arcticons, cada um no seu grupo",
      repr(sorted(grupos)))

vazia = glifos("")
checa(sum(1 for g in vazia.get("glifos", []) if g.get("pack")) == 60
      and sum(1 for g in vazia.get("glifos", []) if not g.get("pack")) > 0,
      "a busca vazia traz 60 do pack e o traço de sempre, cada um com o seu teto")

# --- 2. nenhum acervo de pack fora do ar -------------------------------------
todos = [g for busca in ("", "alien", "chrome", "cosmic") for g in glifos(busca).get("glifos", [])]
checa(not [g for g in todos if g["grupo"] == "Catppuccin" or (g.get("pack") or "dracula") != "dracula"],
      "com o Dracula no ar, nenhum grupo de outro pack — o «Catppuccin» cravado saiu")
autorais = [g for g in todos if g.get("pack") and g["desenho"].startswith("autorais/")]
checa(autorais and all(g["desenho"].endswith("-dracula.svg") for g in autorais),
      "os autorais oferecidos são os do flavor em vigor (%d do dracula)" % len(
          {g["desenho"] for g in autorais}))

# --- 3. escolher o alien grava a linha, e o passo o põe no tema ---------------
with open(mapa, encoding="utf-8") as fh:
    antes = fh.read().split("\n")
codigo, dados = escolher("google-chrome", "biblioteca/alien.svg")
checa(codigo == 200 and dados.get("ok") and dados.get("nome_pack") == "Dracula",
      "o «Usar este ícone» com o alien grava a escolha no pack Dracula", repr(dados))
with open(mapa, encoding="utf-8") as fh:
    depois = fh.read().split("\n")
mudou = [i for i, (a, b) in enumerate(zip(antes, depois)) if a != b]
checa(len(antes) == len(depois) and len(mudou) == 1
      and depois[mudou[0]] == "google-chrome : biblioteca/alien.svg   # Chrome de Brinquedo — escolhido no painel",
      "no apps.map do Dracula só a linha do google-chrome muda, e ela diz de onde veio",
      repr([depois[i] for i in mudou]))

ultima = max(i for i, l in enumerate(depois) if l.split("#", 1)[0].count(":"))
codigo, dados = escolher("programa-de-brinquedo", "biblioteca/arcade.svg")
with open(mapa, encoding="utf-8") as fh:
    agora = fh.read().split("\n")
checa(codigo == 200 and len(agora) == len(depois) + 1
      and agora[ultima + 1].startswith("programa-de-brinquedo : biblioteca/arcade.svg   #"),
      "um programa que o mapa não conhecia ganha a linha depois da última ativa",
      repr(agora[ultima:ultima + 2]))

rc, saida = passo_do_pack()
checa(rc in (0, 1) and texto(os.path.join(tema, "google-chrome.svg")) == texto(alien),
      "a ação `icones_pack` põe o alien no tema instalado, com os bytes da miniatura (rc=%s)" % rc,
      saida[-600:])
rc, saida = conferir()
checa(rc == 0, "depois dela o --conferir do passo sai 0 — nada a mudar (rc=%s)" % rc, saida[-600:])

# --- 4. as recusas ------------------------------------------------------------
codigo, dados = escolher("google-chrome", "biblioteca/alien.svg", pack="catppuccin")
checa(codigo == 409, "gravar no mapa de um pack fora do ar é recusado (%s)" % codigo, repr(dados))
for forjado in ("../../../etc/passwd", "biblioteca/sem-desenho.svg", "icones/biblioteca/alien.svg"):
    codigo, dados = escolher("google-chrome", forjado)
    checa(codigo == 404, "o desenho %r, que a busca não ofereceria, é recusado (%s)" % (forjado, codigo))
codigo, dados = escolher("com.system76.CosmicFiles", "biblioteca/alien.svg")
checa(codigo == 409 and "outro passo" in dados.get("erro", ""),
      "o «Arquivos», que o completar_icones.sh decide, recusa o desenho do pack", repr(dados))
apps = {a["id"]: a for a in servidor.Manipulador._dados_apps(m, {}).get("apps", [])}
checa((apps.get("com.system76.CosmicFiles") or {}).get("trava_pack")
      and (apps.get("google-chrome") or {}).get("trava_pack") is None,
      "a grade diz a trava do pack no «Arquivos», e não no Chrome")

conf_com(ICONES_DRACULA="")
r = glifos("alien")
esquema = servidor.ler_esquema()
servidor._com_o_vocabulario_do_pack(esquema, servidor.vocabulario_do_pack(), {})
titulo = next((i.get("titulo") for i in esquema if i["chave"] == "ICONES_DRACULA"), None)
checa(not [g for g in r.get("glifos", []) if g.get("pack")] and r.get("aviso")
      and titulo and ("«%s»" % titulo) in r["aviso"],
      "com a camada desligada o pack sai da busca, e o aviso aponta o cartão pelo título da tela",
      repr((r.get("aviso"), titulo)))
codigo, dados = escolher("google-chrome", "biblioteca/alien.svg")
checa(codigo == 409 and dados.get("erro") == r.get("aviso"),
      "e gravar com ela desligada é recusado com a mesma frase (%s)" % codigo)
conf_com(ICONES_DRACULA="sim")

# --- 5. trocar para o Catppuccin não carrega a escolha ------------------------
catppuccin = os.path.join(raiz, "packs", "catppuccin")
antes_c = arvore(catppuccin)
conf_com(PACK="catppuccin", FLAVOR="mocha")
r = glifos("alien")
checa(not r.get("glifos") and not r.get("aviso"),
      "com o Catppuccin no ar, «alien» não acha nada — o Dracula saiu da busca")
r = glifos("chrome")
checa([g["grupo"] for g in r.get("glifos", [])] == ["traço (Arcticons)"],
      "e «chrome» volta a ser só o traço do Arcticons",
      repr([(g["glifo"], g["grupo"]) for g in r.get("glifos", [])]))
codigo, dados = escolher("google-chrome", "biblioteca/alien.svg")
checa(codigo == 409, "uma página de antes da troca não grava no mapa do Dracula (%s)" % codigo)
rc, saida = passo_do_pack()
# O QUE FICA É SÓ DO RESGATE. Os dois nomes que o Dracula disputa com o
# `apps-resgatados.map` (P43) voltam a ser do resgate com o Catppuccin no ar, e
# quem os devolve é o `icones_resgatados.sh`, que a instalação roda antes deste
# passo — o bloco 10 do tests/fonte-unica.sh cobra essa volta. Aqui se cobra que
# o passo do pack não os leve junto, e que depois do resgate não sobre desenho
# nenhum do Dracula.
do_resgate = {n for n, _f, camada in servidor.modulo_pack().fontes("catppuccin")
              if camada == "resgatados"}
sobra = sorted(os.listdir(tema))
checa(rc in (0, 1) and not os.path.exists(os.path.join(tema, "google-chrome.svg"))
      and not os.path.exists(os.path.join(tema, "programa-de-brinquedo.svg"))
      and {s[:-len(".svg")] for s in sobra} <= do_resgate,
      "o passo do pack, com o Catppuccin no ar, tira do tema o que o Dracula pôs — o "
      "alien do Chrome inclusive —, e só o que o resgate disputa fica para ele (rc=%s)" % rc,
      "sobrou: %s" % ", ".join(sobra[:8]))
rc_r, saida_r = script("icones_resgatados.sh", "--aplicar")
restos = do_dracula_no_tema()
checa(rc_r in (0, 1) and not restos,
      "depois do resgate, nenhum arquivo do tema é desenho do mapa do Dracula (rc=%s)" % rc_r,
      "ainda do Dracula: %s" % ", ".join(restos[:8]))
rc, saida = conferir()
rc_r, saida_r = script("icones_resgatados.sh", "--conferir")
checa(rc == 0 and rc_r == 0,
      "e a segunda passagem dos dois não tem o que fazer (pack=%s, resgate=%s)" % (rc, rc_r),
      (saida + saida_r)[-600:])
checa(arvore(catppuccin) == antes_c
      and not os.path.exists(os.path.join(catppuccin, "icones", "apps.map")),
      "o pack Catppuccin não ganhou arquivo nenhum")

conf_com(PACK="dracula", FLAVOR="dracula")
rc, saida = passo_do_pack()
checa(texto(os.path.join(tema, "google-chrome.svg")) == texto(alien),
      "de volta ao Dracula, a escolha volta com ele: ela mora no pack (rc=%s)" % rc)

if falhas:
    print("FALHOU: os desenhos do pack na ficha de ícone:", file=sys.stderr)
    for linha in falhas:
        print("    " + linha, file=sys.stderr)
    sys.exit(1)
print("ok: os desenhos do pack no ar aparecem na ficha, a escolha mora no pack e não vaza")
PY

#!/usr/bin/env bash
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

( cd "$RAIZ" && git ls-files -z --cached --others --exclude-standard \
    | tar --null --ignore-failed-read -T - -cf - 2>/dev/null ) \
  | tar -C "$T/raiz" -xf - || { printf 'FALHOU: não consegui copiar a árvore\n' >&2; exit 2; }

cp "$T/raiz/meow.conf.exemplo" "$CASA/.config/meow/meow.conf" || exit 2
printf '\nPACK="dracula"\nFLAVOR="dracula"\nICONES_DRACULA="sim"\n' >> "$CASA/.config/meow/meow.conf"

desktop() {
  printf '[Desktop Entry]\nName=%s\nExec=true\nIcon=%s\nTerminal=false\nType=Application\n' \
    "$2" "$3" > "$CASA/.local/share/applications/$1.desktop"
}
desktop google-chrome "Chrome de Brinquedo" google-chrome
desktop programa-de-brinquedo "Programa de Brinquedo" programa-de-brinquedo
desktop com.system76.CosmicFiles "Arquivos de Brinquedo" com.system76.CosmicFiles
desktop org.gnome.Calculator "Calculadora de Brinquedo" org.gnome.Calculator
jogo() {
  printf '[Desktop Entry]\nName=%s\nExec=true\nIcon=%s\nTerminal=false\nType=Application\nCategories=Game;\n' \
    "$2" "$3" > "$CASA/.local/share/applications/$1.desktop"
}
jogo jogo-de-brinquedo "Jogo de Brinquedo" "$CASA/jogo.svg"
jogo jogo-por-nome "Jogo por Nome" jogo-por-nome
jogo meow-steam-12345 "Jogo da Steam" steam_icon_12345
desktop programa-curado "Programa Curado" programa-curado
printf 'programa-curado\tsvg\tscalable/apps\n' > "$T/raiz/assets/icones/curadoria.map" || exit 2

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
M.DIRS_DESKTOP = ((os.path.join(casa, ".local", "share", "applications"), "pessoal"),)
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
    """O «Levar para o pack» (P73): o gesto explícito que grava no mapa dele.
    Era o «Usar este ícone» até a P73 — o nome ficou, e as seções abaixo
    cobram o que a P60 e a P64 cobravam do mapa do pack."""
    return chamar(m._api_app_icone, {"app": app, "pack": pack, "desenho": desenho})


def usar(app, arquivo):
    """O «Usar este ícone» depois da P73: a escolha no estado de quem usa."""
    return chamar(m._api_app_icone, {"app": app, "arquivo": arquivo})


escolhas = os.path.join(casa, ".config", "meow", "icones-escolhidos.map")


def conf_com(**chaves):
    with open(conf, "a", encoding="utf-8") as fh:
        fh.write("".join('%s="%s"\n' % kv for kv in chaves.items()))


def texto(caminho):
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


r = glifos("alien")
do_pack = [g for g in r.get("glifos", []) if g.get("pack")]
print("  «alien»: %d opção(ões) — %s" % (len(r.get("glifos", [])), ", ".join(
    "%s (%s)" % (g["glifo"], g["grupo"]) for g in r.get("glifos", [])) or "nenhuma"))
achado = next((g for g in do_pack if g["glifo"] == "alien"), None)
checa(achado and achado["grupo"] == "pack:dracula:biblioteca"
      and achado["desenho"] == "biblioteca/alien.svg"
      and achado["arquivo"] == "packs/dracula/icones/biblioteca/alien.svg",
      "«alien» acha o desenho da biblioteca do Dracula, na pasta da biblioteca do pack",
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
checa({"pack:dracula:apps", "pack:meowsystem:apps"} <= grupos,
      "«chrome» oferece o google-chrome do Dracula e o do Arcticons, cada um na sua pasta",
      repr(sorted(grupos)))

vazia = glifos("")
por_grupo = {}
for g in vazia.get("glifos", []):
    por_grupo[g["grupo"]] = por_grupo.get(g["grupo"], 0) + 1
checa(not vazia.get("limitado") and vazia.get("grupos")
      and all(por_grupo.get(gr["id"], 0) == gr["total"] for gr in vazia["grupos"])
      and por_grupo.get("pack:dracula:biblioteca", 0) > 60,
      "a busca vazia traz o acervo inteiro, sem teto: cada pasta com o total que ela diz",
      repr({gr["id"]: (por_grupo.get(gr["id"], 0), gr["total"]) for gr in vazia.get("grupos", [])}))

ordem = [gr["id"] for gr in vazia.get("grupos", [])]
do_ar = [i for i, gid in enumerate(ordem) if gid.startswith("pack:dracula:")]
de_fora = [i for i, gid in enumerate(ordem) if gid.startswith("pack:meowsystem:")]
checa(do_ar and de_fora and max(do_ar) < min(de_fora),
      "com o Dracula no ar, o pack padrão aparece na pasta dele, depois das do Dracula", repr(ordem))
checa({"pack:dracula:autorais:dracula", "pack:dracula:autorais:alucard"} <= set(ordem),
      "os autorais do pack vêm nos dois flavors, cada um na sua pasta", repr(ordem))
checa(all(g["grupo"].startswith("pack:dracula:") for g in vazia["glifos"] if g.get("pack")),
      "só o desenho do pack no ar pode ser levado ao mapa dele")

with open(mapa, encoding="utf-8") as fh:
    antes = fh.read().split("\n")
codigo, dados = usar("google-chrome", "packs/dracula/icones/biblioteca/alien.svg")
with open(mapa, encoding="utf-8") as fh:
    checa(codigo == 200 and fh.read().split("\n") == antes,
          "o «Usar este ícone» com o alien não muda um byte do apps.map do Dracula", repr(dados))
with open(escolhas, encoding="utf-8") as fh:
    linha_minha = fh.read()
checa(linha_minha == "google-chrome : packs/dracula/icones/biblioteca/alien.svg   "
                     "# Chrome de Brinquedo — escolhido no painel\n",
      "a escolha mora no icones-escolhidos.map de quem usa, no formato dos mapas", repr(linha_minha))
rc, saida = passo_do_pack()
checa(rc in (0, 1) and texto(os.path.join(tema, "google-chrome.svg")) == texto(alien),
      "a ação `icones_pack` põe no tema o alien escolhido no estado (rc=%s)" % rc, saida[-600:])
r = chamar(m._api_glifos, {"busca": [""], "app": ["google-chrome"]})[1]
checa((r.get("minha") or {}).get("desenho") == "biblioteca/alien.svg",
      "a ficha diz a escolha de quem usa, e que ela pode ser levada ao pack", repr(r.get("minha")))
codigo, dados = escolher("google-chrome", "biblioteca/alien.svg")
checa(codigo == 200 and dados.get("ok") and dados.get("nome_pack") == "Dracula",
      "o «Levar para o pack» com o alien grava a escolha no pack Dracula", repr(dados))
with open(escolhas, encoding="utf-8") as fh:
    checa(fh.read() == "", "e a escolha sai do estado de quem usa: a linha do pack é ela")
with open(mapa, encoding="utf-8") as fh:
    depois = fh.read().split("\n")
mudou = [i for i, (a, b) in enumerate(zip(antes, depois)) if a != b]
checa(len(antes) == len(depois) and len(mudou) == 1
      and depois[mudou[0]] == ("google-chrome : biblioteca/alien.svg   # Chrome de Brinquedo — "
                               "escolhido no painel; antes: " + antes[mudou[0]])
      and antes[mudou[0]] == "google-chrome : apps/google-chrome.svg   # Google Chrome [alias-heuristico]",
      "no apps.map do Dracula só a linha do google-chrome muda, e ela diz de onde veio e a que trocou",
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
jogos = {a["id"]: a for a in servidor.Manipulador._dados_jogos(m, {}).get("apps", [])}
por_caminho = jogos.get("jogo-de-brinquedo") or {}
codigo, dados = escolher("jogo-de-brinquedo", "biblioteca/alien.svg")
checa(por_caminho.get("trava_pack") and codigo == 409
      and dados.get("erro") == por_caminho["trava_pack"],
      "a grade de jogos diz a trava do pack no jogo de ícone por caminho, com a "
      "frase do 409 que o «Usar este ícone» ouviria (%s)" % codigo,
      repr((por_caminho.get("trava_pack"), dados)))
por_nome = jogos.get("jogo-por-nome") or {}
checa("trava_pack" in por_nome and por_nome["trava_pack"] is None,
      "e manda o campo vazio no jogo de ícone por nome, onde o pack vale", repr(por_nome))

conf_com(ICONES_DRACULA="nao")
r = glifos("alien")
esquema = servidor.ler_esquema()
servidor._com_o_vocabulario_do_pack(esquema, servidor.vocabulario_do_pack(), {})
titulo = next((i.get("titulo") for i in esquema if i["chave"] == "ICONES_DRACULA"), None)
checa([g for g in r.get("glifos", []) if g["glifo"] == "alien"] and r.get("aviso")
      and titulo and ("«%s»" % titulo) in r["aviso"],
      "com a camada desligada o alien continua na ficha (P73), e o aviso aponta o cartão "
      "pelo título da tela", repr((r.get("aviso"), titulo)))
codigo, dados = escolher("google-chrome", "biblioteca/alien.svg")
checa(codigo == 409 and dados.get("erro") == r.get("aviso"),
      "e levar para o pack com ela desligada é recusado com a mesma frase (%s)" % codigo)
conf_com(ICONES_DRACULA="sim")

catppuccin = os.path.join(raiz, "packs", "catppuccin")
antes_c = arvore(catppuccin)
conf_com(PACK="meowsystem", FLAVOR="mocha")
r = glifos("alien")
checa([g for g in r.get("glifos", []) if g["glifo"] == "alien" and not g.get("pack")]
      and not [g for g in r.get("glifos", []) if g.get("pack")],
      "com o Catppuccin no ar, «alien» ainda acha o do Dracula (decisão 3), sem o "
      "«Levar para o pack» — o pack no ar não tem mapa", repr(r.get("glifos")))
r = glifos("chrome")
checa(r.get("grupos") and r["grupos"][0]["id"].startswith("pack:meowsystem:"),
      "e o pack no ar passa a ser o primeiro da ficha",
      repr([gr["id"] for gr in r.get("grupos", [])][:3]))
codigo, dados = escolher("google-chrome", "biblioteca/alien.svg")
checa(codigo == 409, "uma página de antes da troca não grava no mapa do Dracula (%s)" % codigo)
rc, saida = passo_do_pack()
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

def glifos_de(app, busca="chrome"):
    return chamar(m._api_glifos, {"busca": [busca], "app": [app]})[1]


def desfazer(app, pack="dracula"):
    return chamar(m._api_app_icone, {"app": app, "pack": pack, "remover": True})


def mapa_agora():
    with open(mapa, encoding="utf-8") as fh:
        return fh.read().split("\n")


r = glifos_de("google-chrome")
checa(r.get("pack") == {"id": "dracula", "nome": "Dracula"}
      and r.get("escolha") == {"pack": "dracula", "nome_pack": "Dracula",
                               "desenho": "biblioteca/alien.svg", "antes": "apps/google-chrome.svg"},
      "a busca da ficha do Chrome diz a escolha do painel no pack, e o desenho que ela trocou",
      repr((r.get("pack"), r.get("escolha"))))
checa((glifos_de("programa-de-brinquedo").get("escolha") or {}).get("antes", "?") is None
      and glifos_de("com.system76.CosmicFiles").get("escolha") is None,
      "a do programa novo não trocou desenho nenhum, e o «Arquivos» não tem escolha")

traco_projeto = os.path.join(raiz, "packs", "meowsystem", "icones", "apps-arcticons.map")
antes_traco = texto(traco_projeto)
codigo, dados = chamar(m._api_app_icone, {"app": "google-chrome", "remover": True})
fica = dados.get("fica") or {}
checa(codigo == 200 and dados.get("removido") is False and fica.get("tipo") == "pack"
      and fica.get("frase") == "o desenho «alien» do pack «Dracula»"
      and texto(traco_projeto) == antes_traco,
      "tirar o traço do Chrome não mexe no mapa do projeto, e diz que fica o desenho do "
      "pack, e não o de fábrica", repr(dados))

codigo, dados = desfazer("google-chrome")
checa(codigo == 200 and dados.get("removido")
      and (dados.get("fica") or {}).get("frase") == "o desenho «google-chrome» do pack «Dracula»",
      "desfazer a escolha do Chrome devolve o desenho que o pack dava, e o diz", repr(dados))
codigo, dados = desfazer("programa-de-brinquedo")
fica = dados.get("fica") or {}
checa(codigo == 200 and dados.get("removido") and fica.get("tipo") == "fabrica",
      "desfazer a do programa que o pack não conhecia tira a linha, e a resposta diz o ícone "
      "que fica depois do passo do pack: o de fábrica", repr(dados))
checa(mapa_agora() == antes,
      "sem as duas escolhas, o apps.map do Dracula volta byte a byte ao que era")
rc, saida = conferir()
checa(rc == 1 and "programa-de-brinquedo.svg (desenho que saiu do mapa do pack no ar)" in saida,
      "antes do passo, o --conferir diz que apagaria o arcade do programa, e por quê (rc=%s)" % rc,
      saida[-600:])
rc, saida = passo_do_pack()
checa(texto(os.path.join(tema, "google-chrome.svg"))
      == texto(os.path.join(icones, "apps", "google-chrome.svg")) is not None,
      "o passo do pack põe no tema o desenho que o pack dava ao Chrome (rc=%s)" % rc, saida[-600:])
checa(not os.path.exists(os.path.join(tema, "programa-de-brinquedo.svg")),
      "e tira do tema o arcade do programa que saiu do mapa no ar — o ícone de fábrica que a "
      "resposta disse", saida[-600:])
rc, saida = conferir()
checa(rc == 0, "e o --conferir do passo sai 0 depois dele (rc=%s)" % rc, saida[-600:])

codigo, dados = desfazer("google-chrome")
checa(codigo == 200 and dados.get("removido") is False and mapa_agora() == antes,
      "desfazer sem escolha no pack não mexe no mapa", repr(dados))
codigo, dados = desfazer("google-chrome", pack="catppuccin")
checa(codigo == 409, "desfazer no mapa de um pack fora do ar é recusado (%s)" % codigo, repr(dados))

escolher("google-chrome", "biblioteca/alien.svg")
codigo, dados = escolher("google-chrome", "biblioteca/arcade.svg")
desfazer("google-chrome")
checa(codigo == 200 and mapa_agora() == antes,
      "duas escolhas seguidas e um desfazer: o mapa volta ao do pack, byte a byte")

apps = {a["id"]: a for a in servidor.Manipulador._dados_apps(m, {}).get("apps", [])}
calc = apps.get("org.gnome.Calculator") or {}
codigo, dados = escolher("org.gnome.Calculator", "biblioteca/alien.svg")
checa(calc.get("trava") and calc.get("trava_pack") is None and codigo == 200,
      "a Calculadora, com a trava do traço e sem a do pack, aceita o desenho do pack (%s)" % codigo,
      repr((calc.get("trava"), dados)))
desfazer("org.gnome.Calculator")
checa(mapa_agora() == antes, "e o desfazer dela devolve o mapa do pack")

jogos = {a["id"]: a for a in servidor.Manipulador._dados_jogos(m, {}).get("apps", [])}
apps = {a["id"]: a for a in servidor.Manipulador._dados_apps(m, {}).get("apps", [])}
for app, grade, caso in (("meow-steam-12345", jogos, "o jogo da Steam, intocável"),
                         ("programa-curado", apps, "o programa com arte da curadoria")):
    a = grade.get(app) or {}
    codigo, dados = escolher(app, "biblioteca/alien.svg")
    checa(a.get("trava") and a.get("trava_pack") == a.get("trava")
          and codigo == 409 and dados.get("erro") == a["trava_pack"] and mapa_agora() == antes,
          "%s: a grade diz a trava do pack com a frase da do traço, e o POST a devolve no 409 "
          "sem mexer no mapa (%s)" % (caso, codigo),
          repr((a.get("trava"), a.get("trava_pack"), codigo, dados)))

codigo, dados = usar("programa-de-brinquedo", "packs/dracula/icones/biblioteca/alien.svg")
rc, saida = passo_do_pack()
checa(codigo == 200 and texto(os.path.join(tema, "programa-de-brinquedo.svg")) == texto(alien),
      "o programa veste o alien escolhido como desenho (rc=%s)" % rc, repr(dados) + saida[-400:])
codigo, dados = chamar(m._api_app_icone, {"app": "programa-de-brinquedo", "cor": "mauve",
                                          "arquivo": "packs/meowsystem/icones/apps/firefox.svg"})
with open(escolhas, encoding="utf-8") as fh:
    sobrou = [l for l in fh if l.startswith("programa-de-brinquedo ")]
checa(codigo == 200 and dados.get("tirou_escolha") is True and not sobrou
      and m._o_que_fica("programa-de-brinquedo").get("tipo") != "escolha",
      "o traço escolhido depois tira a escolha de desenho do estado, e a resposta diz que tirou",
      repr((codigo, dados, sobrou)))
rc, saida = passo_do_pack()
checa(not os.path.exists(os.path.join(tema, "programa-de-brinquedo.svg")),
      "e o passo do pack tira o desenho do `scalable/apps`, para o traço aparecer (rc=%s)" % rc,
      saida[-400:])
codigo, dados = chamar(m._api_app_icone, {"app": "programa-de-brinquedo", "cor": "mauve",
                                          "arquivo": "packs/meowsystem/icones/apps/firefox.svg"})
checa(codigo == 200 and dados.get("tirou_escolha") is False,
      "sem escolha de desenho, o traço não diz que tirou nada", repr(dados))

if falhas:
    print("FALHOU: os desenhos do pack na ficha de ícone:", file=sys.stderr)
    for linha in falhas:
        print("    " + linha, file=sys.stderr)
    sys.exit(1)
print("ok: o acervo inteiro aparece na ficha, a escolha mora com quem usa, e só o gesto a leva ao pack")
PY

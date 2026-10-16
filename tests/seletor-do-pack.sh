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
#      a frase que aponta o cartão pelo título que ele tem na tela. E as duas
#      grades que abrem a ficha (Aplicativos, e Lançadores e jogos) mandam a
#      trava do pack que o POST aplica.
#   5. Trocar para o Catppuccin não carrega a escolha: a busca não oferece o
#      Dracula, o passo do pack tira do tema o que o Dracula tinha posto, o
#      Catppuccin não ganha arquivo nenhum — e a escolha volta com o Dracula.
#   [09/10/2026, P73 — o que mudou, e as seções acima dizem a regra nova:
#    · a ficha mostra TODOS os acervos, de todos os packs, em pastas (a decisão
#      3 de 09/10 revoga a regra da P60 do item 2): o Catppuccin aparece com o
#      Dracula no ar, depois dele; e a camada desligada não tira nada da ficha;
#    · o «Usar este ícone» grava no estado de quem usa (`icones-escolhidos.map`,
#      ao lado do meow.conf), e o mapa do pack só muda pelo gesto explícito
#      «Levar para o pack» (a regressão I3). O item 3 confere as duas metades:
#      escolher não toca o mapa; levar troca a linha, como a P60 trocava.]
#   6. (P64, 25/09/2026) A escolha tem desfazer: a linha do painel leva a que
#      ela trocou, e desfazer a devolve — o mapa volta byte a byte. A resposta
#      diz o ícone que fica, e o «Desfazer a escolha no traço» de um app que
#      está nos dois mapas não diz mais «de fábrica». E a trava do traço não
#      recusa o desenho do pack — só a do convertido: o intocável e a curadoria
#      travam os dois, na grade e no POST (revisão da P64).
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
# E um com a trava do TRAÇO (P64): a Calculadora tem desenho convertido no
# `apps-convertidos.map`, e nenhum outro dono do `scalable/apps`.
desktop org.gnome.Calculator "Calculadora de Brinquedo" org.gnome.Calculator
# E dois jogos, que a aba «Lançadores e jogos» mostra com a MESMA ficha: um com
# o `Icon=` por caminho de arquivo, onde o desenho do pack não vale, e um com
# nome de ícone, onde vale. Revisão da P60: a grade de jogos não mandava a trava
# do pack, e a ficha do primeiro oferecia o Dracula que o POST recusa com 409.
jogo() {   # jogo <arquivo> <Name> <Icon>
  printf '[Desktop Entry]\nName=%s\nExec=true\nIcon=%s\nTerminal=false\nType=Application\nCategories=Game;\n' \
    "$2" "$3" > "$CASA/.local/share/applications/$1.desktop"
}
jogo jogo-de-brinquedo "Jogo de Brinquedo" "$CASA/jogo.svg"
jogo jogo-por-nome "Jogo por Nome" jogo-por-nome
# E os dois casos da trava do traço que travam o pack também (revisão da P64):
# um jogo da Steam, intocável pelo prefixo `steam_icon_` da lista do script, e
# um programa com a arte que ela escolheu na curadoria — a linha como o
# `importar_icones.sh` a escreve, no `curadoria.map` da raiz de brinquedo.
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
checa({"pack:dracula:apps", "pack:meowsystem:apps/arcticons"} <= grupos,
      "«chrome» oferece o google-chrome do Dracula e o do Arcticons, cada um na sua pasta",
      repr(sorted(grupos)))

# SEM TETO (P73): a busca vazia traz tudo, e cada pasta diz o total dela.
vazia = glifos("")
por_grupo = {}
for g in vazia.get("glifos", []):
    por_grupo[g["grupo"]] = por_grupo.get(g["grupo"], 0) + 1
checa(not vazia.get("limitado") and vazia.get("grupos")
      and all(por_grupo.get(gr["id"], 0) == gr["total"] for gr in vazia["grupos"])
      and por_grupo.get("pack:dracula:biblioteca", 0) > 60,
      "a busca vazia traz o acervo inteiro, sem teto: cada pasta com o total que ela diz",
      repr({gr["id"]: (por_grupo.get(gr["id"], 0), gr["total"]) for gr in vazia.get("grupos", [])}))

# --- 2. todos os acervos, o pack no ar primeiro (P73, decisão 3) ------------
# [Até a P73 este bloco cobrava o contrário: nenhum grupo de pack fora do ar.]
ordem = [gr["id"] for gr in vazia.get("grupos", [])]
do_ar = [i for i, gid in enumerate(ordem) if gid.startswith("pack:dracula:")]
de_fora = [i for i, gid in enumerate(ordem) if gid.startswith("pack:catppuccin:")]
checa(do_ar and de_fora and max(do_ar) < min(de_fora),
      "com o Dracula no ar, o Catppuccin aparece na pasta dele, depois das do Dracula", repr(ordem))
checa({"pack:dracula:autorais:dracula", "pack:dracula:autorais:alucard"} <= set(ordem),
      "os autorais do pack vêm nos dois flavors, cada um na sua pasta", repr(ordem))
# Só o que é do mapa do pack no ar traz `pack`/`desenho` (o «Levar para o pack»).
checa(all(g["grupo"].startswith("pack:dracula:") for g in vazia["glifos"] if g.get("pack")),
      "só o desenho do pack no ar pode ser levado ao mapa dele")

# --- 3. escolher o alien grava a linha, e o passo o põe no tema ---------------
with open(mapa, encoding="utf-8") as fh:
    antes = fh.read().split("\n")
# O «USAR ESTE ÍCONE» NÃO TOCA O MAPA (P73, I3): a escolha vai para o estado de
# quem usa, e o passo do pack a põe no tema.
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
# O «LEVAR PARA O PACK» é o gesto que grava no mapa: o mesmo POST da P60.
codigo, dados = escolher("google-chrome", "biblioteca/alien.svg")
checa(codigo == 200 and dados.get("ok") and dados.get("nome_pack") == "Dracula",
      "o «Levar para o pack» com o alien grava a escolha no pack Dracula", repr(dados))
with open(escolhas, encoding="utf-8") as fh:
    checa(fh.read() == "", "e a escolha sai do estado de quem usa: a linha do pack é ela")
with open(mapa, encoding="utf-8") as fh:
    depois = fh.read().split("\n")
mudou = [i for i, (a, b) in enumerate(zip(antes, depois)) if a != b]
# P64: a linha diz também a que ela trocou, inteira — é o que o desfazer devolve.
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
# A GRADE DE JOGOS ABRE A MESMA FICHA, E A TELA E A RECUSA DIZEM A MESMA FRASE.
# O campo tem de vir nos dois jogos: ausente, a ficha lê "sem trava" e oferece
# o pack. Com a camada ligada, para o POST chegar à trava do app.
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

# --- 5. trocar para o Catppuccin não carrega a escolha ------------------------
catppuccin = os.path.join(raiz, "packs", "catppuccin")
antes_c = arvore(catppuccin)
conf_com(PACK="catppuccin", FLAVOR="mocha")
r = glifos("alien")
checa([g for g in r.get("glifos", []) if g["glifo"] == "alien" and not g.get("pack")]
      and not [g for g in r.get("glifos", []) if g.get("pack")],
      "com o Catppuccin no ar, «alien» ainda acha o do Dracula (decisão 3), sem o "
      "«Levar para o pack» — o pack no ar não tem mapa", repr(r.get("glifos")))
r = glifos("chrome")
checa(r.get("grupos") and r["grupos"][0]["id"].startswith("pack:catppuccin:"),
      "e o pack no ar passa a ser o primeiro da ficha",
      repr([gr["id"] for gr in r.get("grupos", [])][:3]))
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

# --- 6. desfazer a escolha, e o ícone que fica — P64 ---------------------------
# Aqui o mapa do Dracula tem as duas escolhas da seção 3: a do Chrome, que
# trocou a linha dele, e a do programa, que o pack não conhecia.
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

# O CHROME ESTÁ NOS DOIS MAPAS: tirar o traço deixa o desenho do pack na tela,
# e a torrada dizia «voltou para o ícone de fábrica».
# [P73: o «Desfazer a escolha no traço» só tira a linha de QUEM USA — a do
# `apps-arcticons.map` do projeto é curadoria, e não sai por clique. O Chrome
# de brinquedo não tem escolha de traço: nada sai, e a resposta continua
# dizendo o que fica na tela, que é o ponto da P64.]
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
# O arcade do programa está no tema desde a seção 5 (a volta ao Dracula o repôs).
# Desfeita a escolha, o nome sai do mapa no ar — e o passo do pack o tira do
# tema, pelo registro do que ele pôs lá (P66, 25/09/2026). Até a P66 a resposta
# dizia `sobra` («continua no tema»), e este bloco era o defeito conhecido que o
# `_dracula_sobras` não tirava: ele só olhava os mapas dos packs fora do ar.
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

# ESCOLHER DUAS VEZES: o desfazer volta ao desenho do PACK, e não ao da
# primeira escolha — a linha trocada viaja de uma escolha para a outra.
escolher("google-chrome", "biblioteca/alien.svg")
codigo, dados = escolher("google-chrome", "biblioteca/arcade.svg")
desfazer("google-chrome")
checa(codigo == 200 and mapa_agora() == antes,
      "duas escolhas seguidas e um desfazer: o mapa volta ao do pack, byte a byte")

# A TRAVA DO TRAÇO NÃO É A DO PACK. A Calculadora tem desenho convertido — o
# glifo do Arcticons não vale nela —, e o desenho do pack vai para o
# `scalable/apps`, que vence o traço. A ficha oferece o pack, e o POST aceita.
apps = {a["id"]: a for a in servidor.Manipulador._dados_apps(m, {}).get("apps", [])}
calc = apps.get("org.gnome.Calculator") or {}
codigo, dados = escolher("org.gnome.Calculator", "biblioteca/alien.svg")
checa(calc.get("trava") and calc.get("trava_pack") is None and codigo == 200,
      "a Calculadora, com a trava do traço e sem a do pack, aceita o desenho do pack (%s)" % codigo,
      repr((calc.get("trava"), dados)))
desfazer("org.gnome.Calculator")
checa(mapa_agora() == antes, "e o desfazer dela devolve o mapa do pack")

# O INTOCÁVEL E A CURADORIA TRAVAM O PACK — revisão da P64. Dos três casos da
# trava do traço, só o convertido mora no `48x48/apps`. O intocável é pedido
# dela, e a arte da curadoria mora no mesmo `scalable/apps` do pack; o
# `icones_apps_dracula.sh` não cede a nenhum dos dois, e a linha no mapa poria
# o desenho do pack por cima. A grade manda a frase na `trava_pack` (é ela que
# esconde a busca na ficha), e o POST a devolve no 409, sem tocar no mapa.
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

# O TRAÇO ESCOLHIDO DEPOIS DE UM DESENHO É O QUE FICA — conferência da P73. A
# escolha de desenho vai para o `scalable/apps`, que vence o `48x48/apps` do
# traço: com as duas linhas no estado de quem usa, o «Usar este ícone» do traço
# respondia ok e a tela continuava com o desenho. A última escolha vale.
codigo, dados = usar("programa-de-brinquedo", "packs/dracula/icones/biblioteca/alien.svg")
rc, saida = passo_do_pack()
checa(codigo == 200 and texto(os.path.join(tema, "programa-de-brinquedo.svg")) == texto(alien),
      "o programa veste o alien escolhido como desenho (rc=%s)" % rc, repr(dados) + saida[-400:])
codigo, dados = chamar(m._api_app_icone, {"app": "programa-de-brinquedo", "cor": "mauve",
                                          "arquivo": "packs/meowsystem/icones/apps/arcticons/firefox.svg"})
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
                                          "arquivo": "packs/meowsystem/icones/apps/arcticons/firefox.svg"})
checa(codigo == 200 and dados.get("tirou_escolha") is False,
      "sem escolha de desenho, o traço não diz que tirou nada", repr(dados))

if falhas:
    print("FALHOU: os desenhos do pack na ficha de ícone:", file=sys.stderr)
    for linha in falhas:
        print("    " + linha, file=sys.stderr)
    sys.exit(1)
print("ok: o acervo inteiro aparece na ficha, a escolha mora com quem usa, e só o gesto a leva ao pack")
PY

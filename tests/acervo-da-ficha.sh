#!/usr/bin/env bash
# acervo-da-ficha.sh — a ficha de ícone oferece o acervo inteiro, em pastas.
# Sprint P73, 09/10/2026.
#
# A QUEIXA QUE ABRIU ISTO
#   «Era pra aparecerem todos os Drácula feitos e todos os do MeowSystem
#   feitos, numa pasta cada. Independente do app que eu escolher, eu deveria
#   acessar todas as imagens disponíveis, não só as que mapeamos à mão.»
#   Medido na auditoria de 09/10 (docs/pesquisas/2026-10-09-paridade-de-
#   icones.md): no máximo 120 desenhos por tela, a ficha aberta com a 1ª
#   palavra do nome do app como filtro, e 146 dos 591 desenhos versionados
#   distintos nunca oferecidos.
#
# O QUE ELE COBRA — a prova da spec da P73
#   1. Para cada pasta de acervo, o total que a ficha oferece é o número de
#      SVG (ou PNG, na pasta dos feitos à mão) da pasta, contado AQUI, no disco,
#      e não pela função que monta a ficha. E nenhuma pasta de desenho do
#      repositório fica sem grupo, fora as excluídas de propósito.
#   2. Por sha256: os desenhos versionados menos os oferecíveis só deixam
#      `pastas/`, `assets/gatos/`, os `logo.svg` e a folha de antes e depois
#      dos resgatados (que é comparação, e não ícone).
#   3. A busca acha pelo nome do app e pelo significado: «firefox» acha o
#      `apps/net.waterfox.waterfox.svg`; «alienígena» acha o `alien.svg`.
#   4. Abrir a ficha sem busca não corta nada (`limitado` falso) e o nome do
#      app vira destaque (`sugerido`), não filtro.
#
# NÃO ESCREVE NADA: as rotas são chamadas no processo, no molde do
#   tests/oficina.sh, com o HOME de brinquedo; o repositório só é lido.
#
# CÓDIGOS DE SAÍDA (os do projeto)
#   0 = tudo cobrado passou · 1 = achados · 2 = erro deste teste · 3 = pulado.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 3; }
command -v git >/dev/null 2>&1 || { printf 'pulado: sem git para listar o versionado\n'; exit 3; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
CASA="$T/casa"
mkdir -p "$CASA/.config/meow" "$CASA/.local/share/applications" "$CASA/.local/state/meowsystem" || exit 2
cp "$RAIZ/meow.conf.exemplo" "$CASA/.config/meow/meow.conf" || exit 2
printf '\nPACK="dracula"\nFLAVOR="dracula"\nICONES_DRACULA="sim"\n' >> "$CASA/.config/meow/meow.conf"
printf '[Desktop Entry]\nName=Firefox\nExec=true\nIcon=firefox\nType=Application\n' \
  > "$CASA/.local/share/applications/firefox.desktop"

env -u MEOW_PACK_DIR -u PACK -u FLAVOR -u ICONES_DRACULA -u MEOW_PACKS \
    HOME="$CASA" MEOW_CONF="$CASA/.config/meow/meow.conf" XDG_CONFIG_HOME="$CASA/.config" \
    XDG_DATA_HOME="$CASA/.local/share" XDG_STATE_HOME="$CASA/.local/state" \
    MEOW_ESTADO="$CASA/.local/state/meowsystem" PYTHONDONTWRITEBYTECODE=1 \
    python3 - "$RAIZ" "$CASA" <<'PY'
import hashlib
import os
import subprocess
import sys
from urllib.parse import unquote

raiz, casa = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor  # noqa: E402

M = servidor.Manipulador
M.DIRS_DESKTOP = ((os.path.join(casa, ".local", "share", "applications"), "usuária"),)
m = M.__new__(M)
resposta = {}
m._json = lambda dados, codigo=200: resposta.update(dados=dados, codigo=codigo)
falhas = []


def checa(cond, frase, detalhe=""):
    if cond:
        print("ok: " + frase)
    else:
        falhas.append(frase + (" — " + detalhe if detalhe else ""))
    return cond


def glifos(busca="", app=""):
    resposta.clear()
    m._api_glifos({"busca": [busca], "app": [app]})
    return resposta.get("dados") or {}


def sha(caminho):
    with open(caminho, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def caminho_de(item):
    return os.path.normpath(unquote(item["url"].split("id=", 1)[1]))


vazia = glifos("", "firefox")
grupos = vazia.get("grupos") or []
itens = vazia.get("glifos") or []

# --- 1. cada pasta: o que a ficha oferece é o que o disco tem --------------------
# A conta do disco é feita aqui, com `os.listdir`, sobre a pasta de cada item
# oferecido: o teste não pergunta ao `acervos_de_icone` quanto ele mesmo achou.
por_pasta = {}
for it in itens:
    por_pasta.setdefault(os.path.dirname(caminho_de(it)), []).append(it)
for pasta, deles in sorted(por_pasta.items()):
    ext = ".png" if deles[0]["tipo"] == "png" else ".svg"
    no_disco = sorted(a for a in os.listdir(pasta)
                      if a.lower().endswith(ext) and not a.startswith(".")
                      and os.path.isfile(os.path.join(pasta, a)) and a != "ANTES-E-DEPOIS.png")
    oferecidos = sorted(os.path.basename(caminho_de(it)) for it in deles)
    checa(oferecidos == no_disco,
          "%s: a ficha oferece %d, o disco tem %d" % (os.path.relpath(pasta, raiz), len(oferecidos),
                                                      len(no_disco)),
          "faltam %s" % sorted(set(no_disco) - set(oferecidos))[:6])
soma = {}
for g in grupos:
    soma[g["id"]] = g["total"]
contados = {}
for it in itens:
    contados[it["grupo"]] = contados.get(it["grupo"], 0) + 1
checa(soma == contados, "o total que cada pasta anuncia é o número de itens dela", repr(
    {k: (soma.get(k), contados.get(k)) for k in set(soma) | set(contados) if soma.get(k) != contados.get(k)}))

# Nenhuma pasta de desenho do repositório sem grupo — fora as excluídas de
# propósito (ver "O ACERVO DA FICHA DE ÍCONE, DECLARADO NUM LUGAR SÓ", no
# scripts/pack.py): pastas e mimetypes (não são ícone de app), o
# `previa-arcticons/` (os mesmos bytes de outra pasta), o `upstream/`
# (papirus-folders, fora do git) e o `tray-terceiros/` (originais de bandeja).
FORA = {"pastas", "mimetypes", "previa-arcticons", "upstream", "tray-terceiros"}
versionados = subprocess.run(["git", "-C", raiz, "ls-files", "packs", "assets/icones"],
                             capture_output=True, text=True).stdout.split()
sem_grupo = set()
for rel in versionados:
    if not rel.lower().endswith((".svg", ".png")) or rel.endswith("logo.svg"):
        continue
    partes = rel.split("/")
    if FORA & set(partes) or os.path.basename(rel) == "ANTES-E-DEPOIS.png" or "temas" in partes:
        continue
    if os.path.normpath(os.path.dirname(os.path.join(raiz, rel))) not in por_pasta:
        sem_grupo.add(os.path.dirname(rel))
checa(not sem_grupo, "toda pasta de desenho versionada tem a sua pasta na ficha", repr(sorted(sem_grupo)))

# --- 2. versionados − oferecíveis, por sha256 ----------------------------------
oferecidos = {sha(caminho_de(it)) for it in itens}
sobra = {}
for rel in subprocess.run(["git", "-C", raiz, "ls-files", "packs", "assets/icones", "assets/gatos"],
                          capture_output=True, text=True).stdout.split():
    if not rel.lower().endswith((".svg", ".png")) or "/mimetypes/" in rel or "/temas/" in rel:
        continue
    h = sha(os.path.join(raiz, rel))
    if h not in oferecidos:
        sobra.setdefault(h, rel)
fora_da_regra = sorted(r for r in sobra.values()
                       if not ("/icones/pastas/" in r or r.startswith("assets/gatos/")
                               or r.endswith("/logo.svg") or r.endswith("resgatados/ANTES-E-DEPOIS.png")))
print("  versionados únicos menos oferecíveis: %d — %s" % (
    len(sobra), ", ".join(sorted({r.rsplit("/", 1)[0] if not r.endswith("logo.svg") else "logo.svg"
                                  for r in sobra.values()}))))
checa(not fora_da_regra,
      "a conta versionados − oferecíveis só deixa pastas/, gatos/, logo.svg e a folha dos resgatados",
      repr(fora_da_regra[:10]))

# --- 3. a busca pelo nome do app e pelo significado ------------------------------
achados = {os.path.relpath(caminho_de(it), raiz) for it in glifos("firefox").get("glifos", [])}
checa("packs/dracula/icones/apps/net.waterfox.waterfox.svg" in achados,
      "«firefox» acha o net.waterfox.waterfox.svg (o Firefox-Dracula, pelo comentário do apps.map)",
      repr(sorted(achados)[:8]))
achados = {os.path.relpath(caminho_de(it), raiz) for it in glifos("alienígena").get("glifos", [])}
checa("packs/dracula/icones/biblioteca/alien.svg" in achados,
      "«alienígena» acha o alien.svg (pela descrição do catalog.json)", repr(sorted(achados)))
achados2 = {os.path.relpath(caminho_de(it), raiz) for it in glifos("alienigena").get("glifos", [])}
checa(achados2 == achados, "e «alienigena», sem acento, acha o mesmo")

# --- 4. sem teto, e o nome do app é destaque -------------------------------------
checa(vazia.get("limitado") is False and len(itens) == sum(soma.values()) and len(itens) > 120,
      "a ficha aberta sem busca traz %d desenhos, sem corte" % len(itens))
sugeridos = [it["glifo"] for it in itens if it.get("sugerido")]
checa("net.waterfox.waterfox" in sugeridos and len(sugeridos) < len(itens),
      "o nome do app acende os sugeridos (%d) sem filtrar o resto" % len(sugeridos), repr(sugeridos[:8]))
ordem = [g["id"] for g in grupos]
checa(ordem and ordem[0].startswith("pack:dracula:")
      and any(g.startswith("pack:catppuccin:") for g in ordem)
      and any(g.startswith("motor:") for g in ordem),
      "o pack no ar vem primeiro, e os outros packs e o motor vêm depois, cada um na sua pasta",
      repr(ordem))

if falhas:
    print("FALHOU: o acervo da ficha de ícone:", file=sys.stderr)
    for linha in falhas:
        print("    " + linha, file=sys.stderr)
    sys.exit(1)
print("ok: a ficha oferece o acervo inteiro, uma pasta por acervo, e a busca acha pelo nome e pelo sentido")
PY

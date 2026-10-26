#!/usr/bin/env bash
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
DIRS_DE_FABRICA = M.DIRS_DESKTOP
M.DIRS_DESKTOP = ((os.path.join(casa, ".local", "share", "applications"), "pessoal"),)
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

por_pasta = {}
for it in itens:
    ext = ".png" if it["tipo"] == "png" else ".svg"
    por_pasta.setdefault((os.path.dirname(caminho_de(it)), ext), []).append(it)
for (pasta, ext), deles in sorted(por_pasta.items()):
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

FORA = {"pastas", "mimetypes", "previa-arcticons", "upstream", "tray-terceiros", "wallpapers",
        "sistema", "mascote"}
versionados = subprocess.run(["git", "-C", raiz, "ls-files", "packs", "assets/icones"],
                             capture_output=True, text=True).stdout.split()
sem_grupo = set()
for rel in versionados:
    if not rel.lower().endswith((".svg", ".png")) or rel.endswith("logo.svg"):
        continue
    partes = rel.split("/")
    if FORA & set(partes) or os.path.basename(rel) == "resgatados-antes-e-depois.png" or "temas" in partes:
        continue
    if os.path.normpath(os.path.dirname(os.path.join(raiz, rel))) not in {p for p, _e in por_pasta}:
        sem_grupo.add(os.path.dirname(rel))
checa(not sem_grupo, "toda pasta de desenho versionada tem a sua pasta na ficha", repr(sorted(sem_grupo)))

oferecidos = {sha(caminho_de(it)) for it in itens}
sobra = {}
for rel in subprocess.run(["git", "-C", raiz, "ls-files", "packs", "assets/icones", "packs/meowsystem/mascote/"],
                          capture_output=True, text=True).stdout.split():
    if (not rel.lower().endswith((".svg", ".png")) or "/mimetypes/" in rel or "/temas/" in rel
            or "/wallpapers/" in rel):
        continue
    h = sha(os.path.join(raiz, rel))
    if h not in oferecidos:
        sobra.setdefault(h, rel)
fora_da_regra = sorted(r for r in sobra.values()
                       if not ("/icones/pastas/" in r or "/icones/sistema/" in r
                               or "/mascote/" in r
                               or r.endswith("/logo.svg") or r.endswith("resgatados-antes-e-depois.png")))
print("  versionados únicos menos oferecíveis: %d — %s" % (
    len(sobra), ", ".join(sorted({r.rsplit("/", 1)[0] if not r.endswith("logo.svg") else "logo.svg"
                                  for r in sobra.values()}))))
checa(not fora_da_regra,
      "a conta versionados − oferecíveis só deixa pastas/, gatos/, logo.svg e a folha dos resgatados",
      repr(fora_da_regra[:10]))

achados = {os.path.relpath(caminho_de(it), raiz) for it in glifos("firefox").get("glifos", [])}
checa("packs/dracula/icones/apps/firefox.svg" in achados,
      "«firefox» acha o firefox.svg (o desenho que veste o Firefox e o Waterfox)",
      repr(sorted(achados)[:8]))
achados = {os.path.relpath(caminho_de(it), raiz) for it in glifos("alienígena").get("glifos", [])}
checa("packs/dracula/icones/biblioteca/alien.svg" in achados,
      "«alienígena» acha o alien.svg (pela descrição do catalog.json)", repr(sorted(achados)))
achados2 = {os.path.relpath(caminho_de(it), raiz) for it in glifos("alienigena").get("glifos", [])}
checa(achados2 == achados, "e «alienigena», sem acento, acha o mesmo")

checa(vazia.get("limitado") is False and len(itens) == sum(soma.values()) and len(itens) > 120,
      "a ficha aberta sem busca traz %d desenhos, sem corte" % len(itens))
sugeridos = [it["glifo"] for it in itens if it.get("sugerido")]
checa("net.waterfox.waterfox" in sugeridos and len(sugeridos) < len(itens),
      "o nome do app acende os sugeridos (%d) sem filtrar o resto" % len(sugeridos), repr(sugeridos[:8]))
ordem = [g["id"] for g in grupos]
checa(ordem and ordem[0].startswith("pack:dracula:")
      and any(g.startswith("pack:meowsystem:") for g in ordem),
      "o pack no ar vem primeiro, e os outros packs e o motor vêm depois, cada um na sua pasta",
      repr(ordem))

import re  # noqa: E402
de_sistema = sorted({it["grupo"] for it in itens if "/icones/sistema/" in caminho_de(it)})
checa(not de_sistema, "nenhuma pasta de sistema/ na ficha", repr(de_sistema))
fora_das_duas = [g["id"] for g in grupos if g["pack"] and ":autorais:" not in g["id"]
                 and not re.match(r"^pack:[a-z0-9-]+:(apps|biblioteca)(/[^:]+)?(:png)?$", g["id"])]
checa(not fora_das_duas, "todo grupo de pack é apps/ ou biblioteca/, ou os autorais", repr(fora_das_duas))
base = {g["id"]: g["tipo"] for g in grupos if g["pack"] == "meowsystem"}
checa(base and base.get("pack:meowsystem:apps") == "traco",
      "o acervo do pack-base aparece como traço", repr(base))

for pasta_rel in ("apps", "biblioteca"):
    pasta_p96 = os.path.join(raiz, "packs", "dracula", "icones", pasta_rel)
    gp = next((g for g in grupos if g["id"] == "pack:dracula:" + pasta_rel), None)
    flavors = ("dracula", "alucard")
    esperado = len([a for a in os.listdir(pasta_p96) if a.endswith(".svg")
                    and not (pasta_rel == "apps" and a[:-4].endswith(tuple("-" + f for f in flavors)))])
    checa(gp and gp["total"] == esperado, "a pasta %s do Dracula aparece inteira na ficha (%d)" % (pasta_rel, esperado),
          repr(gp and gp["total"]))
sub = [g["id"] for g in grupos if re.match(r"^pack:[a-z0-9-]+:(apps|biblioteca)/", g["id"])]
checa(not sub, "nenhum grupo de subpasta: as três pastas são planas", repr(sub))

por_arquivo = {os.path.relpath(caminho_de(it), raiz): it for it in itens}
esperados = {
    "packs/dracula/icones/apps/firefox.svg": "Waterfox",
    "packs/dracula/icones/biblioteca/alien.svg": "Alienígena",
    "packs/dracula/icones/biblioteca/005-potion.svg": "Poção",
}
for rel, rotulo in esperados.items():
    it = por_arquivo.get(rel) or {}
    checa(it.get("rotulo") == rotulo, "%s ganha o rótulo «%s»" % (os.path.basename(rel), rotulo),
          "veio %r" % it.get("rotulo"))
traco = [it for rel, it in por_arquivo.items()
         if it["tipo"] == "traco" and it["glifo"] == "firefox"]
checa(traco and all(it.get("rotulo") == "Firefox" for it in traco),
      "o traço «firefox» ganha o nome do .desktop que o veste (Firefox)",
      repr([it.get("rotulo") for it in traco]))
import re  # noqa: E402
TECNICO = re.compile(r"^\d{2,}[-_]|^[A-Za-z0-9-]+\.[A-Za-z0-9-]+\.[A-Za-z0-9.-]+$")
tecnicos = sorted({it.get("rotulo") or "" for it in itens if TECNICO.search(it.get("rotulo") or "")
                   or not it.get("rotulo")})
checa(not tecnicos, "nenhum rótulo é nome técnico (número na frente, domínio invertido) nem vazio",
      repr(tecnicos[:8]))
for glifo, rotulo in (("org.telegram.desktop", "Telegram"), ("com.spotify.Client", "Spotify")):
    deles = sorted({(it["grupo"], it.get("rotulo")) for it in itens if it["glifo"] == glifo
                    and it["grupo"].endswith(":apps")})
    checa(len(deles) > 1 and all(r == rotulo for _g, r in deles),
          "«%s» se chama «%s» em toda pasta" % (glifo, rotulo), repr(deles))

import base64  # noqa: E402
antes_git = subprocess.run(["git", "-C", raiz, "status", "--porcelain", "--untracked-files=all"],
                           capture_output=True, text=True).stdout
svg = b'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><circle cx="24" cy="24" r="20"/></svg>'
resposta.clear()
m._api_acervo({"tipo": "icone", "nome": "meu-desenho-p82.svg",
               "conteudo": base64.b64encode(svg).decode()})
enviado = resposta.get("dados") or {}
depois_git = subprocess.run(["git", "-C", raiz, "status", "--porcelain", "--untracked-files=all"],
                            capture_output=True, text=True).stdout
checa(enviado.get("ok") and depois_git == antes_git,
      "enviar um SVG pelo «Adicionar ícone» deixa o git status do clone como estava",
      "resposta %r; novo no git: %r" % (enviado, sorted(set(depois_git.splitlines()) - set(antes_git.splitlines()))))
casa_real = os.path.realpath(casa)
dele = [it for it in glifos("").get("glifos", []) if it["glifo"] == "meu-desenho-p82"]
checa(dele and caminho_de(dele[0]).startswith(casa_real + os.sep) and dele[0]["tipo"] == "desenho",
      "e o desenho enviado aparece na ficha, numa pasta da casa de quem usa",
      repr([(caminho_de(i), i["grupo"]) for i in dele]))

achados = {os.path.relpath(caminho_de(it), raiz) for it in glifos("firefox").get("glifos", [])}
checa({"packs/dracula/icones/apps/firefox.svg",
       "packs/dracula/icones/biblioteca/net.waterfox.waterfox.svg"} <= achados,
      "«firefox» acha o desenho que veste e a chama guardada na biblioteca",
      repr(sorted(a for a in achados if "waterfox" in a)))

veste = glifos("", "net.waterfox.waterfox").get("veste")
checa(veste == "packs/dracula/icones/apps/firefox.svg",
      "o net.waterfox.waterfox vem com «veste» no desenho do pack no ar", "veio %r" % veste)

import json  # noqa: E402
bib = os.path.join(raiz, "packs", "dracula", "icones", "biblioteca")
with open(os.path.join(bib, "catalog.json"), encoding="utf-8") as fh:
    catalogo = json.load(fh)
sem_descricao = sorted(a for a in os.listdir(bib) if a.endswith(".svg")
                       and not str((catalogo.get(a) or {}).get("descricao") or "").strip())
checa(not sem_descricao, "todo desenho da biblioteca do Dracula tem descrição no catálogo",
      "%d sem: %s" % (len(sem_descricao), sem_descricao[:6]))
with open(os.path.join(raiz, "packs", "meowsystem", "icones", "apps-convertidos.map"), encoding="utf-8") as fh:
    linhas_conv = fh.read().split("\n")
sem_nome = [l.split(":", 1)[0] for i, l in enumerate(linhas_conv)
            if re.match(r"^[a-z]+\.[A-Za-z0-9_.-]+\.[A-Za-z0-9_.-]+:", l)
            and not (i and re.match(r"^# app: \S", linhas_conv[i - 1]))]
checa(not sem_nome, "toda linha de id invertido do apps-convertidos.map tem o «# app:» com o nome",
      "%d sem: %s" % (len(sem_nome), sem_nome[:6]))
for rel, rotulo in (("packs/meowsystem/icones/apps/com.obsproject.Studio.svg", "OBS Studio"),
                    ("packs/meowsystem/icones/apps/io.github.shiftey.Desktop.svg", "GitHub Desktop")):
    it = por_arquivo.get(rel) or {}
    checa(it.get("rotulo") == rotulo, "%s ganha o rótulo «%s»" % (os.path.basename(rel), rotulo),
          "veio %r" % it.get("rotulo"))
origens = [o for _d, o in DIRS_DE_FABRICA]
checa("pessoal" in origens and "usuária" not in origens,
      "a origem do .desktop da casa se chama «pessoal»", repr(origens))

if falhas:
    print("FALHOU: o acervo da ficha de ícone:", file=sys.stderr)
    for linha in falhas:
        print("    " + linha, file=sys.stderr)
    sys.exit(1)
print("ok: a ficha oferece o acervo inteiro, uma pasta por acervo, e a busca acha pelo nome e pelo sentido")
PY

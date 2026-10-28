#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 3; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
CASA="$T/casa"
mkdir -p "$CASA/.config/meow" "$CASA/.local/share/meowsystem/packs/meu-dracula" \
         "$CASA/.local/state/meowsystem" || exit 2
cp "$RAIZ/meow.conf.exemplo" "$CASA/.config/meow/meow.conf" || exit 2
printf '{"formato": 2, "id": "meu-dracula", "nome": "Meu Dracula", "heranca": "dracula"}\n' \
  > "$CASA/.local/share/meowsystem/packs/meu-dracula/pack.json"
cp "$RAIZ/packs/dracula/paleta.json" "$CASA/.local/share/meowsystem/packs/meu-dracula/paleta.json"

env -u MEOW_PACK_DIR -u PACK -u FLAVOR -u ICONES_DRACULA -u MEOW_PACKS \
    HOME="$CASA" MEOW_CONF="$CASA/.config/meow/meow.conf" XDG_CONFIG_HOME="$CASA/.config" \
    XDG_DATA_HOME="$CASA/.local/share" XDG_STATE_HOME="$CASA/.local/state" \
    MEOW_ESTADO="$CASA/.local/state/meowsystem" PYTHONDONTWRITEBYTECODE=1 \
    python3 - "$RAIZ" <<'PY'
import json
import os
import re
import sys
from urllib.parse import unquote

raiz = sys.argv[1]
sys.path.insert(0, os.path.join(raiz, "app"))
sys.path.insert(0, os.path.join(raiz, "scripts"))
import servidor  # noqa: E402
import pack  # noqa: E402

falhas = []


def checa(cond, frase, detalhe=""):
    if cond:
        print("ok: " + frase)
    else:
        falhas.append(frase + (" — " + detalhe if detalhe else ""))
    return cond


m = servidor.Manipulador.__new__(servidor.Manipulador)
resposta = {}
m._json = lambda dados, codigo=200: resposta.update(dados=dados, codigo=codigo)


def chamar(metodo, arg):
    resposta.clear()
    metodo(arg)
    return resposta.get("dados") or {}


checa(pack.cadeia_de_acervo("meowsystem") == ["meowsystem"], "a cadeia do MeowSystem é só ele")
checa(pack.cadeia_de_acervo("dracula") == ["dracula"],
      "a do Dracula para nele, sem descer ao MeowSystem de quem ele herda", repr(pack.cadeia_de_acervo("dracula")))
checa(pack.cadeia_de_acervo("meu-dracula") == ["meu-dracula", "dracula"],
      "a de um pack da pessoa feito do Dracula é ele e o Dracula", repr(pack.cadeia_de_acervo("meu-dracula")))

cores_mocha = pack._cores_do_flavor("meowsystem", "mocha")
for em_edicao, esperado in (("meowsystem", {"meowsystem"}), ("dracula", {"dracula"}),
                            ("meu-dracula", {"dracula"})):
    for pasta in pack.PASTAS_QUE_SE_LEVAM:
        itens = pack.acervo_para_levar(None, pasta, em_edicao, cores_mocha)
        de = {i["de"] for i in itens}
        checa(itens and de == esperado, "%s em edição: a aba %s só tem o acervo de %s"
              % (em_edicao, pasta, "/".join(sorted(esperado))), repr(sorted(de)))

for em_edicao in ("meowsystem", "dracula"):
    itens = pack.acervo_para_levar(None, "sistema", em_edicao, cores_mocha)
    rotulos = {i["rotulo"] for i in itens}
    checa({"Documentos", "Downloads", "Música", "Imagens"} <= rotulos,
          "%s: a aba Sistema chama as pastas pelo nome (Documentos, Downloads…)" % em_edicao, repr(sorted(rotulos)))
    pastas = {i["rotulo"] for i in itens if i.get("grupo") == "pastas"}
    checa(pastas and not [r for r in pastas if re.search(r"[-_.]|^folder|^user", r)],
          "%s: nenhum rótulo de pasta tem hífen nem nome técnico" % em_edicao, repr(sorted(pastas)))
    checa(not [i for i in itens if re.search(r"_|symbolic|^folder|^user", i["rotulo"]) or i["rotulo"] == i["nome"]],
          "%s: nenhum rótulo do sistema é o nome técnico do ícone" % em_edicao,
          repr(sorted(i["rotulo"] for i in itens if re.search(r"_|symbolic", i["rotulo"]) or i["rotulo"] == i["nome"])))

amostra = pack.acervo_para_levar(None, "sistema", "meowsystem", cores_mocha)
hexes = {v.lower() for v in cores_mocha.values()}
usadas = {h.lower() for i in amostra for h in re.findall(r"#[0-9a-fA-F]{6}", i["svg"] or "")}
checa(amostra and all("--vscode-ctp" not in (i["svg"] or "") for i in amostra)
      and usadas and usadas <= hexes,
      "as pastas do MeowSystem vêm pintadas só com cores do tema em edição", repr(sorted(usadas - hexes)))
outras = {k: "#%02x%02x%02x" % (n * 7 % 256, n * 13 % 256, n * 29 % 256)
          for n, k in enumerate(cores_mocha, 1)}
pintadas = pack.acervo_para_levar(None, "sistema", "meowsystem", outras)
checa([i["svg"] for i in pintadas] != [i["svg"] for i in amostra]
      and {h.lower() for i in pintadas for h in re.findall(r"#[0-9a-fA-F]{6}", i["svg"] or "")} <= set(outras.values()),
      "trocar a cor do tema em edição troca a cor das pastas")

for em_edicao, fora in (("meowsystem", "pack:dracula:"), ("dracula", "pack:meowsystem:")):
    r = chamar(m._api_glifos, {"busca": [""], "pack": [em_edicao]})
    grupos = [g["id"] for g in r.get("grupos", [])]
    checa(grupos and not [g for g in grupos if g.startswith(fora)]
          and not [i for i in r.get("glifos", []) if i["grupo"].startswith(fora)],
          "a ficha com %s em edição não traz grupo nem item de %s" % (em_edicao, fora[5:-1]), repr(grupos))

r = chamar(m._api_criar_ler, {"id": [""], "base": ["meowsystem"], "cores": [json.dumps(cores_mocha)]})
sist = r.get("sistema") or []
checa(sist and all(i["de"] == "meowsystem" for i in sist) and any(i["rotulo"] == "Documentos" for i in sist)
      and all(i["url"].startswith("data:image/svg+xml") for i in sist),
      "o /api/criar ler entrega a aba Sistema do MeowSystem pintada, com rótulo", repr(sist[:1]))
r = chamar(m._api_criar_ler, {"id": [""], "base": ["dracula"]})
checa((r.get("biblioteca") or []) and {i["de"] for i in r["biblioteca"]} == {"dracula"}
      and {i["de"] for i in r["sistema"]} == {"dracula"},
      "e com o Dracula como base: Sistema e Biblioteca só do Dracula")

if falhas:
    print("FALHOU: o acervo do pack em edição:", file=sys.stderr)
    for f in falhas:
        print("    " + f, file=sys.stderr)
    sys.exit(1)
print("ok: cada pack em edição mostra só o acervo dele")
PY

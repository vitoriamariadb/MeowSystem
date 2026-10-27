#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
cat > "$T/arte.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64"><rect x="8" y="8" width="48" height="48" rx="10" fill="#d33"/><circle cx="32" cy="32" r="14" fill="#fff"/><rect x="28" y="12" width="8" height="40" fill="#222"/></svg>
SVG

saida="$(env -i PATH="$PATH" HOME="$T/casa" python3 -I - "$RAIZ" "$T/arte.svg" <<'PY' 2>&1
import glob, importlib.util, os, subprocess, sys, xml.etree.ElementTree as ET
raiz, arte = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(raiz, "scripts"))
import gerador_circulo as g
import pack

conv = os.path.join(os.path.dirname(arte), "conv.svg")
subprocess.run([sys.executable, os.path.join(raiz, "scripts", "converter_icone.py"), arte, conv,
                "--k", "4", "--funde", "76", "--tol", "1.2"], capture_output=True, check=True)
glifo = open(conv).read()
ns = "{http://www.w3.org/2000/svg}"

def tags(texto):
    return [e.tag.replace(ns, "") for e in ET.fromstring(texto).iter()]

def preenchidos(texto):
    return [e for e in ET.fromstring(texto).iter(ns + "path") if e.get("fill") not in (None, "none")]

for pid, _rot, _aj in g.PRESETS:
    svg = g.gerar(glifo, pid)
    t = tags(svg)
    assert "stroke" not in svg, pid + ": traz stroke"
    assert "currentColor" not in svg, pid + ": traz currentColor"
    assert preenchidos(svg), pid + ": sem path preenchido"
    if pid != "solto":
        assert "circle" in t, pid + ": sem circle"
print("presets:", len(g.PRESETS))

disco = g.gerar(glifo, "disco-aro")
assert tags(disco).count("circle") == 2, "o aro tem de ser um segundo circle"
assert g.gerar(glifo, "disco", aro=True).count("<circle") == 2
assert "#FF0000" in g.gerar(glifo, "disco", tinta="#ff0000")
assert "<script" not in g.gerar(glifo, "disco", disco="javascript:x")

dracula = sorted(glob.glob(os.path.join(raiz, "packs", "dracula", "icones", "apps", "*.svg")))
assert dracula
referencia = [p for p in dracula if "circle" in tags(open(p).read()) and preenchidos(open(p).read())]
assert referencia, "nenhum ícone do Dracula com circle e path preenchido"
nosso = set(tags(g.gerar(glifo, "disco")))
dele = set(tags(open(referencia[0]).read()))
assert nosso <= dele | {"svg"}, "estrutura fora do que o pack tem: %s" % sorted(nosso - dele)
print("estrutura-comparavel:", len(referencia))

assert pack.gerador_de_icones("dracula") == "circle"
assert pack.gerador_de_icones("meowsystem") == "traco"
print("geradores-ok")
PY
)"
for esperado in "presets: 5" "estrutura-comparavel:" "geradores-ok"; do
  grep -q "$esperado" <<< "$saida" && ok "$esperado" || falha "unidade do gerador: faltou «$esperado»" "$saida"
done

api="$(env -i PATH="$PATH" HOME="$T/casa" python3 -I - "$RAIZ/app" "$T/arte.svg" <<'PY' 2>&1
import json, sys
sys.path.insert(0, sys.argv[1])
import servidor
m = servidor.Manipulador.__new__(servidor.Manipulador)
r = []
m._json = lambda dados, status=200: r.append(dados)
d = {"id": "org.exemplo.App", "icone": "org.exemplo.App", "nome": "App"}
m._desktops = lambda: [d]
m._arte_de_fabrica = lambda x: sys.argv[2]
m._arte_da_capa = lambda a: ""
m._icone_na_tela = lambda x, y: ("", False)
m._vizinhos_do_dock = lambda: []
m._editor_de_svg = lambda: None
m._mapa_convertidos = lambda: {}
m._mapa_arcticons = lambda: {}
m._salvo_do_app = lambda n: {"tem": False, "svg": "", "modo": ""}
for pk in ("dracula", "meowsystem"):
    m._api_app_desenho({"app": "org.exemplo.App", "acao": "variacoes", "pack": pk})
m._api_app_desenho({"app": "org.exemplo.App", "acao": "gerar", "preset": "lua", "tinta": "#FF0000", "aro": True})
dra, mew, ger = r
cartoes = [c for c in dra["variacoes"] if c.get("svg")]
print("dracula", dra["gerador"], len(cartoes), all(("<circle" in c["svg"] or c["id"] == "solto") and "stroke" not in c["svg"] for c in cartoes))
tracos = [c for c in mew["variacoes"] if c.get("svg")]
print("meowsystem", mew["gerador"], len(tracos) > 0, all("stroke=\"currentColor\"" in c["svg"] for c in tracos))
print("gerar", ger.get("ok"), "#FF0000" in ger["svg"], ger["svg"].count("<circle"))
PY
)"
grep -q "^dracula circle 4 True$" <<< "$api" && ok "Dracula em edição: quatro cartões do gerador (sem capa), de círculo e sem traço, sem traço" || falha "variações do Dracula" "$api"
grep -q "^meowsystem traco True True$" <<< "$api" && ok "MeowSystem em edição: cartões em traço" || falha "variações do MeowSystem" "$api"
grep -q "^gerar True True 2$" <<< "$api" && ok "o gerador responde aos ajustes (tinta e aro)" || falha "ação gerar" "$api"

[ "$falhas" = 0 ] || exit 1

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

T="$(mktemp -d -p "${TMPDIR:-/tmp}" meow-logo-pessoal.XXXXXX)" || exit 2
trap 'rm -rf "$T"' EXIT
falhas=0
ok() { printf '  ok  %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }

FALSO="$T/falso"; mkdir -p "$FALSO"
for b in sudo pkexec su pkill systemctl; do printf '#!/bin/sh\nexit 1\n' > "$FALSO/$b"; chmod 755 "$FALSO/$b"; done
CASA="$T/casa"
CONF="$CASA/.config/meow/meow.conf"
mkdir -p "${CONF%/*}"
amb() { env -i PATH="$FALSO:$PATH" HOME="$CASA" LANG=C.UTF-8 NO_COLOR=1 MEOW_RAIZ="$RAIZ" "$@"; }

python3 - "$T/meu-tema.csv" "$RAIZ/packs/dracula/paleta.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[2], encoding="utf-8"))
ordem = p.get("ordem_canonica") or list(next(iter(p["flavors"].values())))
cores = p["flavors"]["dracula"]
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("slot,flavor,hex\n" + "".join(f"{n},meutema,{cores[n]}\n" for n in ordem))
PY
amb python3 "$RAIZ/scripts/pack.py" importar "$T/meu-tema.csv" >/dev/null 2>&1 || { echo "erro: o CSV não virou pack"; exit 2; }
DIR="$CASA/.local/share/meowsystem/packs/meu-tema"
printf 'PACK="meu-tema"\nFLAVOR="meutema"\nACCENT="mauve"\nLOGO_PROGRAMA=""\n' > "$CONF"
M_ANTES="$(md5sum "$DIR/logo.svg" | cut -d' ' -f1)"

PEQUENO="$T/pequeno.png"
python3 - "$PEQUENO" <<'PY'
import struct, sys, zlib
def bloco(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
larg = alt = 16
linhas = b"".join(b"\x00" + b"".join(b"\xff\x00\x80\xff" if 4 <= x < 12 and 4 <= y < 12 else b"\x00\x00\x00\x00"
                                      for x in range(larg)) for y in range(alt))
png = (b"\x89PNG\r\n\x1a\n" + bloco(b"IHDR", struct.pack(">IIBBBBB", larg, alt, 8, 6, 0, 0, 0))
       + bloco(b"IDAT", zlib.compress(linhas)) + bloco(b"IEND", b""))
open(sys.argv[1], "wb").write(png)
PY
printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 20"><circle cx="20" cy="10" r="9" fill="#f00"/></svg>' > "$T/largo.svg"
printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><script>alert(1)</script></svg>' > "$T/script.svg"
printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="5" height="5" onload="x()"/></svg>' > "$T/onload.svg"
printf '<svg xmlns="http://www.w3.org/2000/svg" xmlns:x="http://www.w3.org/1999/xlink" viewBox="0 0 10 10"><use x:href="http://e.com/a.svg#b"/><use href="https://e.com/a.svg#b"/></svg>' > "$T/externo.svg"
printf 'isto não é imagem' > "$T/texto.txt"
head -c 700000 /dev/zero | tr '\0' 'a' > "$T/enorme.svg"

servidor() {
  amb MEOW_CONF="$CONF" MEOW_PACK_DIR="$DIR" python3 - "$RAIZ" "$T" "$DIR" "$@" <<'PY'
import base64, json, os, sys
sys.path.insert(0, sys.argv[1] + "/app")
import servidor
T, DIR = sys.argv[2], sys.argv[3]
acao = sys.argv[4]
def grava(**corpo):
    resposta, codigo = servidor.gravar_logo_do_pack_pessoal({"pack": "meu-tema", **corpo})
    return {"codigo": codigo, **resposta}
def arquivo(nome):
    with open(os.path.join(T, nome), "rb") as fh:
        return {"de": "arquivo", "nome": nome, "conteudo": base64.b64encode(fh.read()).decode()}
if acao == "opcoes":
    r = servidor.logo_do_pack_pessoal_opcoes(sys.argv[5])
    print(json.dumps(None if r is None else {"atual": r["atual"], "chaves": [o["chave"] for o in r["opcoes"]],
                                             "urls": all(o["url"].startswith("data:image/svg+xml") for o in r["opcoes"])}))
elif acao == "gravar":
    print(json.dumps(grava(de=sys.argv[5], id=sys.argv[6] if len(sys.argv) > 6 else "")))
elif acao == "arquivo":
    print(json.dumps(grava(**arquivo(sys.argv[5]))))
elif acao == "pack-alheio":
    print(json.dumps(servidor.gravar_logo_do_pack_pessoal({"pack": sys.argv[5], "de": "gerada", "id": ""})[1]))
elif acao == "logo":
    m = servidor.Manipulador.__new__(servidor.Manipulador)
    m._host_confere = m._origem_confere = lambda: True
    m._token_confere = lambda consulta: True
    saida = []
    m._responder = lambda corpo, **_k: saida.append(corpo if isinstance(corpo, bytes) else corpo.encode())
    m._recusar = lambda codigo, frase: saida.append(("%d %s" % (codigo, frase)).encode())
    m.path = "/logo.svg" + sys.argv[5]
    m.do_GET()
    sys.stdout.buffer.write(saida[0])
elif acao == "oferta":
    print(json.dumps("meu-tema" in servidor._packs_com_logo() and servidor.logo_de_pack("meu-tema", "meutema", "mauve") is not None))
elif acao == "pacotes":
    print(json.dumps({p["id"]: p["pessoal"] for p in servidor.packs_com_vitrine()}, sort_keys=True))
PY
}
campo() { python3 -c 'import json,sys; print(json.loads(sys.argv[1]).get(sys.argv[2], ""))' "$1" "$2"; }
guardada() { md5sum "$DIR/logo.svg" | cut -d' ' -f1; }

pacotes="$(servidor pacotes)"
[ "$(campo "$pacotes" "meu-tema")" = "True" ] && [ "$(campo "$pacotes" "dracula")" = "False" ] && [ "$(campo "$pacotes" "meowsystem")" = "False" ] \
  && ok "só o pack do HOME é pessoal; dracula e meowsystem não são" || falha "o campo pessoal veio $pacotes"

[ "$(servidor pack-alheio dracula)" = "400" ] && ok "pack que vem com o programa recusa a troca" || falha "dracula aceitou trocar a logo"
[ "$(servidor opcoes dracula)" = "null" ] && ok "e não lista opções" || falha "dracula listou opções"

opcoes="$(servidor opcoes meu-tema)"
python3 - "$opcoes" <<'PY' && ok "as opções são a gerada, a logo de cada pack e os desenhos do mascote, com a gerada marcada" || falhas=$((falhas + 1))
import json, sys
d = json.loads(sys.argv[1])
chaves = set(d["chaves"])
erros = []
if not {"gerada:", "pack:dracula", "pack:meowsystem", "gato:coquinha"} <= chaves:
    erros.append("chaves %r" % sorted(chaves))
if "pack:meu-tema" in chaves:
    erros.append("o próprio pack não é opção")
if d["atual"] != "gerada:":
    erros.append("atual %r" % d["atual"])
if not d["urls"]:
    erros.append("alguma opção sem prévia")
if erros:
    print("  FALHA " + "; ".join(erros))
    sys.exit(1)
PY

r="$(servidor gravar pack dracula)"
[ "$(campo "$r" codigo)" = "200" ] && [ "$(campo "$r" mudou)" = "True" ] \
  && ok "gravar a logo do dracula no pack pessoal" || falha "gravar dracula: $r"
cmp -s <(python3 - "$RAIZ/packs/dracula/logo.svg" <<'PY'
import re, sys
print(re.sub(r'\s*<style\b[^>]*id="meow-papeis"[^>]*>.*?</style>', "", open(sys.argv[1]).read(), flags=re.S), end="")
PY
) <(python3 - "$DIR/logo.svg" <<'PY'
import re, sys
print(re.sub(r'\s*<style\b[^>]*id="meow-papeis"[^>]*>.*?</style>', "", open(sys.argv[1]).read(), flags=re.S), end="")
PY
) && ok "o arquivo do pack pessoal é a logo do dracula" || falha "logo.svg do pack pessoal não é a do dracula"
[ "$(campo "$(servidor opcoes meu-tema)" atual)" = "pack:dracula" ] \
  && ok "e a escolha vem marcada" || falha "a escolha do dracula não veio marcada"
antes="$(guardada)"; marca="$(stat -c %Y.%N "$DIR/logo.svg")"
sleep 1
r="$(servidor gravar pack dracula)"
[ "$(campo "$r" mudou)" = "False" ] && [ "$(guardada)" = "$antes" ] && [ "$(stat -c %Y.%N "$DIR/logo.svg")" = "$marca" ] \
  && ok "a segunda gravação igual não escreve" || falha "a segunda gravação reescreveu: $r"
[ -z "$(ls "$DIR" | grep 'meow-parcial')" ] && ok "nenhum arquivo parcial sobra" || falha "sobrou arquivo parcial"

r="$(servidor gravar gato coquinha)"
[ "$(campo "$r" codigo)" = "200" ] && grep -q 'viewBox="[^"]*"' "$DIR/logo.svg" && ! cmp -s "$DIR/logo.svg" "$RAIZ/packs/dracula/logo.svg" \
  && ok "gravar um desenho do mascote" || falha "gravar o gato: $r"
python3 - "$DIR/logo.svg" <<'PY' && ok "e o desenho do mascote fica quadrado" || falhas=$((falhas + 1))
import re, sys
v = re.search(r'viewBox="([^"]*)"', open(sys.argv[1]).read()).group(1).split()
if float(v[2]) != float(v[3]):
    print("  FALHA viewBox %r" % v); sys.exit(1)
PY

r="$(servidor arquivo largo.svg)"
[ "$(campo "$r" codigo)" = "200" ] && python3 - "$DIR/logo.svg" <<'PY' && ok "SVG largo vira quadrado, centrado" || falha "SVG largo: $r"
import re, sys
v = [float(x) for x in re.search(r'viewBox="([^"]*)"', open(sys.argv[1]).read()).group(1).split()]
sys.exit(0 if v == [0, -10, 40, 40] else 1)
PY
r="$(servidor arquivo pequeno.png)"
[ "$(campo "$r" codigo)" = "200" ] && grep -q 'fill="#FF0080"' "$DIR/logo.svg" && ! grep -qi '<image' "$DIR/logo.svg" \
  && ok "PNG vira SVG de verdade, sem imagem embutida" || falha "PNG: $r"
amb python3 -c "
import sys; sys.path.insert(0, '$RAIZ/scripts'); import pack
pack.logo('meu-tema')" >/dev/null 2>&1 && ok "o pack continua válido com a logo vinda do PNG" || falha "o pack ficou inválido"

boa="$(guardada)"
for ruim in script.svg onload.svg externo.svg texto.txt enorme.svg; do
  r="$(servidor arquivo "$ruim")"
  case "$ruim" in enorme.svg) quer=413 ;; *) quer=400 ;; esac
  [ "$(campo "$r" codigo)" = "$quer" ] && [ "$(guardada)" = "$boa" ] \
    && ok "$ruim recusa ($quer) e a logo anterior fica" || falha "$ruim: $r"
done

r="$(servidor gravar gerada)"
[ "$(campo "$r" codigo)" = "200" ] && [ "$(campo "$(servidor opcoes meu-tema)" atual)" = "gerada:" ] \
  && ok "voltar à logo gerada" || falha "voltar à gerada: $r"
[ "$(servidor gravar pack inexistente | python3 -c 'import json,sys; print(json.load(sys.stdin)["codigo"])')" = "400" ] \
  && ok "opção que não existe recusa" || falha "opção inexistente foi aceita"

servidor gravar pack dracula >/dev/null
no_ar="$(servidor logo "")"
em_pack="$(amb python3 "$RAIZ/scripts/pack.py" logo meu-tema meutema mauve 2>/dev/null)"
[ -n "$em_pack" ] && [ "$no_ar" = "$em_pack" ] \
  && ok "com LOGO_PROGRAMA vazio e o pack pessoal no ar, /logo.svg segue a logo dele" || falha "/logo.svg não seguiu a logo do pack pessoal"
printf 'PACK="meu-tema"\nFLAVOR="meutema"\nACCENT="mauve"\nLOGO_PROGRAMA="meowsystem"\n' > "$CONF"
[ "$(servidor logo "")" != "$no_ar" ] \
  && ok "com LOGO_PROGRAMA escolhido, vale a escolha" || falha "LOGO_PROGRAMA não mandou"

[ "$(servidor oferta)" = "true" ] \
  && ok "o LOGO_PROGRAMA oferece e serve a logo do pack pessoal" || falha "o LOGO_PROGRAMA não oferece o pack pessoal"

if [ "$falhas" = 0 ]; then echo "logo-do-pack-pessoal: tudo verde"; exit 0; fi
echo "logo-do-pack-pessoal: $falhas falha(s)"; exit 1

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
[ -z "$(ls -A "$DIR" | grep 'meow-parcial')" ] && ok "nenhum arquivo parcial sobra" || falha "sobrou arquivo parcial"

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

printf 'PACK="meu-tema"\nFLAVOR="meutema"\nACCENT="mauve"\nLOGO_PROGRAMA=""\n' > "$CONF"
servidor gravar gato coquinha >/dev/null
amb python3 "$RAIZ/scripts/pack.py" validar meu-tema >/dev/null 2>&1 \
  && ok "o pack pessoal passa no validador depois da troca" || falha "o validador recusou o pack pessoal"
[ "$(amb python3 -c "import sys; sys.path.insert(0, '$RAIZ/scripts'); import pack; print(pack.campo('meu-tema', 'vitrine.capa'))")" = "logo.svg" ] \
  && ok "e a vitrine.capa aponta para a logo.svg gravada" || falha "a vitrine.capa não aponta para logo.svg"

ICONES="$CASA/.local/share/icons/MeowSystem-Icons"
mkdir -p "$ICONES/scalable/apps"
printf '[Icon Theme]\nName=MeowSystem-Icons\nDirectories=scalable/apps\n\n[scalable/apps]\nSize=48\nType=Scalable\n' > "$ICONES/index.theme"
amb PACK=meu-tema FLAVOR=meutema ACCENT=mauve LOGO_PROGRAMA="" "$RAIZ/scripts/completar_icones.sh" >/dev/null 2>&1
lancado="$(cat "$ICONES/scalable/apps/com.meowsystem.Painel.svg" 2>/dev/null)"
[ -n "$lancado" ] && [ "$lancado" = "$(amb python3 "$RAIZ/scripts/pack.py" logo meu-tema meutema mauve 2>/dev/null)" ] \
  && ok "o lançador do MeowSystem segue a logo nova do pack pessoal" || falha "o lançador não seguiu a logo nova"

boa="$(guardada)"
H='<svg xmlns="http://www.w3.org/2000/svg" xmlns:xl="http://www.w3.org/1999/xlink" viewBox="0 0 10 10">'
printf '%s<a href="javascript:alert(1)"><rect width="5" height="5"/></a></svg>' "$H" > "$T/js.svg"
printf '%s<use xl:href="http://e.com/a.svg#b"/></svg>' "$H" > "$T/xlink.svg"
printf '%s<foreignObject><div xmlns="http://www.w3.org/1999/xhtml">x</div></foreignObject></svg>' "$H" > "$T/foreign.svg"
printf '<!DOCTYPE svg [<!ENTITY x SYSTEM "file:///etc/passwd">]>%s<text>&x;</text></svg>' "$H" > "$T/xxe.svg"
printf '<!DOCTYPE svg [<!ENTITY a "aaaa"><!ENTITY b "&a;&a;&a;&a;">]>%s<text>&b;</text></svg>' "$H" > "$T/risos.svg"
printf '%s<style>rect{fill:u\\72l(http://e.com/x)}</style><rect/></svg>' "$H" > "$T/css-url.svg"
printf '%s<style>@\\69mport "http://e.com/x.css";</style></svg>' "$H" > "$T/css-import.svg"
printf '%s<rect xl:onclick="x()"/></svg>' "$H" > "$T/on-ns.svg"
printf '%s<rect style="fill:url(https://e.com/x)"/></svg>' "$H" > "$T/estilo.svg"
printf '%s<a href="#q"><set attributeName="href" to="javascript:alert(1)"/></a></svg>' "$H" > "$T/set.svg"
printf '<?xml-stylesheet href="http://e.com/x.css"?>%s</svg>' "$H" > "$T/pi.svg"
for ruim in js.svg xlink.svg foreign.svg xxe.svg risos.svg css-url.svg css-import.svg on-ns.svg estilo.svg set.svg pi.svg; do
  r="$(servidor arquivo "$ruim")"
  [ "$(campo "$r" codigo)" = "400" ] && [ "$(guardada)" = "$boa" ] \
    && ok "$ruim recusa e a logo fica" || falha "$ruim: $r"
done
r="$(servidor arquivo foreign.svg)"
case "$(campo "$r" erro)" in
  *.) ok "a queixa é uma frase inteira" ;;
  *) falha "a queixa veio cortada: $(campo "$r" erro)" ;;
esac

python3 - "$T" <<'PY'
import os, struct, sys, zlib
def bloco(t, d):
    return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
def png(nome, larg, alt, linhas):
    with open(os.path.join(sys.argv[1], nome), "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n" + bloco(b"IHDR", struct.pack(">IIBBBBB", larg, alt, 8, 6, 0, 0, 0))
                 + bloco(b"IDAT", zlib.compress(linhas, 9)) + bloco(b"IEND", b""))
png("gigante.png", 4096, 4096, (b"\x00" + b"\xff\x00\x80\xff" * 4096) * 4096)
png("bomba.png", 16, 16, b"\x00" * (64 << 20))
png("mil.png", 1024, 1024, (b"\x00" + b"\xff\x00\x80\xff" * 1024) * 1024)
SVG = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
with open(os.path.join(sys.argv[1], "espacos.svg"), "w") as fh:
    fh.write(SVG + " " * 500000 + '<rect width="5" height="5"/></svg>')
with open(os.path.join(sys.argv[1], "sem-fecho.svg"), "w") as fh:
    fh.write("<svg " * 100000)
PY
ms() { printf '%s' $(( ($(date +%s%N) - $1) / 1000000 )); }
for ruim in gigante.png bomba.png sem-fecho.svg; do
  inicio="$(date +%s%N)"
  r="$(servidor arquivo "$ruim")"
  gasto="$(ms "$inicio")"
  [ "$(campo "$r" codigo)" = "400" ] && [ "$(guardada)" = "$boa" ] && [ "$gasto" -lt 5000 ] \
    && ok "$ruim recusa em $gasto ms" || falha "$ruim ($gasto ms): $r"
done
for bom in mil.png espacos.svg; do
  inicio="$(date +%s%N)"
  r="$(servidor arquivo "$bom")"
  gasto="$(ms "$inicio")"
  [ "$(campo "$r" codigo)" = "200" ] && [ "$gasto" -lt 8000 ] \
    && ok "$bom grava em $gasto ms" || falha "$bom ($gasto ms): $r"
done
inicio="$(date +%s%N)"
servidor logo "" >/dev/null
gasto="$(ms "$inicio")"
[ "$gasto" -lt 5000 ] && ok "e a /logo.svg responde em $gasto ms" || falha "/logo.svg levou $gasto ms"

servidor gravar gerada >/dev/null
mkdir -p "$T/fora"
printf 'de fora\n' > "$T/fora/alvo.txt"
cp -r "$DIR" "$T/fora/pack-fora"
ln -s "$T/fora/pack-fora" "$CASA/.local/share/meowsystem/packs/ligado"
[ "$(servidor pack-alheio ligado)" = "400" ] && ok "pack que é link para fora da pasta dos packs recusa" || falha "o link para fora foi aceito"
[ "$(servidor pack-alheio "../packs/meu-tema")" = "400" ] && ok "nome com ../ recusa" || falha "../ foi aceito"
rm "$CASA/.local/share/meowsystem/packs/ligado"
mv "$DIR/logo.svg" "$T/fora/logo-guardada.svg"
ln -s "$T/fora/alvo.txt" "$DIR/logo.svg"
r="$(servidor gravar pack dracula)"
[ "$(campo "$r" codigo)" = "400" ] && [ "$(cat "$T/fora/alvo.txt")" = "de fora" ] \
  && ok "logo.svg que é link para fora recusa e o alvo fica intacto" || falha "logo.svg em link: $r"
rm "$DIR/logo.svg"; mv "$T/fora/logo-guardada.svg" "$DIR/logo.svg"
ln -s "$T/fora/alvo.txt" "$DIR/logo.svg.meow-parcial"
r="$(servidor gravar pack dracula)"
[ "$(campo "$r" codigo)" = "200" ] && [ "$(cat "$T/fora/alvo.txt")" = "de fora" ] && [ ! -L "$DIR/logo.svg" ] \
  && ok "um parcial plantado como link não é seguido" || falha "o parcial plantado foi seguido: $r"
rm -f "$DIR/logo.svg.meow-parcial"

if [ "$falhas" = 0 ]; then echo "logo-do-pack-pessoal: tudo verde"; exit 0; fi
echo "logo-do-pack-pessoal: $falhas falha(s)"; exit 1

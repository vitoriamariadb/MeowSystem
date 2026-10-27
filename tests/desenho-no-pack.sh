#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }
command -v zstd >/dev/null 2>&1 || python3 -c 'import zstandard' 2>/dev/null \
  || { printf 'pulado: sem zstd\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
CASA="$T/casa"; mkdir -p "$CASA" "$T/estado"
casa() {
  env -i PATH="$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$T/estado" MEOW_IGNORA_DESKTOP=1 "$@"
}
pack() { casa python3 "$RAIZ/scripts/pack.py" "$@"; }

python3 - "$T/meu-tema.csv" "$RAIZ/packs/meowsystem/paleta.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[2], encoding="utf-8"))
ordem = p.get("ordem_canonica") or list(next(iter(p["flavors"].values())))
cores = p["flavors"]["mocha"]
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("slot,flavor,hex\n" + "".join(f"{n},meutema,{cores[n]}\n" for n in ordem))
PY
pack importar "$T/meu-tema.csv" >/dev/null 2>&1 || { falha "o CSV de brinquedo não virou pack"; exit 1; }
DIR="$CASA/.local/share/meowsystem/packs/meu-tema"
sed -i 's/"heranca": "[a-z0-9-]*"/"heranca": "dracula"/' "$DIR/pack.json"

cat > "$T/app.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><circle cx="24" cy="24" r="22.6" fill="#44475A"/><path fill="#50FA7B" d="M16 16h16v16H16z"/></svg>
SVG
pack usar-desenho meu-tema org.exemplo.App "$T/app.svg" >/dev/null 2>"$T/err" \
  && [ -f "$DIR/icones/apps/org.exemplo.App.svg" ] \
  && ok "«Usar» grava o desenho dentro do pack da pessoa" \
  || falha "o desenho não foi para dentro do pack" "$(cat "$T/err")"

grep -q '^org.exemplo.App : apps/org.exemplo.App.svg' "$DIR/icones/apps.map" 2>/dev/null \
  && ok "o mapa do pack aponta o app para o desenho guardado" \
  || falha "o mapa do pack não ganhou a linha do app" "$(cat "$DIR/icones/apps.map" 2>&1 | tail -3)"

[ "$(tail -c1 "$DIR/icones/apps.map" | od -An -c | tr -d ' ')" = '\n' ] \
  && ok "o mapa termina em quebra de linha" || falha "o mapa não termina em \\n"

grep -q 'pack:dracula:' "$DIR/icones/apps.map" \
  && ok "as linhas do pack herdado seguem valendo, apontadas para o pack de origem" \
  || falha "o mapa novo perdeu as linhas do pack herdado"

pack exportar meu-tema "$T/meu-tema.meowpack" >/dev/null 2>"$T/err" \
  || falha "o pack não exportou" "$(cat "$T/err")"
if [ -f "$T/meu-tema.meowpack" ]; then
  python3 - "$T/meu-tema.meowpack" > "$T/lista" <<'PY'
import sys, tarfile, io
import subprocess
dados = open(sys.argv[1], "rb").read()
try:
    import zstandard
    dados = zstandard.ZstdDecompressor().stream_reader(io.BytesIO(dados)).read()
except ImportError:
    dados = subprocess.run(["zstd", "-dc"], input=dados, capture_output=True).stdout
for m in tarfile.open(fileobj=io.BytesIO(dados)).getmembers():
    print(m.name)
PY
  grep -q 'icones/apps/org.exemplo.App.svg$' "$T/lista" \
    && ok "o .meowpack exportado leva icones/apps/org.exemplo.App.svg" \
    || falha "o .meowpack não leva o desenho" "$(head -20 "$T/lista")"
fi

printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><script>1</script></svg>' > "$T/ruim.svg"
pack usar-desenho meu-tema org.exemplo.Ruim "$T/ruim.svg" >/dev/null 2>&1 \
  && falha "um SVG com script foi aceito" || ok "SVG com script é recusado"
pack usar-desenho meowsystem org.exemplo.App "$T/app.svg" >/dev/null 2>&1 \
  && falha "um pack que vem com o programa recebeu desenho" || ok "pack que vem com o programa não recebe desenho"

pack usar-desenho meu-tema org.exemplo.App "$T/app.svg" >/dev/null 2>&1
[ "$(grep -c '^org.exemplo.App :' "$DIR/icones/apps.map")" = 1 ] \
  && ok "usar de novo troca a linha, não duplica" || falha "a linha do app duplicou"

pack tirar-desenho meu-tema org.exemplo.App >/dev/null 2>&1 \
  && [ ! -f "$DIR/icones/apps/org.exemplo.App.svg" ] \
  && ! grep -q '^org.exemplo.App :' "$DIR/icones/apps.map" \
  && ok "«Desfazer» tira o desenho e a linha do mapa" || falha "tirar-desenho não desfez"

api="$(casa python3 -I - "$RAIZ/app" "$T/app.svg" <<'PY' 2>&1
import json, sys
sys.path.insert(0, sys.argv[1])
import servidor
m = servidor.Manipulador.__new__(servidor.Manipulador)
r = []
m._json = lambda dados, status=200: r.append((status, dados))
svg = open(sys.argv[2]).read()
m._api_app_desenho({"app": "org.exemplo.App", "acao": "salvar", "svg": svg, "cor": "green", "pack": "meu-tema"})
m._api_app_desenho({"app": "org.exemplo.App", "acao": "salvar", "svg": svg, "cor": "green", "pack": "dracula"})
m._api_app_desenho({"app": "org.exemplo.App", "acao": "desfazer-no-pack", "pack": "meu-tema"})
print(json.dumps([[s, d.get("ok"), d.get("guardado"), d.get("tirou")] for s, d in r]))
PY
)"
[ "$api" = '[[200, true, true, null], [400, null, null, null], [200, true, null, true]]' ] \
  && ok "a API grava no pack da pessoa, recusa pack que vem com o programa e desfaz" \
  || falha "a API de «Usar» no pack respondeu errado" "$api"

pack validar meu-tema >/dev/null 2>"$T/err" \
  && ok "o pack continua válido" || falha "o pack ficou inválido" "$(cat "$T/err")"

[ "$falhas" = 0 ] || exit 1

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v python3 >/dev/null || { printf 'pulado: sem python3\n'; exit 3; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALHAS=0
falha() { printf 'FALHOU: %s\n' "$1" >&2; FALHAS=$((FALHAS + 1)); }

printf 'ultimo:linha\npenultimo:linha' > "$T/sem-quebra.map"
lidas=0
while IFS= read -r linha || [ -n "$linha" ]; do lidas=$((lidas + 1)); done < "$T/sem-quebra.map"
[ "$lidas" = 2 ] || falha "o idioma do leitor devia ler 2 linhas num mapa sem quebra final, leu $lidas"

for s in appid_dock completar_icones construir_convertidos construir_pastas icones_apps_arcticons icones_bandeja icones_sistema; do
  if grep -nE 'read -r linha; do' "$RAIZ/scripts/$s.sh" >/dev/null; then
    falha "$s.sh ainda tem um leitor de mapa sem '|| [ -n ... ]'"
  fi
  grep -qE 'read -r (linha|nome)( _)? \|\| \[ -n' "$RAIZ/scripts/$s.sh" || falha "$s.sh perdeu o leitor tolerante"
done

env HOME="$T" XDG_DATA_HOME="$T/dados" MEOW_CONF="$T/meow/meow.conf" \
    MEOW_ICONES_CONVERTIDOS="$T/convertidos.map" PYTHONDONTWRITEBYTECODE=1 \
    python3 - "$RAIZ" "$T" <<'PY' || FALHAS=$((FALHAS + 1))
import os
import sys

raiz, t = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor  # noqa: E402

erros = []


def fim_ok(caminho, rotulo):
    with open(caminho, "rb") as fh:
        dados = fh.read()
    if not dados.endswith(b"\n"):
        erros.append("%s não termina em quebra de linha" % rotulo)


for entrada, esperado in ((["a:1", "b:2"], "a:1\nb:2\n"), (["a:1", ""], "a:1\n"),
                          ([], ""), (["a:1\n"], "a:1\n")):
    if servidor._texto_de_mapa(entrada) != esperado:
        erros.append("_texto_de_mapa(%r) = %r" % (entrada, servidor._texto_de_mapa(entrada)))

m = servidor.Manipulador.__new__(servidor.Manipulador)
caminho = os.path.join(t, "convertidos.map")
for app in ("um.app", "dois.app", "um.app"):
    msg = m._gravar_linha_convertidos(app, "mauve")
    if msg:
        erros.append("gravar_linha_convertidos(%s): %s" % (app, msg))
    fim_ok(caminho, "o mapa dos convertidos depois de %s" % app)

with open(caminho, encoding="utf-8") as fh:
    if len([l for l in fh.read().split("\n") if l and not l.startswith("#")]) != 2:
        erros.append("o mapa dos convertidos devia ter 2 desenhos")

for e in erros:
    print("FALHOU: " + e, file=sys.stderr)
sys.exit(1 if erros else 0)
PY

[ "$FALHAS" = 0 ] || exit 1
printf 'ok: todo mapa que o painel grava termina em quebra e todo leitor lê o último desenho\n'

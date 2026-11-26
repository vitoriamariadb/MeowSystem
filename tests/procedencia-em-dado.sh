#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/packs" "$T/xdg" "$T/home"

amb() { env MEOW_PACKS="$T/packs" XDG_DATA_HOME="$T/xdg" HOME="$T/home" MEOW_RAIZ="$RAIZ" "$@"; }
pack_py() { amb python3 "$RAIZ/scripts/pack.py" "$@"; }

CABECALHO=$'arquivo\tde onde\tlido de\tlicença\tcopiado em\tsha256'

resultado="$(python3 -I - "$RAIZ" <<'PY'
import os, re, sys
raiz = sys.argv[1]
cab = ["arquivo", "de onde", "lido de", "licença", "copiado em", "sha256"]
ruins = []
for pack in ("dracula", "meowsystem"):
    tsv = os.path.join(raiz, "packs", pack, "procedencia.tsv")
    if not os.path.isfile(tsv):
        ruins.append(f"{pack}: sem procedencia.tsv")
        continue
    linhas = open(tsv, encoding="utf-8").read().split("\n")
    if linhas[-1] != "":
        ruins.append(f"{pack}: o arquivo não termina em quebra de linha")
    linhas = linhas[:-1]
    if linhas[0].split("\t") != cab:
        ruins.append(f"{pack}: cabeçalho {linhas[0]!r}")
    for n, l in enumerate(linhas[1:], 2):
        c = l.split("\t")
        if len(c) != 6:
            ruins.append(f"{pack}:{n}: {len(c)} colunas")
        elif not re.fullmatch(r"[0-9a-f]{64}", c[5]) or any("`" in c[i] for i in (0, 2, 4, 5)):
            ruins.append(f"{pack}:{n}: valor fora da forma")
    md = open(os.path.join(raiz, "packs", pack, "PROCEDENCIA.md"), encoding="utf-8").read()
    repetidas = [l.split("\t")[0] for l in linhas[1:] if f"| `{l.split(chr(9))[0]}` |" in md]
    if repetidas:
        ruins.append(f"{pack}: {len(repetidas)} linha(s) moram nos dois arquivos, como {repetidas[0]}")
print("; ".join(ruins[:6]) if ruins else "limpo")
PY
)"
[ "$resultado" = "limpo" ] \
  && ok "a tabela de procedência do Dracula e do pack-base mora em procedencia.tsv, no formato fixo, e não repete no PROCEDENCIA.md" \
  || falha "a procedência ainda não é dado do pack" "$resultado"

tam="$(wc -c < "$RAIZ/packs/dracula/PROCEDENCIA.md")"
[ "$tam" -lt 60000 ] \
  && ok "o PROCEDENCIA.md do Dracula ficou só com a prosa ($tam bytes)" \
  || falha "o PROCEDENCIA.md do Dracula ainda tem $tam bytes: a tabela não saiu" ""

grep -q 'procedencia\.tsv' "$RAIZ/packs/dracula/PROCEDENCIA.md" \
  && grep -q 'procedencia\.tsv' "$RAIZ/packs/meowsystem/PROCEDENCIA.md" \
  && ok "o PROCEDENCIA.md de cada pack aponta para o arquivo de dados" \
  || falha "o PROCEDENCIA.md de um dos packs não aponta para o procedencia.tsv" ""

brinquedo() {
  local id="$1" d="$T/packs/$1"
  mkdir -p "$d/icones/apps"
  cp "$RAIZ/packs/dracula/paleta.json" "$d/paleta.json"
  printf '{"formato": 2, "id": "%s", "nome": "%s", "paleta": {"arquivo": "paleta.json"}, "icones": {"apps": {"mapa": "icones/apps.map"}}, "vitrine": {"capa": "logo.svg"}}\n' \
    "$id" "$id" > "$d/pack.json"
  : > "$d/icones/apps.map"
  amb python3 "$RAIZ/scripts/pack.py" logo-gerado "$d" > "$d/logo.svg" || return 2
  printf '%s' "$d"
}

d="$(brinquedo lido)"
cp "$RAIZ/packs/dracula/icones/apps/steam.svg" "$d/icones/apps/steam.svg"
sha="$(sha256sum "$d/icones/apps/steam.svg" | cut -d' ' -f1)"
printf '%s\n%s\t%s\t%s\t%s\t%s\t%s\n' "$CABECALHO" "icones/apps/steam.svg" "texto livre" "" "GPL-3.0" "2026-09-23" "$sha" \
  > "$d/procedencia.tsv"
saida="$(pack_py sincronizar lido 2>&1)"; rc=$?
[ "$rc" = "0" ] && printf '%s' "$saida" | grep -q '1 só registro' \
  && ok "o sincronizar lê a linha do procedencia.tsv" \
  || falha "o sincronizar não leu o procedencia.tsv (rc=$rc)" "$saida"

printf '| arquivo | de onde | lido de | licença | copiado em | sha256 |\n|---|---|---|---|---|---|\n| `icones/apps/steam.svg` | x |  | GPL-3.0 | 2026-09-23 | `%s` |\n' "$sha" \
  > "$d/PROCEDENCIA.md"
rm -f "$d/procedencia.tsv"
saida="$(pack_py sincronizar lido 2>&1)"; rc=$?
[ "$rc" = "0" ] && printf '%s' "$saida" | grep -q 'procedencia.tsv' && ! printf '%s' "$saida" | grep -q 'em dia\|só registro' \
  && ok "a tabela no formato antigo do PROCEDENCIA.md deixou de ser lida: o sincronizar diz que falta o arquivo de dados" \
  || falha "o sincronizar ainda lê a tabela do PROCEDENCIA.md (rc=$rc)" "$saida"

printf '%s\n%s\t%s\t%s\n' "$CABECALHO" "icones/apps/steam.svg" "texto livre" "GPL-3.0" > "$d/procedencia.tsv"
saida="$(pack_py sincronizar lido 2>&1)"; rc=$?
[ "$rc" != "0" ] && printf '%s' "$saida" | grep -q 'procedencia.tsv:2' \
  && ok "linha com número de colunas errado é recusada, com o arquivo e a linha" \
  || falha "o sincronizar aceitou uma linha torta (rc=$rc)" "$saida"

printf 'arquivo\tlido de\n' > "$d/procedencia.tsv"
saida="$(pack_py sincronizar lido 2>&1)"; rc=$?
[ "$rc" != "0" ] && printf '%s' "$saida" | grep -q 'sha256' \
  && ok "cabeçalho sem as colunas obrigatórias é recusado" \
  || falha "o sincronizar aceitou um cabeçalho sem sha256 (rc=$rc)" "$saida"

printf '\n'
if [ "$falhas" -eq 0 ]; then
  ok "a procedência é dado do pack, lido de procedencia.tsv"
  exit 0
fi
printf 'FALHOU: %s conferência(s)\n' "$falhas" >&2
exit 1

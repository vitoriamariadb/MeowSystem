#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
for b in sudo pkexec pkill; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/fotos-do-pack.sh\\n" >&2\nexit 1\n' "$b" > "$FALSO/$b"
  chmod 755 "$FALSO/$b"
done
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/rede.log"\nexit 7\n' "$T" > "$FALSO/curl"
chmod 755 "$FALSO/curl"

PACKS="$T/packs"; mkdir -p "$PACKS"
cp -r "$RAIZ/docs/pack-minimo" "$PACKS/fotos"
python3 - "$PACKS/fotos/pack.json" <<'PY'
import json, sys
f = sys.argv[1]
p = json.load(open(f, encoding="utf-8"))
p["id"] = "fotos"
p["nome"] = "Fotos"
p.setdefault("origens", {})["wallpapers"] = {
    "repo": "exemplo/acervo", "commit": "0" * 40, "prefixo": "fot"}
json.dump(p, open(f, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
W="$PACKS/fotos/wallpapers"; mkdir -p "$W" "$T/fora"
png() { printf '\x89PNG\r\n\x1a\n%s\n' "$2" > "$1"; }
png "$W/fot-um.png" um
printf 'jpeg de brinquedo\n' > "$W/avulsa.jpg"
png "$W/recusada.png" recusada
png "$W/nome ruim.png" espaco
png "$T/fora/segredo.png" segredo
ln -s "$T/fora/segredo.png" "$W/vazou.png"
printf 'MIT\n' > "$W/LICENSE"
printf '# recusadas\nrecusada.png\n' > "$T/banidos.txt"

CASA="$T/casa"; mkdir -p "$CASA"
papel() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" MEOW_ESTADO="$T/estado" MEOW_IGNORA_DESKTOP=1 \
    PACK=fotos FLAVOR="" WALLPAPER_BANIDOS="$T/banidos.txt" "$@"
}
AT="$CASA/.local/share/backgrounds/meowsystem/ativos"

seco="$(papel MEOW_DRY_RUN=1 bash "$RAIZ/scripts/wallpaper.sh" semear-se-faltar 2>&1)"; rc_seco=$?
if [ "$rc_seco" = 1 ] && [ ! -e "$AT/fot-um.png" ] && [[ "$seco" != *"rede"* ]]; then
  ok "no ensaio, a semeadura das fotos diz que faria, não escreve e não fala em rede"
else
  falha "o ensaio das fotos do pack escreveu ou pediu rede (rc=$rc_seco)" "$seco"
fi

s1="$(papel bash "$RAIZ/scripts/wallpaper.sh" semear-se-faltar 2>&1)"; rc1=$?
postas="$(ls -1A "$AT" 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
if [ "$rc1" = 1 ] && [ "$postas" = "avulsa.jpg fot-um.png " ] && cmp -s "$W/fot-um.png" "$AT/fot-um.png" \
   && [ ! -s "$T/rede.log" ]; then
  ok "as fotos do pack entram com o nome que têm, sem rede: a recusada, o link e o nome torto ficam fora"
else
  falha "as fotos do pack não entraram como deviam (rc=$rc1)" "ativos: $postas
rede: $(cat "$T/rede.log" 2>/dev/null)
$s1"
fi

s2="$(papel bash "$RAIZ/scripts/wallpaper.sh" semear 2>&1)"; rc2=$?
if [ "$rc2" = 0 ] && [[ "$s2" == *"já semeada"* ]] && [ ! -s "$T/rede.log" ]; then
  ok "a segunda passada não copia nada e continua sem rede"
else
  falha "a segunda semeadura das fotos escreveu ou foi à rede (rc=$rc2)" "$s2"
fi

mkdir -p "$PACKS/sem" && cp -r "$PACKS/fotos/." "$PACKS/sem/" && rm -rf "$PACKS/sem/wallpapers"
python3 - "$PACKS/sem/pack.json" <<'PY'
import json, sys
f = sys.argv[1]
p = json.load(open(f, encoding="utf-8"))
p["id"] = "sem"
json.dump(p, open(f, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
CASA="$T/casa-sem"; mkdir -p "$CASA"
papel PACK=sem bash "$RAIZ/scripts/wallpaper.sh" semear >/dev/null 2>&1
grep -q 'api.github.com/repos/exemplo/acervo' "$T/rede.log" 2>/dev/null \
  && ok "um pack sem fotos continua semeando da origem que declara" \
  || falha "o pack sem fotos deixou de ir à origem dele" "$(cat "$T/rede.log" 2>/dev/null)"

[ "$falhas" = 0 ] || { printf '%d falha(s)\n' "$falhas" >&2; exit 1; }
printf 'fotos-do-pack: tudo ok\n'

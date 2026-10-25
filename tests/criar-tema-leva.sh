#!/usr/bin/env bash
# criar-tema-leva.sh — o que o «Criar tema» leva para dentro do pack que ele
# grava: as fotos (para `wallpapers/`). Vestir o pack põe essas fotos na
# rotação, sem rede. O que vem de quem usa é validado antes de entrar: arquivo
# comum, conteúdo que é o que diz ser, e nome que vira arquivo do lado de cá.
#
# HOME, packs e estado de brinquedo; `curl`, `sudo`, `pkexec` e `pkill` falsos
# que recusam. Nada sai do `mktemp -d`.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
for b in sudo pkexec pkill curl wget cosmic-bg; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/criar-tema-leva.sh\\n" >&2\nexit 1\n' "$b" > "$FALSO/$b"
  chmod 755 "$FALSO/$b"
done

CASA="$T/casa"; mkdir -p "$CASA" "$T/estado"
casa() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$T/estado" MEOW_IGNORA_DESKTOP=1 WALLPAPER_NOITE=nao \
    WALLPAPER_BANIDOS="$T/banidos.txt" "$@"
}
pack() { casa python3 "$RAIZ/scripts/pack.py" "$@"; }
png() { printf '\x89PNG\r\n\x1a\n%s\n' "$2" > "$1"; }

# O pack que o «Guardar» do Criar tema grava: um CSV de cores, pela mesma porta.
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

# --- 1. as fotos --------------------------------------------------------------
AT="$CASA/.local/share/backgrounds/meowsystem/ativos"; mkdir -p "$AT" "$T/fora"
png "$AT/cat-noite.png" "do pack meowsystem"
png "$AT/minha foto.png" "de quem usa"
png "$AT/outra.png" "fica fora do tema"
printf 'texto com nome de foto\n' > "$T/fora/falsa.png"
png "$T/fora/segredo.png" segredo
ln -s "$T/fora/segredo.png" "$AT/vazou.png"

s="$(pack levar meu-tema foto "$AT/cat-noite.png" 2>&1)"; r1=$?
s2="$(pack levar meu-tema foto "$AT/minha foto.png" 2>&1)"; r2=$?
postas="$(ls -1A "$DIR/wallpapers" 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
if [ "$r1" = 0 ] && [ "$r2" = 0 ] && [ "$postas" = "meu-tema-cat-noite.png meu-tema-minha-foto.png " ] \
   && cmp -s "$AT/cat-noite.png" "$DIR/wallpapers/meu-tema-cat-noite.png"; then
  ok "as duas fotos entram em wallpapers/ do pack, com o nome do pack na frente e sem espaço"
else
  falha "as fotos não entraram no pack (rc=$r1/$r2)" "wallpapers: $postas
$s
$s2"
fi

pack levar meu-tema foto "$T/fora/falsa.png" >/dev/null 2>&1; rf=$?
pack levar meu-tema foto "$AT/vazou.png" >/dev/null 2>&1; rl=$?
if [ "$rf" = 1 ] && [ "$rl" = 1 ] && [ "$(ls -1A "$DIR/wallpapers" | wc -l)" = 2 ]; then
  ok "texto com nome de foto e link para fora são recusados, e nada entra"
else
  falha "o pack aceitou o que não é foto, ou um link (rc=$rf/$rl)" "$(ls -1A "$DIR/wallpapers")"
fi

v="$(pack validar meu-tema 2>&1)" \
  && ok "o pack com as fotos continua validando" \
  || falha "o pack com as fotos não valida" "$v"

# Vestir: o que o install roda para o papel de parede, com o pack no ar.
vestir() { casa PACK=meu-tema FLAVOR=meutema bash "$RAIZ/scripts/wallpaper.sh" "$@"; }
vestir semear-se-faltar >/dev/null 2>&1
vestir aplicar >"$T/aplicar.log" 2>&1
GIRA="$CASA/.local/share/backgrounds/meowsystem/ativos-pack"
roda="$(ls -1A "$GIRA" 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
if [[ "$roda" == *"meu-tema-cat-noite.png"* && "$roda" == *"meu-tema-minha-foto.png"* \
      && "$roda" != *" cat-noite.png"* && "$roda" != "cat-noite.png"* ]]; then
  ok "vestido o pack, as duas fotos dele estão na rotação, e a do outro pack não"
else
  falha "as fotos do pack não entraram na rotação" "ativos-pack: $roda
ativos: $(ls -1A "$AT" | tr '\n' ' ')
$(cat "$T/aplicar.log")"
fi

s="$(pack tirar meu-tema foto meu-tema-minha-foto.png 2>&1)"; rt=$?
pack tirar meu-tema foto "../pack.json" >/dev/null 2>&1; rx=$?
if [ "$rt" = 0 ] && [ ! -e "$DIR/wallpapers/meu-tema-minha-foto.png" ] && [ "$rx" = 1 ] \
   && [ -f "$DIR/pack.json" ]; then
  ok "tirar uma foto do pack tira só ela; nome com caminho é recusado"
else
  falha "o tirar foto do pack não fez o que devia (rc=$rt/$rx)" "$s"
fi

pack levar meowsystem foto "$AT/outra.png" >/dev/null 2>&1; rm_=$?
[ "$rm_" = 1 ] && [ -z "$(ls -A "$RAIZ/packs/meowsystem/wallpapers" 2>/dev/null | grep -F outra)" ] \
  && ok "o pack que vem com o MeowSystem não recebe nada" \
  || falha "o levar escreveu num pack do repositório (rc=$rm_)"

[ "$falhas" = 0 ] || { printf '%d falha(s)\n' "$falhas" >&2; exit 1; }
printf 'criar-tema-leva: tudo ok\n'

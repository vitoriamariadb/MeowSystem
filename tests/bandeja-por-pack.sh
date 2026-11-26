#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

for dep in python3 rsvg-convert; do
  command -v "$dep" >/dev/null 2>&1 || { printf 'pulado: sem %s\n' "$dep"; exit 0; }
done

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
printf '#!/bin/sh\nprintf "sudo: recusado pelo tests/bandeja-por-pack.sh\\n" >&2\nexit 1\n' > "$FALSO/sudo"
cat > "$FALSO/flatpak" <<'FIM'
#!/bin/sh
if [ "$1" = info ] && [ "$2" = --show-location ]; then
  printf '%s\n' "$ZZ_LOC"
  exit 0
fi
exit 1
FIM
chmod 755 "$FALSO/sudo" "$FALSO/flatpak"

ZZ_ORIGINAL='import os

_SYMBOLIC = """<svg viewBox="0 0 256 256" xmlns="http://www.w3.org/2000/svg"><path fill="{color}" d="M0 0h256v256z"/>{notify}</svg>"""
'
ZZ_REL="files/lib/python3.12/site-packages/zapzap/assets/icons/tray_icon.py"

casa() {
  local h="$T/casa-$1"
  mkdir -p "$h/.steam/debian-installation/public" "$h/zz/$(dirname "$ZZ_REL")" \
           "$h/.local/share/flatpak/app/com.rtosta.zapzap/x86_64/stable/active" "$h/.local/state/meowsystem"
  cp "$RAIZ/dados/apps/tray-terceiros/steam_tray_mono.png.original" "$h/.steam/debian-installation/public/steam_tray_mono.png"
  printf '%s' "$ZZ_ORIGINAL" > "$h/zz/$ZZ_REL"
  printf '%s' "$h"
}

rodar() {
  local h="$1" pack="$2" flavor="$3" script="$4" modo="$5" packs="${6:-}"
  env -i PATH="$FALSO:$PATH" HOME="$h" MEOW_RAIZ="$RAIZ" NO_COLOR=1 PACK="$pack" FLAVOR="$flavor" \
    ZZ_LOC="$h/zz" ${packs:+MEOW_PACKS="$packs"} \
    "$RAIZ/scripts/$script" "$modo" 2>&1
}

dominante() {
  python3 -I - "$1" <<'PY'
import collections, struct, sys, zlib
d = open(sys.argv[1], 'rb').read()
p, idat, w, h, bpp = 8, b'', 0, 0, 4
while p < len(d):
    n, t = struct.unpack('>I4s', d[p:p + 8])
    c = d[p + 8:p + 8 + n]
    if t == b'IHDR':
        w, h, prof, tipo = struct.unpack('>IIBB', c[:10])
        if prof != 8 or tipo != 6:
            sys.exit('png que o teste nao le')
    if t == b'IDAT':
        idat += c
    if t == b'IEND':
        break
    p += 12 + n
cru = zlib.decompress(idat)
linha, ant, cores = w * bpp, bytearray(w * bpp), collections.Counter()
for y in range(h):
    f, atual = cru[y * (linha + 1)], bytearray(cru[y * (linha + 1) + 1:(y + 1) * (linha + 1)])
    for i in range(linha):
        a = atual[i - bpp] if i >= bpp else 0
        b = ant[i]
        c = ant[i - bpp] if i >= bpp else 0
        if f == 1: atual[i] = (atual[i] + a) & 255
        elif f == 2: atual[i] = (atual[i] + b) & 255
        elif f == 3: atual[i] = (atual[i] + ((a + b) >> 1)) & 255
        elif f == 4:
            pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
            atual[i] = (atual[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
    for x in range(w):
        r, g, b, al = atual[x * 4:x * 4 + 4]
        if al > 200:
            cores[(r, g, b)] += 1
    ant = atual
print('#%02x%02x%02x' % cores.most_common(1)[0][0])
PY
}

prefixo_do_desenho() {
  python3 -I - "$1" <<'PY'
import re, sys
m = re.search(r'\sd="([^"]{40})', open(sys.argv[1], encoding='utf-8').read())
print(m.group(1) if m else '')
PY
}

pack_com() {
  local pack="$1" glifo_zz="$2" flavor="$3" cor="$4" tracado="$5"
  local h saida rc estrito
  h="$(casa "$pack-$flavor")"
  local steam="$h/.steam/debian-installation/public/steam_tray_mono.png"
  local zz="$h/zz/$ZZ_REL"
  local fabrica_steam fabrica_zz
  fabrica_steam="$(sha256sum < "$steam")"
  fabrica_zz="$(sha256sum < "$zz")"

  saida="$(rodar "$h" "$pack" "$flavor" icones_bandeja.sh --aplicar)"; rc=$?
  [ "$rc" = 0 ] && [[ "$saida" != *"não declara icones.bandeja"* ]] \
    && ok "$pack/$flavor: icones_bandeja.sh declara a bandeja e não pula (rc=0)" \
    || falha "$pack/$flavor: icones_bandeja.sh saiu rc=$rc ou pulou" "$saida"

  saida="$(rodar "$h" "$pack" "$flavor" icones_tray_steam.sh --conferir)"; rc=$?
  [ "$rc" = 1 ] && ok "$pack/$flavor: a Steam de fábrica diverge do pack no conferir (rc=1)" \
    || falha "$pack/$flavor: o conferir da Steam saiu rc=$rc" "$saida"
  saida="$(rodar "$h" "$pack" "$flavor" icones_tray_steam.sh --aplicar)"; rc=$?
  [ "$rc" = 1 ] && [ "$(sha256sum < "$steam")" != "$fabrica_steam" ] \
    && ok "$pack/$flavor: a Steam recebeu o glifo do pack" \
    || falha "$pack/$flavor: a Steam não recebeu o glifo (rc=$rc)" "$saida"
  [ "$(dominante "$steam")" = "$cor" ] \
    && ok "$pack/$flavor: o glifo da Steam sai na cor $cor" \
    || falha "$pack/$flavor: a cor dominante do glifo da Steam é $(dominante "$steam"), e não $cor"
  [[ "$saida" != *"packs/meowsystem"* || "$pack" = meowsystem ]] \
    && ok "$pack/$flavor: a Steam não leu o acervo de outro pack" || falha "$pack/$flavor: a Steam leu packs/meowsystem" "$saida"

  saida="$(rodar "$h" "$pack" "$flavor" icones_tray_zapzap.sh --aplicar)"; rc=$?
  [ "$rc" = 1 ] && [ "$(sha256sum < "$zz")" != "$fabrica_zz" ] \
    && grep -qF "$(prefixo_do_desenho "$glifo_zz")" "$zz" \
    && python3 -I -c 'import sys; compile(open(sys.argv[1]).read(), sys.argv[1], "exec")' "$zz" \
    && ok "$pack/$flavor: o ZapZap recebeu o glifo do pack e o arquivo compila" \
    || falha "$pack/$flavor: o ZapZap não recebeu o glifo do pack (rc=$rc)" "$saida"
  grep -q '{color}' "$zz" && grep -q '{notify}' "$zz" \
    && ok "$pack/$flavor: o ZapZap manteve {color} e {notify}" || falha "$pack/$flavor: o ZapZap perdeu {color} ou {notify}"
  estrito="$(grep -c 'stroke-width="4"' "$zz")"
  if [ "$tracado" = sim ]; then
    [ "$estrito" -gt 0 ] && ok "$pack/$flavor: o glifo de traço do pack sai com o traço 4 no ZapZap" \
      || falha "$pack/$flavor: o glifo de traço saiu sem o traço 4 no ZapZap"
  else
    [ "$estrito" = 0 ] && ok "$pack/$flavor: o glifo cheio do pack não leva traço no ZapZap" \
      || falha "$pack/$flavor: o glifo cheio do pack levou o traço do MeowSystem no ZapZap"
  fi

  for s in icones_bandeja.sh icones_tray_steam.sh icones_tray_zapzap.sh; do
    saida="$(rodar "$h" "$pack" "$flavor" "$s" --aplicar)"; rc=$?
    [ "$rc" = 0 ] && ok "$pack/$flavor: a segunda passada de $s não escreve (rc=0)" \
      || falha "$pack/$flavor: a segunda passada de $s saiu rc=$rc" "$saida"
  done
  H_DE="$h"
}

pack_com meowsystem "$RAIZ/packs/meowsystem/icones/biblioteca/whatsapp.svg" mocha "#dedede" sim
pack_com dracula "$RAIZ/packs/dracula/icones/sistema/whatsapp.svg" dracula "#f8f8f2" nao
H_DRACULA="$H_DE"
pack_com dracula "$RAIZ/packs/dracula/icones/sistema/whatsapp.svg" alucard "#4a4f67" nao

mkdir -p "$T/packs"
cp -r "$RAIZ/packs/dracula" "$T/packs/semband"
python3 - "$T/packs/semband/pack.json" <<'PY'
import json, sys
f = sys.argv[1]
p = json.load(open(f, encoding="utf-8"))
p["id"] = "semband"
p["icones"].pop("bandeja", None)
json.dump(p, open(f, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
steam="$H_DRACULA/.steam/debian-installation/public/steam_tray_mono.png"
zz="$H_DRACULA/zz/$ZZ_REL"
saida="$(rodar "$H_DRACULA" semband dracula icones_tray_steam.sh --conferir "$T/packs")"; rc_c=$?
saida2="$(rodar "$H_DRACULA" semband dracula icones_tray_steam.sh --aplicar "$T/packs")"; rc_a=$?
rodar "$H_DRACULA" semband dracula icones_tray_steam.sh --aplicar "$T/packs" >/dev/null; rc_a2=$?
if [ "$rc_c" = 1 ] && [ "$rc_a" = 1 ] && [ "$rc_a2" = 3 ] \
   && cmp -s "$steam" "$RAIZ/dados/apps/tray-terceiros/steam_tray_mono.png.original"; then
  ok "trocar para um pack sem bandeja devolve a Steam de fábrica, e a segunda passada não escreve"
else
  falha "a Steam não voltou ao de fábrica ao sair do pack com bandeja (conferir=$rc_c aplicar=$rc_a segunda=$rc_a2)" "$saida$saida2"
fi
rodar "$H_DRACULA" semband dracula icones_tray_zapzap.sh --aplicar "$T/packs" >/dev/null; rc_z=$?
[ "$rc_z" = 1 ] && [ "$(cat "$zz")" = "${ZZ_ORIGINAL%$'\n'}" ] \
  && ok "trocar para um pack sem bandeja devolve o ZapZap de fábrica" \
  || falha "o ZapZap não voltou ao de fábrica ao sair do pack com bandeja (rc=$rc_z)"

for pack in dracula; do
  saida="$(env -i PATH="$FALSO:$PATH" HOME="$T/casa-validar" MEOW_RAIZ="$RAIZ" NO_COLOR=1 python3 "$RAIZ/scripts/pack.py" validar "$pack" 2>&1)"; rc=$?
  [ "$rc" = 0 ] && ! grep -qi 'bandeja' <<<"$saida" \
    && ok "o validar do $pack aceita a bandeja sem aviso" || falha "o validar do $pack reclamou da bandeja (rc=$rc)" "$saida"
done

if [ "$falhas" -gt 0 ]; then
  printf '\n%d falha(s) na bandeja por pack.\n' "$falhas" >&2
  exit 1
fi
printf '\nSteam e ZapZap recebem o glifo e a cor do pack no ar, a segunda passada não escreve e sair do pack devolve o de fábrica.\n'

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 3; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
for b in sudo pkexec su apt cargo just make pkill killall cosmic-bg notify-send systemctl gsettings dconf busctl curl; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/papel-em-par.sh\\n" >&2\nexit 1\n' "$b" > "$FALSO/$b"
  chmod 755 "$FALSO/$b"
done
DATA_REAL="$(command -v date)"
printf '#!/bin/sh\n[ "$1" = "+%%H:%%M" ] && [ -n "${HORA_FALSA:-}" ] && { echo "$HORA_FALSA"; exit 0; }\nexec %s "$@"\n' "$DATA_REAL" > "$FALSO/date"
chmod 755 "$FALSO/date"

png() {
  python3 - "$1" "$2" <<'PY'
import struct, sys, zlib
cinza = int(sys.argv[2])
linha = b"\x00" + bytes([cinza]) * 8
cru = linha * 8
def bloco(tipo, dados):
    return struct.pack(">I", len(dados)) + tipo + dados + struct.pack(">I", zlib.crc32(tipo + dados) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n" + bloco(b"IHDR", struct.pack(">IIBBBBB", 8, 8, 8, 0, 0, 0, 0)) \
    + bloco(b"IDAT", zlib.compress(cru)) + bloco(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
PY
}

PACKS="$T/packs"; P="$PACKS/par"
mkdir -p "$P/wallpapers/cena" || exit 2
printf '{"formato": 2, "id": "par", "nome": "Par", "heranca": "dracula", "licenca": "GPL-3.0-or-later", "origens": {"wallpapers": {"desenhos": "wallpapers/", "prefixo": "par"}}}\n' \
  > "$P/pack.json"
cp "$RAIZ/packs/dracula/paleta.json" "$P/"
png "$P/wallpapers/cena/torre-dia.png" 20; png "$P/wallpapers/cena/torre-noite.png" 230
png "$P/wallpapers/solto.png" 120
printf 'cena\tdia\tnoite\tlicenca\tdata\ntorre\tcena/torre-dia.png\tcena/torre-noite.png\t\t2026-11-17\nsolto\tsolto.png\t-\tCC0-1.0\t2026-11-17\nfora\t../../fora.png\t-\t\t2026-11-17\n' \
  > "$P/wallpapers/papeis.tsv"

CASA="$T/casa"; B="$CASA/.local/share/backgrounds/meowsystem"; A="$B/ativos"
mkdir -p "$A" "$CASA/cosmic" "$CASA/estado" "$CASA/.local/state/cosmic/com.system76.CosmicBackground/v1" || exit 2
cp "$P/wallpapers/cena/torre-dia.png" "$A/par-cena-torre-dia.png"
cp "$P/wallpapers/cena/torre-noite.png" "$A/par-cena-torre-noite.png"
cp "$P/wallpapers/solto.png" "$A/par-solto.png"
png "$A/par-claro.png" 240; png "$A/par-escuro.png" 10
ESTADO_BG="$CASA/.local/state/cosmic/com.system76.CosmicBackground/v1/wallpapers"
FIXADO="$CASA/estado/wallpaper-fixado"

papel() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_ESTADO="$CASA/estado" MEOW_IGNORA_DESKTOP=1 MEOW_COSMIC_DIR="$CASA/cosmic" MEOW_COSMIC_SISTEMA="$T/sem-cosmic" \
    MEOW_PACKS="$PACKS" PACK=par FLAVOR=dracula XDG_CONFIG_HOME="$CASA/.config" "$@" \
    bash "$RAIZ/scripts/wallpaper.sh" aplicar
}

pares="$(MEOW_PACKS="$PACKS" python3 "$RAIZ/scripts/pack.py" pares par)"
[ "$pares" = "$(printf 'torre\tcena/torre-dia.png\tcena/torre-noite.png')" ] \
  && ok "o pack declara o par e só o par (o solto e o de fora não viram par)" || falha "pares do pack" "$pares"

agora="$(date +%s)"
printf '%s\t%s\n' "$A/par-cena-torre-dia.png" "$agora" > "$FIXADO"
papel HORA_FALSA=23:00 >"$T/s1" 2>&1
[ "$(cut -f1 "$FIXADO")" = "$A/par-cena-torre-noite.png" ] && [ "$(cut -f2 "$FIXADO")" = "$agora" ] \
  && ok "às 23h a torre de dia dá lugar à de noite, e a fixação dura o mesmo" || falha "a noite não trocou o par" "$(cat "$FIXADO" "$T/s1")"
grep -q 'par-cena-torre-noite.png' "$CASA/cosmic/com.system76.CosmicBackground/v1/all" 2>/dev/null \
  && ok "o cosmic-bg aponta para a torre de noite" || falha "o fundo não aponta para o par" "$(cat "$CASA/cosmic/com.system76.CosmicBackground/v1/all" 2>&1)"
antes="$(cat "$FIXADO")"
papel HORA_FALSA=23:30 >"$T/s2" 2>&1; rc=$?
[ "$(cat "$FIXADO")" = "$antes" ] && [ "$rc" = 0 ] && ok "a segunda passada à noite não escreve nada" \
  || falha "a segunda passada mexeu (rc=$rc)" "$(cat "$FIXADO" "$T/s2")"
papel HORA_FALSA=12:00 >/dev/null 2>&1
[ "$(cut -f1 "$FIXADO")" = "$A/par-cena-torre-dia.png" ] && ok "ao meio-dia a torre volta a ser a de dia" || falha "o dia não devolveu o par" "$(cat "$FIXADO")"
papel HORA_FALSA=23:00 NOITE_INICIO=23:30 NOITE_FIM=06:00 >/dev/null 2>&1
[ "$(cut -f1 "$FIXADO")" = "$A/par-cena-torre-dia.png" ] \
  && ok "a troca segue a janela de noite do mascote (NOITE_INICIO), não a do carrossel" || falha "o par ignorou a janela do mascote" "$(cat "$FIXADO")"

if command -v convert >/dev/null 2>&1 || command -v magick >/dev/null 2>&1; then
  [ -e "$B/ativos-dia/par-cena-torre-dia.png" ] && [ -e "$B/ativos-noite/par-cena-torre-noite.png" ] \
    && [ ! -e "$B/ativos-noite/par-cena-torre-dia.png" ] \
    && ok "o par vence a medição: a torre de dia (escura) gira de dia e a de noite (clara) à noite" \
    || falha "o par foi separado pela luz" "$(ls "$B"/ativos-dia "$B"/ativos-noite 2>&1)"
else
  printf 'pulado: sem ImageMagick, o carrossel não se divide em dia e noite\n'
fi

printf '%s\t%s\n' "$A/par-solto.png" "$agora" > "$FIXADO"
papel HORA_FALSA=23:00 >/dev/null 2>&1
[ "$(cut -f1 "$FIXADO")" = "$A/par-solto.png" ] && ok "papel sem par fica como está" || falha "o solto trocou" "$(cat "$FIXADO")"

rm -f "$FIXADO"
printf '[(output: "all", source: Path("%s"))]\n' "$A/par-cena-torre-dia.png" > "$ESTADO_BG"
papel HORA_FALSA=23:00 WALLPAPER_FIXO_TTL=30m WALLPAPER_INTERVALO=5m >"$T/s3" 2>&1
quando="$(cut -f2 "$FIXADO" 2>/dev/null)"
[ "$(cut -f1 "$FIXADO" 2>/dev/null)" = "$A/par-cena-torre-noite.png" ] && [ -n "$quando" ] \
  && [ $(( $(date +%s) - quando )) -ge 1490 ] \
  && ok "no carrossel, a torre que estava na tela vira a de noite só por um intervalo, sem pular de cena" \
  || falha "o carrossel pulou de cena" "$(cat "$FIXADO" "$T/s3" 2>&1)"

rm -f "$FIXADO"
papel HORA_FALSA=23:00 WALLPAPER_FIXO_TTL=0 >/dev/null 2>&1
[ ! -e "$FIXADO" ] && ok "com a fixação sem prazo, o carrossel não é congelado pelo par" || falha "o par congelou o carrossel" "$(cat "$FIXADO")"

rm -f "$FIXADO"
printf '%s\t%s\n' "$A/par-cena-torre-dia.png" "$agora" > "$FIXADO"
papel HORA_FALSA=23:00 MEOW_DRY_RUN=1 >"$T/s4" 2>&1
[ "$(cut -f1 "$FIXADO")" = "$A/par-cena-torre-dia.png" ] && grep -q 'trocaria par-cena-torre-dia.png' "$T/s4" \
  && ok "o ensaio diz a troca e não escreve" || falha "o ensaio escreveu ou calou" "$(cat "$T/s4")"

if [ "$falhas" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$falhas" >&2
  exit 1
fi
exit 0

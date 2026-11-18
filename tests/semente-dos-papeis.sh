#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 3; }
command -v rsvg-convert >/dev/null 2>&1 || { printf 'pulado: sem rsvg-convert\n'; exit 3; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
for b in sudo pkexec su apt cargo just make pkill killall cosmic-bg notify-send systemctl gsettings dconf busctl curl; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/semente-dos-papeis.sh\\n" >&2\nexit 1\n' "$b" > "$FALSO/$b"
  chmod 755 "$FALSO/$b"
done
DATA_REAL="$(command -v date)"
printf '#!/bin/sh\n[ "$1" = "+%%H:%%M" ] && [ -n "${HORA_FALSA:-}" ] && { echo "$HORA_FALSA"; exit 0; }\nexec %s "$@"\n' "$DATA_REAL" > "$FALSO/date"
chmod 755 "$FALSO/date"

svg() {
  printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 9"><rect width="16" height="9" fill="%s"/></svg>\n' "$2" > "$1"
}

casa() {
  CASA="$T/casa-$1"; B="$CASA/.local/share/backgrounds/meowsystem"; A="$B/ativos"
  mkdir -p "$A" "$CASA/cosmic" "$CASA/estado" "$CASA/.local/state/cosmic/com.system76.CosmicBackground/v1" || exit 2
  FIXADO="$CASA/estado/wallpaper-fixado"
}

rodar() {
  local packs="$1" pack="$2" flavor="$3" verbo="$4"; shift 4
  env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_ESTADO="$CASA/estado" MEOW_IGNORA_DESKTOP=1 MEOW_COSMIC_DIR="$CASA/cosmic" MEOW_COSMIC_SISTEMA="$T/sem-cosmic" \
    MEOW_PACKS="$packs" PACK="$pack" FLAVOR="$flavor" XDG_CONFIG_HOME="$CASA/.config" "$@" \
    bash "$RAIZ/scripts/wallpaper.sh" "$verbo"
}

PACKS="$T/packs"; P="$PACKS/soma"; ACERVO="$T/acervo"
mkdir -p "$P/wallpapers/pares" "$ACERVO" || exit 2
printf '{"formato": 2, "id": "soma", "nome": "Soma", "heranca": "dracula", "licenca": "GPL-3.0-or-later", "origens": {"wallpapers": {"repo": "%s", "prefixo": "som"}}}\n' "$ACERVO" > "$P/pack.json"
cp "$RAIZ/packs/dracula/paleta.json" "$P/"
printf 'P3\n1 1\n255\n9 9 9\n' > "$ACERVO/alheia.ppm"
python3 -I -c "
import struct, sys, zlib
def bloco(t, d): return struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
cru = (b'\x00' + bytes([200]) * 8) * 8
open(sys.argv[1], 'wb').write(b'\x89PNG\r\n\x1a\n' + bloco(b'IHDR', struct.pack('>IIBBBBB', 8, 8, 8, 0, 0, 0, 0)) + bloco(b'IDAT', zlib.compress(cru)) + bloco(b'IEND', b''))
" "$ACERVO/alheia.png"
rm -f "$ACERVO/alheia.ppm"
svg "$P/wallpapers/pares/torre-dia.svg" '#eeeeee'; svg "$P/wallpapers/pares/torre-noite.svg" '#101010'
printf 'cena\tdia\tnoite\tlicenca\tdata\ntorre\tpares/torre-dia.svg\tpares/torre-noite.svg\t\t2026-11-17\n' > "$P/wallpapers/papeis.tsv"

casa soma
rodar "$PACKS" soma dracula semear >"$T/s1" 2>&1
[ -f "$A/som-alheia.png" ] && [ -f "$A/som-pares-torre-dia.png" ] && [ -f "$A/som-pares-torre-noite.png" ] \
  && ok "a semente soma: o acervo do pack continua e o par entra junto" || falha "a semente não somou" "$(ls "$A"; cat "$T/s1")"
[ "$(file -b "$A/som-pares-torre-dia.png" | cut -d, -f2 | tr -d ' ')" = "3840x2160" ] \
  && ok "o SVG vira PNG 3840x2160" || falha "o par não foi rasterizado em 4K" "$(file "$A"/som-pares-*)"

antes="$(cd "$A" && sha256sum -- * | sort)"; mt="$(stat -c %Y "$A/som-pares-torre-dia.png")"
rodar "$PACKS" soma dracula semear >"$T/s2" 2>&1; rc=$?
depois="$(cd "$A" && sha256sum -- * | sort)"
[ "$antes" = "$depois" ] && [ "$mt" = "$(stat -c %Y "$A/som-pares-torre-dia.png")" ] && [ "$rc" = 0 ] \
  && ok "a segunda passada não escreve nada" || falha "a segunda passada mexeu (rc=$rc)" "$(cat "$T/s2")"
rodar "$PACKS" soma dracula semear-se-faltar MEOW_DRY_RUN=1 >"$T/s3" 2>&1; rc=$?
[ "$rc" = 0 ] && ! grep -q 'semearia' "$T/s3" && ok "o ensaio de uma instalação em dia não vê nada a semear" || falha "o ensaio viu divergência (rc=$rc)" "$(cat "$T/s3")"

casa antiga
printf 'x' > "$A/som-alheia.png"
rodar "$PACKS" soma dracula semear-se-faltar MEOW_DRY_RUN=1 >"$T/s4" 2>&1; rc=$?
[ "$rc" = 1 ] && grep -q 'semearia som-pares-torre-dia.png' "$T/s4" && [ ! -e "$A/som-pares-torre-dia.png" ] \
  && ok "o ensaio de uma instalação antiga diz o par que falta e não escreve" || falha "o ensaio calou ou escreveu (rc=$rc)" "$(cat "$T/s4"; ls "$A")"
rodar "$PACKS" soma dracula semear-se-faltar >"$T/s5" 2>&1
[ -f "$A/som-pares-torre-dia.png" ] && [ -f "$A/som-pares-torre-noite.png" ] && [ "$(cat "$A/som-alheia.png")" = "x" ] \
  && ok "numa instalação antiga, o par entra e o que já estava fica" || falha "a instalação antiga não ganhou o par" "$(ls "$A"; cat "$T/s5")"
rm -f "$A/som-pares-torre-noite.png"
mkdir -p "$B/banidos"; : > "$B/banidos/som-pares-torre-noite.png"
rodar "$PACKS" soma dracula semear-se-faltar >/dev/null 2>&1
[ ! -e "$A/som-pares-torre-noite.png" ] && ok "o que ela baniu não volta" || falha "o banido voltou" "$(ls "$A")"
rm -f "$B/banidos/som-pares-torre-noite.png"

casa troca
rodar "$PACKS" soma dracula semear >/dev/null 2>&1
agora="$(date +%s)"
printf '%s\t%s\n' "$A/som-pares-torre-dia.png" "$agora" > "$FIXADO"
rodar "$PACKS" soma dracula aplicar HORA_FALSA=23:00 >"$T/s6" 2>&1
[ "$(cut -f1 "$FIXADO")" = "$A/som-pares-torre-noite.png" ] \
  && ok "à noite o papel de dia semeado troca pelo de noite" || falha "a noite não trocou o par semeado" "$(cat "$FIXADO" "$T/s6")"
rodar "$PACKS" soma dracula aplicar HORA_FALSA=12:00 >/dev/null 2>&1
[ "$(cut -f1 "$FIXADO")" = "$A/som-pares-torre-dia.png" ] \
  && ok "de dia volta ao papel de dia" || falha "o dia não devolveu o par" "$(cat "$FIXADO")"

REDE="$T/rede"; mkdir -p "$REDE"
cat > "$REDE/curl" <<CURL
#!/bin/sh
saida=""; url=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) saida="\$2"; shift 2 ;;
    --max-time|--proto|--proto-redir) shift 2 ;;
    -*) shift ;;
    *) url="\$1"; shift ;;
  esac
done
case "\$url" in
  https://api.github.com/*) printf '{"tree":[{"type":"blob","path":"landscapes/lago.png"}]}' ;;
  https://*) [ -n "\$saida" ] && cp "$ACERVO/alheia.png" "\$saida" ;;
  *) exit 1 ;;
esac
CURL
chmod 755 "$REDE/curl"

casa cat-com-rede
rodar "$RAIZ/packs" meowsystem mocha semear-se-faltar PATH="$REDE:$FALSO:$PATH" >"$T/c1" 2>&1
[ -f "$A/cat-landscapes-lago.png" ] && [ "$(find "$A" -maxdepth 1 -name 'cat-pares-*.png' | wc -l)" = 6 ] \
  && ok "meowsystem: o Catppuccin continua descendo e os seis pares entram junto" || falha "meowsystem: a semente não somou" "$(ls "$A"; cat "$T/c1")"

casa cat-sem-rede
rodar "$RAIZ/packs" meowsystem mocha semear-se-faltar >"$T/c2" 2>&1
rodar "$RAIZ/packs" meowsystem mocha semear-se-faltar MEOW_DRY_RUN=1 >"$T/c3" 2>&1; rc=$?
[ "$rc" = 1 ] && grep -q 'semearia os papéis de parede do pack' "$T/c3" \
  && ok "meowsystem instalado sem rede: os pares não passam pelo Catppuccin que falta" || falha "os pares calaram o Catppuccin que falta (rc=$rc)" "$(ls "$A"; cat "$T/c2" "$T/c3")"
rodar "$RAIZ/packs" meowsystem mocha semear-se-faltar PATH="$REDE:$FALSO:$PATH" >"$T/c4" 2>&1
[ -f "$A/cat-landscapes-lago.png" ] && ok "meowsystem: com a rede de volta, o Catppuccin desce" || falha "o Catppuccin não desceu depois" "$(ls "$A"; cat "$T/c4")"

for alvo in "dracula dracula tulip" "meowsystem mocha cat"; do
  set -- $alvo
  casa "real-$1"
  rodar "$RAIZ/packs" "$1" "$2" semear >"$T/r-$1" 2>&1
  n="$(find "$A" -maxdepth 1 -name "$3-pares-*.png" | wc -l)"
  [ "$n" = 6 ] && ok "$1: os seis papéis do pack no ar ($3-pares-*)" || falha "$1: $n papéis em vez de 6" "$(ls "$A"; cat "$T/r-$1")"
  c="$(find "$A" -maxdepth 1 -type f | wc -l)"
  antes="$(cd "$A" && sha256sum -- * | sort)"
  rodar "$RAIZ/packs" "$1" "$2" semear >"$T/r2-$1" 2>&1
  [ "$antes" = "$(cd "$A" && sha256sum -- * | sort)" ] && [ "$c" = "$(find "$A" -maxdepth 1 -type f | wc -l)" ] \
    && ok "$1: a segunda passada não escreve nem duplica" || falha "$1: a segunda passada mexeu" "$(cat "$T/r2-$1")"
done

if [ "$falhas" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$falhas" >&2
  exit 1
fi
exit 0

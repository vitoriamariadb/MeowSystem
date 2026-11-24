#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

CASA="$T/casa"; APPS="$CASA/.local/share/applications"; ESTADO="$CASA/.local/state/meowsystem"
FLAT="$T/flatpak/exports/share"; SIS="$T/sistema/applications"
mkdir -p "$T/bin" "$APPS" "$ESTADO" "$FLAT/applications" "$SIS" "$T/vazio"
for c in sudo pkexec su systemctl systemd-run pkill apt apt-get; do
  printf '#!/bin/sh\nexit 1\n' > "$T/bin/$c"
done
printf '#!/bin/sh\n[ "$1" = list ] && printf "org.example.Vivo\\n"\nexit 0\n' > "$T/bin/flatpak"
printf '#!/bin/sh\nfor d; do :; done; printf "[MIME Cache]\\n" > "$d/mimeinfo.cache"; echo "$d" >> "%s/udd.log"\n' "$T" \
  > "$T/bin/update-desktop-database"
chmod 755 "$T/bin"/*
: > "$T/udd.log"

chamadas() { grep -c . "$T/udd.log"; }
zerar_chamadas() { : > "$T/udd.log"; }
desktop() { { printf '[Desktop Entry]\n'; printf '%s\n' "${@:2}"; } > "$1"; }
cache_em_dia() {
  [ -f "$APPS/mimeinfo.cache" ] \
    && [ -z "$(find "$APPS" -maxdepth 1 -name '*.desktop' -newer "$APPS/mimeinfo.cache" -print -quit)" ]
}
rodar() {
  local s="$1"; shift
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$ESTADO" NO_COLOR=1 \
      XDG_DATA_DIRS="$FLAT:$T/sistema" MEOW_APLICATIVOS_SISTEMA="$SIS" MEOW_APLICATIVOS_FLATPAK="$T/vazio" \
      bash "$RAIZ/scripts/$s" "$@" > "$T/saida" 2>&1
}
ajudante() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$ESTADO" NO_COLOR=1 "$@" \
    bash -c '. "'"$RAIZ"'/scripts/lib/comum.sh"; meow_cache_dos_lancadores "$APPS_TESTE" ${FORCAR_TESTE:-}' > "$T/saida" 2>&1
}

echo "== 1. o ajudante da lib"
export APPS_TESTE="$APPS"
ajudante APPS_TESTE="$T/nao-existe"
igual "pasta que não existe: não chama" "$(chamadas)" 0
ajudante APPS_TESTE="$APPS"
igual "pasta sem lançador: não chama" "$(chamadas)" 0
desktop "$APPS/a.desktop" 'Type=Application' 'Name=A' 'Exec=true'
ajudante APPS_TESTE="$APPS" MEOW_DRY_RUN=1
igual "em ensaio: não chama" "$(chamadas)" 0
ajudante APPS_TESTE="$APPS"
igual "lançador sem cache: chama uma vez" "$(chamadas)" 1
cache_em_dia && ok "a cache ficou mais nova que o lançador" || falha "a cache não ficou mais nova que o lançador"
ajudante APPS_TESTE="$APPS"
igual "cache em dia: a segunda passada não chama" "$(chamadas)" 1
sleep 1; desktop "$APPS/b.desktop" 'Type=Application' 'Name=B' 'Exec=true'
ajudante APPS_TESTE="$APPS"
igual "lançador novo: chama de novo, uma vez" "$(chamadas)" 2
cache_em_dia && ok "e a cache volta a ficar em dia" || falha "a cache não voltou a ficar em dia"

rm -f "$APPS/b.desktop"
ajudante APPS_TESTE="$APPS"
igual "lançador que saiu não deixa a cache velha para o ajudante sem força" "$(chamadas)" 2
ajudante APPS_TESTE="$APPS" FORCAR_TESTE=forcar
igual "com «forcar», a saída de um lançador refaz a cache" "$(chamadas)" 3

echo "== 2. as etapas que escrevem lançador deixam a cache em dia, e a segunda passada não chama"
rm -rf "$APPS"; mkdir -p "$APPS"; zerar_chamadas
sleep 1
desktop "$FLAT/applications/com.boxy_svg.BoxySVG.desktop" 'Type=Application' 'Name=Boxy SVG' \
  'Exec=/usr/bin/flatpak run --command=boxy-svg com.boxy_svg.BoxySVG @@ %f @@' 'Icon=com.boxy_svg.BoxySVG' \
  'StartupWMClass=Boxy SVG' 'X-Flatpak=com.boxy_svg.BoxySVG'
rodar appid_dock.sh --aplicar
igual "appid_dock: refez a cache uma vez" "$(chamadas)" 1
cache_em_dia && ok "appid_dock: a cache é mais nova que as pontes" || falha "appid_dock: a cache ficou velha"
rodar appid_dock.sh --aplicar
igual "appid_dock: a segunda passada não chama" "$(chamadas)" 1

zerar_chamadas
sleep 1
rodar atalho.sh --aplicar
igual "atalho: refez a cache uma vez" "$(chamadas)" 1
cache_em_dia && ok "atalho: a cache é mais nova que o lançador do painel" || falha "atalho: a cache ficou velha"
rodar atalho.sh --aplicar
igual "atalho: a segunda passada não chama" "$(chamadas)" 1

zerar_chamadas
mkdir -p "$ESTADO/libreoffice-atalhos"
desktop "$ESTADO/libreoffice-atalhos/libreoffice-writer.desktop" 'Type=Application' 'Name=Writer' 'Exec=true' \
  'MimeType=application/vnd.oasis.opendocument.text;'
touch -d '2020-01-01' "$ESTADO/libreoffice-atalhos/libreoffice-writer.desktop"
rodar escritorio.sh reverter
[ -f "$APPS/libreoffice-writer.desktop" ] && ok "escritorio: o atalho do LibreOffice voltou à casa" \
  || falha "escritorio: o atalho do LibreOffice não voltou" "$(cat "$T/saida")"
igual "escritorio: a volta com a data antiga (cp -p) refaz a cache uma vez" "$(chamadas)" 1

echo "== 3. nenhuma etapa chama o update-desktop-database por conta própria"
CHAMADA='(^|[;&|({]|\$\(|\bthen|\bdo|\belse)[[:space:]]*((exec|command|env|nice|nohup|sudo)[[:space:]]+)*update-desktop-database([[:space:]]|$)'
soltas="$(grep -rlE "$CHAMADA" "$RAIZ/scripts" "$RAIZ/scripts/lib" "$RAIZ/install.sh" "$RAIZ/scripts" 2>/dev/null \
  | grep -v -e 'scripts/ponte_root.sh$' -e 'scripts/lib/comum.sh$' | sed "s|$RAIZ/||" | sort)"
igual "só o ajudante da lib e a ponte root chamam" "$soltas" ""
achou() { printf '%s\n' "$1" | grep -qE "$CHAMADA"; }
pegas=0; soltos=""
for linha in 'update-desktop-database "$APPS"' 'update-desktop-database -q "$APPS"' 'update-desktop-database $APPS' \
  'update-desktop-database ~/.local/share/applications' 'meow_tem update-desktop-database && update-desktop-database "$d"' \
  '  exec update-desktop-database "$d"' 'x=$(update-desktop-database "$d")' 'if true; then update-desktop-database "$d"; fi'; do
  if achou "$linha"; then pegas=$((pegas + 1)); else soltos="$soltos [$linha]"; fi
done
igual "o guarda pega as variações de chamada${soltos}" "$pegas" 8
pegas=""
for linha in 'meow_tem update-desktop-database || return 0' 'command -v update-desktop-database >/dev/null' \
  'meow_pula "sem update-desktop-database — fica"' '"update-desktop-database|etapa|desktop-file-utils"' \
  'VERBO="gtk-update-icon-cache|update-desktop-database|fc-cache"'; do
  achou "$linha" && pegas="$pegas [$linha]"
done
igual "o guarda não acusa a palavra fora de chamada" "$pegas" ""

if [ "$falhas" -gt 0 ]; then
  printf '\n%d falha(s) na cache dos lançadores.\n' "$falhas" >&2
  exit 1
fi
printf '\ntoda etapa que escreve lançador passa pelo ajudante, a cache fica em dia e a segunda passada não chama.\n'

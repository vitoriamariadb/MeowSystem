#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

GLIFO="${MEOW_TRAY_STEAM_GLIFO:-}"
if [ -z "$GLIFO" ]; then
  for _p in sistema apps biblioteca; do
    GLIFO="$RAIZ/packs/meowsystem/icones/$_p/steam.svg"; [ -f "$GLIFO" ] && break
  done
fi
TRACO="${MEOW_TRAY_STEAM_TRACO:-4}"
COR="${MEOW_TRAY_STEAM_COR:-#DEDEDE}"
FABRICA="$RAIZ/assets/apps/tray-terceiros/steam_tray_mono.png.original"

RELATIVO="public/steam_tray_mono.png"
INVENTARIO="package/steam_client_ubuntu12.installed"

_raiz_steam() {
  local d
  for d in "$HOME/.steam/debian-installation" "$HOME/.steam/steam" \
           "$HOME/.local/share/Steam" "$HOME/.steam/root"; do
    [ -f "$d/$RELATIVO" ] && { readlink -f -- "$d"; return 0; }
  done
  return 1
}

_esperado() {
  local raiz="$1" linha campos
  linha="$(grep -a -m1 "^$RELATIVO," "$raiz/$INVENTARIO" 2>/dev/null)"
  if [ -n "$linha" ]; then
    campos="${linha#*,}"
    printf '%s %s %s\n' "${campos%%;*}" \
      "$(printf '%s' "$campos" | cut -d';' -f2)" \
      "$(printf '%s' "$campos" | cut -d';' -f3)"
    return 0
  fi
  if [ -f "$FABRICA" ]; then
    meow_debug "sem $INVENTARIO — tamanho e crc do backup de fábrica, mtime do arquivo vivo"
    MEOW_MTIME="$(stat -c '%Y' "$raiz/$RELATIVO" 2>/dev/null)" \
      python3 -I - "$FABRICA" <<'PY' 2>/dev/null || return 1
import os, sys, zlib
d = open(sys.argv[1], 'rb').read()
print(len(d), os.environ.get('MEOW_MTIME') or int(os.stat(sys.argv[1]).st_mtime),
      zlib.crc32(d) & 0xffffffff)
PY
    return 0
  fi
  return 1
}

_desenhar() {
  local destino="$1" tam="$2" crc="$3" svg rc
  svg="$(mktemp -t meow-steam-XXXXXX.svg)" || return 1
  if grep -q 'stroke-width' "$GLIFO"; then
    sed -E 's/stroke-width="[^"]*"/stroke-width="'"$TRACO"'"/g; s/currentColor/'"$COR"'/g' "$GLIFO" > "$svg"
  else
    sed -E 's/<(circle|rect|line|polyline|polygon|path|ellipse) /<\1 stroke-width="'"$TRACO"'" /g; s/currentColor/'"$COR"'/g' "$GLIFO" > "$svg"
  fi
  rsvg-convert -w 48 -h 48 -f png -o "$destino.cru" "$svg" 2>/dev/null; rc=$?
  rm -f "$svg"
  [ "$rc" = 0 ] || { rm -f "$destino.cru"; return 1; }

  MEOW_TAM="$tam" MEOW_CRC="$crc" python3 -I - "$destino.cru" "$destino" <<'PY'
import os, struct, sys, zlib

alvo_tam = int(os.environ['MEOW_TAM'])
alvo_crc = int(os.environ['MEOW_CRC'])
base = open(sys.argv[1], 'rb').read()

fim = base.rfind(b'\x00\x00\x00\x00IEND\xaeB`\x82')
if fim < 0:
    sys.exit('png sem IEND')
cabeca, iend = base[:fim], base[fim:]

nota = (b'MeowSystem: o glifo steam do Arcticons (CC BY-SA 4.0) no lugar do '
        b'icone de fabrica da bandeja. Este chunk existe so para o arquivo ter '
        b'o tamanho que package/steam_client_ubuntu12.installed espera. ')
folga = alvo_tam - len(cabeca) - len(iend) - 12 - 4
if folga < 0:
    sys.exit('o desenho ja passa do tamanho de fabrica')
enchimento = (nota + b'-' * folga)[:folga]
corpo = b'meOw' + enchimento
png = (cabeca + struct.pack('>I', len(enchimento)) + corpo
       + struct.pack('>I', zlib.crc32(corpo) & 0xffffffff) + iend)

def f(x): return zlib.crc32(png + struct.pack('>I', x)) & 0xffffffff
c0 = f(0)
pivos = {}
for b0 in range(32):
    v, m = f(1 << b0) ^ c0, 1 << b0
    while v:
        b = v.bit_length() - 1
        if b not in pivos:
            pivos[b] = (v, m); break
        v ^= pivos[b][0]; m ^= pivos[b][1]
x, v = 0, alvo_crc ^ c0
while v:
    b = v.bit_length() - 1
    if b not in pivos:
        sys.exit('nao ha 4 bytes que levem ao crc pedido')
    v ^= pivos[b][0]; x ^= pivos[b][1]

saida = png + struct.pack('>I', x)
if len(saida) != alvo_tam or (zlib.crc32(saida) & 0xffffffff) != alvo_crc:
    sys.exit('o arquivo montado nao bate com o alvo')
open(sys.argv[2], 'wb').write(saida)
PY
  rc=$?
  rm -f "$destino.cru"
  return "$rc"
}

_pronto() {
  if [ ! -f "$GLIFO" ]; then
    meow_pula "sem o glifo steam em packs/meowsystem/icones — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  RAIZ_STEAM="$(_raiz_steam)" || {
    meow_pula "a Steam não está instalada (sem $RELATIVO) — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  meow_tem rsvg-convert || {
    meow_pula "sem rsvg-convert — não dá para rasterizar o glifo"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  meow_tem python3 || {
    meow_pula "sem python3 — não dá para montar o PNG no tamanho de fábrica"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  return "$MEOW_OK"
}

DESEJADO=""
trap '[ -n "$DESEJADO" ] && rm -f "$DESEJADO" "$DESEJADO.cru"' EXIT
_preparar() {
  local esperado tam mtime crc
  esperado="$(_esperado "$RAIZ_STEAM")" || {
    meow_erro "não achei o tamanho/crc de fábrica ($INVENTARIO nem o backup versionado)"
    meow_aviso "sem eles, um arquivo nosso seria desfeito na próxima abertura da Steam"
    return "$MEOW_ERRO"
  }
  read -r tam mtime crc <<<"$esperado"
  MTIME_FABRICA="$mtime"
  DESEJADO="$(mktemp -t meow-steam-XXXXXX.png)" || return "$MEOW_ERRO"
  if ! _desenhar "$DESEJADO" "$tam" "$crc"; then
    meow_erro "não consegui montar o PNG de $tam bytes com crc $crc"
    rm -f "$DESEJADO"; DESEJADO=""
    return "$MEOW_ERRO"
  fi
  meow_debug "alvo: $tam bytes, mtime $mtime, crc $crc"
  return "$MEOW_OK"
}

_igual() {
  cmp -s "$RAIZ_STEAM/$RELATIVO" "$DESEJADO"
}

_conferir() {
  if _igual; then
    meow_ok "o ícone da bandeja da Steam está vestido de Arcticons"
    return "$MEOW_OK"
  fi
  if cmp -s "$RAIZ_STEAM/$RELATIVO" "$FABRICA" 2>/dev/null; then
    meow_muda "o ícone da bandeja da Steam voltou ao de fábrica (o cliente reextraiu public_all.zip)"
  else
    meow_muda "o ícone da bandeja da Steam não é o nosso ($RAIZ_STEAM/$RELATIVO)"
  fi
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local alvo="$RAIZ_STEAM/$RELATIVO" tmp modo
  if _igual; then
    meow_ok "o ícone da bandeja da Steam está vestido de Arcticons"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "mudaria $alvo"
    return "$MEOW_DIVERGENTE"
  fi
  meow_destino_permitido "$alvo" || return "$MEOW_ERRO"

  if [ ! -f "$alvo.meow-original" ]; then
    cp -a "$alvo" "$alvo.meow-original" || {
      meow_erro "não consegui guardar o original em $alvo.meow-original"
      return "$MEOW_ERRO"
    }
  fi
  meow_backup_sistema "$alvo" || {
    meow_erro "não consegui guardar o backup datado de $alvo"
    return "$MEOW_ERRO"
  }

  modo="$(stat -c '%a' "$alvo" 2>/dev/null || echo 775)"
  tmp="$(mktemp -p "$(dirname "$alvo")" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  cp -- "$DESEJADO" "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod "$modo" "$tmp"
  touch -d "@$MTIME_FABRICA" "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$alvo" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  meow_manifesto_registrar "$alvo"

  meow_info "ícone da bandeja da Steam: vestido de Arcticons (traço $TRACO, $COR)"
  meow_info "o ícone novo aparece quando a Steam reabrir"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  case "${1:-}" in
    --conferir|''|--aplicar) ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
  _preparar || return $?
  case "${1:-}" in
    --conferir) _conferir ;;
    *)          _aplicar ;;
  esac
}

main "$@"

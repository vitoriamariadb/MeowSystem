#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

APP_ID="io.github.meowsystem.NowPlaying"
BINARIO="$HOME/.local/bin/meowsystem-now-playing"
SOMBRA="${XDG_DATA_HOME:-$HOME/.local/share}/applications/$APP_ID.desktop"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/$APP_ID/v1"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/meowsystem-now-playing"

MIDIA="${MIDIA:-sim}"
LARGURA="${MIDIA_LARGURA:-440}"
COR="${MIDIA_COR_ALBUM:-traco}"
CAPA="${MIDIA_CAPA:-sim}"
FONTE="${MIDIA_FONTE:-auto}"
COR_TITULO="${MIDIA_COR_TITULO:-mauve}"
COR_ARTISTA="${MIDIA_COR_ARTISTA:-green}"
CONTROLES="${MIDIA_CONTROLES:-nao}"
_FLAVOR="$(meow_flavor)"
PALETA="$(meow_paleta)"

CONFERIR=0; REVERTER=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  --reverter) REVERTER=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--reverter]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && [ "$REVERTER" = 0 ] && CONFERIR=1

_largura_valida() {
  case "$LARGURA" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$LARGURA" -ge 80 ] && [ "$LARGURA" -le 900 ]
}

_cor_valida() { [ "$COR" = "traco" ] || [ "$COR" = "chapado" ]; }

_capa_valida() { [ "$CAPA" = "sim" ] || [ "$CAPA" = "nao" ]; }
_controles_valido() { [ "$CONTROLES" = "sim" ] || [ "$CONTROLES" = "nao" ]; }

_capa_valor() { [ "$CAPA" = "sim" ] && printf 'true' || printf 'false'; }

_cor_hex() {
  local nome="$1"
  [ "$nome" = "auto" ] && { printf 'auto'; return 0; }
  python3 -I -c '
import json, sys
try:
    p = json.load(open(sys.argv[1]))["flavors"][sys.argv[2]]
except Exception:
    sys.exit(1)
v = p.get(sys.argv[3])
if not isinstance(v, str) or not v.startswith("#"):
    sys.exit(1)
print(v.lower())
' "$PALETA" "$_FLAVOR" "$nome" 2>/dev/null
}

_cor_nome_valido() { [ -n "$(_cor_hex "$1")" ]; }

_fonte_valida() {
  [ "$FONTE" = "auto" ] && return 0
  case "$FONTE" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "$FONTE" -ge 6 ] && [ "$FONTE" -le 48 ]
}

_fonte_valor() { [ "$FONTE" = "auto" ] && printf '0' || printf '%s' "$FONTE"; }

_texto_cor() {
  local hex; hex="$(_cor_hex "$1")"
  [ "$hex" = auto ] && hex=""
  printf '"%s"' "$hex"
}

_chaves() {
  printf '%s\t%s\n' panel_text_width   "$LARGURA"
  printf '%s\t%s\n' panel_color_style  "\"$COR\""
  printf '%s\t%s\n' album_art_remote   "$(_capa_valor)"
  printf '%s\t%s\n' panel_font_size    "$(_fonte_valor)"
  printf '%s\t%s\n' title_color        "$(_texto_cor "$COR_TITULO")"
  printf '%s\t%s\n' artist_color       "$(_texto_cor "$COR_ARTISTA")"
  printf '%s\t%s\n' panel_controls     "$([ "$CONTROLES" = "sim" ] && printf true || printf false)"
}

_pronto() {
  if ! _largura_valida; then
    meow_aviso "MIDIA_LARGURA=\"$LARGURA\" fora de 80..900 — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _cor_valida; then
    meow_aviso "MIDIA_COR_ALBUM=\"$COR\" não existe (use traco ou chapado) — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _capa_valida; then
    meow_aviso "MIDIA_CAPA=\"$CAPA\" não existe (use sim ou nao) — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _controles_valido; then
    meow_aviso "MIDIA_CONTROLES=\"$CONTROLES\" não existe (use sim ou nao) — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _fonte_valida; then
    meow_aviso "MIDIA_FONTE=\"$FONTE\" não serve (use auto ou 6..48) — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  local c
  for c in "$COR_TITULO" "$COR_ARTISTA"; do
    if ! _cor_nome_valido "$c"; then
      meow_aviso "a cor \"$c\" não existe na paleta $_FLAVOR — confira o meow.conf"
      meow_info "  nomes válidos: os do $(meow_paleta_nome) (mauve, green, blue, peach…), ou auto"
      return "$MEOW_SEM_DEPENDENCIA"
    fi
  done
  return "$MEOW_OK"
}

_conferir() {
  if [ ! -x "$BINARIO" ]; then
    meow_pula "o applet de mídia ainda não foi instalado — nada a configurar ainda"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local nome valor
  while IFS=$'\t' read -r nome valor; do
    [ -f "$CONFIG/$nome" ] || { meow_muda "falta a chave $nome do applet de mídia"; return "$MEOW_DIVERGENTE"; }
    [ "$(cat "$CONFIG/$nome" 2>/dev/null)" = "$valor" ] || {
      meow_muda "a chave $nome do applet de mídia diz '$(cat "$CONFIG/$nome")' e devia dizer '$valor'"
      return "$MEOW_DIVERGENTE"
    }
  done <<< "$(_chaves)"

  meow_ok "applet de mídia no lugar (largura $LARGURA, fonte $FONTE, cor $COR, título $COR_TITULO, artista $COR_ARTISTA)"
  return "$MEOW_OK"
}

_aplicar() {
  local mudou=0 rc

  if [ ! -x "$BINARIO" ]; then
    meow_pula "o applet de mídia ainda não foi instalado — nada a configurar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local nome valor
  while IFS=$'\t' read -r nome valor; do
    meow_escrever "$CONFIG/$nome" "$valor" 644
    rc=$?
    case $rc in
      1) mudou=1 ;;
      2) meow_erro "não consegui escrever $CONFIG/$nome"; return "$MEOW_ERRO" ;;
    esac
  done <<< "$(_chaves)"

  if meow_seco; then
    [ "$mudou" = 1 ] && return "$MEOW_DIVERGENTE"
    meow_ok "applet de mídia já estava no lugar"
    return "$MEOW_OK"
  fi

  if [ "$mudou" = 0 ]; then
    meow_ok "applet de mídia já estava no lugar (largura $LARGURA, fonte $FONTE, título $COR_TITULO, artista $COR_ARTISTA)"
    return "$MEOW_OK"
  fi
  if [ "$CONTROLES" = "sim" ]; then
    meow_ok "applet de mídia configurado: capa, nome e ⏮⏸⏭ na barra"
  else
    meow_ok "applet de mídia configurado: capa e nome na barra; os ⏮⏸⏭ são os do applet de Som"
  fi
  return "$MEOW_DIVERGENTE"
}

_reverter() {
  local mexeu=0
  if meow_seco; then
    [ -d "$CONFIG" ] && { meow_muda "removeria as chaves $CONFIG"; mexeu=1; }
    [ -d "$CACHE" ]  && { meow_muda "removeria o cache $CACHE"; mexeu=1; }
    [ "$mexeu" = 1 ] && return "$MEOW_DIVERGENTE"
    meow_pula "não há configuração de mídia nossa para remover"
    return "$MEOW_OK"
  fi

  [ -d "$CONFIG" ] && { rm -rf "$CONFIG"; mexeu=1; }
  [ -d "$CACHE" ] && { rm -rf "$CACHE"; mexeu=1; }
  "$RAIZ/scripts/extensoes_build.sh" now-playing --reverter >/dev/null 2>&1
  [ $? = 1 ] && mexeu=1

  if [ "$mexeu" = 0 ]; then
    meow_pula "não havia applet de mídia nosso para remover"
    return "$MEOW_OK"
  fi
  meow_ok "applet de mídia removido"
  return "$MEOW_DIVERGENTE"
}

main() {
  [ "$REVERTER" = 1 ] && { _reverter; return $?; }
  if [ "$MIDIA" != "sim" ]; then
    meow_pula "MIDIA=\"$MIDIA\" no meow.conf — o applet de mídia fica sem as chaves do MeowSystem"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  _pronto || return $?
  if [ "$CONFERIR" = 1 ]; then _conferir; else _aplicar; fi
}

main "$@"

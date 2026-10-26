#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

BASE="${HICOLOR_BASE:-$HOME/.local/share/icons/hicolor}"
INDEX="$BASE/index.theme"

[ -d "$BASE" ] || { meow_pula "não há hicolor do usuário em $BASE — nada a fazer"; exit "$MEOW_OK"; }

contexto_de() {
  case "$1" in
    apps)       echo Applications ;;
    actions)    echo Actions ;;
    animations) echo Animations ;;
    categories) echo Categories ;;
    devices)    echo Devices ;;
    emblems)    echo Emblems ;;
    emotes)     echo Emotes ;;
    intl)       echo International ;;
    mimetypes)  echo MimeTypes ;;
    places)     echo Places ;;
    status)     echo Status ;;
    *)          echo Applications ;;
  esac
}

pares_com_icone() {
  local d ctx
  for d in "$BASE"/*/; do
    d="${d%/}"; d="$(basename "$d")"
    case "$d" in scalable|[0-9]*x[0-9]*) ;; *) continue ;; esac
    for ctx in "$BASE/$d"/*/; do
      [ -d "$ctx" ] || continue
      ctx="${ctx%/}"; ctx="$(basename "$ctx")"
      [ -n "$(find "$BASE/$d/$ctx" -maxdepth 1 -type f -print -quit 2>/dev/null)" ] || continue
      printf '%s/%s\n' "$d" "$ctx"
    done
  done | sort -u
}

ordenar() {
  while IFS= read -r p; do
    local dir="${p%%/*}"
    case "$dir" in
      scalable) printf '999999 %s\n' "$p" ;;
      *) printf '%06d %s\n' "${dir%%x*}" "$p" ;;
    esac
  done | sort -n | cut -d' ' -f2-
}

mapfile -t PARES < <(pares_com_icone | ordenar)

if [ "${#PARES[@]}" -eq 0 ]; then
  meow_pula "o hicolor do usuário não tem ícone nenhum — nada a declarar"
  exit "$MEOW_OK"
fi

gerar_index() {
  local p dir ctx tam
  printf '[Icon Theme]\n'
  printf 'Name=Hicolor\n'
  printf 'Comment=Fallback Icon Theme\n'
  printf 'Hidden=true\n'
  printf 'Directories=%s\n' "$(printf '%s,' "${PARES[@]}" | sed 's/,$//')"

  for p in "${PARES[@]}"; do
    dir="${p%%/*}"; ctx="${p##*/}"
    printf '\n[%s]\n' "$p"
    if [ "$dir" = "scalable" ]; then
      printf 'Size=128\n'
      printf 'MinSize=8\n'
      printf 'MaxSize=512\n'
      printf 'Type=Scalable\n'
    else
      tam="${dir%%x*}"
      printf 'Size=%s\n' "$tam"
      printf 'Type=Fixed\n'
    fi
    printf 'Context=%s\n' "$(contexto_de "$ctx")"
  done
}

NOVO="$(gerar_index)"

_hicolor_cache_velha() {
  [ -f "$BASE/icon-theme.cache" ] \
    && [ -n "$(find "$BASE" -mindepth 1 -newer "$BASE/icon-theme.cache" -print -quit 2>/dev/null)" ]
}

if [ -f "$INDEX" ] && [ "$NOVO" = "$(cat "$INDEX" 2>/dev/null)" ]; then
  if _hicolor_cache_velha; then
    if meow_seco; then
      meow_muda "reindexaria a cache do hicolor do usuário (ela é mais velha que algum ícone dele)"
      exit "$MEOW_DIVERGENTE"
    fi
    if meow_tem gtk-update-icon-cache && gtk-update-icon-cache -q -f "$BASE" 2>/dev/null; then
      meow_muda "cache do hicolor do usuário reindexada (algum programa plantou ícone sem reindexar)"
      exit "$MEOW_DIVERGENTE"
    fi
    meow_aviso "a cache do hicolor do usuário está velha e não consegui reindexá-la"
    exit "$MEOW_ERRO"
  fi
  meow_ok "hicolor do usuário já declara as ${#PARES[@]} pastas que tem"
  exit "$MEOW_OK"
fi

antes=0
if [ -f "$INDEX" ]; then
  antes="$(grep -cE '^\[[^]]+/[^]]+\]' "$INDEX" 2>/dev/null)"; antes="${antes:-0}"
fi

if meow_seco; then
  meow_muda "declararia ${#PARES[@]} pastas no hicolor do usuário (hoje: $antes)"
  exit "$MEOW_DIVERGENTE"
fi

if [ -f "$INDEX" ]; then
  DIR_BK="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/backups/${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"
  mkdir -p "$DIR_BK"
  cp -a "$INDEX" "$DIR_BK/hicolor-index.theme" 2>/dev/null \
    && printf '%s\n' "$INDEX" >> "$DIR_BK/origens.txt"
fi

meow_escrever "$INDEX" "$NOVO" 644
case $? in 2) meow_erro "não consegui escrever $INDEX"; exit "$MEOW_ERRO" ;; esac

CACHE="$BASE/icon-theme.cache"
if [ -f "$CACHE" ]; then
  if meow_tem gtk-update-icon-cache; then
    if gtk-update-icon-cache -q -f "$BASE" 2>/dev/null; then
      meow_info "cache do hicolor reindexada"
    else
      meow_aviso "não consegui reindexar $CACHE — apague-a se algum ícone não aparecer"
    fi
  else
    meow_aviso "$CACHE está velha e esconde os ícones, e não há gtk-update-icon-cache"
    meow_info "  apague o arquivo: rm '$CACHE'"
  fi
fi

meow_ok "hicolor do usuário: ${#PARES[@]} pastas declaradas (antes: $antes)"
meow_info "as logos que só existiam em tamanho não declarado voltam a aparecer"
exit "$MEOW_DIVERGENTE"

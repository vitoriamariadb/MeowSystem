#!/usr/bin/env bash

meow_icones_escala_pct() {
  local pct=''
  if command -v cosmic-randr >/dev/null 2>&1; then
    pct="$(cosmic-randr list 2>/dev/null \
           | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
           | sed -n 's/.*[Ss]cale:[[:space:]]*\([0-9][0-9]*\)%.*/\1/p' \
           | head -n1)"
  fi
  case "$pct" in
    ''|*[!0-9]*) printf '100' ;;
    0)           printf '100' ;;
    *)           printf '%s' "$pct" ;;
  esac
}

MEOW_ICONES_CANONICOS="16 22 24 32 48 56 64 72 80 96 128 256 512"

MEOW_ICONES_TETO_LOGICO="${MEOW_ICONES_TETO_LOGICO:-76}"
MEOW_ICONES_PISO_LOGICO="${MEOW_ICONES_PISO_LOGICO:-16}"

meow_icones_escada() {
  local pct piso teto d saida='' n=0
  pct="$(meow_icones_escala_pct)"

  piso=$(( MEOW_ICONES_PISO_LOGICO * pct * 80 / 10000 ))
  teto=$(( MEOW_ICONES_TETO_LOGICO * pct * 125 / 10000 ))
  [ "$piso" -lt 1 ] && piso=1

  for d in $MEOW_ICONES_CANONICOS; do
    if [ "$d" -ge "$piso" ] && [ "$d" -le "$teto" ]; then
      saida="$saida$d
"
      n=$((n + 1))
    fi
  done

  if [ "$n" -lt 4 ]; then
    printf '24\n32\n48\n64\n96\n'
    return 0
  fi
  printf '%s' "$saida"
}

meow_icones_escada_dita() {
  meow_icones_escada | tr '\n' ' ' | sed 's/ $//'
}

meow_hicolor_reindexar() {
  local base="${1:-$HOME/.local/share/icons/hicolor}"
  local cache="$base/icon-theme.cache"
  meow_seco && return 0
  [ -f "$cache" ] || return 0
  meow_tem gtk-update-icon-cache || {
    meow_aviso "$cache está velha e esconde os ícones novos, e não há gtk-update-icon-cache"
    meow_info "  apague o arquivo: rm '$cache'"
    return 1
  }
  gtk-update-icon-cache -q -f "$base" 2>/dev/null || {
    meow_aviso "não consegui reindexar $cache — apague-a se algum ícone não aparecer"
    return 1
  }
  meow_debug "cache do hicolor reindexada"
  return 0
}

meow_icones_derivados() {
  local fonte="$1" nome="$2"
  local tema="${3:-$HOME/.local/share/icons/${NOME_TEMA_ICONES:-MeowSystem-Icons}}"
  case "$fonte" in
    *.svg) printf 'scalable\t%s/scalable/apps/%s.svg\n' "$tema" "$nome" ;;
    *) printf 'fonte não é SVG, e raster não é fonte: %s\n' "$fonte" >&2; return 2 ;;
  esac
}

meow_icones_derivar() {
  local fonte="$1" nome="$2" tema="${3:-}" plano tipo destino conteudo rc=0 r
  plano="$(meow_icones_derivados "$fonte" "$nome" ${tema:+"$tema"})" || return 2
  conteudo="$(cat "$fonte" 2>/dev/null)" || { meow_erro "não consegui ler $fonte"; return 2; }
  while IFS=$'\t' read -r tipo destino; do
    [ -n "$destino" ] || continue
    case "$tipo" in
      scalable) meow_escrever "$destino" "$conteudo" 644; r=$? ;;
      *) meow_erro "derivado sem escritor: $tipo"; r=2 ;;
    esac
    case "$r" in
      0) : ;;
      1) [ "$rc" = "0" ] && rc=1 ;;
      *) rc=2 ;;
    esac
  done <<< "$plano"
  return "$rc"
}

meow_tema_base_escondida() {
  local dir="$1" idx="$1/index.theme" tmp soma
  [ -f "$idx" ] || return "$MEOW_ERRO"
  if awk '/^\[/{sec=$0} sec=="[Icon Theme]" && $0=="Hidden=true"{achou=1} END{exit !achou}' "$idx"; then
    return "$MEOW_OK"
  fi
  tmp="$(mktemp -p "$dir" .meow.XXXXXX)" || return "$MEOW_ERRO"
  awk '/^\[/{sec=$0} sec=="[Icon Theme]" && /^Hidden=/{next}
       {print} $0=="[Icon Theme]" && !feito {print "Hidden=true"; feito=1}' "$idx" > "$tmp" \
    || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod --reference="$idx" "$tmp" 2>/dev/null
  mv -f "$tmp" "$idx" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  if [ -f "$dir/.meow-somas.sha256" ]; then
    soma="$(cd "$dir" && sha256sum ./index.theme)" || return "$MEOW_ERRO"
    tmp="$(mktemp -p "$dir" .meow.XXXXXX)" || return "$MEOW_ERRO"
    awk -v nova="$soma" '$2=="./index.theme"{print nova; next} {print}' "$dir/.meow-somas.sha256" > "$tmp" \
      && mv -f "$tmp" "$dir/.meow-somas.sha256" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  fi
  return "$MEOW_DIVERGENTE"
}

meow_tema_exportado_heranca() {
  local icones="$1" nome="$2" tema="$1/$2" h camadas=() herda c
  for h in $(sed -n 's/^Inherits=//p' "$tema/index.theme" | head -1 | tr ',' ' '); do
    case "$h" in "$nome"-Base|"$nome"-Base-[0-9]*) [ -d "$icones/$h" ] && camadas+=("$h") ;; esac
  done
  herda="$(printf '%s,' ${camadas[@]+"${camadas[@]}"})Cosmic,Adwaita,hicolor"
  _meow_herdar "$tema/index.theme" "$herda" || return "$MEOW_ERRO"
  for c in ${camadas[@]+"${camadas[@]}"}; do
    _meow_herdar "$icones/$c/index.theme" "hicolor" || return "$MEOW_ERRO"
    rm -f "$icones/$c/.meow-origem" "$icones/$c/.meow-somas.sha256"
    meow_tema_base_escondida "$icones/$c"; [ "$?" -le 1 ] || return "$MEOW_ERRO"
  done
  printf '%s\n' ${camadas[@]+"${camadas[@]}"}
}

_meow_herdar() {
  local tmp; tmp="$(mktemp -p "$(dirname "$1")" .meow.XXXXXX)" || return 1
  awk -v h="$2" 'BEGIN{feito=0} /^Inherits=/ && !feito {print "Inherits=" h; feito=1; next} {print}' "$1" > "$tmp" \
    && mv -f "$tmp" "$1"
}

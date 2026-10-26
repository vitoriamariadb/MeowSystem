#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"
TABELA="$ESTADO/derivados.tsv"
REGISTRO="$ESTADO/derivados.log"
TEMA_NOME="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA_NOME"
ESPERA="${MEOW_DERIVADOS_ESPERA:-2}"

_pack_ref="$(meow_pack_dir)"
[ -n "$_pack_ref" ] || _pack_ref="$(meow_pack_padrao_dir || true)"

_fontes() { python3 "$RAIZ/scripts/pack.py" derivados "$_pack_ref" fontes 2>/dev/null; }
_pastas() { python3 "$RAIZ/scripts/pack.py" derivados "$_pack_ref" pastas 2>/dev/null; }

_foto() {
  local p
  while IFS= read -r p; do
    find "$p" -maxdepth 1 -type f -printf '%p %s %T@\n' 2>/dev/null
  done < <(_pastas) | sort | sha256sum
}

_quieto() {
  local antes depois voltas=0
  [ "$ESPERA" = "0" ] && return 0
  antes="$(_foto)"
  while :; do
    sleep "$ESPERA"
    depois="$(_foto)"
    [ "$depois" = "$antes" ] && return 0
    antes="$depois"; voltas=$((voltas + 1))
    [ "$voltas" -ge 30 ] && return 0
  done
}

_passos_de() {
  case "$1" in
    */logo.svg)                                printf 'completar\n' ;;
    */icones/apps.map)                         printf 'dracula\napps\narcticons\n' ;;
    */icones/apps-resgatados.map)              printf 'resgatados\narcticons\n' ;;
    */icones/apps-arcticons.map|*/icones/apps-convertidos.map|*/icones/apps-marca.map) printf 'arcticons\n' ;;
    */icones/apps-hicolor.map)                 printf 'completar\n' ;;
    */icones/sistema.map)                      printf 'sistema\n' ;;
    */icones/bandeja.map)                      printf 'bandeja\n' ;;
    */icones/pastas.map)                       printf 'pastas\n' ;;
    */icones/mimetypes.map)                    printf 'mimetypes\n' ;;
    */icones/sistema/leitura-*)                : ;;
    */icones/apps/*)                           printf 'dracula\nresgatados\narcticons\ncompletar\n' ;;
    */icones/sistema/*)                        printf 'sistema\nbandeja\npastas\nmimetypes\n' ;;
    */icones/biblioteca/*)                     printf 'dracula\narcticons\n' ;;
  esac
}

_rodar() {
  local tema="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
  case "$1" in
    dracula)    ICONES_DRACULA="${ICONES_DRACULA:-sim}" NOME_TEMA_ICONES="$tema" \
                  "$RAIZ/scripts/icones_apps_dracula.sh" --aplicar ;;
    resgatados) ICONES_RESGATADOS="${ICONES_RESGATADOS:-sim}" NOME_TEMA_ICONES="$tema" \
                  "$RAIZ/scripts/icones_resgatados.sh" --aplicar ;;
    arcticons)  "$RAIZ/scripts/construir_convertidos.sh" --so-mao
                FLAVOR="${FLAVOR:-}" ICONES_COR_MARCA="${ICONES_COR_MARCA:-nao}" ICONES_TEMA="$tema" \
                  "$RAIZ/scripts/icones_apps_arcticons.sh" ;;
    completar)  FLAVOR="${FLAVOR:-}" ACCENT="${ACCENT:-}" NOME_TEMA_ICONES="$tema" \
                  "$RAIZ/scripts/completar_icones.sh" ;;
    sistema)    ICONES_TEMA="$tema" "$RAIZ/scripts/icones_sistema.sh" ;;
    bandeja)    ICONES_TEMA="$tema" "$RAIZ/scripts/icones_bandeja.sh" ;;
    mimetypes)  ICONES_FLAVOR="${ICONES_FLAVOR:-}" ICONES_TEMA="$tema" "$RAIZ/scripts/icones_mimetypes.sh" ;;
    pastas)     PASTAS_XDG="${PASTAS_XDG:-nao}" ICONES_FLAVOR="${ICONES_FLAVOR:-}" ICONES_TEMA="$tema" \
                  "$RAIZ/scripts/icones_pastas.sh"
                ICONES_BASE="${ICONES_BASE:-Papirus-Dark}" NOME_TEMA_ICONES="$tema" \
                  ICONES_PASTAS="${ICONES_PASTAS:-cat-${FLAVOR:-}-${ACCENT:-}}" \
                  "$RAIZ/scripts/construir_pastas.sh" ;;
  esac
}

_cache() {
  local cache="$TEMA_DIR/icon-theme.cache"
  [ -f "$cache" ] || return 0
  [ -n "$(find "$TEMA_DIR" -newer "$cache" \( -name '*.svg' -o -name '*.png' \) -print -quit 2>/dev/null)" ] \
    || [ "${1:-0}" = "1" ] || return 0
  meow_tem gtk-update-icon-cache || return 0
  gtk-update-icon-cache -q -f "$TEMA_DIR" 2>/dev/null
}

_comparar() {
  local agora="$1"
  if [ ! -f "$TABELA" ]; then
    awk -F'\t' '{ print "mudou\t" $1 }' "$agora"
    return
  fi
  awk -F'\t' 'NR == FNR { velho[$1] = $2; next }
              { if (velho[$1] != $2) print "mudou\t" $1; visto[$1] = 1 }
              END { for (c in velho) if (!(c in visto)) print "saiu\t" c "\t" velho[c] }' \
    "$TABELA" "$agora" | sort
}

_registrar() {
  local agora="$1"
  if [ -f "$TABELA" ] && cmp -s "$agora" "$TABELA"; then
    return 0
  fi
  mkdir -p "$ESTADO" && cp "$agora" "$TABELA.novo" && mv -f "$TABELA.novo" "$TABELA"
}

_passada() {
  local modo="$1" tmp agora diferencas mudou=0 rc=0 passo c tipo sha
  tmp="$(mktemp -d)" || { meow_erro "não consegui um temporário"; return "$MEOW_ERRO"; }
  agora="$tmp/agora.tsv"
  _fontes > "$agora"
  if [ ! -s "$agora" ]; then
    rm -rf "$tmp"; meow_pula "nenhum desenho de pack a vigiar"; return "$MEOW_SEM_DEPENDENCIA"
  fi
  diferencas="$(_comparar "$agora")"
  if [ "$modo" = "registrar" ] && meow_seco; then
    rm -rf "$tmp"
    [ -z "$diferencas" ] && { meow_ok "derivados: a tabela dos desenhos está em dia"; return "$MEOW_OK"; }
    meow_muda "derivados: registraria $(grep -c . <<<"$diferencas") mudança(s) na tabela dos desenhos"
    return "$MEOW_DIVERGENTE"
  fi
  if [ "$modo" = "registrar" ]; then
    _registrar "$agora"; rc=$?
    rm -rf "$tmp"
    [ "$rc" = 0 ] || { meow_erro "não consegui gravar $TABELA"; return "$MEOW_ERRO"; }
    if [ -n "$diferencas" ]; then
      meow_muda "derivados: a tabela dos desenhos registrou $(grep -c . <<<"$diferencas") mudança(s)"
      return "$MEOW_DIVERGENTE"
    fi
    meow_ok "derivados: a tabela dos desenhos está em dia ($(grep -c . "$TABELA") fontes)"
    return "$MEOW_OK"
  fi
  if [ -z "$diferencas" ]; then
    rm -rf "$tmp"
    meow_ok "derivados em dia com os desenhos ($(grep -c . "$TABELA") fontes)"
    return "$MEOW_OK"
  fi
  if [ "$modo" = "conferir" ]; then
    meow_muda "derivados: $(grep -c . <<<"$diferencas") desenho(s) mudaram desde a última passada"
    rm -rf "$tmp"; return "$MEOW_DIVERGENTE"
  fi

  local saiu=() vivos
  vivos="$(cut -f2 "$agora")"
  while IFS=$'\t' read -r tipo c sha; do
    [ "$tipo" = "saiu" ] && ! grep -qxF "$sha" <<<"$vivos" && saiu+=("$sha")
  done <<<"$diferencas"
  if [ "${#saiu[@]}" -gt 0 ] && [ -d "$TEMA_DIR" ]; then
    while IFS= read -r c; do
      [ -n "$c" ] || continue
      rm -f "$c" && mudou=1
    done < <(python3 "$RAIZ/scripts/pack.py" derivados "$_pack_ref" copias "$TEMA_DIR" "${saiu[@]}" 2>/dev/null)
  fi

  local -A pedir=()
  while IFS=$'\t' read -r tipo c _sha; do
    while IFS= read -r passo; do [ -n "$passo" ] && pedir["$passo"]=1; done < <(_passos_de "$c")
  done <<<"$diferencas"
  MEOW_RELER_NO_FIM="$(mktemp "${TMPDIR:-/tmp}/meow-reler.XXXXXX" 2>/dev/null)" && export MEOW_RELER_NO_FIM
  local feitos=()
  for passo in completar mimetypes resgatados arcticons dracula sistema bandeja pastas; do
    [ -n "${pedir[$passo]:-}" ] || continue
    feitos+=("$passo")
    _rodar "$passo" >>"$tmp/passos.log" 2>&1
    case $? in 1) mudou=1 ;; 0|3) : ;; *) rc=2 ;; esac
  done
  if [ "${#feitos[@]}" -gt 0 ]; then
    "$RAIZ/scripts/construir_icones.sh" indice >>"$tmp/passos.log" 2>&1
  fi
  _cache "$mudou"
  meow_tela_reler_no_fim >>"$tmp/passos.log" 2>&1

  _registrar "$agora" || { meow_erro "não consegui gravar $TABELA"; rc=2; }
  mkdir -p "$ESTADO" 2>/dev/null
  printf '%s passada · %s desenho(s) · passos: %s\n' "$(date '+%F %T')" \
    "$(grep -c . <<<"$diferencas")" "${feitos[*]:-nenhum}" >>"$REGISTRO" 2>/dev/null
  rm -rf "$tmp"
  [ "$rc" = 2 ] && { meow_erro "derivados: um passo falhou — ver $REGISTRO"; return "$MEOW_ERRO"; }
  meow_ok "derivados refeitos: $(grep -c . <<<"$diferencas") desenho(s), passos ${feitos[*]:-nenhum}"
  return "$MEOW_DIVERGENTE"
}

case "${1:---aplicar}" in
  --aplicar)   if meow_seco; then _passada conferir; else _quieto; _passada aplicar; fi ;;
  --conferir)  _passada conferir ;;
  --registrar) _passada registrar ;;
  --pastas)    _pastas ;;
  *) printf 'uso: derivados.sh [--aplicar|--conferir|--registrar|--pastas]\n' >&2; exit 2 ;;
esac

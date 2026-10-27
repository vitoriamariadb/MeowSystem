#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ACAO="${1:-aplicar}"
APPS="${APPS_ATIVOS:-}"

declare -a APLICADOS=() JA_OK=() PENDENTES=() FALHOS=()

pasta_de() {
  case "$1" in
    bat|btop) echo "btop-bat" ;;
    qt5ct|gtk|qt) echo "toolkits-gtk-qt" ;;
    *) echo "$1" ;;
  esac
}

rodar_modulo() {
  local pasta="$1" acao="$2"
  local mod="$RAIZ/scripts/temas-de-apps/$pasta/manifesto.sh"
  [ -f "$mod" ] || return 4
  (
    # shellcheck disable=SC1090
    . "$mod" || exit 2
    case "$acao" in
      detectar)        meow_app_detectar ;;
      conferir)        meow_app_conferir ;;
      aplicar)         meow_app_aplicar ;;
      reverter)
        if declare -F meow_app_reverter >/dev/null; then
          meow_app_reverter
        else
          meow_pula "o módulo '$pasta' não sabe desfazer"
          exit "$MEOW_SEM_DEPENDENCIA"
        fi ;;
      instalado)
        if declare -F meow_app_instalado >/dev/null; then
          meow_app_instalado
        else
          meow_erro "o módulo '$pasta' não diz se o programa está instalado"
          exit 2
        fi ;;
      motivo)
        meow_app_detectar 2>/dev/null && exit "$MEOW_OK"
        [ -n "$MEOW_APP_MOTIVO" ] && meow_app_pendente "$pasta"
        exit "$MEOW_SEM_DEPENDENCIA" ;;
      *) meow_erro "ação desconhecida para o módulo '$pasta': $acao"; exit 2 ;;
    esac
  )
}

if [ "$ACAO" = "tabela" ]; then
  MEOW_ESTADO="$(mktemp -d -p "${TMPDIR:-/tmp}" .meow-tabela.XXXXXX)" || exit "$MEOW_ERRO"
  export MEOW_ESTADO
  trap 'rm -rf "$MEOW_ESTADO"' EXIT

  vistos=""
  declare -A SLUGS_DE=()
  declare -a ORDEM=()
  IFS=',' read -ra LISTA <<< "$APPS"
  for slug in "${LISTA[@]}"; do
    slug="$(printf '%s' "$slug" | tr -d ' ')"
    [ -n "$slug" ] || continue
    pasta="$(pasta_de "$slug")"
    [ -f "$RAIZ/scripts/temas-de-apps/$pasta/manifesto.sh" ] || continue
    case " $vistos " in
      *" $pasta "*) SLUGS_DE[$pasta]="${SLUGS_DE[$pasta]}, $slug"; continue ;;
    esac
    vistos="$vistos $pasta"
    ORDEM+=("$pasta")
    SLUGS_DE[$pasta]="$slug"
  done
  linhas_de_pulo() {
    sed -n -e 's/\x1b\[[0-9;]*m//g' -e 's/^  --   //p' | tr '\t' ' ' \
      | awk 'NR > 1 { printf " · " } { printf "%s", $0 }'
  }
  for pasta in "${ORDEM[@]}"; do
    rodar_modulo "$pasta" instalado >/dev/null 2>&1; rc_inst=$?
    saida="$(rodar_modulo "$pasta" conferir 2>/dev/null)"; rc_conf=$?
    motivo=""
    if [ "$rc_conf" = "$MEOW_SEM_DEPENDENCIA" ]; then
      motivo="$(printf '%s\n' "$saida" | linhas_de_pulo)"
      [ -n "$motivo" ] || motivo="$(rodar_modulo "$pasta" motivo 2>/dev/null | linhas_de_pulo)"
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$pasta" "${SLUGS_DE[$pasta]}" "$rc_inst" "$rc_conf" "$motivo"
  done
  exit "$MEOW_OK"
fi

vistos=""
IFS=',' read -ra LISTA <<< "$APPS"
for slug in "${LISTA[@]}"; do
  slug="$(printf '%s' "$slug" | tr -d ' ')"
  [ -n "$slug" ] || continue
  pasta="$(pasta_de "$slug")"
  case " $vistos " in *" $pasta "*) continue ;; esac
  vistos="$vistos $pasta"

  rodar_modulo "$pasta" "$ACAO"
  case $? in
    0) JA_OK+=("$pasta") ;;
    1) APLICADOS+=("$pasta") ;;
    3) PENDENTES+=("$pasta") ;;
    4) ;;
    *) FALHOS+=("$pasta") ;;
  esac
done

if [ ${#APLICADOS[@]} -gt 0 ]; then
  case "$ACAO" in
    conferir) meow_muda "divergentes: ${APLICADOS[*]}" ;;
    reverter) if meow_seco; then meow_muda "desfaria: ${APLICADOS[*]}"
              else meow_ok "desfeitos: ${APLICADOS[*]}"; fi ;;
    *)        if meow_seco; then meow_muda "aplicaria: ${APLICADOS[*]}"
              else meow_ok "aplicados: ${APLICADOS[*]}"; fi ;;
  esac
fi
[ ${#JA_OK[@]}     -gt 0 ] && meow_ok   "já estavam certos: ${JA_OK[*]}"
[ ${#PENDENTES[@]} -gt 0 ] && meow_pula "pendentes (app não instalado, ou não dá para agir agora): ${PENDENTES[*]}"
[ ${#FALHOS[@]}    -gt 0 ] && meow_erro "falharam: ${FALHOS[*]}"

[ ${#FALHOS[@]}    -gt 0 ] && exit "$MEOW_ERRO"
[ ${#APLICADOS[@]} -gt 0 ] && exit "$MEOW_DIVERGENTE"
exit "$MEOW_OK"

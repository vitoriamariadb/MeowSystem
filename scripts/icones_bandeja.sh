#!/usr/bin/env bash
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ORIGEM="${MEOW_BANDEJA_ORIGEM:-}"
MAPA="${MEOW_BANDEJA_MAPA:-}"
TEMA="${ICONES_TEMA:-${NOME_TEMA_ICONES:-MeowSystem-Icons}}"
BASE="$HOME/.local/share/icons/$TEMA"

declare -A TRACO=( ["20x20/status"]=4 )

INTOCAVEIS=(
  hefesto-dualsense4unix-symbolic
  com.vitoriamaria.HefestoDualsense4Unix-symbolic
)

intocavel() {
  local n="$1" i
  for i in "${INTOCAVEIS[@]}"; do [ "$n" = "$i" ] && return 0; done
  return 1
}

declare -A MAPA_LIDO=()
declare -A ALIAS_OK=()

_ler_mapa() {
  local linha nome glifo marca
  while IFS= read -r linha || [ -n "$linha" ]; do
    case "$linha" in ''|'#'*) continue ;; esac
    IFS=':' read -r nome glifo marca <<<"$linha"
    [ -n "$nome" ] && [ -n "$glifo" ] || continue
    if intocavel "$nome"; then
      meow_aviso "'$nome' está nos INTOCÁVEIS: é desenho autoral — a linha do mapa foi ignorada"
      continue
    fi
    MAPA_LIDO["$nome"]="$glifo"
    if [ "${marca:-}" = "alias" ]; then ALIAS_OK["$glifo"]=1; fi
  done < "$MAPA"
  return 0
}

_conferir_gemeos() {
  local nome glifo erro=0
  declare -A visto=()
  for nome in "${!MAPA_LIDO[@]}"; do
    glifo="${MAPA_LIDO[$nome]}"
    if [ -n "${visto[$glifo]:-}" ] && [ -z "${ALIAS_OK[$glifo]:-}" ]; then
      meow_erro "dois ícones da bandeja receberiam o mesmo desenho '$glifo': '$nome' e '${visto[$glifo]}'"
      meow_erro "  decida: troque um dos dois, ou marque a repetição com ':alias' no mapa"
      erro=1
    fi
    visto["$glifo"]="$nome"
  done
  [ "$erro" = 0 ] || return "$MEOW_ERRO"
  return "$MEOW_OK"
}

_restos() {
  local dir arq
  for dir in "${!TRACO[@]}"; do
    [ -d "$BASE/$dir" ] || continue
    for arq in "$BASE/$dir"/*.svg; do
      [ -e "$arq" ] || continue
      intocavel "$(basename "$arq" .svg)" || printf '%s\n' "$arq"
    done
  done
  return 0
}

_sem_acervo() {
  local modo="$1" arq n=0
  while IFS= read -r arq; do
    n=$((n + 1))
    [ "$modo" = --conferir ] && continue
    if meow_seco; then
      meow_muda "removeria $arq (o pack no ar não traz ícones de bandeja)"
    else
      meow_destino_permitido "$arq" || return "$MEOW_ERRO"
      rm -f "$arq"
    fi
  done < <(_restos)
  if [ "$n" = 0 ]; then
    meow_pula "o pack no ar não declara icones.bandeja — nada a aplicar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  meow_muda "ícones de bandeja de outro pack: $n a remover"
  return "$MEOW_DIVERGENTE"
}

_pronto() {
  local achado
  if [ -z "$ORIGEM" ] || [ -z "$MAPA" ]; then
    achado="$(meow_icones_de_status bandeja)" || return 1
    IFS=$'\t' read -r ORIGEM MAPA _ <<<"$achado"
  fi
  [ -d "$ORIGEM" ] && [ -f "$MAPA" ] || return 1
  return "$MEOW_OK"
}

_com_traco() {
  local arq="$1" largura="$2"
  if grep -q 'stroke-width' "$arq"; then
    sed -E 's/stroke-width="[^"]*"/stroke-width="'"$largura"'"/g' "$arq"
  else
    sed -E 's/<(circle|rect|line|polyline|polygon|path|ellipse) /<\1 stroke-width="'"$largura"'" /g' "$arq"
  fi
}

_desejado() {
  local nome glifo dir
  for dir in "${!TRACO[@]}"; do
    for nome in "${!MAPA_LIDO[@]}"; do
      glifo="${MAPA_LIDO[$nome]}"
      [ -f "$ORIGEM/$glifo.svg" ] && printf '%s\t%s\t%s\n' "$dir" "$nome" "$glifo"
    done
  done
}

_avisar_faltantes() {
  local nome glifo
  for nome in "${!MAPA_LIDO[@]}"; do
    glifo="${MAPA_LIDO[$nome]}"
    [ -f "$ORIGEM/$glifo.svg" ] && continue
    meow_aviso "o glifo '$glifo' não está em $ORIGEM — '$nome' fica como está"
    meow_info "  baixe com: curl -s https://api.iconify.design/arcticons/$glifo.svg -o $ORIGEM/$glifo.svg"
  done
  return 0
}

_frase_nada_a_fazer() {
  local total="$1"
  if [ "${#MAPA_LIDO[@]}" = 0 ]; then
    printf 'a bandeja não tem alvo hoje (0 linha ativa no mapa) — ver %s' "$MAPA"
  elif [ "$total" = 0 ]; then
    printf '%s linha(s) no mapa e nenhum glifo em %s — nada a aplicar' "${#MAPA_LIDO[@]}" "$ORIGEM"
  else
    printf '%s ícone(s) da bandeja já com o Arcticons' "$total"
  fi
}

_conferir() {
  local dir nome glifo divergentes=0 ausentes=0 orfaos=0 total=0 arq alvo
  while IFS=$'\t' read -r dir nome glifo; do
    total=$((total + 1))
    alvo="$BASE/$dir/$nome.svg"
    if [ ! -f "$alvo" ]; then
      ausentes=$((ausentes + 1))
    elif [ "$(_com_traco "$ORIGEM/$glifo.svg" "${TRACO[$dir]}")" != "$(cat "$alvo")" ]; then
      divergentes=$((divergentes + 1))
    fi
  done < <(_desejado)

  for dir in "${!TRACO[@]}"; do
    [ -d "$BASE/$dir" ] || continue
    for arq in "$BASE/$dir"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      [ -n "${MAPA_LIDO[$nome]:-}" ] || orfaos=$((orfaos + 1))
    done
  done

  if [ "$ausentes" = 0 ] && [ "$divergentes" = 0 ] && [ "$orfaos" = 0 ]; then
    meow_ok "$(_frase_nada_a_fazer "$total")"
    return "$MEOW_OK"
  fi
  meow_muda "ícones da bandeja: $ausentes a instalar, $divergentes a atualizar, $orfaos a remover (de $total)"
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local dir nome glifo arq mudou=0 postos=0 removidos=0 total=0 rc

  while IFS=$'\t' read -r dir nome glifo; do
    total=$((total + 1))
    set +e
    meow_escrever "$BASE/$dir/$nome.svg" "$(_com_traco "$ORIGEM/$glifo.svg" "${TRACO[$dir]}")" 644
    rc=$?
    set -e
    case "$rc" in
      "$MEOW_OK") ;;
      "$MEOW_DIVERGENTE") mudou=1; postos=$((postos + 1)) ;;
      *) meow_erro "não consegui escrever $BASE/$dir/$nome.svg"; return "$MEOW_ERRO" ;;
    esac
  done < <(_desejado)

  for dir in "${!TRACO[@]}"; do
    [ -d "$BASE/$dir" ] || continue
    for arq in "$BASE/$dir"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      if [ -z "${MAPA_LIDO[$nome]:-}" ]; then
        if meow_seco; then
          meow_muda "removeria $arq (saiu do mapa)"
        else
          meow_destino_permitido "$arq" || return "$MEOW_ERRO"
          rm -f "$arq"
        fi
        mudou=1; removidos=$((removidos + 1))
      fi
    done
  done

  if [ "$mudou" = 0 ]; then
    meow_ok "$(_frase_nada_a_fazer "$total")"
    return "$MEOW_OK"
  fi
  meow_info "ícones da bandeja: $postos posto(s), $removidos removido(s)"
  meow_info "o ícone novo aparece quando O APLICATIVO reabrir (o item nasce no start dele)"
  return "$MEOW_DIVERGENTE"
}

main() {
  case "${1:-}" in
    --conferir|''|--aplicar) ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
  _pronto || { _sem_acervo "${1:-}"; return $?; }
  _ler_mapa
  _conferir_gemeos || return $?
  _avisar_faltantes
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"

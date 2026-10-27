#!/usr/bin/env bash
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

CONVERSOR="$RAIZ/scripts/converter_icone.py"
MAPA="$RAIZ/packs/meowsystem/icones/apps-convertidos.map"
DESTINO="$RAIZ/packs/meowsystem/icones/apps"
RETOQUES="$DESTINO"
MAPA_USUARIO="${MEOW_ICONES_CONVERTIDOS:-$(dirname "$MEOW_CONF_ARQUIVO")/icones-convertidos.map}"
DESTINO_USUARIO="${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/convertidos-apps"
RETOQUES_USUARIO="${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/retoques"
declare -A DO_USUARIO=()
declare -A DO_PROJETO=()

declare -A ORIGEM=()
declare -A ARGS=()
declare -A MAO=()
declare -A RETOQUE=()

declare -A CONHECIDO=()

_ler_mapa() {
  local linha nome origem cor extra dono
  while IFS= read -r linha; do
    case "$linha" in '#!meow:usuario') dono=usuario; continue ;; esac
    case "$linha" in ''|'#'*) continue ;; esac
    IFS=':' read -r nome origem cor extra <<<"$linha"
    [ -n "$nome" ] && [ -n "$origem" ] && [ -n "$cor" ] || continue
    case "$origem" in
      mao) MAO["$nome"]=1; origem="" ;;
      /*)  ;;
      *)   origem="$RAIZ/$origem" ;;
    esac
    CONHECIDO["$nome"]=1
    ORIGEM["$nome"]="$origem"
    ARGS["$nome"]="${extra:-}"
    case " ${extra:-} " in
      *" retoque "*) RETOQUE["$nome"]=1
                     ARGS["$nome"]="$(printf '%s' " ${extra:-} " | sed -e 's/ retoque / /g' -e 's/^ *//' -e 's/ *$//')" ;;
    esac
    if [ "${dono:-}" = usuario ]; then
      DO_USUARIO["$nome"]=1
      if [ -n "$origem" ]; then unset 'MAO[$nome]'; fi
    else
      DO_PROJETO["$nome"]=1
    fi
  done < <(cat "$MAPA"; echo; [ -f "$MAPA_USUARIO" ] && { echo '#!meow:usuario'; cat "$MAPA_USUARIO"; echo; })
  return 0
}

_pronto() {
  if [ ! -f "$MAPA" ]; then
    meow_pula "sem packs/meowsystem/icones/apps-convertidos.map — nada a converter"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$CONVERSOR" ]; then
    meow_pula "sem scripts/converter_icone.py — nada a converter"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! meow_tem python3 || ! meow_tem rsvg-convert || ! meow_tem convert; then
    meow_pula "sem python3 / rsvg-convert / ImageMagick — o conversor rasteriza para traçar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! python3 -I -c 'import numpy' 2>/dev/null; then
    meow_pula "sem numpy — é ele que faz o traçado de contorno e o Douglas-Peucker"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

_retoques_de() { if [ -n "${DO_USUARIO[$1]:-}" ]; then printf '%s' "$RETOQUES_USUARIO"; else printf '%s' "$RETOQUES"; fi; }
_destino_de()  { if [ -n "${DO_USUARIO[$1]:-}" ]; then printf '%s' "$DESTINO_USUARIO";  else printf '%s' "$DESTINO";  fi; }

_desejado_de() {
  local nome="$1" saida
  local origem="${ORIGEM[$nome]}" retoques
  retoques="$(_retoques_de "$nome")"
  if [ -f "$retoques/$nome.svg" ] && { [ -n "${DO_USUARIO[$nome]:-}" ] || [ -n "${RETOQUE[$nome]:-}" ] || [ -n "${MAO[$nome]:-}" ]; }; then
    cat "$retoques/$nome.svg"
    return "$MEOW_OK"
  fi
  [ -n "$origem" ] && [ -f "$origem" ] || return "$MEOW_SEM_DEPENDENCIA"
  saida="$(mktemp -t meow-conv.XXXXXX.svg)"
  # shellcheck disable=SC2086
  if ! python3 "$CONVERSOR" "$origem" "$saida" ${ARGS[$nome]} 2>/dev/null; then
    rm -f "$saida"
    return "$MEOW_ERRO"
  fi
  cat "$saida"
  rm -f "$saida"
  return "$MEOW_OK"
}

_avisar_faltantes() {
  local nome
  for nome in "${!CONHECIDO[@]}"; do
    if [ -f "$(_retoques_de "$nome")/$nome.svg" ]; then continue; fi
    if [ -n "${MAO[$nome]:-}" ]; then
      meow_aviso "'$nome' está declarado como 'mao' e não tem retoques/$nome.svg"
      meow_info "  a linha promete um desenho à mão que não existe — desenhe ou tire a linha"
      continue
    fi
    if [ -f "${ORIGEM[$nome]}" ]; then continue; fi
    meow_aviso "a origem de '$nome' não existe: ${ORIGEM[$nome]}"
    meow_info "  o aplicativo continua vindo do Papirus — tire a linha do mapa ou conserte o caminho"
  done
  return 0
}

_conferir() {
  local nome ausentes=0 divergentes=0 orfaos=0 total=0 arq querido rc dest
  local -a n_ausentes=() n_divergentes=() n_orfaos=()
  for nome in "${!CONHECIDO[@]}"; do
    set +e
    querido="$(_desejado_de "$nome")"; rc=$?
    set -e
    [ "$rc" = "$MEOW_OK" ] || continue
    total=$((total + 1))
    dest="$(_destino_de "$nome")"
    if [ ! -f "$dest/$nome.svg" ]; then
      ausentes=$((ausentes + 1)); n_ausentes+=("$nome")
    elif [ "$querido" != "$(cat "$dest/$nome.svg")" ]; then
      divergentes=$((divergentes + 1)); n_divergentes+=("$nome")
    fi
  done

  if [ -d "$DESTINO_USUARIO" ]; then
    for arq in "$DESTINO_USUARIO"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      [ -n "${DO_USUARIO[$nome]:-}" ] || { orfaos=$((orfaos + 1)); n_orfaos+=("$nome"); }
    done
  fi

  if [ "$ausentes" = 0 ] && [ "$divergentes" = 0 ] && [ "$orfaos" = 0 ]; then
    meow_ok "$total ícone(s) convertido(s) em dia"
    return "$MEOW_OK"
  fi
  meow_muda "ícones convertidos: $ausentes a gerar, $divergentes desatualizados, $orfaos a remover (de $total)"
  [ "$ausentes"    -gt 0 ] && meow_info "  a gerar:        ${n_ausentes[*]}"
  [ "$divergentes" -gt 0 ] && meow_info "  desatualizado:  ${n_divergentes[*]}"
  [ "$orfaos"      -gt 0 ] && meow_info "  a remover:      ${n_orfaos[*]}"
  meow_info "  desatualizado = a arte do Papirus mudou. NÃO conserte no automático:"
  meow_info "  gere a folha e confira antes — arte aprovada não se troca em silêncio"
  return "$MEOW_DIVERGENTE"
}

SO_MAO=0

_aplicar() {
  local nome arq mudou=0 postos=0 removidos=0 querido rc dest
  for nome in "${!CONHECIDO[@]}"; do
    [ "$SO_MAO" = "1" ] && [ -z "${MAO[$nome]:-}" ] && continue
    set +e
    querido="$(_desejado_de "$nome")"; rc=$?
    set -e
    case "$rc" in
      "$MEOW_OK") ;;
      "$MEOW_SEM_DEPENDENCIA") continue ;;
      *) meow_erro "o conversor falhou em '$nome' (${ORIGEM[$nome]})"; return "$MEOW_ERRO" ;;
    esac
    dest="$(_destino_de "$nome")"
    [ -d "$dest" ] || meow_seco || mkdir -p "$dest"
    set +e
    meow_escrever "$dest/$nome.svg" "$querido" 644
    rc=$?
    set -e
    case "$rc" in
      "$MEOW_OK") ;;
      "$MEOW_DIVERGENTE") mudou=1; postos=$((postos + 1)) ;;
      *) meow_erro "não consegui escrever $dest/$nome.svg"; return "$MEOW_ERRO" ;;
    esac
  done

  local pasta conhecidos
  for pasta in "$DESTINO_USUARIO"; do
    [ "$SO_MAO" != "1" ] && [ -d "$pasta" ] || continue
    for arq in "$pasta"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      if [ "$pasta" = "$DESTINO" ]; then conhecidos="${DO_PROJETO[$nome]:-}"; else conhecidos="${DO_USUARIO[$nome]:-}"; fi
      if [ -z "$conhecidos" ]; then
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
    if [ "$SO_MAO" = "1" ]; then
      meow_ok "desenhos à mão já construídos"
    else
      meow_ok "ícones convertidos já em dia"
    fi
    return "$MEOW_OK"
  fi
  meow_info "ícones convertidos: $postos gerado(s), $removidos removido(s)"
  meow_info "  eles só chegam na tela depois do icones_apps_arcticons.sh (é ele o dono de 48x48/apps)"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  _ler_mapa
  _avisar_faltantes
  case "${1:-}" in
    --conferir) _conferir ;;
    --so-mao|--só-mão) SO_MAO=1; _aplicar ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--so-mao]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"

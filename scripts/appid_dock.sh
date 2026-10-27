#!/usr/bin/env bash
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

MAPA="$RAIZ/assets/apps/appid.map"
SONDA="$RAIZ/scripts/appid_sonda.py"
APPS="$HOME/.local/share/applications"
MARCA="X-MeowSystem=janela-dock"
PREFIXO="meow-janela-"

declare -A MAPA_LIDO=()
declare -A ALIAS_OK=()
declare -A ALVO_CAMINHO=()
declare -A ALVO_NOME=()
declare -A ALVO_ICONE=()
declare -A ALVO_EXEC=()
declare -A JA_CASA=()
MAPA_ORDEM=()

_arquivo_de() {
  local id="$1"
  printf '%s%s.desktop' "$PREFIXO" "$(printf '%s' "$id" | tr -c 'A-Za-z0-9._-' '-')"
}

_ler_mapa() {
  local linha id alvo marca
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    IFS=':' read -r id alvo marca <<<"$linha"
    [ -n "$id" ] && [ -n "$alvo" ] || continue
    MAPA_LIDO["$id"]="$alvo"
    MAPA_ORDEM+=("$id")
    if [ "${marca:-}" = "alias" ]; then ALIAS_OK["$alvo"]=1; fi
  done < "$MAPA"
  return 0
}

_conferir_mapa() {
  local id alvo arq erro=0
  declare -A visto_alvo=() visto_arq=()
  for id in "${!MAPA_LIDO[@]}"; do
    alvo="${MAPA_LIDO[$id]}"

    case "$id" in
      steam_app_*)
        meow_erro "'$id' é chave do jogos_steam.sh — tire esta linha do mapa"
        erro=1 ;;
    esac

    if [ -n "${visto_alvo[$alvo]:-}" ] && [ -z "${ALIAS_OK[$alvo]:-}" ]; then
      meow_erro "dois app_id apontam para o mesmo alvo '$alvo': '$id' e '${visto_alvo[$alvo]}'"
      meow_erro "  decida: tire o app_id velho, ou marque a repetição com ':alias'"
      erro=1
    fi
    visto_alvo["$alvo"]="$id"

    arq="$(_arquivo_de "$id")"
    if [ -n "${visto_arq[$arq]:-}" ]; then
      meow_erro "'$id' e '${visto_arq[$arq]}' geram o mesmo arquivo '$arq'"
      erro=1
    fi
    visto_arq["$arq"]="$id"
  done
  [ "$erro" = 0 ] || return "$MEOW_ERRO"
  return "$MEOW_OK"
}

_pronto() {
  if [ ! -f "$MAPA" ]; then
    meow_pula "sem assets/apps/appid.map — nenhuma ponte de janela a construir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! meow_tem python3 || [ ! -f "$SONDA" ]; then
    meow_pula "sem python3 ou sem scripts/appid_sonda.py — sem o casador não se escreve ponte"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

_ler_parque() {
  local id caminho nome icone exec flat n=0
  while IFS=$'\t' read -r id caminho nome icone exec flat; do
    [ -n "$id" ] || continue
    [ -z "${ALVO_CAMINHO[$id]:-}" ] || continue
    ALVO_CAMINHO["$id"]="$caminho"
    ALVO_NOME["$id"]="$nome"
    ALVO_ICONE["$id"]="$icone"
    if [ -n "$flat" ]; then
      ALVO_EXEC["$id"]="/usr/bin/flatpak run $flat"
    else
      ALVO_EXEC["$id"]="$(printf '%s' "$exec" \
        | sed -E 's/ --file-forwarding//g; s/ @@u?( |$)/\1/g; s/ %[a-zA-Z]//g; s/[[:space:]]+$//')"
    fi
    n=$((n + 1))
  done < <(python3 "$SONDA" --parque)
  [ "$n" -gt 0 ] || { meow_erro "o casador não leu nenhum .desktop — parque ilegível"; return "$MEOW_ERRO"; }
  return "$MEOW_OK"
}

_ler_casamentos() {
  local id etapa caminho
  [ "${#MAPA_ORDEM[@]}" -gt 0 ] || return 0
  while IFS=$'\t' read -r id etapa caminho; do
    [ "$etapa" = "-" ] && continue
    JA_CASA["$id"]="$etapa"$'\t'"$caminho"
  done < <(printf '%s\n' "${MAPA_ORDEM[@]}" | python3 "$SONDA" --casar --sem-ponte)
  return 0
}

_corpo() {
  local id="$1" alvo="$2"
  printf '%s\n' \
    '[Desktop Entry]' \
    '# Gerado por MeowSystem/scripts/appid_dock.sh a partir de assets/apps/appid.map.' \
    '# Ponte de app_id: existe só para o cosmic-app-list achar esta janela.' \
    '# Não é o .desktop do aplicativo — o de verdade continua intacto, e é ele' \
    '# que abre os arquivos. Edições aqui são desfeitas: mude o mapa.' \
    'Type=Application' \
    "Name=${ALVO_NOME[$alvo]}" \
    "Icon=${ALVO_ICONE[$alvo]}" \
    "Exec=${ALVO_EXEC[$alvo]}" \
    'Terminal=false' \
    'NoDisplay=true' \
    "StartupWMClass=$id" \
    "$MARCA" \
    "X-MeowSystem-AppId=$id" \
    "X-MeowSystem-Alvo=$alvo.desktop"
}

_desejado() {
  local id alvo
  for id in ${MAPA_ORDEM[@]+"${MAPA_ORDEM[@]}"}; do
    alvo="${MAPA_LIDO[$id]}"
    if [ -z "${ALVO_CAMINHO[$alvo]:-}" ]; then
      meow_pula "'$id': o alvo '$alvo.desktop' não está instalado — fica como está" >&2
      continue
    fi
    if [ -n "${JA_CASA[$id]:-}" ]; then
      meow_pula "'$id' JÁ casa por ${JA_CASA[$id]%%$'\t'*} em ${JA_CASA[$id]#*$'\t'} — não sequestro" >&2
      continue
    fi
    if [ -z "${ALVO_NOME[$alvo]:-}" ]; then
      meow_pula "'$id': o alvo '$alvo.desktop' não tem Name= — nada a desenhar na dock" >&2
      continue
    fi
    [ -n "${ALVO_ICONE[$alvo]:-}" ] || \
      meow_aviso "'$id': o alvo '$alvo.desktop' não tem Icon= — a ponte aparece sem ícone"
    printf '%s\t%s\n' "$id" "$alvo"
  done
}

_orfaos() {
  local arq id mantidas="$1"
  [ -d "$APPS" ] || return 0
  for arq in "$APPS/$PREFIXO"*.desktop; do
    [ -e "$arq" ] || continue
    grep -qxF "$MARCA" "$arq" || continue
    id="$(sed -n 's/^X-MeowSystem-AppId=//p' "$arq" | head -n1)"
    printf '%s' "$mantidas" | grep -qxF "$(_arquivo_de "$id")" && continue
    printf '%s\t%s\n' "$arq" "${id:-<sem app_id>}"
  done
  return 0
}

_avisar_novos() {
  local id titulo etapa caminho cand novos=0
  declare -A vivos=() titulos=()

  if ! python3 "$SONDA" --janelas >/dev/null 2>&1; then
    meow_pula "sem sessão Wayland utilizável — não dá para colher app_id agora"
    return 0
  fi
  while IFS=$'\t' read -r id titulo; do
    [ -n "$id" ] || continue
    [ -n "${MAPA_LIDO[$id]:-}" ] && continue
    case "$id" in steam_app_*) continue ;; esac
    vivos["$id"]=1
    titulos["$id"]="$titulo"
  done < <(python3 "$SONDA" --janelas)

  [ "${#vivos[@]}" -gt 0 ] || return 0

  while IFS=$'\t' read -r id etapa caminho; do
    [ "$etapa" = "-" ] || continue
    novos=$((novos + 1))
    if [ "$novos" = 1 ]; then
      meow_aviso "janela(s) aberta(s) cujo app_id não casa com nenhum .desktop:"
    fi
    cand="$(printf '%s\n' "$id" | python3 "$SONDA" --sugerir | cut -f2)"
    meow_aviso "  app_id '$id'   (janela: ${titulos[$id]:-?})"
    if [ -n "$cand" ]; then
      meow_aviso "  se for um destes, cole em assets/apps/appid.map:"
      local c
      for c in ${cand//,/ }; do meow_aviso "      $id:$c"; done
    else
      meow_aviso "  nenhum .desktop parecido — escolha o alvo à mão e cole:"
      meow_aviso "      $id:<desktop-id-sem-.desktop>"
    fi
  done < <(printf '%s\n' "${!vivos[@]}" | python3 "$SONDA" --casar)

  [ "$novos" = 0 ] || meow_aviso "  (nada foi escrito: o mapa é curado à mão, de propósito)"
  return 0
}

_conferir_donos() {
  local arq erro=0
  [ -d "$APPS" ] || return "$MEOW_OK"
  for arq in "$APPS/$PREFIXO"*.desktop; do
    [ -e "$arq" ] || continue
    grep -qxF "$MARCA" "$arq" || continue
    if ! grep -qxF 'NoDisplay=true' "$arq"; then
      meow_erro "a ponte '$arq' perdeu o NoDisplay=true"
      meow_erro "  sem ele o nomes_apps.sh passa a editar este arquivo: dois donos"
      erro=1
    fi
  done
  [ "$erro" = 0 ] || return "$MEOW_ERRO"
  return "$MEOW_OK"
}

_conferir() {
  local id alvo arq ausentes=0 divergentes=0 orfaos=0 total=0 mantidas=""
  _conferir_donos || return $?

  while IFS=$'\t' read -r id alvo; do
    total=$((total + 1))
    arq="$APPS/$(_arquivo_de "$id")"
    mantidas="$mantidas$(_arquivo_de "$id")"$'\n'
    if [ ! -f "$arq" ]; then
      ausentes=$((ausentes + 1))
    elif [ "$(_corpo "$id" "$alvo")" != "$(cat "$arq")" ]; then
      divergentes=$((divergentes + 1))
    fi
  done < <(_desejado)

  while IFS=$'\t' read -r arq id; do
    [ -n "$arq" ] || continue
    meow_muda "removeria a ponte de '$id' ($(basename "$arq")) — saiu do mapa ou o alvo sumiu"
    orfaos=$((orfaos + 1))
  done < <(_orfaos "$mantidas")

  _avisar_novos

  if [ "$ausentes" = 0 ] && [ "$divergentes" = 0 ] && [ "$orfaos" = 0 ]; then
    meow_ok "$total ponte(s) de app_id conformes"
    return "$MEOW_OK"
  fi
  meow_muda "pontes de app_id: $ausentes a criar, $divergentes a atualizar, $orfaos a remover (de $total)"
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local id alvo arq rc mudou=0 postas=0 removidas=0 mantidas=""
  _conferir_donos || return $?

  while IFS=$'\t' read -r id alvo; do
    arq="$APPS/$(_arquivo_de "$id")"
    mantidas="$mantidas$(_arquivo_de "$id")"$'\n'
    set +e
    meow_escrever "$arq" "$(_corpo "$id" "$alvo")" 644
    rc=$?
    set -e
    case "$rc" in
      "$MEOW_OK") ;;
      "$MEOW_DIVERGENTE") mudou=1; postas=$((postas + 1)) ;;
      *) meow_erro "não consegui escrever $arq"; return "$MEOW_ERRO" ;;
    esac
  done < <(_desejado)

  while IFS=$'\t' read -r arq id; do
    [ -n "$arq" ] || continue
    if meow_seco; then
      meow_muda "removeria a ponte de '$id' ($(basename "$arq"))"
    else
      meow_destino_permitido "$arq" || return "$MEOW_ERRO"
      meow_guardar_antes "$arq"
      rm -f "$arq"
      meow_info "ponte de '$id' removida (saiu do mapa ou o alvo sumiu)"
    fi
    mudou=1; removidas=$((removidas + 1))
  done < <(_orfaos "$mantidas")

  _avisar_novos

  if [ "$mudou" = 0 ]; then
    meow_ok "pontes de app_id já conformes"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "pontes de app_id: $postas a escrever, $removidas a remover"
    return "$MEOW_DIVERGENTE"
  fi
  meow_info "pontes de app_id: $postas escrita(s), $removidas removida(s)"
  meow_info "vale na próxima janela que o app abrir — o applist re-varre o disco quando o casamento falha"
  return "$MEOW_DIVERGENTE"
}

_reverter() {
  local arq n=0
  [ -d "$APPS" ] || { meow_ok "nada a reverter"; return "$MEOW_OK"; }
  for arq in "$APPS/$PREFIXO"*.desktop; do
    [ -e "$arq" ] || continue
    grep -qxF "$MARCA" "$arq" || { meow_pula "$(basename "$arq") não tem a nossa marca — é sua, fica"; continue; }
    if meow_seco; then
      meow_muda "removeria $arq"
    else
      meow_destino_permitido "$arq" || return "$MEOW_ERRO"
      meow_guardar_antes "$arq"
      rm -f "$arq"
    fi
    n=$((n + 1))
  done
  [ "$n" = 0 ] && { meow_ok "nenhuma ponte de app_id no disco"; return "$MEOW_OK"; }
  meow_info "$n ponte(s) removida(s); o dock volta ao estado antigo no próximo login"
  meow_info "(o applist só re-varre o disco quando o casamento FALHA — e agora ele não falha mais)"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  _ler_mapa
  _conferir_mapa || return $?

  case "${1:-}" in
    --reverter) _reverter; return $? ;;
  esac

  _ler_parque || return $?
  _ler_casamentos

  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--reverter]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"

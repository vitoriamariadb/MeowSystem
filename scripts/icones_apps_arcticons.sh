#!/usr/bin/env bash
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ORIGEM="$RAIZ/packs/meowsystem/icones/apps"
ORIGEM_BIBLIOTECA="$RAIZ/packs/meowsystem/icones/biblioteca"
MAPA="$RAIZ/packs/meowsystem/icones/apps-arcticons.map"
MAPA_USUARIO="${MEOW_ICONES_TRACO:-$(dirname "$MEOW_CONF_ARQUIVO")/icones-traco.map}"
ORIGEM_CONV="$RAIZ/packs/meowsystem/icones/apps"
MAPA_CONV="$RAIZ/packs/meowsystem/icones/apps-convertidos.map"
MAPA_CONV_USUARIO="${MEOW_ICONES_CONVERTIDOS:-$(dirname "$MEOW_CONF_ARQUIVO")/icones-convertidos.map}"
ORIGEM_CONV_USUARIO="${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/convertidos-apps"
MAPA_MARCA="$RAIZ/packs/meowsystem/icones/apps-marca.map"
MAPA_PNG="$RAIZ/packs/meowsystem/icones/apps.map"
PALETA="$(meow_paleta)"
TEMA="${ICONES_TEMA:-${NOME_TEMA_ICONES:-MeowSystem-Icons}}"
BASE="$HOME/.local/share/icons/$TEMA"

FLAVOR="$(meow_flavor_vestido)" || {
  meow_erro "aplicativos em traço: sem o flavor não há cor para o traço — nada foi tocado"
  exit "$MEOW_ERRO"
}

declare -A TRACO=( ["48x48/apps"]=1.25 )

INTOCAVEIS_PREFIXO=(steam_icon_)
INTOCAVEIS=(fogstripper hefesto-dualsense4unix com.vitoriamaria.HefestoDualsense4Unix)

intocavel() {
  local n="$1" i
  for i in "${INTOCAVEIS[@]}"; do [ "$n" = "$i" ] && return 0; done
  for i in "${INTOCAVEIS_PREFIXO[@]}"; do case "$n" in "$i"*) return 0 ;; esac; done
  return 1
}

declare -A CURADO=()
_ler_curadoria() {
  local chave ext subdir
  [ -f "$RAIZ/assets/icones/curadoria.map" ] || return 0
  while IFS=$'\t' read -r chave ext subdir; do
    case "$chave" in ''|'#'*) continue ;; esac
    [ -n "$ext" ] && [ -n "$subdir" ] || continue
    CURADO["$chave"]=1
  done < "$RAIZ/assets/icones/curadoria.map"
  return 0
}

declare -A GLIFO=()
declare -A ARTE=()
declare -A ACERVO=()
declare -A DUPLO=()
declare -A COR=()
declare -A ALIAS_OK=()
declare -A HEX=()

COR_POR_CATEGORIA=0

_ler_mapa() {
  local linha nome glifo cor marca
  while IFS= read -r linha; do
    case "$linha" in
      '#!cor-por-categoria') COR_POR_CATEGORIA=1; continue ;;
      ''|'#'*) continue ;;
    esac
    IFS=':' read -r nome glifo cor marca <<<"$linha"
    [ -n "$nome" ] && [ -n "$glifo" ] && [ -n "$cor" ] || continue
    case "$glifo" in */*) case "/$glifo/" in */../*) continue ;; esac ;; esac
    intocavel "$nome" && continue
    if [ -n "${CURADO[$nome]:-}" ]; then
      meow_debug "$nome: arte escolhida na curadoria — o Arcticons sai de cima"
      continue
    fi
    GLIFO["$nome"]="$glifo"
    ARTE["$nome"]="$ORIGEM/$glifo.svg"
    [ -f "${ARTE[$nome]}" ] || [ ! -f "$ORIGEM_BIBLIOTECA/$glifo.svg" ] || ARTE["$nome"]="$ORIGEM_BIBLIOTECA/$glifo.svg"
    case "$glifo" in
      */*) [ -e "$RAIZ/$glifo" ] || glifo="$(python3 "$RAIZ/scripts/pack.py" hoje "$glifo" 2>/dev/null || printf '%s' "$glifo")"
           ARTE["$nome"]="$RAIZ/$glifo" ;;
    esac
    ACERVO["$nome"]="Arcticons"
    COR["$nome"]="$cor"
    if [ "${marca:-}" = "alias" ]; then ALIAS_OK["$glifo"]=1; ALIAS_OK["cor:$cor"]=1; fi
  done < <(cat "$MAPA"; echo; [ -f "$MAPA_USUARIO" ] && cat "$MAPA_USUARIO"; echo)
  return 0
}

_ler_mapa_convertidos() {
  local linha nome origem cor
  [ -f "$MAPA_CONV" ] || return 0
  while IFS= read -r linha; do
    case "$linha" in
      '#!cor-por-categoria') COR_POR_CATEGORIA=1; continue ;;
      ''|'#'*) continue ;;
    esac
    IFS=':' read -r nome origem cor _ <<<"$linha"
    [ -n "$nome" ] && [ -n "$origem" ] && [ -n "$cor" ] || continue
    if [ "$origem" != "mao" ] && intocavel "$nome"; then continue; fi
    if [ -n "${CURADO[$nome]:-}" ]; then
      meow_debug "$nome: arte escolhida na curadoria — o convertido sai de cima"
      continue
    fi
    if [ -n "${ACERVO[$nome]:-}" ]; then
      DUPLO["$nome"]=1
      continue
    fi
    ARTE["$nome"]="$ORIGEM_CONV/$nome.svg"
    ACERVO["$nome"]="convertido"
    COR["$nome"]="$cor"
  done < "$MAPA_CONV"
  [ -f "$MAPA_CONV_USUARIO" ] || return 0
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    IFS=':' read -r nome origem cor _ <<<"$linha"
    [ -n "$nome" ] && [ -n "$origem" ] && [ -n "$cor" ] || continue
    if [ "$origem" != "mao" ] && intocavel "$nome"; then continue; fi
    if [ -n "${CURADO[$nome]:-}" ]; then continue; fi
    unset 'GLIFO[$nome]' 'DUPLO[$nome]'
    ARTE["$nome"]="$ORIGEM_CONV_USUARIO/$nome.svg"
    ACERVO["$nome"]="convertido"
    COR["$nome"]="$cor"
  done < "$MAPA_CONV_USUARIO"
  return 0
}

declare -A CEDIDO=()
_ceder_ao_pack() {
  local nome m
  declare -A do_usuario=()
  for m in "$MAPA_USUARIO" "$MAPA_CONV_USUARIO"; do
    [ -f "$m" ] || continue
    while IFS=':' read -r nome _; do
      case "$nome" in ''|'#'*) continue ;; esac
      do_usuario["$nome"]=1
    done < "$m"
  done
  while IFS=$'\t' read -r nome fonte camada; do
    [ -n "$nome" ] && [ -n "${ARTE[$nome]:-}" ] && [ -z "${do_usuario[$nome]:-}" ] || continue
    case "$fonte" in /*) ;; *) fonte="$RAIZ/$fonte" ;; esac
    [ -f "$fonte" ] || continue
    case "$camada" in
      pack:*)     [ "${ICONES_DRACULA:-sim}" != "nao" ] || continue ;;
      resgatados) [ "${ICONES_RESGATADOS:-sim}" = "sim" ] || continue ;;
    esac
    meow_debug "$nome: o desenho do pack vence o traço, também a 48 px"
    unset 'ARTE[$nome]' 'GLIFO[$nome]' 'ACERVO[$nome]' 'COR[$nome]' 'DUPLO[$nome]'
    CEDIDO["$nome"]=1
  done < <(MEOW_PACK_DIR="$(meow_pack_dir)" python3 "$RAIZ/scripts/pack.py" fontes 2>/dev/null || true)
  return 0
}

COR_MARCA_LIGADA=0
_ler_mapa_marca() {
  local linha nome cor
  [ "${ICONES_COR_MARCA:-nao}" = "sim" ] || return 0
  if [ ! -f "$MAPA_MARCA" ]; then
    meow_aviso "ICONES_COR_MARCA=sim mas packs/meowsystem/icones/apps-marca.map não existe — a cor segue por categoria"
    return 0
  fi
  COR_MARCA_LIGADA=1
  while IFS= read -r linha; do
    case "$linha" in
      '#!cor-por-categoria') COR_POR_CATEGORIA=1; continue ;;
      ''|'#'*) continue ;;
    esac
    IFS=':' read -r nome cor _ <<<"$linha"
    [ -n "$nome" ] && [ -n "$cor" ] || continue
    intocavel "$nome" && continue
    [ -n "${CEDIDO[$nome]:-}" ] && continue
    if [ -z "${COR[$nome]:-}" ]; then
      meow_aviso "apps-marca.map: '$nome' não está em nenhum acervo de traço — linha ignorada"
      continue
    fi
    COR["$nome"]="$cor"
  done < "$MAPA_MARCA"
  return 0
}

_ler_paleta() {
  local nome saida
  for nome in "${COR[@]}"; do
    [ -n "${HEX[$nome]:-}" ] && continue
    saida="$(python3 -I - "$PALETA" "$FLAVOR" "$nome" <<'PY'
import json, sys
paleta, flavor, chave = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(paleta))["flavors"]
if flavor not in d:
    sys.exit(1)
print(d[flavor].get(chave, ""))
PY
)" || { meow_erro "não consegui ler a paleta para o flavor '$FLAVOR'"; return "$MEOW_ERRO"; }
    if [ -z "$saida" ]; then
      meow_erro "a cor '$nome' não existe em $(meow_paleta_nome) (flavor $FLAVOR)"
      return "$MEOW_ERRO"
    fi
    HEX["$nome"]="$saida"
  done
  return "$MEOW_OK"
}

_conferir_gemeos() {
  local nome chave erro=0 linha outro
  declare -A visto_glifo=() visto_cor=()

  for nome in "${!DUPLO[@]}"; do
    meow_erro "'$nome' está nos DOIS mapas de traço (apps-arcticons.map e apps-convertidos.map)"
    meow_erro "  a arte que venceria seria a ordem de leitura, não uma escolha — tire de um dos dois"
    erro=1
  done

  for nome in "${!COR[@]}"; do
    if [ -n "${GLIFO[$nome]:-}" ]; then
      chave="${GLIFO[$nome]}"
      if [ -n "${visto_glifo[$chave]:-}" ] && [ -z "${ALIAS_OK[$chave]:-}" ]; then
        meow_erro "dois aplicativos receberiam o mesmo desenho '$chave': '$nome' e '${visto_glifo[$chave]}'"
        meow_erro "  decida: troque um dos dois, ou marque a repetição com ':alias' no fim da linha"
        erro=1
      fi
      visto_glifo["$chave"]="$nome"
    fi

    chave="${COR[$nome]}"
    if [ "$COR_POR_CATEGORIA" = 1 ]; then
      :
    elif [ -n "${visto_cor[$chave]:-}" ] && [ -z "${ALIAS_OK[cor:$chave]:-}" ]; then
      meow_erro "dois aplicativos receberiam a mesma cor '$chave': '$nome' e '${visto_cor[$chave]}'"
      meow_erro "  decida: troque um dos dois, ou marque a repetição com ':alias' no fim da linha"
      erro=1
    fi
    visto_cor["$chave"]="$nome"
  done

  if [ -f "$MAPA_PNG" ]; then
    while IFS= read -r linha; do
      case "$linha" in ''|'#'*) continue ;; esac
      outro="${linha%%:*}"
      if [ -n "${COR[$outro]:-}" ]; then
        meow_erro "'$outro' está nos DOIS mapas (apps.map e o mapa de traço do acervo ${ACERVO[$outro]})"
        meow_erro "  o .svg venceria o .png sem ninguém ter decidido — tire de um dos dois"
        erro=1
      fi
    done < "$MAPA_PNG"
  fi

  [ "$erro" = 0 ] || return "$MEOW_ERRO"
  return "$MEOW_OK"
}

_pronto() {
  if [ ! -d "$ORIGEM" ]; then
    meow_pula "o acervo Arcticons de aplicativo não está em packs/meowsystem/icones/apps"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$MAPA" ]; then
    meow_pula "sem packs/meowsystem/icones/apps-arcticons.map — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$PALETA" ]; then
    meow_pula "sem $(meow_paleta_nome) — sem fonte de cor, nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! meow_tem python3; then
    meow_pula "sem python3 — é ele que lê a paleta (nenhum hex mora em script)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

_vestido() {
  local arq="$1" largura="$2" hex="$3"
  if grep -q 'stroke-width' "$arq"; then
    sed -E 's/stroke-width="[^"]*"/stroke-width="'"$largura"'"/g' "$arq" \
      | sed "s/currentColor/$hex/g"
  else
    sed -E 's/<(circle|rect|line|polyline|polygon|path|ellipse) /<\1 stroke-width="'"$largura"'" /g' "$arq" \
      | sed "s/currentColor/$hex/g"
  fi
}

_desejado() {
  local nome dir
  for dir in "${!TRACO[@]}"; do
    for nome in "${!ARTE[@]}"; do
      [ -f "${ARTE[$nome]}" ] && printf '%s\t%s\t%s\n' "$dir" "$nome" "${ARTE[$nome]}"
    done
  done
}

_avisar_faltantes() {
  local nome glifo
  for nome in "${!ARTE[@]}"; do
    [ -f "${ARTE[$nome]}" ] && continue
    if [ "${ACERVO[$nome]}" = "convertido" ]; then
      meow_aviso "'$nome' está no apps-convertidos.map mas a arte não está no acervo"
      meow_info "  gere o acervo com: ./scripts/construir_convertidos.sh"
      continue
    fi
    glifo="${GLIFO[$nome]}"
    meow_aviso "o glifo '$glifo' não está em packs/meowsystem/icones/apps — '$nome' fica no Papirus"
    meow_info "  baixe com: curl -s https://api.iconify.design/arcticons/$glifo.svg -o packs/meowsystem/icones/apps/$glifo.svg"
  done
  return 0
}

_conferir() {
  local dir nome arte divergentes=0 ausentes=0 orfaos=0 total=0 arq alvo
  while IFS=$'\t' read -r dir nome arte; do
    total=$((total + 1))
    alvo="$BASE/$dir/$nome.svg"
    if [ ! -f "$alvo" ]; then
      ausentes=$((ausentes + 1))
    elif [ "$(_vestido "$arte" "${TRACO[$dir]}" "${HEX[${COR[$nome]}]}")" != "$(cat "$alvo")" ]; then
      divergentes=$((divergentes + 1))
    fi
  done < <(_desejado)

  for dir in "${!TRACO[@]}"; do
    [ -d "$BASE/$dir" ] || continue
    for arq in "$BASE/$dir"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      [ -n "${ARTE[$nome]:-}" ] || orfaos=$((orfaos + 1))
    done
  done

  if [ "$ausentes" = 0 ] && [ "$divergentes" = 0 ] && [ "$orfaos" = 0 ]; then
    meow_ok "$total aplicativo(s) já vestidos em traço ($FLAVOR)"
    return "$MEOW_OK"
  fi
  meow_muda "aplicativos em traço: $ausentes a instalar, $divergentes a atualizar, $orfaos a remover (de $total)"
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local dir nome arte arq mudou=0 postos=0 removidos=0 rc

  while IFS=$'\t' read -r dir nome arte; do
    set +e
    meow_escrever "$BASE/$dir/$nome.svg" \
      "$(_vestido "$arte" "${TRACO[$dir]}" "${HEX[${COR[$nome]}]}")" 644
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
      if [ -z "${ARTE[$nome]:-}" ]; then
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
    meow_ok "aplicativos já vestidos em traço ($FLAVOR)"
    return "$MEOW_OK"
  fi
  meow_info "aplicativos em traço: $postos posto(s), $removidos removido(s) — $FLAVOR"
  rc=0
  meow_tela_reler || rc=$?
  case $rc in
    0) meow_seco || meow_ok "os ícones novos já estão na dock e no menu" ;;
    3) meow_info "fora da sessão gráfica: os ícones novos aparecem no próximo login" ;;
  esac
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  _ler_curadoria
  _ler_mapa
  _ler_mapa_convertidos
  _ceder_ao_pack
  _ler_mapa_marca
  _conferir_gemeos || return $?
  _ler_paleta || return $?
  if [ "$COR_MARCA_LIGADA" = 1 ]; then
    meow_info "cor por MARCA ligada (ICONES_COR_MARCA=sim) — a cor de categoria está sobreposta"
  fi
  _avisar_faltantes
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"

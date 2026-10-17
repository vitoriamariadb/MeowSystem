#!/usr/bin/env bash
# icones_bandeja.sh — o Arcticons vestindo os ícones da BANDEJA da barra
#                     (o `CosmicAppletStatusArea`).
#
# Isso vale para o ZapZap e para o qBittorrent, que mandam `IconPixmap`, e está
# ERRADO COMO REGRA GERAL. Um item da bandeja publica no D-Bus
# (`org.kde.StatusNotifierItem`) TRÊS coisas que decidem quem desenha:
#
#     IconPixmap      raster embutido na mensagem. Se vier, o tema não entra.
#     IconThemePath   um diretório que o applet põe ANTES do tema. Se vier
#                     preenchido, o arquivo de lá vence o nosso. E ele pode
#                     simplesmente NÃO EXISTIR — ver a remedição abaixo.
#     IconName        o nome. Com `IconPixmap` ausente e `IconThemePath` VAZIO,
#                     quem resolve é o tema de ícones — e aí nós alcançamos.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ORIGEM="${MEOW_BANDEJA_ORIGEM:-$RAIZ/packs/meowsystem/icones/sistema/arcticons}"
MAPA="${MEOW_BANDEJA_MAPA:-$RAIZ/packs/meowsystem/icones/bandeja.map}"
TEMA="${ICONES_TEMA:-${NOME_TEMA_ICONES:-MeowSystem-Icons}}"
BASE="$HOME/.local/share/icons/$TEMA"

# O diretório de destino e a espessura do traço dele.
#
# O `stroke-width` é em unidades do `viewBox`, que no Arcticons é 48 — então 4 é
# 8,33% da caixa, em qualquer tamanho de tela.
declare -A TRACO=( ["20x20/status"]=4 )

# Desenho DELA, autoral: não se toca, venha o que vier no mapa. Mesma disciplina
# das listas do `icones_apps.sh` e do `icones_apps_arcticons.sh` — a guarda mora
# no script, e não na memória de quem escreveu o mapa.
#
#   hefesto-dualsense4unix-symbolic         o aro aberto da logo com o martelo,
#                                           DECISÃO 14 dela
#   com.vitoriamaria.HefestoDualsense4Unix-symbolic
#                                           o mesmo arquivo, com o id de flatpak
#                                           (é o nome que o pacote .deb instala)
INTOCAVEIS=(
  hefesto-dualsense4unix-symbolic
  com.vitoriamaria.HefestoDualsense4Unix-symbolic
)

intocavel() {
  local n="$1" i
  for i in "${INTOCAVEIS[@]}"; do [ "$n" = "$i" ] && return 0; done
  return 1
}

declare -A MAPA_LIDO=()   # IconName do app -> glifo Arcticons
declare -A ALIAS_OK=()    # glifo -> 1, quando a repetição é deliberada

# --- o mapa, lido uma vez ----------------------------------------------------
# Três campos, separados por ':'. Nenhum nome de ícone tem ':', então é seguro.
# O terceiro campo, quando é `alias`, autoriza a repetição de glifo.
_ler_mapa() {
  local linha nome glifo marca
  while IFS= read -r linha; do
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
  # `return 0` NÃO É DECORAÇÃO: um `while` devolve o status do último comando do
  # corpo, e a última linha do mapa não é um alias — o teste devolveria 1 e, com
  # `set -e`, o script morreria aqui, calado e com código 1. Foi exatamente o que
  # aconteceu na primeira execução do `icones_sistema.sh`.
  return 0
}

# --- a asserção que ESTOURA em vez de deixar passar --------------------------
# Dois itens da bandeja com o mesmo desenho é pior aqui que no lançador: eles
# ficam LADO A LADO, sempre, na mesma barra de 20 px de altura. Sem `:alias`, o
# script para (código 2) em vez de deixar dois nascerem gêmeos em silêncio.
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

# --- dependências ------------------------------------------------------------
_pronto() {
  if [ ! -d "$ORIGEM" ]; then
    meow_pula "o acervo Arcticons não está em packs/meowsystem/icones/sistema/arcticons — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$MAPA" ]; then
    meow_pula "sem packs/meowsystem/icones/bandeja.map — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- a transformação ---------------------------------------------------------
# Insere `stroke-width` em cada elemento de desenho. UM atributo por elemento:
# duplicar invalida o XML e o rasterizador recusa o SVG inteiro, calado.
# O `if` não é defensivo à toa: os 37 SVG do acervo de 05/08 NÃO declaram
# `stroke-width`, mas a API do Iconify entrega alguns COM ele — conferido em
# 08/08 nos candidatos baixados. Quem chegar depois pode não ser como os de hoje.
_com_traco() {
  local arq="$1" largura="$2"
  if grep -q 'stroke-width' "$arq"; then
    sed -E 's/stroke-width="[^"]*"/stroke-width="'"$largura"'"/g' "$arq"
  else
    sed -E 's/<(circle|rect|line|polyline|polygon|path|ellipse) /<\1 stroke-width="'"$largura"'" /g' "$arq"
  fi
}

# --- o que deveria estar no disco --------------------------------------------
# "dir<TAB>nome<TAB>glifo", só dos glifos que existem de fato. Um glifo faltando
# é aviso, não erro: aquele ícone continua vindo de onde vinha.
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
    meow_aviso "o glifo '$glifo' não está em packs/meowsystem/icones/sistema/arcticons — '$nome' fica como está"
    meow_info "  baixe com: curl -s https://api.iconify.design/arcticons/$glifo.svg -o packs/meowsystem/icones/sistema/arcticons/$glifo.svg"
  done
  return 0
}

# "NADA A FAZER" TEM TRÊS CAUSAS, E DIZER A ERRADA MANDA PROCURAR NO LUGAR ERRADO
#   mapa sem linha        a decisão está no `packs/meowsystem/icones/bandeja.map`
#   linha sem glifo       o `_avisar_faltantes` já disse qual baixar
#   tudo no lugar         é o caso feliz
_frase_nada_a_fazer() {
  local total="$1"
  if [ "${#MAPA_LIDO[@]}" = 0 ]; then
    printf 'a bandeja não tem alvo hoje (0 linha ativa no mapa) — ver packs/meowsystem/icones/bandeja.map'
  elif [ "$total" = 0 ]; then
    printf '%s linha(s) no mapa e nenhum glifo em packs/meowsystem/icones/sistema/arcticons — nada a vestir' "${#MAPA_LIDO[@]}"
  else
    printf '%s ícone(s) da bandeja já vestidos de Arcticons' "$total"
  fi
}

# O CRITÉRIO DO CONFERIR TEM DE SER O DO ESCRITOR
#   `meow_escrever` grava com `printf '%s'`, que come o `\n` final. Um `cmp` byte
#   a byte acusaria divergência eterna num arquivo perfeito — já custou um
#   `--conferir` gritando 123 divergências num tema correto. Compara-se com
#   `$(...)` porque é assim que se escreve.
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

  # Órfão: estava no mapa ontem, não está hoje. Removível porque o dono é único —
  # `20x20/status` nasce aqui e nenhum outro script do projeto escreve nele (o
  # `icones_sistema.sh` é dono de `22x22/status` e `scalable/status`).
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
  # A espera aqui é OUTRA, e dizer "próximo login" seria mentira: o item da
  # bandeja nasce no start do aplicativo, não no start do COSMIC.
  meow_info "o ícone novo aparece quando O APLICATIVO reabrir (o item nasce no start dele)"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
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

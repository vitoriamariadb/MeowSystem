#!/usr/bin/env bash
# icones_sistema.sh — o Arcticons vestindo os ícones do PRÓPRIO COSMIC.
#
# POR QUE ESTE SCRIPT EXISTE
#   Ela pediu duas vezes: "até os applet e icons do próprio sistema operacional
#   quero mudar. Tipo tudo tudo mesmo", e logo depois "inclusive os icons do
#   sistema". Repetir um pedido é o sinal mais forte que existe neste projeto.
#
# O QUE FOI MEDIDO ANTES DE ESCREVER UMA LINHA (docs/COSMIC-THEMING.md §4g)
#
#   1. A COR DO ARQUIVO É JOGADA FORA. O toolkit não ajusta a cor do symbolic:
#      ele descarta o arquivo inteiro e repinta com UMA cor, preservando só o
#      alpha. Prova: o `cosmic-applet-bluetooth-disabled-symbolic` tem #232323 e
#      #808080 gravados, e sai #FFFFFF puro no painel dela. Dois tons viraram um.
#      Consequência: NÃO pintamos nada aqui. Seria trabalho apagado. O único eixo
#      que sobrevive é o DESENHO.
#
#   2. A ESCOLHA É POR TAMANHO, NÃO PELA ORDEM DE `Directories=`. Medido com
#      strace, plantando o MESMO nome em dois diretórios: com `22x22/status`
#      PRIMEIRO na lista e `48x48/status` depois, o `cosmic-settings` abriu o
#      `48x48`. Repetido contra `scalable/status`, mesmo resultado.
#      É isto que torna possível o que ela escolheu ao ver a folha: traço fino no
#      tamanho grande, traço dobrado a 22px — cada consumidor pega o seu.
#
#   3. O TRAÇO DO PACK SOME A 22 px. O Arcticons desenha num viewBox 48x48 e não
#      declara `stroke-width`; o padrão SVG é 1, que a 22px vira 0,46px de tela.
#      Dobrar resolve, e é um atributo só.
#
# O DIRETÓRIO É NOSSO, E POR ISSO PODEMOS REMOVER ÓRFÃO
#   `22x22/status` e `scalable/status` dentro de `MeowSystem-Icons` nascem aqui:
#   nenhum outro script do projeto escreve neles. Dono único, então tirar uma
#   linha do mapa pode remover o arquivo — sem repetir o defeito dos dois donos.
#
# QUEM DECLARA OS DIRETÓRIOS NÃO É ESTE SCRIPT
#   É o `construir_icones.sh`, e de propósito: ele monta o `index.theme` a partir
#   do que EXISTE no disco. Ter dois donos daquela linha já custou a este projeto
#   um laço eterno de seis rodadas (o comentário está lá). Aqui só se põe arquivo;
#   o índice se ajusta sozinho na passagem seguinte.
#
# NÃO REINICIAMOS O PAINEL
#   Ícone novo aparece no próximo login. Derrubar o `cosmic-panel` para economizar
#   essa espera já deixou ela sem painel e sem dock duas vezes, numa máquina de
#   uma tela só.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta o pack
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ORIGEM="$RAIZ/icons/arcticons"
MAPA="$RAIZ/icons/sistema.map"
TEMA="${ICONES_TEMA:-MeowSystem-Icons}"
BASE="$HOME/.local/share/icons/$TEMA"

# Os dois tamanhos, e a espessura de traço de cada um. Foi a escolha dela ao ver
# a folha: "depende do tamanho" — fino onde o ícone respira, dobrado onde ele
# tem 22px para existir. A chave do array é o diretório; o valor, o stroke-width.
# 4 no pequeno foi escolha dela, olhando a folha: 2 ainda ficava fino demais ao
# lado dos ícones cheios do Papirus que dividem a mesma barra.
declare -A TRACO=( ["22x22/status"]=4 ["scalable/status"]=1 )

declare -A MAPA_LIDO=()   # nome COSMIC -> glifo Arcticons
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
    MAPA_LIDO["$nome"]="$glifo"
    if [ "${marca:-}" = "alias" ]; then ALIAS_OK["$glifo"]=1; fi
  done < "$MAPA"
  # `return 0` NÃO É DECORAÇÃO: um `while` devolve o status do último comando do
  # corpo, e a última linha do mapa não é um alias — o teste devolveria 1 e, com
  # `set -e`, o script morreria aqui, calado e com código 1. Foi exatamente o que
  # aconteceu na primeira execução deste arquivo.
  return 0
}

# --- a asserção que ESTOURA em vez de deixar passar --------------------------
# O SPRINTS.md pede isto por causa de um caso real que já está no disco: com
# `--accent green`, `cosmic-files` e `cosmic-term` nasceram gêmeos em silêncio.
# Aqui o risco é o mesmo, trocando cor por desenho: dois alvos apontando para o
# mesmo glifo sem que ninguém tenha decidido isso.
_conferir_gemeos() {
  local nome glifo erro=0
  declare -A visto=()
  for nome in "${!MAPA_LIDO[@]}"; do
    glifo="${MAPA_LIDO[$nome]}"
    if [ -n "${visto[$glifo]:-}" ] && [ -z "${ALIAS_OK[$glifo]:-}" ]; then
      meow_erro "dois ícones receberiam o mesmo desenho '$glifo': '$nome' e '${visto[$glifo]}'"
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
    meow_pula "o acervo Arcticons não está em icons/arcticons — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$MAPA" ]; then
    meow_pula "sem icons/sistema.map — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- a transformação ---------------------------------------------------------
# Insere `stroke-width` em cada elemento de desenho. UM atributo por elemento:
# duplicar invalida o XML e o rasterizador recusa o SVG inteiro, calado.
# Os SVG do pack são uniformes (medido nos 37: viewBox 0 0 48 48,
# stroke="currentColor", nenhum com stroke-width), por isso o sed basta.
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
# é aviso, não erro: aquele ícone continua vindo do Papirus, como sempre veio.
_desejado() {
  local nome glifo dir
  for dir in "${!TRACO[@]}"; do
    for nome in "${!MAPA_LIDO[@]}"; do
      glifo="${MAPA_LIDO[$nome]}"
      [ -f "$ORIGEM/$glifo.svg" ] && printf '%s\t%s\t%s\n' "$dir" "$nome" "$glifo"
    done
  done
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
    meow_ok "$total ícone(s) do sistema já vestidos de Arcticons"
    return "$MEOW_OK"
  fi
  meow_muda "ícones do sistema: $ausentes a instalar, $divergentes a atualizar, $orfaos a remover (de $total)"
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local dir nome glifo arq mudou=0 postos=0 removidos=0 rc

  while IFS=$'\t' read -r dir nome glifo; do
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

  # Órfão: estava no mapa ontem, não está hoje. Removível porque o dono é único.
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
    meow_ok "ícones do sistema já vestidos de Arcticons"
    return "$MEOW_OK"
  fi
  meow_info "ícones do sistema: $postos posto(s), $removidos removido(s)"
  meow_info "os ícones novos aparecem no próximo login (o painel não relê o tema)"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  _ler_mapa
  _conferir_gemeos || return $?
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"

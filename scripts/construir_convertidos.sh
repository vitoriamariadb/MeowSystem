#!/usr/bin/env bash
# construir_convertidos.sh — GERA o acervo
# `packs/meowsystem/icones/apps/`: os ícones do lançador que nós
# convertemos de CHAPADO para TRAÇO, no dialeto do Arcticons.
#
# Ele NÃO instala nada.
#
# A primeira ideia — "um `icones_apps_convertidos.sh` irmão do
# `icones_apps_arcticons.sh`" — está errada, e o motivo é o mesmo laço eterno
# que o cabeçalho daquele script descreve.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

CONVERSOR="$RAIZ/scripts/converter_icone.py"
MAPA="$RAIZ/packs/meowsystem/icones/apps-convertidos.map"
# P96 (23/10/2026): as três pastas do pack são planas. O convertido e o retoque moram juntos em
# `apps/`; quem diz que um nome é retoque (desenho à mão, que o conversor nunca sobrescreve) é a
# palavra `retoque` no 4º campo do mapa, ou a origem `mao`.
DESTINO="$RAIZ/packs/meowsystem/icones/apps"
RETOQUES="$DESTINO"
MAPA_USUARIO="${MEOW_ICONES_CONVERTIDOS:-$(dirname "$MEOW_CONF_ARQUIVO")/icones-convertidos.map}"
DESTINO_USUARIO="${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/convertidos-apps"
RETOQUES_USUARIO="${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/retoques"
declare -A DO_USUARIO=()
declare -A DO_PROJETO=() # nome -> 1 para toda linha do mapa do projeto (a varredura de órfão)

declare -A ORIGEM=()     # nome do .desktop -> arquivo chapado de origem
declare -A ARGS=()       # nome -> parâmetros extras do conversor (ou vazio)
declare -A MAO=()        # nome -> 1 quando a linha declara `mao` (sem origem)
declare -A RETOQUE=()    # nome -> 1 quando o 4º campo traz a palavra `retoque` (P96)

# Um registro separado, com a pergunta certa, e o modo de falha não volta.
declare -A CONHECIDO=()  # nome -> 1 para toda linha do mapa, com origem ou sem

# --- o mapa, lido uma vez ----------------------------------------------------
# Formato, QUATRO campos separados por ':' —
#
#     nome-de-icone-do-.desktop : origem-chapada : cor [ : parametros ]
#
# O campo `cor` parece morto aqui e não é: ele é do OUTRO leitor deste mesmo
# arquivo.
#
# O caminho da origem pode ser absoluto (o Papirus, um flatpak), relativo ao
# repositório (`assets/icones/autorais/...`), ou a palavra `mao`.
_ler_mapa() {
  local linha nome origem cor extra dono
  while IFS= read -r linha; do
    # O marcador entre as duas fontes (ver o `done` deste laço).
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
      # A linha de quem usa troca a do projeto inteira: um `mao` de lá não
      # sobrevive a uma conversão daqui.
      if [ -n "$origem" ]; then unset 'MAO[$nome]'; fi
    else
      DO_PROJETO["$nome"]=1
    fi
  done < <(cat "$MAPA"; echo; [ -f "$MAPA_USUARIO" ] && { echo '#!meow:usuario'; cat "$MAPA_USUARIO"; echo; })
  # `return 0` NÃO É DECORAÇÃO: um `while` devolve o status do último comando do
  # corpo, e com `set -e` um teste falso na última linha mataria o script calado.
  # Já aconteceu no `icones_apps_arcticons.sh`.
  return 0
}

# --- dependências ------------------------------------------------------------
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

# Onde mora o retoque e o construído de um nome: na casa, quando a linha que
# vale é a de quem usa (P82, item 5); no projeto, no resto.
_retoques_de() { if [ -n "${DO_USUARIO[$1]:-}" ]; then printf '%s' "$RETOQUES_USUARIO"; else printf '%s' "$RETOQUES"; fi; }
_destino_de()  { if [ -n "${DO_USUARIO[$1]:-}" ]; then printf '%s' "$DESTINO_USUARIO";  else printf '%s' "$DESTINO";  fi; }

# --- o conteúdo desejado de UM ícone -----------------------------------------
# Retoque à mão VENCE, sempre, e nem chama o conversor. A origem que sumiu é
# AVISO, não erro: aquele aplicativo continua vindo do Papirus, como sempre.
_desejado_de() {
  # DOIS `local`, e não um: num `local a=X b=$a` o `b` NÃO enxerga o `a` da
  # mesma linha — a atribuição só vale depois que o comando inteiro termina.
  local nome="$1" saida
  local origem="${ORIGEM[$nome]}" retoques
  retoques="$(_retoques_de "$nome")"
  if [ -f "$retoques/$nome.svg" ] && { [ -n "${DO_USUARIO[$nome]:-}" ] || [ -n "${RETOQUE[$nome]:-}" ] || [ -n "${MAO[$nome]:-}" ]; }; then
    cat "$retoques/$nome.svg"
    return "$MEOW_OK"
  fi
  # Sem retoque e sem origem (linha `mao`, ou caminho que sumiu): não há o que
  # gerar. Quem explica é o `_avisar_faltantes`.
  [ -n "$origem" ] && [ -f "$origem" ] || return "$MEOW_SEM_DEPENDENCIA"
  saida="$(mktemp -t meow-conv.XXXXXX.svg)"
  # shellcheck disable=SC2086  # ARGS é lista de parâmetros, o split é o ponto
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
    # `A || B && continue` mataria o script: com as duas falsas a lista devolve
    # 1 e o `set -e` derruba tudo, calado. `if` explícito, então.
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

# O CRITÉRIO DO CONFERIR TEM DE SER O DO ESCRITOR
#   `meow_escrever` grava com `printf '%s'`, que come o `\n` final. Um `cmp`
#   byte a byte acusaria divergência eterna num acervo perfeito — já custou um
#   `--conferir` gritando 123 divergências num tema correto.
_conferir() {
  local nome ausentes=0 divergentes=0 orfaos=0 total=0 arq querido rc dest
  # QUAIS, E NÃO SÓ QUANTOS — 16/09/2026
  #   A linha dizia "0 a gerar, 1 desatualizados, 0 a remover (de 31)" e o
  #   parágrafo seguinte mandava gerar a folha e mostrar a ela ANTES de
  #   reconverter. Só que sem o nome não há o que olhar: a folha sai com os 31 e
  #   quem lê tem de caçar a diferença a olho. Um número que não diz onde é um
  #   número que manda procurar.
  local -a n_ausentes=() n_divergentes=() n_orfaos=()
  for nome in "${!CONHECIDO[@]}"; do
    set +e
    querido="$(_desejado_de "$nome")"; rc=$?
    set -e
    # Origem sumida já virou aviso lá em cima e NÃO entra no total: dizer
    # "4 em dia" quando um dos quatro não existe é um número que mente.
    [ "$rc" = "$MEOW_OK" ] || continue
    total=$((total + 1))
    dest="$(_destino_de "$nome")"
    if [ ! -f "$dest/$nome.svg" ]; then
      ausentes=$((ausentes + 1)); n_ausentes+=("$nome")
    elif [ "$querido" != "$(cat "$dest/$nome.svg")" ]; then
      divergentes=$((divergentes + 1)); n_divergentes+=("$nome")
    fi
  done

  # O órfão é contado por dono (P82): o de quem usa saiu do mapa dela. A `apps/`
  # do pack é plana e guarda também o traço e os autorais, que não são deste
  # mapa: ela não tem órfão a contar, como o `_aplicar` não tem a varrer (P96).
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

# `--so-mao`: SÓ AS LINHAS DESENHADAS À MÃO, E O INSTALADOR CHAMA ASSIM
# ===========================================================================
# O `install.sh` não roda este script inteiro, e a razão está no `bin/meow`:
# "reconverter trocaria arte que você aprovou por arte que ninguém viu". Uma
# origem do Papirus que mudou de versão sairia diferente, e a troca aconteceria
# calada, no meio de uma instalação.
#
# A linha `mao` é o caso em que isso não existe: ali "converter" é literalmente
# `cat retoques/<nome>.svg` (ver o `_desejado_de`). Não há conversor, não há
# origem de terceiro, não há nada a divergir — há um desenho que ELA fez e que
# precisa chegar na tela.
#
# Pedido dela em 08/09/2026, sobre a oficina do painel: *"aproveitar e garantir
# que o nosso install consiga fazer isso"*. Sem esta parte, um retoque que
# chegasse pelo git (outra máquina, um clone novo) ou escrito à mão ficaria no
# repositório sem nunca ser construído — e a rota do painel, que grava os dois
# arquivos de uma vez, seria o ÚNICO caminho que funciona. Um recurso com um
# caminho só é um recurso que quebra quando alguém usa o outro.
#
# A varredura de órfão fica de fora do `--so-mao`, e isso não é esquecimento:
# ela apagaria os 25 convertidos que este modo nem olhou.
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

  # Órfão: estava no mapa ontem, não está hoje. Removível porque o dono é único —
  # `packs/meowsystem/icones/apps/` nasce aqui e nenhum outro script escreve nele.
  # O subdiretório `retoques/` NÃO é varrido: é escrito à mão, e o glob `*.svg`
  # não desce em subdiretório.
  # [P82: por dono — o do projeto contra o mapa do projeto, o de quem usa
  #   contra o dela.]
  local pasta conhecidos
  # A varredura de órfão é só na casa: a `apps/` do pack é plana e guarda também o traço e os
  # autorais, que não são deste mapa (P96).
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

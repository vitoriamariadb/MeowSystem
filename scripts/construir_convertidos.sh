#!/usr/bin/env bash
# construir_convertidos.sh — GERA o acervo `assets/icones/convertidos-apps/`: os ícones
# do lançador que nós convertemos de CHAPADO para TRAÇO, no dialeto do Arcticons.
#
# Ele NÃO instala nada. Quem veste o lançador continua sendo UM script só, o
# `icones_apps_arcticons.sh`, e o porquê disso é a primeira coisa deste arquivo.
#
# ============================================================================
# POR QUE O CONVERSOR **NÃO** PODE VIRAR UM SEGUNDO INSTALADOR
# ============================================================================
#
# A primeira ideia — "um `icones_apps_convertidos.sh` irmão do
# `icones_apps_arcticons.sh`" — está errada, e o motivo é o mesmo laço eterno
# que o cabeçalho daquele script descreve. Vale a pena escrever inteiro porque
# a ideia errada é a natural:
#
#   O `icones_apps_arcticons.sh` é DONO de `48x48/apps` e, na varredura final,
#   REMOVE todo `.svg` de lá cujo nome não esteja no mapa dele. Um segundo
#   script escrevendo `48x48/apps/org.gimp.GIMP.svg` teria esse arquivo apagado
#   na passagem seguinte do irmão — que o veria como órfão —, e o reporia na
#   passagem seguinte. `meow doctor` acusaria os dois como divergentes PARA
#   SEMPRE e `meow fix` alternaria entre os dois estados sem nunca convergir.
#
#   E não adianta escolher outro diretório: `48x48/apps` não é gosto, é o que
#   VENCE. A dock desenha a 48 px (medido em 08/08/2026 na captura dela), o
#   diretório é `Type=Fixed`, e um `64x64/apps` só seria consultado no
#   desempate por proximidade — ou seja, o ícone convertido existiria no disco e
#   nunca apareceria na tela, que é o pior desfecho possível porque parece que
#   funcionou. `scalable/apps` casa qualquer tamanho, mas já tem TRÊS donos
#   (`completar_icones.sh`, `logo.sh`, o bootstrap do `construir_icones.sh`).
#
# ENTÃO A CONVERSÃO NÃO É UMA ETAPA DE INSTALAÇÃO: É UM ACERVO.
#
#   Exatamente como `assets/icones/arcticons-apps/`, que está COMMITADO no repositório e
#   não é baixado no install. Este script gera `assets/icones/convertidos-apps/*.svg`
#   DENTRO do repositório, e quem instala continua sendo um script só.
#
#   Três razões, e nenhuma é preguiça:
#     1. arte que ela aprovou numa folha tem de aparecer no `git diff`. Gerar no
#        install faria o desenho mudar em silêncio quando o Papirus atualizasse.
#     2. converter custa tempo de CPU por ícone (rasteriza a 256², rotula
#        componentes, traça, simplifica) para um resultado que é idêntico 364
#        dias por ano. Pagar isso a cada `./install.sh` é pagar por nada.
#     3. o retoque à mão (a boca do Wilber) precisa de um lugar onde SOBREVIVA à
#        próxima conversão. Um arquivo gerado em tempo de instalação não tem
#        onde guardar uma decisão humana.
#
#   Por isso o `install.sh` NÃO ganhou etapa nenhuma, e isso foi confirmado por
#   ela em 11/08/2026: "Nenhuma etapa nova no install." Este script é ferramenta
#   de MANUTENÇÃO, rodada à mão quando o Papirus for atualizado ou entrar
#   aplicativo novo — como o `curl` do Iconify já é hoje para o Arcticons.
#
# ============================================================================
# O QUE ESTE SCRIPT É DONO, E POR QUE ISSO É SEGURO
# ============================================================================
#
# Dono único de `assets/icones/convertidos-apps/`, um diretório que NASCE aqui e onde
# mais ninguém escreve — a mesma disciplina do `icones_apps_arcticons.sh` com
# `48x48/apps` e do `icones_sistema.sh` com `22x22/status`. Por isso ele pode
# remover órfão: nome que saiu do mapa, arquivo que sai do disco.
#
# A EXCEÇÃO SÃO OS RETOQUES, e ela é explícita: `assets/icones/convertidos-apps/
# retoques/NOME.svg` é escrito À MÃO e NUNCA é sobrescrito nem varrido. Se o
# retoque existe, ele é copiado para o acervo e a conversão automática nem roda.
# Um retoque é decisão humana registrada, e reconverter por cima apagaria a
# decisão em silêncio — o defeito que este projeto persegue.
#
# ============================================================================
# COMO ISTO SE LIGA AO RESTO
# ============================================================================
#
#   `assets/icones/apps-convertidos.map`          o mapa, lido por ESTE script e pelo
#                                         `icones_apps_arcticons.sh`. Campos 1,
#                                         2 e 4 são meus; o campo 3 (a cor) é
#                                         dele. Um mapa só, porque duas listas
#                                         da mesma verdade é o defeito que o
#                                         `_conferir_gemeos` daquele script
#                                         ESTOURA para impedir.
#   `scripts/converter_icone.py`          o conversor. Chamado SEM `--lw`.
#   `assets/icones/convertidos-apps/`             a saída, commitada.
#   `assets/icones/convertidos-apps/retoques/`    a decisão humana, escrita à mão.
#   `bin/meow` -> `chk_convertidos`       confere, e está em SEM_CONSERTO: o
#                                         `--conferir` avisa que a origem do
#                                         Papirus mudou, mas o conserto
#                                         automático trocaria arte que ELA
#                                         aprovou por arte que ninguém viu.
#
# O TRAÇO NÃO MORA AQUI, E ISSO É DE PROPÓSITO
#   Quem manda na espessura é o `TRACO` do `icones_apps_arcticons.sh`, UM número
#   que engrossa os DOIS acervos juntos. Se a conversão gravasse `stroke-width`,
#   ela obedeceria a este arquivo e o Arcticons obedeceria àquele: dois donos da
#   mesma decisão, e a tela ficaria incoerente por esquecimento. Por isso o
#   conversor é chamado SEM `--lw`. O `--lw` existe só para a folha de escolha.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta dependência
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

CONVERSOR="$RAIZ/scripts/converter_icone.py"
MAPA="$RAIZ/assets/icones/apps-convertidos.map"
DESTINO="$RAIZ/assets/icones/convertidos-apps"
RETOQUES="$DESTINO/retoques"

declare -A ORIGEM=()     # nome do .desktop -> arquivo chapado de origem
declare -A ARGS=()       # nome -> parâmetros extras do conversor (ou vazio)
declare -A MAO=()        # nome -> 1 quando a linha declara `mao` (sem origem)

# "ESTE NOME ESTÁ NO MAPA?" NÃO É A MESMA PERGUNTA QUE "ELE TEM ORIGEM?"
#   E confundir as duas custou o Gradia na primeira execução deste script: a
#   varredura de órfão perguntava `[ -z "${ORIGEM[$nome]}" ]`, e a linha `mao`
#   guarda origem VAZIA de propósito — então o arquivo recém-gerado a partir do
#   retoque à mão foi visto como órfão e apagado na mesma passagem. Um registro
#   separado, com a pergunta certa, e o modo de falha não volta.
declare -A CONHECIDO=()  # nome -> 1 para toda linha do mapa, com origem ou sem

# --- o mapa, lido uma vez ----------------------------------------------------
# Formato, QUATRO campos separados por ':' —
#
#     nome-de-icone-do-.desktop : origem-chapada : cor [ : parametros ]
#
# O campo `cor` parece morto aqui e não é: ele é do OUTRO leitor deste mesmo
# arquivo. Ver o cabeçalho do mapa.
#
# O caminho da origem pode ser absoluto (o Papirus, um flatpak), relativo ao
# repositório (`assets/icones/autorais/...`), ou a palavra `mao`.
#
# `mao` NÃO É "sem origem por descuido": é a declaração de que aquele ícone
# NASCE à mão, porque não existe arte chapada honesta de onde partir. Hoje só o
# Gradia: ele dá zero no índice de 14.996 nomes do Arcticons, não está no
# Papirus, e o que o flatpak entrega é um ícone com GRADIENTE cuja fronteira de
# cor vira bolha a 48px. Escrever esse caminho aqui seria registrar como origem
# um arquivo que nunca é lido — e que some se ela desinstalar o aplicativo.
#
# Os `parametros` são a válvula para o caso raro em que um ícone pede `--k 8`;
# vazio é o normal, e hoje TODOS estão vazios.
_ler_mapa() {
  local linha nome origem cor extra
  while IFS= read -r linha; do
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
  done < "$MAPA"
  # `return 0` NÃO É DECORAÇÃO: um `while` devolve o status do último comando do
  # corpo, e com `set -e` um teste falso na última linha mataria o script calado.
  # Já aconteceu no `icones_apps_arcticons.sh`.
  return 0
}

# --- dependências ------------------------------------------------------------
_pronto() {
  if [ ! -f "$MAPA" ]; then
    meow_pula "sem assets/icones/apps-convertidos.map — nada a converter"
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
  if ! python3 -c 'import numpy' 2>/dev/null; then
    meow_pula "sem numpy — é ele que faz o traçado de contorno e o Douglas-Peucker"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- o conteúdo desejado de UM ícone -----------------------------------------
# Retoque à mão VENCE, sempre, e nem chama o conversor. A origem que sumiu é
# AVISO, não erro: aquele aplicativo continua vindo do Papirus, como sempre.
_desejado_de() {
  # DOIS `local`, e não um: num `local a=X b=$a` o `b` NÃO enxerga o `a` da
  # mesma linha — a atribuição só vale depois que o comando inteiro termina.
  local nome="$1" saida
  local origem="${ORIGEM[$nome]}"
  if [ -f "$RETOQUES/$nome.svg" ]; then
    cat "$RETOQUES/$nome.svg"
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
    if [ -f "$RETOQUES/$nome.svg" ]; then continue; fi
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
  local nome ausentes=0 divergentes=0 orfaos=0 total=0 arq querido rc
  for nome in "${!CONHECIDO[@]}"; do
    set +e
    querido="$(_desejado_de "$nome")"; rc=$?
    set -e
    # Origem sumida já virou aviso lá em cima e NÃO entra no total: dizer
    # "4 em dia" quando um dos quatro não existe é um número que mente.
    [ "$rc" = "$MEOW_OK" ] || continue
    total=$((total + 1))
    if [ ! -f "$DESTINO/$nome.svg" ]; then
      ausentes=$((ausentes + 1))
    elif [ "$querido" != "$(cat "$DESTINO/$nome.svg")" ]; then
      divergentes=$((divergentes + 1))
    fi
  done

  if [ -d "$DESTINO" ]; then
    for arq in "$DESTINO"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      [ -n "${CONHECIDO[$nome]:-}" ] || orfaos=$((orfaos + 1))
    done
  fi

  if [ "$ausentes" = 0 ] && [ "$divergentes" = 0 ] && [ "$orfaos" = 0 ]; then
    meow_ok "$total ícone(s) convertido(s) em dia"
    return "$MEOW_OK"
  fi
  meow_muda "ícones convertidos: $ausentes a gerar, $divergentes desatualizados, $orfaos a remover (de $total)"
  meow_info "  desatualizado = a arte do Papirus mudou. NÃO conserte no automático:"
  meow_info "  gere a folha e mostre a ela antes — arte aprovada não se troca em silêncio"
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
  local nome arq mudou=0 postos=0 removidos=0 querido rc
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
    set +e
    meow_escrever "$DESTINO/$nome.svg" "$querido" 644
    rc=$?
    set -e
    case "$rc" in
      "$MEOW_OK") ;;
      "$MEOW_DIVERGENTE") mudou=1; postos=$((postos + 1)) ;;
      *) meow_erro "não consegui escrever $DESTINO/$nome.svg"; return "$MEOW_ERRO" ;;
    esac
  done

  # Órfão: estava no mapa ontem, não está hoje. Removível porque o dono é único —
  # `assets/icones/convertidos-apps/` nasce aqui e nenhum outro script escreve nele.
  # O subdiretório `retoques/` NÃO é varrido: é escrito à mão, e o glob `*.svg`
  # não desce em subdiretório.
  if [ "$SO_MAO" != "1" ] && [ -d "$DESTINO" ]; then
    for arq in "$DESTINO"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      if [ -z "${CONHECIDO[$nome]:-}" ]; then
        if meow_seco; then
          meow_muda "removeria $arq (saiu do mapa)"
        else
          meow_destino_permitido "$arq" || return "$MEOW_ERRO"
          rm -f "$arq"
        fi
        mudou=1; removidos=$((removidos + 1))
      fi
    done
  fi

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

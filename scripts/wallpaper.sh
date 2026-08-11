#!/usr/bin/env bash
# wallpaper.sh — o carrossel de papéis de parede, na rotação NATIVA do COSMIC.
#
# POR QUE NATIVA, E NÃO UM TIMER NOSSO
#   Medido em 2026-08-04: com `source: Path(<diretório>)` e `rotation_frequency: 60`,
#   o `cosmic-bg` abriu três arquivos distintos em intervalos de 60,04s. A rotação
#   sempre funcionou — o motivo de não girar nesta máquina é que o `source` aponta
#   para um ARQUIVO ÚNICO. Em teste de controle com um arquivo só, o timer disparava
#   e redesenhava a mesma imagem. Ligar o carrossel é trocar UM campo.
#
#   Um timer `systemd --user` faria o mesmo com um processo a mais, uma unit a mais
#   e um modo de falha a mais. Fica documentado como plano B, não implementado.
#
# AS TRÊS ARMADILHAS MEDIDAS
#   1. A lista de imagens é FOTOGRAFADA quando a configuração é carregada. Um arquivo
#      novo largado no diretório NÃO entra na rotação, apesar de o log dizer
#      "watching source" — passou cinco rotações inteiras sem ser aberto. Por isso
#      `adicionar` reescreve a configuração no fim: é o que força a releitura.
#   2. Escrever na configuração NÃO AVANÇA, REINICIA: revarre o diretório, volta para
#      a PRIMEIRA imagem alfanumérica e zera o timer. Logo não existe "próximo" barato.
#   3. Escrever conteúdo IDÊNTICO é no-op total — nem releitura acontece. Quando se
#      QUER forçar a releitura, é preciso que o conteúdo mude de fato.
#
# NÃO EXISTE GATILHO DE "PRÓXIMO"
#   O `cosmic-bg` não fala D-Bus: não tem nome no barramento, não tem conexão, e o
#   binário não contém nenhuma string de D-Bus (medido). Os fds dele são dois sockets
#   Wayland e um inotify. Então `proximo` só é possível reiniciando a rotação — o que
#   leva de volta à primeira imagem, não à seguinte. Este script não finge o contrário.
#
# AS QUATRO PASTAS
#   ativos/     o que entra na rotação  <- é ela que vira `source`
#   favoritos/  guardadas por escolha dela; entram na rotação por cópia
#   banidos/    saíram por decisão dela. MOVIDAS, nunca apagadas.
#   originais/  a foto antes de qualquer recolorização, para poder refazer
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

BASE="${WALLPAPER_BASE:-$HOME/.local/share/backgrounds/meowsystem}"
ATIVOS="$BASE/ativos"
BG="$HOME/.config/cosmic/com.system76.CosmicBackground/v1"
ORDEM="${WALLPAPER_ORDEM:-aleatoria}"
INTERVALO="${WALLPAPER_INTERVALO:-5m}"

# --- COMO A IMAGEM OCUPA A TELA ----------------------------------------------
# Em 11/08/2026 ela mandou uma captura da tela e disse: "o wallpaper precisa
# preencher a largura e altura". A captura mostrava duas tarjas pretas, uma de
# cada lado — a imagem cabia inteira no meio e sobrava tela.
#
# A causa estava AQUI, e o comentário que existia neste arquivo mentia: dizia
# que `scaling_mode` "é escolha dela e é preservada", mas a `config_desejada`
# gravava `Fit((0.0, 0.0, 0.0))` cravado no texto, toda vez, por cima do que ela
# tivesse escolhido na GUI. Não era preservação nenhuma: era imposição de um
# valor que ninguém tinha decidido.
#
#   preencher -> `Zoom`   a imagem cobre a tela inteira; o que não couber, corta
#   caber     -> `Fit`    a imagem inteira aparece; o que sobrar vira tarja
#   esticar   -> `Stretch` a imagem deforma até caber (nunca é o que se quer)
#
# `Fit` leva uma cor de tarja `(r, g, b)` em floats 0-1. Os outros dois não
# levam nada — e escrever `Zoom(...)` com argumento é erro de sintaxe RON que o
# cosmic-bg engole calado, ficando com a config anterior em memória.
AJUSTE="${WALLPAPER_AJUSTE:-preencher}"

modo_de_ajuste() {
  case "$1" in
    preencher|zoom)   printf 'Zoom' ;;
    esticar|stretch)  printf 'Stretch' ;;
    caber|fit)        printf 'Fit((0.0, 0.0, 0.0))' ;;
    *)
      meow_aviso "WALLPAPER_AJUSTE=\"$1\" não existe; usando preencher"
      printf 'Zoom' ;;
  esac
}

# --- A ALLOWLIST: A ESCOLHA DELA PASSOU A SER DITA, NÃO ADIVINHADA -----------
# Caminhos absolutos separados por `:` (convenção do $PATH), cada um valendo
# para ele mesmo e para tudo abaixo dele. Quem preenche é `permitir <caminho>`,
# e o porquê inteiro está no comentário desta chave no `meow.conf.exemplo` e na
# fronteira, mais abaixo neste arquivo.
#
# LER DO AMBIENTE É O QUE TORNA ISTO REAL NO RELÓGIO DE 15 MINUTOS: o
# `meow-wallpaper.service` sourceia o meow.conf e exporta as chaves de wallpaper
# uma a uma. Uma chave nova que não entre naquela lista de `export` chega aqui
# vazia — e o timer passaria a desfazer, a cada quinze minutos, exatamente a
# escolha que ela acabou de autorizar.
FONTES_DELA="${WALLPAPER_FONTES_DELA:-}"

fonte_autorizada() {
  local fonte="$1" texto="${2-$FONTES_DELA}" p
  [ -n "$fonte" ] && [ -n "$texto" ] || return 1
  # Array, e não `for p in $texto` com IFS=: — a expansão sem aspas também faz
  # *globbing*, e um caminho com `*` ou `[` no nome (a pasta dela tem emoji e
  # espaço; `[` não seria surpresa) viraria outra coisa no meio do caminho,
  # calado.
  local -a lista=()
  IFS=: read -r -a lista <<< "$texto"
  for p in ${lista[@]+"${lista[@]}"}; do
    [ -n "$p" ] || continue
    case "$fonte" in "$p"|"$p"/*) return 0 ;; esac
  done
  return 1
}

# "30s" / "5m" / "2h" -> segundos. O COSMIC quer segundos e nada mais.
segundos_de() {
  local v="$1" n u
  n="${v%[smh]}"; u="${v#$n}"
  case "$n" in ''|*[!0-9]*) echo 300; return ;; esac
  case "$u" in
    s) echo "$n" ;;
    m) echo $((n * 60)) ;;
    h) echo $((n * 3600)) ;;
    *) echo "$n" ;;   # sem sufixo já é segundos
  esac
}

# Só existem dois valores no binário: Alphanumeric e Random. Não há ordenação por
# data nem manual — se a ordem importar, prefixe os arquivos com 01-, 02-.
metodo_de() {
  case "${1:-aleatoria}" in
    alfabetica|alphanumeric) echo Alphanumeric ;;
    *) echo Random ;;
  esac
}

config_desejada() {
  local freq metodo ajuste
  freq="$(segundos_de "$INTERVALO")"
  metodo="$(metodo_de "$ORDEM")"
  ajuste="$(modo_de_ajuste "$AJUSTE")"
  # `filter_by_theme: false` de propósito: com `true` o COSMIC filtra as imagens
  # pelo claro/escuro do tema e pode acabar sem nenhuma candidata no diretório —
  # tela preta sem explicação. O carrossel é dela, não do tema.
  #
  # `filter_method: Lanczos` é o único campo aqui que continua cravado, e é de
  # propósito: é o reamostrador que não serrilha ao reduzir, a mesma lição que a
  # geração dos ícones pagou em 08/08 (512→48 em tempo de desenho).
  cat <<FIM
(
    output: "all",
    source: Path("$ATIVOS"),
    filter_by_theme: false,
    rotation_frequency: $freq,
    filter_method: Lanczos,
    scaling_mode: $ajuste,
    sampling_method: $metodo,
)
FIM
}

criar_pastas() {
  local p
  for p in ativos favoritos banidos originais; do
    [ -d "$BASE/$p" ] && continue
    meow_seco && { meow_muda "criaria $BASE/$p"; continue; }
    mkdir -p "$BASE/$p" || return "$MEOW_ERRO"
  done
  return 0
}

# Semear a partir das imagens que ela JÁ tem. Não baixamos nada da internet sem
# ela pedir: o carrossel tem de funcionar no primeiro `install.sh`, offline.
#
# SÓ NA PRIMEIRA VEZ, e isso não é detalhe. A versão anterior semeava a cada
# `aplicar` — e como `banir` chama `aplicar` no fim (para forçar a releitura da
# lista), banir uma imagem da pasta dela a copiava DE VOLTA no mesmo comando.
# Ela bania, o script dizia "banida", e a imagem continuava lá. Agora a semeadura
# só acontece quando `ativos/` está vazio, ou seja, na primeira instalação:
# depois disso quem manda no conteúdo da pasta é ela.
semear_das_dela() {
  local origem="$HOME/Imagens/Parede_papel"
  [ -d "$origem" ] || return 0
  [ "$(quantas)" -eq 0 ] || return 0
  local n=0
  while IFS= read -r img; do
    local destino="$ATIVOS/$(basename "$img")"
    [ -e "$destino" ] && continue
    meow_seco || cp -n "$img" "$destino" 2>/dev/null || continue
    n=$((n + 1))
  done < <(find "$origem" -maxdepth 1 -type f \
             \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null)
  if [ "$n" -gt 0 ]; then
    if meow_seco; then
      meow_muda "copiaria $n imagem(ns) de ~/Imagens/Parede_papel"
    else
      meow_info "$n imagem(ns) copiadas de ~/Imagens/Parede_papel"
    fi
  fi
  return 0
}

quantas() { find "$ATIVOS" -maxdepth 1 -type f 2>/dev/null | wc -l; }

# --- o estado com caminho fantasma, que suja o journal a cada 5 minutos -------
# `~/.local/state/cosmic/.../v1/wallpapers` é a memória do COSMIC de qual imagem
# estava em cada saída. Não é configuração: é estado, escrito por ele.
#
# O PROBLEMA MEDIDO (2026-08-04, 23:40 em diante)
#   O arquivo guardava três entradas, e DUAS apontavam para arquivo que não existe
#   mais — uma imagem banida da pasta `ativos/` e uma pasta `meowsystem-teste/`
#   apagada há tempo. O `cosmic-greeter` lê este estado e cospe no journal, a cada
#   cinco minutos, para sempre:
#       failed to read wallpaper ".../meowsystem-teste/c-rosa.png": NotFound
#   Não é fatal — mas é a tela de bloqueio dela tentando desenhar um arquivo
#   fantasma, e é ruído que esconde erro de verdade no journal.
#
# SÓ REMOVE O QUE NÃO EXISTE, E NADA MAIS
#   Uma entrada com arquivo presente fica intocada, mesmo apontando para fora da
#   pasta do carrossel: pode ser escolha dela para uma saída específica.
#
# E SÓ VALE NO PRÓXIMO LOGIN — medido, não suposto (2026-08-05)
#   Limpamos a entrada morta, e dois segundos depois ela estava de volta no
#   arquivo. O `cosmic-bg` não relê este estado: ele carrega a lista na MEMÓRIA
#   no início da sessão e reescreve o arquivo INTEIRO a cada troca de imagem —
#   a cada 5 minutos, aqui. Ou seja, enquanto a sessão viver, a entrada fantasma
#   volta; no próximo login ele lê o arquivo já limpo e ela some de vez.
#
#   Por isso o chamador NÃO conta esta limpeza como divergência. Se contasse, o
#   `meow doctor` acusaria diferença a cada rodada para sempre, e o auto-reparo
#   "consertaria" de hora em hora algo que o COSMIC desfaz em cinco minutos —
#   o mesmo ping-pong que o projeto já teve com a Aurora e resolveu cedendo.
ESTADO_BG="$HOME/.local/state/cosmic/com.system76.CosmicBackground/v1/wallpapers"

limpar_estado_morto() {
  [ -f "$ESTADO_BG" ] || return 1

  # SÓ QUANDO NÃO HÁ DONO VIVO — o cabeçalho acima já explica o porquê, e agora
  # o código respeita o que ele diz. Medido em 10/08/2026: `stat` deste arquivo
  # deu 16:33 e depois 16:38:12 — cinco minutos exatos, batendo com o
  # `rotation_frequency: 300` de `output.DP-1`. O `cosmic-bg` reescreve o
  # arquivo INTEIRO nesse ritmo, a partir da lista que carregou na memória.
  # Gravar por cima enquanto ele vive é apostar contra o dono do arquivo: ou a
  # nossa escrita some no próximo tique, ou ela apaga a rotação em curso. E
  # como a limpeza só vale no login seguinte de qualquer jeito, esperar não
  # custa nada — o ganho de escrever agora é zero.
  if pgrep -x cosmic-bg >/dev/null 2>&1; then
    meow_debug "cosmic-bg de pé — a limpeza do estado fica para uma sessão em que ele não esteja"
    return 1
  fi

  local novo mortas saida
  # UMA LEITURA SÓ, E NÃO DUAS. Antes eram duas invocações separadas de
  # `python3` que reabriam o arquivo em momentos diferentes; com o `cosmic-bg`
  # reescrevendo no meio, a contagem da segunda podia discordar do conteúdo que
  # a primeira produziu — e a frase do `meow_info` mentiria sobre o que foi
  # feito. A primeira linha da saída é a contagem, o resto é o conteúdo novo.
  saida="$(python3 - "$ESTADO_BG" <<'FIM' 2>/dev/null
import os, re, sys
texto = open(sys.argv[1], encoding="utf-8").read()
# ("DP-1", Path("/caminho")),  — uma entrada por linha, é o formato que ele grava.
padrao = re.compile(r'^\s*\(\s*"[^"]*"\s*,\s*Path\("([^"]*)"\)\s*\)\s*,?\s*$')
guardar, mortas = [], 0
for linha in texto.splitlines():
    m = padrao.match(linha)
    if m and not os.path.exists(m.group(1)):
        mortas += 1
        continue
    guardar.append(linha)
if not mortas:
    sys.exit(1)          # nada a fazer: o chamador trata como "já limpo"
print(mortas)
print("\n".join(guardar))
FIM
)" || return 1
  mortas="${saida%%$'\n'*}"
  # `$( )` come as newlines do fim: se sobrasse conteúdo NENHUM depois da poda,
  # a saída seria só a contagem, sem newline alguma — e `${saida#*$'\n'}`, que
  # devolve a string intacta quando não acha o padrão, entregaria o número como
  # se fosse o arquivo novo. Não deve acontecer (o arquivo tem os parênteses de
  # abertura e fecho, que não casam com o padrão de entrada), mas o custo de
  # não escrever lixo no estado do COSMIC é uma linha.
  case "$saida" in
    *$'\n'*) novo="${saida#*$'\n'}" ;;
    *)       novo="" ;;
  esac
  if meow_seco; then
    meow_muda "removeria $mortas caminho(s) fantasma do estado do papel de parede"
    return 0
  fi
  meow_escrever "$ESTADO_BG" "$novo" 644
  case $? in
    1) meow_info "$mortas caminho(s) fantasma removidos do estado (o greeter reclamava deles)"
       return 0 ;;
    *) return 1 ;;
  esac
}

cmd_aplicar() {
  criar_pastas || { meow_erro "não consegui criar as pastas"; return "$MEOW_ERRO"; }
  semear_das_dela

  local n; n="$(quantas)"
  if [ "$n" -lt 2 ]; then
    meow_aviso "só $n imagem(ns) em $ATIVOS — o carrossel precisa de 2 ou mais"
    meow_info "adicione com: meow wallpaper adicionar <arquivo|pasta>"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local desejada; desejada="$(config_desejada)"
  local mudou=0

  # `same-on-all` PASSOU A SER NOSSO EM 08/08/2026 — E É ELA QUE DECIDE TUDO
  #   O comentário que estava aqui dizia "`all` é o que vale (same-on-all está
  #   ligado)". Era falso desde 06/08 15:48:02, e o preço apareceu na tela dela:
  #   com `same-on-all: false`, quem manda é o `output.<saída>`, e o `all` — o
  #   arquivo que este script escreve e que o `estado` lia — fica INERTE.
  #
  #   Medido em 08/08, no estado vivo do cosmic-bg: a TV dela girava as imagens
  #   da NASA de `/usr/share/backgrounds` de 5 em 5 minutos, em ordem alfabética,
  #   enquanto o `all` apontava para o acervo dela e o `estado` respondia
  #   "carrossel ATIVO". Duas escritas soltas no `output.DP-1` em 48 h, e o
  #   conserto só passava às 5h — uma delas ficou 38 h no ar.
  #
  #   ESTE SCRIPT NÃO ESCREVE `same-on-all`, E ISSO FOI MEDIDO, NÃO SUPOSTO.
  #   A saída óbvia parecia ser gravar `true` e deixar só o `all` mandar. Foi
  #   tentado em 08/08/2026 e o TESTE REFUTOU: com `same-on-all` valendo `true`
  #   no disco, um `output.DP-1` apontando para `/usr/share/backgrounds` levou a
  #   tela de volta para as imagens da NASA em menos de 20 s. O `cosmic-bg`
  #   continuou obedecendo o arquivo da saída.
  #
  #   Duas leituras sobram, e nenhuma está provada: ou a chave é lida uma vez, no
  #   início da sessão (ele subiu às 00:02 lendo `false`), ou ela não governa
  #   precedência nenhuma. Separar as duas exige medir depois de um login novo —
  #   até lá, escrever a chave seria impor um valor da GUI dela apostando num
  #   efeito que ninguém demonstrou.
  #
  #   O que continua valendo é o de sempre: escrever TODO `output.*` que existe,
  #   porque é neles que o cosmic-bg obedece — provado pelo mesmo teste.
  #
  # A LISTA DE SAÍDAS SAI DO DISCO, NÃO DE UMA LISTA CRAVADA — e isto custou a
  # tela dela ficar PRETA. A versão anterior tratava `DP-1` e `HDMI-A-1` porque
  # eram as duas saídas conhecidas em 04/08/2026. O problema não é a saída que
  # desaparece (essa é ignorada de graça): é a que APARECE. Quando o COSMIC cria
  # um `output.<nome>` novo — monitor novo, TV ligada na outra entrada, nome que
  # mudou de `DP-1` para `DP-2` depois de um reboot — o arquivo não estava na
  # lista, ninguém escrevia nele, e aquela tela caía no papel de parede de
  # fábrica sem nenhum aviso.
  #
  # Agora vale o que existe: `all` sempre, mais TODO `output.*` já presente no
  # diretório, mais toda saída nomeada em `backgrounds` (a lista viva do COSMIC),
  # mesmo que o arquivo dela ainda não exista. É essa última que cobre o monitor
  # recém-chegado.
  local -a alvos=(all)
  local f
  for f in "$BG"/output.*; do
    [ -f "$f" ] || continue
    alvos+=("$(basename "$f")")
  done
  # `backgrounds` é um array RON de nomes de saída, um por linha:
  #     [
  #         "DP-1",
  #     ]
  # O padrão ancora no COMEÇO da linha de propósito. Sem a âncora, o `grep -o`
  # trata a aspa de FECHAMENTO como abertura da próxima ocorrência e devolve a
  # vírgula e o colchete como se fossem nomes de saída — o teste em seco chegou a
  # anunciar que criaria um arquivo chamado `output.,`.
  # Um nome só entra se ainda não estiver na lista: senão a mesma saída seria
  # escrita duas vezes.
  if [ -f "$BG/backgrounds" ]; then
    while IFS= read -r saida; do
      [ -n "$saida" ] || continue
      case " ${alvos[*]} " in *" output.$saida "*) continue ;; esac
      alvos+=("output.$saida")
    done < <(grep -oP '^\s*"\K[^"]+' "$BG/backgrounds" 2>/dev/null)
  fi

  # A FRONTEIRA: QUATRO CASOS, E O QUARTO NASCEU DE UM DEFEITO MEDIDO
  #   Medido em 07/08 e 08/08/2026: algum processo do COSMIC reescreveu o
  #   `output.DP-1` apontando para `/usr/share/backgrounds` — a pasta de fábrica
  #   —, com TODOS os campos no default do construtor (`Zoom`, `Alphanumeric`,
  #   `rotation_frequency: 300`). Quem mexe num controle da GUI não produz isso:
  #   carrega os valores anteriores. É reset programático, não escolha.
  #
  #   Reverter tudo cegamente seria o defeito que o `aplicar_tema.sh` já
  #   documenta ter custado caro (§ "os dois slideres de vidro fosco são dela"):
  #   fotografar uma preferência e passar a impô-la todo dia. Então a regra é a
  #   mesma daquele arquivo, aplicada por saída:
  #
  #     aponta para o nosso acervo        -> confere, nada a fazer
  #     aponta para a pasta de FÁBRICA    -> é o reset; conserta (código 1)
  #     aponta para a WALLPAPER_FONTES_DELA -> é ela; não se toca (código 4)
  #     aponta para QUALQUER outro lugar  -> é reversão; conserta (código 1)
  #
  #   O TERCEIRO CASO ERA "QUALQUER OUTRO LUGAR" ATÉ 11/08/2026, E ISSO CUSTOU O
  #   CARROSSEL INTEIRO. Nesta máquina o `output.DP-1` voltou a apontar para
  #   `~/Imagens/Parede_papel/Cyberpunk Neon Cat…jpeg` — a pasta onde o papel de
  #   parede dela morava ANTES do MeowSystem. Não é `/usr/share/backgrounds`,
  #   então caía no "é ela" e o script se calava: o `meow-wallpaper.timer` rodou
  #   a cada 15 minutos devolvendo `status=4`, e o carrossel nunca voltou. A
  #   frase dela foi "o papel de parede voltou a ser o antigo também. novamente"
  #   — ou seja, ela não tinha escolhido nada.
  #
  #   A fronteira sabia distinguir fábrica de não-fábrica; não sabia distinguir
  #   "escolha dela de agora" de "onde o wallpaper dela estava antes". E não há
  #   como ler essa diferença do disco: o COSMIC grava o MESMO arquivo nos dois
  #   casos, e não existe carimbo de quem escreveu. Então a decisão passou a ser
  #   DITA uma vez, em vez de adivinhada toda vez — é a `WALLPAPER_FONTES_DELA`,
  #   preenchida por `meow wallpaper permitir <caminho>`.
  #
  #   O que este script NÃO faz: adivinhar. Quando conserta, ele diz no log qual
  #   caminho substituiu e imprime o comando exato que o autoriza. Se a reversão
  #   era escolha dela, ela desfaz com uma linha — e o timer nunca mais mexe
  #   naquele caminho.
  local FABRICA="/usr/share/backgrounds"
  local alvo escolha_dela=0 fonte_atual
  for alvo in "${alvos[@]}"; do
    local conteudo="$desejada"
    [ "$alvo" = "all" ] || conteudo="${desejada/output: \"all\"/output: \"${alvo#output.}\"}"

    if [ -f "$BG/$alvo" ]; then
      fonte_atual="$(grep -oP 'source: Path\("\K[^"]+' "$BG/$alvo" 2>/dev/null)"
      case "$fonte_atual" in
        "$ATIVOS"|"$ATIVOS"/*|"") ;;                  # é nosso (ou ilegível): segue
        "$FABRICA"|"$FABRICA"/*) ;;                   # reset de fábrica: conserta
        *)
          if fonte_autorizada "$fonte_atual"; then
            meow_pula "$alvo aponta para $fonte_atual — está na WALLPAPER_FONTES_DELA, não mexo"
            escolha_dela=1
            continue
          fi
          # Reversão. Dizer QUAL caminho saiu é o que impede este conserto de
          # ser mágico: sem o caminho no log, um papel de parede que ela tinha
          # posto de propósito sumiria sem deixar como voltar.
          meow_aviso "$alvo apontava para $fonte_atual — isso não é o carrossel; devolvendo"
          meow_info "era escolha sua? autorize e eu paro de mexer:"
          meow_info "  meow wallpaper permitir \"$fonte_atual\""
          ;;
      esac
    fi

    meow_escrever "$BG/$alvo" "$conteudo" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao escrever $alvo"; return "$MEOW_ERRO" ;; esac
  done

  # A limpeza do estado NÃO conta como divergência — ver o cabeçalho de
  # `limpar_estado_morto`. Contá-la faria o `meow doctor` acusar diferença a cada
  # rodada, para sempre, porque o cosmic-bg reescreve o arquivo a cada troca de
  # imagem (5 min) a partir da lista que ele carregou na MEMÓRIA no início da
  # sessão. É o mesmo ping-pong que o projeto já evitou com a Aurora.
  limpar_estado_morto || true

  if [ "$mudou" = "0" ]; then
    # 4 = divergente POR ESCOLHA DELA. Sai do laço de conserto sem sair do
    # relatório, e o `meow-doctor.service` não notifica — senão ela receberia
    # "o auto-reparo consertou" toda madrugada por uma pasta que ela escolheu.
    if [ "$escolha_dela" = "1" ]; then
      meow_info "o carrossel está no lugar; a saída acima é escolha sua"
      return 4
    fi
    meow_ok "carrossel já configurado ($n imagens, a cada $INTERVALO, $ORDEM)"
    return "$MEOW_OK"
  fi
  meow_seco && return "$MEOW_DIVERGENTE"
  meow_ok "carrossel ligado: $n imagens, troca a cada $INTERVALO ($ORDEM)"
  return "$MEOW_DIVERGENTE"
}

cmd_estado() {
  local n; n="$(quantas)"
  echo "pasta:     $ATIVOS"
  echo "imagens:   $n"
  echo "intervalo: $INTERVALO ($(segundos_de "$INTERVALO")s)"
  echo "ordem:     $ORDEM ($(metodo_de "$ORDEM"))"
  # CONFERE O ARQUIVO QUE MANDA, NÃO O `all` — ignorar isto já fez este comando
  # MENTIR. Em 08/08/2026 ele respondia "carrossel ATIVO" lendo o `all` enquanto
  # a tela dela exibia o papel de parede de fábrica: `same-on-all` era `false`,
  # e quem valia era o `output.DP-1`. O projeto agora é dono da chave e a escreve
  # como `true`, mas o diagnóstico continua perguntando ao disco quem manda —
  # senão volta a mentir no dia em que alguma coisa a mudar de novo.
  local mesma; mesma="$(cat "$BG/same-on-all" 2>/dev/null)"
  local -a mandam=()
  if [ "$mesma" = "false" ]; then
    local f
    for f in "$BG"/output.*; do [ -f "$f" ] && mandam+=("$f"); done
  fi
  [ "${#mandam[@]}" -gt 0 ] || mandam=("$BG/all")

  local fora=0 fonte arq
  for arq in "${mandam[@]}"; do
    [ -f "$arq" ] || continue
    fonte="$(grep -oP 'source: Path\("\K[^"]+' "$arq" 2>/dev/null)"
    [ "$fonte" = "$ATIVOS" ] && continue
    echo "estado:    $(basename "$arq") aponta para outro lugar ($fonte)"
    fora=1
  done
  [ "$fora" = "0" ] && echo "estado:    carrossel ATIVO"
  # A imagem exata que está na tela não é observável: o cosmic-bg não fala D-Bus
  # e não grava o índice em lugar nenhum. Dizer "não sei" é melhor que inventar.
  echo "atual:     (o cosmic-bg não expõe qual imagem está em exibição)"
}

# --- permitir: a única forma de a escolha dela virar regra -------------------
# O VALOR VEM DO ARQUIVO, NÃO DO AMBIENTE, E ISSO NÃO É PREFERÊNCIA
#   O `FONTES_DELA` lá de cima chega pelo ambiente, e chega VAZIO quando alguém
#   roda `./scripts/wallpaper.sh permitir …` na mão, sem passar pela CLI. Se a
#   gravação usasse aquilo como base, o segundo `permitir` apagaria o primeiro —
#   uma autorização anterior dela sumindo em silêncio, que é o pior defeito
#   possível num comando cujo propósito é justamente respeitar a escolha dela.
#   Aqui a lista de partida é lida do meow.conf, pela MESMA regra do wizard
#   (`wiz_linha_da_chave`/`wiz_valor_da_linha` em bin/meow): vale a ÚLTIMA
#   atribuição, que é a que o `.` do shell obedece.
#
# E O VALOR VOLTA CRU, COM O `$HOME` QUE ELA TIVER ESCRITO
#   `WALLPAPER_BASE="$HOME/..."` é o estilo deste arquivo. Gravar a expansão
#   congelaria o caminho; então o que sai daqui é o texto como está, com o novo
#   caminho anexado. A expansão só acontece na hora de comparar.
fontes_no_conf() {
  local linha resto
  [ -f "$MEOW_CONF_ARQUIVO" ] || return 0
  linha="$(grep -E -- '^[[:space:]]*(export[[:space:]]+)?WALLPAPER_FONTES_DELA=' \
             "$MEOW_CONF_ARQUIVO" 2>/dev/null | tail -n1)"
  [ -n "$linha" ] || return 0
  resto="${linha#*=}"
  case "$resto" in
    '"'*) resto="${resto#\"}"; printf '%s' "${resto%%\"*}" ;;
    "'"*) resto="${resto#\'}"; printf '%s' "${resto%%\'*}" ;;
    *)    printf '%s' "${resto%%[[:space:]#]*}" ;;
  esac
}

cmd_permitir() {
  local caminho="${1:-}"
  [ -n "$caminho" ] || {
    meow_erro "uso: wallpaper.sh permitir <caminho>"
    meow_info "o caminho é o que aparece no aviso \"apontava para …\""
    return "$MEOW_ERRO"; }

  # ABSOLUTO E NORMALIZADO: é com o `source: Path(...)` do COSMIC que este valor
  # vai ser comparado, e lá o caminho é SEMPRE absoluto. Gravar `../Imagens`
  # produziria uma entrada que nunca casa com nada — uma autorização que não
  # autoriza, sem nada acusando.
  # `-m` e não `-e`: a pasta pode não existir hoje (um disco desmontado, uma
  # pasta que ela ainda vai criar), e recusar por isso seria recusar a intenção.
  caminho="$(readlink -m -- "$caminho")"

  # O meow.conf é SOURCEADO pelo shell. Um `$` ou uma crase no valor deixariam
  # de ser texto e virariam código no próximo `carregar_conf`; um `#` viraria
  # comentário e comeria o resto da linha; uma aspa dupla fecharia a string. O
  # wizard recusa `#` e `"` pelo mesmo motivo — aqui a lista é maior porque este
  # valor é um caminho, e caminho aceita caractere que resposta de wizard não.
  if [ "${caminho//[\"\$\`\\#]/}" != "$caminho" ]; then
    meow_erro "não gravo caminho com \" \$ \` \\ ou # — o meow.conf é lido pelo shell"
    return "$MEOW_ERRO"
  fi

  # A CONFERÊNCIA VEM ANTES DO AVISO DE "não existe": um caminho já coberto por
  # uma pasta autorizada não precisa existir para nada, e avisar sobre ele seria
  # alarme falso num comando que não vai escrever coisa nenhuma.
  local bruto expandido
  bruto="$(fontes_no_conf)"
  expandido="${bruto//\$\{HOME\}/$HOME}"; expandido="${expandido//\$HOME/$HOME}"
  if fonte_autorizada "$caminho" "$expandido"; then
    meow_ok "$caminho já está autorizado em WALLPAPER_FONTES_DELA"
    return "$MEOW_OK"
  fi

  [ -e "$caminho" ] || meow_aviso "$caminho não existe hoje — autorizando assim mesmo"

  local novo="$caminho"
  [ -n "$bruto" ] && novo="$bruto:$caminho"

  meow_conf_definir WALLPAPER_FONTES_DELA "$novo"
  case $? in
    0) meow_ok "$MEOW_CONF_ARQUIVO já estava assim — nada foi escrito"
       return "$MEOW_OK" ;;
    1) if meow_seco; then
         meow_muda "gravaria WALLPAPER_FONTES_DELA=\"$novo\""
         return "$MEOW_DIVERGENTE"
       fi
       meow_ok "autorizado: $caminho"
       meow_info "o carrossel não mexe mais em saída que aponte para lá"
       meow_registrar "wallpaper permitir: $caminho"
       return "$MEOW_DIVERGENTE" ;;
    *) meow_erro "não consegui gravar $MEOW_CONF_ARQUIVO"
       return "$MEOW_ERRO" ;;
  esac
}

# Mover, nunca apagar: uma imagem banida pode ser recuperada de banidos/.
cmd_banir() {
  local img="$1"
  [ -f "$img" ] || { meow_erro "não achei $img"; return "$MEOW_ERRO"; }
  criar_pastas
  local nome; nome="$(basename "$img")"
  # `mv -n` recusa sobrescrever — e uma imagem JÁ banida antes deixaria o arquivo
  # parado em ativos/, com o script dizendo "banida". Se a cópia em banidos/ já
  # existe e é idêntica, o banimento anterior valeu: basta tirar daqui.
  if [ -e "$BASE/banidos/$nome" ] && cmp -s "$img" "$BASE/banidos/$nome"; then
    rm -f "$img"
  else
    mv -f "$img" "$BASE/banidos/" || return "$MEOW_ERRO"
  fi
  meow_ok "banida: $nome — está em banidos/, não foi apagada"
  cmd_aplicar >/dev/null   # força a releitura da lista
  return "$MEOW_DIVERGENTE"
}

cmd_adicionar() {
  local alvo="$1"
  criar_pastas
  local n=0
  if [ -d "$alvo" ]; then
    while IFS= read -r img; do
      cp -n "$img" "$ATIVOS/" 2>/dev/null && n=$((n + 1))
    done < <(find "$alvo" -maxdepth 1 -type f \
               \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \))
  elif [ -f "$alvo" ]; then
    cp -n "$alvo" "$ATIVOS/" && n=1
  else
    meow_erro "não achei $alvo"; return "$MEOW_ERRO"
  fi
  meow_ok "$n imagem(ns) adicionada(s)"
  # Sem reescrever a configuração, a imagem nova NÃO entra na rotação: a lista foi
  # fotografada no carregamento. Este passo não é enfeite.
  cmd_aplicar >/dev/null
  return "$MEOW_DIVERGENTE"
}

# --- semear: a coleção Catppuccin da comunidade ----------------------------
# POR QUE NÃO CLONAR O REPOSITÓRIO
#   `zhichaoh/catppuccin-wallpapers` tem 371 MB e 242 imagens; o
#   `orangci/walls-catppuccin-mocha` tem 795 MB. Baixar tudo para usar uma dúzia
#   é desperdício de banda e de disco. Aqui se lê a árvore do commit PINADO pela
#   API e se baixam só os arquivos escolhidos, por URL crua.
#
# COMMIT PINADO, NUNCA `main`
#   Um upstream que muda sozinho transforma "rodei o instalador" em "rodei num
#   dia em que o repositório estava de um jeito".
#
# AS IMAGENS NÃO ENTRAM NO GIT
#   O repositório guarda esta receita. As fotos ficam só na máquina.
SEMENTE_REPO="${WALLPAPER_SEMENTE_REPO:-zhichaoh/catppuccin-wallpapers}"
SEMENTE_COMMIT="${WALLPAPER_SEMENTE_COMMIT:-1023077979591cdeca76aae94e0359da1707a60e}"
# 0 = TODAS as imagens do repositorio. Um numero baixa so uma amostra, uma de
# cada categoria por rodizio (util para testar sem gastar banda).
SEMENTE_QUANTAS="${WALLPAPER_SEMENTE_QUANTAS:-0}"

cmd_semear() {
  meow_tem curl || { meow_erro "curl não encontrado"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem python3 || { meow_erro "python3 não encontrado"; return "$MEOW_SEM_DEPENDENCIA"; }
  criar_pastas

  local api="https://api.github.com/repos/$SEMENTE_REPO/git/trees/$SEMENTE_COMMIT?recursive=1"
  local lista; lista="$(curl -sS --max-time 30 "$api" 2>/dev/null)" || {
    meow_aviso "não consegui falar com o GitHub — semeadura pulada"
    return "$MEOW_SEM_DEPENDENCIA"
  }

  # Escolhe espalhando pelas categorias, em vez de pegar as N primeiras (que
  # seriam todas da mesma pasta e pareceriam a mesma imagem repetida).
  local escolhidas
  escolhidas="$(printf '%s' "$lista" | python3 -c "
import json, sys
from urllib.parse import quote
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if 'tree' not in d:
    sys.exit(1)
imgs = [t['path'] for t in d['tree']
        if t.get('type') == 'blob' and t['path'].lower().endswith(('.png', '.jpg', '.jpeg'))]
por_pasta = {}
for p in imgs:
    por_pasta.setdefault(p.split('/')[0], []).append(p)
# rodízio entre as pastas: uma de cada, depois a segunda de cada, e assim por diante
limite = $SEMENTE_QUANTAS or len(imgs)
saida, i = [], 0
while len(saida) < limite:
    houve = False
    for pasta in sorted(por_pasta):
        if i < len(por_pasta[pasta]):
            saida.append(por_pasta[pasta][i]); houve = True
            if len(saida) >= limite: break
    if not houve: break
    i += 1
print('\n'.join(p + '\t' + quote(p, safe='/') for p in saida))
")" || { meow_aviso "resposta do GitHub inesperada — semeadura pulada"; return "$MEOW_SEM_DEPENDENCIA"; }

  # DUAS COLUNAS: a URL vai escapada, o nome de arquivo vai cru.
  #   Sem isso, toda imagem cujo nome tem espaço falhava calada — curl com espaço
  #   na URL devolve 000, e o ramo de erro apagava o temporário sem dizer nada.
  #   Medido em 05/08/2026: três imagens de waves/ ficaram de fora da máquina dela
  #   desde a primeira semeadura, com o script relatando sucesso. 239 de 242.
  #   (E o comentário mora AQUI, não dentro do bloco Python acima: aquilo é uma
  #   string entre aspas duplas do bash, então um crase ali vira substituição de
  #   comando. Foi o que aconteceu na primeira tentativa desta correção.)

  [ -n "$escolhidas" ] || { meow_aviso "nenhuma imagem encontrada"; return "$MEOW_SEM_DEPENDENCIA"; }

  local n=0 falhas=0 base="https://raw.githubusercontent.com/$SEMENTE_REPO/$SEMENTE_COMMIT"
  while IFS=$'\t' read -r caminho caminho_url; do
    [ -n "$caminho" ] || continue
    # Prefixo com a categoria: o nome vira legível e a ordem alfanumérica agrupa.
    local nome="cat-${caminho//\//-}"
    local destino="$ATIVOS/$nome"
    [ -e "$destino" ] && continue
    if meow_seco; then
      meow_muda "baixaria $nome"; n=$((n+1)); continue
    fi
    # Baixa para temporário no MESMO diretório e só então renomeia: uma imagem
    # pela metade entraria na rotação e apareceria cortada na tela dela.
    local tmp; tmp="$(mktemp -p "$ATIVOS" ".meow.XXXXXX")"
    if curl -sSL --max-time 60 -o "$tmp" "$base/$caminho_url" 2>/dev/null && [ -s "$tmp" ]; then
      mv -f "$tmp" "$destino"; n=$((n+1))
    else
      rm -f "$tmp"; falhas=$((falhas + 1))
    fi
  done <<< "$escolhidas"

  # Falha de download não pode continuar sendo invisível: era o que escondia as
  # três imagens de nome com espaço.
  [ "$falhas" -gt 0 ] && meow_aviso "$falhas imagem(ns) não baixaram — rode de novo para tentar outra vez"

  if [ "$n" -eq 0 ]; then
    meow_ok "coleção Catppuccin já semeada"
    return "$MEOW_OK"
  fi
  # No seco NADA foi baixado — dizer "baixadas", no passado, é a mesma mentira
  # que o modo seco já cometeu duas vezes neste projeto (a semeadura das imagens
  # dela e o log do install.sh). O tempo verbal aqui é a diferença entre um
  # relatório e uma promessa.
  if meow_seco; then
    meow_muda "baixaria $n imagem(ns) da coleção Catppuccin (${SEMENTE_REPO}@${SEMENTE_COMMIT:0:8})"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "$n imagem(ns) da coleção Catppuccin baixadas (${SEMENTE_REPO}@${SEMENTE_COMMIT:0:8})"
  meow_seco || cmd_aplicar >/dev/null   # a lista é fotografada no load: precisa reescrever
  return "$MEOW_DIVERGENTE"
}

case "${1:-aplicar}" in
  aplicar)   cmd_aplicar ;;
  # `--conferir` é a letra que TODO script deste projeto usa para auditar, e
  # este era o único que não a tinha: `docs/SPRINTS.md` mandava conferir o
  # carrossel com `./scripts/wallpaper.sh --conferir`, e o que acontecia era o
  # ramo de uso lá embaixo, com código 2 — a documentação apontando para um
  # comando inexistente desde que foi escrita. Aqui ela vira o que sempre
  # significou: o `aplicar` em seco, que não escreve e devolve 1 quando há o que
  # consertar.
  --conferir|conferir) MEOW_SECO=1; cmd_aplicar ;;
  estado)    cmd_estado ;;
  semear)    cmd_semear ;;
  banir)     shift; cmd_banir "${1:-}" ;;
  adicionar) shift; cmd_adicionar "${1:-}" ;;
  permitir)  shift; cmd_permitir "${1:-}" ;;
  *) echo "uso: wallpaper.sh [aplicar|--conferir|estado|semear|adicionar <alvo>|banir <img>|permitir <caminho>]" >&2; exit 2 ;;
esac

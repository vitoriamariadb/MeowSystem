#!/usr/bin/env bash
# lib/icones.sh — A ESCADA DE TAMANHOS DO RASTER, derivada da tela.
#
# ============================================================================
# POR QUE ESTE ARQUIVO EXISTE
# ============================================================================
#   27/08/2026, ela: *"precisamos de uma solução universal idempotente e
#   inteligente no sentido de auto ajustál. tem mt icon quebrados."*
#
#   Auditados os 65 ícones que os `.desktop` visíveis pedem, no tamanho real da
#   dock (41 px de dispositivo):
#
#       42  SVG      -> nítidos em qualquer tamanho; o vetor rasteriza no
#                       tamanho pedido e não tem este problema
#       23  PNG      -> TODOS jogos da Steam
#        0  ausentes
#
#   Dos 23, sete entregam 256 px para um pedido de 41 — redução de 6,2x em
#   tempo de desenho. É literalmente o defeito que o `icones_apps.sh` foi
#   reescrito para curar em 08/08/2026, e a lição nunca chegou ao
#   `jogos_steam.sh`, que planta num tamanho só (`256x256`, linha 130).
#
#   Havia DUAS escadas neste projeto: uma cravada em `icones_apps.sh`
#   (`TAMANHOS_DERIVADOS`, dez degraus) e nenhuma no `jogos_steam.sh`. Duas
#   verdades sobre a mesma pergunta é o defeito que esta casa persegue. Agora há
#   UMA, e ela é calculada.
#
# ============================================================================
# A REGRA, E POR QUE ELA NÃO ADIVINHA O NÚMERO EXATO
# ============================================================================
#   O cabeçalho do `icones_apps.sh` já pagou esse preço e a lição fica:
#
#     "A saída não é adivinhar o número exato (ele muda com a densidade da
#      interface, e há mais consumidores que ninguém enumerou): é a escada ter
#      passo pequeno o suficiente para que QUALQUER pedido caia a poucos pixels
#      de um arquivo real."
#
#   Então isto aqui NÃO tenta prever cada consumidor. Ele faz duas coisas:
#     1. calcula a FAIXA de pedidos que esta tela produz;
#     2. instala todos os degraus CANÔNICOS que caem dentro dela, com folga.
#
#   Os degraus são canônicos de propósito — 16, 22, 24, 32, 48, 64, 72, 96,
#   128, 256, 512 são os nomes de diretório que o freedesktop usa e que o
#   `construir_icones.sh` já sabe declarar. Gerar degraus arbitrários (37, 46,
#   58...) criaria diretórios que nenhum outro tema tem, e a varredura de órfão
#   dos scripts irmãos passaria a ver lixo onde há trabalho.
#
# ============================================================================
# DE ONDE SAI A FAIXA — as duas pontas, e a medição de cada uma
# ============================================================================
#   TETO: o LANÇADOR é o maior consumidor de ícone de aplicativo desta máquina.
#   Medido em 11/08/2026 e registrado no `icones_apps.sh`: o círculo do Spotify
#   tem 76 px de largura na captura, e ele ocupa 100% da caixa do PNG — logo o
#   lançador desenha a 76 px. Aquela medição foi feita com a tela a 100%, então
#   76 é o valor LÓGICO, e o pedido de hoje é 76 x escala.
#
#   PISO: o menor ícone de aplicativo que aparece é o da barra com `size XS`,
#   cujo applet mede 32 unidades no total (lib/painel.sh) — o ícone dentro fica
#   na casa de 16 lógicos.
#
#   A FOLGA existe porque a ponta não é um limite duro: um consumidor que
#   ninguém enumerou pode pedir um pouco além. 25% para cima e 20% para baixo
#   é o suficiente para o degrau vizinho existir, e é o que mantém o pior caso
#   de escala perto de 1,17x — o número que o `icones_apps.sh` mediu como
#   aceitável.
#
# ============================================================================
# IDEMPOTÊNCIA: A ESCALA É ARREDONDADA, E ISSO NÃO É ZELO
# ============================================================================
#   `cosmic-randr list` imprime a escala como percentual inteiro ("114%"). Se
#   este arquivo lesse um float e o multiplicasse, um ruído de 1/1000 mudaria um
#   degrau, os arquivos seriam reescritos, e o `--conferir` acusaria divergência
#   eterna — o laço de ping-pong que o `tests/convergencia.sh` existe para pegar.
#   Aqui a escala entra como INTEIRO em porcentagem e toda a conta é feita em
#   aritmética inteira do shell. Mesma tela, mesma escada, sempre.
#
#   E se a escala não puder ser lida (sem `cosmic-randr`, sessão sem saída,
#   headless), o padrão é 100 — nunca um erro. Uma escada que existe está certa
#   para a maioria dos consumidores; uma etapa que morre não veste ninguém.
#
# ============================================================================
# O QUE ESTE ARQUIVO NÃO FAZ
# ============================================================================
#   · Não decide o tamanho das BARRAS. Isso é do `forma.sh` e do `lib/painel.sh`.
#   · Não toca em SVG. Vetor não precisa de escada: está medido (27/08) que o
#     COSMIC rasteriza o vetor no tamanho pedido, e que `Type=Fixed` contra
#     `Type=Scalable` dá ZERO pixel de diferença na tela. Chamar isto para um
#     acervo vetorial seria trabalho inventado.
#   · Não escreve arquivo nenhum. É biblioteca: calcula e imprime.

# --- a escala da tela, em PORCENTAGEM INTEIRA -------------------------------
# Devolve sempre um inteiro >= 1. Sem cosmic-randr, sem saída ligada ou com
# saída ilegível, devolve 100 e segue — ver o parágrafo da idempotência.
meow_icones_escala_pct() {
  local pct=''
  if command -v cosmic-randr >/dev/null 2>&1; then
    # A COR ANSI PRECISA SAIR ANTES, E ISSO CUSTOU UM BUG (27/08/2026)
    #   `cosmic-randr list` imprime a escala entre sequências de escape, e
    #   ELAS TÊM DÍGITOS: `Scale: ESC[0m114%`. Um padrão como
    #   `[Ss]cale:[^0-9]*\([0-9]\+\)%` casa o `0` de dentro do `ESC[0m` e
    #   devolve lixo — foi o que aconteceu na primeira versão, que leu 100%
    #   numa tela a 114%. O primeiro `sed` tira as sequências; só então lê.
    pct="$(cosmic-randr list 2>/dev/null \
           | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' \
           | sed -n 's/.*[Ss]cale:[[:space:]]*\([0-9][0-9]*\)%.*/\1/p' \
           | head -n1)"
  fi
  case "$pct" in
    ''|*[!0-9]*) printf '100' ;;
    0)           printf '100' ;;
    *)           printf '%s' "$pct" ;;
  esac
}

# --- os degraus canônicos ---------------------------------------------------
# Em ordem. Só estes nomes viram diretório; ver o porquê no cabeçalho.
MEOW_ICONES_CANONICOS="16 22 24 32 48 56 64 72 80 96 128 256 512"

# O lançador desenha a 76 px LÓGICOS (medido 11/08/2026 com a tela a 100%; a
# prova está no cabeçalho do icones_apps.sh). O piso é o ícone de um applet
# `size XS`, na casa de 16 lógicos.
MEOW_ICONES_TETO_LOGICO="${MEOW_ICONES_TETO_LOGICO:-76}"
MEOW_ICONES_PISO_LOGICO="${MEOW_ICONES_PISO_LOGICO:-16}"

# --- a escada -------------------------------------------------------------
# Imprime os degraus, um por linha, do menor para o maior.
#
# Nunca devolve menos de 4 degraus: numa tela muito pequena a faixa poderia
# encolher a ponto de um só arquivo servir tudo, e aí o primeiro consumidor
# fora da conta voltaria a ampliar. Quatro é o piso do que o `icones_apps.sh`
# considerou "passo pequeno o suficiente".
meow_icones_escada() {
  local pct piso teto d saida='' n=0
  pct="$(meow_icones_escala_pct)"

  # Aritmética inteira o tempo todo (ver idempotência).
  #   piso = 16 * pct/100 * 0,80      teto = 76 * pct/100 * 1,25
  piso=$(( MEOW_ICONES_PISO_LOGICO * pct * 80 / 10000 ))
  teto=$(( MEOW_ICONES_TETO_LOGICO * pct * 125 / 10000 ))
  [ "$piso" -lt 1 ] && piso=1

  for d in $MEOW_ICONES_CANONICOS; do
    if [ "$d" -ge "$piso" ] && [ "$d" -le "$teto" ]; then
      saida="$saida$d
"
      n=$((n + 1))
    fi
  done

  # Rede: faixa estreita demais devolveria uma escada que não é escada.
  if [ "$n" -lt 4 ]; then
    printf '24\n32\n48\n64\n96\n'
    return 0
  fi
  printf '%s' "$saida"
}

# --- a escada como uma linha, para mensagem ao usuário ----------------------
meow_icones_escada_dita() {
  meow_icones_escada | tr '\n' ' ' | sed 's/ $//'
}

# --- A CACHE DO HICOLOR, DEPOIS DE PLANTAR ÍCONE — 10/09/2026 ---------------
# MEDIDO no dia em que o primeiro jogo do Heroic ganhou capa: o PNG estava nos
# nove degraus de `~/.local/share/icons/hicolor/*/apps/` e o GTK dizia que ele
# não existe.
#
#     python3 -c "import gi; gi.require_version('Gtk','3.0'); \
#       from gi.repository import Gtk; t=Gtk.IconTheme.new(); \
#       t.set_custom_theme('hicolor'); print(t.has_icon('meow-heroic-…'))"
#     # -> False, com o arquivo no disco
#
# A causa é a `icon-theme.cache` da raiz do hicolor (de 09/09 21:56, enquanto
# `48x48/apps/` era de 10/09 11:44): o GTK confia nela e não varre o disco, e a
# validade é decidida pelo mtime da RAIZ do tema — que nenhum arquivo novo dentro
# de uma subpasta muda. É a mesma doença que o `hicolor.sh` e o
# `completar_icones.sh` já tratam, e ela só não apareceu antes porque quem
# plantava ícone de jogo nunca reindexou.
#
# O COSMIC NÃO SOFRE DISSO, e é por isso que o defeito passou meses invisível: o
# `freedesktop-icons` do painel e da grade varre o disco. Quem some é o ícone nos
# aplicativos GTK — e no PAINEL DELA, que resolve ícone por PyGObject
# (`app/servidor.py`, `scripts/icones_orfaos.py`): o jogo novo entrava na aba de
# ícones como órfão, sem ícone nenhum, dias depois de estar certo na tela.
#
# SÓ REINDEXA SE A CACHE JÁ EXISTIR. Criá-la onde não havia seria escolher, pela
# máquina de alguém, um regime de cache que ela não pediu — e é o oposto do que
# faz falta: sem cache, o GTK varre o disco e enxerga tudo.
meow_hicolor_reindexar() {
  local base="${1:-$HOME/.local/share/icons/hicolor}"
  local cache="$base/icon-theme.cache"
  meow_seco && return 0
  [ -f "$cache" ] || return 0
  meow_tem gtk-update-icon-cache || {
    meow_aviso "$cache está velha e esconde os ícones novos, e não há gtk-update-icon-cache"
    meow_info "  apague o arquivo: rm '$cache'"
    return 1
  }
  gtk-update-icon-cache -q -f "$base" 2>/dev/null || {
    meow_aviso "não consegui reindexar $cache — apague-a se algum ícone não aparecer"
    return 1
  }
  meow_debug "cache do hicolor reindexada"
  return 0
}

# ============================================================================
# DERIVAR: O QUE SAI DE UMA FONTE, E PARA ONDE — P28, 23/09/2026
# ============================================================================
#   A diretriz: "centralizar os SVGs — e alterando lá alteraremos o resto dos
#   ícones que têm eles como base". Para isso valer, a pergunta "o que deriva
#   desta fonte?" precisa de UMA resposta, e ela mora aqui: o instalador
#   escreve o que o `meow_icones_derivados` diz, e o `meow icones fonte` mostra
#   o mesmo plano. Se as duas coisas fossem escritas em dois lugares, a tela
#   poderia prometer um derivado que o instalador nunca faz.
#
#   ESTE BLOCO ESCREVE, e o cabeçalho lá em cima diz "não escreve arquivo
#   nenhum". A frase já não era inteira desde 10/09 (o `meow_hicolor_reindexar`
#   reindexa uma cache); valia para a escada, e continua valendo para ela. O
#   `meow_icones_derivados` só calcula e imprime; quem escreve é o
#   `meow_icones_derivar`, e só pelo `meow_escrever`.
#
# UMA FONTE SVG DERIVA `scalable`, E SÓ ELE — o que a P28 pedia a mais, medido
#   A sprint desenhou quatro famílias de derivado: o vetor em `scalable/apps`,
#   os PNG de 32 a 256, as variantes de flavor e o corte de bandeja. Medido em
#   23/09/2026, só a primeira tem para onde ir:
#
#   · TAMANHOS. O `index.theme` do MeowSystem-Icons declara dois diretórios de
#     aplicativo, `48x48/apps` e `scalable/apps`, e os dois têm ZERO arquivo
#     `.png`. Os PNG de 16 a 256 do Waterfox existem — no `Dracula-Icones`, que
#     é tema de OUTRO projeto, herdado pelo nosso e sombreado por ele: o
#     resolvedor acha o `scalable/apps` daqui antes de subir a herança. Gerar a
#     escada de um vetor seria o "trabalho inventado" que o cabeçalho deste
#     arquivo já nomeou em 27/08 (o COSMIC rasteriza o vetor no tamanho
#     pedido; `Type=Fixed` contra `Type=Scalable` deu zero pixel de
#     diferença). E pôr PNG no `48x48/apps` seria disputar arquivo com o
#     `icones_apps_arcticons.sh`, que é o dono único dele. A escada continua
#     sendo a resposta para fonte RASTER (as capas de jogo) — e fonte raster
#     não é fonte única de pack: ver o `*)` abaixo.
#   · FLAVORS. Recolorir por papel é o `gerar_icones_autorais.py`, e ele já o
#     faz para `icones/autorais/` (a regra 6 já é cumprida lá: foi derivando
#     por papel que o `alucard` ganhou os onze dele na P27). Os desenhos de
#     `icones/apps/` do Dracula declaram `recolorir: false` no pack.json — de
#     6 a 10 cores próprias cada, e recolorir seria destruí-los.
#   · BANDEJA. A bandeja tem mapa e instalador próprios (`bandeja.map`,
#     `icones_bandeja.sh`), veste glifo Arcticons e não arte de pack, e o mapa
#     está vazio de propósito — o `chk_bandeja` do `bin/meow` diz por quê.
#
#   Quando uma dessas famílias ganhar um consumidor de verdade, é aqui que ela
#   entra — uma linha no `case` — e o `meow icones fonte` passa a mostrá-la sem
#   ninguém lembrar de mexer nele.

# meow_icones_derivados <fonte> <nome> [dir-do-tema]
#   O PLANO. Imprime "tipo<TAB>destino", uma linha por derivado. Não escreve.
#   2 = a fonte não é o que uma fonte pode ser.
meow_icones_derivados() {
  local fonte="$1" nome="$2"
  local tema="${3:-$HOME/.local/share/icons/${NOME_TEMA_ICONES:-MeowSystem-Icons}}"
  case "$fonte" in
    *.svg) printf 'scalable\t%s/scalable/apps/%s.svg\n' "$tema" "$nome" ;;
    # RASTER NÃO É FONTE — é derivado. De um PNG não se tira vetor, nem outro
    # flavor, nem um tamanho maior que ele sem borrar: aceitar PNG como fonte
    # única seria aceitar que "alterando lá" não altera o resto.
    *) printf 'fonte não é SVG, e raster não é fonte: %s\n' "$fonte" >&2; return 2 ;;
  esac
}

# meow_icones_derivar <fonte> <nome> [dir-do-tema]
#   Escreve cada derivado do plano. O código é o do `meow_escrever`, somado:
#   0 = já estava tudo igual, 1 = escreveu (ou escreveria, no seco), 2 = erro.
#   Comparar por conteúdo é o cache: fonte que não mudou não reescreve nada, e
#   é por isso que o doctor das 5h pode chamar isto sem virar divergência eterna.
meow_icones_derivar() {
  local fonte="$1" nome="$2" tema="${3:-}" plano tipo destino conteudo rc=0 r
  plano="$(meow_icones_derivados "$fonte" "$nome" ${tema:+"$tema"})" || return 2
  conteudo="$(cat "$fonte" 2>/dev/null)" || { meow_erro "não consegui ler $fonte"; return 2; }
  while IFS=$'\t' read -r tipo destino; do
    [ -n "$destino" ] || continue
    # Um tipo novo no plano sem linha aqui é o defeito que o bloco acima veio
    # evitar — a tela prometendo o que o instalador não faz. Erro, e alto.
    case "$tipo" in
      scalable) meow_escrever "$destino" "$conteudo" 644; r=$? ;;
      *) meow_erro "derivado sem escritor: $tipo"; r=2 ;;
    esac
    case "$r" in
      0) : ;;
      1) [ "$rc" = "0" ] && rc=1 ;;
      *) rc=2 ;;
    esac
  done <<< "$plano"
  return "$rc"
}

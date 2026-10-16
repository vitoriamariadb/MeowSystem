#!/usr/bin/env bash
# lib/icones.sh — A ESCADA DE TAMANHOS DO RASTER, derivada da tela.
#
# Auditados os 65 ícones que os `.desktop` visíveis pedem, no tamanho real da
# dock (41 px de dispositivo):
#
# É literalmente o defeito que o `icones_apps.sh` foi reescrito para curar, e a
# lição nunca chegou ao `jogos_steam.sh`, que planta num tamanho só (`256x256`,
# linha 130).
#
# Havia DUAS escadas neste projeto: uma cravada em `icones_apps.sh`
# (`TAMANHOS_DERIVADOS`, dez degraus) e nenhuma no `jogos_steam.sh`.
#
# O cabeçalho do `icones_apps.sh` já pagou esse preço e a lição fica:

# --- a escala da tela, em PORCENTAGEM INTEIRA -------------------------------
# Devolve sempre um inteiro >= 1. Sem cosmic-randr, sem saída ligada ou com
# saída ilegível, devolve 100 e segue — ver o parágrafo da idempotência.
meow_icones_escala_pct() {
  local pct=''
  if command -v cosmic-randr >/dev/null 2>&1; then
    # `cosmic-randr list` imprime a escala entre sequências de escape, e
    # ELAS TÊM DÍGITOS: `Scale: ESC[0m114%`. O primeiro `sed` tira as
    # sequências; só então lê.
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

# O lançador desenha a 76 px LÓGICOS. O piso é o ícone de um applet `size
# XS`, na casa de 16 lógicos.
MEOW_ICONES_TETO_LOGICO="${MEOW_ICONES_TETO_LOGICO:-76}"
MEOW_ICONES_PISO_LOGICO="${MEOW_ICONES_PISO_LOGICO:-16}"

# --- a escada -------------------------------------------------------------
# Imprime os degraus, um por linha, do menor para o maior.
#
# Nunca devolve menos de 4 degraus: numa tela muito pequena a faixa poderia
# encolher a ponto de um só arquivo servir tudo, e aí o primeiro consumidor
# fora da conta voltaria a ampliar.
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

# --- A CACHE DO HICOLOR, DEPOIS DE PLANTAR ÍCONE ---------------
#
#     python3 -c "import gi; gi.require_version('Gtk','3.0'); \
#       from gi.repository import Gtk; t=Gtk.IconTheme.new(); \
#       t.set_custom_theme('hicolor'); print(t.has_icon('meow-heroic-…'))"
#     # -> False, com o arquivo no disco
#
# O COSMIC NÃO SOFRE DISSO, e é por isso que o defeito passou meses invisível: o
# `freedesktop-icons` do painel e da grade varre o disco.
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

# A diretriz: "centralizar os SVGs — e alterando lá alteraremos o resto dos
# ícones que têm eles como base".
#
# ESTE BLOCO ESCREVE, e o cabeçalho lá em cima diz "não escreve arquivo
# nenhum".
#
# Medido, só a primeira tem para onde ir:

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

# meow_icones_derivar <fonte> <nome> [dir-do-tema] Escreve cada derivado do
# plano.
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

# ============================================================================
# AS BASES DE ÍCONE NÃO APARECEM NOS SELETORES — 15/10/2026, P82 (item 12;
# decisão 20)
# ============================================================================
#   A base que o pack traz (`<tema>-Base`) e as camadas de trás
#   (`<tema>-Base-<n>`) são temas inteiros, com `index.theme`, e por isso
#   apareciam no seletor de tema de ícones do COSMIC como «Dracula Circle» e
#   «Dracula», ao lado do nosso. Elas só existem para o nosso herdar. A chave
#   `Hidden=true` do `[Icon Theme]` é da especificação de tema de ícones do
#   freedesktop, e é exatamente isso: o tema existe, e não se oferece.
#
# meow_tema_base_escondida <pasta-do-tema>
#   Põe `Hidden=true` no `[Icon Theme]` do `index.theme`. Se a pasta tem o
#   manifesto da base (`.meow-somas.sha256`, o do `construir_icones.sh`), a
#   linha do `./index.theme` nele é refeita, para a base continuar conferindo.
#   0 = já estava · 1 = escreveu · 2 = erro
meow_tema_base_escondida() {
  local dir="$1" idx="$1/index.theme" tmp soma
  [ -f "$idx" ] || return "$MEOW_ERRO"
  if awk '/^\[/{sec=$0} sec=="[Icon Theme]" && $0=="Hidden=true"{achou=1} END{exit !achou}' "$idx"; then
    return "$MEOW_OK"
  fi
  tmp="$(mktemp -p "$dir" .meow.XXXXXX)" || return "$MEOW_ERRO"
  awk '/^\[/{sec=$0} sec=="[Icon Theme]" && /^Hidden=/{next}
       {print} $0=="[Icon Theme]" && !feito {print "Hidden=true"; feito=1}' "$idx" > "$tmp" \
    || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod --reference="$idx" "$tmp" 2>/dev/null
  mv -f "$tmp" "$idx" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  if [ -f "$dir/.meow-somas.sha256" ]; then
    soma="$(cd "$dir" && sha256sum ./index.theme)" || return "$MEOW_ERRO"
    tmp="$(mktemp -p "$dir" .meow.XXXXXX)" || return "$MEOW_ERRO"
    awk -v nova="$soma" '$2=="./index.theme"{print nova; next} {print}' "$dir/.meow-somas.sha256" > "$tmp" \
      && mv -f "$tmp" "$dir/.meow-somas.sha256" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  fi
  return "$MEOW_DIVERGENTE"
}

# meow_tema_exportado_heranca <pasta-dos-temas> <nome>
#   A herança do tema que o `exportar_tema.sh` monta para viajar: o nosso herda
#   as camadas da base que estão ao lado dele (na ordem do índice), e depois o
#   `Cosmic` e o `Adwaita`, antes do `hicolor` — são os temas que toda máquina
#   com COSMIC tem, e é deles que vêm os `preferences-*` do COSMIC Ajustes que
#   nenhuma base traz (tema herdado que falta é ignorado, e não quebra nada).
#   Cada base herda só o `hicolor` (o `Inherits=` do upstream aponta para temas
#   que não viajam), vai escondida, e perde as marcas de dono desta casa.
#   Imprime as camadas, uma por linha.
meow_tema_exportado_heranca() {
  local icones="$1" nome="$2" tema="$1/$2" h camadas=() herda c
  for h in $(sed -n 's/^Inherits=//p' "$tema/index.theme" | head -1 | tr ',' ' '); do
    case "$h" in "$nome"-Base|"$nome"-Base-[0-9]*) [ -d "$icones/$h" ] && camadas+=("$h") ;; esac
  done
  herda="$(printf '%s,' ${camadas[@]+"${camadas[@]}"})Cosmic,Adwaita,hicolor"
  _meow_herdar "$tema/index.theme" "$herda" || return "$MEOW_ERRO"
  for c in ${camadas[@]+"${camadas[@]}"}; do
    _meow_herdar "$icones/$c/index.theme" "hicolor" || return "$MEOW_ERRO"
    rm -f "$icones/$c/.meow-origem" "$icones/$c/.meow-somas.sha256"
    meow_tema_base_escondida "$icones/$c"; [ "$?" -le 1 ] || return "$MEOW_ERRO"
  done
  printf '%s\n' ${camadas[@]+"${camadas[@]}"}
}

# _meow_herdar <index.theme> <lista> — troca a primeira linha `Inherits=`.
_meow_herdar() {
  local tmp; tmp="$(mktemp -p "$(dirname "$1")" .meow.XXXXXX)" || return 1
  awk -v h="$2" 'BEGIN{feito=0} /^Inherits=/ && !feito {print "Inherits=" h; feito=1; next} {print}' "$1" > "$tmp" \
    && mv -f "$tmp" "$1"
}

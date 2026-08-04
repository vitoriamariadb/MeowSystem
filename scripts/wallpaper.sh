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
  local freq metodo
  freq="$(segundos_de "$INTERVALO")"
  metodo="$(metodo_de "$ORDEM")"
  # `filter_by_theme: false` de propósito: com `true` o COSMIC filtra as imagens
  # pelo claro/escuro do tema e pode acabar sem nenhuma candidata no diretório —
  # tela preta sem explicação. O carrossel é dela, não do tema.
  # `filter_method` e `scaling_mode` são as escolhas dela e são preservadas.
  cat <<FIM
(
    output: "all",
    source: Path("$ATIVOS"),
    filter_by_theme: false,
    rotation_frequency: $freq,
    filter_method: Lanczos,
    scaling_mode: Fit((0.0, 0.0, 0.0)),
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
semear_das_dela() {
  local origem="$HOME/Imagens/Parede_papel"
  [ -d "$origem" ] || return 0
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

  # `all` é o que vale (same-on-all está ligado), mas as saídas por nome existem e
  # o COSMIC lê a que casar. Escrever as três de forma consistente evita um estado
  # em que o monitor certo mostra a imagem errada — e tratar saída desconectada
  # sem erro é de graça, já que só escrevemos os arquivos que já existem.
  local alvo
  for alvo in all output.DP-1 output.HDMI-A-1; do
    [ "$alvo" = "all" ] || [ -f "$BG/$alvo" ] || continue
    local conteudo="$desejada"
    [ "$alvo" = "all" ] || conteudo="${desejada/output: \"all\"/output: \"${alvo#output.}\"}"
    meow_escrever "$BG/$alvo" "$conteudo" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao escrever $alvo"; return "$MEOW_ERRO" ;; esac
  done

  if [ "$mudou" = "0" ]; then
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
  if [ -f "$BG/all" ]; then
    local fonte; fonte="$(grep -oP 'source: Path\("\K[^"]+' "$BG/all" 2>/dev/null)"
    if [ "$fonte" = "$ATIVOS" ]; then
      echo "estado:    carrossel ATIVO"
    else
      echo "estado:    apontando para outro lugar ($fonte)"
    fi
  fi
  # A imagem exata que está na tela não é observável: o cosmic-bg não fala D-Bus
  # e não grava o índice em lugar nenhum. Dizer "não sei" é melhor que inventar.
  echo "atual:     (o cosmic-bg não expõe qual imagem está em exibição)"
}

# Mover, nunca apagar: uma imagem banida pode ser recuperada de banidos/.
cmd_banir() {
  local img="$1"
  [ -f "$img" ] || { meow_erro "não achei $img"; return "$MEOW_ERRO"; }
  criar_pastas
  mv -n "$img" "$BASE/banidos/" || return "$MEOW_ERRO"
  meow_ok "banida: $(basename "$img") — está em banidos/, não foi apagada"
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

case "${1:-aplicar}" in
  aplicar)   cmd_aplicar ;;
  estado)    cmd_estado ;;
  banir)     shift; cmd_banir "${1:-}" ;;
  adicionar) shift; cmd_adicionar "${1:-}" ;;
  *) echo "uso: wallpaper.sh [aplicar|estado|adicionar <alvo>|banir <img>]" >&2; exit 2 ;;
esac

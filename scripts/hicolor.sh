#!/usr/bin/env bash
# hicolor.sh — o `index.theme` do hicolor DELA esconde metade dos próprios ícones.
#
# O SINTOMA: "as logos dos jogos da Steam sumiram"
#   Medido em 2026-08-04. O `~/.local/share/icons/hicolor/index.theme` declarava
#   QUATRO seções — `48x48/apps`, `128x128/apps`, `256x256/apps`, `512x512/apps` —
#   enquanto a pasta tinha TREZE tamanhos no disco (16, 20, 22, 24, 32, 40, 48,
#   64, 96, 128, 192, 256, 512) mais `scalable`.
#
#   Um ícone que só existe num tamanho não declarado é INVISÍVEL: o resolvedor
#   não varre o disco, ele varre as seções do index.theme. E dois ícones de jogo
#   caíam exatamente aí:
#       steam_icon_2369580   só em 32x32   -> "Mad King Redemption.desktop"
#       steam_icon_1657740   só em 32x32
#   Junto com eles sumiam `shadps4-cosmic` (só em `scalable`) e os tamanhos
#   pequenos de `fogstripper` e `hefesto-dualsense4unix`.
#
# POR QUE NÃO É CULPA DO NOSSO TEMA
#   O `MeowSystem-Icons` termina a cadeia no hicolor, como todo tema termina. O
#   arquivo quebrado é de 2026-05-12, muito antes deste projeto existir — foi
#   escrito por algum instalador de terceiro (a Steam grava ícone aqui a cada
#   jogo). Nós não causamos, mas somos quem cuida de ícone nesta máquina, então
#   somos quem conserta.
#
# A REGRA QUE FAZ ISSO DOER (e que o auditar_icones.sh já documenta)
#   `parse.rs::get_all_directories` percorre as SEÇÕES `[...]` e aceita cada uma
#   que declare `Size=`, PARANDO na primeira que não declare — a chave
#   `Directories=` nunca é lida pelo COSMIC. Já o GTK lê o `Directories=`. Como
#   os dois resolvedores rodam nesta máquina (COSMIC para o painel e a área de
#   trabalho, GTK para os apps GTK), este script escreve os DOIS de forma
#   consistente: `Directories=` completo E uma seção com `Size=` para cada.
#
# GERADO DO DISCO, NUNCA DE UMA LISTA FIXA
#   A Steam cria tamanho novo quando ela instala um jogo. Uma lista cravada aqui
#   ficaria velha na próxima compra dela — e o sintoma voltaria idêntico, meses
#   depois, sem ninguém ligar uma coisa à outra. O script varre o que EXISTE.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

BASE="${HICOLOR_BASE:-$HOME/.local/share/icons/hicolor}"
INDEX="$BASE/index.theme"

[ -d "$BASE" ] || { meow_pula "não há hicolor do usuário em $BASE — nada a fazer"; exit "$MEOW_OK"; }

# freedesktop icon-theme spec §Context. O que não estiver aqui vira Applications,
# que é o contexto mais permissivo — errar o Context não esconde o ícone, mas
# omitir a seção esconde.
contexto_de() {
  case "$1" in
    apps)       echo Applications ;;
    actions)    echo Actions ;;
    animations) echo Animations ;;
    categories) echo Categories ;;
    devices)    echo Devices ;;
    emblems)    echo Emblems ;;
    emotes)     echo Emotes ;;
    intl)       echo International ;;
    mimetypes)  echo MimeTypes ;;
    places)     echo Places ;;
    status)     echo Status ;;
    *)          echo Applications ;;
  esac
}

# Varre <tamanho>/<contexto> e devolve só os pares que TÊM arquivo. Pasta vazia
# vira seção morta: não quebra nada, mas mente sobre o que o tema oferece.
pares_com_icone() {
  local d ctx
  for d in "$BASE"/*/; do
    d="${d%/}"; d="$(basename "$d")"
    case "$d" in scalable|[0-9]*x[0-9]*) ;; *) continue ;; esac
    for ctx in "$BASE/$d"/*/; do
      [ -d "$ctx" ] || continue
      ctx="${ctx%/}"; ctx="$(basename "$ctx")"
      # `-print -quit` para na primeira: uma pasta com 400 ícones não precisa
      # ser contada inteira só para responder "tem algum?".
      [ -n "$(find "$BASE/$d/$ctx" -maxdepth 1 -type f -print -quit 2>/dev/null)" ] || continue
      printf '%s/%s\n' "$d" "$ctx"
    done
  done | sort -u
}

# Ordena por tamanho crescente, com `scalable` por último. Não é cosmético: o
# resolvedor do COSMIC percorre as seções NA ORDEM e a primeira que sirva ganha.
# Com `512x512` na frente, um ícone de 16px pediria o arquivo de 512 e o
# downscale ficaria borrado na barra de tarefas.
ordenar() {
  while IFS= read -r p; do
    local dir="${p%%/*}"
    case "$dir" in
      scalable) printf '999999 %s\n' "$p" ;;
      *) printf '%06d %s\n' "${dir%%x*}" "$p" ;;
    esac
  done | sort -n | cut -d' ' -f2-
}

mapfile -t PARES < <(pares_com_icone | ordenar)

if [ "${#PARES[@]}" -eq 0 ]; then
  meow_pula "o hicolor do usuário não tem ícone nenhum — nada a declarar"
  exit "$MEOW_OK"
fi

gerar_index() {
  local p dir ctx tam
  # `Hidden=true` é do spec: o hicolor é o fallback, não deve aparecer na lista de
  # temas escolhíveis. O arquivo dela já tinha, e tirar isso o faria brotar nas
  # Configurações como se fosse um tema de verdade.
  printf '[Icon Theme]\n'
  printf 'Name=Hicolor\n'
  printf 'Comment=Fallback Icon Theme\n'
  printf 'Hidden=true\n'
  printf 'Directories=%s\n' "$(printf '%s,' "${PARES[@]}" | sed 's/,$//')"

  for p in "${PARES[@]}"; do
    dir="${p%%/*}"; ctx="${p##*/}"
    printf '\n[%s]\n' "$p"
    if [ "$dir" = "scalable" ]; then
      # Size é obrigatório MESMO em Scalable (é a regra do parse: seção sem Size
      # corta a lista ali). 128 é o tamanho nominal; Min/Max é o alcance real.
      printf 'Size=128\n'
      printf 'MinSize=8\n'
      printf 'MaxSize=512\n'
      printf 'Type=Scalable\n'
    else
      tam="${dir%%x*}"
      printf 'Size=%s\n' "$tam"
      printf 'Type=Fixed\n'
    fi
    printf 'Context=%s\n' "$(contexto_de "$ctx")"
  done
}

NOVO="$(gerar_index)"

if [ -f "$INDEX" ] && [ "$NOVO" = "$(cat "$INDEX" 2>/dev/null)" ]; then
  meow_ok "hicolor do usuário já declara as ${#PARES[@]} pastas que tem"
  exit "$MEOW_OK"
fi

# Quantas ficariam de fora do jeito que está — é este número que explica o
# sintoma para quem ler o log daqui a seis meses.
antes=0
[ -f "$INDEX" ] && antes="$(grep -cE '^\[[^]]+/[^]]+\]' "$INDEX" 2>/dev/null || echo 0)"

if meow_seco; then
  meow_muda "declararia ${#PARES[@]} pastas no hicolor do usuário (hoje: $antes)"
  exit "$MEOW_DIVERGENTE"
fi

# BACKUP: este arquivo não é nosso. Mesmo padrão dos módulos de aplicativo —
# pasta carimbada e `origens.txt` com o caminho absoluto, para o desfazer saber
# de onde cada cópia veio.
if [ -f "$INDEX" ]; then
  DIR_BK="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/backups/${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"
  mkdir -p "$DIR_BK"
  cp -a "$INDEX" "$DIR_BK/hicolor-index.theme" 2>/dev/null \
    && printf '%s\n' "$INDEX" >> "$DIR_BK/origens.txt"
fi

meow_escrever "$INDEX" "$NOVO" 644
case $? in 2) meow_erro "não consegui escrever $INDEX"; exit "$MEOW_ERRO" ;; esac

# A cache tem a MESMA doença da cache do nosso tema (ver completar_icones.sh §3b):
# se existe, o GTK confia nela e ignora o disco. Como acabamos de mudar quais
# pastas contam, uma cache velha manteria o sintoma inteiro de pé.
CACHE="$BASE/icon-theme.cache"
if [ -f "$CACHE" ]; then
  if meow_tem gtk-update-icon-cache; then
    if gtk-update-icon-cache -q -f "$BASE" 2>/dev/null; then
      meow_info "cache do hicolor reindexada"
    else
      meow_aviso "não consegui reindexar $CACHE — apague-a se algum ícone não aparecer"
    fi
  else
    meow_aviso "$CACHE está velha e esconde os ícones, e não há gtk-update-icon-cache"
    meow_info "  apague o arquivo: rm '$CACHE'"
  fi
fi

meow_ok "hicolor do usuário: ${#PARES[@]} pastas declaradas (antes: $antes)"
meow_info "as logos que só existiam em tamanho não declarado voltam a aparecer"
exit "$MEOW_DIVERGENTE"

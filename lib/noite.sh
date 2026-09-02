#!/usr/bin/env bash
# lib/noite.sh — "é noite AGORA?", uma vez só, para a máquina inteira.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO.
#
# POR QUE ELE EXISTE: A MÁQUINA TINHA TRÊS NOITES
#   Em 01/09/2026 a mesma regra estava escrita em TRÊS lugares, e os três
#   cabeçalhos diziam, cada um por sua vez, que a igualdade entre eles era o que
#   impedia a máquina de ter duas noites:
#
#     scripts/wallpaper.sh:637   `e_noite()`, em bash
#     scripts/leitura.sh:521     as mesmas três linhas, em awk, dentro do BEGIN
#     src/applets/leitura/src/main.rs:518  `fn e_noite()`, em Rust
#
#   Três cópias mantidas à mão por um comentário que pede "se um dia esta regra
#   mudar lá, tem de mudar aqui" é uma promessa que ninguém pode cumprir. E em
#   01/09/2026 chegou o QUARTO consumidor — o gato do dock e o do fastfetch,
#   que trocam de rosto com a hora. Quatro cópias seria pedir para divergirem.
#
#   As duas em shell passam a ser ESTA. A do awk continua onde está, porque o
#   `leitura.sh` calcula a rampa DENTRO do mesmo `awk` (ele precisa da fase E do
#   fator no mesmo passo, e chamar bash de dentro do awk seria pior); a do Rust
#   continua onde está, porque o applet não pode chamar shell a cada quadro. As
#   duas ficam com um comentário apontando para cá, e o `--conferir` do
#   `leitura.sh` compara os números — divergência vira aviso, não silêncio.
#
# A REGRA, QUE É A MESMA DE SEMPRE
#     ini == fim  ->  é noite o dia inteiro
#     ini >  fim  ->  a janela atravessa a meia-noite (é o caso NORMAL aqui:
#                     o padrão é 18:00-07:00, e "entre os dois" seria vazio)
#     ini <  fim  ->  janela normal, dentro do mesmo dia
#
#   `ini == fim` fica valendo NOITE O DIA INTEIRO, e não "janela vazia". A outra
#   leitura transformaria dois valores iguais numa chave que não faz nada e não
#   avisa — o defeito que este projeto mais documenta ter cometido (a `LOG_NIVEL`
#   inerte, as `WALLPAPER_SEMENTES`).
#
# DE ONDE VEM A JANELA, E POR QUE A ORDEM É ESTA
#   `meow_noite_janela` devolve `<ini> <fim> <fonte>` e a fonte é dita em voz
#   alta, porque "que noite está valendo" é pergunta que aparece quando algo
#   troca na hora errada. A ordem de precedência:
#
#     1. `NOITE_INICIO` / `NOITE_FIM` no meow.conf — o nome canônico, novo em
#        01/09/2026. Quem escrever isto manda em tudo.
#     2. `leitura_hora_inicio` / `leitura_hora_fim` do CosmicComp — a janela que
#        ELA ARRASTA na interface do applet do modo de leitura. Vem antes do
#        conf antigo de propósito: é a única que ela pode mudar sem abrir editor,
#        e uma janela que a interface mostra e a máquina ignora é mentira na tela.
#        MEDIDO em 01/09/2026: os dois arquivos estão AUSENTES nesta máquina
#        (ela nunca arrastou), então hoje quem vence é o item 3 — e é por isso
#        que a ordem só aparece quando alguém mexe.
#     3. `WALLPAPER_NOITE_INICIO` / `WALLPAPER_NOITE_FIM` — o nome com que essas
#        chaves nasceram. Continuam valendo para sempre; renomear chave de
#        configuração de alguém sem aviso é quebrar a máquina dela por estética.
#     4. 18:00 / 07:00, o padrão.
#
#   O `wallpaper.sh` já chamava suas variáveis internas de `NOITE_INICIO` e
#   `NOITE_FIM` (ele mapeava `WALLPAPER_NOITE_*` para elas na leitura do conf).
#   Ou seja: o nome canônico não é invenção nova, é a promoção de um nome que já
#   existia dentro de um script para o vocabulário da máquina inteira.
#
# NADA AQUI ESCREVE EM DISCO, E NADA AQUI IMPRIME SOZINHO. É biblioteca de
# consulta: quem decide o que fazer com a resposta é quem chamou.

# `HH:MM` -> minutos desde a meia-noite. Falha (1) em qualquer outra coisa.
#
# ACEITA `H:MM` TAMBÉM, e isso não é frouxidão: o RON do CosmicComp guarda a
# hora como string entre aspas e nada impede um `"7:00"` vindo da interface.
# O que NÃO se aceita é hora fora da faixa — `25:00` vira falha, não 1500.
meow_minutos_de_hora() {
  local v="${1:-}" h m
  v="${v%\"}"; v="${v#\"}"          # o RON entrega com aspas; o conf, sem
  case "$v" in
    [0-9][0-9]:[0-9][0-9]|[0-9]:[0-9][0-9]) ;;
    *) return 1 ;;
  esac
  h="${v%%:*}"; m="${v##*:}"
  [ "$((10#$h))" -le 23 ] && [ "$((10#$m))" -le 59 ] || return 1
  printf '%s' "$(( 10#$h * 60 + 10#$m ))"
}

# Lê uma chave do CosmicComp sem explodir quando o diretório não existe.
_meow_noite_cosmic() {
  local f="$HOME/.config/cosmic/com.system76.CosmicComp/v1/$1"
  [ -f "$f" ] || return 1
  local v; v="$(cat "$f" 2>/dev/null)" || return 1
  [ -n "$v" ] || return 1
  printf '%s' "$v"
}

# `<ini> <fim> <fonte>` em minutos. NUNCA falha: o item 4 da lista é o chão.
meow_noite_janela() {
  local i f ini fim

  if i="${NOITE_INICIO:-}" && f="${NOITE_FIM:-}" && [ -n "$i" ] && [ -n "$f" ]; then
    if ini="$(meow_minutos_de_hora "$i")" && fim="$(meow_minutos_de_hora "$f")"; then
      printf '%s %s meow.conf' "$ini" "$fim"; return 0
    fi
  fi

  if i="$(_meow_noite_cosmic leitura_hora_inicio)" \
     && f="$(_meow_noite_cosmic leitura_hora_fim)"; then
    if ini="$(meow_minutos_de_hora "$i")" && fim="$(meow_minutos_de_hora "$f")"; then
      printf '%s %s applet-leitura' "$ini" "$fim"; return 0
    fi
  fi

  i="${WALLPAPER_NOITE_INICIO:-}"; f="${WALLPAPER_NOITE_FIM:-}"
  if [ -n "$i" ] && [ -n "$f" ]; then
    if ini="$(meow_minutos_de_hora "$i")" && fim="$(meow_minutos_de_hora "$f")"; then
      printf '%s %s meow.conf(WALLPAPER_NOITE_*)' "$ini" "$fim"; return 0
    fi
  fi

  printf '1080 420 padrão'
}

# 0 = é noite agora. Sem argumentos, usa a janela de `meow_noite_janela`.
#
# O `date` É CHAMADO AQUI E NÃO GUARDADO: uma função que memoriza a hora
# responderia a mesma coisa às 17:59 e às 18:01 dentro de um processo que viva
# muito — e o `logo.sh` chamado pelo timer vive segundos, mas o `install.sh`
# vive minutos e chama várias etapas.
meow_e_noite() {
  local ini fim agora janela
  if [ "$#" -ge 2 ]; then
    ini="$1"; fim="$2"
  else
    janela="$(meow_noite_janela)"
    ini="${janela%% *}"; fim="${janela#* }"; fim="${fim%% *}"
  fi
  agora="$(meow_minutos_de_hora "$(date +%H:%M)")" || return 0
  [ "$ini" = "$fim" ] && return 0
  if [ "$ini" -gt "$fim" ]; then
    [ "$agora" -ge "$ini" ] || [ "$agora" -lt "$fim" ]
  else
    [ "$agora" -ge "$ini" ] && [ "$agora" -lt "$fim" ]
  fi
}

# `noite` ou `dia`, para quem precisa do nome e não do código de saída.
meow_fase_da_hora() { if meow_e_noite "$@"; then printf 'noite'; else printf 'dia'; fi; }

# `HH:MM` a partir dos minutos — só para diagnóstico legível.
meow_hora_de_minutos() { printf '%02d:%02d' "$(( ${1:-0} / 60 ))" "$(( ${1:-0} % 60 ))"; }

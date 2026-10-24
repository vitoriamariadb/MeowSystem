#!/usr/bin/env bash
# lib/noite.sh — "é noite AGORA?", uma vez só, para o mascote do dock e o do
# terminal.
#
#     scripts/wallpaper.sh:637   `e_noite()`, em bash
#     scripts/leitura.sh:521     as mesmas três linhas, em awk, dentro do BEGIN
#     src/applets/leitura/src/main.rs:518  `fn e_noite()`, em Rust
#
# Três cópias mantidas à mão por um comentário que pede "se um dia esta regra
# mudar lá, tem de mudar aqui" é uma promessa que ninguém pode cumprir.
#
#     ini == fim  ->  é noite o dia inteiro
#     ini >  fim  ->  a janela atravessa a meia-noite (é o caso NORMAL aqui:
#                     o padrão é 18:00-07:00, e "entre os dois" seria vazio)
#     ini <  fim  ->  janela normal, dentro do mesmo dia

# `HH:MM` -> minutos desde a meia-noite. Falha (1) em qualquer outra coisa.
#
# ACEITA `H:MM` TAMBÉM, e isso não é frouxidão: o RON do CosmicComp guarda a
# hora como string entre aspas e nada impede um `"7:00"` vindo da interface.
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
  local f; f="$(meow_cosmic_dir)/com.system76.CosmicComp/$(meow_cosmic_v com.system76.CosmicComp)/$1"
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

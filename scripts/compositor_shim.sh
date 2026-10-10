#!/usr/bin/env bash
# MEOW-COSMIC-COMP-SHIM-1
# compositor_shim.sh — o `cosmic-comp` que a SESSÃO dela encontra pelo PATH.
#
# Instalado (pelo `meow compositor ativar`) como `~/.local/bin/cosmic-comp`.
# Ele escolhe, a cada início de sessão, entre o build patchado em escopo de
# usuário e o binário de fábrica, e depois some com `exec`: o compositor que
# fica no ar é o escolhido, com o PID deste processo.
#
# POR QUE ISTO EXISTE (P76, `docs/pesquisas/2026-10-09-cosmic-vivo.md` §4.1)
#   O build patchado morava em `/usr/bin/cosmic-comp`. Lá o apt sobrescreve, e
#   a tela de login usa o mesmo arquivo: daí a recusa de auto-build e o
#   `patches/versao` manual. Medido em 09/10/2026: o `cosmic-session` lança o
#   compositor pelo nome nu (cmdline `cosmic-comp`) com um PATH que começa em
#   `~/.local/bin`; o greeter roda por `greetd` com outro usuário e com o PATH
#   do sistema. Então um arquivo aqui vale para a sessão dela e não para a tela
#   de login, e o apt nunca o toca.
#
# AS TRÊS CONDIÇÕES DO BUILD, todas ao mesmo tempo, ou é fábrica:
#   1. existe build para a versão que o dpkg diz instalada (artefato por
#      versão: um build de outra versão nunca vence o que o apt instalou);
#   2. o `estado` do build traz o `req` presente (medido no binário pelo
#      `compilar`, nunca deduzido da série);
#   3. o build não está marcado `ruim` pela guarda de queda.
#
# A GUARDA DE QUEDA, e por que ninguém fica preso fora da sessão
#   Cada início pelo build soma 1 em `quedas`. Um vigia solto zera o contador
#   se o compositor ainda estiver vivo depois de `MEOW_SHIM_JANELA` segundos
#   (30). Se o contador chega aqui em 2, as duas últimas sessões pelo build
#   morreram antes de 30 s: o build desta versão vira `ruim` e a sessão sobe
#   de fábrica até existir um build novo (o `compilar` apaga o `ruim`).
#
# NADA DE `$MEOW_RAIZ` AQUI DENTRO, de propósito: o repositório pode morar num
# disco que ainda não montou quando a sessão sobe. Este arquivo se basta.
#
# `MEOW_SHIM_SO_DIZER=1` só imprime o caminho que seria executado, sem contar
# queda nem lançar nada. É por ele que o `meow` pergunta "qual compositor vale
# no próximo login" sem repetir esta regra em outro lugar.

fabrica="${MEOW_SHIM_FABRICA:-/usr/bin/cosmic-comp}"
casa="${MEOW_SHIM_CASA:-$HOME/.local/libexec/meow/cosmic-comp}"
janela="${MEOW_SHIM_JANELA:-30}"
limite=2

ver="$(dpkg-query -W -f='${Version}' cosmic-comp 2>/dev/null)"
dir="$casa/$ver"
build="$dir/cosmic-comp"

usar_build=0
if [ -n "$ver" ] && [ -x "$build" ] && [ ! -e "$dir/ruim" ] \
   && grep -q '^req [^ ]* [^ ]* presente$' "$dir/estado" 2>/dev/null; then
  usar_build=1
fi

if [ "${MEOW_SHIM_SO_DIZER:-0}" = "1" ]; then
  if [ "$usar_build" = "1" ]; then printf '%s\n' "$build"; else printf '%s\n' "$fabrica"; fi
  exit 0
fi

if [ "$usar_build" = "1" ]; then
  n="$(cat "$dir/quedas" 2>/dev/null)"
  case "$n" in ''|*[!0-9]*) n=0 ;; esac
  if [ "$n" -ge "$limite" ]; then
    date -Is > "$dir/ruim" 2>/dev/null
    exec "$fabrica" "$@"
  fi
  printf '%s\n' "$((n + 1))" > "$dir/quedas" 2>/dev/null
  # O VIGIA É `sh`, E NÃO UM SUBSHELL DESTE BASH: um subshell herdaria o nome
  # `cosmic-comp` deste script, e todo `pgrep -x cosmic-comp` do projeto
  # passaria a achar dois compositores por 30 s. E ele larga todo descritor
  # herdado além de 0-2 (que vão para /dev/null): o `cosmic-session` passa
  # socket ao compositor, e um vigia segurando a ponta deixaria a queda
  # invisível para quem supervisiona.
  (
    for fd in /proc/"$BASHPID"/fd/*; do
      fd="${fd##*/}"
      [ "$fd" -gt 2 ] 2>/dev/null && eval "exec $fd>&-" 2>/dev/null
    done
    exec /bin/sh -c 'sleep "$1"; kill -0 "$2" 2>/dev/null && rm -f "$3"' \
      meow-shim-vigia "$janela" "$$" "$dir/quedas" </dev/null >/dev/null 2>&1
  ) &
  exec "$build" "$@"
fi

exec "$fabrica" "$@"

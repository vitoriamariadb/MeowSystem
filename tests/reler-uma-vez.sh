#!/usr/bin/env bash
# reler-uma-vez.sh — a instalação relê a tela uma vez só, no fim da passada.
# Sprint P80, item 7, 10/10/2026.
#
# O QUE ABRIU ISTO (docs/sprints/2026-10-09-uso-real/04-integracao-onda-2.md, P79)
#   O `icones_apps_arcticons.sh`, o `icones_apps_dracula.sh` e o
#   `icones_resgatados.sh` chamam o `meow_tela_reler` (lib/comum.sh), cada um
#   no fim do seu passo, e uma instalação que muda os três recicla o
#   `cosmic-panel` três vezes seguidas. Um reciclo do painel foi o gatilho da
#   faixa verde de 09/10 (Migração-OS/levas/leva-08-gpu-regressao.md). E
#   nada registrava quem pediu cada reciclo.
#
# O QUE ESTE TESTE COBRA
#   1. Dentro de uma passada (`MEOW_RELER_NO_FIM` no ambiente, que o
#      install.sh arma), três chamadas ao `meow_tela_reler`, de três processos,
#      não reciclam nada: marcam «precisa reler», com o nome de quem pediu.
#   2. O `meow_tela_reler_no_fim` relê UMA vez, e o `painel.sh reciclar` recebe
#      os três nomes; chamado de novo, não relê mais.
#   3. Fora de uma passada, o `meow_tela_reler` relê na hora, como sempre: um
#      «Usar este ícone» do painel roda o passo sozinho, e a dock tem de mudar.
#   4. O install.sh arma a marca antes do laço das passagens e relê depois dele.
#   4b. O `meow doctor --consertar` faz o mesmo em volta dos consertos dele
#      (conferência da P80).
#   5. O `painel.sh reciclar` registra no meow.log quem o chamou, até quando
#      não há painel a reciclar.
#   6. O `icones_apps_arcticons.sh` de verdade, com a marca armada, sai 1
#      (mudou), e não com o código do reler (conferência da P80).
#
# A TELA É DE BRINQUEDO: o `getent` falso diz que a casa de brinquedo é a da
#   conta (a cerca do `meow_tela_reler`), o `pgrep` falso diz que há painel, e
#   o `painel.sh` é um falso que só anota — na raiz de brinquedo. O item 5 roda
#   o `painel.sh` de verdade numa casa onde o `pgrep` falso não acha painel.
#
# PORTÁTIL: só bash.
#   0 = passou · 1 = falhou · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ACHADOS=0
ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /' >&2; ACHADOS=$((ACHADOS + 1)); }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
CASA="$T/casa"; FALSO="$T/falso"; RB="$T/raiz"; ANOTA="$T/reciclos"
mkdir -p "$CASA" "$FALSO" "$RB/scripts" "$RB/lib" || exit 2
cp "$RAIZ/lib/"*.sh "$RB/lib/" || exit 2
: > "$ANOTA"

printf '#!/bin/sh\nprintf "%%s:x:%%s:%%s::%%s:/bin/bash\\n" "$(id -un)" "$(id -u)" "$(id -g)" "%s"\n' "$CASA" > "$FALSO/getent"
# Há painel (`-x cosmic-panel`); o lançador, não (o `-f` dele não acha ninguém).
printf '#!/bin/sh\ncase " $* " in *" -x cosmic-panel "*) echo 4242; exit 0 ;; esac\nexit 1\n' > "$FALSO/pgrep"
printf '#!/bin/sh\nexit 1\n' > "$FALSO/kill"
printf '#!/bin/sh\nprintf "reciclar quem=%%s\\n" "${MEOW_QUEM_RECICLA:-}" >> "%s"\nexit 0\n' "$ANOTA" > "$RB/scripts/painel.sh"
chmod 755 "$FALSO"/* "$RB/scripts/painel.sh"

# Um processo filho com a lib da raiz de brinquedo, como cada script de ícone.
passo() {  # <nome do script>
  env -i PATH="$FALSO:$PATH" HOME="$CASA" MEOW_RAIZ="$RB" NO_COLOR=1 \
      ${MEOW_RELER_NO_FIM:+MEOW_RELER_NO_FIM="$MEOW_RELER_NO_FIM"} \
      bash -c '. "$MEOW_RAIZ/lib/comum.sh"; meow_tela_reler; printf "rc=%s\n" "$?"' "$1"
}

printf '\n--- 1 e 2. numa passada, três pedidos e um reler só ---\n'
MEOW_RELER_NO_FIM="$T/precisa-reler"; export MEOW_RELER_NO_FIM
for s in icones_apps_arcticons.sh icones_apps_dracula.sh icones_resgatados.sh; do passo "$s" >/dev/null 2>&1; done
if [ ! -s "$ANOTA" ] && [ "$(grep -c . "$MEOW_RELER_NO_FIM" 2>/dev/null)" = 3 ]; then
  ok "três pedidos dentro da passada marcam «precisa reler» e não reciclam o painel"
else
  falha "dentro da passada o painel reciclou (ou a marca não tem os três pedidos)" \
        "reciclos: $(cat "$ANOTA") / marca: $(cat "$MEOW_RELER_NO_FIM" 2>/dev/null)"
fi
fim() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA" MEOW_RAIZ="$RB" NO_COLOR=1 MEOW_RELER_NO_FIM="$MEOW_RELER_NO_FIM" \
      bash -c '. "$MEOW_RAIZ/lib/comum.sh"; meow_tela_reler_no_fim' >/dev/null 2>&1
}
fim; fim
if [ "$(grep -c . "$ANOTA")" = 1 ] && grep -q 'icones_apps_arcticons.sh' "$ANOTA" \
   && grep -q 'icones_apps_dracula.sh' "$ANOTA" && grep -q 'icones_resgatados.sh' "$ANOTA" \
   && [ ! -e "$MEOW_RELER_NO_FIM" ]; then
  ok "o fim da passada relê uma vez, com os três nomes; a segunda chamada não relê de novo"
else
  falha "o fim da passada não releu exatamente uma vez com os três nomes" "$(cat "$ANOTA")"
fi
unset MEOW_RELER_NO_FIM

printf '\n--- 3. fora da passada, relê na hora ---\n'
: > "$ANOTA"
saida="$(passo icones_apps_dracula.sh 2>&1)"
if [ "$(grep -c . "$ANOTA")" = 1 ] && grep -q 'icones_apps_dracula.sh' "$ANOTA"; then
  ok "sem passada, o meow_tela_reler recicla na hora e diz quem pediu"
else
  falha "sem passada, o meow_tela_reler não reciclou na hora" "$saida / $(cat "$ANOTA")"
fi

printf '\n--- 4. o install.sh arma a marca antes do laço e relê depois dele ---\n'
laco="$(grep -n 'while :; do' "$RAIZ/install.sh" | head -1 | cut -d: -f1)"
arma="$(grep -nE '^[^#]*export MEOW_RELER_NO_FIM' "$RAIZ/install.sh" | head -1 | cut -d: -f1)"
rele="$(grep -nE '^[^#]*meow_tela_reler_no_fim' "$RAIZ/install.sh" | head -1 | cut -d: -f1)"
if [ -n "$laco" ] && [ -n "$arma" ] && [ -n "$rele" ] && [ "$arma" -lt "$laco" ] && [ "$rele" -gt "$laco" ]; then
  ok "install.sh: a marca nasce na linha $arma, o laço na $laco, o reler na $rele"
else
  falha "o install.sh não arma a marca antes do laço ou não relê depois dele" "laço=$laco arma=$arma relê=$rele"
fi

printf '\n--- 4b. o conserto do doctor também relê uma vez, depois do laço dele ---\n'
#   Conferência da P80: o `meow doctor --consertar` (o auto-reparo das 5h e o
#   «Consertar» do painel) chama o `fix_arcticons`, o `fix_resgatados` e o
#   `fix_dracula` no mesmo laço — os mesmos três reciclos da instalação.
laco="$(grep -n 'meow_passo "Consertando o que falhou"' "$RAIZ/bin/meow" | head -1 | cut -d: -f1)"
fixes="$(grep -n '"fix_\$nome"' "$RAIZ/bin/meow" | head -1 | cut -d: -f1)"
arma="$(grep -nE '^[^#]*export MEOW_RELER_NO_FIM' "$RAIZ/bin/meow" | head -1 | cut -d: -f1)"
rele="$(grep -nE '^[^#]*meow_tela_reler_no_fim' "$RAIZ/bin/meow" | head -1 | cut -d: -f1)"
if [ -n "$laco" ] && [ -n "$fixes" ] && [ -n "$arma" ] && [ -n "$rele" ] \
   && [ "$arma" -gt "$laco" ] && [ "$arma" -lt "$fixes" ] && [ "$rele" -gt "$fixes" ]; then
  ok "bin/meow: a marca nasce na linha $arma, os consertos na $fixes, o reler na $rele"
else
  falha "o doctor não arma a marca antes dos consertos ou não relê depois deles" \
        "consertando=$laco arma=$arma fix=$fixes relê=$rele"
fi

printf '\n--- 5. o painel.sh reciclar registra quem o chamou ---\n'
printf '#!/bin/sh\nexit 1\n' > "$FALSO/pgrep"
env -i PATH="$FALSO:$PATH" HOME="$CASA" NO_COLOR=1 MEOW_QUEM_RECICLA="quem-pediu-no-teste" \
    "$RAIZ/scripts/painel.sh" reciclar >/dev/null 2>&1
LOG="$CASA/.local/state/meowsystem/meow.log"
if grep -q 'painel reciclar.*quem-pediu-no-teste' "$LOG" 2>/dev/null; then
  ok "o meow.log diz quem pediu o reciclo: $(grep 'painel reciclar' "$LOG" | tail -1 | cut -d' ' -f2-)"
else
  falha "o painel.sh reciclar não registrou quem o chamou" "$(cat "$LOG" 2>/dev/null)"
fi

printf '\n--- 6. o passo de ícone que adia o reler continua dizendo «mudou» ---\n'
#   Conferência da P80: o `icones_apps_arcticons.sh` roda sob `set -e`, e o
#   `meow_tela_reler` solto no fim do `_aplicar` derrubava o script com o código
#   do reler — 4 dentro da passada, que o `concluir` do install.sh conta como
#   PULADO, e não como feito (e 3 fora da sessão, desde a P79). O script de
#   verdade, numa casa de brinquedo, com a marca da passada armada.
CASA6="$T/casa6"; mkdir -p "$CASA6"; : > "$T/marca6"
for c in sudo pkexec su; do printf '#!/bin/sh\nexit 1\n' > "$FALSO/$c"; chmod 755 "$FALSO/$c"; done
env -i PATH="$FALSO:$PATH" HOME="$CASA6" MEOW_RAIZ="$RAIZ" NO_COLOR=1 MEOW_RELER_NO_FIM="$T/marca6" \
    ICONES_TEMA=MeowSystem-Icons FLAVOR=mocha "$RAIZ/scripts/icones_apps_arcticons.sh" --aplicar >/dev/null 2>&1
rc=$?
if [ "$rc" = 1 ] && grep -qx 'icones_apps_arcticons.sh' "$T/marca6"; then
  ok "o icones_apps_arcticons.sh pôs os desenhos, anotou o reler e saiu 1 (mudou)"
else
  falha "o icones_apps_arcticons.sh saiu $rc (esperado 1) dentro da passada" "marca: $(cat "$T/marca6")"
fi

printf '\n'
[ "$ACHADOS" -eq 0 ] || { printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2; exit 1; }
printf 'passou: a instalação relê a tela uma vez, e o reciclo diz quem o pediu\n'
exit 0

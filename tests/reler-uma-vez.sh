#!/usr/bin/env bash
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
printf '#!/bin/sh\ncase " $* " in *" -x cosmic-panel "*) echo 4242; exit 0 ;; esac\nexit 1\n' > "$FALSO/pgrep"
printf '#!/bin/sh\nexit 1\n' > "$FALSO/kill"
printf '#!/bin/sh\nprintf "reciclar quem=%%s\\n" "${MEOW_QUEM_RECICLA:-}" >> "%s"\nexit 0\n' "$ANOTA" > "$RB/scripts/painel.sh"
chmod 755 "$FALSO"/* "$RB/scripts/painel.sh"

passo() {
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

printf '\n--- 4c. nenhum passo recicla o painel por fora da porta única ---\n'
achados="$(grep -rnE '^[^#]*painel\.sh"?[[:space:]]+reciclar' "$RAIZ/scripts" "$RAIZ/lib" "$RAIZ/install.sh" \
           | grep -v '^[^:]*/lib/comum\.sh:')"
[ -z "$achados" ] && ok "só o meow_tela_reler chama o painel.sh reciclar" \
  || falha "há passo reciclando o painel por fora do meow_tela_reler" "$achados"

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

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1" "${3:-}"; fi; }

CASA="$T/casa"; SIS="$T/sistema"; FALSO="$T/falso"; ESTADO="$CASA/.local/state/meowsystem"
SONS_SIS="$SIS/usr/share/sounds"; ORIG="$SIS/var/sons"; PONTE="$T/ponte/ponte_root.sh"
mkdir -p "$CASA" "$ESTADO" "$FALSO" "$T/ponte" "$ORIG" \
         "$SONS_SIS/Pop/stereo/notification" "$SONS_SIS/Pop/stereo/alert" "$SONS_SIS/freedesktop/stereo"

for ev in power-plug power-unplug battery-caution complete; do printf 'OggS fabrica %s\n' "$ev" > "$SONS_SIS/Pop/stereo/notification/$ev.oga"; done
for ev in power-unplug-battery-low battery-low; do printf 'OggS fabrica %s\n' "$ev" > "$SONS_SIS/Pop/stereo/alert/$ev.oga"; done
printf 'OggS fabrica dialog-warning\n' > "$SONS_SIS/freedesktop/stereo/dialog-warning.oga"
cp -a "$SONS_SIS" "$T/sons-de-fabrica"

sed -e "s#^export PATH=.*#export PATH=\"$FALSO:/usr/bin:/bin\"#" -e 's/ -o root -g root//g' \
    -e "s#^USR_SHARE=.*#USR_SHARE=$SIS/usr/share#" -e "s#^SONS_ORIGINAIS=.*#SONS_ORIGINAIS=$ORIG#" \
    -e 's#^anotar() {#anotar() { return 0#' "$RAIZ/scripts/ponte_root.sh" > "$PONTE"
chmod 755 "$PONTE"
cat > "$FALSO/sudo" <<FIM
#!/bin/sh
if [ "\$1" = "-n" ] && [ "\$2" = "$PONTE" ] && [ ! -f "$T/sem-ponte" ]; then shift; exec "\$@"; fi
exit 1
FIM
chmod 755 "$FALSO/sudo"

som() {
  local pack="$1" flavor="$2"; shift 2
  env -u DBUS_SESSION_BUS_ADDRESS -u XDG_RUNTIME_DIR HOME="$CASA" PATH="$FALSO:$PATH" MEOW_ESTADO="$ESTADO" \
      MEOW_CONF="$T/nao-existe.conf" MEOW_PONTE="$PONTE" MEOW_SONS_SISTEMA="$SONS_SIS" MEOW_SONS_ORIGINAIS="$ORIG" \
      PACK="$pack" FLAVOR="$flavor" SOM=sim "$@"
}
conf_do_som() { som "$1" "$2" bash "$RAIZ/scripts/som.sh" "${@:3}"; }

printf '\n--- 1. o timbre: o pack manda; o meow.conf só vale no pack em que foi tocado ---\n'
t="$(conf_do_som meowsystem mocha timbre)"
confere "sem nada no conf, o timbre é o do pack meowsystem" '[ "$(printf "%s\n" "$t" | sed -n s/^SOM_FUNDAMENTAL=//p)" = "880.0" ]' "$t"
t="$(conf_do_som dracula dracula timbre)"
confere "o Dracula tem o dele" '[ "$(printf "%s\n" "$t" | sed -n s/^SOM_FUNDAMENTAL=//p)" = "784" ] || [ "$(printf "%s\n" "$t" | sed -n s/^SOM_FUNDAMENTAL=//p)" = "784.0" ]' "$t"
t="$(som meowsystem mocha env SOM_FUNDAMENTAL=500 bash "$RAIZ/scripts/som.sh" timbre)"
confere "um SOM_FUNDAMENTAL velho, sem carimbo, não vence o pack" '[ "$(printf "%s\n" "$t" | sed -n s/^SOM_FUNDAMENTAL=//p)" = "880.0" ]' "$t"
printf 'meowsystem\n' > "$ESTADO/som-do-pack"
t="$(som meowsystem mocha env SOM_FUNDAMENTAL=500 bash "$RAIZ/scripts/som.sh" timbre)"
confere "com o carimbo do próprio pack, o ajuste dela vence" '[ "$(printf "%s\n" "$t" | sed -n s/^SOM_FUNDAMENTAL=//p)" = "500" ]' "$t"
t="$(som dracula dracula env SOM_FUNDAMENTAL=500 bash "$RAIZ/scripts/som.sh" timbre)"
confere "trocou de pack: o ajuste do outro pack não vem junto" '[ "$(printf "%s\n" "$t" | sed -n s/^SOM_FUNDAMENTAL=//p)" != "500" ]' "$t"
rm -f "$ESTADO/som-do-pack"

printf '\n--- 2. um sino só: a prévia, o controle e o Regravar geram os mesmos bytes ---\n'
conf_do_som meowsystem mocha aplicar >"$T/aplicar.txt" 2>&1
BELL="$CASA/.local/share/sounds/freedesktop/stereo/audio-volume-change.oga"
conf_do_som meowsystem mocha gerar "$T/previa.wav" >/dev/null 2>&1
confere "o que o painel toca (gerar) é byte a byte o que o Regravar grava" 'cmp -s "$T/previa.wav" "$BELL"'
t5="SOM_FUNDAMENTAL=520 SOM_HARMONICO=780 SOM_DECAIMENTO=60"
conf_do_som meowsystem mocha gerar "$T/previa2.wav" $t5 >/dev/null 2>&1
printf 'meowsystem\n' > "$ESTADO/som-do-pack"
som meowsystem mocha env $t5 bash "$RAIZ/scripts/som.sh" aplicar >/dev/null 2>&1
confere "com os números da barra, a prévia e o regravado seguem iguais" 'cmp -s "$T/previa2.wav" "$BELL" && ! cmp -s "$T/previa2.wav" "$T/previa.wav"'
conf_do_som meowsystem mocha gerar "$T/x.wav" SOM_FUNDAMENTAL=abc >/dev/null 2>&1; r1=$?
conf_do_som meowsystem mocha gerar "$T/x.wav" CURSOR=1 >/dev/null 2>&1; r2=$?
confere "o gerar recusa valor que não é número e chave fora do timbre" '[ "$r1" != 0 ] && [ "$r2" != 0 ]'
rm -f "$ESTADO/som-do-pack"
conf_do_som meowsystem mocha aplicar >/dev/null 2>&1

printf '\n--- 3. a ponte: carregador e bateria saem do Pop e entram do pack ---\n'
PACK_SONS="$RAIZ/packs/meowsystem/sons/stereo"
conf_do_som meowsystem mocha aplicar >"$T/a1.txt" 2>&1; rc1=$?
confere "aplicar põe os sete sons do pack no lugar dos do sistema" \
  'cmp -s "$PACK_SONS/notification/power-plug.oga" "$SONS_SIS/Pop/stereo/notification/power-plug.oga" && cmp -s "$PACK_SONS/alert/battery-low.oga" "$SONS_SIS/Pop/stereo/alert/battery-low.oga" && cmp -s "$PACK_SONS/alert/dialog-warning.oga" "$SONS_SIS/freedesktop/stereo/dialog-warning.oga" && cmp -s "$PACK_SONS/notification/complete.oga" "$SONS_SIS/Pop/stereo/notification/complete.oga"' "$(cat "$T/a1.txt")"
confere "o de fábrica fica guardado" 'cmp -s "$T/sons-de-fabrica/Pop/stereo/notification/power-plug.oga" "$ORIG/power-plug.original" && cmp -s "$T/sons-de-fabrica/freedesktop/stereo/dialog-warning.oga" "$ORIG/dialog-warning.original"'
conf_do_som meowsystem mocha aplicar >"$T/a2.txt" 2>&1; rc2=$?
confere "a segunda passada não escreve nada (rc 0)" '[ "$rc2" = 0 ]' "rc=$rc2 $(cat "$T/a2.txt")"
conf_do_som meowsystem mocha conferir >/dev/null 2>&1; rcc=$?
confere "conferir diz que está conforme" '[ "$rcc" = 0 ]' "rc=$rcc"

printf 'OggS o apt trocou\n' > "$SONS_SIS/Pop/stereo/notification/power-plug.oga"
conf_do_som meowsystem mocha conferir >/dev/null 2>&1; rcd=$?
confere "um apt que troca o arquivo é pego pelo conferir" '[ "$rcd" = 1 ]' "rc=$rcd"
conf_do_som meowsystem mocha aplicar >/dev/null 2>&1
confere "e o aplicar do pós-apt devolve o do pack" 'cmp -s "$PACK_SONS/notification/power-plug.oga" "$SONS_SIS/Pop/stereo/notification/power-plug.oga"'
confere "guardando o novo de fábrica, o que o apt trouxe" 'grep -q "o apt trocou" "$ORIG/power-plug.original"'

conf_do_som meowsystem mocha remover >/dev/null 2>&1
confere "remover devolve os de fábrica" \
  'cmp -s "$T/sons-de-fabrica/Pop/stereo/alert/battery-low.oga" "$SONS_SIS/Pop/stereo/alert/battery-low.oga" && cmp -s "$T/sons-de-fabrica/freedesktop/stereo/dialog-warning.oga" "$SONS_SIS/freedesktop/stereo/dialog-warning.oga" && [ -z "$(ls -A "$ORIG")" ]'

rm -rf "$T/sons-de-fabrica"; cp -a "$SONS_SIS" "$T/sons-de-fabrica"

printf '\n--- 4. a ponte recusa o que não está na lista ---\n'
verbo() { printf '%b' "$2" | env -i PATH="$FALSO:/usr/bin:/bin" bash "$PONTE" "$1" 2>&1; }
verbo som 'rm-rf\nOggS x' >/dev/null; r1=$?
verbo som '../../etc/passwd\nOggS x' >/dev/null; r2=$?
verbo som 'complete\nnao e ogg' >/dev/null; r3=$?
verbo som 'complete\n' >/dev/null; r4=$?
verbo som-padrao 'message-new-email\n' >/dev/null; r5=$?
bash "$PONTE" som extra </dev/null >/dev/null 2>&1; r6=$?
confere "evento fora da lista, caminho, não-Ogg, vazio, argumento: tudo recusado" \
  '[ "$r1" != 0 ] && [ "$r2" != 0 ] && [ "$r3" != 0 ] && [ "$r4" != 0 ] && [ "$r5" != 0 ] && [ "$r6" != 0 ]' "$r1 $r2 $r3 $r4 $r5 $r6"
confere "nada do sistema mudou com as recusas" 'diff -r "$T/sons-de-fabrica" "$SONS_SIS"' "$(diff -r "$T/sons-de-fabrica" "$SONS_SIS" 2>&1 | head)"
big="$T/grande.oga"; { printf 'OggS'; head -c 1100000 /dev/zero; } > "$big"
{ echo complete; cat "$big"; } | env -i PATH="$FALSO:/usr/bin:/bin" bash "$PONTE" som >/dev/null 2>&1; r7=$?
confere "som acima de 1 MB é recusado" '[ "$r7" != 0 ] && diff -r "$T/sons-de-fabrica" "$SONS_SIS" >/dev/null'
confere "a regra do sudo libera os dois verbos novos, sem curinga" \
  'SUDO_USER=alguem bash "$RAIZ/scripts/ponte_root.sh" regra-sudo | grep -q "ponte_root.sh som, " && SUDO_USER=alguem bash "$RAIZ/scripts/ponte_root.sh" regra-sudo | grep -q "ponte_root.sh som-padrao, " && ! SUDO_USER=alguem bash "$RAIZ/scripts/ponte_root.sh" regra-sudo | grep -q "som \*"'

printf '\n--- 5. sem a ponte: avisa, não troca nada, não falha ---\n'
touch "$T/sem-ponte"
conf_do_som meowsystem mocha aplicar >"$T/a3.txt" 2>&1; rc3=$?
confere "o aplicar não falha, avisa da ponte e deixa o sistema como estava" \
  '[ "$rc3" -le 1 ] && grep -q "ponte" "$T/a3.txt" && diff -r "$T/sons-de-fabrica" "$SONS_SIS" >/dev/null' "rc=$rc3 $(cat "$T/a3.txt")"
rm -f "$T/sem-ponte"

printf '\n--- 6. o tema de som já no lugar não vira «Restaurar» ---\n'
conf_do_som meowsystem mocha aplicar >/dev/null 2>&1
rm -rf "$T/guardados"; mkdir -p "$T/guardados"
som meowsystem mocha env MEOW_BACKUPS="$T/guardados" bash "$RAIZ/scripts/som.sh" aplicar >"$T/a6.txt" 2>&1; rc6=$?
confere "a segunda passada sai conforme (rc 0)" '[ "$rc6" = 0 ]' "rc=$rc6 $(cat "$T/a6.txt")"
confere "e não guarda nada para restaurar (tocados.tsv vazio ou ausente)" '[ ! -s "$T/guardados/tocados.tsv" ]' "$(cat "$T/guardados/tocados.tsv" 2>&1)"
rm -rf "$CASA/.local/share/sounds/MeowSystem-Sons"
som meowsystem mocha env MEOW_BACKUPS="$T/guardados" bash "$RAIZ/scripts/som.sh" aplicar >/dev/null 2>&1
confere "com o tema de som faltando, a pasta é guardada" 'grep -q "MeowSystem-Sons" "$T/guardados/tocados.tsv"' "$(cat "$T/guardados/tocados.tsv" 2>&1)"

printf '\n'
[ "$falhas" = 0 ] && { echo "sons-do-pack: tudo certo"; exit 0; }
echo "sons-do-pack: $falhas falha(s)"; exit 1

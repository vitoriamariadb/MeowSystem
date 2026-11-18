#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1"; fi; }

mkdir -p "$T/bin" "$T/casa/.config/cosmic/com.system76.CosmicPanel.Panel/v1"
CFG="$T/casa/.config/cosmic/com.system76.CosmicPanel.Panel/v1"
cat > "$T/bin/pgrep" <<FIM
#!/bin/sh
case "\$*" in
  *cosmic-applet-notifications*) [ -f "$T/applet-vivo" ] && echo 4242 && exit 0; exit 1 ;;
  *cosmic-session*) exit 1 ;;
  *cosmic-panel*) [ -f "$T/painel-vivo" ] && echo 777 && exit 0; exit 1 ;;
esac
exit 1
FIM
cat > "$T/bin/ps" <<FIM
#!/bin/sh
cat "$T/vida"
FIM
cat > "$T/bin/journalctl" <<FIM
#!/bin/sh
case "\$*" in
  *_PID=777*) cat "$T/journal-pid" 2>/dev/null ;;
  *--since*) echo "\$*" >> "$T/since.log"; cat "$T/journal-sessao" 2>/dev/null ;;
esac
exit 0
FIM
cat > "$T/bin/date" <<FIM
#!/bin/sh
if [ "\$1" = "+%s" ]; then cat "$T/relogio"; exit 0; fi
exec /bin/date "\$@"
FIM
cat > "$T/bin/sleep" <<FIM
#!/bin/sh
r=\$(cat "$T/relogio"); r=\$((r + \$1)); echo "\$r" > "$T/relogio"
[ "\$r" -ge "\$(cat "$T/fim")" ] && kill -TERM "\$PPID"
exit 0
FIM
cat > "$T/bin/notify-send" <<FIM
#!/bin/sh
echo "\$*" >> "$T/avisos.log"
FIM
chmod 755 "$T/bin/"*
echo 1800000000 > "$T/relogio"

fantasma() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/casa" NO_COLOR=1 MEOW_PAINEL_BASE="$T/casa/.config/cosmic" \
    bash -c 'source "$0/lib/comum.sh"; source "$0/lib/painel.sh"; meow_painel_fantasma' "$RAIZ"
}
limpo() {
  rm -f "$T/journal-pid" "$T/journal-sessao" "$T/applet-vivo" "$CFG/plugins_wings" "$CFG/plugins_center"
  touch "$T/painel-vivo"; echo 1000 > "$T/vida"
}
laco_por() {
  echo 1800000000 > "$T/relogio"; echo $((1800000000 + $1)) > "$T/fim"
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/casa" NO_COLOR=1 MEOW_PAINEL_BASE="$T/casa/.config/cosmic" \
      MEOW_ESTADO="$T/casa/.local/state/meowsystem" XDG_RUNTIME_DIR="$2" \
      timeout 60 bash "$RAIZ/scripts/painel.sh" laco > "$T/laco.log" 2>&1
  grep -c 'reciclando' "$T/laco.log"
}
painel_com() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/casa" NO_COLOR=1 MEOW_PAINEL_BASE="$T/casa/.config/cosmic" \
      MEOW_ESTADO="$T/casa/.local/state/meowsystem" XDG_RUNTIME_DIR="$1" \
      bash "$RAIZ/scripts/painel.sh" "$2" 2>&1
}
enxurrada_de_raio() {
  local i
  for i in $(seq 1 "$1"); do
    printf 'cosmic-session: cosmic_corner_radius_layer_v1#51: error 1: corner radius too large\n'
  done > "$T/journal-sessao"
}

printf '\n1. o painel saudável não é fantasma\n'
limpo
printf 'Some(([], ["com.system76.CosmicAppletNotifications"]))\n' > "$CFG/plugins_wings"; touch "$T/applet-vivo"
printf 'cosmic-panel: applet carregado\n' > "$T/journal-pid"
printf 'cosmic-session: tudo em ordem\n' > "$T/journal-sessao"
fantasma; rc=$?
confere "painel velho, applet vivo, journal limpo: não é fantasma" '[ "$rc" = 1 ]'
rm -f "$T/painel-vivo"; fantasma; rc=$?
confere "sem cosmic-panel, não é fantasma" '[ "$rc" = 1 ]'
limpo; echo 10 > "$T/vida"; printf "Can't start notifications applet without a connection\n" > "$T/journal-pid"
fantasma; rc=$?
confere "painel com menos de 20 s não é julgado" '[ "$rc" = 1 ]'

printf '\n2. cada sinal, sozinho, dá fantasma\n'
limpo; printf "cosmic-panel: Can't start notifications applet without a connection\n" > "$T/journal-pid"
fantasma; rc=$?
confere "sinal 1: notificações sem conexão no _PID, com o painel velho" '[ "$rc" = 0 ]'
limpo; printf 'cosmic-panel: Failed to connect to the notifications daemon\n' > "$T/journal-pid"
fantasma; rc=$?
confere "sinal 1: a outra frase também" '[ "$rc" = 0 ]'

limpo; echo 120 > "$T/vida"
printf 'Some((["com.system76.CosmicAppletNotifications"], []))\n' > "$CFG/plugins_center"
fantasma; rc=$?
confere "sinal 2: o applet de notificações na barra, sem processo, com o painel recém-nascido" '[ "$rc" = 0 ]'
echo 1000 > "$T/vida"; fantasma; rc=$?
confere "sinal 2 com o painel velho não é fantasma" '[ "$rc" = 1 ]'
echo 120 > "$T/vida"; touch "$T/applet-vivo"; fantasma; rc=$?
confere "sinal 2 com o applet vivo não é fantasma" '[ "$rc" = 1 ]'
rm -f "$T/applet-vivo" "$CFG/plugins_center"; fantasma; rc=$?
confere "sinal 2 sem o applet na barra não é fantasma" '[ "$rc" = 1 ]'

limpo; printf 'cosmic-panel: Failed to render, error: EGL failed to allocate resources for the requested operation.\n' > "$T/journal-pid"
fantasma; rc=$?
confere "«Failed to render» sozinho no _PID, como no boot saudável de 16/11, não é fantasma" '[ "$rc" = 1 ]'
enxurrada_de_raio 20; fantasma; rc=$?
confere "sinal 3: render no _PID com a enxurrada de raio (20 linhas) desde o nascimento" '[ "$rc" = 0 ]'
enxurrada_de_raio 19; fantasma; rc=$?
confere "19 linhas de raio não são enxurrada" '[ "$rc" = 1 ]'
limpo; printf 'cosmic-panel: Erroneous EGL call did not set EGLError\n' > "$T/journal-pid"; enxurrada_de_raio 20
fantasma; rc=$?
confere "sinal 3: o EGL no _PID com a enxurrada também" '[ "$rc" = 0 ]'

limpo; : > "$T/since.log"
printf 'cosmic-session: xdg_popup#551: error 0: tried to grab after being mapped\n' > "$T/journal-sessao"
fantasma; rc=$?
confere "sinal 4: o erro de protocolo no journal da sessão, fora do _PID" '[ "$rc" = 0 ]'
confere "e o recorte é desde o nascimento do painel" "grep -q -- \"--since $(/bin/date -d @$((1800000000 - 1000)) '+%Y-%m-%d %H:%M:%S')\" \"$T/since.log\""
limpo; printf 'cosmic-session: wl_surface#12: error 2: buffer\n' > "$T/journal-sessao"
fantasma; rc=$?
confere "sinal 4: wl_surface com erro também" '[ "$rc" = 0 ]'

printf '\n3. a carência do laço: um kill a cada 600 s, no máximo\n'
limpo; printf "Can't start notifications applet without a connection\n" > "$T/journal-pid"
n="$(laco_por 1100 "$T/run")"
confere "em 1100 s de fantasma contínuo, duas reciclagens (0, 600), e não 110" '[ "$n" = 2 ]'

printf '\n4. o teto do boot: duas reciclagens, depois um aviso só\n'
limpo; printf "Can't start notifications applet without a connection\n" > "$T/journal-pid"; : > "$T/avisos.log"
n="$(laco_por 2500 "$T/run-teto")"
confere "em 2500 s de fantasma contínuo, a terceira detecção (1200) e as seguintes não reciclam: duas, e não cinco" '[ "$n" = 2 ]'
confere "e o aviso sai uma vez só, nas detecções 3, 4 e 5" '[ "$(wc -l < "$T/avisos.log")" = 1 ]'
confere "o aviso é curto e diz que desistiu" 'grep -q "desisti" "$T/avisos.log"'
n="$(laco_por 700 "$T/run-teto")"; m="$(laco_por 700 "$T/run-boot-novo")"
confere "o laço que volta no mesmo boot não recicla nem avisa de novo; num boot novo (runtime nova) o contador zera e recicla" \
  '[ "$n" = 0 ] && [ "$(wc -l < "$T/avisos.log")" = 1 ] && [ "$m" = 2 ]'

printf '\n5. o boot saudável com «Failed to render» sozinho não recicla\n'
limpo; : > "$T/avisos.log"
printf 'Some(([], ["com.system76.CosmicAppletNotifications"]))\n' > "$CFG/plugins_wings"; touch "$T/applet-vivo"
printf 'cosmic-panel: Failed to render, error: EGL failed to allocate resources for the requested operation.\n' > "$T/journal-pid"
n="$(laco_por 1300 "$T/run-saudavel")"
confere "em 1300 s com «Failed to render» no _PID e nada mais, nenhuma reciclagem" '[ "$n" = 0 ]'

printf '\n6. o estado e o doctor contam as reciclagens do boot\n'
limpo; printf "Can't start notifications applet without a connection\n" > "$T/journal-pid"
saida="$(painel_com "$T/run-teto" estado)"
confere "meow painel estado: «reciclagens : 2 de 2 neste boot — desisti até o próximo boot»" \
  'grep -qx "reciclagens : 2 de 2 neste boot — desisti até o próximo boot" <<< "$saida"'
confere "e a frase não promete que o vigia a reinicia sozinho" '! grep -q "O vigia a reinicia sozinho" <<< "$saida"'
laco_por 500 "$T/run-uma" > /dev/null; saida="$(painel_com "$T/run-uma" estado)"
confere "num boot com uma reciclagem só, sem desistência" 'grep -qx "reciclagens : 1 de 2 neste boot" <<< "$saida"'
saida="$(painel_com "$T/run-vazia" estado)"
confere "num boot sem reciclagem, zero" 'grep -qx "reciclagens : 0 de 2 neste boot" <<< "$saida"'
sed '/^despachar "\$@"$/d' "$RAIZ/bin/meow" > "$T/meow-sem-despachar"
doctor() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/casa-doctor" NO_COLOR=1 MEOW_RAIZ="$RAIZ" XDG_RUNTIME_DIR="$1" \
      MEOW_PAINEL_BASE="$T/casa-doctor/.config/cosmic" XDG_CONFIG_HOME="$T/casa-doctor/.config" \
      bash -c 'source "$0"; chk_painel' "$T/meow-sem-despachar" 2>&1
}
saida="$(doctor "$T/run-teto")"; rc=$?
confere "o doctor abre o painel com o aviso de que o laço desistiu, sem divergência que o conserto não acerta" \
  '[ "$rc" = 0 ] && head -1 <<< "$saida" | grep -q "^ *!! .*desistiu"'
saida="$(doctor "$T/run-vazia")"
confere "num boot sem reciclagem o doctor do painel não fala delas" '! grep -qi "recicl" <<< "$saida"'

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'painel-fantasma: tudo verde\n'; exit 0; fi
printf 'painel-fantasma: %s falha(s)\n' "$falhas"; exit 1

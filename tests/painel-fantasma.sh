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

limpo; printf 'cosmic-panel: Erroneous EGL call did not set EGLError\n' > "$T/journal-pid"
fantasma; rc=$?
confere "sinal 3: render e EGL no _PID" '[ "$rc" = 0 ]'

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
echo 1800000000 > "$T/relogio"; echo 1800001300 > "$T/fim"
env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/casa" NO_COLOR=1 MEOW_PAINEL_BASE="$T/casa/.config/cosmic" \
    MEOW_ESTADO="$T/casa/.local/state/meowsystem" XDG_RUNTIME_DIR="$T/run" \
    timeout 60 bash "$RAIZ/scripts/painel.sh" laco > "$T/laco.log" 2>&1
n="$(grep -c 'reciclando' "$T/laco.log")"
confere "em 1300 s de fantasma contínuo, três reciclagens (0, 600, 1200), e não 130" '[ "$n" = 3 ]'

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'painel-fantasma: tudo verde\n'; exit 0; fi
printf 'painel-fantasma: %s falha(s)\n' "$falhas"; exit 1

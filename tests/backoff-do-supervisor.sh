#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
printf '#!/bin/sh\ncat "%s/journal"\n' "$T" > "$T/bin/journalctl"; chmod 755 "$T/bin/journalctl"
falhas=0
medir() { PATH="$T/bin:$PATH" HOME="$T" bash -c ". '$RAIZ/lib/comum.sh'; . '$RAIZ/lib/painel.sh'; meow_painel_espera_supervisor"; }
caso() {
  local veio; veio="$(medir)"
  if [ "$veio" = "$2" ]; then printf '  ok    %s\n' "$1"; else printf '  FALHA %s (esperado %s, veio %s)\n' "$1" "${2:-<nada>}" "${veio:-<nada>}"; falhas=$((falhas+1)); fi
}

cat > "$T/journal" <<'FIM'
out 09 17:26:01 nitro-5 cosmic-session[4525]: sleeping for 1ms before restarting process cosmic-panel (restart 0)
out 09 17:26:01 nitro-5 cosmic-session[4525]: restarted process ' DISPLAY=:1 cosmic-panel ', now at 1 restarts
out 09 18:00:11 nitro-5 cosmic-session[4525]: sleeping for 4ms before restarting process cosmic-panel (restart 1)
out 09 18:00:11 nitro-5 cosmic-session[4525]: restarted process ' DISPLAY=:1 cosmic-panel ', now at 2 restarts
FIM
caso "formato de hoje: a última espera, em ms" 4

cat > "$T/journal" <<'FIM'
out 10 09:00:00 nitro-5 cosmic-session[4525]: backoff 4096 ms, then respawn cosmic-panel
out 10 09:00:04 nitro-5 cosmic-session[4525]: Restarted cosmic-panel (attempt 3)
FIM
caso "formato que mudou: nao-medida" nao-medida

printf 'out 10 09:00:00 nitro-5 cosmic-session[4525]: launch_pad started\n' > "$T/journal"
caso "boot sem reinício: nada" ""

cat > "$T/journal" <<'FIM'
out 10 09:00:00 nitro-5 cosmic-session[4525]: backoff 4096 ms, then respawn cosmic-panel
out 10 09:00:04 nitro-5 cosmic-session[4525]: Restarted cosmic-panel (attempt 3)
FIM
mkdir -p "$T/casa-rec"
HOME="$T/casa-rec" sleep 30 & PAINEL_FALSO=$!
printf '#!/bin/sh\ncase "$*" in *cosmic-panel*) echo %s ;; *) exit 1 ;; esac\n' "$PAINEL_FALSO" > "$T/bin/pgrep"
cat > "$T/bin/systemctl" <<FIM
#!/bin/sh
case "\$*" in
  *is-active*) [ -f "$T/armado" ] ;;
  *start*) echo "\$*" >> "$T/systemctl.log"; : > "$T/armado" ;;
  *) exit 1 ;;
esac
FIM
chmod 755 "$T/bin/pgrep" "$T/bin/systemctl"
saida="$(PATH="$T/bin:$PATH" HOME="$T/casa-rec" NO_COLOR=1 "$RAIZ/scripts/painel.sh" reciclar 2>&1)"; rc=$?
sleep 0.2
if [ "$rc" = 0 ] && grep -q 'start meow-painel.service' "$T/systemctl.log" 2>/dev/null \
   && ! kill -0 "$PAINEL_FALSO" 2>/dev/null; then
  printf '  ok    supervisor parado e espera não medida: o reciclo arma o supervisor e recicla\n'
else
  printf '  FALHA o reciclo não armou o supervisor (rc=%s): %s\n' "$rc" "$(printf '%s' "$saida" | tail -2 | tr '\n' ' ')"
  falhas=$((falhas+1))
fi
kill "$PAINEL_FALSO" 2>/dev/null

echo
if [ "$falhas" = 0 ]; then echo "backoff-do-supervisor: tudo certo"; exit 0; fi
echo "backoff-do-supervisor: $falhas falha(s)"; exit 1

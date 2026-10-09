#!/usr/bin/env bash
# backoff-do-supervisor.sh — a espera do cosmic-session é medida, ou dita não
# medida, e nunca confundida com "nunca falhou" (P76).
#
# Um `journalctl` falso devolve três journals: o formato de hoje (medido no
# 1.9 e no 1.10 em 09/10/2026), um formato que mudou (o painel reiniciou e a
# frase do `sleeping for … ms` sumiu) e um boot sem reinício nenhum. O
# `meow_painel_espera_supervisor` do lib/painel.sh tem de devolver, nessa
# ordem: os ms, `nao-medida` e nada. Sem sessão, sem COSMIC, sem escrever.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin"
printf '#!/bin/sh\ncat "%s/journal"\n' "$T" > "$T/bin/journalctl"; chmod 755 "$T/bin/journalctl"
falhas=0
medir() { PATH="$T/bin:$PATH" HOME="$T" bash -c ". '$RAIZ/lib/comum.sh'; . '$RAIZ/lib/painel.sh'; meow_painel_espera_supervisor"; }
caso() { # $1 descrição $2 esperado
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

echo
if [ "$falhas" = 0 ]; then echo "backoff-do-supervisor: tudo certo"; exit 0; fi
echo "backoff-do-supervisor: $falhas falha(s)"; exit 1

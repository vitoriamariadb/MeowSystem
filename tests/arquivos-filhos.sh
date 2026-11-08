#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/casa" "$TMP/falso"
cat > "$TMP/falso/systemctl" <<'FIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$MEOW_TESTE_REGISTRO"
FIM
chmod +x "$TMP/falso/systemctl"
DROPIN="$TMP/casa/.config/systemd/user/app-com.system76.CosmicFiles@.service.d/meowsystem-filhos-sobrevivem.conf"

rodar() {
  env -u XDG_CONFIG_HOME -u XDG_STATE_HOME HOME="$TMP/casa" PATH="$TMP/falso:$PATH" NO_COLOR=1 \
    MEOW_TESTE_REGISTRO="$TMP/registro" "$RAIZ/scripts/arquivos_filhos.sh" "$@" >/dev/null 2>&1
}

rodar --conferir; rc=$?
[ "$rc" = 1 ] && [ ! -e "$DROPIN" ] && ok "conferir acusa e não escreve" || falha "conferir: rc=$rc"

rodar aplicar; rc=$?
if [ "$rc" = 1 ] && grep -qx 'KillMode=process' "$DROPIN" 2>/dev/null; then ok "aplicar escreve KillMode=process"
else falha "aplicar: rc=$rc"; fi
grep -qx -- '--user daemon-reload' "$TMP/registro" 2>/dev/null && ok "recarrega o systemd do usuário" \
  || falha "não chamou systemctl --user daemon-reload"

antes="$(stat -c %Y "$DROPIN")"; : > "$TMP/registro"
sleep 1; rodar aplicar; rc=$?
if [ "$rc" = 0 ] && [ "$(stat -c %Y "$DROPIN")" = "$antes" ] && [ ! -s "$TMP/registro" ]; then
  ok "segunda passada não escreve nada"
else falha "segunda passada: rc=$rc"; fi

grep -q 'arquivos_filhos.sh' "$RAIZ/install.sh" && ok "o install chama o passo" || falha "o install não chama o passo"
grep -qE '^VERIFICAVEIS=.* arquivosfilhos( |\))' "$RAIZ/bin/meow" && ok "o doctor confere o passo" \
  || falha "o doctor não confere o passo"

exit "$falhas"

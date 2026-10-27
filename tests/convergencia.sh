#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$(mktemp -d)"; FALSO="$(mktemp -d)"; trap 'rm -rf "$H" "$FALSO"' EXIT

cat > "$FALSO/sudo" <<'FIM'
#!/bin/sh
printf 'sudo: recusado pelo tests/convergencia.sh\n' >&2
exit 1
FIM
chmod 755 "$FALSO/sudo"

cat > "$FALSO/systemctl" <<FIM
#!/bin/bash
case " \$* " in
  *" is-active "*|*" is-enabled "*|*" is-failed "*|*" show "*|*" status "*|*" cat "*\
  |*" list-units "*|*" list-unit-files "*|*" list-timers "*|*" show-environment "*\
  |*" get-default "*|*" --version "*)
    IFS=: read -ra _dirs <<< "\$PATH"
    for _d in "\${_dirs[@]}"; do
      [ "\$_d" = "$FALSO" ] && continue
      [ -x "\$_d/systemctl" ] && exec "\$_d/systemctl" "\$@"
    done
    exit 1 ;;
esac
printf 'systemctl: recusado pelo tests/convergencia.sh (%s)\n' "\$*" >&2
exit 1
FIM
chmod 755 "$FALSO/systemctl"

PASSAGENS="${PASSAGENS:-3}"

correr() {
  env -i PATH="$FALSO:$PATH" HOME="$H" USER="${USER:-t}" \
    MEOW_IGNORA_DESKTOP=1 NO_COLOR=1 MEOW_PONTE=/nao/existe \
    bash "$RAIZ/install.sh" 2>&1
}

saida=""
for i in $(seq 1 "$PASSAGENS"); do
  saida="$(correr)"
  printf 'passagem %s: %s\n' "$i" \
    "$(printf '%s' "$saida" | grep 'mexeu:' || printf 'nada mudou')"
done

if printf '%s' "$saida" | grep -q 'mexeu:'; then
  printf 'FALHOU: ainda mexia na passagem %s — alguma etapa não é idempotente\n' \
    "$PASSAGENS" >&2
  exit 1
fi
printf 'ok: convergiu em %s passagens\n' "$PASSAGENS"

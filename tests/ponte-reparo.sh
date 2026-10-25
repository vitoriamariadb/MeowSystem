#!/usr/bin/env bash
# ponte-reparo.sh — a ponte root se repõe da reserva, sem senha, e só da reserva.
#
# Nada aqui roda como root. O sistema é uma pasta de brinquedo (`$SIS`): a etapa
# do install.sh, o reparo e o doctor rodam em cópias com os destinos trocados.
# `sudo`, `visudo` e `systemctl` são falsos; o `sudo` só executa o que a cópia
# pediu, sem `-o root`, e nunca o sudo de verdade.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1" "${3:-}"; fi; }

SIS="$T/sis"; CASA="$T/casa"; FALSO="$T/falso"
BASE="$SIS/usr/local/lib/meowsystem"; REGRA="$SIS/etc/sudoers.d/49-meowsystem-ponte"
SUDO_LOG="$T/sudo.log"; SYSTEMCTL_LOG="$T/systemctl.log"
mkdir -p "$SIS/usr/local/lib" "$SIS/etc/sudoers.d" "$SIS/etc/systemd/system" \
         "$SIS/etc/polkit-1/rules.d" "$CASA" "$FALSO"
: > "$SUDO_LOG"; : > "$SYSTEMCTL_LOG"

# Os destinos de root, trocados pela pasta de brinquedo.
trocar() {
  sed -e "s#/usr/local/lib/meowsystem#$SIS/usr/local/lib/meowsystem#g" \
      -e "s#/etc/sudoers.d#$SIS/etc/sudoers.d#g" \
      -e "s#/etc/systemd/system#$SIS/etc/systemd/system#g" \
      -e "s#/etc/polkit-1#$SIS/etc/polkit-1#g"
}

# O sudo falso: o `estado` da ponte responde pelo arquivo de brinquedo; o resto
# roda como quem chamou, sem `-o`/`-g`, e fica no registro.
cat > "$FALSO/sudo" <<FIM
#!/bin/bash
[ "\${1:-}" = -n ] && shift
case "\${1:-}" in true|-v) exit 0 ;; esac
if [ "\$1" = "$BASE/ponte_root.sh" ]; then
  [ "\${2:-}" = estado ] && [ -x "$BASE/ponte_root.sh" ] && [ -f "$REGRA" ] || exit 1
  printf 'regra_md5=%s\n' "\$(md5sum < "$REGRA" | cut -d' ' -f1)"
  exit 0
fi
printf '%s\n' "\$*" >> "$SUDO_LOG"
a=(); pula=0
for x in "\$@"; do
  [ "\$pula" = 1 ] && { pula=0; continue; }
  case "\$x" in -o|-g) pula=1; continue ;; esac
  a+=("\$x")
done
exec "\${a[@]}"
FIM
# O visudo falso reprova a regra que diz QUEBRADA.
cat > "$FALSO/visudo" <<'FIM'
#!/bin/sh
for a in "$@"; do f="$a"; done
grep -q QUEBRADA "$f" && exit 1
exit 0
FIM
cat > "$FALSO/systemctl" <<FIM
#!/bin/sh
printf '%s\n' "\$*" >> "$SYSTEMCTL_LOG"
exit 0
FIM
chmod 755 "$FALSO"/*

ETAPA="$T/etapa.sh"
sed -n '/^etapa_ponte_root() {/,/^}/p' "$RAIZ/install.sh" | trocar > "$ETAPA"

# A etapa do install.sh, numa casa e num sistema de brinquedo.
etapa() {
  env -i PATH="$FALSO:/usr/bin:/bin" HOME="$CASA" USER="$(id -un)" MEOW_RAIZ="$RAIZ" \
         PONTE_ROOT="${1:-sim}" ETAPA="$ETAPA" bash -c '
    . "$MEOW_RAIZ/lib/comum.sh"; passo() { :; }
    . "$ETAPA"; etapa_ponte_root' 2>&1
}

printf '\n--- 1. o install guarda a reserva: ponte e regra, 0700, com o sha256 ao lado ---\n'
saida="$(etapa)"; rc=$?
confere "a primeira passada instala (rc=1)" '[ "$rc" = 1 ]' "$saida"
confere "a reserva é uma pasta 0700" '[ "$(stat -c %a "$BASE/reserva" 2>/dev/null)" = 700 ]'
confere "a ponte da reserva é a do repositório" 'cmp -s "$RAIZ/scripts/ponte_root.sh" "$BASE/reserva/ponte_root.sh"'
confere "a regra da reserva é a regra instalada" 'cmp -s "$REGRA" "$BASE/reserva/49-meowsystem-ponte"'
confere "o sha256 da reserva fica ao lado, legível, e confere" \
  '[ "$(stat -c %a "$BASE/reserva.sha256" 2>/dev/null)" = 644 ] && (cd "$BASE/reserva" && sha256sum --check --strict --quiet "$BASE/reserva.sha256")'
confere "o sha256 nomeia só a ponte e a regra" \
  '[ "$(awk "{print \$2}" "$BASE/reserva.sha256" | sort | tr "\n" " ")" = "49-meowsystem-ponte ponte_root.sh " ]'
: > "$SUDO_LOG"
saida="$(etapa)"; rc=$?
confere "a segunda passada não escreve nada (rc=0, nenhum sudo)" '[ "$rc" = 0 ] && [ ! -s "$SUDO_LOG" ]' "$saida
$(cat "$SUDO_LOG")"
rm -rf "$BASE/reserva" "$BASE/reserva.sha256"
saida="$(etapa)"; rc=$?
confere "sem a reserva (install antigo), a etapa a põe de volta" \
  '[ "$rc" = 1 ] && [ -f "$BASE/reserva/ponte_root.sh" ] && [ -f "$BASE/reserva.sha256" ]' "$saida"

printf '\n'
if [ "$falhas" -gt 0 ]; then printf 'FALHOU: %d\n' "$falhas"; exit 1; fi
printf 'tudo ok\n'

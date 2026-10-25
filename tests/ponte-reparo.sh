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

printf '\n--- 2. o reparo: uma unidade oneshot, sem argumento, que só lê a reserva ---\n'
UNIDADE_REPO="$RAIZ/assets/ponte/meowsystem-ponte-reparo.service"
UNIDADE="$SIS/etc/systemd/system/meowsystem-ponte-reparo.service"
REPARO_REPO="$RAIZ/scripts/reparar_ponte.sh"
: > "$SYSTEMCTL_LOG"
rm -f "$BASE/reserva.sha256"
saida="$(etapa)"; rc=$?
confere "a etapa instala o reparo, 0755, igual ao do repositório" \
  '[ "$rc" = 1 ] && cmp -s "$REPARO_REPO" "$BASE/reparar_ponte.sh" && [ "$(stat -c %a "$BASE/reparar_ponte.sh")" = 755 ]' "$saida"
confere "a etapa instala a unidade, igual à do repositório, e relê o systemd" \
  'cmp -s "$UNIDADE_REPO" "$UNIDADE" && grep -qx "daemon-reload" "$SYSTEMCTL_LOG"'
: > "$SUDO_LOG"
saida="$(etapa)"; rc=$?
confere "com tudo no lugar, a segunda passada não escreve nada" '[ "$rc" = 0 ] && [ ! -s "$SUDO_LOG" ]' "$saida"
rm -f "$UNIDADE"
saida="$(etapa)"; rc=$?
confere "sem a unidade, a etapa a põe de volta" '[ "$rc" = 1 ] && cmp -s "$UNIDADE_REPO" "$UNIDADE"' "$saida"

execs="$(grep -c '^ExecStart' "$UNIDADE_REPO" 2>/dev/null)"
confere "a unidade é oneshot, com um ExecStart só" \
  'grep -qx "Type=oneshot" "$UNIDADE_REPO" && [ "$execs" = 1 ]'
confere "o ExecStart é o reparo instalado, sem argumento nenhum" \
  '[ "$(sed -n "s/^ExecStart=//p" "$UNIDADE_REPO")" = /usr/local/lib/meowsystem/reparar_ponte.sh ]'
confere "a unidade não é modelo (sem @, sem %) e não lê ambiente de fora" \
  '[ -f "$UNIDADE_REPO" ] && ! grep -q "%" "$UNIDADE_REPO" && ! grep -qE "^(Environment|EnvironmentFile|PassEnvironment|ExecStartPre|ExecStartPost)=" "$UNIDADE_REPO" \
   && case "${UNIDADE_REPO##*/}" in *@*) false ;; esac'
confere "a unidade não enxerga o HOME" 'grep -qx "ProtectHome=yes" "$UNIDADE_REPO"'
# O código sem os comentários e fora das funções de uma linha (o `$1` delas é
# a mensagem do próprio script): argumento, variável de quem chama, `read`, `source`.
de_fora() { sed 's/#.*$//' "$REPARO_REPO" | grep -vE '^[a-z_]+\(\) \{.*\}$' | grep -nE '\$[@*0-9#]|\$\{[@*0-9#]|HOME|MEOW_|USER|SUDO_|getopts|\bread\b|\bsource\b|^\s*\. '; }
confere "o reparo não lê argumento, ambiente de quem chama, nem o repositório" \
  '[ -f "$REPARO_REPO" ] && ! de_fora >/dev/null' "$(de_fora 2>&1)"

# A cópia do reparo: a raiz de brinquedo e o PATH dos falsos. O resto é o
# código de verdade.
REPARO="$T/reparar_ponte.sh"
cat > "$FALSO/logger" <<'FIM'
#!/bin/sh
exit 0
FIM
chmod 755 "$FALSO/logger"
sed -e "s#^R=\"\"\$#R=\"$SIS\"#" -e "s#^export PATH=.*#export PATH=\"$FALSO:/usr/bin:/bin\"#" \
  "$REPARO_REPO" > "$REPARO" 2>/dev/null; chmod 755 "$REPARO"
confere "a cópia do reparo trocou a raiz e o PATH (uma linha de cada)" \
  '[ "$(grep -c "^R=\"$SIS\"\$" "$REPARO")" = 1 ] && [ "$(grep -c "^export PATH=\"$FALSO" "$REPARO")" = 1 ]'
reparar() { env -i HOME=/nada MEOW_RAIZ=/nada bash "$REPARO" "$@" 2>&1; }

cp "$REGRA" "$T/regra.boa"
rm -f "$REGRA"
saida="$(reparar)"; rc=$?
confere "sem a regra, o reparo a repõe da reserva, 0440" \
  '[ "$rc" = 0 ] && cmp -s "$T/regra.boa" "$REGRA" && [ "$(stat -c %a "$REGRA")" = 440 ]' "$saida"
rm -f "$BASE/ponte_root.sh"
saida="$(reparar)"; rc=$?
confere "sem a ponte, o reparo a repõe, 0755" \
  '[ "$rc" = 0 ] && cmp -s "$BASE/reserva/ponte_root.sh" "$BASE/ponte_root.sh" && [ "$(stat -c %a "$BASE/ponte_root.sh")" = 755 ]' "$saida"
antes="$(stat -c %Y.%i "$REGRA" "$BASE/ponte_root.sh")"
saida="$(reparar)"; rc=$?
confere "com tudo no lugar, o reparo não reescreve nada" \
  '[ "$rc" = 0 ] && [ "$(stat -c %Y.%i "$REGRA" "$BASE/ponte_root.sh")" = "$antes" ]' "$saida"
rm -f "$REGRA"
saida="$(reparar /etc/shadow --qualquer)"; rc=$?
confere "argumento de quem chama não muda nada: repõe a mesma regra" '[ "$rc" = 0 ] && cmp -s "$T/regra.boa" "$REGRA"' "$saida"

rm -f "$REGRA"
cp "$BASE/reserva/ponte_root.sh" "$T/ponte.boa"
printf '\necho adulterada\n' >> "$BASE/reserva/ponte_root.sh"
rm -f "$BASE/ponte_root.sh"
saida="$(reparar)"; rc=$?
confere "reserva adulterada: sai 4 e nada volta" \
  '[ "$rc" = 4 ] && [ ! -e "$REGRA" ] && [ ! -e "$BASE/ponte_root.sh" ]' "$saida"
cp "$T/ponte.boa" "$BASE/reserva/ponte_root.sh"
cp "$BASE/reserva.sha256" "$T/somas.boas"
printf '%s  ../../../etc/passwd\n' "$(sha256sum < /etc/passwd | cut -d' ' -f1)" >> "$BASE/reserva.sha256"
saida="$(reparar)"; rc=$?
confere "um nome a mais no sha256: sai 4 e nada volta" '[ "$rc" = 4 ] && [ ! -e "$REGRA" ]' "$saida"
cp "$T/somas.boas" "$BASE/reserva.sha256"
cp "$BASE/reserva/49-meowsystem-ponte" "$T/regra.reserva"
chmod u+w "$BASE/reserva/49-meowsystem-ponte"; printf 'QUEBRADA\n' >> "$BASE/reserva/49-meowsystem-ponte"
( cd "$BASE/reserva" && sha256sum ponte_root.sh 49-meowsystem-ponte ) > "$BASE/reserva.sha256"
saida="$(reparar)"; rc=$?
confere "a regra que o visudo reprova não entra: sai 5" '[ "$rc" = 5 ] && [ ! -e "$REGRA" ]' "$saida"
cp -f "$T/regra.reserva" "$BASE/reserva/49-meowsystem-ponte"
cp "$T/somas.boas" "$BASE/reserva.sha256"
mv "$BASE/reserva" "$T/reserva.guardada"
saida="$(reparar)"; rc=$?
confere "sem reserva: sai 3 e nada volta" '[ "$rc" = 3 ] && [ ! -e "$REGRA" ]' "$saida"
mv "$T/reserva.guardada" "$BASE/reserva"
saida="$(reparar)"; rc=$?
confere "com a reserva de volta, tudo volta" '[ "$rc" = 0 ] && [ -f "$REGRA" ] && [ -x "$BASE/ponte_root.sh" ]' "$saida"

printf '\n'
if [ "$falhas" -gt 0 ]; then printf 'FALHOU: %d\n' "$falhas"; exit 1; fi
printf 'tudo ok\n'

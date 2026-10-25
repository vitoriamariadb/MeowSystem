#!/usr/bin/env bash
# ponte-so-reserva.sh — o que a ponte põe em root vem só da reserva do install.
#
# O clone é gravável por quem usa. O wrapper e o hook do apt e a completion do
# zsh viram root, e por isso só entram pela reserva que o install guardou com a
# senha (0700 root, com o sha256 ao lado). Editar o repositório e chamar o verbo
# sem senha não põe nada em root.
#
# Nada aqui roda como root. O sistema é uma pasta de brinquedo (`$SIS`), e a
# ponte, a etapa do install.sh e o doctor rodam em cópias com os destinos
# trocados. `sudo`, `visudo`, `systemctl` e `logger` são falsos; o `sudo` só
# executa o que a cópia pediu, sem `-o root`, e nunca o sudo de verdade.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1" "${3:-}"; fi; }

SIS="$T/sis"; CASA="$T/casa"; FALSO="$T/falso"; CLONE="$T/clone"
BASE="$SIS/usr/local/lib/meowsystem"; RESERVA="$BASE/reserva"; PECAS="$BASE/reserva-pecas.sha256"
REGRA="$SIS/etc/sudoers.d/49-meowsystem-ponte"
WRAPPER="$SIS/usr/local/sbin/meow-lancador-apt.sh"; HOOK="$SIS/etc/apt/apt.conf.d/99-meow-lancador"
COMPLETION="$SIS/usr/local/share/zsh/site-functions/_meow"
SUDO_LOG="$T/sudo.log"; PONTE_LOG="$T/ponte.log"
mkdir -p "$SIS/usr/local/lib" "$SIS/usr/local/sbin" "$SIS/etc/sudoers.d" "$SIS/etc/apt/apt.conf.d" \
         "$SIS/etc/systemd/system" "$SIS/etc/polkit-1/rules.d" "$SIS/usr/local/share/zsh/site-functions" \
         "$CASA" "$FALSO"
: > "$SUDO_LOG"; : > "$PONTE_LOG"

# O clone de quem usa: só o que a etapa da ponte lê. É ele que o teste adultera.
for f in scripts/ponte_root.sh scripts/reparar_ponte.sh scripts/meow-lancador-apt.sh \
         scripts/99-meow-lancador assets/ponte/meowsystem-ponte-reparo.service \
         assets/ponte/49-meowsystem-ponte-reparo.rules assets/zsh/_meow; do
  mkdir -p "$CLONE/${f%/*}"; cp "$RAIZ/$f" "$CLONE/$f"
done
cp -a "$CLONE" "$T/clone.limpo"
clone_limpo() { rm -rf "$CLONE"; cp -a "$T/clone.limpo" "$CLONE"; }

# Os destinos de root, trocados pela pasta de brinquedo.
trocar() {
  sed -e "s#/usr/local/lib/meowsystem#$SIS/usr/local/lib/meowsystem#g" \
      -e "s#/usr/local/sbin/meow-lancador-apt.sh#$WRAPPER#g" \
      -e "s#/usr/local/share/zsh/site-functions#$SIS/usr/local/share/zsh/site-functions#g" \
      -e "s#/etc/apt/apt.conf.d#$SIS/etc/apt/apt.conf.d#g" \
      -e "s#/etc/sudoers.d#$SIS/etc/sudoers.d#g" \
      -e "s#/etc/systemd/system#$SIS/etc/systemd/system#g" \
      -e "s#/etc/polkit-1#$SIS/etc/polkit-1#g"
}

# A ponte de brinquedo: a do repositório, com os destinos trocados, o PATH dos
# falsos e sem `-o root -g root`. O resto é o código de verdade.
PONTE_TOY="$T/ponte-brinquedo.sh"
sed -e "s#^export PATH=.*#export PATH=\"$FALSO:/usr/bin:/bin\"#" -e 's/ -o root -g root//g' \
  "$RAIZ/scripts/ponte_root.sh" | trocar > "$PONTE_TOY"
chmod 755 "$PONTE_TOY"

# O sudo falso: a ponte instalada vira a de brinquedo (a regra a libera sem
# senha); o resto roda como quem chamou, sem `-o`/`-g`, e fica no registro.
cat > "$FALSO/sudo" <<FIM
#!/bin/bash
[ "\${1:-}" = -n ] && shift
case "\${1:-}" in true|-v) exit 0 ;; esac
if [ "\$1" = "$BASE/ponte_root.sh" ]; then
  [ -x "$BASE/ponte_root.sh" ] && [ -f "$REGRA" ] || exit 1
  printf '%s\n' "\${2:-}" >> "$PONTE_LOG"
  exec bash "$PONTE_TOY" "\${2:-}"
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
printf '#!/bin/sh\nexit 0\n' > "$FALSO/visudo"
printf '#!/bin/sh\nexit 0\n' > "$FALSO/systemctl"
printf '#!/bin/sh\nexit 0\n' > "$FALSO/logger"
chmod 755 "$FALSO"/*

ETAPA="$T/etapa.sh"
for f in etapa_ponte_root etapa_lancador_apt; do
  sed -n "/^$f() {/,/^}/p" "$RAIZ/install.sh"
done | trocar > "$ETAPA"

# Uma etapa do install.sh, com o clone como repositório.
etapa() {   # $1 = etapa_ponte_root | etapa_lancador_apt
  env -i PATH="$FALSO:/usr/bin:/bin" HOME="$CASA" USER="$(id -un)" MEOW_RAIZ="$CLONE" \
         MEOW_PONTE="$BASE/ponte_root.sh" LANCADOR_SISTEMA=sim LIB="$RAIZ/lib/comum.sh" \
         ETAPA="$ETAPA" FUNCAO="$1" bash -c '
    . "$LIB"; passo() { :; }; pular_por_optin() { return 3; }
    . "$ETAPA"; "$FUNCAO"' 2>&1
}

# Um verbo da ponte instalada, como o painel e o doctor o chamam: sem senha.
verbo() { env -i PATH="$FALSO:/usr/bin:/bin" HOME="$CASA" sudo -n "$BASE/ponte_root.sh" "$1" </dev/null 2>&1; }

# O wrapper que o install preenche: o molde do clone com o clone, quem usa e a casa.
preenchido() { sed -e "s|@ACERVO@|$CLONE|g" -e "s|@USUARIA@|$(id -un)|g" -e "s|@LAR@|$CASA|g" "$1"; }

printf '\n--- 1. a reserva guarda tudo o que vira root, e os verbos copiam só dela ---\n'
saida="$(etapa etapa_ponte_root)"; rc=$?
confere "a primeira passada instala (rc=1)" '[ "$rc" = 1 ]' "$saida"
confere "a reserva tem o wrapper do apt já preenchido" \
  'preenchido "$CLONE/scripts/meow-lancador-apt.sh" | cmp -s - "$RESERVA/meow-lancador-apt.sh"'
confere "a reserva tem o hook do apt" 'cmp -s "$CLONE/scripts/99-meow-lancador" "$RESERVA/99-meow-lancador"'
confere "a reserva tem a completion" 'cmp -s "$CLONE/assets/zsh/_meow" "$RESERVA/_meow"'
confere "o sha256 das peças fica ao lado, legível, e confere" \
  '[ "$(stat -c %a "$PECAS" 2>/dev/null)" = 644 ] && (cd "$RESERVA" && sha256sum --check --strict --quiet "$PECAS")'
confere "o sha256 das peças nomeia só as três" \
  '[ "$(awk "{print \$2}" "$PECAS" | LC_ALL=C sort | tr "\n" " ")" = "99-meow-lancador _meow meow-lancador-apt.sh " ]'
confere "o sha256 da ponte continua nomeando só a ponte e a regra (o reparo não muda)" \
  '[ "$(awk "{print \$2}" "$BASE/reserva.sha256" | sort | tr "\n" " ")" = "49-meowsystem-ponte ponte_root.sh " ]'
: > "$SUDO_LOG"
saida="$(etapa etapa_ponte_root)"; rc=$?
confere "a segunda passada não escreve nada (rc=0, nenhum sudo)" '[ "$rc" = 0 ] && [ ! -s "$SUDO_LOG" ]' "$saida
$(cat "$SUDO_LOG")"
rm -f "$PECAS"
saida="$(etapa etapa_ponte_root)"; rc=$?
confere "sem o sha256 das peças (install antigo), a etapa as guarda" '[ "$rc" = 1 ] && [ -f "$PECAS" ]' "$saida"

# O repositório adulterado: o que quem usa pode editar sem senha.
printf '\ntouch %s/pwned-wrapper\n' "$T" >> "$CLONE/scripts/meow-lancador-apt.sh"
printf '\nDPkg::Post-Invoke { "touch %s/pwned-hook"; };\n' "$T" >> "$CLONE/scripts/99-meow-lancador"
printf '\ntouch %s/pwned-completion\n' "$T" >> "$CLONE/assets/zsh/_meow"
saida="$(verbo apt-hook-instalar)"; rc=$?
confere "repositório adulterado: apt-hook-instalar instala o wrapper da reserva" \
  '[ "$rc" = 0 ] && cmp -s "$RESERVA/meow-lancador-apt.sh" "$WRAPPER" && ! grep -q pwned "$WRAPPER"' "$saida"
confere "e o hook da reserva" 'cmp -s "$RESERVA/99-meow-lancador" "$HOOK" && ! grep -q pwned "$HOOK"'
saida="$(verbo completion-instalar)"; rc=$?
confere "repositório adulterado: completion-instalar instala a da reserva" \
  '[ "$rc" = 0 ] && cmp -s "$RESERVA/_meow" "$COMPLETION" && ! grep -q pwned "$COMPLETION"' "$saida"
clone_limpo

# A reserva adulterada: o sha256 não confere, e nada se instala.
rm -f "$WRAPPER" "$HOOK" "$COMPLETION"
cp "$RESERVA/meow-lancador-apt.sh" "$T/wrapper.bom"; cp "$RESERVA/_meow" "$T/completion.boa"
printf '\ntouch %s/pwned-reserva\n' "$T" >> "$RESERVA/meow-lancador-apt.sh"
printf '\ntouch %s/pwned-reserva\n' "$T" >> "$RESERVA/_meow"
saida="$(verbo apt-hook-instalar)"; rc=$?
confere "reserva adulterada: apt-hook-instalar sai 4 e não instala nada" \
  '[ "$rc" = 4 ] && [ ! -e "$WRAPPER" ] && [ ! -e "$HOOK" ]' "$saida"
saida="$(verbo completion-instalar)"; rc=$?
confere "reserva adulterada: completion-instalar sai 4 e não instala nada" \
  '[ "$rc" = 4 ] && [ ! -e "$COMPLETION" ]' "$saida"
cp -f "$T/wrapper.bom" "$RESERVA/meow-lancador-apt.sh"; cp -f "$T/completion.boa" "$RESERVA/_meow"

cp "$PECAS" "$T/pecas.boas"
printf '%s  ../../../etc/passwd\n' "$(sha256sum < /etc/passwd | cut -d' ' -f1)" >> "$PECAS"
saida="$(verbo completion-instalar)"; rc=$?
confere "um nome a mais no sha256 das peças: sai 4 e nada se instala" '[ "$rc" = 4 ] && [ ! -e "$COMPLETION" ]' "$saida"
cp -f "$T/pecas.boas" "$PECAS"

# Install antigo: a reserva sem as peças. O verbo não cai no repositório.
mv "$PECAS" "$T/pecas.guardadas"
saida="$(verbo apt-hook-instalar)"; rc=$?
confere "sem as peças na reserva: apt-hook-instalar sai 3 e não lê o repositório" \
  '[ "$rc" = 3 ] && [ ! -e "$WRAPPER" ] && [ ! -e "$HOOK" ]' "$saida"
saida="$(verbo completion-instalar)"; rc=$?
confere "sem as peças na reserva: completion-instalar sai 3" '[ "$rc" = 3 ] && [ ! -e "$COMPLETION" ]' "$saida"
mv "$T/pecas.guardadas" "$PECAS"

saida="$(verbo apt-hook-instalar)"; rc=$?
confere "com a reserva boa, o hook volta" '[ "$rc" = 0 ] && cmp -s "$RESERVA/99-meow-lancador" "$HOOK"' "$saida"
antes="$(stat -c %Y.%i "$WRAPPER" "$HOOK")"
saida="$(verbo apt-hook-instalar)"; rc=$?
confere "com tudo no lugar, o verbo não reescreve nada" \
  '[ "$rc" = 0 ] && [ "$(stat -c %Y.%i "$WRAPPER" "$HOOK")" = "$antes" ]' "$saida"

printf '\n--- 2. o repositório mais novo que a reserva entra no próximo «Instalar tudo» ---\n'
DOCTOR="$T/doctor.sh"
for f in _lancadorapt_igual_a_reserva chk_lancadorapt fix_lancadorapt; do
  sed -n "/^$f() {/,/^}/p" "$RAIZ/bin/meow"
done | trocar > "$DOCTOR"
doctor() {   # $1 = chk_lancadorapt | fix_lancadorapt
  env -i PATH="$FALSO:/usr/bin:/bin" HOME="$CASA" RAIZ="$CLONE" MEOW_RAIZ="$CLONE" \
         MEOW_PONTE="$BASE/ponte_root.sh" LANCADOR_SISTEMA=sim LIB="$RAIZ/lib/comum.sh" \
         DOCTOR="$DOCTOR" FUNCAO="$1" bash -c '. "$LIB"; . "$DOCTOR"; "$FUNCAO"' 2>&1
}
saida="$(doctor chk_lancadorapt)"; rc=$?
confere "hook e wrapper iguais à reserva e ao repositório: ok" '[ "$rc" = 0 ]' "$saida"
rm -f "$HOOK"
saida="$(doctor chk_lancadorapt)"; rc=$?
confere "sem o hook: divergente, e a ponte o repõe da reserva" '[ "$rc" = 1 ] && grep -q "reserva" <<< "$saida"' "$saida"
: > "$PONTE_LOG"
saida="$(doctor fix_lancadorapt)"; rc=$?
confere "o conserto repõe o hook da reserva, pela ponte" \
  '[ "$rc" = 1 ] && cmp -s "$RESERVA/99-meow-lancador" "$HOOK" && grep -qx apt-hook-instalar "$PONTE_LOG"' "$saida"

printf '\n# mudou no repositório\n' >> "$CLONE/scripts/meow-lancador-apt.sh"
saida="$(doctor chk_lancadorapt)"; rc=$?
confere "o wrapper mudou no repositório: pendência do install" \
  '[ "$rc" = 1 ] && grep -q "Instalar tudo" <<< "$saida"' "$saida"
: > "$PONTE_LOG"
saida="$(doctor fix_lancadorapt)"; rc=$?
confere "e o conserto não chama a ponte (sai 3)" \
  '[ "$rc" = 3 ] && ! grep -q apt-hook-instalar "$PONTE_LOG" && grep -q "Instalar tudo" <<< "$saida"' "$saida"
rm -f "$HOOK"
saida="$(doctor fix_lancadorapt)"; rc=$?
confere "sem o hook, o conserto repõe o da reserva, e o wrapper novo não entra" \
  '[ "$rc" = 1 ] && cmp -s "$RESERVA/99-meow-lancador" "$HOOK" && cmp -s "$RESERVA/meow-lancador-apt.sh" "$WRAPPER"' "$saida"
saida="$(doctor chk_lancadorapt)"; rc=$?
confere "e o doctor segue pedindo o install para o wrapper novo" '[ "$rc" = 1 ] && grep -q "Instalar tudo" <<< "$saida"' "$saida"

: > "$SUDO_LOG"
saida="$(etapa etapa_lancador_apt)"; rc=$?
confere "a etapa do hook, sem a senha da etapa da ponte, não promove o repositório (rc=3)" \
  '[ "$rc" = 3 ] && cmp -s "$RESERVA/meow-lancador-apt.sh" "$WRAPPER" && [ ! -s "$SUDO_LOG" ]' "$saida
$(cat "$SUDO_LOG")"
saida="$(etapa etapa_ponte_root)"; rc=$?
confere "com a senha, a etapa da ponte guarda o wrapper novo na reserva" \
  '[ "$rc" = 1 ] && preenchido "$CLONE/scripts/meow-lancador-apt.sh" | cmp -s - "$RESERVA/meow-lancador-apt.sh"' "$saida"
saida="$(etapa etapa_lancador_apt)"; rc=$?
confere "e a etapa do hook o instala pela ponte" \
  '[ "$rc" = 1 ] && preenchido "$CLONE/scripts/meow-lancador-apt.sh" | cmp -s - "$WRAPPER"' "$saida"
saida="$(etapa etapa_lancador_apt)"; rc=$?
confere "a segunda passada da etapa do hook não muda nada" '[ "$rc" = 0 ]' "$saida"
saida="$(doctor chk_lancadorapt)"; rc=$?
confere "e o doctor diz ok" '[ "$rc" = 0 ]' "$saida"

mv "$PECAS" "$T/pecas.guardadas"
rm -f "$HOOK"
saida="$(doctor chk_lancadorapt)"; rc=$?
confere "install antigo, sem as peças na reserva: o doctor pede o install" \
  '[ "$rc" = 1 ] && grep -q "Instalar tudo" <<< "$saida"' "$saida"
: > "$PONTE_LOG"
saida="$(doctor fix_lancadorapt)"; rc=$?
confere "e o conserto não chama a ponte (sai 3)" '[ "$rc" = 3 ] && [ ! -s "$PONTE_LOG" ] && [ ! -e "$HOOK" ]' "$saida"
mv "$T/pecas.guardadas" "$PECAS"
clone_limpo

printf '\n'
if [ "$falhas" -gt 0 ]; then printf 'FALHOU: %d\n' "$falhas"; exit 1; fi
printf 'tudo ok\n'

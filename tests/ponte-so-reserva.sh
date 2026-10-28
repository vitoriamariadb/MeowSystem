#!/usr/bin/env bash
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

for f in scripts/ponte_root.sh scripts/reparar_ponte.sh scripts/meow-lancador-apt.sh \
         scripts/99-meow-lancador assets/ponte/meowsystem-ponte-reparo.service \
         assets/ponte/49-meowsystem-ponte-reparo.rules assets/zsh/_meow; do
  mkdir -p "$CLONE/${f%/*}"; cp "$RAIZ/$f" "$CLONE/$f"
done
cp -a "$CLONE" "$T/clone.limpo"
clone_limpo() { rm -rf "$CLONE"; cp -a "$T/clone.limpo" "$CLONE"; }

trocar() {
  sed -e "s#/usr/local/lib/meowsystem#$SIS/usr/local/lib/meowsystem#g" \
      -e "s#/usr/local/sbin/meow-lancador-apt.sh#$WRAPPER#g" \
      -e "s#/usr/local/share/zsh/site-functions#$SIS/usr/local/share/zsh/site-functions#g" \
      -e "s#/etc/apt/apt.conf.d#$SIS/etc/apt/apt.conf.d#g" \
      -e "s#/etc/sudoers.d#$SIS/etc/sudoers.d#g" \
      -e "s#/etc/systemd/system#$SIS/etc/systemd/system#g" \
      -e "s#/etc/polkit-1#$SIS/etc/polkit-1#g"
}

PONTE_TOY="$T/ponte-brinquedo.sh"
sed -e "s#^export PATH=.*#export PATH=\"$FALSO:/usr/bin:/bin\"#" -e 's/ -o root -g root//g' \
  "$RAIZ/scripts/ponte_root.sh" | trocar > "$PONTE_TOY"
chmod 755 "$PONTE_TOY"

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

etapa() {
  env -i PATH="$FALSO:/usr/bin:/bin" HOME="$CASA" USER="$(id -un)" MEOW_RAIZ="$CLONE" \
         MEOW_PONTE="$BASE/ponte_root.sh" LANCADOR_SISTEMA=sim LIB="$RAIZ/lib/comum.sh" \
         ETAPA="$ETAPA" FUNCAO="$1" bash -c '
    . "$LIB"; passo() { :; }; pular_por_optin() { return 3; }
    . "$ETAPA"; "$FUNCAO"' 2>&1
}

verbo() { env -i PATH="$FALSO:/usr/bin:/bin" HOME="$CASA" sudo -n "$BASE/ponte_root.sh" "$1" </dev/null 2>&1; }

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
doctor() {
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

printf '\n--- 3. a varredura: todo verbo que escreve em root, e de onde vem o que ele escreve ---\n'
VARRER="${PONTE_VARRER:-$RAIZ/scripts/ponte_root.sh}"
por_verbo() {
  sed 's/#.*$//' "$VARRER" | awk '
    /^[a-z][a-z-]*\)[ \t]*$/ { v = $0; sub(/\).*/, "", v); next }
    /^[ \t]*;;/ { v = ""; next }
    v != "" { print v "\t" $0 }'
}
declare -A ORIGEM=(
  [desktop]="stdin: o .desktop que já existe, editado; dado de aplicativo, que roda como quem o abre"
  [greeter-aplicar]="stdin: um tar, extraído para o lar do cosmic-greeter, com o dono dele"
  [apt-hook-instalar]="a reserva: o wrapper preenchido e o hook, com o sha256"
  [completion-instalar]="a reserva: a completion, com o sha256"
  [flatpak-global-limpar]="o próprio override global, menos as linhas de tema perdido"
  [libreoffice-remover]="a lista do dpkg, gravada em /var/lib/meowsystem"
  [som]="stdin: um Ogg de até 1 MB, só para um dos sete eventos da lista, com o de fábrica guardado em /var/lib/meowsystem"
  [som-padrao]="o de fábrica que o verbo som guardou, devolvido ao lugar"
  [gpu-compositor]="a placa dedicada achada em /sys, gravada como a única linha COSMIC_RENDER_DEVICE do /etc/environment, com o de antes guardado em /var/lib/meowsystem"
  [gpu-compositor-tirar]="o /etc/environment de antes, devolvido do que o verbo gpu-compositor guardou"
)
escrevem="$(por_verbo | awk -F'\t' '$2 ~ /(^|[ \t])(install -m|cp -a|mv -f|tee|dd) / { print $1 }' | sort -u | tr '\n' ' ')"
esperados="$(printf '%s\n' "${!ORIGEM[@]}" | sort | tr '\n' ' ')"
confere "os verbos que escrevem em root são os da tabela da varredura" \
  '[ "$escrevem" = "$esperados" ]' "escrevem: $escrevem
tabela:   $esperados"
for v in "${!ORIGEM[@]}"; do printf '        %-22s %s\n' "$v" "${ORIGEM[$v]}"; done | sort
leem_raiz="$(por_verbo | awk -F'\t' '$2 ~ /s\/\^raiz=\/\/p|raiz\) raiz=/ { print $1 }' | sort -u | tr '\n' ' ')"
confere "a raiz do clone, só o estado a lê do perfil (e só a imprime)" '[ "$leem_raiz" = "estado " ]' "lê: $leem_raiz"
for v in apt-hook-instalar completion-instalar; do
  bloco="$(por_verbo | awk -F'\t' -v v="$v" '$1 == v { print $2 }')"
  confere "$v copia da reserva, e não do perfil" \
    'grep -q "da_reserva" <<< "$bloco" && ! grep -q "PERFIL" <<< "$bloco"'
done
copias="$(por_verbo | awk -F'\t' '$2 ~ /(^|[ \t])(install -m|cp -a) / && $2 !~ /"\$tmp[_a-z]*(\/\.)?" "/ { print $1 ": " $2 }')"
confere "toda cópia para root parte de um temporário do verbo" '[ -z "$copias" ]' "$copias"

printf '\n--- 4. o wrapper do apt roda o clone como quem usa, nunca como root ---\n'
FALSO_W="$T/falso-wrapper"; CLONE_W="$T/clone-w"; CASA_W="$T/casa-w"; UIDS="$T/uids"; RUNUSER_LOG="$T/runuser.log"
mkdir -p "$FALSO_W" "$CLONE_W/scripts" "$CASA_W/.local/state/meowsystem"
cat > "$FALSO_W/id" <<FIM
#!/bin/sh
[ "\${1:-}" = -u ] && [ -z "\${TROCOU:-}" ] && { echo 0; exit 0; }
exec /usr/bin/id "\$@"
FIM
cat > "$FALSO_W/runuser" <<FIM
#!/bin/sh
printf '%s\n' "\$*" >> "$RUNUSER_LOG"
[ -e "$T/runuser-falha" ] && exit 1
[ "\$1" = -u ] && [ "\$3" = -- ] || exit 1
shift 3
TROCOU=1 exec "\$@"
FIM
for alvo in ocultar_apps.sh nomes_apps.sh; do
  printf '#!/bin/sh\nprintf "%%s %%s\\n" %s "$(id -u)" >> %s\nexit 0\n' "$alvo" "$UIDS" > "$CLONE_W/scripts/$alvo"
done
chmod 755 "$FALSO_W"/* "$CLONE_W/scripts/"*
WRAP_W="$T/wrapper-w.sh"
sed -e "s|@ACERVO@|$CLONE_W|g" -e "s|@USUARIA@|$(id -un)|g" -e "s|@LAR@|$CASA_W|g" \
  "$RAIZ/scripts/meow-lancador-apt.sh" > "$WRAP_W"; chmod 755 "$WRAP_W"
wrapper_como_root() { env -i PATH="$FALSO_W:/usr/bin:/bin" "$WRAP_W" 2>&1; }

: > "$UIDS"; : > "$RUNUSER_LOG"
saida="$(wrapper_como_root)"; rc=$?
confere "chamado como root, o wrapper se troca por quem usa com o runuser" \
  '[ "$rc" = 0 ] && grep -qx -- "-u $(id -un) -- $WRAP_W" "$RUNUSER_LOG"' "$saida
$(cat "$RUNUSER_LOG")"
confere "e os dois alvos do clone rodam com o uid de quem usa, nunca com 0" \
  '[ "$(cat "$UIDS")" = "ocultar_apps.sh $(id -u)
nomes_apps.sh $(id -u)" ]' "$(cat "$UIDS")"
: > "$UIDS"; rm -f "$CASA_W/.local/state/meowsystem/apt-lancador.log"; touch "$T/runuser-falha"
saida="$(wrapper_como_root)"; rc=$?
confere "se a troca falha, nada do clone roda e nada se escreve no lar (rc=0, o apt segue)" \
  '[ "$rc" = 0 ] && [ ! -s "$UIDS" ] && [ ! -e "$CASA_W/.local/state/meowsystem/apt-lancador.log" ]' "$saida
$(cat "$UIDS")"
rm -f "$T/runuser-falha"
sed -e "s|@ACERVO@|$CLONE_W|g" -e "s|@USUARIA@|root|g" -e "s|@LAR@|$CASA_W|g" \
  "$RAIZ/scripts/meow-lancador-apt.sh" > "$WRAP_W"
: > "$UIDS"; : > "$RUNUSER_LOG"
saida="$(wrapper_como_root)"; rc=$?
confere "preenchido com root, o wrapper não roda nada do clone" \
  '[ "$rc" = 0 ] && [ ! -s "$UIDS" ] && [ ! -s "$RUNUSER_LOG" ]' "$saida"

printf '\n'
if [ "$falhas" -gt 0 ]; then printf 'FALHOU: %d\n' "$falhas"; exit 1; fi
printf 'tudo ok\n'

#!/usr/bin/env bash
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

trocar() {
  sed -e "s#/usr/local/lib/meowsystem#$SIS/usr/local/lib/meowsystem#g" \
      -e "s#/etc/sudoers.d#$SIS/etc/sudoers.d#g" \
      -e "s#/etc/systemd/system#$SIS/etc/systemd/system#g" \
      -e "s#/etc/polkit-1#$SIS/etc/polkit-1#g"
}

PONTE_TOY="$T/ponte-brinquedo.sh"
sed -e "s#^export PATH=.*#export PATH=\"$FALSO:/usr/bin:/bin\"#" "$RAIZ/scripts/ponte_root.sh" | trocar > "$PONTE_TOY"

cat > "$FALSO/sudo" <<FIM
#!/bin/bash
[ "\${1:-}" = -n ] && shift
case "\${1:-}" in true|-v) exit 0 ;; esac
if [ "\$1" = "$BASE/ponte_root.sh" ]; then
  [ "\${2:-}" = estado ] && [ -x "$BASE/ponte_root.sh" ] && [ -f "$REGRA" ] || exit 1
  exec bash "$PONTE_TOY" estado
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
confere "a reserva nova esquece o veredito da rodada de antes do reparo" \
  'grep -qx "reset-failed meowsystem-ponte-reparo.service" "$SYSTEMCTL_LOG"' "$(cat "$SYSTEMCTL_LOG")"
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
de_fora() { sed 's/#.*$//' "$REPARO_REPO" | grep -vE '^[a-z_]+\(\) \{.*\}$' | grep -nE '\$[@*0-9#]|\$\{[@*0-9#]|HOME|MEOW_|USER|SUDO_|getopts|\bread\b|\bsource\b|^\s*\. '; }
confere "o reparo não lê argumento, ambiente de quem chama, nem o repositório" \
  '[ -f "$REPARO_REPO" ] && ! de_fora >/dev/null' "$(de_fora 2>&1)"

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

printf '\n--- 3. sem senha: o polkit libera o start do reparo, e nada além dele ---\n'
REGRA_PK_REPO="$RAIZ/assets/ponte/49-meowsystem-ponte-reparo.rules"
REGRA_PK="$SIS/etc/polkit-1/rules.d/49-meowsystem-ponte-reparo.rules"
rm -f "$REGRA_PK"
saida="$(etapa)"; rc=$?
confere "a etapa instala a regra do polkit, 0644, igual à do repositório" \
  '[ "$rc" = 1 ] && cmp -s "$REGRA_PK_REPO" "$REGRA_PK" && [ "$(stat -c %a "$REGRA_PK")" = 644 ]' "$saida"
: > "$SUDO_LOG"
saida="$(etapa)"; rc=$?
confere "com a regra no lugar, a segunda passada não escreve nada" '[ "$rc" = 0 ] && [ ! -s "$SUDO_LOG" ]' "$saida"

if command -v node >/dev/null 2>&1 && [ -f "$REGRA_PK_REPO" ]; then
  r="$(node - "$REGRA_PK_REPO" <<'JS' 2>&1
const fs = require("fs");
const regras = [];
const polkit = { Result: { YES: "yes", NO: "no", AUTH_ADMIN: "auth_admin" },
                 addRule: (f) => regras.push(f), log: () => {} };
new Function("polkit", fs.readFileSync(process.argv[2], "utf8"))(polkit);
const U = "meowsystem-ponte-reparo.service", A = "org.freedesktop.systemd1.manage-units";
const casos = [
  ["o start do reparo, na sessão local ativa", A, U, "start", true, true, "yes"],
  ["stop do reparo", A, U, "stop", true, true, undefined],
  ["restart do reparo", A, U, "restart", true, true, undefined],
  ["reload do reparo", A, U, "reload", true, true, undefined],
  ["start de outra unidade", A, "ssh.service", "start", true, true, undefined],
  ["start de um nome parecido", A, U + ".x", "start", true, true, undefined],
  ["start sem sessão ativa", A, U, "start", true, false, undefined],
  ["start de sessão remota", A, U, "start", false, true, undefined],
  ["outra ação com a mesma unidade", "org.freedesktop.systemd1.manage-unit-files", U, "start", true, true, undefined],
];
const erros = [];
if (regras.length !== 1) erros.push("regras registradas: " + regras.length);
for (const [nome, id, unit, verb, local, active, quer] of casos) {
  const det = { unit, verb };
  const acao = { id, lookup: (k) => det[k] };
  const quem = { local, active, user: "gata", isInGroup: () => true };
  const tem = regras.map((f) => f(acao, quem)).find((x) => x !== undefined);
  if (tem !== quer) erros.push(nome + ": " + tem);
}
console.log(erros.length ? erros.join("\n") : "ok");
JS
)"
  confere "a regra só diz sim ao start do reparo na sessão local ativa (9 casos no node)" '[ "$r" = ok ]' "$r"
else
  printf 'pulado: sem node, a regra do polkit não rodou\n'
fi

printf '\n--- 3b. desligar a ponte leva o reparo junto ---\n'
saida="$(etapa nao)"; rc=$?
confere 'PONTE_ROOT="nao" tira a regra do polkit, a unidade, a regra de sudo e a pasta' \
  '[ ! -e "$REGRA_PK" ] && [ ! -e "$UNIDADE" ] && [ ! -e "$REGRA" ] && [ ! -e "$BASE" ]' "$saida"
confere "o desinstalador tira a unidade e a regra do polkit" \
  'grep -q "/etc/polkit-1/rules.d/49-meowsystem-ponte-reparo.rules" "$RAIZ/lib/desinstalar.sh" \
   && grep -q "/etc/systemd/system/meowsystem-ponte-reparo.service" "$RAIZ/lib/desinstalar.sh"'
saida="$(etapa)"; rc=$?
confere "ligada de novo, tudo volta" '[ "$rc" = 1 ] && [ -f "$REGRA_PK" ] && [ -f "$UNIDADE" ] && [ -f "$BASE/reserva.sha256" ]' "$saida"

printf '\n--- 4. o doctor confere a ponte contra a reserva, e o conserto dispara o reparo ---\n'
UNI=meowsystem-ponte-reparo.service
cat > "$FALSO/systemctl" <<FIM
#!/bin/bash
printf '%s\n' "\$*" >> "$SYSTEMCTL_LOG"
est="$T/unidade"
case " \$* " in
  *" start "*" $UNI "*)
    [ -f "$T/polkit-nega" ] && { echo "Interactive authentication required." >&2; exit 1; }
    echo activating > "\$est.ativo"; sleep 0.5
    bash "$REPARO" >/dev/null 2>&1; r=\$?
    echo "\$r" > "\$est.status"
    if [ "\$r" = 0 ]; then echo success > "\$est.result"; echo inactive > "\$est.ativo"; exit 0; fi
    echo exit-code > "\$est.result"; echo failed > "\$est.ativo"; exit 1 ;;
  *" show "*" $UNI "*)
    case " \$* " in
      *" LoadState "*)      [ -f "$UNIDADE" ] && echo loaded || echo not-found ;;
      *" ActiveState "*)    cat "\$est.ativo" 2>/dev/null || echo inactive ;;
      *" Result "*)         cat "\$est.result" 2>/dev/null || echo success ;;
      *" ExecMainStatus "*) cat "\$est.status" 2>/dev/null || echo 0 ;;
    esac
    exit 0 ;;
esac
exit 0
FIM
chmod 755 "$FALSO/systemctl"
DOCTOR="$T/doctor.sh"
for f in _ponte_reparo_ha _ponte_reparo_motivo _ponte_regra_igual_a_reserva chk_ponte fix_ponte; do
  sed -n "/^$f() {/,/^}/p" "$RAIZ/bin/meow"
done | trocar > "$DOCTOR"
doctor() {
  env -i PATH="$FALSO:/usr/bin:/bin" HOME="$CASA" RAIZ="${RAIZ_DOCTOR:-$RAIZ}" MEOW_RAIZ="$RAIZ" \
         PONTE_ROOT="${PONTE_ROOT_DOCTOR:-sim}" DOCTOR="$DOCTOR" FUNCAO="$1" bash -c '
    . "$MEOW_RAIZ/lib/comum.sh"; . "$DOCTOR"; "$FUNCAO"' 2>&1
}
saida="$(doctor chk_ponte)"; rc=$?
confere "com a ponte no lugar, o doctor diz ok" '[ "$rc" = 0 ]' "$saida"

rm -f "$REGRA"
saida="$(doctor chk_ponte)"; rc=$?
confere "sem a regra: divergente, e o conserto é o reparo" \
  '[ "$rc" = 1 ] && grep -q "49-meowsystem-ponte" <<< "$saida" && grep -q "reserva" <<< "$saida"' "$saida"
: > "$SUDO_LOG"; : > "$SYSTEMCTL_LOG"
saida="$(doctor fix_ponte)"; rc=$?
confere "o conserto dá start no reparo, sem sudo, e a regra volta" \
  '[ "$rc" = 1 ] && grep -q "^start --no-ask-password $UNI\$" "$SYSTEMCTL_LOG" && [ ! -s "$SUDO_LOG" ] && cmp -s "$T/regra.boa" "$REGRA"' \
  "$saida
$(cat "$SYSTEMCTL_LOG")"
confere "o conserto mostra o estado da unidade enquanto ela roda" 'grep -q "repondo" <<< "$saida"' "$saida"
saida="$(doctor chk_ponte)"; rc=$?
confere "depois do reparo, o doctor diz ok" '[ "$rc" = 0 ]' "$saida"

printf '\necho outra\n' >> "$BASE/ponte_root.sh"
saida="$(doctor chk_ponte)"; rc=$?
confere "ponte instalada diferente da reserva: divergente" '[ "$rc" = 1 ] && grep -q "reserva" <<< "$saida"' "$saida"
saida="$(doctor fix_ponte)"; rc=$?
confere "o reparo põe a ponte da reserva de volta" '[ "$rc" = 1 ] && cmp -s "$BASE/reserva/ponte_root.sh" "$BASE/ponte_root.sh"' "$saida"

rm -f "$REGRA"
chmod u+w "$BASE/reserva/ponte_root.sh"; printf '\necho adulterada\n' >> "$BASE/reserva/ponte_root.sh"
saida="$(doctor fix_ponte)"; rc=$?
confere "reserva adulterada: o conserto falha e nada volta" '[ "$rc" = 2 ] && [ ! -e "$REGRA" ]' "$saida"
saida="$(doctor chk_ponte)"; rc=$?
confere "e o doctor diz por quê: a reserva não confere" '[ "$rc" = 1 ] && grep -q "não confere" <<< "$saida"' "$saida"
cp -f "$T/ponte.boa" "$BASE/reserva/ponte_root.sh"

: > "$T/polkit-nega"
saida="$(doctor fix_ponte)"; rc=$?
confere "fora da sessão local ativa, o polkit recusa, e o doctor diz isso" \
  '[ "$rc" = 2 ] && [ ! -e "$REGRA" ] && grep -q "polkit" <<< "$saida"' "$saida"
rm -f "$T/polkit-nega"
saida="$(doctor fix_ponte)"; rc=$?
confere "na sessão, a regra volta" '[ "$rc" = 1 ] && [ -f "$REGRA" ]' "$saida"

confere "a ponte saiu da lista do que o doctor não conserta" \
  '! grep -E "^ *SEM_CONSERTO=\".* ponte " "$RAIZ/bin/meow"'
confere "o conserto do doctor sai na hora, linha a linha (o painel mostra o progresso)" \
  'grep -qF "\"fix_\$nome\" 2>&1 | sed -u " "$RAIZ/bin/meow"'
confere "a ponte de volta abre, na mesma passada, os consertos que precisam dela" \
  'grep -qF "[ \"\$nome\" = \"ponte\" ] && [ \"\$rc\" = \"1\" ] && meow_ponte_viva" "$RAIZ/bin/meow"'

r="$(env -i PATH="$PATH" HOME="$CASA" PYTHONDONTWRITEBYTECODE=1 python3 - "$RAIZ" <<'PYFIM' 2>&1
import os, sys, time
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
servidor._ponte_cache.update(quando=time.time(), vale=False)
t = servidor.Trabalho("teste", ["true"], dict(os.environ), "teste")
fim = time.time() + 10
while t.fim is None and time.time() < fim:
    time.sleep(0.02)
print("ok" if servidor._ponte_cache["quando"] == 0.0 else "cache=%r" % servidor._ponte_cache)
PYFIM
)"
confere "o fim de um trabalho do painel esquece a ponte lida" '[ "$(tail -n1 <<< "$r")" = ok ]' "$r"

printf '\n--- 5. o limite: ponte nova no repositório e install sem reserva ficam com o install ---\n'
CLONE="$T/clone"; mkdir -p "$CLONE/scripts" "$CLONE/assets/ponte"
cp "$RAIZ/scripts/ponte_root.sh" "$CLONE/scripts/ponte_root.sh"
cp "$RAIZ/assets/ponte/49-meowsystem-ponte-reparo.rules" "$CLONE/assets/ponte/"
printf '\n# mudou no repositório\n' >> "$CLONE/scripts/ponte_root.sh"
saida="$(RAIZ_DOCTOR="$CLONE" doctor chk_ponte)"; rc=$?
confere "ponte nova no repositório: pendência do install" \
  '[ "$rc" = 1 ] && grep -q "Instalar tudo" <<< "$saida" && grep -q "repositório" <<< "$saida"' "$saida"
: > "$SYSTEMCTL_LOG"
saida="$(RAIZ_DOCTOR="$CLONE" doctor fix_ponte)"; rc=$?
confere "e o conserto não dispara o reparo (sai 3, nenhum start)" \
  '[ "$rc" = 3 ] && ! grep -q "^start" "$SYSTEMCTL_LOG" && grep -q "Instalar tudo" <<< "$saida"' "$saida
$(cat "$SYSTEMCTL_LOG")"
rm -f "$BASE/ponte_root.sh"
saida="$(RAIZ_DOCTOR="$CLONE" doctor fix_ponte)"; rc=$?
confere "sem a ponte, o reparo repõe a da reserva, nunca a do repositório" \
  '[ "$rc" = 1 ] && cmp -s "$BASE/reserva/ponte_root.sh" "$BASE/ponte_root.sh" && ! cmp -s "$CLONE/scripts/ponte_root.sh" "$BASE/ponte_root.sh"' "$saida"
saida="$(RAIZ_DOCTOR="$CLONE" doctor chk_ponte)"; rc=$?
confere "e o doctor segue pedindo o install para a ponte nova" '[ "$rc" = 1 ] && grep -q "Instalar tudo" <<< "$saida"' "$saida"

mv "$BASE/reserva" "$T/reserva.antiga"; mv "$BASE/reserva.sha256" "$T/somas.antigas"
saida="$(doctor chk_ponte)"; rc=$?
confere "install antigo, sem reserva: a ponte funciona e o doctor pede o install" \
  '[ "$rc" = 1 ] && grep -q "sem reserva" <<< "$saida" && grep -q "Instalar tudo" <<< "$saida"' "$saida"
: > "$SYSTEMCTL_LOG"
saida="$(doctor fix_ponte)"; rc=$?
confere "e o conserto não dispara nada (sai 3, nenhum start)" '[ "$rc" = 3 ] && ! grep -q "^start" "$SYSTEMCTL_LOG"' "$saida"
mv "$T/reserva.antiga" "$BASE/reserva"; mv "$T/somas.antigas" "$BASE/reserva.sha256"
saida="$(doctor chk_ponte)"; rc=$?
confere "com a reserva de volta, ok" '[ "$rc" = 0 ]' "$saida"

printf '\n--- 6. PONTE_ROOT="nao": o reparo nunca devolve a ponte que quem usa desligou ---\n'
rm -f "$REGRA"
saida="$(PONTE_ROOT_DOCTOR=nao doctor chk_ponte)"; rc=$?
confere 'PONTE_ROOT="nao" com a ponte no disco: o doctor aponta a divergência' '[ "$rc" = 1 ]' "$saida"
: > "$SYSTEMCTL_LOG"
saida="$(PONTE_ROOT_DOCTOR=nao doctor fix_ponte)"; rc=$?
confere 'e o conserto não dispara o reparo nem devolve a regra (sai 3, nenhum start)' \
  '[ "$rc" = 3 ] && ! grep -q "^start" "$SYSTEMCTL_LOG" && [ ! -e "$REGRA" ] && grep -q "Instalar tudo" <<< "$saida"' "$saida
$(cat "$SYSTEMCTL_LOG")"
saida="$(doctor fix_ponte)"; rc=$?
confere "ligada de novo no meow.conf, o reparo volta a repor" '[ "$rc" = 1 ] && [ -f "$REGRA" ]' "$saida"

printf '\n--- 7. o doctor confere a regra de sudo contra a reserva, e a ponte, a do polkit ---\n'
etapa >/dev/null
saida="$(etapa)"; rc=$?
confere "com tudo no lugar, a etapa não muda nada" '[ "$rc" = 0 ]' "$saida"
saida="$(doctor chk_ponte)"; rc=$?
confere "e o doctor diz ok" '[ "$rc" = 0 ]' "$saida"
chmod u+w "$REGRA"; printf '# trocada, e ainda libera a ponte\n' >> "$REGRA"
saida="$(doctor chk_ponte)"; rc=$?
confere "a regra de sudo trocada: divergente, contra a reserva" \
  '[ "$rc" = 1 ] && grep -q "49-meowsystem-ponte difere da reserva" <<< "$saida"' "$saida"
: > "$SYSTEMCTL_LOG"
saida="$(doctor fix_ponte)"; rc=$?
confere "o conserto dispara o reparo, e a regra da reserva volta" \
  '[ "$rc" = 1 ] && grep -q "^start --no-ask-password $UNI\$" "$SYSTEMCTL_LOG" && cmp -s "$BASE/reserva/49-meowsystem-ponte" "$REGRA"' "$saida"
saida="$(doctor chk_ponte)"; rc=$?
confere "depois do reparo, ok" '[ "$rc" = 0 ]' "$saida"

rm -f "$REGRA_PK"
saida="$(doctor chk_ponte)"; rc=$?
confere "sem a regra do polkit: a ponte a confere, e o doctor pede o install" \
  '[ "$rc" = 1 ] && grep -q "polkit" <<< "$saida" && grep -q "Instalar tudo" <<< "$saida"' "$saida"
: > "$SYSTEMCTL_LOG"
saida="$(doctor fix_ponte)"; rc=$?
confere "e o conserto não dispara o reparo (sai 3, nenhum start)" \
  '[ "$rc" = 3 ] && ! grep -q "^start" "$SYSTEMCTL_LOG"' "$saida"
chmod 300 "$SIS/etc/polkit-1/rules.d"
saida="$(etapa)"; rc=$?
chmod 755 "$SIS/etc/polkit-1/rules.d"
confere "a etapa, sem ler a pasta do polkit, vê a regra que falta e a põe" \
  '[ "$rc" = 1 ] && cmp -s "$REGRA_PK_REPO" "$REGRA_PK"' "$saida"
saida="$(doctor chk_ponte)"; rc=$?
confere "com a regra do polkit de volta, ok" '[ "$rc" = 0 ]' "$saida"
printf '// trocada\n' >> "$REGRA_PK"
saida="$(doctor chk_ponte)"; rc=$?
confere "a regra do polkit trocada: divergente, e o install a repõe" \
  '[ "$rc" = 1 ] && grep -q "polkit" <<< "$saida" && grep -q "Instalar tudo" <<< "$saida"' "$saida"
chmod 300 "$SIS/etc/polkit-1/rules.d"
saida="$(etapa)"; rc=$?
chmod 755 "$SIS/etc/polkit-1/rules.d"
confere "e a etapa a põe de volta" '[ "$rc" = 1 ] && cmp -s "$REGRA_PK_REPO" "$REGRA_PK"' "$saida"
saida="$(doctor chk_ponte)"; rc=$?
confere "e o doctor diz ok" '[ "$rc" = 0 ]' "$saida"

printf '\n--- 8. a ponte de antes dos verbos da GPU: o doctor a acusa e o install a renova ---\n'
VELHA="$T/ponte-velha.sh"
sed -e '/^gpu-compositor)/,/^  ;;$/d' -e '/^gpu-compositor-tirar)/,/^  ;;$/d' -e '/gpu-compositor/d' \
  "$RAIZ/scripts/ponte_root.sh" > "$VELHA"
regra_velha="$(SUDO_USER="$(id -un)" bash "$VELHA" regra-sudo)"
confere "a ponte velha de brinquedo não conhece os verbos da GPU" \
  'bash -n "$VELHA" && ! grep -q gpu-compositor "$VELHA" && grep -q "ponte_root.sh estado" <<< "$regra_velha"'
chmod -R u+w "$BASE"; chmod u+w "$REGRA"
cp "$VELHA" "$BASE/ponte_root.sh"; cp "$VELHA" "$BASE/reserva/ponte_root.sh"
printf '%s\n' "$regra_velha" > "$REGRA"; printf '%s\n' "$regra_velha" > "$BASE/reserva/49-meowsystem-ponte"
( cd "$BASE/reserva" && sha256sum ponte_root.sh 49-meowsystem-ponte ) > "$BASE/reserva.sha256"
saida="$(doctor chk_ponte)"; rc=$?
confere "ponte e reserva da mesma época, sem gpu-compositor: divergente, e pede o «Instalar tudo»" \
  '[ "$rc" = 1 ] && grep -q "repositório" <<< "$saida" && grep -q "Instalar tudo" <<< "$saida"' "$saida"
: > "$SYSTEMCTL_LOG"
saida="$(doctor fix_ponte)"; rc=$?
confere "e o conserto não dispara o reparo, que só devolveria a velha (sai 3)" \
  '[ "$rc" = 3 ] && ! grep -q "^start" "$SYSTEMCTL_LOG" && grep -q "Instalar tudo" <<< "$saida"' "$saida"
saida="$(etapa)"; rc=$?
confere "o install renova ponte, reserva e regra, que passa a liberar os dois verbos" \
  '[ "$rc" = 1 ] && cmp -s "$RAIZ/scripts/ponte_root.sh" "$BASE/ponte_root.sh" && cmp -s "$RAIZ/scripts/ponte_root.sh" "$BASE/reserva/ponte_root.sh" \
   && grep -q "ponte_root.sh gpu-compositor, " "$REGRA" && grep -q "ponte_root.sh gpu-compositor-tirar, " "$REGRA"' "$saida"
saida="$(doctor chk_ponte)"; rc=$?
confere "e o doctor diz ok" '[ "$rc" = 0 ]' "$saida"

printf '\n'
if [ "$falhas" -gt 0 ]; then printf 'FALHOU: %d\n' "$falhas"; exit 1; fi
printf 'tudo ok\n'

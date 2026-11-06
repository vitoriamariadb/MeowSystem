#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
SHIM="$RAIZ/scripts/compositor_shim.sh"
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

mkdir -p "$T/bin" "$T/casa" "$T/home"
VER_INST="0.1~1791227611~24.04~41497b4"
printf '%s' "$VER_INST" > "$T/versao"
cat > "$T/bin/dpkg-query" <<FIM
#!/bin/sh
cat "$T/versao"
FIM
chmod 755 "$T/bin/dpkg-query"

cat > "$T/fabrica" <<'FIM'
#!/bin/sh
echo fabrica
FIM
chmod 755 "$T/fabrica"
fazer_build() {
  mkdir -p "$T/casa/$1"
  cat > "$T/casa/$1/cosmic-comp" <<'FIM'
#!/bin/sh
echo build
[ "${1:-}" = --version ] && exit 0
[ -n "${FICAR:-}" ] && sleep "$FICAR"
exit 0
FIM
  chmod 755 "$T/casa/$1/cosmic-comp"
  printf 'versao=%s\nreq AURORA-COSMIC-WS-PATCH-3.67 cosmic-comp-sem-workspace-vazio.patch presente\n' "$1" > "$T/casa/$1/estado"
}
rodar() { PATH="$T/bin:$PATH" MEOW_SHIM_FABRICA="$T/fabrica" MEOW_SHIM_CASA="$T/casa" \
          MEOW_SHIM_JANELA="${JANELA:-1}" HOME="$T/home" bash "$SHIM" "$@"; }

echo "== o shim escolhe"
igual "sem build: fábrica" "$(rodar)" fabrica

fazer_build "$VER_INST"
igual "versão igual: build" "$(rodar)" build
rm -f "$T/casa/$VER_INST/quedas"

printf '0.1~outra' > "$T/versao"
igual "versão diferente: fábrica" "$(rodar)" fabrica
printf '%s' "$VER_INST" > "$T/versao"

date -Is > "$T/casa/$VER_INST/ruim"
igual "build ruim: fábrica" "$(rodar)" fabrica
rm -f "$T/casa/$VER_INST/ruim"

sed -i 's/presente$/ausente/' "$T/casa/$VER_INST/estado"
igual "estado sem req presente: fábrica" "$(rodar)" fabrica
fazer_build "$VER_INST"

igual "só dizer: o caminho do build" "$(MEOW_SHIM_SO_DIZER=1 rodar)" "$T/casa/$VER_INST/cosmic-comp"
[ -e "$T/casa/$VER_INST/quedas" ] && falha "só dizer contou queda" || ok "só dizer não conta queda"

for q in --version -V --help -h; do
  igual "pergunta $q: o build responde" "$(rodar $q)" build
done
[ -e "$T/casa/$VER_INST/quedas" ] && falha "pergunta contou queda (o fastfetch marcava o build de ruim)" \
  || ok "pergunta (--version, --help) não conta queda"

echo "== a guarda de queda"
igual "1º início: build" "$(rodar)" build; sleep 2
igual "2º início: build" "$(rodar)" build; sleep 2
igual "3º início, depois de duas quedas: fábrica" "$(rodar)" fabrica
[ -e "$T/casa/$VER_INST/ruim" ] && ok "o build ficou marcado ruim" || falha "o build não foi marcado ruim"
igual "4º início: continua fábrica até build novo" "$(rodar)" fabrica

fazer_build "$VER_INST"; rm -f "$T/casa/$VER_INST/ruim" "$T/casa/$VER_INST/quedas"
igual "sessão longa: build" "$(FICAR=3 rodar)" build
sleep 1
[ -e "$T/casa/$VER_INST/quedas" ] && falha "o contador ficou depois de uma sessão que passou da janela" \
  || ok "o contador zerou depois de uma sessão que passou da janela"

echo "== os verbos (HOME de brinquedo)"
CP() { HOME="$T/home" PATH="$T/bin:$PATH" CP_BIN="$T/fabrica" CP_CASA="$T/casa" \
       MEOW_ESTADO="$T/home/.local/state/meowsystem" MEOW_IGNORA_DESKTOP=1 \
       "$RAIZ/scripts/compositor_patches.sh" "$@" 2>&1; }
igual "qual, sem shim: fábrica" "$(CP qual)" "$T/fabrica"
CP ativar >/dev/null; rc=$?
igual "ativar escreve (1)" "$rc" 1
cmp -s "$SHIM" "$T/home/.local/bin/cosmic-comp" && ok "o shim foi instalado em ~/.local/bin" || falha "o shim não está em ~/.local/bin"
CP ativar >/dev/null; igual "ativar de novo não escreve (0)" "$?" 0
igual "qual, com shim e build: build" "$(CP qual)" "$T/casa/$VER_INST/cosmic-comp"
CP desativar >/dev/null; igual "desativar escreve (1)" "$?" 1
[ -e "$T/home/.local/bin/cosmic-comp" ] && falha "o shim ficou" || ok "o shim saiu"
CP desativar >/dev/null; igual "desativar de novo não escreve (0)" "$?" 0
echo "== a conferência com o shim e sem build (conferência da P76)"
CP ativar >/dev/null
printf '0.1~sem-build' > "$T/versao"
CP conferir >/dev/null; igual "sem build e sem degrau 4: 1 (o conserto compila)" "$?" 1
mkdir -p "$T/home/.local/state/meowsystem"
flock "$T/home/.local/state/meowsystem/builds.lock" sleep 3 & trava=$!
sleep 0.5
saida="$(CP conferir)"; rc=$?
igual "sem build, com um build em andamento: 0" "$rc" 0
grep -q '^ *!! *construindo' <<< "$saida" && ok "e diz «construindo», com aviso" || falha "não disse construindo: $saida"
kill "$trava" 2>/dev/null; wait "$trava" 2>/dev/null
mkdir -p "$T/home/.local/state/meowsystem/cosmic-comp"
printf '0.1~sem-build\t2026-10-09\tcosmic-comp-sem-workspace-vazio.patch:4 cosmic-comp-raio-clampado.patch:1\n' \
  > "$T/home/.local/state/meowsystem/cosmic-comp/matriz.tsv"
CP conferir >/dev/null; igual "sem build e com o degrau 4 na matriz: 1" "$?" 1
printf '%s' "$VER_INST" > "$T/versao"
CP desativar >/dev/null

echo "== o Restaurar do ativar e do desativar deixa um compositor que sobe"
RESTAURAR() { HOME="$T/home" PATH="$T/bin:$PATH" MEOW_ESTADO="$T/home/.local/state/meowsystem" NO_COLOR=1 \
              "$RAIZ/bin/meow" restaurar "$1" </dev/null >/dev/null 2>&1; }
SHIM_NA_CASA="$T/home/.local/bin/cosmic-comp"
MEOW_BACKUPS="$T/guarda-ativar" CP ativar >/dev/null
RESTAURAR "$T/guarda-ativar"; igual "restaurar o ativar: rc 1" "$?" 1
[ -e "$SHIM_NA_CASA" ] && falha "restaurar o ativar deixou o shim" || ok "restaurar o ativar tira o shim"
igual "e o próximo login sobe a fábrica" "$(CP qual)" "$T/fabrica"
CP ativar >/dev/null
MEOW_BACKUPS="$T/guarda-desativar" CP desativar >/dev/null
RESTAURAR "$T/guarda-desativar"; igual "restaurar o desativar: rc 1" "$?" 1
cmp -s "$SHIM" "$SHIM_NA_CASA" && [ -x "$SHIM_NA_CASA" ] && ok "restaurar o desativar devolve o shim, executável" \
  || falha "o shim devolvido não é o shim executável"
igual "o shim devolvido com build sobe o build" "$(CP qual)" "$T/casa/$VER_INST/cosmic-comp"
printf '0.1~sem-build' > "$T/versao"
igual "o shim devolvido sem build sobe a fábrica" \
  "$(PATH="$T/bin:$PATH" MEOW_SHIM_FABRICA="$T/fabrica" MEOW_SHIM_CASA="$T/casa" HOME="$T/home" "$SHIM_NA_CASA")" fabrica
printf '%s' "$VER_INST" > "$T/versao"
CP desativar >/dev/null

printf '#!/bin/sh\necho alheio\n' > "$T/home/.local/bin/cosmic-comp"
CP ativar >/dev/null; igual "ativar recusa um cosmic-comp alheio (2)" "$?" 2
grep -q alheio "$T/home/.local/bin/cosmic-comp" && ok "o alheio ficou intocado" || falha "o alheio foi sobrescrito"
rm -f "$T/home/.local/bin/cosmic-comp"

B="$T/casa/$VER_INST"
GENTE="$T/home/.local/state/meowsystem/precisa-de-gente.tsv"
: > "$T/journal"
cat > "$T/bin/journalctl" <<FIM
#!/bin/sh
cat "$T/journal"
FIM
chmod 755 "$T/bin/journalctl"
EXE="$(readlink -f "$B/cosmic-comp")"
jornal() {
  printf '{"_BOOT_ID":"b1","SYSLOG_IDENTIFIER":"cosmic-session","MESSAGE":"starting process '"'"' X=1 cosmic-comp '"'"'"}\n' >> "$T/journal"
  printf '{"_BOOT_ID":"b1","SYSLOG_IDENTIFIER":"cosmic-comp","_EXE":"%s","MESSAGE":"ola"}\n' "$1" >> "$T/journal"
  printf '{"_BOOT_ID":"b1","SYSLOG_IDENTIFIER":"cosmic-session","MESSAGE":"process '"'"' X=1 cosmic-comp '"'"' terminated with signal %s"}\n' "$2" >> "$T/journal"
}

echo "== P154 1: o binário que cai na partida não chega à sessão"
fazer_build "$VER_INST"
printf '#!/bin/sh\nkill -SEGV $$\n' > "$B/cosmic-comp"
igual "o build que cai no --version: fábrica já no 1º login" "$(rodar)" fabrica
[ -e "$B/quedas" ] && falha "o teste de fumaça contou queda" || ok "e não conta queda nem marca nada"
head -c 200 /bin/sh > "$B/cosmic-comp"; chmod 755 "$B/cosmic-comp"
igual "o build truncado: fábrica" "$(rodar)" fabrica

echo "== P154 2: a pasta do build sem escrita"
fazer_build "$VER_INST"
chmod 555 "$B"
igual "sem gravar quedas: fábrica, e não o build sem guarda" "$(rodar)" fabrica
chmod 755 "$B"
igual "com escrita de volta: build" "$(rodar)" build; rm -f "$B/quedas"

echo "== P154 4: um req ausente, mesmo com outro presente"
printf 'req AURORA-X-1 x.patch ausente\n' >> "$B/estado"
igual "req presente e req ausente: fábrica" "$(rodar)" fabrica
fazer_build "$VER_INST"

echo "== P154 3: duas partidas curtas normais não tiram os patches para sempre"
CP ativar >/dev/null
igual "1ª sessão curta: build" "$(rodar)" build; sleep 2
igual "2ª sessão curta: build" "$(rodar)" build; sleep 2
igual "3ª: a guarda põe de lado" "$(rodar)" fabrica
CP conferir >/dev/null; igual "o conferir diverge: o conserto decide" "$?" 1
saida="$(CP cuidar)"; rc=$?
igual "o cuidar devolve o build (1)" "$rc" 1
[ ! -e "$B/ruim" ] && [ -e "$B/perdoado" ] && ok "sem queda no registro: a marca sai, e fica anotado que foi devolvido" \
  || falha "o cuidar não devolveu o build: $saida"
igual "o login seguinte sobe o build" "$(rodar)" build; rm -f "$B/quedas"
CP cuidar >/dev/null; igual "o cuidar de novo, sem nada: 0" "$?" 0
date -Is > "$B/ruim"
CP cuidar >/dev/null
igual "posto de lado de novo depois de devolvido: fica de lado (caiu)" "$(head -c 4 "$B/ruim")" caiu
grep -q '^compositor-caiu	' "$GENTE" 2>/dev/null && ok "e entra no precisa de gente" || falha "não entrou no precisa de gente"
saida="$(CP conferir)"; rc=$?
igual "o conferir de um build que caiu: 3, sem conserto" "$rc" 3
grep -q '!!' <<< "$saida" && ok "com aviso" || falha "sem aviso: $saida"

echo "== P154 5: a queda depois da janela conta, pelo registro"
fazer_build "$VER_INST"; rm -f "$B/ruim" "$B/perdoado"
jornal "$EXE" 15
CP conferir > "$T/saida"
grep -q 'caiu' "$T/saida" && falha "o SIGTERM do fim de sessão contou como queda" || ok "o fim de sessão normal (sinal 15) não conta"
jornal /usr/bin/cosmic-comp 11
CP conferir > "$T/saida"
grep -q 'caiu' "$T/saida" && falha "a queda do de fábrica contou para o build" || ok "a queda do de fábrica não conta para o build"
jornal "$EXE" 11
CP conferir > "$T/saida"; rc=$?
igual "a queda do build aos 5 min: o conferir diverge" "$rc" 1
grep -q 'caiu 1 vez' "$T/saida" && ok "e diz que caiu" || falha "não disse que caiu: $(cat "$T/saida")"
CP cuidar >/dev/null; igual "o cuidar põe de lado (1)" "$?" 1
igual "a marca diz caiu" "$(head -c 4 "$B/ruim")" caiu
igual "e o próximo login sobe a fábrica" "$(rodar)" fabrica
fazer_build "$VER_INST"; rm -f "$B/ruim"; : > "$T/journal"
printf '{"_BOOT_ID":"b1","SYSLOG_IDENTIFIER":"cosmic-session","MESSAGE":"process '"'"' X=1 cosmic-comp '"'"' exited with error 1"}\n' >> "$T/journal"
CP conferir > "$T/saida"
grep -q 'caiu 1 vez' "$T/saida" && ok "a queda antes da primeira linha do compositor conta" || falha "a queda sem linha do compositor não contou"
: > "$T/journal"; rm -f "$B/ruim"
mv "$T/bin/journalctl" "$T/journalctl.guardado"
printf '#!/bin/sh\nexit 1\n' > "$T/bin/journalctl"; chmod 755 "$T/bin/journalctl"
date -Is > "$B/ruim"
mkdir "$T/sem-coredump"; ln -s /usr/bin/* "$T/sem-coredump/"; rm -f "$T/sem-coredump/coredumpctl"
PATH="$T/sem-coredump" CP cuidar >/dev/null
igual "sem registro legível, na dúvida: fica de lado" "$(head -c 4 "$B/ruim")" caiu
mv -f "$T/journalctl.guardado" "$T/bin/journalctl"
fazer_build "$VER_INST"; rm -f "$B/ruim" "$B/perdoado"

echo "== P154 5: o build de degrau 2 fica retido até o sim"
echo "cosmic-comp-raio-clampado.patch" > "$B/retido"
igual "retido: fábrica" "$(rodar)" fabrica
saida="$(CP conferir)"; rc=$?
igual "o conferir do retido: 4, escolha" "$rc" 4
grep -q 'degrau 2' <<< "$saida" && ok "e diz degrau 2" || falha "não disse degrau 2: $saida"
CP liberar >/dev/null; igual "liberar escreve (1)" "$?" 1
igual "liberado: build" "$(rodar)" build; rm -f "$B/quedas"
igual "o liberado fica anotado" "$(cat "$B/liberado")" cosmic-comp-raio-clampado.patch
CP liberar >/dev/null; igual "liberar de novo: 0" "$?" 0

echo "== P154: as bibliotecas mudaram desde o build"
printf 'bibliotecas=00000000000000000000000000000000\n' >> "$B/estado"
CP conferir > "$T/saida"; rc=$?
igual "a impressão digital não bate: 1" "$rc" 1
grep -q 'bibliotecas do sistema mudaram' "$T/saida" && ok "e diz que as bibliotecas mudaram" || falha "não disse: $(cat "$T/saida")"
igual "e o build segue valendo até o novo" "$(rodar)" build; rm -f "$B/quedas"
fazer_build "$VER_INST"

echo "== P154 8: o login que não passa pelo shim"
cat > "$T/bin/pgrep" <<'FIM'
#!/bin/sh
case "$*" in *cosmic-session*) echo 4242 ;; esac
FIM
printf '#!/bin/sh\necho 100\n' > "$T/bin/ps"
chmod 755 "$T/bin/pgrep" "$T/bin/ps"
mkdir -p "$T/proc/4242"
printf 'HOME=%s\0PATH=/usr/local/bin:/usr/bin:/bin\0' "$T/home" > "$T/proc/4242/environ"
mkdir -p "$T/usr-bin"; cp "$T/fabrica" "$T/usr-bin/cosmic-comp"
printf 'HOME=%s\0PATH=%s:/bin\0' "$T/home" "$T/usr-bin" > "$T/proc/4242/environ"
saida="$(CP_PROC="$T/proc" CP conferir)"
grep -q 'não passa' <<< "$saida" && falha "o shim nasceu depois da sessão e o conferir já culpa o PATH" \
  || ok "o shim posto depois do login: ainda vale no próximo"
touch -d '-1 hour' "$T/home/.local/bin/cosmic-comp"
saida="$(CP_PROC="$T/proc" CP conferir)"; rc=$?
igual "o PATH da sessão acha outro cosmic-comp antes do shim: 3" "$rc" 3
grep -q '!!.*não passa por' <<< "$saida" && ok "e diz, com aviso, que o login não passa pelo shim" || falha "não disse: $saida"
printf 'HOME=%s\0PATH=%s:%s:/bin\0' "$T/home" "$T/home/.local/bin" "$T/usr-bin" > "$T/proc/4242/environ"
saida="$(CP_PROC="$T/proc" CP conferir)"
grep -q 'não passa' <<< "$saida" && falha "o PATH com o shim na frente ainda é culpado" || ok "com o shim na frente do PATH, nada a dizer"
printf 'HOME=/outra/casa\0PATH=/bin\0' > "$T/proc/4242/environ"
saida="$(CP_PROC="$T/proc" CP conferir)"
grep -q 'não passa' <<< "$saida" && falha "a sessão de outra casa foi lida" || ok "a sessão de outra casa não conta"
rm -f "$T/bin/pgrep" "$T/bin/ps"
CP desativar >/dev/null

echo
if [ "$falhas" = 0 ]; then echo "compositor-shim: tudo certo"; exit 0; fi
echo "compositor-shim: $falhas falha(s)"; exit 1

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ESPACO="$RAIZ/scripts/espaco.py"
REGISTRO="$RAIZ/assets/contratos/espaco.tsv"

falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }
perto() {
  local nome="$1" a="$2" b="$3" pct="${4:-5}"
  if python3 - "$a" "$b" "$pct" <<'PY'
import sys
a, b, pct = float(sys.argv[1]), float(sys.argv[2]), float(sys.argv[3])
sys.exit(0 if b > 0 and abs(a - b) / b * 100 <= pct else 1)
PY
  then ok "$nome ($a contra $b)"; else falha "$nome: $a contra $b, fora de ${pct}%"; fi
}

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

mkdir -p "$T/bin"
for c in sudo pkexec su apt apt-get pkill killall systemd-run notify-send just make; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/recusas.log"\nexit 1\n' "$c" "$T" > "$T/bin/$c"; chmod 755 "$T/bin/$c"
done

mundo() {
  M="$(mktemp -d -p "$T")"
  CASA="$M/casa"; E="$CASA/.local/state/meowsystem"; C="$CASA/.cache/meowsystem"
  LIBEXEC="$CASA/.local/libexec/meow"; CLONE="$M/clone"
  mkdir -p "$E" "$C" "$LIBEXEC" "$CLONE/src"
}

esp() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$E" MEOW_CACHE="$C" MEOW_RAIZ="$CLONE" \
    ESPACO_REGISTRO="${ESPACO_REGISTRO_USADO:-$REGISTRO}" ESPACO_VERSAO_DO_PACOTE="${VERSAO_COMP:-}" \
    ESPACO_DISCO_USO_PCT="${USO_PCT:-10}" ESPACO_GUARDA_DO_COMPOSITOR="$M/guarda" \
    MEOW_GUARDAR_BACKUPS="${GUARDAR:-0}" python3 "$ESPACO" "$@"
}

grande() { head -c "$2" /dev/zero > "$1"; }
velho() { find "$1" -exec touch -d "${2:-3 hours ago}" {} + 2>/dev/null; }
hash_de() { printf '%s' "$1" | md5sum | cut -c1-16; }
kb() { du -sk "$@" 2>/dev/null | awk '{s+=$1} END {print s+0}'; }

echo "== 1. o inventário"
n=$(grep -c . "$REGISTRO")
[ "$n" -ge 25 ] && ok "o registro tem $n linhas" || falha "registro curto: $n"
cats="$(cut -f2 "$REGISTRO" | sort -u | tr '\n' '|')"
igual "só as três categorias" "$cats" "backup|de quem usa|reconstruível|"
semcampo="$(awk -F'\t' 'NF != 9 {print NR": "NF}' "$REGISTRO")"
[ -z "$semcampo" ] && ok "toda linha tem os nove campos" || falha "linha torta: $semcampo"
dupes="$(cut -f1 "$REGISTRO" | sort | uniq -d)"
[ -z "$dupes" ] && ok "nenhum id repetido" || falha "id repetido: $dupes"
for nao_cortavel in "de quem usa"; do
  corta="$(awk -F'\t' -v c="$nao_cortavel" '$2 == c && $7 != "nunca" {print $1}' "$REGISTRO")"
  [ -z "$corta" ] && ok "o que é de quem usa nunca tem corte" || falha "de quem usa com corte: $corta"
done
teto_fixo="$(awk -F'\t' '$1 == "extensoes-alvo" {print $6}' "$REGISTRO")"
igual "o .target tem teto fixo de 8 GB" "$teto_fixo" "8192"
igual "o compositor guarda a versão em uso e uma anterior" "$(awk -F'\t' '$1 == "compositor-cache" {print $7}' "$REGISTRO")" "versoes:2"
igual "os backups guardam 30 dias" "$(awk -F'\t' '$1 == "backups" {print $7}' "$REGISTRO")" "rotacao:30:100"

mundo
nomes_do_codigo="$(cd "$RAIZ" && { grep -rhoE '(\$MEOW_ESTADO|\$\{MEOW_ESTADO\}|\$\{MEOW_ESTADO:-[^}]*\}|\$HOME/\.local/state/meowsystem)/[A-Za-z0-9_.-]+' bin lib scripts install.sh app/run.sh app/servidor.py 2>/dev/null
  grep -hoE 'ESTADO, "[A-Za-z0-9_.-]+"' app/servidor.py | sed -E 's|.*"(.*)"|/\1|'; } | sed -E 's|^.*/||' | grep -v '^meowsystem$' | sort -u)"
cache_do_codigo="$(cd "$RAIZ" && grep -rhoE '(\$MEOW_CACHE|\$\{MEOW_CACHE\}|\$\{MEOW_CACHE:-[^}]*\}|\$HOME/\.cache/meowsystem|\$\{XDG_CACHE_HOME:-[^}]*\}/meowsystem)/[A-Za-z0-9_.-]+' bin lib scripts install.sh app/run.sh app/servidor.py 2>/dev/null \
  | sed -E 's|^.*/||' | grep -v '^meowsystem$' | sort -u)"
for nome in $nomes_do_codigo; do mkdir -p "$E/$nome" 2>/dev/null || : > "$E/$nome"; done
for nome in $cache_do_codigo; do mkdir -p "$C/$nome"; done
mkdir -p "$LIBEXEC/cosmic-comp" "$LIBEXEC/oraculo-tema" "$LIBEXEC/graficos" "$C/graficos" "$CASA/.local/share/meowsystem/fastfetch" \
  "$CASA/.local/share/meowsystem/packs" "$CASA/.local/share/meowsystem/temas-de-apps" "$CASA/.local/share/meowsystem/bin" \
  "$CASA/.config/meowsystem/extensoes" "$CASA/.config/meow" "$C/pintados" "$C/painel" "$E/vizinhos" "$E/paineis" "$E/zapzap"
: > "$C/flatpak-libadwaita.tsv"; : > "$CASA/.config/meow/meow.conf"
for nome in navegador painel paineis restauros vizinhos; do
  [ -e "$E/$nome" ] && ok "a varredura achou o que o código escreve: $nome" || falha "a varredura não achou $nome"
done
sem_dono="$(esp cobre)"; rc=$?
igual "todo caminho que o código escreve em estado e cache tem dono no registro" "$rc" 0
[ -n "$sem_dono" ] && printf '        sem dono: %s\n' "$sem_dono"
printf 'x' > "$E/arquivo-que-ninguem-declarou"
sem_dono="$(esp cobre)"; rc=$?
igual "um caminho novo sem linha no registro é defeito" "$rc" 1
case "$sem_dono" in *arquivo-que-ninguem-declarou*) ok "e o teste diz qual" ;; *) falha "não apontou: $sem_dono" ;; esac

echo "== 1b. build de verdade em HOME temporário: tudo o que nasceu está no registro"
FK="$T/fork"; PF="$T/pinos"; mkdir -p "$FK/data" "$PF"
(
  cd "$FK" && git init -q -b main . && git config user.email t@t && git config user.name t
  printf '[package]\nname = "x"\n' > Cargo.toml
  printf '[Desktop Entry]\nExec=@bindir@/meowsystem-teste\n' > data/io.github.meowsystem.Fake.desktop.in
  printf 'um\n' > versao.txt
  git add -A && git -c core.hooksPath=/dev/null commit -q -m um
)
commit() { git -C "$FK" rev-parse HEAD; }
pino() {
  cat > "$PF/fake.pino" <<FIM
ORDEM=1
NOME="Fake"
URL="$FK"
COMMIT="$(commit)"
VERSAO="0.1.0"
LIBCOSMIC="1111111111111111111111111111111111111111"
APP_ID="io.github.meowsystem.Fake"
BIN="meowsystem-teste"
DESKTOP="data/io.github.meowsystem.Fake.desktop.in"
FIM
}
cat > "$T/bin/cargo" <<'FIM'
#!/bin/sh
d="${CARGO_TARGET_DIR:-target}/release"
h="$(printf '%s' "$(cat "$FALSO_VERSAO")" | md5sum | cut -c1-16)"
hb="$(printf 'bin%s' "$(cat "$FALSO_VERSAO")" | md5sum | cut -c1-16)"
json=0
for a in "$@"; do [ "$a" = "--message-format=json" ] && json=1; done
if [ "$json" = 1 ]; then
  printf '{"reason":"compiler-artifact","filenames":["%s/deps/libdep-%s.rlib","%s/deps/libdep-%s.rmeta"],"fresh":true}\n' "$d" "$h" "$d" "$h"
  printf '{"reason":"build-script-executed","out_dir":"%s/build/dep-%s/out"}\n' "$d" "$h"
  printf '{"reason":"compiler-artifact","filenames":["%s/%s"],"executable":"%s/%s","fresh":true}\n' "$d" "$FAKE_BIN" "$d" "$FAKE_BIN"
  printf '{"reason":"build-finished","success":true}\n'
  exit 0
fi
case "$1" in
  build)
    mkdir -p "$d/deps" "$d/.fingerprint/dep-$h" "$d/.fingerprint/app-$hb" "$d/build/dep-$h/out"
    head -c 400000 /dev/zero > "$d/deps/libdep-$h.rlib"
    head -c 100000 /dev/zero > "$d/deps/libdep-$h.rmeta"
    printf 'x' > "$d/deps/dep-$h.d"
    printf 'x' > "$d/.fingerprint/dep-$h/dep.json"
    printf 'x' > "$d/build/dep-$h/out/saida"
    printf 'x' > "$d/.fingerprint/app-$hb/bin.json"
    printf '#!/bin/sh\n' > "$d/deps/meowsystem_teste-$hb"; chmod 755 "$d/deps/meowsystem_teste-$hb"
    rm -f "$d/$FAKE_BIN"; ln "$d/deps/meowsystem_teste-$hb" "$d/$FAKE_BIN" ;;
esac
exit 0
FIM
chmod 755 "$T/bin/cargo"

construir() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" NO_COLOR=1 USER=t FAKE_BIN=meowsystem-teste FALSO_VERSAO="$T/versao" \
    XDG_DATA_HOME="$CASA/.local/share" XDG_CONFIG_HOME="$CASA/.config" MEOW_ESTADO="$E" MEOW_CACHE="$C" \
    EXTENSOES_PINOS="$PF" EXTENSOES_PERMITE_LOCAL=1 EXTENSOES_COMPILAR=1 AP_LOCK_PAINEL="$M/painel.lock" \
    ESPACO_DISCO_USO_PCT=10 \
    bash "$RAIZ/scripts/extensoes_build.sh" fake --aplicar >"$M/construir.log" 2>&1
}

mundo
printf '[[package]]\nname = "libcosmic"\nsource = "git+https://github.com/pop-os/libcosmic#1111111111111111111111111111111111111111"\n' > "$M/painel.lock"
printf 'v1' > "$T/versao"
pino
construir
H1="$(hash_de v1)"
ALVO="$E/extensoes/.target"
[ -x "$CASA/.local/bin/meowsystem-teste" ] && ok "o applet falso compilou e instalou" || falha "não instalou: $(tail -4 "$M/construir.log")"
[ -s "$E/extensoes/fake/uso.lista" ] && grep -qx "$H1" "$E/extensoes/fake/uso.lista" \
  && ok "o fim do build registrou as unidades em uso" || falha "sem uso.lista: $(cat "$E/extensoes/fake/uso.lista" 2>/dev/null)"
sem_dono="$(esp cobre)"; rc=$?
igual "tudo o que o build criou em estado e cache está no registro" "$rc" 0
[ -n "$sem_dono" ] && printf '        sem dono: %s\n' "$sem_dono"
fora="$(esp cobre --casa)"; rc=$?
igual "e nada do que o build criou na casa fica sem dono" "$rc" 0
[ -n "$fora" ] && printf '        sem dono: %s\n' "$fora"
printf 'x' > "$CASA/.local/share/applications/de-outro.desktop"
fora="$(esp cobre --casa)"; rc=$?
igual "um arquivo que não é do Meow na casa é apontado" "$rc" 1
rm -f "$CASA/.local/share/applications/de-outro.desktop"

echo "== 2. dois builds com versões diferentes de dependência: o .target não soma os dois"
TAM1="$(kb "$ALVO")"
velho "$ALVO"
printf 'v2' > "$T/versao"
printf 'dois\n' > "$FK/versao.txt"
(cd "$FK" && git add -A && git -c core.hooksPath=/dev/null commit -q -m dois)
pino
construir
H2="$(hash_de v2)"
[ -e "$ALVO/release/deps/libdep-$H2.rlib" ] && ok "a versão nova está no .target" || falha "versão nova ausente: $(tail -4 "$M/construir.log")"
[ ! -e "$ALVO/release/deps/libdep-$H1.rlib" ] && ok "a versão velha saiu no fim do build" || falha "a versão velha ficou"
[ ! -e "$ALVO/release/.fingerprint/dep-$H1" ] && [ ! -e "$ALVO/release/build/dep-$H1" ] \
  && ok "e o fingerprint e a saída do build dela também" || falha "restos da versão velha"
TAM2="$(kb "$ALVO")"
perto "o tamanho depois dos dois builds é o de um só" "$TAM2" "$TAM1" 20
grep -q 'cortou Applets' "$M/construir.log" && ok "o build conta o que cortou" || falha "o build não disse nada: $(tail -6 "$M/construir.log")"
[ -x "$CASA/.local/bin/meowsystem-teste" ] && ok "o binário instalado segue de pé" || falha "o binário sumiu"
saida="$(esp continua)"; rc=$?
igual "a segunda passada não corta nada" "$rc" 0
HB2="$(hash_de binv2)"
grep -qx "$HB2" "$E/extensoes/fake/uso.lista" && ok "a unidade do próprio binário está na lista, mesmo o cargo citando só release/<bin>" \
  || falha "a unidade do binário ficou fora da lista: $(cat "$E/extensoes/fake/uso.lista")"
velho "$ALVO"
saida="$(esp aparar)"; rc=$?
igual "com tudo parado há horas, o doctor não acha o que cortar no build atual" "$rc" 0
[ -e "$ALVO/release/deps/meowsystem_teste-$HB2" ] && [ -e "$ALVO/release/.fingerprint/app-$HB2" ] \
  && ok "e a unidade do binário fica, senão o próximo build recompila o applet" || falha "o doctor cortou a unidade do binário em uso"

echo "== 3. cache acima do teto: o doctor corta, o build em uso fica de pé, e nunca durante um build"
mundo
REG="$M/registro.tsv"
sed 's#^\(extensoes-alvo\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t\)8192#\11#' "$REGISTRO" > "$REG"
ESPACO_REGISTRO_USADO="$REG"
mkdir -p "$E/extensoes/a" "$E/extensoes/.target/release/deps"
printf 'x' > "$E/extensoes/a/carimbo"
alvo="$E/extensoes/.target"
for h in 0000000000000001 0000000000000002 0000000000000003 0000000000000004; do grande "$alvo/release/deps/libx-$h.rlib" 500000; done
printf '#!/bin/sh\n' > "$alvo/release/meowsystem-a"; chmod 755 "$alvo/release/meowsystem-a"
touch -d '4 hours ago' "$alvo/release/deps/libx-0000000000000001.rlib"
touch -d '3 hours ago' "$alvo/release/deps/libx-0000000000000002.rlib"
touch -d '2 hours ago' "$alvo/release/deps/libx-0000000000000003.rlib"
touch -d '1 hour ago'  "$alvo/release/deps/libx-0000000000000004.rlib"
printf '#!/bin/sh\n' > "$CASA/binario-instalado"
saida="$(esp conferir)"; rc=$?
igual "acima do teto, o doctor acusa (divergente)" "$rc" 1
case "$saida" in *"para cortar"*) ok "e diz quanto há para cortar" ;; *) falha "sem o aviso: $saida" ;; esac
exec 8>>"$alvo/release/.cargo-lock"; flock -n 8
saida="$(esp aparar)"; rc=$?
igual "com um build em curso nada é cortado" "$rc" 0
n="$(ls "$alvo/release/deps" | wc -l)"
igual "as quatro unidades seguem lá" "$n" 4
saida="$(esp conferir)"; rc=$?
igual "e o doctor espera, sem acusar" "$rc" 0
case "$saida" in *"build em curso"*) ok "dizendo que há build em curso" ;; *) falha "sem aviso do build: $saida" ;; esac
flock -u 8; exec 8>&-
saida="$(esp aparar)"; rc=$?
igual "livre o build, o doctor corta" "$rc" 1
[ ! -e "$alvo/release/deps/libx-0000000000000001.rlib" ] && ok "o mais velho saiu primeiro" || falha "o mais velho ficou"
[ -e "$alvo/release/deps/libx-0000000000000004.rlib" ] && ok "o mais novo ficou" || falha "o mais novo saiu"
[ -x "$alvo/release/meowsystem-a" ] && ok "o binário do build em uso continua de pé" || falha "o binário do build saiu"
saida="$(esp conferir)"; rc=$?
igual "depois do corte o doctor confere" "$rc" 0
saida="$(esp aparar)"; rc=$?
igual "a segunda passada não escreve nada" "$rc" 0

echo "== 3b. o que está em uso por um applet instalado nunca é cortado, e o resto sai"
mundo
mkdir -p "$E/extensoes/a" "$E/extensoes/.target/release/deps" "$E/extensoes/.target/release/.fingerprint"
alvo="$E/extensoes/.target"
printf 'x' > "$E/extensoes/a/carimbo"
printf 'aaaaaaaaaaaaaaaa\n' > "$E/extensoes/a/uso.lista"
grande "$alvo/release/deps/libusada-aaaaaaaaaaaaaaaa.rlib" 300000
grande "$alvo/release/deps/libvelha-bbbbbbbbbbbbbbbb.rlib" 300000
grande "$alvo/release/deps/libnova-cccccccccccccccc.rlib" 300000
mkdir -p "$alvo/release/.fingerprint/velha-bbbbbbbbbbbbbbbb" "$alvo/debug"
printf 'x' > "$alvo/release/.fingerprint/velha-bbbbbbbbbbbbbbbb/velha.json"
grande "$alvo/debug/lixo" 200000
velho "$alvo/release/deps/libusada-aaaaaaaaaaaaaaaa.rlib" "2 days ago"
velho "$alvo/release/deps/libvelha-bbbbbbbbbbbbbbbb.rlib" "2 hours ago"
velho "$alvo/release/.fingerprint/velha-bbbbbbbbbbbbbbbb" "2 hours ago"
saida="$(esp aparar)"; rc=$?
[ -e "$alvo/release/deps/libusada-aaaaaaaaaaaaaaaa.rlib" ] && ok "a unidade do build atual fica mesmo velha" || falha "a unidade em uso saiu"
[ ! -e "$alvo/release/deps/libvelha-bbbbbbbbbbbbbbbb.rlib" ] && ok "a de fora do build atual sai" || falha "a velha ficou"
[ ! -e "$alvo/release/.fingerprint/velha-bbbbbbbbbbbbbbbb" ] && ok "com o fingerprint dela" || falha "fingerprint ficou"
[ -e "$alvo/release/deps/libnova-cccccccccccccccc.rlib" ] && ok "a de agora, que um build pode estar escrevendo, fica" || falha "a recente saiu"
[ ! -e "$alvo/debug" ] && ok "o perfil que ninguém usa sai" || falha "debug ficou"
rm -f "$E/extensoes/a/uso.lista"
touch -d '8 days ago' "$alvo/release/deps/libnova-cccccccccccccccc.rlib"
saida="$(esp aparar)"
[ ! -e "$alvo/release/deps/libnova-cccccccccccccccc.rlib" ] && ok "sem lista de uso, a de oito dias saiu" || falha "a de oito dias ficou"
[ -e "$alvo/release/deps/libusada-aaaaaaaaaaaaaaaa.rlib" ] && ok "e a de dois dias, sem lista, fica" || falha "a de dois dias saiu"

mundo
mkdir -p "$E/extensoes/com" "$E/extensoes/sem" "$E/extensoes/.target/release/deps"
alvo="$E/extensoes/.target"
printf 'x' > "$E/extensoes/com/carimbo"; printf 'x' > "$E/extensoes/sem/carimbo"
printf 'aaaaaaaaaaaaaaaa\n' > "$E/extensoes/com/uso.lista"
grande "$alvo/release/deps/libcom-aaaaaaaaaaaaaaaa.rlib" 300000
grande "$alvo/release/deps/libvelha-bbbbbbbbbbbbbbbb.rlib" 300000
touch -d '9 days ago' "$alvo/release/deps/libcom-aaaaaaaaaaaaaaaa.rlib" "$alvo/release/deps/libvelha-bbbbbbbbbbbbbbbb.rlib"
saida="$(esp aparar)"
[ -e "$alvo/release/deps/libcom-aaaaaaaaaaaaaaaa.rlib" ] && ok "com um applet ainda sem lista, a lista do outro segue protegendo" || falha "a unidade listada saiu por idade"
[ ! -e "$alvo/release/deps/libvelha-bbbbbbbbbbbbbbbb.rlib" ] && ok "e o que ninguém lista sai por idade" || falha "a velha ficou"

echo "== 3c. disco apertado: os tetos pela metade"
mundo
REG="$M/registro.tsv"
sed 's#^\(extensoes-alvo\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t\)8192#\12#' "$REGISTRO" > "$REG"
ESPACO_REGISTRO_USADO="$REG"
mkdir -p "$E/extensoes/.target/release/deps"
alvo="$E/extensoes/.target"
for i in 1 2 3 4; do
  grande "$alvo/release/deps/libx-000000000000000$i.rlib" 600000
  touch -d "$((i + 1)) hours ago" "$alvo/release/deps/libx-000000000000000$i.rlib"
done
USO_PCT=10
saida="$(esp aparar)"
n_folgado="$(ls "$alvo/release/deps" | wc -l)"
USO_PCT=92
for i in 1 2 3 4; do
  grande "$alvo/release/deps/libx-000000000000000$i.rlib" 600000
  touch -d "$((i + 1)) hours ago" "$alvo/release/deps/libx-000000000000000$i.rlib"
done
saida="$(esp aparar)"
n_apertado="$(ls "$alvo/release/deps" | wc -l)"
[ "$n_apertado" -lt "$n_folgado" ] && ok "apertado, ficam menos unidades ($n_apertado) do que folgado ($n_folgado)" || falha "o aperto não cortou mais ($n_apertado contra $n_folgado)"
case "$saida" in *apertado*) falha "disco apertado não aparece na tela (decisão 27): $saida" ;; *) ok "e aperta sem aviso" ;; esac
case "$(esp conferir)" in *apertado*) falha "a linha do doctor fala do aperto" ;; *) ok "nem na linha do doctor" ;; esac
USO_PCT=10; ESPACO_REGISTRO_USADO=""

echo "== 4. backups acima da rotação: ficam os mais novos e o tema-PRIMEIRO"
mundo
mkdir -p "$E/backups"
for d in 3 8 15 25; do mkdir -p "$E/backups/$(date -d "$d days ago" +%Y-%m-%dT%H-%M-%S)-tema"; done
for d in 31 40 90 200 365; do mkdir -p "$E/backups/$(date -d "$d days ago" +%Y-%m-%dT%H-%M-%S)-vizinho"; done
mkdir -p "$E/backups/$(date -d '700 days ago' +%Y-%m-%dT%H-%M-%S)-tema-PRIMEIRO-pre-instalacao"
mkdir -p "$E/backups/$(date -d '700 days ago' +%Y-%m-%dT%H-%M-%S)-sistema"
mkdir -p "$E/backups/$(date -d '700 days ago' +%Y-%m-%dT%H-%M-%S)-meow.conf-antes-da-instalacao"
saida="$(esp aparar)"; rc=$?
igual "a rotação por idade corta" "$rc" 1
igual "ficam os quatro dos últimos 30 dias e os três protegidos" "$(ls "$E/backups" | wc -l)" 7
ls "$E/backups" | grep -q 'tema-PRIMEIRO' && ok "o tema-PRIMEIRO ficou" || falha "o PRIMEIRO saiu"
ls "$E/backups" | grep -q -- '-sistema$' && ok "o -sistema ficou" || falha "o -sistema saiu"
ls "$E/backups" | grep -q -- '-meow.conf-antes-da-instalacao$' && ok "o meow.conf de antes da instalação ficou" || falha "o meow.conf de antes da instalação saiu"
ls "$E/backups" | grep -q -- '-vizinho$' && falha "sobrou um backup velho" || ok "nenhum backup velho sobrou"
saida="$(esp aparar)"; rc=$?
igual "a segunda passada não corta nada" "$rc" 0

mundo
mkdir -p "$E/backups"
BASE_B="$(date -d '20 days ago' +%s)"
for i in $(seq 1 130); do mkdir -p "$E/backups/$(date -d "@$((BASE_B + i * 60))" +%Y-%m-%dT%H-%M-%S)-op"; done
mkdir -p "$E/backups/2020-01-01T00-00-00-tema-PRIMEIRO-pre-instalacao"
saida="$(esp aparar)"
igual "130 recentes: sobram os 100 mais novos e o tema-PRIMEIRO" "$(ls "$E/backups" | wc -l)" 101
mais_novo="$(ls "$E/backups" | grep -v PRIMEIRO | sort | tail -1)"
esperado="$(date -d "@$((BASE_B + 130 * 60))" +%Y-%m-%dT%H-%M-%S)-op"
igual "e o mais novo de todos está lá" "$mais_novo" "$esperado"
mais_velho="$(ls "$E/backups" | grep -v PRIMEIRO | sort | head -1)"
esperado="$(date -d "@$((BASE_B + 31 * 60))" +%Y-%m-%dT%H-%M-%S)-op"
igual "e o corte foi no 101º" "$mais_velho" "$esperado"

echo "== 4b. o compositor guarda a versão em uso e uma anterior"
mundo
mkdir -p "$C/cosmic-comp"
for v in 1.0 1.1 1.2; do mkdir -p "$C/cosmic-comp/cosmic-comp-$v/target"; grande "$C/cosmic-comp/cosmic-comp-$v/target/f" 200000; printf 'x' > "$C/cosmic-comp/compilar-$v.log"; done
touch -d '9 days ago' "$C/cosmic-comp/cosmic-comp-1.0"; touch -d '5 days ago' "$C/cosmic-comp/cosmic-comp-1.1"; touch -d '1 day ago' "$C/cosmic-comp/cosmic-comp-1.2"
for v in 1.0 1.1 1.2; do find "$C/cosmic-comp/cosmic-comp-$v" -exec touch -d "$(stat -c %y "$C/cosmic-comp/cosmic-comp-$v")" {} +; done
VERSAO_COMP=1.2
saida="$(esp aparar)"; rc=$?
[ ! -d "$C/cosmic-comp/cosmic-comp-1.0" ] && ok "a versão mais velha saiu" || falha "a 1.0 ficou"
[ -d "$C/cosmic-comp/cosmic-comp-1.1" ] && [ -d "$C/cosmic-comp/cosmic-comp-1.2" ] && ok "a em uso e a anterior ficaram" || falha "perdeu uma que devia ficar"
[ ! -e "$C/cosmic-comp/compilar-1.0.log" ] && [ -e "$C/cosmic-comp/compilar-1.2.log" ] && ok "o registro da que saiu foi junto" || falha "registros fora do lugar"
mkdir -p "$M/guarda"; printf 'x' > "$C/cosmic-comp/cosmic-comp_1.2.dsc"; printf 'x' > "$M/guarda/cosmic-comp_1.2.dsc"
printf 'x' > "$C/cosmic-comp/cosmic-comp_1.1.dsc"
saida="$(esp aparar)"
[ ! -e "$C/cosmic-comp/cosmic-comp_1.2.dsc" ] && ok "o fonte que já está guardado sai do cache" || falha "dsc guardado ficou"
[ -e "$C/cosmic-comp/cosmic-comp_1.1.dsc" ] && ok "e o que não está guardado fica" || falha "dsc sem guarda saiu"
VERSAO_COMP=""

echo "== 4b2. o que já está pronto ou baixado de versões antigas: ficam a em uso e uma anterior"
mundo
GUARDA_F="$CASA/.local/share/meowsystem/fontes"
mkdir -p "$LIBEXEC/cosmic-comp" "$E/cosmic-files" "$GUARDA_F/cosmic-comp"
for v in 1.0 1.1 1.2 1.3; do
  mkdir -p "$LIBEXEC/cosmic-comp/$v" "$E/cosmic-files/$v"
  grande "$LIBEXEC/cosmic-comp/$v/cosmic-comp" 100000
  grande "$E/cosmic-files/$v/cosmic-files" 100000
  printf 'x' > "$E/cosmic-files/$v.tentado"
  grande "$GUARDA_F/cosmic-comp/cosmic-comp_$v.tar.xz" 100000
  printf 'x' > "$GUARDA_F/cosmic-comp/cosmic-comp_$v.dsc"
done
printf 'x' > "$E/cosmic-files/1.4.tentado"
for v in 1.0 1.1 1.2 1.3; do
  dias="$(( 40 - ${v#1.} * 10 ))"
  find "$LIBEXEC/cosmic-comp/$v" "$E/cosmic-files/$v" "$E/cosmic-files/$v.tentado" "$GUARDA_F/cosmic-comp/cosmic-comp_$v".* -exec touch -d "$dias days ago" {} +
done
VERSAO_COMP=1.1
json="$(esp json)"
refaz="$(printf '%s' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["refazer"])')"
igual "tirar versão antiga não põe preço de refazer no Liberar" "$refaz" 0
saida="$(esp aparar)"; rc=$?
igual "o doctor corta o que passou das duas versões" "$rc" 1
for caminho in "$LIBEXEC/cosmic-comp" "$E/cosmic-files"; do
  [ -d "$caminho/1.1" ] && ok "a versão em uso fica, mesmo mais velha: ${caminho##*/}" || falha "cortou a versão em uso em $caminho"
  [ -d "$caminho/1.3" ] && ok "a mais nova fica: ${caminho##*/}" || falha "cortou a mais nova em $caminho"
  [ ! -d "$caminho/1.0" ] && [ ! -d "$caminho/1.2" ] && ok "as outras saem: ${caminho##*/}" || falha "sobrou versão antiga em $caminho"
done
[ -e "$E/cosmic-files/1.1.tentado" ] && [ ! -e "$E/cosmic-files/1.0.tentado" ] && ok "a marca de tentativa acompanha a versão" || falha "marca de tentativa fora do lugar"
[ -e "$GUARDA_F/cosmic-comp/cosmic-comp_1.1.tar.xz" ] && [ -e "$GUARDA_F/cosmic-comp/cosmic-comp_1.3.dsc" ] \
  && [ ! -e "$GUARDA_F/cosmic-comp/cosmic-comp_1.2.tar.xz" ] && [ ! -e "$GUARDA_F/cosmic-comp/cosmic-comp_1.0.dsc" ] \
  && ok "e os fontes guardados seguem a mesma conta" || falha "fontes guardados fora do lugar: $(ls "$GUARDA_F/cosmic-comp")"
saida="$(esp aparar)"; rc=$?
igual "a segunda passada não corta nada" "$rc" 0
mkdir -p "$LIBEXEC/cosmic-comp/1.4"
VERSAO_COMP=1.9
saida="$(esp aparar)"
[ -d "$LIBEXEC/cosmic-comp/1.4" ] && [ -d "$LIBEXEC/cosmic-comp/1.3" ] && [ ! -d "$LIBEXEC/cosmic-comp/1.1" ] \
  && ok "pacote novo ainda sem build: ficam os dois mais novos" || falha "versão sem build tomou lugar: $(ls "$LIBEXEC/cosmic-comp")"
VERSAO_COMP=""

echo "== 4c. resíduos: o target esquecido no clone, a prévia e o oráculo parados"
mundo
mkdir -p "$CLONE/src/applets/leitura/target" "$CLONE/src/oraculo-tema/target" "$C/cosmic-prever/serie" "$C/oraculo-tema/rev1"
grande "$CLONE/src/applets/leitura/target/f" 100000
grande "$C/cosmic-prever/serie/f" 100000
grande "$C/oraculo-tema/rev1/f" 100000
touch -d '8 days ago' "$C/cosmic-prever/serie/f" "$C/cosmic-prever/serie"
mkdir -p "$C/oraculo-tema/rev2"; grande "$C/oraculo-tema/rev2/f" 100000
saida="$(esp aparar)"
[ ! -e "$CLONE/src/applets/leitura/target" ] && [ ! -e "$CLONE/src/oraculo-tema/target" ] && ok "o target órfão do clone sai" || falha "target órfão ficou"
[ ! -e "$C/cosmic-prever/serie" ] && ok "a prévia parada há mais de uma semana sai" || falha "prévia ficou"
[ -e "$C/oraculo-tema/rev1" ] && ok "o oráculo mexido agora fica" || falha "oráculo recente saiu"

echo "== 4d. medir não renova a idade: a leitura da pasta acerta o atime dela"
mundo
mkdir -p "$C/cosmic-prever/lida/sub" "$C/cosmic-prever/usada"
grande "$C/cosmic-prever/lida/sub/f" 1000
grande "$C/cosmic-prever/usada/f" 1000
touch -d '8 days ago' "$C/cosmic-prever/lida/sub/f" "$C/cosmic-prever/lida/sub" "$C/cosmic-prever/lida" "$C/cosmic-prever/usada/f" "$C/cosmic-prever/usada"
touch -a "$C/cosmic-prever/lida" "$C/cosmic-prever/lida/sub" "$C/cosmic-prever/usada/f"
saida="$(esp aparar)"
[ ! -e "$C/cosmic-prever/lida" ] && ok "pasta com atime novo e nada mexido dentro sai" || falha "a leitura do doctor renovou a idade da pasta"
[ -e "$C/cosmic-prever/usada" ] && ok "arquivo lido agora conta como uso" || falha "o atime do arquivo foi ignorado"

echo "== 5. o espaço do meow bate com o du"
mundo
mkdir -p "$E/extensoes/.target/release/deps" "$E/extensoes/a/src" "$C/cosmic-comp/cosmic-comp-1.0" "$C/upstream" "$LIBEXEC/cosmic-comp/1.0"
grande "$E/extensoes/.target/release/deps/libx-0000000000000001.rlib" 9000000
grande "$E/extensoes/a/src/f" 800000
AGORA_B="$(date +%Y-%m-%dT%H-%M-%S)-x"; mkdir -p "$E/backups/$AGORA_B"
grande "$E/backups/$AGORA_B/f" 2500000
grande "$C/cosmic-comp/cosmic-comp-1.0/f" 4000000
grande "$C/upstream/f" 1200000
grande "$LIBEXEC/cosmic-comp/1.0/cosmic-comp" 3000000
printf 'x\n' > "$E/pendencias.tsv"
ln "$C/upstream/f" "$C/upstream/f2"
json="$(esp json)"
total="$(printf '%s' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["total"])')"
du_kb="$(kb "$E" "$C" "$LIBEXEC")"
perto "o total do json contra o du, em bytes" "$total" "$((du_kb * 1024))" 5
rel="$(esp ver)"
case "$rel" in *"o MeowSystem ocupa"*"reconstruível"*"backup"*"de quem usa"*) ok "o relatório mostra as três categorias" ;; *) falha "relatório torto: $rel" ;; esac
por_cat="$(printf '%s' "$json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(sum(c["bytes"] for c in d["categorias"]))')"
igual "as categorias somam o total" "$por_cat" "$total"
libera="$(printf '%s' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["liberavel"])')"
alvo_kb="$(kb "$E/extensoes/.target" "$C/cosmic-comp")"
perto "o liberável bate com o du do que é reconstruível e cortável" "$libera" "$((alvo_kb * 1024))" 5
refaz="$(printf '%s' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["refazer"])')"
igual "o preço é a soma do tempo de refazer o que sai (10 min dos applets e 4 do compositor)" "$refaz" 14
saida="$(esp liberar)"; rc=$?
igual "liberar corta" "$rc" 1
[ ! -e "$E/extensoes/.target" ] && [ ! -e "$C/cosmic-comp" ] && ok "o .target e o cache do compositor saíram" || falha "restou o que devia sair"
[ -e "$LIBEXEC/cosmic-comp/1.0/cosmic-comp" ] && ok "o compositor em uso ficou" || falha "o compositor em uso saiu"
[ -e "$E/pendencias.tsv" ] && [ -e "$E/backups/$AGORA_B/f" ] && ok "o que é de quem usa e o backup recente ficaram" || falha "liberar tocou no que não devia"
[ -e "$C/upstream/f" ] && ok "o que só se baixa de novo com a rede ficou" || falha "upstream saiu"
saida="$(esp liberar)"; rc=$?
igual "a segunda passada não tem o que liberar" "$rc" 0

echo "== 5b. liberar nunca corta durante um build"
mundo
mkdir -p "$E/extensoes/.target/release/deps" "$E/extensoes/a" "$C/cosmic-comp/cosmic-comp-1.0/target/release"
grande "$E/extensoes/.target/release/deps/libx-0000000000000001.rlib" 300000
grande "$C/cosmic-comp/cosmic-comp-1.0/target/release/f" 300000
: > "$C/cosmic-comp/cosmic-comp-1.0/target/release/.cargo-lock"
exec 8>>"$C/cosmic-comp/cosmic-comp-1.0/target/release/.cargo-lock"; flock -n 8
saida="$(esp liberar)"
[ -e "$C/cosmic-comp/cosmic-comp-1.0/target/release/f" ] && ok "o compositor em compilação não é cortado" || falha "cortou um build em curso"
[ ! -e "$E/extensoes/.target" ] && ok "e o resto sai" || falha "o resto não saiu"
case "$saida" in *"build em curso"*) ok "dizendo que ficou para depois" ;; *) falha "sem aviso: $saida" ;; esac
flock -u 8; exec 8>&-
mundo
mkdir -p "$E/extensoes/.target/release/deps"
grande "$E/extensoes/.target/release/deps/libx-0000000000000001.rlib" 300000
: > "$E/builds.lock"
exec 8>>"$E/builds.lock"; flock -n 8
saida="$(esp liberar)"
[ -e "$E/extensoes/.target/release/deps/libx-0000000000000001.rlib" ] && ok "com o builds.lock tomado nada sai" || falha "cortou com a trava dos builds tomada"
flock -u 8; exec 8>&-

echo "== 6. o desinstalar usa o inventário"
mundo
ESPACO_REGISTRO_USADO=""
mkdir -p "$E/extensoes/.target/release/deps" "$E/extensoes/usuario" "$E/extensoes/a/src" "$E/backups/2026-01-01T00-00-00-x" \
  "$E/oficina" "$E/papeis-de-parede" "$C/cosmic-comp/cosmic-comp-1.0" "$C/upstream" "$LIBEXEC/cosmic-comp/1.0" "$LIBEXEC/oraculo-tema" \
  "$CASA/.local/share/meowsystem/packs/meu" "$CASA/.local/share/meowsystem/fastfetch" "$CASA/.config/meowsystem" \
  "$E/cosmic-files" "$E/temas" "$E/cosmic-comp"
grande "$E/extensoes/.target/release/deps/libx-0000000000000001.rlib" 5000000
grande "$E/extensoes/a/src/f" 700000
grande "$E/backups/2026-01-01T00-00-00-x/f" 1500000
grande "$C/cosmic-comp/cosmic-comp-1.0/f" 3000000
grande "$C/upstream/f" 600000
grande "$LIBEXEC/cosmic-comp/1.0/cosmic-comp" 2000000
grande "$E/cosmic-files/f" 900000
grande "$E/oficina/meu.svg" 20000
grande "$E/papeis-de-parede/BANIDOS.txt" 5000
grande "$CASA/.local/share/meowsystem/packs/meu/pack.json" 5000
printf 'pino\n' > "$E/extensoes/usuario/meu.pino"
for f in pendencias.tsv manifesto.tsv meow.log raiz lock builds.lock; do printf 'x\n' > "$E/$f"; done
sairao="$(cd "$M" && kb "$E/extensoes/.target" "$E/extensoes/a" "$E/backups" "$C" "$LIBEXEC" "$E/cosmic-files" "$E/temas" "$E/cosmic-comp" \
  "$E/pendencias.tsv" "$E/manifesto.tsv" "$E/meow.log" "$E/raiz" "$E/lock" "$E/builds.lock")"
saida="$(esp desinstalar)"; rc=$?
liberou="${saida%%$'\t'*}"
igual "o desinstalar do inventário termina certo" "$rc" 0
perto "o valor que ele diz bate com o medido" "$liberou" "$((sairao * 1024))" 5
for f in "$E/extensoes/.target" "$E/extensoes/a" "$E/backups" "$C/cosmic-comp" "$C/upstream" "$LIBEXEC/cosmic-comp" "$E/cosmic-files" \
  "$E/pendencias.tsv" "$E/manifesto.tsv" "$E/meow.log" "$E/raiz" "$E/temas" "$E/cosmic-comp" "$E/lock"; do
  [ ! -e "$f" ] || falha "sobrou do inventário: ${f#"$M/"}"
done
[ ! -e "$E/extensoes/.target" ] && [ ! -e "$E/backups" ] && [ ! -e "$LIBEXEC/cosmic-comp" ] && ok "nenhum caminho do inventário que sai sobrou, e o backup foi junto"
[ -e "$E/extensoes/usuario/meu.pino" ] && [ -e "$E/oficina/meu.svg" ] && [ -e "$CASA/.local/share/meowsystem/packs/meu/pack.json" ] \
  && ok "o que é seu ficou: repositórios, oficina e temas" || falha "o desinstalar apagou o que é de quem usa"
[ -e "$E/papeis-de-parede/BANIDOS.txt" ] && ok "a curadoria de papel de parede ficou" || falha "a curadoria saiu"
[ -d "$CASA/.config/meowsystem" ] && ok "a configuração dos applets ficou" || falha "a configuração saiu"

mundo
mkdir -p "$E/backups/2026-01-01T00-00-00-x" "$E/backups/2026-01-02T00-00-00-tema-PRIMEIRO-pre-instalacao" "$C/upstream"
grande "$E/backups/2026-01-01T00-00-00-x/f" 100000
grande "$C/upstream/f" 100000
GUARDAR=1
saida="$(esp desinstalar)"
GUARDAR=0
[ -e "$E/backups/2026-01-01T00-00-00-x/f" ] && [ -e "$E/backups/2026-01-02T00-00-00-tema-PRIMEIRO-pre-instalacao" ] \
  && ok "pedindo para guardar, os backups ficam" || falha "os backups saíram mesmo guardando"
[ ! -e "$C/upstream" ] && ok "e o resto sai" || falha "o cache ficou"

echo "== 6b. a fiação: desinstalador, install.sh, doctor e CLI"
grep -q 'meow_desinstalar_espaco$' "$RAIZ/lib/desinstalar.sh" && ok "o meow_desinstalar chama o inventário" || falha "o desinstalador não chama o inventário"
grep -q 'apague à mão' "$RAIZ/lib/desinstalar.sh" && falha "o desinstalador ainda manda apagar à mão" || ok "e não manda mais apagar à mão"
grep -q -- '--guardar-backups' "$RAIZ/install.sh" && ok "o install.sh tem a escolha de guardar os backups" || falha "sem --guardar-backups"
grep -qE '^VERIFICAVEIS=\(.* disco ' "$RAIZ/bin/meow" && ok "o doctor tem a conferência disco" || falha "disco fora do VERIFICAVEIS"
grep -q '^fix_disco' "$RAIZ/bin/meow" && ok "e o conserto dela" || falha "sem fix_disco"
grep -q 'espaco.py" continua' "$RAIZ/scripts/extensoes_build.sh" && ok "o fim do build limpa" || falha "o build não limpa no fim"
grep -qE '^    espaco\|espaço\)' "$RAIZ/bin/meow" && ok "a CLI tem o meow espaco" || falha "sem meow espaco"
grep -q '"espaco_liberar"' "$RAIZ/app/servidor.py" && ok "o painel tem a ação Liberar" || falha "sem ação do painel"

echo "== 6c. o doctor: conferir e consertar pelas funções do bin/meow"
mundo
REG="$M/registro.tsv"
sed 's#^\(extensoes-alvo\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t\)8192#\11#' "$REGISTRO" > "$REG"
mkdir -p "$E/extensoes/.target/release/deps"
for i in 1 2 3; do grande "$E/extensoes/.target/release/deps/libx-000000000000000$i.rlib" 600000; touch -d "$((i + 1)) hours ago" "$E/extensoes/.target/release/deps/libx-000000000000000$i.rlib"; done
funcoes="$(sed -n '/^chk_disco() {/,/^}/p;/^fix_disco()/,/^                    python3.*2>&1; }/p' "$RAIZ/bin/meow")"
doctor() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$E" MEOW_CACHE="$C" RAIZ="$RAIZ" ESPACO_REGISTRO="$REG" ESPACO_DISCO_USO_PCT=10 \
    bash -c "MEOW_SEM_DEPENDENCIA=3; meow_tem() { command -v \"\$1\" >/dev/null 2>&1; }; meow_pula() { printf '%s\n' \"\$*\"; }; $funcoes; \"\$@\"" _ "$@"
}
saida="$(doctor chk_disco)"; rc=$?
igual "chk_disco: acima do teto devolve divergente" "$rc" 1
case "$saida" in "o MeowSystem ocupa"*) ok "e a primeira linha é o peso do Meow" ;; *) falha "linha estranha: $saida" ;; esac
saida="$(doctor fix_disco)"; rc=$?
igual "fix_disco: corta e devolve 1 (mexeu)" "$rc" 1
saida="$(doctor chk_disco)"; rc=$?
igual "chk_disco depois do conserto confere" "$rc" 0
saida="$(doctor fix_disco)"; rc=$?
igual "fix_disco na segunda passada não escreve nada" "$rc" 0
mkdir -p "$E/extensoes/.target/release/deps"
for i in 1 2 3; do grande "$E/extensoes/.target/release/deps/libx-000000000000000$i.rlib" 600000; touch -d "$((i + 1)) hours ago" "$E/extensoes/.target/release/deps/libx-000000000000000$i.rlib"; done
antes="$(ls "$E/extensoes/.target/release/deps" | wc -l)"
saida="$(env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$E" MEOW_CACHE="$C" MEOW_RAIZ="$CLONE" MEOW_DRY_RUN=1 ESPACO_REGISTRO="$REG" ESPACO_DISCO_USO_PCT=10 python3 "$ESPACO" aparar)"
igual "no ensaio (MEOW_DRY_RUN=1) nada é cortado" "$(ls "$E/extensoes/.target/release/deps" | wc -l)" "$antes"
case "$saida" in *cortaria*) ok "e o ensaio diz o que cortaria" ;; *) falha "ensaio mudo: $saida" ;; esac

echo "== 6d. a CLI de ponta a ponta, em HOME temporário"
mundo
mkdir -p "$E/extensoes/.target/release/deps"
grande "$E/extensoes/.target/release/deps/libx-0000000000000001.rlib" 300000
cat > "$CASA/meow.conf" <<'FIM'
PACK="meowsystem"
FIM
saida="$(env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$E" MEOW_CACHE="$C" MEOW_RAIZ="$RAIZ" MEOW_CONF="$CASA/meow.conf" NO_COLOR=1 \
  ESPACO_DISCO_USO_PCT=10 "$RAIZ/bin/meow" espaco 2>&1)"; rc=$?
igual "meow espaco responde" "$rc" 0
case "$saida" in *"o MeowSystem ocupa"*Applets*) ok "e mostra o item" ;; *) falha "saída: $saida" ;; esac
[ -e "$E/extensoes/.target/release/deps/libx-0000000000000001.rlib" ] && ok "ver não corta" || falha "ver cortou"
saida="$(env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$E" MEOW_CACHE="$C" MEOW_RAIZ="$RAIZ" MEOW_CONF="$CASA/meow.conf" NO_COLOR=1 \
  ESPACO_DISCO_USO_PCT=10 "$RAIZ/bin/meow" espaco liberar 2>&1)"; rc=$?
[ ! -e "$E/extensoes/.target" ] && ok "meow espaco liberar corta o .target" || falha "não cortou: $saida"
[ ! -s "$T/recusas.log" ] && ok "nenhum falso recusou chamada (sem sudo, sem apt, sem systemctl de escrita)" || falha "chamou o que não devia: $(cat "$T/recusas.log")"

echo "== 6e. o meow_desinstalar de verdade, num clone mínimo"
mundo
cp -a "$RAIZ/lib" "$RAIZ/bin" "$RAIZ/install.sh" "$CLONE/"
mkdir -p "$CLONE/scripts" "$CLONE/assets" "$CLONE/app"
cp -a "$RAIZ/assets/contratos" "$CLONE/assets/"
cp -a "$RAIZ/scripts/espaco.py" "$RAIZ/scripts/compositor_patches.sh" "$RAIZ/scripts/files_menu.sh" "$CLONE/scripts/"
for c in systemctl update-desktop-database gtk-update-icon-cache fc-cache; do
  printf '#!/bin/sh\nexit 0\n' > "$T/bin/$c"; chmod 755 "$T/bin/$c"
done
mkdir -p "$E/extensoes/.target/release/deps" "$E/extensoes/a/src" "$E/extensoes/usuario" "$E/oficina" "$E/vizinhos" \
  "$C/cosmic-comp/cosmic-comp-1.0" "$LIBEXEC/cosmic-comp/1.0" "$E/cosmic-files/1.0" "$CASA/.local/bin" "$CASA/.config/meow" "$M/sistema" \
  "$E/backups/2026-01-01T00-00-00-x" "$E/backups/2026-01-02T00-00-00-sistema$M/sistema"
grande "$E/extensoes/.target/release/deps/libx-0000000000000001.rlib" 5000000
grande "$C/cosmic-comp/cosmic-comp-1.0/f" 3000000
grande "$LIBEXEC/cosmic-comp/1.0/cosmic-comp" 2000000
grande "$E/cosmic-files/1.0/cosmic-files" 1000000
grande "$E/backups/2026-01-01T00-00-00-x/f" 1000000
printf 'de meu\n' > "$E/oficina/meu.svg"
printf 'pino\n' > "$E/extensoes/usuario/meu.pino"
printf 'copia\n' > "$E/vizinhos/antigo"
printf 'PACK="meowsystem"\n' > "$CASA/.config/meow/meow.conf"
printf 'x\n' > "$E/meow.log"
printf 'mexido pelo meow\n' > "$M/sistema/app.desktop"
printf 'do apt\n' > "$E/backups/2026-01-02T00-00-00-sistema$M/sistema/app.desktop"
printf '#!/bin/sh\n# MEOW-COSMIC-COMP-SHIM\n' > "$CASA/.local/bin/cosmic-comp"; chmod 755 "$CASA/.local/bin/cosmic-comp"
printf 'menu' > "$CASA/.local/bin/cosmic-files"; printf 'menu' > "$CASA/.local/bin/cosmic-files-applet"
printf '#!/bin/sh\n' > "$CASA/.local/bin/meow"; chmod 755 "$CASA/.local/bin/meow"
antes_mb="$(( $(kb "$E" "$C" "$LIBEXEC") / 1024 ))"
desinstalar() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" NO_COLOR=1 USER=t MEOW_ESTADO="$E" MEOW_CACHE="$C" MEOW_RAIZ="$CLONE" \
    MEOW_CONF="$CASA/.config/meow/meow.conf" XDG_DATA_HOME="$CASA/.local/share" XDG_CONFIG_HOME="$CASA/.config" "$@" \
    bash -c '. "$MEOW_RAIZ/lib/comum.sh"; . "$MEOW_RAIZ/lib/desinstalar.sh"; meow_desinstalar' 2>&1
}
saida="$(desinstalar MEOW_DRY_RUN=1)"
[ -e "$E/extensoes/.target" ] && [ -e "$E/backups/2026-01-01T00-00-00-x/f" ] && [ -e "$CASA/.local/bin/cosmic-comp" ] \
  && ok "o ensaio do desinstalador não apaga nada" || falha "o ensaio apagou"
igual "nem devolve o .desktop" "$(cat "$M/sistema/app.desktop")" "mexido pelo meow"
saida="$(desinstalar)"
depois_mb="$(( $(kb "$E" "$C" "$LIBEXEC") / 1024 ))"
disse="$(printf '%s\n' "$saida" | sed -n 's/.*liberou \([0-9]*\) MB.*/\1/p' | head -1)"
[ -n "$disse" ] && [ $(( disse - (antes_mb - depois_mb) )) -ge -1 ] && [ $(( disse - (antes_mb - depois_mb) )) -le 1 ] \
  && ok "o valor dito ($disse MB) bate com o medido ($((antes_mb - depois_mb)) MB)" || falha "disse '$disse', mediu $((antes_mb - depois_mb)): $(printf '%s' "$saida" | tail -3)"
igual "o .desktop do sistema voltou ao que o apt instalou antes de o backup sair" "$(cat "$M/sistema/app.desktop")" "do apt"
case "$saida" in *"Tema de antes"*) falha "promete o Tema de antes depois de apagar os backups" ;; *) ok "e não promete o que os backups faziam" ;; esac
[ ! -e "$CASA/.local/bin/cosmic-comp" ] && ok "o shim do compositor saiu com o build que ele chamava" || falha "o shim ficou"
[ ! -e "$CASA/.local/bin/cosmic-files" ] && [ ! -e "$CASA/.local/bin/cosmic-files-applet" ] && ok "e o menu patchado também" || falha "o menu patchado ficou"
for f in "$E/extensoes/.target" "$E/extensoes/a" "$E/backups" "$E/cosmic-files" "$E/meow.log" "$C/cosmic-comp" "$LIBEXEC"; do
  [ ! -e "$f" ] || falha "sobrou: ${f#"$M/"}"
done
[ ! -e "$E/backups" ] && [ ! -e "$LIBEXEC" ] && [ ! -e "$E/meow.log" ] && ok "nada do que sai sobrou, nem o registro renasceu depois" || falha "algo renasceu: $(ls -A "$E")"
[ -e "$E/oficina/meu.svg" ] && [ -e "$E/extensoes/usuario/meu.pino" ] && [ -e "$E/vizinhos/antigo" ] && [ -e "$CASA/.config/meow/meow.conf" ] \
  && ok "o que é de quem usa ficou" || falha "o desinstalador apagou o que é de quem usa"

echo "== 7. o Liberar segura o builds.lock do primeiro corte ao último"
mundo
mkdir -p "$E/extensoes/.target/release/deps" "$C/cosmic-comp/cosmic-comp-1.0"
grande "$E/extensoes/.target/release/deps/libx-0000000000000001.rlib" 300000
grande "$C/cosmic-comp/cosmic-comp-1.0/f" 300000
saida="$(env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$E" MEOW_CACHE="$C" MEOW_RAIZ="$CLONE" ESPACO_REGISTRO="$REGISTRO" \
  ESPACO_DISCO_USO_PCT=10 python3 - "$ESPACO" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("espaco", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
original = m.remover
vistos = []
def com_sonda(caminho):
    vistos.append(m.travado(m.trava_de_builds()))
    return original(caminho)
m.remover = com_sonda
m.executar("liberar")
print("%d %s" % (len(vistos), "presa" if vistos and all(vistos) else "solta"))
PY
)"
case "$saida" in "2 presa"|"3 presa"|"4 presa") ok "a cada corte do Liberar o builds.lock está preso ($saida)" ;; *) falha "a trava soltou no meio: $saida" ;; esac
[ ! -e "$E/extensoes/.target" ] && ok "e o Liberar cortou" || falha "o Liberar não cortou"

mundo
mkdir -p "$E/extensoes/.target/release/deps"
grande "$E/extensoes/.target/release/deps/libx-0000000000000001.rlib" 300000
: > "$E/builds.lock"
flock "$E/builds.lock" sleep 4 &
build_falso=$!
sleep 0.5
saida="$(esp liberar)"
[ -e "$E/extensoes/.target/release/deps/libx-0000000000000001.rlib" ] && ok "com um build falso em andamento o Liberar não corta nada" || falha "cortou com build em curso"
case "$saida" in *"build em curso"*) ok "e diz que fica para depois" ;; *) falha "sem aviso: $saida" ;; esac
case "$saida" in *"nada a liberar"*) falha "disse que não há nada, com o corte só adiado: $saida" ;; *) ok "e não diz que não há nada a liberar" ;; esac
kill "$build_falso" 2>/dev/null; wait "$build_falso" 2>/dev/null

echo "== 7b. o fim do build limpa mesmo segurando a trava dele"
mundo
REG="$M/registro.tsv"
sed 's#^\(extensoes-alvo\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t\)8192#\11#' "$REGISTRO" > "$REG"
mkdir -p "$E/extensoes/.target/release/deps"
for i in 1 2 3; do grande "$E/extensoes/.target/release/deps/libx-000000000000000$i.rlib" 600000; touch -d "$((i + 1)) hours ago" "$E/extensoes/.target/release/deps/libx-000000000000000$i.rlib"; done
fim_de_build() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$E" MEOW_CACHE="$C" MEOW_RAIZ="$RAIZ" ESPACO_REGISTRO="$REG" ESPACO_DISCO_USO_PCT=10 \
    bash -c '. "$MEOW_RAIZ/lib/comum.sh"; exec 9>>"$MEOW_ESTADO/builds.lock"; flock 9; meow_limpar_fim_de_build' 2>&1
}
saida="$(fim_de_build)"
case "$saida" in *"cortou Applets"*) ok "segurando a trava do próprio build o fim do build corta ($saida)" ;; *) falha "não cortou: $saida" ;; esac
antes="$(find "$CASA" -printf '%p %T@ %s\n' | sort | md5sum)"
saida="$(fim_de_build)"
igual "a segunda passada não diz nada" "$saida" ""
igual "e não escreve nada" "$(find "$CASA" -printf '%p %T@ %s\n' | sort | md5sum)" "$antes"

echo "== 7b2. o build de verdade, de dentro da trava de quem o chamou, limpa no fim"
mundo
REG="$M/registro.tsv"
sed 's#^\(extensoes-alvo\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t\)8192#\11#' "$REGISTRO" > "$REG"
mkdir -p "$M/falso" "$C/cosmic-comp/cosmic-comp-1.0~teste/src"
printf '#!/bin/sh\nprintf "1.0~teste"\n' > "$M/falso/dpkg-query"
printf '#!/bin/sh\nexit 0\n' > "$M/falso/patch"
cat > "$M/falso/make" <<'FIM'
#!/bin/sh
mkdir -p target/release && printf '#!/bin/sh\nexit 0\n' > target/release/cosmic-comp && chmod 755 target/release/cosmic-comp
FIM
cat > "$M/falso/cargo" <<'FIM'
#!/bin/sh
mkdir -p target/release
for b in cosmic-files cosmic-files-applet; do printf 'MEOW-FILES-WALLPAPER-PATCH-2' > target/release/$b; done
FIM
cat > "$M/falso/apt-get" <<'FIM'
#!/bin/sh
mkdir -p cosmic-files-1.0~teste/src && printf 'MEOW-FILES-WALLPAPER-PATCH-2' > cosmic-files-1.0~teste/src/app.rs
FIM
chmod 755 "$M/falso/"*
printf '[package]\nname = "cosmic-comp"\n' > "$C/cosmic-comp/cosmic-comp-1.0~teste/Cargo.toml"
printf 'all:\n\ttrue\n' > "$C/cosmic-comp/cosmic-comp-1.0~teste/Makefile"
: > "$M/serie-vazia"
inchar() {
  mkdir -p "$E/extensoes/.target/release/deps"
  for i in 1 2 3; do grande "$E/extensoes/.target/release/deps/libx-000000000000000$i.rlib" 600000; touch -d "$((i + 1)) hours ago" "$E/extensoes/.target/release/deps/libx-000000000000000$i.rlib"; done
}
sob_a_trava() {
  env -i PATH="$M/falso:$T/bin:/usr/bin:/bin" HOME="$CASA" NO_COLOR=1 MEOW_ESTADO="$E" MEOW_CACHE="$C" ESPACO_REGISTRO="$REG" ESPACO_DISCO_USO_PCT=10 \
    CP_SERIE="$M/serie-vazia" CP_ESPACO_KB=1 FILES_MENU=sim \
    bash -c 'exec 9>>"$MEOW_ESTADO/builds.lock"; flock 9; bash "$@"' _ "$@" 2>&1
}
inchar
saida="$(sob_a_trava "$RAIZ/scripts/compositor_patches.sh" compilar)"
case "$saida" in *"cortou Applets"*) ok "o build do compositor limpa no fim" ;; *) falha "o compositor não limpou: $saida" ;; esac
case "$saida" in *"build em curso"*) falha "o compositor esperou por si mesmo: $saida" ;; *) ok "e não espera por si mesmo" ;; esac
inchar
saida="$(sob_a_trava "$RAIZ/scripts/compositor_patches.sh" compilar)"
case "$saida" in *"nada a instalar"*) ok "o build repetido dá o mesmo binário" ;; *) falha "não caiu no binário igual: $saida" ;; esac
case "$saida" in *"cortou Applets"*) ok "e limpa no fim do mesmo jeito" ;; *) falha "o binário igual não limpou: $saida" ;; esac
inchar
saida="$(sob_a_trava "$RAIZ/scripts/files_menu.sh" build)"
case "$saida" in *"cortou Applets"*) ok "o build do menu do Arquivos limpa no fim" ;; *) falha "o menu não limpou: $saida" ;; esac
[ -x "$CASA/.local/bin/cosmic-files" ] && ok "e o menu segue instalado depois da limpeza" || falha "a limpeza atrapalhou o aplicar: $saida"
compgen -G "$C/cosmic-files/compilar-*.log" >/dev/null && [ -z "$(find "$C/cosmic-files" -maxdepth 1 -name 'meow-cf.*' -print -quit)" ] \
  && ok "o menu compila no cache do disco, guarda o registro e não deixa a árvore" \
  || falha "o build do menu não ficou no cache do disco: $(ls -la "$C/cosmic-files" 2>&1)"

echo "== 7c. oraculo-builds guarda o em uso e um anterior"
mundo
mkdir -p "$LIBEXEC/oraculo-tema/revA" "$LIBEXEC/oraculo-tema/revB" "$LIBEXEC/oraculo-tema/revC" "$LIBEXEC/oraculo-tema/revD" "$LIBEXEC/oraculo-tema/revE"
for r in revA revB revC revD; do grande "$LIBEXEC/oraculo-tema/$r/meow-oraculo-tema" 100000; done
touch -d '5 days ago' "$LIBEXEC/oraculo-tema/revA/meow-oraculo-tema" "$LIBEXEC/oraculo-tema/revA"
touch -d '4 days ago' "$LIBEXEC/oraculo-tema/revB/meow-oraculo-tema" "$LIBEXEC/oraculo-tema/revB"
touch -d '3 days ago' "$LIBEXEC/oraculo-tema/revC/meow-oraculo-tema" "$LIBEXEC/oraculo-tema/revC"
touch -d '2 days ago' "$LIBEXEC/oraculo-tema/revD/meow-oraculo-tema" "$LIBEXEC/oraculo-tema/revD"
saida="$(esp aparar)"; rc=$?
igual "o aparar corta as revisões antigas do oráculo" "$rc" 1
[ ! -e "$LIBEXEC/oraculo-tema/revA" ] && [ ! -e "$LIBEXEC/oraculo-tema/revB" ] && ok "as duas mais velhas saíram" || falha "restou revisão velha: $(ls "$LIBEXEC/oraculo-tema")"
[ -e "$LIBEXEC/oraculo-tema/revC" ] && [ -e "$LIBEXEC/oraculo-tema/revD" ] && ok "ficam a mais nova e a anterior" || falha "cortou o que devia ficar"
[ -d "$LIBEXEC/oraculo-tema/revE" ] && ok "a pasta de um build em andamento, sem binário, não conta nem sai" || falha "mexeu na pasta ainda vazia"
saida="$(esp aparar)"; rc=$?
igual "a segunda passada não corta nada" "$rc" 0
saida="$(esp liberar)"
[ -e "$LIBEXEC/oraculo-tema/revC" ] && [ -e "$LIBEXEC/oraculo-tema/revD" ] && ok "o Liberar não toca no oráculo em uso" || falha "o Liberar cortou o oráculo"
mkdir -p "$LIBEXEC/oraculo-tema/revA" "$LIBEXEC/oraculo-tema/revB"
for r in revA revB; do grande "$LIBEXEC/oraculo-tema/$r/meow-oraculo-tema" 100000; done
touch -d '5 days ago' "$LIBEXEC/oraculo-tema/revA/meow-oraculo-tema" "$LIBEXEC/oraculo-tema/revA"
touch -d '4 days ago' "$LIBEXEC/oraculo-tema/revB/meow-oraculo-tema" "$LIBEXEC/oraculo-tema/revB"
saida="$(esp json | python3 -c 'import json, sys; d = json.load(sys.stdin); print(d["liberavel"] > 0, d["refazer"])')"
igual "cortar revisão antiga não promete recompilar nada" "$saida" "True 0"
touch -d '4 days ago' "$LIBEXEC/oraculo-tema/revC/meow-oraculo-tema" "$LIBEXEC/oraculo-tema/revC"
touch -d '3 days ago' "$LIBEXEC/oraculo-tema/revD/meow-oraculo-tema" "$LIBEXEC/oraculo-tema/revD"
touch -a "$LIBEXEC/oraculo-tema/revA/meow-oraculo-tema"
touch -d '10 days ago' -m "$LIBEXEC/oraculo-tema/revA/meow-oraculo-tema"
esp aparar >/dev/null
[ -e "$LIBEXEC/oraculo-tema/revA" ] && ok "a revisão velha que acabou de rodar é a em uso e fica" || falha "cortou o oráculo que acabou de rodar: $(ls "$LIBEXEC/oraculo-tema")"

echo "== 7d. cosmic-prever tem teto e o mais antigo sai primeiro"
mundo
REG="$M/registro.tsv"
sed 's#^\(previa-cache\t[^\t]*\t[^\t]*\t[^\t]*\t[^\t]*\t\)1024#\11#' "$REGISTRO" > "$REG"
ESPACO_REGISTRO_USADO="$REG"
mkdir -p "$C/cosmic-prever/src/a-1" "$C/cosmic-prever/src/b-2" "$C/cosmic-prever/src/c-3" "$C/cosmic-prever/debs"
for d in src/a-1 src/b-2 src/c-3; do grande "$C/cosmic-prever/$d/f" 700000; done
grande "$C/cosmic-prever/debs/cosmic-comp_1.deb" 700000
touch -d '6 hours ago' "$C/cosmic-prever/src/a-1/f" "$C/cosmic-prever/src/a-1"
touch -d '5 hours ago' "$C/cosmic-prever/src/b-2/f" "$C/cosmic-prever/src/b-2"
touch -d '4 hours ago' "$C/cosmic-prever/debs/cosmic-comp_1.deb"
touch -d '3 hours ago' "$C/cosmic-prever/src/c-3/f" "$C/cosmic-prever/src/c-3"
touch -d '1 hour ago' "$C/cosmic-prever" "$C/cosmic-prever/src" "$C/cosmic-prever/debs"
saida="$(esp aparar)"; rc=$?
igual "acima do teto o aparar corta" "$rc" 1
[ ! -e "$C/cosmic-prever/src/a-1" ] && [ ! -e "$C/cosmic-prever/src/b-2" ] && [ ! -e "$C/cosmic-prever/debs/cosmic-comp_1.deb" ] && ok "saíram os três mais antigos, fontes e deb" || falha "restou o mais antigo: $(ls "$C/cosmic-prever/src")"
[ -e "$C/cosmic-prever/src/c-3" ] && ok "o mais novo ficou" || falha "o mais novo saiu"
perto "o que sobra é só o mais novo, dentro do teto de 1 MB" "$(kb "$C/cosmic-prever")" 700 10
saida="$(esp aparar)"; rc=$?
igual "a segunda passada não corta nada" "$rc" 0
mundo
mkdir -p "$C/cosmic-prever/src/a-1" "$C/cosmic-prever/src/b-2"
grande "$C/cosmic-prever/src/a-1/f" 700000
grande "$C/cosmic-prever/src/b-2/f" 700000
saida="$(esp aparar)"; rc=$?
[ -e "$C/cosmic-prever/src/a-1" ] && [ -e "$C/cosmic-prever/src/b-2" ] && ok "o que acabou de ser mexido não sai, mesmo acima do teto" || falha "cortou fonte em uso agora"
mundo
mkdir -p "$C/cosmic-prever/src/a-1" "$C/cosmic-prever/src/b-2" "$C/cosmic-prever/src/c-3"
for d in a-1 b-2 c-3; do grande "$C/cosmic-prever/src/$d/f" 400000; done
touch -d '6 hours ago' "$C/cosmic-prever/src/a-1/f" "$C/cosmic-prever/src/a-1"
touch -d '5 hours ago' "$C/cosmic-prever/src/b-2/f" "$C/cosmic-prever/src/b-2"
touch -d '4 hours ago' "$C/cosmic-prever/src/c-3/f" "$C/cosmic-prever/src/c-3"
USO_PCT=90 esp aparar >/dev/null
[ ! -e "$C/cosmic-prever/src/b-2" ] && [ -e "$C/cosmic-prever/src/c-3" ] && ok "com o disco apertado o teto cai à metade" || falha "o teto apertado não valeu: $(ls "$C/cosmic-prever/src")"
ESPACO_REGISTRO_USADO=""

echo
[ "$falhas" -eq 0 ] && { echo "espaco: tudo certo"; exit 0; }
echo "espaco: $falhas falha(s)"; exit 1

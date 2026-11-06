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
    ESPACO_REGISTRO="${ESPACO_REGISTRO_USADO:-$REGISTRO}" ESPACO_VERSAO_COMPOSITOR="${VERSAO_COMP:-}" \
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
nomes_do_codigo="$(cd "$RAIZ" && grep -rhoE '(\$MEOW_ESTADO|\$\{MEOW_ESTADO\})/[A-Za-z0-9_.-]+' bin lib scripts install.sh app/servidor.py 2>/dev/null \
  | sed -E 's|^[^/]*/||' | sort -u)"
cache_do_codigo="$(cd "$RAIZ" && grep -rhoE '(\$MEOW_CACHE|\$\{MEOW_CACHE\})/[A-Za-z0-9_.-]+' bin lib scripts install.sh app/servidor.py 2>/dev/null \
  | sed -E 's|^[^/]*/||' | sort -u)"
for nome in $nomes_do_codigo; do mkdir -p "$E/$nome" 2>/dev/null || : > "$E/$nome"; done
for nome in $cache_do_codigo; do mkdir -p "$C/$nome"; done
mkdir -p "$LIBEXEC/cosmic-comp" "$LIBEXEC/oraculo-tema" "$CASA/.local/share/meowsystem/fastfetch" \
  "$CASA/.local/share/meowsystem/packs" "$CASA/.config/meowsystem"
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
  printf '[Desktop Entry]\nExec=@bindir@/meowsystem-teste\n' > data/io.github.teste.Fake.desktop.in
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
APP_ID="io.github.teste.Fake"
BIN="meowsystem-teste"
DESKTOP="data/io.github.teste.Fake.desktop.in"
FIM
}
cat > "$T/bin/cargo" <<'FIM'
#!/bin/sh
d="${CARGO_TARGET_DIR:-target}/release"
h="$(printf '%s' "$(cat "$FALSO_VERSAO")" | md5sum | cut -c1-16)"
json=0
for a in "$@"; do [ "$a" = "--message-format=json" ] && json=1; done
if [ "$json" = 1 ]; then
  printf '{"reason":"compiler-artifact","filenames":["%s/deps/libdep-%s.rlib","%s/deps/libdep-%s.rmeta"],"fresh":true}\n' "$d" "$h" "$d" "$h"
  printf '{"reason":"build-script-executed","out_dir":"%s/build/dep-%s/out"}\n' "$d" "$h"
  printf '{"reason":"build-finished","success":true}\n'
  exit 0
fi
case "$1" in
  build)
    mkdir -p "$d/deps" "$d/.fingerprint/dep-$h" "$d/build/dep-$h/out"
    head -c 400000 /dev/zero > "$d/deps/libdep-$h.rlib"
    head -c 100000 /dev/zero > "$d/deps/libdep-$h.rmeta"
    printf 'x' > "$d/deps/dep-$h.d"
    printf 'x' > "$d/.fingerprint/dep-$h/dep.json"
    printf 'x' > "$d/build/dep-$h/out/saida"
    printf '#!/bin/sh\n' > "$d/$FAKE_BIN"; chmod 755 "$d/$FAKE_BIN" ;;
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
case "$saida" in *"disco está apertado"*) ok "e o doctor diz que apertou" ;; *) falha "sem aviso do aperto: $saida" ;; esac
USO_PCT=10; ESPACO_REGISTRO_USADO=""

echo "== 4. backups acima da rotação: ficam os mais novos e o tema-PRIMEIRO"
mundo
mkdir -p "$E/backups"
for d in 3 8 15 25; do mkdir -p "$E/backups/$(date -d "$d days ago" +%Y-%m-%dT%H-%M-%S)-tema"; done
for d in 31 40 90 200 365; do mkdir -p "$E/backups/$(date -d "$d days ago" +%Y-%m-%dT%H-%M-%S)-sistema"; done
mkdir -p "$E/backups/$(date -d '700 days ago' +%Y-%m-%dT%H-%M-%S)-tema-PRIMEIRO-pre-instalacao"
saida="$(esp aparar)"; rc=$?
igual "a rotação por idade corta" "$rc" 1
igual "ficam os quatro dos últimos 30 dias e o tema-PRIMEIRO" "$(ls "$E/backups" | wc -l)" 5
ls "$E/backups" | grep -q 'tema-PRIMEIRO' && ok "o tema-PRIMEIRO ficou" || falha "o PRIMEIRO saiu"
ls "$E/backups" | grep -q -- '-sistema' && falha "sobrou um backup velho" || ok "nenhum backup velho sobrou"
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

echo
[ "$falhas" -eq 0 ] && { echo "espaco: tudo certo"; exit 0; }
echo "espaco: $falhas falha(s)"; exit 1

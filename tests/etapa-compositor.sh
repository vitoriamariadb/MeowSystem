#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)" || exit 2
trap "cp -r $T/saida /tmp/claude-1000/-home-vitoriamaria-Desenvolvimento-MeowSystem/a7736095-6179-4e12-b0ee-1944c28bfa25/scratchpad/etapa5-saida.txt 2>/dev/null; rm -rf $T" EXIT
falhas=0
confere() {
  if eval "$2"; then printf 'ok: %s\n' "$1"
  else printf 'FALHOU: %s\n%s\n' "$1" "$(tail -8 "$T/saida" 2>/dev/null)" >&2; falhas=$((falhas + 1)); fi
}

CASA="$T/casa"; SHIM="$CASA/.local/bin/cosmic-comp"
mkdir -p "$T/falso" "$CASA/.config/meow"
for c in sudo pkexec su apt apt-get systemctl; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/recusados"\nexit 1\n' "$c" "$T" > "$T/falso/$c"
done
cat > "$T/garantir" <<'G'
#!/bin/sh
case "$1" in
  estado)
    c=nao; [ -f "$TESTE_DIR/construindo" ] && c=sim
    printf 'compositor_versao=0.1~t\ncompositor_estado=pendente\nmenu_versao=1.0~t\nmenu_estado=pendente\nconstruindo=%s\n' "$c" ;;
  --fundo)
    echo "fundo" >> "$TESTE_DIR/chamadas"; : > "$TESTE_DIR/construindo"; exit 1 ;;
  *) echo "$*" >> "$TESTE_DIR/chamadas" ;;
esac
exit 0
G
chmod 755 "$T/falso/"* "$T/garantir"
cp "$RAIZ/meow.conf.exemplo" "$CASA/.config/meow/meow.conf"

instalar() {
  env -i PATH="$T/falso:$PATH" HOME="$CASA" USER=t NO_COLOR=1 MEOW_IGNORA_DESKTOP=1 \
    MEOW_PONTE=/nao/existe TESTE_DIR="$T" EXTENSOES_GARANTIR="$T/garantir" \
    bash "$RAIZ/install.sh" --etapa compositor > "$T/saida" 2>&1
}

printf '\n1. a etapa existe e vem depois das extensões\n'
confere "etapa_compositor está na lista, logo depois de etapa_extensoes" \
  'grep -qE "etapa_extensoes etapa_compositor " "$RAIZ/install.sh"'
confere "a etapa chama o gesto em fundo" \
  'sed -n "/^etapa_compositor()/,/^}/p" "$RAIZ/install.sh" | grep -q "EXTENSOES_FUNDO=1 .*extensoes_gesto.sh\" instalar compositor"'

printf '\n2. do zero: o build vai para o fundo e o shim liga\n'
instalar; rc=$?
confere "o install sai 0" '[ "$rc" = 0 ]'
confere "o build foi pedido em fundo uma vez só" '[ "$(grep -c "^fundo$" "$T/chamadas" 2>/dev/null)" = 1 ]'
confere "o shim nasce em ~/.local/bin com a marca" 'grep -q MEOW-COSMIC-COMP-SHIM-1 "$SHIM" && [ -x "$SHIM" ]'
sem_root() { ! grep -qv '^sudo -n true$' "$T/recusados" 2>/dev/null; }
confere "nenhum sudo, pkexec, apt ou systemctl além da sondagem do install" 'sem_root'
confere "a segunda passada do próprio install já confere" 'grep -q "Pronto. 2 passagens" "$T/saida"'

printf '\n3. a segunda vez não escreve\n'
antes="$(cd "$CASA" && find . -type f -newer "$T/chamadas" | sort)"
cp -a "$CASA" "$T/casa-antes"
instalar; rc=$?
confere "sai 0 numa passagem" '[ "$rc" = 0 ] && grep -q "Pronto. 1 passagem" "$T/saida"'
confere "não pede outro build" '[ "$(grep -c "^fundo$" "$T/chamadas")" = 1 ]'
confere "o shim e o meow.conf ficam como estavam" \
  'cmp -s "$SHIM" "$T/casa-antes/.local/bin/cosmic-comp" && cmp -s "$CASA/.config/meow/meow.conf" "$T/casa-antes/.config/meow/meow.conf"'

printf '\n4. COMPOSITOR="nao" tira o shim e não compila\n'
sed -i 's/^COMPOSITOR=.*/COMPOSITOR="nao"/' "$CASA/.config/meow/meow.conf"
instalar; rc=$?
confere "o shim sai" '[ "$rc" = 0 ] && [ ! -e "$SHIM" ]'
confere "não pede build" '[ "$(grep -c "^fundo$" "$T/chamadas")" = 1 ]'
instalar; rc=$?
confere "a segunda vez com nao confere numa passagem" '[ "$rc" = 0 ] && grep -q "Pronto. 1 passagem" "$T/saida"'
confere "nenhum sudo no caminho todo" 'sem_root'

printf '\n5. com o garantir_builds.sh de verdade, o install nunca compila no primeiro plano\n'
CASA="$T/casa5"; SHIM="$CASA/.local/bin/cosmic-comp"
mkdir -p "$CASA/.config/meow" "$T/real"
cp "$RAIZ/meow.conf.exemplo" "$CASA/.config/meow/meow.conf"
printf '#!/bin/sh\nprintf "cosmic-comp\\t0.1~r\\tinstalled\\n"\n' > "$T/real/dpkg-query"
printf '#!/bin/sh\necho "compositor $*" >> "%s/comp5.log"\nexit 0\n' "$T" > "$T/real/compositor"
printf '#!/bin/sh\nexit 0\n' > "$T/real/files"
chmod 755 "$T/real/"*
env -i PATH="$T/real:$T/falso:$PATH" HOME="$CASA" USER=t NO_COLOR=1 MEOW_IGNORA_DESKTOP=1 \
  MEOW_PONTE=/nao/existe GB_COMPOSITOR="$T/real/compositor" GB_FILES="$T/real/files" GB_ESPERA=1 \
  bash "$RAIZ/install.sh" --etapa compositor > "$T/saida" 2>&1; rc=$?
confere "o install sai 0" '[ "$rc" = 0 ]'
confere "o compositor não compila no primeiro plano do install" '! grep -q "^compositor compilar" "$T/comp5.log" 2>/dev/null'
confere "e diz o que acontece com o build" 'grep -qE "cosmic-comp 0.1~r (fica|—)" "$T/saida"'
confere "o shim nasce mesmo assim" 'grep -q MEOW-COSMIC-COMP-SHIM-1 "$SHIM"'

printf '\n6. o compilar: degrau 2 sem clique, falha na matriz, espera, espaço e fumaça\n'
C6="$T/c6"; VER6="2.0~t"; FONTE6="$C6/cache/cosmic-comp-$VER6"
CASA6="$C6/casa/.local/libexec/meow/cosmic-comp"; ESTADO6="$C6/estado"; MATRIZ6="$ESTADO6/cosmic-comp/matriz.tsv"
mkdir -p "$C6/bin" "$C6/patches" "$C6/guarda" "$C6/casa/.local/bin"
cat > "$C6/bin/dpkg-query" <<FIM
#!/bin/sh
case "\$*" in
  *Package*) printf 'cosmic-comp\t$VER6\tinstalled\n' ;;
  *) printf '%s' "$VER6" ;;
esac
FIM
printf '#!/bin/sh\nexit 0\n' > "$C6/bin/cargo"
cat > "$C6/bin/dpkg-source" <<FIM
#!/bin/sh
d="\$3"; mkdir -p "\$d/src"
printf '[package]\nname = "cosmic-comp"\n' > "\$d/Cargo.toml"
printf 'all:\n\ttrue\n' > "\$d/Makefile"
cp "$C6/a.rs" "\$d/src/a.rs"
FIM
cat > "$C6/bin/make" <<FIM
#!/bin/sh
[ -f "$C6/make-falha" ] && { mkdir -p target/lixo; echo "error: falhou" >&2; exit 2; }
mkdir -p target/release
r=0; [ -f "$C6/make-quebrado" ] && r=139
{ printf '#!/bin/sh\nexit %s\n' "\$r"; grep -rho 'MEOW-T6-[0-9]*' src; } > target/release/cosmic-comp
chmod 755 target/release/cosmic-comp
FIM
chmod 755 "$C6/bin/"*
: > "$C6/guarda/cosmic-comp_$VER6.dsc"
echo 'req t6.patch MEOW-T6' > "$C6/patches/series"
printf 'fn um() {}\nfn dois() {}\nfn tres() {}\nfn quatro() {}\n' > "$C6/a.rs"
cat > "$C6/patches/t6.patch" <<'FIM'
--- a/src/a.rs
+++ b/src/a.rs
@@ -1,4 +1,5 @@
 fn um() {}
+static M: &str = "MEOW-T6-1";
 fn dois() {}
 fn tres() {}
 fn quatro() {}
FIM
comp6() {
  env -i PATH="$C6/bin:$T/falso:$PATH" HOME="$C6/casa" NO_COLOR=1 MEOW_ESTADO="$ESTADO6" \
    CP_REPO="$C6/patches" CP_SERIE="$C6/patches/series" CP_CACHE="$C6/cache" CP_GUARDA="$C6/guarda" \
    CP_CASA="$CASA6" CP_SHIM="$C6/casa/.local/bin/cosmic-comp" CP_BIN="$C6/nao-existe" "$@" > "$T/saida" 2>&1
}
gb6() {
  env -i PATH="$C6/bin:$T/falso:$PATH" HOME="$C6/casa" NO_COLOR=1 MEOW_ESTADO="$ESTADO6" COMPOSITOR=sim FILES_MENU=nao \
    MEOW_CONF="$C6/casa/.config/meow/meow.conf" CP_REPO="$C6/patches" CP_SERIE="$C6/patches/series" \
    CP_CASA="$CASA6" GB_COMPOSITOR="$C6/gb-comp" bash "$RAIZ/scripts/garantir_builds.sh" "$@" > "$T/saida" 2>&1
}
printf '#!/bin/sh\necho "compilar" >> "%s/gb6.log"\nexit 2\n' "$C6" > "$C6/gb-comp"; chmod 755 "$C6/gb-comp"

: > "$C6/make-falha"
comp6 bash "$RAIZ/scripts/compositor_patches.sh" compilar; rc=$?
confere "a compilação que falha sai 2" '[ "$rc" = 2 ]'
confere "a falha entra na matriz, com a versão" 'grep -q "^$VER6	.*	falhou=1@[0-9]*$" "$MATRIZ6"'
confere "e o target/ da falha sai do disco" '[ ! -e "$FONTE6/target" ]'
comp6 bash "$RAIZ/scripts/compositor_patches.sh" compilar
confere "a segunda falha conta 2" 'grep -q "	falhou=2@" "$MATRIZ6"'
: > "$C6/gb6.log"; gb6 rodar; rc=$?
confere "o garantir espera: não compila de novo dentro da espera" '[ "$rc" = 0 ] && [ ! -s "$C6/gb6.log" ]'
confere "e diz quando tenta de novo" 'grep -q "próxima tentativa é a partir de" "$T/saida"'
gb6 estado
confere "o estado segue pendente (o cartão mostra «Não instalada»)" 'grep -qx "compositor_estado=pendente" "$T/saida"'
sed -i "s/@[0-9]*$/@$(( $(date +%s) - 8000 ))/" "$MATRIZ6"
: > "$C6/gb6.log"; gb6 rodar
confere "passada a espera de 2 h, compila de novo" '[ "$(grep -c compilar "$C6/gb6.log")" = 1 ]'
sed -i "s/@[0-9]*$/@$(date +%s)/" "$MATRIZ6"
sleep 1; touch "$C6/patches/t6.patch"
: > "$C6/gb6.log"; gb6 rodar
confere "a série mudou: a espera cai e compila" '[ "$(grep -c compilar "$C6/gb6.log")" = 1 ]'
comp6 bash "$RAIZ/scripts/compositor_patches.sh" compilar
confere "e a contagem recomeça na série nova" 'grep -q "	falhou=1@" "$MATRIZ6"'
rm -f "$C6/make-falha"

: > "$C6/make-quebrado"
comp6 bash "$RAIZ/scripts/compositor_patches.sh" compilar; rc=$?
confere "o binário que não passa no teste de fumaça não é instalado" '[ "$rc" = 2 ] && [ ! -e "$CASA6/$VER6/cosmic-comp" ]'
confere "e diz o teste de fumaça" 'grep -q "teste de fumaça" "$T/saida"'
confere "e entra na matriz como falha" 'grep -q "	falhou=2@" "$MATRIZ6"'
rm -f "$C6/make-quebrado"

comp6 env CP_ESPACO_KB=999999999999 bash "$RAIZ/scripts/compositor_patches.sh" compilar; rc=$?
confere "sem espaço: sai 3, sem compilar" '[ "$rc" = 3 ] && grep -q "sem espaço para compilar" "$T/saida" && [ ! -e "$CASA6/$VER6/cosmic-comp" ]'

comp6 bash "$RAIZ/scripts/compositor_patches.sh" compilar; rc=$?
confere "o build bom: sai 0 e é instalado, com a impressão digital das bibliotecas" \
  '[ "$rc" = 0 ] && [ -x "$CASA6/$VER6/cosmic-comp" ] && grep -q "^bibliotecas=[0-9a-f]\{32\}$" "$CASA6/$VER6/estado"'
confere "a matriz perde a falha" '! grep -q falhou "$MATRIZ6" && grep -q "^$VER6	" "$MATRIZ6"'
confere "o primeiro build, sem contexto mudado: a linha fica vazia" 'grep -qx "contexto=" "$CASA6/$VER6/estado"'

rm -rf "${CASA6:?}/$VER6" "$FONTE6"
printf 'fn um() {}\nfn dois() {}\nfn tres() {}\nfn quatro(x: u8) {}\n' > "$C6/a.rs"
comp6 bash "$RAIZ/scripts/compositor_patches.sh" compilar; rc=$?
confere "o patch que só entra com -F1: degrau 2 na matriz" 'grep -q "t6.patch:2" "$MATRIZ6"'
confere "o build é guardado, e o estado guarda o -F1" '[ "$rc" = 0 ] && [ -x "$CASA6/$VER6/cosmic-comp" ] && grep -qx "contexto=t6.patch" "$CASA6/$VER6/estado"'
confere "o degrau 2 entra sem marca nenhuma" '[ ! -e "$CASA6/$VER6/retido" ] && [ ! -e "$CASA6/$VER6/liberado" ]'
mkdir -p "$C6/casa/.local/bin"; cp "$RAIZ/scripts/compositor_shim.sh" "$C6/casa/.local/bin/cosmic-comp"
confere "o shim escolhe o build sem liberar" \
  '[ "$(env PATH="$C6/bin:$PATH" HOME="$C6/casa" MEOW_SHIM_SO_DIZER=1 MEOW_SHIM_FABRICA=/fabrica MEOW_SHIM_CASA="$CASA6" bash "$C6/casa/.local/bin/cosmic-comp")" = "$CASA6/$VER6/cosmic-comp" ]'
gb6 estado
confere "o estado diz ok" 'grep -qx "compositor_estado=ok" "$T/saida"'
: > "$C6/gb6.log"; gb6 rodar
confere "e o garantir não o refaz" '[ ! -s "$C6/gb6.log" ]'
comp6 env CP_BIN="$C6/bin/cargo" bash "$RAIZ/scripts/compositor_patches.sh" conferir
confere "o doctor diz que o patch entrou com o contexto mudado" 'grep -q "contexto mudado: t6.patch" "$T/saida"'
confere "nenhum sudo no compilar" '! grep -qv "^sudo -n true$" "$T/recusados" 2>/dev/null'

printf '\n7. patches/versao acompanha a matriz no gancho de commit\n'
V7="$T/versao7"; E7="$T/estado7"; mkdir -p "$E7/cosmic-comp"
printf '# cabeça\n1.0~velha\n' > "$V7"
printf '2.0~boa\t2026-11-06\tp.patch:2\n3.0~quebra\t2026-11-06\tp.patch:4\n4.0~falha\t2026-11-06\t\tfalhou=1@1\n' > "$E7/cosmic-comp/matriz.tsv"
env MEOW_ESTADO="$E7" NUMEROS_VERSAO="$V7" bash "$RAIZ/tests/numeros.sh" > "$T/saida" 2>&1
confere "a versão atrasada fica vermelha" 'grep -q "não tem a última versão boa da matriz: 2.0~boa" "$T/saida"'
env MEOW_ESTADO="$E7" NUMEROS_VERSAO="$V7" MEOW_NUMEROS_CORRIGIR=1 bash "$RAIZ/tests/numeros.sh" > "$T/saida" 2>&1
confere "o gancho a corrige, e só a linha da versão" '[ "$(cat "$V7")" = "# cabeça
2.0~boa" ]'

printf '\n'
[ "$falhas" = 0 ] && { printf 'etapa-compositor: tudo verde\n'; exit 0; }
printf 'etapa-compositor: %s falha(s)\n' "$falhas"; exit 1

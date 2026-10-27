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

printf '\n'
[ "$falhas" = 0 ] && { printf 'etapa-compositor: tudo verde\n'; exit 0; }
printf 'etapa-compositor: %s falha(s)\n' "$falhas"; exit 1

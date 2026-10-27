#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }
existe() { if [ -e "$2" ]; then ok "$1"; else falha "$1 ($2 não existe)"; fi; }
some()   { if [ ! -e "$2" ]; then ok "$1"; else falha "$1 ($2 existe)"; fi; }

H="$T/lar"; PINOS="$T/pinos"; ORIGEM="$T/origem"; VAZIO="$T/vazio"
mkdir -p "$H/.config/meow" "$PINOS" "$T/bin" "$ORIGEM/data" "$VAZIO"

(cd "$ORIGEM" && git init -q -b main . && git config user.email t@t && git config user.name t
 printf '[package]\nname = "meowsystem-teste"\nversion = "0.2.0"\n' > Cargo.toml
 printf '[Desktop Entry]\nName=Novo\nExec=@bindir@/meowsystem-teste\nIcon=io.github.teste.Novo\nX-CosmicApplet=true\n' > data/io.github.teste.Novo.desktop.in
 printf '<svg xmlns="http://www.w3.org/2000/svg"/>\n' > data/io.github.teste.Novo.svg
 git add -A && git -c core.hooksPath=/dev/null commit -q -m um)
C1="$(git -C "$ORIGEM" rev-parse HEAD)"
(cd "$VAZIO" && git init -q -b main . && git config user.email t@t && git config user.name t
 printf '[package]\nname = "nada"\nversion = "1.0.0"\n' > Cargo.toml
 git add -A && git -c core.hooksPath=/dev/null commit -q -m um)

cat > "$H/gitconfig" <<FIM2
[url "file://$ORIGEM"]
	insteadOf = https://exemplo.test/dona/cosmic-ext-applet-novo
[url "file://$VAZIO"]
	insteadOf = https://exemplo.test/dona/vazio
FIM2

cat > "$T/bin/cargo" <<FIM2
#!/bin/sh
echo "cargo \$*" >> "$T/cargo.log"
[ "\$1" = build ] || exit 0
mkdir -p "\$CARGO_TARGET_DIR/release"
printf '#!/bin/sh\n' > "\$CARGO_TARGET_DIR/release/meowsystem-teste"
chmod 755 "\$CARGO_TARGET_DIR/release/meowsystem-teste"
FIM2
chmod 755 "$T/bin/cargo"

PAINEL="$H/.config/cosmic/com.system76.CosmicPanel.Panel/v1"
mkdir -p "$PAINEL"
printf 'Some(([\n    "com.system76.CosmicAppletWorkspaces",\n], [\n    "io.velho.Antigo",\n    "outro.Applet",\n]))' > "$PAINEL/plugins_wings"
printf 'Some([\n    "com.system76.CosmicAppletTime",\n])' > "$PAINEL/plugins_center"
printf 'MIDIA="sim"\nLEITURA_APPLET="sim"\nEXTENSOES=""\n' > "$H/.config/meow/meow.conf"

G() {
  env -i PATH="$T/bin:$PATH" HOME="$H" NO_COLOR=1 USER=t GIT_CONFIG_GLOBAL="$H/gitconfig" \
    XDG_DATA_HOME="$H/.local/share" XDG_CONFIG_HOME="$H/.config" MEOW_CONF="$H/.config/meow/meow.conf" \
    MEOW_ESTADO="$H/.local/state/meowsystem" EXTENSOES_PINOS="${PINOS_USADOS:-$PINOS}" \
    bash "$RAIZ/scripts/extensoes_gesto.sh" "$@" 2>&1
}
USUARIO="$H/.local/state/meowsystem/extensoes/usuario"
conf() { sed -n 's/^EXTENSOES="\(.*\)"/\1/p' "$H/.config/meow/meow.conf"; }

echo "== ler: só https, só applet do COSMIC, e nada é instalado"
saida="$(G ler http://exemplo.test/dona/cosmic-ext-applet-novo)"; rc=$?
igual "http é recusado" "$rc" 2
saida="$(G ler https://exemplo.test/dona/vazio)"; rc=$?
igual "repositório sem applet é recusado" "$rc" 4
saida="$(G ler https://exemplo.test/dona/cosmic-ext-applet-novo)"; rc=$?
igual "o applet é lido" "$rc" 0
igual "a ficha traz o id" "$(printf '%s\n' "$saida" | sed -n 's/^id=//p')" novo
igual "a ficha traz o commit" "$(printf '%s\n' "$saida" | sed -n 's/^commit=//p')" "$C1"
igual "a ficha traz o dono/nome" "$(printf '%s\n' "$saida" | sed -n 's/^repo=//p')" "dona/cosmic-ext-applet-novo"
some "ler não instala nada" "$H/.local/bin/meowsystem-teste"
some "ler não grava o pino ainda" "$USUARIO/novo.pino"

echo "== adicionar: o pino passa para a lista do usuário"
saida="$(G adicionar novo)"; rc=$?
igual "adicionar devolve 0" "$rc" 0
existe "o pino do usuário existe" "$USUARIO/novo.pino"
igual "e diz o app id" "$(sed -n 's/^APP_ID="\(.*\)"/\1/p' "$USUARIO/novo.pino")" io.github.teste.Novo
igual "e a data do commit" "$(sed -n 's/^DATA="\(.*\)"/\1/p' "$USUARIO/novo.pino")" "$(git -C "$ORIGEM" log -1 --format=%cd --date=format:%d/%m/%Y)"
igual "e o ícone" "$(sed -n 's/^ICONES="\(.*\)"/\1/p' "$USUARIO/novo.pino")" "data/io.github.teste.Novo.svg:scalable/apps"

echo "== instalar um repo do usuário: compila, não mexe no EXTENSOES"
saida="$(G instalar novo)"; rc=$?
igual "instalar devolve 1 (mudou)" "$rc" 1
existe "o binário está no lugar" "$H/.local/bin/meowsystem-teste"
existe "a sombra está no lugar" "$H/.local/share/applications/io.github.teste.Novo.desktop"
igual "EXTENSOES segue vazio" "$(conf)" ""
estado="$(env -i PATH="$T/bin:$PATH" HOME="$H" MEOW_ESTADO="$H/.local/state/meowsystem" XDG_DATA_HOME="$H/.local/share" XDG_CONFIG_HOME="$H/.config" bash "$RAIZ/scripts/extensoes_build.sh" novo --estado 2>&1)"
igual "o estado diz instalada" "$(printf '%s\n' "$estado" | sed -n 's/^instalada=//p')" sim
igual "e que não é da casa" "$(printf '%s\n' "$estado" | sed -n 's/^casa=//p')" 0

echo "== por no painel: no fim da ala direita, sem mexer na ordem"
saida="$(G por novo)"; rc=$?
igual "por devolve 1" "$rc" 1
igual "o applet é o último" "$(grep -o '"[^"]*"' "$PAINEL/plugins_wings" | tail -1)" '"io.github.teste.Novo"'
igual "e os outros ficaram na ordem" "$(grep -o '"[^"]*"' "$PAINEL/plugins_wings" | head -3 | paste -sd' ')" '"com.system76.CosmicAppletWorkspaces" "io.velho.Antigo" "outro.Applet"'
saida="$(G por novo)"; rc=$?
igual "de novo não escreve" "$rc" 0

echo "== trocar: o antigo sai e o novo ocupa a mesma posição"
sed -i 's/^SUBSTITUI=.*/SUBSTITUI="io.velho.Antigo"/' "$USUARIO/novo.pino"
saida="$(G trocar novo)"; rc=$?
igual "trocar devolve 1" "$rc" 1
igual "se o novo já estava, o antigo só sai" "$(grep -o '"[^"]*"' "$PAINEL/plugins_wings" | paste -sd' ')" '"com.system76.CosmicAppletWorkspaces" "outro.Applet" "io.github.teste.Novo"'
printf 'Some(([\n    "com.system76.CosmicAppletWorkspaces",\n], [\n    "io.velho.Antigo",\n    "outro.Applet",\n]))' > "$PAINEL/plugins_wings"
saida="$(G trocar novo)"
igual "senão o novo ocupa a posição do antigo" "$(grep -o '"[^"]*"' "$PAINEL/plugins_wings" | paste -sd' ')" '"com.system76.CosmicAppletWorkspaces" "io.github.teste.Novo" "outro.Applet"'
igual "o centro não mudou" "$(cat "$PAINEL/plugins_center")" "$(printf 'Some([\n    "com.system76.CosmicAppletTime",\n])')"

echo "== a Dock: trocar troca onde o antigo mora, e por sem troca vai ao Panel"
DOCK="$H/.config/cosmic/com.system76.CosmicPanel.Dock/v1"
mkdir -p "$DOCK"
printf 'Some(([\n    "com.system76.CosmicAppletWorkspaces",\n], [\n    "outro.Applet",\n]))' > "$PAINEL/plugins_wings"
printf 'Some(([\n    "com.system76.CosmicAppList",\n], [\n    "io.velho.Antigo",\n    "com.system76.CosmicAppletMinimize",\n]))' > "$DOCK/plugins_wings"
painel_antes="$(md5sum < "$PAINEL/plugins_wings")"
saida="$(G trocar novo)"; rc=$?
igual "trocar com o antigo só na Dock devolve 1" "$rc" 1
igual "o novo ocupa a posição do antigo na Dock" "$(grep -o '"[^"]*"' "$DOCK/plugins_wings" | paste -sd' ')" '"com.system76.CosmicAppList" "io.github.teste.Novo" "com.system76.CosmicAppletMinimize"'
igual "o Panel não mudou" "$(md5sum < "$PAINEL/plugins_wings")" "$painel_antes"
dock_antes="$(md5sum < "$DOCK/plugins_wings")"
saida="$(G trocar novo)"; rc=$?
igual "a segunda passada do trocar devolve 0" "$rc" 0
igual "e não escreve na Dock" "$(md5sum < "$DOCK/plugins_wings")" "$dock_antes"
printf 'Some(([\n    "com.system76.CosmicAppList",\n], [\n    "com.system76.CosmicAppletMinimize",\n]))' > "$DOCK/plugins_wings"
dock_antes="$(md5sum < "$DOCK/plugins_wings")"
saida="$(G por novo)"; rc=$?
igual "por sem troca devolve 1" "$rc" 1
igual "e escreve no fim do Panel" "$(grep -o '"[^"]*"' "$PAINEL/plugins_wings" | tail -1)" '"io.github.teste.Novo"'
igual "a Dock não mudou" "$(md5sum < "$DOCK/plugins_wings")" "$dock_antes"
painel_antes="$(md5sum < "$PAINEL/plugins_wings")"
saida="$(G por novo)"; rc=$?
igual "a segunda passada do por devolve 0" "$rc" 0
igual "e não escreve no Panel" "$(md5sum < "$PAINEL/plugins_wings")" "$painel_antes"
printf 'Some(([\n    "com.system76.CosmicAppletWorkspaces",\n], [\n    "outro.Applet",\n]))' > "$PAINEL/plugins_wings"
printf 'Some(([\n    "com.system76.CosmicAppList",\n], [\n    "io.velho.Antigo",\n]))' > "$DOCK/plugins_wings"
saida="$(G por novo)"; rc=$?
igual "por com o antigo na Dock devolve 1" "$rc" 1
igual "e escreve na Dock, onde o antigo mora" "$(grep -o '"[^"]*"' "$DOCK/plugins_wings" | tail -1)" '"io.github.teste.Novo"'
igual "e o Panel fica como estava" "$(grep -o '"[^"]*"' "$PAINEL/plugins_wings" | paste -sd' ')" '"com.system76.CosmicAppletWorkspaces" "outro.Applet"'
rm -rf "$H/.config/cosmic/com.system76.CosmicPanel.Dock"

echo "== reiniciar-painel: só o painel desta casa, e aqui não há nenhum de pé"
saida="$(G reiniciar-painel)"; rc=$?
igual "reiniciar-painel devolve 0 sem painel desta casa" "$rc" 0

echo "== atualizar: o commit novo vira o pino e é compilado"
(cd "$ORIGEM" && printf 'x' > data/mais && git add -A && git -c core.hooksPath=/dev/null commit -q -m dois)
C2="$(git -C "$ORIGEM" rev-parse HEAD)"
saida="$(G atualizar novo)"; rc=$?
igual "atualizar devolve 1" "$rc" 1
igual "o pino anda para o commit novo" "$(sed -n 's/^COMMIT="\(.*\)"/\1/p' "$USUARIO/novo.pino")" "$C2"

echo "== refazer: sem o carimbo, o cargo roda de novo"
antes="$(grep -c '^cargo build' "$T/cargo.log")"
saida="$(G refazer novo)"; rc=$?
igual "refazer devolve 1" "$rc" 1
igual "e o cargo rodou uma vez a mais" "$(grep -c '^cargo build' "$T/cargo.log")" "$((antes + 1))"
saida="$(G refazer nao-existe)"; rc=$?
igual "um id desconhecido é recusado" "$rc" 2

echo "== remover um repo do usuário: some o binário e o pino"
saida="$(G remover novo)"; rc=$?
igual "remover devolve 1" "$rc" 1
some "o binário saiu" "$H/.local/bin/meowsystem-teste"
some "o pino saiu" "$USUARIO/novo.pino"

echo "== extensão da casa: instalar e remover escrevem o EXTENSOES"
mkdir -p "$T/casa-pinos"
cat > "$T/casa-pinos/fake.pino" <<FIM2
ORDEM=3
NOME="Fake"
URL="https://exemplo.test/dona/cosmic-ext-applet-novo"
COMMIT="$C2"
VERSAO="0.2.0"
APP_ID="io.github.teste.Novo"
BIN="meowsystem-teste"
DESKTOP="data/io.github.teste.Novo.desktop.in"
ICONES="data/io.github.teste.Novo.svg:scalable/apps"
FIM2
ordem=0
for par in now-playing:MIDIA leitura:LEITURA_APPLET; do
  ordem=$((ordem + 1))
  cat > "$T/casa-pinos/${par%%:*}.pino" <<FIM2
ORDEM=$ordem
TIPO="applet"
PADRAO="sim"
CHAVE_DO_CONF="${par#*:}"
NOME="${par%%:*}"
URL="https://exemplo.test/dona/${par%%:*}"
COMMIT="$C2"
APP_ID="io.github.teste.${par#*:}"
BIN="meowsystem-${par%%:*}"
DESKTOP="data/x.desktop"
FIM2
done
PINOS_USADOS="$T/casa-pinos"
saida="$(G instalar fake)"; rc=$?
igual "instalar da casa devolve 1" "$rc" 1
igual "EXTENSOES ganha o id, somado ao que já valia" "$(conf)" "now-playing,leitura,fake"
existe "e o binário está no lugar" "$H/.local/bin/meowsystem-teste"
saida="$(G remover fake)"; rc=$?
igual "remover da casa devolve 1" "$rc" 1
igual "EXTENSOES perde só o id" "$(conf)" "now-playing,leitura"
some "e o binário saiu" "$H/.local/bin/meowsystem-teste"
printf 'MIDIA="nao"\nLEITURA_APPLET="nao"\nEXTENSOES=""\n' > "$H/.config/meow/meow.conf"
saida="$(G instalar fake)"; rc=$?
igual "com a lista derivada vazia, o id vai sozinho" "$(conf)" "fake"
saida="$(G remover fake)"; rc=$?
igual "e tirar o último grava o traço" "$(conf)" "-"

[ "$falhas" = 0 ] || { printf '\n%s falha(s)\n' "$falhas"; exit 1; }
printf '\nok: os gestos das extensões passaram, sem rede e sem compilar\n'

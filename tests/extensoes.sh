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

REPO="$T/repo"; PINOS="$T/pinos"; H="$T/lar"
mkdir -p "$REPO/data/icones" "$REPO/data/icons/scalable/apps" "$PINOS" "$H" "$T/bin"
cd "$REPO" && git init -q -b main . && git config user.email t@t && git config user.name t
cat > Cargo.toml <<'FIM'
[package]
name = "meowsystem-teste"
version = "0.4.2"
[dependencies.libcosmic]
git = "https://github.com/pop-os/libcosmic.git"
rev = "1111111111111111111111111111111111111111"
FIM
printf '[[package]]\nname = "libcosmic"\nsource = "git+https://github.com/pop-os/libcosmic#1111111111111111111111111111111111111111"\n' > Cargo.lock
cat > data/io.github.teste.Fake.desktop.in <<'FIM'
[Desktop Entry]
Name=Fake
Exec=@bindir@/meowsystem-teste
Icon=io.github.teste.Fake
X-CosmicApplet=true
FIM
printf '<svg xmlns="http://www.w3.org/2000/svg"/>\n' > data/icons/scalable/apps/io.github.teste.Fake.svg
printf '<component type="desktop-application"><id>io.github.teste.Fake</id></component>\n' > data/io.github.teste.Fake.metainfo.xml
git add -A && git -c core.hooksPath=/dev/null commit -q -m um && C1="$(git rev-parse HEAD)"
cd "$RAIZ"

pino() {
  cat > "$PINOS/fake.pino" <<FIM
ORDEM=1
NOME="Fake"
URL="$REPO"
COMMIT="$1"
VERSAO="0.4.2"
LIBCOSMIC="1111111111111111111111111111111111111111"
APP_ID="io.github.teste.Fake"
BIN="meowsystem-teste"
DESKTOP="data/io.github.teste.Fake.desktop.in"
ICONES="data/icons:."
METAINFO="data/io.github.teste.Fake.metainfo.xml"
SUBSTITUI="io.github.velho.Fake"
LEGADO="io.github.velho.Fake:meow-fake-velho"
FIM
}
pino "$C1"

lock_painel() { printf '[[package]]\nname = "libcosmic"\nsource = "git+https://github.com/pop-os/libcosmic#%s"\n' "$1" > "$T/painel.lock"; }
lock_painel 1111111111111111111111111111111111111111

cat > "$T/bin/cargo" <<FIM
#!/bin/sh
echo "cargo \$*" >> "$T/cargo.log"
[ "\$1" = build ] || exit 0
case "\$*" in *--locked*) ;; *) [ -f "$T/painel-falha" ] && exit 101 ;; esac
[ -f "$T/cargo-falha" ] && { echo "error: linker \\\`cc\\\` not found" >&2; exit 101; }
mkdir -p "\$CARGO_TARGET_DIR/release"
printf '#!/bin/sh\n# %s\n' "\$(grep -o 'rev = "[0-9a-f]*"' "$T/lar/.local/state/meowsystem/extensoes/fake/src/Cargo.toml")" > "\$CARGO_TARGET_DIR/release/meowsystem-teste"
chmod 755 "\$CARGO_TARGET_DIR/release/meowsystem-teste"
FIM
chmod 755 "$T/bin/cargo"

EB() {
  env -i PATH="$T/bin:$PATH" HOME="$H" NO_COLOR=1 USER=t \
    XDG_DATA_HOME="$H/.local/share" XDG_CONFIG_HOME="$H/.config" \
    MEOW_ESTADO="$H/.local/state/meowsystem" EXTENSOES_PINOS="$PINOS" EXTENSOES_PERMITE_LOCAL=1 \
    AP_LOCK_PAINEL="$T/painel.lock" "$@" bash "$RAIZ/scripts/extensoes_build.sh" 2>&1
}
run() { local -a v=(); while [ "${1#*=}" != "$1" ]; do v+=("$1"); shift; done; EBX "${v[@]+"${v[@]}"}" "$@"; }
EBX() {
  local -a v=(); while [ "$#" -gt 0 ] && [ "${1#*=}" != "$1" ]; do v+=("$1"); shift; done
  env -i PATH="$T/bin:$PATH" HOME="$H" NO_COLOR=1 USER=t \
    XDG_DATA_HOME="$H/.local/share" XDG_CONFIG_HOME="$H/.config" \
    MEOW_ESTADO="$H/.local/state/meowsystem" EXTENSOES_PINOS="$PINOS" EXTENSOES_PERMITE_LOCAL=1 \
    AP_LOCK_PAINEL="$T/painel.lock" ${v[@]+"${v[@]}"} bash "$RAIZ/scripts/extensoes_build.sh" "$@" 2>&1
}
builds() { grep -c '^cargo build' "$T/cargo.log" 2>/dev/null || true; }
arquivos() { (cd "$H" && find . -mindepth 1 ! -type d | sort); }
BIN="$H/.local/bin/meowsystem-teste"
SOMBRA="$H/.local/share/applications/io.github.teste.Fake.desktop"
ICONE="$H/.local/share/icons/hicolor/scalable/apps/io.github.teste.Fake.svg"
METAINFO_F="$H/.local/share/metainfo/io.github.teste.Fake.metainfo.xml"
ESTADO="$H/.local/state/meowsystem/extensoes/fake"

echo "== sem rede e sem cargo: o seco e o conferir não escrevem"
: > "$T/cargo.log"
saida="$(EBX MEOW_DRY_RUN=1 EXTENSOES_COMPILAR=1 fake --aplicar)"; rc=$?
igual "o seco, sem binário, diverge" "$rc" 1
igual "o seco não deixou arquivo nenhum" "$(arquivos | wc -l)" 0
saida="$(EBX fake --conferir)"; rc=$?
igual "conferir, sem binário, diverge" "$rc" 1
igual "conferir não deixou arquivo nenhum" "$(arquivos | wc -l)" 0
igual "e o cargo não rodou" "$(builds)" 0

echo "== sem EXTENSOES_COMPILAR, o aplicar só avisa"
saida="$(EBX fake --aplicar)"; rc=$?
igual "sem permissão para compilar: rc 3" "$rc" 3
some "e não instalou o binário" "$BIN"
grep -q '^extensao-fake' "$H/.local/state/meowsystem/pendencias.tsv" && ok "e deixou a pendência acionável" || falha "sem pendência"

echo "== aplicar compila, instala o binário, a sombra e o ícone"
: > "$T/cargo.log"
saida="$(EBX EXTENSOES_COMPILAR=1 fake --aplicar)"; rc=$?
igual "rc 1 (mudou)" "$rc" 1
igual "um build" "$(builds)" 1
grep -q -- '--locked' "$T/cargo.log" && ok "e com --locked" || falha "faltou --locked"
existe "binário" "$BIN"
existe "sombra" "$SOMBRA"
existe "ícone" "$ICONE"
existe "metainfo" "$METAINFO_F"
grep -qxF "$METAINFO_F" "$ESTADO/icones.lista" && ok "o metainfo entra na lista do que é nosso" || falha "metainfo fora da lista"
grep -qx "Exec=$H/.local/bin/meowsystem-teste" "$SOMBRA" && ok "o Exec é o caminho absoluto" || falha "Exec: $(grep Exec "$SOMBRA")"
! grep -q '^extensao-fake' "$H/.local/state/meowsystem/pendencias.tsv" 2>/dev/null && ok "a pendência saiu" || falha "a pendência ficou"
grep -q "$C1" "$ESTADO/carimbo" && ok "o carimbo guarda o commit" || falha "carimbo sem commit"

echo "== a segunda passada não escreve e não compila"
antes="$(cd "$H" && find . -mindepth 1 ! -type d -exec sha256sum {} + | sort | grep -v 'pendencias.tsv\|meow.log')"
: > "$T/cargo.log"
saida="$(EBX EXTENSOES_COMPILAR=1 fake --aplicar)"; rc=$?
igual "rc 0" "$rc" 0
igual "nenhum build" "$(builds)" 0
depois="$(cd "$H" && find . -mindepth 1 ! -type d -exec sha256sum {} + | sort | grep -v 'pendencias.tsv\|meow.log')"
igual "nenhum arquivo mudou" "$depois" "$antes"
saida="$(EBX fake --conferir)"; igual "conferir: rc 0" "$?" 0

echo "== instalada antes do METAINFO: o metainfo volta sem compilar"
rm -f "$METAINFO_F"; grep -vxF "$METAINFO_F" "$ESTADO/icones.lista" > "$T/lista" || true; cp "$T/lista" "$ESTADO/icones.lista"
soma=""; while IFS= read -r f; do soma="$soma$(sha256sum "$f" | cut -d' ' -f1)"; done < "$ESTADO/icones.lista"
sed -i "s/^icones .*/icones $(printf '%s' "$soma" | sha256sum | cut -d' ' -f1)/" "$ESTADO/carimbo"
saida="$(EBX fake --conferir)"; igual "sem o metainfo o conferir diverge" "$?" 1
: > "$T/cargo.log"
saida="$(EBX EXTENSOES_COMPILAR=1 fake --aplicar)"; rc=$?
igual "rc 1 (mudou)" "$rc" 1
igual "sem cargo" "$(builds)" 0
existe "metainfo de volta" "$METAINFO_F"
saida="$(EBX fake --conferir)"; igual "e o conferir fecha" "$?" 0

echo "== o estado diz o que a página precisa"
saida="$(EBX fake --estado)"
grep -qx 'instalada=sim' <<< "$saida" && grep -qx 'em_dia=sim' <<< "$saida" && grep -qx 'na_barra=nao' <<< "$saida" && ok "instalada, em dia, fora da barra" || falha "estado: $saida"
mkdir -p "$H/.config/cosmic/com.system76.CosmicPanel.Panel/v1"
printf 'Some(([], ["io.github.velho.Fake"]))' > "$H/.config/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings"
saida="$(EBX fake --estado)"
grep -qx 'troca=io.github.velho.Fake' <<< "$saida" && ok "a barra cita o id antigo: troca oferecida" || falha "troca: $saida"

echo "== o pino andou: atualização, e um build só"
cd "$REPO" && echo novo >> data/novo && git add -A && git -c core.hooksPath=/dev/null commit -q -m dois && C2="$(git rev-parse HEAD)"; cd "$RAIZ"
pino "$C2"
saida="$(EBX fake --estado)"
grep -qx 'atualizacao=sim' <<< "$saida" && ok "estado: atualização" || falha "estado: $saida"
: > "$T/cargo.log"
saida="$(EBX EXTENSOES_COMPILAR=1 fake --aplicar)"; rc=$?
igual "rc 1" "$rc" 1
igual "um build" "$(builds)" 1
saida="$(EBX fake --estado)"
grep -qx 'atualizacao=nao' <<< "$saida" && ok "depois: sem atualização" || falha "estado: $saida"

echo "== o painel andou: segue o libcosmic do painel, e volta ao pino se não compilar"
OUTRA=2222222222222222222222222222222222222222
lock_painel "$OUTRA"; : > "$T/cargo.log"
saida="$(EBX EXTENSOES_COMPILAR=1 fake --aplicar)"; rc=$?
igual "rc 1" "$rc" 1
grep -q "$OUTRA" "$BIN" && ok "o binário é o do libcosmic do painel" || falha "binário: $(cat "$BIN")"
: > "$T/cargo.log"; saida="$(EBX EXTENSOES_COMPILAR=1 fake --aplicar)"
igual "zero builds na passagem seguinte" "$(builds)" 0

OUTRA2=3333333333333333333333333333333333333333
cd "$REPO" && echo c >> data/novo && git add -A && git -c core.hooksPath=/dev/null commit -q -m painel && C4="$(git rev-parse HEAD)"; cd "$RAIZ"
pino "$C4"; lock_painel "$OUTRA2"; touch "$T/painel-falha"; : > "$T/cargo.log"
saida="$(EBX EXTENSOES_COMPILAR=1 fake --aplicar)"; rc=$?
igual "o painel andou e não compila nele: dois builds (painel, depois pino)" "$(builds)" 2
grep -q 1111111111111111111111111111111111111111 "$BIN" && ok "o binário voltou ao pino" || falha "binário: $(cat "$BIN")"
: > "$T/cargo.log"; saida="$(EBX EXTENSOES_COMPILAR=1 fake --aplicar)"
igual "e não tenta de novo na passagem seguinte" "$(builds)" 0
rm -f "$T/painel-falha"

echo "== cargo que falha: nada é trocado, o log diz o motivo, o estado marca a falha"
cd "$REPO" && echo outro >> data/novo && git add -A && git -c core.hooksPath=/dev/null commit -q -m tres && C3="$(git rev-parse HEAD)"; cd "$RAIZ"
pino "$C3"; lock_painel 1111111111111111111111111111111111111111
antes="$(sha256sum "$BIN")"; touch "$T/cargo-falha"
saida="$(EBX EXTENSOES_COMPILAR=1 fake --aplicar)"; rc=$?
igual "rc 2" "$rc" 2
grep -q 'compilador C' <<< "$saida" && ok "o motivo é legível" || falha "motivo: $saida"
igual "o binário anterior ficou" "$(sha256sum "$BIN")" "$antes"
grep -qx 'falhou=sim' <<< "$(EBX fake --estado)" && ok "estado: falhou" || falha "estado sem falhou"
rm -f "$T/cargo-falha"
saida="$(EBX EXTENSOES_COMPILAR=1 fake --aplicar)"; rc=$?
igual "tentar de novo cura" "$rc" 1
grep -qx 'falhou=nao' <<< "$(EBX fake --estado)" && ok "e a marca de falha sai" || falha "falhou ficou"

echo "== o binário sumiu: volta sem compilar"
rm -f "$BIN"; : > "$T/cargo.log"
saida="$(EBX EXTENSOES_COMPILAR=1 fake --aplicar)"; rc=$?
igual "rc 1" "$rc" 1
igual "sem cargo" "$(builds)" 0
existe "binário de volta" "$BIN"

echo "== sombra órfã: sem binário e sem poder compilar, a sombra sai"
SOMBRA_F="$H/.local/share/applications/io.github.teste.Fake.desktop"
cp "$BIN" "$T/bin-guardado"; rm -f "$BIN"; rm -rf "$H/.local/state/meowsystem/extensoes/fake/target"
existe "armado: sombra sem binário" "$SOMBRA_F"
saida="$(EBX MEOW_DRY_RUN=1 fake --aplicar)"; igual "o seco só avisa (diverge)" "$?" 1
existe "o seco não tirou a sombra" "$SOMBRA_F"
saida="$(EBX fake --aplicar)"; igual "sem EXTENSOES_COMPILAR: rc 3" "$?" 3
some "a sombra órfã saiu" "$SOMBRA_F"
saida="$(EBX EXTENSOES_COMPILAR=1 fake --aplicar)"; igual "o build recria" "$?" 1
existe "sombra de volta" "$SOMBRA_F"
existe "binário de volta" "$BIN"

echo "== o legado só sai quando a barra não o cita"
mkdir -p "$H/.local/share/applications"
printf '[Desktop Entry]\nExec=%s/.local/bin/meow-fake-velho\n' "$H" > "$H/.local/share/applications/io.github.velho.Fake.desktop"
printf '#!/bin/sh\n' > "$H/.local/bin/meow-fake-velho"; chmod 755 "$H/.local/bin/meow-fake-velho"
saida="$(EBX fake --conferir)"; igual "a barra cita o antigo: nada a fazer" "$?" 0
printf 'Some(([], []))' > "$H/.config/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings"
saida="$(EBX fake --conferir)"; igual "a barra largou o antigo: diverge" "$?" 1
: > "$T/cargo.log"
saida="$(EBX EXTENSOES_COMPILAR=1 fake --aplicar)"; rc=$?
igual "limpa sem compilar" "$(builds)" 0
some "sombra antiga saiu" "$H/.local/share/applications/io.github.velho.Fake.desktop"
some "binário antigo saiu" "$H/.local/bin/meow-fake-velho"

echo "== pino malformado não executa nada"
cat > "$PINOS/ruim.pino" <<FIM
URL="https://exemplo.com/a.git; touch $T/pwn"
COMMIT="abcdef1"
APP_ID="a.b"
BIN="x"
DESKTOP="../fora"
FIM
saida="$(EBX ruim --conferir)"; rc=$?
igual "recusa" "$rc" 2
some "e nada rodou" "$T/pwn"

echo "== reverter tira o que é nosso e deixa a configuração"
mkdir -p "$H/.config/cosmic/io.github.teste.Fake/v1"; echo x > "$H/.config/cosmic/io.github.teste.Fake/v1/chave"
saida="$(EBX fake --reverter)"
some "binário" "$BIN"; some "sombra" "$SOMBRA"; some "ícone" "$ICONE"; some "metainfo" "$METAINFO_F"; some "árvore" "$ESTADO"
existe "a configuração fica" "$H/.config/cosmic/io.github.teste.Fake/v1/chave"

echo "== METAINFO fora do lugar não executa nada"
for ruim in "../fora.metainfo.xml" "data/a.xml" "/etc/a.metainfo.xml"; do
  printf 'URL="https://exemplo.com/a.git"\nCOMMIT="abcdef1"\nAPP_ID="a.b"\nBIN="x"\nDESKTOP="d/a.desktop"\nMETAINFO="%s"\n' "$ruim" > "$PINOS/ruim.pino"
  saida="$(EBX ruim --conferir)"; igual "METAINFO=$ruim: recusa" "$?" 2
done
rm -f "$PINOS/ruim.pino"

echo "== EXTENSOES manda no --todas"
rm -f "$PINOS/ruim.pino"
saida="$(EBX EXTENSOES=- --todas --conferir)"; igual "lista vazia (-): nada pedido, rc 3" "$?" 3
saida="$(EBX EXTENSOES=fake --todas --conferir)"; igual "pedida e ausente: diverge" "$?" 1
saida="$(EBX EXTENSOES=fake EXTENSOES_COMPILAR=1 --todas --aplicar)"; igual "aplica pelo --todas" "$?" 1
existe "binário pelo --todas" "$BIN"
saida="$(EBX EXTENSOES=- --todas --conferir)"; igual "instalada e fora da lista: diverge" "$?" 1
saida="$(EBX EXTENSOES=- --todas --aplicar)"; some "fora da lista, o --aplicar remove" "$BIN"
saida="$(EBX EXTENSOES=fake EXTENSOES_COMPILAR=1 --todas --aplicar)"
saida="$(EBX --todas --reverter)"; igual "--todas --reverter: mexeu" "$?" 1
some "e o binário saiu" "$BIN"
saida="$(EBX --todas --reverter)"; igual "e a segunda não tem o que tirar" "$?" 0

echo "== PADRAO=sim: sem EXTENSOES, o pino entra no --todas sozinho"
saida="$(EBX --todas --conferir)"; igual "sem PADRAO e sem EXTENSOES: nada pedido, rc 3" "$?" 3
sed -i 's/^ORDEM=1$/ORDEM=1\nTIPO="applet"\nPADRAO="sim"\nCHAVE_DO_CONF="FAKE_APPLET"/' "$PINOS/fake.pino"
saida="$(EBX --todas --conferir)"; igual "PADRAO=sim sem EXTENSOES: pedida e ausente, diverge" "$?" 1
igual "o --queridas a lista" "$(EBX --queridas)" fake
saida="$(EBX FAKE_APPLET=nao --todas --conferir)"; igual "a chave do conf em nao a tira" "$?" 3
saida="$(EBX EXTENSOES=- --todas --conferir)"; igual "EXTENSOES=- vence o PADRAO" "$?" 3
pino "$C1"

echo "== o tema do pack: gerado, igual na segunda passada, e muda com o sabor"
TH="$T/tema"; mkdir -p "$TH/.local/bin"
printf '#!/bin/sh\n' > "$TH/.local/bin/meowsystem-status-hub"; chmod 755 "$TH/.local/bin/meowsystem-status-hub"
printf '#!/bin/sh\n' > "$TH/.local/bin/meowsystem-quick-settings"; chmod 755 "$TH/.local/bin/meowsystem-quick-settings"
TEMA() { local -a v=(); while [ "$#" -gt 0 ] && [ "${1#*=}" != "$1" ]; do v+=("$1"); shift; done
  env -i PATH="$PATH" HOME="$TH" NO_COLOR=1 USER=t XDG_CONFIG_HOME="$TH/.config" MEOW_ESTADO="$TH/estado" \
    ${v[@]+"${v[@]}"} bash "$RAIZ/scripts/extensoes_tema.sh" "$@" 2>&1; }
BANDEJA="$TH/.config/meowsystem/extensoes/io.github.meowsystem.Bandeja/tema.conf"
AJUSTES="$TH/.config/meowsystem/extensoes/io.github.meowsystem.AjustesRapidos/tema.conf"
saida="$(TEMA MEOW_DRY_RUN=1 FLAVOR=mocha)"; igual "o seco diverge" "$?" 1
some "e não escreveu a Bandeja" "$BANDEJA"
saida="$(TEMA FLAVOR=mocha)"; igual "aplicar escreve" "$?" 1
existe "tema da Bandeja" "$BANDEJA"; existe "tema dos Ajustes rápidos" "$AJUSTES"
grep -qx 'acento = #cba6f7' "$BANDEJA" && grep -qx 'tinta = #cdd6f4' "$BANDEJA" && ok "a Bandeja leva a mauve e o texto da mocha" || falha "Bandeja: $(cat "$BANDEJA")"
grep -qx 'bloco = #313244' "$AJUSTES" && grep -qx 'microfone = #fab387' "$AJUSTES" && ok "os Ajustes rápidos levam as nove chaves da mocha" || falha "Ajustes: $(cat "$AJUSTES")"
igual "nove chaves nos Ajustes" "$(grep -c ' = #' "$AJUSTES")" 9
antes="$(cd "$TH" && find . -type f -exec sha256sum {} + | sort)"
saida="$(TEMA FLAVOR=mocha)"; igual "segunda passada: rc 0" "$?" 0
igual "e nada mudou" "$(cd "$TH" && find . -type f -exec sha256sum {} + | sort)" "$antes"
saida="$(TEMA FLAVOR=latte --conferir)"; igual "outro sabor: o conferir diverge" "$?" 1
saida="$(TEMA FLAVOR=latte)"
grep -qx 'tinta = #4c4f69' "$BANDEJA" && ok "e o aplicar traz a latte" || falha "latte: $(cat "$BANDEJA")"
saida="$(TEMA --reverter)"; some "reverter tira o tema" "$BANDEJA"
grep -q 'Bandeja\|AjustesRapidos' "$RAIZ/scripts/extensoes_tema.sh" && falha "o extensoes_tema.sh ainda nomeia um applet" || ok "o extensoes_tema.sh não nomeia applet: as chaves moram no pino"
NP="$T/pinos-tema"; mkdir -p "$NP"
printf 'ORDEM=1\nNOME="Novo"\nBIN="meowsystem-status-hub"\nTEMA="io.github.teste.Novo"\nTEMA_CHAVES="fundo:base/f0 realce:@acento"\n' > "$NP/novo.pino"
saida="$(TEMA EXTENSOES_PINOS="$NP" FLAVOR=mocha)"; igual "um pino novo com TEMA_CHAVES ganha tema sem código" "$?" 1
NOVO="$TH/.config/meowsystem/extensoes/io.github.teste.Novo/tema.conf"
igual "com as chaves do pino, o sufixo e o acento" "$(cat "$NOVO" 2>/dev/null | paste -sd' ')" "fundo = #1e1e2ef0 realce = #cba6f7"

echo "== os quatro forks: pino válido e a troca do app id de hoje"
FK="$T/forks"; mkdir -p "$FK/.local/bin" "$FK/.local/share/applications" "$FK/.config/cosmic/com.system76.CosmicPanel.Dock/v1"
ESTADO_FORK() { env -i PATH="$PATH" HOME="$FK" NO_COLOR=1 USER=t XDG_DATA_HOME="$FK/.local/share" XDG_CONFIG_HOME="$FK/.config" \
  MEOW_ESTADO="$FK/.local/state/meowsystem" EXTENSOES_PINOS="$RAIZ/assets/extensoes" AP_LOCK_PAINEL="$T/painel.lock" \
  bash "$RAIZ/scripts/extensoes_build.sh" "$1" --estado 2>&1; }
for par in eyedropper:meowsystem-eyedropper:io.github.meowsystem.Eyedropper:io.github.nalladev.CosmicExtAppletEyedropper \
           clipboard:meowsystem-clipboard:io.github.meowsystem.Clipboard:io.github.cosmic_utils.cosmic-ext-applet-clipboard-manager \
           drives:meowsystem-drives:io.github.meowsystem.Drives:dev.cappsy.CosmicExtAppletDrives \
           ascii-battery:meowsystem-ascii-battery:io.github.meowsystem.AsciiBattery:com.github.pewmoe.cosmic-ext-ASCII-dot-battery; do
  IFS=: read -r id bin appid velho <<< "$par"
  pino="$RAIZ/assets/extensoes/$id.pino"
  existe "$id: o pino existe" "$pino"
  grep -qx 'PADRAO="sim"' "$pino" && grep -qx 'TIPO="applet"' "$pino" && ok "$id: applet, ligado por padrão" || falha "$id: TIPO/PADRAO"
  grep -qx "APP_ID=\"$appid\"" "$pino" && grep -qx "BIN=\"$bin\"" "$pino" && grep -qx "SUBSTITUI=\"$velho\"" "$pino" && ok "$id: app id, binário e o id de hoje" || falha "$id: APP_ID/BIN/SUBSTITUI"
  grep -qx "TEMA=\"$appid\"" "$pino" && grep -q '^TEMA_CHAVES="acento:@acento ' "$pino" && ok "$id: tema e chaves" || falha "$id: TEMA/TEMA_CHAVES"
  existe "$id: o ícone do cartão" "$RAIZ/assets/extensoes/icones/$id.svg"
  saida="$(ESTADO_FORK "$id")"; igual "$id: o pino passa na validação" "$?" 0
  grep -qx "casa=1" <<< "$saida" && grep -qx "instalada=nao" <<< "$saida" && grep -qx "troca=" <<< "$saida" && ok "$id: sem binário, nada a trocar" || falha "$id: estado sem instalar: $saida"
  printf '#!/bin/sh\n' > "$FK/.local/bin/$bin"; chmod 755 "$FK/.local/bin/$bin"
  printf '[Desktop Entry]\nExec=%s/.local/bin/%s\n' "$FK" "$bin" > "$FK/.local/share/applications/$appid.desktop"
  printf 'Some(([\n    "%s",\n], []))' "$velho" > "$FK/.config/cosmic/com.system76.CosmicPanel.Dock/v1/plugins_wings"
  saida="$(ESTADO_FORK "$id")"
  grep -qx "troca=$velho" <<< "$saida" && ok "$id: a Dock cita $velho e o estado oferece a troca" || falha "$id: troca: $saida"
  rm -f "$FK/.local/bin/$bin" "$FK/.local/share/applications/$appid.desktop"
done
[ "$(grep -hx 'MIGRA_ESTADO=""' "$RAIZ"/assets/extensoes/{eyedropper,clipboard,drives,ascii-battery}.pino | wc -l)" = 4 ] \
  && ok "os quatro sem MIGRA_ESTADO: nenhum guarda estado em ~/.local/state/cosmic" \
  || falha "um fork aponta MIGRA_ESTADO para um estado que o applet não lê"

[ "$falhas" = 0 ] && { echo "extensoes.sh: tudo verde"; exit 0; }
echo "extensoes.sh: $falhas falha(s)"; exit 1

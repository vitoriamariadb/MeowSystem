#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
V="$RAIZ/scripts/vizinhos.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1"; fi; }

CASA="$T/casa"; ETC="$T/etc"; ZD="$CASA/.config/zsh"; DESENV="$CASA/Desenvolvimento"
ESTADO="$CASA/.local/state/meowsystem"
mkdir -p "$T/bin" "$ZD/functions" "$ZD/aurora" "$CASA/.config/systemd/user/default.target.wants" \
         "$ETC/apt/apt.conf.d" "$ETC/systemd/system" "$DESENV/Dracula_OS-Theme/scripts" "$CASA/.local/share/icons/hicolor/48x48/apps"
for c in curl wget sudo; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/rede.log"\nexit 1\n' "$c" "$T" > "$T/bin/$c"; chmod 755 "$T/bin/$c"
done

cat > "$ZD/.zshrc" <<'FIM'
# comentário que fala de install.sh e não chama nada
cura_no_login
FIM
cat > "$ZD/functions/sistema.zsh" <<'FIM'
#!/bin/zsh
cura_no_login() {
    _cura_menu
}
_cura_menu() {
    sed -i 's/a/b/' "$HOME/.config/cosmic/com.system76.CosmicTheme.Dark/v1/accent"
    "$HOME/.config/zsh/aurora/menu-doctor.sh" --fix
}
_reconstruir_caches_icones() {
    sudo gtk-update-icon-cache -f /usr/share/icons/x 2>/dev/null
    for tema_dir in "$HOME/.local/share/icons/"*/; do
        [ -f "${tema_dir}index.theme" ] || continue
        gtk-update-icon-cache -f -q "$tema_dir" 2>/dev/null
    done
    echo fim
}
# [2026-09-23] DESATIVADA: o Icon= é do MeowSystem.
_fix_flatpak_icons() {
    echo "quem acerta é o MeowSystem"
    return 0
    sed -i "s|^Icon=.*|Icon=x|" "$HOME/.local/share/applications/a.desktop"
}
FIM
printf "alias atualizar_icones='_reconstruir_caches_icones'\n" > "$ZD/aliases.zsh"
cat > "$ZD/aurora/menu-doctor.sh" <<'FIM'
#!/bin/sh
dst="$HOME/.local/share/applications/x.desktop"
printf 'StartupWMClass=y\n' > "$dst"
FIM
cat > "$ZD/aurora/cursor.sh" <<'FIM'
#!/bin/sh
gsettings set org.gnome.desktop.interface cursor-theme Outro
FIM
printf '[Service]\nExecStart=%%h/.config/zsh/aurora/cursor.sh\n' > "$CASA/.config/systemd/user/vizinho-cursor.service"
ln -s ../vizinho-cursor.service "$CASA/.config/systemd/user/default.target.wants/vizinho-cursor.service"
printf '[Service]\nExecStart=%%h/.config/zsh/aurora/cursor.sh\n' > "$CASA/.config/systemd/user/desligada.service"
cat > "$ZD/aurora/fundo.sh" <<'FIM'
#!/bin/sh
cp /tmp/x.png "$HOME/.local/share/backgrounds/x.png"
FIM
printf 'DPkg::Post-Invoke { "%s/.config/zsh/aurora/fundo.sh || true"; };\n' "$CASA" > "$ETC/apt/apt.conf.d/99-vizinho"
cat > "$DESENV/Dracula_OS-Theme/scripts/reparar_hicolor_index.sh" <<'FIM'
#!/usr/bin/env bash
set -euo pipefail
printf '[Icon Theme]\n' > "$HOME/.local/share/icons/hicolor/index.theme"
gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor"
echo "escrevi"
FIM
chmod 755 "$ZD"/aurora/*.sh "$DESENV/Dracula_OS-Theme/scripts/reparar_hicolor_index.sh"
cp -a "$DESENV/Dracula_OS-Theme/scripts/reparar_hicolor_index.sh" "$T/hicolor-original.sh"
cp -a "$ZD/functions/sistema.zsh" "$T/sistema-original.zsh"

rodar() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" ZDOTDIR="$ZD" VIZINHOS_ETC="$ETC" \
      VIZINHOS_DESENV="$DESENV" VIZINHOS_CRONTAB="$T/sem-cron" MEOW_ESTADO="$ESTADO" NO_COLOR=1 \
      VIZINHOS_SBIN="$T/real-sbin" bash "$V" "$@"
}

printf '\n1. o inventário\n'
antes="$(cd "$CASA" && find . -printf '%p %s %T@\n' | sort)"
inv1="$(rodar --inventario)"; rc1=$?
inv2="$(rodar --inventario)"
depois="$(cd "$CASA" && find . -printf '%p %s %T@\n' | sort)"
confere "sai 0" '[ "$rc1" = 0 ]'
confere "duas rodadas iguais" '[ "$inv1" = "$inv2" ]'
confere "não escreve nada na casa" '[ "$antes" = "$depois" ]'
confere "sem rede e sem sudo" '[ ! -s "$T/rede.log" ]'
linha() { printf '%s\n' "$inv1" | grep -F -- "$1"; }
confere "o login do shell alcança o script da função (lançador, ativo)" \
  'linha "menu-doctor.sh" | grep -q "^lançador (.desktop)	~/.config/zsh/aurora/menu-doctor.sh	login do shell (via _cura_menu)	ativo	"'
confere "a função chamada pelo login é ativa e diz quem a chama" \
  'linha "_cura_menu()" | grep -q "^tema do COSMIC	.*	login do shell (via cura_no_login)	ativo	sim$"'
confere "a função à mão diz o alias que a chama" \
  'linha "_reconstruir_caches_icones()" | grep -q "^cache do tema de ícones	.*	à mão (via atualizar_icones)	à mão	sim$"'
confere "a unidade ligada escreve o cursor (ativo), e a desligada aparece como desligada" \
  'linha "cursor.sh" | grep -q "^cursor	.*(desligada.service, desligada); systemd do usuário (vizinho-cursor.service)	ativo	"'
confere "o gancho do apt escreve o papel de parede (ativo)" \
  'linha "fundo.sh" | grep -q "^papel de parede	.*	apt (99-vizinho)	ativo	"'
confere "o repositório vizinho roda à mão" \
  'linha "reparar_hicolor_index.sh" | grep -q "	à mão	à mão	sim$"'
confere "a função com o aviso de desativado sai desativada" \
  'linha "_fix_flatpak_icons()" | grep -q "	desativado	"'
confere "comentário do .zshrc não vira chamada" '! linha "install.sh" | grep -q .'
confere "o rodapé conta as escritas" 'printf "%s\n" "$inv1" | tail -1 | grep -q "^# escritas: [0-9]"'
confere "nenhum caminho da casa de brinquedo cravado na tabela" '! printf "%s\n" "$inv1" | grep -qF "$CASA"'
printf 'export ZDOTDIR="$HOME/.config/zsh"\n' > "$CASA/.zshenv"
inv3="$(env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" VIZINHOS_ETC="$ETC" VIZINHOS_DESENV="$DESENV" \
        VIZINHOS_CRONTAB="$T/sem-cron" MEOW_ESTADO="$ESTADO" NO_COLOR=1 bash "$V" --inventario)"
confere "sem ZDOTDIR no ambiente, o do ~/.zshenv dá a mesma tabela" '[ "$inv3" = "$inv1" ]'

printf '\n2. a linha do doctor\n'
saida="$(rodar --conferir)"; rc=$?
confere "duplicata automática não revisada sai 4" '[ "$rc" = 4 ]'
confere "e diz qual é, sem mandar digitar" 'printf "%s\n" "$saida" | grep -q "duplicata(s) nova(s)" && ! printf "%s\n" "$saida" | grep -qiE "rode|digite|execute"'
rodar --revisado >/dev/null
confere "o revisado guarda o estado de hoje" '[ -s "$ESTADO/vizinhos-revisados.tsv" ]'
rodar --conferir >/dev/null; rc=$?
confere "revisada, a mesma duplicata sai 0" '[ "$rc" = 0 ]'
printf '#!/bin/sh\nsed -i s/a/b/ "$HOME/.config/fastfetch/config.jsonc"\n' > "$ZD/aurora/ff.sh"; chmod 755 "$ZD/aurora/ff.sh"
printf '[Service]\nExecStart=%%h/.config/zsh/aurora/ff.sh\n' > "$CASA/.config/systemd/user/ff.service"
ln -s ../ff.service "$CASA/.config/systemd/user/default.target.wants/ff.service"
saida="$(rodar --conferir)"; rc=$?
confere "uma duplicata nova volta a sair 4, e só ela" '[ "$rc" = 4 ] && printf "%s\n" "$saida" | grep -q "1 duplicata(s) nova(s) com o MeowSystem: fastfetch"'

printf '\n3. desativar e restaurar (saída antecipada)\n'
saida="$(rodar --desativar dracula-hicolor)"; rc=$?
arq="$DESENV/Dracula_OS-Theme/scripts/reparar_hicolor_index.sh"
confere "desativar muda (sai 1)" '[ "$rc" = 1 ]'
confere "a linha nova fica logo abaixo do shebang" '[ "$(sed -n 1p "$arq")" = "#!/usr/bin/env bash" ] && sed -n 2p "$arq" | grep -q "exit 0  #vizinhos+:dracula-hicolor#"'
confere "a cópia de antes existe e é a original" 'cmp -s "$(ls "$ESTADO"/vizinhos/dracula-hicolor/*/reparar_hicolor_index.sh)" "$T/hicolor-original.sh"'
confere "o registro ganha a linha" 'grep -q "	dracula-hicolor	saida	.*	desativado$" "$ESTADO/vizinhos-desativados.tsv"'
saida="$(env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/outra" bash "$arq" 2>&1)"; rc=$?
confere "o script de fora sai 0 sem fazer o resto" '[ "$rc" = 0 ] && [ ! -e "$T/outra" ] && printf "%s" "$saida" | grep -q "MeowSystem" && ! printf "%s" "$saida" | grep -q escrevi'
copias="$(ls "$ESTADO"/vizinhos/dracula-hicolor | wc -l)"
saida="$(rodar --desativar dracula-hicolor)"; rc=$?
confere "desativar de novo não muda nada" '[ "$rc" = 0 ] && [ "$(ls "$ESTADO"/vizinhos/dracula-hicolor | wc -l)" = "$copias" ] && [ "$(grep -c "dracula-hicolor" "$ESTADO/vizinhos-desativados.tsv")" = 1 ]'
confere "o inventário passa a dizer desativado" 'rodar --inventario | grep -F "reparar_hicolor_index.sh" | grep -q "	desativado	"'
confere "o --listar diz desativado" 'rodar --listar | grep -q "^dracula-hicolor	desativado	"'
rodar --restaurar dracula-hicolor >/dev/null
confere "restaurar devolve o arquivo byte a byte" 'cmp -s "$arq" "$T/hicolor-original.sh"'
confere "e o modo de execução" '[ -x "$arq" ]'
confere "o registro diz restaurado" 'tail -1 "$ESTADO/vizinhos-desativados.tsv" | grep -q "	dracula-hicolor	saida	.*	restaurado$"'
confere "item que esta casa não tem não muda nada" 'rodar --desativar dracula-spicetify | grep -q "não existe nesta casa"'
confere "item desconhecido é erro" '! rodar --desativar nao-existe 2>/dev/null'

printf '\n4. desativar e restaurar (trecho comentado, que espera o MeowSystem)\n'
FALSA="$T/meow-velho"; mkdir -p "$FALSA/bin" "$FALSA/scripts"; : > "$FALSA/bin/meow"
printf '#!/bin/sh\necho velho\n' > "$FALSA/scripts/hicolor.sh"
mkdir -p "$ESTADO"; printf '%s\n' "$FALSA" > "$ESTADO/raiz"
saida="$(rodar --desativar caches-icones-casa)"; rc=$?
confere "com o MeowSystem instalado velho, o item espera e nada muda" \
  '[ "$rc" = 0 ] && printf "%s" "$saida" | grep -q "espera" && cmp -s "$ZD/functions/sistema.zsh" "$T/sistema-original.zsh"'
confere "o --listar diz que espera" 'rodar --listar | grep -q "^caches-icones-casa	espera"'
printf '%s\n' "$RAIZ" > "$ESTADO/raiz"
rodar --desativar caches-icones-casa >/dev/null; rc=$?
confere "com o MeowSystem que já cuida, o laço da casa sai comentado" \
  '[ "$rc" = 1 ] && [ "$(grep -c "^#vizinhos:caches-icones-casa# " "$ZD/functions/sistema.zsh")" = 4 ]'
confere "o resto da função fica (o sudo do sistema e o echo)" \
  'grep -q "^    sudo gtk-update-icon-cache" "$ZD/functions/sistema.zsh" && grep -q "^    echo fim" "$ZD/functions/sistema.zsh"'
confere "zsh lê o arquivo sem erro" '! command -v zsh >/dev/null || zsh -n "$ZD/functions/sistema.zsh"'
rodar --desativar dracula-hicolor >/dev/null
rodar --restaurar todos >/dev/null
confere "restaurar todos devolve os dois arquivos byte a byte" \
  'cmp -s "$ZD/functions/sistema.zsh" "$T/sistema-original.zsh" && cmp -s "$arq" "$T/hicolor-original.sh"'

printf '\n5. desativar e restaurar (arquivo movido para a cópia datada)\n'
APPS="$CASA/.local/share/applications"; mkdir -p "$APPS"
COP="$APPS/org.keepassxc.KeePassXC.desktop"
printf '[Desktop Entry]\nType=Application\nName=KeePassXC\nExec=keepassxc\nNoDisplay=true\n' > "$COP"
cp -a "$COP" "$T/copia-original.desktop"
printf '%s\n' "$FALSA" > "$ESTADO/raiz"
saida="$(rodar --desativar dracula-copia-org.keepassxc.KeePassXC)"; rc=$?
confere "sem a sombra do ocultar no MeowSystem instalado, a cópia espera e fica" \
  '[ "$rc" = 0 ] && printf "%s" "$saida" | grep -q "espera" && cmp -s "$COP" "$T/copia-original.desktop"'
printf '%s\n' "$RAIZ" > "$ESTADO/raiz"
rodar --desativar dracula-copia-org.keepassxc.KeePassXC >/dev/null; rc=$?
confere "desativar tira o arquivo do lugar (sai 1)" '[ "$rc" = 1 ] && [ ! -e "$COP" ]'
confere "a cópia datada é o arquivo de antes" \
  'cmp -s "$(ls "$ESTADO"/vizinhos/dracula-copia-org.keepassxc.KeePassXC/*/org.keepassxc.KeePassXC.desktop)" "$T/copia-original.desktop"'
confere "o --listar diz desativado" 'rodar --listar | grep -q "^dracula-copia-org.keepassxc.KeePassXC	desativado	~/.local/share/applications/"'
rodar --desativar dracula-copia-org.keepassxc.KeePassXC >/dev/null; rc=$?
confere "desativar de novo não muda nada" \
  '[ "$rc" = 0 ] && [ "$(grep -c "dracula-copia-org.keepassxc.KeePassXC" "$ESTADO/vizinhos-desativados.tsv")" = 1 ]'
rodar --restaurar dracula-copia-org.keepassxc.KeePassXC >/dev/null; rc=$?
confere "restaurar devolve o arquivo byte a byte" '[ "$rc" = 1 ] && cmp -s "$COP" "$T/copia-original.desktop"'
confere "o registro diz restaurado" 'tail -1 "$ESTADO/vizinhos-desativados.tsv" | grep -q "	dracula-copia-org.keepassxc.KeePassXC	mover	.*	restaurado$"'
rodar --desativar dracula-copia-org.keepassxc.KeePassXC >/dev/null
printf '[Desktop Entry]\nName=Outro\n' > "$COP"
saida="$(rodar --restaurar todos 2>&1)"
confere "o arquivo voltou a existir: o restaurar não o sobrescreve e a cópia fica" \
  'grep -qx "Name=Outro" "$COP" && printf "%s" "$saida" | grep -q "voltou a existir" && ls "$ESTADO"/vizinhos/dracula-copia-org.keepassxc.KeePassXC/*/org.keepassxc.KeePassXC.desktop >/dev/null'
rm -f "$COP"

printf '\n6. a cache do hicolor da casa (o que o MeowSystem passa a cuidar)\n'
H="$CASA/.local/share/icons/hicolor"
printf '<svg/>' > "$H/48x48/apps/a.svg"
printf '#!/bin/sh\nfor a; do d="$a"; done; : > "$d/icon-theme.cache"; echo "$*" >> "%s/gtk.log"\n' "$T" > "$T/bin/gtk-update-icon-cache"
chmod 755 "$T/bin/gtk-update-icon-cache"
hc() { env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$ESTADO" NO_COLOR=1 "$@" bash "$RAIZ/scripts/hicolor.sh"; }
hc >/dev/null 2>&1
: > "$H/icon-theme.cache"; touch -d '2 days ago' "$H/icon-theme.cache"; touch "$H/48x48/apps/a.svg"
: > "$T/gtk.log"
saida="$(hc MEOW_DRY_RUN=1 2>&1)"; rc=$?
confere "o ensaio vê a cache velha e não reindexa" '[ "$rc" = 1 ] && printf "%s" "$saida" | grep -q "reindexaria" && [ ! -s "$T/gtk.log" ]'
saida="$(hc 2>&1)"; rc=$?
confere "o conserto reindexa" '[ "$rc" = 1 ] && [ -s "$T/gtk.log" ]'
saida="$(hc 2>&1)"; rc=$?
confere "a segunda passada não escreve" '[ "$rc" = 0 ] && printf "%s" "$saida" | grep -q "já declara"'

printf '\n7. o bloco do terminal no .zshrc que o vizinho guarda\n'
C2="$T/casa2"; Z2="$C2/.config/zsh"
mkdir -p "$Z2" "$C2/.config/meow"
printf 'export ZDOTDIR="$HOME/.config/zsh"\n' > "$C2/.zshenv"
printf 'alias x=y\n' > "$Z2/.zshrc"; printf 'export A=1\n' > "$Z2/env.zsh"
printf '$HOME/.config/zsh   # o Spellbook\n' > "$C2/.config/meow/vizinhos.conf"
tb() { env -i PATH="$T/bin:/usr/bin:/bin" HOME="$C2" SHELL=/bin/zsh MEOW_ESTADO="$C2/.local/state/meowsystem" NO_COLOR=1 \
         bash "$RAIZ/scripts/terminal_bloco.sh" "$@"; }
pode() { env -i PATH=/usr/bin:/bin HOME="$C2" bash -c '. "$1/lib/comum.sh" >/dev/null 2>&1; meow_destino_permitido "$2" 2>/dev/null' _ "$RAIZ" "$1"; }
confere "sem a exceção, o .zshrc do vizinho é recusado" '! pode "$Z2/.zshrc"'
tb >/dev/null 2>&1; rc=$?
confere "o bloco entra no .zshrc do ZDOTDIR, abaixo do que já estava" \
  '[ "$rc" = 1 ] && [ "$(head -n1 "$Z2/.zshrc")" = "alias x=y" ] && grep -qxF "# >>> MeowSystem — o meow põe e tira este bloco >>>" "$Z2/.zshrc"'
confere "o vizinhos.conf ganha a exceção daquele arquivo, com \$HOME escrito" \
  'grep -qxF "!\$HOME/.config/zsh/.zshrc" "$C2/.config/meow/vizinhos.conf" && grep -qxF "\$HOME/.config/zsh   # o Spellbook" "$C2/.config/meow/vizinhos.conf"'
confere "o resto da pasta segue do vizinho" 'pode "$Z2/.zshrc" && ! pode "$Z2/env.zsh" && ! pode "$Z2/outro.zsh" && [ "$(cat "$Z2/env.zsh")" = "export A=1" ]'
antes="$(md5sum "$Z2/.zshrc" "$C2/.config/meow/vizinhos.conf")"
tb >/dev/null 2>&1; rc=$?
confere "a segunda passada não escreve" '[ "$rc" = 0 ] && [ "$antes" = "$(md5sum "$Z2/.zshrc" "$C2/.config/meow/vizinhos.conf")" ]'
tb remover >/dev/null 2>&1
confere "remover tira o bloco do .zshrc do vizinho" '[ "$(cat "$Z2/.zshrc")" = "alias x=y" ]'
printf '$HOME/.config/zsh/.zshrc\n' > "$C2/.config/meow/vizinhos.conf"; cp "$Z2/.zshrc" "$T/zshrc-antes"
tb >/dev/null 2>&1
confere "o .zshrc guardado pelo nome, e não pela pasta, fica intocado e sem exceção" \
  'cmp -s "$Z2/.zshrc" "$T/zshrc-antes" && ! grep -q "^!" "$C2/.config/meow/vizinhos.conf"'
C3="$T/casa3"; mkdir -p "$C3"; printf 'alias y=z\n' > "$C3/.bashrc"
env -i PATH="$T/bin:/usr/bin:/bin" HOME="$C3" SHELL=/bin/bash MEOW_ESTADO="$C3/estado" NO_COLOR=1 \
  bash "$RAIZ/scripts/terminal_bloco.sh" >/dev/null 2>&1
confere "no PC sem Spellbook, o bloco vai ao .bashrc de sempre, sem vizinhos.conf" \
  'grep -q "^# >>> MeowSystem" "$C3/.bashrc" && [ ! -e "$C3/.config/meow/vizinhos.conf" ]'

printf '\n8. o compositor da Aurora: só o bloco do --ensure e o do night-light saem, e só com o shim usando o build da casa\n'
mkdir -p "$ZD/scripts"
SH="$ZD/scripts/ritual-aurora-self-heal.sh"
cat > "$SH" <<'FIM'
#!/bin/bash
SRC="$USER_HOME/.config/zsh/scripts"
install_if_diff "$SRC/ritual-aurora-self-heal.sh"          /usr/local/sbin/ritual-aurora-self-heal.sh             755 none
if [ -x /usr/local/sbin/aurora-other.sh ]; then
  echo outro
fi
if [ -x /usr/local/sbin/aurora-cosmic-comp-ws.sh ]; then
  env HOME="$USER_HOME" AURORA_USER="$USER_NAME" \
    /usr/local/sbin/aurora-cosmic-comp-ws.sh --ensure 2>&1 || err "cosmic-comp-ws falhou"
fi

if [ -x /usr/local/bin/aurora-night-light.py ] && [ -f /usr/bin/cosmic-comp ]; then
  nl_out="$(/usr/local/bin/aurora-night-light.py 2>&1)"; nl_rc=$?
  case "$nl_rc" in
    0) if echo "$nl_out" | grep -q aplicado; then
         echo ok
       fi ;;
  esac
fi
echo depois
FIM
cp -a "$SH" "$T/self-heal-original.sh"
saida="$(rodar --desativar aurora-compositor)"; rc=$?
confere "sem o shim em ~/.local/bin, o requer impede o corte" \
  '[ "$rc" = 0 ] && printf "%s" "$saida" | grep -q "espera" && cmp -s "$SH" "$T/self-heal-original.sh"'
confere "o --listar diz que o compositor espera" 'rodar --listar | grep -q "^aurora-compositor	espera"'
mkdir -p "$CASA/.local/bin"; cp "$RAIZ/scripts/compositor_shim.sh" "$CASA/.local/bin/cosmic-comp"
printf '#!/bin/sh\nprintf 1.0-toy\n' > "$T/bin/dpkg-query"; chmod 755 "$T/bin/dpkg-query"
saida="$(rodar --desativar aurora-compositor)"; rc=$?
confere "com o shim e sem o build da versão instalada, o corte espera" \
  '[ "$rc" = 0 ] && printf "%s" "$saida" | grep -q "espera" && cmp -s "$SH" "$T/self-heal-original.sh"'
BUILD="$CASA/.local/libexec/meow/cosmic-comp/1.0-toy"
mkdir -p "$BUILD"; printf '#!/bin/sh\n' > "$BUILD/cosmic-comp"; chmod 755 "$BUILD/cosmic-comp"
printf 'req cosmic-comp-modo-leitura.patch abc presente\n' > "$BUILD/estado"; touch "$BUILD/ruim"
rodar --desativar aurora-compositor >/dev/null; rc=$?
confere "com o build marcado ruim, o shim usaria o de fábrica e o corte espera" \
  '[ "$rc" = 0 ] && cmp -s "$SH" "$T/self-heal-original.sh"'
rm -f "$BUILD/ruim"
rodar --desativar aurora-compositor >/dev/null; rc=$?
confere "com o shim usando o build válido, as quatro linhas do --ensure saem comentadas" \
  '[ "$rc" = 1 ] && [ "$(grep -c "^#vizinhos:aurora-compositor# " "$SH")" = 4 ] && grep -q "^#vizinhos:aurora-compositor# fi$" "$SH"'
confere "e só elas: o outro bloco, o night-light e o resto ficam" \
  '[ "$(diff "$T/self-heal-original.sh" "$SH" | grep -c "^>")" = 4 ] && grep -q "^  echo outro" "$SH" && grep -q "^echo depois" "$SH"'
rodar --desativar aurora-night-light >/dev/null; rc=$?
confere "o night-light sai até o seu fi, com o case e o fi de dentro" \
  '[ "$rc" = 1 ] && [ "$(grep -c "^#vizinhos:aurora-night-light# " "$SH")" = 8 ] && grep -q "^echo depois" "$SH"'
confere "bash lê o self-heal sem erro" 'bash -n "$SH"'
confere "o self-heal se reinstala do \$ZD/scripts, então o corte chega ao /usr/local/sbin" \
  'grep -q "^install_if_diff \"\$SRC/ritual-aurora-self-heal.sh\" *  */usr/local/sbin/ritual-aurora-self-heal.sh" "$SH"'
saida="$(rodar --desativar aurora-compositor)"; rc=$?
confere "a segunda passada não escreve" '[ "$rc" = 0 ] && [ "$(grep -c "^#vizinhos:aurora-compositor# " "$SH")" = 4 ]'
rodar --restaurar aurora-compositor >/dev/null
rodar --restaurar aurora-night-light >/dev/null
confere "--restaurar devolve o self-heal byte a byte" 'cmp -s "$SH" "$T/self-heal-original.sh"'

doutor() {
  local f="$1"; shift
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" ZDOTDIR="$ZD" VIZINHOS_ETC="$ETC" \
      VIZINHOS_DESENV="$DESENV" VIZINHOS_CRONTAB="$T/sem-cron" MEOW_ESTADO="$ESTADO" NO_COLOR=1 \
      MEOW_RAIZ="$RAIZ" XDG_CONFIG_HOME="$CASA/.config" XDG_STATE_HOME="$CASA/.local/state" \
      VIZINHOS_SBIN="$T/real-sbin" "$@" \
      bash -c 'source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/bin/meow"); "$0"' "$f" 2>&1
}
retrato() { (cd "$1" && find . -path ./.local/state -prune -o -printf '%p %s %T@\n' | sort); }

printf '\n9. as cópias reais da Aurora: o doctor corta o que está pronto, uma vez só\n'
REAL="${SUITE_CASA_REAL:-$HOME}/.config/zsh"
if [ -f "$REAL/scripts/ritual-aurora-self-heal.sh" ] && [ -f "$REAL/install.sh" ] && [ -f "$REAL/env.zsh" ] \
   && [ -f "$REAL/scripts/aurora-qbittorrent-config.sh" ]; then
  CASA="$T/real"; ZD="$CASA/.config/zsh"; ESTADO="$CASA/.local/state/meowsystem"
  UD="$CASA/.config/systemd/user"
  mkdir -p "$ZD/scripts" "$ZD/functions" "$ESTADO" "$T/real-sbin" "$UD/timers.target.wants" "$UD/default.target.wants"
  cp "$REAL/scripts/ritual-aurora-self-heal.sh" "$REAL/scripts/spicetify-setup.sh" "$REAL/scripts/aurora-qbittorrent-config.sh" "$ZD/scripts/"
  cp "$REAL/scripts/ritual-aurora-self-heal.sh" "$T/real-sbin/"
  UNIDADES="aurora-painel-fantasma.timer aurora-vidro-maximizado.path aurora-cosmic-nightlight-watch.timer"
  for u in $UNIDADES; do
    case "$u" in
      *.timer) printf '[Timer]\nOnCalendar=daily\n' > "$UD/$u"; ln -s "../$u" "$UD/timers.target.wants/$u" ;;
      *.path)  printf '[Path]\nPathChanged=%%h/x\n' > "$UD/$u"; ln -s "../$u" "$UD/default.target.wants/$u" ;;
    esac
    printf '[Service]\nExecStart=/bin/true\n' > "$UD/${u%.*}.service"
  done
  cp -a "$UD" "$T/real-uni-original"
  printf '#!/bin/sh\necho "systemctl $*" >> "%s/systemctl-real.log"\nexit 0\n' "$T" > "$T/bin/systemctl"; chmod 755 "$T/bin/systemctl"
  cp "$REAL/install.sh" "$REAL/env.zsh" "$ZD/"
  cp "$REAL/functions/sistema.zsh" "$ZD/functions/"
  find "$ZD" "$T/real-sbin" -type f -exec sed -i -e '/#vizinhos+:[a-z0-9-]*#/d' -e 's/^#vizinhos:[a-z0-9-]*# //' {} +
  cp -a "$ZD" "$T/real-original"
  NOVOS="aurora-fastfetch-link aurora-fastfetch-passo aurora-completion-meow aurora-icone-applib aurora-stubs-ocultar aurora-gato-pop aurora-spicetify-instalar"
  NOVOS="$NOVOS aurora-painel-fantasma-instalar aurora-painel-fantasma-ligar aurora-painel-fantasma-passo"
  NOVOS="$NOVOS aurora-vidro-instalar aurora-vidro-reconciliar aurora-vidro-passo aurora-leitura-vigia-instalar"
  NOVOS="$NOVOS aurora-alfinetes aurora-alfinetes-passo aurora-qbittorrent-wings"
  UNIDADE_ITENS="aurora-painel-fantasma-unidade aurora-vidro-unidade aurora-leitura-vigia-unidade"
  COMPOSITOR="aurora-compositor aurora-night-light aurora-compositor-instalar aurora-compositor-serie aurora-night-light-instalar aurora-compositor-passo aurora-night-light-passo"
  ANTIGOS="caches-icones-casa spellbook-terminal-fastfetch spellbook-terminal-starship spellbook-terminal-fzf"

  antes="$(retrato "$CASA")"
  doutor chk_vizinhos VIZINHOS_DESATIVAR=nao >/dev/null; rc=$?
  confere "com VIZINHOS_DESATIVAR=nao, o doctor não pede conserto" '[ "$rc" != 1 ]'
  doutor fix_vizinhos VIZINHOS_DESATIVAR=nao >/dev/null
  confere "e nada é cortado" '[ "$antes" = "$(retrato "$CASA")" ]'

  saida="$(doutor chk_vizinhos)"; rc=$?
  confere "com item pronto, chk_vizinhos dá 1" '[ "$rc" = 1 ] && printf "%s" "$saida" | grep -q aurora-gato-pop'
  confere "e o ensaio não escreve" '[ "$antes" = "$(retrato "$CASA")" ]'
  doutor fix_vizinhos MEOW_DRY_RUN=1 >/dev/null
  confere "o fix_vizinhos em seco também não" '[ "$antes" = "$(retrato "$CASA")" ]'
  doutor fix_vizinhos >/dev/null
  todos=1
  for i in $NOVOS $ANTIGOS; do
    case "$i" in
      aurora-spicetify-instalar) grep -qF "#vizinhos+:$i#" "$ZD/scripts/spicetify-setup.sh" || { todos=0; printf '       não cortou %s\n' "$i"; } ;;
      *) grep -rqF "#vizinhos:$i# " "$ZD" || { todos=0; printf '       não cortou %s\n' "$i"; } ;;
    esac
  done
  confere "os $(printf '%s\n' $NOVOS | grep -c .) itens novos e os quatro antigos cortam nas cópias reais" '[ "$todos" = 1 ]'
  esperam=1
  for i in $COMPOSITOR; do grep -rqF "#vizinhos:$i# " "$ZD" && { esperam=0; printf '       cortou %s sem o build\n' "$i"; }; done
  confere "os sete trechos do compositor e do night-light esperam o build, sem corte" '[ "$esperam" = 1 ]'
  confere "as três unidades esperam a Aurora ler o corte" \
    '[ ! -e "$T/systemctl-real.log" ] && for u in $UNIDADES; do [ -f "$UD/$u" ] || exit 1; done'
  confere "o self-heal cortado passa bash -n" 'bash -n "$ZD/scripts/ritual-aurora-self-heal.sh"'
  confere "o install.sh cortado passa bash -n" 'bash -n "$ZD/install.sh"'
  confere "o script do qBittorrent cortado passa bash -n" 'bash -n "$ZD/scripts/aurora-qbittorrent-config.sh"'
  confere "o vigia do painel sai inteiro do self-heal: nenhuma linha viva cita o aurora-painel-fantasma" \
    '! grep -v "^#vizinhos:" "$ZD/scripts/ritual-aurora-self-heal.sh" | grep -qE "aurora-painel-fantasma[.](timer|sh)"'
  if command -v zsh >/dev/null 2>&1; then
    confere "o env.zsh cortado passa zsh -n" 'zsh -n "$ZD/env.zsh"'
    confere "o sistema.zsh cortado passa zsh -n" 'zsh -n "$ZD/functions/sistema.zsh"'
  else
    printf '  info  sem zsh nesta máquina: o zsh -n do env.zsh fica para a máquina com zsh\n'
  fi
  confere "o passo do fastfetch no install.sh sai numa linha só" \
    '[ "$(grep -c "^#vizinhos:aurora-fastfetch-passo# " "$ZD/install.sh")" = 1 ]'
  confere "o self-heal já não cria o symlink do fastfetch" \
    '! grep -v "^#vizinhos:" "$ZD/scripts/ritual-aurora-self-heal.sh" | grep -q "criando symlink ~/.config/fastfetch"'

  depois="$(retrato "$CASA")"
  doutor chk_vizinhos >/dev/null; rc=$?
  confere "na segunda passada, chk_vizinhos dá 0 ou 4" '[ "$rc" = 0 ] || [ "$rc" = 4 ]'
  confere "e nenhum mtime muda" '[ "$depois" = "$(retrato "$CASA")" ]'
  doutor fix_vizinhos >/dev/null
  confere "nem com o fix rodado de novo" '[ "$depois" = "$(retrato "$CASA")" ]'

  cp "$ZD/scripts/ritual-aurora-self-heal.sh" "$T/real-sbin/ritual-aurora-self-heal.sh"
  doutor fix_vizinhos >/dev/null
  movidas=1
  for i in $UNIDADE_ITENS; do
    case "$i" in
      aurora-painel-fantasma-unidade) u=aurora-painel-fantasma.timer ;;
      aurora-vidro-unidade) u=aurora-vidro-maximizado.path ;;
      aurora-leitura-vigia-unidade) u=aurora-cosmic-nightlight-watch.timer ;;
    esac
    { [ ! -e "$UD/$u" ] && [ ! -e "$UD/${u%.*}.service" ] && [ ! -L "$UD/timers.target.wants/$u" ] && [ ! -L "$UD/default.target.wants/$u" ] \
      && ls "$ESTADO/vizinhos/$i"/*/"$u" "$ESTADO/vizinhos/$i"/*/"${u%.*}.service" >/dev/null 2>&1 \
      && grep -qx "systemctl --user disable --now $u" "$T/systemctl-real.log"; } || { movidas=0; printf '       %s ficou\n' "$u"; }
  done
  confere "com o self-heal instalado já cortado, as três unidades saem desligadas, com o .service e o link" '[ "$movidas" = 1 ]'
  depois="$(retrato "$CASA")"; : > "$T/systemctl-real.log"
  doutor fix_vizinhos >/dev/null
  confere "e a passada seguinte não chama o systemd nem escreve" '[ ! -s "$T/systemctl-real.log" ] && [ "$depois" = "$(retrato "$CASA")" ]'

  rodar --restaurar aurora-gato-pop >/dev/null
  confere "o --restaurar devolve o trecho do gato" '! grep -qF "#vizinhos:aurora-gato-pop# " "$ZD/scripts/ritual-aurora-self-heal.sh"'
  doutor chk_vizinhos >/dev/null; rc=$?
  confere "o que ela devolveu não conta como pronto" '[ "$rc" != 1 ] && ! rodar --prontos | grep -q aurora-gato-pop'
  doutor fix_vizinhos >/dev/null
  confere "e continua ativo depois do conserto" '! grep -qF "#vizinhos:aurora-gato-pop# " "$ZD/scripts/ritual-aurora-self-heal.sh"'
  confere "o --listar diz que foi ela" 'rodar --listar | grep -q "^aurora-gato-pop	ativo, devolvido por você"'
  rodar --desativar aurora-gato-pop >/dev/null
  confere "o --desativar dito à mão ainda corta" 'grep -qF "#vizinhos:aurora-gato-pop# " "$ZD/scripts/ritual-aurora-self-heal.sh"'
  for i in $NOVOS $ANTIGOS $UNIDADE_ITENS; do rodar --restaurar "$i" >/dev/null; done
  confere "restaurados todos, as cópias voltam byte a byte" 'diff -r "$T/real-original" "$ZD" >/dev/null'
  confere "e as três unidades e os .service voltam byte a byte, religadas" \
    'for u in $UNIDADES; do cmp -s "$UD/$u" "$T/real-uni-original/$u" && cmp -s "$UD/${u%.*}.service" "$T/real-uni-original/${u%.*}.service" && grep -qx "systemctl --user enable --now $u" "$T/systemctl-real.log" || exit 1; done'
  rm -f "$T/bin/systemctl"
else
  printf '  info  sem o ~/.config/zsh da Aurora nesta máquina: as cópias reais ficam para a máquina dela; os blocos 10 a 14 cobrem o corte com arquivos de brinquedo\n'
fi

CASA="$T/brinquedo"; ZD="$CASA/.config/zsh"; ESTADO="$CASA/.local/state/meowsystem"
mkdir -p "$ZD/scripts" "$ESTADO" "$CASA/.config/systemd/user/timers.target.wants" "$T/sbin"
CT="$T/contrato.tsv"
printf 'item\ttoy-passo\tbloco\t$ZD/install.sh\t        _step_vidro_fosco\t-\t-\tmotivo de brinquedo\n' > "$CT"
printf 'item\ttoy-repetido\tbloco\t$ZD/scripts/repetido.sh\tfaz_isto\t-\t-\tmotivo de brinquedo\n' >> "$CT"
printf 'item\ttoy-sintaxe\tbloco\t$ZD/scripts/sintaxe.sh\tif [ -f /x ]; then\t^  echo x$\t-\tmotivo de brinquedo\n' >> "$CT"
printf 'item\ttoy-sem-fim\tbloco\t$ZD/scripts/sintaxe.sh\tif [ -f /y ]; then\t^nunca$\t-\tmotivo de brinquedo\n' >> "$CT"
printf 'item\ttoy-instalar\tbloco\t$ZD/scripts/self-heal.sh\tinstall_user_if_diff "$SRC/toy.timer"\ttoy[.]service\t-\tmotivo de brinquedo\n' >> "$CT"
printf 'item\ttoy-unidade\tunidade\t$UNI/toy.timer\ttoy-instalar\t$SBIN/self-heal.sh\t-\tmotivo de brinquedo\n' >> "$CT"
rodar() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" ZDOTDIR="$ZD" VIZINHOS_ETC="$ETC" \
      VIZINHOS_DESENV="$DESENV" VIZINHOS_CRONTAB="$T/sem-cron" MEOW_ESTADO="$ESTADO" NO_COLOR=1 \
      VIZINHOS_CONTRATO="$CT" VIZINHOS_SBIN="$T/sbin" bash "$V" "$@"
}

printf '\n10. fim - corta uma linha só, e o --restaurar a devolve byte a byte\n'
cat > "$ZD/install.sh" <<'FIM'
#!/bin/bash
STEPS=(
        _step_night_light
        _step_vidro_fosco
        _step_painel_fantasma
)
for s in "${STEPS[@]}"; do "$s"; done
FIM
cp "$ZD/install.sh" "$T/install-original.sh"
rodar --desativar toy-passo >/dev/null; rc=$?
confere "a linha do vidro sai comentada" \
  '[ "$rc" = 1 ] && grep -qxF "#vizinhos:toy-passo#         _step_vidro_fosco" "$ZD/install.sh"'
confere "e só ela" '[ "$(diff "$T/install-original.sh" "$ZD/install.sh" | grep -c "^>")" = 1 ]'
confere "o install.sh cortado passa bash -n" 'bash -n "$ZD/install.sh"'
rodar --restaurar toy-passo >/dev/null
confere "--restaurar devolve byte a byte" 'cmp -s "$ZD/install.sh" "$T/install-original.sh"'

printf '\n11. um início que aparece duas vezes não é cortado\n'
printf '#!/bin/bash\nfaz_isto\necho a\nfaz_isto\n' > "$ZD/scripts/repetido.sh"
md5a="$(md5sum < "$ZD/scripts/repetido.sh")"
saida="$(rodar --desativar toy-repetido 2>&1)"; rc=$?
confere "o corte é recusado" '[ "$rc" = 2 ] && printf "%s" "$saida" | grep -q "não é único"'
confere "e o arquivo fica com o mesmo md5" '[ "$md5a" = "$(md5sum < "$ZD/scripts/repetido.sh")" ]'
confere "o --listar diz que o trecho repete" 'rodar --listar | grep -q "^toy-repetido	o trecho não é único"'
confere "o --prontos não o conta entre os prontos" '! rodar --prontos | grep "repetem o que" | grep -q toy-repetido'

printf '\n12. um corte que quebraria a leitura do arquivo é recusado\n'
cat > "$ZD/scripts/sintaxe.sh" <<'FIM'
#!/bin/bash
if [ -f /x ]; then
  echo x
  echo y
fi
if [ -f /y ]; then
  echo z
fi
FIM
md5a="$(md5sum < "$ZD/scripts/sintaxe.sh")"
saida="$(rodar --desativar toy-sintaxe 2>&1)"; rc=$?
confere "o corte até o meio do if é recusado" '[ "$rc" = 2 ] && printf "%s" "$saida" | grep -q "quebraria a leitura"'
confere "e o arquivo fica igual" '[ "$md5a" = "$(md5sum < "$ZD/scripts/sintaxe.sh")" ]'
saida="$(rodar --desativar toy-sem-fim 2>&1)"; rc=$?
confere "um fim que não aparece também é recusado, sem mudar nada" \
  '[ "$rc" = 2 ] && printf "%s" "$saida" | grep -q "fim do trecho não aparece" && [ "$md5a" = "$(md5sum < "$ZD/scripts/sintaxe.sh")" ]'
confere "e nenhuma cópia fica para trás" '[ ! -d "$ESTADO/vizinhos/toy-sintaxe" ] && [ ! -d "$ESTADO/vizinhos/toy-sem-fim" ]'

printf '\n13. a unidade só sai depois que a Aurora leu o corte da instalação\n'
printf '#!/bin/sh\necho "systemctl $*" >> "%s/systemctl.log"\nexit 0\n' "$T" > "$T/bin/systemctl"; chmod 755 "$T/bin/systemctl"
UD="$CASA/.config/systemd/user"
printf '[Timer]\nOnCalendar=hourly\n' > "$UD/toy.timer"
printf '[Service]\nExecStart=/bin/true\n' > "$UD/toy.service"
ln -s ../toy.timer "$UD/timers.target.wants/toy.timer"
cp "$UD/toy.timer" "$T/toy.timer.original"; cp "$UD/toy.service" "$T/toy.service.original"
cat > "$ZD/scripts/self-heal.sh" <<'FIM'
#!/bin/bash
SRC=/x
install_user_if_diff "$SRC/toy.timer"
install_user_if_diff "$SRC/toy.service"
echo depois
FIM
cp "$ZD/scripts/self-heal.sh" "$T/sbin/self-heal.sh"
saida="$(rodar --desativar toy-unidade)"; rc=$?
confere "sem a marca no instalado, espera e dá 0" \
  '[ "$rc" = 0 ] && printf "%s" "$saida" | grep -q "esperando a Aurora" && [ -f "$UD/toy.timer" ] && [ ! -e "$T/systemctl.log" ]'
confere "o --listar diz que espera a Aurora" 'rodar --listar | grep -q "^toy-unidade	esperando a Aurora ler o corte"'
rodar --desativar toy-instalar >/dev/null
confere "o corte da instalação entra na cópia do ZDOTDIR" 'grep -qF "#vizinhos:toy-instalar# " "$ZD/scripts/self-heal.sh"'
saida="$(rodar --desativar toy-unidade)"; rc=$?
confere "enquanto o instalado não tem a marca, a unidade fica" '[ "$rc" = 0 ] && [ -f "$UD/toy.timer" ]'
cp "$ZD/scripts/self-heal.sh" "$T/sbin/self-heal.sh"
rodar --desativar toy-unidade >/dev/null; rc=$?
confere "com a marca, chama systemctl --user disable --now" '[ "$rc" = 1 ] && grep -qx "systemctl --user disable --now toy.timer" "$T/systemctl.log"'
confere "e move o .timer e o .service para a cópia" \
  '[ ! -e "$UD/toy.timer" ] && [ ! -e "$UD/toy.service" ] && ls "$ESTADO"/vizinhos/toy-unidade/*/toy.timer "$ESTADO"/vizinhos/toy-unidade/*/toy.service >/dev/null 2>&1'
confere "o link do timers.target.wants sai junto" '[ ! -L "$UD/timers.target.wants/toy.timer" ]'
: > "$T/systemctl.log"
rodar --desativar toy-unidade >/dev/null; rc=$?
confere "a segunda passada não chama o systemd" '[ "$rc" = 0 ] && [ ! -s "$T/systemctl.log" ]'
rodar --restaurar toy-unidade >/dev/null
confere "--restaurar devolve os dois byte a byte" \
  'cmp -s "$UD/toy.timer" "$T/toy.timer.original" && cmp -s "$UD/toy.service" "$T/toy.service.original"'
confere "e chama enable --now" 'grep -qx "systemctl --user enable --now toy.timer" "$T/systemctl.log"'
rm -f "$T/bin/systemctl"

printf '\n14. o link do fastfetch que sobrou da briga\n'
CASA="$T/ff"; ZD="$CASA/.config/zsh"; FF="$CASA/.config/fastfetch"
mkdir -p "$ZD/fastfetch" "$FF"
printf '{}\n' > "$FF/config.jsonc"; : > "$ZD/.zshrc"
ln -s "$ZD/fastfetch" "$FF/fastfetch"
ffl() {
  env -i PATH="/usr/bin:/bin" HOME="$CASA" NO_COLOR=1 XDG_CONFIG_HOME="$CASA/.config" \
      XDG_STATE_HOME="$CASA/.local/state" FASTFETCH_LOGO_CONF=sim "$@" \
      bash -c 'source "$0/lib/comum.sh"; source <(sed -n "/^_ffl_link_da_briga() {/,/^}/p;/^_ffl_assumir_diretorio() {/,/^}/p" "$0/scripts/fastfetch_logo.sh"); FFL_CONF_DIR="$HOME/.config/fastfetch"; _ffl_assumir_diretorio' "$RAIZ" 2>&1
}
ffl MEOW_DRY_RUN=1 >/dev/null; rc=$?
confere "o ensaio vê o link e não apaga" '[ "$rc" = 1 ] && [ -L "$FF/fastfetch" ]'
saida="$(ffl)"; rc=$?
confere "o conserto apaga o link, em voz alta" '[ "$rc" = 1 ] && [ ! -e "$FF/fastfetch" ] && [ ! -L "$FF/fastfetch" ] && printf "%s" "$saida" | grep -q "apaguei o link"'
confere "e não mexe em mais nada" '[ -f "$FF/config.jsonc" ] && [ -d "$ZD/fastfetch" ] && [ "$(ls -A "$FF")" = config.jsonc ]'
antes="$(retrato "$CASA")"
ffl >/dev/null; rc=$?
confere "a segunda passada não escreve" '[ "$rc" = 0 ] && [ "$antes" = "$(retrato "$CASA")" ]'
ln -s /outro/lugar "$FF/fastfetch"
ffl >/dev/null; rc=$?
confere "um link que não vai ao ZDOTDIR fica" '[ "$rc" = 0 ] && [ -L "$FF/fastfetch" ]'

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'vizinhos: tudo verde\n'; exit 0; fi
printf 'vizinhos: %s falha(s)\n' "$falhas"; exit 1

#!/usr/bin/env bash
# vizinhos.sh — o inventário de quem mais escreve onde o MeowSystem escreve, e o
# desligar com volta, numa casa de brinquedo.
#
# A casa tem um zsh com função que roda no login, uma unidade do systemd ligada,
# um gancho do apt, um repositório "Dracula_OS-Theme" de brinquedo e um script
# com o aviso de desativado. `curl`, `wget` e `sudo` falsos registram e recusam.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
V="$RAIZ/scripts/vizinhos.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }
# Sem pipefail na conferência: o `grep -q` fecha o cano no primeiro acerto.
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1"; fi; }

CASA="$T/casa"; ETC="$T/etc"; ZD="$CASA/.config/zsh"; DESENV="$CASA/Desenvolvimento"
ESTADO="$CASA/.local/state/meowsystem"
mkdir -p "$T/bin" "$ZD/functions" "$ZD/aurora" "$CASA/.config/systemd/user/default.target.wants" \
         "$ETC/apt/apt.conf.d" "$ETC/systemd/system" "$DESENV/Dracula_OS-Theme/scripts" "$CASA/.local/share/icons/hicolor/48x48/apps"
for c in curl wget sudo; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/rede.log"\nexit 1\n' "$c" "$T" > "$T/bin/$c"; chmod 755 "$T/bin/$c"
done

# O zsh: o .zshrc chama uma função que chama outra, e esta roda um script que
# escreve no lançador. Uma função à mão refaz a cache dos ícones da casa, e outra
# tem o aviso de desativado acima do return.
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
# A unidade do usuário, ligada, que escreve o cursor.
cat > "$ZD/aurora/cursor.sh" <<'FIM'
#!/bin/sh
gsettings set org.gnome.desktop.interface cursor-theme Outro
FIM
printf '[Service]\nExecStart=%%h/.config/zsh/aurora/cursor.sh\n' > "$CASA/.config/systemd/user/vizinho-cursor.service"
ln -s ../vizinho-cursor.service "$CASA/.config/systemd/user/default.target.wants/vizinho-cursor.service"
# Uma unidade desligada não é "ativa".
printf '[Service]\nExecStart=%%h/.config/zsh/aurora/cursor.sh\n' > "$CASA/.config/systemd/user/desligada.service"
# O gancho do apt que refaz o papel de parede.
cat > "$ZD/aurora/fundo.sh" <<'FIM'
#!/bin/sh
cp /tmp/x.png "$HOME/.local/share/backgrounds/x.png"
FIM
printf 'DPkg::Post-Invoke { "%s/.config/zsh/aurora/fundo.sh || true"; };\n' "$CASA" > "$ETC/apt/apt.conf.d/99-vizinho"
# O repositório de brinquedo, que roda à mão.
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

rodar() { # o vizinhos.sh dentro da casa de brinquedo
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" ZDOTDIR="$ZD" VIZINHOS_ETC="$ETC" \
      VIZINHOS_DESENV="$DESENV" VIZINHOS_CRONTAB="$T/sem-cron" MEOW_ESTADO="$ESTADO" NO_COLOR=1 \
      bash "$V" "$@"
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
# Sem ZDOTDIR no ambiente (o timer do doctor), ele vem do ~/.zshenv, como o zsh faz.
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

printf '\n5. a cache do hicolor da casa (o que o MeowSystem passa a cuidar)\n'
H="$CASA/.local/share/icons/hicolor"
printf '<svg/>' > "$H/48x48/apps/a.svg"
printf '#!/bin/sh\nfor a; do d="$a"; done; : > "$d/icon-theme.cache"; echo "$*" >> "%s/gtk.log"\n' "$T" > "$T/bin/gtk-update-icon-cache"
chmod 755 "$T/bin/gtk-update-icon-cache"
hc() { env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$ESTADO" NO_COLOR=1 "$@" bash "$RAIZ/scripts/hicolor.sh"; }
hc >/dev/null 2>&1   # escreve o índice
: > "$H/icon-theme.cache"; touch -d '2 days ago' "$H/icon-theme.cache"; touch "$H/48x48/apps/a.svg"
: > "$T/gtk.log"
saida="$(hc MEOW_DRY_RUN=1 2>&1)"; rc=$?
confere "o ensaio vê a cache velha e não reindexa" '[ "$rc" = 1 ] && printf "%s" "$saida" | grep -q "reindexaria" && [ ! -s "$T/gtk.log" ]'
saida="$(hc 2>&1)"; rc=$?
confere "o conserto reindexa" '[ "$rc" = 1 ] && [ -s "$T/gtk.log" ]'
saida="$(hc 2>&1)"; rc=$?
confere "a segunda passada não escreve" '[ "$rc" = 0 ] && printf "%s" "$saida" | grep -q "já declara"'

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'vizinhos: tudo verde\n'; exit 0; fi
printf 'vizinhos: %s falha(s)\n' "$falhas"; exit 1

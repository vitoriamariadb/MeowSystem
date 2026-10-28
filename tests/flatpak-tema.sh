#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FT="$RAIZ/scripts/flatpak_tema.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1"; fi; }

CASA="$T/casa"; SIS="$T/sistema"; FSYS="$T/flatpak-sistema"; ESTADO="$CASA/.local/state/meowsystem"
USUARIO="$CASA/.local/share/flatpak/overrides/global"; GLOBAL="$FSYS/overrides/global"
PONTE_DIR="$T/ponte"; LOG="$T/flatpak.log"; SUDO_LOG="$T/sudo.log"
mkdir -p "$T/bin" "$CASA/.local/share/icons/MeowSystem-Icons" "$CASA/.local/share/icons/Dracula-Cursor-cursors/cursors" \
         "$SIS/themes/adw-gtk3-dark/gtk-3.0" "$SIS/icons" "$(dirname "$USUARIO")" "$(dirname "$GLOBAL")" "$PONTE_DIR" "$ESTADO"
: > "$LOG"; : > "$SUDO_LOG"

cat > "$T/bin/gsettings" <<'FIM'
#!/bin/sh
[ "$1 $2 $3" = "get org.gnome.desktop.interface gtk-theme" ] && { echo "'adw-gtk3-dark'"; exit 0; }
exit 1
FIM
cat > "$T/bin/flatpak" <<'FIM'
#!/usr/bin/env python3
import os, sys
args = [a for a in sys.argv[1:] if a != "--system"]
open(os.environ["FLATPAK_LOG"], "a").write(" ".join(args) + "\n")
fake = os.environ.get("FLATPAK_FAKE", "")
def ler(nome):
    try:
        return open(os.path.join(fake, nome)).read().split()
    except OSError:
        return []
def app(i):
    return os.path.join(fake, "apps", i)
if args[:1] == ["list"]:
    d = os.path.join(fake, "apps")
    for i in sorted(os.listdir(d) if os.path.isdir(d) else []):
        print(i)
    sys.exit(0)
if args[:1] == ["info"]:
    alvo = args[-1]
    if args[1:2] == ["--show-location"]:
        if not os.path.isdir(app(alvo)): sys.exit(1)
        print(app(alvo)); sys.exit(0)
    if args[1:2] == ["--show-commit"]:
        if not os.path.isdir(app(alvo)): sys.exit(1)
        print(open(os.path.join(app(alvo), "commit")).read().strip()); sys.exit(0)
    if args[1:2] == ["--show-runtime"]:
        if not os.path.isdir(app(alvo)): sys.exit(1)
        print(open(os.path.join(app(alvo), "runtime")).read().strip()); sys.exit(0)
    if os.path.isdir(app(alvo)):
        print("              ID: %s\nLaufzeitumgebung: %s" % (alvo, open(os.path.join(app(alvo), "runtime")).read().strip()))
        sys.exit(0)
    if alvo in ler("instalados"):
        sys.exit(0)
    sys.exit(1)
if args[:1] == ["install"]:
    if os.path.exists(os.path.join(fake, "install-falha")):
        sys.exit(1)
    open(os.path.join(fake, "instalados"), "a").write(args[-1] + "\n")
    sys.exit(0)
if args[:2] != ["override", "--user"]:
    sys.exit(0)
arq = os.path.join(os.environ["FLATPAK_USER_DIR"], "overrides", "global")
grupos = {}
if os.path.exists(arq):
    g = None
    for l in open(arq).read().splitlines():
        if l.startswith("["):
            g = l.strip("[]"); grupos.setdefault(g, [])
        elif l.strip() and g:
            k, _, v = l.partition("="); grupos[g].append([k, v])
def pega(g, k):
    for kv in grupos.setdefault(g, []):
        if kv[0] == k: return kv
    kv = [k, ""]; grupos[g].append(kv); return kv
for a in args[2:]:
    if a.startswith("--env="):
        k, _, v = a[6:].partition("="); pega("Environment", k)[1] = v
    elif a.startswith("--filesystem="):
        e = a[13:]; kv = pega("Context", "filesystems")
        itens = [i for i in kv[1].split(";") if i and i.split(":")[0] != e.split(":")[0]]
        kv[1] = ";".join(itens + [e]) + ";"
os.makedirs(os.path.dirname(arq), exist_ok=True)
ordem = [g for g in ("Context", "Environment") if g in grupos] + [g for g in grupos if g not in ("Context", "Environment")]
open(arq, "w").write("\n".join("[%s]\n%s\n" % (g, "\n".join("%s=%s" % (k, v) for k, v in grupos[g])) for g in ordem))
FIM
chmod 755 "$T/bin/gsettings" "$T/bin/flatpak"
cat > "$T/bin/sudo" <<FIM
#!/bin/sh
if [ "\$1" = "-n" ] && [ "\$2" = "$PONTE_DIR/ponte_root.sh" ] && [ -f "$T/ponte-ligada" ]; then shift; exec "\$@"; fi
echo "sudo \$*" >> "$SUDO_LOG"; exit 1
FIM
chmod 755 "$T/bin/sudo"
sed -e "s#^FLATPAK_GLOBAL=.*#FLATPAK_GLOBAL=\"$GLOBAL\"#" -e "s#^USR_SHARE=.*#USR_SHARE=\"$SIS\"#" \
    -e "s#^PERFIL=.*#PERFIL=\"$PONTE_DIR/perfil\"#" -e 's#-o root -g root##' \
    -e 's#^anotar() {#anotar() { return 0#' "$RAIZ/scripts/ponte_root.sh" > "$PONTE_DIR/ponte_root.sh"
chmod 755 "$PONTE_DIR/ponte_root.sh"
printf 'lar=%s\n' "$CASA" > "$PONTE_DIR/perfil"

FAKE="$T/falso"; mkdir -p "$FAKE/apps"
app_falso() {
  local id="$1" runtime="$2" adw="$3" d="$FAKE/apps/$1"
  mkdir -p "$d/files/lib" "$d/export/share/applications" "$d/export/share/dbus-1/services"
  printf '%s\n' "$runtime" > "$d/runtime"; printf 'commit-%s-%s\n' "$id" "$RANDOM" > "$d/commit"
  if [ "$adw" = sim ]; then printf 'binario libadwaita-1.so.0 aqui' > "$d/files/lib/app"; else printf 'binario gtk3 puro' > "$d/files/lib/app"; fi
  printf '[Desktop Entry]\nName=%s\nExec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=app %s @@u %%U @@\nDBusActivatable=true\n' "$id" "$id" > "$d/export/share/applications/$id.desktop"
  printf '[D-BUS Service]\nName=%s\nExec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=app %s --gapplication-service\n' "$id" "$id" > "$d/export/share/dbus-1/services/$id.service"
}
app_falso com.exemplo.Clapper org.gnome.Platform/x86_64/47 sim
app_falso com.exemplo.Gradia org.gnome.Platform/x86_64/51 sim
app_falso com.exemplo.Tocante org.gnome.Platform/x86_64/46 sim
app_falso com.exemplo.Mensagens org.gnome.Platform/x86_64/47 nao
app_falso com.exemplo.Torrent org.kde.Platform/x86_64/6.11 nao
printf 'org.gnome.Platform//47\norg.gnome.Platform//51\n' > "$FAKE/instalados"

rodar() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$ESTADO" NO_COLOR=1 \
      FLATPAK_USER_DIR="$CASA/.local/share/flatpak" FLATPAK_SYSTEM_DIR="$FSYS" FLATPAK_TEMA_SISTEMA="$SIS" \
      FLATPAK_LOG="$LOG" FLATPAK_FAKE="$FAKE" MEOW_PONTE="$PONTE_DIR/ponte_root.sh" CURSOR="${CURSOR_DO_PACK-Dracula-Cursor}" \
      NOME_TEMA_ICONES=MeowSystem-Icons bash "$FT" "$@"
}
env_de() { awk -v k="$2" '/^\[/ { g = $0; next } g == "[Environment]" && index($0, k "=") == 1 { print substr($0, length(k) + 2) }' "$1"; }
chamadas() { grep -c '^override --user' "$LOG"; }
instalacoes() { grep -c '^install ' "$LOG"; }
tudo_do() {
  python3 -I - "$1" <<'PY'
import sys
g = None
for l in open(sys.argv[1]).read().splitlines():
    if l.startswith("["): g = l; continue
    if not l.strip(): continue
    k, _, v = l.partition("=")
    if k == "filesystems":
        for i in v.split(";"):
            if i: print(g, "fs", i)
    else:
        print(g, k, v)
PY
}
igual_a() { [ "$(tudo_do "$1" | sort)" = "$(tudo_do "$2" | sort)" ]; }
instantaneo() { find "$CASA" "$FSYS" -path "$CASA/.cache" -prune -o -type f -printf '%p %s %T@\n' | sort; }
APPS_LOCAIS="$CASA/.local/share/applications"; DBUS_LOCAL="$CASA/.local/share/dbus-1/services"

printf '[Context]\nshared=ipc;\nfilesystems=!home;xdg-config/gtk-3.0:ro;xdg-config/gtk-4.0:ro;xdg-data/icons:ro;/usr/share/themes:ro;\n\n[Environment]\nGTK_THEME=adw-gtk3-dark\n' > "$USUARIO"
cp "$USUARIO" "$T/usuario-original"
printf '[Context]\nfilesystems=xdg-config/gtk-4.0;/usr/share/themes;xdg-data/icons;~/.icons:ro;\n\n[Environment]\nGTK_THEME=adw-gtk3-dark\nICON_THEME=Dracula-Icones\nXCURSOR_THEME=Dracula-Cursor\n' > "$GLOBAL"
cp "$GLOBAL" "$T/global-original"
CONTORNO='[Context]\nfilesystems=!xdg-config/gtk-4.0;!xdg-data/icons;\nunset-environment=GTK_THEME;\n\n[Environment]\nGTK_THEME=\n'
printf "$CONTORNO" > "$(dirname "$USUARIO")/com.exemplo.Clapper"
if [ -x /usr/bin/flatpak ]; then
  env -i PATH=/usr/bin:/bin HOME="$T/fp-real" FLATPAK_USER_DIR="$T/fp-real" /usr/bin/flatpak override --user \
    --unset-env=GTK_THEME --nofilesystem=xdg-config/gtk-4.0 --nofilesystem=xdg-data/icons com.exemplo.Clapper >/dev/null 2>&1
  confere "o contorno da prova é o que o flatpak de verdade grava" \
    'cmp -s "$T/fp-real/overrides/com.exemplo.Clapper" "$(dirname "$USUARIO")/com.exemplo.Clapper"'
fi
printf "$CONTORNO[Context]\nsockets=x11;\n" > "$(dirname "$USUARIO")/com.exemplo.Gradia"
printf '[Context]\nsockets=x11;\n' > "$(dirname "$USUARIO")/com.exemplo.Torrent"

printf '\n1. o doctor vê e não escreve\n'
antes="$(instantaneo)"
saida="$(rodar conferir usuario)"; rc=$?
depois="$(instantaneo)"
confere "o conferir do usuário sai 1 e diz o que mudaria, sem GTK_THEME" \
  '[ "$rc" = 1 ] && grep -q "ICON_THEME=MeowSystem-Icons" <<< "$saida" && grep -q "XCURSOR_THEME=Dracula-Cursor-cursors" <<< "$saida" && ! grep -q "GTK_THEME" <<< "$saida"'
confere "diz que falta a extensão do tema GTK3" 'grep -q "falta a extensão org.gtk.Gtk3theme.adw-gtk3-dark" <<< "$saida"'
confere "não escreve nada e não muda o flatpak" '[ "$antes" = "$depois" ] && [ "$(chamadas)" = 0 ] && [ "$(instalacoes)" = 0 ]'
saida="$(rodar conferir global)"; rc=$?
confere "o conferir do global sai 1 e nomeia o tema que falta, o GTK_THEME e as pastas que quebram" \
  '[ "$rc" = 1 ] && grep -q "ICON_THEME=Dracula-Icones" <<< "$saida" && grep -q "XCURSOR_THEME=Dracula-Cursor" <<< "$saida" && grep -q "GTK_THEME=adw-gtk3-dark" <<< "$saida" && grep -q "filesystems=xdg-config/gtk-4.0" <<< "$saida" && grep -q "filesystems=/usr/share/themes" <<< "$saida" && grep -q "filesystems=xdg-data/icons" <<< "$saida" && ! grep -q "filesystems=~/.icons" <<< "$saida"'

printf '\n2. o --consertar aplica o override do usuário, sem GTK_THEME nem xdg-data/icons\n'
saida="$(rodar aplicar usuario)"; rc=$?
confere "aplicar sai 1, com uma chamada de override e uma instalação da extensão" '[ "$rc" = 1 ] && [ "$(chamadas)" = 1 ] && [ "$(instalacoes)" = 1 ]'
confere "o ícone e o cursor saem do que o MeowSystem instala" \
  '[ "$(env_de "$USUARIO" ICON_THEME)" = MeowSystem-Icons ] && [ "$(env_de "$USUARIO" XCURSOR_THEME)" = Dracula-Cursor-cursors ]'
confere "o override não ganha pasta nenhuma: o Flatpak já monta os ícones" '! grep -q "^override --user.*--filesystem" "$LOG"'
confere "a extensão do tema GTK3 do gsettings é pedida ao Flathub" 'grep -q "^install --user -y --noninteractive flathub org.gtk.Gtk3theme.adw-gtk3-dark$" "$LOG"'
confere "guarda o estado de antes (a chave que ele não tinha)" \
  'grep -q "^env	ICON_THEME	-$" "$ESTADO/flatpak-tema-antes.tsv" && grep -q "^env	XCURSOR_THEME	-$" "$ESTADO/flatpak-tema-antes.tsv"'
confere "a segunda passada não escreve" '
  m1="$(md5sum < "$USUARIO")"; g1="$(md5sum < "$ESTADO/flatpak-tema-antes.tsv")"
  rodar aplicar usuario >/dev/null; rc=$?
  [ "$rc" = 0 ] && [ "$(chamadas)" = 1 ] && [ "$(instalacoes)" = 1 ] && [ "$m1" = "$(md5sum < "$USUARIO")" ] && [ "$g1" = "$(md5sum < "$ESTADO/flatpak-tema-antes.tsv")" ]'
confere "conferido, o doctor fica verde" 'rodar conferir usuario >/dev/null'

printf '\n3. app libadwaita com tema quebrado: o doctor vê, o --consertar tira a causa\n'
antes="$(instantaneo)"
saida="$(rodar conferir libadwaita)"; rc=$?
depois="$(instantaneo)"
confere "o conferir sai 1 e nomeia o GTK_THEME, as duas pastas, o override à parte e os apps libadwaita" \
  '[ "$rc" = 1 ] && grep -q "GTK_THEME=adw-gtk3-dark" <<< "$saida" && grep -q "xdg-config/gtk-4.0" <<< "$saida" && grep -q "/usr/share/themes" <<< "$saida" && grep -q "override à parte de com.exemplo.Clapper" <<< "$saida" && grep -q "com.exemplo.Clapper, com.exemplo.Gradia, com.exemplo.Tocante" <<< "$saida" && ! grep -q "Mensagens" <<< "$saida" && ! grep -q "Torrent" <<< "$saida"'
confere "e não escreve nada" '[ "$antes" = "$depois" ]'
confere "o veredito de cada app fica em cache por commit, fora do estado" \
  'grep -q "^com.exemplo.Clapper	commit-com.exemplo.Clapper-.*	sim$" "$CASA/.cache/meowsystem/flatpak-libadwaita.tsv" && grep -q "^com.exemplo.Mensagens	.*	nao$" "$CASA/.cache/meowsystem/flatpak-libadwaita.tsv"'
saida="$(rodar aplicar libadwaita)"; rc=$?
confere "aplicar sai 1 e o override fica sem GTK_THEME, sem gtk-4.0 e sem /usr/share/themes" \
  '[ "$rc" = 1 ] && [ -z "$(env_de "$USUARIO" GTK_THEME)" ] && ! grep -q "gtk-4.0" "$USUARIO" && ! grep -q "/usr/share/themes" "$USUARIO"'
confere "o que é do usuário e do pack fica" \
  'grep -q "^filesystems=!home;xdg-config/gtk-3.0:ro;xdg-data/icons:ro;$" "$USUARIO" && grep -q "^shared=ipc;" "$USUARIO" && [ "$(env_de "$USUARIO" ICON_THEME)" = MeowSystem-Icons ]'
confere "o override à parte que era só o contorno sai, o que tem mais coisa fica" \
  '[ ! -e "$(dirname "$USUARIO")/com.exemplo.Clapper" ] && [ -e "$(dirname "$USUARIO")/com.exemplo.Gradia" ] && [ -e "$(dirname "$USUARIO")/com.exemplo.Torrent" ]'
confere "o estado de antes guarda o que tirou" \
  'grep -q "^env	GTK_THEME	adw-gtk3-dark$" "$ESTADO/flatpak-tema-antes.tsv" && grep -q "^fsx	xdg-config/gtk-4.0:ro$" "$ESTADO/flatpak-tema-antes.tsv" && grep -q "^fsx	/usr/share/themes:ro$" "$ESTADO/flatpak-tema-antes.tsv"'
rm -f "$(dirname "$USUARIO")/com.exemplo.Gradia"
confere "a segunda passada não escreve e fica verde" '
  m1="$(md5sum < "$USUARIO")"; g1="$(md5sum < "$ESTADO/flatpak-tema-antes.tsv")"
  rodar aplicar libadwaita >/dev/null; rc=$?
  [ "$rc" = 0 ] && [ "$m1" = "$(md5sum < "$USUARIO")" ] && [ "$g1" = "$(md5sum < "$ESTADO/flatpak-tema-antes.tsv")" ] && rodar conferir libadwaita >/dev/null'

printf '\n4. ícones expostos em dobro\n'
saida="$(rodar conferir icones)"; rc=$?
confere "o conferir sai 1 e nomeia xdg-data/icons" '[ "$rc" = 1 ] && grep -q "xdg-data/icons" <<< "$saida"'
rodar aplicar icones >/dev/null; rc=$?
confere "aplicar tira só o xdg-data/icons" \
  '[ "$rc" = 1 ] && ! grep -q "xdg-data/icons" "$USUARIO" && grep -q "^filesystems=!home;xdg-config/gtk-3.0:ro;$" "$USUARIO"'
confere "guarda para devolver e a segunda passada não escreve" '
  grep -q "^fsx	xdg-data/icons:ro$" "$ESTADO/flatpak-tema-antes.tsv"
  m1="$(md5sum < "$USUARIO")"; rodar aplicar icones >/dev/null; rc=$?
  [ "$rc" = 0 ] && [ "$m1" = "$(md5sum < "$USUARIO")" ] && rodar conferir icones >/dev/null'

printf '\n5. trocar de pack troca o override e não traz o GTK_THEME de volta\n'
mkdir -p "$CASA/.local/share/icons/catppuccin-mocha-cursors/cursors"
CURSOR_DO_PACK=catppuccin-mocha rodar aplicar usuario >/dev/null; rc=$?
confere "o cursor do pack novo entra" \
  '[ "$rc" = 1 ] && [ "$(env_de "$USUARIO" XCURSOR_THEME)" = catppuccin-mocha-cursors ] && [ "$(chamadas)" = 2 ]'
confere "o estado de antes do cursor continua o de antes do MeowSystem" 'grep -q "^env	XCURSOR_THEME	-$" "$ESTADO/flatpak-tema-antes.tsv" && [ "$(grep -c "^env	XCURSOR_THEME" "$ESTADO/flatpak-tema-antes.tsv")" = 1 ]'
CURSOR_DO_PACK=catppuccin-mocha rodar aplicar usuario >/dev/null; rc=$?
confere "a passada seguinte não escreve" '[ "$rc" = 0 ] && [ "$(chamadas)" = 2 ]'
confere "nenhum GTK_THEME voltou, para nenhum app libadwaita" '[ -z "$(env_de "$USUARIO" GTK_THEME)" ] && CURSOR_DO_PACK=catppuccin-mocha rodar conferir libadwaita >/dev/null'
confere "CURSOR vazio não toca no cursor" 'CURSOR_DO_PACK="" rodar conferir usuario >/dev/null'

printf '\n6. o global do sistema: sem a ponte, só mostra\n'
saida="$(rodar aplicar global)"; rc=$?
confere "sem ponte sai 3, sem pedir senha, e o arquivo do sistema fica" '[ "$rc" = 3 ] && cmp -s "$GLOBAL" "$T/global-original" && grep -q "^sudo -n .*estado" "$SUDO_LOG"'
confere "vira pendência com botão, sem mandar digitar" 'grep -q "^flatpak-global-sistema	" "$ESTADO/pendencias.tsv" && ! grep -qiE "digite|rode " <<< "$saida"'

printf '\n7. o global do sistema: com a ponte, sai o tema que falta, o GTK_THEME e as pastas que quebram\n'
: > "$T/ponte-ligada"
saida="$(rodar aplicar global)"; rc=$?
confere "aplicar sai 1" '[ "$rc" = 1 ]'
confere "sai tudo menos a pasta do usuário" \
  '[ -z "$(env_de "$GLOBAL" ICON_THEME)" ] && [ -z "$(env_de "$GLOBAL" XCURSOR_THEME)" ] && [ -z "$(env_de "$GLOBAL" GTK_THEME)" ] && [ "$(cat "$GLOBAL")" = "[Context]
filesystems=~/.icons:ro;" ]'
confere "a pendência sai" '! grep -q "^flatpak-global-sistema	" "$ESTADO/pendencias.tsv"'
cp "$GLOBAL" "$T/global-limpo"
rodar aplicar global >/dev/null; rc=$?
confere "a segunda passada não escreve" '[ "$rc" = 0 ] && cmp -s "$GLOBAL" "$T/global-limpo"'
confere "o conferir dos dois fecha verde" 'CURSOR_DO_PACK=catppuccin-mocha rodar conferir usuario >/dev/null && CURSOR_DO_PACK=catppuccin-mocha rodar conferir global >/dev/null'

printf '\n8. a ponte recusa o que não é dela\n'
printf '[Context]\nfilesystems=xdg-data/icons;~/.icons:ro;\n\n[Environment]\nICON_THEME=Dracula-Icones\nGTK_THEME=adw-gtk3-dark\nXCURSOR_THEME=MeowSystem-Icons\n' > "$GLOBAL"; cp "$GLOBAL" "$T/global-recusa"
ponte() { bash "$PONTE_DIR/ponte_root.sh" flatpak-global-limpar; }
printf 'PATH=/tmp\n' | ponte >/dev/null 2>&1; rc=$?
confere "chave fora da lista é recusada e o arquivo fica" '[ "$rc" != 0 ] && cmp -s "$GLOBAL" "$T/global-recusa"'
printf 'ICON_THEME=../x\n' | ponte >/dev/null 2>&1; rc=$?
confere "valor com caminho é recusado" '[ "$rc" != 0 ] && cmp -s "$GLOBAL" "$T/global-recusa"'
printf 'filesystems=/etc\n' | ponte >/dev/null 2>&1; rc=$?
confere "pasta fora da lista é recusada" '[ "$rc" != 0 ] && cmp -s "$GLOBAL" "$T/global-recusa"'
printf 'filesystems=~/.icons\n' | ponte >/dev/null 2>&1; rc=$?
confere "a pasta do usuário também" '[ "$rc" != 0 ] && cmp -s "$GLOBAL" "$T/global-recusa"'
printf 'XCURSOR_THEME=MeowSystem-Icons\n' | ponte >/dev/null 2>&1; rc=$?
confere "tema que existe no disco não sai, mesmo pedido" '[ "$rc" = 0 ] && cmp -s "$GLOBAL" "$T/global-recusa"'
printf 'ICON_THEME=Outro\n' | ponte >/dev/null 2>&1; rc=$?
confere "valor que o arquivo não tem não sai" '[ "$rc" = 0 ] && cmp -s "$GLOBAL" "$T/global-recusa"'
printf 'ICON_THEME=Dracula-Icones\n' | ponte >/dev/null 2>&1
confere "o pedido certo tira só a linha dele" '[ -z "$(env_de "$GLOBAL" ICON_THEME)" ] && [ "$(env_de "$GLOBAL" GTK_THEME)" = adw-gtk3-dark ]'
printf 'GTK_THEME=adw-gtk3-dark\nfilesystems=xdg-data/icons\n' | ponte >/dev/null 2>&1; rc=$?
confere "o GTK_THEME sai mesmo com o tema no disco, e a pasta sai sem levar a do usuário" \
  '[ "$rc" = 0 ] && [ -z "$(env_de "$GLOBAL" GTK_THEME)" ] && grep -q "^filesystems=~/.icons:ro;$" "$GLOBAL" && [ "$(env_de "$GLOBAL" XCURSOR_THEME)" = MeowSystem-Icons ]'
confere "a regra de sudo da ponte nomeia o verbo, sem curinga" \
  'PONTE_ROOT_USER=x SUDO_USER=alguem bash "$RAIZ/scripts/ponte_root.sh" regra-sudo | grep -q "ponte_root.sh flatpak-global-limpar, " && ! bash "$RAIZ/scripts/ponte_root.sh" regra-sudo | grep -q "flatpak-global-limpar \*"'

printf '\n9. app Flatpak em runtime GNOME antigo abre no runtime validado\n'
antes="$(instantaneo)"
saida="$(rodar conferir runtime)"; rc=$?
depois="$(instantaneo)"
confere "o conferir sai 1 e diz que falta o runtime 49, só para os libadwaita em runtime antigo" \
  '[ "$rc" = 1 ] && grep -q "falta o runtime org.gnome.Platform//49" <<< "$saida" && grep -q "com.exemplo.Clapper" <<< "$saida" && grep -q "com.exemplo.Tocante" <<< "$saida" && ! grep -q "Mensagens" <<< "$saida" && ! grep -q "Gradia" <<< "$saida"'
confere "e não escreve nem instala" '[ "$antes" = "$depois" ] && [ "$(instalacoes)" = 1 ]'
touch "$FAKE/install-falha"
n0="$(instalacoes)"
saida="$(rodar aplicar runtime)"; rc=$?
rm -f "$FAKE/install-falha"
confere "sem conseguir instalar o runtime, sai 3 e não escreve contorno" \
  '[ "$rc" = 3 ] && [ "$(instalacoes)" = "$((n0 + 1))" ] && [ ! -e "$APPS_LOCAIS/com.exemplo.Clapper.desktop" ] && [ ! -e "$DBUS_LOCAL/com.exemplo.Clapper.service" ]'
mkdir -p "$APPS_LOCAIS" "$DBUS_LOCAL"
printf '[Desktop Entry]\nName=Tocante\nName[pt_BR]=Meu nome\nExec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=app com.exemplo.Tocante @@u %%U @@\n' > "$APPS_LOCAIS/com.exemplo.Tocante.desktop"
printf '[D-BUS Service]\nName=com.exemplo.Tocante\nExec=/bin/meu-proprio\n' > "$DBUS_LOCAL/com.exemplo.Tocante.service"
cp "$DBUS_LOCAL/com.exemplo.Tocante.service" "$T/tocante-servico"
saida="$(rodar aplicar runtime)"; rc=$?
confere "aplicar sai 1 e instala o 49 sem senha" \
  '[ "$rc" = 1 ] && grep -q "^install --user -y --noninteractive flathub org.gnome.Platform//49$" "$LOG"'
confere "o Clapper ganha o .desktop e o serviço D-Bus no runtime 49, com a marca" \
  'grep -q "flatpak run --runtime=org.gnome.Platform//49 --branch=stable" "$APPS_LOCAIS/com.exemplo.Clapper.desktop" && grep -qx "# corrigir-flatpaks-libadwaita" "$DBUS_LOCAL/com.exemplo.Clapper.service" && grep -q "flatpak run --runtime=org.gnome.Platform//49 --branch=stable" "$DBUS_LOCAL/com.exemplo.Clapper.service"'
confere "a cópia local que já existia guarda a tradução dela" \
  'grep -qx "Name\[pt_BR\]=Meu nome" "$APPS_LOCAIS/com.exemplo.Tocante.desktop" && grep -q "flatpak run --runtime=org.gnome.Platform//49 " "$APPS_LOCAIS/com.exemplo.Tocante.desktop"'
confere "o serviço D-Bus sem a marca não é tocado" 'cmp -s "$DBUS_LOCAL/com.exemplo.Tocante.service" "$T/tocante-servico"'
confere "app em runtime novo, sem libadwaita ou em outro runtime fica como está" \
  '[ ! -e "$APPS_LOCAIS/com.exemplo.Gradia.desktop" ] && [ ! -e "$APPS_LOCAIS/com.exemplo.Mensagens.desktop" ] && [ ! -e "$APPS_LOCAIS/com.exemplo.Torrent.desktop" ] && [ ! -e "$DBUS_LOCAL/com.exemplo.Mensagens.service" ]'
confere "a segunda passada não escreve" '
  a1="$(find "$APPS_LOCAIS" "$DBUS_LOCAL" -type f -exec md5sum {} + | sort)"; n1="$(instalacoes)"
  rodar aplicar runtime >/dev/null; rc=$?
  [ "$rc" = 0 ] && [ "$a1" = "$(find "$APPS_LOCAIS" "$DBUS_LOCAL" -type f -exec md5sum {} + | sort)" ] && [ "$(instalacoes)" = "$n1" ] && rodar conferir runtime >/dev/null'
printf 'org.gnome.Platform/x86_64/49\n' > "$FAKE/apps/com.exemplo.Clapper/runtime"
saida="$(rodar aplicar runtime)"; rc=$?
confere "o app que sobe para o 49 perde o contorno sozinho" \
  '[ "$rc" = 1 ] && [ ! -e "$APPS_LOCAIS/com.exemplo.Clapper.desktop" ] && [ ! -e "$DBUS_LOCAL/com.exemplo.Clapper.service" ] && [ -e "$APPS_LOCAIS/com.exemplo.Tocante.desktop" ]'
confere "e a passada seguinte não escreve" 'rodar aplicar runtime >/dev/null'
printf 'org.gnome.Platform//50\n' > "$FAKE/instalados"
rodar aplicar runtime >/dev/null
confere "sem o 49 e com o 50 instalado, o 50 serve" 'grep -q "flatpak run --runtime=org.gnome.Platform//50 " "$APPS_LOCAIS/com.exemplo.Tocante.desktop"'

printf '\n10. a extensão do tema GTK3 que o Flathub não tem não vira erro nem repetição\n'
rm -f "$ESTADO/flatpak-gtk3-tentou.tsv"; : > "$FAKE/instalados"
printf '#!/bin/sh\n[ "$1 $2 $3" = "get org.gnome.desktop.interface gtk-theme" ] && { echo "'"'"'Dracula'"'"'"; exit 0; }\nexit 1\n' > "$T/bin/gsettings"
touch "$FAKE/install-falha"; n0="$(instalacoes)"
saida="$(CURSOR_DO_PACK=catppuccin-mocha rodar aplicar usuario)"; rc=$?
confere "uma tentativa, avisa e sai 0" '[ "$rc" = 0 ] && [ "$(instalacoes)" = "$((n0 + 1))" ] && grep -q "org.gtk.Gtk3theme.Dracula" <<< "$saida"'
CURSOR_DO_PACK=catppuccin-mocha rodar aplicar usuario >/dev/null; rc=$?
confere "no mesmo dia não tenta de novo" '[ "$rc" = 0 ] && [ "$(instalacoes)" = "$((n0 + 1))" ]'
rm -f "$FAKE/install-falha"
cat > "$T/bin/gsettings" <<'FIM'
#!/bin/sh
[ "$1 $2 $3" = "get org.gnome.desktop.interface gtk-theme" ] && { echo "'adw-gtk3-dark'"; exit 0; }
exit 1
FIM

printf '\n11. o desinstalador devolve o de antes\n'
saida="$(rodar reverter)"; rc=$?
confere "o reverter sai 0 e o override volta ao de antes, com o GTK_THEME e as pastas que ele tinha" \
  '[ "$rc" = 0 ] && igual_a "$USUARIO" "$T/usuario-original"'
confere "a guarda sai junto" '[ ! -e "$ESTADO/flatpak-tema-antes.tsv" ]'
rodar reverter >/dev/null; rc=$?
confere "reverter de novo não faz nada" '[ "$rc" = 0 ] && igual_a "$USUARIO" "$T/usuario-original"'
rm -f "$USUARIO"; : > "$LOG"
rodar aplicar usuario >/dev/null
rodar reverter >/dev/null
confere "sem override de antes, o reverter tira o arquivo" '[ ! -e "$USUARIO" ]'
confere "o lib/desinstalar.sh chama o reverter" 'grep -qE "flatpak_tema\.sh\" reverter" "$RAIZ/lib/desinstalar.sh"'

printf '\n12. sem o que pôr ou sem flatpak, nada a fazer\n'
mkdir -p "$T/sem-flatpak"
for b in /usr/bin/*; do [ "${b##*/}" = flatpak ] || ln -s "$b" "$T/sem-flatpak/${b##*/}" 2>/dev/null; done
saida="$(env -i PATH="$T/sem-flatpak" HOME="$CASA" MEOW_ESTADO="$ESTADO" NO_COLOR=1 FLATPAK_USER_DIR="$CASA/.local/share/flatpak" bash "$FT" aplicar)"; rc=$?
confere "sem flatpak no PATH sai 0 e não escreve" '[ "$rc" = 0 ] && [ ! -e "$USUARIO" ]'
saida="$(env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/vazia" MEOW_ESTADO="$T/vazia/estado" NO_COLOR=1 FLATPAK_USER_DIR="$T/vazia/flatpak" FLATPAK_TEMA_SISTEMA="$T/nada" FLATPAK_LOG="$LOG" FLATPAK_FAKE="$T/falso-vazio" bash "$FT" aplicar usuario)"; rc=$?
confere "sem tema nenhum no disco o override fica como está" '[ ! -e "$T/vazia/flatpak/overrides" ]'

printf '\n13. a fiação: etapa, doctor e ponte\n'
confere "a etapa está na lista do instalador" 'sed -n "/local etapas=(/,/)/p" "$RAIZ/install.sh" | grep -q etapa_flatpak_tema'
confere "o doctor tem o par chk_/fix_ de cada item" \
  'for n in flatpaktema flatpakadwaita flatpakicones flatpakruntime flatpakglobal; do grep -q "^chk_$n()" "$RAIZ/bin/meow" && grep -q "^fix_$n()" "$RAIZ/bin/meow" && grep -q "^VERIFICAVEIS=.* $n" "$RAIZ/bin/meow" || exit 1; done'
confere "sem ponte, o doctor não promete consertar o global" 'grep -q "SEM_CONSERTO=\".* flatpakglobal " "$RAIZ/bin/meow"'
confere "o vigia do flatpak reaplica o conserto depois de instalar ou atualizar um app" \
  'grep -q "flatpak_tema.sh" "$RAIZ/scripts/apos_flatpak.sh"'
confere "o LibreOffice não está escondido nem no lançador nem no pack (a decisão de 23/10)" '! grep -rqiE "startcenter" "$RAIZ/meow.conf.exemplo" "$RAIZ/scripts" "$RAIZ/lib" "$RAIZ/bin" "$RAIZ/install.sh" "$RAIZ/app" "$RAIZ/docs/PACKS.md" && ! grep -qi libreoffice "$RAIZ/meow.conf.exemplo" "$RAIZ/scripts/pack.py" "$RAIZ/docs/PACKS.md" "$RAIZ/scripts/ocultar_apps.sh"'
confere "o script não escreve GTK_THEME nem xdg-data/icons no que o Flatpak recebe" \
  '! grep -E "^FT_CHAVES=.*GTK_THEME" "$FT" && ! grep -E "DESEJO\[GTK_THEME\]" "$FT"'
printf '\n14. os dois scripts do NitroKit saem pelo vizinhos.sh, quando o instalado cuida\n'
DESENV="$CASA/Desenvolvimento"; mkdir -p "$DESENV/NitroKit/src" "$T/vbin"
for s in unificador_temas_dracula ritual_de_harmonia; do
  printf '#!/usr/bin/env bash\necho escrevi\n' > "$DESENV/NitroKit/src/$s.sh"; chmod 755 "$DESENV/NitroKit/src/$s.sh"
  cp -a "$DESENV/NitroKit/src/$s.sh" "$T/$s-original.sh"
done
for c in curl wget sudo; do printf '#!/bin/sh\nexit 1\n' > "$T/vbin/$c"; chmod 755 "$T/vbin/$c"; done
viz() { env -i PATH="$T/vbin:/usr/bin:/bin" HOME="$CASA" ZDOTDIR="$CASA/zsh" VIZINHOS_ETC="$T/etc" VIZINHOS_DESENV="$DESENV" \
            VIZINHOS_CRONTAB="$T/sem-cron" MEOW_ESTADO="$ESTADO" NO_COLOR=1 bash "$RAIZ/scripts/vizinhos.sh" "$@"; }
mkdir -p "$CASA/zsh" "$T/etc"
FALSA="$T/meow-velho"; mkdir -p "$FALSA/bin" "$FALSA/scripts"; : > "$FALSA/bin/meow"; printf '#!/bin/sh\n' > "$FALSA/scripts/flatpak_tema.sh"
printf '%s\n' "$FALSA" > "$ESTADO/raiz"
confere "o contrato lista os dois itens, esperando o MeowSystem instalado" \
  'viz --listar | grep -q "^nitrokit-unificador-temas	espera" && viz --listar | grep -q "^nitrokit-ritual-harmonia	espera"'
viz --desativar nitrokit-unificador-temas >/dev/null
confere "com o instalado velho, nada muda" 'cmp -s "$DESENV/NitroKit/src/unificador_temas_dracula.sh" "$T/unificador_temas_dracula-original.sh"'
printf '%s\n' "$RAIZ" > "$ESTADO/raiz"
viz --desativar nitrokit-unificador-temas >/dev/null; viz --desativar nitrokit-ritual-harmonia >/dev/null
saida="$(env -i PATH="/usr/bin:/bin" HOME="$T/outra" bash "$DESENV/NitroKit/src/unificador_temas_dracula.sh" 2>&1)"; rc=$?
confere "com o instalado que cuida, os dois saem 0 sem fazer o resto" \
  '[ "$rc" = 0 ] && ! grep -q escrevi <<< "$saida" && ! env -i PATH=/usr/bin:/bin bash "$DESENV/NitroKit/src/ritual_de_harmonia.sh" | grep -q escrevi'
viz --restaurar todos >/dev/null
confere "e restaurar devolve os dois byte a byte" \
  'cmp -s "$DESENV/NitroKit/src/unificador_temas_dracula.sh" "$T/unificador_temas_dracula-original.sh" && cmp -s "$DESENV/NitroKit/src/ritual_de_harmonia.sh" "$T/ritual_de_harmonia-original.sh"'

printf '\n15. app em JavaScript com o código comprimido no gresource também é achado\n'
if command -v gresource >/dev/null 2>&1 && command -v glib-compile-resources >/dev/null 2>&1; then
  FAKE2="$T/falso-gjs"; mkdir -p "$FAKE2/apps" "$T/gjs"
  for par in com.exemplo.Selo:"pkg.require({ Gio: '2.0', Gtk: '4.0', Adw: '1' });" com.exemplo.Gtk3:"pkg.require({ Gtk: '3.0' });"; do
    id="${par%%:*}"; d="$FAKE2/apps/$id"; mkdir -p "$d/files/share" "$T/gjs/$id/js"
    printf '%s\n' "${par#*:}" > "$T/gjs/$id/js/main.js"
    printf '<?xml version="1.0"?>\n<gresources><gresource prefix="/x"><file compressed="true">js/main.js</file></gresource></gresources>\n' > "$T/gjs/$id/r.xml"
    glib-compile-resources --sourcedir="$T/gjs/$id" --target="$d/files/share/$id.src.gresource" "$T/gjs/$id/r.xml"
    printf 'org.gnome.Platform/x86_64/50\n' > "$d/runtime"; printf 'commit-%s\n' "$id" > "$d/commit"
  done
  achados="$(env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/casa-gjs" XDG_CACHE_HOME="$T/casa-gjs/.cache" MEOW_ESTADO="$T/casa-gjs/estado" \
             FLATPAK_LOG="$LOG" FLATPAK_FAKE="$FAKE2" bash -c '. "$0/lib/comum.sh"; meow_flatpak_apps_libadwaita' "$RAIZ")"
  confere "o texto comprimido não esconde o Adw, e o app GTK3 fica de fora" \
    '! grep -qa "Adw" "$FAKE2/apps/com.exemplo.Selo/files/share/com.exemplo.Selo.src.gresource" && [ "$achados" = com.exemplo.Selo ]'
else
  falha "falta gresource ou glib-compile-resources para provar a detecção no gresource"
fi

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'flatpak-tema: tudo verde\n'; exit 0; fi
printf 'flatpak-tema: %s falha(s)\n' "$falhas"; exit 1

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
args = sys.argv[1:]
open(os.environ["FLATPAK_LOG"], "a").write(" ".join(args) + "\n")
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

rodar() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$CASA" MEOW_ESTADO="$ESTADO" NO_COLOR=1 \
      FLATPAK_USER_DIR="$CASA/.local/share/flatpak" FLATPAK_SYSTEM_DIR="$FSYS" FLATPAK_TEMA_SISTEMA="$SIS" \
      FLATPAK_LOG="$LOG" MEOW_PONTE="$PONTE_DIR/ponte_root.sh" CURSOR="${CURSOR_DO_PACK-Dracula-Cursor}" \
      NOME_TEMA_ICONES=MeowSystem-Icons bash "$FT" "$@"
}
env_de() { awk -v k="$2" '/^\[/ { g = $0; next } g == "[Environment]" && index($0, k "=") == 1 { print substr($0, length(k) + 2) }' "$1"; }
chamadas() { grep -c 'override --user' "$LOG"; }

printf '[Context]\nshared=ipc;\nfilesystems=!home;xdg-config/gtk-3.0:ro;\n\n[Environment]\nGTK_THEME=Velho\n' > "$USUARIO"
cp "$USUARIO" "$T/usuario-original"
printf '[Context]\nfilesystems=xdg-config/gtk-4.0;/usr/share/themes;\n\n[Environment]\nGTK_THEME=adw-gtk3-dark\nICON_THEME=Dracula-Icones\nXCURSOR_THEME=Dracula-Cursor\n' > "$GLOBAL"
cp "$GLOBAL" "$T/global-original"

printf '\n1. o doctor vê e não escreve\n'
antes="$(find "$CASA" "$FSYS" -type f -printf '%p %s %T@\n' | sort)"
saida="$(rodar conferir usuario)"; rc=$?
depois="$(find "$CASA" "$FSYS" -type f -printf '%p %s %T@\n' | sort)"
confere "o conferir do usuário sai 1 e diz o que mudaria" '[ "$rc" = 1 ] && grep -q "ICON_THEME=MeowSystem-Icons" <<< "$saida" && grep -q "XCURSOR_THEME=Dracula-Cursor-cursors" <<< "$saida" && grep -q "GTK_THEME=adw-gtk3-dark" <<< "$saida"'
confere "não escreve nada e não chama o flatpak" '[ "$antes" = "$depois" ] && [ "$(chamadas)" = 0 ]'
saida="$(rodar conferir global)"; rc=$?
confere "o conferir do global sai 1 e nomeia só os dois temas que faltam" '[ "$rc" = 1 ] && grep -q "ICON_THEME=Dracula-Icones" <<< "$saida" && grep -q "XCURSOR_THEME=Dracula-Cursor" <<< "$saida" && ! grep -q "GTK_THEME" <<< "$saida"'

printf '\n2. o --consertar aplica o override do usuário\n'
saida="$(rodar aplicar usuario)"; rc=$?
confere "aplicar sai 1, com uma chamada só ao flatpak" '[ "$rc" = 1 ] && [ "$(chamadas)" = 1 ]'
confere "o ícone, o cursor e o GTK saem do que o MeowSystem instala" \
  '[ "$(env_de "$USUARIO" ICON_THEME)" = MeowSystem-Icons ] && [ "$(env_de "$USUARIO" XCURSOR_THEME)" = Dracula-Cursor-cursors ] && [ "$(env_de "$USUARIO" GTK_THEME)" = adw-gtk3-dark ]'
confere "leitura nas pastas dos temas, e o que o usuário tinha fica" \
  'grep -q "^filesystems=.*xdg-data/icons:ro" "$USUARIO" && grep -q "^filesystems=.*$SIS/themes:ro" "$USUARIO" && grep -q "^filesystems=!home;xdg-config/gtk-3.0:ro;" "$USUARIO" && grep -q "^shared=ipc;" "$USUARIO"'
confere "guarda o estado de antes (o GTK_THEME que ele tinha)" \
  'grep -q "^env	GTK_THEME	Velho$" "$ESTADO/flatpak-tema-antes.tsv" && grep -q "^env	ICON_THEME	-$" "$ESTADO/flatpak-tema-antes.tsv"'
confere "a segunda passada não escreve" '
  m1="$(md5sum < "$USUARIO")"; g1="$(md5sum < "$ESTADO/flatpak-tema-antes.tsv")"
  rodar aplicar usuario >/dev/null; rc=$?
  [ "$rc" = 0 ] && [ "$(chamadas)" = 1 ] && [ "$m1" = "$(md5sum < "$USUARIO")" ] && [ "$g1" = "$(md5sum < "$ESTADO/flatpak-tema-antes.tsv")" ]'
confere "conferido, o doctor fica verde" 'rodar conferir usuario >/dev/null'

printf '\n3. trocar de pack troca o override\n'
mkdir -p "$CASA/.local/share/icons/catppuccin-mocha-cursors/cursors"
CURSOR_DO_PACK=catppuccin-mocha rodar aplicar usuario >/dev/null; rc=$?
confere "o cursor do pack novo entra e a chave antiga sai de cena" \
  '[ "$rc" = 1 ] && [ "$(env_de "$USUARIO" XCURSOR_THEME)" = catppuccin-mocha-cursors ] && [ "$(chamadas)" = 2 ]'
confere "o estado de antes do cursor continua o de antes do MeowSystem" 'grep -q "^env	XCURSOR_THEME	-$" "$ESTADO/flatpak-tema-antes.tsv" && [ "$(grep -c "^env	XCURSOR_THEME" "$ESTADO/flatpak-tema-antes.tsv")" = 1 ]'
CURSOR_DO_PACK=catppuccin-mocha rodar aplicar usuario >/dev/null; rc=$?
confere "e a passada seguinte não escreve" '[ "$rc" = 0 ] && [ "$(chamadas)" = 2 ]'
confere "CURSOR vazio não toca no cursor" 'CURSOR_DO_PACK="" rodar conferir usuario >/dev/null'

printf '\n4. o global do sistema: sem a ponte, só mostra\n'
saida="$(rodar aplicar global)"; rc=$?
confere "sem ponte sai 3, sem pedir senha, e o arquivo do sistema fica" '[ "$rc" = 3 ] && cmp -s "$GLOBAL" "$T/global-original" && grep -q "^sudo -n .*estado" "$SUDO_LOG"'
confere "vira pendência com botão, sem mandar digitar" 'grep -q "^flatpak-global-sistema	" "$ESTADO/pendencias.tsv" && ! grep -qiE "digite|rode " <<< "$saida"'

printf '\n5. o global do sistema: com a ponte, sai só o que aponta para o vazio\n'
: > "$T/ponte-ligada"
saida="$(rodar aplicar global)"; rc=$?
confere "aplicar sai 1" '[ "$rc" = 1 ]'
confere "saem ICON_THEME e XCURSOR_THEME, o GTK_THEME que existe fica" \
  '[ -z "$(env_de "$GLOBAL" ICON_THEME)" ] && [ -z "$(env_de "$GLOBAL" XCURSOR_THEME)" ] && [ "$(env_de "$GLOBAL" GTK_THEME)" = adw-gtk3-dark ]'
confere "o resto do arquivo fica" 'grep -q "^filesystems=xdg-config/gtk-4.0;/usr/share/themes;$" "$GLOBAL"'
confere "a pendência sai" '! grep -q "^flatpak-global-sistema	" "$ESTADO/pendencias.tsv"'
cp "$GLOBAL" "$T/global-limpo"
rodar aplicar global >/dev/null; rc=$?
confere "a segunda passada não escreve" '[ "$rc" = 0 ] && cmp -s "$GLOBAL" "$T/global-limpo"'
confere "o conferir dos dois fecha verde" 'CURSOR_DO_PACK=catppuccin-mocha rodar conferir >/dev/null'

printf '\n6. a ponte recusa o que não é dela\n'
printf '[Environment]\nICON_THEME=Dracula-Icones\nGTK_THEME=adw-gtk3-dark\n' > "$GLOBAL"; cp "$GLOBAL" "$T/global-recusa"
ponte() { bash "$PONTE_DIR/ponte_root.sh" flatpak-global-limpar; }
printf 'PATH=/tmp\n' | ponte >/dev/null 2>&1; rc=$?
confere "chave fora das três é recusada e o arquivo fica" '[ "$rc" != 0 ] && cmp -s "$GLOBAL" "$T/global-recusa"'
printf 'ICON_THEME=../x\n' | ponte >/dev/null 2>&1; rc=$?
confere "valor com caminho é recusado" '[ "$rc" != 0 ] && cmp -s "$GLOBAL" "$T/global-recusa"'
printf 'GTK_THEME=adw-gtk3-dark\n' | ponte >/dev/null 2>&1; rc=$?
confere "tema que existe não sai, mesmo pedido" '[ "$rc" = 0 ] && cmp -s "$GLOBAL" "$T/global-recusa"'
printf 'ICON_THEME=Outro\n' | ponte >/dev/null 2>&1; rc=$?
confere "valor que o arquivo não tem não sai" '[ "$rc" = 0 ] && cmp -s "$GLOBAL" "$T/global-recusa"'
printf 'ICON_THEME=Dracula-Icones\n' | ponte >/dev/null 2>&1
confere "o pedido certo tira só a linha dele" '[ -z "$(env_de "$GLOBAL" ICON_THEME)" ] && [ "$(env_de "$GLOBAL" GTK_THEME)" = adw-gtk3-dark ]'
confere "a regra de sudo da ponte nomeia o verbo, sem curinga" \
  'PONTE_ROOT_USER=x SUDO_USER=alguem bash "$RAIZ/scripts/ponte_root.sh" regra-sudo | grep -q "ponte_root.sh flatpak-global-limpar, " && ! bash "$RAIZ/scripts/ponte_root.sh" regra-sudo | grep -q "flatpak-global-limpar \*"'

printf '\n7. o desinstalador devolve o de antes\n'
saida="$(rodar reverter)"; rc=$?
confere "o reverter sai 0 e o arquivo volta ao de antes" '[ "$rc" = 0 ] && cmp -s "$USUARIO" "$T/usuario-original"'
confere "a guarda sai junto" '[ ! -e "$ESTADO/flatpak-tema-antes.tsv" ]'
rodar reverter >/dev/null; rc=$?
confere "reverter de novo não faz nada" '[ "$rc" = 0 ] && cmp -s "$USUARIO" "$T/usuario-original"'
rm -f "$USUARIO"; : > "$LOG"
rodar aplicar usuario >/dev/null
rodar reverter >/dev/null
confere "sem override de antes, o reverter tira o arquivo" '[ ! -e "$USUARIO" ]'
confere "o lib/desinstalar.sh chama o reverter" 'grep -qE "flatpak_tema\.sh\" reverter" "$RAIZ/lib/desinstalar.sh"'

printf '\n8. sem o que vestir ou sem flatpak, nada a fazer\n'
mkdir -p "$T/sem-flatpak"
for b in /usr/bin/*; do [ "${b##*/}" = flatpak ] || ln -s "$b" "$T/sem-flatpak/${b##*/}" 2>/dev/null; done
saida="$(env -i PATH="$T/sem-flatpak" HOME="$CASA" MEOW_ESTADO="$ESTADO" NO_COLOR=1 FLATPAK_USER_DIR="$CASA/.local/share/flatpak" bash "$FT" aplicar usuario)"; rc=$?
confere "sem flatpak no PATH sai 0 e não escreve" '[ "$rc" = 0 ] && [ ! -e "$USUARIO" ]'
saida="$(env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/vazia" MEOW_ESTADO="$T/vazia/estado" NO_COLOR=1 FLATPAK_USER_DIR="$T/vazia/flatpak" FLATPAK_TEMA_SISTEMA="$T/nada" FLATPAK_LOG="$LOG" bash "$FT" aplicar usuario)"; rc=$?
confere "sem tema nenhum no disco sai 0 e não escreve" '[ "$rc" = 0 ] && [ ! -e "$T/vazia/flatpak" ]'

printf '\n9. a fiação: etapa, doctor e ponte\n'
confere "a etapa está na lista do instalador" 'sed -n "/local etapas=(/,/)/p" "$RAIZ/install.sh" | grep -q etapa_flatpak_tema'
confere "o doctor tem o par chk_/fix_ dos dois itens" \
  'for n in flatpaktema flatpakglobal; do grep -q "^chk_$n()" "$RAIZ/bin/meow" && grep -q "^fix_$n()" "$RAIZ/bin/meow" && grep -q "^VERIFICAVEIS=.* $n" "$RAIZ/bin/meow" || exit 1; done'
confere "sem ponte, o doctor não promete consertar o global" 'grep -q "SEM_CONSERTO=\".* flatpakglobal " "$RAIZ/bin/meow"'
confere "o LibreOffice não está escondido nem no lançador nem no pack (a decisão de 23/10)" '! grep -rqiE "startcenter" "$RAIZ/meow.conf.exemplo" "$RAIZ/scripts" "$RAIZ/lib" "$RAIZ/bin" "$RAIZ/install.sh" "$RAIZ/app" "$RAIZ/contratos" "$RAIZ/docs/PACKS.md" && ! grep -qi libreoffice "$RAIZ/meow.conf.exemplo" "$RAIZ/scripts/pack.py" "$RAIZ/docs/PACKS.md" "$RAIZ/scripts/ocultar_apps.sh"'

printf '\n10. os dois scripts do NitroKit saem pelo vizinhos.sh, quando o instalado cuida\n'
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

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'flatpak-tema: tudo verde\n'; exit 0; fi
printf 'flatpak-tema: %s falha(s)\n' "$falhas"; exit 1

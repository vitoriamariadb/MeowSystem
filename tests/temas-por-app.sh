#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'FALHOU: sem python3\n' >&2; exit 1; }

APPS=(libadwaita krita obs firefox godot gimp ghostwriter)
PACKS=(meowsystem:mocha dracula:dracula)

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
BIN="$T/bin"; CASA="$T/casa"; FAKE="$T/falso"; mkdir -p "$BIN"
for x in sudo pkexec su apt apt-get systemctl pkill; do
  printf '#!/bin/sh\necho "recusado: %s" >&2\nexit 1\n' "$x" > "$BIN/$x"; chmod +x "$BIN/$x"
done
printf '#!/bin/sh\nexit 1\n' > "$BIN/pgrep"; chmod +x "$BIN/pgrep"
cat > "$BIN/flatpak" <<'FIM'
#!/usr/bin/env python3
import os, sys
args = [a for a in sys.argv[1:] if a != "--system"]
fake = os.environ["FLATPAK_FAKE"]
apps = os.path.join(fake, "apps")
if args[:1] == ["list"]:
    for i in sorted(os.listdir(apps) if os.path.isdir(apps) else []):
        print(i)
    sys.exit(0)
if args[:1] == ["info"]:
    alvo = args[-1]
    pasta = os.path.join(apps, alvo)
    if not os.path.isdir(pasta):
        sys.exit(1)
    if args[1:2] == ["--show-location"]:
        print(pasta); sys.exit(0)
    if args[1:2] == ["--show-commit"]:
        print(open(os.path.join(pasta, "commit")).read().strip()); sys.exit(0)
    sys.exit(0)
sys.exit(1)
FIM
chmod +x "$BIN/flatpak"

app_flatpak() {
  local id="$1" adw="$2" d="$FAKE/apps/$1"
  mkdir -p "$d/files/lib"
  printf 'commit-%s\n' "$id" > "$d/commit"
  if [ "$adw" = sim ]; then printf 'binario libadwaita-1.so.0 aqui' > "$d/files/lib/app"; else printf 'binario gtk3 puro' > "$d/files/lib/app"; fi
}
no_disco() {
  local a="$CASA/.local/share/flatpak/app/$1"
  mkdir -p "$a/x86_64/stable/0123abcd" && ln -sfn 0123abcd "$a/x86_64/stable/active"
}
semear() {
  rm -rf "$CASA" "$FAKE" "$T/estado"; mkdir -p "$CASA/.config" "$FAKE/apps"
  rm -f "$BIN/obs" "$BIN/krita" "$BIN/firefox" "$BIN/ghostwriter"
  case "$1" in
    libadwaita)
      app_flatpak com.github.rafostar.Clapper sim
      app_flatpak be.alexandervanhee.gradia sim
      app_flatpak org.bleachbit.BleachBit nao ;;
    krita)
      no_disco org.kde.krita
      mkdir -p "$CASA/.var/app/org.kde.krita/config"
      printf '[General]\nfirst_run=false\n' > "$CASA/.var/app/org.kde.krita/config/kritarc" ;;
    obs)
      no_disco com.obsproject.Studio
      mkdir -p "$CASA/.var/app/com.obsproject.Studio/config/obs-studio"
      printf '[General]\nLanguage=pt-BR\n' > "$CASA/.var/app/com.obsproject.Studio/config/obs-studio/user.ini" ;;
    ghostwriter)
      no_disco org.kde.ghostwriter
      mkdir -p "$CASA/.var/app/org.kde.ghostwriter/config/kde.org"
      printf '[General]\nlocale=pt_BR\n\n[Style]\ndarkModeEnabled=true\ntheme=Classic Light\n' \
        > "$CASA/.var/app/org.kde.ghostwriter/config/kde.org/ghostwriter.conf" ;;
    gimp)
      no_disco org.gimp.GIMP
      mkdir -p "$CASA/.config/GIMP/3.2/themes" "$CASA/.config/GIMP/3.0"
      printf '(undo-levels 99)\n' > "$CASA/.config/GIMP/3.0/gimprc" ;;
    godot)
      mkdir -p "$CASA/.config/godot"
      printf '[gd_resource type="EditorSettings" load_steps=2 format=3]\n\n[sub_resource type="InputEventKey" id="InputEventKey_lde7y"]\nkeycode = 4194326\n\n[resource]\ninterface/theme/base_color = Color(0.21, 0.24, 0.29, 1)\ninterface/theme/accent_color = Color(0.44, 0.73, 0.98, 1)\ninterface/theme/contrast = 0.3\ninterface/editor/display_scale = 3\n' \
        > "$CASA/.config/godot/editor_settings-4.4.tres"
      printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\nresource_local_to_scene = false\ninterface/theme/color_preset = "Default"\ninterface/theme/base_color = Color(0.161, 0.161, 0.161, 1)\ninterface/theme/accent_color = Color(0.337, 0.62, 1, 1)\ninterface/theme/contrast = 0.3\nasset_store/available_urls = {\n"Godot Asset Library": "https://godotengine.org/asset-library/api"\n}\ntext_editor/theme/color_theme = "Default"\n' \
        > "$CASA/.config/godot/editor_settings-4.7.tres" ;;
    firefox)
      no_disco org.mozilla.firefox
      mkdir -p "$CASA/.var/app/org.mozilla.firefox/.mozilla/firefox/abc.default"
      printf '[Profile0]\nName=default\nIsRelative=1\nPath=abc.default\nDefault=1\n' \
        > "$CASA/.var/app/org.mozilla.firefox/.mozilla/firefox/profiles.ini"
      printf 'user_pref("browser.startup.page", 3);\n' \
        > "$CASA/.var/app/org.mozilla.firefox/.mozilla/firefox/abc.default/user.js" ;;
  esac
}
mod() {
  env -i PATH="$BIN:$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" XDG_DATA_HOME="$CASA/.local/share" \
      XDG_CACHE_HOME="$CASA/.cache" FLATPAK_FAKE="$FAKE" \
      MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$T/estado" TMPDIR="$T" ${SECO:+MEOW_DRY_RUN=1} \
      PACK="$3" FLAVOR="$4" ACCENT=mauve NO_COLOR=1 \
      bash -c '. "$MEOW_RAIZ/scripts/lib/comum.sh" || exit 2
               . "$MEOW_RAIZ/scripts/temas-de-apps/$0/manifesto.sh" || exit 2
               meow_app_$1' "$1" "$2" </dev/null 2>&1
}
fundo() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["flavors"][sys.argv[2]]["base"].lstrip("#"))' \
    "$RAIZ/packs/$1/paleta.json" "$2"
}
csv() {
  python3 -c 'import sys; h=sys.argv[1]; print(",".join(str(int(h[i:i+2],16)) for i in (0,2,4)))' "$1"
}
com_cor() {
  { grep -rIil -- "$1" "$CASA" 2>/dev/null; grep -rIl -- "$(csv "$1")" "$CASA" 2>/dev/null; } \
    | grep -v -e '/.cache/' -e '/.local/state/' -e '/.config/meow/meow.conf$' | sort -u | wc -l
}
arquivos() { find "$CASA" -type f -not -path '*/.cache/*' -printf '%P %s %T@\n' 2>/dev/null | LC_ALL=C sort | sha256sum; }
mkdir -p "$T/packs"

for app in "${APPS[@]}"; do
  for par in "${PACKS[@]}"; do
    p="${par%%:*}"; f="${par#*:}"
    case "$p" in meowsystem) o=dracula:dracula ;; *) o=meowsystem:mocha ;; esac
    meu="$(fundo "$p" "$f")"; dele="$(fundo "${o%%:*}" "${o#*:}")"
    quem="$(python3 "$RAIZ/scripts/pack.py" app "$p" "apps.$app.arquivo" 2>/dev/null | sed -n 's/^pack=//p')"
    [ "$quem" = "$p" ] \
      && ok "$app/$p: o pack responde pelo próprio tema" \
      || falha "$app/$p: o tema não é do pack $p (responde: '${quem:-ninguém}')"
    semear "$app"
    saida="$(mod "$app" conferir "$p" "$f")"; rc=$?
    [ "$rc" = 1 ] && ok "$app/$p: antes de aplicar, o conferir acusa" \
      || falha "$app/$p: o conferir antes de aplicar devia dar 1 e deu $rc" "$saida"
    antes="$(arquivos)"
    SECO=1 mod "$app" aplicar "$p" "$f" >/dev/null
    [ "$antes" = "$(arquivos)" ] && ok "$app/$p: o ensaio seco não escreve nada" \
      || falha "$app/$p: o ensaio seco mexeu na casa"
    saida="$(mod "$app" aplicar "$p" "$f")"; rc=$?
    if [ "$rc" = 1 ] && [ "$(com_cor "$meu")" -gt 0 ] && [ "$(com_cor "$dele")" = 0 ]; then
      ok "$app/$p: o aplicar veste a cor do $p (#$meu) e nenhuma do outro"
    else
      falha "$app/$p: o aplicar não vestiu a cor do pack (rc=$rc, #$meu em $(com_cor "$meu"), #$dele em $(com_cor "$dele"))" "$saida"
    fi
    antes="$(arquivos)"
    saida="$(mod "$app" aplicar "$p" "$f")"; rc=$?
    if [ "$rc" = 0 ] && [ "$antes" = "$(arquivos)" ]; then
      ok "$app/$p: a segunda passada fica quieta e não escreve"
    else
      falha "$app/$p: a segunda passada não ficou quieta (rc=$rc)" "$saida"
    fi
    saida="$(mod "$app" conferir "$p" "$f")"; rc=$?
    [ "$rc" = 0 ] && ok "$app/$p: depois de aplicar, o conferir fecha" \
      || falha "$app/$p: o conferir depois de aplicar devia dar 0 e deu $rc" "$saida"
  done
  semear "$app"
  mod "$app" aplicar meowsystem mocha >/dev/null
  saida="$(mod "$app" aplicar dracula dracula)"; rc1=$?
  d1="$(com_cor "$(fundo dracula dracula)")"; m1="$(com_cor "$(fundo meowsystem mocha)")"
  saida="$saida$(mod "$app" aplicar meowsystem mocha)"; rc2=$?
  d2="$(com_cor "$(fundo dracula dracula)")"; m2="$(com_cor "$(fundo meowsystem mocha)")"
  if [ "$rc1" = 1 ] && [ "$d1" -gt 0 ] && [ "$m1" = 0 ] && [ "$rc2" = 1 ] && [ "$m2" -gt 0 ] && [ "$d2" = 0 ]; then
    ok "$app: a ida e volta de pack troca o tema junto"
  else
    falha "$app: a ida e volta não trocou o tema (rc $rc1/$rc2; dracula $d1/$d2, meowsystem $m1/$m2)" "$saida"
  fi
  saida="$(mod "$app" reverter meowsystem mocha)"; rc=$?
  if [ "$rc" = 1 ] && [ "$(com_cor "$(fundo meowsystem mocha)")" = 0 ]; then
    ok "$app: o reverter tira o que pôs"
  else
    falha "$app: o reverter não tirou o tema (rc=$rc, ainda em $(com_cor "$(fundo meowsystem mocha)") arquivo(s))" "$saida"
  fi
  saida="$(mod "$app" reverter meowsystem mocha)"; rc=$?
  [ "$rc" = 0 ] && ok "$app: o segundo reverter fica quieto" \
    || falha "$app: o segundo reverter devia dar 0 e deu $rc" "$saida"
done

semear libadwaita
mod libadwaita aplicar meowsystem mocha >/dev/null
GTK="$CASA/.var/app"
if [ -f "$GTK/com.github.rafostar.Clapper/config/gtk-4.0/gtk.css" ] \
   && [ -f "$GTK/be.alexandervanhee.gradia/config/gtk-4.0/gtk.css" ] \
   && [ ! -e "$GTK/org.bleachbit.BleachBit/config/gtk-4.0/gtk.css" ]; then
  ok "libadwaita: só o app que usa libadwaita ganha gtk.css"
else
  falha "libadwaita: o gtk.css foi parar no app errado (ou faltou em um libadwaita)"
fi
if grep -q 'initialstate' "$GTK/com.github.rafostar.Clapper/config/gtk-4.0/gtk.css" \
   && ! grep -q 'initialstate' "$GTK/be.alexandervanhee.gradia/config/gtk-4.0/gtk.css"; then
  ok "libadwaita: o ajuste do Clapper entra só no Clapper"
else
  falha "libadwaita: o ajuste por app não entrou onde devia"
fi

semear libadwaita
mkdir -p "$GTK/be.alexandervanhee.gradia/config/gtk-4.0"
printf '/* meu css */\nwindow { color: red; }\n' > "$GTK/be.alexandervanhee.gradia/config/gtk-4.0/gtk.css"
dele="$GTK/be.alexandervanhee.gradia/config/gtk-4.0/gtk.css"
antes="$(cat "$dele")"
saida="$(mod libadwaita aplicar meowsystem mocha)"; rc1=$?
saida="$saida$(mod libadwaita aplicar meowsystem mocha)"; rc2=$?
if [ "$rc1" = 1 ] && [ "$rc2" = 3 ] && [ -f "$GTK/com.github.rafostar.Clapper/config/gtk-4.0/gtk.css" ]; then
  ok "libadwaita: com um gtk.css dela no meio, o resto é vestido e o aviso (3) não some"
else
  falha "libadwaita: com gtk.css alheio devia dar 1 e depois 3 (deu $rc1 e $rc2)" "$saida"
fi
mod libadwaita reverter meowsystem mocha >/dev/null
if [ "$antes" = "$(cat "$dele")" ] && [ ! -e "$GTK/com.github.rafostar.Clapper/config/gtk-4.0/gtk.css" ]; then
  ok "libadwaita: o gtk.css dela nunca é sobrescrito nem apagado, e o do MeowSystem sai"
else
  falha "libadwaita: o gtk.css dela foi tocado, ou o do MeowSystem ficou"
fi

semear krita
KR="$CASA/.var/app/org.kde.krita"
mod krita aplicar meowsystem mocha >/dev/null
if grep -qx 'first_run=false' "$KR/config/kritarc" && grep -qx 'Theme=MeowSystem' "$KR/config/kritarc" \
   && [ -f "$KR/data/krita/color-schemes/MeowSystem.colors" ]; then
  ok "krita: o esquema entra, o kritarc ganha o Theme e guarda o resto"
else
  falha "krita: o kritarc ou o esquema não ficaram como o esperado"
fi
mod krita reverter meowsystem mocha >/dev/null
if grep -qx 'first_run=false' "$KR/config/kritarc" && ! grep -q 'Theme=' "$KR/config/kritarc" \
   && [ ! -e "$KR/data/krita/color-schemes/MeowSystem.colors" ]; then
  ok "krita: o reverter tira o Theme e o esquema, e o resto do kritarc fica"
else
  falha "krita: o reverter deixou resto ou levou o que não era dele"
fi
semear krita
printf '[theme]\nTheme=Krita dark\n' >> "$KR/config/kritarc"
mod krita aplicar meowsystem mocha >/dev/null
saida="$(mod krita aplicar meowsystem mocha)"; rc=$?
if [ "$rc" = 3 ] && grep -qx 'Theme=Krita dark' "$KR/config/kritarc"; then
  ok "krita: o tema que ela escolheu à mão não é trocado (3)"
else
  falha "krita: o Theme dela foi trocado ou o rc não foi 3 (rc=$rc)" "$saida"
fi

semear obs
OB="$CASA/.var/app/com.obsproject.Studio/config/obs-studio"
mod obs aplicar meowsystem mocha >/dev/null
if grep -qx 'Language=pt-BR' "$OB/user.ini" && grep -qx 'Theme=com.obsproject.Yami.MeowSystem' "$OB/user.ini" \
   && grep -q "dark: 'true'" "$OB/themes/MeowSystem.ovt"; then
  ok "obs: o tema escuro entra como dark true e o user.ini guarda o resto"
else
  falha "obs: o user.ini ou o .ovt não ficaram como o esperado"
fi
python3 - "$RAIZ/packs/dracula/paleta.json" <<'PY' && claro=sim || claro=nao
import json, sys
sys.exit(0 if "alucard" in (json.load(open(sys.argv[1])).get("claros") or []) else 1)
PY
if [ "$claro" = sim ]; then
  mod obs aplicar dracula alucard >/dev/null
  grep -q "dark: 'false'" "$OB/themes/MeowSystem.ovt" \
    && ok "obs: o flavor claro vira dark false" \
    || falha "obs: o flavor claro não virou dark false"
fi
mod obs reverter dracula alucard >/dev/null
if grep -qx 'Language=pt-BR' "$OB/user.ini" && ! grep -q 'Theme=' "$OB/user.ini" && [ ! -e "$OB/themes/MeowSystem.ovt" ]; then
  ok "obs: o reverter tira o Theme e o .ovt e guarda o resto"
else
  falha "obs: o reverter deixou resto ou levou o que não era dele"
fi

semear firefox
FF="$CASA/.var/app/org.mozilla.firefox/.mozilla/firefox/abc.default"
mod firefox aplicar dracula dracula >/dev/null
if grep -q 'browser.startup.page' "$FF/user.js" && grep -q 'legacyUserProfileCustomizations.stylesheets", true' "$FF/user.js" \
   && [ -f "$FF/chrome/userChrome.css" ]; then
  ok "firefox: o userChrome entra, o user.js liga a preferência e guarda a dele"
else
  falha "firefox: o perfil não ficou como o esperado"
fi
mod firefox reverter dracula dracula >/dev/null
if grep -q 'browser.startup.page' "$FF/user.js" && ! grep -q 'legacyUserProfileCustomizations' "$FF/user.js" \
   && [ ! -e "$FF/chrome/userChrome.css" ]; then
  ok "firefox: o reverter tira a linha dele e o userChrome e guarda o resto do user.js"
else
  falha "firefox: o reverter deixou resto ou levou o que não era dele"
fi
semear firefox
rm -rf "$CASA/.var/app/org.mozilla.firefox/.mozilla/firefox/profiles.ini"
saida="$(mod firefox aplicar meowsystem mocha)"; rc=$?
[ "$rc" = 3 ] && ok "firefox: sem profiles.ini o módulo se pula (3)" \
  || falha "firefox: sem profiles.ini devia dar 3 e deu $rc" "$saida"

semear firefox
rm -rf "$CASA/.var"
printf '#!/bin/sh\nexit 0\n' > "$BIN/firefox"; chmod +x "$BIN/firefox"
FA="$CASA/.mozilla/firefox"; mkdir -p "$FA/xyz.default"
printf '[Profile0]\nName=default\nIsRelative=1\nPath=xyz.default\nDefault=1\n' > "$FA/profiles.ini"
mod firefox aplicar dracula dracula >/dev/null
if grep -q 'legacyUserProfileCustomizations.stylesheets", true' "$FA/xyz.default/user.js" && [ -s "$FA/xyz.default/chrome/userChrome.css" ]; then
  ok "firefox: o perfil do apt em ~/.mozilla/firefox recebe o userChrome e a preferência"
else
  falha "firefox: o perfil do apt não ficou como o esperado"
fi
mod firefox reverter dracula dracula >/dev/null
[ ! -e "$FA/xyz.default/chrome/userChrome.css" ] && [ ! -e "$FA/xyz.default/user.js" ] \
  && ok "firefox: o reverter limpa o perfil do apt" \
  || falha "firefox: o reverter deixou resto no perfil do apt"
rm -f "$BIN/firefox"

semear libadwaita
OV="$CASA/.local/share/flatpak/overrides"; mkdir -p "$OV"
printf '[Context]\nfilesystems=xdg-config/gtk-3.0:ro;xdg-config/gtk-4.0:ro;xdg-data/icons:ro;/usr/share/themes:ro;\n\n[Environment]\nICON_THEME=MeowSystem-Icons\nGTK_THEME=adw-gtk3-dark\n' > "$OV/global"
trocar_pack() {
  env -i PATH="$BIN:$PATH" HOME="$CASA" XDG_CACHE_HOME="$CASA/.cache" FLATPAK_FAKE="$FAKE" MEOW_RAIZ="$RAIZ" \
      MEOW_ESTADO="$T/estado" TMPDIR="$T" FLATPAK_USER_DIR="$CASA/.local/share/flatpak" FLATPAK_SYSTEM_DIR="$T/sistema" \
      FLATPAK_TEMA_SISTEMA="$T/sistema" NOME_TEMA_ICONES=nenhum PACK="$1" FLAVOR="$2" ACCENT=mauve NO_COLOR=1 \
      bash -c '"$MEOW_RAIZ/scripts/flatpak_tema.sh" aplicar tudo; APPS_ATIVOS=libadwaita "$MEOW_RAIZ/scripts/aplicar_apps.sh" aplicar' </dev/null >/dev/null 2>&1
}
CSS="$GTK/be.alexandervanhee.gradia/config/gtk-4.0/gtk.css"
trocar_pack meowsystem mocha
c1="$(grep -ci "$(fundo meowsystem mocha)" "$CSS" 2>/dev/null)"
trocar_pack dracula dracula
c2="$(grep -ci "$(fundo dracula dracula)" "$CSS" 2>/dev/null)"; c3="$(grep -ci "$(fundo meowsystem mocha)" "$CSS" 2>/dev/null)"
trocar_pack meowsystem mocha
c4="$(grep -ci "$(fundo meowsystem mocha)" "$CSS" 2>/dev/null)"
if [ "${c1:-0}" -gt 0 ] && [ "${c2:-0}" -gt 0 ] && [ "${c3:-0}" = 0 ] && [ "${c4:-0}" -gt 0 ] \
   && ! grep -q 'GTK_THEME' "$OV/global" && ! grep -qE 'gtk-4\.0|xdg-data/icons|/usr/share/themes' "$OV/global" \
   && grep -q 'xdg-config/gtk-3.0:ro' "$OV/global"; then
  ok "libadwaita: trocar de pack pelo flatpak_tema.sh e pelo aplicar_apps.sh reescreve o gtk.css e o GTK_THEME não volta"
else
  falha "libadwaita: a troca de pack não reescreveu o gtk.css ou trouxe o GTK_THEME de volta (mocha $c1, dracula $c2, mocha na volta $c4)" "$(cat "$OV/global" 2>/dev/null)"
fi

for app in "${APPS[@]}"; do
  rm -rf "$CASA" "$FAKE"; mkdir -p "$CASA" "$FAKE/apps"
  saida="$(mod "$app" aplicar meowsystem mocha)"; rc=$?
  [ "$rc" = 3 ] && [ -z "$(find "$CASA" -type f -not -path '*/.cache/*')" ] \
    && ok "$app: sem o programa o módulo se pula (3) e não escreve" \
    || falha "$app: sem o programa devia pular com 3 e sem escrever (rc=$rc)" "$saida"
done

printf '\n'
semear godot
GD="$CASA/.config/godot"
mod godot aplicar meowsystem mocha >/dev/null
if grep -qx 'interface/theme/preset = "Custom"' "$GD/editor_settings-4.4.tres" \
   && grep -qx 'interface/theme/color_preset = "Custom"' "$GD/editor_settings-4.7.tres" \
   && ! grep -q '^interface/theme/preset' "$GD/editor_settings-4.7.tres" \
   && ! grep -q 'color_preset' "$GD/editor_settings-4.4.tres"; then
  ok "godot: a chave do preset segue a versão do arquivo (preset até o 4.5, color_preset desde o 4.6)"
else
  falha "godot: a chave do preset não seguiu a versão do arquivo" "$(cat "$GD"/editor_settings-4.*.tres)"
fi
if grep -qx 'interface/theme/base_color = Color(0.117647, 0.117647, 0.180392, 1)' "$GD/editor_settings-4.4.tres" \
   && grep -qx 'interface/theme/base_color = Color(0.117647, 0.117647, 0.180392, 1)' "$GD/editor_settings-4.7.tres" \
   && grep -qx 'interface/theme/contrast = 0.3' "$GD/editor_settings-4.7.tres" \
   && grep -qx 'text_editor/theme/color_theme = "MeowSystem"' "$GD/editor_settings-4.4.tres" \
   && grep -qx 'text_editor/theme/color_theme = "MeowSystem"' "$GD/editor_settings-4.7.tres" \
   && [ "$(grep -c '^interface/theme/base_color' "$GD/editor_settings-4.7.tres")" = 1 ]; then
  ok "godot: a base do mocha entra em Color de 0 a 1 nos dois arquivos, sem chave repetida"
else
  falha "godot: as cores do mocha não entraram como esperado" "$(cat "$GD"/editor_settings-4.*.tres)"
fi
if grep -qx 'interface/editor/display_scale = 3' "$GD/editor_settings-4.4.tres" \
   && grep -q 'InputEventKey_lde7y' "$GD/editor_settings-4.4.tres" \
   && grep -qx '"Godot Asset Library": "https://godotengine.org/asset-library/api"' "$GD/editor_settings-4.7.tres" \
   && grep -q '^\[resource\]$' "$GD/editor_settings-4.7.tres"; then
  ok "godot: o resto do editor_settings fica como o Godot deixou"
else
  falha "godot: o aplicar mexeu no que não era dele" "$(cat "$GD"/editor_settings-4.*.tres)"
fi
if grep -q 'symbol_color="#89DCEB"' "$GD/text_editor_themes/MeowSystem.tet" \
   && grep -q 'selection_color="#9399B240"' "$GD/text_editor_themes/MeowSystem.tet" \
   && head -n 1 "$GD/text_editor_themes/MeowSystem.tet" | grep -qx '; meowsystem-tema: meowsystem/mocha'; then
  ok "godot: o tema do editor de texto sai da paleta, com alfa onde o molde pede"
else
  falha "godot: o MeowSystem.tet não saiu como o esperado" "$(head -n 12 "$GD/text_editor_themes/MeowSystem.tet" 2>&1)"
fi
sed -i 's/Color(0.117647, 0.117647, 0.180392, 1)/Color(0.118, 0.118, 0.18, 1)/' "$GD/editor_settings-4.7.tres"
antes="$(arquivos)"
saida="$(mod godot aplicar meowsystem mocha)"; rc=$?
if [ "$rc" = 0 ] && [ "$antes" = "$(arquivos)" ]; then
  ok "godot: o Godot que reescreve a cor com três casas não reabre o aplicar"
else
  falha "godot: a cor arredondada pelo Godot foi tratada como diferente (rc=$rc)" "$saida"
fi
mod godot aplicar meowsystem latte >/dev/null
if grep -qx 'interface/theme/contrast = -0.06' "$GD/editor_settings-4.4.tres" \
   && grep -qx 'interface/theme/base_color = Color(0.937255, 0.945098, 0.960784, 1)' "$GD/editor_settings-4.7.tres" \
   && grep -q 'tipo="light"' "$GD/text_editor_themes/MeowSystem.tet"; then
  ok "godot: o flavor claro troca a base, vira contraste negativo e mantém o preset Custom"
else
  falha "godot: a troca para o latte não saiu como o esperado" "$(cat "$GD"/editor_settings-4.4.tres)"
fi
mod godot reverter meowsystem latte >/dev/null
if ! grep -q 'preset\|color_theme' "$GD/editor_settings-4.4.tres" "$GD/editor_settings-4.7.tres" \
   && grep -qx 'interface/editor/display_scale = 3' "$GD/editor_settings-4.4.tres" \
   && [ ! -e "$GD/text_editor_themes/MeowSystem.tet" ] && [ ! -d "$GD/text_editor_themes" ]; then
  ok "godot: o reverter tira o preset, as cores, o color_theme e o .tet e guarda o resto"
else
  falha "godot: o reverter deixou resto ou levou o que não era dele" "$(cat "$GD"/editor_settings-4.4.tres; ls -R "$GD")"
fi

semear godot
sed -i 's/^interface\/theme\/color_preset = .*/interface\/theme\/color_preset = "Light"/' "$GD/editor_settings-4.7.tres"
saida="$(mod godot aplicar meowsystem mocha)"; rc=$?
if [ "$rc" = 1 ] && grep -qx 'interface/theme/color_preset = "Light"' "$GD/editor_settings-4.7.tres" \
   && grep -qx 'interface/theme/base_color = Color(0.161, 0.161, 0.161, 1)' "$GD/editor_settings-4.7.tres" \
   && grep -qx 'text_editor/theme/color_theme = "MeowSystem"' "$GD/editor_settings-4.7.tres" \
   && grep -qx 'interface/theme/preset = "Custom"' "$GD/editor_settings-4.4.tres"; then
  ok "godot: o preset que ela escolheu à mão fica como está e o outro arquivo é vestido"
else
  falha "godot: o preset Light dela foi trocado, ou o outro arquivo não foi vestido (rc=$rc)" "$saida"
fi
sed -i 's/^text_editor\/theme\/color_theme = .*/text_editor\/theme\/color_theme = "Godot 2"/' "$GD/editor_settings-4.4.tres"
saida="$(mod godot aplicar meowsystem mocha)"; rc=$?
[ "$rc" = 3 ] && grep -qx 'text_editor/theme/color_theme = "Godot 2"' "$GD/editor_settings-4.4.tres" \
  && ok "godot: o tema de texto que ela escolheu à mão não é trocado, e o aviso (3) não some" \
  || falha "godot: o tema de texto dela foi trocado ou o rc não foi 3 (rc=$rc)" "$saida"
mod godot reverter meowsystem mocha >/dev/null
grep -qx 'interface/theme/color_preset = "Light"' "$GD/editor_settings-4.7.tres" \
  && grep -qx 'text_editor/theme/color_theme = "Godot 2"' "$GD/editor_settings-4.4.tres" \
  && ok "godot: o reverter nunca apaga a escolha dela" \
  || falha "godot: o reverter apagou a escolha dela"

semear godot
mkdir -p "$GD/text_editor_themes"
printf '[color_theme]\nsymbol_color="#010203"\n' > "$GD/text_editor_themes/MeowSystem.tet"
antes="$(arquivos)"
saida="$(mod godot aplicar meowsystem mocha)"; rc=$?
if [ "$rc" = 3 ] && [ "$antes" = "$(arquivos)" ]; then
  ok "godot: um MeowSystem.tet dela, sem a marca, não é sobrescrito e nada é ligado a ele"
else
  falha "godot: o MeowSystem.tet dela foi tocado ou o editor_settings mudou (rc=$rc)" "$saida"
fi

semear godot
rm -rf "$GD"
antes="$(arquivos)"
saida="$(mod godot aplicar meowsystem mocha)"; rc=$?
if [ "$rc" = 3 ] && [ "$antes" = "$(arquivos)" ] && ! printf '%s' "$saida" | grep -qi 'erro\|falhou'; then
  ok "godot: sem configuração do editor o módulo se pula (3) sem escrever nem acusar erro"
else
  falha "godot: sem configuração devia dar 3 sem escrever (rc=$rc)" "$saida"
fi
saida="$(mod godot reverter meowsystem mocha)"; rc=$?
[ "$rc" = 0 ] && ok "godot: o reverter sem configuração não tem o que desfazer (0)" \
  || falha "godot: o reverter sem configuração devia dar 0 e deu $rc" "$saida"

semear godot
mkdir -p "$CASA/.var/app/org.godotengine.Godot/config/godot"
cp "$GD/editor_settings-4.4.tres" "$CASA/.var/app/org.godotengine.Godot/config/godot/"
mod godot aplicar dracula dracula >/dev/null
if grep -qx 'text_editor/theme/color_theme = "MeowSystem"' "$CASA/.var/app/org.godotengine.Godot/config/godot/editor_settings-4.4.tres" \
   && [ -f "$CASA/.var/app/org.godotengine.Godot/config/godot/text_editor_themes/MeowSystem.tet" ]; then
  ok "godot: o Godot em flatpak também recebe o tema, na pasta de configuração dele"
else
  falha "godot: a instalação em flatpak não foi vestida"
fi

semear godot
rm -f "$GD/editor_settings-4.4.tres" "$GD/editor_settings-4.7.tres"
printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\ninterface/editor/display_scale = 3\n' > "$GD/editor_settings-4.5.tres"
printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\ninterface/editor/display_scale = 3\n' > "$GD/editor_settings-4.6.tres"
mod godot aplicar meowsystem mocha >/dev/null
if grep -qx 'interface/theme/color_preset = "Custom"' "$GD/editor_settings-4.6.tres" \
   && ! grep -q '^interface/theme/preset' "$GD/editor_settings-4.6.tres" \
   && grep -qx 'interface/theme/preset = "Custom"' "$GD/editor_settings-4.5.tres" \
   && ! grep -q 'color_preset' "$GD/editor_settings-4.5.tres"; then
  ok "godot: sem chave de preset no arquivo, o 4.5 ganha preset e o 4.6 já ganha color_preset (o 4.6 apaga o preset ao abrir)"
else
  falha "godot: a chave do preset não seguiu a versão nos arquivos 4.5 e 4.6" "$(cat "$GD"/editor_settings-4.[56].tres)"
fi

semear gimp
GM="$CASA/.config/GIMP"
mod gimp aplicar meowsystem mocha >/dev/null
if grep -qx '@import url("file:///app/share/gimp/3.0/themes/Default/gimp-dark.css");' "$GM/3.2/themes/MeowSystem/gimp-dark.css" \
   && grep -qx '@define-color bg-color               #1E1E2E;' "$GM/3.2/themes/MeowSystem/gimp-dark.css" \
   && grep -qx '@define-color ruler-color            rgba(17, 17, 27, 0.3);' "$GM/3.2/themes/MeowSystem/gimp-dark.css" \
   && ! grep -q 'escuro\|claro' "$GM/3.2/themes/MeowSystem/gimp-dark.css" \
   && [ ! -e "$GM/3.2/themes/MeowSystem/gimp-light.css" ] && [ -f "$GM/3.0/themes/MeowSystem/gimp-dark.css" ]; then
  ok "gimp: o tema escuro importa o Default escuro, traz só a seção escura e entra em cada pasta de versão"
else
  falha "gimp: o gimp-dark.css não saiu como o esperado" "$(cat "$GM/3.2/themes/MeowSystem/gimp-dark.css" 2>&1 | head -n 12)"
fi
if [ "$(cat "$GM/3.2/gimprc")" = '(theme "MeowSystem")' ] \
   && [ "$(cat "$GM/3.0/gimprc")" = "$(printf '(undo-levels 99)\n(theme "MeowSystem")')" ]; then
  ok "gimp: o gimprc ganha o (theme) e guarda o resto, e nasce quando não existia"
else
  falha "gimp: o gimprc não ficou como o esperado" "$(cat "$GM/3.2/gimprc" "$GM/3.0/gimprc" 2>&1)"
fi
mod gimp aplicar meowsystem latte >/dev/null
if [ -f "$GM/3.2/themes/MeowSystem/gimp-light.css" ] && [ ! -e "$GM/3.2/themes/MeowSystem/gimp-dark.css" ] \
   && grep -qx '@import url("file:///app/share/gimp/3.0/themes/Default/gimp-light.css");' "$GM/3.2/themes/MeowSystem/gimp-light.css" \
   && grep -qx '@define-color bg-color               #E6E9EF;' "$GM/3.2/themes/MeowSystem/gimp-light.css" \
   && [ "$(grep -c '^@define-color bg-color' "$GM/3.2/themes/MeowSystem/gimp-light.css")" = 1 ]; then
  ok "gimp: o flavor claro troca para gimp-light.css, com a seção clara, e tira o escuro que era dele"
else
  falha "gimp: a troca para o latte não saiu como o esperado" "$(ls "$GM/3.2/themes/MeowSystem")"
fi
mod gimp reverter meowsystem latte >/dev/null
if [ ! -e "$GM/3.2/themes/MeowSystem" ] && [ ! -e "$GM/3.2/gimprc" ] \
   && [ "$(cat "$GM/3.0/gimprc")" = '(undo-levels 99)' ] && [ -d "$GM/3.2/themes" ]; then
  ok "gimp: o reverter tira o tema e o (theme), apaga o gimprc que ele criou e guarda o resto do outro"
else
  falha "gimp: o reverter deixou resto ou levou o que não era dele" "$(find "$GM" -type f | sort)"
fi

semear gimp
printf '(theme "System")\n(undo-levels 99)\n' > "$GM/3.2/gimprc"
saida="$(mod gimp aplicar meowsystem mocha)"; rc1=$?
saida="$saida$(mod gimp aplicar meowsystem mocha)"; rc2=$?
if [ "$rc1" = 1 ] && [ "$rc2" = 3 ] && [ "$(cat "$GM/3.2/gimprc")" = "$(printf '(theme "System")\n(undo-levels 99)')" ]; then
  ok "gimp: o tema que ela escolheu à mão no gimprc não é trocado, e o aviso (3) não some"
else
  falha "gimp: o (theme) dela foi trocado ou os rc não foram 1 e 3 (deu $rc1 e $rc2)" "$saida"
fi
mod gimp reverter meowsystem mocha >/dev/null
[ "$(cat "$GM/3.2/gimprc")" = "$(printf '(theme "System")\n(undo-levels 99)')" ] \
  && ok "gimp: o reverter nunca apaga o tema dela" \
  || falha "gimp: o reverter mexeu no (theme) dela"

semear gimp
mkdir -p "$GM/3.2/themes/MeowSystem"
printf '* { color: red; }\n' > "$GM/3.2/themes/MeowSystem/gimp-dark.css"
antes="$(arquivos)"
saida="$(mod gimp aplicar meowsystem mocha)"; rc=$?
if [ "$rc" = 1 ] && [ "$(cat "$GM/3.2/themes/MeowSystem/gimp-dark.css")" = '* { color: red; }' ] \
   && [ ! -e "$GM/3.2/gimprc" ] && [ -f "$GM/3.0/themes/MeowSystem/gimp-dark.css" ]; then
  ok "gimp: um gimp-dark.css dela, sem a marca, não é sobrescrito e o gimprc não aponta para ele"
else
  falha "gimp: o tema dela foi tocado ou o gimprc passou a apontar para ele (rc=$rc)" "$saida"
fi

semear gimp
rm -rf "$GM"
antes="$(arquivos)"
saida="$(mod gimp aplicar meowsystem mocha)"; rc=$?
if [ "$rc" = 3 ] && [ "$antes" = "$(arquivos)" ] && ! printf '%s' "$saida" | grep -qi 'erro\|falhou'; then
  ok "gimp: instalado mas sem pasta de versão o módulo se pula (3) sem escrever nem acusar erro"
else
  falha "gimp: sem pasta de configuração devia dar 3 sem escrever (rc=$rc)" "$saida"
fi
saida="$(mod gimp reverter meowsystem mocha)"; rc=$?
[ "$rc" = 0 ] && ok "gimp: o reverter sem pasta de configuração não tem o que desfazer (0)" \
  || falha "gimp: o reverter sem pasta de configuração devia dar 0 e deu $rc" "$saida"

semear gimp
mkdir -p "$CASA/.var/app/org.gimp.GIMP/config/GIMP/3.2"
mod gimp aplicar dracula dracula >/dev/null
if [ -f "$CASA/.var/app/org.gimp.GIMP/config/GIMP/3.2/themes/MeowSystem/gimp-dark.css" ] \
   && grep -qx '(theme "MeowSystem")' "$CASA/.var/app/org.gimp.GIMP/config/GIMP/3.2/gimprc"; then
  ok "gimp: a pasta de versão que o flatpak guarda em ~/.var também é vestida"
else
  falha "gimp: a pasta de ~/.var/app/org.gimp.GIMP não foi vestida"
fi

semear ghostwriter
GW="$CASA/.var/app/org.kde.ghostwriter"
mod ghostwriter aplicar meowsystem mocha >/dev/null
if grep -qx 'theme=MeowSystem' "$GW/config/kde.org/ghostwriter.conf" \
   && grep -qx 'darkModeEnabled=true' "$GW/config/kde.org/ghostwriter.conf" \
   && grep -qx 'locale=pt_BR' "$GW/config/kde.org/ghostwriter.conf" \
   && ! grep -q 'Classic Light' "$GW/config/kde.org/ghostwriter.conf" \
   && [ -f "$GW/data/ghostwriter/themes/MeowSystem.json" ]; then
  ok "ghostwriter: o Style/theme troca o padrão de fábrica pelo MeowSystem e o conf guarda o resto"
else
  falha "ghostwriter: o conf ou o tema não ficaram como o esperado" "$(cat "$GW/config/kde.org/ghostwriter.conf")"
fi
if python3 -I - "$GW/data/ghostwriter/themes/MeowSystem.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
chaves = {"foreground", "background", "selection", "cursor", "markup", "accent", "heading", "emphasis", "block", "link", "error"}
cores = {k: d.get(k) for k in chaves}
ok = all(isinstance(v, str) and len(v) == 7 and v[0] == "#" for v in cores.values())
sys.exit(0 if ok and d["background"] == "#1E1E2E" and d["foreground"] == "#CDD6F4" and "meowsystem-tema:" in d.get("origem", "") else 1)
PY
then
  ok "ghostwriter: o tema é um JSON plano com as 11 cores do ghostwriter, tiradas da paleta, e a marca do módulo"
else
  falha "ghostwriter: o MeowSystem.json não é o JSON esperado" "$(cat "$GW/data/ghostwriter/themes/MeowSystem.json")"
fi
mod ghostwriter aplicar dracula alucard >/dev/null
if grep -q '"background": "#F0F0F6"' "$GW/data/ghostwriter/themes/MeowSystem.json" && grep -qx 'theme=MeowSystem' "$GW/config/kde.org/ghostwriter.conf"; then
  ok "ghostwriter: a troca para o flavor claro reescreve o tema e mantém a escolha"
else
  falha "ghostwriter: a troca para o alucard não saiu como o esperado" "$(cat "$GW/data/ghostwriter/themes/MeowSystem.json")"
fi
mod ghostwriter reverter dracula alucard >/dev/null
if grep -qx 'darkModeEnabled=true' "$GW/config/kde.org/ghostwriter.conf" && ! grep -q 'theme=' "$GW/config/kde.org/ghostwriter.conf" \
   && [ ! -e "$GW/data/ghostwriter/themes/MeowSystem.json" ]; then
  ok "ghostwriter: o reverter tira o theme e o JSON e guarda o resto do conf"
else
  falha "ghostwriter: o reverter deixou resto ou levou o que não era dele" "$(cat "$GW/config/kde.org/ghostwriter.conf"; ls -R "$GW/data" 2>&1)"
fi

semear ghostwriter
sed -i 's/^theme=.*/theme=Plainstraction/' "$GW/config/kde.org/ghostwriter.conf"
saida="$(mod ghostwriter aplicar meowsystem mocha)"; rc1=$?
saida="$saida$(mod ghostwriter aplicar meowsystem mocha)"; rc2=$?
if [ "$rc1" = 1 ] && [ "$rc2" = 3 ] && grep -qx 'theme=Plainstraction' "$GW/config/kde.org/ghostwriter.conf" \
   && [ -f "$GW/data/ghostwriter/themes/MeowSystem.json" ]; then
  ok "ghostwriter: o tema que ela escolheu à mão não é trocado, e o aviso (3) não some"
else
  falha "ghostwriter: o tema dela foi trocado ou os rc não foram 1 e 3 (deu $rc1 e $rc2)" "$saida"
fi
mod ghostwriter reverter meowsystem mocha >/dev/null
grep -qx 'theme=Plainstraction' "$GW/config/kde.org/ghostwriter.conf" \
  && ok "ghostwriter: o reverter nunca apaga o tema dela" \
  || falha "ghostwriter: o reverter mexeu no tema dela"

semear ghostwriter
sed -i 's/^theme=.*/theme=Classic/' "$GW/config/kde.org/ghostwriter.conf"
mod ghostwriter aplicar meowsystem mocha >/dev/null
grep -qx 'theme=MeowSystem' "$GW/config/kde.org/ghostwriter.conf" \
  && ok "ghostwriter: o Classic, que o app grava sozinho no primeiro uso, não conta como escolha dela" \
  || falha "ghostwriter: o Classic foi tratado como escolha dela"

semear ghostwriter
printf '[General]\nlocale=pt_BR\n\n[Style]\ndarkModeEnabled=true\ninterfaceStyle=0\ntheme=Sem nome 1\n\n[style]\nshowUnbreakableSpace=false\n' \
  > "$GW/config/kde.org/ghostwriter.conf"
mkdir -p "$GW/data/ghostwriter/themes"
printf '{"dark": {"background": "#010203"}, "light": {"background": "#040506"}}\n' > "$GW/data/ghostwriter/themes/Sem nome 1.json"
conf_antes="$(cat "$GW/config/kde.org/ghostwriter.conf")"; dela_antes="$(cat "$GW/data/ghostwriter/themes/Sem nome 1.json")"
saida="$(mod ghostwriter aplicar meowsystem mocha)"; rc1=$?
saida="$saida$(mod ghostwriter reverter meowsystem mocha)"
if [ "$rc1" = 1 ] && [ "$conf_antes" = "$(cat "$GW/config/kde.org/ghostwriter.conf")" ] \
   && [ "$dela_antes" = "$(cat "$GW/data/ghostwriter/themes/Sem nome 1.json")" ] \
   && [ ! -e "$GW/data/ghostwriter/themes/MeowSystem.json" ]; then
  ok "ghostwriter: o tema dela com espaço no nome fica escolhido, o arquivo dela fica intacto, e o reverter devolve o conf como era"
else
  falha "ghostwriter: o tema dela ou o conf mudaram (rc=$rc1)" "$saida$(cat "$GW/config/kde.org/ghostwriter.conf")"
fi

semear ghostwriter
printf '[General]\nlocale=pt_BR\n\n[style]\nshowUnbreakableSpace=false\n' > "$GW/config/kde.org/ghostwriter.conf"
mod ghostwriter aplicar meowsystem mocha >/dev/null
secao="$(awk '/^\[/{s=$0} /^theme=/{print s}' "$GW/config/kde.org/ghostwriter.conf")"
if [ "$secao" = '[Style]' ] && [ "$(sed -n '/^\[style\]$/,/^\[/p' "$GW/config/kde.org/ghostwriter.conf" | grep -c '=')" = 1 ]; then
  ok "ghostwriter: o theme entra no [Style] maiúsculo e o [style] minúsculo, outra seção, fica só com o que tinha"
else
  falha "ghostwriter: o theme caiu na seção errada" "$(cat "$GW/config/kde.org/ghostwriter.conf")"
fi

semear ghostwriter
mkdir -p "$GW/data/ghostwriter/themes"
printf '{"foreground": "#010203", "background": "#040506"}\n' > "$GW/data/ghostwriter/themes/MeowSystem.json"
antes="$(arquivos)"
saida="$(mod ghostwriter aplicar meowsystem mocha)"; rc=$?
if [ "$rc" = 3 ] && [ "$antes" = "$(arquivos)" ]; then
  ok "ghostwriter: um MeowSystem.json dela, sem a marca, não é sobrescrito e o conf não aponta para ele"
else
  falha "ghostwriter: o JSON dela foi tocado ou o conf mudou (rc=$rc)" "$saida"
fi

semear ghostwriter
rm -rf "$GW"
saida="$(mod ghostwriter aplicar meowsystem mocha)"; rc=$?
if [ "$rc" = 1 ] && grep -qx 'theme=MeowSystem' "$GW/config/kde.org/ghostwriter.conf" && [ -f "$GW/data/ghostwriter/themes/MeowSystem.json" ]; then
  ok "ghostwriter: instalado e nunca aberto, o conf e o tema nascem do módulo"
else
  falha "ghostwriter: sem conf anterior o módulo não criou o conf e o tema (rc=$rc)" "$saida"
fi
mod ghostwriter reverter meowsystem mocha >/dev/null
[ ! -e "$GW/config/kde.org/ghostwriter.conf" ] && [ ! -e "$GW/data/ghostwriter/themes/MeowSystem.json" ] \
  && ok "ghostwriter: o reverter apaga o conf que o módulo criou" \
  || falha "ghostwriter: o reverter deixou o conf ou o tema que o módulo criou"

semear ghostwriter
rm -rf "$CASA/.var" "$CASA/.local/share/flatpak"
printf '#!/bin/sh\nexit 0\n' > "$BIN/ghostwriter"; chmod +x "$BIN/ghostwriter"
mod ghostwriter aplicar dracula dracula >/dev/null
if [ -f "$CASA/.local/share/ghostwriter/themes/MeowSystem.json" ] \
   && grep -qx 'theme=MeowSystem' "$CASA/.config/kde.org/ghostwriter.conf"; then
  ok "ghostwriter: o pacote nativo escreve em ~/.local/share/ghostwriter e ~/.config/kde.org"
else
  falha "ghostwriter: a instalação nativa não foi vestida"
fi
mod ghostwriter reverter dracula dracula >/dev/null
[ ! -e "$CASA/.local/share/ghostwriter/themes/MeowSystem.json" ] && [ ! -e "$CASA/.config/kde.org/ghostwriter.conf" ] \
  && ok "ghostwriter: o reverter nativo limpa o tema e o conf" \
  || falha "ghostwriter: o reverter nativo deixou resto"
rm -f "$BIN/ghostwriter"

if [ "$falhas" -gt 0 ]; then
  printf 'temas-por-app: %s falha(s)\n' "$falhas" >&2
  exit 1
fi
printf 'temas-por-app: tudo verde\n'

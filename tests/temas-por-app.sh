#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'FALHOU: sem python3\n' >&2; exit 1; }

APPS=(libadwaita krita obs waterfox)
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
  rm -f "$BIN/obs" "$BIN/krita" "$BIN/waterfox"
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
    waterfox)
      no_disco net.waterfox.waterfox
      mkdir -p "$CASA/.var/app/net.waterfox.waterfox/.waterfox/abc.default"
      printf '[Profile0]\nName=default\nIsRelative=1\nPath=abc.default\nDefault=1\n' \
        > "$CASA/.var/app/net.waterfox.waterfox/.waterfox/profiles.ini"
      printf 'user_pref("browser.startup.page", 3);\n' \
        > "$CASA/.var/app/net.waterfox.waterfox/.waterfox/abc.default/user.js" ;;
  esac
}
mod() {
  env -i PATH="$BIN:$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" XDG_DATA_HOME="$CASA/.local/share" \
      XDG_CACHE_HOME="$CASA/.cache" FLATPAK_FAKE="$FAKE" \
      MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$T/estado" TMPDIR="$T" ${SECO:+MEOW_DRY_RUN=1} \
      PACK="$3" FLAVOR="$4" ACCENT=mauve NO_COLOR=1 \
      bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 2
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
    | grep -v -e '/.cache/' -e '/.local/state/' | sort -u | wc -l
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

semear waterfox
WF="$CASA/.var/app/net.waterfox.waterfox/.waterfox/abc.default"
mod waterfox aplicar dracula dracula >/dev/null
if grep -q 'browser.startup.page' "$WF/user.js" && grep -q 'legacyUserProfileCustomizations.stylesheets", true' "$WF/user.js" \
   && [ -f "$WF/chrome/userChrome.css" ]; then
  ok "waterfox: o userChrome entra, o user.js liga a preferência e guarda a dele"
else
  falha "waterfox: o perfil não ficou como o esperado"
fi
mod waterfox reverter dracula dracula >/dev/null
if grep -q 'browser.startup.page' "$WF/user.js" && ! grep -q 'legacyUserProfileCustomizations' "$WF/user.js" \
   && [ ! -e "$WF/chrome/userChrome.css" ]; then
  ok "waterfox: o reverter tira a linha dele e o userChrome e guarda o resto do user.js"
else
  falha "waterfox: o reverter deixou resto ou levou o que não era dele"
fi
semear waterfox
rm -rf "$CASA/.var/app/net.waterfox.waterfox/.waterfox/profiles.ini"
saida="$(mod waterfox aplicar meowsystem mocha)"; rc=$?
[ "$rc" = 3 ] && ok "waterfox: sem profiles.ini o módulo se pula (3)" \
  || falha "waterfox: sem profiles.ini devia dar 3 e deu $rc" "$saida"

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
if [ "$falhas" -gt 0 ]; then
  printf 'temas-por-app: %s falha(s)\n' "$falhas" >&2
  exit 1
fi
printf 'temas-por-app: tudo verde\n'

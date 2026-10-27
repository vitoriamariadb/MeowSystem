#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'FALHOU: sem python3\n' >&2; exit 1; }

MODELOS=(kitty gnome-terminal telegram discord onlyoffice)
PACKS=(meowsystem:mocha dracula:dracula)

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
BIN="$T/bin"; CASA="$T/casa"; mkdir -p "$BIN"
falso() { printf '#!/bin/sh\nexit %s\n' "${2:-0}" > "$BIN/$1"; chmod +x "$BIN/$1"; }
for x in sudo pkexec su apt apt-get systemctl pkill; do
  printf '#!/bin/sh\necho "recusado: %s" >&2\nexit 1\n' "$x" > "$BIN/$x"; chmod +x "$BIN/$x"
done
falso pgrep 1; falso flatpak 0
cat > "$BIN/dconf" <<'DCONF'
#!/usr/bin/env python3
import os, sys
banco = os.path.join(os.environ["HOME"], ".dconf-de-mentira")
d = {}
if os.path.exists(banco):
    for l in open(banco, encoding="utf-8"):
        k, v = l.rstrip("\n").split("\t", 1)
        d[k] = v
def salvar():
    open(banco, "w", encoding="utf-8").write("".join(f"{k}\t{v}\n" for k, v in sorted(d.items())))
verbo = sys.argv[1]
if verbo == "read":
    if sys.argv[2] in d:
        print(d[sys.argv[2]])
elif verbo == "write":
    d[sys.argv[2]] = sys.argv[3]; salvar()
elif verbo == "reset":
    if sys.argv[2] == "-f":
        for k in [k for k in d if k.startswith(sys.argv[3])]:
            del d[k]
    else:
        d.pop(sys.argv[2], None)
    salvar()
elif verbo == "dump":
    p = sys.argv[2]
    ks = sorted(k for k in d if k.startswith(p) and "/" not in k[len(p):])
    if ks:
        print("[/]")
        for k in ks:
            print(f"{k[len(p):]}={d[k]}")
elif verbo == "load":
    for l in sys.stdin:
        l = l.rstrip("\n")
        if l and not l.startswith(("#", "[")):
            k, v = l.split("=", 1)
            d[sys.argv[2] + k] = v
    salvar()
else:
    sys.exit(1)
DCONF
chmod +x "$BIN/dconf"

implantar() {
  local a="$CASA/.local/share/flatpak/app/$1"
  mkdir -p "$a/x86_64/stable/0123abcd" && ln -sfn 0123abcd "$a/x86_64/stable/active" && ln -sfn x86_64/stable "$a/current"
}
semear() {
  rm -rf "$CASA" "$T/estado"; mkdir -p "$CASA/.config"
  rm -f "$BIN/kitty" "$BIN/gnome-terminal" "$BIN/spicetify"
  case "$1" in
    kitty) falso kitty ;;
    gnome-terminal) falso gnome-terminal ;;
    telegram) implantar org.telegram.desktop ;;
    discord) implantar com.discordapp.Discord; mkdir -p "$CASA/.config/Vencord/themes" ;;
    onlyoffice)
      implantar org.onlyoffice.desktopeditors
      local oo="$CASA/.var/app/org.onlyoffice.desktopeditors"
      mkdir -p "$oo/config/onlyoffice" "$oo/data/onlyoffice/desktopeditors/uithemes"
      printf '[General]\nUITheme=theme-dark\n' > "$oo/config/onlyoffice/DesktopEditors.conf" ;;
    qbittorrent)
      implantar org.qbittorrent.qBittorrent
      mkdir -p "$CASA/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent"
      printf '[Preferences]\n' > "$CASA/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent/qBittorrent.conf" ;;
    spotify)
      implantar com.spotify.Client
      mkdir -p "$CASA/.local/share/flatpak/app/com.spotify.Client/current/active/files/extra/share/spotify/Apps/xpui" \
               "$CASA/.config/spicetify/Themes/catppuccin"
      printf '[mocha]\ntext = cdd6f4\nbutton-active = 9399b2\nmauve = cba6f7\nbase = 1e1e2e\n' \
        > "$CASA/.config/spicetify/Themes/catppuccin/color.ini"
      cat > "$BIN/spicetify" <<'SPI'
#!/bin/sh
ini="$HOME/.config/spicetify/config-xpui.ini"
if [ "$1" = config ] && [ -n "$3" ]; then
  [ -f "$ini" ] || printf '[Setting]\n' > "$ini"
  grep -v "^$2 *=" "$ini" > "$ini.n"; printf '%s = %s\n' "$2" "$3" >> "$ini.n"; mv "$ini.n" "$ini"
fi
exit 0
SPI
      chmod +x "$BIN/spicetify" ;;
  esac
}
mod() {
  env -i PATH="$BIN:$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" XDG_DATA_HOME="$CASA/.local/share" \
      MEOW_PACKS="$T/packs" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$T/estado" TMPDIR="$T" \
      PACK="$3" FLAVOR="$4" ACCENT=mauve NO_COLOR=1 \
      bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 2
               . "$MEOW_RAIZ/scripts/temas-de-apps/$0/manifesto.sh" || exit 2
               meow_app_$1' "$1" "$2" </dev/null 2>&1
}
fundo() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["flavors"][sys.argv[2]]["base"].lstrip("#"))' \
    "$RAIZ/packs/$1/paleta.json" "$2"
}
com_cor() { grep -rIil -- "$1" "$CASA" 2>/dev/null | grep -v '/.local/state/' | wc -l; }
mkdir -p "$T/packs"

for app in "${MODELOS[@]}"; do
  for par in "${PACKS[@]}"; do
    p="${par%%:*}"; f="${par#*:}"
    case "$p" in meowsystem) o=dracula:dracula ;; *) o=meowsystem:mocha ;; esac
    meu="$(fundo "$p" "$f")"; dele="$(fundo "${o%%:*}" "${o#*:}")"
    quem="$(python3 "$RAIZ/scripts/pack.py" app "$p" "apps.$app.arquivo" 2>/dev/null | sed -n 's/^pack=//p')"
    [ "$quem" = "$p" ] \
      && ok "$app/$p: o pack responde pelo próprio tema" \
      || falha "$app/$p: o tema não é do pack $p (responde: '${quem:-ninguém}')"
    semear "$app"
    saida="$(mod "$app" aplicar "$p" "$f")"; rc=$?
    if [ "$rc" = 1 ] && [ "$(com_cor "$meu")" -gt 0 ] && [ "$(com_cor "$dele")" = 0 ]; then
      ok "$app/$p: o aplicar veste a cor do $p (#$meu) e nenhuma do outro"
    else
      falha "$app/$p: o aplicar não vestiu a cor do pack (rc=$rc, #$meu em $(com_cor "$meu"), #$dele em $(com_cor "$dele"))" "$saida"
    fi
    saida="$(mod "$app" aplicar "$p" "$f")"; rc=$?
    [ "$rc" = 0 ] && ok "$app/$p: a segunda passada fica quieta" \
      || falha "$app/$p: a segunda passada não ficou quieta (rc=$rc)" "$saida"
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
done

printf '#!/bin/sh\nexit 22\n' > "$BIN/curl"; chmod +x "$BIN/curl"
spot() {
  env -i PATH="$BIN:$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" XDG_DATA_HOME="$CASA/.local/share" \
      MEOW_PACKS="$T/packs" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$T/estado" TMPDIR="$T" \
      PACK="$1" FLAVOR="$2" ACCENT=mauve NO_COLOR=1 \
      bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 2
               . "$MEOW_RAIZ/scripts/temas-de-apps/spotify/manifesto.sh" || exit 2
               _spot_tema_baixar; printf "rc=%s\n" "$?"' </dev/null 2>&1
}
secao() {
  awk -v s="[$2]" '$0 == s { d = 1; next } /^\[/ { d = 0 } d' "$1" 2>/dev/null
}
for par in "${PACKS[@]}"; do
  p="${par%%:*}"; f="${par#*:}"
  quem="$(python3 "$RAIZ/scripts/pack.py" app "$p" apps.spotify.spicetify_tema 2>/dev/null | sed -n 's/^pack=//p')"
  [ "$quem" = "$p" ] && ok "spotify/$p: o pack responde pelo próprio tema" \
    || falha "spotify/$p: o tema não é do pack $p (responde: '${quem:-ninguém}')"
  fonte="$(python3 "$RAIZ/scripts/pack.py" app "$p" apps.spotify.arquivo 2>/dev/null | sed -n 's/^valor=//p')"
  repo="$(python3 "$RAIZ/scripts/pack.py" app "$p" apps.spotify.origem.commit 2>/dev/null | sed -n 's/^valor=//p')"
  [ -n "$fonte$repo" ] && ok "spotify/$p: o pack diz de onde o tema vem (arte no pack ou origem pinada)" \
    || falha "spotify/$p: o pack pede um tema do spicetify e não diz de onde ele vem"
done
semear spotify
saida="$(spot dracula dracula)"
SLEEK="$CASA/.config/spicetify/Themes/Sleek"
cores="$(secao "$SLEEK/color.ini" Dracula)"
if printf '%s' "$saida" | grep -qx 'rc=1' && cmp -s "$SLEEK/color.ini" "$RAIZ/packs/dracula/temas-de-apps/spotify/Sleek/color.ini" \
   && printf '%s' "$cores" | grep -qi "$(fundo dracula dracula)" && ! printf '%s' "$cores" | grep -qi "$(fundo meowsystem mocha)"; then
  ok "spotify/dracula: sem rede, o Sleek sai da pasta do pack, e a seção Dracula tem a cor dele"
else
  falha "spotify/dracula: o tema do spicetify não saiu do pack" "$saida"
fi
saida="$(spot dracula dracula)"
printf '%s' "$saida" | grep -qx 'rc=0' && ok "spotify/dracula: a segunda passada fica quieta" \
  || falha "spotify/dracula: a segunda passada não ficou quieta" "$saida"
rm -rf "$CASA/.config/spicetify/Themes"
saida="$(spot meowsystem mocha)"
CAT="$CASA/.config/spicetify/Themes/catppuccin"
if printf '%s' "$saida" | grep -qx 'rc=1' \
   && ( cd "$RAIZ/packs/meowsystem/temas-de-apps/spotify" && sha256sum --status -c SHA256SUMS ) \
   && ( cd "$CASA/.config/spicetify/Themes" && sha256sum --status -c "$RAIZ/packs/meowsystem/temas-de-apps/spotify/SHA256SUMS" ) \
   && [ -f "$CAT/theme.js" ] && [ -f "$CAT/user.css" ] && [ -d "$CAT/assets/mocha" ]; then
  ok "spotify/meowsystem: sem rede, o catppuccin sai inteiro da pasta do pack"
else
  falha "spotify/meowsystem: o tema do spicetify não saiu do pack" "$saida"
fi

QBC="$CASA/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent/qBittorrent.conf"
SPI_INI="$CASA/.config/spicetify/config-xpui.ini"
no_ar() {
  case "$1" in
    qbittorrent) sed -n 's/^General\\CustomUIThemePath=.*\/themes\///p' "$QBC" 2>/dev/null ;;
    spotify) sed -n 's/^current_theme *= *//p' "$SPI_INI" 2>/dev/null ;;
  esac
}
quero() {
  case "$1" in
    qbittorrent) basename "$(python3 "$RAIZ/scripts/pack.py" app "$2" apps.qbittorrent.arquivo 2>/dev/null | sed -n 's/^valor=//p')" ;;
    spotify) python3 "$RAIZ/scripts/pack.py" app "$2" apps.spotify.spicetify_tema 2>/dev/null | sed -n 's/^valor=//p' ;;
  esac
}
for app in qbittorrent spotify; do
  semear "$app"
  r=""; log=""
  for par in meowsystem:mocha dracula:dracula meowsystem:mocha; do
    p="${par%%:*}"
    saida="$(mod "$app" aplicar "$p" "${par#*:}")"; rc=$?
    log+="$saida"$'\n'
    [ "$(no_ar "$app")" = "$(quero "$app" "$p")" ] && r+=" $p:$rc" || r+=" $p:$rc:$(no_ar "$app")"
  done
  if [ "$r" = " meowsystem:1 dracula:1 meowsystem:1" ]; then
    ok "$app: a ida e volta de pack troca o tema que o MeowSystem pôs, sem perguntar"
  else
    falha "$app: a ida e volta de pack não trocou o tema ($r )" "$(printf '%s' "$log" | tail -n 8)"
  fi
  case "$app" in
    qbittorrent) printf '[Preferences]\nGeneral\\CustomUIThemePath=%s/themes/dela.qbtheme\nGeneral\\UseCustomUITheme=true\n' \
                   "$(dirname "$QBC")" > "$QBC" ;;
    spotify) mkdir -p "$CASA/.config/spicetify/Themes/Dela"
             printf '[x]\n' > "$CASA/.config/spicetify/Themes/Dela/color.ini"
             printf '[Setting]\ncurrent_theme = Dela\ncolor_scheme = x\n' > "$SPI_INI" ;;
  esac
  saida="$(mod "$app" aplicar dracula dracula)"; rc=$?
  case "$app" in qbittorrent) dela=dela.qbtheme ;; *) dela=Dela ;; esac
  [ "$rc" = 3 ] && [ "$(no_ar "$app")" = "$dela" ] \
    && ok "$app: o tema que ela pôs à mão não é trocado pela troca de pack" \
    || falha "$app: o tema dela foi trocado (rc=$rc, no ar: $(no_ar "$app"))" "$saida"
done

for trilha in qbittorrent.arquivo obsidian.esquema vscode.esquema heroic.esquema; do
  for par in "${PACKS[@]}"; do
    p="${par%%:*}"
    quem="$(FLAVOR="${par#*:}" python3 "$RAIZ/scripts/pack.py" app "$p" "apps.$trilha" 2>/dev/null | sed -n 's/^pack=//p')"
    [ "$quem" = "$p" ] && ok "${trilha%%.*}/$p: o pack responde pelo próprio tema" \
      || falha "${trilha%%.*}/$p: o tema não é do pack $p (responde: '${quem:-ninguém}')"
  done
done

fabrica=",$(sed -n 's/^APPS_ATIVOS="\(.*\)"$/\1/p' "$RAIZ/meow.conf.exemplo" | tail -n 1 | tr -d ' '),"
faltam=""
for d in "$RAIZ"/scripts/temas-de-apps/*/manifesto.sh; do
  m="$(basename "$(dirname "$d")")"
  case "$m" in
    btop-bat) slugs="bat btop" ;;
    toolkits-gtk-qt) slugs="qt5ct gtk qt" ;;
    *) slugs="$m" ;;
  esac
  achou=0
  for s in $slugs; do case "$fabrica" in *",$s,"*) achou=1 ;; esac; done
  [ "$achou" = 1 ] || faltam+=" $m"
done
[ -z "$faltam" ] && ok "todo módulo de app vem ligado no APPS_ATIVOS de fábrica" \
  || falha "módulos fora do APPS_ATIVOS de fábrica (meow.conf.exemplo):$faltam"

printf '\n'
if [ "$falhas" -gt 0 ]; then
  printf '%s achado(s).\n' "$falhas" >&2
  exit 1
fi
printf 'Cada aplicativo veste os dois packs, cada um com a cor dele.\n'
exit 0

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
BIN="$T/bin"; CASA="$T/casa"; ESTADO="$T/estado"
mkdir -p "$BIN" "$CASA/.config" "$ESTADO"
for b in sudo pkexec su apt apt-get pkill systemctl curl wget; do
  printf '#!/bin/sh\nexit 1\n' > "$BIN/$b"; chmod 755 "$BIN/$b"
done
printf '#!/bin/sh\nexit 1\n' > "$BIN/pgrep"; chmod 755 "$BIN/pgrep"
cat > "$BIN/flatpak" <<'FLATPAK'
#!/bin/sh
case "$1" in
  list) printf 'com.spotify.Client\t%s\n' "$(cat "$HOME/.fake/spotify-versao")" ;;
esac
exit 0
FLATPAK
chmod 755 "$BIN/flatpak"

cat > "$BIN/spicetify" <<'SPI'
#!/bin/bash
F="$HOME/.fake"; mkdir -p "$F"
ini="$HOME/.config/spicetify/config-xpui.ini"
base="$HOME/.local/share/flatpak/app/com.spotify.Client/current/active/files/extra/share/spotify"
backup="$HOME/.local/state/spicetify/Backup"
printf '%s\n' "$*" >> "$F/chamadas"
gravar() {
  [ -f "$ini" ] || printf '[Setting]\n' > "$ini"
  grep -v "^$1 *=" "$ini" > "$ini.n"; printf '%s = %s\n' "$1" "$2" >> "$ini.n"; mv "$ini.n" "$ini"
}
aplicar() {
  [ -f "$F/apply-quebrado" ] && { echo "Error: boom" >&2; return 1; }
  if [ -f "$F/desatualizado" ]; then
    echo 'Preprocessed Spotify data is outdated. Please run "spicetify restore backup apply"' >&2
    return 1
  fi
  esquema="$(sed -n 's/^color_scheme *= *//p' "$ini" | head -1)"
  tema="$(sed -n 's/^current_theme *= *//p' "$ini" | head -1)"
  texto="$(awk -v s="[$esquema]" '$0 == s { d = 1; next } /^\[/ { d = 0 } d && $1 == "text" { print $3; exit }' \
            "$HOME/.config/spicetify/Themes/$tema/color.ini")"
  rm -rf "$base/Apps/xpui"; mkdir -p "$base/Apps/xpui"
  printf ':root { --spice-text: #%s; }\n' "$texto" > "$base/Apps/xpui/colors.css"
  rm -f "$base/Apps/xpui.spa"
}
fazer_backup() {
  mkdir -p "$backup"; : > "$backup/xpui.spa"
  gravar version "$(cat "$F/spotify-versao")"
  rm -f "$F/desatualizado"
}
case "$*" in
  -v) cat "$F/spicetify-versao" ;;
  config*) shift; while [ $# -ge 2 ]; do gravar "$1" "$2"; shift 2; done ;;
  "apply") aplicar ;;
  "backup apply")
    [ -f "$base/Apps/xpui.spa" ] || { echo "Error: o app já está modificado" >&2; exit 1; }
    fazer_backup; aplicar ;;
  "restore backup apply")
    fazer_backup
    aplicar ;;
  "restore") rm -rf "$base/Apps/xpui"; : > "$base/Apps/xpui.spa" ;;
esac
SPI
chmod 755 "$BIN/spicetify"

BASE="$CASA/.local/share/flatpak/app/com.spotify.Client"
APPS_DE() { printf '%s/x86_64/stable/%s/files/extra/share/spotify/Apps' "$BASE" "$1"; }
implantar() {
  local commit="$1"
  mkdir -p "$(APPS_DE "$commit")" "$CASA/.fake"
  ln -sfn x86_64/stable "$BASE/current"
  ln -sfn "$commit" "$BASE/x86_64/stable/active"
  : > "$(APPS_DE "$commit")/xpui.spa"
}
rm -rf "$BASE"
implantar commit1
printf '1.2.90\n' > "$CASA/.fake/spotify-versao"
printf '2.46.3\n' > "$CASA/.fake/spicetify-versao"
mkdir -p "$CASA/.config/spicetify/Themes/catppuccin"
printf '[mocha]\ntext = cdd6f4\nbutton-active = 9399b2\nmauve = cba6f7\nbase = 1e1e2e\n' \
  > "$CASA/.config/spicetify/Themes/catppuccin/color.ini"
printf '[Setting]\ncustom_apps = marketplace\n[Backup]\nversion = 1.2.90\n' > "$CASA/.config/spicetify/config-xpui.ini"
mkdir -p "$CASA/.config/spicetify/CustomApps/marketplace"
: > "$CASA/.config/spicetify/CustomApps/marketplace/index.js"

spot() {
  env -i PATH="$BIN:$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" XDG_DATA_HOME="$CASA/.local/share" \
      XDG_STATE_HOME="$CASA/.local/state" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$ESTADO" TMPDIR="$T" \
      MEOW_CONF="$CASA/meow.conf" MEOW_DRY_RUN="${SECO:-0}" \
      PACK=meowsystem FLAVOR=mocha ACCENT=mauve SPOTIFY_MARKETPLACE=nao NO_COLOR=1 \
      bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 2
               . "$MEOW_RAIZ/scripts/temas-de-apps/spotify/manifesto.sh" || exit 2
               meow_app_$1; printf "rc=%s\n" "$?"' _ "$1" </dev/null 2>&1
}
rc_de() { printf '%s\n' "$1" | sed -n 's/^rc=//p' | tail -1; }
retrato() { (cd "$CASA" && find . -type f ! -path './.fake/*' -printf '%p %s %T@\n' | sort); }
chamadas() { grep -vx -- '-v' "$CASA/.fake/chamadas" 2>/dev/null; }
zerar() { rm -f "$CASA/.fake/chamadas"; }
colors() { printf '%s/xpui/colors.css' "$(APPS_DE "$(readlink "$BASE/x86_64/stable/active")")"; }

s="$(spot aplicar)"
[ "$(rc_de "$s")" = 1 ] && grep -qi -- '--spice-text: #cba6f7' "$(colors)" \
  && ok "1. a primeira passada aplica o tema do pack no Spotify" \
  || falha "1. a primeira passada não aplicou" "$s"
s="$(spot conferir)"
[ "$(rc_de "$s")" = 0 ] && ok "1. depois de aplicado, a conferência fecha em 0" || falha "1. conferir não fechou em 0" "$s"
antes="$(retrato)"
s="$(spot aplicar)"
[ "$(rc_de "$s")" = 0 ] && [ "$antes" = "$(retrato)" ] \
  && ok "1. a segunda passada não escreve nada" \
  || falha "1. a segunda passada escreveu ou saiu diferente de 0" "$s
$(diff <(printf '%s\n' "$antes") <(retrato))"

printf '2.46.4\n' > "$CASA/.fake/spicetify-versao"
: > "$CASA/.fake/desatualizado"
s="$(spot conferir)"
[ "$(rc_de "$s")" = 1 ] \
  && ok "2. o spicetify novo (outro número) deixa a conferência divergente, mesmo com o tema no disco" \
  || falha "2. a conferência não notou o spicetify novo" "$s"
zerar
s="$(spot aplicar)"
[ "$(rc_de "$s")" = 1 ] && chamadas | grep -qx 'restore backup apply' && [ ! -f "$CASA/.fake/desatualizado" ] \
  && ok "2. com o aviso «outdated», o módulo refaz sozinho o 'restore backup apply' e aplica" \
  || falha "2. o módulo não refez o backup depois do «outdated»" "$s
$(chamadas)"
antes="$(retrato)"
s="$(spot aplicar)"
[ "$(rc_de "$s")" = 0 ] && [ "$antes" = "$(retrato)" ] && [ "$(rc_de "$(spot conferir)")" = 0 ] \
  && ok "2. a passada seguinte não escreve e a conferência fecha em 0" \
  || falha "2. a passada seguinte escreveu ou não fechou" "$s"

printf '1.2.91\n' > "$CASA/.fake/spotify-versao"
implantar commit2
: > "$CASA/.fake/desatualizado"
touch -d '2020-01-01' "$CASA/.local/state/spicetify/Backup/xpui.spa" "$CASA/.local/state/spicetify/Backup"
s="$(spot conferir)"
[ "$(rc_de "$s")" = 1 ] \
  && ok "3. o Spotify atualizou (backup de outra versão): a conferência diverge, não avisa de ler documento" \
  || falha "3. a conferência não divergiu com o Spotify atualizado" "$s"
zerar
s="$(spot aplicar)"
if [ "$(rc_de "$s")" = 1 ] && chamadas | grep -qx 'backup apply' && ! chamadas | grep -qx 'restore backup apply' \
   && [ "$(sed -n 's/^version *= *//p' "$CASA/.config/spicetify/config-xpui.ini")" = 1.2.91 ] \
   && [ -n "$(ls -d "$ESTADO"/backups/spotify-spicetify-* 2>/dev/null)" ] \
   && [ -f "$(colors)" ]; then
  ok "3. com o app de fábrica e o backup velho, o módulo põe o backup velho de lado e faz 'backup apply'"
else
  falha "3. o módulo não refez o backup do Spotify atualizado" "$s
$(chamadas)"
fi
antes="$(retrato)"
s="$(spot aplicar)"
[ "$(rc_de "$s")" = 0 ] && [ "$antes" = "$(retrato)" ] \
  && ok "3. a passada seguinte não escreve nada" || falha "3. a passada seguinte escreveu" "$s"

printf '2.46.5\n' > "$CASA/.fake/spicetify-versao"
: > "$CASA/.fake/apply-quebrado"
zerar
s="$(spot aplicar)"
[ "$(rc_de "$s")" = 2 ] \
  && ok "4. com o apply quebrando de verdade, o aplicar sai com erro" \
  || falha "4. o aplicar não saiu com erro" "$s"
s="$(spot conferir)"
[ "$(rc_de "$s")" = 1 ] \
  && ok "4. e a conferência fica divergente, não ok (com o colors.css de antes no disco)" \
  || falha "4. a conferência disse ok com o apply falhado" "$s"
s="$(spot aplicar)"
printf '%s\n' "$s" | grep -q 'nada a fazer' \
  && falha "4. a passada seguinte disse «nada a fazer» com o apply falhado" "$s" \
  || ok "4. a passada seguinte não diz «nada a fazer»"
rm -f "$CASA/.fake/apply-quebrado"
s="$(spot aplicar)"
[ "$(rc_de "$s")" = 1 ] && [ "$(rc_de "$(spot conferir)")" = 0 ] \
  && ok "4. com o apply voltando a funcionar, aplica e a conferência fecha" \
  || falha "4. o apply que voltou não fechou" "$s"

printf '2.46.6\n' > "$CASA/.fake/spicetify-versao"
: > "$CASA/.fake/desatualizado"
zerar
antes="$(retrato)"
s="$(SECO=1 spot aplicar)"
[ "$(rc_de "$s")" = 1 ] && [ "$antes" = "$(retrato)" ] && [ -z "$(chamadas)" ] \
  && ok "5. no «ver sem mudar» nada é escrito nem chamado" \
  || falha "5. o «ver sem mudar» escreveu ou chamou o spicetify" "$s
$(chamadas)"

if grep -nEi '(meow_(info|pula|aviso|muda|ok|erro)) .*(meow\.conf|\babra\b|\brode\b|digite|RECUPERACAO|\bveja\b)' \
     "$RAIZ/scripts/temas-de-apps/spotify/manifesto.sh" >/dev/null; then
  falha "6. saída do módulo do Spotify manda ler, abrir ou digitar" \
    "$(grep -nEi '(meow_(info|pula|aviso|muda|ok|erro)) .*(meow\.conf|\babra\b|\brode\b|digite|RECUPERACAO|\bveja\b)' "$RAIZ/scripts/temas-de-apps/spotify/manifesto.sh")"
else
  ok "6. nenhuma saída do módulo do Spotify manda ler, abrir ou digitar"
fi

[ "$falhas" -eq 0 ] || { printf '\n%d falha(s)\n' "$falhas" >&2; exit 1; }
printf '\ntudo certo\n'

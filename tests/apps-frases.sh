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
mkdir -p "$BIN" "$CASA/.config/meow" "$ESTADO"
for b in sudo pkexec su pkill notify-send systemctl gsettings dconf busctl curl wget; do
  printf '#!/bin/sh\nexit 1\n' > "$BIN/$b"; chmod 755 "$BIN/$b"
done
printf '#!/bin/sh\nexit 0\n' > "$BIN/flatpak"; chmod 755 "$BIN/flatpak"
printf '#!/bin/sh\nexit 1\n' > "$BIN/pgrep"; chmod 755 "$BIN/pgrep"

ramo="$CASA/.local/share/flatpak/app/org.qbittorrent.qBittorrent/x86_64/stable"
mkdir -p "$ramo/0123abcd" && ln -sfn 0123abcd "$ramo/active"
ln -sfn x86_64/stable "$CASA/.local/share/flatpak/app/org.qbittorrent.qBittorrent/current"
QB="$CASA/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent"
mkdir -p "$QB"
printf '[Preferences]\nGeneral\\Locale=en\n' > "$QB/qBittorrent.conf"
CONF="$CASA/.config/meow/meow.conf"
printf 'PACK="meowsystem"\nAPPS_ATIVOS="kitty,qbittorrent,spotify,zapzap"  # os apps\nFLAVOR="mocha"\n' > "$CONF"

casa() {
  env -i PATH="$BIN:$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    XDG_CONFIG_HOME="$CASA/.config" XDG_DATA_HOME="$CASA/.local/share" XDG_STATE_HOME="$CASA/.local/state" \
    MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$ESTADO" MEOW_CONF="$CONF" TMPDIR="$T" \
    PACK=meowsystem FLAVOR=mocha ACCENT=mauve "$@"
}
retrato() { (cd "$CASA" && find . -type f -printf '%p %s %T@\n' | sort); }
ativos() { sed -n 's/^APPS_ATIVOS="\([^"]*\)".*/\1/p' "$CONF"; }

s="$(casa env APPS_ATIVOS=qbittorrent bash "$RAIZ/scripts/aplicar_apps.sh" aplicar 2>&1)"
grep -qxF 'General\UseCustomUITheme=true' "$QB/qBittorrent.conf" \
  && ok "1. o qBittorrent recebe o tema do pack (ponto de partida)" \
  || falha "1. o tema do pack não entrou no qBittorrent" "$s
$(cat "$QB/qBittorrent.conf")"
s="$(casa env APPS_ATIVOS=qbittorrent bash "$RAIZ/scripts/aplicar_apps.sh" reverter 2>&1)"
[ "$(ativos)" = "kitty,spotify,zapzap" ] && grep -q '^APPS_ATIVOS="kitty,spotify,zapzap"  # os apps$' "$CONF" \
  && ok "1. reverter o qBittorrent tira 'qbittorrent' do APPS_ATIVOS do meow.conf, e o comentário da linha fica" \
  || falha "1. o reverter não desligou o qBittorrent" "$s
$(cat "$CONF")"
printf '%s\n' "$s" | grep -qiE 'meow\.conf|\babra\b|\brode\b|digite|tire ' \
  && falha "1. a saída do reverter manda editar, abrir ou digitar" "$s" \
  || ok "1. a saída do reverter diz só o fato"
antes="$(retrato)"
s="$(casa env APPS_ATIVOS=qbittorrent bash "$RAIZ/scripts/aplicar_apps.sh" reverter 2>&1)"
[ "$antes" = "$(retrato)" ] \
  && ok "1. a segunda passada do reverter não escreve" \
  || falha "1. a segunda passada do reverter escreveu" "$(diff <(printf '%s\n' "$antes") <(retrato))"

printf 'APPS_ATIVOS="kitty,qbittorrent"\n' > "$CONF"
s="$(casa env MEOW_DRY_RUN=1 APPS_ATIVOS=qbittorrent bash "$RAIZ/scripts/aplicar_apps.sh" reverter 2>&1)"
[ "$(ativos)" = "kitty,qbittorrent" ] \
  && ok "1. no «ver sem mudar» o meow.conf não muda" \
  || falha "1. o «ver sem mudar» mexeu no meow.conf" "$s"

WF="$CASA/.var/app/net.waterfox.waterfox/.waterfox"
mkdir -p "$CASA/.local/share/flatpak/app/net.waterfox.waterfox/x86_64/stable/0123abcd"
ln -sfn 0123abcd "$CASA/.local/share/flatpak/app/net.waterfox.waterfox/x86_64/stable/active"
ln -sfn x86_64/stable "$CASA/.local/share/flatpak/app/net.waterfox.waterfox/current"
mkdir -p "$WF"
s="$(casa env APPS_ATIVOS=waterfox bash "$RAIZ/scripts/aplicar_apps.sh" aplicar 2>&1)"
printf '%s\n' "$s" | grep -qiE 'abra|rode|digite|meow\.conf' \
  && falha "2. o Waterfox sem perfil manda abrir o programa" "$s" \
  || ok "2. o Waterfox sem perfil diz o estado, sem ordem"
printf '%s\n' "$s" | grep -q 'ainda sem perfil; o tema entra quando o perfil existir' \
  && ok "2. a frase do Waterfox sem perfil é o fato" \
  || falha "2. a frase do Waterfox sem perfil mudou" "$s"
mkdir -p "$WF/abc.default"
printf '[Profile0]\nName=default\nIsRelative=1\nPath=abc.default\nDefault=1\n' > "$WF/profiles.ini"
s="$(casa env APPS_ATIVOS=waterfox bash "$RAIZ/scripts/aplicar_apps.sh" aplicar 2>&1)"
[ -s "$WF/abc.default/chrome/userChrome.css" ] \
  && ok "2. com o perfil criado, a passada seguinte aplica o tema" \
  || falha "2. a passada seguinte não aplicou o tema do Waterfox" "$s"
antes="$(retrato)"
casa env APPS_ATIVOS=waterfox bash "$RAIZ/scripts/aplicar_apps.sh" aplicar >/dev/null 2>&1
[ "$antes" = "$(retrato)" ] \
  && ok "2. a segunda passada do Waterfox não escreve" \
  || falha "2. a segunda passada do Waterfox escreveu" "$(diff <(printf '%s\n' "$antes") <(retrato))"

for par in meowsystem:mocha dracula:dracula; do
  p="${par%%:*}"; f="${par#*:}"
  css="$(python3 "$RAIZ/scripts/temas-de-apps/modelo.py" "$RAIZ/scripts/temas-de-apps/zapzap/zapzap.modelo.css" "$RAIZ/packs/$p/paleta.json" "$f" "$p" 2>&1)"
  base="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["flavors"][sys.argv[2]]["crust"].lstrip("#").upper())' "$RAIZ/packs/$p/paleta.json" "$f")"
  if printf '%s\n' "$css" | grep -qiE "^ *--WDS-systems-chat-background-wallpaper: #$base !important;" \
     && printf '%s\n' "$css" | grep -qE '^ *--WDS-systems-chat-background-wallpaper-RGB: [0-9]+, ?[0-9]+, ?[0-9]+ !important;' \
     && printf '%s\n' "$css" | grep -qE '^ *--WDS-systems-chat-foreground-wallpaper: #' \
     && ! printf '%s\n' "$css" | grep -q '{{'; then
    ok "3. zapzap/$p: o CSS pinta o fundo da conversa (cor e canais RGB) com o crust do pack"
  else
    falha "3. zapzap/$p: o CSS não pinta o fundo da conversa" "$(printf '%s\n' "$css" | grep -i wallpaper)"
  fi
done

[ "$falhas" -eq 0 ] || { printf '\n%d falha(s)\n' "$falhas" >&2; exit 1; }
printf '\ntudo certo\n'

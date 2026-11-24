#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d -p "${TMPDIR:-/tmp}" meow-pulado.XXXXXX)" || exit 2
trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }

CASA="$T/casa"; FALSO="$T/falso"
mkdir -p "$CASA/.config/meow" "$FALSO"
for b in sudo pkexec su pkill systemctl; do
  printf '#!/bin/sh\nexit 1\n' > "$FALSO/$b"; chmod 755 "$FALSO/$b"
done
printf '#!/bin/sh\nexit 0\n' > "$FALSO/cosmic-randr"; chmod 755 "$FALSO/cosmic-randr"

rodar() {
  local script="$1"; shift
  env -i PATH="$FALSO:/usr/bin:/bin" HOME="$CASA" LANG=C.UTF-8 NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
    MEOW_ESTADO="$T/estado" TMPDIR="$T" "$@" bash "$RAIZ/scripts/$script" $ARGS > "$T/saida" 2>&1
  RC=$?
}
ARGS=""
marca() { grep -qE "^  $1 " "$T/saida"; }

pulado() {
  local nome="$1"; shift
  rodar "$@"
  if [ "$RC" = 3 ] && marca '--'; then ok "$nome: «--» com código 3"
  else falha "$nome: esperava «--» com código 3, veio $RC: $(cat "$T/saida")"; fi
}
confere() {
  local nome="$1"; shift
  rodar "$@"
  if [ "$RC" = 0 ] && marca 'ok' && ! marca '--'; then ok "$nome: «ok» com código 0"
  else falha "$nome: esperava «ok» com código 0, veio $RC: $(cat "$T/saida")"; fi
}

echo "== o que não há para fazer devolve 3"
pulado "escala com ESCALA_TELA vazia" escala.sh ESCALA_TELA=
pulado "jogos sem a Steam" jogos_steam.sh
pulado "jogos sem o Heroic" jogos_heroic.sh

echo "== o que há e está certo, ou é escolha respeitada, devolve 0 com ok"
mkdir -p "$CASA/.steam/steam/steamapps"
confere "jogos com a Steam sem jogo no lançador" jogos_steam.sh
rm -rf "$CASA/.steam"
mkdir -p "$CASA/.config/heroic/store_cache"; printf '[]' > "$CASA/.config/heroic/store_cache/legendary_library.json"
confere "jogos com o Heroic sem jogo instalado" jogos_heroic.sh
rm -rf "$CASA/.config/heroic"
confere "vigia da Steam desligado" vigia_steam.sh STEAM_VIGIA=nao
confere "vigia do Heroic desligado" vigia_heroic.sh HEROIC_VIGIA=nao
confere "vigia do Discord desligado" vigia_discord.sh DISCORD_VENCORD=nao
confere "vigia de flatpak desligado" vigia_flatpak.sh FLATPAK_VIGIA=nao

BASE="$CASA/.config/cosmic/com.system76.CosmicComp/$(MEOW_RAIZ="$RAIZ" bash -c '. "$MEOW_RAIZ/scripts/lib/comum.sh"; meow_cosmic_v com.system76.CosmicComp' 2>/dev/null)"
mkdir -p "$BASE"; printf 'false' > "$BASE/leitura_agenda"
ARGS=aplicar confere "leitura com o Agendar desligado no applet" leitura.sh LEITURA_AGENDA=sim

echo "== a frase sai uma vez, com o nome certo"
rodar icones_mimetypes.sh PACK=dracula FLAVOR=dracula ACCENT=mauve
rodar icones_mimetypes.sh PACK=dracula FLAVOR=dracula ACCENT=mauve
if grep -qiE 'já com o (\S+) \1( |$)' "$T/saida"; then falha "os tipos de arquivo repetem o nome do acervo: $(cat "$T/saida")"
elif grep -q 'tipos de arquivo já com o Dracula$' "$T/saida"; then ok "tipos de arquivo já com o Dracula, sem repetir o flavor"
else falha "a frase dos tipos de arquivo mudou: $(cat "$T/saida")"; fi

RAMO="$CASA/.local/share/flatpak/app/org.qbittorrent.qBittorrent/x86_64/stable"
mkdir -p "$RAMO/0123abcd" "$CASA/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent"
ln -sfn 0123abcd "$RAMO/active"
ln -sfn x86_64/stable "$CASA/.local/share/flatpak/app/org.qbittorrent.qBittorrent/current"
printf '#!/bin/sh\nexit 0\n' > "$FALSO/flatpak"; printf '#!/bin/sh\nexit 1\n' > "$FALSO/pgrep"; chmod 755 "$FALSO/flatpak" "$FALSO/pgrep"
printf 'PACK="meowsystem"\nFLAVOR="mocha"\n' > "$CASA/.config/meow/meow.conf"
rodar aplicar_apps.sh APPS_ATIVOS=qbittorrent PACK=meowsystem FLAVOR=mocha ACCENT=mauve MEOW_CONF="$CASA/.config/meow/meow.conf"
rodar aplicar_apps.sh APPS_ATIVOS=qbittorrent PACK=meowsystem FLAVOR=mocha ACCENT=mauve MEOW_CONF="$CASA/.config/meow/meow.conf"
[ "$(grep -ci '^  ok .*qbittorrent.*tema do pack' "$T/saida")" = 1 ] && ok "o qBittorrent já certo diz o tema do pack numa linha ok só" || falha "o qBittorrent já certo sai em mais de uma linha ok: $(cat "$T/saida")"

echo
if [ "$falhas" = 0 ]; then echo "etapa-sem-pulo-verde: tudo certo"; exit 0; fi
echo "etapa-sem-pulo-verde: $falhas falha(s)"; exit 1

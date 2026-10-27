#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$(mktemp -d)"; trap 'rm -rf "$H"' EXIT

APPS="$H/.local/share/applications"
CONF="$H/.var/app/com.heroicgameslauncher.hgl/config/heroic"
mkdir -p "$APPS" "$CONF/store_cache" "$CONF/legendaryConfig/legendary" "$CONF/icons"

JOGO=63a665088eb1480298f1e57943b225d8
DLC=9596620d263b40c083ddf1f0c662c8ff
FORA=aaaa1111bbbb2222cccc3333dddd4444
ID="meow-heroic-legendary-$JOGO"

biblioteca() {
  local instalado="${1:-true}"
  cat > "$CONF/store_cache/legendary_library.json" <<JSON
{
  "library": [
    {
      "app_name": "$JOGO",
      "title": "Marvel's Guardians of the Galaxy",
      "runner": "legendary",
      "is_installed": $instalado,
      "install": { "is_dlc": false, "install_path": "$H/Games/MarvelGOTG" }
    },
    {
      "app_name": "$DLC",
      "title": "Marvel's Guardians of the Galaxy: Social-Lord Outfit",
      "runner": "legendary",
      "is_installed": true,
      "install": { "is_dlc": true, "install_path": "$H/Games/MarvelGOTG" }
    },
    {
      "app_name": "$FORA",
      "title": "Um jogo que ela não instalou",
      "runner": "legendary",
      "is_installed": false,
      "install": {}
    }
  ],
  "__timestamp": 0
}
JSON
}

instalados() {
  local corpo="${1:-}"
  cat > "$CONF/legendaryConfig/legendary/installed.json" <<JSON
{$corpo}
JSON
}

biblioteca true
instalados "
  \"$JOGO\": { \"app_name\": \"$JOGO\", \"title\": \"Marvel's Guardians of the Galaxy\", \"is_dlc\": false },
  \"$DLC\":  { \"app_name\": \"$DLC\",  \"title\": \"Social-Lord Outfit\", \"is_dlc\": true }"

correr() {
  env -i PATH="$PATH" HOME="$H" USER="${USER:-t}" NO_COLOR=1 HEROIC_CONF="$CONF" \
    MEOW_HEROIC_TIRAR="${MEOW_HEROIC_TIRAR:-}" MEOW_HEROIC_POR="${MEOW_HEROIC_POR:-}" \
    bash "$RAIZ/scripts/jogos_heroic.sh" "$@" 2>&1
  return "$?"
}

falhas=0
reclamar() { printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas + 1)); }

saida="$(correr)"; rc=$?
[ "$rc" = "1" ] || reclamar "1ª rodada devolveu rc=$rc (esperado 1: mexeu)\n$saida"
[ -f "$APPS/$ID.desktop" ] || reclamar "o cartão do jogo não foi escrito\n$saida"
grep -q '^X-MeowSystem=jogo-heroic$' "$APPS/$ID.desktop" 2>/dev/null \
  || reclamar "o cartão saiu sem a marca de autoria — sem ela a limpeza não pode apagá-lo"
grep -q "^Exec=xdg-open \"heroic://launch?appName=$JOGO&runner=legendary\"$" "$APPS/$ID.desktop" 2>/dev/null \
  || reclamar "o Exec não é o protocolo do Heroic:\n$(grep '^Exec=' "$APPS/$ID.desktop" 2>/dev/null)"
[ -e "$APPS/meow-heroic-legendary-$DLC.desktop" ] \
  && reclamar "o DLC ganhou cartão — install.is_dlc não foi respeitado"
[ -e "$APPS/meow-heroic-legendary-$FORA.desktop" ] \
  && reclamar "um jogo NÃO instalado ganhou cartão"

saida="$(correr)"; rc=$?
[ "$rc" = "0" ] || reclamar "2ª rodada devolveu rc=$rc (esperado 0: convergiu)\n$saida"

RIVAL="$APPS/Marvel's Guardians of the Galaxy.desktop"
cat > "$RIVAL" <<DESKTOP
[Desktop Entry]
Name=Marvel's Guardians of the Galaxy
Exec=xdg-open heroic://launch?appName=$JOGO&runner=legendary
Terminal=false
Type=Application
Icon=$CONF/icons/$JOGO.jpg
Categories=Game;
DESKTOP

SEM_SUBSTITUTO="$APPS/jogo-que-nao-e-nosso.desktop"
cat > "$SEM_SUBSTITUTO" <<DESKTOP
[Desktop Entry]
Name=Outro jogo do Heroic
Exec=xdg-open heroic://launch?appName=$FORA&runner=legendary
Type=Application
Categories=Game;
DESKTOP

saida="$(correr)"; rc=$?
[ "$rc" = "1" ] || reclamar "com o rival do Heroic ao lado, rc=$rc (esperado 1)\n$saida"
[ -e "$RIVAL" ] && reclamar "o cartão que o próprio Heroic escreveu continua lá — são dois na tela dela"
[ -f "$SEM_SUBSTITUTO" ] \
  && : || reclamar "removeu o cartão de um jogo para o qual NÃO temos substituto"
if ! find "$H/.local/state/meowsystem/backups" -name "Marvel's Guardians of the Galaxy.desktop" 2>/dev/null | grep -q .; then
  reclamar "removeu sem guardar cópia do que não é nosso"
fi
saida="$(correr)"; rc=$?
[ "$rc" = "0" ] || reclamar "não voltou a convergir depois de tirar o rival (rc=$rc)\n$saida"

cat > "$RIVAL" <<DESKTOP
[Desktop Entry]
Name=Marvel's Guardians of the Galaxy
Exec=xdg-open heroic://launch?appName=$JOGO&runner=legendary
Type=Application
DESKTOP
saida="$(correr --conferir)"; rc=$?
[ "$rc" = "1" ] || reclamar "o seco devolveu rc=$rc com um rival no disco (esperado 1)\n$saida"
[ -f "$RIVAL" ] || reclamar "--conferir REMOVEU o cartão duplicado — o seco não escreve nem apaga"
case "$saida" in
  *"Marvel's Guardians of the Galaxy.desktop"*) : ;;
  *) reclamar "o seco não NOMEOU o arquivo que sairia\n$saida" ;;
esac
rm -f "$RIVAL"

biblioteca false
instalados ""
saida="$(correr)"; rc=$?
[ "$rc" = "1" ] || reclamar "com o jogo desinstalado, rc=$rc (esperado 1: tinha o que remover)\n$saida"
[ -e "$APPS/$ID.desktop" ] && reclamar "o cartão do jogo desinstalado continua no lançador"
if find "$H/.local/share/icons/hicolor" -name "$ID.png" 2>/dev/null | grep -q .; then
  reclamar "sobrou ícone do jogo desinstalado no hicolor"
fi

biblioteca true
instalados "
  \"$JOGO\": { \"app_name\": \"$JOGO\", \"title\": \"Marvel's Guardians of the Galaxy\", \"is_dlc\": false }"
correr >/dev/null 2>&1
lista="$(correr --listar)"
printf '%s\n' "$lista" | grep -q "^$ID	.*	sim$" || reclamar "--listar não mostrou o jogo no lançador\n$lista"
MEOW_HEROIC_TIRAR="$ID" correr >/dev/null 2>&1
[ -e "$APPS/$ID.desktop" ] && reclamar "o interruptor desligado não tirou o cartão do lançador"
grep -qxF "$ID" "$H/.config/meow/jogos-heroic-fora.list" 2>/dev/null || reclamar "o interruptor não gravou a lista"
correr --listar | grep -q "^$ID	.*	nao$" || reclamar "--listar não mostrou o jogo fora do lançador"
correr >/dev/null 2>&1
[ -e "$APPS/$ID.desktop" ] && reclamar "a passada seguinte devolveu o jogo que ela tirou"
MEOW_HEROIC_POR="$ID" correr >/dev/null 2>&1
[ -f "$APPS/$ID.desktop" ] || reclamar "o interruptor ligado não devolveu o cartão"
grep -qxF "$ID" "$H/.config/meow/jogos-heroic-fora.list" 2>/dev/null && reclamar "o jogo devolvido continua na lista"

biblioteca true
instalados "
  \"$JOGO\": { \"app_name\": \"$JOGO\", \"title\": \"Marvel's Guardians of the Galaxy\", \"is_dlc\": false }"
correr >/dev/null 2>&1
[ -f "$APPS/$ID.desktop" ] || reclamar "o cartão não voltou depois de o jogo ser reinstalado"
printf 'isto não é json {{{' > "$CONF/store_cache/legendary_library.json"
rm -f "$CONF/store_cache/gog_library.json" "$CONF/store_cache/nile_library.json"
saida="$(correr)"; rc=$?
[ "$rc" = "3" ] || reclamar "biblioteca ilegível devolveu rc=$rc (esperado 3: falta dependência)\n$saida"
[ -f "$APPS/$ID.desktop" ] \
  || reclamar "biblioteca ilegível APAGOU o cartão de um jogo instalado — a ausência era falsa"

[ "$falhas" = "0" ] || exit 1
printf 'ok: um cartão por jogo do Heroic, e o rival do próprio Heroic não duplica\n'

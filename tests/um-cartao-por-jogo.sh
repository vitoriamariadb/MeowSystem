#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$(mktemp -d)"; trap 'rm -rf "$H"' EXIT

INSTALADO=1715980
DESINSTALADO=999999

APPS="$H/.local/share/applications"
STEAMAPPS="$H/.steam/steam/steamapps"
HICOLOR="$H/.local/share/icons/hicolor"
mkdir -p "$APPS" "$STEAMAPPS" "$HICOLOR/256x256/apps"

cat > "$STEAMAPPS/appmanifest_$INSTALADO.acf" <<ACF
"AppState"
{
	"appid"		"$INSTALADO"
	"name"		"Bail or Jail"
}
ACF
: > "$HICOLOR/256x256/apps/steam_icon_$INSTALADO.png"

molde() {
  cat <<DESKTOP
[Desktop Entry]
Name=Bail or Jail
Comment=Play this game on Steam
Exec=steam steam://rungameid/$1
Icon=steam_icon_$1
Terminal=false
Type=Application
Categories=Game;
DESKTOP
}

molde "$INSTALADO"    > "$APPS/steam_app_$INSTALADO.desktop"
molde "$DESINSTALADO" > "$APPS/steam_app_$DESINSTALADO.desktop"

RIVAL_LIVRE="$APPS/Jogo Qualquer Ação.desktop"
molde "$INSTALADO" > "$RIVAL_LIVRE"

cat > "$APPS/o-jogo-dela.desktop" <<DESKTOP
[Desktop Entry]
Name=Um jogo do jeito dela
Exec=steam steam://rungameid/$DESINSTALADO
Type=Application
Categories=Game;
DESKTOP

cat > "$APPS/abrir-a-steam.desktop" <<DESKTOP
[Desktop Entry]
Name=Abrir a Steam
Exec=steam
Type=Application
DESKTOP

SEQUELA="${INSTALADO}0"
cat > "$APPS/sequela-sem-manifesto.desktop" <<DESKTOP
[Desktop Entry]
Name=Bail or Jail 2
Exec=steam steam://rungameid/$SEQUELA
Type=Application
Categories=Game;
DESKTOP

correr() {
  env -i PATH="$PATH" HOME="$H" USER="${USER:-t}" NO_COLOR=1 \
    bash "$RAIZ/scripts/jogos_steam.sh" 2>&1
  return "$?"
}

falhas=0
reclamar() { printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas + 1)); }

saida="$(correr)"; rc=$?
[ "$rc" = "1" ] || reclamar "1ª rodada devolveu rc=$rc (esperado 1: mexeu)\n$saida"
[ -f "$APPS/meow-steam-$INSTALADO.desktop" ] \
  || reclamar "o nosso cartão não foi escrito\n$saida"
[ -e "$APPS/steam_app_$INSTALADO.desktop" ] \
  && reclamar "o cartão duplicado do appid $INSTALADO continua lá\n$saida"
[ -e "$RIVAL_LIVRE" ] \
  && reclamar "o rival de NOME LIVRE (espaço e acento) continua lá — é o defeito de 09/09\n$saida"
[ -f "$APPS/steam_app_$DESINSTALADO.desktop" ] \
  || reclamar "removeu o steam_app_ de um jogo SEM manifesto — não há substituto para ele"
[ -f "$APPS/o-jogo-dela.desktop" ] \
  || reclamar "apagou o .desktop que ela escreveu à mão para um jogo sem manifesto"
[ -f "$APPS/abrir-a-steam.desktop" ] \
  || reclamar "apagou um lançador genérico da Steam, que não aponta para jogo nenhum"
[ -f "$APPS/sequela-sem-manifesto.desktop" ] \
  || reclamar "a âncora do appid falhou: rungameid/$SEQUELA foi tratado como o jogo $INSTALADO"

if ! find "$H/.local/state/meowsystem/backups" -name "steam_app_$INSTALADO.desktop" 2>/dev/null | grep -q .; then
  reclamar "removeu sem guardar cópia do que não é nosso"
fi
if ! find "$H/.local/state/meowsystem/backups" -name "Jogo Qualquer Ação.desktop" 2>/dev/null | grep -q .; then
  reclamar "removeu o rival de nome livre sem guardar cópia — e ele podia ser o que ela escreveu"
fi

saida="$(correr)"; rc=$?
[ "$rc" = "0" ] || reclamar "2ª rodada devolveu rc=$rc (esperado 0: convergiu)\n$saida"
n="$(ls "$APPS"/*"$INSTALADO"*.desktop 2>/dev/null | wc -l)"
[ "$n" = "1" ] || reclamar "$n cartões para o appid $INSTALADO depois de convergir (esperado 1)"

molde "$INSTALADO" > "$APPS/steam_app_$INSTALADO.desktop"
molde "$INSTALADO" > "$RIVAL_LIVRE"
saida="$(correr)"; rc=$?
[ "$rc" = "1" ] || reclamar "com o rival de volta, rc=$rc (esperado 1: tinha o que fazer)\n$saida"
[ -e "$APPS/steam_app_$INSTALADO.desktop" ] \
  && reclamar "o rival recriado sobreviveu à rodada seguinte"
[ -e "$RIVAL_LIVRE" ] \
  && reclamar "o rival de nome livre recriado sobreviveu à rodada seguinte"
saida="$(correr)"; rc=$?
[ "$rc" = "0" ] || reclamar "não voltou a convergir depois de tirar o rival recriado (rc=$rc)\n$saida"

molde "$INSTALADO" > "$APPS/steam_app_$INSTALADO.desktop"
molde "$INSTALADO" > "$RIVAL_LIVRE"
saida="$(env -i PATH="$PATH" HOME="$H" USER="${USER:-t}" NO_COLOR=1 MEOW_DRY_RUN=1 \
  bash "$RAIZ/scripts/jogos_steam.sh" 2>&1)"
[ -f "$APPS/steam_app_$INSTALADO.desktop" ] \
  || reclamar "MEOW_DRY_RUN=1 REMOVEU o cartão duplicado — o seco não escreve nem apaga"
[ -f "$RIVAL_LIVRE" ] \
  || reclamar "MEOW_DRY_RUN=1 REMOVEU o rival de nome livre — o seco não escreve nem apaga"
case "$saida" in
  *"Jogo Qualquer Ação.desktop"*) : ;;
  *) reclamar "o seco não NOMEOU o arquivo que sairia\n$saida" ;;
esac

resumo="$(env -i PATH="$PATH" HOME="$H" USER="${USER:-t}" NO_COLOR=1 MEOW_DRY_RUN=1 \
  MEOW_JOGOS_RESUMO=1 bash "$RAIZ/scripts/jogos_steam.sh" 2>&1 | grep '^@@jogo repete ')"
[ "$(printf '%s\n' "$resumo" | grep -c "^@@jogo repete $INSTALADO Bail or Jail$")" = "2" ] \
  || reclamar "o resumo do ensaio não conta os dois cartões duplicados que sairiam\n$resumo"

[ "$falhas" = "0" ] || exit 1
printf 'ok: um cartão por jogo, e o rival não volta a duplicar\n'

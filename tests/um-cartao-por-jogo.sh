#!/usr/bin/env bash
# UM JOGO INSTALADO = UM CARTÃO NO LANÇADOR, venha o rival de onde vier.
#
# O DEFEITO QUE ESTE TESTE PEGA JÁ ACONTECEU, E ELA VIU
#   15/08/2026: quinze jogos apareciam DUAS vezes na pasta Steam do lançador do
#   COSMIC. O `jogos_steam.sh` escrevia `meow-steam-<id>.desktop` e, ao lado,
#   havia `steam_app_<id>.desktop` com o mesmo `Name=` — escritos às 03h02 de
#   14/08 pelo resgate do estrago do BleachBit, com o molde que a Steam usa nos
#   atalhos da área de trabalho. A limpeza do script conhecia dois donos rivais
#   (`steam-jogo-*` e `steam-<id>*`) e não conhecia esse terceiro nome.
#
# AS QUATRO AFIRMAÇÕES
#   1. o rival com o MESMO appid sai, e sobra um cartão só;
#   2. rodar de novo dá o mesmo (rc=0, nada a fazer) — idempotência;
#   3. se o rival VOLTAR (é o que o próximo resgate fará), a rodada seguinte o
#      tira outra vez e volta a convergir;
#   4. o que NÃO é rival sobrevive: um `.desktop` escrito à mão com `rungameid`
#      dentro, e um `steam_app_<id>.desktop` de um jogo que não está instalado
#      (sem manifesto, não temos substituto para pôr no lugar dele).
#
# POR QUE UM HOME DE BRINQUEDO
#   O território real é o lançador dela. Um teste que apaga `.desktop` de
#   verdade para ver se sabe apagar é o próprio defeito com outro nome.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$(mktemp -d)"; trap 'rm -rf "$H"' EXIT

INSTALADO=1715980          # tem manifesto: nós escrevemos o cartão dele
DESINSTALADO=999999        # não tem manifesto: não é nosso assunto

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
# Ícone bom da Steam: evita depender do `convert` para o caminho feliz.
: > "$HICOLOR/256x256/apps/steam_icon_$INSTALADO.png"

# O molde da Steam, byte a byte como os 17 de 14/08.
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

# O que ela escreveu à mão: tem `rungameid` e NÃO pode sumir (garantia de 10/08).
cat > "$APPS/o-jogo-dela.desktop" <<DESKTOP
[Desktop Entry]
Name=Bail or Jail do jeito dela
Exec=steam steam://rungameid/$INSTALADO
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

# --- 1ª rodada: escreve o nosso e tira o rival -------------------------------
saida="$(correr)"; rc=$?
[ "$rc" = "1" ] || reclamar "1ª rodada devolveu rc=$rc (esperado 1: mexeu)\n$saida"
[ -f "$APPS/meow-steam-$INSTALADO.desktop" ] \
  || reclamar "o nosso cartão não foi escrito\n$saida"
[ -e "$APPS/steam_app_$INSTALADO.desktop" ] \
  && reclamar "o cartão duplicado do appid $INSTALADO continua lá\n$saida"
[ -f "$APPS/steam_app_$DESINSTALADO.desktop" ] \
  || reclamar "removeu o steam_app_ de um jogo SEM manifesto — não há substituto para ele"
[ -f "$APPS/o-jogo-dela.desktop" ] \
  || reclamar "apagou o .desktop que ela escreveu à mão"

# O backup existe, porque o arquivo removido não era nosso.
if ! find "$H/.local/state/meowsystem/backups" -name "steam_app_$INSTALADO.desktop" 2>/dev/null | grep -q .; then
  reclamar "removeu sem guardar cópia do que não é nosso"
fi

# --- 2ª rodada: idempotência --------------------------------------------------
saida="$(correr)"; rc=$?
[ "$rc" = "0" ] || reclamar "2ª rodada devolveu rc=$rc (esperado 0: convergiu)\n$saida"
n="$(ls "$APPS"/*"$INSTALADO"*.desktop 2>/dev/null | wc -l)"
[ "$n" = "1" ] || reclamar "$n cartões para o appid $INSTALADO depois de convergir (esperado 1)"

# --- 3ª rodada: o rival VOLTA (o próximo resgate o refaz) ---------------------
molde "$INSTALADO" > "$APPS/steam_app_$INSTALADO.desktop"
saida="$(correr)"; rc=$?
[ "$rc" = "1" ] || reclamar "com o rival de volta, rc=$rc (esperado 1: tinha o que fazer)\n$saida"
[ -e "$APPS/steam_app_$INSTALADO.desktop" ] \
  && reclamar "o rival recriado sobreviveu à rodada seguinte"
saida="$(correr)"; rc=$?
[ "$rc" = "0" ] || reclamar "não voltou a convergir depois de tirar o rival recriado (rc=$rc)\n$saida"

# --- o seco não pode remover nada ---------------------------------------------
molde "$INSTALADO" > "$APPS/steam_app_$INSTALADO.desktop"
env -i PATH="$PATH" HOME="$H" USER="${USER:-t}" NO_COLOR=1 MEOW_DRY_RUN=1 \
  bash "$RAIZ/scripts/jogos_steam.sh" >/dev/null 2>&1
[ -f "$APPS/steam_app_$INSTALADO.desktop" ] \
  || reclamar "MEOW_DRY_RUN=1 REMOVEU o cartão duplicado — o seco não escreve nem apaga"

[ "$falhas" = "0" ] || exit 1
printf 'ok: um cartão por jogo, e o rival não volta a duplicar\n'

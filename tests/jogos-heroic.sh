#!/usr/bin/env bash
# UM JOGO INSTALADO NO HEROIC = UM CARTÃO NO LANÇADOR — e nada além disso.
#
# O DEFEITO QUE ESTE TESTE PEGA JÁ ACONTECEU, E ELA VIU
#   10/09/2026: "os jogos instalados pelo heroic launcher não aparecem nos
#   .desktop da interface". O Heroic só escreve atalho quando as chaves
#   `addDesktopShortcuts`/`addStartMenuShortcuts` estão ligadas — e elas nascem
#   desligadas —, então a biblioteca inteira ficava fora do lançador.
#
# AS AFIRMAÇÕES
#   1. o jogo instalado ganha cartão, com a marca `X-MeowSystem=jogo-heroic` e o
#      `Exec` do protocolo do próprio Heroic;
#   2. o DLC NÃO ganha cartão (`install.is_dlc`) — nesta máquina são dois
#      registros instalados para um jogo só, e o segundo é uma roupa de 327 KiB;
#   3. o jogo que está na biblioteca mas NÃO está instalado também não ganha;
#   4. rodar de novo dá o mesmo (rc=0) — idempotência;
#   5. o cartão que o PRÓPRIO Heroic escreve (nome do jogo no arquivo, sem molde
#      nenhum) sai, com cópia guardada antes — é o `Future Knight.desktop` de
#      09/09/2026 com outro sobrenome;
#   6. desinstalou o jogo, o cartão sai junto — e o ícone também;
#   7. o que aponta para OUTRO jogo do Heroic, sem substituto nosso, FICA:
#      remover deixaria esse jogo sem cartão nenhum;
#   8. o seco não escreve nem apaga;
#   9. biblioteca ilegível não é biblioteca vazia: não escreve, não apaga, e
#      devolve 3 — o contrário disto esvaziaria o lançador dela por causa de um
#      arquivo corrompido.
#
# POR QUE UM HOME DE BRINQUEDO
#   O território real é o lançador dela. Um teste que apaga `.desktop` de
#   verdade para ver se sabe apagar é o próprio defeito com outro nome.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$(mktemp -d)"; trap 'rm -rf "$H"' EXIT

APPS="$H/.local/share/applications"
CONF="$H/.var/app/com.heroicgameslauncher.hgl/config/heroic"
mkdir -p "$APPS" "$CONF/store_cache" "$CONF/legendaryConfig/legendary" "$CONF/icons"

JOGO=63a665088eb1480298f1e57943b225d8       # instalado
DLC=9596620d263b40c083ddf1f0c662c8ff        # instalado, e é DLC
FORA=aaaa1111bbbb2222cccc3333dddd4444       # na biblioteca, não instalado
ID="meow-heroic-legendary-$JOGO"

# A biblioteca, no formato que o Heroic 2.22.1 grava (medido em 10/09/2026).
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

# O que o backend escreve ao instalar. Quando o jogo sai, some daqui.
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
    bash "$RAIZ/scripts/jogos_heroic.sh" "$@" 2>&1
  return "$?"
}

falhas=0
reclamar() { printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas + 1)); }

# --- 1ª rodada: escreve o nosso -----------------------------------------------
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

# --- 2ª rodada: idempotência ---------------------------------------------------
saida="$(correr)"; rc=$?
[ "$rc" = "0" ] || reclamar "2ª rodada devolveu rc=$rc (esperado 0: convergiu)\n$saida"

# --- o cartão do próprio Heroic, com nome livre -------------------------------
# `shortcutFiles()` do `app.asar`: o arquivo se chama `<título>.desktop`. Nome
# com espaço, apóstrofo e nenhum molde — é por isso que a limpeza pergunta pelo
# conteúdo, e não pelo nome.
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

# E um cartão que aponta para OUTRO jogo do Heroic, que não temos. Ele fica:
# tirá-lo deixaria esse jogo sem cartão nenhum no lançador.
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

# --- o seco não escreve nem apaga ---------------------------------------------
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

# --- desinstalou: o cartão sai, e o ícone junto -------------------------------
biblioteca false
instalados ""
saida="$(correr)"; rc=$?
[ "$rc" = "1" ] || reclamar "com o jogo desinstalado, rc=$rc (esperado 1: tinha o que remover)\n$saida"
[ -e "$APPS/$ID.desktop" ] && reclamar "o cartão do jogo desinstalado continua no lançador"
if find "$H/.local/share/icons/hicolor" -name "$ID.png" 2>/dev/null | grep -q .; then
  reclamar "sobrou ícone do jogo desinstalado no hicolor"
fi

# --- biblioteca ilegível NÃO é biblioteca vazia -------------------------------
# O caso que apagaria o lançador dela por causa de um arquivo pela metade.
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

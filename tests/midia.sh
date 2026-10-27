#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$(mktemp -d)"; trap 'rm -rf "$H"' EXIT

APP_ID="io.github.meowsystem.NowPlaying"
BIN="$H/.local/bin/meowsystem-now-playing"
CONFIG="$H/.config/cosmic/$APP_ID/v1"
ESTADO="$H/.local/state/meowsystem"
MANIFESTO="$ESTADO/manifesto.tsv"

falhas=0; MARCA=0; CASO=""
caso()  { CASO="$1"; MARCA="$falhas"; }
fecha() { if [ "$falhas" = "$MARCA" ]; then printf 'ok:   %s\n' "$CASO"
          else printf 'ruim: %s\n' "$CASO" >&2; fi; }
reclamar() {
  printf 'FALHOU: %s\n' "$1" >&2
  if [ "$#" -gt 1 ] && [ -n "$2" ]; then printf '%s\n' "$2" | sed 's/^/        | /' >&2; fi
  falhas=$((falhas + 1))
}

correr() {
  local -a chaves=()
  while [ "$#" -gt 0 ] && [ "${1#*=}" != "$1" ]; do chaves+=("$1"); shift; done
  local script="$1"; shift
  env -i PATH="$PATH" HOME="$H" USER="${USER:-t}" NO_COLOR=1 \
      XDG_DATA_HOME="$H/.local/share" XDG_CONFIG_HOME="$H/.config" \
      XDG_CACHE_HOME="$H/.cache" MEOW_ESTADO="$ESTADO" \
      ${chaves[@]+"${chaves[@]}"} \
      bash "$RAIZ/scripts/$script" "$@" 2>&1
}

zerar() { [ -n "$H" ] && rm -rf "$H"; mkdir -p "$H"; }
arquivos() { (cd "$H" && find . -mindepth 1 ! -type d | sort); }

binario_falso() {
  mkdir -p "$(dirname "$BIN")"
  printf '#!/bin/sh\n' > "$BIN"
  chmod +x "$BIN"
}

chave_vale() {
  local tem
  tem="$(cat "$CONFIG/$1" 2>/dev/null)"
  [ "$tem" = "$2" ] || reclamar "a chave $1 diz '$tem' e devia dizer '$2'"
}

caso "1. sem o applet instalado nada é escrito, nem no seco"
zerar
antes="$(arquivos)"
saida="$(correr MEOW_DRY_RUN=1 midia.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "midia.sh no seco, sem binário, devolveu rc=$rc (esperado 3)" "$saida"
saida="$(correr midia.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "midia.sh, sem binário, devolveu rc=$rc (esperado 3)" "$saida"
[ "$(arquivos)" = "$antes" ] || reclamar "escreveu no HOME de teste sem o applet instalado"

binario_falso
antes="$(arquivos)"
saida="$(correr MEOW_DRY_RUN=1 midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "midia.sh no seco, com binário e sem chaves, devolveu rc=$rc (esperado 1)" "$saida"
[ "$(arquivos)" = "$antes" ] || reclamar "o seco escreveu no HOME de teste"
fecha

caso "2. as chaves vão para o cosmic-config do app id novo, e a segunda aplicação devolve 0"
zerar; binario_falso

saida="$(correr midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "1ª aplicação devolveu rc=$rc (esperado 1: gravou)" "$saida"
chave_vale panel_text_width  440
chave_vale panel_color_style '"traco"'
chave_vale album_art_remote  true
chave_vale panel_font_size   0
chave_vale panel_controls    false
grep -q '^"#[0-9a-f]\{6\}"$' "$CONFIG/title_color" 2>/dev/null \
  || reclamar "title_color não é um \"#rrggbb\" entre aspas: $(cat "$CONFIG/title_color" 2>/dev/null)"
grep -q '^"#[0-9a-f]\{6\}"$' "$CONFIG/artist_color" 2>/dev/null \
  || reclamar "artist_color não é um \"#rrggbb\" entre aspas"
grep -qF "$CONFIG/panel_text_width" "$MANIFESTO" 2>/dev/null \
  || reclamar "a chave não entrou no manifesto — o --uninstall a deixaria para trás"
[ -e "$H/.config/cosmic-ext-applet-now-playing" ] && reclamar "ainda escreve no diretório legado do patch"

saida="$(correr midia.sh)"; rc=$?
[ "$rc" = "0" ] || reclamar "2ª aplicação devolveu rc=$rc (esperado 0: já estava no lugar)" "$saida"
saida="$(correr midia.sh --conferir)"; rc=$?
[ "$rc" = "0" ] || reclamar "o --conferir depois de convergir devolveu rc=$rc (esperado 0)" "$saida"
fecha

caso "3. MIDIA=\"nao\" não grava nada"
zerar; binario_falso
saida="$(correr MIDIA=nao midia.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "com MIDIA=nao, o --aplicar devolveu rc=$rc (esperado 3)" "$saida"
[ -e "$CONFIG" ] && reclamar "com MIDIA=nao gravou em $CONFIG"
fecha

caso "4. valor inválido é recusado com aviso, e não gravado"
zerar; binario_falso

saida="$(correr MIDIA_LARGURA=5000 midia.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "MIDIA_LARGURA=5000 devolveu rc=$rc (esperado 3)" "$saida"
printf '%s' "$saida" | grep -q 'MIDIA_LARGURA' \
  || reclamar "MIDIA_LARGURA=5000 foi recusada em silêncio — o aviso tem de dizer a chave" "$saida"
[ -e "$CONFIG" ] && reclamar "MIDIA_LARGURA=5000 gravou em $CONFIG"

saida="$(correr MIDIA_COR_ALBUM=roxo midia.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "MIDIA_COR_ALBUM=roxo devolveu rc=$rc (esperado 3)" "$saida"
[ -e "$CONFIG" ] && reclamar "MIDIA_COR_ALBUM=roxo gravou em $CONFIG"

saida="$(correr MIDIA_CAPA=xis midia.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "MIDIA_CAPA=xis devolveu rc=$rc (esperado 3)" "$saida"
[ -e "$CONFIG" ] && reclamar "MIDIA_CAPA=xis gravou em $CONFIG — a capa teria sido desligada em silêncio"

saida="$(correr MIDIA_LARGURA=900 MIDIA_COR_ALBUM=chapado MIDIA_CAPA=nao MIDIA_FONTE=14 midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "os valores válidos no limite devolveram rc=$rc (esperado 1)" "$saida"
chave_vale panel_text_width  900
chave_vale panel_color_style '"chapado"'
chave_vale album_art_remote  false
chave_vale panel_font_size   14
fecha

caso "5. o --reverter tira as chaves e o cache, e o segundo não tem o que tirar"
zerar; binario_falso
correr midia.sh >/dev/null
mkdir -p "$H/.cache/meowsystem-now-playing/art"
saida="$(correr midia.sh --reverter)"; rc=$?
[ "$rc" = "1" ] || reclamar "o --reverter devolveu rc=$rc (esperado 1: mexeu)" "$saida"
[ -e "$CONFIG" ] && reclamar "o --reverter deixou as chaves em $CONFIG"
[ -e "$H/.cache/meowsystem-now-playing" ] && reclamar "o --reverter deixou o cache"
saida="$(correr midia.sh --reverter)"; rc=$?
[ "$rc" = "0" ] || reclamar "o --reverter sem nada para remover devolveu rc=$rc (esperado 0)" "$saida"
fecha

[ "$falhas" = "0" ] || { printf '\n%s caso(s) reprovado(s)\n' "$falhas" >&2; exit 1; }
printf '\nok: os cinco casos da configuração do applet de mídia passaram, sem compilar nada\n'

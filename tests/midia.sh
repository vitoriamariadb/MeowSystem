#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$(mktemp -d)"; trap 'rm -rf "$H"' EXIT

APP_ID="com.github.DiegoMMR.CosmicExtAppletNowPlaying"
RECEITA="$RAIZ/src/applets/now-playing"
PATCH="$RECEITA/0001-meow-capa-cor-controles.patch"

BIN="$H/.local/bin/meow-applet-now-playing"
SOMBRA="$H/.local/share/applications/$APP_ID.desktop"
CONFIG="$H/.config/cosmic-ext-applet-now-playing"
ESTADO="$H/.local/state/meowsystem"
CARIMBO="$ESTADO/midia/carimbo"
MANIFESTO="$ESTADO/manifesto.tsv"
RUSTUP="$H/.rustup/settings.toml"

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

caso "1. o seco não escreve um byte, nem o .rustup/settings.toml"
zerar
antes="$(arquivos)"

saida="$(correr MEOW_DRY_RUN=1 MIDIA_COMPILAR=1 midia_build.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "midia_build.sh no seco, sem binário, devolveu rc=$rc (esperado 1)" "$saida"

saida="$(correr MEOW_DRY_RUN=1 midia.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "midia.sh no seco, sem binário, devolveu rc=$rc (esperado 3)" "$saida"

binario_falso
comm_pino="$( set +u; . "$RECEITA/PINO" >/dev/null 2>&1; printf '%s' "${COMMIT:-}" )"
[ -n "$comm_pino" ] || reclamar "não consegui ler COMMIT de $RECEITA/PINO"
mkdir -p "$(dirname "$CARIMBO")"
{ printf 'patch %s\n'   "$(sha256sum -- "$PATCH" | cut -d' ' -f1)"
  printf 'commit %s\n'  "$comm_pino"
  printf 'binario %s\n' "$(sha256sum -- "$BIN" | cut -d' ' -f1)"
  printf 'rustc rustc 9.9.9 (carimbo de brinquedo)\n'
} > "$CARIMBO"
antes="$(arquivos)"

saida="$(correr MEOW_DRY_RUN=1 MIDIA_COMPILAR=1 midia_build.sh)"; rc=$?
[ "$rc" = "0" ] || reclamar "com o carimbo batendo, o seco devolveu rc=$rc (esperado 0: o campo rustc é pulado no seco)" "$saida"

saida="$(correr MEOW_DRY_RUN=1 midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "midia.sh no seco, com binário e sem sombra, devolveu rc=$rc (esperado 1)" "$saida"

saida="$(correr MEOW_DRY_RUN=1 midia.sh --reverter)"; rc=$?
[ "$rc" = "1" ] || reclamar "midia.sh --reverter no seco devolveu rc=$rc (esperado 1)" "$saida"

[ -f "$RUSTUP" ] && reclamar "o seco escreveu $RUSTUP — a guarda do _rustc_versao caiu"
depois="$(arquivos)"
sobra="$(comm -13 <(printf '%s\n' "$antes") <(printf '%s\n' "$depois"))"
[ -n "$sobra" ] && reclamar "o seco escreveu no HOME de teste:"$'\n'"$sobra"
sumiu="$(comm -23 <(printf '%s\n' "$antes") <(printf '%s\n' "$depois"))"
[ -n "$sumiu" ] && reclamar "o seco APAGOU do HOME de teste:"$'\n'"$sumiu"
fecha

caso "2. a segunda aplicação devolve 0 (comparação por conteúdo)"
zerar; binario_falso

saida="$(correr midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "1ª aplicação devolveu rc=$rc (esperado 1: instalou)" "$saida"
[ -f "$SOMBRA" ] || reclamar "a sombra não foi escrita em $SOMBRA" "$saida"
grep -qx "Exec=$BIN" "$SOMBRA" 2>/dev/null \
  || reclamar "o Exec= da sombra não aponta o nosso binário em caminho absoluto"
grep -qx "Icon=$APP_ID" "$SOMBRA" 2>/dev/null \
  || reclamar "a sombra perdeu o Icon= do flatpak — o ícone deixaria de resolver"
chave_vale panel-text-width  440
chave_vale panel-color-style traco
chave_vale album-art-remote  true
grep -qF "$SOMBRA" "$MANIFESTO" 2>/dev/null \
  || reclamar "a sombra não entrou no manifesto — o --uninstall a deixaria para trás"

saida="$(correr midia.sh)"; rc=$?
[ "$rc" = "0" ] || reclamar "2ª aplicação devolveu rc=$rc (esperado 0: já estava no lugar)" "$saida"

saida="$(correr midia.sh --conferir)"; rc=$?
[ "$rc" = "0" ] || reclamar "o --conferir depois de convergir devolveu rc=$rc (esperado 0)" "$saida"
fecha

caso "3. sombra órfã é removida (o pior modo de falha da família)"
zerar; binario_falso
correr midia.sh >/dev/null
rm -f "$BIN"

saida="$(correr midia.sh --conferir)"; rc=$?
[ "$rc" = "1" ] || reclamar "com a sombra órfã, o --conferir devolveu rc=$rc (esperado 1)" "$saida"

saida="$(correr MEOW_DRY_RUN=1 midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "com a sombra órfã, o seco devolveu rc=$rc (esperado 1)" "$saida"
[ -f "$SOMBRA" ] || reclamar "o SECO removeu a sombra órfã — ele só podia dizer que removeria"

saida="$(correr midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "ao remover a sombra órfã, devolveu rc=$rc (esperado 1)" "$saida"
[ -e "$SOMBRA" ] && reclamar "a sombra órfã continua em $SOMBRA — a dock ficaria sem applet nenhum" "$saida"

saida="$(correr midia.sh --conferir)"; rc=$?
[ "$rc" = "3" ] || reclamar "depois do fail-safe, o --conferir devolveu rc=$rc (esperado 3: nada a instalar)" "$saida"
fecha

caso "4. MIDIA=\"nao\" desliga de verdade"
zerar; binario_falso
correr midia.sh >/dev/null

saida="$(correr MIDIA=nao midia.sh --conferir)"; rc=$?
[ "$rc" = "1" ] || reclamar "com MIDIA=nao e tudo instalado, o --conferir devolveu rc=$rc (esperado 1)" "$saida"
[ -f "$SOMBRA" ] || reclamar "o --conferir REMOVEU a sombra — conferir é leitura pura"
[ -x "$BIN" ]    || reclamar "o --conferir REMOVEU o binário — conferir é leitura pura"

saida="$(correr MIDIA=nao midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "com MIDIA=nao, o --aplicar devolveu rc=$rc (esperado 1)" "$saida"
[ -e "$SOMBRA" ] && reclamar "com MIDIA=nao, a sombra sobreviveu ao --aplicar" "$saida"
[ -e "$BIN" ]    && reclamar "com MIDIA=nao, o binário sobreviveu ao --aplicar" "$saida"

saida="$(correr MIDIA=nao midia.sh --conferir)"; rc=$?
[ "$rc" = "3" ] || reclamar "com MIDIA=nao e nada instalado, o --conferir devolveu rc=$rc (esperado 3)" "$saida"

saida="$(correr MIDIA=nao MEOW_DRY_RUN=1 midia_build.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "com MIDIA=nao, o midia_build.sh devolveu rc=$rc (esperado 3: não é ele quem desliga)" "$saida"
fecha

caso "5. valor inválido é recusado com aviso, e não gravado"
zerar; binario_falso

saida="$(correr MIDIA_LARGURA=5000 midia.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "MIDIA_LARGURA=5000 devolveu rc=$rc (esperado 3)" "$saida"
printf '%s' "$saida" | grep -q 'MIDIA_LARGURA' \
  || reclamar "MIDIA_LARGURA=5000 foi recusada em silêncio — o aviso tem de dizer a chave" "$saida"
[ -e "$CONFIG" ] && reclamar "MIDIA_LARGURA=5000 gravou em $CONFIG"
[ -e "$SOMBRA" ] && reclamar "MIDIA_LARGURA=5000 escreveu a sombra"

saida="$(correr MIDIA_COR_ALBUM=roxo midia.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "MIDIA_COR_ALBUM=roxo devolveu rc=$rc (esperado 3)" "$saida"
printf '%s' "$saida" | grep -q 'MIDIA_COR_ALBUM' \
  || reclamar "MIDIA_COR_ALBUM=roxo foi recusada em silêncio" "$saida"
[ -e "$CONFIG" ] && reclamar "MIDIA_COR_ALBUM=roxo gravou em $CONFIG"
[ -e "$SOMBRA" ] && reclamar "MIDIA_COR_ALBUM=roxo escreveu a sombra"

saida="$(correr MIDIA_CAPA=xis midia.sh)"; rc=$?
[ "$rc" = "3" ] || reclamar "MIDIA_CAPA=xis devolveu rc=$rc (esperado 3)" "$saida"
[ -e "$CONFIG" ] && reclamar "MIDIA_CAPA=xis gravou em $CONFIG — a capa teria sido desligada em silêncio"

saida="$(correr MIDIA_LARGURA=900 MIDIA_COR_ALBUM=chapado MIDIA_CAPA=nao midia.sh)"; rc=$?
[ "$rc" = "1" ] || reclamar "os valores válidos no limite devolveram rc=$rc (esperado 1)" "$saida"
chave_vale panel-text-width  900
chave_vale panel-color-style chapado
chave_vale album-art-remote  false
fecha

caso "6. o --reverter tira a sombra ANTES do binário"
zerar; binario_falso
correr midia.sh >/dev/null
[ -f "$SOMBRA" ] && [ -x "$BIN" ] || reclamar "não consegui armar o estado do caso 6"

saida="$(correr midia.sh --reverter)"; rc=$?
[ "$rc" = "1" ] || reclamar "o --reverter devolveu rc=$rc (esperado 1: mexeu)" "$saida"
[ -e "$SOMBRA" ] && reclamar "o --reverter deixou a sombra em $SOMBRA" "$saida"
[ -e "$BIN" ]    && reclamar "o --reverter deixou o binário em $BIN" "$saida"
chave_vale panel-text-width 440

saida="$(correr midia.sh --reverter)"; rc=$?
[ "$rc" = "0" ] || reclamar "o --reverter sem nada para remover devolveu rc=$rc (esperado 0)" "$saida"

fonte="$RAIZ/scripts/midia.sh"
l_sombra="$(grep -nF 'rm -f "$SOMBRA"; mexeu=1' "$fonte" | cut -d: -f1)"
l_binario="$(grep -nF 'rm -f "$BINARIO"; mexeu=1' "$fonte" | cut -d: -f1)"
if [ "$(printf '%s\n' "$l_sombra" | grep -c .)" != "1" ] \
|| [ "$(printf '%s\n' "$l_binario" | grep -c .)" != "1" ]; then
  reclamar "não achei exatamente uma remoção de cada em _reverter — o teste da ordem precisa ser reescrito"
elif [ "$l_sombra" -ge "$l_binario" ]; then
  reclamar "o --reverter remove o binário (linha $l_binario) ANTES da sombra (linha $l_sombra) — isso abre a janela em que a dock fica sem applet nenhum"
fi
fecha

if command -v rustc >/dev/null 2>&1; then
  N="$H/nota-rustup"; mkdir -p "$N"
  env -i PATH="$PATH" HOME="$N" rustc -V >/dev/null 2>&1
  if [ -f "$N/.rustup/settings.toml" ]; then
    printf 'nota: sob env -i, o shim do rustup escreveu .rustup/settings.toml num HOME limpo\n'
    printf '      (é essa escrita que o _rustc_versao do midia_build.sh evita no seco)\n'
  fi
fi

[ "$falhas" = "0" ] || { printf '\n%s caso(s) reprovado(s)\n' "$falhas" >&2; exit 1; }
printf '\nok: os seis casos do applet de mídia passaram, sem compilar nada\n'

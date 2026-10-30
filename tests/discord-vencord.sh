#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
BIN="$T/bin"; CASA="$T/casa"; LOG="$T/chamadas"
mkdir -p "$BIN" "$CASA/.config/meow" "$T/estado"
: > "$LOG"
for b in sudo pkexec su pkill notify-send systemctl gsettings dconf busctl wget; do
  printf '#!/bin/sh\nexit 1\n' > "$BIN/$b"; chmod 755 "$BIN/$b"
done
printf '#!/bin/sh\nexit 1\n' > "$BIN/pgrep"; chmod 755 "$BIN/pgrep"

cat > "$T/instalador" <<'FIM'
#!/bin/sh
[ "$1" = "-install" ] && [ "$2" = "-location" ] || exit 2
app="$3"
printf 'instalador %s\n' "$app" >> "$MEOW_TESTE_LOG"
mv "$app/resources/app.asar" "$app/resources/_app.asar" || exit 1
printf 'require("Vencord/dist/patcher.js")' > "$app/resources/app.asar"
mkdir -p "$HOME/.config/Vencord/dist"
FIM
cat > "$BIN/curl" <<'FIM'
#!/bin/sh
destino=""
while [ $# -gt 0 ]; do
  [ "$1" = "-o" ] && destino="$2"
  shift
done
printf 'curl\n' >> "$MEOW_TESTE_LOG"
[ -n "$destino" ] && cp "$MEOW_TESTE_INSTALADOR" "$destino"
FIM
chmod 755 "$BIN/curl" "$T/instalador"
SHA="$(sha256sum "$T/instalador" | cut -d' ' -f1)"

CONF="$CASA/.config/discord"
printf 'ORIGINAL-ASAR-%s\n\000\001binario' "$$" > "$T/original.asar"
nova_versao() {
  mkdir -p "$CONF/app-$1/resources"
  cp "$T/original.asar" "$CONF/app-$1/resources/app.asar"
  printf '{"version": "%s"}\n' "$1" > "$CONF/app-$1/resources/build_info.json"
}

mod() {
  local v="$1"; shift
  env -i PATH="$BIN:$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" \
      XDG_DATA_HOME="$CASA/.local/share" MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$T/estado" \
      MEOW_VENCORD_SHA256="$SHA" MEOW_TESTE_LOG="$LOG" MEOW_TESTE_INSTALADOR="$T/instalador" \
      MEOW_VENCORD_URL="https://exemplo.invalido/instalador" \
      PACK=dracula FLAVOR=dracula NO_COLOR=1 "$@" \
      bash -c '. "$MEOW_RAIZ/lib/comum.sh" || exit 2
               . "$MEOW_RAIZ/scripts/temas-de-apps/discord/manifesto.sh" || exit 2
               meow_app_$0' "$v" </dev/null 2>&1
}
retrato() { (cd "$CASA" && find . -type f -printf '%p %s %T@\n' | sort); }
chamadas() { grep -c "^$1" "$LOG"; }
tem_vencord() { grep -qa Vencord "$CONF/app-$1/resources/app.asar" && cmp -s "$T/original.asar" "$CONF/app-$1/resources/_app.asar"; }

nova_versao 1.0.1
saida="$(mod aplicar)"; rc=$?
[ "$rc" = 1 ] && tem_vencord 1.0.1 && [ "$(chamadas instalador)" = 1 ] \
  && ok "1. Discord oficial sem cliente modificado: a primeira passada injeta o Vencord no app-<versão> e guarda o app.asar original" \
  || falha "1. a primeira passada não injetou o Vencord (rc=$rc)" "$saida"
[ -f "$CASA/.config/Vencord/themes/MeowSystem.theme.css" ] \
  && grep -q enabledThemes "$CASA/.config/Vencord/settings/settings.json" \
  && ok "1. o tema do pack entra na pasta themes/ do Vencord e fica ligado" \
  || falha "1. o tema do pack não entrou no Vencord" "$saida"
saida="$(mod conferir)"; rc=$?
[ "$rc" = 0 ] && ok "1. depois de injetar, o conferir dá 0" || falha "1. conferir devolveu $rc" "$saida"

antes="$(retrato)"; n_antes="$(wc -l < "$LOG")"
saida="$(mod aplicar)"; rc=$?
[ "$rc" = 0 ] && [ "$antes" = "$(retrato)" ] && [ "$(wc -l < "$LOG")" = "$n_antes" ] \
  && ok "2. a segunda passada não escreve nem chama o instalador" \
  || falha "2. a segunda passada escreveu ou chamou o instalador (rc=$rc)" "$saida
$(diff <(printf '%s\n' "$antes") <(retrato))"
[ "$(chamadas curl)" = 1 ] \
  && ok "2. o instalador foi baixado uma vez, com o sha256 conferido, e fica guardado" \
  || falha "2. o instalador foi baixado $(chamadas curl) vezes"

nova_versao 1.0.2
saida="$(mod conferir)"; rc=$?
[ "$rc" = 1 ] && ok "3. um app-<versão> novo sem o Vencord faz o conferir acusar" || falha "3. o conferir não acusou o app novo (rc=$rc)" "$saida"
saida="$(mod aplicar)"; rc=$?
[ "$rc" = 1 ] && tem_vencord 1.0.2 && [ "$(chamadas instalador)" = 2 ] && [ "$(chamadas curl)" = 1 ] \
  && ok "3. a passada seguinte injeta no app novo, sem baixar de novo" \
  || falha "3. o app novo não foi injetado (rc=$rc)" "$saida"

nova_versao 1.0.3
printf '#!/bin/sh\n[ "$2" = Discord ] && exit 0\nexit 1\n' > "$BIN/pgrep"; chmod 755 "$BIN/pgrep"
n_antes="$(chamadas instalador)"
saida="$(mod aplicar)"; rc=$?
[ "$rc" = 3 ] && [ "$(chamadas instalador)" = "$n_antes" ] && ! grep -qa Vencord "$CONF/app-1.0.3/resources/app.asar" \
  && ok "4. com o Discord aberto, nada é injetado e a passada sai pendente" \
  || falha "4. o Discord aberto não segurou a injeção (rc=$rc)" "$saida"
printf '#!/bin/sh\nexit 1\n' > "$BIN/pgrep"; chmod 755 "$BIN/pgrep"

saida="$(mod conferir DISCORD_VENCORD=nao)"; rc=$?
[ "$rc" = 1 ] && printf '%s\n' "$saida" | grep -q 'o Vencord está em' \
  && ok "5. com DISCORD_VENCORD=nao, o Vencord que está no disco faz o conferir acusar" \
  || falha "5. o conferir com DISCORD_VENCORD=nao não acusou o Vencord no disco (rc=$rc)" "$saida"
printf '#!/bin/sh\n[ "$2" = Discord ] && exit 0\nexit 1\n' > "$BIN/pgrep"; chmod 755 "$BIN/pgrep"
saida="$(mod aplicar DISCORD_VENCORD=nao)"; rc=$?
[ "$rc" = 3 ] && tem_vencord 1.0.1 && tem_vencord 1.0.2 \
  && ok "5. com o Discord aberto, DISCORD_VENCORD=nao não mexe no app.asar e a passada sai pendente" \
  || falha "5. DISCORD_VENCORD=nao mexeu no Discord aberto (rc=$rc)" "$saida"
printf '#!/bin/sh\nexit 1\n' > "$BIN/pgrep"; chmod 755 "$BIN/pgrep"
saida="$(mod aplicar DISCORD_VENCORD=nao)"; rc=$?
if [ "$rc" = 1 ] && ! grep -qa Vencord "$CONF/app-1.0.3/resources/app.asar" && [ "$(chamadas instalador)" = "$n_antes" ] \
   && cmp -s "$T/original.asar" "$CONF/app-1.0.1/resources/app.asar" \
   && cmp -s "$T/original.asar" "$CONF/app-1.0.2/resources/app.asar" \
   && [ ! -e "$CONF/app-1.0.1/resources/_app.asar" ] && [ ! -e "$CONF/app-1.0.2/resources/_app.asar" ]; then
  ok "5. com DISCORD_VENCORD=nao o meow não injeta e tira o Vencord de cada app-<versão>, com o app.asar original byte a byte"
else
  falha "5. DISCORD_VENCORD=nao não tirou o Vencord (rc=$rc)" "$saida"
fi
antes="$(retrato)"
saida="$(mod aplicar DISCORD_VENCORD=nao)"; rc=$?
[ "$rc" = 0 ] && [ "$antes" = "$(retrato)" ] && [ "$(mod conferir DISCORD_VENCORD=nao >/dev/null; echo $?)" = 0 ] \
  && ok "5. a segunda passada com DISCORD_VENCORD=nao não escreve, e o conferir dá 0" \
  || falha "5. a segunda passada com DISCORD_VENCORD=nao escreveu ou não fechou (rc=$rc)" "$saida"

rm -rf "$CASA/.local/share/meowsystem/vencord"
saida="$(mod aplicar MEOW_VENCORD_SHA256=0000000000000000000000000000000000000000000000000000000000000000)"; rc=$?
[ "$rc" = 2 ] && ! grep -qa Vencord "$CONF/app-1.0.3/resources/app.asar" \
  && ok "6. instalador com sha256 diferente do pinado: erro e nada injetado" \
  || falha "6. o sha256 errado não foi recusado (rc=$rc)" "$saida"

saida="$(mod aplicar)"; rc=$?
[ "$rc" = 1 ] && tem_vencord 1.0.3 \
  && ok "6. de volta a sim, com o sha256 certo, o Vencord entra de novo no app mais novo" \
  || falha "6. o Vencord não voltou com DISCORD_VENCORD=sim (rc=$rc)" "$saida"

printf 'APPS_ATIVOS="kitty,discord"\n' > "$CASA/.config/meow/meow.conf"
saida="$(mod reverter MEOW_CONF="$CASA/.config/meow/meow.conf")"; rc=$?
if [ "$rc" = 1 ] && cmp -s "$T/original.asar" "$CONF/app-1.0.1/resources/app.asar" \
   && cmp -s "$T/original.asar" "$CONF/app-1.0.3/resources/app.asar" \
   && [ ! -e "$CONF/app-1.0.3/resources/_app.asar" ] && [ ! -e "$CASA/.config/Vencord/themes/MeowSystem.theme.css" ]; then
  ok "7. reverter devolve o app.asar original byte a byte e tira o tema"
else
  falha "7. o reverter não devolveu o app.asar original (rc=$rc)" "$saida"
fi
grep -qx 'APPS_ATIVOS="kitty"' "$CASA/.config/meow/meow.conf" \
  && ok "7. reverter desliga o Discord do APPS_ATIVOS, para o doctor não reinjetar" \
  || falha "7. o Discord continua no APPS_ATIVOS" "$(cat "$CASA/.config/meow/meow.conf")"
printf '%s\n' "$saida" | grep -qiE 'meow\.conf|\babra\b|\brode\b|digite' \
  && falha "7. a saída do reverter manda editar ou digitar" "$saida" \
  || ok "7. a saída do reverter diz só o fato"
antes="$(retrato)"
saida="$(mod reverter MEOW_CONF="$CASA/.config/meow/meow.conf")"; rc=$?
[ "$rc" = 0 ] && [ "$antes" = "$(retrato)" ] \
  && ok "7. a segunda passada do reverter não escreve" \
  || falha "7. a segunda passada do reverter escreveu (rc=$rc)" "$saida"

grep -q 'flatpak oficial' "$RAIZ/packs/dracula/pack.json" \
  && falha "8. a nota do Discord no pack Dracula ainda diz que o Discord é o flatpak oficial" \
  || ok "8. a nota do Discord no pack Dracula não diz mais que é o flatpak oficial"

[ "$falhas" -eq 0 ] || { printf '\n%d falha(s)\n' "$falhas" >&2; exit 1; }
printf '\ntudo certo\n'

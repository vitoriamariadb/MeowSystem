#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
BIN="$T/bin"; CASA="$T/casa"; mkdir -p "$BIN" "$CASA/.local/share/fonts" "$CASA/.config"
for x in sudo pkexec su apt apt-get systemctl pkill; do
  printf '#!/bin/sh\necho "recusado: %s" >&2\nexit 1\n' "$x" > "$BIN/$x"; chmod +x "$BIN/$x"
done
printf '#!/bin/sh\necho "$@" >> %s/rede.log\nexit 7\n' "$T" > "$BIN/curl"; chmod +x "$BIN/curl"
printf '#!/bin/sh\necho "$@" >> %s/rede.log\nexit 7\n' "$T" > "$BIN/wget"; chmod +x "$BIN/wget"

amb() {
  HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" XDG_CACHE_HOME="$CASA/.cache" \
  XDG_STATE_HOME="$CASA/.state" XDG_DATA_HOME="$CASA/.local/share" \
  PATH="$BIN:$PATH" DBUS_SESSION_BUS_ADDRESS= NO_COLOR=1 "$@"
}

printf '\n--- 1. a fonte do terminal sai do pack, sem rede ---\n'
saida="$(amb bash "$RAIZ/scripts/instalar_fontes.sh" 2>&1)"; rc=$?
n="$(ls "$CASA/.local/share/fonts/MeowSystem"/JetBrainsMonoNerdFontMono-*.ttf 2>/dev/null | wc -l)"
if [ "$n" = 16 ] && [ ! -s "$T/rede.log" ]; then
  ok "instalar_fontes.sh: 16 faces da JetBrainsMono Nerd Font Mono instaladas sem tocar na rede"
else
  falha "instalar_fontes.sh: $n faces e/ou chamou a rede ($(cat "$T/rede.log" 2>/dev/null))" "$saida"
fi
saida="$(amb bash "$RAIZ/scripts/instalar_fontes.sh" 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "instalar_fontes.sh: a segunda passada não escreve nada" \
  || falha "instalar_fontes.sh: a segunda passada escreveu (rc=$rc)" "$saida"
if grep -qE 'curl .*(nerd-fonts|NERD_URL)|NERD_URL' "$RAIZ/scripts/instalar_fontes.sh"; then
  falha "instalar_fontes.sh ainda tem o endereço de download da Nerd Font"
else
  ok "instalar_fontes.sh não guarda mais o endereço de download da Nerd Font"
fi
[ -f "$RAIZ/packs/meowsystem/fontes/PROCEDENCIA.md" ] && grep -q 'OFL-1.1' "$RAIZ/packs/meowsystem/fontes/PROCEDENCIA.md" \
  && ok "a fonte tem procedência e licença ao lado" || falha "a fonte do pack não tem procedência"

printf '\n--- 1b. a fonte solta na pasta de antes vai para o pack e continua instalada ---\n'
R="$T/raiz"
mkdir -p "$R/scripts" "$R/packs/meowsystem/fontes/locais" "$R/assets/fontes/locais"
ln -s "$RAIZ/scripts/lib" "$R/scripts/lib"
cp "$RAIZ/scripts/instalar_fontes.sh" "$R/scripts/"
ln -s "$RAIZ/packs/meowsystem/fontes/JetBrainsMono.tar.xz" "$R/packs/meowsystem/fontes/JetBrainsMono.tar.xz"
printf 'uma fonte de mentira\n' > "$R/assets/fontes/locais/zrnic rg.otf"
mkdir -p "$CASA/.local/share/fonts/MeowSystem/locais"
cp "$R/assets/fontes/locais/zrnic rg.otf" "$CASA/.local/share/fonts/MeowSystem/locais/"
seco="$(amb env MEOW_DRY_RUN=1 bash "$R/scripts/instalar_fontes.sh" --conferir 2>&1)"
saida="$(amb bash "$R/scripts/instalar_fontes.sh" 2>&1)"
if grep -q 'levaria a fonte local zrnic rg.otf' <<< "$seco" \
   && [ -f "$R/packs/meowsystem/fontes/locais/zrnic rg.otf" ] && [ ! -e "$R/assets/fontes" ] \
   && [ -f "$CASA/.local/share/fonts/MeowSystem/locais/zrnic rg.otf" ]; then
  ok "a fonte de assets/fontes/locais/ vai para packs/meowsystem/fontes/locais/, a pasta velha some e a instalada fica"
else
  falha "a fonte da pasta de antes não migrou, ou a instalada foi tirada" "$seco
$saida"
fi
saida="$(amb bash "$R/scripts/instalar_fontes.sh" 2>&1)"; rc=$?
[ "$rc" = 0 ] && ok "a passada depois da migração não escreve nada" || falha "a passada depois da migração escreveu (rc=$rc)" "$saida"

printf '\n--- 2. a interface não oferece download ---\n'
if grep -q 'spotify_baixar_tema' "$RAIZ/scripts/app/servidor.py" "$RAIZ"/scripts/app/pagina/*.js; then
  falha "a ação spotify_baixar_tema ainda existe"
else
  ok "não há ação nem botão «Baixar» do tema do Spotify"
fi

[ "$falhas" = 0 ] && { printf '\nTudo certo.\n'; exit 0; }
printf '\n%s falha(s).\n' "$falhas" >&2; exit 1

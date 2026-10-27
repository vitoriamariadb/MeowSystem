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

printf '\n--- 2. o tema do Spotify é arte do pack ---\n'
( cd "$RAIZ/packs/meowsystem/temas-de-apps/spotify" && sha256sum --status -c SHA256SUMS ) \
  && ok "spotify: os 64 arquivos do tema conferem no SHA256SUMS" || falha "spotify: o SHA256SUMS não confere"
arq="$(python3 "$RAIZ/scripts/pack.py" app meowsystem apps.spotify.arquivo 2>/dev/null | sed -n 's/^valor=//p')"
[ -n "$arq" ] && [ -f "$arq" ] && ok "spotify: o pack declara o color.ini que traz (${arq#"$RAIZ"/})" \
  || falha "spotify: o pack não declara o tema que traz"
org="$(python3 "$RAIZ/scripts/pack.py" app meowsystem apps.spotify.origem.repo 2>/dev/null | sed -n 's/^valor=//p')"
[ -z "$org" ] && ok "spotify: o pack não tem mais origem de rede" || falha "spotify: o pack ainda aponta para $org"

printf '\n--- 3. a interface não oferece download ---\n'
if grep -q 'spotify_baixar_tema' "$RAIZ/app/servidor.py" "$RAIZ"/app/pagina/*.js; then
  falha "a ação spotify_baixar_tema ainda existe"
else
  ok "não há ação nem botão «Baixar» do tema do Spotify"
fi

[ "$falhas" = 0 ] && { printf '\nTudo certo.\n'; exit 0; }
printf '\n%s falha(s).\n' "$falhas" >&2; exit 1

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }

eval "$(sed -n '/^_binario_da_linha() {/,/^}/p;/^_e_chromium() {/,/^}/p' "$RAIZ/app/run.sh")"

quem() { _binario_da_linha "$1" || true; }

confere() {
  local titulo="$1" linha="$2" quer="$3" tem
  tem="$(quem "$linha")"
  if [ "$tem" = "$quer" ]; then ok "$titulo"; else falha "$titulo (deu «$tem», queria «$quer»)"; fi
}

printf '\no lançador do navegador padrão chega ao binário de verdade\n'
confere "linha direta" '/usr/bin/google-chrome-stable' /usr/bin/google-chrome-stable
confere "com env e variável" 'env GDK_BACKEND=wayland /usr/bin/brave-browser --flag' /usr/bin/brave-browser
confere "com systemd-run e slice" \
  'systemd-run --user --slice=browser.slice --scope --quiet -- /usr/bin/google-chrome-stable --load-extension=/x' \
  /usr/bin/google-chrome-stable
confere "com systemd-run pelo caminho" '/usr/bin/systemd-run --user --scope -- env A=1 chromium' chromium
confere "navegador sem Chromium segue sendo ele" 'firefox' firefox

if _e_chromium "$(quem 'systemd-run --user --slice=browser.slice --scope --quiet -- /usr/bin/google-chrome-stable')"; then
  ok "o Chrome atrás do systemd-run ganha a janela própria"
else
  falha "o Chrome atrás do systemd-run caiu em aba comum"
fi

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'painel-janela-propria: tudo verde\n'; exit 0; fi
printf 'painel-janela-propria: %s falha(s)\n' "$falhas"; exit 1

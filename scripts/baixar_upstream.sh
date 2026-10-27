#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

DESTINO="$MEOW_CACHE/upstream"

FONTES=(
  "https://github.com/catppuccin/papirus-folders.git|papirus-folders|f83671d17ea67e335b34f8028a7e6d78bca735d7"
)

meow_tem git || { meow_erro "git não encontrado"; exit "$MEOW_SEM_DEPENDENCIA"; }

mkdir -p "$DESTINO"
mudou=0

for linha in "${FONTES[@]}"; do
  IFS='|' read -r url pasta commit <<< "$linha"
  alvo="$DESTINO/$pasta"

  if [ -d "$alvo/.git" ]; then
    atual="$(git -C "$alvo" rev-parse HEAD 2>/dev/null)"
    if [ "$atual" = "$commit" ]; then
      meow_ok "$pasta já em ${commit:0:8}"
      continue
    fi
    meow_info "$pasta está em ${atual:0:8}, quero ${commit:0:8}"
  fi

  if meow_seco; then
    meow_muda "baixaria $pasta em ${commit:0:8}"
    mudou=1
    continue
  fi

  rm -rf "$alvo"
  if ! git clone -q --depth 50 "$url" "$alvo" 2>/dev/null; then
    meow_aviso "não consegui clonar $url (sem rede?) — fica para o próximo ciclo"
    meow_info "  as pastas coloridas do Papirus ficam como estão até haver rede"
    exit "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! git -C "$alvo" checkout -q "$commit" 2>/dev/null; then
    git -C "$alvo" fetch -q --unshallow 2>/dev/null || true
    git -C "$alvo" checkout -q "$commit" || {
      meow_erro "commit $commit não existe em $url"
      exit "$MEOW_ERRO"
    }
  fi
  meow_ok "$pasta baixado em ${commit:0:8}"
  mudou=1
done

[ "$mudou" = "1" ] && exit "$MEOW_DIVERGENTE"
exit "$MEOW_OK"

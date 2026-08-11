#!/usr/bin/env bash
# O seco não escreve NADA fora do próprio lock.
#
# JÁ FALHOU UMA VEZ, E EM SILÊNCIO: a fase de DETECÇÃO chamava
# `code --list-extensions` e `flatpak info`, e cada um deixava rastro no HOME —
# oito arquivos, medidos em 10/08/2026 num HOME criado do zero. Nenhum deles é
# configuração, então nenhuma trava pegava: o que quebrava era a única promessa
# que o README faz sobre auditoria.
#
# `MEOW_IGNORA_DESKTOP=1` porque o pré-voo recusa máquina sem COSMIC, e este
# teste tem de rodar em qualquer lugar — inclusive num CI sem sessão gráfica.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$(mktemp -d)"; trap 'rm -rf "$H"' EXIT

env -i PATH="$PATH" HOME="$H" USER="${USER:-t}" \
  MEOW_DRY_RUN=1 MEOW_IGNORA_DESKTOP=1 NO_COLOR=1 \
  bash "$RAIZ/install.sh" >/dev/null 2>&1

sobra="$(cd "$H" && find . -type f ! -path './.local/state/meowsystem/lock')"
if [ -n "$sobra" ]; then
  printf 'FALHOU: MEOW_DRY_RUN=1 escreveu:\n%s\n' "$sobra" >&2
  exit 1
fi
printf 'ok: o seco não escreveu nada\n'

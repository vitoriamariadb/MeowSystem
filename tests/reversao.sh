#!/usr/bin/env bash
# O `--uninstall` desfaz TODO módulo de aplicativo, e não só os que alguém
# lembrou de cobrir.
#
# O DEFEITO QUE ESTE TESTE PEGA JÁ ACONTECEU, E DUROU MESES
#   Até 11/08/2026 o `install.sh --uninstall` não chamava `aplicar_apps.sh
#   reverter` nenhuma vez. O manifesto levava embora tudo que passa pela
#   `meow_escrever`, e por isso a desinstalação PARECIA completa — mas o Spotify
#   continuava com o tema do spicetify, o ZapZap continuava chamando-se
#   "WhatsApp" com o `.desktop` do export trocado, e o GTK continuava com o
#   symlink religado. Nada disso está no manifesto, por desenho: são mutações
#   fora da `meow_escrever`, e é justamente por isso que precisam de um verbo
#   próprio.
#
#   O buraco não deu erro em lugar nenhum. Foi preciso alguém perguntar "o
#   install e o uninstall estão pareados?" para ele aparecer.
#
# SÃO DUAS AFIRMAÇÕES, E A SEGUNDA É A QUE ENVELHECE
#   1. o desinstalador chama o `reverter` — uma linha, quebra alto se sumir;
#   2. TODO módulo em `app-themes/` define `meow_app_reverter` — esta é a que
#      apodrece sozinha: um módulo novo nasce com `detectar/conferir/aplicar`
#      (é o que o contrato exige) e o quarto verbo é opcional no runner. Sem
#      este teste, o primeiro app-tema escrito depois de hoje volta a ficar
#      para trás no `--uninstall`, em silêncio.
#
# POR QUE `declare -F` NUM SUBSHELL, E NÃO UM `grep`
#   `grep -q meow_app_reverter` passaria com a palavra dentro de um comentário —
#   e este projeto tem cabeçalhos que citam os nomes das funções o tempo todo.
#   O que importa é a função EXISTIR depois do `source`, que é exatamente como o
#   `rodar_modulo` a procura.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
falhou=0

# --- 1. o desinstalador chama o runner --------------------------------------
if ! grep -qE 'aplicar_apps\.sh" reverter' "$RAIZ/lib/desinstalar.sh"; then
  printf 'FALHOU: lib/desinstalar.sh não chama "aplicar_apps.sh reverter"\n' >&2
  printf '        os temas por aplicativo ficariam na máquina depois do --uninstall\n' >&2
  falhou=1
fi

# --- 2. todo módulo sabe desfazer -------------------------------------------
# `MEOW_IGNORA_DESKTOP=1` e o `lib/comum.sh` antes: os módulos são escritos para
# serem `source` DEPOIS dele (usam meow_ok, MEOW_OK, meow_seco). Carregá-los
# soltos daria "comando não encontrado" e um falso positivo de sintaxe.
for mod in "$RAIZ"/app-themes/*/manifesto.sh; do
  nome="$(basename "$(dirname "$mod")")"
  if ! (
        set +u
        MEOW_IGNORA_DESKTOP=1 NO_COLOR=1
        # shellcheck source=../lib/comum.sh
        . "$RAIZ/lib/comum.sh" >/dev/null 2>&1
        # shellcheck disable=SC1090
        . "$mod" >/dev/null 2>&1
        declare -F meow_app_reverter >/dev/null
      ); then
    printf 'FALHOU: o módulo %s não define meow_app_reverter\n' "$nome" >&2
    printf '        ele ficaria aplicado na máquina depois de ./install.sh --uninstall\n' >&2
    falhou=1
  fi
done

[ "$falhou" = "0" ] || exit 1
printf 'ok: o --uninstall desfaz os %s módulos de aplicativo\n' \
  "$(find "$RAIZ/app-themes" -mindepth 1 -maxdepth 1 -type d | wc -l)"

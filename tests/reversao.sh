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
# SÃO TRÊS AFIRMAÇÕES, E AS DUAS ÚLTIMAS SÃO AS QUE ENVELHECEM
#   1. o desinstalador chama o `reverter` — uma linha, quebra alto se sumir;
#   2. TODO módulo em `assets/temas-de-apps/` define `meow_app_reverter` — esta é a que
#      apodrece sozinha: um módulo novo nasce com `detectar/conferir/aplicar`
#      (é o que o contrato exige) e o quarto verbo é opcional no runner. Sem
#      este teste, o primeiro app-tema escrito depois de hoje volta a ficar
#      para trás no `--uninstall`, em silêncio.
#   3. TODA unidade de `systemd/` está nas DUAS listas do desinstalador — a que
#      APAGA o arquivo (o `find`) e a que PARA a unidade viva (o
#      `systemctl --user disable --now`). Acrescentada em 09/09/2026, e pelo
#      mesmo motivo da 2: o `lib/desinstalar.sh` já trazia o comentário
#      *"toda unidade nova entra nas DUAS"* — e o `meow-qt.{path,service}`,
#      nascido naquele dia, entrou só numa. A frase estava lá desde 01/09,
#      quando as três unidades da Sprint W tinham cometido exatamente o mesmo
#      erro. **Uma regra que só existe como comentário é uma regra que se
#      repete**: da segunda vez, quem cobra é este bloco.
#
#      O sintoma que ele evita não é cosmético: o `find` apaga o arquivo de uma
#      unidade que continua ATIVA, e sobra processo rodando sem arquivo. No
#      `meow-painel.service` isso é um supervisor com `Restart=on-failure`
#      batendo num binário que o passo seguinte apagou.
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
for mod in "$RAIZ"/assets/temas-de-apps/*/manifesto.sh; do
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

# --- 3. toda unidade está nas DUAS listas do desinstalador -------------------
# A lista NOMEADA é a do `systemctl --user disable --now`, e é a que apodrece:
# o `find -name 'meow-*' -delete` pega qualquer unidade nova de graça, então
# esquecer a outra metade não dá erro nenhum — dá processo órfão.
#
# Comparo contra `systemd/`, que é a fonte: é de lá que o `install.sh` copia
# para `~/.config/systemd/user`. Uma unidade que exista no repositório e não
# esteja na lista é o defeito; o contrário (nome na lista sem arquivo) é
# inofensivo, porque `disable` de unidade inexistente é justamente o estado que
# se quer, e o `|| true` de lá já conta isso.
nomeadas="$(sed -n '/systemctl --user disable --now/,/2>\/dev\/null/p' \
              "$RAIZ/lib/desinstalar.sh" \
            | grep -oE 'meow-[a-z-]+\.(path|service|timer)' | sort -u)"
if [ -z "$nomeadas" ]; then
  printf 'FALHOU: não achei o "systemctl --user disable --now" em lib/desinstalar.sh\n' >&2
  printf '        (o comando mudou de forma? esta afirmação precisa ser reescrita)\n' >&2
  falhou=1
else
  for u in "$RAIZ"/systemd/meow-*.path "$RAIZ"/systemd/meow-*.service "$RAIZ"/systemd/meow-*.timer; do
    [ -e "$u" ] || continue
    nome="$(basename "$u")"
    printf '%s\n' "$nomeadas" | grep -qx "$nome" && continue
    printf 'FALHOU: %s existe em systemd/ e NÃO está no "disable --now" do desinstalador\n' "$nome" >&2
    printf '        o --uninstall apagaria o arquivo dela com a unidade ainda ativa\n' >&2
    falhou=1
  done
fi

[ "$falhou" = "0" ] || exit 1
printf 'ok: o --uninstall desfaz os %s módulos de aplicativo\n' \
  "$(find "$RAIZ/assets/temas-de-apps" -mindepth 1 -maxdepth 1 -type d | wc -l)"
printf 'ok: as %s unidades de systemd/ estão nas duas listas do desinstalador\n' \
  "$(find "$RAIZ/systemd" -maxdepth 1 -name 'meow-*' -type f | wc -l)"

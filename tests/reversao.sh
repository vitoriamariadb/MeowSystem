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
# SÃO QUATRO AFIRMAÇÕES, E AS TRÊS ÚLTIMAS SÃO AS QUE ENVELHECEM
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
#   4. TODO módulo que já usa `meow_app_sem` declara o motivo em CADA saída de
#      pendência do `detectar` — acrescentada em 21/09/2026, quando o log disse
#      "Spotify não instalado" para um Spotify instalado. O bloco 4 lá embaixo
#      explica as duas cobranças; esta é a que nasce velha se alguém migrar um
#      módulo pela metade, e o custo de falhar nela é o log mentir de novo.
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

# --- 4. o motivo da pendência viaja junto com o código 3 --------------------
# POR QUE ESTA AFIRMAÇÃO MORA AQUI
#   Este arquivo já é o teste do CONTRATO dos módulos de aplicativo — do verbo
#   que um módulo novo esquece de escrever. O motivo é a segunda cláusula do
#   mesmo contrato, e esquecê-la custa o mesmo: em 21/09/2026 o log do
#   install.sh dizia "Spotify não instalado" para um Spotify instalado,
#   patchado e tematizado, porque o `meow_app_detectar` sabia a causa (faltava o
#   tema catppuccin do spicetify) e devolvia só o número 3.
#
# SÃO DUAS COBRANÇAS, E NENHUMA DAS DUAS SOZINHA BASTA
#   A ESTÁTICA pega o caminho que esta máquina não percorre hoje: num módulo
#   migrado, NENHUMA saída-3 do `detectar` pode escapar do `meow_app_sem` — é
#   ele que guarda o motivo, e sair por outra porta é sair mudo. É a cobrança
#   que o risco da sprint nomeia: um módulo com vários `return 3` precisa do
#   motivo em CADA um, e só o grep vê todos.
#   A DINÂMICA pega o que o grep não vê: roda o `detectar` de verdade e, se ele
#   disser 3 aqui e agora, cobra o motivo. Foi por este caminho que o Spotify
#   mentiu, e é ele que passaria batido numa conferência só de texto.
#
#   MÓDULO NÃO MIGRADO PASSA BATIDO DE PROPÓSITO. Quem se declara sujeito ao
#   contrato é o próprio arquivo, por usar `meow_app_sem` — uma lista de
#   migrados escrita aqui seria a armadilha nº 3 do projeto de novo.
migrados=0
for mod in "$RAIZ"/assets/temas-de-apps/*/manifesto.sh; do
  nome="$(basename "$(dirname "$mod")")"
  grep -q 'meow_app_sem' "$mod" || continue
  migrados=$((migrados + 1))

  corpo="$(sed -n '/^meow_app_detectar() {/,/^}/p' "$mod")"
  if [ -z "$corpo" ]; then
    printf 'FALHOU: não achei o meow_app_detectar de %s para conferir\n' "$nome" >&2
    printf '        (a função mudou de forma? esta afirmação precisa ser reescrita)\n' >&2
    falhou=1
    continue
  fi
  if printf '%s\n' "$corpo" | grep -q 'MEOW_SEM_DEPENDENCIA'; then
    printf 'FALHOU: o meow_app_detectar de %s sai com 3 por fora do meow_app_sem\n' "$nome" >&2
    printf '        essa saída não guarda motivo, e o aplicar imprimiria a causa errada\n' >&2
    falhou=1
  fi
  if ! printf '%s\n' "$corpo" | grep -q 'MEOW_APP_MOTIVO=""'; then
    printf 'FALHOU: o meow_app_detectar de %s não zera o MEOW_APP_MOTIVO ao começar\n' "$nome" >&2
    printf '        um motivo velho de outra chamada seria impresso como se fosse medido agora\n' >&2
    falhou=1
  fi

  # A dinâmica, e O ESTADO VAI PARA UM DESCARTÁVEL — corrigido em 22/09/2026.
  #   Este comentário dizia que `detectar` é leitura pura e que rodá-lo "não
  #   escreve um byte na máquina de ninguém". Deixou de ser verdade na sprint
  #   P2: o `detectar` do Spotify registra pendência (é o desenho dela), e a
  #   pendência mora em `$MEOW_ESTADO/pendencias.tsv`. Medido: a suíte criava
  #   aquele arquivo no HOME REAL de quem rodasse o teste.
  #
  #   O conserto é apontar `MEOW_ESTADO` para um temporário, e não desligar a
  #   medição: o que este bloco quer saber é se o `detectar` declara o motivo
  #   AQUI E AGORA, na máquina de verdade. Só o efeito colateral se desvia.
  medida="$(
    set +u
    MEOW_ESTADO="$(mktemp -d -p "${TMPDIR:-/tmp}" .meow-reversao.XXXXXX)"
    trap 'rm -rf "$MEOW_ESTADO"' EXIT
    MEOW_IGNORA_DESKTOP=1 NO_COLOR=1
    # shellcheck source=../lib/comum.sh
    . "$RAIZ/lib/comum.sh" >/dev/null 2>&1
    # shellcheck disable=SC1090
    . "$mod" >/dev/null 2>&1
    meow_app_detectar >/dev/null 2>&1
    printf '%s\t%s' "$?" "${MEOW_APP_MOTIVO:-}"
  )"
  rc_det="${medida%%$'\t'*}"
  motivo="${medida#*$'\t'}"
  if [ "$rc_det" = "3" ] && [ -z "$motivo" ]; then
    printf 'FALHOU: o meow_app_detectar de %s devolveu 3 sem declarar motivo\n' "$nome" >&2
    printf '        nesta máquina, agora — é o caso exato do Spotify de 21/09/2026\n' >&2
    falhou=1
  fi
done

# E A GUARDA MORDE. Sem esta conferência o `meow_app_pendente` poderia degenerar
# numa frase genérica sem ninguém notar, que é o defeito voltando pela porta de
# trás: motivo vazio tem de GRITAR "defeito no módulo", não virar silêncio bonito.
guarda="$(
  set +u
  NO_COLOR=1
  # shellcheck source=../lib/comum.sh
  . "$RAIZ/lib/comum.sh" >/dev/null 2>&1
  MEOW_APP_MOTIVO=""
  meow_app_pendente modulo-de-mentira 2>&1
)"
case "$guarda" in
  *"sem motivo declarado"*"modulo-de-mentira"*) : ;;
  *) printf 'FALHOU: meow_app_pendente com motivo vazio não acusou o defeito do módulo\n' >&2
     printf '        saiu: %s\n' "$guarda" >&2
     falhou=1 ;;
esac

[ "$falhou" = "0" ] || exit 1
printf 'ok: o --uninstall desfaz os %s módulos de aplicativo\n' \
  "$(find "$RAIZ/assets/temas-de-apps" -mindepth 1 -maxdepth 1 -type d | wc -l)"
printf 'ok: os %s módulos migrados declaram o motivo em toda saída de pendência\n' "$migrados"
printf 'ok: as %s unidades de systemd/ estão nas duas listas do desinstalador\n' \
  "$(find "$RAIZ/systemd" -maxdepth 1 -name 'meow-*' -type f | wc -l)"

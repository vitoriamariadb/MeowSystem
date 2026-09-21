#!/usr/bin/env bash
# baixar_upstream.sh — traz o que vem de terceiros, sempre em commit PINADO.
#
# POR QUE PINAR, E NÃO SEGUIR `main`
#   Um upstream que muda sozinho transforma "rodei o instalador" em "rodei o
#   instalador num dia em que o repositório estava de um jeito". O
#   `catppuccin/papirus-folders` está parado há dois anos e não tem UMA tag —
#   só dá para prender pelo SHA. O dia em que alguém mexer nele, a gente decide
#   se acompanha; não descobre por acidente.
#
# O QUE NÃO ENTRA NO GIT
#   Nada disto é versionado (ver .gitignore): são megabytes reproduzíveis. O
#   repositório guarda a RECEITA — este arquivo — e não o conteúdo.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

DESTINO="$RAIZ/assets/icones/upstream"

# repositório                                   pasta            commit pinado
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
  # --depth grande o bastante para alcançar o commit pinado sem baixar a
  # história inteira. Se o commit for antigo demais, o fetch explícito resolve.
  # SEM REDE É FALTA DE DEPENDÊNCIA, NÃO ERRO — 21/09/2026
  #   Esta linha devolvia 2 e o instalador imprimia "falhou: upstream" numa
  #   máquina que só estava offline. As outras etapas que baixam coisa já
  #   tratavam o mesmo caso como 3: `midia_build.sh:144-146` ("não consegui
  #   clonar $URL (sem rede?) — fica para o próximo ciclo") e `cursor.sh:376-384`
  #   ("nada foi instalado — o cursor continua exatamente como estava"). Dois
  #   comportamentos para a mesma causa faziam a primeira instalação de quem não
  #   tem rede terminar em vermelho com `return 2`, quando o certo é terminar em
  #   0 com a etapa em "pulados".
  #   O `checkout` logo abaixo CONTINUA em 2, de propósito: ali o clone já veio,
  #   então não é a rede — é o commit pinado que não existe mais, e isso é
  #   problema do repositório, não da máquina de quem instala.
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

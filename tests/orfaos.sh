#!/usr/bin/env bash
# orfaos.sh — CÓDIGO QUE NINGUÉM CHAMA APARECE NA TELA, E NÃO É APAGADO AQUI.
#
# Citação feita por um órfão não conta como chamada: dois arquivos que só se
# citam um ao outro caem juntos, pelo ponto fixo mais abaixo.
#
# A regra desta casa é mencionar, não deletar.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# Caminho absoluto DESTE arquivo, para que ele possa se tirar da lista de
# chamadores mais abaixo — o `find` imprime absoluto e `${BASH_SOURCE[0]}` vem
# como a pessoa digitou (`./tests/orfaos.sh`), que não casaria.
EU="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
FALHAS=0

falhou() { printf 'FALHOU: %s\n' "$*" >&2; FALHAS=$((FALHAS + 1)); }
passou() { printf 'ok: %s\n' "$*"; }

# OS ISENTOS, e o motivo de cada um
#
# Todos são ferramenta de bancada: rodam NA MÃO, produzem uma folha ou um
# diagnóstico para alguém olhar, e por isso nunca vão aparecer chamados por
# outro script.
ISENTOS=(
  listar-apps.sh        # inventário de .desktop da máquina, uso manual, com --csv
  coleta-meowsystem.sh  # inventário READ-ONLY do COSMIC; `bash scripts/coleta-meowsystem.sh`
  folha_conversor.py    # folha do traço do conversor
  folha_icones.py       # folha dos 41 aplicativos por procedência; apareceu
                        #   quando o ponto fixo parou de contar a citação que vinha do
                        #   folha_conversor.py:647 — um isento citando o outro, em cadeia
  folha_marcas.py       # folha de aprovação da cor por marca
  folha_proposta.py     # folha de aprovação da unificação em Arcticons
  icones_orfaos.py      # diagnóstico de quem não resolve dentro do nosso tema
)

# A DÍVIDA DECLARADA, e o motivo de cada linha
#
# Ficam aqui para que o CI não acenda vermelho por elas todo dia — e para que
# aposentar qualquer um deles seja uma linha de commit própria, com o motivo,
# como manda a regra da casa (mencionar, não deletar).
CONHECIDOS=(
  derivar_claro.py   # gerador de tiro único: a saída já está em packs/dracula/paleta.json (commit 045b82b)
  folha_barra.py     # folha dos ícones da barra; só o sistema.map a cita, em comentário
)

na_lista() {
  local alvo="$1"; shift
  local i
  for i in "$@"; do
    [ "$i" = "$alvo" ] && return 0
  done
  return 1
}

# Os arquivos que PODEM chamar alguém
#
# `bin/meow` não tem extensão e é o maior chamador do repositório, então a lista
# é montada com `find` e não com `--include` do grep.
#
# A lista de exceção se autoimunizava: bastava escrever o nome do órfão aqui
# para ele sumir do relatório, que é o contrário do que uma isenção deve fazer —
# ela declara o órfão, não o esconde.
mapfile -t CHAMADORES < <(
  find "$RAIZ" \
    -path "$RAIZ/.git" -prune -o \
    -path "$RAIZ/docs" -prune -o \
    -path "$EU" -prune -o \
    -name '__pycache__' -prune -o \
    -type f \( -name '*.sh' -o -name '*.py' -o -name '*.js' -o -name '*.html' \
            -o -name '*.json' -o -name '*.map' -o -name '*.yml' -o -name '*.desktop' \
            -o -name '*.service' -o -name '*.path' -o -name '*.timer' \
            -o -name '*.exemplo' -o -name '*.conf' -o -name 'meow' \) -print
)
[ "${#CHAMADORES[@]}" -gt 0 ] || { printf 'FALHOU: não montei a lista de chamadores\n' >&2; exit 2; }

# `varrer` preenche o array global `orfaos` contando só as citações que vêm de
# quem NÃO está em `IGNORADOS` — e é essa lista que cresce a cada passagem do
# ponto fixo logo abaixo.
orfaos=()
varrer() {
  local alvo nome chamadas ign
  orfaos=()
  for alvo in "$RAIZ"/scripts/*.sh "$RAIZ"/scripts/*.py; do
  [ -f "$alvo" ] || continue
  nome="$(basename "$alvo")"
  # `grep -v` tira a autocitação (o shebang, o cabeçalho, o `argv[0]`) e a
  # segunda peneira tira as linhas de comentário — é nelas que a prosa mora.
  #
  # com `set -o pipefail`, o `-q` fecha o cano assim que acha a primeira linha,
  # o grep de cima morre de SIGPIPE (141) e o pipeline inteiro devolve != 0.
  chamadas="$(grep -nHF "$nome" "${CHAMADORES[@]}" 2>/dev/null \
              | grep -v "^$alvo:" \
              | grep -vE ':[0-9]+:[[:space:]]*(#|//|\*)')"
  # A TERCEIRA PENEIRA: citação feita por quem já se sabe inalcançável não vale
  # como chamada. É ela que quebra o ciclo de duas pontas do cabeçalho.
  for ign in "${IGNORADOS[@]:-}"; do
    [ -n "$ign" ] || continue
    [ -n "$chamadas" ] || break
    chamadas="$(printf '%s\n' "$chamadas" | grep -v "^$ign:")"
  done
  [ -n "$chamadas" ] && continue
  orfaos+=("$nome")
  done
}

# Para quando uma passagem não acrescenta ninguém. O laço termina sempre porque
# `IGNORADOS` só cresce e é limitada pelo número de scripts do diretório.
IGNORADOS=()
while :; do
  varrer
  novos=0
  for nome in "${orfaos[@]:-}"; do
    [ -n "$nome" ] || continue
    na_lista "$RAIZ/scripts/$nome" "${IGNORADOS[@]:-}" && continue
    IGNORADOS+=("$RAIZ/scripts/$nome")
    novos=$((novos + 1))
  done
  [ "$novos" -gt 0 ] || break
done

DECLARADOS=0
for nome in "${orfaos[@]:-}"; do
  [ -n "$nome" ] || continue
  if na_lista "$nome" "${ISENTOS[@]}"; then
    printf 'isento: scripts/%s — ferramenta de bancada, roda na mão\n' "$nome"
    DECLARADOS=$((DECLARADOS + 1))
  elif na_lista "$nome" "${CONHECIDOS[@]}"; then
    # AVISO, E NÃO FALHA: o motivo de cada um está na lista `CONHECIDOS` deste
    # arquivo, e a decisão é que dívida já escrita não pinta o CI.
    printf 'aviso: scripts/%s — órfão conhecido, dívida declarada na P23 (o motivo está na lista CONHECIDOS deste arquivo)\n' "$nome"
    DECLARADOS=$((DECLARADOS + 1))
  else
    falhou "scripts/$nome não é chamado por ninguém — mencione-o ou aposente-o numa linha própria"
  fi
done

# ---------------------------------------------------------------------------
printf '\n'
if [ "$FALHAS" -gt 0 ]; then
  printf '%s órfão(s) NOVO(S), fora do que está declarado aqui. Este teste NÃO apaga:\n' \
         "$FALHAS" >&2
  printf 'apagar é decisão sua, num commit só dela — ou ele entra na lista, com o motivo.\n' >&2
  exit 1
fi
passou "nenhum órfão novo — os $DECLARADOS que apareceram estão todos declarados acima"
exit 0

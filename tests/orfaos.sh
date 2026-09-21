#!/usr/bin/env bash
# orfaos.sh — CÓDIGO QUE NINGUÉM CHAMA APARECE NA TELA, E NÃO É APAGADO AQUI.
#
# O QUE ESTE TESTE MEDE, EM 21/09/2026
#   A auditoria de pontas soltas contou 83 scripts e achou dois que o
#   repositório inteiro não executa em lugar nenhum:
#
#     scripts/derivar_claro.py   gerador de tiro único: a saída dele já está
#                                colada em `packs/dracula/paleta.json`. Nasceu e
#                                morreu no commit 045b82b, e não tem UMA
#                                menção fora dele mesmo em todo o repositório.
#     scripts/folha_barra.py     a folha dos ícones da barra, de 10/08/2026. O
#                                `assets/icones/sistema.map` fala dela em duas
#                                linhas de comentário (89 e 100) e mais nada a
#                                invoca — por isso a regra abaixo conta CHAMADA,
#                                nunca menção: prosa não executa arquivo.
#
# E UM TERCEIRO, QUE A AUDITORIA NÃO TINHA — ACHADO POR ESTE ARQUIVO EM 21/09
#   `scripts/appid_dock.sh` ESCREVE (a ponte de `app_id` que a dock não casa) e
#   não é chamado por ninguém: nem pelo `bin/meow`, nem pelo `install.sh`, nem
#   por unidade do systemd. A auditoria o classificou como quase-órfão porque
#   contou MENÇÕES, e ele tem três — todas em comentário do `appid_sonda.py`,
#   que por sua vez só é alcançável por ele. São dois arquivos que se citam e
#   que nada mais alcança.
#
# O CICLO DE DUAS PONTAS, E A CEGUEIRA QUE ELE CAUSAVA — corrigido em 21/09/2026
#   A primeira versão desta varredura perguntava, de cada script, "alguém me
#   cita numa linha executável?". Com essa pergunta o `appid_sonda.py` some do
#   relatório: o `scripts/appid_dock.sh:159` tem `SONDA=".../appid_sonda.py"`,
#   que é código e não comentário — então a sonda conta como chamada POR UM
#   ÓRFÃO. O cabeçalho aqui já dizia "são dois arquivos que se citam" e o teste
#   só reportava um; quem aposentasse o dock descobriria a sonda na rodada
#   seguinte, que é a pior hora para descobrir.
#
#   A pergunta certa é "alguém ALCANÇÁVEL me cita?", e ela se responde por ponto
#   fixo: varre, tira do jogo as citações que vêm de quem já se sabe órfão,
#   varre de novo, até a lista parar de crescer. Um ciclo de N pontas cai todo
#   na N-ésima passagem. É a mesma ideia de um coletor de lixo por alcance — e
#   pelo mesmo motivo: contar referências não enxerga ilha que se auto-sustenta.
#
# POR QUE ELE NÃO APAGA, E ISSO É REGRA E NÃO TIMIDEZ
#   A regra desta casa é mencionar, não deletar. Apagar arquivo é decisão de
#   quem enxerga a história dele, e vai numa linha de commit própria, com o
#   motivo escrito — não no meio de um teste que alguém rodou para outra coisa.
#   Este arquivo só garante que um órfão não volte a ficar invisível.
#
# A LISTA DE ÓRFÃOS É DERIVADA, NUNCA ESCRITA — é a armadilha nº 3 do projeto
#   (toda lista fixa é uma lista que alguém vai esquecer). O que está escrito
#   aqui são as duas listas de EXCEÇÃO — `ISENTOS` (ferramenta de bancada) e
#   `CONHECIDOS` (dívida declarada) —, que são poucas linhas, mudam devagar e
#   cada uma traz o porquê ao lado. Um script novo que nasça sem chamador
#   aparece sozinho.
#
#   E A EXCEÇÃO NÃO PODE ESCONDER O ÓRFÃO QUE ELA DECLARA — medido em 21/09/2026
#     As duas listas são linhas de CÓDIGO deste arquivo (o nome, e o motivo
#     depois do `#`), então a varredura as lia como chamada: bastava escrever um
#     nome aqui para ele sumir do relatório. Seis isentos tinham sumido assim,
#     sem ninguém notar, e os três da dívida sumiram no minuto em que entraram.
#     Por isso este arquivo se tira da lista de chamadores, logo abaixo.
#
# O QUE CONTA COMO CHAMADA
#   O nome do arquivo citado numa linha que NÃO é comentário, dentro de um
#   arquivo que executa (`*.sh`, `*.py`, `bin/meow`, unidade do systemd, mapa,
#   conf, o painel). `docs/` e todo `*.md` ficam de fora de propósito: um script
#   citado só em prosa é exatamente o caso que este teste veio pegar — o
#   `folha_barra.py` é ele.
#
# O QUE FAZ ESTE TESTE FALHAR — CORREÇÃO DE 21/09/2026, e a contradição era da sprint
#   A primeira versão mandava falhar nos órfãos CONHECIDOS. Isso põe o CI em
#   vermelho todos os dias por uma dívida que já está escrita, medida e aceita —
#   e vermelho que é normal deixa de ser lido, que é exatamente o defeito que a
#   P23 veio consertar. Um teste serve para pegar REGRESSÃO.
#
#   Então: os órfãos conhecidos saem na tela como `aviso:`, com o motivo de cada
#   um, e o `rc` continua 0. Aparecendo um órfão NOVO — um que não esteja nem na
#   isenção nem na dívida declarada —, aí sim `rc=1`, e o vermelho quer dizer
#   alguma coisa no dia em que acender.
#
# CÓDIGOS DE SAÍDA (os do projeto)
#   0 = os órfãos achados são exatamente os declarados · 1 = apareceu um novo ·
#   2 = erro.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# Caminho absoluto DESTE arquivo, para que ele possa se tirar da lista de
# chamadores mais abaixo — o `find` imprime absoluto e `${BASH_SOURCE[0]}` vem
# como a pessoa digitou (`./tests/orfaos.sh`), que não casaria.
EU="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
FALHAS=0

falhou() { printf 'FALHOU: %s\n' "$*" >&2; FALHAS=$((FALHAS + 1)); }
passou() { printf 'ok: %s\n' "$*"; }

# ---------------------------------------------------------------------------
# OS ISENTOS, e o motivo de cada um
# ---------------------------------------------------------------------------
# Todos são ferramenta de bancada: rodam NA MÃO, produzem uma folha ou um
# diagnóstico para alguém olhar, e por isso nunca vão aparecer chamados por
# outro script. Ser chamado por ninguém é o desenho deles, não um esquecimento.
ISENTOS=(
  listar-apps.sh        # inventário de .desktop da máquina, uso manual, com --csv
  coleta-meowsystem.sh  # inventário READ-ONLY do COSMIC; `bash scripts/coleta-meowsystem.sh`
  folha_conversor.py    # folha do traço do conversor (09/09/2026)
  folha_icones.py       # folha dos 41 aplicativos por procedência (10/08/2026); apareceu em 21/09
                        #   quando o ponto fixo parou de contar a citação que vinha do
                        #   folha_conversor.py:647 — um isento citando o outro, em cadeia
  folha_marcas.py       # folha de aprovação da cor por marca (23/08/2026)
  folha_proposta.py     # folha de aprovação da unificação em Arcticons (10/08/2026)
  icones_orfaos.py      # diagnóstico de quem não resolve dentro do nosso tema
)

# ---------------------------------------------------------------------------
# A DÍVIDA DECLARADA, e o motivo de cada linha
# ---------------------------------------------------------------------------
# Estes NÃO são desenho: são pontas soltas medidas em 21/09/2026 e aceitas por
# escrito, na P23. Ficam aqui para que o CI não acenda vermelho por elas todo
# dia — e para que aposentar qualquer um deles seja uma linha de commit própria,
# com o motivo, como manda a regra da casa (mencionar, não deletar).
CONHECIDOS=(
  derivar_claro.py   # gerador de tiro único: a saída já está em packs/dracula/paleta.json (commit 045b82b)
  folha_barra.py     # folha dos ícones da barra (10/08/2026); só o sistema.map a cita, em comentário
  appid_dock.sh      # escreve a ponte de app_id e ninguém o chama: nem bin/meow, nem install.sh, nem unidade
  appid_sonda.py     # só o appid_dock.sh a alcança; cai junto com ele, pelo ciclo de duas pontas
)

na_lista() {
  local alvo="$1"; shift
  local i
  for i in "$@"; do
    [ "$i" = "$alvo" ] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Os arquivos que PODEM chamar alguém
# ---------------------------------------------------------------------------
# `bin/meow` não tem extensão e é o maior chamador do repositório, então a lista
# é montada com `find` e não com `--include` do grep.
#
# E ESTE ARQUIVO SE TIRA DA LISTA, o que não é modéstia — medido em 21/09/2026:
#   as listas `ISENTOS` e `CONHECIDOS` acima são linhas de código (o nome, e o
#   motivo depois do `#`), então o `grep` as lia como CHAMADA e todo nome posto
#   nelas parava de aparecer na varredura. A lista de exceção se autoimunizava:
#   bastava escrever o nome do órfão aqui para ele sumir do relatório, que é o
#   contrário do que uma isenção deve fazer — ela declara o órfão, não o esconde.
#   Um auditor não é chamador: ele cita nomes sem executar arquivo nenhum.
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

# ---------------------------------------------------------------------------
# A varredura
# ---------------------------------------------------------------------------
# `varrer` preenche o array global `orfaos` contando só as citações que vêm de
# quem NÃO está em `IGNORADOS` — e é essa lista que cresce a cada passagem do
# ponto fixo logo abaixo. Com ela vazia, esta função é a varredura ingênua de
# antes, palavra por palavra.
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
  # O RESULTADO VAI PARA UMA VARIÁVEL, E NÃO PARA UM `grep -q`, POR MEDIDA:
  #   com `set -o pipefail`, o `-q` fecha o cano assim que acha a primeira
  #   linha, o grep de cima morre de SIGPIPE (141) e o pipeline inteiro devolve
  #   != 0. Medido em 21/09/2026: doze scripts vivos — `wallpaper.sh`,
  #   `painel.sh`, `logo.sh` entre eles — apareceram como órfãos por causa
  #   disso. Um teste de órfão que acusa o `wallpaper.sh` é um teste que
  #   ninguém acredita na segunda vez.
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

# O PONTO FIXO: varre, tira do jogo os órfãos recém-achados, varre de novo. Para
# quando uma passagem não acrescenta ninguém. O laço termina sempre porque
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
    # arquivo, e a decisão de 21/09 é que dívida já escrita não pinta o CI.
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

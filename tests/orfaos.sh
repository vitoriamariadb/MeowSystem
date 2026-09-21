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
#   que nada mais alcança. Ele fica aqui como falha, e não na isenção, porque
#   as isenções são ferramenta de bancada e ele não é: ele escreve no sistema.
#
# POR QUE ELE NÃO APAGA, E ISSO É REGRA E NÃO TIMIDEZ
#   A regra desta casa é mencionar, não deletar. Apagar arquivo é decisão de
#   quem enxerga a história dele, e vai numa linha de commit própria, com o
#   motivo escrito — não no meio de um teste que alguém rodou para outra coisa.
#   Este arquivo só garante que um órfão não volte a ficar invisível.
#
# A LISTA DE ÓRFÃOS É DERIVADA, NUNCA ESCRITA — é a armadilha nº 3 do projeto
#   (toda lista fixa é uma lista que alguém vai esquecer). O que está escrito
#   aqui é o contrário: os ISENTOS, que são poucos, mudam devagar e cada um traz
#   o porquê ao lado. Um script novo que nasça sem chamador aparece sozinho.
#
# O QUE CONTA COMO CHAMADA
#   O nome do arquivo citado numa linha que NÃO é comentário, dentro de um
#   arquivo que executa (`*.sh`, `*.py`, `bin/meow`, unidade do systemd, mapa,
#   conf, o painel). `docs/` e todo `*.md` ficam de fora de propósito: um script
#   citado só em prosa é exatamente o caso que este teste veio pegar — o
#   `folha_barra.py` é ele.
#
# CÓDIGOS DE SAÍDA (os do projeto)
#   0 = ninguém órfão fora da isenção · 1 = há órfão duro · 2 = erro.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
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
  folha_marcas.py       # folha de aprovação da cor por marca (23/08/2026)
  folha_proposta.py     # folha de aprovação da unificação em Arcticons (10/08/2026)
  icones_orfaos.py      # diagnóstico de quem não resolve dentro do nosso tema
)

esta_isento() {
  local alvo="$1" i
  for i in "${ISENTOS[@]}"; do
    [ "$i" = "$alvo" ] && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Os arquivos que PODEM chamar alguém
# ---------------------------------------------------------------------------
# `bin/meow` não tem extensão e é o maior chamador do repositório, então a lista
# é montada com `find` e não com `--include` do grep.
mapfile -t CHAMADORES < <(
  find "$RAIZ" \
    -path "$RAIZ/.git" -prune -o \
    -path "$RAIZ/docs" -prune -o \
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
  [ -n "$chamadas" ] && continue
  orfaos+=("$nome")
done

for nome in "${orfaos[@]:-}"; do
  [ -n "$nome" ] || continue
  if esta_isento "$nome"; then
    printf 'isento: scripts/%s — ferramenta de bancada, roda na mão\n' "$nome"
  else
    falhou "scripts/$nome não é chamado por ninguém — mencione-o ou aposente-o numa linha própria"
  fi
done

# ---------------------------------------------------------------------------
printf '\n'
if [ "$FALHAS" -gt 0 ]; then
  printf '%s órfão(s) duro(s). Este teste NÃO apaga: apagar é decisão sua, num commit só dela.\n' \
         "$FALHAS" >&2
  exit 1
fi
passou "nenhum script órfão fora dos ${#ISENTOS[@]} isentos"
exit 0

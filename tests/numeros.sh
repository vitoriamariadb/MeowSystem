#!/usr/bin/env bash
# numeros.sh — O NÚMERO QUE A TELA DIZ É O NÚMERO QUE O CÓDIGO TEM.
#
# O DEFEITO QUE ESTE TESTE PEGA JÁ ACONTECEU, E DUROU SEMANAS — 09/09/2026
#   O desenho da aba «Instalação» abria com `const ETAPAS_DO_INSTALADOR = 52` e,
#   três linhas acima, um comentário jurando *"os dois números são CONTADOS, não
#   lembrados"*. Eram lembrados. No mesmo dia, medido:
#
#     install.sh           53 etapas        o desenho dizia 52
#     bin/meow             48 conferências  o desenho dizia 46
#     ajuda dos botões     52 e 46          nenhum dos dois batia
#     README.md            47 conferências  e o badge do topo, 47
#     docs/SPRINTS.md      46 conferências  na linha que diz "hoje são"
#     app/LEIA-ME.md       103 chaves       são 109
#
#   Seis lugares, cinco números diferentes para duas verdades. Ninguém mentiu:
#   cada um estava certo no dia em que foi escrito.
#
# É A ARMADILHA Nº 3 COM OUTRA ROUPA
#   `app/LEIA-ME.md` conta por que o catálogo de chaves do painel é DERIVADO do
#   `meow.conf.exemplo`: *"toda lista fixa é uma lista que alguém vai esquecer"*.
#   O número escrito à mão é o mesmo defeito num único inteiro — e é pior, porque
#   uma lista incompleta some da tela e um número errado FICA na tela, com cara
#   de medido.
#
#   A cura tem duas metades, e este arquivo é a segunda:
#     · o painel passou a CONTAR (`_medidas_do_projeto()` do `app/servidor.py`,
#       servido em `medidas` e consumido pelo desenho via `window.MEOW_MEDIDAS`);
#     · o texto que um humano escreve — README, LEIA-ME, o quadro "O ESTADO DE
#       HOJE" das sprints — não tem como contar sozinho, então quem cobra é este
#       teste.
#
# O QUE ELE **NÃO** POLICIA
#   Registro histórico. `docs/SPRINTS.md` é quase todo sprint fechada, e a regra
#   do próprio arquivo é que aquilo *"fica como está — é história medida, não
#   plano"*. Um "19 chaves" de 11/08 continua verdadeiro sobre 11/08. Por isso
#   este teste confere ALVOS NOMEADOS, um por afirmação de HOJE, e não uma
#   varredura de todo número do repositório: uma varredura pegaria a história
#   junto e seria desligada na primeira semana.
#
# CÓDIGOS DE SAÍDA (os do projeto)
#   0 = tudo bate · 1 = algum número divergiu · 3 = falta dependência.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FALHAS=0

falhou() { printf 'FALHOU: %s\n' "$*" >&2; FALHAS=$((FALHAS + 1)); }
passou() { printf 'ok: %s\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. As contagens canônicas, tiradas da MESMA lista que o código executa
# ---------------------------------------------------------------------------
# Não é `grep -c '^etapa_.*()'`: existem funções de etapa que a lista do `main`
# não chama, e o número que importa é o que RODA.
etapas_do_install() {
  sed -n '/local etapas=(/,/)/p' "$RAIZ/install.sh" \
    | grep -oE '\betapa_[a-z_0-9]+\b' | sort -u | grep -c .
}

# A lista que o `doctor` percorre, e não as funções definidas — a afirmação 2
# abaixo prova que as duas são a mesma coisa, e é ela que garante que contar uma
# responde pela outra.
conferencias_do_meow() {
  sed -n 's/^VERIFICAVEIS=(\(.*\))$/\1/p' "$RAIZ/bin/meow" | tr ' ' '\n' | grep -c .
}

chaves_do_exemplo() { grep -c '^[A-Z_][A-Z_0-9]*=' "$RAIZ/meow.conf.exemplo"; }

ETAPAS="$(etapas_do_install)"
CONFERENCIAS="$(conferencias_do_meow)"
CHAVES="$(chaves_do_exemplo)"

for par in "ETAPAS:$ETAPAS" "CONFERENCIAS:$CONFERENCIAS" "CHAVES:$CHAVES"; do
  case "${par#*:}" in
    ''|0|*[!0-9]*) printf 'FALHOU: não consegui contar %s\n' "${par%%:*}" >&2; exit 1 ;;
  esac
done
printf 'contado: %s etapas · %s conferências · %s chaves\n' \
       "$ETAPAS" "$CONFERENCIAS" "$CHAVES"

# ---------------------------------------------------------------------------
# 2. As duas listas do doctor descrevem o mesmo conjunto
# ---------------------------------------------------------------------------
# `VERIFICAVEIS` é o que o laço percorre; `chk_*` é o que existe. Uma função sem
# entrada na lista NUNCA RODA e o doctor diz "ok" sem ter conferido — que é o
# pior sintoma possível, e já aconteceu neste repositório com chave de conf
# (25/08/2026). Uma entrada sem função quebra o laço.
lista="$(sed -n 's/^VERIFICAVEIS=(\(.*\))$/\1/p' "$RAIZ/bin/meow" | tr ' ' '\n' | grep -c . >/dev/null; \
         sed -n 's/^VERIFICAVEIS=(\(.*\))$/\1/p' "$RAIZ/bin/meow" | tr ' ' '\n' | grep . | sort -u)"
funcoes="$(grep -oE '^chk_[a-z_0-9]+' "$RAIZ/bin/meow" | sed 's/^chk_//' | sort -u)"
if [ "$lista" = "$funcoes" ]; then
  passou "as $CONFERENCIAS conferências do VERIFICAVEIS são exatamente as chk_ que existem"
else
  falhou "VERIFICAVEIS e as funções chk_ divergem:"
  diff <(printf '%s\n' "$lista") <(printf '%s\n' "$funcoes") \
    | sed 's/^</  só no VERIFICAVEIS  /; s/^>/  só como função    /' >&2
fi

# ---------------------------------------------------------------------------
# 3. O servidor conta o mesmo que este shell
# ---------------------------------------------------------------------------
# Mesmo espírito do `tests/app.sh`: duas leituras da mesma verdade têm de
# concordar no mesmo dia, e não meses depois. Sem python3 isto se PULA — o resto
# do arquivo continua valendo.
if command -v python3 >/dev/null 2>&1; then
  saida="$(MEOW_RAIZ="$RAIZ" python3 - "$RAIZ" <<'PY' 2>/dev/null
import sys
sys.path.insert(0, sys.argv[1] + "/app")
import servidor
m = servidor._medidas_do_projeto()
print("%s %s %s" % (m.get("etapas"), m.get("conferencias"), len(servidor.ACOES)))
PY
)" || saida=""
  if [ -z "$saida" ]; then
    falhou "não consegui rodar o _medidas_do_projeto() do app/servidor.py"
  else
    set -- $saida
    [ "${1:-}" = "$ETAPAS" ] || falhou "servidor conta $1 etapas; o install.sh tem $ETAPAS"
    [ "${2:-}" = "$CONFERENCIAS" ] || falhou "servidor conta $2 conferências; o bin/meow tem $CONFERENCIAS"
    ACOES="${3:-}"
    [ "${1:-}" = "$ETAPAS" ] && [ "${2:-}" = "$CONFERENCIAS" ] && \
      passou "o painel conta o mesmo que o código: $ETAPAS etapas, $CONFERENCIAS conferências"
  fi
else
  printf 'pulado: sem python3 — as afirmações do servidor não foram conferidas\n'
  ACOES=""
fi

# ---------------------------------------------------------------------------
# 4. Cada texto que fala do ESTADO DE HOJE diz o número de hoje
# ---------------------------------------------------------------------------
# Um alvo por afirmação, com o motivo no nome. Acrescentar um texto novo que
# cite número é acrescentar uma linha aqui — e é de propósito que dê trabalho:
# um número escrito à mão sem cobrador é o defeito que este arquivo existe para
# não deixar voltar.
#
# `%20` e `%C3%AA` são o badge do shields.io no topo do README, onde o espaço e o
# "ê" vão percent-encoded. É a primeira coisa que alguém vê do projeto.
confere() {   # $1 = arquivo · $2 = regex com UM grupo (o número) · $3 = esperado · $4 = o que é
  local arq="$RAIZ/$1" achado
  [ -f "$arq" ] || { falhou "$1 não existe"; return; }
  achado="$(grep -oE "$2" "$arq" | head -n1 | grep -oE '[0-9]+' | head -n1)"
  if [ -z "$achado" ]; then
    falhou "$1: não achei a afirmação sobre $4 (o texto mudou de forma?)"
  elif [ "$achado" != "$3" ]; then
    falhou "$1 diz $achado $4; são $3"
  else
    passou "$1: $4 = $3"
  fi
}

confere README.md    'instalador-[0-9]+%20etapas'        "$ETAPAS"        "etapas (badge)"
confere README.md    'São [0-9]+ etapas'                 "$ETAPAS"        "etapas"
confere README.md    'doctor-[0-9]+%20confer'            "$CONFERENCIAS"  "conferências (badge)"
confere README.md    '# [0-9]+ conferências'             "$CONFERENCIAS"  "conferências"
confere README.md    '[0-9]+ ajustes e'                  "$CHAVES"        "ajustes"

confere README.en.md 'installer-[0-9]+%20steps'          "$ETAPAS"        "steps (badge)"
confere README.en.md '[0-9]+ steps\.'                    "$ETAPAS"        "steps"
confere README.en.md 'doctor-[0-9]+%20checks'            "$CONFERENCIAS"  "checks (badge)"
confere README.en.md '# [0-9]+ checks'                   "$CONFERENCIAS"  "checks"

confere app/LEIA-ME.md 'As [0-9]+ chaves'                "$CHAVES"        "chaves"

# O BADGE DO NAVEGADOR É O ÚNICO QUE ESTE ARQUIVO **NÃO** SABE CONTAR, e está
# dito aqui para ninguém procurar o cobrador que não existe: o placar de
# `tests/app-navegador.py` só aparece RODANDO a suíte (ele conta as afirmações
# que de fato executaram, e algumas se pulam quando o recurso não está na
# máquina). Contar `checa(` no fonte daria um número maior que o placar e a
# cobrança seria falsa — pior que a ausência dela. Quem atualiza os dois badges
# é quem roda a suíte, e o placar dela é a fonte. Medido em 09/09/2026: 103/103.
# O que DÁ para cobrar sem rodar nada é que os dois README digam o MESMO
# placar. Eles já disseram 84/84 em uníssono por coincidência — foram escritos
# no mesmo dia e envelheceram juntos —, mas a tradução é o lugar clássico onde
# um lado é atualizado e o outro não.
placar_pt="$(grep -oE 'navegador-[0-9]+%2F[0-9]+' "$RAIZ/README.md" | head -n1 | sed 's/^navegador-//')"
placar_en="$(grep -oE 'browser-[0-9]+%2F[0-9]+' "$RAIZ/README.en.md" | head -n1 | sed 's/^browser-//')"
if [ -z "$placar_pt" ] || [ -z "$placar_en" ]; then
  falhou "não achei o badge do navegador em um dos README (mudou de forma?)"
elif [ "$placar_pt" != "$placar_en" ]; then
  falhou "o badge do navegador diz $placar_pt no README.md e $placar_en no README.en.md"
else
  passou "os dois README dizem o mesmo placar do navegador: $placar_pt"
fi

# O quadro "O ESTADO DE HOJE, MEDIDO" do SPRINTS.md. As linhas de baixo daquele
# arquivo são história e não entram aqui — ver o cabeçalho deste teste.
confere docs/SPRINTS.md '\| `install.sh` \| [0-9]+ etapas' "$ETAPAS"       "etapas (estado de hoje)"
confere docs/SPRINTS.md '\*\*[0-9]+\*\* conferências'      "$CONFERENCIAS" "conferências (estado de hoje)"

if [ -n "${ACOES:-}" ]; then
  confere README.md      '[0-9]+ ações em'   "$ACOES" "ações"
  confere app/LEIA-ME.md '[0-9]+ ações, com a saída' "$ACOES" "ações"
fi

# ---------------------------------------------------------------------------
printf '\n'
if [ "$FALHAS" -gt 0 ]; then
  printf '%s número(s) fora do lugar.\n' "$FALHAS" >&2
  printf 'O conserto é atualizar o TEXTO, nunca o código: quem manda é a contagem.\n' >&2
  exit 1
fi
printf 'todos os números escritos batem com os contados.\n'
exit 0

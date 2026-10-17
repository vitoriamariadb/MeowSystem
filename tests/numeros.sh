#!/usr/bin/env bash
# numeros.sh — O NÚMERO QUE A TELA DIZ É O NÚMERO QUE O CÓDIGO TEM.
#
# O número escrito à mão é o mesmo defeito num único inteiro — e é pior, porque
# uma lista incompleta some da tela e um número errado FICA na tela, com cara de
# medido.
#
# 0 = tudo bate · 1 = algum número divergiu · 3 = falta dependência.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
FALHAS=0

falhou() { printf 'FALHOU: %s\n' "$*" >&2; FALHAS=$((FALHAS + 1)); }
passou() { printf 'ok: %s\n' "$*"; }

# 1. As contagens canônicas, tiradas da MESMA lista que o código executa
#
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

# 2. As duas listas do doctor descrevem o mesmo conjunto
#
# `VERIFICAVEIS` é o que o laço percorre; `chk_*` é o que existe. Uma entrada
# sem função quebra o laço.
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

# 3. O servidor conta o mesmo que este shell
#
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

# 4. Cada texto que fala do ESTADO DE HOJE diz o número de hoje
#
# Um alvo por afirmação, com o motivo no nome.
#
# `%20` e `%C3%AA` são o badge do shields.io no topo do README, onde o espaço e
# o "ê" vão percent-encoded.
# Com MEOW_NUMEROS_CORRIGIR=1 (o scripts/higiene.sh), o número errado é trocado
# pelo contado no primeiro trecho que casa o padrão.
corrige() {   # $1 = arquivo · $2 = regex · $3 = número certo
  python3 - "$@" <<'PY'
import re, sys
caminho, padrao, certo = sys.argv[1:]
texto = open(caminho, encoding="utf-8").read()
m = re.search(padrao, texto)
if not m:
    sys.exit(1)
trecho = re.sub(r"[0-9]+", certo, m.group(0), count=1)
open(caminho, "w", encoding="utf-8").write(texto[:m.start()] + trecho + texto[m.end():])
PY
}

confere() {   # $1 = arquivo · $2 = regex com UM grupo (o número) · $3 = esperado · $4 = o que é
  local arq="$RAIZ/$1" achado
  [ -f "$arq" ] || { falhou "$1 não existe"; return; }
  achado="$(grep -oE "$2" "$arq" | head -n1 | grep -oE '[0-9]+' | head -n1)"
  if [ -z "$achado" ]; then
    falhou "$1: não achei a afirmação sobre $4 (o texto mudou de forma?)"
  elif [ "$achado" != "$3" ]; then
    if [ "${MEOW_NUMEROS_CORRIGIR:-0}" = "1" ] && corrige "$arq" "$2" "$3"; then
      passou "$1: $4 corrigido de $achado para $3"
    else
      falhou "$1 diz $achado $4; são $3"
    fi
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
# É o defeito que o cabeçalho deste arquivo descreve, na forma clássica: um
# lado da tradução é atualizado e o outro não.
#
# O `actions` entra no regex porque `[0-9]+ settings and` sozinho casa também
# com a linha do papel de parede, mais abaixo no mesmo arquivo.
confere README.en.md '[0-9]+ settings and [0-9]+ actions' "$CHAVES"       "settings"

confere app/LEIA-ME.md 'As [0-9]+ chaves'                "$CHAVES"        "chaves"

# O BADGE DO NAVEGADOR É O ÚNICO QUE ESTE ARQUIVO **NÃO** SABE CONTAR, e está
# dito aqui para ninguém procurar o cobrador que não existe: o placar de
# `tests/app-navegador.py` só aparece RODANDO a suíte (ele conta as afirmações
# que de fato executaram, e algumas se pulam quando o recurso não está na
# máquina).
placar_pt="$(grep -oE 'navegador-[0-9]+%2F[0-9]+' "$RAIZ/README.md" | head -n1 | sed 's/^navegador-//')"
placar_en="$(grep -oE 'browser-[0-9]+%2F[0-9]+' "$RAIZ/README.en.md" | head -n1 | sed 's/^browser-//')"
if [ -z "$placar_pt" ] || [ -z "$placar_en" ]; then
  falhou "não achei o badge do navegador em um dos README (mudou de forma?)"
elif [ "$placar_pt" != "$placar_en" ]; then
  falhou "o badge do navegador diz $placar_pt no README.md e $placar_en no README.en.md"
else
  passou "os dois README dizem o mesmo placar do navegador: $placar_pt"
fi

# As linhas de baixo daquele arquivo são história e não entram aqui — ver o
# cabeçalho deste teste.
confere docs/SPRINTS.md '\| `install.sh` \| [0-9]+ etapas' "$ETAPAS"       "etapas (estado de hoje)"
confere docs/SPRINTS.md '\*\*[0-9]+\*\* conferências'      "$CONFERENCIAS" "conferências (estado de hoje)"
# A linha do PAINEL do mesmo quadro. Ela envelheceu calada, pelo mesmo motivo
# do `README.en.md` lá em cima: ninguém a cobrava.
confere docs/SPRINTS.md '\| painel \| [0-9]+ chaves'      "$CHAVES"       "chaves (estado de hoje)"

if [ -n "${ACOES:-}" ]; then
  confere README.md      '[0-9]+ ações em'   "$ACOES" "ações"
  confere app/LEIA-ME.md '[0-9]+ ações, com a saída' "$ACOES" "ações"
fi

# 5. A lista de aplicativos ocultados existe em DOIS lugares
lista_do_script() {
  awk '
    /^OCULTAR=\(/           { dentro = 1; next }
    /^OCULTAR_DUPLICATA=\(/ { dentro = 1; next }
    dentro && /^\)/         { dentro = 0; next }
    dentro { sub(/#.*/, ""); gsub(/[ \t]/, ""); if ($0 != "") print }
  ' "$RAIZ/scripts/ocultar_apps.sh" | LC_ALL=C sort
}
lista_do_conf() {
  sed -n 's/^LANCADOR_OCULTAR="\(.*\)"$/\1/p' "$RAIZ/meow.conf.exemplo" \
    | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' \
    | grep -v '^$' | LC_ALL=C sort
}

_script_n="$(lista_do_script | grep -c .)"
_conf_n="$(lista_do_conf | grep -c .)"
if [ "$_script_n" = "0" ] || [ "$_conf_n" = "0" ]; then
  falhou "não achei uma das duas listas de aplicativos ocultados (script: $_script_n, conf: $_conf_n)"
elif ! _diferenca="$(diff <(lista_do_script) <(lista_do_conf))"; then
  falhou "a lista de ocultar_apps.sh e a chave LANCADOR_OCULTAR não batem:"
  printf '%s\n' "$_diferenca" | sed 's/^/       /' >&2
  printf '       (< só no script, > só no meow.conf.exemplo)\n' >&2
else
  passou "ocultar_apps.sh e LANCADOR_OCULTAR dizem os mesmos $_script_n aplicativos"
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

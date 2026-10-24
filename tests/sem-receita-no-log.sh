#!/usr/bin/env bash
# sem-receita-no-log.sh — nenhuma etapa termina em "faça você mesmo".
#
# Uma etapa que sabe o conserto ou FAZ, ou oferece um botão que faz
# (`meow_pendencia_acionavel`, lib/comum.sh). Quando nem o botão é possível —
# porque o que falta é decisão humana genuína —, a mensagem diz A DECISÃO, e não
# a receita.
#
# Na prática, o que o teste procura é a receita: uma linha de `meow_info` ou
# `meow_aviso` que carregue `curl | sh`, `git clone` ou `apt install` (em
# qualquer das duas grafias, `apt` e `apt-get`).
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$RAIZ" || exit 2

EU="tests/sem-receita-no-log.sh"
achados=0
isentos=0
ok()    { printf 'ok: %s\n' "$1"; }
acusa() {
  printf 'FALHOU: %s:%s — %s\n' "$1" "$2" "$4" >&2
  printf '        %s\n' "$3" >&2
  achados=$((achados+1))
}

# AS ISENÇÕES, uma a uma, com o motivo ao lado
#
# Cada entrada é um trecho LITERAL da linha isenta (comparação por substring,
# sem regex).
#
#   O argumento era que a ponte root não tinha verbo de pacote, e terminava
#   assim: "O dia em que a ponte ganhar um verbo de pacote, estas oito viram
#   botão e a isenção para de casar sozinha."
ISENTAS=(
  'meow_info "      sudo apt install ${faltam_apt% }"'
)

isenta() {
  local linha="$1" i
  for i in "${ISENTAS[@]}"; do
    case "$linha" in *"$i"*) return 0 ;; esac
  done
  return 1
}

# `-print0`/`read -d ''` porque nome de arquivo pode ter espaço, e um `for`
# sobre `$(find)` partiria o caminho no meio — a armadilha que o resto da suíte
# já evita do mesmo jeito.
while IFS= read -r -d '' arq; do
  case "$arq" in
    "./$EU"|./lib/comum.sh) continue ;;
  esac
  num=0
  while IFS= read -r linha || [ -n "$linha" ]; do
    num=$((num+1))
    # Só linha que CHAMA um dos dois verbos. Uma linha de comentário que os
    # mencione não é mensagem na tela de ninguém.
    case "$linha" in
      *meow_info*|*meow_aviso*) : ;;
      *) continue ;;
    esac
    # Comentário puro (a linha inteira começa com `#`, com ou sem recuo) fica de
    # fora: ele documenta, não fala.
    aparada="${linha#"${linha%%[![:space:]]*}"}"
    case "$aparada" in '#'*) continue ;; esac

    motivo=""
    case "$linha" in
      *'curl'*'| sh'*|*'curl'*'|sh'*)  motivo="receita de \`curl | sh\` dentro de uma mensagem" ;;
      *'git clone'*)                   motivo="receita de \`git clone\` dentro de uma mensagem" ;;
      # As duas grafias do mesmo comando. `apt-get` é a que os scripts usam
      # quando querem a interface estável; `apt`, a que a pessoa digita. Casar
      # só uma deixa a outra passar, e foi o que aconteceu.
      *'apt install'*|*'apt-get install'*)
                                       motivo="receita de \`apt install\` dentro de uma mensagem" ;;
    esac
    [ -n "$motivo" ] || continue

    if isenta "$linha"; then
      isentos=$((isentos+1))
      continue
    fi
    acusa "${arq#./}" "$num" "$aparada" "$motivo"
  done < "$arq"
done < <(find ./scripts ./lib ./scripts/temas-de-apps \
              -type f \( -name '*.sh' -o -name '*.bash' \) -print0 2>/dev/null)

printf '\n'
if [ "$achados" -eq 0 ]; then
  ok "sem receita no log: nenhuma etapa manda a pessoa rodar o que o projeto sabe fazer ($isentos isenções)"
  exit 0
fi
printf 'FALHOU: %d receita(s) solta(s) em mensagem (%d isenções)\n' "$achados" "$isentos" >&2
printf 'O conserto é o `meow_pendencia_acionavel` do lib/comum.sh — ver a sprint P2.\n' >&2
exit 1

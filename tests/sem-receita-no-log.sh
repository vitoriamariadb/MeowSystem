#!/usr/bin/env bash
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

while IFS= read -r -d '' arq; do
  case "$arq" in
    "./$EU"|./lib/comum.sh) continue ;;
  esac
  num=0
  while IFS= read -r linha || [ -n "$linha" ]; do
    num=$((num+1))
    case "$linha" in
      *meow_info*|*meow_aviso*) : ;;
      *) continue ;;
    esac
    aparada="${linha#"${linha%%[![:space:]]*}"}"
    case "$aparada" in '#'*) continue ;; esac

    motivo=""
    case "$linha" in
      *'curl'*'| sh'*|*'curl'*'|sh'*)  motivo="receita de \`curl | sh\` dentro de uma mensagem" ;;
      *'git clone'*)                   motivo="receita de \`git clone\` dentro de uma mensagem" ;;
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

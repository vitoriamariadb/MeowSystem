#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$RAIZ" || exit 0

mapfile -t STAGED < <(git diff --cached --name-only --diff-filter=ACM)
[ "${#STAGED[@]}" -gt 0 ] || exit 0

intervalos() {
  git diff --cached -U0 -- "$1" | awk '
    /^@@/ { split($3, a, ","); ini = substr(a[1], 2) + 0; n = (a[2] == "" ? 1 : a[2] + 0)
            if (n > 0) printf "%s%d-%d", (s++ ? "," : ""), ini, ini + n - 1 }'
}

for f in "${STAGED[@]}"; do
  [ -f "$f" ] || continue
  git diff --quiet -- "$f" || continue
  faixa="$(intervalos "$f")"
  [ -n "$faixa" ] || continue
  case "$(python3 scripts/comentarios.py zerar --linhas "$faixa" "$f")" in
    mudou*)    git add -- "$f"; printf 'higiene: comentário tirado de %s\n' "$f" ;;
    recusado*) printf 'higiene: %s ficou com comentário (o código mudaria)\n' "$f" ;;
  esac
done

barrado=0
antes="$(git diff --name-only)"
if ! MEOW_NUMEROS_CORRIGIR=1 bash tests/numeros.sh >/dev/null 2>&1; then
  bash tests/numeros.sh >&2 || barrado=1
fi
for f in $(comm -13 <(printf '%s\n' "$antes" | sort) <(git diff --name-only | sort)); do
  git add -- "$f"
  printf 'higiene: número corrigido em %s\n' "$f"
done

for t in frases-velhas portabilidade; do
  saida="$(bash "tests/$t.sh" 2>&1)" || { printf '%s\n' "$saida" | grep -vE '^\s*ok' >&2; barrado=1; }
done

[ "$barrado" -eq 0 ] || printf 'higiene: commit barrado; corrija o que está acima.\n' >&2
exit "$barrado"

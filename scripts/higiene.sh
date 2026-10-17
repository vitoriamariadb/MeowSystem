#!/usr/bin/env bash
# higiene.sh — o gancho de commit do repositório, chamado pelo pre-commit global.
#
# 1. comentário de registro (id de sprint, data, conferência, nome de ferramenta
#    de IA) sai das linhas que o commit toca; o porquê fica;
# 2. número que o tests/numeros.sh sabe contar é corrigido e entra no commit;
# 3. frase velha e caminho de máquina barram o commit (tests/frases-velhas.sh,
#    tests/portabilidade.sh).
#
# Determinístico, sem rede. Os testes leem a árvore de trabalho, não o índice.
# 0 = pode commitar · 1 = barrado.
set -uo pipefail
RAIZ="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$RAIZ" || exit 0

mapfile -t STAGED < <(git diff --cached --name-only --diff-filter=ACM)
[ "${#STAGED[@]}" -gt 0 ] || exit 0

# Intervalos "ini-fim" das linhas novas de um arquivo no índice.
intervalos() {
  git diff --cached -U0 -- "$1" | awk '
    /^@@/ { split($3, a, ","); ini = substr(a[1], 2) + 0; n = (a[2] == "" ? 1 : a[2] + 0)
            if (n > 0) printf "%s%d-%d", (s++ ? "," : ""), ini, ini + n - 1 }'
}

for f in "${STAGED[@]}"; do
  case "$f" in
    bin/*|lib/*|scripts/*|app/*|tests/*|src/*|install.sh) ;;
    *) continue ;;
  esac
  [ -f "$f" ] || continue
  # Com mudança fora do índice, o `git add` levaria junto o que não foi pedido.
  git diff --quiet -- "$f" || continue
  faixa="$(intervalos "$f")"
  [ -n "$faixa" ] || continue
  case "$(python3 scripts/comentarios.py enxugar --linhas "$faixa" "$f")" in
    mudou*)    git add -- "$f"; printf 'higiene: comentário de registro reduzido em %s\n' "$f" ;;
    recusado*) printf 'higiene: %s não foi enxugado (o código mudaria)\n' "$f" ;;
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

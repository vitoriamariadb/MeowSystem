#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$RAIZ" || exit 2
while IFS= read -r v; do unset "$v"; done < <(compgen -e | grep '^GIT_')

CONFERIR=0 CAPTURAR=1 COMMIT=0
for a in "$@"; do
  case "$a" in
    --conferir)     CONFERIR=1; CAPTURAR=0 ;;
    --sem-capturas) CAPTURAR=0 ;;
    --commit)       COMMIT=1 ;;
    *) printf 'uso: readme.sh [--conferir] [--sem-capturas] [--commit]\n' >&2; exit 2 ;;
  esac
done

GERADOS=(README.md README.en.md docs/capturas/readme)

if [ "$COMMIT" -eq 1 ] && [ -n "$(git status --porcelain -- "${GERADOS[@]}")" ]; then
  printf 'readme: o README tem mudança sem commit; fica como está\n'
  exit 0
fi

if [ "$CAPTURAR" -eq 1 ]; then
  [ -d "$HOME/.cache/ms-playwright" ] && \
    export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-$HOME/.cache/ms-playwright}"
  PY=""
  while IFS= read -r py; do
    [ -x "$py" ] || continue
    "$py" -c 'import playwright.sync_api' >/dev/null 2>&1 && { PY="$py"; break; }
  done < <(
    type -ap python3
    command -v pyenv >/dev/null 2>&1 && pyenv which python3 2>/dev/null
    printf '%s\n' "$HOME/.local/share/meowsystem/venv-testes/bin/python3"
  )
  if [ -n "$PY" ]; then
    "$PY" scripts/readme.py capturas
    [ $? -le 1 ] || printf 'readme: as capturas falharam; o texto segue\n' >&2
  else
    printf 'pulado: nenhum python3 com Playwright; as capturas ficaram como estavam\n'
  fi
fi

if [ "$CONFERIR" -eq 1 ]; then
  python3 scripts/readme.py texto --conferir
  exit $?
fi
python3 scripts/readme.py texto
rc=$?
[ "$rc" -le 1 ] || exit "$rc"

[ "$COMMIT" -eq 1 ] || exit 0
PRESENTES=()
for g in "${GERADOS[@]}"; do [ -e "$g" ] && PRESENTES+=("$g"); done
git add -- "${PRESENTES[@]}"
if git diff --cached --quiet -- "${PRESENTES[@]}"; then
  exit 0
fi
git commit -q -m "docs(readme): regerado do código" -- "${PRESENTES[@]}" || exit 2
printf 'readme: regerado no commit %s\n' "$(git rev-parse --short HEAD)"
exit 1

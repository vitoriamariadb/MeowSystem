#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }

COMPLETION="$RAIZ/dados/zsh/_meow"

despachados="$(awk '
  /^despachar\(\) \{/ { dentro = 1; next }
  dentro && /^}/ { exit }
  dentro && /^    [^ ()]+\)/ { sub(/\).*/, ""); sub(/^ +/, ""); print }
' "$RAIZ/scripts/meow")"

oferecidos="$(awk '
  /^  comandos=\(/ { dentro = 1; next }
  dentro && /^  \)/ { exit }
  dentro { sub(/^ +'"'"'/, ""); sub(/:.*/, ""); print }
' "$COMPLETION")"

[ -n "$despachados" ] && ok "achei os padrões do despachar em scripts/meow ($(wc -l <<<"$despachados") linhas)" \
  || falha "não achei os padrões do despachar em scripts/meow"
[ -n "$oferecidos" ] && ok "achei a lista de comandos da completion ($(wc -l <<<"$oferecidos") nomes)" \
  || falha "não achei a lista de comandos da completion"

canonicos=()
apelidos=()
while IFS= read -r padrao; do
  IFS='|' read -ra partes <<<"$padrao"
  case "${partes[0]}" in '""'|'*'|-*) continue ;; esac
  canonicos+=("${partes[0]}")
  for p in "${partes[@]}"; do [ -n "$p" ] && [[ "$p" != -* ]] && apelidos+=("$p"); done
done <<<"$despachados"

for verbo in "${canonicos[@]}"; do
  if grep -qxF "$verbo" <<<"$oferecidos"; then ok "a completion oferece «$verbo»"
  else falha "a completion não oferece «$verbo», que o despachar do meow aceita"; fi
done

while IFS= read -r nome; do
  [ -n "$nome" ] || continue
  if printf '%s\n' "${apelidos[@]}" | grep -qxF "$nome"; then ok "«$nome» da completion existe no despachar"
  else falha "a completion oferece «$nome», que o despachar do meow não aceita"; fi
done <<<"$oferecidos"

if [ "$falhas" -gt 0 ]; then
  printf '\n%d falha(s) na completion dos verbos.\n' "$falhas" >&2
  exit 1
fi
printf '\ntodo verbo do meow é oferecido pela completion, e ela não oferece verbo que o meow não tem.\n'

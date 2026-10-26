#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
EU="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)/$(basename "${BASH_SOURCE[0]}")"
FALHAS=0

falhou() { printf 'FALHOU: %s\n' "$*" >&2; FALHAS=$((FALHAS + 1)); }
passou() { printf 'ok: %s\n' "$*"; }

ISENTOS=(
  icones_orfaos.py
)

CONHECIDOS=(
  derivar_claro.py
)

na_lista() {
  local alvo="$1"; shift
  local i
  for i in "$@"; do
    [ "$i" = "$alvo" ] && return 0
  done
  return 1
}

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

orfaos=()
varrer() {
  local alvo nome chamadas ign
  orfaos=()
  for alvo in "$RAIZ"/scripts/*.sh "$RAIZ"/scripts/*.py; do
  [ -f "$alvo" ] || continue
  nome="$(basename "$alvo")"
  chamadas="$(grep -nHF "$nome" "${CHAMADORES[@]}" 2>/dev/null \
              | grep -v "^$alvo:" \
              | grep -vE ':[0-9]+:[[:space:]]*(#|//|\*)')"
  for ign in "${IGNORADOS[@]:-}"; do
    [ -n "$ign" ] || continue
    [ -n "$chamadas" ] || break
    chamadas="$(printf '%s\n' "$chamadas" | grep -v "^$ign:")"
  done
  [ -n "$chamadas" ] && continue
  orfaos+=("$nome")
  done
}

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
    printf 'aviso: scripts/%s — órfão conhecido, dívida declarada na P23 (o motivo está na lista CONHECIDOS deste arquivo)\n' "$nome"
    DECLARADOS=$((DECLARADOS + 1))
  else
    falhou "scripts/$nome não é chamado por ninguém — mencione-o ou aposente-o numa linha própria"
  fi
done

printf '\n'
if [ "$FALHAS" -gt 0 ]; then
  printf '%s órfão(s) NOVO(S), fora do que está declarado aqui. Este teste NÃO apaga:\n' \
         "$FALHAS" >&2
  printf 'apagar é decisão sua, num commit só dela — ou ele entra na lista, com o motivo.\n' >&2
  exit 1
fi
passou "nenhum órfão novo — os $DECLARADOS que apareceram estão todos declarados acima"
exit 0

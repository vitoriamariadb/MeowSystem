#!/usr/bin/env bash
# listar-apps.sh — tudo que tem .desktop no seu sistema (nome, id, ícone, origem)
# Uso:  bash listar-apps.sh              -> tabela na tela
#       bash listar-apps.sh > apps.md    -> salva
#       bash listar-apps.sh --csv        -> csv pra planilha
set -uo pipefail

FMT="${1:-tabela}"

DIRS=(
  "/usr/share/applications:apt"
  "/usr/local/share/applications:local"
  "$HOME/.local/share/applications:usuário"
  "/var/lib/flatpak/exports/share/applications:flatpak-sys"
  "$HOME/.local/share/flatpak/exports/share/applications:flatpak-user"
  "/var/lib/snapd/desktop/applications:snap"
)

[ "$FMT" = "--csv" ] && echo "origem,arquivo,nome,icone,exec,nodisplay"

total=0
for entry in "${DIRS[@]}"; do
  dir="${entry%%:*}"; origem="${entry##*:}"
  [ -d "$dir" ] || continue
  [ "$FMT" = "--csv" ] || printf '\n### %s  (%s)\n\n' "$origem" "$dir"
  while IFS= read -r f; do
    nome=$(grep -m1 '^Name='     "$f" 2>/dev/null | cut -d= -f2-)
    icon=$(grep -m1 '^Icon='     "$f" 2>/dev/null | cut -d= -f2-)
    exe=$( grep -m1 '^Exec='     "$f" 2>/dev/null | cut -d= -f2- | awk '{print $1}')
    nod=$( grep -m1 '^NoDisplay=' "$f" 2>/dev/null | cut -d= -f2-)
    id=$(basename "$f" .desktop)
    total=$((total+1))
    if [ "$FMT" = "--csv" ]; then
      printf '%s,"%s","%s","%s","%s",%s\n' "$origem" "$id" "${nome:-}" "${icon:-}" "${exe:-}" "${nod:-false}"
    else
      printf '%-46s | %-30s | %-34s%s\n' \
        "$id" "${nome:--}" "${icon:--}" \
        "$( [ "${nod,,}" = "true" ] && echo ' [oculto]' )"
    fi
  done < <(find "$dir" -maxdepth 1 -name '*.desktop' 2>/dev/null | sort)
done

[ "$FMT" = "--csv" ] || printf '\n%s aplicativos com .desktop\n' "$total"

#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$RAIZ" || exit 2
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

saida="$(python3 scripts/readme.py texto --conferir 2>&1)"
[ $? -eq 0 ] && ok "o README diz o que o código diz" || falha "o README está velho: rode scripts/readme.sh" "$saida"

tag="$(git tag --list 'v[0-9]*' --merged HEAD --sort=-v:refname 2>/dev/null | head -n1)"
if [ -n "$tag" ]; then
  grep -qF "vers%C3%A3o-$tag-" README.md && ok "README.md: o badge diz $tag" || falha "README.md: o badge da versão não diz $tag"
  grep -qF "version-$tag-" README.en.md && ok "README.en.md: o badge diz $tag" || falha "README.en.md: o badge da versão não diz $tag"
else
  printf 'sem tag de versão neste clone: o badge não foi comparado\n'
fi

for f in README.md README.en.md; do
  velhas="$(grep -nE 'Início|Salvar e aplicar|Modo de leitura|Usar este|catorze páginas|navegador-[0-9]|browser-[0-9]' "$f")"
  [ -z "$velhas" ] && ok "$f: nenhuma palavra do painel antigo" || falha "$f fala do painel antigo" "$velhas"

  faltam=""
  while IFS= read -r img; do
    case "$img" in http*|'') continue ;; esac
    [ -e "$img" ] || faltam+="$img "
  done < <(grep -oE '(src="[^"]+"|\]\([^)#]+\))' "$f" | sed -E 's/^src="//; s/"$//; s/^\]\(//; s/\)$//')
  [ -z "$faltam" ] && ok "$f: toda imagem e todo link local existem" || falha "$f cita o que não existe: $faltam"

  grep -qF 'Vitória Maria' "$f" && grep -qF 'André Farias' "$f" \
    && ok "$f: as duas autorias" || falha "$f não nomeia Vitória Maria e André Farias"
  grep -qF './install.sh --perfil' "$f" && ok "$f: o --perfil está lá" || falha "$f perdeu o ./install.sh --perfil"
done

capturas="$(grep -oE 'docs/capturas/readme/[a-z-]+\.png' README.md | sort -u | wc -l)"
[ "$capturas" -eq 4 ] && ok "as quatro portas aparecem em captura" || falha "o README mostra $capturas captura(s) das portas, e são quatro"

if [ "$falhas" -gt 0 ]; then
  printf '\n%d falha(s) no README.\n' "$falhas" >&2
  exit 1
fi
printf '\no README está em dia com o código.\n'

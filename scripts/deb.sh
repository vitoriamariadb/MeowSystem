#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
umask 022

FORA=(tests/ docs/sprints/ docs/capturas/ .github/ packaging/ .gitignore .gitattributes LICENSE)
CASA=usr/share/meowsystem

uso() {
  printf 'uso: scripts/deb.sh [versão] [--saida <pasta>]\n'
  printf '  gera <pasta>/meowsystem_<versão>_all.deb (padrão: dist/) com o que o git lista\n'
  printf '  a versão vem da última tag vX.Y.Z, mais +<commits> depois dela\n'
}

erro() { printf 'deb: %s\n' "$*" >&2; }

VERSAO="" SAIDA="$RAIZ/dist"
while [ $# -gt 0 ]; do
  case "$1" in
    --saida) SAIDA="${2:-}"; [ -n "$SAIDA" ] || { uso >&2; exit 2; }; shift ;;
    --saida=*) SAIDA="${1#--saida=}" ;;
    -h|--help) uso; exit 0 ;;
    -*) uso >&2; exit 2 ;;
    *) VERSAO="$1" ;;
  esac
  shift
done

for c in dpkg-deb git gzip md5sum; do
  command -v "$c" >/dev/null 2>&1 || { erro "falta o $c"; exit 3; }
done

versao_do_git() {
  local d tag n
  d="$(git -C "$RAIZ" describe --tags --long --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null)" || return 1
  n="${d%-g*}"; n="${n##*-}"
  tag="${d%-"$n"-g*}"; tag="${tag#v}"
  if [ "$n" = "0" ]; then printf '%s' "$tag"; else printf '%s+%s' "$tag" "$n"; fi
}

[ -n "$VERSAO" ] || VERSAO="$(versao_do_git)" || { erro "sem tag vX.Y.Z no git e sem versão no argumento"; exit 2; }
[[ $VERSAO =~ ^[0-9][A-Za-z0-9.+~]*$ ]] || { erro "versão inválida para o dpkg: $VERSAO"; exit 2; }

TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT
ARV="$TMP/arvore"
mkdir -p "$ARV/$CASA" "$ARV/usr/bin" "$ARV/usr/share/doc/meowsystem" "$ARV/DEBIAN" || exit 2

fora() {
  local p="$1" f
  for f in "${FORA[@]}"; do
    case "$f" in
      */) [[ $p == "$f"* ]] && return 0 ;;
      *)  [ "$p" = "$f" ] && return 0 ;;
    esac
  done
  return 1
}

: > "$TMP/lista"; : > "$TMP/executaveis"
while IFS= read -r -d '' linha; do
  modo="${linha%% *}"; caminho="${linha#*$'\t'}"
  fora "$caminho" && continue
  [ -e "$RAIZ/$caminho" ] || [ -L "$RAIZ/$caminho" ] || continue
  printf '%s\0' "$caminho" >> "$TMP/lista"
  if [ "$modo" = "100755" ] && [ -f "$RAIZ/$caminho" ]; then
    case "$(head -c 4 "$RAIZ/$caminho" | od -An -tx1 | tr -d ' \n')" in
      2321*|7f454c46) printf '%s\0' "$caminho" >> "$TMP/executaveis" ;;
    esac
  fi
done < <(git -C "$RAIZ" ls-files -s -z)

[ -s "$TMP/lista" ] || { erro "o git não listou nada"; exit 2; }
tar -C "$RAIZ" --null -T "$TMP/lista" -cf - | tar -C "$ARV/$CASA" -xf - || { erro "a cópia da árvore falhou"; exit 2; }
find "$ARV" -type d -exec chmod 755 {} +
find "$ARV/$CASA" -type f -exec chmod 644 {} +
(cd "$ARV/$CASA" && xargs -0 -r chmod 755 < "$TMP/executaveis") || exit 2

ln -s ../share/meowsystem/bin/meow "$ARV/usr/bin/meow"

DOC="$ARV/usr/share/doc/meowsystem"
install -m 644 "$RAIZ/packaging/deb/copyright" "$DOC/copyright" || exit 2
COMMIT="$(git -C "$RAIZ" rev-parse --short HEAD 2>/dev/null || printf 'sem-git')"
DATA="$(git -C "$RAIZ" log -1 --format=%cD 2>/dev/null || date -R)"
QUEM="$(git -C "$RAIZ" config user.name 2>/dev/null || git -C "$RAIZ" log -1 --format=%an 2>/dev/null)"
CORREIO="$(git -C "$RAIZ" config user.email 2>/dev/null || git -C "$RAIZ" log -1 --format=%ae 2>/dev/null)"
[ -n "$QUEM" ] && [[ $CORREIO == ?*@?* ]] || { erro "o git não diz quem empacota (user.name e user.email)"; exit 2; }
MANTENEDOR="$QUEM <$CORREIO>"
{
  printf 'meowsystem (%s) noble; urgency=medium\n\n' "$VERSAO"
  printf '  * Pacote gerado do commit %s.\n\n' "$COMMIT"
  printf ' -- %s  %s\n' "$MANTENEDOR" "$DATA"
} | gzip -9n > "$DOC/changelog.gz" || exit 2
chmod 644 "$DOC/changelog.gz"

TAMANHO="$(du -sk --apparent-size --exclude=DEBIAN "$ARV" | cut -f1)"
sed -e "s|@VERSAO@|$VERSAO|" -e "s|@TAMANHO@|$TAMANHO|" -e "s|@MANTENEDOR@|$MANTENEDOR|" "$RAIZ/packaging/deb/control" > "$ARV/DEBIAN/control" || exit 2
(cd "$ARV" && find usr -type f -print0 | LC_ALL=C sort -z | xargs -0 md5sum) > "$ARV/DEBIAN/md5sums" || exit 2
chmod 644 "$ARV/DEBIAN/control" "$ARV/DEBIAN/md5sums"

mkdir -p "$SAIDA" || { erro "não consegui criar $SAIDA"; exit 2; }
DEB="$(cd "$SAIDA" && pwd -P)/meowsystem_${VERSAO}_all.deb"
EMBRULHO=()
command -v fakeroot >/dev/null 2>&1 && EMBRULHO=(fakeroot)
${EMBRULHO[@]+"${EMBRULHO[@]}"} dpkg-deb --root-owner-group -Zxz --build "$ARV" "$DEB" >/dev/null || { erro "o dpkg-deb falhou"; exit 2; }
printf '%s\n' "$DEB"

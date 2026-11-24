#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1" "${3:-}"; fi; }

LAR="${SUITE_CASA_REAL:-$HOME}"
APPLETS_GIT="${DK_FONTE_GIT:-$LAR/.local/src/cosmic-applets}"
read -r VERSAO COMMIT < "$RAIZ/dados/patches/dock.versao"
P="$RAIZ/dados/patches/cosmic-app-list-casamento-por-padrao.patch"

if ! git -C "$APPLETS_GIT" cat-file -e "$COMMIT^{commit}" 2>/dev/null; then
  printf 'pulado: sem o fonte do cosmic-applets (%s) nesta máquina\n' "${COMMIT:0:7}"
  exit 0
fi

mkdir -p "$T/applets"
git -C "$APPLETS_GIT" archive "$COMMIT" Cargo.toml Cargo.lock cosmic-app-list/src/app.rs | tar x -C "$T/applets"

printf '\n1. o patch entra com -F0 no fonte real\n'
confere "o commit fixado é o que a versão $VERSAO diz" '[ "${COMMIT:0:7}" = "${VERSAO##*~}" ]'
confere "o cosmic-applets ${COMMIT:0:7} aceita o patch do casamento sem folga" \
  '(cd "$T/applets" && patch -p1 -F0 --forward --dry-run < "$P") >/dev/null'

printf '\n2. aplicado, o que importa está no fonte\n'
( cd "$T/applets" && patch -p1 -F0 --forward --no-backup-if-mismatch < "$P" >/dev/null )
A="$T/applets/cosmic-app-list/src/app.rs"
confere "o marcador da dock está no fonte" 'grep -q "MEOW-DOCK-PATCH-1" "$A"'
confere "o casamento exato vem primeiro, a segunda tentativa só no else" \
  'grep -B2 "} else if let Some(entry) = find_app_by_pattern(&self.desktop_entries, &info.app_id) {" "$A" | tr -d "\n " | grep -qx "ifletSome(entry)=fde::find_app_by_id(&self.desktop_entries,unicase_appid){entry.clone()}elseifletSome(entry)=find_app_by_pattern(&self.desktop_entries,&info.app_id){"'
confere "a fábrica segue de reserva: o fallback por nome de jogo continua lá" 'grep -q "is_proton_game" "$A"'
confere "os testes de unidade entram no módulo" 'grep -q "^mod tests {" "$A" && grep -q "fn ambiguous_prefix_matches_nothing" "$A"'
confere "a crate do casamento é a 0.8.4 que o Cargo.lock trava" 'grep -A1 "^name = \"freedesktop-desktop-entry\"" "$T/applets/Cargo.lock" | grep -qx "version = \"0.8.4\""'

[ "$falhas" = 0 ] && printf '\nok: a série da dock entra com -F0 no cosmic-applets %s\n' "${COMMIT:0:7}"
exit $((falhas > 0))

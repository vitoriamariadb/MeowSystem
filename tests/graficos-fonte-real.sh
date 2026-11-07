#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /'; falhas=$((falhas + 1)); }
confere() { if (set +o pipefail; eval "$2"); then ok "$1"; else falha "$1" "${3:-}"; fi; }

antes() {
  awk -v bloco="$1" -v primeiro="$2" -v depois="$3" \
    '$0 ~ bloco {r = 1} r && !d && $0 ~ primeiro {d = NR} r && !a && $0 ~ depois {a = NR} END {exit !(d && a && d < a)}' "$4"
}

LAR="${SUITE_CASA_REAL:-$HOME}"
PORTAL_GIT="${GR_FONTE_PORTAL_GIT:-$LAR/.local/src/xdg-desktop-portal-cosmic}"
TOOLKIT_GIT="${GR_FONTE_TOOLKIT_GIT:-$LAR/.local/src/cosmic-protocols}"
PORTAL_REV=f448ddf
TOOLKIT_REV=c0cff4d

if ! git -C "$PORTAL_GIT" cat-file -e "$PORTAL_REV^{commit}" 2>/dev/null || ! git -C "$TOOLKIT_GIT" cat-file -e "$TOOLKIT_REV^{commit}" 2>/dev/null; then
  printf 'pulado: sem o fonte do portal (%s) e do cosmic-protocols (%s) nesta máquina\n' "$PORTAL_REV" "$TOOLKIT_REV"
  exit 0
fi

mkdir -p "$T/portal" "$T/toolkit"
git -C "$PORTAL_GIT" archive "$PORTAL_REV" Cargo.toml Cargo.lock src/screencast_thread.rs | tar x -C "$T/portal"
git -C "$TOOLKIT_GIT" archive "$TOOLKIT_REV" client-toolkit/src/screencopy/dispatch.rs | tar x -C "$T/toolkit"
P="$RAIZ/patches"

printf '\n1. os patches entram com -F0 no fonte real\n'
confere "o portal 1.11.0 (f448ddf) aceita o patch da P159 sem folga" \
  '(cd "$T/portal" && patch -p1 -F0 --forward --dry-run < "$P/xdg-desktop-portal-cosmic-modificador-unico.patch") >/dev/null'
confere "o portal aceita o [patch] do toolkit com caminho relativo" \
  '(cd "$T/portal" && patch -p1 -F0 --forward --dry-run < "$P/xdg-desktop-portal-cosmic-toolkit-local.patch") >/dev/null'
confere "o cosmic-protocols c0cff4d aceita o patch da P160 sem folga" \
  '(cd "$T/toolkit" && patch -p1 -F0 --forward --dry-run < "$P/cosmic-protocols-frame-destruido-antes.patch") >/dev/null'
confere "o rev do toolkit no Cargo.lock do portal é o c0cff4d" 'grep -q "cosmic-protocols?rev=$TOOLKIT_REV#" "$T/portal/Cargo.lock"'

printf '\n2. aplicados, o que importa está no fonte\n'
( cd "$T/portal" && for p in xdg-desktop-portal-cosmic-modificador-unico xdg-desktop-portal-cosmic-toolkit-local; do patch -p1 -F0 --forward --no-backup-if-mismatch < "$P/$p.patch" >/dev/null; done )
( cd "$T/toolkit" && patch -p1 -F0 --forward --no-backup-if-mismatch < "$P/cosmic-protocols-frame-destruido-antes.patch" >/dev/null )
confere "o None(0) do PipeWire vira lista de um item" 'grep -q "spa::utils::ChoiceEnum::None(modifier) => vec!\[\*modifier\]" "$T/portal/src/screencast_thread.rs"'
confere "o modifier velho some quando o cliente volta para SHM" 'grep -q "self.modifier = None;" "$T/portal/src/screencast_thread.rs"'
confere "o marcador do portal está no fonte" 'grep -q "MEOW-PORTAL-PATCH-1" "$T/portal/src/screencast_thread.rs"'
confere "o SHM forçado não está no fonte (é cura de máquina)" '! grep -q "let _ = (dmabuf, fixated)" "$T/portal/src/screencast_thread.rs"'
confere "o toolkit destrói o frame antes de avisar o consumidor" 'antes "Event::Ready" "screencopy_frame.destroy" "app_data.ready" "$T/toolkit/client-toolkit/src/screencopy/dispatch.rs"'
confere "o Failed também destrói antes de avisar" 'antes "Event::Failed" "screencopy_frame.destroy" "app_data.failed" "$T/toolkit/client-toolkit/src/screencopy/dispatch.rs"'
confere "o marcador do toolkit está no fonte" 'grep -q "MEOW-TOOLKIT-PATCH-1" "$T/toolkit/client-toolkit/src/screencopy/dispatch.rs"'
confere "o Cargo.toml do portal aponta para meow-toolkit, relativo" 'grep -q "path = \"meow-toolkit/client-toolkit\"" "$T/portal/Cargo.toml" && ! grep -q "/home/" "$T/portal/Cargo.toml"'

[ "$falhas" = 0 ] && printf '\nok: a série entra com -F0 no portal 1.11.0 (f448ddf) e no cosmic-protocols c0cff4d\n'
exit $((falhas > 0))

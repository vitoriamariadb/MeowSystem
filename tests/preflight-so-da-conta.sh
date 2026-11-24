#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/casa"
cat > "$T/bin/pgrep" <<FIM
#!/bin/sh
echo "pgrep \$*" >> "$T/pgrep.log"
dono=outro
for a in "\$@"; do [ "\$a" = "-u" ] && dono=meu; done
[ "\$dono" = meu ] && [ -f "$T/meu-cosmic" ] && { echo 4242; exit 0; }
[ "\$dono" = outro ] && [ -f "$T/outro-cosmic" ] && { echo 4243; exit 0; }
exit 1
FIM
chmod 755 "$T/bin/pgrep"

pre_voo() {
  env -i PATH="$T/bin:/usr/bin:/bin" HOME="$T/casa" NO_COLOR=1 LANG=C.UTF-8 MEOW_RAIZ="$RAIZ" \
    bash -c '. "$MEOW_RAIZ/scripts/lib/comum.sh"; . "$MEOW_RAIZ/scripts/lib/preflight.sh"; meow_preflight' 2>&1
}

: > "$T/outro-cosmic"
saida="$(pre_voo)"; rc=$?
if [ "$rc" = "2" ] && [[ "$saida" == *"o COSMIC não está rodando aqui"* ]]; then
  ok "cosmic-comp só de outra conta: o pré-voo recusa"
else
  falha "o pré-voo aceitou o cosmic-comp de outra conta (rc=$rc)" "$saida"
fi
grep -q -- '-u' "$T/pgrep.log" && ok "o pgrep filtra pela própria conta" || falha "o pgrep não usou -u" "$(cat "$T/pgrep.log")"

: > "$T/meu-cosmic"
saida="$(pre_voo)"
[[ "$saida" == *"o cosmic-comp está vivo — seguindo"* ]] && ok "cosmic-comp da própria conta: o pré-voo segue" \
  || falha "o pré-voo recusou o cosmic-comp da própria conta" "$saida"

[ "$falhas" = 0 ] && { echo "preflight-so-da-conta: tudo certo"; exit 0; }
echo "preflight-so-da-conta: $falhas falha(s)"; exit 1

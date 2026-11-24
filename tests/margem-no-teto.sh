#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$1"; }
falha() { printf '  FALHA %s\n' "$1"; falhas=$((falhas + 1)); }

mkdir -p "$T/sistema/com.system76.CosmicPanel.Panel/v1" "$T/sistema/com.system76.CosmicPanel.Dock/v1"
C="$T/home/.config/cosmic"
for b in Panel Dock; do
  d="$C/com.system76.CosmicPanel.$b/v1"; mkdir -p "$d"
  echo '"XS"' > "$d/size"; echo 0 > "$d/padding"; echo 0 > "$d/border_radius"; echo 0 > "$d/margin"
done
forma() {
  env -i PATH="/usr/bin:/bin" HOME="$T/home" NO_COLOR=1 LANG=C.UTF-8 MEOW_RAIZ="$RAIZ" \
    MEOW_COSMIC_SISTEMA="$T/sistema" MEOW_ESTADO="$T/estado" "$@" "$RAIZ/scripts/forma.sh" aplicar 2>&1
}
margem() { tr -d '\n' < "$C/com.system76.CosmicPanel.$1/v1/margin"; }

printf '\na margem acima de 8 derruba o cosmic-panel 1.11: o forma.sh grava o teto\n'
forma FORMA_MARGEM_PAINEL=21 FORMA_MARGEM_DOCK=12 >/dev/null
[ "$(margem Panel)" = 8 ] && ok "painel pedido em 21 fica em 8" || falha "painel ficou em $(margem Panel)"
[ "$(margem Dock)" = 8 ] && ok "dock pedida em 12 fica em 8" || falha "dock ficou em $(margem Dock)"
forma FORMA_MARGEM_PAINEL=5 >/dev/null
[ "$(margem Panel)" = 5 ] && ok "5 cabe e é gravado como veio" || falha "5 virou $(margem Panel)"
forma FORMA_MARGEM_PAINEL=8 >/dev/null
[ "$(margem Panel)" = 8 ] && ok "8 é o próprio teto" || falha "8 virou $(margem Panel)"

printf '\na margem que já está no disco acima do teto também desce\n'
echo 21 > "$C/com.system76.CosmicPanel.Panel/v1/margin"
forma >/dev/null
[ "$(margem Panel)" = 8 ] && ok "21 no disco, sem pedido, desce para 8" || falha "o disco ficou em $(margem Panel)"
antes="$(md5sum < "$C/com.system76.CosmicPanel.Panel/v1/margin")"
forma >/dev/null
[ "$antes" = "$(md5sum < "$C/com.system76.CosmicPanel.Panel/v1/margin")" ] && ok "a segunda passada não escreve" || falha "a segunda passada escreveu"

printf '\na margem acima do teto que mora no meow.conf desce na conf também, e o aviso não volta\n'
CONF="$T/home/.config/meow/meow.conf"; mkdir -p "${CONF%/*}"
printf 'FORMA_MARGEM_PAINEL="20"\nFORMA_MARGEM_DOCK="20"\nOUTRA="fica"\n' > "$CONF"
echo 0 > "$C/com.system76.CosmicPanel.Panel/v1/margin"; echo 0 > "$C/com.system76.CosmicPanel.Dock/v1/margin"
antes="$(md5sum < "$CONF")"
forma MEOW_DRY_RUN=1 FORMA_MARGEM_PAINEL=20 FORMA_MARGEM_DOCK=20 >/dev/null; rc=$?
[ "$rc" = 1 ] && [ "$antes" = "$(md5sum < "$CONF")" ] && ok "o conferir diverge e não toca na conf" || falha "o conferir saiu $rc ou mexeu na conf"
saida="$(forma FORMA_MARGEM_PAINEL=20 FORMA_MARGEM_DOCK=20)"
grep -qx 'FORMA_MARGEM_PAINEL="8"' "$CONF" && grep -qx 'FORMA_MARGEM_DOCK="8"' "$CONF" && grep -qx 'OUTRA="fica"' "$CONF" \
  && ok "a conf passa a dizer 8 nas duas barras, e o resto dela fica" || falha "a conf ficou: $(cat "$CONF")"
[ "$(margem Panel)" = 8 ] && [ "$(margem Dock)" = 8 ] && ok "e a tela fica em 8" || falha "a tela ficou em $(margem Panel)/$(margem Dock)"
saida="$(forma FORMA_MARGEM_PAINEL=8 FORMA_MARGEM_DOCK=8)"; rc=$?
[ "$rc" = 0 ] && ! grep -q 'derruba' <<< "$saida" && grep -q 'margem 8' <<< "$saida" \
  && ok "a passada seguinte sai 0, sem aviso, e diz a margem que está na tela" || falha "rc $rc: $saida"

printf '\na faixa do painel acompanha o teto\n'
grep -qE '^FORMA_MARGEM_PAINEL=.*# 0 a 8 px' "$RAIZ/meow.conf.exemplo" && ok "o exemplo oferece de 0 a 8" || falha "o exemplo ainda oferece outra faixa"

printf '\n'
if [ "$falhas" -eq 0 ]; then printf 'margem-no-teto: tudo verde\n'; exit 0; fi
printf 'margem-no-teto: %s falha(s)\n' "$falhas"; exit 1

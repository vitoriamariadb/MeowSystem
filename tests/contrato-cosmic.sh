#!/usr/bin/env bash
# contrato-cosmic.sh — os escritores seguem o esquema do pacote? (P76)
#
# `docs/pesquisas/2026-10-09-cosmic-vivo.md` §4.4: "um `/usr/share/cosmic` falso
# com `v2` e verificar que todo escritor grava em `v2`". O `/usr/share/cosmic`
# de brinquedo (`MEOW_COSMIC_SISTEMA`) traz `v1` e `v2`; o COSMIC de brinquedo
# do usuário só conhece o `v2`. Depois de cada escritor:
#   - a chave dele está no `v2`;
#   - nenhum `v1` nasceu em namespace nenhum (a pasta morta que o `v1` cravado
#     criava).
# E o pré-voo da instalação: `v1 v2 v3` no tema deixou de passar verde.
# HOME e COSMIC de brinquedo; nada de sudo nem de sessão.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }

for n in com.system76.CosmicComp com.system76.CosmicPanel.Panel com.system76.CosmicPanel.Dock \
         com.system76.CosmicAppletTime com.system76.CosmicTerm com.system76.CosmicBackground; do
  mkdir -p "$T/sistema/$n/v1" "$T/sistema/$n/v2"
done
C="$T/home/.config/cosmic"
for b in Panel Dock; do
  d="$C/com.system76.CosmicPanel.$b/v2"; mkdir -p "$d"
  echo '"M"' > "$d/size"; echo 4 > "$d/padding"; echo 8 > "$d/border_radius"
  echo 0 > "$d/margin"; echo 1.0 > "$d/opacity"; echo true > "$d/anchor_gap"
done

export HOME="$T/home" MEOW_COSMIC_SISTEMA="$T/sistema" MEOW_IGNORA_DESKTOP=1 NO_COLOR=1

echo "== meow_cosmic_v"
v="$(bash -c ". '$RAIZ/lib/comum.sh'; meow_cosmic_v com.system76.CosmicComp")"
[ "$v" = v2 ] && ok "namespace com v1 e v2 no pacote: v2" || falha "veio '$v'"
v="$(bash -c ". '$RAIZ/lib/comum.sh'; meow_cosmic_v com.system76.NaoExiste")"
[ "$v" = v1 ] && ok "namespace que o pacote não traz: v1" || falha "veio '$v'"

echo "== os escritores gravam no v2"
JANELAS_TILING=sim "$RAIZ/scripts/janelas.sh" aplicar >/dev/null 2>&1
[ -f "$C/com.system76.CosmicComp/v2/autotile" ] && ok "janelas.sh: autotile no v2" || falha "janelas.sh não gravou no v2"
RELOGIO_SEGUNDOS=sim "$RAIZ/scripts/relogio.sh" aplicar >/dev/null 2>&1
[ -f "$C/com.system76.CosmicAppletTime/v2/show_seconds" ] && ok "relogio.sh: show_seconds no v2" || falha "relogio.sh não gravou no v2"
"$RAIZ/scripts/terminal.sh" aplicar >/dev/null 2>&1
[ -f "$C/com.system76.CosmicTerm/v2/color_schemes_dark" ] && ok "terminal.sh: esquema de cor no v2" || falha "terminal.sh não gravou no v2"
VIDRO_OPACIDADE_PAINEL=0.8 VIDRO_OPACIDADE_DOCK=0.8 "$RAIZ/scripts/vidro.sh" >/dev/null 2>&1
grep -q '0.8' "$C/com.system76.CosmicPanel.Panel/v2/opacity" && ok "vidro.sh: opacity no v2" || falha "vidro.sh não gravou no v2 ($(cat "$C/com.system76.CosmicPanel.Panel/v2/opacity"))"
FORMA_RAIO_PAINEL=8 FORMA_MARGEM_PAINEL=4 "$RAIZ/scripts/forma.sh" aplicar >/dev/null 2>&1
[ -f "$C/com.system76.CosmicPanel.Panel/v2/expand_to_edges" ] && ok "forma.sh: expand_to_edges no v2" || falha "forma.sh não gravou no v2"

mortas="$(find "$C" -mindepth 2 -maxdepth 2 -type d -name v1 | sed "s|$C/||")"
[ -z "$mortas" ] && ok "nenhuma pasta v1 nasceu" || falha "pasta v1 nasceu: $mortas"

echo "== o pré-voo da instalação: a lista inteira, contra o contrato"
preflight_esquema() { # $@ = os v* do tema no COSMIC de brinquedo
  local d="$T/pf-$$-$RANDOM/.config/cosmic/com.system76.CosmicTheme.Dark" x
  for x in "$@"; do mkdir -p "$d/$x"; done
  HOME="${d%/.config/*}" bash -c "MEOW_RAIZ='$RAIZ'; . '$RAIZ/lib/comum.sh'; . '$RAIZ/lib/preflight.sh'; meow_preflight" 2>&1 | grep 'esquema de tema'
}
# Saída numa variável antes do `grep -q`: com `pipefail`, o `grep -q` que
# acha e sai cedo devolve SIGPIPE a quem escreve, e o pipe inteiro "falha".
s="$(preflight_esquema v1 v2)";    [[ "$s" == *'cobrem v1 v2'* ]]   && ok "v1 v2: verde" || falha "v1 v2 não saiu verde: $s"
s="$(preflight_esquema v1)";       [[ "$s" == *'anterior ao v2'* ]] && ok "v1: conhecido" || falha "v1 não saiu conhecido: $s"
s="$(preflight_esquema v1 v2 v3)"; [[ "$s" == *desconhecido* ]]     && ok "v1 v2 v3: aviso (o furo fechou)" || falha "v1 v2 v3 ainda passa: $s"
s="$(preflight_esquema v2 v3)";    [[ "$s" == *desconhecido* ]]     && ok "v2 v3: aviso" || falha "v2 v3 ainda passa: $s"

echo
if [ "$falhas" = 0 ]; then echo "contrato-cosmic: tudo certo"; exit 0; fi
echo "contrato-cosmic: $falhas falha(s)"; exit 1

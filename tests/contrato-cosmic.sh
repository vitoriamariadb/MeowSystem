#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }

for n in com.system76.CosmicComp com.system76.CosmicPanel.Panel com.system76.CosmicPanel.Dock \
         com.system76.CosmicAppletTime com.system76.CosmicTerm com.system76.CosmicBackground \
         com.system76.CosmicTheme.Dark; do
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

mkdir -p "$T/bin"
printf '#!/bin/sh\nprintf "eDP-1 (enabled)\\n  Xwayland primary: true\\n"\n' > "$T/bin/cosmic-randr"
chmod 755 "$T/bin/cosmic-randr"
AREAS_NOMES="Uma" PATH="$T/bin:$PATH" "$RAIZ/scripts/areas.sh" alfinetar-primeira >/dev/null 2>&1
[ -f "$C/com.system76.CosmicComp/v2/pinned_workspaces" ] && ok "areas.sh: pinned_workspaces no v2" \
  || falha "areas.sh não gravou no v2"
WP="$HOME/.local/share/backgrounds/meowsystem/ativos"; mkdir -p "$WP"
python3 -I - "$WP" <<'PY'
import struct, sys, zlib
def png(cam, cor):
    linha = b"\x00" + bytes(cor) * 8
    corpo = zlib.compress(linha * 8)
    def bloco(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    with open(cam, "wb") as fh:
        fh.write(b"\x89PNG\r\n\x1a\n" + bloco(b"IHDR", struct.pack(">IIBBBBB", 8, 8, 8, 2, 0, 0, 0))
                 + bloco(b"IDAT", corpo) + bloco(b"IEND", b""))
png(sys.argv[1] + "/a.png", (0, 0, 0)); png(sys.argv[1] + "/b.png", (255, 255, 255))
PY
"$RAIZ/scripts/wallpaper.sh" aplicar >/dev/null 2>&1
[ -n "$(ls -A "$C/com.system76.CosmicBackground/v2" 2>/dev/null)" ] && ok "wallpaper.sh: a configuração do cosmic-bg no v2" \
  || falha "wallpaper.sh não gravou no v2"
eval "$(sed -n '/^e_produto() {/,/^}/p' "$RAIZ/scripts/aplicar_tema.sh")"
if e_produto com.system76.CosmicTheme.Dark/v2/accent && ! e_produto com.system76.CosmicTheme.Dark/v1/accent; then
  ok "aplicar_tema.sh: a árvore de produto é a do esquema novo, e a v1 legada fica de fora"
else
  falha "a fronteira do aplicar_tema.sh não separa a v2 (produto) da v1 (legada)"
fi
mkdir -p "$C/com.system76.CosmicTheme.Dark/v1" "$C/com.system76.CosmicTheme.Dark/v2"
echo 24 > "$C/com.system76.CosmicTheme.Dark/v1/gaps"; echo 8 > "$C/com.system76.CosmicTheme.Dark/v2/gaps"
g="$("$RAIZ/scripts/janelas.sh" estado 2>&1 | grep 'gaps (do TEMA)')"
[[ "$g" == *" 8 "* ]] && ok "janelas.sh estado: o gaps é o do v2" || falha "janelas.sh estado mostrou outro gaps: $g"

mortas="$(find "$C" -mindepth 2 -maxdepth 2 -type d -name v1 | grep -v 'CosmicTheme.Dark/v1' | sed "s|$C/||")"
[ -z "$mortas" ] && ok "nenhuma pasta v1 nasceu" || falha "pasta v1 nasceu: $mortas"

echo "== o pré-voo da instalação: a lista inteira, contra o contrato"
preflight_esquema() {
  local d="$T/pf-$$-$RANDOM/.config/cosmic/com.system76.CosmicTheme.Dark" x
  for x in "$@"; do mkdir -p "$d/$x"; done
  HOME="${d%/.config/*}" bash -c "MEOW_RAIZ='$RAIZ'; . '$RAIZ/lib/comum.sh'; . '$RAIZ/lib/preflight.sh'; meow_preflight" 2>&1 | grep 'esquema de tema'
}
s="$(preflight_esquema v1 v2)";    [[ "$s" == *'cobrem v1 v2'* ]]   && ok "v1 v2: verde" || falha "v1 v2 não saiu verde: $s"
s="$(preflight_esquema v1)";       [[ "$s" == *'anterior ao v2'* ]] && ok "v1: conhecido" || falha "v1 não saiu conhecido: $s"
s="$(preflight_esquema v1 v2 v3)"; [[ "$s" == *desconhecido* ]]     && ok "v1 v2 v3: aviso (o furo fechou)" || falha "v1 v2 v3 ainda passa: $s"
s="$(preflight_esquema v2 v3)";    [[ "$s" == *desconhecido* ]]     && ok "v2 v3: aviso" || falha "v2 v3 ainda passa: $s"

echo
if [ "$falhas" = 0 ]; then echo "contrato-cosmic: tudo certo"; exit 0; fi
echo "contrato-cosmic: $falhas falha(s)"; exit 1

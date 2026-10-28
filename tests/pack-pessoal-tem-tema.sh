#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
for b in sudo pkexec su pkill curl wget notify-send systemctl gsettings dconf busctl cosmic-bg; do
  printf '#!/bin/sh\nexit 1\n' > "$FALSO/$b"; chmod 755 "$FALSO/$b"
done
CASA="$T/casa"; COSMIC="$T/cosmic"; ESTADO="$T/estado"
CONF="$CASA/.config/meow/meow.conf"
mkdir -p "$(dirname "$CONF")" "$COSMIC" "$ESTADO"

amb() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" MEOW_RAIZ="$RAIZ" MEOW_CONF="$CONF" \
    MEOW_ESTADO="$ESTADO" MEOW_COSMIC_DIR="$COSMIC" MEOW_PONTE=/caminho/inexistente \
    LANG=C.UTF-8 NO_COLOR=1 "$@"
}

python3 - "$T/meu-tema.csv" "$RAIZ/packs/dracula/paleta.json" <<'PY'
import json, sys
p = json.load(open(sys.argv[2], encoding="utf-8"))
ordem = p.get("ordem_canonica") or list(next(iter(p["flavors"].values())))
cores = p["flavors"]["dracula"]
with open(sys.argv[1], "w", encoding="utf-8") as fh:
    fh.write("slot,flavor,hex\n" + "".join(f"{n},meutema,{cores[n]}\n" for n in ordem))
PY
s="$(amb python3 "$RAIZ/scripts/pack.py" importar "$T/meu-tema.csv" 2>&1)" \
  || { falha "o CSV não virou pack pelo caminho do Personalizar" "$s"; exit 1; }
DIR="$CASA/.local/share/meowsystem/packs/meu-tema"
FLAVOR="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["paleta"]["flavor_padrao"])' "$DIR/pack.json")"
CLARO="$(python3 -c 'import json,sys; print(" ".join(json.load(open(sys.argv[1])).get("claros") or []))' "$DIR/paleta.json")"
[ "$FLAVOR" = "meutema" ] && [ "$CLARO" = "meutemaclaro" ] \
  && ok "o pack meu-tema nasce com o escuro meutema e o claro meutemaclaro, como o da máquina dela" \
  || falha "o pack do CSV não tem o par escuro e claro" "flavor=$FLAVOR claros=$CLARO"
[ ! -d "$DIR/temas/capturados" ] \
  && ok "o pack pessoal nasce sem captura própria (o tema vem do pack de onde nasceu)" \
  || falha "o pack pessoal já nasceu com captura: o teste não prova a derivação" "$(ls "$DIR/temas/capturados")"

printf 'FLAVOR="%s"\nACCENT="mauve"\nMODO="escuro"\nPACK="meu-tema"\nLOGO="coquinha"\n' "$FLAVOR" > "$CONF"

ETAPAS="$T/etapas.sh"
{ sed -n '/^etapa_gerar() {$/,/^}$/p' "$RAIZ/install.sh"
  sed -n '/^etapa_tema() {$/,/^}$/p' "$RAIZ/install.sh"; } > "$ETAPAS"
grep -q '^etapa_tema() {' "$ETAPAS" || { printf 'erro: não achei etapa_tema no install.sh\n' >&2; exit 2; }
etapa() {
  amb bash -c '
    . "$MEOW_RAIZ/lib/comum.sh" >/dev/null 2>&1
    set -a; . "$MEOW_CONF"; set +a
    meow_ponte_python >/dev/null 2>&1 || exit 9
    meow_notificar() { :; }
    passo() { :; }
    . "$1"
    "etapa_$2"' _ "$ETAPAS" "$1" 2>&1
  printf '%s' "$?" > "$T/rc"
}

etapa gerar >/dev/null
saida="$(etapa tema)"; rc="$(cat "$T/rc")"
nome_dark="$(cat "$COSMIC/com.system76.CosmicTheme.Dark/v2/name" 2>/dev/null)"
nome_light="$(cat "$COSMIC/com.system76.CosmicTheme.Light/v2/name" 2>/dev/null)"
[ "$rc" = "1" ] && [ "$nome_dark" = '"meu-tema-meutema"' ] && [ "$nome_light" = '"meu-tema-meutemaclaro"' ] \
  && ok "a etapa tema aplica o pack pessoal: o escuro é o meu-tema-meutema e o claro, o meu-tema-meutemaclaro" \
  || falha "o pack pessoal ficou sem tema do COSMIC (rc=$rc)" "Dark: $nome_dark / Light: $nome_light
$saida"

acento_claro="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["flavors"]["meutemaclaro"]["mauve"].upper())' "$DIR/paleta.json")"
grep -qi "${acento_claro#\#}" "$COSMIC/com.system76.CosmicTheme.Light.Builder/v2/accent" 2>/dev/null \
  && ok "o acento do claro é o mauve do meutemaclaro ($acento_claro)" \
  || falha "o acento do claro não é o do meutemaclaro" "$(cat "$COSMIC/com.system76.CosmicTheme.Light.Builder/v2/accent" 2>&1)"

[ -d "$DIR/temas/capturados/meutema-mauve" ] \
  && grep -q '^origem: derivada de ' "$DIR/temas/capturados/meutema-mauve/captura.txt" \
  && ok "a captura derivada mora no pack pessoal ($(sed -n 's/^origem: //p' "$DIR/temas/capturados/meutema-mauve/captura.txt"))" \
  || falha "a captura derivada não foi para o pack pessoal" "$(ls -R "$DIR/temas" 2>&1 | head)"

if grep -q '^tema-sem-captura	' "$ESTADO/pendencias.tsv" 2>/dev/null; then
  falha "ficou a pendência tema-sem-captura" "$(cat "$ESTADO/pendencias.tsv")"
else
  ok "nenhuma pendência tema-sem-captura"
fi

antes="$(find "$COSMIC" "$DIR" -type f -printf '%P %T@\n' | sort | sha256sum)"
saida2="$(etapa tema)"; rc2="$(cat "$T/rc")"
depois="$(find "$COSMIC" "$DIR" -type f -printf '%P %T@\n' | sort | sha256sum)"
[ "$rc2" = "0" ] && [ "$antes" = "$depois" ] \
  && ok "a segunda passada da etapa tema não escreve nada" \
  || falha "a segunda passada da etapa tema escreveu (rc=$rc2)" "$saida2"

rm -rf "$COSMIC" "$DIR/temas"; mkdir -p "$COSMIC"; : > "$ESTADO/pendencias.tsv"
printf 'FLAVOR="%s"\nACCENT="mauve"\nMODO="claro"\nPACK="meu-tema"\nLOGO="coquinha"\n' "$CLARO" > "$CONF"
saida3="$(etapa tema)"; rc3="$(cat "$T/rc")"
[ "$rc3" = "1" ] && [ "$(cat "$COSMIC/com.system76.CosmicTheme.Light/v2/name" 2>/dev/null)" = '"meu-tema-meutemaclaro"' ] \
  && [ "$(cat "$COSMIC/com.system76.CosmicTheme.Dark/v2/name" 2>/dev/null)" = '"meu-tema-meutema"' ] \
  && ! grep -q '^tema-sem-captura	' "$ESTADO/pendencias.tsv" 2>/dev/null \
  && ok "com o claro do pack no FLAVOR, o tema também se aplica, com o escuro do par" \
  || falha "com o claro do pack no FLAVOR, o tema não se aplicou (rc=$rc3)" "$saida3"

[ "$falhas" -eq 0 ] || { printf '\n%d falha(s)\n' "$falhas" >&2; exit 1; }
printf '\ntudo certo\n'

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
moldes_do_base="$(cd "$RAIZ/packs/meowsystem" && find temas-de-apps -name '*.modelo.*' -type f | sort)"
moldes_iguais() {
  local m
  [ "$(printf '%s\n' "$moldes_do_base" | wc -l)" = 14 ] || return 1
  while IFS= read -r m; do cmp -s "$RAIZ/packs/meowsystem/$m" "$1/$m" || return 1; done <<< "$moldes_do_base"
}
moldes_iguais "$DIR" && moldes_iguais "$RAIZ/packs/dracula" \
  && ok "o pack que nasce do Personalizar traz os 14 moldes de tema de aplicativo, os mesmos do pack-base e do Dracula" \
  || falha "o pack pessoal ou o Dracula não trazem os 14 moldes do pack-base" "$(cd "$DIR" && find temas-de-apps -type f 2>&1 | sort)"
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
    . "$MEOW_RAIZ/scripts/lib/comum.sh" >/dev/null 2>&1
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

amb env MEOW_PACKS="$T/novos" python3 "$RAIZ/scripts/pack.py" novo do-meow-novo >/dev/null 2>&1
moldes_iguais "$T/novos/do-meow-novo" \
  && ok "o meow pack novo também semeia os 14 moldes no pack que nasce" \
  || falha "o meow pack novo nasceu sem os moldes" "$(find "$T/novos" -name '*.modelo.*' 2>&1)"

VELHO="$CASA/.local/share/meowsystem/packs/meu-meow-portatil"
cp -a "$DIR" "$VELHO"
sed -i 's/"id": "meu-tema"/"id": "meu-meow-portatil"/' "$VELHO/pack.json"
rm -rf "$VELHO/temas-de-apps"
mkdir -p "$VELHO/temas-de-apps/kitty"
printf '# o kitty dela, mexido à mão\nforeground {{text}}\n' > "$VELHO/temas-de-apps/kitty/kitty.modelo.conf"
retrato_moldes() { find "$CASA/.local/share/meowsystem/packs" -path '*temas-de-apps*' -type f -printf '%P %s %T@\n' | sort; }
antes="$(retrato_moldes)"
conferir="$(amb python3 "$RAIZ/scripts/pack.py" semear-moldes --conferir 2>&1)"
[ "$antes" = "$(retrato_moldes)" ] && grep -q 'meu-meow-portatil ganharia 13 molde' <<< "$conferir" \
  && ! grep -q 'meu-tema' <<< "$conferir" \
  && ok "o --conferir conta os 13 moldes que faltam no pack pessoal de antes e não escreve" \
  || falha "o semear-moldes --conferir escreveu ou contou errado" "$conferir"
semeou="$(amb python3 "$RAIZ/scripts/pack.py" semear-moldes 2>&1)"
mexido="$(cat "$VELHO/temas-de-apps/kitty/kitty.modelo.conf")"
faltam="$(cd "$RAIZ/packs/meowsystem" && while IFS= read -r m; do [ -f "$VELHO/$m" ] || printf '%s\n' "$m"; done <<< "$moldes_do_base")"
[ -z "$faltam" ] && [ "$mexido" = "$(printf '# o kitty dela, mexido à mão\nforeground {{text}}')" ] \
  && grep -q 'meu-meow-portatil ganhou 13 molde' <<< "$semeou" \
  && ok "a passada do install dá ao pack pessoal de antes os moldes que faltam, sem tocar no que ela mexeu" \
  || falha "o semear-moldes não completou o pack pessoal, ou trocou o molde dela" "$semeou / faltam: $faltam"
antes="$(retrato_moldes)"
segunda="$(amb python3 "$RAIZ/scripts/pack.py" semear-moldes 2>&1)"
[ -z "$segunda" ] && [ "$antes" = "$(retrato_moldes)" ] && [ -z "$(amb python3 "$RAIZ/scripts/pack.py" semear-moldes --conferir 2>&1)" ] \
  && ok "a segunda passada do semear-moldes não escreve nada" \
  || falha "a segunda passada do semear-moldes escreveu" "$segunda"
TRAVADO="$CASA/.local/share/meowsystem/packs/meu-travado"
cp -a "$DIR" "$TRAVADO"
sed -i 's/"id": "meu-tema"/"id": "meu-travado"/' "$TRAVADO/pack.json"
rm -rf "$TRAVADO/temas-de-apps"
chmod 555 "$TRAVADO"
travado="$(amb python3 "$RAIZ/scripts/pack.py" semear-moldes 2>&1)"; rc_travado=$?
chmod 755 "$TRAVADO"
{ [ "$rc_travado" != 0 ] && [ ! -e "$TRAVADO/temas-de-apps" ] && [[ $travado == *"não consegui escrever no pack meu-travado"* ]] \
  && [[ $travado != *Traceback* ]]; } \
  && ok "no pack pessoal só-leitura a semeadura diz que não conseguiu, sem rastro de Python, e não escreve nada" \
  || falha "pack só-leitura: rc=$rc_travado" "$travado"
grep -q 'semear-moldes 2>/dev/null)"' "$RAIZ/install.sh" && grep -q 'rc_moldes' "$RAIZ/install.sh" \
  && ok "o install não mostra como feito o erro da semeadura: só a saída boa vira linha de ok, e o código de saída vira aviso" \
  || falha "o install mistura o erro da semeadura com a linha de ok"
rm -rf "$TRAVADO"
de_quem="$(amb FLAVOR="$FLAVOR" python3 "$RAIZ/scripts/pack.py" app meu-meow-portatil apps.kitty.arquivo 2>&1)"
aviso_kitty="$(amb python3 "$RAIZ/scripts/pack.py" validar meu-meow-portatil 2>&1)"; rc_kitty=$?
de_semeado="$(amb FLAVOR="$FLAVOR" python3 "$RAIZ/scripts/pack.py" app meu-meow-portatil apps.telegram.arquivo 2>&1)"
grep -qxF "valor=$RAIZ/packs/meowsystem/temas-de-apps/kitty/kitty.modelo.conf" <<< "$de_quem" && grep -qx 'pack=meu-meow-portatil' <<< "$de_quem" \
  && grep -qxF "valor=$RAIZ/packs/meowsystem/temas-de-apps/telegram/telegram.modelo.tdesktop-theme" <<< "$de_semeado" \
  && [ "$rc_kitty" = 0 ] && grep -q 'aviso apps.kitty:' <<< "$aviso_kitty" && ! grep -q 'aviso apps.telegram:' <<< "$aviso_kitty" \
  && grep -q 'pack.py" semear-moldes' "$RAIZ/install.sh" \
  && ok "o molde do kitty mexido à mão não é lido (vale o do pack-base, nas cores do pack, e o validar avisa), o semeado igual vale sem aviso, e o install chama a semeadura" \
  || falha "o molde mexido de pack pessoal foi lido, ou o validar não avisou, ou o install não semeia" "$de_quem / $de_semeado / rc=$rc_kitty $aviso_kitty"

[ "$falhas" -eq 0 ] || { printf '\n%d falha(s)\n' "$falhas" >&2; exit 1; }
printf '\ntudo certo\n'

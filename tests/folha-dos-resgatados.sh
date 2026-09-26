#!/usr/bin/env bash
# folha-dos-resgatados.sh — `meow icones resgatados folha` não perde o que a folha tem.
#
# POR QUE ESTE ARQUIVO NASCEU EM 25/09/2026 (sprint P68, item 4)
#   A folha `assets/icones/resgatados/ANTES-E-DEPOIS.png` sai do
#   `scripts/resgatados_folha.sh`, que pede o PNG de origem de cada par no
#   caminho do mapa. Em 25/09 doze dos 21 não estavam mais no disco, e a P67
#   costurou a folha à mão: a esquerda desses doze veio da folha de 12/09. O
#   comando, rodado de novo, trocava essa folha por uma com doze molduras
#   «sem o PNG» (181952 pixels diferentes, medido), e a trava da P67 diria
#   «refeita nesta árvore». A costura passou a ser do script, e é ela que este
#   teste prende, num acervo de brinquedo com três pares:
#     1. com os três PNG, a folha nasce;
#     2. sem dois deles, a folha refeita é a mesma, pixel a pixel, e o arquivo
#        não é regravado;
#     3. com o desenho de um par sem PNG trocado, a direita dele muda e a
#        esquerda fica a da folha de antes: a folha é a que o script monta com
#        os PNG no disco;
#     4. com a folha mudando de forma (o mapa em outra ordem) e PNG faltando,
#        o script sai 3 sem escrever, e diz quais pares;
#     5. sem folha nenhuma no caminho, a moldura vazia continua valendo — não
#        há o que perder.
#
# NADA FORA DO TEMPORÁRIO: o script e o lib/ são copiados para uma raiz de
#   brinquedo, e o acervo, o mapa e os PNG são dela. O repositório é conferido
#   no fim.
#
#   0 = passou · 1 = achados · 2 = erro deste teste · pulado sem as ferramentas
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

for b in rsvg-convert convert montage compare identify; do
  command -v "$b" >/dev/null 2>&1 || { printf 'pulado: sem %s (librsvg2-bin e imagemagick)\n' "$b"; exit 0; }
done

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
git_antes="$(git -C "$RAIZ" status --porcelain 2>/dev/null)"

# Uma raiz de brinquedo por cenário: o script acha o acervo e o mapa pela raiz
# dele, e não por variável.
raiz() {   # raiz <dir> — o script, o lib/ e um acervo com os SVG de três pares
  mkdir -p "$1/scripts" "$1/assets/icones/resgatados"
  cp "$RAIZ/scripts/resgatados_folha.sh" "$1/scripts/"
  cp -a "$RAIZ/lib" "$1/"
  for n in luna sigilo discord; do
    cp "$RAIZ/assets/icones/resgatados/$n.svg" "$1/assets/icones/resgatados/" || exit 2
  done
}
mapa() {   # mapa <dir> <nome>... — o mapa com os pares nesta ordem, PNG em $T/png
  local d="$1"; shift
  { printf '# mapa de brinquedo\n'
    for n in "$@"; do printf '%s : %s/png/%s.png : dela\n' "$n" "$T" "$n"; done
  } > "$d/assets/icones/apps-resgatados.map"
}
png() {   # png <nome> <cor> — o PNG de origem de brinquedo
  convert -size 64x64 "xc:$2" -fill white -draw 'circle 32,32 32,12' "$T/png/$1.png" || exit 2
}
folha() {   # folha <dir> <saída> — roda o script; a tela fica em $T/tela, o código em $T/rc
  env -i PATH="$PATH" HOME="$T/casa" LANG=C.UTF-8 NO_COLOR=1 \
    bash "$1/scripts/resgatados_folha.sh" "$2" > "$T/tela" 2>&1
  printf '%s' "$?" > "$T/rc"
}
rc() { cat "$T/rc"; }
iguais() {   # iguais <a> <b> — o mesmo tamanho e os mesmos pixels
  [ "$(compare -metric AE "$1" "$2" null: 2>&1)" = "0" ]
}

mkdir -p "$T/png" "$T/casa"
png luna "#FF5555"; png sigilo "#50FA7B"; png discord "#8BE9FD"
R="$T/raiz"; raiz "$R"; mapa "$R" luna sigilo discord
F="$T/folha.png"

# --- 1. com os três PNG, a folha nasce --------------------------------------
folha "$R" "$F"
[ "$(rc)" = "0" ] && [ -f "$F" ] \
  && ok "com os três PNG no disco, a folha nasce" \
  || { falha "a folha de brinquedo não nasceu (rc=$(rc))" "$(cat "$T/tela")"; exit 2; }
cp "$F" "$T/completa.png"

# --- 2. sem dois PNG, a folha continua a mesma ------------------------------
mkdir -p "$T/png-fora"; mv "$T/png/luna.png" "$T/png/discord.png" "$T/png-fora/"
folha "$R" "$F"
if [ "$(rc)" = "0" ] && cmp -s "$F" "$T/completa.png" && grep -q 'a folha já é esta' "$T/tela"; then
  ok "sem o PNG de dois pares, a folha refeita é a mesma, pixel a pixel, e não é regravada"
else
  falha "sem o PNG de dois pares, a folha perdeu a esquerda deles (rc=$(rc); $(compare -metric AE "$F" "$T/completa.png" null: 2>&1) pixels diferentes)" \
        "$(cat "$T/tela")"
  cp "$T/completa.png" "$F"
fi

# --- 3. o desenho de um par sem PNG muda: a direita anda, a esquerda fica ---
cp "$RAIZ/assets/icones/resgatados/extase-em-4r73.svg" "$R/assets/icones/resgatados/luna.svg"
folha "$R" "$F"
#   A régua: a folha que o script monta com os PNG no disco e o desenho novo.
R2="$T/raiz2"; raiz "$R2"; mapa "$R2" luna sigilo discord
cp "$R/assets/icones/resgatados/luna.svg" "$R2/assets/icones/resgatados/"
cp "$T/png-fora/"*.png "$T/png/"
folha "$R2" "$T/regua.png"
mv "$T/png/luna.png" "$T/png/discord.png" "$T/png-fora/"
if ! iguais "$T/completa.png" "$F" && iguais "$F" "$T/regua.png"; then
  ok "com o desenho de um par sem PNG trocado, a direita dele muda e a esquerda fica a da folha de antes"
else
  falha "a folha com o desenho novo não é a que os PNG dariam ($(compare -metric AE "$F" "$T/regua.png" null: 2>&1) pixels diferentes da régua)" \
        "$(cat "$T/tela")"
fi

# --- 4. a folha muda de forma com PNG faltando: não escreve, e diz ----------
cp "$F" "$T/antes-da-ordem.png"
mapa "$R" discord sigilo luna
folha "$R" "$F"
[ "$(rc)" = "3" ] && cmp -s "$F" "$T/antes-da-ordem.png" \
  && grep -q 'a folha fica a de antes' "$T/tela" && grep -q 'discord' "$T/tela" && grep -q 'luna' "$T/tela" \
  && ok "com o mapa em outra ordem e PNG faltando, o script sai 3, não escreve, e diz quais pares" \
  || falha "o script refez uma folha que ele não sabia costurar (rc=$(rc))" "$(cat "$T/tela")"
mapa "$R" luna sigilo discord

# --- 5. sem folha no caminho, a moldura vazia vale --------------------------
folha "$R" "$T/nova.png"
[ "$(rc)" = "0" ] && [ -f "$T/nova.png" ] && ! iguais "$T/nova.png" "$T/regua.png" \
  && grep -q '2 sem o PNG de origem (o caminho' "$T/tela" \
  && ok "sem folha no caminho, a folha nasce com a moldura vazia dos dois pares sem PNG" \
  || falha "sem folha no caminho, o script não fez a folha com as molduras vazias (rc=$(rc))" "$(cat "$T/tela")"

# --- 6. o repositório não mudou ---------------------------------------------
[ "$(git -C "$RAIZ" status --porcelain 2>/dev/null)" = "$git_antes" ] \
  && ok "o repositório saiu como entrou" \
  || falha "o teste mexeu no repositório" "$(git -C "$RAIZ" status --porcelain)"

printf '\n'
[ "$falhas" = "0" ] && { printf 'folha-dos-resgatados: tudo certo\n'; exit 0; }
printf 'folha-dos-resgatados: %d achado(s)\n' "$falhas"
exit 1

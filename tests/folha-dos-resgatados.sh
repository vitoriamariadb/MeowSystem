#!/usr/bin/env bash
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

raiz() {
  mkdir -p "$1/scripts" "$1/packs/dracula/icones/apps/resgatados"
  cp "$RAIZ/scripts/resgatados_folha.sh" "$1/scripts/"
  cp -a "$RAIZ/lib" "$1/"
  for n in luna sigilo pdfforge; do
    cp "$RAIZ/packs/dracula/icones/apps/$n.svg" "$1/packs/dracula/icones/apps/" || exit 2
  done
}
mapa() {
  local d="$1"; shift
  { printf '# mapa de brinquedo\n'
    for n in "$@"; do printf '%s : %s/png/%s.png : dela\n' "$n" "$T" "$n"; done
  } > "$d/packs/dracula/icones/apps-resgatados.map"
}
png() {
  convert -size 64x64 "xc:$2" -fill white -draw 'circle 32,32 32,12' "$T/png/$1.png" || exit 2
}
folha() {
  env -i PATH="$PATH" HOME="$T/casa" LANG=C.UTF-8 NO_COLOR=1 \
    bash "$1/scripts/resgatados_folha.sh" "$2" > "$T/tela" 2>&1
  printf '%s' "$?" > "$T/rc"
}
rc() { cat "$T/rc"; }
iguais() {
  [ "$(compare -metric AE "$1" "$2" null: 2>&1)" = "0" ]
}

mkdir -p "$T/png" "$T/casa"
png luna "#FF5555"; png sigilo "#50FA7B"; png pdfforge "#8BE9FD"
R="$T/raiz"; raiz "$R"; mapa "$R" luna sigilo pdfforge
F="$T/folha.png"

folha "$R" "$F"
[ "$(rc)" = "0" ] && [ -f "$F" ] \
  && ok "com os três PNG no disco, a folha nasce" \
  || { falha "a folha de brinquedo não nasceu (rc=$(rc))" "$(cat "$T/tela")"; exit 2; }
cp "$F" "$T/completa.png"

mkdir -p "$T/png-fora"; mv "$T/png/luna.png" "$T/png/pdfforge.png" "$T/png-fora/"
folha "$R" "$F"
if [ "$(rc)" = "0" ] && cmp -s "$F" "$T/completa.png" && grep -q 'a folha já é esta' "$T/tela"; then
  ok "sem o PNG de dois pares, a folha refeita é a mesma, pixel a pixel, e não é regravada"
else
  falha "sem o PNG de dois pares, a folha perdeu a esquerda deles (rc=$(rc); $(compare -metric AE "$F" "$T/completa.png" null: 2>&1) pixels diferentes)" \
        "$(cat "$T/tela")"
  cp "$T/completa.png" "$F"
fi

cp "$RAIZ/packs/dracula/icones/apps/extase-em-4r73.svg" "$R/packs/dracula/icones/apps/luna.svg"
folha "$R" "$F"
R2="$T/raiz2"; raiz "$R2"; mapa "$R2" luna sigilo pdfforge
cp "$R/packs/dracula/icones/apps/luna.svg" "$R2/packs/dracula/icones/apps/"
cp "$T/png-fora/"*.png "$T/png/"
folha "$R2" "$T/regua.png"
mv "$T/png/luna.png" "$T/png/pdfforge.png" "$T/png-fora/"
if ! iguais "$T/completa.png" "$F" && iguais "$F" "$T/regua.png"; then
  ok "com o desenho de um par sem PNG trocado, a direita dele muda e a esquerda fica a da folha de antes"
else
  falha "a folha com o desenho novo não é a que os PNG dariam ($(compare -metric AE "$F" "$T/regua.png" null: 2>&1) pixels diferentes da régua)" \
        "$(cat "$T/tela")"
fi

cp "$F" "$T/antes-da-ordem.png"
mapa "$R" pdfforge sigilo luna
folha "$R" "$F"
[ "$(rc)" = "3" ] && cmp -s "$F" "$T/antes-da-ordem.png" \
  && grep -q 'a folha fica a de antes' "$T/tela" && grep -q 'pdfforge' "$T/tela" && grep -q 'luna' "$T/tela" \
  && ok "com o mapa em outra ordem e PNG faltando, o script sai 3, não escreve, e diz quais pares" \
  || falha "o script refez uma folha que ele não sabia costurar (rc=$(rc))" "$(cat "$T/tela")"
mapa "$R" luna sigilo pdfforge

folha "$R" "$T/nova.png"
[ "$(rc)" = "0" ] && [ -f "$T/nova.png" ] && ! iguais "$T/nova.png" "$T/regua.png" \
  && grep -q '2 sem o PNG de origem (o caminho' "$T/tela" \
  && ok "sem folha no caminho, a folha nasce com a moldura vazia dos dois pares sem PNG" \
  || falha "sem folha no caminho, o script não fez a folha com as molduras vazias (rc=$(rc))" "$(cat "$T/tela")"

[ "$(git -C "$RAIZ" status --porcelain 2>/dev/null)" = "$git_antes" ] \
  && ok "o repositório saiu como entrou" \
  || falha "o teste mexeu no repositório" "$(git -C "$RAIZ" status --porcelain)"

printf '\n'
[ "$falhas" = "0" ] && { printf 'folha-dos-resgatados: tudo certo\n'; exit 0; }
printf 'folha-dos-resgatados: %d achado(s)\n' "$falhas"
exit 1

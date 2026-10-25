#!/usr/bin/env bash
# perfil.sh — `./install.sh --perfil <nome>` copia `perfis/<nome>/` para
# `~/.config/meow/` antes da fila, guarda o que havia, e sem a flag nada muda
# (P102: um PC virgem recebe as escolhas de quem usa a partir do clone).
#
# HOME, estado e raiz de brinquedo; `curl`, `sudo` e `pkill` falsos que recusam.
# Nada sai do `mktemp -d`.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas + 1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
for b in sudo pkexec pkill; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/perfil.sh\\n" >&2\nexit 1\n' "$b" > "$FALSO/$b"
  chmod 755 "$FALSO/$b"
done
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/rede.log"\nexit 7\n' "$T" > "$FALSO/curl"
chmod 755 "$FALSO/curl"

# --- install.sh --perfil <nome> --------------------------------------------
# A raiz de brinquedo de tests/instalacao.sh: links para o repositório, uma
# cópia do install.sh com a fila trocada por uma etapa que só diz o PACK, e uma
# pasta `perfis/` própria (a do repositório, se houver, não entra).
R="$T/raiz"; mkdir -p "$R/perfis/teste"
for i in "$RAIZ"/*; do
  case "$(basename "$i")" in install.sh|perfis) continue ;; esac
  ln -s "$i" "$R/"
done
awk '
  /local etapas=\(/ && !trocou { print "  local etapas=(etapa_diz_pack)"; trocou=1; pulando=1 }
  pulando { if ($0 ~ /\)[ \t]*$/) pulando=0; next }
  /^main "\$@"$/ { print "etapa_diz_pack() { passo \"diz o pack\"; printf \"pack-no-ar=%s\\n\" \"${PACK:-}\"; return 0; }" }
  { print }
' "$RAIZ/install.sh" > "$R/install.sh"
chmod +x "$R/install.sh"
sed -e 's/^PACK=.*/PACK="dracula"/' -e 's/^FLAVOR=.*/FLAVOR="dracula"/' "$RAIZ/meow.conf.exemplo" > "$R/perfis/teste/meow.conf"
printf 'firefox : packs/dracula/icones/apps/firefox.svg\n' > "$R/perfis/teste/icones-escolhidos.map"

CASA="$T/casa-perfil"
instalar() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_IGNORA_DESKTOP=1 MEOW_PONTE=/nao/existe MEOW_ESTADO="$T/estado-perfil" \
    bash "$R/install.sh" --uma-passagem "$@" 2>&1
}
CF="$CASA/.config/meow"

mkdir -p "$CASA"
s="$(instalar --perfil teste)"; rc=$?
if [ "$rc" != 2 ] && cmp -s "$R/perfis/teste/meow.conf" "$CF/meow.conf" \
   && cmp -s "$R/perfis/teste/icones-escolhidos.map" "$CF/icones-escolhidos.map" \
   && [[ "$s" == *"pack-no-ar=dracula"* ]]; then
  ok "numa casa sem meow.conf, --perfil teste põe o conf e o mapa do perfil, e a fila já lê o pack dele"
else
  falha "o --perfil não pôs o perfil na casa vazia (rc=$rc)" "$(tail -8 <<< "$s")"
fi

sed -e 's/^PACK=.*/PACK=""/' "$RAIZ/meow.conf.exemplo" > "$CF/meow.conf"
cp "$CF/meow.conf" "$T/conf-dela"
s="$(instalar)"
if cmp -s "$T/conf-dela" "$CF/meow.conf" && ! ls "$CF"/meow.conf.antes-perfil-* >/dev/null 2>&1 \
   && [[ "$s" != *"pack-no-ar=dracula"* ]]; then
  ok "sem a flag, o meow.conf que já existe não muda"
else
  falha "sem --perfil, o meow.conf da casa mudou" "$(diff "$T/conf-dela" "$CF/meow.conf" | head -5)"
fi

s="$(instalar --perfil teste --dry-run)"
if cmp -s "$T/conf-dela" "$CF/meow.conf" && ! ls "$CF"/meow.conf.antes-perfil-* >/dev/null 2>&1 \
   && [[ "$s" == *"pack-no-ar=dracula"* ]]; then
  ok "no ensaio, --perfil não escreve nada, e a fila ensaia com o perfil"
else
  falha "o ensaio do --perfil escreveu ou não leu o perfil" "$(tail -8 <<< "$s")"
fi

s="$(instalar --perfil=teste)"
antes=("$CF"/meow.conf.antes-perfil-*)
if cmp -s "$R/perfis/teste/meow.conf" "$CF/meow.conf" && [ "${#antes[@]}" = 1 ] && cmp -s "$T/conf-dela" "${antes[0]}"; then
  ok "com a flag, o perfil entra e o meow.conf de antes fica guardado ao lado"
else
  falha "o --perfil=teste não trocou o conf ou não guardou o de antes" "$(ls "$CF")"
fi

instalar --perfil teste >/dev/null
n="$(ls -1 "$CF" | grep -c '^meow.conf.antes-perfil-')"
[ "$n" = 1 ] && ok "a segunda vez com o mesmo perfil não escreve nem guarda nada" \
  || falha "o --perfil repetido guardou cópia de novo ($n)" "$(ls "$CF")"

for nome in inexistente ../teste ""; do
  cp "$CF/meow.conf" "$T/conf-antes"
  s="$(instalar --perfil "$nome")"; rc=$?
  if [ "$rc" = 2 ] && cmp -s "$T/conf-antes" "$CF/meow.conf" && [[ "$s" != *"diz o pack"* ]]; then
    ok "--perfil '$nome' é recusado antes da fila, sem tocar no conf"
  else
    falha "--perfil '$nome' não foi recusado (rc=$rc)" "$(tail -4 <<< "$s")"
  fi
done

# A flag e a página de entrada não se separam caladas.
for leia in README.md README.en.md; do
  grep -q './install.sh --perfil' "$RAIZ/$leia" \
    && ok "o $leia diz como instalar com um perfil" \
    || falha "o $leia não fala do ./install.sh --perfil"
done

[ "$falhas" = 0 ] || { printf '%d falha(s)\n' "$falhas" >&2; exit 1; }
printf 'perfil: tudo ok\n'

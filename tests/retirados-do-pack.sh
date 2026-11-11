#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 3; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
printf '#!/bin/sh\nexit 1\n' > "$FALSO/sudo"; chmod 755 "$FALSO/sudo"
mkdir -p "$T/raiz"
for d in lib scripts assets packs meow.conf.exemplo; do cp -r "$RAIZ/$d" "$T/raiz/"; done

CASA="$T/casa"
ALVO="$CASA/.local/share/icons/MeowSystem-Icons/scalable/apps"
mkdir -p "$ALVO" "$CASA/.config/meow"
printf '[Icon Theme]\nName=MeowSystem-Icons\nDirectories=scalable/apps\n' \
  > "$CASA/.local/share/icons/MeowSystem-Icons/index.theme"

completar() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" NO_COLOR=1 MEOW_RAIZ="$T/raiz" \
    PACK=dracula FLAVOR=dracula ACCENT=mauve ICONES_BASE=Tema-Ausente NOME_TEMA_ICONES=MeowSystem-Icons \
    bash "$T/raiz/scripts/completar_icones.sh" 2>&1
}

NOME=com.system76.CosmicFiles
printf '<svg xmlns="http://www.w3.org/2000/svg"/>\n' > "$ALVO/$NOME.svg"
saida="$(completar)"
[ ! -e "$ALVO/$NOME.svg" ] \
  && ok "sem escolha do pack, o completar retira o $NOME do tema (quem veste é o Arcticons)" \
  || falha "o completar não retirou o $NOME sem escolha" "$saida"

printf '<svg xmlns="http://www.w3.org/2000/svg"/>\n' > "$ALVO/$NOME.svg"
alvo="packs/dracula/icones/biblioteca/$(ls "$T/raiz/packs/dracula/icones/biblioteca" | grep '\.svg$' | head -1)"
printf '%s : %s   # Arquivos — escolhido no painel\n' "$NOME" "$alvo" > "$CASA/.config/meow/icones-escolhidos.map"
saida="$(completar)"
[ -e "$ALVO/$NOME.svg" ] \
  && ok "com o desenho do pack escolhido para o $NOME, o completar deixa o arquivo onde está" \
  || falha "o completar apagou o desenho que o pack escolheu para o $NOME" "$saida"

[ "$falhas" -eq 0 ] || exit 1
printf 'retirados-do-pack: tudo certo\n'

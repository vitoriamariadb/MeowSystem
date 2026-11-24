#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
export HOME="$T/casa"
unset XDG_CONFIG_HOME XDG_DATA_HOME MEOW_CONF MEOW_ICONES_TRACO MEOW_ICONES_CONVERTIDOS MEOW_ICONES_DESTRAVADOS
mkdir -p "$HOME/.config/meow"
cp "$RAIZ/meow.conf.exemplo" "$HOME/.config/meow/meow.conf"
LISTA="$HOME/.config/meow/icones-destravados.list"
TRACO="$HOME/.config/meow/icones-traco.map"
falhas=0
ok() { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1"; falhas=$((falhas + 1)); }

arcticons() { MEOW_DRY_RUN=1 bash "$RAIZ/scripts/icones_apps_arcticons.sh" 2>&1; }

printf 'fogstripper:keymapper:mauve:alias\n' > "$TRACO"
saida="$(arcticons)"
grep -q 'fogstripper' <<< "$saida" \
  && falha "o intocável sem destravar já entrava no tema" \
  || ok "sem destravar, o intocável fica de fora"
printf 'fogstripper\n../fora\n' > "$LISTA"
saida="$(arcticons)"
grep -q '/fogstripper.svg' <<< "$saida" \
  && ok "destravado, o traço escolhido do intocável entra no tema" \
  || falha "destravado, o traço do intocável não entrou: $(tail -3 <<< "$saida")"

convertido="$(grep -v '^#' "$RAIZ/packs/meowsystem/icones/apps-convertidos.map" | grep -m1 . | cut -d: -f1)"
printf '%s:keymapper:mauve:alias\n' "$convertido" > "$TRACO"
: > "$LISTA"
saida="$(arcticons)"
grep -q 'está nos DOIS mapas' <<< "$saida" \
  && ok "sem destravar, o traço por cima do convertido do projeto é recusado ($convertido)" \
  || falha "sem destravar, o traço por cima do convertido passou calado"
printf '%s\n' "$convertido" > "$LISTA"
saida="$(arcticons)"; rc=$?
if ! grep -q 'está nos DOIS mapas' <<< "$saida" && [ "$rc" != 2 ] && grep -q "/$convertido.svg" <<< "$saida"; then
  ok "destravado, o traço escolhido vence o convertido do projeto"
else
  falha "destravado, o convertido ainda briga com o traço (rc=$rc): $(tail -3 <<< "$saida")"
fi

saida="$(bash -c '. "$1/scripts/lib/comum.sh"; meow_destravados' _ "$RAIZ")"
[ "$saida" = "$convertido" ] && ok "a lista só aceita nome de ícone" || falha "a lista leu o que não devia: $saida"

lev="$(python3 "$RAIZ/scripts/pack.py" levadas dracula mimetypes)"
[ "$lev" = "$(cd "$RAIZ/packs/dracula/icones/sistema" && pwd -P)" ] \
  && ok "o Dracula herda os tipos de arquivo: o desenho próprio por nome vale" \
  || falha "levadas dracula mimetypes deu «$lev»"
lev="$(python3 "$RAIZ/scripts/pack.py" levadas dracula sistema)"
[ -z "$lev" ] && ok "no bloco que o Dracula declara, o nome não troca o mapa" || falha "levadas dracula sistema deu «$lev»"

mkdir -p "$T/packs"
cp -r "$RAIZ/packs/dracula" "$T/packs/"
printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path d="M1 1h14v14H1z" data-meu="sim"/></svg>\n' \
  > "$T/packs/dracula/icones/sistema/application-certificate.svg"
MEOW_PACKS="$T/packs" PACK=dracula bash "$RAIZ/scripts/icones_mimetypes.sh" > /dev/null 2>&1
instalado="$HOME/.local/share/icons/MeowSystem-Icons/scalable/mimetypes/application-certificate.svg"
grep -q 'data-meu' "$instalado" 2>/dev/null \
  && ok "o tipo de arquivo herdado usa o desenho próprio do tema em edição" \
  || falha "o instalador dos tipos de arquivo ignorou o desenho próprio herdado"

python3 -I - "$RAIZ" <<'PY' || falhas=$((falhas + 1))
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "scripts", "app"))
import servidor
servidor.destravar(["um.app", "../fora", "um.app"])
lido = servidor.destravados()
ok = "um.app" in lido and "../fora" not in lido
print(("ok: " if ok else "FALHOU: ") + "o servidor grava o destravado uma vez e recusa nome que não serve")
sys.exit(0 if ok else 1)
PY

[ "$falhas" = 0 ] || { printf '\n%s FALHOU\n' "$falhas"; exit 1; }
printf '\ndestrava: tudo certo\n'

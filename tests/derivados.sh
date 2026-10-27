#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/        /' >&2
          falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }
command -v git >/dev/null 2>&1 || { printf 'pulado: sem git, não há como copiar a árvore\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
R="$T/raiz"; CASA="$T/casa"; FALSO="$T/falso"
mkdir -p "$R" "$CASA" "$FALSO"
( cd "$RAIZ" && { git ls-files -z; git ls-files -z --others --exclude-standard; } \
    | tar --null -T - -cf - 2>/dev/null ) | tar -xf - -C "$R" || exit 2
for b in sudo pkexec su apt apt-get cargo just make rustup systemctl pkill; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/derivados.sh\\n" >&2\nexit 1\n' "$b" > "$FALSO/$b"
  chmod 755 "$FALSO/$b"
done
amb() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_ESTADO="$CASA/estado" PACK=dracula FLAVOR=dracula ACCENT=mauve \
    NOME_TEMA_ICONES=MeowSystem-Icons ICONES_DRACULA=sim MEOW_DERIVADOS_ESPERA="${ESPERA:-0.3}" "$@"
}
TEMA="$CASA/.local/share/icons/MeowSystem-Icons"
TABELA="$CASA/estado/derivados.tsv"
REGISTRO="$CASA/estado/derivados.log"
F="$R/packs/dracula/icones/apps/steam.svg"
NO_TEMA="$TEMA/scalable/apps/steam.svg"
passadas() { grep -c ' passada ' "$REGISTRO" 2>/dev/null || true; }
mesmo() { [ -f "$1" ] && [ -f "$2" ] && [ "$(cat "$1")" = "$(cat "$2")" ]; }
TEM_CACHE=0; command -v gtk-update-icon-cache >/dev/null 2>&1 && TEM_CACHE=1

mkdir -p "$TEMA/scalable/apps"
printf '[Icon Theme]\nName=MeowSystem-Icons\nInherits=hicolor\nDirectories=scalable/apps\n\n[scalable/apps]\nSize=128\nType=Scalable\nMinSize=8\nMaxSize=512\nContext=Applications\n' \
  > "$TEMA/index.theme"
amb bash "$R/scripts/icones_apps_dracula.sh" --aplicar >/dev/null 2>&1
[ "$TEM_CACHE" = 1 ] && gtk-update-icon-cache -q -f "$TEMA"
saida="$(amb bash "$R/scripts/derivados.sh" --registrar 2>&1)"; rc=$?
[ "$rc" = "1" ] && [ -s "$TABELA" ] && mesmo "$F" "$NO_TEMA" \
  || { falha "o tema de partida não ficou de pé (rc=$rc)" "$saida"; exit 1; }
saida="$(amb bash "$R/scripts/derivados.sh" --conferir 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "registrada a tabela, o doctor vê os derivados em dia" \
  || falha "logo depois de registrar, o --conferir acusa diferença (rc=$rc)" "$saida"

printf '<!-- editado pelo teste -->\n' >> "$F"
cache_antes="$(stat -c %Y.%N "$TEMA/icon-theme.cache" 2>/dev/null)"
sleep 1.1
ini=$(date +%s)
saida="$(amb bash "$R/scripts/derivados.sh" --aplicar 2>&1)"; rc=$?
gasto=$(( $(date +%s) - ini ))
if [ "$rc" = "1" ] && mesmo "$F" "$NO_TEMA" && [ "$gasto" -le 60 ] && [ "$(passadas)" = "1" ]; then
  ok "o SVG editado chegou ao tema instalado em ${gasto}s, numa passada"
else
  falha "o SVG editado não chegou ao tema (rc=$rc, ${gasto}s, $(passadas) passada(s))" "$saida"
fi
if [ "$TEM_CACHE" = 1 ]; then
  [ "$(stat -c %Y.%N "$TEMA/icon-theme.cache")" != "$cache_antes" ] \
    && ok "a cache do tema foi refeita junto" \
    || falha "a cache do tema ficou a de antes, e esconderia o desenho novo"
else
  printf 'pulado: sem gtk-update-icon-cache, a cache do tema não se confere\n'
fi
amb bash "$R/scripts/derivados.sh" --conferir >/dev/null 2>&1 \
  && ok "depois da passada, a tabela é a do disco" \
  || falha "depois da passada, o --conferir ainda acusa diferença"

antes="$(stat -c %Y.%N "$NO_TEMA" "$TABELA" "$TEMA/icon-theme.cache" 2>/dev/null)"
cp "$F" "$F.tmp" && mv -f "$F.tmp" "$F"; touch "$F"
sleep 1.1
saida="$(amb bash "$R/scripts/derivados.sh" --aplicar 2>&1)"; rc=$?
depois="$(stat -c %Y.%N "$NO_TEMA" "$TABELA" "$TEMA/icon-theme.cache" 2>/dev/null)"
[ "$rc" = "0" ] && [ "$antes" = "$depois" ] && [ "$(passadas)" = "1" ] \
  && ok "salvar de novo o mesmo conteúdo não escreve nada: nem o tema, nem a tabela, nem a cache" \
  || falha "o mesmo conteúdo escreveu alguma coisa (rc=$rc, $(passadas) passada(s))" "$saida"

( for i in $(seq 1 20); do printf '<!-- rajada %s -->\n' "$i" >> "$F"; sleep 0.05; done ) &
saida="$(ESPERA=0.8 amb bash "$R/scripts/derivados.sh" --aplicar 2>&1)"; rc=$?
wait
[ "$rc" = "1" ] && [ "$(passadas)" = "2" ] && mesmo "$F" "$NO_TEMA" \
  && ok "vinte salvamentos seguidos viraram uma passada só, com o último conteúdo no tema" \
  || falha "a rajada não virou uma passada com o último conteúdo (rc=$rc, $(passadas) passada(s))" "$saida"

printf '<!-- com o PC desligado -->\n' >> "$F"
antes="$(stat -c %Y.%N "$NO_TEMA" "$TABELA" 2>/dev/null)"
saida="$(amb bash "$R/scripts/derivados.sh" --conferir 2>&1)"; rc=$?
[ "$rc" = "1" ] && [ "$antes" = "$(stat -c %Y.%N "$NO_TEMA" "$TABELA" 2>/dev/null)" ] \
  && ok "o --conferir do doctor acusa o desenho que o vigia perdeu, sem escrever nada" \
  || falha "o --conferir não viu a mudança, ou escreveu (rc=$rc)" "$saida"
saida="$(amb env MEOW_DRY_RUN=1 bash "$R/scripts/derivados.sh" --aplicar 2>&1)"; rc=$?
[ "$rc" = "1" ] && [ "$antes" = "$(stat -c %Y.%N "$NO_TEMA" "$TABELA" 2>/dev/null)" ] \
  && ok "no ensaio, o --aplicar só conta" \
  || falha "o ensaio do --aplicar escreveu (rc=$rc)" "$saida"
amb bash "$R/scripts/derivados.sh" --aplicar >/dev/null 2>&1
mesmo "$F" "$NO_TEMA" \
  && ok "o conserto do doctor (--aplicar) refaz o que faltava" \
  || falha "o conserto não pôs o desenho no tema"

rm -f "$F"
saida="$(amb bash "$R/scripts/derivados.sh" --aplicar 2>&1)"; rc=$?
[ "$rc" = "1" ] && [ ! -e "$NO_TEMA" ] \
  && ok "o desenho apagado saiu do tema junto" \
  || falha "o desenho apagado deixou a cópia no tema (rc=$rc)" "$saida"
amb bash "$R/scripts/derivados.sh" --conferir >/dev/null 2>&1 \
  && ok "e a tabela esqueceu a fonte que saiu" \
  || falha "a tabela ainda conta a fonte que saiu"
rm -f "$R/packs/dracula/icones/apps/google-chrome.svg"
saida="$(amb bash "$R/scripts/derivados.sh" --aplicar 2>&1)"; rc=$?
[ "$rc" = "1" ] && [ -f "$TEMA/48x48/apps/google-chrome.svg" ] \
  && ok "o desenho do pack apagado devolve o traço a 48 px" \
  || falha "o desenho do pack saiu e o traço não voltou a 48 px (rc=$rc)" "$saida"

pastas="$(amb bash "$R/scripts/derivados.sh" --pastas 2>/dev/null)"
esperadas="$R/packs/dracula/icones/apps
$R/packs/dracula/icones/sistema
$R/packs/dracula/icones/biblioteca
$R/packs/meowsystem/icones/apps
$R/packs/meowsystem/icones/sistema
$R/packs/meowsystem/icones"
faltam="$(grep -vxF -f <(printf '%s\n' "$pastas") <<<"$esperadas")"
fora="$(grep -v -e "^$R/packs/[a-z0-9-]*\$" -e "^$R/packs/[a-z0-9-]*/icones\(/\(apps\|sistema\|biblioteca\)\(/.*\)\?\)\?\$" <<<"$pastas")"
[ -z "$faltam" ] && [ -z "$fora" ] \
  && ok "a .path vigia as três pastas de cada pack da cadeia, o icones/ e a raiz (o logo), e nada mais" \
  || falha "as pastas vigiadas não são as do formato" "faltam: $faltam
fora: $fora"
unidade="$T/meow-derivados.path"
linhas="$(sed 's/^/PathModified=/' <<<"$pastas")"
awk -v linhas="$linhas" '$0 == "@VIGIADOS@" { print linhas; next } { print }' \
  "$RAIZ/systemd/meow-derivados.path" > "$unidade"
cp "$RAIZ/systemd/meow-derivados.service" "$T/"
if command -v systemd-analyze >/dev/null 2>&1; then
  saida="$(systemd-analyze verify --user "$unidade" 2>&1 | grep -v -i 'dbus\|bus\b\|XDG_RUNTIME_DIR\|Failed to connect')"
  [[ "$saida" != *"$unidade"* ]] \
    && ok "a unidade .path, com as pastas no lugar do @VIGIADOS@, passa no systemd-analyze verify" \
    || falha "a unidade .path gerada não passa no systemd-analyze" "$saida"
else
  printf 'pulado: sem systemd-analyze, a unidade gerada não se confere\n'
fi
saida="$(amb bash "$R/scripts/vigia_derivados.sh" --conferir 2>&1)"; rc=$?
{ [ "$rc" = "1" ] && [[ "$saida" == *"a instalar"* ]] || [ "$rc" = "3" ]; } \
  && [ ! -e "$CASA/.config/systemd/user/meow-derivados.path" ] \
  && ok "o --conferir do vigia diz o que falta e não escreve unidade nenhuma" \
  || falha "o --conferir do vigia escreveu, ou não disse o que falta (rc=$rc)" "$saida"

MOLDE="$R/packs/meowsystem/icones/sistema/json.svg"
NO_TEMA_MT="$TEMA/scalable/mimetypes/application-json.svg"
amb bash "$R/scripts/icones_mimetypes.sh" --aplicar >/dev/null 2>&1
amb bash "$R/scripts/derivados.sh" --registrar >/dev/null 2>&1
vermelho="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["flavors"]["dracula"]["red"].lower())' "$R/packs/dracula/paleta.json")"
if [ -f "$NO_TEMA_MT" ] && grep -q 'vscode-ctp-yellow' "$MOLDE"; then
  sed -i 's/vscode-ctp-yellow/vscode-ctp-red/g' "$MOLDE"
  sleep 1.1
  saida="$(amb bash "$R/scripts/derivados.sh" --aplicar 2>&1)"; rc=$?
  [ "$rc" = "1" ] && grep -qi "$vermelho" "$NO_TEMA_MT" && ! grep -q 'var(--' "$NO_TEMA_MT" \
    && ok "o molde editado no pack chegou ao tema, pintado com a paleta do Dracula ($vermelho)" \
    || falha "o molde editado não chegou ao tema pintado (rc=$rc)" "$saida$(head -c 300 "$NO_TEMA_MT" 2>/dev/null)"
  antes="$(stat -c %Y.%N "$NO_TEMA_MT" "$TABELA" 2>/dev/null)"
  saida="$(amb bash "$R/scripts/derivados.sh" --aplicar 2>&1)"; rc=$?
  [ "$rc" = "0" ] && [ "$antes" = "$(stat -c %Y.%N "$NO_TEMA_MT" "$TABELA" 2>/dev/null)" ] \
    && ok "a segunda passada depois do molde não escreve nada" \
    || falha "a segunda passada depois do molde escreveu (rc=$rc)" "$saida"
else
  falha "o tipo de arquivo do JSON não ficou no tema de partida, ou o molde mudou de papel" "$(ls "$TEMA/scalable/mimetypes" 2>&1 | head -3)"
fi

if [ "$falhas" -gt 0 ]; then
  printf '\nFALHOU: %s achado(s)\n' "$falhas" >&2
  exit 1
fi
exit 0

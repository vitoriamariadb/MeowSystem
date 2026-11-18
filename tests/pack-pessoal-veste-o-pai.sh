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
for c in sudo pkexec su; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/pack-pessoal-veste-o-pai.sh\\n" >&2\nexit 1\n' "$c" > "$FALSO/$c"
  chmod 755 "$FALSO/$c"
done
CASA="$T/casa"
TEMA="$CASA/.local/share/icons/MeowSystem-Icons"
MEU="$CASA/.local/share/meowsystem/packs/meu-pessoal"
mkdir -p "$TEMA" "$MEU/icones/sistema" "$MEU/icones/autorais" "$MEU/icones/apps" "$CASA/.config/meow" || exit 2
printf '[Icon Theme]\nName=MeowSystem-Icons\nInherits=hicolor\nDirectories=scalable/apps\n' > "$TEMA/index.theme"
cp "$RAIZ/meow.conf.exemplo" "$CASA/.config/meow/meow.conf"
cp "$RAIZ/packs/meowsystem/paleta.json" "$MEU/paleta.json"
printf '{"formato": 2, "id": "meu-pessoal", "nome": "Meu pessoal", "heranca": "meowsystem", "icones": {"autorais": {}, "apps": {}}}\n' > "$MEU/pack.json"

amb() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" PACK=meu-pessoal FLAVOR= "$@"
}

saida="$(amb "$RAIZ/scripts/icones_sistema.sh" --conferir 2>&1)"
[[ "$saida" != *"não declara icones.sistema"* ]] \
  && ok "a linha sistema do doctor deixa de dizer que o pack não declara icones.sistema" \
  || falha "o doctor ainda diz que o pack pessoal não declara icones.sistema" "$saida"

amb "$RAIZ/scripts/icones_sistema.sh" --aplicar >/dev/null 2>&1
n="$(find "$TEMA" -name '*-symbolic.svg' | wc -l)"
[ "$n" -ge 100 ] && [ -f "$TEMA/scalable/actions/window-close-symbolic.svg" ] \
  && ok "o pack pessoal sem icones.sistema veste os desenhos do pack de heranca ($n símbolos, com os botões da janela)" \
  || falha "o pack pessoal não recebeu os desenhos do pai" "$n"

PAI="$(cat "$TEMA/scalable/status/audio-volume-high-symbolic.svg")"
printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><circle cx="24" cy="24" r="10" fill="none" stroke="currentColor" stroke-width="1"/></svg>\n' \
  > "$MEU/icones/sistema/audio-volume-high-symbolic.svg"
amb "$RAIZ/scripts/icones_sistema.sh" --aplicar >/dev/null 2>&1
PROPRIO="$(cat "$TEMA/scalable/status/audio-volume-high-symbolic.svg")"
[ "$PROPRIO" != "$PAI" ] && [[ "$PROPRIO" == *"<circle"* ]] \
  && ok "o desenho próprio do pack vence o herdado, nome a nome" \
  || falha "o desenho do pai ficou no lugar do próprio"
grep -q 'stroke-width="1"' "$TEMA/scalable/status/audio-volume-high-symbolic.svg" \
  && grep -q 'stroke-width="2.5"' "$TEMA/scalable/status/network-wireless-signal-weak-symbolic.svg" \
  && ok "o desenho herdado sai com o traço do pai (2,5) e o próprio com o que o pack desenhou (1)" \
  || falha "o traço do pai engordou o desenho próprio, ou o herdado perdeu o dele"
python3 - "$MEU/pack.json" <<'PY2'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
d["icones"]["sistema"] = {"traco": {"22x22": 3, "scalable": 1.5}}
json.dump(d, open(sys.argv[1], "w", encoding="utf-8"))
PY2
amb "$RAIZ/scripts/icones_sistema.sh" --aplicar >/dev/null 2>&1
grep -q 'stroke-width="1.5"' "$TEMA/scalable/status/audio-volume-high-symbolic.svg" \
  && grep -q 'stroke-width="2.5"' "$TEMA/scalable/status/network-wireless-signal-weak-symbolic.svg" \
  && ok "o traço que o pack pessoal declara vale só para o desenho próprio; o herdado segue com o do pai" \
  || falha "o traço declarado pelo pack pessoal não foi para o desenho próprio"
[ -f "$TEMA/scalable/actions/window-close-symbolic.svg" ] \
  && ok "os outros nomes seguem com o desenho do pai" \
  || falha "o desenho próprio apagou os herdados"

amb "$RAIZ/scripts/icones_sistema.sh" --conferir >/dev/null 2>&1
[ $? = 0 ] && ok "a conferência depois de aplicar diz que está tudo no lugar" || falha "a conferência diverge logo depois de aplicar"
antes="$(cd "$TEMA" && find . -type f | sort | xargs sha256sum)"
amb "$RAIZ/scripts/icones_sistema.sh" --aplicar >/dev/null 2>&1
[ $? = 0 ] && [ "$antes" = "$(cd "$TEMA" && find . -type f | sort | xargs sha256sum)" ] \
  && ok "a segunda passada não escreve nada" || falha "a segunda passada escreveu"

if [ "$falhas" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$falhas" >&2
  exit 1
fi
exit 0

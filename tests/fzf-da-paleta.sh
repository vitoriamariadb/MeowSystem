#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf '  NÃO  %s\n' "$*" >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }
[ -x "$RAIZ/scripts/fzf.sh" ] || { printf 'erro: falta scripts/fzf.sh\n' >&2; exit 2; }

TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT

correr() {
  local casa="$1" verbo="$2"; shift 2
  env -i PATH="$PATH" HOME="$casa" NO_COLOR=1 MEOW_RAIZ="$RAIZ" PACK= "$@" \
    "$RAIZ/scripts/fzf.sh" "$verbo" 2>&1
}
arquivo() { printf '%s/.config/meowsystem/fzf.sh' "$1"; }

esperado() {
  python3 - "$1" "$2" "$3" <<'PY'
import json, sys
c = json.load(open(sys.argv[1], encoding="utf-8"))["flavors"][sys.argv[2]]
a = sys.argv[3]
pares = [("bg+", "surface1"), ("fg+", "text"), ("hl", a), ("hl+", "pink"),
         ("pointer", "green"), ("marker", "green"), ("prompt", a),
         ("header", "overlay0"), ("border", "overlay0")]
print("--color=" + ",".join("%s:%s" % (k, c[s]) for k, s in pares))
PY
}
opcoes_de() { sed -n 's/^export FZF_DEFAULT_OPTS="\(.*\)"$/\1/p' "$1" 2>/dev/null; }

printf '\n--- 1. o script não carrega cor ---\n'
hex_no_codigo() { grep -nE '#[0-9A-Fa-f]{6}\b' "$RAIZ/scripts/fzf.sh" | grep -vE '^[0-9]+:[[:space:]]*#'; }
if hex_no_codigo >/dev/null; then
  falha "scripts/fzf.sh tem hex cravado em código:"
  hex_no_codigo | sed 's/^/       /' >&2
else
  ok "scripts/fzf.sh não tem um #RRGGBB em linha de código"
fi

printf '\n--- 2. a paleta manda: cores que nenhum pack tem ---\n'
FALSA="$TMP/paleta-falsa.json"
python3 - "$FALSA" <<'PY'
import json, sys
slots = ["surface1", "text", "mauve", "pink", "green", "overlay0"]
cores = {s: "#%02X%02X%02X" % (i + 1, 0x11 * (i + 1), 0xF0 - i) for i, s in enumerate(slots)}
json.dump({"claros": [], "nomes": {"teste": "Teste"}, "flavors": {"teste": cores}},
          open(sys.argv[1], "w", encoding="utf-8"))
PY
C2="$TMP/casa-falsa"; mkdir -p "$C2"
saida="$(correr "$C2" aplicar FLAVOR=teste ACCENT=mauve MEOW_PALETA="$FALSA")"; rc=$?
quer="$(esperado "$FALSA" teste mauve)"
tem="$(opcoes_de "$(arquivo "$C2")")"
if [ "$rc" = "1" ] && [ -n "$tem" ] && [ "$tem" = "$quer" ]; then
  ok "a paleta inventada saiu inteira, papel por papel ($tem)"
else
  falha "com a paleta inventada: rc=$rc, esperado [$quer], veio [$tem]"
  printf '%s\n' "$saida" | tail -3 | sed 's/^/       /' >&2
fi

printf '\n--- 3. o pack no ar decide ---\n'
for par in "dracula:$RAIZ/packs/dracula/paleta.json" "mocha:$RAIZ/packs/meowsystem/paleta.json"; do
  flavor="${par%%:*}"; paleta="${par#*:}"
  [ -f "$paleta" ] || { falha "falta $paleta"; continue; }
  casa="$TMP/casa-$flavor"; mkdir -p "$casa"
  correr "$casa" aplicar FLAVOR="$flavor" ACCENT=mauve >/dev/null; rc=$?
  quer="$(esperado "$paleta" "$flavor" mauve)"
  tem="$(opcoes_de "$(arquivo "$casa")")"
  if [ "$rc" = "1" ] && [ "$tem" = "$quer" ]; then
    ok "FLAVOR=$flavor: as cores são as de ${paleta#"$RAIZ"/}"
  else
    falha "FLAVOR=$flavor: rc=$rc, esperado [$quer], veio [$tem]"
  fi
done
d="$(opcoes_de "$(arquivo "$TMP/casa-dracula")")"; m="$(opcoes_de "$(arquivo "$TMP/casa-mocha")")"
if [ -n "$d" ] && [ -n "$m" ] && [ "$d" != "$m" ]; then
  ok "Dracula e Catppuccin dão cores diferentes (não é uma cor só para os dois)"
else
  falha "Dracula e Catppuccin deram a mesma saída: [$d]"
fi

printf '\n--- 4. a segunda passagem não escreve, e o conferir acompanha ---\n'
casa="$TMP/casa-mocha"
antes="$(stat -c '%Y %i' "$(arquivo "$casa")" 2>/dev/null)"
correr "$casa" aplicar FLAVOR=mocha ACCENT=mauve >/dev/null; rc=$?
depois="$(stat -c '%Y %i' "$(arquivo "$casa")" 2>/dev/null)"
if [ "$rc" = "0" ] && [ "$antes" = "$depois" ]; then
  ok "segunda passagem: rc=0 e o arquivo não foi reescrito"
else
  falha "segunda passagem: rc=$rc (esperado 0), arquivo antes [$antes] depois [$depois]"
fi
correr "$casa" conferir FLAVOR=mocha ACCENT=mauve >/dev/null; rc=$?
[ "$rc" = "0" ] && ok "conferir depois do aplicar: 0" || falha "conferir depois do aplicar: rc=$rc"
correr "$casa" conferir FLAVOR=dracula ACCENT=mauve >/dev/null; rc=$?
[ "$rc" = "1" ] && ok "conferir com o pack trocado: 1" || falha "conferir com o pack trocado: rc=$rc (esperado 1)"
seco_antes="$(sha256sum "$(arquivo "$casa")" | cut -d' ' -f1)"
correr "$casa" aplicar FLAVOR=dracula ACCENT=mauve MEOW_DRY_RUN=1 >/dev/null; rc=$?
seco_depois="$(sha256sum "$(arquivo "$casa")" | cut -d' ' -f1)"
if [ "$rc" = "1" ] && [ "$seco_antes" = "$seco_depois" ]; then
  ok "no seco, o aplicar diz que mudaria e não muda"
else
  falha "no seco: rc=$rc, arquivo mudou? $([ "$seco_antes" = "$seco_depois" ] && echo não || echo SIM)"
fi

printf '\n'
if [ "$ACHADOS" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2
  exit 1
fi
printf 'passou: as cores do fzf são da paleta, e só dela\n'
exit 0

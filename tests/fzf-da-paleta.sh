#!/usr/bin/env bash
# fzf-da-paleta.sh — as cores do fzf saem da paleta do pack no ar, nunca de hex.
#
# POR QUE ESTE ARQUIVO NASCEU EM 24/09/2026 (P44)
#   As cores do fzf moravam cravadas no `env.zsh` do Spellbook, e em DUAS
#   paletas na mesma máquina: o `FZF_DEFAULT_OPTS` em Catppuccin e o fzf-tab em
#   Dracula, com `FLAVOR="dracula"` no meow.conf. Trocar de pack não mudava
#   nenhuma. O `scripts/fzf.sh` tirou as duas de lá; este teste cobra que o que
#   ele escreve é função da paleta e de nada mais.
#
# AS QUATRO PERGUNTAS
#   1. O script não carrega hex nenhum. Um `#RRGGBB` no fonte seria o cravado
#      de volta, só que do lado de cá.
#   2. Uma paleta INVENTADA (cores que nenhum pack tem) sai no arquivo, papel
#      por papel. É a prova de que a cor vem da paleta: um script que tivesse
#      guardado o Catppuccin passaria nos dois packs de verdade e cairia aqui.
#   3. Os dois packs do repositório: com o Dracula no ar, as cores do Dracula;
#      com o Catppuccin, as do Catppuccin — lidas da `paleta.json` de cada um.
#   4. Idempotência e conferência: a segunda passagem não escreve, e o
#      `conferir` diz 0 depois do `aplicar` e 1 quando o pack muda.
#
#   0 = passou · 1 = falhou · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf '  NÃO  %s\n' "$*" >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }
[ -x "$RAIZ/scripts/fzf.sh" ] || { printf 'erro: falta scripts/fzf.sh\n' >&2; exit 2; }

TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT

# `env -i`: nada do shell de quem roda o teste (um MEOW_PALETA ou um PACK
# exportado mudaria a resposta). PACK vazio deixa o FLAVOR adotar o pack.
correr() {   # $1 = casa · $2 = verbo · resto = VAR=valor
  local casa="$1" verbo="$2"; shift 2
  env -i PATH="$PATH" HOME="$casa" NO_COLOR=1 MEOW_RAIZ="$RAIZ" PACK= "$@" \
    "$RAIZ/scripts/fzf.sh" "$verbo" 2>&1
}
arquivo() { printf '%s/.config/meowsystem/fzf.sh' "$1"; }

# O que o arquivo DEVERIA dizer, montado aqui a partir da paleta e do mapa de
# papéis do cabeçalho do script — sem passar por ele.
esperado() {   # $1 = paleta · $2 = flavor · $3 = acento
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

# --- 1. nenhum hex no fonte --------------------------------------------------
# COMENTÁRIO NÃO CONTA: o cabeçalho do script cita os hex que estavam cravados
# no `env.zsh`, e é o registro da medição. O que se caça é hex em CÓDIGO.
printf '\n--- 1. o script não carrega cor ---\n'
hex_no_codigo() { grep -nE '#[0-9A-Fa-f]{6}\b' "$RAIZ/scripts/fzf.sh" | grep -vE '^[0-9]+:[[:space:]]*#'; }
if hex_no_codigo >/dev/null; then
  falha "scripts/fzf.sh tem hex cravado em código:"
  hex_no_codigo | sed 's/^/       /' >&2
else
  ok "scripts/fzf.sh não tem um #RRGGBB em linha de código"
fi

# --- 2. uma paleta inventada -------------------------------------------------
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

# --- 3. os dois packs do repositório ------------------------------------------
printf '\n--- 3. o pack no ar decide ---\n'
for par in "dracula:$RAIZ/packs/dracula/paleta.json" "mocha:$RAIZ/packs/catppuccin/paleta.json"; do
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

# --- 4. idempotência e conferência --------------------------------------------
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

#!/usr/bin/env bash
# pack-dracula-completo.sh — o pack Dracula é um tema completo, montado certo e
# exportável (P74, 09/10/2026).
#
# O QUE ELE VIGIA
#   Cada bloco abaixo é um item da spec `docs/sprints/2026-10-09-uso-real/
#   P74-pack-dracula-completo.md`, e confere o contrato dele sem rede e sem
#   escrever fora de um temporário. As provas que pedem rede (baixar a base,
#   montar o tema inteiro) estão no relatório da spec, com o comando e a saída.
#
# NADA SAI DA CASA DE BRINQUEDO: `env -i` com HOME temporário, e um `sudo`
#   falso na frente do PATH — nenhuma linha daqui chama sudo, e o falso existe
#   para que nenhuma passe a chamar calada numa máquina com `NOPASSWD`.
#
#   0 = o pack Dracula cumpre o que a P74 pediu · 1 = achados · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO" "$T/casa"
printf '#!/bin/sh\nprintf "sudo: recusado pelo tests/pack-dracula-completo.sh\\n" >&2\nexit 1\n' > "$FALSO/sudo"
chmod 755 "$FALSO/sudo"

# amb <comando...> — numa casa vazia, sem o ambiente de quem roda.
amb() {
  env -i PATH="$FALSO:$PATH" HOME="$T/casa" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" "$@"
}

# --- item 2: a base em duas camadas, as duas pinadas -------------------------
#   Decisão 1 de 09/10: `circle` por cima, `main` por trás, como o tema antigo.
#   O verbo diz a frente nas linhas de sempre e uma `atras=` por camada; o nome
#   da camada de trás, escolhido no conf, cede ao pack como o da frente; e o
#   `validar` recusa uma camada sem pino.
saida="$(amb env ICONES_BASE=Papirus-Dark python3 "$RAIZ/scripts/pack.py" base-icones dracula 2>&1)"
atras="$(printf '%s\n' "$saida" | sed -n 's/^atras=//p')"
if [[ "$saida" == *"quem=pack"* ]] && [[ "$saida" == *"/00a230a277d5e6ad913b90182977738335afee89.tar.gz"* ]] \
   && [ "$(printf '%s\n' "$atras" | grep -c .)" = "1" ] \
   && [[ "$atras" == *"/de2a8edd94608ba0ac4dcf5a187af0ffaa511ebc.tar.gz"$'\t'*$'\t'"dracula-icons-de2a8edd94608ba0ac4dcf5a187af0ffaa511ebc" ]] \
   && [[ "$atras" =~ $'\t'[0-9a-f]{64}$'\t' ]]; then
  ok "a base do Dracula tem duas camadas pinadas: circle na frente, main por trás"
else
  falha "o verbo base-icones não diz as duas camadas da base do Dracula" "$saida"
fi
v="$(amb env ICONES_BASE=MeowSystem-Icons-Base-2 python3 "$RAIZ/scripts/pack.py" base-icones dracula 2>&1 | sed -n 's/^quem=//p')"
[ "$v" = "pack" ] \
  && ok "ICONES_BASE=MeowSystem-Icons-Base-2 (a camada de trás) cede ao pack, como a frente" \
  || falha "o nome da camada de trás foi lido como escolha à mão" "quem=$v"

mkdir -p "$T/packs"
cp -r "$RAIZ/packs/dracula" "$T/packs/torto"
python3 - "$T/packs/torto/pack.json" <<'PY'
import json, sys
f = sys.argv[1]
p = json.load(open(f, encoding="utf-8"))
p["id"] = "torto"
p["icones"]["base"]["por_tras"][0]["origem"].pop("sha256")
json.dump(p, open(f, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
saida="$(amb env MEOW_PACKS="$T/packs" python3 "$RAIZ/scripts/pack.py" validar torto 2>&1)"; rc=$?
[ "$rc" != "0" ] && [[ "$saida" == *"icones.base.por_tras[0].origem"* ]] \
  && ok "uma camada de trás sem sha256 é recusada pelo validar, com a trilha do campo" \
  || falha "o validar aceitou uma camada de trás sem pino (rc=$rc)" "$saida"

printf '\n'
if [ "$falhas" -eq 0 ]; then
  ok "o pack Dracula cumpre o que a P74 pediu"
  exit 0
fi
printf 'FALHOU: %d achado(s)\n' "$falhas" >&2
exit 1

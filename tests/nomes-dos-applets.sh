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
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/nomes-dos-applets.sh\\n" >&2\nexit 1\n' "$c" > "$FALSO/$c"
  chmod 755 "$FALSO/$c"
done
SISTEMA="$RAIZ/assets/contratos/nomes-de-sistema.tsv"
EXTENSOES="$RAIZ/assets/contratos/nomes-das-extensoes.tsv"
LAR="${SUITE_CASA_REAL:-$HOME}"
FONTES="${NOMES_DOS_APPLETS_FONTES:-$LAR/.local/state/meowsystem/extensoes}"
NAO_SAO_NOME_DE_ICONE='^(explicit|glyph|original|plain|regular|meow-icone-que-nao-existe)-symbolic$'

cut -f1 "$SISTEMA" "$EXTENSOES" | grep -v '^#' | sort -u > "$T/contrato"

verificados=0
for pino in "$RAIZ"/assets/extensoes/*.pino; do
  id="$(basename "$pino" .pino)"
  grep -q '^TIPO="applet"' "$pino" || continue
  commit="$(sed -n 's/^COMMIT="\(.*\)"/\1/p' "$pino")"
  fonte="$FONTES/$id/src"
  if [ ! -d "$fonte" ] || ! grep -q "^commit $commit\$" "$FONTES/$id/carimbo" 2>/dev/null; then
    printf 'pulado: o fonte do applet %s no commit %s não está nesta máquina\n' "$id" "${commit:0:8}"
    continue
  fi
  verificados=$((verificados + 1))
  fora="$(grep -rhoE '"[a-zA-Z0-9_.-]+-symbolic"' "$fonte" | tr -d '"' | sort -u \
    | grep -vE "$NAO_SAO_NOME_DE_ICONE" | grep -v '\.' | comm -23 - "$T/contrato")"
  [ -z "$fora" ] \
    && ok "$id: todo nome -symbolic do fonte está num dos dois contratos" \
    || falha "$id: nome(s) que o applet pede e nenhum contrato lista" "$fora"
done

n_ext="$(grep -vc '^#' "$EXTENSOES")"
[ "$n_ext" -ge 60 ] \
  && ok "o contrato das extensões lista $n_ext nomes" \
  || falha "o contrato das extensões encolheu" "$n_ext"

amb() {
  local casa="$1" pack="$2" flavor="$3"; shift 3
  env -i PATH="$FALSO:$PATH" HOME="$casa" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_RAIZ="$RAIZ" PACK="$pack" FLAVOR="$flavor" "$@"
}

for par in meowsystem:mocha dracula:dracula; do
  pack="${par%%:*}"; flavor="${par#*:}"
  casa="$T/casa-$pack"; tema="$casa/.local/share/icons/MeowSystem-Icons"
  mapa="$RAIZ/packs/$pack/icones/sistema.map"
  mkdir -p "$tema"
  printf '[Icon Theme]\nName=MeowSystem-Icons\nInherits=hicolor\nDirectories=scalable/apps\n' > "$tema/index.theme"
  amb "$casa" "$pack" "$flavor" "$RAIZ/scripts/icones_sistema.sh" --aplicar > "$T/aplicar-$pack" 2>&1
  ligados=0; faltam=""; vagas=""
  while IFS=$'\t' read -r nome ctx _grupo _rotulo quem; do
    case "$nome" in ''|'#'*) continue ;; esac
    [ "$quem" = soneca ] && continue
    if grep -q "^$nome:" "$mapa"; then
      if [ -f "$tema/scalable/$ctx/$nome.svg" ] && [ -f "$tema/22x22/$ctx/$nome.svg" ]; then
        ligados=$((ligados + 1))
      else
        faltam="$faltam  $ctx/$nome
"
      fi
    else
      vagas="$vagas $nome"
    fi
  done < "$EXTENSOES"
  [ -z "$faltam" ] && [ "$ligados" -ge 40 ] \
    && ok "$pack: os $ligados nomes das extensões ligados no mapa chegam ao tema instalado" \
    || falha "$pack: nome ligado no mapa que não chegou ao tema ($ligados ligados)" "$faltam"
  printf 'vagas do %s sem desenho (caem na base):%s\n' "$pack" "$vagas"
  for nome in notification-symbolic notification-new-symbolic battery-full-charged-symbolic color-select-symbolic; do
    ctx="$(awk -F'\t' -v n="$nome" '$1 == n {print $2}' "$EXTENSOES")"
    [ -f "$tema/scalable/$ctx/$nome.svg" ] \
      && ok "$pack: $nome está no tema, no desenho do pack" \
      || falha "$pack: $nome não chegou ao tema"
  done
  amb "$casa" "$pack" "$flavor" "$RAIZ/scripts/icones_sistema.sh" --aplicar >/dev/null 2>&1
  [ $? = 0 ] && ok "$pack: a segunda passada não escreve nada" || falha "$pack: a segunda passada escreveu"
done

[ "$verificados" -gt 0 ] || { printf 'pulado: nenhum fonte de applet nesta máquina\n'; exit 3; }
if [ "$falhas" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$falhas" >&2
  exit 1
fi
exit 0

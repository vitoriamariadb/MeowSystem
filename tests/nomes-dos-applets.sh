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
SISTEMA="$RAIZ/dados/contratos/nomes-de-sistema.tsv"
EXTENSOES="$RAIZ/dados/contratos/nomes-das-extensoes.tsv"
LAR="${SUITE_CASA_REAL:-$HOME}"
FONTES="${NOMES_DOS_APPLETS_FONTES:-$LAR/.local/state/meowsystem/extensoes}"
NAO_SAO_NOME_DE_ICONE='^(explicit|glyph|original|plain|regular|meow-icone-que-nao-existe)-symbolic$'

cut -f1 "$SISTEMA" "$EXTENSOES" | grep -v '^#' | sort -u > "$T/contrato"

pulados=0
for pino in "$RAIZ"/dados/extensoes/*.pino; do
  id="$(basename "$pino" .pino)"
  grep -q '^TIPO="applet"' "$pino" || continue
  commit="$(sed -n 's/^COMMIT="\(.*\)"/\1/p' "$pino")"
  fonte="$FONTES/$id/src"
  if [ ! -d "$fonte" ] || ! grep -q "^commit $commit\$" "$FONTES/$id/carimbo" 2>/dev/null; then
    printf 'pulado: o fonte do applet %s no commit %s não está nesta máquina\n' "$id" "${commit:0:8}"
    pulados=$((pulados + 1))
    continue
  fi
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
  enganam="$(grep -E \
    -e '^(network-vpn-disabled|network-wireless-encrypted|view-reveal)-symbolic:(network-vpn|shield|network-wireless-signal|image-red-eye-symbolic)' \
    -e '^network-wireless-disabled-symbolic:network-wireless-disconnected' \
    -e '^color-select-symbolic:preferences-(color|appearance)' "$mapa")"
  [ -z "$enganam" ] \
    && ok "$pack: nenhum nome mostra o desenho de outra coisa (VPN ligada, sinal cheio, olho riscado, Wi-Fi sem conexão no Wi-Fi desligado, paleta no seletor de cor)" \
    || falha "$pack: alias que mostra o estado errado" "$enganam"
  fora_da_faixa="$(awk -F: '
    $1 ~ /^battery-(caution|low|good|full)(-charging)?-symbolic$/ && match($2, /level-[0-9]+/) {
      n = substr($2, RSTART + 6, RLENGTH - 6) + 0
      if (($1 ~ /caution/ && n > 20) || ($1 ~ /low/ && (n < 20 || n > 29)) \
          || ($1 ~ /good/ && (n < 30 || n > 59)) || ($1 ~ /full/ && n < 60)) print
    }' "$mapa")"
  [ -z "$fora_da_faixa" ] \
    && ok "$pack: cada nome de bateria do UPower mostra um nível dentro da faixa dele (crítica até 20, baixa até 29, boa até 59)" \
    || falha "$pack: nome de bateria do UPower ligado a um nível fora da faixa" "$fora_da_faixa"
done

if [ "$falhas" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$falhas" >&2
  exit 1
fi
[ "$pulados" = 0 ] || { printf 'pulado: %s applet(s) sem o fonte nesta máquina\n' "$pulados"; exit 3; }
exit 0

#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

PINOS_CASA="${EXTENSOES_PINOS:-$RAIZ/assets/extensoes}"
BASE="$MEOW_ESTADO/extensoes"
PINOS_USUARIO="$BASE/usuario"
RASCUNHOS="$BASE/rascunho"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
CONSTRUTOR="$RAIZ/scripts/extensoes_build.sh"

uso() {
  meow_erro "uso: $(basename "$0") ler <url> | adicionar <id> | instalar <id> | atualizar <id> | refazer <id> | refazer-tudo | remover <id> | por <id> | trocar <id> | reiniciar-painel"
  exit "$MEOW_ERRO"
}

_id_valido() { [[ "${1:-}" =~ ^[a-z0-9][a-z0-9-]*$ ]]; }
_da_casa() { [ -f "$PINOS_CASA/$1.pino" ]; }
_do_usuario() { [ -f "$PINOS_USUARIO/$1.pino" ]; }

_campo() { sed -n "s/^$2=\"\(.*\)\"/\1/p" "$1" | head -1; }

_pino_de() { if _da_casa "$1"; then printf '%s' "$PINOS_CASA/$1.pino"; else printf '%s' "$PINOS_USUARIO/$1.pino"; fi; }
_tipo_de() { local t; t="$(_campo "$(_pino_de "$1")" TIPO)"; printf '%s' "${t:-applet}"; }
_e_build() { _da_casa "$1" && [ "$(_tipo_de "$1")" != applet ]; }

_build_chave() {
  local chave
  chave="$(_campo "$PINOS_CASA/$1.pino" CHAVE_DO_CONF)"
  [ -n "$chave" ] || return 0
  meow_conf_definir "$chave" "$2"
}

_lista_atual() {
  local lista="${EXTENSOES:-}"
  [ -n "$lista" ] || lista="$(meow_conf_valor EXTENSOES 2>/dev/null)" || lista=""
  lista="${lista//,/ }"
  if [ -z "$lista" ]; then
    lista="$(EXTENSOES="" "$CONSTRUTOR" --queridas 2>/dev/null | tr '\n' ' ')"
    lista="${lista% }"
  fi
  [ "$lista" = "-" ] && lista=""
  printf '%s' "$lista"
}

_gravar_lista() {
  local lista="$1" saida
  lista="$(printf '%s\n' $lista | awk 'NF && !visto[$0]++' | paste -sd, -)"
  [ -n "$lista" ] || lista="-"
  meow_conf_definir EXTENSOES "$lista"
  saida=$?
  EXTENSOES_NOVA="$lista"
  return "$saida"
}

_com_a_lista() { EXTENSOES="${EXTENSOES_NOVA:-$(_lista_atual | tr ' ' ',')}" "$@"; }

cmd_ler() {
  local url="${1:-}" nome repo id tmp commit data versao bin desktop app_id icones f
  url="${url%/}"
  [[ "$url" =~ ^https://[A-Za-z0-9._~/%:@+-]+$ ]] || { meow_erro "só endereço https"; return 2; }
  repo="${url#https://}"; repo="${repo#*/}"; repo="${repo%.git}"
  [[ "$repo" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || { meow_erro "o endereço não é de um repositório (dono/nome)"; return 2; }
  nome="${repo#*/}"
  id="$(printf '%s' "$nome" | tr 'A-Z_.' 'a-z--' | sed 's/^cosmic-ext-applet-//;s/^cosmic-applet-//;s/[^a-z0-9-]//g;s/^-*//')"
  _id_valido "$id" || { meow_erro "não consegui tirar um nome do endereço"; return 2; }
  _da_casa "$id" && { meow_erro "$id já é uma extensão da casa"; return 2; }
  tmp="$(mktemp -d)" || return "$MEOW_ERRO"
  if ! timeout 180 git clone -q --depth 1 "$url" "$tmp/r" 2>"$tmp/erro"; then
    meow_erro "não consegui ler o repositório: $(head -c 200 "$tmp/erro" | tr '\n' ' ')"
    rm -rf "$tmp"; return 3
  fi
  commit="$(git -C "$tmp/r" rev-parse HEAD)"
  data="$(git -C "$tmp/r" log -1 --format=%cd --date=format:%d/%m/%Y)"
  versao="$(sed -n '/^\[package\]/,/^\[/{s/^version *= *"\(.*\)"/\1/p}' "$tmp/r/Cargo.toml" 2>/dev/null | head -1)"
  bin="$(sed -n '/^\[\[bin\]\]/,/^\[/{s/^name *= *"\(.*\)"/\1/p}' "$tmp/r/Cargo.toml" 2>/dev/null | head -1)"
  [ -n "$bin" ] || bin="$(sed -n '/^\[package\]/,/^\[/{s/^name *= *"\(.*\)"/\1/p}' "$tmp/r/Cargo.toml" 2>/dev/null | head -1)"
  desktop=""
  while IFS= read -r f; do
    f="${f#"$tmp/r/"}"
    if grep -qs '^X-CosmicApplet=true' "$tmp/r/$f"; then desktop="$f"; break; fi
    [ -n "$desktop" ] || desktop="$f"
  done < <(find "$tmp/r" -maxdepth 3 \( -name '*.desktop' -o -name '*.desktop.in' \) -not -path '*/target/*' -not -path '*/.git/*' | sort)
  if [ -z "$bin" ] || [ -z "$desktop" ] || ! grep -qs '^X-CosmicApplet=true' "$tmp/r/$desktop"; then
    meow_erro "não achei um applet do COSMIC nesse repositório"
    rm -rf "$tmp"; return 4
  fi
  app_id="$(basename "$desktop")"; app_id="${app_id%.in}"; app_id="${app_id%.desktop}"
  [[ "$bin" =~ ^[A-Za-z0-9._-]+$ ]] && [[ "$app_id" =~ ^[A-Za-z0-9._-]+$ ]] || { meow_erro "nomes fora do padrão"; rm -rf "$tmp"; return 4; }
  icones=""
  while IFS= read -r f; do
    f="${f#"$tmp/r/"}"
    [[ "$f" =~ ^[A-Za-z0-9._@-][A-Za-z0-9._@/-]*$ ]] || continue
    icones="${icones:+$icones }$f:scalable/apps"
  done < <(find "$tmp/r" -maxdepth 4 -name "$app_id*.svg" -not -path '*/target/*' -not -path '*/.git/*' | sort)
  mkdir -p "$RASCUNHOS" "$PINOS_USUARIO" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  printf 'ORDEM=99\nNOME="%s"\nDESCRICAO=""\nURL="%s"\nCOMMIT="%s"\nVERSAO="%s"\nLIBCOSMIC=""\nAPP_ID="%s"\nBIN="%s"\nDESKTOP="%s"\nICONES="%s"\nSUBSTITUI=""\nLEGADO=""\nMIGRA_ESTADO=""\nTEMA=""\nUPSTREAM="%s"\nDATA="%s"\n' \
    "$nome" "$url" "$commit" "${versao:-0}" "$app_id" "$bin" "$desktop" "$icones" "${url%.git}" "$data" > "$RASCUNHOS/$id.pino"
  rm -rf "$tmp"
  printf 'id=%s\nnome=%s\nrepo=%s\nurl=%s\ncommit=%s\ndata=%s\nversao=%s\nsubstitui=\n' \
    "$id" "$nome" "$repo" "$url" "$commit" "$data" "${versao:-0}"
  return "$MEOW_OK"
}

cmd_adicionar() {
  local id="${1:-}"
  _id_valido "$id" || uso
  [ -f "$RASCUNHOS/$id.pino" ] || { meow_erro "não há ficha lida para $id: leia o endereço antes"; return "$MEOW_ERRO"; }
  mkdir -p "$PINOS_USUARIO" || return "$MEOW_ERRO"
  mv -f "$RASCUNHOS/$id.pino" "$PINOS_USUARIO/$id.pino" || return "$MEOW_ERRO"
  meow_ok "$id entrou na lista das suas extensões"
  return "$MEOW_OK"
}

cmd_instalar() {
  local id="${1:-}"
  _id_valido "$id" || uso
  if _e_build "$id"; then
    _build_chave "$id" sim
    EXTENSOES_COMPILAR=1 "$CONSTRUTOR" "$id" --aplicar
    return $?
  fi
  if _da_casa "$id"; then
    _gravar_lista "$(_lista_atual) $id"
    _com_a_lista env EXTENSOES_COMPILAR=1 "$CONSTRUTOR" "$id" --aplicar
    return $?
  fi
  _do_usuario "$id" || { meow_erro "não conheço a extensão $id"; return "$MEOW_ERRO"; }
  EXTENSOES_COMPILAR=1 "$CONSTRUTOR" "$id" --aplicar
}

cmd_atualizar() {
  local id="${1:-}"
  _id_valido "$id" || uso
  if _da_casa "$id"; then
    EXTENSOES_COMPILAR=1 "$CONSTRUTOR" "$id" --aplicar
  else
    EXTENSOES_COMPILAR=1 "$CONSTRUTOR" "$id" --atualizar
  fi
}

cmd_refazer() {
  local id="${1:-}"
  _id_valido "$id" || uso
  _da_casa "$id" || _do_usuario "$id" || { meow_erro "não conheço a extensão $id"; return "$MEOW_ERRO"; }
  if _e_build "$id"; then
    EXTENSOES_REFAZER=1 EXTENSOES_COMPILAR=1 "$CONSTRUTOR" "$id" --aplicar
    return $?
  fi
  rm -f "$BASE/$id/carimbo"
  EXTENSOES_COMPILAR=1 "$CONSTRUTOR" "$id" --aplicar
}

_ids_instalados() {
  local f id
  for f in "$PINOS_CASA"/*.pino "$PINOS_USUARIO"/*.pino; do
    [ -f "$f" ] || continue
    id="$(basename "$f" .pino)"
    if _e_build "$id"; then
      _quer_build "$id" && printf '%s\n' "$id"
      continue
    fi
    "$CONSTRUTOR" "$id" --estado 2>/dev/null | grep -qx 'instalada=sim' && printf '%s\n' "$id"
  done
}

_quer_build() {
  local chave valor
  chave="$(_campo "$PINOS_CASA/$1.pino" CHAVE_DO_CONF)"
  [ -n "$chave" ] || return 0
  valor="${!chave:-}"
  [ -n "$valor" ] || valor="$(meow_conf_valor "$chave" 2>/dev/null)" || valor=sim
  [ "$valor" != nao ]
}

cmd_refazer_tudo() {
  local rc geral="$MEOW_OK" id
  for id in $(_ids_instalados); do
    cmd_refazer "$id"; rc=$?
    case "$rc" in 0|1|3) ;; *) geral="$MEOW_ERRO" ;; esac
  done
  return "$geral"
}

cmd_remover() {
  local id="${1:-}" lista novo="" x rc
  _id_valido "$id" || uso
  if _e_build "$id"; then
    _build_chave "$id" nao
    "$CONSTRUTOR" "$id" --reverter
    return $?
  fi
  if _da_casa "$id"; then
    lista="$(_lista_atual)"
    for x in $lista; do [ "$x" = "$id" ] || novo="${novo:+$novo }$x"; done
    _gravar_lista "$novo"
    "$CONSTRUTOR" "$id" --reverter; rc=$?
    return "$rc"
  fi
  _do_usuario "$id" || { meow_erro "não conheço a extensão $id"; return "$MEOW_ERRO"; }
  "$CONSTRUTOR" "$id" --reverter; rc=$?
  rm -f "$PINOS_USUARIO/$id.pino"
  return "$rc"
}

_arquivos_do_painel() {
  local dir arq
  for dir in "$CONFIG"/cosmic/com.system76.CosmicPanel.Panel "$CONFIG"/cosmic/com.system76.CosmicPanel.Dock; do
    for arq in "$dir"/v*/plugins_wings "$dir"/v*/plugins_center; do
      [ -f "$arq" ] && printf '%s\n' "$arq"
    done
  done
}

_app_id_de() { _campo "$(_pino_de "$1")" APP_ID; }

_painel_tem() {
  local arq
  while IFS= read -r arq; do grep -qs "\"$1\"" "$arq" && return 0; done < <(_arquivos_do_painel)
  return 1
}

_asa_do_trocado() {
  local velho arq
  for velho in $(_campo "$(_pino_de "$1")" SUBSTITUI); do
    while IFS= read -r arq; do
      grep -qs "\"$velho\"" "$arq" || continue
      arq="${arq%/*}/plugins_wings"
      [ -f "$arq" ] && { printf '%s' "$arq"; return 0; }
    done < <(_arquivos_do_painel)
  done
  _arquivos_do_painel | grep 'CosmicPanel\.Panel/.*plugins_wings$' | head -1
}

cmd_por() {
  local id="${1:-}" app arq texto novo
  _id_valido "$id" || uso
  app="$(_app_id_de "$id")"
  [ -n "$app" ] || { meow_erro "não conheço a extensão $id"; return "$MEOW_ERRO"; }
  if _painel_tem "$app"; then
    meow_pula "$app já está no painel"
    return "$MEOW_OK"
  fi
  arq="$(_asa_do_trocado "$id")"
  [ -n "$arq" ] || { meow_erro "não achei a configuração do painel"; return "$MEOW_ERRO"; }
  texto="$(cat "$arq")"
  case "$texto" in
    *']))') novo="${texto%']))'}    \"$app\",
]))" ;;
    *) meow_erro "o formato do painel mudou: não mexo nele"; return "$MEOW_ERRO" ;;
  esac
  meow_escrever "$arq" "$novo" 644
  case $? in
    2) meow_erro "não consegui escrever $arq"; return "$MEOW_ERRO" ;;
  esac
  meow_ok "$app entrou no fim do painel"
  return "$MEOW_DIVERGENTE"
}

cmd_trocar() {
  local id="${1:-}" app antigo arq novo mexeu=1 estado
  _id_valido "$id" || uso
  app="$(_app_id_de "$id")"
  estado="$("$CONSTRUTOR" "$id" --estado 2>/dev/null)"
  antigo="$(printf '%s\n' "$estado" | sed -n 's/^troca=//p')"
  [ -n "$app" ] && [ -n "$antigo" ] || { meow_pula "não há o que trocar em $id"; return "$MEOW_OK"; }
  while IFS= read -r arq; do
    grep -qs "\"$antigo\"" "$arq" || continue
    if grep -qs "\"$app\"" "$arq"; then
      novo="$(grep -v "\"$antigo\"" "$arq")"
    else
      novo="$(sed "s|\"$antigo\"|\"$app\"|" "$arq")"
    fi
    meow_escrever "$arq" "$novo" 644
    [ $? = 2 ] && { meow_erro "não consegui escrever $arq"; return "$MEOW_ERRO"; }
    mexeu=0
  done < <(_arquivos_do_painel)
  [ "$mexeu" = 0 ] || { meow_pula "o painel não cita $antigo"; return "$MEOW_OK"; }
  meow_ok "$app no lugar de $antigo, na mesma posição do painel"
  return "$MEOW_DIVERGENTE"
}

cmd_reiniciar_painel() {
  local rc
  MEOW_QUEM_RECICLA="extensoes reiniciar-painel" meow_tela_reler; rc=$?
  case "$rc" in 3|4) return "$MEOW_OK" ;; esac
  return "$rc"
}

main() {
  local verbo="${1:-}"
  [ -n "$verbo" ] || uso
  shift
  case "$verbo" in
    ler) cmd_ler "$@" ;;
    adicionar) cmd_adicionar "$@" ;;
    instalar) cmd_instalar "$@" ;;
    atualizar) cmd_atualizar "$@" ;;
    refazer) cmd_refazer "$@" ;;
    refazer-tudo) cmd_refazer_tudo ;;
    remover) cmd_remover "$@" ;;
    por) cmd_por "$@" ;;
    trocar) cmd_trocar "$@" ;;
    reiniciar-painel) cmd_reiniciar_painel ;;
    *) uso ;;
  esac
}

main "$@"

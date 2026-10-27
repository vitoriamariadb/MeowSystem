#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

RECEITA="$RAIZ/src/applets/now-playing"
PATCH="$RECEITA/0001-meow-capa-cor-controles.patch"
PINO="$RECEITA/PINO"

ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/midia"
ARVORE="$ESTADO/src"
ALVO="$ESTADO/target"
CARIMBO="$ESTADO/carimbo"

BINARIO="$HOME/.local/bin/meow-applet-now-playing"

MIDIA="${MIDIA:-sim}"
COMPILAR="${MIDIA_COMPILAR:-0}"

. "$RAIZ/scripts/applet_pino.sh"
_alvo_rev() { ap_alvo midia "${LIBCOSMIC:-}"; }

CONFERIR=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1
[ "$CONFERIR" = 1 ] && AP_SO_LER=1

_sha() { sha256sum -- "$1" 2>/dev/null | cut -d' ' -f1; }

_rustc_versao() {
  meow_seco && return 0
  meow_tem rustc || return 0
  rustc -V 2>/dev/null
}

_pino_ler() {
  [ -f "$PINO" ] || return 1
  # shellcheck source=/dev/null
  . "$PINO"
  [ -n "${URL:-}" ] && [ -n "${COMMIT:-}" ]
}

_carimbo_vivo() {
  local alvo; alvo="$(_alvo_rev)"
  printf 'patch %s\ncommit %s\nbinario %s\nrustc %s\n' \
    "$(_sha "$PATCH")" "${COMMIT:-}" "$(_sha "$BINARIO")" "$(_rustc_versao)"
  [ -z "${LIBCOSMIC:-}" ] || [ "$alvo" = "$LIBCOSMIC" ] || printf 'libcosmic %s\n' "$alvo"
}

_carimbo_bate() {
  [ -f "$CARIMBO" ] || return 1
  local campo vivo gravado
  while read -r campo vivo; do
    [ -z "$vivo" ] && continue
    gravado="$(sed -n "s/^$campo //p" "$CARIMBO" | head -1)"
    [ "$gravado" = "$vivo" ] || return 1
  done <<< "$(_carimbo_vivo)"
  return 0
}

_pronto() {
  if [ ! -f "$PATCH" ] || [ ! -f "$PINO" ]; then
    meow_erro "falta $RECEITA (patch ou PINO) — repositório incompleto"
    return "$MEOW_ERRO"
  fi
  _pino_ler || { meow_erro "o PINO não tem URL/COMMIT"; return "$MEOW_ERRO"; }
  return "$MEOW_OK"
}

_conferir() {
  if [ ! -x "$BINARIO" ]; then
    meow_muda "o applet de mídia ainda não foi compilado ($BINARIO)"
    return "$MEOW_DIVERGENTE"
  fi
  if ! _carimbo_bate; then
    meow_muda "o applet de mídia instalado não é o desta receita (patch, commit ou rustc mudaram)"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "applet de mídia $(_sha "$BINARIO" | cut -c1-8) já é o do repositório"
  return "$MEOW_OK"
}

_arvore_no_pino() {
  if [ ! -d "$ARVORE/.git" ]; then
    rm -rf "$ARVORE"
    mkdir -p "$(dirname "$ARVORE")" || return "$MEOW_ERRO"
    git clone -q --depth 50 "$URL" "$ARVORE" || {
      meow_aviso "não consegui clonar $URL (sem rede?) — fica para o próximo ciclo"
      return "$MEOW_SEM_DEPENDENCIA"
    }
  fi

  if [ "$(git -C "$ARVORE" rev-parse HEAD 2>/dev/null)" != "$COMMIT" ]; then
    git -C "$ARVORE" checkout -q "$COMMIT" 2>/dev/null || {
      git -C "$ARVORE" fetch -q --unshallow 2>/dev/null || git -C "$ARVORE" fetch -q --all 2>/dev/null
      git -C "$ARVORE" checkout -q "$COMMIT" 2>/dev/null || {
        meow_erro "o commit $COMMIT não existe em $URL — confira o PINO"
        return "$MEOW_ERRO"
      }
    }
  fi
  return "$MEOW_OK"
}

_aplicar() {
  _conferir >/dev/null 2>&1 && { _conferir; return $?; }

  if [ "$COMPILAR" != "1" ]; then
    meow_pula "o applet de mídia ainda não foi compilado — o conserto do doctor e o instalador compilam"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_garantir_cargo || true
  if ! meow_tem cargo; then
    meow_pula "sem cargo nesta máquina — o applet de mídia fica de fora"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_destino_permitido "$BINARIO" || return "$MEOW_ERRO"
  mkdir -p "$ESTADO" || { meow_erro "não consegui criar $ESTADO"; return "$MEOW_ERRO"; }

  _arvore_no_pino
  case $? in
    2) return "$MEOW_ERRO" ;;
    3) return "$MEOW_SEM_DEPENDENCIA" ;;
  esac

  git -C "$ARVORE" checkout -q -- . || { meow_erro "não consegui limpar a árvore"; return "$MEOW_ERRO"; }
  if ! git -C "$ARVORE" apply "$PATCH"; then
    meow_erro "o patch não aplica em $COMMIT — o upstream mexeu nos arquivos que tocamos"
    meow_info "  regenere: git -C $ARVORE diff > $PATCH"
    return "$MEOW_ERRO"
  fi

  meow_info "compilando o applet de mídia (a primeira vez leva ~2min)"
  local alvo_rev compilou=0
  alvo_rev="$(_alvo_rev)"
  if [ -n "${LIBCOSMIC:-}" ] && [ "$alvo_rev" != "$LIBCOSMIC" ]; then
    meow_info "  contra o libcosmic do painel instalado (${alvo_rev:0:7})"
    if cargo update -q --manifest-path "$ARVORE/Cargo.toml" -p libcosmic --precise "$alvo_rev" >/dev/null 2>&1 \
       && CARGO_TARGET_DIR="$ALVO" cargo build --release \
            --manifest-path "$ARVORE/Cargo.toml" >/dev/null 2>&1; then
      compilou=1
    else
      ap_falhou midia "$alvo_rev"
      git -C "$ARVORE" checkout -q -- Cargo.lock 2>/dev/null
      meow_aviso "o applet de mídia não compila no libcosmic ${alvo_rev:0:7} do painel — volta ao pino ${LIBCOSMIC:0:7}"
    fi
  fi
  if [ "$compilou" = 0 ] && ! CARGO_TARGET_DIR="$ALVO" cargo build --release --locked \
        --manifest-path "$ARVORE/Cargo.toml" >"$ESTADO/compilar.log" 2>&1; then
    meow_erro "o cargo falhou — $(meow_motivo_do_cargo "$ESTADO/compilar.log")"
    meow_info "  o registro está em $ESTADO/compilar.log"
    meow_info "  o binário anterior segue instalado e funcionando; nada foi trocado"
    return "$MEOW_ERRO"
  fi

  local recem="$ALVO/release/cosmic-ext-applet-now-playing"
  [ -x "$recem" ] || { meow_erro "o cargo terminou e não deixou binário em $recem"; return "$MEOW_ERRO"; }

  install -Dm0755 "$recem" "$BINARIO" || { meow_erro "não consegui instalar $BINARIO"; return "$MEOW_ERRO"; }
  strip "$BINARIO" 2>/dev/null

  meow_manifesto_registrar "$BINARIO"

  if [ "$compilou" = 1 ]; then ap_compilou midia "$alvo_rev"; else ap_compilou midia "${LIBCOSMIC:-}"; fi
  _carimbo_vivo > "$CARIMBO" || { meow_erro "não consegui gravar o carimbo"; return "$MEOW_ERRO"; }
  meow_ok "applet de mídia compilado e instalado ($(_sha "$BINARIO" | cut -c1-8))"
  return "$MEOW_DIVERGENTE"
}

main() {
  if [ "$MIDIA" != "sim" ]; then
    meow_pula "MIDIA=\"$MIDIA\" no meow.conf — o applet de mídia não é compilado"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  _pronto || return $?
  if [ "$CONFERIR" = 1 ]; then _conferir; else _aplicar; fi
}

main "$@"

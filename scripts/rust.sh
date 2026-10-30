#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

PINO="${MEOW_RUSTUP_PINO:-$MEOW_RAIZ/assets/rust/rustup.pino}"
CARGO_DIR="${CARGO_HOME:-$HOME/.cargo}"
RUSTUP_DIR="${RUSTUP_HOME:-$HOME/.rustup}"
TROUXE="$MEOW_ESTADO/rust/trouxe"

_rs_pino() {
  VERSAO="" URL="" RUST_MINIMO="" TAMANHO=""
  # shellcheck disable=SC1090
  [ -f "$PINO" ] && . "$PINO"
  [ -n "$VERSAO" ] && [ -n "$URL" ] && [ -n "$RUST_MINIMO" ] \
    || { meow_erro "o pino do rustup está incompleto: $PINO"; return 1; }
}

_rs_precisa() {
  [ "${RUST_PRECISA:-}" = sim ] && return 0
  [ -n "$(meow_grupos_de_compilar)" ]
}

_rs_versao() {
  local v
  v="$( (cd / && RUSTUP_AUTO_INSTALL=0 rustc --version) 2>/dev/null | awk '{print $2}')"
  printf '%s' "${v%%-*}"
}

_rs_rotulo() {
  local v
  v="$(_rs_versao)"
  printf 'rust%s' "${v:+ $v}"
}

_rs_basta() {
  local v
  meow_tem cargo || return 1
  v="$(_rs_versao)"
  [ -n "$v" ] || return 0
  [ "$(printf '%s\n%s\n' "$RUST_MINIMO" "$v" | sort -V | head -n1)" = "$RUST_MINIMO" ]
}

_rs_fato() {
  if ! meow_tem cargo; then
    printf 'falta o rust (cargo), e o que compila pede o %s ou mais novo' "$RUST_MINIMO"
  else
    printf 'o rust daqui é o %s, e o que compila pede o %s ou mais novo' "$(_rs_versao)" "$RUST_MINIMO"
  fi
}

conferir() {
  _rs_pino || return "$MEOW_ERRO"
  meow_rust_no_path
  if ! _rs_precisa; then
    echo "nada compila nesta casa: o rust não faz falta"
    return "$MEOW_OK"
  fi
  if _rs_basta; then
    echo "$(_rs_rotulo) em $(command -v cargo | sed "s#^$HOME#~#")"
    return "$MEOW_OK"
  fi
  echo "$(_rs_fato) — o conserto baixa o rustup $VERSAO pinado"
  return "$MEOW_DIVERGENTE"
}

_rs_retrato() {
  [ -d "$CARGO_DIR" ] || return 0
  find "$CARGO_DIR" -mindepth 1 -maxdepth 2 2>/dev/null | LC_ALL=C sort
}

_rs_anotar() {
  mkdir -p "${TROUXE%/*}" && printf '%s\n' "$1" >> "$TROUXE"
}

_rs_do_rustup_existente() {
  meow_info "BAIXA DA INTERNET: o toolchain stable, pelo rustup que já estava aqui"
  rustup toolchain install stable --profile minimal --no-self-update >/dev/null 2>&1 || return 1
  [ -n "$(_rs_versao)" ] || rustup default stable >/dev/null 2>&1 || return 1
  return 0
}

_rs_baixar_e_rodar() {
  local arq sha alvo tmp antes depois novo
  arq="$(uname -m)"
  sha="SHA256_$arq"; sha="${!sha:-}"
  [ -n "$sha" ] || { meow_pula "o rustup pinado não tem binário para $arq — o rust fica de fora"; return "$MEOW_SEM_DEPENDENCIA"; }
  alvo="${URL//@ALVO@/$arq-unknown-linux-gnu}"
  [ "${MEOW_SEM_REDE:-0}" = 1 ] && { meow_pula "sem rede (MEOW_SEM_REDE=1): o rustup não baixa agora"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem curl || { meow_pula "sem curl para baixar o rust — a próxima passada tenta de novo"; return "$MEOW_SEM_DEPENDENCIA"; }
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/meow-rustup.XXXXXX")" || return "$MEOW_ERRO"
  meow_info "BAIXA DA INTERNET: o rustup $VERSAO (${TAMANHO:-~20 MB}), e com ele o rust stable, em ${CARGO_DIR/#$HOME/\~} e ${RUSTUP_DIR/#$HOME/\~}"
  if ! curl --proto '=https' --tlsv1.2 -sSfL --connect-timeout 15 --max-time 300 --retry 3 --retry-delay 2 \
       -o "$tmp/rustup-init" "$alvo" 2>/dev/null; then
    rm -rf "$tmp"
    meow_pula "sem rede para baixar o rustup — a próxima passada tenta de novo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! echo "$sha  $tmp/rustup-init" | sha256sum --status -c - 2>/dev/null; then
    rm -rf "$tmp"
    meow_erro "o rustup-init baixado não bate com o sha256 pinado de $VERSAO — nada rodou"
    return "$MEOW_ERRO"
  fi
  chmod 755 "$tmp/rustup-init"

  local d
  for d in "$CARGO_DIR" "$RUSTUP_DIR"; do
    if [ ! -e "$d" ]; then
      meow_guardar_pasta "$d"
      _rs_anotar "$d"
    fi
  done
  antes="$(_rs_retrato)"
  mkdir -p "$MEOW_ESTADO/rust"
  if ! CARGO_HOME="$CARGO_DIR" RUSTUP_HOME="$RUSTUP_DIR" RUSTUP_INIT_SKIP_PATH_CHECK=yes \
       "$tmp/rustup-init" -y --no-modify-path --profile minimal --default-toolchain stable \
       >"$MEOW_ESTADO/rust/rustup-init.log" 2>&1; then
    rm -rf "$tmp"
    meow_erro "o rustup-init não terminou (registro: $MEOW_ESTADO/rust/rustup-init.log)"
    return "$MEOW_ERRO"
  fi
  rm -rf "$tmp"
  depois="$(_rs_retrato)"
  while IFS= read -r novo; do
    [ -n "$novo" ] || continue
    grep -qxF -- "$CARGO_DIR" "$TROUXE" 2>/dev/null && break
    grep -qxF -- "${novo%/*}" <(comm -13 <(printf '%s\n' "$antes") <(printf '%s\n' "$depois")) && continue
    if [ -d "$novo" ]; then meow_marcar_pasta_nova "$novo"; else meow_marcar_novo "$novo"; fi
    _rs_anotar "$novo"
  done < <(comm -13 <(printf '%s\n' "$antes") <(printf '%s\n' "$depois"))
  return "$MEOW_OK"
}

aplicar() {
  _rs_pino || return "$MEOW_ERRO"
  meow_rust_no_path
  _rs_precisa || { meow_ok "nada compila nesta casa: o rust não faz falta"; return "$MEOW_OK"; }
  if _rs_basta; then
    meow_ok "$(_rs_rotulo) — basta para o que compila"
    return "$MEOW_OK"
  fi
  meow_info "$(_rs_fato)"
  if meow_seco; then
    meow_muda "baixaria o rustup $VERSAO pinado (BAIXA DA INTERNET) e instalaria o rust stable em ${CARGO_DIR/#$HOME/\~}"
    return "$MEOW_DIVERGENTE"
  fi
  local rc
  if meow_tem rustup; then
    _rs_do_rustup_existente || { meow_pula "o rustup daqui não trouxe o stable agora (sem rede?) — a próxima passada tenta de novo"; return "$MEOW_SEM_DEPENDENCIA"; }
  else
    _rs_baixar_e_rodar; rc=$?
    [ "$rc" = 0 ] || return "$rc"
  fi
  meow_rust_no_path
  if _rs_basta; then
    meow_ok "$(_rs_rotulo) instalado em ${CARGO_DIR/#$HOME/\~}"
    return "$MEOW_DIVERGENTE"
  fi
  meow_erro "$(_rs_fato), mesmo depois do rustup"
  return "$MEOW_ERRO"
}

remover() {
  [ -f "$TROUXE" ] || { meow_ok "o MeowSystem não trouxe rust aqui: nada a tirar"; return "$MEOW_OK"; }
  local alvo n=0
  while IFS= read -r alvo; do
    case "$alvo" in "$HOME"/?*) ;; *) continue ;; esac
    [ -e "$alvo" ] || [ -L "$alvo" ] || continue
    if meow_seco; then meow_muda "tiraria ${alvo/#$HOME/\~}"; n=$((n + 1)); continue; fi
    rm -rf -- "$alvo" && meow_muda "saiu: ${alvo/#$HOME/\~}" && n=$((n + 1))
  done < <(tac "$TROUXE")
  meow_seco || rm -f "$TROUXE"
  [ "$n" -gt 0 ] && return "$MEOW_DIVERGENTE"
  return "$MEOW_OK"
}

case "${1:-}" in
  conferir) conferir ;;
  aplicar)  aplicar ;;
  remover)  remover ;;
  *) meow_erro "uso: $(basename "$0") conferir|aplicar|remover"; exit "$MEOW_ERRO" ;;
esac

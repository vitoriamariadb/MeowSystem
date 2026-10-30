#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

SPICE_VERSAO="${SPICE_VERSAO:-2.45.1}"
SPICE_DIR="${SPICE_DIR:-$HOME/.spicetify}"
SPICE_BIN="$SPICE_DIR/spicetify"
SPICE_RELEASES="${SPICE_RELEASES:-https://github.com/spicetify/cli/releases/download}"

SPICE_PREFS_FLATPAK="${SPICE_PREFS_FLATPAK:-$HOME/.var/app/com.spotify.Client/config/spotify/prefs}"

_spice_achar() {
  [ -x "$SPICE_BIN" ] && { printf '%s' "$SPICE_BIN"; return 0; }
  command -v spicetify 2>/dev/null && return 0
  return 1
}

_spice_arquitetura() {
  case "$(uname -m)" in
    x86_64|amd64)  printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    *)             return 1 ;;
  esac
}

cmd_conferir() {
  local achado
  if achado="$(_spice_achar)"; then
    local v; v="$("$achado" --version 2>/dev/null || printf 'desconhecida')"
    meow_ok "spicetify $v em $achado"
    return "$MEOW_OK"
  fi
  meow_muda "o spicetify não está instalado — é ele que pinta o Spotify"
  return "$MEOW_DIVERGENTE"
}

cmd_instalar() {
  local achado
  if achado="$(_spice_achar)"; then
    local v; v="$("$achado" --version 2>/dev/null || printf 'desconhecida')"
    meow_ok "spicetify $v já está em $achado — nada a fazer"
    return "$MEOW_OK"
  fi

  meow_tem curl || { meow_pula "sem curl — não dá para baixar o spicetify"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem tar  || { meow_pula "sem tar — não dá para abrir o release";      return "$MEOW_SEM_DEPENDENCIA"; }

  local arq
  arq="$(_spice_arquitetura)" || {
    meow_erro "arquitetura sem release de linux no spicetify: $(uname -m)"
    meow_info "o projeto publica amd64 e arm64; instale à mão se a sua for outra"
    return "$MEOW_ERRO"
  }

  local nome="spicetify-$SPICE_VERSAO-linux-$arq.tar.gz"
  local url="$SPICE_RELEASES/v$SPICE_VERSAO/$nome"

  if meow_seco; then
    meow_muda "baixaria $url"
    meow_muda "e abriria o binário em $SPICE_DIR (nenhum byte escrito neste ensaio)"
    return "$MEOW_OK"
  fi

  local tmp
  tmp="$(mktemp -d)" || { meow_erro "não consegui criar diretório temporário"; return "$MEOW_ERRO"; }
  trap 'rm -rf "$tmp"' RETURN

  meow_info "baixando spicetify $SPICE_VERSAO ($arq)"
  if ! curl -fsSL -o "$tmp/$nome" "$url"; then
    meow_erro "falhou o download de $url"
    meow_info "confira a rede, ou se a versão $SPICE_VERSAO ainda tem release publicado"
    return "$MEOW_ERRO"
  fi

  mkdir -p "$SPICE_DIR" || { meow_erro "não consegui criar $SPICE_DIR"; return "$MEOW_ERRO"; }
  if ! tar -xzf "$tmp/$nome" -C "$SPICE_DIR"; then
    meow_erro "o tarball baixou mas não abriu — arquivo truncado ou corrompido"
    return "$MEOW_ERRO"
  fi

  if [ ! -x "$SPICE_BIN" ]; then
    meow_erro "o tarball abriu e não há binário executável em $SPICE_BIN"
    return "$MEOW_ERRO"
  fi

  meow_ok "spicetify $("$SPICE_BIN" --version 2>/dev/null) instalado em $SPICE_DIR"
  meow_info "nenhum arquivo de shell foi tocado: quem acha o binário é o próprio módulo do Spotify"
  cmd_prefs
  return "$MEOW_OK"
}

cmd_prefs() {
  local cli
  cli="$(_spice_achar)" || { meow_pula "sem spicetify instalado — nada a configurar"; return "$MEOW_SEM_DEPENDENCIA"; }

  if [ ! -f "$SPICE_PREFS_FLATPAK" ]; then
    meow_pula "não achei o prefs do Spotify flatpak em $SPICE_PREFS_FLATPAK"
    meow_info "abra o Spotify uma vez: ele cria o arquivo no primeiro início"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if meow_seco; then
    meow_muda "apontaria o prefs_path do spicetify para $SPICE_PREFS_FLATPAK"
    return "$MEOW_OK"
  fi

  if ! "$cli" config prefs_path "$SPICE_PREFS_FLATPAK" >/dev/null 2>&1; then
    meow_erro "o spicetify recusou gravar prefs_path"
    return "$MEOW_ERRO"
  fi
  meow_ok "prefs_path do spicetify aponta para o Spotify flatpak"
  return "$MEOW_OK"
}

case "${1:-conferir}" in
  conferir) cmd_conferir ;;
  instalar) cmd_instalar ;;
  prefs)    cmd_prefs ;;
  *) meow_erro "uso: spicetify_setup.sh {conferir|instalar|prefs}"; exit "$MEOW_ERRO" ;;
esac

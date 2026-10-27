#!/usr/bin/env bash

_SPOT_DIR_MOD="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
_SPOT_ACENTO_PY="$_SPOT_DIR_MOD/acento.py"
_SPOT_PALETA="$(meow_paleta)"

_SPOT_FLAVOR="$(meow_flavor)"
_SPOT_ACENTO="${ACCENT:-mauve}"

_SPOT_CONFIG_DIR="$HOME/.config/spicetify"
_SPOT_INI="$_SPOT_CONFIG_DIR/config-xpui.ini"
_SPOT_NOSSO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/temas-de-apps/spotify/tema-nosso"

meow_app_tema_do_pack spotify.spicetify_tema
_SPOT_TEMA_NOME="$MEOW_APP_TEMA"
_SPOT_TEMA_DE="$MEOW_APP_TEMA_PACK"
_SPOT_NOME_RECUSADO=""
if [ -n "$_SPOT_TEMA_NOME" ] && ! [[ "$_SPOT_TEMA_NOME" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]]; then
  _SPOT_NOME_RECUSADO="$_SPOT_TEMA_NOME"; _SPOT_TEMA_NOME=""
fi
meow_app_tema_do_pack spotify.esquema
_SPOT_ESQUEMA="$MEOW_APP_TEMA"
meow_app_tema_do_pack spotify.acento_no_color_ini
_SPOT_ACENTO_NO_INI="$MEOW_APP_TEMA"

_SPOT_TEMA=""; _SPOT_COLOR_INI=""
if [ -n "$_SPOT_TEMA_NOME" ]; then
  _SPOT_TEMA="$_SPOT_CONFIG_DIR/Themes/$_SPOT_TEMA_NOME"
  _SPOT_COLOR_INI="$_SPOT_TEMA/color.ini"
fi

_SPOT_MP_DIR="$_SPOT_CONFIG_DIR/CustomApps/marketplace"
_SPOT_MP_VERSAO="$_SPOT_MP_DIR/.meow-versao"
_SPOT_MP_RELEASES="https://github.com/spicetify/marketplace/releases"
_SPOT_MARKETPLACE="${SPOTIFY_MARKETPLACE:-sim}"

_spot_cli() {
  if meow_tem spicetify; then command -v spicetify; return 0; fi
  [ -x "$HOME/.spicetify/spicetify" ] && { printf '%s' "$HOME/.spicetify/spicetify"; return 0; }
  return 1
}

_spot_dir() {
  printf '%s' "${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/app/com.spotify.Client/current/active/files/extra/share/spotify"
}

_spot_instalado() {
  local d; d="$(_spot_dir)"
  [ -f "$d/Apps/xpui.spa" ] || [ -d "$d/Apps/xpui" ]
}

_spot_versao() {
  flatpak list --app --columns=application,version 2>/dev/null \
    | awk -F'\t' '$1=="com.spotify.Client"{print $2; exit}'
}

_spot_ini_ler() {
  [ -f "$_SPOT_INI" ] || return 1
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*$/\1/p" \
    "$_SPOT_INI" | head -1
}

_spot_deploy_dir() {
  readlink -f -- "${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/app/com.spotify.Client/current/active" 2>/dev/null
}

_spot_backup_spa() {
  printf '%s' "${XDG_STATE_HOME:-$HOME/.local/state}/spicetify/Backup/xpui.spa"
}

_spot_backup_fresco() {
  local spa dep tspa tdep
  spa="$(_spot_backup_spa)"
  dep="$(_spot_deploy_dir)"
  [ -f "$spa" ] || return 1
  [ -n "$dep" ] && [ -d "$dep" ] || return 1
  tspa="$(stat -c %Y -- "$spa" 2>/dev/null)" || return 1
  tdep="$(stat -c %Y -- "$dep" 2>/dev/null)" || return 1
  [ "$tspa" -ge "$tdep" ]
}

_spot_carimbar_versao() {
  local vi vb texto novo modo tmp
  vi="$(_spot_versao)"
  [ -n "$vi" ] || return "$MEOW_ERRO"
  [ -f "$_SPOT_INI" ] || return "$MEOW_ERRO"
  vb="$(_spot_ini_ler version)"
  [ "$vb" = "$vi" ] && return "$MEOW_OK"

  meow_destino_permitido "$_SPOT_INI" || return "$MEOW_ERRO"
  if meow_seco; then
    meow_muda "carimbaria [Backup] version = $vi no config-xpui.ini (está $vb)"
    return "$MEOW_DIVERGENTE"
  fi

  texto="$(cat -- "$_SPOT_INI")" || return "$MEOW_ERRO"
  novo="$(printf '%s\n' "$texto" | sed "0,/^[[:space:]]*version[[:space:]]*=/s|^\([[:space:]]*version[[:space:]]*=[[:space:]]*\).*\$|\1$vi|")"
  [ -n "$novo" ] || return "$MEOW_ERRO"
  printf '%s\n' "$novo" | grep -qx "[[:space:]]*version[[:space:]]*=[[:space:]]*$vi" || return "$MEOW_ERRO"

  modo="$(stat -c %a -- "$_SPOT_INI" 2>/dev/null)"; modo="${modo:-644}"
  tmp="$(mktemp -p "$(dirname -- "$_SPOT_INI")" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  printf '%s\n' "$novo" > "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod "$modo" "$tmp"
  mv -f "$tmp" "$_SPOT_INI" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"
}

_spot_mp_quer() { [ "$_SPOT_MARKETPLACE" = "sim" ]; }

_spot_mp_registrado() {
  case "|$(_spot_ini_ler custom_apps | tr -d '[:space:]' | tr ',' '|')|" in
    *"|marketplace|"*) return 0 ;;
  esac
  return 1
}

_spot_mp_baixado() {
  [ -d "$_SPOT_MP_DIR" ] && [ -n "$(ls -A "$_SPOT_MP_DIR" 2>/dev/null)" ]
}

_spot_mp_no_disco() { [ -f "$(_spot_dir)/Apps/xpui/spicetify-routes-marketplace.js" ]; }

_spot_mp_instalar() {
  local tag tmp zip
  _spot_mp_baixado && return "$MEOW_OK"

  meow_tem curl  || { meow_pula "sem curl — o Marketplace fica de fora"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem unzip || { meow_pula "sem unzip — o Marketplace fica de fora"; return "$MEOW_SEM_DEPENDENCIA"; }

  if meow_seco; then
    meow_muda "baixaria o Marketplace do spicetify para $_SPOT_MP_DIR"
    return "$MEOW_DIVERGENTE"
  fi

  tag="$(curl -fsSL -H 'Accept: application/json' "$_SPOT_MP_RELEASES/latest" 2>/dev/null \
          | sed -n 's/.*"tag_name":"\([^"]*\)".*/\1/p' | head -1)"
  if [ -z "$tag" ]; then
    meow_aviso "não descobri a versão do Marketplace (sem rede?) — fica para o próximo ciclo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_destino_permitido "$_SPOT_MP_DIR" || return "$MEOW_ERRO"
  tmp="$(mktemp -d)" || return "$MEOW_ERRO"
  zip="$tmp/marketplace.zip"
  if ! curl -fsSL -o "$zip" "$_SPOT_MP_RELEASES/download/$tag/marketplace.zip"; then
    rm -rf "$tmp"
    meow_aviso "o download do Marketplace $tag falhou — fica para o próximo ciclo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! unzip -q -d "$tmp/x" "$zip" 2>/dev/null; then
    rm -rf "$tmp"; meow_erro "o zip do Marketplace veio corrompido"; return "$MEOW_ERRO"
  fi
  if [ ! -d "$tmp/x/marketplace-dist" ]; then
    rm -rf "$tmp"
    meow_erro "o zip do Marketplace mudou de formato (sem marketplace-dist)"
    return "$MEOW_ERRO"
  fi

  mkdir -p "$(dirname -- "$_SPOT_MP_DIR")" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  rm -rf "$_SPOT_MP_DIR"
  mv "$tmp/x/marketplace-dist" "$_SPOT_MP_DIR" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  printf '%s\n' "$tag" > "$_SPOT_MP_VERSAO"
  rm -rf "$tmp"
  meow_ok "Marketplace do spicetify $tag baixado"
  return "$MEOW_DIVERGENTE"
}

_spot_mp_registrar() {
  local cli
  _spot_mp_registrado && return "$MEOW_OK"
  if meow_seco; then
    meow_muda "acrescentaria 'marketplace' ao custom_apps do spicetify"
    return "$MEOW_DIVERGENTE"
  fi
  cli="$(_spot_cli)" || return "$MEOW_ERRO"
  "$cli" config custom_apps marketplace >/dev/null 2>&1 || {
    meow_erro "não consegui acrescentar 'marketplace' ao custom_apps"
    return "$MEOW_ERRO"
  }
  _spot_mp_registrado || { meow_erro "o spicetify não gravou o custom_apps"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"
}

_spot_alvo_seguro() {
  local themes alvo
  themes="$(readlink -m -- "$_SPOT_CONFIG_DIR/Themes")"
  alvo="$(readlink -m -- "$_SPOT_TEMA")"
  if [ -n "$_SPOT_TEMA_NOME" ] && [ "$alvo" != "$themes" ] && [ "$(dirname -- "$alvo")" = "$themes" ]; then
    return 0
  fi
  meow_erro "recusado: '$_SPOT_TEMA' não é uma pasta de $_SPOT_CONFIG_DIR/Themes"
  return 1
}

_spot_tema_do_pack() {
  local ini="$1" dir tmp f
  dir="$(dirname -- "$ini")"
  if meow_seco; then
    meow_muda "poria o tema '$_SPOT_TEMA_NOME' do spicetify, que vem no pack, em $_SPOT_TEMA"
    return "$MEOW_DIVERGENTE"
  fi
  meow_destino_permitido "$_SPOT_TEMA" || return "$MEOW_ERRO"
  _spot_alvo_seguro || return "$MEOW_ERRO"
  mkdir -p "$(dirname -- "$_SPOT_TEMA")" || return "$MEOW_ERRO"
  tmp="$(mktemp -d -p "$(dirname -- "$_SPOT_TEMA")" ".meow-spot-tema.XXXXXX")" || return "$MEOW_ERRO"
  chmod 755 "$tmp"
  while IFS= read -r -d '' f; do
    f="${f#"$dir"/}"
    mkdir -p -- "$tmp/$(dirname -- "$f")" && cp -- "$dir/$f" "$tmp/$f" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  done < <(find "$dir" -type f ! -type l -print0)
  [ -f "$tmp/color.ini" ] || { rm -rf "$tmp"; meow_erro "o tema do pack não tem color.ini"; return "$MEOW_ERRO"; }
  printf 'pack %s: %s\ncopiado pelo MeowSystem em %s\n' "${_SPOT_TEMA_DE:-?}" "$dir" "$(date -Iseconds)" \
    > "$tmp/PROCEDENCIA.txt" 2>/dev/null
  rm -rf "$_SPOT_TEMA"
  mv -f "$tmp" "$_SPOT_TEMA" || { rm -rf "$tmp"; meow_erro "não consegui pôr o tema em $_SPOT_TEMA"; return "$MEOW_ERRO"; }
  meow_ok "tema '$_SPOT_TEMA_NOME' do spicetify posto em $_SPOT_TEMA, do pack ${_SPOT_TEMA_DE:-ativo}"
  return "$MEOW_DIVERGENTE"
}

_spot_tema_baixar() {
  local tmp origem repo commit pasta tar
  [ -n "$_SPOT_COLOR_INI" ] || return "$MEOW_SEM_DEPENDENCIA"
  [ -f "$_SPOT_COLOR_INI" ] && return "$MEOW_OK"

  meow_app_tema_do_pack spotify.arquivo
  if [ -n "$MEOW_APP_TEMA" ]; then
    _spot_tema_do_pack "$MEOW_APP_TEMA"
    return $?
  fi

  meow_app_tema_do_pack spotify.origem.repo;   repo="$MEOW_APP_TEMA"
  meow_app_tema_do_pack spotify.origem.commit; commit="$MEOW_APP_TEMA"
  meow_app_tema_do_pack spotify.origem.pasta;  pasta="$MEOW_APP_TEMA"
  if [ -z "$repo" ] || [ -z "$commit" ] || [ -z "$pasta" ]; then
    meow_pula "o pack pede o tema '$_SPOT_TEMA_NOME' do spicetify e não diz de onde ele desce"
    meow_info "instale-o em $_SPOT_TEMA, ou escolha um pack que traga a origem do tema"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  tar="https://github.com/$repo/archive/$commit.tar.gz"

  meow_tem curl || { meow_pula "sem curl — o tema do spicetify fica de fora"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem tar  || { meow_pula "sem tar — o tema do spicetify fica de fora";  return "$MEOW_SEM_DEPENDENCIA"; }

  if meow_seco; then
    meow_muda "baixaria o tema '$_SPOT_TEMA_NOME' do spicetify para $_SPOT_TEMA"
    return "$MEOW_DIVERGENTE"
  fi

  meow_destino_permitido "$_SPOT_TEMA" || return "$MEOW_ERRO"
  _spot_alvo_seguro || return "$MEOW_ERRO"
  tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" ".meow-spot-tema.XXXXXX")" || return "$MEOW_ERRO"

  if ! curl -sSL --fail --connect-timeout 15 --max-time 300 \
         -o "$tmp/tema.tar.gz" "$tar" 2>/dev/null; then
    rm -rf "$tmp"
    meow_aviso "não deu para baixar o tema '$_SPOT_TEMA_NOME' do spicetify (sem rede?) — fica para o próximo ciclo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! tar -xzf "$tmp/tema.tar.gz" -C "$tmp" 2>/dev/null; then
    rm -rf "$tmp"
    meow_erro "o tarball do tema veio corrompido — nada instalado"
    return "$MEOW_ERRO"
  fi

  origem="$tmp/${repo##*/}-$commit/$pasta"
  case "$(readlink -m -- "$origem")" in
    "$(readlink -m -- "$tmp")"/*) ;;
    *) rm -rf "$tmp"; meow_erro "recusado: a origem do tema sai de dentro do tarball ($pasta)"; return "$MEOW_ERRO" ;;
  esac
  if [ ! -f "$origem/color.ini" ]; then
    rm -rf "$tmp"
    meow_erro "o tarball do tema mudou de formato (sem $pasta/color.ini)"
    return "$MEOW_ERRO"
  fi

  mkdir -p "$(dirname -- "$_SPOT_TEMA")" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  rm -rf "$_SPOT_TEMA"
  if ! mv -f "$origem" "$_SPOT_TEMA"; then
    rm -rf "$tmp"
    meow_erro "não consegui mover o tema para $_SPOT_TEMA"
    return "$MEOW_ERRO"
  fi
  printf '%s @ %s\npedido pelo pack %s\nbaixado pelo MeowSystem em %s\n' \
         "$repo" "$commit" "${_SPOT_TEMA_DE:-?}" "$(date -Iseconds)" \
    > "$_SPOT_TEMA/PROCEDENCIA.txt" 2>/dev/null
  rm -rf "$tmp"
  meow_ok "tema '$_SPOT_TEMA_NOME' do spicetify baixado em $_SPOT_TEMA"
  return "$MEOW_DIVERGENTE"
}

_spot_rodando() {
  if meow_tem flatpak && \
     flatpak ps --columns=application 2>/dev/null | grep -qx 'com.spotify.Client'; then
    return 0
  fi
  pgrep -x spotify >/dev/null 2>&1
}

_spot_quer_acento() { [ "$_SPOT_ACENTO_NO_INI" = "sim" ]; }

_spot_receita_valida() {
  python3 -c 'import json,sys; json.load(open(sys.argv[1]))["flavors"][sys.argv[2]][sys.argv[3]]' \
    "$_SPOT_PALETA" "$_SPOT_FLAVOR" "$_SPOT_ACENTO" 2>/dev/null
}

meow_app_instalado() { meow_flatpak_tem com.spotify.Client; }

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "Spotify: não está instalado"; return; }
  _spot_instalado || { meow_app_sem "Spotify: não está instalado como flatpak de usuário"; return; }

  if [ -n "$_SPOT_NOME_RECUSADO" ]; then
    meow_app_sem "Spotify: o pack ${_SPOT_TEMA_DE:-ativo} dá ao tema um nome que não serve de pasta ('$_SPOT_NOME_RECUSADO') — nada é escrito"
    return
  fi
  if [ -z "$_SPOT_TEMA_NOME" ] || [ -z "$_SPOT_ESQUEMA" ]; then
    meow_app_sem "Spotify: o pack ativo não declara tema para este app (apps.spotify no pack.json)"
    return
  fi

  if ! _spot_cli >/dev/null; then
    meow_pendencia_acionavel spicetify-ausente \
      "O Spotify está instalado, mas falta o spicetify — é ele que pinta o app. Posso baixá-lo (versão pinada) para ~/.spicetify, sem tocar na configuração do seu terminal" \
      "scripts/spicetify_setup.sh instalar"
    meow_app_sem "Spotify: falta o spicetify — é ele que tematiza o app desde 10/08/2026"
    return
  fi
  meow_pendencia_resolvida spicetify-ausente
  if [ ! -f "$_SPOT_COLOR_INI" ]; then
    meow_pendencia_acionavel spicetify-tema-ausente \
      "Falta o tema '$_SPOT_TEMA_NOME' do Spotify em $_SPOT_TEMA, e o pack ${_SPOT_TEMA_DE:-ativo} o pede" \
      "meow apps aplicar spotify"
    meow_app_sem "Spotify: falta o tema '$_SPOT_TEMA_NOME' do spicetify em $_SPOT_TEMA"
    return
  fi
  meow_pendencia_resolvida spicetify-tema-ausente
  meow_tem python3 || { meow_app_sem "Spotify: falta python3, que lê a paleta"; return; }
  if _spot_quer_acento; then
    [ -f "$_SPOT_ACENTO_PY" ] || { meow_app_sem "Spotify: falta $_SPOT_ACENTO_PY, que escreve o acento no color.ini"; return; }
  fi
  if _spot_quer_acento && ! _spot_receita_valida; then
    meow_app_sem "Spotify: flavor/acento inexistentes na paleta ($_SPOT_FLAVOR/$_SPOT_ACENTO) — confira o meow.conf"
    return
  fi
  [ -w "$(_spot_dir)/Apps" ] || { meow_app_sem "Spotify: o corpo do app não está gravável em $(_spot_dir)/Apps"; return; }
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar >/dev/null 2>&1 || {
    if _spot_quer_acento && ! _spot_receita_valida; then
      meow_aviso "flavor/acento inexistentes na paleta: $_SPOT_FLAVOR/$_SPOT_ACENTO — confira o meow.conf"
    fi
    return "$MEOW_SEM_DEPENDENCIA"
  }

  local tema esquema acento_ok hex colors
  tema="$(_spot_ini_ler current_theme)"
  esquema="$(_spot_ini_ler color_scheme)"

  [ "$tema" = "$_SPOT_TEMA_NOME" ] || return "$MEOW_DIVERGENTE"
  [ "$esquema" = "$_SPOT_ESQUEMA" ] || return "$MEOW_DIVERGENTE"

  hex=""
  if _spot_quer_acento; then
    acento_ok="$(python3 "$_SPOT_ACENTO_PY" estado "$_SPOT_COLOR_INI" \
                   --flavor "$_SPOT_ESQUEMA" --acento "$_SPOT_ACENTO" 2>/dev/null)" || {
      meow_erro "não consegui ler o color.ini do tema '$_SPOT_TEMA_NOME'"
      return "$MEOW_ERRO"
    }
    hex="$(printf '%s\n' "$acento_ok" | sed -n 's/^desejado=//p')"
    printf '%s\n' "$acento_ok" | grep -qx 'ok=sim' || return "$MEOW_DIVERGENTE"
  fi

  colors="$(_spot_dir)/Apps/xpui/colors.css"
  if [ ! -f "$colors" ]; then
    meow_aviso "o Spotify no disco não tem o tema aplicado (o spicetify foi desfeito, ou o app atualizou)"
    return "$MEOW_DIVERGENTE"
  fi
  if [ -n "$hex" ]; then
    grep -qi -- "--spice-text: *#\?${hex}" "$colors" || return "$MEOW_DIVERGENTE"
  fi

  if _spot_mp_quer; then
    if ! _spot_mp_baixado; then
      meow_muda "o Marketplace do spicetify está pedido e não foi baixado"
      return "$MEOW_DIVERGENTE"
    fi
    if ! _spot_mp_registrado; then
      meow_muda "o Marketplace está baixado e fora do custom_apps do spicetify"
      return "$MEOW_DIVERGENTE"
    fi
    if ! _spot_mp_no_disco; then
      meow_muda "o Marketplace está configurado e ainda não entrou no Spotify (falta um apply)"
      return "$MEOW_DIVERGENTE"
    fi
  fi

  local vb vi
  vb="$(_spot_ini_ler version)"; vi="$(_spot_versao)"
  if [ -n "$vb" ] && [ -n "$vi" ] && [ "$vb" != "$vi" ]; then
    if _spot_backup_fresco; then
      meow_muda "o carimbo de versão do spicetify está velho ($vb; o Spotify é a $vi) — o backup, porém, é do app de agora"
      return "$MEOW_DIVERGENTE"
    fi
    meow_aviso "o backup do spicetify é da versão $vb e o Spotify é a $vi — veja scripts/temas-de-apps/spotify/RECUPERACAO.md"
  fi

  meow_ok "Spotify em $_SPOT_TEMA_NOME/$_SPOT_ESQUEMA, do pack ${_SPOT_TEMA_DE:-ativo} (via spicetify)"
  return "$MEOW_OK"
}

meow_app_aplicar() {
  if _spot_instalado && _spot_cli >/dev/null && [ -n "$_SPOT_COLOR_INI" ] && [ ! -f "$_SPOT_COLOR_INI" ]; then
    _spot_tema_baixar
    case $? in
      2) return "$MEOW_ERRO" ;;
    esac
  fi
  meow_app_detectar || { meow_app_pendente spotify; return; }
  local mexi=0 vb0 vi0
  vb0="$(_spot_ini_ler version)"; vi0="$(_spot_versao)"
  if [ -n "$vb0" ] && [ -n "$vi0" ] && [ "$vb0" != "$vi0" ] && _spot_backup_fresco; then
    _spot_carimbar_versao
    case $? in
      1) mexi=1
         meow_seco || meow_ok "carimbo de versão do spicetify corrigido: $vb0 -> $vi0 (o backup já era do app de agora)" ;;
      2) meow_erro "não consegui corrigir o [Backup] version do config-xpui.ini"
         return "$MEOW_ERRO" ;;
    esac
  fi

  if _spot_mp_quer; then
    _spot_mp_instalar
    case $? in
      1) mexi=1 ;;
      2) return "$MEOW_ERRO" ;;
    esac
    if _spot_mp_baixado; then
      _spot_mp_registrar
      case $? in
        1) mexi=1 ;;
        2) return "$MEOW_ERRO" ;;
      esac
    fi
  fi

  meow_app_conferir >/dev/null 2>&1
  case $? in
    0)
       meow_pendencia_resolvida spotify-tema-de-terceiro
       [ "$mexi" = "1" ] && return "$MEOW_DIVERGENTE"
       meow_ok "Spotify já está em $_SPOT_TEMA_NOME/$_SPOT_ESQUEMA, do pack ${_SPOT_TEMA_DE:-ativo} — nada a fazer"
       return "$MEOW_OK" ;;
    3) meow_pula "Spotify: nada a fazer (veja o aviso do conferir)"
       return "$MEOW_SEM_DEPENDENCIA" ;;
    2) return "$MEOW_ERRO" ;;
  esac

  local no_ar; no_ar="$(_spot_ini_ler current_theme)"
  if [ -n "$no_ar" ] && [ "$no_ar" != "$_SPOT_TEMA_NOME" ] && [ "$no_ar" = "$(cat "$_SPOT_NOSSO" 2>/dev/null)" ]; then
    meow_pendencia_resolvida spotify-tema-de-terceiro
    meow_info "spotify: o tema do MeowSystem estava em '$no_ar' — passa a '$_SPOT_TEMA_NOME' (do pack ${_SPOT_TEMA_DE:-ativo})"
  else
    meow_app_tema_no_ar spotify "$no_ar" "$_SPOT_TEMA_NOME" "$_SPOT_TEMA_DE" pergunte
    [ $? = "$MEOW_SEM_DEPENDENCIA" ] && return "$MEOW_SEM_DEPENDENCIA"
  fi

  if _spot_rodando; then
    meow_pula "Spotify está ABERTO — não mexo no app no meio do uso; tento no próximo ciclo"
    meow_info "a mudança só valeria no próximo início do Spotify de qualquer forma"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local vb vi
  vb="$(_spot_ini_ler version)"; vi="$(_spot_versao)"
  if [ -n "$vb" ] && [ -n "$vi" ] && [ "$vb" != "$vi" ]; then
    meow_aviso "o Spotify atualizou ($vb -> $vi) e o backup do spicetify é da versão velha"
    meow_info "o tema do Spotify fica como está até o backup novo; o passo a passo está em scripts/temas-de-apps/spotify/RECUPERACAO.md"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local cli; cli="$(_spot_cli)"

  if meow_seco; then
    meow_muda "mudaria o Spotify para $_SPOT_TEMA_NOME/$_SPOT_ESQUEMA, do pack ${_SPOT_TEMA_DE:-ativo} (spicetify config + apply)"
    return "$MEOW_DIVERGENTE"
  fi

  if _spot_quer_acento; then
    meow_destino_permitido "$_SPOT_COLOR_INI" || return "$MEOW_ERRO"
    if ! python3 "$_SPOT_ACENTO_PY" aplicar "$_SPOT_COLOR_INI" \
          --flavor "$_SPOT_ESQUEMA" --acento "$_SPOT_ACENTO" >/dev/null; then
      meow_erro "não consegui pôr o acento $_SPOT_ACENTO no color.ini do tema '$_SPOT_TEMA_NOME'"
      return "$MEOW_ERRO"
    fi
  fi

  "$cli" config current_theme "$_SPOT_TEMA_NOME" >/dev/null 2>&1
  "$cli" config color_scheme "$_SPOT_ESQUEMA" >/dev/null 2>&1
  "$cli" config inject_css 1 inject_theme_js 1 replace_colors 1 overwrite_assets 1 >/dev/null 2>&1

  local _saida
  if ! _saida="$("$cli" apply 2>&1)"; then
    meow_erro "o 'spicetify apply' falhou — o Spotify segue com o tema de antes"
    printf '%s\n' "$_saida" | tail -n 4 | sed 's/^/        /' >&2
    return "$MEOW_ERRO"
  fi

  mkdir -p "$(dirname -- "$_SPOT_NOSSO")" && printf '%s\n' "$_SPOT_TEMA_NOME" > "$_SPOT_NOSSO"
  meow_ok "Spotify em $_SPOT_TEMA_NOME/$_SPOT_ESQUEMA, do pack ${_SPOT_TEMA_DE:-ativo} (vale no próximo início do app)"
  return "$MEOW_DIVERGENTE"
}

meow_app_reverter() {
  meow_app_detectar || { meow_app_pendente spotify; return; }
  if _spot_rodando; then
    meow_pula "Spotify está ABERTO — não mexo no app no meio do uso"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if meow_seco; then
    meow_muda "desfaria o tema '$_SPOT_TEMA_NOME' no Spotify (spicetify restore)"
    return "$MEOW_DIVERGENTE"
  fi

  local vb vi
  vb="$(_spot_ini_ler version)"; vi="$(_spot_versao)"
  if [ -n "$vb" ] && [ -n "$vi" ] && [ "$vb" != "$vi" ]; then
    if _spot_backup_fresco; then
      _spot_carimbar_versao >/dev/null
      if [ "$(_spot_ini_ler version)" != "$vi" ]; then
        meow_erro "não consegui corrigir o [Backup] version antes de restaurar"
        return "$MEOW_ERRO"
      fi
      meow_info "carimbo de versão corrigido ($vb -> $vi) — o backup é do app de agora, dá para restaurar"
    else
      meow_erro "o backup do spicetify é da versão $vb e o Spotify é a $vi — restaurar daria janela em branco"
      meow_info "a volta limpa é reinstalar o Spotify do flathub; o passo a passo está em scripts/temas-de-apps/spotify/RECUPERACAO.md"
      return "$MEOW_ERRO"
    fi
  fi

  local cli; cli="$(_spot_cli)"
  local _saida
  if ! _saida="$("$cli" restore 2>&1)"; then
    meow_erro "o 'spicetify restore' falhou — o Spotify segue com o tema do MeowSystem"
    printf '%s\n' "$_saida" | tail -n 4 | sed 's/^/        /' >&2
    return "$MEOW_ERRO"
  fi

  meow_ok "Spotify sem o tema do pack (vale no próximo início do app)"
  meow_info "tire 'spotify' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}

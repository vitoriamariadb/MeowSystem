#!/usr/bin/env bash

_DC_ARQ_NOME="MeowSystem.theme.css"
_DC_MODELO_PY="$MEOW_RAIZ/scripts/temas-de-apps/modelo.py"
_DC_CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
_DC_VENCORD_VERSAO="v1.4.2"
_DC_VENCORD_SHA="52642c8521a866ad241c10337144a4f513672c54b9c86a8169954785054c815d"
_DC_VENCORD_URL="${MEOW_VENCORD_URL:-https://github.com/Vencord/Installer/releases/download/$_DC_VENCORD_VERSAO/VencordInstallerCli-linux}"

_dc_pastas() {
  local d
  for d in \
    "$_DC_CONF/BetterDiscord/themes" \
    "$_DC_CONF/Vencord/themes" \
    "$_DC_CONF/vesktop/themes" \
    "$HOME/.var/app/com.discordapp.Discord/config/BetterDiscord/themes" \
    "$HOME/.var/app/com.discordapp.Discord/config/Vencord/themes" \
    "$HOME/.var/app/dev.vencord.Vesktop/config/vesktop/themes"; do
    [ -d "$d" ] && printf '%s\n' "$d"
  done
}

_dc_instalado() {
  meow_flatpak_tem com.discordapp.Discord || meow_flatpak_tem dev.vencord.Vesktop \
    || meow_tem discord || meow_tem Discord || meow_tem vesktop || [ -n "$(_dc_app_novo)" ]
}

_dc_app_novo() {
  local d
  d="$(find "$_DC_CONF/discord" -mindepth 1 -maxdepth 1 -type d -name 'app-*' 2>/dev/null | sort -V | tail -n 1)"
  [ -n "$d" ] && [ -d "$d/resources" ] && printf '%s' "$d"
}

_dc_com_vencord() {
  [ -f "$1/resources/_app.asar" ] && grep -qa 'Vencord' "$1/resources/app.asar" 2>/dev/null
}

_dc_quer_vencord() {
  [ "${DISCORD_VENCORD:-sim}" = "sim" ] && [ -n "$(_dc_app_novo)" ]
}

_dc_instalador() {
  local dir bin sha tmp
  sha="${MEOW_VENCORD_SHA256:-$_DC_VENCORD_SHA}"
  dir="${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/vencord/$_DC_VENCORD_VERSAO"
  bin="$dir/VencordInstallerCli-linux"
  _DC_INSTALADOR=""
  if [ -x "$bin" ] && echo "$sha  $bin" | sha256sum --status -c - 2>/dev/null; then
    _DC_INSTALADOR="$bin"
    return "$MEOW_OK"
  fi
  meow_tem curl || { meow_pula "Discord: sem curl — o Vencord fica para a próxima passada"; return "$MEOW_SEM_DEPENDENCIA"; }
  mkdir -p "$dir" || return "$MEOW_ERRO"
  tmp="$(mktemp -p "$dir" ".baixando.XXXXXX")" || return "$MEOW_ERRO"
  if ! curl -sSfL --connect-timeout 15 --max-time 300 --retry 3 --retry-delay 2 -o "$tmp" "$_DC_VENCORD_URL" 2>/dev/null; then
    rm -f "$tmp"
    meow_pula "Discord: sem rede para baixar o instalador do Vencord — fica para a próxima passada"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! echo "$sha  $tmp" | sha256sum --status -c - 2>/dev/null; then
    rm -f "$tmp"
    meow_erro "Discord: o instalador do Vencord baixado não bate com o sha256 pinado de $_DC_VENCORD_VERSAO — nada injetado"
    return "$MEOW_ERRO"
  fi
  chmod 755 "$tmp" && mv -f "$tmp" "$bin" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  _DC_INSTALADOR="$bin"
  return "$MEOW_OK"
}

_dc_injetar() {
  local app="$1" rc
  if meow_seco; then
    meow_muda "Discord: injetaria o Vencord em $app"
    return "$MEOW_DIVERGENTE"
  fi
  if _dc_aberto; then
    meow_pula "Discord: o cliente está aberto — o Vencord entra na próxima passada com ele fechado"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  _dc_instalador
  rc=$?
  [ "$rc" = "$MEOW_OK" ] || return "$rc"
  if ! "$_DC_INSTALADOR" -install -location "$app" >/dev/null 2>&1 || ! _dc_com_vencord "$app"; then
    meow_erro "Discord: o instalador do Vencord não injetou em $app"
    return "$MEOW_ERRO"
  fi
  meow_ok "Discord: Vencord injetado em $app"
  return "$MEOW_DIVERGENTE"
}

_dc_tirar_vencord() {
  local app="$1"
  _dc_com_vencord "$app" || return "$MEOW_OK"
  if meow_seco; then
    meow_muda "Discord: tiraria o Vencord de $app"
    return "$MEOW_DIVERGENTE"
  fi
  mv -f -- "$app/resources/_app.asar" "$app/resources/app.asar" \
    || { meow_erro "Discord: não consegui devolver o app.asar original em $app"; return "$MEOW_ERRO"; }
  meow_ok "Discord: o Vencord saiu de $app"
  return "$MEOW_DIVERGENTE"
}

_dc_marca() {
  sed -n 's|^ \* meowsystem-tema: \([^ ]*\).*$|\1|p' "$1" 2>/dev/null | head -n 1
}

meow_app_instalado() { _dc_instalado; }

_dc_ajustes() {
  case "$1" in
    */Vencord/themes|*/vesktop/themes) printf '%s/settings/settings.json' "${1%/themes}" ;;
  esac
}

_dc_aberto() {
  pgrep -x vesktop >/dev/null 2>&1 || pgrep -x vesktop.bin >/dev/null 2>&1 \
    || pgrep -x Discord >/dev/null 2>&1 || pgrep -x discord >/dev/null 2>&1
}

_dc_lista() {
  local modo="$1" ajustes="$2"
  [ -n "$ajustes" ] || return "$MEOW_OK"
  [ "$modo" = "conferir" ] || meow_seco || meow_destino_permitido "$ajustes" || return "$MEOW_ERRO"
  MEOW_PY_SECO="$(meow_seco && echo 1 || echo 0)" \
  python3 -I - "$modo" "$ajustes" "$_DC_ARQ_NOME" <<'PYFIM'
import json, os, sys, tempfile
modo, caminho, nome = sys.argv[1:4]
seco = os.environ.get("MEOW_PY_SECO") == "1"
try:
    with open(caminho, encoding="utf-8") as fh:
        dados = json.load(fh)
except FileNotFoundError:
    dados = {}
except (OSError, ValueError) as e:
    sys.stderr.write("%s ilegível (%s)\n" % (caminho, e))
    sys.exit(2)
if not isinstance(dados, dict):
    sys.exit(2)
lista = dados.get("enabledThemes")
lista = list(lista) if isinstance(lista, list) else []
if modo in ("conferir", "ligar"):
    if nome in lista:
        sys.exit(0)
    if modo == "conferir" or seco:
        sys.exit(1)
    lista.append(nome)
else:
    if nome not in lista:
        sys.exit(0)
    if seco:
        sys.exit(1)
    lista = [x for x in lista if x != nome]
dados["enabledThemes"] = lista
pasta = os.path.dirname(caminho)
os.makedirs(pasta, exist_ok=True)
fd, tmp = tempfile.mkstemp(dir=pasta, prefix=".meow-vencord.")
with os.fdopen(fd, "w", encoding="utf-8") as fh:
    json.dump(dados, fh, indent=4, ensure_ascii=False)
os.chmod(tmp, 0o644)
os.replace(tmp, caminho)
sys.exit(1)
PYFIM
}

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "Discord: não está instalado"; return; }
  _DC_PASTAS="$(_dc_pastas)"
  if _dc_quer_vencord; then
    printf '%s\n' "$_DC_PASTAS" | grep -qx "$_DC_CONF/Vencord/themes" \
      || _DC_PASTAS="${_DC_PASTAS:+$_DC_PASTAS
}$_DC_CONF/Vencord/themes"
  fi
  [ -n "$_DC_PASTAS" ] || { meow_app_sem "Discord: o cliente oficial não carrega tema; o tema entra quando houver um cliente modificado (BetterDiscord, Vencord ou Vesktop)"; return; }
  meow_tem python3 || { meow_app_sem "Discord: falta python3, que monta o tema com a paleta do pack"; return; }
  meow_app_tema_do_pack discord.arquivo
  _DC_DE="$MEOW_APP_TEMA_PACK"
  [ -n "$MEOW_APP_TEMA" ] || { meow_app_sem "Discord: o pack no ar não declara tema para o Discord"; return; }
  _DC_QUERO="$_DC_DE/${FLAVOR:-}"
  _DC_DESEJADO="$(python3 "$_DC_MODELO_PY" "$MEOW_APP_TEMA" "$(meow_paleta)" "${FLAVOR:-}" "$_DC_DE" 2>&1)" \
    || { meow_app_sem "Discord: o modelo do pack $_DC_DE não montou — $_DC_DESEJADO"; return; }
  _DC_NOME="$(python3 "$_DC_MODELO_PY" --nome "$(meow_paleta)" "${FLAVOR:-}" 2>/dev/null) (MeowSystem)"
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  local pasta arq marca rc="$MEOW_OK" app
  if _dc_quer_vencord; then
    app="$(_dc_app_novo)"
    if ! _dc_com_vencord "$app"; then
      meow_muda "Discord: o Vencord não está em $app"
      rc="$MEOW_DIVERGENTE"
    fi
  fi
  while IFS= read -r pasta; do
    arq="$pasta/$_DC_ARQ_NOME"
    marca="$(_dc_marca "$arq")"
    if [ ! -f "$arq" ]; then
      meow_muda "Discord: o tema do pack não está em $pasta"
      rc="$MEOW_DIVERGENTE"
    elif [ -z "$marca" ]; then
      meow_pula "Discord: $arq não veio daqui — não é tocado"
      [ "$rc" = "$MEOW_OK" ] && rc="$MEOW_SEM_DEPENDENCIA"
    elif [ "$(cat "$arq")" != "$_DC_DESEJADO" ]; then
      meow_muda "Discord: em $pasta está '$marca', e o de agora é '$_DC_QUERO' (ou o modelo mudou)"
      rc="$MEOW_DIVERGENTE"
    fi
    if [ -n "$marca" ] && ! _dc_lista conferir "$(_dc_ajustes "$pasta")"; then
      meow_muda "Discord: o tema do pack está em $pasta, e desligado no cliente"
      rc="$MEOW_DIVERGENTE"
    fi
  done <<< "$_DC_PASTAS"
  [ "$rc" = "$MEOW_OK" ] && meow_ok "Discord: o tema do pack (do pack $_DC_DE) está na pasta de cada cliente — $_DC_QUERO"
  return "$rc"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente discord; return; }
  local pasta arq marca mudou=0 pulou=0 ajustes app rc
  if _dc_quer_vencord; then
    app="$(_dc_app_novo)"
    if ! _dc_com_vencord "$app"; then
      _dc_injetar "$app"
      rc=$?
      case "$rc" in
        "$MEOW_DIVERGENTE") mudou=1 ;;
        "$MEOW_SEM_DEPENDENCIA") pulou=1 ;;
        *) return "$rc" ;;
      esac
    fi
  fi
  while IFS= read -r pasta; do
    arq="$pasta/$_DC_ARQ_NOME"
    marca="$(_dc_marca "$arq")"
    if [ -n "$marca" ]; then
      if [ "$marca" = "$_DC_QUERO" ]; then
        meow_app_tema_no_ar discord "$marca" "$_DC_QUERO" "$_DC_DE" >/dev/null
      else
        meow_muda "Discord: em $pasta o tema do MeowSystem estava em '$marca' — passa a '$_DC_QUERO'"
      fi
    else
      local no_ar=""
      [ -f "$arq" ] && no_ar="$arq"
      meow_app_tema_no_ar discord "$no_ar" "$_DC_QUERO" "$_DC_DE" pergunte
      [ $? = "$MEOW_DIVERGENTE" ] || { pulou=1; continue; }
    fi
    meow_escrever "$arq" "$_DC_DESEJADO" 644
    case $? in
      1) mudou=1; meow_seco || meow_ok "Discord: tema do pack em $pasta" ;;
      2) meow_erro "Discord: falhou ao escrever $arq"; return "$MEOW_ERRO" ;;
    esac
    ajustes="$(_dc_ajustes "$pasta")"
    if [ -n "$ajustes" ] && ! _dc_lista conferir "$ajustes"; then
      if _dc_aberto; then
        meow_pula "Discord: o cliente está aberto — o tema fica na pasta, e liga na próxima passada com ele fechado"
        pulou=1
      else
        _dc_lista ligar "$ajustes"
        case $? in
          0) ;;
          1) mudou=1; meow_seco && meow_muda "Discord: ligaria '$_DC_NOME' em $ajustes" \
                               || meow_ok "Discord: '$_DC_NOME' ligado em $ajustes" ;;
          *) meow_erro "Discord: não consegui ligar o tema em $ajustes"; return "$MEOW_ERRO" ;;
        esac
      fi
    fi
  done <<< "$_DC_PASTAS"

  if [ "$mudou" = 1 ]; then
    meow_seco && return "$MEOW_DIVERGENTE"
    grep -q '/BetterDiscord/themes$' <<< "$_DC_PASTAS" \
      && meow_info "no BetterDiscord, ligue '$_DC_NOME' em Configurações > Temas (vale ao reabrir o Discord)"
    return "$MEOW_DIVERGENTE"
  fi
  [ "$pulou" = 1 ] && return "$MEOW_SEM_DEPENDENCIA"
  meow_ok "Discord: já está no tema do pack (do pack $_DC_DE) — $_DC_QUERO"
  return "$MEOW_OK"
}

meow_app_reverter() {
  local pasta arq mudou=0 app rc
  while IFS= read -r app; do
    [ -n "$app" ] || continue
    _dc_com_vencord "$app" || continue
    _dc_tirar_vencord "$app"
    rc=$?
    [ "$rc" = "$MEOW_ERRO" ] && return "$MEOW_ERRO"
    mudou=1
  done <<< "$(find "$_DC_CONF/discord" -mindepth 1 -maxdepth 1 -type d -name 'app-*' 2>/dev/null | sort -V)"
  while IFS= read -r pasta; do
    [ -n "$pasta" ] || continue
    arq="$pasta/$_DC_ARQ_NOME"
    [ -n "$(_dc_marca "$arq")" ] || continue
    _dc_lista desligar "$(_dc_ajustes "$pasta")" >/dev/null 2>&1
    if meow_seco; then
      meow_muda "Discord: tiraria $arq"
    else
      rm -f -- "$arq" || { meow_erro "Discord: não consegui tirar $arq"; return "$MEOW_ERRO"; }
      meow_ok "Discord: o tema do pack saiu de $pasta"
    fi
    mudou=1
  done <<< "$(_dc_pastas)"
  if [ "$mudou" = 0 ]; then
    meow_ok "Discord: nenhum tema do MeowSystem no disco — nada a desfazer"
    return "$MEOW_OK"
  fi
  meow_app_desligar discord
  return "$MEOW_DIVERGENTE"
}

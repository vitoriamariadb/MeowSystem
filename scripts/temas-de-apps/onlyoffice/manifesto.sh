#!/usr/bin/env bash

_OO_ID="org.onlyoffice.desktopeditors"
_OO_TEMA_ID="theme-meowsystem"
_OO_FABRICA=" theme-system theme-light theme-classic-light theme-dark theme-contrast-dark theme-gray theme-white theme-night "
_OO_MODELO_PY="$MEOW_RAIZ/scripts/temas-de-apps/modelo.py"
_OO_ANTES="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/temas-de-apps/onlyoffice/escolha.antes"

_oo_lugares() {
  if meow_flatpak_tem "$_OO_ID"; then
    _OO_DADOS="$HOME/.var/app/$_OO_ID/data/onlyoffice/desktopeditors"
    _OO_CONF="$HOME/.var/app/$_OO_ID/config/onlyoffice/DesktopEditors.conf"
  elif meow_tem onlyoffice-desktopeditors || meow_tem desktopeditors \
       || [ -x /opt/onlyoffice/desktopeditors/DesktopEditors ]; then
    _OO_DADOS="${XDG_DATA_HOME:-$HOME/.local/share}/onlyoffice/desktopeditors"
    _OO_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/onlyoffice/DesktopEditors.conf"
  else
    return 1
  fi
  _OO_ARQ="$_OO_DADOS/uithemes/meowsystem.json"
}

_oo_py() {
  python3 -I - "$@" <<'PY'
import base64, json, os, re, sys

modo, caminho = sys.argv[1], sys.argv[2]
try:
    linhas = open(caminho, encoding="utf-8").read().split("\n")
except OSError:
    linhas = []
RE_APP = re.compile(r'^appdata="@ByteArray\(([A-Za-z0-9+/=]*)\)"$')


def appdata(linha):
    m = RE_APP.match(linha)
    return json.loads(base64.b64decode(m.group(1)).decode("utf-8")) if m else None


secao = None
if modo == "ler":
    ui, dados = "", ""
    for l in linhas:
        if l.startswith("["):
            secao = l.strip()
        elif secao == "[General]" and l.startswith("UITheme="):
            ui = l[len("UITheme="):]
        elif secao == "[General]" and l.startswith("appdata="):
            try:
                d = appdata(l)
            except (ValueError, UnicodeDecodeError):
                d = {"uitheme": "(appdata ilegível)"}
            dados = (d or {}).get("uitheme", "") if isinstance(d, dict) else ""
    ui_id = ui
    if ui.endswith(".json") and os.path.isfile(ui):
        try:
            ui_id = json.load(open(ui, encoding="utf-8")).get("id") or ui
        except (OSError, ValueError, AttributeError):
            ui_id = ui
    print(f"UITheme={ui}")
    print(f"uitheme={dados}")
    print(f"id_do_UITheme={ui_id}")
    sys.exit(0)

if modo == "escolher":
    novo_id, novo_ui = sys.argv[3], sys.argv[4]
    saida, viu_ui, viu_geral = [], False, False
    for l in linhas:
        if l.startswith("["):
            if secao == "[General]" and not viu_ui:
                saida.append(f"UITheme={novo_ui}")
                viu_ui = True
            secao = l.strip()
            viu_geral = viu_geral or secao == "[General]"
        elif secao == "[General]" and l.startswith("UITheme="):
            l, viu_ui = f"UITheme={novo_ui}", True
        elif secao == "[General]" and l.startswith("appdata="):
            d = appdata(l)
            if isinstance(d, dict):
                d["uitheme"] = novo_id
                cru = json.dumps(d, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
                l = f'appdata="@ByteArray({base64.b64encode(cru).decode()})"'
        saida.append(l)
    if not viu_ui:
        if not viu_geral:
            saida = ["[General]"] + saida
            viu_geral = True
        pos = saida.index("[General]") + 1
        saida.insert(pos, f"UITheme={novo_ui}")
    sys.stdout.write("\n".join(saida).rstrip("\n") + "\n")
    sys.exit(0)

sys.exit(2)
PY
}

_oo_no_ar() {
  local lido ui dados ui_id
  _OO_NO_AR=""; _OO_ESCOLHA=""
  [ -f "$_OO_CONF" ] || return 0
  lido="$(_oo_py ler "$_OO_CONF" 2>/dev/null)"
  ui="$(sed -n 's/^UITheme=//p' <<< "$lido")"
  dados="$(sed -n 's/^uitheme=//p' <<< "$lido")"
  ui_id="$(sed -n 's/^id_do_UITheme=//p' <<< "$lido")"
  _OO_ESCOLHA="$(printf '%s\t%s' "$dados" "$ui")"
  _OO_NO_AR="${dados:-$ui_id}"
  case "$_OO_FABRICA" in *" $_OO_NO_AR "*) _OO_NO_AR="" ;; esac
  return 0
}

_oo_aberto() { pgrep -x DesktopEditors >/dev/null 2>&1; }

_oo_gravar_conf() {
  local novo="$1" dir tmp
  meow_destino_permitido "$_OO_CONF" || return "$MEOW_ERRO"
  [ -f "$_OO_CONF" ] && [ "$novo" = "$(cat "$_OO_CONF")" ] && return "$MEOW_OK"
  if meow_seco; then meow_muda "escolheria o tema em $_OO_CONF"; return "$MEOW_DIVERGENTE"; fi
  dir="$(dirname "$_OO_CONF")"
  mkdir -p "$dir" || return "$MEOW_ERRO"
  tmp="$(mktemp -p "$dir" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  printf '%s\n' "$novo" > "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod --reference="$_OO_CONF" "$tmp" 2>/dev/null || chmod 644 "$tmp"
  mv -f "$tmp" "$_OO_CONF" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"
}

meow_app_instalado() { _oo_lugares; }

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "OnlyOffice: não está instalado"; return; }
  local falta
  for falta in python3 pgrep; do
    meow_tem "$falta" || { meow_app_sem "OnlyOffice: falta '$falta' (sem ele não dá para aplicar com segurança)"; return; }
  done
  meow_app_tema_do_pack onlyoffice.arquivo
  _OO_DE="$MEOW_APP_TEMA_PACK"
  [ -n "$MEOW_APP_TEMA" ] || { meow_app_sem "OnlyOffice: o pack no ar não declara tema para o OnlyOffice"; return; }
  _OO_DESEJADO="$(python3 "$_OO_MODELO_PY" "$MEOW_APP_TEMA" "$(meow_paleta)" "${FLAVOR:-}" "$_OO_DE" 2>&1)" \
    || { meow_app_sem "OnlyOffice: o modelo do pack $_OO_DE não montou — $_OO_DESEJADO"; return; }
  _OO_NOME="$(python3 "$_OO_MODELO_PY" --nome "$(meow_paleta)" "${FLAVOR:-}" 2>/dev/null) (MeowSystem)"
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _oo_no_ar
  if [ "$_OO_NO_AR" != "$_OO_TEMA_ID" ] && [ -n "$_OO_NO_AR" ]; then
    meow_pula "OnlyOffice: está no tema '$_OO_NO_AR', que não veio daqui — trocar é decisão sua"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  local rc="$MEOW_OK"
  if [ ! -f "$_OO_ARQ" ] || [ "$(cat "$_OO_ARQ")" != "$_OO_DESEJADO" ]; then
    meow_muda "OnlyOffice: o tema do pack não está em $_OO_ARQ, ou é de outro flavor"
    rc="$MEOW_DIVERGENTE"
  fi
  if [ "$_OO_NO_AR" != "$_OO_TEMA_ID" ] && [ ! -f "$_OO_CONF" ] && [ "$rc" = "$MEOW_OK" ]; then
    meow_pula "OnlyOffice: nunca foi aberto — o tema do pack já está na pasta, e a escolha espera o conf que o app cria ao abrir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ "$_OO_NO_AR" != "$_OO_TEMA_ID" ]; then
    meow_muda "OnlyOffice: o tema escolhido é o de fábrica — o pack $_OO_DE traz '$_OO_NOME'"
    rc="$MEOW_DIVERGENTE"
  fi
  [ "$rc" = "$MEOW_OK" ] && meow_ok "OnlyOffice: já está no tema do pack (do pack $_OO_DE) — $_OO_NOME"
  return "$rc"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente onlyoffice; return; }
  _oo_no_ar
  local mudou=0
  if [ "$_OO_NO_AR" != "$_OO_TEMA_ID" ]; then
    meow_app_tema_no_ar onlyoffice "$_OO_NO_AR" "$_OO_TEMA_ID" "$_OO_DE" pergunte
    [ $? = "$MEOW_DIVERGENTE" ] || return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_escrever "$_OO_ARQ" "$_OO_DESEJADO" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "OnlyOffice: falhou ao escrever $_OO_ARQ"; return "$MEOW_ERRO" ;; esac

  if [ "$_OO_NO_AR" != "$_OO_TEMA_ID" ]; then
    if [ ! -f "$_OO_CONF" ]; then
      meow_app_sem "OnlyOffice: nunca foi aberto, e sem o conf dele não há onde escolher o tema — ele já está na pasta; a escolha fica para depois da primeira abertura (ou escolha '$_OO_NOME' em Preferências > Aparência)"
      meow_app_pendente onlyoffice
      return "$MEOW_SEM_DEPENDENCIA"
    elif _oo_aberto; then
      meow_app_sem "OnlyOffice: está aberto, e ele reescreve o conf ao sair — o tema já está na pasta; a escolha fica para quando ele estiver fechado"
      meow_app_pendente onlyoffice
      return "$MEOW_SEM_DEPENDENCIA"
    else
      if [ ! -f "$_OO_ANTES" ] && ! meow_seco; then
        mkdir -p "$(dirname "$_OO_ANTES")" && printf '%s\n' "$_OO_ESCOLHA" > "$_OO_ANTES" \
          || { meow_erro "OnlyOffice: não consegui guardar a escolha de antes"; return "$MEOW_ERRO"; }
      fi
      local novo
      novo="$(_oo_py escolher "$_OO_CONF" "$_OO_TEMA_ID" "$_OO_ARQ")" \
        || { meow_erro "OnlyOffice: não consegui ler $_OO_CONF"; return "$MEOW_ERRO"; }
      _oo_gravar_conf "$novo"
      case $? in 1) mudou=1 ;; 2) meow_erro "OnlyOffice: falhou ao escrever $_OO_CONF"; return "$MEOW_ERRO" ;; esac
    fi
  fi

  if [ "$mudou" = 0 ]; then
    meow_app_tema_no_ar onlyoffice "$_OO_TEMA_ID" "$_OO_TEMA_ID" "$_OO_DE"
    return "$MEOW_OK"
  fi
  meow_seco && return "$MEOW_DIVERGENTE"
  meow_ok "OnlyOffice: tema do pack aplicado — $_OO_NOME (vale ao abrir o app)"
  return "$MEOW_DIVERGENTE"
}

meow_app_reverter() {
  if ! _oo_lugares; then
    meow_ok "OnlyOffice: não está instalado — nada a desfazer"
    return "$MEOW_OK"
  fi
  _oo_no_ar
  local mudou=0 antes_id="theme-system" antes_ui="theme-system" linha
  if [ "$_OO_NO_AR" = "$_OO_TEMA_ID" ]; then
    if _oo_aberto; then
      meow_app_sem "OnlyOffice: está aberto, e ele reescreve o conf ao sair — feche-o e desfaça de novo"
      meow_app_pendente onlyoffice
      return "$MEOW_SEM_DEPENDENCIA"
    fi
    if [ -f "$_OO_ANTES" ]; then
      linha="$(head -n 1 "$_OO_ANTES")"
      antes_id="${linha%%$'\t'*}"; antes_ui="${linha#*$'\t'}"
      [ -n "$antes_id" ] || antes_id="$antes_ui"
      [ -n "$antes_ui" ] || antes_ui="$antes_id"
    fi
    [ -n "$antes_id" ] || { antes_id="theme-system"; antes_ui="theme-system"; }
    _oo_gravar_conf "$(_oo_py escolher "$_OO_CONF" "$antes_id" "$antes_ui")"
    case $? in
      1) mudou=1; meow_seco || meow_ok "OnlyOffice: a escolha voltou a '$antes_id'" ;;
      2) meow_erro "OnlyOffice: não consegui devolver a escolha"; return "$MEOW_ERRO" ;;
    esac
  fi
  if [ -f "$_OO_ARQ" ]; then
    if meow_seco; then
      meow_muda "OnlyOffice: tiraria $_OO_ARQ"
    else
      rm -f -- "$_OO_ARQ" || { meow_erro "OnlyOffice: não consegui tirar $_OO_ARQ"; return "$MEOW_ERRO"; }
      meow_ok "OnlyOffice: o tema do pack saiu da pasta uithemes/"
    fi
    mudou=1
  fi
  meow_seco || rm -f -- "$_OO_ANTES"
  if [ "$mudou" = 0 ]; then
    meow_ok "OnlyOffice: nenhum tema do MeowSystem no disco — nada a desfazer"
    return "$MEOW_OK"
  fi
  meow_app_desligar onlyoffice
  return "$MEOW_DIVERGENTE"
}

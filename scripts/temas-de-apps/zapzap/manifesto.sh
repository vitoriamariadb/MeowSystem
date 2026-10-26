#!/usr/bin/env bash

_ZZ_APP="com.rtosta.zapzap"
_ZZ_NOME_NOVO="WhatsApp"
_ZZ_ICONE="meow-whatsapp"
_ZZ_ORIGEM="$HOME/.local/share/flatpak/exports/share/applications/$_ZZ_APP.desktop"
_ZZ_DESTINO="$_ZZ_ORIGEM"
_ZZ_GUARDADO="$HOME/.local/share/flatpak/exports/share/applications/.$_ZZ_APP.desktop.meow-original"

_zz_tema_dir() {
  printf '%s' "$HOME/.local/share/icons/${NOME_TEMA_ICONES:-MeowSystem-Icons}"
}

_zz_pack_nome() {
  local nome
  nome="$(python3 "$MEOW_RAIZ/scripts/pack.py" adocao "${PACK:-}" "${FLAVOR:-}" 2>/dev/null | sed -n 's/^nome=//p')"
  printf '%s' "${nome:-do pack no ar}"
}

_zz_fonte() {
  if [ -L "$_ZZ_ORIGEM" ]; then printf '%s' "$_ZZ_ORIGEM"; return; fi
  if [ -f "$_ZZ_GUARDADO" ]; then printf '%s' "$_ZZ_GUARDADO"; else printf '%s' "$_ZZ_ORIGEM"; fi
}

_zz_guardar_original() {
  [ -L "$_ZZ_ORIGEM" ] || return 0
  [ -f "$_ZZ_GUARDADO" ] && return 0
  meow_seco && return 0
  cp -L "$_ZZ_ORIGEM" "$_ZZ_GUARDADO" 2>/dev/null || true
}

_zz_desktop_desejado() {
  sed -E \
    -e "s|^Name=.*|Name=$_ZZ_NOME_NOVO|" \
    -e "s|^Name\[[^]]+\]=.*|Name[pt_BR]=$_ZZ_NOME_NOVO|" \
    -e "s|^Icon=.*|Icon=$_ZZ_ICONE|" \
    "$(_zz_fonte)"
}

_zz_icone_velho() {
  printf '%s' "$(_zz_tema_dir)/scalable/apps/$_ZZ_ICONE.svg"
}

_zz_do_pack() {
  MEOW_PACK_DIR="$(meow_pack_dir)" python3 "$MEOW_RAIZ/scripts/pack.py" fontes 2>/dev/null \
    | awk -F'\t' -v n="$_ZZ_ICONE" '$1 == n { achou = 1 } END { exit !achou }'
}

_ZZ_CONF="$HOME/.var/app/$_ZZ_APP/config/ZapZap/ZapZap.conf"
_ZZ_TRAY_DESEJADO="${ZAPZAP_TRAY:-symbolic_light}"

_zz_tray_atual() {
  [ -f "$_ZZ_CONF" ] || { printf 'default'; return; }
  local v
  v="$(awk -F= '/^\[/{s=$0} s=="[system]" && /^tray_theme=/{print $2; exit}' "$_ZZ_CONF")"
  printf '%s' "${v:-default}"
}

_zz_conf_com_tray() {
  local desejado="$1"
  [ -f "$_ZZ_CONF" ] || return 1
  python3 -I - "$_ZZ_CONF" "$desejado" <<'PY'
import sys, re
caminho, valor = sys.argv[1], sys.argv[2]
linhas = open(caminho, encoding='utf-8').read().split('\n')
saida, secao, escrito = [], None, False
for l in linhas:
    if l.startswith('['):
        if secao == '[system]' and not escrito:
            saida.append(f'tray_theme={valor}'); escrito = True
        secao = l.strip()
    if re.match(r'^tray_theme=', l) and secao == '[system]':
        saida.append(f'tray_theme={valor}'); escrito = True; continue
    saida.append(l)
if not escrito:
    if secao != '[system]':
        saida.append('[system]')
    saida.append(f'tray_theme={valor}')
sys.stdout.write('\n'.join(saida))
PY
}

_ZZ_CSS_DIR="$HOME/.var/app/$_ZZ_APP/data/ZapZap/customizations/global/css"
_ZZ_CSS="$_ZZ_CSS_DIR/MeowSystem.css"
_ZZ_MODELO_PY="$MEOW_RAIZ/scripts/temas-de-apps/modelo.py"

_zz_css_marca() {
  sed -n 's|^ \* meowsystem-tema: \([^ ]*\).*$|\1|p' "$1" 2>/dev/null | head -n 1
}

_zz_css_de_terceiro() {
  local f
  for f in "$_ZZ_CSS_DIR"/*; do
    [ -f "$f" ] || continue
    case "${f,,}" in *.css) ;; *) continue ;; esac
    [ "$f" = "$_ZZ_CSS" ] && [ -n "$(_zz_css_marca "$f")" ] && continue
    printf '%s\n' "$f"
  done
}

_zz_css_ligado() {
  [ -f "$_ZZ_CONF" ] || return 1
  awk -F= '/^\[/{s=$0} s=="[custom]" && $1=="global\\css\\enabled"{v=$2} END{exit !(v=="true")}' "$_ZZ_CONF"
}

_zz_conf_css() {
  [ -f "$_ZZ_CONF" ] || return 1
  python3 -I - "$_ZZ_CONF" "$1" <<'PY'
import sys
caminho, modo = sys.argv[1], sys.argv[2]
CHAVE = 'global\\css\\enabled'
linhas = open(caminho, encoding='utf-8').read().split('\n')
ini = next((i for i, l in enumerate(linhas) if l.strip() == '[custom]'), None)
if ini is None:
    if modo == 'ligar':
        while linhas and linhas[-1] == '':
            linhas.pop()
        linhas += ['', '[custom]', CHAVE + '=true', '']
else:
    fim = next((i for i in range(ini + 1, len(linhas)) if linhas[i].startswith('[')), len(linhas))
    achadas = [i for i in range(ini + 1, fim) if linhas[i].split('=', 1)[0] == CHAVE]
    if modo == 'ligar':
        if achadas:
            linhas[achadas[0]] = CHAVE + '=true'
        else:
            linhas.insert(ini + 1, CHAVE + '=true')
    else:
        for i in reversed(achadas):
            del linhas[i]
        fim -= len(achadas)
        if all(not l.strip() for l in linhas[ini + 1:fim]):
            del linhas[ini:fim]
sys.stdout.write('\n'.join(linhas))
PY
}

_zz_css_do_pack() {
  _ZZ_CSS_DESEJADO=""; _ZZ_CSS_QUERO=""; _ZZ_CSS_ERRO=""
  meow_app_tema_do_pack zapzap.arquivo
  _ZZ_CSS_DE="$MEOW_APP_TEMA_PACK"
  [ -n "$MEOW_APP_TEMA" ] || return 1
  _ZZ_CSS_QUERO="$_ZZ_CSS_DE/${FLAVOR:-}"
  [[ "$_ZZ_CSS_QUERO" =~ ^[A-Za-z0-9_-]+/[A-Za-z0-9_-]+$ ]] \
    || { _ZZ_CSS_ERRO="pack ou flavor com nome fora do padrão ('$_ZZ_CSS_QUERO')"; return 2; }
  _ZZ_CSS_DESEJADO="$(python3 "$_ZZ_MODELO_PY" "$MEOW_APP_TEMA" "$(meow_paleta)" "${FLAVOR:-}" "$_ZZ_CSS_DE" 2>&1)" \
    || { _ZZ_CSS_ERRO="$_ZZ_CSS_DESEJADO"; _ZZ_CSS_DESEJADO=""; return 2; }
  return 0
}

_zz_css_conferir() {
  local marca rc
  marca="$(_zz_css_marca "$_ZZ_CSS")"
  _zz_css_do_pack; rc=$?
  if [ "$rc" = 1 ]; then
    [ -z "$marca" ] && return "$MEOW_OK"
    meow_muda "ZapZap: o pack no ar não traz tema para o WhatsApp, e o do MeowSystem ('$marca') continua lá"
    return "$MEOW_DIVERGENTE"
  fi
  [ "$rc" = 2 ] && { meow_aviso "ZapZap: o modelo do tema não montou — $_ZZ_CSS_ERRO"; return "$MEOW_SEM_DEPENDENCIA"; }
  [ -f "$_ZZ_CONF" ] || return "$MEOW_OK"
  if [ -z "$marca" ]; then
    if [ -n "$(_zz_css_de_terceiro)" ]; then
      meow_pula "ZapZap: há CSS que não veio daqui em $_ZZ_CSS_DIR — não é tocado"
      return "$MEOW_SEM_DEPENDENCIA"
    fi
    meow_muda "ZapZap: o tema do pack ainda não está no WhatsApp"
    return "$MEOW_DIVERGENTE"
  fi
  if [ "$(cat "$_ZZ_CSS")" != "$_ZZ_CSS_DESEJADO" ]; then
    meow_muda "ZapZap: o WhatsApp está em '$marca', e o de agora é '$_ZZ_CSS_QUERO' (ou o modelo mudou)"
    return "$MEOW_DIVERGENTE"
  fi
  _zz_css_ligado || { meow_muda "ZapZap: o tema está na pasta, e o CSS está desligado no ZapZap"; return "$MEOW_DIVERGENTE"; }
  meow_ok "ZapZap: o WhatsApp está no tema do pack (do pack $_ZZ_CSS_DE) — $_ZZ_CSS_QUERO"
  return "$MEOW_OK"
}

_zz_css_tirar() {
  [ -n "$(_zz_css_marca "$_ZZ_CSS")" ] || return "$MEOW_OK"
  if meow_seco; then
    meow_muda "ZapZap: tiraria $_ZZ_CSS"
    return "$MEOW_DIVERGENTE"
  fi
  rm -f -- "$_ZZ_CSS" || { meow_erro "ZapZap: não consegui tirar $_ZZ_CSS"; return "$MEOW_ERRO"; }
  meow_ok "ZapZap: o tema do pack saiu do WhatsApp (vale quando o ZapZap reabrir)"
  if _zz_css_ligado && [ -z "$(_zz_css_de_terceiro)" ]; then
    local novo
    if ! novo="$(_zz_conf_css tirar)" || ! printf '%s' "$novo" > "$_ZZ_CONF" 2>/dev/null; then
      meow_aviso "ZapZap: não consegui desligar o CSS no ZapZap.conf"
    fi
  fi
  return "$MEOW_DIVERGENTE"
}

_zz_css_aplicar() {
  local marca rc no_ar mudou=0 novo
  _zz_css_do_pack; rc=$?
  [ "$rc" = 1 ] && { _zz_css_tirar; return; }
  [ "$rc" = 2 ] && { meow_aviso "ZapZap: o modelo do tema não montou — $_ZZ_CSS_ERRO"; return "$MEOW_SEM_DEPENDENCIA"; }
  [ -f "$_ZZ_CONF" ] || { meow_info "ZapZap: o tema do WhatsApp entra depois que o ZapZap abrir uma vez"; return "$MEOW_OK"; }

  marca="$(_zz_css_marca "$_ZZ_CSS")"
  if [ -n "$marca" ]; then
    [ "$marca" = "$_ZZ_CSS_QUERO" ] \
      || meow_muda "ZapZap: o WhatsApp estava em '$marca' — passa a '$_ZZ_CSS_QUERO'"
  else
    no_ar="$(_zz_css_de_terceiro | head -n 1)"
    meow_app_tema_no_ar zapzap "$no_ar" "$_ZZ_CSS_QUERO" "$_ZZ_CSS_DE" pergunte
    [ $? = "$MEOW_DIVERGENTE" ] || return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_escrever "$_ZZ_CSS" "$_ZZ_CSS_DESEJADO" 644
  case $? in
    1) mudou=1 ;;
    2) meow_erro "ZapZap: falhou ao escrever $_ZZ_CSS"; return "$MEOW_ERRO" ;;
  esac
  if ! _zz_css_ligado; then
    novo="$(_zz_conf_css ligar)" || { meow_erro "ZapZap: não consegui ler o ZapZap.conf"; return "$MEOW_ERRO"; }
    meow_escrever "$_ZZ_CONF" "$novo" 644
    case $? in
      1) mudou=1 ;;
      2) meow_erro "ZapZap: não consegui ligar o CSS no ZapZap.conf"; return "$MEOW_ERRO" ;;
    esac
  fi
  [ "$mudou" = 1 ] || return "$MEOW_OK"
  meow_seco || meow_ok "ZapZap: o WhatsApp veste o tema do pack (do pack $_ZZ_CSS_DE) — $_ZZ_CSS_QUERO (vale quando o ZapZap reabrir)"
  return "$MEOW_DIVERGENTE"
}

meow_app_instalado() { meow_flatpak_tem "$_ZZ_APP"; }

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_tem flatpak || { meow_app_sem "ZapZap: o flatpak não está instalado"; return; }
  meow_app_instalado || { meow_app_sem "ZapZap: $_ZZ_APP não está instalado"; return; }
  [ -f "$_ZZ_ORIGEM" ] || { meow_app_sem "ZapZap: não achei o .desktop do flatpak em $_ZZ_ORIGEM"; return; }
  meow_tem python3 || { meow_app_sem "ZapZap: falta python3, que escreve a chave da bandeja no ZapZap.conf"; return; }
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"

  [ -f "$_ZZ_DESTINO" ] || return "$MEOW_DIVERGENTE"
  [ "$(_zz_desktop_desejado)" = "$(cat "$_ZZ_DESTINO")" ] || return "$MEOW_DIVERGENTE"
  [ ! -f "$(_zz_icone_velho)" ] || _zz_do_pack || return "$MEOW_DIVERGENTE"

  if [ -f "$_ZZ_CONF" ] && [ "$(_zz_tray_atual)" != "$_ZZ_TRAY_DESEJADO" ]; then
    return "$MEOW_DIVERGENTE"
  fi

  _zz_css_conferir || return $?

  meow_ok "ZapZap já aparece como '$_ZZ_NOME_NOVO' com o ícone $(_zz_pack_nome)"
  return "$MEOW_OK"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente zapzap; return; }
  meow_app_conferir >/dev/null 2>&1 && {
    meow_ok "ZapZap já aparece como '$_ZZ_NOME_NOVO' — nada a fazer"
    return "$MEOW_OK"
  }

  local icone; icone="$(_zz_icone_velho)"
  local mudou=0

  _zz_guardar_original

  if [ -f "$icone" ] && ! _zz_do_pack; then
    if meow_seco; then
      meow_muda "removeria $icone (o glifo de traço do Arcticons é o que vale)"
      mudou=1
    elif meow_destino_permitido "$icone" && rm -f "$icone"; then
      mudou=1
      meow_info "balão verde retirado de scalable/apps — quem veste é o apps-arcticons.map"
    else
      meow_aviso "não consegui remover $icone — o balão cheio continua vencendo"
    fi
  fi

  meow_escrever "$_ZZ_DESTINO" "$(_zz_desktop_desejado)" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao escrever o .desktop"; return "$MEOW_ERRO" ;; esac

  if [ -f "$_ZZ_CONF" ] && [ "$(_zz_tray_atual)" != "$_ZZ_TRAY_DESEJADO" ]; then
    local novo
    if novo="$(_zz_conf_com_tray "$_ZZ_TRAY_DESEJADO")" && [ -n "$novo" ]; then
      meow_escrever "$_ZZ_CONF" "$novo" 644
      case $? in
        1) mudou=1
           meow_info "ícone da bandeja: $_ZZ_TRAY_DESEJADO (vale quando o ZapZap reabrir)" ;;
        2) meow_aviso "não consegui escrever o ZapZap.conf — bandeja fica como está" ;;
      esac
    fi
  fi

  local tema=0
  _zz_css_aplicar
  case $? in
    1) tema=1 ;;
    2) return "$MEOW_ERRO" ;;
    3) tema=3 ;;
  esac

  if [ "$mudou" = "0" ]; then
    [ "$tema" = 1 ] && return "$MEOW_DIVERGENTE"
    [ "$tema" = 3 ] && return "$MEOW_SEM_DEPENDENCIA"
    return "$MEOW_OK"
  fi
  meow_seco && return "$MEOW_DIVERGENTE"

  meow_tem update-desktop-database && \
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

  meow_lancador_reler

  meow_ok "ZapZap agora aparece como '$_ZZ_NOME_NOVO' (o ícone vem do apps-arcticons.map)"
  return "$MEOW_DIVERGENTE"
}

meow_app_reverter() {
  meow_app_detectar || { meow_app_pendente zapzap; return; }

  local css_mudou=0
  _zz_css_tirar
  case $? in 1) css_mudou=1 ;; 2) return "$MEOW_ERRO" ;; esac

  if [ ! -L "$_ZZ_ORIGEM" ] && [ ! -f "$_ZZ_GUARDADO" ]; then
    meow_aviso "não achei o original em $(basename "$_ZZ_GUARDADO") — não invento um .desktop de flatpak"
    meow_info "  o flatpak recria o dele: flatpak update com.rtosta.zapzap  (ou flatpak repair --user)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local mudou="$css_mudou"
  local tray_atual; tray_atual="$(_zz_tray_atual)"

  if meow_seco; then
    [ -f "$_ZZ_GUARDADO" ] && meow_muda "devolveria o .desktop de fábrica (nome 'ZapZap' de volta)"
    [ "$tray_atual" != "default" ] && meow_muda "devolveria tray_theme=default no ZapZap.conf"
    return "$MEOW_DIVERGENTE"
  fi

  if [ -f "$_ZZ_GUARDADO" ]; then
    if cp -f "$_ZZ_GUARDADO" "$_ZZ_DESTINO" 2>/dev/null; then
      rm -f "$_ZZ_GUARDADO"
      mudou=1
      meow_ok "o .desktop voltou ao de fábrica — o app chama-se 'ZapZap' de novo"
    else
      meow_erro "não consegui devolver $_ZZ_DESTINO"
      return "$MEOW_ERRO"
    fi
  fi

  if [ -f "$_ZZ_CONF" ] && [ "$tray_atual" != "default" ]; then
    local novo
    if novo="$(_zz_conf_com_tray default)" && [ -n "$novo" ]; then
      if printf '%s' "$novo" > "$_ZZ_CONF" 2>/dev/null; then
        mudou=1
        meow_ok "ícone da bandeja: default (vale quando o ZapZap reabrir)"
      else
        meow_aviso "não consegui escrever o ZapZap.conf — a bandeja fica símbolica"
      fi
    fi
  fi

  [ "$mudou" = "0" ] && { meow_ok "ZapZap já estava como de fábrica"; return "$MEOW_OK"; }

  meow_tem update-desktop-database && \
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

  meow_info "o ícone da bandeja segue vestido na FONTE do app (tray_icon.py do flatpak)"
  meow_info "  para devolver aquele: flatpak update com.rtosta.zapzap — ver packs/meowsystem/icones/bandeja.map"
  meow_info "tire 'zapzap' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}

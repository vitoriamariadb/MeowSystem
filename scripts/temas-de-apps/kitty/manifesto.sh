#!/usr/bin/env bash

_KITTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
_KITTY_TEMA="$_KITTY_DIR/current-theme.conf"
_KITTY_CONF="$_KITTY_DIR/kitty.conf"
_KITTY_ANTES="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/temas-de-apps/kitty/current-theme.conf.antes"
_KITTY_MODELO_PY="$MEOW_RAIZ/scripts/temas-de-apps/modelo.py"

_kitty_instalado() {
  meow_tem kitty || [ -x "$HOME/.local/kitty.app/bin/kitty" ]
}

_kitty_marca() {
  sed -n 's/^# meowsystem-tema: \([^ ]*\).*$/\1/p' "$1" 2>/dev/null | head -n 1
}

_kitty_conf_tem_cor() {
  [ -f "$_KITTY_CONF" ] || return 1
  python3 -I - "$_KITTY_CONF" <<'PY'
import glob, os, re, sys

COR = re.compile(r"^\s*(foreground|background|color[0-9]+)\s")
INC = re.compile(r"^\s*(include|globinclude)\s+(.+?)\s*$")
vistos = set()


def linhas(arq):
    with open(arq, encoding="utf-8", errors="replace") as f:
        return f.read().split("\n")


def alvos(tipo, valor, pasta):
    alvo = os.path.expanduser(os.path.expandvars(valor))
    if not os.path.isabs(alvo):
        alvo = os.path.join(pasta, alvo)
    return sorted(glob.glob(alvo)) if tipo == "globinclude" else [alvo]


def pinta(arq):
    real = os.path.realpath(arq)
    if real in vistos:
        return False
    vistos.add(real)
    try:
        ls = linhas(arq)
    except FileNotFoundError:
        return False
    except OSError:
        return True
    for l in ls:
        if COR.match(l):
            return True
        m = INC.match(l)
        if m and any(pinta(a) for a in alvos(m.group(1), m.group(2), os.path.dirname(arq))):
            return True
    return False


conf = sys.argv[1]
vistos.add(os.path.realpath(conf))
try:
    raiz = linhas(conf)
except OSError:
    print("o kitty.conf, que não se deixa ler")
    sys.exit(0)
dentro = False
for l in raiz:
    if l.startswith("# BEGIN_KITTY_THEME"):
        dentro = True
    elif l.startswith("# END_KITTY_THEME"):
        dentro = False
    elif not dentro:
        if COR.match(l):
            print("as cores escritas no próprio kitty.conf")
            sys.exit(0)
        m = INC.match(l)
        if m and any(pinta(a) for a in alvos(m.group(1), m.group(2), os.path.dirname(conf))):
            print(f"{m.group(2)} (incluído pelo kitty.conf)")
            sys.exit(0)
sys.exit(1)
PY
}

_kitty_no_ar() {
  local de_la
  _KITTY_NO_AR=""; _KITTY_NOSSO=0
  if [ -f "$_KITTY_TEMA" ]; then
    _KITTY_NO_AR="$(_kitty_marca "$_KITTY_TEMA")"
    if [ -n "$_KITTY_NO_AR" ]; then _KITTY_NOSSO=1; else _KITTY_NO_AR="$_KITTY_TEMA"; fi
  elif de_la="$(_kitty_conf_tem_cor)"; then
    _KITTY_NO_AR="$de_la"
  fi
}

_kitty_bloco() {
  printf '# BEGIN_KITTY_THEME\n# %s (MeowSystem)\ninclude current-theme.conf\n# END_KITTY_THEME' "$1"
}

_kitty_bloco_presente() {
  [ -f "$_KITTY_CONF" ] || return 1
  awk -v b="$_KITTY_BLOCO" 'BEGIN { RS = "\001" } index($0, b) { achou = 1 } END { exit !achou }' "$_KITTY_CONF"
}

_kitty_conf_com_bloco() {
  local bloco="$1" resto=""
  [ -f "$_KITTY_CONF" ] && resto="$(awk '
      /^# BEGIN_KITTY_THEME/ { dentro = 1; next }
      /^# END_KITTY_THEME/   { dentro = 0; next }
      !dentro { print }
    ' "$_KITTY_CONF")"
  if [ -n "$resto" ] && [ -n "$bloco" ]; then
    printf '%s\n\n%s' "$resto" "$bloco"
  else
    printf '%s%s' "$resto" "$bloco"
  fi
}

_kitty_gravar_conf() {
  local novo="$1" tmp
  meow_destino_permitido "$_KITTY_CONF" || return "$MEOW_ERRO"
  if [ -z "$novo" ]; then
    [ -f "$_KITTY_CONF" ] || return "$MEOW_OK"
    if meow_seco; then meow_muda "tiraria $_KITTY_CONF, que só tinha o bloco do tema"; return "$MEOW_DIVERGENTE"; fi
    rm -f -- "$_KITTY_CONF" || return "$MEOW_ERRO"
    return "$MEOW_DIVERGENTE"
  fi
  [ -f "$_KITTY_CONF" ] && [ "$novo" = "$(cat "$_KITTY_CONF")" ] && return "$MEOW_OK"
  if meow_seco; then meow_muda "mudaria o bloco do tema em $_KITTY_CONF"; return "$MEOW_DIVERGENTE"; fi
  mkdir -p "$_KITTY_DIR" || return "$MEOW_ERRO"
  tmp="$(mktemp -p "$_KITTY_DIR" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  printf '%s\n' "$novo" > "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod --reference="$_KITTY_CONF" "$tmp" 2>/dev/null || chmod 644 "$tmp"
  mv -f "$tmp" "$_KITTY_CONF" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"
}

meow_app_instalado() { _kitty_instalado; }

_KITTY_CHAVES_DE_COR='^(foreground|background|selection_foreground|selection_background|cursor|cursor_text_color|url_color|color[0-9]|color[1-9][0-9]|color1[0-9][0-9]|color2[0-4][0-9]|color25[0-5]|active_border_color|inactive_border_color|bell_border_color|active_tab_foreground|active_tab_background|active_tab_font_style|inactive_tab_foreground|inactive_tab_background|inactive_tab_font_style|tab_bar_background|tab_bar_margin_color|mark[1-3]_foreground|mark[1-3]_background|wayland_titlebar_color|macos_titlebar_color)$'
_kitty_so_cor() {
  local fora
  fora="$(printf '%s\n' "$_KITTY_DESEJADO" \
    | awk -v re="$_KITTY_CHAVES_DE_COR" '!/^[ \t]*(#|$)/ && $1 !~ re' | wc -l)"
  _KITTY_DESEJADO="$(printf '%s\n' "$_KITTY_DESEJADO" \
    | awk -v re="$_KITTY_CHAVES_DE_COR" '/^[ \t]*(#|$)/ || $1 ~ re')"
  [ "$fora" -gt 0 ] && meow_aviso "kitty: $fora linha(s) do modelo do pack $_KITTY_DE que não são cor ficaram de fora"
  return 0
}

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "kitty: não está instalado"; return; }
  meow_tem python3 || { meow_app_sem "kitty: falta python3, que monta o tema com a paleta do pack"; return; }
  meow_app_tema_do_pack kitty.arquivo
  _KITTY_DE="$MEOW_APP_TEMA_PACK"
  [ -n "$MEOW_APP_TEMA" ] || { meow_app_sem "kitty: o pack no ar não declara tema para o kitty"; return; }
  _KITTY_QUERO="$_KITTY_DE/${FLAVOR:-}"
  _KITTY_DESEJADO="$(python3 "$_KITTY_MODELO_PY" "$MEOW_APP_TEMA" "$(meow_paleta)" "${FLAVOR:-}" "$_KITTY_DE" 2>&1)" \
    || { meow_app_sem "kitty: o modelo do pack $_KITTY_DE não montou — $_KITTY_DESEJADO"; return; }
  _kitty_so_cor
  _KITTY_NOME="$(python3 "$_KITTY_MODELO_PY" --nome "$(meow_paleta)" "${FLAVOR:-}" 2>/dev/null)"
  _KITTY_BLOCO="$(_kitty_bloco "$_KITTY_NOME")"
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _kitty_no_ar
  if [ "$_KITTY_NOSSO" != 1 ]; then
    if [ -z "$_KITTY_NO_AR" ]; then
      meow_muda "kitty: está sem tema — o pack $_KITTY_DE traz '$_KITTY_NOME'"
      return "$MEOW_DIVERGENTE"
    fi
    meow_pula "kitty: está em '$_KITTY_NO_AR', que não veio daqui — trocar é decisão sua"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ "$(cat "$_KITTY_TEMA")" != "$_KITTY_DESEJADO" ]; then
    meow_muda "kitty: o tema do MeowSystem no disco é '$_KITTY_NO_AR', e o de agora é '$_KITTY_QUERO' (ou o modelo mudou)"
    return "$MEOW_DIVERGENTE"
  fi
  if ! _kitty_bloco_presente; then
    meow_muda "kitty: o tema está no disco, mas o kitty.conf não o inclui"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "kitty: já está no tema do pack (do pack $_KITTY_DE) — $_KITTY_QUERO"
  return "$MEOW_OK"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente kitty; return; }
  _kitty_no_ar
  local mudou=0

  if [ "$_KITTY_NOSSO" = 1 ]; then
    [ "$_KITTY_NO_AR" = "$_KITTY_QUERO" ] \
      || meow_muda "kitty: o tema do MeowSystem estava em '$_KITTY_NO_AR' — passa a '$_KITTY_QUERO'"
  else
    meow_app_tema_no_ar kitty "$_KITTY_NO_AR" "$_KITTY_QUERO" "$_KITTY_DE" pergunte
    [ $? = "$MEOW_DIVERGENTE" ] || return "$MEOW_SEM_DEPENDENCIA"
    if [ -f "$_KITTY_TEMA" ] && [ ! -f "$_KITTY_ANTES" ] && ! meow_seco; then
      mkdir -p "$(dirname "$_KITTY_ANTES")" && cp -a -- "$_KITTY_TEMA" "$_KITTY_ANTES" \
        || { meow_erro "kitty: não consegui guardar o seu tema antes de trocar"; return "$MEOW_ERRO"; }
      meow_info "kitty: o seu tema ficou guardado em $_KITTY_ANTES"
    fi
  fi

  meow_escrever "$_KITTY_TEMA" "$_KITTY_DESEJADO" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "kitty: falhou ao escrever $_KITTY_TEMA"; return "$MEOW_ERRO" ;; esac

  if ! _kitty_bloco_presente; then
    _kitty_gravar_conf "$(_kitty_conf_com_bloco "$_KITTY_BLOCO")"
    case $? in 1) mudou=1 ;; 2) meow_erro "kitty: falhou ao escrever $_KITTY_CONF"; return "$MEOW_ERRO" ;; esac
  fi

  if [ "$mudou" = 0 ]; then
    meow_app_tema_no_ar kitty "$_KITTY_QUERO" "$_KITTY_QUERO" "$_KITTY_DE"
    return "$MEOW_OK"
  fi
  meow_seco && return "$MEOW_DIVERGENTE"
  meow_ok "kitty: tema do pack aplicado — $_KITTY_NOME (vale na próxima janela, ou ctrl+shift+F5)"
  return "$MEOW_DIVERGENTE"
}

meow_app_reverter() {
  local marca bloco=""
  marca="$(_kitty_marca "$_KITTY_TEMA")"
  if [ -z "$marca" ]; then
    meow_ok "kitty: nenhum tema do MeowSystem no disco — nada a desfazer"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "kitty: tiraria o tema do pack ($marca)$([ -f "$_KITTY_ANTES" ] && printf ' e devolveria o seu')"
    return "$MEOW_DIVERGENTE"
  fi
  if [ -f "$_KITTY_ANTES" ]; then
    cp -a -- "$_KITTY_ANTES" "$_KITTY_TEMA" && rm -f -- "$_KITTY_ANTES" \
      || { meow_erro "kitty: não consegui devolver o seu tema"; return "$MEOW_ERRO"; }
    bloco="$(printf '# BEGIN_KITTY_THEME\ninclude current-theme.conf\n# END_KITTY_THEME')"
    meow_ok "kitty: o seu tema voltou para $_KITTY_TEMA"
  else
    rm -f -- "$_KITTY_TEMA" || { meow_erro "kitty: não consegui tirar $_KITTY_TEMA"; return "$MEOW_ERRO"; }
    meow_ok "kitty: o tema do pack saiu do kitty"
  fi
  if [ -f "$_KITTY_CONF" ] && grep -q '^# .* (MeowSystem)$' "$_KITTY_CONF"; then
    _kitty_gravar_conf "$(_kitty_conf_com_bloco "$bloco")"
    [ $? = "$MEOW_ERRO" ] && { meow_erro "kitty: não consegui tirar o bloco do tema do kitty.conf"; return "$MEOW_ERRO"; }
  fi
  meow_info "tire 'kitty' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}

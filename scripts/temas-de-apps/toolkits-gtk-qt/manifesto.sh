#!/usr/bin/env bash

MEOW_TK_GTK3_CSS="$HOME/.config/gtk-3.0/gtk.css"
MEOW_TK_GTK4_CSS="$HOME/.config/gtk-4.0/gtk.css"
MEOW_TK_COSMIC_CSS_DIR="$HOME/.config/gtk-4.0/cosmic"
MEOW_TK_TK_DIR="$(meow_cosmic_dir)/com.system76.CosmicTk/$(meow_cosmic_v com.system76.CosmicTk)"
MEOW_TK_QT5_CONF="$HOME/.config/qt5ct/qt5ct.conf"
MEOW_TK_QT6_CONF="$HOME/.config/qt6ct/qt6ct.conf"

MEOW_TK_BACKUP_DIR=""

_meow_tk_ler_tk() {
  local chave="${1:-}" bruto=""
  [ -r "$MEOW_TK_TK_DIR/$chave" ] || return 1
  bruto="$(cat "$MEOW_TK_TK_DIR/$chave" 2>/dev/null)" || return 1
  bruto="${bruto%\"}"; bruto="${bruto#\"}"
  printf '%s' "$bruto"
}

_meow_tk_ini_ler() {
  local arquivo="${1:-}" chave="${2:-}"
  [ -r "$arquivo" ] || return 1
  MEOW_INI_CHAVE="$chave" awk '
    BEGIN { chave = ENVIRON["MEOW_INI_CHAVE"]; achou = 0 }
    /^\[/ { na = ($0 == "[Appearance]"); next }
    na && index($0, chave "=") == 1 { print substr($0, length(chave) + 2); achou = 1; exit }
    END { if (!achou) exit 1 }
  ' "$arquivo"
}

_meow_tk_ini_definir() {
  local arquivo="${1:-}" chave="${2:-}" valor="${3:-}"
  if [ ! -r "$arquivo" ]; then
    printf '[Appearance]\n%s=%s\n' "$chave" "$valor"
    return 0
  fi
  MEOW_INI_CHAVE="$chave" MEOW_INI_VALOR="$valor" awk '
    BEGIN { chave = ENVIRON["MEOW_INI_CHAVE"]; valor = ENVIRON["MEOW_INI_VALOR"]
            posto = 0; na = 0; viu = 0; nbuf = 0 }
    function despejar(   i) { for (i = 1; i <= nbuf; i++) print buf[i]; nbuf = 0 }
    function por() { if (!posto) { print chave "=" valor; posto = 1 } }
    /^\[/ {
      if (na) por()
      despejar()
      na = ($0 == "[Appearance]"); if (na) viu = 1
      print; next
    }
    /^[ \t]*$/ { buf[++nbuf] = $0; next }
    {
      despejar()
      # troca no lugar, preservando a posição original da chave
      if (na && index($0, chave "=") == 1) { por(); next }
      print
    }
    END {
      if (na) por()
      vazias = nbuf
      despejar()
      if (!viu) {
        if (!vazias && NR > 0) print ""
        printf "[Appearance]\n%s=%s\n", chave, valor
      }
    }
  ' "$arquivo"
}

_meow_tk_backup() {
  local origem="${1:-}" rel="" destino=""
  meow_guardar_antes "$1"
  [ -e "$origem" ] || [ -L "$origem" ] || return 0
  meow_seco && return 0
  if [ -z "$MEOW_TK_BACKUP_DIR" ]; then
    MEOW_TK_BACKUP_DIR="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/backups/${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"
  fi
  case "$origem" in
    "$HOME"/*) rel="${origem#"$HOME"/}" ;;
    *)         rel="fora-da-home/${origem#/}" ;;
  esac
  destino="$MEOW_TK_BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$destino")" || return 1
  cp -P --preserve=all -- "$origem" "$destino" || return 1
  printf '%s\n' "$origem" >> "$MEOW_TK_BACKUP_DIR/origens.txt" || return 1
  if [ ! -L "$origem" ] && [ -f "$origem" ]; then
    ( cd "$MEOW_TK_BACKUP_DIR" && sha256sum -- "$rel" >> manifesto.sha256 ) || return 1
  fi
  meow_info "backup: $destino"
  return 0
}

_meow_tk_css_gerado() {
  local c
  for c in "$MEOW_TK_COSMIC_CSS_DIR/dark.css" "$MEOW_TK_COSMIC_CSS_DIR/light.css"; do
    if [ -r "$c" ]; then printf '%s' "$c"; return 0; fi
  done
  return 1
}

_meow_tk_gtk_estado() {
  local css="${1:-}" alvo="" gerado=""
  if [ -L "$css" ]; then
    alvo="$(readlink -m -- "$css")"
    case "$alvo" in
      "$MEOW_TK_COSMIC_CSS_DIR"/*.css)
        if [ -e "$css" ]; then printf 'ok'; else printf 'link-quebrado'; fi ;;
      *) printf 'link-alheio' ;;
    esac
    return 0
  fi
  if [ ! -e "$css" ]; then printf 'ausente'; return 0; fi
  if ! gerado="$(_meow_tk_css_gerado)"; then printf 'arquivo-sem-fonte'; return 0; fi
  if cmp -s "$css" "$gerado"; then printf 'arquivo-igual'; else printf 'arquivo-proprio'; fi
  return 0
}

_meow_tk_curto() { printf '%s/%s' "$(basename "$(dirname "${1:-}")")" "$(basename "${1:-}")"; }

_meow_tk_qt_presente() { meow_tem qt5ct || meow_tem qt6ct; }

_meow_tk_conf_vale() {
  case "${1:-}" in
    *qt5ct*) meow_tem qt5ct ;;
    *qt6ct*) meow_tem qt6ct ;;
    *) return 1 ;;
  esac
}

meow_app_instalado() { meow_tem cosmic-settings-daemon || [ -d "$MEOW_TK_TK_DIR" ]; }

meow_app_detectar() {
  if ! meow_app_instalado; then
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"

  local divergente=0 global="" icone_cosmic="" atual="" curto=""

  global="$(_meow_tk_ler_tk apply_theme_global || printf 'ausente')"
  if [ "$global" = "true" ]; then
    meow_ok "CosmicTk apply_theme_global=true — o COSMIC pinta GTK e Qt sozinho"
  else
    meow_aviso "apply_theme_global=$global — GTK e Qt NÃO estão seguindo o tema"
    divergente=1
  fi

  local css
  for css in "$MEOW_TK_GTK3_CSS" "$MEOW_TK_GTK4_CSS"; do
    curto="$(_meow_tk_curto "$css")"
    case "$(_meow_tk_gtk_estado "$css")" in
      ok)
        meow_ok "$curto -> $(readlink -- "$css")" ;;
      arquivo-igual)
        meow_muda "$curto é arquivo comum, cópia exata do css gerado — dá para religar o symlink"
        divergente=1 ;;
      arquivo-proprio)
        meow_aviso "$curto é arquivo comum com conteúdo PRÓPRIO — não mexo; apague-o se quiser o COSMIC de volta" ;;
      arquivo-sem-fonte)
        meow_aviso "$curto é arquivo comum e não há css do COSMIC para comparar" ;;
      link-alheio)
        meow_aviso "$curto aponta para $(readlink -- "$css") — fora do COSMIC; é escolha sua, não mexo" ;;
      link-quebrado)
        meow_aviso "$curto aponta para um css que ainda não existe — o COSMIC gera na próxima troca de tema" ;;
      ausente)
        meow_info "$curto ainda não existe — quem gera é o COSMIC, não este módulo" ;;
    esac
  done

  if ! _meow_tk_qt_presente; then
    meow_pula "qt5ct/qt6ct ausentes — nenhum app Qt para tematizar"
    [ "$divergente" = "1" ] && return "$MEOW_DIVERGENTE"
    return "$MEOW_OK"
  fi

  if meow_tem kvantummanager || [ -d "$HOME/.config/Kvantum" ]; then
    meow_aviso "Kvantum instalado — o estilo dele IGNORA a paleta do qt5ct e desliga a sincronia com o COSMIC"
  fi

  icone_cosmic="$(_meow_tk_ler_tk icon_theme || printf '')"
  if [ -z "$icone_cosmic" ]; then
    meow_pula "CosmicTk sem icon_theme — deixo o breeze-dark do COSMIC em paz"
    [ "$divergente" = "1" ] && return "$MEOW_DIVERGENTE"
    return "$MEOW_OK"
  fi

  local conf
  for conf in "$MEOW_TK_QT5_CONF" "$MEOW_TK_QT6_CONF"; do
    _meow_tk_conf_vale "$conf" || continue
    if [ ! -e "$conf" ]; then
      meow_pula "$(basename "$conf") ainda não existe — quem cria é o cosmic-settings-daemon"
      continue
    fi
    atual="$(_meow_tk_ini_ler "$conf" icon_theme || printf 'ausente')"
    if [ "$atual" = "$icone_cosmic" ]; then
      meow_ok "$(basename "$conf"): icon_theme=$atual"
    else
      meow_muda "$(basename "$conf"): icon_theme=$atual (o COSMIC usa '$icone_cosmic')"
      divergente=1
    fi

    local paleta
    paleta="$(_meow_tk_ini_ler "$conf" color_scheme_path || printf 'ausente')"
    case "$paleta" in
      */colors/Cosmic*.conf) meow_ok "$(basename "$conf"): paleta gerada pelo COSMIC" ;;
      *) meow_aviso "$(basename "$conf"): color_scheme_path=$paleta — fora da sincronia do COSMIC" ;;
    esac
  done

  [ "$divergente" = "1" ] && return "$MEOW_DIVERGENTE"
  return "$MEOW_OK"
}

meow_app_aplicar() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"

  local mudou=0 erro=0 global="" icone_cosmic="" conteudo="" atual="" curto=""

  global="$(_meow_tk_ler_tk apply_theme_global || printf 'ausente')"
  if [ "$global" != "true" ]; then
    if _meow_tk_backup "$MEOW_TK_TK_DIR/apply_theme_global"; then
      meow_escrever "$MEOW_TK_TK_DIR/apply_theme_global" "true" 644
      case $? in
        1) mudou=1; meow_muda "apply_theme_global=true (GTK e Qt voltam a seguir o tema)" ;;
        2) erro=1; meow_erro "não consegui ligar o apply_theme_global" ;;
      esac
    else
      erro=1; meow_erro "backup do apply_theme_global falhou — não escrevi"
    fi
  fi

  local css gerado
  for css in "$MEOW_TK_GTK3_CSS" "$MEOW_TK_GTK4_CSS"; do
    [ "$(_meow_tk_gtk_estado "$css")" = "arquivo-igual" ] || continue
    gerado="$(_meow_tk_css_gerado)" || continue
    curto="$(_meow_tk_curto "$css")"
    if meow_seco; then
      meow_muda "religaria o symlink $curto -> $gerado"
      mudou=1
      continue
    fi
    if ! _meow_tk_backup "$css"; then
      meow_erro "backup de $curto falhou — abortei o religamento"; erro=1; continue
    fi
    if ln -sfn "$gerado" "$css"; then
      mudou=1; meow_muda "symlink religado: $curto -> $gerado"
    else
      erro=1; meow_erro "falhei ao religar $curto"
    fi
  done

  if ! _meow_tk_qt_presente; then
    meow_pula "qt5ct/qt6ct ausentes — nada a aplicar no Qt"
  else
    icone_cosmic="$(_meow_tk_ler_tk icon_theme || printf '')"
    if [ -z "$icone_cosmic" ]; then
      meow_pula "CosmicTk sem icon_theme — não invento tema de ícone para o Qt"
    else
      local conf
      for conf in "$MEOW_TK_QT5_CONF" "$MEOW_TK_QT6_CONF"; do
        _meow_tk_conf_vale "$conf" || continue
        if [ ! -e "$conf" ]; then
          meow_pula "$(basename "$conf") não existe — o daemon cria na próxima troca de tema, e aí eu ponho o ícone"
          continue
        fi
        atual="$(_meow_tk_ini_ler "$conf" icon_theme || printf '')"
        [ "$atual" = "$icone_cosmic" ] && continue

        conteudo="$(_meow_tk_ini_definir "$conf" icon_theme "$icone_cosmic")"
        if [ -z "$conteudo" ]; then
          meow_erro "não consegui montar o conteúdo de $conf"; erro=1; continue
        fi
        if ! _meow_tk_backup "$conf"; then
          meow_erro "backup de $(basename "$conf") falhou — não escrevi"; erro=1; continue
        fi
        meow_escrever "$conf" "$conteudo" 644
        case $? in
          1) mudou=1; meow_muda "$(basename "$conf"): icon_theme=$icone_cosmic" ;;
          2) erro=1; meow_erro "falhei ao escrever $conf" ;;
        esac
      done
    fi
  fi

  [ "$erro" = "1" ] && return "$MEOW_ERRO"
  if [ "$mudou" = "0" ]; then
    meow_ok "GTK3, GTK4, Qt5 e Qt6 já seguem o tema do COSMIC — nada a fazer"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    return "$MEOW_DIVERGENTE"
  fi
  meow_registrar "toolkits-gtk-qt: aplicado (icon_theme=${icone_cosmic:-n/a})"
  return "$MEOW_DIVERGENTE"
}

_MEOW_TK_ICONES_FABRICA="$(ICONES_BASE="${ICONES_BASE:-}" \
  python3 "$MEOW_RAIZ/scripts/pack.py" base-apelidos 2>/dev/null | sed -n 's/^tema=//p')"
_MEOW_TK_ICONES_FABRICA="${_MEOW_TK_ICONES_FABRICA:-Papirus-Dark}"

meow_app_reverter() {
  meow_app_detectar || {
    meow_pula "sem COSMIC aqui — nada a desfazer nos toolkits"
    return "$MEOW_SEM_DEPENDENCIA"
  }

  local mudou=0 erro=0 css curto estado global conf atual conteudo tmp

  global="$(_meow_tk_ler_tk apply_theme_global || printf 'ausente')"
  if [ "$global" = "true" ]; then
    if meow_seco; then
      meow_muda "apply_theme_global voltaria para false"; mudou=1
    elif _meow_tk_backup "$MEOW_TK_TK_DIR/apply_theme_global" \
         && printf '%s' "false" > "$MEOW_TK_TK_DIR/apply_theme_global" 2>/dev/null; then
      mudou=1; meow_muda "apply_theme_global=false (GTK e Qt deixam de seguir o COSMIC)"
    else
      erro=1; meow_erro "não consegui desligar o apply_theme_global"
    fi
  fi

  for css in "$MEOW_TK_GTK3_CSS" "$MEOW_TK_GTK4_CSS"; do
    estado="$(_meow_tk_gtk_estado "$css")"
    [ "$estado" = "ok" ] || continue
    curto="$(_meow_tk_curto "$css")"
    if meow_seco; then
      meow_muda "$curto voltaria a ser arquivo comum (hoje é symlink)"; mudou=1; continue
    fi
    if ! _meow_tk_backup "$css"; then
      erro=1; meow_erro "backup de $curto falhou — não desfiz o link"; continue
    fi
    tmp="$(mktemp -p "$(dirname "$css")" ".meow.XXXXXX")" || { erro=1; continue; }
    if cp -L -- "$css" "$tmp" 2>/dev/null && chmod 644 "$tmp" && mv -f -- "$tmp" "$css"; then
      mudou=1; meow_muda "$curto: symlink desfeito, virou arquivo comum"
    else
      rm -f "$tmp"; erro=1; meow_erro "não consegui desfazer o link de $curto"
    fi
  done

  if _meow_tk_qt_presente; then
    for conf in "$MEOW_TK_QT5_CONF" "$MEOW_TK_QT6_CONF"; do
      _meow_tk_conf_vale "$conf" || continue
      [ -f "$conf" ] || continue
      atual="$(_meow_tk_ini_ler "$conf" icon_theme || printf '')"
      [ "$atual" = "${NOME_TEMA_ICONES:-MeowSystem-Icons}" ] || continue
      if meow_seco; then
        meow_muda "$(basename "$conf"): icon_theme voltaria para $_MEOW_TK_ICONES_FABRICA"; mudou=1; continue
      fi
      if ! conteudo="$(_meow_tk_ini_definir "$conf" icon_theme "$_MEOW_TK_ICONES_FABRICA")"; then
        erro=1; meow_erro "não consegui montar o conteúdo de $conf"; continue
      fi
      if _meow_tk_backup "$conf" && printf '%s' "$conteudo" > "$conf" 2>/dev/null; then
        mudou=1; meow_muda "$(basename "$conf"): icon_theme=$_MEOW_TK_ICONES_FABRICA"
      else
        erro=1; meow_erro "não consegui escrever $conf"
      fi
    done
  fi

  [ "$erro" = "1" ] && return "$MEOW_ERRO"
  [ "$mudou" = "0" ] && { meow_ok "toolkits: já estavam sem a sincronia do MeowSystem"; return "$MEOW_OK"; }
  meow_seco || meow_ok "toolkits: GTK e Qt desligados do tema do COSMIC (vale ao reabrir os apps)"
  meow_seco || meow_info "tire 'qt5ct' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}

#!/usr/bin/env bash

MEOW_BB_REPO_BAT="https://github.com/catppuccin/bat"
MEOW_BB_COMMIT_BAT="6810349b28055dce54076712fc05fc68da4b8ec0"
MEOW_BB_REPO_BTOP="https://github.com/catppuccin/btop"
MEOW_BB_COMMIT_BTOP="f437574b600f1c6d932627050b15ff5153b58fa3"

MEOW_BB_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

_bb_up() {
  local d f; f="$(_bb_flavor)"
  for d in "${MEOW_RAIZ:-$MEOW_BB_DIR/../../..}"/packs/*/temas-de-apps/btop-bat/upstream; do
    if [ -f "$d/btop/$f.theme" ] || compgen -G "$d/btop/*_$f.theme" >/dev/null; then
      printf '%s' "$d"; return 0
    fi
  done
  printf '%s' "${MEOW_RAIZ:-$MEOW_BB_DIR/../../..}/packs/meowsystem/temas-de-apps/btop-bat/upstream"
}

_bb_flavor() {
  if [ -n "${MEOW_FLAVOR:-}" ]; then printf '%s' "$MEOW_FLAVOR"; else meow_flavor; fi
}

_bb_bat_caminho() {
  local bin="$1" flag="$2" reserva="$3" v
  if v="$("$bin" "$flag" 2>/dev/null)" && [ -n "$v" ]; then printf '%s' "$v"; return 0; fi
  printf '%s' "$reserva"
  return 0
}
_bb_bat_cfg_dir()   { _bb_bat_caminho "$1" --config-dir  "${BAT_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/bat}"; }
_bb_bat_cache_dir() { _bb_bat_caminho "$1" --cache-dir   "${BAT_CACHE_PATH:-${XDG_CACHE_HOME:-$HOME/.cache}/bat}"; }
_bb_bat_cfg_file()  { _bb_bat_caminho "$1" --config-file "$(_bb_bat_cfg_dir "$1")/config"; }

_bb_btop_cfg_dir() { printf '%s/btop' "${XDG_CONFIG_HOME:-$HOME/.config}"; }

_bb_bat_bin() {
  if command -v bat >/dev/null 2>&1; then printf 'bat'; return 0; fi
  if command -v batcat >/dev/null 2>&1; then printf 'batcat'; return 0; fi
  return 1
}

_bb_btop_bin() { command -v btop >/dev/null 2>&1; }

_bb_familia() {
  local f arq
  f="$(_bb_flavor)"
  if [ -f "$(_bb_up)/btop/$f.theme" ]; then printf '%s' "$f"; return 0; fi
  for arq in "$(_bb_up)/btop/"*_"$f.theme"; do
    if [ -f "$arq" ]; then
      arq="${arq##*/}"
      printf '%s' "${arq%_"$f".theme}"
      return 0
    fi
  done
  return 0
}
_bb_tem_tema() { [ -n "$(_bb_familia)" ]; }
_bb_avisar_sem_tema() {
  meow_pula "btop/bat: o flavor '$(_bb_flavor)' não tem tema vendorizado em packs/meowsystem/temas-de-apps/btop-bat/upstream — os dois ficam como estão"
}
_bb_familia_titulo() {
  local f; f="$(_bb_familia)"
  printf '%s' "$(printf '%s' "${f:0:1}" | tr '[:lower:]' '[:upper:]')${f:1}"
}

_bb_bat_tema_nome() {
  local f fam; f="$(_bb_flavor)"; fam="$(_bb_familia)"
  local f_tit; f_tit="$(printf '%s' "${f:0:1}" | tr '[:lower:]' '[:upper:]')${f:1}"
  [ "$f" = "$fam" ] && { printf '%s' "$f_tit"; return; }
  printf '%s %s' "$(_bb_familia_titulo)" "$f_tit"
}
_bb_bat_tema_arquivo() { printf '%s/bat/%s.tmTheme' "$(_bb_up)" "$(_bb_bat_tema_nome)"; }

_bb_btop_tema_stem() {
  if [ "${MEOW_BTOP_ACENTO:-}" = "mauve" ]; then
    printf 'meowsystem_%s' "$(_bb_flavor)"
  else
    if [ "$(_bb_flavor)" = "$(_bb_familia)" ]; then printf '%s' "$(_bb_flavor)"
    else printf '%s_%s' "$(_bb_familia)" "$(_bb_flavor)"; fi
  fi
}
_bb_btop_upstream() {
  if [ "$(_bb_flavor)" = "$(_bb_familia)" ]; then
    printf '%s/btop/%s.theme' "$(_bb_up)" "$(_bb_flavor)"
  else
    printf '%s/btop/%s_%s.theme' "$(_bb_up)" "$(_bb_familia)" "$(_bb_flavor)"
  fi
}

_bb_btop_conteudo() {
  local orig; orig="$(_bb_btop_upstream)"
  [ -f "$orig" ] || return 1
  if [ "${MEOW_BTOP_ACENTO:-}" = "mauve" ]; then
    sed -E 's/^(theme\[(hi_fg|selected_fg)\]=")#[0-9A-Fa-f]{6}(")/\1#cba6f7\3/' "$orig"
  else
    cat "$orig"
  fi
}

_bb_carimbo() {
  if [ -z "${MEOW_BB_CARIMBO:-}" ]; then
    MEOW_BB_CARIMBO="${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"
  fi
  printf '%s' "$MEOW_BB_CARIMBO"
}

_bb_backup() {
  local alvo="$1" rel dest
  meow_guardar_antes "$1"
  [ -f "$alvo" ] || return 0
  if meow_seco; then return 0; fi
  case "$alvo" in "$HOME"/*) rel="${alvo#"$HOME"/}" ;; *) rel="fora-da-home/${alvo#/}" ;; esac
  dest="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/backups/$(_bb_carimbo)/$rel"
  mkdir -p "$(dirname "$dest")" || return 1
  cp -p -- "$alvo" "$dest" || return 1
  meow_info "backup: $dest"
  return 0
}

_bb_instalar_stdin() {
  local destino="$1" dir tmp
  meow_destino_permitido "$destino" || return "$MEOW_ERRO"
  dir="$(dirname "$destino")"

  if [ ! -d "$dir" ]; then
    if meow_seco; then
      cat >/dev/null
      meow_muda "mudaria $destino (criaria $dir)"
      return "$MEOW_DIVERGENTE"
    fi
    mkdir -p "$dir" || return "$MEOW_ERRO"
  fi

  if meow_seco; then
    tmp="$(mktemp "${TMPDIR:-/tmp}/meow-seco.XXXXXX")" || return "$MEOW_ERRO"
  else
    tmp="$(mktemp -p "$dir" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  fi
  cat > "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }

  if [ -f "$destino" ] && cmp -s "$tmp" "$destino"; then
    rm -f "$tmp"; return "$MEOW_OK"
  fi
  if meow_seco; then
    rm -f "$tmp"; meow_muda "mudaria $destino"; return "$MEOW_DIVERGENTE"
  fi
  _bb_backup "$destino" || { rm -f "$tmp"; meow_erro "backup de $destino falhou"; return "$MEOW_ERRO"; }
  chmod 644 "$tmp"
  mv -f "$tmp" "$destino" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"
}

_bb_igual_stdin() {
  local destino="$1"
  if [ ! -f "$destino" ]; then cat >/dev/null; return 1; fi
  cmp -s - "$destino"
}

_bb_merge_linha() {
  local arquivo="$1" padrao="$2" nova="$3"
  if [ ! -f "$arquivo" ]; then printf '%s\n' "$nova"; return 0; fi
  awk -v pad="$padrao" -v nova="$nova" '
    { linha[NR] = $0; if ($0 ~ pad) alvo = NR }
    END {
      for (i = 1; i <= NR; i++) print (i == alvo ? nova : linha[i])
      if (!alvo) print nova
    }
  ' "$arquivo"
}

_bb_ultima_linha() {
  if [ ! -f "$1" ]; then return 0; fi
  grep -E -- "$2" "$1" 2>/dev/null | tail -n 1 || true
}

_bb_bat_cache_ok() {
  local bin="$1" tema_dest="$2" nome="$3" bin_cache saida
  bin_cache="$(_bb_bat_cache_dir "$bin")/themes.bin"
  [ -f "$bin_cache" ] || return 1
  [ -f "$tema_dest" ] || return 1
  [ ! "$tema_dest" -nt "$bin_cache" ] || return 1
  if saida="$("$bin" --no-config --paging=never --color=never --list-themes 2>/dev/null)"; then
    case "$saida" in *"$nome"*) : ;; *) return 1 ;; esac
  fi
  return 0
}

_bb_bat_padrao_chave() { printf '^[[:space:]]*--theme([=[:space:]]|$)'; }
_bb_bat_padrao_ok() {
  printf '^[[:space:]]*--theme[[:space:]]*=?[[:space:]]*"?%s"?[[:space:]]*$' "$1"
}

_bb_bat_linha_ok() {
  local cfg="$1" nome="$2" linha
  linha="$(_bb_ultima_linha "$cfg" "$(_bb_bat_padrao_chave)")"
  if [ -z "$linha" ]; then return 1; fi
  printf '%s' "$linha" | grep -Eq "$(_bb_bat_padrao_ok "$nome")"
}

_bb_bat_ambiente_manda() {
  [ -n "${BAT_THEME:-}" ] && [ "${BAT_THEME}" != "$1" ]
}
_bb_bat_avisar_ambiente() {
  meow_aviso "bat: BAT_THEME='${BAT_THEME:-}' no ambiente VENCE o arquivo de config (medido) — o que você vê NÃO é o '$1'. O conserto é tirar a variável do seu shell, e isso mora no arquivo de inicialização do shell, que não é território deste módulo."
}

_bb_bat_conferir() {
  local bin nome origem destino cfg
  bin="$(_bb_bat_bin)" || return "$MEOW_SEM_DEPENDENCIA"
  nome="$(_bb_bat_tema_nome)"; origem="$(_bb_bat_tema_arquivo)"
  destino="$(_bb_bat_cfg_dir "$bin")/themes/$nome.tmTheme"
  cfg="$(_bb_bat_cfg_file "$bin")"

  [ -f "$origem" ] || { meow_erro "falta o tema vendorizado: $origem"; return "$MEOW_ERRO"; }
  cmp -s "$origem" "$destino" || { meow_info "bat: tema '$nome' ausente ou divergente"; return "$MEOW_DIVERGENTE"; }
  _bb_bat_cache_ok "$bin" "$destino" "$nome" || { meow_info "bat: cache não contém '$nome' (falta 'bat cache --build')"; return "$MEOW_DIVERGENTE"; }

  if ! _bb_bat_linha_ok "$cfg" "$nome"; then
    meow_info "bat: o --theme que vale (o último de $cfg) não aponta para '$nome'"
    return "$MEOW_DIVERGENTE"
  fi

  if _bb_bat_ambiente_manda "$nome"; then
    _bb_bat_avisar_ambiente "$nome"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

_bb_bat_aplicar() {
  local bin nome origem destino cfg mudou=0 rc texto
  bin="$(_bb_bat_bin)" || return "$MEOW_SEM_DEPENDENCIA"
  nome="$(_bb_bat_tema_nome)"; origem="$(_bb_bat_tema_arquivo)"
  destino="$(_bb_bat_cfg_dir "$bin")/themes/$nome.tmTheme"
  cfg="$(_bb_bat_cfg_file "$bin")"

  [ -f "$origem" ] || { meow_erro "falta o tema vendorizado: $origem"; return "$MEOW_ERRO"; }

  _bb_instalar_stdin "$destino" < "$origem"; rc=$?
  case $rc in
    1) mudou=1; meow_muda "bat: tema '$nome' instalado em $destino" ;;
    2) meow_erro "bat: falhou ao instalar $destino"; return "$MEOW_ERRO" ;;
  esac

  if ! _bb_bat_linha_ok "$cfg" "$nome"; then
    texto="$(_bb_merge_linha "$cfg" "$(_bb_bat_padrao_chave)" "--theme=\"$nome\"")"
    printf '%s\n' "$texto" | _bb_instalar_stdin "$cfg"
    case $? in
      1) mudou=1; meow_muda "bat: --theme=\"$nome\" gravado em $cfg" ;;
      2) meow_erro "bat: falhou ao gravar $cfg"; return "$MEOW_ERRO" ;;
    esac
  fi

  if ! _bb_bat_cache_ok "$bin" "$destino" "$nome"; then
    if meow_seco; then
      meow_muda "rodaria '$bin cache --build'"
      mudou=1
    else
      meow_info "bat: compilando o cache de temas ($bin cache --build)"
      if "$bin" cache --build >/dev/null 2>&1; then
        mudou=1
      else
        meow_erro "bat: '$bin cache --build' falhou"
        return "$MEOW_ERRO"
      fi
    fi
  fi

  if [ "$mudou" = "1" ] && [ "$bin" = "batcat" ]; then
    meow_aviso "bat: o binário aqui chama-se 'batcat' (colisão com bacula-console-qt no Debian) — o alias é decisão sua, e mora no arquivo de inicialização do shell, que não é território deste módulo"
  fi
  if _bb_bat_ambiente_manda "$nome"; then
    _bb_bat_avisar_ambiente "$nome"
    if [ "$mudou" = "1" ]; then return "$MEOW_DIVERGENTE"; fi
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ "$mudou" = "1" ]; then return "$MEOW_DIVERGENTE"; fi
  return "$MEOW_OK"
}

_bb_btop_padrao_chave() { printf '^[[:space:]]*color_theme[[:space:]]*='; }
_bb_btop_padrao_ok() {
  printf '^[[:space:]]*color_theme[[:space:]]*=[[:space:]]*"(.*/)?%s(\.theme)?"[[:space:]]*$' "$1"
}

_bb_btop_linha_ok() {
  local conf="$1" stem="$2" linha
  linha="$(_bb_ultima_linha "$conf" "$(_bb_btop_padrao_chave)")"
  if [ -z "$linha" ]; then return 1; fi
  printf '%s' "$linha" | grep -Eq "$(_bb_btop_padrao_ok "$stem")"
}

_bb_btop_conferir() {
  local stem destino conf
  _bb_btop_bin || return "$MEOW_SEM_DEPENDENCIA"
  stem="$(_bb_btop_tema_stem)"
  destino="$(_bb_btop_cfg_dir)/themes/$stem.theme"
  conf="$(_bb_btop_cfg_dir)/btop.conf"

  [ -f "$(_bb_btop_upstream)" ] || { meow_erro "falta o tema vendorizado: $(_bb_btop_upstream)"; return "$MEOW_ERRO"; }
  _bb_btop_conteudo | _bb_igual_stdin "$destino" || { meow_info "btop: tema '$stem' ausente ou divergente"; return "$MEOW_DIVERGENTE"; }

  if _bb_btop_linha_ok "$conf" "$stem"; then
    return "$MEOW_OK"
  fi
  meow_info "btop: o color_theme que vale (o último de $conf) não aponta para '$stem'"
  return "$MEOW_DIVERGENTE"
}

_bb_btop_aplicar() {
  local stem destino conf mudou=0 texto
  _bb_btop_bin || return "$MEOW_SEM_DEPENDENCIA"
  stem="$(_bb_btop_tema_stem)"
  destino="$(_bb_btop_cfg_dir)/themes/$stem.theme"
  conf="$(_bb_btop_cfg_dir)/btop.conf"

  [ -f "$(_bb_btop_upstream)" ] || { meow_erro "falta o tema vendorizado: $(_bb_btop_upstream)"; return "$MEOW_ERRO"; }

  _bb_btop_conteudo | _bb_instalar_stdin "$destino"
  case $? in
    1) mudou=1; meow_muda "btop: tema '$stem' instalado em $destino" ;;
    2) meow_erro "btop: falhou ao instalar $destino"; return "$MEOW_ERRO" ;;
  esac

  if ! _bb_btop_linha_ok "$conf" "$stem"; then
    texto="$(_bb_merge_linha "$conf" "$(_bb_btop_padrao_chave)" "color_theme = \"$stem\"")"
    printf '%s\n' "$texto" | _bb_instalar_stdin "$conf"
    case $? in
      1) mudou=1; meow_muda "btop: color_theme = \"$stem\" gravado em $conf" ;;
      2) meow_erro "btop: falhou ao gravar $conf"; return "$MEOW_ERRO" ;;
    esac
  fi

  if [ "$mudou" = "1" ] && ! meow_seco && pgrep -x btop >/dev/null 2>&1; then
    meow_aviso "btop: há um btop ABERTO — ele regrava o btop.conf ao sair e desfaz isto. Feche e reabra."
  fi

  if [ "$mudou" = "1" ]; then return "$MEOW_DIVERGENTE"; fi
  return "$MEOW_OK"
}

meow_app_instalado() { [ "$(_bb_presentes)" != "0" ]; }

meow_app_detectar() {
  local bat_bin
  if ! meow_app_instalado; then
    meow_pula "btop e bat não estão instalados"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if bat_bin="$(_bb_bat_bin)"; then meow_info "bat encontrado como '$bat_bin'"; fi
  if _bb_btop_bin; then meow_info "btop encontrado"; fi
  if ! _bb_tem_tema; then _bb_avisar_sem_tema; return "$MEOW_SEM_DEPENDENCIA"; fi
  return "$MEOW_OK"
}

_bb_presentes() {
  local n=0
  if _bb_bat_bin >/dev/null; then n=$((n+1)); fi
  if _bb_btop_bin; then n=$((n+1)); fi
  printf '%s' "$n"
}

_bb_rotulo() {
  local l=""
  if [ "$1" != "3" ]; then l="bat"; fi
  if [ "$2" != "3" ]; then l="${l:+$l/}btop"; fi
  printf '%s' "${l:-btop/bat}"
}

_bb_pior() {
  local atual="$1" novo="$2"
  if [ "$novo" = "3" ]; then printf '%s' "$atual"; return 0; fi
  if [ "$novo" -gt "$atual" ]; then printf '%s' "$novo"; else printf '%s' "$atual"; fi
}

meow_app_conferir() {
  local pior=0 bat_rc btop_rc
  if [ "$(_bb_presentes)" = "0" ]; then return "$MEOW_SEM_DEPENDENCIA"; fi
  if ! _bb_tem_tema; then _bb_avisar_sem_tema; return "$MEOW_SEM_DEPENDENCIA"; fi

  _bb_bat_conferir;  bat_rc=$?;  pior="$(_bb_pior "$pior" "$bat_rc")"
  _bb_btop_conferir; btop_rc=$?; pior="$(_bb_pior "$pior" "$btop_rc")"

  if [ "$bat_rc" = "3" ] && [ "$btop_rc" = "3" ]; then return "$MEOW_SEM_DEPENDENCIA"; fi

  if [ "$pior" = "0" ]; then
    meow_ok "$(_bb_rotulo "$bat_rc" "$btop_rc"): $(_bb_bat_tema_nome) já aplicado"
  fi
  return "$pior"
}

meow_app_aplicar() {
  local pior=0 bat_rc btop_rc
  if [ "$(_bb_presentes)" = "0" ]; then
    meow_pula "btop e bat não estão instalados — temas prontos em $(_bb_up) para o dia da instalação"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _bb_tem_tema; then _bb_avisar_sem_tema; return "$MEOW_SEM_DEPENDENCIA"; fi

  MEOW_BB_CARIMBO="${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"

  _bb_bat_aplicar;  bat_rc=$?;  pior="$(_bb_pior "$pior" "$bat_rc")"
  _bb_btop_aplicar; btop_rc=$?; pior="$(_bb_pior "$pior" "$btop_rc")"

  if [ "$bat_rc" = "3" ] && [ "$btop_rc" = "3" ]; then return "$MEOW_SEM_DEPENDENCIA"; fi

  local rotulo; rotulo="$(_bb_rotulo "$bat_rc" "$btop_rc")"
  case "$pior" in
    0) meow_ok "$rotulo: nada a fazer" ;;
    1) if meow_seco; then
         meow_muda "$rotulo: divergente — nada foi gravado (MEOW_DRY_RUN=1)"
       else
         meow_ok "$rotulo: $(_bb_bat_tema_nome) aplicado"
       fi ;;
  esac
  return "$pior"
}

_bb_bat_reverter() {
  local bin nome destino cfg texto mudou=0
  bin="$(_bb_bat_bin)" || return "$MEOW_SEM_DEPENDENCIA"
  nome="$(_bb_bat_tema_nome)"
  destino="$(_bb_bat_cfg_dir "$bin")/themes/$nome.tmTheme"
  cfg="$(_bb_bat_cfg_file "$bin")"

  if [ -f "$destino" ]; then
    if cmp -s "$(_bb_bat_tema_arquivo)" "$destino"; then
      if meow_seco; then meow_muda "bat: removeria $destino"; mudou=1
      elif meow_guardar_antes "$destino"; rm -f "$destino"; then mudou=1; meow_muda "bat: tema '$nome' removido"
      fi
    else
      meow_pula "bat: $destino mudou depois que escrevemos — fica"
    fi
  fi

  if _bb_bat_linha_ok "$cfg" "$nome"; then
    if meow_seco; then
      meow_muda "bat: tiraria o --theme='$nome' de $cfg"; mudou=1
    else
      texto="$(awk -v pad="$(_bb_bat_padrao_chave)" -v ok="$(_bb_bat_padrao_ok "$nome")" \
                 '$0 ~ pad && $0 ~ ok { next } { print }' "$cfg")"
      meow_guardar_antes "$cfg"
      if printf '%s\n' "$texto" > "$cfg" 2>/dev/null; then
        mudou=1; meow_muda "bat: --theme='$nome' retirado de $cfg"
      else
        meow_erro "bat: não consegui reescrever $cfg"; return "$MEOW_ERRO"
      fi
    fi
  fi

  [ "$mudou" = "1" ] && ! meow_seco && "$bin" cache --build >/dev/null 2>&1
  [ "$mudou" = "0" ] && return "$MEOW_OK"
  return "$MEOW_DIVERGENTE"
}

_bb_btop_reverter() {
  local stem destino conf texto mudou=0
  _bb_btop_bin || return "$MEOW_SEM_DEPENDENCIA"
  stem="$(_bb_btop_tema_stem)"
  destino="$(_bb_btop_cfg_dir)/themes/$stem.theme"
  conf="$(_bb_btop_cfg_dir)/btop.conf"

  if [ -f "$destino" ]; then
    if _bb_btop_conteudo | _bb_igual_stdin "$destino"; then
      if meow_seco; then meow_muda "btop: removeria $destino"; mudou=1
      elif meow_guardar_antes "$destino"; rm -f "$destino"; then mudou=1; meow_muda "btop: tema '$stem' removido"
      fi
    else
      meow_pula "btop: $destino mudou depois que escrevemos — fica"
    fi
  fi

  if [ -f "$conf" ] && _bb_btop_linha_ok "$conf" "$stem"; then
    if meow_seco; then
      meow_muda "btop: color_theme voltaria para \"Default\""; mudou=1
    else
      texto="$(_bb_merge_linha "$conf" "$(_bb_btop_padrao_chave)" 'color_theme = "Default"')"
      meow_guardar_antes "$conf"
      if printf '%s\n' "$texto" > "$conf" 2>/dev/null; then
        mudou=1; meow_muda "btop: color_theme = \"Default\""
      else
        meow_erro "btop: não consegui reescrever $conf"; return "$MEOW_ERRO"
      fi
    fi
  fi

  [ "$mudou" = "0" ] && return "$MEOW_OK"
  return "$MEOW_DIVERGENTE"
}

meow_app_reverter() {
  if [ "$(_bb_presentes)" = "0" ]; then
    meow_pula "nem bat nem btop instalados"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  local pior=0 bat_rc btop_rc
  _bb_bat_reverter;  bat_rc=$?;  pior="$(_bb_pior "$pior" "$bat_rc")"
  _bb_btop_reverter; btop_rc=$?; pior="$(_bb_pior "$pior" "$btop_rc")"

  if [ "$bat_rc" = "3" ] && [ "$btop_rc" = "3" ]; then return "$MEOW_SEM_DEPENDENCIA"; fi
  local rotulo; rotulo="$(_bb_rotulo "$bat_rc" "$btop_rc")"
  local sem
  if _bb_tem_tema; then sem="$(_bb_bat_tema_nome)"
  else sem="$(python3 "$MEOW_BB_DIR/../modelo.py" --nome "$(meow_paleta)" "$(_bb_flavor)" 2>/dev/null)"
  fi
  case "$pior" in
    0) meow_ok "$rotulo: já estavam sem o tema ${sem:-$(_bb_flavor)}" ;;
    1) meow_app_desligar bat btop ;;
  esac
  return "$pior"
}

_bb_rebaixar_upstream() {
  local tmp par nome url commit sub glob
  meow_tem git || { meow_erro "git não encontrado"; return "$MEOW_SEM_DEPENDENCIA"; }
  tmp="$(mktemp -d)" || return "$MEOW_ERRO"
  for par in "bat|$MEOW_BB_REPO_BAT|$MEOW_BB_COMMIT_BAT|themes|*.tmTheme" \
             "btop|$MEOW_BB_REPO_BTOP|$MEOW_BB_COMMIT_BTOP|themes|*.theme"; do
    IFS='|' read -r nome url commit sub glob <<< "$par"
    git clone -q "$url" "$tmp/$nome" || { meow_erro "clone de $url falhou"; rm -rf "$tmp"; return "$MEOW_ERRO"; }
    git -C "$tmp/$nome" checkout -q "$commit" || { meow_erro "commit $commit não existe em $url"; rm -rf "$tmp"; return "$MEOW_ERRO"; }
    mkdir -p "$MEOW_RAIZ/packs/meowsystem/temas-de-apps/btop-bat/upstream/$nome"
    # shellcheck disable=SC2086
    cp -p "$tmp/$nome/$sub"/$glob "$MEOW_RAIZ/packs/meowsystem/temas-de-apps/btop-bat/upstream/$nome/" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
    meow_ok "$nome rebaixado em ${commit:0:8}"
  done
  rm -rf "$tmp"
  ( cd "$MEOW_RAIZ/packs/meowsystem/temas-de-apps/btop-bat" && find upstream -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS )
  meow_ok "SHA256SUMS regravado"
  return "$MEOW_OK"
}

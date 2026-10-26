#!/usr/bin/env bash

_GT_BASE="/org/gnome/terminal/legacy/profiles:"
_GT_UUID="6d656f77-7379-4374-656d-2d7465726d31"
_GT_FABRICA="b1dcc9dd-5262-4d8d-a863-c897e6d979b9"
_GT_ANTES="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/temas-de-apps/gnome-terminal/padrao.antes"
_GT_MODELO_PY="$MEOW_RAIZ/scripts/temas-de-apps/modelo.py"

_gt_ler_s() { dconf read "$1" 2>/dev/null | sed "s/^'//; s/'\$//"; }

_gt_padrao() {
  local p; p="$(_gt_ler_s "$_GT_BASE/default")"
  printf '%s' "${p:-$_GT_FABRICA}"
}

_gt_chaves() { grep -vE '^[[:space:]]*(#|\[|$)' <<< "$_GT_DESEJADO"; }

_gt_perfil_em_dia() {
  local dump linha
  dump="$(dconf dump "$_GT_BASE/:$_GT_UUID/" 2>/dev/null)"
  [ -n "$dump" ] || return 1
  while IFS= read -r linha; do
    grep -qxF -- "$linha" <<< "$dump" || return 1
  done <<< "$(_gt_chaves)"
  return 0
}

_gt_no_ar() {
  local padrao cores nome
  _GT_NO_AR=""; _GT_NOSSO=0
  padrao="$(_gt_padrao)"
  if [ "$padrao" = "$_GT_UUID" ]; then
    _GT_NOSSO=1; _GT_NO_AR="$_GT_UUID"; return 0
  fi
  cores="$(dconf read "$_GT_BASE/:$padrao/use-theme-colors" 2>/dev/null)"
  [ "$cores" = "false" ] || return 0
  nome="$(_gt_ler_s "$_GT_BASE/:$padrao/visible-name")"
  _GT_NO_AR="o perfil '${nome:-$padrao}'"
}

meow_app_instalado() { meow_tem gnome-terminal; }

_GT_CHAVES_DE_COR='^(visible-name|background-color|foreground-color|bold-color|bold-color-same-as-fg|bold-is-bright|cursor-background-color|cursor-foreground-color|cursor-colors-set|highlight-background-color|highlight-foreground-color|highlight-colors-set|palette|use-theme-colors|use-theme-transparency|use-transparent-background|background-transparency-percent)$'
_gt_so_cor() {
  local filtro fora
  filtro='
    /^[ \t]*(#|$)/ { if (!ruim) print; next }
    /^\[/ { ruim = ($0 != "[/]"); if (ruim) n++; else print; next }
    { k = $0; sub(/=.*/, "", k); gsub(/[ \t]/, "", k)
      if (ruim || k !~ re) { n++; next } print }
    END { if (conta) print n + 0 }'
  fora="$(printf '%s\n' "$_GT_DESEJADO" | awk -v re="$_GT_CHAVES_DE_COR" -v conta=1 "$filtro" | tail -1)"
  _GT_DESEJADO="$(printf '%s\n' "$_GT_DESEJADO" | awk -v re="$_GT_CHAVES_DE_COR" -v conta=0 "$filtro")"
  [ "${fora:-0}" -gt 0 ] && meow_aviso "GNOME Terminal: $fora linha(s) do modelo do pack $_GT_DE que não são cor ficaram de fora"
  return 0
}

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "GNOME Terminal: não está instalado"; return; }
  meow_tem dconf || { meow_app_sem "GNOME Terminal: falta o dconf, que guarda os perfis dele"; return; }
  meow_tem python3 || { meow_app_sem "GNOME Terminal: falta python3, que monta o tema com a paleta do pack"; return; }
  meow_app_tema_do_pack gnome-terminal.arquivo
  _GT_DE="$MEOW_APP_TEMA_PACK"
  [ -n "$MEOW_APP_TEMA" ] || { meow_app_sem "GNOME Terminal: o pack no ar não declara tema para ele"; return; }
  _GT_DESEJADO="$(python3 "$_GT_MODELO_PY" "$MEOW_APP_TEMA" "$(meow_paleta)" "${FLAVOR:-}" "$_GT_DE" 2>&1)" \
    || { meow_app_sem "GNOME Terminal: o modelo do pack $_GT_DE não montou — $_GT_DESEJADO"; return; }
  _gt_so_cor
  _GT_QUERO="$_GT_UUID"
  _GT_NOME="$(python3 "$_GT_MODELO_PY" --nome "$(meow_paleta)" "${FLAVOR:-}" 2>/dev/null) (MeowSystem)"
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _gt_no_ar
  if [ "$_GT_NOSSO" != 1 ]; then
    if [ -z "$_GT_NO_AR" ]; then
      meow_muda "GNOME Terminal: o perfil padrão usa as cores do sistema — o pack $_GT_DE traz '$_GT_NOME'"
      return "$MEOW_DIVERGENTE"
    fi
    meow_pula "GNOME Terminal: o padrão é $_GT_NO_AR, que não veio daqui — trocar é decisão sua"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _gt_perfil_em_dia; then
    meow_muda "GNOME Terminal: o perfil do MeowSystem é o padrão, mas as cores dele não são as do pack de agora"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "GNOME Terminal: já está no tema do pack (do pack $_GT_DE) — $_GT_NOME"
  return "$MEOW_OK"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente gnome-terminal; return; }
  _gt_no_ar
  local mudou=0 lista padrao_antes
  if [ "$_GT_NOSSO" = 1 ]; then
    meow_app_tema_no_ar gnome-terminal "$_GT_NO_AR" "$_GT_QUERO" "$_GT_DE" >/dev/null
  else
    meow_app_tema_no_ar gnome-terminal "$_GT_NO_AR" "$_GT_QUERO" "$_GT_DE" pergunte
    [ $? = "$MEOW_DIVERGENTE" ] || return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! _gt_perfil_em_dia; then
    if meow_seco; then
      meow_muda "carregaria o perfil '$_GT_NOME' em $_GT_BASE/:$_GT_UUID/"
    else
      dconf load "$_GT_BASE/:$_GT_UUID/" <<< "$_GT_DESEJADO" \
        || { meow_erro "GNOME Terminal: o dconf recusou o perfil do pack"; return "$MEOW_ERRO"; }
    fi
    mudou=1
  fi

  lista="$(dconf read "$_GT_BASE/list" 2>/dev/null)"
  if ! grep -q "$_GT_UUID" <<< "$lista"; then
    local ids novo
    ids="$(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' <<< "$lista")"
    [ -n "$ids" ] || ids="$_GT_FABRICA"
    novo="[$(printf "'%s', " $ids)'$_GT_UUID']"
    if meow_seco; then meow_muda "poria o perfil do pack na lista do GNOME Terminal"
    else dconf write "$_GT_BASE/list" "$novo" || { meow_erro "GNOME Terminal: o dconf recusou a lista de perfis"; return "$MEOW_ERRO"; }
    fi
    mudou=1
  fi

  if [ "$_GT_NOSSO" != 1 ]; then
    padrao_antes="$(_gt_ler_s "$_GT_BASE/default")"
    if [ ! -f "$_GT_ANTES" ] && ! meow_seco; then
      mkdir -p "$(dirname "$_GT_ANTES")" && printf '%s\n' "$padrao_antes" > "$_GT_ANTES" \
        || { meow_erro "GNOME Terminal: não consegui guardar o perfil padrão de antes"; return "$MEOW_ERRO"; }
    fi
    if meow_seco; then meow_muda "faria do perfil '$_GT_NOME' o padrão"
    else dconf write "$_GT_BASE/default" "'$_GT_UUID'" || { meow_erro "GNOME Terminal: o dconf recusou o perfil padrão"; return "$MEOW_ERRO"; }
    fi
    mudou=1
  fi

  [ "$mudou" = 0 ] && { meow_ok "GNOME Terminal: já está no tema do pack (do pack $_GT_DE) — $_GT_NOME"; return "$MEOW_OK"; }
  meow_seco && return "$MEOW_DIVERGENTE"
  meow_ok "GNOME Terminal: tema do pack aplicado — '$_GT_NOME' é o perfil padrão (vale na próxima janela)"
  return "$MEOW_DIVERGENTE"
}

meow_app_reverter() {
  meow_tem dconf || { meow_ok "GNOME Terminal: sem dconf, não há perfil nosso a desfazer"; return "$MEOW_OK"; }
  local mudou=0 antes lista ids resto
  if [ "$(_gt_ler_s "$_GT_BASE/default")" = "$_GT_UUID" ]; then
    antes=""
    [ -f "$_GT_ANTES" ] && antes="$(head -n 1 "$_GT_ANTES")"
    if meow_seco; then
      meow_muda "GNOME Terminal: devolveria o perfil padrão de antes"
    elif [ -n "$antes" ]; then
      dconf write "$_GT_BASE/default" "'$antes'" || { meow_erro "GNOME Terminal: não consegui devolver o padrão"; return "$MEOW_ERRO"; }
      meow_ok "GNOME Terminal: o perfil padrão voltou a ser o de antes"
    else
      dconf reset "$_GT_BASE/default" || { meow_erro "GNOME Terminal: não consegui devolver o padrão"; return "$MEOW_ERRO"; }
      meow_ok "GNOME Terminal: o perfil padrão voltou ao de fábrica"
    fi
    mudou=1
  fi
  lista="$(dconf read "$_GT_BASE/list" 2>/dev/null)"
  if grep -q "$_GT_UUID" <<< "$lista"; then
    ids="$(grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' <<< "$lista" | grep -vx "$_GT_UUID")"
    if meow_seco; then
      meow_muda "GNOME Terminal: tiraria o perfil do pack da lista"
    elif [ -z "$ids" ] || [ "$ids" = "$_GT_FABRICA" ]; then
      dconf reset "$_GT_BASE/list"
    else
      resto="[$(printf "'%s', " $ids)"; resto="${resto%, }]"
      dconf write "$_GT_BASE/list" "$resto"
    fi
    mudou=1
  fi
  if [ -n "$(dconf dump "$_GT_BASE/:$_GT_UUID/" 2>/dev/null)" ]; then
    if meow_seco; then meow_muda "GNOME Terminal: apagaria o perfil do pack"
    else dconf reset -f "$_GT_BASE/:$_GT_UUID/" && meow_ok "GNOME Terminal: o perfil do pack saiu"
    fi
    mudou=1
  fi
  meow_seco || rm -f -- "$_GT_ANTES"
  if [ "$mudou" = 0 ]; then
    meow_ok "GNOME Terminal: nenhum perfil do MeowSystem — nada a desfazer"
    return "$MEOW_OK"
  fi
  meow_seco || meow_info "tire 'gnome-terminal' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}

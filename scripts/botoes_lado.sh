#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=lib/comum.sh
. "$MEOW_RAIZ/scripts/lib/comum.sh"

BOTOES_LADO="${BOTOES_LADO:-direita}"
BL_SCHEMA="org.gnome.desktop.wm.preferences"
BL_CHAVE="button-layout"
BL_GTK_CHAVE="gtk-decoration-layout"
BL_INIS=("$HOME/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini")
BL_PADRAO_DIREITA=":minimize,maximize,close"
BL_PADRAO_ESQUERDA="close,maximize,minimize:"

_bl_gsettings() {
  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    DCONF_PROFILE=/dev/null gsettings "$@"
  else
    gsettings "$@"
  fi
}

_bl_gsettings_valor() {
  _bl_gsettings get "$BL_SCHEMA" "$BL_CHAVE" 2>/dev/null | sed "s/^'//; s/'\$//"
}

_bl_inverter() {
  local -a itens=()
  local i saida=""
  IFS=',' read -r -a itens <<< "$1"
  for ((i = ${#itens[@]} - 1; i >= 0; i--)); do
    saida="${saida:+$saida,}${itens[$i]}"
  done
  printf '%s' "$saida"
}

_bl_entendivel() {
  local v="$1" t
  case "$v" in *:*:*) return 1 ;; *:*) : ;; *) return 1 ;; esac
  [ -n "${v//[: ]/}" ] || return 0
  local -a itens=()
  IFS=',:' read -r -a itens <<< "$v"
  for t in "${itens[@]}"; do
    case "$t" in ""|menu|appmenu|icon|minimize|maximize|close|spacer) : ;; *) return 1 ;; esac
  done
  return 0
}

_bl_alvo() {
  local v="${1// /}" lado="$2" esq dir
  if ! _bl_entendivel "$v"; then
    [ "$lado" = "direita" ] && printf '%s' "$BL_PADRAO_DIREITA" || printf '%s' "$BL_PADRAO_ESQUERDA"
    return 0
  fi
  esq="${v%%:*}"; dir="${v#*:}"
  if [ "$lado" = "direita" ]; then
    [ -z "$esq" ] && { printf '%s' "$v"; return 0; }
    dir="$(_bl_inverter "$esq")${dir:+,$dir}"
    printf ':%s' "$dir"
  else
    [ -z "$dir" ] && { printf '%s' "$v"; return 0; }
    esq="${esq:+$esq,}$(_bl_inverter "$dir")"
    printf '%s:' "$esq"
  fi
}

_bl_ini_valor() {
  LC_ALL=C awk -v chave="$BL_GTK_CHAVE" '
    /^[[:space:]]*\[/ { dentro = ($0 ~ /^[[:space:]]*\[Settings\][[:space:]]*$/); next }
    dentro && $0 ~ "^[[:space:]]*" chave "[[:space:]]*=" {
      v = $0; sub(/^[^=]*=[[:space:]]*/, "", v); sub(/[[:space:]]*$/, "", v); print v; exit
    }' "$1"
}

_bl_ini_com() {
  LC_ALL=C awk -v chave="$BL_GTK_CHAVE" -v valor="$2" '
    { linhas[NR] = $0 }
    END {
      secao = 0; posta = 0
      for (i = 1; i <= NR; i++) {
        l = linhas[i]
        if (l ~ /^[[:space:]]*\[/) {
          if (secao && !posta) { print chave "=" valor; posta = 1 }
          secao = (l ~ /^[[:space:]]*\[Settings\][[:space:]]*$/)
          if (secao) achou = 1
          print l; continue
        }
        if (secao && l ~ "^[[:space:]]*" chave "[[:space:]]*=") {
          if (!posta) { print chave "=" valor; posta = 1 }
          continue
        }
        print l
      }
      if (!achou) { if (NR) print ""; print "[Settings]" }
      if (!posta) print chave "=" valor
    }' "$1"
}

_bl_escrever_ini() {
  local arq="$1" valor="$2" tmp dir
  meow_destino_permitido "$arq" || return "$MEOW_ERRO"
  dir="$(dirname -- "$arq")"
  meow_guardar_antes "$arq"
  tmp="$(mktemp -p "$dir" ".atomicwrite.meow.XXXXXX")" || return "$MEOW_ERRO"
  if ! _bl_ini_com "$arq" "$valor" > "$tmp"; then rm -f "$tmp"; return "$MEOW_ERRO"; fi
  chmod --reference="$arq" "$tmp" 2>/dev/null || chmod 644 "$tmp"
  mv -f "$tmp" "$arq" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  meow_manifesto_registrar "$arq"
  return 0
}

_bl_validar() {
  case "$BOTOES_LADO" in
    direita|esquerda) return 0 ;;
    *) meow_erro "BOTOES_LADO='$BOTOES_LADO' — esperado direita ou esquerda"; return 1 ;;
  esac
}

_bl_exigir() {
  _bl_validar || exit "$MEOW_ERRO"
  if ! meow_tem gsettings; then
    meow_pula "sem gsettings — os botões das janelas não são tocados"
    exit "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _bl_gsettings get "$BL_SCHEMA" "$BL_CHAVE" >/dev/null 2>&1; then
    meow_pula "o gsettings não conhece $BL_SCHEMA — os botões das janelas não são tocados"
    exit "$MEOW_SEM_DEPENDENCIA"
  fi
}

_bl_passar() {
  local escrever="$1" rc="$MEOW_OK" atual alvo ini ini_atual ini_alvo

  atual="$(_bl_gsettings_valor)"
  alvo="$(_bl_alvo "$atual" "$BOTOES_LADO")"
  if [ "$atual" = "$alvo" ]; then
    [ "$escrever" = "1" ] && meow_guardar_valor_de_antes "$BL_CHAVE" ""
    meow_ok "gsettings $BL_CHAVE = '$alvo'"
  else
    rc="$MEOW_DIVERGENTE"
    if [ "$escrever" = "1" ] && ! meow_seco; then
      meow_guardar_valor_de_antes "$BL_CHAVE" "$atual"
      if ! gsettings set "$BL_SCHEMA" "$BL_CHAVE" "$alvo" 2>/dev/null; then
        meow_erro "o gsettings recusou escrever $BL_CHAVE"; return "$MEOW_ERRO"
      fi
      if [ "$(_bl_gsettings_valor)" = "$alvo" ]; then
        meow_muda "gsettings $BL_CHAVE: '$atual' -> '$alvo'"
      else
        meow_pula "o gsettings aceitou $BL_CHAVE e não guardou (sem barramento de sessão)"
      fi
    else
      meow_muda "gsettings $BL_CHAVE = '$atual' (esperado '$alvo')"
    fi
  fi

  for ini in "${BL_INIS[@]}"; do
    [ -f "$ini" ] || { meow_pula "$ini não existe — fica como está"; continue; }
    ini_atual="$(_bl_ini_valor "$ini")"
    if [ -n "$ini_atual" ]; then ini_alvo="$(_bl_alvo "$ini_atual" "$BOTOES_LADO")"; else ini_alvo="$alvo"; fi
    if [ "$ini_atual" = "$ini_alvo" ]; then
      meow_ok "$ini: $BL_GTK_CHAVE = '$ini_alvo'"
      continue
    fi
    rc="$MEOW_DIVERGENTE"
    if [ "$escrever" = "1" ] && ! meow_seco; then
      _bl_escrever_ini "$ini" "$ini_alvo" || { meow_erro "falha ao escrever $ini"; return "$MEOW_ERRO"; }
      meow_muda "$ini: $BL_GTK_CHAVE '$ini_atual' -> '$ini_alvo'"
    else
      meow_muda "$ini: $BL_GTK_CHAVE = '$ini_atual' (esperado '$ini_alvo')"
    fi
  done

  [ "$escrever" = "1" ] && [ "$rc" != "$MEOW_OK" ] && ! meow_seco && meow_registrar "botoes_lado.sh aplicar lado=$BOTOES_LADO"
  return "$rc"
}

case "${1:-aplicar}" in
  aplicar)  _bl_exigir; _bl_passar 1; exit $? ;;
  conferir) _bl_exigir; _bl_passar 0; exit $? ;;
  *) meow_erro "uso: botoes_lado.sh {aplicar|conferir}"; exit "$MEOW_ERRO" ;;
esac

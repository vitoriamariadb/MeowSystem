#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

SN_CARGO_BIN="${CARGO_HOME:-$HOME/.cargo}/bin"
case ":$PATH:" in
  *":$SN_CARGO_BIN:"*) ;;
  *) [ -d "$SN_CARGO_BIN" ] && PATH="$SN_CARGO_BIN:$PATH" && export PATH ;;
esac

SN_SAIDA="${SN_SAIDA:-$MEOW_ESTADO/sentinela.tsv}"
SN_PREVER="${SN_PREVER:-$MEOW_RAIZ/scripts/cosmic_prever.sh}"
SN_VEREDITO="${CV_SAIDA:-$MEOW_ESTADO/cosmic-candidato.tsv}"
SN_ID="sentinela-cosmic"
SN_NOME="O COSMIC da fila não entra"

_sn_fila() {
  apt list --upgradable 2>/dev/null | sed -n 's#^\(cosmic-[^/]*\)/[^ ]* \([^ ]*\) .*#\1=\2#p' | sort
}

_sn_assinatura() {
  local f; f="$(cat)"
  [ -n "$f" ] || { printf 'nada'; return 0; }
  printf '%s' "$f" | sha256sum | cut -c1-16
}

_sn_incompleto() { grep -qE 'não consegui abrir o \.deb|não foi baixado|não foi medida' "$1"; }

cmd_ler() {
  [ -r "$SN_SAIDA" ] || { meow_pula "a sentinela ainda não mediu nada"; return "$MEOW_OK"; }
  local k a b
  while IFS=$'\t' read -r k a b; do
    case "$k" in \#*|"") continue ;; esac
    case "$a" in
      verde|nada) meow_ok "$k: $a${b:+ — $b}" ;;
      amarelo)    meow_aviso "$k: $a${b:+ — $b}" ;;
      vermelho)   meow_muda "$k: $a${b:+ — $b}" ;;
      *)          meow_info "$k: $a${b:+ $b}" ;;
    esac
  done < "$SN_SAIDA"
  return "$MEOW_OK"
}

_sn_gravar() {
  local tmp
  mkdir -p "${SN_SAIDA%/*}" && tmp="$(mktemp -p "${SN_SAIDA%/*}" .sentinela.XXXXXX)" || return "$MEOW_ERRO"
  { printf '# gravado por sentinela.sh em %s — NAO EDITAR A MAO\n' "$(date -Is)"
    printf 'candidato\t%s\t%s\n' "$1" "$(printf '%s' "$2" | tr '\n' ' ' | sed 's/ $//')"
    printf 'resultado\t%s\n' "$3"
    if [ -n "$4" ]; then grep -v '^#' "$4"; fi; } > "$tmp" && mv -f "$tmp" "$SN_SAIDA"
}

cmd_rodar() {
  local fila sig atual cor rc motivo
  meow_tem apt || { meow_pula "sem apt nesta máquina — nada a vigiar"; return "$MEOW_SEM_DEPENDENCIA"; }
  fila="$(_sn_fila)"
  sig="$(printf '%s' "$fila" | _sn_assinatura)"
  atual="$(awk -F'\t' '$1 == "candidato" {print $2; exit}' "$SN_SAIDA" 2>/dev/null)"
  if [ "$atual" = "$sig" ]; then
    meow_ok "o candidato é o mesmo da última medida ($sig) — nada novo"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "mediria a fila do apt (${fila:-sem cosmic-*}) e gravaria $SN_SAIDA"
    return "$MEOW_DIVERGENTE"
  fi

  if [ "$sig" = "nada" ]; then
    _sn_gravar nada "" nada "" || return "$MEOW_ERRO"
    meow_precisa_de_gente_resolvida "$SN_ID"
    meow_ok "nenhum pacote do COSMIC na fila do apt"
    return "$MEOW_OK"
  fi

  # shellcheck disable=SC2086
  "$SN_PREVER" ${SN_PREVER_ARGS:-} >/dev/null 2>&1; rc=$?
  case "$rc" in
    0|1) ;;
    3)   meow_pula "o pré-voo não roda nesta máquina (sem dpkg-deb)"; return "$MEOW_SEM_DEPENDENCIA" ;;
    *)   meow_erro "o pré-voo do COSMIC falhou (rc $rc) — a próxima passagem mede de novo"; return "$MEOW_ERRO" ;;
  esac
  [ -r "$SN_VEREDITO" ] || { meow_erro "o pré-voo não deixou veredito em $SN_VEREDITO"; return "$MEOW_ERRO"; }

  if awk -F'\t' '$2 == "vermelho" {a = 1} END {exit !a}' "$SN_VEREDITO"; then cor=vermelho
  elif awk -F'\t' '$2 == "amarelo" {a = 1} END {exit !a}' "$SN_VEREDITO"; then cor=amarelo
  else cor=verde; fi
  _sn_incompleto "$SN_VEREDITO" && sig="-"
  _sn_gravar "$sig" "$fila" "$cor" "$SN_VEREDITO" || return "$MEOW_ERRO"
  meow_registrar "sentinela.sh candidato=${fila//$'\n'/,} resultado=$cor"

  if [ "$cor" = "vermelho" ]; then
    motivo="$(awk -F'\t' '$2 == "vermelho" {printf "%s%s: %s", (n++ ? " · " : ""), $1, $3}' "$SN_VEREDITO")"
    meow_precisa_de_gente "$SN_ID" "$SN_NOME" "$motivo"
    meow_muda "o COSMIC da fila não entra inteiro: $motivo"
    return "$MEOW_DIVERGENTE"
  fi
  meow_precisa_de_gente_resolvida "$SN_ID"
  meow_ok "o COSMIC da fila entra ($cor)"
  return "$MEOW_OK"
}

case "${1:-rodar}" in
  rodar) cmd_rodar ;;
  ler)   cmd_ler ;;
  *) meow_erro "uso: sentinela.sh [rodar|ler]"; exit "$MEOW_ERRO" ;;
esac

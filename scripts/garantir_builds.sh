#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

GB_COMPOSITOR="${GB_COMPOSITOR:-$MEOW_RAIZ/scripts/compositor_patches.sh}"
GB_FILES="${GB_FILES:-$MEOW_RAIZ/scripts/files_menu.sh}"
GB_EXTENSOES="${GB_EXTENSOES:-$MEOW_RAIZ/scripts/extensoes_build.sh}"
GB_CASA="${GB_CASA:-${CP_CASA:-$HOME/.local/libexec/meow/cosmic-comp}}"
GB_FILES_GUARDA="${GB_FILES_GUARDA:-$MEOW_ESTADO/cosmic-files}"
GB_MATRIZ="${GB_MATRIZ:-${CP_MATRIZ:-$MEOW_ESTADO/cosmic-comp/matriz.tsv}}"
GB_REPO="${CP_REPO:-$MEOW_RAIZ/patches}"
GB_SERIE="${CP_SERIE:-$GB_REPO/series}"
GB_TRAVA="${GB_TRAVA:-$MEOW_ESTADO/builds.lock}"
GB_UNIDADE="meow-builds-login.service"
GB_FILES_MARCA="MEOW-FILES-WALLPAPER-PATCH-1"

GB_CARGO_BIN="${CARGO_HOME:-$HOME/.cargo}/bin"
case ":$PATH:" in
  *":$GB_CARGO_BIN:"*) ;;
  *) [ -d "$GB_CARGO_BIN" ] && PATH="$GB_CARGO_BIN:$PATH" && export PATH ;;
esac

_gb_instalados() {
  dpkg-query -W -f='${Package}\t${Version}\t${db:Status-Status}\n' cosmic-files cosmic-comp 2>/dev/null |
    awk -F'\t' '($1=="cosmic-files" || $1=="cosmic-comp") && $3=="installed" && $2!="" {print $1"\t"$2}'
}

_gb_comp_valido() {
  [ -x "$GB_CASA/$1/cosmic-comp" ] && grep -q '^req [^ ]* [^ ]* presente$' "$GB_CASA/$1/estado" 2>/dev/null \
    && ! _gb_comp_velho "$1"
}
_gb_comp_velho() {
  local c a b m
  while read -r c a b _; do
    case "$c" in req|opt) ;; *) continue ;; esac
    m="$(sed -n "s/^+.*\"\($b-[0-9][0-9.]*\)\".*/\1/p" "$GB_REPO/$a" 2>/dev/null | head -1)"
    [ -n "$m" ] || continue
    awk -v m="$m" -v a="$a" '$3==a && $4=="presente" && $2!=m {x=1} END {exit !x}' \
      "$GB_CASA/$1/estado" 2>/dev/null && return 0
  done < "$GB_SERIE"
  return 1
}
_gb_files_valido() {
  local b
  for b in cosmic-files cosmic-files-applet; do
    grep -a -q -- "$GB_FILES_MARCA" "$GB_FILES_GUARDA/$1/$b" 2>/dev/null || return 1
  done
}
_gb_comp_degrau4() {
  awk -F'\t' -v v="$1" '$1==v && $3 ~ /:4( |$)/ {a=1} END {exit !a}' "$GB_MATRIZ" 2>/dev/null || return 1
  [ -z "$(find "$GB_REPO" "$GB_SERIE" -newer "$GB_MATRIZ" -print -quit 2>/dev/null)" ]
}
_gb_gente() {
  local vc linhas
  vc="$(_gb_instalados | awk -F'\t' '$1=="cosmic-comp" {print $2}')"
  if [ -n "$vc" ] && _gb_comp_degrau4 "$vc" && ! _gb_comp_valido "$vc"; then
    linhas="$(awk -F'\t' -v v="$vc" '$1==v {for (i = 1; i <= split($3, a, " "); i++) if (a[i] ~ /:4$/) {sub(/:4$/, "", a[i]); print a[i]}}' "$GB_MATRIZ" 2>/dev/null | sort -u | tr '\n' ' ')"
    meow_precisa_de_gente patch-obrigatorio "Patch obrigatório precisa de rebase" \
      "cosmic-comp $vc: ${linhas:-a série} não entra, e a sessão segue no compositor de fábrica até um rebase em patches/"
  else
    meow_precisa_de_gente_resolvida patch-obrigatorio
  fi
}

_gb_files_quer() {
  local q="${FILES_MENU:-}"
  [ -n "$q" ] || q="$(meow_conf_valor FILES_MENU 2>/dev/null)" || q="sim"
  [ "${q:-sim}" = "sim" ]
}

_gb_pendentes() {
  local p v
  while IFS=$'\t' read -r p v; do
    case "$p" in
      cosmic-files) _gb_files_quer && ! _gb_files_valido "$v" && printf '%s\t%s\n' "$p" "$v" ;;
      cosmic-comp)  [ ! -e "$GB_CASA/$v/ruim" ] && ! _gb_comp_valido "$v" && ! _gb_comp_degrau4 "$v" \
                      && printf '%s\t%s\n' "$p" "$v" ;;
    esac
  done < <(_gb_instalados)
  return 0
}

gb_construindo() { [ -e "$GB_TRAVA" ] && ! flock -n "$GB_TRAVA" true 2>/dev/null; }

_gb_compilar_files() {
  meow_info "cosmic-files $1: sem o menu desta versão — compilando"
  FILES_MENU=sim "$GB_FILES" build; local rc=$?
  _gb_files_valido "$1" && return 0
  [ "$rc" = "3" ] && { meow_pula "cosmic-files $1: falta ferramenta de compilação nesta máquina — o do pacote segue valendo"; return 0; }
  meow_aviso "cosmic-files $1: o build falhou — o do pacote segue valendo, e o próximo gatilho tenta de novo"
  return 2
}

_gb_compilar_comp() {
  meow_info "cosmic-comp $1: sem build desta versão — compilando"
  local t0; t0="$(date +%s)"
  "$GB_COMPOSITOR" compilar; local rc=$?
  _gb_comp_valido "$1" && return 0
  [ "$rc" = "3" ] && { meow_pula "cosmic-comp $1: falta ferramenta de compilação nesta máquina — a sessão segue no de fábrica"; return 0; }
  if [ "$(stat -c %Y "$GB_MATRIZ" 2>/dev/null || echo 0)" -ge "$t0" ] && _gb_comp_degrau4 "$1"; then
    meow_pula "cosmic-comp $1: o patch obrigatório não entra nesta versão (degrau 4) — a sessão segue no de fábrica"
    return 0
  fi
  meow_aviso "cosmic-comp $1: o build falhou — a sessão segue no de fábrica, e o próximo gatilho tenta de novo"
  return 2
}

cmd_rodar() {
  local p v falhou=0
  local -a pend=()
  meow_tem dpkg-query || { meow_pula "sem dpkg nesta máquina"; return "$MEOW_SEM_DEPENDENCIA"; }
  mapfile -t pend < <(_gb_pendentes)
  if [ "${#pend[@]}" = "0" ]; then
    _gb_gente
    local vc; vc="$(_gb_instalados | awk -F'\t' '$1=="cosmic-comp" {print $2}')"
    if [ -n "$vc" ] && _gb_comp_degrau4 "$vc" && ! _gb_comp_valido "$vc"; then
      meow_pula "cosmic-comp $vc: o patch obrigatório não entra nesta versão (degrau 4) — a sessão segue no de fábrica até a série mudar"
      return "$MEOW_OK"
    fi
    meow_ok "o compositor e o menu do cosmic-files têm build para a versão instalada"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    for p in "${pend[@]}"; do meow_muda "compilaria o ${p%%$'\t'*} ${p#*$'\t'}"; done
    return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "${GB_TRAVA%/*}" || return "$MEOW_ERRO"
  exec 9>>"$GB_TRAVA" || return "$MEOW_ERRO"
  gb_construindo && meow_info "outra passagem está compilando — espero ela acabar"
  flock 9
  renice -n 19 -p $$ >/dev/null 2>&1
  ionice -c 3 -p $$ >/dev/null 2>&1

  mapfile -t pend < <(_gb_pendentes)
  for p in "${pend[@]}"; do
    v="${p#*$'\t'}"
    case "${p%%$'\t'*}" in
      cosmic-files) _gb_compilar_files "$v" || falhou=1 ;;
      cosmic-comp)  _gb_compilar_comp  "$v" || falhou=1 ;;
    esac
  done
  meow_registrar "garantir_builds.sh falhou=$falhou"
  _gb_gente
  [ "$falhou" = "1" ] && return "$MEOW_ERRO"
  return "$MEOW_OK"
}

cmd_fundo() {
  local -a pend=()
  mapfile -t pend < <(_gb_pendentes)
  [ "${#pend[@]}" = "0" ] && { cmd_rodar; return $?; }
  meow_seco && { cmd_rodar; return $?; }
  if [ -f "$HOME/.config/systemd/user/$GB_UNIDADE" ] \
     && systemctl --user start --no-block "$GB_UNIDADE" >/dev/null 2>&1; then
    local i
    for i in $(seq 50); do gb_construindo && break; sleep 0.2; done
    meow_muda "construindo em segundo plano: ${pend[*]//$'\t'/ } — vale no próximo login"
    return "$MEOW_DIVERGENTE"
  fi
  cmd_rodar || return $?
  return "$MEOW_DIVERGENTE"
}

cmd_estado() {
  local vc vf e_comp e_menu remendos
  vc="$(_gb_instalados | awk -F'\t' '$1=="cosmic-comp" {print $2}')"
  vf="$(_gb_instalados | awk -F'\t' '$1=="cosmic-files" {print $2}')"
  if [ -z "$vc" ]; then e_comp=ausente
  elif [ -e "$GB_CASA/$vc/ruim" ]; then e_comp=falhou
  elif _gb_comp_valido "$vc"; then
    e_comp=ok
    [ "$("$GB_EXTENSOES" compositor --ativa 2>/dev/null)" = nao ] && e_comp=desligado
  elif _gb_comp_degrau4 "$vc"; then e_comp=nao-encaixa
  else e_comp=pendente; fi
  if [ -z "$vf" ]; then e_menu=ausente
  elif ! _gb_files_quer; then e_menu=desligado
  elif _gb_files_valido "$vf"; then e_menu=ok
  else e_menu=pendente; fi
  remendos="$(awk '$1=="req" || $1=="opt" {n++} END {print n+0}' "$GB_SERIE" 2>/dev/null)"
  printf 'compositor_versao=%s\ncompositor_estado=%s\nremendos=%s\nmenu_versao=%s\nmenu_estado=%s\nconstruindo=%s\n' \
    "$vc" "$e_comp" "$remendos" "$vf" "$e_menu" "$(gb_construindo && echo sim || echo nao)"
  return "$MEOW_OK"
}

case "${1:-}" in
  estado)   cmd_estado ;;
  ""|rodar) cmd_rodar ;;
  --seco)   MEOW_SECO=1; cmd_rodar ;;
  --fundo)  cmd_fundo ;;
  *) meow_erro "uso: garantir_builds.sh [estado|--seco|--fundo]"; exit "$MEOW_ERRO" ;;
esac

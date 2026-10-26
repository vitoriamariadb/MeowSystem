#!/usr/bin/env bash

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/icones.sh
. "$RAIZ/lib/icones.sh"

TEMA_NOME="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA_NOME"
ALVO="$TEMA_DIR/scalable/apps"
ICONES="$RAIZ/assets/icones"
_pack_ref="$(meow_pack_dir)"
[ -n "$_pack_ref" ] || _pack_ref="$(meow_pack_padrao_dir || true)"
MAPA="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" icones.apps.mapa)" || MAPA=""
[ -n "$MAPA" ] || MAPA="$(meow_pack_arquivo icones/apps.map assets/icones/apps-dracula.map)"
ICONES_BASE_MAPA="$(dirname "$MAPA")"

_dracula_pares_do_mapa() {
  [ -f "$MAPA" ] || return 1
  local cru
  cru="$(sed -e 's/#.*//' "$MAPA" | awk -F: '
    NF>=2 {
      nome=$1; caminho=substr($0, index($0, ":") + 1)
      gsub(/^[ \t]+|[ \t]+$/, "", nome)
      gsub(/^[ \t]+|[ \t]+$/, "", caminho)
      if (nome == "" || caminho == "") next
      # O recusado vai para o aviso no terminal: fora do conjunto, sai `?`.
      if (nome !~ /^[A-Za-z0-9._+-]+$/ || index(nome, "..")) { gsub(/[^A-Za-z0-9._+-]/, "?", nome); print "!\t" nome; next }
      print nome "\t" caminho
    }')"
  local recusados
  recusados="$(printf '%s\n' "$cru" | grep -c $'^!\t')"
  if [ "$recusados" -gt 0 ]; then
    meow_aviso "$MAPA: $recusados linha(s) com nome fora de [A-Za-z0-9._+-] (ou com '..') puladas: $(printf '%s\n' "$cru" | sed -n $'s/^!\t//p' | head -3 | paste -sd' ')"
    cru="$(printf '%s\n' "$cru" | grep -v $'^!\t')"
  fi
  [ -n "$cru" ] || return 0
  paste <(printf '%s\n' "$cru" | cut -f1) \
        <(printf '%s\n' "$cru" | cut -f2 \
            | python3 "$RAIZ/scripts/pack.py" alvo "$ICONES_BASE_MAPA")
}

_escolhas_pares() {
  python3 "$RAIZ/scripts/pack.py" escolhas
}

_dracula_pares() {
  local fora
  fora="$(_escolhas_pares | cut -f1)"
  _dracula_pares_do_mapa | awk -F'\t' -v fora="$fora" '
    BEGIN { n = split(fora, f, "\n"); for (i = 1; i <= n; i++) if (f[i] != "") x[f[i]] = 1 }
    !($1 in x)'
}

_dracula_no_ar() {
  [ "${ICONES_DRACULA:-sim}" != "nao" ] && _dracula_pares
  _escolhas_pares
}

_dracula_instalar() {
  local rc=0 nome caminho origem
  local postos=0 faltando=() no_tema=()

  while IFS=$'\t' read -r nome caminho; do
    [ -n "$nome" ] || continue
    origem="$caminho"
    if [ ! -f "$origem" ]; then
      faltando+=("$nome -> $caminho"); continue
    fi
    meow_icones_derivar "$origem" "$nome" "$TEMA_DIR"
    case $? in
      0) : ;;
      1) postos=$((postos+1)) ;;
      *) rc=2 ;;
    esac
    [ -f "$ALVO/$nome.svg" ] && no_tema+=("$nome"$'\t'"$origem")
  done < <(_dracula_no_ar)
  _dracula_registrar "${no_tema[@]}"

  if [ "${#faltando[@]}" -gt 0 ]; then
    meow_aviso "no mapa mas sem desenho no disco: ${faltando[*]}"
    [ "$rc" = "0" ] && rc=1
  fi

  local rc_c; _dracula_cache; rc_c=$?
  [ "$rc_c" = "1" ] && [ "$rc" = "0" ] && rc=1

  if [ "$postos" -gt 0 ]; then
    meow_ok "$postos desenho(s) do pack Dracula no tema"
    _dracula_avisar
    rc=1
  elif [ "$rc" = "0" ] && [ "${ICONES_DRACULA:-sim}" = "nao" ]; then
    meow_ok "$(_escolhas_pares | grep -c .) escolha(s) do painel no tema"
  elif [ "$rc" = "0" ]; then
    local par; par="$(_dracula_estado)"
    meow_ok "pack Dracula: ${par% *} de ${par#* } no tema"
  fi
  return "$rc"
}

_dracula_do_resgate() {
  MEOW_PACK_DIR="$_pack_ref" python3 "$RAIZ/scripts/pack.py" fontes 2>/dev/null \
    | awk -F'\t' '$3 == "resgatados" { print $1 }'
}

_dracula_remover() {
  local rc=0 tirados=0 nome caminho origem do_resgate
  do_resgate="$(_dracula_do_resgate)"
  while IFS=$'\t' read -r nome caminho; do
    [ -n "$nome" ] || continue
    [ -f "$ALVO/$nome.svg" ] || continue
    grep -qxF -- "$nome" <<<"$do_resgate" && continue
    origem="$caminho"
    if [ ! -f "$origem" ]; then
      meow_info "  $nome.svg: sem a origem não dá para conferir se é nosso — fica como está"
      continue
    fi
    if [ "$(cat "$origem")" != "$(cat "$ALVO/$nome.svg")" ]; then
      meow_info "  $nome.svg não é o desenho do acervo — fica como está"
      continue
    fi
    if meow_seco; then
      meow_muda "apagaria $ALVO/$nome.svg"
      tirados=$((tirados+1)); continue
    fi
    rm -f "$ALVO/$nome.svg" && tirados=$((tirados+1)) || rc=2
  done < <(_dracula_pares)

  if [ "$tirados" -gt 0 ]; then
    meow_ok "$tirados desenho(s) do pack Dracula retirado(s) — o Arcticons do 48x48 volta a valer"
    _dracula_avisar
    [ "$rc" = "0" ] && rc=1
  fi
  local rc_c; _dracula_cache; rc_c=$?
  [ "$rc_c" = "1" ] && [ "$rc" = "0" ] && rc=1
  [ "$tirados" = "0" ] && [ "$rc" = "0" ] && \
    meow_ok "pack Dracula desligado (ICONES_DRACULA=\"nao\") — nada dele no tema"
  return "$rc"
}

REGISTRO="$MEOW_ESTADO/icones-do-pack.tsv"
_dracula_registrar() {
  meow_seco && return 0
  meow_escrever "$REGISTRO" "$(printf '%s\n' "$@" | sort -u)" 644 >/dev/null || true
}

_dracula_de_fora() {
  python3 -I - "$RAIZ" "$MAPA" "$_pack_ref" "$REGISTRO" <<'PY'
import contextlib
import io
import os
import sys

sys.path.insert(0, os.path.join(sys.argv[1], "scripts"))
import pack  # noqa: E402

no_ar = os.path.realpath(sys.argv[2]) if sys.argv[2] and os.path.isfile(sys.argv[2]) else ""
nomes_no_ar = {nome for _num, nome, _alvo in pack.ler_mapa(no_ar)} if no_ar else set()
with contextlib.redirect_stderr(io.StringIO()):
    nomes_no_ar |= {nome for nome, _fonte, _camada in pack.fontes(sys.argv[3] or None)}
vistos, mapas = set(), []
for base in pack.raizes():
    try:
        ids = sorted(os.listdir(base))
    except OSError:
        continue
    for pid in ids:
        dir_pack = os.path.join(base, pid)
        if pid in vistos or not os.path.isfile(os.path.join(dir_pack, "pack.json")):
            continue
        vistos.add(pid)
        mapa = pack.acervo("icones.apps.mapa", ref=dir_pack)
        if mapa and os.path.realpath(mapa) not in (no_ar, *mapas):
            mapas.append(os.path.realpath(mapa))
ditos = set()
for mapa in mapas:
    try:
        linhas = list(pack.ler_mapa(mapa))
    except OSError:
        continue
    for _num, nome, alvo in linhas:
        if nome in nomes_no_ar:
            continue
        try:
            desenho = pack.resolver_alvo(alvo, os.path.dirname(mapa))
        except pack.Recusa:
            continue
        ditos.add((nome, desenho))
        print("%s\t%s\tde um pack que não está no ar" % (nome, desenho))
try:
    with open(sys.argv[4], encoding="utf-8") as fh:
        anotados = [linha.rstrip("\n").split("\t") for linha in fh]
except OSError:
    anotados = []
for campos in anotados:
    if len(campos) != 2 or not campos[0] or "/" in campos[0] or campos[0] in nomes_no_ar \
            or tuple(campos) in ditos:
        continue
    print("%s\t%s\tque saiu do mapa do pack no ar" % tuple(campos))
PY
}

_dracula_sobras() {
  local rc=0 tirados=0 nome caminho porque
  while IFS=$'\t' read -r nome caminho porque; do
    [ -n "$nome" ] && [ -f "$ALVO/$nome.svg" ] && [ -f "$caminho" ] || continue
    [ "$(cat "$caminho")" = "$(cat "$ALVO/$nome.svg")" ] || continue
    if meow_seco; then
      meow_muda "apagaria $ALVO/$nome.svg (desenho $porque)"
      tirados=$((tirados+1)); continue
    fi
    rm -f "$ALVO/$nome.svg" && tirados=$((tirados+1)) || rc=2
  done < <(_dracula_de_fora | sort -u)

  [ "$tirados" -gt 0 ] || return "$rc"
  meow_seco && return 1
  meow_ok "$tirados desenho(s) de pack que nenhum mapa no ar pede retirado(s) do tema"
  if [ -f "$TEMA_DIR/icon-theme.cache" ]; then
    if meow_tem gtk-update-icon-cache && gtk-update-icon-cache -q -f "$TEMA_DIR" 2>/dev/null; then
      meow_ok "cache do tema reindexada (ela ainda listava os desenhos retirados)"
    else
      meow_aviso "$TEMA_DIR/icon-theme.cache ainda lista os desenhos retirados — apague-a se um ícone sumir"
    fi
  fi
  _dracula_avisar
  [ "$rc" = "0" ] && rc=1
  return "$rc"
}

_dracula_cache() {
  local cache="$TEMA_DIR/icon-theme.cache"
  [ -f "$cache" ] || return 0
  [ -n "$(find "$ALVO" -name '*.svg' -newer "$cache" -print -quit 2>/dev/null)" ] || return 0

  if meow_seco; then
    meow_muda "reindexaria a cache do tema ($cache está velha e esconde o pack)"
    return 1
  fi
  if ! meow_tem gtk-update-icon-cache; then
    meow_aviso "$cache está velha e esconde os ícones novos, e não há gtk-update-icon-cache"
    meow_info  "  apague o arquivo: rm '$cache'"
    return 1
  fi
  if gtk-update-icon-cache -q -f "$TEMA_DIR" 2>/dev/null; then
    meow_ok "cache do tema reindexada (ela escondia o pack Dracula)"
    return 1
  fi
  meow_aviso "não consegui reindexar $cache — apague-a se algum ícone não aparecer"
  return 1
}

_dracula_avisar() {
  meow_seco && return 0
  meow_tela_reler
  case $? in
    0) meow_ok "os desenhos novos já estão na dock e no menu" ;;
    3) meow_info "fora da sessão gráfica: os desenhos novos aparecem no próximo login" ;;
  esac
  return 0
}

_dracula_estado() {
  local total=0 postos=0 nome caminho
  while IFS=$'\t' read -r nome caminho; do
    [ -n "$nome" ] || continue
    total=$((total+1))
    [ -f "$ALVO/$nome.svg" ] && postos=$((postos+1))
  done < <(_dracula_pares)
  printf '%s %s' "$postos" "$total"
}

_dracula_aplicar() {
  local rc_fora rc
  _dracula_sobras; rc_fora=$?
  if [ "${ICONES_DRACULA:-sim}" != "nao" ]; then _dracula_instalar
  else
    _dracula_remover; rc=$?
    if [ -n "$(_escolhas_pares)" ]; then
      local rc_e; _dracula_instalar; rc_e=$?
      if [ "$rc_e" = "2" ] || [ "$rc" = "2" ]; then rc=2
      elif [ "$rc_e" = "1" ]; then rc=1; fi
    fi
    ( exit "$rc" )
  fi
  rc=$?
  if [ "$rc" = "2" ] || [ "$rc_fora" = "2" ]; then return 2; fi
  if [ "$rc" = "1" ] || [ "$rc_fora" = "1" ]; then return 1; fi
  return 0
}

case "${1:-aplicar}" in
  aplicar|--aplicar) _dracula_aplicar ;;
  --conferir) MEOW_SECO=1 _dracula_aplicar ;;
  instalar) _dracula_instalar ;;
  remover)  _dracula_remover ;;
  estado)   _dracula_estado ;;
  *) printf 'uso: icones_apps_dracula.sh [aplicar|--conferir|instalar|remover|estado]\n' >&2; exit 2 ;;
esac

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
APPS_USUARIO="$HOME/.local/share/applications"

_pack_ref="$(meow_pack_dir)"
[ -n "$_pack_ref" ] || _pack_ref="$(meow_pack_padrao_dir || true)"
MAPA="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" icones.resgatados.mapa 2>/dev/null)" || MAPA=""
ACERVO="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" icones.resgatados.desenhos 2>/dev/null)" || ACERVO=""
ACERVO="${ACERVO%/}"
SO_TIRAR=0
if [ -z "$MAPA" ] || [ -z "$ACERVO" ]; then
  SO_TIRAR=1
  { IFS= read -r MAPA; IFS= read -r ACERVO; } < <(python3 -I - "$RAIZ/scripts" <<'PYFIM' 2>/dev/null
import os, sys
sys.path.insert(0, sys.argv[1])
import pack
for base in pack.raizes():
    try:
        ids = sorted(os.listdir(base))
    except OSError:
        continue
    for pid in ids:
        dir_pack = os.path.join(base, pid)
        if not os.path.isfile(os.path.join(dir_pack, "pack.json")):
            continue
        mapa = pack.acervo("icones.resgatados.mapa", ref=dir_pack)
        pasta = pack.acervo("icones.resgatados.desenhos", ref=dir_pack)
        if mapa and pasta:
            print(mapa)
            print(pasta.rstrip("/"))
            raise SystemExit(0)
PYFIM
)
fi

declare -A DESKTOP_ABSOLUTO=(
  [guvcview.desktop]="guvcview"
)

_resgatados_cedidos() {
  MEOW_PACK_DIR="$(meow_pack_dir)" python3 "$RAIZ/scripts/pack.py" fontes 2>/dev/null \
    | awk -F'\t' '$3 ~ /^pack:/ || $3 == "escolha" { print $1 }'
}

_resgatados_todos() {
  sed -e 's/#.*//' "$MAPA" | awk -F: 'NF>=3 { gsub(/^[ \t]+|[ \t]+$/, "", $1); if ($1 != "") print $1 }'
}

_resgatados_nomes() {
  [ -f "$MAPA" ] || return 1
  local cedidos nome
  cedidos="$(_resgatados_cedidos)"
  _resgatados_todos \
    | awk -v cedidos="$cedidos" 'BEGIN { n = split(cedidos, c, "\n"); for (i = 1; i <= n; i++) fora[c[i]] = 1 }
                                 !($0 in fora)' \
    | while IFS= read -r nome; do meow_nome_seguro "$nome" && printf '%s\n' "$nome"; done
  return 0
}

_resgatados_tortos() {
  local nome n=0
  [ -f "$MAPA" ] || { printf 0; return 0; }
  while IFS= read -r nome; do meow_nome_seguro "$nome" || n=$((n + 1)); done < <(_resgatados_todos)
  printf '%s' "$n"
}

_resgatados_instalar() {
  [ "$SO_TIRAR" = "0" ] || { meow_pula "o pack no ar não traz resgatados"; return "$MEOW_SEM_DEPENDENCIA"; }
  local rc=0 nome origem
  local postos=0 faltando=()

  while read -r nome; do
    [ -n "$nome" ] || continue
    origem="$(meow_dentro "$ACERVO" "$nome.svg")" || origem=""
    if [ -z "$origem" ] || [ ! -f "$origem" ]; then
      faltando+=("$nome"); continue
    fi
    meow_icones_derivar "$origem" "$nome" "$TEMA_DIR"
    case $? in
      0) : ;;
      1) postos=$((postos+1)) ;;
      *) rc=2 ;;
    esac
  done < <(_resgatados_nomes)

  if [ "${#faltando[@]}" -gt 0 ]; then
    meow_aviso "no mapa mas sem desenho em $ACERVO/: ${faltando[*]}"
    [ "$rc" = "0" ] && rc=1
  fi

  local rc_d; _resgatados_desktops_instalar; rc_d=$?
  [ "$rc_d" = "2" ] && rc=2
  [ "$rc_d" = "1" ] && [ "$rc" = "0" ] && rc=1

  local rc_c; _resgatados_cache; rc_c=$?
  [ "$rc_c" = "1" ] && [ "$rc" = "0" ] && rc=1

  if [ "$postos" -gt 0 ]; then
    meow_ok "$postos ícone(s) resgatado(s) no tema"
    _resgatados_avisar
    rc=1
  elif [ "$rc" = "0" ]; then
    meow_ok "os $(_resgatados_estado | cut -d' ' -f1) resgatados já estão no tema"
  fi
  return "$rc"
}

_resgatados_avisar() {
  meow_seco && return 0
  meow_tela_reler
  case $? in
    0) meow_ok "os ícones resgatados já estão na dock e no menu" ;;
    3) meow_info "fora da sessão gráfica: os ícones resgatados aparecem no próximo login" ;;
  esac
  return 0
}

_resgatados_cache() {
  local cache="$TEMA_DIR/icon-theme.cache"
  [ -f "$cache" ] || return 0
  [ -n "$(find "$ALVO" -name '*.svg' -newer "$cache" -print -quit 2>/dev/null)" ] || return 0

  if meow_seco; then
    meow_muda "reindexaria a cache do tema ($cache está velha e esconde os resgatados)"
    return 1
  fi
  if ! meow_tem gtk-update-icon-cache; then
    meow_aviso "$cache está velha e esconde os ícones novos, e não há gtk-update-icon-cache"
    meow_info  "  apague o arquivo: rm '$cache'"
    return 1
  fi
  if gtk-update-icon-cache -q -f "$TEMA_DIR" 2>/dev/null; then
    meow_ok "cache do tema reindexada (ela escondia os resgatados)"
    return 1
  fi
  meow_aviso "não consegui reindexar $cache — apague-a se algum ícone não aparecer"
  return 1
}

_resgatados_desktops_instalar() {
  local rc=0 arquivo nome origem conteudo destino
  for arquivo in "${!DESKTOP_ABSOLUTO[@]}"; do
    nome="${DESKTOP_ABSOLUTO[$arquivo]}"
    [ -f "$ACERVO/$nome.svg" ] || continue
    origem="/usr/share/applications/$arquivo"
    destino="$APPS_USUARIO/$arquivo"
    [ -f "$destino" ] && origem="$destino"
    [ -f "$origem" ] || continue
    conteudo="$(sed -E "s|^Icon=.*|Icon=$nome|" "$origem")" || { rc=2; continue; }
    meow_escrever "$destino" "$conteudo" 644
    case $? in 0) : ;; 1) [ "$rc" = "0" ] && rc=1 ;; *) rc=2 ;; esac
  done
  return "$rc"
}

_resgatados_remover() {
  local rc=0 nome tirados=0 arquivo de_quem
  while read -r nome; do
    [ -n "$nome" ] || continue
    [ -f "$ALVO/$nome.svg" ] || continue
    if [ "$SO_TIRAR" = "1" ] && { ! de_quem="$(meow_dentro "$ACERVO" "$nome.svg")" \
         || [ "$(cat "$ALVO/$nome.svg")" != "$(cat "$de_quem" 2>/dev/null)" ]; }; then
      continue
    fi
    if meow_seco; then
      meow_muda "removeria $ALVO/$nome.svg"; rc=1; continue
    fi
    rm -f "$ALVO/$nome.svg" && tirados=$((tirados+1)) || rc=2
  done < <(_resgatados_nomes)

  for arquivo in "${!DESKTOP_ABSOLUTO[@]}"; do
    [ -f "$APPS_USUARIO/$arquivo" ] || continue
    [ -f "/usr/share/applications/$arquivo" ] || continue
    grep -q "^Icon=${DESKTOP_ABSOLUTO[$arquivo]}$" "$APPS_USUARIO/$arquivo" || continue
    if meow_seco; then
      meow_muda "removeria $APPS_USUARIO/$arquivo"; rc=1; continue
    fi
    rm -f "$APPS_USUARIO/$arquivo" || rc=2
  done

  if [ "$tirados" -gt 0 ] && [ -f "$TEMA_DIR/icon-theme.cache" ] && meow_tem gtk-update-icon-cache; then
    gtk-update-icon-cache -q -f "$TEMA_DIR" 2>/dev/null \
      && meow_ok "cache do tema reindexada (ela ainda anunciava os retirados)" \
      || meow_aviso "não consegui reindexar a cache — apague $TEMA_DIR/icon-theme.cache se algum ícone sumir"
  fi

  [ "$tirados" -gt 0 ] && { meow_ok "$tirados ícone(s) resgatado(s) retirado(s) do tema"; rc=1; }
  if [ "$rc" = "0" ]; then
    if [ "$SO_TIRAR" = "1" ]; then meow_ok "o pack no ar não traz resgatados — nenhum no tema"
    else meow_ok "resgatados desligados — nenhum no tema"; fi
  fi
  return "$rc"
}

_resgatados_estado() {
  local total=0 postos=0 nome
  while read -r nome; do
    [ -n "$nome" ] || continue
    total=$((total+1))
    [ -f "$ALVO/$nome.svg" ] && postos=$((postos+1))
  done < <(_resgatados_nomes)
  printf '%s %s' "$postos" "$total"
}

_resgatados_aplicar() {
  local tortos
  tortos="$(_resgatados_tortos)"
  [ "${tortos:-0}" -gt 0 ] && meow_aviso "$tortos linha(s) com nome fora da forma no mapa dos resgatados — pulada(s)"
  if [ "${ICONES_RESGATADOS:-sim}" = "sim" ] && [ "$SO_TIRAR" = "0" ]; then _resgatados_instalar
  else _resgatados_remover; fi
}

case "${1:-aplicar}" in
  aplicar|--aplicar) _resgatados_aplicar ;;
  --conferir) MEOW_SECO=1 _resgatados_aplicar ;;
  instalar) _resgatados_instalar ;;
  remover)  _resgatados_remover ;;
  estado)   _resgatados_estado ;;
  *) printf 'uso: icones_resgatados.sh [aplicar|--conferir|instalar|remover|estado]\n' >&2; exit 2 ;;
esac

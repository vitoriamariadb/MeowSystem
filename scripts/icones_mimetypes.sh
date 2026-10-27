#!/usr/bin/env bash
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

_pack_ref="$(meow_pack_dir)"
[ -n "$_pack_ref" ] || _pack_ref="$(meow_pack_padrao_dir || true)"
FLAVOR_ICONES="$(python3 "$RAIZ/scripts/pack.py" flavor-icones "$_pack_ref")" || FLAVOR_ICONES=""
_pintar_onde=""
{ [ "${1:-}" = "--conferir" ] || meow_seco; } && _pintar_onde="--temporario"
ORIGEM="$( [ -n "$FLAVOR_ICONES" ] && python3 "$RAIZ/scripts/pack.py" pintados "$_pack_ref" "$FLAVOR_ICONES" $_pintar_onde)" || ORIGEM=""
_pintado_temporario=""
case "$ORIGEM" in */meow-pintados-*) _pintado_temporario="$ORIGEM"; trap 'rm -rf "$_pintado_temporario"' EXIT ;; esac
[ -n "$FLAVOR_ICONES" ] || ORIGEM=""
DONO_ACERVO="$( [ -n "$ORIGEM" ] && python3 -I - "$RAIZ/scripts" "$_pack_ref" <<'PY' 2>/dev/null
import sys
sys.path.insert(0, sys.argv[1])
import pack
print(pack.campo(sys.argv[2], "nome", "") or "")
PY
)"
[ -n "$DONO_ACERVO" ] || DONO_ACERVO="Catppuccin"
MAPA="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" \
          icones.mimetypes.mapa)" || MAPA=""
TEMA="${ICONES_TEMA:-MeowSystem-Icons}"
DESTINO="$HOME/.local/share/icons/$TEMA/scalable/mimetypes"

declare -A MAPA_LIDO=()
_ler_mapa() {
  local linha nome glifo pulados=()
  while IFS= read -r linha || [ -n "$linha" ]; do
    linha="${linha%$'\r'}"
    case "$linha" in ''|'#'*) continue ;; esac
    nome="${linha%%:*}"; glifo="${linha#*:}"
    if ! meow_nome_seguro "$nome" || ! meow_nome_seguro "$glifo"; then
      pulados+=("$(meow_texto_seguro "$nome")"); continue
    fi
    [ -n "$nome" ] && [ -n "$glifo" ] && MAPA_LIDO["$nome"]="$glifo"
  done < "$MAPA"
  [ "${#pulados[@]}" -gt 0 ] && \
    meow_aviso "$MAPA: ${#pulados[@]} linha(s) com nome fora de [A-Za-z0-9._+-] (ou com '..') puladas: ${pulados[*]:0:3}"
  return 0
}

_pronto() {
  if [ ! -d "$ORIGEM" ]; then
    meow_pula "não há acervo de mimetype para o flavor '$FLAVOR_ICONES' — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$MAPA" ]; then
    meow_pula "o pack não traz mapa de mimetype (icones.mimetypes.mapa) — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

_desejado() {
  local nome glifo real
  for nome in "${!MAPA_LIDO[@]}"; do
    glifo="${MAPA_LIDO[$nome]}"
    [ -f "$ORIGEM/$glifo.svg" ] && [ ! -L "$ORIGEM/$glifo.svg" ] \
      && real="$(meow_dentro "$ORIGEM" "$glifo.svg")" \
      && printf '%s\t%s\n' "$nome" "$real"
  done
  return 0
}

_conferir() {
  local nome origem divergentes=0 ausentes=0 orfaos=0 total=0 arq
  while IFS=$'\t' read -r nome origem; do
    total=$((total + 1))
    if [ ! -f "$DESTINO/$nome.svg" ]; then
      ausentes=$((ausentes + 1))
    elif [ "$(cat "$origem")" != "$(cat "$DESTINO/$nome.svg")" ]; then
      divergentes=$((divergentes + 1))
    fi
  done < <(_desejado)

  if [ -d "$DESTINO" ]; then
    for arq in "$DESTINO"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      [ -n "${MAPA_LIDO[$nome]:-}" ] || orfaos=$((orfaos + 1))
    done
  fi

  if [ "$ausentes" = 0 ] && [ "$divergentes" = 0 ] && [ "$orfaos" = 0 ]; then
    meow_ok "$total tipos de arquivo já vestidos de $DONO_ACERVO $FLAVOR_ICONES"
    return "$MEOW_OK"
  fi
  meow_muda "tipos de arquivo: $ausentes a instalar, $divergentes a atualizar, $orfaos a remover (de $total)"
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local nome origem arq mudou=0 postos=0 removidos=0 rc

  while IFS=$'\t' read -r nome origem; do
    set +e
    meow_escrever "$DESTINO/$nome.svg" "$(cat "$origem")" 644
    rc=$?
    set -e
    case "$rc" in
      "$MEOW_OK") ;;
      "$MEOW_DIVERGENTE") mudou=1; postos=$((postos + 1)) ;;
      *) meow_erro "não consegui escrever $DESTINO/$nome.svg"; return "$MEOW_ERRO" ;;
    esac
  done < <(_desejado)

  if [ -d "$DESTINO" ]; then
    for arq in "$DESTINO"/*.svg; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .svg)"
      if [ -z "${MAPA_LIDO[$nome]:-}" ]; then
        if meow_seco; then
          meow_muda "removeria $arq (saiu do mapa)"
        else
          meow_destino_permitido "$arq" || return "$MEOW_ERRO"
          rm -f "$arq"
        fi
        mudou=1; removidos=$((removidos + 1))
      fi
    done
  fi

  if [ "$mudou" = 0 ]; then
    meow_ok "tipos de arquivo já vestidos de $DONO_ACERVO $FLAVOR_ICONES"
    return "$MEOW_OK"
  fi
  meow_info "tipos de arquivo: $postos posto(s), $removidos removido(s) — flavor $FLAVOR_ICONES"
  meow_info "o cosmic-files relê o tema ao abrir uma janela nova"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  _ler_mapa
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"

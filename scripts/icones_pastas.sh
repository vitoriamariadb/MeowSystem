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
_pastas_decl="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" icones.pastas.desenhos 2>/dev/null)" || _pastas_decl=""
_molde="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" icones.mimetypes.desenhos 2>/dev/null)" || _molde=""
_pastas_do_pack=""
[ -n "$_pastas_decl" ] && [ "${_pastas_decl%/}" != "${_molde%/}" ] && _pastas_do_pack="${_pastas_decl%/}"
if [ -n "$_pastas_do_pack" ] && [ -d "$_pastas_do_pack" ]; then
  ORIGEM="$_pastas_do_pack"
fi
LEVADAS=""
if [ -n "$_pack_ref" ] && [ -d "$_pack_ref/icones/sistema" ] && [ ! -L "$_pack_ref/icones/sistema" ]; then
  _levadas="$(cd "$_pack_ref/icones/sistema" && pwd -P)"
  _decl_real="$( [ -n "$_pastas_decl" ] && cd "$_pastas_decl" 2>/dev/null && pwd -P)" || _decl_real=""
  _molde_real="$( [ -n "$_molde" ] && cd "$_molde" 2>/dev/null && pwd -P)" || _molde_real=""
  [ "$_levadas" != "$_decl_real" ] && [ "$_levadas" != "$_molde_real" ] && LEVADAS="$_levadas"
fi
VESTIDAS="de Catppuccin $FLAVOR_ICONES"; DE_QUEM="flavor $FLAVOR_ICONES"
if [ -n "$ORIGEM" ] && [ "$ORIGEM" = "$_pastas_do_pack" ]; then
  _nome_pack="$(python3 "$RAIZ/scripts/pack.py" adocao "${PACK:-}" "${FLAVOR:-}" 2>/dev/null \
                | sed -n 's/^nome=//p')" || _nome_pack=""
  VESTIDAS="com os desenhos do pack ${_nome_pack:-no ar}"
  DE_QUEM="desenhos do pack ${_nome_pack:-no ar}"
fi
MAPA="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" icones.pastas.mapa)" || MAPA=""
[ -n "$MAPA" ] || MAPA="$RAIZ/packs/meowsystem/icones/pastas.map"
TEMA="${ICONES_TEMA:-MeowSystem-Icons}"
DESTINO="$HOME/.local/share/icons/$TEMA/scalable/places"

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
    meow_pula "não há acervo de pasta para o flavor '$FLAVOR_ICONES' — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$MAPA" ]; then
    meow_pula "sem packs/meowsystem/icones/pastas.map — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

_desejado() {
  local nome glifo real fora=()
  for nome in "${!MAPA_LIDO[@]}"; do
    glifo="${MAPA_LIDO[$nome]}"
    if [ -n "$LEVADAS" ] && [ -f "$LEVADAS/$nome.svg" ] && [ ! -L "$LEVADAS/$nome.svg" ] \
       && real="$(meow_dentro "$LEVADAS" "$nome.svg")"; then
      printf '%s\t%s\n' "$nome" "$real"
      continue
    fi
    if [ -f "$ORIGEM/$glifo.svg" ]; then
      { [ ! -L "$ORIGEM/$glifo.svg" ] && real="$(meow_dentro "$ORIGEM" "$glifo.svg")"; } \
        || { fora+=("$glifo.svg"); continue; }
      printf '%s\t%s\n' "$nome" "$real"
    elif [ -f "$ORIGEM/$nome.svg" ]; then
      { [ ! -L "$ORIGEM/$nome.svg" ] && real="$(meow_dentro "$ORIGEM" "$nome.svg")"; } \
        || { fora+=("$nome.svg"); continue; }
      printf '%s\t%s\n' "$nome" "$real"
    fi
  done
  [ "${#fora[@]}" -gt 0 ] && \
    meow_aviso "$ORIGEM: ${#fora[@]} desenho(s) que são link (link não entra), pulados: ${fora[*]:0:3}"
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
    meow_ok "$total pasta(s) especiais já vestidas $VESTIDAS"
    return "$MEOW_OK"
  fi
  meow_muda "pastas especiais: $ausentes a instalar, $divergentes a atualizar, $orfaos a remover (de $total)"
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
    meow_ok "pastas especiais já vestidas $VESTIDAS"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_info "pastas especiais: poria $postos, removeria $removidos — $DE_QUEM"
  else
    meow_info "pastas especiais: $postos posto(s), $removidos removido(s) — $DE_QUEM"
  fi
  meow_info "o cosmic-files relê o tema ao abrir uma janela nova"
  return "$MEOW_DIVERGENTE"
}

_desligado() { [ "${PASTAS_XDG:-nao}" != "sim" ]; }

main() {
  _pronto || return $?
  _ler_mapa
  if _desligado; then
    if [ -d "$DESTINO" ] && [ -n "$(find "$DESTINO" -maxdepth 1 -name '*.svg' -print -quit 2>/dev/null)" ]; then
      if meow_seco || [ "${1:-}" = "--conferir" ]; then
        meow_info "PASTAS_XDG=\"${PASTAS_XDG:-nao}\" — devolveria as pastas especiais à cor das outras pastas"
      else
        meow_info "PASTAS_XDG=\"${PASTAS_XDG:-nao}\" — devolvendo as pastas especiais à cor das outras pastas"
      fi
      MAPA_LIDO=()
    else
      meow_ok "pastas especiais desligadas (PASTAS_XDG=\"${PASTAS_XDG:-nao}\") — elas seguem a cor das outras pastas"
      return "$MEOW_OK"
    fi
  fi
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"

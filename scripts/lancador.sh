#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
CACHE="$APPS/mimeinfo.cache"
QUARENTENA="$MEOW_ESTADO/lancador-quarentena"
REGISTRO="$QUARENTENA/registro.tsv"

MODO="aplicar"
case "${1:-}" in
  --conferir) MODO="conferir" ;;
  --reverter) MODO="reverter" ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--reverter]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && [ "$MODO" = "aplicar" ] && MODO="conferir"

_cache_velha() {
  [ -d "$APPS" ] || return 1
  if [ ! -f "$CACHE" ]; then
    find "$APPS" -maxdepth 1 -name '*.desktop' -print -quit | grep -q .
    return $?
  fi
  find "$APPS" -maxdepth 1 -name '*.desktop' -newer "$CACHE" -print -quit | grep -q .
}

_refazer_cache() {
  if ! meow_tem update-desktop-database; then
    meow_pula "sem update-desktop-database — o mimeinfo.cache do home fica como está"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  meow_guardar_antes "$CACHE"
  update-desktop-database "$APPS" 2>/dev/null
}

_reverter() {
  local origem destino n=0 resto
  [ -s "$REGISTRO" ] || { meow_ok "a quarentena do lançador está vazia"; return "$MEOW_OK"; }
  resto="$(mktemp)" || return "$MEOW_ERRO"
  while IFS=$'\t' read -r origem destino; do
    [ -n "$origem" ] || continue
    if [ ! -e "$destino" ] && [ ! -L "$destino" ]; then continue; fi
    if [ -e "$origem" ] || [ -L "$origem" ]; then
      meow_aviso "$(basename "$origem") voltou a existir — a cópia fica em $destino"
      printf '%s\t%s\n' "$origem" "$destino" >> "$resto"
      continue
    fi
    if meow_seco; then meow_muda "devolveria $(basename "$origem")"; n=$((n + 1)); continue; fi
    meow_guardar_antes "$destino"; meow_guardar_antes "$origem"
    mkdir -p "$(dirname "$origem")" && mv -f "$destino" "$origem" && n=$((n + 1))
  done < "$REGISTRO"
  meow_seco || { meow_guardar_antes "$REGISTRO"; mv -f "$resto" "$REGISTRO"; }
  rm -f "$resto"
  [ "$n" = 0 ] && { meow_ok "nada a devolver da quarentena do lançador"; return "$MEOW_OK"; }
  meow_seco || _refazer_cache
  meow_ok "$n lançador(es) devolvido(s) da quarentena"
  return "$MEOW_DIVERGENTE"
}

[ "$MODO" = "reverter" ] && { _reverter; exit $?; }

if ! meow_tem python3; then
  meow_pula "sem python3 — os lançadores órfãos não foram conferidos"
  exit "$MEOW_SEM_DEPENDENCIA"
fi
orfaos="$(python3 "$RAIZ/scripts/lancador_orfaos.py")" || {
  meow_erro "não consegui ler os lançadores do home"; exit "$MEOW_ERRO"; }

n="$(printf '%s' "$orfaos" | grep -c .)"
velha=0
meow_tem update-desktop-database && _cache_velha && velha=1

if [ "$n" = 0 ] && [ "$velha" = 0 ]; then
  meow_ok "lançador do home sem órfão, e o mimeinfo.cache em dia"
  exit "$MEOW_OK"
fi
if [ "$MODO" = "conferir" ]; then
  if [ "$n" -gt 0 ]; then
    meow_muda "$n lançador(es) de programa que não existe mais a levar para a quarentena"
    while IFS=$'\t' read -r arq nome alvo; do
      [ -n "$arq" ] && meow_info "  $nome ($alvo)"
    done <<< "$orfaos"
  else
    meow_muda "o mimeinfo.cache do home é mais velho que um lançador"
  fi
  exit "$MEOW_DIVERGENTE"
fi

while IFS=$'\t' read -r arq nome alvo; do
  [ -n "$arq" ] || continue
  meow_destino_permitido "$arq" || exit "$MEOW_ERRO"
  meow_guardar_pasta "$QUARENTENA"
  mkdir -p "$QUARENTENA" || exit "$MEOW_ERRO"
  destino="$QUARENTENA/$(basename "$arq")"
  { [ -e "$destino" ] || [ -L "$destino" ]; } && destino="$QUARENTENA/$(basename "$arq" .desktop).$(date +%s).desktop"
  meow_guardar_antes "$arq"; meow_guardar_antes "$REGISTRO"
  mv -f "$arq" "$destino" || { meow_erro "não consegui mover $arq"; exit "$MEOW_ERRO"; }
  printf '%s\t%s\n' "$arq" "$destino" >> "$REGISTRO"
  meow_info "$nome foi para a quarentena ($destino)"
done <<< "$orfaos"

if _refazer_cache; then
  meow_ok "lançador do home conforme: $n na quarentena, mimeinfo.cache refeito"
else
  meow_ok "lançador do home conforme: $n na quarentena"
fi
exit "$MEOW_DIVERGENTE"

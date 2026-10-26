meow_guardar_antes() {
  local alvo lista
  [ -n "${MEOW_BACKUPS:-}" ] || return 0
  if [ "${MEOW_SECO:-0}" = "1" ] || [ "${MEOW_DRY_RUN:-0}" = "1" ]; then return 0; fi
  alvo="$(readlink -m -- "$1")"
  case "$alvo" in /*) ;; *) return 0 ;; esac
  case "$alvo" in *$'\t'*|*$'\n'*) return 0 ;; esac
  lista="$MEOW_BACKUPS/tocados.tsv"
  mkdir -p "$MEOW_BACKUPS" 2>/dev/null || return 0
  if [ -f "$lista" ] && cut -f1 "$lista" | grep -qxF -- "$alvo"; then return 0; fi
  if [ -e "$alvo" ] || [ -L "$alvo" ]; then
    [ -d "$alvo" ] && [ ! -L "$alvo" ] && return 0
    mkdir -p "$MEOW_BACKUPS/antes$(dirname "$alvo")" 2>/dev/null \
      && cp -a -- "$alvo" "$MEOW_BACKUPS/antes$alvo" 2>/dev/null || return 0
    printf '%s\texistia\n' "$alvo" >> "$lista"
  else
    printf '%s\tnovo\n' "$alvo" >> "$lista"
  fi
  return 0
}

meow_guardar_pasta() {
  local alvo lista
  [ -n "${MEOW_BACKUPS:-}" ] || return 0
  if [ "${MEOW_SECO:-0}" = "1" ] || [ "${MEOW_DRY_RUN:-0}" = "1" ]; then return 0; fi
  alvo="$(readlink -m -- "$1")"
  case "$alvo" in /*) ;; *) return 0 ;; esac
  case "$alvo" in *$'\t'*|*$'\n'*) return 0 ;; esac
  lista="$MEOW_BACKUPS/tocados.tsv"
  mkdir -p "$MEOW_BACKUPS" 2>/dev/null || return 0
  if [ -f "$lista" ] && cut -f1 "$lista" | grep -qxF -- "$alvo"; then return 0; fi
  if [ -d "$alvo" ] && [ ! -L "$alvo" ]; then
    mkdir -p "$MEOW_BACKUPS/antes$(dirname "$alvo")" 2>/dev/null \
      && cp -a -- "$alvo" "$MEOW_BACKUPS/antes$alvo" 2>/dev/null || return 0
    printf '%s\tpasta\n' "$alvo" >> "$lista"
  elif [ ! -e "$alvo" ] && [ ! -L "$alvo" ]; then
    printf '%s\tpasta-nova\n' "$alvo" >> "$lista"
  fi
  return 0
}

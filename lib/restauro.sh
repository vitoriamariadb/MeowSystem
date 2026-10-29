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

meow_vigiar_inicio() {
  _MEOW_VIGIA_RAIZES=("$@")
  _MEOW_VIGIA_ANTES=""
  [ -n "${MEOW_BACKUPS:-}" ] || return 0
  if [ "${MEOW_SECO:-0}" = "1" ] || [ "${MEOW_DRY_RUN:-0}" = "1" ]; then return 0; fi
  _MEOW_VIGIA_ANTES="$(mktemp -t meow-vigia.XXXXXX)" || { _MEOW_VIGIA_ANTES=""; return 0; }
  find "$@" 2>/dev/null | sort > "$_MEOW_VIGIA_ANTES"
  return 0
}

meow_vigiar_fim() {
  local depois lista novo
  [ -n "${_MEOW_VIGIA_ANTES:-}" ] || return 0
  depois="$(mktemp -t meow-vigia.XXXXXX)" || { rm -f "$_MEOW_VIGIA_ANTES"; _MEOW_VIGIA_ANTES=""; return 0; }
  find "${_MEOW_VIGIA_RAIZES[@]}" 2>/dev/null | sort > "$depois"
  lista="$MEOW_BACKUPS/tocados.tsv"
  mkdir -p "$MEOW_BACKUPS" 2>/dev/null || true
  [ -f "$lista" ] || : > "$lista"
  while IFS= read -r novo; do
    case "$novo" in /*) ;; *) continue ;; esac
    if [ -d "$novo" ] && [ ! -L "$novo" ]; then
      printf '%s\tpasta-nova\n' "$novo" >> "$lista"
    else
      printf '%s\tnovo\n' "$novo" >> "$lista"
    fi
  done < <(awk -v raizes="$(printf '%s\n' "${_MEOW_VIGIA_RAIZES[@]}")" -v lista="$lista" '
    BEGIN {
      n = split(raizes, r, "\n"); for (i = 1; i <= n; i++) if (r[i] != "") raiz[r[i]] = 1
      while ((getline l < lista) > 0) { split(l, c, "\t"); visto[c[1]] = 1 }
    }
    FILENAME == ARGV[1] { antes[$0] = 1; next }
    !($0 in antes) && !($0 in visto) {
      pai = $0; sub(/\/[^\/]*$/, "", pai)
      if (($0 in raiz) || (pai in antes)) print $0
    }' "$_MEOW_VIGIA_ANTES" "$depois")
  rm -f "$_MEOW_VIGIA_ANTES" "$depois"
  _MEOW_VIGIA_ANTES=""
  return 0
}

meow_guardar_antes() {
  local alvo lista
  [ -n "${MEOW_BACKUPS:-}" ] || return 0
  if [ "${MEOW_SECO:-0}" = "1" ] || [ "${MEOW_DRY_RUN:-0}" = "1" ]; then return 0; fi
  alvo="$(readlink -m -- "$1")"
  case "$alvo" in /*) ;; *) return 0 ;; esac
  case "$alvo" in *$'\t'*|*$'\n'*) return 0 ;; esac
  lista="$MEOW_BACKUPS/tocados.tsv"
  mkdir -p "$MEOW_BACKUPS" 2>/dev/null || return 0
  if [ -f "$lista" ] && cut -f1 "$lista" | grep -xF -- "$alvo" >/dev/null; then return 0; fi
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
  if [ -f "$lista" ] && cut -f1 "$lista" | grep -xF -- "$alvo" >/dev/null; then return 0; fi
  if [ -d "$alvo" ] && [ ! -L "$alvo" ]; then
    mkdir -p "$MEOW_BACKUPS/antes$(dirname "$alvo")" 2>/dev/null \
      && cp -a -- "$alvo" "$MEOW_BACKUPS/antes$alvo" 2>/dev/null || return 0
    printf '%s\tpasta\n' "$alvo" >> "$lista"
  elif [ ! -e "$alvo" ] && [ ! -L "$alvo" ]; then
    printf '%s\tpasta-nova\n' "$alvo" >> "$lista"
  fi
  return 0
}

meow_marcar_novo() {
  local alvo lista
  [ -n "${MEOW_BACKUPS:-}" ] || return 0
  if [ "${MEOW_SECO:-0}" = "1" ] || [ "${MEOW_DRY_RUN:-0}" = "1" ]; then return 0; fi
  alvo="$(readlink -m -- "$1")"
  case "$alvo" in /*) ;; *) return 0 ;; esac
  case "$alvo" in *$'\t'*|*$'\n'*) return 0 ;; esac
  [ -e "$alvo" ] || [ -L "$alvo" ] || return 0
  lista="$MEOW_BACKUPS/tocados.tsv"
  mkdir -p "$MEOW_BACKUPS" 2>/dev/null || return 0
  if [ -f "$lista" ] && cut -f1 "$lista" | grep -xF -- "$alvo" >/dev/null; then return 0; fi
  printf '%s\tnovo\n' "$alvo" >> "$lista"
  return 0
}

meow_marcar_pasta_nova() {
  local alvo lista
  [ -n "${MEOW_BACKUPS:-}" ] || return 0
  if [ "${MEOW_SECO:-0}" = "1" ] || [ "${MEOW_DRY_RUN:-0}" = "1" ]; then return 0; fi
  alvo="$(readlink -m -- "$1")"
  case "$alvo" in /*) ;; *) return 0 ;; esac
  case "$alvo" in *$'\t'*|*$'\n'*) return 0 ;; esac
  [ -d "$alvo" ] && [ ! -L "$alvo" ] || return 0
  lista="$MEOW_BACKUPS/tocados.tsv"
  mkdir -p "$MEOW_BACKUPS" 2>/dev/null || return 0
  if [ -f "$lista" ] && cut -f1 "$lista" | grep -xF -- "$alvo" >/dev/null; then return 0; fi
  printf '%s\tpasta-nova\n' "$alvo" >> "$lista"
  return 0
}

meow_valores_de_antes_pasta() {
  local d
  [ -n "${MEOW_ESTADO:-}" ] || return 1
  for d in "$MEOW_ESTADO"/backups/*-valores-PRIMEIRO-pre-instalacao; do
    [ -d "$d" ] && { printf '%s' "$d"; return 0; }
  done
  return 1
}

meow_guardar_valor_de_antes() {
  local nome="$1" valor="$2" pasta tmp
  [ -n "${MEOW_ESTADO:-}" ] || return 0
  if [ "${MEOW_SECO:-0}" = "1" ] || [ "${MEOW_DRY_RUN:-0}" = "1" ]; then return 0; fi
  if ! pasta="$(meow_valores_de_antes_pasta)"; then
    pasta="$MEOW_ESTADO/backups/$(date +%Y-%m-%dT%H-%M-%S)-valores-PRIMEIRO-pre-instalacao"
    mkdir -p "$pasta" 2>/dev/null || return 0
  fi
  [ -e "$pasta/$nome" ] && return 0
  tmp="$(mktemp -p "$pasta" ".valor.XXXXXX")" || return 0
  if printf '%s\n' "$valor" > "$tmp"; then mv -f "$tmp" "$pasta/$nome"; else rm -f "$tmp"; fi
  return 0
}

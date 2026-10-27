#!/usr/bin/env bash

meow_flatpak_ler() {
  local verbo="$1"
  shift
  if [ -d "$HOME/.local/share/flatpak/repo" ]; then
    flatpak "$verbo" "$@"
  else
    flatpak "$verbo" --system "$@"
  fi
}

meow_flatpak_apps() {
  meow_tem flatpak || return 0
  meow_flatpak_ler list --app --columns=application 2>/dev/null | sed '/^[[:space:]]*$/d' | sort -u
}

meow_flatpak_pasta() {
  meow_flatpak_ler info --show-location "$1" 2>/dev/null
}

_meow_flatpak_cache_libadwaita() { printf '%s/meowsystem/flatpak-libadwaita.tsv' "${XDG_CACHE_HOME:-$HOME/.cache}"; }

_meow_flatpak_cache_gravar() {
  local arq="$1" id="$2" commit="$3" veredito="$4" tmp
  mkdir -p "$(dirname "$arq")" 2>/dev/null || return 0
  tmp="$(mktemp -p "$(dirname "$arq")" ".libadwaita.XXXXXX" 2>/dev/null)" || return 0
  { [ -f "$arq" ] && awk -F'\t' -v i="$id" '$1 != i' "$arq"
    printf '%s\t%s\t%s\n' "$id" "$commit" "$veredito"; } > "$tmp" 2>/dev/null
  mv -f "$tmp" "$arq" 2>/dev/null || rm -f "$tmp"
  return 0
}

meow_flatpak_usa_libadwaita() {
  local id="$1" pasta commit cache dito veredito=nao
  pasta="$(meow_flatpak_pasta "$id")" || return 1
  [ -d "$pasta/files" ] || return 1
  commit="$(meow_flatpak_ler info --show-commit "$id" 2>/dev/null)"
  cache="$(_meow_flatpak_cache_libadwaita)"
  if [ -n "$commit" ] && [ -f "$cache" ]; then
    dito="$(awk -F'\t' -v i="$id" -v c="$commit" '$1 == i && $2 == c { print $3; exit }' "$cache")"
    case "$dito" in sim) return 0 ;; nao) return 1 ;; esac
  fi
  grep -rqaE 'libadwaita-1\.so|require_version\(.Adw.|gi://Adw' "$pasta/files" 2>/dev/null && veredito=sim
  [ -n "$commit" ] && _meow_flatpak_cache_gravar "$cache" "$id" "$commit" "$veredito"
  [ "$veredito" = sim ]
}

meow_flatpak_apps_libadwaita() {
  local id
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    meow_flatpak_usa_libadwaita "$id" && printf '%s\n' "$id"
  done < <(meow_flatpak_apps)
  return 0
}

meow_flatpak_runtime_gnome() {
  local versao
  versao="$(meow_flatpak_ler info "$1" 2>/dev/null | sed -n 's|.*Runtime:[[:space:]]*org\.gnome\.Platform/[^/]*/||p' | head -n 1)"
  case "$versao" in ''|*[!0-9]*) return 0 ;; esac
  printf '%s' "$versao"
}

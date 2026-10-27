#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[ "${1:-}" = "--conferir" ] && { MEOW_DRY_RUN=1; export MEOW_DRY_RUN; }
. "$MEOW_RAIZ/lib/comum.sh"

ACAO="aplicar"
case "${1:-}" in
  --conferir) ;;
  remover) ACAO="remover" ;;
  ''|aplicar) ;;
  *) meow_erro "uso: terminal_bloco.sh [aplicar|--conferir|remover]"; exit "$MEOW_ERRO" ;;
esac

CARREGADO="${XDG_CONFIG_HOME:-$HOME/.config}/meowsystem/terminal.sh"
MARCA_INICIO="# >>> MeowSystem — o meow põe e tira este bloco >>>"
MARCA_FIM="# <<< MeowSystem <<<"
BLOCO="$MARCA_INICIO
"'[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/meowsystem/terminal.sh" ] && . "${XDG_CONFIG_HOME:-$HOME/.config}/meowsystem/terminal.sh"'"
$MARCA_FIM"

_zdotdir() {
  local z=""
  if [ -n "${ZDOTDIR:-}" ]; then printf '%s' "$ZDOTDIR"; return 0; fi
  [ -r "$HOME/.zshenv" ] && z="$(sed -n -E 's/^[[:space:]]*(export[[:space:]]+)?ZDOTDIR=["'"'"']?([^"'"'"' ]*).*/\2/p' "$HOME/.zshenv" | head -1)"
  z="${z//\$HOME/$HOME}"; z="${z//\$\{HOME\}/$HOME}"; z="${z/#\~/$HOME}"
  printf '%s' "${z:-$HOME}"
}

_alvos() {
  local z; z="$(_zdotdir)/.zshrc"
  { [ -f "$HOME/.bashrc" ] || [ "${SHELL##*/}" = "bash" ]; } && printf '%s\n' "$HOME/.bashrc"
  { [ -f "$z" ] || [ "${SHELL##*/}" = "zsh" ]; } && printf '%s\n' "$z"
  return 0
}

_texto_carregado() {
  cat <<'SH'
# Gerado pelo MeowSystem (scripts/terminal_bloco.sh); a próxima passada o refaz.
case $- in *i*) ;; *) return 0 ;; esac
if [ -n "${ZSH_VERSION:-}" ]; then
  # A completion do `meow`, mesmo com o compinit já rodado.
  fpath=("${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions" $fpath)
  if (( $+functions[compdef] )); then autoload -Uz _meow 2>/dev/null && compdef _meow meow; fi
fi
[ -r "$HOME/.config/meowsystem/fzf.sh" ] && . "$HOME/.config/meowsystem/fzf.sh"
if command -v starship >/dev/null 2>&1; then
  if [ -n "${ZSH_VERSION:-}" ]; then eval "$(starship init zsh)"
  elif [ -n "${BASH_VERSION:-}" ]; then eval "$(starship init bash)"; fi
fi
# O mascote ao abrir o terminal, com os rótulos traduzidos na cor `peach` do pack.
if [ -z "${TMUX:-}" ] && command -v fastfetch >/dev/null 2>&1; then
  printf '\033c'
  _ff=fastfetch
  command -v meow-fetch >/dev/null 2>&1 && _ff=meow-fetch
  _lj="" _lz=""
  [ -n "${MEOW_SGR_LARANJA:-}" ] && _lj="$(printf '\033[%sm' "$MEOW_SGR_LARANJA")" && _lz="$(printf '\033[0m')"
  "$_ff" --pipe false | sed -E "
      s/\\[Discrete\\]/${_lj}(Dedicada)${_lz}/g;
      s/\\[Integrated\\]/${_lj}(Integrada)${_lz}/g;
      s/\\[AC Connected\\]/${_lj}(Conectado)${_lz}/g;
      s/\\[AC Disconnected\\]/${_lj}(Desconectado)${_lz}/g;
      s/\\[External\\]/${_lj}(Externo)${_lz}/g;
      s/\\[Built-in\\]/${_lj}(Embutido)${_lz}/g;
      s/\\[([^][\\x1b]+)\\]/${_lj}(\\1)${_lz}/g
  "
  unset _ff _lj _lz
  echo
fi
SH
}

_sem_bloco() {
  awk -v i="$MARCA_INICIO" -v f="$MARCA_FIM" '
    $0 == i { dentro = 1; next }
    dentro && $0 == f { dentro = 0; next }
    !dentro' "$1"
}

rc=0
_marcar() { [ "$1" = "$MEOW_ERRO" ] && rc="$MEOW_ERRO"; [ "$1" = "$MEOW_DIVERGENTE" ] && [ "$rc" = 0 ] && rc="$MEOW_DIVERGENTE"; }

if [ "$ACAO" = "remover" ]; then
  while IFS= read -r alvo; do
    [ -f "$alvo" ] && grep -qxF -- "$MARCA_INICIO" "$alvo" || continue
    meow_destino_permitido "$alvo" 2>/dev/null || continue
    meow_escrever "$alvo" "$(_sem_bloco "$alvo")" "$(stat -c %a "$alvo" 2>/dev/null || echo 644)"; _marcar $?
    meow_seco || meow_muda "bloco do MeowSystem tirado de $alvo"
  done < <(_alvos)
  if [ -f "$CARREGADO" ]; then
    if meow_seco; then meow_muda "removeria $CARREGADO"; else rm -f "$CARREGADO"; fi
    _marcar "$MEOW_DIVERGENTE"
  fi
  [ "$rc" = 0 ] && meow_ok "nenhum bloco do MeowSystem no terminal"
  exit "$rc"
fi

_excecao_do_zshrc() {
  local z linha
  z="$(_zdotdir)/.zshrc"
  [ -f "$MEOW_VIZINHOS" ] || return 0
  meow_destino_permitido "$z" 2>/dev/null && return 0
  case "$(readlink -m -- "$z")" in /usr/*) return 0 ;; esac
  for linha in ${MEOW_PROIBIDOS_LOCAIS[@]+"${MEOW_PROIBIDOS_LOCAIS[@]}"}; do
    [ "$(readlink -m -- "$z")" = "$linha" ] && return 0
  done
  linha="!${z/#"$HOME"/\$HOME}"
  meow_escrever "$MEOW_VIZINHOS" "$(cat "$MEOW_VIZINHOS")
$linha" "$(stat -c %a "$MEOW_VIZINHOS" 2>/dev/null || echo 644)"; _marcar $?
  meow_seco || meow_muda "exceção do $z no vizinhos.conf"
  MEOW_EXCECOES_LOCAIS+=("$(readlink -m -- "$z")")
}

meow_escrever "$CARREGADO" "$(_texto_carregado)" 644; _marcar $?
_excecao_do_zshrc
postos=() guardados=()
while IFS= read -r alvo; do
  if ! meow_destino_permitido "$alvo" 2>/dev/null; then
    guardados+=("$alvo"); continue
  fi
  base=""
  [ -f "$alvo" ] && base="$(_sem_bloco "$alvo")"
  if [ -n "$base" ]; then novo="$base

$BLOCO"; else novo="$BLOCO"; fi
  meow_escrever "$alvo" "$novo" "$(stat -c %a "$alvo" 2>/dev/null || echo 644)"; _marcar $?
  postos+=("$alvo")
done < <(_alvos)

if [ "${#guardados[@]}" -gt 0 ]; then
  meow_pula "$(printf '%s ' "${guardados[@]}")é de outro projeto (vizinhos.conf) — o bloco fica com ele"
fi
case "$rc" in
  0) meow_ok "bloco do terminal no lugar (${postos[*]:-nenhum arquivo})" ;;
  1) meow_seco || meow_muda "bloco do terminal escrito em ${postos[*]}" ;;
esac
exit "$rc"

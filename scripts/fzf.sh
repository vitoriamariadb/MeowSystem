#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

FZF_ALVO="${FZF_ALVO:-${XDG_CONFIG_HOME:-$HOME/.config}/meowsystem/fzf.sh}"
_FLAVOR="$(meow_flavor)"
_ACCENT="${ACCENT:-mauve}"

ACAO="${1:-aplicar}"
case "$ACAO" in
  aplicar|conferir|mostrar) ;;
  --conferir) ACAO="conferir" ;;
  -h|--help)
    printf 'uso: %s [aplicar|conferir|mostrar]\n\n' "$(basename "$0")"
    printf '  aplicar   escreve as cores do fzf a partir da paleta do pack no ar\n'
    printf '  conferir  não escreve nada (0 igual · 1 divergente · 3 sem o flavor)\n'
    printf '  mostrar   a linha do seu shell que carrega o arquivo\n\n'
    printf 'conf: FLAVOR, ACCENT\n'
    exit 0 ;;
  *) meow_erro "uso: fzf.sh [aplicar|conferir|mostrar]"; exit "$MEOW_ERRO" ;;
esac
# shellcheck disable=SC2034
[ "$ACAO" = "conferir" ] && MEOW_SECO=1

_fzf_linha() {
  local rel="${FZF_ALVO#"$HOME"/}"
  [ "$rel" = "$FZF_ALVO" ] && { printf '[ -r "%s" ] && . "%s"' "$FZF_ALVO" "$FZF_ALVO"; return; }
  printf '[ -r "$HOME/%s" ] && . "$HOME/%s"' "$rel" "$rel"
}

cmd_mostrar() {
  meow_info "no arquivo de inicialização do seu shell (zsh ou bash), no lugar de um"
  meow_info "FZF_DEFAULT_OPTS com cor cravada:"
  printf '\n  %s\n' "$(_fzf_linha)"
  printf "  zstyle ':fzf-tab:*' use-fzf-default-opts yes   # só zsh com fzf-tab\n\n"
  return "$MEOW_OK"
}
[ "$ACAO" = "mostrar" ] && { cmd_mostrar; exit $?; }

PALETA="$(meow_paleta)"

_fzf_cores() {
  python3 -I - "$PALETA" "$_FLAVOR" "$_ACCENT" <<'PY'
import json, sys
paleta, flavor, acento = sys.argv[1:4]
try:
    d = json.load(open(paleta, encoding="utf-8"))
except Exception as e:
    print("não li a paleta: %s" % e, file=sys.stderr); sys.exit(2)
cores = (d.get("flavors") or {}).get(flavor)
if not isinstance(cores, dict):
    sys.exit(3)
mapa = [("bg+", "surface1"), ("fg+", "text"), ("hl", acento), ("hl+", "pink"),
        ("pointer", "green"), ("marker", "green"), ("prompt", acento),
        ("header", "overlay0"), ("border", "overlay0")]
partes = []
for chave, slot in mapa:
    v = cores.get(slot)
    if not (isinstance(v, str) and v.startswith("#")):
        if slot == acento:
            sys.exit(3)
        print("falta o slot '%s' no flavor '%s'" % (slot, flavor), file=sys.stderr)
        sys.exit(2)
    partes.append("%s:%s" % (chave, v))
print("--color=" + ",".join(partes))
PY
}

_fzf_laranja() {
  python3 -I - "$PALETA" "$_FLAVOR" <<'PY'
import json, re, sys
try:
    v = json.load(open(sys.argv[1], encoding="utf-8"))["flavors"][sys.argv[2]].get("peach")
except Exception:
    sys.exit(0)
if isinstance(v, str) and re.fullmatch(r"#[0-9A-Fa-f]{6}", v):
    print("38;2;%d;%d;%d" % tuple(int(v[i:i + 2], 16) for i in (1, 3, 5)))
PY
}

_fzf_texto() {
  cat <<FIM
# Gerado pelo MeowSystem (scripts/fzf.sh) a partir da paleta do pack no ar:
#   $(meow_paleta_nome) · flavor $_FLAVOR · acento $_ACCENT
# Editar aqui não adianta: o próximo \`meow aplicar\` reescreve. Para outras
# opções do fzf, acrescente DEPOIS da linha que carrega este arquivo.
export FZF_DEFAULT_OPTS="$1"
FIM
  [ -n "$2" ] || return 0
  cat <<FIM
# O laranja da paleta (slot peach), para quem pinta texto no terminal:
#   printf '\\e[%sm' "\$MEOW_SGR_LARANJA"
export MEOW_SGR_LARANJA="$2"
FIM
}

meow_tem python3 || { meow_pula "sem python3 — é ele que lê a paleta"; exit "$MEOW_SEM_DEPENDENCIA"; }
[ -f "$PALETA" ] || { meow_erro "paleta ausente: $PALETA"; exit "$MEOW_ERRO"; }

CORES="$(_fzf_cores)"; rc=$?
case "$rc" in
  0) ;;
  3) meow_pula "a paleta $(meow_paleta_nome) não tem FLAVOR=\"$_FLAVOR\" com ACCENT=\"$_ACCENT\" — as cores do fzf ficam como estão"
     exit "$MEOW_SEM_DEPENDENCIA" ;;
  *) meow_erro "não consegui montar as cores do fzf a partir de $(meow_paleta_nome)"
     exit "$MEOW_ERRO" ;;
esac
TEXTO="$(_fzf_texto "$CORES" "$(_fzf_laranja)")"

if [ "$ACAO" = "conferir" ]; then
  if [ -f "$FZF_ALVO" ] && [ "$TEXTO" = "$(cat "$FZF_ALVO" 2>/dev/null)" ]; then
    meow_ok "cores do fzf conferem com $_FLAVOR ($FZF_ALVO)"
    exit "$MEOW_OK"
  fi
  meow_muda "escreveria as cores do fzf a partir da paleta ($_FLAVOR, acento $_ACCENT) em $FZF_ALVO"
  exit "$MEOW_DIVERGENTE"
fi

meow_escrever "$FZF_ALVO" "$TEXTO" 644; rc=$?
case "$rc" in
  0) meow_ok "cores do fzf já são as de $_FLAVOR ($FZF_ALVO)"
     exit "$MEOW_OK" ;;
  1) if meow_seco; then
       meow_muda "escreveria as cores do fzf a partir da paleta ($_FLAVOR, acento $_ACCENT)"
     else
       meow_ok "cores do fzf de $_FLAVOR escritas em $FZF_ALVO"
       meow_info "valem no próximo terminal (o bloco do MeowSystem carrega o arquivo)"
     fi
     exit "$MEOW_DIVERGENTE" ;;
  *) meow_erro "não consegui escrever $FZF_ALVO"
     exit "$MEOW_ERRO" ;;
esac

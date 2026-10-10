#!/usr/bin/env bash
# fzf.sh — as cores do fzf saem da paleta do pack no ar, e não de um hex cravado.
#
# POR QUE ESTA ETAPA NASCEU EM 24/09/2026 (P44)
#   A regra de 23/09 é "tema é do MeowSystem; máquina é do Spellbook", e as
#   cores do fzf eram tema morando do lado errado. Medido no dia, no `env.zsh`
#   do Spellbook: DUAS paletas cravadas, e nenhuma delas a do pack no ar —
#
#     FZF_DEFAULT_OPTS             Catppuccin Mocha (#45475A, #CBA6F7, …)
#     zstyle ':fzf-tab:*' fzf-flags Dracula          (#44475a, #bd93f9, …)
#
#   com `FLAVOR="dracula"` no meow.conf. O Ctrl+R saía Catppuccin e o TAB saía
#   Dracula, no mesmo terminal. Trocar de pack não mudava nenhum dos dois.
#
# O MAPA É O QUE AS DUAS LINHAS JÁ FAZIAM, lido como PAPEL da paleta
#   As duas linhas cravadas eram a mesma receita em dois packs, e a receita
#   se escreve em slots da `paleta.json` (os 26 nomes que todo pack tem):
#
#     bg+     surface1     a linha selecionada
#     fg+     text
#     hl      ACCENT       o trecho que casou com a busca (mauve, de fábrica)
#     hl+     pink         o mesmo, na linha selecionada
#     pointer green        e marker, o marcador de seleção
#     prompt  ACCENT
#     header  overlay0     e border
#
#   Conferido slot a slot em 24/09/2026: com `FLAVOR="mocha"` e o acento
#   mauve, sai BYTE A BYTE o `FZF_DEFAULT_OPTS` que estava no `env.zsh`; com
#   `FLAVOR="dracula"`, sai o `fzf-flags` do fzf-tab (a menos da caixa das
#   letras, que o fzf ignora). Nenhuma cor nova foi inventada — só deixaram de
#   ser duas.
#
# O CAMINHO É O DO STARSHIP, E ESTA É A MEDIÇÃO QUE O DECIDIU
#   O prompt já resolve a mesma pergunta: o MeowSystem escreve a config
#   (`~/.config/starship.toml`, `scripts/prompt.sh`) e a linha que a LIGA mora
#   no arquivo de inicialização do shell de quem usa. O starship lê o arquivo
#   dele sozinho; o fzf 0.44 desta máquina (o do apt do noble) não lê arquivo
#   nenhum — o `FZF_DEFAULT_OPTS_FILE` só existe em fzf mais novo. Então o que
#   o MeowSystem escreve é um trecho de shell, `~/.config/meowsystem/fzf.sh`,
#   que exporta o `FZF_DEFAULT_OPTS`; a linha que o carrega é de quem usa, e
#   este script só a DIZ (`mostrar`, e no `aplicar` quando escreve). Trocar de
#   pack reescreve o arquivo, e todo shell novo já nasce com as cores novas.
#
#   O ARQUIVO DEFINE a variável, como a linha que ele substitui definia — não
#   acrescenta. Um "acrescentar" dobraria as opções a cada shell aninhado
#   (a variável é exportada e o arquivo é lido de novo). Quem quiser outras
#   opções do fzf põe DEPOIS da linha que o carrega:
#       export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --layout=reverse"
#
#   O fzf-tab NÃO LÊ o `FZF_DEFAULT_OPTS` por padrão (é o README dele que
#   diz): o `zstyle ':fzf-tab:*' use-fzf-default-opts yes` é o que o faz
#   seguir as mesmas cores. Também é linha do shell de quem usa.
#
# O FLAVOR É O DO meow.conf, e não o do modo claro/escuro da hora: a variável
#   nasce uma vez por shell e não acompanha a troca do tema no meio da sessão.
#   É o mesmo que a linha cravada fazia — ela era escura sempre.
#
# E O LARANJA DOS RÓTULOS DO TERMINAL — 24/09/2026 (P47)
#   A P44 deixou anotado um terceiro cravado no `env.zsh` do Spellbook: o
#   `sed` que traduz os rótulos do fastfetch na abertura do terminal
#   (`[Discrete]` vira `(Dedicada)`, `[AC Connected]` vira `(Conectado)`…) os
#   pinta com `\e[38;2;255;184;108m`, sete vezes — o laranja do Dracula, com
#   qualquer pack no ar. É tema, e sai pelo mesmo arquivo: ele passa a exportar
#   também `MEOW_SGR_LARANJA`, o slot `peach` da paleta (o laranja dos dois
#   packs) já no formato de cor de 24 bits do terminal, e a linha de lá o usa.
#   Sem o slot — uma paleta que não o tenha —, a variável não nasce e os
#   rótulos saem sem cor: inventar um laranja aqui seria o cravado de volta.
#   Ele não é do fzf; mora aqui porque é a mesma pergunta ("que cor o shell usa
#   para este papel?") e o mesmo arquivo que o shell já lê.
#
# USO
#   fzf.sh aplicar    escreve ~/.config/meowsystem/fzf.sh (idempotente)
#   fzf.sh conferir   0 = conforme · 1 = divergente · 3 = a paleta não tem o flavor
#   fzf.sh mostrar    imprime a linha que carrega o arquivo no shell
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 = certo · 1 = divergente (ou escrevi) · 2 = erro · 3 = falta dependência
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

FZF_ALVO="${FZF_ALVO:-${XDG_CONFIG_HOME:-$HOME/.config}/meowsystem/fzf.sh}"
# Vazio, vale o flavor padrão do pack no ar: o `meow_flavor` (lib/comum.sh).
# Era `${FLAVOR:-mocha}`, o padrão de um pack só (P61, 25/09/2026).
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
# O `conferir` é o seco visto de fora, e o `MEOW_DRY_RUN=1 fzf.sh` dos `chk_`
# vira conferência — nunca uma escrita.
# shellcheck disable=SC2034  # quem lê MEOW_SECO é o meow_seco() do comum.sh
[ "$ACAO" = "conferir" ] && MEOW_SECO=1

# A linha do shell, escrita uma vez só: o `mostrar` e o `aplicar` a dizem pelo
# mesmo texto, para o que a tela promete e o que se cola nunca divergirem. O
# `$HOME` fica literal de propósito — é a linha que vai para o shell dela.
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

# --- as cores, da paleta -----------------------------------------------------
# A paleta vem da porta única (`meow_paleta`, lib/comum.sh): o pack no ar, ou o
# padrão. Um slot que falte é ERRO e não um hex de reserva — uma cor inventada
# aqui seria exatamente o cravado que esta etapa veio tirar.
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
    sys.exit(3)          # quem diz isto na tela é o shell, com o nome da paleta
# O papel de cada chave do fzf: ver o mapa no cabeçalho.
mapa = [("bg+", "surface1"), ("fg+", "text"), ("hl", acento), ("hl+", "pink"),
        ("pointer", "green"), ("marker", "green"), ("prompt", acento),
        ("header", "overlay0"), ("border", "overlay0")]
partes = []
for chave, slot in mapa:
    v = cores.get(slot)
    if not (isinstance(v, str) and v.startswith("#")):
        if slot == acento:
            sys.exit(3)  # ACCENT que a paleta não tem: escolha no conf, não defeito
        print("falta o slot '%s' no flavor '%s'" % (slot, flavor), file=sys.stderr)
        sys.exit(2)
    partes.append("%s:%s" % (chave, v))
print("--color=" + ",".join(partes))
PY
}

# O laranja (slot `peach`) como o terminal o pede: `38;2;R;G;B`. Vazio quando a
# paleta não tem o slot — ver "E O LARANJA DOS RÓTULOS", no cabeçalho.
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

_fzf_texto() {   # $1 = as opções de cor · $2 = o laranja em SGR (pode ser vazio)
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

# --- aplicar -------------------------------------------------------------------
meow_escrever "$FZF_ALVO" "$TEXTO" 644; rc=$?
case "$rc" in
  0) meow_ok "cores do fzf já são as de $_FLAVOR ($FZF_ALVO)"
     exit "$MEOW_OK" ;;
  1) if meow_seco; then
       meow_muda "escreveria as cores do fzf a partir da paleta ($_FLAVOR, acento $_ACCENT)"
     else
       meow_ok "cores do fzf de $_FLAVOR escritas em $FZF_ALVO"
       meow_info "valem em todo shell que carregar o arquivo — a linha, se ainda não estiver no seu:"
       meow_info "  $(_fzf_linha)"
     fi
     exit "$MEOW_DIVERGENTE" ;;
  *) meow_erro "não consegui escrever $FZF_ALVO"
     exit "$MEOW_ERRO" ;;
esac

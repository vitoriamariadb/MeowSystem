#!/usr/bin/env bash
# exportar_tema.sh — o tema de ícones MONTADO de um pack, num arquivo que se
# instala em qualquer máquina (P74 item 4, 09/10/2026; T7 da paridade).
#
#   scripts/exportar_tema.sh <id> [flavor] [arquivo.tar.gz]
#   meow pack exportar-tema <id> [flavor] [arquivo.tar.gz]
#
# O BURACO, MEDIDO
#   O `meow pack exportar` leva a RECEITA (o pack: mapas, desenhos, paleta), e
#   não o tema montado: o `.meowpack` do Dracula tinha 0 `index.theme`. Quem
#   recebia precisava do MeowSystem inteiro para ver um ícone. E o tema montado
#   se chamava `MeowSystem-Icons` em qualquer pack, com `Comment=Catppuccin`
#   (docs/pesquisas/2026-10-09-paridade-de-icones.md, seção 5).
#
# O QUE SAI
#   Um `.tar.gz` com três pastas de tema, prontas para `~/.local/share/icons/`:
#     <nome>          o tema, com o nome do pack e do flavor (`MeowSystem-
#                     Dracula-Icons`; o `tema-icones` do pack.py dá o nome e o
#                     `Comment=`), herdando SÓ do que vai junto e do `hicolor`;
#     <nome>-Base     a base que o pack traz (a frente), e
#     <nome>-Base-<n> as camadas de trás dela, quando o pack as declara.
#   Os recibos de instalação (`.meow-origem`, `.meow-somas.sha256`) e a cache
#   não vão: são desta máquina, e quem instala refaz a cache.
#
# ONDE ELE É MONTADO: NUMA CASA DE BRINQUEDO, DO ZERO
#   As etapas de ícone do `install.sh` rodam num HOME temporário, com o
#   `meow.conf.exemplo` (o pack e o flavor pedidos, o resto de fábrica). Assim
#   o tema exportado é o do PACK, e não o desta casa: nenhuma escolha do
#   meow.conf de quem exporta (a logo do Hefesto, um ICONES_BASE à mão) viaja
#   sem querer. As etapas são as que escrevem no tema e não pedem root nem
#   sessão — as mesmas linhas de ambiente do `install.sh`, na mesma ordem, e o
#   `indice` no fim (P74 item 5). Uma base que esta máquina já tem, conferida
#   pelo sha256 do pino, é copiada para a casa de brinquedo em vez de baixada
#   de novo; o `construir_icones.sh` confere o manifesto dela do mesmo jeito.
#
#   0 = exportado · 1 = no seco, exportaria · 2 = erro (nada é deixado pela metade)
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ID="${1:-}"
[ -n "$ID" ] || { meow_erro "uso: exportar_tema.sh <id> [flavor] [arquivo.tar.gz]"; exit "$MEOW_ERRO"; }
# O id e o flavor entram num meow.conf que a casa de brinquedo carrega com `.`
# (o `sed` lá embaixo): só da forma que o pack.py aceita (RE_ID e
# RE_FLAVOR_CONF), para uma aspa ou um `$(` não virar código ao carregar.
# [Conferência da P74, alerta de segurança de 09/10/2026.]
case "$ID" in ''|-*|*[!a-z0-9-]*) meow_erro "'$ID' não é um id de pack (minúsculas, dígitos e hífen)"; exit "$MEOW_ERRO" ;; esac
if ! python3 "$RAIZ/scripts/pack.py" validar "$ID" >/dev/null 2>&1; then
  meow_erro "o pack '$ID' não valida — rode: meow pack validar $ID"
  exit "$MEOW_ERRO"
fi
FLAVOR_PEDIDO="${2:-}"
[ -n "$FLAVOR_PEDIDO" ] || FLAVOR_PEDIDO="$(python3 -I - "$RAIZ/scripts" "$ID" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import pack
print(pack.campo(sys.argv[2], "paleta.flavor_padrao", "") or "")
PY
)"
# O flavor pela mesma régua, e depois de resolvido: o padrão vem do pack.json,
# e um pack importado é dado não confiável.
case "$FLAVOR_PEDIDO" in *[!a-z0-9_]*) meow_erro "'$FLAVOR_PEDIDO' não é um nome de flavor (minúsculas, dígitos e '_')"; exit "$MEOW_ERRO" ;; esac
saida_nome="$(python3 "$RAIZ/scripts/pack.py" tema-icones "$ID" "$FLAVOR_PEDIDO")" || exit "$MEOW_ERRO"
NOME="$(printf '%s\n' "$saida_nome" | sed -n 's/^nome=//p')"
[ -n "$NOME" ] || { meow_erro "o pack.py não deu nome ao tema de '$ID'"; exit "$MEOW_ERRO"; }
DESTINO="${3:-$PWD/$NOME.tar.gz}"
case "$DESTINO" in /*) ;; *) DESTINO="$PWD/$DESTINO" ;; esac

if meow_seco; then
  meow_muda "montaria o tema '$NOME' ($ID, $FLAVOR_PEDIDO) numa casa temporária e o gravaria em $DESTINO"
  exit "$MEOW_DIVERGENTE"
fi
[ -d "$(dirname "$DESTINO")" ] || { meow_erro "a pasta de $DESTINO não existe"; exit "$MEOW_ERRO"; }

CASA="$(mktemp -d "${TMPDIR:-/tmp}/meow-exportar-tema.XXXXXX")" || exit "$MEOW_ERRO"
trap 'rm -rf "$CASA"' EXIT
ICONES="$CASA/.local/share/icons"
mkdir -p "$CASA/.config/meow" "$ICONES" || exit "$MEOW_ERRO"
CONF="$CASA/.config/meow/meow.conf"
# O conf de fábrica com o pack, o flavor e o nome do tema pedidos. O
# `ICONES_BASE` sai: o de fábrica cede à base do pack de qualquer jeito, e a
# linha a menos impede um valor antigo do exemplo de decidir a herança.
sed -e "s/^PACK=.*/PACK=\"$ID\"/" -e "s/^FLAVOR=.*/FLAVOR=\"$FLAVOR_PEDIDO\"/" \
    -e "s/^NOME_TEMA_ICONES=.*/NOME_TEMA_ICONES=\"$NOME\"/" \
    -e '/^ICONES_BASE=/d' "$RAIZ/meow.conf.exemplo" > "$CONF" || exit "$MEOW_ERRO"

# As bases que esta máquina já tem, pelo sha256 do pino — e só elas.
_semear_bases() {
  local saida linhas n=1 sha d alvo
  saida="$(ICONES_BASE= NOME_TEMA_ICONES="$NOME" python3 "$RAIZ/scripts/pack.py" base-icones "$ID")" || return 0
  linhas="$(printf '%s\n' "$saida" | sed -n 's/^sha256=//p')"
  while IFS=$'\t' read -r _url sha _pasta; do linhas="$linhas"$'\n'"$sha"; done \
    < <(printf '%s\n' "$saida" | sed -n 's/^atras=//p')
  while IFS= read -r sha; do
    [ -n "$sha" ] || continue
    alvo="$ICONES/$NOME-Base"; [ "$n" -gt 1 ] && alvo="$ICONES/$NOME-Base-$n"
    for d in "$HOME/.local/share/icons"/*; do
      [ -f "$d/.meow-origem" ] && grep -qx "sha256=$sha" "$d/.meow-origem" || continue
      cp -a "$d" "$alvo" 2>/dev/null && break
    done
    n=$((n + 1))
  done <<< "$linhas"
}
_semear_bases

# etapa <rótulo> <linha de shell> — numa casa só dela, com o conf de lá
# carregado como o `install.sh` o carrega (`set -a`), e a ponte do pack de pé.
# A linha é a mesma do `etapa_*` do `install.sh` que tem esse nome.
pulados=()
etapa() {
  local rotulo="$1" linha="$2"
  env -i PATH="$PATH" HOME="$CASA" LANG="${LANG:-C.UTF-8}" TERM="${TERM:-dumb}" NO_COLOR=1 \
    XDG_CONFIG_HOME="$CASA/.config" XDG_DATA_HOME="$CASA/.local/share" \
    XDG_STATE_HOME="$CASA/.local/state" XDG_CACHE_HOME="$CASA/.cache" \
    MEOW_RAIZ="$RAIZ" MEOW_CONF="$CONF" MEOW_COSMIC_DIR="$CASA/.config/cosmic" \
    MEOW_ESTADO="$CASA/.local/state/meowsystem" \
    bash -c 'set -a; . "$MEOW_CONF"; set +a; . "$MEOW_RAIZ/lib/comum.sh"
             meow_ponte_python || exit 2; eval "$1"' _ "$linha" \
    > "$CASA/log-$rotulo.txt" 2>&1
  local rc=$?
  case "$rc" in
    0|1) ;;
    3) pulados+=("$rotulo") ;;
    *) meow_erro "a etapa '$rotulo' falhou montando o tema — nada foi exportado"
       sed 's/^/    /' "$CASA/log-$rotulo.txt" | tail -8 >&2
       exit "$MEOW_ERRO" ;;
  esac
}

meow_info "montando o tema '$NOME' do pack $ID ($FLAVOR_PEDIDO)…"
etapa icones     'FLAVOR="$FLAVOR" LOGO="$LOGO" ICONES_BASE="${ICONES_BASE:-}" "$MEOW_RAIZ/scripts/construir_icones.sh"'
etapa pastas_xdg 'PASTAS_XDG="${PASTAS_XDG:-nao}" ICONES_FLAVOR="${ICONES_FLAVOR:-}" ICONES_TEMA="$NOME_TEMA_ICONES" "$MEOW_RAIZ/scripts/icones_pastas.sh"'
etapa pastas     'ICONES_PASTAS="${ICONES_PASTAS:-cat-${FLAVOR}-${ACCENT}}" "$MEOW_RAIZ/scripts/construir_pastas.sh"'
etapa completar  'FLAVOR="$FLAVOR" ACCENT="$ACCENT" "$MEOW_RAIZ/scripts/completar_icones.sh"'
etapa mimetypes  'ICONES_FLAVOR="${ICONES_FLAVOR:-}" ICONES_TEMA="$NOME_TEMA_ICONES" "$MEOW_RAIZ/scripts/icones_mimetypes.sh"'
etapa apps       'ICONES_FLAVOR="${ICONES_FLAVOR:-}" ICONES_TEMA="$NOME_TEMA_ICONES" "$MEOW_RAIZ/scripts/icones_apps.sh"'
etapa resgatados 'ICONES_RESGATADOS="${ICONES_RESGATADOS:-sim}" "$MEOW_RAIZ/scripts/icones_resgatados.sh" --aplicar'
etapa arcticons  'FLAVOR="${FLAVOR:-}" ICONES_COR_MARCA="${ICONES_COR_MARCA:-nao}" ICONES_TEMA="$NOME_TEMA_ICONES" "$MEOW_RAIZ/scripts/icones_apps_arcticons.sh"'
etapa dracula    'ICONES_DRACULA="${ICONES_DRACULA:-sim}" "$MEOW_RAIZ/scripts/icones_apps_dracula.sh" --aplicar'
etapa sistema    'ICONES_TEMA="$NOME_TEMA_ICONES" "$MEOW_RAIZ/scripts/icones_sistema.sh"'
etapa bandeja    'ICONES_TEMA="$NOME_TEMA_ICONES" "$MEOW_RAIZ/scripts/icones_bandeja.sh"'
etapa indice     '"$MEOW_RAIZ/scripts/construir_icones.sh" indice'

TEMA="$ICONES/$NOME"
[ -f "$TEMA/index.theme" ] || { meow_erro "o tema '$NOME' não saiu montado — nada foi exportado"; exit "$MEOW_ERRO"; }

# --- o que vai junto, e a herança que só aponta para ele --------------------
#   O nosso herda as camadas da base que estão na casa (na ordem do índice) e o
#   `hicolor`; cada base herda só o `hicolor` — o `Inherits=` do upstream
#   (`-Dark,breeze-dark,Zafiro,…`) aponta para temas que não viajam.
camadas=()
for h in $(sed -n 's/^Inherits=//p' "$TEMA/index.theme" | head -1 | tr ',' ' '); do
  case "$h" in "$NOME"-Base|"$NOME"-Base-[0-9]*) [ -d "$ICONES/$h" ] && camadas+=("$h") ;; esac
done
_herdar() {   # $1 = index.theme · $2 = a nova lista
  local tmp; tmp="$(mktemp -p "$(dirname "$1")" .meow.XXXXXX)" || return 1
  awk -v h="$2" 'BEGIN{feito=0} /^Inherits=/ && !feito {print "Inherits=" h; feito=1; next} {print}' "$1" > "$tmp" \
    && mv -f "$tmp" "$1"
}
herda="$(printf '%s,' "${camadas[@]}")hicolor"
_herdar "$TEMA/index.theme" "$herda" || exit "$MEOW_ERRO"
for c in "${camadas[@]}"; do
  _herdar "$ICONES/$c/index.theme" "hicolor" || exit "$MEOW_ERRO"
  rm -f "$ICONES/$c/.meow-origem" "$ICONES/$c/.meow-somas.sha256"
done
find "$TEMA" "${camadas[@]/#/$ICONES/}" -maxdepth 1 -name icon-theme.cache -delete 2>/dev/null

# --- nenhum link para fora do que vai no arquivo ------------------------------
fora="$(cd "$ICONES" && find "$NOME" "${camadas[@]}" -type l -print0 \
        | xargs -0 -r realpath -m -- 2>/dev/null | grep -v "^$(realpath -m "$ICONES")/" || true)"
if [ -n "$fora" ]; then
  meow_erro "o tema montado tem link apontando para fora dele — nada foi exportado"
  printf '%s\n' "$fora" | head -3 | sed 's/^/    /' >&2
  exit "$MEOW_ERRO"
fi

tmp_dest="$(mktemp -p "$(dirname "$DESTINO")" ".meow-tema.XXXXXX")" || exit "$MEOW_ERRO"
if ! tar -czf "$tmp_dest" -C "$ICONES" "$NOME" "${camadas[@]}"; then
  rm -f "$tmp_dest"; meow_erro "não consegui gravar $DESTINO"; exit "$MEOW_ERRO"
fi
chmod 644 "$tmp_dest" && mv -f "$tmp_dest" "$DESTINO" || { rm -f "$tmp_dest"; exit "$MEOW_ERRO"; }

n_apps="$(find "$TEMA/scalable/apps" -maxdepth 1 \( -name '*.svg' -o -name '*.png' \) 2>/dev/null | wc -l)"
meow_ok "tema '$NOME' exportado em $DESTINO"
meow_info "  $n_apps ícones de aplicativo em scalable/apps; herda de ${herda//,/, }"
[ "${#pulados[@]}" -gt 0 ] && meow_info "  saíram sem dependência (código 3): ${pulados[*]}"
meow_info "  para instalar: tar -xzf '$(basename "$DESTINO")' -C ~/.local/share/icons && gtk-update-icon-cache -f ~/.local/share/icons/$NOME"
exit "$MEOW_OK"

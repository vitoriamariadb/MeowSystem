#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/icones.sh
. "$RAIZ/lib/icones.sh"

ID="${1:-}"
[ -n "$ID" ] || { meow_erro "uso: exportar_tema.sh <id> [flavor] [arquivo.tar.gz]"; exit "$MEOW_ERRO"; }
case "$ID" in ''|-*|*[!a-z0-9-]*) meow_erro "'$ID' não é um id de pack (minúsculas, dígitos e hífen)"; exit "$MEOW_ERRO" ;; esac
if ! python3 "$RAIZ/scripts/pack.py" validar "$ID" >/dev/null 2>&1; then
  meow_erro "o pack '$ID' não valida — nada foi exportado"
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
sed -e "s/^PACK=.*/PACK=\"$ID\"/" -e "s/^FLAVOR=.*/FLAVOR=\"$FLAVOR_PEDIDO\"/" \
    -e "s/^NOME_TEMA_ICONES=.*/NOME_TEMA_ICONES=\"$NOME\"/" \
    -e '/^ICONES_BASE=/d' "$RAIZ/meow.conf.exemplo" > "$CONF" || exit "$MEOW_ERRO"

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
etapa resgatados 'ICONES_RESGATADOS="${ICONES_RESGATADOS:-sim}" "$MEOW_RAIZ/scripts/icones_resgatados.sh" --aplicar'
etapa arcticons  'FLAVOR="${FLAVOR:-}" ICONES_COR_MARCA="${ICONES_COR_MARCA:-nao}" ICONES_TEMA="$NOME_TEMA_ICONES" "$MEOW_RAIZ/scripts/icones_apps_arcticons.sh"'
etapa dracula    'ICONES_DRACULA="${ICONES_DRACULA:-sim}" "$MEOW_RAIZ/scripts/icones_apps_dracula.sh" --aplicar'
etapa sistema    'ICONES_TEMA="$NOME_TEMA_ICONES" "$MEOW_RAIZ/scripts/icones_sistema.sh"'
etapa bandeja    'ICONES_TEMA="$NOME_TEMA_ICONES" "$MEOW_RAIZ/scripts/icones_bandeja.sh"'
etapa indice     '"$MEOW_RAIZ/scripts/construir_icones.sh" indice'

TEMA="$ICONES/$NOME"
[ -f "$TEMA/index.theme" ] || { meow_erro "o tema '$NOME' não saiu montado — nada foi exportado"; exit "$MEOW_ERRO"; }

_camadas="$(meow_tema_exportado_heranca "$ICONES" "$NOME")" || exit "$MEOW_ERRO"
camadas=()
[ -n "$_camadas" ] && mapfile -t camadas <<< "$_camadas"
find "$TEMA" "${camadas[@]/#/$ICONES/}" -maxdepth 1 -name icon-theme.cache -delete 2>/dev/null

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

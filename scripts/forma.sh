#!/usr/bin/env bash
_forma_teto_raio() {
  local t
  t="$(meow_painel_teto "$BASE/com.system76.CosmicPanel.$1/$(meow_cosmic_v "com.system76.CosmicPanel.$1")" 2>/dev/null)" && { printf '%s' "$t"; return 0; }
  printf '0'
}

FORMA_COMP_BIN="${FORMA_COMP_BIN:-}"
MEOW_PAINEL_COMP_BIN="$FORMA_COMP_BIN"
_forma_compositor_clampa() {
  meow_painel_compositor_clampa && return 0
  meow_painel_patch_pendente && return 2
  return 1
}


_forma_conferir_raio_do_disco() {
  local barra="$1" dir="$2" atual teto chave rc
  atual="$(cat "$dir/border_radius" 2>/dev/null || true)"
  case "$atual" in ''|*[!0-9]*) return 0 ;; esac

  _forma_compositor_clampa; local comp=$?
  if [ "$comp" = "0" ]; then
    meow_debug "$barra: raio $atual é seu — o cosmic-comp clampa o que não couber"
    return 0
  fi

  teto="$(_forma_teto_raio "$barra")"

  if [ "$comp" = "2" ] && [ "$atual" -gt "$teto" ]; then
    meow_aviso "$barra: raio $atual — o patch do cosmic-comp já está instalado, mas vale no PRÓXIMO LOGIN"
    meow_info  "  até lá esta sessão roda o compositor antigo; se a barra sumir, é isto"
    return 0
  fi
  if [ "$atual" -le "$teto" ]; then
    meow_debug "$barra: raio $atual é seu (cabe no teto de $teto)"
    return 0
  fi

  chave="FORMA_RAIO_PAINEL"; [ "$barra" = "Dock" ] && chave="FORMA_RAIO_DOCK"
  meow_aviso "$barra: raio $atual no disco, acima de $teto, e o cosmic-comp NÃO está patchado"
  meow_info  "  com este valor topbar e dock somem JUNTAS e não voltam — medido em 26/08/2026"
  meow_info  "  o patch some num 'apt upgrade' do cosmic-comp; refazer: meow compositor (~4 min, sudo no fim)"
  meow_info  "  para impor um valor daqui em vez disso: $chave no meow.conf"
  meow_escrever "$dir/border_radius" "$teto" 644; rc=$?
  case "$rc" in
    1) mudou=1 ;;
    2) meow_erro "não consegui escrever $dir/border_radius"; return 2 ;;
  esac
  return 0
}

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/painel.sh
. "$RAIZ/lib/painel.sh"

FORMA_PAINEL_SOLTO="${FORMA_PAINEL_SOLTO:-sim}"
FORMA_DOCK_SOLTO="${FORMA_DOCK_SOLTO:-sim}"

FORMA_PAINEL_ILHA="${FORMA_PAINEL_ILHA:-nao}"
FORMA_DOCK_ILHA="${FORMA_DOCK_ILHA:-nao}"

FORMA_MARGEM_PAINEL="${FORMA_MARGEM_PAINEL:-}"
FORMA_MARGEM_DOCK="${FORMA_MARGEM_DOCK:-}"
FORMA_RAIO_PAINEL="${FORMA_RAIO_PAINEL:-}"
FORMA_RAIO_DOCK="${FORMA_RAIO_DOCK:-}"

FORMA_ESPACO_PAINEL="${FORMA_ESPACO_PAINEL:-}"
FORMA_ESPACO_DOCK="${FORMA_ESPACO_DOCK:-}"

FORMA_RECHEIO_PAINEL="${FORMA_RECHEIO_PAINEL:-}"
FORMA_RECHEIO_DOCK="${FORMA_RECHEIO_DOCK:-}"

FORMA_CENTRO_PAINEL="${FORMA_CENTRO_PAINEL:-}"
FORMA_CENTRO_DOCK="${FORMA_CENTRO_DOCK:-}"
FORMA_ALA_INICIAL_PAINEL="${FORMA_ALA_INICIAL_PAINEL:-}"
FORMA_ALA_FINAL_PAINEL="${FORMA_ALA_FINAL_PAINEL:-}"
FORMA_ALA_INICIAL_DOCK="${FORMA_ALA_INICIAL_DOCK:-}"
FORMA_ALA_FINAL_DOCK="${FORMA_ALA_FINAL_DOCK:-}"

BASE="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}"

_forma_veio_do_ambiente=0
for _n in $(compgen -e); do
  case "$_n" in FORMA_*) _forma_veio_do_ambiente=1; break ;; esac
done
if [ "$_forma_veio_do_ambiente" = "0" ] &&
   grep -qE '^[[:space:]]*(export[[:space:]]+)?FORMA_' "$MEOW_CONF_ARQUIVO" 2>/dev/null; then
  meow_aviso "o $MEOW_CONF_ARQUIVO tem geometria e nada dela chegou aqui — vou gravar os padrões DESTE arquivo por cima"
  meow_info "quem lê o conf é 'meow doctor --consertar' (ou o ./install.sh); rodar este script na mão desfaz a sua escolha"
fi

_bool() { case "$1" in sim|true|1) printf 'true' ;; nao|não|false|0) printf 'false' ;;
                       *) return 1 ;; esac; }
_int()  { case "$2" in ''|*[!0-9]*) meow_erro "$1='$2' — esperado um inteiro"; return 1 ;;
                       *) printf '%s' "$2" ;; esac; }

mudou=0
escritos=0

aplicar_barra() {
  local barra="$1" dir solto ilha expandir margem raio espaco recheio rc
  dir="$BASE/com.system76.CosmicPanel.$barra/$(meow_cosmic_v "com.system76.CosmicPanel.$barra")"
  [ -d "$dir" ] || { meow_pula "com.system76.CosmicPanel.$barra não está configurado aqui"; return 0; }

  solto="$(_bool "$2")"   || { meow_erro "$barra: 'solto' esperava sim|nao, veio '$2'"; return 2; }
  ilha="$(_bool "$3")"    || { meow_erro "$barra: 'ilha' esperava sim|nao, veio '$3'"; return 2; }
  margem="$4"; raio="$5"; espaco="$6"; recheio="$7"
  [ -z "$margem" ]  || { margem="$(_int  "margem do $barra"  "$margem")"  || return 2; }
  [ -z "$espaco" ]  || { espaco="$(_int  "espaço do $barra"  "$espaco")"  || return 2; }
  [ -z "$recheio" ] || { recheio="$(_int "recheio do $barra" "$recheio")" || return 2; }

  if [ -z "$raio" ]; then
    _forma_conferir_raio_do_disco "$barra" "$dir" || return 2
  else
    raio="$(_int "raio do $barra" "$raio")" || return 2
    local teto; teto="$(_forma_teto_raio "$barra")"
    if [ "$raio" -gt "$teto" ] && _forma_compositor_clampa; then
      meow_info "$barra: raio $raio acima de $teto, mas o cosmic-comp clampa — seguindo"
    elif [ "$raio" -gt "$teto" ]; then
      local chave; chave="FORMA_RAIO_PAINEL"; [ "$barra" = "Dock" ] && chave="FORMA_RAIO_DOCK"
      case "${FORMA_RAIO_EXPERIMENTAL:-nao}" in
        sim|true|1)
          meow_aviso "$barra: raio $raio acima do valor com evidência ($teto) — modo experimental, seguindo"
          meow_info  "  se topbar e dock sumirem JUNTAS, é isto: $chave=\"$teto\" e 'meow forma' devolve"
          ;;
        *)
          meow_aviso "$barra: raio $raio acima de $teto, o único valor com dias de uso atrás"
          meow_info  "  não há teto calculável: o cosmic-comp compara o raio NOVO com a caixa do frame ANTERIOR"
          meow_info  "  (corner_radius.rs:657-698) e mata o cliente — topbar e dock somem JUNTAS"
          meow_info  "  o conserto de raiz é o patch: meow compositor (~4 min, sudo no fim)"
          meow_info  "  para tentar acima disso sem o patch: FORMA_RAIO_EXPERIMENTAL=sim"
          raio="$teto"
          ;;
      esac
    fi
  fi

  case "$ilha" in true) expandir=false ;; *) expandir=true ;; esac

  escritos=$((escritos + 1))
  local par k v
  for par in "anchor_gap:$solto" "margin:$margem" "border_radius:$raio" \
             "spacing:$espaco" "padding:$recheio" "expand_to_edges:$expandir"; do
    k="${par%%:*}"; v="${par#*:}"
    [ -n "$v" ] || continue
    meow_escrever "$dir/$k" "$v" 644; rc=$?
    case "$rc" in
      1) mudou=1 ;;
      2) meow_erro "não consegui escrever $dir/$k"; return 2 ;;
    esac
  done
  return 0
}

_tam() { case "$2" in XS|S|M|L|XL) printf '%s' "$2" ;;
                      *) meow_erro "$1='$2' — esperado XS, S, M, L ou XL (ou vazio)"; return 1 ;;
         esac; }

aplicar_tamanhos() {
  local barra="$1" centro="$2" ini="$3" fim="$4" dir rc v_ini v_fim
  dir="$BASE/com.system76.CosmicPanel.$barra/$(meow_cosmic_v "com.system76.CosmicPanel.$barra")"
  [ -d "$dir" ] || return 0

  if [ -n "$centro" ]; then
    centro="$(_tam "centro do $barra" "$centro")" || return 2
    meow_escrever "$dir/size_center" "Some($centro)" 644; rc=$?
    case "$rc" in 1) mudou=1 ;; 2) meow_erro "não consegui escrever $dir/size_center"; return 2 ;; esac
  fi

  [ -z "$ini$fim" ] && return 0
  v_ini=None; v_fim=None
  if [ -n "$ini" ]; then ini="$(_tam "ala inicial do $barra" "$ini")" || return 2; v_ini="Some($ini)"; fi
  if [ -n "$fim" ]; then fim="$(_tam "ala final do $barra"   "$fim")" || return 2; v_fim="Some($fim)"; fi
  meow_escrever "$dir/size_wings" "Some(($v_ini, $v_fim))" 644; rc=$?
  case "$rc" in 1) mudou=1 ;; 2) meow_erro "não consegui escrever $dir/size_wings"; return 2 ;; esac
  return 0
}

aplicar_barra Panel "$FORMA_PAINEL_SOLTO" "$FORMA_PAINEL_ILHA" \
  "$FORMA_MARGEM_PAINEL" "$FORMA_RAIO_PAINEL" "$FORMA_ESPACO_PAINEL" "$FORMA_RECHEIO_PAINEL" \
  || exit "$MEOW_ERRO"
aplicar_barra Dock "$FORMA_DOCK_SOLTO" "$FORMA_DOCK_ILHA" \
  "$FORMA_MARGEM_DOCK" "$FORMA_RAIO_DOCK" "$FORMA_ESPACO_DOCK" "$FORMA_RECHEIO_DOCK" \
  || exit "$MEOW_ERRO"

aplicar_tamanhos Panel "$FORMA_CENTRO_PAINEL" "$FORMA_ALA_INICIAL_PAINEL" "$FORMA_ALA_FINAL_PAINEL" \
  || exit "$MEOW_ERRO"
aplicar_tamanhos Dock  "$FORMA_CENTRO_DOCK"   "$FORMA_ALA_INICIAL_DOCK"   "$FORMA_ALA_FINAL_DOCK" \
  || exit "$MEOW_ERRO"

if [ "$escritos" -eq 0 ]; then
  meow_pula "não há painel nem dock configurados — nada a ajustar"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

for barra in Panel Dock; do
  arq="$BASE/com.system76.CosmicPanel.$barra/$(meow_cosmic_v "com.system76.CosmicPanel.$barra")/keep_style_on_maximize"
  [ -f "$arq" ] || continue
  [ "$(cat "$arq")" = "true" ] && continue
  meow_aviso "keep_style_on_maximize=false no $barra: a forma se desfaz ao maximizar"
  meow_info "com «Manter o vidro com janela maximizada» em sim, o vidro fica"
done

_forma_raio_dito() {
  local disco
  [ -n "$2" ] && { printf 'raio %s' "$2"; return 0; }
  disco="$(cat "$BASE/com.system76.CosmicPanel.$1/$(meow_cosmic_v "com.system76.CosmicPanel.$1")/border_radius" 2>/dev/null || true)"
  case "$disco" in
    ''|*[!0-9]*) printf 'raio da GUI' ;;
    *)           printf 'raio %s (seu)' "$disco" ;;
  esac
}

_forma_margem_dita() {
  local disco
  [ -n "$2" ] && { printf 'margem %s' "$2"; return 0; }
  disco="$(cat "$BASE/com.system76.CosmicPanel.$1/$(meow_cosmic_v "com.system76.CosmicPanel.$1")/margin" 2>/dev/null || true)"
  case "$disco" in
    ''|*[!0-9]*) printf 'margem da GUI' ;;
    *)           printf 'margem %s (sua)' "$disco" ;;
  esac
}

if [ "$mudou" = "0" ]; then
  meow_ok "forma já conforme: painel $(_forma_raio_dito Panel "$FORMA_RAIO_PAINEL") $(_forma_margem_dita Panel "$FORMA_MARGEM_PAINEL"), dock $(_forma_raio_dito Dock "$FORMA_RAIO_DOCK") $(_forma_margem_dita Dock "$FORMA_MARGEM_DOCK")"
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"
_forma_como() { case "$(_bool "$1")" in
                  true) printf 'em ilha com %s' "$2" ;;
                  *)    printf 'de largura cheia com %s' "$2" ;;
                esac; }
meow_ok "painel $(_forma_como "$FORMA_PAINEL_ILHA" "$(_forma_raio_dito Panel "$FORMA_RAIO_PAINEL")"), dock $(_forma_como "$FORMA_DOCK_ILHA" "$(_forma_raio_dito Dock "$FORMA_RAIO_DOCK")") — já valendo"
exit "$MEOW_DIVERGENTE"

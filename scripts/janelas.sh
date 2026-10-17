#!/usr/bin/env bash
# janelas.sh — o LADO A LADO automático (tiling) do cosmic-comp.
#
# nele inteiro dá zero linhas. O que existe é `layout = "dwindle"` no
# `.config/hypr/hyprland.lua:58` — dwindle é o LAYOUT (BSP), e a espiral é
# consequência da divisão ao meio, não de um efeito.
#
#      `TilingLayout::new_group` (src/shell/layout/tiling/mod.rs:2898, chamado em
#      :592) cria um grupo com `sizes: vec![metade; 2]`, e a orientação sai do
#      lado mais longo da janela FOCADA (:585-591):
#          if window_size.w > window_size.h { Vertical } else { Horizontal }
#      A janela nova entra sempre depois (:2929-2934), desenhada em baixo/à
#      direita (:3098-3118). Isso é exatamente `dwindle` + `force_split = 2` do
#      Hyprland. `force_split` não existe aqui e não faz falta.
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# VAZIO = NÃO TOCA, igual a RELOGIO_SEGUNDOS e VIDRO_OPACIDADE_*. O tiling tem
# atalho de teclado (Super+Y), então é comportamento que ela pode mudar sem
# passar por aqui — e o `conferir` avisa em vez de brigar calado.
JANELAS_TILING="${JANELAS_TILING:-}"
JANELAS_TILING_ESCOPO="${JANELAS_TILING_ESCOPO:-}"

JANELAS_BASE="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}/com.system76.CosmicComp/$(meow_cosmic_v com.system76.CosmicComp)"
JANELAS_ALVO_LIGADO="$JANELAS_BASE/autotile"
JANELAS_ALVO_ESCOPO="$JANELAS_BASE/autotile_behavior"
JANELAS_ALVO_PIN="$JANELAS_BASE/pinned_workspaces"
JANELAS_BINARIO="/usr/bin/cosmic-comp"

# O valor de antes da PRIMEIRA gravação nossa, para o `remover` devolver o que
# era dela e não o que nós inventamos.
JANELAS_ANTES="$MEOW_ESTADO/janelas"

_janelas_bool() {
  case "$1" in
    sim|true|1)      printf 'true' ;;
    nao|não|false|0) printf 'false' ;;
    *) return 1 ;;
  esac
}

# O RON aceita só estes dois nomes; qualquer outra coisa o cosmic-comp descarta
# calado e continua com o valor anterior — falha silenciosa, que é o pior tipo.
_janelas_escopo() {
  case "$1" in
    global|Global)                        printf 'Global' ;;
    workspace|por-workspace|PerWorkspace) printf 'PerWorkspace' ;;
    *) return 1 ;;
  esac
}

# 3 e não 1: sem cosmic-comp não há divergência, há ausência de assunto.
_janelas_dependencia() {
  if [ ! -x "$JANELAS_BINARIO" ] && [ ! -d "$JANELAS_BASE" ]; then
    meow_pula "cosmic-comp não encontrado — nada a fazer com o lado a lado"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

_janelas_no_disco() {
  [ -f "$1" ] && cat "$1" 2>/dev/null || printf ''
}

# --- o pinned_workspaces, que é quem manda no LOGIN -------------------------
# Formato: uma lista RON de entradas, cada uma com uma linha `tiling_enabled:`.

# Quantas entradas estão FORA do valor pedido. 0 = conforme; vazio = sem arquivo.
_janelas_pin_divergentes() {
  [ -f "$JANELAS_ALVO_PIN" ] || { printf ''; return 0; }
  local oposto; [ "$1" = "true" ] && oposto="false" || oposto="true"
  grep -c "tiling_enabled: $oposto," "$JANELAS_ALVO_PIN" 2>/dev/null || true
}

_janelas_pin_total() {
  [ -f "$JANELAS_ALVO_PIN" ] || { printf 0; return 0; }
  local n; n="$(grep -c 'tiling_enabled:' "$JANELAS_ALVO_PIN" 2>/dev/null || true)"
  printf '%s' "${n:-0}"
}

# Devolve 0 = já estava conforme · 1 = mudou (ou mudaria) · 2 = erro.
# Os mesmos códigos do `meow_escrever`, para o chamador não precisar traduzir.
_janelas_pin_escrever() {
  local valor="$1" oposto novo
  [ -f "$JANELAS_ALVO_PIN" ] || return "$MEOW_OK"   # sem alfinetado, sem assunto
  [ "$valor" = "true" ] && oposto="false" || oposto="true"
  grep -q "tiling_enabled: $oposto," "$JANELAS_ALVO_PIN" 2>/dev/null || return "$MEOW_OK"

  if meow_seco; then
    meow_muda "mudaria $JANELAS_ALVO_PIN (tiling_enabled: $valor)"
    return "$MEOW_DIVERGENTE"
  fi
  # `meow_escrever` com o conteúdo inteiro: ele já grava atômico (mktemp + mv),
  # que aqui não é luxo — o cosmic-comp lê este arquivo por inotify e um `printf
  # >` no meio da leitura entrega RON truncado.
  local nl=""
  [ -n "$(tail -c1 "$JANELAS_ALVO_PIN" 2>/dev/null)" ] || nl=$'\n'
  novo="$(sed "s/tiling_enabled: $oposto,/tiling_enabled: $valor,/g" "$JANELAS_ALVO_PIN")$nl" \
    || return "$MEOW_ERRO"
  meow_escrever "$JANELAS_ALVO_PIN" "$novo" 644
}

_janelas_lembrar_antes() {
  meow_seco && return 0
  [ -f "$JANELAS_ANTES/autotile.antes" ] && return 0
  mkdir -p "$JANELAS_ANTES" 2>/dev/null || return 0
  printf '%s' "$(_janelas_no_disco "$JANELAS_ALVO_LIGADO")" \
    > "$JANELAS_ANTES/autotile.antes" 2>/dev/null || true
  printf '%s' "$(_janelas_no_disco "$JANELAS_ALVO_ESCOPO")" \
    > "$JANELAS_ANTES/autotile_behavior.antes" 2>/dev/null || true
  return 0
}

cmd_aplicar() {
  if [ -z "$JANELAS_TILING" ]; then
    meow_pula "JANELAS_TILING vazio — o lado a lado é seu (Super+Y manda)"
    return "$MEOW_OK"
  fi
  _janelas_dependencia || return $?

  local ligado escopo
  ligado="$(_janelas_bool "$JANELAS_TILING")" || {
    meow_erro "JANELAS_TILING='$JANELAS_TILING' — esperado sim ou nao"
    return "$MEOW_ERRO"
  }
  # O escopo tem padrão porque `sim` sem `Global` é a armadilha nº 1 do
  # cabeçalho: ligaria a chave e não mudaria um pixel. Quem pede o lado a lado
  # quer ver o lado a lado.
  escopo="$(_janelas_escopo "${JANELAS_TILING_ESCOPO:-global}")" || {
    meow_erro "JANELAS_TILING_ESCOPO='$JANELAS_TILING_ESCOPO' — esperado global ou workspace"
    return "$MEOW_ERRO"
  }

  local atual_l atual_e
  atual_l="$(_janelas_no_disco "$JANELAS_ALVO_LIGADO")"
  atual_e="$(_janelas_no_disco "$JANELAS_ALVO_ESCOPO")"
  { [ "$atual_l" = "$ligado" ] && [ "$atual_e" = "$escopo" ]; } || _janelas_lembrar_antes

  # A ORDEM IMPORTA NA PRIMEIRA VEZ, e é por isso que ela está escrita e não
  # subentendida: os dois handlers do compositor chamam `apply_tile_change`, mas
  # ele só re-tila os workspaces que já existem quando o escopo JÁ é `Global`.
  local rc_l rc_e rc_p rc
  meow_escrever "$JANELAS_ALVO_LIGADO" "$ligado" 644; rc_l=$?
  meow_escrever "$JANELAS_ALVO_ESCOPO" "$escopo" 644; rc_e=$?
  # A terceira, que é a que decide o LOGIN — ver a armadilha nº 3 do cabeçalho.
  _janelas_pin_escrever "$ligado"; rc_p=$?

  if [ "$rc_l" = "$MEOW_ERRO" ] || [ "$rc_e" = "$MEOW_ERRO" ] || [ "$rc_p" = "$MEOW_ERRO" ]; then
    meow_erro "não consegui gravar em $JANELAS_BASE"
    meow_registrar "janelas.sh aplicar rc=$MEOW_ERRO"
    return "$MEOW_ERRO"
  fi

  # `case` e não `[ a ] || [ b ] && c`: nessa forma o `&&` só enxerga o último
  # teste, então um divergente na PRIMEIRA chave sozinho não levantava o rc.
  rc="$MEOW_OK"
  case "$MEOW_DIVERGENTE" in
    "$rc_l"|"$rc_e"|"$rc_p") rc="$MEOW_DIVERGENTE" ;;
  esac

  case "$rc" in
    "$MEOW_DIVERGENTE")
      if meow_seco; then
        meow_muda "gravaria autotile=$ligado e autotile_behavior=$escopo"
      else
        if [ "$ligado" = "true" ]; then
          meow_muda "lado a lado LIGADO ($escopo) — as janelas dividem a tela sozinhas"
        else
          meow_muda "lado a lado DESLIGADO ($escopo) — as janelas voltam a flutuar"
        fi
        meow_info "vale na hora: medido em 25/08/2026, sem reiniciar cosmic-comp nem sessão"
        meow_info "Super+Y alterna no workspace atual · Super+O vira a divisão · Super+G solta a janela"
      fi ;;
    *)
      meow_ok "lado a lado já estava em autotile=$ligado ($escopo)" ;;
  esac
  meow_registrar "janelas.sh aplicar autotile=$ligado escopo=$escopo rc=$rc"
  return "$rc"
}

cmd_conferir() {
  if [ -z "$JANELAS_TILING" ]; then
    meow_pula "JANELAS_TILING vazio — nada a conferir (o valor é seu)"
    return "$MEOW_OK"
  fi
  _janelas_dependencia || return $?

  local ligado escopo
  ligado="$(_janelas_bool "$JANELAS_TILING")" || {
    meow_erro "JANELAS_TILING='$JANELAS_TILING' — esperado sim ou nao"
    return "$MEOW_ERRO"
  }
  escopo="$(_janelas_escopo "${JANELAS_TILING_ESCOPO:-global}")" || {
    meow_erro "JANELAS_TILING_ESCOPO='$JANELAS_TILING_ESCOPO' — esperado global ou workspace"
    return "$MEOW_ERRO"
  }

  local atual_l atual_e pin_div pin_tot
  atual_l="$(_janelas_no_disco "$JANELAS_ALVO_LIGADO")"
  atual_e="$(_janelas_no_disco "$JANELAS_ALVO_ESCOPO")"
  pin_div="$(_janelas_pin_divergentes "$ligado")"
  pin_tot="$(_janelas_pin_total)"

  if [ "$atual_l" = "$ligado" ] && [ "$atual_e" = "$escopo" ] && [ "${pin_div:-0}" = "0" ]; then
    meow_ok "lado a lado conforme (autotile=$ligado, $escopo, $pin_tot alfinetado(s))"
    return "$MEOW_OK"
  fi

  # A primeira linha diz o que o conf pede, e não termina em dois-pontos: é ela
  # que a tabela do doctor mostra, e "divergente:" sozinho saía cortado. O
  # detalhe de cada chave segue embaixo.
  meow_muda "lado a lado divergente do meow.conf (ele pede autotile=$ligado, $escopo)"
  [ "$atual_l" = "$ligado" ] || meow_muda "  autotile: disco='${atual_l:-<ausente>}', conf pede '$ligado'"
  [ "$atual_e" = "$escopo" ] || meow_muda "  autotile_behavior: disco='${atual_e:-<ausente>}', conf pede '$escopo'"
  if [ -n "$pin_div" ] && [ "$pin_div" != "0" ]; then
    meow_muda "  pinned_workspaces: $pin_div de $pin_tot workspace(s) alfinetado(s) fora de tiling_enabled: $ligado"
    meow_aviso "essa é a que decide o LOGIN — as outras duas valem só na sessão de agora."
  fi
  # O mesmo pedágio do relogio.sh: a chave tem atalho de teclado, então ela pode
  # ter mudado de propósito, e o doctor não pode desfazer isso calado.
  meow_aviso "o lado a lado tem atalho (Super+Y) e pode ter sido você."
  meow_aviso "se foi, esvazie JANELAS_TILING no meow.conf — senão o"
  meow_aviso "'meow doctor --consertar' devolve o valor daqui todo dia às 5h."
  return "$MEOW_DIVERGENTE"
}

_janelas_col() { printf '%-22s' "$1"; }

cmd_estado() {
  _janelas_dependencia || return $?
  local k v
  for k in autotile autotile_behavior active_hint edge_snap_threshold; do
    if [ -f "$JANELAS_BASE/$k" ]; then
      v="$(cat "$JANELAS_BASE/$k" 2>/dev/null)"
      meow_info "$(_janelas_col "$k") = $v"
    else
      meow_pula "$(_janelas_col "$k") = <ausente: vale o Default do cosmic-comp>"
    fi
  done

  # O que o pinned_workspaces diz é a foto do INÍCIO da sessão, não o agora.
  # Dizer isso aqui evita a conclusão errada de que o tiling "não pegou".
  local pin="$JANELAS_BASE/pinned_workspaces"
  if [ -f "$pin" ]; then
    # `|| printf 0` aqui seria bug: o `grep -c` JÁ imprime "0" quando não acha, e
    # sai com 1 — os dois rodariam e o número viria "0\n0". Deixar o rc morrer no
    # `|| true` e normalizar depois é o que dá um número só.
    local n t
    n="$(grep -c 'tiling_enabled: true' "$pin" 2>/dev/null || true)"; n="${n:-0}"
    t="$(grep -c 'tiling_enabled' "$pin" 2>/dev/null || true)"; t="${t:-0}"
    meow_info "$(_janelas_col "workspaces alfinetados") $n de $t com tiling_enabled: true"
    meow_info "  (é ESTE que decide o login — o cosmic-comp lê o arquivo uma vez, ao iniciar)"
  fi

  local gaps
  gaps="$(meow_cosmic_dir)/com.system76.CosmicTheme.Dark/$(meow_cosmic_v com.system76.CosmicTheme.Dark)/gaps"
  [ -f "$gaps" ] && meow_info "$(_janelas_col "gaps (do TEMA)") $(cat "$gaps") — (margem da tela, entre janelas)"

  local pid; pid="$(pgrep -x cosmic-comp 2>/dev/null | head -1)"
  if [ -n "$pid" ]; then
    meow_ok "cosmic-comp vivo (PID $pid) — ele relê autotile/autotile_behavior a quente"
  else
    meow_aviso "cosmic-comp NÃO está rodando — nada disto está valendo agora"
  fi
  return "$MEOW_OK"
}

cmd_remover() {
  _janelas_dependencia || return $?
  # Padrão de fábrica do CosmicCompConfig, e também o que havia no disco dela
  # antes. Se houver registro do valor de antes, ele vence.
  local dev_l="false" dev_e="PerWorkspace" g
  if [ -f "$JANELAS_ANTES/autotile.antes" ]; then
    g="$(cat "$JANELAS_ANTES/autotile.antes" 2>/dev/null)"
    case "$g" in true|false) dev_l="$g" ;; esac
  fi
  if [ -f "$JANELAS_ANTES/autotile_behavior.antes" ]; then
    g="$(cat "$JANELAS_ANTES/autotile_behavior.antes" 2>/dev/null)"
    case "$g" in Global|PerWorkspace) dev_e="$g" ;; esac
  fi

  # Os três rc, e ERRO vence DIVERGENTE. A versão anterior só comparava o
  # segundo rc com DIVERGENTE: um erro de escrita (2) virava "ok" e o script
  # devolvia 0 dizendo que tinha devolvido o valor. Mentira silenciosa.
  local rc rc_e rc_p
  meow_escrever "$JANELAS_ALVO_LIGADO" "$dev_l" 644; rc=$?
  meow_escrever "$JANELAS_ALVO_ESCOPO" "$dev_e" 644; rc_e=$?
  _janelas_pin_escrever "$dev_l"; rc_p=$?
  case "$MEOW_DIVERGENTE" in "$rc_e"|"$rc_p") [ "$rc" = "$MEOW_ERRO" ] || rc="$MEOW_DIVERGENTE" ;; esac
  case "$MEOW_ERRO"       in "$rc_e"|"$rc_p") rc="$MEOW_ERRO" ;; esac

  case "$rc" in
    "$MEOW_ERRO") meow_erro "não consegui devolver as chaves de $JANELAS_BASE"; return "$MEOW_ERRO" ;;
    "$MEOW_DIVERGENTE")
      meow_seco && meow_muda "devolveria autotile=$dev_l ($dev_e)" \
                || meow_muda "lado a lado devolvido: autotile=$dev_l ($dev_e)" ;;
    *) meow_ok "lado a lado já estava em autotile=$dev_l ($dev_e)" ;;
  esac
  meow_seco || rm -rf "$JANELAS_ANTES" 2>/dev/null
  meow_registrar "janelas.sh remover autotile=$dev_l escopo=$dev_e rc=$rc"
  return "$rc"
}

case "${1:-aplicar}" in
  aplicar)  cmd_aplicar ;;
  conferir) cmd_conferir ;;
  estado)   cmd_estado ;;
  remover)  cmd_remover ;;
  *) meow_erro "uso: janelas.sh {aplicar|conferir|estado|remover}"; exit "$MEOW_ERRO" ;;
esac

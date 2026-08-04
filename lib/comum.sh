#!/usr/bin/env bash
# lib/comum.sh — a base de todo módulo do MeowSystem: cores, log, códigos de
# saída e as duas travas que impedem o instalador de estragar a máquina dela.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO.
#
# AS CORES SAEM DA PALETA, COMO TUDO AQUI
#   São os mesmos hex de `palette/catppuccin.json`, convertidos para o truecolor
#   do terminal. Se um dia a paleta mudar, muda aqui também — mas continua sem
#   inventar cor nova no meio do caminho.
#
# CÓDIGOS DE SAÍDA HONESTOS (regra 7 do contrato)
#   0 = certo · 1 = divergente · 2 = erro de execução · 3 = falta dependência.
#   A diferença entre 1 e 3 é o que permite ao auto-reparo ficar quieto quando o
#   app simplesmente não está instalado, e gritar quando algo de fato quebrou.
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
MEOW_SECO="${MEOW_DRY_RUN:-0}"

MEOW_OK=0; MEOW_DIVERGENTE=1; MEOW_ERRO=2; MEOW_SEM_DEPENDENCIA=3

if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  C_MAUVE=$'\033[38;2;203;166;247m'; C_ROSA=$'\033[38;2;245;194;231m'
  C_VERDE=$'\033[38;2;166;227;161m'; C_AMARELO=$'\033[38;2;249;226;175m'
  C_VERM=$'\033[38;2;243;139;168m';  C_AZUL=$'\033[38;2;137;180;250m'
  C_DIM=$'\033[38;2;127;132;156m';   C_FORTE=$'\033[1m'; C_ZERO=$'\033[0m'
else
  C_MAUVE=""; C_ROSA=""; C_VERDE=""; C_AMARELO=""; C_VERM=""; C_AZUL=""
  C_DIM=""; C_FORTE=""; C_ZERO=""
fi

meow_titulo() { printf '\n%s%s%s\n' "$C_MAUVE$C_FORTE" "$*" "$C_ZERO"; }
meow_passo()  { printf '\n  %s%s%s\n  %s%s%s\n' "$C_MAUVE$C_FORTE" "$*" "$C_ZERO" \
                       "$C_DIM" "$(printf '%.0s─' {1..52})" "$C_ZERO"; }
meow_info()   { printf '  %s>>%s %s\n' "$C_AZUL" "$C_ZERO" "$*"; }
meow_ok()     { printf '  %sok%s   %s\n' "$C_VERDE" "$C_ZERO" "$*"; }
meow_muda()   { printf '  %s~~%s   %s\n' "$C_AMARELO" "$C_ZERO" "$*"; }
meow_pula()   { printf '  %s--%s   %s\n' "$C_DIM" "$C_ZERO" "$*"; }
meow_aviso()  { printf '  %s!!%s   %s\n' "$C_AMARELO" "$C_ZERO" "$*" >&2; }
meow_erro()   { printf '  %serro%s %s\n' "$C_VERM" "$C_ZERO" "$*" >&2; }
meow_seco()   { [ "$MEOW_SECO" = "1" ]; }

# --- TRAVA 1: territórios proibidos ----------------------------------------
# Uma escrita fora de lugar aqui não dá erro: dá um sintoma bizarro dias depois.
#   /usr/share  — é do Ritual da Aurora e do apt. O self-heal reverte em até 1h,
#                 e um `apt upgrade` sobrescreve. Escrever lá é trabalho perdido.
#   ~/.config/zsh — é o repo Andromeda com auto-commit a cada 10min: qualquer
#                 arquivo largado lá vira commit e push no repo PRIVADO dela.
#   ~/.config/cosmic/com.system76.CosmicSettings.Shortcuts — os atalhos são do
#                 Aurora, que remove Spawn órfão sob /usr/local/bin sem avisar.
meow_destino_permitido() {
  local alvo="$1" real
  real="$(readlink -m -- "$alvo")"
  case "$real" in
    /usr/share/*|/usr/local/share/*|/usr/bin/*|/usr/lib/*)
      meow_erro "recusado: '$alvo' é território do sistema/Aurora"; return 1 ;;
    "$HOME/.config/zsh"|"$HOME/.config/zsh"/*)
      meow_erro "recusado: '$alvo' está no repo Andromeda (auto-commit em 10min)"; return 1 ;;
    *com.system76.CosmicSettings.Shortcuts*)
      meow_erro "recusado: os atalhos de teclado são do Ritual da Aurora"; return 1 ;;
  esac
  return 0
}

# --- TRAVA 2: escrita atômica no MESMO sistema de arquivos ------------------
# O repo mora em /mnt/Apate e os destinos em /home: `mv` entre eles NÃO é
# atômico, e um corte no meio deixaria arquivo de config pela metade. O
# temporário nasce sempre dentro do diretório de DESTINO.
meow_escrever() {
  local destino="$1" conteudo="$2" modo="${3:-644}" tmp dir
  meow_destino_permitido "$destino" || return "$MEOW_ERRO"
  dir="$(dirname "$destino")"

  if [ -f "$destino" ] && [ "$conteudo" = "$(cat "$destino" 2>/dev/null)" ]; then
    return "$MEOW_OK"   # regra 5: comparar por conteúdo, não escrever à toa
  fi
  if meow_seco; then
    meow_muda "mudaria $destino"
    return "$MEOW_DIVERGENTE"
  fi
  mkdir -p "$dir" || return "$MEOW_ERRO"
  tmp="$(mktemp -p "$dir" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  printf '%s' "$conteudo" > "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod "$modo" "$tmp"
  mv -f "$tmp" "$destino" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"   # 1 = "estava divergente e eu consertei"
}

# --- lock: o timer pode disparar enquanto ela roda na mão (regra 10) --------
MEOW_ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"
meow_travar() {
  mkdir -p "$MEOW_ESTADO"
  exec {MEOW_FD}>"$MEOW_ESTADO/lock" || return "$MEOW_ERRO"
  if ! flock -n "$MEOW_FD"; then
    meow_aviso "outro meow está rodando (lock em $MEOW_ESTADO/lock) — saindo"
    return "$MEOW_ERRO"
  fi
  return 0
}

meow_registrar() {
  mkdir -p "$MEOW_ESTADO"
  printf '%s %s\n' "$(date -Iseconds)" "$*" >> "$MEOW_ESTADO/meow.log"
}

meow_tem() { command -v "$1" >/dev/null 2>&1; }

# Notificação: ela precisa saber quando algo mudou sozinho.
meow_notificar() {
  meow_tem notify-send || return 0
  notify-send -a MeowSystem -i preferences-desktop-theme "$1" "${2:-}" 2>/dev/null || true
}

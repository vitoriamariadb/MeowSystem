#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

GPU_PCI="${MEOW_GPU_PCI:-/sys/bus/pci/devices}"
GPU_ENV="${MEOW_GPU_ENV:-/etc/environment}"
GPU_ORIGINAL="${MEOW_GPU_ORIGINAL:-/var/lib/meowsystem/environment.original}"
GPU_CHAVE=COSMIC_RENDER_DEVICE
GPU_COMPOSITOR="${GPU_COMPOSITOR:-dedicada}"

ACAO="${1:-aplicar}"
case "$ACAO" in
  aplicar|conferir|reverter|detectar) ;;
  --conferir) ACAO="conferir" ;;
  -h|--help)
    printf 'uso: %s [aplicar|conferir|reverter|detectar]\n\n' "$(basename "$0")"
    printf '  aplicar   a placa dedicada vira o %s do /etc/environment, pela ponte root\n' "$GPU_CHAVE"
    printf '  conferir  não escreve nada (0 igual · 1 divergente · 3 falta a ponte root)\n'
    printf '  reverter  tira a linha que o MeowSystem gravou\n'
    printf '  detectar  imprime a placa dedicada, ou nada com uma GPU só\n\n'
    printf 'conf: GPU_COMPOSITOR (dedicada | padrao)\n'
    exit 0 ;;
  *) meow_erro "uso: gpu_compositor.sh [aplicar|conferir|reverter|detectar]"; exit "$MEOW_ERRO" ;;
esac
# shellcheck disable=SC2034
[ "$ACAO" = "conferir" ] && MEOW_SECO=1

_gpu_detectar() {
  local dev cls v d b id n=0 primeira="" nvidia=""
  for dev in "$GPU_PCI"/*; do
    [ -r "$dev/class" ] || continue
    cls="$(cat "$dev/class" 2>/dev/null)"
    case "$cls" in 0x0300??|0x0302??) ;; *) continue ;; esac
    compgen -G "$dev/drm/renderD*" >/dev/null || continue
    v="$(cat "$dev/vendor" 2>/dev/null)"; d="$(cat "$dev/device" 2>/dev/null)"
    case "$v:$d" in
      0x[0-9a-f][0-9a-f][0-9a-f][0-9a-f]:0x[0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
      *) continue ;;
    esac
    n=$((n + 1))
    b="$(cat "$dev/boot_vga" 2>/dev/null || true)"
    [ "$b" != 1 ] || continue
    id="$v:$d"
    [ -n "$primeira" ] || primeira="$id"
    if [ "$v" = 0x10de ] && [ -z "$nvidia" ]; then nvidia="$id"; fi
  done
  [ "$n" -ge 2 ] || return 0
  printf '%s' "${nvidia:-$primeira}"
}

_gpu_atual() {
  local linha
  linha="$(grep -m1 "^$GPU_CHAVE=" "$GPU_ENV" 2>/dev/null || true)"
  linha="${linha#*=}"
  linha="${linha#\"}"; linha="${linha%\"}"
  printf '%s' "$linha"
}

_gpu_e_nossa() { [ -e "$GPU_ORIGINAL" ]; }

_gpu_pedir_a_ponte() {
  local verbo="$1" frase="$2"
  if ! meow_ponte_viva; then
    meow_pula "$frase: a ponte root não está de pé, o «Instalar tudo» a levanta"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! grep -qx "$verbo)" "$MEOW_PONTE" 2>/dev/null; then
    meow_pula "$frase: a ponte root instalada é de antes deste conserto, o «Instalar tudo» a renova"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! meow_ponte "$verbo" </dev/null >/dev/null 2>&1; then
    meow_erro "a ponte root não aceitou $verbo: o «Instalar tudo» a atualiza"
    return "$MEOW_ERRO"
  fi
  return "$MEOW_OK"
}

cmd_conferir_ou_aplicar() {
  local quer atual
  atual="$(_gpu_atual)"
  if [ "$GPU_COMPOSITOR" = padrao ]; then
    if _gpu_e_nossa && [ -n "$atual" ]; then
      meow_muda "GPU_COMPOSITOR=\"padrao\" e o /etc/environment ainda tem o $GPU_CHAVE que o MeowSystem gravou ($atual)"
      meow_seco && return "$MEOW_DIVERGENTE"
      _gpu_pedir_a_ponte gpu-compositor-tirar "tirar o $GPU_CHAVE do /etc/environment" || return $?
      meow_muda "o $GPU_CHAVE saiu do /etc/environment (vale no próximo login)"
      return "$MEOW_DIVERGENTE"
    fi
    meow_ok "o compositor fica na GPU que o cosmic-comp escolhe (GPU_COMPOSITOR=\"padrao\")"
    return "$MEOW_OK"
  fi

  quer="$(_gpu_detectar)"
  if [ -z "$quer" ]; then
    if [ -n "$atual" ] && _gpu_e_nossa; then
      meow_muda "só há uma GPU e o /etc/environment ainda tem o $GPU_CHAVE que o MeowSystem gravou ($atual)"
      meow_seco && return "$MEOW_DIVERGENTE"
      _gpu_pedir_a_ponte gpu-compositor "tirar o $GPU_CHAVE do /etc/environment" || return $?
      meow_muda "o $GPU_CHAVE saiu do /etc/environment (vale no próximo login)"
      return "$MEOW_DIVERGENTE"
    fi
    meow_ok "só há uma GPU: o compositor usa a que há, sem linha no /etc/environment"
    return "$MEOW_OK"
  fi

  if [ "$atual" = "$quer" ]; then
    meow_ok "o compositor usa a placa dedicada ($quer)"
    return "$MEOW_OK"
  fi
  meow_muda "o $GPU_CHAVE do /etc/environment é ${atual:-ausente} e a placa dedicada é $quer — vale no próximo login"
  meow_seco && return "$MEOW_DIVERGENTE"
  _gpu_pedir_a_ponte gpu-compositor "pôr a placa dedicada ($quer) no /etc/environment" || return $?
  meow_registrar "gpu_compositor.sh $GPU_CHAVE=$quer"
  return "$MEOW_DIVERGENTE"
}

cmd_reverter() {
  if ! _gpu_e_nossa; then
    meow_pula "o MeowSystem não gravou o $GPU_CHAVE — nada a tirar"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "tiraria o $GPU_CHAVE que o MeowSystem gravou no /etc/environment"
    return "$MEOW_DIVERGENTE"
  fi
  _gpu_pedir_a_ponte gpu-compositor-tirar "tirar o $GPU_CHAVE do /etc/environment" || return $?
  meow_muda "o $GPU_CHAVE saiu do /etc/environment (vale no próximo login)"
  return "$MEOW_DIVERGENTE"
}

case "$ACAO" in
  detectar) _gpu_detectar; exit 0 ;;
  reverter) cmd_reverter; exit $? ;;
  *)        cmd_conferir_ou_aplicar; exit $? ;;
esac

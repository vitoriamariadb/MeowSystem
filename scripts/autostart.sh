#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

AUTOSTART_BLOQUEADOS="${AUTOSTART_BLOQUEADOS:-}"

AUTOSTART_REGISTRO="$MEOW_ESTADO/autostart-mascarados.tsv"

_auto_unidade() {
  local id="$1" esc
  esc="$(systemd-escape -- "$id" 2>/dev/null)" || return 1
  [ -n "$esc" ] || return 1
  printf 'app-%s@autostart.service' "$esc"
}

_auto_lista() {
  local item
  printf '%s\n' "$AUTOSTART_BLOQUEADOS" | tr ',' '\n' | while IFS= read -r item; do
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [ -n "$item" ] && printf '%s\n' "$item"
  done
}

_auto_dependencia() {
  if ! meow_tem systemctl || ! meow_tem systemd-escape; then
    meow_pula "sem systemctl/systemd-escape — nada a fazer com autostart"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! systemctl --user show --property=Version >/dev/null 2>&1; then
    meow_pula "sem gerenciador systemd de usuário ao alcance — nada a fazer"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

_auto_estado_unidade() { systemctl --user is-enabled -- "$1" 2>/dev/null || true; }
_auto_mascarada()      { case "$(_auto_estado_unidade "$1")" in masked|masked-runtime) return 0 ;; esac; return 1; }

_auto_registrar() {
  local id="$1" unidade="$2" antes="$3"
  meow_seco && return 0
  mkdir -p "$MEOW_ESTADO" || return 0
  if [ -f "$AUTOSTART_REGISTRO" ]; then
    awk -F'\t' -v a="$id" '$1 != a' "$AUTOSTART_REGISTRO" > "$AUTOSTART_REGISTRO.tmp" 2>/dev/null \
      && mv -f "$AUTOSTART_REGISTRO.tmp" "$AUTOSTART_REGISTRO" 2>/dev/null
    rm -f "$AUTOSTART_REGISTRO.tmp" 2>/dev/null
  fi
  printf '%s\t%s\t%s\t%s\n' "$id" "$unidade" "$antes" "$(date -Iseconds)" >> "$AUTOSTART_REGISTRO"
  return 0
}

_auto_esquecer() {
  local id="$1"
  meow_seco && return 0
  [ -f "$AUTOSTART_REGISTRO" ] || return 0
  awk -F'\t' -v a="$id" '$1 != a' "$AUTOSTART_REGISTRO" > "$AUTOSTART_REGISTRO.tmp" 2>/dev/null \
    && mv -f "$AUTOSTART_REGISTRO.tmp" "$AUTOSTART_REGISTRO" 2>/dev/null
  rm -f "$AUTOSTART_REGISTRO.tmp" 2>/dev/null
  return 0
}

_auto_antes_de() {
  [ -f "$AUTOSTART_REGISTRO" ] || return 1
  awk -F'\t' -v a="$1" '$1 == a { print $3; achou=1 } END { exit !achou }' "$AUTOSTART_REGISTRO" 2>/dev/null
}

_auto_ids_registrados() {
  [ -f "$AUTOSTART_REGISTRO" ] || return 0
  awk -F'\t' '{ print $1 }' "$AUTOSTART_REGISTRO" 2>/dev/null
}

_auto_vivo() { pgrep -i -x -- "${1##*.}" >/dev/null 2>&1; }

_auto_saidos() {
  local reg
  while IFS= read -r reg; do
    [ -n "$reg" ] || continue
    _auto_lista | grep -qxF -- "$reg" && continue
    [ "$(_auto_antes_de "$reg" 2>/dev/null)" = "masked-antes-de-nos" ] && continue
    printf '%s\n' "$reg"
  done <<< "$(_auto_ids_registrados)"
}

cmd_aplicar() {
  if [ -z "$AUTOSTART_BLOQUEADOS" ] && [ -z "$(_auto_saidos)" ]; then
    meow_pula "AUTOSTART_BLOQUEADOS vazio — nenhum autostart a bloquear"
    return "$MEOW_OK"
  fi
  _auto_dependencia || return $?

  local rc="$MEOW_OK" id unidade antes
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    unidade="$(_auto_unidade "$id")" || {
      meow_erro "não consegui montar o nome da unidade para '$id'"; rc="$MEOW_ERRO"; continue
    }

    if _auto_mascarada "$unidade"; then
      if ! _auto_antes_de "$id" >/dev/null 2>&1; then
        _auto_registrar "$id" "$unidade" "masked-antes-de-nos"
        meow_ok "$id já estava mascarado por fora — anotado, e o 'remover' não vai desfazer"
      else
        meow_ok "$id já mascarado ($unidade)"
      fi
      continue
    fi

    antes="$(_auto_estado_unidade "$unidade")"; antes="${antes:-desconhecido}"
    if meow_seco; then
      meow_muda "mascararia $unidade (estado hoje: $antes)"
      rc="$MEOW_DIVERGENTE"; continue
    fi

    if systemctl --user mask -- "$unidade" >/dev/null 2>&1; then
      _auto_registrar "$id" "$unidade" "$antes"
      meow_muda "$id não sobe mais no login (mask em $unidade)"
      _auto_vivo "$id" && meow_aviso "$id está ABERTO agora — não vou fechá-lo; o efeito vale no próximo login"
      rc="$MEOW_DIVERGENTE"
    else
      meow_erro "systemctl --user mask falhou para $unidade"
      rc="$MEOW_ERRO"
    fi
  done <<< "$(_auto_lista)"

  local -a saidos=()
  mapfile -t saidos < <(_auto_saidos)
  if [ "${#saidos[@]}" -gt 0 ]; then
    local rc_saidos
    cmd_remover "${saidos[@]}"; rc_saidos=$?
    if [ "$rc_saidos" = "$MEOW_ERRO" ]; then rc="$MEOW_ERRO"
    elif [ "$rc_saidos" = "$MEOW_DIVERGENTE" ] && [ "$rc" = "$MEOW_OK" ]; then rc="$MEOW_DIVERGENTE"; fi
  fi

  meow_registrar "autostart.sh aplicar rc=$rc lista=$AUTOSTART_BLOQUEADOS"
  return "$rc"
}

cmd_conferir() {
  if [ -z "$AUTOSTART_BLOQUEADOS" ] && [ -z "$(_auto_saidos)" ]; then
    meow_pula "AUTOSTART_BLOQUEADOS vazio — nada a conferir"
    return "$MEOW_OK"
  fi
  _auto_dependencia || return $?

  local rc="$MEOW_OK" id unidade
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    unidade="$(_auto_unidade "$id")" || { meow_erro "id inválido: '$id'"; rc="$MEOW_ERRO"; continue; }
    if _auto_mascarada "$unidade"; then
      meow_ok "$id bloqueado no login"
    else
      meow_muda "$id NÃO está bloqueado ($unidade = $(_auto_estado_unidade "$unidade" | sed 's/^$/sem resposta/'))"
      [ "$rc" = "$MEOW_ERRO" ] || rc="$MEOW_DIVERGENTE"
    fi
  done <<< "$(_auto_lista)"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    unidade="$(_auto_unidade "$id")" || continue
    if _auto_mascarada "$unidade"; then
      meow_muda "$id saiu da lista e segue mascarado; a próxima passada o desmascara"
      [ "$rc" = "$MEOW_ERRO" ] || rc="$MEOW_DIVERGENTE"
    fi
  done <<< "$(_auto_saidos)"
  return "$rc"
}

cmd_estado() {
  _auto_dependencia || return $?
  local vistos="" id unidade est antes
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    vistos="$vistos $id"
    unidade="$(_auto_unidade "$id")" || continue
    est="$(_auto_estado_unidade "$unidade")"; est="${est:-sem resposta}"
    antes="$(_auto_antes_de "$id" 2>/dev/null)" || antes="—"
    meow_info "$id: $est   (unidade: $unidade · antes de nós: ${antes:-—})"
  done <<< "$(_auto_lista)"

  while IFS= read -r id; do
    [ -n "$id" ] || continue
    case " $vistos " in *" $id "*) continue ;; esac
    unidade="$(_auto_unidade "$id")" || continue
    est="$(_auto_estado_unidade "$unidade")"; est="${est:-sem resposta}"
    meow_pula "$id: $est   (fora do conf, mas no nosso registro)"
  done <<< "$(_auto_ids_registrados)"

  meow_info "abrir pelo ícone não passa por estas unidades — ver o cabeçalho deste arquivo"
  return "$MEOW_OK"
}

cmd_remover() {
  _auto_dependencia || return $?

  local alvos
  if [ "$#" -gt 0 ]; then alvos="$(printf '%s\n' "$@")"
  else                    alvos="$(_auto_ids_registrados)"; fi

  if [ -z "$alvos" ]; then
    meow_pula "não há nada no nosso registro para desmascarar"
    return "$MEOW_OK"
  fi

  local rc="$MEOW_OK" id unidade antes
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    unidade="$(_auto_unidade "$id")" || { meow_erro "id inválido: '$id'"; rc="$MEOW_ERRO"; continue; }

    antes="$(_auto_antes_de "$id" 2>/dev/null)" || antes=""
    if [ -z "$antes" ]; then
      meow_pula "$id não está no nosso registro — não fomos nós que mascaramos, não mexo"
      continue
    fi
    if [ "$antes" = "masked-antes-de-nos" ]; then
      meow_pula "$id já estava mascarado antes do MeowSystem — deixo como estava"
      _auto_esquecer "$id"
      continue
    fi
    if ! _auto_mascarada "$unidade"; then
      meow_ok "$id já não está mascarado"
      _auto_esquecer "$id"
      continue
    fi
    if meow_seco; then
      meow_muda "desmascararia $unidade (devolvendo ao estado '$antes')"
      rc="$MEOW_DIVERGENTE"; continue
    fi
    if systemctl --user unmask -- "$unidade" >/dev/null 2>&1; then
      _auto_esquecer "$id"
      meow_muda "$id devolvido ao autostart (unmask em $unidade, estado de antes: $antes)"
      meow_info "volta a subir no próximo login, se o .desktop dele existir em ~/.config/autostart"
      rc="$MEOW_DIVERGENTE"
    else
      meow_erro "systemctl --user unmask falhou para $unidade"
      rc="$MEOW_ERRO"
    fi
  done <<< "$alvos"

  meow_registrar "autostart.sh remover rc=$rc"
  return "$rc"
}

sub="${1:-aplicar}"; shift 2>/dev/null || true
case "$sub" in
  aplicar)  cmd_aplicar ;;
  conferir) cmd_conferir ;;
  estado)   cmd_estado ;;
  remover)  cmd_remover "$@" ;;
  *) meow_erro "uso: autostart.sh {aplicar|conferir|estado|remover [id…]}"; exit "$MEOW_ERRO" ;;
esac

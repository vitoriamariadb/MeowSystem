#!/usr/bin/env bash
# escritorio.sh — o escritório é o OnlyOffice: o Flathub do usuário o traz quando
# falta e, só com ele instalado, o apt tira o LibreOffice (pela ponte root).
#
# USO
#   escritorio.sh aplicar [onlyoffice|libreoffice]    faz o que falta (sem alvo, os dois)
#   escritorio.sh conferir [onlyoffice|libreoffice]   0 = no ar · 1 = divergente · 3 = falta root
#   escritorio.sh reverter                            devolve o LibreOffice pelo apt (o desinstalador)
#
# A ordem é a garantia: o LibreOffice nunca sai antes de o OnlyOffice estar na
# máquina. O tema de app do OnlyOffice é do módulo dele, que o `aplicar_apps.sh`
# aplica na etapa seguinte. Os nomes dos pacotes que saíram ficam guardados para o
# reverter. O OnlyOffice instalado fica: é o que se usa.
#
#   0 = certo · 1 = divergente (ou escrevi) · 2 = erro · 3 = falta dependência
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

ES_ID="org.onlyoffice.desktopeditors"
ES_FLATHUB="https://dl.flathub.org/repo/flathub.flatpakrepo"
# Os pacotes que o MeowSystem tirou, um por linha: o reverter os devolve.
ES_ANTES="$MEOW_ESTADO/libreoffice-antes.tsv"

ACAO="${1:-aplicar}"
ALVO="${2:-tudo}"
case "$ACAO" in
  aplicar|conferir|reverter) ;;
  --conferir) ACAO="conferir" ;;
  -h|--help)
    printf 'uso: %s [aplicar|conferir] [onlyoffice|libreoffice] | reverter\n\n' "$(basename "$0")"
    printf '  aplicar   instala o OnlyOffice do Flathub (--user) e tira os pacotes libreoffice* do apt\n'
    printf '  conferir  não escreve nada (0 igual · 1 divergente · 3 falta a ponte root)\n'
    printf '  reverter  devolve os pacotes libreoffice* que saíram\n'
    exit 0 ;;
  *) meow_erro "uso: escritorio.sh [aplicar|conferir] [onlyoffice|libreoffice] | reverter"; exit "$MEOW_ERRO" ;;
esac
case "$ALVO" in tudo|onlyoffice|libreoffice) ;; *) meow_erro "alvo desconhecido: $ALVO"; exit "$MEOW_ERRO" ;; esac
# shellcheck disable=SC2034  # quem lê MEOW_SECO é o meow_seco() do comum.sh
[ "$ACAO" = "conferir" ] && MEOW_SECO=1

# Os libreoffice* instalados, ou só com a configuração que sobrou: a mesma
# pergunta que a ponte faz, para a lista guardada ser a que ela vai tirar.
_es_libre() {
  meow_tem dpkg-query || return 0
  dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'libreoffice*' 2>/dev/null \
    | awk '$1 ~ /^.[ic]/ && $2 ~ /^libreoffice/ { print $2 }'
}

# --- o OnlyOffice -------------------------------------------------------------
cmd_onlyoffice() {
  local modo="$1"
  if meow_flatpak_tem "$ES_ID"; then
    meow_ok "OnlyOffice instalado (Flatpak)"
    return "$MEOW_OK"
  fi
  if ! meow_tem flatpak; then
    meow_pula "sem flatpak — o OnlyOffice não tem de onde vir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ "$modo" = "conferir" ] || meow_seco; then
    meow_muda "o OnlyOffice não está instalado — viria do Flathub, no usuário"
    return "$MEOW_DIVERGENTE"
  fi
  meow_info "instalando o OnlyOffice do Flathub (baixa da internet)"
  flatpak remote-add --user --if-not-exists flathub "$ES_FLATHUB" >/dev/null 2>&1
  if ! flatpak install --user -y --noninteractive flathub "$ES_ID" >/dev/null 2>&1 || ! meow_flatpak_tem "$ES_ID"; then
    meow_erro "o flatpak não instalou o OnlyOffice (sem rede?)"
    return "$MEOW_ERRO"
  fi
  meow_muda "OnlyOffice instalado do Flathub"
  meow_registrar "escritorio.sh OnlyOffice instalado (flatpak --user)"
  return "$MEOW_DIVERGENTE"
}

# --- o LibreOffice ------------------------------------------------------------
_es_guardar_antes() { # $1 lista de pacotes -> soma ao que já estava guardado, sem repetir
  local texto=""
  [ -f "$ES_ANTES" ] && texto="$(cat "$ES_ANTES")"
  texto="$(printf '%s\n%s\n' "$texto" "$1" | sed '/^$/d' | sort -u)"
  meow_escrever "$ES_ANTES" "$texto" 644 >/dev/null
}

cmd_libreoffice() {
  local modo="$1" lista n
  lista="$(_es_libre)"
  if [ -z "$lista" ]; then
    meow_pendencia_resolvida libreoffice-sistema
    meow_ok "sem pacotes do LibreOffice no apt"
    return "$MEOW_OK"
  fi
  n="$(printf '%s\n' "$lista" | wc -l)"
  if [ "$modo" = "conferir" ] || meow_seco; then
    meow_muda "o LibreOffice está instalado ($n pacotes) — o apt o tiraria, pela ponte root"
    return "$MEOW_DIVERGENTE"
  fi
  if ! meow_flatpak_tem "$ES_ID"; then
    meow_pula "o LibreOffice fica até o OnlyOffice estar instalado"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! meow_ponte_viva; then
    meow_pendencia_acionavel libreoffice-sistema \
      "O LibreOffice ($n pacotes) só sai pela ponte root" "./install.sh"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  _es_guardar_antes "$lista"
  if ! meow_ponte libreoffice-remover </dev/null >/dev/null 2>&1; then
    meow_erro "a ponte root não tirou o LibreOffice"
    return "$MEOW_ERRO"
  fi
  if [ -n "$(_es_libre)" ]; then
    meow_erro "a ponte root rodou e ainda há pacotes do LibreOffice"
    return "$MEOW_ERRO"
  fi
  meow_pendencia_resolvida libreoffice-sistema
  meow_muda "LibreOffice fora da máquina ($n pacotes)"
  meow_registrar "escritorio.sh LibreOffice removido pelo apt ($n pacotes)"
  return "$MEOW_DIVERGENTE"
}

# --- juntar os dois -----------------------------------------------------------
# Erro vence, depois o que mudou, depois a falta de root. O LibreOffice vai por
# último: só sai com o OnlyOffice no lugar.
cmd_tudo() {
  local modo="$1" ro=0 rl=0
  case "$ALVO" in onlyoffice|tudo)  cmd_onlyoffice "$modo";  ro=$? ;; esac
  case "$ALVO" in libreoffice|tudo) cmd_libreoffice "$modo"; rl=$? ;; esac
  [ "$ro" -ge 2 ] && [ "$ro" -ne 3 ] && return "$ro"
  [ "$rl" -ge 2 ] && [ "$rl" -ne 3 ] && return "$rl"
  [ "$ro" = "1" ] || [ "$rl" = "1" ] && return "$MEOW_DIVERGENTE"
  [ "$ro" = "3" ] && return "$MEOW_SEM_DEPENDENCIA"
  [ "$rl" = "3" ] && return "$MEOW_SEM_DEPENDENCIA"
  return "$MEOW_OK"
}

# --- reverter: o desinstalador devolve o LibreOffice --------------------------
cmd_reverter() {
  if [ ! -f "$ES_ANTES" ]; then
    meow_pula "o MeowSystem não tirou o LibreOffice — nada a devolver"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "devolveria o LibreOffice pelo apt, pela ponte root"
    return "$MEOW_DIVERGENTE"
  fi
  if ! meow_ponte_viva; then
    meow_aviso "sem a ponte root, o LibreOffice não voltou; a lista dele fica em $ES_ANTES"
    return "$MEOW_OK"
  fi
  if ! meow_ponte libreoffice-devolver < "$ES_ANTES" >/dev/null 2>&1; then
    meow_aviso "a ponte root não devolveu o LibreOffice; a lista dele fica em $ES_ANTES"
    return "$MEOW_OK"
  fi
  meow_guardar_antes "$ES_ANTES"
  rm -f "$ES_ANTES"
  meow_ok "LibreOffice devolvido pelo apt"
  return "$MEOW_OK"
}

case "$ACAO" in
  aplicar)  cmd_tudo aplicar;  exit $? ;;
  conferir) cmd_tudo conferir; exit $? ;;
  reverter) cmd_reverter;      exit $? ;;
esac

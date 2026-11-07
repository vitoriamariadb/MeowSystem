#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

LV_GARANTIR="${LV_GARANTIR:-$MEOW_RAIZ/scripts/garantir_builds.sh}"
LV_DOCTOR="${LV_DOCTOR:-$MEOW_RAIZ/bin/meow}"
LV_PINOS="${LV_PINOS:-$MEOW_RAIZ/assets/extensoes}"
LV_ESPACO_KB="${LV_ESPACO_KB:-${CP_ESPACO_KB:-3500000}}"
LV_NOMES="${LV_NOMES:-static.crates.io github.com apt.pop-os.org}"
LV_PACOTES="${LV_PACOTES:-cosmic-comp cosmic-files xdg-desktop-portal-cosmic}"
LV_GIT="${LV_GIT:-1}"

ACHADOS=0
achado() { ACHADOS=$((ACHADOS + 1)); meow_aviso "$1"; }

_lv_kb_em_texto() { awk -v k="$1" 'BEGIN { printf "%.1f GB", k / 1048576 }' | tr . ,; }

lv_disco() {
  local alvo="$MEOW_CACHE" livre
  while [ ! -d "$alvo" ] && [ "$alvo" != / ]; do alvo="$(dirname "$alvo")"; done
  livre="$(df -Pk "$alvo" 2>/dev/null | awk 'NR == 2 {print $4}')"
  case "$livre" in ''|*[!0-9]*) achado "disco: não consegui medir o espaço livre em $alvo"; return ;; esac
  if [ "$livre" -lt "$LV_ESPACO_KB" ]; then
    achado "disco: $(_lv_kb_em_texto "$livre") livres em $alvo, e o build do compositor pede $(_lv_kb_em_texto "$LV_ESPACO_KB")"
  else
    meow_ok "disco: $(_lv_kb_em_texto "$livre") livres em $alvo"
  fi
}

lv_rede() {
  local nome falta=()
  for nome in $LV_NOMES; do
    timeout 5 getent hosts "$nome" >/dev/null 2>&1 || falta+=("$nome")
  done
  if [ "${#falta[@]}" -gt 0 ]; then
    achado "rede: sem resposta de ${falta[*]} — os builds que baixam caem"
  else
    meow_ok "rede: $LV_NOMES respondem"
  fi
}

lv_ponte() {
  if [ ! -x "$MEOW_PONTE" ]; then
    achado "ponte root: não está instalada — o que pede root fica de fora"
  elif sudo -n "$MEOW_PONTE" estado >/dev/null 2>&1; then
    meow_ok "ponte root: responde sem senha"
  else
    achado "ponte root: instalada, e o sudo dela pede senha"
  fi
}

lv_fontes_apt() {
  local p ver base cosmic
  for p in $LV_PACOTES; do
    ver="$(dpkg-query -W -f='${Version}' "$p" 2>/dev/null)"
    [ -n "$ver" ] || continue
    base="$(meow_versao_do_fonte "$ver")"
    if apt-cache showsrc "$p" 2>/dev/null | grep -qxF "Version: $base"; then
      meow_ok "fonte do apt: $p $base no repositório"
    else
      achado "fonte do apt: o repositório já não serve o fonte do $p $base — o build dele espera o próximo apt"
    fi
  done
  cosmic="$(apt list --upgradable 2>/dev/null | grep -c '^cosmic-')"
  if [ "${cosmic:-0}" -gt 0 ]; then
    achado "apt: $cosmic pacote(s) do COSMIC esperam o apt"
  else
    meow_ok "apt: nenhum pacote do COSMIC na fila"
  fi
}

lv_builds() {
  local saida linha nome estado ruins=0
  saida="$("$LV_GARANTIR" estado 2>/dev/null)" || { achado "builds: o estado não respondeu"; return; }
  for nome in compositor menu graficos; do
    estado="$(sed -n "s/^${nome}_estado=//p" <<< "$saida" | head -1)"
    case "$estado" in
      ok|desligado|ausente|oficial|'') ;;
      *) achado "builds: $(_lv_nome_build "$nome") está $estado ($(sed -n "s/^${nome}_versao=//p" <<< "$saida" | head -1))"; ruins=1 ;;
    esac
  done
  linha="$(sed -n 's/^construindo=//p' <<< "$saida")"
  [ "$linha" = sim ] && meow_info "builds: há um build correndo agora"
  [ "$ruins" = 0 ] && meow_ok "builds: compositor, menu do Arquivos e portal em dia"
}

_lv_nome_build() {
  case "$1" in
    compositor) printf 'o compositor' ;;
    menu) printf 'o menu do Arquivos' ;;
    graficos) printf 'o portal de captura' ;;
  esac
}

lv_applets() {
  local marca id nome log presos=0
  for marca in "$MEOW_ESTADO"/extensoes/*/falhou; do
    [ -f "$marca" ] || continue
    id="$(basename "$(dirname "$marca")")"
    nome="$(sed -n 's/^NOME="\(.*\)"$/\1/p' "$LV_PINOS/$id.pino" 2>/dev/null | head -1)"
    log="$(dirname "$marca")/compilar.log"
    achado "applets: ${nome:-$id} não compilou com o pino atual — $(meow_motivo_do_cargo "$log")"
    presos=1
  done
  [ "$presos" = 0 ] && meow_ok "applets: nenhum preso numa falha"
}

lv_git() {
  [ "$LV_GIT" = 1 ] || return 0
  git -C "$MEOW_RAIZ" rev-parse --git-dir >/dev/null 2>&1 || return 0
  local remoto local_ diverge
  remoto="$(timeout 20 git -C "$MEOW_RAIZ" ls-remote origin 2>/dev/null)" || { achado "git: o GitHub não respondeu"; return; }
  local_="$(git -C "$MEOW_RAIZ" rev-parse master 2>/dev/null)"
  if [ "$(awk '$2 == "refs/heads/master" {print $1}' <<< "$remoto")" != "$local_" ]; then
    achado "git: o master daqui e o do GitHub estão em commits diferentes"
  else
    meow_ok "git: o master é o mesmo do GitHub"
  fi
  diverge="$(awk '$2 ~ /^refs\/tags\// && $2 !~ /\^\{\}$/ {sub("refs/tags/", "", $2); print $2, $1}' <<< "$remoto" \
    | while read -r tag hash; do
        [ "$(git -C "$MEOW_RAIZ" rev-parse -q --verify "refs/tags/$tag" 2>/dev/null)" = "$hash" ] || printf '%s ' "$tag"
      done)"
  if [ -n "$diverge" ]; then
    achado "git: tags diferentes das do GitHub: ${diverge% }"
  else
    meow_ok "git: as tags são as do GitHub"
  fi
}

lv_doctor() {
  local saida linhas
  saida="$(NO_COLOR=1 timeout 300 "$LV_DOCTOR" doctor 2>&1)"
  linhas="$(grep -E '^  (!!|erro|xx) ' <<< "$saida" | sed -E 's/^  (!!|erro|xx) +//; s/^([a-z_]+) +/\1: /')"
  if [ -n "$linhas" ]; then
    while IFS= read -r l; do achado "doctor: $l"; done <<< "$linhas"
  else
    meow_ok "doctor: nada divergente"
  fi
}

main() {
  case "${1:-}" in
    -h|--help|ajuda)
      printf '  meow levantamento   lê a máquina inteira antes do install e lista tudo o que vai travar; não escreve nada\n'
      return 0 ;;
    '') ;;
    *) meow_erro "opção desconhecida: $1"; return "$MEOW_ERRO" ;;
  esac
  meow_titulo "Levantamento"
  lv_disco
  lv_rede
  lv_ponte
  lv_fontes_apt
  lv_builds
  lv_applets
  lv_git
  lv_doctor
  printf '\n'
  if [ "$ACHADOS" = 0 ]; then
    meow_ok "nada a resolver"
    return "$MEOW_OK"
  fi
  meow_aviso "$ACHADOS achado(s)"
  return "$MEOW_DIVERGENTE"
}

main "$@"

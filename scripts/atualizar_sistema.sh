#!/usr/bin/env bash

set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

APT_OPCOES=(-y -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef)

_as_tem() { command -v "$1" >/dev/null 2>&1; }

cmd_ver() {
  local n=0
  meow_titulo "O que a atualização mudaria"

  meow_passo "1/3 Pacotes do sistema"
  if _as_tem apt; then
    local lista
    lista="$(apt list --upgradable 2>/dev/null | tail -n +2)"
    if [ -n "$lista" ]; then
      n=$(printf '%s\n' "$lista" | grep -c .)
      meow_muda "$n pacote(s) com versão nova já conhecida"
      printf '%s\n' "$lista" | head -20 | sed 's/^/      /'
      [ "$n" -gt 20 ] && meow_info "  … e mais $((n - 20))"
    else
      meow_ok "nenhum pacote pendente na lista atual"
    fi
    meow_info "  a lista pode estar velha; o \`aplicar\` roda \`apt update\` antes"
  else
    meow_pula "sem apt nesta máquina"
  fi

  meow_passo "2/3 Programas em Rust"
  if _as_tem cargo-install-update; then
    cargo install-update --list 2>/dev/null | sed 's/^/      /' || true
  else
    meow_pula "cargo-install-update não está instalado"
  fi

  meow_passo "3/3 O que o MeowSystem teria de refazer"
  meow_info "depois de atualizar, o \`aplicar\` roda \`meow doctor\` e diz o que"
  meow_info "  a atualização desfez — é a metade que o comando à mão não tem"
  return "$MEOW_OK"
}

cmd_aplicar() {
  local rc="$MEOW_OK"

  if meow_seco; then
    meow_titulo "Atualizar a máquina (ensaio)"
    meow_muda "rodaria: apt update && apt full-upgrade"
    _as_tem topgrade && meow_muda "rodaria: topgrade"
    _as_tem cargo-install-update && meow_muda "rodaria: cargo install-update -a"
    meow_muda "e depois conferiria com o doctor o que a atualização desfez"
    return "$MEOW_DIVERGENTE"
  fi

  meow_titulo "Atualizar a máquina"

  meow_passo "1/4 Pacotes do sistema"
  if _as_tem apt && [ -x "$MEOW_RAIZ/scripts/cosmic_prever.sh" ]; then
    "$MEOW_RAIZ/scripts/cosmic_prever.sh" prever \
      || meow_info "  o veredito do COSMIC tem vermelho — o upgrade segue, e o doctor confere depois o que ele desfizer"
  fi
  if _as_tem apt; then
    local rc_ponte=0
    meow_ponte atualizar || rc_ponte=$?
    if [ "$rc_ponte" = "0" ]; then
      :
    elif [ "$rc_ponte" = "127" ]; then
      sudo apt update || { meow_erro "apt update falhou"; return "$MEOW_ERRO"; }
      sudo apt full-upgrade "${APT_OPCOES[@]}" \
        || { meow_erro "apt full-upgrade falhou — a máquina não ficou pela metade,"
             meow_erro "  o apt desfez o que não conseguiu; a próxima atualização retoma daí"
             return "$MEOW_ERRO"; }
    else
      meow_erro "a atualização falhou — a máquina não ficou pela metade,"
      meow_erro "  o apt desfez o que não conseguiu; a próxima atualização retoma daí"
      return "$MEOW_ERRO"
    fi
    meow_ok "pacotes do sistema em dia"
    rc="$MEOW_DIVERGENTE"
  else
    meow_pula "sem apt nesta máquina"
  fi

  meow_passo "2/4 O resto (flatpak, cargo, pnpm…)"
  if _as_tem topgrade; then
    topgrade -y --no-retry --disable system || meow_aviso "topgrade terminou com pendência — a saída acima diz qual"
    rc="$MEOW_DIVERGENTE"
  else
    meow_pula "topgrade não está instalado"
  fi

  meow_passo "3/4 Programas em Rust"
  if _as_tem cargo-install-update; then
    cargo install-update -a || meow_aviso "alguma caixa não atualizou — a saída acima diz qual"
  else
    meow_pula "cargo-install-update não está instalado"
  fi

  meow_passo "4/4 O que a atualização desfez"
  meow_info "cada troca de pacote pode ter desfeito uma etapa nossa: o tema, os"
  meow_info "  ícones, o applet da barra, o mascote do terminal. O doctor diz quais."
  printf '\n'
  MEOW_DRY_RUN=1 "$MEOW_RAIZ/bin/meow" doctor
  local rcd=$?
  printf '\n'
  case "$rcd" in
    0) meow_ok "a atualização não desfez nada — o MeowSystem sobreviveu inteiro" ;;
    *) meow_muda "há etapa fora do lugar depois da atualização"
       local onde; onde="$(meow_onde_no_painel doctor_consertar)"
       meow_info "  o doctor refaz o que ficou fora do lugar na próxima passada${onde:+; no painel, $onde}"
       rc="$MEOW_DIVERGENTE" ;;
  esac

  meow_registrar "atualizar_sistema.sh aplicar rc=$rc doctor=$rcd"
  return "$rc"
}

AS_ARQUIVOS="${AS_ARQUIVOS:-/var/cache/apt/archives}"
AS_GUARDA_DEBS="${AS_GUARDA_DEBS:-${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/debs}"

_as_guardar_debs() {
  local p v arq n=0
  while IFS=$'\t' read -r p v; do
    arq="$(ls "$AS_ARQUIVOS/${p}_${v//:/%3a}_"*.deb 2>/dev/null | head -1)"
    [ -n "$arq" ] || continue
    if [ -f "$AS_GUARDA_DEBS/${arq##*/}" ]; then
      meow_ok "já guardado: ${arq##*/}"
      continue
    fi
    if meow_seco; then
      meow_muda "guardaria ${arq##*/} em $AS_GUARDA_DEBS antes do clean"; n=$((n+1)); continue
    fi
    mkdir -p "$AS_GUARDA_DEBS" && cp -f "$arq" "$AS_GUARDA_DEBS/" \
      && { meow_muda "guardado ${arq##*/} — a volta para trás do $p"; n=$((n+1)); } \
      || meow_aviso "não consegui guardar ${arq##*/}"
  done < <(dpkg-query -W -f='${Package}\t${Version}\t${db:Status-Status}\n' 'cosmic-*' 2>/dev/null |
           awk -F'\t' '$3=="installed" {print $1"\t"$2}')
  meow_seco || _as_podar_debs
  [ "$n" = "0" ] || return "$MEOW_DIVERGENTE"
  return "$MEOW_OK"
}

_as_podar_debs() {
  local p inst d
  [ -d "$AS_GUARDA_DEBS" ] || return 0
  for p in $(ls "$AS_GUARDA_DEBS" 2>/dev/null | sed -n 's/^\(cosmic-[^_]*\)_.*\.deb$/\1/p' | sort -u); do
    inst="$(dpkg-query -W -f='${Version}' "$p" 2>/dev/null)"
    ls "$AS_GUARDA_DEBS/${p}_"*.deb 2>/dev/null | grep -v -F "_${inst//:/%3a}_" | sort -V | head -n -1 |
      while IFS= read -r d; do rm -f "$d" && meow_info "podado da guarda: ${d##*/}"; done
  done
}

cmd_limpar() {
  if meow_seco; then
    _as_guardar_debs
    meow_muda "rodaria: apt autoclean, apt autoremove e apt clean"
    return "$MEOW_DIVERGENTE"
  fi
  _as_tem apt || { meow_pula "sem apt nesta máquina"; return "$MEOW_OK"; }
  meow_titulo "Limpar o que sobrou"
  _as_guardar_debs
  local antes depois
  antes="$(du -sm /var/cache/apt/archives 2>/dev/null | cut -f1)"
  if ! meow_ponte limpar; then
    sudo apt autoclean -y || true
    sudo apt autoremove "${APT_OPCOES[@]}" || true
    sudo apt clean || true
  fi
  depois="$(du -sm /var/cache/apt/archives 2>/dev/null | cut -f1)"
  if [ -n "$antes" ] && [ -n "$depois" ]; then
    meow_ok "cache do apt: ${antes} MB -> ${depois} MB"
  else
    meow_ok "cache do apt limpo"
  fi
  meow_registrar "atualizar_sistema.sh limpar"
  return "$MEOW_DIVERGENTE"
}

case "${1:-ver}" in
  ver)     cmd_ver ;;
  aplicar) cmd_aplicar ;;
  limpar)  cmd_limpar ;;
  *) meow_erro "uso: atualizar_sistema.sh {ver|aplicar|limpar}"; exit "$MEOW_ERRO" ;;
esac

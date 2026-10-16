#!/usr/bin/env bash
# cosmic_pos_apt.sh — depois de um apt, refaz em escopo de usuário o que o
# COSMIC novo desfez.
#
#   ./cosmic_pos_apt.sh           reconstrói o que mudou de versão, e conserta
#   ./cosmic_pos_apt.sh --seco    diz o que faria, sem escrever
#
# O CÓDIGO DE SAÍDA, PARA O SYSTEMD: 0 = sucesso (escrevendo ou não), 2 = algum
# passo falhou.
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

PA_VERSOES="${PA_VERSOES:-$MEOW_ESTADO/cosmic-versoes}"
# Os comandos de cada passo. Sobrescrevíveis para o teste trocar um build de
# meia hora por um registro de uma linha; nenhum vira chave do meow.conf.
PA_COMPOSITOR="${PA_COMPOSITOR:-$MEOW_RAIZ/scripts/compositor_patches.sh}"
PA_BUILDS="${PA_BUILDS:-$MEOW_RAIZ/scripts/garantir_builds.sh}"
PA_DOCTOR="${PA_DOCTOR:-$MEOW_RAIZ/bin/meow}"
PA_RUSTUP="${PA_RUSTUP:-rustup}"
PA_ORACULO="${PA_ORACULO:-$MEOW_RAIZ/scripts/oraculo_tema.sh}"
# O veredito do pré-voo (`meow cosmic prever`), gravado antes do apt.
PA_CANDIDATO="${PA_CANDIDATO:-$MEOW_ESTADO/cosmic-candidato.tsv}"

# O rustup põe o `cargo` e o `rustup` só ali, e quem os acha na sessão é o
# `~/.profile`, que o systemd não lê.
PA_CARGO_BIN="${CARGO_HOME:-$HOME/.cargo}/bin"
case ":$PATH:" in
  *":$PA_CARGO_BIN:"*) ;;
  *) [ -d "$PA_CARGO_BIN" ] && PATH="$PA_CARGO_BIN:$PATH" && export PATH ;;
esac

# pacote<TAB>versão dos `cosmic-*` instalados, ordenado.
_pa_instalados() {
  dpkg-query -W -f='${Package}\t${Version}\t${db:Status-Status}\n' 'cosmic-*' 2>/dev/null |
    awk -F'\t' '$3=="installed" && $2!="" {print $1"\t"$2}' | sort
}

# --- os passos: 0 = feito ou nada a fazer · outro = falhou, tenta de novo ---
# As duas guardas, só quando algum pacote mudou de versão (senão a passagem
# tem de sair sem escrever nada).
_pa_guardas() {
  local p algum=0
  for p in "$@"; do [ "${visto[$p]:-}" != "${novo[$p]}" ] && algum=1; done
  [ "$algum" = "1" ] || return 0
  if awk -F'\t' '$1=="toolchain" && $2=="vermelho" {achou=1} END {exit !achou}' "$PA_CANDIDATO" 2>/dev/null; then
    if meow_seco; then
      meow_muda "atualizaria o rust (rustup update): o pré-voo acusou o rustc abaixo do que o fonte novo pede"
    elif command -v "$PA_RUSTUP" >/dev/null 2>&1; then
      meow_info "o pré-voo acusou o rustc abaixo do que o fonte novo pede — rustup update"
      "$PA_RUSTUP" update >/dev/null 2>&1 || meow_aviso "o rustup update falhou — o build vai tentar com o rust de agora"
    fi
  fi
  [ -x "$PA_COMPOSITOR" ] && MEOW_DRY_RUN="${MEOW_SECO:-0}" "$PA_COMPOSITOR" guardar >/dev/null 2>&1
  return 0
}

passo_cosmic_settings() { # $1 versão
  meow_seco && { meow_muda "conferiria a derivação do tema do cosmic-settings $1 (e compilaria o oráculo se ela mudou)"; return 0; }
  "$PA_ORACULO" construir
  case $? in 0|1|3) return 0 ;; *) return 1 ;; esac
}

cmd_rodar() {
  local p v antigo mudou=0 falhou=0
  local -A visto=() novo=()
  meow_tem dpkg-query || { meow_pula "sem dpkg nesta máquina"; return "$MEOW_SEM_DEPENDENCIA"; }

  if [ -f "$PA_VERSOES" ]; then
    while IFS=$'\t' read -r p v; do [ -n "$p" ] && visto["$p"]="$v"; done < "$PA_VERSOES"
  fi
  while IFS=$'\t' read -r p v; do novo["$p"]="$v"; done < <(_pa_instalados)

  _pa_guardas "${novo[@]+"${!novo[@]}"}"

  local -a gravar=()
  for p in "${!novo[@]}"; do
    v="${novo[$p]}"; antigo="${visto[$p]:-}"
    if [ "$antigo" = "$v" ]; then gravar+=("$p"$'\t'"$v"); continue; fi
    mudou=1
    meow_info "$p: ${antigo:-<nunca visto>} -> $v"
    local rc=0
    case "$p" in
      cosmic-settings) passo_cosmic_settings "$v"; rc=$? ;;
    esac
    if [ "$rc" = "0" ]; then
      gravar+=("$p"$'\t'"$v")
    else
      falhou=1
      meow_aviso "$p $v: o passo falhou — tenta de novo no próximo apt"
      [ -n "$antigo" ] && gravar+=("$p"$'\t'"$antigo")
    fi
  done

  # OS BUILDS, SEMPRE — e depois dos passos por versão, com o rustc já
  # atualizado pela guarda e o fonte já guardado. Nada faltando, a função não
  # escreve um byte.
  local rc_b=0
  if meow_seco; then "$PA_BUILDS" --seco; rc_b=$?; else "$PA_BUILDS"; rc_b=$?; fi
  [ "$rc_b" = "1" ] && mudou=1
  [ "$rc_b" = "2" ] && falhou=1

  if [ "$mudou" = "0" ]; then
    meow_ok "nenhum pacote do COSMIC mudou de versão desde a última passagem"
    [ "$falhou" = "1" ] && return "$MEOW_ERRO"
    return "$MEOW_OK"
  fi
  meow_seco && return "$MEOW_DIVERGENTE"

  mkdir -p "${PA_VERSOES%/*}" || return "$MEOW_ERRO"
  local tmp; tmp="$(mktemp -p "${PA_VERSOES%/*}" .versoes.XXXXXX)" || return "$MEOW_ERRO"
  printf '%s\n' "${gravar[@]}" | sort > "$tmp" && mv -f "$tmp" "$PA_VERSOES"

  # O DOCTOR POR ÚLTIMO: ele conserta o que é nosso e não depende de build —
  # tema, ícones, a sombra órfã do applet —, e lê os artefatos que os passos
  # acabaram de deixar.
  "$PA_DOCTOR" doctor --consertar >/dev/null 2>&1
  meow_registrar "cosmic_pos_apt.sh falhou=$falhou"
  [ "$falhou" = "1" ] && return "$MEOW_ERRO"
  return "$MEOW_OK"
}

case "${1:-}" in
  ""|rodar) cmd_rodar ;;
  --seco)   MEOW_SECO=1; cmd_rodar ;;
  *) meow_erro "uso: cosmic_pos_apt.sh [--seco]"; exit "$MEOW_ERRO" ;;
esac

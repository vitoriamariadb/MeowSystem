#!/usr/bin/env bash
# cosmic_pos_apt.sh — depois de um apt, refaz em escopo de usuário o que o
# COSMIC novo desfez. Quem chama é o `meow-pos-apt.service`, disparado pelo
# `meow-pos-apt.path` quando o hook de apt (`scripts/99-meow-lancador`) toca
# `/var/lib/meowsystem/apt-mudou`.
#
#   ./cosmic_pos_apt.sh           reconstrói o que mudou de versão, e conserta
#   ./cosmic_pos_apt.sh --seco    diz o que faria, sem escrever
#
# O DESENHO (P76, `docs/pesquisas/2026-10-09-cosmic-vivo.md` §4.3)
#   O apt é dono de `/usr`; o meow é dono do escopo do usuário. A linha root do
#   hook só toca um arquivo — todo o trabalho é daqui, sem sudo:
#     1. compara a versão de cada `cosmic-*` com a última vista
#        (`~/.local/state/meowsystem/cosmic-versoes`). Nada mudou: sai sem
#        escrever um byte — é a idempotência que o teste cobra;
#     2. para cada pacote que mudou, roda o passo dele. Cada passo é
#        idempotente pelo critério do `files_menu`: artefato por versão, que só
#        se reconstrói se faltar;
#     3. termina com o `meow doctor --consertar`.
#   Um passo que FALHA não grava a versão nova do pacote dele: o próximo apt
#   (ou a próxima passagem) tenta de novo. Um passo que deu certo, ou que não
#   tem o que fazer nesta máquina, grava.
#
# OS PASSOS, um por pacote
#   cosmic-comp      o compositor em escopo de usuário (`meow compositor`), só
#                    com o shim ligado: sem ele o build não vale em sessão
#                    nenhuma, e meia hora de cargo para nada não é conserto;
#   cosmic-files     o menu de papel de parede (`files_menu.sh build`), se
#                    FILES_MENU não for "nao".
#
# E DUAS GUARDAS QUE VALEM ANTES DE QUALQUER PASSO (P76, tarefa 5)
#   - o rustc: se o pré-voo acusou toolchain vermelho (o fonte novo pede um
#     rust mais novo que o instalado), `rustup update` antes do build. O
#     `~/.cargo` é dela, sem sudo; sem isso o build só falharia e contaria a
#     tentativa;
#   - o fonte: o que o cache antigo do compositor guardava vai para
#     `~/.local/share/meowsystem/fontes/` (`compositor_patches.sh guardar`).
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

PA_VERSOES="${PA_VERSOES:-$MEOW_ESTADO/cosmic-versoes}"
PA_CASA="${PA_CASA:-$HOME/.local/libexec/meow/cosmic-comp}"
# Os comandos de cada passo. Sobrescrevíveis para o teste trocar um build de
# meia hora por um registro de uma linha; nenhum vira chave do meow.conf.
PA_COMPOSITOR="${PA_COMPOSITOR:-$MEOW_RAIZ/scripts/compositor_patches.sh}"
PA_FILES="${PA_FILES:-$MEOW_RAIZ/scripts/files_menu.sh}"
PA_DOCTOR="${PA_DOCTOR:-$MEOW_RAIZ/bin/meow}"
PA_RUSTUP="${PA_RUSTUP:-rustup}"
# O veredito do pré-voo (`meow cosmic prever`), gravado antes do apt.
PA_CANDIDATO="${PA_CANDIDATO:-$MEOW_ESTADO/cosmic-candidato.tsv}"

# pacote<TAB>versão dos `cosmic-*` instalados, ordenado.
_pa_instalados() {
  dpkg-query -W -f='${Package}\t${Version}\t${db:Status-Status}\n' 'cosmic-*' 2>/dev/null |
    awk -F'\t' '$3=="installed" && $2!="" {print $1"\t"$2}' | sort
}

# --- os passos: 0 = feito ou nada a fazer · outro = falhou, tenta de novo ---
passo_cosmic_comp() { # $1 versão
  if ! grep -qs MEOW-COSMIC-COMP-SHIM "$HOME/.local/bin/cosmic-comp"; then
    meow_pula "cosmic-comp $1: o shim do compositor está desligado — sem build (meow compositor ativar liga)"
    return 0
  fi
  if [ -f "$PA_CASA/$1/estado" ]; then
    meow_ok "cosmic-comp $1: o build desta versão já existe"
    return 0
  fi
  meow_seco && { meow_muda "compilaria o cosmic-comp $1 em escopo de usuário"; return 0; }
  "$PA_COMPOSITOR" compilar
  case $? in 0|1) return 0 ;; *) return 1 ;; esac
}

passo_cosmic_files() { # $1 versão
  local quer; quer="$(meow_conf_valor FILES_MENU 2>/dev/null)" || quer="sim"
  [ "$quer" = "sim" ] || { meow_pula "cosmic-files $1: FILES_MENU=\"$quer\" — menu de fábrica"; return 0; }
  meow_seco && { meow_muda "construiria o menu de papel de parede do cosmic-files $1"; return 0; }
  FILES_MENU=sim "$PA_FILES" build
  case $? in 0|1) return 0 ;; *) return 1 ;; esac
}

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
      cosmic-comp)  passo_cosmic_comp "$v";  rc=$? ;;
      cosmic-files) passo_cosmic_files "$v"; rc=$? ;;
    esac
    if [ "$rc" = "0" ]; then
      gravar+=("$p"$'\t'"$v")
    else
      falhou=1
      meow_aviso "$p $v: o passo falhou — tenta de novo no próximo apt"
      [ -n "$antigo" ] && gravar+=("$p"$'\t'"$antigo")
    fi
  done

  if [ "$mudou" = "0" ]; then
    meow_ok "nenhum pacote do COSMIC mudou de versão desde a última passagem"
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
  return "$MEOW_DIVERGENTE"
}

case "${1:-}" in
  ""|rodar) cmd_rodar ;;
  --seco)   MEOW_SECO=1; cmd_rodar ;;
  *) meow_erro "uso: cosmic_pos_apt.sh [--seco]"; exit "$MEOW_ERRO" ;;
esac

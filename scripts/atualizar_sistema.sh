#!/usr/bin/env bash
# atualizar_sistema.sh — atualiza a máquina inteira e prova que o MeowSystem
# sobreviveu.
#
# POR QUE ISTO É UM SCRIPT DESTE PROJETO, E NÃO UM ALIAS NO ZSH DELA
#   Ela já tem o comando, e ele é uma linha só:
#
#     sudo apt update && sudo apt full-upgrade -y && topgrade -y \
#       && sudo apt autoclean -y && sudo apt autoremove -y \
#       && cargo install cargo-update --force && limpar_cache \
#       && cargo-install-update-config
#
#   O que falta nessa linha é a SEGUNDA METADE do problema. Um `full-upgrade`
#   troca o `cosmic-comp`, o `cosmic-panel`, o `fastfetch`, o `papirus-icon-
#   theme` — e cada uma dessas trocas desfaz alguma coisa que este projeto
#   escreveu. É a razão de o projeto existir: o `meow doctor` sabe dizer o que
#   saiu do lugar, mas ninguém se lembra de rodá-lo logo depois de uma
#   atualização de meia hora.
#
#   Aqui as duas metades ficam grudadas: atualiza, e em seguida CONFERE o que a
#   atualização desfez — e conserta, se ela pedir. A frase dela foi *"conferir a
#   idempotência do app como um todo, se sobreviveríamos a um [upgrade], que é a
#   ideia do projeto também"*.
#
# O QUE ELE NÃO FAZ
#   Não decide por ela. `ver` não escreve um byte e é o padrão; `aplicar` é o
#   que mexe, e o painel o marca como ação que pede senha e pede confirmação.
#   E ele NUNCA responde a um prompt de conflito de arquivo de configuração do
#   `dpkg`: as opções abaixo mandam o apt MANTER o que está no disco e listar o
#   que ficou pendente. Escolher por ela num `.conf` do sistema seria trocar uma
#   pergunta de dez segundos por um estrago silencioso.
#
# AS PEÇAS, E POR QUE CADA UMA
#   apt update / full-upgrade   os pacotes do sistema. `full-upgrade` e não
#                               `upgrade`: o Pop!_OS move pacotes entre metas e
#                               o `upgrade` os segura para trás.
#   topgrade                    o resto — flatpak, cargo, pnpm, o que houver.
#   apt autoclean / autoremove  o que sobrou. Separado, no `limpar`.
#   cargo install-update -a     as caixas de Rust instaladas por ela.
#
#   `snap` não entra: não está instalado nesta máquina (medido em 06/09/2026).
#
# USO
#   atualizar_sistema.sh ver        o que mudaria. Não escreve, não pede senha.
#   atualizar_sistema.sh aplicar    atualiza e confere o MeowSystem depois.
#   atualizar_sistema.sh limpar     autoclean, autoremove e cache do apt.

set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# O apt NUNCA PERGUNTA E NUNCA DECIDE. `--force-confold` mantém o arquivo que
# está no disco quando o pacote traz um novo; `--force-confdef` só aceita o
# padrão quando NÃO há versão dela. Sem os dois, um `-y` em terminal sem tty
# pode aceitar o arquivo do pacote e apagar configuração dela em silêncio.
APT_OPCOES=(-y -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef)

_as_tem() { command -v "$1" >/dev/null 2>&1; }

# --- o que mudaria ----------------------------------------------------------
cmd_ver() {
  local n=0
  meow_titulo "O que a atualização mudaria"

  meow_passo "1/3 Pacotes do sistema"
  if _as_tem apt; then
    # `apt update` escreve na lista do apt, que é cache, não configuração — mas
    # ele pede senha, e `ver` promete não pedir. Então lê o que já está lido.
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

  meow_passo "2/3 Caixas de Rust"
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

# --- a atualização ----------------------------------------------------------
cmd_aplicar() {
  local rc="$MEOW_OK"

  if meow_seco; then
    meow_titulo "Atualizar a máquina (ensaio)"
    meow_muda "rodaria: apt update && apt full-upgrade"
    _as_tem topgrade && meow_muda "rodaria: topgrade"
    _as_tem cargo-install-update && meow_muda "rodaria: cargo install-update -a"
    meow_muda "e depois: meow doctor, para ver o que a atualização desfez"
    return "$MEOW_DIVERGENTE"
  fi

  meow_titulo "Atualizar a máquina"

  meow_passo "1/4 Pacotes do sistema"
  if _as_tem apt; then
    # PELA PONTE, SEM SENHA — 08/09/2026. É o que faz o botão "Atualizar a
    # máquina inteira" do painel funcionar: ele roda sem terminal, e um prompt
    # de senha ali nunca chegava a lugar nenhum. O verbo `atualizar` da ponte é
    # `apt update` + `full-upgrade` dos repositórios JÁ configurados — ela não
    # instala pacote por nome nem acrescenta fonte.
    # `rc_ponte` NUM `local` PRÓPRIO, e não `$?` no `elif`: ali ele já é o
    # status do teste anterior em alguns caminhos, e o 127 ("não há ponte") é
    # justamente o que precisa sobreviver intacto para escolher o outro caminho.
    local rc_ponte=0
    meow_ponte atualizar || rc_ponte=$?
    if [ "$rc_ponte" = "0" ]; then
      : # feito pela ponte
    elif [ "$rc_ponte" = "127" ]; then
      # Sem ponte: o caminho de sempre, que pede senha no terminal.
      sudo apt update || { meow_erro "apt update falhou"; return "$MEOW_ERRO"; }
      sudo apt full-upgrade "${APT_OPCOES[@]}" \
        || { meow_erro "apt full-upgrade falhou — a máquina não ficou pela metade,"
             meow_erro "  o apt desfaz o que não conseguiu; rode 'sudo apt -f install'"
             return "$MEOW_ERRO"; }
    else
      meow_erro "a atualização falhou — a máquina não ficou pela metade,"
      meow_erro "  o apt desfaz o que não conseguiu; rode 'sudo apt -f install'"
      return "$MEOW_ERRO"
    fi
    meow_ok "pacotes do sistema em dia"
    rc="$MEOW_DIVERGENTE"
  else
    meow_pula "sem apt nesta máquina"
  fi

  meow_passo "2/4 O resto (flatpak, cargo, pnpm…)"
  if _as_tem topgrade; then
    # O topgrade já pula o que não existe e já sabe do apt; aqui ele entra pelo
    # resto. `--no-retry` porque um passo que falha duas vezes falha as duas.
    topgrade -y --no-retry --disable system || meow_aviso "topgrade terminou com pendência — a saída acima diz qual"
    rc="$MEOW_DIVERGENTE"
  else
    meow_pula "topgrade não está instalado"
  fi

  meow_passo "3/4 Caixas de Rust"
  if _as_tem cargo-install-update; then
    cargo install-update -a || meow_aviso "alguma caixa não atualizou — a saída acima diz qual"
  else
    meow_pula "cargo-install-update não está instalado"
  fi

  # --- E AQUI COMEÇA A PARTE QUE SÓ ESTE PROJETO FAZ ------------------------
  meow_passo "4/4 O que a atualização desfez"
  meow_info "cada troca de pacote pode ter desfeito uma etapa nossa: o tema, os"
  meow_info "  ícones, o applet da barra, o gato do terminal. O doctor diz quais."
  printf '\n'
  MEOW_DRY_RUN=1 "$MEOW_RAIZ/bin/meow" doctor
  local rcd=$?
  printf '\n'
  case "$rcd" in
    0) meow_ok "a atualização não desfez nada — o MeowSystem sobreviveu inteiro" ;;
    *) meow_muda "há etapa fora do lugar depois da atualização"
       meow_info "  conserte com:  meow doctor --consertar"
       meow_info "  (ou pelo painel, em \"Instalar e conferir\")"
       rc="$MEOW_DIVERGENTE" ;;
  esac

  meow_registrar "atualizar_sistema.sh aplicar rc=$rc doctor=$rcd"
  return "$rc"
}

# --- a limpeza --------------------------------------------------------------
cmd_limpar() {
  if meow_seco; then
    meow_muda "rodaria: apt autoclean, apt autoremove e apt clean"
    return "$MEOW_DIVERGENTE"
  fi
  _as_tem apt || { meow_pula "sem apt nesta máquina"; return "$MEOW_OK"; }
  meow_titulo "Limpar o que sobrou"
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

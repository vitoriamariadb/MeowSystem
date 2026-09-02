#!/usr/bin/env bash
# apos_flatpak.sh — o braço do gatilho de flatpak: reaplica O QUE É DA BANDEJA
#                   depois de todo `flatpak install/update/uninstall`.
#
# Fonte-de-verdade: MeowSystem/scripts/apos_flatpak.sh
# Quem chama:       systemd/meow-flatpak.service, disparado pelo
#                   systemd/meow-flatpak.path
# Quem instala:     install.sh, `etapa_vigia_flatpak` (via scripts/vigia_flatpak.sh)
#
# ============================================================================
# O BURACO QUE ISTO FECHA, COM A DATA E A HORA
# ============================================================================
#
# Queixa dela, 23/08/2026: "ao atualizar o flatpak tipo zap zap, o tray, o icon
# que fica no applet, voltaram aos originais."
#
# O `assets/icones/bandeja.map` já tinha ESCRITO que isso ia acontecer, em 10/08:
# "Um `flatpak update com.rtosta.zapzap` devolve o arquivo de fábrica e o ícone
# volta a destoar, SEM NADA ACUSANDO." O `flatpak history` diz quando foi:
#
#   ago 20 03:30:36   deploy update   com.rtosta.zapzap   stable   user
#
# Havia a previsão e não havia o gatilho. Este é o gatilho.
#
# ============================================================================
# POR QUE UM SCRIPT, E NÃO DUAS LINHAS `ExecStart=` NA UNIDADE
# ============================================================================
#
# Duas `ExecStart=` num `Type=oneshot` rodam em sequência, mas o estado final da
# unidade é o da ÚLTIMA — e o contrato deste projeto usa o código de saída para
# dizer "consertei alguma coisa" (1) versus "estava tudo certo" (0). Com duas
# linhas, um ZapZap revestido (1) seguido de uma bandeja já correta (0) sairia
# como 0, e a notificação dela nunca apareceria justamente na vez que importava.
#
# Aqui os códigos são DOBRADOS, com a regra "o pior vence, mas 3 não estraga":
#
#   2 (erro)          vence tudo — alguma coisa quebrou e precisa de olho
#   1 (consertei)     vence 0 e 3 — houve escrita, e é isso que a notificação diz
#   3 (sem o alvo)    só sobrevive se TODOS forem 3 — numa máquina sem ZapZap e
#                     sem acervo não há o que fazer, e isso não é falha
#   0                 todos já estavam certos
#
# `SuccessExitStatus=1 3` na unidade é o outro lado deste acordo: sem ele o
# systemd marcaria a unidade como `failed` toda vez que ela CONSERTASSE algo, e
# depois de cinco consertos o `StartLimitBurst` desligaria o vigia.
#
# ============================================================================
# O QUE ENTRA AQUI, E O QUE NÃO ENTRA
# ============================================================================
#
# ENTRA só o que um `flatpak install/update` tem como desfazer, e só na bandeja:
#
#   icones_tray_zapzap.sh   O flatpak update TROCA A ÁRVORE DE DEPLOY inteira —
#                           diretório de commit novo, arquivos novos, hardlinks
#                           novos do OSTree. Tudo que estava escrito lá dentro
#                           some. É o caso dela.
#
#   icones_bandeja.sh       Escreve em `~/.local/share/icons/MeowSystem-Icons/`,
#                           que o flatpak NÃO toca. Entra assim mesmo por um
#                           motivo medido: `~/.local/share/flatpak/exports/share`
#                           está no `XDG_DATA_DIRS` desta máquina (ver
#                           docs/FRONTEIRA.md:145), e um app novo pode chegar
#                           trazendo `assets/icones/hicolor/...` com um nome que a
#                           bandeja resolve. É barato — o script compara por
#                           conteúdo e não escreve nada quando está tudo certo.
#
#   nomes_apps.sh --so-flatpak
#   aplicar_apps.sh (só zapzap e spotify)
#                           OS DOIS ENTRARAM EM 02/09/2026, E O MOTIVO É UMA
#                           MEDIÇÃO QUE CONTRADIZ O BLOCO LOGO ABAIXO.
#
#                           Queixa dela, 02/09/2026: "o icon do wpp voltou ao
#                           default dele". O `flatpak history` diz quando:
#
#                             set  2 15:23:34  deploy update  org.gimp.GIMP
#                             set  2 15:24:09  deploy update  com.rtosta.zapzap
#
#                           O bloco "POR QUE O LANCADOR TAMBEM ENTRA" (mais
#                           abaixo) mediu, em 23/08, que um update NÃO desfaz o
#                           ícone do lançador — e aquilo continua verdade PARA O
#                           TEMA DE ÍCONES. Só que o ZapZap não é vestido pelo
#                           tema sozinho: o `assets/temas-de-apps/zapzap/manifesto.sh`
#                           SUBSTITUI o symlink de export por um arquivo real, e
#                           é esse arquivo que diz `Icon=meow-whatsapp` e
#                           `Name=WhatsApp`. O deploy recria o symlink, o
#                           `Icon=` volta a `com.rtosta.zapzap`, e o glifo de
#                           traço fica no disco sem nome que o alcance. O mesmo
#                           vale para o `Name=` curto do GIMP.
#
#                           O `meow-doctor.timer` das 05:00 consertaria — no dia
#                           seguinte. Ela viu em quatro horas, que é a distância
#                           entre o update e a queixa. O gatilho de evento existe
#                           justamente para essa janela.
#
#                           O `aplicar_apps.sh` entra RESTRITO a dois slugs, e
#                           não com o `APPS_ATIVOS` inteiro: só o `zapzap` e o
#                           `spotify` escrevem DENTRO da árvore de deploy do
#                           flatpak (o spicetify reescreve `Apps/xpui` em
#                           `~/.local/share/flatpak/app/com.spotify.Client/…`).
#                           Os outros cinco módulos moram em `~/.config` e em
#                           `~/.var/app/…/config`, que o deploy não toca — rodá-los
#                           aqui seria trabalho no evento errado.
#
# NÃO ENTRA o tema inteiro. Um `flatpak update` do Calculator não é motivo para
# reconstruir 1.200 ícones, remontar o `index.theme` e reescrever o tema do
# COSMIC. Quem faz a passagem completa é o `meow-doctor.timer`, às 5h, uma vez
# por dia — e essa divisão é deliberada: gatilho de EVENTO faz o mínimo que o
# evento desfez; gatilho de RELÓGIO faz a varredura.
#
# NÃO ENTRA a Steam (`icones_tray_steam.sh`). Quem desfaz aquele arquivo é a
# auditoria do próprio cliente Steam (`BVerifyInstalledFiles`, medido em 10/08),
# que não tem relação nenhuma com flatpak — a Steam desta máquina vem do apt.
# Pendurá-lo aqui seria trabalho no evento errado.
#
# ============================================================================
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 tudo já estava certo · 1 algo divergia e foi consertado · 2 erro
#   3 nada aplicável nesta máquina
# ============================================================================
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

CONFERIR=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

# A dobra. `pior` começa em -1 = "ninguém falou ainda", que é diferente de 0.
pior=-1
_dobrar() {
  local rc="$1"
  case "$rc" in
    2) pior=2 ;;
    1) [ "$pior" = 2 ] || pior=1 ;;
    0) case "$pior" in 2|1) ;; *) pior=0 ;; esac ;;
    3) [ "$pior" = -1 ] && pior=3 ;;
    *) pior=2 ;;
  esac
}

_rodar() {
  local script="$1"; shift
  if [ ! -x "$RAIZ/scripts/$script" ]; then
    meow_aviso "falta $RAIZ/scripts/$script — repositório incompleto"
    _dobrar 2
    return
  fi
  local arg=--aplicar
  [ "$CONFERIR" = 1 ] && arg=--conferir
  # O que sobrar em "$@" vai JUNTO do verbo — é assim que o `nomes_apps.sh`
  # recebe o `--so-flatpak` sem precisar de um segundo executor aqui.
  set -- "$arg" "$@"
  # FLAVOR e ICONES_COR_MARCA so interessam ao `icones_apps_arcticons.sh`; passar
  # para todos e inofensivo (os outros ignoram) e evita um segundo `_rodar` so
  # para ele — dois caminhos de invocacao e o que se esquece de atualizar.
  ICONES_TEMA="${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
    FLAVOR="${FLAVOR:-}" \
    ICONES_COR_MARCA="${ICONES_COR_MARCA:-nao}" \
    "$RAIZ/scripts/$script" "$@"
  _dobrar $?
}

_rodar icones_tray_zapzap.sh
_rodar icones_bandeja.sh
# ============================================================================
# POR QUE O LANCADOR TAMBEM ENTRA, se ele ja sobrevive ao update
# ============================================================================
#   Medido em 23/08/2026 com o resolvedor real (`Gtk.IconTheme.lookup_icon`, tema
#   MeowSystem-Icons): um `flatpak update` NAO desfaz o icone do lancador. O
#   flatpak exporta `org.telegram.desktop.png` para
#   `~/.local/share/flatpak/exports/share/icons/hicolor/`, mas `hicolor` e o
#   ULTIMO elo da heranca e o nosso `48x48/apps/*.svg` vence:
#
#     org.telegram.desktop  48px -> .../MeowSystem-Icons/48x48/apps/…svg
#     meow-whatsapp         48px -> .../MeowSystem-Icons/48x48/apps/…svg
#
#   Ele entra assim mesmo por UM motivo que a bandeja nao cobre: um flatpak
#   INSTALADO agora e um nome de icone que ainda nao existe no nosso tema. Sem
#   esta linha ele fica com a arte de fabrica ate o `meow-doctor.timer` do dia
#   seguinte. A passagem custa uma leitura quando nao ha o que fazer (rc=0).
_rodar icones_apps_arcticons.sh

# ============================================================================
# O `.desktop` DE EXPORT — O QUE O DEPLOY REALMENTE DESFAZ (02/09/2026)
# ============================================================================
# O bloco acima trata do TEMA de ícones, que sobrevive ao update. Estes dois
# tratam dos arquivos que o próprio deploy reescreve: o `Name=` curto e, no caso
# do ZapZap, o `Icon=meow-whatsapp` que faz o glifo de traço alcançar o app.
# O porquê está no cabeçalho.
_rodar nomes_apps.sh --so-flatpak

# --- os módulos de app que moram na árvore do flatpak -----------------------
# `APPS_ATIVOS` é a lista dela, e a unidade do systemd não a exporta (ela exporta
# só FLAVOR/ACCENT/NOME_TEMA_ICONES/ICONES_COR_MARCA). Ler a chave direto do
# arquivo é de propósito: dar `source` no meow.conf inteiro aqui sobrescreveria
# justamente as variáveis que a unidade acabou de passar.
if [ -z "${APPS_ATIVOS:-}" ] && [ -f "$HOME/.config/meow/meow.conf" ]; then
  APPS_ATIVOS="$(sed -n 's/^[[:space:]]*APPS_ATIVOS=//p' "$HOME/.config/meow/meow.conf" \
                 | tail -n 1 | tr -d '"'\''')"
fi

# A interseção com a lista dela: um slug desligado no meow.conf continua
# desligado aqui. Sem isto, o gatilho tematizaria um app que ela mandou deixar em
# paz — e um gatilho que desobedece à configuração é pior que gatilho nenhum.
_flatpak_apps=""
for _slug in zapzap spotify; do
  case ",${APPS_ATIVOS:-}," in
    *",$_slug,"*) _flatpak_apps="${_flatpak_apps:+$_flatpak_apps,}$_slug" ;;
  esac
done

if [ -n "$_flatpak_apps" ] && [ -x "$RAIZ/scripts/aplicar_apps.sh" ]; then
  _acao=aplicar
  [ "$CONFERIR" = 1 ] && _acao=conferir
  APPS_ATIVOS="$_flatpak_apps" "$RAIZ/scripts/aplicar_apps.sh" "$_acao"
  _dobrar $?
elif [ -n "$_flatpak_apps" ]; then
  meow_aviso "falta $RAIZ/scripts/aplicar_apps.sh — repositório incompleto"
  _dobrar 2
fi

case "$pior" in
  -1|3) exit "$MEOW_SEM_DEPENDENCIA" ;;
  *)    exit "$pior" ;;
esac

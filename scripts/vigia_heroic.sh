#!/usr/bin/env bash
# vigia_heroic.sh — liga (ou desliga) o gatilho que acerta os atalhos de jogo do
#                   Heroic sozinho, assim que a biblioteca dele muda.
#
#   ./vigia_heroic.sh              instala as unidades e liga o vigia
#   ./vigia_heroic.sh --conferir   não escreve; 1 se algo divergir
#
# POR QUE ISTO EXISTE
#   Pedido dela, 10/09/2026: "o ponto é que qualquer jogo que eu instalar quero
#   que automaticamente isso se corrija". O `scripts/jogos_heroic.sh` já sabe
#   escrever e limpar; o que faltava era alguém CHAMÁ-LO na hora. Sem o gatilho,
#   um jogo instalado às 3h da tarde só apareceria no lançador na passagem
#   seguinte do `meow doctor` — às 5h da manhã do dia seguinte.
#
#   O cabeçalho de `systemd/meow-heroic.path` traz o resto: por que o evento são
#   os arquivos do `store_cache` (e não a pasta, nem o `installed.json` do
#   backend) e por que os dois prefixos de configuração estão lá.
#
# É O IRMÃO GÊMEO DO `vigia_steam.sh`, DE PROPÓSITO
#   Mesma estrutura, mesmos códigos de saída, mesma divisão `_desligar`/
#   `_conferir`/`_aplicar` — e pelo mesmo motivo que aquele dá: o `meow doctor`
#   precisa da MESMA verificação e o `--consertar` do MESMO conserto, então a
#   regra mora num lugar só. As duas unidades vão por CÓPIA byte a byte (elas
#   resolvem tudo com `%h`, sem marcador a substituir).
#
# DESLIGAR TEM DE DESLIGAR
#   Deixar de instalar não é desligar: a unidade que uma execução anterior ligou
#   continuaria vigiando depois de ela escrever HEROIC_VIGIA="nao" no meow.conf.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta dependência
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ORIGEM="$RAIZ/systemd"
DESTINO="$HOME/.config/systemd/user"
UNIDADES=(meow-heroic.service meow-heroic.path)
GATILHO="meow-heroic.path"

VIGIA="${HEROIC_VIGIA:-sim}"

CONFERIR=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

_texto_de() { cat "$ORIGEM/$1" 2>/dev/null; }

_tem_systemd() {
  meow_tem systemctl && [ -d "/run/user/$(id -u)/systemd" ]
}

_ligado() {
  [ "$(systemctl --user is-enabled "$GATILHO" 2>/dev/null)" = "enabled" ] &&
  [ "$(systemctl --user is-active  "$GATILHO" 2>/dev/null)" = "active" ]
}

# --- desligado: o que existe tem de SAIR -------------------------------------
_desligar() {
  local u restos=0
  for u in "${UNIDADES[@]}"; do [ -f "$DESTINO/$u" ] && restos=$((restos + 1)); done

  if [ "$restos" = 0 ]; then
    meow_pula "vigia do Heroic desligado (HEROIC_VIGIA=\"$VIGIA\")"
    return "$MEOW_OK"
  fi
  if [ "$CONFERIR" = 1 ]; then
    meow_muda "HEROIC_VIGIA=\"$VIGIA\" mas o vigia continua instalado — removeria $restos unidade(s)"
    return "$MEOW_DIVERGENTE"
  fi
  _tem_systemd && systemctl --user disable --now "$GATILHO" >/dev/null 2>&1
  for u in "${UNIDADES[@]}"; do rm -f "$DESTINO/$u"; done
  _tem_systemd && systemctl --user daemon-reload >/dev/null 2>&1
  meow_muda "HEROIC_VIGIA=\"$VIGIA\" — vigia do Heroic desligado e removido"
  return "$MEOW_DIVERGENTE"
}

# --- as dependências ---------------------------------------------------------
_pronto() {
  local u
  for u in "${UNIDADES[@]}"; do
    if [ ! -f "$ORIGEM/$u" ]; then
      meow_erro "falta $ORIGEM/$u — repositório incompleto"
      return "$MEOW_ERRO"
    fi
  done
  # A pergunta é pela PASTA DE CONFIGURAÇÃO, e não pelo binário: é o mesmo
  # critério do `jogos_heroic.sh`, que se pula sozinho quando ela não existe. Um
  # Heroic instalado e nunca aberto não tem biblioteca a vigiar.
  if [ ! -d "$HOME/.var/app/com.heroicgameslauncher.hgl/config/heroic" ] &&
     [ ! -d "${XDG_CONFIG_HOME:-$HOME/.config}/heroic" ]; then
    meow_pula "Heroic não instalado (ou nunca aberto) — nada a vigiar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _tem_systemd; then
    meow_aviso "não há systemd --user nesta sessão — o vigia do Heroic fica de fora"
    meow_info "  os atalhos de jogo continuam sendo revistos pelo meow-doctor.timer, às 5h"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- conferir ----------------------------------------------------------------
_conferir() {
  local u texto divergentes=0
  for u in "${UNIDADES[@]}"; do
    texto="$(_texto_de "$u")" || { meow_erro "não consegui ler $ORIGEM/$u"; return "$MEOW_ERRO"; }
    if [ ! -f "$DESTINO/$u" ] || [ "$texto" != "$(cat "$DESTINO/$u" 2>/dev/null)" ]; then
      divergentes=$((divergentes + 1))
    fi
  done

  if [ "$divergentes" != 0 ]; then
    meow_muda "vigia do Heroic: $divergentes unidade(s) a instalar ou atualizar"
    return "$MEOW_DIVERGENTE"
  fi
  if [ "$(systemctl --user is-failed "$GATILHO" 2>/dev/null)" = "failed" ]; then
    meow_muda "o $GATILHO está FALHO — provavelmente estourou o StartLimit"
    meow_info "  o conserto faz 'systemctl --user reset-failed' e religa"
    return "$MEOW_DIVERGENTE"
  fi
  if ! _ligado; then
    meow_muda "as unidades estão no lugar, mas o $GATILHO não está ligado"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "vigiando o Heroic — jogo instalado entra no lançador sozinho"
  return "$MEOW_OK"
}

# --- aplicar -----------------------------------------------------------------
_aplicar() {
  local u texto mudou=0 estado="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"

  # O diretório do log tem de existir ANTES de a unidade subir: o
  # `StandardOutput=append:` é montado antes de qualquer comando do serviço, e
  # sem ele a unidade morre com `status=209/STDOUT`. Medido em 05/08/2026, na
  # primeira unidade `.path` do projeto.
  if ! mkdir -p "$estado"; then
    meow_erro "não consegui criar $estado (é lá que fica o log do vigia)"
    return "$MEOW_ERRO"
  fi

  for u in "${UNIDADES[@]}"; do
    texto="$(_texto_de "$u")" || { meow_erro "não consegui ler $ORIGEM/$u"; return "$MEOW_ERRO"; }
    meow_escrever "$DESTINO/$u" "$texto" 644
    case $? in
      1) mudou=1 ;;
      2) meow_erro "não consegui instalar $u"; return "$MEOW_ERRO" ;;
    esac
  done

  [ "$mudou" = 1 ] && systemctl --user daemon-reload

  # Um estouro do StartLimit deixa a unidade em `failed`, e nesse estado o
  # `enable --now` não a levanta. Limpar antes é o que faz o `--consertar` de
  # fato consertar, em vez de dizer que consertou.
  if [ "$(systemctl --user is-failed "$GATILHO" 2>/dev/null)" = "failed" ]; then
    systemctl --user reset-failed "$GATILHO" meow-heroic.service >/dev/null 2>&1
    mudou=1
  fi

  if ! _ligado; then
    if ! systemctl --user enable --now "$GATILHO" >/dev/null 2>&1; then
      meow_erro "não consegui ligar o $GATILHO"
      return "$MEOW_ERRO"
    fi
    mudou=1
  fi

  if [ ! -f "$estado/raiz" ]; then
    meow_aviso "o vigia está ligado, mas $estado/raiz ainda não existe"
    meow_info "  até ele aparecer, cada disparo é pulado (o journal diz o motivo)"
  fi

  if [ "$mudou" = 0 ]; then
    meow_ok "vigia do Heroic já ligado"
    return "$MEOW_OK"
  fi
  meow_ok "vigia ligado: instalou um jogo no Heroic, o atalho entra no lançador em menos de um minuto"
  return "$MEOW_DIVERGENTE"
}

main() {
  [ "$VIGIA" = "sim" ] || { _desligar; return $?; }
  _pronto || return $?
  if [ "$CONFERIR" = 1 ]; then _conferir; else _aplicar; fi
}

main "$@"

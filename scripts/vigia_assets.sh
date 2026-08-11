#!/usr/bin/env bash
# vigia_assets.sh — liga (ou desliga) o vigia que faz `assets/gatos/` responder
# na hora, em vez de esperar a volta do `meow-logo.timer`.
#
#   ./vigia_assets.sh              instala as unidades e liga o vigia
#   ./vigia_assets.sh --conferir   não escreve; 1 se algo divergir
#
# POR QUE ISTO EXISTE
#   Pedido dela em 05/08/2026: "o comando do meow tem que disparar em automático,
#   talvez no self heal algo assim". O acervo de gatos JÁ era a interface — soltar
#   um SVG em `assets/gatos/` o põe na rotação —, mas o efeito só chegava ao disco
#   na volta seguinte do relógio, que hoje é de um dia. O par
#   `meow-assets.path` + `meow-assets.service` fecha essa distância.
#
# POR QUE UM SCRIPT, E NÃO A LÓGICA DENTRO DO install.sh
#   Porque o `meow doctor` precisa da MESMA verificação, e o `--consertar` precisa
#   do MESMO conserto. É o desenho que `icones_mimetypes.sh` e `icones_sistema.sh`
#   já seguem: o `install.sh` chama, o `bin/meow` chama com `--conferir` e com
#   `--aplicar`, e a regra mora num lugar só. Duplicá-la no `bin/meow` seria a
#   segunda verdade que ninguém atualiza.
#
# POR QUE NÃO NO SELF-HEAL DO RITUAL DA AURORA
#   Ela sugeriu "talvez no self heal". O Aurora é de OUTRO projeto, roda como root
#   e ela pode desligá-lo — e nesse dia o gato pararia de entrar sozinho sem nada
#   dizer por quê. A unidade é do MeowSystem; quem liga e desliga é o `meow.conf`.
#
# O MARCADOR `@ACERVO@`
#   O `meow-assets.path` é a única unidade deste projeto que NÃO pode ir por cópia
#   byte a byte: o diretório vigiado é o do repositório, em /mnt/Apate, e o systemd
#   não tem especificador para "onde está o clone" (`%h` só resolve o HOME). A
#   troca acontece aqui, antes de gravar — e por isso a CONFERÊNCIA tem de fazer a
#   mesma troca antes de comparar, ou a unidade divergiria eternamente.
#
#   E POR ISSO O CAMINHO AQUI É O FÍSICO, `pwd -P`. Esta máquina tem
#   `~/Desenvolvimento/MeowSystem` como link simbólico para `/mnt/Apate/...`, e o
#   `pwd` lógico devolve o caminho pelo qual o script FOI CHAMADO. Medido em
#   10/08/2026: chamado de /mnt/Apate o `--conferir` dizia `ok`, e chamado do
#   link dizia "1 unidade(s) a instalar ou atualizar" — a mesma máquina, o mesmo
#   disco, duas respostas. Pior que o barulho: aplicar pelo link reescreveria o
#   `PathModified=` com o caminho do link, e o vigia passaria a depender de um
#   symlink que ninguém prometeu manter. O acervo é UM só; o nome dele também.
#
# COMPARAR DO MESMO JEITO QUE SE ESCREVE
#   `meow_escrever` grava com `printf '%s'`, que come o `\n` final. Comparar com
#   `cmp` byte a byte acusaria divergência para sempre num arquivo perfeito — já
#   custou a este projeto um `--conferir` gritando 123 divergências num tema
#   correto. Aqui a comparação é `"$texto" = "$(cat ...)"`, que é o critério do
#   escritor.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta dependência
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ACERVO="$RAIZ/assets/gatos"
ORIGEM="$RAIZ/systemd"
DESTINO="$HOME/.config/systemd/user"
UNIDADES=(meow-assets.service meow-assets.path)
GATILHO="meow-assets.path"

VIGIA="${ASSETS_VIGIA:-sim}"

CONFERIR=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

# --- o texto que cada unidade deve ter no disco ------------------------------
_texto_de() {
  local u="$1" texto
  texto="$(cat "$ORIGEM/$u" 2>/dev/null)" || return 1
  [ "$u" = "$GATILHO" ] && texto="${texto//@ACERVO@/$ACERVO}"
  printf '%s' "$texto"
}

_tem_systemd() {
  meow_tem systemctl && [ -d "/run/user/$(id -u)/systemd" ]
}

_ligado() {
  [ "$(systemctl --user is-enabled "$GATILHO" 2>/dev/null)" = "enabled" ] &&
  [ "$(systemctl --user is-active  "$GATILHO" 2>/dev/null)" = "active" ]
}

# --- desligado: o que existe tem de SAIR -------------------------------------
# Deixar de instalar não é desligar. Sem esta metade, a unidade que uma execução
# anterior ligou continuaria vigiando depois de ela ter escrito ASSETS_VIGIA="nao"
# — e o sintoma seria "desliguei e continua acontecendo", que é o pior de todos
# porque não há onde olhar.
_desligar() {
  local u restos=0
  for u in "${UNIDADES[@]}"; do [ -f "$DESTINO/$u" ] && restos=$((restos + 1)); done

  if [ "$restos" = 0 ]; then
    meow_pula "vigia do acervo desligado (ASSETS_VIGIA=\"$VIGIA\")"
    return "$MEOW_OK"
  fi
  if [ "$CONFERIR" = 1 ]; then
    meow_muda "ASSETS_VIGIA=\"$VIGIA\" mas o vigia continua instalado — removeria $restos unidade(s)"
    return "$MEOW_DIVERGENTE"
  fi
  _tem_systemd && systemctl --user disable --now "$GATILHO" >/dev/null 2>&1
  for u in "${UNIDADES[@]}"; do rm -f "$DESTINO/$u"; done
  _tem_systemd && systemctl --user daemon-reload >/dev/null 2>&1
  meow_muda "ASSETS_VIGIA=\"$VIGIA\" — vigia do acervo desligado e removido"
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
  # Sem o acervo não há o que vigiar, e apontar o `.path` para um diretório que
  # não existe no próprio clone seria instalar um vigia sem objeto.
  if [ ! -d "$ACERVO" ]; then
    meow_pula "não existe $ACERVO — nada a vigiar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _tem_systemd; then
    meow_aviso "não há systemd --user nesta sessão — o vigia do acervo fica de fora"
    meow_info "  o gato novo continua entrando pelo relógio (meow-logo.timer)"
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
    meow_muda "vigia do acervo: $divergentes unidade(s) a instalar ou atualizar"
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
  meow_ok "vigiando assets/gatos/ — gato novo entra sem esperar o relógio"
  return "$MEOW_OK"
}

# --- aplicar -----------------------------------------------------------------
_aplicar() {
  local u texto mudou=0 estado="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"

  # O DIRETÓRIO DO LOG TEM DE EXISTIR ANTES DA UNIDADE SUBIR
  #   `StandardOutput=append:` é montado antes de qualquer comando do serviço e
  #   antes até do `StateDirectory=`. Reproduzido em 05/08/2026 com o diretório
  #   ausente: `Failed to set up standard output: No such file or directory`,
  #   `status=209/STDOUT`, e nada mais roda. Este mkdir é o que garante o primeiro
  #   disparo numa máquina recém-instalada.
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
    systemctl --user reset-failed "$GATILHO" meow-assets.service >/dev/null 2>&1
    mudou=1
  fi

  # Ligar só quando precisa: um `enable --now` incondicional reescreveria o link
  # em `default.target.wants` e reiniciaria o vigia a cada execução.
  if ! _ligado; then
    if ! systemctl --user enable --now "$GATILHO" >/dev/null 2>&1; then
      meow_erro "não consegui ligar o $GATILHO"
      return "$MEOW_ERRO"
    fi
    mudou=1
  fi

  # Aviso honesto, não falha: as unidades ficam instaladas e o vigia ligado, mas
  # cada disparo será PULADO pelo `ConditionPathExists=` até o ponteiro existir.
  if [ ! -f "$estado/raiz" ]; then
    meow_aviso "o vigia está ligado, mas $estado/raiz ainda não existe"
    meow_info "  até ele aparecer, cada disparo é pulado (o journal diz o motivo)"
  fi

  if [ "$mudou" = 0 ]; then
    meow_ok "vigia do acervo já ligado sobre assets/gatos/"
    return "$MEOW_OK"
  fi
  meow_ok "vigia ligado: soltou um .svg em assets/gatos/, ele entra na hora"
  meow_info "  o gato do dock só troca no próximo login — o painel não relê ícone"
  return "$MEOW_DIVERGENTE"
}

main() {
  [ "$VIGIA" = "sim" ] || { _desligar; return $?; }
  _pronto || return $?
  if [ "$CONFERIR" = 1 ]; then _conferir; else _aplicar; fi
}

main "$@"

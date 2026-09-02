#!/usr/bin/env bash
# vigia_flatpak.sh — liga (ou desliga) o gatilho que repõe o ícone da bandeja
#                    depois de todo deploy de flatpak.
#
#   ./vigia_flatpak.sh              instala as unidades e liga o vigia
#   ./vigia_flatpak.sh --conferir   não escreve; 1 se algo divergir
#
# POR QUE ISTO EXISTE
#   Queixa dela, 23/08/2026: "ao atualizar o flatpak tipo zap zap, o tray, o icon
#   que fica no applet, voltaram aos originais". O `assets/icones/bandeja.map` previa a
#   regressão desde 10/08 e não havia nada que agisse sobre ela. O par
#   `meow-flatpak.path` + `meow-flatpak.service` fecha essa distância — e o
#   cabeçalho do `.path` traz a medição que escolheu o `.changed` como evento,
#   além do porquê de o mecanismo nativo de triggers do flatpak não servir.
#
# POR QUE UM SCRIPT, E NÃO A LÓGICA DENTRO DO install.sh
#   Porque o `meow doctor` precisa da MESMA verificação e o `--consertar` do
#   MESMO conserto. É o desenho que o `vigia_assets.sh` já segue: o `install.sh`
#   chama, o `bin/meow` chama com `--conferir` e com `--aplicar`, e a regra mora
#   num lugar só. Duplicá-la no `bin/meow` seria a segunda verdade que ninguém
#   atualiza.
#
# ESTE É MAIS SIMPLES QUE O `vigia_assets.sh`, E A DIFERENÇA É UMA SÓ
#   Lá existe o marcador `@ACERVO@`, porque a unidade vigia um diretório do
#   REPOSITÓRIO (em /mnt/Apate) e o systemd não tem especificador para "onde está
#   o clone". Aqui os dois caminhos vigiados são fixos ou resolvem com `%h`
#   (`%h/.local/share/flatpak/.changed` e `/var/lib/flatpak/.changed`), então as
#   unidades vão por CÓPIA BYTE A BYTE e não há troca de texto — nem na escrita,
#   nem na conferência.
#
# DESLIGAR TEM DE DESLIGAR
#   Deixar de instalar não é desligar. Sem a metade `_desligar`, a unidade que uma
#   execução anterior ligou continuaria vigiando depois de ela escrever
#   FLATPAK_VIGIA="nao" no meow.conf — e o sintoma seria "desliguei e continua
#   acontecendo", que é o pior de todos porque não há onde olhar.
#
# COMPARAR DO MESMO JEITO QUE SE ESCREVE
#   `meow_escrever` grava com `printf '%s'`, que come o `\n` final. Comparar com
#   `cmp` byte a byte acusaria divergência para sempre num arquivo perfeito — já
#   custou a este projeto um `--conferir` gritando 123 divergências num tema
#   correto. Aqui a comparação é `"$texto" = "$(cat ...)"`, o critério do escritor.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta dependência
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ORIGEM="$RAIZ/systemd"
DESTINO="$HOME/.config/systemd/user"
UNIDADES=(meow-flatpak.service meow-flatpak.path)
GATILHO="meow-flatpak.path"

VIGIA="${FLATPAK_VIGIA:-sim}"

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
    meow_pula "vigia de flatpak desligado (FLATPAK_VIGIA=\"$VIGIA\")"
    return "$MEOW_OK"
  fi
  if [ "$CONFERIR" = 1 ]; then
    meow_muda "FLATPAK_VIGIA=\"$VIGIA\" mas o vigia continua instalado — removeria $restos unidade(s)"
    return "$MEOW_DIVERGENTE"
  fi
  _tem_systemd && systemctl --user disable --now "$GATILHO" >/dev/null 2>&1
  for u in "${UNIDADES[@]}"; do rm -f "$DESTINO/$u"; done
  _tem_systemd && systemctl --user daemon-reload >/dev/null 2>&1
  meow_muda "FLATPAK_VIGIA=\"$VIGIA\" — vigia de flatpak desligado e removido"
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
  # Sem flatpak não há evento nenhum a vigiar, e o `.changed` que a unidade
  # espera nunca existiria. Numa máquina assim a etapa some do relatório, que é
  # o comportamento certo para uma etapa opcional.
  if ! meow_tem flatpak; then
    meow_pula "sem flatpak nesta máquina — nada a vigiar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _tem_systemd; then
    meow_aviso "não há systemd --user nesta sessão — o vigia de flatpak fica de fora"
    meow_info "  o ícone da bandeja continua sendo reposto pelo meow-doctor.timer, às 5h"
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
    meow_muda "vigia de flatpak: $divergentes unidade(s) a instalar ou atualizar"
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
  meow_ok "vigiando o flatpak — o ícone da bandeja volta sozinho depois de um update"
  return "$MEOW_OK"
}

# --- aplicar -----------------------------------------------------------------
_aplicar() {
  local u texto mudou=0 estado="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"

  # O DIRETÓRIO DO LOG TEM DE EXISTIR ANTES DA UNIDADE SUBIR
  #   `StandardOutput=append:` é montado antes de qualquer comando do serviço e
  #   antes até do `StateDirectory=`. Reproduzido em 05/08/2026 com o diretório
  #   ausente: `Failed to set up standard output: No such file or directory`,
  #   `status=209/STDOUT`, e nada mais roda.
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
    systemctl --user reset-failed "$GATILHO" meow-flatpak.service >/dev/null 2>&1
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
    meow_ok "vigia de flatpak já ligado"
    return "$MEOW_OK"
  fi
  meow_ok "vigia ligado: o ícone da bandeja se repõe sozinho depois de um flatpak update"
  meow_info "  o desenho novo aparece quando o aplicativo for fechado e aberto de novo"
  return "$MEOW_DIVERGENTE"
}

main() {
  [ "$VIGIA" = "sim" ] || { _desligar; return $?; }
  _pronto || return $?
  if [ "$CONFERIR" = 1 ]; then _conferir; else _aplicar; fi
}

main "$@"

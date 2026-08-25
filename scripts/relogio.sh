#!/usr/bin/env bash
# relogio.sh — os SEGUNDOS do relógio da topbar, e nada além disso.
#
# POR QUE UMA CHAVE SÓ MERECE UM ARQUIVO INTEIRO
#   O relógio é o único elemento da tela dela que se move sozinho. Com
#   `show_seconds = true` ele redesenha uma vez por segundo, o dia inteiro:
#   86.400 pedidos de atenção por dia para dizer uma informação que ela nunca
#   pediu. A Sprint T chama isso de "a regra da atenção" e o teste dela é
#   apertar os olhos até a captura virar borrão — têm que sobrar no máximo três
#   manchas claras. Um dígito que pisca 86.400 vezes é a quarta.
#
#   O que justifica o arquivo não é o tamanho da mudança (é UMA palavra num
#   arquivo de 4 bytes). É a FRONTEIRA. Esta chave tem controle na GUI, e a
#   regra do projeto (`docs/FRONTEIRA.md`, seção de 17/08/2026) diz, com todas
#   as letras: **onde a GUI do COSMIC tem um controle, o valor é dela.** Um
#   `printf false > show_seconds` solto no install.sh seria a quarta travessia
#   da mesma fronteira que já custou o `opacity` do painel. Aqui a mudança é
#   feita, mas com o mesmo desenho que devolveu a opacidade a ela: a chave nasce
#   no `meow.conf`, VAZIO quer dizer "não toque", e ela retoma o controle
#   apagando uma palavra.
#
# ============================================================================
# O QUE FOI MEDIDO EM 25/08/2026, NESTA MÁQUINA, ANTES DE ESCREVER UMA LINHA
# ============================================================================
#
# 1. O QUE EXISTE NO DISCO
#      ~/.config/cosmic/com.system76.CosmicAppletTime/v1/
#          first_day_of_week = 6
#          military_time     = true
#          show_seconds      = true     <- é esta, e só esta
#    Três arquivos, sem `\n` final, 4 bytes cada nos booleanos. O `meow_escrever`
#    grava com `printf '%s'` e come o `\n` — quer dizer que ele produz
#    exatamente o mesmo byte a byte que o COSMIC produz, e um `cmp` entre os
#    dois não acusa nada. Isso não é sorte: é o mesmo motivo pelo qual o
#    `chk_mimetypes` compara pelo critério do escritor e não byte a byte.
#
# 2. VALE NA HORA — MEDIDO NA TELA, NÃO DEDUZIDO
#    A pergunta da sprint era "o applet relê a chave sozinho (inotify) ou só no
#    próximo login?". A resposta é SOZINHO, e em menos de dois segundos:
#
#      02:11:13  `show_seconds` = true   -> a topbar mostrava "25 de ago., 02:11:13"
#      02:11:37  gravado `false`         -> 6 s depois a topbar mostrava "25 de ago., 02:11"
#      02:13:06  gravado `true` de volta -> 2 s depois a topbar mostrava "02:13:08"
#
#    Capturas comparadas com `captura-de-tela.sh`, sem reiniciar NADA — nem
#    `cosmic-panel`, nem `cosmic-comp`, nem a sessão.
#
#    A ARMADILHA: O MECANISMO **NÃO** É O INOTIFY DO APPLET.
#    Foi o que eu supus, e a medição derrubou. O processo `cosmic-applet-time`
#    (PID 4865, filho do `cosmic-panel`) tem ZERO descritores de inotify:
#        for f in /proc/4865/fdinfo/*; do grep -l inotify "$f"; done   -> nada
#    enquanto o `cosmic-panel` (PID 4265) tem SEIS, e eles apontam para
#    `CosmicPanel/v1`, `CosmicPanel.Panel/v1`, `CosmicPanel.Dock/v1`,
#    `CosmicTheme.Mode/v1`, `CosmicTheme.Light/v2` e `CosmicTheme.Dark/v2` —
#    nenhum para `CosmicAppletTime/v1`. Ou seja: ninguém nesta máquina vigia o
#    diretório do relógio por inotify, e mesmo assim a mudança aparece na tela.
#    O relógio já acorda uma vez por segundo para desenhar a hora, e relê a
#    configuração nessa mesma volta.
#
#    A consequência prática é a única que importa aqui, e ela é a mesma nos dois
#    casos: **este script NÃO reinicia o painel.** Não precisa — e a issue #13 do
#    upstream (`xdg_popup: tried to grab after being mapped`) derruba topbar e
#    dock juntas quando alguém tenta, que é o painel fantasma que este projeto
#    já perseguiu uma vez inteira (`docs/FRONTEIRA.md`, 24/08/2026).
#
# 3. APAGAR O ARQUIVO **NÃO** É REVERTER — POR ISSO `remover` ESCREVE `true`
#    Medido: com `show_seconds` movido para fora do diretório, a topbar
#    continuou mostrando "02:15:29", com segundos. Não dá para saber pela tela
#    se isso é o `Default` do applet ou cache do processo vivo, e a diferença
#    não importa: em qualquer das duas leituras, apagar o arquivo é um jeito de
#    reverter que não se pode conferir. Escrever `true` de volta é conferível,
#    idempotente, e é o que a GUI de Ajustes lê quando ela for olhar o botão.
#
# 4. AS DUAS CHAVES QUE O BINÁRIO CONHECE E QUE NÃO ESTÃO NO DISCO
#      strings /usr/bin/cosmic-applet-time | grep -oE 'show_[a-z_]+'
#    devolve, no bloco do struct de configuração do applet:
#      show_seconds · show_weekday · show_date_in_top_panel · first_day_of_week
#      · military_time · format_strftime
#    `show_weekday` e `show_date_in_top_panel` **existem e não estão no disco** —
#    e a data ESTÁ na tela ("25 de ago., 02:11"), o que quer dizer que o
#    `Default` de `show_date_in_top_panel` é ligado.
#
#    **Este script não escreve nenhuma das duas, de propósito.** Tirar a data da
#    topbar é exatamente o tipo de decisão de gosto que a `MEMORY` deste projeto
#    manda não tomar sozinho ("a folha visual vem antes do código"), e a sprint
#    autorizou os SEGUNDOS, não a data. Se ela pedir, são seis linhas aqui e
#    duas chaves novas no conf, no mesmo desenho de "vazio = não toca".
#
# 5. O QUE NÃO É DESTE ARQUIVO
#    O canto superior direito da topbar (`plugins_wings`) é território da
#    Aurora — `docs/FRONTEIRA.md:32`. Medido hoje, a asa direita tem SEIS
#    applets, e um script que assumisse "a asa é uma lista de um" apagaria a
#    Status Area dela (o susto está registrado em `docs/FRONTEIRA.md:85-88`).
#    Este arquivo não abre `plugins_wings` nem para ler.
#
# O CUSTO DE PREENCHER A CHAVE, DITO SEM ROMANCE
#   Com `RELOGIO_SEGUNDOS` preenchido e `chk_relogio` no `meow doctor`, o valor
#   é REIMPOSTO em toda passagem do doctor — inclusive às 5h da manhã. Se ela
#   mexer no botão da GUI e quiser que a escolha valha, o caminho é ESVAZIAR a
#   chave no `meow.conf`, não brigar com o botão. É o mesmo contrato do
#   `VIDRO_OPACIDADE_PAINEL`, e o `conferir` abaixo diz isso na cara quando
#   encontra divergência.
#
# USO
#   relogio.sh aplicar    grava a escolha do conf (idempotente; vazio = não toca)
#   relogio.sh conferir   0 = conforme · 1 = divergente · 2 = erro · 3 = sem applet
#   relogio.sh estado     lê o disco e diz o que a topbar está desenhando
#   relogio.sh remover    devolve `show_seconds = true`, que é o que havia antes
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# VAZIO = NÃO TOCA. É o contrato inteiro deste arquivo; ver o cabeçalho.
RELOGIO_SEGUNDOS="${RELOGIO_SEGUNDOS:-}"

RELOGIO_BASE="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}/com.system76.CosmicAppletTime/v1"
RELOGIO_ALVO="$RELOGIO_BASE/show_seconds"
RELOGIO_BINARIO="/usr/bin/cosmic-applet-time"

# O valor que havia antes da PRIMEIRA gravação nossa. Sem isto, `remover` teria
# de adivinhar — e adivinhar aqui é escolher por ela numa chave que é dela.
RELOGIO_ANTES="$MEOW_ESTADO/relogio/show_seconds.antes"

# O RON destas chaves é booleano nu, sem aspas e sem `\n`. Normalizar aqui evita
# gravar um valor que o COSMIC descarta calado — o mesmo cuidado que o forma.sh
# toma com os inteiros da geometria.
_relogio_bool() {
  case "$1" in
    sim|true|1)        printf 'true' ;;
    nao|não|false|0)   printf 'false' ;;
    *) return 1 ;;
  esac
}

# 3 e não 1: sem o applet instalado não há divergência, há ausência de assunto.
# É a diferença que deixa o auto-reparo ficar quieto em vez de gritar todo dia.
_relogio_dependencia() {
  if [ ! -x "$RELOGIO_BINARIO" ] && [ ! -d "$RELOGIO_BASE" ]; then
    meow_pula "cosmic-applet-time não encontrado — nada a fazer com o relógio"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

_relogio_no_disco() {
  [ -f "$RELOGIO_ALVO" ] && cat "$RELOGIO_ALVO" 2>/dev/null || printf ''
}

# Guarda o valor de antes UMA vez, na primeira gravação. Chamar de novo não
# sobrescreve: senão o segundo `aplicar` gravaria o nosso próprio valor como se
# fosse o dela, e o `remover` devolveria o que nós mesmos pusemos.
_relogio_lembrar_antes() {
  meow_seco && return 0
  [ -f "$RELOGIO_ANTES" ] && return 0
  mkdir -p "$(dirname "$RELOGIO_ANTES")" 2>/dev/null || return 0
  printf '%s' "$(_relogio_no_disco)" > "$RELOGIO_ANTES" 2>/dev/null || true
  return 0
}

cmd_aplicar() {
  if [ -z "$RELOGIO_SEGUNDOS" ]; then
    meow_pula "RELOGIO_SEGUNDOS vazio — o relógio é seu, o botão da GUI manda"
    return "$MEOW_OK"
  fi
  _relogio_dependencia || return $?

  local valor
  valor="$(_relogio_bool "$RELOGIO_SEGUNDOS")" || {
    meow_erro "RELOGIO_SEGUNDOS='$RELOGIO_SEGUNDOS' — esperado sim ou nao"
    return "$MEOW_ERRO"
  }

  local atual; atual="$(_relogio_no_disco)"
  [ "$atual" = "$valor" ] || _relogio_lembrar_antes

  meow_escrever "$RELOGIO_ALVO" "$valor" 644
  local rc=$?
  case "$rc" in
    "$MEOW_ERRO")
      meow_erro "não consegui gravar $RELOGIO_ALVO"; return "$MEOW_ERRO" ;;
    "$MEOW_DIVERGENTE")
      if meow_seco; then
        meow_muda "gravaria show_seconds=$valor"
      else
        if [ "$valor" = "false" ]; then
          meow_muda "relógio SEM segundos (show_seconds=false)"
        else
          meow_muda "relógio COM segundos (show_seconds=true)"
        fi
        meow_info "vale na hora: medido em 25/08/2026, a topbar acompanha em menos de 2 s"
        meow_info "nada a reiniciar — o cosmic-panel NÃO é tocado por este script"
      fi ;;
    *)
      meow_ok "relógio já estava com show_seconds=$valor" ;;
  esac
  meow_registrar "relogio.sh aplicar valor=$valor rc=$rc"
  return "$rc"
}

cmd_conferir() {
  if [ -z "$RELOGIO_SEGUNDOS" ]; then
    meow_pula "RELOGIO_SEGUNDOS vazio — nada a conferir (o valor é seu)"
    return "$MEOW_OK"
  fi
  _relogio_dependencia || return $?

  local valor
  valor="$(_relogio_bool "$RELOGIO_SEGUNDOS")" || {
    meow_erro "RELOGIO_SEGUNDOS='$RELOGIO_SEGUNDOS' — esperado sim ou nao"
    return "$MEOW_ERRO"
  }

  local atual; atual="$(_relogio_no_disco)"
  if [ "$atual" = "$valor" ]; then
    meow_ok "relógio conforme (show_seconds=$valor)"
    return "$MEOW_OK"
  fi
  meow_muda "relógio divergente: disco='${atual:-<ausente>}', conf pede '$valor'"
  # Esta linha é o pedágio de mexer numa chave que tem botão na GUI: sem ela, um
  # dia ela mudaria pelo botão, o doctor desfaria às 5h e nada diria por quê.
  meow_aviso "o relógio tem controle na GUI (Ajustes → Data e hora)."
  meow_aviso "se foi VOCÊ quem mudou, esvazie RELOGIO_SEGUNDOS no meow.conf —"
  meow_aviso "senão o 'meow doctor --consertar' devolve o valor daqui todo dia."
  return "$MEOW_DIVERGENTE"
}

_relogio_col() { printf '%-24s' "$1"; }

# Read-only de propósito: diz o que a topbar está desenhando AGORA, incluindo as
# duas chaves que este script não escreve. É o comando para responder "por que a
# data ainda aparece?" sem ninguém abrir o binário de novo.
cmd_estado() {
  _relogio_dependencia || return $?
  local k v
  for k in show_seconds military_time first_day_of_week show_weekday show_date_in_top_panel format_strftime; do
    if [ -f "$RELOGIO_BASE/$k" ]; then
      v="$(cat "$RELOGIO_BASE/$k" 2>/dev/null)"
      meow_info "$(_relogio_col "$k") = $v"
    else
      meow_pula "$(_relogio_col "$k") = <ausente: vale o Default do applet>"
    fi
  done
  meow_info "as duas 'ausente' que o binário conhece — show_weekday e"
  meow_info "show_date_in_top_panel — são decisão dela, e este script não as escreve."
  local pid; pid="$(pgrep -f 'cosmic-applet-time' 2>/dev/null | head -1)"
  if [ -n "$pid" ]; then
    meow_ok "cosmic-applet-time vivo (PID $pid) — ele relê a chave sozinho, em ~2 s"
  else
    meow_aviso "cosmic-applet-time NÃO está rodando — o relógio não está na topbar"
  fi
  return "$MEOW_OK"
}

cmd_remover() {
  _relogio_dependencia || return $?
  # O padrão é `true`: foi o que estava no disco em 25/08/2026, antes de este
  # arquivo existir, e é o que a tela mostra quando o arquivo some (medição 3 do
  # cabeçalho). Se houver registro do valor de antes, ele vence o padrão.
  local devolver="true"
  if [ -f "$RELOGIO_ANTES" ]; then
    local guardado; guardado="$(cat "$RELOGIO_ANTES" 2>/dev/null)"
    case "$guardado" in true|false) devolver="$guardado" ;; esac
  fi

  meow_escrever "$RELOGIO_ALVO" "$devolver" 644
  local rc=$?
  case "$rc" in
    "$MEOW_ERRO") meow_erro "não consegui devolver $RELOGIO_ALVO"; return "$MEOW_ERRO" ;;
    "$MEOW_DIVERGENTE")
      meow_seco && meow_muda "devolveria show_seconds=$devolver" \
                || meow_muda "relógio devolvido: show_seconds=$devolver" ;;
    *) meow_ok "relógio já estava em show_seconds=$devolver" ;;
  esac
  meow_seco || rm -f "$RELOGIO_ANTES" 2>/dev/null
  meow_registrar "relogio.sh remover valor=$devolver rc=$rc"
  return "$rc"
}

case "${1:-aplicar}" in
  aplicar)  cmd_aplicar ;;
  conferir) cmd_conferir ;;
  estado)   cmd_estado ;;
  remover)  cmd_remover ;;
  *) meow_erro "uso: relogio.sh {aplicar|conferir|estado|remover}"; exit "$MEOW_ERRO" ;;
esac

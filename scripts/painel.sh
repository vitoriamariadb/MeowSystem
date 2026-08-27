#!/usr/bin/env bash
# painel.sh — o ÚNICO lugar do MeowSystem que sobe, derruba ou clampa a barra.
#
# ============================================================================
# O PROBLEMA, EM UMA FRASE
# ============================================================================
#   Topbar e dock somem juntas e não voltam, e ela tem de apertar Alt+F2 —
#   cada vez com mais frequência.
#
# ============================================================================
# POR QUE NÃO VOLTAM: O SUPERVISOR DO COSMIC DESISTE, E NÃO AVISA
# ============================================================================
#   O `cosmic-session` respawna o `cosmic-panel` com backoff. A fórmula, medida
#   em 26/08/2026 contra as 28 linhas de backoff de um boot inteiro (28
#   quocientes inteiros, zero exceção):
#
#       espera = 2^restarts  ms  x  um inteiro sorteado de 0 a 9
#
#   Três consequências que mudam tudo:
#     - não há teto. No restart 22 a base é 2^22 ms; no 26, 18 horas.
#     - o contador NUNCA zera por sucesso: o painel viveu 2h26 (14:50 -> 17:16)
#       e a espera seguinte ainda saiu com base 2^20.
#     - 1 chance em 10 do sorteio dar ZERO — daí as linhas "sleeping for 0ms" e
#       a barra às vezes voltar na hora mesmo com o contador alto. Não é perdão:
#       é o bilhete bom.
#
#   Medido nesta máquina em 26/08: restart 22 -> 8388608 ms (2h19); restart 23
#   -> 58720256 ms (16h18). Depois de ~20 mortes o supervisor está, na prática,
#   morto para o resto da sessão. Só o logout zera o contador — não há arquivo
#   de estado (o único fd não-socket do processo é /run/systemd/inhibit/*.ref) e
#   a interface D-Bus dele só tem `Exit` e `Restart`, que fecham tudo.
#
#   NÃO DÁ PARA CONSERTAR O SUPERVISOR. Dá para não depender dele.
#
# ============================================================================
# QUEM GASTOU AS VIDAS
# ============================================================================
#   Em 26/08, entre 10:29 e 10:48, seis usos do Alt+F2 levaram o contador de 3 a
#   9. Daí em diante o supervisor já não devolvia o painel em 5s, o fallback do
#   `aurora-reiniciar-painel.sh` assumia, e todo painel passou a nascer ÓRFÃO
#   (PPID 1, sem `PANEL_NOTIFICATIONS_FD`). Órfão ninguém ressuscita: quando o
#   vigia da Aurora o matava — ou qualquer coisa o derrubava — ela ficava sem
#   barra até apertar a tecla de novo. Foi assim que "Alt+F2" virou rotina.
#
#   Este script é o "alguém" que faltava. Com ele de pé, a premissa que o
#   `aurora-painel-fantasma.sh` já assume no cabeçalho dele ("a cura é matar; o
#   cosmic-session respawna") volta a ser verdade — sem tocar numa linha dele.
#
# ============================================================================
# O QUE ESTE SCRIPT **NÃO** FAZ
# ============================================================================
#   - Não edita, não desativa e não mascara nada do Ritual da Aurora. Onde há
#     conflito, o Meow resolve DO LADO DELE: a trégua com o vigia é carimbada no
#     `tentativas.ts` que o próprio vigia já lê (ver lib/painel.sh).
#   - Não devolve o applet de notificações. O sino depende do socketpair que só
#     o `cosmic-session` cria (`PANEL_NOTIFICATIONS_FD`); a outra ponta teria de
#     estar DENTRO do `cosmic-notifications`, e o nome D-Bus
#     `com.system76.NotificationsSocket` não está no barramento nem é ativável.
#     O custo é exatamente UM applet de treze — e as notificações continuam
#     funcionando, porque o daemon segue dono de `org.freedesktop.Notifications`.
#     Quando o supervisor volta a ter painel, cedemos a vez e o sino volta.
#   - Não reinicia a sessão. O método D-Bus `Restart` de `com.system76.CosmicSession`
#     fecha todos os aplicativos dela, e fica deliberadamente fora daqui.
#
# ============================================================================
# VERBOS
# ============================================================================
#   conferir   clampa o raio se for preciso e sai. Zero relação com processos.
#              É o que o `meow-painel-raio.path` chama quando a config muda.
#   teto       imprime a conta (altura, teto, estado do compositor).
#   laco       o supervisor. É o ExecStart da unidade. NUNCA escreve config.
#   reciclar   SIGTERM no painel — a porta única para quem precisa que ele releia.
#   estado     diagnóstico de uma tela.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/painel.sh
. "$RAIZ/lib/painel.sh"

BASE="${MEOW_PAINEL_BASE:-$HOME/.config/cosmic}"
ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/painel"

# ANTI-LAÇO — os números saem da medição, não de cautela vaga.
#   As cinco mortes de painel de 26/08 (10:48:56, 11:07:22, 11:09:49, 11:13:06,
#   19:44:07) têm como pior aglomerado TRÊS em 5min44. Uma cota de 5 em 300s não
#   dispara nesse caso real, e corta em ~10s um painel que morre em menos de 1s.
COTA=${MEOW_PAINEL_COTA:-5}
JANELA=${MEOW_PAINEL_JANELA:-300}
# Painel que viveu mais que isto não conta como tentativa: é episódio isolado,
# não laço. Sem esta regra, uma sessão longa e saudável acabaria "estourando a
# cota" por acumular mortes espaçadas de horas.
VIDA_BOA=${MEOW_PAINEL_VIDA_BOA:-120}

# ---------------------------------------------------------------- conferir --
# O CLAMP, E POR QUE ELE É "IDEMPOTENTE DE FATO"
#   1. se o compositor EM EXECUÇÃO clampa (patches/cosmic-comp-raio-clampado.patch),
#      não existe teto: o raio é dela, e não escrevemos NADA;
#   2. senão, o alvo é min(desejo dela, teto derivado);
#   3. e só gravamos se o alvo diferir do disco — o `meow_escrever` compara por
#      conteúdo, então "já cabe" não gera evento de inotify nenhum. O painel tem
#      seis watches, e cada escrita à toa é um reload da barra na tela dela.
#
# O DESEJO DELA SOBREVIVE AO CLAMP
#   O clamp é catraca de mão única: depois dele não sobra lugar nenhum onde
#   esteja escrito "ela queria 41". Se o `size` da barra mudar depois, o teto
#   sobe e ninguém devolveria o número. Por isso o desejo mora fora da config do
#   COSMIC, em $ESTADO/raio_desejado.<barra>, e a reconciliação é:
#       disco != o que NÓS gravamos  ->  foi ela  ->  desejo := disco
#   Assim o 41 volta sozinho no dia em que couber.
conferir() {
  local rc=0 barra dir teto atual desejo escrito alvo
  mkdir -p "$ESTADO" 2>/dev/null || true

  if meow_painel_compositor_clampa; then
    meow_ok "o cosmic-comp em execução clampa o raio — o canto das barras é seu, sem teto"
    for barra in Panel Dock; do
      dir="$BASE/com.system76.CosmicPanel.$barra/v1"
      [ -d "$dir" ] || continue
      atual="$(cat "$dir/border_radius" 2>/dev/null)"
      case "$atual" in ''|*[!0-9]*) continue ;; esac
      printf '%s' "$atual" > "$ESTADO/raio_desejado.$barra" 2>/dev/null || true
    done
    return "$MEOW_OK"
  fi

  if meow_painel_patch_pendente; then
    meow_aviso "o patch do raio já está em /usr/bin/cosmic-comp, mas vale no PRÓXIMO LOGIN"
    meow_info  "  até lá esta sessão roda o compositor antigo, e o teto abaixo continua valendo"
  fi

  for barra in Panel Dock; do
    dir="$BASE/com.system76.CosmicPanel.$barra/v1"
    [ -d "$dir" ] || { meow_pula "com.system76.CosmicPanel.$barra não está configurado aqui"; continue; }

    teto="$(meow_painel_teto "$dir")" || {
      # Sem conseguir derivar o teto NÃO chutamos: escrever um número inventado
      # na barra dela é pior que não fazer nada.
      meow_aviso "$barra: não consegui derivar a altura (size/padding ilegíveis) — não vou escrever raio nenhum"
      rc=1; continue
    }
    atual="$(cat "$dir/border_radius" 2>/dev/null)"
    case "$atual" in ''|*[!0-9]*) meow_pula "$barra: sem border_radius no disco"; continue ;; esac

    escrito="$(cat "$ESTADO/raio_escrito.$barra" 2>/dev/null)"
    desejo="$(cat "$ESTADO/raio_desejado.$barra" 2>/dev/null)"
    # mudou por fora (ela, o COSMIC Tweaks, o cosmic-settings): o desejo é este
    if [ "$atual" != "$escrito" ]; then desejo="$atual"; fi
    case "$desejo" in ''|*[!0-9]*) desejo="$atual" ;; esac
    printf '%s' "$desejo" > "$ESTADO/raio_desejado.$barra" 2>/dev/null || true

    alvo="$desejo"
    [ "$alvo" -gt "$teto" ] && alvo="$teto"

    if [ "$alvo" = "$atual" ]; then
      meow_debug "$barra: raio $atual cabe no teto $teto — nada a fazer"
      continue
    fi

    meow_aviso "$barra: raio $desejo não cabe (a barra tem $(meow_painel_altura "$dir") de altura; o teto é $teto)"
    meow_info  "  com um raio maior que a metade da altura o compositor derruba a layer surface,"
    meow_info  "  e como painel e dock são o MESMO processo os dois somem JUNTOS — medido em 26/08/2026"
    meow_info  "  guardei o seu $desejo: ele volta sozinho se a barra crescer, ou com o patch do compositor"
    meow_escrever "$dir/border_radius" "$alvo" 644
    case "$?" in
      1) printf '%s' "$alvo" > "$ESTADO/raio_escrito.$barra" 2>/dev/null || true; rc=1 ;;
      2) meow_erro "não consegui escrever $dir/border_radius"; return "$MEOW_ERRO" ;;
    esac
  done
  [ "$rc" = "0" ] && return "$MEOW_OK"
  return "$MEOW_DIVERGENTE"
}

# -------------------------------------------------------------------- teto --
teto() {
  local barra dir
  for barra in Panel Dock; do
    dir="$BASE/com.system76.CosmicPanel.$barra/v1"
    [ -d "$dir" ] || continue
    printf '%-6s size=%-3s padding=%-2s altura=%-3s teto=%-3s raio=%s\n' \
      "$barra" "$(cat "$dir/size" 2>/dev/null)" "$(cat "$dir/padding" 2>/dev/null)" \
      "$(meow_painel_altura "$dir" 2>/dev/null || echo '?')" \
      "$(meow_painel_teto "$dir" 2>/dev/null || echo '?')" \
      "$(cat "$dir/border_radius" 2>/dev/null)"
  done
  if meow_painel_compositor_clampa; then
    printf 'compositor: CLAMPA (o teto acima não se aplica — o raio é seu)\n'
  elif meow_painel_patch_pendente; then
    printf 'compositor: patch instalado, vale no PRÓXIMO LOGIN (o teto acima vale até lá)\n'
  else
    printf 'compositor: sem o patch — o teto acima é o que separa a barra do sumiço\n'
  fi
}

# ---------------------------------------------------------------- reciclar --
# A PORTA ÚNICA. Quem precisa que o painel releia entra por aqui.
#   `pkill -x`, nunca `-f`: `-f` pegaria o `cosmic-panel-button` e os
#   `cosmic-applet-*` junto (eles morrem com o pai de todo jeito).
#   SIGTERM, nunca SIGKILL: o painel precisa desmontar as layer surfaces antes
#   de sair; com SIGKILL o compositor às vezes segura a superfície órfã e o
#   painel novo nasce por cima do fantasma do velho.
reciclar() {
  local espera
  if ! pgrep -x cosmic-panel >/dev/null 2>&1; then
    meow_info "não há painel de pé — nada a reciclar (o laço o repõe, se estiver armado)"
    return "$MEOW_OK"
  fi
  # Se o laço está de pé, ele repõe. Se não está, quem repõe é o cosmic-session
  # — e aí precisamos saber se ele ainda socorre.
  if ! systemctl --user is-active --quiet meow-painel.service 2>/dev/null; then
    espera="$(meow_painel_espera_supervisor)"
    case "$espera" in
      ''|*[!0-9]*) : ;;
      *) if [ "$espera" -gt 5000 ]; then
           meow_erro "não vou reciclar: o meow-painel.service está parado e o cosmic-session dormiria $(( espera / 60000 ))min"
           meow_info "  arme o supervisor do Meow primeiro: systemctl --user start meow-painel.service"
           return "$MEOW_ERRO"
         fi ;;
    esac
  fi
  meow_painel_carencia_aurora
  meow_info "SIGTERM no cosmic-panel"
  pkill -x cosmic-panel
  return "$MEOW_OK"
}

# ------------------------------------------------------------------ estado --
estado() {
  local sup nossos espera
  printf 'compositor  : pid %s\n' "$(pgrep -x cosmic-comp | head -1)"
  sup="$(meow_painel_do_supervisor || true)"
  nossos="$(meow_painel_nossos | tr '\n' ' ' || true)"
  printf 'painel      : do supervisor=%s  nossos=%s\n' "${sup:-<nenhum>}" "${nossos:-<nenhum>}"
  espera="$(meow_painel_espera_supervisor)"
  if [ -n "$espera" ]; then
    printf 'supervisor  : dormiria %s ms (%s min) antes de repor\n' "$espera" "$(( espera / 60000 ))"
  else
    printf 'supervisor  : nunca falhou neste boot\n'
  fi
  # `is-active` IMPRIME o estado e ainda assim sai != 0 quando não está ativo —
  # com `|| echo` a linha saía duplicada ("inactive" e "inativo").
  printf 'laço        : %s\n' "$(systemctl --user is-active meow-painel.service 2>/dev/null; true)"
  teto
}

# -------------------------------------------------------------------- laço --
# O DESENHO, E POR QUE NÃO É UM TIMER
#   Um timer de 5s custaria 17.280 execuções/dia (~7-9 min de CPU) e ainda
#   perderia até 5 segundos até notar a morte. Um `.path` é impossível: o painel
#   não cria nem remove arquivo ao nascer ou morrer (os applets falam por
#   socketpairs anônimos). E `dbus-monitor` não serve: o `cosmic-session` não
#   emite sinal nenhum, e o painel não tem nome bem-conhecido no barramento.
#
#   Então o painel vira FILHO desta unidade e o laço dorme em `wait -n`: acorda
#   no instante da morte, com CPU zero. O `sleep` paralelo existe só para
#   reconciliar de tempos em tempos com o painel do supervisor — se ele
#   ressuscitar o dele, cedemos a vez e ela recupera o sino.
_sair() {
  if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null
    # até 10s esperando a saída graciosa; o TimeoutStopSec da unidade é 15s
    local i
    for i in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  fi
  exit 0
}

laco() {
  local pid sono nascimento vida tentativas=0 janela_ini sup
  janela_ini="$(date +%s)"

  # SAIR SEM ESPERAR O PAINEL DEIXA FANTASMA NA TELA — 26/08/2026
  #   O painel precisa desmontar as layer surfaces antes de sair. Se este laço
  #   manda SIGTERM e sai no mesmo instante, o systemd recolhe o cgroup (SIGKILL
  #   nos que sobraram) antes de ele terminar — e o compositor SEGURA as
  #   superfícies órfãs. O painel seguinte nasce por cima, e ela vê topbar e dock
  #   DUPLICADAS. Aconteceu num `systemctl restart` desta unidade.
  #   Então: SIGTERM e ESPERA. O TimeoutStopSec=15s da unidade é o teto.
  trap '_sair' TERM INT

  while :; do
    # 1) O supervisor do COSMIC voltou a ter painel? Ele é melhor que o nosso
    #    (tem o applet de notificações). Cedemos e ficamos de vigia.
    if sup="$(meow_painel_do_supervisor)"; then
      meow_painel_nossos | while read -r p; do
        [ -n "$p" ] && { echo "cedendo a vez ao painel do supervisor (pid $sup); encerrando o nosso (pid $p)"; kill -TERM "$p" 2>/dev/null; }
      done
      sleep 30
      continue
    fi

    # 2) Já existe painel nosso vivo que não nasceu deste laço (Alt+F2, por
    #    exemplo)? Não duplicamos: vigiamos.
    if pgrep -x cosmic-panel >/dev/null 2>&1 && [ -z "${pid:-}" ]; then
      meow_painel_carencia_aurora
      sleep 10
      continue
    fi

    # 3) Sem painel. Antes de repor: dá para esperar o supervisor?
    if espera="$(meow_painel_espera_supervisor)" && [ -n "$espera" ] && [ "$espera" -le 3000 ] 2>/dev/null; then
      echo "o cosmic-session repõe em ${espera}ms — esperando (o painel dele tem o sino)"
      sleep 5
      continue
    fi

    # 4) Ambiente. Sem socket Wayland não há o que subir; esperar é a resposta,
    #    não falhar (falhar aqui viraria o laço de reinício de 2s que o wrapper
    #    do wl-clip-persist já teve de matar, com 531 falhas em 7 dias).
    if [ -z "${WAYLAND_DISPLAY:-}" ]; then
      WAYLAND_DISPLAY="$(meow_painel_achar_display)" || { sleep 5; continue; }
      export WAYLAND_DISPLAY
    fi
    meow_painel_ambiente_ok || { sleep 5; continue; }

    # 5) Cota.
    [ $(( $(date +%s) - janela_ini )) -gt "$JANELA" ] && { tentativas=0; janela_ini="$(date +%s)"; }
    if [ "$tentativas" -ge "$COTA" ]; then
      echo "DESISTI: $COTA reposições em ${JANELA}s. Algo mata o painel em laço — reiniciar mais só piora."
      meow_notificar "O painel não para de cair" \
        "Reiniciei $COTA vezes em $(( JANELA / 60 )) min e ele morreu de novo. O motivo está no journal: 'corner radius too large' é o suspeito nº 1. Rode: meow painel estado"
      return 1   # Restart=on-failure + StartLimitBurst deixam a unidade em failed, e ela PARA
    fi
    tentativas=$(( tentativas + 1 ))

    # 6) O clamp roda ANTES do spawn, nunca com o painel subindo: escrever em
    #    CosmicPanel.*/v1 com a barra nascendo joga um reload no pior momento da
    #    corrida do corner_radius.
    conferir >/dev/null 2>&1 || true

    meow_painel_carencia_aurora

    # 7) `env -i` + lista negra. Ver lib/painel.sh: sem isso a barra sobe sem
    #    bandeja e sem botão de desligar, e nada na tela diz por quê.
    local -a limpo=()
    local kv nome pular
    while IFS= read -r -d '' kv; do
      nome="${kv%%=*}"; pular=0
      for n in $MEOW_PAINEL_LISTA_NEGRA; do [ "$nome" = "$n" ] && { pular=1; break; }; done
      [ "$pular" = "0" ] && limpo+=("$kv")
    done < <(env -0)

    env -i "${limpo[@]}" cosmic-panel &
    pid=$!
    nascimento="$(date +%s)"
    echo "painel reposto (pid $pid, tentativa $tentativas/$COTA)"

    sleep 60 & sono=$!
    wait -n "$pid" "$sono" 2>/dev/null
    kill "$sono" 2>/dev/null

    if kill -0 "$pid" 2>/dev/null; then
      # Foi o sono que acordou: o painel segue vivo.
      # RENOVAR A TRÉGUA AQUI NÃO É ZELO — 26/08/2026.
      #   Carimbar só no spawn cobre os primeiros 600s (a CARENCIA do vigia da
      #   Aurora). Passado esse prazo o vigia volta a julgar um painel que é
      #   nosso, e o sinal 1 dele ("Can't start notifications applet") é
      #   PERMANENTE num painel sem o socketpair do supervisor — o nosso.
      #   Sem esta linha o par vira um pisca-pisca: ele mata a cada 3 min, nós
      #   repomos, a cota se esgota e a barra fica caída de verdade.
      meow_painel_carencia_aurora
      continue
    fi

    vida=$(( $(date +%s) - nascimento ))
    [ "$vida" -ge "$VIDA_BOA" ] && { tentativas=0; janela_ini="$(date +%s)"; }
    echo "o painel (pid $pid) saiu depois de ${vida}s"
    pid=""
  done
}

# ------------------------------------------------------------------- CLI ----
case "${1:-estado}" in
  conferir) conferir ;;
  teto)     teto ;;
  laco)     laco ;;
  reciclar) reciclar ;;
  estado)   estado ;;
  -h|--help)
    printf 'uso: painel.sh [conferir|teto|laco|reciclar|estado]\n\n'
    printf '  conferir  clampa o raio ao que cabe na barra, se for preciso\n'
    printf '  teto      mostra a conta (altura, teto, estado do compositor)\n'
    printf '  laco      o supervisor; é o ExecStart de meow-painel.service\n'
    printf '  reciclar  SIGTERM no painel, pela porta única\n'
    printf '  estado    diagnóstico de uma tela\n'
    ;;
  *) meow_erro "verbo desconhecido: $1"; exit "$MEOW_ERRO" ;;
esac

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
#   - Não edita, não desativa e não mascara nada do Ritual da Aurora. A trégua
#     que se carimbava no `tentativas.ts` do vigia dele saiu na P39, as
#     chamadas a ela na P44, e a função vazia que sobrou na P47 (24/09/2026).
#   - Não sinaliza painel de outra casa. O `reciclar`, que é a porta dos
#     outros scripts, mira só o painel do mesmo usuário e do mesmo `$HOME` de
#     quem chamou (`meow_painel_desta_casa`, P44), e o último SIGTERM do ramo 2
#     do `laco` também. OS OUTROS TRÊS DO `laco` — o `kill` no painel do
#     supervisor e os dois laços sobre `meow_painel_nossos` — achavam o painel
#     pela máquina, pelo parentesco com o primeiro `cosmic-session`, e a revisão
#     da P44 os anotou aqui. O que os segurava era outra coisa: o `laco` é o
#     `ExecStart` do `meow-painel.service`, que roda na sessão e com o `HOME`
#     dela, e o kernel recusa (EPERM) o sinal de quem não é root a processo de
#     outro usuário; escapava um `meow painel laco` à mão, do mesmo usuário,
#     com outro `HOME`. DESDE A P47 (24/09/2026) OS TRÊS FILTRAM: as duas
#     funções de onde eles tiram o PID só escolhem entre os painéis desta casa
#     (o porquê de filtrar nelas, e não em cada `kill`, está em lib/painel.sh).
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

BASE="${MEOW_PAINEL_BASE:-$(meow_cosmic_dir)}"
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
  # O diretório também é escrita, e o seco não escreve — 24/09/2026 (P44): o
  # `chk_painel` do doctor passava por aqui e deixava `painel/` (e os três pais)
  # criados numa casa de brinquedo onde nada mais seria gravado.
  meow_seco || mkdir -p "$ESTADO" 2>/dev/null || true

  if meow_painel_compositor_clampa; then
    meow_ok "o cosmic-comp em execução clampa o raio — o canto das barras é seu, sem teto"
    for barra in Panel Dock; do
      dir="$BASE/com.system76.CosmicPanel.$barra/$(meow_cosmic_v "com.system76.CosmicPanel.$barra")"
      [ -d "$dir" ] || continue
      atual="$(cat "$dir/border_radius" 2>/dev/null)"
      case "$atual" in ''|*[!0-9]*) continue ;; esac
      # O SECO NÃO ESCREVE, NEM O DESEJO. [2026-09-18]
      #   Este printf rodava também sob MEOW_DRY_RUN=1, e é por ele que a ação
      #   `doctor` do painel — declarada "escreve": false, com a ajuda dizendo
      #   "Não escreve nada." — tocava o disco a cada conferência.
      meow_seco || printf '%s' "$atual" > "$ESTADO/raio_desejado.$barra" 2>/dev/null || true
    done
    return "$MEOW_OK"
  fi

  if meow_painel_patch_pendente; then
    meow_aviso "o patch do raio já está em /usr/bin/cosmic-comp, mas vale no PRÓXIMO LOGIN"
    meow_info  "  até lá esta sessão roda o compositor antigo, e o teto abaixo continua valendo"
  fi

  for barra in Panel Dock; do
    dir="$BASE/com.system76.CosmicPanel.$barra/$(meow_cosmic_v "com.system76.CosmicPanel.$barra")"
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
    # Mesmo motivo do printf acima: registrar o desejo é escrita, e escrita não
    # acontece no ensaio. O caminho de conserto (fix_painel, bin/meow) chama sem
    # o seco, que é onde este registro pertence.
    meow_seco || printf '%s' "$desejo" > "$ESTADO/raio_desejado.$barra" 2>/dev/null || true

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
    # No seco o `meow_escrever` devolve 1 SEM ter escrito, e carimbar "fui eu que
    # gravei $alvo" aqui seria mentir para a reconciliação do desejo — e
    # escrever no estado durante uma leitura do doctor (P44, 24/09/2026).
    case "$?" in
      1) meow_seco || printf '%s' "$alvo" > "$ESTADO/raio_escrito.$barra" 2>/dev/null || true; rc=1 ;;
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
    dir="$BASE/com.system76.CosmicPanel.$barra/$(meow_cosmic_v "com.system76.CosmicPanel.$barra")"
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
#   O alvo é o `cosmic-panel` pelo nome exato, nunca por `-f`: `-f` pegaria o
#   `cosmic-panel-button` e os `cosmic-applet-*` junto (eles morrem com o pai
#   de todo jeito).
#   SIGTERM, nunca SIGKILL: o painel precisa desmontar as layer surfaces antes
#   de sair; com SIGKILL o compositor às vezes segura a superfície órfã e o
#   painel novo nasce por cima do fantasma do velho.
#
# E SÓ O PAINEL DESTA CASA — 24/09/2026 (P44). Até aqui o alvo era
# `pkill -x cosmic-panel`, a máquina inteira; um `meow doctor` numa casa de
# brinquedo derrubava a barra da sessão de verdade. Quem decide o que é "desta
# casa" é o `meow_painel_desta_casa` (lib/painel.sh), e o porquê de usuário +
# `HOME` está lá. Há painel de pé que não é daqui: ele é de outra casa, e a
# resposta é dizer isso e sair 0 — não há o que reciclar NESTA.
reciclar() {
  local espera alvos
  # QUEM PEDIU FICA NO LOG — 10/10/2026, P80 (item 7). Um reciclo do painel
  #   foi o gatilho da faixa verde de 09/10, e o meow.log não dizia quem o
  #   tinha pedido. O `meow_tela_reler` manda o nome (`MEOW_QUEM_RECICLA`); sem
  #   ele, a linha de comando de quem chamou. Antes de qualquer resposta: o
  #   pedido conta mesmo quando não há painel a reciclar.
  meow_registrar "painel reciclar — pedido por ${MEOW_QUEM_RECICLA:-$(ps -o args= -p "$PPID" 2>/dev/null | cut -c1-120)}"
  alvos="$(meow_painel_desta_casa)"
  if [ -z "$alvos" ]; then
    if pgrep -x cosmic-panel >/dev/null 2>&1; then
      meow_info "o painel de pé não é desta casa (HOME=$HOME) — não reciclo o de ninguém"
    else
      meow_info "não há painel de pé — nada a reciclar (o laço o repõe, se estiver armado)"
    fi
    return "$MEOW_OK"
  fi
  # Se o laço está de pé, ele repõe. Se não está, quem repõe é o cosmic-session
  # — e aí precisamos saber se ele ainda socorre.
  if ! systemctl --user is-active --quiet meow-painel.service 2>/dev/null; then
    espera="$(meow_painel_espera_supervisor)"
    recusa=""
    case "$espera" in
      # P76: o formato do log mudou e a espera não foi medida — o conservador é
      # não confiar num supervisor cuja espera ninguém sabe.
      nao-medida) recusa="a espera do cosmic-session não foi medida" ;;
      ''|*[!0-9]*) : ;;
      *) [ "$espera" -gt 5000 ] && recusa="o cosmic-session dormiria $(( espera / 60000 ))min" ;;
    esac
    # O SUPERVISOR SE ARMA AQUI — 15/10/2026, P82 (item 1). A linha mandava
    #   digitar o `systemctl --user start` e parava. Quem sabe que ele falta é
    #   este verbo, então ele o arma; só sem o supervisor de pé, de jeito
    #   nenhum, o reciclo é recusado, e a linha diz o estado.
    if [ -n "$recusa" ]; then
      if systemctl --user start meow-painel.service 2>/dev/null \
         && systemctl --user is-active --quiet meow-painel.service 2>/dev/null; then
        meow_muda "o meow-painel.service estava parado ($recusa) — armado antes de reciclar"
      else
        meow_erro "não vou reciclar: o meow-painel.service está parado, não armou, e $recusa"
        return "$MEOW_ERRO"
      fi
    fi
  fi
  # `~~`, e não `>>` — 24/09/2026, sprint P50 (achado 17). O código de saída
  # é 0 nos dois caminhos (reciclou, ou não havia painel desta casa para
  # reciclar), e quem chama por `|| ...` depende disso. O que separa um do
  # outro na saída é esta linha: `~~` é o glifo do projeto para "mudou", e é
  # ele que a gaveta do painel lê para dizer «recarregou» em vez de «nada a
  # recarregar» — antes ela dizia «já estava certo» com o PID do painel novo.
  meow_muda "SIGTERM no cosmic-panel — ele volta em uns 2 s"
  # shellcheck disable=SC2086  # um PID por palavra, de propósito
  kill -TERM $alvos 2>/dev/null
  return "$MEOW_OK"
}

# ------------------------------------------------------------------ estado --
estado() {
  local sup nossos espera
  printf 'compositor  : pid %s\n' "$(pgrep -x cosmic-comp | head -1)"
  sup="$(meow_painel_do_supervisor || true)"
  nossos="$(meow_painel_nossos | tr '\n' ' ' || true)"
  printf 'painel      : do supervisor=%s  nossos=%s\n' "${sup:-<nenhum>}" "${nossos:-<nenhum>}"
  # "Existe painel" não é "há barra na tela" — a diferença é o painel fantasma,
  # e sem esta linha o `estado` dizia "do supervisor=NNN" com a tela vazia.
  if meow_painel_fantasma; then
    printf 'desenhando  : NÃO — painel vivo sem desenhar (fantasma). O laço recicla; ou: meow painel reciclar\n'
  else
    printf 'desenhando  : sim\n'
  fi
  espera="$(meow_painel_espera_supervisor)"
  if [ "$espera" = "nao-medida" ]; then
    printf 'supervisor  : reiniciou o painel, e a espera não foi medida (o formato do log mudou)\n'
  elif [ -n "$espera" ]; then
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
  # Carência do reciclo por fantasma. Sem ela, o detector vira o laço que o
  # COTA existe para impedir: recicla, o painel novo demora a montar, a
  # passagem seguinte acha fantasma de novo. 600 s é o intervalo em que um
  # episódio real não se repete — e se repetir, o COTA lá embaixo desiste e
  # avisa, que é o comportamento certo.
  local ultimo_fantasma=0 agora_f
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
      # CEDER A VEZ A UM PAINEL QUE NÃO DESENHA É FICAR SEM BARRA [18/09/2026]
      #   O painel do supervisor é preferível ao nosso — ele tem o applet de
      #   notificações, que só o socketpair dele fornece. Mas isso vale para um
      #   painel que DESENHA. Um fantasma responde "existo" para sempre, e este
      #   ramo cedia a vez a ele indefinidamente.
      agora_f="$(date +%s)"
      if meow_painel_fantasma && [ $(( agora_f - ultimo_fantasma )) -ge 600 ]; then
        echo "o painel do supervisor (pid $sup) está vivo e NÃO desenha — reciclando"
        ultimo_fantasma="$agora_f"
        kill -TERM "$sup" 2>/dev/null
        sleep 10
        continue
      fi
      meow_painel_nossos | while read -r p; do
        [ -n "$p" ] && { echo "cedendo a vez ao painel do supervisor (pid $sup); encerrando o nosso (pid $p)"; kill -TERM "$p" 2>/dev/null; }
      done
      sleep 30
      continue
    fi

    # 2) Já existe painel nosso vivo que não nasceu deste laço (Alt+F2, por
    #    exemplo)? Não duplicamos: vigiamos.
    if pgrep -x cosmic-panel >/dev/null 2>&1 && [ -z "${pid:-}" ]; then
      # O mesmo ponto cego do ramo acima: "existe painel" não é "há barra na
      # tela". Aqui o painel é nosso (ou do Alt+F2), e a cura é a mesma.
      agora_f="$(date +%s)"
      if meow_painel_fantasma && [ $(( agora_f - ultimo_fantasma )) -ge 600 ]; then
        echo "painel vivo que NÃO desenha — reciclando"
        ultimo_fantasma="$agora_f"
        meow_painel_nossos | while read -r p; do kill -TERM "$p" 2>/dev/null; done
        # O que sobrou de pé, e só o desta casa: era `pkill -TERM -x cosmic-panel`,
        # a máquina inteira, até a P44 (24/09/2026). Ver `meow_painel_desta_casa`.
        meow_painel_desta_casa | while read -r p; do kill -TERM "$p" 2>/dev/null; done
        sleep 10
        continue
      fi
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

    # A VIGÍLIA É UM LAÇO INTERNO, E ISSO NÃO É ESTILO — 26/08/2026
    #   A primeira versão fazia `continue` quando o sono de reconciliação
    #   acordava, voltando ao topo do laço externo. Mas o topo não tinha guarda
    #   para "o meu painel ainda está vivo": ele caía no ramo de reposição e
    #   spawnava OUTRO. Resultado, medido na tela dela: dois cosmic-panel do
    #   mesmo laço (2041167 e 2042099), topbar e dock duplicadas.
    #   Enquanto este painel viver, quem manda é este laço interno.
    # A RONDA É DE 5s, E ERA DE 60s — 01/09/2026, DUPLA NA TELA DELA
    #   Ela viu topbar E dock duplicadas por volta das 20:32 e perguntou por que
    #   o problema tinha voltado. Não era o painel fantasma: era ESTE laço.
    #   Medido no journal do dia:
    #
    #     20:29:02  meow-painel: painel reposto (pid 1894196)   <- o NOSSO
    #     ~20:32    o cosmic-session, vencido o backoff, repôs o DELE
    #     20:33:02  meow-painel: o cosmic-session voltou a ter painel — cedendo
    #
    #   Entre a volta do supervisor e a nossa cessão, DOIS cosmic-panel
    #   desenhavam a mesma barra e a mesma dock. A cessão estava correta; ela só
    #   acontecia na próxima acordada, e a acordada era de minuto em minuto —
    #   240s de dupla naquele caso (quatro sonos), porque quem define o instante
    #   da volta é o backoff do supervisor, não nós.
    #
    #   Cinco segundos põem o teto da dupla em 5s. O custo é a ronda:
    #   `meow_painel_do_supervisor` são dois `pgrep` e, por painel vivo desta
    #   casa, a leitura do `environ` (P47) e um `ps` — 12 rondas por minuto
    #   contra 1. É barulho de fundo perto de um painel duplicado na tela dela.
    #
    #   A TRÉGUA COM O VIGIA DA AURORA, que era renovada aqui uma vez por minuto
    #   com um contador próprio, saiu na P44 (24/09/2026) junto com as outras
    #   cinco chamadas: a função já estava vazia desde a P39 — ela escrevia no
    #   estado de um vigia de outro projeto, que a regra de 23/09 tira —, e ela
    #   mesma saiu na P47, por não ter mais quem a chamasse.
    while kill -0 "$pid" 2>/dev/null; do
      sleep 5 & sono=$!
      wait -n "$pid" "$sono" 2>/dev/null
      kill "$sono" 2>/dev/null
      kill -0 "$pid" 2>/dev/null || break

      # O supervisor voltou a ter painel? O dele é melhor (tem o sino).
      if meow_painel_do_supervisor >/dev/null 2>&1; then
        echo "o cosmic-session voltou a ter painel — cedendo a vez (o dele tem o sino)"
        kill -TERM "$pid" 2>/dev/null
        break
      fi
    done

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

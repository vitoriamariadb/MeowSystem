#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/painel.sh
. "$RAIZ/lib/painel.sh"

BASE="${MEOW_PAINEL_BASE:-$(meow_cosmic_dir)}"
ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/painel"

COTA=${MEOW_PAINEL_COTA:-5}
JANELA=${MEOW_PAINEL_JANELA:-300}
VIDA_BOA=${MEOW_PAINEL_VIDA_BOA:-120}

conferir() {
  local rc=0 barra dir teto atual desejo escrito alvo
  meow_seco || mkdir -p "$ESTADO" 2>/dev/null || true

  if meow_painel_compositor_clampa; then
    meow_ok "o cosmic-comp em execução clampa o raio — o canto das barras é seu, sem teto"
    for barra in Panel Dock; do
      dir="$BASE/com.system76.CosmicPanel.$barra/$(meow_cosmic_v "com.system76.CosmicPanel.$barra")"
      [ -d "$dir" ] || continue
      atual="$(cat "$dir/border_radius" 2>/dev/null)"
      case "$atual" in ''|*[!0-9]*) continue ;; esac
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
      meow_aviso "$barra: não consegui derivar a altura (size/padding ilegíveis) — não vou escrever raio nenhum"
      rc=1; continue
    }
    atual="$(cat "$dir/border_radius" 2>/dev/null)"
    case "$atual" in ''|*[!0-9]*) meow_pula "$barra: sem border_radius no disco"; continue ;; esac

    escrito="$(cat "$ESTADO/raio_escrito.$barra" 2>/dev/null)"
    desejo="$(cat "$ESTADO/raio_desejado.$barra" 2>/dev/null)"
    if [ "$atual" != "$escrito" ]; then desejo="$atual"; fi
    case "$desejo" in ''|*[!0-9]*) desejo="$atual" ;; esac
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
    case "$?" in
      1) meow_seco || printf '%s' "$alvo" > "$ESTADO/raio_escrito.$barra" 2>/dev/null || true; rc=1 ;;
      2) meow_erro "não consegui escrever $dir/border_radius"; return "$MEOW_ERRO" ;;
    esac
  done
  [ "$rc" = "0" ] && return "$MEOW_OK"
  return "$MEOW_DIVERGENTE"
}

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

reciclar() {
  local espera alvos
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
  if ! systemctl --user is-active --quiet meow-painel.service 2>/dev/null; then
    espera="$(meow_painel_espera_supervisor)"
    recusa=""
    case "$espera" in
      nao-medida) recusa="a espera do cosmic-session não foi medida" ;;
      ''|*[!0-9]*) : ;;
      *) [ "$espera" -gt 5000 ] && recusa="o cosmic-session dormiria $(( espera / 60000 ))min" ;;
    esac
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
  meow_muda "SIGTERM no cosmic-panel — ele volta em uns 2 s"
  local filhos="" _p
  for _p in $alvos; do filhos="$filhos $(pgrep -P "$_p" | tr '\n' ' ')"; done
  # shellcheck disable=SC2086
  [ -n "${filhos// /}" ] && kill -TERM $filhos 2>/dev/null
  # shellcheck disable=SC2086
  kill -TERM $alvos 2>/dev/null
  return "$MEOW_OK"
}

estado() {
  local sup nossos espera
  printf 'compositor  : pid %s\n' "$(pgrep -x cosmic-comp | head -1)"
  sup="$(meow_painel_do_supervisor || true)"
  nossos="$(meow_painel_nossos | tr '\n' ' ' || true)"
  printf 'painel      : do supervisor=%s  nossos=%s\n' "${sup:-<nenhum>}" "${nossos:-<nenhum>}"
  if meow_painel_fantasma; then
    printf 'desenhando  : NÃO — painel vivo sem desenhar (fantasma). O laço o recicla sozinho\n'
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
  printf 'laço        : %s\n' "$(systemctl --user is-active meow-painel.service 2>/dev/null; true)"
  teto
}

_sair() {
  if [ -n "${pid:-}" ] && kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null
    local i
    for i in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  fi
  exit 0
}

laco() {
  local pid sono nascimento vida tentativas=0 janela_ini sup
  local ultimo_fantasma=0 agora_f
  janela_ini="$(date +%s)"

  trap '_sair' TERM INT

  while :; do
    if sup="$(meow_painel_do_supervisor)"; then
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

    if pgrep -x cosmic-panel >/dev/null 2>&1 && [ -z "${pid:-}" ]; then
      agora_f="$(date +%s)"
      if meow_painel_fantasma && [ $(( agora_f - ultimo_fantasma )) -ge 600 ]; then
        echo "painel vivo que NÃO desenha — reciclando"
        ultimo_fantasma="$agora_f"
        meow_painel_nossos | while read -r p; do kill -TERM "$p" 2>/dev/null; done
        meow_painel_desta_casa | while read -r p; do kill -TERM "$p" 2>/dev/null; done
        sleep 10
        continue
      fi
      sleep 10
      continue
    fi

    if espera="$(meow_painel_espera_supervisor)" && [ -n "$espera" ] && [ "$espera" -le 3000 ] 2>/dev/null; then
      echo "o cosmic-session repõe em ${espera}ms — esperando (o painel dele tem o sino)"
      sleep 5
      continue
    fi

    if [ -z "${WAYLAND_DISPLAY:-}" ]; then
      WAYLAND_DISPLAY="$(meow_painel_achar_display)" || { sleep 5; continue; }
      export WAYLAND_DISPLAY
    fi
    meow_painel_ambiente_ok || { sleep 5; continue; }

    [ $(( $(date +%s) - janela_ini )) -gt "$JANELA" ] && { tentativas=0; janela_ini="$(date +%s)"; }
    if [ "$tentativas" -ge "$COTA" ]; then
      echo "DESISTI: $COTA reposições em ${JANELA}s. Algo mata o painel em laço — reiniciar mais só piora."
      meow_notificar "O painel não para de cair" \
        "Reiniciei $COTA vezes em $(( JANELA / 60 )) min e ele morreu de novo. O motivo está no journal: 'corner radius too large' é o suspeito nº 1; «Como estão o painel e a dock» mostra o resto."
      return 1
    fi
    tentativas=$(( tentativas + 1 ))

    conferir >/dev/null 2>&1 || true

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

    while kill -0 "$pid" 2>/dev/null; do
      sleep 5 & sono=$!
      wait -n "$pid" "$sono" 2>/dev/null
      kill "$sono" 2>/dev/null
      kill -0 "$pid" 2>/dev/null || break

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

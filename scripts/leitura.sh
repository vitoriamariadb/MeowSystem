#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

LEITURA_AGENDA="${LEITURA_AGENDA:-}"
LEITURA_HORARIO_INICIO="${LEITURA_HORARIO_INICIO:-18:00}"
LEITURA_HORARIO_FIM="${LEITURA_HORARIO_FIM:-07:00}"
LEITURA_TEMPERATURA="${LEITURA_TEMPERATURA:-3500}"
LEITURA_TEXTURA="${LEITURA_TEXTURA:-0.35}"
LEITURA_RAMPA_MIN="${LEITURA_RAMPA_MIN:-0}"

LEITURA_BASE="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}/com.system76.CosmicComp/$(meow_cosmic_v com.system76.CosmicComp)"
LEITURA_K_TEMP="$LEITURA_BASE/leitura_temperatura"
LEITURA_K_TEXT="$LEITURA_BASE/leitura_textura"
LEITURA_K_AGENDA="$LEITURA_BASE/leitura_agenda"
LEITURA_K_INI="$LEITURA_BASE/leitura_hora_inicio"
LEITURA_K_FIM="$LEITURA_BASE/leitura_hora_fim"

LEITURA_APPLET_ID="com.meowsystem.AppletLeitura"
LEITURA_APPLET_BIN="$HOME/.local/bin/meow-applet-leitura"
LEITURA_APPLET_SOMBRA="${XDG_DATA_HOME:-$HOME/.local/share}/applications/$LEITURA_APPLET_ID.desktop"
LEITURA_APPLET_ASA="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel.Panel/$(meow_cosmic_v com.system76.CosmicPanel.Panel)/plugins_wings"
LEITURA_APPLET_MEIO="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel.Panel/$(meow_cosmic_v com.system76.CosmicPanel.Panel)/plugins_center"

LEITURA_ESTADO_BASE="${XDG_STATE_HOME:-$HOME/.local/state}/cosmic/$LEITURA_APPLET_ID/v1"
LEITURA_K_ULT_T="$LEITURA_ESTADO_BASE/ultima_temperatura"
LEITURA_K_ULT_X="$LEITURA_ESTADO_BASE/ultima_textura"

LEITURA_COMP="$(meow_cosmic_comp_disco)"
LEITURA_MARCADOR="AURORA-READING-MODE"
LEITURA_TIMER="meow-leitura.timer"

LEITURA_NEUTRO=6500
LEITURA_PISO=1000
LEITURA_DELA=4

_leitura_cru() {
  local arq="$1" v
  [ -f "$arq" ] || return 1
  v="$(cat "$arq" 2>/dev/null)" || return 1
  v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
  v="${v#\"}"; v="${v%\"}"
  v="${v#"${v%%[![:space:]]*}"}"; v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
  [ -n "$v" ]
}

_leitura_minutos() {
  local v="$1" h m
  case "$v" in
    [0-9][0-9]:[0-9][0-9]|[0-9]:[0-9][0-9])
      h="${v%%:*}"; m="${v##*:}"
      [ "$((10#$h))" -le 23 ] && [ "$((10#$m))" -le 59 ] || return 1
      printf '%s' "$(( 10#$h * 60 + 10#$m ))" ;;
    ""|*[!0-9]*) return 1 ;;
    *)
      [ "$((10#$v))" -le 1439 ] || return 1
      printf '%s' "$((10#$v))" ;;
  esac
}

_leitura_hhmm() { printf '%02d:%02d' "$(( $1 / 60 ))" "$(( $1 % 60 ))"; }

LEITURA_FONTE=""
LEITURA_FONTE_INI=""
LEITURA_FONTE_FIM=""
LEITURA_INI=0
LEITURA_FIM=0
LEITURA_APPLET_DIZ=""

LEITURA_PONTA=0
LEITURA_PONTA_FONTE=""
_leitura_uma_ponta() {
  local chave="$1" padrao="$2" nome="$3" v m
  if v="$(_leitura_cru "$chave")" && m="$(_leitura_minutos "$v")"; then
    LEITURA_PONTA="$m"; LEITURA_PONTA_FONTE="applet"; return "$MEOW_OK"
  fi
  m="$(_leitura_minutos "$padrao")" || {
    meow_erro "$nome='$padrao' não é HH:MM"; return "$MEOW_ERRO"; }
  LEITURA_PONTA="$m"; LEITURA_PONTA_FONTE="meow.conf"; return "$MEOW_OK"
}

_leitura_resolver_agenda() {
  local a
  _leitura_uma_ponta "$LEITURA_K_INI" "$LEITURA_HORARIO_INICIO" LEITURA_HORARIO_INICIO \
    || return "$MEOW_ERRO"
  LEITURA_INI="$LEITURA_PONTA"; LEITURA_FONTE_INI="$LEITURA_PONTA_FONTE"
  _leitura_uma_ponta "$LEITURA_K_FIM" "$LEITURA_HORARIO_FIM" LEITURA_HORARIO_FIM \
    || return "$MEOW_ERRO"
  LEITURA_FIM="$LEITURA_PONTA"; LEITURA_FONTE_FIM="$LEITURA_PONTA_FONTE"

  if [ "$LEITURA_FONTE_INI" != "$LEITURA_FONTE_FIM" ]; then
    LEITURA_FONTE="misto"
  elif [ "$LEITURA_FONTE_INI" = "applet" ]; then
    LEITURA_FONTE="applet"
  else
    LEITURA_FONTE="padrao"
  fi

  LEITURA_APPLET_DIZ=""
  if a="$(_leitura_cru "$LEITURA_K_AGENDA")"; then
    case "$a" in
      true|"Some(true)")   LEITURA_APPLET_DIZ="sim" ;;
      false|"Some(false)") LEITURA_APPLET_DIZ="nao" ;;
    esac
  fi
  return "$MEOW_OK"
}

LEITURA_FONTE_ALVO_T=""
LEITURA_FONTE_ALVO_X=""

_leitura_resolver_alvo() {
  local v
  LEITURA_FONTE_ALVO_T="meow.conf"
  LEITURA_FONTE_ALVO_X="meow.conf"

  if v="$(_leitura_cru "$LEITURA_K_ULT_T")"; then
    case "$v" in
      ""|*[!0-9]*) ;;
      *) if [ "$v" -ge "$LEITURA_PISO" ] && [ "$v" -le "$LEITURA_NEUTRO" ]; then
           LEITURA_TEMPERATURA="$v"; LEITURA_FONTE_ALVO_T="applet"
         fi ;;
    esac
  fi

  if v="$(_leitura_cru "$LEITURA_K_ULT_X")"; then
    case "$v" in
      ""|*[!0-9.]*) ;;
      *) if LC_ALL=C awk -v x="$v" 'BEGIN{ exit !(x >= 0 && x <= 1) }'; then
           LEITURA_TEXTURA="$v"; LEITURA_FONTE_ALVO_X="applet"
         fi ;;
    esac
  fi
  return "$MEOW_OK"
}

LEITURA_ALVO_T=0
LEITURA_ALVO_X="0.00"
LEITURA_ALVO_F="0.00"
LEITURA_FASE=""
LEITURA_AGORA=0

_leitura_alvo_agora() {
  local t="$LEITURA_TEMPERATURA" x="$LEITURA_TEXTURA" n="$LEITURA_RAMPA_MIN" saida
  LEITURA_AGORA="$(_leitura_minutos "$(date +%H:%M)")" || return "$MEOW_ERRO"

  case "$t" in ""|*[!0-9]*)  t="$LEITURA_NEUTRO" ;; esac
  case "$x" in ""|*[!0-9.]*) x=0 ;; esac
  case "$n" in ""|*[!0-9]*)  n=0 ;; esac

  saida="$(LC_ALL=C awk -v ini="$LEITURA_INI" -v fim="$LEITURA_FIM" -v n="$n" \
               -v agora="$LEITURA_AGORA" -v alvo_t="$t" -v alvo_x="$x" \
               -v neutro="$LEITURA_NEUTRO" -v piso="$LEITURA_PISO" 'BEGIN{
    # As três linhas abaixo são o e_noite() do wallpaper.sh:637, e a igualdade
    # entre os dois arquivos é o que impede a máquina de ter duas noites.
    if      (ini == fim) noite = 1;
    else if (ini >  fim) noite = (agora >= ini || agora <  fim);
    else                 noite = (agora >= ini && agora <  fim);

    # Com ini == fim é noite o dia inteiro: não existe borda de onde a rampa
    # partisse, e inventar uma faria a tela saltar para o neutro uma vez por dia.
    if (n <= 0 || ini == fim) {
      f = noite ? 1 : 0;
      fase = noite ? "noite" : "dia";
    } else {
      dini = (agora - ini + 1440) % 1440;
      dfim = (agora - fim + 1440) % 1440;

      # O TETO E O PISO QUE A JANELA PERMITE — ver o cabeçalho (31/08/2026).
      # A subida sobe 1/n por minuto e tem `dur_noite` minutos; a descida desce
      # 1/n por minuto e tem `dur_dia`. Quando uma das duas não tem tempo de
      # chegar ao fim, o vaivém se acomoda entre `vale` e `pico` — e é ISSO que
      # a descida tem de tomar como ponto de partida, senão ela começa em 1 e a
      # tela salta para o âmbar cheio no minuto em que a janela fecha.
      #
      # O estado estacionário fecha sem laço: o lado mais LONGO é o que chega ao
      # seu extremo, e o mais curto herda o que sobrou do outro.
      dur_noite = (fim - ini + 1440) % 1440;
      dur_dia   = 1440 - dur_noite;
      if (dur_noite >= dur_dia) { pico = 1; vale = 1 - dur_dia/n;   if (vale < 0) vale = 0 }
      else                      { vale = 0; pico = dur_noite/n;     if (pico > 1) pico = 1 }

      if (noite) {
        f = vale + dini / n; if (f > 1) f = 1;
        fase = (f >= pico) ? "noite" : "esquentando";
      } else {
        f = pico - dfim / n; if (f < 0) f = 0;
        fase = (f <= vale) ? "dia" : "esfriando";
      }
    }

    # A temperatura sai do neutro e caminha para o alvo. Fora da faixa útil o
    # valor é aparado em silêncio aqui; quem AVISA é o `conferir`, uma vez por
    # dia, e não o timer, 1440 vezes.
    if (alvo_t < piso)   alvo_t = piso;
    if (alvo_t > neutro) alvo_t = neutro;
    if (alvo_x < 0)      alvo_x = 0;
    if (alvo_x > 1)      alvo_x = 1;

    temp = int(neutro - f * (neutro - alvo_t) + 0.5);
    # `0`, e nunca `6500`: o is_noop() da etapa 1 exige == 0 para PULAR o passe
    # do shader. Escrever o neutro deixaria a multiplicação neutra rodando por
    # quadro, para sempre, sem nada na tela para acusar.
    if (f <= 0 || temp >= neutro) temp = 0;

    tex = f * alvo_x;
    if (tex < 0.005) tex = 0;

    printf "%d %.2f %.2f %s\n", temp, tex, f, fase;
  }' 2>/dev/null)" || return "$MEOW_ERRO"

  [ -n "$saida" ] || return "$MEOW_ERRO"
  read -r LEITURA_ALVO_T LEITURA_ALVO_X LEITURA_ALVO_F LEITURA_FASE <<< "$saida"
  return "$MEOW_OK"
}

_leitura_mesmo_numero() {
  local a="${1:-}" b="${2:-}"
  case "$a" in ""|*[!0-9.+-]*) return 1 ;; esac
  case "$b" in ""|*[!0-9.+-]*) return 1 ;; esac
  [ "$a" = "$b" ] && return 0
  LC_ALL=C awk -v a="$a" -v b="$b" 'BEGIN{ exit ((a-b) < 0.005 && (b-a) < 0.005) ? 0 : 1 }'
}

_leitura_no_disco() {
  LEITURA_DISCO_T="$(_leitura_cru "$LEITURA_K_TEMP")" || LEITURA_DISCO_T=""
  LEITURA_DISCO_X="$(_leitura_cru "$LEITURA_K_TEXT")" || LEITURA_DISCO_X=""
}
LEITURA_DISCO_T=""
LEITURA_DISCO_X=""

_leitura_gravar() {
  local temp="$1" text="$2" motivo="$3" mudou=0 r
  _leitura_no_disco

  if ! _leitura_mesmo_numero "$LEITURA_DISCO_T" "$temp"; then
    meow_escrever "$LEITURA_K_TEMP" "$temp" 644; r=$?
    case "$r" in
      2) meow_erro "não consegui gravar $LEITURA_K_TEMP"; return "$MEOW_ERRO" ;;
      1) mudou=1 ;;
    esac
  fi
  if ! _leitura_mesmo_numero "$LEITURA_DISCO_X" "$text"; then
    meow_escrever "$LEITURA_K_TEXT" "$text" 644; r=$?
    case "$r" in
      2) meow_erro "não consegui gravar $LEITURA_K_TEXT"; return "$MEOW_ERRO" ;;
      1) mudou=1 ;;
    esac
  fi

  if [ "$mudou" = "1" ]; then
    if meow_seco; then
      meow_muda "gravaria temperatura=$temp textura=$text ($motivo)"
    else
      meow_muda "$motivo: temperatura=${temp}K textura=$text"
      meow_registrar "leitura.sh temp=$temp textura=$text fase=${LEITURA_FASE:-$motivo}"
    fi
    return "$MEOW_DIVERGENTE"
  fi
  return "$MEOW_OK"
}

_leitura_dizer_fonte() {
  local diz="${1:-info}"
  local janela; janela="das $(_leitura_hhmm "$LEITURA_INI") às $(_leitura_hhmm "$LEITURA_FIM")"
  case "$LEITURA_FONTE" in
    applet)
      "meow_$diz" "horário do applet (leitura_hora_inicio/fim): $janela" ;;
    misto)
      local ponta="o início"
      [ "$LEITURA_FONTE_INI" = "applet" ] || ponta="o fim"
      "meow_$diz" "o applet gravou só $ponta — a outra ponta vem do PADRÃO do meow.conf ($janela)" ;;
    *)
      "meow_$diz" "o applet ainda não gravou horário — usando o PADRÃO do meow.conf: $janela" ;;
  esac
}

_leitura_avisar_chaves() {
  case "$LEITURA_TEMPERATURA" in
    ""|*[!0-9]*) meow_aviso "LEITURA_TEMPERATURA='$LEITURA_TEMPERATURA' não é um inteiro — tratada como ${LEITURA_NEUTRO}K (desligado)" ;;
    *) if [ "$LEITURA_TEMPERATURA" -lt "$LEITURA_PISO" ] || [ "$LEITURA_TEMPERATURA" -gt "$LEITURA_NEUTRO" ]; then
         meow_aviso "LEITURA_TEMPERATURA=$LEITURA_TEMPERATURA está fora de ${LEITURA_PISO}–${LEITURA_NEUTRO}K — aparada"
       fi ;;
  esac
  case "$LEITURA_TEXTURA" in
    ""|*[!0-9.]*) meow_aviso "LEITURA_TEXTURA='$LEITURA_TEXTURA' não é um decimal com PONTO — tratada como 0 (sem papel)" ;;
    *) if ! LC_ALL=C awk -v v="$LEITURA_TEXTURA" 'BEGIN{ exit (v <= 1) ? 0 : 1 }'; then
         meow_aviso "LEITURA_TEXTURA=$LEITURA_TEXTURA está fora de 0.0–1.0 — aparada"
       fi ;;
  esac
  case "$LEITURA_RAMPA_MIN" in
    ""|*[!0-9]*) meow_aviso "LEITURA_RAMPA_MIN='$LEITURA_RAMPA_MIN' não é um inteiro de minutos — tratada como 0 (virada seca)" ;;
  esac
  if [ "$LEITURA_RAMPA_MIN" -gt 0 ] 2>/dev/null && [ "$LEITURA_INI" != "$LEITURA_FIM" ]; then
    local dur_noite=$(( (LEITURA_FIM - LEITURA_INI + 1440) % 1440 ))
    if [ "$LEITURA_RAMPA_MIN" -gt "$dur_noite" ] || [ "$LEITURA_RAMPA_MIN" -gt $(( 1440 - dur_noite )) ]; then
      meow_aviso "LEITURA_RAMPA_MIN=$LEITURA_RAMPA_MIN é maior que a janela (${dur_noite}min ligada / $(( 1440 - dur_noite ))min desligada) — a rampa não chega ao fim"
    fi
  fi
  return "$MEOW_OK"
}

cmd_aplicar() {
  if [ -z "$LEITURA_AGENDA" ]; then
    meow_info "LEITURA_AGENDA vazio — o modo de leitura é seu; não escrevo nada"
    return "$MEOW_OK"
  fi
  case "$LEITURA_AGENDA" in
    sim|nao|não) ;;
    *) meow_erro "LEITURA_AGENDA='$LEITURA_AGENDA' — esperado sim, nao ou vazio"
       return "$MEOW_ERRO" ;;
  esac

  if [ "$LEITURA_AGENDA" != "sim" ]; then
    LEITURA_FASE="desligado"
    _leitura_gravar 0 "0.00" "LEITURA_AGENDA=\"$LEITURA_AGENDA\" — modo de leitura desligado"
    local rc=$?
    [ "$rc" = "$MEOW_OK" ] && meow_ok "modo de leitura já estava desligado (0 / 0.00)"
    return "$rc"
  fi

  _leitura_resolver_agenda || return $?

  if [ "$LEITURA_APPLET_DIZ" = "nao" ]; then
    meow_info "o applet diz 'Agendar: desligado' — os sliders mandam, não escrevo nada"
    return "$LEITURA_DELA"
  fi

  _leitura_resolver_alvo
  _leitura_alvo_agora || { meow_erro "não consegui calcular o degrau da hora"; return "$MEOW_ERRO"; }
  _leitura_dizer_fonte info

  _leitura_gravar "$LEITURA_ALVO_T" "$LEITURA_ALVO_X" "$LEITURA_FASE"
  local rc=$?
  if [ "$rc" = "$MEOW_OK" ]; then
    meow_ok "modo de leitura já no degrau da hora ($LEITURA_FASE: ${LEITURA_ALVO_T}K / $LEITURA_ALVO_X)"
  fi
  return "$rc"
}

cmd_conferir() {
  # shellcheck disable=SC2034
  MEOW_SECO=1
  if [ -z "$LEITURA_AGENDA" ]; then
    meow_pula "LEITURA_AGENDA vazio — nada a conferir (o modo de leitura é seu)"
    return "$MEOW_OK"
  fi
  case "$LEITURA_AGENDA" in
    sim|nao|não) ;;
    *) meow_erro "LEITURA_AGENDA='$LEITURA_AGENDA' — esperado sim, nao ou vazio"
       return "$MEOW_ERRO" ;;
  esac

  local alvo_t alvo_x
  if [ "$LEITURA_AGENDA" != "sim" ]; then
    alvo_t=0; alvo_x="0.00"; LEITURA_FASE="desligado"
  else
    _leitura_resolver_agenda || return $?
    if [ "$LEITURA_APPLET_DIZ" = "nao" ]; then
      meow_pula "o applet desligou o 'Agendar' — o degrau é o que você arrastou"
      return "$LEITURA_DELA"
    fi
    _leitura_resolver_alvo
    _leitura_alvo_agora || { meow_erro "não consegui calcular o degrau da hora"; return "$MEOW_ERRO"; }
    alvo_t="$LEITURA_ALVO_T"; alvo_x="$LEITURA_ALVO_X"
    _leitura_avisar_chaves
    _leitura_dizer_fonte pula
  fi

  _leitura_no_disco
  local ok_t=1 ok_x=1
  _leitura_mesmo_numero "$LEITURA_DISCO_T" "$alvo_t" && ok_t=0
  _leitura_mesmo_numero "$LEITURA_DISCO_X" "$alvo_x" && ok_x=0

  if [ "$ok_t" = "0" ] && [ "$ok_x" = "0" ]; then
    meow_ok "modo de leitura conforme ($LEITURA_FASE: ${alvo_t}K / $alvo_x)"
    return "$MEOW_OK"
  fi
  meow_muda "modo de leitura divergente ($LEITURA_FASE): disco=${LEITURA_DISCO_T:-<ausente>}K/${LEITURA_DISCO_X:-<ausente>}, a hora pede ${alvo_t}K/$alvo_x"
  meow_aviso "os dois sliders do applet escrevem NAS MESMAS chaves."
  meow_aviso "se foi você quem arrastou, desligue o 'Agendar' no applet — ou"
  meow_aviso "esvazie LEITURA_AGENDA no meow.conf. Com o relógio armado, ele"
  meow_aviso "devolve o valor da hora no próximo minuto."
  return "$MEOW_DIVERGENTE"
}

_leitura_col() { printf '%-22s' "$1"; }

cmd_estado() {
  meow_info "$(_leitura_col "meow.conf") LEITURA_AGENDA=\"${LEITURA_AGENDA:-}\" rampa=${LEITURA_RAMPA_MIN}min"
  meow_info "$(_leitura_col "alvo do conf") ${LEITURA_TEMPERATURA}K / ${LEITURA_TEXTURA}"

  if [ -z "$LEITURA_AGENDA" ]; then
    meow_pula "LEITURA_AGENDA vazio — o MeowSystem não agenda nada; segue o diagnóstico"
  fi

  if _leitura_resolver_agenda; then
    _leitura_avisar_chaves
    _leitura_dizer_fonte info
    case "$LEITURA_APPLET_DIZ" in
      sim) meow_info "quem manda agora: o relógio (o applet quer o agendamento)" ;;
      nao) meow_pula "quem manda agora: OS SLIDERS — o applet desligou o 'Agendar'" ;;
      *)   meow_pula "quem manda agora: o relógio (o applet ainda não gravou o 'Agendar')" ;;
    esac
    _leitura_resolver_alvo
    if [ "$LEITURA_FONTE_ALVO_T" = "applet" ] || [ "$LEITURA_FONTE_ALVO_X" = "applet" ]; then
      meow_info "$(_leitura_col "alvo que vale") ${LEITURA_TEMPERATURA}K ($LEITURA_FONTE_ALVO_T) / ${LEITURA_TEXTURA} ($LEITURA_FONTE_ALVO_X) — os sliders mandam no QUANTO"
    fi
    if _leitura_alvo_agora; then
      meow_info "$(_leitura_col "agora são")$(_leitura_hhmm "$LEITURA_AGORA") — fase: $LEITURA_FASE (fração $LEITURA_ALVO_F)"
      meow_info "$(_leitura_col "o relógio pede")temperatura=${LEITURA_ALVO_T}  textura=${LEITURA_ALVO_X}"
    fi
  fi

  _leitura_no_disco
  local k v
  for k in leitura_temperatura leitura_textura leitura_agenda leitura_hora_inicio leitura_hora_fim; do
    if v="$(_leitura_cru "$LEITURA_BASE/$k")"; then
      meow_info "$(_leitura_col "$k")= $v"
    else
      meow_pula "$(_leitura_col "$k")= <ausente>"
    fi
  done

  if [ -x "$LEITURA_APPLET_BIN" ]; then
    meow_ok "$(_leitura_col "applet: binário")$LEITURA_APPLET_BIN"
  else
    meow_pula "$(_leitura_col "applet: binário")ausente — o conserto do doctor o compila"
  fi
  if [ -f "$LEITURA_APPLET_SOMBRA" ]; then
    meow_ok "$(_leitura_col "applet: .desktop")$LEITURA_APPLET_SOMBRA"
  else
    meow_pula "$(_leitura_col "applet: .desktop")ausente — o painel não tem o que abrir"
  fi
  if grep -qs "\"$LEITURA_APPLET_ID\"" "$LEITURA_APPLET_ASA"; then
    meow_ok "$(_leitura_col "applet: na topbar")citado no plugins_wings"
  elif grep -qs "\"$LEITURA_APPLET_ID\"" "$LEITURA_APPLET_MEIO"; then
    meow_ok "$(_leitura_col "applet: na topbar")citado no plugins_center"
  else
    meow_pula "$(_leitura_col "applet: na topbar")fora das asas e do meio (a ordem dos applets é de quem usa)"
  fi

  if [ -r "$LEITURA_COMP" ]; then
    if grep -aqs "$LEITURA_MARCADOR" "$LEITURA_COMP"; then
      meow_ok "$(_leitura_col "cosmic-comp no disco")sabe ler leitura_* ($LEITURA_MARCADOR presente)"
    else
      meow_pula "$(_leitura_col "cosmic-comp no disco")NÃO sabe ler leitura_* — falta a etapa 1 (o patch do compositor: meow compositor)"
    fi
  fi
  local pid=""
  if ! meow_tem pgrep; then
    meow_pula "$(_leitura_col "a sessão viva")sem pgrep nesta máquina — não dá para dizer"
  else
    pid="$(pgrep -x cosmic-comp 2>/dev/null | head -1)"
    if [ -z "$pid" ]; then
      meow_aviso "cosmic-comp não está rodando — nada desenha esta tela"
    elif grep -aqs "$LEITURA_MARCADOR" "/proc/$pid/exe"; then
      meow_ok "$(_leitura_col "a sessão viva")roda um cosmic-comp que sabe ler (PID $pid)"
    else
      meow_pula "$(_leitura_col "a sessão viva")roda um cosmic-comp SEM o modo de leitura (PID $pid)"
      meow_info "  escrever a chave hoje é inofensivo e passa a valer no PRÓXIMO LOGIN."
    fi
  fi

  if meow_tem systemctl && [ -d "/run/user/$(id -u)/systemd" ]; then
    local ativo; ativo="$(systemctl --user is-active "$LEITURA_TIMER" 2>/dev/null)"
    case "$ativo" in
      active) meow_ok "$(_leitura_col "$LEITURA_TIMER")armado — próximo tique em menos de 1 min" ;;
      *)      meow_pula "$(_leitura_col "$LEITURA_TIMER")${ativo:-ausente} — ninguém vai virar o degrau sozinho" ;;
    esac
  else
    meow_pula "$(_leitura_col "$LEITURA_TIMER")sem systemd --user aqui — não dá para dizer se está armado"
  fi
  return "$MEOW_OK"
}

cmd_remover() {
  LEITURA_FASE="desligado"
  _leitura_gravar 0 "0.00" "modo de leitura removido"
  local rc=$?
  [ "$rc" = "$MEOW_OK" ] && meow_ok "os dois números já estavam em 0"

  if meow_tem systemctl && [ -d "/run/user/$(id -u)/systemd" ]; then
    if meow_seco; then
      meow_muda "desarmaria o $LEITURA_TIMER"
    elif [ "$(systemctl --user is-enabled "$LEITURA_TIMER" 2>/dev/null)" = "enabled" ] ||
         [ "$(systemctl --user is-active  "$LEITURA_TIMER" 2>/dev/null)" = "active" ]; then
      if systemctl --user disable --now "$LEITURA_TIMER" >/dev/null 2>&1; then
        meow_muda "$LEITURA_TIMER desarmado"
      else
        meow_aviso "não consegui desarmar o $LEITURA_TIMER"
      fi
      rc="$MEOW_DIVERGENTE"
    fi
  fi
  meow_seco || meow_registrar "leitura.sh remover rc=$rc"
  return "$rc"
}

cmd_adotar() {
  local chave v m r rc="$MEOW_OK"
  if [ "$#" -eq 0 ]; then
    meow_erro "uso: leitura.sh adotar CHAVE..."; return "$MEOW_ERRO"
  fi
  for chave in "$@"; do
    case "$chave" in
      LEITURA_TEMPERATURA)
        v="$LEITURA_TEMPERATURA"
        case "$v" in ""|*[!0-9]*) meow_aviso "$chave='$v' não é kelvin inteiro"; continue ;; esac
        if [ "$v" -lt "$LEITURA_PISO" ] || [ "$v" -gt "$LEITURA_NEUTRO" ]; then
          meow_aviso "$chave=$v fora de $LEITURA_PISO..$LEITURA_NEUTRO"; continue
        fi
        meow_escrever "$LEITURA_K_ULT_T" "$v" 644 ;;
      LEITURA_TEXTURA)
        v="$LEITURA_TEXTURA"
        case "$v" in ""|*[!0-9.]*) meow_aviso "$chave='$v' não é número com ponto"; continue ;; esac
        LC_ALL=C awk -v x="$v" 'BEGIN{ exit !(x >= 0 && x <= 1) }' \
          || { meow_aviso "$chave=$v fora de 0..1"; continue; }
        meow_escrever "$LEITURA_K_ULT_X" "$v" 644 ;;
      LEITURA_AGENDA)
        case "$LEITURA_AGENDA" in
          sim) v=true ;;
          nao) v=false ;;
          *) continue ;;
        esac
        meow_escrever "$LEITURA_K_AGENDA" "$v" 644 ;;
      LEITURA_HORARIO_INICIO|LEITURA_HORARIO_FIM)
        if [ "$chave" = LEITURA_HORARIO_INICIO ]; then v="$LEITURA_HORARIO_INICIO"; else v="$LEITURA_HORARIO_FIM"; fi
        m="$(_leitura_minutos "$v")" || { meow_aviso "$chave='$v' não é HH:MM"; continue; }
        if [ "$chave" = LEITURA_HORARIO_INICIO ]; then
          meow_escrever "$LEITURA_K_INI" "\"$(_leitura_hhmm "$m")\"" 644
        else
          meow_escrever "$LEITURA_K_FIM" "\"$(_leitura_hhmm "$m")\"" 644
        fi ;;
      *) meow_aviso "$chave não é guardada pelo controle do painel"; continue ;;
    esac
    r=$?
    case "$r" in
      "$MEOW_OK") ;;
      "$MEOW_DIVERGENTE") meow_muda "$chave: o controle do painel passa a guardar o mesmo valor"
                          rc="$MEOW_DIVERGENTE" ;;
      *) meow_erro "não consegui gravar o lugar de $chave"; return "$MEOW_ERRO" ;;
    esac
  done
  meow_seco || meow_registrar "leitura.sh adotar $* rc=$rc"
  return "$rc"
}

case "${1:-aplicar}" in
  aplicar|tique) cmd_aplicar ;;
  conferir)      cmd_conferir ;;
  estado)        cmd_estado ;;
  remover)       cmd_remover ;;
  adotar)        shift; cmd_adotar "$@" ;;
  *) meow_erro "uso: leitura.sh {aplicar|conferir|estado|remover|adotar CHAVE...}"; exit "$MEOW_ERRO" ;;
esac

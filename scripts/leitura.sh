#!/usr/bin/env bash
# leitura.sh — o horário liga o modo de leitura sozinho, e o desliga sozinho.
#
#   A cada tique ele pergunta "que horas são?" e "que degrau o relógio pede?", e
#   põe DOIS números no disco:
#       ~/.config/cosmic/com.system76.CosmicComp/v1/leitura_temperatura   (Kelvin)
#       ~/.config/cosmic/com.system76.CosmicComp/v1/leitura_textura       (0.0..1.0)
#   Quem PINTA é o `cosmic-comp` recompilado. Este
#   arquivo não pinta um pixel, não fala Wayland, não reinicia nada e não toca em
#   binário nenhum.
#
# Aposentá-lo era a etapa 4 do plano, de outro dono.
#
# 4. RON ACEITA `0` ONDE ESPERA f32 — conferido em `ron-0.11.0/src/parse.rs:852`
#    (`T::parse(&f)` = `f32::from_str`), que é a versão que o `Cargo.lock` do
#    `cosmic-comp` pina. Mesmo assim este script escreve SEMPRE com casa decimal
#    (`0.00`, `0.35`): custa nada e tira uma ambiguidade do caminho.
# Com o «Agendar» desligado no applet este script não escreve NADA, nem 0: zerar
# desfaria a temperatura que ela acabou de arrastar. A rampa vai DEPOIS da hora.
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# VAZIO = NÃO TOCA. É o contrato inteiro deste arquivo; ver o cabeçalho.
LEITURA_AGENDA="${LEITURA_AGENDA:-}"
# Os padrões abaixo só valem quando a chave do applet não existe. Estão aqui E no
# meow.conf.exemplo, com o mesmo valor, de propósito: o exemplo é o que ela lê, e
# este é o que vale numa máquina cujo conf ainda não tem a linha.
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

# As três peças do applet. Só LIDAS aqui: quem as instala e confere é o
# `scripts/leitura_build.sh`, e o `plugins_wings` não é escrito por script
# nenhum deste projeto (docs/FRONTEIRA.md).
LEITURA_APPLET_ID="com.meowsystem.AppletLeitura"
LEITURA_APPLET_BIN="$HOME/.local/bin/meow-applet-leitura"
LEITURA_APPLET_SOMBRA="${XDG_DATA_HOME:-$HOME/.local/share}/applications/$LEITURA_APPLET_ID.desktop"
# Os DOIS arquivos da topbar: `plugins_wings` é o par de asas, `plugins_center`
# é o meio — e um applet arrastado para o meio em Ajustes só aparece no segundo.
LEITURA_APPLET_ASA="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel.Panel/$(meow_cosmic_v com.system76.CosmicPanel.Panel)/plugins_wings"
LEITURA_APPLET_MEIO="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel.Panel/$(meow_cosmic_v com.system76.CosmicPanel.Panel)/plugins_center"

# `Config::new_state(NS_ESTADO, 1)` do libcosmic escreve em
# ~/.local/state/cosmic/<id>/v1/.
LEITURA_ESTADO_BASE="${XDG_STATE_HOME:-$HOME/.local/state}/cosmic/$LEITURA_APPLET_ID/v1"
LEITURA_K_ULT_T="$LEITURA_ESTADO_BASE/ultima_temperatura"
LEITURA_K_ULT_X="$LEITURA_ESTADO_BASE/ultima_textura"

LEITURA_COMP="$(meow_cosmic_comp_disco)"   # o do próximo login (build do shim ou /usr/bin)
LEITURA_MARCADOR="AURORA-READING-MODE"
# O `LEITURA_NIGHTLIGHT` (o `/var/lib/aurora/night-light-temp`) saiu — ver
# o bloco "O NIGHT LIGHT DA AURORA" no `cmd_estado`.
LEITURA_TIMER="meow-leitura.timer"

# 6500K é o NEUTRO e o topo da faixa. 1000K é o fundo da tabela WHITEPOINTS do
# redshift que o aurora-night-light.py já carrega.
LEITURA_NEUTRO=6500
LEITURA_PISO=1000
# 4 = "divergente por escolha dela". O `rotulo_rc` do bin/meow o pinta `--`,
# igual ao 3, porque a leitura é a mesma para quem olha: não há nada que o
# auto-reparo deva fazer aqui.
LEITURA_DELA=4

# --- leitura crua de uma chave do cosmic-config -----------------------------
# Apara espaço, tira as aspas de string RON, apara de novo. Devolve 1 quando o
# arquivo não existe ou está vazio — que é o mesmo caso para quem chama: não há
# valor a considerar.
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

# "18:00" -> 1080. Também aceita o inteiro de minutos: o applet grava `"18:00"`,
# mas quem edita o arquivo à mão pode escrever 1080, e recusar isso seria
# recusar por nada. Falha (1) em qualquer outra coisa.
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

# --- quem manda no horário --------------------------------------------------
LEITURA_FONTE=""        # applet | padrao | misto
LEITURA_FONTE_INI=""    # applet | meow.conf
LEITURA_FONTE_FIM=""
LEITURA_INI=0
LEITURA_FIM=0
LEITURA_APPLET_DIZ=""   # "" (ausente) | sim | nao

# UMA ponta do horário: a chave do applet quando ela existe e é legível, o
# padrão do meow.conf quando não.
#
# ASSINA EM GLOBAIS EM VEZ DE ECOAR, e isso não é gosto: `X="$(_ponta …)"` roda
# a função num SUBSHELL, e a origem ("veio do applet ou do conf?") morreria
# junto com ele — que é metade do que esta função tem para dizer.
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
      # O applet declara o campo como `bool` e grava `true`/`false` pelados —
      # conferido, em src/applets/leitura/src/main.rs.
      true|"Some(true)")   LEITURA_APPLET_DIZ="sim" ;;
      false|"Some(false)") LEITURA_APPLET_DIZ="nao" ;;
    esac
  fi
  return "$MEOW_OK"
}

# --- de onde vem o ALVO dos dois números ------------------------------------
#
#   "o negócio fica mudando de temperatura sozinho sem respeitar a temperatura
#   que eu defini."
#
# Estava certíssima, e a conta é de um minuto: o `meow-leitura.timer` bate
# `*-*-* *:*:00`, e cada tique gravava `LEITURA_TEMPERATURA` do meow.conf.
#
#   "com agendamento ligado ele sempre vai reproduzir essa funcionalidade tal
#   horário apenas. Mas respeitando os sliders."
LEITURA_FONTE_ALVO_T=""   # applet | meow.conf
LEITURA_FONTE_ALVO_X=""   # applet | meow.conf

_leitura_resolver_alvo() {
  local v
  LEITURA_FONTE_ALVO_T="meow.conf"
  LEITURA_FONTE_ALVO_X="meow.conf"

  # O portão é o mesmo do `_leitura_alvo_agora`: inteiro que não é inteiro, ou
  # fora de 1000..6500, não vira alvo — cai no conf em silêncio, e quem AVISA é
  # o `conferir`.
  if v="$(_leitura_cru "$LEITURA_K_ULT_T")"; then
    case "$v" in
      ""|*[!0-9]*) ;;
      *) if [ "$v" -ge "$LEITURA_PISO" ] && [ "$v" -le "$LEITURA_NEUTRO" ]; then
           LEITURA_TEMPERATURA="$v"; LEITURA_FONTE_ALVO_T="applet"
         fi ;;
    esac
  fi

  # `LC_ALL=C` pelo mesmo motivo dos outros dois awk deste arquivo: em pt_BR a
  # conversão de string para número segue a locale, e um `0.35` viraria 0.
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

# --- os alvos, e a conta da rampa -------------------------------------------
# Ecoa "<temperatura> <textura> <fração> <fase>".
LEITURA_ALVO_T=0
LEITURA_ALVO_X="0.00"
LEITURA_ALVO_F="0.00"
LEITURA_FASE=""
LEITURA_AGORA=0

_leitura_alvo_agora() {
  local t="$LEITURA_TEMPERATURA" x="$LEITURA_TEXTURA" n="$LEITURA_RAMPA_MIN" saida
  LEITURA_AGORA="$(_leitura_minutos "$(date +%H:%M)")" || return "$MEOW_ERRO"

  # O awk não recusa lixo, ele o CONVERTE — e o que ele converte depende de o
  # texto "parecer número", o que muda a conta inteira sem dar erro.
  #
  # MEDIDO, com `LEITURA_RAMPA_MIN="abc"`: o mawk compara string com número por
  # STRING, então `n <= 0` deu falso ("a" > "0") e o ramo da rampa rodou com n
  # valendo 0.
  #
  # Continua virando 0, mas agora é o `conferir` que diz por quê.
  case "$t" in ""|*[!0-9]*)  t="$LEITURA_NEUTRO" ;; esac
  case "$x" in ""|*[!0-9.]*) x=0 ;; esac
  case "$n" in ""|*[!0-9]*)  n=0 ;; esac

  # `LC_ALL=C`: em pt_BR o awk gravaria `0,35`, e o cosmic-config devolve 0 calado.
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

# 0 = os dois são o mesmo número até a segunda casa. Existe por causa de um caso
# concreto: o applet grava `0.4` e este script grava `0.40`. Um `[ "$a" = "$b" ]`
# — e o próprio `meow_escrever`, que compara por conteúdo — chamaria isso de
# divergência e reescreveria a chave, acordando o compositor de graça.
#
# A FRASE ANTERIOR DIZIA "divergência ETERNA, a cada minuto", E ISSO ERA DEMAIS
#   MEDIDO em 31/08/2026, chamando o `meow_escrever` três vezes com `0.40` sobre
#   um disco que tinha `0.4`: ele escreveu UMA vez e as outras duas devolveram 0
#   com o mesmo inode. Depois da primeira o disco já diz `0.40` e ele se cala. O
#   que esta função evita, então, não é um laço — é a normalização silenciosa do
#   número que ELA arrastou: sem ela, o `0.4` do applet vira `0.40` do script na
#   primeira virada, e o valor no disco deixa de ser o que ela pôs lá. Verificado
#   nos dois sentidos no mesmo dia: com a função, três tiques seguidos deixam o
#   `0.4` intacto.
_leitura_mesmo_numero() {
  local a="${1:-}" b="${2:-}"
  # OS DOIS PORTÕES VÊM PRIMEIRO, E A ORDEM É O CONTRATO
  #   O que NÃO é número não é "o mesmo número", ainda que os bytes batam. Em
  #   31/08/2026 o atalho de baixo estava ACIMA destes dois `case` e alargava o
  #   contrato sem querer: `abc` contra `abc` passou a responder "mesmo número",
  #   quando antes respondia "diferentes". Inalcançável hoje (o segundo argumento
  #   é sempre saída do awk ou um literal deste arquivo), mas apertar custou
  #   trocar duas linhas de lugar: `case` é builtin, não nasce processo nenhum, e
  #   o atalho continua valendo para todo número.
  case "$a" in ""|*[!0-9.+-]*) return 1 ;; esac
  case "$b" in ""|*[!0-9.+-]*) return 1 ;; esac
  # ATALHO PARA O CASO QUE ACONTECE 1438 VEZES POR DIA: byte a byte igual é o
  # mesmo número, e nenhum awk precisa nascer para descobrir isso. O tique em
  # repouso chamava esta função duas vezes e pagava dois `fork`+`exec` de mawk
  # para comparar "3500" com "3500" e "0.35" com "0.35" — ~2880 processos por
  # dia numa unidade que o `meow-leitura.timer` já mede em 26ms. O awk continua
  # aí embaixo, e é ele quem faz o trabalho de verdade: `0.4` (do applet) contra
  # `0.40` (daqui) são strings diferentes e o mesmo número.
  [ "$a" = "$b" ] && return 0
  # `LC_ALL=C` pelo mesmo motivo do `_leitura_alvo_agora`: em pt_BR o awk lê
  # `0.35` como 0 e `0,35` como 0,35 — e a comparação diria "diferente" para
  # sempre, reescrevendo a chave a cada minuto.
  LC_ALL=C awk -v a="$a" -v b="$b" 'BEGIN{ exit ((a-b) < 0.005 && (b-a) < 0.005) ? 0 : 1 }'
}

_leitura_no_disco() {
  LEITURA_DISCO_T="$(_leitura_cru "$LEITURA_K_TEMP")" || LEITURA_DISCO_T=""
  LEITURA_DISCO_X="$(_leitura_cru "$LEITURA_K_TEXT")" || LEITURA_DISCO_X=""
}
LEITURA_DISCO_T=""
LEITURA_DISCO_X=""

# Grava os dois números, e só o que MUDOU. Devolve 0 (já estava assim), 1
# (escreveu, ou escreveria no seco) ou 2.
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
      # O registro no meow.log é condicionado ao que MUDOU, e não ao tique. Um
      # `meow_registrar` incondicional aqui daria 1440 linhas por dia num arquivo
      # que o `meow log` mostra — o log viraria só isto.
      meow_registrar "leitura.sh temp=$temp textura=$text fase=${LEITURA_FASE:-$motivo}"
    fi
    return "$MEOW_DIVERGENTE"
  fi
  return "$MEOW_OK"
}

# A frase de "de onde veio o horário". `meow_info` de propósito: o
# `LOG_NIVEL=silencioso` da unidade systemd a cala, e ela reaparece inteira
# quando alguém roda o comando na mão, no `conferir` e no `estado`.
_leitura_dizer_fonte() {
  local diz="${1:-info}"
  local janela; janela="das $(_leitura_hhmm "$LEITURA_INI") às $(_leitura_hhmm "$LEITURA_FIM")"
  case "$LEITURA_FONTE" in
    applet)
      "meow_$diz" "horário do applet (leitura_hora_inicio/fim): $janela" ;;
    misto)
      # O estado de "ela arrastou UM slider só". Dizer de qual ponta veio cada
      # número é o que impede a pergunta "por que a janela não é a que eu
      # marquei?" — as duas metades estão certas, e vêm de lugares diferentes.
      #
      # A FRASE ANTIGA ERA `início: applet, fim: meow.conf`, E ISSO PEDIA UMA
      # TRADUÇÃO QUE NÃO É DELA (31/08/2026)
      #   Duas palavras de ARQUITETURA — onde o valor MORA — para descrever uma
      #   coisa que ela fez com o dedo. A irmã de baixo já falava certo ("o
      #   applet ainda não gravou horário"), e esta destoava: agora as duas dizem
      #   o que ACONTECEU. Qual ponta veio do applet é decidido no `if`, e não
      #   escrito à mão, porque `misto` só existe quando exatamente uma veio.
      local ponta="o início"
      [ "$LEITURA_FONTE_INI" = "applet" ] || ponta="o fim"
      "meow_$diz" "o applet gravou só $ponta — a outra ponta vem do PADRÃO do meow.conf ($janela)" ;;
    *)
      # "não gravou", e não "não existe": desde 30/08/2026 o applet existe, e o
      # que falta é ela ter mexido no horário — ele só escreve o que ela muda.
      # Dizer "não existe" mandaria procurar um binário que está instalado.
      "meow_$diz" "o applet ainda não gravou horário — usando o PADRÃO do meow.conf: $janela" ;;
  esac
}

# --- os avisos das chaves do meow.conf --------------------------------------
# O awk APARA em silêncio o que não entende (ver o portão do `_leitura_alvo_agora`);
# esta função é a única coisa na máquina que DIZ que aparou. Ela não mora no
# `aplicar` porque o `aplicar` roda 1440 vezes por dia pelo timer, e um aviso que
# aparece 1440 vezes por dia é um aviso que se aprende a ignorar.
#
# ELA PRECISA ESTAR NOS DOIS COMANDOS, E ESTAVA SÓ NO QUE ELA NÃO RODA (31/08/2026)
#   `meow leitura` SEM VERBO cai no `estado` (o `cmd_leitura` do `bin/meow` usa
#   `${1:-estado}`); o `conferir` é o que o doctor das 05:00 despeja para dentro
#   de um log. Ou seja, os três avisos escritos ontem nasceram no comando que ela
#   não digita. MEDIDO no mesmo dia, com `LEITURA_TEXTURA="0,35"` no meow.conf —
#   a vírgula do teclado pt_BR dela, o erro de digitação mais provável deste
#   arquivo inteiro: o `estado` imprimia `alvo do conf  3500K / 0,35` e, três
#   linhas abaixo, `o relógio pede  temperatura=3500  textura=0.00`, sem uma
#   palavra ligando as duas. A frase existia e estava no outro comando.
#
# NÃO ESCREVE NADA — quatro `case`, um `awk` de comparação e `meow_aviso`. É essa
# ausência que permite chamá-la do `estado`, que é leitura pura por contrato.
#
# PRECONDIÇÃO DO ÚLTIMO AVISO: `LEITURA_INI`/`LEITURA_FIM` já resolvidos, isto é,
# chamada DEPOIS do `_leitura_resolver_agenda` — que é o que os dois chamadores
# fazem. Chamada antes, as duas pontas valem 0, a janela mede zero e o aviso da
# rampa se cala sozinho: exatamente a falha silenciosa que este arquivo caça.
_leitura_avisar_chaves() {
  case "$LEITURA_TEMPERATURA" in
    ""|*[!0-9]*) meow_aviso "LEITURA_TEMPERATURA='$LEITURA_TEMPERATURA' não é um inteiro — tratada como ${LEITURA_NEUTRO}K (desligado)" ;;
    *) if [ "$LEITURA_TEMPERATURA" -lt "$LEITURA_PISO" ] || [ "$LEITURA_TEMPERATURA" -gt "$LEITURA_NEUTRO" ]; then
         meow_aviso "LEITURA_TEMPERATURA=$LEITURA_TEMPERATURA está fora de ${LEITURA_PISO}–${LEITURA_NEUTRO}K — aparada"
       fi ;;
  esac
  # A VÍRGULA É A PIOR DAS TRÊS: `LEITURA_TEXTURA="0,35"` vira 0 lá dentro (o awk
  # sob `LC_ALL=C` não lê vírgula) e o papel fica desligado PARA SEMPRE, sem nada
  # na tela para acusar — nem erro, nem valor estranho, só um recurso que não
  # aparece. As outras duas ao menos mudam um número visível.
  case "$LEITURA_TEXTURA" in
    ""|*[!0-9.]*) meow_aviso "LEITURA_TEXTURA='$LEITURA_TEXTURA' não é um decimal com PONTO — tratada como 0 (sem papel)" ;;
    *) if ! LC_ALL=C awk -v v="$LEITURA_TEXTURA" 'BEGIN{ exit (v <= 1) ? 0 : 1 }'; then
         meow_aviso "LEITURA_TEXTURA=$LEITURA_TEXTURA está fora de 0.0–1.0 — aparada"
       fi ;;
  esac
  case "$LEITURA_RAMPA_MIN" in
    ""|*[!0-9]*) meow_aviso "LEITURA_RAMPA_MIN='$LEITURA_RAMPA_MIN' não é um inteiro de minutos — tratada como 0 (virada seca)" ;;
  esac
  # A rampa que não cabe na janela não é erro, é uma escolha que entrega menos do
  # que promete: o degrau nunca chega ao valor cheio, e o `estado` mostra a fração
  # parando no meio. Dizê-lo é mais barato que ela descobrir olhando a tela e não
  # sabendo o que perguntar.
  if [ "$LEITURA_RAMPA_MIN" -gt 0 ] 2>/dev/null && [ "$LEITURA_INI" != "$LEITURA_FIM" ]; then
    local dur_noite=$(( (LEITURA_FIM - LEITURA_INI + 1440) % 1440 ))
    if [ "$LEITURA_RAMPA_MIN" -gt "$dur_noite" ] || [ "$LEITURA_RAMPA_MIN" -gt $(( 1440 - dur_noite )) ]; then
      meow_aviso "LEITURA_RAMPA_MIN=$LEITURA_RAMPA_MIN é maior que a janela (${dur_noite}min ligada / $(( 1440 - dur_noite ))min desligada) — a rampa não chega ao fim"
    fi
  fi
  return "$MEOW_OK"
}

# --- aplicar ----------------------------------------------------------------
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

  # DESLIGAR TEM DE DESLIGAR: os números voltam a 0. Quem desarma o timer é o
  # `install.sh` (etapa_leitura) e o `remover` daqui — não este caminho, porque
  # um `aplicar` disparado PELO timer que desarma o próprio timer é a receita de
  # unidade que morre no meio de si mesma.
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

# --- conferir (leitura pura; é o que o doctor chama) ------------------------
cmd_conferir() {
  # ESTRUTURAL, E NÃO POR INSPEÇÃO: o `bin/meow:35` promete que "nenhum caminho
  # de `doctor` sem `--consertar` escreve", e hoje esse caminho passa por aqui.
  # Nenhuma linha desta função chama um escritor — mas a próxima que alguém
  # acrescentar não sabe disso, e com o seco ligado ela cai no `meow_escrever`
  # que devolve 1 sem tocar no disco. É o mesmo `MEOW_SECO=1` do
  # `terminal.sh:285` e do `wallpaper.sh:1567`, pelo mesmo motivo.
  # shellcheck disable=SC2034  # quem lê MEOW_SECO é o meow_seco() do comum.sh
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
  # "COM O RELÓGIO ARMADO" NÃO É ENFEITE — A FRASE ANTERIOR PROMETIA DEMAIS
  #   Ela dizia, seco, "senão o timer devolve o valor da hora no próximo minuto",
  #   e isso é FALSO em toda máquina onde o timer não está armado: `AUTO_REPARO`
  #   desligado, sessão sem `systemd --user`, máquina onde o `install.sh` nunca
  #   passou, e qualquer `meow leitura conferir` rodado na mão nessas condições —
  #   que é justamente quando alguém está lendo esta linha. Prometer um conserto
  #   automático que não vem é mandá-la esperar por nada, e esperar por nada é
  #   como este projeto perde uma tarde. Quem sabe se o relógio está armado é o
  #   `estado`, que responde isso na última linha (31/08/2026).
  meow_aviso "os dois sliders do applet escrevem NAS MESMAS chaves."
  meow_aviso "se foi você quem arrastou, desligue o 'Agendar' no applet — ou"
  meow_aviso "esvazie LEITURA_AGENDA no meow.conf. Com o relógio armado, ele"
  meow_aviso "devolve o valor da hora no próximo minuto."
  return "$MEOW_DIVERGENTE"
}

# --- estado (read-only, e é o comando de responder "por quê?") --------------
_leitura_col() { printf '%-22s' "$1"; }

cmd_estado() {
  meow_info "$(_leitura_col "meow.conf") LEITURA_AGENDA=\"${LEITURA_AGENDA:-}\" rampa=${LEITURA_RAMPA_MIN}min"
  meow_info "$(_leitura_col "alvo do conf") ${LEITURA_TEMPERATURA}K / ${LEITURA_TEXTURA}"

  if [ -z "$LEITURA_AGENDA" ]; then
    meow_pula "LEITURA_AGENDA vazio — o MeowSystem não agenda nada; segue o diagnóstico"
  fi

  if _leitura_resolver_agenda; then
    # COLADO NO `alvo do conf`, e é aí que ele serve: é a linha de cima que
    # mostra o `0,35` e é este aviso que diz por que ele vira 0. Vem antes do
    # `dizer_fonte` justamente para não deixar as duas se separarem de novo.
    # Depois do resolver por causa da precondição da janela — ver a função.
    _leitura_avisar_chaves
    _leitura_dizer_fonte info
    case "$LEITURA_APPLET_DIZ" in
      sim) meow_info "quem manda agora: o relógio (o applet quer o agendamento)" ;;
      nao) meow_pula "quem manda agora: OS SLIDERS — o applet desligou o 'Agendar'" ;;
      *)   meow_pula "quem manda agora: o relógio (o applet ainda não gravou o 'Agendar')" ;;
    esac
    _leitura_resolver_alvo
    # A linha `alvo do conf`, acima, mostra os DOIS números antes desta função
    # rodar — ou seja, mostra o conf. Esta diz de onde cada um veio DEPOIS, que é
    # a pergunta que ela fez em 31/08 ("por que muda sozinho?").
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

  # O APPLET, EM TRÊS PEÇAS QUE FALHAM SEPARADO (30/08/2026)
  #   Binário, sombra `.desktop` e a linha no `plugins_wings` da topbar. Cada uma
  #   some por um motivo diferente, então mostrar as três em linhas separadas é o
  #   que troca "o applet sumiu" por "sumiu ESTA peça". A conferência de verdade
  #   é do `scripts/leitura_build.sh --conferir`; aqui é diagnóstico, e por isso
  #   nada acende divergência.
  #
  #   NENHUMA DAS TRÊS PRECISA DE LOGOUT — e isso contraria o que este projeto
  #   vinha repetindo. MEDIDO em 30/08/2026, 05:43: o `cosmic-panel` mantém um
  #   watch de inotify no diretório `CosmicPanel.Panel/v1` (visto em
  #   `/proc/<pid>/fdinfo`, inode do diretório), e `plugins_wings` está na lista
  #   `must_recreate` do `space_container.rs` do painel. Escrever a linha
  #   RECRIOU o espaço da topbar na hora: o processo do painel manteve o mesmo
  #   PID e TODOS os applets renasceram com PIDs novos, o nosso incluído.
  #   Quem ainda espera o logout é o SHADER — o `cosmic-comp` da sessão.
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

  # AS DUAS PERGUNTAS QUE NINGUÉM VÊ HOJE, E QUE SÃO DIFERENTES: o binário do
  # DISCO sabe ler os dois números? E o processo que está desenhando a tela dela
  # AGORA sabe? Um build feito e uma sessão que não relogou são um estado normal,
  # e é justamente esse estado que faz "escrevi a chave e nada aconteceu".
  if [ -r "$LEITURA_COMP" ]; then
    if grep -aqs "$LEITURA_MARCADOR" "$LEITURA_COMP"; then
      meow_ok "$(_leitura_col "cosmic-comp no disco")sabe ler leitura_* ($LEITURA_MARCADOR presente)"
    else
      meow_pula "$(_leitura_col "cosmic-comp no disco")NÃO sabe ler leitura_* — falta a etapa 1 (o patch do compositor: meow compositor)"
    fi
  fi
  # `meow_tem pgrep` porque sem ele a resposta seria "cosmic-comp não está
  # rodando" — um diagnóstico ERRADO com cara de certo, dado justamente pelo
  # comando cujo trabalho é responder "por quê?". Sem pgrep a pergunta fica sem
  # resposta, e é isso que a linha diz.
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

  # O NIGHT LIGHT DA AURORA: A LINHA SAIU EM 24/09/2026 (P39)
  #   Aqui morava a conferência do patcher de luz noturna do Ritual da Aurora:
  #   lia a temperatura que ele guardava em `/var/lib/aurora/` e procurava o
  #   rastro do shader dele no binário, para avisar no dia em que um `apt`
  #   destravasse o patcher e as duas luzes quentes se somassem.
  #
  #   A LUZ QUENTE É DO PRODUTO E JÁ MORA AQUI: é este arquivo, com o
  #   `AURORA-READING-MODE`, que é um patch da série de `patches/` — e o build
  #   dela passou a ser o `meow compositor`, no mesmo dia. O patcher da Aurora
  #   não está no Spellbook (medido em 24/09: nenhum `*night-light*` lá), e o
  #   único que o chamava depois de instalar um build era o
  #   `aurora-cosmic-comp-ws.sh`, desativado junto. A regra de 23/09 tira o
  #   resto sem terceira via: o MeowSystem não lê o estado de outro projeto.
  #
  #   O que isto deixa de ver, dito para não virar promessa: numa máquina onde
  #   algum OUTRO programa reescreva o shader do compositor, as duas luzes
  #   voltam a se somar sem aviso daqui. O cabeçalho, item 3, tem a medição.

  # O `-d /run/user/.../systemd` é o MESMO teste do `cmd_remover` logo abaixo e
  # da `etapa_leitura` do `install.sh`, e faltava só aqui: sem barramento de
  # usuário o `systemctl --user` não devolve "inactive", devolve erro engolido pelo
  # `2>/dev/null` — e o `estado` dizia "ausente" para um timer que pode estar
  # armado numa sessão que este processo não enxerga.
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

# --- remover ----------------------------------------------------------------
# Zera os dois números E desarma o timer. As duas coisas, porque só zerar deixa o
# relógio de pé para repor o valor no minuto seguinte — o recurso pareceria
# desligado por um minuto e voltaria sozinho, que é pior que não desligar.
#
# NÃO APAGA os arquivos: `0` é conferível e é exatamente o que o Default do
# compositor vale (etapa 1, EDIÇÃO 5). É a mesma lição do `relogio.sh`, medida em
# 25/08/2026 — apagar o arquivo é um jeito de reverter que não se pode conferir.
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

# --- adotar -----------------------------------------------------------------
# O PAINEL ESCOLHEU, E O CONTROLE DA BARRA PASSA A GUARDAR O MESMO — 10/10/2026,
# P77 (achado 26 do uso real de 09/10)
#   O uso real mediu duas fontes de verdade: o painel dizia 3500 K e «Sim», a
#   máquina estava em 6300 K e «Não», e o cartão explicava «quem guarda esse
#   valor é o controle do painel; Salvar e aplicar faz este ajuste vencer». A
#   segunda metade não era verdade: o «Salvar e aplicar» grava o meow.conf, e
#   este arquivo, por desenho (o bug de 31/08, no cabeçalho do
#   `_leitura_resolver_alvo`), lê PRIMEIRO o que o applet guarda — o meow.conf
#   é o padrão de fábrica. O 3500 escolhido no painel não chegava nunca.
#
#   A cura não é o relógio voltar a sobrescrever o slider (o defeito de 31/08):
#   é o painel escrever onde a máquina lê, quando QUEM USA escolhe no painel.
#   Escolher no painel e arrastar na barra viram o mesmo gesto, e a última mão
#   vence. Este verbo é chamado pelo `servidor.py` depois de gravar o meow.conf,
#   com as chaves que o «Salvar e aplicar» levou; ele lê o valor do conf (o que
#   acabou de ser gravado) e o põe na peça do applet que guarda a mesma coisa:
#     LEITURA_TEMPERATURA     estado do applet, `ultima_temperatura`
#     LEITURA_TEXTURA         estado do applet, `ultima_textura`
#     LEITURA_AGENDA          `leitura_agenda` do CosmicComp (sim/nao; vazio,
#                             que é «não toca», não escreve nada)
#     LEITURA_HORARIO_INICIO  `leitura_hora_inicio` do CosmicComp, "HH:MM"
#     LEITURA_HORARIO_FIM     `leitura_hora_fim` do CosmicComp, "HH:MM"
#   Valor que não passa nos mesmos portões do `_leitura_resolver_alvo` não é
#   escrito: um lixo no conf não pode virar a memória do applet.
#
#   O APPLET DE PÉ RELÊ O HORÁRIO E A AGENDA NA HORA (`watch_config`); o ponto
#   dos sliders ele lê do estado ao nascer, e o relógio deste arquivo já o lê
#   do disco a cada tique — a tela segue o painel no minuto seguinte.
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

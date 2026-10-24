#!/usr/bin/env bash
# logo.sh — o mascote do dock e do painel: de dia a Coquinha, de noite o Mimir.
#
#   ./logo.sh              põe no ar o mascote que a HORA pede (e instala o acervo)
#   ./logo.sh girar        passa para o próximo mascote (só no modo `rotacao`)
#   ./logo.sh --conferir   não escreve; 1 se algo divergir
#   ./logo.sh listar       mostra o acervo, quem está no ar e por quê
#   ./logo.sh no-dock      imprime o mascote que está no botão do dock (1 = nenhum)
#   ./logo.sh applet       imprime a chave do applet de logo instalado (1 = nenhum)
#
# O QUE NÃO PRECISA DE RECICLO NENHUM: o `fastfetch`, que lê o arquivo do logo a
# cada execução.
# A porta do reciclo é o `painel.sh reciclar`, nunca um `pkill` daqui: ele recusa
# quando o supervisor demoraria a repor a barra. Matar só o applet deixa buraco no dock.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/noite.sh
. "$RAIZ/lib/noite.sh"

ACERVO="$(meow_mascote_dir)/"
COSMIC="$(meow_cosmic_dir)"
LOGOS_DIR="$COSMIC/logos"

# Instalado é o que o COSMIC acha como applet: um `.desktop` com
# `X-CosmicApplet=true` nas pastas de aplicativos do XDG, de id terminado em
# `LogoMenu` — o nome de família que o `applet_montado`, lá embaixo, já
# procura nas barras.
_applet_de_logo() {
  local dir arq
  for dir in "${XDG_DATA_HOME:-$HOME/.local/share}" \
             $(printf '%s' "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}" | tr ':' ' '); do
    for arq in "$dir"/applications/*LogoMenu.desktop; do
      grep -qsx 'X-CosmicApplet=true' "$arq" && { basename "$arq" .desktop; return 0; }
    done
  done
  return 1
}
APPLET_ID="$(_applet_de_logo)"
APPLET="$COSMIC/${APPLET_ID:-sem-applet-de-logo}/v1"
ESTADO="$MEOW_ESTADO/logo-atual"

# Vazio, vale o flavor padrão do pack no ar: o `meow_flavor` (lib/comum.sh).
# Era `${FLAVOR:-mocha}`, o padrão de um pack só.
FLAVOR="$(meow_flavor)"
LOGO="${LOGO:-$FLAVOR}"

# --- AS TRÊS MANEIRAS DE ESCOLHER O MASCOTE ------------------------------------
#
# Chave velha não vira inerte: quem tem `LOGO_ROTACAO="sim"` e não escreveu
# `LOGO_MODO` continua no modo `rotacao`.
if [ -n "${LOGO_MODO:-}" ]; then
  :
elif [ "${LOGO_ROTACAO:-nao}" = "sim" ]; then
  LOGO_MODO="rotacao"
else
  LOGO_MODO="hora"
fi

# Os nomes saem do acervo (`packs/meowsystem/mascote/<nome>.svg`). Um nome que não exista
# não é erro fatal: o script avisa e cai no `LOGO`, porque um mascote errado na
# tela é melhor que um instalador que aborta por causa de um enfeite.
LOGO_DIA="${LOGO_DIA:-mimir}"
LOGO_NOITE="${LOGO_NOITE:-coquinha}"
# `nao` troca o arquivo e NÃO recicla o painel: o mascote novo passa a valer no
# próximo login. Existe para quem não quer o pisca de ~2s, e para o dia em que
# ela estiver gravando a tela.
LOGO_RECICLAR="${LOGO_RECICLAR:-sim}"

CONFERIR=0
ACAO="aplicar"
# Até aqui ele ligava só o `CONFERIR=1`, que nenhuma linha deste arquivo lê:
# quem segura cada escrita é o `meow_seco`, e o seco só nascia de um
# `MEOW_DRY_RUN=1` de fora.
case "${1:-}" in
  --conferir)    CONFERIR=1; MEOW_SECO=1; MEOW_DRY_RUN=1; export MEOW_DRY_RUN ;;
  girar)         ACAO="girar" ;;
  girar-vencido) ACAO="girar-vencido" ;;
  listar)        ACAO="listar" ;;
  # Existe para que o `install.sh` não precise reimplementar a regra de
  # compatibilidade `LOGO_ROTACAO` -> `LOGO_MODO` acima: dois donos da mesma
  # regra é o defeito que este projeto mais persegue, e a etapa de lá precisa
  # saber qual unidade do systemd instalar.
  modo)          printf '%s\n' "$LOGO_MODO"; exit "$MEOW_OK" ;;
  # A regra é o `_esta_no_dock`, lá embaixo, que o `listar` também usa.
  no-dock)       ACAO="no-dock" ;;
  # Com o `co.uk.cappsy` instalado, o `meow logo` diria «(nenhuma)» com o
  # mascote já na chave dele; com a pasta do `dev.cappsy` sobrando, o `status`
  # mostraria a chave de um applet que já saiu.
  applet)
    [ -n "$APPLET_ID" ] && [ -f "$APPLET/custom_logo_path" ] || exit "$MEOW_DIVERGENTE"
    printf '%s\n' "$(cat "$APPLET/custom_logo_path")"; exit "$MEOW_OK" ;;
  aplicar|"") ;;
  *) meow_erro "uso: logo.sh [aplicar|girar|girar-vencido|listar|no-dock|modo|applet|--conferir]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

# --- O RELÓGIO DA ROTAÇÃO MORA AQUI, NÃO NA UNIDADE DO SYSTEMD --------------
# Duas coisas derrubaram esse desenho:
#
# Com o gatilho no encerramento, o intervalo não pode mais viver num
# `OnUnitActiveSec`.
CARIMBO_GIRO="$MEOW_ESTADO/logo-girado-em"

_segundos_de() {
  local v="${1:-1d}" n="${1:-1d}"; n="${n%[smhd]}"
  case "$n" in ''|*[!0-9]*) printf '86400'; return ;; esac
  case "$v" in
    *s) printf '%s' "$n" ;;
    *m) printf '%s' "$((n * 60))" ;;
    *h) printf '%s' "$((n * 3600))" ;;
    *d) printf '%s' "$((n * 86400))" ;;
    *)  printf '%s' "$n" ;;              # sem sufixo, o systemd lê como segundos
  esac
}

_giro_venceu() {
  local ultimo agora intervalo
  ultimo="$(cat "$CARIMBO_GIRO" 2>/dev/null)"
  case "$ultimo" in ''|*[!0-9]*) return 0 ;; esac   # nunca girou: venceu
  agora="$(date +%s)"
  intervalo="$(_segundos_de "${LOGO_INTERVALO:-1d}")"
  [ "$((agora - ultimo))" -ge "$intervalo" ]
}

# No modo `hora` o mascote é função do relógio: um `girar` que trocasse o arquivo
# seria desfeito no tique seguinte do `meow-gato.timer`, no máximo cinco minutos
# depois.
if [ "$ACAO" = "girar" ] || [ "$ACAO" = "girar-vencido" ]; then
  if [ "$LOGO_MODO" != "rotacao" ]; then
    meow_pula "o modo é \`$LOGO_MODO\` — o mascote não gira, ele segue o relógio"
    meow_info "  para girar: LOGO_MODO=\"rotacao\" no ~/.config/meow/meow.conf"
    exit "$MEOW_OK"
  fi
fi

if [ "$ACAO" = "girar-vencido" ]; then
  if _giro_venceu; then
    ACAO="girar"
  else
    meow_info "o mascote ainda não venceu (${LOGO_INTERVALO:-1d}) — nada a girar"
    exit "$MEOW_OK"
  fi
fi

# --- o acervo ---------------------------------------------------------------
#
# Consertar só na saída deixaria o arquivo do repositório quebrado — e ele é o
# que ela abre da próxima vez, o que o `git diff` mostra e o que qualquer outro
# programa dela vai ler.
#
# O cabeçalho do `meow-assets.service` diz que nenhuma escrita daqui cai dentro
# do acervo.
if [ "$ACAO" != "no-dock" ] && [ -d "$ACERVO" ] && meow_tem python3 \
   && [ -f "$RAIZ/scripts/normalizar_svg.py" ]; then
  if meow_seco; then
    python3 "$RAIZ/scripts/normalizar_svg.py" --conferir "$ACERVO" || true
  else
    _svg_saida="$(python3 "$RAIZ/scripts/normalizar_svg.py" "$ACERVO" 2>&1)"
    if [ -n "$_svg_saida" ]; then
      printf '%s\n' "$_svg_saida"
      # O aviso é para ELA, não para o log: um desenho que não vai aparecer na
      # tela é exatamente a pergunta que ela faria meia hora depois.
      case "$_svg_saida" in
        *"não vai aparecer"*|*"não sei"*)
          meow_notificar "MeowSystem" \
            "Um mascote do acervo tem desenho que o painel não sabe mostrar — meow doctor conta qual." 2>/dev/null || true ;;
      esac
    fi
    unset _svg_saida
  fi
fi

# A ordem é estável — alfabética — para que "o próximo" signifique a mesma coisa
# em toda execução, inclusive depois de um reboot.
declare -a POOL=() NOMES=()
if [ -d "$ACERVO" ]; then
  while IFS= read -r svg; do
    case "$(basename "$svg")" in *-symbolic.svg) continue ;; esac
    POOL+=("$svg"); NOMES+=("$(basename "${svg%.svg}")")
  done < <(find "$ACERVO" -maxdepth 1 -name '*.svg' | sort)
fi

if [ "${#POOL[@]}" -eq 0 ]; then
  meow_pula "não há mascote nenhum em $ACERVO — solte um .svg lá e ele entra"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

destino_de() { printf '%s/meow-%s.svg' "$LOGOS_DIR" "$1"; }

# O que ela VÊ é o botão do dock, não a chave do applet Logo Menu (que não
# está montado nesta máquina). Perguntar só a chave responderia a pergunta errada.
_tema="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
_no_dock="$HOME/.local/share/icons/$_tema/scalable/apps/com.system76.CosmicPanelAppButton.svg"

# 0 = o mascote de índice $1 é o do botão do dock. Comparar com o cru só casava
# enquanto quem escrevia o botão era o `construir_icones.sh`, que copiava o
# asset direto.
_esta_no_dock() {
  local instalado
  instalado="$(destino_de "${NOMES[$1]}")"
  [ -f "$instalado" ] || instalado="${POOL[$1]}"
  [ -f "$_no_dock" ] && cmp -s "$instalado" "$_no_dock"
}

# --- no-dock ----------------------------------------------------------------
if [ "$ACAO" = "no-dock" ]; then
  for i in "${!NOMES[@]}"; do
    _esta_no_dock "$i" && { printf '%s\n' "${NOMES[$i]}"; exit "$MEOW_OK"; }
  done
  exit "$MEOW_DIVERGENTE"
fi

# --- listar -----------------------------------------------------------------
if [ "$ACAO" = "listar" ]; then
  atual="$(cat "$APPLET/custom_logo_path" 2>/dev/null | tr -d '"')"
  meow_titulo "Gatos do painel (${#POOL[@]})"
  for i in "${!NOMES[@]}"; do
    _marca=""
    [ "$(destino_de "${NOMES[$i]}")" = "$atual" ] && _marca="  <- na chave do applet"
    if _esta_no_dock "$i"; then
      _marca="$_marca  <- NO DOCK (é o que você vê)"
    fi
    if [ -n "$_marca" ]; then meow_ok "${NOMES[$i]}$_marca"; else meow_info "${NOMES[$i]}"; fi
  done

  _j="$(meow_noite_janela)"
  _ini="${_j%% *}"; _fim="${_j#* }"; _fim="${_fim%% *}"
  printf '\n  modo    : %s' "$LOGO_MODO"
  case "$LOGO_MODO" in
    hora)    printf '  (dia=%s · noite=%s)\n' "$LOGO_DIA" "$LOGO_NOITE" ;;
    rotacao) printf '  (gira a cada %s, no encerramento da sessão)\n' "${LOGO_INTERVALO:-1d}" ;;
    *)       printf '  (LOGO="%s" vence sempre)\n' "$LOGO" ;;
  esac
  printf '  noite   : %s–%s  (fonte: %s)\n' \
    "$(meow_hora_de_minutos "$_ini")" "$(meow_hora_de_minutos "$_fim")" "${_j##* }"
  printf '  agora   : %s, portanto é %s\n' "$(date +%H:%M)" "$(meow_fase_da_hora "$_ini" "$_fim")"
  printf '  acervo  : %s\n  solte um .svg ali e ele entra.\n\n' "$ACERVO"
  exit "$MEOW_OK"
fi

# --- o applet existe? E ELE NÃO É O DONO DA TELA ----------------------------
#
# Só que esta guarda continuou saindo do script ANTES dele.
#
# Falta de applet não é falta de tela.
TEM_APPLET=1
if [ -z "$APPLET_ID" ]; then
  TEM_APPLET=0
  meow_pula "nenhum applet de logo do painel instalado — o mascote do dock e o do terminal seguem"
fi

# TER A CONFIGURAÇÃO NÃO É ESTAR NA BARRA — e a diferença é invisível de outro
# jeito.
#
# Um recurso que roda, devolve sucesso e não faz nada é pior do que um recurso
# que falta: ela testaria, não veria efeito, e não teria como saber de quem é a
# culpa.
applet_montado() {
  local barras="$COSMIC/com.system76.CosmicPanel" vp vd
  vp="$(meow_cosmic_v com.system76.CosmicPanel.Panel)"; vd="$(meow_cosmic_v com.system76.CosmicPanel.Dock)"
  grep -qs 'LogoMenu' "$barras.Panel/$vp/plugins_wings" "$barras.Panel/$vp/plugins_center" \
                      "$barras.Dock/$vd/plugins_wings"  "$barras.Dock/$vd/plugins_center"
}

# "isso tá fora em definitivo do projeto", sobre o applet Logo Menu.
#
# O que NÃO mudou: a checagem continua no código, e volta a falar sozinha no dia
# em que alguém puser `LOGO_ROTACAO="sim"` de novo.
if [ "${LOGO_ROTACAO:-nao}" = "sim" ] && ! applet_montado; then
  meow_aviso "o applet da logo não está em nenhuma das barras — girar não muda nada na tela"
  meow_info "  para usá-lo: Ajustes → Área de trabalho → Painel → Applets, e acrescente"
  meow_info "  \"Logo Menu\". A ordem dos applets é sua; este script não mexe nisso."
fi

mudou=0

# --- 1. o acervo inteiro vai para o disco -----------------------------------
# TODOS os mascotes, não só o da vez: girar depois é só trocar a chave, e a troca
# tem de encontrar o arquivo já lá.
for i in "${!POOL[@]}"; do
  meow_escrever "$(destino_de "${NOMES[$i]}")" "$(cat "${POOL[$i]}")" 644
  case $? in
    1) mudou=1 ;;
    2) meow_erro "não consegui instalar ${NOMES[$i]}"; exit "$MEOW_ERRO" ;;
  esac
done

# --- 1b. e os que ela APAGOU do acervo saem do disco -------------------------
# Regra 3 do contrato: reescrever o estado inteiro, nunca acrescentar.
#
# SÓ SE APAGA O QUE É NOSSO: o prefixo `meow-` protege o `gato-pop.svg` do
# Ritual da Aurora, que mora no mesmo diretório e é dele.
if [ -d "$LOGOS_DIR" ]; then
  for velho in "$LOGOS_DIR"/meow-*.svg; do
    [ -f "$velho" ] || continue
    conhecido=0
    for n in "${NOMES[@]}"; do
      [ "$velho" = "$(destino_de "$n")" ] && { conhecido=1; break; }
    done
    [ "$conhecido" = "1" ] && continue
    if meow_seco; then
      meow_muda "removeria $(basename "$velho") (saiu do acervo)"
      mudou=1
    else
      rm -f "$velho" && mudou=1
    fi
  done
fi

# --- 2. quem está no ar -----------------------------------------------------
atual="$(cat "$APPLET/custom_logo_path" 2>/dev/null | tr -d '"')"
indice=-1
for i in "${!NOMES[@]}"; do
  [ "$(destino_de "${NOMES[$i]}")" = "$atual" ] && { indice=$i; break; }
done
# O `indice` saía só da chave, e numa máquina sem applet ele era sempre -1: o
# modo fixo com um `LOGO` fora do acervo prometia «fica o mascote que está no ar»
# e punha o primeiro da ordem alfabética no dock (medido numa casa de
# brinquedo: mimir no dock, coquinha depois); a rotação voltava ao `LOGO` a
# cada passagem e girava sempre para o mesmo.
if [ "$indice" -lt 0 ]; then
  for i in "${!NOMES[@]}"; do
    _esta_no_dock "$i" && { indice=$i; break; }
  done
fi

# O ÍNDICE DE UM NOME DO ACERVO, ou -1. Usado pelo modo `hora` e pelo `LOGO`.
_indice_de() {
  local alvo="$1" i
  for i in "${!NOMES[@]}"; do
    [ "${NOMES[$i]}" = "$alvo" ] && { printf '%s' "$i"; return 0; }
  done
  printf '%s' "-1"
}

FASE=""; FONTE_JANELA=""
if [ "$ACAO" = "girar" ]; then
  # Fora do acervo (ou primeira vez) começa do zero; dentro, avança em círculo.
  proximo=$(( (indice + 1) % ${#NOMES[@]} ))
  [ "$indice" -lt 0 ] && proximo=0
elif [ "$LOGO_MODO" = "hora" ]; then
  # --- O MODO NOVO: O RELÓGIO MANDA, E ELE MANDA SOBRE O QUE JÁ ESTÁ NO AR ----
  # Aqui NÃO se preserva o que está no ar, ao contrário do modo `rotacao`.
  #
  # Ver lá a ordem de precedência e por que a fonte é dita em voz alta.
  _j="$(meow_noite_janela)"
  _ini="${_j%% *}"; _fim="${_j#* }"; _fim="${_fim%% *}"; FONTE_JANELA="${_j##* }"
  if meow_e_noite "$_ini" "$_fim"; then FASE="noite"; _quer="$LOGO_NOITE"
  else                                  FASE="dia";   _quer="$LOGO_DIA"; fi

  proximo="$(_indice_de "$_quer")"
  if [ "$proximo" -lt 0 ]; then
    # O nome do conf é de outro pack (o Mimir com o Dracula no ar): vale o
    # mascote de fábrica do pack no ar para esta fase.
    _padrao="$(python3 "$RAIZ/scripts/pack.py" mascote-padrao "$(meow_pack_dir)" "$FASE" 2>/dev/null)"
    proximo="$(_indice_de "${_padrao:-}")"
    unset _padrao
  fi
  if [ "$proximo" -lt 0 ]; then
    # O acervo é a interface: um nome que não está lá é engano de digitação no
    # conf, ou um mascote que ela apagou.
    meow_aviso "LOGO_${FASE^^}=\"$_quer\" não está em $ACERVO — caindo em \"$LOGO\""
    proximo="$(_indice_de "$LOGO")"
    [ "$proximo" -lt 0 ] && proximo=0
  fi
  unset _j _ini _fim _quer
elif [ "$LOGO_MODO" = "fixo" ]; then
  # --- O MODO FIXO: O `LOGO` VENCE, COMO O CABEÇALHO SEMPRE PROMETEU ---------
  # Até aqui o `fixo` caía no ramo de baixo, que é o da rotação: com um mascote do
  # acervo já na chave, ele ficava, e o `LOGO` não era lido.
  proximo="$(_indice_de "$LOGO")"
  if [ "$proximo" -lt 0 ]; then
    # O mesmo aviso do modo `hora` para um nome fora do acervo. Ela dizia «fica
    # o mascote que está no ar» também quando nenhum estava (sem applet, o
    # `indice` era sempre -1) e o dock ia para o primeiro do acervo.
    if [ "$indice" -ge 0 ]; then
      proximo="$indice"
      meow_aviso "LOGO=\"$LOGO\" não está em $ACERVO — fica o mascote que está no ar, ${NOMES[$proximo]}"
    else
      proximo=0
      meow_aviso "LOGO=\"$LOGO\" não está em $ACERVO, e nenhum mascote do acervo está no ar — vai o primeiro, ${NOMES[0]}"
    fi
  fi
else
  # Só garante que o que está no ar — a chave do applet ou, sem ela, o dock —
  # é ALGUM mascote do acervo.
  if [ "$indice" -ge 0 ]; then
    proximo="$indice"
  else
    # `LOGO` do meow.conf nomeia o mascote PREFERIDO do acervo — é o ponto de
    # partida da rotação, quando nenhum mascote do acervo está no ar (a máquina
    # nova).
    #
    # Só vale quando o que está no ar NÃO é mascote do acervo: se apontasse para
    # um, sobrescrever aqui desfaria a rotação a cada `install.sh` — o mesmo
    # defeito dos dois donos, agora numa linha só.
    proximo=0
    for i in "${!NOMES[@]}"; do
      [ "${NOMES[$i]}" = "$LOGO" ] && { proximo=$i; break; }
    done
  fi
fi

alvo="$(destino_de "${NOMES[$proximo]}")"
if [ "$alvo" != "$atual" ]; then
  # O RON quer a string entre aspas e SEM newline no fim: um \n a mais faz o
  # applet ignorar o valor calado.
  if [ "$TEM_APPLET" = "1" ]; then
    meow_escrever "$APPLET/custom_logo_path" "\"$alvo\"" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "não consegui apontar a logo"; exit "$MEOW_ERRO" ;; esac
  fi
  # `>` abre com O_TRUNC: o arquivo fica VAZIO no disco entre a truncagem e a
  # escrita, e é nessa fresta que um leitor pega nada.
  meow_seco || meow_escrever "$ESTADO" "${NOMES[$proximo]}" 644 >/dev/null || true
fi

# Fora do `if` acima porque um giro que caia no mesmo mascote (acervo de um só)
# ainda é um giro — sem isto ele tentaria de novo a cada encerramento.
if [ "$ACAO" = "girar" ] && ! meow_seco; then
  # Mesmo motivo do estado acima: `mv` no lugar de O_TRUNC. Aqui a fresta tem
  # dono conhecido — o `_giro_venceu` já trata carimbo vazio como "venceu"
  # (linhas 100-102), e o pior caso seria um giro a mais.
  meow_escrever "$CARIMBO_GIRO" "$(date +%s)" 644 >/dev/null || true
fi

# Fora do `if`: a chave que LIGA a logo personalizada não depende de o caminho
# ter mudado.
if [ "$TEM_APPLET" = "1" ]; then
  meow_escrever "$APPLET/custom_logo_active" "true" 644
  case $? in 1) mudou=1 ;; esac
fi

# --- O MASCOTE DO DOCK, QUE É O ÚNICO QUE ELA DE FATO VÊ ------------------------
#
# Ela apontou o mascote do canto do dock e perguntou por que a Coquinha não estava
# lá. Ele nunca consultou o acervo.
#
# Enquanto isso, toda a rotação construída neste projeto mirava em
# `custom_logo_path`, do applet Logo Menu — que NÃO ESTÁ MONTADO em barra
# nenhuma nesta máquina.
TEMA_ICONES="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
BOTOES_DOCK=(com.system76.CosmicPanelAppButton com.system76.CosmicAppLibrary)
DIR_BOTOES="$HOME/.local/share/icons/$TEMA_ICONES/scalable/apps"

dock_mudou=0
if [ -f "$alvo" ]; then
  for _b in "${BOTOES_DOCK[@]}"; do
    meow_escrever "$DIR_BOTOES/$_b.svg" "$(cat "$alvo")" 644
    case $? in
      1) mudou=1; dock_mudou=1 ;;
      2) meow_erro "não consegui vestir o botão do dock com $_b"; exit "$MEOW_ERRO" ;;
    esac
  done
fi

# --- E O RECICLO, QUE É O QUE FAZ O ARQUIVO VIRAR PIXEL -----------------------
#
# Este script roda a cada cinco minutos pelo `meow-gato.timer`, e o
# `meow-assets.path` o dispara de novo a cada mexida no acervo.
#
# A PORTA É ÚNICA, E NÃO É UM `pkill` DAQUI. Ver o cabeçalho: o
# `scripts/painel.sh reciclar` recusa quando o supervisor dormiria minutos, e
# essa recusa é a única coisa entre um mascote e uma barra sumida. `|| true`
# porque a recusa dele é decisão correta, não falha desta etapa — e o arquivo já
# está no disco de qualquer jeito, então o mascote certo aparece no próximo login.
if [ "$dock_mudou" = "1" ] && ! meow_seco; then
  if [ "$LOGO_RECICLAR" != "sim" ]; then
    meow_info "mascote do dock trocado; LOGO_RECICLAR=\"$LOGO_RECICLAR\" — vale no próximo login"
  elif [ -x "$RAIZ/scripts/painel.sh" ]; then
    meow_info "mascote do dock trocado — reciclando o painel para ele aparecer"
    # O `com.system76.CosmicAppLibrary` que acabamos de vestir é o ícone da
    # GRADE — reciclar o painel repõe o botão do dock e não toca no
    # `cosmic-app-library`, que resolveu o ícone quando subiu.
    meow_tela_reler || true
  fi
fi

# --- O MASCOTE DO TERMINAL VAI JUNTO -------------------------------------------
# O `fastfetch` lê o arquivo do logo a CADA execução: não há cache, não há
# reciclo, não há pisca.
#
# NÃO É ERRO DAQUI SE ELE FALHAR: ele tem código de saída próprio (4 = "o
# config.jsonc da Aurora ainda não aponta para nós") e quem o interpreta é o
# `install.sh` e o `bin/meow doctor`. Aqui ele é efeito colateral desejado, não
# etapa — por isso `|| true` e saída silenciada.
# `FFL_FUNDO=1` liga a guarda barata de lá: com o carimbo batendo, o tique sai
# sem rasterizar nada. Ver o bloco `_ffl_ja_esta_certo` no fastfetch_logo.sh — e
# note que o `conferir` do doctor NÃO passa essa variável, então a checagem
# profunda continua acontecendo uma vez por dia.
if ! meow_seco && [ -x "$RAIZ/scripts/fastfetch_logo.sh" ]; then
  FFL_FUNDO=1 LOG_NIVEL=silencioso "$RAIZ/scripts/fastfetch_logo.sh" aplicar >/dev/null 2>&1 || true
fi

# O PORQUÊ ENTRA NA LINHA, E NÃO SÓ O QUÊ. "no ar: mimir" às 15h parece defeito;
# "no ar: mimir (noite, janela 18:00–07:00 de meow.conf)" é uma frase que se
# pode conferir contra o relógio sem abrir um arquivo.
PORQUE=""
if [ -n "$FASE" ]; then
  _j="$(meow_noite_janela)"; _i="${_j%% *}"; _f="${_j#* }"; _f="${_f%% *}"
  PORQUE=" — $FASE, janela $(meow_hora_de_minutos "$_i")–$(meow_hora_de_minutos "$_f") ($FONTE_JANELA)"
  unset _j _i _f
fi

if [ "$mudou" = "0" ]; then
  meow_ok "logo já no lugar: ${NOMES[$proximo]}$PORQUE"
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"
if [ "$ACAO" = "girar" ]; then
  meow_ok "o mascote do painel agora é ${NOMES[$proximo]} — já valendo, sem reiniciar"
else
  meow_ok "acervo de ${#POOL[@]} mascote(s) instalado; no ar: ${NOMES[$proximo]}$PORQUE"
fi
exit "$MEOW_DIVERGENTE"

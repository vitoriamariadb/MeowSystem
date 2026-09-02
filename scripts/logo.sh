#!/usr/bin/env bash
# logo.sh — o gato do dock e do painel: de dia a Coquinha, de noite o Mimir.
#
#   ./logo.sh              põe no ar o gato que a HORA pede (e instala o acervo)
#   ./logo.sh girar        passa para o próximo gato (só no modo `rotacao`)
#   ./logo.sh --conferir   não escreve; 1 se algo divergir
#   ./logo.sh listar       mostra o acervo, quem está no ar e por quê
#
# ============================================================================
# O QUE MUDOU EM 01/09/2026, E O QUE FOI MEDIDO PARA PODER MUDAR
# ============================================================================
# O PEDIDO DELA: "de noite o menu com o mimir e de dia a coquinha" — o mesmo
# que o applet do modo de leitura já faz com a lua e o sol na barra.
#
# ISSO ERA DADO COMO IMPOSSÍVEL AQUI, POR ESCRITO, E A FRASE ESTAVA ERRADA
#   O bloco "O GATO DO DOCK" mais abaixo dizia, desde 05/08/2026:
#
#       "trocar ícone de tema exige reiniciar o painel, que pisca a tela. Por
#        isso a rotação não o acompanha: um enfeite não vale um pisca-pisca a
#        cada 30 minutos."
#
#   A primeira metade continua VERDADEIRA e foi remedida em 01/09/2026, com
#   captura de tela antes e depois: reescrever
#   `~/.local/share/icons/<tema>/scalable/apps/com.system76.CosmicPanelAppButton.svg`
#   com o outro gato e esperar 2s NÃO troca um pixel na tela. O
#   `cosmic-panel-button` resolve o ícone uma vez, no arranque, e guarda.
#
#   Matar SÓ o applet também não serve, e isso é novo: `kill <pid do
#   cosmic-panel-button>` deixou um BURACO no dock — o `cosmic-panel` NÃO
#   ressuscita applet morto. O botão só voltou com o painel inteiro.
#
#   O que caiu foi a SEGUNDA metade — a conta. `./bin/meow painel reciclar`
#   (SIGTERM no `cosmic-panel`, pela porta única do `scripts/painel.sh`) trouxe
#   o botão de volta JÁ COM O GATO NOVO, em ~6s, com o `meow-painel.service`
#   armado. E a frequência deixou de ser "a cada 30 minutos": são DUAS trocas
#   por dia, no nascer e no pôr da janela de noite. Um pisca de ~2s duas vezes
#   por dia é preço diferente de um a cada meia hora — e é por isso que a
#   decisão muda sem que a medição de 05/08 tenha ficado errada.
#
# A PORTA É `scripts/painel.sh reciclar`, E NUNCA UM `pkill` DAQUI
#   Aquele script recusa reciclar quando o `meow-painel.service` está parado E o
#   `cosmic-session` dormiria minutos antes de repor o painel — o backoff do
#   supervisor é `2^N × sorteio(0..9)`, sem teto e sem zerar. Um `pkill -x
#   cosmic-panel` escrito aqui seria um segundo dono dessa regra, e o dia em que
#   o backoff estivesse alto ela ficaria sem barra por minutos por causa de um
#   gato. `LOGO_RECICLAR="nao"` desliga o reciclo sem tirar a troca do arquivo.
#
# O QUE NÃO PRECISA DE RECICLO NENHUM: o `fastfetch`, que lê o arquivo do logo a
# cada execução. Quem cuida dele é o `scripts/fastfetch_logo.sh`, chamado no fim
# desta rodada — o gato do terminal troca sozinho, sem piscar nada.
#
# A PASTA É A INTERFACE
#   Quem manda no acervo é `assets/gatos/`: soltou um SVG lá, ele entra na
#   rotação; apagou, sai. Não há lista dentro de script — uma lista fixa
#   envelheceria no dia em que ela desenhasse outro gato, e o sintoma seria
#   "coloquei o arquivo e não aconteceu nada".
#
# POR QUE TROCAR A CHAVE, E NUNCA O CONTEÚDO DO ARQUIVO (medido, §3 do
# docs/COSMIC-THEMING.md)
#   O applet `dev.cappsy.CosmicExtAppletLogoMenu` CACHEIA a imagem no
#   carregamento. Reescrever o mesmo arquivo não muda nada até o próximo
#   `pkill -x cosmic-panel` — que pisca a tela dela e gasta uma vida do respawn
#   do `cosmic-session`. Já apontar `custom_logo_path` para OUTRO arquivo troca o
#   gato instantaneamente, porque o applet vigia a configuração por inotify.
#   Por isso cada gato vive em seu próprio arquivo e a rotação só mexe na chave.
#
# A ARMADILHA DO NOME
#   O applet faz `.symbolic(path.contains("-symbolic.svg"))`: um arquivo cujo
#   nome termine assim é achatado numa cor só. Nenhum gato do acervo pode ter
#   esse sufixo, e é por isso que o `assets/meow-symbolic.svg` fica de fora.
#
# O APPLET É DE TERCEIRO
#   `dev.cappsy` não vem com o COSMIC: ela o instalou, e pode desinstalá-lo ou
#   tirá-lo do painel a qualquer momento. Quando ele não está, isto aqui não é
#   erro: é etapa pulada, com a razão dita em voz alta. Isso não é portabilidade
#   — é o que faz o instalador não explodir quando um programa não está no lugar.
#
# CONVIVÊNCIA COM O RITUAL DA AURORA
#   `~/.config/cosmic/logos/` é NOSSO desde o self-heal v3.56. O `gato-pop.svg`
#   que o Aurora repunha a cada ciclo foi aposentado lá e removido daqui: era um
#   terceiro arquivo, de outro dono e de outra paleta, para uma chave
#   (`custom_logo_path`) que aponta para um só. Escrevemos `meow-<nome>.svg` e o
#   diretório tem um dono só. Ver docs/FRONTEIRA.md.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/noite.sh
. "$RAIZ/lib/noite.sh"

ACERVO="$RAIZ/assets/gatos"
LOGOS_DIR="$HOME/.config/cosmic/logos"
APPLET="$HOME/.config/cosmic/dev.cappsy.CosmicExtAppletLogoMenu/v1"
ESTADO="$MEOW_ESTADO/logo-atual"

FLAVOR="${FLAVOR:-mocha}"
LOGO="${LOGO:-$FLAVOR}"

# --- AS TRÊS MANEIRAS DE ESCOLHER O GATO ------------------------------------
#   hora     (padrão) o relógio manda: `LOGO_NOITE` de noite, `LOGO_DIA` de dia.
#   rotacao  o desenho antigo: gira no encerramento da sessão, um por
#            `LOGO_INTERVALO`. Continua inteiro, e `LOGO_ROTACAO="sim"` continua
#            sendo o que o liga — ver a compatibilidade logo abaixo.
#   fixo     `LOGO=` vence sempre; nada gira, nada segue relógio.
#
# COMPATIBILIDADE, PORQUE O CONF DELA JÁ EXISTE E NÃO PODE MENTIR
#   O `meow.conf` desta máquina tem `LOGO_ROTACAO="nao"` desde 24/08/2026. Se o
#   novo padrão fosse `hora` sem olhar para essa chave, tudo bem — mas numa
#   máquina com `LOGO_ROTACAO="sim"` o padrão novo DESLIGARIA calado a rotação
#   que a pessoa ligou. Então: quem escreveu `LOGO_ROTACAO="sim"` e não escreveu
#   `LOGO_MODO` continua no modo `rotacao`. Chave velha não vira inerte.
if [ -n "${LOGO_MODO:-}" ]; then
  :
elif [ "${LOGO_ROTACAO:-nao}" = "sim" ]; then
  LOGO_MODO="rotacao"
else
  LOGO_MODO="hora"
fi

# Os nomes saem do acervo (`assets/gatos/<nome>.svg`). Um nome que não exista
# não é erro fatal: o script avisa e cai no `LOGO`, porque um gato errado na
# tela é melhor que um instalador que aborta por causa de um enfeite.
LOGO_DIA="${LOGO_DIA:-coquinha}"
LOGO_NOITE="${LOGO_NOITE:-mimir}"
# `nao` troca o arquivo e NÃO recicla o painel: o gato novo passa a valer no
# próximo login. Existe para quem não quer o pisca de ~2s, e para o dia em que
# ela estiver gravando a tela.
LOGO_RECICLAR="${LOGO_RECICLAR:-sim}"

CONFERIR=0
ACAO="aplicar"
case "${1:-}" in
  --conferir)    CONFERIR=1 ;;
  girar)         ACAO="girar" ;;
  girar-vencido) ACAO="girar-vencido" ;;
  listar)        ACAO="listar" ;;
  # `modo` IMPRIME O MODO EFETIVO E SAI. Existe para que o `install.sh` não
  # precise reimplementar a regra de compatibilidade `LOGO_ROTACAO` -> `LOGO_MODO`
  # acima: dois donos da mesma regra é o defeito que este projeto mais persegue,
  # e a etapa de lá precisa saber qual unidade do systemd instalar.
  modo)          printf '%s\n' "$LOGO_MODO"; exit "$MEOW_OK" ;;
  aplicar|"") ;;
  *) meow_erro "uso: logo.sh [aplicar|girar|girar-vencido|listar|modo|--conferir]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

# --- O RELÓGIO DA ROTAÇÃO MORA AQUI, NÃO NA UNIDADE DO SYSTEMD --------------
# Até 08/08/2026 quem contava o intervalo era o `OnUnitActiveSec` do
# `meow-logo.timer`, substituído pelo `LOGO_INTERVALO` na hora de instalar. Duas
# coisas derrubaram esse desenho:
#
#   1. O GATO SÓ MUDA DE APARÊNCIA NO LOGIN. O `cosmic-panel` lê o ícone do dock
#      uma vez, ao iniciar a sessão, e não o relê (seis watches de inotify,
#      nenhum sobre arquivo de ícone). Girar às 00:12, dez minutos depois de o
#      painel ter carregado, escrevia no disco para um efeito que só apareceria
#      no login seguinte — ela via SEMPRE o gato anterior. Foi a queixa de
#      08/08: "voltamos a ter o icon antigo do lançador de menu".
#   2. Logo, a única hora útil de girar é no ENCERRAMENTO da sessão: aí o
#      próximo login já abre com o gato novo. Girar antes do painel subir seria
#      corrida — medido: o `cosmic-panel` nasce no mesmo segundo em que o
#      `cosmic-session.target` fica ativo.
#
# Com o gatilho no encerramento, o intervalo não pode mais viver num `OnUnitActiveSec`.
# Ele passa a ser um CARIMBO em disco, e `girar-vencido` é quem o consulta —
# assim "um gato por dia" continua sendo um gato por dia, mesmo que ela reinicie
# quatro vezes num dia.
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

# GIRAR SÓ EXISTE NO MODO `rotacao`, E RECUSAR É MELHOR QUE FINGIR
#   No modo `hora` o gato é função do relógio: um `girar` que trocasse o arquivo
#   seria desfeito no tique seguinte do `meow-gato.timer`, no máximo cinco
#   minutos depois. Ela veria o gato mudar e voltar sozinho, sem nada na tela
#   explicando por quê — que é exatamente o modo de falha calado que este projeto
#   persegue. Sai 0 (não é erro; é etapa que não se aplica) e diz o que fazer.
if [ "$ACAO" = "girar" ] || [ "$ACAO" = "girar-vencido" ]; then
  if [ "$LOGO_MODO" != "rotacao" ]; then
    meow_pula "o modo é \`$LOGO_MODO\` — o gato não gira, ele segue o relógio"
    meow_info "  para girar: LOGO_MODO=\"rotacao\" no ~/.config/meow/meow.conf"
    exit "$MEOW_OK"
  fi
fi

if [ "$ACAO" = "girar-vencido" ]; then
  if _giro_venceu; then
    ACAO="girar"
  else
    meow_info "o gato ainda não venceu (${LOGO_INTERVALO:-1d}) — nada a girar"
    exit "$MEOW_OK"
  fi
fi

# --- o acervo ---------------------------------------------------------------
# O ACERVO É SÓ `assets/gatos/`, E O GATO GERADO DO FLAVOR SAIU DE VEZ
#   Até 08/08/2026 o gato desenhado por `scripts/gerar_gato.py` entrava na
#   rotação junto com os dela, à frente dos outros. Ela pediu o contrário, com
#   estas palavras: *"tá usando os gatos antigos, eu tinha pedido pra excluir
#   eles e usar só a coquinha e o mimir. excluir pra não ter erro mesmo"*.
#
#   Tirar só daqui não bastava, e é por isso que o gerador foi embora junto: o
#   `gerar_gato.py --conferir` roda no `install.sh` e no `doctor --consertar`, e
#   acusaria os SVG ausentes como divergência — os gatos antigos voltariam ao
#   disco sozinhos na rodada seguinte, que é exatamente o "erro" que ela mandou
#   excluir. Some daqui, some do gerador, some do `install.sh`.
#
# --- ANTES DE LER O ACERVO: O DESENHO DELA TEM DE SER DESENHÁVEL -------------
# 01/09/2026, e é o defeito mais caro que este acervo já teve. Ela pôs dentes na
# Coquinha e no Mimir no Boxy SVG e salvou por cima. Tudo aqui funcionou: o
# `meow-assets.path` disparou, o acervo foi para o disco, o painel reciclou, o
# `.ansi` do terminal foi regerado. E os dentes não apareceram em lugar nenhum.
#
# A causa estava DENTRO do arquivo: o Boxy posiciona forma nova com
# `transform-box: fill-box` + `transform-origin`, duas propriedades do SVG 2 que
# NEM o librsvg (rsvg-convert, GTK, o `.ansi` do fastfetch) NEM o resvg (o que o
# COSMIC usa para ícone de tema) implementam. Os dois leem a matriz e a aplicam
# a partir do (0,0) do arquivo: o dente do Mimir, que devia cair em (554, 634),
# ia para (-191, -705) — fora do viewBox, invisível, sem uma linha de erro.
#
# O `normalizar_svg.py` faz a aritmética que os dois renderizadores não fazem
# (E = T(o)·M·T(-o)) e grava uma matriz comum, sem tocar no `d=` nem no
# `bx:shape=` — ela reabre no editor e continua arrastando a peça como antes.
# É idempotente: numa pasta já normalizada não escreve nada e sai 0.
#
# POR QUE AQUI, E NÃO SÓ NA HORA DE COPIAR PARA O DISCO
#   Consertar só na saída deixaria o arquivo do repositório quebrado — e ele é
#   o que ela abre da próxima vez, o que o `git diff` mostra e o que qualquer
#   outro programa dela vai ler. O arquivo é a fonte; ele é que tem de ficar são.
#
# ESCREVER NO DIRETÓRIO VIGIADO REDISPARA O `meow-assets.path`, E ISSO É ACEITO
#   O cabeçalho do `meow-assets.service` diz que nenhuma escrita daqui cai
#   dentro do acervo. Esta cai, e é a única. O laço não acontece porque a
#   segunda passada não muda byte nenhum (idempotente): o disparo extra roda,
#   não escreve, sai. Um disparo a mais por edição dela, contra o
#   `StartLimitBurst=20` — folga de sobra, e o disjuntor continua lá para o dia
#   em que alguém quebrar a idempotência.
if [ -d "$ACERVO" ] && meow_tem python3 && [ -f "$RAIZ/scripts/normalizar_svg.py" ]; then
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
            "Um gato do acervo tem desenho que o painel não sabe mostrar — meow doctor conta qual." 2>/dev/null || true ;;
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
  meow_pula "não há gato nenhum em $ACERVO — solte um .svg lá e ele entra"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

destino_de() { printf '%s/meow-%s.svg' "$LOGOS_DIR" "$1"; }

# --- listar -----------------------------------------------------------------
if [ "$ACAO" = "listar" ]; then
  atual="$(cat "$APPLET/custom_logo_path" 2>/dev/null | tr -d '"')"
  # O que ela VÊ é o botão do dock, não a chave do applet Logo Menu (que não
  # está montado nesta máquina). Listar só a chave responderia a pergunta errada.
  _tema="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
  _no_dock="$HOME/.local/share/icons/$_tema/scalable/apps/com.system76.CosmicPanelAppButton.svg"
  meow_titulo "Gatos do painel (${#POOL[@]})"
  for i in "${!NOMES[@]}"; do
    _marca=""
    [ "$(destino_de "${NOMES[$i]}")" = "$atual" ] && _marca="  <- na chave do applet"
    if [ -f "$_no_dock" ] && cmp -s "${POOL[$i]}" "$_no_dock"; then
      _marca="$_marca  <- NO DOCK (é o que ela vê)"
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

# --- o applet existe, E ESTÁ MONTADO? ---------------------------------------
if [ ! -d "$APPLET" ]; then
  meow_pula "o applet dev.cappsy (logo do painel) não está nesta máquina"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

# TER A CONFIGURAÇÃO NÃO É ESTAR NA BARRA — e a diferença é invisível de outro jeito.
#   Medido em 05/08/2026: o diretório `dev.cappsy.CosmicExtAppletLogoMenu/v1`
#   existe e tem `custom_logo_path` preenchido, mas o applet NÃO aparece em
#   `plugins_wings` nem em `plugins_center` de nenhuma das duas barras. Ou seja,
#   girar a chave funcionava perfeitamente e não mudava um pixel na tela dela.
#
#   O gato que ela VÊ, no canto do dock, é outro caminho: o applet
#   `com.system76.CosmicPanelAppButton`, cujo ícone vem do TEMA DE ÍCONES
#   (`scalable/apps/com.system76.CosmicPanelAppButton.svg`) — e trocar ícone de
#   tema exige reiniciar o painel, que pisca a tela. Por isso a rotação não o
#   acompanha: um enfeite não vale um pisca-pisca a cada 30 minutos.
#
#   Avisar é obrigatório. Um recurso que roda, devolve sucesso e não faz nada é
#   pior do que um recurso que falta: ela testaria, não veria efeito, e não teria
#   como saber de quem é a culpa.
applet_montado() {
  local barras="$HOME/.config/cosmic/com.system76.CosmicPanel"
  grep -qs 'LogoMenu' "$barras.Panel/v1/plugins_wings" "$barras.Panel/v1/plugins_center" \
                      "$barras.Dock/v1/plugins_wings"  "$barras.Dock/v1/plugins_center"
}

# O AVISO SÓ VALE QUANDO A ROTAÇÃO ESTÁ LIGADA — DECISÃO DELA, 24/08/2026.
#   "isso tá fora em definitivo do projeto", sobre o applet Logo Menu. Com o
#   applet fora, o aviso deixa de ser informação e vira ruído: repetir a cada
#   `install.sh` uma instrução que ela já recusou é gastar a atenção dela para
#   nada, e é assim que um aviso de verdade passa despercebido depois.
#
#   O que NÃO mudou: a checagem continua no código, e volta a falar sozinha no
#   dia em que alguém puser `LOGO_ROTACAO="sim"` de novo. O parágrafo acima
#   continua verdadeiro — girar sem o applet montado não muda um pixel — e é
#   exatamente por isso que a rotação foi desligada em vez de o aviso ser
#   apagado. Silenciar o alarme sem desligar o forno é o que este projeto recusa.
#
#   O gato que ela VÊ no canto da dock não depende disto: vem do
#   `com.system76.CosmicPanelAppButton`, pelo tema de ícones, e continua igual.
if [ "${LOGO_ROTACAO:-nao}" = "sim" ] && ! applet_montado; then
  meow_aviso "o applet da logo não está em nenhuma das barras — girar não muda nada na tela"
  meow_info "  para usá-lo: Ajustes → Área de trabalho → Painel → Applets, e acrescente"
  meow_info "  \"Logo Menu\". A ordem dos applets é dela; este script não mexe nisso."
fi

mudou=0

# --- 1. o acervo inteiro vai para o disco -----------------------------------
# TODOS os gatos, não só o da vez: girar depois é só trocar a chave, e a troca
# tem de encontrar o arquivo já lá. Instalar sob demanda faria a primeira volta
# da rotação escrever arquivo — e escrever é justamente o que a rotação evita.
for i in "${!POOL[@]}"; do
  meow_escrever "$(destino_de "${NOMES[$i]}")" "$(cat "${POOL[$i]}")" 644
  case $? in
    1) mudou=1 ;;
    2) meow_erro "não consegui instalar ${NOMES[$i]}"; exit "$MEOW_ERRO" ;;
  esac
done

# --- 1b. e os que ela APAGOU do acervo saem do disco -------------------------
# Regra 3 do contrato: reescrever o estado inteiro, nunca acrescentar. Sem isto,
# um gato tirado de `assets/gatos/` continuaria instalado para sempre — e como a
# rotação sorteia pelo acervo, não pelo disco, ele viraria um arquivo órfão que
# ninguém usa e ninguém sabe de onde veio. Medido ao apagar um gato de teste.
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
  # Aqui NÃO se preserva o que está na chave, ao contrário dos outros dois modos.
  # A razão é a diferença entre "quem gira é o script" e "quem gira é a hora":
  # no modo `rotacao` sobrescrever a chave a cada `install.sh` desfaria a
  # rotação; no modo `hora` NÃO sobrescrever seria o gato ficar preso no rosto
  # da fase anterior para sempre, que é o defeito que este modo veio curar.
  #
  # A JANELA VEM DO `lib/noite.sh`, QUE É A ÚNICA NOITE DA MÁQUINA. Ver lá a
  # ordem de precedência e por que a fonte é dita em voz alta.
  _j="$(meow_noite_janela)"
  _ini="${_j%% *}"; _fim="${_j#* }"; _fim="${_fim%% *}"; FONTE_JANELA="${_j##* }"
  if meow_e_noite "$_ini" "$_fim"; then FASE="noite"; _quer="$LOGO_NOITE"
  else                                  FASE="dia";   _quer="$LOGO_DIA"; fi

  proximo="$(_indice_de "$_quer")"
  if [ "$proximo" -lt 0 ]; then
    # O acervo é a interface: um nome que não está lá é engano de digitação no
    # conf, ou um gato que ela apagou. Avisar é obrigatório — cair calado no
    # primeiro do acervo faria o gato certo nunca aparecer, e ela procuraria o
    # defeito no relógio.
    meow_aviso "LOGO_${FASE^^}=\"$_quer\" não está em $ACERVO — caindo em \"$LOGO\""
    proximo="$(_indice_de "$LOGO")"
    [ "$proximo" -lt 0 ] && proximo=0
  fi
  unset _j _ini _fim _quer
else
  # Sem girar: só garante que a chave aponta para ALGUM gato do acervo. Se já
  # aponta, não se mexe — senão toda rodada do instalador desfaria a rotação e
  # ela veria o gato voltar ao primeiro sozinho.
  if [ "$indice" -ge 0 ]; then
    proximo="$indice"
  else
    # `LOGO` do meow.conf nomeia o gato PREFERIDO do acervo — é o que vale numa
    # máquina nova e quando a rotação está desligada. A chave deixou de nomear
    # variante do gato gerado em 08/08/2026, quando os gatos do projeto foram
    # excluídos; sem isto ela viraria mais uma chave que o conf oferece e nenhum
    # código lê, que é defeito conhecido deste projeto.
    #
    # Só vale quando o que está no ar NÃO é gato do acervo: se apontasse para um,
    # sobrescrever aqui desfaria a rotação a cada `install.sh` — o mesmo defeito
    # dos dois donos, agora numa linha só.
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
  meow_escrever "$APPLET/custom_logo_path" "\"$alvo\"" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "não consegui apontar a logo"; exit "$MEOW_ERRO" ;; esac
  # `>` abre com O_TRUNC: o arquivo fica VAZIO no disco entre a truncagem e a
  # escrita, e é nessa fresta que um leitor pega nada. `meow_escrever`
  # (lib/comum.sh:92) grava num temporário do mesmo diretório e faz `mv`, que é
  # atômico — o leitor vê o valor velho ou o novo, nunca o meio.
  meow_seco || meow_escrever "$ESTADO" "${NOMES[$proximo]}" 644 >/dev/null || true
fi

# O carimbo é do GIRO, não da escrita: marca-se quando a rotação de fato
# aconteceu, para o `girar-vencido` da próxima sessão saber se o dia passou.
# Fora do `if` acima porque um giro que caia no mesmo gato (acervo de um só)
# ainda é um giro — sem isto ele tentaria de novo a cada encerramento.
if [ "$ACAO" = "girar" ] && ! meow_seco; then
  # Mesmo motivo do estado acima: `mv` no lugar de O_TRUNC. Aqui a fresta tem
  # dono conhecido — o `_giro_venceu` já trata carimbo vazio como "venceu"
  # (linhas 100-102), e o pior caso seria um giro a mais. Ainda assim, escrever
  # certo custa a mesma linha.
  meow_escrever "$CARIMBO_GIRO" "$(date +%s)" 644 >/dev/null || true
fi

# Fora do `if`: a chave que LIGA a logo personalizada não depende de o caminho
# ter mudado. Numa máquina onde o applet já apontasse para o nosso arquivo mas
# com `custom_logo_active = false`, deixá-la de fora aqui mostraria o logo de
# fábrica para sempre, sem nada divergente para o doctor acusar.
meow_escrever "$APPLET/custom_logo_active" "true" 644
case $? in 1) mudou=1 ;; esac

# --- O GATO DO DOCK, QUE É O ÚNICO QUE ELA DE FATO VÊ ------------------------
# A ROTAÇÃO GIRAVA NO LUGAR ERRADO, E ISSO SÓ APARECEU EM 05/08/2026 ÀS 22h
#   Ela apontou o gato do canto do dock e perguntou por que a Coquinha não estava
#   lá. Medido: aquele ícone é `com.system76.CosmicAppLibrary`, e quem o escrevia
#   era o `construir_icones.sh` a partir de um caminho FIXO —
#   `assets/meow-${FLAVOR}-painel.svg`. Ele nunca consultou o acervo.
#
#   Enquanto isso, toda a rotação construída neste projeto mirava em
#   `custom_logo_path`, do applet Logo Menu — que NÃO ESTÁ MONTADO em barra
#   nenhuma nesta máquina. Ou seja: o gato que gira ninguém vê, e o gato que ela
#   vê não gira. A Coquinha e o Mimir entraram no acervo e nunca chegariam à
#   tela dela.
#
# POR QUE O DONO PASSA A SER ESTE SCRIPT, E NÃO O construir_icones.sh
#   O comentário §3 daquele script documenta o preço de errar isto: os dois já
#   escreveram a mesma chave, e a etapa de ícones — que roda ANTES — desfazia a
#   rotação a cada `install.sh`, sem erro nenhum na tela. Dois donos da mesma
#   linha é o modo de falha que este projeto mais persegue.
#   A fronteira aqui é a mesma que resolveu o vidro hoje: quem gira é o dono
#   (este script); o outro só escreve no BOOTSTRAP, quando o arquivo não existe.
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
# MEDIDO EM 01/09/2026, com captura de tela antes e depois:
#   1. escrever o SVG e esperar 2s  ->  ZERO pixel muda. O `cosmic-panel-button`
#      resolve o ícone no arranque e guarda.
#   2. `kill <pid do cosmic-panel-button>`  ->  BURACO no dock. O `cosmic-panel`
#      não ressuscita applet morto; o botão só voltou com o painel inteiro.
#   3. `scripts/painel.sh reciclar`  ->  botão de volta em ~6s, com o gato NOVO.
#
# SÓ QUANDO O ARQUIVO DE FATO MUDOU. Este script roda a cada cinco minutos pelo
# `meow-gato.timer`, e o `meow-assets.path` o dispara de novo a cada mexida no
# acervo. Reciclar sem mudança seria 288 piscadas por dia — com o teste, são
# DUAS: a do nascer e a do pôr da janela de noite.
#
# A PORTA É ÚNICA, E NÃO É UM `pkill` DAQUI. Ver o cabeçalho: o
# `scripts/painel.sh reciclar` recusa quando o supervisor dormiria minutos, e
# essa recusa é a única coisa entre um gato e uma barra sumida. `|| true`
# porque a recusa dele é decisão correta, não falha desta etapa — e o arquivo já
# está no disco de qualquer jeito, então o gato certo aparece no próximo login.
if [ "$dock_mudou" = "1" ] && ! meow_seco; then
  if [ "$LOGO_RECICLAR" != "sim" ]; then
    meow_info "gato do dock trocado; LOGO_RECICLAR=\"$LOGO_RECICLAR\" — vale no próximo login"
  elif [ -x "$RAIZ/scripts/painel.sh" ]; then
    meow_info "gato do dock trocado — reciclando o painel para ele aparecer"
    "$RAIZ/scripts/painel.sh" reciclar || true
    # E O MENU DE LANÇAMENTO, QUE É O TERCEIRO CONSUMIDOR E TEM CACHE PRÓPRIO.
    # O `com.system76.CosmicAppLibrary` que acabamos de vestir é o ícone da
    # GRADE — reciclar o painel repõe o botão do dock e não toca no
    # `cosmic-app-library`, que resolveu o ícone quando subiu. Sem esta linha o
    # gato novo aparecia no dock e no terminal, e continuava velho no menu até
    # o login seguinte: as três telas discordando sobre o mesmo arquivo, que é
    # o sintoma que este projeto persegue. Ver `meow_lancador_reler`.
    meow_lancador_reler
  fi
fi

# --- O GATO DO TERMINAL VAI JUNTO -------------------------------------------
# O `fastfetch` lê o arquivo do logo a CADA execução: não há cache, não há
# reciclo, não há pisca. Chamar daqui é o que faz o dock e o terminal nunca
# discordarem sobre a hora — e é barato, porque o `fastfetch_logo.sh` sai em
# silêncio quando o `.ansi` da fase já está no lugar.
#
# NÃO É ERRO DAQUI SE ELE FALHAR: ele tem código de saída próprio (4 = "o
# config.jsonc da Aurora ainda não aponta para nós") e quem o interpreta é o
# `install.sh` e o `bin/meow doctor`. Aqui ele é efeito colateral desejado, não
# etapa — por isso `|| true` e saída silenciada.
# `FFL_FUNDO=1` liga a guarda barata de lá: com o carimbo batendo, o tique sai
# sem rasterizar nada. Ver o bloco `_ffl_ja_esta_certo` no fastfetch_logo.sh — e
# note que o `conferir` do doctor NÃO passa essa variável, então a checagem
# profunda continua acontecendo uma vez por dia.
if [ "$LOGO_MODO" = "hora" ] && ! meow_seco && [ -x "$RAIZ/scripts/fastfetch_logo.sh" ]; then
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
  meow_ok "o gato do painel agora é ${NOMES[$proximo]} — já valendo, sem reiniciar"
else
  meow_ok "acervo de ${#POOL[@]} gato(s) instalado; no ar: ${NOMES[$proximo]}$PORQUE"
fi
exit "$MEOW_DIVERGENTE"

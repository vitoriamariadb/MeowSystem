#!/usr/bin/env bash
# logo.sh — a logo do painel gira entre os gatos de `assets/gatos/`.
#
#   ./logo.sh              instala o acervo e garante que a chave aponta para um deles
#   ./logo.sh girar        passa para o próximo gato (vale NA HORA, sem reiniciar nada)
#   ./logo.sh --conferir   não escreve; 1 se algo divergir
#   ./logo.sh listar       mostra o acervo e quem está no ar
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

ACERVO="$RAIZ/assets/gatos"
LOGOS_DIR="$HOME/.config/cosmic/logos"
APPLET="$HOME/.config/cosmic/dev.cappsy.CosmicExtAppletLogoMenu/v1"
ESTADO="$MEOW_ESTADO/logo-atual"

FLAVOR="${FLAVOR:-mocha}"
LOGO="${LOGO:-$FLAVOR}"

CONFERIR=0
ACAO="aplicar"
case "${1:-}" in
  --conferir)    CONFERIR=1 ;;
  girar)         ACAO="girar" ;;
  girar-vencido) ACAO="girar-vencido" ;;
  listar)        ACAO="listar" ;;
  aplicar|"") ;;
  *) meow_erro "uso: logo.sh [aplicar|girar|girar-vencido|listar|--conferir]"; exit "$MEOW_ERRO" ;;
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
  meow_titulo "Gatos do painel (${#POOL[@]})"
  for i in "${!NOMES[@]}"; do
    if [ "$(destino_de "${NOMES[$i]}")" = "$atual" ]; then
      meow_ok "${NOMES[$i]}  <- no ar"
    else
      meow_info "${NOMES[$i]}"
    fi
  done
  printf '\n  acervo dela: %s\n  solte um .svg ali e ele entra na rotação.\n\n' "$ACERVO"
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

if ! applet_montado; then
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

if [ "$ACAO" = "girar" ]; then
  # Fora do acervo (ou primeira vez) começa do zero; dentro, avança em círculo.
  proximo=$(( (indice + 1) % ${#NOMES[@]} ))
  [ "$indice" -lt 0 ] && proximo=0
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

if [ -f "$alvo" ]; then
  for _b in "${BOTOES_DOCK[@]}"; do
    meow_escrever "$DIR_BOTOES/$_b.svg" "$(cat "$alvo")" 644
    case $? in
      1) mudou=1 ;;
      2) meow_erro "não consegui vestir o botão do dock com $_b"; exit "$MEOW_ERRO" ;;
    esac
  done
fi

if [ "$mudou" = "0" ]; then
  meow_ok "logo já no lugar: ${NOMES[$proximo]} (acervo de ${#POOL[@]})"
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"
if [ "$ACAO" = "girar" ]; then
  meow_ok "o gato do painel agora é ${NOMES[$proximo]} — já valendo, sem reiniciar"
else
  meow_ok "acervo de ${#POOL[@]} gato(s) instalado; no ar: ${NOMES[$proximo]}"
fi
exit "$MEOW_DIVERGENTE"

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
#   O Aurora é dono de `~/.config/cosmic/logos/gato-pop.svg` e o repõe no
#   self-heal. Nós escrevemos `meow-<nome>.svg` ao lado e nunca tocamos naquele
#   arquivo — os dois acervos coexistem no mesmo diretório sem se ver.
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
  --conferir) CONFERIR=1 ;;
  girar)      ACAO="girar" ;;
  listar)     ACAO="listar" ;;
  aplicar|"") ;;
  *) meow_erro "uso: logo.sh [aplicar|girar|listar|--conferir]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

# --- o acervo ---------------------------------------------------------------
# O gato gerado do flavor entra sempre (é o do projeto, e nasce da paleta); os
# de `assets/gatos/` são os DELA. A ordem é estável — alfabética, com o do
# projeto na frente — para que "o próximo" signifique a mesma coisa em toda
# execução, inclusive depois de um reboot.
declare -a POOL=() NOMES=()
GATO_PROJETO="$RAIZ/assets/meow-${LOGO}-painel.svg"
[ -f "$GATO_PROJETO" ] || GATO_PROJETO="$RAIZ/assets/meow-${FLAVOR}-painel.svg"
if [ -f "$GATO_PROJETO" ]; then
  POOL+=("$GATO_PROJETO"); NOMES+=("$FLAVOR")
fi
if [ -d "$ACERVO" ]; then
  while IFS= read -r svg; do
    case "$(basename "$svg")" in *-symbolic.svg) continue ;; esac
    POOL+=("$svg"); NOMES+=("$(basename "${svg%.svg}")")
  done < <(find "$ACERVO" -maxdepth 1 -name '*.svg' | sort)
fi

if [ "${#POOL[@]}" -eq 0 ]; then
  meow_pula "não há gato nenhum em assets/gatos/ nem gerado — nada a girar"
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
    proximo=0
  fi
fi

alvo="$(destino_de "${NOMES[$proximo]}")"
if [ "$alvo" != "$atual" ]; then
  # O RON quer a string entre aspas e SEM newline no fim: um \n a mais faz o
  # applet ignorar o valor calado.
  meow_escrever "$APPLET/custom_logo_path" "\"$alvo\"" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "não consegui apontar a logo"; exit "$MEOW_ERRO" ;; esac
  meow_seco || printf '%s' "${NOMES[$proximo]}" > "$ESTADO" 2>/dev/null || true
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

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
#   `dev.cappsy` não vem com o COSMIC. Numa máquina que não o tenha, isto aqui
#   não é erro: é etapa pulada, com a razão dita em voz alta. O MeowSystem vai
#   ser publicado, e supor o applet de um terceiro seria supor a máquina dela.
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

# --- o applet existe? -------------------------------------------------------
if [ ! -d "$APPLET" ]; then
  meow_pula "o applet dev.cappsy (logo do painel) não está nesta máquina"
  exit "$MEOW_SEM_DEPENDENCIA"
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

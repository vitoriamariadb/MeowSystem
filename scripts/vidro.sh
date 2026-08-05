#!/usr/bin/env bash
# vidro.sh — o vidro fosco do painel e do dock CONTINUA quando uma janela maximiza.
#
# O QUE ELA PERDEU, E O QUE ESTA CHAVE FAZ
#   O COSMIC tem um comportamento embutido: quando uma janela é maximizada, o
#   painel e o dock LARGAM o estilo translúcido e ficam opacos, encostados na
#   janela. A chave `keep_style_on_maximize` desliga esse comportamento — com
#   `true`, o vidro fosco fica igual, maximizado ou não.
#
#   Ela tinha isso ligado e perdeu. As duas chaves estavam em `false` (medido em
#   2026-08-04, 23:43): o padrão de fábrica. Nada no MeowSystem escrevia essa
#   chave — por isso o `meow doctor` nunca acusou nada, e por isso ela some
#   silenciosamente a cada vez que algo restaura o padrão.
#
# SÃO DUAS CHAVES, NÃO UMA
#   `CosmicPanel.Panel` (a barra de cima) e `CosmicPanel.Dock` (a barra de baixo)
#   são configurações INDEPENDENTES, cada uma com sua própria chave. Escrever só
#   uma deixa metade da tela certa e metade errada — que é pior que as duas
#   erradas, porque parece bug de renderização e não configuração.
#
# VALE NA HORA: O PAINEL VIGIA ESTES DIRETÓRIOS (medido em 2026-08-04)
#   Lendo `/proc/<pid do cosmic-panel>/fdinfo/*`, ele mantém SEIS watches de
#   inotify, e os inodes resolvem exatamente para:
#       com.system76.CosmicPanel/v1        com.system76.CosmicTheme.Mode/v1
#       com.system76.CosmicPanel.Panel/v1  com.system76.CosmicTheme.Light/v2
#       com.system76.CosmicPanel.Dock/v1   com.system76.CosmicTheme.Dark/v2
#
#   Ou seja: escrever aqui aplica SEM reiniciar o painel, sem piscar a tela dela
#   e sem gastar uma das vidas do respawn do `cosmic-session`. Isto corrige, com
#   medida, o comentário do `construir_icones.sh` que dizia "o cosmic-panel não
#   vigia arquivo nenhum (zero fds de inotify)": ele vigia estes seis. O que ele
#   NÃO vigia é o `CosmicTk/icon_theme` nem os arquivos de ícone — e é por isso
#   que a conclusão de lá (reiniciar só quando o tema de ícones muda de nome)
#   continua valendo, mesmo com a justificativa corrigida.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

# "sim" -> o vidro fica ao maximizar. "nao" -> volta o comportamento de fábrica.
VIDRO_AO_MAXIMIZAR="${VIDRO_AO_MAXIMIZAR:-sim}"

# Quanto da COR da barra entra na mistura com o que está atrás. 0 = só o fundo
# desfocado; 1 = chapado, sem vidro nenhum.
#
# ESTE NÚMERO MULTIPLICA OS SLIDERES DELA — E FOI ASSIM QUE EU OS ANULEI
#   O alpha que a barra desenha não é esta chave sozinha. No `cosmic-panel`
#   (`space/panel_space.rs`, `bg_color`) ele é:
#
#       alpha = opacity  x  alpha_map[frosted]
#
#   e `frosted`/`alpha_map` são exatamente os dois sliders de Aparência → Vidro
#   fosco ("Espessura do efeito fosco" e "Opacidade do vidro"). O `alpha_map`
#   desta máquina vai de 0,62 a 0,92 — ou seja, o slider inteiro é um fator de
#   pouco mais de 1,5x. Quem manda na escala é ESTA chave:
#
#       opacity   alcance do slider, ponta a ponta
#       0.05      3,1% -> 4,6%    = 1,5 ponto   (invisível)
#       0.10      6,2% -> 9,2%    = 3,0 pontos
#       0.24     14,9% -> 22,1%   = 7,2 pontos
#       0.50     31,0% -> 46,0%   = 15 pontos
#
#   Em 05/08 eu unifiquei as duas barras em 0.05 para corrigir uma assimetria que
#   ELA não tinha reclamado — e o efeito colateral foi tirar dos sliders dela
#   qualquer autoridade visível. A queixa "os sliders não funcionam" nasceu daqui.
#
# POR QUE VOLTARAM A SER DUAS CHAVES
#   O COSMIC trata painel e dock como configurações independentes, com páginas
#   separadas na GUI. Impor um valor só é uma decisão nossa sobre a tela dela.
#   Os padrões abaixo são o que ela tinha e escolheu; `VIDRO_OPACIDADE` continua
#   valendo como atalho para igualar as duas de uma vez.
VIDRO_OPACIDADE_PAINEL="${VIDRO_OPACIDADE_PAINEL:-${VIDRO_OPACIDADE:-0.1}}"
VIDRO_OPACIDADE_DOCK="${VIDRO_OPACIDADE_DOCK:-${VIDRO_OPACIDADE:-0.24}}"

case "$VIDRO_AO_MAXIMIZAR" in
  sim|true|1)  desejado="true" ;;
  nao|não|false|0) desejado="false" ;;
  *) meow_erro "VIDRO_AO_MAXIMIZAR='$VIDRO_AO_MAXIMIZAR' — esperado sim|nao"
     exit "$MEOW_ERRO" ;;
esac

# O RON quer o float com ponto decimal. "0.05" e ".05" são a mesma coisa para o
# shell e coisas diferentes para o parser: normalizar aqui evita um valor que o
# COSMIC descarta calado, deixando a barra no padrão sem dizer por quê.
normalizar_opacidade() {
  case "$2" in
    [0-9]*.[0-9]*|[0-9]) printf '%s' "$2" ;;
    .[0-9]*)             printf '0%s' "$2" ;;
    *) meow_erro "$1='$2' — esperado um número entre 0 e 1"; return 1 ;;
  esac
}

op_painel="$(normalizar_opacidade VIDRO_OPACIDADE_PAINEL "$VIDRO_OPACIDADE_PAINEL")" \
  || exit "$MEOW_ERRO"
op_dock="$(normalizar_opacidade VIDRO_OPACIDADE_DOCK "$VIDRO_OPACIDADE_DOCK")" \
  || exit "$MEOW_ERRO"

BASE="$HOME/.config/cosmic"
BARRAS=(Panel Dock)

mudou=0
escritos=0
for barra in "${BARRAS[@]}"; do
  dir="$BASE/com.system76.CosmicPanel.$barra/v1"
  # O diretório tem de existir: criá-lo do nada faria o COSMIC ver uma
  # configuração de painel órfã, sem as outras chaves. Se ele não existe, o
  # painel correspondente não está configurado nesta máquina — não é erro.
  [ -d "$dir" ] || { meow_pula "com.system76.CosmicPanel.$barra não está configurado aqui"; continue; }

  escritos=$((escritos + 1))
  case "$barra" in Panel) opacidade="$op_painel" ;; *) opacidade="$op_dock" ;; esac

  # `keep_style_on_maximize` é a única das duas que é nossa de verdade: a GUI do
  # COSMIC não tem controle para ela, então se ninguém a escrever ela se perde em
  # silêncio — foi o que aconteceu e ninguém percebeu, porque nada a conferia.
  meow_escrever "$dir/keep_style_on_maximize" "$desejado" 644
  case $? in
    1) mudou=1 ;;
    2) meow_erro "não consegui escrever $dir/keep_style_on_maximize"; exit "$MEOW_ERRO" ;;
  esac
  meow_escrever "$dir/opacity" "$opacidade" 644
  case $? in
    1) mudou=1 ;;
    2) meow_erro "não consegui escrever $dir/opacity"; exit "$MEOW_ERRO" ;;
  esac
done

# NENHUM alvo existe é diferente de "os dois já estão certos", e a primeira
# versão dizia a mesma frase nos dois casos. Num HOME recém-criado ela pulava os
# dois painéis, um por linha, e logo abaixo anunciava "o vidro já continua ao
# maximizar (painel e dock)" — sobre dois painéis que não existem. Contradizer a
# si mesmo duas linhas depois é pior do que não dizer nada.
if [ "$escritos" -eq 0 ]; then
  meow_pula "não há painel nem dock configurados — nada a ajustar"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

if [ "$mudou" = "0" ]; then
  if [ "$desejado" = "true" ]; then
    meow_ok "vidro já conforme: painel $op_painel, dock $op_dock, mantido ao maximizar"
  else
    meow_ok "vidro já conforme: painel $op_painel, dock $op_dock; sai ao maximizar (padrão do COSMIC)"
  fi
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"

if [ "$desejado" = "true" ]; then
  meow_ok "painel $op_painel e dock $op_dock, vidro mantido ao maximizar — já valendo"
else
  meow_ok "painel $op_painel e dock $op_dock; o vidro sai ao maximizar — já valendo"
fi
exit "$MEOW_DIVERGENTE"

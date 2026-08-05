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

case "$VIDRO_AO_MAXIMIZAR" in
  sim|true|1)  desejado="true" ;;
  nao|não|false|0) desejado="false" ;;
  *) meow_erro "VIDRO_AO_MAXIMIZAR='$VIDRO_AO_MAXIMIZAR' — esperado sim|nao"
     exit "$MEOW_ERRO" ;;
esac

BASE="$HOME/.config/cosmic"
ALVOS=(
  "$BASE/com.system76.CosmicPanel.Panel/v1/keep_style_on_maximize"
  "$BASE/com.system76.CosmicPanel.Dock/v1/keep_style_on_maximize"
)

mudou=0
escritos=0
for alvo in "${ALVOS[@]}"; do
  # O diretório tem de existir: criá-lo do nada faria o COSMIC ver uma
  # configuração de painel órfã, sem as outras chaves. Se ele não existe, o
  # painel correspondente não está configurado nesta máquina — não é erro.
  dir="$(dirname "$alvo")"
  [ -d "$dir" ] || { meow_pula "$(basename "$(dirname "$dir")") não está configurado aqui"; continue; }

  escritos=$((escritos + 1))
  meow_escrever "$alvo" "$desejado" 644
  case $? in
    1) mudou=1 ;;
    2) meow_erro "não consegui escrever $alvo"; exit "$MEOW_ERRO" ;;
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
    meow_ok "o vidro já continua ao maximizar (painel e dock)"
  else
    meow_ok "o vidro já sai ao maximizar (padrão do COSMIC)"
  fi
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"

if [ "$desejado" = "true" ]; then
  meow_ok "vidro fosco mantido ao maximizar — painel e dock, já valendo"
else
  meow_ok "vidro ao maximizar desligado (padrão do COSMIC) — já valendo"
fi
exit "$MEOW_DIVERGENTE"

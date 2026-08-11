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

CONFERIR=0
for _a in "$@"; do
  case "$_a" in
    --conferir) CONFERIR=1 ;;
    -h|--help) printf 'uso: vidro.sh [--conferir]\n\n  --conferir  não escreve nada: mostra o que está no disco e a\n              faixa real de alpha derivada do alpha_map de agora.\n'; exit 0 ;;
    *) meow_erro "opção desconhecida: '$_a' — só existe --conferir"; exit 2 ;;
  esac
done
unset _a

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
#   fosco ("Espessura do efeito fosco" e "Opacidade do vidro").
#
#   AQUI HAVIA UMA TABELA FOTOGRAFADA, E ELA ENVELHECEU 3x
#     Este bloco dizia "o alpha_map desta máquina vai de 0,62 a 0,92" e trazia
#     quatro linhas de porcentagem derivadas disso. Em 10/08/2026 o alpha_map
#     vivo ia de 0,18 a 0,48 — a tabela estava quase três vezes otimista, e foi
#     ela que sustentou o `opacity=0.1` como se desse "6,2% a 9,2%". Desenhava
#     2,3%. O `alpha_map` é REESCRITO toda vez que o tema é reimportado; qualquer
#     número fotografado aqui vira mentira na importação seguinte. Por isso a
#     tabela agora é DERIVADA na hora:
#
#         scripts/vidro.sh --conferir
#
#   ATENÇÃO À NOMENCLATURA INVERTIDA DO alpha_map
#     `extremely_high_2` é o MENOR alpha (mais fosco = menos cor própria da
#     barra) e `extremely_low` é o MAIOR. Ler "high" como "mais opaco" inverte a
#     conclusão inteira.
#
#   Em 05/08 eu unifiquei as duas barras em 0.05 para corrigir uma assimetria que
#   ELA não tinha reclamado — e o efeito colateral foi tirar dos sliders dela
#   qualquer autoridade visível. A queixa "os sliders não funcionam" nasceu daqui.
#
# POR QUE VOLTARAM A SER DUAS CHAVES
#   O COSMIC trata painel e dock como configurações independentes, com páginas
#   separadas na GUI. Impor um valor só é uma decisão nossa sobre a tela dela.
#   `VIDRO_OPACIDADE` continua valendo como atalho para igualar as duas de uma vez.
#
# POR QUE OS PADRÕES SUBIRAM DE 0.1/0.24 PARA 0.19/0.26 EM 10/08/2026
#   O ALVO É PORCENTAGEM DESENHADA, NÃO O NÚMERO DESTA CHAVE. Foi essa distinção
#   que faltou, e ela custou três medições no mesmo dia:
#
#     16:01  alpha_map ia de 0,18 a 0,48 (very_high_2 = 0,22615).
#            Com 0.1 e 0.24, o painel desenhava 2,3% e o dock 5,4% — a queixa
#            "as barras não têm corpo" era literalmente isso.
#     18:31  ELA mexeu o slider "Opacidade do vidro" em Aparência. A GUI rederivou
#            o tema inteiro (37 arquivos entre 18:31:39 e 18:32:47) e o alpha_map
#            passou a ir de 0,61 a 0,91. Com as MESMAS chaves, painel 6,6% e dock
#            15,8%: metade do problema ela já tinha resolvido sozinha, no controle
#            que é dela.
#
#   A conta 0.55/0.75 que parecia dar "12,4% e 17,0%" foi feita com o alpha_map
#   das 16:01. Aplicada às 18:40 daria 36% e 49% — barra quase chapada, e o vidro
#   fosco vira lembrança. Por isso o alvo ficou sendo a PORCENTAGEM combinada
#   (painel ~12,4%, dock ~17,0%) e o número desta chave saiu dela por divisão:
#   0,124/0,65615 = 0,19 e 0,170/0,65615 = 0,26.
#
#   A PROPORÇÃO DELA FOI PRESERVADA, E ISSO É DE PROPÓSITO. O dock continua mais
#   presente que o painel — igualar as duas foi exatamente o erro de 05/08
#   descrito acima. E a folga do slider continua: de ponta a ponta do alpha_map
#   de hoje, o painel varia de 11,6% a 17,3%, e o dock de 15,9% a 23,7%. Os
#   controles dela seguem valendo alguma coisa, que era a queixa original.
#
#   SE A PORCENTAGEM DE HOJE NÃO FOR MAIS ESTA, o número aqui é que está velho —
#   não a conta. `scripts/vidro.sh --conferir` imprime a tabela derivada do
#   alpha_map de agora, inclusive a linha "hoje, com frosted=...". Divida o alvo
#   pelo fator que ele mostra e escreva o resultado aqui.
#
#   Quem quiser a leitura de waybar de verdade (30-40% de cor) tem dois caminhos,
#   e os dois são dela: o slider "Opacidade do vidro" (que move o alpha_map) e o
#   "Espessura do efeito fosco" (que escolhe qual chave do alpha_map vale).
#
# ESTES DOIS PADRÕES SÃO O QUE REALMENTE VALE — O meow.conf NÃO CHEGA AQUI
#   Medido em 10/08/2026: `bin/meow` sourceia o meow.conf sem exportar, e tanto
#   `chk_vidro` quanto `fix_vidro` passam só `VIDRO_AO_MAXIMIZAR` na linha de
#   comando. O `etapa_vidro` do install.sh faz igual. Ou seja: as chaves
#   `VIDRO_OPACIDADE_*` do meow.conf são lidas por bin/meow e morrem lá — nunca
#   alcançam este script. Enquanto a ponte não existir, os padrões daqui e os
#   valores do meow.conf têm de ser mantidos IGUAIS, senão o `meow doctor
#   --consertar` desfaz calado o que ela escreveu no conf. A ponte é uma linha em
#   cada uma das duas funções de bin/meow, e está anotada como pendência.
VIDRO_OPACIDADE_PAINEL="${VIDRO_OPACIDADE_PAINEL:-${VIDRO_OPACIDADE:-0.19}}"
VIDRO_OPACIDADE_DOCK="${VIDRO_OPACIDADE_DOCK:-${VIDRO_OPACIDADE:-0.26}}"

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

BASE="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}"
BARRAS=(Panel Dock)

_frosted_para_chave() {
  # "VeryLow2" -> "very_low_2" ; "Low2" -> "low_2" ; "Medium" -> "medium"
  printf '%s' "$1" | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g; s/([A-Za-z])([0-9])/\1_\2/g' \
    | tr 'A-Z' 'a-z'
}

# --- --conferir: a tabela que não envelhece ---------------------------------
# O `alpha_map` é reescrito a cada reimportação do tema, então a única tabela
# honesta é a que se calcula na hora. As duas pontas da faixa são
# `extremely_high_2` (o MENOR alpha — mais fosco) e `extremely_low` (o maior);
# elas são rotuladas aqui pelo EFEITO e não pelo nome da chave, porque o nome
# mente: "high" ali é mais fosco, não mais opaco.
faixa_alpha() {
  local am="$BASE/com.system76.CosmicTheme.Dark/v2/alpha_map"
  [ -r "$am" ] || { meow_pula "alpha_map ausente — sem faixa a mostrar"; return 0; }
  local lo hi frosted fator chave o
  lo="$(sed -nE 's/.*[^a-z_]extremely_high_2: *([0-9.]+).*/\1/p' "$am" | head -1)"
  hi="$(sed -nE 's/.*[^a-z_]extremely_low: *([0-9.]+).*/\1/p' "$am" | head -1)"
  [ -n "$lo" ] && [ -n "$hi" ] || { meow_pula "não consegui ler as pontas do alpha_map"; return 0; }

  meow_info "quanto da COR da barra é desenhada, com o alpha_map de agora:"
  printf '    %-9s %s\n' "opacity" "mais fosco  ->  menos fosco"
  for o in 0.10 0.19 0.24 0.26 0.50 1.00; do
    awk -v o="$o" -v lo="$lo" -v hi="$hi" \
      'BEGIN{printf "    %-9s %5.1f%%       ->  %5.1f%%\n", o, o*lo*100, o*hi*100}'
  done
  printf '    (a faixa vem do alpha_map vivo: %s a %s)\n' "$lo" "$hi"

  # E o ponto exato em que ela está agora — que é o único número que importa
  # para decidir se a barra tem corpo ou não.
  frosted="$(cat "$BASE/com.system76.CosmicTheme.Dark/v2/frosted" 2>/dev/null)" || return 0
  [ -n "$frosted" ] || return 0
  chave="$(_frosted_para_chave "$frosted")"
  fator="$(sed -nE "s/.*[^a-z_]${chave}: *([0-9.]+).*/\1/p" "$am" | head -1)"
  [ -n "$fator" ] || return 0
  awk -v f="$fator" -v p="$op_painel" -v d="$op_dock" -v n="$frosted" \
    'BEGIN{printf "    hoje, com frosted=%s (%.5f): painel %.1f%%, dock %.1f%%\n", n, f, p*f*100, d*f*100}'
}

if [ "$CONFERIR" = "1" ]; then
  meow_info "no disco agora:"
  for barra in "${BARRAS[@]}"; do
    dir="$BASE/com.system76.CosmicPanel.$barra/v1"
    [ -d "$dir" ] || { meow_pula "com.system76.CosmicPanel.$barra não está configurado aqui"; continue; }
    printf '    %-6s opacity=%s  keep_style_on_maximize=%s\n' "$barra" \
      "$(cat "$dir/opacity" 2>/dev/null || echo '?')" \
      "$(cat "$dir/keep_style_on_maximize" 2>/dev/null || echo '?')"
  done
  meow_info "o que este script quer: painel $op_painel, dock $op_dock, ao maximizar $desejado"
  faixa_alpha
  exit "$MEOW_OK"
fi

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

# --- A RECEITA E O PRODUTO ESTÃO DE ACORDO? ---------------------------------
# ISTO TERIA GRITADO ÀS 18:00:40 DE 05/08 EM VEZ DE FICAR QUATRO HORAS INVISÍVEL
#   Em Aparência ela escolhe `frosted` (um nome: Low2, High2...) e a GUI DERIVA a
#   cor com o alpha correspondente em `alpha_map`. Se alguém reescrever a cor
#   derivada por fora — foi o que o instalador fez, impondo a captura —, a receita
#   passa a apontar para um vidro que a cor gravada não tem. Nada quebra, nada
#   avisa, e a tela fica diferente do que o painel de controle diz.
#
#   Aqui só se COMPARA e se AVISA. Corrigir seria escrever o produto derivado na
#   mão, que é precisamente o ato que criou o problema — e a derivação real tem
#   mais campos do que este script conhece. Quem deriva certo é a GUI: mover o
#   slider uma vez basta.
#
# (`_frosted_para_chave` mora lá em cima, junto do `--conferir`: as duas
#  conferências precisam dela, e a de cima roda antes deste ponto do arquivo.)

conferir_receita() {
  local b="$BASE/com.system76.CosmicTheme.Dark.Builder/v2"
  local d="$BASE/com.system76.CosmicTheme.Dark/v2"
  [ -f "$b/frosted" ] && [ -f "$b/alpha_map" ] && [ -f "$d/transparent_background" ] || return 0

  local nome chave fator esperado gravado
  nome="$(cat "$b/frosted")"
  chave="$(_frosted_para_chave "$nome")"
  fator="$(sed -nE "s/.*[^a-z_]${chave}: *([0-9.]+).*/\1/p" "$b/alpha_map" | head -1)"
  [ -n "$fator" ] || return 0

  esperado="$(python3 -c "print(f'{round($fator*255):02X}')" 2>/dev/null)" || return 0
  gravado="$(grep -oE '#[0-9A-Fa-f]{8}' "$d/transparent_background" | head -1)"
  gravado="${gravado: -2}"
  [ -n "$gravado" ] || return 0

  if [ "$esperado" != "$gravado" ]; then
    meow_aviso "o vidro na tela não é o que você escolheu: '$nome' pede alpha $esperado, está gravado $gravado"
    meow_info "abra Aparência e mova o slider de opacidade uma vez — só a GUI deriva a cor corretamente"
    return 1
  fi
  return 0
}

if [ "$mudou" = "0" ]; then
  if [ "$desejado" = "true" ]; then
    meow_ok "vidro já conforme: painel $op_painel, dock $op_dock, mantido ao maximizar"
  else
    meow_ok "vidro já conforme: painel $op_painel, dock $op_dock; sai ao maximizar (padrão do COSMIC)"
  fi
  # Sai 4, não 1: não há o que consertar — quem deriva é a GUI. Ver o cabeçalho de
  # `conferir_receita` e o bloco do código 4 em scripts/aplicar_tema.sh.
  conferir_receita || exit 4
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"

if [ "$desejado" = "true" ]; then
  meow_ok "painel $op_painel e dock $op_dock, vidro mantido ao maximizar — já valendo"
else
  meow_ok "painel $op_painel e dock $op_dock; o vidro sai ao maximizar — já valendo"
fi
exit "$MEOW_DIVERGENTE"

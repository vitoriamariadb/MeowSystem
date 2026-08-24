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
#       alpha = opacity  x  alpha_map[frosted]      (SÓ SE frosted_panel)
#
#   e `frosted`/`alpha_map` são exatamente os dois sliders de Aparência → Vidro
#   fosco ("Espessura do efeito fosco" e "Opacidade do vidro").
#
#   A FÓRMULA FOI CONFIRMADA EM 23/08/2026, E GANHOU DUAS PORTAS (ver o bloco
#   de 23/08 mais abaixo). A assinatura de hoje, upstream, é:
#
#       pub fn bg_color(&self, mut alpha: f32, opaque: bool) -> [f32; 4] {
#           if self.theme.cosmic().frosted_panel && self.blur_enabled {
#               alpha *= self.theme.cosmic().alpha_map
#                            .blurred_alpha(self.theme.cosmic().frosted);
#           }
#           if opaque { alpha = 1.; }
#           self.color_override.unwrap_or_else(|| {
#               let c = self.theme.cosmic().bg_color();
#               [c.red, c.green, c.blue, alpha]
#           })
#       }
#
#   Ou seja: a multiplicação por `alpha_map[frosted]` é CONDICIONADA a
#   `frosted_panel` (a caixa "Painéis" em Aparência → Vidro fosco). Desmarcá-la
#   faz o slider dela virar 1:1 — é o único jeito de a barra chegar a 100%.
#   E o `opaque` é uma segunda porta que zera tudo, ver o bloco de 23/08.
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
# ===========================================================================
# 17/08/2026: A OPACIDADE DEIXOU DE SER NOSSA. O PADRÃO AGORA É NÃO ESCREVER.
# ===========================================================================
#   "a opacidade de fundo da dock do painel precisam ser de acordo com o que eu
#   setar aqui nas configs do próprio cosmic. isso pq agora tá completamente
#   ilegível os icones e afins."
#
#   O SLIDER "Opacidade do fundo" DA GUI ESCREVE EXATAMENTE ESTA CHAVE. Não é
#   um controle paralelo que a gente atropela por azar: Ajustes → Área de
#   trabalho → Painel → "Opacidade do fundo" grava
#   `com.system76.CosmicPanel.Panel/v1/opacity`, o MESMO arquivo que este script
#   escrevia toda passagem. Com o `meow-doctor.timer` rodando `fix_vidro` todo
#   dia, o número dela voltava para 0.19/0.26 sem nada dizer por quê — e a
#   captura que ela mandou mostrava o slider EXIBINDO 19 e 26, ou seja, a GUI
#   mostrando o nosso valor como se fosse a escolha dela.
#
#   Isto é a terceira vez que a mesma fronteira é atravessada no mesmo arquivo
#   (05/08: unificar as duas em 0.05; 10/08: rederivar para 0.19/0.26). As duas
#   correções anteriores mexeram no NÚMERO. Esta muda o DONO: onde a GUI tem
#   controle, o valor é dela, e nós não escrevemos.
#
#   O QUE CONTINUA SENDO NOSSO: `keep_style_on_maximize`. A GUI não tem controle
#   para essa chave — se ninguém a escrever, ela se perde em silêncio, que é o
#   defeito que fez este script nascer. Essa parte não mudou.
#
#   COMO IMPOR DE NOVO, SE UM DIA ELA QUISER: defina `VIDRO_OPACIDADE_PAINEL` /
#   `VIDRO_OPACIDADE_DOCK` (ou `VIDRO_OPACIDADE` para as duas) no meow.conf.
#   VAZIO — o padrão — significa "não toque". A ponte do meow.conf até aqui foi
#   fechada no mesmo dia (era a pendência anotada no bloco abaixo): `bin/meow` e
#   `install.sh` agora repassam as três chaves.
#
#   A CONTA ABAIXO CONTINUA VALENDO, e é por isso que ela ficou. Se ela pedir um
#   valor imposto, `--conferir` deriva a porcentagem real do alpha_map de hoje.
#
# ===========================================================================
# 23/08/2026: "A OPACIDADE NÃO É RESPEITADA" — ELA É. O QUE FALTA É CONTRASTE.
# ===========================================================================
#   "quando vamos seja em painel ou dock e alteramos a opacidade da barra ela
#   não é respeitada"
#
#   O slider dela FUNCIONA, e aplica na hora. O que estava errado era a
#   expectativa de que 19 no slider virasse 19% na tela — e, principalmente, a
#   suposição de que o efeito seria visível contra QUALQUER coisa atrás.
#
#   O MÉTODO: escrever a chave, capturar a tela, medir o pixel. As barras foram
#   amostradas numa faixa vazia do painel (340x45+1155+15) com `convert ... -format
#   '%[fx:mean.r*255] ...'`, sempre com o dock intocado como CONTROLE — e o
#   controle saiu pixel-idêntico em todas as capturas, o que valida a comparação.
#
#   MEDIÇÃO 1 — A FÓRMULA ESTÁ CERTA, E O FATOR É 0,54
#     Com o papel de parede (claro, quente) atrás do painel e
#     `keep_style_on_maximize=true`:
#
#         opacity=0.19  ->  painel R,G,B = 157,9  130,2  118,8
#         opacity=0.95  ->  painel R,G,B = 107,8   93,7   95,5
#         opacity=0.19  ->  painel R,G,B = 157,9  130,2  118,8   (repetição exata)
#
#     Resolvendo P = a*C + (1-a)*B com C = #313244 = (49,50,68), o único `a`
#     que fecha nos TRÊS canais é `a = opacity x 0,541`. O fundo desfocado sai
#     em (170,139,125). Predito para 0.95: (108,0 / 93,5 / 95,6). Medido:
#     (107,8 / 93,7 / 95,5). O erro é menor que um nível de cor.
#
#     0,541 é `alpha_map[extremely_high_2]` = 0,54, que é o `frosted` dela.
#     **O `--conferir` deste script já dizia "painel 10,3%" e estava certo.**
#     Isto CONFIRMA a fórmula do bloco lá em cima em vez de contradizê-la — é a
#     primeira vez que ela é medida no pixel, e não só lida no código.
#
#   MEDIÇÃO 2 — O QUE ELA VÊ DEPENDE DO QUE ESTÁ ATRÁS, E ESSA É A QUEIXA
#     A MESMA mudança de slider, com um terminal MAXIMIZADO escuro (#1E1E2E)
#     atrás em vez do papel de parede:
#
#         opacity=0.19  ->  painel R,G,B = 43,8  44,8  63,8
#         opacity=0.95  ->  painel R,G,B = 46,1  47,6  65,8
#
#     De 19 a 95 — 76 pontos dos 100 do slider — o pixel anda 2,3 níveis de 255.
#     Contra o papel de parede, a MESMA mudança anda 50 níveis. É a mesma chave,
#     o mesmo código, o mesmo tema: 22x menos autoridade só porque a cor própria
#     da barra (#313244) é quase igual ao que está atrás (#1E1E2E).
#
#     P = a*C + (1-a)*B. Quando C ~ B, P ~ B para QUALQUER a. A barra some no
#     fundo por aritmética, não por bug. E o estado normal de trabalho dela é
#     justamente uma janela escura maximizada.
#
#   MEDIÇÃO 3 — SEM `keep_style_on_maximize` O SLIDER MORRE DE VEZ
#     Com a chave em `false` e uma janela maximizada:
#
#         opacity=0.19  ->  painel R,G,B = 49  50  68   (#313244 exato)
#         opacity=0.95  ->  painel R,G,B = 49  50  68   (#313244 exato)
#
#     PIXEL-IDÊNTICOS. Não é "pouco efeito": é efeito ZERO, a barra chapada na
#     cor do tema. O upstream explica:
#
#         let effective_maximized = maximized && !config.keep_style_on_maximize;
#         let opacity = if effective_maximized { config.maximize(); 1.0 }
#                       else { config.opacity };
#
#     e `CosmicPanelConfig::maximize()` faz `self.opacity = 1.0`.
#
#     ISTO MUDA O PORQUÊ DESTE SCRIPT EXISTIR. O cabeçalho dizia que
#     `keep_style_on_maximize` era nossa porque "a GUI não tem controle e ela se
#     perde em silêncio". Continua verdade, mas era pouco: ela é a PRÉ-CONDIÇÃO
#     para o slider dela funcionar. Se a chave cair, a opacidade que ela escolher
#     não vale mais nada enquanto houver janela maximizada — e o sintoma é
#     exatamente a frase que ela escreveu. Conferir esta chave deixou de ser
#     zelo e virou a defesa do controle dela.
#
#   O QUE A MEDIÇÃO DERRUBOU
#     A suspeita natural era que o alpha do `base:` de `background` (0x8A),
#     que o Ritual da Aurora escreve, estivesse atropelando o `opacity`. NÃO
#     ESTÁ: o `bg_color` do painel usa só os canais R,G,B do tema e DESCARTA o
#     alpha (`[c.red, c.green, c.blue, alpha]`). O 0,54 que aparece na conta vem
#     do `alpha_map[frosted]`, não do `base:`. O `aurora-vidro-maximizado.py`
#     está inocente nesta queixa — e ele nem impõe número: copia o alpha de
#     `transparent_X.base` para `X.base`, ou seja, propaga a escolha DELA.
#
#   O QUE MOVE A AGULHA DE VERDADE, E É TUDO CONTROLE DELA
#     1. "Espessura do efeito fosco" (`frosted`). Ela está em ExtremelyHigh2,
#        que é o MENOR alpha do mapa (0,54) — o teto do slider de opacidade.
#        Mesmo em 100 a barra só desenha 54% da própria cor. Andar para
#        `extremely_low` levaria o teto a 84%.
#     2. A caixa "Painéis" (`frosted_panel`). Desmarcada, a multiplicação some
#        e o slider vira 1:1 — 19 desenha 19%, 100 desenha 100%.
#     3. "Opacidade do vidro", que move o `alpha_map` inteiro.
#     Nenhum dos três é nosso, e nenhum deve virar chave do meow.conf: a lição
#     de 17/08 foi exatamente essa. O que nos cabe é DIZER, e é o que o
#     `--conferir` passou a fazer.
#
#   O PAINEL RELÊ NA HORA — A MEDIÇÃO DE 04/08 CONTINUA VALENDO
#     Reconferido hoje: seis watches de inotify em `/proc/<pid>/fdinfo/*`, e os
#     inodes resolvem para os MESMOS seis diretórios listados no topo deste
#     arquivo. O PID do `cosmic-panel` (364986) era o mesmo antes da primeira
#     escrita e depois da última — treze escritas de `opacity` e duas de
#     `keep_style_on_maximize`, todas aplicadas na hora, nenhuma reinicialização.
#
# COMO OS PADRÕES ANTIGOS (0.19/0.26) FORAM CALCULADOS EM 10/08/2026
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
# A PONTE DO meow.conf ATÉ AQUI ESTÁ FECHADA (17/08/2026)
#   Este bloco dizia: "`bin/meow` sourceia o meow.conf sem exportar, e tanto
#   `chk_vidro` quanto `fix_vidro` passam só `VIDRO_AO_MAXIMIZAR` na linha de
#   comando — as chaves `VIDRO_OPACIDADE_*` morrem lá". Era verdade e virou
#   URGENTE quando o padrão passou a ser vazio: sem a ponte, escrever um valor
#   no meow.conf não teria efeito NENHUM, e o silêncio seria pior que o
#   atropelo. `bin/meow` (chk_vidro/fix_vidro) e `install.sh` (etapa_vidro)
#   repassam as três chaves agora.
#
# VAZIO É O PADRÃO, E VAZIO QUER DIZER "NÃO TOQUE"
#   Sem valor definido, este script não escreve `opacity` — quem manda é o
#   slider de Ajustes → Área de trabalho → Painel/Dock → "Opacidade do fundo".
VIDRO_OPACIDADE_PAINEL="${VIDRO_OPACIDADE_PAINEL:-${VIDRO_OPACIDADE:-}}"
VIDRO_OPACIDADE_DOCK="${VIDRO_OPACIDADE_DOCK:-${VIDRO_OPACIDADE:-}}"

case "$VIDRO_AO_MAXIMIZAR" in
  sim|true|1)  desejado="true" ;;
  nao|não|false|0) desejado="false" ;;
  *) meow_erro "VIDRO_AO_MAXIMIZAR='$VIDRO_AO_MAXIMIZAR' — esperado sim|nao"
     exit "$MEOW_ERRO" ;;
esac

# O RON quer o float com ponto decimal. "0.05" e ".05" são a mesma coisa para o
# shell e coisas diferentes para o parser: normalizar aqui evita um valor que o
# COSMIC descarta calado, deixando a barra no padrão sem dizer por quê.
#
# A STRING VAZIA PASSA DE PROPÓSITO, e é ela que carrega o "não toque". Um
# `case` que estourasse no vazio transformaria o padrão novo em erro de uso.
normalizar_opacidade() {
  case "$2" in
    "")                  printf '' ;;
    [0-9]*.[0-9]*|[0-9]) printf '%s' "$2" ;;
    .[0-9]*)             printf '0%s' "$2" ;;
    *) meow_erro "$1='$2' — esperado um número entre 0 e 1 (ou vazio, para deixar com a GUI)"; return 1 ;;
  esac
}

op_painel="$(normalizar_opacidade VIDRO_OPACIDADE_PAINEL "$VIDRO_OPACIDADE_PAINEL")" \
  || exit "$MEOW_ERRO"
op_dock="$(normalizar_opacidade VIDRO_OPACIDADE_DOCK "$VIDRO_OPACIDADE_DOCK")" \
  || exit "$MEOW_ERRO"

# Uma frase só, usada nas mensagens e no --conferir, para que "não imposto" seja
# dito com as mesmas palavras em todo lugar em que aparece.
descrever_opacidade() {
  case "$1" in
    "") printf 'da GUI' ;;
    *)  printf '%s' "$1" ;;
  esac
}

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
#
# A TABELA PASSOU A LER `frosted_panel` (23/08/2026). O upstream só multiplica
# por `alpha_map[frosted]` quando `frosted_panel` está ligado:
#
#     if self.theme.cosmic().frosted_panel && self.blur_enabled { alpha *= ... }
#
# Com a caixa "Painéis" desmarcada em Aparência → Vidro fosco, o slider dela
# vira 1:1 e esta tabela inteira estaria mentindo por um fator de dois. Imprimir
# a porcentagem sem olhar essa chave foi o mesmo defeito da tabela fotografada
# que este bloco já pagou três vezes: número certo, premissa não conferida.
faixa_alpha() {
  local am="$BASE/com.system76.CosmicTheme.Dark/v2/alpha_map"
  [ -r "$am" ] || { meow_pula "alpha_map ausente — sem faixa a mostrar"; return 0; }
  local lo hi frosted fator chave o fp
  lo="$(sed -nE 's/.*[^a-z_]extremely_high_2: *([0-9.]+).*/\1/p' "$am" | head -1)"
  hi="$(sed -nE 's/.*[^a-z_]extremely_low: *([0-9.]+).*/\1/p' "$am" | head -1)"
  [ -n "$lo" ] && [ -n "$hi" ] || { meow_pula "não consegui ler as pontas do alpha_map"; return 0; }

  # Ausente = ligado: é o padrão do COSMIC, e supor "desligado" aqui faria a
  # tabela prometer o dobro do que a barra desenha.
  fp="$(cat "$BASE/com.system76.CosmicTheme.Dark/v2/frosted_panel" 2>/dev/null)"
  [ -n "$fp" ] || fp="true"

  if [ "$fp" != "true" ]; then
    meow_info "frosted_panel=false — a caixa \"Painéis\" está DESMARCADA, então o"
    printf '    slider é 1:1: opacity 0,19 desenha 19%%, 1,00 desenha 100%%.\n'
    printf '    (o alpha_map não entra na conta enquanto ela estiver assim)\n'
    return 0
  fi

  meow_info "quanto da COR da barra é desenhada, com o alpha_map de agora:"
  printf '    %-9s %s\n' "opacity" "mais fosco  ->  menos fosco"
  for o in 0.10 0.19 0.24 0.26 0.50 1.00; do
    awk -v o="$o" -v lo="$lo" -v hi="$hi" \
      'BEGIN{printf "    %-9s %5.1f%%       ->  %5.1f%%\n", o, o*lo*100, o*hi*100}'
  done
  printf '    (a faixa vem do alpha_map vivo: %s a %s)\n' "$lo" "$hi"

  # E o ponto exato em que ela está agora — que é o único número que importa
  # para decidir se a barra tem corpo ou não.
  #
  # A LINHA "hoje" LÊ O DISCO, NÃO A NOSSA CHAVE (17/08/2026). Desde que a
  # opacidade passou a ser dela, `$op_painel` costuma estar vazio — e uma linha
  # calculada sobre vazio imprimiria 0,0% e mentiria sobre a tela. O número que
  # interessa é o que está gravado, venha da GUI ou de um valor imposto.
  frosted="$(cat "$BASE/com.system76.CosmicTheme.Dark/v2/frosted" 2>/dev/null)" || return 0
  [ -n "$frosted" ] || return 0
  chave="$(_frosted_para_chave "$frosted")"
  fator="$(sed -nE "s/.*[^a-z_]${chave}: *([0-9.]+).*/\1/p" "$am" | head -1)"
  [ -n "$fator" ] || return 0
  local disco_p disco_d
  disco_p="$(cat "$BASE/com.system76.CosmicPanel.Panel/v1/opacity" 2>/dev/null)"
  disco_d="$(cat "$BASE/com.system76.CosmicPanel.Dock/v1/opacity" 2>/dev/null)"
  [ -n "$disco_p" ] && [ -n "$disco_d" ] || return 0
  awk -v f="$fator" -v p="$disco_p" -v d="$disco_d" -v n="$frosted" \
    'BEGIN{printf "    hoje, com frosted=%s (%.5f) e o que está no disco: painel %.1f%%, dock %.1f%%\n", n, f, p*f*100, d*f*100}'

  # O TETO É A RESPOSTA PARA "MEXI NO SLIDER E NÃO MUDOU NADA" (23/08/2026).
  # A tabela acima diz onde ela está; ela não diz até ONDE dá para ir. Com
  # `frosted=ExtremelyHigh2` o slider inteiro, de 0 a 100, só comanda de 0% a
  # 54% — e a última metade dessa faixa quase não se vê contra uma janela
  # escura. Sem esta linha a pessoa mexe o controle errado e conclui que o
  # controle está quebrado, que foi exatamente a queixa de hoje.
  awk -v f="$fator" -v n="$frosted" -v hi="$hi" \
    'BEGIN{printf "    o TETO com frosted=%s é %.0f%% (mesmo com opacity=1,00). Para subir o teto\n", n, f*100;
           printf "    é \"Espessura do efeito fosco\" em Aparência: no outro extremo o teto vira %.0f%%.\n", hi*100}'
  printf '    E o que ela VÊ depende do que está atrás: a cor da barra (#313244) some\n'
  printf '    contra uma janela escura e salta contra o papel de parede — medido em 23/08.\n'
}

# --- o aviso que devolve a autoridade do slider -----------------------------
# MEDIDO EM 23/08/2026: com `keep_style_on_maximize=false` e uma janela
# maximizada, `opacity` é IGNORADA — 0.19 e 0.95 desenharam pixels idênticos
# (#313244 chapado). O upstream faz
#     let effective_maximized = maximized && !config.keep_style_on_maximize;
#     let opacity = if effective_maximized { config.maximize(); 1.0 } else { config.opacity };
# e `maximize()` faz `self.opacity = 1.0`.
#
# Por isso este aviso não é sobre estética: enquanto a chave estiver em `false`,
# o controle DELA não vale nada na maior parte do tempo de uso. Dizer isso é o
# que nos cabe — a opacidade continua sendo dela, e nós não a escrevemos.
avisar_slider_morto() {
  local barra dir v algum=0
  for barra in "${BARRAS[@]}"; do
    dir="$BASE/com.system76.CosmicPanel.$barra/v1"
    [ -d "$dir" ] || continue
    v="$(cat "$dir/keep_style_on_maximize" 2>/dev/null)"
    [ "$v" = "false" ] || continue
    algum=1
    meow_aviso "$barra: keep_style_on_maximize=false — com janela maximizada a barra fica"
    meow_aviso "  chapada e a \"Opacidade do fundo\" que você escolher é ignorada (medido 23/08)"
  done
  [ "$algum" = "0" ]
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
  meow_info "o que este script quer: painel $(descrever_opacidade "$op_painel"), dock $(descrever_opacidade "$op_dock"), ao maximizar $desejado"
  faixa_alpha
  avisar_slider_morto || true
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
  #
  # E ELA VALE MAIS DO QUE ESTE COMENTÁRIO DIZIA (23/08/2026). Não é só "o vidro
  # continua bonito ao maximizar": enquanto ela estiver em `false`, o upstream
  # força `opacity = 1.0` e a "Opacidade do fundo" que ELA escolher não desenha
  # nada — medido, 0.19 e 0.95 saíram pixel-idênticos. Escrever esta chave é o
  # que mantém o controle dela vivo; ver o bloco de 23/08 no cabeçalho.
  meow_escrever "$dir/keep_style_on_maximize" "$desejado" 644
  case $? in
    1) mudou=1 ;;
    2) meow_erro "não consegui escrever $dir/keep_style_on_maximize"; exit "$MEOW_ERRO" ;;
  esac
  # `opacity` SÓ SE FOR PEDIDA. Vazio é o padrão desde 17/08/2026: esta chave é
  # a que o slider "Opacidade do fundo" da GUI escreve, e escrevê-la em toda
  # passagem desfazia a escolha dela um dia depois, calado (ver o cabeçalho).
  if [ -n "$opacidade" ]; then
    meow_escrever "$dir/opacity" "$opacidade" 644
    case $? in
      1) mudou=1 ;;
      2) meow_erro "não consegui escrever $dir/opacity"; exit "$MEOW_ERRO" ;;
    esac
  fi
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

op_msg="painel $(descrever_opacidade "$op_painel"), dock $(descrever_opacidade "$op_dock")"

if [ "$mudou" = "0" ]; then
  if [ "$desejado" = "true" ]; then
    meow_ok "vidro já conforme: $op_msg, mantido ao maximizar"
  else
    meow_ok "vidro já conforme: $op_msg; sai ao maximizar (padrão do COSMIC)"
    meow_aviso "com isso a \"Opacidade do fundo\" da GUI é ignorada enquanto houver janela"
    meow_aviso "  maximizada — a barra fica chapada na cor do tema (medido em 23/08/2026)"
  fi
  # Sai 4, não 1: não há o que consertar — quem deriva é a GUI. Ver o cabeçalho de
  # `conferir_receita` e o bloco do código 4 em scripts/aplicar_tema.sh.
  conferir_receita || exit 4
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"

if [ "$desejado" = "true" ]; then
  meow_ok "$op_msg, vidro mantido ao maximizar — já valendo"
else
  meow_ok "$op_msg; o vidro sai ao maximizar — já valendo"
  meow_aviso "com isso a \"Opacidade do fundo\" da GUI é ignorada enquanto houver janela"
  meow_aviso "  maximizada — a barra fica chapada na cor do tema (medido em 23/08/2026)"
fi
exit "$MEOW_DIVERGENTE"

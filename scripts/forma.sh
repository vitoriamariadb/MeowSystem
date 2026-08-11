#!/usr/bin/env bash
# forma.sh — a GEOMETRIA das barras. O `vidro.sh` cuida da COR do painel e do
# dock; este cuida da FORMA: se encostam na borda, com que raio de canto, e se
# atravessam a tela inteira ou viram ilha.
#
# O QUE ESTAVA NO DISCO EM 10/08/2026, ANTES DESTE ARQUIVO
#   As duas barras, painel e dock, com `anchor_gap=false`, `margin=0`,
#   `border_radius=0` e `expand_to_edges=true`. Ou seja: dois retângulos de
#   1920px de canto vivo, colados na borda da TV. E o padrão de FÁBRICA do
#   cosmic-panel não é esse — o Default de `CosmicPanelConfig`
#   (pop-os/cosmic-panel, cosmic-panel-config/src/panel_config.rs) traz
#   `border_radius: 8` e `margin: 4`. O zero daqui é mais quadrado que o de
#   fábrica; foi escolha nossa em algum momento, não herança do sistema.
#
#   O dock era o caso mais gritante: 1920px de barra para CINCO botões, porque
#   `plugins_wings` tem a asa direita literalmente vazia (`[]`). Toda a metade
#   direita da barra era superfície pintada sem nada em cima.
#
# SÃO DUAS PERGUNTAS DIFERENTES, E CONFUNDI-LAS FAZ A MARGEM NÃO APARECER
#   `anchor_gap` = a barra SOLTA da borda da tela.
#   `expand_to_edges` = a barra atravessa a tela de ponta a ponta.
#   São independentes, e a `margin` só é desenhada quando `anchor_gap` é `true`:
#   `get_effective_anchor_gap()` é literalmente
#       if self.anchor_gap { self.margin as u32 } else { 0 }
#   Escrever `margin: 8` com `anchor_gap: false` é escrever um número que o
#   compositor descarta calado — a barra continua colada e ninguém diz por quê.
#
#   Por isso os padrões abaixo são assimétricos DE PROPÓSITO: o dock vira ilha
#   (solto E sem expandir), o painel fica solto MAS de largura cheia. Barra de
#   status atravessando a tela é legítima, e como `exclusive_zone=true` ela já
#   reserva a faixa inteira; encolher o painel só provocaria reflow sem ganho.
#
# A ILHA SOBREVIVE AO MAXIMIZAR — E ISSO NÃO É SORTE
#   O cosmic-panel desmancha a ilha quando uma janela maximiza: `maximize()`
#   zera `expand_to_edges`, `margin`, `border_radius` e `anchor_gap`. MAS a
#   primeira linha da função é
#       if self.keep_style_on_maximize { return; }
#   e o `vidro.sh` já grava `keep_style_on_maximize=true` nas DUAS barras. A
#   função retorna antes de tocar na geometria. Ou seja: este script DEPENDE do
#   vidro.sh. Quem puser `VIDRO_AO_MAXIMIZAR="nao"` no meow.conf verá a ilha
#   sumir toda vez que uma janela maximizar — e a checagem no fim daqui avisa.
#
# O RAIO DO PAINEL É MENOR QUE O DO DOCK, E ISSO TEM MEDIDA
#   O painel é `size=S` e o dock é `size=L` (lidos do disco). Com `S` o applet
#   simbólico desenha 20px, e a barra inteira fica na casa dos 30px de altura:
#   raio 16 ali arredondaria a barra até quase virar cápsula. 8 no painel e 16
#   no dock deixa as duas com a mesma LEITURA de canto, não o mesmo número.
#
# VALE NA HORA, SEM REINICIAR NADA
#   O cosmic-panel mantém watch de inotify em `CosmicPanel.Panel/v1` e
#   `CosmicPanel.Dock/v1` — medido em 04/08/2026 pelos fdinfo do processo e
#   registrado no cabeçalho do vidro.sh. Escrever aqui aplica na tela dela sem
#   piscar a sessão e sem gastar uma vida do respawn do cosmic-session.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

# "sim" -> solta da borda (anchor_gap). É o que faz a `margin` valer.
FORMA_PAINEL_SOLTO="${FORMA_PAINEL_SOLTO:-sim}"
FORMA_DOCK_SOLTO="${FORMA_DOCK_SOLTO:-sim}"

# "sim" -> ilha: a barra encolhe até o tamanho do conteúdo (expand_to_edges=false).
#
# O DOCK SAIU DA ILHA EM 11/08/2026, E O MOTIVO NÃO É ESTÉTICO
#   `expand_to_edges=false` não encolhe só a barra: ele FUNDE os três segmentos.
#   No `cosmic-panel-bin/src/space/layout.rs`:
#
#       let is_dock = !self.config.expand_to_edges() || ...;
#       if is_dock {
#           windows_center = windows_left.drain(..)
#               .chain(windows_center).chain(windows_right.drain(..)).collect_vec();
#       }
#
#   As três listas viram uma só, e o bloco inteiro é centralizado. A separação
#   início/centro/fim continua no arquivo de config — a GUI de Configurações
#   escreve certinho —, mas o layout a IGNORA nesse modo.
#
#   Em 11/08 ela arrumou os miniaplicativos na GUI (gato no Segmento inicial,
#   aplicativos no central, nada no final), mandou a captura, e o gato continuava
#   colado nos aplicativos no meio do dock. Não havia o que consertar na GUI: a
#   ilha é que anulava a arrumação.
#
#   O default do próprio cosmic-panel confirma a leitura: o Dock de fábrica nasce
#   com `expand_to_edges: false` e TUDO dentro de `plugins_center` — o upstream
#   nunca projetou o dock em ilha para ter um botão isolado num canto.
#
#   Trocar aqui é o mesmo que trocar no `meow.conf`, e volta com uma palavra.
FORMA_PAINEL_ILHA="${FORMA_PAINEL_ILHA:-nao}"
FORMA_DOCK_ILHA="${FORMA_DOCK_ILHA:-nao}"

FORMA_MARGEM_PAINEL="${FORMA_MARGEM_PAINEL:-6}"
FORMA_MARGEM_DOCK="${FORMA_MARGEM_DOCK:-8}"
FORMA_RAIO_PAINEL="${FORMA_RAIO_PAINEL:-8}"
FORMA_RAIO_DOCK="${FORMA_RAIO_DOCK:-16}"

# Espaço ENTRE os applets. O painel estava em 0 — que é o Default de fábrica, e
# não uma assimetria herdada, ao contrário do que parecia. Mas são 13 applets de
# 20px colados um no outro, numa TV de 1150x650mm vista de longe (medida do
# `cosmic-randr list`): 4px de respiro é conforto de mira, não simetria.
FORMA_ESPACO_PAINEL="${FORMA_ESPACO_PAINEL:-4}"
FORMA_ESPACO_DOCK="${FORMA_ESPACO_DOCK:-8}"

# Espaço entre o conteúdo e a moldura da barra. O painel fica no 5 que ele já
# tinha: mexer nele muda a ALTURA da faixa reservada, e isso empurra todas as
# janelas. O dock sobe de 4 para 6 porque a ilha arredondada precisa de um pouco
# mais de folga para o raio não comer o ícone do canto.
FORMA_RECHEIO_PAINEL="${FORMA_RECHEIO_PAINEL:-5}"
FORMA_RECHEIO_DOCK="${FORMA_RECHEIO_DOCK:-6}"

BASE="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}"

# O RON destas chaves é booleano ou inteiro, sem aspas. Normalizar aqui evita um
# valor que o COSMIC descarta calado — o mesmo cuidado que o vidro.sh toma com o
# float da opacidade.
_bool() { case "$1" in sim|true|1) printf 'true' ;; nao|não|false|0) printf 'false' ;;
                       *) return 1 ;; esac; }
_int()  { case "$2" in ''|*[!0-9]*) meow_erro "$1='$2' — esperado um inteiro"; return 1 ;;
                       *) printf '%s' "$2" ;; esac; }

mudou=0
escritos=0

aplicar_barra() { # $1=Panel|Dock  $2=solto  $3=ilha  $4=margem  $5=raio  $6=espaco  $7=recheio
  local barra="$1" dir solto ilha expandir margem raio espaco recheio rc
  dir="$BASE/com.system76.CosmicPanel.$barra/v1"
  # Criar o diretório do nada faria o COSMIC ver uma configuração de painel órfã,
  # sem as outras chaves. Se ele não existe, esta barra não está configurada
  # nesta máquina — não é erro. (Mesma regra do vidro.sh.)
  [ -d "$dir" ] || { meow_pula "com.system76.CosmicPanel.$barra não está configurado aqui"; return 0; }

  solto="$(_bool "$2")"   || { meow_erro "$barra: 'solto' esperava sim|nao, veio '$2'"; return 2; }
  ilha="$(_bool "$3")"    || { meow_erro "$barra: 'ilha' esperava sim|nao, veio '$3'"; return 2; }
  margem="$(_int  "margem do $barra"  "$4")" || return 2
  raio="$(_int    "raio do $barra"    "$5")" || return 2
  espaco="$(_int  "espaço do $barra"  "$6")" || return 2
  recheio="$(_int "recheio do $barra" "$7")" || return 2

  # ilha e expand_to_edges são a mesma pergunta com o sinal trocado.
  case "$ilha" in true) expandir=false ;; *) expandir=true ;; esac

  escritos=$((escritos + 1))
  local par k v
  for par in "anchor_gap:$solto" "margin:$margem" "border_radius:$raio" \
             "spacing:$espaco" "padding:$recheio" "expand_to_edges:$expandir"; do
    k="${par%%:*}"; v="${par#*:}"
    meow_escrever "$dir/$k" "$v" 644; rc=$?
    case "$rc" in
      1) mudou=1 ;;
      2) meow_erro "não consegui escrever $dir/$k"; return 2 ;;
    esac
  done
  return 0
}

aplicar_barra Panel "$FORMA_PAINEL_SOLTO" "$FORMA_PAINEL_ILHA" \
  "$FORMA_MARGEM_PAINEL" "$FORMA_RAIO_PAINEL" "$FORMA_ESPACO_PAINEL" "$FORMA_RECHEIO_PAINEL" \
  || exit "$MEOW_ERRO"
aplicar_barra Dock "$FORMA_DOCK_SOLTO" "$FORMA_DOCK_ILHA" \
  "$FORMA_MARGEM_DOCK" "$FORMA_RAIO_DOCK" "$FORMA_ESPACO_DOCK" "$FORMA_RECHEIO_DOCK" \
  || exit "$MEOW_ERRO"

if [ "$escritos" -eq 0 ]; then
  meow_pula "não há painel nem dock configurados — nada a ajustar"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

# A forma DEPENDE do vidro: sem keep_style_on_maximize a ilha se desfaz sozinha
# na primeira janela maximizada, e o sintoma ("as barras voltaram ao quadrado")
# não aponta para cá. Avisar é barato; escrever a chave aqui seria duplicar a
# dona dela, que é o vidro.sh.
for barra in Panel Dock; do
  arq="$BASE/com.system76.CosmicPanel.$barra/v1/keep_style_on_maximize"
  [ -f "$arq" ] || continue
  [ "$(cat "$arq")" = "true" ] && continue
  meow_aviso "keep_style_on_maximize=false no $barra: a forma se desfaz ao maximizar"
  meow_info "conserto: VIDRO_AO_MAXIMIZAR=\"sim\" no meow.conf e rode scripts/vidro.sh"
done

if [ "$mudou" = "0" ]; then
  meow_ok "forma já conforme: painel raio $FORMA_RAIO_PAINEL margem $FORMA_MARGEM_PAINEL, dock raio $FORMA_RAIO_DOCK margem $FORMA_MARGEM_DOCK"
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"
meow_ok "painel solto com raio $FORMA_RAIO_PAINEL, dock em ilha com raio $FORMA_RAIO_DOCK — já valendo"
exit "$MEOW_DIVERGENTE"

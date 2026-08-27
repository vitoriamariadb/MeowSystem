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
# RAIO GRANDE DEMAIS NÃO É FEIO — É O PAINEL FANTASMA (25/08/2026)
#   Ela pôs 160 nas duas barras pela GUI de Configurações, e a GUI ACEITOU. O
#   compositor não: `src/wayland/protocols/corner_radius.rs:622-628` do
#   cosmic-comp faz
#
#       let half_min_dim = (geo.size.w.min(geo.size.h) / 2) as u32;
#       corners.top_left > half_min_dim || ... -> post_error(RadiusTooLarge)
#
#   e `post_error` é erro de protocolo Wayland, que é FATAL POR DEFINIÇÃO:
#   derruba a conexão inteira do cliente. Topbar e dock são o mesmo processo,
#   então SOMEM JUNTAS. Quatro ocorrências no journal só no dia 25/08:
#
#       cosmic_corner_radius_layer_v1#109: error 1: ... corner radius too large
#
#   É o "painel fantasma" — e a explicação anterior (um `xdg_popup ... tried to
#   grab after being mapped`) descrevia OUTRO dia, não este mecanismo.
#
#   NÃO EXISTE TETO CALCULÁVEL, E EU ERREI DUAS VEZES ANTES DE ENTENDER ISSO
#   Primeiro achei que bastava não exagerar. Depois derivei um teto de `size`
#   (S->20, M->28) pelo `get_applet_icon_size_with_padding`, escrevi aqui que
#   "o teto já é a pastilha completa", e apliquei. Falhou de novo às 13:58:39 do
#   mesmo dia, e a topbar e a dock dela sumiram junto. As duas versões estavam
#   erradas pela mesma razão, que só apareceu quando se leu o hook:
#
#     - quem valida é o `layer_radius_hook`, um PRE-COMMIT hook do compositor
#       (cosmic-comp `src/wayland/protocols/corner_radius.rs:216` e `:657`);
#     - `:658` mede `bbox_from_surface_tree`, a caixa do buffer JÁ COMITADO —
#       o frame ANTERIOR —, ainda descontada do padding (`pad_rect :644-655`);
#     - `:685` compara com `half_min_dim`, e `:696-698` derruba o cliente.
#
#   Ou seja: o compositor compara o raio NOVO contra o tamanho VELHO. O `size`
#   da config não entra nessa conta em lugar nenhum, e o cosmic-panel ainda corta
#   o valor duas vezes antes de enviar (`layout.rs:817`, `panel_space.rs:2101`).
#   O que mata é o descasamento de UM FRAME — boot, applet entrando ou saindo,
#   mudança de escala. É CORRIDA, não limiar. Por isso nenhuma fórmula sobre a
#   configuração pode prometer segurança, e prometer seria repetir o erro.
#
#   E NEM 8/16 É IMUNE: há 14 ocorrências de "corner radius too large" no journal
#   entre 11/08 e 24/08, quase todas no primeiro minuto da sessão, com 8 e 16
#   gravados. A diferença é que ali o contador de reinícios do cosmic-session
#   estava baixo e ele devolvia o painel em milissegundos; com o contador alto,
#   a mesma morte custa dezenas de minutos sem barra nenhuma.
#
#   A PASTILHA NÃO É ALCANÇÁVEL nesta versão do COSMIC. O desenho satura em
#   cápsula quando o raio chega à espessura da barra — e é exatamente esse valor
#   que perde a corrida todas as vezes. O único caminho é patch no cosmic-comp
#   trocando o `post_error` por um clamp em `corner_radius.rs:685-698`, pelo
#   mesmo mecanismo do patch de workspace que ela já mantém. Não está feito.
#
#   POR ISSO OS NÚMEROS ABAIXO SÃO REGISTRO, NÃO CONTA. 8 e 16 são o que está
#   gravado desde 11/08 e o único par com dias de uso atrás. A válvula
#   `FORMA_RAIO_EXPERIMENTAL=sim` existe para ela poder tentar mais, sabendo o
#   preço — trava que não pode ser destravada vira gambiarra no arquivo errado.
# O TETO SAIU DE CRAVADO PARA DERIVADO — 26/08/2026
#   Estava `Panel 8, Dock 16`, e esses números vieram de uma altura ERRADA: o
#   comentário logo acima afirmava "o dock é size=L" (o disco diz M) e "a barra
#   fica na casa dos 30px" (são 44 lógicos, medidos). Havia três tetos
#   contraditórios no projeto para a mesma pergunta — 8/16 aqui, 20/28 nos
#   comentários do meow.conf, e 22/32 na medição. Três números é o mesmo que
#   nenhum.
#   A conta agora é uma só, mora em lib/painel.sh com a citação da fonte dentro,
#   e responde 22 (Panel) e 32 (Dock) nesta máquina.
_forma_teto_raio() { # $1 = Panel|Dock
  local t
  t="$(meow_painel_teto "$BASE/com.system76.CosmicPanel.$1/v1" 2>/dev/null)" && { printf '%s' "$t"; return 0; }
  # Sem conseguir derivar (size/padding ilegíveis), o mais apertado dos antigos.
  # Não é chute: é o valor com dias de uso atrás, e é conservador.
  printf '8'
}

# O COMPOSITOR CLAMPA SOZINHO? — a pergunta que decide se a trava acima vale
#
#   Em 26/08/2026 o cosmic-comp passou a ser buildado com um patch nosso que
#   troca o `post_error(RadiusTooLarge)` por um CLAMP ao `half_min_dim` do frame
#   (patches/cosmic-comp-raio-clampado.patch). Com esse patch de pé não existe
#   mais raio que derrube a barra: o compositor reduz o canto e desenha.
#
#   Então a trava daqui deixa de ter razão de ser — e manter uma trava sem razão
#   é atropelar a escolha dela por hábito. Enquanto o marcador estiver no
#   binário, o raio é DELA, sem teto. Sem o marcador (um `apt upgrade` do
#   cosmic-comp devolve o binário do pacote e o patch se perde em silêncio), a
#   trava volta a valer — é a rede de segurança.
#
#   `grep -a` porque o binário é "arquivo binário" para o grep, que senão só diz
#   "Binary file matches". Mesma razão do `esta_patchado` do
#   aurora-cosmic-comp-ws.sh, de onde esta linha foi copiada.
#   E NÃO BASTA O BINÁRIO TER A MARCA — MEDIDO NA MARRA EM 26/08/2026
#     O patch foi instalado às 22:13 e o `cosmic-comp` em execução era o das
#     01:55, do binário antigo. Trocar o arquivo NÃO troca o processo: o
#     compositor é o servidor Wayland, e substituí-lo a quente fecharia todas as
#     janelas. Ou seja, entre a instalação e o próximo login o binário diz
#     "clampa" e a sessão viva NÃO clampa — e a barra fica sem rede exatamente
#     na janela em que ela ainda pode morrer.
#     Por isso a pergunta certa é sobre o PROCESSO, não sobre o arquivo: o
#     compositor de pé nasceu DEPOIS de o binário patchado chegar ao disco?
FORMA_COMP_BIN="${FORMA_COMP_BIN:-/usr/bin/cosmic-comp}"
MEOW_PAINEL_COMP_BIN="$FORMA_COMP_BIN"
_forma_compositor_clampa() {
  meow_painel_compositor_clampa && return 0
  meow_painel_patch_pendente && return 2
  return 1
}


# O QUE ESTÁ NO DISCO CABE? — usado quando NÃO vamos escrever o raio
#
#   "Vazio = não toca" resolve o atropelo, mas abre um buraco: se o valor que a
#   GUI gravou for grande demais E o compositor não clampar, a barra morre e o
#   MeowSystem fica olhando. Foi exatamente o que aconteceu em 26/08/2026 —
#   `border_radius` 41 no Panel e 67 no Dock, gravados pelo COSMIC Tweaks, e a
#   tarde inteira sem topbar nem dock.
#
#   Então, quando não escrevemos: conferimos. Se couber, não encostamos no
#   arquivo (o cosmic-panel tem inotify neste diretório — escrever à toa joga um
#   reload na tela dela). Se não couber, cortamos e dizemos por quê.
_forma_conferir_raio_do_disco() { # $1 = Panel|Dock  $2 = dir
  local barra="$1" dir="$2" atual teto chave rc
  atual="$(cat "$dir/border_radius" 2>/dev/null || true)"
  case "$atual" in ''|*[!0-9]*) return 0 ;; esac   # ausente ou ilegível: não é nosso problema

  # `meow_debug` e não `meow_pula`: com tudo certo esta função não tem NADA a
  # dizer. Uma linha por barra em toda passagem faria o `meow doctor` marcar
  # `forma` como divergente para sempre — o mesmo defeito que o commit de hoje
  # ("o doctor dizia conforme mesmo assim") corrigiu do outro lado. O resumo
  # final já diz de quem é o raio.
  _forma_compositor_clampa; local comp=$?
  if [ "$comp" = "0" ]; then
    meow_debug "$barra: raio $atual é seu — o cosmic-comp clampa o que não couber"
    return 0
  fi

  teto="$(_forma_teto_raio "$barra")"

  # ESTADO INTERMEDIÁRIO: o patch está no disco e a sessão viva ainda é a velha.
  #   Cortar aqui seria trocar a estética dela para prevenir um risco que esta
  #   sessão já não correu — a barra está de pé com este valor. E o corte
  #   sobreviveria ao login, deixando o canto errado justamente quando o patch
  #   finalmente vale. Então: avisa uma vez e não encosta.
  if [ "$comp" = "2" ] && [ "$atual" -gt "$teto" ]; then
    meow_aviso "$barra: raio $atual — o patch do cosmic-comp já está instalado, mas vale no PRÓXIMO LOGIN"
    meow_info  "  até lá esta sessão roda o compositor antigo; se a barra sumir, é isto"
    return 0
  fi
  if [ "$atual" -le "$teto" ]; then
    meow_debug "$barra: raio $atual é seu (cabe no teto de $teto)"
    return 0
  fi

  chave="FORMA_RAIO_PAINEL"; [ "$barra" = "Dock" ] && chave="FORMA_RAIO_DOCK"
  meow_aviso "$barra: raio $atual no disco, acima de $teto, e o cosmic-comp NÃO está patchado"
  meow_info  "  com este valor topbar e dock somem JUNTAS e não voltam — medido em 26/08/2026"
  meow_info  "  o patch some num 'apt upgrade' do cosmic-comp; refazer: aurora-cosmic-comp-ws.sh --build (~4 min)"
  meow_info  "  para impor um valor daqui em vez disso: $chave no meow.conf"
  meow_escrever "$dir/border_radius" "$teto" 644; rc=$?
  case "$rc" in
    1) mudou=1 ;;
    2) meow_erro "não consegui escrever $dir/border_radius"; return 2 ;;
  esac
  return 0
}

# O RAIO DO PAINEL É MENOR QUE O DO DOCK, E ISSO TEM MEDIDA
#   O painel é `size=S` e o dock é `size=M` (lidos do disco em 26/08/2026 — este
#   comentário dizia `L`, e foi essa altura errada que sustentou o teto 8/16).
#   Com `S` o applet
#   simbólico desenha 20px. A barra NÃO fica "na casa dos 30px": são 44 unidades
#   lógicas (2*padding + 40), medidas em 26/08 e conferidas contra a layer
#   surface que o compositor desenha. Ver lib/painel.sh.
#   raio 16 ali arredondaria a barra até quase virar cápsula. 8 no painel e 16
#   no dock deixa as duas com a mesma LEITURA de canto, não o mesmo número.
#
# O TAMANHO POR SEGMENTO NÃO EXISTE NA GUI — E O RON DELE NÃO É ÓBVIO (25/08/2026)
#   A Vitória reclamou que os ícones da bandeja ficavam do mesmo tamanho dos
#   aplicativos do meio do dock. A GUI de Configurações só oferece UM tamanho
#   para a barra inteira; quem separa é `size_center` e `size_wings`, que a
#   interface não expõe. Descobertos empiricamente, porque as duas chaves NÃO
#   têm a mesma forma:
#       size_center: Some(S)              <- Option<PanelSize>, direto
#       size_wings:  Some((None, Some(S)))<- Option<(Option,Option)>, é TUPLA
#   `Some(S)` em `size_wings` faz o cosmic-panel cuspir
#   `ExpectedStructLike` no journal e IGNORAR a entrada inteira do dock — em
#   silêncio na tela, que é como esse erro sempre chega. A tupla é
#   (segmento inicial, segmento final), na mesma ordem do `plugins_wings`, e
#   `None` de um lado significa "herda o tamanho da barra" — foi assim que o
#   gato ficou grande à esquerda enquanto a bandeja encolhia à direita.
#
# A ILHA **NÃO** ANULA O TAMANHO POR SEGMENTO — CONFERIDO NA FONTE (25/08/2026)
#   A suspeita era natural, porque a ilha anula a ARRUMAÇÃO (é o parágrafo do
#   `FORMA_DOCK_ILHA`, mais abaixo): se `expand_to_edges=false` funde os três
#   segmentos, o tamanho de ala também morreria junto. Não morre, e são dois
#   códigos diferentes, em dois arquivos diferentes do cosmic-panel:
#     - o TAMANHO sai de `get_effective_applet_size(side)`
#       (cosmic-panel-config/src/panel_config.rs:491-516) e o `side` de cada
#       applet vem de qual lista do `plugins_*` ele está
#       (cosmic-panel-bin/src/space/wrapper_space.rs:422-430). O valor vira a
#       variável de ambiente `COSMIC_PANEL_SIZE` do processo do applet
#       (wrapper_space.rs:556-558). Nada disso olha `expand_to_edges`;
#     - a FUSÃO é só das listas de JANELA, na hora de posicionar
#       (cosmic-panel-bin/src/space/layout.rs:197-206).
#   Ou seja, na ilha os applets ficam juntos no meio e continuam com o tamanho
#   do segmento em que foram declarados. É por isso que não há aviso aqui: não
#   há nada de silencioso a avisar.
#
#   O PREÇO É OUTRO: mexer em `size_center`/`size_wings` entra na lista de
#   `must_recreate` do daemon (cosmic-panel-bin/src/space_container/
#   space_container.rs:316-325, junto com `size`, `spacing` e `plugins_*`), o
#   que RESPAWNA os applets da barra. Continua valendo na hora e sem tocar na
#   sessão — mas a barra pisca, ao contrário do raio e da margem.
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
# shellcheck source=../lib/painel.sh
. "$RAIZ/lib/painel.sh"

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

# ===========================================================================
# 26/08/2026: A GEOMETRIA DAS BARRAS DEIXOU DE SER NOSSA. VAZIO = NÃO TOCA.
# ===========================================================================
#   Os oito valores abaixo eram DEFAULTS PREENCHIDOS, e este script os gravava
#   toda passagem. Com o `meow-doctor.timer` rodando `fix_forma` às 05:00, o
#   número que ela escolhesse no COSMIC Tweaks à noite voltava a ser o nosso de
#   manhã — sem nada na tela dizer por quê. É a mesma fronteira que o `vidro.sh`
#   atravessou três vezes com a opacidade antes de mudar o dono (bloco de
#   17/08/2026 lá), e o critério é o mesmo: onde a GUI tem um controle, o valor
#   é dela.
#
#   Os números que estavam aqui viraram comentário — não são lixo, são a
#   receita que ela pode querer de volta. Para reimpor qualquer um, basta
#   preencher a chave no meow.conf; a escrita volta a acontecer exatamente como
#   antes. Vazio, que é o padrão, o script não encosta na chave.
#
#   `anchor_gap` e `expand_to_edges` (o "solto" e a "ilha") ficaram de fora
#   desta virada de propósito: o Tweaks não os expõe, e o que a GUI não oferece
#   continua sendo nosso — senão se perde em silêncio.

FORMA_MARGEM_PAINEL="${FORMA_MARGEM_PAINEL:-}"   # era 6
FORMA_MARGEM_DOCK="${FORMA_MARGEM_DOCK:-}"       # era 8
FORMA_RAIO_PAINEL="${FORMA_RAIO_PAINEL:-}"       # era 8
FORMA_RAIO_DOCK="${FORMA_RAIO_DOCK:-}"           # era 16

# Espaço ENTRE os applets. O painel estava em 0 — que é o Default de fábrica, e
# não uma assimetria herdada, ao contrário do que parecia. Mas são 13 applets de
# 20px colados um no outro, numa TV de 1150x650mm vista de longe (medida do
# `cosmic-randr list`): 4px de respiro é conforto de mira, não simetria.
FORMA_ESPACO_PAINEL="${FORMA_ESPACO_PAINEL:-}"   # era 4
FORMA_ESPACO_DOCK="${FORMA_ESPACO_DOCK:-}"       # era 8

# Espaço entre o conteúdo e a moldura da barra. O painel fica no 5 que ele já
# tinha: mexer nele muda a ALTURA da faixa reservada, e isso empurra todas as
# janelas. O dock sobe de 4 para 6 porque a ilha arredondada precisa de um pouco
# mais de folga para o raio não comer o ícone do canto.
FORMA_RECHEIO_PAINEL="${FORMA_RECHEIO_PAINEL:-}" # era 5
FORMA_RECHEIO_DOCK="${FORMA_RECHEIO_DOCK:-}"     # era 6

# Tamanho POR SEGMENTO. Vazio = não toca, a mesma convenção das
# VIDRO_OPACIDADE_*: quem não escolheu herda o tamanho da barra, e o script não
# grava chave nenhuma. Valores: XS | S | M | L | XL.
#
# E A CONVENÇÃO TEM UMA EXCEÇÃO NAS ALAS, PORQUE AS DUAS DIVIDEM UMA CHAVE SÓ
#   "Vazio = não toca" vale por CHAVE do COSMIC, não por chave do meow.conf: o
#   `size_wings` é uma tupla, então as duas alas são escritas juntas ou não são
#   escritas. Com as DUAS vazias o script não encosta no arquivo; com UMA
#   preenchida ele grava a tupla inteira, e a outra vai como `None` — que não é
#   "não toca", é "herda o tamanho da barra".
#   MEDIDO em 25/08/2026, numa cópia do ~/.config/cosmic: partindo de
#   `Some((None, Some(S)))`, rodar com só `FORMA_ALA_INICIAL_DOCK="XS"` deixa
#   `Some((Some(XS), None))` — o `S` da bandeja evapora. Não dá para fazer
#   melhor sem ler e parsear o valor que já está no disco, e a única maneira de
#   pedir "mexe numa e deixa a outra" é escrever as DUAS no meow.conf.
#
# E NÃO HÁ CAMINHO DE VOLTA POR ESTAS CHAVES — DITO, PORQUE NÃO SERÁ ADIVINHADO
#   "Vazio = não toca" vale antes da PRIMEIRA escrita. Uma vez que
#   `size_center`/`size_wings` existem no disco, esvaziar a chave no meow.conf
#   não os apaga: este script só deixa de encostar neles, e o valor fica valendo
#   para sempre. As `VIDRO_OPACIDADE_*` têm o mesmo buraco e ele é aceitável lá
#   porque a tela de Configurações mostra o controle e desfaz na mão; aqui a GUI
#   NÃO expõe tamanho por segmento (é a razão de estas chaves existirem), então o
#   buraco não tem tampa nenhuma pela interface.
#   Implementar a volta pediria um valor-sentinela novo no meow.conf ("herda") e
#   um vocabulário a mais para uma chave que ela usa uma vez por ano; o conserto
#   manual é uma linha e está escrito no meow.conf dela (o `meow.conf.exemplo`
#   ainda NÃO tem nenhuma das seis chaves novas — isso é de quem cuida dele):
#     rm ~/.config/cosmic/com.system76.CosmicPanel.{Dock,Panel}/v1/size_wings
#     rm ~/.config/cosmic/com.system76.CosmicPanel.{Dock,Panel}/v1/size_center
#   O daemon repõe o padrão (`None` = herda o tamanho da barra) na hora, pelo
#   mesmo `must_recreate` citado no cabeçalho.
FORMA_CENTRO_PAINEL="${FORMA_CENTRO_PAINEL:-}"
FORMA_CENTRO_DOCK="${FORMA_CENTRO_DOCK:-}"
FORMA_ALA_INICIAL_PAINEL="${FORMA_ALA_INICIAL_PAINEL:-}"
FORMA_ALA_FINAL_PAINEL="${FORMA_ALA_FINAL_PAINEL:-}"
FORMA_ALA_INICIAL_DOCK="${FORMA_ALA_INICIAL_DOCK:-}"
FORMA_ALA_FINAL_DOCK="${FORMA_ALA_FINAL_DOCK:-}"

BASE="${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}"

# RODAR ESTE ARQUIVO NA MÃO DESFAZ O MEOW.CONF, E ISSO TEM MEDIDA (25/08/2026)
#   Os padrões acima são os do PROJETO, para uma máquina nova. O meow.conf dela
#   já não é isso: conferido chave a chave hoje, TRÊS divergem —
#   `FORMA_PAINEL_ILHA` (conf `sim`, padrão `nao`), `FORMA_RAIO_PAINEL` (conf
#   `160`, padrão `8`) e `FORMA_ALA_FINAL_DOCK` (conf `S`, padrão vazio). As
#   duas primeiras este script SEMPRE escreve, então um `./scripts/forma.sh`
#   solto devolve o painel para largura cheia e canto de 8px na tela dela, na
#   hora, sem ninguém ter pedido. (A terceira é a única que sobrevive: vazio não
#   toca na chave, então ela fica como estava.)
#
#   Quem carrega o conf é o `bin/meow` (`set -a` no `carregar_conf`) e o
#   `install.sh` (`etapa_forma`). Chamado por qualquer outro caminho, este
#   script não tem como saber o que ela escolheu — mas tem como PERCEBER que
#   ninguém lhe contou, e dizer isso antes de escrever. Não recusa: recusar
#   mudaria o contrato de um script-folha, e numa máquina sem meow.conf os
#   padrões são a resposta certa.
#
#   `compgen -e` lista os nomes EXPORTADOS, sem cano — o `env | grep -q` que
#   estava escrito aqui primeiro devolve 141 por SIGPIPE justamente quando
#   ENCONTRA a chave, com o `pipefail` desta linha 69 ligado, e o aviso sairia
#   ao contrário. É a mesma armadilha do `logos_disponiveis | grep -qx` do
#   bin/meow.
#   E O AVISO SÓ SAI QUANDO HÁ O QUE PERDER — senão ele sequestra a tabela
#   O `chk_forma` do bin/meow captura `2>&1` e a tabela do doctor mostra a
#   PRIMEIRA linha da saída. Um aviso incondicional aqui apareceria no lugar do
#   estado toda vez que o meow.conf simplesmente não tivesse chaves FORMA_* —
#   que é o caso legítimo de quem nunca mexeu na geometria, e onde não há nada a
#   desfazer. Medido: com um conf sem FORMA_*, a linha da tabela virava o aviso.
#   Então a condição é dupla: ninguém me passou geometria E existe geometria
#   escrita no meow.conf. Aí sim há uma escolha dela prestes a ser apagada.
#   O `grep` é num ARQUIVO, não num cano: sem SIGPIPE, ao contrário do
#   `env | grep -q`.
_forma_veio_do_ambiente=0
for _n in $(compgen -e); do
  case "$_n" in FORMA_*) _forma_veio_do_ambiente=1; break ;; esac
done
if [ "$_forma_veio_do_ambiente" = "0" ] &&
   grep -qE '^[[:space:]]*(export[[:space:]]+)?FORMA_' "$MEOW_CONF_ARQUIVO" 2>/dev/null; then
  meow_aviso "o $MEOW_CONF_ARQUIVO tem geometria e nada dela chegou aqui — vou gravar os padrões DESTE arquivo por cima"
  meow_info "quem lê o conf é 'meow doctor --consertar' (ou o ./install.sh); rodar este script na mão desfaz a escolha dela"
fi

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
  # AS QUATRO CHAVES COM SLIDER NA GUI: VAZIO = NÃO TOCA (17/08 -> 26/08/2026)
  #
  #   `margin`, `border_radius`, `spacing` e `padding` têm slider no COSMIC
  #   Tweaks (o flatpak `dev.edfloreshz.CosmicTweaks`, que declara
  #   `filesystems=xdg-config/cosmic` e escreve direto em ~/.config/cosmic).
  #   Não é o cosmic-settings: a página Painel dele não tem controle de raio
  #   nenhum. Foi o Tweaks que gravou o `border_radius` 41/67 de 26/08/2026.
  #
  #   Até aqui este script gravava as seis chaves TODA passagem, com defaults
  #   preenchidos — e o `meow doctor --consertar` roda sozinho às 05:00 pelo
  #   timer. Ou seja: ela mexia no slider de noite e de manhã o número era
  #   nosso de novo, sem nada dizer por quê. É a MESMA fronteira que o
  #   `vidro.sh` atravessou três vezes com a opacidade antes de mudar o dono
  #   (ver o bloco de 17/08/2026 lá).
  #
  #   Agora vale a convenção que este arquivo já usava para `size_center` e
  #   `size_wings`: vazio é o padrão e significa NÃO TOCA. Quem quiser impor
  #   preenche `FORMA_MARGEM_*`, `FORMA_RAIO_*`, `FORMA_ESPACO_*` ou
  #   `FORMA_RECHEIO_*` no meow.conf, e aí o valor é gravado como sempre foi.
  #
  #   O QUE **NÃO** MUDOU DE DONO: `anchor_gap` e `expand_to_edges` (o "solto" e
  #   a "ilha"). O Tweaks não os expõe, e são a decisão estrutural que este
  #   script existe para tomar — a mesma regra do `keep_style_on_maximize` no
  #   vidro.sh: o que a GUI não oferece continua sendo nosso.
  margem="$4"; raio="$5"; espaco="$6"; recheio="$7"
  [ -z "$margem" ]  || { margem="$(_int  "margem do $barra"  "$margem")"  || return 2; }
  [ -z "$espaco" ]  || { espaco="$(_int  "espaço do $barra"  "$espaco")"  || return 2; }
  [ -z "$recheio" ] || { recheio="$(_int "recheio do $barra" "$recheio")" || return 2; }

  if [ -z "$raio" ]; then
    # Não vamos escrever o raio — mas conferimos o que está no disco, porque um
    # valor grande demais com o compositor sem patch apaga a barra inteira.
    _forma_conferir_raio_do_disco "$barra" "$dir" || return 2
  else
    raio="$(_int "raio do $barra" "$raio")" || return 2
    # A trava do raio (ver o cabeçalho). Avisa e CORTA, em vez de recusar: recusar
    # deixaria a barra com o valor velho, que pode ser justamente o 160 que derruba
    # o painel — o conserto tem de valer mesmo com o meow.conf errado.
    #
    # COM O cosmic-comp PATCHADO A TRAVA NÃO SE APLICA: o compositor clampa o
    # canto sozinho, então não há valor que derrube a barra e cortar aqui seria
    # só teimosia. Ver `_forma_compositor_clampa`.
    local teto; teto="$(_forma_teto_raio "$barra")"
    if [ "$raio" -gt "$teto" ] && _forma_compositor_clampa; then
      meow_info "$barra: raio $raio acima de $teto, mas o cosmic-comp clampa — seguindo"
    elif [ "$raio" -gt "$teto" ]; then
      local chave; chave="FORMA_RAIO_PAINEL"; [ "$barra" = "Dock" ] && chave="FORMA_RAIO_DOCK"
      case "${FORMA_RAIO_EXPERIMENTAL:-nao}" in
        sim|true|1)
          meow_aviso "$barra: raio $raio acima do valor com evidência ($teto) — modo experimental, seguindo"
          meow_info  "  se topbar e dock sumirem JUNTAS, é isto: $chave=\"$teto\" e 'meow forma' devolve"
          ;;
        *)
          meow_aviso "$barra: raio $raio acima de $teto, o único valor com dias de uso atrás"
          meow_info  "  não há teto calculável: o cosmic-comp compara o raio NOVO com a caixa do frame ANTERIOR"
          meow_info  "  (corner_radius.rs:657-698) e mata o cliente — topbar e dock somem JUNTAS"
          meow_info  "  o conserto de raiz é o patch: aurora-cosmic-comp-ws.sh --build (~4 min)"
          meow_info  "  para tentar acima disso sem o patch: FORMA_RAIO_EXPERIMENTAL=sim"
          raio="$teto"
          ;;
      esac
    fi
  fi

  # ilha e expand_to_edges são a mesma pergunta com o sinal trocado.
  case "$ilha" in true) expandir=false ;; *) expandir=true ;; esac

  escritos=$((escritos + 1))
  local par k v
  for par in "anchor_gap:$solto" "margin:$margem" "border_radius:$raio" \
             "spacing:$espaco" "padding:$recheio" "expand_to_edges:$expandir"; do
    k="${par%%:*}"; v="${par#*:}"
    # Vazio = não toca. E "não toca" é literal: nem um `meow_escrever` com o
    # mesmo conteúdo, porque o cosmic-panel mantém inotify em
    # CosmicPanel.Panel/v1 e .Dock/v1 (medido nos fdinfo, ver vidro.sh) — cada
    # escrita é um reload da barra na tela dela.
    [ -n "$v" ] || continue
    meow_escrever "$dir/$k" "$v" 644; rc=$?
    case "$rc" in
      1) mudou=1 ;;
      2) meow_erro "não consegui escrever $dir/$k"; return 2 ;;
    esac
  done
  return 0
}

# PanelSize é enum; qualquer outra palavra o COSMIC descarta calado.
_tam() { case "$2" in XS|S|M|L|XL) printf '%s' "$2" ;;
                      *) meow_erro "$1='$2' — esperado XS, S, M, L ou XL (ou vazio)"; return 1 ;;
         esac; }

aplicar_tamanhos() { # $1=Panel|Dock  $2=centro  $3=ala inicial  $4=ala final
  local barra="$1" centro="$2" ini="$3" fim="$4" dir rc v_ini v_fim
  dir="$BASE/com.system76.CosmicPanel.$barra/v1"
  [ -d "$dir" ] || return 0

  if [ -n "$centro" ]; then
    centro="$(_tam "centro do $barra" "$centro")" || return 2
    meow_escrever "$dir/size_center" "Some($centro)" 644; rc=$?
    case "$rc" in 1) mudou=1 ;; 2) meow_erro "não consegui escrever $dir/size_center"; return 2 ;; esac
  fi

  # As duas alas vivem na MESMA chave, então só faz sentido escrever se pelo
  # menos uma foi escolhida — senão apagaríamos a outra ao gravar None,None.
  [ -z "$ini$fim" ] && return 0
  v_ini=None; v_fim=None
  if [ -n "$ini" ]; then ini="$(_tam "ala inicial do $barra" "$ini")" || return 2; v_ini="Some($ini)"; fi
  if [ -n "$fim" ]; then fim="$(_tam "ala final do $barra"   "$fim")" || return 2; v_fim="Some($fim)"; fi
  meow_escrever "$dir/size_wings" "Some(($v_ini, $v_fim))" 644; rc=$?
  case "$rc" in 1) mudou=1 ;; 2) meow_erro "não consegui escrever $dir/size_wings"; return 2 ;; esac
  return 0
}

aplicar_barra Panel "$FORMA_PAINEL_SOLTO" "$FORMA_PAINEL_ILHA" \
  "$FORMA_MARGEM_PAINEL" "$FORMA_RAIO_PAINEL" "$FORMA_ESPACO_PAINEL" "$FORMA_RECHEIO_PAINEL" \
  || exit "$MEOW_ERRO"
aplicar_barra Dock "$FORMA_DOCK_SOLTO" "$FORMA_DOCK_ILHA" \
  "$FORMA_MARGEM_DOCK" "$FORMA_RAIO_DOCK" "$FORMA_ESPACO_DOCK" "$FORMA_RECHEIO_DOCK" \
  || exit "$MEOW_ERRO"

aplicar_tamanhos Panel "$FORMA_CENTRO_PAINEL" "$FORMA_ALA_INICIAL_PAINEL" "$FORMA_ALA_FINAL_PAINEL" \
  || exit "$MEOW_ERRO"
aplicar_tamanhos Dock  "$FORMA_CENTRO_DOCK"   "$FORMA_ALA_INICIAL_DOCK"   "$FORMA_ALA_FINAL_DOCK" \
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

#   E O RAIO PODE NÃO SER NOSSO (26/08/2026): com `FORMA_RAIO_*` vazio este
#   script não escreve a chave, e anunciar "com raio " (vazio) descreveria uma
#   barra que não existe. Nesse caso a frase diz de quem é o número, e mostra o
#   que está no disco — que é o que ela vê na tela.
_forma_raio_dito() { # $1 = Panel|Dock  $2 = valor do meow.conf (pode ser vazio)
  local disco
  [ -n "$2" ] && { printf 'raio %s' "$2"; return 0; }
  disco="$(cat "$BASE/com.system76.CosmicPanel.$1/v1/border_radius" 2>/dev/null || true)"
  case "$disco" in
    ''|*[!0-9]*) printf 'raio da GUI' ;;
    *)           printf 'raio %s (seu)' "$disco" ;;
  esac
}

# Margem também pode estar vazia — mesma razão do raio.
_forma_margem_dita() { # $1 = Panel|Dock  $2 = valor do meow.conf
  local disco
  [ -n "$2" ] && { printf 'margem %s' "$2"; return 0; }
  disco="$(cat "$BASE/com.system76.CosmicPanel.$1/v1/margin" 2>/dev/null || true)"
  case "$disco" in
    ''|*[!0-9]*) printf 'margem da GUI' ;;
    *)           printf 'margem %s (sua)' "$disco" ;;
  esac
}

if [ "$mudou" = "0" ]; then
  meow_ok "forma já conforme: painel $(_forma_raio_dito Panel "$FORMA_RAIO_PAINEL") $(_forma_margem_dita Panel "$FORMA_MARGEM_PAINEL"), dock $(_forma_raio_dito Dock "$FORMA_RAIO_DOCK") $(_forma_margem_dita Dock "$FORMA_MARGEM_DOCK")"
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"
# A FRASE DE SUCESSO DESCREVIA O DIA EM QUE FOI ESCRITA, NÃO O ARQUIVO (25/08)
#   Estava cravada como "painel solto …, dock em ilha …". Era verdade em 10/08 e
#   é o INVERSO do que está no disco agora: o `FORMA_DOCK_ILHA` voltou para
#   `nao` em 11/08 (a ilha fundia os segmentos do dock) e o meow.conf dela pôs
#   `FORMA_PAINEL_ILHA="sim"`. Frase de sucesso que descreve outra configuração
#   é lida como confirmação — é o jeito mais barato de esconder um erro.
#   `_bool` aqui não pode falhar: se o valor fosse inválido o `aplicar_barra`
#   já teria saído com 2 lá em cima.
_forma_como() { case "$(_bool "$1")" in
                  true) printf 'em ilha com %s' "$2" ;;
                  *)    printf 'de largura cheia com %s' "$2" ;;
                esac; }
meow_ok "painel $(_forma_como "$FORMA_PAINEL_ILHA" "$(_forma_raio_dito Panel "$FORMA_RAIO_PAINEL")"), dock $(_forma_como "$FORMA_DOCK_ILHA" "$(_forma_raio_dito Dock "$FORMA_RAIO_DOCK")") — já valendo"
exit "$MEOW_DIVERGENTE"

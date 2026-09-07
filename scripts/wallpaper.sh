#!/usr/bin/env bash
# wallpaper.sh — o carrossel de papéis de parede, na rotação NATIVA do COSMIC.
#
# POR QUE NATIVA, E NÃO UM TIMER NOSSO
#   Medido em 2026-08-04: com `source: Path(<diretório>)` e `rotation_frequency: 60`,
#   o `cosmic-bg` abriu três arquivos distintos em intervalos de 60,04s. A rotação
#   sempre funcionou — o motivo de não girar nesta máquina é que o `source` aponta
#   para um ARQUIVO ÚNICO. Em teste de controle com um arquivo só, o timer disparava
#   e redesenhava a mesma imagem. Ligar o carrossel é trocar UM campo.
#
#   Um timer `systemd --user` faria o mesmo com um processo a mais, uma unit a mais
#   e um modo de falha a mais. Fica documentado como plano B, não implementado.
#
# AS TRÊS ARMADILHAS MEDIDAS
#   1. A lista de imagens é FOTOGRAFADA quando a configuração é carregada. Um arquivo
#      novo largado no diretório NÃO entra na rotação, apesar de o log dizer
#      "watching source" — passou cinco rotações inteiras sem ser aberto. Por isso
#      `adicionar` força a releitura no fim, com o `forcar_releitura` abaixo.
#
#      ATÉ 25/08/2026 ESTA LINHA DIZIA "`adicionar` reescreve a configuração no
#      fim: é o que força a releitura", E ELA SE CONTRADIZIA COM A ARMADILHA 3,
#      TRÊS LINHAS ABAIXO. O `adicionar` chamava `cmd_aplicar`, que escreve a
#      configuração — e a configuração NÃO CONTÉM a lista de imagens, só o
#      caminho da pasta. Então o conteúdo saía idêntico, o `meow_escrever`
#      devolvia "sem mudança", e nenhuma releitura acontecia: a imagem
#      adicionada não entrava na rotação até que outra coisa mudasse o texto do
#      arquivo. O comando dizia "1 imagem adicionada" e estava certo sobre o
#      `cp` e errado sobre o efeito.
#   2. Escrever na configuração NÃO AVANÇA, REINICIA: revarre o diretório, volta para
#      a PRIMEIRA imagem alfanumérica e zera o timer. Logo não existe "próximo" barato.
#   3. Escrever conteúdo IDÊNTICO é no-op total — nem releitura acontece. Quando se
#      QUER forçar a releitura, é preciso que o conteúdo mude DE FATO. É o que o
#      `forcar_releitura` faz: escreve uma vez com o `rotation_frequency`
#      trocado e outra com o valor certo. Duas escritas, dois conteúdos
#      diferentes, e o estado final é o correto.
#
# NÃO EXISTE GATILHO DE "PRÓXIMO"
#   O `cosmic-bg` não fala D-Bus: não tem nome no barramento, não tem conexão, e o
#   binário não contém nenhuma string de D-Bus (medido). Os fds dele são dois sockets
#   Wayland e um inotify. Então `proximo` só é possível reiniciando a rotação — o que
#   leva de volta à primeira imagem, não à seguinte. Este script não finge o contrário.
#
# AS QUATRO PASTAS
#   ativos/     o que entra na rotação  <- é ela que vira `source`
#   favoritos/  guardadas por escolha dela; entram na rotação por cópia
#   banidos/    saíram por decisão dela. MOVIDAS, nunca apagadas.
#   originais/  a foto antes de qualquer recolorização, para poder refazer
#
#   E, desde 25/08/2026, mais duas que NÃO são curadoria e sim DERIVADAS:
#   `ativos-noite/` e `ativos-dia/`. Ninguém guarda imagem nelas — são links
#   duros para os arquivos de `ativos/`, remontados a cada `aplicar` e apagados
#   inteiros quando `WALLPAPER_NOITE="nao"`. O acervo continua sendo um só, e
#   nenhum arquivo dela é movido para separar claro de escuro.
#
# --- DIA E NOITE: POR QUE UMA PASTA A MAIS, E NÃO UM FILTRO ------------------
# O QUE ELA VIU (24/08/2026, captura de 23:57)
#   O papel de parede era vaporwave pastel CLARO e saturado dentro de um sistema
#   Mocha, e as duas barras apareciam lavadas e sem lugar. Ela baniu a imagem no
#   mesmo dia ("esse em específico eu odiei"). O papel de parede é 95% dos pixels
#   da tela: sem campo escuro não existe "aceso", e o carrossel não distinguia
#   claro de escuro.
#
# A MEDIÇÃO, QUE VEIO ANTES DO CÓDIGO (25/08/2026, os 54 papéis de `ativos/`)
#   Duas métricas foram medidas e comparadas, e a diferença entre elas não é
#   acadêmica:
#
#     `%[fx:mean]` é a média dos TRÊS canais com peso IGUAL — não é luminância.
#     O verde carrega 71,5% do brilho que o olho enxerga e o azul só 7,2%. Num
#     papel roxo-escuro deste acervo (R=0,412 G=0,029 B=0,279) essa média dá
#     0,240 e o coloca em 15º entre os 54, quando ele é, para o olho, o SEGUNDO
#     mais escuro do acervo (0,128). O erro é de 0,112 — maior que duas faixas
#     inteiras do histograma.
#
#     `-colorspace Gray` antes do `%[fx:mean]` aplica 0,2126·R + 0,7152·G +
#     0,0722·B (Rec.709), e é o que este arquivo usa. Cuidado com o atalho que
#     parece equivalente: `%[fx:luminance]` é um símbolo POR PIXEL, avaliado no
#     pixel (0,0) — na primeira imagem testada ele devolveu 0,0248 contra os
#     0,1824 da imagem inteira. Ele não mede o papel, mede o canto dele.
#
#   As duas concordam na ORDEM (com grupos do mesmo tamanho, UMA imagem troca de
#   lado) e discordam em ONDE CORTAR, que é o que decide a sprint: no histograma
#   da média crua não existe vale nenhum entre 0,30 e 0,50 (6, 6, 4, 6 imagens
#   por faixa de 0,05), e o único vazio aparece lá em cima, perto de 0,52 — um
#   corte ali deixaria 45 imagens de um lado e 9 do outro.
#
# O LIMIAR, E POR QUE ELE NÃO É UM NÚMERO REDONDO
#   Na luminância perceptual o histograma tem um vale onde o corte cabe: das 54,
#   só DUAS caem entre 0,35 e 0,40, contra 7 em cada faixa vizinha.
#
#       0,20-0,25   6        0,35-0,40   2   <- o vale
#       0,25-0,30   5        0,40-0,45   7
#       0,30-0,35   7        0,45-0,50   5
#
#   E o vale coincide com a paleta do próprio sistema: `surface2` do Mocha
#   (#585B70) tem luminância 0,3603 e é o tom mais claro que o tema usa como
#   FUNDO. Mais claro que o fundo mais claro do tema, o papel deixa de ser campo
#   e passa a competir com a interface — que é exatamente o que ela viu às 23:57.
#
#   O padrão é 0,37 e não 0,36 por um motivo medido: 0,3603 cai EM CIMA de uma
#   imagem do acervo (0,3605). O trecho vazio mais largo dentro do vale vai de
#   0,3605 a 0,3818, e 0,37 é o meio dele — assim nenhuma imagem fica a menos de
#   0,01 do corte. Limiar apoiado num ponto de dado é limiar que um reencode
#   desempata sozinho.
#
#   Nos 54 de hoje isso dá 32 na noite e 22 no dia. A sprint avisava que menos
#   de ~20 de um dos lados seria falta de imagem, e não erro de corte; não é o
#   caso, mas 22 é pouca folga — quem for buscar imagem nova, busque clara.
#
# POR QUE UMA PASTA, E NÃO UM CAMPO DE CONFIGURAÇÃO
#   O `cosmic-bg` aponta para uma PASTA e roda o carrossel sozinho: não existe
#   "lista de imagens" na configuração dele, e o `filter_by_theme` que ele tem é
#   o que este arquivo já desliga de propósito, logo abaixo. Separar claro de
#   escuro exige, portanto, DUAS pastas — e mover arquivo entre elas está fora
#   de questão: `ativos/` é o caminho que a `WALLPAPER_FONTES_DELA` conhece, que
#   o README manda ela usar para arrastar imagem, e sobre o qual `banir`,
#   `adicionar` e `semear` operam. O acervo tem de continuar sendo um só.
#
#   Então as pastas derivadas são feitas de LINK DURO (`ln`, sem `-s`). Como
#   aponta para o mesmo inode, ele não custa disco nem duplica imagem — e exige
#   o mesmo sistema de arquivos, que é por que as duas pastas nascem ao LADO de
#   `ativos/`. (Há queda para simbólico se o `ln` duro falhar.)
#
#   A JUSTIFICATIVA QUE ESTAVA AQUI ERA UM MEDO NÃO MEDIDO, E FOI MEDIDA EM
#   01/09/2026. O texto dizia: *"o `read_dir` do Rust devolve `file_type()` SEM
#   seguir link simbólico, e um `is_file()` do outro lado descartaria a pasta
#   inteira — tela preta, sem mensagem. Não dá para medir isso sem apontar a
#   configuração dela para uma pasta de teste e olhar a TV dela, o que esta
#   sprint não faz."*
#
#   Dá, e foi feito: uma pasta `teste-simbolico/` com três links simbólicos para
#   imagens de `ativos/`, o `source:` apontado para lá, e o estado do próprio
#   cosmic-bg lido depois:
#       ("DP-1", Path(".../teste-simbolico/cat-landscapes-Cloudsnight.jpg"))
#   Ou seja: **o cosmic-bg SEGUE link simbólico e desenha a imagem**. Não há tela
#   preta. O link duro continua sendo a escolha certa — por inode e por disco,
#   não por medo —, e a queda para simbólico deixou de ser um degrau para o
#   desconhecido.
#
#   (O primeiro teste foi DESFEITO EM SEGUNDOS pelo `meow-fundo.path`, que viu a
#   configuração mudar e a restaurou. Foi preciso parar o vigia para medir — e
#   isso é, por si só, a melhor prova de que aquela proteção funciona.)
#
# A TROCA CUSTA UMA REESCRITA DE CONFIGURAÇÃO POR VIRADA, E SÓ
#   Trocar `ativos-noite/` por `ativos-dia/` muda o texto do `source:`, e o
#   `meow_escrever` só escreve quando o conteúdo muda de fato. Ou seja: a rotação
#   é reiniciada (armadilha 2, lá em cima) duas vezes por dia, nas duas viradas,
#   e em nenhum outro momento. Remontar os links NÃO reinicia nada — o
#   `cosmic-bg` tem uma única watch de inotify, e é sobre o diretório de
#   CONFIGURAÇÃO, não sobre a pasta de imagens.
#
#   A virada acontece no tique seguinte do `meow-wallpaper.timer`: ela vê a troca
#   em até 15 minutos depois do horário, não no minuto exato. Um relógio próprio
#   só para isso seria o processo a mais que o topo deste arquivo já recusou.
#
# O QUE ACONTECE QUANDO NÃO DÁ PARA MEDIR
#   Sem ImageMagick, ou com um grupo que ficou com menos de duas imagens (ela
#   banir os escuros todos, por exemplo), a rotação volta para `ativos/` com um
#   aviso e o carrossel continua girando. Um papel de parede claro é um defeito
#   de gosto; uma tela preta é um defeito de verdade.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

BASE="${WALLPAPER_BASE:-$HOME/.local/share/backgrounds/meowsystem}"
ATIVOS="$BASE/ativos"
NOITE_DIR="$BASE/ativos-noite"
DIA_DIR="$BASE/ativos-dia"
BG="$HOME/.config/cosmic/com.system76.CosmicBackground/v1"
ORDEM="${WALLPAPER_ORDEM:-aleatoria}"
INTERVALO="${WALLPAPER_INTERVALO:-5m}"

# A pasta que o `source:` vai apontar nesta rodada. Nasce em `ativos/` — que é o
# comportamento de antes de 25/08/2026 e o de sempre com a noite desligada — e
# só muda dentro de `resolver_rotacao`. `GRUPO` fica vazio quando a rotação é o
# acervo inteiro, e é isso que o `estado` mostra.
ROTACAO="$ATIVOS"
GRUPO=""
NOITE_N=0
DIA_N=0

# --- LER O MEOW.CONF DIRETO, E POR QUE ISSO PRECISOU EXISTIR AQUI ------------
# As chaves antigas de wallpaper chegam pelo AMBIENTE: o `install.sh`, o
# `bin/meow` e o `meow-wallpaper.service` exportam uma a uma, e o cabeçalho da
# `WALLPAPER_FONTES_DELA`, mais abaixo, explica por que uma chave fora daquelas
# listas chega vazia e o relógio de 15 minutos passa a desfazer a escolha dela
# quatro vezes por hora.
#
# As quatro chaves da noite nasceram DEPOIS daquelas listas, e mudá-las é mudar
# `install.sh`, `bin/meow` e a unit — três arquivos, de três donos diferentes,
# para uma chave só. Enquanto isso não acontece, uma chave nova que só fosse
# lida do ambiente seria uma chave que a Vitória escreve no `meow.conf`, vê o
# `meow wallpaper aplicar` obedecer (a CLI sourceia o conf) e vê o timer ignorar
# quinze minutos depois. Silenciosamente, que é o pior jeito.
#
# Então a ordem de precedência passa a ser explícita: AMBIENTE, depois
# MEOW.CONF, depois o padrão do código. A leitura do arquivo é a mesma regra do
# wizard (`wiz_linha_da_chave` em bin/meow) e a mesma que a `fontes_no_conf`
# usava sozinha desde 11/08: vale a ÚLTIMA atribuição, que é a que o `.` do
# shell obedece.
#
# VALOR CRU, SEM EXPANDIR: `WALLPAPER_BASE="$HOME/..."` é o estilo do arquivo, e
# expandir aqui congelaria o caminho. Quem precisa do caminho expandido expande
# na hora de comparar — é o que o `cmd_permitir` faz. Para as chaves da noite,
# que são "sim", "18:00" e "0.37", a diferença não aparece.
conf_bruto() {
  local chave="$1" linha resto
  [ -f "$MEOW_CONF_ARQUIVO" ] || return 0
  linha="$(grep -E -- "^[[:space:]]*(export[[:space:]]+)?${chave}=" \
             "$MEOW_CONF_ARQUIVO" 2>/dev/null | tail -n1)"
  [ -n "$linha" ] || return 0
  resto="${linha#*=}"
  case "$resto" in
    '"'*) resto="${resto#\"}"; printf '%s' "${resto%%\"*}" ;;
    "'"*) resto="${resto#\'}"; printf '%s' "${resto%%\'*}" ;;
    *)    printf '%s' "${resto%%[[:space:]#]*}" ;;
  esac
}

# ambiente > meow.conf > padrão. `${!chave-}` é expansão indireta do bash: a
# chave chega como NOME, não como valor, para a precedência caber numa linha.
valor_da_chave() {
  local chave="$1" padrao="$2" v
  v="${!chave-}"
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  v="$(conf_bruto "$chave")"
  [ -n "$v" ] && { printf '%s' "$v"; return 0; }
  printf '%s' "$padrao"
}

# "Sim " -> sim · "NÃO" -> nao · qualquer outra coisa -> o padrão, com aviso.
#
# É a mesma forma do `modo_de_ajuste` lá em cima, e a escolha de cair no PADRÃO
# (e não no contrário) é deliberada: um valor que o script não entende não pode
# virar a decisão oposta à que ela escreveu. `WALLPAPER_NOITE="nao "`, com um
# espaço sobrando, ligaria a noite; `WALLPAPER_NOITE="Sim"` a desligaria. Aqui os
# dois são aparados, o `ã` é normalizado à mão (o `${v,,}` do bash depende do
# locale, e sob `LC_ALL=C` — que é como o timer pode rodar — ele não mexe em
# multibyte) e o que sobrar de estranho sai avisado.
sim_ou_nao() {
  local v="$1" chave="$2" padrao="$3"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  v="${v//ã/a}"; v="${v//Ã/a}"
  case "${v,,}" in
    sim|s|1|true|yes)     printf 'sim'; return 0 ;;
    nao|n|0|false|no)     printf 'nao'; return 0 ;;
  esac
  meow_aviso "$chave=\"$1\" não existe; usando $padrao (sim | nao)"
  printf '%s' "$padrao"
}

# --- AS QUATRO CHAVES DA NOITE ----------------------------------------------
# O PADRÃO NASCE LIGADO, E ISSO É ESCOLHA DELA, NÃO MINHA. A Sprint S existe
# porque ela viu o desktop lavado às 23:57 e mandou consertar; nascer desligado
# seria entregar a sprint e não entregar o efeito. Desligar é uma linha
# (`WALLPAPER_NOITE="nao"`), e desligar DESLIGA: a rotação volta para `ativos/`
# e as duas pastas derivadas somem do disco no mesmo comando.
NOITE="$(sim_ou_nao "$(valor_da_chave WALLPAPER_NOITE sim)" WALLPAPER_NOITE sim)"
NOITE_INICIO="$(valor_da_chave WALLPAPER_NOITE_INICIO 18:00)"
NOITE_FIM="$(valor_da_chave WALLPAPER_NOITE_FIM 07:00)"
LIMIAR_LUZ="$(valor_da_chave WALLPAPER_LIMIAR_LUZ 0.37)"

# O cache das medições. É ESTADO, não configuração: dá para apagar sem perder
# nada além dos segundos de remedir. Fica fora do acervo de propósito — arquivo
# de texto dentro de `ativos/` seria uma imagem quebrada na rotação dela.
LUZ_TSV="$MEOW_ESTADO/wallpaper-luz.tsv"

# --- COMO A IMAGEM OCUPA A TELA ----------------------------------------------
# Em 11/08/2026 ela mandou uma captura da tela e disse: "o wallpaper precisa
# preencher a largura e altura". A captura mostrava duas tarjas pretas, uma de
# cada lado — a imagem cabia inteira no meio e sobrava tela.
#
# A causa estava AQUI, e o comentário que existia neste arquivo mentia: dizia
# que `scaling_mode` "é escolha dela e é preservada", mas a `config_desejada`
# gravava `Fit((0.0, 0.0, 0.0))` cravado no texto, toda vez, por cima do que ela
# tivesse escolhido na GUI. Não era preservação nenhuma: era imposição de um
# valor que ninguém tinha decidido.
#
#   preencher -> `Zoom`   a imagem cobre a tela inteira; o que não couber, corta
#   caber     -> `Fit`    a imagem inteira aparece; o que sobrar vira tarja
#   esticar   -> `Stretch` a imagem deforma até caber (nunca é o que se quer)
#
# `Fit` leva uma cor de tarja `(r, g, b)` em floats 0-1. Os outros dois não
# levam nada — e escrever `Zoom(...)` com argumento é erro de sintaxe RON que o
# cosmic-bg engole calado, ficando com a config anterior em memória.
AJUSTE="${WALLPAPER_AJUSTE:-preencher}"

modo_de_ajuste() {
  case "$1" in
    preencher|zoom)   printf 'Zoom' ;;
    esticar|stretch)  printf 'Stretch' ;;
    caber|fit)        printf 'Fit((0.0, 0.0, 0.0))' ;;
    *)
      meow_aviso "WALLPAPER_AJUSTE=\"$1\" não existe; usando preencher"
      printf 'Zoom' ;;
  esac
}

# --- A ALLOWLIST: A ESCOLHA DELA PASSOU A SER DITA, NÃO ADIVINHADA -----------
# Caminhos absolutos separados por `:` (convenção do $PATH), cada um valendo
# para ele mesmo e para tudo abaixo dele. Quem preenche é `permitir <caminho>`,
# e o porquê inteiro está no comentário desta chave no `meow.conf.exemplo` e na
# fronteira, mais abaixo neste arquivo.
#
# LER DO AMBIENTE É O QUE TORNA ISTO REAL NO RELÓGIO DE 15 MINUTOS: o
# `meow-wallpaper.service` sourceia o meow.conf e exporta as chaves de wallpaper
# uma a uma. Uma chave nova que não entre naquela lista de `export` chega aqui
# vazia — e o timer passaria a desfazer, a cada quinze minutos, exatamente a
# escolha que ela acabou de autorizar.
FONTES_DELA="${WALLPAPER_FONTES_DELA:-}"

fonte_autorizada() {
  local fonte="$1" texto="${2-$FONTES_DELA}" p
  [ -n "$fonte" ] && [ -n "$texto" ] || return 1
  # Array, e não `for p in $texto` com IFS=: — a expansão sem aspas também faz
  # *globbing*, e um caminho com `*` ou `[` no nome (a pasta dela tem emoji e
  # espaço; `[` não seria surpresa) viraria outra coisa no meio do caminho,
  # calado.
  local -a lista=()
  IFS=: read -r -a lista <<< "$texto"
  for p in ${lista[@]+"${lista[@]}"}; do
    [ -n "$p" ] || continue
    case "$fonte" in "$p"|"$p"/*) return 0 ;; esac
  done
  return 1
}

# "30s" / "5m" / "2h" -> segundos. O COSMIC quer segundos e nada mais.
segundos_de() {
  local v="$1" n u
  n="${v%[smh]}"; u="${v#$n}"
  case "$n" in ''|*[!0-9]*) echo 300; return ;; esac
  case "$u" in
    s) echo "$n" ;;
    m) echo $((n * 60)) ;;
    h) echo $((n * 3600)) ;;
    *) echo "$n" ;;   # sem sufixo já é segundos
  esac
}

# Só existem dois valores no binário: Alphanumeric e Random. Não há ordenação por
# data nem manual — se a ordem importar, prefixe os arquivos com 01-, 02-.
metodo_de() {
  case "${1:-aleatoria}" in
    alfabetica|alphanumeric) echo Alphanumeric ;;
    *) echo Random ;;
  esac
}

config_desejada() {
  local freq metodo ajuste
  freq="$(segundos_de "$INTERVALO")"
  metodo="$(metodo_de "$ORDEM")"
  ajuste="$(modo_de_ajuste "$AJUSTE")"
  # `filter_by_theme: false` de propósito: com `true` o COSMIC filtra as imagens
  # pelo claro/escuro do tema e pode acabar sem nenhuma candidata no diretório —
  # tela preta sem explicação. O carrossel é dela, não do tema.
  #
  # `filter_method: Lanczos` é o único campo aqui que continua cravado, e é de
  # propósito: é o reamostrador que não serrilha ao reduzir, a mesma lição que a
  # geração dos ícones pagou em 08/08 (512→48 em tempo de desenho).
  # `$ROTACAO` e não `$ATIVOS`: com a noite ligada esta é a ÚNICA linha que muda
  # entre um grupo e outro, e é por isso que a virada custa uma reescrita de
  # configuração e nada mais.
  cat <<FIM
(
    output: "all",
    source: Path("$ROTACAO"),
    filter_by_theme: false,
    rotation_frequency: $freq,
    filter_method: Lanczos,
    scaling_mode: $ajuste,
    sampling_method: $metodo,
)
FIM
}

# --- FORÇAR A RELEITURA, QUANDO ESCREVER O MESMO NÃO BASTA (25/08/2026) ------
#
# Só existe por causa da armadilha 3 do cabeçalho: o `cosmic-bg` ignora uma
# escrita cujo conteúdo não mudou, e a configuração não contém a lista de
# imagens — só o caminho da pasta. Quem acrescenta ou tira um arquivo DENTRO da
# pasta produz exatamente esse caso: o que o script quer gravar é byte a byte o
# que já está lá, e a lista fotografada no carregamento continua valendo.
#
# O truque é escrever DUAS vezes: a primeira com o `rotation_frequency` trocado
# por um valor que ninguém usa, a segunda com o conteúdo verdadeiro. Os dois
# conteúdos diferem entre si e do que estava no disco, então as duas escritas
# são reais e o `cosmic-bg` relê. O estado final é o certo — a passagem pelo
# valor falso dura o tempo de um `printf`.
#
# O PREÇO ESTÁ NA ARMADILHA 2, E QUEM CHAMA PRECISA QUERER PAGAR: releitura não
# avança, REINICIA. O diretório é revarrido, a rotação volta ao começo e o timer
# zera. Isso é aceitável num comando que a pessoa digitou (`adicionar`, `banir`)
# — ela acabou de mexer no acervo e espera ver o efeito. É INACEITÁVEL no
# `aplicar` do relógio de 15 minutos, que rodaria isto sozinho e reiniciaria a
# rotação quatro vezes por hora, para sempre. Por isso a função é chamada só
# pelos comandos de mão, nunca pelo caminho do timer.
#
# Em seco não escreve nada: só diz o que faria.
forcar_releitura() {
  local alvos=() alvo conteudo
  mapfile -t alvos < <(ls -1 "$BG" 2>/dev/null | grep -E '^(all|output\.)' )
  [ "${#alvos[@]}" -gt 0 ] || return 0

  if meow_seco; then
    meow_muda "forçaria o cosmic-bg a reler a pasta (a rotação recomeça)"
    return 0
  fi

  for alvo in "${alvos[@]}"; do
    [ -f "$BG/$alvo" ] || continue
    conteudo="$(cat "$BG/$alvo")"
    # 1 é frequência que nenhum caminho deste script produz (os valores vêm de
    # WALLPAPER_INTERVALO, mínimo 30s) — some no instante seguinte, mas mesmo
    # que a máquina morra aqui o carrossel só ficaria rápido, nunca parado.
    printf '%s' "${conteudo/rotation_frequency: /rotation_frequency: 1, x_meow_reler: }" > "$BG/$alvo"
    printf '%s' "$conteudo" > "$BG/$alvo"
  done
  meow_info "cosmic-bg avisado — a rotação recomeça pela primeira imagem"
  return 0
}

criar_pastas() {
  local p
  for p in ativos favoritos banidos originais; do
    [ -d "$BASE/$p" ] && continue
    meow_seco && { meow_muda "criaria $BASE/$p"; continue; }
    mkdir -p "$BASE/$p" || return "$MEOW_ERRO"
  done
  return 0
}

# Semear a partir das imagens que ela JÁ tem. Não baixamos nada da internet sem
# ela pedir: o carrossel tem de funcionar no primeiro `install.sh`, offline.
#
# SÓ NA PRIMEIRA VEZ, e isso não é detalhe. A versão anterior semeava a cada
# `aplicar` — e como `banir` chama `aplicar` no fim (para forçar a releitura da
# lista), banir uma imagem da pasta dela a copiava DE VOLTA no mesmo comando.
# Ela bania, o script dizia "banida", e a imagem continuava lá. Agora a semeadura
# só acontece quando `ativos/` está vazio, ou seja, na primeira instalação:
# depois disso quem manda no conteúdo da pasta é ela.
semear_das_dela() {
  local origem="$HOME/Imagens/Parede_papel"
  [ -d "$origem" ] || return 0
  [ "$(quantas)" -eq 0 ] || return 0
  local n=0
  while IFS= read -r img; do
    local nome_dela; nome_dela="$(basename "$img")"
    local destino="$ATIVOS/$nome_dela"
    [ -e "$destino" ] && continue
    # ESTA PORTA TAMBÉM REPUNHA O QUE ELA TIROU
    #   O `semear` da coleção já consulta o banimento; esta cópia da pasta
    #   pessoal dela não consultava nada. Uma imagem banida daqui voltava
    #   sozinha na primeira vez que `ativos/` esvaziasse. Medido em 24/08/2026:
    #   era o caso de uma imagem que ela já tinha banido antes desta sessão.
    esta_banida "$nome_dela" && continue
    meow_seco || cp -n "$img" "$destino" 2>/dev/null || continue
    n=$((n + 1))
  done < <(find "$origem" -maxdepth 1 -type f \
             \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null)
  if [ "$n" -gt 0 ]; then
    if meow_seco; then
      meow_muda "copiaria $n imagem(ns) de ~/Imagens/Parede_papel"
    else
      meow_info "$n imagem(ns) copiadas de ~/Imagens/Parede_papel"
    fi
  fi
  return 0
}

quantas() { find "$ATIVOS" -maxdepth 1 -type f 2>/dev/null | wc -l; }
# As pastas derivadas são feitas de link — `-type f` sozinho contaria zero se um
# dia a queda para simbólico tiver acontecido.
quantas_em() { find "$1" -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | wc -l; }

# =============================================================================
# DIA E NOITE — a medição, a classificação e as duas pastas derivadas
# O porquê inteiro está no cabeçalho, em "DIA E NOITE". Aqui fica o como.
# =============================================================================

# `magick` no ImageMagick 7, `convert` no 6 (é o que esta máquina tem).
# Resolvido uma vez; vazio quer dizer "não dá para medir", e quem chama trata
# isso voltando para `ativos/` em vez de falhar.
IM=""
tem_imagemagick() {
  [ -n "$IM" ] && return 0
  if   meow_tem magick;  then IM=magick
  elif meow_tem convert; then IM=convert
  else return 1
  fi
  return 0
}

# A luminância perceptual de UM arquivo, em 0-1.
#
# `-define jpeg:size=` NÃO É OTIMIZAÇÃO PREMATURA: isto roda no relógio de 15
# minutos. Medir os 54 papéis em tamanho cheio custa ~10 s de CPU; com a dica,
# que faz o libjpeg decodificar já reduzido no próprio DCT, custa ~4 s. E a
# perda de exatidão foi medida nos 54: 0,0005 no pior caso, três ordens de
# grandeza abaixo do limiar — reduzir é tirar média, que é o que se está
# calculando de qualquer jeito.
#
# `[0]` seleciona o primeiro quadro. Sem ele, um GIF ou um PNG animado
# entregariam N imagens e o `%[fx:mean]` sairia repetido, N linhas, e o valor
# viraria lixo silencioso.
luz_de() {
  local arq="$1" v
  v="$("$IM" -quiet -define jpeg:size=256x256 "${arq}[0]" -resize 128x128 \
        -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null)" || return 1
  case "$v" in ''|*[!0-9.eE+-]*) return 1 ;; esac
  printf '%s' "$v"
}

# "0.3605" -> 3605, para comparar sem `awk`.
#
# Comparar float em bash sai por `awk`, e seriam 54 processos por rodada, quatro
# vezes por hora, só para dizer qual de dois números é maior. Aqui é texto puro:
# parte inteira × 10000 mais quatro casas truncadas.
#
# `10#` em toda ponta porque `08` e `09` são octal INVÁLIDO para o bash, e por
# aqui passam a hora `08:00` e a luminância `0.0812`.
milesimos_de() {
  local v="$1" i f
  case "$v" in *e*|*E*) v="$(printf '%.6f' "$v" 2>/dev/null)" || v=0 ;; esac
  case "$v" in
    *.*) i="${v%%.*}"; f="${v#*.}" ;;
    *)   i="$v";       f="0" ;;
  esac
  f="${f}0000"; f="${f:0:4}"
  case "$i" in ''|*[!0-9]*) i=0 ;; esac
  case "$f" in *[!0-9]*) f=0000 ;; esac
  echo $(( 10#$i * 10000 + 10#$f ))
}

# nome do arquivo -> luminância. Preenchido por `medir_acervo`.
declare -A LUZ=()

# Mede `ativos/` inteiro, reaproveitando o que já foi medido.
#
# O CACHE É POR (TAMANHO, MTIME), E NÃO POR NOME. Um arquivo trocado por outro
# com o mesmo nome — que é exatamente o que `adicionar` e `semear` fazem quando
# uma imagem é substituída — muda pelo menos um dos dois, e é remedido. Só o
# nome seria memória que envelhece calada.
#
# O ARQUIVO NÃO PASSA PELO `meow_escrever`, DE PROPÓSITO. Ele é ESTADO derivado,
# não configuração: apagá-lo custa os segundos de remedir e nada mais. Pelo
# `meow_escrever` ele entraria no manifesto (e o `--uninstall` passaria a
# removê-lo como se fosse config dela) e, pior, imprimiria `~~ mudaria …` no
# modo seco — o que faria o `meow doctor` acusar divergência a cada rodada por
# causa de um cache. É a mesma decisão, e pelo mesmo motivo, que o cabeçalho de
# `limpar_estado_morto` já registra: aquilo também não conta como divergência.
#
# NO SECO, MEDE MAS NÃO GRAVA. Medir é leitura; gravar é escrita, e `--conferir`
# promete não escrever. O preço é um `meow doctor` de 4 s a mais numa máquina em
# que o `aplicar` nunca rodou — e some sozinho no primeiro `aplicar` de verdade.
medir_acervo() {
  LUZ=()
  local TAB=$'\t' NL=$'\n'
  local -A guardado=() carimbos=()
  local nome tam mt luz

  if [ -f "$LUZ_TSV" ]; then
    while IFS="$TAB" read -r nome tam mt luz; do
      case "$nome" in ''|'#'*) continue ;; esac
      [ -n "$luz" ] || continue
      guardado["$nome"]="$tam$TAB$mt$TAB$luz"
    done < "$LUZ_TSV"
  fi

  local arq base carimbo antes novos=0 falhas=0
  for arq in "$ATIVOS"/*; do
    [ -f "$arq" ] || continue
    base="${arq##*/}"
    # O cache é um TSV. Um nome com tab ou quebra de linha o corromperia na
    # gravação, e o defeito só apareceria na leitura seguinte, em outro arquivo.
    case "$base" in
      *"$TAB"*|*"$NL"*)
        meow_aviso "'$base' tem tab ou quebra de linha no nome — fica fora da separação claro/escuro"
        continue ;;
    esac
    carimbo="$(stat -c $'%s\t%Y' -- "$arq" 2>/dev/null)" || continue
    carimbos["$base"]="$carimbo"
    antes="${guardado[$base]:-}"
    if [ -n "$antes" ] && [ "${antes%"$TAB"*}" = "$carimbo" ]; then
      LUZ["$base"]="${antes##*"$TAB"}"
      continue
    fi
    tem_imagemagick || { falhas=$((falhas + 1)); continue; }
    luz="$(luz_de "$arq")" || { falhas=$((falhas + 1)); continue; }
    LUZ["$base"]="$luz"
    novos=$((novos + 1))
  done

  [ "$novos" -gt 0 ] && meow_debug "medi $novos papel(is) de parede novo(s) ou trocado(s)"
  if [ "$falhas" -gt 0 ]; then
    if tem_imagemagick; then
      meow_aviso "$falhas imagem(ns) não puderam ser medidas — ficam fora da separação claro/escuro"
    else
      meow_aviso "sem ImageMagick não dá para separar claro de escuro ($falhas imagem(ns))"
      meow_info "  instale com: sudo apt install imagemagick"
    fi
  fi

  meow_seco && return 0
  [ "${#LUZ[@]}" -gt 0 ] || return 0

  local conteudo linhas=""
  conteudo="# wallpaper-luz.tsv — a luminância perceptual (Rec.709) de cada papel de ativos/.$NL"
  conteudo="$conteudo# nome<TAB>tamanho<TAB>mtime<TAB>luminância. É CACHE: apagar só custa remedir.$NL"
  while IFS= read -r base; do
    linhas="$linhas$base$TAB${carimbos[$base]}$TAB${LUZ[$base]}$NL"
  done < <(printf '%s\n' "${!LUZ[@]}" | LC_ALL=C sort)
  conteudo="$conteudo$linhas"

  [ "$conteudo" = "$(cat "$LUZ_TSV" 2>/dev/null)$NL" ] && return 0
  local dir tmp; dir="$(dirname "$LUZ_TSV")"
  mkdir -p "$dir" 2>/dev/null || return 0
  tmp="$(mktemp -p "$dir" ".meow.XXXXXX" 2>/dev/null)" || return 0
  printf '%s' "$conteudo" > "$tmp" 2>/dev/null \
    && chmod 644 "$tmp" 2>/dev/null \
    && mv -f "$tmp" "$LUZ_TSV" 2>/dev/null \
    || rm -f "$tmp"
  return 0
}

# "18:00" -> 1080. Falha (1) em qualquer coisa que não seja HH:MM.
minutos_de_hora() {
  local v="$1" h m
  case "$v" in
    [0-9][0-9]:[0-9][0-9]|[0-9]:[0-9][0-9]) ;;
    *) return 1 ;;
  esac
  h="${v%%:*}"; m="${v##*:}"
  [ "$((10#$h))" -le 23 ] && [ "$((10#$m))" -le 59 ] || return 1
  echo $(( 10#$h * 60 + 10#$m ))
}

# "é noite agora?" — 0 = sim.
#
# A JANELA ATRAVESSA A MEIA-NOITE, E ESSE É O CASO NORMAL AQUI: o padrão é
# 18:00-07:00, ou seja `início > fim`. Nesse formato a noite é "depois do início
# OU antes do fim"; "entre os dois" não existiria e a janela seria vazia.
#
# `início == fim` é o caso sem resposta óbvia, e fica valendo NOITE O DIA
# INTEIRO. A outra leitura — janela vazia — transformaria dois valores iguais
# numa chave que não faz nada e não avisa, que é o defeito que este projeto mais
# documenta ter cometido (a `LOG_NIVEL` inerte, as `WALLPAPER_SEMENTES`).
e_noite() {
  local ini fim agora
  ini="$(minutos_de_hora "$NOITE_INICIO")" || {
    meow_aviso "WALLPAPER_NOITE_INICIO=\"$NOITE_INICIO\" não é HH:MM; usando 18:00"
    ini=1080; }
  fim="$(minutos_de_hora "$NOITE_FIM")" || {
    meow_aviso "WALLPAPER_NOITE_FIM=\"$NOITE_FIM\" não é HH:MM; usando 07:00"
    fim=420; }
  agora="$(minutos_de_hora "$(date +%H:%M)")" || return 0
  [ "$ini" = "$fim" ] && return 0
  if [ "$ini" -gt "$fim" ]; then
    [ "$agora" -ge "$ini" ] || [ "$agora" -lt "$fim" ]
  else
    [ "$agora" -ge "$ini" ] && [ "$agora" -lt "$fim" ]
  fi
}

# Monta UMA pasta derivada: um link duro por nome da lista, e nada além disso
# dentro dela.
#
# O QUE ELA APAGA, E O QUE NUNCA APAGA. Só mexe em `$NOITE_DIR` e `$DIA_DIR` —
# nomes CRAVADOS neste arquivo, não deduzidos de nada, e que ninguém mais
# escreve. Lá dentro some o que saiu da lista e o que deixou de apontar para o
# arquivo de `ativos/`; o `-ef` compara device e inode, não nome, então uma
# imagem substituída em `ativos/` é relinkada em vez de ficar velha para sempre.
# Não entra em subdiretório e não toca em `ativos/` nunca.
montar_derivada() {
  local dir="$1"; shift
  local -A quer=()
  local base arq
  for base in "$@"; do quer["$base"]=1; done

  mkdir -p "$dir" || { meow_erro "não consegui criar $dir"; return 1; }

  for arq in "$dir"/* "$dir"/.[!.]*; do
    [ -e "$arq" ] || [ -L "$arq" ] || continue
    base="${arq##*/}"
    [ -n "${quer[$base]:-}" ] && [ "$arq" -ef "$ATIVOS/$base" ] && continue
    rm -f -- "$arq"
  done

  for base in "$@"; do
    [ -e "$dir/$base" ] && continue
    ln -f -- "$ATIVOS/$base" "$dir/$base" 2>/dev/null && continue
    # Outro sistema de arquivos, ou um `ln` que recusou. O simbólico é pior (o
    # cabeçalho diz por quê) mas é melhor que a pasta ficar sem a imagem.
    ln -sfn -- "$ATIVOS/$base" "$dir/$base" 2>/dev/null || return 1
  done
  return 0
}

# DESLIGAR TEM DE DESLIGAR: com `WALLPAPER_NOITE="nao"` as duas pastas somem do
# disco, e não ficam ali paradas parecendo que o recurso continua ligado.
#
# É CHAMADA DEPOIS DE ESCREVER A CONFIGURAÇÃO, e a ordem não é detalhe: apagar
# antes deixaria o `cosmic-bg` apontando para uma pasta que não existe mais.
# O `rmdir` só remove diretório vazio — se sobrou alguma coisa que não era nossa,
# ele recusa e a gente diz, em vez de forçar.
soltar_derivadas() {
  local dir vistas=0
  for dir in "$NOITE_DIR" "$DIA_DIR"; do
    [ -d "$dir" ] || continue
    vistas=1
    if meow_seco; then meow_muda "removeria $dir/"; continue; fi
    find "$dir" -maxdepth 1 \( -type f -o -type l \) -delete 2>/dev/null
    rmdir "$dir" 2>/dev/null || meow_aviso "$dir/ não ficou vazio — deixei como estava"
  done
  [ "$vistas" = "1" ] || return 1     # 1 = não havia nada a soltar
  meow_seco || meow_info "a noite está desligada: as pastas derivadas saíram e a rotação é ativos/"
  return 0
}

# =============================================================================
# O REGISTRO DE LADO — A ESCOLHA DELA VENCE A MEDIÇÃO (06/09/2026)
# =============================================================================
# O PEDIDO, COM A GALERIA NA FRENTE
#   *"quando eu colocar o mouse em cima da imagem temos que ter as opções de Dia
#   e a opção Noite, não apenas a Tirar"*.
#
# O QUE FALTAVA, MEDIDO
#   Até 06/09/2026 o `_resolver_grupo` separava `ativos-dia/` de `ativos-noite/`
#   SÓ pela luminância: `medir_acervo` mede, `milesimos_de` compara, `LIMIAR_LUZ`
#   corta. Não existia porta nenhuma para discordar da medição. As duas saídas
#   que sobravam eram ruins do mesmo jeito: banir a imagem inteira (perder a
#   imagem para consertar o horário dela) ou mexer no limiar, que é GLOBAL e
#   move dezenas de outras imagens junto para corrigir uma.
#
#   E a medição erra de um jeito que número nenhum resolve, porque o que ela não
#   mede é o gosto: uma foto clara que ela quer de madrugada, um gráfico escuro
#   que ela quer de dia. O cabeçalho deste arquivo defende o limiar 0,37 com o
#   histograma dos 54 papéis de 25/08 — e continua valendo. O que ele nunca pôde
#   dizer é onde ela discorda.
#
# O DESENHO: DECISÃO ESCRITA VENCE HEURÍSTICA
#   É o mesmo padrão que o resto do projeto já usa: a automação age por decisão
#   escrita, e a medição só opina quando ninguém decidiu. Por isso o registro
#   guarda SÓ a discordância — ausente quer dizer "a medição decide". Nos 46
#   papéis desta máquina isso é a diferença entre um arquivo de 46 linhas que
#   envelhece a cada reencode e um de duas ou três que ela abre e entende.
#
# `auto` NÃO É UM VALOR, É A AUSÊNCIA DA LINHA
#   Escrever a palavra "auto" criaria três estados ("dia", "noite", "auto") onde
#   existem dois mais o padrão, e o registro passaria a crescer com linhas que
#   não decidem nada — exatamente o lixo silencioso que a poda mais abaixo
#   existe para evitar.
#
# POR QUE ELE MORA AO LADO DO `BANIDOS.txt`, E NÃO NO ESTADO
#   O `wallpaper-luz.tsv` fica em `$MEOW_ESTADO` porque é CACHE: apagar custa os
#   segundos de remedir e nada mais. Este aqui é RECEITA, como o `BANIDOS.txt` e
#   o `FONTES.tsv` — é uma escolha dela que nenhuma máquina refaz sozinha, e as
#   imagens não vão para o git. Some daqui e a decisão morre com a formatação.
LADO_TSV="${WALLPAPER_LADO:-$RAIZ/assets/papeis-de-parede/lado.tsv}"

# nome do arquivo -> dia|noite. Só quem discorda da medição; preenchido por
# `ler_lado`, e vazio quer dizer "ninguém discordou de nada".
declare -A LADO=()

# `|| [ -n "$nome" ]` NO `read` PORQUE A ÚLTIMA LINHA JÁ SUMIU AQUI ANTES
#   É a armadilha 1 que o `semear_da_curadoria` documenta ter pago em 24/08/2026:
#   o `read` devolve status != 0 na última linha quando o arquivo não termina em
#   newline — as variáveis são preenchidas, mas o laço encerra ANTES do corpo. O
#   `gravar_lado` sempre fecha com newline, mas este arquivo é feito para ela
#   abrir e editar à mão, e um editor que não fecha a última linha faria a última
#   escolha dela sumir sem aviso.
#
# LINHA ESTRANHA NÃO VIRA ESCOLHA. Um valor que não seja `dia` nem `noite` é
# ignorado e contado — cair no silêncio faria uma linha malformada valer como
# "auto" sem ninguém saber, e ela procuraria o defeito na medição.
ler_lado() {
  LADO=()
  [ -f "$LADO_TSV" ] || return 0
  local TAB=$'\t' nome escolha estranhas=0
  while IFS="$TAB" read -r nome escolha || [ -n "$nome" ]; do
    case "$nome" in ''|'#'*) continue ;; esac
    case "$escolha" in
      dia|noite) LADO["$nome"]="$escolha" ;;
      *)         estranhas=$((estranhas + 1)) ;;
    esac
  done < "$LADO_TSV"
  [ "$estranhas" -gt 0 ] && \
    meow_aviso "$(basename "$LADO_TSV"): $estranhas linha(s) sem 'dia' nem 'noite' — ignoradas"
  return 0
}

# Escreve o mapa `LADO` inteiro, ordenado por nome, de uma vez.
#
# ATÔMICO, COMO O RESTO DO SCRIPT: arquivo temporário ao lado e `mv`. Quem
# estiver lendo o registro no meio da escrita lê o antigo inteiro, nunca meio
# arquivo — e é o mesmo `.atomicwrite.meow.XXXXXX` que o `cmd_desbanir` usa para
# reescrever o `BANIDOS.txt`, pelo mesmo motivo.
#
# ORDENADO POR `LC_ALL=C sort`, E NÃO PELA ORDEM DO MAPA: a ordem de iteração de
# um array associativo do bash é a da tabela de espalhamento, isto é, arbitrária
# e instável entre execuções. Sem a ordenação, gravar a MESMA escolha duas vezes
# produziria dois arquivos diferentes — e num arquivo versionado isso é um diff
# fantasma a cada passagem.
#
# MAPA VAZIO APAGA O ARQUIVO, e isto é o `auto` levado às últimas consequências:
# "nenhuma discordância" e "arquivo ausente" têm de ser o mesmo estado, senão
# sobra um arquivo de duas linhas de cabeçalho dizendo que existe uma escolha
# onde não existe nenhuma. Este projeto tem histórico documentado de pasta
# fantasma; arquivo fantasma é a mesma doença com outro nome.
gravar_lado() {
  local TAB=$'\t' NL=$'\n' dir tmp conteudo base

  if [ "${#LADO[@]}" -eq 0 ]; then
    [ -f "$LADO_TSV" ] || return 0
    rm -f -- "$LADO_TSV" 2>/dev/null || return 1
    return 0
  fi

  dir="$(dirname "$LADO_TSV")"
  mkdir -p "$dir" 2>/dev/null || return 1
  conteudo="# lado.tsv — de que lado cada papel de parede fica POR ESCOLHA DELA.$NL"
  conteudo="$conteudo# nome-do-arquivo<TAB>dia|noite. Quem não está aqui é separado pela luminância.$NL"
  while IFS= read -r base; do
    conteudo="$conteudo$base$TAB${LADO[$base]}$NL"
  done < <(printf '%s\n' "${!LADO[@]}" | LC_ALL=C sort)

  tmp="$(mktemp -p "$dir" ".atomicwrite.meow.XXXXXX" 2>/dev/null)" || return 1
  if printf '%s' "$conteudo" > "$tmp" 2>/dev/null \
     && chmod 644 "$tmp" 2>/dev/null \
     && mv -f "$tmp" "$LADO_TSV" 2>/dev/null; then
    return 0
  fi
  rm -f "$tmp"
  return 1
}

# Tira do mapa a linha de UM nome. Existe como função porque `unset "LADO[$n]"`
# é armadilha: o bash expande o subscrito de novo dentro do `unset`, e um nome de
# arquivo com `[` ou `]` — que a pasta dela pode ter, ela já tem emoji e espaço —
# apagaria outra chave ou nenhuma, calado. Reconstruir o mapa custa um laço e não
# depende de como o nome é escrito.
_lado_esquecer() {
  local alvo="$1" base
  local -A resto=()
  for base in "${!LADO[@]}"; do
    [ "$base" = "$alvo" ] && continue
    resto["$base"]="${LADO[$base]}"
  done
  LADO=()
  [ "${#resto[@]}" -gt 0 ] || return 0
  for base in "${!resto[@]}"; do LADO["$base"]="${resto[$base]}"; done
  return 0
}

# A HIGIENE: UM REGISTRO QUE SÓ CRESCE VIRA LIXO SILENCIOSO
#   Uma imagem banida (`cmd_banir` a move para `banidos/`) ou apagada à mão sai
#   de `ativos/` e nunca mais volta sozinha. A linha dela, se ficasse, seria uma
#   escolha sobre uma imagem que não existe — e o arquivo cresceria para sempre
#   com nomes que ninguém reconhece mais. Este projeto já pagou por lixo assim
#   em outra pasta; o conserto é podar na mesma passagem em que o sumiço é visto.
#
# É CHAMADA DEPOIS DA GUARDA DE "MENOS DE DUAS IMAGENS" DO `cmd_aplicar`, e a
# ordem é a proteção: `ativos/` vazio (disco desmontado, home ainda não montado
# no boot) NUNCA chega até aqui, então a poda nunca confunde acervo ausente com
# curadoria. É o mesmo cuidado das quatro guardas do `reconciliar_sumicos`,
# aproveitando a que já existe em vez de escrever a quinta.
#
# CONTA COMO DIVERGÊNCIA (devolve 1), ao contrário do `limpar_estado_morto`: uma
# linha morta é uma sobra REAL num arquivo versionado, que não volta ao lugar
# sozinha. Se não contasse, o `--conferir` imprimiria "~~ tiraria …" e devolveria
# 0 — e o auto-reparo nunca passaria ali. Converge na primeira passagem de
# verdade: podado uma vez, o nome não volta.
podar_lado() {
  ler_lado
  [ "${#LADO[@]}" -gt 0 ] || return 0

  local -a mortas=()
  local -A vivas=()
  local base
  for base in "${!LADO[@]}"; do
    if [ -f "$ATIVOS/$base" ]; then
      vivas["$base"]="${LADO[$base]}"
    else
      mortas+=("$base")
    fi
  done
  [ "${#mortas[@]}" = "0" ] && return 0

  if meow_seco; then
    meow_muda "tiraria ${#mortas[@]} linha(s) de $(basename "$LADO_TSV") — não estão mais em ativos/"
    return 1
  fi

  LADO=()
  if [ "${#vivas[@]}" -gt 0 ]; then
    for base in "${!vivas[@]}"; do LADO["$base"]="${vivas[$base]}"; done
  fi
  gravar_lado || { meow_aviso "não consegui podar $LADO_TSV"; return 0; }
  meow_info "${#mortas[@]} escolha(s) de lado saíram de $(basename "$LADO_TSV"): ${mortas[*]}"
  return 1
}

# Decide para qual pasta o `source:` aponta nesta rodada, e deixa o disco pronto
# para isso. DEVOLVE SEMPRE 0: dia e noite é melhoria, e nenhuma falha dela pode
# derrubar o carrossel. O pior caso é voltar para `ativos/` com um aviso.
#
# AS DUAS DERIVADAS SÃO MONTADAS JUNTAS, e não só a da vez. Custam link duro,
# isto é, zero disco — e assim a virada das 18:00 é a reescrita de UMA linha de
# configuração, sem criação de pasta no minuto em que ela está olhando a tela.
# A FIXAÇÃO ENTRA POR CIMA, DEPOIS DE O GRUPO ESTAR RESOLVIDO — e é por isso que
# há um invólucro em vez de um `if` no meio do miolo.
#
#   1. O grupo precisa ser resolvido de qualquer jeito: as pastas `ativos-dia/`
#      e `ativos-noite/` são montadas lá dentro, e o `proximo` precisa da lista
#      do grupo para saber quem vem depois. Pular o miolo quando há fixação
#      deixaria as derivadas envelhecendo enquanto ela navega.
#   2. O miolo tem cinco `return 0` diferentes (acervo vazio, grupo pequeno,
#      falha de montagem…). Enfiar a fixação em cada um seria cinco cópias da
#      mesma regra — o defeito que este projeto mais persegue.
#
# QUEM SOLTA A FIXAÇÃO VENCIDA É AQUI, e só fora do seco: o `--conferir` precisa
# poder dizer "soltaria" sem soltar.
resolver_rotacao() {
  _resolver_grupo || return $?
  local fixo

  # CURADORIA SOLTA A FIXAÇÃO — 01/09/2026, e este é o pedido dela em uma linha:
  # "preciso que vc melhore o projeto nesse sentido", depois de mover oito
  # papéis de parede para `banidos/` e não ver nada mudar na tela.
  #
  # O QUE ACONTECEU, MEDIDO: mover funcionou (saíram de `ativos/` e dos grupos
  # em segundos), mas a tela estava com a imagem FIXADA pelo "avançar papel de
  # parede" do menu da área de trabalho, que fixa por `WALLPAPER_FIXO_TTL`
  # (30 min). Fixação é para segurar uma escolha dela — mas ela ACABOU de fazer
  # outra escolha, e a mais recente vence. Sem isto, o recurso parece quebrado
  # exatamente no momento em que ela está usando o outro recurso.
  #
  # Só quando algo foi de fato banido nesta rodada (`CUROU`), não a cada
  # passagem: soltar a fixação em toda reafirmação do carrossel jogaria fora a
  # escolha dela do nada, que é o defeito oposto e pior.
  if [ "${CUROU:-0}" = "1" ] && [ -f "$FIXADO" ]; then
    if meow_seco; then
      meow_muda "soltaria a fixação — você acabou de banir papel de parede"
    else
      soltar_fixo
      meow_info "curadoria nova: soltei a fixação para o carrossel responder na hora"
    fi
  fi

  if fixo="$(fixo_valido)"; then
    ROTACAO="$fixo"; GRUPO="fixado"
  elif [ -f "$FIXADO" ]; then
    if meow_seco; then
      meow_muda "soltaria a fixação vencida — o carrossel volta"
    else
      soltar_fixo
      meow_info "fixação vencida ($FIXO_TTL) — o carrossel voltou"
    fi
  fi
  return 0
}

_resolver_grupo() {
  ROTACAO="$ATIVOS"; GRUPO=""; NOITE_N=0; DIA_N=0

  [ "$NOITE" = "sim" ] || return 0   # o `sim_ou_nao` já avisou de valor estranho

  local lim; lim="$(milesimos_de "$LIMIAR_LUZ")"
  if [ "$lim" -le 0 ] || [ "$lim" -ge 10000 ]; then
    meow_aviso "WALLPAPER_LIMIAR_LUZ=\"$LIMIAR_LUZ\" fora de 0-1; usando 0.37"
    LIMIAR_LUZ="0.37"; lim=3700
  fi

  medir_acervo
  if [ "${#LUZ[@]}" -eq 0 ]; then
    meow_aviso "nenhum papel de parede medido — a rotação fica em ativos/"
    return 0
  fi

  # A ESCOLHA ESCRITA É CONSULTADA ANTES DE A LUMINÂNCIA SER COMPARADA. A ordem é
  # o recurso inteiro: escolha dela > medição. Tudo o que vem DEPOIS continua
  # igual — o aviso de "o grupo de X ficou com N imagem(ns)" e a queda para
  # `ativos/` valem sobre o resultado JÁ com as escolhas aplicadas, senão uma
  # escolha dela poderia esvaziar um grupo sem que ninguém avisasse.
  ler_lado

  local -a escuros=() claros=()
  local base por_escolha=0

  # O UNIVERSO É O QUE FOI MEDIDO, MAIS O QUE ELA ESCOLHEU E NÃO PÔDE SER MEDIDO
  #   `medir_acervo` deixa de fora a imagem que o ImageMagick recusou (um arquivo
  #   truncado, um formato que ele não abre). Sem esta união, uma escolha escrita
  #   sobre uma dessas seria ignorada em silêncio — e o único caso em que a
  #   decisão dela é a ÚNICA informação disponível é justamente esse.
  #
  #   A união NÃO substitui a guarda de "nenhum papel medido" logo acima, e isso
  #   é deliberado: sem ImageMagick nenhum, `LUZ` fica vazio e a rotação volta
  #   inteira para `ativos/` como sempre voltou. Montar os grupos só com as duas
  #   ou três escolhas escritas tiraria as outras 44 imagens da rotação dela para
  #   obedecer a uma preferência — o oposto do que ela pediu.
  local -A universo=()
  for base in "${!LUZ[@]}"; do universo["$base"]=1; done
  if [ "${#LADO[@]}" -gt 0 ]; then
    for base in "${!LADO[@]}"; do
      [ -n "${universo[$base]:-}" ] && continue
      [ -f "$ATIVOS/$base" ] || continue    # linha morta; a poda tira na passagem certa
      universo["$base"]=1
    done
  fi

  for base in "${!universo[@]}"; do
    case "${LADO[$base]:-}" in
      noite) escuros+=("$base"); por_escolha=$((por_escolha + 1)); continue ;;
      dia)   claros+=("$base");  por_escolha=$((por_escolha + 1)); continue ;;
    esac
    # `:-` porque o universo pode conter um nome que só veio do registro; esse
    # nome sempre sai por um dos dois `continue` acima, e o valor de reserva
    # existe para o `set -u` do topo do arquivo, não para ser usado.
    if [ "$(milesimos_de "${LUZ[$base]:-}")" -lt "$lim" ]
      then escuros+=("$base")
      else claros+=("$base")
    fi
  done
  [ "$por_escolha" -gt 0 ] && \
    meow_debug "$por_escolha papel(is) de parede foram para o grupo por escolha escrita, não pela medição"
  NOITE_N="${#escuros[@]}"; DIA_N="${#claros[@]}"

  local dir
  local -a lista=()
  if e_noite; then
    GRUPO="noite"; dir="$NOITE_DIR"; lista=(${escuros[@]+"${escuros[@]}"})
  else
    GRUPO="dia";   dir="$DIA_DIR";   lista=(${claros[@]+"${claros[@]}"})
  fi

  # Menos de duas imagens não é carrossel — é a mesma regra que o `cmd_aplicar`
  # aplica ao acervo inteiro, aqui aplicada ao grupo. Acontece se ela banir os
  # escuros todos, ou se o limiar for empurrado para uma ponta.
  if [ "${#lista[@]}" -lt 2 ]; then
    meow_aviso "o grupo de $GRUPO ficou com ${#lista[@]} imagem(ns) (limiar $LIMIAR_LUZ) — a rotação fica em ativos/"
    GRUPO=""
    return 0
  fi

  if meow_seco; then
    # AS DUAS, e não só a da vez: o `aplicar` monta as duas juntas, e um seco que
    # anunciasse uma pasta e criasse duas seria a mesma mentira de tempo verbal
    # que este arquivo já documenta ter cometido três vezes.
    [ -d "$NOITE_DIR" ] || meow_muda "criaria $NOITE_DIR/ com $NOITE_N link(s) duro(s) para ativos/"
    [ -d "$DIA_DIR" ]   || meow_muda "criaria $DIA_DIR/ com $DIA_N link(s) duro(s) para ativos/"
    ROTACAO="$dir"
    return 0
  fi

  if montar_derivada "$NOITE_DIR" ${escuros[@]+"${escuros[@]}"} \
     && montar_derivada "$DIA_DIR" ${claros[@]+"${claros[@]}"}; then
    ROTACAO="$dir"
  else
    meow_aviso "não consegui montar as pastas de dia/noite — a rotação fica em ativos/"
    GRUPO=""
  fi
  return 0
}

# A pasta é nossa? Vale para as três: o acervo e as duas derivadas dele.
#
# ISTO É METADE DO PRIMEIRO DOS QUATRO CASOS DA FRONTEIRA, e existe como função
# porque agora são três caminhos e não um. Uma saída apontando para
# `ativos-dia/` às 23h não é reversão nem escolha dela: é a nossa própria pasta,
# do grupo errado, e o conserto é escrever a certa sem aviso nenhum.
fonte_nossa() {
  case "$1" in
    "$ATIVOS"|"$ATIVOS"/*|"$NOITE_DIR"|"$NOITE_DIR"/*|"$DIA_DIR"|"$DIA_DIR"/*) return 0 ;;
  esac
  return 1
}

# ============================================================================
# AVANÇAR E VOLTAR O PAPEL DE PAREDE (01/09/2026)
# ============================================================================
# O PEDIDO DELA: "adicionar no botão direito do mouse, no menu de contexto
# quando eu o aperto na área de trabalho, a opção de avançar wallpaper e voltar
# wallpaper".
#
# O CABEÇALHO DESTE ARQUIVO DIZIA "NÃO EXISTE GATILHO DE PRÓXIMO", E CONTINUA
# CERTO SOBRE O `cosmic-bg`
#   Ele não fala D-Bus: não tem nome no barramento, não tem conexão, e o binário
#   não contém string de D-Bus nenhuma (medido em 04/08/2026). Os fds dele são
#   dois sockets Wayland e um inotify. Não há como pedir "próximo" a ele.
#
# O QUE MUDOU FOI A DESCOBERTA DA ÂNCORA, e ela estava neste mesmo arquivo, 80
# linhas abaixo, sendo usada para outra coisa:
#   `~/.local/state/cosmic/com.system76.CosmicBackground/v1/wallpapers` guarda a
#   imagem que está EM CADA SAÍDA, escrita pelo próprio cosmic-bg:
#       [ ("DP-1", Path("…/ativos-dia/meow-lofi-lofi-j38rp5.jpg")), ]
#   Com isso "próximo" deixa de ser adivinhação: sabe-se onde a rotação está, e
#   dá para escolher quem vem depois na lista ordenada do grupo.
#
# COMO SE MOSTRA UMA IMAGEM ESCOLHIDA: `source: Path(<arquivo>)`
#   O `config_desejada` já escreve `Path("$ROTACAO")`, e o RON aceita arquivo
#   tanto quanto diretório. Então FIXAR é só trocar o valor de `$ROTACAO` — não
#   há um segundo formato de configuração, nem um segundo caminho de escrita, e
#   toda a fronteira de quatro casos do `cmd_aplicar` continua valendo.
#
# O PREÇO, DITO EM VOZ ALTA: COM UMA IMAGEM SÓ, NÃO HÁ ROTAÇÃO
#   Enquanto a fixação vale, o carrossel está parado. Isso é inevitável — o
#   `cosmic-bg` gira o que estiver na PASTA, e uma pasta não tem "posição
#   atual" que se possa empurrar. Fingir o contrário seria pior.
#
# ENTÃO A FIXAÇÃO EXPIRA, e é isso que a torna aceitável
#   `WALLPAPER_FIXO_TTL` (padrão 30m) é quanto tempo a escolha dela dura. Quem
#   devolve o carrossel é o `meow-wallpaper.timer`, que já roda a cada 15 min
#   chamando o `aplicar` — nenhuma unidade nova, nenhum relógio novo. Com `0` a
#   fixação é para sempre, e aí quem a solta é `meow wallpaper carrossel`.
#
#   O TTL é o que separa este recurso de uma armadilha: sem ele, um clique
#   distraído em "avançar" deixaria o carrossel morto por dias, e o sintoma
#   ("o papel de parede parou de girar") não apontaria para o clique.
FIXO_TTL="${WALLPAPER_FIXO_TTL:-30m}"
FIXADO="$MEOW_ESTADO/wallpaper-fixado"
# "Houve curadoria nesta rodada?" — escrita pelas duas reconciliações, lida pelo
# `resolver_rotacao`. Variável e não arquivo: o efeito é desta passagem só.
CUROU=0

# `<caminho><TAB><epoch>` — o caminho para saber o que mostrar, o carimbo para
# saber quando soltar. Duas coisas num arquivo só porque elas nascem e morrem
# juntas: um carimbo sem caminho não diz nada, e um caminho sem carimbo nunca
# expira.
gravar_fixo() { printf '%s\t%s\n' "$1" "$(date +%s)" > "$FIXADO" 2>/dev/null; }
soltar_fixo() { rm -f "$FIXADO" 2>/dev/null; return 0; }

# Imprime o caminho fixado se ele ainda vale; falha (1) se não há fixação, se o
# arquivo sumiu do acervo, ou se o prazo passou. NUNCA apaga nada: quem apaga é
# `resolver_rotacao`, para que o `--conferir` (que roda em seco) possa dizer
# "soltaria a fixação" sem soltá-la.
fixo_valido() {
  local linha caminho quando ttl agora
  [ -f "$FIXADO" ] || return 1
  linha="$(cat "$FIXADO" 2>/dev/null)" || return 1
  caminho="${linha%%	*}"; quando="${linha##*	}"
  [ -n "$caminho" ] && [ -f "$caminho" ] || return 1
  case "$quando" in ''|*[!0-9]*) return 1 ;; esac
  ttl="$(segundos_de "$FIXO_TTL")"
  # `0` (ou qualquer coisa que vire 0) = para sempre. É o mesmo idioma de
  # `LEITURA_RAMPA_MIN=0` e do `rotation_frequency` do COSMIC: zero desliga o
  # relógio, não zera o prazo.
  if [ "$ttl" -gt 0 ]; then
    agora="$(date +%s)"
    [ "$((agora - quando))" -lt "$ttl" ] || return 1
  fi
  printf '%s' "$caminho"
}

# A imagem que o cosmic-bg está mostrando AGORA, lida do estado dele. Só devolve
# caminho que seja NOSSO — uma entrada apontando para `/usr/share/backgrounds`
# (a saída de fábrica, ou um monitor que a fronteira ainda não consertou) não
# serve de âncora para "próximo".
#
# LÊ TODAS AS SAÍDAS E FICA COM A PRIMEIRA NOSSA. Com dois monitores mostrando
# imagens diferentes, "próximo" passa a ser relativo ao primeiro — e não há
# resposta melhor: o `source` é um só por saída, mas o comando é um só.
imagem_atual() {
  local estado="$HOME/.local/state/cosmic/com.system76.CosmicBackground/v1/wallpapers"
  local p
  [ -f "$estado" ] || return 1
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    fonte_nossa "$p" && [ -f "$p" ] && { printf '%s' "$p"; return 0; }
  done < <(grep -oP 'Path\("\K[^"]+' "$estado" 2>/dev/null)
  return 1
}

# As imagens do grupo da vez, em ordem ESTÁVEL (`LC_ALL=C sort`), uma por linha.
#
# A ORDEM É ALFABÉTICA MESMO COM `WALLPAPER_ORDEM="aleatoria"`, e isso é de
# propósito: "aleatória" descreve como o `cosmic-bg` SORTEIA a próxima; aqui é
# preciso uma sequência que seja a MESMA nas duas direções, senão "avançar" e
# "voltar" não se desfariam. Uma lista sorteada faria "voltar" cair em qualquer
# lugar — e o botão prometeria desfazer sem desfazer.
lista_do_grupo() {
  local dir="$1"
  find "$dir" -maxdepth 1 \( -type f -o -type l \) 2>/dev/null | LC_ALL=C sort
}

# --- o estado com caminho fantasma, que suja o journal a cada 5 minutos -------
# `~/.local/state/cosmic/.../v1/wallpapers` é a memória do COSMIC de qual imagem
# estava em cada saída. Não é configuração: é estado, escrito por ele.
#
# O PROBLEMA MEDIDO (2026-08-04, 23:40 em diante)
#   O arquivo guardava três entradas, e DUAS apontavam para arquivo que não existe
#   mais — uma imagem banida da pasta `ativos/` e uma pasta `meowsystem-teste/`
#   apagada há tempo. O `cosmic-greeter` lê este estado e cospe no journal, a cada
#   cinco minutos, para sempre:
#       failed to read wallpaper ".../meowsystem-teste/c-rosa.png": NotFound
#   Não é fatal — mas é a tela de bloqueio dela tentando desenhar um arquivo
#   fantasma, e é ruído que esconde erro de verdade no journal.
#
# SÓ REMOVE O QUE NÃO EXISTE, E NADA MAIS
#   Uma entrada com arquivo presente fica intocada, mesmo apontando para fora da
#   pasta do carrossel: pode ser escolha dela para uma saída específica.
#
# E SÓ VALE NO PRÓXIMO LOGIN — medido, não suposto (2026-08-05)
#   Limpamos a entrada morta, e dois segundos depois ela estava de volta no
#   arquivo. O `cosmic-bg` não relê este estado: ele carrega a lista na MEMÓRIA
#   no início da sessão e reescreve o arquivo INTEIRO a cada troca de imagem —
#   a cada 5 minutos, aqui. Ou seja, enquanto a sessão viver, a entrada fantasma
#   volta; no próximo login ele lê o arquivo já limpo e ela some de vez.
#
#   Por isso o chamador NÃO conta esta limpeza como divergência. Se contasse, o
#   `meow doctor` acusaria diferença a cada rodada para sempre, e o auto-reparo
#   "consertaria" de hora em hora algo que o COSMIC desfaz em cinco minutos —
#   o mesmo ping-pong que o projeto já teve com a Aurora e resolveu cedendo.
ESTADO_BG="$HOME/.local/state/cosmic/com.system76.CosmicBackground/v1/wallpapers"

limpar_estado_morto() {
  [ -f "$ESTADO_BG" ] || return 1

  # SÓ QUANDO NÃO HÁ DONO VIVO — o cabeçalho acima já explica o porquê, e agora
  # o código respeita o que ele diz. Medido em 10/08/2026: `stat` deste arquivo
  # deu 16:33 e depois 16:38:12 — cinco minutos exatos, batendo com o
  # `rotation_frequency: 300` de `output.DP-1`. O `cosmic-bg` reescreve o
  # arquivo INTEIRO nesse ritmo, a partir da lista que carregou na memória.
  # Gravar por cima enquanto ele vive é apostar contra o dono do arquivo: ou a
  # nossa escrita some no próximo tique, ou ela apaga a rotação em curso. E
  # como a limpeza só vale no login seguinte de qualquer jeito, esperar não
  # custa nada — o ganho de escrever agora é zero.
  if pgrep -x cosmic-bg >/dev/null 2>&1; then
    meow_debug "cosmic-bg de pé — a limpeza do estado fica para uma sessão em que ele não esteja"
    return 1
  fi

  local novo mortas saida
  # UMA LEITURA SÓ, E NÃO DUAS. Antes eram duas invocações separadas de
  # `python3` que reabriam o arquivo em momentos diferentes; com o `cosmic-bg`
  # reescrevendo no meio, a contagem da segunda podia discordar do conteúdo que
  # a primeira produziu — e a frase do `meow_info` mentiria sobre o que foi
  # feito. A primeira linha da saída é a contagem, o resto é o conteúdo novo.
  saida="$(python3 - "$ESTADO_BG" <<'FIM' 2>/dev/null
import os, re, sys
texto = open(sys.argv[1], encoding="utf-8").read()
# ("DP-1", Path("/caminho")),  — uma entrada por linha, é o formato que ele grava.
padrao = re.compile(r'^\s*\(\s*"[^"]*"\s*,\s*Path\("([^"]*)"\)\s*\)\s*,?\s*$')
guardar, mortas = [], 0
for linha in texto.splitlines():
    m = padrao.match(linha)
    if m and not os.path.exists(m.group(1)):
        mortas += 1
        continue
    guardar.append(linha)
if not mortas:
    sys.exit(1)          # nada a fazer: o chamador trata como "já limpo"
print(mortas)
print("\n".join(guardar))
FIM
)" || return 1
  mortas="${saida%%$'\n'*}"
  # `$( )` come as newlines do fim: se sobrasse conteúdo NENHUM depois da poda,
  # a saída seria só a contagem, sem newline alguma — e `${saida#*$'\n'}`, que
  # devolve a string intacta quando não acha o padrão, entregaria o número como
  # se fosse o arquivo novo. Não deve acontecer (o arquivo tem os parênteses de
  # abertura e fecho, que não casam com o padrão de entrada), mas o custo de
  # não escrever lixo no estado do COSMIC é uma linha.
  case "$saida" in
    *$'\n'*) novo="${saida#*$'\n'}" ;;
    *)       novo="" ;;
  esac
  if meow_seco; then
    meow_muda "removeria $mortas caminho(s) fantasma do estado do papel de parede"
    return 0
  fi
  meow_escrever "$ESTADO_BG" "$novo" 644
  case $? in
    1) meow_info "$mortas caminho(s) fantasma removidos do estado (o greeter reclamava deles)"
       return 0 ;;
    *) return 1 ;;
  esac
}

# ============================================================================
# APAGAR À MÃO PASSA A SER BANIR (01/09/2026)
# ============================================================================
# O QUE ELA DESCOBRIU, E TINHA RAZÃO
#   Ela apagou papéis de parede feios e nada aconteceu — porque apagou da pasta
#   ERRADA (`assets/papeis-de-parede/`, que era 145 MB de cópia inerte que
#   nenhum script lia; as imagens saíram do repositório no mesmo dia). Mas ao
#   perguntar "essa pasta então não é usada?" ela expôs um buraco de verdade no
#   lado CERTO:
#
#     `meow wallpaper banir X`  -> move para banidos/ E grava no BANIDOS.txt.
#                                  PERMANENTE.
#     apagar X à mão de ativos/ -> sai da rotação agora, e o `semear` traz de
#                                  volta na próxima vez. TEMPORÁRIO, sem avisar.
#
#   Duas ações que parecem a mesma coisa e não são. E o README promete o
#   contrário desde sempre: *"a pasta é a configuração: soltou o arquivo,
#   entrou; apagou, saiu"* — verdade para `assets/gatos/`, mentira aqui.
#
# O QUE ESTA FUNÇÃO FAZ
#   Guarda a lista de nomes que estavam em `ativos/` na passagem anterior. Na
#   seguinte, o que sumiu entra no `BANIDOS.txt` sozinho. A decisão dela virou
#   uma linha: *"sempre que apagar o script se auto corrige"*.
#
# AS QUATRO GUARDAS — sem elas isto apaga o acervo dela algum dia
#   1. PRIMEIRA PASSAGEM NÃO BANE NADA. Sem lista anterior não há "sumiu": só
#      se grava o retrato e volta. Senão, a primeira execução numa máquina nova
#      baniria o acervo inteiro.
#   2. PASTA VAZIA NÃO BANE NADA. `ativos/` vazio é disco desmontado, `mv`
#      interrompido, home ainda não montado no boot — nunca "ela apagou 54
#      imagens". Avisa e NÃO atualiza o retrato, para o próximo ciclo reconhecer
#      o estado bom.
#   3. SUMIÇO EM MASSA NÃO BANE NADA. Mais da metade fora de uma vez é evento,
#      não curadoria. Mesmo tratamento: avisa e segura o retrato.
#   4. QUEM JÁ ESTÁ BANIDO NÃO É BANIDO DE NOVO. O `cmd_banir` também faz o
#      arquivo sumir de `ativos/`; sem este teste ele apareceria aqui como
#      "sumiço" e a lista ganharia linha duplicada a cada banimento.
#
# EM SECO NÃO ESCREVE NADA, e é por isso que o retrato só é gravado no fim: um
# `--conferir` que atualizasse a lista faria o sumiço ser esquecido sem nunca
# ter sido banido.
VISTAS="$MEOW_ESTADO/wallpaper-vistas.txt"

reconciliar_sumicos() {
  local -a agora=() sumidas=()
  local nome n_antes n_agora

  mapfile -t agora < <(find "$ATIVOS" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | LC_ALL=C sort)
  n_agora="${#agora[@]}"

  if [ ! -f "$VISTAS" ]; then
    meow_seco || printf '%s\n' ${agora[@]+"${agora[@]}"} > "$VISTAS" 2>/dev/null
    return 0                                   # guarda 1
  fi
  n_antes="$(grep -c . "$VISTAS" 2>/dev/null || echo 0)"

  if [ "$n_agora" = "0" ] && [ "$n_antes" -gt 0 ]; then
    meow_aviso "ativos/ está VAZIO e tinha $n_antes imagem(ns) — não vou banir nada"
    meow_info  "  isso é disco desmontado ou home ainda não montado, não curadoria"
    return 0                                   # guarda 2
  fi

  mapfile -t sumidas < <(comm -23 <(LC_ALL=C sort -u "$VISTAS") <(printf '%s\n' ${agora[@]+"${agora[@]}"}))
  [ "${#sumidas[@]}" = "0" ] && { meow_seco || printf '%s\n' ${agora[@]+"${agora[@]}"} > "$VISTAS" 2>/dev/null; return 0; }

  if [ "$n_antes" -gt 4 ] && [ "${#sumidas[@]}" -gt $(( n_antes / 2 )) ]; then
    meow_aviso "${#sumidas[@]} de $n_antes imagens sumiram de ativos/ de uma vez — não vou banir nada"
    meow_info  "  se foi você mesma, bana uma a uma: meow wallpaper banir <nome>"
    return 0                                   # guarda 3
  fi

  # GUARDA 4 — SÓ O TEXTO CONTA AQUI, E ISSO É UM CONSERTO DE 01/09/2026
  #   Ela moveu 8 imagens de `ativos/` para `banidos/` pelo gerenciador de
  #   arquivos, às 20:58. O vigia acordou, os grupos de dia e de noite foram
  #   refeitos, e o carrossel parou de mostrá-las — tudo certo na tela. Mas o
  #   `BANIDOS.txt` continuou o de 17:57: NENHUM dos 8 nomes entrou.
  #
  #   A causa era esta linha chamando `esta_banida`, que responde 0 tanto para
  #   "está no BANIDOS.txt" quanto para "existe um arquivo com esse nome em
  #   `banidos/`". Movendo o arquivo, a segunda metade passa a valer ANTES de a
  #   primeira ser escrita: cada nome era pulado como se já estivesse
  #   registrado, e o retrato era atualizado por cima.
  #
  #   POR QUE ISSO IMPORTA, JÁ QUE NA TELA FUNCIONOU: as imagens não vão para o
  #   git — só as receitas vão. Numa máquina reformatada, `banidos/` nasce
  #   VAZIA, e aí o único que sabe o que ela recusou é o `BANIDOS.txt`. Sem o
  #   nome lá, o `semear` repõe a imagem que ela tirou. É o mesmo buraco que o
  #   auto-banir veio tapar em 01/09, na variante "mover" em vez de "apagar" —
  #   e ele passou despercebido porque as duas ações parecem a mesma.
  #
  #   Então: a guarda contra escrever duas vezes é o TEXTO, e só ele.
  local -a novas=()
  for nome in "${sumidas[@]}"; do
    [ -f "$BANIDOS_TXT" ] && grep -qxF -- "$nome" "$BANIDOS_TXT" && continue
    novas+=("$nome")
  done
  [ "${#novas[@]}" = "0" ] && { meow_seco || printf '%s\n' ${agora[@]+"${agora[@]}"} > "$VISTAS" 2>/dev/null; return 0; }

  if meow_seco; then
    meow_muda "baniria ${#novas[@]} imagem(ns) apagada(s) à mão: ${novas[*]}"
    return 1
  fi

  mkdir -p "$(dirname "$BANIDOS_TXT")" 2>/dev/null
  [ -f "$BANIDOS_TXT" ] || printf '%s\n' \
    "# BANIDOS.txt — os papéis de parede que ela recusou, por nome de arquivo." \
    "# O 'semear' não repõe nada que esteja aqui." > "$BANIDOS_TXT"
  for nome in "${novas[@]}"; do
    grep -qxF -- "$nome" "$BANIDOS_TXT" || printf '%s\n' "$nome" >> "$BANIDOS_TXT"
  done
  meow_ok "${#novas[@]} imagem(ns) apagada(s) à mão entraram no BANIDOS.txt — o semear não as repõe"
  meow_info "  ${novas[*]}"
  meow_registrar "wallpaper.sh auto-banir: ${novas[*]}"
  printf '%s\n' ${agora[@]+"${agora[@]}"} > "$VISTAS" 2>/dev/null
  CUROU=1
  return 1
}

# ============================================================================
# ARRASTAR PARA `banidos/` É BANIR — 01/09/2026
# ============================================================================
# Pergunta dela, com a coisa já feita: "remover os papeis de parede de ativos
# automaticamente corrige os papeis de parede disponivel? pq movi pra pasta dos
# que eu não quero mas não vi mudando isso."
#
# Ela tinha movido 8 imagens de `ativos/` para `banidos/` pelo gerenciador de
# arquivos. Medido no mesmo minuto: na TELA funcionou (o vigia acordou, os
# grupos de dia e noite foram refeitos, o carrossel parou de sorteá-las), mas o
# `BANIDOS.txt` continuou o de três horas antes — nenhum dos 8 nomes registrado.
# A causa está comentada na guarda 4 do `reconciliar_sumicos`.
#
# ISTO AQUI É A OUTRA METADE, e vale para o passado também: qualquer arquivo que
# esteja em `banidos/` e não esteja no `BANIDOS.txt` é uma recusa dela que o
# repositório não sabe repetir. Na primeira passagem depois deste conserto eram
# 121 — anos de curadoria que uma máquina reformatada teria desfeito, porque as
# imagens não vão para o git e `banidos/` nasceria vazia lá.
#
# É a mesma regra do resto do projeto: a PASTA é a interface, e o texto é a
# receita. Ela arrasta; nós registramos.
reconciliar_banidos_pasta() {
  [ -d "$BASE/banidos" ] || return 0
  local -a novas=()
  local nome
  while IFS= read -r nome; do
    [ -n "$nome" ] || continue
    [ -f "$BANIDOS_TXT" ] && grep -qxF -- "$nome" "$BANIDOS_TXT" && continue
    # NOME COM EMOJI NAO ENTRA NO TEXTO — e isto e uma regra do repositorio, nao
    # capricho: o ADR-011 dela proibe emoji nos arquivos versionados, e o
    # `universal-sanitizer.py` do pre-commit REMOVE o caractere em vez de
    # recusar o commit. Medido em 01/09/2026, ao commitar: a linha
    # "Cyberpunk Neon Cat Wallpaper _ Synthwave Vibe <gato><coracao>.jpeg" virou
    # a mesma frase SEM os dois emojis — e um nome sem os emojis nao casa com
    # arquivo nenhum, entao a linha deixava de banir o que dizia banir, calada.
    #
    # Registrar aqui criaria ping-pong: nos escrevemos, o hook apaga o emoji, e
    # na rodada seguinte o nome "falta" de novo. Fica de fora, e a protecao
    # daquela imagem continua sendo a PASTA `banidos/` — que e onde ela ja
    # estava. O aviso sai uma vez por rodada, para ninguem procurar o defeito.
    if printf '%s' "$nome" | grep -qP '[\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE0F}]' 2>/dev/null; then
      meow_debug "banidos: '$nome' tem emoji no nome e nao entra no BANIDOS.txt (ADR-011)"
      continue
    fi
    novas+=("$nome")
  done < <(find "$BASE/banidos" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | LC_ALL=C sort)

  [ "${#novas[@]}" = "0" ] && return 0

  if meow_seco; then
    meow_muda "registraria ${#novas[@]} imagem(ns) que estão em banidos/ e não no BANIDOS.txt"
    return 1
  fi

  mkdir -p "$(dirname "$BANIDOS_TXT")" 2>/dev/null
  [ -f "$BANIDOS_TXT" ] || printf '%s\n' \
    "# BANIDOS.txt — os papéis de parede que ela recusou, por nome de arquivo." \
    "# O 'semear' não repõe nada que esteja aqui." > "$BANIDOS_TXT"
  for nome in "${novas[@]}"; do
    printf '%s\n' "$nome" >> "$BANIDOS_TXT"
  done
  meow_ok "${#novas[@]} imagem(ns) de banidos/ entraram no BANIDOS.txt — a recusa agora sobrevive a uma reinstalação"
  meow_registrar "wallpaper.sh registrar-banidos: ${#novas[@]}"
  CUROU=1
  return 1
}

cmd_aplicar() {
  criar_pastas || { meow_erro "não consegui criar as pastas"; return "$MEOW_ERRO"; }
  # ANTES do `semear_das_dela`, e a ordem não é detalhe: aquele copia imagens
  # das pastas dela para `ativos/`. Rodar depois faria uma imagem recém-copiada
  # contar como "nova" no retrato e — pior — uma que ela apagou de `ativos/` mas
  # que ainda existe na pasta de origem voltaria ANTES de ser reconhecida como
  # sumida, e o banimento nunca aconteceria.
  reconciliar_sumicos
  # DEPOIS do `reconciliar_sumicos` e ANTES do `semear_das_dela`: o primeiro é
  # quem transforma "sumiu de ativos/" em linha de texto; este varre a pasta
  # inteira e pega o que chegou lá por qualquer outro caminho (o gerenciador de
  # arquivos dela, um `mv` no terminal, uma versão anterior deste script). E
  # tem de vir antes de semear, senão a imagem volta para `ativos/` na mesma
  # rodada em que seria registrada.
  reconciliar_banidos_pasta
  semear_das_dela

  local n; n="$(quantas)"
  if [ "$n" -lt 2 ]; then
    meow_aviso "só $n imagem(ns) em $ATIVOS — o carrossel precisa de 2 ou mais"
    meow_info "adicione com: meow wallpaper adicionar <arquivo|pasta>"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local mudou=0

  # A PODA DO REGISTRO DE LADO VEM AQUI, e o lugar é a proteção: o `return` de
  # "menos de duas imagens", logo acima, já garantiu que `ativos/` não está vazio
  # nem inacessível. Uma imagem banida neste mesmo comando (o `cmd_banir` chama
  # este `aplicar` no fim) já saiu de `ativos/` quando a poda passa, então a linha
  # dela cai na MESMA passagem em que o banimento acontece — que é o contrato.
  #
  # ANTES do `resolver_rotacao`, para que o grupo seja montado a partir do
  # registro já limpo em vez de um com nome morto dentro.
  podar_lado || mudou=1     # 1 = podou (ou podaria, em seco): é divergência

  # DIA E NOITE VÊM ANTES DA CONFIGURAÇÃO, porque é isto que decide o `source:`.
  # Não devolve erro nunca: se a separação não der certo, `$ROTACAO` continua
  # valendo `ativos/` e o carrossel gira como girava antes de 25/08/2026.
  resolver_rotacao

  local desejada; desejada="$(config_desejada)"

  # `same-on-all` PASSOU A SER NOSSO EM 08/08/2026 — E É ELA QUE DECIDE TUDO
  #   O comentário que estava aqui dizia "`all` é o que vale (same-on-all está
  #   ligado)". Era falso desde 06/08 15:48:02, e o preço apareceu na tela dela:
  #   com `same-on-all: false`, quem manda é o `output.<saída>`, e o `all` — o
  #   arquivo que este script escreve e que o `estado` lia — fica INERTE.
  #
  #   Medido em 08/08, no estado vivo do cosmic-bg: a TV dela girava as imagens
  #   da NASA de `/usr/share/backgrounds` de 5 em 5 minutos, em ordem alfabética,
  #   enquanto o `all` apontava para o acervo dela e o `estado` respondia
  #   "carrossel ATIVO". Duas escritas soltas no `output.DP-1` em 48 h, e o
  #   conserto só passava às 5h — uma delas ficou 38 h no ar.
  #
  #   ESTE SCRIPT NÃO ESCREVE `same-on-all`, E ISSO FOI MEDIDO, NÃO SUPOSTO.
  #   A saída óbvia parecia ser gravar `true` e deixar só o `all` mandar. Foi
  #   tentado em 08/08/2026 e o TESTE REFUTOU: com `same-on-all` valendo `true`
  #   no disco, um `output.DP-1` apontando para `/usr/share/backgrounds` levou a
  #   tela de volta para as imagens da NASA em menos de 20 s. O `cosmic-bg`
  #   continuou obedecendo o arquivo da saída.
  #
  #   Duas leituras sobram, e nenhuma está provada: ou a chave é lida uma vez, no
  #   início da sessão (ele subiu às 00:02 lendo `false`), ou ela não governa
  #   precedência nenhuma. Separar as duas exige medir depois de um login novo —
  #   até lá, escrever a chave seria impor um valor da GUI dela apostando num
  #   efeito que ninguém demonstrou.
  #
  #   O que continua valendo é o de sempre: escrever TODO `output.*` que existe,
  #   porque é neles que o cosmic-bg obedece — provado pelo mesmo teste.
  #
  # A LISTA DE SAÍDAS SAI DO DISCO, NÃO DE UMA LISTA CRAVADA — e isto custou a
  # tela dela ficar PRETA. A versão anterior tratava `DP-1` e `HDMI-A-1` porque
  # eram as duas saídas conhecidas em 04/08/2026. O problema não é a saída que
  # desaparece (essa é ignorada de graça): é a que APARECE. Quando o COSMIC cria
  # um `output.<nome>` novo — monitor novo, TV ligada na outra entrada, nome que
  # mudou de `DP-1` para `DP-2` depois de um reboot — o arquivo não estava na
  # lista, ninguém escrevia nele, e aquela tela caía no papel de parede de
  # fábrica sem nenhum aviso.
  #
  # Agora vale o que existe: `all` sempre, mais TODO `output.*` já presente no
  # diretório, mais toda saída nomeada em `backgrounds` (a lista viva do COSMIC),
  # mesmo que o arquivo dela ainda não exista. É essa última que cobre o monitor
  # recém-chegado.
  local -a alvos=(all)
  local f
  for f in "$BG"/output.*; do
    [ -f "$f" ] || continue
    alvos+=("$(basename "$f")")
  done
  # `backgrounds` é um array RON de nomes de saída, um por linha:
  #     [
  #         "DP-1",
  #     ]
  # O padrão ancora no COMEÇO da linha de propósito. Sem a âncora, o `grep -o`
  # trata a aspa de FECHAMENTO como abertura da próxima ocorrência e devolve a
  # vírgula e o colchete como se fossem nomes de saída — o teste em seco chegou a
  # anunciar que criaria um arquivo chamado `output.,`.
  # Um nome só entra se ainda não estiver na lista: senão a mesma saída seria
  # escrita duas vezes.
  if [ -f "$BG/backgrounds" ]; then
    while IFS= read -r saida; do
      [ -n "$saida" ] || continue
      case " ${alvos[*]} " in *" output.$saida "*) continue ;; esac
      alvos+=("output.$saida")
    done < <(grep -oP '^\s*"\K[^"]+' "$BG/backgrounds" 2>/dev/null)
  fi

  # A FRONTEIRA: QUATRO CASOS, E O QUARTO NASCEU DE UM DEFEITO MEDIDO
  #   Medido em 07/08 e 08/08/2026: algum processo do COSMIC reescreveu o
  #   `output.DP-1` apontando para `/usr/share/backgrounds` — a pasta de fábrica
  #   —, com TODOS os campos no default do construtor (`Zoom`, `Alphanumeric`,
  #   `rotation_frequency: 300`). Quem mexe num controle da GUI não produz isso:
  #   carrega os valores anteriores. É reset programático, não escolha.
  #
  #   Reverter tudo cegamente seria o defeito que o `aplicar_tema.sh` já
  #   documenta ter custado caro (§ "os dois slideres de vidro fosco são dela"):
  #   fotografar uma preferência e passar a impô-la todo dia. Então a regra é a
  #   mesma daquele arquivo, aplicada por saída:
  #
  #     aponta para o nosso acervo        -> confere, nada a fazer
  #     aponta para a pasta de FÁBRICA    -> é o reset; conserta (código 1)
  #     aponta para a WALLPAPER_FONTES_DELA -> é ela; não se toca (código 4)
  #     aponta para QUALQUER outro lugar  -> é reversão; conserta (código 1)
  #
  #   O TERCEIRO CASO ERA "QUALQUER OUTRO LUGAR" ATÉ 11/08/2026, E ISSO CUSTOU O
  #   CARROSSEL INTEIRO. Nesta máquina o `output.DP-1` voltou a apontar para
  #   `~/Imagens/Parede_papel/Cyberpunk Neon Cat…jpeg` — a pasta onde o papel de
  #   parede dela morava ANTES do MeowSystem. Não é `/usr/share/backgrounds`,
  #   então caía no "é ela" e o script se calava: o `meow-wallpaper.timer` rodou
  #   a cada 15 minutos devolvendo `status=4`, e o carrossel nunca voltou. A
  #   frase dela foi "o papel de parede voltou a ser o antigo também. novamente"
  #   — ou seja, ela não tinha escolhido nada.
  #
  #   A fronteira sabia distinguir fábrica de não-fábrica; não sabia distinguir
  #   "escolha dela de agora" de "onde o wallpaper dela estava antes". E não há
  #   como ler essa diferença do disco: o COSMIC grava o MESMO arquivo nos dois
  #   casos, e não existe carimbo de quem escreveu. Então a decisão passou a ser
  #   DITA uma vez, em vez de adivinhada toda vez — é a `WALLPAPER_FONTES_DELA`,
  #   preenchida por `meow wallpaper permitir <caminho>`.
  #
  #   O que este script NÃO faz: adivinhar. Quando conserta, ele diz no log qual
  #   caminho substituiu e imprime o comando exato que o autoriza. Se a reversão
  #   era escolha dela, ela desfaz com uma linha — e o timer nunca mais mexe
  #   naquele caminho.
  local FABRICA="/usr/share/backgrounds"
  local alvo escolha_dela=0 fonte_atual
  for alvo in "${alvos[@]}"; do
    local conteudo="$desejada"
    [ "$alvo" = "all" ] || conteudo="${desejada/output: \"all\"/output: \"${alvo#output.}\"}"

    if [ -f "$BG/$alvo" ]; then
      fonte_atual="$(grep -oP 'source: Path\("\K[^"]+' "$BG/$alvo" 2>/dev/null)"
      case "$fonte_atual" in
        # É nosso (ou ilegível): segue. As duas pastas derivadas entram aqui
        # desde 25/08/2026 — uma saída apontando para `ativos-dia/` às 23h não é
        # reversão nem escolha dela, é a nossa própria pasta do grupo errado, e
        # o conserto é escrever a certa sem aviso nenhum. Ver `fonte_nossa`.
        "$ATIVOS"|"$ATIVOS"/*|"$NOITE_DIR"|"$NOITE_DIR"/*|"$DIA_DIR"|"$DIA_DIR"/*|"") ;;
        "$FABRICA"|"$FABRICA"/*) ;;                   # reset de fábrica: conserta
        *)
          if fonte_autorizada "$fonte_atual"; then
            meow_pula "$alvo aponta para $fonte_atual — está na WALLPAPER_FONTES_DELA, não mexo"
            escolha_dela=1
            continue
          fi
          # Reversão. Dizer QUAL caminho saiu é o que impede este conserto de
          # ser mágico: sem o caminho no log, um papel de parede que ela tinha
          # posto de propósito sumiria sem deixar como voltar.
          meow_aviso "$alvo apontava para $fonte_atual — isso não é o carrossel; devolvendo"
          meow_info "era escolha sua? autorize e eu paro de mexer:"
          meow_info "  meow wallpaper permitir \"$fonte_atual\""
          ;;
      esac
    fi

    meow_escrever "$BG/$alvo" "$conteudo" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao escrever $alvo"; return "$MEOW_ERRO" ;; esac
  done

  # DESLIGAR TEM DE DESLIGAR, E A ORDEM É O CUIDADO: as pastas derivadas só saem
  # DEPOIS de a configuração acima já ter voltado para `ativos/`. Apagar antes
  # deixaria o `cosmic-bg` apontando para uma pasta que não existe mais.
  #
  # Conta como divergência (ao contrário da limpeza logo abaixo) porque é uma
  # sobra REAL no disco dela, que não volta sozinha: sem isto, `--conferir`
  # imprimiria "removeria …" e devolveria 0, e o auto-reparo nunca passaria ali.
  [ "$NOITE" = "sim" ] || { soltar_derivadas && mudou=1; }

  # A limpeza do estado NÃO conta como divergência — ver o cabeçalho de
  # `limpar_estado_morto`. Contá-la faria o `meow doctor` acusar diferença a cada
  # rodada, para sempre, porque o cosmic-bg reescreve o arquivo a cada troca de
  # imagem (5 min) a partir da lista que ele carregou na MEMÓRIA no início da
  # sessão. É o mesmo ping-pong que o projeto já evitou com a Aurora.
  limpar_estado_morto || true

  # O QUE ELA LÊ NO FIM TEM DE DIZER QUANTAS ESTÃO DE FATO GIRANDO. Com a noite
  # ligada, "54 imagens" seria mentira: giram 32 ou 22, conforme a hora.
  local resumo="$n imagens"
  if [ -n "$GRUPO" ]; then
    local n_grupo="$DIA_N"
    [ "$GRUPO" = "noite" ] && n_grupo="$NOITE_N"
    resumo="$n_grupo de $n imagens (grupo de $GRUPO)"
  fi

  if [ "$mudou" = "0" ]; then
    # 4 = divergente POR ESCOLHA DELA. Sai do laço de conserto sem sair do
    # relatório, e o `meow-doctor.service` não notifica — senão ela receberia
    # "o auto-reparo consertou" toda madrugada por uma pasta que ela escolheu.
    if [ "$escolha_dela" = "1" ]; then
      meow_info "o carrossel está no lugar; a saída acima é escolha sua"
      return 4
    fi
    meow_ok "carrossel já configurado ($resumo, a cada $INTERVALO, $ORDEM)"
    return "$MEOW_OK"
  fi
  meow_seco && return "$MEOW_DIVERGENTE"
  meow_ok "carrossel ligado: $resumo, troca a cada $INTERVALO ($ORDEM)"
  return "$MEOW_DIVERGENTE"
}

cmd_estado() {
  local n; n="$(quantas)"
  local alvo="$ATIVOS"
  echo "pasta:     $ATIVOS"
  echo "imagens:   $n"
  echo "intervalo: $INTERVALO ($(segundos_de "$INTERVALO")s)"
  echo "ordem:     $ORDEM ($(metodo_de "$ORDEM"))"

  # DIA E NOITE, LIDOS DO DISCO. Este comando é DIAGNÓSTICO: não mede imagem,
  # não cria pasta e não escreve nada — o `bin/meow` o chama em seco para montar
  # o painel do `meow estado`, e um diagnóstico que gasta 4 s de ImageMagick, ou
  # que cria pasta para poder responder, é um diagnóstico que muda o que mede.
  # Por isso a contagem sai dos links que EXISTEM, e não de uma classificação
  # recalculada aqui.
  case "$NOITE" in
    sim)
      local agora escuras claras
      escuras="$(quantas_em "$NOITE_DIR")"; claras="$(quantas_em "$DIA_DIR")"
      if e_noite 2>/dev/null; then agora="NOITE"; alvo="$NOITE_DIR"
      else                         agora="DIA";   alvo="$DIA_DIR"; fi
      echo "noite:     ligada, das $NOITE_INICIO às $NOITE_FIM — agora é $agora"

      # QUANTAS ESTÃO EM CADA LADO POR ESCOLHA, E QUANTAS POR MEDIÇÃO. Sem esta
      # conta a linha do limiar convida ao erro que a escolha escrita veio
      # resolver: ela olharia "25 escuras | 21 claras", acharia que o número
      # 0,37 respondeu por todas, e passaria a mexer no limiar para consertar
      # uma imagem que já está onde ela mandou. E é uma conta BARATA — ler um
      # arquivo de texto de duas ou três linhas —, o que importa porque este
      # comando é diagnóstico e não pode medir imagem (ver o comentário acima).
      #
      # A contagem por escolha só vale para quem ainda está em `ativos/`: uma
      # linha morta seria contada como escolha em vigor até a próxima poda.
      #
      # "por medição" é subtração, e não uma classificação refeita aqui, pelo
      # mesmo motivo de sempre: recalcular custaria os 4 s de ImageMagick que
      # este comando promete não gastar. O piso em zero cobre o instante em que
      # as pastas derivadas estão mais velhas que o registro (uma escolha nova,
      # antes do primeiro `aplicar`) — melhor um zero do que um número negativo.
      ler_lado
      local esc_dia=0 esc_noite=0 nome_l por_medicao
      # `"${!LADO[@]}"` DIRETO, e não o `${arr[@]+"${arr[@]}"}` que este arquivo
      # usa com array indexado: com o `!` na frente aquele contorno não é a
      # expansão das CHAVES, é expansão INDIRETA — o bash tenta usar o valor
      # como nome de variável e morre com "nome de variável inválido". Medido
      # aqui em 06/09/2026, e o defeito era mudo: o erro ia para a saída de erro,
      # que o `bin/meow` descarta ao montar o painel do `meow estado`, e a conta
      # simplesmente dava zero. A guarda de tamanho faz o mesmo serviço sem
      # depender de bash 4.4 para expandir array associativo vazio sob `set -u`.
      if [ "${#LADO[@]}" -gt 0 ]; then
        for nome_l in "${!LADO[@]}"; do
          [ -f "$ATIVOS/$nome_l" ] || continue
          case "${LADO[$nome_l]}" in
            dia)   esc_dia=$((esc_dia + 1)) ;;
            noite) esc_noite=$((esc_noite + 1)) ;;
          esac
        done
      fi
      por_medicao=$(( escuras + claras - esc_dia - esc_noite ))
      [ "$por_medicao" -lt 0 ] && por_medicao=0
      echo "limiar:    $LIMIAR_LUZ de luminância ($escuras escuras | $claras claras, contadas no disco; escolha sua: $esc_noite noite | $esc_dia dia · medição: $por_medicao)"
      if [ -d "$alvo" ]; then
        echo "rotação:   $alvo"
      else
        echo "rotação:   $ATIVOS (as pastas derivadas ainda não existem — rode: meow wallpaper aplicar)"
        alvo="$ATIVOS"
      fi
      ;;
    *)
      echo "noite:     desligada (WALLPAPER_NOITE=\"$NOITE\") — a rotação é o acervo inteiro" ;;
  esac
  # CONFERE O ARQUIVO QUE MANDA, NÃO O `all` — ignorar isto já fez este comando
  # MENTIR. Em 08/08/2026 ele respondia "carrossel ATIVO" lendo o `all` enquanto
  # a tela dela exibia o papel de parede de fábrica: `same-on-all` era `false`,
  # e quem valia era o `output.DP-1`. O projeto agora é dono da chave e a escreve
  # como `true`, mas o diagnóstico continua perguntando ao disco quem manda —
  # senão volta a mentir no dia em que alguma coisa a mudar de novo.
  local mesma; mesma="$(cat "$BG/same-on-all" 2>/dev/null)"
  local -a mandam=()
  if [ "$mesma" = "false" ]; then
    local f
    for f in "$BG"/output.*; do [ -f "$f" ] && mandam+=("$f"); done
  fi
  [ "${#mandam[@]}" -gt 0 ] || mandam=("$BG/all")

  local fora=0 fonte arq
  for arq in "${mandam[@]}"; do
    [ -f "$arq" ] || continue
    fonte="$(grep -oP 'source: Path\("\K[^"]+' "$arq" 2>/dev/null)"
    # `$alvo` e não `$ATIVOS`: com a noite ligada, "no lugar certo" é a pasta do
    # grupo desta hora. Comparar com `ativos/` faria este comando gritar duas
    # vezes por dia, para sempre, sobre uma configuração que está correta.
    [ "$fonte" = "$alvo" ] && continue
    echo "estado:    $(basename "$arq") aponta para outro lugar ($fonte)"
    fora=1
  done
  [ "$fora" = "0" ] && echo "estado:    carrossel ATIVO"
  # A imagem exata que está na tela não é observável: o cosmic-bg não fala D-Bus
  # e não grava o índice em lugar nenhum. Dizer "não sei" é melhor que inventar.
  echo "atual:     (o cosmic-bg não expõe qual imagem está em exibição)"
}

# --- permitir: a única forma de a escolha dela virar regra -------------------
# O VALOR VEM DO ARQUIVO, NÃO DO AMBIENTE, E ISSO NÃO É PREFERÊNCIA
#   O `FONTES_DELA` lá de cima chega pelo ambiente, e chega VAZIO quando alguém
#   roda `./scripts/wallpaper.sh permitir …` na mão, sem passar pela CLI. Se a
#   gravação usasse aquilo como base, o segundo `permitir` apagaria o primeiro —
#   uma autorização anterior dela sumindo em silêncio, que é o pior defeito
#   possível num comando cujo propósito é justamente respeitar a escolha dela.
#   Aqui a lista de partida é lida do meow.conf, pela MESMA regra do wizard
#   (`wiz_linha_da_chave`/`wiz_valor_da_linha` em bin/meow): vale a ÚLTIMA
#   atribuição, que é a que o `.` do shell obedece.
#
# E O VALOR VOLTA CRU, COM O `$HOME` QUE ELA TIVER ESCRITO
#   `WALLPAPER_BASE="$HOME/..."` é o estilo deste arquivo. Gravar a expansão
#   congelaria o caminho; então o que sai daqui é o texto como está, com o novo
#   caminho anexado. A expansão só acontece na hora de comparar.
#
# O CORPO DISTO VIROU `conf_bruto`, LÁ EM CIMA, em 25/08/2026 — as chaves da
# noite precisavam da mesma leitura, e chave de configuração com duas rotinas de
# leitura é a receita de as duas discordarem no dia em que uma for corrigida (é
# a mesma frase que o `lib/comum.sh` escreveu ao trazer a `meow_conf_definir`
# para cá, pelo mesmo motivo). O que estava documentado acima continua valendo
# palavra por palavra; só o endereço mudou.
fontes_no_conf() { conf_bruto WALLPAPER_FONTES_DELA; }

cmd_permitir() {
  local caminho="${1:-}"
  [ -n "$caminho" ] || {
    meow_erro "uso: wallpaper.sh permitir <caminho>"
    meow_info "o caminho é o que aparece no aviso \"apontava para …\""
    return "$MEOW_ERRO"; }

  # ABSOLUTO E NORMALIZADO: é com o `source: Path(...)` do COSMIC que este valor
  # vai ser comparado, e lá o caminho é SEMPRE absoluto. Gravar `../Imagens`
  # produziria uma entrada que nunca casa com nada — uma autorização que não
  # autoriza, sem nada acusando.
  # `-m` e não `-e`: a pasta pode não existir hoje (um disco desmontado, uma
  # pasta que ela ainda vai criar), e recusar por isso seria recusar a intenção.
  caminho="$(readlink -m -- "$caminho")"

  # O meow.conf é SOURCEADO pelo shell. Um `$` ou uma crase no valor deixariam
  # de ser texto e virariam código no próximo `carregar_conf`; um `#` viraria
  # comentário e comeria o resto da linha; uma aspa dupla fecharia a string. O
  # wizard recusa `#` e `"` pelo mesmo motivo — aqui a lista é maior porque este
  # valor é um caminho, e caminho aceita caractere que resposta de wizard não.
  if [ "${caminho//[\"\$\`\\#]/}" != "$caminho" ]; then
    meow_erro "não gravo caminho com \" \$ \` \\ ou # — o meow.conf é lido pelo shell"
    return "$MEOW_ERRO"
  fi

  # A CONFERÊNCIA VEM ANTES DO AVISO DE "não existe": um caminho já coberto por
  # uma pasta autorizada não precisa existir para nada, e avisar sobre ele seria
  # alarme falso num comando que não vai escrever coisa nenhuma.
  local bruto expandido
  bruto="$(fontes_no_conf)"
  expandido="${bruto//\$\{HOME\}/$HOME}"; expandido="${expandido//\$HOME/$HOME}"
  if fonte_autorizada "$caminho" "$expandido"; then
    meow_ok "$caminho já está autorizado em WALLPAPER_FONTES_DELA"
    return "$MEOW_OK"
  fi

  [ -e "$caminho" ] || meow_aviso "$caminho não existe hoje — autorizando assim mesmo"

  local novo="$caminho"
  [ -n "$bruto" ] && novo="$bruto:$caminho"

  meow_conf_definir WALLPAPER_FONTES_DELA "$novo"
  case $? in
    0) meow_ok "$MEOW_CONF_ARQUIVO já estava assim — nada foi escrito"
       return "$MEOW_OK" ;;
    1) if meow_seco; then
         meow_muda "gravaria WALLPAPER_FONTES_DELA=\"$novo\""
         return "$MEOW_DIVERGENTE"
       fi
       meow_ok "autorizado: $caminho"
       meow_info "o carrossel não mexe mais em saída que aponte para lá"
       meow_registrar "wallpaper permitir: $caminho"
       return "$MEOW_DIVERGENTE" ;;
    *) meow_erro "não consegui gravar $MEOW_CONF_ARQUIVO"
       return "$MEOW_ERRO" ;;
  esac
}

# Mover, nunca apagar: uma imagem banida pode ser recuperada de banidos/.
cmd_banir() {
  local img="$1"
  [ -f "$img" ] || { meow_erro "não achei $img"; return "$MEOW_ERRO"; }
  local nome; nome="$(basename "$img")"
  # O SECO NÃO BANE — E ATÉ 24/08/2026 BANIA
  #   O `mv` abaixo nunca consultou `meow_seco`: `MEOW_DRY_RUN=1 meow wallpaper
  #   banir <img>`, que a pessoa roda esperando uma PRÉVIA, tirava a imagem de
  #   `ativos/` de verdade. A auditoria daquele dia mediu o defeito (antigo, não
  #   regressão) ao conferir a linha nova que grava a lista logo abaixo — que
  #   repetia o mesmo descuido. A guarda vale para os dois.
  if meow_seco; then
    meow_muda "baniria $nome (iria para banidos/ e entraria em $(basename "$BANIDOS_TXT"))"
    return "$MEOW_DIVERGENTE"
  fi
  criar_pastas
  # `mv -n` recusa sobrescrever — e uma imagem JÁ banida antes deixaria o arquivo
  # parado em ativos/, com o script dizendo "banida". Se a cópia em banidos/ já
  # existe e é idêntica, o banimento anterior valeu: basta tirar daqui.
  if [ -e "$BASE/banidos/$nome" ] && cmp -s "$img" "$BASE/banidos/$nome"; then
    rm -f "$img"
  else
    mv -f "$img" "$BASE/banidos/" || return "$MEOW_ERRO"
  fi
  # A LISTA, NÃO SÓ A PASTA: sem ela o banimento morre com esta máquina.
  # E A LISTA PRECISA NASCER SOZINHA: a primeira escrita disto exigia que o
  # arquivo JÁ existisse (`[ -f ] && grep ...`), então numa árvore recém-clonada
  # — exatamente o caso que esta lista existe para resolver — o `banir` pulava
  # calado e o `meow_ok` mentia dizendo que tinha registrado.
  local pasta_lista; pasta_lista="$(dirname "$BANIDOS_TXT")"
  if [ -d "$pasta_lista" ]; then
    [ -f "$BANIDOS_TXT" ] || printf '%s\n' \
      "# BANIDOS.txt — os papéis de parede que ela recusou, por nome de arquivo." \
      "# O 'meow wallpaper banir' acrescenta aqui; o 'semear' não repõe o que está listado." \
      > "$BANIDOS_TXT"
    grep -qxF -- "$nome" "$BANIDOS_TXT" || printf '%s\n' "$nome" >> "$BANIDOS_TXT"
  else
    meow_aviso "não achei $pasta_lista — o banimento de $nome vale só nesta máquina"
  fi
  meow_ok "banida: $nome — está em banidos/, não foi apagada"
  # O `aplicar` primeiro: com a noite ligada é ele quem tira o link duro da
  # pasta derivada, e o comentário que estava nesta linha ("força a releitura da
  # lista") descrevia uma coisa que ele NÃO faz — a configuração não contém a
  # lista, então escrever o mesmo texto é no-op e o cosmic-bg continuava com a
  # imagem banida na lista fotografada, tentando abrir um arquivo que saiu da
  # pasta. Quem força de verdade é o `forcar_releitura`, logo abaixo.
  cmd_aplicar >/dev/null
  forcar_releitura
  return "$MEOW_DIVERGENTE"
}

# O SECO AQUI VAZAVA, E FOI O TESTE DO CONSERTO IRMÃO QUE PEGOU (25/08/2026)
#   `MEOW_DRY_RUN=1 wallpaper.sh adicionar foto.png` COPIAVA a foto. O `cp` não
#   passava por `meow_escrever` (que respeita o seco por dentro) nem consultava
#   `meow_seco`, então o único comando deste script que traz arquivo de fora era
#   também o único em que "mostrar o que faria" fazia.
#
#   O estrago não é grande — copiar imagem para `ativos/` é reversível com um
#   `banir` —, mas o contrato é: `--dry-run` não escreve. Um seco que escreve é
#   pior que não ter seco, porque a pessoa confia nele para auditar antes.
#
#   Não é regressão: está assim desde `527b36d`.
_adicionar_uma() {
  local img="$1"
  if meow_seco; then
    [ -e "$ATIVOS/$(basename "$img")" ] && return 1
    meow_muda "copiaria $(basename "$img") para ativos/"
    return 0
  fi
  # A EXISTÊNCIA SE TESTA ANTES, PORQUE O `cp -n` NÃO CONTA A HISTÓRIA
  #   `cp -n` devolve **0** quando o destino já existe: ele não é erro, ele
  #   simplesmente não copia. Confiar no status dele fazia o `n` contar uma
  #   imagem que não entrou — e o `adicionar` de uma foto repetida ia até o
  #   `forcar_releitura` e REINICIAVA a rotação dela sem ter acrescentado nada.
  #   Foi o teste do terceiro cenário que pegou; o primeiro conserto tinha
  #   trocado um defeito calado por outro.
  [ -e "$ATIVOS/$(basename "$img")" ] && return 1
  cp -n "$img" "$ATIVOS/" 2>/dev/null || return 1
  return 0
}

# O INVERSO DO `banir`, QUE NÃO EXISTIA — 01/09/2026
#
# POR QUE ELE FALTAVA, E POR QUE ISSO PESAVA
#   `cmd_banir` faz DUAS coisas: move a imagem para `banidos/` E grava o nome no
#   `BANIDOS.txt`, que é o que impede o `semear` de repô-la. Desfazer isso à mão
#   exigia saber das duas — e `adicionar banidos/<img>` sozinho não desfaz: a
#   imagem volta para `ativos/` e o nome CONTINUA na lista de recusadas. O
#   resultado é um estado que se contradiz: a foto girando no carrossel e o
#   arquivo do repositório dizendo que ela foi recusada. No próximo `semear`
#   numa máquina limpa, a recusa venceria de novo, sem ninguém entender por quê.
#
#   Ficou de fora até hoje porque banir era o gesto natural (apagar de `ativos/`,
#   que o vigia percebe em ~4 s) e desbanir não tinha gesto nenhum: era mexer
#   num arquivo de texto. Com a galeria de miniaturas da página, desbanir passou
#   a ser um clique — e um clique precisa de um comando que faça a coisa
#   INTEIRA, não metade dela.
#
# SÃO 255 IMAGENS EM `banidos/` NESTA MÁQUINA, e nenhuma foi apagada: o banir
# move, nunca remove. É por isso que desbanir é possível de verdade e não uma
# promessa — o arquivo está lá.
cmd_desbanir() {
  local nome; nome="$(basename "${1:-}")"
  [ -n "$nome" ] || { meow_erro "uso: wallpaper.sh desbanir <nome-do-arquivo>"; return "$MEOW_ERRO"; }
  local origem="$BASE/banidos/$nome"
  if [ ! -f "$origem" ]; then
    meow_erro "não achei $nome em banidos/"
    meow_info "  o nome é o do ARQUIVO, sem caminho — veja: ls \"$BASE/banidos\""
    return "$MEOW_ERRO"
  fi

  local na_lista=0
  [ -f "$BANIDOS_TXT" ] && grep -qxF -- "$nome" "$BANIDOS_TXT" && na_lista=1
  local em_ativos=0
  [ -e "$ATIVOS/$nome" ] && em_ativos=1

  if [ "$em_ativos" = "1" ] && [ "$na_lista" = "0" ]; then
    meow_ok "$nome já está em ativos/ e fora da lista — nada a fazer"
    return "$MEOW_OK"
  fi

  if meow_seco; then
    [ "$em_ativos" = "0" ] && meow_muda "devolveria $nome para ativos/"
    [ "$na_lista" = "1" ]  && meow_muda "tiraria $nome de $(basename "$BANIDOS_TXT")"
    return "$MEOW_DIVERGENTE"
  fi

  criar_pastas
  # `cp` e não `mv`: a cópia em `banidos/` fica como estava. Banir de novo é um
  # comando, e é bom que ele não dependa de o arquivo ter sobrevivido a esta ida
  # e volta — a pasta `banidos/` é o arquivo morto, e arquivo morto não se
  # esvazia por causa de uma mudança de ideia.
  if [ "$em_ativos" = "0" ]; then
    cp -n "$origem" "$ATIVOS/" 2>/dev/null || { meow_erro "não consegui copiar $nome"; return "$MEOW_ERRO"; }
  fi

  # A SEGUNDA METADE, que é a que faltava em qualquer contorno manual.
  # `grep -vxF` compara a LINHA INTEIRA e literalmente: nome de arquivo é texto
  # cheio de `.`, `+` e `[`, e num grep de expressão regular `cat-lofi.jpg`
  # casaria com `catXlofiXjpg`. É o mesmo cuidado do `meow_manifesto_registrar`.
  if [ "$na_lista" = "1" ]; then
    local tmp; tmp="$(mktemp -p "$(dirname "$BANIDOS_TXT")" ".atomicwrite.meow.XXXXXX")" || return "$MEOW_ERRO"
    grep -vxF -- "$nome" "$BANIDOS_TXT" > "$tmp" 2>/dev/null
    mv -f "$tmp" "$BANIDOS_TXT" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  fi

  meow_ok "devolvida: $nome — está em ativos/ e saiu da lista de recusadas"
  # A MESMA ORDEM DO `banir` e do `adicionar`, e pelo mesmo motivo medido: o
  # `aplicar` põe a imagem na pasta derivada do grupo certo (a noite está
  # ligada), e só depois o `forcar_releitura` faz o cosmic-bg reler — sozinho o
  # `aplicar` escreve conteúdo idêntico e é ignorado.
  cmd_aplicar >/dev/null
  forcar_releitura
  return "$MEOW_DIVERGENTE"
}

# --- lado: a porta para discordar da medição --------------------------------
# O porquê inteiro está em "O REGISTRO DE LADO", lá em cima, junto do `ler_lado`.
# Aqui fica o comando, e as três decisões que ele carrega.
#
# 1. A REFERÊNCIA É RESOLVIDA COMO A DO `banir`, E PELO MESMO CUIDADO MEDIDO
#    O `cmd_banir` recebe um CAMINHO de arquivo (`[ -f "$img" ]`), e o
#    `app/servidor.py` documenta por que ele manda o caminho canônico, o de
#    `ativos/`: `ativos-dia/` e `ativos-noite/` são LINK DURO do mesmo inode, e
#    banir pelo link move só o link e deixa a imagem girando — um banimento pela
#    metade, e mudo. Aqui o registro é por NOME (como o `BANIDOS.txt`), então o
#    link não estraga a chave; mas a CONFERÊNCIA de existência tem de ser feita
#    em `ativos/` de qualquer jeito, senão daria para escrever uma escolha sobre
#    um link que sobrou de uma passagem antiga, ou sobre uma imagem que já foi
#    banida. Por isso o caminho serve para achar o nome, e o nome é conferido
#    contra o acervo — e só contra ele.
#
# 2. `auto` APAGA A LINHA, NUNCA ESCREVE A PALAVRA. Ausente é o padrão.
#
# 3. O `aplicar` VEM NO FIM, COMO NO `banir` E NO `desbanir`
#    Sem ele o comando escreveria a escolha e não moveria imagem nenhuma: quem
#    monta `ativos-dia/` e `ativos-noite/` é o `resolver_rotacao`, dentro do
#    `aplicar`. Ela clicaria em "Noite" e não veria nada acontecer até o tique
#    seguinte do relógio de 15 minutos — o defeito exato que este arquivo já
#    documenta ter cometido com a fixação em 01/09/2026 ("o recurso parece
#    quebrado justamente no momento em que ela está usando o outro recurso").
#    E o `forcar_releitura` depois, pelo motivo da armadilha 3 do cabeçalho: a
#    imagem SAIU da pasta que o cosmic-bg fotografou, e sem a releitura ele
#    continuaria tentando abrir um arquivo que não está mais lá.
#
#    Só quando algo mudou de verdade. Uma reafirmação (`0`) não paga o preço da
#    armadilha 2 — releitura não avança, REINICIA a rotação.
cmd_lado() {
  local ref="${1:-}" escolha="${2:-}"
  if [ -z "$ref" ] || [ -z "$escolha" ]; then
    meow_erro "uso: wallpaper.sh lado <arquivo|nome> dia|noite|auto"
    meow_info "  dia    a imagem fica no grupo do dia, custe o que custar a medição"
    meow_info "  noite  a imagem fica no grupo da noite"
    meow_info "  auto   devolve a decisão para a luminância (apaga a linha)"
    return "$MEOW_ERRO"
  fi
  case "$escolha" in
    dia|noite|auto) ;;
    *) meow_erro "não conheço o lado \"$escolha\" — é dia, noite ou auto"
       return "$MEOW_ERRO" ;;
  esac

  # A PENEIRA, ANTES DE O NOME DE FORA VIRAR CAMINHO OU LINHA DE ARQUIVO.
  # O `basename` derruba o `../..` de qualquer profundidade; o `.`/`..` que
  # sobra do `basename` de um diretório é recusado à mão; e tab ou quebra de
  # linha no nome corromperiam o TSV na gravação, com o defeito aparecendo só na
  # leitura seguinte, em OUTRO arquivo — é o mesmo cuidado que o `medir_acervo`
  # já toma com o cache de luminância, e a mesma recusa.
  local nome TAB=$'\t' NL=$'\n'
  nome="$(basename -- "$ref")"
  case "$nome" in
    ''|.|..) meow_erro "\"$ref\" não é nome de imagem"; return "$MEOW_ERRO" ;;
    *"$TAB"*|*"$NL"*)
      meow_erro "o nome tem tab ou quebra de linha — não dá para registrar o lado dele"
      return "$MEOW_ERRO" ;;
  esac

  if [ ! -f "$ATIVOS/$nome" ]; then
    meow_erro "não achei $nome em ativos/"
    if [ -f "$BASE/banidos/$nome" ]; then
      meow_info "  ela está em banidos/ — devolva antes: meow wallpaper desbanir \"$nome\""
    else
      meow_info "  o lado se escolhe para imagem do acervo — veja: ls \"$ATIVOS\""
    fi
    return "$MEOW_ERRO"
  fi

  ler_lado
  local antes="${LADO[$nome]:-auto}"
  if [ "$antes" = "$escolha" ]; then
    if [ "$escolha" = "auto" ]; then
      meow_ok "$nome já é decidida pela medição — nada a fazer"
    else
      meow_ok "$nome já está escrita como $escolha — nada a fazer"
    fi
    return "$MEOW_OK"
  fi

  if meow_seco; then
    if [ "$escolha" = "auto" ]; then
      meow_muda "tiraria $nome de $(basename "$LADO_TSV") — a medição voltaria a decidir"
    else
      meow_muda "gravaria $nome como $escolha em $(basename "$LADO_TSV")"
    fi
    return "$MEOW_DIVERGENTE"
  fi

  if [ "$escolha" = "auto" ]; then
    _lado_esquecer "$nome"
  else
    LADO["$nome"]="$escolha"
  fi
  gravar_lado || { meow_erro "não consegui gravar $LADO_TSV"; return "$MEOW_ERRO"; }

  if [ "$escolha" = "auto" ]; then
    meow_ok "$nome volta para a medição (limiar $LIMIAR_LUZ decide de novo)"
  else
    meow_ok "$nome fica no grupo de $escolha — escolha sua, a medição não decide mais por ela"
  fi

  # A ESCOLHA É GRAVADA, MAS COM A NOITE DESLIGADA ELA NÃO FAZ NADA — E ISSO
  # PRECISA SER DITO. Com `WALLPAPER_NOITE="nao"` as duas pastas derivadas somem
  # do disco e a rotação é o acervo inteiro: não existe "grupo de dia" para a
  # imagem ir. Guardar a escolha em silêncio faria o comando parecer obedecer e
  # não obedecer — o defeito que este arquivo mais documenta ter cometido (a
  # `LOG_NIVEL` inerte, as `WALLPAPER_SEMENTES`). O registro continua sendo
  # escrito de propósito: a escolha vale no dia em que ela religar a noite.
  [ "$NOITE" = "sim" ] || \
    meow_aviso "a noite está desligada (WALLPAPER_NOITE=\"$NOITE\") — a escolha fica guardada e só separa alguma coisa quando você religar"

  cmd_aplicar >/dev/null || true
  forcar_releitura
  return "$MEOW_DIVERGENTE"
}

cmd_adicionar() {
  local alvo="$1"
  criar_pastas
  local n=0
  if [ -d "$alvo" ]; then
    while IFS= read -r img; do
      _adicionar_uma "$img" && n=$((n + 1))
    done < <(find "$alvo" -maxdepth 1 -type f \
               \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \))
  elif [ -f "$alvo" ]; then
    _adicionar_uma "$alvo" && n=1
  else
    meow_erro "não achei $alvo"; return "$MEOW_ERRO"
  fi
  if [ "$n" = "0" ]; then
    # `cp -n` não sobrescreve, então zero quer dizer "já estavam todas lá". Sem
    # esta saída antecipada o comando reiniciaria a rotação dela para não ter
    # acrescentado nada — barulho puro.
    meow_pula "nenhuma imagem nova (as que você passou já estavam em ativos/)"
    return "$MEOW_OK"
  fi
  meow_ok "$n imagem(ns) adicionada(s)"
  # `cmd_aplicar` primeiro, porque com a noite ligada é ele quem põe a imagem
  # nova na pasta derivada do grupo certo — sem isso ela entraria em `ativos/` e
  # ficaria de fora da rotação que está no ar.
  cmd_aplicar >/dev/null
  # E o `forcar_releitura` DEPOIS, porque o `aplicar` sozinho não basta: a
  # configuração não contém a lista de imagens, então ele escreve conteúdo
  # idêntico e o cosmic-bg ignora. Ver a armadilha 1 no cabeçalho — esta era a
  # contradição que o próprio cabeçalho carregava desde que foi escrito.
  forcar_releitura
  return "$MEOW_DIVERGENTE"
}

# --- semear: a coleção Catppuccin da comunidade ----------------------------
# POR QUE NÃO CLONAR O REPOSITÓRIO
#   `zhichaoh/catppuccin-wallpapers` tem 371 MB e 242 imagens; o
#   `orangci/walls-catppuccin-mocha` tem 795 MB. Baixar tudo para usar uma dúzia
#   é desperdício de banda e de disco. Aqui se lê a árvore do commit PINADO pela
#   API e se baixam só os arquivos escolhidos, por URL crua.
#
# COMMIT PINADO, NUNCA `main`
#   Um upstream que muda sozinho transforma "rodei o instalador" em "rodei num
#   dia em que o repositório estava de um jeito".
#
# AS IMAGENS NÃO ENTRAM NO GIT
#   O repositório guarda esta receita. As fotos ficam só na máquina.
SEMENTE_REPO="${WALLPAPER_SEMENTE_REPO:-zhichaoh/catppuccin-wallpapers}"
SEMENTE_COMMIT="${WALLPAPER_SEMENTE_COMMIT:-1023077979591cdeca76aae94e0359da1707a60e}"
# 0 = TODAS as imagens do repositorio. Um numero baixa so uma amostra, uma de
# cada categoria por rodizio (util para testar sem gastar banda).
SEMENTE_QUANTAS="${WALLPAPER_SEMENTE_QUANTAS:-0}"

# --- o "não quero" dela também precisa ser receita ---------------------------
# `banidos/` guarda os ARQUIVOS recusados, e isso resolve esta máquina. Não
# resolve a PRÓXIMA: numa instalação nova, `banidos/` nasce vazio, e o `semear`
# baixaria de volta as 231 imagens que ela tirou em 24/08/2026, uma por uma.
#
# `assets/papeis-de-parede/BANIDOS.txt` é a lista de nomes recusados — texto, pequeno, vai
# para o git (a regra do `.gitignore` barra imagem, não lista). É o par do
# `FONTES.tsv` abaixo: um diz o que ela quer, o outro diz o que ela não quer, e
# juntos os dois reproduzem a escolha dela em qualquer máquina.
BANIDOS_TXT="${WALLPAPER_BANIDOS:-$RAIZ/assets/papeis-de-parede/BANIDOS.txt}"

esta_banida() {
  local nome="$1"
  [ -e "$BASE/banidos/$nome" ] && return 0
  [ -f "$BANIDOS_TXT" ] && grep -qxF -- "$nome" "$BANIDOS_TXT" && return 0
  return 1
}

# --- a curadoria dela: escolhida a mão, reproduzível pela receita -------------
# A coleção Catppuccin acima é acervo de TERCEIRO, e o que o reproduz é o commit
# pinado. Este bloco é o acervo DELA: o que sobreviveu à curadoria de 24/08/2026
# e o que buscamos na internet naquele dia, imagem por imagem.
#
# Mesma regra do resto do repositório: a imagem não vai para o git, a RECEITA
# vai. `assets/papeis-de-parede/FONTES.tsv` é a receita — uma linha por imagem, com a URL de
# onde ela veio. Sem este arquivo, uma máquina reformatada voltaria só com o que
# sobrou da coleção de terceiro e NENHUMA das escolhas dela; sem o `BANIDOS.txt`
# do bloco acima, voltaria com as 242 do upstream inteiras. Os dois juntos são a
# curadoria — um diz o que ela quer, o outro o que ela não quer.
FONTES_TSV="${WALLPAPER_FONTES:-$RAIZ/assets/papeis-de-parede/FONTES.tsv}"
CURADORIA_N=0

semear_da_curadoria() {
  CURADORIA_N=0
  [ -f "$FONTES_TSV" ] || return 0
  # POR QUE O AWK FILTRA ANTES, EM VEZ DE CONFIAR NO `read`
  #   Duas armadilhas medidas em 24/08/2026, na auditoria desta própria função:
  #   1. `read` devolve status != 0 na ÚLTIMA linha quando o arquivo não termina
  #      em newline — as variáveis são preenchidas, mas o laço encerra ANTES de
  #      rodar o corpo. A última imagem da receita sumia sem um aviso. (O laço
  #      irmão, logo acima, usa here-string e por isso nunca teve o problema.)
  #   2. `IFS=$'\t'` NÃO isola campo vazio: tab é "IFS whitespace" no bash, e
  #      dois tabs seguidos colapsam num só. Uma linha com a URL em branco
  #      entregava a RESOLUÇÃO dentro de `$url`, e o script tentava baixar
  #      "1920x1080" — falhando com "não baixaram, rode de novo", que manda
  #      consertar rede quando o defeito está no dado.
  #   O awk conta campo de verdade (NF), exige que a URL PAREÇA uma URL, e o
  #   here-string abaixo garante o newline final.
  local validas descartadas
  validas="$(awk -F'\t' '$1 !~ /^#/ && $1 != "arquivo" && $1 != "" && NF >= 3 && $3 ~ /^https?:\/\// {print}' "$FONTES_TSV")"
  descartadas="$(awk -F'\t' '$1 !~ /^#/ && $1 != "arquivo" && $1 != "" && !(NF >= 3 && $3 ~ /^https?:\/\//) {n++} END {print n+0}' "$FONTES_TSV")"
  if [ "$descartadas" -gt 0 ]; then
    meow_aviso "$descartadas linha(s) de $(basename "$FONTES_TSV") sem URL utilizável — ignoradas"
  fi
  [ -n "$validas" ] || return 0

  local falhas=0 nome categoria url resolucao
  while IFS=$'\t' read -r nome categoria url resolucao; do
    [ -n "$nome" ] || continue
    local destino="$ATIVOS/$nome"
    [ -e "$destino" ] && continue
    esta_banida "$nome" && continue   # o que ela tirou, fica tirado
    if meow_seco; then
      meow_muda "baixaria $nome (curadoria)"; CURADORIA_N=$((CURADORIA_N + 1)); continue
    fi
    local tmp; tmp="$(mktemp -p "$ATIVOS" ".meow.XXXXXX")"
    if curl -sSL --max-time 90 -o "$tmp" "$url" 2>/dev/null && [ -s "$tmp" ]; then
      mv -f "$tmp" "$destino"; CURADORIA_N=$((CURADORIA_N + 1))
    else
      rm -f "$tmp"; falhas=$((falhas + 1))
    fi
  done <<< "$validas"
  [ "$falhas" -gt 0 ] && meow_aviso "$falhas imagem(ns) da curadoria não baixaram — rode de novo"
  return 0
}

cmd_semear() {
  meow_tem curl || { meow_erro "curl não encontrado"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem python3 || { meow_erro "python3 não encontrado"; return "$MEOW_SEM_DEPENDENCIA"; }
  criar_pastas

  local api="https://api.github.com/repos/$SEMENTE_REPO/git/trees/$SEMENTE_COMMIT?recursive=1"
  local lista; lista="$(curl -sS --max-time 30 "$api" 2>/dev/null)" || {
    meow_aviso "não consegui falar com o GitHub — semeadura pulada"
    return "$MEOW_SEM_DEPENDENCIA"
  }

  # Escolhe espalhando pelas categorias, em vez de pegar as N primeiras (que
  # seriam todas da mesma pasta e pareceriam a mesma imagem repetida).
  local escolhidas
  escolhidas="$(printf '%s' "$lista" | python3 -c "
import json, sys
from urllib.parse import quote
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if 'tree' not in d:
    sys.exit(1)
imgs = [t['path'] for t in d['tree']
        if t.get('type') == 'blob' and t['path'].lower().endswith(('.png', '.jpg', '.jpeg'))]
por_pasta = {}
for p in imgs:
    por_pasta.setdefault(p.split('/')[0], []).append(p)
# rodízio entre as pastas: uma de cada, depois a segunda de cada, e assim por diante
limite = $SEMENTE_QUANTAS or len(imgs)
saida, i = [], 0
while len(saida) < limite:
    houve = False
    for pasta in sorted(por_pasta):
        if i < len(por_pasta[pasta]):
            saida.append(por_pasta[pasta][i]); houve = True
            if len(saida) >= limite: break
    if not houve: break
    i += 1
print('\n'.join(p + '\t' + quote(p, safe='/') for p in saida))
")" || { meow_aviso "resposta do GitHub inesperada — semeadura pulada"; return "$MEOW_SEM_DEPENDENCIA"; }

  # DUAS COLUNAS: a URL vai escapada, o nome de arquivo vai cru.
  #   Sem isso, toda imagem cujo nome tem espaço falhava calada — curl com espaço
  #   na URL devolve 000, e o ramo de erro apagava o temporário sem dizer nada.
  #   Medido em 05/08/2026: três imagens de waves/ ficaram de fora da máquina dela
  #   desde a primeira semeadura, com o script relatando sucesso. 239 de 242.
  #   (E o comentário mora AQUI, não dentro do bloco Python acima: aquilo é uma
  #   string entre aspas duplas do bash, então um crase ali vira substituição de
  #   comando. Foi o que aconteceu na primeira tentativa desta correção.)

  [ -n "$escolhidas" ] || { meow_aviso "nenhuma imagem encontrada"; return "$MEOW_SEM_DEPENDENCIA"; }

  local n=0 falhas=0 base="https://raw.githubusercontent.com/$SEMENTE_REPO/$SEMENTE_COMMIT"
  while IFS=$'\t' read -r caminho caminho_url; do
    [ -n "$caminho" ] || continue
    # Prefixo com a categoria: o nome vira legível e a ordem alfanumérica agrupa.
    local nome="cat-${caminho//\//-}"
    local destino="$ATIVOS/$nome"
    [ -e "$destino" ] && continue
    # O BANIMENTO PRECISA SOBREVIVER A UM `semear` — E NÃO SOBREVIVIA
    #   Medido em 24/08/2026, curando o acervo com ela: `semear` repõe tudo que
    #   não estiver em `ativos/`, e a única coisa que ele consultava era
    #   `ativos/`. Uma imagem que ela tirou está, por definição, fora de
    #   `ativos/` — então toda escolha dela era desfeita pela próxima
    #   semeadura, calada, com o script relatando sucesso. Naquele dia foram
    #   231 imagens banidas; sem esta linha, um `meow wallpaper aplicar` que
    #   caísse no semear traria as 231 de volta para a tela dela.
    #
    #   `banidos/` é a memória do que ela NÃO quer. Consultá-la aqui é o que
    #   transforma "banir" em decisão, não em adiamento.
    esta_banida "$nome" && continue
    if meow_seco; then
      meow_muda "baixaria $nome"; n=$((n+1)); continue
    fi
    # Baixa para temporário no MESMO diretório e só então renomeia: uma imagem
    # pela metade entraria na rotação e apareceria cortada na tela dela.
    local tmp; tmp="$(mktemp -p "$ATIVOS" ".meow.XXXXXX")"
    if curl -sSL --max-time 60 -o "$tmp" "$base/$caminho_url" 2>/dev/null && [ -s "$tmp" ]; then
      mv -f "$tmp" "$destino"; n=$((n+1))
    else
      rm -f "$tmp"; falhas=$((falhas + 1))
    fi
  done <<< "$escolhidas"

  # Falha de download não pode continuar sendo invisível: era o que escondia as
  # três imagens de nome com espaço.
  [ "$falhas" -gt 0 ] && meow_aviso "$falhas imagem(ns) não baixaram — rode de novo para tentar outra vez"

  semear_da_curadoria
  if [ "$CURADORIA_N" -gt 0 ]; then
    # O TEMPO VERBAL DE NOVO: no seco NADA foi baixado. Dizer "reproduzidas", no
    # passado, é a mesma mentira que este arquivo já documenta duas linhas abaixo
    # — e que a auditoria de 24/08/2026 pegou nesta função, recém-escrita.
    if meow_seco; then
      meow_muda "reproduziria $CURADORIA_N imagem(ns) da curadoria dela (assets/papeis-de-parede/FONTES.tsv)"
    else
      meow_ok "$CURADORIA_N imagem(ns) da curadoria dela reproduzidas (assets/papeis-de-parede/FONTES.tsv)"
    fi
    n=$((n + CURADORIA_N))
  fi

  if [ "$n" -eq 0 ]; then
    meow_ok "coleção Catppuccin já semeada"
    return "$MEOW_OK"
  fi
  # No seco NADA foi baixado — dizer "baixadas", no passado, é a mesma mentira
  # que o modo seco já cometeu duas vezes neste projeto (a semeadura das imagens
  # dela e o log do install.sh). O tempo verbal aqui é a diferença entre um
  # relatório e uma promessa.
  if meow_seco; then
    meow_muda "baixaria $n imagem(ns) da coleção Catppuccin (${SEMENTE_REPO}@${SEMENTE_COMMIT:0:8})"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "$n imagem(ns) da coleção Catppuccin baixadas (${SEMENTE_REPO}@${SEMENTE_COMMIT:0:8})"
  meow_seco || cmd_aplicar >/dev/null   # a lista é fotografada no load: precisa reescrever
  return "$MEOW_DIVERGENTE"
}

# --- avançar / voltar --------------------------------------------------------
# `$1` = +1 ou -1. Devolve 1 (mudou) porque é o código de "estava diferente e eu
# escrevi" deste projeto — e é o que o `bin/meow` já sabe interpretar.
#
# POR QUE O GRUPO, E NÃO O ACERVO INTEIRO
#   Avançar tem de andar pela mesma lista que o carrossel gira. Se a noite está
#   ligada, o carrossel gira `ativos-noite/`; oferecer, no "próximo", uma imagem
#   clara que o grupo da noite exclui seria o botão desfazendo a curadoria de
#   dia/noite a cada clique.
#
# QUANDO NÃO SE SABE ONDE ESTAMOS, COMEÇA DO COMEÇO. `imagem_atual` falha se o
# estado do cosmic-bg ainda não tem entrada nossa (sessão recém-aberta, monitor
# novo). Aí `avançar` mostra a primeira e `voltar` mostra a última — que é o que
# um carrossel faz quando se entra nele pela borda.
cmd_passo() {
  local delta="$1" dir lista n atual i alvo
  criar_pastas || { meow_erro "não consegui criar as pastas"; return "$MEOW_ERRO"; }
  resolver_rotacao

  # Com fixação valendo, `$ROTACAO` é um ARQUIVO; a lista tem de vir da pasta do
  # grupo, não dele. `_resolver_grupo` já deixou `$GRUPO` em "dia"/"noite" antes
  # de o invólucro sobrescrever — mas ele o troca por "fixado", então a pasta se
  # redescobre aqui pelo mesmo teste de sempre.
  if   [ -d "$NOITE_DIR" ] && [ "$GRUPO" != "dia" ] && e_noite; then dir="$NOITE_DIR"
  elif [ -d "$DIA_DIR" ]   && ! e_noite;                        then dir="$DIA_DIR"
  else dir="$ATIVOS"; fi
  [ -d "$dir" ] || dir="$ATIVOS"

  mapfile -t lista < <(lista_do_grupo "$dir")
  n="${#lista[@]}"
  if [ "$n" -lt 2 ]; then
    meow_aviso "só $n imagem(ns) em $(basename "$dir") — não há para onde avançar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # A âncora é o BASENAME, não o caminho: o estado do cosmic-bg pode apontar
  # para `ativos-dia/x.jpg` enquanto a lista da vez é de `ativos-noite/` (a
  # virada aconteceu entre uma coisa e outra). Comparar caminho inteiro perderia
  # a posição e voltaria sempre para a primeira imagem na hora da virada.
  atual="$(imagem_atual || true)"
  i=-1
  if [ -n "$atual" ]; then
    local j
    for j in "${!lista[@]}"; do
      [ "$(basename "${lista[$j]}")" = "$(basename "$atual")" ] && { i="$j"; break; }
    done
  fi
  if [ "$i" -lt 0 ]; then
    [ "$delta" -gt 0 ] && i=-1 || i=0
  fi

  # `% n` em bash pode devolver negativo; o `+ n` antes do segundo `%` é o que
  # faz `voltar` na primeira imagem cair na última em vez de virar índice -1.
  alvo=$(( ( (i + delta) % n + n ) % n ))

  if meow_seco; then
    meow_muda "fixaria $(basename "${lista[$alvo]}") (${alvo_1:-$((alvo + 1))} de $n, grupo $(basename "$dir"))"
    return "$MEOW_DIVERGENTE"
  fi

  gravar_fixo "${lista[$alvo]}"
  # `cmd_aplicar` é quem escreve a configuração, e ele relê a fixação por
  # `resolver_rotacao`. Nada aqui escreve em `$BG` — um segundo escritor daquela
  # configuração é o defeito que o `cmd_aplicar` inteiro existe para evitar.
  cmd_aplicar >/dev/null || true
  meow_ok "papel de parede: $(basename "${lista[$alvo]}")  [$((alvo + 1))/$n · grupo $(basename "$dir")]"
  if [ "$(segundos_de "$FIXO_TTL")" -gt 0 ]; then
    meow_info "  o carrossel volta em $FIXO_TTL (ou agora, com 'meow wallpaper carrossel')"
  else
    meow_info "  fixado até você soltar: 'meow wallpaper carrossel'"
  fi
  return "$MEOW_DIVERGENTE"
}

# "QUERO ESTA, AGORA" — 07/09/2026
# A conferência de tarefas mediu o buraco: a jornada "fixar UMA imagem para
# sempre" não tinha verbo — a ficha da imagem oferecia Dia, Noite e Tirar, e a
# busca por "fixar" devolvia um gato. Toda a maquinaria já existia (o menu do
# botão direito fixa a PRÓXIMA via `gravar_fixo`); o que faltava era poder
# apontar QUAL. A duração é a mesma regra de sempre: `WALLPAPER_FIXO_TTL`
# manda, e com 0 a fixação dura até `meow wallpaper carrossel`.
cmd_usar() {
  local img="$1"
  [ -f "$img" ] || { meow_erro "não achei $img"; return "$MEOW_ERRO"; }
  if meow_seco; then
    meow_muda "fixaria $(basename "$img") como o papel de parede de agora"
    return "$MEOW_DIVERGENTE"
  fi
  criar_pastas || { meow_erro "não consegui criar as pastas"; return "$MEOW_ERRO"; }
  gravar_fixo "$img"
  # `cmd_aplicar` é quem escreve a configuração — mesma regra do `cmd_passo`:
  # um segundo escritor de `$BG` é o defeito que ele existe para evitar.
  cmd_aplicar >/dev/null || true
  meow_ok "papel de parede: $(basename "$img")"
  if [ "$(segundos_de "$FIXO_TTL")" -gt 0 ]; then
    meow_info "  o carrossel volta em $FIXO_TTL (ou agora, com 'meow wallpaper carrossel')"
  else
    meow_info "  fixado até você soltar: 'meow wallpaper carrossel'"
  fi
  return "$MEOW_DIVERGENTE"
}

cmd_carrossel() {
  if [ ! -f "$FIXADO" ]; then
    meow_ok "o carrossel já está girando — nada fixado"
    return "$MEOW_OK"
  fi
  if meow_seco; then meow_muda "soltaria a fixação e devolveria o carrossel"; return "$MEOW_DIVERGENTE"; fi
  soltar_fixo
  cmd_aplicar >/dev/null || true
  meow_ok "carrossel de volta"
  return "$MEOW_DIVERGENTE"
}

case "${1:-aplicar}" in
  aplicar)   cmd_aplicar ;;
  proximo|próximo|avançar|avancar)  cmd_passo 1 ;;
  anterior|voltar)                  cmd_passo -1 ;;
  carrossel|soltar)                 cmd_carrossel ;;
  # `--conferir` é a letra que TODO script deste projeto usa para auditar, e
  # este era o único que não a tinha: `docs/SPRINTS.md` mandava conferir o
  # carrossel com `./scripts/wallpaper.sh --conferir`, e o que acontecia era o
  # ramo de uso lá embaixo, com código 2 — a documentação apontando para um
  # comando inexistente desde que foi escrita. Aqui ela vira o que sempre
  # significou: o `aplicar` em seco, que não escreve e devolve 1 quando há o que
  # consertar.
  --conferir|conferir) MEOW_SECO=1; cmd_aplicar ;;
  estado)    cmd_estado ;;
  semear)    cmd_semear ;;
  banir)     shift; cmd_banir "${1:-}" ;;
  desbanir)  shift; cmd_desbanir "${1:-}" ;;
  adicionar) shift; cmd_adicionar "${1:-}" ;;
  permitir)  shift; cmd_permitir "${1:-}" ;;
  # O ÚNICO SUBCOMANDO DESTE ARQUIVO COM DOIS ARGUMENTOS, e isso importa para
  # quem for ligá-lo à CLI: o `cmd_wallpaper` do `bin/meow` encaminha UM só
  # (`"$acao" ${1:+"$1"}`), então `meow wallpaper lado <img> noite` chegaria aqui
  # sem o lado. Enquanto aquela linha não passar os dois, o caminho que funciona
  # é chamar este script direto.
  lado)      shift; cmd_lado "${1:-}" "${2:-}" ;;
  usar)      shift; cmd_usar "${1:-}" ;;
  *) echo "uso: wallpaper.sh [aplicar|proximo|anterior|usar <img>|carrossel|--conferir|estado|semear|adicionar <alvo>|banir <img>|desbanir <nome>|permitir <caminho>|lado <img> dia|noite|auto]" >&2; exit 2 ;;
esac

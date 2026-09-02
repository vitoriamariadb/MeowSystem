#!/usr/bin/env bash
# completar_icones.sh — os ícones que faltavam de verdade, e os dois que são dela.
#
# A LISTA DE "12 SEM ÍCONE" ERA FALSO POSITIVO — E O PORQUÊ IMPORTA MAIS
#   O levantamento que originou esta tarefa dizia que 12 dos `.desktop` da
#   máquina não tinham ícone em tema nenhum. Refeita a conta com o método que a
#   biblioteca de ícones usa de fato, o número é ZERO. Duas armadilhas fabricaram
#   os 12, e quem for reauditar cai nas duas de novo:
#
#     1. PROCURAR SÓ EM `**/apps/`. A busca de ícone do freedesktop não filtra
#        por contexto: varre TODOS os diretórios listados em `Directories=` do
#        `index.theme`. Conferido nome a nome no resolvedor real (as sete
#        resoluções abaixo saíram do `Gtk.IconTheme.lookup_icon` a 48px):
#            printer, input-keyboard, drive-removable-media  ->  48x48/devices/
#            dialog-information                              ->  48x48/status/
#            document-print-preview                          ->  24x24@2x/actions/
#            applications-system-symbolic                    ->  symbolic/categories/
#            mark-location-symbolic                          ->  symbolic/actions/
#        Restringir a `apps/` inventa essas SETE ausências — não oito. O oitavo
#        nome, `ibus-setup-chewing`, mora em `48x48/apps/` mesmo (é um link de
#        ARQUIVO para `ibus.svg`) e caiu pela armadilha 2, não por esta.
#
#     2. `find` E `os.walk` NÃO DESCEM EM DIRETÓRIO SIMBÓLICO — e no Papirus-Dark
#        o link está no NÍVEL DO TAMANHO, não dentro dele:
#            /usr/share/icons/Papirus-Dark/48x48 -> ../Papirus/48x48
#        Ou seja: sem `-L` a varredura não vê NENHUM ícone de 48px do tema, e não
#        só os de um contexto. Medido nesta máquina:
#            find    .../Papirus-Dark -name drive-removable-media.svg  ->  1 (só o 16x16, que é dir real)
#            find -L .../Papirus-Dark -name drive-removable-media.svg  -> 14
#            find    .../Papirus-Dark -name 'ibus-setup*'              ->  0 (some por completo)
#        Foi isso que fez `drive-removable-media` parecer existir só em 16x16.
#
#   O jeito certo é não andar no disco: LER o `index.theme` e testar o caminho
#   exato, que é o que a biblioteca faz. Conferido contra o resolvedor do GTK
#   (`Gtk.IconTheme.lookup_icon`, tema `MeowSystem-Icons`, 48px), ícone a ícone.
#
#   A auditoria geral e permanente é do `scripts/auditar_icones.sh`, de outra
#   frente. Este script não a repete: ele só confere as PRÓPRIAS pós-condições.
#
# ENTÃO O QUE ESTE SCRIPT CONSERTA, SE NADA FALTA?
#   As duas coisas que a auditoria correta aponta como problema DE VERDADE:
#
#   1. Os DOIS aplicativos dela (FogStripper e Hefesto) resolviam num PNG
#      RASTERIZADO no `hicolor` do usuário — o último elo da cadeia. Medido:
#          fogstripper            -> ~/.local/share/icons/hicolor/128x128/apps/fogstripper.png
#          hefesto-dualsense4unix -> ~/.local/share/icons/hicolor/48x48/apps/hefesto-dualsense4unix.png
#          com.vitoriamaria.HefestoDualsense4Unix -> /usr/share/icons/hicolor/256x256/apps/...png
#      Reduzidos a 48px e olhados: o do FogStripper (uma mão dissolvendo em
#      partículas sobre disco preto) vira um borrão escuro sem assunto; o do
#      Hefesto (martelo e bigorna num círculo roxo com anel rosa/azul) continua
#      LEGÍVEL — o problema dele não é sumir, é ser raster e estar fora da
#      paleta. Ganham SVG autoral, na paleta, por `gerar_icones_autorais.py`.
#
#   2. O `repoman` resolvia em `/usr/share/icons/Pop/48x48/apps/repoman.svg` —
#      ciano brilhante da marca do Pop!_OS no meio de uma grade Papirus. Nosso
#      `Inherits=` NÃO cita o Pop: ele entra por dentro do `Cosmic`
#      (`/usr/share/icons/Cosmic/index.theme` traz `Inherits=Pop,hicolor`), e é
#      por isso que ninguém acha o culpado olhando só o nosso índice. O Papirus
#      não tem `repoman` nenhum (conferido), então sem este script o ícone ou é
#      o do Pop ou é nada. É o único dos utilitários que destoa.
#
# E O QUE ELE DELIBERADAMENTE NÃO FAZ (a parte que é decisão, não preguiça)
#   Os outros 8 nomes da lista original resolvem no PRÓPRIO Papirus, na mesma
#   linguagem visual do resto do tema, e em tamanho grande (`printer`,
#   `input-keyboard`, `drive-removable-media` e `dialog-information` existem até
#   128x128). Não há o que consertar. Mais do que isso: sobrescrevê-los seria
#   ATIVAMENTE RUIM, por dois motivos distintos —
#
#     - São nomes GENÉRICOS, não nomes de aplicativo. `printer` é pedido pelo
#       painel de impressoras das Configurações, por diálogo de impressão, por
#       gerenciador de arquivos. Plantar `printer.svg` no nosso tema troca o
#       ícone de TODOS eles de uma vez, para consertar um `.desktop` que já
#       estava certo. O `repoman` é a exceção justamente por ser nome de
#       aplicativo: só o Repoman e o instalador de flatpak o pedem.
#
#     - `applications-system-symbolic` e `mark-location-symbolic` terminam em
#       `-symbolic`, e ícone simbólico é contrato: o toolkit o recolore para
#       casar com o tema. Substituí-lo por desenho colorido não deixa o ícone
#       colorido — deixa o desenho achatado numa cor só. É a mesma armadilha que
#       o applet LogoMenu cria com `custom_logo_path` (docs/COSMIC-THEMING.md §3).
#
# E O QUE ELE DEIXOU DE FAZER EM 11/08/2026: OS OITO `com.system76.Cosmic*`
#   Até esta data ele instalava aqui oito desenhos autorais — Arquivos, Terminal,
#   Loja, Ajustes, Editor, Monitor, Reprodutor e Captura de Tela. Eles nunca
#   estiveram "sem ícone"; o motivo de existirem era a cor de fábrica do Pop!_OS
#   (teal e azul-marinho, #00717C/#102A4C/#49BAC8), que não existe em Catppuccin
#   nenhum. O motivo era bom e a solução envelheceu mal.
#
#   O QUE ELA DECIDIU, DUAS VEZES
#     10/08/2026 — aprovou na folha (`scripts/folha_proposta.py:79-91`) os oito
#     glifos de LINHA do Arcticons para estes mesmos nomes, um a um.
#     11/08/2026 — mandou a captura do lançador: "no sentido de criarmos icons
#     igual o nosso tema atual", e reclamou nominalmente da PASTA MAUVE CHAPADA
#     dos Arquivos, que é justamente um destes oito autorais. O "nosso tema" é o
#     TRAÇO; o chapado é que destoa (docs/SPRINTS.md, Sprint J).
#
#   POR QUE TIRAR DO MAPA ARCTICONS NÃO BASTAVA, E É ESTE O PONTO
#     Os dois acervos escreviam o mesmo nome em diretórios diferentes — o autoral
#     aqui em `scalable/apps`, o Arcticons em `48x48/apps`. Duas verdades por
#     nome, e quem vence depende do tamanho pedido. O `strace` do resolvedor
#     (08/08/2026, registrado no docs/SPRINTS.md) mostra que a pilha COSMIC
#     costuma pedir direto em `scalable/apps` — ou seja, com o autoral instalado
#     AQUI, o chapado ganha na tela dela por mais que o mapa Arcticons diga outra
#     coisa. Uma verdade só por nome exige que este script pare de escrever os
#     oito E remova os que já pôs; a lista `RETIRADOS`, abaixo, é isso.
#
#   O QUE NÃO SAIU, E POR QUÊ
#     FogStripper, Hefesto (os dois nomes) e o apelido `repoman` continuam. Não
#     são a mesma pergunta: o Hefesto é a logo que ELA desenhou — autoria dela
#     vence tema, sempre —, o FogStripper resolvia num PNG rasterizado que vira
#     borrão a 48 px, e nenhum dos dois está no `apps-arcticons.map` disputando
#     nome com ninguém. A decisão sobre esses dois é dela e está numa folha.
#
#   COMO SE DESFAZ
#     Os oito SVGs continuam VERSIONADOS em `assets/icones/autorais/` e o gerador
#     continua produzindo-os: desfazer é mover os oito nomes de `RETIRADOS` de
#     volta para `AUTORAL` e tirar as oito linhas do `assets/icones/apps-arcticons.map`.
#     Nada foi apagado do repositório.
#
# ONDE ESCREVE, E POR QUE ISSO BASTA
#   `~/.local/share/icons/MeowSystem-Icons/scalable/apps/`. O tema selecionado é
#   o laço EXTERNO da busca (§2 do doc), então o nosso ganha do `hicolor` e do
#   `Pop` sem precisar de sudo e sem tocar em /usr/share. E `scalable/apps` já é
#   declarado no `Directories=` pelo `construir_icones.sh` — o que não estiver
#   declarado ali é invisível, por mais certo que esteja o arquivo.
#
# CÓPIA, NÃO SYMLINK PARA /usr/share
#   Mesmo raciocínio do `construir_pastas.sh`: um link para dentro do Papirus
#   amarra o tema à versão do pacote, e um `apt upgrade` que renomeie o arquivo
#   deixa link quebrado — que aparece como ícone sumido, sem dizer por quê.
#
# ELE NÃO REINICIA O PAINEL, DE PROPÓSITO
#   O `cosmic-panel` lê o tema no início da sessão. Reiniciá-lo faria os ícones
#   novos aparecerem na hora, mas o `construir_icones.sh` documenta (e sofreu) o
#   modo de falha: com o painel morto e revivido muitas vezes na mesma sessão, o
#   `cosmic-session` desiste, e ela fica sem painel e sem dock numa máquina de
#   UMA tela. Um segundo `pkill` no mesmo `install.sh`, só para adiantar um
#   refresh cosmético, não paga esse risco. Os arquivos ficam no disco e entram
#   na próxima leitura; o script diz a linha para quem quiser adiantar.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

TEMA_NOME="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA_NOME"
ALVO="$TEMA_DIR/scalable/apps"
BASE="${ICONES_BASE:-Papirus-Dark}"
BASE_DIR="/usr/share/icons/$BASE"
FLAVOR="${FLAVOR:-mocha}"
ACCENT="${ACCENT:-mauve}"
AUTORAIS="$RAIZ/assets/icones/autorais"

# --- os dois aplicativos dela: nome pedido pelo .desktop -> desenho autoral ----
# O Hefesto aparece com DOIS nomes de ícone na máquina, e os dois precisam do
# desenho: `hefesto-dualsense4unix` é o lançador (dela, em ~/.local) e
# `com.vitoriamaria.HefestoDualsense4Unix` é o applet empacotado (em
# /usr/share/applications). Instalar só o primeiro deixaria a janela/bandeja com
# o PNG antigo — a divergência só apareceria com o programa aberto.
#
# O terceiro nome, `com.vitoriamaria.HefestoDualsense4Unix-symbolic`, fica FORA:
# simbólico é monocromático por contrato e seria achatado numa cor só.
# O caminho da logo que a Vitória desenhou. Fora do repo de propósito: é obra
# dela, mora no projeto dela, e copiar para cá seria congelar uma versão.
LOGO_HEFESTO_DELA="$HOME/Desenvolvimento/hefesto-dualsense4unix/assets/hefesto-logo.svg"

declare -A AUTORAL=(
  [fogstripper]="fogstripper-$FLAVOR.svg"
  # EXCEÇÃO, a pedido dela: o Hefesto TEM logo própria, e foi ELA que desenhou
  # (~/Desenvolvimento/hefesto-dualsense4unix/assets/hefesto-logo.svg — a bigorna
  # com o martelo). O desenho autoral que eu tinha feito era um controle genérico,
  # sem identidade nenhuma perto do dela. Autoria dela vence tema, sempre.
  # Se o repositório não estiver no lugar, cai no desenho gerado — o instalador
  # não pode depender de um caminho fora dele.
  [hefesto-dualsense4unix]="__LOGO_DELA__"
  [com.vitoriamaria.HefestoDualsense4Unix]="__LOGO_DELA__"
)

# --- o que este script PLANTOU E AGORA TEM DE ARRANCAR ------------------------
# Os oito `com.system76.Cosmic*` moravam na tabela acima até 11/08/2026. Tirá-los
# de lá faz o script parar de escrever — e SÓ ISSO. O arquivo já instalado
# continuaria no disco para sempre, vencendo o Arcticons de `48x48/apps` toda vez
# que o resolvedor pedisse `scalable` (que é o caso comum, medido no `strace` de
# 08/08/2026). Uma lista de "parou de ser nosso" é o que fecha o buraco.
#
# POR QUE UMA LISTA NOMEADA, E NÃO UMA VARREDURA DE ÓRFÃOS
#   `scalable/apps` tem TRÊS donos — este script, o `logo.sh` (os botões do dock,
#   `com.system76.CosmicPanelAppButton` e `com.system76.CosmicAppLibrary`, que
#   casam com o mesmo prefixo `com.system76.Cosmic*`) e o bootstrap do
#   `construir_icones.sh`; o `assets/temas-de-apps/zapzap` também escrevia ali até hoje.
#   Varrer o que "não está na minha tabela" apagaria arquivo dos outros — é
#   exatamente o que o cabeçalho do `icones_apps_arcticons.sh` explica ao dizer
#   por que ele escolheu `48x48/apps` para ser dono. Então a remoção é por NOME,
#   e cada nome aqui é uma linha que alguém escreveu de propósito.
#
# ELA NÃO É SÓ PARA A LIMPEZA DE HOJE
#   Numa instalação nova ela não faz nada (o `[ -f ]` abaixo é falso) e não custa
#   nada. Mas ela continua valendo depois: quem rodar um `install.sh` de um
#   checkout ANTERIOR a 11/08/2026 replanta os oito, e a passagem seguinte com
#   este código os arranca de novo. Tirá-la faria isso virar um arquivo mudo no
#   disco outra vez.
RETIRADOS=(
  com.system76.CosmicFiles
  com.system76.CosmicTerm
  com.system76.CosmicStore
  com.system76.CosmicSettings
  com.system76.CosmicEdit
  com.system76.CosmicMonitor
  com.system76.CosmicPlayer
  com.system76.CosmicScreenshot
)

# --- apelidos de utilitário: nome pedido -> arquivo equivalente no Papirus -----
# Tabela curta de propósito. Cada linha aqui é um nome de ícone que passa a ser
# resolvido pelo NOSSO tema para sempre; o cabeçalho explica por que só o
# `repoman` entrou. `cs-sources` é o "fontes de software" do Cinnamon: o Repoman
# gerencia repositórios APT, então é o equivalente semântico, não só um ícone
# bonito. Escolhido entre 11 candidatos renderizados a 48px e olhados.
declare -A APELIDO=(
  [repoman]="64x64/apps/cs-sources.svg"
)

# --- do hicolor do SISTEMA: a marca de fábrica, quando ela é o que se quer ----
# A frase que estava aqui — "só entram os que o Papirus de fato não cobre" — era
# FALSA, e o único morador desta tabela é o contraexemplo. Medido em 10/08/2026:
#     ls -L /usr/share/icons/Papirus-Dark/*/apps/thunderbird.svg
#   devolve 16x16, 22x22, 24x24, 32x32, 48x48, 64x64, 128x128 (e os `@2x`), todos
#   VETOR. Sem esta tabela o Thunderbird não cairia no vazio: cairia num SVG
#   nítido em qualquer tamanho.
#
# Então o que esta tabela faz de verdade é OUTRA coisa: prefere a marca DE FÁBRICA
# ao desenho do Papirus. Isso é gosto, não técnica — e está aberto na página de
# curadoria junto com os outros. Tirar a linha é o desfazer completo: o `--aplicar`
# seguinte remove o arquivo do tema e o vetor do Papirus volta a valer.
#
# A FONTE É O RASTER GRANDE, E O DESTINO É O TAMANHO REAL DELE
#   Até 10/08/2026 aqui estava o PNG de **48**, despejado em `scalable/apps`.
#   Os dois erros somavam um só sintoma, que ela viu na grade do lançador: borrão.
#   `scalable/apps` declara `Size=128`, e quem escolhe o arquivo é o TAMANHO, não
#   a ordem (`docs/COSMIC-THEMING.md` §4d) — logo quem pedia 128 recebia 48
#   ampliado 2,7×. É o mesmo defeito do acervo em `512x512/apps`, de cabeça para
#   baixo. O sistema já traz o de 128 (`/usr/share/icons/hicolor/128x128/apps/`,
#   link para o `default128.png` do pacote), e o destino passa a sair do PRÓPRIO
#   CAMINHO da fonte, que no `hicolor` sempre carrega o `WxH`.
#
# A TABELA SAIU DO SCRIPT PORQUE ELA TEM DOIS LEITORES
#   O `icones_apps.sh` é dono de `<tam>/apps` e varre órfão lá dentro. Enquanto
#   esta lista morava aqui, ele não tinha como saber que `thunderbird.png` é de
#   outro dono — e o `install.sh` roda os dois na mesma passagem, nesta ordem.
#   O porquê inteiro, com a medição, está no cabeçalho do próprio mapa.
MAPA_HICOLOR="$RAIZ/assets/icones/apps-hicolor.map"
declare -A DO_HICOLOR=()
if [ -f "$MAPA_HICOLOR" ]; then
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    chave="${linha%%:*}"; caminho="${linha#*:}"
    [ -n "$chave" ] && [ -n "$caminho" ] || continue
    DO_HICOLOR["$chave"]="$caminho"
  done < "$MAPA_HICOLOR"
fi

mudou=0
avisos=0

# --- 0. o tema precisa existir e declarar scalable/apps ----------------------
# Sem isto o script "funciona" e não aparece nada: é a armadilha clássica de tema
# de ícones montado à mão, e o `Directories=` é a única chave de tamanho que a
# crate do COSMIC lê (docs/COSMIC-THEMING.md §2).
if [ ! -f "$TEMA_DIR/index.theme" ]; then
  meow_aviso "o tema '$TEMA_NOME' ainda não existe"
  meow_info "rode antes: scripts/construir_icones.sh"
  exit "$MEOW_SEM_DEPENDENCIA"
fi
if ! grep -q '^Directories=.*scalable/apps' "$TEMA_DIR/index.theme"; then
  meow_erro "'scalable/apps' não está no Directories= de $TEMA_DIR/index.theme"
  meow_info "sem essa declaração o ícone é ignorado mesmo estando no lugar certo"
  exit "$MEOW_ERRO"
fi
# O python3 desenha os SVGs a partir da paleta — mas os oito SVGs prontos ESTÃO
# VERSIONADOS em `assets/icones/autorais/`. Sair 3 aqui recusaria um trabalho que dá
# para fazer: numa máquina sem python3 os ícones já existem no clone e só faltava
# copiá-los. Então falta de python3 vira AVISO, e só vira dependência ausente
# (código 3) lá embaixo, se o flavor pedido de fato não estiver no repositório —
# aí sim ninguém consegue produzi-lo. Mesma disciplina do Papirus ausente.
SEM_PYTHON=0
if ! meow_tem python3; then
  meow_aviso "python3 ausente — não dá para conferir os SVGs contra a paleta"
  meow_info "  os autorais já versionados em assets/icones/autorais/ continuam entrando"
  SEM_PYTHON=1
  avisos=1
fi

meow_destino_permitido "$ALVO" || exit "$MEOW_ERRO"
meow_seco || mkdir -p "$ALVO" || { meow_erro "não consegui criar $ALVO"; exit "$MEOW_ERRO"; }

# --- 1. desenhar os autorais, se divergirem da paleta -------------------------
# `--conferir` primeiro: regerar sempre reescreveria 8 arquivos a cada execução
# e o `git status` nunca ficaria limpo.
if [ "$SEM_PYTHON" = "0" ] &&
   ! python3 "$RAIZ/scripts/gerar_icones_autorais.py" --accent "$ACCENT" --conferir >/dev/null 2>&1; then
  if meow_seco; then
    meow_muda "regeraria os SVGs autorais em assets/icones/autorais/"
    mudou=1
  else
    if ! python3 "$RAIZ/scripts/gerar_icones_autorais.py" --accent "$ACCENT" | sed 's/^/  /'; then
      meow_erro "falhou ao gerar os ícones autorais"
      exit "$MEOW_ERRO"
    fi
    mudou=1
  fi
fi

# --- 2. instalar os autorais no tema -----------------------------------------
instalados=0
for nome in "${!AUTORAL[@]}"; do
  fonte="$AUTORAIS/${AUTORAL[$nome]}"
  # A EXCEÇÃO: onde o mapa diz `__LOGO_DELA__`, a fonte é a logo que a Vitória
  # desenhou, no repositório do próprio app. Se ele não estiver no lugar (clone
  # ausente, disco não montado), cai no desenho gerado — o instalador não pode
  # ficar de pé ou não por causa de um caminho fora dele.
  if [ "${AUTORAL[$nome]}" = "__LOGO_DELA__" ]; then
    if [ -f "$LOGO_HEFESTO_DELA" ]; then
      fonte="$LOGO_HEFESTO_DELA"
    else
      fonte="$AUTORAIS/hefesto-$FLAVOR.svg"
      meow_info "a logo dela não está em $LOGO_HEFESTO_DELA — usando o desenho gerado"
    fi
  fi
  if [ ! -f "$fonte" ]; then
    # No seco o passo 1 não escreveu nada, então a fonte pode não existir ainda.
    if meow_seco; then
      meow_muda "instalaria $nome.svg (a fonte nasce no passo anterior)"
      continue
    fi
    if [ "$SEM_PYTHON" = "1" ]; then
      # Aqui, e SÓ aqui, a falta de python3 vira dependência ausente: o SVG deste
      # flavor não está no repositório e não há com que desenhá-lo.
      meow_erro "falta $fonte e não há python3 para desenhá-lo"
      meow_info "  instale python3 ou rode com um FLAVOR já versionado em assets/icones/autorais/"
      exit "$MEOW_SEM_DEPENDENCIA"
    fi
    meow_erro "falta $fonte — o gerador não produziu o flavor '$FLAVOR'"
    exit "$MEOW_ERRO"
  fi
  meow_escrever "$ALVO/$nome.svg" "$(cat "$fonte")" 644
  case $? in
    1) mudou=1; instalados=$((instalados+1)) ;;
    2) meow_erro "não consegui instalar $nome.svg"; exit "$MEOW_ERRO" ;;
  esac
done

# --- 2b. arrancar o que este script deixou de ser dono ------------------------
# Ver o comentário do `RETIRADOS`, acima. Enquanto o arquivo estiver aqui, o
# glifo de linha que ela aprovou em `48x48/apps` não chega à tela: o resolvedor
# pede `scalable` primeiro. Remover é o que torna a decisão dela visível.
retirados=0
for nome in "${RETIRADOS[@]}"; do
  [ -f "$ALVO/$nome.svg" ] || continue
  if meow_seco; then
    meow_muda "removeria $nome.svg de scalable/apps (o glifo de linha é o que vale)"
    mudou=1; retirados=$((retirados+1))
    continue
  fi
  meow_destino_permitido "$ALVO/$nome.svg" || exit "$MEOW_ERRO"
  if rm -f "$ALVO/$nome.svg"; then
    mudou=1; retirados=$((retirados+1))
  else
    meow_aviso "não consegui remover $ALVO/$nome.svg — o chapado continua vencendo"
    avisos=1
  fi
done
[ "$retirados" -gt 0 ] && ! meow_seco &&
  meow_ok "$retirados desenho(s) autorais retirados — quem veste os oito agora é o Arcticons"

# --- 3. apelidos vindos do Papirus -------------------------------------------
# Papirus ausente NÃO é erro: os autorais já entraram e o resto do tema continua
# de pé. Vira aviso, e o `repoman` segue com o ícone do Pop até o pacote existir.
if [ ! -d "$BASE_DIR" ]; then
  meow_aviso "$BASE não está instalado — apelidos de utilitário pulados"
  meow_info "  sudo apt install papirus-icon-theme"
  avisos=1
else
  for nome in "${!APELIDO[@]}"; do
    fonte="$BASE_DIR/${APELIDO[$nome]}"
    if [ ! -f "$fonte" ]; then
      # O Papirus renomeia arquivo entre versões. Dizer QUAL sumiu, em vez de
      # instalar um ícone vazio e deixar o sintoma para a tela dela.
      meow_aviso "o $BASE desta máquina não tem ${APELIDO[$nome]} — '$nome' fica como está"
      avisos=1
      continue
    fi
    meow_escrever "$ALVO/$nome.svg" "$(cat "$fonte")" 644
    case $? in
      1) mudou=1; instalados=$((instalados+1)) ;;
      2) meow_erro "não consegui instalar o apelido $nome.svg"; exit "$MEOW_ERRO" ;;
    esac
  done
fi

# --- 3b. a cache do tema, que engole ícone novo em silêncio -------------------
# MEDIDO nesta máquina, com um tema descartável: com um `icon-theme.cache` dentro
# do diretório do tema, o GTK lê a CACHE e ignora o disco — um SVG copiado depois
# dela simplesmente não existe para o resolvedor.
#     sem cache: teste-depois -> .../scalable/apps/teste-depois.svg
#     com cache: teste-depois -> (NAO ENCONTRADO)   (mesmo arquivo, mesmo tema)
# Nós nunca criamos essa cache — mas `gtk-update-icon-cache` rodado à mão, ou um
# instalador de terceiros, cria. Como o diretório do tema é inteiramente nosso, a
# presença dela só pode ser isso, e o conserto é reindexar (não apagar: quem a
# criou queria a cache). Só age se houver ícone MAIS NOVO que ela — sem essa
# condição o `-f` reescreveria o arquivo a cada rodada e o script escreveria duas
# vezes ao ser rodado duas vezes.
CACHE="$TEMA_DIR/icon-theme.cache"
if [ -f "$CACHE" ] && [ -n "$(find "$ALVO" -name '*.svg' -newer "$CACHE" -print -quit 2>/dev/null)" ]; then
  if meow_seco; then
    meow_muda "reindexaria a cache do tema ($CACHE está velha e esconde ícone novo)"
    mudou=1
  elif meow_tem gtk-update-icon-cache; then
    if gtk-update-icon-cache -q -f "$TEMA_DIR" 2>/dev/null; then
      meow_ok "cache do tema reindexada (ela escondia os ícones novos)"
      mudou=1
    else
      meow_aviso "não consegui reindexar $CACHE — apague-a se algum ícone não aparecer"
      avisos=1
    fi
  else
    meow_aviso "$CACHE está velha e esconde os ícones novos, e não há gtk-update-icon-cache"
    meow_info "  apague o arquivo: rm '$CACHE'"
    avisos=1
  fi
fi

# --- 4. conferir as PRÓPRIAS pós-condições -----------------------------------
# Três coisas têm de valer para um arquivo aqui virar ícone na tela, e as três
# falham CALADAS. As duas primeiras já foram conferidas lá em cima (o arquivo
# existe; `scalable/apps` está no `Directories=`). Falta a terceira, e é a que
# mais engana: o tema pode estar montado e perfeito e mesmo assim não ser o
# SELECIONADO — e aí nada disto aparece, porque o nome do tema é o laço externo
# da busca (docs/COSMIC-THEMING.md §2). Quem seleciona é o `construir_icones.sh`.
TK="$HOME/.config/cosmic/com.system76.CosmicTk/v1/icon_theme"
if [ -f "$TK" ] && ! grep -q "\"$TEMA_NOME\"" "$TK"; then
  meow_aviso "'$TEMA_NOME' NÃO é o tema de ícones selecionado — nada disto vai aparecer"
  meow_info "  rode: scripts/construir_icones.sh"
  avisos=1
fi

faltando=()
for nome in "${!DO_HICOLOR[@]}"; do
  fonte="${DO_HICOLOR[$nome]}"
  if [ ! -f "$fonte" ]; then
    meow_info "$nome: $fonte não existe — pulado"
    continue
  fi
  # PNG mesmo: renomear para `.svg` seria mentira e o renderizador reclamaria.
  #
  # O DIRETÓRIO É O TAMANHO REAL DO ARQUIVO, E NUNCA `scalable/`. Não há
  # `identify` aqui de propósito: o caminho do `hicolor` já CARREGA o tamanho
  # (`.../128x128/apps/`), e lê-lo dali não acrescenta dependência ao script.
  lado="$(basename "$(dirname "$(dirname "$fonte")")")"
  case "$lado" in
    [0-9]*x[0-9]*) : ;;
    *) meow_aviso "$nome: não consigo deduzir o tamanho de $fonte — pulado"
       avisos=1; continue ;;
  esac
  # Diretório no disco que ninguém DECLARA é diretório que ninguém acha (§2). Na
  # primeira instalação de uma máquina virgem o `128x128/apps` ainda não existe
  # quando este script roda (quem o cria é o `icones_apps.sh`, que vem depois, e
  # quem o declara é o `construir_icones.sh`, que vem antes) — então aqui se pula
  # com aviso, e a linha entra na rodada seguinte. Pular é seguro justamente por
  # causa da medição acima: enquanto isso o Thunderbird vem do vetor do Papirus.
  if ! grep -q "^Directories=.*${lado}/apps" "$TEMA_DIR/index.theme"; then
    meow_aviso "$nome: '${lado}/apps' ainda não está no Directories= — pulado"
    meow_info "  entra na próxima rodada, depois de scripts/construir_icones.sh"
    avisos=1; continue
  fi
  # O arquivo no lugar ERRADO tem de sair, senão ficam DOIS donos do mesmo nome e
  # a regra da extensão (§2) faz um deles vencer sem ninguém ter decidido. É o
  # que sobra do `scalable/apps/thunderbird.png` de antes de 10/08/2026.
  if [ -f "$ALVO/$nome.png" ]; then
    if meow_seco; then
      meow_muda "removeria $nome.png de scalable/apps (raster em diretório escalável)"
      mudou=1
    else
      rm -f "$ALVO/$nome.png" && mudou=1
    fi
  fi
  alvo_png="$TEMA_DIR/$lado/apps/$nome.png"
  if [ ! -f "$alvo_png" ] || ! cmp -s "$fonte" "$alvo_png"; then
    if meow_seco; then
      meow_muda "copiaria $nome do hicolor do sistema para $lado/apps"
    else
      meow_destino_permitido "$alvo_png" || exit "$MEOW_ERRO"
      mkdir -p "$TEMA_DIR/$lado/apps"
      cp -f "$fonte" "$alvo_png" && chmod 644 "$alvo_png" && mudou=1
    fi
  fi
done

for nome in "${!AUTORAL[@]}" "${!APELIDO[@]}"; do
  [ -f "$ALVO/$nome.svg" ] || faltando+=("$nome")
done
if [ ${#faltando[@]} -gt 0 ] && ! meow_seco; then
  meow_aviso "não chegaram ao tema: ${faltando[*]}"
  avisos=1
fi

# A auditoria geral (todos os .desktop da máquina) é de outra frente. Só aponta.
[ -x "$RAIZ/scripts/auditar_icones.sh" ] &&
  meow_info "auditoria completa da máquina: ./scripts/auditar_icones.sh"

if [ "$mudou" = "0" ]; then
  meow_ok "ícones completos: ${#AUTORAL[@]} autorais e ${#APELIDO[@]} apelido(s) já no lugar"
  exit "$MEOW_OK"
fi

if meow_seco; then
  exit "$MEOW_DIVERGENTE"
fi

if [ "$instalados" = "0" ]; then
  # Chega-se aqui quando os SVGs já estavam certos e o que divergia era outra
  # coisa (a cache do tema, ou os fontes regerados por troca de ACCENT). Dizer
  # "0 ícones instalados" faria parecer que o script não fez nada.
  meow_ok "os ícones já estavam no lugar; o que divergia acima foi corrigido"
else
  meow_ok "$instalados ícone(s) instalados em $ALVO"
fi
meow_info "o painel só relê no início da sessão — para ver agora: meow painel reciclar"
[ "$avisos" = "1" ] && meow_info "houve avisos acima; nada ficou pela metade"
meow_notificar "MeowSystem" "Ícones completados ($instalados)."
exit "$MEOW_DIVERGENTE"

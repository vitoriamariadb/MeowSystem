#!/usr/bin/env bash
# icones_resgatados.sh — instala no tema os ícones que voltaram a ser VETOR
# depois de terem existido só como PNG.
#
# O QUE ACONTECEU, E POR QUE ISTO NÃO É "MAIS UM CONVERSOR"
#   Ela desenhou os ícones dos projetos dela, exportou para PNG, e perdeu os SVG
#   originais. Sobrou o PNG — e PNG num COSMIC a 100% de escala numa tela de 24"
#   é exatamente o que ela descreveu em 11/09/2026: "meus pngs originais ficaram
#   horríveis aqui no cosmic". Um ícone de 128 px esticado para o tamanho do
#   dock não tem para onde ir.
#
#   Medido no mesmo dia, deduplicando por ID de `.desktop` (o arquivo em
#   ~/.local/share/applications SOMBREIA o de /usr/share, então contar os dois
#   dá número inflado): dos 86 nomes de ícone distintos que os 91 aplicativos
#   visíveis pedem, 66 resolviam para SVG e 20 caíam em PNG. Os 20 são os que
#   este script instala.
#
#   O `construir_convertidos.sh` NÃO servia para isto, e a diferença é de
#   intenção: ele REESCREVE arte de terceiro no traço monocromático do Arcticons,
#   para o app caber no tema. Aqui a arte já era dela e já estava certa — o que
#   se perdeu foi o arquivo. Passar esses ícones pelo conversor seria jogar fora
#   justamente o que se quer de volta. Por isso o desenho é DECALQUE: gradiente
#   vira `<linearGradient>` de verdade, sombra vira `<filter>`, e o que não se
#   reproduz é só o ruído de compressão do PNG.
#
# POR QUE `scalable/apps` E NÃO `48x48/apps`
#   `48x48/apps` é `Type=Fixed` e tem dono declarado — o `icones_apps_arcticons.sh`
#   é dono único dele e reescreve por conteúdo divergente; escrever ali seria
#   disputar arquivo com outro script. `scalable/apps` é `Type=Scalable`
#   (Size=128, MinSize=8, MaxSize=512 no nosso index.theme) e já é onde os
#   desenhos autorais moram, postos pelo `completar_icones.sh`.
#   E é o lugar que FUNCIONA: o cabeçalho do `completar_icones.sh` registra, do
#   strace de 08/08/2026, que o resolvedor pede `scalable` no caso comum e que um
#   arquivo ali vence o `48x48`. Um ícone escalável é o que resolve um ícone
#   borrado — pôr o resgate no diretório de tamanho fixo seria trocar um PNG de
#   128 px por um SVG travado em 48.
#
# O INTERRUPTOR É DELA — `ICONES_RESGATADOS`
#   "de resto quero ter poder de escolha no meowsystem" (11/09/2026). Então:
#   `sim` instala, `nao` REMOVE o que este script pôs e devolve o PNG que estava
#   valendo. Não há terceiro estado e não há estado guardado em lugar nenhum: a
#   remoção é por NOME, lida do mesmo mapa que a instalação lê, pela mesma razão
#   que o `completar_icones.sh` mantém uma lista de "parou de ser nosso" — uma
#   varredura de órfãos apagaria arquivo dos outros dois donos de `scalable/apps`.
#
# OS TRÊS `.desktop` COM `Icon=` ABSOLUTO — o caso que o tema não alcança
#   `elden-ring-tracker`, `guvcview` e `setup-mozc` trazem o CAMINHO do PNG na
#   chave `Icon=`, em vez de um nome de ícone. Um `Icon=` absoluto PULA a busca
#   no tema inteira: não adianta ter o SVG instalado, o lançador vai ler o
#   arquivo apontado e pronto.
#   Dois deles já têm arquivo em ~/.local/share/applications, que é onde este
#   script pode escrever; `elden-ring-tracker.desktop` só existe em /usr/share,
#   território do gerenciador de pacotes (e o `meow_destino_permitido` recusaria
#   escrever lá, corretamente). A saída é a que o XDG desenhou para isso: uma
#   CÓPIA em ~/.local/share/applications com o mesmo nome de arquivo sombreia a
#   do sistema. Copiar o arquivo inteiro e trocar uma linha preserva Exec,
#   Categories e traduções, e desligar o interruptor apaga a cópia — o do
#   sistema volta a valer sozinho, intacto.
#
#   `setup-mozc` fica de fora desta parte: ele é `NoDisplay=true`, não aparece no
#   lançador, e mexer no `.desktop` dele seria trabalho sem nada na tela para
#   mostrar. O SVG é instalado assim mesmo, porque custa um arquivo e cobre o dia
#   em que algo pedir o ícone por nome.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

TEMA_NOME="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA_NOME"
ALVO="$TEMA_DIR/scalable/apps"
ACERVO="$RAIZ/assets/icones/resgatados"
MAPA="$RAIZ/assets/icones/apps-resgatados.map"
APPS_USUARIO="$HOME/.local/share/applications"

# Os `.desktop` cujo `Icon=` é caminho absoluto, e o nome de ícone que cada um
# passa a usar. A chave é o ARQUIVO, porque é ele que a cópia local sombreia.
declare -A DESKTOP_ABSOLUTO=(
  [elden-ring-tracker.desktop]="elden-ring-tracker"
  [guvcview.desktop]="guvcview"
)

# --- o mapa -------------------------------------------------------------------
# Uma linha por ícone: `nome : png-de-origem : autoria`. Só o primeiro campo
# interessa aqui — os outros dois são procedência, e quem os lê é a folha de
# antes-e-depois e quem for abrir o mapa para entender de onde veio o desenho.
_resgatados_nomes() {
  [ -f "$MAPA" ] || return 1
  sed -e 's/#.*//' "$MAPA" | awk -F: 'NF>=3 { gsub(/^[ \t]+|[ \t]+$/, "", $1); if ($1 != "") print $1 }'
}

# --- instalar -----------------------------------------------------------------
_resgatados_instalar() {
  local rc=0 nome origem svg
  local postos=0 faltando=()

  while read -r nome; do
    [ -n "$nome" ] || continue
    origem="$ACERVO/$nome.svg"
    if [ ! -f "$origem" ]; then
      # Nome no mapa sem desenho no acervo: é falha de quem editou o mapa, e
      # dizer qual é vale mais que um total. Não aborta — os outros 19 não têm
      # culpa de um nome digitado errado.
      faltando+=("$nome"); continue
    fi
    svg="$(cat "$origem")" || { meow_erro "não consegui ler $origem"; rc=2; continue; }
    meow_escrever "$ALVO/$nome.svg" "$svg" 644
    case $? in
      0) : ;;
      1) postos=$((postos+1)) ;;
      *) rc=2 ;;
    esac
  done < <(_resgatados_nomes)

  if [ "${#faltando[@]}" -gt 0 ]; then
    meow_aviso "no mapa mas sem desenho em assets/icones/resgatados/: ${faltando[*]}"
    [ "$rc" = "0" ] && rc=1
  fi

  local rc_d; _resgatados_desktops_instalar; rc_d=$?
  [ "$rc_d" = "2" ] && rc=2
  [ "$rc_d" = "1" ] && [ "$rc" = "0" ] && rc=1

  local rc_c; _resgatados_cache; rc_c=$?
  [ "$rc_c" = "1" ] && [ "$rc" = "0" ] && rc=1

  if [ "$postos" -gt 0 ]; then
    meow_ok "$postos ícone(s) resgatado(s) no tema"
    _resgatados_avisar
    rc=1
  elif [ "$rc" = "0" ]; then
    meow_debug "os resgatados já estavam todos no lugar"
  fi
  return "$rc"
}

# O ARQUIVO CERTO, NO LUGAR CERTO, E A TELA NÃO MUDA — 12/09/2026
#   O `cosmic-app-library` e o `cosmic-panel` NÃO ligam em GTK:
#       ldd /usr/bin/cosmic-app-library | grep -c libgtk   ->  0
#   Eles são libcosmic/iced e varrem o tema de ícones AO NASCER, guardando o
#   resultado em memória. Um SVG que chega depois disso não existe para eles até
#   o processo reiniciar — nem reindexar a cache do GTK ajuda, porque não é a
#   cache do GTK que eles leem.
#
#   Foi exatamente o que aconteceu na primeira instalação: os dois estavam de pé
#   desde as 23:13, os ícones entraram às 01:43, o `meow icones resgatados` dizia
#   "22 de 22" e a tela continuava com os antigos. A pergunta foi "mas pq elas
#   não tao funcionando agora?" — e não havia nada errado com os arquivos.
#
#   POR QUE ISTO AVISA EM VEZ DE REINICIAR SOZINHO
#     Reiniciar o painel é derrubar a topbar e a dock da tela dela por alguns
#     segundos, e o `meow-painel.service` existe justamente porque o supervisor
#     do COSMIC tem um backoff SEM TETO que já deixou esta máquina 16h sem barra
#     (ver o cabeçalho daquela unidade). Um `pkill` escondido dentro de "instalei
#     um ícone" é caro demais para ser efeito colateral de outra coisa — e o
#     `install.sh` roda este script no meio de trinta etapas.
#     Quem decide derrubar a barra é ela, com a linha impressa aqui na mão.
_resgatados_avisar() {
  meow_info "  o painel e o lançador leem o tema ao nascer e guardam em memória —"
  meow_info "  para ver agora, sem esperar o próximo login:"
  meow_info "      pkill -x cosmic-panel && pkill -f cosmic-app-library"
}

# A CACHE DO TEMA, QUE ENGOLE ÍCONE NOVO EM SILÊNCIO
#   Com um `icon-theme.cache` dentro do diretório do tema, o GTK lê a CACHE e
#   IGNORA o disco: um SVG copiado depois dela simplesmente não existe para o
#   resolvedor. O `completar_icones.sh` já media isso, e o commit 0a24198 é a
#   mesma história do outro lado (a cache do hicolor escondendo as capas de jogo).
#
#   ESTE SCRIPT NASCEU SEM ISTO, e o buraco era real: instalar deixava a cache
#   mais velha que os arquivos, e quem quisesse o efeito na tela dependia de
#   alguém lembrar de reindexar à mão. Reindexar tem de ser parte de instalar.
#
#   O QUE ESTA GUARDA **NÃO** CONSERTA — e vale dizer, porque em 12/09/2026 eu
#   apontei para ela como causa de um sintoma que era de outra coisa:
#     Quando os ícones não apareceram, a cache velha foi a primeira suspeita. Ao
#     tentar reproduzir — `touch -d 2020` na cache e consultar de novo — o GTK
#     achou os 22 assim mesmo, porque a cache JÁ TINHA as entradas e envelhecer
#     a data não as remove. A causa era outra: o `cosmic-app-library` e o
#     `cosmic-panel` estavam de pé desde as 23:13, e os ícones chegaram às 01:43.
#     Nenhum dos dois liga em GTK (`ldd` não devolve libgtk); eles varrem o tema
#     ao nascer, guardam em memória e não releem. Dois processos reiniciados
#     resolveram, sem tocar em cache nenhuma.
#   Ou seja: esta guarda cobre o resolvedor GTK, e não cobre os clientes
#   libcosmic. Para esses, o que vale é reiniciar — ver `_resgatados_avisar`.
#
#   SÓ AGE SE HOUVER ÍCONE MAIS NOVO QUE ELA — sem essa condição o `-f`
#   reescreveria a cache a cada rodada, e um script que escreve ao ser rodado
#   duas vezes não é idempotente. Mesma guarda do `completar_icones.sh`.
#   E REINDEXA, NÃO APAGA: quem criou a cache queria a cache.
_resgatados_cache() {
  local cache="$TEMA_DIR/icon-theme.cache"
  [ -f "$cache" ] || return 0
  [ -n "$(find "$ALVO" -name '*.svg' -newer "$cache" -print -quit 2>/dev/null)" ] || return 0

  if meow_seco; then
    meow_muda "reindexaria a cache do tema ($cache está velha e esconde os resgatados)"
    return 1
  fi
  if ! meow_tem gtk-update-icon-cache; then
    meow_aviso "$cache está velha e esconde os ícones novos, e não há gtk-update-icon-cache"
    meow_info  "  apague o arquivo: rm '$cache'"
    return 1
  fi
  if gtk-update-icon-cache -q -f "$TEMA_DIR" 2>/dev/null; then
    meow_ok "cache do tema reindexada (ela escondia os resgatados)"
    return 1
  fi
  meow_aviso "não consegui reindexar $cache — apague-a se algum ícone não aparecer"
  return 1
}

# A cópia local do `.desktop`, para os que trazem o PNG por caminho absoluto.
# É `sed` numa linha só e o resto do arquivo passa intacto: trocar `Icon=` sem
# tocar em `Exec`, `Categories` ou nas traduções é o ponto.
_resgatados_desktops_instalar() {
  local rc=0 arquivo nome origem conteudo destino
  for arquivo in "${!DESKTOP_ABSOLUTO[@]}"; do
    nome="${DESKTOP_ABSOLUTO[$arquivo]}"
    [ -f "$ACERVO/$nome.svg" ] || continue   # sem desenho, não há o que apontar
    origem="/usr/share/applications/$arquivo"
    destino="$APPS_USUARIO/$arquivo"
    # Se já existe cópia local, ela é a base — senão, a do sistema. Assim um
    # arquivo que ELA editou não é substituído pelo de fábrica.
    [ -f "$destino" ] && origem="$destino"
    [ -f "$origem" ] || continue
    conteudo="$(sed -E "s|^Icon=.*|Icon=$nome|" "$origem")" || { rc=2; continue; }
    meow_escrever "$destino" "$conteudo" 644
    case $? in 0) : ;; 1) [ "$rc" = "0" ] && rc=1 ;; *) rc=2 ;; esac
  done
  return "$rc"
}

# --- remover ------------------------------------------------------------------
# Desligar desliga: some o SVG que este script pôs, e o PNG que estava atrás dele
# volta a ser o que o resolvedor acha. Por NOME, nunca por varredura — o
# `scalable/apps` tem outros dois donos.
_resgatados_remover() {
  local rc=0 nome tirados=0 arquivo
  while read -r nome; do
    [ -n "$nome" ] || continue
    [ -f "$ALVO/$nome.svg" ] || continue
    if meow_seco; then
      meow_muda "removeria $ALVO/$nome.svg"; rc=1; continue
    fi
    rm -f "$ALVO/$nome.svg" && tirados=$((tirados+1)) || rc=2
  done < <(_resgatados_nomes)

  # A cópia local do `.desktop` some inteira: ela só existia para trocar o
  # `Icon=`, e o arquivo do sistema por baixo volta a valer intacto.
  for arquivo in "${!DESKTOP_ABSOLUTO[@]}"; do
    [ -f "$APPS_USUARIO/$arquivo" ] || continue
    [ -f "/usr/share/applications/$arquivo" ] || continue  # sem original, não apaga
    grep -q "^Icon=${DESKTOP_ABSOLUTO[$arquivo]}$" "$APPS_USUARIO/$arquivo" || continue
    if meow_seco; then
      meow_muda "removeria $APPS_USUARIO/$arquivo"; rc=1; continue
    fi
    rm -f "$APPS_USUARIO/$arquivo" || rc=2
  done

  # REMOVER TAMBÉM SUJA A CACHE, e o sintoma é pior que o de instalar: ela segue
  # anunciando um `.svg` que não existe mais, e o GTK NÃO cai para o PNG de trás
  # — ele pede o arquivo que a cache prometeu, não acha, e desenha o ícone
  # genérico. Ou seja, desligar o interruptor deixaria a tela pior do que antes
  # de o resgate existir. O `-newer` não serve aqui (arquivo apagado não tem
  # data), então a condição é ter apagado alguma coisa.
  if [ "$tirados" -gt 0 ] && [ -f "$TEMA_DIR/icon-theme.cache" ] && meow_tem gtk-update-icon-cache; then
    gtk-update-icon-cache -q -f "$TEMA_DIR" 2>/dev/null \
      && meow_ok "cache do tema reindexada (ela ainda anunciava os retirados)" \
      || meow_aviso "não consegui reindexar a cache — apague $TEMA_DIR/icon-theme.cache se algum ícone sumir"
  fi

  [ "$tirados" -gt 0 ] && { meow_ok "$tirados ícone(s) resgatado(s) retirado(s) do tema"; rc=1; }
  return "$rc"
}

# --- estado -------------------------------------------------------------------
_resgatados_estado() {
  local total=0 postos=0 nome
  while read -r nome; do
    [ -n "$nome" ] || continue
    total=$((total+1))
    [ -f "$ALVO/$nome.svg" ] && postos=$((postos+1))
  done < <(_resgatados_nomes)
  printf '%s %s' "$postos" "$total"
}

# --- ponto de entrada ---------------------------------------------------------
_resgatados_aplicar() {
  if [ "${ICONES_RESGATADOS:-sim}" = "sim" ]; then _resgatados_instalar
  else _resgatados_remover; fi
}

case "${1:-aplicar}" in
  aplicar|--aplicar) _resgatados_aplicar ;;
  # `--conferir` é o `aplicar` de olhos abertos e mãos no bolso: o `meow_seco`
  # faz o `meow_escrever` relatar em vez de gravar, e o código de saída 1 é o que
  # o `meow doctor` lê como "divergente". Um verificador que fosse código à parte
  # do aplicador é como se mede uma coisa e se conserta outra.
  --conferir) MEOW_SECO=1 _resgatados_aplicar ;;
  instalar) _resgatados_instalar ;;
  remover)  _resgatados_remover ;;
  estado)   _resgatados_estado ;;
  *) printf 'uso: icones_resgatados.sh [aplicar|--conferir|instalar|remover|estado]\n' >&2; exit 2 ;;
esac

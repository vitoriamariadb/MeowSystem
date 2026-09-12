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
ALVO="$HOME/.local/share/icons/$TEMA_NOME/scalable/apps"
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

  if [ "$postos" -gt 0 ]; then
    meow_ok "$postos ícone(s) resgatado(s) no tema"
    rc=1
  elif [ "$rc" = "0" ]; then
    meow_debug "os resgatados já estavam todos no lugar"
  fi
  return "$rc"
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

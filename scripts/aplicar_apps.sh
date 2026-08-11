#!/usr/bin/env bash
# aplicar_apps.sh — roda os módulos de tema por aplicativo, um a um.
#
# CADA APP É UMA UNIDADE QUE PODE FALHAR SOZINHA (regra 8 do contrato)
#   Um módulo devolve 0 (nada a fazer), 1 (aplicou), 2 (erro) ou 3 (app ausente).
#   Nenhum deles pode derrubar os outros nem o `install.sh`: por isso são
#   carregados com `source` num SUBSHELL, e por isso o contrato proíbe `exit`
#   dentro deles — um `exit` num módulo mataria o instalador inteiro.
#
# POR QUE SUBSHELL, E NÃO `source` DIRETO
#   Os módulos definem as mesmas três funções com os mesmos nomes. Carregados no
#   mesmo shell, o segundo sobrescreveria o primeiro e o terceiro rodaria com
#   pedaços do segundo. O subshell também garante que uma variável esquecida por
#   um módulo não vaze para o seguinte.
#
# APP AUSENTE NÃO É ERRO
#   É "pendente". No dia em que ela instalar o app, o próximo ciclo o tematiza
#   sozinho — e é isso que faz o `doctor --consertar` valer a pena.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

# aplicar | conferir | tabela | reverter
#
# `reverter` é o único que não roda sozinho nunca: o `install.sh` e o doctor das
# 05:00 chamam `aplicar`, e desfazer é decisão dela, digitada. Ver o `case` do
# `rodar_modulo`, onde ele é opcional por módulo.
#
# `tabela` existe para o `meow apps` não precisar de uma SEGUNDA cópia do
# `pasta_de` e do `rodar_modulo`. Ele imprime TSV cru — uma linha por módulo,
# `pasta<TAB>slugs<TAB>rc_detectar<TAB>rc_conferir` — e quem pinta a tabela é a
# CLI. Duas listas de slug-para-pasta em arquivos diferentes é como se ganha uma
# tabela que mente sobre um app três meses depois.
ACAO="${1:-aplicar}"
APPS="${APPS_ATIVOS:-}"

declare -a APLICADOS=() JA_OK=() PENDENTES=() FALHOS=()

# O slug do meow.conf nem sempre é o nome da pasta: `bat` e `btop` moram juntos
# num módulo só (compartilham o padrão de instalação e nenhum dos dois está
# instalado hoje), e os toolkits idem.
pasta_de() {
  case "$1" in
    bat|btop) echo "btop-bat" ;;
    qt5ct|gtk|qt) echo "toolkits-gtk-qt" ;;
    *) echo "$1" ;;
  esac
}

rodar_modulo() {
  local pasta="$1" acao="$2"
  local mod="$RAIZ/app-themes/$pasta/manifesto.sh"
  [ -f "$mod" ] || return 4          # 4 = não temos módulo para esse app ainda
  (
    # shellcheck disable=SC1090
    . "$mod" || exit 2
    # AÇÃO DESCONHECIDA NÃO PODE CAIR EM `aplicar` — E CAÍA, ATÉ 08/08/2026.
    #   O `*)` daqui mandava qualquer coisa para `meow_app_aplicar`: um erro de
    #   digitação (`conferrir`) ESCREVIA, em vez de dizer que não existe. Num
    #   projeto cujo modo de auditar é `--conferir`, essa é a pior letra a
    #   errar. Agora `aplicar` é explícito e o resto é erro de execução.
    case "$acao" in
      detectar)        meow_app_detectar ;;
      conferir)        meow_app_conferir ;;
      aplicar)         meow_app_aplicar ;;
      # QUARTO VERBO, E OPCIONAL DE PROPÓSITO. Só o `spotify` sabe desfazer hoje
      # — desde 10/08/2026 chamando `spicetify restore`, que devolve o
      # `xpui.spa` de fábrica byte a byte (conferido: sha256 5ec1901f…, o mesmo
      # do backup guardado). Um módulo que não sabe desfazer diz isso em voz
      # alta e vira "pendente" — fingir que desfez seria pior do que não ter o
      # verbo, porque ela deixaria de procurar o caminho que funciona.
      reverter)
        if declare -F meow_app_reverter >/dev/null; then
          meow_app_reverter
        else
          meow_pula "o módulo '$pasta' não sabe desfazer"
          exit "$MEOW_SEM_DEPENDENCIA"
        fi ;;
      *) meow_erro "ação desconhecida para o módulo '$pasta': $acao"; exit 2 ;;
    esac
  )
}

# --- modo tabela ------------------------------------------------------------
# Sai antes do laço normal porque a saída é para ser lida por outro programa:
# uma linha de log misturada no TSV viraria uma coluna fantasma na tela dela.
if [ "$ACAO" = "tabela" ]; then
  vistos=""
  declare -A SLUGS_DE=()
  declare -a ORDEM=()
  IFS=',' read -ra LISTA <<< "$APPS"
  for slug in "${LISTA[@]}"; do
    slug="$(printf '%s' "$slug" | tr -d ' ')"
    [ -n "$slug" ] || continue
    pasta="$(pasta_de "$slug")"
    [ -f "$RAIZ/app-themes/$pasta/manifesto.sh" ] || continue
    case " $vistos " in
      *" $pasta "*) SLUGS_DE[$pasta]="${SLUGS_DE[$pasta]}, $slug"; continue ;;
    esac
    vistos="$vistos $pasta"
    ORDEM+=("$pasta")
    SLUGS_DE[$pasta]="$slug"
  done
  for pasta in "${ORDEM[@]}"; do
    rodar_modulo "$pasta" detectar >/dev/null 2>&1; rc_det=$?
    rodar_modulo "$pasta" conferir >/dev/null 2>&1; rc_conf=$?
    printf '%s\t%s\t%s\t%s\n' "$pasta" "${SLUGS_DE[$pasta]}" "$rc_det" "$rc_conf"
  done
  exit "$MEOW_OK"
fi

vistos=""
IFS=',' read -ra LISTA <<< "$APPS"
for slug in "${LISTA[@]}"; do
  slug="$(printf '%s' "$slug" | tr -d ' ')"
  [ -n "$slug" ] || continue
  pasta="$(pasta_de "$slug")"
  # bat e btop apontam para o mesmo módulo: rodar duas vezes só duplicaria a saída.
  case " $vistos " in *" $pasta "*) continue ;; esac
  vistos="$vistos $pasta"

  rodar_modulo "$pasta" "$ACAO"
  case $? in
    0) JA_OK+=("$pasta") ;;
    1) APLICADOS+=("$pasta") ;;
    3) PENDENTES+=("$pasta") ;;
    4) ;;                            # sem módulo ainda: silêncio, não é falha
    *) FALHOS+=("$pasta") ;;
  esac
done

# O RÓTULO SEGUE A AÇÃO — dizer "aplicados" num `conferir` é mentira medida.
#   `meow apps conferir` (que NÃO escreve nada) terminava anunciando
#   `ok aplicados: zapzap toolkits-gtk-qt`. Quem lesse concluiria que o comando
#   de auditoria tinha mexido na máquina. O bucket é o mesmo (rc=1); o que muda
#   é o que 1 SIGNIFICA em cada ação: no aplicar, "consertei"; no conferir,
#   "diverge". É a mesma disciplina do tempo verbal no modo seco.
if [ ${#APLICADOS[@]} -gt 0 ]; then
  case "$ACAO" in
    conferir) meow_muda "divergentes: ${APLICADOS[*]}" ;;
    reverter) meow_ok   "desfeitos: ${APLICADOS[*]}" ;;
    *)        meow_ok   "aplicados: ${APLICADOS[*]}" ;;
  esac
fi
[ ${#JA_OK[@]}     -gt 0 ] && meow_ok   "já estavam certos: ${JA_OK[*]}"
[ ${#PENDENTES[@]} -gt 0 ] && meow_pula "pendentes (app não instalado, ou não dá para agir agora): ${PENDENTES[*]}"
[ ${#FALHOS[@]}    -gt 0 ] && meow_erro "falharam: ${FALHOS[*]}"

[ ${#FALHOS[@]}    -gt 0 ] && exit "$MEOW_ERRO"
[ ${#APLICADOS[@]} -gt 0 ] && exit "$MEOW_DIVERGENTE"
exit "$MEOW_OK"

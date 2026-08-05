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

# aplicar | conferir | tabela
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
    case "$acao" in
      detectar) meow_app_detectar ;;
      conferir) meow_app_conferir ;;
      *)        meow_app_aplicar ;;
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

[ ${#APLICADOS[@]} -gt 0 ] && meow_ok   "aplicados: ${APLICADOS[*]}"
[ ${#JA_OK[@]}     -gt 0 ] && meow_ok   "já estavam certos: ${JA_OK[*]}"
[ ${#PENDENTES[@]} -gt 0 ] && meow_pula "pendentes (app não instalado): ${PENDENTES[*]}"
[ ${#FALHOS[@]}    -gt 0 ] && meow_erro "falharam: ${FALHOS[*]}"

[ ${#FALHOS[@]}    -gt 0 ] && exit "$MEOW_ERRO"
[ ${#APLICADOS[@]} -gt 0 ] && exit "$MEOW_DIVERGENTE"
exit "$MEOW_OK"

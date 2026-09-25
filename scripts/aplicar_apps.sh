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
# `pasta<TAB>slugs<TAB>rc_instalado<TAB>rc_conferir<TAB>motivo` (a terceira era
# o `rc_detectar` até 24/09/2026, P49; o motivo do 3 entrou em 25/09, P62) — e
# quem pinta a tabela é a CLI. Duas
# listas de slug-para-pasta em arquivos diferentes é como se ganha uma tabela
# que mente sobre um app três meses depois.
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
  local mod="$RAIZ/assets/temas-de-apps/$pasta/manifesto.sh"
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
      # QUARTO VERBO. Desde 11/08/2026 os SETE módulos sabem desfazer — antes
      # era só o `spotify` (que chama `spicetify restore` e devolve o `xpui.spa`
      # de fábrica byte a byte: sha256 5ec1901f…, o mesmo do backup guardado).
      #
      # O QUE MUDOU, E POR QUE O VERBO CONTINUA OPCIONAL
      #   O `install.sh --uninstall` passou a chamar `reverter` (passo 2/6 de
      #   lib/desinstalar.sh). Enquanto seis módulos não sabiam desfazer, o
      #   desinstalador só levava embora o que passava pela `meow_escrever`, e o
      #   Spotify, o ZapZap e os toolkits ficavam tematizados para sempre.
      #   O `declare -F` fica: um módulo NOVO nasce sem o verbo, e é melhor que
      #   ele diga "não sei desfazer" em voz alta a que alguém precise
      #   implementar a reversão antes de poder escrever o `aplicar`.
      #
      # NENHUM DELES FINGE. Onde a volta exata não existe — o tema que ela usava
      # no VS Code antes, o `.desktop` de um flatpak sem original guardado — o
      # módulo repõe o padrão de FÁBRICA e diz na tela que foi isso que fez.
      reverter)
        if declare -F meow_app_reverter >/dev/null; then
          meow_app_reverter
        else
          meow_pula "o módulo '$pasta' não sabe desfazer"
          exit "$MEOW_SEM_DEPENDENCIA"
        fi ;;
      # QUINTO VERBO: O PROGRAMA ESTÁ NESTA MÁQUINA? — 24/09/2026, P49
      #   0 = está, 1 = não está. Só isso: não é "dá para vestir" (quem responde
      #   isso é o `detectar`, e com o motivo). Medido na validação do painel de
      #   verdade (achado 45): a tabela do `meow apps` disse qBittorrent e
      #   Discord «não instalado», e os dois estavam (flatpak do usuário, com o
      #   diretório em ~/.local/share/flatpak/app). A tabela lia o código do
      #   `detectar` como se fosse "instalado", e o `detectar` sai 3 por
      #   qualquer coisa que impeça de vestir: o Discord sem cliente modificado,
      #   o qBittorrent já vestido por um tema que não veio daqui. Duas regras
      #   de "instalado", e a da tabela mentia.
      #   Agora é UMA: cada módulo diz a dele em `meow_app_instalado`, o
      #   `detectar` dele abre com ela, e a tabela pergunta a mesma função. O
      #   `tests/reversao.sh` cobra que todo módulo a tenha, como cobra o
      #   `reverter` — sem ela a coluna não teria como não mentir.
      instalado)
        if declare -F meow_app_instalado >/dev/null; then
          meow_app_instalado
        else
          meow_erro "o módulo '$pasta' não diz se o programa está instalado"
          exit 2
        fi ;;
      # SEXTO VERBO, SÓ DA TABELA: O MOTIVO DO `detectar` — 25/09/2026, revisão da P62
      #   Quase todo `conferir` sai 3 CALADO quando o `detectar` barra — o
      #   `meow_app_detectar || return 3` do Discord, do kitty, do OnlyOffice, do
      #   Spotify… —, e o motivo que o `meow_app_sem` guardou morre com o
      #   subshell. A tabela pergunta aqui, e só quando o `conferir` não deu linha
      #   `--` nenhuma: o que o `detectar` diz nessa linha (os módulos de antes do
      #   contrato, como o Heroic que nunca abriu) ou o MEOW_APP_MOTIVO dos do
      #   contrato, dito pela porta dele (`meow_app_pendente`, lib/comum.sh). Sem
      #   nenhum dos dois não sai linha: o qBittorrent vestido por fora diz o dele
      #   por `!!` e `>>`, e a tabela não traduz aviso em motivo.
      motivo)
        meow_app_detectar 2>/dev/null && exit "$MEOW_OK"
        [ -n "$MEOW_APP_MOTIVO" ] && meow_app_pendente "$pasta"
        exit "$MEOW_SEM_DEPENDENCIA" ;;
      *) meow_erro "ação desconhecida para o módulo '$pasta': $acao"; exit 2 ;;
    esac
  )
}

# --- modo tabela ------------------------------------------------------------
# Sai antes do laço normal porque a saída é para ser lida por outro programa:
# uma linha de log misturada no TSV viraria uma coluna fantasma na tela dela.
if [ "$ACAO" = "tabela" ]; then
  # A TABELA É LEITURA, E LEITURA NÃO PODE ESCREVER — 22/09/2026
  #   O painel oferece esta saída como "Quais programas estão vestidos", com
  #   `escreve: False` na tabela `ACOES` (app/servidor.py). Desde a sprint P2 o
  #   `meow_app_detectar` de alguns módulos REGISTRA pendência, e pendência é
  #   arquivo em `$MEOW_ESTADO`: medido nesta máquina, um `aplicar_apps.sh
  #   tabela` criava `~/.local/state/meowsystem/pendencias.tsv` do nada. O
  #   botão mentia, e a mentira era do tipo que a P3 persegue.
  #
  #   O conserto NÃO é tirar o registro do `detectar` — ele está certo onde
  #   está, e é o que faz a Home saber do problema numa passagem de verdade. É
  #   mandar o estado desta passagem para um descartável: aqui ninguém está
  #   consertando nada, está lendo uma coluna. Mesma classe do `flatpak info` e
  #   do `gsettings get` que já sujaram HOME virgem neste projeto.
  MEOW_ESTADO="$(mktemp -d -p "${TMPDIR:-/tmp}" .meow-tabela.XXXXXX)" || exit "$MEOW_ERRO"
  export MEOW_ESTADO
  trap 'rm -rf "$MEOW_ESTADO"' EXIT

  vistos=""
  declare -A SLUGS_DE=()
  declare -a ORDEM=()
  IFS=',' read -ra LISTA <<< "$APPS"
  for slug in "${LISTA[@]}"; do
    slug="$(printf '%s' "$slug" | tr -d ' ')"
    [ -n "$slug" ] || continue
    pasta="$(pasta_de "$slug")"
    [ -f "$RAIZ/assets/temas-de-apps/$pasta/manifesto.sh" ] || continue
    case " $vistos " in
      *" $pasta "*) SLUGS_DE[$pasta]="${SLUGS_DE[$pasta]}, $slug"; continue ;;
    esac
    vistos="$vistos $pasta"
    ORDEM+=("$pasta")
    SLUGS_DE[$pasta]="$slug"
  done
  # A terceira coluna é o `instalado`, e não o `detectar` (ver o quinto verbo,
  # no `rodar_modulo`): "não dá para vestir" não é "não está instalado".
  #
  # A QUINTA É O MOTIVO DO 3 — 25/09/2026, sprint P62
  #   A P55 pediu que o `meow apps` dissesse «sem tema neste pack», e só o
  #   `meow apps conferir` dizia: com um pack sem aplicativo nenhum, a frase
  #   saía lá três vezes, uma por programa, e a tabela pintava os três de `--`.
  #   Quem sabe o motivo é o módulo, e ele chega aqui por dois caminhos: as
  #   linhas `--` do `conferir` (o `meow_app_pendente` do Obsidian e do VS
  #   Code, o `meow_pula` do «não veio daqui» do kitty e do OnlyOffice) e, se o
  #   `conferir` sai 3 calado, o verbo `motivo` do `rodar_modulo`, que traz o
  #   do `detectar`. As linhas vão na quinta coluna, unidas por « · » — o TSV
  #   não aceita tabulação nem quebra de linha. Sem nenhum dos dois a coluna
  #   fica vazia: a tabela não inventa o motivo que o módulo não disse.
  #   [Até a revisão da P62, no mesmo dia, só havia o primeiro caminho, e este
  #   bloco chamava o `meow_pula` de "a porta do contrato do motivo no
  #   lib/comum.sh". A porta é o `meow_app_sem`, que guarda no MEOW_APP_MOTIVO,
  #   e quem diz é o `meow_app_pendente`. Medido numa casa de brinquedo vazia,
  #   dos onze `conferir` que saíram 3 só o do Obsidian e o do qBittorrent deram
  #   a linha `--`; nesta máquina, o Discord e o qBittorrent instalados saíam na
  #   tabela «não veste», sem motivo nenhum embaixo.]
  linhas_de_pulo() {
    sed -n -e 's/\x1b\[[0-9;]*m//g' -e 's/^  --   //p' | tr '\t' ' ' \
      | awk 'NR > 1 { printf " · " } { printf "%s", $0 }'
  }
  for pasta in "${ORDEM[@]}"; do
    rodar_modulo "$pasta" instalado >/dev/null 2>&1; rc_inst=$?
    saida="$(rodar_modulo "$pasta" conferir 2>/dev/null)"; rc_conf=$?
    motivo=""
    if [ "$rc_conf" = "$MEOW_SEM_DEPENDENCIA" ]; then
      motivo="$(printf '%s\n' "$saida" | linhas_de_pulo)"
      [ -n "$motivo" ] || motivo="$(rodar_modulo "$pasta" motivo 2>/dev/null | linhas_de_pulo)"
    fi
    printf '%s\t%s\t%s\t%s\t%s\n' "$pasta" "${SLUGS_DE[$pasta]}" "$rc_inst" "$rc_conf" "$motivo"
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
#
# E NO SECO O 1 É "APLICARIA" — 25/09/2026, sprint P62
#   A disciplina estava escrita aqui e faltava neste resumo: o ensaio do
#   «Trocar pelo tema do pack» (o `meow apps aplicar onlyoffice` com
#   `MEOW_DRY_RUN=1`) terminava em `ok aplicados: onlyoffice`, logo abaixo das
#   linhas `~~ mudaria` do próprio módulo — a classe do achado 11, que a P50
#   consertou só no rodapé do `install.sh`. No ensaio nada foi escrito: o 1 diz
#   o que o módulo faria, com o `~~` das linhas dele, e o desfazer em seco
#   segue a mesma régua.
if [ ${#APLICADOS[@]} -gt 0 ]; then
  case "$ACAO" in
    conferir) meow_muda "divergentes: ${APLICADOS[*]}" ;;
    reverter) if meow_seco; then meow_muda "desfaria: ${APLICADOS[*]}"
              else meow_ok "desfeitos: ${APLICADOS[*]}"; fi ;;
    *)        if meow_seco; then meow_muda "aplicaria: ${APLICADOS[*]}"
              else meow_ok "aplicados: ${APLICADOS[*]}"; fi ;;
  esac
fi
[ ${#JA_OK[@]}     -gt 0 ] && meow_ok   "já estavam certos: ${JA_OK[*]}"
[ ${#PENDENTES[@]} -gt 0 ] && meow_pula "pendentes (app não instalado, ou não dá para agir agora): ${PENDENTES[*]}"
[ ${#FALHOS[@]}    -gt 0 ] && meow_erro "falharam: ${FALHOS[*]}"

[ ${#FALHOS[@]}    -gt 0 ] && exit "$MEOW_ERRO"
[ ${#APLICADOS[@]} -gt 0 ] && exit "$MEOW_DIVERGENTE"
exit "$MEOW_OK"

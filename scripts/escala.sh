#!/usr/bin/env bash
# escala.sh — o tamanho de TUDO na tela, que é a única alavanca de fonte que o
#             COSMIC tem.
#
# Telas → Escala é um controle DELA, na GUI. Uma etapa que reimpõe a escala todo
# dia é exatamente o defeito que o `vidro.sh` acabou de corrigir no mesmo dia: o
# slider "Opacidade do fundo" voltando para o nosso número a cada passagem do
# timer.
#
# Consequência prática, dita para não surpreender: se ela mudar a escala pela
# GUI e depois rodar o install de novo, o valor do meow.conf volta.
#
#   0 já estava certo · 1 divergia e foi aplicado · 2 erro · 3 falta dependência
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

CONFERIR=0
for _a in "$@"; do
  case "$_a" in
    --conferir) CONFERIR=1 ;;
    -h|--help)
      printf 'uso: escala.sh [--conferir]\n\n  Aplica ESCALA_TELA em todas as saídas ligadas.\n  Vazio = não mexe (a escala é da GUI).\n\n  --conferir  só mostra o que está ligado e em que escala.\n'
      exit 0 ;;
    *) meow_erro "opção desconhecida: '$_a' — só existe --conferir"; exit 2 ;;
  esac
done
unset _a

# Vazio é o padrão, e vazio quer dizer "não toque". A mesma disciplina do
# `vidro.sh`: onde a GUI tem controle, o valor é dela até que ela peça o nosso.
ESCALA_TELA="${ESCALA_TELA:-}"

if ! meow_tem cosmic-randr; then
  meow_pula "cosmic-randr não está instalado — sem como falar com o compositor"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

# --- ler o que está ligado AGORA --------------------------------------------
# Uma linha por saída habilitada:  nome<TAB>escala<TAB>largura<TAB>altura<TAB>hz
#
# Até aqui o awk lia a saída colorida e indentada do `cosmic-randr list`, com a
# escala em porcentagem ("100%") e o hz em texto ("60.000 Hz").
#
# Medido, seis chamadas seguidas: o `cosmic-randr` entrega as saídas numa ordem
# que muda de uma chamada para outra (`HDMI-A-1 eDP-1`, depois `eDP-1
# HDMI-A-1`), no `--kdl` e na tela de humano.
saidas() {
  cosmic-randr list --kdl 2>/dev/null \
    | LC_ALL=C awk '
        /^output "/ {
          nome = $2; gsub(/"/, "", nome)
          ligada = (index($0, "enabled=#true") > 0)
          escala = ""
          next
        }
        /^  scale / { escala = $2 + 0; next }
        ligada && /^    mode / && /current=#true/ {
          printf "%s\t%s\t%s\t%s\t%.3f\n", nome, escala, $2, $3, $4 / 1000
          ligada = 0   # uma linha por saída: só o modo corrente interessa
        }
      ' \
    | LC_ALL=C sort -f -t "$(printf '\t')" -k1,1
}

# `1.25` e `1.250` são o mesmo número e strings diferentes. Comparar como texto
# faria o script "consertar" para sempre uma tela que já está certa.
mesma_escala() {
  LC_ALL=C awk -v a="$1" -v b="$2" 'BEGIN{ exit !(a+0 == b+0) }'
}

# Ela era o cabeçalho "saídas ligadas agora:", e a linha `escala` do
# doctor (que mostra só a primeira) saía cortada no dois-pontos.
if [ "$CONFERIR" = "1" ]; then
  lista="$(saidas)"
  resumo="$(printf '%s\n' "$lista" | awk -F'\t' 'NF { printf "%s%s na escala %s", (n++ ? ", " : ""), $1, $2 }')"
  if [ -z "$ESCALA_TELA" ]; then
    meow_info "${resumo:-nenhuma saída ligada} — a escala é da GUI (Ajustes → Telas → Escala)"
  else
    meow_info "${resumo:-nenhuma saída ligada} — ESCALA_TELA pede $ESCALA_TELA em todas"
  fi
  while IFS=$'\t' read -r nome escala larg alt hz; do
    [ -n "$nome" ] || continue
    printf '    %-10s escala=%s  modo=%sx%s @ %s Hz\n' "$nome" "$escala" "$larg" "$alt" "$hz"
  done <<< "$lista"
  exit "$MEOW_OK"
fi

# ============================================================================
# A ESCALA FRACIONÁRIA SERRILHA O TRAÇO FINO — E ISSO ELE PASSA A DIZER SOZINHO
# ============================================================================
# 01/09/2026, pergunta dela sobre os ícones do lançador: "e sobre o serrilhado
# dos apps e icons?", com captura. O traço do Spotify, do Steam e do Telegram
# engrossava e afinava dentro do mesmo círculo.
#
# NÃO ERAM OS ARQUIVOS, e isso já estava medido aqui dentro: `lib/icones.sh`
# registra desde 27/08 que o COSMIC rasteriza vetor no tamanho pedido e que
# `Type=Fixed` contra `Type=Scalable` dá ZERO pixel de diferença. Era a TELA:
# `cosmic-randr list` devolvia `Scale: 90%` na TV de 1920x1080.
#
# O QUE 90% FAZ COM UM ÍCONE DE TRAÇO: o app desenha em 1x e o resultado é
# reamostrado para 0,9. Uma linha de 1 px vira 0,9 px e o filtro reparte a
# sobra entre dois pixels — em traço fino, que é o nosso tema inteiro
# (Arcticons, `fill:none` + `stroke`), o efeito é exatamente o que ela viu.
# Reproduzido no mesmo dia com o `com.spotify.Client.svg`: rasterizado em
# tamanho inteiro, nítido; reduzido a 90%, o traço perde a espessura constante.
#
# POR QUE ISTO É AVISO E NÃO CONSERTO
#   Consertar é pôr a escala em 100%, e aí TUDO cresce ~11% na tela dela — que
#   é uma TV de 52 polegadas onde ela escolheu caber mais coisa. Essa é uma
#   escolha de gosto, e a regra da casa é que gosto é dela: o script diz o que
#   mediu, mostra a chave, e para. `ESCALA_TELA="1.0"` no meow.conf aplica.
#
# A CONTA DE "FRACIONÁRIA": o dano aparece quando a escala não é um inteiro.
# 1.0 e 2.0 são reamostragens exatas (ou nenhuma); 0.9, 1.25 e 1.5 não são.
_escala_fracionaria() {   # 0 = fracionária
  case "$1" in
    1|1.0|1.00|2|2.0|2.00|3|3.0) return 1 ;;
    *) return 0 ;;
  esac
}

if [ -z "$ESCALA_TELA" ]; then
  meow_pula "ESCALA_TELA vazia — a escala fica com a GUI"
  if [ "${ESCALA_AVISAR:-sim}" = "sim" ]; then
    while IFS=$'\t' read -r nome escala larg alt hz; do
      [ -n "$nome" ] && [ -n "$escala" ] || continue
      if _escala_fracionaria "$escala"; then
        meow_aviso "$nome está em escala $escala (fracionária) — o traço fino dos ícones serrilha"
        meow_info "  o app desenha em 1x e o compositor reamostra: 1 px de traço vira ${escala} px"
        meow_info "  isso não tem conserto do lado do arquivo — o vetor já é rasterizado no tamanho certo"
        meow_info "  se quiser nitidez no lugar do tamanho: ESCALA_TELA=\"1.0\" no meow.conf"
        meow_info "  para calar este aviso sem mudar nada: ESCALA_AVISAR=\"nao\""
      fi
    done < <(saidas)
  fi
  exit "$MEOW_OK"
fi

# ============================================================================
# `ESCALA_TELA="nitida"` — O AUTOMÁTICO QUE ELA PEDIU EM 01/09/2026
# ============================================================================
# Palavras dela, sobre a versão que só avisava: "automatico de fato. assim nao".
# E ela tem razão: um aviso que repete todo dia a mesma frase e espera que
# alguém digite uma chave não é adaptação, é lista de tarefas para o humano.
#
# O QUE `nitida` FAZ: arredonda a escala de cada saída para o INTEIRO mais
# próximo. 0.9 vira 1; 1.25 vira 1; 1.6 vira 2. Escala inteira é a única que
# não obriga o compositor a reamostrar o que os aplicativos desenharam — e é a
# reamostragem que come o traço fino dos ícones (medido no mesmo dia com o
# `com.spotify.Client.svg`: o traço perde a espessura constante).
#
# O QUE ELA CUSTA, E POR ISSO ESTÁ ESCRITO AQUI: sair de 0.9 para 1.0 faz TUDO
# crescer ~11% — cabe menos coisa na tela. É troca de tamanho por nitidez, e a
# escolha continua sendo dela: `ESCALA_TELA="0.9"` volta ao que era, e vazio
# devolve a decisão para a GUI.
#
# POR QUE ARREDONDAR EM VEZ DE CHUMBAR 1.0: numa tela 4K a escala boa é 2, e
# chumbar 1 deixaria a interface minúscula. O arredondamento respeita o tamanho
# que ela já escolheu e só tira a fração.
if [ "$ESCALA_TELA" = "nitida" ] || [ "$ESCALA_TELA" = "auto" ]; then
  ESCALA_AUTO=1
else
  ESCALA_AUTO=0
  case "$ESCALA_TELA" in
    [0-9]*.[0-9]*|[0-9]) : ;;
    *) meow_erro "ESCALA_TELA='$ESCALA_TELA' — esperado um número (1.0, 1.25) ou \"nitida\""
       exit "$MEOW_ERRO" ;;
  esac
fi

mudou=0
vistas=0
while IFS=$'\t' read -r nome escala larg alt hz; do
  [ -n "$nome" ] && [ -n "$larg" ] || continue
  vistas=$((vistas + 1))

  # No modo `nitida` o alvo é POR SAÍDA: dois monitores podem estar em escalas
  # diferentes, e arredondar cada um preserva o tamanho que ela escolheu em
  # cada tela. `awk` porque o bash não faz conta com vírgula flutuante, e o
  # arredondamento é o comum (0.5 sobe) com piso em 1 — escala 0 não existe.
  ALVO="$ESCALA_TELA"
  if [ "$ESCALA_AUTO" = "1" ]; then
    # `LC_ALL=C` NÃO É ZELO: o locale dela é pt_BR, e sem isso o `printf "%.1f"`
    # do awk devolve "1,0" — com vírgula. O `cosmic-randr` recusa aquilo, e o
    # sintoma seria "o script diz que mudaria e nunca muda". Pego no primeiro
    # ensaio seco, 01/09/2026.
    ALVO="$(LC_ALL=C awk -v e="$escala" 'BEGIN { n = int(e + 0.5); if (n < 1) n = 1; printf "%.1f", n }')"
  fi

  if mesma_escala "$escala" "$ALVO"; then
    [ "$ESCALA_AUTO" = "1" ] && meow_ok "$nome já está em escala inteira ($escala) — nada a reamostrar" \
                             || meow_ok "$nome já está em $ALVO"
    continue
  fi

  if meow_seco; then
    meow_muda "mudaria $nome de $escala para $ALVO"
    mudou=1
    continue
  fi

  # O MODO VAI JUNTO PORQUE O COMANDO EXIGE, e é o modo CORRENTE: passar outro
  # aqui trocaria a resolução dela de brinde. `--refresh` idem — sem ele o
  # compositor escolheria o modo preferido, que nem sempre é o que está valendo.
  if cosmic-randr mode "$nome" "$larg" "$alt" --refresh "$hz" --scale "$ALVO" 2>/dev/null; then
    meow_ok "$nome: escala $escala -> $ALVO (o traço fino para de ser reamostrado)"
    mudou=1
  else
    meow_erro "cosmic-randr recusou a escala $ALVO em $nome"
    exit "$MEOW_ERRO"
  fi
done < <(saidas)

# Nenhuma saída ligada não é "tudo certo": é não haver o que ajustar. Dizer
# "escala conforme" sobre zero telas é a contradição que o `vidro.sh` já
# documenta ter cometido uma vez.
if [ "$vistas" -eq 0 ]; then
  meow_pula "nenhuma saída ligada — nada a ajustar"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

[ "$mudou" = "0" ] && exit "$MEOW_OK"
meow_seco && exit "$MEOW_DIVERGENTE"

# O AVISO É PARTE DO TRABALHO: a escala vale na hora nas janelas COSMIC, mas
# quem já estava aberto sob Xwayland (Steam, jogos) só reamostra ao reabrir.
meow_info "apps Xwayland já abertos só assumem o tamanho novo ao reabrir"
exit "$MEOW_DIVERGENTE"

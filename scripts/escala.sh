#!/usr/bin/env bash
# escala.sh — o tamanho de TUDO na tela, que é a única alavanca de fonte que o
#             COSMIC tem.
#
# O PEDIDO QUE FEZ ESTE ARQUIVO EXISTIR (17/08/2026)
#   "outra coisa que eu gostaria de fazer é aumentar o tamanho universal das
#   fontes do pc."
#
# NÃO EXISTE "TAMANHO DA FONTE" NO COSMIC, E ISSO FOI MEDIDO ANTES DE ESCREVER
#   A tentação era procurar uma chave de tamanho e escrevê-la. Ela não existe.
#   O que existe, e o que cada coisa faz de verdade:
#
#     CosmicTk/interface_font    struct RON com `family`, `weight`, `stretch`,
#                                `style`. NÃO tem campo de tamanho — conferido
#                                no fonte da libcosmic (`src/config/mod.rs`).
#     CosmicTk/interface_density  Compact | Standard | Spacious. Vira `Spacing`
#                                (`cosmic-theme/src/model/density.rs`): mexe em
#                                padding e espaçamento, NUNCA no texto.
#     CosmicTk/header_size       a altura da barra de título. Mesma história.
#     libcosmic default_text_size  14.0, CONSTANTE no código (`app/settings.rs`).
#                                Não é lida de config nenhuma.
#     COSMIC_SCALE (env)         multiplica a UI, mas só de apps libcosmic:
#                                `strings /usr/bin/cosmic-panel | grep -c
#                                COSMIC_SCALE` devolve 0. O painel e a dock
#                                ficariam de fora — meia tela grande, meia não.
#
#   Sobra a ESCALA DA SAÍDA, que é o que a GUI chama de Ajustes → Telas →
#   Escala. Ela multiplica o texto de 14 px junto com todo o resto: painel,
#   dock, Ajustes, apps COSMIC, apps GTK e Xwayland. É "universal" no sentido
#   exato do pedido — e é o preço também: ícones e barras crescem junto.
#
#   O CUSTO A DIZER EM VOZ ALTA: escala fracionária (1,25 · 1,5) faz o Xwayland
#   renderizar num tamanho e o compositor reamostrar. Steam e jogos antigos
#   podem sair levemente borrados. Ela foi avisada disto antes de escolher 1.25.
#
# POR QUE 0,75 APARECIA NO outputs.ron E NÃO ERA A TELA DELA
#   `~/.local/state/cosmic-comp/outputs.ron` guarda uma entrada POR CONJUNTO DE
#   MONITORES já visto, com `make`/`model` no cabeçalho. Havia lá um
#   `DP-1 · PNP(GDH) · TV PHILCO` com `scale: 0.75` — uma TV que não está mais
#   ligada. A que está ligada hoje é `DP-1 · PNP(HSI) · HiTV`, que estava em
#   1.0. Ler o .ron pelo conector e concluir "a tela dela está em 75%" é o erro
#   fácil aqui, e eu o cometi antes de olhar o `cosmic-randr list`. Por isso
#   este script NÃO lê aquele arquivo: pergunta ao compositor quem está ligado
#   agora.
#
# POR QUE ESCREVER PELO cosmic-randr, E NÃO NO ARQUIVO
#   O `outputs.ron` é ESTADO do compositor, não configuração: quem o escreve é o
#   `cosmic-comp`, na saída, a partir do que tem na memória. Editar o arquivo
#   com a sessão viva é escrever num lugar que vai ser sobrescrito por cima —
#   o mesmo tipo de defeito que este projeto já pagou com o tema. O
#   `cosmic-randr` fala com o compositor pelo protocolo de saída do Wayland:
#   vale na hora e é ele quem persiste depois.
#
# A FLAG `--test` DO cosmic-randr APLICA DE VERDADE — MEDIDO EM 17/08/2026
#   O help diz "Tests the output configuration without applying it". Rodado
#   `cosmic-randr mode DP-1 1920 1080 --refresh 60 --scale 1.25 --test`, o
#   comando devolveu 0 e a tela MUDOU: o `list` seguinte já dizia `Scale: 125%`.
#   Não use `--test` esperando um ensaio — não é um. O ensaio deste script é o
#   `--conferir`, que só lê.
#
# ESTA ETAPA NÃO ENTRA NO `meow doctor`, E ISSO É DELIBERADO
#   Telas → Escala é um controle DELA, na GUI. Uma etapa que reimpõe a escala
#   todo dia é exatamente o defeito que o `vidro.sh` acabou de corrigir no mesmo
#   dia: o slider "Opacidade do fundo" voltando para o nosso número a cada
#   passagem do timer. Aqui a regra é a mesma, com uma diferença: a escala é
#   cara de descobrir e ela pediu um valor específico, então o `install.sh`
#   aplica quando ela roda a instalação — e mais ninguém mexe.
#
#   Consequência prática, dita para não surpreender: se ela mudar a escala pela
#   GUI e depois rodar o install de novo, o valor do meow.conf volta. Para que
#   isso pare de acontecer, esvazie `ESCALA_TELA` no meow.conf.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
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
# A saída do `cosmic-randr list` é colorida e indentada. O awk abaixo devolve
# uma linha por saída habilitada:  nome<TAB>escala<TAB>largura<TAB>altura<TAB>hz
#
# A ESCALA VEM EM PORCENTAGEM ("100%") e o `--scale` quer fração (1.0): a
# conversão é feita aqui, uma vez, para que o resto do script compare maçã com
# maçã. Comparar "100%" com "1.25" foi o primeiro jeito e ele dizia que tudo
# divergia sempre.
#
# `LC_ALL=C` NÃO É PARANOIA: sem ele o awk desta máquina (pt_BR) imprime
# `escala=1,25`, com vírgula. O `cosmic-randr --scale` recusa vírgula, e a
# comparação numérica passa a mentir. Foi o primeiro defeito deste arquivo.
saidas() {
  cosmic-randr list 2>/dev/null \
    | sed -E 's/\x1b\[[0-9;]*m//g' \
    | LC_ALL=C awk '
        /^[^ ]/ {
          nome = $1
          ligada = (index($0, "(enabled)") > 0)
          escala = ""; larg = ""; alt = ""; hz = ""
          next
        }
        /^  Scale:/ { sub(/%$/, "", $2); escala = $2 / 100; next }
        ligada && /\(current\)/ {
          # "    1920x1080 @  60.000 Hz (current) (preferred)"
          split($1, wh, "x"); larg = wh[1]; alt = wh[2]; hz = $3
          printf "%s\t%s\t%s\t%s\t%s\n", nome, escala, larg, alt, hz
          ligada = 0   # uma linha por saída: só o modo corrente interessa
        }
      '
}

# `1.25` e `1.250` são o mesmo número e strings diferentes. Comparar como texto
# faria o script "consertar" para sempre uma tela que já está certa.
mesma_escala() {
  LC_ALL=C awk -v a="$1" -v b="$2" 'BEGIN{ exit !(a+0 == b+0) }'
}

if [ "$CONFERIR" = "1" ]; then
  meow_info "saídas ligadas agora:"
  while IFS=$'\t' read -r nome escala larg alt hz; do
    [ -n "$nome" ] || continue
    printf '    %-10s escala=%s  modo=%sx%s @ %s Hz\n' "$nome" "$escala" "$larg" "$alt" "$hz"
  done < <(saidas)
  if [ -z "$ESCALA_TELA" ]; then
    meow_info "ESCALA_TELA vazia — a escala é da GUI (Ajustes → Telas → Escala)"
  else
    meow_info "o que este script quer: escala $ESCALA_TELA em todas elas"
  fi
  exit "$MEOW_OK"
fi

if [ -z "$ESCALA_TELA" ]; then
  meow_pula "ESCALA_TELA vazia — a escala fica com a GUI"
  exit "$MEOW_OK"
fi

case "$ESCALA_TELA" in
  [0-9]*.[0-9]*|[0-9]) : ;;
  *) meow_erro "ESCALA_TELA='$ESCALA_TELA' — esperado um número como 1.0, 1.25, 1.5"
     exit "$MEOW_ERRO" ;;
esac

mudou=0
vistas=0
while IFS=$'\t' read -r nome escala larg alt hz; do
  [ -n "$nome" ] && [ -n "$larg" ] || continue
  vistas=$((vistas + 1))

  if mesma_escala "$escala" "$ESCALA_TELA"; then
    meow_ok "$nome já está em $ESCALA_TELA"
    continue
  fi

  if meow_seco; then
    meow_muda "mudaria $nome de $escala para $ESCALA_TELA"
    mudou=1
    continue
  fi

  # O MODO VAI JUNTO PORQUE O COMANDO EXIGE, e é o modo CORRENTE: passar outro
  # aqui trocaria a resolução dela de brinde. `--refresh` idem — sem ele o
  # compositor escolheria o modo preferido, que nem sempre é o que está valendo.
  if cosmic-randr mode "$nome" "$larg" "$alt" --refresh "$hz" --scale "$ESCALA_TELA" 2>/dev/null; then
    meow_ok "$nome: escala $escala -> $ESCALA_TELA"
    mudou=1
  else
    meow_erro "cosmic-randr recusou a escala $ESCALA_TELA em $nome"
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

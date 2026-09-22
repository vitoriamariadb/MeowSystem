#!/usr/bin/env bash
# instalacao.sh — O LAÇO DAS PASSAGENS: ele fecha sozinho, e sabe parar.
#
# POR QUE ESTE ARQUIVO NASCEU EM 21/09/2026
#   Até esta data o `install.sh` rodava as 59 etapas UMA vez e terminava
#   pedindo: "N etapa(s) mudaram nesta passagem. Rode mais uma vez." O laço
#   passou para dentro do instalador, e com ele vieram duas guardas que não são
#   enfeite: um teto de 5 passagens e um detector de oscilação. Guarda que só
#   dispara em máquina defeituosa nunca dispara em lugar nenhum — e o dia em que
#   ela for precisa é o dia em que ninguém está olhando a tela.
#
# COMO SE TESTA UM TETO SEM UMA MÁQUINA DEFEITUOSA
#   Com uma RAIZ DE BRINQUEDO: um diretório de links simbólicos para este
#   repositório mais uma CÓPIA do `install.sh` com a lista de etapas do `main`
#   trocada por etapas falsas — uma que escreve toda passagem, duas que se
#   revezam, uma que escreve só na primeira. O laço, o teto, o detector e as
#   frases da tela são os do arquivo de verdade; de mentira é só a fila.
#
#   Os links existem por causa do `MEOW_RAIZ`, que o `install.sh` deriva de onde
#   ELE está (`pwd -P` do próprio diretório): uma cópia solta em /tmp não
#   acharia o `lib/comum.sh`. Um diretório de links tem caminho físico próprio e
#   resolve os dois lados.
#
#   A convergência da fila DE VERDADE, com as 59 etapas numa máquina zerada, é o
#   `tests/convergencia.sh`, e são cinquenta segundos: este aqui não a repete.
#
# ONDE ELE RODA
#   HOME de brinquedo, `env -i`, sem COSMIC e sem sessão gráfica. As etapas
#   falsas não escrevem nada, nem dentro dele.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

FALHAS=0
falhou() { printf 'FALHOU: %s\n' "$*" >&2; FALHAS=$((FALHAS + 1)); }
passou() { printf 'ok: %s\n' "$*"; }

SAIDA=""
RC=0

# Monta a raiz de brinquedo e roda o instalador dela.
#   $1 = nome do cenário · $2 = lista de etapas falsas · $3 = corpo das funções
#   $4... = o que for passado ao install.sh (por exemplo --uma-passagem)
cenario() {
  local nome="$1" lista="$2" corpo="$3"; shift 3
  local raiz="$TMP/$nome/raiz" lar="$TMP/$nome/lar" i
  mkdir -p "$raiz" "$lar"
  for i in "$RAIZ"/*; do
    [ "$(basename "$i")" = "install.sh" ] && continue
    ln -s "$i" "$raiz/"
  done
  printf '%s\n' "$corpo" > "$TMP/$nome/falsas.sh"

  # A troca é cirúrgica: a lista do `main` e nada mais. O formato do
  # `local etapas=(...)` já é contrato — o `tests/numeros.sh` e o `bin/meow`
  # leem essa mesma lista com `sed` para contar as etapas —, então depender dele
  # aqui não cria dívida nova: cria um leitor a mais do mesmo contrato.
  awk -v lista="$lista" -v falsas="$TMP/$nome/falsas.sh" '
    /local etapas=\(/ && !trocou { print "  local etapas=(" lista ")"; trocou=1; pulando=1 }
    pulando { if ($0 ~ /\)[ \t]*$/) pulando=0; next }
    /^main "\$@"$/ { while ((getline linha < falsas) > 0) print linha }
    { print }
  ' "$RAIZ/install.sh" > "$raiz/install.sh"
  chmod +x "$raiz/install.sh"

  # `MEOW_PONTE` apontando para o vazio é a mesma linha do
  # `tests/convergencia.sh`, pelo mesmo motivo: a raiz de brinquedo é feita de
  # links para os scripts DE VERDADE, e o dia em que algo aqui chamar um deles
  # por engano não pode ser o dia em que um teste mexe no /etc desta máquina.
  SAIDA="$(env -i PATH="$PATH" HOME="$lar" USER="${USER:-t}" \
    MEOW_IGNORA_DESKTOP=1 NO_COLOR=1 MEOW_PONTE=/nao/existe \
    bash "$raiz/install.sh" "$@" 2>&1)"
  RC=$?
}

contem()     { case "$SAIDA" in *"$1"*) return 0 ;; esac; return 1; }
passagens()  { printf '%s\n' "$SAIDA" | grep -c 'de até' ; }

confere() {
  # A frase que esta sprint aposentou não pode voltar por nenhuma porta.
  if contem 'Rode mais uma vez'; then
    falhou "$1: a tela ainda pede que a pessoa rode de novo"
  fi
}

# ---------------------------------------------------------------------------
# 1. Máquina já pronta: uma passagem, e uma frase só
# ---------------------------------------------------------------------------
cenario pronta 'etapa_falsa_ok etapa_falsa_ok2' '
etapa_falsa_ok()  { passo "etapa falsa que já está no lugar"; return 0; }
etapa_falsa_ok2() { passo "outra que já está no lugar";       return 0; }
'
confere pronta
if [ "$RC" != "0" ]; then
  falhou "pronta: o instalador saiu $RC onde nada tinha o que escrever"
elif ! contem 'Pronto. 1 passagem, 2 etapas, nada mais a escrever.'; then
  falhou "pronta: a frase final não é a de convergência — saiu: $(printf '%s' "$SAIDA" | tail -2 | tr -d '\n')"
elif [ "$(passagens)" != "1" ]; then
  falhou "pronta: $(passagens) passagem(ns) anunciadas onde uma bastava"
else
  passou "máquina pronta: uma passagem, e a tela diz 'Pronto. 1 passagem'"
fi

# ---------------------------------------------------------------------------
# 2. A cadeia: a etapa que só escreve na primeira passagem
# ---------------------------------------------------------------------------
# É o caso que esta sprint existe para atender — o `index.theme` descreve os
# diretórios que EXISTEM, e as pastas coloridas nascem na etapa seguinte. Aqui o
# instalador tem de fechar o laço sozinho, sem pedir nada a ninguém.
cenario cadeia 'etapa_falsa_primeira etapa_falsa_quieta' '
FALSA_PASSAGEM=0
etapa_falsa_primeira() {
  passo "etapa falsa que só escreve na primeira passagem"
  FALSA_PASSAGEM=$((FALSA_PASSAGEM + 1))
  [ "$FALSA_PASSAGEM" = "1" ] && { meow_muda "escrevi, e agora está no lugar"; return 1; }
  return 0
}
etapa_falsa_quieta() { passo "etapa falsa que nunca escreve"; return 0; }
'
confere cadeia
if [ "$RC" != "0" ]; then
  falhou "cadeia: o instalador saiu $RC em vez de convergir na segunda passagem"
elif ! contem 'Pronto. 2 passagens, 2 etapas, nada mais a escrever.'; then
  falhou "cadeia: não fechou o laço sozinho — saiu: $(printf '%s' "$SAIDA" | tail -2 | tr -d '\n')"
elif ! contem 'passagem 2 de até 5 · 1 etapa ainda muda'; then
  falhou "cadeia: a tela não disse em qual passagem estava, nem quantas ainda mudavam"
else
  passou "cadeia: duas passagens, sem pedir nada, e a tela numerou as duas"
fi

# ---------------------------------------------------------------------------
# 3. A oscilação: as mesmas etapas escrevendo em duas passagens seguidas
# ---------------------------------------------------------------------------
cenario teimosa 'etapa_falsa_teimosa etapa_falsa_quieta' '
etapa_falsa_teimosa() {
  passo "etapa falsa que escreve toda passagem"
  meow_muda "escrevi de novo"
  return 1
}
etapa_falsa_quieta() { passo "etapa falsa que nunca escreve"; return 0; }
'
confere teimosa
if [ "$RC" != "2" ]; then
  falhou "teimosa: saiu $RC — uma etapa que escreve sempre é defeito, e defeito sai 2"
elif [ "$(passagens)" != "2" ]; then
  falhou "teimosa: $(passagens) passagens — o detector tinha de parar na segunda"
elif ! contem 'as mesmas etapas escreveram em duas passagens seguidas'; then
  falhou "teimosa: parou sem dizer que era oscilação"
elif ! contem 'falsa_teimosa'; then
  falhou "teimosa: não nomeou a etapa culpada"
elif ! contem 'meow doctor'; then
  falhou "teimosa: não disse para onde ir depois"
else
  passou "oscilação: para na segunda passagem, nomeia a etapa e manda ao doctor"
fi

# ---------------------------------------------------------------------------
# 4. O teto: duas etapas que se revezam, e nunca repetem o conjunto
# ---------------------------------------------------------------------------
# O detector de oscilação não pega este caso de propósito (o conjunto muda a
# cada passagem), e é exatamente para isto que o teto existe.
cenario teto 'etapa_falsa_a etapa_falsa_b' '
FALSA_P=1
etapa_falsa_a() {
  passo "falsa a"
  if [ $((FALSA_P % 2)) = 1 ]; then meow_muda "a escreveu"; return 1; fi
  return 0
}
etapa_falsa_b() {
  passo "falsa b"
  local r=0
  if [ $((FALSA_P % 2)) = 0 ]; then meow_muda "b escreveu"; r=1; fi
  FALSA_P=$((FALSA_P + 1))
  return "$r"
}
'
confere teto
if [ "$RC" != "2" ]; then
  falhou "teto: saiu $RC — cinco passagens sem convergir é defeito, e defeito sai 2"
elif [ "$(passagens)" != "5" ]; then
  falhou "teto: $(passagens) passagens — o teto é 5, nem mais nem menos"
elif ! contem '5 passagens, e estas etapas ainda escrevem'; then
  falhou "teto: parou sem dizer o que ainda mudava"
else
  passou "teto: cinco passagens, para, e diz quais etapas ainda escrevem"
fi

# ---------------------------------------------------------------------------
# 5. --uma-passagem: o comportamento de antes, preservado
# ---------------------------------------------------------------------------
# É a flag do timer e da depuração. Ela não conserta nada: ela mostra a primeira
# passagem sozinha, com o rodapé de sempre.
cenario uma_passagem 'etapa_falsa_teimosa etapa_falsa_quieta' '
etapa_falsa_teimosa() {
  passo "etapa falsa que escreve toda passagem"
  meow_muda "escrevi de novo"
  return 1
}
etapa_falsa_quieta() { passo "etapa falsa que nunca escreve"; return 0; }
' --uma-passagem
if [ "$RC" != "0" ]; then
  falhou "uma-passagem: saiu $RC — uma passagem que escreveu não é falha"
elif [ "$(passagens)" != "0" ]; then
  falhou "uma-passagem: anunciou passagem numerada onde só há uma"
elif ! contem '1 etapa(s) mudaram nesta passagem.'; then
  falhou "uma-passagem: perdeu o rodapé de antes, que esta flag existe para preservar"
elif contem 'Pronto.'; then
  falhou "uma-passagem: disse que convergiu, e a etapa teimosa ainda escreve"
else
  passou "--uma-passagem: uma passagem só, com o rodapé de antes"
fi

# ---------------------------------------------------------------------------
[ "$FALHAS" = "0" ] || exit 1
printf 'ok: o laço das passagens fecha sozinho, e as duas guardas disparam\n'

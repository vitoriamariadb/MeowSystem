#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

FALHAS=0
falhou() { printf 'FALHOU: %s\n' "$*" >&2; FALHAS=$((FALHAS + 1)); }
passou() { printf 'ok: %s\n' "$*"; }

SAIDA=""
RC=0

cenario() {
  local nome="$1" lista="$2" corpo="$3"; shift 3
  local raiz="$TMP/$nome/raiz" lar="$TMP/$nome/lar" i
  mkdir -p "$raiz" "$lar"
  for i in "$RAIZ"/*; do
    [ "$(basename "$i")" = "install.sh" ] && continue
    ln -s "$i" "$raiz/"
  done
  printf '%s\n' "$corpo" > "$TMP/$nome/falsas.sh"

  awk -v lista="$lista" -v falsas="$TMP/$nome/falsas.sh" '
    /local etapas=\(/ && !trocou { print "  local etapas=(" lista ")"; trocou=1; pulando=1 }
    pulando { if ($0 ~ /\)[ \t]*$/) pulando=0; next }
    /^main "\$@"$/ { while ((getline linha < falsas) > 0) print linha }
    { print }
  ' "$RAIZ/install.sh" > "$raiz/install.sh"
  chmod +x "$raiz/install.sh"

  SAIDA="$(env -i PATH="$PATH" HOME="$lar" USER="${USER:-t}" \
    MEOW_IGNORA_DESKTOP=1 NO_COLOR=1 MEOW_PONTE=/nao/existe \
    bash "$raiz/install.sh" "$@" 2>&1)"
  RC=$?
}

contem()     { case "$SAIDA" in *"$1"*) return 0 ;; esac; return 1; }
passagens()  { printf '%s\n' "$SAIDA" | grep -c 'de até' ; }

confere() {
  if contem 'Rode mais uma vez'; then
    falhou "$1: a tela ainda pede que a pessoa rode de novo"
  fi
}

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

cenario teimosa_com_falha 'etapa_falsa_teimosa etapa_falsa_quebrada' '
etapa_falsa_teimosa() {
  passo "etapa falsa que escreve toda passagem"
  meow_muda "escrevi de novo"
  return 1
}
etapa_falsa_quebrada() { passo "etapa falsa que falha"; meow_erro "quebrei"; return 2; }
'
confere teimosa_com_falha
if [ "$RC" != "2" ]; then
  falhou "teimosa+falha: saiu $RC em vez de 2"
elif ! contem 'as mesmas etapas escreveram em duas passagens seguidas'; then
  falhou "teimosa+falha: o 'falhou:' engoliu o relatório da oscilação"
elif ! contem 'Algumas etapas falharam'; then
  falhou "teimosa+falha: a oscilação engoliu o relatório das falhas"
else
  passou "oscilação e falha juntas: a tela conta as duas histórias"
fi

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

cenario ensaio 'etapa_falsa_mudaria etapa_falsa_quieta' '
etapa_falsa_mudaria() { passo "etapa falsa que mudaria"; meow_muda "mudaria"; return 1; }
etapa_falsa_quieta() { passo "etapa falsa que nunca escreve"; return 0; }
' --dry-run
if [ "$RC" != "0" ]; then
  falhou "ensaio: saiu $RC — um ensaio que acha o que mudar não é falha"
elif ! contem '1 etapa(s) mudariam nesta passagem.' || contem 'mudaram nesta passagem'; then
  falhou "ensaio: o rodapé diz que algo mudou — saiu: $(printf '%s' "$SAIDA" | grep 'etapa(s)')"
else
  passou "ensaio: o rodapé diz o que mudaria, e não o que mudou"
fi

cenario conf_quebrada 'etapa_falsa_escreve etapa_conf etapa_falsa_depois' '
etapa_falsa_escreve() { passo "etapa falsa que abre a fila e escreve"; meow_muda "escrevi"; return 1; }
etapa_conf() { passo "a conf de brinquedo, que não consegue escrever"; meow_erro "não consegui criar o meow.conf"; return 2; }
etapa_falsa_depois() { passo "etapa falsa que não deve rodar"; meow_muda "eu não devia estar aqui"; return 1; }
'
confere conf_quebrada
if [ "$RC" != "2" ]; then
  falhou "conf quebrada: saiu $RC — sem configuração válida não há instalação, e isso sai 2"
elif ! contem 'sem configuração válida não há o que instalar'; then
  falhou "conf quebrada: parou sem dizer que era a conf"
elif contem 'ainda escrevem'; then
  falhou "conf quebrada: o relatório do teto falou numa passagem só, e culpou etapa inocente"
elif [ "$(passagens)" != "1" ]; then
  falhou "conf quebrada: $(passagens) passagens — sem conf a segunda não tem o que tentar"
elif ! contem 'Algumas etapas falharam'; then
  falhou "conf quebrada: perdeu o único relatório que cabe neste caso"
elif contem 'não devia estar aqui'; then
  falhou "conf quebrada: a fila seguiu depois da conf, que é o que o break existe para impedir"
else
  passou "conf quebrada: para na conf, sai 2, e o teto não acusa ninguém"
fi

cenario login_sem_tema 'etapa_tema etapa_greeter' '
LOG_NIVEL=info
etapa_tema() { passo "tema falso sem captura"; TEMA_SEM_CAPTURA="falta"; return 3; }
etapa_greeter() { passo "tela de login falsa"; meow_aviso "não há captura"; return 3; }
'
if contem 'sudo -v && ./install.sh'; then
  falhou "login sem tema: o rodapé mandou ao sudo por um pulo que é de captura"
elif ! contem 'greeter: a tela de login usa o tema do COSMIC, e ele não tem captura — não é falta de root'; then
  falhou "login sem tema: o rodapé não disse que o pulo é da captura — saiu: $(printf '%s' "$SAIDA" | tail -4 | tr '\n' ' ')"
else
  passou "tela de login sem tema: o rodapé diz que falta a captura, e não manda ao sudo"
fi
cenario login_por_root 'etapa_tema etapa_greeter etapa_ocultar' '
LOG_NIVEL=info
etapa_tema() { passo "tema falso que aplicou"; TEMA_SEM_CAPTURA=""; return 0; }
etapa_greeter() { passo "tela de login falsa sem sudo"; return 3; }
etapa_ocultar() { passo "ocultar falso sem sudo"; return 3; }
'
pend_root="$(cut -f1,4 "$TMP/login_por_root/lar/.local/state/meowsystem/pendencias.tsv" 2>/dev/null | grep '^instalar-com-root')"
if contem 'sudo -v'; then
  falhou "login por root: o rodapé ainda manda digitar o sudo"
elif ! contem 'precisavam de root e se pularam: greeter ocultar' || [ -z "$pend_root" ]; then
  falhou "login por root: o pulo de root não virou pendência com as etapas — pendência «$pend_root», saiu: $(printf '%s' "$SAIDA" | tail -4 | tr '\n' ' ')"
elif contem 'não tem captura'; then
  falhou "login por root: o rodapé culpou a captura com o tema aplicado"
else
  passou "tela de login sem sudo, com o tema aplicado: o pulo de root vira pendência com botão, sem receita"
fi
cenario login_ensaio 'etapa_tema etapa_greeter' '
LOG_NIVEL=info
etapa_tema() { passo "tema falso no ensaio"; TEMA_SEM_CAPTURA="deriva"; meow_muda "derivaria"; return 1; }
etapa_greeter() { passo "tela de login falsa"; return 3; }
' --dry-run
if contem 'sudo -v && ./install.sh' || ! contem 'greeter: no ensaio a captura do tema ainda não foi escrita'; then
  falhou "login no ensaio: o rodapé não disse que a captura ainda não existe — saiu: $(printf '%s' "$SAIDA" | tail -4 | tr '\n' ' ')"
else
  passou "tela de login no ensaio: o rodapé diz que a captura ainda não foi escrita, e não manda ao sudo"
fi

[ "$FALHAS" = "0" ] || exit 1
printf 'ok: o laço das passagens fecha sozinho, e as duas guardas disparam\n'

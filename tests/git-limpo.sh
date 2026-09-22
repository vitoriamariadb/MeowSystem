#!/usr/bin/env bash
# git-limpo.sh — usar o programa não pode sujar o repositório.
#
# POR QUE ESTE ARQUIVO NASCEU EM 21/09/2026
#   Uma auditoria do git daquele dia achou a coisa mais cara que um "produto
#   para qualquer um" pode ter: o painel gravava DENTRO do clone versionado.
#   A prova estava no `git status` dele, sem precisar de teoria nenhuma —
#
#       M assets/papeis-de-parede/BANIDOS.txt     +47 linhas
#       M assets/papeis-de-parede/lado.tsv         -3 linhas
#
#   Ele tinha clicado em "Tirar" e em "Dia"/"Noite" às 17h09 e 17h10. Ninguém
#   programou nada. USAR O PRODUTO ERA UM COMMIT PENDENTE.
#
#   E já doía em DUAS PESSOAS REAIS: são três remotos entre as duas máquinas
#   (`origin`, `fork` e um caminho local), dois desktops, dois carrosséis de
#   papel de parede. Cada `git pull` entre elas era conflito de merge num
#   arquivo que nenhuma das duas editou de propósito. O `merge=ours` do
#   `.gitattributes` prometia cobrir isso e era INERTE em qualquer clone novo:
#   a declaração estava versionada, o driver só existia no `.git/config` dele.
#
# A ÚNICA CONFERÊNCIA QUE PEGA A PRÓXIMA OCORRÊNCIA
#   Consertar as sete escritas de hoje não impede a oitava. O que impede é uma
#   pergunta que a suíte faça toda vez: EXECUTAR UMA AÇÃO DE CURADORIA MUDA O
#   `git status`? Enquanto a resposta for não, o produto pode ser usado por
#   quem clonou sem virar um repositório sujo.
#
# COMO ELE MEDE, E POR QUE NÃO TOCA EM NADA DELA
#   O acervo de papel de parede, o HOME e o diretório de estado são TODOS de
#   brinquedo, criados em `mktemp -d` e apagados no fim. O que é de verdade é o
#   REPOSITÓRIO — tem de ser, porque é justamente nele que a sujeira apareceria.
#
#   A comparação é por DELTA e não por "o git status está vazio": na bancada
#   dela quase sempre há trabalho em curso, e um teste que só passa com a árvore
#   limpa é um teste que ninguém consegue rodar. O que este arquivo cobra é que
#   a lista de antes e a de depois sejam IGUAIS.
#
# ELE NÃO CONSERTA O QUE ACHAR, e isso é decisão e não preguiça: desfazer
# mudança em árvore de trabalho alheia é a forma mais rápida de apagar duas
# horas de alguém. Quando falha, ele NOMEIA os caminhos e para.
#
# CÓDIGOS DE SAÍDA (os do projeto)
#   0 = passou · 1 = falhou · 2 = erro deste teste.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf '  NÃO  %s\n' "$*" >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0

command -v git >/dev/null 2>&1 || { printf 'pulado: sem git\n'; exit 0; }
git -C "$RAIZ" rev-parse --git-dir >/dev/null 2>&1 || {
  printf 'pulado: %s não é um clone git\n' "$RAIZ"; exit 0; }

# O `-uno` DEIXA O NÃO RASTREADO DE FORA, e de propósito: a pasta de trabalho
# dela tem rascunho, e um arquivo novo que o teste não criou não é sujeira
# NOSSA. O que este teste persegue é o arquivo VERSIONADO que muda sozinho — e,
# para o arquivo que acabou de sair do git, é a regra do `.gitignore` que o
# segura, conferida logo abaixo pelo `check-ignore`.
estado_git() { git -C "$RAIZ" status --porcelain -uno | LC_ALL=C sort; }

TMP="$(mktemp -d)" || { printf 'erro: mktemp\n' >&2; exit 2; }
limpar() { rm -rf "$TMP"; }
trap limpar EXIT

printf '\n--- 1/3 uma ação de curadoria não pode mudar o git status ---\n'

ANTES="$TMP/antes"; DEPOIS="$TMP/depois"
estado_git > "$ANTES"

# O acervo de brinquedo. Duas imagens porque são dois gestos diferentes: uma
# para banir (que sai de `ativos/`) e outra para escolher o lado (que precisa
# CONTINUAR em `ativos/` para o comando aceitar).
ACERVO="$TMP/acervo"
mkdir -p "$ACERVO/ativos" || exit 2
printf 'nao e uma imagem de verdade, e nao precisa ser\n' > "$ACERVO/ativos/teste-banir.jpg"
printf 'nao e uma imagem de verdade, e nao precisa ser\n' > "$ACERVO/ativos/teste-lado.jpg"

# `env -i` não: o script precisa de PATH e de um bash utilizável. O que se troca
# é só o que decide ONDE ele escreve — e `MEOW_IGNORA_DESKTOP=1` é o mesmo
# acordo que o `reversao.sh` e o `convergencia.sh` já usam para não mexer na
# sessão gráfica de quem roda a suíte.
rodar_curadoria() {
  HOME="$TMP/home" \
  XDG_STATE_HOME="$TMP/home/.local/state" \
  MEOW_ESTADO="$TMP/estado" \
  MEOW_IGNORA_DESKTOP=1 \
  WALLPAPER_BASE="$ACERVO" \
    "$RAIZ/scripts/wallpaper.sh" "$@"
}
mkdir -p "$TMP/home" || exit 2

rodar_curadoria banir "$ACERVO/ativos/teste-banir.jpg" >"$TMP/log-banir" 2>&1
rodar_curadoria lado  "teste-lado.jpg" noite           >"$TMP/log-lado"  2>&1

# A PROVA POSITIVA VEM ANTES DA NEGATIVA, e sem ela este teste seria uma
# fraude cara: um `wallpaper.sh` que saísse com erro na primeira linha também
# deixaria o `git status` intacto, e o teste diria verde para um programa que
# não faz nada. Primeiro se confere que a curadoria ACONTECEU; depois, onde.
BANIDOS_ESTADO="$TMP/estado/papeis-de-parede/BANIDOS.txt"
LADO_ESTADO="$TMP/estado/papeis-de-parede/lado.tsv"

if [ -f "$BANIDOS_ESTADO" ] && grep -qxF 'teste-banir.jpg' "$BANIDOS_ESTADO"; then
  ok "o banimento foi registrado em \$MEOW_ESTADO/papeis-de-parede/BANIDOS.txt"
else
  falha "o banimento NÃO chegou em $BANIDOS_ESTADO"
  printf '       log: %s\n' "$(tail -3 "$TMP/log-banir" 2>/dev/null | tr '\n' ' ')" >&2
fi

if [ -f "$LADO_ESTADO" ] && grep -q 'teste-lado.jpg' "$LADO_ESTADO"; then
  ok "o lado escolhido foi registrado em \$MEOW_ESTADO/papeis-de-parede/lado.tsv"
else
  falha "o lado escolhido NÃO chegou em $LADO_ESTADO"
  printf '       log: %s\n' "$(tail -3 "$TMP/log-lado" 2>/dev/null | tr '\n' ' ')" >&2
fi

# A SEMENTE TAMBÉM É COBRADA: sem ela o arquivo de estado nasceria só com a
# linha que o teste acabou de acrescentar, e a curadoria de fábrica — as 231
# imagens que ela tirou em 24/08/2026 — voltaria no primeiro `semear` de uma
# máquina nova. É o `.padrao` cumprindo o papel que o arquivo versionado tinha.
if [ -f "$BANIDOS_ESTADO" ] && grep -qxF 'cat-dithered-barn.png' "$BANIDOS_ESTADO"; then
  ok "o estado foi semeado do BANIDOS.txt.padrao versionado"
else
  falha "o estado NÃO trouxe a lista de fábrica do BANIDOS.txt.padrao"
fi

estado_git > "$DEPOIS"
if diff -u "$ANTES" "$DEPOIS" > "$TMP/diff" 2>&1; then
  ok "git status idêntico antes e depois da curadoria"
else
  falha "a curadoria MUDOU o git status do repositório:"
  sed 's/^/       /' "$TMP/diff" >&2
  printf '       este é o defeito que a P21 veio matar — o painel voltou a\n' >&2
  printf '       escrever dentro do clone. NADA foi desfeito: confira à mão.\n' >&2
fi

printf '\n--- 2/3 os dois arquivos de curadoria fora do índice ---\n'

# DOIS, E NÃO CINCO: este título dizia "os cinco arquivos" e conferia dois.
# Os três `.map` de ícone continuam versionados de propósito — a leitura deles
# atravessa doze arquivos que a P21 não autorizou a tocar, e movê-los pela
# metade deixaria clone novo sem ícone de aplicativo. O adiamento está declarado
# na mensagem do commit, e o bloco de PENDENTE lá embaixo o conta na tela toda
# vez, para a suíte nunca dizer mais do que mede.
for alvo in assets/papeis-de-parede/BANIDOS.txt assets/papeis-de-parede/lado.tsv; do
  if git -C "$RAIZ" ls-files --error-unmatch "$alvo" >/dev/null 2>&1; then
    falha "$alvo ainda está no índice do git"
  else
    ok "$alvo fora do índice"
  fi
  if git -C "$RAIZ" check-ignore -q "$alvo"; then
    ok "$alvo coberto pelo .gitignore (o cinto do 'git add -A' distraído)"
  else
    falha "$alvo NÃO está no .gitignore — um 'git add -A' o traz de volta"
  fi
  if [ -f "$RAIZ/$alvo.padrao" ]; then
    ok "$alvo.padrao versionado (a receita de fábrica sobreviveu)"
  else
    falha "falta $alvo.padrao — clone novo perde a curadoria de fábrica"
  fi
done

printf '\n--- 3/3 o .gitignore barra o que ele promete barrar ---\n'

# CONFERIDO COM A FERRAMENTA, E NAO POR LEITURA — e a diferenca custou caro.
# Ate 21/09/2026 as quatro linhas diziam `assets/fontes/locais/*.otf`, e esse
# diretorio NUNCA existiu: o acervo real e `assets/fontes/fonts/locais/`. A
# regra nao casava nada, e o paragrafo de licenca ao lado dela — fonte de
# terceiro vem com EULA propria — estava de pe sozinho. Ler o arquivo dizia que
# estava protegido; `check-ignore` dizia a verdade.
for face in teste.otf teste.ttf teste.OTF teste.TTF; do
  alvo="assets/fontes/fonts/locais/$face"
  if regra="$(git -C "$RAIZ" check-ignore -v "$alvo" 2>/dev/null)"; then
    ok "$alvo barrado por ${regra%%$'\t'*}"
  else
    falha "$alvo NÃO é barrado — binário de fonte com EULA própria entra no commit"
  fi
done

# O LEIA-ME TEM DE CONTINUAR ENTRANDO: a regra e por EXTENSAO, e nao por
# diretorio, exatamente para isso. Um `assets/fontes/fonts/locais/*` consertaria
# o caminho e quebraria a outra metade da decisao, calado.
if git -C "$RAIZ" check-ignore -q assets/fontes/fonts/locais/LEIA-ME.txt; then
  falha "o LEIA-ME do acervo de fontes ficou de fora do git — a regra pegou demais"
else
  ok "assets/fontes/fonts/locais/LEIA-ME.txt continua versionável"
fi

# O QUE AINDA NÃO SAIU, CONTADO E NÃO AFIRMADO -- 22/09/2026
#   A P21 nomeia SETE escritas dentro do repositório versionado e esta passagem
#   entregou DUAS. Enquanto isso for verdade, um veredito final dizendo "usar o
#   programa não suja o repositório" seria mentira da suíte inteira: o botão de
#   tirar jogo do carrossel (`servidor.py`, `MAPA_JOGOS`) e o de adicionar gato
#   escrevem dentro do clone AGORA.
#
#   ISTO É CONTADO, E NÃO ESCRITO À MÃO, pela armadilha nº 3 do projeto: uma
#   frase fixa com "faltam cinco" envelhece calada no dia em que alguém mover os
#   `.map`. O laço pergunta ao índice, então a linha some sozinha quando a
#   dívida acabar — e é ela que diz se a P21 pode ser fechada.
printf '\n--- pendente: o que a P21 promete e esta passagem não entregou ---\n'
PENDENTES=0
for alvo in assets/icones/apps-arcticons.map assets/icones/apps-convertidos.map \
            assets/icones/jogos-fora.map assets/icones/arcticons-apps \
            assets/icones/convertidos-apps assets/gatos; do
  n_alvo="$(git -C "$RAIZ" ls-files -- "$alvo" | wc -l)"
  [ "$n_alvo" -gt 0 ] || continue
  PENDENTES=$((PENDENTES + n_alvo))
  printf '  ~~   %s: %s arquivo(s) que o painel escreve e o git ainda vê\n' "$alvo" "$n_alvo"
done
[ "$PENDENTES" -eq 0 ] && printf '  ok   nenhuma escrita da P21 sobrou dentro do repositório\n'

printf '\n'
if [ "$ACHADOS" -eq 0 ]; then
  if [ "$PENDENTES" -gt 0 ]; then
    printf 'ok: a curadoria de papel de parede não suja o repositório\n'
    printf '    (e só ela: %d arquivos das outras escritas da P21 seguem no índice)\n' "$PENDENTES"
  else
    printf 'ok: usar o programa não suja o repositório\n'
  fi
  exit 0
fi
printf 'FALHOU: %d achado(s)\n' "$ACHADOS" >&2
exit 1

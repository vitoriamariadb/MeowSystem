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
falha() { printf '  NAO  %s\n' "$*" >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0

command -v git >/dev/null 2>&1 || { printf 'pulado: sem git\n'; exit 0; }
git -C "$RAIZ" rev-parse --git-dir >/dev/null 2>&1 || {
  printf 'pulado: %s nao e um clone git\n' "$RAIZ"; exit 0; }

# O `-uno` DEIXA O NÃO RASTREADO DE FORA, e de propósito: a pasta de trabalho
# dela tem rascunho, e um arquivo novo que o teste não criou não é sujeira
# NOSSA. O que este teste persegue é o arquivo VERSIONADO que muda sozinho — e,
# para o arquivo que acabou de sair do git, é a regra do `.gitignore` que o
# segura, conferida logo abaixo pelo `check-ignore`.
estado_git() { git -C "$RAIZ" status --porcelain -uno | LC_ALL=C sort; }

TMP="$(mktemp -d)" || { printf 'erro: mktemp\n' >&2; exit 2; }
limpar() { rm -rf "$TMP"; }
trap limpar EXIT

printf '\n--- 1/3 uma acao de curadoria nao pode mudar o git status ---\n'

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
  falha "o banimento NAO chegou em $BANIDOS_ESTADO"
  printf '       log: %s\n' "$(tail -3 "$TMP/log-banir" 2>/dev/null | tr '\n' ' ')" >&2
fi

if [ -f "$LADO_ESTADO" ] && grep -q 'teste-lado.jpg' "$LADO_ESTADO"; then
  ok "o lado escolhido foi registrado em \$MEOW_ESTADO/papeis-de-parede/lado.tsv"
else
  falha "o lado escolhido NAO chegou em $LADO_ESTADO"
  printf '       log: %s\n' "$(tail -3 "$TMP/log-lado" 2>/dev/null | tr '\n' ' ')" >&2
fi

# A SEMENTE TAMBÉM É COBRADA: sem ela o arquivo de estado nasceria só com a
# linha que o teste acabou de acrescentar, e a curadoria de fábrica — as 231
# imagens que ela tirou em 24/08/2026 — voltaria no primeiro `semear` de uma
# máquina nova. É o `.padrao` cumprindo o papel que o arquivo versionado tinha.
if [ -f "$BANIDOS_ESTADO" ] && grep -qxF 'cat-dithered-barn.png' "$BANIDOS_ESTADO"; then
  ok "o estado foi semeado do BANIDOS.txt.padrao versionado"
else
  falha "o estado NAO trouxe a lista de fabrica do BANIDOS.txt.padrao"
fi

estado_git > "$DEPOIS"
if diff -u "$ANTES" "$DEPOIS" > "$TMP/diff" 2>&1; then
  ok "git status identico antes e depois da curadoria"
else
  falha "a curadoria MUDOU o git status do repositorio:"
  sed 's/^/       /' "$TMP/diff" >&2
  printf '       este e o defeito que a P21 veio matar — o painel voltou a\n' >&2
  printf '       escrever dentro do clone. NADA foi desfeito: confira a mao.\n' >&2
fi

printf '\n--- 2/3 os cinco arquivos de estado fora do indice ---\n'

# Os dois que a P21 tirou do git. Os tres `.map` de icone NAO estao nesta lista
# de proposito: eles continuam versionados, e o porque esta no relatorio da
# sprint — a leitura deles atravessa doze arquivos que a P21 nao autorizou a
# tocar, e move-los pela metade deixaria clone novo sem icone de aplicativo.
for alvo in assets/papeis-de-parede/BANIDOS.txt assets/papeis-de-parede/lado.tsv; do
  if git -C "$RAIZ" ls-files --error-unmatch "$alvo" >/dev/null 2>&1; then
    falha "$alvo ainda esta no indice do git"
  else
    ok "$alvo fora do indice"
  fi
  if git -C "$RAIZ" check-ignore -q "$alvo"; then
    ok "$alvo coberto pelo .gitignore (o cinto do 'git add -A' distraido)"
  else
    falha "$alvo NAO esta no .gitignore — um 'git add -A' o traz de volta"
  fi
  if [ -f "$RAIZ/$alvo.padrao" ]; then
    ok "$alvo.padrao versionado (a receita de fabrica sobreviveu)"
  else
    falha "falta $alvo.padrao — clone novo perde a curadoria de fabrica"
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
    falha "$alvo NAO e barrado — binario de fonte com EULA propria entra no commit"
  fi
done

# O LEIA-ME TEM DE CONTINUAR ENTRANDO: a regra e por EXTENSAO, e nao por
# diretorio, exatamente para isso. Um `assets/fontes/fonts/locais/*` consertaria
# o caminho e quebraria a outra metade da decisao, calado.
if git -C "$RAIZ" check-ignore -q assets/fontes/fonts/locais/LEIA-ME.txt; then
  falha "o LEIA-ME do acervo de fontes ficou de fora do git — a regra pegou demais"
else
  ok "assets/fontes/fonts/locais/LEIA-ME.txt continua versionavel"
fi

printf '\n'
if [ "$ACHADOS" -eq 0 ]; then
  printf 'ok: usar o programa nao suja o repositorio\n'
  exit 0
fi
printf 'FALHOU: %d achado(s)\n' "$ACHADOS" >&2
exit 1

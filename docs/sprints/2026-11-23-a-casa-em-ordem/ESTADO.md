# Estado da leva de 23/11 (coordenador)

Árvore desta leva: `../.meow-wt-leva-23`, branch `docs/leva-2026-11-23`, a partir do `master` `9110e7d7`. O `master`
e o GitHub seguem intocados: tudo vive em branches locais.

## O pedido (23/11)
1. Rodar o install completo, ler cada linha e propor a solução do que aparecer. Feito: 1 passagem, 77 etapas, 71
   conferem, 6 puladas, 0 falhas; o `meow doctor` logo depois sai 1. Os achados são a P264 até a P270.
2. «Vamos começar pela limpeza da casa»: toda arte só nos packs, pastas legadas fora do repositório (local e
   online), pastas mescladas, testes antigos apagados, o repositório barato de ler. São a P271 até a P287.
3. «Manda ver» sobre os dez passos, com os agentes de cada um. Quem mexe nos testes é o coordenador.

## Feito
- Catálogo do repositório por quatro agentes de leitura, sem escrita no repositório: `CATALOGO.md`. Os quatro
  relatórios inteiros e as saídas do install e do doctor estão em `~/.cache/meow-leva/catalogo-2026-11-23/`.
- 24 tarefas escritas (P264 a P287). A ordem, os agentes de cada passo, a regra da suíte e o encaixe das herdadas
  estão no `00-leva.md`.
- As respostas de quem usa (três rodadas de AskUserQuestion) estão no `00-leva.md`, seção «As decisões tomadas».

- «Manda ver» de quem usa, 23/11, sobre a ordem dos dez passos com os agentes de cada um.
- Passo 1 (P271) feito no nitro-5; o que saiu e o que ficou está no fim da P271.

## Onde a leva parou (24/11/2026, 9h)
Os dez passos estão feitos no nitro-5 e no desktop. O `master` do GitHub é a raiz nova `11ed66b8`, com a tag
`v2.4.0`, o run `testes` verde e a atualização sozinha religada. O que cada passo mediu está no fim da tarefa dele;
o do passo 10, no fim da `P284`.

A única árvore de trabalho que sobrou é esta, `../.meow-wt-leva-23`, na branch `docs/fecho-da-leva`: os commits dela
(este estado e o fecho da `P284`) ainda não foram enviados. As outras árvores, as branches e as tags de antes saíram
do nitro-5; o histórico de antes mora em `~/Backups/meowsystem/` (decisão 24).

## Próximo passo
1. Enviar a `docs/fecho-da-leva` ao `master`, com a palavra de quem usa.
2. O portátil, quando ligar (roteiro no fim da `P284`).
3. O que ficou aberto no fim da `P284`, a `P269` e a `P267`.
4. A leva seguinte: a `P283` e o `PARA-A-PROXIMA-LEVA.md`. O índice de código (`fazer_grafos`) abre essa leva.

## Abertos que não podem se perder
O que ficou para depois desta leva está no `PARA-A-PROXIMA-LEVA.md`. Desta leva, seguem abertos:
- P269: a linha do Hefesto no `appid.map` espera a medida no desktop, com o Hefesto aberto.
- P267: a linha `revisao cosmic-applets` do contrato espera o clone do fonte e a conferência pelo palco.
- P277: a tabela `packs/CAMINHOS-DE-ANTES.tsv` só sai depois de o install rodar no nitro-5.

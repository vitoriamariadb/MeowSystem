# P156 — o rodapé da página Tema

Pedido dela, 04/11/2026 (captura: um cartão de tema; ao lado, «Cor de destaque» da altura do cartão, quase
vazia; embaixo, «Claro ou escuro» e «Criar o meu tema»).

## O que se mediu

`app/pagina/paginas.js` `paginaTema()`: a `grade-tema` põe cada cartão com `span 2`, e a «Cor de destaque»
também com `span 2`, na mesma grade. Com número ímpar de temas ela ocupa a vaga ao lado do último cartão e
estica até a altura dele; com número par ela desce. Os três nunca ficam juntos.

## A cura

Escolha dela (AskUserQuestion, 04/11): **faixa de 3 no rodapé**. Depois de todos os cartões, uma fileira própria
com Cor de destaque | Claro ou escuro | Criar o meu tema, lado a lado, a mesma altura de bloco comum (a do
«Claro ou escuro» de hoje), com 1, 2 ou 5 temas. A fileira é um elemento separado da grade dos cartões, não
depende do `span`. Em tela estreita os três empilham.

## Como se prova

Teste de navegador (padrão de `tests/app-layout.py`) com 1 e com 2 packs: os três `top` iguais, alturas iguais,
e o `top` deles abaixo do `bottom` do último cartão. Captura headless para o fecho.

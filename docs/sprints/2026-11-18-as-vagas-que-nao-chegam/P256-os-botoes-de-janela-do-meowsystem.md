# P256 — os botões de janela do MeowSystem não se leem (19/11/2026)

Pedido de quem usa, 19/11: «no meowsystem os gatos de diminuir fechar e maximizar. Na prática não ficaram legais.
Preciso que atue nisso também.» Direção (AskUserQuestion, 19/11): «Outra metáfora de gato, mais simples».

## O que se mediu (coordenador, 19/11, folha em 96, 24 e 16 px no traço do pack)
- Hoje, em `packs/meowsystem/icones/sistema/`: `window-close` é um arranhão em X, `window-minimize` um novelo com o
  fio, `window-maximize` uma caixa de papelão aberta, `window-restore` duas caixas (decisão 59, P231).
- Em 16 px o novelo vira um borrão redondo e a caixa não se lê como maximizar; o X é o único que se lê.

## A causa
O objeto escolhido não carrega o gesto: novelo não diz «descer», caixa não diz «crescer». E o detalhe (fios, abas)
não cabe em 16 px com traço de 2,5.

## A cura
1. Duas propostas novas por botão (fechar, minimizar, maximizar, restaurar), ainda com tema de gato, em que a
   forma do gesto vem primeiro e o gato é a silhueta: no máximo três traços por desenho, nada de textura, legível
   em 16 px. Ideias de partida, a testar na folha: o gato deitado achatado na base (minimizar), o gato de pé ou
   esticado enchendo o quadro (maximizar), dois gatos ou gato e sombra sobrepostos (restaurar), as duas orelhas
   cruzadas ou a pata riscando (fechar).
2. Fora do `sistema.map` até quem usa escolher no quadro; o desenho de hoje fica no pack.
3. Com a escolha: mapa, `PROCEDENCIA.md` com sha256, e a linha da decisão 59 se o texto dela citar o desenho.

## Como se prova
Folha de contato em 16, 22, 24 e 96 px, claro e escuro, ao lado dos de hoje; `tests/vagas-novas.sh`,
`icones-do-sistema.sh`, `desenho-no-pack.sh`, `pack.sh`. Foto da barra de título no palco depois da escolha.

## Nos três PCs
Os dois da Vitória (pack `meowsystem`) e todo pack pessoal que herda dele (P241).

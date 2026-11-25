# P299 · O btop sem o mauve do Mocha cravado

## O que se mediu
`scripts/temas-de-apps/btop-bat/manifesto.sh` trazia `#cba6f7` (o mauve do Mocha) num `sed` que só rodava com
`MEOW_BTOP_ACENTO=mauve`. Nenhum arquivo do projeto, nem o `meow.conf` dos três PCs, liga essa variável: o ramo
nunca rodou. Ligado, pintaria o mauve do Mocha em qualquer flavor e em qualquer pack.

## A causa
Um acento opcional escrito antes de a cor morar no pack, que ficou sem quem o ligasse.

## A cura
Os dois ramos saíram (`_bb_btop_tema_stem` e `_bb_btop_conteudo`): o tema do btop é o vendorizado do pack no ar,
sem retoque de cor no código.

## A prova
`tests/temas-de-apps.sh` ganhou a guarda «nenhum módulo de app crava cor no código». Vermelho com o manifesto de
antes, verde com o novo; `temas-de-apps.sh`, `apps-em-todo-pack.sh` e `flavor-padrao.sh` verdes pelo `todos.sh`.

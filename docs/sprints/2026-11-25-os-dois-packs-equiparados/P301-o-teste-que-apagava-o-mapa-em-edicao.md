# P301 · O teste que apagava o mapa em edição

## O que se mediu
Com uma linha nova e ainda sem commit em `packs/meowsystem/icones/apps-convertidos.map` (a receita do COSMIC Viewer),
rodar `tests/git-limpo.sh` pela suíte devolveu o arquivo ao último commit: a linha sumiu e o teste que a esperava
ficou vermelho.

## A causa
A faxina da seção 3/4 fazia `git checkout -- packs/meowsystem/icones/apps-convertidos.map`, sem condição. Isso
desfaz o que o teste escreveu e, junto, qualquer edição de quem está trabalhando no mapa.

## A cura
O teste guarda uma cópia do mapa ao entrar na seção e devolve essa cópia no fim, só se o arquivo mudou.

## A prova
Com a linha do Viewer sem commit: antes, `git-limpo.sh` rodado e a linha some (0 ocorrências); depois, `git-limpo.sh`
verde e a linha continua (1 ocorrência).

# Andamento do bloco B (arte do Dracula)

Árvore `../.meow-wt-arte`, branch `bloco/arte-dracula`. Ordem: P206, P208, P207; um commit por tarefa.

| tarefa | estado | commit |
| --- | --- | --- |
| P206 os escolhidos viram padrão | feita | ver `git log` |
| P208 pastas com borda | feita | ver `git log` |
| P207 botões de janela | feita | ver `git log` |

## P206
- Os 11 desenhos escolhidos da `biblioteca/` mudam para `apps/` (uma versão por ícone, o precedente da P96), com a
  ficha do `catalog.json`, a linha do `PROCEDENCIA.md` e a linha do `packs/CAMINHOS-DE-ANTES.tsv` (o mapa de quem
  usa aponta para `biblioteca/` e continua resolvendo).
- O desenho anterior de Câmera, Calculator e Gradia sai de `apps/` e fica na `biblioteca/` (o seletor ainda o oferece).
- Prova: tema montado com HOME temporário, sem o mapa escolhido e com ele, dá o mesmo sha256 nos 13 ids.
- O instalador corta o `\n` final do SVG (`meow_escrever "$(cat …)"`), então o sha do tema bate com o do arquivo
  sem o `\n` final: achado colateral, fora deste bloco.

## P208
- As dez pastas ganham o traço de 1,5 em `#A267F6` (o mauve do meio entre `dracula` e `alucard`) nas costas e na
  frente: 3,2:1 contra `#3b3552` e 3,19:1 contra `#F0F0F6`; o `tests/pastas-do-pack.sh` mede.
- Os `folder-symbolic`, `folder-new-symbolic` e `user-home-symbolic` são simbólicos (`currentColor`) e ficam.

## P207
- Os cinco `window-*-symbolic` viram silhuetas cheias em `currentColor` (sem traço): minimizar é um morcego
  pousado embaixo, maximizar a moldura de um caixão, restaurar duas lápides, destacar um fantasma saindo da janela e
  fechar dois ossos cruzados. O `icones_sistema.sh` os pinta com o `text` do flavor, em 22 px e no escalável.

## Conferência (16/11)
- P206: tema montado com HOME temporário, master contra branch, id a id: só os 14 nomes da P206 mudam; os 13
  escolhidos batem o sha256 (6 deles sem o `\n` final, o corte do instalador). TSV: só as linhas novas diferem.
- P208 e P207: renderizados em 16/24/32/48/128 nos dois fundos; borda a 3,2:1 e 3,19:1.
- `tests/icones-por-pack.py`: o «Usar» clica uma variação gerada antes de usar (linha 215), sem depender de
  botão desligado; a integração concilia com a P204/P210.

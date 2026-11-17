# Andamento do bloco B (arte do Dracula)

Árvore `../.meow-wt-arte`, branch `bloco/arte-dracula`. Ordem: P206, P208, P207; um commit por tarefa.

| tarefa | estado | commit |
| --- | --- | --- |
| P206 os escolhidos viram padrão | feita | ver `git log` |
| P208 pastas com borda | a fazer | |
| P207 botões de janela | a fazer | |

## P206
- Os 11 desenhos escolhidos da `biblioteca/` mudam para `apps/` (uma versão por ícone, o precedente da P96), com a
  ficha do `catalog.json`, a linha do `PROCEDENCIA.md` e a linha do `packs/CAMINHOS-DE-ANTES.tsv` (o mapa de quem
  usa aponta para `biblioteca/` e continua resolvendo).
- O desenho anterior de Câmera, Calculator e Gradia sai de `apps/` e fica na `biblioteca/` (o seletor ainda o oferece).
- Prova: tema montado com HOME temporário, sem o mapa escolhido e com ele, dá o mesmo sha256 nos 13 ids.
- O instalador corta o `\n` final do SVG (`meow_escrever "$(cat …)"`), então o sha do tema bate com o do arquivo
  sem o `\n` final: achado colateral, fora deste bloco.

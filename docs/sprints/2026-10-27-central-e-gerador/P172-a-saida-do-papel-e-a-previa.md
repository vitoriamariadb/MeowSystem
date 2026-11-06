# P172 — a saída do papel e a prévia que some (06/11/2026)

Achados da P168 e da suíte do bloco 0.

## O que se mediu

- A saída de `cmd_lado`, em `scripts/wallpaper.sh`, manda usar «Devolver» do grupo «Fora», que não existe mais (decisão 51), e diz «veja: ls ...», mandando digitar.
- `tests/app-completo.py` deu 10 respostas 404 em `/previa`, «prévia ainda não gerada», na tela `ajustes/papel`, depois de `acao:files_menu` e de `descartar`.

## A causa

- A saída é anterior à decisão 51.
- As imagens pedidas tinham `pronta: true` na lista que a página guardou, e a prévia deixou de existir no servidor: a lista em cache fica velha. Hipótese: a chave de `_previa_chave` muda depois de uma ação. Medir antes de corrigir.

## A cura

- A saída diz o que aconteceu e o doctor faz o resto, sem verbo que não existe e sem comando para digitar.
- A prévia velha se renova sozinha: a página refaz a lista ou o servidor devolve a prévia sem 404. A cura depende da medida.

## Como se prova

`tests/nada-manda-digitar.sh` pega a saída antiga; um teste novo reproduz o 404 e passa com a cura; `tests/app-completo.py` termina verde.

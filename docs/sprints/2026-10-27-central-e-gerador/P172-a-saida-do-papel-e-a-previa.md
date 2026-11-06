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

## Execução

Commit `8d518122`.

- **A causa medida não é a da hipótese.** Com o servidor instrumentado numa cópia, o `/previa` caía em `item is None` com a lista vazia (`SEM-ITEM ativos/brinquedo-00.png []`), não em chave nova. `_previa_chave` não muda. O passeio escreve «Brinquedo» no campo `WALLPAPER_BASE`: a pasta dos papéis muda, o servidor não acha mais a imagem, e a página segue com a lista antiga em `PREVIAS`. O «depois de `acao:files_menu`» e o «depois de `descartar`» eram só o último clique registrado; a ação não tem nada com isso.
- **A cura.** `enviarLote`, em `app/pagina/app.js`, esquece as listas `parede/` quando `WALLPAPER_BASE` grava, e o Desfazer passa pelo mesmo caminho.
- **A saída.** `cmd_lado` diz o que aconteceu («ela foi recusada e saiu do acervo; a cópia em banidos/ o doctor apaga» e «o lado vale só para imagem do acervo»), sem «Devolver» e sem `veja: ls`.

Provas:

- `tests/galeria-do-papel.py`, antes da cura: `XX  nenhuma prévia da pasta antiga fica pedindo 404 (lista: [404, 404, 404, 404, 404]; respostas: 5)`, `FALHOU: 3 de 11`.
- `tests/galeria-do-papel.py`, com a cura: `ok  nenhuma prévia da pasta antiga fica pedindo 404 (lista: []; respostas: 0)`, `ok: 11 conferências da galeria do papel de parede`.
- `tests/nada-manda-digitar.sh` no código antigo: `FALHOU: mensagens que ainda mandam digitar`, com `scripts/wallpaper.sh:1147` e `:1149`. No novo: `passou: nada manda digitar`.
- `tests/app-completo.py` inteiro: `1410 conferências, 264 moldes acionados, 384 vistos, 1674s`, `ok: o painel inteiro, porta por porta e controle por controle`, nenhum `XX`.

Da mão de quem usa: mudar a pasta dos papéis no painel e ver a galeria se refazer sem imagem quebrada.

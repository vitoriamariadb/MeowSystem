# P271 — a limpeza do disco, fora do git (23/11/2026)

## O que se mediu (nitro-5, 23/11)
- Seis árvores de trabalho: `.meow-wt-assinatura`, `.meow-wt-cache-tema`, `.meow-wt-dock-junta`,
  `.meow-wt-integracao-20` e `.meow-wt-leva-19`, todas já no `master` (`9110e7d7`), e a desta leva.
- Na raiz do repositório, ignorados pelo git: `.trabalho-icones/` (24 MB), `docs/sprints/*/fotos/` (3,1 MB), os
  `__pycache__` (1,6 MB) e `assets/temas-de-apps/` (um `.pyc` de 24/09).
- Em `~/.config/meow/`: quatro `meow.conf.antes-*` (setembro e outubro).
- Em `~/.local/state/meowsystem/`: `backup-limpeza-20261024`, `backup-limpeza-20261025`,
  `backup-temas-terceiros-20261024`, `guardado-16-10` e os registros `*-17-10.log`, `compositor-15-10.log`.

## A causa
Cada leva deixou a árvore dela e os rascunhos; o estado guarda cópias de limpezas de outubro que a decisão 56 não
cobre, porque não estão no `assets/contratos/espaco.tsv`.

## A cura
Sim de quem usa, 23/11/2026 (AskUserQuestion): `.trabalho-icones/`, as árvores integradas e os backups e registros
velhos.
1. Antes de apagar, listar o conteúdo de cada alvo com o tamanho.
2. `git worktree remove` em cada árvore integrada e `git branch -d` na branch dela (o `-d` recusa o que não está no
   `master`).
3. Apagar os ignorados da raiz e os quatro `meow.conf.antes-*`.
4. No estado: apagar os `backup-limpeza-*` e os registros de outubro. O `tema-PRIMEIRO`, os `-sistema`, o
   `meow.conf-antes-da-instalacao` (decisão 56) e o que é cópia de coisa de quem usa ficam.

## Como se prova
- `git worktree list` com duas linhas: o checkout e a árvore desta leva.
- `git status --short --ignored` sem `.trabalho-icones/`, `fotos/` nem `__pycache__`.
- `meow espaco` antes e depois; `meow doctor` sem divergência nova.

## Feito no nitro-5 (23/11)
- Saíram as cinco árvores integradas e as branches delas (`git branch -d` aceitou as cinco), `.trabalho-icones/`,
  os três `__pycache__`, `assets/temas-de-apps/`, os quatro `meow.conf.antes-*`, os dois `backup-limpeza-*` e os
  nove registros de 15/10 e de 17/10.
- Conferido antes: dos 33 SVG do rascunho, 25 têm cópia byte a byte nos packs, 7 têm sucessor de mesmo nome e o
  oitavo (`_discord-b.svg`) é a alternativa que perdeu para a `discord-c.svg` em 23/10.
- Ficaram, por serem de quem usa: `backup-temas-terceiros-20261024` (o conf do OnlyOffice e do qBittorrent de antes
  do tema) e `guardado-16-10` (um SVG editado à mão). Ficaram também as `fotos/` das levas de 10/11 e de 17/11
  (3,1 MB, fora do git): saem quando a P273 chegar ao checkout.
- `git worktree list` com duas linhas. O `meow doctor` de depois difere do de antes só na linha do disco
  (10,7 GB para 10,6 GB).

## Nos três PCs
Feito no nitro-5. No desktop e no portátil só a parte do estado e do `~/.config/meow`, depois de listar o que há lá,
no dia da P284.

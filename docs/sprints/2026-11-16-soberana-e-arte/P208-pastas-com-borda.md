# P208 — as pastas do Dracula com borda nítida (16/11/2026)

Texto de quem usa: «nossa pastas todas elas precisam ter a borda mais nitida e destacada».

## O que se mediu
`packs/dracula/icones/sistema/{folder,folder-documents,folder-download,folder-music,folder-pictures,folder-publicshare,
folder-templates,folder-videos,user-home,user-desktop}.svg` (o `pastas.map` liga as dez): corpo `#433f4d`/`#534b62`, sem
contorno. Renderizadas sobre o fundo do lançador (`#3b3552`), somem: a aba e a borda quase não se veem.

## A cura na origem
- Contorno nítido em todas as dez, no mesmo desenho: traço contínuo de cor clara da paleta do pack
  (`packs/dracula/paleta.json`, ex. o `comment` ou o acento roxo), espessura que se lê a 16 px sem engrossar a 128 px,
  aba destacada do corpo. Uma regra só para as dez; a silhueta não muda.
- Conferir também os `folder-*-symbolic` e `user-home-symbolic`: se forem simbólicos (pintados pelo tema), ficam.

## Como se prova
Contraste medido do contorno contra `#3b3552` e contra o fundo claro (alucard) ≥ 3:1 (WCAG para gráfico); PNG de prova
16/48/128 px sobre os dois fundos; testes de pasta (`tests/derivados.sh` e o que o grep de `pastas.map` achar) verdes.

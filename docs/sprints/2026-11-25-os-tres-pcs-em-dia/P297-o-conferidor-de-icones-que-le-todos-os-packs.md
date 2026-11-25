# P297: o conferidor de ícones que lê todos os packs

## O que se mediu (25/11, MeowSystem, pack `meowsystem`)
`meow cosmic icones` dizia «todo app visível do COSMIC instalado tem desenho num mapa». O COSMIC Viewer
(`com.system76.CosmicViewer`) não está em mapa nenhum do pack `meowsystem` nem no tema instalado; só o
`packs/dracula/icones/apps.map` o desenha.

## A causa
`CV_MAPAS`, no `scripts/cosmic_prever.sh`, era `packs/*/icones/*.map`: o desenho de qualquer pack contava como
desenho do pack no ar. A segunda metade da lista, `assets/icones/*.map`, aponta para uma pasta que saiu na P274.
O mesmo engano valia para o `completar_icones.sh` e para a sentinela, que usam a mesma lista.

## O que entra no tema, medido
No nitro-5 (Dracula no ar) o `com.system76.CosmicPlayer`, que só o mapa do `meowsystem` desenha, está em
`48x48/apps`: os mapas de `packs/meowsystem/icones/` são do motor e valem com qualquer pack. O mapa do pack no ar
(`icones.apps.mapa` e o dos resgatados) soma por cima.

## A cura
A lista passa a ser os mapas do motor mais os do pack no ar, perguntados ao `pack.py acervo`. Sem `PACK` no ambiente
(a sentinela roda por timer), o pack vem do `meow.conf`.

## Como se prova
- `tests/cosmic-prever.sh`: um nome que só o Dracula desenha «vale com o Dracula no ar e falta com o pack padrão no
  ar», e «sem PACK no ambiente, o pack no ar vem do meow.conf». Vermelho antes, verde depois.
- `meow cosmic icones` no MeowSystem: «sem desenho: com.system76.CosmicViewer». Com `PACK=dracula`: tudo coberto.

## O que fica para quem usa
O desenho do COSMIC Viewer no pack `meowsystem` é arte: entra na folha do que falta nos dois packs.

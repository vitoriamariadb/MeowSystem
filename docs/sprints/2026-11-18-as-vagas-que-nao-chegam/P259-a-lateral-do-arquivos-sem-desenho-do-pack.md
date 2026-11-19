# P259 — a lateral do Arquivos ainda usa o ícone de fábrica (19/11/2026)

## Texto de quem usa
Com a foto da lateral do COSMIC Files: «ESSES SVGS NÃO ALTERAMOS TAMBEM. TEMOS QUE FAZÊ-LO INCLUSIVE.»

## O que se mediu (nitro-5, 19/11 13h45)
- Na foto, a lateral mistura glifo cheio (recentes, documentos, downloads, música, imagens, vídeos, disco, lixeira,
  ejetar) com glifo de contorno (pasta pessoal, pastas): metade é do tema de base.
- No `sistema.map` dos dois packs não há linha para `document-open-recent-symbolic`, `folder-documents-symbolic`,
  `folder-download-symbolic`, `folder-music-symbolic`, `folder-pictures-symbolic`, `folder-videos-symbolic`,
  `drive-harddisk-symbolic`, `user-trash-symbolic`. Há para `user-home-symbolic`, `folder-symbolic`,
  `network-workgroup-symbolic`, `media-eject-symbolic`.
- Não se mediu ainda o nome exato que o `cosmic-files` pede em cada linha da lateral.

## A causa (a provar)
As vagas da lateral nunca entraram no levantamento de nomes (P243 e P253 partiram dos applets e do painel).

## A cura na origem
- Medir no fonte do `cosmic-files` (a árvore que o `scripts/files_menu.sh` compila) ou no binário os nomes que a
  lateral pede, e para cada um qual arquivo o tema instalado entrega hoje.
- Desenhar o que falta em cada pack, no traço do pack (`traco_do_sistema`), e ligar no `sistema.map` com a linha na
  `PROCEDENCIA.md`. Os que já têm linha e saem errados na foto (ejetar cheio, rede) entram na medida.

## Como se prova
- Foto da janela real do Arquivos no palco, antes e depois, nos dois packs.
- `tests/vagas-novas.sh`, `tests/desenho-no-pack.sh`, `tests/icones-do-sistema.sh`, `tests/pack-traz-o-que-usa.sh`,
  `tests/tres-pastas.sh`, `tests/icones-por-pack.py`, `tests/higiene.sh`, `tests/acento.sh` verdes.

## Nos três PCs
Vale nos três.

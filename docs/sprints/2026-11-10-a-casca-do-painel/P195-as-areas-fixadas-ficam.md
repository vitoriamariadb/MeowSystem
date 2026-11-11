# P195 — as áreas fixadas ficam (10/11/2026)

Texto de quem usa: «por que os workspaces não ficam pinados?»

## O que se mediu

1. `~/.config/cosmic/com.system76.CosmicComp/v1/pinned_workspaces` (07/11 04:31) tem duas áreas, « Pop » e
   « OS », as duas presas à `eDP-1`. Pela decisão 53, em modo juntas a lista vive numa tela só, e o
   `cosmic-comp-nomes-nas-duas-telas.patch` repete os nomes na outra.
2. O que «não ficam pinadas» quer dizer na tela ainda não foi visto: a área perde o alfinete após login? Some do
   monitor externo? Volta com outro nome? Medir na sessão real com quem usa.

## A cura na origem

- Primeiro reproduzir com quem usa (o que fez, o que viu). Depois achar se quem desfaz é o cosmic-comp, o
  `areas.sh` (install, doctor, `areas_aplicar`) ou o religar do monitor.
- Se o arquivo muda sozinho, a cura mora em quem escreve; se o arquivo fica e a tela não, mora no patch.

## Como se prova

- `pinned_workspaces` igual antes e depois de logout, de tirar e religar o monitor e de um `meow doctor --consertar`.
- Na tela, as duas áreas com o alfinete nas duas telas.

Tamanho: 2 a 4 h, só quem coordena, sessão real. Mesma família da P194: mesmo bloco.

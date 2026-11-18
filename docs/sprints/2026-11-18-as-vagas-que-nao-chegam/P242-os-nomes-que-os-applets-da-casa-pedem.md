# P242 — os applets da casa pedem nomes que o pack não liga a desenho nenhum (18/11/2026)

Pedido de quem usa, 18/11: «alguns ícones não mudaram», com a foto do sino e da bateria genéricos no Dracula.

## O que se mediu (coordenador, nitro-5, 18/11)
- Ajustes rápidos (`quick-settings`, commit `4b049480`) desenha o sino com `notification-symbolic` e
  `notification-new-symbolic` (`src/app.rs:1460` e `:1467`) e a bateria com o `icon-name` do UPower mais `-symbolic`
  (`src/app.rs:1516`, `src/tiles.rs:400`). Nesta máquina o UPower diz `battery-full-charged-symbolic`.
- O pack Dracula tem os desenhos (`notification-symbolic.svg`, `battery-level-100-charged-symbolic.svg`, a ampulheta
  do P232), mas o `sistema.map` só os liga a `cosmic-applet-notification-*` e `cosmic-applet-battery-level-*`, os
  nomes que os applets de fábrica do COSMIC pedem. Ninguém nesta barra pede esses nomes.
- No tema instalado: `notification-symbolic`, `notification-new-symbolic`, `battery-full-charged-symbolic` e
  `color-select-symbolic` não existem. Caem no `MeowSystem-Icons-Base` (dracula-icons), que é o desenho genérico.
- `assets/contratos/nomes-das-extensoes.tsv` tem duas linhas, as da Soneca.
- Nomes `*-symbolic` no fonte dos applets pinados que nenhum dos dois contratos cobre: `quick-settings` 31
  (`notification-*`, `power-profile-*`, `bluetooth-*`, `network-wireless-{disabled,encrypted,offline}`,
  `network-vpn-disabled`, `camera-web`, `weather-clear-night`, `view-app-grid`, entre outros), `drives` 4,
  `status-hub` 3, `now-playing` 2, `eyedropper` 1 (`color-select-symbolic`). Fora da conta: os nomes que o UPower
  monta em tempo de execução (`battery-{full,good,low,caution,empty}[-charging|-charged]`, `battery-missing`) e o
  `battery-level-<N>-symbolic` dos periféricos (`src/tiles.rs:394`).

## A causa
O contrato de nomes foi levantado do que o COSMIC de fábrica pede (`nomes-de-sistema.tsv`). Os applets da casa, que
são o padrão do install (`PADRAO="sim"` nos pinos), pedem nomes freedesktop e do UPower, e esses nunca entraram no
contrato nem nos mapas.

## A cura na origem
1. `nomes-das-extensoes.tsv` passa a listar todo nome que um applet pinado pede, com o applet na coluna «quem pede».
2. Os `sistema.map` dos dois packs ligam esses nomes aos desenhos que já existem (linha com `:alias` onde o desenho se
   repete de propósito): o sino, os níveis de bateria do UPower para o nível mais próximo, o `battery-level-<N>`.
3. Nome sem desenho no pack vira vaga do criador, como os botões da janela (decisão 59). Desenho novo só com arte
   aprovada: entra no quadro do P243.
4. Um teste lê o fonte do applet no commit do pino, quando ele está na máquina
   (`~/.local/state/meowsystem/extensoes/<id>/src`), e cobra que cada `"...-symbolic"` esteja no contrato. Sem o
   fonte, o teste diz que pulou (pulado não é verde).

## Como se prova
`tests/icones-do-sistema.sh` e `tests/vagas-novas.sh` verdes; o teste novo do item 4. No palco, com o Dracula: foto da
barra com o sino e a ampulheta do pack no Ajustes rápidos, e a mesma foto com o `meowsystem`. Install real pelo
coordenador, duas passadas, a segunda sem escrever.

## Nos três PCs
nitro-5: resolve o sino, a bateria e o conta-gotas. Desktop e portátil: só depois do P241; o desktop não tem bateria.

# P290 — o `mimeinfo.cache` que só o doctor refaz (23/11/2026)

Herdada da leva de 18/11.

## O que se mediu (integração, 23/11)
- `scripts/lancador.sh` refaz o `mimeinfo.cache` do home (`update-desktop-database`) e acusa quando ele é mais
  velho que um lançador.
- `scripts/atalho.sh`, `scripts/icones_resgatados.sh` e as etapas que criam sombra de `.desktop` escrevem em
  `~/.local/share/applications` e não refazem a cache. `flatpak_tema.sh`, `jogos_heroic.sh` e `icones_absolutos.sh`
  refazem, cada um do seu jeito.
- Efeito: depois dessas etapas a cache fica velha até a etapa do lançador ou o doctor passarem; o install pode
  pedir uma segunda passada por isso. Falta medir se pede.

## A causa
Cada etapa que escreve um `.desktop` decidiu sozinha se refaz a cache.

## A cura na origem
Um ajudante só em `lib/` («escrevi um lançador, a cache está velha») usado por toda etapa que escreve em
`applications/`; a cache é refeita uma vez, no fim da etapa que escreveu.

## Como se prova
- Casa de mentira com `update-desktop-database` falso que registra chamada: cada etapa que escreve um lançador
  deixa a cache mais nova que ele; a segunda passada não chama.
- `tests/lancador-do-meow.sh` e `tests/convergencia.sh` verdes.

## Feito (24/11, bloco `install-herdadas`, integrado em `eae6f987`)
- `meow_cache_dos_lancadores` em `lib/comum.sh`, chamado uma vez no fim de cada etapa que escreve lançador
  (13 scripts). `atalho.sh`, `appid_dock.sh` e `icones_resgatados.sh`, que nunca refaziam, passaram a refazer.
- Quem conferiu corrigiu três pontos: o reverter do `escritorio.sh` devolve atalho com data antiga (`cp -p`) e
  ninguém refazia a cache; o `extensoes_build.sh --todas --aplicar` refaz uma vez no fim (por applet quebraria o
  pino); e o guarda de texto do teste pegava só uma forma de chamada.
- Prova: `tests/cache-do-lancador.sh`; `convergencia.sh` e `segunda-passada-sem-rede.sh` verdes.
- Falta, no passo 10: a segunda passada do `./install.sh` real sem nenhuma chamada a `update-desktop-database`.

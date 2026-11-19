# P263 — a cache do tema fica velha depois do conserto de depois do apt (19/11/2026)

## O que se mediu (nitro-5, 19/11)
- 17h45: `atualizar` (apt full-upgrade de 107 pacotes, topgrade). `cosmic-comp` foi a `…abb6ebc`, `cosmic-files` a
  `…df4ae0f`, `cosmic-applets` a `…779f920` e o portal a `…7b0864c`. O gatilho de depois do apt refez os quatro
  builds sozinho; às 18h10 os quatro estavam `ok`.
- 18h11m20: `scalable/apps/com.system76.CosmicPanelAppButton.svg` e `com.system76.CosmicAppLibrary.svg` do tema
  `MeowSystem-Icons` foram reescritos (os botões da dock, que o `scripts/logo.sh` escreve). O
  `meow-pos-apt.service` rodou de 18h11m00 a 18h12m19. A `icon-theme.cache` seguiu com a hora do install (15h09).
- 18h13, com o `meow-pos-apt.service` já terminado: o `meow doctor` acusa `completar`, `resgatados`, `dracula` e
  `indice`, as quatro com «reindexaria a cache do tema». `meow doctor --consertar` acertou; depois, 82 `ok` e 0
  divergências.
- Durante o `meow-pos-apt.service` o doctor também acusou `flatpakadwaita` e `som`; as duas sumiram sozinhas quando
  ele terminou (eram o conserto no meio do caminho, não defeito).

## A causa (a provar)
Quem escreve os botões da dock no tema (`scripts/logo.sh`, laço de `BOTOES_DOCK`) não reindexa a cache. Falta provar
qual chamada escreveu às 18h11: o conserto de depois do apt ou a troca de fase das 18h (dia para noite) pelo
`meow-gato.service`. Se for a troca de fase, o doctor acusa quatro divergências toda manhã e toda noite.

## A cura na origem
Quem escreve arquivo dentro do tema reindexa a cache no mesmo gesto, pela função que os outros scripts de ícone já
usam; nenhuma etapa deixa o tema com arquivo mais novo que a cache.

## Como se prova
- `tests/logo.sh`: depois de o mascote da dock trocar, `construir_icones.sh indice` em modo seco não tem o que fazer.
- No nitro-5: `meow doctor` limpo depois da troca de fase das 18h e depois de um `apt` que refaz os builds.

## Nos três PCs
Medido no nitro-5. Nos PCs da Vitória o tema não tem `icon-theme.cache` (a conferir por quê, na mesma tarefa).

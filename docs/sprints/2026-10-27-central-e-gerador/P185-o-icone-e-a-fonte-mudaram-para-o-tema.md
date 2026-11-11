# P185 — o ícone e a fonte mudaram de casa no COSMIC (11/11/2026)

## O que se mediu

- No Meow-portatil, o apt de 11/11 às 16:06 subiu o COSMIC inteiro: `cosmic-app-library` 1794242244~90c399d,
  `cosmic-applets` 1794060008~ef6c9e6, `cosmic-panel`, `cosmic-launcher` e `cosmic-settings`.
- Depois disso, a Biblioteca de apps e a dock mostram os ícones coloridos de origem (Chrome, Firefox, GIMP, Spotify) no lugar
  do traço do pack, mesmo com o painel reiniciado às 16:42, depois de o install regravar os desenhos (16:41).
- O `meow doctor` dá tudo verde: `ícones e logo já no lugar` e `índice do 'MeowSystem-Icons' descreve o disco`.
- O `CosmicTk/v1/icon_theme` diz `"MeowSystem-Icons"`. Os 52 desenhos estão em `MeowSystem-Icons/48x48/apps`.
- Uma sonda compilada com o `cosmic-freedesktop-icons` atual (`lookup(n).with_theme("MeowSystem-Icons")`, tamanhos 32 a 96)
  devolve o nosso `48x48/apps/<n>.svg` para google-chrome, firefox, CosmicTerm e CosmicFiles. A busca está certa; o
  nome do tema que chega a ela é que está errado.

## A causa

O commit `4c853eb` da libcosmic (22/10/2026, «refactor: move font and icon from Tk to Theme») tirou o tema de ícones e as
fontes do `com.system76.CosmicTk` e os pôs no tema:

- `libcosmic/src/icon_theme.rs`: `default()` lê `theme::active().cosmic().icon_theme`;
- `cosmic-theme/src/model/theme.rs`: `Theme` e `ThemeBuilder` ganharam `icon_theme` (padrão `"Cosmic"`), `font` e
  `mono_font`, e o `build()` do Builder repassa os três para o Theme.

Em `~/.config/cosmic/com.system76.CosmicTheme.{Dark,Light}{,.Builder}/v2/` não existe `icon_theme`, `font` nem
`mono_font`. Então todo programa compilado com a libcosmic nova cai no `"Cosmic"`, que herda o hicolor (os ícones
coloridos), e na fonte padrão. O MeowSystem grava só no Tk: `construir_icones.sh:658` (`icon_theme`) e
`instalar_fontes.sh:471` (`monospace_font`; a `interface_font` do Tk, hoje "Fira Sans", não é gravada pelo MeowSystem). O doctor confere o Tk, por isso fica verde.

## A cura na origem

1. A etapa que grava o tema de ícones grava também `icon_theme` em `CosmicTheme.Dark`, `CosmicTheme.Light`,
   `CosmicTheme.Dark.Builder` e `CosmicTheme.Light.Builder`, na versão que `meow_cosmic_v` resolve para cada uma. O Tk
   continua gravado, porque os programas da libcosmic antiga (os applets do `src/`, até recompilar) ainda o leem.
2. O `instalar_fontes.sh` grava `mono_font` no tema, no formato RON do `FontConfig`. A `font` copia o que o Tk diz em
   `interface_font`, para a fonte que ela escolheu não voltar à padrão.
3. O doctor confere as cinco casas. Qualquer uma divergente é `~~`, não `ok`.
4. O `aplicar_tema.sh` e o `capturar_tema.sh` não podem apagar essas chaves quando reescrevem o Builder e o Theme.
   O `--respeitar-gui` da P181 entra nessa mesma conta.
5. A `vizinhos.sh` passa a reconhecer `icon_theme` no tema como chave do MeowSystem.

## Sobreviver sempre (ela, 11/11: «isso é um problema real na nossa idempotência. temos que sobreviver sempre»)

A falha de fundo é que o doctor confere o LUGAR onde escrevemos, não o EFEITO que o COSMIC instalado lê. A próxima mudança
de casa no upstream não pode passar calada de novo:

6. O doctor confere o efeito: o `scripts/oraculo_tema.sh`, compilado na revisão da libcosmic do COSMIC instalado, já
   serializa o `Theme` que o COSMIC monta; com a libcosmic nova, esse JSON traz `icon_theme`, `font` e `mono_font`. O doctor
   compara esses campos com o que o pack pede. Divergente é `~~` e o conserto grava. Sem o oráculo (sem rede), vale a cópia
   em Python, que também passa a conhecer esses campos.
7. O contrato `assets/contratos/cosmic.tsv` passa a vigiar também `src/icon_theme.rs` e o `model/theme.rs` da libcosmic
   (de onde vêm o tema de ícones e as fontes). Hash diferente depois de um apt é sinal de que a casa pode ter mudado: o
   `cosmic_pos_apt.sh` refaz as etapas de ícone e fonte e o doctor acusa o que não fechar.
8. As etapas escrevem em todas as casas que a libcosmic já usou e ainda pode usar (Tk e tema), na versão que
   `meow_cosmic_v` resolve. Assim, um COSMIC velho e um novo convivem: um applet do `src/` ainda não recompilado lê o Tk, e o
   painel novo lê o tema.

## Como se prova

- Teste em fixture: HOME temporário com `CosmicTheme.Dark/v2` sem `icon_theme`. Depois da etapa, as quatro casas do tema e
  o Tk dizem `"MeowSystem-Icons"`. Uma segunda passada não escreve nada, e o doctor acusa `~~` quando uma delas falta.
- O mesmo teste para `font` e `mono_font`.
- Teste do efeito: um JSON de oráculo (fixture) com `icon_theme: "Cosmic"` faz o doctor dar `~~`; com `"MeowSystem-Icons"`,
  `ok`. Um contrato com hash trocado em `icon_theme.rs` faz o pós-apt refazer as etapas.
- Com o HOME real, depois do install: `cat ~/.config/cosmic/com.system76.CosmicTheme.Dark/v2/icon_theme` mostra
  `"MeowSystem-Icons"`.
- Ela confere com a mão: a dock e a Biblioteca de apps em traço, e a fonte da Biblioteca igual à do resto.

# Créditos

O MeowSystem é uma casca. O que aparece na tela — a paleta, os glifos, as pastas,
os cursores, as fontes, as imagens — quase tudo foi feito por outra pessoa, sob
uma licença que permite isso. Esta página diz **quem**, **o quê** e **sob que
licença**, com o link para o lugar de onde veio.

A regra do projeto é antiga e não tem exceção: **nenhum acervo de terceiro entra
sem licença registrada.** A auditoria fina de cada família mora ao lado do próprio
acervo — [`assets/icones/PROCEDENCIA.md`](../assets/icones/PROCEDENCIA.md),
[`assets/cursores/CREDITOS.md`](../assets/cursores/CREDITOS.md),
[`assets/sons/CREDITOS.md`](../assets/sons/CREDITOS.md) e os `PROCEDENCIA.md` de
`assets/temas-de-apps/`. Esta página é o índice delas.

---

## A paleta

| projeto | o que dá | licença |
|---|---|---|
| [catppuccin/catppuccin](https://github.com/catppuccin/catppuccin) | as quatro flavors e os 14 accents — **toda** cor deste repositório sai daqui, via `assets/paleta/catppuccin.json` | MIT |

Não existe cor inventada no MeowSystem. Quando um desenho precisa de um tom, ele
pede o nome (`mauve`, `peach`, `sky`) e a paleta responde com o hex daquela
flavor. É o que permite trocar Mocha por Latte sem reescrever um arquivo.

## Os ícones

| projeto | o que dá | licença | onde |
|---|---|---|---|
| [Arcticons](https://github.com/Donnnno/Arcticons) — Donno e colaboradores | **78** glifos de traço (39 de sistema + 39 de aplicativo), recoloridos pela paleta | **CC BY-SA 4.0** | `assets/icones/arcticons/`, `assets/icones/arcticons-apps/` |
| [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) | a base sobre a qual o tema é montado, e a arte de origem dos **33** SVGs convertidos para traço | GPL-3.0 | pacote do sistema, `assets/icones/convertidos-apps/` |
| [catppuccin/papirus-folders](https://github.com/catppuccin/papirus-folders) | as pastas mauve, com o símbolo interno de cada uma — pinado em `f83671d1` | GPL-3.0 | `assets/icones/upstream/papirus-folders/` |
| [catppuccin/vscode-icons](https://github.com/catppuccin/vscode-icons) | glifos de arquivo do editor (recurso desligado — ver a procedência) | MIT | `assets/icones/catppuccin/` |

O **Arcticons é o que define o estilo do tema**, e a obrigação da CC BY-SA 4.0 é
levada a sério aqui porque o repositório é público: atribuição (esta página, e a
tabela da procedência) e *share-alike* — os derivados dele saem sob a mesma
licença.

Os **52 desenhos autorais** de `assets/icones/autorais/` e os **19 retoques à
mão** de `assets/icones/convertidos-apps/retoques/` são deste projeto, no dialeto
do Arcticons mas sem copiar traço nenhum dele. A folha que descreve o dialeto está
em [`docs/folhas/`](folhas/).

## Os papéis de parede

**As imagens não estão neste repositório, e isso é de propósito.** O que vai para
o git é a receita: [`assets/papeis-de-parede/FONTES.tsv`](../assets/papeis-de-parede/FONTES.tsv),
uma linha por imagem, com a URL de origem e a resolução. `scripts/wallpaper.sh
semear` baixa a coleção de novo a partir dela.

As **43** imagens ativas vêm do [wallhaven.cc](https://wallhaven.cc), e **cada uma
pertence ao seu autor** — o wallhaven é um catálogo, não o titular. Se você
reproduzir a coleção, está baixando arte de terceiros para uso pessoal, e o
crédito de cada peça é o link na coluna `url` do TSV.

O `LICENSE` que existe nesse diretório é o do **Catppuccin** (MIT) e cobre o
material Catppuccin que já esteve ali, **não** as imagens do wallhaven.

## Os cursores

| projeto | o que dá | licença |
|---|---|---|
| [catppuccin/cursors](https://github.com/catppuccin/cursors) `v2.0.0` | o tema de cursor inteiro, na flavor e no accent escolhidos | **GPL-2.0** |
| [varlesh/volantes-cursors](https://github.com/varlesh/volantes-cursors) | o desenho original que o Catppuccin recolore | GPL-2.0 |

Autoria, como o `AUTHORS` do pacote declara: **Alexey Varfolomeev** (`varlesh`) e
**Kylie** (`covkie`) nos cursores, **`elkrien`** na recoloração. Também não vão
para o git — o instalador baixa do release oficial. Detalhes e a medição de
luminância de cada flavor: [`assets/cursores/CREDITOS.md`](../assets/cursores/CREDITOS.md).

## As fontes

| fonte | de onde | licença |
|---|---|---|
| **JetBrains Mono Nerd Font** | release [ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts) `v3.5.0` | OFL-1.1 (a fonte) · MIT (o patcher) |
| `zrnic rg.otf` | arquivo que ela mesma trouxe, instalado como qualquer fonte local | da distribuidora original |

## Os temas dentro dos programas

Todos do [Catppuccin](https://github.com/catppuccin), todos **MIT**, todos com o
commit ou o release **pinado** para o acervo não mudar debaixo de ninguém:

| programa | upstream |
|---|---|
| bat, btop | [catppuccin/bat](https://github.com/catppuccin/bat) · [catppuccin/btop](https://github.com/catppuccin/btop) |
| qBittorrent | [catppuccin/qbittorrent](https://github.com/catppuccin/qbittorrent) `v2.0.1` |
| VS Code | [catppuccin/vscode](https://github.com/catppuccin/vscode) |
| Obsidian | [catppuccin/obsidian](https://github.com/catppuccin/obsidian), sobre o [Minimal](https://github.com/kepano/obsidian-minimal) de kepano (MIT) |
| GTK e Qt | [catppuccin/qt5ct](https://github.com/catppuccin/qt5ct) |
| Spotify | [catppuccin/spicetify](https://github.com/catppuccin/spicetify), aplicado pelo [spicetify](https://github.com/spicetify/spicetify-cli) |

## A plataforma

| projeto | o que dá |
|---|---|
| [System76 / Pop!_OS e COSMIC](https://github.com/pop-os/cosmic-epoch) | o desktop que este repositório veste: `cosmic-comp`, `cosmic-panel`, `cosmic-settings`, `cosmic-files` e os applets |
| [starship](https://starship.rs) | o prompt do terminal (ISC) |
| [fastfetch](https://github.com/fastfetch-cli/fastfetch) | o cartão de sistema (MIT) |

## O que é deste projeto

O código (`install.sh`, `bin/meow`, `lib/`, `scripts/`, `app/`), os **52** desenhos
autorais, os **19** retoques à mão, o som de volume — sintetizado, não baixado, e
liberado em **CC0-1.0** — e a documentação em `docs/`. Tudo sob **GPL-3.0**, como
o repositório.

Os dois gatos do painel são a **Coquinha** e o **Mimir**, que existem de verdade e
foram desenhados a partir de fotos deles ([`assets/gatos/`](../assets/gatos/)).

## O que foi recusado, e por quê

Registrado para a próxima pessoa não refazer a pesquisa:

| candidato | por que ficou de fora |
|---|---|
| `Daveedmee/catppuccin-icons` | licença **não declarada**. Excluído pelo nome no `.gitignore`, com o motivo escrito ao lado da regra |
| `cosmic-icons` (System76, CC BY-SA 4.0) | a silhueta é a mesma do `papirus-folders` em mauve; adotá-lo custaria um segundo dono de `scalable/places` para entregar o mesmo desenho |
| sons do tema `freedesktop` | CC-BY-SA **3.0**, incompatível com a GPL-3.0 (só a 4.0 ganhou compatibilidade, em 2015) |
| som do tema `Pop` | licença serviria; o som não — 0,35 s contra um debounce de 125 ms no `cosmic-osd` |

---

## Obrigações, em uma tabela

Se você redistribuir este repositório ou algo derivado dele:

| você mexeu em | precisa |
|---|---|
| qualquer coisa derivada do **Arcticons** | creditar o Arcticons **e** liberar sob CC BY-SA 4.0 |
| os SVGs convertidos do **Papirus**, as pastas, os cursores | manter sob GPL (2.0 nos cursores, 3.0 no resto) |
| o material **Catppuccin** | manter o aviso de copyright MIT |
| os **papéis de parede** | nada a fazer aqui: eles não estão no repositório |
| o **código e os desenhos deste projeto** | GPL-3.0 |

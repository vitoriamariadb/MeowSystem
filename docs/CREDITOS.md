# Créditos

O MeowSystem é de **Vitória Maria** ([vitoriamariadb](https://github.com/vitoriamariadb)) e
**André Farias** ([AndreBFarias](https://github.com/AndreBFarias)). O que aparece na tela — a
paleta, os glifos, as pastas, os cursores, as fontes, as imagens — quase tudo foi feito por outra
pessoa, sob uma licença que permite isso. Esta página diz **quem**, **o quê** e **sob que
licença**, com o link para o lugar de onde veio.

**Nenhum acervo de terceiro entra sem licença registrada.** A auditoria fina de cada família mora ao lado do próprio
acervo — [`packs/meowsystem/PROCEDENCIA.md`](../packs/meowsystem/PROCEDENCIA.md),
[`packs/meowsystem/licencas/cursores.md`](../packs/meowsystem/licencas/cursores.md),
[`docs/SONS.md`](../docs/SONS.md), os `PROCEDENCIA.md` de `scripts/temas-de-apps/` e o
[`CREDITOS.md`](../packs/dracula/CREDITOS.md) do pack Dracula. Esta página é o índice delas.

---

## A paleta

| projeto | o que dá | licença |
|---|---|---|
| [catppuccin/catppuccin](https://github.com/catppuccin/catppuccin) | as quatro flavors e os 14 accents do pack padrão — **toda** cor que este repositório desenha sai de uma paleta, e a de fábrica é `packs/meowsystem/paleta.json` | MIT |

Não existe cor inventada no MeowSystem. Quando um desenho precisa de um tom, ele
pede o nome (`mauve`, `peach`, `sky`) e a paleta responde com o hex daquela
flavor. É o que permite trocar Mocha por Latte sem reescrever um arquivo.

## Os ícones

| projeto | o que dá | licença | onde |
|---|---|---|---|
| [Arcticons](https://github.com/Donnnno/Arcticons) — Donno e colaboradores | **78** glifos de traço (39 de sistema + 39 de aplicativo), recoloridos pela paleta | **CC BY-SA 4.0** | `packs/meowsystem/icones/` (`apps/`, `sistema/` e `biblioteca/`; a lista em `arcticons.lista`) |
| [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) | a base sobre a qual o tema é montado, e a arte de origem dos **33** SVGs convertidos para traço | GPL-3.0 | pacote do sistema, `packs/meowsystem/icones/apps/` (o mapa em `apps-convertidos.map`) |
| [catppuccin/papirus-folders](https://github.com/catppuccin/papirus-folders) | as pastas na cor do acento, com o símbolo interno de cada uma — pinado em `f83671d1` | GPL-3.0 | `~/.cache/meowsystem/upstream/papirus-folders/`, baixado pelo install |
| [catppuccin/vscode-icons](https://github.com/catppuccin/vscode-icons) | glifos de arquivo do editor (recurso desligado — ver a procedência) | MIT | `packs/meowsystem/icones/sistema/` |

O **Arcticons é o que define o estilo do tema**, e a obrigação da CC BY-SA 4.0 é
levada a sério aqui porque o repositório é público: atribuição (esta página, e a
tabela da procedência) e *share-alike* — os derivados dele saem sob a mesma
licença.

Os **52 desenhos autorais** de `packs/meowsystem/icones/apps/` e os **19 retoques à
mão** (ali e em `biblioteca/`) são deste projeto, no dialeto
do Arcticons mas sem copiar traço nenhum dele.

## Os papéis de parede

**As imagens não estão neste repositório, e isso é de propósito.** O que vai para
o git é a receita: [`packs/meowsystem/wallpapers/FONTES.tsv`](../packs/meowsystem/wallpapers/FONTES.tsv),
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
luminância de cada flavor: [`packs/meowsystem/licencas/cursores.md`](../packs/meowsystem/licencas/cursores.md).

## As fontes

| fonte | de onde | licença |
|---|---|---|
| **JetBrains Mono Nerd Font** | release [ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts) `v3.5.0` | OFL-1.1 (a fonte) · MIT (o patcher) |
| `zrnic rg.otf` | arquivo que quem usa trouxe, instalado como qualquer fonte local | da distribuidora original |

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
| Heroic Games Launcher | [catppuccin/heroic](https://github.com/catppuccin/heroic) — **56** CSS, 4 flavors × 14 accents |

## A plataforma

| projeto | o que dá |
|---|---|
| [System76 / Pop!_OS e COSMIC](https://github.com/pop-os/cosmic-epoch) | o desktop que este repositório veste: `cosmic-comp`, `cosmic-panel`, `cosmic-settings`, `cosmic-files` e os applets |
| [starship](https://starship.rs) | o prompt do terminal (ISC) |
| [fastfetch](https://github.com/fastfetch-cli/fastfetch) | o cartão de sistema (MIT) |

## Os applets

Os cinco applets da casa moram em repositórios próprios, fixados em `assets/extensoes/`, e a
página Extensões do painel os baixa e compila. Três vêm de um projeto de outra pessoa:

| applet | upstream |
|---|---|
| Tocando agora | [cosmic-utils/cosmic-ext-applet-now-playing](https://github.com/cosmic-utils/cosmic-ext-applet-now-playing) |
| Bandeja | [marcelogomes90/cosmic-ext-applet-status-hub](https://github.com/marcelogomes90/cosmic-ext-applet-status-hub) |
| Ajustes rápidos | [DrakRosmann/cosmic-ext-applet-quick-settings](https://github.com/DrakRosmann/cosmic-ext-applet-quick-settings) |

O Modo de leitura e o Modo performance são de **Vitória Maria** e **André Farias**.

## O que é deste projeto

O código (`install.sh`, `bin/meow`, `lib/`, `scripts/`, `app/`), os **52** desenhos
autorais, os **19** retoques à mão, o som de volume — sintetizado, não baixado, e
liberado em **CC0-1.0** — e a documentação em `docs/`. Tudo sob **GPL-3.0**, como
o repositório.

Os dois mascotes do painel são a **Coquinha** e o **Mimir**, que existem de verdade e
foram desenhados a partir de fotos deles ([`packs/meowsystem/mascote/`](../packs/meowsystem/mascote/)).

## O que foi recusado, e por quê

| candidato | por que ficou de fora |
|---|---|
| `Daveedmee/catppuccin-icons` | licença **não declarada**. Excluído pelo nome no `.gitignore`, com o motivo escrito ao lado da regra |
| `cosmic-icons` (System76, CC BY-SA 4.0) | a silhueta é a mesma do `papirus-folders` em mauve; adotá-lo custaria um segundo dono de `scalable/places` para entregar o mesmo desenho |
| sons do tema `freedesktop` | CC-BY-SA **3.0**, incompatível com a GPL-3.0 (só a 4.0 é compatível) |
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

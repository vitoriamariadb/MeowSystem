# Procedência do tema qBittorrent

> Este arquivo morava em `scripts/temas-de-apps/qbittorrent/` até 22/09/2026
> (sprint P18) e veio para cá junto com o `.qbtheme` que ele descreve. A regra é
> a da casa: a procedência viaja com a arte, e a arte agora é do pack — quem
> publica um pack com tema de aplicativo publica a procedência dele ao lado.
> O módulo que instala o arquivo continua sendo
> `scripts/temas-de-apps/qbittorrent/manifesto.sh`; o que mudou é que ele
> pergunta ao pack qual tema aplicar, em vez de saber.

## Arquivo

`catppuccin-mocha.qbtheme` — Qt Binary Resource (magic `qres`), 5980 bytes.

| campo | valor |
|---|---|
| origem | <https://github.com/catppuccin/qbittorrent> |
| release | `v2.0.1` (publicada em 2024-10-05) |
| **commit pinado** | `e24f1dd1ce507fbf0ef327c27c47fc4442b7391b` |
| tag object | `f95403f5e87c86ce02605531c78e7e3567c7523d` (tag anotada `v2.0.1`) |
| URL do asset | `https://github.com/catppuccin/qbittorrent/releases/download/v2.0.1/catppuccin-mocha.qbtheme` |
| sha256 | `f6ddf59ed881ea4a423e8d48a73f6f507c594a560f398097891fcb70bc8255e1` |
| licença | MIT (Catppuccin) |
| baixado em | 2026-08-04 |

O repositório foi conferido por WebFetch antes do download; a existência da release
e o nome exato dos assets vieram da API do GitHub, não de memória. Os quatro flavors
estão publicados (`latte`, `frappe`, `macchiato`, `mocha`); baixamos só o **mocha**,
que é o flavor da casa.

Para reconferir a integridade:

```sh
sha256sum -c <<< 'f6ddf59ed881ea4a423e8d48a73f6f507c594a560f398097891fcb70bc8255e1  catppuccin-mocha.qbtheme'
head -c 4 catppuccin-mocha.qbtheme   # tem de imprimir: qres
```

## O que tem dentro (medido, não suposto)

O `.qbtheme` é um `.rcc` do Qt: os recursos vêm **comprimidos com zlib**, então
`strings` no arquivo NÃO mostra as cores da paleta — mostra só os SVGs dos ícones,
que ficam sem compressão. Descomprimindo os dois blobs (offsets 32 e 570) saem o
`config.json` e o `stylesheet.qss`.

### Armadilha: o acento upstream é AZUL, não o mauve da casa

O `config.json` do upstream traz:

```json
"Palette.Highlight":     "#89b4fa",   /* blue  — seleção, o acento visível */
"Palette.Link":          "#89b4fa",   /* blue  */
"Palette.LinkVisited":   "#b4befe",   /* lavender */
"Palette.BrightText":    "#cba6f7",   /* mauve — só aqui */
"RSS.UnreadArticle":     "#89b4fa",   /* blue  */
"Log.Info":              "#89b4fa"    /* blue  */
```

Ou seja: é Catppuccin Mocha legítimo, mas acentuado em **blue**. O MeowSystem-Theme
é Mocha **+ accent mauve `#CBA6F7`**. Quem instalar este arquivo como está ganha um
qBittorrent Mocha de seleção azul — coerente com a paleta, divergente do acento.

O `stylesheet.qss` reforça o mesmo azul em **10 lugares**, não só na aba selecionada.

#### Inventário completo do `#89b4fa` (contado, não estimado)

Uma versão anterior desta página listava 4 chaves e 1 regra. Está errado — seguir
aquela lista deixaria o tema **metade azul**: a barra de progresso, os sliders, o
radio button, as bordas de foco e os dois estados de envio continuariam azuis.
O que existe de fato:

`config.json` — 6 chaves:

| chave | |
|---|---|
| `Palette.Highlight` | a seleção, o acento mais visível |
| `Palette.Link` | |
| `RSS.UnreadArticle` | |
| `Log.Info` | |
| `TransferList.Uploading` | |
| `TransferList.ForcedUploading` | |

`stylesheet.qss` — 10 ocorrências, em 8 regras:

| regra | |
|---|---|
| `QTabBar::tab:selected` | `border-bottom` |
| `QLineEdit:hover, QTextEdit:hover, QPlainTextEdit:hover` | `border` |
| `QLineEdit:focus, QTextEdit:focus, QPlainTextEdit:focus` | `border` |
| `QProgressBar::chunk` | gradiente `#89b4fa` -> `#b4befe` |
| `QAbstractSpinBox:focus` | `border` |
| `QSlider::handle:horizontal` / `::sub-page:horizontal` | `background-color` |
| `QSlider::handle:vertical` / `::add-page:vertical` | `background-color` |
| `QRadioButton::indicator::checked` | `background-color` |

Para reconferir a qualquer momento (é assim que a lista acima foi levantada):

```sh
python3 -c '
import zlib, re
d = open("catppuccin-mocha.qbtheme","rb").read()
for off in (32, 570):
    t = zlib.decompressobj().decompress(d[off:]).decode("utf-8","replace")
    print(off, t.lower().count("#89b4fa"), "ocorrencias")
'
```

**Não corrigimos isso aqui de propósito.** Mexer nas cores exigiria reempacotar o
`.rcc` (ferramenta `rcc` do Qt), e o resultado seria impossível de testar enquanto o
tema estiver travado do lado do Andromeda (ver `manifesto.sh`). Fica registrado para
a decisão ser dela, quando destravar. Há dois caminhos, ambos já mapeados:

1. **Reempacotar o `.rcc`** trocando `#89b4fa` -> `#cba6f7` nas 6 chaves e nas 10
   ocorrências da tabela acima — todas elas, senão o resultado fica bicolor.
   Atenção ao gradiente do `QProgressBar::chunk`, que combina o azul com o
   lavender `#b4befe`: trocar só a primeira parada deixa a barra roxo-para-azul.
2. **Servir como diretório**, sem ferramenta nenhuma: o qBittorrent aceita tanto um
   `.qbtheme` quanto um diretório com `config.json` + `stylesheet.qss` (é assim que o
   tema `andromeda` do Aurora já funciona — ele aponta para
   `assets/temas/andromeda/config.json`). Descomprimir, editar o JSON e apontar para o
   diretório é o caminho sem build.

## Os modelos do motor

Os apps abaixo não trazem arquivo neste pack: o bloco `apps.<app>` vazio do
`pack.json` pede o modelo do motor (`scripts/temas-de-apps/<app>/<app>.modelo.*`),
e o `scripts/temas-de-apps/modelo.py` põe nele a paleta deste pack, no flavor da
máquina. O modelo não traz cor escrita (o `tests/temas-de-apps.sh` cobra). De onde
veio o desenho de cada um, e sob que licença, está na seção «Os temas de
aplicativo» do `packs/dracula/PROCEDENCIA.md`.

| app | modelo | desenho de origem | licença |
|---|---|---|---|
| kitty | `scripts/temas-de-apps/kitty/kitty.modelo.conf` | `dracula/kitty` | MIT |
| gnome-terminal | `scripts/temas-de-apps/gnome-terminal/gnome-terminal.modelo.dconf` | desenho deste projeto | GPL-3.0 |
| telegram | `scripts/temas-de-apps/telegram/telegram.modelo.tdesktop-theme` | `dracula/telegram` v0.1.3 | MIT |
| discord | `scripts/temas-de-apps/discord/discord.modelo.theme.css` | o Dracula do CtorW para Vesktop e Vencord, sobre o `midnight` do refact0r | MIT |
| onlyoffice | `scripts/temas-de-apps/onlyoffice/onlyoffice.modelo.json` | os nomes das chaves de um tema de interface do OnlyOffice (todo valor é papel) | ver a nota do `packs/dracula/PROCEDENCIA.md` |

## O tema do Spotify (spicetify)

A pasta `spotify/catppuccin/` é a pasta `catppuccin/` do repositório do tema, copiada sem mudança
(sem os `src/` e o `app.scss`, que só servem para recompilar). O módulo
`scripts/temas-de-apps/spotify/manifesto.sh` a copia para `~/.config/spicetify/Themes/` quando o
tema não está lá; nada desce da internet.

| campo | valor |
|---|---|
| origem | <https://github.com/catppuccin/spicetify> |
| commit pinado | `1ec645c4cf7f42f9792b9eeb1bb7930f94593277` |
| tarball | `https://github.com/catppuccin/spicetify/archive/1ec645c4cf7f42f9792b9eeb1bb7930f94593277.tar.gz` |
| sha256 do tarball | `b97c087e4631f9a605bfa9f7326ea24eb63dee32d7c2cbf3beed706c2f774948` |
| licença | MIT (Catppuccin), `spotify/catppuccin/LICENSE` |
| baixado em | 2026-10-26 |
| sha256 do `color.ini` guardado | `9145743f76f81d95125df3aa65b16ab8e3f50d16c09608010b302b1834dbfeb9` |

O sha256 de cada um dos 64 arquivos está em `spotify/SHA256SUMS` (`cd spotify && sha256sum -c SHA256SUMS`).
O repositório não tem tag nem release, por isso o pino é o commit.

Três arquivos de texto foram guardados com o ajuste que o gancho de commit faz em todo texto, e só
com ele (o desenho e o efeito são os mesmos):

| arquivo | o que mudou | sha256 do upstream |
|---|---|---|
| `color.ini` | tirado o espaço no fim da linha `surface1` | `f5c2b6a46e9b463020f8b36a21517ce6ade9e89230850f24944076e586576e07` |
| `LICENSE` | acrescentada a quebra de linha final | `9df242fd9ee91e5ef30acce92d6cadfe5472abcf3404c4abdc3ab8026b53965f` |
| `theme.js` | cinco linhas só de comentário `//` a menos | `cac51cc1236b37b0d100ae41c9279aa6fbf2b00aa332067854d72ef37bea151c` |

Os outros 61 arquivos (imagens, `user.css`) são byte a byte os do commit.

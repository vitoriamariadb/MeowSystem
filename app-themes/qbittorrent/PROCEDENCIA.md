# Procedência do tema qBittorrent

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
   `themes/andromeda/config.json`). Descomprimir, editar o JSON e apontar para o
   diretório é o caminho sem build.

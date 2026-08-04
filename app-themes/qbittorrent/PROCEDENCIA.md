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

O `stylesheet.qss` reforça o mesmo azul na aba selecionada
(`QTabBar::tab:selected { border-bottom: 1px solid #89b4fa; }`).

**Não corrigimos isso aqui de propósito.** Mexer nas cores exigiria reempacotar o
`.rcc` (ferramenta `rcc` do Qt), e o resultado seria impossível de testar enquanto o
tema estiver travado do lado do Andromeda (ver `manifesto.sh`). Fica registrado para
a decisão ser dela, quando destravar. Há dois caminhos, ambos já mapeados:

1. **Reempacotar o `.rcc`** trocando `#89b4fa` -> `#cba6f7` em `Palette.Highlight`,
   `Palette.Link`, `RSS.UnreadArticle`, `Log.Info` e na regra `QTabBar::tab:selected`.
2. **Servir como diretório**, sem ferramenta nenhuma: o qBittorrent aceita tanto um
   `.qbtheme` quanto um diretório com `config.json` + `stylesheet.qss` (é assim que o
   tema `andromeda` do Aurora já funciona — ele aponta para
   `themes/andromeda/config.json`). Descomprimir, editar o JSON e apontar para o
   diretório é o caminho sem build.

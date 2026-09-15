# Papéis de parede — origem e licença de cada acervo

Regra do projeto: **nenhuma imagem entra sem a origem registrada aqui.** As
imagens não vão para o git (regra de `*.png`/`*.jpg`); o que vai é a receita —
qual repositório, qual commit, e sob que termos.

Desde 15/09/2026 o acervo **acompanha o `FLAVOR`**: cada variante tem a sua
semente, escolhida em `scripts/wallpaper.sh` (`_semente_do_flavor`). O commit é
pinado por semente, nunca `main`.

## `mocha`, `macchiato`, `frappe`, `latte` — Catppuccin

| | |
|---|---|
| Repositório | [`zhichaoh/catppuccin-wallpapers`](https://github.com/zhichaoh/catppuccin-wallpapers) |
| Commit pinado | `1023077979591cdeca76aae94e0359da1707a60e` |
| Licença | MIT — o texto completo está em `LICENSE`, ao lado deste arquivo |
| Prefixo no acervo | `cat-` |
| Curadoria | `FONTES.tsv`, 44 imagens em 4 categorias |

## `dracula` — helpotters/dracula-wallpapers

| | |
|---|---|
| Repositório | [`helpotters/dracula-wallpapers`](https://github.com/helpotters/dracula-wallpapers) |
| Commit pinado | `bd6282d192b6cf8ac4241a69abaa657a0da43e75` |
| Licença | **não declarada** — ver o aviso abaixo |
| Prefixo no acervo | `drac-` |
| O que entra | 28 imagens, depois de ignorar `colors/` e `source-images/` |

### O aviso, porque a regra acima pede

**O repositório não publica um arquivo de licença.** A API do GitHub devolve
`licenseInfo: null`, e não há `LICENSE` na árvore. O que existe é a seção de
créditos do `readme.org`, que declara, por ilustração:

- material de origem: **Freepik** (conta gratuita)
- edições de cor: **@helpotters**
- paleta: **Dracula Team**

A Freepik Free License permite uso, inclusive comercial, **mas exige
atribuição** — e não é uma licença que autorize sublicenciar. Na prática, para
esta máquina:

- usar como papel de parede pessoal está coberto;
- **redistribuir as imagens** (por exemplo, colocá-las num release do MeowSystem)
  **não está**, e é mais um motivo para elas seguirem fora do git;
- a atribuição fica registrada aqui e é este arquivo que a cumpre.

Se o acervo Dracula um dia for publicado junto com o tema, o certo é trocar esta
semente por imagens de origem própria ou de licença explícita — que é
exatamente o caminho dos SVG autorais em andamento.

### O que elas não são

O pedido original era **SVG em 4K**. Estas imagens são **PNG em 3440×1440**
(ultrawide), segundo o próprio `readme.org` do repositório. Servem como acervo
provisório; não são vetor e não são 4K.

## `tulip-orchid` — o gerador da casa (autoral)

| | |
|---|---|
| Repositório | `[REDACTED]/tulip-orchid` (privado) |
| O que é | gerador de papéis de parede; 13 desenhos em 4 categorias (catedral, cemitério, ornamento, noite) |
| Exporta | SVG 4K (3840×2160), SVG ultrawide, SVG mobile e **PNG 4K** |
| Licença | autoral — do dono do MeowSystem |

**Ainda não é semente de repositório, e não é por escolha.** Três coisas
impedem, todas medidas em 15/09/2026:

1. o repositório é **privado**, e o `semear` baixa por URL crua, sem autenticação;
2. as imagens **não existem como arquivo** lá dentro — `src/lib/wallpapers/render.ts`
   as desenha em tempo de execução a partir de `scenes.ts`;
3. o formato padrão é **SVG**, e o `cosmic-bg` não lê SVG. Conferido no binário:
   avif, gif, jpeg, jpg, png, tiff, webp.

O caminho que funciona hoje é **pasta-semente**: exportar **PNG 4K** pelo menu de
download do gerador para uma pasta, e apontar a semente para ela.

```sh
WALLPAPER_SEMENTE_REPO="$HOME/Imagens/tulip-orchid" \
WALLPAPER_SEMENTE_PREFIXO="tulip" \
  meow wallpaper semear
```

Sendo autoral, é a única das três origens cujas imagens **podem** ser publicadas
junto com o tema. Quando houver PNG renderizado num repositório público ou num
release, ela vira a semente definitiva do `dracula` e a do helpotters sai.

## Como trocar a semente sem editar código

```sh
WALLPAPER_SEMENTE_REPO="usuario/repo" \
WALLPAPER_SEMENTE_COMMIT="<sha completo>" \
WALLPAPER_SEMENTE_IGNORAR="pasta-a pasta-b" \
WALLPAPER_SEMENTE_PREFIXO="abrev" \
  meow wallpaper semear
```

O repositório pode ser `dono/repo` (baixa do GitHub, exige o commit) ou um
caminho começando com `/`, `~` ou `./` (copia da pasta, sem rede e sem pino).

Passar o repositório sem o commit é erro honesto: sem pino não há receita.

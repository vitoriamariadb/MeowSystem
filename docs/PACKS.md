# Theme packs

Um **theme pack** é um diretório que diz ao MeowSystem que cores usar — e, se
quiser, que ícones, que papéis de parede e que ponteiro. O MeowSystem lê o pack e
escreve no seu desktop; **ele nunca escreve dentro do pack.**

O pack mais simples que se publica tem três arquivos e nenhuma linha de código.

```
packs/meu-tema/
  pack.json      quem é o pack e o que ele fornece
  paleta.json    as 26 cores
  logo.svg       a cara do pack, e a capa do cartão onde ele é escolhido — ver "O logo do pack"
```

Com os dois primeiros o tema já **funciona**; o `logo.svg` é o que faz o pack
**passar** no `meow pack validar`. Com isso você já ganha tema do COSMIC,
esquema do terminal, cores do painel, dos ícones autorais e dos temas de
aplicativo. Tudo o que você não declarar é
herdado do **pack padrão** — o `catppuccin`, que acompanha o projeto e **pode
ser trocado** —, e o `meow pack info` diz exatamente o que veio de onde.

**"Padrão" e não "embutido".** O Catppuccin mora no pack `meowsystem`
(`packs/meowsystem/`; `catppuccin` vale como apelido), com `pack.json`, e passa pelas
mesmas regras que o seu pack vai passar: o formato descreve **todos** os temas, inclusive o
de casa.

---

## Sumário

- [Começar por um CSV](#começar-por-um-csv)
- [As 26 cores](#as-26-cores)
- [A fronteira: `assets/` contra `packs/`](#a-fronteira-assets-contra-packs)
- [A estrutura do pack](#a-estrutura-do-pack)
- [`pack.json`, campo a campo](#packjson-campo-a-campo)
- [A vitrine](#a-vitrine)
- [De onde sai um acervo: pack, herança, motor](#de-onde-sai-um-acervo-pack-herança-motor)
- [O acervo de ícones do pack](#o-acervo-de-ícones-do-pack)
- [Fonte e derivados](#fonte-e-derivados)
- [Temas de aplicativo](#temas-de-aplicativo)
- [Trocar de pack: `meow pack usar`](#trocar-de-pack-meow-pack-usar)
- [Quem vence: o pack ou o `meow.conf`](#quem-vence-o-pack-ou-o-meowconf)
- [O tema do COSMIC, e o único passo manual que existe](#o-tema-do-cosmic-e-o-único-passo-manual-que-existe)
- [O som](#o-som)
- [A base de ícones](#a-base-de-ícones)
- [O ponteiro](#o-ponteiro)
- [As fontes](#as-fontes)
- [O que ainda não é do pack](#o-que-ainda-não-é-do-pack)
- [As categorias, uma por linha](#as-categorias-uma-por-linha)
- [O logo do pack](#o-logo-do-pack)
- [O que um pack não pode fazer](#o-que-um-pack-não-pode-fazer)
- [Validar antes de publicar](#validar-antes-de-publicar)
- [Publicar](#publicar)

---

## Começar por um CSV

Se as suas cores estão numa coluna do Figma ou numa planilha, você não precisa
escrever o JSON da próxima seção: 26 linhas bastam.

```csv
slot,flavor,hex
base,meutema,#282A36
text,meutema,#F8F8F2
mauve,meutema,#BD93F9
…
```

- **As colunas são fixas**, separadas por vírgula, e a primeira linha é esse
  cabeçalho. Uma linha por cor; os 26 nomes de `slot` são os da seção abaixo,
  em minúsculas. Um CSV exportado com BOM (o Excel faz isso)
  é lido igual. O Excel em português salva com `;`: o erro avisa, e é trocar
  os `;` por `,`.
- **O `flavor` é uma palavra só, em minúsculas, de letras `a-z` e dígitos** —
  como `mocha` e `alucard`. O nome vira arquivo de tema (`<flavor>-<accent>`) e
  vai para o `FLAVOR=` do `meow.conf`, e nenhum dos dois aguenta espaço, barra
  ou `$(…)`.
- **O erro diz a linha.** Slot desconhecido sai com o número da linha e o nome;
  slot faltando sai com a lista do que falta, por flavor; hex fora de
  `#RRGGBB` e slot repetido também. Tudo de uma vez, não um por rodada.
- **O CSV é entrada; o `paleta.json` continua sendo a forma canônica.** Nenhum
  leitor do projeto entende CSV: ele é traduzido uma vez para o JSON
  equivalente, com o hex em maiúsculas como nas paletas daqui, e dali em diante
  quem manda é o JSON.

**O pack inteiro sai de uma vez:**

```bash
meow pack novo meu-tema --de-csv minhas-cores.csv
meow pack validar meu-tema                  # sai 0
meow pack info meu-tema | grep claro        # o claro derivado diz que é derivado
```

O `novo` confere o CSV, deriva o claro se faltar, roda a régua de contraste,
escreve o `paleta.json` equivalente e monta o resto: o `pack.json` (ver o fim
desta seção), o `logo.svg` gerado, o `CREDITOS.md` e os ícones autorais nas
cores do CSV. O `id` é o da linha de comando e o `flavor` é o do CSV, e os dois
não se confundem: `meu-tema` é um id válido e seria um flavor recusado — flavor
não tem hífen. Ele escreve onde todo `novo` escreve (ver [`meow pack
novo`](#meow-pack-novo-o-pack-que-começa-pelo-que-está-no-ar)), e nada do que
está no ar entra: nem o timbre, nem o accent do seu `meow.conf`.

**Pela tela, é o «Abrir um tema»** da porta Tema, que aceita o `.csv` solto além do
`.meowpack`. A caixa de confirmar desenha a paleta, marca o claro derivado como
derivado e lista o que ficou abaixo da régua — sem bloquear. É o mesmo pack do
`novo --de-csv`, montado pela mesma função, com duas diferenças que são as de
todo pack importado: ele vai para `~/.local/share/meowsystem/packs/`, e **o id
sai do nome do arquivo**, porque o CSV não tem onde dizê-lo — `Minhas
Cores.csv` vira o pack `minhas-cores`. No terminal, o mesmo é `meow pack
importar minhas-cores.csv`. Importar não escreve por cima de um pack que já
existe: o mesmo nome de arquivo, de novo, é recusado.

**Só a paleta**, sem montar pack, é o `de-csv`:

```bash
meow pack de-csv minhas-cores.csv > ~/.local/share/meowsystem/packs/meu-tema/paleta.json
```

O verbo **só imprime**, como o `logo-gerado`: quem põe o arquivo no pack é você,
com o `>`. Aponte o `>` para um arquivo novo — um CSV recusado não imprime JSON
nenhum, e o `>` já terá esvaziado o destino.

**Se o CSV traz só flavors escuros, o claro é derivado** — do primeiro flavor
do CSV, que é o que vira o `flavor_padrao` —, pelo método da subseção [Se o seu
tema não tem um claro](#se-o-seu-tema-não-tem-um-claro), e não por outro. Ele se
chama `<flavor>claro` (uma palavra só: nome de flavor não tem hífen) e **diz que
foi derivado**: a paleta ganha o campo

```json fragmento
"derivados": { "meutemaclaro": "meutema" }
```

e o `meow pack info` e o cartão do pack no painel mostram isso na cara:

```
  claros    : meutemaclaro — claro: derivado do escuro pelo método do Latte (não é próprio), a partir de 'meutema'
```

É o mesmo algoritmo que fez o `alucard`, e isso é conferido: dadas as 26 cores
do `dracula`, ele devolve o `alucard` versionado, 26 de 26 iguais. Derivar
continua sendo opinativo — para usar o seu claro, traga as 26 linhas dele no
CSV. Um flavor é claro quando o `base` dele é mais luminoso que o `text`: a
medida decide, e não o nome.

**Onde o método erra, e se sabe: tema em cinza puro.** A regra 3 empresta o
matiz do `base`, e cinza não tem matiz — a conta devolve 0, que é vermelho, e a
saturação do Latte o acende: um escuro todo cinza deriva `text` `#664A4A` sobre
`base` `#F6F0F0`, um claro rosado que o tema não tem. Nesse caso, traga o claro
no CSV.

**A régua de contraste roda na tradução, e avisa sem bloquear.** `text` sobre
`base` ≥ 7:1, e cada slot não abaixo de 95% do que o Latte faz no mesmo slot —
a régua que gerou o `alucard`. (Ao pé da letra, "não pior que o Latte" reprova
o próprio `alucard` em 21 slots por um centésimo: a derivação mira a luminância
do Latte, e o arredondamento para hexa cai logo abaixo.) Ela vale para todo
flavor, escuro ou claro, e as cores oficiais do Dracula reprovam em três
(`red`, `blue`, `surface0`). A régua é do projeto; a decisão é de quem fez o
tema. O que bloqueia continua sendo o `validar`: `text` sobre `base` abaixo de
4,5:1.

**Um pack feito de CSV tem paleta e nada mais**, e isso é legítimo — é o que o
Dracula faz com sete categorias. O resto vem por herança, e só vem se o
`pack.json` disser de quem. É este o que o `novo --de-csv` escreve (sem a
`_nota` e a `descricao_curta`):

```json
{
  "formato": 1, "id": "meu-tema", "nome": "Meu Tema",
  "creditos": "CREDITOS.md",
  "heranca": "meowsystem",
  "vitrine": { "capa": "logo.svg" },
  "paleta":  { "arquivo": "paleta.json", "flavor_padrao": "meutema" },
  "cosmic":  { "nome_da_paleta": "meu-tema-<flavor>" },
  "icones":  { "autorais": { "gerar": true, "desenhos": "icones/apps/" } }
}
```

Sem `heranca`, ícones, ponteiro e papéis de parede não sobem para pack nenhum.
Com ela, o `meow pack info` e o cartão dizem categoria a categoria o que veio de
onde — `próprio: paleta, ícones autorais · herdado de catppuccin: …` no `info`,
e o mesmo com o nome do pack no cartão, «herdado do Catppuccin» —, para
ninguém achar que ganhou menos do que ganhou. A herança é o **pack padrão**, e
não o que está no ar: o mesmo CSV tem de dar o mesmo pack em qualquer máquina,
e o padrão é o único pack que toda instalação tem. O `logo.svg` sai do
[`logo-gerado`](#pack-sem-logo-não-fica-sem-cara).

**Os ícones autorais são a exceção, e ela foi medida.** Herdados, eles vêm nos
flavors do pai: os 44 do Catppuccin são `mocha`, `macchiato`, `frappe` e
`latte`, e nenhum veste `meutema`. Montado à mão só com a `heranca`, o pack de
CSV mostrava `icones.autorais  HERDADO de catppuccin  44 desenho(s)` e zero
flavors dele. Então o `novo` declara `icones.autorais.gerar` e já entrega os
desenhos construídos pelo [`meow pack construir`](#os-autorais-e-o-flavor-que-caía-no-pack-do-vizinho) — 11
desenhos em cada flavor, o claro derivado incluído —, sem rede e escrevendo só
dentro do pack. O `info` diz `PRÓPRIO  22 desenho(s), 2 flavor(s)`. Se mudar a
paleta depois, rode `meow pack construir meu-tema` de novo.

---

## As 26 cores

A paleta é um JSON com os mesmos campos de `packs/meowsystem/paleta.json`:

```json
{
  "ordem_canonica": ["rosewater", "flamingo", "pink", "mauve", "red", "maroon",
                     "peach", "yellow", "green", "teal", "sky", "sapphire",
                     "blue", "lavender", "text", "subtext1", "subtext0",
                     "overlay2", "overlay1", "overlay0", "surface2", "surface1",
                     "surface0", "base", "mantle", "crust"],
  "claros": [],
  "nomes":  { "meutema": "Meu Tema" },
  "flavors": {
    "meutema": {
      "rosewater": "#F8F0EC", "flamingo": "#FFB8D1", "pink": "#FF79C6",
      "mauve": "#BD93F9", "red": "#FF5555", "maroon": "#FF6E6E",
      "peach": "#FFB86C", "yellow": "#F1FA8C", "green": "#50FA7B",
      "teal": "#7FE9DE", "sky": "#8BE9FD", "sapphire": "#62D6E8",
      "blue": "#6272A4", "lavender": "#D6ACFF", "text": "#F8F8F2",
      "subtext1": "#E0E0DA", "subtext0": "#C8C8C2", "overlay2": "#A4A6B8",
      "overlay1": "#8B8DA0", "overlay0": "#6272A4", "surface2": "#565A72",
      "surface1": "#44475A", "surface0": "#383A4C", "base": "#282A36",
      "mantle": "#21222C", "crust": "#191A21"
    }
  }
}
```

Este exemplo valida como está, e o flavor é `meutema`, uma palavra só: o id do
pack pode ter hífen, o nome de flavor não. Todo bloco JSON inteiro deste
documento passa pelo `validar` no `tests/pack.sh`; os que mostram só um pedaço
de arquivo levam `json fragmento` no fonte, e deles se confere só que são JSON.

**Os 26 nomes são do Catppuccin, e isso é deliberado.** Eles não são "as cores
do Catppuccin": são o **vocabulário** com que o resto do projeto fala de cor.
O `cosmic-map.json` mapeia cada slot do tema do COSMIC para um desses nomes e
nunca cita um hex; o esquema ANSI do terminal sai deles; o painel gera o CSS a
partir deles.

Você não fornece "as suas cores". Você fornece **um mapeamento das suas cores
para esses 26 nomes**. Se o seu tema tem 12 cores, as outras 14 são derivadas —
é exatamente o que o Dracula faz, e o `_comentario` da `paleta.json` dele
registra quais foram derivadas e como.

O que cada nome quer dizer, na prática:

| Grupo | Nomes | Papel |
|---|---|---|
| Acentos | `rosewater` `flamingo` `pink` `mauve` `red` `maroon` `peach` `yellow` `green` `teal` `sky` `sapphire` `blue` `lavender` | cor de destaque; um deles vira o `ACCENT` |
| Texto | `text` `subtext1` `subtext0` | do mais forte ao mais apagado |
| Sobreposição | `overlay2` `overlay1` `overlay0` | bordas, separadores, texto desabilitado |
| Superfície | `surface2` `surface1` `surface0` | fundos elevados, do mais claro ao mais escuro |
| Fundo | `base` `mantle` `crust` | o fundo da janela, o da barra, o mais profundo |

**`claros`** lista quais flavors são de fundo claro. O COSMIC alterna entre um
tema escuro e um claro, e alguém precisa responder pelo claro: sem isso, ao
alternar, a pessoa cai no tema do pack ANTERIOR.

**Nome de flavor é uma palavra só, sem hífen.** O tema é gravado como
`<flavor>-<accent>` e o leitor corta no hífen — um flavor `tema-claro` vira
flavor `tema` com accent `claro-mauve`, e o erro que aparece manda procurar
defeito no lugar errado. A validação recusa antes disso acontecer.

### Se o seu tema não tem um claro

Derive um, e confira contra o Latte. Foi assim que o pack `dracula` ganhou o `alucard`, e
o método cabe em três regras:

1. **Matiz do seu tema, luminância do Latte.** O Latte não é "o Mocha
   invertido": medindo os 26 slots, ele preserva o matiz (±10°) e reescreve a
   rampa de luminância — `base` vai de 0,01 para 0,88 e `text` de 0,68 para
   0,08. Copiar essa rampa é herdar uma calibração pronta; o matiz é o que faz
   a cor continuar sendo do seu tema.
2. **A saturação também vem do Latte.** Ele clareia a estrutura *baixando* a
   saturação (o `base` dele é quase neutro) e escurece os acentos *subindo*.
   Manter a saturação do tema escuro produz pastel: o `base` do Dracula claro
   saiu `#BDC6FF`, um azul forte, e os 14 acentos reprovaram contra ele.
3. **Onde o slot original é quase neutro (saturação < 0,10), use o matiz do
   `base`.** O matiz de um quase-branco é ruído. O `text` do Dracula é
   `#F8F8F2`; preservar "o matiz dele" e saturar deu `#52523C`, um oliva que o
   tema não tem.

E confira com uma régua que a referência cumpra: `text` sobre `base` ≥ 7:1
(AAA), e **cada slot não abaixo de 95% do que o Latte faz no mesmo slot** — a
régua do `scripts/derivar_claro.py`, que gerou o `alucard`; "não pior" ao pé da
letra reprova o próprio `alucard` em 21 slots por um centésimo, porque a
derivação mira a luminância do Latte e o arredondamento para hexa cai logo
abaixo. Exigir 4,5:1 de todo acento reprova 12 slots — e reprova o próprio
Latte, onde `rosewater` sobre `base` dá 2,32. Esses slots são decoração, não
texto.

---

## A fronteira: `assets/` contra `packs/`

Esta é a regra que decide, para **todo arquivo novo**, onde ele mora. Ela cabe
em três linhas:

| diretório | o que guarda | exemplo |
|---|---|---|
| `assets/` | **o que o MeowSystem É** — o motor, menos a arte de ícone | `assets/paleta/cosmic-map.json`, `packs/meowsystem/mascote/`, `assets/apps/appid.map` |
| `packs/` | **o que ele VESTE** — o tema, e **todo** desenho de ícone | `packs/dracula/paleta.json`, `packs/meowsystem/icones/sistema/`, `packs/dracula/mascote/` |
| `~/.local/state/meowsystem/` | **o que a máquina GEROU** — e não volta para o git | os `.ron` do COSMIC, os backups, o log |

**Desenho de ícone é sempre `packs/`** (decisão 14). O traço Arcticons, os
convertidos, os retoques e os glifos do sistema são o **pack-base** `packs/meowsystem/`, no
mesmo formato de três pastas, e todo pack o herda. Os mapas técnicos de aplicativo
(`appid.map`, `apps-nomes.map`, `jogos-fora.map`) e os originais de fábrica da
bandeja moram em `assets/apps/`, porque são fato da máquina e não arte.

**A pergunta que separa as duas primeiras:** *este arquivo continuaria fazendo
sentido se o tema fosse outro?* O `cosmic-map.json` sim — ele é o molde, e não
tem um hex dentro. A paleta do Catppuccin não — ela **é** o tema.

**O par mais fácil de errar:** `assets/paleta/cosmic-map.json` é motor, e a paleta do
Catppuccin é tema, em `packs/meowsystem/paleta.json`.

**Quem cobra a regra é `tests/arvore.sh`**, e ele pergunta ao `git ls-files`, e
não ao disco. Medir o disco já custou caro: o `du` disse que o acervo de ícones
do Catppuccin tinha 13 MB (são 413 KB — o bloco de 4 KB mentindo sobre milhares
de SVG minúsculos) e que `assets/icones/upstream/` tinha 96 MB versionados,
quando ele tem **zero** arquivos no git.

### As duas exceções, e elas são escritas

**`scripts/temas-de-apps/`** tem nome de flavor dentro e **fica**: são os temas
que os *outros* aplicativos publicam — o `dracula.css` do Heroic, o
`catppuccin-mocha.theme` do btop —, baixados do upstream deles e conferidos por
SHA256. O nome do tema está no arquivo do terceiro, não num arquivo nosso. É
contrato próprio, com manifesto próprio.

**`assets/temas/capturados/original/`** é a única captura que não mora num pack,
e ela não é tema de pack nenhum: é o **molde** do esquema `v1` que o COSMIC
escrevia (o `scripts/gerar_tema_v1.py` deriva dela, chave por chave) e o
reset de fábrica daquela máquina. O `capturar_tema.sh` **recusa** recapturá-la —
fora do git ela é irrecuperável.

---

## A estrutura do pack

`pack.json` e a paleta são obrigatórios para o tema funcionar; o `logo.svg`, para
o pack se publicar. Todo o resto é opcional.

```
packs/<id>/
  pack.json                 OBRIGATÓRIO
  paleta.json               OBRIGATÓRIO (o nome vem de paleta.arquivo)
  logo.svg                  OBRIGATÓRIO para publicar — quadrado, cores por papel
  LEIA-ME.md                a história do pack, em texto (vitrine.descricao)
  capturas/                 fotos de tela, se quiser (vitrine.capturas)
  CREDITOS.md               a procedência de cada acervo — obrigatório se houver arte de terceiro
  cosmic-map.json           opcional: substitui o molde do tema do COSMIC
  icones/                   TRÊS PASTAS PLANAS (formato 2): sem subpasta — ver "O acervo de ícones do pack"
    apps.map                "nome-do-ícone : caminho/relativo.svg"
    apps/                   o desenho LIGADO a um programa (o apps.map aponta para cá), e os
                            autorais: <nome>-<flavor>.svg e <nome>.json — ver "Desenhos autorais"
    sistema/                pasta, tipo de arquivo, status, simbólico — o tema monta daqui:
                            folder-*.svg (pastas.map) e os moldes de tipo de arquivo (mimetypes.map)
    biblioteca/             TODO o resto, para escolher no painel: SVG e PNG feito à mão
  PROCEDENCIA.md            de onde veio cada arquivo (o flavor vai no nome, a origem aqui)
  mascote/                  o mascote do dock e do terminal (mascote.dia, mascote.noite)
  temas-de-apps/<app>/      os temas de DENTRO dos aplicativos — ver a seção própria
  cursores/<nome>/cursors/  o ponteiro do pack (origens.cursores.proprio) — ver "O ponteiro"
  wallpapers/               papéis de parede em SVG (origens.wallpapers.desenhos), rasterizados ao semear
  sons/                     um tema de som freedesktop (som.tema)
  fontes/                   .ttf/.otf que o pack traz (fontes.proprio) — ver "As fontes"
  temas/
    capturados/<flavor>-<accent>/    o tema do COSMIC já fotografado — ver a seção própria
                                     (é convenção: não precisa declarar nada)
```

### Onde um pack mora

O MeowSystem procura nesta ordem, e a **primeira** que tiver o `id` vence:

| | Caminho | Para quê |
|---|---|---|
| 1 | `$MEOW_PACKS/<id>/` | teste, sem instalar nada |
| 2 | `~/.local/share/meowsystem/packs/<id>/` | **o seu**: clone de git, tarball, o que você quiser |
| 3 | `<raiz do MeowSystem>/packs/<id>/` | os que vêm de fábrica |

A raiz 2 é o `XDG_DATA_HOME`. Não é `/usr/share`, não é `~/.config/zsh` — passa
longe das duas listas de destino proibido de `lib/comum.sh`.

---

## `pack.json`, campo a campo

### Obrigatórios

| Campo | Tipo | O que é |
|---|---|---|
| `formato` | inteiro | a versão **do formato**, não do seu pack. Hoje: `1` |
| `id` | texto | `[a-z0-9-]+`. É o nome do diretório e o prefixo de tudo |
| `nome` | texto | como aparece na tela |
| `paleta.arquivo` | caminho | relativo ao pack |
| `paleta.flavor_padrao` | texto | um flavor que exista na paleta |
| `vitrine.capa` | caminho | um SVG dentro do pack — por convenção `logo.svg` —, e ele é o logo do pack. Cobrado só por quem publica: ver [A vitrine](#a-vitrine) |

`formato` existe para que um pack antigo num MeowSystem novo **falhe dizendo o
que falta**, em vez de pintar errado. Um pack com `formato` maior que o
suportado é recusado com o número na mensagem.

### O resto

```json fragmento
{
  "versao": "1.0.0",
  "autor": "Seu Nome",
  "licenca": "MIT",
  "creditos": "CREDITOS.md",
  "heranca": "catppuccin",

  "vitrine": {
    "capa": "logo.svg",
    "descricao_curta": "Uma linha, até 80 caracteres.",
    "descricao": "LEIA-ME.md",
    "tags": ["escuro", "verde"],
    "capturas": ["capturas/area-de-trabalho.png"],
    "site": "https://exemplo.org/meu-tema"
  },

  "paleta": {
    "arquivo": "paleta.json",
    "flavor_padrao": "meutema",
    "acentos": ["mauve", "pink", "green"],
    "claro_de_reserva": { "pack": "catppuccin", "flavor": "latte" }
  },

  "cosmic": {
    "mapa": null,
    "nome_da_paleta": "meu-tema-<flavor>"
  },

  "icones": {
    "apps":      { "mapa": "icones/apps.map", "desenhos": "icones/apps/",
                   "camada": "scalable/apps", "recolorir": false },
    "pastas":    { "desenhos": "icones/sistema/" },
    "mimetypes": { "herda": "meowsystem" },
    "autorais":  { "gerar": true },
    "base":      { "origem": { "url": "https://exemplo.org/tema-v1.tar.gz",
                               "sha256": "…", "pasta": "tema-v1" },
                   "por_tras": [ { "origem": { "url": "…", "sha256": "…", "pasta": "…" } } ] }
  },

  "lancador": { "ocultar": ["org.gnome.baobab", "qt5ct"] },

  "som": { "tema": "sons/" },

  "origens": {
    "cursores":   { "proprio": "cursores/meu-tema-roxo" },
    "wallpapers": { "tipo": "github-arvore",
                    "repo_do_conf": "WALLPAPER_SEMENTE_REPO",
                    "commit_do_conf": "WALLPAPER_SEMENTE_COMMIT",
                    "se_vazio": "herdar",
                    "desenhos": "wallpapers/" }
  },

  "apps": {
    "spotify":     { "spicetify_tema": "Sleek", "esquema": "Dracula" },
    "qbittorrent": { "arquivo": "apps/meu-tema.qbtheme", "sha256": "…" }
  },

  "fontes": {
    "proprio": [ { "arquivo": "fontes/MinhaFonte-Regular.otf" } ]
  }
}
```

**`origens.cursores`** é `{"proprio": "cursores/<nome>"}` para o pack que traz
o ponteiro, `{"origem": {…}}` para o que manda baixá-lo de um endereço pinado,
ou `{"herda": "<id>"}` para o que pega o de outro — ver [O
ponteiro](#o-ponteiro). **`fontes`** tem a mesma forma, com uma lista — ver [As
fontes](#as-fontes). **`icones.base`** é o tema que o seu herda para tudo o que
ele não desenha — ver [A base de ícones](#a-base-de-ícones).

**`icones.mimetypes.derivar`** é a outra forma do bloco de ícones de arquivo:
`{"de": "catppuccin", "pasta": "css-variables"}` manda o `meow pack construir`
pegar o acervo daquele pack em que a cor vem escrita por papel, trocar cada papel
pelo hex da sua paleta. O Dracula não usa esta
forma: os 656 ícones de arquivo são o molde do pack `meowsystem`
(`icones/sistema/`, herdado por `icones.mimetypes.herda`), pintado na instalação
com a paleta do pack no ar, sem copiar desenho nenhum.

**`lancador.ocultar`** é a lista de `.desktop` que o pack esconde do lançador:
ids com letras, dígitos, `.`, `_` e `-`, sem `/` e sem a extensão. Ela soma à
chave `LANCADOR_OCULTAR` do `meow.conf`, e trocar de pack devolve ao lançador o
que só o pack de antes escondia.

**`som.tema`** aponta para um tema de som freedesktop dentro do pack, que o
`scripts/som.sh` instala. **`origens.wallpapers.desenhos`** aponta para uma
pasta de SVG: o `scripts/wallpaper.sh` os rasteriza em PNG 4K ao semear a
coleção.

**`autor`, `versao` e `licenca`** aparecem no alto do `meow pack info`, e o
`autor` também no cartão do painel.

**`heranca`** nomeia o pack de onde vem tudo o que você não declarou. Ela é
obrigatória de escrever mesmo quando é o default: um pack que herda 18 de 21
categorias **é o pack base com outra paleta**, e isso precisa estar na cara de
quem lê, não escondido num default.

**`cosmic.mapa: null`** usa o molde do núcleo inteiro. Só o campo
`palette.name` é substituído por `cosmic.nome_da_paleta` — hoje o molde crava
`"catppuccin-<flavor>"` (`assets/paleta/cosmic-map.json:4`), o que faria um pack
Dracula aparecer como `catppuccin-dracula` na GUI de tema.

**`icones.apps.recolorir`** decide se os desenhos são repintados com a sua
paleta. Use `false` quando a arte já nasce na cor certa e tem cores próprias —
repintar não seria aplicar o tema, seria destruir o desenho. Use `true` para
acervos monocromáticos de traço, em que o mapa carrega uma coluna de cor.

**`repo_do_conf`** e **`commit_do_conf`** nomeiam **chaves do `meow.conf`**, não
valores. É de propósito: `dono/repo` nomeia a conta de uma pessoa, e este arquivo
é versionado. Quem instala o pack põe o repositório no próprio `meow.conf`, que
não vai para commit nenhum. `se_vazio: "herdar"` diz o que fazer quando a chave
está vazia. Só valem chaves `WALLPAPER_*_REPO` e `WALLPAPER_*_COMMIT`: o `validar`
recusa qualquer outro nome, porque o `wallpaper.sh` o lê por expansão indireta.

**`curadoria`** é o `FONTES.tsv` do pack (arquivo, categoria, URL): só entra a
linha com nome simples de arquivo (letras, dígitos, `.`, `_`, `+`, `-`, sem `/`,
sem `..` e sem começar por ponto) e URL `https://`. O resto é ignorado com aviso.

Os papéis de parede são **separados por pack**: só a coleção do pack no ar gira
(o prefixo dele no nome e a curadoria dele); a de outro pack fica em `ativos/`
sem girar, e trocar de pack troca a coleção. A imagem que não é de pack nenhum
gira com qualquer um.

---

## A vitrine

Ninguém escolhe um tema por um `id`. O bloco `vitrine` é o que o pack diz de si para
quem vai escolher:

```json fragmento
"vitrine": {
  "capa": "logo.svg",
  "descricao_curta": "O roxo do Dracula, com os morcegos de mascote.",
  "descricao": "LEIA-ME.md",
  "tags": ["escuro", "claro", "roxo", "alto contraste"],
  "capturas": ["capturas/area-de-trabalho.png"],
  "site": "https://draculatheme.com"
}
```

| Campo | Regra | Por quê |
|---|---|---|
| `capa` | **obrigatória**; SVG; dentro do pack; o arquivo existe — e o arquivo é o logo, com as regras de [O logo do pack](#o-logo-do-pack) | vetor porque o cartão aparece em vários tamanhos, e um PNG de capa envelhece junto com a resolução |
| `descricao_curta` | uma linha, **até 80 caracteres** | é o que cabe numa linha do cartão — o mesmo teto dos balões do painel |
| `descricao` | um `.md` dentro do pack, até 64 KiB | a história inteira, para quem abrir o cartão |
| `tags` | lista de textos | as etiquetas do cartão |
| `capturas` | lista de `.png`, `.jpg`, `.jpeg` ou `.svg` dentro do pack | fotos de tela; as quatro extensões que o painel sabe mostrar |
| `site` | **só `https://`** | é o único campo do pack que vira link clicável |

**A capa é o logo.** Tira de cores é paleta, não identidade — dois packs de
paleta parecida ficariam iguais no cartão. A capa é o `logo.svg` do pack, o
mesmo arquivo que vira o ícone do lançador; a tira continua no cartão, fina,
embaixo dele, como amostra da paleta. Por isso o campo é um só: um
`vitrine.logo` ao lado de um `vitrine.capa` seriam duas verdades para a mesma
figura. E o campo manda: se a capa apontar para outro arquivo que não o
`logo.svg`, é **esse** arquivo que o `validar` e o verbo `logo` conferem como
logo — sem script, `viewBox` quadrado, nada apontando para fora. Não sobra uma
segunda figura que escape das regras do logo.

**A descrição é mostrada como texto, nunca como HTML.** O painel põe o
Markdown do `LEIA-ME.md` num bloco de texto puro, sem interpretar nada — nem
negrito, nem link. Um pack é dado, e dado não injeta: renderizar Markdown de
terceiro numa página que carrega o token de sessão seria dar a um arquivo
baixado da internet a chance de virar código dentro do painel. Quem quiser
formatação escreve no site, que o cartão linka.

**Ela é cobrada de quem publica, e nunca de quem usa.** `meow pack validar`
recusa a vitrine quebrada — e diz todos os problemas de uma vez. O instalador,
o `meow pack info` e o painel **não**: o tema de um pack sem capa continua
funcionando no desktop, e o `info` e o cartão mostram o pack dizendo o que
falta. Se a capa ausente trancasse o motor, o tema inteiro seria trocado pelo
padrão por causa de uma figura que só a tela de escolha mostra. O logo segue a
mesma fronteira (ver [O logo do pack](#o-logo-do-pack)), e a capa é o logo.

**Com uma exceção, que não nasceu na vitrine: a URL fora de `https://`.** Ela
é o item 11 do `validar`, vale para **qualquer** campo do `pack.json` e roda
também para quem usa. Um `site` em `http://`, ou uma `descricao_curta` que cite
um endereço `http://`, tira o pack do desktop como tiraria em qualquer outro
campo: o `meow pack info` recusa com a mesma mensagem do `validar`, e o cartão
do painel mostra o pack só com o motivo. O `site` em `javascript:`, que não tem
`://`, é da vitrine — só o `validar` o recusa, e o cartão simplesmente não o
transforma em link.

No terminal, a vitrine é o alto do `meow pack info`:

```
$ meow pack info dracula | head -6
Dracula  [dracula]  versão 1.0.0 · formato 1
  autor     : MeowSystem · licença GPL-3.0-or-later
  descrição : O roxo do Dracula, com os morcegos de mascote.
  tags      : escuro, claro, roxo, alto contraste
  origem    : próprio: paleta, ícones de aplicativo, pastas, … · herdado de catppuccin: …
  diretório : …
```

A linha `origem` é a tabela de categorias do mesmo comando virada frase, e o
cartão do painel mostra exatamente ela — as duas saem da mesma função do
`scripts/pack.py`.

---

## De onde sai um acervo: pack, herança, motor

Um **acervo** é um diretório ou um arquivo de arte que o pack declara: o mapa de
ícones de aplicativo, os desenhos, os glifos de tipo de arquivo. Quem responde
"onde está este acervo" é **um lugar só** — o verbo `acervo` do
`scripts/pack.py` —, e ele sobe três degraus, nesta ordem:

| | degrau | o que é |
|---|---|---|
| 1 | **o pack ativo** | o que o `pack.json` dele declara naquela categoria |
| 2 | **a herança** | o pack nomeado em `<categoria>.herda`, ou em `heranca` |
| 3 | **o pack-base** | `packs/meowsystem/`, o acervo do próprio MeowSystem |

```bash
python3 scripts/pack.py acervo dracula icones.apps.mapa
#   packs/dracula/icones/apps.map

python3 scripts/pack.py acervo dracula icones.mimetypes.desenhos
#   packs/meowsystem/icones/sistema/   <- subiu pela herança
```

**A herança do bloco vence a do pack inteiro.** O Dracula declara
`heranca: "meowsystem"` no topo **e** `icones.mimetypes.herda: "meowsystem"` no
bloco — a do bloco é a que fala daquela categoria, e um pack que herde só uma
categoria de outro lugar precisa dela.

**Herança circular não trava.** Dois packs que herdem um do outro devolvem "não
achei", e não um laço infinito.

**O caminho declarado tem de cair dentro do pack.** Um `"mapa":
"../../../etc/algo"` é ignorado naquele degrau, com um aviso no stderr que
nomeia o campo — e a herança logo abaixo ainda pode ter a resposta certa. É a
mesma regra do `realpath` que o validador aplica.

**Ausência é resposta**, e não erro: uma categoria que o pack não declara e que
ninguém herda devolve nada, e quem chamou decide se isso é problema.

> **`acervo` não é `caminho`.** O verbo `caminho` olha **só** o pack e serve de
> sonda de existência para o shell (`lib/comum.sh` joga a saída dele fora e olha
> o código de retorno). Reaproveitar aquele nome para esta semântica faria todo
> script de shell deixar de enxergar o pack, sem erro nenhum na tela.

### A captura de tema tem verbos próprios, e ler não é escrever

```bash
python3 scripts/pack.py captura mocha-mauve
#   onde ESTÁ: sobe pack ativo -> herança -> motor, como o `acervo`

python3 scripts/pack.py captura-destino dracula-sky
#   onde ESCREVER: o pack ATIVO, sempre. Nunca sobe pela herança.

python3 scripts/pack.py capturas
#   os nomes alcançáveis daqui, um por linha
```

**Por que a escrita não sobe pela herança.** Com o Dracula no ar, ler
`mocha-mauve` acha a captura do Catppuccin, de quem ele herda — e isso é o certo.
**Gravar** ali poria a foto do Dracula *dentro* do pack do Catppuccin, e a
próxima pessoa a instalar o Catppuccin receberia um tema que não é dele.

**Não é preciso declarar nada.** `temas/capturados/` é convenção, como
`pack.json` e `CREDITOS.md`. Declarar `temas.capturados` no `pack.json` continua
valendo e vence a convenção, para quem organiza o pack de outro jeito.

Do lado do shell, as mesmas perguntas são `meow_captura` e `meow_capturas`
(`lib/comum.sh`), que refazem a ponte `MEOW_PACK_DIR` sozinhas — o `vidro.sh` e
o `greeter.sh` rodam pelo timer e pelo hook, sem passar por ela.

---

## O acervo de ícones do pack

**A regra cabe numa frase: todo desenho de ícone mora num pack, em três pastas
planas** (decisão 14). Vale para o Dracula, o Catppuccin, o
pack-base `meowsystem` e todo pack futuro.

### Uma versão por ícone, e os projetos da autora

**Uma versão por ícone** (decisão 13): a ligada a um programa é a que quem usa
escolheu. **Os projetos da autora entram na biblioteca do Dracula**, direto em
`icones/biblioteca/`. Nenhum desenho
da biblioteca veste um programa sozinho: quem veste é uma linha do `apps.map`.
De onde veio cada arquivo está no `PROCEDENCIA.md`, e o `catalog.json` da pasta
dá o rótulo do seletor.

### As três pastas

```
packs/<id>/icones/
  apps/         o desenho ligado a um programa; o apps.map aponta só para cá
  sistema/      pastas, tipos de arquivo, status, simbólicos — o tema monta daqui
  biblioteca/   todo o resto, para escolher no painel
  apps.map      a ligação programa → desenho (e os outros mapas, ao lado dele)
```

- **Flavor é sufixo no nome** (`cosmic-term-mocha.svg`), nunca subpasta nem
  quarta pasta: as três são planas, e o `validar` recusa subpasta dentro delas.
- **A origem não é pasta.** PNG feito à mão, desenho recuperado, autoral ou
  versão antiga: tudo é `biblioteca/` (ou `apps/`, se estiver ligado). O que
  diferencia de onde veio é o `PROCEDENCIA.md`.
- **O `validar` recusa a quarta pasta** num pack de formato 2, na porta de quem
  publica — a do motor continua vendo o pack, para uma pasta solta não trocar o
  tema de ninguém.
- **Um pack de formato 1 continua valendo.** O motor lê as pastas que ele
  declara, e o `meow pack importar` converte um `.meowpack` de formato 1 na
  chegada: cada pasta vai para uma das três (pelo nome ou pela categoria), e o
  `pack.json`, o `apps.map` e a primeira coluna do `PROCEDENCIA.md` passam a
  dizer o caminho novo, sem mudar um byte de desenho.
- **`meow pack novo` cria as três**, vazias, e o `CREDITOS.md` dele diz o que
  vai em cada uma.

**Os autorais não têm mapa, e é de propósito:** o nome do arquivo *é* o
pareamento. `cosmic-term-mocha.svg` diz, sozinho, qual ícone e qual flavor — um
mapa ao lado seria uma segunda verdade sobre a mesma coisa. As pastas e os tipos
de arquivo precisam de mapa porque o nome que o sistema pede
(`application-x-cd-image`) não é o nome do desenho (`cd`).

Cada categoria declara os dois no `pack.json`, e nenhuma é obrigatória:

```json fragmento
"icones": {
  "apps":      { "mapa": "icones/apps.map", "desenhos": "icones/apps/" },
  "mimetypes": { "mapa": "icones/mimetypes.map", "desenhos": "icones/sistema/" },
  "autorais":  { "desenhos": "icones/apps/" }
}
```

O `validar` cobra a existência de tudo o que estiver declarado. Um pack que
promete um acervo e não entrega é recusado — pelo mesmo motivo que o `creditos`
é cobrado: um validador que carimba a promessa vazia ensina a escrevê-la.

### O pack-base `meowsystem`

`packs/meowsystem/` é o acervo do próprio MeowSystem, no mesmo formato: o traço
Arcticons e os convertidos em `apps/`, os glifos do sistema e do modo de leitura
em `sistema/`. Ele declara `"papel": "base"`: **todo pack o herda sem
declarar** — é a última camada de onde o motor tira o que um pack não traz, e é
para onde `motor:` aponta —, e **ele não se veste sozinho**: não tem paleta nem
logo, a porta do motor (o `meow pack usar`, o `PACK=` do `meow.conf`) o recusa, e
o painel não faz cartão dele.

Os mapas do motor desceram com ele, para `packs/meowsystem/icones/`, cada um no
formato que o leitor dele lê: `apps-arcticons.map` (`nome:glifo:cor`),
`apps-convertidos.map` (a receita do conversor), `apps-marca.map`, `sistema.map`,
`bandeja.map`, `pastas.map`, `apps-hicolor.map`. Juntá-los num `apps.map` só é
decidir um formato de mapa que caiba em todos, e reescrever os leitores que
recolorem por categoria — fica para quando houver um quinto leitor que o peça.

**O desenho de um pack vence o traço do pack-base em todo tamanho** (decisão 16,
item 7). Um nome que o pack no ar põe em `scalable/apps` (pelo `apps.map`, pelos
resgatados ou pela escolha do painel) não ganha o traço de 48 px, que antes o
encobria naquele tamanho — eram 17 no Dracula. Fica o traço que quem usa
escolheu (a linha dele no `icones-traco.map`).

Os **resgatados** (os desenhos da autora que só existiam em PNG, de cor Dracula fixa)
**não** estão no pack-base: no `meowsystem` o Catppuccin os herdaria (decisão
16). Moram em `packs/dracula/icones/apps/`, com o mapa
`apps-resgatados.map` ao lado do `apps.map`, declarados como
`icones.resgatados`. Com outro pack no ar, nenhum vale, e o que estava no tema
sai dele.

### A biblioteca: os desenhos que ainda não vestem ninguém

`icones/biblioteca/` guarda a **coleção** do pack — os desenhos de onde a pessoa
escolhe o próximo ícone de aplicativo, vestindo alguém ou não.

- **Não tem campo no `pack.json`, e é de propósito.** Nada instala a biblioteca:
  quem põe desenho no tema é o `apps.map`, e uma linha dele aponta para
  `biblioteca/x.svg` como aponta para `apps/x.svg` —
  `best.ellie.StartupConfiguration : biblioteca/sun.svg`. A pasta é convenção,
  como `temas/capturados/`.
- **O `meow pack info` a conta**, na linha dos aplicativos:
  `icones.apps  PRÓPRIO  203 apps, 263 na biblioteca sem app ligado`. "Sem app
  ligado" é medido por **conteúdo** (sha256), não por caminho: onze desenhos da
  biblioteca do Dracula também moram em `apps/` com nome de aplicativo (o
  `dice.svg` é o `apps/foundryvtt.svg`, byte a byte), e contar por caminho diria
  que o dado não veste ninguém.
- **O `validar` cobra a forma** — `.svg` e `.png` comuns, sem link e sem
  subpasta, todos os achados de uma vez — e só na porta
  de quem publica: um arquivo solto numa pasta que nada instala não pode fazer o
  motor ignorar o pack inteiro.
- **Cada desenho tem a linha dele no `PROCEDENCIA.md`**, como qualquer arte
  copiada (ver [Fonte e derivados](#fonte-e-derivados)). O `tests/pack.sh`
  cobra isso, e conta a biblioteca do Dracula contra o `Dracula_OS-Theme` por
  sha256 quando ele está na máquina — onde não está, pula dizendo por quê.
  Nada do MeowSystem lê aquele repositório em execução: ele é a origem da
  cópia, e só.

**Trazer as ligações de outro tema não troca escolha nenhuma.** Um nome que já tem outra
escolha (no próprio mapa, no `apps-resgatados.map`, numa tabela do `completar_icones.sh`)
não entra pela metade: soltar só os nomes livres vestiria o mesmo aplicativo com dois
desenhos. Quando o pack e o `apps-resgatados.map` disputam o mesmo arquivo, a precedência é
a do `fontes` do `scripts/pack.py`: o pack vence com `ICONES_DRACULA="sim"`, o resgate sem
ele.

### Os feitos à mão

Os desenhos feitos à mão para aplicativos moram em `icones/biblioteca/`, sem
campo no `pack.json`, e nada os instala sozinho — quem veste um programa com eles
é uma linha de mapa, ou a escolha de quem usa no seletor.

Desenho que chega em PNG vira vetor (decisão 2): o SVG é desenhado em formas, na cor medida
no PNG, e conferido por RMSE contra ele, sobre o fundo do pack e sobre branco, valendo o
pior dos dois. O PNG sai só quando o vetor passa, e o SVG tem a linha dele no
`PROCEDENCIA.md`, com o sha256 do PNG de que nasceu.

**Raster não é fonte.** Um PNG que ainda não tenha vetor continua visível no
seletor, numa pasta à parte («feitos à mão (PNG)»), e travado: ele não se
escolhe. No Dracula essa pasta está vazia, e não aparece.

### `motor:` — apontar para o acervo do pack-base sem copiá-lo

Um alvo de mapa pode sair do pack, **com prefixo declarado**:

```
org.telegram.desktop          : motor:biblioteca/telegram.svg
io.github.flattool.Warehouse  : apps/Warehouse.svg
```

| forma | resolve em |
|---|---|
| `motor:<caminho>` | `packs/meowsystem/icones/<caminho>` — o acervo do pack-base (o caminho antigo com subpasta, como `apps/arcticons/x.svg`, ainda vale num mapa velho) |
| `pack:<id>:<caminho>` | `<pack id>/icones/<caminho>` — o acervo de **outro** pack |
| sem prefixo | dentro do pack, contra o diretório do próprio mapa |

São três casas, e só três. `~/…` e caminho absoluto são **recusados** pelo
`validar`, com a frase que diz por quê — ver [Fonte e derivados](#fonte-e-derivados).

**É isto que permite a decisão morar no pack sem duplicar o acervo.** Sem o
prefixo, cada pack carregaria uma **cópia** dos SVG do Arcticons — e a segunda
cópia defasa da primeira calado, que é a lição que este projeto já pagou uma vez.

Os dois lados têm guarda: um alvo que **saia** da raiz dele é recusado, com o
motivo no stderr. Um mapa é dado, e um pack de terceiro escreve o dado dele.

```bash
printf 'motor:biblioteca/telegram.svg\n' \
  | python3 scripts/pack.py alvo packs/dracula/icones
#   <raiz>/packs/meowsystem/icones/biblioteca/telegram.svg
```

O verbo lê a entrada padrão e devolve **uma linha por linha de entrada** — a
recusada volta vazia. Quem chama junta essa saída com os nomes do mapa lado a
lado, e uma linha a mais ou a menos vestiria cada aplicativo com o ícone do
vizinho, sem erro nenhum na tela.

### Ler e escrever são portas diferentes

| verbo | responde | para quem |
|---|---|---|
| `acervo <id> <categoria> [arquivo]` | o arquivo, **se ele existe**; sobe a herança | quem vai **ler** |
| `onde <id> <categoria> [padrão]` | o diretório, **exista ele ou não**; não sobe a herança | quem vai **escrever** |

O `onde` não sobe a herança de propósito: herdar é dizer *"leia do vizinho"*, e
escrever no acervo do vizinho seria um pack gravando dentro de outro. Um pack
que não declara a categoria escreve **em casa**.

```bash
python3 scripts/pack.py onde dracula icones.autorais.desenhos
#   packs/dracula/icones/apps/     — mesmo antes de o diretório existir
```

### Os autorais, e o flavor que caía no pack do vizinho

Os desenhos autorais de `icones/apps/` nascem **por papel**, nunca por hex digitado:
cada forma declara `sujeito`, `tinta`, `fundo`, e o papel resolve na paleta
**daquele flavor**. É o que faz um flavor novo nascer sem redesenho.

> **Todo flavor da sua paleta precisa dos seus.** Um flavor declarado que não
> tem desenho nenhum no acervo cai, calado, no acervo de quem o pack herda — e
> aí o modo claro do seu tema mostra o claro **de outro pack**.
>
> `tests/pack.sh` trava isso: um flavor vazio ao lado de um irmão cheio é
> achado, em qualquer pack.

Gerar os de um pack é uma linha:

```bash
MEOW_PACK_DIR=packs/dracula python3 scripts/gerar_icones_autorais.py
```

### Desenhos autorais

**O desenho é um arquivo do pack.** Cada `icones/apps/<nome>.json` é um desenho, que o
gerador pinta pela paleta, por papel. Os dois packs do projeto não trazem declaração
nenhuma: projeto pessoal não entra num pack público (decisão 29). O formato, para o seu
pack:

```json
{
  "_nota": "a história do desenho: por que esta forma, o que foi medido a 48px",
  "papeis": {
    "corpo":    { "escuro": "text",     "claro": "text" },
    "tinta":    { "escuro": "crust",    "claro": "base" },
    "touchpad": { "escuro": "<accent>", "claro": "<accent>" }
  },
  "svg": [
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 48 48\" …>",
    "  <title>{titulo}</title>",
    "  <path d=\"…\" fill=\"{corpo}\"/>",
    "  <rect x=\"19.2\" y=\"17.2\" width=\"9.6\" height=\"6.4\" fill=\"{touchpad}\" stroke=\"{tinta}\"/>",
    "</svg>"
  ]
}
```

- **O nome vem do arquivo.** `meu-app.json` gera `meu-app-<flavor>.svg`, um por
  flavor da paleta, **na mesma pasta**. Não há campo `nome`: seria a segunda
  verdade sobre a mesma coisa.
- **Cada papel diz a cor no flavor escuro e no claro, por nome da paleta** — um
  dos 26 que todo pack tem, ou `<accent>`, o acento que a pessoa escolheu. Por
  isso uma declaração serve a qualquer pack: o `alucard` do Dracula nasce dela
  sem redesenho.
- **O SVG é uma lista de linhas**, com uma lacuna `{papel}` onde a cor entra.
  `{titulo}` é do gerador. Toda lacuna tem papel, e todo papel tem lacuna.
- **Nenhum hex no SVG**, nada de `script`, `foreignObject`, `on*=` ou `href`
  para fora. O `validar` recusa, e diz o arquivo e o que consertar.

**A herança vale para ler.** Um pack alcança as declarações do pack de quem
herda. Quem escreve é sempre o pack em casa: um `meu-app.json` declarado no
Catppuccin e lido pelo Dracula gera o `meu-app-alucard.svg` em
`packs/dracula/icones/apps/`, da paleta do Dracula. Uma declaração no pack
vence a herdada de mesmo nome.

**`desenhos` é um diretório**, não um glob: é a pasta onde os autorais do pack moram, por
onde o gerador sabe onde escrever. As declarações são os `.json` daquela pasta. **Sem
`desenhos`** — é o caso do modelo lá em cima, que declara só `"gerar": true` — a pasta é
`icones/apps/`, para ler e para escrever.

Um terceiro desenho entra **sem tocar em Python**:

```bash
cp meu-app.json packs/dracula/icones/apps/
python3 scripts/pack.py validar dracula       # confere a declaração
python3 scripts/pack.py construir dracula     # gera meu-app-dracula.svg e -alucard.svg
```

> **O que ainda é código:** os nove desenhos do próprio sistema (o painel do
> MeowSystem e os oito `com.system76.Cosmic*`) continuam funções no gerador, e
> a tabela de *qual `Icon=` veste qual desenho* continua no `AUTORAL` do
> `completar_icones.sh`. O desenho novo **nasce** no pack; pô-lo na tela de um
> aplicativo ainda pede uma linha naquela tabela.

**No painel**, o passo «Ícones» de Criar tema termina na seção **Desenhos autorais do pack**: o
desenho, os papéis dele com a cor em cada flavor, e a prévia — cada flavor sobre
quatro fundos da paleta dele (`crust`, `base`, `overlay0`, `text`). Escolher
uma cor repinta a prévia; só **Salvar no pack** grava, no pack que está no ar, e
roda o gerador para ele. A torrada diz se o desenho chega à tela, **medindo** o
tema: se algum ícone instalado tem a forma dele, a próxima passagem dos ícones o
troca; se nenhum tem (o desenho sem linha no `AUTORAL`), ela diz que o pack
mudou e a tela não.

### O seletor de ícone: o acervo do pack em edição, em pastas

No passo «Ícones», cada programa abre a ficha dele, e a ficha oferece os desenhos do
**pack em edição** e dos que ele herda, parando no primeiro pack do projeto (decisão 3):

| pasta | de onde |
|---|---|
| `apps/`, `biblioteca/`, autorais por flavor | cada pack, o que está no ar primeiro |
| traço, convertidos, convertidos · retoques | o pack-base, em traço (`icones.apps.recolorir`), por último entre os packs |
| enviados | o «Adicionar ícone» de quem usa, em `~/.local/share/meowsystem/icones-enviados/` |

Quem decide as pastas é uma função só, a `acervos_de_icone` do
`scripts/pack.py`; o servidor pergunta a ela, e o `tests/acervo-da-ficha.sh`
conta o disco contra ela. Os grupos são pack × `apps/`/`biblioteca/`; fica de
fora, de propósito, todo o `sistema/` (um ícone de pasta no lugar de um programa
no lançador seria engano). O PNG de uma pasta aparece num grupo à parte, travado.
A busca casa pelo nome do arquivo e, onde houver, pela descrição em português
do `catalog.json` da pasta (a biblioteca do Dracula e os resgatados têm um).

**A ficha marca o que veste o programa agora**, nesta ordem: a escolha de quem
usa, a linha do mapa do pack no ar, o traço. **Usar este ícone** grava a
escolha em `~/.config/meow/icones-escolhidos.map`, ao lado do `meow.conf`, e
nunca no pack nem no repositório: usar o produto não vira commit. O gesto que
leva uma escolha para dentro do pack é outro, **Levar para o pack**, explícito.

### A oficina

A oficina «Gerar ícone» de cada aplicativo mostra **todas** as origens que
existem para ele, lado a lado: *Original, Do pack, Salvo* e as variações em
traço. O cartão **Do pack** é o desenho de `icones/apps/` que casa com o
`Icon=` do aplicativo — pelo nome do arquivo ou por uma linha do `apps.map` —,
de **qualquer** pack no disco, com o nome do pack e se ele está no ar.

**Do pack vence por padrão:** é o cartão marcado quando a oficina abre, porque é
o desenho que alguém fez à mão para aquele aplicativo. Marcar não grava nada, e
quando o cartão do pack **não** é o que está na tela, a oficina diz quem está.
O «Usar» não grava arte de pack: o retoque, o construído e a linha dele vão
para o estado de quem usa (`~/.local/share/meowsystem/retoques/`,
`convertidos-apps/` e o `icones-convertidos.map` ao lado do `meow.conf`; decisão 28);
quem põe o desenho do pack na tela é o próprio pack.

`tests/oficina.sh` trava a regra: todo SVG de `packs/<id>/icones/apps/` que veste
um `Icon=` da máquina tem cartão na oficina daquele aplicativo. O teto é zero.

### O que **não** vai para o pack

Arte de ícone vai sempre para um pack. Fica no motor o que não é desenho:

| fica em `assets/` | por quê |
|---|---|
| `apps/appid.map`, `apps-nomes.map`, `wmclass.map`, `jogos-fora.map` | identidade técnica de aplicativo e decisão da máquina. Não é gosto, é fato |
| `apps/tray-terceiros/` | os originais de fábrica da bandeja da Steam e do ZapZap, para desfazer |
| `prompt/`, `fastfetch/`, `paleta/cosmic-map.json` | modelos que a paleta do pack no ar preenche: servem a todo pack |
| `contratos/` (`assets/contratos/`) | o que o programa sabe do COSMIC e dos vizinhos |

O mascote mora no pack (`mascote/`, com `mascote.dia` e `mascote.noite` no
`pack.json`), como os papéis de parede (`wallpapers/` e `origens.wallpapers`) e
os temas de aplicativo (`temas-de-apps/<app>/`). O código de cada aplicativo é
do programa: `scripts/temas-de-apps/<app>/`.

---

## Fonte e derivados

> *"Centralizar os SVGs — e alterando lá alteraremos o resto dos ícones que
> têm eles como base."*

Para isso valer, cada ícone precisa de **uma** fonte, e ela precisa morar no
repositório. O resto — o que o instalador põe no tema — é **derivado** dela, e
derivado não se edita: a próxima instalação apaga o retoque.

```
  packs/<id>/icones/apps/<nome>.svg     <- A FONTE. É isto que se edita.
            │
            └─ ~/.local/share/icons/MeowSystem-Icons/scalable/apps/<nome>.svg
                                           o vetor, como está
```

### As regras, e onde cada uma é cobrada

| regra | o que diz | quem cobra |
|---|---|---|
| 1. um nome, uma fonte | um nome de ícone tem **um** arquivo de onde sai. Duas fontes é erro, não precedência | `validar` (nome repetido no mapa), `pack.py fonte`, `tests/fonte-unica.sh` |
| 2. derivado não se edita | o que está no tema é calculado da fonte, na instalação | `meow_icones_derivar`, em `lib/icones.sh` |
| 3. derivado não se versiona | o git guarda a fonte; o derivado nasce no tema | a própria forma: nenhum derivado mora no repositório |
| 4. mapa não aponta para fora | alvo é pack, `motor:` ou `pack:` — `~/` e absoluto são recusados | `validar`, `pack.py alvo` |
| 5. arte de terceiro entra por cópia | copiada para dentro do pack, com uma linha no `PROCEDENCIA.md` | `tests/fonte-unica.sh` (o Waterfox) |
| 6. recolorir é por papel | `sujeito`, `tinta`, `fundo` resolvidos na paleta do flavor | `gerar_icones_autorais.py` — é por papel que o `alucard` ganhou os seus |
| 7. uma linha responde | `meow icones fonte <nome>` diz a fonte e o que deriva dela | `bin/meow` |
| 8. a cópia tem caminho de volta | `meow pack sincronizar <id>` compara cópia e origem, e **não copia** | `pack.py sincronizar` |

**A camada da regra 1 é `scalable/apps`.** É o diretório onde dois donos
disputam o mesmo arquivo: o mapa de aplicativos do pack ativo e o
`apps-resgatados.map` do motor escrevem lá, e um nome nos dois é o instalador
que rodar por último vencendo calado — e o `meow doctor` trocando um pelo outro
todo dia. O Arcticons e os convertidos moram no `48x48/apps`: um nome que
exista lá e aqui não é empate, é a precedência *"Dracula vence tudo"*, com um interruptor (`ICONES_DRACULA`) que devolve o
Arcticons sem apagar nada.

### Alterou o desenho, o tema se atualiza sozinho

Decisão 15: um SVG salvo numa das três pastas de qualquer pack de
onde o tema deriva (o no ar, os herdados, o pack-base), uma linha de mapa ou o
`logo.svg` chegam ao tema instalado em segundos, sem comando.

- **O vigia** é o `meow-derivados.path`, uma linha `PathModified=` por pasta
  (o `install.sh` a escreve, e reescreve ao trocar de pack), e o
  `meow-derivados.service` irmão roda o `scripts/derivados.sh`.
- **Uma função, idempotente.** A tabela `~/.local/state/meowsystem/derivados.tsv`
  guarda o sha256 de cada fonte na passada anterior; a passada refaz só os
  passos de quem mudou (os mesmos do instalador, que só reescrevem o que
  difere), reindexa a cache do tema e relê a tela uma vez no fim. Salvar de
  novo o mesmo conteúdo não escreve nada. O desenho apagado leva junto a cópia
  dele no tema (o arquivo com o sha256 que ele tinha).
- **A espera** de 2 s antes de comparar faz uma rajada de salvamentos virar uma
  passada só.
- **O doctor das 5h** confere a mesma tabela e refaz o que o vigia perdeu com o
  PC desligado.
- O tema não tem derivado raster: uma fonte SVG deriva `scalable`, e só ele (ver
  abaixo). O seletor do painel lê o disco a cada abertura.

### `meow icones fonte`

```
$ meow icones fonte net.waterfox.waterfox
fonte: packs/dracula/icones/apps/net.waterfox.waterfox.svg
deriva: scalable
       camada    pack:dracula  (ICONES_DRACULA="sim")
       scalable  ~/.local/share/icons/MeowSystem-Icons/scalable/apps/net.waterfox.waterfox.svg — igual à fonte
```

A fonte vem do `pack.py fonte`, que lê os mapas e recusa o empate. O `deriva`
vem do `meow_icones_derivados`, a mesma função que os dois instaladores da
camada chamam para escrever — então a tela não tem como prometer um derivado
que o instalador não faz. Sai 1 quando o nome não tem fonte em mapa nenhum, ou
tem mais de uma.

### Uma fonte SVG deriva `scalable`, e só ele

Das quatro famílias de derivado (o vetor, os PNG de 32 a 256, as variantes de flavor e o
corte de bandeja), **só a primeira tem para onde ir:**

- **Tamanhos.** O `index.theme` do MeowSystem-Icons declara dois diretórios de
  aplicativo, `48x48/apps` e `scalable/apps`, e os dois têm **zero** `.png`. O
  COSMIC rasteriza o vetor no tamanho pedido: `Type=Fixed` contra `Type=Scalable` dá zero
  pixel de diferença. Os PNG de 16 a 256 do Waterfox existem, mas no
  `Dracula-Icones`, que é tema de outro projeto, herdado pelo nosso e sombreado
  por ele. Pôr PNG no `48x48/apps` seria disputar arquivo com o
  `icones_apps_arcticons.sh`, que é o dono único daquele diretório.
- **Flavors.** Recolorir por papel é o `gerar_icones_autorais.py`, para os
  autorais de `icones/apps/`. Os desenhos de `icones/apps/` do Dracula declaram
  `recolorir: false`: cada um tem de 6 a 10 cores próprias.
- **Bandeja.** Tem mapa e instalador próprios (`bandeja.map`,
  `icones_bandeja.sh`), veste glifo Arcticons, e o mapa está vazio de propósito.

Quando uma dessas famílias ganhar consumidor, ela entra como uma linha no
`meow_icones_derivados` — e aparece no `meow icones fonte` sem ninguém lembrar
de mexer nele. **Raster não é fonte:** um PNG passado ao `derivar` é recusado
com 2, porque de um PNG não sai vetor, nem outro flavor, nem tamanho maior sem
borrar.

### O `PROCEDENCIA.md` do pack, e o `sincronizar`

Arte de terceiro entra no pack **copiada**, e não apontada: apontar para um diretório de
outro projeto é depender de algo que ele pode reescrever do zero.

Cada cópia ganha uma linha no `packs/<id>/PROCEDENCIA.md`:

```
| arquivo | de onde | lido de | licença | copiado em | sha256 |
|---|---|---|---|---|---|
| `icones/apps/net.waterfox.waterfox.svg` | `m4thewz/dracula-icons`, ramo `circle` — … |  | GPL-3.0 | 2026-09-23 | `a13118bd…` |
| `icones/biblioteca/guvcview.svg` | este repositório — `assets/icones/resgatados/guvcview.svg` | `pack:dracula:biblioteca/guvcview.svg` | a do pacote `guvcview` | 2026-09-17 | `085829f8…` |
```

`lido de` aceita `~/…`, `motor:…`, `pack:<id>:…` ou caminho absoluto, e é só **lido**. Para
publicar, a casa vai como `~/…`: um `/home/<nome>/…` ali é nome de usuário, e o
`validar` recusa (item 13 de [Validar antes de publicar](#validar-antes-de-publicar)).

**`lido de` vazio é só registro**. A origem fica escrita como
texto em `de onde`, o `sincronizar` confere que o arquivo existe no pack e não
abre nada fora dele. É o que o Dracula faz desde que a comparação com o
`Dracula_OS-Theme` foi aposentada — ele só existe na máquina de quem o escreveu,
e o `meow doctor` relia 364 arquivos dele a cada passada. Uma origem que só
existe numa máquina não é origem para comparar: é história, e vai em `de onde`.
A coluna fica, mesmo vazia: é a mesma tabela que o `exportar` lê para a licença.

O `sha256` é o da cópia no dia da cópia — o terceiro ponto que permite dizer
qual lado andou:

| a cópia | a origem | o `sincronizar` diz |
|---|---|---|
| = registro | = registro | em dia |
| = registro | mudou | a **origem** andou — imprime o `cp` e para |
| mudou | = registro | **retocada** aqui — a origem não a sobrescreve |
| = origem | ≠ registro | as duas iguais; só o registro ficou velho |
| mudou | mudou | as **duas** andaram |
| — | não está na máquina | fora de alcance; não é divergência |

**Ele não copia, e não tem opção que copie.** Uma arte retocada aqui depois da
cópia é trabalho de alguém, e um `git pull` de outro repositório não pode
apagá-la. Trazer a versão da origem é o gesto de quem decide: o `cp` que o
comando imprime, e o `sha256` da linha trocado. O `meow doctor` diz o mesmo como
**informação**, ao lado da tabela, e nunca como conserto — escolher entre o
retoque e o upstream é decisão de autor.

```bash
meow pack sincronizar dracula
#   ok   icones/apps/guvcview.svg
#
#   1 de 1 em dia com a origem · 366 só registro, sem origem a ler
```

A coluna `lido de` precisa ter a mesma extensão do `arquivo`: ela é dado de
quem escreveu o pack, e um pack de terceiro que apontasse para
`~/.ssh/id_ed25519` teria o `sha256` dele impresso na tela.

---

## Temas de aplicativo

O pack veste o COSMIC, os ícones e o terminal — e também o
**tema de dentro dos aplicativos**: o esquema de cor do Spotify, o `.qbtheme` do
qBittorrent, o tema do Obsidian.

> **`apps` não é `icones.apps`.** `icones.apps` são os **ícones** dos
> aplicativos. `apps` é o **tema de dentro** deles. As trilhas não colidem; quem
> lê o `pack.json` de cima para baixo, sim.

### Por que este bloco existe

O preço estava na tela: numa máquina cujo pack ativo é o **Dracula**, o módulo do
Obsidian anunciou *"Catppuccin Mocha já estava aplicado"*. O único dos oito que
"deu certo" foi o que aplicou o tema do **outro** pack e chamou de sucesso.

### O que se declara

```json fragmento
"apps": {
  "spotify":     { "spicetify_tema": "Sleek", "esquema": "Dracula" },
  "qbittorrent": { "arquivo": "apps/dracula.qbtheme", "sha256": "27948d…" }
}
```

| Campo | O que é |
|---|---|
| `arquivo` | caminho **dentro do pack** para a arte do tema. Volta resolvido em caminho absoluto |
| `sha256` | a integridade daquele arquivo. O `validar` a confere **na publicação** |
| `herda` | *"este aplicativo eu pego emprestado daquele pack"*. Vence a `heranca` do topo. Nenhum pack o usa hoje, e no Obsidian, no tema do VS Code e no Heroic ele não veste nada: o tema desses tem a cor escrita, e o módulo recusa o herdado dizendo *«sem tema neste pack»*. Os ícones do VS Code herdados ficam de fora do mesmo jeito, mas em silêncio: o tema do pack entra sem eles, e nenhuma frase diz por quê |
| o resto | nomes que o módulo daquele app entende — veja a tabela abaixo |

Os campos que cada módulo entende hoje:

| App | Campo | O que é |
|---|---|---|
| `spotify` | `spicetify_tema` | a pasta de `~/.config/spicetify/Themes` a usar. Só letras, dígitos, `.`, `_` e `-`, sem começar por `.` ou `-` |
| | `esquema` | a seção do `color.ini` daquele tema. Aceita `<flavor>` |
| | `acento_no_color_ini` | `true` só se o tema nomear as 26 cores como chaves |
| | `arquivo`, `sha256` | o `color.ini` de um tema que mora no pack; o módulo copia a pasta dele (`color.ini`, `user.css`, `LICENSE`) e vence a `origem` |
| | `origem` | de onde o tema desce: `tipo`, `repo` (`dono/repo`), `commit` (40 hex), `pasta` (sem `..`) |
| `qbittorrent` | `arquivo`, `sha256` | o `.qbtheme`, e a integridade dele |

`<flavor>` é expandido com o `FLAVOR` da máquina e, na falta dele, com o
`paleta.flavor_padrao` do pack ativo. É o mesmo marcador de
`cosmic.nome_da_paleta`.

Um campo que você declare e nenhum módulo leia aparece no aviso de **campo sem
leitor** do `validar`. É de propósito: o formato não aceita declaração morta em
silêncio.

### A herança é por aplicativo, não por campo

Quem responde é o **primeiro pack da cadeia que declara o bloco `apps.<app>`
inteiro**. Um campo que falte **dentro** de um bloco declarado é ausência — não
motivo para descer mais um degrau.

Se fosse por campo, um pack que declarasse `spicetify_tema` sem `esquema`
herdaria o esquema do vizinho, e o Spotify sairia com o tema de um pack e o
esquema de cor de outro. Divergência silenciosa é o que este formato inteiro
existe para evitar.

```bash
python3 scripts/pack.py app dracula apps.spotify.spicetify_tema
#   pack=dracula
#   valor=Sleek

python3 scripts/pack.py app meu-tema apps.qbittorrent.arquivo
#   pack=meowsystem            <- subiu pela herança, e a linha diz de quem
#   valor=…/packs/meowsystem/temas-de-apps/qbittorrent/catppuccin-mocha.qbtheme
```

### Ler o que está no ar antes de escrever

Esta é a metade que importa. **Antes de aplicar, o módulo lê o que o aplicativo
está vestindo agora.** Três saídas, e as três aparecem na tela:

| O que está no ar | O que acontece |
|---|---|
| **o tema do pack** | nada a fazer, e o log diz qual |
| **nada** | aplica |
| **um tema que não veio daqui** | **pergunta. Não sobrescreve** |

A terceira é a que torna visível ao programa o que a pessoa já fez à mão: um
`qBittorrent.conf` que já aponta para um tema não é «sem tema».

**A pergunta não pode travar o timer.** O instalador roda desatendido, de hora em
hora. Então ela só acontece quando há alguém: as duas pontas precisam ser
terminal, e mesmo assim a espera tem teto de 30 segundos. Fora da tela o caso
vira **pendência acionável** (`<app>-tema-de-terceiro`), o arquivo dele fica
intocado, e a linha espera na porta Cuidar.

Sobrescrever calado o tema que alguém escolheu à mão não conserta a divergência:
apaga a pessoa do processo.

### Para quem escreve um módulo

```bash
meow_app_tema_do_pack spotify.spicetify_tema   # SEM $( ) — veja abaixo
tema="$MEOW_APP_TEMA"                          # o QUE aplicar
de_quem="$MEOW_APP_TEMA_PACK"                  # QUEM respondeu

# O 5º argumento só entra no caminho que ESCREVE (o seu `meow_app_aplicar`).
# Sem ele a função nunca pergunta: diz o fato, registra a pendência e devolve 3.
meow_app_tema_no_ar spotify "$no_ar" "$tema" "$de_quem" pergunte
case $? in
  0) : ;;                       # já está no tema do pack
  1) : ;;                       # está sem tema: pode aplicar
  3) return 3 ;;                # tema de terceiro: não toque
esac
```

**`meow_app_tema_do_pack` não imprime nada, e chamá-la dentro de `$( )` devolve
vazio.** Ela responde duas coisas — o valor e a procedência —, e `$( )` é
subshell: a variável seria atribuída num processo que morre na mesma linha, e a
procedência chegaria vazia. O stdout fica mudo de propósito, para que o erro apareça na hora em vez de virar um `''` silencioso.
O `tests/temas-de-apps.sh` recusa o `$( )` num módulo migrado.

As duas funções andam juntas. Usar a primeira sem a segunda troca um defeito por
outro: o módulo passaria a aplicar o tema certo por cima do que a pessoa
escolheu.

O teto de citações por módulo está em `tests/temas-de-apps.sh`, e ele só desce.

---

## Trocar de pack: `meow pack usar`

```bash
meow pack usar dracula            # grava PACK e FLAVOR no meow.conf, e aplica
meow pack usar catppuccin latte   # com o flavor escolhido
meow pack usar meu-tema --sem-aplicar
```

O verbo é o mesmo que o botão **Vestir** da porta Tema do painel chama (decisão 33:
trocar de pack é um gesto só).

**O que ele faz, nesta ordem:**

1. **Valida o pack com a régua do motor** — a mesma que o instalador aplica. Um
   pack que ela reprova seria trocado pelo padrão em silêncio (o
   `meow_pack_dir` cai no Catppuccin e só avisa), então o verbo recusa **antes
   de escrever**: pack que não existe, pack fora das [raízes](#onde-um-pack-mora),
   flavor que o pack não tem. Capa e logo ausentes não impedem: o motor usa o
   pack sem eles.
2. **Escolhe o flavor.** O que você pediu; senão o que já está no ar, se ele
   for do pack (voltar ao Catppuccin estando no Latte não te joga no Mocha);
   senão o `paleta.flavor_padrao` do pack.
3. **Grava `PACK` e `FLAVOR`, e leva junto o que o pack de antes escolhia.**
   O `CURSOR` igual ao ponteiro do pack de antes vira o
   do pack novo, e o `ICONES_PASTAS` com o flavor de outro pack volta a
   acompanhar o pack: o pack decide, e quem usa pode fixar outro valor, que
   fica. A régua é a do `scripts/migrar_conf.py` (`vestigios`), a mesma do
   doctor. O resto do `meow.conf` fica intacto, comentários inclusive.
4. **Diz o que ficou de outro pack.** O `meow.conf` vence o pack (ver a seção
   seguinte), então um `ICONES_BASE="Dracula-Icones"` escrito por você continua
   valendo depois de `usar catppuccin`. O verbo não decide por você o que é
   gosto e o que é resto: ele lista as chaves que o painel marcaria como
   «Vestígio do pack» depois da troca — e é a **mesma** pergunta, feita à mesma
   função do painel, não uma cópia dela. Por isso um valor que o pack novo
   receita não entra: o `CURSOR="catppuccin-mocha-light"` de fábrica, com o
   Dracula no ar, é o que o `packs/dracula/pack.json` pede. Uma chave que o
   `meow.conf.exemplo` não tem, e que por isso não tem cartão no painel, entra
   na lista com esse aviso.
5. **Aplica** — o instalador inteiro, porque trocar de pack mexe em quase todas
   as etapas. `--sem-aplicar` grava e para. Na passagem, o lançador devolve o
   que o pack de antes escondia (`lancador.ocultar`) e esconde o que o novo
   pede, e o ponteiro do pack novo desce da rede se precisar, com o selo de quem
   baixa no painel (decisão 12).

**O ensaio ensaia a troca.** Com `MEOW_DRY_RUN=1` (ou o «Ver sem mudar» do
painel), o `meow.conf` não é tocado: as duas chaves vão para uma cópia
descartável, e o instalador seco lê a cópia. Um ensaio que lesse o conf do disco
mostraria o pack que **já** está no ar, com cara de ensaio da troca.

**Na tela**, a porta Tema abre com um cartão por pack instalado — o logo, a paleta
embaixo, o que ele traz de próprio e o que herda de quem —, e o que está no ar
tem o anel de acento. Com escolhas ainda não salvas na página, **Vestir**
pergunta antes: elas foram feitas olhando o pack de agora, e são descartadas
quando a troca de verdade começa — um «Ver sem mudar» não troca nada, e as
deixa como estavam até o «Rodar de verdade» da janela de resultado. E o passo Ícones passa a falar com as palavras do pack no ar:
a «Variante dos ícones de arquivo» de um pack que herda o acervo de mimetype
oferece o flavor que **ele** escolheu em `icones.mimetypes.flavor`, com o nome
do dono ao lado — `Macchiato (herdado do Catppuccin)` —, e não os quatro
sabores do Catppuccin soltos numa máquina vestida de Dracula.

---

## Quem vence: o pack ou o `meow.conf`

**O `meow.conf` da máquina sempre vence.** Sem exceção.

O pack diz *"para este tema, o ponteiro bom é este"*. O `meow.conf` diz *"nesta
máquina, o ponteiro é este"*. Quem mora na máquina decide.

| Chave do `meow.conf` | Campo do pack | Quem ganha |
|---|---|---|
| `CURSOR` | `origens.cursores.tema` | o conf — mas o valor que só repetia o ponteiro do pack de antes acompanha a troca |
| `ICONES_BASE` | `icones.base` | **o pack** — a chave não existe no `meow.conf.exemplo`, e o `migrar_conf.py` a tira de todo conf; ver abaixo |
| `ICONES_FLAVOR` | `icones.mimetypes.flavor` | o conf |
| `ICONES_PASTAS` | — | o conf |
| `ACCENT` | `paleta.acentos[0]` | o conf |
| `FLAVOR` | `paleta.flavor_padrao` | o conf |

Quando o conf está **vazio**, o valor do pack entra. Quando os dois existem e
discordam, o `meow pack info` mostra os dois e diz qual está valendo — silêncio
aqui seria a divergência silenciosa de volta, por outra porta.

**`CURSOR` é a exceção.**
`CURSOR` vazio **não toca no ponteiro** — é o jeito de desistir do tema sem
desinstalar nada ("Vazio = NÃO TOCA", no `scripts/cursor.sh`) —, e o `tema` de
`origens.cursores` nunca foi lido para aplicar coisa nenhuma: o único leitor
dele é o painel, que o usa para não acusar de "outro pack" o `CURSOR` que o
próprio pack receita. O que o pack faz
pelo ponteiro é **trazê-lo** (`origens.cursores.proprio`); quem o escolhe é
sempre a chave. Ver [O ponteiro](#o-ponteiro).

**`ICONES_BASE` não é escolha da máquina.** A base de ícones vem do pack, pinada, e o
`scripts/migrar_conf.py` tira a chave aposentada de todo `meow.conf` que ainda a tenha.
Ver [A base de ícones](#a-base-de-ícones).

---

## O tema do COSMIC, e o único passo manual que existe

Esta é a parte que você precisa saber antes de publicar.

**O COSMIC não tem CLI de tema.** A derivação que transforma o que a GUI edita
(`*.Builder/v1`) no que o sistema lê (`*/v1` e `*/v2`) mora dentro do aplicativo
gráfico. Medido: escrever em `Dark.Builder/v1/accent` não moveu
`Dark/v1/accent`, nem em 4 segundos nem depois, com o `cosmic-settings-daemon`
vivo. Não dá para reproduzir de fora.

A saída é **fotografar**: importar o tema uma vez pela GUI e capturar o
resultado inteiro. A partir daí, aplicar é copiar de volta — sem GUI, sem clique.

**E é por isso que o pack pode trazer a captura pronta.** Você paga o import
manual **uma vez, na sua máquina**, e todo mundo que instalar o seu pack recebe
o tema funcionando com zero cliques:

```bash
# 1. gere o .ron a partir da sua paleta
MEOW_PALETA=~/.local/share/meowsystem/packs/meu-tema/paleta.json \
  ./scripts/gerar_temas.py meutema-mauve

# 2. importe UMA vez:
#    Configurações > Área de trabalho > Aparência > Importar

# 3. fotografe — ele grava DENTRO do pack ATIVO, sozinho
MEOW_PACK_DIR=~/.local/share/meowsystem/packs/meu-tema \
  ./scripts/capturar_tema.sh meutema-mauve
#   ~/.local/share/meowsystem/packs/meu-tema/temas/capturados/meutema-mauve/

# 4. confira que o resolvedor a acha, e publique
MEOW_PACK_DIR=~/.local/share/meowsystem/packs/meu-tema \
  python3 scripts/pack.py captura meutema-mauve
```

**O `.ron` do passo 1 não vem no clone**: ele é produto de `gerar_temas.py`, e produto
gerado não entra no git. Sem `--saida`
ele nasce em `~/.local/state/meowsystem/temas/`.

**Quem diz qual é o pack ativo é `MEOW_PACK_DIR`, e não `PACK`.** A chave `PACK`
é do `meow.conf` e quem a lê é o shell (`meow_pack_dir`, em `lib/comum.sh`); o
`capturar_tema.sh` **não** carrega o `lib/comum.sh` — de propósito, está escrito
no cabeçalho dele — e fala direto com o `pack.py`, que só conhece
`MEOW_PACK_DIR`. Uma receita com `PACK=` na frente **não erra: ela acerta o
alvo errado**, grava a sua foto dentro de `packs/meowsystem/` do clone, e é
exatamente o *"pôr a foto do Dracula dentro do pack do Catppuccin"* que o
`pack.py` impede (dentro do pack-base). Medido:

```
$ env -u MEOW_PACK_DIR PACK=dracula python3 scripts/pack.py captura-destino meu-tema-mauve
<clone>/packs/meowsystem/temas/capturados/meu-tema-mauve
```

**Com o pack já ativo no `meow.conf`** (`PACK=meu-tema`, ou um `FLAVOR` com o
mesmo nome), a ponte já está montada e as duas linhas acima viram uma:
`meow tema capturar meutema-mauve` — o `bin/meow` chama o `meow_ponte_python`
na entrada e exporta o `MEOW_PACK_DIR` para você.

A captura é **portátil**: são ~176 arquivos de texto com caminhos relativos. O
`captura.txt` é metadado de procedência, e o `aplicar_tema.sh` o pula
explicitamente. A linha `origem:` diz `~/.config/cosmic` — de qual árvore a foto saiu, e
não de quem. O `capturar_tema.sh` o escreve depois
do `manifesto.sha256`, que então não o lista; o `gerar_tema_v1.py`, quando
refaz o manifesto, o inclui — quem editar o `captura.txt` de uma captura dessas
refaz a linha dele no manifesto, ou o `sha256sum -c` acusa.

Se o pack **não** trouxer captura, o MeowSystem não quebra: ele avisa e diz ao
usuário os três passos acima. Mas aí cada pessoa paga o custo, em vez de você
pagar uma vez.

---

## O som

Um pack pode trazer o próprio som de volume. **É um som só** — e a razão está
medida, não suposta.

O COSMIC quase não toca som. Varrendo os 41 binários `/usr/bin/cosmic-*`: `pw-play`
aparece em dois, `canberra` em nenhum (os três acertos no
`cosmic-initial-setup` eram a *cidade* Canberra, da lista de fusos). Quem toca é
o `cosmic-osd`, e o único evento que ele anuncia é a mudança de volume. O
`cosmic-notifications` **anuncia** a capacidade "sound" no `GetCapabilities` e
não tem reprodutor nenhum. Os sons de energia do `cosmic-settings-daemon`
procuram em `/usr/share/sounds/Pop/`, caminho cravado sem XDG — nem daria para
sobrescrever.

Então não existe "tema de som" a fazer aqui. Existe **um sino**, e o pack pode
escolher o timbre dele.

O som é **sintetizado na instalação**, nunca baixado: não há binário de áudio no
repositório e não há licença de terceiro para auditar. O pack declara números, e
o `scripts/som.sh` gera o WAV.

```json fragmento
"som": {
  "fundamental": 784.0,
  "harmonico": 932.3,
  "peso_fundamental": 0.58,
  "peso_harmonico": 0.32,
  "decaimento": 38.0
}
```

| Campo | Faixa | O que é |
|---|---|---|
| `fundamental` | 60 – 8000 | a nota de base, em Hz |
| `harmonico` | 60 – 12000 | a segunda senoide; o **intervalo** entre as duas é o caráter do som |
| `peso_fundamental` | 0 – 1 | quanto cada senoide pesa na mistura… |
| `peso_harmonico` | 0 – 1 | …e a **soma das duas precisa ficar ≤ 1** |
| `decaimento` | 5 – 200 | o expoente da queda. Maior = mais seco |
| `duracao` | 0.010 – 0.125 | em segundos |
| `ganho` | 0 – 0.40 | a intensidade |

**Os limites não são gosto.** Cada um tem uma razão que já custou caro:

- A soma dos pesos acima de 1 **satura**: o gerador corta a onda em ±1 e o
  resultado soa como estalo, não como sino.
- `duracao` acima de 0,125 s **empilha**: é o debounce do `cosmic-osd`. Quem
  segurar a tecla de volume ouve os sons um por cima do outro.
- `ganho` acima de 0,40 muda o **susto**, não o timbre. O default é calibrado
  contra o arquivo de fábrica (`ffmpeg -af volumedetect`: mean −30,7 dB / max
  −17,1 dB) justamente para que trocar o som não obrigue ninguém a reaprender o
  volume.
- `decaimento` abaixo de ~20 arrasta a cauda e o sino vira "blop".

O validador recusa qualquer um desses com o número e o motivo.

### Escolher um intervalo

O que dá caráter ao som não é a nota: é a distância entre as duas.

| Intervalo | `harmonico` para `fundamental` 880 | Como soa |
|---|---|---|
| Quinta justa | 1320 | resolvido, claro — é o do pack padrão |
| Terça maior | 1100 | alegre |
| Terça menor | 1046.5 | sombrio |
| Oitava | 1760 | neutro, quase um bipe |

O pack Dracula usa sol (784) com a terça menor acima (si bemol, 932.3): o mesmo
gesto de mexer no volume soa noturno, sem virar alarme. E o decaimento dele é
mais lento que o do padrão (38 contra 46) porque a terça menor precisa de um
instante a mais para ser reconhecida como intervalo — abaixo disso as duas notas
viram um clique só.

### Ouvir antes de decidir

```bash
SOM_FUNDAMENTAL=784 SOM_HARMONICO=932.3 SOM_DECAIMENTO=38 \
  ./scripts/som.sh aplicar && ./scripts/som.sh ouvir
```

No painel: **Manutenção → Som de evento**, com o botão «Ouvir».

E lembre da precedência: um `SOM_*` no `meow.conf` da máquina vence o do pack,
como qualquer outra chave.

## A base de ícones

O `MeowSystem-Icons` desenha uma parte dos ícones e **herda** o resto: é o
`Inherits=` do `index.theme` dele, e é o pack que diz qual base vai ali.

Um pack pode declarar a base dele. Ela não mora dentro do pack: um tema de
ícones completo são dezenas de milhares de arquivos de terceiro, e copiá-los
seria congelar a arte de alguém. O pack declara a **receita** — de onde, e qual
conteúdo exato —, e quem instala baixa e confere:

```json fragmento
"icones": {
  "base": {
    "origem": {
      "url": "https://github.com/dono/tema/archive/<commit>.tar.gz",
      "sha256": "…os 64 hex do pacote…",
      "pasta": "tema-<commit>"
    }
  }
}
```

- **`url`** é `https://` e termina em `.tar.gz`, `.tgz`, `.tar.xz` ou `.txz`: o
  arquivo que o GitHub gera para um commit, ou o asset de um release. Pinar pelo
  commit na URL é o que o arquivo do GitHub permite quando o ramo não tem tag.
- **`sha256`** é o do **pacote**, e é o pino: sem ele a URL entrega o que
  quiser.
- **`pasta`** é onde, no pacote aberto, está o tema (o diretório com o
  `index.theme`). Nome por nome, sem `..` e sem barra na frente.

**Quem instala é o `scripts/construir_icones.sh`**, porque ele é quem escreve o
`Inherits=`. O pacote desce para um temporário dentro de
`~/.local/share/icons/`, o sha256 é conferido, a pasta tem de ser um tema de
ícones e nenhum link pode apontar para fora dele — e só então ela entra, com um
`mv` só, em `~/.local/share/icons/MeowSystem-Icons-Base/`. O nome é deste
projeto, e não o do upstream: um diretório de dono único é o que deixa a troca
de pack levar a base junto, e o que impede de escrever por cima de uma cópia
que outra ferramenta tenha posto ali com o nome do upstream.

**A conferência de toda passagem é pelo conteúdo.** Ao lado do tema ficam o
`.meow-origem` (o sha256 do pacote de onde ele veio) e o
`.meow-somas.sha256` (o de cada arquivo). Um arquivo que some é percebido, e
a base volta inteira; nada mudou, nada é baixado. Sem rede, a base fica para o
próximo ciclo e o tema herda do que havia (a base de antes, ou o de fábrica).
Com o sha256 errado, a construção para e diz os dois números — é o arquivo
mudando debaixo do pino.

**Quem vence é o pack** (ver [Quem vence](#quem-vence-o-pack-ou-o-meowconf)); um pack sem
base herda a do pack de quem herda, e na ponta da cadeia o motor usa o
`Papirus-Dark`. A regra mora no `_base_escolhida` do `scripts/pack.py`, e o
`construir_icones.sh`, o verbo `base-icones` e o `info` leem dela. Quando a
base do pack não é a que vale, o diretório dela sai do disco.

**Camadas de trás: `por_tras`.** Uma base pode precisar de outra atrás dela,
para os nomes que a da frente não desenha. É o caso do Dracula (decisão 1): o ramo
`circle` dos `dracula-icons` vai na frente e o ramo `main` atrás,
como o tema Dracula de antes; só com o `circle`, 458 dos nomes `-symbolic`
caíam fora do tema. Cada camada é uma `origem` com a mesma forma, numa lista:

```json fragmento
"icones": {
  "base": {
    "origem":   { "url": "…/circle.tar.gz", "sha256": "…", "pasta": "…" },
    "por_tras": [ { "origem": { "url": "…/main.tar.gz", "sha256": "…", "pasta": "…" } } ]
  }
}
```

A primeira desce para `MeowSystem-Icons-Base`, a segunda para
`MeowSystem-Icons-Base-2`, e assim por diante, e o `Inherits=` do tema as lista
nessa ordem. `por_tras` só vale ao lado de uma `origem`, e não vazio.

**As bases não aparecem nos seletores.** O `index.theme` de toda base, a
instalada e a do tema exportado, leva `Hidden=true` (é da especificação de tema
de ícones do freedesktop): elas são camada do `MeowSystem-Icons`, e não um tema
para escolher. O desinstalador tira a `-Base` e todas as `-Base-<n>`.

**Herdar é pelo bloco**, como nas fontes: responde o primeiro pack da cadeia que
declara `icones.base.origem`, e `icones.base.herda` vence a `heranca`.

| o `validar` cobra | por quê |
|---|---|
| `url`, `sha256` e `pasta`, e só elas | a origem sem uma delas não diz o que baixar, ou não diz o que conferir |
| `https://`, terminando em `.tar.*` | quem instala abre um `.tar` e mais nada |
| o sha256 com 64 hex minúsculos | é o pino do conteúdo |
| a pasta sem `..`, sem barra na frente | ela vira caminho no disco de quem instala |
| `origem` e `herda` não aparecem juntas | um bloco que diz "baixe" e "use o do vizinho" não disse qual |

O `validar` não toca a rede: ele confere a forma, e o conteúdo é conferido byte
a byte na instalação.

```bash
python3 scripts/pack.py base-icones dracula
#   quem=pack
#   tema=
#   pack=dracula
#   url=https://github.com/m4thewz/dracula-icons/archive/00a230a2….tar.gz
#   sha256=563580916e42…
#   pasta=dracula-icons-00a230a2…
#   atras=https://github.com/m4thewz/dracula-icons/archive/de2a8edd….tar.gz  51db7832…  dracula-icons-de2a8edd…
scripts/construir_icones.sh base     # põe ou confere só a base, e diz de quem o tema herda
```

## O ponteiro

Um pack pode trazer o próprio ponteiro: um tema Xcursor comum, dentro dele.

```
packs/meu-tema/
  cursores/
    meu-tema-roxo/
      index.theme
      LICENSE               a licença de quem desenhou — ver "Licença", abaixo
      cursors/              default, left_ptr, pointer… (link vale, se ficar dentro)
```

```json fragmento
"origens": {
  "cursores": { "proprio": "cursores/meu-tema-roxo" }
}
```

**Quem escolhe continua sendo a chave `CURSOR`.** O pack oferece; o
`meow.conf` decide. Trocar de pack troca também o `CURSOR` que só repetia o
ponteiro do pack de antes (ver [Trocar de pack](#trocar-de-pack-meow-pack-usar)). Com `CURSOR="meu-tema-roxo"`, o `scripts/cursor.sh` instala
o tema do pack em `~/.local/share/icons/meu-tema-roxo-cursors/` **sem tocar a
rede**, e a cada passagem compara o instalado com o do pack (`diff -rq
--no-dereference`: o link é comparado como link, que é o que a cópia leva): se
você redesenhar o ponteiro, a passagem seguinte traz o novo; se nada mudou, ela
diz "idêntico" e não mexe. `CURSOR` vazio continua não tocando em nada, e um
`CURSOR` que nomeia outro tema continua valendo.

**O valor é o nome do diretório, sem `-cursors`.** `cursores/meu-tema-roxo/` e
`cursores/meu-tema-roxo-cursors/` são escolhidos pelo mesmo
`CURSOR="meu-tema-roxo"` — é a regra do `cursor.sh` para todo tema.

**Ele aparece no painel antes de estar instalado.** A lista de ponteiros é "o
que a chave aceita sem baixar nada", e o do pack é isso; a prévia sai do próprio
pack. A lista do painel (`_cursor_pastas_do_valor`, `app/servidor.py`) e a do
script (`_cursor_do_pack`, `scripts/cursor.sh`) fazem a mesma conta, e mudam
juntas.

**Um diretório de nome exato vence o pack.** Se `meu-tema-roxo/` existir em
`~/.local/share/icons/`, `~/.icons/` ou `/usr/share/icons/`, as duas alavancas
do `cursor.sh` apontam para ele. Nesse caso o ponteiro do pack sai da lista, em vez de
virar um botão que baixa da rede.

| o `validar` cobra | por quê |
|---|---|
| o caminho cai dentro do pack, e existe | o `realpath` de todo campo |
| o nome só tem `[A-Za-z0-9._-]`, sem começar por `.` ou `-` | é o nome que vira diretório. O `cursor.sh` trocaria qualquer outro caractere, e o painel ofereceria um nome que o script instala com outro |
| `cursors/` existe e tem `default` ou `left_ptr` | é o ponteiro de repouso: sem ele não há o que ver, nem de onde tirar a prévia |
| nenhum arquivo ou link do tema aponta para fora dele | o tema é copiado inteiro (`cp -a`), e o link iria junto para `~/.local/share/icons/` |
| todo link do tema leva a um arquivo que existe | o ponteiro que o link promete não existe, e o instalador reinstalaria o tema em toda passagem, sem convergir |
| `proprio` e `herda` não aparecem juntos | um bloco que diz "o meu" e "o do vizinho" não disse qual |

**Herdar é pelo bloco.** `origens.cursores.herda: "outro"` sobe para o pack
`outro`; sem `proprio` nem `herda`, vale a `heranca` do pack. O `meow pack info`
diz até onde a subida chega — `CURSOR="x", do pack y`, ou "a cadeia não traz
ponteiro".

```bash
python3 scripts/pack.py ponteiro meu-tema
#   pack=meu-tema
#   dir=/…/packs/meu-tema/cursores/meu-tema-roxo
#   valor=meu-tema-roxo
```

**Licença.** Tema de ponteiro é arte de terceiro quase sempre. O `LICENSE` e o
`AUTHORS` vão dentro do diretório do tema — o `cursor.sh` os copia junto, e a
auditoria funciona na máquina de quem instalou —, e o `CREDITOS.md` do pack diz
de onde ele veio. Sem procedência, não entra.

### O ponteiro que se baixa

Quando o tema não cabe no pack, o pack declara de onde ele desce, com a mesma
forma da [base de ícones](#a-base-de-ícones) e um campo a mais, `nome` — o valor
que a chave `CURSOR` escreve para escolhê-lo:

```json fragmento
"origens": {
  "cursores": {
    "origem": {
      "nome": "Dracula-Cursor",
      "url": "https://github.com/dracula/gtk/releases/download/v4.0.0/Dracula-cursors.tar.xz",
      "sha256": "81780e218fdda616016aedf42e731c86ed16290b9753a21616642023821b85f5",
      "pasta": "Dracula-cursors"
    }
  }
}
```

É o caso do Dracula. O tema cabe em tamanho, mas 66 dos 113
ponteiros dele são links, e um pack que carrega link é recusado pelo
`exportar`: um pack viaja com cópias. O pacote pinado é o que o `cursor.sh` já
fazia com o `catppuccin/cursors`.

Com `CURSOR="Dracula-Cursor"`, o `cursor.sh` baixa o pacote, confere o sha256,
confere que a pasta tem `cursors/` e nenhum link para fora, e instala em
`~/.local/share/icons/Dracula-Cursor-cursors/` — com o nome que a chave usa, e
não com o de dentro do pacote. Um diretório de nome exato continua vencendo:
onde `Dracula-Cursor/` já existe, nada é baixado. **Ele não entra na lista do
painel antes de instalado**, porque a lista é "o que a chave aceita sem baixar
nada" — o valor funciona escrito no `meow.conf`, como o de um ponteiro do
`catppuccin/cursors`. `origem` vem sozinha no bloco: nem com `proprio`, nem com
`herda`.

## As fontes

Um pack pode trazer fontes de texto. Elas **somam** às do motor: a
JetBrainsMono Nerd Font pinada continua sendo instalada, e continua sendo a do
terminal, para todo pack.

```json fragmento
"fontes": {
  "proprio": [
    { "arquivo": "fontes/MinhaFonte-Regular.otf" },
    { "nome": "OutraFonte-Bold.ttf",
      "url": "https://exemplo.org/releases/v1.2/OutraFonte-Bold.ttf",
      "sha256": "…os 64 hex do arquivo…" }
  ]
}
```

- **`arquivo`** mora dentro do pack. O `realpath` cai dentro dele, e os quatro
  primeiros bytes têm de ser TrueType ou OpenType: extensão não é conteúdo.
- **`nome` + `url` + `sha256`** vêm de fora, e sempre os três. Só `https://`, e o
  conteúdo é pinado, como o da Nerd Font. A URL aponta para **um arquivo de
  fonte**, e não para um `.zip`: pacote se abre pelas mãos de quem instala
  (`meow fontes adicionar`); um pack instala sozinho, e o que entra sozinho é o
  que se confere byte a byte.
- O nome vira arquivo em `~/.local/share/fonts/MeowSystem/pack/`: termina em
  `.ttf` ou `.otf`, sem barra, sem começar por `.` ou `-`. Dois iguais na lista
  são recusa.

**Trocar de pack leva as fontes junto.** `MeowSystem/pack/` é de dono único: o
`scripts/instalar_fontes.sh` deixa ali só o que o pack ativo declara, e tira o
resto. Uma lista que não valida não apaga nada — o erro do pack não é culpa da
máquina. Sem rede, a fonte de fora fica para o próximo ciclo; com o `sha256`
errado, o instalador para e diz os dois números.

**Herdar é pelo bloco inteiro.** Responde o primeiro pack da cadeia que declara
`fontes.proprio`, e a lista dele é a lista — uma fonte não "falta" e desce ao
vizinho. `fontes.herda` vence a `heranca`. `"proprio": []` é "este pack não traz
fonte, e não herda".

**Escolher a fonte do terminal não é isto.** O pack põe a fonte no sistema; o
terminal e o `monospace_font` do COSMIC continuam apontando para a Nerd Font do
motor. Um campo "a fonte do terminal é esta" é outra decisão, e não existe.

```bash
python3 scripts/pack.py tipografia meu-tema
#   meu-tema  MinhaFonte-Regular.otf  /…/packs/meu-tema/fontes/MinhaFonte-Regular.otf  -
#   meu-tema  OutraFonte-Bold.ttf     https://exemplo.org/…/OutraFonte-Bold.ttf      <sha256>
```

> **`tipografia`, e não `fontes`.** O verbo `fontes` do `pack.py` é o de ícone
> — "de onde sai cada ícone", ver [Fonte e derivados](#fonte-e-derivados). A
> chave do `pack.json` é `fontes`, que é como quem escreve um pack procura; o
> verbo não podia ser.

## O que ainda não é do pack

Três coisas continuam do **motor**, iguais para todo pack, e o formato **não tem campo**
para elas. O mascote é do pack (decisão 19), em `mascote/`.

| categoria | de onde sai | quem teria de perguntar ao pack |
|---|---|---|
| **traço do gerador de ícone** | `scripts/converter_icone.py` e as réguas da oficina | ver abaixo |
| **prompt** | `assets/prompt/` | `scripts/prompt.sh` |
| **fastfetch** | `assets/fastfetch/` | `scripts/fastfetch_logo.sh` |

**Declarar sem leitor não serve.** Um `"prompt": {"proprio": …}` que nenhum
script lê é o campo morto que o `validar` avisa em voz alta: o pack prometeria
um prompt, e a tela mostraria o de sempre. Cada uma destas entra no dia em que
o leitor dela perguntar ao pack, e não antes.

**O traço do gerador não é o `icones.autorais`.** É declarável **o que** o gerador de
autorais desenha (os `.json` de [Desenhos
autorais](#desenhos-autorais)). O **traço** da conversão — espessura, fusão,
aparo, cantos, se preenche área — continua nos padrões do `converter_icone.py`
e nas réguas da oficina, por dois motivos (o `estilo_icone.py` só MEDE a caneta; ele não tem
parâmetro nenhum):

- os padrões do conversor produzem os convertidos de `packs/meowsystem/icones/apps/`, que é
  **versionado no pack-base** — quase todas as linhas do `apps-convertidos.map` deixam o
  campo de parâmetros vazio, e usam o padrão.
  Um padrão vindo do pack ativo faria o acervo do git depender de qual pack
  estava no ar quando alguém o reconstruiu;
- a oficina grava no mapa a string exata dos parâmetros
  (`--k 8 --funde 52 --tol 1`) e conta com "régua em zero = bandeira ausente =
  a saída de ontem" para que a linha reproduza o desenho gravado ao lado dela.
  Um padrão vindo do pack mudaria o que a ausência significa.

Fazer direito é levar o acervo convertido para dentro do pack e fazer a oficina
começar as réguas do perfil do pack. O que segura o item são essas duas
decisões de desenho — onde mora o acervo que hoje é do git, e o que a régua em
zero passa a significar. O limite: **só os parâmetros que a oficina já aceita, com nome**. Nada de expressão, nada de condicional.

## As categorias, uma por linha

`meow pack info <id>` imprime **todas** as categorias, e cada uma diz o que é
naquele pack:

| origem | quer dizer |
|---|---|
| `PRÓPRIO` | o pack declara o bloco |
| `HERDADO de X` | o bloco diz `herda: X`, ou o pack não declara e a `heranca` dele é X |
| `DO MOTOR, ou inexistente` | o pack não declara e não herda: vale o que o motor faz, se faz |
| `DO MOTOR — não declarável` | o formato não tem campo — ver [O que ainda não é do pack](#o-que-ainda-não-é-do-pack) |

A coluna da direita diz até onde a subida chega: as categorias de ícone contam
desenhos, o ponteiro diz o valor de `CURSOR` e o pack que o traz, as fontes
dizem quantas e de quem, e as não declaráveis dizem de onde saem. `HERDADO` com
"a cadeia não traz" ao lado é a herança vazia, dita em voz alta.

```
  icones.base       PRÓPRIO                      github.com/m4thewz/dracula-icons, sha256 563580916e42…, do pack dracula, +1 por trás
  cursores          PRÓPRIO                      CURSOR="Dracula-Cursor", do pack dracula, baixado de github.com/dracula/gtk
  wallpapers        PRÓPRIO                      13 desenho(s) SVG, rasterizados em PNG 4K ao semear (scripts/wallpaper.sh)
  som               PRÓPRIO
  fontes            DO MOTOR, ou inexistente
  gerador           DO MOTOR — não declarável    scripts/converter_icone.py
```

(Seis linhas do `meow pack info dracula`.)

**O som não sobe a herança.** O `scripts/som.sh` lê só o `som` do pack ativo e
põe os padrões dele no que faltar; um pack que herda do Dracula e não declara
`som` toca o sino do motor. A tabela diz `DO MOTOR` para ele, e não `HERDADO`.

**Os papéis de parede do pack.** O bloco `origens.wallpapers` tem leitor: o install semeia
da origem que ele declara (decisão 23), o `wallpaper.sh` rasteriza os SVG de
`origens.wallpapers.desenhos`, e o `meow pack info` diz `PRÓPRIO` e quantos são. Só a
coleção do pack no ar gira (decisão 25).

Na linha da [base de ícones](#a-base-de-ícones), a coluna da direita diz de onde ela desce
e de quem.

## O logo do pack

Todo pack tem um `logo.svg` na raiz, e ele é **a cara do pack** — o que o
separa de outro pack de paleta parecida. É obrigatório para publicar: o `meow pack
validar` recusa pack sem ele.

**Cobrado de quem publica, nunca de quem usa.** O tema de um pack sem logo, ou
com um logo recusado, continua no ar: o instalador, a paleta, o som e a sonda
que diz se o pack existe não olham o logo: um pack íntegro em todo o resto não pode
fazer o desktop voltar ao padrão por causa de uma figura que só o cartão e o lançador
mostram. Quem
cobra é o `meow pack validar` (e o `meow pack listar`, que o chama); quem
mostra o logo confere o arquivo por conta própria — ver abaixo.

**Por que um logo, e não a tira de cores.** Tira de cor é paleta, não identidade: dois packs de paleta parecida ficam indistinguíveis. O logo é a
cara; a tira continua existindo — embaixo dele, fina, como **amostra** da
paleta.

**A capa da vitrine é este arquivo, e o campo é um só.** Quando o `pack.json`
tem `vitrine.capa`, é ele que diz onde o logo mora; sem o campo, vale
`packs/<id>/logo.svg` — que é também o valor que o campo recomenda. Um
`vitrine.logo` ao lado de um `vitrine.capa` seriam duas verdades para a mesma
figura, e elas divergem no dia em que alguém atualiza só uma.

**Quadrado, com `viewBox`** — `viewBox="0 0 128 128"` é o que os dois packs
daqui usam. O mesmo arquivo serve ao cartão em vários tamanhos e ao lançador,
que pede 48, 64, 128 e 256. Desenhe pensando em **48 px**: é o tamanho em que
ele mais aparece, e ali um detalhe de 1 px some.

### As cores vêm da paleta, por papel

Nenhuma forma do logo precisa de hex. Cada forma diz, na `class`, o **papel**
que cumpre, e o MeowSystem resolve o papel para uma cor da paleta do pack — a
mesma regra que o `scripts/gerar_icones_autorais.py` cumpre no cabeçalho dele
(*"o desenho nasce da paleta — nenhum hex é digitado aqui"*), levada para um
arquivo que é dado:

| `class` | pinta | com |
|---|---|---|
| `fundo` | `fill` | `base` |
| `tinta` | `fill` | `text` |
| `sujeito` | `fill` | o accent (`ACCENT`; `mauve` na falta) |
| `traco-fundo`, `traco-tinta`, `traco-sujeito` | `stroke` | o mesmo papel, no traço |
| um dos 26 nomes (`pink`, `surface1`…), e `traco-<nome>` | `fill` / `stroke` | aquela cor, para quem precisar de uma quarta |

É isso que faz o logo **acompanhar o flavor claro sem redesenho**: no claro o
`text` escurece e o `base` clareia, e o logo descrito por papel se inverte junto.
Medido nos dois logos daqui: o do Dracula resolvido no `alucard`
sai com `#4A4F67`, `#853AF2` e `#F0F0F6` — as três da paleta do alucard,
**nenhuma** do latte —, e o `sujeito` fica acima de 4,5:1 contra o `fundo` nos
quatro flavors conferidos (5,90 no dracula, 4,76 no alucard, 8,07 no mocha,
4,79 no latte).

Um logo sem papel nenhum, com hex fixo, **não é recusado**. Ele só fica igual em
todo flavor.

### O bloco `meow-papeis` é prévia, não fonte

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <style id="meow-papeis">.fundo{fill:#282A36}.sujeito{fill:#BD93F9}</style>
  <rect class="fundo" x="4" y="4" width="120" height="120" rx="28"/>
  <path class="sujeito" d="…"/>
</svg>
```

Sem ele, o arquivo aberto cru — no editor de SVG, na prévia do git — é um
quadrado preto: forma sem `fill` é preta, e quem desenha precisa ver cor. Então
o arquivo leva o bloco resolvido para o `flavor_padrao`, e o MeowSystem o
**reescreve** a cada resolução. O que vale é a `class`; mudar a cor dentro do
bloco não muda nada fora do seu editor.

Por isso quem **mostra** o logo — o cartão do pack, o ícone do lançador — não
abre o arquivo cru nem o serve direto a um `<img>`. Pergunta:

```bash
python3 scripts/pack.py logo dracula                  # o FLAVOR do ambiente, ou o padrão do pack
python3 scripts/pack.py logo dracula alucard          # um flavor dado
python3 scripts/pack.py logo dracula alucard pink     # e um accent dado
```

A resposta sai pelo stdout, e resolver duas vezes não muda um byte. O verbo
**confere o arquivo antes de devolvê-lo**, com as mesmas regras do `validar`
(abaixo): como o motor não cobra o logo, é essa conferência que impede um logo
com `<script>` de chegar à tela vindo de um pack que nunca passou pelo
`meow pack validar`. Sem logo, ou com um recusado, ele sai 1 — não há o que
mostrar, e o tema segue no ar.

### Pack sem logo não fica sem cara

```bash
python3 scripts/pack.py logo-gerado meu-tema > ~/.local/share/meowsystem/packs/meu-tema/logo.svg
```

A inicial do nome, em traço, sobre o `base` do pack, com o accent de contorno.
Feio e honesto é melhor que ausente — e é ponto de partida: abra, redesenhe,
mantenha as `class`.

- **O verbo só imprime.** Quem põe o arquivo no pack é você, com o `>`: o
  MeowSystem não escreve dentro de pack, e sobrescrever um logo que alguém
  desenhou seria o erro que não se desfaz com Ctrl+C.
- **A letra é caminho, e não `<text>`.** Texto depende de fonte, e quem desenha
  ícone de tema no COSMIC é o resvg, que só desenha texto quando recebe um banco
  de fontes. Uma inicial que some em um renderizador é o logo vazio que esta
  regra veio proibir. Há um glifo por caractere com que um `id` pode começar —
  `[a-z0-9]`.
- **A inicial é a primeira letra ou algarismo do nome.** Símbolo na frente é
  pulado (`* Nord` dá `N`), e o acento cai na letra base (`Árvore` dá `A`). Se
  essa letra não tem glifo — `Ωmega`, `日本` —, a inicial vem do `id`, e não da
  segunda letra do nome: `m` não é a inicial de `Ωmega`.

### O que o `validar` cobra do logo

As mesmas regras valem no `meow pack validar` e no verbo `logo`, que é a porta
de quem mostra.

- **existe, e mora no pack** — um link simbólico para fora é recusado;
- **é SVG de verdade**: texto, XML, raiz `<svg>` no namespace do SVG. PNG
  renomeado não passa;
- **`viewBox` quadrado**;
- **sem `<script>`, e sem atributo `on…`** (`onload`, `onclick`) — é script com
  outra roupa;
- **sem `<image>`, `<feImage>` ou `<foreignObject>`** — um logo é vetor, e os
  três são portas para imagem ou HTML dentro dele;
- **nenhuma referência para fora dele**: `href` e `url(…)` só como `#id`, e nada
  de `@import`. Não é só a URL remota: o logo é **copiado** para fora do pack —
  para o tema de ícones, para o cartão —, e lá um caminho relativo quebra. E as
  portas laterais da mesma coisa — nas três primeiras, medido no Chromium, o
  navegador busca o arquivo remoto:
  - o CSS é lido **como o navegador o lê**: `@IMPORT` em maiúscula e os escapes
    (`@\69mport`, `u\72l(`) contam como `@import` e `url(`, e `image-set()`,
    que aceita a URL como texto, é recusado;
  - **nenhuma instrução de processamento** — `<?xml-stylesheet href="…"?>` busca
    folha de fora, e o navegador a segue. Só a declaração `<?xml …?>` do topo;
  - **nenhum elemento do HTML** dentro do SVG: fora de um `<foreignObject>` ele
    não desenha nada, e ainda assim um `<img src>` busca a imagem;
  - **nenhuma animação do `href`** (`<set attributeName="href" to="…">`): ela
    não busca nada sozinha, mas é o link trocando de destino depois de
    conferido;
- **sem `<!ENTITY>`** — nenhum desenho precisa, e uma entidade que se expande
  em si mesma trava quem lê. Quem lê é também o verbo `logo`, a porta de quem
  mostra; ele não pode travar.

### O que ainda não existe, e ninguém deve ler como pronto

- **O ícone do lançador é o logo.** O `scripts/atalho.sh` escreve
  `Icon=com.meowsystem.Painel`, e o `completar_icones.sh` instala esse nome a partir do verbo
  `logo` do pack no ar, com o autoral como rede.
- **O cartão do pack na porta Tema** (ver [A vitrine](#a-vitrine)) mostra o que
  `logo <id> <flavor_padrao>` responde — não o arquivo cru, que não passou pela conferência.
  Um logo que o verbo recusa não vira imagem: o cartão diz o motivo.
- **`logo-mono.svg`**, a versão de traço único para barra e bandeja, não entrou:
  nada no projeto o leria, e um arquivo declarado sem leitor é a promessa vazia
  que o `validar` avisa em voz alta.

## O que um pack não pode fazer

Um pack é **dado**. Nunca é código.

- **Nenhum arquivo executável é lido de um pack.** Não existe `ganchos.sh`, não
  existe script de instalação. O único subsistema do MeowSystem que aceita shell
  de terceiro é `scripts/temas-de-apps/*/manifesto.sh`, e ele tem contrato
  próprio, é carregado em subshell e é coberto por `tests/reversao.sh`. Um pack
  que precise de comportamento entra por ali, não por aqui.
- **Todo caminho declarado é resolvido com `realpath` e precisa cair dentro do
  pack.** `../` não escapa.
- **Todo `destino` é conferido contra uma lista fechada** de subdiretórios de
  tema conhecidos.
- **Toda URL precisa ser `https://`.**
- **O MeowSystem nunca escreve dentro de um pack.** O que sai do pack e chega ao
  seu sistema passa por `meow_escrever` (`lib/comum.sh`), que registra caminho e
  `sha256` no manifesto — é isso que faz o `--uninstall` saber desfazer.

**Tudo o que vem de um pack é dado não confiável**, e a
regra tem um lugar só em cada linguagem, que todo leitor usa:

- **caminho**: o `realpath` cai dentro da raiz permitida, link simbólico que
  aponta para fora é recusado, e nome de destino é de um conjunto fechado. A
  forma conferida é a mesma que se usa. Um alvo de `apps.map` que sai da raiz
  recusa o **pack inteiro** (a máquina veste o padrão); uma linha de mapa com
  nome torto é pulada e contada (decisão 41);
- **nome de flavor**: só `[a-z0-9_]`, em `flavors` e em `claros` — o nome vira
  pasta e chave do `meow.conf`, e `..` ou `a/b` recusam o pack inteiro;
- **texto**: nome, autor, descrição, tags e nome de desenho saem sem caractere
  de controle antes de chegar ao terminal (`meow_texto_seguro`);
- **desenho**: SVG e PNG de acervo chegam ao painel com `Content-Security-Policy`
  `default-src 'none'; style-src 'unsafe-inline'; sandbox` e `nosniff`, e nunca
  entram no DOM da página: um `<script>` dentro de um SVG não roda;
- **temas de aplicativo**: o modelo de kitty e o de GNOME Terminal de um pack só
  levam chave de cor; o que manda executar alguma coisa é pulado e contado;
- **extensão do VS Code**: só os packs que vêm com o MeowSystem (`packs/` do
  repositório) instalam a extensão que pedem. Um pack importado mostra a
  extensão, com o selo, e ela só se instala por um gesto naquela extensão, pelo
  id, da loja oficial (decisão 9). Uma extensão é código que roda
  a cada abertura do editor, e o sha256 de um pack prova integridade, não
  confiança.

O `tests/pack-malicioso.sh` monta um pack de terceiro com `..`, caminho absoluto,
link para fora, script e SVG com `<script>`, e confere que nada é lido nem
escrito fora da raiz e que nada executa.

---

## Validar antes de publicar

```bash
meow pack validar ~/.local/share/meowsystem/packs/meu-tema
```

Os verbos, todos em `scripts/pack.py` — o **único** arquivo deste projeto que
abre um `pack.json`:

| verbo | o que responde |
|---|---|
| `validar <id-ou-caminho>` | confere o pack inteiro. 0 = ok, 1 = recusado |
| `info <id>` | a vitrine no alto; depois o que é próprio, o que é herdado, categoria a categoria |
| `usar <id> [flavor]` | o `PACK` e o `FLAVOR` que o `meow pack usar` vai gravar — **não escreve**; recusa antes |
| `remover <id> [--seco]` | tira da sua casa de packs um pack que você importou; recusa o pack no ar, os que vêm com o MeowSystem e o que outro pack herda. Ver [Tirar um pack](#tirar-um-pack-meow-pack-remover) |
| `caminho <id> <categoria>` | o caminho que aquela categoria resolve **no pack** |
| `acervo <id> <categoria> [arquivo]` | o mesmo, subindo pack → herança → motor |
| `paleta <id>` | o arquivo de paleta daquele pack |
| `logo <id> [flavor] [accent]` | o `logo.svg`, com as cores resolvidas por papel para aquele flavor |
| `logo-gerado <id> [flavor] [accent]` | o logo gerado, para o pack que ainda não tem — **só imprime** |
| `de-csv <arquivo.csv>` | o `paleta.json` de um CSV `slot,flavor,hex`, com o claro derivado se faltar — **só imprime**. Ver [Começar por um CSV](#começar-por-um-csv) |
| `som <id>` | o timbre do pack, como `CHAVE=valor` para o shell |
| `raizes` | as três raízes de busca, na ordem |
| `padrao` | o diretório do pack **padrão** |

`padrao` existe para que o nome do pack padrão more num lugar só.

Ele confere, nesta ordem, e **para no primeiro erro**:

1. `pack.json` é JSON válido e tem os campos obrigatórios
2. `formato` é suportado
3. `id` casa com o nome do diretório
4. a paleta existe, é JSON e tem `ordem_canonica`, `flavors`, `nomes`, `claros`
5. **cada flavor tem os 26 slots** — e o erro **nomeia os que faltam**, todos de
   uma vez, não um por vez
6. todo hex é `#RRGGBB`
7. `flavor_padrao` existe na paleta
8. **todo arquivo prometido existe.** São cinco campos que nomeiam arquivo —
   `paleta.arquivo`, `icones.*.mapa`, `icones.*.desenhos`, `cosmic.mapa` e
   `creditos` —, e todos são abertos, não só olhados. Ou crie o arquivo, ou tire o campo
9. todo caminho declarado está dentro do pack (resolvido com `realpath`)
10. todo `herda` aponta para um pack que existe
11. nenhuma URL fora de `https://`
12. **contraste**: `text` sobre `base` precisa passar em WCAG AA (4.5:1) — 26
    hexes aleatórios passam em tudo acima e produzem uma interface ilegível
13. **nenhum nome de usuário**: nenhum arquivo de texto do
    pack traz `/home/<nome>/` ou `/Users/<nome>/`. A recusa diz o arquivo e a
    linha, todas de uma vez. `~/…` passa — diz "a casa de quem lê" sem dizer
    de quem —, e ficam de fora o binário (byte nulo nos primeiros 8000 bytes,
    a pergunta do git) e o oculto, que o `exportar` não leva. Cobrado só pelo
    verbo `validar`, como o 14 e o 15: um pack pessoal com o próprio caminho
    num `PROCEDENCIA.md` continua vestindo o desktop. O `exportar`, o
    `importar` e o `novo` (com ou sem `--de-csv`) rodam o `validar` inteiro, e
    a herdam sem uma linha a mais
14. **a vitrine** — a capa existe, é SVG e está dentro do pack; a frase curta
    cabe em 80 caracteres; a descrição é um `.md` do pack; o `site` é
    `https://`. Cobrado só pelo verbo `validar`, como o 15: o instalador e o
    painel usam um pack de vitrine quebrada assim mesmo. A exceção é o `site`
    em `http://`, que já caiu no 11 — e o 11 vale para o motor. Ver
    [A vitrine](#a-vitrine)
15. **o logo**: `logo.svg` existe, é SVG quadrado, sem script, sem imagem
    embutida e sem nada que aponte para fora dele. Cobrado só pelo verbo
    `validar`: o instalador usa o pack sem logo assim mesmo — ver
    [O logo do pack](#o-logo-do-pack), que diz cada regra e o porquê. Depois
    da vitrine, e de propósito: o logo é o arquivo que `vitrine.capa` nomeia, e
    é o 14 que diz, antes, se o campo aponta para um SVG que existe

A validação roda de novo dentro do `meow_preflight`, **antes** de o instalador
escrever qualquer coisa. Um pack quebrado não chega a tocar no seu desktop.

### O campo que ninguém lê: aviso, nunca silêncio

Antes do `ok`, o validador imprime **quais campos aquele `pack.json` declara e
nenhuma linha deste projeto consulta**:

```
  aviso 9 campo(s) que este pack declara e NENHUM código lê:
          icones.apps.camada
          origens.wallpapers.tipo
          …
        Eles não quebram nada — e também não fazem nada: nenhuma linha deste
        projeto os consulta.
```

**Por que existe.** Um campo sem leitor parece fazer alguma coisa e não faz. Um formato que aceita declaração
morta ensina a escrever declaração morta: quem copia um `pack.json` repete os
campos mortos acreditando que eles fazem alguma coisa.

**É aviso, e não recusa.** Um campo sem leitor hoje pode ser o campo que a
versão seguinte vai ler, e recusar por causa dele quebraria packs que já
funcionam. O que não pode é o silêncio.

**Campo que comece com `_` não é cobrado** — `_nota`, `_comentario`,
`_nota_heranca` são prosa do autor do pack, e cobrá-las seria punir quem
documentou.

O `packs/meowsystem/` sai **limpo** deste aviso, de propósito: ele é o primeiro
`pack.json` que alguém copia, e declarar ali um campo sem leitor ensinaria a
promessa vazia antes de ela ter conserto.

---

## Publicar

Um pack é um diretório, e o jeito de mandá-lo a alguém é **um arquivo só**, o
`.meowpack`:

```bash
meow pack novo meu-tema                     # um pack seu, a partir do que está no ar
meow pack exportar meu-tema                 # escreve meu-tema.meowpack aqui mesmo
```

E quem recebe:

```bash
meow pack importar meu-tema.meowpack        # confere tudo, e só então instala
```

O pack importado vai para `~/.local/share/meowsystem/packs/<id>/` — a raiz 2,
"o seu". **Importar não troca o tema:** é ganhar uma opção. O `importar`
termina dizendo o que pôr no `meow.conf` para vestir o pack:

```bash
PACK="meu-tema"
FLAVOR="dracula"          # o flavor_padrao do pack — uma palavra só, sem hífen
ACCENT="mauve"
```

Depois, `meow ativar`.

Um repositório git continua valendo — `git clone https://exemplo/meu-tema
~/.local/share/meowsystem/packs/meu-tema` e `meow pack validar meu-tema`. O
que o `.meowpack` dá a mais é **a conferência do outro lado**: um clone chega
como veio; um `.meowpack` só chega se passar por tudo o que está abaixo.

### `meow pack novo`: o pack que começa pelo que está no ar

```
$ meow pack novo meu-tema
  ok   Meu Tema (meu-tema) — formato 1, 2 flavor(s), 26 slots conferidos
  ok   <raiz>/packs/meu-tema/
       a partir do 'dracula': a paleta (2 flavor(s), padrão dracula), o timbre, um logo gerado e os créditos
  --   o resto vem do 'dracula' pela herança — meow pack info meu-tema diz o quê
  --   papel de parede e ponteiro não entram: o formato ainda não tem onde guardá-los dentro de um pack
```

| o que entra | de onde |
|---|---|
| `paleta.json` | a paleta que vale **agora** — o arquivo inteiro, cada flavor com as 26 cores. O `flavor_padrao` é o flavor em uso. Inteiro, e não só o flavor em uso, porque o claro é o par dele: sem ele, o modo claro cairia no pack anterior |
| `som` no `pack.json` | o timbre do pack no ar, com os `SOM_*` do `meow.conf` por cima — o que se ouve. Ele é copiado porque o `som` não é herdado |
| `logo.svg` | gerado: a inicial do nome sobre o `base` (ver [O logo do pack](#o-logo-do-pack)) |
| `CREDITOS.md` | escrito pelo verbo, dizendo de que pack tudo veio |
| `heranca` | o pack no ar, **por id**. Ícones, capturas do tema, temas de aplicativo, ponteiro: tudo o que não está declarado vem dele. Nenhum caminho absoluto, e nenhuma segunda cópia do mesmo acervo para defasar calada |

Ele escreve em `packs/<id>/` do projeto — onde a sprint o pôs, e de onde um pack
se publica por commit —, ou em `$MEOW_PACKS/<id>/` quando essa variável existe
(a raiz de teste). **Recusa** um id que já exista em qualquer raiz: escrever por
cima é o erro que não se desfaz com Ctrl+C.

**`meow pack novo <id> --de-csv <arquivo>`** troca o ponto de partida: a paleta
é a do CSV, a herança é o pack padrão, e nada vem do que está no ar — nem o
timbre. Ver [Começar por um CSV](#começar-por-um-csv).

**O que ele não leva, e por quê.** Os acervos que a pessoa adicionou fora do pack (papéis
de parede, ponteiro) ficam: copiá-los sem leitor seria criar arquivo morto, que o
`validar` existe para denunciar. O verbo diz isso na tela em vez de fingir.

### O `.meowpack`

Um `.tar.zst` com o diretório do pack e, ao lado, um `MANIFESTO`:

```
MANIFESTO
meu-tema/pack.json
meu-tema/paleta.json
meu-tema/…
```

```
meowpack 1
formato 1
pack meu-tema
b29515d8…  CREDITOS.md
4af4db0d…  logo.svg
…
```

`meowpack` é a versão do **arquivo**; `formato` é a do `pack.json` (a do topo
deste documento). Os dois mudam por motivos diferentes. As linhas de `sha256`
têm a forma do `sha256sum`, relativas ao diretório do pack — dentro dele,
`sed 1,3d ../MANIFESTO | sha256sum -c` confere tudo sem o MeowSystem.

O tar não carrega dono (`uname` vazio): o nome de quem exportou é nome de
pessoa, e nenhum nome de usuário vai junto.

### O que o `exportar` cobra

Exportar é publicar, e ele recusa — dizendo o arquivo — antes de escrever:

1. **o pack que não valida**, pelo `meow pack validar` de sempre, inteiro, com
   vitrine e logo. Um segundo validador aqui aprovaria o que o primeiro
   recusa, e o arquivo seria recusado na máquina de quem o recebe;
2. **o pack sem `CREDITOS.md`** (ou sem o arquivo que o campo `creditos`
   nomeia). Arte de terceiro não é reempacotada sem dizer de onde veio; se
   tudo é seu, ele diz isso;
3. **a arte do `PROCEDENCIA.md` sem licença.** O exportar lê a mesma tabela que
   o `sincronizar` (ver [Fonte e derivados](#fonte-e-derivados)), e a coluna
   `licença` vazia, `?` ou `—` é arte que ninguém disse que pode sair;
4. **script e link simbólico** — `.sh`, arquivo que abra com `#!`, link. As
   entradas ocultas (o `.git/` de um clone, que é uma pasta de scripts) ficam
   de fora, e a saída diz quantas.

**O tamanho vem dito antes**, e as imagens raster (`.png`, `.jpg`, `.webp`) em
separado. Se há imagem e há terminal, ele pergunta se elas vão junto — com o
teto de 30 segundos da casa; sem terminal, elas vão, e a saída diz que
`--sem-imagens` as deixa. Sem as imagens, a `vitrine.capturas` **da cópia** as
esquece e a cópia passa pelo `validar` de novo: um pack que declara uma captura
que não traz é recusado do outro lado. O pack de origem não muda um byte.

Se o pack herda de outro que **não** vem com o MeowSystem, o exportar avisa:
quem importar precisa ter aquele também.

### O tema montado: `meow pack exportar-tema`

```bash
meow pack exportar-tema dracula              # o flavor padrão do pack
meow pack exportar-tema dracula alucard tema.tar.gz
```

O `exportar` leva a **receita** (o pack); quem a recebe precisa do MeowSystem
para ver um ícone. O `exportar-tema` leva o **tema de ícones
montado**, num `.tar.gz` pronto para `~/.local/share/icons/` de qualquer
máquina: o tema com o nome do pack e do flavor (`MeowSystem-Dracula-Icons`), a
base que o pack traz (`-Base`) e as camadas de trás dela (`-Base-<n>`). As bases
vão com `Hidden=true`, para não aparecerem como tema nos seletores, e o tema
herda as bases, depois `Cosmic` e `Adwaita`, e por fim o `hicolor` — o que falta
numa máquina sem COSMIC é ignorado, e não quebra a herança.

Ele é montado do zero numa casa temporária, com o pack e o flavor pedidos e o
resto de fábrica: nenhuma escolha do `meow.conf` de quem exporta viaja junto, e
nada é escrito fora do arquivo que ele entrega.

### O que o `importar` recusa

Um `.meowpack` vem de fora, e fora é onde mora quem não leu este documento.
**Um pack é dado, nunca é código** — e na importação isso é conferido, não
prometido. Tudo acontece na memória; o disco só é tocado depois:

| recusa | por quê |
|---|---|
| **um `.sh`, ou qualquer arquivo que comece com `#!`** | é script, seja qual for o nome. O pacote inteiro é recusado, com uma linha por arquivo |
| caminho absoluto, `..`, entrada fora de `<id>/`, dois packs num arquivo | um tar escreve onde o nome manda |
| link simbólico, dispositivo, tudo o que não é arquivo comum | um pack é feito de arquivos |
| entrada oculta | o `exportar` não as gera |
| o `MANIFESTO` que não bate — arquivo a mais, a menos, ou `sha256` diferente | o arquivo mudou depois de exportado |
| `meowpack` ou `formato` maiores que os deste MeowSystem | um pack novo num MeowSystem velho falha dizendo o número |
| mais de 256 MB **aberto**, ou mais de 20.000 arquivos | o zstd reduz zeros a quase nada: o teto é do que abre, não do que chega |
| o pack que não passa no `validar` inteiro | as 26 cores, `https://` em toda URL, todo caminho dentro do pack, nome de flavor só com `[a-z0-9_]`, a herança existindo nesta máquina |
| um id que já existe em **qualquer** raiz | por cima trocaria o que está lá sem perguntar; noutra raiz, um dos dois sumiria da vista |

E o que passa **nasce 0644**, seja qual for o modo que o tar peça: nada do que
chega ganha bit de execução. O pack é montado num diretório oculto ao lado,
validado, e só então renomeado para o lugar — não existe instante com meio
pack na raiz.

`meow pack importar arquivo.meowpack --seco` (ou `MEOW_DRY_RUN=1`) faz tudo
isso num temporário e diz o que o pack traz — a paleta, quantos ícones, de onde
vêm ponteiro, papel de parede e som — sem escrever nada. É o que a tela de
confirmar do painel mostra.

### Tirar um pack: `meow pack remover`

```bash
meow pack remover meu-tema          # tira ~/.local/share/meowsystem/packs/meu-tema
meow pack remover meu-tema --seco   # diz o que sairia, e o tamanho; não apaga nada
```

O avesso do `importar`.

**Só sai o que mora na sua casa de packs**, `~/.local/share/meowsystem/packs/<id>/`
— a raiz 2, que é onde o `importar` grava. **Tirar um pack não troca o tema**:
é perder uma opção, e para tê-la de volta basta importar o arquivo dele outra
vez. E o verbo **recusa** três casos — sai 1, diz o porquê, e não toca em nada:

| recusa | por quê |
|---|---|
| **o pack no ar** — o que o `PACK` e o `FLAVOR` do `meow.conf` vestem, pela mesma conta do `meow_pack_dir`, e também o que a chave `PACK` nomeia mesmo sem validar | sem ele no disco, o próximo aplicar vestiria o pack padrão, calado. Troque antes, com o **Vestir** de outro cartão ou o [`meow pack usar`](#trocar-de-pack-meow-pack-usar) |
| **os que vêm com o MeowSystem** — os de `packs/` do projeto | a casa deles é o repositório, e não a sua. A regra é pela raiz, e não por nome: o próximo pack que o projeto publicar nasce protegido, sem ninguém vir a esta tabela |
| **o que outro pack herda** — pela `heranca` ou por um `herda` de qualquer bloco, lido cru, mesmo de um pack que não valida por outro motivo | o herdeiro passaria a ser recusado pelo `validar` sem que você tivesse tocado nele. Remova o herdeiro primeiro |

**Sai inteiro, ou não sai.** A pasta é renomeada para um oculto ao lado (no
mesmo disco o `rename` é atômico, e quem procura pack não vê oculto) e só então
apagada: um Ctrl+C no meio deixa o resto no oculto, e nunca meio pack com um
`pack.json` que o `validar` recusaria.

Quem decide é uma função só, a `remocao` do `scripts/pack.py`: o terminal a
pergunta pelo `cmd_remover`, e o painel pela mesma função — é ela que acende o
**Remover** no cartão da porta Tema, e que cerca o argumento da ação `pack_remover`.
O cartão de um pack que não pode sair não ganha o botão: diz o motivo na linha
de baixo, com as palavras da tabela acima. O **Remover** passa pela caixa de
confirmar de todo gesto que desfaz alguma coisa, com o «Ver sem mudar», que é
o `--seco`.

### No painel

**Abrir um tema**, na porta Tema, e **Baixar o tema**, no passo Mandar de Criar tema,
chamam estas duas rotas:

| rota | o que faz |
|---|---|
| `GET /api/pack-exportar?id=<id>` | o `.meowpack`, para baixar. `&imagens=nao` deixa as imagens; `&medir=1` roda o exportar em ensaio e devolve o tamanho e as imagens, em JSON. Recusa volta como `{erro}` e 400, nunca como arquivo |
| `POST /api/pack-importar` | `{nome, conteudo}` em base64. Sem `confirmado`, é o `--seco`: devolve `precisa_confirmar`, `titulo`, `resumo` (uma frase) e `pack` (o que ele traz). Com `confirmado: true`, instala e devolve `instalado` e `frase`. Nas duas, nada é aplicado |

**Baixar o tema** pede o `medir` primeiro: a recusa (licença, `CREDITOS.md`,
`validar`) aparece antes de qualquer pergunta, e quando o pack tem imagem a
caixa diz quantos MB ele tem com e sem elas, com "levar as imagens junto"
marcado — o `[S/n]` do terminal. Só então baixa. **Abrir um tema** abre a
caixa de confirmar com a paleta desenhada, cada flavor com as 26 cores, e uma
linha para ícones, papéis de parede, ponteiro e som; a mensagem de que entrou
só aparece quando a rota diz `instalado`. Ele aceita também um **`.csv`** de
cores: a rota o reconhece pelo `nome`, o pack é montado pelo mesmo
`meow pack importar` — que monta como o `novo --de-csv` —, e a caixa mostra
ainda o claro derivado, como derivado, e a régua de contraste, sem bloquear.
Ver [Começar por um CSV](#começar-por-um-csv).

Quem confere e quem instala é o **mesmo** `meow pack exportar`/`importar` do
terminal — as rotas só levam o arquivo de um lado para o outro. Uma segunda
leitura do tarball no servidor seria a porta que ninguém conferiu.

### Antes de publicar, confira

- [ ] `meow pack validar` passa
- [ ] `CREDITOS.md` nomeia a origem e a licença de cada acervo de terceiro
- [ ] `licenca` no `pack.json` é compatível com a de tudo que você empacotou
- [ ] a captura do tema está no pack (senão, diga no `LEIA-ME.md` que não está)
- [ ] `heranca` está escrita, mesmo sendo o default
- [ ] nenhum caminho absoluto, nenhum `~` no que o pack declara (campos do
      `pack.json`, mapas) — e nenhum nome de usuário em arquivo nenhum: este
      o `validar` cobra, recusando a linha de texto com `/home/<nome>/` ou
      `/Users/<nome>/` (item 13 de [Validar antes de publicar](#validar-antes-de-publicar)).
      Numa nota de procedência, `~/…` passa
- [ ] o `logo.svg` é seu, e as formas declaram papel na `class` em vez de hex

Este repositório traz **dois** packs, e eles ensinam coisas diferentes:

- **`packs/meowsystem/`** é o pack **padrão** (o Catppuccin) — o mínimo honesto. Só campos com
  leitor, a paleta de quatro flavors e um acervo de glifos. É o que todo pack
  herda quando não declara.
- **`packs/dracula/`** é o exemplo completo: uma paleta, dois acervos de ícone,
  um acervo de papel de parede declarado por chave de conf, e tudo o mais
  herdado — com cada herança dita na cara.

Se for copiar um para começar o seu, copie o **meowsystem**: o do Dracula declara campos
que ainda não têm leitor, e o `validar` diz quais são.

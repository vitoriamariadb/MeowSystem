# Theme packs

Um **theme pack** é um diretório que diz ao MeowSystem que cores usar — e, se
quiser, que ícones, que papéis de parede e que agente. O MeowSystem lê o pack e
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

**"Padrão" e não "embutido", e a palavra mudou com o código.** Até 22/09/2026 o
Catppuccin não era um pack: era uma constante no `scripts/pack.py` apontando
para um arquivo dentro de `assets/`. Ele não tinha `pack.json`, não aparecia na
varredura do `meow pack listar` (havia uma linha de código só para ele aparecer)
e não tinha onde declarar nada — e por isso o `dracula` herdava sete categorias
de um lugar que não podia declará-las. Hoje ele é `packs/catppuccin/`, com
`pack.json`, e passa pelas mesmas regras que o seu pack vai passar. É essa a
promessa do formato: ele descreve **todos** os temas, inclusive o de casa.

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
  em minúsculas. Um CSV exportado com BOM (o Excel e o LibreOffice fazem isso)
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

```bash
meow pack de-csv minhas-cores.csv > ~/.local/share/meowsystem/packs/meu-tema/paleta.json
```

O verbo **só imprime**, como o `logo-gerado`: quem põe o arquivo no pack é você,
com o `>`. Aponte o `>` para um arquivo novo — um CSV recusado não imprime JSON
nenhum, e o `>` já terá esvaziado o destino. Montar o pack inteiro de uma vez,
`meow pack novo <id> --de-csv <arquivo>`, **ainda não existe**: o `novo` nasce
na sprint P11, e ligar o `--de-csv` nele — e o `.csv` na tela de importar — é
pendência da P16, que fez esta tradução. Até lá, o pack se monta à mão, com os
três arquivos do fim desta seção.

**Se o CSV traz só flavors escuros, o claro é derivado** — do primeiro flavor
do CSV, que é o que vira o `flavor_padrao` —, pelo método da subseção [Se o seu
tema não tem um claro](#se-o-seu-tema-não-tem-um-claro), e não por outro. Ele se
chama `<flavor>claro` (uma palavra só: nome de flavor não tem hífen) e **diz que
foi derivado**: a paleta ganha o campo

```json
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
`pack.json` disser de quem:

```json
{
  "formato": 1, "id": "meu-tema", "nome": "Meu Tema",
  "heranca": "catppuccin",
  "paleta":  { "arquivo": "paleta.json", "flavor_padrao": "meutema" },
  "vitrine": { "capa": "logo.svg" }
}
```

Sem `heranca`, ícones, ponteiro e papéis de parede não sobem para pack nenhum.
Com ela, o `meow pack info` e o cartão dizem categoria a categoria o que veio de
onde — `próprio: paleta · herdado de catppuccin: …` —, para ninguém achar que
ganhou menos do que ganhou. O `logo.svg` sai do [`logo-gerado`](#pack-sem-logo-não-fica-sem-cara).

---

## As 26 cores

A paleta é um JSON com os mesmos campos de `packs/catppuccin/paleta.json`:

```json
{
  "ordem_canonica": ["rosewater", "flamingo", "pink", "mauve", "red", "maroon",
                     "peach", "yellow", "green", "teal", "sky", "sapphire",
                     "blue", "lavender", "text", "subtext1", "subtext0",
                     "overlay2", "overlay1", "overlay0", "surface2", "surface1",
                     "surface0", "base", "mantle", "crust"],
  "claros": [],
  "nomes":  { "meu-tema": "Meu Tema" },
  "flavors": {
    "meu-tema": {
      "base": "#282A36", "text": "#F8F8F2", "mauve": "#BD93F9",
      "…": "as 26, sem exceção"
    }
  }
}
```

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

Derive um, e confira contra o Latte. Foi o que o pack `dracula` fez em
19/09/2026 para ganhar o `alucard`, e o método cabe em três regras:

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
| `assets/` | **o que o MeowSystem É** — o motor | `assets/paleta/cosmic-map.json`, `assets/icones/autorais/`, `assets/gatos/` |
| `packs/` | **o que ele VESTE** — o tema | `packs/dracula/paleta.json`, `packs/catppuccin/icones/mimetypes/` |
| `~/.local/state/meowsystem/` | **o que a máquina GEROU** — e não volta para o git | os `.ron` do COSMIC, os backups, o log |

**A pergunta que separa as duas primeiras:** *este arquivo continuaria fazendo
sentido se o tema fosse outro?* O `cosmic-map.json` sim — ele é o molde, e não
tem um hex dentro. A paleta do Catppuccin não — ela **é** o tema.

**O par mais fácil de errar** morava no mesmo diretório até 22/09/2026:
`assets/paleta/cosmic-map.json` é motor e `assets/paleta/catppuccin.json` era
tema. Eram irmãos de pasta e foram para lados opostos da linha — o segundo é
hoje `packs/catppuccin/paleta.json`.

**Quem cobra a regra é `tests/arvore.sh`**, e ele pergunta ao `git ls-files`, e
não ao disco. Medir o disco já custou caro: o `du` disse que o acervo de ícones
do Catppuccin tinha 13 MB (são 413 KB — o bloco de 4 KB mentindo sobre milhares
de SVG minúsculos) e que `assets/icones/upstream/` tinha 96 MB versionados,
quando ele tem **zero** arquivos no git.

### As duas exceções, e elas são escritas

**`assets/temas-de-apps/`** tem nome de flavor dentro e **fica**: são os temas
que os *outros* aplicativos publicam — o `dracula.css` do Heroic, o
`catppuccin-mocha.theme` do btop —, baixados do upstream deles e conferidos por
SHA256. O nome do tema está no arquivo do terceiro, não num arquivo nosso. É
contrato próprio, com manifesto próprio.

**`assets/temas/capturados/original/`** é a única captura que não mora num pack,
e ela não é tema de pack nenhum: é o **molde** do esquema `v1` que o COSMIC de
04/2026 escrevia (o `scripts/gerar_tema_v1.py` deriva dela, chave por chave) e o
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
  logo.svg                  OBRIGATÓRIO para publicar, desde 23/09/2026 — quadrado, cores por papel
  LEIA-ME.md                a história do pack, em texto (vitrine.descricao)
  capturas/                 fotos de tela, se quiser (vitrine.capturas)
  CREDITOS.md               a procedência de cada acervo — obrigatório se houver arte de terceiro
  cosmic-map.json           opcional: substitui o molde do tema do COSMIC
  icones/                   MESMA FORMA para as quatro categorias — ver a seção própria
    apps.map                "nome-do-ícone : caminho/relativo.svg"
    apps/                   os desenhos referidos pelo mapa
    pastas.map              pastas/
    pastas/                 folder-documents.svg, folder-download.svg…
    mimetypes.map           "nome-freedesktop : glifo"
    mimetypes/<flavor>/     o acervo por tipo de arquivo (é grande: ~656 por flavor)
    autorais/               <nome>-<flavor>.svg — sem mapa: o nome É o pareamento
                            <nome>.json — a declaração de um desenho (ver "Desenhos autorais")
  apps/
    <tema>.qbtheme                   os temas de DENTRO dos aplicativos — ver a seção própria
    PROCEDENCIA.md                   obrigatória quando a arte é de terceiro
  cursores/<nome>/cursors/  o ponteiro do pack (origens.cursores.proprio) — ver "O ponteiro"
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

```json
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
    "flavor_padrao": "meu-tema",
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
    "pastas":    { "desenhos": "icones/pastas/" },
    "mimetypes": { "herda": "catppuccin", "flavor": "macchiato" },
    "autorais":  { "gerar": true }
  },

  "origens": {
    "cursores":   { "proprio": "cursores/meu-tema-roxo" },
    "wallpapers": { "tipo": "github-arvore",
                    "repo_do_conf": "WALLPAPER_SEMENTE_REPO",
                    "commit_do_conf": "WALLPAPER_SEMENTE_COMMIT",
                    "se_vazio": "herdar" }
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
o ponteiro, ou `{"herda": "<id>"}` para o que pega o de outro — ver [O
ponteiro](#o-ponteiro). **`fontes`** tem a mesma forma, com uma lista — ver [As
fontes](#as-fontes).

**`autor`, `versao` e `licenca`** aparecem no alto do `meow pack info`, e o
`autor` também no cartão do painel. Até 23/09/2026 nenhum código lia os três, e
o `validar` os listava como campo morto.

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
está vazia.

---

## A vitrine

Ninguém escolhe um tema por um `id`. Até 23/09/2026 um pack era isso e 26
hexadecimais, e a tela que escolhe um pack não tinha o que desenhar. O bloco
`vitrine` é o que o pack diz de si para quem vai escolher:

```json
"vitrine": {
  "capa": "logo.svg",
  "descricao_curta": "O roxo do Dracula, com o gato do MeowSystem.",
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

**A capa é o logo.** O mockup de 21/09/2026 desenhava a capa como uma tira de
cores, e isso foi corrigido: tira é paleta, não identidade — dois packs de
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
  descrição : O roxo do Dracula, com o gato do MeowSystem.
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
| 3 | **o motor** | o acervo de `assets/`, para quem ainda não migrou |

```bash
python3 scripts/pack.py acervo dracula icones.apps.mapa
#   packs/dracula/icones/apps.map

python3 scripts/pack.py acervo dracula icones.mimetypes.desenhos
#   packs/catppuccin/icones/mimetypes/   <- subiu pela herança
```

**A herança do bloco vence a do pack inteiro.** O Dracula declara
`heranca: "catppuccin"` no topo **e** `icones.mimetypes.herda: "catppuccin"` no
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

**A regra cabe numa frase: o mapa é do pack; o acervo pode ser do motor.**

Um pack diz *"o Telegram veste o desenho X"* — isso é **decisão de tema**, e vai
para o pack. O desenho X pode vir do acervo Arcticons, que é ferramenta
compartilhada e fica onde está. O que não pode é a decisão morar em `assets/`.

### A forma é a mesma para as quatro categorias

```
packs/<id>/icones/
  apps.map          apps/         quais aplicativos, e os desenhos
  pastas.map        pastas/
  mimetypes.map     mimetypes/<flavor>/
                    autorais/     os desenhos do projeto, por flavor
```

**`autorais/` não tem mapa, e é de propósito:** o nome do arquivo *é* o
pareamento. `cosmic-term-mocha.svg` diz, sozinho, qual ícone e qual flavor — um
mapa ao lado seria uma segunda verdade sobre a mesma coisa, e ela divergiria na
primeira renomeação. As outras três precisam de mapa porque o nome que o sistema
pede (`application-x-cd-image`) não é o nome do desenho (`cd`).

Cada categoria declara os dois no `pack.json`, e nenhuma é obrigatória:

```json
"icones": {
  "apps":      { "mapa": "icones/apps.map", "desenhos": "icones/apps/" },
  "mimetypes": { "mapa": "icones/mimetypes.map", "desenhos": "icones/mimetypes/" },
  "autorais":  { "desenhos": "icones/autorais/" }
}
```

O `validar` cobra a existência de tudo o que estiver declarado, nas quatro. Um
pack que promete um acervo e não entrega é recusado — pelo mesmo motivo que o
`creditos` é cobrado: um validador que carimba a promessa vazia ensina a
escrevê-la.

### `motor:` — apontar para o acervo do motor sem copiá-lo

Um alvo de mapa pode sair do pack, **com prefixo declarado**:

```
org.telegram.desktop          : motor:arcticons/telegram.svg
io.github.flattool.Warehouse  : apps/Warehouse.svg
```

| forma | resolve em |
|---|---|
| `motor:<caminho>` | `assets/icones/<caminho>` — o acervo do motor |
| `pack:<id>:<caminho>` | `<pack id>/icones/<caminho>` — o acervo de **outro** pack (desde 23/09/2026) |
| sem prefixo | dentro do pack, contra o diretório do próprio mapa |

São três casas, e só três. `~/…` e caminho absoluto são **recusados** pelo
`validar`, com a frase que diz por quê — ver [Fonte e derivados](#fonte-e-derivados).

**É isto que permite tirar a decisão de `assets/` sem duplicar o acervo.** Sem o
prefixo só havia duas saídas, e as duas eram ruins: ou a escolha fica em
`assets/` (e trocar de pack não troca a escolha), ou cada pack carrega uma
**cópia** dos 113 SVG do Arcticons — e a segunda cópia defasa da primeira
calado, que é a lição que este projeto já pagou uma vez.

Os dois lados têm guarda: um alvo que **saia** da raiz dele é recusado, com o
motivo no stderr. Um mapa é dado, e um pack de terceiro escreve o dado dele.

```bash
printf 'motor:arcticons/telegram.svg\n' \
  | python3 scripts/pack.py alvo packs/dracula/icones
#   <raiz>/assets/icones/arcticons/telegram.svg
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
#   packs/dracula/icones/autorais/     — mesmo antes de o diretório existir
```

### Os autorais, e o flavor que caía no pack do vizinho

Os desenhos de `icones/autorais/` nascem **por papel**, nunca por hex digitado:
cada forma declara `sujeito`, `tinta`, `fundo`, e o papel resolve na paleta
**daquele flavor**. É o que faz um flavor novo nascer sem redesenho.

> **Todo flavor da sua paleta precisa dos seus.** Um flavor declarado que não
> tem desenho nenhum no acervo cai, calado, no acervo de quem o pack herda — e
> aí o modo claro do seu tema mostra o claro **de outro pack**. Foi o que
> aconteceu com o `alucard` entre 19 e 22/09/2026: ele tinha zero dos onze, e os
> onze do modo claro do Dracula vinham do `latte` do Catppuccin.
>
> `tests/pack.sh` trava isso: um flavor vazio ao lado de um irmão cheio é
> achado, em qualquer pack.

Gerar os de um pack é uma linha:

```bash
MEOW_PACK_DIR=packs/dracula python3 scripts/gerar_icones_autorais.py
```

### Desenhos autorais

Até 23/09/2026 o gerador abria dizendo *"Desenha os ícones dos DOIS aplicativos
da Vitória: FogStripper, Hefesto"*. Um gerador bom — nasce da paleta, por papel,
e sobrevive ao flavor claro — que servia dois aplicativos **nomeados no Python**.
Um terceiro não entrava sem editar código, e um pack de terceiro não tinha como
trazer desenho nenhum.

Agora **o desenho é um arquivo do pack.** Cada `icones/autorais/<nome>.json` é
um desenho, no vocabulário que o gerador já usava por dentro:

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
    "</svg>"
  ]
}
```

- **O nome vem do arquivo.** `hefesto.json` gera `hefesto-<flavor>.svg`, um por
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

**A herança vale para ler.** O Dracula não tem `fogstripper.json`: as duas
declarações moram no Catppuccin, e o Dracula as alcança pela `heranca`. Quem
escreve é sempre o pack em casa — o `fogstripper-alucard.svg` nasce em
`packs/dracula/icones/autorais/`, da paleta do Dracula. Uma declaração no pack
vence a herdada de mesmo nome.

**`desenhos` continua sendo um diretório**, e a spec da P26 pedia um glob
(`"icones/autorais/*.json"`). Ela foi escrita antes de a P27 dar a esse campo o
sentido de "a pasta onde os autorais do pack moram" — que é por onde o gerador
sabe onde escrever. As declarações são os `.json` daquela pasta. **Sem
`desenhos`** — é o caso do modelo lá em cima, que declara só `"gerar": true` —
a pasta é `icones/autorais/`, para ler e para escrever: até a revisão de
23/09/2026 o gerador escrevia ali e não lia dali, e o desenho novo sumia calado.

Um terceiro desenho entra **sem tocar em Python**:

```bash
cp meu-app.json packs/dracula/icones/autorais/
python3 scripts/pack.py validar dracula       # confere a declaração
python3 scripts/pack.py construir dracula     # gera meu-app-dracula.svg e -alucard.svg
```

> **O que ainda é código:** os nove desenhos do próprio sistema (o painel do
> MeowSystem e os oito `com.system76.Cosmic*`) continuam funções no gerador, e
> a tabela de *qual `Icon=` veste qual desenho* continua no `AUTORAL` do
> `completar_icones.sh`. O desenho novo **nasce** no pack; pô-lo na tela de um
> aplicativo ainda pede uma linha naquela tabela.

**No painel**, a aba «Ícones» termina na seção **Desenhos autorais do pack**: o
desenho, os papéis dele com a cor em cada flavor, e a prévia — cada flavor sobre
quatro fundos da paleta dele (`crust`, `base`, `overlay0`, `text`). Escolher
uma cor repinta a prévia; só **Salvar no pack** grava, no pack que está no ar, e
roda o gerador para ele. A torrada diz se o desenho chega à tela, **medindo** o
tema: se algum ícone instalado tem a forma dele, a próxima passagem dos ícones o
troca; se nenhum tem (o Hefesto que veste a logo dela, ou o desenho sem linha no
`AUTORAL`), ela diz que o pack mudou e a tela não.

### O acervo do pack é uma origem na oficina

A oficina «Gerar ícone» de cada aplicativo mostra **todas** as origens que
existem para ele, lado a lado: *Original, Do pack, Salvo* e as variações em
traço. O cartão **Do pack** é o desenho de `icones/apps/` que casa com o
`Icon=` do aplicativo — pelo nome do arquivo ou por uma linha do `apps.map` —,
de **qualquer** pack no disco, com o nome do pack e se ele está no ar.

**Do pack vence por padrão:** é o cartão marcado quando a oficina abre, porque é
o desenho que alguém fez à mão para aquele aplicativo. Marcar não grava nada, e
quando o cartão do pack **não** é o que está na tela, a oficina diz quem está.
O «Usar» não grava arte de pack — ele escreve no acervo de traço; quem põe o
desenho do pack na tela é o próprio pack.

`tests/oficina.sh` trava a regra: todo SVG de `packs/<id>/icones/apps/` que veste
um `Icon=` da máquina tem cartão na oficina daquele aplicativo. O teto é zero.

### O que **não** vai para o pack

Nem todo SVG do repositório é tema. Fica no motor o que não muda quando você
troca de pack:

| fica em `assets/` | por quê |
|---|---|
| `icones/arcticons/`, `arcticons-apps/` | acervo de terceiro, base de conversão. Um pack **aponta** para ele com `motor:` |
| `icones/convertidos-apps/`, `retoques/` | saída do conversor sobre o acervo acima |
| `icones/resgatados/` | resgatados do PNG **desta máquina** — são da máquina, não do tema |
| `icones/autorais/leitura/` | sem flavor no nome: são recoloridos em tempo de build |
| `gatos/` | a marca MeowSystem. O seu pack pode trazer os dele; estes são os de casa |
| `appid.map`, `wmclass.map`, `apps-nomes.map` | identidade técnica de aplicativo. Não é gosto, é fato da máquina |

### O que ainda **não** desceu, e ninguém deve ler isto como pronto

A regra lá em cima — *o mapa é do pack* — está escrita e o resolvedor está de
pé. Cinco mapas que são **decisão de tema** continuam em `assets/icones/`, e
estão listados aqui porque uma migração pela metade que não se declara é pior
que a de antes: quem lê a regra e não vê a exceção escreve um pack contando com
o que não existe.

A ordem que a P27 manda é `estrutura -> resolvedor -> mover -> apagar`. O que
falta a estes cinco é o **terceiro** passo, e para quatro deles falta antes uma
decisão de formato.

| ainda em `assets/icones/` | quem lê | o que falta |
|---|---|---|
| `sistema.map` (30 linhas) | `icones_sistema.sh` | o formato do pack tem **quatro** categorias (`apps`, `pastas`, `mimetypes`, `autorais`) e `sistema` não é uma delas. Descer o mapa é abrir a quinta — em `validar`, no `pack.json` e aqui |
| `apps-arcticons.map` (16) | `icones_apps_arcticons.sh` | os quatro caem no **mesmo** `icones.apps.mapa`, que já tem dono e formato: `nome : caminho`, duas colunas. Estes quatro têm três e quatro colunas, e cada um as suas — `nome:glifo:cor:tipo`, `nome:caminho:cor`, `nome:cor:nota`, `nome:caminho:dono`. Juntá-los não é renomear arquivo: é decidir um formato de mapa de aplicativo que caiba nos cinco, e reescrever os leitores que recolorem por categoria |
| `apps-convertidos.map` (31) | `icones_apps_arcticons.sh` | o mesmo da linha acima |
| `apps-marca.map` (13) | `icones_apps_arcticons.sh` | o mesmo da linha acima |
| `apps-resgatados.map` (21) | `icones_resgatados.sh` | o mesmo da linha acima. Eram 22: o Waterfox saiu em 23/09/2026 para o `apps.map` do Dracula (ver [Fonte e derivados](#fonte-e-derivados)) |

`pastas.map` **não** está nesta lista: o leitor dele já pergunta ao pack
(`icones.pastas.mapa`) e só cai em `assets/` quando nenhum pack declara o seu.
O arquivo continua lá porque o quarto passo é apagar, e apagar antes de algum
pack trazer o seu deixaria as sete pastas sem ícone.

---

## Fonte e derivados

> *"Centralizar os SVGs — e alterando lá alteraremos o resto dos ícones que
> têm eles como base."* — a diretriz que abriu a P28, em 21/09/2026.

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
| 6. recolorir é por papel | `sujeito`, `tinta`, `fundo` resolvidos na paleta do flavor | `gerar_icones_autorais.py` — é por papel que o `alucard` ganhou os seus na P27 |
| 7. uma linha responde | `meow icones fonte <nome>` diz a fonte e o que deriva dela | `bin/meow` |
| 8. a cópia tem caminho de volta | `meow pack sincronizar <id>` compara cópia e origem, e **não copia** | `pack.py sincronizar` |

**A camada da regra 1 é `scalable/apps`.** É o diretório onde dois donos
disputam o mesmo arquivo: o mapa de aplicativos do pack ativo e o
`apps-resgatados.map` do motor escrevem lá, e um nome nos dois é o instalador
que rodar por último vencendo calado — e o `meow doctor` trocando um pelo outro
todo dia. O Arcticons e os convertidos moram no `48x48/apps`: um nome que
exista lá e aqui não é empate, é a precedência *"Dracula vence tudo"* que foi
escolhida em 16/09/2026, com um interruptor (`ICONES_DRACULA`) que devolve o
Arcticons sem apagar nada.

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

A P28 desenhou quatro famílias de derivado: o vetor, os PNG de 32 a 256, as
variantes de flavor e o corte de bandeja. **Medido em 23/09/2026, só a primeira
tem para onde ir:**

- **Tamanhos.** O `index.theme` do MeowSystem-Icons declara dois diretórios de
  aplicativo, `48x48/apps` e `scalable/apps`, e os dois têm **zero** `.png`. O
  COSMIC rasteriza o vetor no tamanho pedido — medido em 27/08, e registrado no
  cabeçalho do `lib/icones.sh`: `Type=Fixed` contra `Type=Scalable` deu zero
  pixel de diferença. Os PNG de 16 a 256 do Waterfox existem, mas no
  `Dracula-Icones`, que é tema de outro projeto, herdado pelo nosso e sombreado
  por ele. Pôr PNG no `48x48/apps` seria disputar arquivo com o
  `icones_apps_arcticons.sh`, que é o dono único daquele diretório.
- **Flavors.** Recolorir por papel é o `gerar_icones_autorais.py`, para
  `icones/autorais/`. Os desenhos de `icones/apps/` do Dracula declaram
  `recolorir: false`: cada um tem de 6 a 10 cores próprias.
- **Bandeja.** Tem mapa e instalador próprios (`bandeja.map`,
  `icones_bandeja.sh`), veste glifo Arcticons, e o mapa está vazio de propósito.

Quando uma dessas famílias ganhar consumidor, ela entra como uma linha no
`meow_icones_derivados` — e aparece no `meow icones fonte` sem ninguém lembrar
de mexer nele. **Raster não é fonte:** um PNG passado ao `derivar` é recusado
com 2, porque de um PNG não sai vetor, nem outro flavor, nem tamanho maior sem
borrar.

### O `PROCEDENCIA.md` do pack, e o `sincronizar`

Arte de terceiro entra no pack **copiada**, e não apontada. Apontar para
`~/.local/share/icons/Dracula-Icones/` seria depender de um diretório que o
`rebuild_dracula_theme()` do Spellbook-OS reescreve do zero — aconteceu em
21/09/2026, às 16:52:33. A regra já estava escrita em
`assets/icones/PROCEDENCIA.md` desde 16/09 (*"por que copiar em vez de
apontar"*); a P28 a levou ao pack inteiro.

Cada cópia ganha uma linha no `packs/<id>/PROCEDENCIA.md`:

```
| arquivo | de onde | lido de | licença | copiado em | sha256 |
|---|---|---|---|---|---|
| `icones/apps/net.waterfox.waterfox.svg` | `m4thewz/dracula-icons`, ramo `circle` — … | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/upstream/…/firefox.svg` | GPL-3.0 | 2026-09-23 | `a13118bd…` |
```

`lido de` aceita `~/…`, `motor:…` ou caminho absoluto, e é só **lido**. O
`sha256` é o da cópia no dia da cópia — o terceiro ponto que permite dizer qual
lado andou:

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
#   ok   icones/apps/net.waterfox.waterfox.svg
#   …
#   19 de 19 em dia com a origem
```

A coluna `lido de` precisa ter a mesma extensão do `arquivo`: ela é dado de
quem escreveu o pack, e um pack de terceiro que apontasse para
`~/.ssh/id_ed25519` teria o `sha256` dele impresso na tela.

---

## Temas de aplicativo

O pack veste o COSMIC, os ícones e o terminal — e, desde 22/09/2026, também o
**tema de dentro dos aplicativos**: o esquema de cor do Spotify, o `.qbtheme` do
qBittorrent, o tema do Obsidian.

> **`apps` não é `icones.apps`.** `icones.apps` são os **ícones** dos
> aplicativos. `apps` é o **tema de dentro** deles. As trilhas não colidem; quem
> lê o `pack.json` de cima para baixo, sim.

### Por que este bloco existe

`assets/temas-de-apps/` é **anterior** ao formato de pack e nunca soube que ele
existe. Contado em 21/09/2026: **446 citações** da palavra `catppuccin` em oito
módulos, e **zero** consultas ao pack ativo. Na prática, os oito eram aplicadores
de um tema só.

O preço estava na tela: numa máquina cujo pack ativo é o **Dracula**, o módulo do
Obsidian anunciou *"Catppuccin Mocha já estava aplicado"*. O único dos oito que
"deu certo" foi o que aplicou o tema do **outro** pack e chamou de sucesso.

### O que se declara

```json
"apps": {
  "spotify":     { "spicetify_tema": "Sleek", "esquema": "Dracula" },
  "qbittorrent": { "arquivo": "apps/dracula.qbtheme", "sha256": "27948d…" },
  "obsidian":    { "herda": "catppuccin" }
}
```

| Campo | O que é |
|---|---|
| `arquivo` | caminho **dentro do pack** para a arte do tema. Volta resolvido em caminho absoluto |
| `sha256` | a integridade daquele arquivo. O `validar` a confere **na publicação** |
| `herda` | *"este aplicativo eu pego emprestado daquele pack"*. Vence a `heranca` do topo |
| o resto | nomes que o módulo daquele app entende — veja a tabela abaixo |

Os campos que cada módulo entende hoje:

| App | Campo | O que é |
|---|---|---|
| `spotify` | `spicetify_tema` | a pasta de `~/.config/spicetify/Themes` a usar |
| | `esquema` | a seção do `color.ini` daquele tema. Aceita `<flavor>` |
| | `acento_no_color_ini` | `true` só se o tema nomear as 26 cores como chaves |
| | `origem` | de onde o tema desce: `tipo`, `repo`, `commit`, `pasta` |
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

python3 scripts/pack.py app dracula apps.qbittorrent.arquivo
#   pack=catppuccin            <- subiu pela herança, e a linha diz de quem
#   valor=…/packs/catppuccin/apps/catppuccin-mocha.qbtheme
```

### Ler o que está no ar antes de escrever

Esta é a metade que importa. **Antes de aplicar, o módulo lê o que o aplicativo
está vestindo agora.** Três saídas, e as três aparecem na tela:

| O que está no ar | O que acontece |
|---|---|
| **o tema do pack** | nada a fazer, e o log diz qual |
| **nada** | aplica |
| **um tema que não veio daqui** | **pergunta. Não sobrescreve** |

A terceira é a que faltava a todos os oito módulos, e é por isso que o trabalho
que a pessoa já tinha feito à mão era invisível para o programa. Medido em
21/09/2026: o `qBittorrent.conf` apontava para `~/.themes/dracula.qbtheme` desde
as 16:49 daquele dia, e o módulo dizia *"não há quem escreva o
qBittorrent.conf"* — com o conf já escrito.

**A pergunta não pode travar o timer.** O instalador roda desatendido, de hora em
hora. Então ela só acontece quando há alguém: as duas pontas precisam ser
terminal, e mesmo assim a espera tem teto de 30 segundos. Fora da tela o caso
vira **pendência acionável** (`<app>-tema-de-terceiro`), o arquivo dele fica
intocado, e a linha espera na Home.

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
subshell: a variável seria atribuída num processo que morre na mesma linha. Foi
exatamente o que aconteceu na primeira versão desta seção, em 22/09/2026: os
dois módulos migrados recebiam o tema certo com a procedência vazia, e o log
dizia "do pack ativo" onde devia dizer de quem herdou. O stdout ficou mudo de
propósito, para que o erro apareça na hora em vez de virar um `''` silencioso.
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

Até 23/09/2026 trocar de pack era editar `PACK=` no `meow.conf` à mão: os
verbos de `meow pack` liam, validavam e construíam, e nenhum dizia à máquina
"use este". Agora há o verbo, e ele é o mesmo que o botão **Usar este** dos
cartões da Home do painel chama.

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
3. **Grava `PACK` e `FLAVOR`, e só as duas.** O resto do `meow.conf` fica
   intacto, comentários inclusive.
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
   as etapas. `--sem-aplicar` grava e para.

**O ensaio ensaia a troca.** Com `MEOW_DRY_RUN=1` (ou o «Ver o que faria» do
painel), o `meow.conf` não é tocado: as duas chaves vão para uma cópia
descartável, e o instalador seco lê a cópia. Um ensaio que lesse o conf do disco
mostraria o pack que **já** está no ar, com cara de ensaio da troca.

**Na tela**, a Home abre com um cartão por pack instalado — o logo, a paleta
embaixo, o que ele traz de próprio e o que herda de quem —, e o que está no ar
tem o anel de acento. Com escolhas ainda não salvas na página, **Usar este**
pergunta antes: elas foram feitas olhando o pack de agora, e são descartadas
quando a troca de verdade começa — um «Ver o que faria» não troca nada, e as
deixa como estavam até o «Rodar de verdade» da gaveta. E a aba Ícones passa a falar com as palavras do pack no ar:
a «Variante dos ícones de arquivo» de um pack que herda o acervo de mimetype
oferece o flavor que **ele** escolheu em `icones.mimetypes.flavor`, com o nome
do dono ao lado — `Macchiato (herdado do Catppuccin)` —, e não os quatro
sabores do Catppuccin soltos numa máquina vestida de Dracula.

---

## Quem vence: o pack ou o `meow.conf`

**O `meow.conf` da máquina sempre vence.** Sem exceção.

O pack diz *"para este tema, o agente bom é este"*. O `meow.conf` diz *"nesta
máquina, o agente é este"*. Quem mora na máquina decide.

| Chave do `meow.conf` | Campo do pack | Quem ganha |
|---|---|---|
| `CURSOR` | `origens.cursores.tema` | o conf |
| `ICONES_FLAVOR` | `icones.mimetypes.flavor` | o conf |
| `ICONES_PASTAS` | — | o conf |
| `ACCENT` | `paleta.acentos[0]` | o conf |
| `FLAVOR` | `paleta.flavor_padrao` | o conf |

Quando o conf está **vazio**, o valor do pack entra. Quando os dois existem e
discordam, o `meow pack info` mostra os dois e diz qual está valendo — silêncio
aqui seria a divergência silenciosa de volta, por outra porta.

**`CURSOR` é a exceção, e o parágrafo acima mentia sobre ela até 23/09/2026.**
`CURSOR` vazio **não toca no ponteiro** — é o jeito de desistir do tema sem
desinstalar nada ("Vazio = NÃO TOCA", no `scripts/cursor.sh`) —, e o `tema` de
`origens.cursores` nunca foi lido para aplicar coisa nenhuma: o único leitor
dele é o painel, que o usa para não acusar de "outro pack" o `CURSOR` que o
próprio pack receita. O que o pack faz
pelo ponteiro é **trazê-lo** (`origens.cursores.proprio`); quem o escolhe é
sempre a chave. Ver [O ponteiro](#o-ponteiro).

---

## O tema do COSMIC, e o único passo manual que existe

Esta é a parte que você precisa saber antes de publicar.

**O COSMIC não tem CLI de tema.** A derivação que transforma o que a GUI edita
(`*.Builder/v1`) no que o sistema lê (`*/v1` e `*/v2`) mora dentro do aplicativo
gráfico. Medido em 04/08/2026: escrever em `Dark.Builder/v1/accent` não moveu
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
  ./scripts/gerar_temas.py meu-tema-mauve

# 2. importe UMA vez:
#    Configurações > Área de trabalho > Aparência > Importar

# 3. fotografe — desde 22/09/2026 ele grava DENTRO do pack ATIVO, sozinho
MEOW_PACK_DIR=~/.local/share/meowsystem/packs/meu-tema \
  ./scripts/capturar_tema.sh meu-tema-mauve
#   ~/.local/share/meowsystem/packs/meu-tema/temas/capturados/meu-tema-mauve/

# 4. confira que o resolvedor a acha, e publique
MEOW_PACK_DIR=~/.local/share/meowsystem/packs/meu-tema \
  python3 scripts/pack.py captura meu-tema-mauve
```

**O `.ron` do passo 1 não vem no clone de ninguém**, e isso mudou em 22/09/2026:
ele é produto de `gerar_temas.py`, e produto gerado saiu do git. Sem `--saida`
ele nasce em `~/.local/state/meowsystem/temas/`.

**Quem diz qual é o pack ativo é `MEOW_PACK_DIR`, e não `PACK`.** A chave `PACK`
é do `meow.conf` e quem a lê é o shell (`meow_pack_dir`, em `lib/comum.sh`); o
`capturar_tema.sh` **não** carrega o `lib/comum.sh` — de propósito, está escrito
no cabeçalho dele — e fala direto com o `pack.py`, que só conhece
`MEOW_PACK_DIR`. Uma receita com `PACK=` na frente **não erra: ela acerta o
alvo errado**, grava a sua foto dentro de `packs/catppuccin/` do clone, e é
exatamente o *"pôr a foto do Dracula dentro do pack do Catppuccin"* que o
`pack.py` passou a impedir. Medido em 22/09/2026:

```
$ env -u MEOW_PACK_DIR PACK=dracula python3 scripts/pack.py captura-destino meu-tema-mauve
<clone>/packs/catppuccin/temas/capturados/meu-tema-mauve
```

**Com o pack já ativo no `meow.conf`** (`PACK=meu-tema`, ou um `FLAVOR` com o
mesmo nome), a ponte já está montada e as duas linhas acima viram uma:
`meow tema capturar meu-tema-mauve` — o `bin/meow` chama o `meow_ponte_python`
na entrada e exporta o `MEOW_PACK_DIR` para você.

A captura é **portátil**: são ~176 arquivos de texto com caminhos relativos. O
único arquivo com caminho de máquina é o `captura.txt`, que é metadado de
procedência — `aplicar_tema.sh:394` o pula explicitamente, e ele não entra no
`manifesto.sha256`.

Se o pack **não** trouxer captura, o MeowSystem não quebra: ele avisa e diz ao
usuário os três passos acima. Mas aí cada pessoa paga o custo, em vez de você
pagar uma vez.

---

## O som

Um pack pode trazer o próprio som de volume. **É um som só** — e a razão está
medida, não suposta.

O COSMIC quase não toca som. Varrendo os 41 binários `/usr/bin/cosmic-*` em
04/08/2026: `pw-play` aparece em dois, `canberra` em nenhum (os três acertos no
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

```json
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

```json
"origens": {
  "cursores": { "proprio": "cursores/meu-tema-roxo" }
}
```

**Quem escolhe continua sendo a chave `CURSOR`.** O pack oferece; o
`meow.conf` decide. Com `CURSOR="meu-tema-roxo"`, o `scripts/cursor.sh` instala
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
juntas — a P17 pegou duas vezes uma delas andando sozinha.

**Um diretório de nome exato vence o pack.** Se `meu-tema-roxo/` existir em
`~/.local/share/icons/`, `~/.icons/` ou `/usr/share/icons/`, as duas alavancas
do `cursor.sh` apontam para ele — é a regra de 15/09/2026 que fez o
`Dracula-Cursor` funcionar. Nesse caso o ponteiro do pack sai da lista, em vez de
virar um botão que baixa da rede.

| o `validar` cobra | por quê |
|---|---|
| o caminho cai dentro do pack, e existe | o `realpath` de todo campo |
| o nome só tem `[A-Za-z0-9._-]`, sem começar por `.` ou `-` | é o nome que vira diretório. O `cursor.sh` trocaria qualquer outro caractere, e o painel ofereceria um nome que o script instala com outro |
| `cursors/` existe e tem `default` ou `left_ptr` | é o ponteiro de repouso: sem ele não há o que ver, nem de onde tirar a prévia |
| nenhum arquivo ou link do tema aponta para fora dele | o tema é copiado inteiro (`cp -a`), e o link iria junto para `~/.local/share/icons/` |
| todo link do tema leva a um arquivo que existe | o ponteiro que o link promete não existe. Até a revisão de 23/09/2026 ele passava, e o instalador reinstalava o tema em toda passagem, sem convergir |
| `proprio` e `herda` não aparecem juntos | um bloco que diz "o meu" e "o do vizinho" não disse qual |

**Herdar é pelo bloco.** `origens.cursores.herda: "outro"` sobe para o pack
`outro`; sem `proprio` nem `herda`, vale a `heranca` do pack. O `meow pack info`
diz até onde a subida chega — `CURSOR="x", do pack y`, ou "a cadeia não traz
ponteiro", que é o caso do Dracula hoje (o motivo está no `pack.json` dele:
procedência).

```bash
python3 scripts/pack.py ponteiro meu-tema
#   pack=meu-tema
#   dir=/…/packs/meu-tema/cursores/meu-tema-roxo
#   valor=meu-tema-roxo
```

**Licença.** Tema de ponteiro é arte de terceiro quase sempre. O `LICENSE` e o
`AUTHORS` vão dentro do diretório do tema — o `cursor.sh` os copia junto, e a
auditoria funciona na máquina de quem instalou —, e o `CREDITOS.md` do pack diz
de onde ele veio. Sem procedência, não entra: é por isso que o Dracula continua
com `herda`.

## As fontes

Um pack pode trazer fontes de texto. Elas **somam** às do motor: a
JetBrainsMono Nerd Font pinada continua sendo instalada, e continua sendo a do
terminal, para todo pack.

```json
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

Quatro coisas continuam do **motor**, iguais para todo pack, e o formato **não
tem campo** para elas. Estão escritas aqui porque uma lista que omite o que
falta é lida como pronta — e a nota de herança do Dracula dizia, até
23/09/2026, que prompt, fastfetch e gatos "vêm do pack base".

| categoria | de onde sai | quem teria de perguntar ao pack |
|---|---|---|
| **traço do gerador de ícone** | `scripts/converter_icone.py` e as réguas da oficina | ver abaixo |
| **prompt** | `assets/prompt/` | `scripts/prompt.sh` |
| **fastfetch** | `assets/fastfetch/` | `scripts/fastfetch_logo.sh` |
| **gatos** | `assets/gatos/` | seis leitores da pasta: `greeter.sh`, `logo.sh`, `construir_icones.sh`, `fastfetch_logo.sh`, `vigia_assets.sh` e o `bin/meow` (contados em 23/09/2026) |

**Declarar sem leitor não serve.** Um `"prompt": {"proprio": …}` que nenhum
script lê é o campo morto que o `validar` avisa em voz alta: o pack prometeria
um prompt, e a tela mostraria o de sempre. Cada uma destas entra no dia em que
o leitor dela perguntar ao pack, e não antes.

**O traço do gerador não é o `icones.autorais`.** A P26 tornou declarável **o
que** o gerador de autorais desenha (os `.json` de [Desenhos
autorais](#desenhos-autorais)). O **traço** da conversão — espessura, fusão,
aparo, cantos, se preenche área — continua nos padrões do `converter_icone.py`
e nas réguas da oficina, e medido em 23/09/2026 há dois motivos para ele não
virar campo só com esses dois arquivos na mão (o `estilo_icone.py`, que a P12
também nomeava, só MEDE a caneta; ele não tem parâmetro nenhum):

- os padrões do conversor produzem `assets/icones/convertidos-apps/`, que é
  **versionado no motor** — contadas em 23/09/2026, 28 das 31 linhas do
  `apps-convertidos.map` deixam o campo de parâmetros vazio, e usam o padrão.
  Um padrão vindo do pack ativo faria o acervo do git depender de qual pack
  estava no ar quando alguém o reconstruiu;
- a oficina grava no mapa a string exata dos parâmetros
  (`--k 8 --funde 52 --tol 1`) e conta com "régua em zero = bandeira ausente =
  a saída de ontem" para que a linha reproduza o desenho gravado ao lado dela.
  Um padrão vindo do pack mudaria o que a ausência significa.

Fazer direito é levar o acervo convertido para dentro do pack e fazer a oficina
começar as réguas do perfil do pack. O que segura o item são essas duas
decisões de desenho — onde mora o acervo que hoje é do git, e o que a régua em
zero passa a significar —, e elas pedem sprint própria, aberta por quem é dono
do projeto. O limite continua o da P12: **só os parâmetros que a oficina já
aceita, com nome**. Nada de expressão, nada de condicional.

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
  cursores          HERDADO de catppuccin        a cadeia não traz ponteiro
  wallpapers        PRÓPRIO
  apps              PRÓPRIO
  som               PRÓPRIO
  fontes            HERDADO de catppuccin        a cadeia não traz fonte
  gerador           DO MOTOR — não declarável    scripts/converter_icone.py
```

**O som não sobe a herança.** O `scripts/som.sh` lê só o `som` do pack ativo e
põe os padrões dele no que faltar; um pack que herda do Dracula e não declara
`som` toca o sino do motor. A tabela diz `DO MOTOR` para ele, e não `HERDADO`.

**`wallpapers` diz PRÓPRIO no Dracula, e é a exceção que falta consertar.** Os
campos de `origens.wallpapers` ainda não têm leitor — o `validar` os lista como
campo morto —, e o papel de parede do Dracula vem de `WALLPAPER_DRACULA_REPO`
no `meow.conf`, que o `wallpaper.sh` lê pelo nome do flavor. A linha fica como
está até a sprint que der leitor ao bloco; o aviso de campo morto já conta a
verdade sobre ela.

**Eram onze, e são quinze linhas.** A tabela da P12 (21/09/2026) contava onze:
paleta, tema do COSMIC, ícones de aplicativo, de pasta, mimetypes, papéis de
parede, som, ponteiro, fontes, gerador de ícone e "prompt, fastfetch, gatos"
numa linha só. A P18 e a P27 acrescentaram duas que ela não contava (temas de
aplicativo e ícones autorais), e a última linha dela são três coisas com três
leitores diferentes, que viram três linhas aqui.

## O logo do pack

Todo pack tem um `logo.svg` na raiz, e ele é **a cara do pack** — o que o
separa de outro pack de paleta parecida. É obrigatório para publicar desde
23/09/2026 (P25): o `meow pack validar` recusa pack sem ele.

**Cobrado de quem publica, nunca de quem usa.** O tema de um pack sem logo, ou
com um logo recusado, continua no ar: o instalador, a paleta, o som e a sonda
que diz se o pack existe não olham o logo. Se olhassem, um pack de antes de
23/09 — íntegro em todo o resto — faria o desktop inteiro voltar ao padrão
depois de uma atualização, com um "não resolve" que nem diria que o motivo é o
logo, e por causa de uma figura que só o cartão e o lançador mostram. Quem
cobra é o `meow pack validar` (e o `meow pack listar`, que o chama); quem
mostra o logo confere o arquivo por conta própria — ver abaixo.

**Por que um logo, e não a tira de cores.** O mockup de 21/09 desenhava a capa
do cartão de pack como uma tira com as cores da paleta. Tira de cor é paleta,
não identidade: dois packs de paleta parecida ficam indistinguíveis. O logo é a
cara; a tira continua existindo — embaixo dele, fina, como **amostra** da
paleta.

**A capa da vitrine é este arquivo, e o campo é um só.** Quando o `pack.json`
tem `vitrine.capa` (P15), é ele que diz onde o logo mora; sem o campo, vale
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
Medido em 23/09/2026 nos dois logos daqui: o do Dracula resolvido no `alucard`
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
  portas laterais da mesma coisa — nas três primeiras, medido no Chromium em
  23/09/2026, o navegador buscou o arquivo remoto:
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

- **O ícone do lançador ainda não é o logo.** A P25 pediu que o `.desktop` do
  MeowSystem apontasse para o logo do pack ativo. Medido em 23/09/2026: quem
  escreve aquele `.desktop` é o `scripts/atalho.sh` (`Icon=com.meowsystem.Painel`,
  um nome de tema, pelos motivos escritos lá), e quem instala o ícone com esse
  nome é o `scripts/completar_icones.sh`, a partir do autoral
  `meowsystem-painel-<flavor>.svg`. Os dois ficaram fora da sprint, que nomeava o
  `scripts/logo.sh` — e esse é dono dos gatos do dock, não do `.desktop`. Quando o
  passo vier, a porta é o verbo `logo`, e ele vem com o `meow_lancador_reler`: o
  lançador do COSMIC cacheia ícone (`lancador-cosmic-cacheia-icones`, 11/08), e
  trocar só o arquivo faz parecer que a troca de pack não funcionou.
- **O cartão do pack na Home** nasceu com a P15 (ver [A vitrine](#a-vitrine)),
  e mostra o que `logo <id> <flavor_padrao>` responde — não o arquivo cru, que
  não passou pela conferência, e não a tira, que desce para baixo do logo como
  amostra do mesmo flavor. Um logo que o verbo recusa não vira imagem: o cartão
  diz o motivo. Mostrar o logo no flavor que está no ar fica para a P10, que faz
  da Home o lugar de trocar de pack.
- **`logo-mono.svg`**, a versão de traço único para barra e bandeja, não entrou:
  nada no projeto o leria, e um arquivo declarado sem leitor é a promessa vazia
  que o `validar` avisa em voz alta.

## O que um pack não pode fazer

Um pack é **dado**. Nunca é código.

- **Nenhum arquivo executável é lido de um pack.** Não existe `ganchos.sh`, não
  existe script de instalação. O único subsistema do MeowSystem que aceita shell
  de terceiro é `assets/temas-de-apps/*/manifesto.sh`, e ele tem contrato
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
| `caminho <id> <categoria>` | o caminho que aquela categoria resolve **no pack** |
| `acervo <id> <categoria> [arquivo]` | o mesmo, subindo pack → herança → motor |
| `paleta <id>` | o arquivo de paleta daquele pack |
| `logo <id> [flavor] [accent]` | o `logo.svg`, com as cores resolvidas por papel para aquele flavor |
| `logo-gerado <id> [flavor] [accent]` | o logo gerado, para o pack que ainda não tem — **só imprime** |
| `de-csv <arquivo.csv>` | o `paleta.json` de um CSV `slot,flavor,hex`, com o claro derivado se faltar — **só imprime**. Ver [Começar por um CSV](#começar-por-um-csv) |
| `som <id>` | o timbre do pack, como `CHAVE=valor` para o shell |
| `raizes` | as três raízes de busca, na ordem |
| `padrao` | o diretório do pack **padrão** |

`padrao` existe para que o nome do pack padrão more num lugar só. Antes de
22/09/2026 ele estava cravado em nove pontos de código.

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
   `creditos` —, e todos são abertos, não só olhados. O `creditos` entrou em
   21/09/2026: o `packs/dracula/pack.json` prometia um `CREDITOS.md` desde que
   nasceu, o arquivo nunca esteve lá, e `meow pack validar dracula` saía 0. Um
   validador que aprova um pack que promete e não entrega não está validando o
   formato: está carimbando. Ou crie o arquivo, ou tire o campo
9. todo caminho declarado está dentro do pack (resolvido com `realpath`)
10. todo `herda` aponta para um pack que existe
11. nenhuma URL fora de `https://`
12. **contraste**: `text` sobre `base` precisa passar em WCAG AA (4.5:1) — 26
    hexes aleatórios passam em tudo acima e produzem uma interface ilegível
13. **a vitrine** — a capa existe, é SVG e está dentro do pack; a frase curta
    cabe em 80 caracteres; a descrição é um `.md` do pack; o `site` é
    `https://`. Cobrado só pelo verbo `validar`, como o 14: o instalador e o
    painel usam um pack de vitrine quebrada assim mesmo. A exceção é o `site`
    em `http://`, que já caiu no 11 — e o 11 vale para o motor. Ver
    [A vitrine](#a-vitrine)
14. **o logo**: `logo.svg` existe, é SVG quadrado, sem script, sem imagem
    embutida e sem nada que aponte para fora dele. Cobrado só pelo verbo
    `validar`: o instalador usa o pack sem logo assim mesmo — ver
    [O logo do pack](#o-logo-do-pack), que diz cada regra e o porquê. Depois
    da vitrine, e de propósito: o logo é o arquivo que `vitrine.capa` nomeia, e
    é o 13 que diz, antes, se o campo aponta para um SVG que existe

A validação roda de novo dentro do `meow_preflight`, **antes** de o instalador
escrever qualquer coisa. Um pack quebrado não chega a tocar no seu desktop.

### O campo que ninguém lê: aviso, nunca silêncio

Antes do `ok`, o validador imprime **quais campos aquele `pack.json` declara e
nenhuma linha deste projeto consulta**:

```
  aviso 11 campo(s) que este pack declara e NENHUM código lê:
          icones.apps.camada
          origens.wallpapers.tipo
          …
        Eles não quebram nada — e também não fazem nada: nenhuma linha deste
        projeto os consulta.
```

**Por que existe.** Uma varredura em 21/09/2026 mediu que metade do que o
`packs/dracula/` declarava não tinha um único leitor em código. O caso que dói:
ele declarava `cosmic.nome_da_paleta` **exatamente** para impedir que o tema
aparecesse como `catppuccin-dracula` na GUI do COSMIC — e era assim que ele
aparecia, porque o conserto não tinha leitor. Um formato que aceita declaração
morta ensina a escrever declaração morta: quem copia um `pack.json` repete os
campos mortos acreditando que eles fazem alguma coisa.

**É aviso, e não recusa.** Um campo sem leitor hoje pode ser o campo que a
versão seguinte vai ler, e recusar por causa dele quebraria packs que já
funcionam. O que não pode é o silêncio.

**Campo que comece com `_` não é cobrado** — `_nota`, `_comentario`,
`_nota_heranca` são prosa do autor do pack, e cobrá-las seria punir quem
documentou.

O `packs/catppuccin/` sai **limpo** deste aviso, de propósito: ele é o primeiro
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

**O que ele não leva, e por quê.** A P11 pedia também "os acervos que a pessoa
adicionou — ícones, papéis de parede, ponteiro — copiados". Medido em
23/09/2026: o formato não tem onde guardar papel de parede nem ponteiro
**dentro** do pack — o `wallpaper.sh` e o `cursor.sh` não abrem pack nenhum, e
o ponteiro próprio é a P12. Copiá-los seria criar arquivo sem leitor, que é o
que o `validar` existe para denunciar. O verbo diz isso na tela em vez de fingir.

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
| o pack que não passa no `validar` inteiro | as 26 cores, `https://` em toda URL, todo caminho dentro do pack, a herança existindo nesta máquina |
| um id que já existe em **qualquer** raiz | por cima trocaria o que está lá sem perguntar; noutra raiz, um dos dois sumiria da vista |

E o que passa **nasce 0644**, seja qual for o modo que o tar peça: nada do que
chega ganha bit de execução. O pack é montado num diretório oculto ao lado,
validado, e só então renomeado para o lugar — não existe instante com meio
pack na raiz.

`meow pack importar arquivo.meowpack --seco` (ou `MEOW_DRY_RUN=1`) faz tudo
isso num temporário e diz o que o pack traz — a paleta, quantos ícones, de onde
vêm ponteiro, papel de parede e som — sem escrever nada. É o que a tela de
confirmar do painel mostra.

### No painel

Os botões **Exportar o meu** e **Importar um pack** do bloco "Theme packs" da
Home (P10), e as duas rotas que eles chamam:

| rota | o que faz |
|---|---|
| `GET /api/pack-exportar?id=<id>` | o `.meowpack`, para baixar. `&imagens=nao` deixa as imagens; `&medir=1` roda o exportar em ensaio e devolve o tamanho e as imagens, em JSON. Recusa volta como `{erro}` e 400, nunca como arquivo |
| `POST /api/pack-importar` | `{nome, conteudo}` em base64. Sem `confirmado`, é o `--seco`: devolve `precisa_confirmar`, `titulo`, `resumo` (uma frase) e `pack` (o que ele traz). Com `confirmado: true`, instala e devolve `instalado` e `frase`. Nas duas, nada é aplicado |

**Exportar o meu** pede o `medir` primeiro: a recusa (licença, `CREDITOS.md`,
`validar`) aparece antes de qualquer pergunta, e quando o pack tem imagem a
caixa diz quantos MB ele tem com e sem elas, com "levar as imagens junto"
marcado — o `[S/n]` do terminal. Só então baixa. **Importar um pack** abre a
caixa de confirmar com a paleta desenhada, cada flavor com as 26 cores, e uma
linha para ícones, papéis de parede, ponteiro e som; a mensagem de que entrou
só aparece quando a rota diz `instalado`.

Quem confere e quem instala é o **mesmo** `meow pack exportar`/`importar` do
terminal — as rotas só levam o arquivo de um lado para o outro. Uma segunda
leitura do tarball no servidor seria a porta que ninguém conferiu.

### Antes de publicar, confira

- [ ] `meow pack validar` passa
- [ ] `CREDITOS.md` nomeia a origem e a licença de cada acervo de terceiro
- [ ] `licenca` no `pack.json` é compatível com a de tudo que você empacotou
- [ ] a captura do tema está no pack (senão, diga no `LEIA-ME.md` que não está)
- [ ] `heranca` está escrita, mesmo sendo o default
- [ ] nenhum caminho absoluto, nenhum `~`, nenhum nome de usuário
- [ ] o `logo.svg` é seu, e as formas declaram papel na `class` em vez de hex

Este repositório traz **dois** packs, e eles ensinam coisas diferentes:

- **`packs/catppuccin/`** é o pack **padrão** — o mínimo honesto. Só campos com
  leitor, a paleta de quatro flavors e um acervo de glifos. É o que todo pack
  herda quando não declara.
- **`packs/dracula/`** é o exemplo completo: uma paleta, dois acervos de ícone,
  um acervo de papel de parede declarado por chave de conf, e tudo o mais
  herdado — com cada herança dita na cara.

Se for copiar um para começar o seu, copie o **catppuccin**: o do Dracula
declara onze campos que ainda não têm leitor, e o `validar` diz quais são. Eram
quinze até a P15 dar leitor a `autor`, `versao` e `licenca`, e doze até a P10
dar leitor a `icones.mimetypes.flavor` — ver [Trocar de pack](#trocar-de-pack-meow-pack-usar).

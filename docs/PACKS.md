# Theme packs

Um **theme pack** é um diretório que diz ao MeowSystem que cores usar — e, se
quiser, que ícones, que papéis de parede e que agente. O MeowSystem lê o pack e
escreve no seu desktop; **ele nunca escreve dentro do pack.**

O pack mais simples que funciona tem dois arquivos e nenhuma linha de código.

```
packs/meu-tema/
  pack.json      quem é o pack e o que ele fornece
  paleta.json    as 26 cores
```

Com isso você já ganha tema do COSMIC, esquema do terminal, cores do painel, dos
ícones autorais e dos temas de aplicativo. Tudo o que você não declarar é
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

- [As 26 cores](#as-26-cores)
- [A fronteira: `assets/` contra `packs/`](#a-fronteira-assets-contra-packs)
- [A estrutura do pack](#a-estrutura-do-pack)
- [`pack.json`, campo a campo](#packjson-campo-a-campo)
- [De onde sai um acervo: pack, herança, motor](#de-onde-sai-um-acervo-pack-herança-motor)
- [O acervo de ícones do pack](#o-acervo-de-ícones-do-pack)
- [Temas de aplicativo](#temas-de-aplicativo)
- [Quem vence: o pack ou o `meow.conf`](#quem-vence-o-pack-ou-o-meowconf)
- [O tema do COSMIC, e o único passo manual que existe](#o-tema-do-cosmic-e-o-único-passo-manual-que-existe)
- [O som](#o-som)
- [O que um pack não pode fazer](#o-que-um-pack-não-pode-fazer)
- [Validar antes de publicar](#validar-antes-de-publicar)
- [Publicar](#publicar)

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
(AAA), e **cada slot não pior que o Latte no mesmo slot**. Exigir 4,5:1 de todo
acento reprova 12 slots — e reprova o próprio Latte, onde `rosewater` sobre
`base` dá 2,32. Esses slots são decoração, não texto.

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

Só `pack.json` e a paleta são obrigatórios. Todo o resto é opcional.

```
packs/<id>/
  pack.json                 OBRIGATÓRIO
  paleta.json               OBRIGATÓRIO (o nome vem de paleta.arquivo)
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
  apps/
    <tema>.qbtheme                   os temas de DENTRO dos aplicativos — ver a seção própria
    PROCEDENCIA.md                   obrigatória quando a arte é de terceiro
  temas/
    capturados/<flavor>-<accent>/    o tema do COSMIC já fotografado — ver a seção própria
                                     (é convenção: não precisa declarar nada)
  LEIAME.md                 opcional
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
    "cursores":   { "herda": "catppuccin", "tema": "catppuccin-mocha-light" },
    "wallpapers": { "tipo": "github-arvore",
                    "repo_do_conf": "WALLPAPER_SEMENTE_REPO",
                    "commit_do_conf": "WALLPAPER_SEMENTE_COMMIT",
                    "se_vazio": "herdar" }
  },

  "apps": {
    "spotify":     { "spicetify_tema": "Sleek", "esquema": "Dracula" },
    "qbittorrent": { "arquivo": "apps/meu-tema.qbtheme", "sha256": "…" }
  }
}
```

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
| sem prefixo | dentro do pack, contra o diretório do próprio mapa |

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
| `apps-resgatados.map` (22) | `icones_resgatados.sh` | o mesmo da linha acima |

`pastas.map` **não** está nesta lista: o leitor dele já pergunta ao pack
(`icones.pastas.mapa`) e só cai em `assets/` quando nenhum pack declara o seu.
O arquivo continua lá porque o quarto passo é apagar, e apagar antes de algum
pack trazer o seu deixaria as sete pastas sem ícone.

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
| `info <id>` | o que é próprio, o que é herdado, categoria a categoria |
| `caminho <id> <categoria>` | o caminho que aquela categoria resolve **no pack** |
| `acervo <id> <categoria> [arquivo]` | o mesmo, subindo pack → herança → motor |
| `paleta <id>` | o arquivo de paleta daquele pack |
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

A validação roda de novo dentro do `meow_preflight`, **antes** de o instalador
escrever qualquer coisa. Um pack quebrado não chega a tocar no seu desktop.

### O campo que ninguém lê: aviso, nunca silêncio

Antes do `ok`, o validador imprime **quais campos aquele `pack.json` declara e
nenhuma linha deste projeto consulta**:

```
  aviso 15 campo(s) que este pack declara e NENHUM código lê:
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

Um pack é um diretório. Publique como quiser: um repositório git, um tarball,
uma pasta compartilhada. Quem instala faz:

```bash
git clone https://exemplo/meu-tema ~/.local/share/meowsystem/packs/meu-tema
meow pack validar meu-tema
```

e põe no `meow.conf`:

```bash
PACK="meu-tema"
FLAVOR="meu-tema"
ACCENT="mauve"
```

Depois, `meow ativar`.

### Antes de publicar, confira

- [ ] `meow pack validar` passa
- [ ] `CREDITOS.md` nomeia a origem e a licença de cada acervo de terceiro
- [ ] `licenca` no `pack.json` é compatível com a de tudo que você empacotou
- [ ] a captura do tema está no pack (senão, diga no `LEIAME.md` que não está)
- [ ] `heranca` está escrita, mesmo sendo o default
- [ ] nenhum caminho absoluto, nenhum `~`, nenhum nome de usuário

Este repositório traz **dois** packs, e eles ensinam coisas diferentes:

- **`packs/catppuccin/`** é o pack **padrão** — o mínimo honesto. Só campos com
  leitor, a paleta de quatro flavors e um acervo de glifos. É o que todo pack
  herda quando não declara.
- **`packs/dracula/`** é o exemplo completo: uma paleta, dois acervos de ícone,
  um acervo de papel de parede declarado por chave de conf, e tudo o mais
  herdado — com cada herança dita na cara.

Se for copiar um para começar o seu, copie o **catppuccin**: o do Dracula
declara quinze campos que ainda não têm leitor, e o `validar` diz quais são.

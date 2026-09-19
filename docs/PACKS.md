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
herdado do pack embutido, e o `meow pack info` diz exatamente o que veio de onde.

---

## Sumário

- [As 26 cores](#as-26-cores)
- [A estrutura do pack](#a-estrutura-do-pack)
- [`pack.json`, campo a campo](#packjson-campo-a-campo)
- [Quem vence: o pack ou o `meow.conf`](#quem-vence-o-pack-ou-o-meowconf)
- [O tema do COSMIC, e o único passo manual que existe](#o-tema-do-cosmic-e-o-único-passo-manual-que-existe)
- [O som](#o-som)
- [O que um pack não pode fazer](#o-que-um-pack-não-pode-fazer)
- [Validar antes de publicar](#validar-antes-de-publicar)
- [Publicar](#publicar)

---

## As 26 cores

A paleta é um JSON com os mesmos campos de `assets/paleta/catppuccin.json`:

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
é exatamente o que o Dracula faz, e o `_comentario` de `catppuccin.json` registra
quais foram derivadas e como.

O que cada nome quer dizer, na prática:

| Grupo | Nomes | Papel |
|---|---|---|
| Acentos | `rosewater` `flamingo` `pink` `mauve` `red` `maroon` `peach` `yellow` `green` `teal` `sky` `sapphire` `blue` `lavender` | cor de destaque; um deles vira o `ACCENT` |
| Texto | `text` `subtext1` `subtext0` | do mais forte ao mais apagado |
| Sobreposição | `overlay2` `overlay1` `overlay0` | bordas, separadores, texto desabilitado |
| Superfície | `surface2` `surface1` `surface0` | fundos elevados, do mais claro ao mais escuro |
| Fundo | `base` `mantle` `crust` | o fundo da janela, o da barra, o mais profundo |

**`claros`** lista quais flavors são de fundo claro. Se o seu pack não tem
flavor claro, deixe `[]` — e leia a seção `paleta.claro_de_reserva` do
`pack.json`, porque o COSMIC alterna entre um tema escuro e um claro e alguém
precisa responder pelo claro.

---

## A estrutura do pack

Só `pack.json` e a paleta são obrigatórios. Todo o resto é opcional.

```
packs/<id>/
  pack.json                 OBRIGATÓRIO
  paleta.json               OBRIGATÓRIO (o nome vem de paleta.arquivo)
  CREDITOS.md               a procedência de cada acervo — obrigatório se houver arte de terceiro
  cosmic-map.json           opcional: substitui o molde do tema do COSMIC
  icones/
    apps.map                "nome-do-ícone : caminho/relativo.svg"
    apps/                   os desenhos referidos pelo mapa
    pastas/                 folder-documents.svg, folder-download.svg…
    mimetypes/<flavor>/     o acervo por tipo de arquivo (é grande: ~656 por flavor)
  temas/
    capturados/<flavor>-<accent>/    o tema do COSMIC já fotografado — ver a seção própria
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

# 3. fotografe
./scripts/capturar_tema.sh meu-tema-mauve

# 4. mova a captura para dentro do pack e publique
mv assets/temas/capturados/meu-tema-mauve \
   ~/.local/share/meowsystem/packs/meu-tema/temas/capturados/
```

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
| Quinta justa | 1320 | resolvido, claro — é o do pack embutido |
| Terça maior | 1100 | alegre |
| Terça menor | 1046.5 | sombrio |
| Oitava | 1760 | neutro, quase um bipe |

O pack Dracula usa sol (784) com a terça menor acima (si bemol, 932.3): o mesmo
gesto de mexer no volume soa noturno, sem virar alarme. E o decaimento dele é
mais lento que o do embutido (38 contra 46) porque a terça menor precisa de um
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

Ele confere, nesta ordem, e **para no primeiro erro**:

1. `pack.json` é JSON válido e tem os campos obrigatórios
2. `formato` é suportado
3. `id` casa com o nome do diretório
4. a paleta existe, é JSON e tem `ordem_canonica`, `flavors`, `nomes`, `claros`
5. **cada flavor tem os 26 slots** — e o erro **nomeia os que faltam**, todos de
   uma vez, não um por vez
6. todo hex é `#RRGGBB`
7. `flavor_padrao` existe na paleta
8. todo caminho declarado existe e está dentro do pack
9. todo `herda` aponta para um pack que existe
10. nenhuma URL fora de `https://`
11. **contraste**: `text` sobre `base` precisa passar em WCAG AA (4.5:1) — 26
    hexes aleatórios passam em tudo acima e produzem uma interface ilegível

A validação roda de novo dentro do `meow_preflight`, **antes** de o instalador
escrever qualquer coisa. Um pack quebrado não chega a tocar no seu desktop.

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

O `packs/dracula/` deste repositório é um exemplo completo e funcional: uma
paleta, dois acervos de ícone, um acervo de papel de parede declarado por chave
de conf, e tudo o mais herdado — com cada herança dita na cara.

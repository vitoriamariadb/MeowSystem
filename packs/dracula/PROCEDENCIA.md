# Procedência do pack Dracula — de onde veio cada arte copiada

Este arquivo nasceu em 23/09/2026, com a P28 (*"a fonte única: um desenho no
pack, todo o resto derivado"*), e ele tem **dois leitores**: quem abre o pack
para saber de onde veio um desenho, e o `meow pack sincronizar dracula`, que lê
a tabela lá embaixo linha a linha. Por isso a tabela tem forma fixa — ver
"Para quem for acrescentar uma linha", no fim.

## Por que copiar, e por que copiar não basta

**Copiar em vez de apontar** é regra antiga desta casa, e ela está escrita desde
16/09/2026 em `assets/icones/PROCEDENCIA.md`: o `apps-dracula.map` apontava
para dentro do `Dracula_OS-Theme`, um repositório que só existe na máquina do
dono dele, e um script que o lesse funcionaria de um lado e quebraria do outro.
A P28 levou a mesma regra ao pack inteiro (a regra 5 da sprint): arte de
terceiro entra **por cópia**, com uma linha aqui dizendo de onde veio, sob que
licença e em que data.

**Mas a cópia congela.** A origem de quase tudo daqui é outro projeto, que
continua andando: o `Dracula-Icones` desta máquina é reconstruído do zero pelo
`rebuild_dracula_theme()` do Spellbook-OS, a partir do `Dracula_OS-Theme`. Sem
caminho de volta, a cópia defasa e ninguém percebe — é o modo de falha que a
memória do `Dracula-OS-Theme` já registrava em 18/08/2026: *"o tema copia arte
em vez de referenciar, então divergência silenciosa é o modo de falha natural"*.

**E o caminho de volta não pode ser automático** (a regra 8). Uma arte retocada
aqui depois de copiada é trabalho de alguém; um `git pull` do outro repositório
não pode apagá-la. Então o `meow pack sincronizar dracula` **só lê**: calcula o
`sha256` de cada cópia e de cada origem, compara com o que ficou registrado na
cópia, e diz qual dos lados andou. Trazer a versão da origem é um gesto de quem
decide — o comando imprime a linha do `cp` e para ali. O `meow doctor` repete o
aviso como informação, e nunca como conserto: escolher entre o retoque daqui e o
upstream de lá é decisão de autor, não de programa.

## As artes

A coluna **sha256** é a da cópia **no dia em que foi copiada** — que, para as
dezenove, era também a da origem naquele dia (medido: cada uma bateu byte a byte
com o arquivo da coluna "lido de" em 23/09/2026). É ela que permite dizer qual
lado andou depois: se a cópia mudou e a origem não, foi retoque daqui; se a
origem mudou e a cópia não, foi o upstream.

A coluna **lido de** é o arquivo que o `sincronizar` abre para comparar. `~/`
é a pasta pessoal de quem roda; `motor:` é o `assets/icones/` deste
repositório, o mesmo prefixo dos mapas de ícone. Numa máquina onde a origem não
existe — a dela não tem o `Dracula_OS-Theme` — a linha sai como "fora de
alcance", e isso não é divergência: é só não haver com o que comparar.

| arquivo | de onde | lido de | licença | copiado em | sha256 |
|---|---|---|---|---|---|
| `icones/apps/com.system76.Popsicle.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/lollipop.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/new-sessao-atual/lollipop.svg` | GPL-3.0 | 2026-09-16 | `c2744bb1238641416f208b54b43da816320f038cc26f802ea1d1657dae0b6451` |
| `icones/apps/foundryvtt.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/dice.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/new-sessao-atual/dice.svg` | GPL-3.0 | 2026-09-16 | `b054beb4ed504629488527eb5f3253279aa20e6dd793d20c635f042d121e09bb` |
| `icones/apps/google-chrome.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/google-chrome.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/current/scalable/apps/google-chrome.svg` | GPL-3.0 | 2026-09-16 | `66310f2646b82ab59c81d66950d84f945a88656ff760bc2e6bcf49827dbc4b0c` |
| `icones/apps/guvcview.svg` | este repositório — `assets/icones/resgatados/guvcview.svg` | `motor:resgatados/guvcview.svg` | a do pacote `guvcview` | 2026-09-17 | `085829f880ad8727fb077f58a84609e9e0b38dd12e323726a9ace2b84026700d` |
| `icones/apps/input-keyboard.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/input-keyboard.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/upstream/dracula-icons-circle/scalable/apps/input-keyboard.svg` | GPL-3.0 | 2026-09-16 | `45865667705880f1c2867e3123215ae10acdd72c9244d50c37ab6d8805fceba8` |
| `icones/apps/io.github.dvlv.boxbuddyrs.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/chest-variant.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/new-sessao-atual/chest-variant.svg` | GPL-3.0 | 2026-09-16 | `e5100327eab6480a79a45d03fed67fec99c74c5c061219568e37ccfd23f5cc33` |
| `icones/apps/io.github.flattool.Warehouse.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/building.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/new-sessao-atual/building.svg` | GPL-3.0 | 2026-09-16 | `4a1b45ba5d52f2b2751d3ca66acd38d6b072eab6e9de35361fb7b77a7241df7f` |
| `icones/apps/io.gitlab.theevilskeleton.Upscaler.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/telescope.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/new-sessao-atual/telescope.svg` | GPL-3.0 | 2026-09-16 | `4bfb72775f8ec20dec95283c0952ec532b3619bfe2df6d2b2534fc7de0d79139` |
| `icones/apps/md.obsidian.Obsidian.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/050-circle.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/current/scalable/apps/050-circle.svg` | GPL-3.0 | 2026-09-16 | `03f6930f6935331a75a3bd596a3415d5a6ae78e03ed7a1e61647017911f474db` |
| `icones/apps/menulibre.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/scroll.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/new-sessao-atual/scroll.svg` | GPL-3.0 | 2026-09-16 | `292afff3113b91e08a647ee813c663908d937c7f1d4b8e9437820020d13ed860` |
| `icones/apps/net.waterfox.waterfox.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/firefox.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/upstream/dracula-icons-circle/scalable/apps/firefox.svg` | GPL-3.0 | 2026-09-23 | `a13118bdc6224a5ed393380da1b63d808a0307c5c41c40139087e13291b47a24` |
| `icones/apps/nyx.svg` | `Dracula_OS-Theme` — `src/icons/projects/nyx.svg` (arte própria) | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/projects/nyx.svg` | GPL-3.0 | 2026-09-16 | `68638a101304513870c1d966fcded9e3fb8e6f1f05b91bcc71da0ea75e29fd26` |
| `icones/apps/org.gnome.Calculator.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/org.gnome.Calculator.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/upstream/dracula-icons-circle/scalable/apps/org.gnome.Calculator.svg` | GPL-3.0 | 2026-09-16 | `826461a4c306d4439b5d7875aca0094b5fc3e68d6f9932b4e2b2ea267ca0d5db` |
| `icones/apps/org.kde.krita.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magic-wand-variant.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/new-sessao-atual/magic-wand-variant.svg` | GPL-3.0 | 2026-09-16 | `e224decf0eaa1e64fe0ae190e59750288db80571942da2615506bbcdd2b3000d` |
| `icones/apps/org.onlyoffice.desktopeditors.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/book.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/new-sessao-atual/book.svg` | GPL-3.0 | 2026-09-16 | `19dbc5d86905ce3d275d9f53f5bf2dc0aa4dbfbdc2574a0f749ecbacb04eb80c` |
| `icones/apps/org.qbittorrent.qBittorrent.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/qbittorrent.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/current/scalable/apps/qbittorrent.svg` | GPL-3.0 | 2026-09-16 | `8ec4cb95cd533233513e9b0cc1a08aa60dd086fa4034a0fc165ac700f831124b` |
| `icones/apps/org.telegram.desktop.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/telegram.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/current/scalable/apps/telegram.svg` | GPL-3.0 | 2026-09-16 | `d77779cd1bf430e3f81068a1de707240efafa6ea304954fdf16b89f4561cc3a5` |
| `icones/apps/rlogo_icon.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/spell-book.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/new-sessao-atual/spell-book.svg` | GPL-3.0 | 2026-09-16 | `36f6898feb180c5bcd4bfafc4326d6909890d4af36cccab3a0c5d7e0f99cb977` |
| `icones/apps/steam.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam.svg` | `~/Desenvolvimento/Dracula_OS-Theme/src/icons/current/scalable/apps/steam.svg` | GPL-3.0 | 2026-09-16 | `6975830d60507bb85e35f7ee92d340a6f955786427482ae72c3450405f5635ed` |

### Onde cada origem foi reencontrada — e a diferença com o `CREDITOS.md`

Cada linha acima foi achada **pelo conteúdo**, e não pelo nome: o `sha256` de
cada arquivo do pack foi procurado entre os 31.551 SVG de `src/` do
`Dracula_OS-Theme`, e o caminho escolhido quando havia mais de um igual é o que o
`mapping.json` daquele projeto declara como `fonte`. Três tinham gêmeos
idênticos: o Obsidian (`050-circle.svg`, `obsidia3.svg`,
`new-sessao-atual/circle.svg`), o qBittorrent (`qbittorrent.svg`,
`new-sessao-atual/pirate.svg`) e o Telegram (`telegram.svg`, `029-bomb.svg`).

A contagem por origem que sai daqui é **9** de `new-sessao-atual/`, **5** de
`current/scalable/apps/`, **3** do upstream `circle`, **1** de `projects/` e
**1** do `resgatados/` — dezenove. O `CREDITOS.md` diz 8 de `new-sessao-atual/`
e 2 do upstream, somando 17 para 18 desenhos; a diferença de uma linha lá é
anterior a esta sprint, e o terceiro do upstream é o Waterfox, que entrou hoje.

### O Waterfox veste o Firefox-Dracula, e qual dos dois Firefox — 23/09/2026

A decisão que abriu a P28 é *"o Waterfox passa a usar o Firefox-Dracula"*. O
upstream `m4thewz/dracula-icons` tem **dois** Firefox, um por ramo, e o escolhido
foi o do `circle`, por três medições:

1. **É o que está pintado com a paleta Dracula.** O `circle/firefox.svg` usa
   `#ff5555`, `#ffb86c` e `#f1fa8c` — o vermelho, o laranja e o amarelo do
   draculatheme.com. O `main/firefox.svg` mantém as cores de fábrica do Firefox
   (`#ff3944`, `#ffcd34`, `#ff9633`…) e só troca o globo por `#9a46eb`.
2. **É o ramo das outras duas cópias do upstream** que este pack já tinha — a
   Calculadora e o teclado vieram do `circle`.
3. **É o ramo que o `Dracula-Icones` desta máquina consulta primeiro**: o
   `index.theme` dele diz `Inherits=dracula-icons-circle,dracula-icons-main,…`.

O `net.waterfox.waterfox.svg` do upstream **não** serve, e vale dizer por quê: em
`dracula-icons-main` e em `dracula-icons-circle` ele é um link simbólico para
`waterfox.svg` — que é o logo do **Waterfox** (azul, `#13b1d5`), e não o
Firefox. No `main`, pior: o `waterfox.svg` é um link cujo destino é o próprio
texto do SVG, e o `sha256sum` dele responde "arquivo ou diretório inexistente".

**A raposa roxa da lua não saiu do repositório.** Ela é o resgate
`assets/icones/resgatados/net.waterfox.waterfox.svg` (o decalque do
`current/scalable/apps/firefox.png` do `Dracula_OS-Theme`, 838x853) e continua
lá, intacta, como alternativa. O que mudou é que ela deixou de ser o que vence
calado: o `apps-resgatados.map` não a instala mais, e o nome
`net.waterfox.waterfox` tem **uma** fonte — esta.

## Licença, marca e o que a cópia não muda

**GPL-3.0 nas duas origens, medida e não suposta.** O `LICENSE` do
`Dracula_OS-Theme` é a GPL versão 3. O `README.md` do `m4thewz/dracula-icons`
declara *"GPL-3.0 License"* nos dois ramos — o `LICENSE.md` que ele cita não
veio na cópia local do upstream, e isto fica escrito para que ninguém conte com
um arquivo que não está no disco.

**Logo de marca continua sendo da marca.** Chrome, Steam, Telegram, Firefox e
companhia são marcas de quem são; a GPL cobre o desenho recolorido, não o
direito sobre o logotipo. O uso aqui é o de sempre deste repositório: tema
pessoal, sem vender nada.

**O guvcview é a exceção de casa.** Ele veio do acervo `resgatados/` do próprio
MeowSystem em 17/09/2026 (a Câmera veste o desenho dele, por escolha registrada
no `icones/apps.map`), e o resgate de um ícone de pacote herda a licença do
pacote — ver `assets/icones/PROCEDENCIA.md`, seção dos resgatados.

## Para quem for acrescentar uma linha

O `sincronizar` procura a **primeira tabela** cujo cabeçalho tenha as colunas
`arquivo`, `lido de` e `sha256`, e lê cada linha até a tabela acabar. A ordem
das colunas não importa; o nome delas, sim.

- `arquivo` — relativo a este diretório (`packs/dracula/`), e precisa cair
  dentro dele.
- `lido de` — `~/…`, `motor:…` ou caminho absoluto. É só **lido**, nunca
  escrito, e tem de ter a mesma extensão do `arquivo`: comparar um `.svg` com
  outra coisa não é sincronizar.
- `sha256` — os 64 hex da cópia no dia da cópia. Adotar um retoque, ou trazer a
  versão da origem, é trocar este número: é o registro dizendo qual versão foi
  escolhida.

As crases em volta de cada campo são enfeite para quem lê, e o leitor as tira.

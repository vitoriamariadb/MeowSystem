# Sprints do MeowSystem-Theme

Este arquivo é **autossuficiente**: quem for executar uma sprint não precisa de
nenhum contexto de conversa anterior. Cada uma traz o que já foi medido, o que
fazer, em que arquivo, como conferir que ficou certo, e o que pode dar errado.

Última atualização: **09/09/2026**.

---

## AO VOLTAR, COMECE POR AQUI

**Há três sprints ABERTAS, nenhuma executada — planejadas em 09/09/2026:**
[`docs/sprints/2026-09-09-heroic-e-oficina.md`](sprints/2026-09-09-heroic-e-oficina.md).
Sprint **P** (o Heroic grava o tema sem `.css`, e por isso a tela ficou de
fábrica — causa lida no `app.asar` do 2.22.1), Sprint **Q** (o conversor
emite escada, e é a terceira causa do "pixelado") e Sprint **R** (a oficina
com variações, o original ao lado e clique para tirar traço). Cada uma é
autossuficiente; começar por lá. **Q e R estão materializadas em nível de
código** — [`sprint-q-conversor`](sprints/2026-09-09-sprint-q-conversor.md) e
[`sprint-r-oficina`](sprints/2026-09-09-sprint-r-oficina.md). Nada pendente
de logout ou reboot.

O repositório é **público** desde 06/09/2026, e a última leva fechou em
07/09/2026 com três versões publicadas no mesmo dia — **v1.2.2**, **v1.2.3** e
**v1.2.4**. O registro delas, autossuficiente, está em
[`docs/sprints/2026-09-07-acabamento-do-painel.md`](sprints/2026-09-07-acabamento-do-painel.md):
o que mudou, o que a medição derrubou, e como cada número da capa foi obtido.

**O ESTADO DE HOJE, MEDIDO:**

| | |
|---|---|
| `install.sh` | 53 etapas; rodar de novo não escreve um byte |
| `meow doctor` | 47 conferências, "nada a consertar" |
| painel | 109 chaves · 46 ações · 13 páginas de assunto |
| conferência do navegador | **84/84**, console limpo nas catorze páginas |
| suítes de shell | `app`, `seco`, `reversao`, `um-cartao-por-jogo`, `convergencia` — todas passam |

**O QUE ENVELHECEU NESTE ARQUIVO:** tudo abaixo da linha é registro de sprint
**fechada**, e fica como está — é história medida, não plano. Duas coisas que a
leitura de hoje contradiz, e por isso ficam ditas aqui em cima:

- o *"doctor em 41 ok"* da Sprint W é de 01/09; hoje são **46 conferências**;
- o *"falta um logout"* daquela mesma leva **já aconteceu**: o doctor diz
  *"4 marcadores de pé no disco e na sessão"* e o pipewire está em 1.6.8.

**O NOME DA SEÇÃO MUDOU:** o que estas sprints chamam de **«Barra e dock»** é a
página **«Painel e dock»** desde 07/09/2026, e o elemento se chama *painel* em
todo texto de tela. Onde "barra" sobrevive no `meow.conf.exemplo`, é de
propósito: ali é o termo genérico para "painel **ou** dock".

---

## Sprint W — O gato da hora, o menu e a arrumação  ← **FECHADA em 01/09/2026**

Cinco pedidos dela na mesma tarde, e um comando de upgrade que ela queria rodar
sem quebrar nada. Tudo medido, tudo idempotente, tudo com etapa no `install.sh`
e conferidor no `meow doctor` — que passou a ser o critério de "pronto" depois
de ela dizer: *"tudo tem que ser idempotente e autoajustável (script
inteligente) de forma que ele sobreviva sempre. o install e o selfheal devem ser
atualizados inclusive."*

**1. O gato segue o relógio.** Coquinha de dia, Mimir de noite, no botão do dock
E no logo do fastfetch. `LOGO_MODO="hora"` é o novo padrão; `rotacao` e `fixo`
continuam inteiros, e quem tinha `LOGO_ROTACAO="sim"` não muda de comportamento.
Peças: `lib/noite.sh` (a noite da máquina, uma vez só — ela estava copiada em
três lugares), `systemd/meow-gato.{timer,service}` (tique de 5 min, 0,05 s
cada), etapa e conferidor.
> **A medição que destravou:** reescrever o SVG do botão do dock **não muda um
> pixel** — o `cosmic-panel-button` resolve o ícone no arranque. Matar só o
> applet abre um **buraco** no dock. Quem faz o gato aparecer é
> `meow painel reciclar`, em ~6 s. O comentário do `logo.sh` dizia desde 05/08
> que isso não valia a pena "a cada 30 minutos" — e estava certo; o que mudou é
> que agora são **duas trocas por dia**.
> **Provado ao vivo às 18:06 de 01/09**, sem intervenção: o dock virou Mimir
> sozinho na virada.

**2. Avançar e voltar papel de parede.** `meow wallpaper proximo|anterior|carrossel`.
> **A âncora que faltava** estava neste repositório havia semanas, usada para
> outra coisa: `~/.local/state/cosmic/…/v1/wallpapers` guarda a imagem que o
> `cosmic-bg` está mostrando. Com ela, "próximo" deixa de ser adivinhação. O
> cabeçalho do `wallpaper.sh` continua certo sobre o `cosmic-bg` não falar
> D-Bus — o que mudou é o significado de "avançar": fixar a imagem seguinte, com
> prazo (`WALLPAPER_FIXO_TTL`, 30 min) para o carrossel voltar sozinho.

**3. Os dois itens no menu da área de trabalho.** `patches/cosmic-files-wallpaper-menu.patch`
+ `scripts/files_menu.sh`. Ver as armadilhas **5** e **6** do `patches/LEIA-ME.txt`.
> Quem desenha a área de trabalho é o **`cosmic-files-applet`**, não o
> `cosmic-files` — descobrir isso custou um build inteiro. E o binário vai para
> `~/.local/bin`, que vence `/usr/bin` no PATH: o apt não tem o que sobrescrever.

**4. A arrumação do repositório.** 16 diretórios de topo → **9**. A regra:
**`assets/` é o que o projeto DESENHA, `src/` é o que ele COMPILA.** 4206
arquivos movidos com `git mv` (o histórico seguiu). Sumiram `icons/`,
`palette/`, `themes/`, `state/`, `app-themes/`, `wallpapers/` e `zsh/` do topo.
> **A primeira tentativa foi REVERTIDA**, e vale registrar por quê: a regra de
> substituição pegou a palavra solta `zsh` (o shell) em 36 frases de prosa — "o
> prompt do zsh mora em" virou "o prompt do assets/zsh mora em". A cura foi
> exigir que o token venha **seguido de barra** (é diretório, não palavra), com
> uma segunda passada só para os caminhos ancorados em `$RAIZ/`, `$MEOW_RAIZ/` e
> `../`, que a primeira regra excluía de propósito.

**5. Apagar um papel de parede virou banir, e o acervo mudou de casa.** Ela
apagou imagens feias e nada aconteceu — porque havia **três** pastas de papel de
parede, duas delas falsas: `src/wallpapers/` era **fantasma** (só existia no
`.gitignore`) e `wallpapers/` eram 145 MB de cópia byte a byte que **nenhum
script lia**. As imagens saíram; ficaram as três receitas.
> E o buraco real estava no lado certo: `meow wallpaper banir` era permanente,
> apagar à mão de `ativos/` não era. Curado pelo `meow-ativos.path` +
> `reconciliar_sumicos`, com **quatro guardas** (primeira passagem, pasta vazia,
> sumiço em massa, já-banido). **Medido: 4 s** entre apagar e ficar permanente.
> Depois, a pedido dela, o acervo inteiro mudou para
> `assets/papeis-de-parede/` — `~/.local/share/backgrounds/meowsystem` virou
> symlink. Mover a base INTEIRA preservou os links duros das pastas de dia e
> noite (mesmo inode, `nlink=2`, zero duplicação).

**6. O comando grande, rodado e acompanhado.** `apt full-upgrade` + `topgrade` +
`autoremove` + `cargo`: **87 pacotes, 0 removidos**. Tema, ícones, cursor,
terminal, starship, spicetify e o repo `~/.config/zsh` — **intactos**. O único
que quebra é o `cosmic-comp`, e ele se reergue sozinho: o hook
`DPkg::Post-Invoke` → self-heal → `--ensure` → auto-build, disparado às
16:50:31, tentativa 1/3.
> **Uma dívida virou conserto no mesmo dia:** o patch do raio parou de aplicar
> (o upstream reescreveu `layer_radius_hook`) e o build seguiu sem ele, calado,
> porque é `opt`. Quem acusou foi o `meow doctor`. Reescrito, compilado e
> validado como `AURORA-COSMIC-RADIUS-PATCH-2`.

**7. Duas afirmações antigas foram MEDIDAS e corrigidas.** O `wallpaper.sh`
dizia, por escrito, que não dava para medir se o `cosmic-bg` segue link
simbólico "sem apontar a configuração dela para uma pasta de teste, o que esta
sprint não faz". Dava: **ele segue, e desenha a imagem**. E o primeiro teste foi
desfeito em segundos pelo `meow-fundo.path` — a melhor prova possível de que
aquela proteção funciona.

**Fronteira atravessada, com as quatro guardas.** O `logo.source` do
`config.jsonc` do fastfetch (território da Aurora) passou a ser escrito pelo
Meow: uma linha, backup antes, em voz alta, e `FASTFETCH_LOGO_CONF="nao"` para
desligar. O porquê inteiro está em `docs/FRONTEIRA.md`. Autorizado por ela:
*"pode alterar tudo a nível de sistema. incluindo no aurora tá bom?"*

---

> **Contexto histórico da Sprint U, mantido:**

> **Por que o build não foi feito sozinho:** `/usr/bin/cosmic-greeter-start` é
> literalmente `exec cosmic-comp cosmic-greeter`. Um binário ruim tira o desktop
> **e a tela de login** junto, e ela estava trabalhando na máquina. Um build de
> ~4 min é barato; uma tela preta às 2h da manhã, não. O cartão de recuperação
> vem antes: `docs/pesquisas/2026-08-29-modo-leitura-e-botoes.md`, primeira seção.

Em 25/08/2026 as dez que constavam abertas foram
fechadas numa passagem só: **seis executadas** (O, P, Q, R, S, T) e **três que
já estavam feitas e ninguém tinha marcado** (H, J, L). A décima, a **N**, nunca
foi defeito — é só abrir o Spotify.

**A lição que este dia deixou vale mais que o código.** Depois da auditoria de
24/08 ter pego a Sprint M nessa condição, mais **três** apareceram no mesmo
estado. Quatro de dez. O modo de falha não é esquecimento: é que **quem executa
uma sprint escreve o registro DENTRO da seção dela** — o "Achado 3 (11/08)", o
"O que foi feito" — e ninguém volta ao índice no topo. O texto da sprint conta a
execução no passado enquanto a tabela três telas acima ainda diz "ABERTA".

> **Para quem for executar a próxima:** o índice acima é o produto, não a
> anotação. Fechar uma sprint é DUAS edições, sempre — a seção **e** a linha da
> tabela. Uma sem a outra é como o defeito nasce, e nasceu quatro vezes.

### Onde paramos — modo de leitura (29/08/2026, 19h30)

Plano completo em `docs/pesquisas/2026-08-29-modo-leitura-e-botoes.md`; o que ela
abre para decidir é `docs/pesquisas/2026-08-29-modo-leitura.html`, que tem duas
abas. **Nada foi executado** — em 29/08 ela estava a 10% do limite semanal e
escolheu gravar o plano em vez de tocar na máquina.

**AS SEIS ETAPAS ESTÃO FEITAS.** Executadas em 30/08/2026 em cinco frentes
paralelas, uma por arquivo, com a validação medida depois, à mão. Uma segunda onda, em
31/08, corrigiu o que dois revisores acharam. **O registro completo, com as medições e
as três dívidas, é a [Sprint V](#sprint-v--o-modo-de-leitura)** — esta nota aqui é o
estado da conversa, e o índice é o produto.

~~Falta um logout dela.~~ **Não falta.** Medido em 31/08/2026: o `cosmic-comp` vivo
nasceu em `dom ago 30 20:25:53`, depois do build das 04:59, e `/proc/<pid>/exe` carrega
os três marcadores. O shader já está na tela dela.

| etapa | estado |
|---|---|
| **caminho 1** — acender a luz que JÁ está no binário | **morto e melhor**: a luz quente deixou de morar no filtro "Escala de cinza". Ver a etapa 4 |
| 1. os dois números na tela | **feita** · `AURORA-READING-MODE-1` no `/usr/bin/cosmic-comp`, com portão de GLSL 6/6 no compilador da NVIDIA |
| 2. o horário liga sozinho | **feita** · `meow-leitura.timer` armado, de minuto em minuto; `LEITURA_AGENDA="sim"` no conf dela |
| 3. o slider na barra | **feita** · `meow-applet-leitura` **vivo na topbar dela sem logout** — o `plugins_wings` não era inerte, ver abaixo |
| 4. aposentar o night light | **feita** · o bloco quente saiu do binário; "Escala de cinza" voltou a ser cinza |
| 5. o doctor conta a verdade | **feita** · veio de graça com a Sprint U (o verificável `patches`) |
| 6. a dívida do raio de canto | **feita** · veio de graça com a Sprint U (o patch entrou no binário) |

**O achado que muda uma regra escrita neste repositório:** `plugins_wings` **não
é inerte**. O texto de 29/08 usava "só vale no próximo início de sessão" como
razão para a escrita ser inofensiva. Medido às 05:43 de 30/08: o `cosmic-panel`
mantém watch de inotify no diretório e a chave está na lista `must_recreate` —
a escrita **recriou o espaço da topbar na hora**, matando e renascendo TODOS os
applets (código 137), com uma segunda onda 22 s depois que levou os da dock
junto. Painel e dock sobreviveram, mas é a mesma classe de evento que já apagou
os dois. Quem for escrever ali de novo: com backup, e sabendo que a barra pisca.

**Travado em DUAS decisões dela**, as duas de gosto e as duas resolvíveis
arrastando o slider do `.html`: o **teto da textura** e se a **virada do
agendamento é seca ou rampa** (e de quantos minutos).

O que já foi decidido e não se re-litiga: o slider vai de **1000K a 6500K** (a
faixa inteira), o **horário mora dentro do applet** (e o timer lê de lá), e a rota
sem rebuild está **morta e medida** — nem gamma, nem `cosmic-randr`, nem escrever
o `.ron`.

O ícone do editor (`e1`) foi o único item **executado** em 29/08: está instalado
em `48x48/apps` e aparece no próximo login.

---

### O que entrou em 25/08/2026

Seis frentes em paralelo, uma por sprint, cada uma num arquivo próprio; a
integração no `install.sh`, `bin/meow` e `meow.conf.exemplo` foi feita depois, à
mão, para duas frentes não colidirem no mesmo arquivo.

| sprint | o que está na tela dela agora |
|---|---|
| **O** | o `cosmic-term` em Catppuccin Mocha, cursor no `#CBA6F7` dela. `font_size` e `opacity: 96` não foram tocados |
| **P** | cursor `catppuccin-mocha-light` — **não** o `latte-mauve` decidido em 24/08, e o porquê está abaixo |
| **Q** | a Coquinha em ANSI 40×16 no lugar do logo do Pop!_OS, com os 19 módulos em português intactos |
| **R** | `starship` com o preset oficial catppuccin-powerline; o `FZF_DEFAULT_OPTS` global ganhou a paleta que só existia em cinco cópias locais |
| **S** | o carrossel gira sobre **32 dos 54** papéis — só os escuros, entre 18:00 e 07:00 |
| **T** | o relógio perdeu os segundos. O canto direito **não** foi tocado, e a medição explica por quê |

Fecha com `./bin/meow doctor` em **37 verificáveis, 37 verdes** — hoje são
**39**: `painel`, `janelas` e `fundo` entraram no trabalho de 26/08, e o `install.sh`
convergindo em duas passagens.

### As seis coisas que a medição derrubou, e que este arquivo afirmava

Cada linha aqui é um dia que alguém não vai perder de novo:

| onde | o que o texto dizia | o que foi medido em 25/08 |
|---|---|---|
| Sprint P | *"só o **Latte** tem corpo claro"* | **invertido.** Nos flavors de accent o CORPO recebe o accent: `latte-mauve` = `#8839EF`, luminância **87** (o mais escuro dos três); `mocha-mauve` = `#CBA6F7`, **180**. O argumento "some no campo escuro" apontava para o oposto do que foi escolhido |
| Sprint P | *"o `cosmic-comp` lê `org.gnome.desktop.interface`"* | lê, mas **só `color-scheme`**. Para cursor, zero: `strings /usr/bin/cosmic-comp \| grep -c cursor-theme` → 0. **São dois cursores na tela**, e o gsettings alcança só as janelas GTK |
| Sprint Q | *"a Coquinha, em ANSI, a partir de **foto dela**"* | **não existe foto da Coquinha nesta máquina.** Só o SVG de traço. E *"~40×20 células"* **deforma**: a célula do terminal dela é 9,00×23,00 px (1:2,556), então o quadrado é **40×16** |
| Sprint R | *"a causa: `env.zsh:9` tem `ZSH_THEME="agnoster"`"* | o agnoster era carregado na linha 26 e **jogado fora na linha 135**, por um `export PS1` no mesmo arquivo. **Mexer só na linha 9 não mudaria um pixel** |
| Sprint S | *"a luminância média — `identify -format '%[fx:mean]'`"* | `%[fx:mean]` **não é luminância**: pesa R, G e B igual. Um papel com R=0,412 G=0,029 B=0,279 dá 0,240 na crua (15º) e **0,128** na perceptual (2º mais escuro). E `%[fx:luminance]` é pior — é símbolo **por pixel**, avaliado em (0,0) |
| Sprint T | *"seis glifos de ~16px … em **2560px** de largura"* | a tela é **1920×1080 a 105%**. São **cinco** glifos desenhados (o NowPlaying ocioso não pinta nada), em 224px, com 84px de tinta |

### As duas dívidas de 25/08 estão MORTAS — auditoria de 29/08

Esta seção listava duas dívidas ("`lib/desinstalar.sh` apaga o acervo dela" e
"`adicionar` não entra na rotação"). **As duas foram consertadas no MESMO commit
que as escreveu** — `0bdfa43` trouxe a porta `MEOW_APAGAR_ACERVO=1` em
`lib/desinstalar.sh` (o bloco `O ACERVO DE PAPEL DE PAREDE NÃO ENTRA NO LAÇO
ACIMA`) e o `forcar_releitura` em `wallpaper.sh:1340`. A
seção nasceu obsoleta e ficou quatro dias sendo a primeira coisa que alguém lia.

**Cuidado com o nome:** existem DUAS "duas dívidas achadas de passagem" neste
arquivo. As vivas são as do topo — o `.patch` único e o `raio-clampado` — e elas
viraram a Sprint U. Estas aqui, não.

### O que continua sendo dela, e não se toca sem resposta

- **O corte do wallpaper.** A folha está em `~/folha-wallpaper-noite.html`. O
  limiar `0.37` tem motivo medido (é o vale do histograma **e** o `surface2` do
  Mocha, `#585B70` = 0,3603), mas quem julga imagem é ela. Reverter é
  `WALLPAPER_NOITE="nao"`.
- **O cursor.** A folha está em `~/folha-cursor.html`, com os 7 temas sobre
  campo escuro e claro. `mocha-light` é o que a medição sustenta — claro (214) e
  **neutro**, o que o mantém fora da regra da Sprint T. Trocar é uma linha.
- **O canto direito da topbar.** Ver a Sprint T: dos seis applets, **cinco se
  defendem com medição**, e o ganho que a sprint queria já existe de graça.

---

## Sprint H — o gato do dock, agrupado no centro  ← **FECHADA em 11/08/2026**

> **Esta sprint estava marcada como aberta até 25/08/2026, e não estava.** É o
> segundo caso da mesma doença que a auditoria pegou na Sprint M — sprint
> executada e não marcada.
>
> A **opção 1** do texto abaixo foi aplicada em **11/08/2026**, no commit
> `aacdc3c` (*"a arrumacao dos miniaplicativos na GUI nao valia nada -- a ilha
> fundia os tres"*), e o cabeçalho do `scripts/forma.sh` (linhas 65-80) traz o
> motivo escrito por extenso: *"O DOCK SAIU DA ILHA EM 11/08/2026, E O MOTIVO
> NÃO É ESTÉTICO"*.
>
> Medido ao vivo em 25/08, em `com.system76.CosmicPanel.Dock/v1/`:
>
> ```
> expand_to_edges = true                             <- era false
> plugins_wings   = Some((["...CosmicPanelAppButton"], ["...CosmicAppletStatusArea"]))
> plugins_center  = Some(["...CosmicAppList"])
> ```
>
> O gato está **sozinho no segmento inicial**, e o `soulless-launcher` — o
> flatpak de terceiro que ficava entre o gato e a lista de apps — **saiu**. O
> `meow.conf` dela grava `FORMA_DOCK_ILHA="nao"`, que é a chave que sustenta
> isso: qualquer `install.sh` a partir daqui preserva o estado.
>
> **O texto original fica abaixo por valer como registro da causa** — a leitura
> do `layout.rs` continua sendo a explicação de por que a GUI e o layout
> discordavam.


Ela abriu Configurações > Área de trabalho > Dock > Miniaplicativos e mostrou a
tela: **Segmento inicial** = Botão da Biblioteca de Aplicativos. **Segmento
central** = vazio. **Segmento final** = Área de notificação. A configuração está
exatamente como deveria — e mesmo assim o gato aparece colado nos apps, no meio
do dock.

### A causa, lida no fonte (não deduzida)

O `cosmic-panel` está compilado nesta máquina como dependência de outro projeto
dela, e o checkout está em
`~/.cargo/git/checkouts/cosmic-panel-*/26fee6c/cosmic-panel-bin/src/space/layout.rs`:

```rust
let is_dock = !self.config.expand_to_edges()
    || self.animate_state.as_ref().is_some_and(|a| !(a.cur.expanded > 0.5));

if is_dock {
    windows_center = windows_left
        .drain(..)
        .chain(windows_center)
        .chain(windows_right.drain(..))
        .collect_vec();
}
```

Com `expand_to_edges = false`, **os três segmentos viram uma lista só** e o bloco
inteiro é centralizado (`center_pos = layer_major/2 - center_sum/2`). A separação
início/centro/fim continua existindo no arquivo de config — a GUI escreve
direitinho —, mas o **layout a ignora nesse modo**. Não há bug em lugar nenhum: a
GUI e o layout discordam sobre o que os segmentos significam.

Confirmação de segunda ordem: o **default de fábrica** do próprio cosmic-panel
para o Dock já nasce com `expand_to_edges: false` e **tudo** dentro de
`plugins_center` — o upstream nunca projetou o Dock em modo ilha para ter um
botão isolado num canto. Isso só existe no Painel, que nasce com `true`.

### Quem escreveu `false`, e por quê

Nós. `scripts/forma.sh:66` — `FORMA_DOCK_ILHA="${FORMA_DOCK_ILHA:-sim}"` — e o
cabeçalho do script (linhas 27-31) diz o motivo: *"o dock vira ilha (solto E sem
expandir)"*. Foi uma decisão deliberada de 10/08, para o dock não ser uma barra
atravessando a tela com metade vazia.

O `forma.sh` **nunca toca** em `plugins_wings`/`plugins_center`, e os `mtime`
provam: `expand_to_edges` foi escrito às 21:41 pelo script; os arrays de plugin,
às 21:50, pela GUI. As duas configurações estão certas isoladamente. A
incompatibilidade é entre elas.

### Estado medido hoje

| chave (`~/.config/cosmic/com.system76.CosmicPanel.Dock/v1/`) | valor |
|---|---|
| `expand_to_edges` | `false` |
| `plugins_wings` | `Some((["com.system76.CosmicPanelAppButton", "com.github.hmrdsmoke.soulless-launcher"], ["com.system76.CosmicAppList"]))` |
| `plugins_center` | `Some([])` |
| `spacing` | `8` · `padding` `6` · `margin` `8` · `border_radius` `16` · `size` `L` |

**Achado colateral:** há **dois** applets no segmento inicial, não um. O segundo,
`com.github.hmrdsmoke.soulless-launcher`, é um flatpak que **não aparece em lugar
nenhum do repositório** (`grep` por `soulless`/`hmrdsmoke`: zero ocorrências).
Ele fica entre o gato e a lista de apps, a 8px de cada um — contribui para o
"colado" sem ser a causa.

### As três opções, com o preço de cada uma

1. **`expand_to_edges = true` no Dock** (`FORMA_DOCK_ILHA=nao` no `meow.conf`).
   O gato isola de verdade no canto esquerdo. **Preço:** desfaz a ilha — o dock
   volta a ser uma barra larga com metade vazia, que é o problema que o
   `forma.sh` foi escrito para resolver em 10/08.
2. **Uma segunda superfície de painel só para o gato.** Duas ilhas independentes,
   separação real e permanente. **Preço:** é a mudança mais estrutural; criar uma
   entrada nova em `com.system76.CosmicPanel/v1/entries` com o compositor vivo
   não tem garantia de subir sem relogar. Deve ser feito pela GUI, se a versão
   instalada tiver "Adicionar painel".
3. **Só mais respiro** (`spacing` de `8` para `24`–`32`, e tirar o
   `soulless-launcher` do array). **Preço:** mitiga, não resolve — continua sendo
   um bloco único centralizado, só que com espaços iguais entre os três.

**Não há applet de espaçador/separador** em lugar nenhum do sistema — foi
procurado. Não dá para abrir um vão fixo entre segmentos.

### Como conferir que ficou certo

Olhar a tela. Isto é gosto, não medição.

---

## Sprint I — o lançador inteiro em traço  ← **FECHADA em 11/08/2026**

> **O que foi feito, em uma tela.** O lançador tem hoje **41 aplicativos em
> traço de linha**, de **dois** acervos que saem no mesmo dialeto: **16** do
> Arcticons e **25** de `assets/icones/convertidos-apps/`, que é arte do PRÓPRIO
> aplicativo convertida de chapado para traço por um script deste projeto. O
> traço subiu de **1** para **1,75**, um número só para os dois acervos. Quatro
> desenhos são retoque à mão. O `install.sh` **não ganhou etapa nenhuma**: o
> acervo é commitado, como o Arcticons.
>
> A seção **"O que a execução fez"**, no fim desta sprint, lista arquivo por
> arquivo. O texto do meio é o histórico do dia, e continua valendo — ele é o
> que explica por que o escopo virou três vezes antes de fechar.

A frase dela, em 11/08/2026: *"à exceção dos jogos, todos os demais ícones
deveriam ter um ícone próprio nosso desenhado"*.

Isto **revisa a direção de 08/08**, quando ela disse que o Arcticons *"vem pra
apoiar o outro tema principal, não vem pra ser o tema principal"*. Em 10/08 a
unificação levou 35 apps do lançador para Arcticons — e o Arcticons virou, na
prática, o tema principal. A frase de 11/08 fecha esse ciclo: o tema principal
tem de ser **nosso**.

### O inventário, medido

62 `.desktop` visíveis nos cinco diretórios. **21 são jogos** (`X-MeowSystem=jogo-steam`)
e ficam **fora** por decisão dela. Restam **41**:

| categoria | qtde | quais |
|---|---|---|
| **AUTORAL** (pronto) | 2 | FogStripper, Hefesto |
| **AUTORAL + conflito** | 8 | os `com.system76.Cosmic*` — ver Sprint J |
| **ARCTICONS** (a converter) | 28 | lista abaixo |
| **FÁBRICA** (nem tema têm) | 3 | Flatseal, Gradia, Warehouse |

### A correção que ela fez neste texto, no mesmo dia

Ainda em 11/08, lendo o levantamento acima, ela listou o que achava que faltava:
*"tipo da loja, gradia, warehouse, arquivos, flatseal, reprodutor, terminal,
whatsapp"*.

Quatro desses — **Loja, Arquivos, Reprodutor e Terminal** — a tabela dá como
**prontos**, com desenho autoral em `assets/icones/autorais/`. Ela olhou para eles na
tela e **não os reconheceu como nossos**.

Isso não é engano dela. É o achado desta sprint, e ele muda o escopo:

> **Ter desenho autoral não é o mesmo que ter identidade.** A Loja é uma sacola
> de compras. Os Arquivos são uma pasta. O Reprodutor é um botão de play. O
> Terminal é um `>_`. São as silhuetas que **qualquer** tema de ícone usa — o
> desenho é nosso no sentido de que o geramos, não no sentido de que se
> reconhece como nosso ao olhar.

O gerador diz isso de si mesmo sem perceber que era um problema
(`gerar_icones_autorais.py:266-268`): *"A silhueta mais reconhecível que existe —
não há o que inventar."* Escolher a silhueta mais reconhecível **é** escolher a
mais genérica.

**Consequência para o escopo:** os 8 `com.system76.Cosmic*` deixam de ser "já
prontos" e entram na sprint. O trabalho passa de **31** para **39** ícones —
28 Arcticons + 3 de fábrica + 8 redesenhos.

E entra uma pergunta que precede todo desenho, e que é dela:
**o que faz um ícone parecer do MeowSystem?**

### A segunda correção dela, e esta desmonta a sprint inteira

Meia hora depois, ela mandou uma captura do lançador aberto e uma frase:
*"no sentido de criarmos icons igual o nosso tema atual, entende?"*

**A pergunta acima já estava respondida, e a resposta não era a que este texto
supunha.** Não se trata de dar personalidade a cada aplicativo. Trata-se de
**coerência de estilo**.

Na captura, os ícones em Arcticons — Ajustes, Ampliar, Apostrophe, Boxy SVG,
Brave, Calculadora, Captura de Tela, Câmera, Discord, File Roller, BleachBit —
formam visivelmente um conjunto: **traço de linha fino, sem preenchimento, cor
pastel Catppuccin**. O que salta aos olhos é o que está **cheio** no meio deles.
E o mais gritante é o "Arquivos": a pasta mauve chapada.

Que é, exatamente, a "pasta rosa" da queixa original. As duas frases dela eram a
mesma frase.

**Consequência, e ela inverte o diagnóstico anterior:**

> O "nosso tema" **não é** o desenho autoral. É o **traço**.
>
> O desenho autoral atual — formas chapadas com contorno universal — é o que
> está fora do padrão. Ela olhou a Loja, os Arquivos, o Reprodutor e o Terminal
> e não os reconheceu como nossos **não por falta de personalidade, mas por
> serem cheios num lançador de linhas**.

O escopo vira outro, e encolhe:

| antes se pensava | agora se sabe |
|---|---|
| 39 ícones a desenhar, um a um, com identidade própria | os 28 em Arcticons **já estão no padrão** — não se mexe |
| os 8 `com.system76.Cosmic*` estão prontos | os 8 estão **fora** do padrão: são chapados |
| FogStripper e Hefesto são a régua | a régua é o **conjunto Arcticons**; os dois autorais é que destoam |
| trabalho de desenho, um por vez | trabalho de **conversão de estilo**, possivelmente em lote |

**O que de fato está fora do padrão hoje:**
1. os 8 `com.system76.Cosmic*` (chapados) — inclui Arquivos, Terminal, Loja, Reprodutor
2. FogStripper e Hefesto (chapados) — **mas são desenho dela; pode ser exceção deliberada, e a decisão é dela**
3. Flatseal, Gradia e Warehouse (crus de fábrica)

### A pergunta dela que virou o caminho principal

No mesmo dia: *"será que não temos um script pra converter todos os icons, seja
png ou svg, pra virar só a linha de contorno?"*

Com o escopo corrigido acima, **essa deixou de ser uma alternativa e passou a ser
a via principal**. Se um conversor levar formas chapadas ao traço com qualidade,
ele resolve os itens 1 e 3 de uma vez, sem 39 desenhos à mão.

O que precisa ser medido antes de acreditar nisso (está sendo, em paralelo):
- o alvo não é abstrato: `assets/icones/arcticons-apps/` tem 39 SVGs com grade,
  `stroke-width` e terminações medíveis. É esse peso que a saída tem de imitar.
- o teste honesto não é o par antes/depois. É **misturar conversões novas com
  Arcticons feitos à mão, sem rótulo**. Se ela não distinguir, funciona.
- e o caso mais duro é `assets/icones/autorais/`, chapado com contorno — é lá que a
  queixa mora, e é por lá que se começa.

E ela mesma já disse onde fica o limite da ideia, na frase seguinte:
*"isso é, se for mais simples, mas dependendo o desenho autoral já resolve
mesmo"*.

Ou seja: **o conversor não é a meta, é a hipótese barata.** Ele só ganha se for
de fato mais simples E o resultado passar despercebido no meio dos Arcticons. Se
o teste sem rótulo denunciar as conversões, o caminho é desenhar à mão, no
estilo de traço — e isso não é derrota, é a segunda opção que ela já autorizou de
antemão.

As duas coisas estão sendo medidas em paralelo, e vão para a **mesma folha**,
lado a lado. Quem escolhe é ela, olhando.

**Nada disso se aplica sem ela ver na folha primeiro.** A regra não mudou.

### O veredito dela sobre o conversor — 11/08/2026, olhando a folha

*"tão todos muito bons"*. **O caminho é o conversor.** Não se desenham 26 ícones
à mão.

Quatro ajustes pedidos, e o quarto é uma ordem de não-fazer:

1. **Engrossar a linha.** *"só engrossaria mais a linha"*. Com uma condição que
   não é dela mas decorre do objetivo: o traço tem de subir **junto** com os 30
   Arcticons que já estão na tela. Se só o convertido engrossar, quebra-se a
   coerência que é a razão de tudo isto.
2. **Boca no GIMP.** O Wilber convertido perdeu o focinho — fronteira de baixo
   contraste que o algoritmo descartou. O GIMP já estava na lista de "retoque".
3. **O Gradia faltou na folha.** E o motivo é real: ele não tem SVG chapado de
   origem — zero no índice Arcticons de 14.996 nomes, ausente do Papirus. Só
   existem o SVG colorido do próprio flatpak e um `-symbolic`.
4. **Bluetooth, wifi e cabo: fica o original.** *"bt tá sem logo, pode deixar o
   original nesse caso. wifi e conexão por cabo também"*.

**Sobre o item 4, medido antes de aceitar** (a ampliação da captura dela): o
Bluetooth **não** está quebrado — é o desenho do Papirus, o símbolo dentro de um
quadrado tipo chip. Wifi e cabo não têm entrada própria na barra dela. Ou seja:
não há ícone faltando a consertar, e a instrução dela é para **não inventar
glifo onde não há origem honesta** — a mesma regra que fez 11 dos 12 órfãos da
Sprint B ficarem no Papirus. Ícone errado mente sobre o que a coisa é.

Isto **confirma** a decisão de 08/08 sobre a barra do painel, e ela deixa de ser
"pendência que ninguém mexeu" para ser escolha reafirmada.

### O que os `-symbolic` do próprio app NÃO resolvem (testado, 11/08)

Ideia que parecia barata para os três sem origem (Flatseal, Gradia, Warehouse):
os três flatpaks trazem um `<app-id>-symbolic.svg`. Rasterizados a 48px ao lado
de três Arcticons recoloridos, o veredito foi imediato: **os symbolic do GNOME
são formas CHEIAS monocromáticas em grade 16**, não traço. Postos no lançador,
virariam manchas pesadas no meio das linhas — exatamente a queixa que originou
tudo isto. **Via descartada, com prova na tela.**

**Prioridade 1 — os 3 de fábrica**, que hoje mostram o ícone cru do app ou do
Papirus: Flatseal, Gradia, Warehouse. (Estes três estão registrados em
`assets/icones/apps-arcticons.map:296-298` como "os que ficam de fora, por honestidade" —
não havia glifo honesto no Arcticons para eles. Com desenho autoral, deixam de
ser exceção.)

**Prioridade 2 — os 28 em Arcticons**, em ordem alfabética: Ajustes (CosmicTweaks),
Apostrophe, BleachBit, Boxy SVG, Brave, btop++, Calculator, Camera, Discord,
File Roller, Foliate, GIMP, GitHub Desktop, Google Chrome, Input Remapper, Krita,
OBS Studio, Obsidian, ONLYOFFICE, ProtonUp-Qt, qBittorrent, Spotify, Steam (o
cliente, não os jogos), Telegram, Thunderbird, Upscaler, VS Code, WhatsApp.

### A gramática visual, que já existe e não se inventa de novo

Está em `scripts/gerar_icones_autorais.py`, e o próprio script se declara na
linha 250: *"Todos partilham o mesmo esqueleto: viewBox de 48, formas chapadas,
traço de ~3px onde há traço, e a cor de identidade em `c['marca']`. O que muda de
um para outro é só a silhueta."*

As regras que **não** se negociam, porque cada uma custou um erro medido:

- `viewBox="0 0 48 48"`, `role="img"`, `<title><nome> — Catppuccin <Flavor></title>`.
- **Silhueta ocupa quase o quadro inteiro.** A 48px, cada pixel de margem é
  presença perdida.
- **Formas chapadas.** `linearGradient` vira sujeira de compressão a 48px.
- **Todo ícone leva contorno.** É a moldura que segura o desenho contra o papel
  de parede claro atrás do dock (erro medido e corrigido: oito ícones sumiam).
- **Zero hex digitado à mão.** Cada forma referencia um **papel** (`sujeito`,
  `tinta`, `contorno`, `folha`…) que resolve por **nome** em
  `assets/paleta/catppuccin.json`. Nome que não existe na paleta faz o script morrer.
- **Papéis são sensíveis a claro/escuro** — `contorno = ("crust", "text")`. É o
  que faz o mesmo desenho funcionar nos 4 flavors sem duplicar lógica.
- **Cor de identidade por app**, não o accent genérico — senão viram N manchas
  mauve do mesmo tamanho.
- **Uma `path` por forma composta.** Formas empilhadas viram degrau de meio pixel
  a 48px.
- **Decide-se olhando o PNG rasterizado a 48px**, nunca o SVG no editor. Foi
  assim que o FogStripper perdeu a "mão se dissolvendo em partículas" (virava
  borrão) e o Hefesto perdeu o "martelo e bigorna".

### A ordem de trabalho

Esta sprint **não começa pelo código**. A regra do projeto vale aqui inteira: a
folha visual vem antes. 31 ícones é volume demais para uma folha só — o caminho é
**por lotes**, cada lote rasterizado a 48px sobre os dois fundos reais (dock
escuro e papel de parede claro em `opacity:0.05`), e ela aprova ou recusa lote a
lote. Um ícone recusado é barato; 31 ícones aplicados e recusados, não.

Sugestão de lote 1: **os 3 de fábrica** (Flatseal, Gradia, Warehouse) — é o
menor lote possível, e serve para calibrar a gramática com ela antes do volume.

### O que pode dar errado

- Trocar `48x48/apps` (dono do `icones_apps_arcticons.sh`) por `scalable/apps`
  (dono do `completar_icones.sh`) sem religar os dois cria **exatamente** o
  problema da Sprint J, multiplicado por 31. Decidir o dono ANTES de desenhar.
- O acervo Arcticons continua sendo de apoio — os ícones convertidos saem do
  `apps-arcticons.map` e entram no gerador autoral. Deixar nos dois lugares é o
  laço eterno que o projeto já pagou mais de uma vez.

### O que a execução fez — 11/08/2026

**O aviso acima virou asserção, e é o achado de método desta sprint.** "Não
deixar nos dois lugares" não podia ficar como recomendação num documento: o
`_conferir_gemeos` do `icones_apps_arcticons.sh` ganhou um terceiro cruzamento
e **ESTOURA com código 2** se um nome aparecer nos dois mapas de traço. Testado:
`firefox` acrescentado ao mapa novo derruba o script com o nome na tela.

**Arquivos novos**

| arquivo | o que é |
|---|---|
| `scripts/converter_icone.py` | o conversor. Rasteriza a 256 px, quantiza em regiões de cor e traça a **fronteira entre elas** — não a silhueta externa, que apagaria a identidade. Sai no dialeto exato do Arcticons e **não grava `stroke-width`**, de propósito |
| `scripts/construir_convertidos.sh` | dono único de `assets/icones/convertidos-apps/`. `--conferir`, `MEOW_DRY_RUN`, `meow_escrever`, remove órfão, e **o retoque à mão vence a conversão e nunca é sobrescrito** |
| `assets/icones/apps-convertidos.map` | 25 linhas, `nome : origem : cor [ : parâmetros ]`. **Um mapa, dois leitores**: o gerador lê 1/2/4, o instalador lê 1/3 |
| `assets/icones/convertidos-apps/` | o acervo gerado, **commitado** — 25 SVGs |
| `assets/icones/convertidos-apps/retoques/` | GIMP (boca aberta + a variante discreta), Gradia, Flatseal, Warehouse, e o `LEIA-ME.txt` com a medição |

**Arquivos mudados**

| arquivo | mudança |
|---|---|
| `scripts/icones_apps_arcticons.sh` | lê os **dois** acervos (aditivo). `_vestido()` **não mudou uma linha** — a conversão sai no mesmo dialeto. `TRACO` de `1` para `1.75`. Continua dono único de `48x48/apps` |
| `assets/icones/apps-arcticons.map` | 22 nomes saíram para o mapa novo; 16 ficaram, cada um por medida |
| `bin/meow` | `chk_convertidos`, dentro de `SEM_CONSERTO` |
| `assets/icones/PROCEDENCIA.md` | o acervo novo, a herança **GPL-3.0** do Papirus, e os desenhos à mão |
| `install.sh` | **nada.** Confirmado por ela: "Nenhuma etapa nova no install" |

**O peso 1,75 é medido, não escolhido.** A régua é a **contra-forma que
sobrevive** — quantos dos buracos fechados do desenho original ainda existem
depois de engrossar. O empastamento deixou de servir porque traço de 2 px tem
miolo próprio, e todo pixel de miolo tem 8 vizinhos com tinta: a mediana dos 39
Arcticons vai de 3,0% a 1,0 para 47,3% a 2,0 sem que nada tenha se encostado.

| peso | Arcticons | conversão | tinta na caixa (arct/conv) |
|---|---|---|---|
| 1,0 | 100% | 100% | 13,0% / 18,8% |
| 1,5 | 97% | 80% | 19,1% / 24,6% |
| **1,75** | **97%** | **76%** | **21,2% / 27,8%** |
| 2,0 | 97% | 74% | 23,0% / 30,0% |
| 2,5 | 96% | 66% | 26,8% / 35,2% |

Quem limita **não** é o Arcticons (97% de 1,5 a 2,25): é a conversão, densa por
construção. A 1,75 a Spotify ainda tem três ondas e o Wilber ainda tem olho; a
2,0 as duas ondas de cima soldam. Ganho: **+63%** de tinta contra o 1,0.

**Os cinco que perderam e ficaram no Arcticons**, cada um por medida:
`firefox`, `org.kde.krita` e `thunderbird` (orgânicos — a informação está no
preenchimento); `com.boxy_svg.BoxySVG` (a flor vira bolha); `btop` (a conversão
é fiel ao Papirus, e o Papirus é o "B" na placa opaca de que ela reclamou).

**Os três de fábrica deixaram de ser exceção**, mas não pela conversão: os
desenhos à mão ganharam de lado a lado, a 48 px. O Gradia é o único do mapa sem
origem chapada nenhuma — a linha dele diz `mao` no campo da origem.

**Um defeito real foi encontrado e corrigido durante a execução.** A varredura
de órfão perguntava `[ -z "${ORIGEM[$nome]}" ]`, e a linha `mao` guarda origem
vazia de propósito: o Gradia recém-gerado foi visto como órfão e **apagado na
mesma passagem**. O conserto é um registro separado (`CONHECIDO`) para a
pergunta "este nome está no mapa?", que não é a mesma que "ele tem origem?".

**A boca do Wilber foi estendida até tocar o pincel**, a pedido dela: *"acho que
falta só a boca do gimp e o pincel se sobreporem"*. No original do Papirus o gato
**segura** o pincel na boca. A primeira tentativa levou a curva para dentro do
corpo do pincel e a boca **deixou de ser boca** — lia-se como continuação do
cabo. Só se viu rasterizando a 400 px; a 48 px não aparecia. O ponto de controle
subiu junto, e o canto do sorriso voltou a subir antes de encontrar o pincel.

### O que NÃO foi feito, e por quê

- **Bluetooth, Wi-Fi e cabo ficam no original.** Ordem dela, e foi medido antes
  de aceitar: o Bluetooth não está quebrado, é o desenho do Papirus; Wi-Fi e
  cabo não têm entrada própria na barra dela. São da **barra do painel**, não do
  lançador.
- **FogStripper e Hefesto não foram tocados.** São desenho dela, e a decisão de
  convertê-los ou não é dela. Continuam nos `INTOCAVEIS` do script.
- **Os oito `com.system76.Cosmic*` continuam com glifo Arcticons.** A conversão
  dos autorais existe e é boa, mas quem decidiu ali foi a **Sprint J**,
  FECHADA em 11/08/2026 — e quem escolheu foi ela. Antecipar seria decidir no lugar dela — o erro que este
  mesmo mapa já registra ter cometido uma vez, hoje de manhã.
- ~~**O `com.system76.CosmicPlayer` continua desenhando a PALAVRA "player".**~~
  **RESOLVIDO em 27/08/2026, e quem escolheu foi ela.** O desenho autoral está em
  `assets/icones/convertidos-apps/retoques/com.system76.CosmicPlayer.svg`, e a linha migrou
  do `apps-arcticons.map` para o `apps-convertidos.map` como `mao`. O
  `com.system76.CosmicEdit` seguiu o mesmo caminho em 29/08 — pelo mesmo motivo:
  era «retângulo com linhas», o ícone de documento de todo tema do mundo.

---

## Sprint J — a pasta rosa, e os dois donos do mesmo nome  ← **FECHADA em 11/08/2026**

> **Terceiro caso de sprint executada e não marcada** (depois de M e H). Os
> Achados 3 e 4 abaixo **são o registro da execução**, feita em 11/08/2026 — o
> texto conta o conserto no passado e mesmo assim o topo do arquivo continuava
> listando a sprint como aberta.
>
> Conferido ao vivo em 25/08, com o critério que o próprio "Como conferir"
> desta sprint define:
>
> ```
> 48x48/apps/    CosmicEdit CosmicFiles CosmicMonitor CosmicPlayer
>                CosmicScreenshot CosmicSettings CosmicStore CosmicTerm
>                meow-whatsapp                       <- 9 nomes, todos em traço
> scalable/apps/ CosmicAppLibrary CosmicPanelAppButton  <- só os 2 botões do dock
> ```
>
> **Exatamente um caminho por nome**, e os 9 são traço: `fill="none"` com
> `stroke=` na paleta. Os únicos `fill` de cor são os três pontinhos de `r=0.75`
> do glifo do Monitor, como o texto previa. O Gestor de Arquivos hoje é glifo de
> linha em `#B4BEFE` (lavender) — **a pasta mauve chapada que ela reclamou não
> está mais na tela**, e com ela morreu o item 2 ("decisão dela"): não há mais
> pasta para decidir se continua pasta.


Frase dela: *"o desenho da pasta do sistema operacional ainda é a mesma pasta
rosa"*.

### Achado 1 — ela está certa, e é de propósito

O ícone do Gestor de Arquivos (`com.system76.CosmicFiles`) **é** uma pasta
genérica. O comentário do próprio gerador diz isso com todas as letras
(`scripts/gerar_icones_autorais.py:266-268`): *"Pasta. A silhueta mais
reconhecível que existe — não há o que inventar."*

E a cor foi escolhida deliberadamente como o **accent** (mauve), não uma cor de
identidade própria — `gerar_icones_autorais.py:80-85`: *"a única exceção é o
Gestor de Arquivos, que usa o ACCENT — porque as pastas dentro dele já são
`cat-<flavor>-<accent>`"*.

O raciocínio é coerente por dentro e **falha por fora**: o ícone do aplicativo
ficou visualmente indistinguível de uma pasta qualquer. Some a Lixeira do dock,
que é o ícone do Papirus recolorido no **mesmo** mauve por `construir_pastas.sh`,
e o efeito é "tudo é a mesma mancha rosa".

### Achado 2 — há dois SVGs diferentes para o mesmo nome, agora

| arquivo | desenho | cor | quem escreveu |
|---|---|---|---|
| `MeowSystem-Icons/scalable/apps/com.system76.CosmicFiles.svg` | pasta cheia, autoral | `#CBA6F7` mauve | `completar_icones.sh` |
| `MeowSystem-Icons/48x48/apps/com.system76.CosmicFiles.svg` | glifo de linha Arcticons | `#B4BEFE` lavender | `icones_apps_arcticons.sh` |

Nenhum dos dois foi escrito por engano — cada script escreveu na pasta de que é
dono, como `install.sh:629-633` manda. Só que **ninguém religou os dois**, e o
tema ficou com duas verdades. Qual vence depende do tamanho pedido: a exatamente
48px ganha o lavender; em qualquer outro tamanho cai no `scalable` e ganha o
mauve. O `strace` de 08/08 (registrado neste arquivo) já mostrou que a pilha
COSMIC costuma ir direto no `scalable` — é o mauve que está na tela dela.

**Isto vale para os 8 apps `com.system76.Cosmic*`, não só o Files.** Todos têm
autoral em `scalable/apps` e Arcticons em `48x48/apps`.

### O que fazer

Duas coisas separadas, e a segunda depende dela:

1. **Código, sem perguntar:** resolver o conflito de donos. Uma verdade só por
   nome. ~~Os 8 nomes `com.system76.Cosmic*` têm desenho autoral — devem **sair**
   do `assets/icones/apps-arcticons.map`.~~ **Feito e DESFEITO no mesmo dia — ver abaixo.**
2. **Decisão dela:** o Gestor de Arquivos continua sendo uma pasta? Se sim, ao
   menos **sai do accent** e ganha cor de identidade própria, como os outros
   sete, para não se confundir com as pastas de verdade nem com a Lixeira. Se
   não, precisa de silhueta nova — e aí entra na folha da Sprint I.

### Achado 3 — o conserto estava certo e o vencedor estava errado (11/08/2026)

O item 1 acima foi executado na manhã de 11/08 (commit `aacdc3c`): as 8 linhas
saíram do `assets/icones/apps-arcticons.map`, o autoral em `scalable/apps` ficou como
verdade única. **O diagnóstico estava certo; a escolha do vencedor estava
errada, e a prova está neste próprio arquivo.**

O raciocínio da remoção foi: *"o Arcticons é acervo de APOIO — decisão dela, de
08/08 —, e apoio preenche lacuna, não disputa nome que já tem dono."* A frase é
verdadeira e não se aplica: em **10/08** ela aprovou na folha
(`scripts/folha_proposta.py:79-91`) exatamente estes 8 glifos de linha, um a um,
com o motivo escrito em cada cartão. Aprovar um a um **não é** o Arcticons
preenchendo lacuna — é ela escolhendo o desenho. A regra de 08/08 tinha sido
substituída pela escolha de 10/08, e eu apliquei a antiga.

E o texto que desmonta a remoção está **acima nesta mesma sprint**, escrito
horas antes: *"O 'nosso tema' não é o desenho autoral. É o traço. O desenho
autoral atual — formas chapadas com contorno universal — é o que está fora do
padrão."* A queixa nominal dela era a **pasta mauve chapada** dos Arquivos, que é
precisamente o autoral que a remoção deixou vencer. A remoção não consertou a
queixa: consolidou-a.

**Devolver as 8 linhas ao mapa não bastava**, e é o que o primeiro conserto não
viu. Com o autoral ainda instalado em `scalable/apps`, o chapado continua
vencendo na tela dela — é o `strace` do Achado 2 outra vez. Então o conserto tem
duas metades, e a segunda é a que faltava:

1. as 8 linhas voltaram ao `assets/icones/apps-arcticons.map`, idênticas ao estado
   anterior a `aacdc3c` (conferido linha a linha contra o git);
2. o `scripts/completar_icones.sh` **parou de instalar** os 8 autorais em
   `scalable/apps` e ganhou uma lista `RETIRADOS` que **remove** os que já estão
   lá. Remoção por NOME, nunca varredura: `scalable/apps` tem três donos, e dois
   dos arquivos que sobram ali (`com.system76.CosmicPanelAppButton` e
   `com.system76.CosmicAppLibrary`, os botões do dock, do `logo.sh`) casam com o
   mesmo prefixo `com.system76.Cosmic*`.

Ficaram **de fora**, e de propósito: o FogStripper, o Hefesto (nos dois nomes) e
o apelido `repoman`. O Hefesto é a logo que **ela** desenhou — autoria dela vence
tema, sempre —, e a decisão sobre esses dois é dela, numa folha ainda pendente.

Os 8 SVGs autorais continuam versionados em `assets/icones/autorais/` e o gerador
continua produzindo-os. Desfazer é mover os 8 nomes de `RETIRADOS` de volta para
`AUTORAL` e tirar as 8 linhas do mapa — nunca só uma das duas coisas, que é
exatamente como o defeito nasceu.

### Achado 4 — a mesma doença fora da lista dos 8: o `meow-whatsapp`

Procurado o padrão, ele tinha um segundo caso. O `assets/temas-de-apps/zapzap/manifesto.sh`
instalava uma **bolha verde cheia** (o `whatsapp-desktop` do Papirus recolorido)
em `scalable/apps/meow-whatsapp.svg`, enquanto o `assets/icones/apps-arcticons.map` traz
`meow-whatsapp:whatsapp:sky` — glifo de **traço** — desde a unificação de 10/08.
Dois donos, mesmo nome, e o `scalable` vencendo pelo mesmo motivo.

Pelo critério dela, vence o traço. O módulo do zapzap parou de instalar a bolha e
passa a removê-la; o que ele continua fazendo é o que só ele pode fazer — gravar
`Icon=meow-whatsapp` no `.desktop`, que é o nome pelo qual a linha do mapa
alcança o app.

**A bandeja não foi tocada, e foi conferido antes:** o ícone da bandeja do ZapZap
nunca passou por este SVG. Ele é `IconPixmap` cru pelo D-Bus (Achado da pesquisa
de 05/08), e foi vestido na **fonte do app** — o `tray_icon.py` do flatpak, mais
a chave `tray_theme=symbolic_light` — como registra o `assets/icones/bandeja.map`.

### Como conferir

```sh
ls ~/.local/share/icons/MeowSystem-Icons/*/apps/com.system76.Cosmic*.svg
ls ~/.local/share/icons/MeowSystem-Icons/*/apps/meow-whatsapp.svg
# exatamente um caminho por nome — e tem de ser o de 48x48/apps.
# Os únicos `com.system76.Cosmic*` que continuam em scalable/apps são os
# DOIS botões do dock (PanelAppButton e AppLibrary), que são do logo.sh.
```

O que sobrou é traço, e isso se mede em vez de se supor — os 9 arquivos têm
`fill="none"` e `stroke="<cor da paleta>"`; os únicos `fill` de cor são os três
pontinhos de `r=0.75` dentro do glifo `osmonitor` do Monitor.

---

## Sprint K — os ícones da bandeja  ← **FECHADA em 11/08/2026**

Frase dela: *"temos o problema do ícone do tray de todos os apps"*.

### A regra que decide tudo (medida em 08/08, revalidada em 11/08)

O protocolo é `org.kde.StatusNotifierItem`, e a ordem de precedência é:
`IconPixmap` presente **vence sempre** → `IconThemePath` preenchido vence o tema
→ só com os dois ausentes e `IconName` preenchido é que o **tema** resolve.

### Estado medido ao vivo hoje

Só **um** item registrado no D-Bus agora: `:1.172` = **qBittorrent**.
`IconName=""`, `IconPixmap` presente em 22×22 e 64×64. Os demais apps não estão
abertos — o item de bandeja só nasce quando o app abre.

Importante para não caçar fantasma: os ~6 ícones que ela vê à direita do painel
(conta-gotas, prancheta, volume, bluetooth, energia) **não são bandeja** — são
applets nativos do COSMIC, dono `icones_sistema.sh`, e **já estão vestidos**
(42 arquivos em `22x22/status`, conferidos).

| app | dá para vestir pelo tema? | por quê |
|---|---|---|
| **Steam** | sim, por substituição de arquivo | regrediu em 10/08 e está **vestido de novo**, agora com dono — ver abaixo |
| **ZapZap** | sim, por substituição na fonte | **intacto**, conferido no arquivo vivo |
| **qBittorrent** | **não** | recurso Qt compilado no binário; `IconName` vazio + `IconPixmap` raster |
| **Spotify** | **não** | `IconThemePath` aponta para dentro do flatpak, somente-leitura |
| **Hefesto** | sim, mas **não se toca** | é desenho autoral dela (Decisão 14) |

### A regressão da Steam — a causa, e por que a hipótese anterior caiu

A hipótese registrada aqui era **bug no nosso passo de escrita** ("copiou o
original por cima do desenhado"), apoiada num intervalo de **11 segundos** entre
o backup e o `ctime`. As duas coisas estavam erradas, e a medição mostra por quê.

**Os 11 segundos não são backup → reversão.** São `birth` → `ctime` do próprio
arquivo (23:29:55 → 23:30:06). O backup foi criado às **23:12:00**, isto é
**17 min 55 s** antes. E aqueles 11 segundos são de uma coisa muito maior: **todo**
arquivo de `public/` nasceu entre 23:29:55 e 23:29:57 e teve `ctime` 23:30:06,
com o `mtime` de dentro do pacote preservado (2004, 2009, 2011, 2024, 2025…).
Não foi *um* arquivo trocado — foi o `public_all.zip` inteiro reextraído.

**Quem desfez foi a própria Steam**, e está escrito com o nome da função em
`~/.steam/debian-installation/logs/bootstrap_log.txt`:

```
[2026-08-10 23:29:48] Verificando a instalação...
[2026-08-10 23:29:48] Verifying all executable checksums
[2026-08-10 23:29:49] BVerifyInstalledFiles: public/steam_tray_mono.png is 2342 bytes, expected 5405
[2026-08-10 23:29:53] Verification complete
[2026-08-10 23:29:54] Extraindo o pacote...
[2026-08-10 23:30:05] Instalando a atualização...
```

**Não foi o Ritual da Aurora**: `grep -rn steam_tray ~/.config/zsh/scripts/` não
devolve uma linha. **Não foi bug nosso**: o `meow.log` não tem nenhuma entrada
com "steam", e nenhum script do repositório citava aquele caminho.

### O conserto: o arquivo passa na auditoria da Steam

O cliente guarda o inventário em `package/steam_client_ubuntu12.installed`:

```
public/steam_tray_mono.png,5405;1407376580;3187707190
                           tam ;  mtime   ;   crc32
```

Os três campos foram conferidos contra o arquivo de fábrica e batem
(`1407376580` = 2014-08-06 22:56:20; `zlib.crc32` = `3187707190`). E o binário
tem as duas armas — `BVerifyInstalledFiles: %s is %lld bytes, expected %lld` e
`bad CRC on %s` —, com os arquivos daquele diretório em modo `0775`, bit de
execução ligado. Reaplicar sem cuidar disso seria assinar uma esteira: **180**
verificações "all executable checksums" e **174** "file sizes only" estão
registradas naquele log, uma por abertura do cliente.

O `scripts/icones_tray_steam.sh` monta o PNG com os **três** campos iguais aos de
fábrica: chunk ancilar privado `meOw` para o tamanho, 4 bytes depois do `IEND`
resolvidos por eliminação de Gauss sobre GF(2) para o `crc32`, e `touch -d` para
o `mtime`. O porquê de cada passo está no cabeçalho do script.

**De quebra, o traço da manobra manual estava errado, e o tamanho prova:** 2342
bytes é exatamente o que o glifo dá a 48 px **sem** `stroke-width`; com
`stroke-width="4"` dá 2429. A troca de 10/08 saiu com o traço padrão do SVG (1 de
48 = 0,33 px na bandeja de 16 px) — o traço fino que o cabeçalho do
`icones_bandeja.sh` avisa que some. O script usa **4**, o número dela.

### O que foi feito

1. Causa achada e provada (acima). Não era bug nosso nem da Aurora.
2. `scripts/icones_tray_steam.sh`, com `--conferir`, `MEOW_DRY_RUN`, backup
   antes de escrever e códigos 0/1/2/3. Ligado no `install.sh`
   (`etapa_icones_tray_steam`) e no `meow doctor` (`chk_traysteam`/`fix_traysteam`,
   linha `traysteam`) — a reversão deixa de ser muda, que era o que o
   `assets/icones/bandeja.map` pedia.
3. Glifo `steam` no acervo, em `assets/icones/arcticons/steam.svg` (38 glifos). **Não
   foi baixado**: já estava em `assets/icones/arcticons-apps/steam.svg`, mesmo pack e
   mesma licença — foi `cp`, pela regra que o `shield` inaugurou. Conferido
   mesmo assim contra o upstream (713 bytes byte a byte idênticos) e registrado
   em `assets/icones/PROCEDENCIA.md`.
4. qBittorrent e Spotify: **não há via**, registrado como limite. (No
   qBittorrent a única alavanca é `Advanced\TrayIconStyle`, já em `MonoDark`.)

### O que fica em aberto, e é decisão dela

O traço **4** é 8,33% da caixa — o peso relativo que ela aprovou na folha da
Sprint A. Na bandeja o ícone é desenhado a 16–17 px, então dá **1,33 px** de
tela, enquanto os simbólicos vizinhos (20 px, traço 4) dão **1,67 px**. Para
igualar em pixel, o número é **5,0**, e é uma linha no topo do script
(`MEOW_TRAY_STEAM_TRACO`). Fica no que ela já aprovou até ela dizer outra coisa.

### Achado solto, a esclarecer com ela

O daemon do **Hefesto** está rodando (PID 1603, `--foreground`) mas **não
registra item de bandeja** no D-Bus. Pode ser normal (modo sem tray) ou bug à
parte. Não é o mesmo problema da vestimenta.

---

## Sprint L — o qBittorrent que abre sozinho  ← **FECHADA em 11/08/2026**

> **Quarto caso de sprint executada e não marcada** (depois de M, H e J), e o
> mais completo: ela estava resolvida em **dois** lugares independentes, e o
> texto abaixo descreve um mundo que não existe mais. Medido em 25/08:
>
> | o que o texto diz | o que está no disco |
> |---|---|
> | *"`~/.config/autostart/org.qbittorrent.qBittorrent.desktop`, sem `Hidden=true`"* | **o arquivo não existe.** Só `openrgb-gloway.desktop` e `ritual_aurora.desktop` |
> | *"a unidade … está `loaded active running`"* | `Loaded: masked` / `Active: inactive (dead)`. O generator **nem gera mais** |
> | *"É o Ritual da Aurora, em `aurora-qbittorrent-config.sh:469-480`"* | **esse código não existe.** As linhas de hoje são o oposto: *"6. autostart: DESLIGADO (ela pediu em 11/08/2026) … Agora o script faz o OPOSTO: remove o arquivo se ele existir"* |
> | *"O conserto: `systemctl --user mask …`"* | **já aplicado à mão em 11/08/2026 09:59** — o link para `/dev/null` está lá com essa data |
>
> **A mecânica que o texto acerta continua valendo**, e foi reconferida: o
> `~/.config/systemd/user` vem **doze** posições antes do `generator.late` no
> `UnitPath`, e abrir o app pelo ícone continua funcionando porque o lançador do
> COSMIC cria um **escopo** (`app-cosmic-<id>-<pid>.scope`), não a unidade
> mascarada.
>
> **O que 25/08 acrescentou** foi transformar um link solto para `/dev/null` em
> política declarada: `AUTOSTART_BLOQUEADOS` no `meow.conf` e o `scripts/autostart.sh`,
> com um verificador no doctor. O mask que já existia **não** é desfeito pelo
> `remover` — está anotado como "mascarado por fora".


Frase dela: *"o qbtorrent segue iniciando com o sistema operacional"*. O "segue"
é a parte importante: já foi tentado desligar, e voltou.

### A via ativa, medida

`~/.config/autostart/org.qbittorrent.qBittorrent.desktop`, sem `Hidden=true` e
sem `X-GNOME-Autostart-enabled=false`. O `systemd-xdg-autostart-generator` gera a
partir dele a unidade `app-org.qbittorrent.qBittorrent@autostart.service`, que
agora está `loaded active running` — e o `pgrep` confirma o processo vivo.

### Quem cria, e por que apagar não resolve

**Não é o qBittorrent** (o `qBittorrent.conf` não tem chave de autostart; a opção
é `setVisible(false)` fora do Windows). **Não é o MeowSystem** — o
`assets/temas-de-apps/qbittorrent/manifesto.sh:7-46` declara: *"o qBittorrent NÃO é nosso
território"*.

É o **Ritual da Aurora**, em
`~/.config/zsh/scripts/aurora-qbittorrent-config.sh:469-480`:

```bash
if [ ! -f "$AUTOSTART" ] || ! cmp -s "$DESKTOP_SRC" "$AUTOSTART"; then
  cp "$DESKTOP_SRC" "$AUTOSTART"
fi
```

Esse `cmp -s` é o motivo de a tentativa anterior não ter pegado: qualquer edição
no arquivo (inclusive `Hidden=true`) vira "diferente da fonte" e é **recopiada por
cima, em silêncio**. O script roda pelo `ritual-aurora-self-heal.timer` (unidade
de sistema, cadência ~1h) e por `/etc/apt/apt.conf.d/99-ritual-aurora-self-heal`
depois de **todo** `apt`.

### O conserto — e a trava que ele respeita

`~/.config/zsh` está na lista de vizinhos da **TRAVA 1** (`lib/comum.sh:90-99`).
O MeowSystem **não pode** escrever lá, e não vai. Consertar na raiz (editar o
bloco "6. autostart" do script da Aurora) é decisão dela, feita por fora.

O conserto que **funciona sem tocar em território proibido**:

```sh
systemctl --user mask app-org.qbittorrent.qBittorrent@autostart.service
```

O mask cria um link para `/dev/null` em `~/.config/systemd/user/`, que tem
prioridade **maior** que `/run/user/1000/systemd/generator.late/`. A Aurora pode
seguir recopiando o `.desktop` para sempre — vira trabalho perdido e inofensivo,
porque o mask bloqueia a **ativação**, não a geração. Abrir o app pelo ícone
continua funcionando normalmente.

**Não** editar `Hidden=true` no `.desktop`: some em até 1h ou no próximo `apt`.

---

## Sprint M — o carrossel que não volta  ← **FECHADA em 11/08/2026**

> **Esta sprint estava marcada como aberta até 25/08/2026, e não estava.** A
> auditoria de documentação daquele dia pegou: a opção "**Recomendada: a 1**" do
> texto abaixo — a allowlist `WALLPAPER_FONTES_DELA` / `meow wallpaper permitir`
> — **foi implementada em 11/08**, no mesmo dia em que a sprint foi escrita.
> `scripts/wallpaper.sh:394` diz, no próprio código: *"O TERCEIRO CASO ERA
> 'QUALQUER OUTRO LUGAR' ATÉ 11/08/2026"*. A fronteira tem **quatro** casos hoje.
>
> Medido em 25/08, ao vivo: o `output.DP-1` aponta para `.../meowsystem/ativos`,
> e o `meow-wallpaper.service` fecha com `ExecMainStatus=0` — não o código 4 "a
> cada 15 min, para sempre" que o texto descreve.
>
> **O texto original fica abaixo por valer como registro do defeito e do
> raciocínio** — mas ele descreve o passado, não o estado de hoje.

### O texto original da sprint (o desenho foi o que se implementou)

Frase dela: *"o papel de parede voltou a ser o antigo também. novamente"*.

### O estado medido

```
~/.config/cosmic/com.system76.CosmicBackground/v1/output.DP-1   [10/08 18:48]
    source: Path("/home/vitoriamaria/Imagens/Parede_papel/Cyberpunk Neon Cat …jpeg")
    sampling_method: Alphanumeric
```

O `all` está **correto** (aponta para `…/backgrounds/meowsystem/ativos`), mas
`same-on-all` é `false` — então quem manda é o `output.DP-1`, e ele aponta para a
pasta antiga dela.

O timer roda: `meow-wallpaper.timer` está `enabled`/`active`, última execução às
09:35 de hoje. E **devolveu `status=4`**.

### Por que o timer roda a cada 15 min e nunca conserta

O `scripts/wallpaper.sh:306-338` implementa uma fronteira de **três** casos:

```
aponta para o nosso acervo      -> confere, nada a fazer
aponta para a pasta de FÁBRICA  -> é reset programático; conserta (código 1)
aponta para QUALQUER outro lugar -> é ela; não se toca (código 4)
```

O terceiro caso existe por um bom motivo — é o que impede o script de brigar com
ela no dia em que ela escolher uma pasta própria pela GUI. Mas
`~/Imagens/Parede_papel/` **não é** a pasta de fábrica, então cai no terceiro
caso, e o script se cala. Para sempre.

**Falta o quarto caso: a reversão para um estado antigo que ela não escolheu.**
A fronteira sabe distinguir "fábrica" de "não-fábrica"; não sabe distinguir
"escolha dela de agora" de "onde o wallpaper dela estava antes do MeowSystem".

### As opções de conserto

1. **Allowlist explícita.** Só respeita como "escolha dela" um caminho que esteja
   numa chave nova do `meow.conf` (ex. `WALLPAPER_FONTES_DELA`), preenchida por
   `meow wallpaper permitir <caminho>`. Qualquer outro caminho não-nosso é
   reversão e se conserta. **É a que mais respeita a regra do projeto**: ela
   continua dona da decisão, mas a decisão passa a ser dita uma vez, em vez de
   inferida do disco toda vez.
2. **Carimbo de última escrita nossa.** Guardar em
   `~/.local/state/meowsystem/` quando o script escreveu por último; se o
   `output.*` mudou sem ela ter aberto Aparência, é reversão. **Frágil** — não há
   como saber se ela abriu Aparência.
3. **Perguntar uma vez.** O `doctor` mostra o caminho e pergunta. Quebra o modo
   não-interativo do timer.

**Recomendada: a 1.** As outras duas adivinham; essa pergunta.

### Como conferir

```sh
./scripts/wallpaper.sh --conferir ; echo "codigo=$?"
# hoje: 4 (calou-se). Depois do conserto, num caso de reversão: 1 (consertou).
```

E olhar a tela: o carrossel volta a girar de 5 em 5 minutos sobre
`~/.local/share/backgrounds/meowsystem/ativos`.

---

## Sprint N — o Spotify  ← **NÃO É DEFEITO**

Frase dela: *"spotify falta o spicetify"*. Foi medido, e **não falta**.

| conferido | resultado |
|---|---|
| `spicetify` instalado | sim, `2.44.0`, em `~/.spicetify/spicetify` |
| tema no lugar | sim, `~/.config/spicetify/Themes/catppuccin/` (`catppuccin/spicetify @ 1ec645c4`) |
| intenção gravada | `current_theme=catppuccin`, `color_scheme=mocha` |
| **aplicado no disco** | **sim** — `Apps/xpui/colors.css` tem `--spice-text: #cba6f7`, que é o `mauve` do `mocha` |
| backups de fábrica | os 4 batem `sha256 5ec1901f…` |
| versões batem | `[Backup] version` = `flatpak list` = `1.2.92.147.g5b8f9367` |
| `meow apps conferir` | `ok   Spotify em Catppuccin mocha/mauve (via spicetify)` |

**A explicação:** nada dentro de `~/.var/app/com.spotify.Client/` foi tocado
desde **07/08/2026 18:40** — o último fechamento do app. O `spicetify apply`
rodou em **10/08 20:19**, com o app fechado (como o manifesto exige). **Ela
simplesmente não abriu o Spotify desde então.**

### A ação

Abrir o Spotify. Se aparecer Catppuccin, **não mexer em mais nada**.

Se aparecer cinza de fábrica → `meow apps aplicar spotify`.
Se abrir **em branco** → é o cenário 2 do `assets/temas-de-apps/spotify/RECUPERACAO.md`:
`spicetify upgrade && spicetify backup apply`, e se não houver versão nova,
saída limpa via `spicetify restore`.

**A armadilha que destrói o backup de fábrica:** rodar `spicetify restore` com um
backup de versão diferente da instalada copia a UI velha por cima do app novo
**sem mensagem de erro**. Por isso o manifesto recusa agir sozinho quando as
versões divergem. Hoje elas batem, então o risco não está presente — mas passa a
estar no minuto seguinte a um `flatpak update` do Spotify.

---

### O que entrou em 08/08/2026

| o quê | resultado, medido |
|---|---|
| **Sprint B** — órfãos em Arcticons | **1 de 12** passou na regra dura (ONLYOFFICE). Os outros 11 não existem no acervo de 14.996 nomes; ficam no Papirus. Folha: `~/folha-apps-orfaos-2.html` |
| **Sprint C** — pastas | implementada e **recusada por ela ao ver na tela**: `PASTAS_XDG="nao"` é o padrão, e as pastas seguem mauve. O código fica de pé atrás da chave. Folha: `~/folha-pastas-2.html` |
| **Spotify** | módulo novo, pelos *design tokens* do Encore — sem spicetify. **Revertido em 10/08/2026: agora é o spicetify que aplica** e o Meow decide o flavor/acento (`assets/temas-de-apps/spotify/manifesto.sh`, item 0; recuperação em `RECUPERACAO.md`) |
| **WhatsApp** | reaplicado; o `flatpak update` tinha recriado o symlink de export |
| **Nomes no lançador** | 10 nomes encurtados; nenhum truncado |
| **Duplicatas** | Chrome e os dois Syncthing ocultados de novo, e agora o `doctor` confere |
| **Gato do painel** | a rotação saiu do relógio e foi para o **encerramento da sessão** |
| **Carrossel** | fronteira reset-de-fábrica × escolha dela, mais um relógio de 15 min |
| **9 chaves inertes** | o wizard caiu de 31 para 24 perguntas; as 24 são lidas por código |
| **Serrilhado do lançador** | a causa era downscale de 512→48 em tempo de desenho; agora há 48/64/128/256 gerados com Lanczos, por 936 KB. Prova visual, e a regra estava aplicada só no script irmão |
| **As duas lixeiras** | eram os únicos 2 dos 12 nomes fora do accent — cinza, não azuis como o repo afirmava. Recoloridas lendo os tons da pasta vizinha |

### A decisão que continua sendo dela, e só dela

**A barra do painel.** O Arcticons não tem ícone de estado — zero sufixos `-off`,
`-mute`, `-low`, `-high` no índice completo —, então volume, wifi, microfone e
notificações continuam no Papirus. Isso **não é pendência**: em 08/08 ela fechou
a direção com uma frase — *"o arcticons ele vem pra apoiar o outro tema principal
não vem pra ser o tema principal"*. Vestir um estado só faria o ícone mudar de
estilo conforme o volume. Só se mexe nisso se ela pedir.

### Duas coisas que dependem de ela agir, não de código

- **Relogar.** Ícone novo e gato novo só aparecem no próximo login: o
  `cosmic-panel` lê o tema ao iniciar e não o vigia. **Não derrube o painel para
  antecipar isso** — foi o que a deixou sem painel e sem dock duas vezes em
  04/08, numa máquina de uma tela só.
- **A captura de tema velha.** O `doctor` mostra código **4** (divergente por
  escolha dela): ela mexeu em Aparência e a GUI derivou um tema novo. Não é
  defeito e não notifica de madrugada. Para fixar o que está na tela:
  `meow tema capturar mocha-mauve`.

---

## Sprint G — a árvore de tema que nunca foi vestida (`CosmicTheme` **v1**)  ← **FEITA em 08/08/2026**

**Achada em 08/08/2026**, quando ela pediu para "parear os ícones por completo".
Não era sobre ícone: era sobre cor. Foi executada no mesmo dia.

### O que ficou de pé, em uma tabela

| o quê | resultado, medido |
|---|---|
| **A v1 foi aposentada?** | **Não.** As duas árvores estão vivas. Provado pelas watches de inotify em `/proc/<pid>/fdinfo`, sem reiniciar nada: `cosmic-panel` vigia `Dark/v2` + `Light/v2`; `cosmic-ext-applet-drives` e `-clipboard-manager` vigiam `Dark/v1` (inode 3932173) + `Mode/v1`. O `-eyedropper` não vigia árvore nenhuma. Ver `docs/COSMIC-THEMING.md` §4h |
| **A GUI deriva a v1?** | **Não.** `is_frosted` só existe no esquema v1, e **nenhum** dos 41 binários `/usr/bin/cosmic-*` contém essa string. Um derivador de v1 teria de escrevê-la |
| **O campo do sintoma** | é `Dark/v1/background.on`, **não** `background.component.on`. `0.79136145 × 255 = 202 = 0xCA`. O `component.on` é `0.8945329 → 0xE4` |
| **sRGB direto, sem gama** | confirmado em campos exatamente `n/255`: `bright_red` = `1.0 / 0.627451 / 0.5647059` → `#FFA090`; `gray_1` `0.105882354` → `#1B1B1B`; `gray_2` → `#262626` |
| **Conjunto mínimo** | **19 chaves** na `Dark` e **15** na `Light` (a Light/v1 só tem 18 arquivos). Fora, com motivo: `shade` e `accent_text` (já idênticos), `window_hint` e `active_hint` (borda de janela — applet de painel não desenha), `is_frosted` (dela), `corner_radii` (é estrutura, não cor — ver achado abaixo) |
| **Como foi gerada** | `scripts/gerar_tema_v1.py`: substituição dos literais **numéricos de R, G e B** dentro do arquivo do fóssil, com o valor do mesmo caminho na `v2` da captura. Nada de reimplementar a derivação de contraste do COSMIC — era isso que §1 proibia |
| **O alpha** | **não entra.** Fica o do fóssil. Na v2 ele já vem multiplicado pelos dois slideres de Vidro fosco, e a captura é congelada: copiá-lo seria impor o valor fotografado de um controle contínuo |
| **Ritual da Aurora** | a v1 está fora do alcance dele **por estrutura**: a função `temas()` do `aurora-vidro-maximizado.py` exige `transparent_*` no diretório, e a v1 não tem nenhum |
| **Prova no disco** | 393 de 489 campos da v1 viva mudaram; **0 alphas**; os 489 caminhos RON são os mesmos antes e depois |

### O antes e o depois, em hex (`Dark/v1`, ao vivo)

```
accent.base            #E272F8  ->  #CBA6F7    o mauve dela
background.on          #CACACA  ->  #F6F8FF    era o sintoma no painel
background.base        #313250  ->  #313244    surface0 do mocha
background.component.on #E4E4E4 ->  #FFFFFF
icon_button.on         #BEBEBE  ->  #B8BCD4    o ícone dentro do popup
text_tint              #FFFFFF  ->  #CDD6F4    text do mocha
control_tint           #777777  ->  #6C7086    overlay0
palette.neutral_10     #FFFFFF  ->  #CDD6F4
name                "cosmic-dark" -> "catppuccin-mocha"
```

**Por que `#F6F8FF` e não `#FFFFFF`:** a fonte de cor é a `v2` **da captura**, que
é o estado declarado e versionado. A captura está velha (código 4: ela mexeu em
Aparência em 05/08 e a GUI rederivou 9 arquivos de `Dark/v2`). Na captura,
`background.on` é `#F6F8FF`; no disco vivo é `#FFFFFF`. A diferença máxima é
**9/255 num canal** e desaparece sozinha quando ela rodar
`meow tema capturar mocha-mauve`. Ler a v2 **viva** em vez da captura resolveria
o resíduo e quebraria a regra de estado declarado — não valeu a troca.

### O efeito na tela

Os dois applets vigiam a `v1` por inotify, então o `cosmic-config` deles pode
reler sozinho. **Nada foi reiniciado** — e não se reinicia: os dois processos
continuaram vivos (mesmos PIDs) depois da escrita. Se não tiver recarregado, o
valor certo já está no disco e chega no próximo login.

### Achado que sobrou, e é decisão dela

O `corner_radii` da v1 é o de fábrica (`radius_xs/m/l/xl` = 4/16/32/160) e o da v2
é o dela (2/8/8/8), já declarado em `assets/paleta/cosmic-map.json →
estrutura_preservada`. Ou seja: os popups desses dois applets têm cantos de 16 px
onde todo o resto tem 8. É visível, mas é **estrutura, não cor** — ficou fora do
conjunto mínimo de propósito. Para incluir, basta acrescentar `"corner_radii"` à
lista `CONJUNTO` de `scripts/gerar_tema_v1.py`.

Idem `active_hint` (v1 = 3, v2 = 4): é espessura de realce de janela ativa, que um
applet de painel não desenha. Não vale a escrita.

---

### O texto original da sprint (a medição continua válida)

**O que está medido.** O COSMIC tem duas árvores de tema derivadas, `v1` e `v2`.
O projeto veste a `v2` e **nunca tocou a `v1`** — e a `v1` desta máquina é
anterior ao projeto:

```
mtime  v1/accent      2026-04-12      v1/accent.base  = #E272F8  (um magenta)
mtime  v1/background  2026-05-20      v2/accent.base  = #CBA6F7  (o mauve dela)
mtime  v2/accent      2026-08-05
```

E as **quatro capturas** de `assets/temas/capturados/` carregam o mesmo `v1` fóssil, md5
idêntico — inclusive a `original`. Ou seja: **trocar de flavor ou de accent nunca
mexeu naquela árvore**, e nunca vai, do jeito que está.

**Quem lê a v1, e por isso está com a cor errada na tela dela agora:** os applets
flatpak `dev.cappsy.CosmicExtAppletDrives` e o `clipboard-manager`. Os dois saem
`#CACACA` no painel, contra `#FFFFFF` dos applets nativos — e `#CACACA` é, ao
pixel, o `background.component.on` da v1 (`0.79136145 × 255 = 201,8 = 0xCA`).
Que os floats da v1 são sRGB direto está provado no mesmo arquivo:
`base.red = 0.19223961 × 255 = 49 = 0x31`, e `base` é `#313250`.

**Por que NÃO foi consertado na mesma hora**, e isto é a parte que importa:

1. O `docs/COSMIC-THEMING.md` §1 diz, com medição, **"o que NÃO fazer: escrever
   chave por chave em `Dark/v1`"** — as duas árvores discordam (30 chaves contra
   17, formatos diferentes) e reproduzir uma à mão "gera um tema híbrido que
   *quase* funciona, e o quase só aparece semanas depois".
2. A GUI **não deriva mais a v1** (os mtimes acima provam), então não há o
   caminho barato que o resto do projeto usa: importar uma vez e fotografar.
3. Provar que o conserto funciona exige **reiniciar os applets** dela, na tela
   dela, no meio do uso.
4. O ganho visível é dois applets passando de cinza-claro para branco. Real, mas
   pequeno ao lado do risco de escrever numa árvore legada sem poder testar.

**O caminho, quando for a hora.** Não escrever a v1 à mão: **gerar** a v1 a partir
da paleta, como o `gerar_temas.py` já gera o `.ron` — a fonte de cor continua
sendo `assets/paleta/catppuccin.json` e o mapa de destino, `assets/paleta/cosmic-map.json`.
Depois `--conferir` campo a campo (nunca byte a byte: float contra hex), backup da
v1 vigente porque ela é de terceiro, e um teste com o painel reiniciado **por
escolha dela**, não pelo script.

**O que checar antes de começar:** se uma versão nova do COSMIC já aposentou a v1,
esta sprint morre sozinha — e a medição são os mtimes acima mais um
`strings -a` nos applets flatpak procurando `CosmicTheme.*v1`.

### O que a execução corrigiu neste texto

- O item 3 **caiu**: não é preciso reiniciar nada para provar. As watches de
  inotify em `/proc/<pid>/fdinfo` dizem quem lê o quê num processo vivo, e o
  antes/depois em hex no disco prova o conserto. Os dois applets ficaram de pé,
  mesmos PIDs, depois da escrita.
- O item 4 **subestimava o ganho**: não eram dois applets ficando brancos, eram
  **393 campos** de cor errada, incluindo o accent magenta `#E272F8` em todo
  foco, seleção e realce dos dois popups.
- A receita "gerar a partir de `cosmic-map.json`" **não fecha sozinha**: o mapa só
  declara os slots de TOPO do `.ron`. Os campos derivados da v1 (`hover`,
  `pressed`, `component.*`, `on_disabled`, `divider`…) saem de um algoritmo de
  contraste que vive dentro do COSMIC, e reimplementá-lo seria exatamente o
  híbrido do item 1. A fonte de cor virou a **`v2` da própria captura**, que é o
  produto que o COSMIC derivou do `.ron` gerado da paleta — transitivo, mas ainda
  ancorado em `assets/paleta/catppuccin.json`.
- O `background.component.on` do texto acima é, na verdade, `background.on`.

---

## A leva de 25/08/2026 — o pedido do "ricing"

Ela pediu, textual: *"como podemos melhorar a interface como um todo, meter um
ricing no meu linux, deixar ele agradável e descolado igual os linux que eu vejo
no reddit?"* — e mandou **materializar as sprints, não executar**. Nada abaixo
foi aplicado.

Seis frentes levantaram o terreno em paralelo. O que sobrou de medido está aqui,
porque **metade do trabalho de uma sprint de aparência é saber o que já existe e
o que é impossível** — sem isso, o executor gasta o dia tentando o que o COSMIC
não faz.

### A direção, tirada das referências dela e não de moda

Ela escolheu 5 imagens como referência de papel de parede, e depois apontou 2 de
14 screenshots de desktop: **as duas são pixel art** (um porto ao entardecer e um
templo japonês). Somando as sete, o denominador é um só:

> **campo escuro grande e quieto, coisas pequenas e acesas repetidas, e um único
> sujeito.**

Quatro das cinco referências são noturnas. Cinco das cinco têm **um** ponto focal
e nada mais. Nenhuma tem borda desenhada — o que separa é escuro contra claro. E
o motivo que se repete em três delas é literalmente o mesmo: dezenas de
retanguinhos acesos num campo apagado.

O teste de sucesso, para não virar discussão de gosto: **aperte os olhos até a
screenshot virar borrão. Têm que sobrar no máximo três manchas claras — a janela
em foco, o item aceso da dock e o relógio — sobre campo escuro que chega às
quatro bordas, e nenhum número visível fora do relógio.**

### O que o COSMIC NÃO faz, e o executor vai tentar

Medido lendo `pop-os/cosmic-comp` e as issues, em 25/08/2026. Cada linha aqui é
um dia economizado:

| o que o tutorial promete | realidade |
|---|---|
| blur atrás de **qualquer** janela | o protocolo `ext-background-blur` existe e é **opt-in por app**. Painel, dock, lançador e apps libcosmic pedem; GTK, Qt e Electron não pedem e **nunca** ficam borrados. Issues [#2297], [#1971], [#604], [#1300] |
| animações customizáveis | **hardcoded** no compositor (`RESCALE_ANIMATION_DURATION=150ms`, `MINIMIZE=320ms`), sem chave. [cosmic-comp#376] aberta desde 2024, 31 comentários |
| trocar a barra por waybar | o painel não é substituível. O `wlr-layer-shell` existe, então uma barra externa poderia rodar **ao lado**, nunca **no lugar** — e ninguém relatou fazendo |
| widgets de desktop (eww, conky) | não existe. [cosmic-epoch#3102] |
| regras por janela (opacidade por app) | só **exceção de autotile**, nada além. [cosmic-epoch#847] |
| night light | não chegou. [cosmic-comp#2059], 83 comentários, Epoch **3** |

### A correção que precisa ficar registrada: o vidro fosco JÁ está ligado

Duas leituras se contradisseram, e o erro é instrutivo. Uma pegou
`CosmicTheme.Dark/**v1**/is_frosted` = `false` e concluiu "o fosco está desligado,
é o maior ganho disponível". O outro leu a **v2** e viu `frosted:
ExtremelyHigh2` com os quatro booleanos em `true`.

**O esquema vivo é a v2**, e foi medido de três jeitos independentes:

```
grep -c frosted_panel /usr/bin/cosmic-settings   ->  3   (conhece o esquema novo)
grep -c is_frosted    /usr/bin/cosmic-comp       ->  0   (não conhece o antigo)
```

E a prova visual: uma captura da topbar dela mostra o papel de parede
**atravessando e borrado** atrás da barra. Está ligado, no nível máximo.

**Consequência prática:** "ligar o vidro fosco" não é sprint — já está feito, e o
`assets/paleta/cosmic-map.json` do próprio projeto grava isso na seção
`estrutura_preservada`. **A v1 é legado e mente.** Quem for medir estado de tema,
leia a v2.

**A armadilha que sobra:** 308 dos 350 temas do `cosmic-themes.org` gravam
`is_frosted: false`, e o Catppuccin oficial para COSMIC está parado desde
04/2025 e não conhece as chaves novas. **Aplicar tema de terceiro desliga o
fosco.** Se um dia isso acontecer, a ordem é: aplicar o tema primeiro, religar o
fosco depois.

---

## Sprint O — o terminal está de fábrica  ← **FEITA em 25/08/2026**

> **Executada em 25/08/2026.** `scripts/terminal.sh`, `etapa_terminal` no
> `install.sh`, `chk_terminal`/`fix_terminal` no doctor, `TERMINAL_ESQUEMA` e
> `TERMINAL_CURSOR` no conf.
>
> **O dilema que esta sprint propunha era falso, e é o achado que interessa.** O
> texto mandava medir se a importação da GUI cai em
> `color_schemes_dark` — *"se cai, o projeto pode escrever direto e o módulo é
> trivial"*. **As duas coisas são verdade e não se implicam.** A importação cai
> ali, sim; e escrever o `.ron` do port oficial direto **falha**
> (`Expected opening '{'`), porque o arquivo do port é o **miolo de uma entrada**
> e o de config é o **mapa inteiro** (`BTreeMap<ColorSchemeId, ColorScheme>`,
> `src/config.rs` do commit `032a107`, que é o que gerou este binário). E o
> módulo não é trivial pelo motivo **oposto** ao previsto: o mapa pode conter
> esquemas dela, então escrever exige ler-e-fundir.
>
> Três armadilhas medidas, cada uma capaz de custar uma tarde:
>
> 1. **A chave que SELECIONA é `syntax_theme_dark`/`syntax_theme_light`**, e ela
>    casa por **nome**. O `main.rs` tem um `.or_else()` que cai calado no tema
>    embutido se o nome não bater: nome errado = tela idêntica, sem erro, sem
>    log. Um esquema instalado e não selecionado não muda um pixel.
> 2. **O hex que o `hex_color` serializa é MAIÚSCULO.** Escrever minúsculo criaria
>    pingue-pongue eterno com a GUI, que reescreve o mapa inteiro a cada
>    importação.
> 3. **Nenhum dos quatro `.ron` do port tem `background:`** — de propósito
>    (*"Background comes from theme settings"*). Gravá-lo mataria o `opacity: 96`
>    dela.
>
> E o "como conferir" original estava **duplamente errado**: o port oficial não
> tem `#CBA6F7` em nenhum dos 29 hex, e o magenta do ANSI no Catppuccin é o
> **`pink`** (`#F5C2E7`), não o mauve. Só existe mauve na tela porque o `ACCENT`
> foi levado ao **cursor do terminal** — a única decisão de gosto do módulo, com
> botão de desligar (`TERMINAL_CURSOR="port"`).
>
> **A fronteira que apareceu no meio:** `syntax_theme_*` é o que o seletor de
> *Ajustes → Cores* escreve. Reimpô-la todo dia às 5h seria o defeito que custou
> ao `vidro.sh` a chave `opacity` em 17/08. O script só a escreve quando está
> vazia, de fábrica ou já nossa; se ela escolher outro esquema na GUI, avisa alto
> e não mexe.


**O que ela vai ver.** A janela onde ela passa o dia é a única peça do sistema
que nunca foi vestida.

**A causa, medida.** `~/.config/cosmic/com.system76.CosmicTerm/v1/` tem `font_name`
(JetBrainsMono Nerd Font Mono), `font_size` 16 e `opacity` 96 — mas **não existe**
`color_schemes_dark` nem `color_schemes_light`. A paleta ANSI é a de fábrica do
app. O `scripts/instalar_fontes.sh:173` escreve a fonte e para aí; nenhum script
do projeto escreve cor de terminal.

Ela tem Catppuccin em VS Code, Obsidian, btop, bat, qBittorrent e Spotify. Falta
exatamente onde tudo isso é digitado.

**O que fazer.** Existe port **oficial e específico** para o cosmic-term (não é
adaptação): [`catppuccin/cosmic-desktop`](https://github.com/catppuccin/cosmic-desktop),
pasta `assets/temas/cosmic-term/`, nos 4 flavors.

**A armadilha que decide o desenho da sprint:** o README manda importar pela GUI
(**View → Color schemes… → Import**). Antes de escrever qualquer script, **medir
onde a importação cai no disco** — se ela vira arquivo em
`~/.config/cosmic/com.system76.CosmicTerm/v1/color_schemes_dark`, o projeto pode
escrever direto e o módulo é trivial. Se o formato for opaco, o caminho é o mesmo
das capturas de tema (`assets/temas/capturados/`): importar **uma vez** na GUI e fotografar.

**Como conferir.** `cat ~/.config/cosmic/com.system76.CosmicTerm/v1/color_schemes_dark`
existe e o nome aparece; e a olho: `#CBA6F7` (o mauve dela) no lugar do magenta
de fábrica.

**Não fazer:** não mexer em `font_size` nem `opacity` — os dois são escolha dela,
e o `opacity: 96` já está no ponto.

---

## Sprint P — o ponteiro não tem tema  ← **FEITA em 25/08/2026**

> **Executada em 25/08/2026** — e a decisão de 24/08 **caiu na medição**.
>
> **A premissa estava invertida.** O texto abaixo diz que *"só o Latte tem corpo
> claro"*. Decodificando o XCursor e tirando a luminância do pixel opaco mais
> frequente do ponteiro `default`:
>
> ```
> catppuccin-mocha-light   #CDD6F4   214,3   <- o Text do Mocha
> catppuccin-mocha-mauve   #CBA6F7   179,7
> catppuccin-frappe-mauve  #CA9EE6   172,6
> catppuccin-latte-mauve   #8839EF    86,9   <- o MAIS ESCURO dos três
> catppuccin-mocha-dark    #1E1E2E    31,2
> Pop (o de fábrica)       #FFFFFF   255,0
> ```
>
> Nos flavors de **accent**, o corpo recebe o accent e o contorno a Base — a
> regra `-light`/`-dark` do texto vale só para as variantes neutras. O argumento
> *"cursor escuro sobre campo escuro some"* apontava para o **oposto** do que foi
> escolhido.
>
> **E o segundo argumento também não se sustentava:** a sprint usou *"evita
> brigar com a Sprint T"* a favor do `latte-mauve`. O `latte-mauve` **é** mauve,
> só que escuro; a regra T não distingue mauve claro de mauve escuro. Quem
> escapa dela é o neutro.
>
> **Escolhido: `catppuccin-mocha-light`** — o único que resolve as duas
> restrições, claro (214) e neutro. Está atrás de `CURSOR=` no `meow.conf`, e a
> folha com os 7 temas sobre os dois campos está em `~/folha-cursor.html`. Se ela
> preferir o mauve na tela, é uma linha.
>
> **O achado que mudou o desenho: são DOIS cursores, e o gsettings alcança um.**
> `strings /usr/bin/cosmic-comp | grep -c cursor-theme` → **0**. O compositor usa
> a crate `xcursor` com `XCURSOR_THEME`, **vazia** no ambiente dele, e cai no
> tema `default` — que herda **Adwaita, corpo `#000000`**. O `Pop` que o
> `gsettings get` devolvia governava só as janelas GTK. Por isso o script puxa
> duas alavancas: o gsettings (GTK, vale na hora) e `~/.icons/default/index.theme`
> (compositor, vale no próximo login).
>
> **A fronteira foi respondida com medição, e a resposta é "é nossa"** — está em
> `docs/FRONTEIRA.md`, com os quatro greps. E o `'Pop'` **nunca foi valor
> gravado**: `dconf read` devolve vazio, vem de
> `50_pop-desktop.gschema.override`. Por isso `remover` faz `gsettings reset`, e
> não `set 'Pop'` — repor à mão deixaria valor onde não havia nenhum.


**O que ela vai ver.** O cursor é o único elemento que atravessa a tela inteira o
tempo todo, e é o de fábrica.

**A causa, medida.** O projeto **não escreve tema de cursor em lugar nenhum** —
zero ocorrências fora de `scripts/coleta-meowsystem.sh:158-164`, que é inventário
read-only. É o buraco visual mais visível do inventário.

**O cursor de hoje, medido:** `Pop` — o tema da distribuição. É o mesmo caso da
Sprint Q: a marca do Pop!_OS ocupando o lugar da identidade dela.

**A ESCOLHA, decidida por ela em 25/08/2026: `catppuccin-latte-mauve-cursors`.**
**Latte, não Mocha**, e isso é contraintuitivo o bastante para merecer a linha:
os quatro flavors do Catppuccin diferem no **corpo** do cursor — Mocha, Frappé e
Macchiato têm corpo **escuro**; só o **Latte** tem corpo claro. Com a Sprint S
levando o papel de parede para o lado noturno, cursor escuro sobre campo escuro
some. É por isso que o ponteiro padrão de quase todo sistema é branco.

O `-mauve` mantém o accent dela no detalhe sem virar mancha lilás — o que também
evita brigar com a Sprint T: se **mauve significa "aceso"**, um cursor mauve
estaria aceso o tempo todo. Base: [Volantes](https://github.com/varlesh/volantes-cursors),
GPL-2.0.

**ONDE A CHAVE MORA — E NÃO É ONDE SE ESPERA.** Medido em 25/08:
`com.system76.CosmicTk/v1/` tem `apply_theme_global`, `header_size`, `icon_theme`,
`interface_density`, `interface_font` e `monospace_font` — **não existe
`cursor_theme`**. O `cosmic-comp` lê `org.gnome.desktop.interface` (gsettings) e
as variáveis `XCURSOR_THEME`/`XCURSOR_SIZE`; as duas variáveis estão **vazias**
no ambiente, e o valor em vigor é:

```
gsettings get org.gnome.desktop.interface cursor-theme  ->  'Pop'
gsettings get org.gnome.desktop.interface cursor-size    ->  24
```

**A FRONTEIRA QUE ISSO ABRE, e que precisa ser resolvida ANTES do código:**
`gsettings`/`dconf` aparece em `docs/FRONTEIRA.md:53` como território da Aurora —
mas a linha nomeia **`button-layout`**, não a chave inteira. Ou seja: não está
decidido se `cursor-theme` é nosso ou dela. **Perguntar ao Ritual da Aurora antes
de escrever**, e registrar a resposta no `FRONTEIRA.md`. Escrever primeiro e
descobrir depois é exatamente o modo de falha que mais custou a este projeto
(dois programas no mesmo arquivo).

**A folha visual continua vindo antes do código:** montar o cursor atual (`Pop`) e
2 ou 3 candidatos, sobre fundo escuro e sobre fundo claro, e mostrar. A decisão
acima é da direção, não do desenho — se o Latte-mauve ficar feio na tela, ela
manda.

**Não fazer:** não instalar em `/usr/share/icons` — território travado pela
TRAVA 1 do `lib/comum.sh`. O destino é `~/.local/share/icons/` (que já existe e
já hospeda o `MeowSystem-Icons`) ou `~/.icons/` (que **não** existe hoje).

---

## Sprint Q — o cartão de visita mostra a marca errada  ← **FEITA em 25/08/2026**

> **Executada em 25/08/2026.** `scripts/fastfetch_logo.sh` gera
> `~/.local/share/meowsystem/fastfetch/coquinha.ansi`; o `logo.source` do
> `config.jsonc` — que é da Aurora — foi trocado à mão, anunciado, e os **19**
> módulos com chave própria continuam intactos.
>
> **O teste que podia derrubar a sprint passou:** a Coquinha lê a 40×16 —
> orelhas, olhos fechados, focinho, gravata e o disco arco-íris.
>
> **Três coisas que o texto abaixo erra:**
>
> 1. *"a partir de **foto dela**"* — **não existe foto da Coquinha nesta
>    máquina.** O disco foi varrido: só o SVG de traço, em três caminhos com o
>    mesmo md5. Foi dele que saiu o ANSI. A outra metade da regra continua de pé:
>    nada foi desenhado à mão.
> 2. *"~40×20 células"* — **deforma.** A célula do cosmic-term dela mede
>    **9,00 × 23,00 px** (`TIOCGWINSZ` de uma janela viva), razão 1:2,556. Em
>    40×20 o disco vira elipse. O quadrado é **40×16**, e 40 é justamente a
>    largura do logo `pop` que ele substitui — o bloco de texto não se desloca.
> 3. *"18 módulos"* — são **19** com chave própria, 16 deles traduções.
>
> **O sixel/kitty foi medido, não suposto**, e a decisão dela por ANSI estava
> certa: a DA1 do cosmic-term responde `\e[?6c` (**sem** o `;4` do sixel), a
> query kitty volta vazia, e `strings /usr/bin/cosmic-term | grep -ci sixel` = 0.
> O VTE dele é o `alacritty_terminal`, que nunca implementou nenhum dos dois.
>
> **O `chafa` não foi instalado e não fez falta** — testado, ele produz ASCII de
> 8 cores, pior que o meio-bloco truecolor. O gerador usa `rsvg-convert` +
> `convert` + Python puro. **E o `logo.type` importa:** `file` contamina a saída
> com um `\e[36m` e substitui `$1`..`$9`; o certo é **`file-raw`**.
>
> Se o `.ansi` sumir, o fastfetch cai no logo da distribuição — volta o Pop, sem
> buraco.
>
> **Achado solto:** o repositório já tinha `assets/fastfetch/config.jsonc` e
> `assets/fastfetch/meow.txt`, de 04/08, que **nada instala** e que não correspondem
> ao config vivo. Arquivo morto, e vale decidir se sai.


**O que ela vai ver.** O `fastfetch` dela abre com o logo do **Pop!_OS**, num
desktop que se chama MeowSystem, tem gato no painel e cujo dono tem dois gatos
reais.

**O que já existe** (e o relatório inicial errou — o doc `fastfetch.md` está
desatualizado): o wiring **está feito** desde 21/07/2026 —
`~/.config/fastfetch -> ~/.config/zsh/fastfetch`, config em `config.jsonc`, com
`logo.type: builtin`, `logo.source: "pop"`, cores `magenta` e **18 módulos com as
chaves em português** (SO, Modelo, Tempo Ativo, Tela, Ambiente, Tema, Ícones,
Fonte). É config caprichada; a sprint mexe em **uma** chave.

**Por que agora.** Ela escolheu **pixel art** como direção (das 14 referências,
apontou as duas pixel art). O logo do fastfetch é o único lugar da tela onde arte
grande aparece sem disputar espaço com nada.

**O que medir antes.** O `fastfetch` aceita `logo.type` = `builtin`, `file`
(ASCII/ANSI), `kitty`/`sixel`/`chafa` (imagem de verdade). **Medir se o
`cosmic-term` suporta o protocolo de imagem** — se não suportar, o caminho é ANSI
colorido, que combina melhor com pixel art de qualquer forma.

**A ESCOLHA, decidida por ela em 25/08/2026: a Coquinha, em ANSI, a partir de
foto dela.** Três razões, nesta ordem:

1. **Gato preto é silhueta**, que é o que aparece em quatro das cinco referências
   de papel de parede dela.
2. **ANSI colorido funciona em qualquer terminal**, sem depender de o
   `cosmic-term` implementar protocolo de imagem (kitty/sixel) — o que ainda não
   está medido e, se faltar, derrubaria a sprint inteira.
3. **Sai de foto dela**, não de desenho meu.

O caminho é `chafa` reduzindo uma foto para ~40×20 células. **O teste que decide:**
se a Coquinha ficar irreconhecível nesse tamanho, o plano B é pixel art de acervo
com licença declarada — **nunca** desenhada por mim.

**Não fazer:** **nada desenhado à mão por mim.** Ela reprovou desenho autoral em
05/08/2026 ("sinceramente são péssimos") e estava certa.

**Como conferir.** `fastfetch --pipe false` e olhar; e `config.jsonc` continua
com os 18 módulos em português intactos.

---

## Sprint R — o prompt é de 2010  ← **FEITA em 25/08/2026**

> **Executada em 25/08/2026, nas duas metades.** O `~/.config/starship.toml` é
> nosso (`scripts/prompt.sh`); a linha que liga o starship saiu como
> `assets/prompt/aurora.patch` e foi aplicada à mão no `env.zsh`, anunciado.
>
> **A causa que o texto abaixo dá está errada, e é o achado que interessa.** O
> `ZSH_THEME="agnoster"` da linha 9 é carregado pelo oh-my-zsh na linha 26 e
> **jogado fora na linha 135**, por um `export PS1` no mesmo arquivo. Medido no
> shell vivo: o `$PROMPT` nunca teve um segmento do agnoster. **Mexer só na linha
> 9 não mudaria um pixel** — um tema de 2010 lido a cada abertura de shell para
> não aparecer na tela. O patch mexe nas duas, e o `else` dele devolve
> exatamente o PS1 de hoje se o starship sumir do PATH.
>
> **`starship` não está no apt do Pop!_OS** — confirmado, a sprint acertou.
> Instalado em `~/.local/bin` pelo script oficial, versão 1.26.0.
>
> **Um pirulito escapou por pouco.** O preset oficial não lista `Pop` em
> `[os.symbols]`, e o starship cai no padrão do binário:
> `Type::Pop => "<U+1F36D> "` — um pirulito. E
> a `JetBrainsMono Nerd Font Mono` dela **não tem** o U+1F36D — sairia um emoji
> colorido de outra fonte dentro do retângulo mauve. Trocado pelo glifo do Pop
> que a fonte dela tem, junto com outros três desvios do upstream, todos
> justificados no cabeçalho do `starship.toml`.
>
> **Sobre o `FZF_DEFAULT_OPTS`, o texto erra duas vezes:** a completion **já
> tinha cor** (`env.zsh:41-43` passa a paleta ao fzf-tab); quem rodava sem cor era
> o Ctrl+R, o Ctrl+T, o Alt+C e todo `fzf` na unha. E o `__MEC_FZF_COLOR` não
> está *"só no seletor de modelo"* — a mesma string vive em **cinco**
> lugares, e o seletor citado é de modelo **dbt**, com cópia própria.
>
> **O patch reverte byte a byte** (`patch -R` + `cmp`, conferido). Desfazer é o
> `patch -R` **primeiro** e só depois `prompt.sh remover`: na ordem inversa o
> shell não volta ao prompt antigo, volta ao padrão do starship.


**A causa, medida.** `~/.config/zsh/env.zsh:9` tem `ZSH_THEME="agnoster"` — tema
do oh-my-zsh de 2010, sem segmento assíncrono e sem preset Catppuccin (as cores
teriam que ser portadas à mão). `starship` e `powerlevel10k` **não estão
instalados** (`which` falha nos dois; `starship` nem está nos repositórios do
Pop!_OS — instala por script oficial ou cargo).

**O que fazer.** `starship` com o preset **oficial**:
`starship preset catppuccin-powerline -o ~/.config/starship.toml`
([starship.rs/presets/catppuccin-powerline](https://starship.rs/presets/catppuccin-powerline)),
ou o port dedicado com os 4 flavors ([`catppuccin/starship`](https://github.com/catppuccin/starship)).
Exige Nerd Font — ela já tem.

**A fronteira que decide onde isto mora.** `~/.config/zsh` é **território da
Aurora**, e a TRAVA 1 do `lib/comum.sh` recusa escrita ali por caminho. Então o
MeowSystem **não instala isto sozinho**: ou a sprint entrega um patch para a
Aurora aplicar, ou ela roda um comando. Decidir isso **antes** de escrever
código, não depois.

**Junto, porque é a mesma linha de código:** `FZF_DEFAULT_OPTS`. A paleta
Catppuccin Mocha exata já existe em `~/.config/zsh/functions/mec.zsh:12`
(`__MEC_FZF_COLOR`), usada **só** dentro do seletor de modelo. O `fzf` do
dia a dia (Ctrl+R, completion) roda sem cor nenhuma. É promover uma paleta que
ela já validou de "um script" para "todo uso".

---

## Sprint S — a noite não é o padrão  ← **FEITA em 25/08/2026**

> **Executada em 25/08/2026.** O `wallpaper.sh` mede a luminância de cada imagem
> de `ativos/` e monta `ativos-noite/` e `ativos-dia/` com **link duro** —
> nenhum arquivo é movido, e o acervo continua sendo `ativos/`, que é o que o
> `permitir`, o `banir` e o `semear` conhecem. Chaves: `WALLPAPER_NOITE`,
> `WALLPAPER_NOITE_INICIO`, `WALLPAPER_NOITE_FIM`, `WALLPAPER_LIMIAR_LUZ`.
>
> **O texto abaixo manda medir a coisa errada.** `identify -format '%[fx:mean]'`
> **não é luminância**: pesa R, G e B igual. Um dos papéis, com R=0,412 G=0,029
> B=0,279, dá **0,240** na crua (15º lugar) e **0,128** na perceptual (**2º mais
> escuro do acervo**) — erro de 0,112, mais de duas faixas do histograma. E a
> crua **não tem vale** entre 0,30 e 0,50, ou seja, não oferece onde cortar; o
> único vazio dela daria **45 × 9**, que a própria sprint proíbe.
> **`%[fx:luminance]` é pior ainda** — é símbolo **por pixel**, avaliado em (0,0):
> devolveu 0,0248 numa imagem de luminância média 0,1824. O caminho é
> `-colorspace Gray` antes do `%[fx:mean]`.
>
> **O corte é `0.37`, e não é número redondo por três razões que se apoiam:**
> é o vale do histograma (só **2** imagens entre 0,35 e 0,40, contra 7 em cada
> faixa vizinha); o vale coincide com o `surface2` do Mocha (`#585B70` = 0,3603),
> o tom mais claro que o tema usa como **fundo**; e 0,37 e não 0,36 porque 0,3603
> cai **em cima** de uma imagem (0,3605) — limiar apoiado num ponto de dado é
> limiar que um reencode desempata.
>
> **Calibragem:** o vaporwave que ela baniu mede **0,767**. Só 2 dos 54 são mais
> claros.
>
> **32 na noite, 22 no dia**, e o texto subestimava: *"uma parte é clara"* são
> **41% do acervo**. Os dois lados passam o piso de ~20, mas **a folga está toda
> no lado certo** — o risco é o grupo do dia, com 22. Quem for buscar imagem
> nova, **busque clara**: baixar o limiar para engordar a noite dilui justamente
> o campo escuro que é o ponto da sprint.
>
> Folha de contato em `~/folha-wallpaper-noite.html`. Desligar devolve a rotação
> a `ativos/` e apaga as duas pastas derivadas no mesmo comando.


**O que ela viu.** Em 24/08/2026, olhando a própria tela: o papel de parede era
vaporwave pastel **claro** e saturado, dentro de um sistema Mocha. As duas barras
apareciam lavadas e sem lugar. Ela baniu a imagem no mesmo dia ("esse em
específico eu odiei").

**A causa.** O carrossel não distingue claro de escuro. Dos 54 papéis curados,
uma parte é clara — e cada vez que um deles entra, o desktop inteiro perde o
contraste que o tema pressupõe. **O wallpaper é 95% dos pixels da tela**: sem
campo escuro não existe "aceso", e toda a direção depende disso.

**O que fazer.** Dois conjuntos — `ativos/` continua sendo a rotação, mas o
`wallpaper.sh` ganha a noção de **claro** e **escuro**, e alterna por horário. Ela
usa a máquina à noite (a captura que motivou tudo isto é de 23:57).

**O que medir antes de escrever.** A luminância média de cada um dos 54 — é uma
linha de ImageMagick (`identify -format '%[fx:mean]'`) — e **montar a folha de
contato dos dois grupos** para ela conferir o corte. Um limiar mal escolhido joga
uma imagem boa no grupo errado.

**O risco, que é o de sempre com ela:** se o grupo "noturno" for pequeno demais,
volta o *"sinto como se todos fossem os mesmos wallpapers"*, que é a reclamação
que ela mais repete. Se o corte deixar menos de ~20 imagens de cada lado, é sinal
de que faltam imagens, não de que o corte está errado — e aí a sprint vira busca,
não classificação.

**A dependência da Sprint M caiu.** Quando esta sprint foi escrita, M constava
como aberta e seria pré-requisito — não adianta separar dia e noite se a
configuração é revertida a cada 15 minutos. A auditoria de 25/08 mostrou que **M
foi fechada em 11/08**: a fronteira tem quatro casos e o carrossel está saudável.
**S pode começar quando quiser.**

---

## Sprint T — a regra da atenção  ← **FEITA EM PARTE em 25/08/2026** (o relógio; o canto direito não)

> **Executada em parte, em 25/08/2026**, e a parte que **não** foi feita tem a
> medição melhor.
>
> **O relógio perdeu os segundos.** `scripts/relogio.sh`, com `RELOGIO_SEGUNDOS`
> no conf sob o mesmo contrato das `VIDRO_OPACIDADE_*`: **vazio = não toca**,
> porque a chave tem botão na GUI e a regra do projeto é que ali o valor é dela.
>
> Duas medições que valem mais que a mudança:
>
> 1. **Vale em menos de 2 s, sem reiniciar nada** — provado na tela, com o
>    `cosmic-panel` no mesmo PID. E o mecanismo **não é inotify do applet**: o
>    `cosmic-applet-time` tem **zero** descritores de inotify; ele já acorda 1×/s
>    para desenhar e relê a config na mesma volta. Os seis watches do
>    `cosmic-panel` não incluem `CosmicAppletTime/v1`.
> 2. **APAGAR O ARQUIVO NÃO REVERTE.** Com o `show_seconds` movido para fora, a
>    topbar continuou mostrando os segundos. O texto abaixo diz *"reversível em
>    uma linha"* — é, **se você escrever `true`**. Por isso o `remover` escreve, e
>    o valor de antes ficou em `~/.local/state/meowsystem/relogio/`.
>
> **O canto direito NÃO foi tocado, e a medição explica por quê.** Primeiro, os
> números do texto estão errados: a tela é **1920×1080 a 105%**, não 2560; são
> **cinco** glifos desenhados, não seis — o sexto, o NowPlaying, **não pinta
> pixel nenhum** quando não há música tocando. Medido coluna a coluna no PNG:
> vão de 1666 a 1889 = **224 px**, com **84 px de tinta**.
>
> Segundo, e é o que decide: **dos seis, cinco se defendem com medição.**
> Bluetooth (dois controles DualSense em `/sys/class/power_supply/`, adaptador
> batizado por ela), Rede (ela está em **Wi-Fi**, não em cabo — ícone de sinal é
> informação), Som (desenha os ⏮⏸⏭), Energia (único caminho de desligar pela
> barra) e o NowPlaying (que **ela mesma** pôs ali em 24/08, à mão, com backup).
> O único corte defensável é o **clipboard**, e só depois de ela ganhar um atalho
> de teclado para o histórico — hoje o applet é o único acesso a ele. **O ganho
> que a sprint queria já existe de graça.**
>
> O comando exato do corte, com guardas e backup, está no relatório da execução;
> `plugins_wings` continua da Aurora e **nada foi escrito lá**.


**A ideia.** As referências dela têm **um** sujeito por imagem. A tela dela tem
quatro candidatos a ponto focal e nenhum vence. A regra proposta:

> **mauve significa "aceso", e nada que não esteja aceso pode ser mauve.**

Três lugares no mundo inteiro: a janela em foco, o item ativo da dock, o
workspace atual.

**O que isso implica, e por que é decisão dela.** Hoje o **logo do gato no painel
é o único mauve permanente da tela** — ou seja, o objeto mais chamativo do
desktop é um botão que ela quase nunca aperta. A proposta é ele virar traço na cor
de texto e **acender** mauve só com o menu aberto. Isso é gosto, não técnica: vai
como **mockup**, nunca como commit.

**Os dois cortes baratos que vêm junto:**

1. **O relógio mostra segundos.** É o único elemento da tela que se move uma vez
   por segundo — 86.400 pedidos de atenção por dia para dizer algo que ela nunca
   precisou.
2. **O canto superior direito tem seis glifos de ~16px espalhados por ~200px.** Em
   2560px de largura isso não é informação, é poeira.

**A DECISÃO DELA, em 25/08/2026:** fazer **as duas partes baratas** (segundos e
canto direito) e o logo do gato **só como mockup**, nunca como commit.

**O relógio já está medido, e a chave existe:**

```
~/.config/cosmic/com.system76.CosmicAppletTime/v1/
    show_seconds      = true      <- é esta
    military_time     = true
    first_day_of_week = 6
```

O binário aceita ainda `show_date_in_top_panel` e `show_weekday`. Tirar os
segundos é **uma linha, reversível em uma linha**.

**A ressalva que vale mais que a mudança:** o relógio **tem controle na GUI** do
COSMIC, e a regra do projeto (`docs/FRONTEIRA.md`, a linha "onde a GUI do COSMIC tem um
controle, o valor é dela") diz que onde a GUI tem
controle, **o valor é dela**. Ela autorizou explicitamente em 25/08 — mas quem
executar deve confirmar que a autorização ainda vale antes de escrever, porque
esta é a categoria de chave que o projeto combinou não decidir sozinho.

**O que ainda falta medir:** quais applets da direita podem sair do painel.
**Cuidado de fronteira:** `plugins_wings`/`plugins_center` — a ordem dos applets —
é **território da Aurora** (`docs/FRONTEIRA.md:32`), e o MeowSystem **nunca**
escreveu essas chaves. Mexer ali é conversa com o outro projeto, não commit
nosso. Se a conversa não acontecer, a sprint entrega só o relógio — e isso já
vale, porque é o único elemento da tela que se move sozinho.

**A regra é indivisível.** Se o realce de foco não for configurável, a regra fica
aplicada pela metade — o mauve sumiria dos lugares certos e continuaria nos
errados, que é **pior** do que não aplicar. Ou vai inteira, ou não vai.

---

## A ordem, decidida por ela em 25/08/2026

**T → P → Q**, e o resto quando der.

- **T primeiro** porque as duas partes baratas (relógio sem segundos, canto
  direito enxuto) dão resultado visível **hoje**, com uma linha cada e reversíveis
  em uma linha. Nenhuma das outras cinco tem essa relação.
- **P depois** porque passa por uma folha visual e por uma conversa de fronteira
  com a Aurora (o `gsettings`) — quer dizer, tem espera embutida.
- **Q por último** das três porque depende de um teste que pode derrubá-la: se a
  Coquinha ficar irreconhecível em 40×20 células, o desenho muda.
- **O** (terminal) é código puro e não espera ninguém — pode entrar em qualquer
  buraco entre as outras.
- ~~**S** (dia/noite) depende da **Sprint M**~~ — **esta linha estava errada
  quando foi escrita.** A própria Sprint S, 79 linhas acima dela, já dizia *"A
  dependência da Sprint M caiu … S pode começar quando quiser"*. A auditoria de
  25/08 corrigiu a seção da sprint e esqueceu a seção da ordem — que é, em
  miniatura, o mesmo defeito das quatro sprints fechadas e não marcadas.
- **R** (prompt) é a única que o MeowSystem **não executa sozinho** — mora em
  `~/.config/zsh`, território da Aurora, e sai como patch ou como comando que ela
  roda.

---

## O que ficou de fora, e por quê

Levantado, avaliado e **descartado** — para ninguém gastar tempo de novo:

| item | por que não |
|---|---|
| **dock flutuante** (`expand_to_edges: false`) | é literalmente a **Sprint H** — FECHADA em 11/08/2026, e a decisão foi dela: o mesmo `false` que descola a dock das bordas **funde os três segmentos** e é a causa do gato estar grudado no centro. Não é sprint nova, é a mesma decisão |
| **applets de telemetria** (Minimon, System Monitor) | bem mantidos e reais, mas **nenhuma das sete referências dela tem um único número**. Ela não administra servidor; número no painel é decoração fingindo de utilidade. E instalar exige mexer em `plugins_wings`, que é da Aurora |
| **cava, tmux** | ganho visual que só aparece em screenshot posada. `cava` precisa de um pane dedicado rodando; `tmux` só compensa se ela adotar o fluxo |
| **CuteCosmic** (apps Qt herdarem o tema) | conceitualmente o melhor item do levantamento, mas **não empacotado para o noble** — exigiria compilar contra Qt 6.4.2. Guardar para quando houver pacote |
| **ligar o vidro fosco** | **já está ligado** — ver a correção no topo desta leva |
| **`eza`/`lsd`** | vale, mas é `~/.config/zsh` (Aurora) e o ganho é dentro do `ls`, não na tela. Entra junto da Sprint R se ela quiser |

---

## Como este projeto trabalha (leia antes de qualquer sprint)

**O alvo é uma máquina só.** Em 05/08/2026 foi decidido que o repositório **não
será publicado**: ele existe para deixar o COSMIC da Vitória funcional e bonito.
Acoplar a esta máquina é permitido — caminhos absolutos, `apt`, o uid 987 do
`cosmic-greeter`, os `.desktop` dos jogos dela. O que continua obrigatório é
outra coisa: **não destruir dado dela** e **não brigar com o Ritual da Aurora**.

**Não reinventar a roda.** Regra explícita dela. Preferir pacote pronto de
terceiro a desenhar do zero. Ela rejeitou os ícones autorais que o projeto
gerava ("sinceramente são péssimos") depois de ver a folha de comparação.

**Medir, não supor.** Toda afirmação vem com o comando que a produziu. Uma
conclusão plausível e não medida é o defeito que este projeto mais combate.

**Os códigos de saída são a interface.**

| código | significado | o auto-reparo faz o quê |
|---|---|---|
| 0 | já estava certo | nada |
| 1 | divergia e foi consertado | conserta, e **notifica** |
| 2 | erro de verdade | falha alto |
| 3 | falta dependência | pula, avisa |
| 4 | divergente **por escolha dela** | mostra e **não mexe**, sem notificar |

O 4 existe por causa do timer: `meow-doctor.timer` roda todo dia às 5h e o
`ExecStopPost` notifica **só quando o código é 1**. Um estado que não tem
conserto possível, saindo 1, viraria "o auto-reparo corrigiu" toda madrugada,
sem nada ter sido corrigido. Foi ela quem apontou esse risco.

**Idempotência é conferida, não prometida.** Toda sprint termina com
`./install.sh` duas vezes: a segunda não pode escrever um byte.

**Comparar do mesmo jeito que se escreve.** `meow_escrever` grava com
`printf '%s'`, que come o `\n` final — um `cmp` byte a byte acusa divergência
eterna num arquivo que está perfeito. Já custou um `--conferir` que gritava 123
divergências num tema correto. Se o escritor é `meow_escrever`, o conferidor
compara com `$(cat ...)`; se o escritor é `cp` (binário), aí sim `cmp`.

**Um dono por arquivo.** Dois programas escrevendo o mesmo arquivo é o modo de
falha que mais custou a este projeto (`custom_logo_path`, e o tema derivado da
GUI). Quem não é dono apenas confere.

---

## O acervo de ícones que existe hoje, e o que cada um cobre

**Quatro** fontes, e confundi-las já causou erro. **Leia esta tabela antes de
mexer em ícone.** O Arcticons entrou por último e é o acervo de **APOIO** — ela
fechou a direção em 08/08: *"o arcticons ele vem pra apoiar o outro tema
principal não vem pra ser o tema principal"*.

| fonte | onde | o que é | cobre |
|---|---|---|---|
| `catppuccin/vscode-icons` | `assets/icones/catppuccin/<flavor>/` | 656 glifos × 4 flavors, MIT, linha fina pastel. É o pack do Iconify (`catppuccin:*`) e do allsvgicons — **os três links são o mesmo acervo**. | **tipos de arquivo** e **pastas**. 123 mimetypes instalados. |
| `Daveedmee/catppuccin-icons` | `assets/icones/catppuccin-apps/<macchiato\|latte>/` | 146 PNG 512×512 com alpha. As marcas conhecidas recoloridas em pastel. **Sem licença declarada** — uso local, nunca redistribuir. | **aplicativos**. 16 instalados. |
| Arcticons | `assets/icones/arcticons/` e `assets/icones/arcticons-apps/` | 14.996 nomes, CC BY-SA 4.0, traço monocromático em grid 48. Baixado um a um pela API do Iconify. | os **ícones de sistema** (56, em `<tam>/status`) e os **aplicativos** (41 em `48x48/apps` — o número 1 é de 08/08 e envelheceu). **Não tem estado** — por isso a barra fica no Papirus. |
| desenho autoral | `assets/icones/autorais/` | 10 SVG × 4 flavors, gerados por `scripts/gerar_icones_autorais.py`. | os 8 apps do COSMIC + FogStripper + Hefesto. |

### A correção que precisa ficar registrada

Foi dito nesta conversa que "o pack `catppuccin/vscode-icons` não tem nenhum
ícone de aplicativo, só `figma`". **Isso está errado.** O pack tem pelo menos 23
glifos de marca de software:

```
adobe-ae adobe-ai adobe-id adobe-ps adobe-xd angular django docker figma
gitlab godot go java kotlin laravel npm python rust svelte swift unity vue
```

O que é verdade é outra coisa, e é o que foi de fato medido: **desses 23, só o
`vscode` corresponde a um aplicativo instalado nesta máquina**. Os outros são
marcas de coisas que ela não usa, e no pack eles representam o **formato de
arquivo** (o `adobe-ps.svg` é o ícone do `.psd`, não do programa Photoshop) —
embora nada impeça usá-los como ícone de aplicativo, se um dia ela instalar
Blender, Godot, Unity ou Docker Desktop.

Comando que produz a lista:

```bash
ls assets/icones/catppuccin/macchiato/ | sed 's/.svg$//' \
  | grep -xE 'adobe-.*|figma|docker|gitlab|python|rust|go|java|godot|unity|blender'
```

### O que NÃO se toca, por pedido expresso dela

Os jogos da Steam (`steam_icon_*`), o **Hefesto** (a logo é dela) e o
**FogStripper**. `scripts/icones_apps.sh` recusa esses nomes mesmo que entrem no
mapa — a lista está em `INTOCAVEIS` e `INTOCAVEIS_PREFIXO`.

---

## O achado que destrava as Sprints A e B: **Arcticons**

Foi ideia dela, em duas frases: *"allsvgicons.com não conseguiríamos nenhum outro
pack que pudesse complementar as lacunas do nosso?"* e *"por serem svgs se
acharmos algum que prestasse poderíamos alterar as cores sei lá."*

**Medido em 05/08/2026, pela API do Iconify:**

```
Arcticons · 14.996 ícones · CC BY-SA 4.0
```

> O número aqui dizia **14.913** e divergia dos outros três lugares do repo
> (`assets/icones/PROCEDENCIA.md`, `assets/icones/sistema.map`, a Sprint A) que dizem 14.996.
> Refeito em 08/08 pelo índice completo (`/collection?prefix=arcticons`, não pelo
> `/search`, que é difuso): **14.996 nomes + 304 apelidos**. Os três estavam
> certos; este estava errado.

Licença **livre e que permite modificar** — é o que autoriza recolorir. São
ícones de **linha, monocromáticos**, feitos para nomear aplicativos Android, o
que na prática significa um catálogo enorme de programas e de conceitos de
sistema. Testado contra as lacunas exatas que sobraram aqui:

| lacuna | Arcticons tem? |
|---|---|
| `wifi` `bluetooth` `settings` `volume` `battery` | **sim** — são os ícones de sistema da Sprint A |
| `calculator` `camera` `keyboard` `monitor` `mail` | **sim** — o pack `vscode-icons` não tinha nenhum |
| `thunderbird` `krita` `discord` | **sim**, pelo nome exato |
| `gimp` `flatseal` `boxy` | não |

Comando que reproduz:

```bash
curl -s "https://api.iconify.design/search?query=<termo>&prefix=arcticons&limit=5" \
  | python3 -c "import sys,json;print(json.load(sys.stdin).get('icons'))"
```

**Por que isso muda o desenho das duas sprints.** Monocromático de linha é
*matéria-prima*, não produto acabado: uma cor só, trocável com um `sed` no
`stroke`/`fill`. E este projeto já tem a fonte única de cor — `assets/paleta/catppuccin.json`,
com a regra de que **nenhum hex vive dentro de script**. Recolorir Arcticons para
Catppuccin é o encaixe mais natural que apareceu até agora, e é barato.

### A direção estética, definida por ela olhando as duas telas

Ela comparou a página do Arcticons com o `catwalk.webp` do `catppuccin/vscode-icons`
e fechou o desenho numa frase: *"esse primeiro pack parece que se encaixa legal
no estilo que queremos né? Só precisaríamos deixar as cores mais fortes de acordo
com a logo do app original."*

Isso é **exatamente** o que o `vscode-icons` faz, e é o que dá coerência ao
conjunto: **traço fino monocromático + UMA cor por ícone, escolhida por afinidade
com a marca original.** O Firefox puxa `peach`, o Spotify puxa `green`, o Discord
puxa `blue` — cada um reconhecível, todos na mesma paleta.

O Arcticons é a matéria-prima certa para isso porque já é **traço puro**: o pack
se descreve como *Logos*, grid de 48 px, e vem sem cor própria. Colorir é atribuir
uma cor, não repintar um desenho.

**O método, e ele é automatizável:**

1. para cada aplicativo, pegar a cor dominante da marca real — a fonte natural é
   o ícone que o Papirus já entrega, que é colorido e está no disco
2. converter para **Oklab** e achar a cor Catppuccin mais próxima em matiz, não
   em RGB (este conversor já foi escrito duas vezes neste projeto; a
   pesquisa em `docs/pesquisas/` tem os números)
3. aplicar no `stroke`/`fill` do SVG do Arcticons
4. gerar nos 4 flavors, como todo o resto do projeto

**Duas armadilhas já medidas neste projeto, e as duas mordem aqui:**

- **A paleta não tem cor escura E saturada.** Croma máximo **0,034** entre as
  cores com L < 0,55 no mocha (o 0,039 que estava escrito aqui não existe em
  flavor nenhum; 0,043 é o do latte, medido em 08/08). Marcas escuras (GitHub, Steam) vão para um tom claro ou para um
  neutro — decidir explicitamente qual, e registrar.
- **Duas marcas podem cair na mesma cor Catppuccin.** Já existe um caso no disco:
  com `--accent green`, `cosmic-files` e `cosmic-term` nascem gêmeos em silêncio.
  O gerador precisa de uma asserção que **estoure** quando dois ícones do mesmo
  contexto recebem a mesma cor, em vez de deixar passar.

**Cuidados antes de sair recolorindo:**

- **CC BY-SA 4.0 é _share-alike_ com atribuição.** Uso local não exige nada, mas
  registre a procedência em `assets/icones/PROCEDENCIA.md` como o projeto já faz para
  Papirus e papirus-folders. Se um dia houver publicação, o share-alike passa a
  ter consequência.
- **Baixe pela API do Iconify, não o repositório inteiro** (são ~15 mil ícones).
  `https://api.iconify.design/arcticons/<nome>.svg` devolve um SVG por vez, e
  `?color=%23cba6f7` já devolve **recolorido** — vale medir se isso basta e
  poupa o passo de recolorir na mão.
- **Estilo:** linha fina monocromática ao lado dos ícones pastel cheios do
  lançador. Pode ficar coerente (o painel já é monocromático) ou pode brigar.
  **Folha visual antes**, pelo método da Sprint B, a 22 px e a 48 px.
- Um ícone genérico bem escolhido é aceitável aqui, ao contrário do caso das
  marcas: `settings` para Configurações **não mente** sobre o que a coisa é.

---

## Sprint A — Os ícones do próprio COSMIC  ← **FEITA em 05/08/2026, em parte**

> **O que entrou:** as **21 páginas das Configurações** + 7 ícones únicos, pelo
> `assets/icones/sistema.map` e `scripts/icones_sistema.sh`. Provado com `strace`: o
> `cosmic-settings` carrega os ícones novos do `scalable/status`.
>
> **O que NÃO entrou, e é medição, não desistência:** a **barra**. Os applets são
> famílias de estado (`audio-volume-*` em 5, `network-wireless-*` em 7,
> `microphone-sensitivity-*` em 4) e o Arcticons tem **zero** sufixos `-off`,
> `-mute`, `-muted`, `-disabled`, `-low`, `-high`, `-medium` — medido contra o
> índice completo dos 14.996 nomes. Vestir um estado só faria o ícone mudar de
> estilo conforme o volume. Continua no Papirus.
>
> **O que sobrou para decidir com ela:** se vale desenhar as variantes de estado
> à mão (é desenho autoral, que ela já rejeitou uma vez) ou procurar um terceiro
> pack que as tenha. **Enquanto não houver decisão, a barra fica como está.**
>
> Leia `docs/COSMIC-THEMING.md` §4g antes de mexer: a cor do arquivo é jogada
> fora pelo toolkit, e a escolha de tamanho não é pela ordem de `Directories=`.

### O registro de como a sprint foi conduzida (o histórico abaixo continua válido)

**Por que existe.** Ela mandou a tela das Configurações (Rede, Bluetooth,
Acessibilidade, Área de trabalho, Telas, Som, Energia e Bateria, Dispositivos de
entrada, Aplicativos, Hora e Idioma, Sistema e Contas) e disse: *"até os applet e
icons do próprio sistema operacional quero mudar. Tipo tudo tudo mesmo."* E
reforçou logo depois: *"inclusive os icons do sistema."* Repetir um pedido é o
sinal mais forte que existe neste projeto — **esta sprint tem prioridade sobre a
ordem sugerida no fim do arquivo.**

O alcance é os dois: as **páginas das Configurações** e os **applets da barra**
(bateria, som, rede, bluetooth, notificações, relógio).

**O que já se sabe, e muda a abordagem.** Esses ícones são `symbolic`:
monocromáticos, com uma única cor, **recolorida pelo toolkit em tempo de
desenho**. Não adianta procurar por eles nos dois packs — nenhum os tem, e o
problema não é de mapeamento, é de geração.

**Primeiro passo obrigatório: descobrir de onde eles vêm.** Não presuma.

```bash
# 1. quais ícones a página de Configurações pede
strings -a /usr/bin/cosmic-settings | grep -E '^[a-z-]+-symbolic$' | sort -u

# 2. onde cada um resolve HOJE, no resolvedor real (não com find)
python3 - <<'EOF'
import gi; gi.require_version("Gtk","3.0")
from gi.repository import Gtk
t = Gtk.IconTheme.new(); t.set_custom_theme("MeowSystem-Icons")
for n in ["network-wireless-symbolic","bluetooth-symbolic","audio-volume-high-symbolic"]:
    i = t.lookup_icon(n, 24, 0)
    print(n, "->", i.get_filename() if i else "(nada)")
EOF

# 3. de que pacote vem
dpkg -S /usr/share/icons/Cosmic/scalable/... 2>/dev/null
```

**Decisão a tomar com ela, não sozinho.** Symbolic monocromático **já segue o
tema** — a cor vem do `CosmicTheme`. Então há duas leituras possíveis do pedido:

1. *"estão com a cor errada"* → o conserto é no tema, não nos ícones.
2. *"quero eles coloridos/pastel como os do lançador"* → é desenho novo, e é
   exatamente o caminho que ela rejeitou uma vez ("péssimos").

**Antes de escrever qualquer código, monte uma folha de comparação e mostre a
ela.** Foi assim que a decisão dos ícones autorais foi tomada, e foi assim que se
descobriu que 19 dos 27 candidatos eram logomarca. O método está na Sprint B.

**Risco declarado:** substituir symbolic por colorido no painel pode ficar
poluído — a barra tem 8 ícones em 22px. O que funciona no lançador a 64px não
funciona ali. Rasterize a 22px e olhe antes de propor.

**Como conferir:** `Gtk.IconTheme.lookup_icon` para cada nome, a 22px e 24px,
mostrando de qual tema veio. Nunca `find`: o Papirus tem link simbólico no
**nível do tamanho**, e `find` sem `-L` não desce nele — isso já fabricou uma
lista falsa de "12 ícones faltando" que na verdade era zero.

---

## Sprint B — Curadoria assistida  ← **FEITA em 08/08/2026**

> **1 de 12 entrou, e isso é a regra dura funcionando.** Só o ONLYOFFICE tem no
> Arcticons um glifo que É o mesmo aplicativo (`onlyoffice-documents`), em
> `sapphire`, escolhido por matiz em Oklab a partir da cor dominante do ícone do
> Papirus. Instalado em `48x48/apps` — diretório NOVO, porque `scalable/apps` tem
> **três** donos e remover órfão lá apagaria arquivo dos outros.
>
> **Os outros 11 não existem no acervo**, medido contra o índice completo de
> 14.996 nomes: `boxy`, `flatseal`, `bleachbit`, `foliate`, `btop`, `file-roller`
> dão 404; os 32 `proton-*` são da Proton AG, não do ProtonUp-Qt. Ficam no
> Papirus.
>
> **Três números deste texto estavam errados, e foram medidos de novo:**
> os órfãos são **12** (não 25, não 35, não 14) — a diferença para a medição
> anterior é o `syncthing`, que tem `NoDisplay=true` nos dois `.desktop` da
> Debian e por isso **ela nunca o vê no lançador**. E o croma máximo com L<0,55 é
> **0,034** no mocha; 0,039 não existe em flavor nenhum (0,043 é o do latte).
>
> **A armadilha (b) era pior que o previsto:** rodando o método nos 13, **três
> grupos de marcas colidem na mesma cor** — peach, green e sapphire. O gerador
> tem asserção que ESTOURA (código 2) em glifo repetido, cor repetida e nome nos
> dois mapas; a curadoria decide, e o mapa grava a decisão.
>
> **O que a folha revelou e não estava previsto:** a dock é vidro e o papel de
> parede gira, então o fundo oscila **na mesma captura** entre `#3C3B50`
> (sapphire dá 5,8:1) e `#826E92` (2,4:1 — apagado). Não há conserto pela cor: é
> a armadilha (a). O que sobra é engrossar o traço ou deixar no Papirus.

### O registro de como a sprint foi desenhada (continua válido)

> **A folha está em `~/folha-apps-orfaos.html`.** Nada foi aplicado: esta sprint
> termina na escolha dela, e o `assets/icones/apps.map` segue intocado.
>
> **Três números do texto abaixo estão errados, e foram medidos de novo:**
> os órfãos são **12**, não 25 (nem os 35 que o cabeçalho do `apps.map` afirma).
> Os outros já resolvem fora do Papirus: 7 jogos Steam em `hicolor`, 3 flatpaks,
> 1 por caminho absoluto, e o `thunderbird` já está no `MeowSystem-Icons`.
> **Zero candidatos são o mesmo aplicativo** — pela regra dura, nada entra
> sozinho. 18 são genéricos honestos, 26 mentem, 1 app não tem nada.
>
> **A busca por regex sobre nomes é necessária e insuficiente** — três dos
> melhores candidatos são invisíveis a ela, e só apareceram rasterizando os 428
> glifos e olhando: `lib.svg` são três livros (Foliate), `security.svg` é uma
> câmera (Snapshot), `verilog.svg` é um chip (btop).
>
> **O alerta que não estava previsto:** sete dos candidatos mais honestos são
> traço monocromático na cor `text`. Medido em contraste WCAG, o traço macchiato
> `#CAD3F5` dá **11,0:1 sobre Mocha e 1,3:1 sobre Latte** — some. Trocar de
> flavor inverte o lado (`#4C4F69`: 2,1:1 e 7,1:1), e o `icones_apps.sh` instala
> um flavor por vez. É o defeito de 04/08 outra vez, agora com número. Os
> candidatos coloridos e os PNG do acervo de aplicativo não têm esse problema.
>
> **Custo escondido:** candidato do `catppuccin-apps` é uma linha no mapa;
> candidato do pack `vscode-icons` **não é** — o `icones_apps.sh` só lê
> `assets/icones/catppuccin-apps/$VARIANTE/*.png` e escreve em `512x512/apps`.

### O registro de como a sprint foi desenhada (continua válido)

**Por que existe.** Ideia dela: *"os que não encontrarem, procurar semelhantes
usando regex similares e criar uma lista com os possíveis icons e eu escolho."*

**O estado atual, medido.** Dos 51 aplicativos com ícone nesta máquina:

- 16 já usam o acervo Catppuccin de aplicativo (`assets/icones/apps.map`)
- 10 usam desenho autoral (8 do COSMIC + FogStripper + Hefesto)
- **os demais continuam no Papirus** — e são o alvo desta sprint

Para gerar a lista dos que faltam:

```bash
./scripts/auditar_icones.sh --json > /tmp/audit.json
python3 - <<'EOF'
import json, glob, os
d = json.load(open('/tmp/audit.json'))
mapeados = {l.split(':')[0] for l in open('assets/icones/apps.map')
            if l.strip() and not l.startswith('#')}
for a in d['aplicativos']:
    if a['icone'] not in mapeados and 'Papirus' in a['tema']:
        print(f"{a['icone']:38} {a['nome']}")
EOF
```

**Como a busca roda.** Uma frente por aplicativo órfão, em paralelo. Cada uma
recebe: o nome do `.desktop`, o nome legível do app, e os dois acervos. Cada
uma devolve **até 5 candidatos**, cada candidato com: o arquivo, por que ele foi
sugerido, e um veredito honesto de se ele **mente** sobre o que é o aplicativo.

A busca é por regex sobre os nomes dos dois acervos, mais o nome legível:

```bash
ls assets/icones/catppuccin/macchiato/ assets/icones/catppuccin-apps/macchiato/ \
  | sed 's/\.\(svg\|png\)$//' | grep -iE '<termo>'
```

### Exemplo já trabalhado: a busca por semelhança funciona, e falha

Ela levantou o caso e a hipótese: *"loja de aplicativos e afins, se o regex
falhar temos opções similares. aposto que deve ter um shop ou um folder
específico que se encaixe."* Testado em 05/08/2026, com o comando acima:

| termo buscado | achou |
|---|---|
| `shop\|store\|market\|cart\|bag\|package\|app` | **`folder_app`, `folder_packages`** — a aposta dela procede |
| `book\|read\|library` | `folder_storybook`, `mdbook`, `readme` |
| `camera\|photo\|snap` | só `photoshop` (é outra coisa) |
| `calc\|math` · `keyboard\|input` · `clean\|broom` · `disk\|drive` · `monitor\|cpu` · `mail\|email` | **nada** |

Ou seja: a busca por semelhança **resolve uma parte e não resolve o resto**, e o
motivo é estrutural — o pack `vscode-icons` é de **desenvolvimento**, então tem
`folder_packages` e não tem calculadora. Onde ele não alcança, os candidatos vêm
do acervo de aplicativo (`assets/icones/catppuccin-apps/`) ou não existem, e aí o ícone
fica no Papirus e isso é dito na folha em voz alta, em vez de forçar um
casamento ruim.

**Ícone de pasta como ícone de aplicativo é decisão dela, não sua.** `folder_app`
na Loja de Aplicativos pode ficar excelente ou pode confundir pasta com programa.
Entra na folha como candidato marcado, com o veredito honesto ao lado.

**A regra que decide, e ela custa cobertura de propósito:** só entra quando é o
**mesmo aplicativo**. Já foram descartados, com correspondência tentadora e
falsa: `BoxySVG → inkscape`, `CosmicEdit → notepad`, `ProtonUp-Qt → lutris`,
`BleachBit → ccleaner`. **Um ícone errado é pior que um genérico, porque mente
sobre o que a coisa é.** Se a busca achar que vale mesmo assim, ela marca como
"parecido, não é o mesmo" e deixa a decisão para ela.

**A entrega é uma folha visual, não uma tabela de texto.** Cada órfão numa
linha: o ícone atual do Papirus e os candidatos ao lado, todos a 48px, cada um
sobre os **dois fundos** — Mocha `#1e1e2e` à esquerda, Latte `#eff1f5` à direita,
divididos na vertical, com o ícone em cima da fronteira. Isso não é enfeite: o
defeito de 04/08 foi ícone sumindo sobre papel de parede claro, e a divisão
diagonal (tentada antes) joga o ícone quase todo sobre um lado só.

Gere como **HTML standalone**, com os SVG/PNG embutidos em data URI, salvo em
`~/`. Ela pediu explicitamente "html standalone sem artifacts". Confira o
resultado antes de entregar renderizando em headless:

```bash
google-chrome --headless=new --disable-gpu --no-sandbox \
  --user-data-dir=/tmp/ch --window-size=1280,2400 --hide-scrollbars \
  --screenshot=/tmp/folha.png "file://$HOME/<arquivo>.html"
```

**Depois que ela escolher:** as linhas entram em `assets/icones/apps.map` e
`./scripts/icones_apps.sh --aplicar` faz o resto. O script já remove órfão (o
diretório tem dono único) e já é idempotente.

---

## Sprint C — As pastas  ← **FEITA e DESLIGADA em 08/08/2026**

> **O VEREDITO DELA VEIO DEPOIS DE APLICAR, E É O QUE VALE.** Implementada, ela
> olhou o Gestor de Arquivos e disse: *"as pastas do temas dos icons do vscode
> catpuccin, tipo as folders, essas nao tão legais tambem"*. Na tela, as 7 são
> pasta **vazada de traço claro** ao lado das mauve **cheias** do
> `papirus-folders`, e nenhuma das 7 usa `mauve`, que é o accent dela — o
> conjunto não fechou. O risco estava previsto no desenho abaixo ("pode ficar
> ótimo ou pode ficar inconsistente"); quem decidiu foi a tela, não o palpite.
>
> **Hoje `PASTAS_XDG="nao"` é o padrão do `meow.conf`.** O recurso ficou de pé
> atrás da chave em vez de ser apagado: está medido, provado e pronto para o dia
> em que ela quiser experimentar de novo — de preferência junto com
> `ICONES_FLAVOR="latte"`, que a folha mostra com contraste bem melhor.
>
> **A lição de método:** a folha visual foi gerada, mas a sprint foi APLICADA
> antes de ela olhar. A regra do projeto — *"a folha visual vem antes do código"*
> — existe exatamente para isso, e desta vez foi invertida porque ela pediu para
> seguir sem parar para perguntar. O custo foi uma ida e volta; a lição é que
> "seguir sem perguntar" vale para decisão técnica, não para gosto.
>
> **O que o desligamento comprova, e é bom que comprove:** com o diretório
> limpo, o `construir_pastas.sh` devolveu os 231 apelidos mauve numa passagem, e
> as 7 voltaram a apontar para `folder-cat-mocha-mauve-*`. A cessão condicional
> funcionou nos dois sentidos.

### O que foi implementado (continua no disco, atrás da chave)

> **Entraram 7 nomes XDG**, não as 14 do desenho original: `folder-documents`,
> `folder-download`, `folder-music`, `folder-pictures`, `folder-publicshare`,
> `folder-templates`, `folder-videos`. Vão para `scalable/places` — diretório de
> dono único, com remoção de órfão — pelo `scripts/icones_pastas.sh` e o mapa
> `assets/icones/pastas.map`. Folha em `~/folha-pastas-2.html`.
>
> **A CESSÃO CONTINUA OBRIGATÓRIA, MAS PELO MOTIVO OPOSTO AO QUE ESTE ARQUIVO
> DAVA.** O texto abaixo diz que a opção (a) não funciona porque "quem escolhe o
> diretório é o tamanho, não a ordem de `Directories=`". Medido em 08/08,
> plantando o mesmo nome nos dois lugares e rodando o `cosmic-files` sob strace
> num `Xvfb :99`: ele abriu o **`scalable/places`**, sem nem tentar o `32x32`.
> Mas o **GTK discorda com o mesmo disco** — resolve `scalable` a 16 e 24 px e
> `32x32` a 32 px. Ou seja, a mesma pasta apareceria pastel a 16 px e mauve a
> 48 px dentro do mesmo aplicativo. Não é que `scalable` perca: é que **dois
> arquivos para um nome é o defeito dos dois donos**, e os dois resolvedores
> desta máquina resolvem diferente.
>
> **A cadeia de nível 2 era pelo lado inverso, e são 11, não 1.** O aviso deste
> arquivo mirava em `folder-videos → folder-video`; medido, cedemos o TOPO da
> cadeia e não há carona nenhuma. O problema real é o outro: **11 apelidos**
> (`folder-downloads`, `folder-images`, `folder-sound`, `folder-text`,
> `folder-public`…) × 5 tamanhos = **55 links** que o passe 2 abandonaria e que
> cairiam azuis, calados. O `construir_pastas.sh` agora desce a cadeia com
> `readlink -f` e aponta direto para a cor.
>
> **Dois achados que ninguém tinha:** o `cosmic-files` pede a **32 px**, e a
> **barra lateral dele é `-symbolic`** — repintada numa cor só pelo toolkit
> (§4g). Pintar ali seria trabalho apagado; a barra lateral está **fora** do
> alcance desta sprint, por medição.
>
> **O modo de destruição foi reproduzido**, em sandbox: sem a cessão, **5 dos 7**
> viram link mauve na primeira rodada e 2 passam batidos. Com a cessão, duas
> rodadas seguidas dão diff de zero linhas.
>
> **E a cessão é condicional, de propósito:** só cede o nome cujo pastel JÁ está
> em `scalable/places`. Apagando aquele diretório, os 7 voltam a mauve numa
> rodada, sozinhos — o projeto não fica com pasta sem ícone se um script sumir.

### O desenho original, e por que a premissa dele caiu

> **O `cosmic-files` não pede 12 das 14.** Medido casando por dicionário os 2.480
> nomes de `places` do disco contra `strings -a /usr/bin/cosmic-files`: o binário
> contém **12** nomes de pasta, e das 14 desta sprint só **duas** aparecem —
> `folder-download` e `folder-templates`.
>
> O motivo é estrutural: `folder-github`, `folder-docker` e companhia são apelidos
> do Papirus para o **Dolphin/KDE**, que lê um `.directory` dentro da pasta. O
> `cosmic-files` **não tem essa lógica** — `.directory` aparece **zero** vezes no
> binário. Instalar as 12 seria instalar ícone que ela nunca veria.
>
> **O casamento que vale é outro:** os nomes XDG que ele de fato pede. O pack
> cobre 8 dos 12, mas com outro nome (`folder_images`→`pictures`,
> `folder_audio`→`music`, `folder_docs`→`documents`, `folder_video`→`videos`,
> `folder_public`→`publicshare`). **Entra por renomeio, e é decisão dela.**
>
> **Dois fatos que ninguém tinha visto:** `folder-docker` **já é azul** hoje (o
> `papirus-folders` não tem variante mauve dela, e ela cai no Papirus) — a mistura
> de estilos que esta sprint pergunta se ela aceita **já está na tela**. E
> **nenhum dos 14 ícones do pack usa `mauve`**, que é o accent dela.
>
> **Dois donos — a resposta medida é (b), e (a) não funciona.** O
> `construir_pastas.sh` reproduz todo apelido do Papirus e reescreve o link quando
> `readlink` diverge; um arquivo regular ali devolve `readlink` vazio e o
> `ln -sfn` o substitui. **9 das 14 seriam apagadas a cada ciclo** (passe 1) e
> **5 passariam batido** (passe 2, que tem `[ -e ] && continue`) — metade quebra
> alto, metade em silêncio. E (a) não decide nada, porque quem escolhe o
> diretório é o **tamanho**, não a ordem de `Directories=` (ver §4g). A saída é o
> `construir_pastas.sh` conhecer a lista e ceder, como o `icones_apps.sh` já faz
> com `INTOCAVEIS`. Cuidado com `folder-videos → folder-video`, que é cadeia de
> nível 2: ceder o segundo faz o primeiro virar pastel de carona.

### O registro de como a sprint foi desenhada (o resto continua válido)

**Por que existe.** A tela que ela mandou dizendo *"esses são os ícones que eu
quero"* era a página do pack mostrando `folder-debug`, `folder-docker`,
`folder-github`, `folder-images`. São ícones de **pasta**, e é o que ela vê no
Gestor de Arquivos.

**O que está medido:**

- o pack tem **228** ícones de pasta (`folder_*.svg`, com **underscore** — o site
  e o Iconify mostram com hífen porque normalizam; no repositório é underscore)
- **14** casam com nomes de pasta que o sistema usa: `folder-android`,
  `folder-cloud`, `folder-docker`, `folder-download`, `folder-git`,
  `folder-github`, `folder-gitlab`, `folder-images`, `folder-linux`,
  `folder-private`, `folder-public`, `folder-temp`, `folder-templates`,
  `folder-video`
- hoje as pastas dela vêm do `papirus-folders` em `cat-mocha-mauve` (roxas),
  instaladas por `scripts/construir_pastas.sh`

**Decisão a tomar com ela:** as 14 pastel do pack conviveriam com as roxas do
`papirus-folders` — pastas de tipos diferentes com estilos diferentes. Pode ficar
ótimo (destaque para pastas especiais) ou pode ficar inconsistente. **Folha
visual antes**, pelo método da Sprint B.

**Cuidado com dois donos:** `construir_pastas.sh` já é dono de
`<tam>/places/folder-*`. Se estes forem para o mesmo diretório, os dois scripts
brigam a cada rodada — o laço eterno que o `construir_icones.sh` documenta no
próprio cabeçalho. Ou o novo script escreve em `scalable/places/` (diretório
próprio, dono único, e a ordem de `Directories=` decide quem ganha), ou o
`construir_pastas.sh` passa a conhecer a lista e cede.

---

## Sprint D — O wizard  ← **FEITA em 05/08/2026**

> `meow configurar` (e `./install.sh --wizard`). O esquema — ordem, seções, ajuda
> — é **lido do `meow.conf.exemplo`**, não de uma lista dentro do script: são
> **31 chaves**, e a lista que este arquivo dava estava incompleta.
>
> *(29/08/2026: o número envelheceu. Hoje o `meow.conf.exemplo` tem **75** chaves
> e o wizard curto pergunta **4** — `grep -c '\[essencial\]'`. Três números
> incompatíveis circulavam: 31 aqui, 24 na linha 1017 e 25 no `bin/meow`.)*
>
> **O defeito que a implementação revelou:** o `meow.conf.exemplo` tinha
> `LOGO_INTERVALO=` **duas vezes** (`30m` e `1d`). O `.` do shell obedece a
> **última**; o `conf_definir` escrevia a **primeira** — ou seja, o `meow` dizia
> "gravado" e o valor em vigor não mudava. Corrigido, e vale como regra: a
> premissa "o exemplo é a lista de chaves" só se sustenta sem chave repetida.
>
> Provado: ENTER em tudo não escreve um byte · `MEOW_DRY_RUN=1` não escreve ·
> `echo | ./install.sh` não trava e não pergunta · sem tty o wizard diz "sem
> terminal interativo" e segue · o `install.sh` duas vezes não escreve nada.

## O texto original da sprint (o desenho continua válido)

**Por que existe.** Pedido dela, textual: *"o install faz dele wizard pra eu ir
modificando e afins."*

**O conflito a resolver primeiro.** O cabeçalho do `install.sh` diz, hoje:

> **POR QUE NÃO TEM FLAG** — quem decide o que instalar é o `meow.conf`, não a
> linha de comando. Uma flag a menos é uma decisão a menos na hora de usar.

Um wizard **não contradiz** isso, desde que ele seja um jeito de **editar o
`meow.conf`** — e não um segundo lugar onde as decisões moram. A regra: o wizard
pergunta, grava no `meow.conf`, e depois roda o instalador de sempre. Duas fontes
de verdade seria o mesmo defeito de "dois donos".

**Desenho:**

- `./install.sh` sem argumento continua fazendo exatamente o que faz hoje. O
  wizard é `meow configurar` (ou `./install.sh --wizard`), nunca o padrão: o
  instalador roda em timer e por script, e um prompt ali travaria tudo.
- Ele só pergunta o que está no `meow.conf`: `FLAVOR`, `ACCENT`, `MODO`, `LOGO`,
  `ICONES_FLAVOR`, `VIDRO_*`, `WALLPAPER_*`, `APPS_ATIVOS`.
- Mostra o valor atual como padrão. Enter mantém.
- Grava com `meow_escrever` (atômico, e não escreve se nada mudou).
- **Nunca pergunta quando não há terminal interativo.** O teste é `[ -t 0 ]` —
  já é o padrão do projeto para as duas perguntas que existem na CLI.
- No fim, mostra o diff do que mudou e pergunta se aplica agora.

**Onde mexer:** `bin/meow` (novo `cmd_configurar`), `install.sh` (a flag),
`assets/zsh/_meow` (completion), `meow.conf.exemplo` (é a lista de chaves e a fonte dos
comentários que o wizard mostra como ajuda).

**Como conferir:** rodar o wizard aceitando tudo com Enter não pode escrever um
byte no `meow.conf`. `MEOW_DRY_RUN=1` também não. E `echo | ./install.sh` (stdin
não-tty) tem de seguir o caminho de sempre, sem travar.

---

## Sprint E — Sincronização automática dos assets  ← **FEITA em 05/08/2026**

> **O que entrou:** o par `systemd/meow-assets.path` + `systemd/meow-assets.service`,
> instalado e conferido por `scripts/vigia_assets.sh`, ligado no `install.sh`
> (`etapa_assets`) e no `meow doctor` (`chk_assets`/`fix_assets`, verificável
> `assets`). Duas chaves novas no `meow.conf`: `ASSETS_VIGIA` e
> `ASSETS_VIGIA_NOTIFICAR`.
>
> **A prova:** com o vigia ligado e 10 s de silêncio medidos antes, um `.svg`
> solto em `assets/gatos/` disparou **exatamente uma vez** (23:22:44) e o gato
> apareceu em `~/.config/cosmic/logos/`; apagá-lo disparou **exatamente uma vez**
> (23:23:10) e o órfão saiu do disco. `./install.sh` rodou duas vezes inteiras
> sem disparar o vigia nenhuma vez, e a segunda não escreveu um byte.
>
> **O que ele NÃO faz, de propósito:** não gira o gato. Acrescentar um arquivo
> não muda qual está no ar — quem gira é o relógio, um por dia, que foi a escolha
> dela. E o gato do dock só troca no login seguinte, porque o `cosmic-panel` não
> tem watch de inotify sobre arquivo de ícone (já medido neste projeto). Por isso
> o serviço avisa por `notify-send` quando o acervo muda: sem o aviso, o recurso
> rodaria, devolveria sucesso e não mostraria nada.

### O que a medição CONTRADISSE nesta sprint

A armadilha 1 desta sprint dizia, textualmente: *"Uma unit `.path` apontando para
um diretório inexistente falha no boot. Precisa de `ConditionPathIsDirectory=` e
de degradação silenciosa."* **As duas metades estão erradas**, e a receita
produziria o defeito que ela queria evitar. Medido em 05/08/2026, systemd 255:

| teste | resultado |
|---|---|
| `.path` com `PathModified=/mnt/NAO-EXISTE/repo/assets/gatos`, sem condição | **`active (waiting)`** — não falha. O systemd vigia o ancestral que existe (`/mnt`) e espera |
| o mesmo, criando o diretório depois e soltando um SVG | disparou **2 vezes** (criação do diretório e chegada do arquivo) — ou seja, o vigia se cura sozinho quando o Ápate monta |
| `.path` **com** `ConditionPathIsDirectory=` e o diretório ausente | `ConditionResult=no`, `ActiveState=inactive` |
| o mesmo, criando o diretório depois e soltando um SVG | disparou **0 vezes** — condição de unidade é avaliada na PARTIDA, e nada a reavalia |

Conclusão: no cenário exato que a condição existia para cobrir — `/mnt/Apate`
desmontado no boot e montado depois — ela troca um vigia que se recupera sozinho
por um vigia morto e calado. A degradação silenciosa foi para o **serviço**
(`ConditionPathExists=` no ponteiro da raiz, que mora em `/home`, mais o
`[ -x "$R/scripts/logo.sh" ] || exit 0` do `ExecStart`).

A armadilha 2 **se confirmou** e continua valendo: com o diretório de log
ausente, `StandardOutput=append:` derruba o serviço com `Failed to set up
standard output: No such file or directory`, `status=209/STDOUT`, antes de
qualquer comando. Quem garante o diretório é o `mkdir -p` do
`scripts/vigia_assets.sh`.

### O laço: conferido no código, não suposto

Medido que a armadilha é real — escrever **ou apagar** um arquivo dentro do
diretório vigiado dispara a unidade; escrever no diretório **pai** (`assets/`)
**não** dispara, o que é o que torna seguro o `gerar_gato.py` reescrever
`assets/meow-<flavor>.svg` a cada instalação.

Lidas as escritas do `logo.sh`, todas caem fora do caminho vigiado:
`~/.config/cosmic/logos/`, a chave do applet `dev.cappsy`,
`~/.local/state/meowsystem/logo-atual` e os botões do dock em
`~/.local/share/icons/<tema>/scalable/apps/`. O `rm -f` que esta sprint mandava
conferir mira em `$LOGOS_DIR` — que é `~/.config/cosmic/logos` —, nunca no
acervo. E o `StartLimitBurst=20`/`StartLimitIntervalSec=60s` do serviço é o
disjuntor caso alguém quebre essa regra um dia: testado forçando 25 partidas
seguidas, o par foi para `failed`, o `meow doctor` acusou e o `--consertar` fez
`reset-failed` e religou.

### Dois detalhes de systemd que custam uma tarde

- **`$R` sim, `${R}` não.** O systemd expande `${NOME}` na linha de `Exec` mesmo
  dentro de aspas simples, e variável que ele não conhece vira string vazia.
  Testado: `sh -c 'R=abc; printf "[%s][%s]" "$R" "${R}"'` imprimiu `[abc][]`. Já
  `${NOME:-padrão}` passa inteiro (o `:` não é nome de variável válido) e quem
  expande é o shell — `DEF=doshell; "${DEF:-fallback}"` saiu `doshell`. É por
  isso que as unidades deste projeto só usam essas duas formas.
- **Nenhuma aspa dentro do texto do `notify-send`.** O systemd entrega o script
  inteiro ao `sh` como UM argumento; uma aspa dupla escapada no meio da mensagem
  FECHA a string e o corpo se parte em três argumentos, que o `notify-send`
  recusa. Pego aqui com `systemctl --user show -p ExecStopPost` antes de virar
  bug.

---

## Sprint F — A poda  ← **FEITA em 05/08/2026, e não era código**

> **Nenhum dos três itens de código existia.** Medido antes de remover:
> `lib/aurora.sh` não existe (só `comum.sh`); `dnf|pacman|zypper|nix-env|
> rpm-ostree|emerge|apk` dão **zero** ocorrências; não há detecção de schema.
> A poda foi de **promessa**, não de linha — nenhuma função removida, nenhum
> arquivo apagado. Os dois itens do README já tinham sido feitos em `11c758a`.
>
> O que parecia detecção de schema (`e_chave_da_aurora`) é o oposto: ela deduz a
> regra da Aurora em vez de cravar `v2`, para sobreviver a uma migração **nesta**
> máquina. Removê-la seria erro.
>
> **A promessa falsa que a releitura pegou:** o README dizia *"Todo passo faz
> backup antes de sobrescrever"*. São **7 scripts**, não todos. A regra real que
> entrou é melhor que a prometida: backup do que é de outro, e nada nos
> diretórios de dono único, onde o conteúdo anterior é a saída da rodada
> anterior do próprio script.
>
> **Um bug encontrado de raspão, e corrigido:** o `install.sh` gravava o timer
> com `${LOGO_INTERVALO:-1d}` e anunciava na tela `${LOGO_INTERVALO:-30m}`. Não
> aparecia na máquina dela só porque o `meow.conf` dela **tem** a chave.
>
> Intactos de propósito, e conferidos um a um: o `garantir_backup` colado na
> linha anterior ao `rm -f "$vivo"` (361/362), a fronteira com a Aurora e o
> código 4, e a degradação elegante em 26 arquivos.

## O texto original da sprint (o critério continua valendo)

**Por que existe.** A decisão de não publicar tornou obsoleto um bloco de
trabalho que estava planejado e um bloco de texto que já está escrito.

**Sai (não fazer, e remover o que promete fazer):**

- abstração de gerenciador de pacotes além do `apt` (era para Fedora/Arch/NixOS)
- detecção de schema do COSMIC de outra versão, para capturas de tema
- camada única de detecção do Ritual da Aurora (`lib/aurora.sh`)
- a seção **"Noutra máquina"** do `README.md`, que promete portabilidade
- o `README.md` diz *"ele vai ser público"* ao justificar os 136 MB de wallpaper
  fora do git — a razão mudou, o efeito continua certo (imagem em git é dívida)

**Fica, e não é negociável:**

- **o backup antes do `rm -f`** em `scripts/aplicar_tema.sh`. Ele nunca foi sobre
  publicar: é o que protege o tema **dela** de ser apagado sem volta.
- **a não-briga com o Ritual da Aurora.** O Aurora roda nesta máquina, como root,
  a cada hora. Continua valendo integralmente.
- **a degradação elegante** (pular e avisar quando a superfície não existe). Não
  é portabilidade: é o que faz o instalador não explodir quando um app não está
  instalado.

**Como conferir:** `./install.sh` duas vezes, `meow doctor` verde, e nenhuma
promessa no README que o código não cumpra.

---

## Sprint U — Sobreviver a um dist-upgrade  ← **FECHADA em 30/08/2026** (build incluído)

### A pergunta que a abriu

Ela perguntou, em 29/08/2026: *"lembra de colocar nas sprints a idempotência pra
um full dist upgrade"*. A pergunta é a certa, e a resposta medida é que **hoje o
sistema não sobrevive**: um `apt full-upgrade` derruba metade do que este
repositório e o Ritual da Aurora constroem, e **derruba calado**.

### O que foi medido (29/08/2026, investigação do modo de leitura)

| o que quebra | por quê | como se descobre hoje |
|---|---|---|
| o patch de workspace do `cosmic-comp` | o pacote reescreve `/usr/bin/cosmic-comp` | um workspace vazio a mais no painel — ela vê |
| o patch do night light | o mesmo binário; e **um build novo invalida os offsets** do `aurora-night-light.py` | a tela volta a ser azul à noite — ela vê |
| o patch do raio de canto | **nunca entrou**: o `aurora-cosmic-comp-ws.sh` aplica UM `.patch` só (`$PATCH_INSTALADO`, linhas 385-414) | ninguém descobre. O README diz que aplica |
| o modo de leitura (quando existir) | idem: o script não conhece um segundo patch | os sliders arrastam e a tela não muda — **falha muda** |
| os botões dos apps COSMIC (se recompilados) | cada pacote traz seu próprio `libcosmic` estático | os botões voltam à direita **só naquele app** |
| as deps de build | `libdav1d-dev` e `libpulse-dev` ausentes hoje | o build morre em 119 s |

E a frequência não é hipótese: `/var/lib/aurora` guarda **seis versões** de
`cosmic-comp` entre 13/07 e 26/08 — quase semanal. O `cosmic-settings` trocou
**12 vezes em 70 dias**.

### O que fazer

1. **Trocar o patch único por uma SÉRIE.** **Use `cp`, nunca `mv`.** O
   `aurora-cosmic-comp-ws.sh:386` procura o patch num caminho literal e devolve
   `return 2` se não achar: mover o arquivo antes de reescrever o `compilar()`
   deixa o `--build` morto na janela entre os dois passos. Falha segura (nada é
   instalado), mas se um `apt upgrade` cair nessa janela ela fica no compositor de
   fábrica, com o workspace fantasma de volta e sem causa aparente. Criar
   `~/.config/zsh/patches/patches.d/` com um arquivo `series` que declare cada
   patch como `req:` (obrigatório — se falhar, aborta o build e **nada** é
   instalado) ou `opt:` (opcional — se falhar, o build segue sem aquele efeito).
   Dry-run de **todos** antes de aplicar **qualquer um**.
2. **Trocar a idempotência de código de saída para marcador.** `patch --forward`
   devolve **1** para "já aplicado" — medido. Testar por
   `grep -q <marcador> <arquivo-fonte>`, declarado na própria série.
3. **Concatenar TODOS os marcadores** no `marcador_de()` (linha 230), senão o
   `--ensure` não reinstala quando a série muda. Foi esse o bug de 25/08.
4. **Fixar a ordem no self-heal:** build (todos os patches) → `aurora-night-light.py`
   re-patcha o binário novo → `--ensure` instala. O patch binário **não**
   sobrevive a um build.
5. **Fazer o aviso chegar nela pelo `meow doctor`,** não por `notify-send`: o
   Não Perturbe dela engoliu **22 avisos** entre 27 e 28/08. O build grava
   `/var/lib/aurora/cosmic-comp-patches.estado` com uma linha por marcador, e o
   doctor compara contra `/proc/<pid do cosmic-comp>/exe` — a pergunta é sobre o
   **processo**, não sobre o arquivo.
6. **Duas mensagens distintas,** porque significam coisas diferentes:
   `FALTA <marcador>` (o build precisa ser refeito) e
   `<marcador> está no disco mas NÃO na sessão` (vale no próximo login).
7. **Podar `/var/lib/aurora`,** que cresce ~89 MB por versão e que nada limpa:
   guardar os 3 `.orig` mais novos, sempre o da versão instalada, e apagar todo
   `.aurora-ws` de versão que não é a corrente.

### Como conferir que ficou certo

- `./bin/meow doctor` ganha uma linha nova e ela fica **verde** com a sessão em
  dia, **amarela** (`~~`) quando o patch está no disco mas não na sessão.
- Simular: `sudo apt-get install --reinstall cosmic-comp`, esperar o self-heal, e
  conferir que os marcadores voltaram **todos** — não só o de workspace.
- Segunda passagem do `install.sh` = **0 arquivos, 0 avisos**.

### O que pode dar errado

- **Um `.patch` obrigatório que não aplica mais aborta o build inteiro** — e é o
  comportamento certo: melhor ficar no binário do pacote (desktop feio, mas de
  pé) do que instalar um compositor meio-patchado.
- **`make VENDOR=1` apaga o `vendor/` patchado antes de compilar, em silêncio.**
  Quem for mexer nos botões dos apps COSMIC precisa saber disso antes.
- **O `--restore` dos dois scripts está armadilhado.** O `.pkg-orig` do
  `aurora-cosmic-comp-ws.sh` tem md5 que **não bate** com o do dpkg (já vem com o
  night light dentro), e o `.orig` do `aurora-night-light.py` é o binário do
  pacote, **sem** o patch de workspace. O caminho de volta certo está no cartão
  de recuperação de `docs/pesquisas/2026-08-29-modo-leitura-e-botoes.md`.

### Fronteira

O `aurora-cosmic-comp-ws.sh`, o `ritual-aurora-self-heal.sh` e o binário do
`cosmic-comp` são da **Aurora** (`docs/FRONTEIRA.md`). O `meow doctor`, o
`patches/` deste repositório e a linha nova de verificável são do **Meow**.
Escrita em `~/.config/zsh` vira commit no repositório privado dela em até 10 min
— sempre anunciada, nunca silenciosa.

### Material

Tudo que sustenta esta sprint está em `docs/pesquisas/`:
`2026-08-29-modo-leitura-e-botoes.md` (o plano e o cartão de recuperação) e os
dois JSON brutos das 75 investigações.

### O que a execução fez — 30/08/2026

Três frentes em paralelo, uma por arquivo, para não colidirem; a validação (medir
de novo, não reler o relato) foi feita depois, à mão.

| item | onde | estado |
|---|---|---|
| 1. série de patches | `~/.config/zsh/patches/patches.d/` (`series` + os 2 `.patch` + LEIA-ME) e `aurora-cosmic-comp-ws.sh` | **feito.** 3 candidatos de busca, `req`/`opt`, dry-run de todos antes de aplicar qualquer um, desfazer se um `req` cair |
| 2. idempotência por marcador | `compilar()` | **feito.** O arquivo-fonte de cada patch sai do próprio `.patch` (a linha `+++ b/`), nada chumbado |
| 3. marcadores concatenados | `marcador_de()` | **feito.** `sort -u` colado com `+` — o `--ensure` volta a reinstalar quando a SÉRIE muda, não só quando a versão do patch de workspace muda |
| 4. ordem no self-heal | `ritual-aurora-self-heal.sh` | **já estava certa**, e o item da sprint estava invertido — ver abaixo |
| 5. o aviso chega pelo doctor | `scripts/compositor_patches.sh` + `bin/meow` | **feito.** Verificável `patches`, o 40º. Pergunta sobre o **processo** (`/proc/<pid>/exe`), não sobre o arquivo |
| 6. duas mensagens distintas | idem | **feito.** `FALTA <marcador>` (refazer o build) × `no disco mas NÃO na sessão` (o próximo login resolve), com rodapé de conselho diferente para cada |
| 7. poda do `/var/lib/aurora` | `podar_lib()` + `--podar [--seco]` | **feito e NÃO executado.** O seco diz: 449 MB hoje, liberaria **258 MB** |

### O build, e o que foi medido antes e depois — 30/08/2026, 01:40

Ela autorizou com *"pode rodar. só valida tudo antes"*. A validação, em ordem, e
cada linha é uma medição, não uma promessa:

| antes de compilar | resultado |
|---|---|
| o `.orig` da versão instalada bate com o md5 do dpkg | `468c46ba3bc3466933737b185624863b` nos dois — o caminho de volta é real |
| a árvore de fonte está no estado esperado | WS aplicado (1), raio ausente (0) |
| dry-run do raio, procurando **fuzz** | limpo, sem fuzz — a armadilha nova do `LEIA-ME` |
| jogo aberto, freio do auto-build, espaço em disco | nenhum, desligado, 129 GB |

Compilou em **3m08s** (`--compile-only`, sem instalar). O binário saiu com os
**dois** marcadores. Antes de instalar, três provas mais:

| depois de compilar, antes de instalar | resultado |
|---|---|
| `ldd -r` | nenhum símbolo por resolver |
| **teste de fumaça**: o compositor novo rodando ANINHADO, parqueado no workspace `OS` para não aparecer na tela dela | subiu (pid 179903), inicializou EGL, saiu **sem pânico** |
| a poda seco | os 3 arquivos da versão instalada, inclusive o `.orig`, todos marcados "fica" |

Depois de instalar: disco `ac3465b1…` com os dois marcadores **e** a luz noturna
reaplicada; **a sessão dela intacta** (`/proc/3261/exe` ainda `ef12fded…`), que é
o desenho — patch de compositor vale no próximo login. A poda liberou **258 MB**.

O que falta é UM logout dela. E enquanto ele não acontece, o doctor fica amarelo
na linha `patches` **pela segunda razão**, não pela primeira — o binário está em
dia, quem está velha é a sessão.

### As sete coisas que a medição de 30/08 derrubou

| onde | o que o texto dizia | o que foi medido |
|---|---|---|
| item 4 desta sprint | *"build → `aurora-night-light.py` re-patcha → `--ensure` instala"* | **está invertido.** "Build" e "`--ensure`" são a mesma chamada vista de dois lados; o night light tem de vir **depois** do `--ensure`, senão o `cp -a` do artefato joga fora a temperatura recém-escrita e a tela dela fica em 6500K por até uma hora. A ordem no self-heal (`--ensure` :2768, night light :2781) **já estava certa** e não foi tocada |
| item 1 desta sprint e `patches/LEIA-ME.txt` | dry-run limpo = o patch aplica | **dry-run NÃO é prova.** O `patch` do GNU usa **fuzz 2** por padrão: um `.patch` de contexto inteiramente inventado passou no `--dry-run --forward` com rc=0 e depois aplicou com *"succeeded at 1 with fuzz 2"*. A conferência por `strings` do fim **não pega** — o marcador fica presente, pregado no lugar errado. O `compilar()` agora **avisa alto** quando há fuzz; não aborta, porque fuzz também é como um patch sobrevive a upstream empurrando linhas. Ligar `-F0` nos `req` é uma linha, e é decisão dela |
| `patches/LEIA-ME.txt`, armadilha 3 | `grep -q 'AURORA-READING-MODE-1'` | o exemplo usa o marcador **com versão**. Com uma série isso quebra: quando a versão sobe (3.54→3.67) o teste diz "não aplicado" e o `patch` reaplica sobre uma árvore que já tem o anterior. O teste é pelo **base** |
| `docs/pesquisas/2026-08-29-…md:387` | gravar no `.estado` os marcadores **esperados**, tirados da série | grava-se o que o **build produziu**, medido com `strings` no binário instalado. A prova está na tela: o `opt` do raio está *declarado* e *ausente*. A versão "esperada" escreveria `presente` para um efeito que não existe |
| esta sprint | *"`/var/lib/aurora` guarda **seis** versões"* | são **oito** com `.orig` guardado, mais 4 `.pkg-orig` e 4 `.aurora-ws` — **449 MB**. O argumento da frequência fica mais forte, não mais fraco |
| `README.md` | *"o script aplica UM `.patch` só (`$PATCH_INSTALADO`, **linha 88**)"* e *"`grep raio-clampado` devolve zero"* | as duas viraram falsas no meio do próprio dia (linha 137, e `grep -c` = 3). O parágrafo foi reescrito **sem número de linha**, que é o que apodrece |
| — (ninguém tinha escrito) | — | **o patch do night light não tem marcador.** O `aurora-night-light.py` reescreve o bloco do shader GLSL e deixa só um comentário `// NIGHT LIGHT (Aurora)` dentro dele: não é `static &str`, não casa com `AURORA-*`, não está na série. **O verificável `patches` não o cobre**, e um build novo o apaga. Cobri-lo exige outro critério; fingir que este cobre seria pior que a lacuna |

E uma assimetria que também não estava escrita: o
`cosmic-comp-sem-workspace-vazio.patch` — o patch que segura os workspaces
alfinetados dela, o mais importante da máquina — **não existe neste
repositório**. O `patches/` só carrega o raio-clampado. O verificador diz isso em
voz alta, senão o "md5 igual" verde daria impressão de uma cobertura que não há.

### Como conferir hoje, sem compilar nada

```bash
./bin/meow doctor                      # a linha `patches` é a 10ª da tabela
aurora-cosmic-comp-ws.sh --status      # série, marcador por patch, disco × sessão
aurora-cosmic-comp-ws.sh --podar --seco  # o que a poda apagaria (não apaga)
```

---

## Sprint V — O modo de leitura  ← **FECHADA em 31/08/2026** (com dívidas dentro)

### Por que esta seção existe, e por que ela chega atrasada

O modo de leitura inteiro — **10 arquivos**, um applet em Rust, cinco chaves de
`cosmic-config`, duas unidades `systemd`, três etapas do `install.sh` e uma linha
nova no desinstalador — foi construído em 30 e 31/08/2026 e **não tinha uma linha
neste arquivo**. É a **segunda ocorrência** do defeito que a seção
"[O trabalho de 26/08 que nunca teve sprint](#o-trabalho-de-2608-que-nunca-teve-sprint)"
denuncia, e ela termina exatamente com a frase que serve aqui: *"se alguém for
auditar o projeto pelo `SPRINTS.md`, vai concluir que esse trabalho não existe"*.

A nota "Onde paramos — modo de leitura", no topo, é um **estado de conversa**, não
um registro: ela não estava no índice, não listava dívida e não sobreviveria a uma
auditoria. Esta seção é o registro.

### O que foi feito

Plano completo em `docs/pesquisas/2026-08-29-modo-leitura-e-botoes.md`; a folha que
ela abriu para decidir é `docs/pesquisas/2026-08-29-modo-leitura.html`.

| etapa | onde | estado |
|---|---|---|
| 1. os dois números pintam a tela | patch no `cosmic-comp` (Aurora) | **feita** · `AURORA-READING-MODE-1` no binário desde 30/08 04:59 |
| 2. o horário liga sozinho | `scripts/leitura.sh`, `systemd/meow-leitura.{service,timer}` | **feita** · timer de minuto em minuto |
| 3. o slider na barra | `src/applets/leitura/`, `scripts/leitura_build.sh` | **feita** · applet vivo na topbar **sem logout** |
| 4. aposentar o night light da Aurora | binário do compositor | **feita** · ver a medição abaixo |
| 5. o doctor conta a verdade | `bin/meow` (`chk_leitura`, `chk_leiturabin`) | **feita** · veio junto da Sprint U |
| 6. a dívida do raio de canto | Sprint U | **feita** · o patch entrou no binário |

E o que a onda de correção de **31/08** acrescentou, depois que duas conferências
independentes revisaram o trabalho das seis frentes:

- **o horário passou a ter TRÊS estados, não dois.** `HoraInicio` e `HoraFim` são
  braços separados do applet; o `leitura.sh` exigia as duas chaves e, faltando uma,
  jogava fora a outra. Agora cada ponta se resolve sozinha, e o `LEITURA_FONTE` vale
  `applet`, `padrao` ou **`misto`**.
- **a rampa parou de saltar.** A descida partia de 1 sem perguntar até onde a subida
  tinha chegado.
- **o portão do `AUTO_REPARO` desceu até antes da chamada do script.**
- **o applet perdeu o botão "Restaurar padrões"** (fazia o mesmo que o interruptor) e
  a **linha de horário some** quando o `Agendar` está desligado.
- **o `leitura_build.sh` ganhou um caminho sem `cargo`**, que repõe binário e sombra
  sem compilar.
- **o `meow-leitura.timer` ganhou `PartOf=`** e perdeu um `OnBootSec=` inerte.
- **o `meow.conf.exemplo` parou de dizer que o compositor não sabe ler** — era falso
  desde 30/08, e é o arquivo que ela edita.

### O que foi medido (e é o que sustenta cada linha acima)

| afirmação | medição, 31/08/2026 |
|---|---|
| o compositor já sabe ler, no disco e na sessão | `strings -a /usr/bin/cosmic-comp \| grep -c AURORA-READING-MODE` → **1**; o mesmo em `/proc/<pid>/exe` → **1** |
| o night light da Aurora está aposentado | os marcadores do binário são três e nenhum é night light; `md5sum` do `/usr/bin/cosmic-comp` é **idêntico** ao do `.aurora-ws` de 30/08 04:59 — nada foi re-patchado por cima |
| a rampa maior que a janela saltava | janela 18:00–18:30 com `LEITURA_RAMPA_MIN=60`: às 18:29 a fração era 0,48 e às 18:30 saltava para 1,00. Com `=600`, salto de **0,952 em um minuto**. Depois do conserto: 0,017 e 0,002 |
| lixo no `meow.conf` virava `inf` no disco | `LEITURA_RAMPA_MIN="abc"` gravava `-9223372036854775807` em `leitura_temperatura` e `inf` em `leitura_textura` |
| `0,35` (vírgula pt_BR) desliga a textura calada | vira 0 no `awk` sob `LC_ALL=C`; nada na tela acusa |
| o portão do `AUTO_REPARO` prendia a tela numa cor | em HOME falso, com `AUTO_REPARO="nao"` e `LEITURA_AGENDA="sim"`, o instalador gravava 3500K/0.35 e na linha seguinte removia o timer — a única coisa capaz de desfazer às 07:00 |
| `Type=oneshot` não herda o timeout de partida | `TimeoutStartUSec=infinity` em três unidades nossas — ver `COSMIC-THEMING.md` §4i |
| `Linger=yes` mantinha o timer batendo sem sessão | `loginctl show-user … -p Linger` → `Linger=yes`; `WAYLAND_DISPLAY` está no ambiente do gerente |
| quatro gestos de slider não publicam `on_release` | lido no `slider.rs` do rev pinado — ver `COSMIC-THEMING.md` §4i |

Os cinco fatos de **aplicação geral** que saíram daqui foram promovidos para
`docs/COSMIC-THEMING.md` **§4i**, com data e método, porque vão ser reencontrados
fora do modo de leitura.

### O que ficou por fazer

Nenhuma destas tem dono. Estão repetidas na lista de dívidas do índice, que é onde
se procura.

> ~~**`meow-logo.service` e `meow-painel-raio.service` sem teto de partida.**~~
> **DERRUBADA no mesmo dia, e por duas razões diferentes.** O
> `meow-painel-raio.service` ganhou `TimeoutStartSec=30s` em 31/08, enquanto esta
> seção estava sendo escrita. E o `meow-logo.service` **nunca foi risco**: o teto que
> importa nele é o de PARADA, porque o trabalho inteiro está no `ExecStop` — e
> `TimeoutStopSec` **herda** o padrão do gerente, ao contrário do de partida. Medido
> em 31/08/2026: `DefaultTimeoutStopUSec=1min 30s`, e um `oneshot` instalado
> (`meow-assets.service`) responde `TimeoutStopUSec=1min 30s` mesmo com
> `TimeoutStartUSec` cravado em outro valor. O `ExecStart=/bin/true` não trava. Fica
> registrado porque a dívida foi levantada e a medição a matou — e "oneshot herda o
> teto de parada mas não o de partida" é o fato que sobra (`COSMIC-THEMING.md` §4i).

1. **`etapa_logo` e `etapa_wallpaper` com o mesmo modo seco cego — HIPÓTESE, NÃO
   MEDIDA.** Foi o defeito consertado hoje no `etapa_leitura` e no `etapa_autoreparo`:
   o ramo `meow_seco` conclui pelo `mudou` do arquivo e **não pergunta**
   `is-enabled`/`is-active`. Lendo o código, com as unidades no disco porém
   desarmadas, o `--dry-run` do `etapa_logo` imprime um `ok` VERDE ("rotação de gatos
   já ligada") e o do `etapa_wallpaper` devolve 0 sem uma linha, enquanto a execução
   real armaria as unidades. **Ninguém rodou o cenário**; registrar como hipótese é o
   ponto. Conferir antes de consertar.
2. **`leiturabin` no `SEM_CONSERTO` do `bin/meow` ficou largo demais.** O
   `leitura_build.sh` ganhou hoje um caminho **sem `cargo`** (`_sem_cargo`) que repõe
   o binário a partir da árvore de build e reescreve a sombra `.desktop` — 365 bytes
   de texto, nenhuma compilação. O doctor **poderia** consertar isso, mas o laço de
   conserto dá `continue` **pelo nome** antes de olhar o código de saída, então a
   sombra órfã continua sendo linha amarela eterna. Sairia com uma `fix_leiturabin`
   que chamasse só o caminho sem-cargo. A decisão anterior — "um segundo verificável
   seria mais superfície do que conserto" — continua certa; o que mudou foi existir um
   conserto barato do outro lado.
3. **`wallpaper.log` cresce com ruído e ninguém o cala.** Medido em 31/08/2026:
   **141.793 bytes, 1.850 linhas**, das quais 1.770 são `ok carrossel já configurado`.
   O `meow-wallpaper.timer` bate de 15 em 15 minutos (`OnUnitActiveSec=15min`), o que
   dá **96 linhas por dia** de "nada mudou". O `meow-leitura.service` resolveu isso no
   nascimento, com `LOG_NIVEL=silencioso` na frente do `exec`; o `meow-wallpaper.service`
   não tem essa linha. É uma palavra na unidade.

### Fronteira

O patch do compositor e o binário são da **Aurora**; o `plugins_wings` da topbar é
dela e **escrito à mão** — nenhum script deste projeto o toca. As cinco chaves
`leitura_*` são a primeira fronteira deste projeto que não é entre o Meow e a Aurora,
e sim **entre o Meow e ela**, dentro do mesmo diretório: `docs/FRONTEIRA.md` tem a
tabela, os três estados do horário e o que o applet perdeu hoje.

---

## Por onde começar, em concreto

> **A versão anterior desta seção mandava executar a Sprint A do zero** — baixar
> 10 ícones do Arcticons, montar a folha, mostrar a ela. A Sprint A está FEITA
> desde 05/08/2026, com `strace` e 21 páginas de registro. Era exatamente o
> defeito que o topo deste arquivo descreve, no sentido inverso: a seção da
> sprint diz FEITA e o índice mandava refazer. Corrigido em 29/08/2026.

Quem pegar isto do zero, sem nenhum contexto de conversa, faz nesta ordem:

1. **Leia** este arquivo inteiro e `docs/COSMIC-THEMING.md` (os fatos medidos
   nesta máquina, com data e método — inclusive conclusões erradas anteriores e
   por que eram erradas).
2. **Confira o estado real**, não o que o texto promete:
   `./bin/meow doctor` e `git log --oneline -12`.
3. **Não há sprint aberta.** As duas últimas — [U](#sprint-u--sobreviver-a-um-dist-upgrade)
   e [V](#sprint-v--o-modo-de-leitura) — fecharam em 30 e 31/08/2026, e o que sobrou
   delas está na **lista de dívidas do índice**, que é por onde se começa. O material
   das duas está em `docs/pesquisas/2026-08-29-modo-leitura-e-botoes.md`, e o cartão de
   recuperação por TTY vem **antes** de qualquer build do compositor.
4. Se for mexer em ícone, a regra que atravessa tudo continua valendo: **a folha
   visual vem antes do código.** Foi ela que mostrou que 19 dos 27 candidatos a
   desenho autoral eram logomarca, e foi ela que fez a decisão do traço.

---

## O índice de estado — este é o produto

A regra do topo diz que fechar uma sprint são DUAS edições, a seção **e** o
índice. Este é o índice. Auditado em 29/08/2026, sprint por sprint, contra o
texto de cada seção e contra a máquina.

| sprint | assunto | estado |
|---|---|---|
| **A** | ícones do próprio COSMIC | FEITA em parte · 05/08 |
| **B** | curadoria assistida | FEITA · 08/08 |
| **C** | as pastas | FEITA e DESLIGADA · 08/08 |
| **D** | o wizard | FEITA · 05/08 |
| **E** | sincronização de assets | FEITA · 05/08 |
| **F** | a poda | FEITA · 05/08 |
| **G** | árvore v1 do tema | FEITA · 08/08 |
| **H** | o gato do dock | FECHADA · 11/08 |
| **I** | o lançador em traço | FECHADA · 11/08 |
| **J** | a pasta rosa, e os dois donos | FECHADA · 11/08 |
| **K** | ícones da bandeja | FECHADA · 11/08 · **com 2 dívidas dentro** |
| **L** | o qBittorrent que abre sozinho | FECHADA · 11/08 |
| **M** | o carrossel que não volta | FECHADA · 11/08 |
| **N** | o Spotify | NÃO ERA DEFEITO · a ação nunca teve registro de resultado |
| **O** | o terminal | FEITA · 25/08 |
| **P** | o ponteiro | FEITA · 25/08 |
| **Q** | o fastfetch | FEITA · 25/08 |
| **R** | o prompt | FEITA · 25/08 |
| **S** | dia e noite no papel de parede | FEITA · 25/08 |
| **T** | a regra da atenção | FEITA EM PARTE · o canto direito foi recusado com medição |
| **U** | sobreviver a um dist-upgrade | FECHADA · 30/08 · build feito e **na sessão dela** (o logout aconteceu em 30/08 20:25) |
| **V** | o modo de leitura | FECHADA · 31/08 · **com 3 dívidas dentro** |

### As dívidas que vivem dentro de sprints fechadas

Nenhuma destas tem dono, e todas estão enterradas dentro de uma seção marcada
como concluída — que é onde ninguém procura.

1. **O traço do ícone de bandeja da Steam** (Sprint K): 4 dá 1,33 px contra
   1,67 px dos vizinhos; o número que iguala é **5,0**, uma linha em
   `MEOW_TRAY_STEAM_TRACO`.
2. **O daemon do Hefesto** (Sprint K): roda, mas não registra item de bandeja no
   D-Bus. Nunca escalou para pergunta.
3. **As variantes de estado** (Sprint A): desenhar à mão ou achar um terceiro
   pack. É decisão dela, e está dentro de uma sprint FEITA.
4. **O `corner_radii` da v1** (Sprint G): 4/16/32/160 contra 2/8/8/8 da v2 — dois
   applets com canto de 16 onde o resto tem 8. O conserto é acrescentar à lista
   `CONJUNTO` do `gerar_tema_v1.py`.
5. **O atalho do histórico de clipboard** (Sprint T): o corte do applet só é
   defensável depois que ela tiver o atalho. Ele não virou item em lugar nenhum.
6. **`etapa_logo` e `etapa_wallpaper` com o modo seco cego** (Sprint V) —
   **HIPÓTESE, não medida**: o ramo `meow_seco` não pergunta
   `is-enabled`/`is-active`, então o `--dry-run` diria "já ligada" onde a execução
   real armaria a unidade. É o defeito que o `etapa_leitura` e o `etapa_autoreparo`
   consertaram em 31/08. Conferir antes de consertar.
7. **`fix_leiturabin` não existe** (Sprint V): com o caminho sem-`cargo` novo do
   `leitura_build.sh`, o doctor **poderia** repor binário e sombra sem compilar, mas
   o laço de conserto dá `continue` pelo NOME antes de olhar o código de saída.
8. **`wallpaper.log` sem `LOG_NIVEL=silencioso`** (Sprint V): 141.793 bytes / 1.850
   linhas em 31/08, 1.770 delas `ok carrossel já configurado`; o timer bate de 15 em
   15 min, o que dá ~96 linhas de ruído por dia. O irmão `meow-leitura.service` já
   nasceu com a chave na frente do `exec`.

### O trabalho de 26/08 que nunca teve sprint — e o de 30/08, que repetiu

`meow-painel.service` (o supervisor do painel), o clamp do raio de canto, o
`JANELAS_TILING` e o popup do applet de mídia estão no código e no `README.md`, e
este arquivo **não os menciona uma vez**. Os três verificáveis novos do doctor —
`painel`, `janelas`, `fundo` — nasceram daí. Se alguém for auditar o projeto pelo
`SPRINTS.md`, vai concluir que esse trabalho não existe.

**E aconteceu de novo quatro dias depois.** O modo de leitura inteiro — 10 arquivos,
um applet em Rust, cinco chaves, duas unidades — foi construído em 30 e 31/08 sem uma
linha aqui. Foi registrado em 31/08/2026 como
**[Sprint V](#sprint-v--o-modo-de-leitura)**, com as três dívidas acima. Duas
ocorrências em cinco dias fazem disto um modo de falha do processo, não um
esquecimento: **quem executa escreve no cabeçalho do arquivo que tocou** — e o
cabeçalho de um `.service` ou de um `main.rs` é justamente onde ela, e quem auditar,
nunca vão olhar.

---

## Estado atual — o que já está no ar

| entregue em 05/08/2026 | prova |
|---|---|
| 123 tipos de arquivo em Catppuccin | 14/14 alvos resolvem no pack pelo `Gtk.IconTheme` |
| ~~16 aplicativos do lançador em Catppuccin~~ **41 em TRAÇO** | 29/08: o `assets/icones/apps.map` está VAZIO desde 10/08 — nenhum app vem mais do acervo Catppuccin. São 14 do Arcticons + 27 convertidos, em `48x48/apps` |
| 242 wallpapers (eram 239) — hoje **54**, ver 24/08 | 3 faltavam por bug de URL não escapada, calado desde a 1ª semeadura |
| o tema parou de desfazer o vidro dela | fronteira por árvore + código 4, testados em COSMIC isolado |
| o doctor enxerga receita ≠ produto | `'Low2' pede alpha 7C, está gravado D9` |
| 28 ícones do próprio COSMIC em Arcticons | `strace` no `cosmic-settings`: 9 carregados do nosso tema já na 1ª tela |
| o acervo de gatos responde na hora | `.svg` solto → **1** disparo no journal, não laço |
| `meow configurar` edita o `meow.conf` | ENTER em tudo não escreve um byte |
| nenhuma promessa de portabilidade no repo | e nada do que a poda ia remover era código |

**O que espera decisão dela, e só isso:** a **barra do painel** (volume, wifi,
microfone, notificações), que continua no Papirus porque o Arcticons não tem
ícone de estado — e porque o Arcticons não tem famílias de ESTADO
(`audio-volume-*` em 5, `network-wireless-*` em 7) — e não mais porque ele seja
"acervo de apoio", regra que a decisão de 11/08 derrubou. As folhas das Sprints B e C (`~/folha-apps-orfaos-2.html` e
`~/folha-pastas-2.html`) documentam o que entrou e o que ficou de fora, com o
motivo medido de cada um.
| `assets/gatos/` responde na hora, sem esperar o relógio | um `.svg` solto disparou 1 vez e entrou; apagado, disparou 1 vez e saiu — e `install.sh` duas vezes não disparou nenhuma |

**Pendência que depende dela, e leva 2 segundos:** o vidro no disco ainda é o da
captura (`D9`) e não o que ela escolheu (`7C`), porque o estrago de 05/08 às
18:00:36 já foi consolidado. **Ela precisa abrir Aparência e mover o slider de
opacidade uma vez** — só a GUI faz a derivação completa. Escrever esse valor na
mão seria repetir o ato que causou o problema.

---

## Ordem sugerida  ← **MORTA em 29/08/2026**

> Esta seção dizia *"**A** vem primeiro… se a medição travar, **B**… **C** é irmã
> dela… **D** é infraestrutura… **F** é limpeza e pode ir a qualquer momento"*.
>
> **As seis estão FEITAS desde 05 e 08/08/2026.** A seção sobreviveu três semanas
> mandando refazer trabalho concluído, e era a última coisa que alguém lia antes
> de começar. Foi substituída pelo **índice de estado** acima, que é auditado
> contra o texto de cada sprint e contra a máquina.
>
> A única regra desta seção que continua valendo: **ela está trabalhando na
> própria máquina enquanto isto roda.** Nada de abrir janela na tela dela; para
> ver resultado, renderize em headless ou peça que ela olhe.


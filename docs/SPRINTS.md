# Sprints do MeowSystem-Theme

Este arquivo é **autossuficiente**: quem for executar uma sprint não precisa de
nenhum contexto de conversa anterior. Cada uma traz o que já foi medido, o que
fazer, em que arquivo, como conferir que ficou certo, e o que pode dar errado.

Última atualização: **25/08/2026**.

---

## AO VOLTAR, COMECE POR AQUI

**Há dez sprints abertas: H, J, L, N e a leva nova, O a T.** (A **M** estava nesta lista até 25/08/2026, quando a auditoria descobriu que ela foi fechada em 11/08 e ninguém marcou.)

As sete primeiras nasceram em **11/08/2026**, de uma lista que ela ditou olhando
a própria tela; **I e K fecharam no mesmo dia.** As seis novas (**O a T**)
nasceram em **25/08/2026**, do pedido dela de "meter um ricing" — e a instrução
foi explícita: **materializar as sprints, não executar.** Nada de O a T foi
aplicado.

Cada uma já vem com a causa **medida**, não suposta — o levantamento foi feito
antes de escrever este texto, e o que está aqui é o resultado dele.

**Antes de tocar em qualquer sprint de aparência, leia "A leva de 25/08/2026"**
mais abaixo: ela lista o que o COSMIC **não faz** (blur por app, animações,
waybar, widgets de desktop) e registra que o **vidro fosco já está ligado** — dois
frentes se contradisseram nisso, e a v1 do tema mente.

As sprints A a G continuam **feitas**: A, D, E e F em 05/08/2026; B, C e G em
08/08. Nada nelas foi reaberto.

**Comece pela tabela abaixo.** Ela diz o que é conserto de código (executável sem
perguntar) e o que é **decisão dela** (não se toca sem resposta).

| sprint | o que ela viu | causa medida | quem decide |
|---|---|---|---|
| **H** | o gato do dock está grudado nos apps, no centro, em vez de sozinho na esquerda | `expand_to_edges=false` faz o `cosmic-panel` **fundir** os três segmentos num bloco centralizado — está no fonte, não é palpite | **ela** (3 opções, todas com preço) |
| **I** | "à exceção dos jogos, todos deveriam ter um ícone próprio nosso desenhado" | o "nosso tema" é o **traço**, não o desenho autoral — e um conversor leva o chapado ao traço | **FECHADA em 11/08/2026** |
| **J** | "a pasta do sistema operacional ainda é a mesma pasta rosa" | o desenho autoral do Gestor de Arquivos **é** uma pasta genérica, na mesma cor das pastas de verdade — e há **dois SVGs brigando** pelo mesmo nome | **ela** (é gosto, não defeito) |
| **K** | "temos o problema do ícone do tray de todos os apps" | a Steam **regrediu** ao PNG de fábrica de 2014; qBittorrent e Spotify **não têm via** pelo tema | **FECHADA em 11/08/2026** |
| **L** | "o qBittorrent segue iniciando com o sistema operacional" | **não é o MeowSystem**: o Ritual da Aurora recopia o autostart a cada hora | código, mas **por fora** do território proibido |
| **M** | "o papel de parede voltou a ser o antigo. novamente" | a fronteira do `wallpaper.sh` conhecia **três** casos e classificou a reversão como "escolha dela" | **FECHADA em 11/08/2026** — a allowlist recomendada foi implementada no mesmo dia; ninguém atualizou este texto |
| **N** | "spotify falta o spicetify" | **não falta nada.** Está aplicado no disco desde 10/08 20:19. O app não é aberto desde 07/08 | ela (é só abrir) |
| **O** | — (levantado por frente) | o `cosmic-term` está com a **paleta ANSI de fábrica**: existe `font_name` e `opacity`, não existe `color_schemes_dark`. É a única peça do sistema sem Catppuccin | código |
| **P** | — | o cursor é o `Pop`, da distribuição. A chave **não** fica no `CosmicTk`: é `gsettings org.gnome.desktop.interface cursor-theme` | **DECIDIDO 25/08:** `catppuccin-latte-mauve` (Latte porque só ele tem corpo claro) |
| **Q** | — | o `fastfetch` dela abre com o logo do **Pop!_OS**. A direção que ela escolheu é **pixel art** | **DECIDIDO 25/08:** a Coquinha em ANSI, de foto dela |
| **R** | — | o prompt é `agnoster`, de 2010. `starship` não está instalado. Mora em `~/.config/zsh`, que é **território da Aurora** | código, **por fora** |
| **S** | "esse em específico eu odiei" (o vaporwave claro) | o carrossel não distingue claro de escuro; um papel claro dentro de um sistema Mocha lava as duas barras. **Depende da Sprint M** | código |
| **T** | — | quatro candidatos a ponto focal e nenhum vence. **mauve = aceso**, em três lugares só | **DECIDIDO 25/08:** faz relógio e canto direito; o logo do gato só como mockup |

~~E uma dívida que não é sprint, mas é o maior risco do repositório hoje: **o
`git` está cinco dias atrasado.**~~ **PAGA em 24-25/08/2026.** O `HEAD` era de
~06/08 com o disco em ~10/08 — 250 caminhos fora do git, incluindo o módulo do
Spotify e o `RECUPERACAO.md`, que é o manual de resgate para quando o Flathub
atualizar o app. Hoje o Spotify está em `70afe7a`, o applet de mídia em
`7bd7f07`, a curadoria de papel de parede em `527b36d`, e a árvore está limpa.
Fica registrado porque **o modo de falha volta sozinho**: é imagem grande e
trabalho de outra sessão que não se commita, não um evento único.

O hábito de sempre continua: rodar `./bin/meow doctor` antes de acreditar em
qualquer coisa escrita aqui.

---

## Sprint H — o gato do dock, agrupado no centro  ← **ABERTA, decisão dela**

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
> Arcticons e **25** de `icons/convertidos-apps/`, que é arte do PRÓPRIO
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
**prontos**, com desenho autoral em `src/icons/autorais/`. Ela olhou para eles na
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
- o alvo não é abstrato: `icons/arcticons-apps/` tem 39 SVGs com grade,
  `stroke-width` e terminações medíveis. É esse peso que a saída tem de imitar.
- o teste honesto não é o par antes/depois. É **misturar conversões novas com
  Arcticons feitos à mão, sem rótulo**. Se ela não distinguir, funciona.
- e o caso mais duro é `src/icons/autorais/`, chapado com contorno — é lá que a
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
`icons/apps-arcticons.map:296-298` como "os que ficam de fora, por honestidade" —
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
  `palette/catppuccin.json`. Nome que não existe na paleta faz o script morrer.
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
| `scripts/construir_convertidos.sh` | dono único de `icons/convertidos-apps/`. `--conferir`, `MEOW_DRY_RUN`, `meow_escrever`, remove órfão, e **o retoque à mão vence a conversão e nunca é sobrescrito** |
| `icons/apps-convertidos.map` | 25 linhas, `nome : origem : cor [ : parâmetros ]`. **Um mapa, dois leitores**: o gerador lê 1/2/4, o instalador lê 1/3 |
| `icons/convertidos-apps/` | o acervo gerado, **commitado** — 25 SVGs |
| `icons/convertidos-apps/retoques/` | GIMP (boca aberta + a variante discreta), Gradia, Flatseal, Warehouse, e o `LEIA-ME.txt` com a medição |

**Arquivos mudados**

| arquivo | mudança |
|---|---|
| `scripts/icones_apps_arcticons.sh` | lê os **dois** acervos (aditivo). `_vestido()` **não mudou uma linha** — a conversão sai no mesmo dialeto. `TRACO` de `1` para `1.75`. Continua dono único de `48x48/apps` |
| `icons/apps-arcticons.map` | 22 nomes saíram para o mapa novo; 16 ficaram, cada um por medida |
| `bin/meow` | `chk_convertidos`, dentro de `SEM_CONSERTO` |
| `icons/PROCEDENCIA.md` | o acervo novo, a herança **GPL-3.0** do Papirus, e os desenhos à mão |
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
  dos autorais existe e é boa, mas quem decide ali é a **Sprint J**, que segue
  aberta e é gosto dela. Antecipar seria decidir no lugar dela — o erro que este
  mesmo mapa já registra ter cometido uma vez, hoje de manhã.
- **O `com.system76.CosmicPlayer` continua desenhando a PALAVRA "player".** É o
  glifo `player` do Arcticons, e letra vetorizada a 48 px é o defeito que o
  `apps-arcticons.map` já documenta em outros quatro glifos trocados. Não foi
  mexido porque ele é um dos oito da Sprint J. **Fica registrado como pendência
  visível.**

---

## Sprint J — a pasta rosa, e os dois donos do mesmo nome  ← **ABERTA, decisão dela**

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
   do `icons/apps-arcticons.map`.~~ **Feito e DESFEITO no mesmo dia — ver abaixo.**
2. **Decisão dela:** o Gestor de Arquivos continua sendo uma pasta? Se sim, ao
   menos **sai do accent** e ganha cor de identidade própria, como os outros
   sete, para não se confundir com as pastas de verdade nem com a Lixeira. Se
   não, precisa de silhueta nova — e aí entra na folha da Sprint I.

### Achado 3 — o conserto estava certo e o vencedor estava errado (11/08/2026)

O item 1 acima foi executado na manhã de 11/08 (commit `aacdc3c`): as 8 linhas
saíram do `icons/apps-arcticons.map`, o autoral em `scalable/apps` ficou como
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

1. as 8 linhas voltaram ao `icons/apps-arcticons.map`, idênticas ao estado
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

Os 8 SVGs autorais continuam versionados em `src/icons/autorais/` e o gerador
continua produzindo-os. Desfazer é mover os 8 nomes de `RETIRADOS` de volta para
`AUTORAL` e tirar as 8 linhas do mapa — nunca só uma das duas coisas, que é
exatamente como o defeito nasceu.

### Achado 4 — a mesma doença fora da lista dos 8: o `meow-whatsapp`

Procurado o padrão, ele tinha um segundo caso. O `app-themes/zapzap/manifesto.sh`
instalava uma **bolha verde cheia** (o `whatsapp-desktop` do Papirus recolorido)
em `scalable/apps/meow-whatsapp.svg`, enquanto o `icons/apps-arcticons.map` traz
`meow-whatsapp:whatsapp:sky` — glifo de **traço** — desde a unificação de 10/08.
Dois donos, mesmo nome, e o `scalable` vencendo pelo mesmo motivo.

Pelo critério dela, vence o traço. O módulo do zapzap parou de instalar a bolha e
passa a removê-la; o que ele continua fazendo é o que só ele pode fazer — gravar
`Icon=meow-whatsapp` no `.desktop`, que é o nome pelo qual a linha do mapa
alcança o app.

**A bandeja não foi tocada, e foi conferido antes:** o ícone da bandeja do ZapZap
nunca passou por este SVG. Ele é `IconPixmap` cru pelo D-Bus (Achado da pesquisa
de 05/08), e foi vestido na **fonte do app** — o `tray_icon.py` do flatpak, mais
a chave `tray_theme=symbolic_light` — como registra o `icons/bandeja.map`.

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
   `icons/bandeja.map` pedia.
3. Glifo `steam` no acervo, em `icons/arcticons/steam.svg` (38 glifos). **Não
   foi baixado**: já estava em `icons/arcticons-apps/steam.svg`, mesmo pack e
   mesma licença — foi `cp`, pela regra que o `shield` inaugurou. Conferido
   mesmo assim contra o upstream (713 bytes byte a byte idênticos) e registrado
   em `icons/PROCEDENCIA.md`.
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

## Sprint L — o qBittorrent que abre sozinho  ← **ABERTA, a causa é de fora**

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
`app-themes/qbittorrent/manifesto.sh:7-46` declara: *"o qBittorrent NÃO é nosso
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
Se abrir **em branco** → é o cenário 2 do `app-themes/spotify/RECUPERACAO.md`:
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
| **Spotify** | módulo novo, pelos *design tokens* do Encore — sem spicetify. **Revertido em 10/08/2026: agora é o spicetify que aplica** e o Meow decide o flavor/acento (`app-themes/spotify/manifesto.sh`, item 0; recuperação em `RECUPERACAO.md`) |
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
é o dela (2/8/8/8), já declarado em `palette/cosmic-map.json →
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

E as **quatro capturas** de `state/tema/` carregam o mesmo `v1` fóssil, md5
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
sendo `palette/catppuccin.json` e o mapa de destino, `palette/cosmic-map.json`.
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
  ancorado em `palette/catppuccin.json`.
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

Dois frentes se contradisseram, e o erro é instrutivo. Um leu
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
`palette/cosmic-map.json` do próprio projeto grava isso na seção
`estrutura_preservada`. **A v1 é legado e mente.** Quem for medir estado de tema,
leia a v2.

**A armadilha que sobra:** 308 dos 350 temas do `cosmic-themes.org` gravam
`is_frosted: false`, e o Catppuccin oficial para COSMIC está parado desde
04/2025 e não conhece as chaves novas. **Aplicar tema de terceiro desliga o
fosco.** Se um dia isso acontecer, a ordem é: aplicar o tema primeiro, religar o
fosco depois.

---

## Sprint O — o terminal está de fábrica  ← **ABERTA, código**

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
pasta `themes/cosmic-term/`, nos 4 flavors.

**A armadilha que decide o desenho da sprint:** o README manda importar pela GUI
(**View → Color schemes… → Import**). Antes de escrever qualquer script, **medir
onde a importação cai no disco** — se ela vira arquivo em
`~/.config/cosmic/com.system76.CosmicTerm/v1/color_schemes_dark`, o projeto pode
escrever direto e o módulo é trivial. Se o formato for opaco, o caminho é o mesmo
das capturas de tema (`state/tema/`): importar **uma vez** na GUI e fotografar.

**Como conferir.** `cat ~/.config/cosmic/com.system76.CosmicTerm/v1/color_schemes_dark`
existe e o nome aparece; e a olho: `#CBA6F7` (o mauve dela) no lugar do magenta
de fábrica.

**Não fazer:** não mexer em `font_size` nem `opacity` — os dois são escolha dela,
e o `opacity: 96` já está no ponto.

---

## Sprint P — o ponteiro não tem tema  ← **ABERTA, decidida em 25/08**

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

## Sprint Q — o cartão de visita mostra a marca errada  ← **ABERTA, decidida em 25/08**

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

## Sprint R — o prompt é de 2010  ← **ABERTA, código**

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
(`__MEC_FZF_COLOR`), usada **só** dentro do seletor de modelo de IA. O `fzf` do
dia a dia (Ctrl+R, completion) roda sem cor nenhuma. É promover uma paleta que
ela já validou de "um script" para "todo uso".

---

## Sprint S — a noite não é o padrão  ← **ABERTA, código**

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

## Sprint T — a regra da atenção  ← **ABERTA, decidida em 25/08 (em parte)**

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
COSMIC, e a regra do projeto (`docs/FRONTEIRA.md:133`) diz que onde a GUI tem
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
- **S** (dia/noite) depende da **Sprint M**, que é pré-requisito: não adianta
  separar claro de escuro se a configuração é revertida a cada 15 minutos.
- **R** (prompt) é a única que o MeowSystem **não executa sozinho** — mora em
  `~/.config/zsh`, território da Aurora, e sai como patch ou como comando que ela
  roda.

---

## O que ficou de fora, e por quê

Levantado, avaliado e **descartado** — para ninguém gastar tempo de novo:

| item | por que não |
|---|---|
| **dock flutuante** (`expand_to_edges: false`) | é literalmente a **Sprint H**, que já está aberta esperando decisão dela: o mesmo `false` que descola a dock das bordas **funde os três segmentos** e é a causa do gato estar grudado no centro. Não é sprint nova, é a mesma decisão |
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
| `catppuccin/vscode-icons` | `icons/catppuccin/<flavor>/` | 656 glifos × 4 flavors, MIT, linha fina pastel. É o pack do Iconify (`catppuccin:*`) e do allsvgicons — **os três links são o mesmo acervo**. | **tipos de arquivo** e **pastas**. 123 mimetypes instalados. |
| `Daveedmee/catppuccin-icons` | `icons/catppuccin-apps/<macchiato\|latte>/` | 146 PNG 512×512 com alpha. As marcas conhecidas recoloridas em pastel. **Sem licença declarada** — uso local, nunca redistribuir. | **aplicativos**. 16 instalados. |
| Arcticons | `icons/arcticons/` e `icons/arcticons-apps/` | 14.996 nomes, CC BY-SA 4.0, traço monocromático em grid 48. Baixado um a um pela API do Iconify. | os **ícones de sistema** (56, em `<tam>/status`) e o que falta de **aplicativo** (1, em `48x48/apps`). **Não tem estado** — por isso a barra fica no Papirus. |
| desenho autoral | `src/icons/autorais/` | 10 SVG × 4 flavors, gerados por `scripts/gerar_icones_autorais.py`. | os 8 apps do COSMIC + FogStripper + Hefesto. |

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
ls icons/catppuccin/macchiato/ | sed 's/.svg$//' \
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
> (`icons/PROCEDENCIA.md`, `icons/sistema.map`, a Sprint A) que dizem 14.996.
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
`stroke`/`fill`. E este projeto já tem a fonte única de cor — `palette/catppuccin.json`,
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
   em RGB (frentes deste projeto já escreveram esse conversor duas vezes; a
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
  registre a procedência em `icons/PROCEDENCIA.md` como o projeto já faz para
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
> `icons/sistema.map` e `scripts/icones_sistema.sh`. Provado com `strace`: o
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
> termina na escolha dela, e o `icons/apps.map` segue intocado.
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
> `icons/catppuccin-apps/$VARIANTE/*.png` e escreve em `512x512/apps`.

### O registro de como a sprint foi desenhada (continua válido)

**Por que existe.** Ideia dela, textual: *"os que não encontrarem peça pros
frentes procurarem semelhantes usando regex similares e criando uma lista com os
possíveis icons e eu escolho."*

**O estado atual, medido.** Dos 51 aplicativos com ícone nesta máquina:

- 16 já usam o acervo Catppuccin de aplicativo (`icons/apps.map`)
- 10 usam desenho autoral (8 do COSMIC + FogStripper + Hefesto)
- **os demais continuam no Papirus** — e são o alvo desta sprint

Para gerar a lista dos que faltam:

```bash
./scripts/auditar_icones.sh --json > /tmp/audit.json
python3 - <<'EOF'
import json, glob, os
d = json.load(open('/tmp/audit.json'))
mapeados = {l.split(':')[0] for l in open('icons/apps.map')
            if l.strip() and not l.startswith('#')}
for a in d['aplicativos']:
    if a['icone'] not in mapeados and 'Papirus' in a['tema']:
        print(f"{a['icone']:38} {a['nome']}")
EOF
```

**O trabalho dos frentes.** Um frente por aplicativo órfão, em paralelo. Cada um
recebe: o nome do `.desktop`, o nome legível do app, e os dois acervos. Cada um
devolve **até 5 candidatos**, cada candidato com: o arquivo, por que ele foi
sugerido, e um veredito honesto de se ele **mente** sobre o que é o aplicativo.

A busca é por regex sobre os nomes dos dois acervos, mais o nome legível:

```bash
ls icons/catppuccin/macchiato/ icons/catppuccin-apps/macchiato/ \
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
do acervo de aplicativo (`icons/catppuccin-apps/`) ou não existem, e aí o ícone
fica no Papirus e isso é dito na folha em voz alta, em vez de forçar um
casamento ruim.

**Ícone de pasta como ícone de aplicativo é decisão dela, não sua.** `folder_app`
na Loja de Aplicativos pode ficar excelente ou pode confundir pasta com programa.
Entra na folha como candidato marcado, com o veredito honesto ao lado.

**A regra que decide, e ela custa cobertura de propósito:** só entra quando é o
**mesmo aplicativo**. Já foram descartados, com correspondência tentadora e
falsa: `BoxySVG → inkscape`, `CosmicEdit → notepad`, `ProtonUp-Qt → lutris`,
`BleachBit → ccleaner`. **Um ícone errado é pior que um genérico, porque mente
sobre o que a coisa é.** Se o frente achar que vale mesmo assim, ele marca como
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

**Depois que ela escolher:** as linhas entram em `icons/apps.map` e
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
> `icons/pastas.map`. Folha em `~/folha-pastas-2.html`.
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
`zsh/_meow` (completion), `meow.conf.exemplo` (é a lista de chaves e a fonte dos
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

## Por onde começar, em concreto

Quem pegar isto do zero, sem nenhum contexto de conversa, faz nesta ordem:

1. **Leia** este arquivo inteiro e `docs/COSMIC-THEMING.md` (os fatos medidos
   nesta máquina, com data e método — inclusive conclusões erradas anteriores e
   por que eram erradas).
2. **Confira o estado**: `./bin/meow doctor` e `git log --oneline -12`.
3. **Sprint A**, e comece pela **medição**, não pelo código: descobrir quais
   ícones o `cosmic-settings` pede e onde cada um resolve hoje.
4. **Baixe uma amostra do Arcticons** (10 ícones, pela API do Iconify), colora
   pelo método acima, e **monte a folha visual** a 22 px e 48 px, nos dois
   fundos. Mostre a ela **antes** de processar 13 mil.
5. Só depois de ela aprovar a folha, escreva o gerador.

A regra que atravessa tudo: **a folha visual vem antes do código.** Foi assim que
se descobriu que 19 dos 27 candidatos a desenho autoral eram logomarca, e foi a
folha que fez ela decidir abandonar os ícones autorais.

---

## Estado atual — o que já está no ar

| entregue em 05/08/2026 | prova |
|---|---|
| 123 tipos de arquivo em Catppuccin | 14/14 alvos resolvem no pack pelo `Gtk.IconTheme` |
| 16 aplicativos do lançador em Catppuccin | Firefox, Discord, Spotify, VLC, Steam conferidos no resolvedor |
| 242 wallpapers (eram 239) — hoje **54**, ver 24/08 | 3 faltavam por bug de URL não escapada, calado desde a 1ª semeadura |
| o tema parou de desfazer o vidro dela | fronteira por árvore + código 4, testados em COSMIC isolado |
| o doctor enxerga receita ≠ produto | `'Low2' pede alpha 7C, está gravado D9` |
| 28 ícones do próprio COSMIC em Arcticons | `strace` no `cosmic-settings`: 9 carregados do nosso tema já na 1ª tela |
| o acervo de gatos responde na hora | `.svg` solto → **1** disparo no journal, não laço |
| `meow configurar` edita o `meow.conf` | ENTER em tudo não escreve um byte |
| nenhuma promessa de portabilidade no repo | e nada do que a poda ia remover era código |

**O que espera decisão dela, e só isso:** a **barra do painel** (volume, wifi,
microfone, notificações), que continua no Papirus porque o Arcticons não tem
ícone de estado — e porque ela definiu o Arcticons como acervo de APOIO, não como
tema principal. As folhas das Sprints B e C (`~/folha-apps-orfaos-2.html` e
`~/folha-pastas-2.html`) documentam o que entrou e o que ficou de fora, com o
motivo medido de cada um.
| `assets/gatos/` responde na hora, sem esperar o relógio | um `.svg` solto disparou 1 vez e entrou; apagado, disparou 1 vez e saiu — e `install.sh` duas vezes não disparou nenhuma |

**Pendência que depende dela, e leva 2 segundos:** o vidro no disco ainda é o da
captura (`D9`) e não o que ela escolheu (`7C`), porque o estrago de 05/08 às
18:00:36 já foi consolidado. **Ela precisa abrir Aparência e mover o slider de
opacidade uma vez** — só a GUI faz a derivação completa. Escrever esse valor na
mão seria repetir o ato que causou o problema.

---

## Ordem sugerida

**A vem primeiro** — ela pediu duas vezes, e a segunda foi só para reforçar. Mas
comece pela **medição**, não pelo código: descobrir de onde os ícones vêm e
mostrar a folha antes de decidir. Se a medição travar, **B** (curadoria dos
ícones que faltam) tem o maior ganho visível e já tem método pronto, e **C**
(pastas) é irmã dela e sai na mesma folha. **D** é infraestrutura e não muda
pixel (**E** já foi feita, em 05/08). **F** é limpeza e pode ir a qualquer
momento.

Ela está trabalhando na própria máquina enquanto isto roda. Nada de abrir janela
na tela dela; para ver o resultado, renderize em headless ou peça que ela olhe.

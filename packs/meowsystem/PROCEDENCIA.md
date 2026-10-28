# De onde vem cada ícone deste repositório

[P88, 15/10/2026: este arquivo era `assets/icones/PROCEDENCIA.md`. O acervo de
ícone do motor virou o pack-base `packs/meowsystem/`, nas três pastas da
decisão 14; os resgatados, de cor Dracula fixa, foram para `packs/dracula/`.]

Feito para uma máquina só, e **público desde 06/09/2026** — a decisão de
05/08 de não publicar caiu. Isso muda o peso desta tabela: enquanto o uso era
local, a procedência era só uma nota de cuidado; agora ela é a resposta à
pergunta que qualquer pessoa pode fazer sobre o que está aqui dentro.

A coluna "pode redistribuir?" passa a valer de verdade, e uma linha dela
precisava de conserto: o acervo `Daveedmee/catppuccin-icons` tem licença **não
declarada** e nunca esteve no git — mas por acidente, não por decisão. Os 292
arquivos dele são PNG, e o `.gitignore` exclui `*.png` desde antes de qualquer
um pensar em licença. Um SVG dali entraria no repositório sem nada avisar.
Desde 06/09/2026 o diretório está excluído pelo NOME, com o motivo escrito ao
lado da regra.

| acervo | onde | licença | pode modificar? | pode redistribuir? |
|---|---|---|---|---|
| `catppuccin/vscode-icons` | `packs/meowsystem/icones/sistema/` — os **75** moldes que o `mimetypes.map` usa, pintados na instalação; os outros **581** em `biblioteca/` | MIT | sim | sim, com o aviso de copyright |
| `Daveedmee/catppuccin-icons` | `assets/icones/catppuccin-apps/<flavor>/` | **não declarada** | indefinido | **não** — uso local apenas |
| Arcticons (sistema) | `packs/meowsystem/icones/sistema/` e `biblioteca/` (a lista em `icones/arcticons.lista`) — **39** glifos | **CC BY-SA 4.0** | **sim** | sim, **com atribuição e sob a mesma licença** |
| Arcticons (aplicativo) | `packs/meowsystem/icones/apps/` e `biblioteca/` — **39** glifos, **16 em uso**, **recoloridos** | **CC BY-SA 4.0** | **sim** | sim, **com atribuição e sob a mesma licença** |
| **convertido do Papirus** | `packs/meowsystem/icones/apps/` (o mapa em `icones/apps-convertidos.map`) — **22** SVGs **gerados** | **GPL-3.0** (obra derivada) | sim | sim, **sob GPL** |
| **desenho à mão do traço** | `packs/meowsystem/icones/apps/` e `biblioteca/` — **3** desenhos + **2** variantes do GIMP | deste projeto (a do GIMP é derivada, GPL-3.0) | — | — |
| marca de fábrica | `packs/meowsystem/icones/apps-hicolor.map` — **1** nome, copiado do `hicolor` do sistema | a do próprio programa | **não** — cópia literal | não |
| Papirus / Papirus-Dark | pacote `papirus-icon-theme` do sistema | GPL-3.0 | sim | sim, sob GPL |
| `catppuccin/papirus-folders` | `~/.cache/meowsystem/upstream/papirus-folders/` | GPL-3.0 | sim | sim, sob GPL |
| desenho autoral | `packs/<id>/icones/apps/` e os `leitura-*.svg` de `packs/meowsystem/icones/sistema/` | deste projeto | — | — |
| **desenho do traço, sistema** | `packs/meowsystem/icones/sistema/` — **137** glifos (as famílias de estado da barra, energia, mídia, janelas e as páginas das Configurações, P131), no traço do Arcticons | deste projeto | — | — |

## Dois acervos com nome parecido, e cada um veste uma coisa

Já confundiram uma análise inteira. A diferença não é de organização, é de
**forma** — e a linha do `papirus-folders` na tabela acima apontava para o
*script* (`scripts/construir_pastas.sh`) em vez de apontar para o acervo, o que
ajudava a confusão. Corrigido em 10/08/2026.

| | `packs/meowsystem/icones/sistema/` (o molde) | `~/.cache/meowsystem/upstream/papirus-folders/` |
|---|---|---|
| upstream | `catppuccin/vscode-icons` | `catppuccin/papirus-folders` |
| forma | `fill="none"` + `stroke`, `viewBox="0 0 16 16"` — **traço** de árvore de arquivos do VS Code | pasta **cheia**, com dobra, sombra e símbolo interno, 22..64 px |
| quem consome | `scripts/icones_pastas.sh` (as pastas XDG, hoje **desligado**) | `scripts/construir_pastas.sh` (**todas** as pastas) |
| serve de pasta de gestor de arquivos? | **não** | é a fonte viva das pastas, na cor do acento |

São **228 glifos `folder_*` por flavor**, em **cinco** diretórios
(`css-variables`, `frappe`, `latte`, `macchiato`, `mocha`) — mas são ícone de
pasta do **editor**, não de gestor de arquivos.

**Ela reprovou o `vscode-icons` como pasta, olhando a tela, em 08/08/2026:** *"as
pastas do temas dos icons do vscode catpuccin, tipo as folders, essas não tão
legais tambem"*. O motivo está medido em `scripts/icones_pastas.sh` — são pasta
vazada de traço claro ao lado das mauve cheias, e **nenhuma usa `mauve`**, que é
o accent dela. O recurso ficou de pé atrás de `PASTAS_XDG="nao"` em vez de ser
apagado.

E em **10/08/2026** ela fechou a questão pelo outro lado: *"cada pasta ganha o
símbolo interno do que ela guarda, tudo recolorido no mauve dela"*. Ligar as sete
linhas do `vscode-icons` hoje **substituiria exatamente essas sete pastas** —
desfazendo as duas decisões de uma vez. **Não proponha o `vscode-icons` como
fonte de arte de pasta em nenhuma sprint.** A medição completa está em
`packs/meowsystem/icones/pastas.map`.

Na mesma data foi recusada também a troca de acervo para o pack **`cosmic-icons`**
(`/usr/share/icons/Cosmic/`, CC BY-SA 4.0, do pacote `cosmic-icons` do sistema).
Ele **não entra na tabela acima porque não é usado**: renderizado e comparado
lado a lado com o `papirus-folders` em mauve, a silhueta é praticamente a mesma,
e adotá-lo custaria um segundo dono de `scalable/places` e uma obrigação de
atribuição — para entregar o mesmo desenho. Se um dia entrar, entra com linha
própria e com a atribuição *"Cosmic Icons by System76"*.

## Arcticons — o que a licença obriga

**CC BY-SA 4.0** é *share-alike com atribuição*. Uso privado numa máquina só não
dispara obrigação nenhuma. O que dispara é **distribuir**: aí é preciso creditar
o Arcticons e liberar o derivado sob a mesma licença. Como este repositório não
é publicado, o ponto é teórico — mas se um dia for, o share-alike passa a ter
consequência sobre os ícones derivados dele, e só sobre eles.

### O `steam` do acervo de sistema foi CÓPIA, não download — 11/08/2026

O `assets/icones/arcticons/steam.svg` (o 38.º glifo) entrou em 11/08/2026 para o
`scripts/icones_tray_steam.sh` vestir o ícone de bandeja da Steam. Ele **não foi
baixado**: já estava versionado aqui, em `assets/icones/arcticons-apps/steam.svg` — mesmo
pack, mesma licença, e nenhum dos dois acervos lê o diretório do outro. Foi `cp`,
exatamente pela regra que o `shield` inaugurou em 10/08: *vale conferir o
repositório antes de sair baixando*.

Conferido mesmo assim contra o upstream: `curl -s
https://api.iconify.design/arcticons/steam.svg` devolve **713 bytes byte a byte
idênticos** ao arquivo que já estava aqui. Os dois arquivos são o mesmo desenho,
em `currentColor`, e continuam sendo **um** glifo do pack — não dois, para efeito
da contagem da tabela lá em cima.

A cópia não muda nada na tela sozinha: o `icones_sistema.sh` e o
`icones_bandeja.sh` leem os **mapas**, não o diretório, e nenhuma linha nova
entrou em `assets/icones/sistema.map` nem em `assets/icones/bandeja.map`. Quem usa este glifo é
só o `icones_tray_steam.sh`, que o nomeia direto no código porque o alvo dele é
**um** arquivo fora do tema de ícones, e um mapa de uma linha seria cerimônia.

- Fonte: <https://github.com/Arcticons-Team/Arcticons>
- Medido em 05/08/2026 pela API do Iconify: **14.996 ícones**. **Reconferido em
  08/08/2026** pelo índice completo, e agora com a conta aberta, porque "14.996"
  não é um campo da resposta: o campo `total` traz **14.913**, a lista `hidden`
  traz **83** (14.913 + 83 = 14.996) e `aliases` traz **304**. O universo de
  nomes que de fato RESOLVEM é a união dos três: **15.300**. Pesquisar só
  `uncategorized` deixa 387 nomes de fora — é por isso que a busca aqui é feita
  sobre a união, e não sobre a lista visível.
  `curl -s "https://api.iconify.design/collection?prefix=arcticons"`
- Baixado **um a um**, nunca o repositório inteiro:
  `https://api.iconify.design/arcticons/<nome>.svg`
- Formato: traço monocromático, `viewBox="0 0 48 48"`, `stroke="currentColor"`,
  **sem `stroke-width` declarado** (o padrão SVG é 1 — ver
  `docs/COSMIC-THEMING.md` §4g, porque isso some a 22 px).

### São DOIS acervos aqui, e a diferença é a cor

| | `assets/icones/arcticons/` | `assets/icones/arcticons-apps/` |
|---|---|---|
| quem consome | `scripts/icones_sistema.sh`, `scripts/icones_bandeja.sh` **e** `scripts/icones_tray_steam.sh` | `scripts/icones_apps_arcticons.sh` |
| mapa | `assets/icones/sistema.map` **e** `assets/icones/bandeja.map` (o da Steam não tem mapa: é **um** arquivo, nomeado no script) | `assets/icones/apps-arcticons.map` |
| destino | `22x22/status` + `scalable/status` (sistema) · `20x20/status` (bandeja) · `~/.steam/…/public/steam_tray_mono.png` (Steam) | `48x48/apps` |
| cor | **nenhuma** no acervo — fica em `currentColor` | **atribuída**, chave da paleta |

O acervo de sistema tem **três** consumidores porque a bandeja da barra é outro
consumidor do mesmo desenho monocromático — mas cada um é dono do seu diretório,
e nenhum escreve no do outro.

O terceiro é a exceção que confirma a regra da coluna "cor": o
`icones_tray_steam.sh` **coza `#DEDEDE` no PNG que produz**, e não porque
descuidou da paleta. O toolkit repinta `symbolic` e **não** repinta raster
(medido em `assets/icones/bandeja.map:79-94`), então num arquivo raster a cor tem de
estar dentro dele — e ela é cinza, não mauve, porque os vizinhos daquela barra
são cinzas. O SVG do acervo continua em `currentColor`; quem colore é o script,
no momento de rasterizar. Se os dois escrevessem em `scalable/status`, a
remoção de órfão de um apagaria o trabalho do outro a cada passagem: é o defeito
de "dois donos", que este projeto já pagou uma vez. Ver o cabeçalho do
`scripts/icones_bandeja.sh`, que mede por que `20x20` e não `22x22`.

A separação não é organização: é consequência do §4g do `docs/COSMIC-THEMING.md`.
Ícone `symbolic` de sistema tem a cor do arquivo **descartada** pelo toolkit, que
repinta tudo com a cor de texto do tema — pintar ali seria trabalho apagado.
Ícone de **aplicativo** não passa por esse caminho, e a cor sobrevive. Por isso o
acervo de aplicativo é recolorido e o de sistema não.

**Recolorir é o que a CC BY-SA autoriza**, e é a única modificação que fazemos:
a cor sai de `assets/paleta/catppuccin.json` (nunca um hex dentro de script) e entra no
lugar do literal `currentColor`. O desenho não é tocado.

### Um TERCEIRO diretório, que não veste ninguém: `assets/icones/previa-arcticons/`

13 glifos baixados em 10/08/2026, pela mesma API do Iconify e sob a mesma
CC BY-SA 4.0, para a folha `scripts/folha_icones.py` (na branch `arquivo`) mostrar como os ícones
FICARIAM se ela unificasse tudo no Arcticons. Estão **sem cor**, em
`currentColor`, e **nenhum script os instala**: não há mapa que os leia, e o
tema não os enxerga. São material de decisão, não de tema.

Se ela disser sim à unificação, cada glifo escolhido migra para
`assets/icones/arcticons-apps/` com uma cor atribuída por ela e uma linha no
`assets/icones/apps-arcticons.map` — que é o caminho normal. Se disser não, o diretório
inteiro sai. Manter os dois separados é o que impede uma prévia de virar tema
sem ninguém ter decidido.

O `utorrent` foi baixado e **descartado**: é a marca do µTorrent, um aplicativo
de outra empresa, e pô-la no qBittorrent mentiria sobre de quem a coisa é —
a mesma recusa que o `bandeja.map` já registrou para o `playstation-family` no
Hefesto. No lugar ficou `libretorrent`, que desenha uma rede ponto-a-ponto e não
a marca de ninguém.

## `assets/icones/convertidos-apps/` — arte NOSSA, derivada do Papirus — 11/08/2026

O quarto acervo de aplicativo, e o único que este projeto **gera**. Ele existe
porque o Arcticons dá o *estilo* (traço de linha) mas não dá o *próprio*: o
glifo `spotify` do pack é o desenho que o pack tem para aquele nome, não a marca
do aplicativo que está na máquina dela. A frase que abriu isto, em 11/08/2026,
foi *"no sentido de criarmos icons igual o nosso tema atual, entende?"*.

**Como se faz.** `scripts/converter_icone.py` rasteriza a arte chapada a 256 px,
quantiza em regiões de cor e traça a **fronteira entre elas** (não a silhueta
externa — silhueta pura apaga a identidade, e isso foi medido). A saída sai no
dialeto exato do Arcticons, que é o que permite ao `icones_apps_arcticons.sh`
vestir os dois acervos com o mesmo código. Quem roda o conversor e escreve o
diretório é `scripts/construir_convertidos.sh`, à mão, **nunca o `install.sh`**.

**A licença é GPL-3.0, e é herdada.** São **22** obras derivadas de
`/usr/share/icons/Papirus/64x64/apps/*.svg` (pacote `papirus-icon-theme`,
GPL-3.0). Converter para arte de linha é modificar, não citar: o resultado
continua sob GPL. Isto não muda nada hoje — o repositório não é publicado —
mas, se um dia for, este diretório vai junto com o texto da GPL, ao lado da
obrigação de *share-alike* que o Arcticons já impõe sobre o outro acervo.

**Um dos 25 nomes do mapa não é derivado de nada**: o Gradia (`mao` no campo da
origem) é desenho novo, deste projeto. E as marcas que aparecem nos convertidos
(Spotify, Steam, Telegram, GIMP…) continuam sendo **marcas dos donos delas** —
o que a GPL cobre é o arquivo, não o direito de marca. Uso local numa máquina
só não dispara obrigação nenhuma dos dois lados.

**Os retoques à mão.** `assets/icones/convertidos-apps/retoques/` guarda a arte que o
conversor não produz, e é a única parte deste acervo que sobrevive a uma
reconversão. Três desenhos novos (Gradia, Flatseal, Warehouse), na gramática do
traço, deste projeto; e o GIMP, que é a conversão do Papirus **mais uma curva
desenhada à mão** — logo, também GPL-3.0. O `LEIA-ME.txt` de lá registra a
medição que prova por que a boca do Wilber não sai de parâmetro nenhum.

**Os 22 glifos do Arcticons que estes 22 substituíram continuam em
`assets/icones/arcticons-apps/`**, sem ninguém os ler — o diretório tem **39** arquivos e
o `apps-arcticons.map` lê **16**. Não foram apagados de propósito: desfazer a
escolha dela tem de continuar custando uma linha de mapa, não um download. (A
linha desse acervo na tabela dizia "**8** glifos" desde a primeira versão, e
estava velha; corrigida na mesma passagem, junto com a coluna nova de "em uso" —
que é o número que interessa, porque acervo não é tema.)

## O que o Arcticons cobre, e o que ele não cobre

É um catálogo de **logos de aplicativo Android**, não de conceitos de sistema.
Uma busca por `vpn` devolve NordVPN e ProtonVPN; por `dock`, TrustDock. Ainda
assim, os nomes genéricos existem e são exatamente os que faltavam aqui:
`wifi` `bluetooth` `volume` `battery` `keyboard` `mouse` `apps` `clock`
`palette` `power` `settings` `access` `contacts` `tile` `earth` `speaker`.

Ausentes como conceito genérico, medido contra o índice completo de nomes:
`ethernet` `router` `modem` `cable` `display` `monitor` `screen` `window`
`workspace` `user` `globe` `language`.

**Não force casamento.** O `arcticons:network` é um **telefone de mesa** — usá-lo
para "Rede com fio" mente sobre o que a coisa é, e isso é pior que deixar no
Papirus. A regra do projeto vale aqui igual: um ícone errado é pior que um
genérico.

### O que ele cobre dos APLICATIVOS desta máquina — medido em 08/08/2026

Dos **12** aplicativos que naquele dia ainda vinham do Papirus, o pack tinha
match de nome exato para **1**: `onlyoffice-documents`. Os outros não existem no
universo de 15.300 nomes (`boxy`, `flatseal`, `protonup`, `pupgui`, `bleachbit`,
`apostrophe`, `foliate`, `btop`, `file-roller` dão **zero**; `warehouse` só devolve
`tp-warehouse`, que é outro programa; `snapshot` só devolve `vivaldi-snapshot`).

Existem **genéricos honestos** para alguns deles (`calculator`, `camera`, `zip`,
`books`, `cpu`, `shield`) e eles **não entraram sozinhos**: foram para a folha
visual `~/folha-apps-orfaos-2.html`, porque a decisão é dela. Foi ela quem fixou
o papel do pack, em 08/08/2026: *"o arcticons ele vem pra apoiar o outro tema
principal não vem pra ser o tema principal."*

### Remedido em 10/08/2026 — são **13**, e a pergunta mudou

Aquele "12" era um número escrito à mão, e ele envelheceu em dois dias. Pior: a
pergunta que o produziu era cega. Ela era *"quem vem do Papirus"*, e um flatpak
recém-instalado cujo ícone o Papirus não tem cai no `hicolor` que o **próprio
flatpak exporta** — diretório que está no `XDG_DATA_DIRS` e nunca entrou naquela
varredura. Some da conta parecendo resolvido.

A pergunta certa é *"quem NÃO resolve dentro do nosso tema"*, e ela devolve **13**
(de 62 entradas visíveis, 26 dentro do tema e 23 intocáveis — jogos da Steam e os
dois programas dela):

- **10** pelo `Papirus-Dark`: `org.gnome.FileRoller`, `com.boxy_svg.BoxySVG`,
  `com.github.tchx84.Flatseal`, `com.github.johnfactotum.Foliate`,
  `org.bleachbit.BleachBit`, `org.gnome.gitlab.somas.Apostrophe`,
  `org.gnome.Calculator`, `org.gnome.Snapshot`, `net.davidotek.pupgui2`,
  `io.github.flattool.Warehouse` — e todos resolvem em
  `48x48/**categories**/`, não em `apps/`: a busca do freedesktop não filtra por
  contexto, e quem procurar só em `apps/` inventa dez ausências (é a armadilha 1
  do cabeçalho do `scripts/completar_icones.sh`);
- **3** pelo `hicolor` que o flatpak do usuário exporta:
  `be.alexandervanhee.gradia`, `dev.edfloreshz.CosmicTweaks`,
  `io.gitlab.theevilskeleton.Upscaler`.

**O número é volátil de propósito** — o parque de flatpaks muda sozinho. Por isso
não se remede à mão nunca mais: `scripts/icones_orfaos.py` refaz a conta pelo
resolvedor de verdade (`--json` para máquina). Ele é **só leitura**: escolher
ícone é decisão dela.

### Quais dos 13 têm fonte licenciada, e quais não têm

Medido contra o índice completo do Arcticons (15.300 nomes) em 10/08/2026. A
coluna que importa é a última: onde não há fonte, **não há desenho a inventar** —
o ícone fica no Papirus, que é resultado e não fracasso.

| aplicativo | glifo Arcticons | está em `assets/icones/arcticons-apps/`? |
|---|---|---|
| Calculadora (GNOME) | `calculator` (genérico honesto) | **sim** |
| Câmera (Snapshot) | `camera` (genérico honesto) | **sim** |
| File Roller | `zip` (genérico honesto) | **sim** |
| Foliate | `books` (genérico honesto) | **sim** |
| Flatseal | `shield` (genérico honesto) | **sim** |
| Boxy SVG | — nenhum | não há |
| BleachBit | — nenhum (`ccleaner` é outro programa) | não há |
| Apostrophe | — nenhum | não há |
| ProtonUp-Qt | — nenhum (`proton` é a Proton AG, de e-mail e VPN) | não há |
| Warehouse | — nenhum (`tp-warehouse` é outro programa) | não há |
| Gradia | — nenhum | não há |
| Ajustes (CosmicTweaks) | — nenhum | não há |
| Ampliar (Upscaler) | — nenhum | não há |

Os **cinco** glifos da coluna do meio entraram no acervo em 10/08/2026 — é o que
faz o número da tabela lá em cima subir de 3 para 8. **Quatro** foram baixados um
a um da API do Iconify (`calculator`, `camera`, `zip`, `books`); o `shield`
**não foi baixado**: ele já estava versionado aqui, em `assets/icones/arcticons/`, o
acervo de SISTEMA — mesmo pack, mesma licença, e o `icones_apps_arcticons.sh` só
lê `assets/icones/arcticons-apps/`. Foi cópia, não download. Vale conferir o repositório
antes de sair baixando: os dois acervos vêm da mesma fonte e um `curl` por cima
faria a tabela contar o mesmo glifo duas vezes. Eles não
mudam nada na tela: quem o `scripts/icones_apps_arcticons.sh` lê é o **mapa**,
não o diretório, e nenhuma linha nova entrou em `assets/icones/apps-arcticons.map`.
Baixar é técnica e já está feito; **a cor e o sim/não são dela**, e é uma linha
`nome:glifo:cor` quando ela decidir.

Os **oito** de baixo não têm fonte com licença que sirva. Para eles as saídas
honestas são duas, e as duas são decisão dela: ficar no Papirus, ou receber arte
escolhida à mão na página de curadoria (`scripts/importar_icones.sh` a instala e
registra em `assets/icones/curadoria.map`). O que **não** se faz é forçar casamento de
nome — `arcticons:network` é um telefone de mesa, e usá-lo para "Rede com fio"
mentiria sobre o que a coisa é.

**O `btop` é o único que ela já decidiu, e ela pediu.** Em 08/08/2026 disse
*"obsidian btop telegram qb torrent não tão legais. não conseguimos substituir
elas?"*. O `btop` do Papirus era o **pior ícone da dock por medida** — placa
opaca `#3f3f3f` (62% da caixa, luminância < 0,10) e separação WCAG 1,61 em
`#3C3B50`, que é o **piso dos 48 ícones** dela. Entrou `osmonitor` em `maroon`
(uma tela com um gráfico dentro — sem marca de ninguém, logo sem mentira), com
+226% de separação nos dois estados escuros do vidro. A conta inteira, com os
candidatos recusados e o porquê de cada um, está no cabeçalho de
`assets/icones/apps-arcticons.map`.

## `assets/icones/resgatados/` — o desenho dela de volta ao vetor — 11/09/2026

O quinto acervo, e o único que **não muda o estilo de nada**. Ele existe porque
ela desenhou os ícones dos projetos dela, exportou para PNG, e perdeu os SVG
originais. A frase que abriu isto: *"meus pngs originais ficaram horríveis aqui
no cosmic (…) eu perdi os svgs que eu tinha criado deles e só tinha os pngs"*.

**O problema era medível.** Deduplicando por ID de `.desktop` — o arquivo em
`~/.local/share/applications` **sombreia** o de `/usr/share`, e contar os dois
dá número inflado —, dos **86** nomes de ícone distintos que os **91**
aplicativos visíveis pedem, **66** resolviam para SVG e **20** caíam em PNG. Num
COSMIC a 100% de escala numa tela de 24", um PNG de 128 px esticado até o
tamanho do dock é exatamente o "horrível" da queixa.

**Como se faz, e por que não pelo conversor.** O `construir_convertidos.sh` é a
ferramenta errada para isto, e a diferença é de intenção: ele **reescreve** arte
de terceiro no traço monocromático do Arcticons, para o app caber no tema. Aqui
a arte **já era dela e já estava certa** — o que se perdeu foi o arquivo. Passar
esses ícones pelo conversor jogaria fora justamente o que se quer de volta.

Então o redesenho é **decalque**: cada PNG foi aberto e redesenhado à mão em
path SVG, gradiente virando `<linearGradient>` de verdade, sombra virando
`<filter>`. Nada de `potrace` ou traçado automático, e nada de PNG embutido em
`<image>` — traçar não é redesenhar, e um PNG dentro de um SVG não é vetor.
O critério de aceitação foi numérico, não "achei bonito": cada SVG é renderizado
a 256 px e comparado ao original por RMSE (`compare -metric RMSE`), com teto de
**0,15**. Em 11/09/2026 os desenhos ficaram entre **0,018** e **0,105**. [A
frase não tinha data até a P67 (25/09/2026), e cinco desenhos mudaram depois
dela — o de 0,018 era o `uad-ng`, que hoje é outro desenho. Estão em «O antes e
depois», logo abaixo.]

**A coluna `autoria` do mapa decide o quanto se pode mexer.** `dela` é obra
autoral — reproduz, não reinterpreta, e se o SVG original reaparecer um dia, ele
vence o resgate sem discussão. `terceiro` é logo de terceiro que **ela
customizou** (paleta Dracula, morcego, casa assombrada): o PNG desta máquina não
é o logo oficial, e foi a versão dela que foi resgatada. `sistema` é ícone de
pacote que nunca passou pela mão dela, e entra só porque borrava igual.

**Os dois `Icon=` absolutos.** `guvcview` e `setup-mozc`
trazem o *caminho* do PNG na chave `Icon=`, em vez de um nome de ícone — e um
`Icon=` absoluto **pula a busca no tema inteira**. Para esses não basta instalar
o SVG: o `icones_resgatados.sh` põe uma cópia do `.desktop` em
`~/.local/share/applications`, que sombreia a do sistema, com a chave trocada
para o nome do ícone. Desligar o interruptor apaga a cópia e o arquivo do
sistema volta a valer intacto. `setup-mozc` fica de fora dessa parte por ser
`NoDisplay=true` — não aparece no lançador.

**O interruptor é dela.** `ICONES_RESGATADOS="sim|nao"` no `meow.conf`, ou
`meow icones resgatados sim|nao`. `nao` **remove** do tema, por nome, o que este
projeto pôs, e o PNG que estava atrás volta a valer. Não há estado guardado nem
resíduo. O acervo continua no repo de qualquer forma: desligar é sobre o que
aparece na tela, não sobre apagar o desenho.

**O antes e depois** fica em `assets/icones/resgatados/ANTES-E-DEPOIS.png`,
gerado por `scripts/resgatados_folha.sh` a partir do mesmo mapa — se um ícone
entrar ou sair do resgate, a folha refeita acompanha sozinha.

**A folha de hoje é de 17/10/2026: é a de 25/09/2026 sem os três pares que
saíram do mapa, cada um dos outros recortado dela e remontado na ordem do mapa;
o `resgatados_folha.sh` a confere pixel a pixel e não a regrava.** A de
25/09/2026, sprint P67, é a do `resgatados_folha.sh` com uma costura, dita
aqui. O script pede o PNG de origem no caminho que o
mapa guarda, e 12 dos 21 não estão mais nesta máquina: os nove do
`Dracula-Icones`, que saiu do disco, o do `scrcpy`, o do `guvcview` e o do
Thunderbird do flatpak. Rodado hoje, ele sai com doze molduras «sem o PNG» e
perde a comparação que é a razão de a folha existir. Então ela foi remontada a
partir da de 12/09/2026: cada par recortado da velha, a célula da DIREITA dos
cinco desenhos que mudaram trocada pelo SVG de hoje na receita do script
(`rsvg-convert` a 150 px, sobre o `#282A36`, moldura de 2 px), e o par do
`net.waterfox.waterfox`, que saiu do mapa em 23/09/2026 (P28), tirado — o
resgate dele continua em `resgatados/`. Conferido pixel a pixel (RMSE 0): fora
das doze células da esquerda que o script deixaria vazias, ela é a folha que o
script monta hoje; e as nove da esquerda cujo PNG ainda está no disco são as da
folha de 12/09. A costura só guardou o que o disco perdeu.
[Desde a P68 (25/09/2026) a costura é do script: a esquerda de um par sem PNG
sai da folha que já está no caminho, no mesmo lugar e com o mesmo rótulo, e
uma folha que ele não sabe costurar fica como está (sai 3). Rodado nesta
máquina, com os mesmos doze PNG fora do disco, ele devolve esta folha pixel a
pixel e não a regrava; o `tests/folha-dos-resgatados.sh` prende isso.]

O que a direita trocou, medido em 25/09/2026. As distâncias são `compare -metric
RMSE` a 150 px sobre o `#282A36`, entre a célula da folha de 12/09, o SVG de
hoje e o PNG da esquerda — a régua da folha, e não a de 256 px do critério
acima:

| desenho | o que mudou entre a folha de 12/09/2026 e esta | folha de 12/09 × hoje | PNG × folha de 12/09 | PNG × hoje |
|---|---|---|---|---|
| `org.gnome.Nautilus` | o corpo passou ao `surface0` e ao `surface1` do Dracula (P65, 25/09/2026; a conta a 256 px está no `packs/dracula/PROCEDENCIA.md`) | 0,026 | 0,012 | 0,028 |
| `photogimp` | o traço, refeito junto com os autorais do COSMIC (15/09/2026) | 0,035 | 0,046 | 0,055 |
| `uad-ng` | desenho novo, da leva do Dracula (15/09/2026) | 0,371 | 0,019 | 0,371 |
| `Ubuntu` | desenho novo, da leva do Dracula (15/09/2026) | 0,444 | 0,076 | 0,448 |
| `Ubuntu-selfservice` | desenho novo, da leva do Dracula (15/09/2026) | 0,245 | 0,033 | 0,239 |

Os três últimos passam do teto de 0,15 contra o PNG: não são mais decalque, são
desenho novo com o nome do resgate, e a folha agora mostra isso lado a lado.
[Até a revisão da P67 (25/09/2026) esta nota dizia que a folha era a de 12/09 e
que não se refazia aqui, e a tabela acima era o que a folha escondia.]

O `tests/frases-velhas.sh` cobra esta nota em duas coisas. A data da primeira
frase, «A folha de hoje é de…», é a do commit da folha: refeita a folha, a nota
anda junto. E um desenho que mude depois da folha, ou uma linha que entre ou
saia do mapa, tem de estar na primeira coluna de uma tabela cujo cabeçalho diga
«depois da folha de» e a data dela, enquanto a folha não for refeita — nome
citado de passagem, como os PNG que faltam, não conta.

**Licença.** Os `dela` são obra dela. Os `terceiro` são redesenho de logo de
terceiro já customizada por ela: a marca continua de quem é, e o uso aqui é o
mesmo de sempre neste repositório — tema pessoal, não publicado. Os `sistema`
derivam de ícone de pacote e herdam a licença do pacote de origem, registrada na
coluna do meio do mapa.

#### Os resgatados que mudaram na P96 (23/10/2026)

Quem usa escolheu uma versão por ícone (a página de escolha de 23/10); estes vestem agora
outro desenho que o da folha. A tabela vale até a folha ser refeita.

| resgatado — depois da folha de 17/10/2026 | o que mudou |
|---|---|
| `extase-em-4r73` | o desenho escolhido em 23/10 |
| `com.microsoft.Edge` | o desenho escolhido em 23/10 |
| `whatsapp-linux-app` | o desenho escolhido em 23/10 |
| `org.gnome.Nautilus` | o desenho escolhido em 23/10 |
| `photogimp` | o desenho escolhido em 23/10 |
| `com.github.rafostar.Clapper` | o desenho escolhido em 23/10 |
| `setup-mozc` | o desenho escolhido em 23/10 |
| `guvcview` | o desenho escolhido em 23/10 |

## O que não se toca, por pedido expresso dela

Os jogos da Steam (`steam_icon_*`), o **Hefesto** (a logo é dela) e o
**FogStripper**. `scripts/icones_apps.sh` recusa esses nomes mesmo que entrem no
mapa — a lista está em `INTOCAVEIS` e `INTOCAVEIS_PREFIXO`.

## `dracula-apps/` — o pack autoral Dracula (16/09/2026)

Dezessete desenhos **copiados** do `Dracula_OS-Theme`, que é repositório dele, e
um décimo oitavo que já morava aqui. O casamento app → desenho não foi refeito:
ele vem da SPRINT 32 daquele projeto, do `mapping.json` (214 aplicativos) e do
`catalog.json` (295 desenhos descritos em PT-BR). O que mudou foi o **endereço**:

| de onde veio | quantos |
|---|---|
| `src/icons/new-sessao-atual/` | 8 |
| `src/icons/current/scalable/apps/` | 5 |
| `src/icons/upstream/dracula-icons-circle/` | 2 |
| `src/icons/projects/` | 1 (`nyx.svg`, arte própria) |
| `assets/icones/resgatados/` (já daqui) | 1 (a Câmera) |

**Por que copiar em vez de apontar.** A segunda coluna do
`apps-dracula.map` apontava para dentro do `Dracula_OS-Theme`. Aquele repositório
só existe na máquina dele — um script que o lesse funcionaria de um lado e
quebraria do outro, e este projeto é puxado dos dois. Cada arquivo foi copiado
com o **nome do ícone que ele veste**, o que permite ao
`scripts/icones_apps_dracula.sh` conferir o mapa contra o disco sem sair daqui.

**A Câmera é o caso fora da regra.** `io.github.cosmic_utils.camera` veste o
`resgatados/guvcview.svg` — escolha dele, de 16/09/2026: *"a camera tem que ter o
guvcview.svg"*. O guvcview saiu da máquina na limpeza de 15/09 e o desenho
resgatado dele ficou sem app; a Camera do COSMIC estava de fábrica. Um desenho
órfão e um app sem desenho. Por isso a coluna do mapa é um **caminho** e não só
um nome: nem todo desenho mora em `dracula-apps/`.

**Não se recolore nada aqui.** Cada desenho traz de 6 a 10 cores próprias, todas
já da paleta Dracula (broom 6, key 7, dice 6, cat 10). É o oposto do Arcticons,
que é monocromático e é pintado por nós. A cópia é literal.

**Ligar e desligar.** `ICONES_DRACULA="sim"|"nao"` no `meow.conf`, e o cartão
está no painel, na aba «Ícones». Nasce em `"nao"`: onze dos dezoito nomes já
vestem arte aprovada no artifact de 12–15/09, e ligar troca os onze de uma vez —
o `scalable/apps` vence o `48x48/apps` no resolvedor. Ele escolheu *"Dracula
vence tudo"* em 16/09/2026 com os dois lados na mesa; o padrão continua `"nao"`
porque é o que vale numa máquina que não participou da decisão.

`"nao"` apaga só o que este projeto pôs, por nome e conferindo o conteúdo —
arquivo editado à mão fica. O Arcticons nunca saiu do `48x48`: ele reaparece
sozinho na passagem seguinte.

**Licença.** Os desenhos vêm de `dracula-icons-circle`/`dracula-icons-main`
(upstream do Dracula theme) e de arte própria dele. O uso aqui é o mesmo de
sempre neste repositório — tema pessoal, não publicado.


## O que entrou na P96 (23/10/2026)

| arquivo | de onde | lido de | licença | copiado em | sha256 |
|---|---|---|---|---|---|
| `icones/biblioteca/bluetooth.svg` | antes em `icones/sistema/arcticons/bluetooth.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `a21e9c731d8d378a53cb20ecd888c97f05e4e9656b16768822d522cb35c1acbc` |
| `icones/biblioteca/books.svg` | antes em `icones/apps/arcticons/books.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `98eb2de75dc35d458053d043a79ea2fec26a3ce6ce62a7e3a24858107a7ada32` |
| `icones/biblioteca/brave.svg` | antes em `icones/apps/arcticons/brave.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `0abe5067dc7550d51a7e170cd5eb1ef52a2519e668cbdf7923760812932358ba` |
| `icones/biblioteca/browser.svg` | antes em `icones/sistema/arcticons/browser.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `c05dd791c94d2a7079238fde1ce390a73911e691306918ca120ec4d4a2ed7677` |
| `icones/biblioteca/calculator.svg` | antes em `icones/apps/arcticons/calculator.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `9df7b5c00334f5b8acee8b8436d2dbf7b0793a1f07ac9eae413bdccb674cbb6c` |
| `icones/biblioteca/camera.svg` | antes em `icones/apps/arcticons/camera.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `832f397101336bf8cc5efddd71509e56a4c2572ba1ee656c1c1c5d58d5d7e3b5` |
| `icones/biblioteca/cleaner.svg` | antes em `icones/apps/arcticons/cleaner.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `ac7de4eca35b96c3b105a743d2126464acf09a7677af1bdfdde06356949fc256` |
| `icones/biblioteca/code-editor.svg` | antes em `icones/apps/arcticons/code-editor.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `d4d7a3b6fe4ca3ab661721b5b0c49910b1300be970719f928011c269e80347f9` |
| `icones/biblioteca/compressor.svg` | antes em `icones/apps/arcticons/compressor.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `c481734343fa254d62ed7acb4ca8bf4cfb001e4d3842d0456c81175cbfaea39a` |
| `icones/biblioteca/discord.svg` | antes em `icones/apps/arcticons/discord.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `bb4389d637de2721d02574420282627b1ddd580b114087dbc74b62314ae1ba63` |
| `icones/biblioteca/earth.svg` | antes em `icones/sistema/arcticons/earth.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `f987be65dfe100f7b42ed19f58657fa5fd1f949a799a62989a4bb5b0b563ad76` |
| `icones/biblioteca/editor.svg` | antes em `icones/apps/arcticons/editor.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `4595db52f0a9c0c6b191c5e7127e0d0bb0bca75708977412e0871706b1bbe441` |
| `icones/biblioteca/folder.svg` | antes em `icones/sistema/arcticons/folder.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `fd8555d676e867588b2988ebac28b3de05b9935171030626bd070862fd847cb5` |
| `icones/biblioteca/github.svg` | antes em `icones/apps/arcticons/github.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `9193a1b424de33868ee221bd424a7113765c92822e4dbee716c5c7efe27ed60d` |
| `icones/biblioteca/google-chrome.svg` | antes em `icones/apps/convertidos/retoques/google-chrome.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `ef37970e34a6e5d68db13d4fd69fb9b16b3833fd4fab823ad03c1a4fd3a41f74` |
| `icones/biblioteca/key.svg` | antes em `icones/sistema/arcticons/key.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `815c2b54fcfff240a9e1e904a36dd4e75436f83cf3030b668ed8c25c8a0c3015` |
| `icones/biblioteca/libretorrent.svg` | antes em `icones/apps/arcticons/libretorrent.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `5fbb41e795c1cad88928deead57c949d0a188c5a55f59ee5e77409842269040b` |
| `icones/biblioteca/moon.svg` | antes em `icones/sistema/arcticons/moon.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `5cb3332370a8257f3fb128b09801404ad82330111ddcbeedd3f95e232cc0a66d` |
| `icones/biblioteca/music.svg` | antes em `icones/sistema/arcticons/music.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `32b1db0447fb69f9315512509b05060fa57d3c4c54d839285c9137ec80eae0d5` |
| `icones/biblioteca/network.svg` | antes em `icones/sistema/arcticons/network.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `7bd1e5eb9c01d37188d5a4a0623295f94d610b8ba103c6faa3d1a2531142c362` |
| `icones/biblioteca/notifications.svg` | antes em `icones/sistema/arcticons/notifications.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `ddd824ede2a3ac9dc8040215ddcc598682290e9be6401931db56e71d39fb3e5b` |
| `icones/biblioteca/onlyoffice-documents.svg` | antes em `icones/apps/arcticons/onlyoffice-documents.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `368f2c76528ef2468db0959f24ca7e6d72a369702d202a9f8c27b74c14471a93` |
| `icones/biblioteca/org.gimp.GIMP-discreta.svg` | antes em `icones/apps/convertidos/retoques/org.gimp.GIMP-discreta.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `818a7bc7455a1fa3b646114edc43e915e8db8b0c666693f44c8a851be8d9263b` |
| `icones/biblioteca/photo-editor.svg` | antes em `icones/apps/arcticons/photo-editor.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `0f988533dc5df0c232011b1f80417f5e04fceb1afc50ea6dea0f7127d581d25b` |
| `icones/biblioteca/player.svg` | antes em `icones/apps/arcticons/player.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `809369cbd23f23e4c21bd76d8af5b5100d5b274301ea126aea4e19fbe992da27` |
| `icones/biblioteca/power.svg` | antes em `icones/sistema/arcticons/power.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `a62e8e5e4ebff08d274f7a8e89762b1a53cb4ef1be20c57558735e9df76660e3` |
| `icones/biblioteca/proton.svg` | antes em `icones/apps/arcticons/proton.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `8601046adaec5aec6d944c35bf154abfbad88cb8b4caa837ddaf8bafe6c9c20e` |
| `icones/biblioteca/screen-recorder.svg` | antes em `icones/apps/arcticons/screen-recorder.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `f4fab3043667657bb5cf7e2b8ec37c05a4ced740ed4349cbb7f850c96d7dadfa` |
| `icones/biblioteca/shield.svg` | antes em `icones/sistema/arcticons/shield.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `6c7359d1ae019003443c03c24c3376aeff9e3862a4d82a053ac9db9ec9b1bdc2` |
| `icones/biblioteca/spotify.svg` | antes em `icones/apps/arcticons/spotify.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `63d7c204c4d48192006d50c8c0c1c4fc48751849b83d1705aa7917c015215320` |
| `icones/biblioteca/steam.svg` | antes em `icones/apps/convertidos/retoques/steam.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `a8c23f272f46ddb5daaf446e4a8f790096cd55b9c83c744be24b3d13a614afba` |
| `icones/biblioteca/telegram.svg` | antes em `icones/apps/arcticons/telegram.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `6ea0b23c959e604013fe542d700ffbee60c4f374ecbc5f62fb42380d8c4a7a28` |
| `icones/biblioteca/vlc.svg` | antes em `icones/apps/arcticons/vlc.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `fb590085ea829b6e85fd8e8c1d0fec95c7fe7444d3c96fd04a34868544015f7e` |
| `icones/biblioteca/whatsapp.svg` | antes em `icones/sistema/arcticons/whatsapp.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `cf868a8b7c78a0166c1e99a662e1325f6110cf9ea33bbfeee917956be1c4bbdc` |
| `icones/biblioteca/writer.svg` | antes em `icones/apps/arcticons/writer.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `08531f8d373113f1e10f280b97d655c73336cc7c46421fc5696c82ac45c19964` |
| `icones/biblioteca/zip.svg` | antes em `icones/apps/arcticons/zip.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `003b7b15f3c39c79f3402b690c9a702d60ed7eabf121fdea40e072193b99ac39` |

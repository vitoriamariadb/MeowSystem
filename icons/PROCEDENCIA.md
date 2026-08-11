# De onde vem cada ícone deste repositório

Uso **local**, numa máquina só. O repositório não é publicado (decidido em
05/08/2026). Mesmo assim a procedência fica registrada: é o que permite saber, no
dia em que alguma coisa mudar, o que pode ser modificado e o que não pode.

| acervo | onde | licença | pode modificar? | pode redistribuir? |
|---|---|---|---|---|
| `catppuccin/vscode-icons` | `icons/catppuccin/<flavor>/` | MIT | sim | sim, com o aviso de copyright |
| `Daveedmee/catppuccin-icons` | `icons/catppuccin-apps/<flavor>/` | **não declarada** | indefinido | **não** — uso local apenas |
| Arcticons (sistema) | `icons/arcticons/` — **37** glifos | **CC BY-SA 4.0** | **sim** | sim, **com atribuição e sob a mesma licença** |
| Arcticons (aplicativo) | `icons/arcticons-apps/` — **8** glifos, **recoloridos** | **CC BY-SA 4.0** | **sim** | sim, **com atribuição e sob a mesma licença** |
| marca de fábrica | `icons/apps-hicolor.map` — **1** nome, copiado do `hicolor` do sistema | a do próprio programa | **não** — cópia literal | não |
| Papirus / Papirus-Dark | pacote `papirus-icon-theme` do sistema | GPL-3.0 | sim | sim, sob GPL |
| `catppuccin/papirus-folders` | `src/icons/upstream/papirus-folders/` | GPL-3.0 | sim | sim, sob GPL |
| desenho autoral | `src/icons/autorais/` | deste projeto | — | — |

## Dois acervos com nome parecido, e cada um veste uma coisa

Já confundiram uma análise inteira. A diferença não é de organização, é de
**forma** — e a linha do `papirus-folders` na tabela acima apontava para o
*script* (`scripts/construir_pastas.sh`) em vez de apontar para o acervo, o que
ajudava a confusão. Corrigido em 10/08/2026.

| | `icons/catppuccin/<flavor>/` | `src/icons/upstream/papirus-folders/` |
|---|---|---|
| upstream | `catppuccin/vscode-icons` | `catppuccin/papirus-folders` |
| forma | `fill="none"` + `stroke`, `viewBox="0 0 16 16"` — **traço** de árvore de arquivos do VS Code | pasta **cheia**, com dobra, sombra e símbolo interno, 22..64 px |
| quem consome | `scripts/icones_pastas.sh` (as pastas XDG, hoje **desligado**) | `scripts/construir_pastas.sh` (**todas** as pastas) |
| serve de pasta de gestor de arquivos? | **não** | é a fonte viva das pastas mauve |

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
`icons/pastas.map`.

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

| | `icons/arcticons/` | `icons/arcticons-apps/` |
|---|---|---|
| quem consome | `scripts/icones_sistema.sh` **e** `scripts/icones_bandeja.sh` | `scripts/icones_apps_arcticons.sh` |
| mapa | `icons/sistema.map` **e** `icons/bandeja.map` | `icons/apps-arcticons.map` |
| destino | `22x22/status` + `scalable/status` (sistema) · `20x20/status` (bandeja) | `48x48/apps` |
| cor | **nenhuma** — fica em `currentColor` | **atribuída**, chave da paleta |

O acervo de sistema tem **dois** consumidores porque a bandeja da barra é outro
consumidor do mesmo desenho monocromático — mas cada um é dono do seu diretório,
e nenhum escreve no do outro. Se os dois escrevessem em `scalable/status`, a
remoção de órfão de um apagaria o trabalho do outro a cada passagem: é o defeito
de "dois donos", que este projeto já pagou uma vez. Ver o cabeçalho do
`scripts/icones_bandeja.sh`, que mede por que `20x20` e não `22x22`.

A separação não é organização: é consequência do §4g do `docs/COSMIC-THEMING.md`.
Ícone `symbolic` de sistema tem a cor do arquivo **descartada** pelo toolkit, que
repinta tudo com a cor de texto do tema — pintar ali seria trabalho apagado.
Ícone de **aplicativo** não passa por esse caminho, e a cor sobrevive. Por isso o
acervo de aplicativo é recolorido e o de sistema não.

**Recolorir é o que a CC BY-SA autoriza**, e é a única modificação que fazemos:
a cor sai de `palette/catppuccin.json` (nunca um hex dentro de script) e entra no
lugar do literal `currentColor`. O desenho não é tocado.

### Um TERCEIRO diretório, que não veste ninguém: `icons/previa-arcticons/`

13 glifos baixados em 10/08/2026, pela mesma API do Iconify e sob a mesma
CC BY-SA 4.0, para a folha `scripts/folha_icones.py` mostrar como os ícones
FICARIAM se ela unificasse tudo no Arcticons. Estão **sem cor**, em
`currentColor`, e **nenhum script os instala**: não há mapa que os leia, e o
tema não os enxerga. São material de decisão, não de tema.

Se ela disser sim à unificação, cada glifo escolhido migra para
`icons/arcticons-apps/` com uma cor atribuída por ela e uma linha no
`icons/apps-arcticons.map` — que é o caminho normal. Se disser não, o diretório
inteiro sai. Manter os dois separados é o que impede uma prévia de virar tema
sem ninguém ter decidido.

O `utorrent` foi baixado e **descartado**: é a marca do µTorrent, um aplicativo
de outra empresa, e pô-la no qBittorrent mentiria sobre de quem a coisa é —
a mesma recusa que o `bandeja.map` já registrou para o `playstation-family` no
Hefesto. No lugar ficou `libretorrent`, que desenha uma rede ponto-a-ponto e não
a marca de ninguém.

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

| aplicativo | glifo Arcticons | está em `icons/arcticons-apps/`? |
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
**não foi baixado**: ele já estava versionado aqui, em `icons/arcticons/`, o
acervo de SISTEMA — mesmo pack, mesma licença, e o `icones_apps_arcticons.sh` só
lê `icons/arcticons-apps/`. Foi cópia, não download. Vale conferir o repositório
antes de sair baixando: os dois acervos vêm da mesma fonte e um `curl` por cima
faria a tabela contar o mesmo glifo duas vezes. Eles não
mudam nada na tela: quem o `scripts/icones_apps_arcticons.sh` lê é o **mapa**,
não o diretório, e nenhuma linha nova entrou em `icons/apps-arcticons.map`.
Baixar é técnica e já está feito; **a cor e o sim/não são dela**, e é uma linha
`nome:glifo:cor` quando ela decidir.

Os **oito** de baixo não têm fonte com licença que sirva. Para eles as saídas
honestas são duas, e as duas são decisão dela: ficar no Papirus, ou receber arte
escolhida à mão na página de curadoria (`scripts/importar_icones.sh` a instala e
registra em `icons/curadoria.map`). O que **não** se faz é forçar casamento de
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
`icons/apps-arcticons.map`.

## O que não se toca, por pedido expresso dela

Os jogos da Steam (`steam_icon_*`), o **Hefesto** (a logo é dela) e o
**FogStripper**. `scripts/icones_apps.sh` recusa esses nomes mesmo que entrem no
mapa — a lista está em `INTOCAVEIS` e `INTOCAVEIS_PREFIXO`.

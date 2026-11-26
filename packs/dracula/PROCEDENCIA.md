# Procedência do pack Dracula — de onde veio cada arte copiada

Este arquivo nasceu em 23/09/2026, com a P28 (*"a fonte única: um desenho no
pack, todo o resto derivado"*), e é a prosa: quem abre o pack
para saber de onde veio um desenho lê aqui o porquê. A tabela, que o
`meow pack sincronizar dracula` e o `meow pack exportar` leem linha a linha,
mora em `procedencia.tsv`, ao lado deste arquivo — ver "Para quem for
acrescentar uma linha", no fim.

**Desde 24/09/2026 (P43) o segundo leitor não abre mais nada fora do pack por
causa deste arquivo** — ver "A comparação com o Dracula_OS-Theme foi
aposentada", logo abaixo.

## Por que copiar, e por que copiar não basta

**Copiar em vez de apontar** é regra antiga desta casa, e ela está escrita desde
16/09/2026 em `assets/icones/PROCEDENCIA.md`: o `apps-dracula.map` apontava
para dentro do `Dracula_OS-Theme`, um repositório que só existe na máquina do
dono dele, e um script que o lesse funcionaria de um lado e quebraria do outro.
A P28 levou a mesma regra ao pack inteiro (a regra 5 da sprint): arte de
terceiro entra **por cópia**, com uma linha aqui dizendo de onde veio, sob que
licença e em que data.

**Mas a cópia congela.** A origem de quase tudo daqui é outro projeto, que
continua andando: em 23/09 o `Dracula-Icones` desta máquina ainda era
reconstruído do zero pelo `rebuild_dracula_theme()` do Spellbook-OS, a partir do
`Dracula_OS-Theme` (a P37 o desativou lá no mesmo dia; o Dracula passou a ser
montado deste pack). Sem caminho de volta, a cópia defasa e ninguém percebe — é
o modo de falha que a memória do `Dracula-OS-Theme` já registrava em 18/08/2026:
*"o tema copia arte em vez de referenciar, então divergência silenciosa é o modo
de falha natural"*.

**E o caminho de volta não pode ser automático** (a regra 8). Uma arte retocada
aqui depois de copiada é trabalho de alguém; um `git pull` do outro repositório
não pode apagá-la. Então o `meow pack sincronizar dracula` **só lê**: calcula o
`sha256` de cada cópia e de cada origem, compara com o que ficou registrado na
cópia, e diz qual dos lados andou. Trazer a versão da origem é um gesto de quem
decide — o comando imprime a linha do `cp` e para ali. O `meow doctor` repete o
aviso como informação, e nunca como conserto: escolher entre o retoque daqui e o
upstream de lá é decisão de autor, não de programa.

## A comparação com o Dracula_OS-Theme foi aposentada — 24/09/2026, P43

A decisão de 23/09 foi *"aposentar tudo"*. O `Dracula_OS-Theme` só existe na
máquina de quem o escreveu, e a coluna `lido de` era a última coisa do
MeowSystem que, em execução, lia um caminho da casa de alguém: 364 das 365
linhas apontavam para lá, e o `meow doctor` as relia a cada passada, por meio do
`sincronizar`. Numa máquina sem aquele repositório a leitura só dava "fora de
alcance"; nesta, ela amarrava o produto a uma pasta pessoal.

Agora a coluna `lido de` está **vazia** nessas linhas, e a origem continua
escrita como texto na coluna `de onde` — que é o que este arquivo existe para
dizer. O `sincronizar` conta a linha vazia como "só registro": confere que o
arquivo existe no pack e não abre nada fora dele. A coluna ficou, vazia, em vez
de sair: é a mesma tabela que o `meow pack exportar` lê para a licença, e sem ela
o pack não seria reempacotado. A única linha que ainda compara é a do
`guvcview.svg`, cuja origem é o próprio motor (`motor:resgatados/…`), dentro
deste repositório. [P88: os resgatados desceram para este pack, e a linha lê
`pack:dracula:apps/resgatados/…`.]

## As artes

A coluna **sha256** é a da cópia **no dia em que foi copiada** — que, para as
dezenove, era também a da origem naquele dia (medido: cada uma bateu byte a byte
com o arquivo da coluna "lido de" em 23/09/2026). É ela que permite dizer qual
lado andou depois: se a cópia mudou e a origem não, foi retoque daqui; se a
origem mudou e a cópia não, foi o upstream.

A coluna **lido de** é o arquivo que o `sincronizar` abre para comparar. `~/`
é a pasta pessoal de quem roda; `motor:` é o acervo do pack-base
(`packs/meowsystem/icones/`, P88) e `pack:<id>:` o de outro pack, os mesmos
prefixos dos mapas de ícone. Numa máquina onde a origem não
existe, a linha sai como "fora de alcance", e isso não é divergência: é só não
haver com o que comparar. **Vazia**, desde 24/09 (acima), a linha é só
registro, e nada é aberto por ela.

**A biblioteca inteira entrou em 23/09/2026 (P36), e a tabela passou de 19 para
365 linhas.** São 295 de `icones/biblioteca/` — todo o
`src/icons/new-sessao-atual/` do `Dracula_OS-Theme`, com o nome de origem — e
51 de `icones/apps/`, os desenhos de `upstream/` e de `current/` que as
ligações novas do `apps.map` vestem. As 346 linhas novas foram GERADAS por
script, não escritas à mão: cada `sha256` foi medido na cópia e conferido
contra a origem no mesmo dia. Onze desenhos da biblioteca já moravam em
`icones/apps/` com nome de aplicativo desde 16/09; eles continuam lá, e a linha
de cada um na biblioteca diz de qual é gêmeo ("mesmos bytes de"). Quando a
origem de upstream é um link simbólico, a coluna "de onde" diz para onde ele
aponta — o `sincronizar` o seguia, e era o destino que ele comparava.

Tudo aqui é GPL-3.0, pela decisão de 23/09 e pelas medições da seção
[Licença](#licença-marca-e-o-que-a-cópia-não-muda): o `LICENSE` do
`Dracula_OS-Theme` e o `README.md` dos dois ramos do `m4thewz/dracula-icons`.
As 16 ligações de `src/icons/projects/` (os projetos pessoais) NÃO entraram — um
pack é exportável, e aqueles são desta máquina. O `icones/apps/nyx.svg` era
anterior a essa decisão (16/09) e ficou onde estava até 24/09/2026, quando a P43
o tirou do pack pela mesma regra — o arquivo, a linha do `apps.map` e a linha
desta tabela.

**Três desenhos entraram em 24/09/2026 (P43)**, de `current/` do
`Dracula_OS-Theme`, para as entradas que a P36 deixou de fora e que a decisão
de 23/09 mandou vestir de Dracula: `org.gnome.gitlab.somas.Apostrophe.svg` (o
`ghostwriter.svg` de lá), `org.mozilla.Thunderbird.svg` e `guvcview-lente.svg`
(o `guvcview.svg` de lá, com outro nome porque `icones/biblioteca/guvcview.svg` é o
resgate que a Câmera veste). Os `sha256` foram medidos na cópia e conferidos
contra a origem naquele dia, e nascem com a coluna `lido de` vazia. A tabela
ficou com 367 linhas.

**O resto de `current/` e os PNG feitos à mão entraram em 09/10/2026 (P73).**
A auditoria daquele dia (`git show 1b15ccb1^:docs/pesquisas/2026-10-09-paridade-de-icones.md`,
seção 3) mediu 175 desenhos Drácula próprios — sha256 fora do upstream, do
Papirus, do pack, do motor e do tema — que só existiam em
`Dracula_OS-Theme/src/icons/current/scalable/apps/`, fora da tela desde
16/04/2026: nunca tiveram ligação no `mapping.json`, e a P36 trouxe só as
ligações. Entraram **174** em `icones/biblioteca/`; o `calcdeirao.svg` ficou
fora, porque é do projeto pessoal `Caldeirao` (a decisão 4 de
`docs/DECISOES.md`, pela regra de 23/09). Três
mudaram de nome, e a linha de cada um diz por quê: `arcade-antigo.svg` e
`box-antigo.svg` (a biblioteca já tinha um `arcade.svg` e um `box.svg`,
desenhos diferentes) e `045-computer-game.svg` (o espaço do nome de origem não
cabe numa linha de mapa). Três perderam o atributo `inkscape:export-filename`, que guardava a casa de quem os desenhou e não desenha nada (`SPEEDTEST.svg`, `chatons.svg`, `tromapps.svg`: o `validar` recusa o pack com `/home/<nome>/` escrito), e a linha guarda o sha256 da origem ao lado do da cópia. Dois são um PNG embutido num SVG
(`gnome-remote-desktop.svg` e `skype-call-recorder.svg`), e a linha diz isso.
Os **39 PNG** de `icones/feitos-a-mao/` são os desenhados à mão: os 38 únicos de
`current/` (35 em `scalable/apps`, 3 em `48x48/apps-global`) e 1 dos 30 PNG do
tema antigo congelado em 24/09 que não estava em `current/` (o `hplj1020.png`).
Os outros 13 do tema antigo têm os mesmos bytes de `src/icons/projects/` — são
os projetos pessoais, e ficaram fora pela mesma regra. Eles entram como PNG pela
decisão 2 do mesmo dia (nada some), e cada um vira vetor num lote conferido por
RMSE; até lá a ficha de ícone os mostra sem deixar escolher, porque raster não é
fonte (`meow_icones_derivados`, no `scripts/lib/icones.sh`). Cada `sha256` foi medido na
cópia e conferido contra a origem no mesmo dia, e a coluna `lido de` nasce
vazia, como desde a P43. Com o `catalog.json` da biblioteca (P73 também, para a
busca achar «alienígena»), a tabela ficou com 581 linhas.

**Em 15/10/2026 (P84) os 39 viraram vetor**: cada um
ganhou um `.svg` desenhado à mão ao lado, medido contra o PNG (RMSE de 0 a 1,
no pior de dois fundos, `#282A36` e branco) e conferido a olho numa folha de
contato; os 39 passaram, os PNG saíram, e a linha de cada um abaixo é a do
vetor, com o sha256 do PNG de que ele nasceu. O critério e a tabela inteira
estão em `docs/sprints/2026-10-15-fechamento/P84-png-para-vetor.md`, no histórico do git.

A tabela de onde veio cada arte copiada mora em `procedencia.tsv`, ao lado deste arquivo: uma linha por
arquivo, seis colunas separadas por tabulação (`arquivo`, `de onde`, `lido de`, `licença`, `copiado em`, `sha256`).
O `meow pack sincronizar dracula` e o `meow pack exportar` leem de lá; este arquivo é só a prosa.

### O que a P87 trouxe — 16/10/2026

**«Joga tudo pro pack» (15/10; decisões 13 e 16).** A varredura de 15/10
(56.998 arquivos únicos, quatro frentes) e a recuperação de apagados (432
achados) apontaram o que existia fora do pack: 163 arquivos entram agora, e a
linha de cada um está no fim da tabela acima, com a origem em texto, o sha256 e
a licença. A pasta não diz de onde veio; a linha diz.

| pasta | arquivos | classe |
|---|---|---|
| `icones/apps/` | 1 | b: o vetor de 12/09 do Citrix, que veste os 11 nomes dele |
| `icones/biblioteca/` | 5 | a: os morcegos da noite e do dia e o `aurora-iniciar`; b: o morcego; c: o Obsidian do Papirus |
| `icones/biblioteca/` | 144 (132 SVG, 12 PNG) | a: 44 rascunhos e versões de desenhos nossos; b: 100 versões editadas de desenhos do pack |
| `icones/biblioteca/` | 13 (5 SVG, 8 PNG) | d: o desenho de cada projeto dela fora da lista de exclusão |

**O nome distingue as versões.** Em `versoes/` o arquivo é
`<desenho>-<sha8>.<ext>` (`morcego-dia-b47353cb.svg`): o desenho de origem e os
oito primeiros dígitos do sha256 da origem, que nunca colidem. O que cada um é
(gravação 3 de 16/09, fragmento do disco, miniatura de 15/09) está no
`catalog.json` da pasta, que é o rótulo do seletor e o texto da busca.

**De onde vieram.** 88 da transcrição do agente (14 deles também no photorec),
37 só do photorec, 5 do histórico do git, 14 do disco, 3 do backup do tema
antigo, 3 dos mascotes do motor e 13 dos projetos dela (disco, git e backup). A
lixeira, a partição do Windows, o VS Code e o ext4magic não deram nada que
entrasse: a lixeira só tinha Ouroboros e um workspace do Grok, a partição trouxe
dois desenhos de um tema de terceiro, o VS Code voltou vazio e o ext4magic caiu
por falta de memória neste ext4.

**Limpeza (regra de pack da P78).** Todo arquivo passou por ela, e nenhum foi
recusado: nenhum SVG tinha script, `foreignObject`, `on*=` nem referência para
fora do arquivo. Onze mudaram: um SVG (o comentário de gerador do Detector de
Doppelgänger; o render ficou byte a byte o mesmo) e 10 PNG, que perderam os
trechos de texto e de data (`tEXt`, `tIME`). Os seis do COSMIC Files, achados no
photorec, levavam o caminho da casa de quem usa em `Thumb::URI`. Nesses onze o
sha256 da origem está na linha, ao lado do da cópia.

**Os desenhos de projetos dela.** A regra de 23/09 («projeto pessoal fica fora
do pack») ficou só com Beholder, Elden Ring Tracker, Nyx, Protocolo Ouroboros e
Caldeirão. O Sigilo, o PDForge, o Detector de Doppelgänger, o ArcaneTab, o Mnemo,
o Neurosonancy, a Luna, o Crononauta e o Êxtase entram em `projetos/`, um por
vez, o desenho e não a tela. **O Hefesto e o FogStripper não entram**: a decisão
16 da P82 os tirou dos packs, e o `tests/pack-dracula-completo.sh` barra qualquer
arquivo com esses nomes. Os 22 desenhos deles que a varredura achou ficam fora.

**As ligações.** O `icones/apps.map` ganhou 42 linhas: os cinco nomes sem
desenho (uad-ng, Citrix, Clapper, Edge e WhatsApp), os cinco resgatados que o
tema já vestia (Ubuntu, Thunderbird ESR, scrcpy, PhotoGIMP e Nautilus), as 33
que a P37 deixou cair (Discord, Spotify, Opera, Gradia, os 11 nomes do Citrix,
os 3 das Extensões e 13 tipos de arquivo), e duas trocas desfeitas (o
`io.elementary.appcenter` e o `org.gnome.gThumb` voltam ao que o tema antigo
vestia). A ligada é a que vence a régua do BRIEFING, o RMSE contra o PNG feito
à mão; as outras ficam em `versoes/`.

### Onde cada origem foi reencontrada — e a diferença com o `packs/meowsystem/CREDITOS.md`

Cada linha acima foi achada **pelo conteúdo**, e não pelo nome: o `sha256` de
cada arquivo do pack foi procurado entre os 31.551 SVG de `src/` do
`Dracula_OS-Theme`, e o caminho escolhido quando havia mais de um igual é o que o
`mapping.json` daquele projeto declara como `fonte`. Três tinham gêmeos
idênticos: o Obsidian (`050-circle.svg`, `obsidia3.svg`,
`new-sessao-atual/circle.svg`), o qBittorrent (`qbittorrent.svg`,
`new-sessao-atual/pirate.svg`) e o Telegram (`telegram.svg`, `029-bomb.svg`).

A contagem por origem que sai daqui é **9** de `new-sessao-atual/`, **5** de
`current/scalable/apps/`, **3** do upstream `circle`, **1** de `projects/` e
**1** do `resgatados/` — dezenove (em 23/09; o de `projects/` era o
`nyx.svg`, que saiu do pack em 24/09). O `packs/meowsystem/CREDITOS.md` diz 8 de
`new-sessao-atual/` e 2 do upstream, somando 17 para 18 desenhos; a diferença
de uma linha lá é anterior a esta sprint, e o terceiro do upstream é o
Waterfox, que entrou hoje.

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

### O desenho passa do Waterfox para o Firefox — 06/11/2026, P166

O Waterfox saiu da máquina e o Firefox do apt do Pop entrou (`Icon=firefox`). O desenho `icones/apps/firefox.svg`, copiado do upstream em
23/09/2026 e escolhido por quem usa em 23/10, não mudou (mesma origem, mesmo sha256): o `apps.map` é que passou a vesti-lo como
`firefox` e `org.mozilla.firefox`, e não mais como `net.waterfox.waterfox`. A cópia `icones/biblioteca/net.waterfox.waterfox.svg`
continua na biblioteca, com a sua linha acima, como história do desenho.

## Os temas de aplicativo — 24/09/2026, sprint P42

Os moldes moram em `temas-de-apps/<app>/` (os mesmos 11 em todo pack), declarados no bloco `apps` do
`pack.json`. **Não são cópias**, e por isso não estão na tabela de cima: cada
um é o arquivo do aplicativo com o PAPEL da cor no lugar do hex (`{{base}}`,
`{{mauve}}`), pela decisão de 23/09 de que cor de tema de aplicativo sai da
paleta do pack. Quem põe o hex é o `scripts/temas-de-apps/modelo.py`, na hora de
aplicar, no flavor da máquina — é o que faz o `alucard` sair claro nos cinco.

Um modelo nunca vai ser igual, byte a byte, ao arquivo de onde o desenho veio.
Na tabela de cima o `sincronizar` diria "a ORIGEM andou" para sempre e
ofereceria um `cp` que apagaria os papéis. E esta tabela não tem a coluna
"lido de" de propósito: nada lê a origem em execução — o
`tests/sem-dracula-os-theme.sh` cobra, e o `tests/temas-de-apps.sh` cobra que
nenhum modelo traga hex escrito.

| arquivo | desenho de | licença | copiado em | o que mudou |
|---|---|---|---|---|
| `temas-de-apps/kitty/kitty.modelo.conf` | `dracula/kitty` (github.com/dracula/kitty), pela cópia em `Dracula_OS-Theme/app-themes/kitty/current-theme.conf` | MIT | 2026-09-24 | As 36 cores viraram papel. Com o flavor `dracula`, 30 saem iguais às de lá; as 6 sem slot na paleta (verde, amarelo, magenta e ciano brilhantes, branco brilhante e branco da seleção) caem no vizinho. |
| `temas-de-apps/gnome-terminal/gnome-terminal.modelo.dconf` | desenho deste projeto, na ordem do modelo do kitty | GPL-3.0 | 2026-09-24 | Nada foi copiado. O perfil que a origem tinha (`app-themes/gnome-terminal/dracula-profile.dconf`) chama-se "Dracula" e não é: fundo rgb(42,44,57), texto verde rgb(146,181,156), e nenhuma das dezesseis cores da paleta dele é do tema. |
| `temas-de-apps/telegram/telegram.modelo.tdesktop-theme` | `dracula/telegram` v0.1.3, de Neil Smith e colaboradores (github.com/dracula/telegram), pela cópia em `Dracula_OS-Theme/app-themes/telegram/dracula.tdesktop-theme` | MIT | 2026-09-24 | Os 51 hex viraram papel; o cabeçalho de créditos ficou como veio. |
| `temas-de-apps/discord/discord.modelo.theme.css` | o tema Dracula do CtorW para Vesktop e Vencord (github.com/CtorW/Vesktop-Discord), sobre o `midnight` do refact0r, pela cópia em `Dracula_OS-Theme/app-themes/discord-betterdiscord/Dracula.theme.css` | MIT | 2026-09-24 | Os 40 hex viraram papel, e o `@name` ganhou o nome do flavor e "(MeowSystem)". O `@import` do midnight ficou: o tema é um punhado de variáveis sobre ele, e não existe sem ele. |
| `temas-de-apps/onlyoffice/onlyoffice.modelo.json` | os NOMES das 125 chaves de um tema de interface que esta máquina tinha em `uithemes/` (`dracula_only_office.json`, id `theme-dracula-dark-ajustado-2`, de 12/08/2025) | a origem não declara nenhuma — ver abaixo | 2026-09-24 | Todo valor virou papel, inclusive os que não eram Dracula (o texto normal em #00988C, as abas em #333). |
| `temas-de-apps/zapzap/zapzap.modelo.css` | os NOMES das variáveis `--WDS-*` do WhatsApp Web e o papel de cada uma, do WhatsApp Web Catppuccin (github.com/catppuccin/userstyles, `styles/whatsapp-web/catppuccin.user.less`, commit `04413649`, 16/08/2026, sha256 `6430e9db…`), conferidos com o WhatsApp Web Dracula (github.com/dracula/whatsapp-web, `whatsapp-web-dracula.user.css`, commit `5b4f4faf`, 13/08/2026, sha256 `de0345d7…`) | MIT (os dois) | 2026-10-24 | Entrou na P106 (o sexto modelo). Nenhum valor foi copiado: os dois são LESS/CSS com a cor escrita, e aqui cada variável recebe um papel (o mesmo do de lá: `mantle` no fundo, `base` na caixa de texto e no balão que chega, `crust` no papel de parede). O acento é o `green`, como no do Dracula; o balão que sai é `color-mix` de 20% do acento sobre o `base`, como no outro. Ficaram de fora as classes ofuscadas que o do Dracula usa (`.xfmqtgv`, `.x1wb366y`), que mudam a cada versão do site. |

**O que cada papel substituiu** está no próprio modelo: a linha que diz
`{{papel}}` tinha um hex na origem. Onde a origem usava um tom que a paleta não
tem, a escolha foi o vizinho, e as não óbvias foram estas: no Telegram, o
"antracito" (#212020) virou `mantle`; o preto, o branco e o transparente viraram
`crust`, `text` e `crust` com transparência zero; e, nos quatro tipos de
arquivo, o tom escuro virou a cor do tipo com `cc` de transparência (menos o
ciano, que é o `sapphire`), o de seleção, com `80`, e o de passagem, a própria
cor (no vermelho, o `maroon`).

**O OnlyOffice é o caso sem procedência, dito na cara.** O tema de antes não
tinha tema de OnlyOffice — só um README dizendo "não há automação". O arquivo
de onde as chaves vieram estava no disco desta máquina, sem repositório, autor
ou licença. O que entrou dele são os NOMES das chaves, que são o formato de
tema do próprio OnlyOffice, e a escolha de papel de cada uma; nenhum valor. Se
aparecer a origem com uma licença que não permita isto, o modelo se refaz a
partir dos temas de fábrica do app (o binário 9.4.0 traz oito).

## As pastas especiais — 25/09/2026, sprint P61

Os sete desenhos de `icones/sistema/` são **desenho próprio deste projeto** (ver
o `packs/meowsystem/CREDITOS.md`), e por isso não estão na tabela de cima: não há origem a
comparar. Eles não recolorem pelo acento (`icones.pastas.recolorir: false`, a
decisão do pack), e o corpo da pasta — as costas e a frente, a mesma silhueta
nos sete — estava em dois tons fora da paleta do Dracula. Os dois passaram ao
slot mais próximo do flavor `dracula`, pela distância no OKLab (a euclidiana, a
mesma do OKLCH com o matiz pesado pelo croma), medida contra os 26:

| arquivo | desenho de | licença | desde | o que mudou |
|---|---|---|---|---|
| `icones/sistema/*.svg` (os sete) | desenho deste projeto | GPL-3.0 | 2026-09-16 | As costas, `#433F4D` (oklch 0,377 0,024 298°), passaram ao `surface0` `#383A4C`, a 0,0257 (o segundo mais perto, o `surface1`, a 0,0287); a frente, `#534B62` (oklch 0,430 0,039 301°), ao `surface1` `#44475A`, a 0,0310 (o `surface2`, a 0,0464). No `folder-download.svg`, as quatro aberturas do castelo (três em arco e uma janela), que eram da cor da frente, `#534B62`, foram com ela para o `#44475A`; nada mais no desenho mudou. As costas contra a frente foram de 1,24:1 para 1,22:1, e os símbolos sobre a frente ganharam contraste (o mauve, de 3,41:1 para 3,79:1). |

**As três que fecham a família — 09/10/2026, sprint P74.** `folder`, `user-home`
e `user-desktop` vinham do papirus-folders mesmo com as pastas especiais
ligadas (I7 de `docs/sprints/2026-10-09-uso-real/01-regressoes.md`, no histórico do git; o pedido de
16/09 era «que os agentes gerem as demais variações de pastas»). Entraram como
desenho deste projeto, com o corpo das sete path a path (as costas no
`surface0`, a frente no `surface1`) e o símbolo na paleta do flavor `dracula`:

| arquivo | desenho de | licença | desde | o símbolo |
|---|---|---|---|---|
| `icones/sistema/folder.svg` | desenho deste projeto | GPL-3.0 | 2026-10-09 | nenhum: é a pasta comum, só o corpo |
| `icones/sistema/user-desktop.svg` | desenho deste projeto | GPL-3.0 | 2026-10-09 | o espelho gótico largo num pé, que lê como tela (P237, 17/11/2026): a moldura e o pé no `mauve` `#BD93F9`, o remate no `lavender` `#D6ACFF`, o vidro no `sky` `#8BE9FD`, o reflexo no `text` `#F8F8F2` |
| `icones/apps/discord-b.svg` | manuais-final (a arte do Dracula feita à mão, entregue em 23/10/2026); fonte: P96 |  | GPL-3.0 | 2026-10-23 | `ed90ae11fb78d1eace76f8348ace3b36b9e2b57873afc03ee52254d0d7dacdb6` |
| `icones/apps/org.gnome.Nautilus.svg` | manuais-final (a arte do Dracula feita à mão, entregue em 23/10/2026); fonte: P96 |  | GPL-3.0 | 2026-10-23 | `83d560953d1e340d9912a8fba54c20d8c5e6e746750a840608b7373cc83dc3b2` |
| `icones/sistema/user-home.svg` | desenho deste projeto | GPL-3.0 | 2026-11-17 | o castelo na colina (P237): o castelo no `mauve` `#BD93F9`, a janela acesa e a lua no `yellow` `#F1FA8C`, a colina no `mantle` `#21222C` |
| `icones/biblioteca/discord-c.svg` | rascunho de `.trabalho-icones/svg/`, escolhido por quem usa em 23/10/2026; fonte: P96 |  | GPL-3.0 | 2026-10-23 | `a95a5d3627d5a52e75df661d6bd91298028b6ef98cd316c0c8fe747fb236789e` |
| `icones/biblioteca/guvcview-2.svg` | manuais-final (a arte do Dracula feita à mão, entregue em 23/10/2026); fonte: P96 |  | GPL-3.0 | 2026-10-23 | `0837663a400537c5b16267dbcc93449ba6a0e2e1ff1921883e499e99c358fd86` |
| `icones/apps/com.beholder.app.svg` | manuais-final (a arte do Dracula feita à mão, entregue em 23/10/2026); fonte: P96 |  | GPL-3.0 | 2026-10-23 | `628f8875287e7df8738676b75f6a5a9efaecc294871745ef5b58b2a28abf29b3` |
| `icones/apps/elden-ring-tracker.svg` | manuais-final (a arte do Dracula feita à mão, entregue em 23/10/2026); fonte: P96 |  | GPL-3.0 | 2026-10-23 | `563321f7fbe82ccaa61cc189b609cd6dc7c0ccb37c4f702f0770f0da0559a7d4` |
| `icones/apps/protocolo-ouroboros.svg` | manuais-final (a arte do Dracula feita à mão, entregue em 23/10/2026); fonte: P96 |  | GPL-3.0 | 2026-10-23 | `6ea6504d3c3a23826fd38ca9f0a8f6224feecb20c35c43daad70d7aa6e3fe9e3` |
| `icones/biblioteca/md.obsidian.Obsidian.svg` | antes em `icones/apps/resgatados/md.obsidian.Obsidian.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `34c59583036f62791019fe541256187b86eca7d189be4095fe07cd489218bf8f` |
| `icones/biblioteca/mozc.svg` | antes em `icones/apps/resgatados/mozc.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `1aa34d54a761057283bf8f47d13f11df61ee883486c38d22f8484951614ba779` |
| `icones/biblioteca/org.telegram.desktop.svg` | antes em `icones/apps/resgatados/org.telegram.desktop.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `0cb159785c0a08c35992095f7a545b6ff02200bc58b4da149c0f19e25f16f9a4` |

**A borda das dez — 16/11/2026, P208.** Sobre o fundo do lançador (`#3b3552`) a aba e o corpo sumiam. As costas e a frente das dez (`folder`, os sete `folder-*`, `user-home`, `user-desktop`) ganham o mesmo traço de 1,5 em `#A267F6`, o mauve do meio entre o do `dracula` (`#BD93F9`) e o do `alucard` (`#853AF2`): 3,2:1 contra `#3b3552` e 3,19:1 contra o `base` do `alucard` (`#F0F0F6`). A borda da frente risca a aba; a silhueta e os símbolos não mudam.

**As nove ganham cena — 17/11/2026, P237.** O glifo chapado no meio de cada pasta especial vira uma cena no traço
da casa assombrada do `folder.svg`, desenho deste projeto (GPL-3.0), gerada forma a forma por script. O corpo e a
borda não mudam: as costas no `surface0`, a frente no `surface1`, o traço de 1,5 em `#A267F6`. Todo tom da cena é
slot do flavor `dracula`; nada fica fora da paleta. A colina do `folder.svg`, no `surface0`, fica atrás de cada cena
(menos no retrato, que pende na parede, e no castelo, que tem a dele). Cada pasta guarda a cor de antes, que é o que
lê em 16 px, e o objeto que diz o papel (a seta, a colcheia, a moldura, a tela) é o que sobra em 16 px:

| arquivo | a cena | as cores |
|---|---|---|
| `icones/sistema/folder-documents.svg` | grimório aberto, marcador e vela acesa | páginas no `text`, linhas e lombada no `blue`, capa no `mauve`, marcador no `red`, castiçal no `peach`, chama no `yellow` e no `peach` |
| `icones/sistema/folder-download.svg` | morcego mergulhando de cabeça: o corpo é a haste, as asas a ponta da seta, as orelhas o bico; a bandeja em U embaixo | morcego e bandeja no `green`, olhos e nervuras das asas no `base` |
| `icones/sistema/folder-music.svg` | órgão de tubos e uma colcheia dupla no ar | tubos no `mauve` e no `lavender`, console no `base`, teclado no `text`, colcheia no `pink`, nota pequena no `yellow` |
| `icones/sistema/folder-pictures.svg` | retrato com frontão, pendurado num prego, lua sobre as colinas | moldura, cordão e prego no `peach`, céu e cravos no `base`, lua no `yellow`, colinas no `blue` |
| `icones/sistema/folder-publicshare.svg` | corvo mensageiro diante da lua, carta no bico | corvo no `mantle`, lua e olho no `yellow`, carta no `text` com o lacre no `red` |
| `icones/sistema/folder-templates.svg` | castiçal aceso e, ao lado, o molde dele em tracejado | vela no `text`, castiçal no `peach`, chama no `yellow` e no `peach`, molde no `mauve` |
| `icones/sistema/folder-videos.svg` | lanterna mágica projetando um morcego | lanterna no `peach`, lente no `base` com o brilho no `yellow`, facho e projeção no `yellow`, morcego no `mantle` |
| `icones/sistema/user-home.svg` | o castelo na colina com uma janela acesa | ver a linha dele acima |
| `icones/sistema/user-desktop.svg` | espelho gótico de moldura ornada | ver a linha dele acima |

**O resgate do Nautilus foi junto — 25/09/2026, sprint P65.** A tabela acima
dizia «nada mais no desenho mudou», e as aberturas do castelo tinham mudado
com a frente; a frase agora as conta. E o mesmo desenho mora fora deste pack:
`assets/icones/resgatados/org.gnome.Nautilus.svg` é o `folder-download.svg` de
antes da P61 sem a seta — o corpo, a lua, o castelo e as aberturas, path a path,
conferido por `diff` —, e seguia com o `#433F4D` e o `#534B62`. Passou aos mesmos
dois slots, pela mesma medida: as costas no `surface0`, a frente e as aberturas
no `surface1`; o castelo e a lua ficaram. O resgate é decalque de um
PNG que ela customizou na paleta do Dracula (a autoria `terceiro` do
`assets/icones/apps-resgatados.map`), aceito com RMSE de até 0,15 contra o
original a 256 px. O PNG de origem não está mais no disco, mas a troca mede
0,027 de RMSE entre as duas versões do SVG, na mesma régua; somada ao pior
resgate medido (0,105), a distância ao original fica em no máximo 0,132 (o
RMSE é uma distância, e vale a desigualdade triangular), abaixo do teto.

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

## Os ícones de arquivo — 09/10/2026, sprint P74

`icones/sistema/mimetypes/dracula/` e `icones/sistema/mimetypes/alucard/` (656 desenhos cada)
**não foram copiados nem desenhados aqui**: são derivados, pelo `meow pack
construir dracula`, do `css-variables/` do acervo do pack Catppuccin
(`packs/catppuccin/icones/sistema/mimetypes/`, o catppuccin/vscode-icons, MIT).
Desde a P96 (23/10/2026) os dois diretórios saíram do pack: o molde mora uma vez só
em `packs/meowsystem/icones/sistema/`, e a instalação o pinta com esta paleta. Cada
`var(--vscode-ctp-<papel>)` vira o hex do papel na `packs/meowsystem/paleta.json` deste pack, no
flavor do diretório. O `LICENSE` da origem vai junto, em
`icones/sistema/mimetypes/LICENSE`. A conta foi conferida contra a origem no mesmo dia:
com a paleta do Mocha, ela dá os 656 arquivos do `mocha/` do Catppuccin byte a
byte. Por serem derivados de um acervo que já está no repositório, eles não são
linhas da tabela das artes copiadas.

## O que o pack baixa, e não copia

Desde 24/09/2026 (P41) duas artes de terceiro chegam pelo `pack.json` como
**receita**: a URL, o sha256 do pacote e a pasta de dentro dele. Quem instala
baixa, confere byte a byte e só então põe no disco — o `construir_icones.sh`
para a base, o `cursor.sh` para o ponteiro. Nenhum arquivo delas mora neste
diretório, e por isso elas **não são linhas da tabela acima**: a tabela é das
cópias, e o `sincronizar` compara cópia com origem. O que se baixa é conferido
pelo sha256 na instalação, e é o sha256 que diz qual versão foi escolhida.
[Desde a P55, 24/09/2026, são quatro: o tema do Obsidian e a extensão do VS Code
descem pelos módulos de `scripts/temas-de-apps/`, pela mesma receita — ver o fim
desta seção.]

| o quê | de onde | pino | licença | medido em |
|---|---|---|---|---|
| base de ícones (`icones.base`) | `m4thewz/dracula-icons`, ramo `circle`, commit `00a230a277d5e6ad913b90182977738335afee89` (26/05/2024, a ponta do ramo) — o pacote que o GitHub gera para o commit, pasta `dracula-icons-00a230a2…` | sha256 `563580916e426ccccb5da5b1a43f2cc0f7ab5d118c24b87776640da45b50acea`, 3.701.762 bytes | GPL-3.0, declarada no `README.md` do upstream (ver abaixo) | 2026-09-24 |
| camada de trás da base (`icones.base.por_tras`, P74) | `m4thewz/dracula-icons`, ramo `main`, commit `de2a8edd94608ba0ac4dcf5a187af0ffaa511ebc` (02/08/2025, a ponta do ramo) — o pacote que o GitHub gera para o commit, pasta `dracula-icons-de2a8edd…`; desce para `<NOME_TEMA_ICONES>-Base-2`, atrás do `circle` | sha256 `51db7832983249a6d296154fdb7afab7c51c32ac8813bc5bf73ee89a3e1ebb36`, 3.463.683 bytes, baixado duas vezes com o mesmo sha256 | GPL-3.0, a mesma do `circle` (`README.md` e `LICENSE.md` do upstream) | 2026-10-09 |
| ponteiro (`origens.cursores`) | `dracula/gtk`, release `v4.0.0` (24/02/2023), asset `Dracula-cursors.tar.xz`, pasta `Dracula-cursors` | sha256 `81780e218fdda616016aedf42e731c86ed16290b9753a21616642023821b85f5`, 178.252 bytes | GPL-3.0 — o `LICENSE` do `dracula/gtk` | 2026-09-24 |
| tema do Obsidian (`apps.obsidian`, P55) | `dracula/obsidian`, commit `ddb95ec25babe3ef21907b8b612bbdb9fc2904c9` (10/08/2026, a ponta do `main`) — o pacote que o GitHub gera para o commit, pasta `obsidian-ddb95ec2…`; o módulo usa só o `theme.css` e o `manifest.json` dela | sha256 `20fa7f83ebba437b80f09c33297441ba223e2138994c16853965a75cb3ef8462`, 389.546 bytes | MIT — o `LICENSE` do repositório | 2026-09-24 |
| extensão do VS Code (`apps.vscode`, P55) | `dracula/visual-studio-code` 2.25.1, a extensão `dracula-theme.theme-dracula`, no `.vsix` que o Open VSX guarda (`open-vsx.org/api/dracula-theme/theme-dracula/2.25.1/file/…`) | sha256 `f4d8c28fc64874b1b959cc90dbd39c84d5d35c9cf203e32b7a758dc9abf5b1cb`, 483.084 bytes — o mesmo número que o Open VSX publica ao lado do arquivo | MIT — o `LICENSE.txt` que vem no `.vsix` | 2026-09-24 |

**A base é o ramo `circle` porque era ele que esta máquina via.** O
`Dracula-Icones` que o Spellbook montava herdava `dracula-icons-circle` antes do
`main`; os dois cobrem quase os mesmos nomes (24.958 SVG contra 25.635, contados
nos pacotes dos dois commits), e a diferença cai no resto da cadeia. O pacote
foi baixado duas vezes no mesmo dia, e as duas deram o mesmo sha256. As cópias
`dracula-icons-circle` e `-main` de `~/.local/share/icons/` desta máquina
**não** são o pacote do commit: o `diff` contra ele acusa arquivos trocados por
links e desenhos a menos, retoques do `Dracula_OS-Theme`. Por isso o MeowSystem
instala a base num diretório com nome próprio (`MeowSystem-Icons-Base`) e não
encosta naquelas.

**O ponteiro é o mesmo desta máquina, conferido um a um.** Os 113 ponteiros do
`~/.local/share/icons/Dracula-Cursor/` batem com os do pacote (e com a árvore
`kde/cursors/Dracula-cursors` do `dracula/gtk`, pelo hash de blob do git, cuja
última mudança é de 21/12/2021); o `preview.png` também. Só o `index.theme`
difere, por uma quebra de linha a mais no fim do pacote. Dos 113, 66 são links
— e é por isso que ele desce, em vez de morar aqui: o `exportar` recusa link.

**A licença da base, medida e não suposta.** O `README.md` do
`m4thewz/dracula-icons` diz *"GPL-3.0 License"* e aponta para um `LICENSE.md`
que **não existe no repositório**: medido pela API do GitHub em 24/09/2026,
nenhum commit dos dois ramos tocou `LICENSE` nem `LICENSE.md`. O mesmo README
diz que os desenhos vêm do Tela-circle (aplicativos, mimetypes e dispositivos
escaláveis) e do Papirus (lugares, ações e dispositivos pequenos). O Papirus é
GPL-3.0; o repositório do Tela-circle não traz arquivo de licença nem a cita no
README, no mesmo dia. Nada disso é redistribuído por este pack — quem instala
baixa do upstream —, mas fica escrito para que ninguém conte com um arquivo de
licença que ninguém publicou.

**Os temas de aplicativo que descem — 24/09/2026, P55.** Medido naquele dia,
nesta máquina, com o Dracula no ar: o cofre do Obsidian estava com
`cssTheme: "Catppuccin"`, e os módulos do Obsidian, do VS Code e do Heroic só
conheciam o Catppuccin. Os três passaram a vestir o que este pack declara no
bloco `apps`, e dois deles descem pela rede, pinados como a base e o ponteiro:

- **O Obsidian** é o Dracula oficial, o mesmo que a loja do app instala com o
  nome `Dracula Official` (o `name` do `manifest.json`, versão 1.1.6). O
  repositório não tem tag nem release, e por isso o pino é o commit, na URL, e o
  sha256 do pacote; baixado duas vezes no mesmo dia, deu o mesmo número. O
  `Dracula` que esta máquina tinha em `.obsidian/themes/` é esse mesmo tema numa
  versão anterior (1.1.5): o `diff` contra o 1.1.6 acusa só as cores do canvas,
  que passaram a `rgb()`, o glifo de uma caixa marcada e um espaço no fim de uma
  linha. O módulo instala o 1.1.6 numa pasta com o nome do manifest, e não
  encosta naquela.
- **O VS Code** é o Dracula oficial na versão 2.25.1, a última que a Marketplace
  serve (publisher `dracula-theme`, domínio verificado, 17/07/2024). O release do
  GitHub parou na v2.24.3, e não serve: a 2.25 renomeou o tema de «Dracula» para
  «Dracula Theme», e uma 2.24.3 que o editor atualizasse sozinho mudaria o nome
  debaixo do `workbench.colorTheme`, com a tela caindo no tema de fábrica sem
  aviso. O `.vsix` da Marketplace chega comprimido pelo servidor, e os bytes do
  pacote não são garantidos; o do Open VSX é o arquivo guardado, com o sha256
  publicado ao lado. Comparados no mesmo dia, os dois `.vsix` da 2.25.1 têm a
  pasta `extension/` idêntica, arquivo por arquivo — mudam só o
  `extension.vsixmanifest` e o `[Content_Types].xml`, que são do empacotamento.
  O `theme/dracula.json` é o mesmo nos três pacotes medidos (a 2.24.3 do GitHub
  e as duas 2.25.1). O código-fonte do repositório não serve de pacote: o
  `theme/` é gerado no build, e o `.gitignore` o deixa de fora.
- **O Heroic** não desce: o Heroic já traz um tema `dracula` (a chave está no
  `defaultThemes` do `ThemeSelector` nas tags v2.15.0, v2.22.1 e v2.22.3, lidas
  no mesmo dia), e o pack declara só o nome dele.

Os três são escuros nos dois modos, e nenhum tem par para o `alucard`: com ele
no ar, o Obsidian, o VS Code e o Heroic ficam no Dracula.

## O tema do COSMIC: a Dark é foto, a Light é o Alucard — 25/09/2026, sprint P63

`temas/capturados/dracula-mauve/` não é arte de terceiro, e por isso não está
em tabela nenhuma daqui: é o `~/.config/cosmic` desta máquina com o Dracula
aplicado, fotografado pelo `scripts/capturar_tema.sh` em 11/09/2026 (a hora e a
casa estão no `captura.txt`). O que o COSMIC escreveu vai byte a byte — o
`.gitattributes` marca a pasta `byte-exact` —, e o `manifesto.sha256` dá o
sha256 de cada arquivo.

**A árvore Dark é a foto, e continua a mesma.** Os 69 arquivos de
`com.system76.CosmicTheme.Dark/`, os 38 de `Dark.Builder/` e os 2 de `Mode/`
têm no manifesto o mesmo sha256 de antes da P63.

**A árvore Light deixou de ser foto.** A foto trouxe no claro o Latte do
Catppuccin — `name: "catppuccin-latte"`, o acento #8839EF, e as dez chaves de
cor da receita iguais às do `latte-mauve` —, porque em 11/09 era o que esta
máquina tinha no modo claro. Com FLAVOR=dracula e MODO=claro o COSMIC vestia o
Latte, e o pack diz que o claro do dracula é o `alucard` (o `claros` da
`packs/meowsystem/paleta.json`, o `_nota_claro` do `pack.json`); a página e a prévia já diziam
Alucard. Desde a P63 as duas árvores Light (`Light/` e `Light.Builder/`, v1 e
v2, 80 arquivos, 57 deles mudaram) são as do `alucard-mauve`, **derivadas, não
copiadas**:

- **De onde.** Da Light do `latte-mauve` do Catppuccin (a foto de 04/08, a única
  Light ao alcance do Dracula que se reproduz com a receita que traz), trocada
  slot a slot do latte pelo alucard e refeita pelo `build()` do libcosmic que o
  `scripts/derivar_flavor.py` porta — o mesmo caminho que a P59 dá ao
  FLAVOR=alucard. A Light antiga não servia de base: o produto dela não é o que
  a receita dela dá (66 campos, a começar pelo vidro 8A com a receita em
  `VeryHigh2`).
- **O comando.** `MEOW_PACK_DIR=packs/dracula python3 scripts/derivar_flavor.py
  dracula-mauve` escreve as duas árvores, a linha `claro:` do `captura.txt` e
  refaz o manifesto pelo mesmo comando do `capturar_tema.sh`; o resto da foto
  não muda um byte. Com `--conferir` ele só diz se a foto está em dia, e o
  `tests/claro-do-pack.sh` o roda: uma Light que não seja a que a derivação dá
  hoje derruba o teste.
- **Conferido contra o oráculo** (o `build()` de verdade, do commit c003a58):
  todas as cores da `Light/v2` saem iguais. Diferem a quebra de linha final do
  `corner_radii` e do `gaps`, o alpha da Aurora no `base:` do `secondary` (FF, o
  da base) e o `frosted_maximized_apps`, que o oráculo escreve e a base não
  traz — as mesmas diferenças que a P59 anotou no cabeçalho do derivador.
- **A v1** (a árvore dos applets antigos) sai da v2 nova pela mesma função do
  `scripts/gerar_tema_v1.py`, que não precisou mudar: rodado sobre a foto, ele
  confere tudo e escreve zero arquivos.

**O que veio da base e não é cor.** O `build()` só refaz cor; a geometria e o
vidro da Light são os do `latte-mauve`. Medido na receita (`Light.Builder/v2`):

| chave | a Light antiga | a de agora | a Dark |
|---|---|---|---|
| `corner_radii` | 0, 2, 8, 8, 8, 8 | 0, 4, 8, 16, 32, 160 | 0, 2, 8, 8, 8, 8 |
| `spacing` | 4 a 160 | 0 a 128 | 0 a 128 |
| `active_hint` | 5 | 4 | 4 |
| `frosted` | `VeryHigh2` | `VeryLow2` | `VeryHigh2` |
| `alpha_map` | 0,54 a 0,24 | 0,92 a 0,62 | 0,92 a 0,62 |

O `frosted` e o `alpha_map` são dela: o `aplicar_tema.sh` só os escreve onde
faltam, e numa máquina que já tem COSMIC ficam os que o slider gravou. Os
outros três a captura impõe — no modo claro os cantos passam a ser os
arredondados de fábrica, e a Dark continua com os da foto.

**As derivadas de acento** (`dracula-pink`, `dracula-green`…) nascem na
máquina, dentro desta pasta, e não vão para o git (cada uma traz um
`.gitignore`). Desde a P63 a Light de cada uma é a do alucard no MESMO acento
— a do `dracula-pink` é a do `alucard-pink` —, pelo mesmo `derivar_flavor.py`,
e o `captura.txt` dela diz `claro: o do alucard-<acento>, derivado de
latte-mauve`. A regra vale porque o `alucard` nunca foi fotografado: no
Catppuccin, cujo claro tem foto, a derivada de acento continua levando a Light
da base. Uma derivada de antes da P63 que ainda esteja no disco se refaz na
etapa `gerar` do instalador — a do «Salvar e aplicar» — na próxima vez que o
acento dela for escolhido.

## Para quem for acrescentar uma linha

A linha vai no fim do `procedencia.tsv`: seis campos separados por tabulação, um
arquivo por linha, e o cabeçalho na primeira. O `sincronizar` lê o cabeçalho e
cada linha até o fim do arquivo; a ordem das colunas não importa, o nome delas
sim, e uma linha com número de campos diferente do cabeçalho recusa o arquivo
inteiro, dizendo a linha.

- `arquivo` — relativo a este diretório (`packs/dracula/`), e precisa cair
  dentro dele.
- `lido de` — `~/…`, `motor:…` ou caminho absoluto. É só **lido**, nunca
  escrito, e tem de ter a mesma extensão do `arquivo`: comparar um `.svg` com
  outra coisa não é sincronizar. **Vazio** é só registro, e é o certo para o
  que veio do `Dracula_OS-Theme` ou de qualquer lugar que só existe numa
  máquina (P43): a origem vai como texto em `de onde`, e nada a lê.
- `sha256` — os 64 hex da cópia no dia da cópia. Adotar um retoque, ou trazer a
  versão da origem, é trocar este número: é o registro dizendo qual versão foi
  escolhida.

O arquivo não leva crase em `arquivo`, `lido de`, `copiado em` nem `sha256`; `de onde` e `licença`
são texto livre, sem tabulação nem quebra de linha.

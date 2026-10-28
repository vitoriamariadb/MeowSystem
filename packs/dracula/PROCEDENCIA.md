# Procedência do pack Dracula — de onde veio cada arte copiada

Este arquivo nasceu em 23/09/2026, com a P28 (*"a fonte única: um desenho no
pack, todo o resto derivado"*), e ele tem **dois leitores**: quem abre o pack
para saber de onde veio um desenho, e o `meow pack sincronizar dracula`, que lê
a tabela lá embaixo linha a linha. Por isso a tabela tem forma fixa — ver
"Para quem for acrescentar uma linha", no fim.

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
fonte (`meow_icones_derivados`, no `lib/icones.sh`). Cada `sha256` foi medido na
cópia e conferido contra a origem no mesmo dia, e a coluna `lido de` nasce
vazia, como desde a P43. Com o `catalog.json` da biblioteca (P73 também, para a
busca achar «alienígena»), a tabela ficou com 581 linhas.

**Em 15/10/2026 (P84) os 39 viraram vetor**: cada um
ganhou um `.svg` desenhado à mão ao lado, medido contra o PNG (RMSE de 0 a 1,
no pior de dois fundos, `#282A36` e branco) e conferido a olho numa folha de
contato; os 39 passaram, os PNG saíram, e a linha de cada um abaixo é a do
vetor, com o sha256 do PNG de que ele nasceu. O critério e a tabela inteira
estão em `docs/sprints/2026-10-15-fechamento/P84-png-para-vetor.md`, na branch `arquivo`.

| arquivo | de onde | lido de | licença | copiado em | sha256 |
|---|---|---|---|---|---|
| `icones/apps/accessories-character-map.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/accessories-character-map.svg` |  | GPL-3.0 | 2026-09-23 | `90a48589b3abafd55e33e38dba55154e0d03a19a7d7ec15182903a62386a0bcb` |
| `icones/apps/bauh.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/bauh.svg` |  | GPL-3.0 | 2026-09-23 | `7b556ebb33f93ccf7ab6d799d3015b3325f46bcae91f5cc1881beba25b8c5d40` |
| `icones/apps/bluetooth.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/bluetooth.svg` |  | GPL-3.0 | 2026-09-23 | `c452d3abd2862b1c65a403f05c842755ee2d06a6edd481aedae431eb5239245e` |
| `icones/apps/com.github.donadigo.eddy.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/com.github.donadigo.eddy.svg` (link para `softwarecenter-debian.svg`) |  | GPL-3.0 | 2026-09-23 | `c606fbc91b4cbf432ffacf12dd1de418e6e48f3efcfb665a99f7025635b86b7e` |
| `icones/apps/com.system76.Popsicle.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/lollipop.svg` |  | GPL-3.0 | 2026-09-16 | `c2744bb1238641416f208b54b43da816320f038cc26f802ea1d1657dae0b6451` |
| `icones/apps/document-print-preview.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/document-print-preview.svg` |  | GPL-3.0 | 2026-09-23 | `a8b9188a24f962d59be51e3732edd3c4440776b45e8933bd20962e32dceb4fd3` |
| `icones/apps/drive-removable-media.svg` | `m4thewz/dracula-icons`, ramo `main` — `scalable/apps/drive-removable-media.svg` (link para `palimpsest.svg`) |  | GPL-3.0 | 2026-09-23 | `cecd86355ca3aae256609c0133438d2244a7fe7414c7ea25c5d39b3c39cd3f97` |
| `icones/apps/firmware-manager.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/firmware-manager.svg` (link para `org.gnome.Firmware.svg`) |  | GPL-3.0 | 2026-09-23 | `1f67246c02adf908e1ce0e8d1c42995d2251d84e5a741f46ee2e2458004657cb` |
| `icones/apps/foundryvtt.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/dice.svg` |  | GPL-3.0 | 2026-09-16 | `b054beb4ed504629488527eb5f3253279aa20e6dd793d20c635f042d121e09bb` |
| `icones/apps/ghostty.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/025-candle-1.svg` |  | GPL-3.0 | 2026-09-23 | `7092451deaa03df8a4f8022163ddac8644d0a1c79dc516ed14590736a09522cb` |
| `icones/apps/gnome-power-manager.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/gnome-power-manager.svg` |  | GPL-3.0 | 2026-09-23 | `5ed82c7ccd3565b386a50c21cc05020f6957daee67d35b25ff5d69af997f8b5f` |
| `icones/apps/goa-panel.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/goa-panel.svg` (link para `credentials-preferences.svg`) |  | GPL-3.0 | 2026-09-23 | `e6518416e92f92355b1130cfcfdc58bd2bb9edcd185864550e8bb5487811d674` |
| `icones/apps/google-chrome.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/google-chrome.svg` |  | GPL-3.0 | 2026-09-16 | `66310f2646b82ab59c81d66950d84f945a88656ff760bc2e6bcf49827dbc4b0c` |
| `icones/biblioteca/guvcview-lente.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/guvcview.svg` |  | GPL-3.0 | 2026-09-24 | `417188c605306400d3e068e9027bb4a6ece9f88f7f6010fe84c12c12ed07a71c` |
| `icones/biblioteca/guvcview.svg` | este repositório — `assets/icones/resgatados/guvcview.svg` | `pack:dracula:biblioteca/guvcview.svg` | a do pacote `guvcview` | 2026-09-17 | `085829f880ad8727fb077f58a84609e9e0b38dd12e323726a9ace2b84026700d` |
| `icones/apps/help-about.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/help-about.svg` |  | GPL-3.0 | 2026-09-23 | `2ad7e2535f7f917b59aa5e66ec81b46714f7feeaf805952763eebaef343bace7` |
| `icones/apps/ibus-setup-chewing.svg` | `m4thewz/dracula-icons`, ramo `main` — `scalable/apps/ibus-setup-chewing.svg` (link para `ibus.svg`) |  | GPL-3.0 | 2026-09-23 | `c1583e6145451bedf9779ebc3e9d1925f4c3ffc1f69ba285d841c09644d23a2b` |
| `icones/apps/input-keyboard.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/input-keyboard.svg` |  | GPL-3.0 | 2026-09-16 | `45865667705880f1c2867e3123215ae10acdd72c9244d50c37ab6d8805fceba8` |
| `icones/apps/input-mouse.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/input-mouse.svg` |  | GPL-3.0 | 2026-09-23 | `fe4c8af95fbcb92c507d9d51041f89f57ed8393aefe2eebc10dc5f8b942043e5` |
| `icones/apps/input-tablet.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/input-tablet.svg` |  | GPL-3.0 | 2026-09-23 | `7afa78d291fc3b6f1d266b539c8d74865f838ecfbceb26664e0f3991a116c4a3` |
| `icones/apps/io.github.dvlv.boxbuddyrs.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/chest-variant.svg` |  | GPL-3.0 | 2026-09-16 | `e5100327eab6480a79a45d03fed67fec99c74c5c061219568e37ccfd23f5cc33` |
| `icones/apps/io.github.flattool.Warehouse.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/building.svg` |  | GPL-3.0 | 2026-09-16 | `4a1b45ba5d52f2b2751d3ca66acd38d6b072eab6e9de35361fb7b77a7241df7f` |
| `icones/apps/io.gitlab.theevilskeleton.Upscaler.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/telescope.svg` |  | GPL-3.0 | 2026-09-16 | `4bfb72775f8ec20dec95283c0952ec532b3619bfe2df6d2b2534fc7de0d79139` |
| `icones/apps/mark-location-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/mark-location-symbolic.svg` (link para `system-search.svg`) |  | GPL-3.0 | 2026-09-23 | `ca97a27903bac26941f0f2941ff2e7f692baef424cc604bfb37d8d31d6ccac9a` |
| `icones/apps/md.obsidian.Obsidian.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/050-circle.svg` |  | GPL-3.0 | 2026-09-16 | `03f6930f6935331a75a3bd596a3415d5a6ae78e03ed7a1e61647017911f474db` |
| `icones/apps/media-removable.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/media-removable.svg` |  | GPL-3.0 | 2026-09-23 | `c15d1bcd5b6a0ba4dec85b9ef5af451c053022ee8acc27c01a013df7861672ea` |
| `icones/apps/menulibre.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/scroll.svg` |  | GPL-3.0 | 2026-09-16 | `292afff3113b91e08a647ee813c663908d937c7f1d4b8e9437820020d13ed860` |
| `icones/apps/multimedia-volume-control.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/multimedia-volume-control.svg` |  | GPL-3.0 | 2026-09-23 | `93b1e0e5cf0599d0d6721491d03694c9bc282d0aed07d8934f6cb2f20d3a7241` |
| `icones/biblioteca/net.waterfox.waterfox.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/firefox.svg` |  | GPL-3.0 | 2026-09-23 | `a13118bdc6224a5ed393380da1b63d808a0307c5c41c40139087e13291b47a24` |
| `icones/apps/network-cellular-signal-excellent.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/network-cellular-signal-excellent.svg` |  | GPL-3.0 | 2026-09-23 | `74819e827e285dd02d76ffb1dffa5b2673f49ca9c8aaf942f03a339c0fbe5b77` |
| `icones/apps/network-workgroup.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/network-workgroup.svg` |  | GPL-3.0 | 2026-09-23 | `8a30c3645a0a1dba26ef702ff4718689b6a04f221f4668e2e7414d4b2e1ff120` |
| `icones/apps/nm-device-wireless.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/nm-device-wireless.svg` |  | GPL-3.0 | 2026-09-23 | `087bbee6e9db3d2d95044df4055e1c1edcb71f97dd70a319248c10892202b190` |
| `icones/apps/nvidia-settings.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/nvidia.svg` |  | GPL-3.0 | 2026-09-23 | `a05c93b10a36cf5ab9f70aa7e52f809b136544072c9b7de18c4ef6a3c33f4138` |
| `icones/apps/org.gnome.ChromeGnomeShell.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/org.gnome.ChromeGnomeShell.svg` (link para `desktop-environment-gnome.svg`) |  | GPL-3.0 | 2026-09-23 | `3cacc2ed5053287f3abad2449aa2f9797c59bc1011fe38df7118ad8cf07a6ee6` |
| `icones/apps/org.gnome.Evince.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/org.gnome.Evince.svg` (link para `accessories-document-viewer.svg`) |  | GPL-3.0 | 2026-09-23 | `377e456397b133e5d9ef2d1ae7431d458cdf89a5c23767fe87f8356305f2cea2` |
| `icones/apps/org.gnome.Settings.svg` | `m4thewz/dracula-icons`, ramo `main` — `scalable/apps/org.gnome.Settings.svg` (link para `preferences-system.svg`) |  | GPL-3.0 | 2026-09-23 | `7e6ba5e6f358a865e849b108b3037e42b8d516d5979aa39347b83e136fd85c5f` |
| `icones/biblioteca/org.gnome.Shell.Extensions.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/org.gnome.Shell.Extensions.svg` (link para `extensions.svg`) |  | GPL-3.0 | 2026-09-23 | `255539e0dbf78bec37f3418b5c9f9a8302d4fdd39b1cc674172adc84ad5cef28` |
| `icones/apps/org.gnome.SimpleScan.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/org.gnome.SimpleScan.svg` |  | GPL-3.0 | 2026-09-23 | `ba01aa47449a4efeb6d9aa8eccb034f91a81f86f91737e217ed3d884b28326c7` |
| `icones/apps/org.gnome.Weather.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/org.gnome.Weather.svg` |  | GPL-3.0 | 2026-09-23 | `90db0d1c93163b7b581d475c38d89e3e791f9220b54da6b835f73a35e21064d1` |
| `icones/apps/org.gnome.Yelp.svg` | `m4thewz/dracula-icons`, ramo `main` — `scalable/apps/org.gnome.Yelp.svg` (link para `help-browser.svg`) |  | GPL-3.0 | 2026-09-23 | `5ec4ce255c0b7d1a1bf55029866e3b3a36d81ca1b0557c67b22ae60990eb8cc2` |
| `icones/apps/org.gnome.baobab.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/org.gnome.baobab.svg` (link para `baobab.svg`) |  | GPL-3.0 | 2026-09-23 | `1a20f95f6df384b20f1183e5024179ae7c5f393fc51490a9d5220164ec2ae711` |
| `icones/biblioteca/org.gnome.eog.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/org.gnome.eog.svg` (link para `eog.svg`) |  | GPL-3.0 | 2026-09-23 | `42b2c7ee350985cd5684e012873b5cdd65ad4b2ed7ebc37a44f9712755658656` |
| `icones/apps/org.gnome.gThumb.Import.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/org.gnome.gThumb.svg` (link para `gthumb.svg`) |  | GPL-3.0 | 2026-09-23 | `3a9f87ae6172538f8df627686aa3a33c82e4f919983087804fa7fed8d86d5e06` |
| `icones/apps/org.gnome.gedit.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/com.system76.CosmicEdit.svg` |  | GPL-3.0 | 2026-09-23 | `8873f152704ee8c056901a44ebe2c593ae9267612ea5be27163ed0b72499d767` |
| `icones/apps/org.gnome.gitlab.somas.Apostrophe.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/ghostwriter.svg` |  | GPL-3.0 | 2026-09-24 | `b9fba65aa23e7d0a7ba8a0ae10ea12223b447c72d561ca95624d34b2d826b6ae` |
| `icones/apps/org.kde.krita.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magic-wand-variant.svg` |  | GPL-3.0 | 2026-09-16 | `e224decf0eaa1e64fe0ae190e59750288db80571942da2615506bbcdd2b3000d` |
| `icones/apps/org.mozilla.Thunderbird.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/thunderbird.svg` |  | GPL-3.0 | 2026-09-24 | `d1e97725fc2d25b44c7342d2f16cc358b41cbbadf5986a97a4e5a6c08d250188` |
| `icones/apps/org.onlyoffice.desktopeditors.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/book.svg` |  | GPL-3.0 | 2026-09-16 | `19dbc5d86905ce3d275d9f53f5bf2dc0aa4dbfbdc2574a0f749ecbacb04eb80c` |
| `icones/apps/org.qbittorrent.qBittorrent.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/qbittorrent.svg` |  | GPL-3.0 | 2026-09-16 | `8ec4cb95cd533233513e9b0cc1a08aa60dd086fa4034a0fc165ac700f831124b` |
| `icones/apps/org.telegram.desktop.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/telegram.svg` |  | GPL-3.0 | 2026-09-16 | `d77779cd1bf430e3f81068a1de707240efafa6ea304954fdf16b89f4561cc3a5` |
| `icones/apps/pop-cosmic-workspaces.svg` | `m4thewz/dracula-icons`, ramo `main` — `scalable/apps/pop-cosmic-workspaces.svg` |  | GPL-3.0 | 2026-09-23 | `828a79ee57cf31d9a7994e2ae3acbc155dd155461600ce713f39f8f75a740ed6` |
| `icones/apps/preferences-color.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/preferences-color.svg` |  | GPL-3.0 | 2026-09-23 | `2978911811a95219242d4395be26bf8829da9ecd7a2ad949829b0c372f040475` |
| `icones/apps/preferences-desktop-accessibility.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/preferences-desktop-accessibility.svg` |  | GPL-3.0 | 2026-09-23 | `03b8c4bd49151209cd4217a8f55448ca050a449b69e630cc71dec6f18d610bd4` |
| `icones/apps/preferences-desktop-apps-symbolic.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/preferences-desktop-apps-symbolic.svg` |  | GPL-3.0 | 2026-09-23 | `048a5115a1fc52e07095815a060bd67318c20b29af3f579272850173d480cc9d` |
| `icones/apps/preferences-desktop-display.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/preferences-desktop-display.svg` |  | GPL-3.0 | 2026-09-23 | `55056c492f2d354eedac7077c7c764176be4d73de662d328927d6a1b37ab1977` |
| `icones/apps/preferences-desktop-locale.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/preferences-desktop-locale.svg` |  | GPL-3.0 | 2026-09-23 | `cb003c7bb7b2857c97dd62429a74e0793a6c4ba25e878bbcd906f6cec13cf07b` |
| `icones/apps/preferences-desktop-wallpaper.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/preferences-desktop-wallpaper.svg` (link para `desktop.svg`) |  | GPL-3.0 | 2026-09-23 | `8c30c1419a06224f777e4b67200fa49731e86af8e787f3224fb44765617f3bab` |
| `icones/apps/preferences-system-notifications.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/preferences-system-notifications.svg` (link para `preferences-desktop-notification.svg`) |  | GPL-3.0 | 2026-09-23 | `3de7c3579f253fe5aa720e448fd863d8ac7b74a5b1332377483811ffdacbff94` |
| `icones/apps/preferences-system-sharing.svg` | `m4thewz/dracula-icons`, ramo `main` — `scalable/apps/preferences-system-sharing.svg` |  | GPL-3.0 | 2026-09-23 | `ffb42815ada441e8e8213c00da56ab63781f41efd41eeb4d9530c377485014f4` |
| `icones/apps/preferences-system-time.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/preferences-system-time.svg` |  | GPL-3.0 | 2026-09-23 | `82c5a11073bc0ab136633ce42adc973735bf6bc095624f117ceef3f34e218a38` |
| `icones/apps/printer.svg` | `m4thewz/dracula-icons`, ramo `main` — `scalable/apps/printer.svg` |  | GPL-3.0 | 2026-09-23 | `4f0687faf81bf4edcd79b8f302be874a804d43bc3381c7fa852dc7b0ef311880` |
| `icones/apps/rlogo_icon.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/spell-book.svg` |  | GPL-3.0 | 2026-09-16 | `36f6898feb180c5bcd4bfafc4326d6909890d4af36cccab3a0c5d7e0f99cb977` |
| `icones/apps/security-medium.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/security-medium.svg` (link para `passwordsafe.svg`) |  | GPL-3.0 | 2026-09-23 | `5d6c5b31db1b5069a22fdb96387c516644c445d4e94c1add90e01c079ce57f2b` |
| `icones/apps/stacer.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/stacer.svg` |  | GPL-3.0 | 2026-09-23 | `b015ac68278d0508da770b1106c02a4fb1bd425b2c3de1162b3f7639beab6d05` |
| `icones/apps/starred.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/starred.svg` |  | GPL-3.0 | 2026-09-23 | `71d32307c9302e17e8a5e4c526d54b4e0b0250b464a5862f052babed058d791e` |
| `icones/apps/steam.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam.svg` |  | GPL-3.0 | 2026-09-16 | `6975830d60507bb85e35f7ee92d340a6f955786427482ae72c3450405f5635ed` |
| `icones/apps/system-file-manager.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/system-file-manager.svg` (link para `file-manager.svg`) |  | GPL-3.0 | 2026-09-23 | `6db926ed2ee0b85a497ce7961ec1517bf6f67a5fcae4cc4502aa5474141f3d9b` |
| `icones/apps/system-software-update.svg` | `m4thewz/dracula-icons`, ramo `main` — `scalable/apps/system-software-update.svg` |  | GPL-3.0 | 2026-09-23 | `b88e69bc0c486c759770b8c6e6c465b5fed7423bf6687eaf5a6e168edff5558e` |
| `icones/apps/system-users.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/system-users.svg` (link para `preferences-desktop-user.svg`) |  | GPL-3.0 | 2026-09-23 | `ec01fff1b0eae7df1f1fc2949dcf09569d65b9a6977e39dfd17e7e3ea5a89ab2` |
| `icones/apps/thunderbolt.svg` | `m4thewz/dracula-icons`, ramo `circle` — `scalable/apps/thunderbolt.svg` |  | GPL-3.0 | 2026-09-23 | `19844a92b7f5d672ed03d2d575efb861c13991ac758174d9ac8a22a42f66e442` |
| `icones/apps/video-display.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/video-display.svg` |  | GPL-3.0 | 2026-09-23 | `9389f64f0b66d04527994c7eeb9d9a8493bd1959b5325639b92f445ddfd77ba0` |
| `icones/biblioteca/com.discordapp.Discord.svg` | este repositório — `assets/icones/resgatados/discord.svg`, desenho do projeto de 15/09/2026 (commit `5aee691`), aprovado por ela em 16/09 | `pack:dracula:biblioteca/com.discordapp.Discord.svg` | GPL-3.0 | 2026-10-09 | `ce787b5b9bc8d05a802b59c1f0f689e491e15717c2f72b80b354d0b8ccd24db5` |
| `icones/apps/com.spotify.Client.svg` | este repositório — `assets/icones/resgatados/spotify.svg`, desenho do projeto de 15/09/2026 (commit `5aee691`), aprovado por ela em 16/09 | `pack:dracula:apps/com.spotify.Client.svg` | GPL-3.0 | 2026-10-09 | `78f93846b5d59bd6f75cab8817255b1d6e1f45ea2f8e29ed7ad22a9e548d3d93` |
| `icones/biblioteca/syncthing.svg` | este repositório — `assets/icones/resgatados/syncthing.svg`, desenho do projeto de 15/09/2026 (commit `5aee691`), aprovado por ela em 16/09 | `pack:dracula:biblioteca/syncthing.svg` | GPL-3.0 | 2026-10-09 | `e042a9025dc566d43f32bdbf6b03787d5ad64cd181236cb7e3ae075c3cafdc0b` |
| `icones/biblioteca/air-hockey.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/air-hockey.svg` |  | GPL-3.0 | 2026-09-23 | `e3594faf4ffd8aab3605bac5a31962c60350cb84b190fc409e3b6c57f8ae84ad` |
| `icones/biblioteca/alien-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/alien-variant.svg` |  | GPL-3.0 | 2026-09-23 | `dc2a68174c8f7466664467713c38392f3f7c381cfc5c504b5906e27ba803f615` |
| `icones/biblioteca/alien.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/alien.svg` |  | GPL-3.0 | 2026-09-23 | `b21755888a0e37cef08b491570745476e86423be3230030464da8212c04a1cd0` |
| `icones/biblioteca/amphora.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/amphora.svg` |  | GPL-3.0 | 2026-09-23 | `33d6b068f285a59cab30a1faae2a1ce6e1466ebcadc79326792abb5c0e3e2cc5` |
| `icones/biblioteca/aphrodite.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/aphrodite.svg` |  | GPL-3.0 | 2026-09-23 | `0b60444babbe5f609f9f18143e9c3be19dd5054bcddc86591619bd57f7ae69f7` |
| `icones/biblioteca/arcade.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/arcade.svg` |  | GPL-3.0 | 2026-09-23 | `15ed54e73cbb6839ec0c4204a7d611d131d94e4975843e196be3d4bedc9069fa` |
| `icones/biblioteca/asteroid.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/asteroid.svg` |  | GPL-3.0 | 2026-09-23 | `c1d90f3fe939a1c87584ac24362611b706da712967f15da5deef4cab9ceac3e2` |
| `icones/biblioteca/astronaut.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/astronaut.svg` |  | GPL-3.0 | 2026-09-23 | `04f197f89289df17a2c4fc8fd452a68b9385ac6cfde3c0fd630e8352e56bb249` |
| `icones/biblioteca/athena.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/athena.svg` |  | GPL-3.0 | 2026-09-23 | `2b2d3c00bf696678020c7a5d125789da9fee63746a3c33c2781e0954ee94f93c` |
| `icones/biblioteca/axe.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/axe.svg` |  | GPL-3.0 | 2026-09-23 | `d0630e5a9433d7500d8fb8cdaf45cc35b5ce87aea96009609a16391f991a3301` |
| `icones/apps/bag.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/bag.svg` |  | GPL-3.0 | 2026-09-23 | `207221a563ba3eb96da7dc555961cfba1f535306c8ad008e58c322e814f477df` |
| `icones/biblioteca/balloon.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/balloon.svg` |  | GPL-3.0 | 2026-09-23 | `66b3860c1067bbbc16e8e537b26500abd710b88ee663ab19094ad2072d732a0c` |
| `icones/biblioteca/balloons.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/balloons.svg` |  | GPL-3.0 | 2026-09-23 | `85bf02beebc1563359988f73dc41d023e1536dd6710d034b408c5c2c9c4ecf32` |
| `icones/biblioteca/bat.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/bat.svg` |  | GPL-3.0 | 2026-09-23 | `b0350f2df3ba0d987a46b9e659903037c0b377054901aab4507ba5fcf5341f73` |
| `icones/biblioteca/bats.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/bats.svg` |  | GPL-3.0 | 2026-09-23 | `cf5a23b0bda5411a49595b7ccae0ea9f030b354026248d4548598b65f867908b` |
| `icones/biblioteca/bible.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/bible.svg` |  | GPL-3.0 | 2026-09-23 | `b9df15c2374c43ab119ebcb20659200f54c61e0f504b9033f07b00e7397dc86d` |
| `icones/biblioteca/billiard.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/billiard.svg` |  | GPL-3.0 | 2026-09-23 | `5336eda5c8d168606ff881ee5797c7cc9dc66a37b5bdcbcf7f9b5e1e58a058b2` |
| `icones/biblioteca/black-cat.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/black-cat.svg` |  | GPL-3.0 | 2026-09-23 | `b5e370c449e330b1d55c00f3b1c497025bc64d816d39977308f5d7a27744022f` |
| `icones/biblioteca/blood-transfusion.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/blood-transfusion.svg` |  | GPL-3.0 | 2026-09-23 | `b5915e45f9a20ee5456583d96695255613eaef74a0517010397bcff5dbe01daa` |
| `icones/biblioteca/bomb.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/bomb.svg` |  | GPL-3.0 | 2026-09-23 | `c9800a66b5cd9868d4447d94764a4968365b029e04d0f0897a9f3a7f476596fe` |
| `icones/biblioteca/bones.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/bones.svg` |  | GPL-3.0 | 2026-09-23 | `c7353e6b4165220bb34492eb03c6b24c43f4af7153f41cb45d501631fd1d665c` |
| `icones/apps/org.onlyoffice.desktopeditors.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/book.svg`; mesmos bytes de `icones/apps/org.onlyoffice.desktopeditors.svg` |  | GPL-3.0 | 2026-09-23 | `19dbc5d86905ce3d275d9f53f5bf2dc0aa4dbfbdc2574a0f749ecbacb04eb80c` |
| `icones/biblioteca/books.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/books.svg` |  | GPL-3.0 | 2026-09-23 | `3c9c9e53853a6bf72182ec3c6e2b7b25497f26dcb0e5c632ef4f9c660ddadc80` |
| `icones/biblioteca/box.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/box.svg` |  | GPL-3.0 | 2026-09-23 | `207cb1c20c2270e26f59865da46db70d7b7081443998f6ecfe61b5a3c5b4bb45` |
| `icones/biblioteca/brain.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/brain.svg` |  | GPL-3.0 | 2026-09-23 | `b597998f1d7bee8821928b2f88fe84eca57fb44685a4cf4c70981b03678f8af9` |
| `icones/biblioteca/broken.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/broken.svg` |  | GPL-3.0 | 2026-09-23 | `e6c4c4915918b9092f41f3869806519237a4e225700ecd44ad2c3494227b907a` |
| `icones/apps/broom.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/broom.svg` |  | GPL-3.0 | 2026-09-23 | `7ce4f305575fa591dc78c5cb8b80e8313d8ea6f03f996ef12f1a8c88d69701a4` |
| `icones/biblioteca/broomstick.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/broomstick.svg` |  | GPL-3.0 | 2026-09-23 | `0aff6a807f834f3173a5ca5cf66cda6644fb94fc68d7a703b4373643afbdd693` |
| `icones/biblioteca/bucket.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/bucket.svg` |  | GPL-3.0 | 2026-09-23 | `487b630f46357bca5626d659d5fd4cf45da8f435ad6e68e2e635d564214cb727` |
| `icones/biblioteca/bug.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/bug.svg` |  | GPL-3.0 | 2026-09-23 | `a2c2e3108643d328aba2b146a2795884e9d95315244ef87db9f48b796dc705f2` |
| `icones/apps/io.github.flattool.Warehouse.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/building.svg`; mesmos bytes de `icones/apps/io.github.flattool.Warehouse.svg` |  | GPL-3.0 | 2026-09-23 | `4a1b45ba5d52f2b2751d3ca66acd38d6b072eab6e9de35361fb7b77a7241df7f` |
| `icones/biblioteca/candies-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/candies-variant.svg` |  | GPL-3.0 | 2026-09-23 | `68c9bdc4b69860df09fbf96e25b31f0199d3bf98cfd10eedcef67534dcafe9ea` |
| `icones/biblioteca/candies.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/candies.svg` |  | GPL-3.0 | 2026-09-23 | `d11bddd80f79387345fb2344e028b3180c9618c52e3930497f16ea35f563ca9c` |
| `icones/biblioteca/candle-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/candle-variant.svg` |  | GPL-3.0 | 2026-09-23 | `d7043d3735f21078a33a26954f136ab4c52c2cb936490df7e493b1635f6d46ba` |
| `icones/biblioteca/candle.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/candle.svg` |  | GPL-3.0 | 2026-09-23 | `db711b2eb1dae6bcac4411c3e5bc28b51ab91c6ca9f31d18e28331c3a664d0e7` |
| `icones/biblioteca/candles.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/candles.svg` |  | GPL-3.0 | 2026-09-23 | `432f451daf8418d9251c5fe1a8d1b78de919278f9e36e70f8a352fa589257794` |
| `icones/biblioteca/candlestick.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/candlestick.svg` |  | GPL-3.0 | 2026-09-23 | `522934106eb970397d64aa6bde23dac52b0c277bc648aafba203898ab56122e5` |
| `icones/biblioteca/candy-cane.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/candy-cane.svg` |  | GPL-3.0 | 2026-09-23 | `392546da17d1fc1cda5ff045ec9bfc56e199045a5fbfc3d0d8a63a9cd3aa714e` |
| `icones/biblioteca/candy-corn.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/candy-corn.svg` |  | GPL-3.0 | 2026-09-23 | `70ae851a6a60d1280cc817ce62b8fda12cedc290b74c080eecfd634aa6cde989` |
| `icones/biblioteca/capsule.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/capsule.svg` |  | GPL-3.0 | 2026-09-23 | `e7c3e0c3b517b649c9c3fa2b69609e8c722bcd759cc6bfebbb5a2ee4e349944c` |
| `icones/biblioteca/cards-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/cards-variant.svg` |  | GPL-3.0 | 2026-09-23 | `5d77e8f30c32c7f9aa4cf7424f62c07a8ef82cf8cfcf6d614ce15b5af48708ca` |
| `icones/biblioteca/cards.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/cards.svg` |  | GPL-3.0 | 2026-09-23 | `c66e170ffe770d00601ab109ddf5c6ce57aa400356e29c5e40aa9ac70d3932e8` |
| `icones/biblioteca/castle.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/castle.svg` |  | GPL-3.0 | 2026-09-23 | `b5f8f679b8d07cfb44ae9ef2bd8542df0fe1b07843f96998084ede687c0de962` |
| `icones/apps/cat.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/cat.svg` |  | GPL-3.0 | 2026-09-23 | `df43bed4896cf59339e337cd17442128de8c9d8cb47a3bb2778baff78f096a63` |
| `icones/biblioteca/cauldron.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/cauldron.svg` |  | GPL-3.0 | 2026-09-23 | `5c091abb46d2157b318b33f431bc0aa38232556243d24a4329eda898fe1b860c` |
| `icones/biblioteca/cemetery.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/cemetery.svg` |  | GPL-3.0 | 2026-09-23 | `9116b1a4e086a176b28e008069b0dc0a6c512046495b784c6e8dc47f9035df06` |
| `icones/biblioteca/centaur.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/centaur.svg` |  | GPL-3.0 | 2026-09-23 | `5bdb8b8ec88d576edea37a8fbdae0ac7dcd82a26f38d0039905daefcb9a317df` |
| `icones/biblioteca/chariot.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/chariot.svg` |  | GPL-3.0 | 2026-09-23 | `561a6194fbbf554ee046d70df919cdea1b966a53fe5e8509bf163fb6e9410aa9` |
| `icones/biblioteca/chess.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/chess.svg` |  | GPL-3.0 | 2026-09-23 | `3f817cf1fde5c8b92811af8af46c6d397a965c2d12430118ad3e19b4ca045393` |
| `icones/apps/io.github.dvlv.boxbuddyrs.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/chest-variant.svg`; mesmos bytes de `icones/apps/io.github.dvlv.boxbuddyrs.svg` |  | GPL-3.0 | 2026-09-23 | `e5100327eab6480a79a45d03fed67fec99c74c5c061219568e37ccfd23f5cc33` |
| `icones/biblioteca/chest.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/chest.svg` |  | GPL-3.0 | 2026-09-23 | `e9ae842dd440f6de01c52ee8939106a4f25778c58e64a0677f63594fd0133473` |
| `icones/biblioteca/chips.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/chips.svg` |  | GPL-3.0 | 2026-09-23 | `ea809390b6b460a635db593895fc44295b508228e0a9df8374e5c9f56cd86c32` |
| `icones/apps/md.obsidian.Obsidian.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/circle.svg`; mesmos bytes de `icones/apps/md.obsidian.Obsidian.svg` |  | GPL-3.0 | 2026-09-23 | `03f6930f6935331a75a3bd596a3415d5a6ae78e03ed7a1e61647017911f474db` |
| `icones/biblioteca/cleaver.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/cleaver.svg` |  | GPL-3.0 | 2026-09-23 | `7fb80d42f23796ceffba40619ea00793426d2dabb1f3ae12c09a4c06827b1f8c` |
| `icones/biblioteca/clown.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/clown.svg` |  | GPL-3.0 | 2026-09-23 | `0c51ae45c2ffaebfab527f6a216eeb0c912f8d45c25103c7fab86015fe75c5d5` |
| `icones/biblioteca/coffin.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/coffin.svg` |  | GPL-3.0 | 2026-09-23 | `6d649dcfca3fc2ef1596759b6afea1776857f7afc9f338199e8ccd37bafc1458` |
| `icones/biblioteca/column.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/column.svg` |  | GPL-3.0 | 2026-09-23 | `db21db3f946a44c372282259ae9a5aa8e2b9d3fc43b18741bd26fb53c2a6853a` |
| `icones/biblioteca/computer-game.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/computer-game.svg` |  | GPL-3.0 | 2026-09-23 | `60e4eb693ecf76e04a2e10c20a62671f2e6ce5dcbf2f9081a65e403f50dd537e` |
| `icones/biblioteca/computer.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/computer.svg` |  | GPL-3.0 | 2026-09-23 | `27bc6fb7a4c73c4174f3255c908e606607a598829ba930cedebf56d0a727a15e` |
| `icones/biblioteca/console.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/console.svg` |  | GPL-3.0 | 2026-09-23 | `7736b492ff1ff9aad0f76e429a0fd4fee14f8297d45adad0e07f8c05f8cd7b50` |
| `icones/biblioteca/constellation.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/constellation.svg` |  | GPL-3.0 | 2026-09-23 | `dde6d9fb8a6b72d80e0dbf1b283204938a8ee70518dd8a6d3fb93b605eb9b171` |
| `icones/biblioteca/corpse.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/corpse.svg` |  | GPL-3.0 | 2026-09-23 | `6f43a58646e6ca79a47bc9381ae722a55a18c379504a54cff919235e9a10afe1` |
| `icones/biblioteca/costume.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/costume.svg` |  | GPL-3.0 | 2026-09-23 | `4c53d3376a626762ddd28d163719bda4a783e837315cc14472362ca028990c40` |
| `icones/biblioteca/cross.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/cross.svg` |  | GPL-3.0 | 2026-09-23 | `346c80b55b835d5ff02abf2a571d370c3afa17c73eb18580ed76b37c74e50345` |
| `icones/biblioteca/crow.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/crow.svg` |  | GPL-3.0 | 2026-09-23 | `1ca3aa9e860a980e74a70bb7097b91eee95c3c9339fed2cd9c73d0e00002c27b` |
| `icones/biblioteca/crown.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/crown.svg` |  | GPL-3.0 | 2026-09-23 | `30490b71ecab38f2b225caf85eeb67f0db1e910f04e13fbbe3510e05c2e425a2` |
| `icones/biblioteca/crystal-ball.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/crystal-ball.svg` |  | GPL-3.0 | 2026-09-23 | `b65a1c0ea7aa4c195912c2907877b17633e16b5704e401a61001870845216d07` |
| `icones/biblioteca/crystal.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/crystal.svg` |  | GPL-3.0 | 2026-09-23 | `dfc16fe66e939196e88c8cd041255d31deb269c1c070d9bb25a877224fdbffd1` |
| `icones/biblioteca/cupcake.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/cupcake.svg` |  | GPL-3.0 | 2026-09-23 | `2c65b04e87e2a647982b5130e6b70434e76b34d59c194ff1d4df6a0d8af0a9db` |
| `icones/biblioteca/cyclops.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/cyclops.svg` |  | GPL-3.0 | 2026-09-23 | `3e1d4d1c47a48c7a4c8c30e2e3392bbbae44d7346eb1880e7a2452618bd21706` |
| `icones/biblioteca/dagger.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/dagger.svg` |  | GPL-3.0 | 2026-09-23 | `1fd36d67b21a4f3b5523a9e565df09d354429d5139175883b7dc6eaf67a3581d` |
| `icones/biblioteca/darts.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/darts.svg` |  | GPL-3.0 | 2026-09-23 | `b23cda3158ed8cf66a8003fec24dbc6b38f5c826bd180f564bcb7b247e9ea4e1` |
| `icones/biblioteca/dead-tree.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/dead-tree.svg` |  | GPL-3.0 | 2026-09-23 | `6dcc370e0e5675808367d079df08d09c1653134923fe649a4e6965470a263920` |
| `icones/biblioteca/dessert.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/dessert.svg` |  | GPL-3.0 | 2026-09-23 | `d4fe618663a5f43cc74956de71e7a8ac2f17c310495afb58850fda56cb84a256` |
| `icones/biblioteca/devil.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/devil.svg` |  | GPL-3.0 | 2026-09-23 | `f506256ef35ecf77b26c7d087dcb3306562c1394249c56d0a938dd70e313067e` |
| `icones/apps/foundryvtt.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/dice.svg`; mesmos bytes de `icones/apps/foundryvtt.svg` |  | GPL-3.0 | 2026-09-23 | `b054beb4ed504629488527eb5f3253279aa20e6dd793d20c635f042d121e09bb` |
| `icones/biblioteca/domino.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/domino.svg` |  | GPL-3.0 | 2026-09-23 | `f00098faa5c04716d1a2155e7d2638e1b38f1feaf514f358fd9244e56dac74a3` |
| `icones/biblioteca/dove.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/dove.svg` |  | GPL-3.0 | 2026-09-23 | `a35a77b0d0af083de7bb79b3d462e0466669372438d318c1d545b2cd08ded0d9` |
| `icones/biblioteca/dracula-hex.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/dracula-hex.svg` |  | GPL-3.0 | 2026-09-23 | `e536327d62888e73989da00e89da47fff189ca2fe5fcba1eae28f210edf218ba` |
| `icones/biblioteca/dracula.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/dracula.svg` |  | GPL-3.0 | 2026-09-23 | `6177f97ff4091d53a3a9ee3bfd294060f37ebdebde7128fd37425c33e30efea0` |
| `icones/biblioteca/dwarf.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/dwarf.svg` |  | GPL-3.0 | 2026-09-23 | `0f52c10010740e0c415d65fe5b3c65bfcc69425ace7ae0d6ca140855a802dc92` |
| `icones/biblioteca/earth.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/earth.svg` |  | GPL-3.0 | 2026-09-23 | `8f453e531ab4c549e0373dc7e0ac28d576b2cf01d5f92382ed60d692e56c0aa0` |
| `icones/biblioteca/eclipse.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/eclipse.svg` |  | GPL-3.0 | 2026-09-23 | `84a2d045a410b2b68409bbbc3f642d83c3430080ff414122ec9f7e3a236f47a6` |
| `icones/biblioteca/enchanted-mirror.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/enchanted-mirror.svg` |  | GPL-3.0 | 2026-09-23 | `f544772991cf714622bff1d3106e9b7c0463570f732bcb91b62aa303cb639826` |
| `icones/biblioteca/evil.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/evil.svg` |  | GPL-3.0 | 2026-09-23 | `ccf616ae992889d78891a9935bd8cab2b1e373bbf37feaaf2d961d8291b564d6` |
| `icones/apps/eye-ball.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/eye-ball.svg` |  | GPL-3.0 | 2026-09-23 | `53db410da9b1593da25ead71b516f7ada0fba21ce6a12604ae757106b4c758b7` |
| `icones/biblioteca/eye.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/eye.svg` |  | GPL-3.0 | 2026-09-23 | `85091d8855471a060c43c2972b6aa90cce6c1e5aa37a893c78f4238d35956174` |
| `icones/biblioteca/eyeball.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/eyeball.svg` |  | GPL-3.0 | 2026-09-23 | `a00edc7c6b8a109ef8b2ba4ec27d37d5e1569cdf9a97d46390ada0c59d53e9ba` |
| `icones/biblioteca/fairy-dust.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/fairy-dust.svg` |  | GPL-3.0 | 2026-09-23 | `12fb59a91e1f5e6357e4f9dfc5fd16317a15d61ea8a9bc83e8ddd0ae9f0b3092` |
| `icones/biblioteca/fairy.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/fairy.svg` |  | GPL-3.0 | 2026-09-23 | `cef7874e88f37821355d6d861d319a33c0d0a8bd707fe3b2a4571878dea07b83` |
| `icones/biblioteca/fangs.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/fangs.svg` |  | GPL-3.0 | 2026-09-23 | `954b06a3549bc5d07c3eca3cda7abcc86153dcdd60a47617fe0bec985bb60c35` |
| `icones/biblioteca/fear.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/fear.svg` |  | GPL-3.0 | 2026-09-23 | `91527eafc780e2aac416d6034155a1c73f621c36e5494c8afc44e190d6d9ac15` |
| `icones/biblioteca/feather.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/feather.svg` |  | GPL-3.0 | 2026-09-23 | `5627f625633bbb03977445f738b68965ca3493a08a58ecce61381c1f3cb05496` |
| `icones/biblioteca/finger.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/finger.svg` |  | GPL-3.0 | 2026-09-23 | `a87d8b3dee898dbaa9bc588b46783e644a425ec3be73f7e5fa34920d14deb6cb` |
| `icones/biblioteca/fire.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/fire.svg` |  | GPL-3.0 | 2026-09-23 | `da13dd7050063862ddff9a3f0c1f241a45bcc14c2dc8341580a407f4330a2404` |
| `icones/biblioteca/flag.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/flag.svg` |  | GPL-3.0 | 2026-09-23 | `846977f46a910cb467e74e8b28deace6893d8b9e5eb330a85081baaa8fc0d104` |
| `icones/biblioteca/flask.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/flask.svg` |  | GPL-3.0 | 2026-09-23 | `0512b8f8d68db7647826563f135a61ee9311da870f87af38ae439072954e77b6` |
| `icones/biblioteca/food.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/food.svg` |  | GPL-3.0 | 2026-09-23 | `678897a70481143ae975abbc6d9677ec0eb0ebce35efc19ab19158ea793f432c` |
| `icones/biblioteca/fortune-telling.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/fortune-telling.svg` |  | GPL-3.0 | 2026-09-23 | `02d80b19b3d25a50f6bf13d24d00ea8a2378206e825a02f29546a826914e30b5` |
| `icones/biblioteca/frankenstein.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/frankenstein.svg` |  | GPL-3.0 | 2026-09-23 | `594f4038261460970367e378f9edb99c19f6df64c9decb25123a2cc56c5c0526` |
| `icones/apps/full-moon.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/full-moon.svg` |  | GPL-3.0 | 2026-09-23 | `8d275db7e35580a47953528209cdc1c7bb8ca2ad60e9a1cdd599709a5ec70ac7` |
| `icones/biblioteca/galaxy-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/galaxy-variant.svg` |  | GPL-3.0 | 2026-09-23 | `c3ca2e019ddf5dcbc95c1a33e77704f5b4912479c0f41e980d5e6cd0d92fd3d7` |
| `icones/biblioteca/galaxy.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/galaxy.svg` |  | GPL-3.0 | 2026-09-23 | `708c8179f9b4820865340f75b1417974b05d3114231d1686f0f2f69ffe437790` |
| `icones/biblioteca/gallows.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/gallows.svg` |  | GPL-3.0 | 2026-09-23 | `c854297d6c88a5733fef1bfaa721a195f09c48252a50ee731e78ea24d9a1b96b` |
| `icones/biblioteca/game-controller-variant-five.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/game-controller-variant-five.svg` |  | GPL-3.0 | 2026-09-23 | `26141f146eb1a43d1ed1348b0ad0086d5fb54e6d455fd046d25a0fbba60759e0` |
| `icones/biblioteca/game-controller-variant-four.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/game-controller-variant-four.svg` |  | GPL-3.0 | 2026-09-23 | `13d9d65b99a435ca4aba71d1f74cc315ec487186a8b7ce0ae68e65882b31a414` |
| `icones/biblioteca/game-controller-variant-six.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/game-controller-variant-six.svg` |  | GPL-3.0 | 2026-09-23 | `52f160a93a69e419910cd09d1533dc2ca9bcbf6d58109affae17bb3b221f9cfb` |
| `icones/biblioteca/game-controller-variant-three.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/game-controller-variant-three.svg` |  | GPL-3.0 | 2026-09-23 | `e7f2073ad9b07d51aa1de6121d0cfdbb53af6b1349f733217e810bc4e06cf08e` |
| `icones/biblioteca/game-controller-variant-two.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/game-controller-variant-two.svg` |  | GPL-3.0 | 2026-09-23 | `0e9c5c823f5a51345fe85bd7983b6c4e0430b9e03d5cc29df8c5e4df84ede3a5` |
| `icones/biblioteca/game-controller-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/game-controller-variant.svg` |  | GPL-3.0 | 2026-09-23 | `76b4451836ca68eef6258f1d81192903442dd69e71097deb3f3efd18f2ebeb87` |
| `icones/biblioteca/game-controller.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/game-controller.svg` |  | GPL-3.0 | 2026-09-23 | `8122815a57787a4c9ff7eaa349c8cdc010017d4223d4be27b9ac1a91df48009a` |
| `icones/biblioteca/gameboy.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/gameboy.svg` |  | GPL-3.0 | 2026-09-23 | `bf8fe0be255c3101c96192970e1a54cc2397933b3bfe82ae45ab6cd7daf54a0a` |
| `icones/biblioteca/gaming.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/gaming.svg` |  | GPL-3.0 | 2026-09-23 | `c4edbc497fddabea568dcaf0746e680de0226fc21b84c067d142c7840e5948c9` |
| `icones/apps/gate.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/gate.svg` |  | GPL-3.0 | 2026-09-23 | `98410f67e513d4458c318ecef10fc5bc7c50e647af86a94e527fdb44d2b5f34d` |
| `icones/biblioteca/gemstone.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/gemstone.svg` |  | GPL-3.0 | 2026-09-23 | `bb77c83d99e63c250c96deb8682b6f9fc684058ebe8d4dc5857d150f4d63d3d8` |
| `icones/biblioteca/genie.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/genie.svg` |  | GPL-3.0 | 2026-09-23 | `96e3a2be33fff10ec93cde3497e43dce9053545e91a89c3f405ed9e6eb7cebaf` |
| `icones/biblioteca/ghost-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/ghost-variant.svg` |  | GPL-3.0 | 2026-09-23 | `7e07735aa39ab2063123df0457b9c84a0eb32c66878f930db5a2e32d4868ea29` |
| `icones/biblioteca/ghost.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/ghost.svg` |  | GPL-3.0 | 2026-09-23 | `156fe7ec142ff17ba7cbe0a80029e9d09b35133687b0891512901a973f56b340` |
| `icones/biblioteca/ghosts.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/ghosts.svg` |  | GPL-3.0 | 2026-09-23 | `d9f038ba85cd07d5656a60056365cbd9234dee14aa4e046beafb9f0323830c15` |
| `icones/biblioteca/gift.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/gift.svg` |  | GPL-3.0 | 2026-09-23 | `89d1e5280e0650de80487dda55194243915f24cbc5ebe5fa187097d172bcf8de` |
| `icones/biblioteca/gifts.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/gifts.svg` |  | GPL-3.0 | 2026-09-23 | `38e489adf80a5c0f0557a82a464bc7db1c68ac92094dd43a78db65b646ce99ae` |
| `icones/biblioteca/globe.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/globe.svg` |  | GPL-3.0 | 2026-09-23 | `fd9f6182b0d191ef4ff6ec086f44ccf34b7fc6c9b5e7ece945571ac3b681bf1e` |
| `icones/biblioteca/glove.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/glove.svg` |  | GPL-3.0 | 2026-09-23 | `19e2505523a53396578521f9c11335cb86d974c97b466d2c90bd046f69a89743` |
| `icones/biblioteca/grapes.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/grapes.svg` |  | GPL-3.0 | 2026-09-23 | `56b4798c3e3620a7009253c1fb46c9d75e97e28bc7f51bae9e13944253f92423` |
| `icones/biblioteca/grave-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/grave-variant.svg` |  | GPL-3.0 | 2026-09-23 | `0f945771b182afc6339a416e25ebd426740407fa8889509815103f32bc188303` |
| `icones/biblioteca/grave.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/grave.svg` |  | GPL-3.0 | 2026-09-23 | `1860074b0b32ab01cfb28a1b06c42229506e339cb17cafb5495083cb1e6be080` |
| `icones/apps/graveyard-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/graveyard-variant.svg` |  | GPL-3.0 | 2026-09-23 | `b60af65273ad9576e4a0fe07935eed731b9dc9ade30cb990f37359f35a6106ea` |
| `icones/biblioteca/graveyard.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/graveyard.svg` |  | GPL-3.0 | 2026-09-23 | `33da1aaaf25d2011bf6b384599310f6d8433a83314ab62e6a752bab5b3f717b8` |
| `icones/biblioteca/griffin.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/griffin.svg` |  | GPL-3.0 | 2026-09-23 | `0ab3921ffde280582208e10c59277e57dfb75094d77b2e4816f6e450f28a5405` |
| `icones/biblioteca/grim-reaper.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/grim-reaper.svg` |  | GPL-3.0 | 2026-09-23 | `be755d909d3c22917fe9f10310e15f3de63cda05dd161c0324c1bab8a835ec9c` |
| `icones/biblioteca/guillotine.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/guillotine.svg` |  | GPL-3.0 | 2026-09-23 | `a467089051245a3d3be484639f7938629367c494db58db6a49b758767e529fc1` |
| `icones/biblioteca/halloween-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/halloween-variant.svg` |  | GPL-3.0 | 2026-09-23 | `f7023321e11c9d87318e74142ef907167a11dec5dc4e5cab5cdd44e04f757bcb` |
| `icones/apps/halloween.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/halloween.svg` |  | GPL-3.0 | 2026-09-23 | `692c742ef4214e2ca0416f4abf01e2d30e6b201838505d94a4259335205bfca7` |
| `icones/biblioteca/hand.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/hand.svg` |  | GPL-3.0 | 2026-09-23 | `eb326c9b7d95195e7669806fa0f7cc4813764bfccdec04820744018db1e31057` |
| `icones/biblioteca/handcuff.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/handcuff.svg` |  | GPL-3.0 | 2026-09-23 | `c25ad46470e4332c98085f10cc12cca21f894902ec7c491582265bbf1c186767` |
| `icones/biblioteca/handcuffs.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/handcuffs.svg` |  | GPL-3.0 | 2026-09-23 | `9627ef411b1769910043b4bc0777d3da537e5b96e99417ee2d7337a4894d9f42` |
| `icones/biblioteca/harp.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/harp.svg` |  | GPL-3.0 | 2026-09-23 | `fefdb9cd421f5a8ab6b4525436f4df0a9ac44afdbfc45e0f6889a3f6513a1857` |
| `icones/apps/haunted-house.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/haunted-house.svg` |  | GPL-3.0 | 2026-09-23 | `60a8e6e7d92d36ff178aa9497144b74d1ca5889a7552a4400d275ba9dee1da78` |
| `icones/biblioteca/hearts.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/hearts.svg` |  | GPL-3.0 | 2026-09-23 | `7118787070eca88b0158e0c90a76c21192c169cf2840ab9c5357e4c2a49fa5b1` |
| `icones/biblioteca/hephaestus-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/hephaestus-variant.svg` |  | GPL-3.0 | 2026-09-23 | `ef7e0ccef8665e9619894495b2361233f69acaf6eaa26630ca7c02c49ab24778` |
| `icones/biblioteca/hephaestus.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/hephaestus.svg` |  | GPL-3.0 | 2026-09-23 | `591d5241f4e52a3784270a627bf271a5bac91d8ef9b51e10490c48bd2d2ce700` |
| `icones/biblioteca/hermes-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/hermes-variant.svg` |  | GPL-3.0 | 2026-09-23 | `2fd37e34ad6282d417abff53f74ef5d7fb142c29b06bcd36583530c1657ac0de` |
| `icones/biblioteca/hermes.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/hermes.svg` |  | GPL-3.0 | 2026-09-23 | `faac657f572f18518f28710b5d3690a78d27155e563d58a8d9a8fdb359fa130c` |
| `icones/biblioteca/hook.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/hook.svg` |  | GPL-3.0 | 2026-09-23 | `ae0d3a749e20fd084e64201a4a0db812e0b53290737a004991d209c21db85461` |
| `icones/apps/hourglass.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/hourglass.svg` |  | GPL-3.0 | 2026-09-23 | `68fe11907aa0964a2a6846af362f746b6b453e731935368ab077c27a5710a0cc` |
| `icones/biblioteca/hydra.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/hydra.svg` |  | GPL-3.0 | 2026-09-23 | `c1bff670521fd777d9265c4234ecd85c56db0991d407ced300e10988828a0612` |
| `icones/biblioteca/jack-o-lantern.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/jack-o-lantern.svg` |  | GPL-3.0 | 2026-09-23 | `c47c5f7d59bdbec2fa7879b04edc4027df7b60035458ea09695c2e812fe22856` |
| `icones/biblioteca/jenga.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/jenga.svg` |  | GPL-3.0 | 2026-09-23 | `c2e49f89391265513ea9dfb99204db6c943237cbd8baf6b7affafdefb49d4c0e` |
| `icones/biblioteca/kappa.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/kappa.svg` |  | GPL-3.0 | 2026-09-23 | `4f2e26706b60347c28b34636969f552138340288c99e7a57f7b7b15a627cccc5` |
| `icones/apps/key.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/key.svg` |  | GPL-3.0 | 2026-09-23 | `a40945bd4785d6139e75f814333b54dd57a510376c963926d53e943550bd225e` |
| `icones/biblioteca/knife.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/knife.svg` |  | GPL-3.0 | 2026-09-23 | `ddcd824c1528d850251e6636b1a51f1d133b3f1a738030ff6cd16b5c4b6586ae` |
| `icones/biblioteca/kraken.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/kraken.svg` |  | GPL-3.0 | 2026-09-23 | `9bdf82a941f1ea2d270643c3369c55f919bd500a6eb43e3aa356ff8f2cbe50a1` |
| `icones/biblioteca/lantern.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/lantern.svg` |  | GPL-3.0 | 2026-09-23 | `09a4ddc0ada9181dba86db918219d9807fd07b0f65cc63e6a182db569eb80878` |
| `icones/apps/laurel.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/laurel.svg` |  | GPL-3.0 | 2026-09-23 | `2776697ce62f631196ffe98cb562bdb0514ec07126a012f4148e3d01f787073f` |
| `icones/biblioteca/living-dead.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/living-dead.svg` |  | GPL-3.0 | 2026-09-23 | `26d1f52e1c76f03b4bc15a0052505234cf8f3a36d12b172151fb0c826d902d36` |
| `icones/apps/com.system76.Popsicle.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/lollipop.svg`; mesmos bytes de `icones/apps/com.system76.Popsicle.svg` |  | GPL-3.0 | 2026-09-23 | `c2744bb1238641416f208b54b43da816320f038cc26f802ea1d1657dae0b6451` |
| `icones/biblioteca/lyre.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/lyre.svg` |  | GPL-3.0 | 2026-09-23 | `472b908a61bfb38044cb17d7da213f0ae8286cc6f2718b30b0b3fac9d47f7240` |
| `icones/biblioteca/magic-assistant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magic-assistant.svg` |  | GPL-3.0 | 2026-09-23 | `77fbdcfae75b99d2ccaf4c136b509a33a04eb810f9c6de4cb6c5edfc559e04cc` |
| `icones/biblioteca/magic-ball.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magic-ball.svg` |  | GPL-3.0 | 2026-09-23 | `7ebfa78e966a742b1cb91a1912a545be9ff59ac0aac82ac37b32040c1fb248c0` |
| `icones/biblioteca/magic-broom.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magic-broom.svg` |  | GPL-3.0 | 2026-09-23 | `280819db155fe914fc18f5cb7c01732ebbe5ba9a960010c27708491bff99fa5e` |
| `icones/biblioteca/magic-cape.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magic-cape.svg` |  | GPL-3.0 | 2026-09-23 | `38c3871c1272a1ce3dc1b603eff1a617fe6f2169f20cd66df48894c52fd2f4d5` |
| `icones/biblioteca/magic-hat.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magic-hat.svg` |  | GPL-3.0 | 2026-09-23 | `f630fe9fff42c04268d90134c8be3793063027bffef34757db38afa9a3f30eb5` |
| `icones/biblioteca/magic-lamp.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magic-lamp.svg` |  | GPL-3.0 | 2026-09-23 | `e6fd1588b918de62a6db27101a7b426b8b52e768ae59fcaab50a9ef4e2b5bbd5` |
| `icones/biblioteca/magic-mirror.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magic-mirror.svg` |  | GPL-3.0 | 2026-09-23 | `7b4e832020bd3ae50ecd11e8f97c3c9bc7ab5f8f0b232ff74988040043ef4f2c` |
| `icones/biblioteca/magic-trick-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magic-trick-variant.svg` |  | GPL-3.0 | 2026-09-23 | `fd1f0070cc953f281baa85f611998e47d0d7392ef8f0063f5f65bc913a370678` |
| `icones/biblioteca/magic-trick.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magic-trick.svg` |  | GPL-3.0 | 2026-09-23 | `28ee1c92bb897994f06c2fe2419bfa1b21bcc7e31b7737604b335bbe6f55a8ef` |
| `icones/apps/org.kde.krita.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magic-wand-variant.svg`; mesmos bytes de `icones/apps/org.kde.krita.svg` |  | GPL-3.0 | 2026-09-23 | `e224decf0eaa1e64fe0ae190e59750288db80571942da2615506bbcdd2b3000d` |
| `icones/biblioteca/magic-wand.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magic-wand.svg` |  | GPL-3.0 | 2026-09-23 | `a0eeaf3f2c98e3494a0f8df138ffda137ad0fab67c67e74011a35114660e3991` |
| `icones/biblioteca/magic.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magic.svg` |  | GPL-3.0 | 2026-09-23 | `53cda5241838db58da87bf7b701b23ba7a4670f4fc19f84537173a90b552c577` |
| `icones/biblioteca/magician-hat-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magician-hat-variant.svg` |  | GPL-3.0 | 2026-09-23 | `06315a34670fa365a2b4cecd88e594a23971ef42fb59763e28eea731eac15c8e` |
| `icones/apps/magician-hat.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magician-hat.svg` |  | GPL-3.0 | 2026-09-23 | `7bbbf4753b7398c96f96228ca6c5600a4b0338935f69c18dd68520dbbbd2b9b5` |
| `icones/biblioteca/magician.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/magician.svg` |  | GPL-3.0 | 2026-09-23 | `5e686683fd36ff840666ef17af3045d652c24489007d0c36880ba9f9994d0dbd` |
| `icones/biblioteca/makeup.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/makeup.svg` |  | GPL-3.0 | 2026-09-23 | `daef8fe915c00f012d067014b8d1665fcfccc118a2488810db2e56a5e840eca1` |
| `icones/biblioteca/mandolin.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/mandolin.svg` |  | GPL-3.0 | 2026-09-23 | `fc97e63d7f5f743265fe9c35e4f6f488e579b878e6c0761dd87fdccffc3f7d31` |
| `icones/biblioteca/mask-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/mask-variant.svg` |  | GPL-3.0 | 2026-09-23 | `defc782fd1291f3144cb33fabdd70f6f1c49006210b134acd277df073eb249f4` |
| `icones/biblioteca/mask.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/mask.svg` |  | GPL-3.0 | 2026-09-23 | `5dc7889de6c374fc70740b6c639aede37ade77a927a6f515f88058d32b389fe8` |
| `icones/biblioteca/mass.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/mass.svg` |  | GPL-3.0 | 2026-09-23 | `fb38f73d3e4b8970d9336987f56468826798a49c563001b5c3c6d042c8d7ad28` |
| `icones/biblioteca/meteor.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/meteor.svg` |  | GPL-3.0 | 2026-09-23 | `75f2302692165ad27cf1af4452d7f400cb972b62053f096143968246e71a1d54` |
| `icones/biblioteca/minotaur.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/minotaur.svg` |  | GPL-3.0 | 2026-09-23 | `69050853ff3cf3af75142248678e8ad5963a8106bcce64ad81da6c45a04cc41c` |
| `icones/biblioteca/mobile-game.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/mobile-game.svg` |  | GPL-3.0 | 2026-09-23 | `825be690321a5e8d0799ad311bab33807b26b21d4f2782bb70d076a7a9f4f77b` |
| `icones/biblioteca/monkey.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/monkey.svg` |  | GPL-3.0 | 2026-09-23 | `45a2749aa755f9cfcbc4b74659137fca54505445386dde73f588702b6c133680` |
| `icones/biblioteca/monster-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/monster-variant.svg` |  | GPL-3.0 | 2026-09-23 | `0e1acad196d93053b9c1253b4387d1bb0ecb8b58938dc576bcd2d1b07da18270` |
| `icones/biblioteca/monster.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/monster.svg` |  | GPL-3.0 | 2026-09-23 | `bf4d58897354e82e8f7026d943b4ad76527f05f040c8d68b12d76b1f6e8ad9e0` |
| `icones/biblioteca/moon.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/moon.svg` |  | GPL-3.0 | 2026-09-23 | `02e6a9fe997be3567c6a549279569c741e736c1959a635785ceaded61e819d10` |
| `icones/biblioteca/mortar.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/mortar.svg` |  | GPL-3.0 | 2026-09-23 | `43a629191c66db02bf39167bafc12fe66cefeb60a3ca21b905811759f2578467` |
| `icones/biblioteca/mouse.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/mouse.svg` |  | GPL-3.0 | 2026-09-23 | `ebe7d768cd0b92931932e8fb5efc285b765fda0b2d1c39e1fe783853ea496c9e` |
| `icones/biblioteca/muffin.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/muffin.svg` |  | GPL-3.0 | 2026-09-23 | `9f1e2a3803fe249541d9785937cc22ff82a922af929209987eb8ec1f195f260b` |
| `icones/biblioteca/mummy.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/mummy.svg` |  | GPL-3.0 | 2026-09-23 | `fdb4b6d7a26759ef15ffd74147a6d11d4a4dfc821d005ac375a24144c2931fe6` |
| `icones/biblioteca/mushroom.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/mushroom.svg` |  | GPL-3.0 | 2026-09-23 | `e807cf07e88600c0aaa5d3adb552e58e33669bd24514984dbb11bfa7a698027c` |
| `icones/biblioteca/night.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/night.svg` |  | GPL-3.0 | 2026-09-23 | `919e6492a65055b9e4a0f3080af147b01a6cc703ac761008d0be873e08d55c3b` |
| `icones/biblioteca/observatory.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/observatory.svg` |  | GPL-3.0 | 2026-09-23 | `cfc68c8f0336995ec2b76492f5acf4410c4c6bcea4072f8b0c1b7a90fa1310dc` |
| `icones/biblioteca/owl.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/owl.svg` |  | GPL-3.0 | 2026-09-23 | `6745962c2e6ceb0411bcf254990d80aa84bf135634c1fbdd34d2148ca00480ac` |
| `icones/biblioteca/padlock.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/padlock.svg` |  | GPL-3.0 | 2026-09-23 | `bc2e97328501e882efd0454e5a07a8caddb921820d763d0b82195692d9b7f0d5` |
| `icones/biblioteca/paper-bag.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/paper-bag.svg` |  | GPL-3.0 | 2026-09-23 | `04886155863c4ca34c1222f05fb150111df043e1bbd80185421b85faf4c7ddb9` |
| `icones/biblioteca/parthenon.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/parthenon.svg` |  | GPL-3.0 | 2026-09-23 | `456bb514cdbca73d2d162526e6fa32134391a51677615797059952c62dbb8aa0` |
| `icones/biblioteca/party.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/party.svg` |  | GPL-3.0 | 2026-09-23 | `efbf1401df7c3a4184734a0d34758c7368a711388e64da83103a14df6070a3c3` |
| `icones/biblioteca/pendant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/pendant.svg` |  | GPL-3.0 | 2026-09-23 | `d9c95800b44c0b113ca44a080b220704475825ef08d043e2536c6c3584deb6fa` |
| `icones/biblioteca/phoenix.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/phoenix.svg` |  | GPL-3.0 | 2026-09-23 | `5d29a2756bb8fd78f7cc358eae2c21dc53f1d1507f3338d9637fc80b05c786ff` |
| `icones/apps/org.qbittorrent.qBittorrent.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/pirate.svg`; mesmos bytes de `icones/apps/org.qbittorrent.qBittorrent.svg` |  | GPL-3.0 | 2026-09-23 | `8ec4cb95cd533233513e9b0cc1a08aa60dd086fa4034a0fc165ac700f831124b` |
| `icones/biblioteca/planet-variant-two.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/planet-variant-two.svg` |  | GPL-3.0 | 2026-09-23 | `16f4d603131cc398606f0e48ed58670b1ba35759325dc9cc76fd1f2ca74ad072` |
| `icones/biblioteca/planet-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/planet-variant.svg` |  | GPL-3.0 | 2026-09-23 | `f3a4c59c3df50b624fc8d77b28348d3aa638dfdc7ee8e25466fb88a69ae05892` |
| `icones/biblioteca/planet.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/planet.svg` |  | GPL-3.0 | 2026-09-23 | `d9bc96d9d3d8635d982ae699bc185a194a65ccc3e9f67f305031e24543da9c75` |
| `icones/biblioteca/plant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/plant.svg` |  | GPL-3.0 | 2026-09-23 | `c710c33dd762c045ebcc1fc91a64e6acaa3970bf7399b5c1ba26bab0baf8d7d2` |
| `icones/biblioteca/podium.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/podium.svg` |  | GPL-3.0 | 2026-09-23 | `ed961f2d0ac1dbc49257ae93edcc52116c20f483a78e095157ac11f850b284b1` |
| `icones/biblioteca/poison.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/poison.svg` |  | GPL-3.0 | 2026-09-23 | `2db5d5efde8b16efe217d202086dd8d76b9ba1bf7b06bd1890743f9f4a30fc9b` |
| `icones/biblioteca/pot.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/pot.svg` |  | GPL-3.0 | 2026-09-23 | `826491637b0c915c56174c0a17c415b09d0e4aad514a40bc0f80b9aba9b2e976` |
| `icones/biblioteca/potion-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/potion-variant.svg` |  | GPL-3.0 | 2026-09-23 | `0b42db03296cacee6a16a466a0fd29d50ed26ad401c1dc9e21dd9053c7596bba` |
| `icones/biblioteca/potion.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/potion.svg` |  | GPL-3.0 | 2026-09-23 | `1382cdc493cefe83883a03acc437bf0c5d216e6b7e7c0dce380c40f612b9a83f` |
| `icones/biblioteca/powder.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/powder.svg` |  | GPL-3.0 | 2026-09-23 | `ff068303f5bdafb68a808554f21d4362230badb7085ad25c1ccf12d5d35c477d` |
| `icones/biblioteca/prisoner.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/prisoner.svg` |  | GPL-3.0 | 2026-09-23 | `49f14e4ca4bb6fdeb53e5c3834a319eae49ddff7435d4847272c37b9e338e1b3` |
| `icones/biblioteca/pumpkin-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/pumpkin-variant.svg` |  | GPL-3.0 | 2026-09-23 | `187254836505bef56bd1fb1b88677f6f84e7cc6d67f2def88d57e2858b4f1dc3` |
| `icones/biblioteca/pumpkin.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/pumpkin.svg` |  | GPL-3.0 | 2026-09-23 | `56c5b81c8375189b3d1f973d061d67380fe2163c99ecbdc5008821360e5f4610` |
| `icones/biblioteca/pumpkins.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/pumpkins.svg` |  | GPL-3.0 | 2026-09-23 | `4eeafa0c699a3fe89382b3fbd94befdea042903dbd5beec93a9c18784d2e40ee` |
| `icones/biblioteca/puzzle.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/puzzle.svg` |  | GPL-3.0 | 2026-09-23 | `cb9903bb04310d5c220e34080a6169a75fa7fbecd17d5d544fb4f319b6950f0d` |
| `icones/biblioteca/rabbit.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/rabbit.svg` |  | GPL-3.0 | 2026-09-23 | `8f953c07c2a367698e96c78eb6bc7f47fa5b104a9509369214f4cb25d1dd5d69` |
| `icones/biblioteca/rainbow.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/rainbow.svg` |  | GPL-3.0 | 2026-09-23 | `b164ffda3f7b68aa4a49afe895e908f4d6a69d06fec7722e3b894ea715dadc1c` |
| `icones/biblioteca/reaper.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/reaper.svg` |  | GPL-3.0 | 2026-09-23 | `e2c499c215647e713d17f1ab771c56ee24831af6c01e1d0e77dde28a99a12953` |
| `icones/biblioteca/ring.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/ring.svg` |  | GPL-3.0 | 2026-09-23 | `ee87ead0127791083c65a63257014492c9513f7a7ffc896896817293972c863c` |
| `icones/biblioteca/robot-variant-two.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/robot-variant-two.svg` |  | GPL-3.0 | 2026-09-23 | `ed2525874c091527705f7b4ccc3e992934a5b296483fbc1f1da583763baec9ab` |
| `icones/biblioteca/robot-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/robot-variant.svg` |  | GPL-3.0 | 2026-09-23 | `1467f94f9ac35bc2c1ca9c28ff68e39a6e5db79b33a5051f3a2597d0ebdcb5db` |
| `icones/biblioteca/robot.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/robot.svg` |  | GPL-3.0 | 2026-09-23 | `5c8396b4444a23e30394656ff7f52efa3cfc6a970efb3fc005b5e0658051f7e2` |
| `icones/biblioteca/rocket.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/rocket.svg` |  | GPL-3.0 | 2026-09-23 | `37aac97f626722f337c4fca61eaf41a6f97cd8c753a1f07664853e54161c661a` |
| `icones/biblioteca/roulette.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/roulette.svg` |  | GPL-3.0 | 2026-09-23 | `baa0ec4047ec422abaefdccf6fd7255eb2561fee0ab353c44f82af33f6db09af` |
| `icones/biblioteca/rum.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/rum.svg` |  | GPL-3.0 | 2026-09-23 | `6e7055fbcf57b9828fa7fae93a8f928e3993b40bdf7e366b451e96827c1852b9` |
| `icones/biblioteca/sandglass.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/sandglass.svg` |  | GPL-3.0 | 2026-09-23 | `c86da4b95f668fae28fdd9000c5153035cc80ca56e6c4834a15f17227e3133d3` |
| `icones/biblioteca/satellite-dish.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/satellite-dish.svg` |  | GPL-3.0 | 2026-09-23 | `b7c1e3a208d52afe697fc9739918e1af9db8749a81c111897590a964d19d2c54` |
| `icones/biblioteca/satellite-variant-three.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/satellite-variant-three.svg` |  | GPL-3.0 | 2026-09-23 | `52281a7b9ccbf9c759d764afef22db903536a881922ac61189354f9131d555cc` |
| `icones/biblioteca/satellite-variant-two.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/satellite-variant-two.svg` |  | GPL-3.0 | 2026-09-23 | `8a258e363944e8da80ffc7169190566c0396da4e310b4dcc14e361966a6b14d1` |
| `icones/biblioteca/satellite-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/satellite-variant.svg` |  | GPL-3.0 | 2026-09-23 | `6632ec42619cce793fb2dc805dbe73e2abf9d6be8f6d518ade7a686c5c381d54` |
| `icones/biblioteca/satellite.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/satellite.svg` |  | GPL-3.0 | 2026-09-23 | `57111a427e95770f0264e4ddd9cdad3f7387e752881d6d436bb66831c719733e` |
| `icones/apps/saw.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/saw.svg` |  | GPL-3.0 | 2026-09-23 | `e7dbf638f9b8a250b3d355f2b65eeff7ca30d1bf0d65776c47110e87d2e1d405` |
| `icones/biblioteca/scarecrow.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/scarecrow.svg` |  | GPL-3.0 | 2026-09-23 | `afb9ac9aa358f052028702fda57204a01e611799edb95da50a198601ccf1beb0` |
| `icones/biblioteca/scream.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/scream.svg` |  | GPL-3.0 | 2026-09-23 | `81ac4b908215f11843daaaa3c6ecaa7883a6abdae32b8588a09c9b9fcb1362af` |
| `icones/apps/menulibre.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/scroll.svg`; mesmos bytes de `icones/apps/menulibre.svg` |  | GPL-3.0 | 2026-09-23 | `292afff3113b91e08a647ee813c663908d937c7f1d4b8e9437820020d13ed860` |
| `icones/biblioteca/scythe.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/scythe.svg` |  | GPL-3.0 | 2026-09-23 | `da55540c568f435269ca94b5c4512cc064aaf312f49f5711a4bbc63a8e4358a3` |
| `icones/biblioteca/serial-killer.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/serial-killer.svg` |  | GPL-3.0 | 2026-09-23 | `fd26e57603393385ae09e50fb2bbbf3561b56b290c466434594eb1d836d93e7e` |
| `icones/biblioteca/shield.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/shield.svg` |  | GPL-3.0 | 2026-09-23 | `68231cf309775dd94cc3e9a060e5a0c66c8a76ae397e0e02fb011852977b6dc4` |
| `icones/biblioteca/skeleton-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/skeleton-variant.svg` |  | GPL-3.0 | 2026-09-23 | `4415919a99f4a6a382b4d7889be35be0c43d538623acf5f9a4ab589a4fb58c4f` |
| `icones/biblioteca/skeleton.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/skeleton.svg` |  | GPL-3.0 | 2026-09-23 | `61cdf8f418372326c4b098d442302b98743afee254fc32d40984997785b84e91` |
| `icones/biblioteca/skull.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/skull.svg` |  | GPL-3.0 | 2026-09-23 | `e2c2b6db24c99f15134229fdf260d203eb846ab0fee986fdbffd9be845a43a55` |
| `icones/biblioteca/slot-machine.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/slot-machine.svg` |  | GPL-3.0 | 2026-09-23 | `8c1e197a37455733b444d378ad6db5aa2ab5c2594c2d9e20f508f5bd9deebb40` |
| `icones/biblioteca/smoke.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/smoke.svg` |  | GPL-3.0 | 2026-09-23 | `357f36e4753bad7d91802ba8516ffe4de92b231f9e2d9f1a50b37a32bb5e11a5` |
| `icones/biblioteca/snake.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/snake.svg` |  | GPL-3.0 | 2026-09-23 | `548f3d8ee4ce36759f121bad4e4ad81cc8ca02ac293699fa11de244dbb52fe4a` |
| `icones/biblioteca/space-capsule.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/space-capsule.svg` |  | GPL-3.0 | 2026-09-23 | `9e7f2d46345d8f4781eb6fc35be00c75d2e54bb493ef0c39b31e3ae16678cbd3` |
| `icones/biblioteca/space.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/space.svg` |  | GPL-3.0 | 2026-09-23 | `06ceb669b4e0d4e03d4329fac1d1450981d77925b96a8909535c30d4209bc998` |
| `icones/biblioteca/spaceship.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/spaceship.svg` |  | GPL-3.0 | 2026-09-23 | `f2740027d14fe7e28dff207eda1f28b5312c2ae166ec606fd9cc121a5a6f733e` |
| `icones/apps/rlogo_icon.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/spell-book.svg`; mesmos bytes de `icones/apps/rlogo_icon.svg` |  | GPL-3.0 | 2026-09-23 | `36f6898feb180c5bcd4bfafc4326d6909890d4af36cccab3a0c5d7e0f99cb977` |
| `icones/biblioteca/spell-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/spell-variant.svg` |  | GPL-3.0 | 2026-09-23 | `623d5c2b5acedaad519920bbca70f7df959102d5b9e90cfd226df86ba286087b` |
| `icones/apps/spell.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/spell.svg` |  | GPL-3.0 | 2026-09-23 | `605e2974af57a1e3460f678cae3fb02650a97fa19aa19a71f9033f1e30c8f958` |
| `icones/apps/spellbook.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/spellbook.svg` |  | GPL-3.0 | 2026-09-23 | `79eafd15f60e1c96de99744990370f6fce00f26bb999cd956027380152c61e92` |
| `icones/apps/spider-web.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/spider-web.svg` |  | GPL-3.0 | 2026-09-23 | `ad68ffc168403599a349710368b163ed96116622a1f08e9a89c86a1e5e8e748b` |
| `icones/biblioteca/spider.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/spider.svg` |  | GPL-3.0 | 2026-09-23 | `f4d13a3426821ac71c66f8425daa2b0141751d2be90a05feb8116de2fce694cd` |
| `icones/biblioteca/stage.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/stage.svg` |  | GPL-3.0 | 2026-09-23 | `94e6bfd660b4e037566fea1b4937aaa9b704fdf9c2ffab077d46b3178852ab50` |
| `icones/apps/sun.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/sun.svg` |  | GPL-3.0 | 2026-09-23 | `faca6b61292b19b1b96f66189662ad3d10e0dece502018513742ad65eb1d76b5` |
| `icones/biblioteca/sweets.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/sweets.svg` |  | GPL-3.0 | 2026-09-23 | `24b73508ec71bfd1f514a2e565f3b28fd5aacee059637d57047bee7dbe72b014` |
| `icones/biblioteca/sword.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/sword.svg` |  | GPL-3.0 | 2026-09-23 | `a6145cf04ee2d1c3df622920cfdcf0fe835d8032140e2a30ce4467a60b22818c` |
| `icones/biblioteca/target.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/target.svg` |  | GPL-3.0 | 2026-09-23 | `bb4d8120e59df968e7e7d6949e90d7bfd6262e910a2620cdbc469f4a18414b64` |
| `icones/apps/setup-mozc.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/tarot.svg` |  | GPL-3.0 | 2026-09-23 | `539a932536ef38c8834cf58d570f9e71b2115a464199559ad098dbe279a09e8a` |
| `icones/apps/io.gitlab.theevilskeleton.Upscaler.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/telescope.svg`; mesmos bytes de `icones/apps/io.gitlab.theevilskeleton.Upscaler.svg` |  | GPL-3.0 | 2026-09-23 | `4bfb72775f8ec20dec95283c0952ec532b3619bfe2df6d2b2534fc7de0d79139` |
| `icones/biblioteca/tent.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/tent.svg` |  | GPL-3.0 | 2026-09-23 | `82b697bfb5e2194e5939bc634a6f56420781d15e9d0d36a80176de63b95aa82d` |
| `icones/biblioteca/tetris-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/tetris-variant.svg` |  | GPL-3.0 | 2026-09-23 | `9cc8d3663dbebf41d0d61c9e14660b627b9d15df63fe651928c027f2cec03eeb` |
| `icones/biblioteca/tetris.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/tetris.svg` |  | GPL-3.0 | 2026-09-23 | `e4334570098703e0a89540fad8151b50738bec03767dfe36274e749ca3e71ea2` |
| `icones/biblioteca/three-dimensional-glasses.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/three-dimensional-glasses.svg` |  | GPL-3.0 | 2026-09-23 | `7d40a403d102194df0ecfd872a1aa6ba5ee16dba9d42be51f37021a6a5956d53` |
| `icones/biblioteca/tic-tac-toe.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/tic-tac-toe.svg` |  | GPL-3.0 | 2026-09-23 | `4353e50d5af27e19f8b387be4967e5691b58965e6168877370bab76c28874fa9` |
| `icones/biblioteca/ticket.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/ticket.svg` |  | GPL-3.0 | 2026-09-23 | `c85ef21938c108d6199bdaf446407eb316ba2bd1ab34d77df7f8ddaa29dae25f` |
| `icones/biblioteca/tombstone-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/tombstone-variant.svg` |  | GPL-3.0 | 2026-09-23 | `3a1fb651169e202aec5e19230c4213313a59b27a843547e2db647a3a19e34e6d` |
| `icones/biblioteca/tombstone.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/tombstone.svg` |  | GPL-3.0 | 2026-09-23 | `09a52f198af124e5cf59268bd01754d11e23c4943816736ac5147ed616f85f43` |
| `icones/apps/toolbox.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/toolbox.svg` |  | GPL-3.0 | 2026-09-23 | `1357efff6982eb469d51474d57b4496f82d77591926a83116d3d0e6d3a17589b` |
| `icones/biblioteca/torch.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/torch.svg` |  | GPL-3.0 | 2026-09-23 | `492e2c7f2b6b9786ee3ebc26c184ec00bf05664b92f0ec9b201330c25b411bc9` |
| `icones/apps/treasure-chest.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/treasure-chest.svg` |  | GPL-3.0 | 2026-09-23 | `2a900b6a790de13a43d665eb5d7252cf75c39d9a9ce57479d375e96b509d59c7` |
| `icones/biblioteca/tree.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/tree.svg` |  | GPL-3.0 | 2026-09-23 | `986585092e0542ea1f0ddcd66801eac40dd3ef4559a871f2bc0bb2833bae961a` |
| `icones/biblioteca/trick.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/trick.svg` |  | GPL-3.0 | 2026-09-23 | `43299e19ea106c12afda0644e01cc99f8a29c58953f9b1dce263ae534edf426f` |
| `icones/biblioteca/trident.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/trident.svg` |  | GPL-3.0 | 2026-09-23 | `fa6a6638979ec20514d54368696c643a771f45be5364470aadd304f6d5e318d2` |
| `icones/biblioteca/trireme.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/trireme.svg` |  | GPL-3.0 | 2026-09-23 | `d22dc129e0e49677891ae49d72b115dec039675dd0e7b0251e475d6f642c26fe` |
| `icones/biblioteca/tube.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/tube.svg` |  | GPL-3.0 | 2026-09-23 | `8077c8047f8dbb98a09af69af80cbb09be891fd7b5325917591f52e702549241` |
| `icones/biblioteca/unicorn.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/unicorn.svg` |  | GPL-3.0 | 2026-09-23 | `d8265607351a09eb60b076bfa0e8a14969f20edfcf4b5a857d91eb4954c8c150` |
| `icones/biblioteca/vampire.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/vampire.svg` |  | GPL-3.0 | 2026-09-23 | `1cbf2b232538644fad8003d38e7f38fbdf716db52396c9215ec46b32e3f20b54` |
| `icones/biblioteca/vial.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/vial.svg` |  | GPL-3.0 | 2026-09-23 | `f74a20b5367858be7bcfef99dd05a07a2a521701722e8b249681a49e7b1b7ae6` |
| `icones/biblioteca/video-card.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/video-card.svg` |  | GPL-3.0 | 2026-09-23 | `b3f0bb90eb3500e62074e20e9e85fa1f5d5ab6952aeceda9c7370b3ad87dc564` |
| `icones/biblioteca/violin.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/violin.svg` |  | GPL-3.0 | 2026-09-23 | `e77f236e111c4280c89aad2fefbaedf7ede40e0c8c5ffcb9ddd563908f77f9f1` |
| `icones/biblioteca/virtual-reality.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/virtual-reality.svg` |  | GPL-3.0 | 2026-09-23 | `2260caf1030305ec81c0f2bba609883634c9bbdd77c3238f0652df27bd6c651f` |
| `icones/biblioteca/voodoo-doll.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/voodoo-doll.svg` |  | GPL-3.0 | 2026-09-23 | `b857b1f9655a73ab0e28cfa33f63af17f7b3cf75ca1d0605941e73908dc86338` |
| `icones/biblioteca/voodoo.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/voodoo.svg` |  | GPL-3.0 | 2026-09-23 | `73400dfeb47fb6d66f5344bdad0e02eb5e59c736c0b242137a9597ca7f493de3` |
| `icones/biblioteca/wand.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/wand.svg` |  | GPL-3.0 | 2026-09-23 | `3a772bc34acfc97024e3e9c8b3b13f4dbfbe24ded69c8510a2b4785c31987b4a` |
| `icones/biblioteca/werewolf.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/werewolf.svg` |  | GPL-3.0 | 2026-09-23 | `18929ca3f3b4f5c395a55cb21833b8bce4230bcd2d3f04fef598bcbfe065419e` |
| `icones/biblioteca/winner.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/winner.svg` |  | GPL-3.0 | 2026-09-23 | `27e54303fed431de160d40577a6b4699da7db475e1300f4ab21193fe3f0bbdd3` |
| `icones/biblioteca/witch-hat.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/witch-hat.svg` |  | GPL-3.0 | 2026-09-23 | `56d9d6580e7fd501921b4c7bd6f971e57ddbae0178624e7e32b520d036e819bb` |
| `icones/biblioteca/witch-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/witch-variant.svg` |  | GPL-3.0 | 2026-09-23 | `28983387af0f56a4157a5ab03800a95af1fb611f5b4ab7b4173b164e813b1927` |
| `icones/biblioteca/witch.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/witch.svg` |  | GPL-3.0 | 2026-09-23 | `e338984a1cef4c27eacc3883af4e8f423cf2edb55f9abe1ec054d2bfeb35b89a` |
| `icones/biblioteca/wizard-hat.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/wizard-hat.svg` |  | GPL-3.0 | 2026-09-23 | `4c63c0fd2aa3f6aee730c768f09c6ede90517b5c838172561c05acc685bc216b` |
| `icones/biblioteca/wizard-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/wizard-variant.svg` |  | GPL-3.0 | 2026-09-23 | `cfdb0ca36a95917991e1ac6b81630f72459cef25cfbfe1bb0614c206bd3e7fe5` |
| `icones/biblioteca/wizard.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/wizard.svg` |  | GPL-3.0 | 2026-09-23 | `6a3a8264986d602526bfe9f95442f777da9f6842cc5d026ba40251b4adf2ca4a` |
| `icones/biblioteca/zeus.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/zeus.svg` |  | GPL-3.0 | 2026-09-23 | `34d021605abeee091c33cd292d65221838f7e05249ccf39a05b566060f5371c0` |
| `icones/biblioteca/zombie-variant.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/zombie-variant.svg` |  | GPL-3.0 | 2026-09-23 | `b2f1c89ba3151eebf8667c0e7fe95dcd4385ba5c92d4067b59772d35a0ce24ce` |
| `icones/biblioteca/zombie.svg` | `Dracula_OS-Theme` — `src/icons/new-sessao-atual/zombie.svg` |  | GPL-3.0 | 2026-09-23 | `647264ce053bf02633e68856f2fb15520a919f378e037416bb47d1482924dc44` |
| `temas-de-apps/qbittorrent/dracula.qbtheme` | `dracula/qbittorrent` (github.com/dracula/qbittorrent), commit `9020f6eb457087270179beb86d45914d434adb6b` (09/07/2026, «sync from v0.6.6») — `dracula.qbtheme`, binário Qt (`qres`), 5.055 bytes, copiado sem mudança (P74, 09/10/2026) |  | MIT | 2026-10-09 | `b4485f9f4ee6139b7c77bbfb72206b608bcfa748f34d49205c4c4b65e7976d37` |
| `temas-de-apps/spotify/Sleek/LICENSE` | `spicetify/spicetify-themes` (github.com/spicetify/spicetify-themes), commit `c432012478e1f2e2ffccca8e943e188af40d6190` (05/10/2026, a ponta do `master`) — `LICENSE` da raiz, copiado sem mudança (P107). A seção `[Dracula]` do color.ini credita draculatheme.com; o `LICENSE` é o da raiz do repositório |  | MIT | 2026-10-24 | `c2fc7f0965689a0cc2e978aea78596cd184aa8bd08fe4e3eeebf591a78d951e1` |
| `temas-de-apps/spotify/Sleek/color.ini` | `spicetify/spicetify-themes` (github.com/spicetify/spicetify-themes), commit `c432012478e1f2e2ffccca8e943e188af40d6190` (05/10/2026, a ponta do `master`) — `Sleek/color.ini`, copiado sem mudança (P107). A seção `[Dracula]` do color.ini credita draculatheme.com; o `LICENSE` é o da raiz do repositório |  | MIT | 2026-10-24 | `4f5a883afd9e71ddf515e8c7ecf44ca55688f4824b12294f4fdcc0f90745ed68` |
| `temas-de-apps/spotify/Sleek/user.css` | `spicetify/spicetify-themes` (github.com/spicetify/spicetify-themes), commit `c432012478e1f2e2ffccca8e943e188af40d6190` (05/10/2026, a ponta do `master`) — `Sleek/user.css`, copiado sem mudança (P107). A seção `[Dracula]` do color.ini credita draculatheme.com; o `LICENSE` é o da raiz do repositório |  | MIT | 2026-10-24 | `b5741a6e4caf5d9911fdd53010d48fd0e41f81336dc21e9f7da833d349b0a10a` |
| `wallpapers/catedral/agulhas.svg` | o tulip-orchid-wallpapers do dono do projeto (o repositório do `WALLPAPER_DRACULA_REPO`), commit `98770f8a4092b0376d43187dc29fd8110de4e567` — `svg/catedral-agulhas.svg`; desenho em código do gerador tulip-orchid (P74, 09/10/2026) |  | MIT | 2026-10-09 | `82dbd930cc6e05c433cd6f142d81a5e58a15e4573cb20059e1a3796729f0fe43` |
| `wallpapers/catedral/nave.svg` | o tulip-orchid-wallpapers do dono do projeto (o repositório do `WALLPAPER_DRACULA_REPO`), commit `98770f8a4092b0376d43187dc29fd8110de4e567` — `svg/catedral-nave.svg`; desenho em código do gerador tulip-orchid (P74, 09/10/2026) |  | MIT | 2026-10-09 | `b011b2debb64b3ab4a3e5ad7e700199af021b2bd1ec21fcc670c0ecacdf03a81` |
| `wallpapers/catedral/rosacea.svg` | o tulip-orchid-wallpapers do dono do projeto (o repositório do `WALLPAPER_DRACULA_REPO`), commit `98770f8a4092b0376d43187dc29fd8110de4e567` — `svg/catedral-rosacea.svg`; desenho em código do gerador tulip-orchid (P74, 09/10/2026) |  | MIT | 2026-10-09 | `22baa7c26afa34f778315bf1ecdafb7ef0788f25b9a50080b6c911c4fca8e03d` |
| `wallpapers/catedral/vitral.svg` | o tulip-orchid-wallpapers do dono do projeto (o repositório do `WALLPAPER_DRACULA_REPO`), commit `98770f8a4092b0376d43187dc29fd8110de4e567` — `svg/catedral-vitral.svg`; desenho em código do gerador tulip-orchid (P74, 09/10/2026) |  | MIT | 2026-10-09 | `cedb80d8d9619106bd0d999c1640a19c541f32e656bf15c00d0e853c82dc0b01` |
| `wallpapers/cemiterio/camposanto.svg` | o tulip-orchid-wallpapers do dono do projeto (o repositório do `WALLPAPER_DRACULA_REPO`), commit `98770f8a4092b0376d43187dc29fd8110de4e567` — `svg/cemiterio-camposanto.svg`; desenho em código do gerador tulip-orchid (P74, 09/10/2026) |  | MIT | 2026-10-09 | `a554048755f5d784b110c03717cae85b2c15d03d8e8d5cf5cdb0203f1069abf1` |
| `wallpapers/cemiterio/corvo.svg` | o tulip-orchid-wallpapers do dono do projeto (o repositório do `WALLPAPER_DRACULA_REPO`), commit `98770f8a4092b0376d43187dc29fd8110de4e567` — `svg/cemiterio-corvo.svg`; desenho em código do gerador tulip-orchid (P74, 09/10/2026) |  | MIT | 2026-10-09 | `a074e6c338c4112d243ae53c13eb58720f1bf2ff5ab94083161175fc7a44410c` |
| `wallpapers/cemiterio/portao.svg` | o tulip-orchid-wallpapers do dono do projeto (o repositório do `WALLPAPER_DRACULA_REPO`), commit `98770f8a4092b0376d43187dc29fd8110de4e567` — `svg/cemiterio-portao.svg`; desenho em código do gerador tulip-orchid (P74, 09/10/2026) |  | MIT | 2026-10-09 | `33638b94b51874bc8ec47f27ad4f1779336b2f900c05437f6da595f2af5a4044` |
| `wallpapers/noite/eclipse.svg` | o tulip-orchid-wallpapers do dono do projeto (o repositório do `WALLPAPER_DRACULA_REPO`), commit `98770f8a4092b0376d43187dc29fd8110de4e567` — `svg/noite-eclipse.svg`; desenho em código do gerador tulip-orchid (P74, 09/10/2026) |  | MIT | 2026-10-09 | `97f4dd5038c93523bb8ef25437b844e151e909dc3e273264b7a123cb876992c3` |
| `wallpapers/noite/mare.svg` | o tulip-orchid-wallpapers do dono do projeto (o repositório do `WALLPAPER_DRACULA_REPO`), commit `98770f8a4092b0376d43187dc29fd8110de4e567` — `svg/noite-mare.svg`; desenho em código do gerador tulip-orchid (P74, 09/10/2026) |  | MIT | 2026-10-09 | `c30c0cf5ddf799a71f339bfb1e4e475677d8d793f38e30c059c2ffbd8c5ddc6b` |
| `wallpapers/noite/velas.svg` | o tulip-orchid-wallpapers do dono do projeto (o repositório do `WALLPAPER_DRACULA_REPO`), commit `98770f8a4092b0376d43187dc29fd8110de4e567` — `svg/noite-velas.svg`; desenho em código do gerador tulip-orchid (P74, 09/10/2026) |  | MIT | 2026-10-09 | `20c83f6035204d7537e6a374d0c3cff087c5e12ad05f33daf6237f73a5b28d32` |
| `wallpapers/ornamento/espinhos.svg` | o tulip-orchid-wallpapers do dono do projeto (o repositório do `WALLPAPER_DRACULA_REPO`), commit `98770f8a4092b0376d43187dc29fd8110de4e567` — `svg/ornamento-espinhos.svg`; desenho em código do gerador tulip-orchid (P74, 09/10/2026) |  | MIT | 2026-10-09 | `892763fa19d7cf2ea5b95d802ae1902d77f059d581ae249733fc41c2d73588da` |
| `wallpapers/ornamento/filigrana.svg` | o tulip-orchid-wallpapers do dono do projeto (o repositório do `WALLPAPER_DRACULA_REPO`), commit `98770f8a4092b0376d43187dc29fd8110de4e567` — `svg/ornamento-filigrana.svg`; desenho em código do gerador tulip-orchid (P74, 09/10/2026) |  | MIT | 2026-10-09 | `d918010d17bffffb327e4341cfa7427970588b9c9d67b61f97ff9eac01ff2e71` |
| `wallpapers/ornamento/folios.svg` | o tulip-orchid-wallpapers do dono do projeto (o repositório do `WALLPAPER_DRACULA_REPO`), commit `98770f8a4092b0376d43187dc29fd8110de4e567` — `svg/ornamento-folios.svg`; desenho em código do gerador tulip-orchid (P74, 09/10/2026) |  | MIT | 2026-10-09 | `06bb3c4da2e9dfda1dbbf82a3aee79fa9bc7ba486b39a3aa0fa071ecccfd5b49` |
| `wallpapers/LICENSE` | o mesmo repositório e commit — `LICENSE` (MIT), que vai junto com os treze desenhos |  | MIT | 2026-10-09 | `54dd56f745539113bd6b29079d90164f9eede691dc181c46ae4ceead1e108191` |
| `sons/License.txt` | a licença do pacote do Kenney (CC0), que o tema trazia ao lado dos sons (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `7d6d3ccf1142669b7ea8629ed2b9eccda9c2d5d38841ff9ed6b50892651a5857` |
| `sons/index.theme` | o `index.theme` do mesmo tema (`src/sounds/Dracula/index.theme`, commit `4c57d138`), como veio (P74, 09/10/2026) |  | GPL-3.0 | 2026-10-09 | `6251884394c4361c747932931ea22b356de12ce1eac3965611f4a9b13fe3de57` |
| `sons/stereo/action/audio-volume-change.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/action/audio-volume-change.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `2a203a007d24cc7e607eb8bec1d86bedba7f551911217ce2c4c1f31393aed32c` |
| `sons/stereo/action/bell.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/action/bell.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `72b589eadd41781257ac859e4f4d030222e623390e4a1a83f6d05329a6e026f1` |
| `sons/stereo/action/camera-focus.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/action/camera-focus.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `df6112dc4eba5444bc28a1c8b80f6ce942bb2696beb466ac8e736b2ebf3e15b9` |
| `sons/stereo/action/camera-shutter.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/action/camera-shutter.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `0032710d1fc88c217946cd54492f275eb4363bb8025a4bc1b7ce08df7b3c60de` |
| `sons/stereo/action/count-down.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/action/count-down.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `4442b847419f5f203ef8ba16f19957124884da176c843d68d48a22e9cd022796` |
| `sons/stereo/action/screen-capture.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/action/screen-capture.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `0c1bb4db8a4d48b2b8c2e65a175d9056b845f1063837599995d81be1c5957d2c` |
| `sons/stereo/alert/alarm-clock-elapsed.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/alert/alarm-clock-elapsed.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `c2916f2a062c8ddd1aca2826d134fe90847037db31342726ffb0f9097afe339c` |
| `sons/stereo/alert/battery-low.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/alert/battery-low.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `e70139466c3e801358c9041ee17db7ff82c0e9a9cdf44647ad0ea6b9f8458f63` |
| `sons/stereo/alert/power-unplug-battery-low.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/alert/power-unplug-battery-low.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `cfa4391ca280933f567ce81c646b16f7cb2a090866eae674159a20f07641833c` |
| `sons/stereo/alert/software-update-urgent.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/alert/software-update-urgent.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `5574e69dd04e5f59322c5ddffde5978f077b09170ae5e29cec0bd9901828cd90` |
| `sons/stereo/notification/battery-caution.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/battery-caution.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `ab87913aba9790a0c5fa173d086267ba521ad522fcad2252271db49988313cf5` |
| `sons/stereo/notification/battery-full.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/battery-full.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `a0a99efaa755594982d5dfebf3d9cecaed5249bdf1f0de29cf26ca9ea24c191a` |
| `sons/stereo/notification/complete.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/complete.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `956c6612a256aa1a67a2327fffe2454f6b1d82e4c1c2be28fd66916335d5b1d6` |
| `sons/stereo/notification/desktop-screen-lock.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/desktop-screen-lock.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `c9134651ebbd7c016f90393aee495ff8120bd343bb7569b689a7506987ebd6c2` |
| `sons/stereo/notification/device-added.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/device-added.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `5b7e07eccd4413ad9ef3720c2d14f9cc699f4c50111e9b2f48bd60e6f1a164c3` |
| `sons/stereo/notification/device-removed.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/device-removed.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `2153e83ff9880c78f9539aa5dcce80fc9e3b39c6fa0f8dec9325ec6d7ea2c9d5` |
| `sons/stereo/notification/message-new-email.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/message-new-email.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `e42c226741e73fa6f3a501835dcca8c6d51105ee039f5d0ee29e0a3e5450a635` |
| `sons/stereo/notification/message-new-instant.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/message-new-instant.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `a464e34436f3c2a09f0e3a03dc0658a9036148062bbf293722007df4cfd8ff08` |
| `sons/stereo/notification/message.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/message.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `72b589eadd41781257ac859e4f4d030222e623390e4a1a83f6d05329a6e026f1` |
| `sons/stereo/notification/power-plug.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/power-plug.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `8c204ca94eb722d3af95f29221f4551938ca3c217fda32c14dabe2cf6a9c782b` |
| `sons/stereo/notification/power-unplug.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/power-unplug.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `01c7d15e90ae1b218812597d04c20e3df872367ebf22cd99d66dddd5fdb542a4` |
| `sons/stereo/notification/system-ready.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/system-ready.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `05609bb296cbc287ae95ac8924c89809d69c89d7bb357cc6a117ec1b1ef65e09` |
| `sons/stereo/notification/system-shutdown.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/system-shutdown.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `051b0eafc479695af4ca3607d41fd4be41bae7c21f4f9508d004722b09f1bd63` |
| `sons/stereo/notification/theme-demo.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/theme-demo.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `956c6612a256aa1a67a2327fffe2454f6b1d82e4c1c2be28fd66916335d5b1d6` |
| `sons/stereo/notification/window-attention-inactive.oga` | o tema de som do `Dracula_OS-Theme` (commit `4c57d138`), `src/sounds/Dracula/stereo/notification/window-attention-inactive.oga` — um efeito do «Sci-fi Sounds» do Kenney (kenney.nl), copiado do `.ogg` sem reencode, pela curadoria daquele tema (P74, 09/10/2026) |  | CC0-1.0 | 2026-10-09 | `ab87913aba9790a0c5fa173d086267ba521ad522fcad2252271db49988313cf5` |
| `icones/biblioteca/catalog.json` | `Dracula_OS-Theme` — `catalog.json` (o catálogo dos 295 de `src/icons/new-sessao-atual/`: descrição em português e etiquetas; commit `29b393b1`) |  | GPL-3.0 | 2026-10-09 | `1ab89bbcecbeecc6f1ff9cb7cab0d223306279d54120025ac5880a1051e4156d` |
| `icones/biblioteca/005-potion.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/005-potion.svg` |  | GPL-3.0 | 2026-10-09 | `276a9419a0821df9ef4075a024527e8538dc77bb4178f9e0f3db8133f45b8345` |
| `icones/biblioteca/007-mobile-game.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/007-mobile-game.svg` |  | GPL-3.0 | 2026-10-09 | `0de2bbe77fa164e82920051bc80aaa97a6f9745cd90b36e3ab8a7fb84703a63b` |
| `icones/biblioteca/009-crystal-ball.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/009-crystal-ball.svg` |  | GPL-3.0 | 2026-10-09 | `e134592cc143cd3b93d68190404b70da05628bac621c32ce9b68f3b5fbf4b844` |
| `icones/biblioteca/016-galaxy.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/016-galaxy.svg` |  | GPL-3.0 | 2026-10-09 | `07367fb9f391f39ba2fa9b14ad2f830d086a3ef1f1b82b9eef7bd3899ab51e34` |
| `icones/biblioteca/020-halloween.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/020-halloween.svg` |  | GPL-3.0 | 2026-10-09 | `3285653a3f7a79ed6ecc44ba77ee578cf373f074b99d662bfb974e1113d4d6f0` |
| `icones/biblioteca/026-building.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/026-building.svg` |  | GPL-3.0 | 2026-10-09 | `216c98316c1aa2db22aab1dc36995c4a7df94d9613b2d566502286c5ab1acdcd` |
| `icones/biblioteca/030-lantern.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/030-lantern.svg` |  | GPL-3.0 | 2026-10-09 | `c877521834f45d10d3bff8faf69de671d668f456988dba9459c72e8113a286ce` |
| `icones/biblioteca/040-scarecrow.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/040-scarecrow.svg` |  | GPL-3.0 | 2026-10-09 | `f23aa13c71f44dee020af782141ecaefa4d8cf306f854bb802f3c1442423c0c0` |
| `icones/biblioteca/041-scroll.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/041-scroll.svg` |  | GPL-3.0 | 2026-10-09 | `90f8d0735e07cd123f6eaf64f5c5ca1b456b992f3c942ef417f1401210ead339` |
| `icones/biblioteca/043-scythe.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/043-scythe.svg` |  | GPL-3.0 | 2026-10-09 | `e86866f2e0146fcab48816716d55263198ee7bbc0afac4f79862651f13a1f7d9` |
| `icones/biblioteca/045-computer-game.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/045-computer game.svg`; com outro nome porque o espaço do nome não cabe numa linha de mapa |  | GPL-3.0 | 2026-10-09 | `beb379a0832348c9b426240e71ede30429ae3b7a7e02292c75914b292e9d308b` |
| `icones/biblioteca/alpaca.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/alpaca.svg` |  | GPL-3.0 | 2026-10-09 | `31383e85903042a63e7dfa4148879bbbeb29a724c7af8c024d7fd0d2788a6568` |
| `icones/biblioteca/app-launcher.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/app-launcher.svg` |  | GPL-3.0 | 2026-10-09 | `47fed1cb754ce6fb4359459e8aa0cb8bc97f8d2c4f71a924a7a2e697d7e117da` |
| `icones/biblioteca/application-vnd.ms-cab-compressed.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/application-vnd.ms-cab-compressed.svg` |  | GPL-3.0 | 2026-10-09 | `9d4738af8dcfd3409da14561713eebce694c0aa7401d90635016d5ae2c562847` |
| `icones/biblioteca/application-x-dreamcast-rom.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/application-x-dreamcast-rom.svg` |  | GPL-3.0 | 2026-10-09 | `b8bfa43eb2d86634d08e28746a9cff0078b2c1e1e2699e57f50e26118d39f095` |
| `icones/biblioteca/application-x-genesis-rom.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/application-x-genesis-rom.svg` |  | GPL-3.0 | 2026-10-09 | `0a976958f9c2648bbe47a93d0efd967077f015590e3c64c8e7499a807579f745` |
| `icones/biblioteca/arcade-antigo.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/arcade.svg`; com outro nome porque `icones/biblioteca/arcade.svg` já era outro desenho |  | GPL-3.0 | 2026-10-09 | `36b7a2a87887f3422bd6f0797c288bf0cfa2edc2f79113d5ac5a69639beb7ad4` |
| `icones/biblioteca/AtomicGameEngine.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/AtomicGameEngine.svg` |  | GPL-3.0 | 2026-10-09 | `9f37ec5dc6c356551af885381eb0860aad92ed3cb732bb686ae91ff40cc15585` |
| `icones/biblioteca/atoms.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/atoms.svg` |  | GPL-3.0 | 2026-10-09 | `8680d1cd7495a11b0969928b79598e7599c016cb4fe6c770b9d218000b0d848d` |
| `icones/biblioteca/audio-volume-high-warning-symbolic.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/audio-volume-high-warning-symbolic.svg` |  | GPL-3.0 | 2026-10-09 | `12f428cb714e57e1b4f3ba24c28ecd4b995d1f4ea3099b580c29d56c8cdbd374` |
| `icones/biblioteca/bad-marker.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/bad-marker.svg` |  | GPL-3.0 | 2026-10-09 | `617c285c5b848b2da1d7023307f5ef388e59588f76545847e3048b9fc049abaa` |
| `icones/biblioteca/basex.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/basex.svg` |  | GPL-3.0 | 2026-10-09 | `af882e4af9011ab85d20b681101d4f02fb8aea7afff8693f8bd8a27852efa973` |
| `icones/biblioteca/battery-030-charging-profile-performance.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/battery-030-charging-profile-performance.svg` |  | GPL-3.0 | 2026-10-09 | `9c4137b6075eb40b95e6d4503d03719150f23d5d30f564197d875a21404a4208` |
| `icones/biblioteca/battery-080-charging-profile-balanced.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/battery-080-charging-profile-balanced.svg` |  | GPL-3.0 | 2026-10-09 | `54cd196e1c687d74387b57fdb7995aed03136919e0fca4fb2f6bc241ee2d9f10` |
| `icones/biblioteca/battery-100-charging-profile-balanced.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/battery-100-charging-profile-balanced.svg` |  | GPL-3.0 | 2026-10-09 | `25d187521834cb4453d0c193e6b9f9b13f5fc3f75fe71a219ba8e61f6b4813e2` |
| `icones/biblioteca/bibfilex.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/bibfilex.svg` |  | GPL-3.0 | 2026-10-09 | `8622d5bcda7e4bab8ca8fd2f95c97eb6239a68280634ea16e0909f9ecf7c0be5` |
| `icones/biblioteca/bitshares-ui.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/bitshares-ui.svg` |  | GPL-3.0 | 2026-10-09 | `4854d09c03047f293ab2bb83461fd2f047ddc94eeb18ff0665d5910daaf7aa8d` |
| `icones/biblioteca/blackbody.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/blackbody.svg` |  | GPL-3.0 | 2026-10-09 | `1ae39437d2d61a3dd3ecd54b646913bb20442c0a42e66db2e1308b82690354cb` |
| `icones/biblioteca/blue-folder-system.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/blue-folder-system.svg` |  | GPL-3.0 | 2026-10-09 | `2421236f7219ef461cd89f1342d1f7c6ade2fd6248c0489f058107a5b67f6213` |
| `icones/biblioteca/boilr.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/boilr.svg` |  | GPL-3.0 | 2026-10-09 | `2eb47af8fe435830686f2e86b5f0ff7d8169521e2edbc2d2a128e456921c2c6f` |
| `icones/biblioteca/box-antigo.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/box.svg`; com outro nome porque `icones/biblioteca/box.svg` já era outro desenho |  | GPL-3.0 | 2026-10-09 | `1b188ef5ad5a5ea078a5486c3a9a34c7a2dc1244add79c5b98ba51a24ccbd6bd` |
| `icones/biblioteca/braid.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/braid.svg` |  | GPL-3.0 | 2026-10-09 | `c7594e068936f2c2e9d7dae39b6708a5fba3856a5f92fa978f5a4b082ade2c66` |
| `icones/biblioteca/briar.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/briar.svg` |  | GPL-3.0 | 2026-10-09 | `475d69f08ff61c740a19e380cdec0c64be376e3729727605c22fddeee441d693` |
| `icones/biblioteca/brown-user-desktop.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/brown-user-desktop.svg` |  | GPL-3.0 | 2026-10-09 | `edfaef29e9fd4fd75011199fc709b28bd0e0dc4831200e2eb82f2f2fb702bf33` |
| `icones/biblioteca/bspline.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/bspline.svg` |  | GPL-3.0 | 2026-10-09 | `ad7de5e14a75718ac6ca858fa70937eae23b1350093eb65597652e0a0996ca67` |
| `icones/biblioteca/BTORRENT.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/BTORRENT.svg` |  | GPL-3.0 | 2026-10-09 | `ad47dbf902ed6d3b43576d4ba1bddedc7621f4bd8f3264baf4effd01a9502587` |
| `icones/biblioteca/buhocms.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/buhocms.svg` |  | GPL-3.0 | 2026-10-09 | `33803b2b1d936d055f219389efed61c6a3eafb4c18b458de73c9117876335293` |
| `icones/biblioteca/calendar-black-10.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/calendar-black-10.svg` |  | GPL-3.0 | 2026-10-09 | `43ae5e611aef79400a317627c42a784815b5f2f07e97675977703ffbdda89962` |
| `icones/biblioteca/calendar-black-12.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/calendar-black-12.svg` |  | GPL-3.0 | 2026-10-09 | `8d95bfaac4c68689ae996e190a0eb01036a75203b1781879c869cb1f33788a54` |
| `icones/biblioteca/calendar-blue-26.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/calendar-blue-26.svg` |  | GPL-3.0 | 2026-10-09 | `58231ac8e4e882c622956b8e41f9d116c91f630c397cf0d5b7202e4a2a30b03b` |
| `icones/biblioteca/calendar-purple-11.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/calendar-purple-11.svg` |  | GPL-3.0 | 2026-10-09 | `cdd41074a88be47c4a57a948d879e09af570a583269bb202660d355f9193e03a` |
| `icones/biblioteca/calendar-red-27.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/calendar-red-27.svg` |  | GPL-3.0 | 2026-10-09 | `021e320d2c91bd2d4086846401da77b63c06ca80f1b8830114aa2414976341c0` |
| `icones/biblioteca/calligrastage.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/calligrastage.svg` |  | GPL-3.0 | 2026-10-09 | `3e4e6108f18d40d80b8d864613a3068a71cbf7426d0f2d40e4a3d829a6a8012b` |
| `icones/biblioteca/calls.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/calls.svg` |  | GPL-3.0 | 2026-10-09 | `79089b9923eab34cc484b8db29da804dd73a6352bee61ce55f272fbaea952017` |
| `icones/biblioteca/cartridges.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/cartridges.svg` |  | GPL-3.0 | 2026-10-09 | `39f857b0d9e3943db20edb699d61cf54ef9ffc071d8981cca848c931e13703f6` |
| `icones/biblioteca/chatons.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/chatons.svg`; sem o atributo `inkscape:export-filename`, que guardava a casa de quem o desenhou (`/home/<nome>/…`) e não desenha nada — a origem tem sha256 `2bc3e80346a788f54128ff5254cd267b06ff182230b2fe8a2dc0d660e4e9338a` |  | GPL-3.0 | 2026-10-09 | `b91bdcb55f205f6dd799cd8e4750f2e314d3fde8f4c940ea6792ccf9596458a9` |
| `icones/biblioteca/chrome-ieicmdpibfnjbmjolkmohnelljmjomoj-Default.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/chrome-ieicmdpibfnjbmjolkmohnelljmjomoj-Default.svg` |  | GPL-3.0 | 2026-10-09 | `197029630f9ce6c5eba3ed3342ea73e454e718668373a7a3451d5572c1ad4e5c` |
| `icones/biblioteca/chrome-ofbpedjdfkboehhknoohhenbpmgcjoik-Default.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/chrome-ofbpedjdfkboehhknoohhenbpmgcjoik-Default.svg` |  | GPL-3.0 | 2026-10-09 | `e6193f6956e701451743707d87dfad94ab8875d5bafe23b540bf1d547adf7acd` |
| `icones/biblioteca/cleaner.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/cleaner.svg` |  | GPL-3.0 | 2026-10-09 | `dca95f0b0263a5ffae8deab4de6b84a9c194a6c68393229d1500900f980ebc31` |
| `icones/biblioteca/clima2.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/clima2.svg` |  | GPL-3.0 | 2026-10-09 | `60c2bf2b3ae4e1e95462e565741d368ca9ad32986f6dbffa091f29371601124a` |
| `icones/biblioteca/com.github.bilelmoussaoui.Authenticator.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/com.github.bilelmoussaoui.Authenticator.svg` |  | GPL-3.0 | 2026-10-09 | `6663ef7e84cba7ec672ff254c29a990e2dd4beb4e3e550cbca201f45f5aa6188` |
| `icones/biblioteca/com.github.freeeradicals.elements.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/com.github.freeeradicals.elements.svg` |  | GPL-3.0 | 2026-10-09 | `8adf6e2d906df17005b789383c6622adbe753c005b3a7351698186f7c3025e21` |
| `icones/biblioteca/coolero.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/coolero.svg` |  | GPL-3.0 | 2026-10-09 | `d4f35b17059bac144ee91914051e885c5e555fb32e080579657dd27e9bee3395` |
| `icones/biblioteca/cups-launcher.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/cups-launcher.svg` |  | GPL-3.0 | 2026-10-09 | `3a9e29fe0924623ad5c17cba89a46cadb468e0a96b0f8b3709a56ef3afb7c130` |
| `icones/biblioteca/czkawka-gui.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/czkawka-gui.svg` |  | GPL-3.0 | 2026-10-09 | `7d5d8891e29b95d4695410716a42ff82c5a359867ee69eebede806f775a7bf05` |
| `icones/biblioteca/dart.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/dart.svg` |  | GPL-3.0 | 2026-10-09 | `21c1a3dcc77ad491423686c51eb6f0ff2b433ed53531f8a4eae8833e79809ce6` |
| `icones/biblioteca/dbeaver-2.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/dbeaver.svg` |  | GPL-3.0 | 2026-10-09 | `465a0d41390801e0a8e1de34394daa5231630ee65824c2a17ccb6557d4916965` |
| `icones/biblioteca/dbt.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/dbt.svg` |  | GPL-3.0 | 2026-10-09 | `62d63733f9565d945078ad471e10366e228e3bca1365e4c7583adef1684d6cd2` |
| `icones/biblioteca/deepin-deb-installer.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/deepin-deb-installer.svg` |  | GPL-3.0 | 2026-10-09 | `031a26bcda0d3024371b1896dccbaab0eaa775878cc56375b4985dbaf1ff2064` |
| `icones/biblioteca/deepin-image-viewer.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/deepin-image-viewer.svg` |  | GPL-3.0 | 2026-10-09 | `db7ac43bd32d8720a055a7bcb2a2535708d9e0da8d643f2c75cddb85d852d956` |
| `icones/biblioteca/default-folder-github.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/default-folder-github.svg` |  | GPL-3.0 | 2026-10-09 | `2f80ec942b83c1e7e60366f2ed53f16e388df8e3131ae83e33e228ec7da219ed` |
| `icones/biblioteca/default-network-server.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/default-network-server.svg` |  | GPL-3.0 | 2026-10-09 | `e7278f074269a40dab2f63a2f39f12a31295299959bbe27f65b4c65fc154201b` |
| `icones/biblioteca/diffpdf.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/diffpdf.svg` |  | GPL-3.0 | 2026-10-09 | `90316427d2e60092713c0e87e932ecf9083801cf86a62da8b589e8900a2fd7a3` |
| `icones/biblioteca/discord.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/discord.svg` |  | GPL-3.0 | 2026-10-09 | `1669e445e3273665c9d01e367f74d089f1a45eac4c984d2620b6623ed97e1fb5` |
| `icones/biblioteca/distccmon.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/distccmon.svg` |  | GPL-3.0 | 2026-10-09 | `ab53349cc4c87c4b06359b8e5820c727f6d1395be36258160421274f1e17d224` |
| `icones/biblioteca/distributor-logo-lmde.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/distributor-logo-lmde.svg` |  | GPL-3.0 | 2026-10-09 | `c2f432dc8952ffa6b0facb28d9446d0a4bbacbd3d4416a5a8d1559bd26e9bd62` |
| `icones/biblioteca/distributor-logo-nomadbsd.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/distributor-logo-nomadbsd.svg` |  | GPL-3.0 | 2026-10-09 | `59cc62e2b4ad118317634bfd8a19a5ae3f23a5a5dd4ea6eb65250dd0e785e28b` |
| `icones/biblioteca/distributor-logo-quirky.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/distributor-logo-quirky.svg` |  | GPL-3.0 | 2026-10-09 | `07b77b6a396d0e764799606bc36f6d9a0e1db3596dfce46f8483968d39f1973e` |
| `icones/biblioteca/distributor-logo-ubuntu-unity.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/distributor-logo-ubuntu-unity.svg` |  | GPL-3.0 | 2026-10-09 | `ec59f0a4c2f1fd602b59c303c66112467374d8b8f84e9ebbd6db4e31ed833a2f` |
| `icones/biblioteca/distributor-logo-vanillaos.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/distributor-logo-vanillaos.svg` |  | GPL-3.0 | 2026-10-09 | `f2ba32827c9065cd7575e3d4071150e8c4978cc5d3e2d5de10b63c4bbe8063f2` |
| `icones/biblioteca/dwarf-fortress.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/dwarf-fortress.svg` |  | GPL-3.0 | 2026-10-09 | `21ab8358531b9755830a340cacdae399b1f93942f6dbcffd2e1548e26937fd1f` |
| `icones/biblioteca/easyssh.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/easyssh.svg` |  | GPL-3.0 | 2026-10-09 | `a24d82befa8ebb4f010502b47a96892cd25373b434bf198539e81f5d0e587b70` |
| `icones/biblioteca/eddy.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/eddy.svg` |  | GPL-3.0 | 2026-10-09 | `5adf3e581fd44a61a3d92047b23945dd74bed1e9d10a8bb27d2e2ddfd64439d5` |
| `icones/biblioteca/enteauth.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/enteauth.svg` |  | GPL-3.0 | 2026-10-09 | `b2eca6a7b98e91ab9d9a2e2e3b4bb798e6015f86404c01159c319af38a9a4f08` |
| `icones/biblioteca/face-confused.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/face-confused.svg` |  | GPL-3.0 | 2026-10-09 | `db6b8d0b672cb42a2addd3f3e321ce7e6ed52296ce4db42df1a79ad7cc746020` |
| `icones/biblioteca/gaiasky.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/gaiasky.svg` |  | GPL-3.0 | 2026-10-09 | `c88de3b05cff32bf27c391b44bec3d0511be05a5cbf2bba78b55e4e1cfab44ce` |
| `icones/biblioteca/gdevelop.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/gdevelop.svg` |  | GPL-3.0 | 2026-10-09 | `028962653a5417a5e0832dc0622857e0c05c04794b5a017c1e3e8e0a94936425` |
| `icones/biblioteca/gedit.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/gedit.svg` |  | GPL-3.0 | 2026-10-09 | `662f13785fdb37ae644446431651bfdaae6ddf51a6024fb9dee239b1b8176970` |
| `icones/biblioteca/ghostwriter2.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/ghostwriter2.svg` |  | GPL-3.0 | 2026-10-09 | `ac0293ea0518fc6db0403da13a48339caa414f6a132998401ddc2e385d2f4e46` |
| `icones/biblioteca/github.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/github.svg` |  | GPL-3.0 | 2026-10-09 | `170ab6d393e38afc23193342c66b9dc0ae9d7042167815fb5b2d2dfb5bcfcfd8` |
| `icones/biblioteca/glimpse.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/glimpse.svg` |  | GPL-3.0 | 2026-10-09 | `7045d0548b40990ded013307c9068b14a4a41e32ca36aecf73aa5681e260f653` |
| `icones/biblioteca/gnome-design-vectorslicer.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/gnome-design-vectorslicer.svg` |  | GPL-3.0 | 2026-10-09 | `c921f6369779e1ffd99114e602823d5091683cfff92db9ba56110b314bf97398` |
| `icones/biblioteca/gnome-remote-desktop.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/gnome-remote-desktop.svg`; é um PNG embutido num SVG, e não vetor |  | GPL-3.0 | 2026-10-09 | `9b3f29075e4292f73b7460868d41622747b3e235fc794d8d9249e11c62ca5dca` |
| `icones/biblioteca/green-qt.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/green-qt.svg` |  | GPL-3.0 | 2026-10-09 | `bb4f7f511deffbb9122c7a2a79e00ec553ed290b793cc6061db6c62b076e786f` |
| `icones/apps/guvcview.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/gucview.svg` |  | GPL-3.0 | 2026-10-09 | `cc23195d5e32f240772b55b3232a2b0a32dfe37df4847c78c1c94457dd6d9999` |
| `icones/biblioteca/halftone.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/halftone.svg` |  | GPL-3.0 | 2026-10-09 | `07c0b4d1b97bf1ef0dc4cafe1d292ee41a2a2ed28dc18d584c5d421eb7eb79ac` |
| `icones/biblioteca/hardinfo.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/hardinfo.svg` |  | GPL-3.0 | 2026-10-09 | `9304939edbb4697e6a4a9736745e035569a259e07d55dcc398098cabd812aa56` |
| `icones/biblioteca/i-score.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/i-score.svg` |  | GPL-3.0 | 2026-10-09 | `c23dd9bd14eff4ff399fbc5bd5074cbea41c785d271c5d06b7a4a39744c3d18d` |
| `icones/biblioteca/iaito.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/iaito.svg` |  | GPL-3.0 | 2026-10-09 | `94dbc4dc8660b8a6748e0686ca0a1b11aa41854efe0d74600aa2107965dd9fc5` |
| `icones/biblioteca/ic_light_enpass.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/ic_light_enpass.svg` |  | GPL-3.0 | 2026-10-09 | `39ad300d93605363453797d877f42233ee84c315a6e05df4ba9772cde0717608` |
| `icones/biblioteca/ignition.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/ignition.svg` |  | GPL-3.0 | 2026-10-09 | `ecdb2c415512c639c2f0dadcce70b51ad2fcb75efe12ab04f2c67fb13d2f6b93` |
| `icones/biblioteca/image-aseprite.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/image-aseprite.svg` |  | GPL-3.0 | 2026-10-09 | `d74194cece5a6bc259d176ceef4b0207ed62605d0e37caf79425f7274d8a0683` |
| `icones/biblioteca/io.github.dvlv.boxbuddyrs.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/io.github.dvlv.boxbuddyrs.svg` |  | GPL-3.0 | 2026-10-09 | `ca5d0581c7896f0650eca2aea50d73f12514385cee150ce75ffcb20c4aa46d8b` |
| `icones/biblioteca/iotas.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/iotas.svg` |  | GPL-3.0 | 2026-10-09 | `32f8332e740c7bf663d31ef8be7c33b69b83ce8dec6ffab977c4a913cd78fcd9` |
| `icones/biblioteca/jogos.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/jogos.svg` |  | GPL-3.0 | 2026-10-09 | `0e998890dc7f7b22bf8fc4d3fe12400eb1e7c7227cd2c6b74e7b765467eb3830` |
| `icones/biblioteca/jupyter.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/jupyter.svg` |  | GPL-3.0 | 2026-10-09 | `5b55f5ec8d4c08a510bd0a9493e4d988e39e34d56307a7e3fbf1800936e8202e` |
| `icones/biblioteca/Kazam.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/Kazam.svg` |  | GPL-3.0 | 2026-10-09 | `d34e79a3d5c4e67bf954ca1270ebbbabc453a0a1b6c0871e5891abc3f810bfe8` |
| `icones/biblioteca/kongress.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/kongress.svg` |  | GPL-3.0 | 2026-10-09 | `6e83333f70b39cb4877efbfcdd9ee90ab7d59728766a47a72a55f55538fa910d` |
| `icones/biblioteca/latex.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/latex.svg` |  | GPL-3.0 | 2026-10-09 | `1675d954f14bac3b5e0d4964aecdf17b13dfc3ebf6a2f1ef74411c1fa4de093b` |
| `icones/biblioteca/LogAnalyzer.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/LogAnalyzer.svg` |  | GPL-3.0 | 2026-10-09 | `168d708f3a0825d7cbc62e1f80bb3c80e91badc8e856b687fe583f5f42e0a4ad` |
| `icones/biblioteca/logo-dat-desktop.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/logo-dat-desktop.svg` |  | GPL-3.0 | 2026-10-09 | `f43a3b0b870124729f9c09342673f7af4c38614e22254cb531787efa8964b12f` |
| `icones/biblioteca/lunarvim.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/lunarvim.svg` |  | GPL-3.0 | 2026-10-09 | `ccade347e60cc9e11f0ae29abf8d1724ed91a96e08e33fecb71efc250ba06284` |
| `icones/biblioteca/luppp.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/luppp.svg` |  | GPL-3.0 | 2026-10-09 | `6a86742ca382cb594e30e7c2ca2044e61fbdd8109014bdba2c39d51771996a0b` |
| `icones/biblioteca/manta.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/manta.svg` |  | GPL-3.0 | 2026-10-09 | `1e0682abbdc16f41dfd40a0931a2c9832672f3aca70a46c6d9b484634af5f187` |
| `icones/biblioteca/minimal-podcasts-player.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/minimal-podcasts-player.svg` |  | GPL-3.0 | 2026-10-09 | `fc31a3057072c8be46b908c00b4ec27e521bcfbb5bcd7df06a349dbd509f238c` |
| `icones/biblioteca/minuet-rhythms.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/minuet-rhythms.svg` |  | GPL-3.0 | 2026-10-09 | `dc0a683b8fa3b56fea868c53953aa8a73f67fa714ef126f6b487c2988e5d43b5` |
| `icones/biblioteca/mirrorhall.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/mirrorhall.svg` |  | GPL-3.0 | 2026-10-09 | `829b7810b27796cb4de21a2de6ec8d95a1f9f3eb0184c1689ca02098bd2428e6` |
| `icones/biblioteca/ms-teams.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/ms-teams.svg` |  | GPL-3.0 | 2026-10-09 | `cbdd23ce1bfe5d9b5f5e4a5c22296d574972d9300967aed1a8391923d477f9e9` |
| `icones/biblioteca/musictube.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/musictube.svg` |  | GPL-3.0 | 2026-10-09 | `d4552d6cf7664bf1ad5eaa33d8baebbfa4755d6f030fa4f61eac000042d128bd` |
| `icones/biblioteca/network-mobile-20-edge-locked.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/network-mobile-20-edge-locked.svg` |  | GPL-3.0 | 2026-10-09 | `02146f6712931c571f9fb4685c69e781423128632845d9499cf296daee16b6af` |
| `icones/biblioteca/network-mobile-20-lte.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/network-mobile-20-lte.svg` |  | GPL-3.0 | 2026-10-09 | `3a0bd19f0881df2a66fdda71e99a52cdc012f775d9dfca0c0db784d5915ce651` |
| `icones/biblioteca/network-mobile-60-edge.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/network-mobile-60-edge.svg` |  | GPL-3.0 | 2026-10-09 | `845ac8318ff1ef8302576df285e4800c86a8df9070c518260c14e8c9d6ff032b` |
| `icones/biblioteca/network-wireless-80-limited-symbolic.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/network-wireless-80-limited-symbolic.svg` |  | GPL-3.0 | 2026-10-09 | `a87fd244602f73192bc339731c19ed3b3dbcfae117814b2660a4b5ec637732d0` |
| `icones/biblioteca/noisetorch.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/noisetorch.svg` |  | GPL-3.0 | 2026-10-09 | `53d33c5d9849bb68e61eed31cbb6b7ba3bd63075180cb1fb7bfba35dbc05e248` |
| `icones/biblioteca/nuclear.png.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/nuclear.png.svg` |  | GPL-3.0 | 2026-10-09 | `ee7d097f28a840a96e1e0cd2faa92e87b2a55a69cd5950eff6110d57c3983391` |
| `icones/biblioteca/org.gnome.Terminal.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/org.gnome.Terminal.svg` (mesmos bytes de `com.system76.CosmicTerm.svg`) |  | GPL-3.0 | 2026-10-09 | `75c1fc13d733666c8281c04a8a30b23bd25e989d931ca3a82eab659efc34bf3d` |
| `icones/biblioteca/org.kde.kompare.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/org.kde.kompare.svg` |  | GPL-3.0 | 2026-10-09 | `bf364ab9bb3bf7f1d5b9f66e073fc69acb7d33ef9a8216ab337d9d9486b58d9f` |
| `icones/biblioteca/paisa.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/paisa.svg` |  | GPL-3.0 | 2026-10-09 | `678baccb12369be6919bca2ae3a71f2807721c31e3a728db6dd2c3ccd8480d8c` |
| `icones/biblioteca/picsaw.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/picsaw.svg` |  | GPL-3.0 | 2026-10-09 | `8499495b3a76f51a132739309005648fb56d66668b0409535208cc1b59fdc0f7` |
| `icones/biblioteca/pink-folder-gradle.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/pink-folder-gradle.svg` |  | GPL-3.0 | 2026-10-09 | `feb7ee36dcda28f36a17e715e5f3cf60e7ad64d5c829bc6d1c0978a8172dd69a` |
| `icones/biblioteca/plasmavault.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/plasmavault.svg` |  | GPL-3.0 | 2026-10-09 | `3688746e44c4757b965930addb55db6db8a8c8925345761e206bec75708b29bf` |
| `icones/biblioteca/preferences-desktop-display-color.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/preferences-desktop-display-color.svg` |  | GPL-3.0 | 2026-10-09 | `68291770e06c18662f0563eed61b8db21dcc175ad7bfc3ae7fad3845db6a2bca` |
| `icones/biblioteca/proton-mail.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/proton-mail.svg` |  | GPL-3.0 | 2026-10-09 | `ce870f23bd110f457a850f6a018d6adca7e8070eb408f9f1ce5a687ea0e72706` |
| `icones/biblioteca/purple-folder-script.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/purple-folder-script.svg` |  | GPL-3.0 | 2026-10-09 | `67bca39f4665e0be0c911c756c12946a14e6ed8317ae9bc139d157b4bd1ee668` |
| `icones/biblioteca/PySimpleCV.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/PySimpleCV.svg` |  | GPL-3.0 | 2026-10-09 | `547ae979eb91c5fbb4e98525ad8c3337e1d4c98f7b66f76de48193a7f3cdb8fd` |
| `icones/biblioteca/pyspread.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/pyspread.svg` |  | GPL-3.0 | 2026-10-09 | `8ed2efa9d6f258f96d78c737c4681b01bc44a711c659d7fcec7edc0e9b11e87e` |
| `icones/biblioteca/python-idle.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/python-idle.svg` |  | GPL-3.0 | 2026-10-09 | `4aa3db5fe0c4cf71df45145d97de4a3ae3d36fb7236a8326a5e29fa22066fa22` |
| `icones/biblioteca/python.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/python.svg` |  | GPL-3.0 | 2026-10-09 | `5289429a6fc7d2dca1539b1484b82a0605687cae71ba8ec3dfe77880647acbf5` |
| `icones/biblioteca/qcanvas.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/qcanvas.svg` |  | GPL-3.0 | 2026-10-09 | `96c77d6152a2f40d19cb99b8066dd6e316af8221c473c3ad73f6639c8eee4ff5` |
| `icones/biblioteca/qgifer.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/qgifer.svg` |  | GPL-3.0 | 2026-10-09 | `1cf3ce86e34d9d76c4a579003e3418b36260787efffc8a0b0cd7baba679bddba` |
| `icones/biblioteca/readitlater.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/readitlater.svg` |  | GPL-3.0 | 2026-10-09 | `a2b006dea41dc947d264c14da3779295df5264d13cc1a962e0420397cc142847` |
| `icones/biblioteca/recordbox.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/recordbox.svg` |  | GPL-3.0 | 2026-10-09 | `2740d4b5bd10cca9027c9892f4183aa8fde096ca965c380b5bb1c8317348932e` |
| `icones/biblioteca/red-folder-video.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/red-folder-video.svg` |  | GPL-3.0 | 2026-10-09 | `16c0bc3ac60d8142901bf3229ce52f196835d01315efbafb9122bf6cd3407595` |
| `icones/biblioteca/rede.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/rede.svg` |  | GPL-3.0 | 2026-10-09 | `9994285574313ab1e55c36b5b2ae6466e626f5d4fafce2774095131bb75553f9` |
| `icones/biblioteca/retro.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/retro.svg` |  | GPL-3.0 | 2026-10-09 | `ddb205568653f15f31907aa4755bbb661b940042fdc3d50feb109f03a2c032e7` |
| `icones/biblioteca/rhb.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/rhb.svg` |  | GPL-3.0 | 2026-10-09 | `b2a48aed8be29a33fba66d598b4ce9c4da35f12e0b321156c7519eecf0fc5a9d` |
| `icones/biblioteca/sigviewer.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/sigviewer.svg` |  | GPL-3.0 | 2026-10-09 | `1af775abe42876d4b307efb798d18c84a69d611acb6c6cd9499ce198f3666348` |
| `icones/biblioteca/siliconsneaker.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/siliconsneaker.svg` |  | GPL-3.0 | 2026-10-09 | `e13f11abd3caca5a0137bb0ec68f7d97f42664ea26dcf9684af426f690d57ba7` |
| `icones/biblioteca/skype-call-recorder.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/skype-call-recorder.svg`; é um PNG embutido num SVG, e não vetor |  | GPL-3.0 | 2026-10-09 | `a6c641be40fa269bf23ee6ab17f868e87ae12b4e116e0c7dc9acfbf8739bb2f1` |
| `icones/biblioteca/slack.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/slack.svg` |  | GPL-3.0 | 2026-10-09 | `a0f4d8f4ed00457aa89fdffca08370f6221bcdfd2381e8d40aa76332e8ba50f1` |
| `icones/biblioteca/slimbook.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/slimbook.svg` |  | GPL-3.0 | 2026-10-09 | `c0727e9152a5904092101beb9c0b9c28e057aeb3c01461df8e9a2366a31f1f87` |
| `icones/biblioteca/spacestation14.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/spacestation14.svg` |  | GPL-3.0 | 2026-10-09 | `5d08fff9ff0b5d26ddc7aa1a8d3548f4cf5ac6d25483bb0d8eae8ca686a3183f` |
| `icones/biblioteca/SPEEDTEST.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/SPEEDTEST.svg`; sem o atributo `inkscape:export-filename`, que guardava a casa de quem o desenhou (`/home/<nome>/…`) e não desenha nada — a origem tem sha256 `fec959aa8e621975b3684637bae886ffb92c26c37e2cd7a0355fadf8b214241d` |  | GPL-3.0 | 2026-10-09 | `77af003d6b83090ed955f4e45be3231e7ec20daf274c43418bdf57410e7a9074` |
| `icones/biblioteca/spring.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/spring.svg` |  | GPL-3.0 | 2026-10-09 | `54d77bf280a0c1abcd7aa7853653f098a9975b075f9b84b9ab35245d86884a37` |
| `icones/biblioteca/steam_icon_1250.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_1250.svg` |  | GPL-3.0 | 2026-10-09 | `357b06f79c80f86756d6e0271ac2d346fda3f0403a0688d551a41b59314fe62a` |
| `icones/biblioteca/steam_icon_241600.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_241600.svg` |  | GPL-3.0 | 2026-10-09 | `562ad82eeef877167ec3fa6738f38bbb771437cb35404e93bd9501885ffcb8ee` |
| `icones/biblioteca/steam_icon_265930.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_265930.svg` |  | GPL-3.0 | 2026-10-09 | `c46e711d829a88915e4f5d54d1c4fcc3119cd5d2bb43eeb35991b1b245c34dcc` |
| `icones/biblioteca/steam_icon_304930.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_304930.svg` |  | GPL-3.0 | 2026-10-09 | `90e6784e8cfc2c76ff29d657175144307de228be5e132edc22956125b5c65191` |
| `icones/biblioteca/steam_icon_308420.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_308420.svg` |  | GPL-3.0 | 2026-10-09 | `6fdfdca5c1d6bd16fe85106dfc63a91db1158455aaee676e28cb17e18634f6e5` |
| `icones/biblioteca/steam_icon_356570.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_356570.svg` |  | GPL-3.0 | 2026-10-09 | `7e8ba56f6f969b684ae1acb21873e5ff26707b71045726b2d9e2b039f02bd769` |
| `icones/biblioteca/steam_icon_38740.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_38740.svg` |  | GPL-3.0 | 2026-10-09 | `10348a8ff5d18b823b4e0ebe912dea641b293c5512fb8d6bb62c0220ce7f5350` |
| `icones/biblioteca/steam_icon_400020.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_400020.svg` |  | GPL-3.0 | 2026-10-09 | `6c5851a93952236e76c7bf126fb8931138dcd72d119f013f6e9e9de00b860d1c` |
| `icones/biblioteca/steam_icon_435530.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_435530.svg` |  | GPL-3.0 | 2026-10-09 | `647b261d7b5557b2b1a1d418e239695e9baf589843f6a24bcbe02870eed615fd` |
| `icones/biblioteca/steam_icon_457760.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_457760.svg` |  | GPL-3.0 | 2026-10-09 | `4c5280b3cd457adfd8014a6376d7de26e1853c994ac01cd49d7f6e49a0f0fb0f` |
| `icones/biblioteca/steam_icon_514900.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_514900.svg` |  | GPL-3.0 | 2026-10-09 | `b788024873a8dd9df540765dbd4f4846e5cad258f661fd12110adb6fbbe5a4f6` |
| `icones/biblioteca/steam_icon_524220.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_524220.svg` |  | GPL-3.0 | 2026-10-09 | `943efafac216a9862bb6efd47e361a16f60fb05ccff9c9dd8faa0b6bbb06cded` |
| `icones/biblioteca/steam_icon_552620.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_552620.svg` |  | GPL-3.0 | 2026-10-09 | `d3ca64b937b91f3bcb91c7e22daf14c3ac117745ba78fd5c73e2129c5bb38f28` |
| `icones/biblioteca/steam_icon_607260.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_607260.svg` |  | GPL-3.0 | 2026-10-09 | `8d73b162b6d28911eef6a892eb5055fdc7378e4797c99263aa0a1ca59080586f` |
| `icones/biblioteca/steam_icon_65980.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_65980.svg` |  | GPL-3.0 | 2026-10-09 | `580d5c3c437134f6edca328439596a7ad4440bfb6300b890719c27836c7cbf6c` |
| `icones/biblioteca/steam_icon_953490.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/steam_icon_953490.svg` |  | GPL-3.0 | 2026-10-09 | `e3e05e3c2fa1a01762ab1c3bc4210a7a4686c915ff665c3477dd825fd5d106b4` |
| `icones/biblioteca/system-suspend-inhibited.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/system-suspend-inhibited.svg` |  | GPL-3.0 | 2026-10-09 | `a3cdae50ad262a860f41c7613dccf0dd5a246cb8142bfbb52f85c5f01d0fbdfd` |
| `icones/biblioteca/tauno-plotter.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/tauno-plotter.svg` |  | GPL-3.0 | 2026-10-09 | `12b3da67632364f7851c126da1dec78362525890a28fa70b5c1371024444de6e` |
| `icones/biblioteca/timetrack.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/timetrack.svg` |  | GPL-3.0 | 2026-10-09 | `d8b405838e575cb9791557620d67be397a74f21d7aa07fbd731095882b02fa3f` |
| `icones/biblioteca/top-power-off-icon.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/top-power-off-icon.svg` |  | GPL-3.0 | 2026-10-09 | `d0af4747267af4a9ee84fb7dae726459301fac52c5d07389247ace518d2a798b` |
| `icones/biblioteca/tromapps.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/tromapps.svg`; sem o atributo `inkscape:export-filename`, que guardava a casa de quem o desenhou (`/home/<nome>/…`) e não desenha nada — a origem tem sha256 `55071bb9f5bf87d851ae6c553ad99de9a8b9c1d587f7bc157f0e17a986c76212` |  | GPL-3.0 | 2026-10-09 | `7aca833116fbcbd772f80492f49855c8f5863559387a65effb9c9781eb0cf77f` |
| `icones/biblioteca/ultrastardx.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/ultrastardx.svg` |  | GPL-3.0 | 2026-10-09 | `7697a82e9c3f400820f4397cb71f50327ce8f77202ad42608a25eb3e72f46162` |
| `icones/biblioteca/upnp-router-control.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/upnp-router-control.svg` |  | GPL-3.0 | 2026-10-09 | `0e28e37dd15f28fa544d3ee59bc92317daabcd7ccf528aedc990d48b08ce58d7` |
| `icones/biblioteca/vnclicensewiz.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/vnclicensewiz.svg` |  | GPL-3.0 | 2026-10-09 | `1c20a99bf097964e83f8a37b76e3f3cd67eefe79e763036bda36cd2b90d5813a` |
| `icones/biblioteca/whatsapp.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/whatsapp.svg` |  | GPL-3.0 | 2026-10-09 | `de7ef3558ac12718507ebbd886bf1697d7df1133b166122c0a63c3559b77be3b` |
| `icones/biblioteca/window-pop-out.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/window-pop-out.svg` |  | GPL-3.0 | 2026-10-09 | `65b92cb91486e423f0d0d22f11e54b8ee6820c4834ed58696a9f3c2ad34e3e7a` |
| `icones/biblioteca/workspace-switcher-symbolic.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/workspace-switcher-symbolic.svg` |  | GPL-3.0 | 2026-10-09 | `b9ef58c60eaf602fc05789300133326b6d73c478a0e4708b51b0f8e182b653b0` |
| `icones/biblioteca/wrapbox.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/wrapbox.svg` |  | GPL-3.0 | 2026-10-09 | `d9bbe59995fd8913f9c7645097d5375a6c6ef48842381d29339535ca5703fe84` |
| `icones/biblioteca/xfce-system.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/xfce-system.svg` (mesmos bytes de `system_section.svg`) |  | GPL-3.0 | 2026-10-09 | `053d1604e9519fdd6d81efc85c121e6e89b3f1eea74c327b8869abb7a29017e2` |
| `icones/biblioteca/xtactics.svg` | `Dracula_OS-Theme` — `src/icons/current/scalable/apps/xtactics.svg` |  | GPL-3.0 | 2026-10-09 | `76531e5194bfcb8b9be00200907869c4fbbf287707c2c97dd9b6ed787cacb836` |
| `icones/biblioteca/Antigravity.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/Antigravity.png`, sha256 `5126588073f18c9dd6db59ed9a07872ca773520db6e886b9e6651c4af1f4e226`, que saiu do pack depois de passar: RMSE 0,046 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/Antigravity.png` |  | GPL-3.0 | 2026-10-15 | `beb870190805925933e67ef213b0eed657bfff9b7b3e09b0605ac05bc6463ccb` |
| `icones/biblioteca/Easy-Effects.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/Easy-Effects.png`, sha256 `8b305c1392d47c7b8bf0d7c8e0246ecefa51dfaf8c84eee8c27f88cac7a5e898`, que saiu do pack depois de passar: RMSE 0,077 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/Easy Effects.png`; o nome mudou para caber numa linha de mapa |  | GPL-3.0 | 2026-10-15 | `ab4b6f03680003f57febde84da23ffccd94d6a83e611dcf8249482215fb49dd9` |
| `icones/biblioteca/FileZilla.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/FileZilla.png`, sha256 `d527c62329865ef3fe5533068f381e0130b85e67e03abe789ea1470e830abea0`, que saiu do pack depois de passar: RMSE 0,113 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/FileZilla.png` |  | GPL-3.0 | 2026-10-15 | `46483e6331cba2478ae45532a538dddad549f90cab2cda0cbb1683a0b5aa363d` |
| `icones/biblioteca/Heroic-Games-Launcher.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/Heroic-Games-Launcher.png`, sha256 `cbc053c80d212b44ce6ff16ceb5528a8933da59e2e156b9c8c8c8fb327978d49`, que saiu do pack depois de passar: RMSE 0,107 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/Heroic Games Launcher.png`; o nome mudou para caber numa linha de mapa |  | GPL-3.0 | 2026-10-15 | `0c0eaea53e14008bd8a2ec9b7293edd40a85d7f35ce5a1e540200c9dca3adbba` |
| `icones/biblioteca/Tweaks.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/Tweaks.png`, sha256 `0833c26dd15844eb695400027dd344b8d8405e4382ffe259f62cd9e0cec0b695`, que saiu do pack depois de passar: RMSE 0,035 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/Tweaks.png` |  | GPL-3.0 | 2026-10-15 | `4d1c4be6b264ef7f6c4b3823dec78287ffd7e873625bcc5e97ee3a3b90c088c2` |
| `icones/biblioteca/box-buddy.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/box-buddy.png`, sha256 `8d2e773ae84bfe58bb7ad81dde0c38fa0a5da0dce29a3fa307d497b25e7ce243`, que saiu do pack depois de passar: RMSE 0,154 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/box-buddy.png` |  | GPL-3.0 | 2026-10-15 | `7fe1ed2f60018837a4ee3dcf51227be7f9517e566a72313c95dc61c4fac8be3c` |
| `icones/apps/calculadora.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/calculadora.png`, sha256 `7bbeb7a9ebc7ede3ba959d9226bf812f8a9f1fbe94885280d8dd44217294e712`, que saiu do pack depois de passar: RMSE 0,054 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/calculadora.png` |  | GPL-3.0 | 2026-10-15 | `d1cc7b20b7d24702d1fb2e3808ba0eb0cd866b17cc959b31d76672512cb54f88` |
| `icones/biblioteca/calendario.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/calendario.png`, sha256 `853c192a93bf7ef9e8a2d58e91894d6ba526c7cf90ccca81ffeb8f27103caffe`, que saiu do pack depois de passar: RMSE 0,042 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/calendário.png`; o nome mudou para caber numa linha de mapa |  | GPL-3.0 | 2026-10-15 | `dc20004a9603b1583ce0518d4104c443422b9e91b6c79d0d1efa109b1c042feb` |
| `icones/biblioteca/camera.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/camera.png`, sha256 `c5f31a6df32af8d34bb66b510bf9606d5533de1199177583e6023b21e3af74e9`, que saiu do pack depois de passar: RMSE 0,079 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/camera.png` |  | GPL-3.0 | 2026-10-15 | `d77926a8ad416478430590e14e1a38a60fb97a8a0b7422c9348afc7b7e7cf7a3` |
| `icones/biblioteca/cheese.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/cheese.png`, sha256 `49920b0c2c299096e92c574ef9f30161d7fef65d73a4e80dc43cad840b7c561f`, que saiu do pack depois de passar: RMSE 0,063 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/cheese.png` |  | GPL-3.0 | 2026-10-15 | `7a21d7e00fdeaebf18a2b3ff1847eb2c2c6888770f635bbcc13170b132df601d` |
| `icones/biblioteca/com.system76.CosmicSettings.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/com.system76.CosmicSettings.png`, sha256 `1ba596c0e3e4a2ca65f401d2bdfb8c76d733498ea95f9ea7e47b5aa754f73e8f`, que saiu do pack depois de passar: RMSE 0,084 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/com.system76.CosmicSettings.png` |  | GPL-3.0 | 2026-10-15 | `4599f0e8818de5eb76c877b8ea8ce718c99bdd52b85a2cfefe2dc939efa7f87b` |
| `icones/biblioteca/dbeaver.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/dbeaver.png`, sha256 `dc297ee8083deba78b6935b5fe6cc09661d87e7db80b4e8b634a668166c163af`, que saiu do pack depois de passar: RMSE 0,073 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/dbeaver.png` |  | GPL-3.0 | 2026-10-15 | `011b28c1fdbc7b20f16615fd378361b71db85a49c7d447ecb7a7e104a9ea83bc` |
| `icones/apps/com.microsoft.Edge.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/edge.png`, sha256 `479760d3e460ca5c35bd5b7d5911882bf9fc64c56d2793fcfd9f690d62764ea8`, que saiu do pack depois de passar: RMSE 0,177 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/edge.png` |  | GPL-3.0 | 2026-10-15 | `9befe0aa840d14386c7f38d11bb304a2204ed405562e99ca317e5ad1fbb6c81d` |
| `icones/apps/firefox.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/firefox.png`, sha256 `aa0904456835e915ffe60853020856dbb6e977d4644ecf870bd05392c47f484b`, que saiu do pack depois de passar: RMSE 0,164 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/firefox.png` |  | GPL-3.0 | 2026-10-15 | `3a77396fc595cade8e90c713669345596f9108b9fb10817ed9f622db70dd6ed8` |
| `icones/apps/flatseal.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/flatseal.png`, sha256 `818a9353aec97e6561ba97cbfbb7911a501a199593ffca358a19819db813a280`, que saiu do pack depois de passar: RMSE 0,092 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/flatseal.png` |  | GPL-3.0 | 2026-10-15 | `13098598d47fdf97aeff842b6b7f10f220e1a7e3114d70092c54b1ab62d70503` |
| `icones/apps/gerenciador-de-extensoes.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/gerenciador-de-extensoes.png`, sha256 `6b875d6ee9bcc148cdbfeaea553987dc594ea8434a10960262b8dc835399c4eb`, que saiu do pack depois de passar: RMSE 0,078 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/gerenciador-de-extensoes.png` |  | GPL-3.0 | 2026-10-15 | `60fee0e1852fb24fe7c1e2d235bb77009a70d8b070014bf79b8a5a58a2d685b9` |
| `icones/biblioteca/gerenciador-de-menu.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/gerenciador-de-menu.png`, sha256 `cb622c0b6e17a0eacd565770ef0b6607bdfeee566c0c1c9716fff91d51371924`, que saiu do pack depois de passar: RMSE 0,124 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/gerenciador-de-menu.png` |  | GPL-3.0 | 2026-10-15 | `e4075329a9f9d5b0551875a49f62b771ff93ddceecff07e9be14acc00729ce8b` |
| `icones/biblioteca/gparted.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/gparted.png`, sha256 `2ff2033b25eff9377c7444124c2dbb4f12b37fd6abd4ae22d42652f8eadf1694`, que saiu do pack depois de passar: RMSE 0,061 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/gparted.png` |  | GPL-3.0 | 2026-10-15 | `3415ad6bfe9d250a2724cc53461624e7fb10f13f51f3bd55768d4370313c3981` |
| `icones/apps/gradia.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/gradia.png`, sha256 `ddec7ad2f5f7a43c5172b205ad7c0d7d8009371ff1b7b3883efe6ea44ae3bef1`, que saiu do pack depois de passar: RMSE 0,094 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/gradia.png` |  | GPL-3.0 | 2026-10-15 | `04afdf5e046ec71d61f14ae2941131b0d8166a4913829ba73973bd5bc5bda0c3` |
| `icones/biblioteca/krita.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/krita.png`, sha256 `55728bdc2f7a69d927ff990db89b7cd3af9a4a4ab02841267f5880e4c3a2409c`, que saiu do pack depois de passar: RMSE 0,037 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/krita.png` |  | GPL-3.0 | 2026-10-15 | `655edf69451632f79dea04f7cbb051f778092170d92bce4b8502207552adc65e` |
| `icones/biblioteca/linux-toys.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/linux-toys.png`, sha256 `5c3c3b02f5093c371970fc245f680552639687aa0d994eea2e8c8b4af801b3a8`, que saiu do pack depois de passar: RMSE 0,072 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/linux-toys.png` |  | GPL-3.0 | 2026-10-15 | `7cd5bea65444af046800207b5c0e3db93ee18226c8f1898a085e9e48d689d1ab` |
| `icones/biblioteca/obs-studio.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/obs-studio.png`, sha256 `2bcfd1a4427ad06f249bf24a1f4d377c315cada7a65086af1568589732341f77`, que saiu do pack depois de passar: RMSE 0,072 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/obs-studio.png` |  | GPL-3.0 | 2026-10-15 | `9c24958c64f50aa7227f39d222da01ebf31331d7c5b66231056452d291ee9105` |
| `icones/biblioteca/opera.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/opera.png`, sha256 `2b04f4c0af6c87268add74562005d05d3a37a6b4986bb4ad0df2cd61f84e7fcf`, que saiu do pack depois de passar: RMSE 0,051 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/opera.png` |  | GPL-3.0 | 2026-10-15 | `d54d6497b363b258b0c1d2d15c5de81c0e508dfba2ec410d9d7c90aa7ed1c98d` |
| `icones/apps/visualizador-de-imagens.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/visalizador-de-imagens.png` (o nome do vetor saiu com a grafia certa em 16/10/2026, no fechamento da leva H; o PNG tinha o erro de digitação da origem), sha256 `5f541fc13af6e44e92412f1f8ae6a79451b7886d9d9924cd9b71bcfd954c18b7`, que saiu do pack depois de passar: RMSE 0,082 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/visalizador-de-imagens.png` |  | GPL-3.0 | 2026-10-15 | `169ae38e9b126e59d149c507cf4edf9a6cb0faa82f12c094c32fa9d5f14d98e9` |
| `icones/apps/vscode.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/vscode.png`, sha256 `05cd67998b862adb129e7cd7377deae00ca28cfd5fefa07935664a4323ef5054`, que saiu do pack depois de passar: RMSE 0,062 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/vscode.png` |  | GPL-3.0 | 2026-10-15 | `0acf57a682d76a99ed13ff72a8b79f341caf452b86483be2f4634a4c618846f4` |
| `icones/biblioteca/warehouse.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/warehouse.png`, sha256 `a9c0b3e073e71a41219dc851a322c732f8916f385edb8e1a1771e6f7510ca161`, que saiu do pack depois de passar: RMSE 0,044 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/scalable/apps/warehouse.png` |  | GPL-3.0 | 2026-10-15 | `8bd87c30ba19fd51391ae9262cd9009e8192c66524550e23587415b72eb9968c` |
| `icones/apps/com.github.rafostar.Clapper.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/Clapper.png`, sha256 `c2d989baf85e5e65f99b4e7f962e887aa265a5aab2dc87e5b7d21f0b1863ff32`, que saiu do pack depois de passar: RMSE 0,111 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/48x48/apps-global/Clapper.png` |  | GPL-3.0 | 2026-10-15 | `6bac55417c098981508ceaa1503f7a2726fcbc669a402300851758fb69d072b0` |
| `icones/biblioteca/demo-general2018.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/demo-general2018.png`, sha256 `59c4046ebf70ee930547ba3ab1dd93138ff2fad59818d0ef46c98f97110ed4c2`, que saiu do pack depois de passar: RMSE 0,117 contra ele. O PNG veio de `Dracula_OS-Theme` — `src/icons/current/48x48/apps-global/demo-general2018.png` |  | GPL-3.0 | 2026-10-15 | `cdb696467398f387f950663ceb830428599f60e068e2a2810f248a0ce2c9cdea` |
| `icones/biblioteca/hplj1020.svg` | vetor desenhado à mão em 15/10/2026 (P84) sobre `icones/feitos-a-mao/hplj1020.png`, sha256 `d74318b1532ed72064dbe6c30cf63325b58b77f1f83e1c69c685dbc40807d909`, que saiu do pack depois de passar: RMSE 0,165 contra ele. O PNG veio de o tema antigo `Dracula-Icones`, na cópia congelada de 24/09/2026 (`~/.local/state/meowsystem/backups/2026-09-24T03-50-20-copias-congeladas-dracula/`) — `scalable/apps/hplj1020.png` |  | GPL-3.0 | 2026-10-15 | `736bb161b21e6db1c0f3a0e9d7a8e0e9a1a9a65ccfe8c4d740ef9fe7fcb09274` |
| `icones/biblioteca/Ubuntu-3.svg` | versão; escrito em `~/Desenvolvimento/MeowSystem/.trabalho-icones/svg/Ubuntu.svg` e recuperado da transcrição do agente (sessão de 16/09/2026) — gravação 1; fonte: transcrição |  | GPL-3.0 | 2026-10-16 | `604bac97e736a88736311aca1418e8465990617495394b54a85caf689c71e303` |
| `icones/biblioteca/morcego-dia-2.svg` | versão; escrito em `~/Desenvolvimento/MeowSystem/.trabalho-icones/svg/morcego-dia.svg` e recuperado da transcrição do agente (sessão de 16/09/2026) — gravação 4; fonte: transcrição |  | GPL-3.0 | 2026-10-16 | `ec89ff748d4015667efc90d0f1cd046575906a40f6a25c94b899bd9a4d374861` |
| `icones/apps/syncthing-candidato-v4.svg` | versão; escrito em `scratchpad da sessão 55ef96a5/v4.svg` e recuperado da transcrição do agente (sessão de 16/09/2026) — última gravação; fonte: transcrição |  | GPL-3.0 | 2026-10-16 | `97d7a84e491ca0e985fbb59f2049819d42d5015e0ce1f2ef56d782292c7a85a4` |
| `icones/biblioteca/Ubuntu-2.svg` | versão do histórico do git, `git 8b37812:assets/icones/resgatados/Ubuntu.svg` (12/09/2026); fonte: git |  | GPL-3.0 | 2026-10-16 | `4794b7787096f8e7e5efebf4673d0d87fa79f2f71b8db679b8f44dfd086164b0` |
| `icones/apps/opera.svg` | rascunho; escrito em `~/Desenvolvimento/.wt-meow/p84/packs/dracula/icones/feitos-a-mao/opera.svg` e recuperado da transcrição do agente (sessão de 15/10/2026); fonte: transcrição, photorec |  | GPL-3.0 | 2026-10-16 | `5168676f691b37db25ca480b4b7dd546121924d8058a5839732340ed3ffdbdb0` |
| `icones/biblioteca/Ubuntu.svg` | versão; escrito em `~/Desenvolvimento/MeowSystem/.trabalho-icones/svg/Ubuntu.svg` e recuperado da transcrição do agente (sessão de 16/09/2026) — gravação 2; fonte: transcrição |  | GPL-3.0 | 2026-10-16 | `29290ae68d68463aa3691d464c29241bad98f3c3f9c612cc86e29ecb5d858abf` |
| `icones/apps/weylus.svg` | rascunho; escrito em `~/Desenvolvimento/MeowSystem/weylus.svg` e recuperado da transcrição do agente (sessão de 16/10/2026) — última gravação; fonte: transcrição |  | GPL-3.0 | 2026-10-16 | `f9c3d4ef0d23f4b5fa43b7b23182956325c9e3c338a543cdb6a46105ff976e1a` |
| `icones/apps/photogimp.svg` | rascunho da oficina: `~/Desenvolvimento/MeowSystem/.trabalho-icones/svg/photogimp.svg` (15/09/2026); fonte: disco |  | GPL-3.0 | 2026-10-16 | `4cab971732361106d3d58daf7499dfcc745b63f7428ca9c3f07cc32b9596e786` |
| `icones/biblioteca/doppelganger-icon.svg` | projeto dela fora da lista de exclusão (decisão 16, item 2): git fe12d59:Detector-de-Doppelganger/assets/icon.svg; fonte: git; limpeza da P78: tirou comentário de editor (sha256 da origem `0378e56a49dcaa4b7bd37ae3133a416471c2efe9c31119a463b7c7225b6dcf65`) |  | GPL-3.0 (arte dela, entra pelo pedido de 15/10/2026) | 2026-10-16 | `d209a5e448e2ee30084cbdf980e12db85ecf59a46f1ccc5c666634f2ce68e645` |
| `icones/biblioteca/detector-doppelganger.png` | projeto dela fora da lista de exclusão (decisão 16, item 2): ~/.local/share/icons/hicolor/512x512/apps/detector-doppelganger.png; fonte: disco |  | GPL-3.0 (arte dela, entra pelo pedido de 15/10/2026) | 2026-10-16 | `b0a7bbac07015c17d5fca932958f999d0a6557111b4d3eb758ba733727f24dd9` |
| `icones/apps/mnemo.svg` | projeto dela fora da lista de exclusão (decisão 16, item 2): ~/.local/share/icons/hicolor/scalable/apps/mnemo.svg; fonte: disco |  | GPL-3.0 (arte dela, entra pelo pedido de 15/10/2026) | 2026-10-16 | `e400a1ce7b301f84aaa5bbff5f54f9a1a2db61dba3828c5d9e5f5f32abe93d08` |
| `icones/biblioteca/neurosonancy.png` | projeto dela fora da lista de exclusão (decisão 16, item 2): ~/.local/state/meowsystem/backups/2026-09-24T03-50-20-copias-congeladas-dracula/Dracula-Icones/256x256/apps/neurosonancy.png; fonte: backup |  | GPL-3.0 (arte dela, entra pelo pedido de 15/10/2026) | 2026-10-16 | `a1c3f4e02ccd69b2bcaec3563136f20128d521f0de790183bb4fb548b0c47dcb` |
| `icones/biblioteca/arcanetab-dracula.svg` | projeto dela fora da lista de exclusão (decisão 16, item 2): ~/Desenvolvimento/ArcaneTab/assets/dracula.svg; fonte: disco |  | GPL-3.0 (arte dela, entra pelo pedido de 15/10/2026) | 2026-10-16 | `1a1aec807782aaf6b9a904e1d640e3d683dcb07cb64b14eee7fd39d6493c75e0` |
| `icones/biblioteca/luna-favicon.svg` | projeto dela fora da lista de exclusão (decisão 16, item 2): ~/Desenvolvimento/Luna/docs/favicon.svg; fonte: disco |  | GPL-3.0 (arte dela, entra pelo pedido de 15/10/2026) | 2026-10-16 | `22b41f537862b84056154a93fb7f3f714d19bbea0fba92caee6cc4c26e605b4c` |
| `icones/apps/extase-em-4r73.svg` | projeto dela fora da lista de exclusão (decisão 16, item 2): ~/Desenvolvimento/MeowSystem/.trabalho-icones/svg/extase-em-4r73.svg; fonte: disco |  | GPL-3.0 (arte dela, entra pelo pedido de 15/10/2026) | 2026-10-16 | `75d4c4408cdf4dae58f2cee2ab5bad68ca88824c0d3c083341b6451cdec21cb8` |
| `mascote/morcego-dia.svg` | `packs/meowsystem/mascote/morcego-dia.svg` do motor (commit `5aee691`, 15/09/2026), cópia: o motor continua usando o dele como logo do COSMIC; fonte: motor |  | GPL-3.0 | 2026-10-16 | `9db7f5100ab5bfa90e29ec81df62cfcf9ea01acd1a56a2fccf1e78e89bbdab5a` |
| `mascote/morcego-noite.svg` | `packs/meowsystem/mascote/morcego-noite.svg` do motor (commit `5aee691`, 15/09/2026), cópia: o motor continua usando o dele como logo do COSMIC; fonte: motor |  | GPL-3.0 | 2026-10-16 | `8cdb449c7a082ff3f895582f4a781a991883118e9d556a3de3a186eb31234ef2` |
| `icones/biblioteca/aurora-iniciar.svg` | `uploads/aurora-icone-iniciar.svg`, commit `b178261` (04/08/2026, Vitória), que saiu do repositório junto com a pasta `uploads/`; fonte: git |  | GPL-3.0 | 2026-10-16 | `c111a96bc81a01c79d932cf7898be293cefd29fb46308d5c1cc2a065169d5ef5` |
| `mascote/morcego.svg` | `packs/meowsystem/mascote/morcego.svg` do motor (commit `5aee691`, 15/09/2026), cópia: o motor continua usando o dele como logo do COSMIC; fonte: motor |  | GPL-3.0 | 2026-10-16 | `1f0aa6a25e862c43bddf9bc748ee4070ccd088e1e31392d9574fe2478a5b31de` |
| `icones/biblioteca/citrix.svg` | vetor de 12/09/2026 do Citrix, commit `8b37812`, `assets/icones/resgatados/Ubuntu-selfservice.svg`, trocado em 15/09 (`5aee691`); vence a régua do BRIEFING (RMSE 0,030 contra o PNG feito à mão, contra 0,041 da P84): é o desenho que os 11 nomes do Citrix vestem (decisão 16, itens 3 e 6); fonte: git |  | GPL-3.0 | 2026-10-16 | `010b2cf823d454f2d0fea3c3e874550abe1f9f105e363ad0d07fb9555debe862` |
| `icones/sistema/ac-adapter-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/ac-adapter-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `d7c3f955b48f0fda91c63bdb4230caf5be4adc40681108d43ec14f5bde4b8ed4` |
| `icones/sistema/airplane-mode-disabled-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/airplane-mode-disabled-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `434adf418c92553779625e08193aa8a9db40e86fd4301058cca5f7f5c872dbbf` |
| `icones/sistema/airplane-mode-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/airplane-mode-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `4b90ae1b402395531b8ac88e76a4b220df4b456dd8d21285f401342d12c343a5` |
| `icones/sistema/application-x-executable-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/mimetypes/application-x-executable-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `b738b5117d622f59bb2a052d09ad9ed5af674a2efeba143a96e33a6294661a16` |
| `icones/sistema/audio-card-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/audio-card-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `c92f82cc69c12abce8dcbb94da956c8ff29121ba79f109b510c5201eb63900be` |
| `icones/sistema/audio-headphones-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/audio-headphones-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `c0dd3ab91f132073886ebf912f42490e5c854bf15275f47474d8fe70593b9282` |
| `icones/sistema/audio-headset-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/audio-headset-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `faf9e094dfffdad6a2f5d5f615a63a5c3986620ff5f2f5e0e23a1aafbf5927e0` |
| `icones/sistema/audio-input-microphone-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/audio-input-microphone-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `bcd806ef802b69d22d8f5b5e3ddfe2ce2cc398506a3ea1e303fef512920edd47` |
| `icones/sistema/audio-speakers-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/audio-speakers-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `3d6b51998eac726a41400047a4230646108d0282f665adf5a381f5c6ba5fb94d` |
| `icones/sistema/audio-volume-high-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/audio-volume-high-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `645cbd9256dc8bf524f2324d56f0d6c82eac9fb37ae708d776716ee5553d7eb3` |
| `icones/sistema/audio-volume-low-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/audio-volume-low-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `30b3c6c85aeb19f9a86505f2602080b1bab5471969941afa04a91e5cfe50b366` |
| `icones/sistema/audio-volume-medium-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/audio-volume-medium-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `4265b7038f0914f2dcd4629b62ca63bbee3ae926e3552bc2d48d1e00a7381cf9` |
| `icones/sistema/audio-volume-muted-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/audio-volume-muted-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `809a392cff862c41b46d9f04c52b29b212d014c8e2530eb04360dc040979d917` |
| `icones/sistema/audio-volume-overamplified-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/audio-volume-overamplified-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `21049ce5c3ea83b5c6d6b96ec67f60e36e6dd0735f0d6be5d9369828a98902f2` |
| `icones/sistema/audio-x-generic-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/mimetypes/audio-x-generic-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `bdeb98022e633a41fa54c759cd6d0b99b79a3570c8acc384f4b1856f195308c1` |
| `icones/sistema/battery-caution-charging-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-caution-charging-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `bc5688bc3bd51c743a9712b1da028f61d1c884be76f3731ca936dd829802ce03` |
| `icones/sistema/battery-caution-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-caution-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `dacc75894f4518f4603dfd31fd86c9d52fd06431bfc2d275219baf6e2aea75c2` |
| `icones/sistema/battery-good-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-good-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `955780e06070820f33791139b9d6d24adc02b55d12716c34e30cc539659ab84e` |
| `icones/sistema/battery-level-0-charging-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-0-charging-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `43785a389559f87a6ab12cf72b8869f3a8ec72aac275f0264190207e6a63fe03` |
| `icones/sistema/battery-level-0-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-0-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `dacc75894f4518f4603dfd31fd86c9d52fd06431bfc2d275219baf6e2aea75c2` |
| `icones/sistema/battery-level-10-charging-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-10-charging-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `bc5688bc3bd51c743a9712b1da028f61d1c884be76f3731ca936dd829802ce03` |
| `icones/sistema/battery-level-10-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-10-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `cadd3ca67b22045188b7308aac12d2003b2b3e03139b7c2e45c2c5982dfea375` |
| `icones/sistema/battery-level-100-charged-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-100-charged-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `989025f35607bb6e9d837efca41dd98684b0c689a61cbddf7da7843609a4cc16` |
| `icones/sistema/battery-level-100-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-100-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `22cde68ab0ce672d3b3a0b6281f96f2c3085b4d05ca854223f6c031d9213ed56` |
| `icones/sistema/battery-level-20-charging-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-20-charging-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `788b0b5834ab723d52ec35f7391f739d18184a28d97a715274a9f79c9477ebe8` |
| `icones/sistema/battery-level-20-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-20-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `932e8d9f0bded051b0c28c9f63a8f474e249991c96a17c071a3d38276331ebe2` |
| `icones/sistema/battery-level-40-charging-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-40-charging-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `b367dbfb99a3a33a27b9051bcb1da3690dd5f2d7a68b81644f94d644d43bcc94` |
| `icones/sistema/battery-level-40-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-40-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `4dddecc1b9b250d04951f3cc1542de3d0b222e4d2dd4bb03ec1ccd6ffdf15ea9` |
| `icones/sistema/battery-level-50-charging-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-50-charging-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `0fbff4288c4feaa0be14a1d2a6305962d2ae3e2d78bcdfa7b602648d5f75e59f` |
| `icones/sistema/battery-level-50-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-50-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `1df26c8694f90112011653a6a05add73614fa20ee38071566cbaa86f7c9c680a` |
| `icones/sistema/battery-level-70-charging-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-70-charging-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `23308935c3ed14a0c8fca0d4ffa86281e77699f313353be5922327f4a3e8508b` |
| `icones/sistema/battery-level-70-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-70-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `955780e06070820f33791139b9d6d24adc02b55d12716c34e30cc539659ab84e` |
| `icones/sistema/battery-level-80-charging-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-80-charging-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `52eae1bfdc58c6540dacf6642588033281165cc8225cd2770afd1c6a077d4528` |
| `icones/sistema/battery-level-80-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-80-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `954f76fc3524544d621085cc88e617b12f01f84813c4b378f7bfc5de84623d70` |
| `icones/sistema/battery-level-90-charging-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-90-charging-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `eeb8d3217a34a140d7fbbbc7dcac123e81031677b3f33ba1585c7d01d77b1d90` |
| `icones/sistema/battery-level-90-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/battery-level-90-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `49f2e62c4b7711a5bb9e78ba55d06f354c7b1b82ad69de757e1832549926e58b` |
| `icones/sistema/battery-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/battery-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `3d3caed14e4800a6ba688fdccdf63ebb07abb097227313aba6814fe92b300f0f` |
| `icones/sistema/bluetooth-active-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/bluetooth-active-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `56dd085bc74fecf9fc26866445e089fa9c4af8f6800724ff09249a8847e8c7db` |
| `icones/sistema/bluetooth-disabled-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/bluetooth-disabled-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `d3d907733393d0286f67cdbeef2c92597e7c2a0fb36791073a3916c68af9f07a` |
| `icones/sistema/bluetooth-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/bluetooth-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `2dbab4c22ace5876a5c8a35b49a886c0c59aab152268ba19e9199252ae38811d` |
| `icones/sistema/camera-photo-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/camera-photo-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `525b5a40508f7b23f38d8e45bf30233f39e929eae539ba205778629b28f1acde` |
| `icones/sistema/camera-video-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/camera-video-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `a20526409c51299814f39280525ebe5b1e8d0be7b9358a431d02113b3aeee83e` |
| `icones/sistema/channel-secure-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/channel-secure-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `98a7d545fb2e7e914a7eaed1c68598d09e9d55b71ca7427a8d6ce36b1c33be49` |
| `icones/sistema/checkbox-checked-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/checkbox-checked-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `46268ba879108ea02376b3f334b5c6e4e009adef127ebf2ffc88d5e04ee2d04f` |
| `icones/sistema/cosmic-applet-battery-level-0-limited-charging-symbolic.svg` | desenho deste projeto (P131): o `battery-level-0-charging-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `7b0cc9840e33737912058d0c420508eba500042cb91e2a5bd386c11552c4e2d3` |
| `icones/sistema/cosmic-applet-battery-level-0-limited-symbolic.svg` | desenho deste projeto (P131): o `battery-level-0-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `038118b8649897ff7579a43bdd075d663e5703ec8a87eefac07d170f57656f5a` |
| `icones/sistema/cosmic-applet-battery-level-10-limited-charging-symbolic.svg` | desenho deste projeto (P131): o `battery-level-10-charging-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `12e46c56f43611765c6bfc2309c0084558153d99609ff27f1715e456bb18cfda` |
| `icones/sistema/cosmic-applet-battery-level-10-limited-symbolic.svg` | desenho deste projeto (P131): o `battery-level-10-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `6409b40ce7aaa18852f8f9f9a1b06f961c3780113218c0ba0d2ff3f8ce3f57d3` |
| `icones/sistema/cosmic-applet-battery-level-20-limited-charging-symbolic.svg` | desenho deste projeto (P131): o `battery-level-20-charging-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `62f5e3409dff747d14f961f933782d96890b403d2a26b8595ffae17ec2f2b06c` |
| `icones/sistema/cosmic-applet-battery-level-20-limited-symbolic.svg` | desenho deste projeto (P131): o `battery-level-20-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `297de3924c381824f16b3d7fe976f93bbd65059246892f2c4adb374f03a6449c` |
| `icones/sistema/cosmic-applet-battery-level-35-limited-charging-symbolic.svg` | desenho deste projeto (P131): o `battery-level-40-charging-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `fae6a08bbb26c037b425256cc8a850a7ae1f2f1cfb6bc25d121bb785caebace5` |
| `icones/sistema/cosmic-applet-battery-level-35-limited-symbolic.svg` | desenho deste projeto (P131): o `battery-level-40-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `6cb6fb3f3f413718251556299c4099861338343fc5ba7a52a49165ad58956ed4` |
| `icones/sistema/cosmic-applet-battery-level-5-limited-charging-symbolic.svg` | desenho deste projeto (P131): o `battery-caution-charging-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `12e46c56f43611765c6bfc2309c0084558153d99609ff27f1715e456bb18cfda` |
| `icones/sistema/cosmic-applet-battery-level-5-limited-symbolic.svg` | desenho deste projeto (P131): o `battery-caution-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `038118b8649897ff7579a43bdd075d663e5703ec8a87eefac07d170f57656f5a` |
| `icones/sistema/cosmic-applet-battery-level-50-limited-charging-symbolic.svg` | desenho deste projeto (P131): o `battery-level-50-charging-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `6070469ae826af318293763de83c02c1fc0090e3513abeba3d4ae9ec9a16c97e` |
| `icones/sistema/cosmic-applet-battery-level-50-limited-symbolic.svg` | desenho deste projeto (P131): o `battery-level-50-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `41bd21bd28b38172b4350763b8ce7d8e362275176417ac9a46b7af542d8d0501` |
| `icones/sistema/cosmic-applet-battery-level-65-limited-charging-symbolic.svg` | desenho deste projeto (P131): o `battery-level-70-charging-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `67b43ba9800a5339755e78b8c070401acf41823ccba97d7450e0ba687d5491dc` |
| `icones/sistema/cosmic-applet-battery-level-65-limited-symbolic.svg` | desenho deste projeto (P131): o `battery-level-70-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `dfec9d03b50fc21a2f5c21ce6879759acde256bc6d079ce2ea8d57d284146fd0` |
| `icones/sistema/cosmic-applet-battery-level-80-limited-charging-symbolic.svg` | desenho deste projeto (P131): o `battery-level-80-charging-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `9f6e86a87f25b605257be38cbad59d5ba0c19ae3e73cbe82bca589114c15de60` |
| `icones/sistema/cosmic-applet-battery-level-80-limited-symbolic.svg` | desenho deste projeto (P131): o `battery-level-80-symbolic` do `m4thewz/dracula-icons` com o teto do limite de carga |  | GPL-3.0 | 2026-10-27 | `d288411098108f00600bd388d824f1902990e1828b57e4ad0b44380c8a416b8b` |
| `icones/sistema/dialog-error-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/dialog-error-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `99aa7b54afd00f7c9436fb44f1549c0538b4bb585be89af6bc0fd0f3f83199e3` |
| `icones/sistema/display-brightness-high-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/display-brightness-high-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `84800b6313f34757c8351bf3643122aa497b74fdb586701904c610dc592c3c11` |
| `icones/sistema/display-brightness-low-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/display-brightness-low-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `86d760522ff2a9de4fee6333bbefc29c38c42c5fb5dd108423c95a4b0dccb6a4` |
| `icones/sistema/display-brightness-medium-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/display-brightness-medium-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `bff0688bc7c9541fa95b6aa36a1c4609113225f92692f7a946a0b1eab205fe02` |
| `icones/sistema/display-brightness-off-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/display-brightness-off-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `0a669364cb949214812be2b8e4c6429d46ba440c11ae12bb09321ec2ad377032` |
| `icones/sistema/display-brightness-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/display-brightness-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `bff0688bc7c9541fa95b6aa36a1c4609113225f92692f7a946a0b1eab205fe02` |
| `icones/sistema/document-properties-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/document-properties-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `0deb5521e5d34d1bcf51fb9a0c70b170d48f6578f51cd04d6d55a78c33d69e84` |
| `icones/sistema/edit-clear-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/edit-clear-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `496c9624207ece4fc0f035f27cf7d2bc9793312376bf68e13e9493753d39e84d` |
| `icones/sistema/edit-copy-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/edit-copy-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `5517953e08587c48fc0b159e07c609fa9ebbc02bc47c67108d72e693d964b8db` |
| `icones/sistema/edit-delete-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/edit-delete-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `3de4de8243e56214528ac6213f98cf22d5e9d2b8a83790e17e5b9d8bebf9afda` |
| `icones/sistema/edit-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/edit-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `677feb5b715d67d5d8cf2a0c33330d5dfd65b0c997896217a0f57a30f30a5193` |
| `icones/sistema/emblem-ok-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/emblems/emblem-ok-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `04a8b0f48b5478b46dc283244126ca8e069fb0d58a08d33c9e21d87e28c7cebb` |
| `icones/sistema/focus-top-bar-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/focus-top-bar-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `8dbcbeb7c28f7b1593e75d90a2495e3cbe3e2df1de6cc26df6b36ba32621f3c2` |
| `icones/sistema/focus-windows-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/focus-windows-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `6c07c66a2f7e14308965172e5c1886605bda2bcf59ecdb5ff5e5a8ed6c9b899a` |
| `icones/sistema/folder-new-symbolic.svg` | desenho deste projeto (P131), no preenchido de 16 px do `m4thewz/dracula-icons` |  | GPL-3.0 | 2026-10-27 | `7a2a0a086e1fac17bc7323d6572870636bcecbcce2da1bdb76b3e053f0e0e09c` |
| `icones/sistema/folder-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/places/folder-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `359dbcc862ed0bdbfd804da7b7f69bb68010054d4b3f88787da5329e20394b69` |
| `icones/sistema/go-down-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/go-down-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `89c5c1f67b635af484ba67effe2369b55504d859b6276afe0be65b9a45c58422` |
| `icones/sistema/go-next-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/go-next-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `5f05a6b667303146de2ecde40f785e162764fcf7c25ac183621d1ff45a535ada` |
| `icones/sistema/go-previous-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/go-previous-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `20d4a98820c09f72f2c4a1200f0d1bd6ff90e95b648b615a75bc3d94d0a384e3` |
| `icones/sistema/go-up-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/go-up-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `afa9125309bf1dc082fdfb6f4739a6d7fcb64f7d7cba694f8c025ce127de8495` |
| `icones/sistema/grip-lines-symbolic.svg` | desenho deste projeto (P131), no preenchido de 16 px do `m4thewz/dracula-icons` |  | GPL-3.0 | 2026-10-27 | `5816dfed992cf22f17b71f7328e37f680c5b9a402745560bbe6303adff43fae2` |
| `icones/sistema/help-about-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/help-about-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `037e8f25534140c65cb6a51a382c144c5b5580c06ec5fa34be23cd06fbf1a6c4` |
| `icones/sistema/image-red-eye-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/image-red-eye-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `9322a2766e4cbfd17a680e07bcc177b03f937792f5b4a40ac1c59e1a0dfd5d03` |
| `icones/sistema/input-gaming-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/input-gaming-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `e41b4a896c65d1dbed1a6c795aa69a9b83a61ce27613887515b3c7b7d7470669` |
| `icones/sistema/input-keyboard-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/input-keyboard-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `3c237a767db9bb4e3703b77ff3d2a4b3aca49f370c1e43746d0ee7c661b326a9` |
| `icones/sistema/input-mouse-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/input-mouse-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `4cee050a4b38679573b80913d07ef6320a3481eba788ac51b190044c220389e9` |
| `icones/sistema/input-tablet-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/input-tablet-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `ec370340b23cded2cf002788292f31b006ac8cbc02945051b6f23fe324dda104` |
| `icones/sistema/input-touchpad-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/input-touchpad-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `d7f3d4338f4034cdf002cf7000de9dd5395d431378e566bd968c1bc0eb7aeff7` |
| `icones/sistema/keyboard-brightness-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/keyboard-brightness-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `fbff1631ae00314237bff814a29e6c56200e7ebb945a27bfd0a5d82dbb77fea6` |
| `icones/sistema/laptop-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/laptop-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `6e2ce219d439f936a28c4175c9da9ba31c7e9bace9cc4b1acfe534d58f3d1372` |
| `icones/sistema/list-add-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/list-add-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `6ca26011d0cd9e7b0a6930887765d7c639cb4b0c0d16f920fc65d183b0bddcaa` |
| `icones/sistema/list-remove-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/list-remove-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `9c71360b7c0a995340f4cfa97a649aba724a89126845a05c79b466791deb26af` |
| `icones/sistema/media-playback-pause-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/media-playback-pause-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `d775afcbd9efc4a8b5891eec035a1fda2a35c634d3479494b8dd23cfd25525c8` |
| `icones/sistema/media-playback-start-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/media-playback-start-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `ad97cd1b70e55954100679b2d203ad113146c9f475fd03472f1930fc633b32a1` |
| `icones/sistema/media-skip-backward-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/media-skip-backward-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `8dc2b67d2e5e818460e55c28344cfaf631570efe5c35815dc4a92ee671c8ae97` |
| `icones/sistema/media-skip-forward-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/media-skip-forward-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `1de20b75f9540319d5187f260c69f9b113b502d1c043fe7fe79746666234e064` |
| `icones/sistema/microphone-sensitivity-high-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/microphone-sensitivity-high-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `339cf3db1c959e3d1883d9b268c830d5b47b690c6e50976cc7d5fc04c217c714` |
| `icones/sistema/microphone-sensitivity-low-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/microphone-sensitivity-low-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `4ee42b351d78808ca1f16056997df36d7d30f470a12fe8f3710a14718c0f854f` |
| `icones/sistema/microphone-sensitivity-medium-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/microphone-sensitivity-medium-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `5ad7c25449c8a03dfb5d9039b46c3165f0f9e4d005fb27e20961fe927dda1dc1` |
| `icones/sistema/microphone-sensitivity-muted-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/microphone-sensitivity-muted-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `d5b374f03b313766e6cf220c0e0cacab74ef2e220a59f2d88ab3d6882c257f26` |
| `icones/sistema/multimedia-player-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/multimedia-player-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `32ce15c5a397f7c3d33b403f36ad45de136496b0538fccbe80ccc81edb963017` |
| `icones/sistema/multimedia-volume-control-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/apps/multimedia-volume-control-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `595a5b9dcd57d699062ab73eb7cfc3364d1345d7ea94f3c3af5cacf492dcbdce` |
| `icones/sistema/network-vpn-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/network-vpn-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `06ac63a1095074bc3199170cb7a2e5b3f004c93c04551164bc6de9a5c8032022` |
| `icones/sistema/network-wired-disconnected-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/network-wired-disconnected-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `c418113802324ef1f9673525c3483a394be305fe576b9c5c0714c683307f86ac` |
| `icones/sistema/network-wired-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/network-wired-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `6ee420e9f4b99b1105a85b336e0d46e233d9aed401d8ba0df0574e035d02f5de` |
| `icones/sistema/network-wireless-acquiring-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/network-wireless-acquiring-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `2e46293988d2fd79db6811032f66736eb6194c7c4b3ca447dbdb5c73c1502378` |
| `icones/sistema/network-wireless-disconnected-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/network-wireless-disconnected-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `af965ed38ac7e86780eae7bc7c486de968aa78268ce045c380acf7f55211c771` |
| `icones/sistema/network-wireless-error-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/network-wireless-error-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `7e4163ada1c97cadf0d4026884d4b2fcd456e9c5dd17ec2dec4d5707928a4e21` |
| `icones/sistema/network-wireless-signal-excellent-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/network-wireless-signal-excellent-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `842841c699661e7595e88c022af17f280983a262b1ebdff3625064a9c00db99c` |
| `icones/sistema/network-wireless-signal-good-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/network-wireless-signal-good-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `455dcd093a0c7373bc6316bb8669fbe1783c16d99b31c2a31139e3be0ac16c9f` |
| `icones/sistema/network-wireless-signal-none-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/network-wireless-signal-none-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `0bea784560bc25d3bf78f57079833a9328562b4ed0d9a3efad258842753ac066` |
| `icones/sistema/network-wireless-signal-ok-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/network-wireless-signal-ok-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `5d16a4fc0e81d61094f18d4695bcfc8a99b1b9ad09ef5b3ec6802fa691fc3f00` |
| `icones/sistema/network-wireless-signal-weak-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/network-wireless-signal-weak-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `1c50b96ecb6c8109bf3c4a2c2b87f7d2bc9119803f3ea6fcf71deecf8c498532` |
| `icones/sistema/network-wireless-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/network-wireless-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `53fa9ab91f55d59f8c8da7553529bb40c4e174c637f37ffab6ba09994a33c958` |
| `icones/sistema/notification-disabled-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/notification-disabled-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `65b174839c1daf1913e2dd289a39f5239d0ca05f8e12926dffd374b5de941ce6` |
| `icones/sistema/notification-new-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/notification-new-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `7e0248535b224ca0dadcc6ce63630db27197d7253180c6a3c6b0962fc5c8377e` |
| `icones/sistema/notification-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/notification-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `58344b8c0d5d42a7dd4e8524af9f5078124a48e298cc8abc7736863ccb2a3706` |
| `icones/sistema/object-select-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/object-select-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `796b711f5c7052ca3bea020fa70f86fe5247c956b14fbbec9d2c69782a5cd9e0` |
| `icones/sistema/pan-down-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/pan-down-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `e207a049829a6bcbd25c8eb22f5f5156a5f1ea66eec330eb0f5ffa9a3d3aa53d` |
| `icones/sistema/pan-up-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/pan-up-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `43b972e6cc3f4c893e116f81e8b715ec5216021dfec1ca1a6fc6d1685365218e` |
| `icones/sistema/preferences-color-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/apps/preferences-color-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `8ec586903ed2cfd9a1068ef3ea20fb0663cda99a93293e08f298ce03e7e8d38d` |
| `icones/sistema/preferences-desktop-accessibility-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/apps/preferences-desktop-accessibility-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `4ace7f5769c2b681e1c483f459e23c19c3cea8db5a0dea70991cc29a975481ed` |
| `icones/sistema/preferences-desktop-apps-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/apps/preferences-desktop-apps-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `1d46e16d83bb802ce9d8b2dea86dd46e96a9f5885d5e68ee4c5c1924fe7c495d` |
| `icones/sistema/preferences-desktop-default-applications-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/apps/preferences-desktop-default-applications-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `d466204fdb5677fae160ccf3757be4909893f3f845c6927866cd099697af7b8d` |
| `icones/sistema/preferences-desktop-display-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/apps/preferences-desktop-display-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `91653fce8daea352987719a8720ff8736ec10c997ed9b9f6b6ebc6251707668a` |
| `icones/sistema/preferences-desktop-keyboard-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/apps/preferences-desktop-keyboard-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `3c237a767db9bb4e3703b77ff3d2a4b3aca49f370c1e43746d0ee7c661b326a9` |
| `icones/sistema/preferences-desktop-locale-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/apps/preferences-desktop-locale-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `c59141e24b2c4adc3b7743753ab479fd660a92a67e8a0619ba0ec18b2b68d08d` |
| `icones/sistema/preferences-desktop-wallpaper-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/apps/preferences-desktop-wallpaper-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `a935e775a5917213bd046a078711a2eb2da6adbb24a0b31dfcda9f9031df0743` |
| `icones/sistema/preferences-system-network-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/apps/preferences-system-network-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `129a8b64cbbb32678e0662fc35ebe33d144ee8e289803ae10f14d3e82968fc64` |
| `icones/sistema/preferences-system-time-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/apps/preferences-system-time-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `73c38cdbaa92c3c6c89dc5dfd6a752468ebc5b90c37028315df7bb0c31ed44c7` |
| `icones/sistema/preferences-ubuntu-panel-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/apps/preferences-ubuntu-panel-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `4a487c8e36dc5cd218726113fea0c7103efe6cb96a25bd866e807fd328049b75` |
| `icones/sistema/preferences-workspaces-symbolic.svg` | desenho deste projeto (P131), no preenchido de 16 px do `m4thewz/dracula-icons` |  | GPL-3.0 | 2026-10-27 | `c642884cc9521ad136065e353f3891ca5fcf034c91af1e358f51533699b25698` |
| `icones/sistema/printer-network-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/printer-network-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `d6c86694344bd18c71a8f56fe3891a1f57c4fb5438e57564fd9abc52e84c2588` |
| `icones/sistema/scanner-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/scanner-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `cf51c8cb7eae4138e4f4d5614fde7e68fbb5a66115e5157f671444c993d8f1f0` |
| `icones/sistema/sidebar-hide-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/sidebar-hide-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `c4de3b7fe4b1c7762c3c0db7533a3cb3b2069d6a3c3a2bf9cc4e067e6e52f6b3` |
| `icones/sistema/sidebar-show-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/sidebar-show-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `0f6a272fac5f7c247303ff8101f8ee7ee6aef43035134bdeaf540e132568f380` |
| `icones/sistema/smartphone-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/smartphone-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `b58494211cf223b9c41fc9625309f32dc48cb84740df1698c9e5c7dd9a2d2037` |
| `icones/sistema/starred-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/starred-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `36719f25b6c3a65b8963726d6cbb8f4e38bd05455cdd7f5f0fa6abc70f76cdfd` |
| `icones/sistema/system-lock-screen-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/system-lock-screen-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `4b183048c5f29b555d13d4570a5719e38f13d695deffab774302d489fbf53748` |
| `icones/sistema/system-log-out-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/system-log-out-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `9df137e5dd72c406ac8450fb452cee4e074abacce3977c11bd3918d51eb70533` |
| `icones/sistema/system-reboot-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/system-reboot-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `03b46b24b12a44c8855ab4a0bdd30623d2ed2923af378345e18536339a2a7534` |
| `icones/sistema/system-restart-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/system-restart-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `03b46b24b12a44c8855ab4a0bdd30623d2ed2923af378345e18536339a2a7534` |
| `icones/sistema/system-run-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/system-run-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `7538991e557af0f9b908395ba89fe406f866353a4922fb066f51c53e8cbc442b` |
| `icones/sistema/system-search-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/system-search-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `c40c5298e9af676a36ea4233262713b5770adfea374537351c820b3e82201146` |
| `icones/sistema/system-shutdown-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/system-shutdown-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `e7e1788dcb08b1cb482f0f9c107cd11c6c8cafee6dcd0c9d711409a5e959b1b4` |
| `icones/sistema/system-suspend-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/system-suspend-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `5911dc935dae87be9bf5ab9bf553bae3f8af13568a7c18cb47ac2f95030a45ef` |
| `icones/sistema/system-users-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/apps/system-users-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `dd046abe9ea3d9e111da6aeb88f9942e8972d14166b8bb9f5499554f67f1d6e5` |
| `icones/sistema/tablet-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/tablet-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `27b74854c38b5cba694782acaa0b7dae65c34434900fba0fc979fb688c44dde0` |
| `icones/sistema/text-x-generic-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/mimetypes/text-x-generic-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `e6d19122a195ad3d1348116b9352fe12393e74090310bdcaa0d701192586ce1e` |
| `icones/sistema/touchpad-disabled-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/status/touchpad-disabled-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `104bfadcec4e0fdb1d98e61168a948328dc4e1f6b9f20b12aca30ddc755a3038` |
| `icones/sistema/uninterruptible-power-supply-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/uninterruptible-power-supply-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `df7f3f0d19f7bef6d4cfb98a80419396c5bfa9042e81f7973416f012ea2d146f` |
| `icones/sistema/user-home-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/places/user-home-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `d39ed34292bc0096b299f4573071427c3b4c5630321af242fd5d1bb31c6b7232` |
| `icones/sistema/video-display-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/devices/video-display-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `52e94e8322c2d5ab657ac554f8d6ae097cc816b9e9e2e3bf21586c68b24a2ae4` |
| `icones/sistema/video-x-generic-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/mimetypes/video-x-generic-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `112014f870b199f5b4cfbc6e3966b1f4a4359d8c705e9c456e33cb49c0d4714c` |
| `icones/sistema/view-more-horizontal-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/view-more-horizontal-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `2076409156706fa7a16307ff544a69db69bf92009da1f9121ddfe1ad7937ff9c` |
| `icones/sistema/view-more-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/view-more-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `76601aa8aa97718fefe320139d9aa8877cc254851d644f0daa2a3f1175659207` |
| `icones/sistema/view-refresh-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/view-refresh-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `03bd25f8103d6e514d7ad5af1cc1165a349e4471c0e91642fb83eba2696991c1` |
| `icones/sistema/window-close-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/window-close-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `3abaeca92cd54b0d7cf89444a3eabd2b74b616350906beed45777f2ccdba6e59` |
| `icones/sistema/window-maximize-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/window-maximize-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `38bda23cb1edf46349ea50e898e3f2bb696f4acf7e036b0794d778ba2eb6fa1d` |
| `icones/sistema/window-minimize-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/window-minimize-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `e574ba3b90c04167016153942e3efe00c2784bbf4d3851d58c2040ef9833d0de` |
| `icones/sistema/window-pop-out-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/window-pop-out-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `73ae00d7387848fab046ad1dfd2a8ef044c70ea5945abdd626253b8f17fb36ba` |
| `icones/sistema/window-restore-symbolic.svg` | `m4thewz/dracula-icons`, ramo `circle` (`00a230a2`) — `symbolic/actions/window-restore-symbolic.svg`, a cor trocada por `currentColor` |  | GPL-3.0 | 2026-10-27 | `351da04bb5acb39b380517da1f350166fc472fc5ce7c3272db4a642a9f3f5613` |

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

## Os temas de aplicativo — 24/09/2026, sprint P42

Cinco modelos em `apps/`, um por aplicativo, declarados no bloco `apps` do
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
| `scripts/temas-de-apps/kitty/kitty.modelo.conf` | `dracula/kitty` (github.com/dracula/kitty), pela cópia em `Dracula_OS-Theme/app-themes/kitty/current-theme.conf` | MIT | 2026-09-24 | As 36 cores viraram papel. Com o flavor `dracula`, 30 saem iguais às de lá; as 6 sem slot na paleta (verde, amarelo, magenta e ciano brilhantes, branco brilhante e branco da seleção) caem no vizinho. |
| `scripts/temas-de-apps/gnome-terminal/gnome-terminal.modelo.dconf` | desenho deste projeto, na ordem do modelo do kitty | GPL-3.0 | 2026-09-24 | Nada foi copiado. O perfil que a origem tinha (`app-themes/gnome-terminal/dracula-profile.dconf`) chama-se "Dracula" e não é: fundo rgb(42,44,57), texto verde rgb(146,181,156), e nenhuma das dezesseis cores da paleta dele é do tema. |
| `scripts/temas-de-apps/telegram/telegram.modelo.tdesktop-theme` | `dracula/telegram` v0.1.3, de Neil Smith e colaboradores (github.com/dracula/telegram), pela cópia em `Dracula_OS-Theme/app-themes/telegram/dracula.tdesktop-theme` | MIT | 2026-09-24 | Os 51 hex viraram papel; o cabeçalho de créditos ficou como veio. |
| `scripts/temas-de-apps/discord/discord.modelo.theme.css` | o tema Dracula do CtorW para Vesktop e Vencord (github.com/CtorW/Vesktop-Discord), sobre o `midnight` do refact0r, pela cópia em `Dracula_OS-Theme/app-themes/discord-betterdiscord/Dracula.theme.css` | MIT | 2026-09-24 | Os 40 hex viraram papel, e o `@name` ganhou o nome do flavor e "(MeowSystem)". O `@import` do midnight ficou: o tema é um punhado de variáveis sobre ele, e não existe sem ele. |
| `scripts/temas-de-apps/onlyoffice/onlyoffice.modelo.json` | os NOMES das 125 chaves de um tema de interface que esta máquina tinha em `uithemes/` (`dracula_only_office.json`, id `theme-dracula-dark-ajustado-2`, de 12/08/2025) | a origem não declara nenhuma — ver abaixo | 2026-09-24 | Todo valor virou papel, inclusive os que não eram Dracula (o texto normal em #00988C, as abas em #333). |
| `scripts/temas-de-apps/zapzap/zapzap.modelo.css` | os NOMES das variáveis `--WDS-*` do WhatsApp Web e o papel de cada uma, do WhatsApp Web Catppuccin (github.com/catppuccin/userstyles, `styles/whatsapp-web/catppuccin.user.less`, commit `04413649`, 16/08/2026, sha256 `6430e9db…`), conferidos com o WhatsApp Web Dracula (github.com/dracula/whatsapp-web, `whatsapp-web-dracula.user.css`, commit `5b4f4faf`, 13/08/2026, sha256 `de0345d7…`) | MIT (os dois) | 2026-10-24 | Entrou na P106 (o sexto modelo). Nenhum valor foi copiado: os dois são LESS/CSS com a cor escrita, e aqui cada variável recebe um papel (o mesmo do de lá: `mantle` no fundo, `base` na caixa de texto e no balão que chega, `crust` no papel de parede). O acento é o `green`, como no do Dracula; o balão que sai é `color-mix` de 20% do acento sobre o `base`, como no outro. Ficaram de fora as classes ofuscadas que o do Dracula usa (`.xfmqtgv`, `.x1wb366y`), que mudam a cada versão do site. |

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
ligadas (I7 de `docs/sprints/2026-10-09-uso-real/01-regressoes.md`, na branch `arquivo`; o pedido de
16/09 era «que os agentes gerem as demais variações de pastas»). Entraram como
desenho deste projeto, com o corpo das sete path a path (as costas no
`surface0`, a frente no `surface1`) e o símbolo na paleta do flavor `dracula`:

| arquivo | desenho de | licença | desde | o símbolo |
|---|---|---|---|---|
| `icones/sistema/folder.svg` | desenho deste projeto | GPL-3.0 | 2026-10-09 | nenhum: é a pasta comum, só o corpo |
| `icones/sistema/user-desktop.svg` | desenho deste projeto | GPL-3.0 | 2026-10-09 | o monitor, a tela no `sky` `#8BE9FD` e a moldura no `text` `#F8F8F2` |
| `icones/apps/discord-b.svg` | manuais-final (a arte do Dracula feita à mão, entregue em 23/10/2026); fonte: P96 |  | GPL-3.0 | 2026-10-23 | `ed90ae11fb78d1eace76f8348ace3b36b9e2b57873afc03ee52254d0d7dacdb6` |
| `icones/apps/org.gnome.Nautilus.svg` | manuais-final (a arte do Dracula feita à mão, entregue em 23/10/2026); fonte: P96 |  | GPL-3.0 | 2026-10-23 | `83d560953d1e340d9912a8fba54c20d8c5e6e746750a840608b7373cc83dc3b2` |
| `icones/sistema/user-home.svg` | manuais-final (a arte do Dracula feita à mão, entregue em 23/10/2026); fonte: P96 |  | GPL-3.0 | 2026-10-23 | `a5940e7d51f303ce2155e85b821a882dce48601965d851a8b42e727229c04705` |
| `icones/biblioteca/discord-c.svg` | rascunho de `.trabalho-icones/svg/`, escolhido por quem usa em 23/10/2026; fonte: P96 |  | GPL-3.0 | 2026-10-23 | `a95a5d3627d5a52e75df661d6bd91298028b6ef98cd316c0c8fe747fb236789e` |
| `icones/biblioteca/guvcview-2.svg` | manuais-final (a arte do Dracula feita à mão, entregue em 23/10/2026); fonte: P96 |  | GPL-3.0 | 2026-10-23 | `0837663a400537c5b16267dbcc93449ba6a0e2e1ff1921883e499e99c358fd86` |
| `icones/apps/com.beholder.app.svg` | manuais-final (a arte do Dracula feita à mão, entregue em 23/10/2026); fonte: P96 |  | GPL-3.0 | 2026-10-23 | `628f8875287e7df8738676b75f6a5a9efaecc294871745ef5b58b2a28abf29b3` |
| `icones/apps/elden-ring-tracker.svg` | manuais-final (a arte do Dracula feita à mão, entregue em 23/10/2026); fonte: P96 |  | GPL-3.0 | 2026-10-23 | `563321f7fbe82ccaa61cc189b609cd6dc7c0ccb37c4f702f0770f0da0559a7d4` |
| `icones/apps/protocolo-ouroboros.svg` | manuais-final (a arte do Dracula feita à mão, entregue em 23/10/2026); fonte: P96 |  | GPL-3.0 | 2026-10-23 | `6ea6504d3c3a23826fd38ca9f0a8f6224feecb20c35c43daad70d7aa6e3fe9e3` |
| `icones/biblioteca/md.obsidian.Obsidian.svg` | antes em `icones/apps/resgatados/md.obsidian.Obsidian.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `34c59583036f62791019fe541256187b86eca7d189be4095fe07cd489218bf8f` |
| `icones/biblioteca/mozc.svg` | antes em `icones/apps/resgatados/mozc.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `1aa34d54a761057283bf8f47d13f11df61ee883486c38d22f8484951614ba779` |
| `icones/biblioteca/org.telegram.desktop.svg` | antes em `icones/apps/resgatados/org.telegram.desktop.svg`; uma versão por ícone, P96 (23/10/2026) |  | GPL-3.0 | 2026-10-23 | `0cb159785c0a08c35992095f7a545b6ff02200bc58b4da149c0f19e25f16f9a4` |

**O que ficou fora da paleta, dito para não parecer esquecido.** No
`folder-download.svg`, o castelo (`#423E4D`, a 0,0222 do `surface0`) e a lua
(`#DDA442`, a 0,0829 do `peach`) não são o corpo, e não mudaram. Com a frente no
`surface1`, o castelo ficou a 1,13:1 dela, onde estava a 1,26:1.

**O resgate do Nautilus foi junto — 25/09/2026, sprint P65.** A tabela acima
dizia «nada mais no desenho mudou», e as aberturas do castelo tinham mudado
com a frente; a frase agora as conta. E o mesmo desenho mora fora deste pack:
`assets/icones/resgatados/org.gnome.Nautilus.svg` é o `folder-download.svg` de
antes da P61 sem a seta — o corpo, a lua, o castelo e as aberturas, path a path,
conferido por `diff` —, e seguia com o `#433F4D` e o `#534B62`. Passou aos mesmos
dois slots, pela mesma medida: as costas no `surface0`, a frente e as aberturas
no `surface1`; o castelo e a lua ficaram, como aqui. O resgate é decalque de um
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

O `sincronizar` procura a **primeira tabela** cujo cabeçalho tenha as colunas
`arquivo`, `lido de` e `sha256`, e lê cada linha até a tabela acabar. A ordem
das colunas não importa; o nome delas, sim.

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

As crases em volta de cada campo são enfeite para quem lê, e o leitor as tira.

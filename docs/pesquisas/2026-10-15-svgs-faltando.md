# SVGs que faltam no pack Dracula: as quatro varreduras juntas

Data: 15/10/2026. Pesquisa sem commit. Junta as frentes disco, histórico, uso e temas instalados, tira as
duplicatas pelo sha256 e compara tudo com o que o MeowSystem já tem. A frente de recuperação de arquivos
apagados tem relatório próprio: `docs/pesquisas/2026-10-15-svgs-recuperados.md`.

## Resposta curta

1. **Quase nenhum desenho nosso se perdeu de vez.** Três existem só fora do MeowSystem:
   - o **uad-ng** dela (Android no anel);
   - o **Ubuntu** dela (logo com o cubo do distrobox);
   - o **aurora-iniciar** (04/08).

   Os dois primeiros têm o PNG no `Dracula_OS-Theme/src/icons/projects/` e o vetor de 12/09 só no histórico
   do git. Em 15/09 o motor trocou os dois por desenhos novos.
2. **A falta que se sente é de outra coisa: 19 desenhos Dracula nossos estão no motor e nunca foram para o
   pack.** Moram em `assets/icones/resgatados/` e `assets/gatos/`.
   - 12 não têm nenhum par no pack: uad-ng, Ubuntu, Citrix, câmera, mozc, setup-mozc, Obsidian, Telegram,
     Thunderbird, scrcpy, morcego-noite e morcego-dia.
   - 7 são vetores de um PNG que o pack tem: Clapper, Edge, Nautilus, WhatsApp, PhotoGIMP, Waterfox e morcego.

   13 deles estão em uso hoje, mas pelo motor: 10 no tema de ícones e os 3 morcegos como logo do COSMIC. O `apps.map` do pack ainda marca 5 com «?»: uad-ng,
   Citrix, Clapper, Edge e WhatsApp.
3. **33 ligações antigas de nome para desenho sumiram, mas o desenho continua no pack.** São Discord, Spotify,
   Opera, Gradia, os 11 nomes do Citrix, os 3 das extensões e 13 mimetypes (shell, markdown, `.desktop`).
   Outras 7 mudaram de desenho: appcenter, menu-editor, menulibre, onlyoffice ×2, gThumb e stacer. O desenho
   está em `feitos-a-mao/` ou `biblioteca/`, e nenhuma linha do `apps.map` aponta para `feitos-a-mao/`.
4. **O resto é ruído.** 26.740 arquivos são de terceiros, 4.622 são rascunho, render ou versão antiga, e 1.201
   são de projeto pessoal ou dela. 24.414 já estão no MeowSystem.

## Como foi medido

- **Entradas:** `disco.tsv`, `historico.tsv`, `temas-instalados.tsv` e `uso.tsv`, todos no scratchpad
  `svgs/`. São 167.600 linhas e **56.998 arquivos distintos por sha256**. O `uso.tsv` tem ainda 57 citações
  de arquivos que não existem mais. Ficaram fora da conta porque não há o que comparar.
- **Referência:** 27.362 arquivos do MeowSystem:
  - `packs/**` (Dracula e Catppuccin);
  - `assets/**` em disco, com `upstream/` e `gatos/`;
  - `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/`, os 39 vetores de hoje;
  - o `HEAD` do `folder-download.svg`, que está modificado sem commit.
- **«Já no MeowSystem»** quer dizer uma destas três coisas:
  - sha256 igual;
  - texto igual ignorando espaços e quebras de linha;
  - RMSE ≤ 0,004 a 64 px (render com `rsvg-convert`, composto sobre cinza 50%).

  Um PNG com RMSE ≤ 0,03 contra o MeowSystem é tratado como exportação.
- **Classe (b):** RMSE ≤ 0,10, ou ≤ 0,15 quando o nome é o mesmo. É a calibração do relatório de recuperação:
  - edição do mesmo desenho dá de 0,005 a 0,10;
  - desenhos diferentes dão acima de 0,16.
- **Tamanhos:** PNG de 16 a 64 px de um ícone que também existe maior na mesma raiz conta como exportação do
  maior.
- **Árbitro entre versões:** o do `.trabalho-icones/BRIEFING.md`, ou seja, o RMSE do vetor contra o PNG
  original do pack. Mais novo não quer dizer melhor.
- **Conferência a olho:** os casos duvidosos (ibus, Snapcraft, Mint, hplj1020, os pares uad-ng, Ubuntu e
  Citrix) foram vistos numa folha e corrigidos à mão. A regra de cada ajuste está em `cons/final.py`.

## Contagem por classe (arquivos únicos por sha256)

| classe | arquivos | o que é |
|---|---|---|
| já no MeowSystem | 24.414 | 20.724 iguais ao `assets/icones/upstream` (m4thewz), 3.320 ao pack Catppuccin, 142 ao pack Dracula, 39 aos vetores da P84 e 189 a outras partes do motor (53 a `resgatados/`, 8 a `gatos/`, 47 a `convertidos-apps/`, 73 aos Arcticons, 8 a `autorais/`) |
| **(a) feito por nós, fora do pack** | **7 arquivos fora do MeowSystem + 12 desenhos no motor** | 15 desenhos (tabela abaixo) |
| **(b) versão editada de algo do pack** | **14 arquivos fora do MeowSystem + 7 vetores no motor** | 16 desenhos (tabela abaixo) |
| (c) terceiro sem edição nossa | 26.740 | 19.355 iguais ao m4thewz, ao Papirus ou ao `/usr/share/icons`; 5.283 do SDK do Android, de apps web do Chrome e do Edge, do foundry, do Dracula_Hyper-OS3 e do Segape; 2.024 derivados gerados (pastas recoloridas, simbólicos, `dist/`); 78 marcas, logos e ícones de programa sem prova de autoria (ibus, Snapcraft, distrobox, DaVinci, Mint, bauh, apps web) |
| (d) projeto pessoal ou dela | 1.201 | 232 da lista de exclusão (Ouroboros, Caldeirão, Elden Ring, Beholder, Nyx); 852 de projetos dela que **não** estão na lista (decisão pendente, ver abaixo); 112 do próprio repositório de cada projeto; 5 da recuperação |
| (e) lixo, rascunho ou derivado | 4.622 | 3.781 renders da oficina, relatórios e testes; 760 tamanhos menores de um ícone que existe maior; 69 versões antigas substituídas no próprio MeowSystem (Catppuccin e traço `currentColor`); 12 outros (origem da oficina, logo da doc, blob Qt) |

A tabela por arquivo está em `svgs/consolidado.tsv` (56.998 linhas) e a das classes a e b em
`svgs/consolidado-ab.tsv`. Os dois ficam no scratchpad da sessão.

## (a) Feito por nós e sem par no pack Dracula

O RMSE desta tabela é contra o desenho que o pack usa no lugar. Acima de 0,16 quer dizer outro desenho.

| desenho | onde está | sha256 | prova de autoria | o que o pack tem | qual entra |
|---|---|---|---|---|---|
| uad-ng (celular com apps) | `assets/icones/resgatados/uad-ng.svg` | `2169d5bc` | commit `5aee691` (15/09), «os vinte desenhos do Dracula»; na transcrição, pedido de ícone novo | nada (`uad-ng : ?`) | este, em `apps/`, com a linha no `apps.map`. O tema já veste este |
| Ubuntu (maleta de terminal) | `assets/icones/resgatados/Ubuntu.svg` | `e5f77c53` | `5aee691`; na transcrição, ícone novo do «Ubuntu (container)» | nada | este, em `apps/`. O tema já veste |
| Citrix (monitor) | `assets/icones/resgatados/Ubuntu-selfservice.svg` | `0b0325af` | `5aee691`; na transcrição, ícone novo do Citrix | `feitos-a-mao/citrix.png`, que é outro desenho (0,227) | este, em `apps/`. O tema já veste |
| câmera do COSMIC | `assets/icones/resgatados/io.github.cosmic_utils.camera.svg` | `58623773` | `5aee691` | ligada ao `apps/guvcview.svg` (0,328) | `biblioteca/`. A ligação de hoje fica até quem usa escolher |
| mozc | `assets/icones/resgatados/mozc.svg` | `1aa34d54` | `5aee691`; «Desenhe um ícone NOVO para Mozc», 5 gravações e crítica a 24 px | nada | `biblioteca/` |
| setup-mozc | `assets/icones/resgatados/setup-mozc.svg` | `195e1365` | `8b37812` (12/09) | `biblioteca/tarot.svg` [override-novo] (0,338) | `biblioteca/`. O tarot foi escolha registrada e fica |
| Obsidian (pedra facetada) | `assets/icones/resgatados/md.obsidian.Obsidian.svg` | `34c59583` | `5aee691`, transcrição de 16/09 | `apps/md.obsidian.Obsidian.svg` [alias-heurístico] (0,188) | `biblioteca/` |
| Telegram (avião de papel) | `assets/icones/resgatados/org.telegram.desktop.svg` | `0cb15978` | `5aee691`, transcrição de 16/09 | `apps/org.telegram.desktop.svg` [alias-heurístico] (0,318) | `biblioteca/` |
| Thunderbird ESR | `assets/icones/resgatados/org.mozilla.thunderbird_esr.svg` | `a2f6d734` | `fb91400` (12/09) | nada | `apps/`. O tema já veste |
| scrcpy | `assets/icones/resgatados/scrcpy.svg` | `fa095045` | `8b37812` (12/09) | nada | `apps/`. O tema já veste |
| morcego-noite | `assets/gatos/morcego-noite.svg` | `8cdb449c` | `5aee691`; «redesenhe em SVG o morcego». É o logo do COSMIC hoje | nada | `biblioteca/` (é logo, não ícone de programa) |
| morcego-dia | `assets/gatos/morcego-dia.svg` | `9db7f510` | `5aee691`; 7 gravações e 2 edições na transcrição de 16/09 | nada | `biblioteca/` |
| **uad-ng dela** (Android no anel) | `~/.local/share/icons/hicolor/512x512/apps/uad-ng.png`, `Dracula_OS-Theme/src/icons/projects/uad-ng.png` e o backup de 24/09 | `ca4edb39` (512 px), `5237c842` (256 px) | Dracula_OS-Theme `32d35ec` (18/08), «arte própria dos projetos no tema» | nada | o vetor de 12/09 (linha abaixo), com o PNG de 512 px como régua |
| uad-ng dela, vetor de 12/09 | só no git: `8b37812:assets/icones/resgatados/uad-ng.svg` | `45c8b16c` | `8b37812`, «os desenhos dela voltam do PNG»; trocado em `5aee691` | nada | `biblioteca/` |
| **Ubuntu dela** (cubo do distrobox) | `~/.local/share/icons/distrobox/ubuntu.png`, `projects/ubuntu-distrobox.png` e o backup | `4e6ca17f`, `a8561527` | Dracula_OS-Theme `30f826c` (16/04) | nada | o vetor de 12/09 (linha abaixo) |
| Ubuntu dela, vetor de 12/09 | só no git: `8b37812:assets/icones/resgatados/Ubuntu.svg` | `4794b778` | `8b37812`; trocado em `5aee691` | nada | `biblioteca/` |
| aurora-iniciar (gato lilás) | só no git: `b178261:uploads/aurora-icone-iniciar.svg` | `c111a96b` | `b178261` (04/08, Vitória). Saiu em `3863139` junto com o «andaime da obra» | nada | **decidir**: entra só se quem usa reconhecer o desenho |

## (b) Versão editada de um desenho que o pack tem

A régua é o RMSE contra o PNG feito à mão do pack. Quem tem o menor ganha o lugar em `apps/`, e o outro vai
para `biblioteca/` (decisão 13: todas as versões).

| desenho | o que falta e onde está | sha256 | prova | par no pack | RMSE contra o PNG do pack | qual entra |
|---|---|---|---|---|---|---|
| Clapper | `assets/icones/resgatados/com.github.rafostar.Clapper.svg` | `bc007546` | `72cc33c` (12/09) | `feitos-a-mao/Clapper.png`, P84 `Clapper.svg` | motor **0,019**, P84 0,052 | o do motor em `apps/` |
| Edge | `assets/icones/resgatados/com.microsoft.Edge.svg` | `30faff0f` | `8b37812` | `edge.png`, P84 `edge.svg` | motor 0,092, P84 **0,073** | o da P84 em `apps/` |
| Nautilus / gnome-folder | `assets/icones/resgatados/org.gnome.Nautilus.svg` | `0b167f56` | `38b9f49` (25/09) | `gnome-folder.png`, P84 `gnome-folder.svg` | motor 0,031, P84 0,028 | empate na prática. O tema veste o do motor, que fica em `apps/` |
| WhatsApp | `assets/icones/resgatados/whatsapp-linux-app.svg` | `2405c02a` | `8b37812` | `whatsapp.png`, P84 `whatsapp.svg` | motor 0,083, P84 **0,049** | o da P84 em `apps/` |
| PhotoGIMP / GIMP | `assets/icones/resgatados/photogimp.svg` | `d2e8a109` | `25a040c` (15/09) | `gimp.png`, P84 `gimp.svg` | motor **0,042**, P84 0,079 | o do motor em `apps/` (photogimp) |
| Waterfox / Firefox | `assets/icones/resgatados/net.waterfox.waterfox.svg` | `2353bb20` | `8b37812` | `firefox.png`, P84 `firefox.svg` | motor **0,048**, P84 0,069 | só `biblioteca/`. A decisão de 23/09 (P28) veste o Waterfox com o Firefox-Dracula |
| morcego | `assets/gatos/morcego.svg` | `1f0aa6a2` | `5aee691`; «redesenhe em SVG o morcego», 16 gravações | `biblioteca/bat.svg` | 0,016 contra o `bat.svg` | `biblioteca/`, ao lado do `bat.svg` |
| Citrix, vetor de 12/09 | só no git: `8b37812:…/Ubuntu-selfservice.svg` | `010b2cf8` | `8b37812`; trocado em `5aee691` | `citrix.png`, P84 `citrix.svg` | 12/09 **0,030**, P84 0,041 | `biblioteca/`. Vence a régua, e a P84 decide se troca o vetor dela |
| hplj1020 em 256 px | backup `Dracula-Icones/256x256/apps/hplj1020.png` | `59e75835` | Dracula-Icones montado pelo Spellbook | `feitos-a-mao/hplj1020.png` tem **45 px**, e a P84 traçou a partir dele | — | `biblioteca/`. É a régua melhor para a P84 traçar de novo |
| 6 pastas de 15/09 (documents, music, pictures, publicshare, templates, videos) | `.trabalho-icones/pastas/` | `28d9edb1`, `52dd06f7`, `9f2d6183`, `9ebece59`, `4586ebcd`, `1fa23c0c` | rascunho de 15 e 16/09, aprovado e versionado | `pastas/folder-*.svg`, recoloridas na P61 (`542b1e1`, 25/09, `#433f4d`→`#383a4c`) | 0,029 a 0,031 | a do pack continua. As de 15/09 vão para `biblioteca/` como versão antiga |
| folder-download, 3 versões | git `5aee691` (15/09), `.trabalho-icones/pastas/` (21/09), `HEAD` `542b1e1` | `efcc83e5`, `9b85dbb2`, `854d8a94` (instalado = `HEAD` sem espaços) | commits nossos e a oficina | `pastas/folder-download.svg`, editado hoje às 21:42 e sem commit (`4a777f1e`) | hoje × 21/09: 0,043; hoje × `HEAD`: 0,112 | a edição de hoje, quando quem usa commitar. As outras vão para `biblioteca/` |
| rascunhos de 15/09 da oficina (Nautilus, photogimp, whatsapp, waterfox) | `.trabalho-icones/svg/` | `606edd09`, `4cab9717`, `f4fe5805`, `f18a0ebc` | oficina, sessão `55ef96a5` | as versões do motor, nas linhas acima | 0,026 a 0,115 contra o motor | `biblioteca/` só se «todas as versões» incluir rascunho. A memória registra que o motor venceu a medição |

## Por que ficaram de fora

1. **Os desenhos foram feitos antes de o pack existir.** Os resgatados foram vetorizados em 12/09
   (`8b37812`) e redesenhados em 15/09 (`5aee691`). Os dois commits gravaram em
   `assets/icones/resgatados/`, e quem instala no tema é o `scripts/icones_resgatados.sh`, pelo
   `assets/icones/apps-resgatados.map`. O pack Dracula só nasceu em 18/09 (`6807e60`).
2. **A criação do pack levou um só mapa.** O `apps.map` do pack nasceu do `apps-dracula.map`, que vem do
   `mapping.json` do Dracula_OS-Theme (Sprint 32 de lá), e esse mapa não conhece os resgatados. A P28 (23/09)
   só trouxe os 4 que o pack precisava vestir: Discord, Spotify, Syncthing e guvcview. A fronteira de 21/09
   («o acervo pode ser do motor», revogada pela decisão 14) deixou o resto onde estava, sem decisão
   explícita.
3. **O redesenho de 15/09 substituiu, em vez de acrescentar.** O `5aee691` gravou por cima dos vetores de
   12/09 de uad-ng, Ubuntu e Citrix, e esses vetores eram fiéis aos PNG dela. Os desenhos dela sobraram só no
   histórico do git, no `Dracula_OS-Theme/src/icons/projects/` e no backup.
4. **As ligações dos feitos à mão não vieram com os arquivos.** O Dracula-Icones do Spellbook ligava por
   nome: `discord.png`, `spotify.png`, `opera.png` e outros. Os PNG entraram no pack em `feitos-a-mao/`, mas
   sem nenhuma linha no `apps.map`. Quando a P37 (23/09) aposentou o `rebuild_dracula_theme()` e o tema
   congelado virou backup (24/09), 33 dessas ligações sumiram e 7 passaram a apontar para outro desenho.
5. **A camada de 48 px encobre o pack.** Em 25/09 entraram em `MeowSystem-Icons/48x48/apps/` 47 Arcticons
   recoloridos. 17 deles encobrem a 48 px o desenho do pack com o mesmo nome: Discord, Spotify, Obsidian,
   Telegram, Steam, Krita, Calculator, Flatseal e outros. Esse dado é da frente «temas instalados» e foi
   conferido por nome.

## Proposta de sprint

A **P87 já existe** (`docs/sprints/2026-10-15-fechamento/P87-tudo-pro-pack.md`), cita este relatório e
roda depois da P88 (três pastas). Esta é a lista que a P87 precisa. **2 agentes**: um implementa, outro confere
e corrige.

1. **Copiar** (trabalho mecânico, vai por script e não por agente). Os 19 do motor, os 5 blobs do git
   (`45c8b16c`, `4794b778`, `010b2cf8`, `efcc83e5` e `c111a96b`, este se aprovado) e o hplj1020 de 256 px do
   backup entram
   em `packs/dracula/icones/apps/` ou `biblioteca/`, como dizem as colunas «qual entra». As 6 pastas de 15/09
   e as versões do folder-download vão para `biblioteca/`. Cada arquivo ganha uma linha no
   `packs/dracula/PROCEDENCIA.md` com:
   - `arquivo`;
   - `de onde` (commit e caminho);
   - `lido de` (`motor:assets/icones/resgatados/…` enquanto a P88 não mover o motor, e vazio para blob e
     backup);
   - licença: deste projeto, ou GPL-3.0 quando o desenho veio do Dracula_OS-Theme;
   - `copiado em`;
   - `sha256`.
2. **Ligar.** No `apps.map`, as 5 linhas com «?» passam a apontar para os desenhos acima: uad-ng,
   Ubuntu-selfservice, com.github.rafostar.Clapper, com.microsoft.Edge e whatsapp-linux-app. Entram também
   Ubuntu, thunderbird_esr, scrcpy, photogimp e org.gnome.Nautilus, que o tema já veste pelo motor. E voltam
   as 33 ligações perdidas, que apontam para os vetores da P84 quando eles estiverem no `dev`: discord,
   spotify, opera, gradia, Citrix ×11, extensões ×3 e os mimetypes de shell, markdown e `.desktop`. Câmera,
   Obsidian, Telegram e setup-mozc **não mudam de ligação** sem a palavra de quem usa (regra 3 da P87).
3. **Avisar a P88.** Os 19 resgatados e gatos têm cor Dracula fixa (de 4 a 8 cores). Se forem para o
   pack-base `meowsystem`, o Catppuccin herda desenho Dracula. Eles precisam ir para `packs/dracula`, não
   para a base.
4. **Prova.**
   - Conta por sha256: (a + b aprovados) − pack = 0.
   - Os testes `tests/pack.sh`, `tests/pack-malicioso.sh`, `tests/fonte-unica.sh` e
     `tests/acervo-da-ficha.sh` passam.
   - `meow pack sincronizar dracula` não acusa divergência.
   - A folha de contato do que entrou bate com `classe-a.png` e `classe-b.png`.

## Para quem usa decidir

1. **Projetos dela fora da lista de exclusão:** Hefesto, Sigilo, Luna, PDForge, Crononauta, QR-Code-Void,
   Êxtase, Mnemo, Neurosonancy, FogStripper, Doppelgänger e ArcaneTab. A lista explícita é Beholder, Elden Ring
   Tracker, Nyx, Ouroboros e Caldeirão. **Já há precedente de projeto dela dentro do pack:**
   `autorais/hefesto-dracula.svg` e `autorais/fogstripper-dracula.svg`. O motor também tem redesenhos Dracula
   de Sigilo, Luna, PDForge, Crononauta, QR-Code e Êxtase, e o tema veste esses redesenhos hoje. Folha:
   `classe-d-pendente.png`.
2. **aurora-iniciar:** é um desenho seu de 04/08, e saiu do repositório junto com a pasta `uploads/`. Volta?
3. **Desenhos dela trocados em 15/09:** o uad-ng e o Ubuntu foram substituídos por desenhos novos que você
   pediu. O desenho dela vai para `biblioteca/` e o novo continua no `apps/`, ou o contrário?
4. **folder-download:** a edição de hoje, ainda sem commit, está mais perto da versão de 21/09 da oficina
   (0,043) do que do `HEAD` (0,112). É essa que vale?

## O que não deu para comparar

- **57 arquivos citados que não existem mais**, todos da frente uso. Exemplos: `ghostwritter2.svg`, que
  aparece 18 vezes no zsh de jan/2026, e `gato-pop.svg`. Não há conteúdo para medir.
- **O Apate e a partição do Windows**, que não estão montados.
- **Os temas `MeowSystem-Icons-Base` e `Base-2`.** Conferem 100% com o m4thewz, segundo a frente «temas
  instalados», e por isso entraram em (c).

## Folhas de contato

Ficam em `.playwright-mcp/ux-svg/`, e cada uma foi olhada:
- `classe-a.png`: os 17 itens da tabela (a);
- `classe-b.png`: um trio por desenho, com o que falta, o PNG do pack (régua) e o vetor da P84;
- `classe-c.png`, `classe-d.png` e `classe-e.png`: amostras de 96, 64 e 96 arquivos, até 12 ou 16 por motivo;
- `classe-d-pendente.png`: um desenho por projeto dela fora da lista de exclusão.

Scripts: `cons/{ref,cand,vis,classifica,final,folhas}.py` no scratchpad `svgs/` da sessão.

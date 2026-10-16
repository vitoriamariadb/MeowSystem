# P82 — Os abertos da leva G, conferidos no código de hoje e fechados

**Branch:** `sprint/p82` (a partir do `dev` em `c338172`, com a leva G inteira) · **Fonte:**
`00-abertos-brutos.md` (as seções «Aberto», «Achados para a próxima leva» e «Estado da execução»
de 09 e 10/10) · **Pedido de quem usa (15/10):** «pode cuidar de tudo isso? … concluirmos as sprints
e afins pra fecharmos o projeto em definitivo».

Cada item do bruto foi conferido no código atual, com `grep` e arquivo:linha, e caiu numa classe só.

| classe | quantos | onde |
|---|---|---|
| CONSERTAR (entra na P82) | 39 itens | «A lista fechada» |
| RESOLVIDO (com prova) | 36 linhas | «Resolvidos» |
| DECISÃO tomada aqui | 37 (19 viram conserto, 18 fecham sem código) | «Decisões» |
| DA P81 | 13 | «De outros blocos» |
| DA P83 | 3 | «De outros blocos» |
| DA P84 | 5 | «De outros blocos» |
| De quem usa | 1 (o `NOPASSWD: ALL`) | «O que fica com quem usa» |

Siglas das fontes: **O1** `03-integracao-onda-1.md` Aberto · **O2** `04-integracao-onda-2.md`
Aberto · **O2·P79** a seção P79 do mesmo arquivo · **I80** `05-integracao-p80.md` Aberto ·
**P7x-E/A** o «Estado da execução» ou os «Achados» da spec P7x · **S80** a spec P80, itens 6 a 10.

Regras desta sprint (as da leva H): HOME temporário em todo teste, falsos que RECUSAM escrita no
PATH, sem barramento da sessão; nada compila nem escreve com o HOME real enquanto o build do
compositor roda; o pack é dado, nunca código; o doctor corrige e a interface mostra.

---

## A lista fechada (CONSERTAR), por área

### Área 1 — Nada manda digitar (scripts e doctor)

**1. As linhas que ainda mandam digitar** (I80 4, P75-A frases, O2·P79 3)
- *Medido:* `scripts/painel.sh:263,268` («arme o supervisor… `systemctl --user start`»);
  `scripts/construir_icones.sh:1157` («diagnóstico: `meow painel estado`»);
  `scripts/midia_build.sh:198` («instale com rustup e rode o install.sh de novo») e `:239`
  («veja o motivo: `CARGO_TARGET_DIR=… cargo build`»); `scripts/leitura_build.sh:473`
  («veja o motivo com:»); `lib/preflight.sh:212` (`sudo apt install …`) e `:227` (`rustup
  toolchain install`); `bin/meow:453` («importe … pela GUI e rode: `meow tema capturar`») e
  `:3828`; `scripts/aplicar_tema.sh:675`; `scripts/greeter.sh:184,289`; `bin/meow:2624` e
  `install.sh:1636` (`sudo -l`); `scripts/wallpaper.sh:1530` («adicione com: `meow wallpaper
  adicionar`»).
- *Causa:* a P79 e a P80 curaram as linhas que o QA viu no painel; estas saem do terminal, do log e
  do doctor, e o `tests/nada-manda-digitar.sh` não as lista.
- *Cura na origem:* cada linha vira a ação feita ou o estado.
  - O `midia_build.sh` instala o rust pela mesma função do `leitura_build.sh:385-397`.
  - O `painel.sh` arma o supervisor ele mesmo.
  - O `preflight.sh` deixa o `install.sh` instalar a base pela ponte e o rust pelo rustup. A recusa
    de rodar como root (`:28-34`) fica: ela fala antes de existir qualquer coisa a fazer.
  - O resto vira estado sem receita.
  - O `wallpaper.sh` com menos de 2 imagens sai como pulado de rotina: a galeria já tem o
    «Adicionar».
- *Prova:* o `tests/nada-manda-digitar.sh` ganha a varredura destas formas («rode», «instale com»,
  «veja o motivo», «adicione com», `sudo -l`, `systemctl --user start`, `meow <verbo>` dentro de
  `meow_info`/`meow_aviso`/`echo`). Vermelho antes, verde depois. A recusa de root e as linhas do
  `files_menu.sh` (P81) ficam isentas, cada uma pelo nome.

**2. O starship é opcional, e o botão some quando ele já está lá** (P75-A, I80 3, P77-A grupo 2;
decisão 14)
- *Medido:* `scripts/prompt.sh:223` usa `meow_aviso` com o starship ausente e
  `PROMPT_STARSHIP=sim` (o de fábrica), e o aviso pesa no veredito do doctor
  (`pulado_com_aviso`). A ação `prompt_instalar_starship` (`app/servidor.py:5289`) não tem
  `indisponivel`. O botão fica aceso com o starship em `~/.cargo/bin`.
- *Causa:* a decisão 7 separou «baixa e é opcional» de «reparo», e o prompt ficou do lado errado
  nas duas pontas.
- *Cura:*
  - starship ausente → `meow_pula` (de rotina), e a pendência com botão continua;
  - a ação ganha `indisponivel`, que procura o starship nos mesmos lugares do
    `prompt.sh:130` (PATH, `~/.local/bin` e `~/.cargo/bin`).
- *Prova:* um teste com HOME de brinquedo. Sem starship: o doctor não fica vermelho por ele, e o
  botão aparece. Com um `starship` falso em `~/.cargo/bin`: a ação vem indisponível.

**3. O cartão do papel de parede devolvido ganha a saída** (I80 2; decisão 13)
- *Medido:* a pendência `wallpaper-fonte-revertida` só se resolve em `scripts/wallpaper.sh:1908`
  e `:1930`, os dois caminhos do `permitir`. Se a devolução estava certa, o cartão fica na Início
  até alguém clicar em «Era escolha minha», e esse clique autoriza a imagem errada.
- *Cura:* um segundo gesto no cartão, «Deixar assim». Ele chama `meow_pendencia_resolvida`
  (por um verbo `wallpaper dispensar` ou pela rota de pendência do servidor) sem gravar
  `WALLPAPER_FONTES_PERMITIDAS`.
- *Prova:* um teste de servidor: «Deixar assim» tira o cartão e o conf não muda (sha256 igual).

### Área 2 — Ícones, ficha e dados do pack

**4. O «Adicionar ícone» grava fora do clone, e o desenho aparece na ficha** (P73-A; decisão 15)
- *Medido:* o `ACERVOS["icone"]` (`app/servidor.py:8071-8075`) grava em `assets/icones/overrides/`,
  dentro do repositório. A pasta nem existe, e ela não está no `ACERVOS_DO_MOTOR`
  (`scripts/pack.py:4270-4279`). O desenho enviado não aparece para ser escolhido.
- *Cura:* o destino passa a ser o estado de quem usa (`~/.local/share/meowsystem/icones-enviados/`),
  e o `acervos_de_icone` o lista como uma pasta da ficha.
- *Prova:* um teste com HOME de brinquedo: enviar um SVG deixa o `git status` limpo e põe o desenho
  na ficha.

**5. O «Usar» da oficina grava no estado, não no clone** (P73-A; decisão 15)
- *Medido:* `app/servidor.py:10233-10240` grava `retoques/<app>.svg` e a linha `<app>:mao:<cor>`
  no `assets/icones/apps-convertidos.map`. O `tests/git-limpo.sh:399-418` conta isso como pendente.
- *Cura:* o retoque e a linha vão para o estado de quem usa, no mesmo molde do
  `icones-escolhidos.map` da P73 (I3). O construtor lê as duas fontes.
- *Prova:* a seção «pendente» do `git-limpo.sh` chega a 0, e o teste da oficina (`tests/oficina.sh`)
  continua verde.

**6. A ficha marca o desenho que veste o app agora** (P73-A QA, O1)
- *Medido:* o `_escolha_no_pack` (`app/servidor.py:9594-9611`) só responde quando a linha do mapa é
  uma escolha do painel (`antes is None → None`). O Waterfox abre com o desenho do pack sem marca
  nenhuma.
- *Cura:* a resposta da ficha leva `veste`, o arquivo que o app usa hoje, nesta ordem: escolha de
  quem usa, depois a linha do mapa do pack no ar, depois o traço. A ficha marca esse arquivo.
- *Prova:* um caso no `tests/acervo-da-ficha.sh`: o `net.waterfox.waterfox` vem com `veste`
  apontando para `packs/dracula/icones/apps/net.waterfox.waterfox.svg`.

**7. A busca «firefox» acha a raposa resgatada** (P73-A QA, O1)
- *Medido:* `assets/icones/resgatados/net.waterfox.waterfox.svg` existe, mas a linha dele saiu do
  `apps-resgatados.map` na P28 (`:54-58`). Sem linha nem catálogo, a busca não tem texto para casar.
- *Cura (dado):* um `catalog.json` em `assets/icones/resgatados/`, no formato do da biblioteca, com
  a descrição dos desenhos que não têm linha de mapa («raposa roxa — Firefox/Waterfox»).
- *Prova:* um caso no `acervo-da-ficha.sh`: «firefox» acha os dois desenhos.

**8. Nomes na ficha** (I80 5)
- *Medido:*
  - o catálogo da biblioteca do Dracula tem 295 entradas para 469 desenhos, então 174 mostram o nome
    do arquivo em inglês;
  - `com.obsproject.Studio` e `io.github.shiftey.Desktop` viram «Studio» e «Desktop». O
    `_rotulo_do_nome` (`app/servidor.py:9850-9867`) pega a última parte do id, e as linhas
    `assets/icones/apps-convertidos.map:221,231` não têm comentário;
  - o `DIRS_DESKTOP` (`app/servidor.py:8311`) diz «usuária».
- *Cura:*
  - as 174 descrições em pt-BR entram no `catalog.json` (dado do pack);
  - cada linha de id invertido do `apps-convertidos.map` ganha um comentário com o nome do app
    (`# OBS Studio`, `# GitHub Desktop`), que o rótulo já lê;
  - o rótulo «usuária» vira «pessoal».
- *Prova:* um teste que conta desenhos da biblioteca sem descrição (deve dar 0) e linhas de id
  invertido sem comentário (deve dar 0). O `tests/app-uso-real.py` ganha os dois nomes.

**9. Dados do pack: Firefox, Vesktop e os projetos pessoais** (P74-A QA, P77-A grupo 1 e QA;
decisões 16, 18 e 19)
- *Medido:*
  - `assets/icones/apps-arcticons.map:395` traz `firefox:firefox:blue`, e o
    `apps-marca.map:151` já anota «hoje está blue, que é do Chrome»;
  - `dev.vencord.Vesktop` não tem linha no `packs/dracula/icones/apps.map`;
  - `packs/catppuccin/icones/autorais/` e `packs/dracula/icones/autorais/` trazem `hefesto-*` e
    `fogstripper-*` (com o `.json` de cada um), e são projetos pessoais.
- *Cura:*
  - `firefox:firefox:peach`;
  - a linha `dev.vencord.Vesktop : apps/com.discordapp.Discord.svg   # Vesktop — o desenho do
    Discord` no pack;
  - os autorais `hefesto*` e `fogstripper*` saem dos dois packs. O `completar_icones.sh` continua a
    vestir a máquina pela `ICONES_LOGO_HEFESTO`, que vem vazia de fábrica. Conferir que o
    «desenho gerado» (`:423`) não dependia do autoral do pack.
- *Prova:* `tests/pack.sh` e `tests/pastas-do-pack.sh` verdes, e `find packs -iname '*hefesto*' -o
  -iname '*fogstripper*'` vazio. A linha de procedência sai do `PROCEDENCIA.md`, se houver.

**10. A camada de apps do Catppuccin só roda com o Catppuccin** (P74-A, P75-A; decisão 22)
- *Medido:* `scripts/icones_apps.sh:73-78` manda qualquer flavor que não seja do Catppuccin
  (o `dracula`) para `macchiato`, e o `:288` diz «o acervo Catppuccin de aplicativos não está em …»
  com o Dracula no ar.
- *Cura:* um flavor de ícone que não é latte, frappé, macchiato nem mocha sai com o código de
  «não é deste pack», sem linha de aviso.
- *Prova:* com `PACK=dracula` (casa de brinquedo), a etapa não diz nada e não escreve. Com o
  Catppuccin, o caminho de hoje.

**11. O lançador: a troca de pack devolve o que escondia, e a fábrica não esconde app de quem
usa** (P74-A, P77-A grupo 3; decisões 17 e 21)
- *Medido:*
  - `scripts/ocultar_apps.sh:262-310` só desfaz uma marca pelo `-nome`. Trocar do Dracula para o
    Catppuccin deixa os 24 do `lancador.ocultar` do pack fora do lançador;
  - o `LANCADOR_OCULTAR` do `meow.conf.exemplo` esconde `google-chrome`, `steam` e `github-desktop`.
- *Cura:*
  - o script grava no estado o que ELE escondeu. Um nome que saiu da lista efetiva (pack + conf)
    tem a marca desfeita, pela mesma régua do `-nome`;
  - os três saem do valor de fábrica. O conf desta casa (linha 1859) já os tem e não muda.
- *Prova:* um teste com `/usr/share/applications` falso. Esconde com o Dracula, troca para o
  Catppuccin, e os 24 voltam; a 2ª passada não escreve nada. O `tests/app.sh` confere o exemplo.

**12. Temas exportados e bases** (P74-A conferência e QA; decisão 20)
- *Medido:*
  - nenhum `Hidden=` no `scripts/exportar_tema.sh` nem no `construir_icones.sh`, então as bases
    aparecem nos seletores como «Dracula Circle» e «Dracula»;
  - o `exportar_tema.sh:162` herda só as bases e o `hicolor`, e os 24 `preferences-*` do COSMIC
    Ajustes ficam sem desenho;
  - o `lib/desinstalar.sh:410` tira a `-Base` e esquece a `-Base-2`.
- *Cura:*
  - `Hidden=true` no `index.theme` de toda base, exportada e local (é da especificação de tema de
    ícones do freedesktop);
  - o tema exportado herda `<bases>,Cosmic,Adwaita,hicolor`;
  - o desinstalador percorre `-Base` e `-Base-[0-9]*` com a mesma marca de dono.
- *Prova:* o teste do `exportar-tema` (HOME limpo) confere `Hidden=true` nas bases e o `Inherits`
  novo. O `tests/reversao.sh` ou um caso novo tira as duas bases.

**13. Um teste para o `ICONES_DRACULA` ausente** (O1 4)
- *Medido:* o `10a139f` (`scripts/icones_apps_dracula.sh`, `_dracula_no_ar`) foi provado só por
  rodada. Todo teste escreve `ICONES_DRACULA="sim"` (`tests/acervo-da-ficha.sh:45`,
  `seletor-do-pack.sh:82`).
- *Cura:* nenhuma no código.
- *Prova:* um caso com o conf sem a linha e o Dracula no ar: os desenhos do pack entram. Vermelho
  contra o `10a139f^`.

### Área 3 — Segurança e pack

**14. `python3 -I` nos módulos de tema de app** (P74-A conferência)
- *Medido:* `git grep 'python3 - '` sem `-I` dá 16 linhas, todas em
  `assets/temas-de-apps/*/manifesto.sh`: heroic 3, kitty 1, obsidian 5, onlyoffice 1, vscode 5 e
  zapzap 1. Eram 37 na P74.
- *Cura:* `python3 -I -` nas 16. Onde o heredoc importa algo do diretório, o caminho vai por
  `sys.path` explícito, como o `lib/comum.sh:767-770`.
- *Prova:* `tests/estilo.sh` ganha a regra («`python3 -` sem `-I` em código de produto é vermelho»).
  O `tests/temas-de-apps.sh` continua verde.

**15. O nome de flavor tem a forma do conf já na validação** (P74-A conferência)
- *Medido:* o `validar` (`scripts/pack.py:3690-3695`) só recusa hífen em nome de flavor. Um
  `../x` passa, e o `meow_flavor` (`lib/comum.sh:733-744`) o devolve cru: o nome vira caminho de
  pastas e de traço.
- *Cura:* o `validar` exige `RE_FLAVOR_CONF` (`pack.py:4860`) em todo nome de `flavors` e
  `claros`. Uma regra, na origem.
- *Prova:* um caso no `tests/pack-malicioso.sh`: um pack com flavor `..` ou `a/b` é recusado
  inteiro.

**16. A ponte root: o `greeter-aplicar` e a lista de pacotes** (P75-A)
- *Medido:*
  - `scripts/ponte_root.sh:183-185`: o `morrer` dentro do `while` de pipe sai só do subshell, então
    é código morto;
  - o `cp -a "$tmp/." "$GREETER_CONF/"` (`:187`) segue um link simbólico que já exista no destino;
  - o `PERMITIDOS` (`:311`) não tem `curl`, `xz-utils`, `unzip` nem `pop-fonts`, que o
    `scripts/instalar_fontes.sh:294,383,415` nomeia sem cura.
- *Cura:*
  - a recusa de `..` sai do pipe e vira um `find … | grep -q` antes da cópia;
  - um link no destino recusa o verbo;
  - os quatro pacotes entram na lista literal e no `etapa_pacotes` (o `tests/doctor-veredito.sh`
    cobra que as listas sejam iguais);
  - o `instalar_fontes.sh` pede as ferramentas pela ponte.
- *Prova:* numa cópia isolada da ponte (como a da P75 item 7), um destino com link é recusado, e
  o `tests/doctor-veredito.sh` fica verde.
- *Nota:* a ponte instalada é hoje igual à do repositório (`cmp` com
  `/usr/local/lib/meowsystem/ponte_root.sh`). Depois desta mudança, ela precisa ser reinstalada
  pelo `install.sh` na integração final. Isso é com quem coordena, com o askpass ativo.

### Área 4 — COSMIC (o que não é da P81)

**17. Fim do `v1` cravado, e um contrato que cobre os oito escritores** (P76-A)
- *Medido:*
  - o `scripts/janelas.sh:351` lê `com.system76.CosmicTheme.Dark/v1/gaps`, mas o COSMIC 1.10
    instalado traz `v1 v2` nesse namespace (`ls /usr/share/cosmic/…`), e a casa tem um `v1/gaps` de
    24/09 03:46 e um `v2/gaps` de 24/09 08:50. A linha mostra o valor velho;
  - ainda há `v1` cravado em `lib/noite.sh:93`, `scripts/leitura_build.sh:134-135`,
    `scripts/logo.sh:460-461`, `scripts/completar_icones.sh:577`,
    `scripts/auditar_icones.sh:198` e `scripts/wallpaper.sh:1190,1240`;
  - o `tests/contrato-cosmic.sh` cobre 5 dos 8 escritores.
- *Cura:*
  - todo caminho de namespace passa pelo `meow_cosmic_v` (`lib/comum.sh:1106`);
  - o estado do `CosmicBackground` (em `~/.local/state`) usa o mesmo número;
  - o `tests/estilo.sh` cobra `/v1/` cravado em código;
  - o `contrato-cosmic.sh` ganha o `areas.sh`, o `wallpaper.sh` e a fronteira do `aplicar_tema.sh`.
- *Prova:* com um `/usr/share/cosmic` falso que traz `v2`, os escritores e o `janelas.sh` usam o
  `v2`, e nenhum `v1` nasce.

**18. O `completar_icones.sh` lê a lista do `meow cosmic icones`** (P76-A)
- *Medido:* nenhuma referência em `scripts/completar_icones.sh`. O `meow cosmic icones` diz «sem
  desenho: com.system76.CosmicViewer», e ninguém completa.
- *Cura:* o `completar` pega os ids sem desenho da mesma função do verbo e os completa pela regra
  que já usa.
- *Prova:* com um `.desktop` falso de app do COSMIC sem desenho, o tema ganha o ícone, e a 2ª
  passada não escreve.

**19. O tema Light segue o libcosmic do COSMIC instalado** (P76-E item 7; decisão 49)
- *Medido:* `tests/oraculo-tema.sh:28-30` aceita que o 5a8bd94 (o 1.10, que é o instalado agora:
  `cosmic-settings 1.10.0~…~58aeb65`) difira do Python em `background.component.pressed` na Light
  (`#E9EAF5E1` contra `#B6B7C2E1`). O mesmo campo difere nas três Light do Catppuccin.
- *Cura:* a derivação Python (`scripts/gerar_tema_v1.py` e as `derivar_*`) segue a regra do 1.10
  para esse campo.
- *Prova:* o `oraculo-tema.sh` passa a exigir «Light igual» no 5a8bd94. As saídas do oráculo já
  moram em `tests/oraculo/`, então a prova não compila nada.

**20. O applet de leitura relê os sliders depois de nascer** (P77-A grupo 3)
- *Medido:* o `src/applets/leitura` lê `ultima_*` só ao nascer. Depois do «Salvar e aplicar», o
  interruptor do popup religa no ponto antigo até o applet reiniciar.
- *Cura:* um `watch_state` (ou `watch_config`) no applet.
- *Prova:* `cargo build` numa árvore de alvo própria (`CARGO_TARGET_DIR` no scratchpad), **só
  depois que o build real do compositor terminar**, mais um teste do lado do estado (a escrita do
  `ultima_*` acontece). O `tests/applet-pino.sh` continua verde.

### Área 5 — Painel (interface)

**21. A 375 px** (I80 6)
- *Medido:*
  - `app/pagina/app.js:9885` só confere `top/bottom` antes do `scrollIntoView`. Na tira horizontal,
    a aba fora da vista à direita nunca rola;
  - os outros três são do QA da P80: a prévia fixa cobre parte dos cartões, o «?» da prévia de
    Manutenção fica sobre o desenho, e a `trava_pack` passa do teto do balão.
- *Cura:*
  - a conferência inclui `left/right` contra o trilho;
  - os outros três são consertados no CSS de origem, um por vez, com print.
- *Prova:* um caso por item no `tests/app-uso-real.py` a 375 px (vermelho antes, verde depois), com
  os prints em `.playwright-mcp/ux-p82/`.

**22. Pares «ver / aplicar»** (P77-A grupos 3 e 4; decisão 24)
- *Medido:* «Ver o que mudaria nos jogos do Heroic» (`app/servidor.py:5472`) fica aberto, e o
  aplicar dele vai para o «⋯». «O que a atualização mudaria» (`:4784`) e «Atualizar a máquina
  inteira» são dois cartões soltos.
- *Cura:* os dois viram par, no molde do «Conferir» e do «Arrumar» da Steam.
- *Prova:* o gate (`tests/app-completo.py`) com o inventário novo e o `app-uso-real.py`.

**23. Ações que repetem a moldura** (P77-A grupos 1 e 2; decisão 25)
- *Medido:* «Trocar de tema» (`:4852`) e «Passar para claro ou escuro» (`:4862`) em Cor e tela,
  «Pôr um gato no dock» (`:4945`) e «Passar ao próximo gato» (`:4972`) apagadas em dois dos três
  modos.
- *Cura:*
  - as duas de tema vão para o «⋯» de ações técnicas;
  - as duas de gato vão para dentro da moldura do modo que as usa.
- *Prova:* o gate e o `app-uso-real.py`.

**24. O pack se escolhe por um gesto só** (P77-A grupo 1; decisão 23)
- *Medido:* o «Theme pack» de Cor e tela (`meow.conf.exemplo:93`, `PACK`) grava e espera o
  «Salvar e aplicar». O «Usar este» da Início roda o `pack_usar` na hora.
- *Cura:* a escolha em Cor e tela dispara o mesmo `pack_usar`, com a mesma caixa e o mesmo selo.
- *Prova:* o gate confere que as duas portas mandam o mesmo pedido.

**25. O gato de verdade na ponta da dock da prévia** (P77-A grupo 2)
- *Medido:* `app/pagina/previas-tela.js:941` desenha o `gatoDeTraco` genérico.
- *Cura:* o SVG do acervo, pintado pela página, como o terminal já faz.
- *Prova:* um print e um caso no `app-uso-real.py` (o `<svg>` da ponta é o do gato escolhido).

**26. A grade sem buraco, e a seção sem chaves sem vazio** (P77-A grupos 2 e 4)
- *Medido:* um cartão de par de desenhos mais alto deixa buraco na grade de três colunas. O
  `desenhoDaSecaoSemChaves` (`app.js:8718`) ocupa a linha com 260 px e deixa o resto vazio.
- *Cura:* na grade universal (CSS), sem regra por página.
- *Prova:* prints antes e depois em Papel de parede, Instalação, Atualização e Manutenção.

**27. Noite: o par incompleto e a regra única** (P77-A grupo 3; decisão 26)
- *Medido:*
  - o arquivo aceita «a noite começa» sem o «termina», e o `meow_noite_janela` pede as duas pontas;
  - o `lerNoite` (`app/pagina/previas-sistema.js:1287`) é a terceira cópia da regra, ao lado do
    `janelaDoGato` (`app.js:9218`).
- *Cura:*
  - o `validar_valor` do servidor recusa a gravação de um par incompleto (a página já mostra o ⊘);
  - o `previas-sistema.js` usa o `janelaDoGato`.
- *Prova:* um teste de servidor (o par incompleto dá 409) e o `app-navegador.py`.

**28. Folga e encaixe por área sem áreas** (P77-A grupo 3; decisão 28)
- *Medido:* sem `AREAS_NOMES`, o `controlePorArea` não existe, e os dois cartões ficam como campo
  de texto livre.
- *Cura:* com a lista vazia, os dois cartões nascem com o ⊘ e o porquê na dica, como as outras
  travas.
- *Prova:* o `app-uso-real.py` numa casa sem áreas.

**29. Um nome por valor no seletor** (P77-A grupo 4; decisão 27)
- *Medido:* `app.js:2117` põe «— como está —» no `<select>`, e o botão ao lado chama o mesmo vazio
  de «Não tocar» (`:2239`).
- *Cura:* a opção vira «— não tocar —».
- *Prova:* o `tests/app-texto-visivel.py` não acha «como está» em `<select>`.

**30. O «Usar este ícone» mantém o cartão à vista** (P77-A QA)
- *Medido:* a gaveta abre e a página rola até o fim, então o cartão do app que mudou sai da vista.
- *Cura:* foco e rolagem voltam para o cartão do app (o `devolverRolagem` já existe).
- *Prova:* um caso no `app-uso-real.py`: depois do gesto, o cartão está no viewport.

**31. Manutenção: dois «⋯» distintos e números com controle de número** (P77-A QA)
- *Medido:* os dois «⋯» (ajustes técnicos e ações técnicas) são idênticos. «Quantos backups
  guardar» (`meow.conf.exemplo:1993`) não declara faixa e vira campo de texto. «Largura do nome da
  música» (`:975`) declara `80..900`; conferir por que não vira número.
- *Cura:*
  - cada «⋯» leva o rótulo e o ícone do que guarda;
  - a faixa entra no exemplo (dado) para toda chave numérica.
- *Prova:* o `app-acessibilidade.py` (nome acessível distinto) e um caso que conta as chaves
  numéricas sem faixa (deve dar 0).

**32. Código morto** (P77-A, P73-A conferência; decisão 29)
- *Medido:* `comandoCurto` (`app.js:540`) sem nenhum chamador (1 ocorrência, a definição);
  `.descricao-secao` (`estilo.css:624-626`) sem quem a gere; `const comBusca = true` (`app.js:3972`,
  usado só em `:4208`).
- *Cura:* sai, com a nota da casa no lugar de onde saiu.
- *Prova:* os testes de página verdes.

**33. O bloco órfão de chave aposentada no conf** (P75-A; mesmo princípio da P75)
- *Medido:* `~/.config/meow/meow.conf` (só leitura) guarda dois blocos `# @ Tema de onde herdar`
  (linhas 386 e 1820) sem chave embaixo.
- *Cura:* o `scripts/migrar_conf.py` tira o bloco do exemplo (os `# @`/`# >` e o parágrafo colado)
  que ficou sem a chave aposentada. O comentário escrito à mão (`# ICONES_BASE saiu em 24/09…`)
  fica, pela regra da casa.
- *Prova:* o `tests/chaves-aposentadas.sh` ganha um caso com o bloco, sobre uma cópia do conf: o
  bloco sai, a nota fica, e a 2ª passada não escreve.

**34. O papel de parede não semeia estado em verbo que só lê** (P77-A grupo 2)
- *Medido:* o `meow_estado_com_padrao` (`lib/comum.sh:1530-1547`) cria `$MEOW_ESTADO/<pasta>` e
  copia as sementes na primeira LEITURA. O gate o carrega em `DEFEITOS_CONHECIDOS`
  (`tests/app-completo.py:3520`).
- *Cura:* a semente só nasce no verbo que escreve. A leitura devolve o caminho e lê a semente do
  clone quando o estado não existe.
- *Prova:* o `DEFEITOS_CONHECIDOS` volta a ficar vazio, e o gate passa.

### Área 6 — Testes e servidor

**35. A suíte se protege inteira** (P75-A, O1, O2·P79 6)
- *Medido:* o `tests/todos.sh:277-288` falsifica só `sudo`, `pkexec` e `su`. As rodadas verdes de
  09 e 10/10 usaram um envoltório de fora (falsos de `pkill`, `killall`, `notify-send`,
  `systemd-run`, `loginctl`, `apt`, `apt-get` e `xdg-open`; `systemctl`, `gsettings` e `dconf` só
  para leitura; sem `DBUS_SESSION_BUS_ADDRESS`, `XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY` e `DISPLAY`).
- *Cura:* o `todos.sh` monta esse envoltório ele mesmo. A escrita recusa com rc=1 e registra, e o
  placar diz quantas vezes cada falso foi chamado. Nota: `kill` é builtin, então o falso dele não
  pega nada; não prometer.
- *Prova:* `./tests/todos.sh` inteiro verde sem nenhum envoltório externo. Um `find -newer` nas
  pastas do HOME real e em `/etc/sudoers.d` sai vazio.

**36. O `Trabalho.vivo()` não fica vivo para sempre com um neto** (I80 7)
- *Medido:* o `vivo()` responde por `self.fim is None` (`app/servidor.py:6797-6798`), e o `fim` só
  nasce quando o stdout fecha. Um neto que herde o stdout deixa o trabalho vivo para sempre.
- *Cura:* depois que o processo sai, o leitor dá um prazo curto para o pipe e grava o desfecho.
- *Prova:* um caso no `tests/trabalho-vivo.sh` com `sh -c 'sleep 60 & echo ok'`: o trabalho
  termina em menos de 5 s, com `rc` 0.

**37. O `assentar` do gate espera o pedido que nasce depois de um salto assíncrono** (I80 7)
- *Medido:* a cura da integração (`e34845c`) vale só para o `/api/pack-importar`. Qualquer gesto
  cujo pedido nasça depois de um `close` de caixa tem a mesma janela de 3 s.
- *Cura:* o `assentar` registra os pedidos que nascem até X ms depois do gesto, no lugar de olhar o
  `pedidos_vivos` uma vez só.
- *Prova:* um `sleep 4` temporário numa rota confirmada fica verde com a cura e vermelho sem ela.
  O `sleep` não entra em commit.

**38. Os testes não deixam resto em `/tmp`** (I80 7)
- *Medido:* `tests/app.sh:455` faz `_tf.mkdtemp()` sem apagar (o `bom.conf` e o `quebrado.conf`).
  O `app-completo.py` deixa um `meow-completo-*` por rodada, mesmo com o `finally`
  (`:4330-4333`); medir por qual caminho.
- *Cura:* apagar no fim de cada bloco e cobrir a saída por sinal.
- *Prova:* `ls /tmp` antes e depois de uma rodada dos dois: a mesma lista.

**39. A acessibilidade conta as legendas de desenho** (P77-A)
- *Medido:* o `tests/app-acessibilidade.py:475-484` deixa as «12 legendas de desenho» fora do
  teto. A P77 tirou essas legendas da tela.
- *Cura:* a isenção sai, e o teto vale para elas.
- *Prova:* o teste verde sem a isenção. Se uma legenda voltar, ele fica vermelho.

---

## Resolvidos (com prova no código de hoje)

| fonte | item | prova |
|---|---|---|
| O1 1 | o «Consertar» declara rede | decisão 7; `app/servidor.py:4731-4737` (`rede: True`), `app/pagina/app.js:7420` (o selo «baixa da internet») |
| O1 2 | a segurança da P73 (CSP, nosniff, symlink) | `app/servidor.py:259` (`CSP_DE_IMAGEM` com `sandbox`), `:7653,7677`; `tests/pack-malicioso.sh:339-357` (SVG com `<script>`, pasta-symlink 404) |
| O1 3, O2 7 | as specs P73/P74 conflitando no dev | a leva G entrou no dev (`cd34d87`) |
| O1 5, P75-A, P76-A, P76-E | o `portabilidade.sh` vermelho | `1094ee0`; rodado aqui com HOME temporário: «ok: … (9 isenções)» |
| O1 5, P75-E, P76-E | o `doctor-so-le.sh` e o HOME da sessão | `tests/todos.sh:274` (`SUITE_CASA_REAL`), `tests/doctor-so-le.sh:200`; I80: 60 verdes e 0 vermelhos |
| O2 1, I80 8, P78-A, alerta da P79 | a extensão do VS Code | decisão 9 na P79; `app/servidor.py:5411` (o gesto instala pelo id); O2·P79 «O que entrou» 1 |
| O2 2, I80 8, P77-A (grupos 2 e 3, conferência, QA) | o nome do «Restaurar ao padrão» | decisão 10; `app/pagina/app.js:1904` (grava `item.padrao`), `:2239` («Não tocar») |
| O2 3, P77-A QA (3 itens) | a casa real (`ICONES_FLAVOR`, `CURSOR`/`ICONES_PASTAS`, `CosmicBackground`) | `scripts/migrar_conf.py:107` (`VESTIGIOS`); `tests/casa-real.sh`; o conf real tem hoje `ICONES_FLAVOR="$FLAVOR"` (linha 425) |
| O2 4, P77-A QA (2 itens) | as saídas que mandavam digitar (`pkill`, `sudo -v && ./install.sh`, `LEITURA_COMPILAR=1`) e a caixa do sudo | `grep` por essas formas em código ativo: vazio (só o `fix_leiturabin`, que roda a ação); `tests/nada-manda-digitar.sh`; decisão 11, em `app/pagina/app.js:7293` (uma linha, o porquê na dica) |
| O2 5, P77-A conferência e QA, P78-A | CRLF, BOM, `MEOW_COSMIC_DIR`, `LOGO_MODO=""`, «Créditos», favoritar | `tests/achados-tecnicos.sh:6-20`; `scripts/vidro_janela.py:75`; `tests/gate-link-externo.py`; `app/pagina/app.js:6029` |
| O2 6, P78-A | o painel PID 1985165 e o resto em `/tmp` | `ps -p 1985165` vazio; nenhum `app/servidor.py` de pé; nenhum resto `meow*` em `/tmp` |
| O2·P79 1, P77-A grupo 3, S80 6 | a corrida do `Trabalho.vivo()` («SAIU NULL») | `app/servidor.py:6797-6798` (`self.fim is None`); `tests/trabalho-vivo.sh` |
| O2·P79 3, S80 8 | o «resolve: <comando>», o `wallpaper permitir` e o rustup do `leitura_build` | `lib/comum.sh:1800-1811`; `scripts/wallpaper.sh:1680-1688` (o botão «Era escolha minha»); `scripts/leitura_build.sh:385-397` |
| O2·P79 4, S80 7 | três reciclos do painel | `lib/comum.sh:1960-1995` (`meow_tela_reler_no_fim`); `tests/reler-uma-vez.sh` |
| O2·P79 5, S80 10 | o ponteiro do pack que baixa | decisão 12; o selo no «Usar este» (I80 «O que entrou» 10) |
| O2·P79 6, S80 9 | o falso do `systemctl` do `convergencia.sh` | `tests/convergencia.sh:52-80` (a escrita recusa) |
| I80 9 | o dev sem a leva | `cd34d87` (merge de `integracao/leva-g` no dev) |
| P73-E | o ` M packs/dracula/icones/apps.map` do dev | a linha está em `~/.config/meow/icones-escolhidos.map:1` (`org.kde.ghostwriter`); `git status` do checkout principal sem `packs/` |
| P73-E | três cópias sem `inkscape:export-filename` | o `PROCEDENCIA.md` guarda os dois sha256 (registro, sem defeito) |
| P73-A | o comentário «O PADRÃO É `nao`» | `scripts/icones_apps_dracula.sh:581` («O PADRÃO É `sim`») |
| P73-A conferência | a nota da cor na tela | `72d9bf3` (já anotado na spec) |
| P73-A QA | o QA do seletor com o HOME real | decisão 8; `app/run.sh:146-148`; `tests/pack-malicioso.sh:438` |
| P73-A QA | a prévia flutuante sobre a grade (P77) | coberta pela P80 (a fileira «Fundo» só em Cor e tela); o que sobra a 375 px está no item 21 |
| P74-A | o `icones_apps_arcticons.sh` sai 3 sob `set -e` | `scripts/icones_apps_arcticons.sh:654-663` (`|| rc=$?`) |
| P74-A | o cabeçalho do `starship.toml` | `assets/prompt/starship.toml:27-30` |
| P74-A conferência | o `icones_pastas.sh` sem a régua | `scripts/icones_pastas.sh:157-165` (`meow_nome_seguro`, e o `\r` sai) |
| P74-A QA | 229 contra 230 | explicado na spec (o 230 contava um órfão); sem defeito |
| P75-E nota 1 | a ponte instalada estava atrás | `cmp /usr/local/lib/meowsystem/ponte_root.sh scripts/ponte_root.sh`: igual (10/10 17:58) |
| P75-E nota 2 | a 1ª passada vermelha (`index.theme`) | P74 item 5 (`71c95ea`, etapa `icones_indice`; a 2ª passada não escreve) |
| P77-A | a faixa da simulação do modo de leitura | a prévia real existe (`app/pagina/app.js:3657`, `previaRealDaLeitura`) |
| P77-A (4 itens riscados) | `avisoDeCombinacao`, os caracteres da Início, `mexidas`, `meow status` | riscados na própria spec, com o commit |
| P77-A grupo 3 | a régua de horas do tema claro | P80 item 4 (o mesmo seletor de hora nas três linhas) |
| P77-A grupo 4 | os achados 18 e 19 no gate | cobertos por `app-navegador.py` e `um-cartao-por-jogo.sh` (a spec diz) |
| P78-A | o conteúdo dos temas de app | curado na conferência (`_kitty_so_cor`, `_gt_so_cor`) |
| P78-A | `rsvg-convert` e `<image href>` | medido aqui, no librsvg 2.58: `href="../fora.png"`, um link para fora e `file:///etc/hostname` saem vazios, e só o `sub/dentro.png` desenha; o `importar` recusa link simbólico (`tests/pack-malicioso.sh:114-124`) |
| alerta da P80 | ReDoS do `comeco_svg` | o leitor linear em `app/servidor.py:4590-4604` |

---

## Decisões (tomadas aqui; quem usa delegou: «pode cuidar de tudo isso»)

A numeração continua a de `2026-10-09-uso-real/02-decisoes.md` (que vai até a 12). Cada decisão se
desfaz trocando a linha e o código que a lê.

| # | Pergunta (fonte) | Decisão | Por quê |
|---|---|---|---|
| 13 | O cartão do papel devolvido não se dispensa (I80 2) | **«Deixar assim»** ao lado de «Era escolha minha». Ele resolve a pendência sem autorizar (item 3) | um cartão que só sai pelo gesto errado prende a tela; show don't tell |
| 14 | O doctor instala o starship? (P75-A) | **Não.** Starship ausente é pulado de rotina, o botão fica, e some quando ele existe (item 2) | decisão 7: baixar o que é opcional pede gesto; o doctor conserta o que está fora, não instala o que é opcional |
| 15 | Onde mora o ícone enviado e o retoque da oficina (P73-A) | **No estado de quem usa.** O repositório só recebe pelo «Levar para o pack» (itens 4 e 5) | I3 da P73: a escolha mora na casa, e usar o produto não é commit |
| 16 | `hefesto` e `fogstripper` nos autorais dos packs (P77-A) | **Saem dos dois packs.** A `ICONES_LOGO_HEFESTO` fica como gancho só da máquina, vazia de fábrica (item 9) | regra de 23/09 e decisão 4 (o `calcdeirao` saiu pelo mesmo motivo) |
| 17 | O lançador de fábrica esconde Chrome, Steam e github-desktop (P77-A achado 20) | **Saem do valor de fábrica.** O conf desta casa já os tem e não muda (item 11) | são apps de quem usa, não de sistema; o que é só desta máquina mora no conf dela |
| 18 | O Vesktop sem desenho (P74-A QA) | **Veste o Discord do pack** (item 9) | é um cliente do Discord; cair no ícone do flatpak destoa do pack |
| 19 | O traço do Firefox em azul (P74-A QA) | **peach** (item 9) | o próprio `apps-marca.map:151` mede: azul é do Chrome |
| 20 | Bases nos seletores e os 24 `preferences-*` (P74-A) | **`Hidden=true` nas bases; o exportado herda `Cosmic,Adwaita`** antes do `hicolor` (item 12) | `Hidden` é da especificação; tema herdado que falta é ignorado e não quebra a regra do T7 |
| 21 | Trocar de pack não devolve o que o pack escondia (P74-A) | **Devolve** (item 11) | é «o pack decide», o mesmo do ponteiro na P79 |
| 22 | A camada de apps do Catppuccin com o Dracula (P74-A, P75-A) | **Só roda com o Catppuccin** (item 10) | é camada do pack, não do motor |
| 23 | O pack em duas portas (P77-A) | **Um gesto só**: Cor e tela roda o `pack_usar` (item 24) | duas portas com dois comportamentos é o achado 11 pela metade |
| 24 | Heroic e Atualização (P77-A) | **Pares «ver / aplicar»** (item 22) | é o molde já aprovado da Steam |
| 25 | Ações que repetem a moldura (P77-A) | **As de tema vão ao «⋯»; as de gato, para dentro da moldura do modo** (item 23) | uma decisão, um lugar |
| 26 | Noite com uma ponta só (P77-A) | **Recusada na gravação** (item 27) | o ⊘ já mostra; o arquivo não pode aceitar o que não vale |
| 27 | «— como está —» ao lado de «Não tocar» (P77-A) | **«— não tocar —»** (item 29) | um nome por valor |
| 28 | Folga e encaixe sem áreas (P77-A) | **⊘ com o porquê na dica** (item 28) | o `areas.sh` se pula com a lista vazia; um campo livre ali é texto cru |
| 29 | O código morto anotado (P77-A, P73-A) | **Sai no fechamento** (item 32) | ficou anotado pela regra da casa; fechar o projeto é a hora |
| 30 | Um `ICONES_DRACULA="nao"` antigo (P74-A) | **Fica como está**, sem migrar | um «nao» escrito é escolha; adivinhar sobrescreveria uma escolha de verdade (a casa tem `"sim"`, linha 1720) |
| 31 | Unificar o nome do tema instalado com o exportado (P74-A) | **Não.** O instalado continua `MeowSystem-Icons`; o exportado leva o nome do pack | é o nome que o COSMIC lê; trocá-lo mexe no conf de toda casa sem ganho |
| 32 | Duas regras do «lado vestido» (P74-A) | **Ficam** | as duas passam pelo `derivar_flavor.par_do_outro_lado` no lado escuro, e o `tests/variante.sh` §7 vigia |
| 33 | Sons só na notificação (P74-A) | **Fica** | ninguém pediu dispositivo, bloqueio nem captura |
| 34 | O arco dos gatos `coquinha` e `mimir` em macchiato (P74-A QA) | **Não repinto** | é desenho da criadora; o pack que quiser traz o próprio logo (I9) |
| 35 | 52 nomes do tema antigo sem desenho (P74-A QA) | **Ficam fora** | eram PNG do `current/` (raster não é fonte) ou projeto pessoal; caem no ícone do próprio app |
| 36 | O índice do upstream (`32/actions`, emblemas) | **Como veio** | é do upstream, copiado com pino |
| 37 | Desenhos de pasta e de mimetype na biblioteca (P73-A) | **Ficam** | decisão 3: «acessar todas as imagens disponíveis» |
| 38 | O Discord escuro na miniatura (P73-A QA) | **Fica** | é da arte |
| 39 | Nomes em inglês que vêm do `.desktop` do sistema (I80 5) | **Ficam** | é o nome que o lançador mostra; traduzir só na ficha seria uma segunda verdade |
| 40 | Duas políticas para a linha ruim (P78-A) | **O alvo que sai da raiz recusa o pack inteiro**; o nome torto é pulado e contado | sair da raiz é tentativa de fuga, não erro de digitação |
| 41 | O `pack.py sincronizar` abre a coluna `lido de` (P78-A) | **Fica no verbo manual**, com a guarda de mesma extensão (`scripts/pack.py:1351-1358`) | só compara o sha256 de arte com arte |
| 42 | O filtro `awk` do `_dracula_pares_do_mapa` (P78-A) | **Fica** | três testes extraem a função verbatim |
| 43 | Os leitores `${ICONES_BASE:-Papirus-Dark}` (P75-A) | **Ficam** | é variável interna, com o mesmo padrão em todo lugar; nenhum defeito medido |
| 44 | Uma chave ausente no binário não impede o escritor (P76-A) | **Fica** | o COSMIC ignora a chave que não conhece, e o pré-voo avisa |
| 45 | O balão a 375 px sobe sobre a busca (P77-A) | **Fica** | não cobre item do menu (U3), e só existe no hover |
| 46 | O gate falhou uma vez em Lançadores (O2·P79 2) | **Fechado, não reproduzido** | depois das curas da P80 e da integração (`e34845c`), foram 4 rodadas inteiras sem ele (I80 «As duas suítes»); se voltar, o item 37 é o lugar |
| 47 | O ` M .gitignore` do checkout principal | **Fica fora do produto** | são 3 linhas `anti-IA (anonimato local)` de uma ferramenta da máquina, e não são do projeto; esta leva não toca o checkout principal |
| 48 | O aviso do `NOPASSWD: ALL` manda rodar `sudo -l` (P75-A) | **A linha diz o estado, sem receita** (item 1). Tirar ou manter o `NOPASSWD` é de quem usa | o arquivo do sudoers é segurança pessoal da conta |
| 49 | O Light do tema contra o libcosmic 1.10 (P76-E 7) | **Segue o COSMIC instalado** (item 19) | o 1.10 está instalado desde 15/10; o oráculo já mostra a diferença |

As decisões abertas da pesquisa do COSMIC (P76-A: a escada aceita o degrau 2 sozinha, e o GitHub é a
única fonte da revisão do libcosmic) ficam com a P81, que mexe nesse código.

---

## De outros blocos

**DA P81** (compositor, cosmic-files, pós-apt, e as linhas `patches`, `leiturabin` e `files_menu`
do doctor):
1. O `meow-doctor.service` sai 2 e fica `failed` sem notificar (P75-A). A decisão é avisar no 2
   também, numa linha. Vai para a P81 porque a P81 mexe na mesma unidade (o `~/.cargo/bin` no PATH).
2. O `meow-doctor.service` sem `~/.cargo/bin`, e o doctor das 5h que cai em «sem cargo» (P76-A, O1).
3. O gatilho do pós-apt preso ao `99-meow-lancador` com `LANCADOR_SISTEMA="sim"` (P76-A).
4. O doctor não confere as unidades `meow-pos-apt.*`, e o pré-voo não roda no doctor (P76-A).
5. A ponte faz `update` e `full-upgrade` num verbo só (P76-A).
6. A escada aceita o degrau 2 sozinha, e o GitHub é a única fonte do libcosmic (P76-A): confirmar
   ou mudar lá.
7. O `patches.estado` e o `.pacote` antigos sem uso com o shim (P76-A).
8. O `conferir` sai 0 com um `!!`, com o shim ligado e sem build (P76-A); é a `garantir_builds`.
9. A base do pino dos applets só nasce numa passagem que aplica (P76-A).
10. O `compilar` deixa o `alvos.novo` e troca por cópia parcial (P76-A).
11. A prova do login com o shim (P76-E item 2).
12. O coredump do applet tirando a sombra depois do apt (P76-E item 8, O1).
13. As linhas `meow files-menu build` do `scripts/files_menu.sh:183,320,414` (P75-A, O2 4, P77-A QA).

**DA P83** (documentação):
1. O `docs/FRONTEIRA.md` conta «oito verbos fechados» (P75-A). A ponte tem o `pacotes`, e o item
   16 mexe na lista.
2. A doutrina «nunca `apt upgrade`» do `docs/COSMIC-THEMING.md` §6 (P76-A); é a tarefa 3 da P83.
3. O S2 nos documentos: as linhas com `/mnt/Apate` e o «pedido dela» em `docs/` (P77-A); é a
   tarefa 5 da P83.

A P83 também registra as decisões 31, 33, 35 e 43 no `ESTADO-FINAL.md`, na parte do que ficou fora
de propósito.

**DA P84** (PNG para vetor):
1. O `obsidian.png` é um SVG com nome de PNG (I80 1). Entra no lote com o nome certo.
2. Os 39 PNG de `packs/dracula/icones/feitos-a-mao/` viram vetor por RMSE (P73-E T5, P73-A,
   decisão 2).
3. Os 41 MB do `.meowpack` do Dracula, com o teto de envio de 64 MB (P73-A): medir o `exportar`
   depois do lote.
4. A pasta «feitos à mão (PNG)» baixa 41 MB de miniatura com `no-store` (P73-A). Some com o lote; o
   PNG que ficar ganha miniatura reduzida.
5. Os nomes com erro (`visalizador-de-imagens.png`, `calendario.png`, «Gerenciador de
   extensoes»): o vetor nasce com o nome certo e com a linha de procedência (I80 5).

## O que fica com quem usa

1. **`NOPASSWD: ALL` no sudoers desta conta (desde abril).** Com o askpass ativo (decisão 5,
   resolvida em 15/10), ele deixou de ser necessário para o MeowSystem. Tirá-lo é mudança de
   segurança da conta, e o doctor só passa a dizer o estado (decisão 48).

## Ordem sugerida para quem implementa
1. Área 6 (a suíte se protege) primeiro, porque todo o resto se prova nela.
2. Áreas 3 e 1.
3. Áreas 2 e 4, que são dado e scripts.
4. Área 5 por último (navegador, prints em `.playwright-mcp/ux-p82/`).
5. Fecho: o `tests/todos.sh` inteiro verde, duas rodadas.

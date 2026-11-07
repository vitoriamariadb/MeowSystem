# Decisões que valem hoje

Decisão de quem usa só se desfaz com sim explícito sobre aquele tema. Para desfazer: troque a linha
aqui e o código que a lê, no mesmo commit, citando o sim. `tests/decisoes.sh` cobra cada uma que tem
prova no código. O texto de antes de cada linha mora no histórico do git.

| # | vale | base |
|---|---|---|
| 1 | Base de ícones do Dracula: **As duas**, `circle` na frente e `main` atrás | «todos os drácula feitos» |
| 2 | PNG feito à mão vira vetor validado por RMSE; o PNG sai só quando o vetor passa | «pedimos pro agente criar e validamos» |
| 3 | O seletor, a aba Sistema e a Biblioteca mostram só o acervo do pack em edição (e dos que ele herda, até o primeiro pack do projeto); ícone de um pack nunca aparece no outro | sim de 26/10: «o que eu falei hoje sobrescreve» |
| 4 | `calcdeirao` fica fora do pack; `jogos`, `rede` e `clima2` entram | projeto pessoal fora do pack (23/09) |
| 5 | Askpass da Aurora ativo; o segredo mora só no arquivo 600 dele, fora do repositório, e a senha nunca vai para commit nem documento | «askpass ativa» (15/10) |
| 6 | GPU do compositor na placa dedicada, detectada em cada máquina: `COSMIC_RENDER_DEVICE="0x<vendor>:0x<device>"` no `/etc/environment`, gravado pela ponte root (`gpu-compositor`); com uma GPU só não há linha; `GPU_COMPOSITOR="padrao"` no `meow.conf` não toca | «tudo nvidia de fato» (17/09), «sim por favor» (15/10); sim de 28/10: «Pensa num produto universal. Pra ser usado em outras máquinas no meu caso é a 4060 aí reapontamos pra lá» |
| 7 | O «Consertar» do doctor baixa com o selo «baixa da internet», sem caixa de pergunta; a pergunta fica só para o que baixa e é opcional | «O doctor não tem que avisar nada. Tem que corrigir.» (09/10) |
| 8 | QA do painel só com HOME temporário; o `run.sh --sem-abrir` recusa o HOME da conta sem `MEOW_QA_HOME_REAL=1` | o painel escreve no sistema real |
| 9 | Só pack do repositório instala extensão do VS Code; pack importado mostra o pedido e instala só por gesto | pack é dado, nunca código |
| 10 | «Restaurar ao padrão» grava na hora o valor de fábrica (`item.padrao`) e só aparece quando o valor difere; «Não tocar» é outro gesto | «Restaurar ao Padrão e Aplicar» (21/09); grava na hora: sim de 26/10 |
| 11 | Revoga a caixa do sudo: a interface nunca pede senha; a senha é só do install, o root passa pela ponte, e o reparo da ponte também não pede (reserva de root e um oneshot que o polkit libera para a sessão local) | «a interface não pode pedir senha» (23/10); «Não quero recolocar senha direto» (24/10) |
| 12 | Trocar de pack leva o ponteiro do pack; o download aparece com o selo, sem pergunta | «o pack decide, o usuário pode fixar» |
| 13 | Tudo entra no pack: os nossos e os de terceiros com licença conhecida (linha no PROCEDENCIA). Uma versão por ícone, a escolhida em 23/10. Os projetos pessoais entram no Dracula | «Joga tudo pro pack» (15/10); sim de 23/10 |
| 14 | Três pastas por pack, planas: `icones/apps/`, `icones/sistema/`, `icones/biblioteca/`; o acervo do motor é o pack-base `meowsystem`, que todo pack herda | «no máximo três» (15/10) |
| 15 | Alterar um desenho do pack: tudo que deriva dele se atualiza sozinho (tema instalado, PNG por tamanho, cache, lançador, seletor), só o que mudou | «se auto atualiza» (15/10) |
| 16 | Os achados da varredura de 15/10: os desenhos Dracula do motor moram em `packs/dracula`; o Citrix veste o Ubuntu-selfservice (sim explícito de 23/10); as ligações perdidas voltam ao `apps.map`; desenho do pack vence o traço Arcticons em todo tamanho | «Joga tudo pro pack» (15/10) |
| 17 | Repositório enxuto e legível para IA: `AGENTS.md` versionado (exceção do sanitizador), zero comentário em código, um gancho de commit mantém isso | «AGENTS.md são exceção» (15/10); sim de 26/10 |
| 18 | Ações do painel (botões de Manter e Extensões): Executar e Restaurar; o resultado abre numa janela com OK, Guardar e Restaurar; «Ver sem mudar» no lugar de «Ver o que faria» fica no diálogo da ação, e os controles de ajuste não têm «Aplicar» nem «Ver sem mudar»: cada um grava ao soltar e a barra só desfaz; sem comando cru na tela | prints de 16/10; ajustes gravam ao soltar: sim de 26/10 |
| 19 | Cada pack tem o seu mascote em `packs/<id>/mascote/` (`mascote.dia`/`mascote.noite`): Coquinha e Mimir no `meowsystem`, os morcegos no `dracula` | pedido de 23/10 |
| 20 | O MeowSystem escreve o bloco marcado do terminal no `.bashrc`/`.zshrc` e o tira ao desinstalar; o equivalente do Spellbook sai pelo `assets/contratos/vizinhos.tsv` | pedido de 23/10 |
| 21 | O instalador baixa o que o Pop!_OS não traz: compilador e bibliotecas do que compila (`assets/pacotes/compilar.tsv`: applets, compositor, Menu do Arquivos), o Rust pelo rustup pinado (`assets/rust/rustup.pino`), fastfetch do PPA `zhangsongcui3371` | pedido de 23/10 |
| 22 | O tronco é só o `master` de `vitoriamariadb/MeowSystem`, cada bloco nasce dele, e o README aponta para lá | sim de 26/10 (troca do fork de 23/10); sim de 06/11: «Só master» |
| 23 | O install semeia o papel de parede da origem que o `pack.json` declara (`origens.wallpapers`) | pedido de 23/10 |
| 24 | Saem do tronco (o histórico do git guarda): `docs/folhas/`, `docs/pesquisas/`, a etapa do `catppuccin-apps`, `docs/sprints/` antigas, `docs/historico/` e todo teste, script ou documento que nada alcança | pedidos de 23/10 e 26/10 |
| 25 | Papéis de parede separados por pack: só a coleção do pack no ar gira; a imagem sem pack gira com qualquer um | pedido de 23/10 |
| 26 | O starship desce com o install (salvo recusa gravada); o doctor não o baixa: ausente é pulado de rotina | pedido de 23/10 |
| 27 | Pendência não aparece na tela; o que dá para consertar se conserta. O papel de parede devolvido fica devolvido, sem autorizar | show, don't tell; «Não deveria aparecer» (28/10) |
| 28 | Ícone enviado e retoque da oficina moram no estado de quem usa; o repositório só recebe pelo «Levar para o pack» | usar o produto não é commit |
| 29 | `hefesto` e `fogstripper` fora dos autorais dos packs; `ICONES_LOGO_HEFESTO` só da máquina, vazia de fábrica | decisão 4 |
| 30 | O lançador de fábrica não esconde Chrome, Steam nem github-desktop | são apps de quem usa |
| 31 | O Vesktop veste o Discord do pack; o traço do Firefox é `peach` | o azul é do Chrome |
| 32 | `Hidden=true` nas bases de ícone; o tema exportado herda `Cosmic,Adwaita` antes do `hicolor` | especificação freedesktop |
| 33 | Trocar de pack devolve ao lançador o que o pack anterior escondia; trocar de pack é um gesto só (`pack_usar`) | o pack decide |
| 34 | Noite com uma ponta só é recusada na gravação; o valor vazio chama «Automático»; folga e encaixe sem áreas mostram 0 | um nome por valor; sim de 06/11: vale o que o painel mostra |
| 35 | Um `ICONES_DRACULA="nao"` escrito fica, sem migrar | é escolha |
| 36 | O tema instalado continua `MeowSystem-Icons`; o exportado leva o nome do pack | é o nome que o COSMIC lê |
| 37 | O pack traz os sons do sistema (`sons/`), e a página Sons lista cada um para ouvir e trocar; carregador e bateria vão para `/usr/share/sounds/Pop` pela ponte root, e o pós-apt os repõe; um `SOM_*` do `meow.conf` só vale para o pack em que ela o mexeu | pedido de 26/10 (QA final, Q1-04) |
| 38 | Os gatos `coquinha` e `mimir` não se repintam; os 52 nomes do tema antigo sem desenho ficam fora; o índice do upstream fica como veio; o Discord escuro fica | é da arte, do upstream; só texto, nada no código a lê |
| 39 | Desenhos de pasta e de mimetype ficam na biblioteca do pack a que pertencem | decisão 3 |
| 40 | Nomes em inglês que vêm do `.desktop` do sistema ficam | é o nome do lançador; só texto, nada no código a lê |
| 41 | Alvo de pack que sai da raiz recusa o pack inteiro; nome torto é pulado e contado | sair da raiz é fuga |
| 42 | O `pack.py sincronizar` fica no verbo manual, com a guarda de mesma extensão | só compara arte com arte |
| 43 | O doctor não avisa do `NOPASSWD: ALL` nem consulta o sudo; a regra sai do sudoers depois do install, à mão do coordenador | segurança da conta; sim de 06/11: «Tirar a regra e o aviso» |
| 44 | O Light do tema segue o COSMIC instalado | o oráculo mostra a diferença |
| 45 | O README regera o que vem do código e as capturas do painel (headless, HOME temporário) no merge para o master e no push, nunca em cada commit | sim de 26/10 |
| 46 | As duas regras do «lado vestido» ficam: as duas passam pelo `derivar_flavor.par_do_outro_lado` no lado escuro, e o `tests/variante.sh` vigia | uma derivação só |
| 47 | O filtro `awk` do `_dracula_pares_do_mapa` fica como está | três testes extraem a função verbatim |
| 48 | Os leitores `${ICONES_BASE:-Papirus-Dark}` ficam | variável interna, o mesmo padrão em todo lugar; nenhum defeito medido |
| 49 | Uma chave ausente no binário não impede o escritor; o pré-voo (`scripts/cosmic_prever.sh`) acusa a chave que some | o COSMIC ignora a chave que não conhece |
| 50 | Os applets da casa (pinos em `assets/extensoes/`) compilam pelo doctor, com o selo «baixa da internet», sem pergunta (decisão 7); o repositório que o usuário adiciona na página Extensões só baixa e compila por gesto dele | pino é da casa, repositório de fora é código de terceiro (decisão 9) |
| 51 | O lixo do papel de parede apaga de vez, com uma pergunta, e anota o nome no `BANIDOS.txt`; num checkout git do programa, só se o nome está no `FONTES.tsv`, tira a linha dele e põe o nome no `BANIDOS.txt.padrao`, sem commit (foto dela fica só na lista dela); sem checkout, só o disco. O nome vale como bytes: emoji, acento e espaço casam. Sem Favoritas, sem «Levar para o tema», sem a aba Fora | pedido de 04/11 (AskUserQuestion); P168, com o sim de 06/11 (AskUserQuestion) |
| 52 | «Criar o meu tema» (`#novo`) gera um tema novo e termina em Disponibilizar; Personalizar (`#criar`) aprimora o tema no ar e grava nele: tema pessoal na casa dela, tema de fábrica em `packs/<id>/` do checkout git, sem commit; sem checkout, o botão diz o porquê | pedido de 04/11 (AskUserQuestion): «Pra um será o disponibilizar, outro vira aprimorar» |
| 53 | As áreas de trabalho valem juntas por padrão: `AREAS_MODO="juntas"` grava `workspace_mode: Global` na chave `workspaces` do `CosmicComp` e deixa no `pinned_workspaces` a lista numa tela só, sem repetida; `AREAS_MODO="independentes"` volta ao `OutputBound` com os mesmos nomes repostos em cada tela ligada. O install e o doctor aplicam o modo mesmo com `AREAS_NOMES` vazio, e o `cosmic-comp-sem-workspace-vazio.patch` tira a área vazia do fim também em Global | sem alfinete a tela mostra só a posição; pedido de 04/11 (cada tela); sim de 06/11: «mesmas duas áreas pros dois monitores ou manter agora mas impedir o 5 e que as duplicatas apareçam. isso vira correção e chave de feature», juntas por padrão e a chave para independentes; sim de 06/11 (AskUserQuestion): a linha no ramo Global e o modo sem nomes |
| 54 | Os Aprimoramentos gráficos são uma build própria, separada da do compositor: o `xdg-desktop-portal-cosmic` com a série de `patches/graficos.series` (a negociação do formato do PipeWire, #286, e a corrida do toolkit que congela a captura, #384), um shim que o drop-in aponta e que cai no pacote quando o build some, não confere ou cai repetido, e a policy do Chrome (`compartilhar-tela.json`, pela ponte root, só com o `google-chrome-stable` instalado). Correção de outro assunto cria a sua build; o SHM forçado não entra, é cura de máquina | sim de 06/11 (P159): «Cria outra build […] contendo tudo? as demais vai criando separado»; «tenho outros dois pcs com o mesmo problema» |
| 55 | Build do compositor com todos os `req`, marcadores e fumaça entra sem clique; a rede é o shim, e a queda na fábrica fica no log e no `meow doctor`, fora da tela | sim de 06/11: «Liberar sozinho» |
| 56 | O MeowSystem é dono do que escreve e se limpa sozinho: `assets/contratos/espaco.tsv` dá a cada caminho uma categoria (`reconstruível`, `backup`, `de quem usa`); o `.target` dos applets tem teto de 8 GB e perde por idade do artefato, do compositor e do menu do Arquivos ficam o build em uso e um anterior (cache, pronto e fonte guardado), os backups ficam 30 dias, com o `tema-PRIMEIRO`, os `-sistema` e o `meow.conf-antes-da-instalacao` sempre; nunca se corta o build em uso, nem durante um build, nem o que é de quem usa; o doctor mede e corta sozinho, a página Espaço da Central tem o Liberar, e o desinstalar apaga tudo o que é do Meow, diz quanto liberou e só guarda os backups com `--guardar-backups` | pedido de 06/11/2026 («a limpeza tem de ser contínua, e o app, consciente dos resíduos que deixa») e as decisões de 06/11/2026 da P165 |

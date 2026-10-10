# P77 — A interface mostra em vez de explicar (segunda onda, depois da P73)

**Branch:** `sprint/p77` · **Fontes:** `00-achados-como-usuario.md` (6, 8, 10–22, 25–30),
`01-regressoes.md` (U1–U7, L1, S2). **Skill obrigatória:** `hallmark` antes de desenhar.

## Pedido de quem usa
«A interface é moderna estilo show don't tell.» «Sem texto na interface. Máximo vira dica. Mas tem
que ser bem montado pra não gerar dúvida e ficar intuitivo.» «Controle de UI, UX e QA grande, fácil
de usar.»

## Tarefas
1. Sem parágrafo na tela: legendas «Desenho, não é a sua tela…», descrições de ajuste e de ação
   viram dica (tooltip/«?»); a clareza vem do arranjo, da prévia real e do estado visível.
2. Consolidar o que é uma decisão só: Dia e noite (um relógio para gato, tema claro e imagem
   escura), Logo do sistema (um seletor de gato com modo fixo/hora/rotação), variante+pack+claro/
   escuro, modo de leitura com UMA fonte de verdade (app × applet).
3. Tirar da tela de produto o que é do PC de quem fez (S2): «Logo própria do Hefesto», hash de
   commit e repositório do acervo, «ela/dela», caminhos `/mnt/Apate`.
4. Prévias reais: terminal (gato desenhado de verdade), modo de leitura (temperatura e textura
   aplicadas à imagem), painel/dock; a prévia flutuante da página Ícones para de cobrir o conteúdo.
5. Coerência: «descolado da borda» × distância 0; «Restaurar ao padrão» só quando difere; `30m` em
   campo de minutos; Lançadores (Steam como jogo, contagem); galeria do papel de parede no topo;
   card do pack clicável com detalhe legível; comando cru só no «ver comando»; balão que não cobre
   o vizinho (U3); dois botões «Restaurar ao padrão» e «Aplicar» (U2).
6. Carga inicial: nada de 7,5 s de tela vazia (esqueleto imediato, dados por partes).
7. **Gate de uso real (U7)**: um teste de navegador que percorre as 14 páginas como usuário e
   falha nos defeitos desta lista (texto longo, contradição, botão coberto, prévia vazia).

## Prova
- prints antes/depois de cada página em `.playwright-mcp/ux-p77/`.
- contagem de caracteres de texto visível por página cai (medida antes e depois).
- o gate novo falha no `dev` de hoje e passa na branch.

## Achados para a próxima leva
- `comandoCurto` (app.js) perdeu o último chamador quando a linha `code.cmd` do cartão de ação saiu; ficou com a nota, pela regra da casa.
- `.descricao-secao` (estilo.css) não tem mais quem a gere: o subtítulo da página virou o `?` do cabeçalho.
- A faixa da simulação do modo de leitura perdeu «quem pinta de verdade é o cosmic-comp»; a prévia real do item 4 decide o que fica.
- ~~`avisoDeCombinacao` e `avisoDeLado` (Cor e tela) ainda são frase visível: viram selo na reescrita da página.~~ Resolvido no grupo 1: os selos ⊘ e lua na linha do título, frase no topo da dica.
- ~~Início continua com 2 306 caracteres: o bloco «Próprio / herdado / do motor» do cartão do pack (achado 8, U1) é da página.~~ Resolvido no grupo 1: 966 caracteres, origem em selos e detalhe na linha inteira.
- `tests/app-acessibilidade.py` ainda isenta as «12 legendas de desenho»: elas saíram da tela, e a isenção pode cair.
- Grupo 1: os «Desenhos autorais do pack «Catppuccin»» oferecem `fogstripper` e `hefesto`, que são projetos pessoais (decisão 4, S2). É conteúdo do pack, não do painel.
- Grupo 1: em «Cor e tela», as ações «Trocar de tema» e «Passar para claro ou escuro» repetem a decisão da moldura e rodam na hora. São candidatas ao «⋯» de ações técnicas da direção (seção 4), que ainda não existe como componente.
- Grupo 1: o pack se escolhe em dois lugares com dois comportamentos: «Theme pack» em Cor e tela grava `PACK` e espera o «Salvar e aplicar», e o «Usar este» da Início roda o `pack_usar` na hora. O achado 11 fica pela metade até as duas portas dizerem a mesma coisa.
- Grupo 1: a marca `[avancado]` saiu de `LANCADOR_OCULTAR`. Ela nunca tinha efeito, e com o «⋯» de agora esconderia a lista que o achado 20 precisa ver. Quem reescrever Lançadores decide se ela volta.
- ~~Grupo 1: o resumo do topo («N mudados por você», `app.js` perto de `mexidas`) ainda conta a chave `sem_programa`, e a Início já não conta. Os dois números podem diferir por um numa casa que tenha a chave preenchida sem o Hefesto.~~ Resolvido no grupo 4 (`pintarResumo` faz a conta da Início).
- Grupo 1: a faixa da FORMA (Painel e dock) continua grudada na página inteira, de propósito, porque é o desenho do assunto. As outras faixas agora ficam na própria seção. Se Painel e dock também mudar, o `render` é o lugar.
- Grupo 2: o «Restaurar ao padrão» das chaves que aceitam vazio grava VAZIO («não toca»), e para a maioria (forma, vidro) vazio é mesmo o padrão. Em `RELOGIO_SEGUNDOS` o padrão é `nao`: o botão aparece com o valor já no padrão e grava outra coisa, com o nome errado. Precisa de dois gestos com dois nomes (voltar ao padrão do arquivo, devolver ao COSMIC), ou o botão gravar `item.padrao`.
- Grupo 2: `meow_estado_com_padrao` (lib/comum.sh) semeia o estado do papel de parede na primeira LEITURA, inclusive no `meow wallpaper` sem argumento, que só mostra. Com as ações técnicas no «⋯», «O carrossel agora» passou a ser o primeiro script da aba no gate e o achou; ficou em `DEFEITOS_CONHECIDOS` do `tests/app-completo.py`, com o endereço do conserto.
- Grupo 2: o desenho «No dock» (Logo do sistema) ainda usa um gato de traço genérico (`gatoDeTraco`). A mesma técnica do terminal (o SVG do acervo pintado pela página) poria o gato de verdade na ponta da dock.
- Grupo 2: «Pôr um gato no dock» e «Passar ao próximo gato» repetem a decisão da moldura do gato e ficam apagadas (⊘) em dois dos três modos. Candidatas a sair da tela ou a morar dentro da moldura, no modo que as usa.
- Grupo 2: a grade de três colunas deixa buraco quando um cartão de par de desenhos é mais alto que os vizinhos (Papel de parede, sob «Como a imagem ocupa a tela»). É da grade universal, não da página.
- Grupo 2: o «Instalar o starship» mudou de página (Manutenção → Terminal) e aparece mesmo com o starship instalado; a pendência `starship-ausente` já sabe quando ele falta e poderia apagar o botão.
- Grupo 3: o tema claro (`MODO_AUTO_CLARO_DE/ATE`) é hora cheia num deslizante de 0 a 23, ao lado de dois pares de `<input type=time>` no mesmo relógio. Uma régua de horas (ou o campo de hora com passo de 1 h, gravando só a hora) deixaria as três linhas com o mesmo controle.
- Grupo 3: «A noite começa às» preenchida com «A noite termina às» vazia não vale (o `meow_noite_janela` pede as duas pontas); a página agora mostra o ⊘ com o porquê, mas o arquivo aceita a meia escolha calado. O `validar_valor` poderia recusar o par incompleto, ou o `lib/noite.sh` herdar só a ponta vazia.
- Grupo 3: `previas-sistema.js` (`lerNoite`) e o `desenharNoite` do par «Separar imagens» ainda resolvem a noite do gato sem a janela do applet; o relógio e a Início usam o `janelaDoGato`. O desenho do par só mostra a imagem escura, então não mente hoje — mas é a terceira cópia da regra.
- Grupo 3: o applet do modo de leitura lê o ponto dos sliders (`ultima_*`) só ao nascer; depois do «Salvar e aplicar» o relógio e a tela seguem o painel no minuto seguinte, mas o interruptor do popup religa no ponto que o applet tinha na memória até ele reiniciar. Um `watch_state` no `src/applets/leitura` fecharia a última ponta.
- Grupo 3: o «Restaurar ao padrão (Sim/Não)» do `LEITURA_AGENDA` grava vazio («não toca»), com o nome do valor no rótulo — o mesmo defeito de nome que o grupo 2 anotou no `RELOGIO_SEGUNDOS`.
- Grupo 3: «Ver o que mudaria nos jogos do Heroic» (natureza `conferir`) fica aberto e «Pôr os jogos do Heroic no lançador» (`aplicar`) vai para o «⋯»: o par se separa. Candidatos a virar os dois botões da seção de jogos, como o «Conferir» e o «Arrumar» da Steam.
- Grupo 3: achado 20 (o lançador esconde Google Chrome, Steam e github-desktop) é o VALOR de fábrica do `LANCADOR_OCULTAR` (32 ids, de quando a lista saiu do código em 21/09), e só vale com «Arrumar o lançador» em Sim. Pode ser o par sistema × atalho do MeowSystem (o `appid_dock.sh` cita um invólucro do Chrome em `/usr/local/share`), pode ser gosto de quem fez: decisão de produto, não de interface. A lista continua visível (sem `[avancado]`).
- Grupo 3: «Ver o que mudaria nos jogos do Heroic» saiu uma vez com «SAIU NULL» no gate (uma corrida em quatro, sem mudança no script); intermitente, como o clique do jogo da Steam que o grupo 1 anotou.
- Grupo 3: `controlePorArea` (folga e encaixe por área) só existe com `AREAS_NOMES` preenchida; com as áreas do COSMIC na tela (vazio = «são suas»), os dois cartões continuam campo de texto até o primeiro gesto nas pastilhas. É honesto (o `areas.sh` se pula com a lista vazia), mas a folga em texto livre é o último campo cru da página.
- ~~Grupo 4: no gate completo (as 14 abas), o «O que está no ar agora» (`meow status`) passou a reprovar com «mudou 4»: `com.system76.CosmicTheme.{Dark,Light}/v2/{background,primary}` mudam na casa durante os 15 s dele. Ele não escreve sozinho (medido: `meow status` duas vezes numa casa nova, e depois de `doctor --consertar` e de `desfazer`, não muda nada), e a aba Instalação sozinha passa (`--aba Instalação`, duas corridas). O que mudou foi a ORDEM: no «⋯» ele roda depois do «Desinstalar» (ensaio) e do «Voltar ao tema de antes» (ensaio e de verdade), e antes rodava logo depois do «Consertar». Algum escritor do tema (os `derivar_*.py`) está rodando fora do gesto que o pediu e cai na janela do `status`; a causa não ficou achada nesta leva. No `af3159f`+grupos 1-3 o mesmo gate não tem a reprovação.~~ Resolvido na conferência (`c114d75`): o `chk_vidro` roda o `vidro.sh` em ensaio, e o remendo `vidro_janela.py` escrevia assim mesmo; num tema sem `frosted_maximized_apps` (o que o «Voltar ao tema de antes» devolve) ele mudava os 4 arquivos. Agora o ensaio só confere, com teste em `tests/vidro-do-cosmic.sh` (vermelho no código de antes).
- Grupo 4: a Atualização não mudou. «O que a atualização mudaria» é o ensaio do «Atualizar a máquina inteira» (natureza `mostrar`, mas procurado de propósito), e os dois são candidatos a um par «ver / aplicar» como o «Conferir» e o «Arrumar» da Steam, em vez de dois cartões soltos.
- Grupo 4: o desenho de seção sem chaves (`desenhoDaSecaoSemChaves`: Instalação, Atualização, Manutenção) ocupa a linha inteira com o desenho de 260 px à esquerda e o resto vazio. É da faixa comum, não das páginas.
- Grupo 4: no menu a 375 px (faixa horizontal), o balão não cabe à direita e vai para cima, sobre o campo de busca. Não cobre item do menu (a regra do U3), mas cobre a busca enquanto o rato está no item.
- Grupo 4: o `<select>` das chaves que aceitam vazio mantém a opção «— como está —» ao lado do novo «Restaurar ao padrão»: dois gestos para o mesmo vazio. A opção é o jeito de o `<select>` mostrar o vazio; tirá-la pede outro jeito de desenhar «como está» no seletor.
- Grupo 4: o gate de uso real confere o achado 19 (a Steam como jogo) e o 18 (o terminal só com o contorno) pelo que a casa de brinquedo consegue reproduzir: com a loja plantada, o `dev` de hoje não a põe na grade de jogos, e a prévia do terminal tem 27 traços (a moldura das células). Os dois ficam cobertos pelos testes da página (`app-navegador.py`, `um-cartao-por-jogo.sh`), não por este gate.
- Grupo 4: S2 nos documentos continua: as 362 linhas com `/mnt/Apate` e o «pedido dela» de `docs/` não são tela; o gate só olha o que a tela mostra (texto e campos).
- Conferência: o `scripts/vidro_janela.py` acha o tema em `~/.config/cosmic` cravado (`COSMIC_DIR`) e não lê o `MEOW_COSMIC_DIR` que o `vidro.sh` respeita; numa casa com o COSMIC noutro lugar, as duas metades da mesma chave olham pastas diferentes.
- Conferência: com `LOGO_MODO=""` escrito no meow.conf (a compatibilidade do `logo.sh` lê isso como `rotacao` se `LOGO_ROTACAO="sim"`, senão `hora`), a moldura «Gato do dock» não mostra nenhum gato, porque o `mostraNoModo` procura o modo vazio. O servidor já tem o modo efetivo (`_modo_do_gato`) e não o manda à página.
- Conferência: o «Restaurar ao padrão» das chaves que aceitam vazio e têm padrão de fábrica preenchido («Janelas lado a lado» = sim, «Ligar o modo de leitura no horário» = sim) aparece com o valor no padrão e grava vazio («não toca»). O achado 14 ficou resolvido para o vazio; o nome do botão segue o defeito que o grupo 2 anotou no `RELOGIO_SEGUNDOS`.
- Conferência: o clique no «Créditos» do menu (`menu · link externo`) estourou o tempo uma vez no gate completo e passou na corrida seguinte (`--aba Atualização`, que também roda o topo); intermitente, como o clique do jogo da Steam.
- QA de uso real: fora do padrão de fábrica, o «Restaurar ao padrão» das chaves com fábrica preenchida mostra o valor da MÁQUINA no parêntese («Restaurar ao padrão (Não)» com a fábrica em Sim, no modo de leitura) e grava o vazio. O caso «já no padrão» saiu da tela; o nome do gesto segue o achado do grupo 2.
- QA de uso real: a caixa de pergunta das ações com sudo tem um parágrafo de 4 linhas («Nada aqui pede, lê ou guarda senha…»). O gate de uso real não olha `<dialog>`; é a superfície de consentimento, e a decisão de encurtar é de quem usa.
- QA de uso real: saídas que mandam digitar dentro do painel: o `icones_apps_dracula.sh` («para ver agora… pkill -x cosmic-panel»), o instalador («Para completá-las: sudo -v && ./install.sh») e o doctor («conserto: LEITURA_COMPILAR=1 …», «para construir agora: meow files-menu build»). O «há divergências» do conferir ganhou o botão; estes não.
- QA de uso real: a casa real guarda `ICONES_FLAVOR="macchiato"` (herança do Dracula de antes da P74), e o doctor diz «123 tipos de arquivo já vestidos de Catppuccin macchiato» com o Dracula completo no ar. Migrar o valor ou perguntar é decisão de pack, não de tela.
- QA de uso real: o ensaio de trocar o Dracula pelo Catppuccin avisa que `CURSOR` e `ICONES_PASTAS` continuam citando o Dracula («Vestígio do pack»): a troca de pack sai pela metade numa casa que escolheu o ponteiro e as pastas do pack.
- QA de uso real: na casa real, o `CosmicBackground/v1/all` aponta para `ativos-noite` (uma pasta, não o carrossel); o `wallpaper.sh` corrige no primeiro gesto («isso não é o carrossel; devolvendo»), e o doctor não acusa.
- QA de uso real: os «Desenhos autorais do pack «Dracula»» também oferecem `fogstripper` e `hefesto` (a nota do grupo 1 era só do Catppuccin), e o doctor ainda cita `~/Desenvolvimento/hefesto-dualsense4unix/…` pela `ICONES_LOGO_HEFESTO` da casa real (S2).
- QA de uso real: a galeria do papel de parede tem a aba «Favoritos», e nenhuma imagem oferece o gesto de favoritar (o menu da imagem é Usar, Dia, Noite, Tirar).
- QA de uso real: «Usar este ícone» abre a gaveta e a página rola até o fim; o cartão do app que acabou de mudar sai de vista.
- QA de uso real: Manutenção tem dois «⋯» idênticos (ajustes técnicos e ações técnicas) sem nada que os distinga além do lugar; «Quantos backups guardar» e «Largura do nome da música» são campo de texto para um número.

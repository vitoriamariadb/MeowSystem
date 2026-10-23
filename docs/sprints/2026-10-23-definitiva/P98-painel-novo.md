# P98 — O painel novo de verdade, com tudo o que o antigo fazia

**Pedido de quem usa (23/10):** «temos que migrar tudo da interface antiga, mas modificando pro novo painel
que ficou incrível». O desenho é o mockup final da P97 (`docs/design/2026-10-23/final/`, e o `LEIA-ME.md`
com o mapa das páginas de hoje para as novas).

## A forma
- As 4 portas do mockup: **Tema, Criar tema, Ajustes, Cuidar**. Dia e noite fica dentro de Ajustes.
- **Clicar num tema já veste a máquina**, sem pedir nada (decisão de 23/10).
- **A interface NUNCA pede senha** (quem usa, 23/10: «a interface não pode pedir senha. vamos usar senha uma
  vez só no install»). Tudo o que precisa de root passa pela ponte (`scripts/ponte_root.sh`), que o
  `install.sh` instala com a única senha. Sem caixa de senha, sem selo «pede senha», sem `pkexec`. Se a
  ponte não estiver instalada, o painel mostra o estado e o botão «Conferir e consertar» (que a repõe),
  nunca um pedido de senha. Isso revoga a decisão 11 (caixa do sudo de uma linha), com o sim de 23/10.
- Os ajustes que o mockup deixou fora da tela entram num **«Mais ajustes» recolhido** no fim de cada página.
- **Nenhum texto explicativo na tela, em nenhuma aba** (quem usa, 23/10, sobre o mockup: «"pode baixar",
  "Outro computador — Leve suas escolhas num arquivo e vista a máquina nova igual a esta", fora o resto dos
  textões: a interface não tem isso. No máximo dica quando o mouse estiver sobre alguma opção. Moderno,
  minimalista, show don't tell»). Na tela ficam só: o nome curto da opção (uma a três palavras), o ícone, o
  controle e a prévia. Saem: subtítulos de página, parágrafos de cartão, frases sob títulos, selos de texto
  («pode baixar», «pede senha»), legendas de prévia, contagens explicativas e os botões «?». O porquê de cada
  opção vira **dica ao passar o mouse** (e ao focar pelo teclado), curta. Estado mostra-se com cor, ícone ou
  a prévia, não com frase. O mockup da P97 é a referência de layout e de visual, NÃO de texto: onde ele tem
  frase, a P98 tira.
- **Letra maiúscula no começo de todo texto da tela**: botão, rótulo, título, item de lista, dica, estado
  (quem usa, 23/10: «muita frase, botão ou palavra que inicia sem a letra capitular: "Tudo em ordem /
  conferido hoje, 07:00"»). Teste que varre os nós de texto visíveis e as dicas e reprova minúscula inicial
  (fora nome próprio de programa que é minúsculo de fato, numa lista curta e explícita).
- **A interface não se descreve; não é página de vendas** (quem usa, 23/10, sobre a tela «Mandar» do
  mockup). Saem, por exemplo: a árvore «O que vai no arquivo», o bloco «Quem ainda não tem o MeowSystem» com
  o `git clone`, a frase «Quem recebe abre o arquivo em…», a lista de conferência com contagens
  («Créditos e licenças junto 3»), o subtítulo «um tema para MeowSystem · por Vitória», o rodapé com licença e
  autoria e os links de rodapé («Estados da tela», «O que veio de onde»). Créditos e licença moram num
  único item de menu, não em toda tela. Regra: se o elemento explica o app em vez de ser usado, sai.
- **Alinhamento**: uma grade só por página; botões de uma mesma fila com a mesma altura e o mesmo estilo de
  família (nada de um botão cheio, um contornado e um só texto lado a lado sem hierarquia clara); cartões,
  faixas e controles alinhados à mesma borda (no mockup, a tira de cores solta à direita do cartão e o
  «Vestir este computador» como texto solto quebram isso). Prova: prints de toda tela em 1829x1029
  conferidos contra a grade.

## Nada se perde
Cada chave do esquema do painel de hoje e cada uma das ações tem um lugar no painel novo. A prova é uma
tabela gerada a partir do código (chave ou ação, página antiga, página nova) que fica em
`docs/design/2026-10-23/migracao.md`, com zero linhas sem destino. O `tests/app-completo.py` (o gate de
merge: toda aba, todo controle) e os outros `tests/app-*.py` passam a percorrer o painel novo.

## Criar tema
Entra o fluxo do mockup (Cores, Ícones, Papel de parede, Sons, Mandar), gravando um pack no formato de
três pastas planas em `~/.local/share/meowsystem/packs/`. O que o motor já sabe fazer (`pack.py`) é usado;
se algum passo precisar de motor novo grande demais, ele vira tarefa registrada, sem fingir na tela.

## Limites
- A P96 (reorganização) roda em paralelo e muda caminhos no `app/servidor.py` (gatos → mascote, temas de
  apps, papéis de parede). Esta sprint mexe no front (`app/pagina/`) e só ACRESCENTA rota no servidor
  quando precisar; não mexe em caminho de arquivo. Na tela, «Gato» vira «Mascote» (decisão da P96).
- Painel só com HOME temporário, PID próprio, nunca `--parar` (GSD).

## Como se prova
`tests/todos.sh` inteiro verde duas vezes; os `tests/app-*.py` no painel novo; prints em 1829x1029 de
todas as telas nos dois packs, comparados com o mockup, guardados FORA do repositório.

## Execução (23/10)

### O que entrou
- **`app/pagina/` reescrito** do mockup final: quatro portas (Tema, Criar tema, Ajustes, Cuidar); Ajustes com
  trilho de sete páginas (Painel e dock, Janelas e tela, Papel de parede, **Mascote**, Dia e noite, Terminal,
  Programas), cada uma com a prévia ao lado e o «Mais ajustes» recolhido no fim; Criar tema em cinco passos.
  O painel tinha 9.0 mil linhas de `app.js` mais 3,8 mil de prévias; agora são 4.010 linhas em oito arquivos:
  `lugares.js` (onde cada chave e ação mora: dado puro, lido também pelo teste), `app.js` (núcleo: estado,
  controles, trabalhos, busca), `paginas.js` (as quatro portas), `oficina.js` (aplicativos, oficina de ícone,
  autorais, papéis, jogos), `mesa.js` (a prévia, sem uma palavra dentro), `estilo.css`, `index.html`,
  `standalone.js` (a página exportada segue as rotas novas). Saíram `previas-tela.js` e `previas-sistema.js`.
- **Clicar no tema veste**: a variante do tema no ar grava o FLAVOR e aplica, sem pergunta; o outro tema roda
  o `pack_usar` sem pergunta. Destaque e claro ou escuro, na porta Tema, também vestem na hora.
- **Nenhuma senha na interface**: nenhum campo de senha, nenhum selo «pede senha», nenhum `pkexec`. Ação de root
  (`sudo` ou `pela_ponte` no esquema) sem a ponte abre «Falta a ponte» com um botão só, «Conferir e consertar»;
  o Cuidar mostra a ponte na faixa de estado. Decisão 11 revogada no registro e no GSD.md, com o sim de 23/10.
- **Sem texto explicativo**: nenhum `<p>` no conteúdo, nenhum subtítulo, legenda, selo de texto, contagem ou
  botão «?». O porquê de cada ajuste e ação (a primeira frase do `frase`/`ajuda` do servidor, até 110
  caracteres) é dica ao passar o mouse (800 ms) e ao focar pelo teclado (na hora). Estado é cor e ícone.
- **Maiúscula no começo** de todo texto da tela, das dicas, das opções e das torradas (as frases do servidor
  passam por `maiuscula`); a lista do que é minúsculo de fato é a `MINUSCULOS_DE_FATO` do `app.js`.
- **A interface não se descreve**: sem `git clone`, árvore do arquivo, rodapé de autoria e licença, links de
  rodapé, checklist com contagem, história do pack nem «Estados da tela». «Créditos» é um item do menu «⋯»
  do topo (com «Esta tela num arquivo»).
- **Uma grade por página**: Tema em quatro colunas (cartão de tema em duas), Cuidar em seis, Ajustes e Criar
  na grade trilho · prévia · controles; botões de uma fila com a mesma altura, um principal no máximo, nunca
  as três famílias juntas (o `app-uso-real.py` confere as linhas da grade e as filas).
- **Criar tema** pelo motor que existe: «Guardar» monta o CSV das 26 cores (as do flavor de partida com as seis
  trocadas por cima) e chama o `/api/pack-importar` já existente, que roda `meow pack importar` e grava em
  `~/.local/share/meowsystem/packs/<id>/` com `icones/{apps,sistema,biblioteca}`; o botão se apaga, com a
  dica, quando texto e fundo não têm contraste (o motor recusaria). «Baixar o tema» usa o `pack-exportar`
  (mede antes e pergunta pelas imagens); «Vestir» usa o `pack_usar`. Nenhuma rota nova no servidor.
- **Nada se perde**: `docs/design/2026-10-23/migracao.md`, gerada do código por `tests/migracao-do-painel.py`
  (que entrou no `todos.sh` e reprova linha sem destino): 122 chaves, 67 ações e 26 gestos, 0 sem destino.
  O «Ver sem mudar» (ensaio) continua no topo, na pergunta das ações que escrevem e na janela do trabalho.

### Os testes
- `tests/app-completo.py` (o gate) reescrito: censo de todo controle pelo `data-controle` (controle sem nome
  reprova), inventário tirado do `lugares.js` mais os moldes escritos no teste, e cada molde acionado uma vez
  pelo papel dele, nas 14 páginas e na barra de cima (busca, conta, Desfazer, Ver sem mudar, Rodar de
  verdade, pastilha, Parar, Guardar, Aplicar, menu, Créditos). Ação de root cobra «Falta a ponte».
- `tests/app-uso-real.py`: o que a pessoa vê (parágrafo, frase acima de 48, teto de 140, maiúscula no texto e
  na dica, autodescrição, linhas da grade, filas de botão, controle coberto, rolagem lateral a 1829 e a 375 px,
  prévia vazia, console) nas 14 páginas e nos dois packs; com `--fotos` guarda os prints.
- `tests/app-navegador.py`, `tests/app-acessibilidade.py` e `tests/app-texto-visivel.py` reescritos para o
  painel novo; `tests/gate-link-externo.py`, `decisoes.sh` (D10 e D11), `precisa-de-gente.sh`,
  `restos-do-painel.sh`, `app.sh` e `pack.sh` passaram a ler os arquivos novos.

### Números e provas
- `tests/todos.sh` inteiro, duas vezes seguidas depois do último commit de código, com a mesma linha:
  `== todos os 74 · 73 verde(s), 1 pulado(s), 0 vermelho(s) ==` (44 min e 36 min; o pulado é o
  `conversor.sh`, que pede um PNG de `assets/icones/catppuccin-apps/` que esta árvore não tem, e já pulava
  antes da P98). Uma corrida
  antes delas teve 1 vermelho, o seletor de arquivo do gate na página de ícones, curado em `4c5c1c5`.
- O gate sozinho: 1.266 conferências, 269 moldes acionados nas 14 páginas e na barra de cima (~18 min).
- `tests/migracao-do-painel.py`: 122 chaves, 67 ações e 26 gestos com lugar, 0 sem destino.
- `tests/app-texto-visivel.py` (a régua, não gate): 5.129 caracteres nas 14 páginas, 0 frases de 48 ou mais.
- Prints em 1829x1029 das 14 páginas nos dois packs (Catppuccin e Dracula), na janela e inteiras, fora do
  repositório: `.wt-meow/p98-prints/p98/` (do `app-uso-real.py --fotos`), mais `navegador/` e `completo/`.
- O que se confere com a mão: abrir o painel de verdade (`meow painel`) e passar pelas quatro portas; vestir
  uma variante do tema no ar; com a ponte instalada, vestir o outro tema; criar um tema e baixá-lo.

### O que ficou de fora, e por quê (tarefas registradas)
1. **O `--onde` do servidor ainda diz as abas de antes** (`onde_na_tela`, `ABA_INICIO`, `DESCRICAO_SECAO`): o
   `install.sh` fala «na aba Cor e tela». Trocar é mexer no `app/servidor.py` além de rota, e a P96 está nele;
   vai para depois que a P96 entrar: o `lugares.js` já tem a tabela que o servidor pode ler.
2. **A ponte não se repõe pelo «Conferir e consertar»**: o doctor não confere a ponte, e instalá-la pede a
   senha, que só o `install.sh` pede (`scripts/ponte_root.sh`). O painel mostra o estado e o botão, como manda
   a spec, mas o conserto da ponte precisa de motor (o doctor dizer «falta a ponte» e o caminho de repor sem
   senha na interface).
3. **O que o Criar tema não leva para dentro do pack**: os papéis de parede e os sons do passo são os da
   máquina; o formato de pack ainda não tem onde guardá-los (`pack.py novo` diz o mesmo). Os ícones vão para
   o tema pelo «Levar para o tema» da ficha de cada aplicativo (o motor da `/api/app-icone` com `pack`).
4. **Do mockup sem motor**: o interruptor «Tudo segue este horário» de Dia e noite, a lista «Sons de aviso» de
   Criar › Sons e as abas Sistema e Biblioteca de Criar › Ícones (ficou a grade de aplicativos, que é
   `icones/apps`, e a cor das pastas). Não foram desenhados para não fingir na tela.
5. **Saíram por serem texto que explica o app**: a história do pack (o `LEIA-ME` de vitrine), a linha de
   herança e as contagens do cartão, as folhas de `docs/folhas/` e a tela «Estados da tela».

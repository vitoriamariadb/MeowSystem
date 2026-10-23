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

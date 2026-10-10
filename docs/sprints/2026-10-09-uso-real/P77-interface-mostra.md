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
- Grupo 1: o resumo do topo («N mudados por você», `app.js` perto de `mexidas`) ainda conta a chave `sem_programa`, e a Início já não conta. Os dois números podem diferir por um numa casa que tenha a chave preenchida sem o Hefesto.
- Grupo 1: a faixa da FORMA (Painel e dock) continua grudada na página inteira, de propósito, porque é o desenho do assunto. As outras faixas agora ficam na própria seção. Se Painel e dock também mudar, o `render` é o lugar.

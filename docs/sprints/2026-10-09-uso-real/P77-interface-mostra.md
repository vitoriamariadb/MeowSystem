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

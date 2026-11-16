# Leva de 16/11/2026 — a interface soberana e a arte do Dracula

Texto de quem usa, 16/11 (foto da página Mascote, com a dica «Vale com «Como escolhe» em Girando», e duas fotos do
lançador): «pq eu tenho 4 workspaces? pq não consigo clicar em fixar? coisas tipo essa tooltip não podem ocorrer na
interface nunca. a interface é soberana. Aproveita e pega os svgs que escolhi pra setarmos o default do tema dracula.
e pusharmos e aproveita e cria novos botões de minimizar + maximizar e fechar? esse é nosso estilo de arte e nossa
pastas todas elas precisam ter a borda mais nitida e destacada.»

Pull: o `master` local já era igual ao `origin/master` (último push da Vitória, 11/11, já dentro).

| bloco | árvore | tarefas | agentes |
| --- | --- | --- | --- |
| A soberana | `../.meow-wt-soberana`, `bloco/soberana` | P204, P205 | implementa (agente high) → confere e corrige (agente high) |
| B arte | `../.meow-wt-arte`, `bloco/arte-dracula` | P206, P207, P208 | implementa (agente high) → confere e corrige (agente high) |

Arquivos disjuntos: A toca `app/`, `tests/`, `docs/DECISOES.md`, `bin/meow` (áreas); B toca só `packs/dracula/` e
os testes de ícone. Integração em `integracao/2026-11-16`, depois `master`, push.

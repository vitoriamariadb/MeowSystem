# Conferência final da leva (2 Opus)

As seis sprints entram em `integracao/qa-final` (o coordenador junta). Dois conferentes, cada um na sua
worktree a partir dela, com áreas disjuntas. Eles CORRIGEM o que acham, não só apontam.

| conferente | sprints | branch |
|---|---|---|
| A | P109, P110, P111 (aplicar, layout, textos) | `conferencia/a` |
| B | P112, P113, P114 (ícones, sons e temas, extensões) | `conferencia/b` |

## O que cada um faz
1. Lê `00-leva.md`, `ANDAMENTO.md` e as suas três sprints com a `## Execução`.
2. Refaz cada prova da Execução; uma prova que não roda não conta.
3. Percorre as suas portas como usuária, Playwright headless, 1920x1080 e 1280x800, HOME
   temporário: cada controle, cada botão, cada queixa original do ANDAMENTO.md da sua área.
4. Procura regressão entre sprints (o que uma desfez da outra no mesmo arquivo).
5. Corrige, com commit pequeno; `./tests/todos.sh` verde no fim.
6. Escreve `relatorios/conferencia-a.md` (ou `-b`): o que conferiu, o que corrigiu (commit), o que
   ficou para a usuária conferir com a mão (lista curta).

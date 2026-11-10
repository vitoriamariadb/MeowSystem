# Leva a casca do painel — regras comuns às sprints P184 a P198

Pedido de 10/11/2026, com seis fotos em `fotos/`. Leia este arquivo, o `ANDAMENTO.md` (respostas de quem usa e
blocos) e as suas sprints. O que não estiver coberto: o caminho que respeita o GSD.md, anotado em `## Execução`
no fim da sprint.

## Onde trabalhar
- A worktree e a branch do bloco estão na tabela «Blocos» do `ANDAMENTO.md`. Nunca o checkout principal.
- As linhas `arquivo:linha` citadas foram medidas em 10/11 no `master` (`a56ec133`); ache pelo nome da função
  quando a linha andar.

## Estilo
- Trabalho visual passa pela skill `hallmark` primeiro (CLAUDE.md, seção 6).
- Show, don't tell: na tela, nome curto, ícone, controle e prévia; o porquê vai na dica de hover e foco.
- **Todo nome se explica sozinho, sempre.** Quem lê só o botão sabe o que acontece ao clicar (pedido de 10/11:
  «o negócio não é autodescritivo, não pode ser, nunca»). Curto, sim; enigmático, nunca. A dica de hover
  completa, nunca substitui o nome.
- Toda palavra nova que aparece na tela sai do `GLOSSARIO.md` desta leva (P184). Palavra fora dele não entra.

## Provas
- `./tests/todos.sh` verde; o gate do painel pelo navegador junto.
- UI: captura antes e depois (skill `validação-visual`), com HOME temporário e PID próprio.
- O que só a sessão real mede (P194, P195) fica para quem coordena, depois do install.

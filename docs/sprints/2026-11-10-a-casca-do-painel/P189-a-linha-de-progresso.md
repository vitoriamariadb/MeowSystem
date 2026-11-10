# P189 — a linha de progresso no lugar da janela (10/11/2026)

Texto de quem usa: «vamos remover o pop up e adicionar uma linha de progresso abaixo do header que vai de uma
extremidade esquerda à direita.» Sim de 10/11 (AskUserQuestion): vale para TODA ação.

## O que se mediu

1. Toda ação passa por `rodar()` (`app.js`) e abre `<dialog id="resultado">` (`index.html:69-91`) com estado,
   saída, Restaurar, Guardar e OK. `LUGAR_JANELA` (`lugares.js`) lista Parar, Guardar e «Rodar de verdade».
2. A decisão 18 (`docs/DECISOES.md`) manda o resultado abrir nessa janela.

## A cura na origem

- O `<dialog id="resultado">` sai. No lugar, uma linha fina presa logo abaixo do header, de borda a borda,
  determinada quando a ação informa passos e indeterminada quando não.
- Parar vira um X no fim da linha. Fim bom: a linha some. Erro: aviso curto (`torrada`) com o nome da ação.
- Restaurar continua ao lado de cada ação que escreve (já está lá); Guardar sai (P191).
- «Ver sem mudar» (ensaio) mostra o resultado na própria linha da ação, sem janela; decidir na execução e anotar.
- Decisão 18 reescrita no mesmo commit, citando o sim de 10/11.

## Como se prova

- `tests/decisoes.sh` com a linha nova da 18.
- Gate do navegador: rodar Conferir; nenhum `dialog[open]`; a linha aparece, anda e some; Parar interrompe.
- Grep: `resultado-` e `LUGAR_JANELA` sem uso.

Tamanho: meio dia. Bloco B integra antes do A (o A usa o `rodar()`).

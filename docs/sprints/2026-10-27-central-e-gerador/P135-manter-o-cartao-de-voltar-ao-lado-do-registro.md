# P135 — no Manter, o cartão de voltar ao lado do Registro

Anotada em 28/10 (ela, com a captura do Manter: «ao lado direito do card [Registro] temos nada. Ali poderia ficar o
card do restaurar, tema de antes e desinstalar»).

## O que se mediu
- Na porta Manter, em duas colunas, a esquerda tem Sozinho, Registro e, embaixo, o cartão tracejado (Restaurar,
  Tema de antes, Desinstalar). A direita tem Ícones da máquina e, ao lado do Registro, um vão vazio.

## Cura na origem
- O cartão tracejado ocupa a coluna da direita, na mesma linha do Registro. Nada muda dentro dele. Numa janela
  estreita (uma coluna), a ordem continua: Registro e depois o cartão tracejado.

## Prova
- Captura headless (Playwright, HOME temporário) do Manter a 1920 de largura: o topo do cartão tracejado alinha com
  o topo do Registro, e não sobra vão na coluna da direita. A 800 de largura, uma coluna só, na ordem de antes.

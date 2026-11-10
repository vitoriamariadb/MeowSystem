# P186 — Sistema e Biblioteca trocam o ícone (10/11/2026)

Texto de quem usa: «eu não consigo alterar os ícones do sistema e nem os ícones da biblioteca.» Abas «Sistema» e
«Biblioteca» ao lado de «Apps» (foto 1).

## O que se mediu

1. Nada medido ainda além do relato. As abas existem; o gesto de troca não chega ao fim.
2. Provável mesma família da P185 (a oficina só sabe trocar ícone de app com `.desktop`). Confirmar lendo o
   caminho do clique até o servidor em cada aba.

## A cura na origem

- Mapear, para cada aba, o caminho clique → API → arquivo escrito, e consertar onde quebra.
- Se uma aba não tem destino possível (o ícone não é de quem usa trocar), ela não oferece o gesto. Nunca botão
  que não faz nada.

## Como se prova

- Gate do navegador: troca um ícone de Sistema e um de Biblioteca; o arquivo do tema instalado muda e a prévia
  mostra o novo.

Tamanho: 2 a 3 h. Depende da P185 (mesmo componente): mesmo bloco, depois dela.

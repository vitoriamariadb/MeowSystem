# P193 — sem versão do ponteiro (10/11/2026)

Texto de quem usa: «remove o versão de ponteiro».

## O que se mediu

1. `lugares.js:116`: `{ c: "CURSOR_VERSAO", r: "Versão do ponteiro", sub: true }` em Definir › Janelas e tela.

## A cura na origem

- A linha sai da tela. A chave segue no `meow.conf` com o padrão de hoje (o install não muda).

## Como se prova

- Gate do navegador: «Versão do ponteiro» ausente; trocar o Ponteiro continua funcionando.

Tamanho: 15 min.

# P188 — o sino se grava com nome e lugar (10/11/2026)

Texto de quem usa: «regravar nem permite salvar o negócio ou escolher o nome ou onde ele vai ficar ali no "Toca no
COSMIC". Tira o "Toca no" e coloca "Nativo do COSMIC".»

## O que se mediu

1. «Regravar o som» (`lugares.js:62`, `som_aplicar` em `servidor.py:3668`) só ressintetiza o sino do volume a
   partir das chaves `SOM_*` e grava por cima. Não pergunta nome nem destino.
2. O desenhador do sino (Primeira nota, Segunda nota, Duração, Pesos) e a lista de eventos («Toca no COSMIC»,
   `paginas.js:716-718`) são dois blocos que não se falam.

## A cura na origem

- O sino desenhado vira um som com nome, gravado no pack em edição, e com destino escolhido: qualquer evento da
  lista Nativo do COSMIC (volume é o padrão). Botão de nome que se explica (P184), sem «Regravar».
- Títulos dos grupos: «Nativo do COSMIC» e o par aprovado na P184 para «Toca nos apps».

## Como se prova

- Teste: gravar com nome X no evento Y escreve `sons/<Y>.oga` no pack e a linha Y mostra «Do pack».
- Gate do navegador: o fluxo inteiro sem diálogo nativo.

Tamanho: 3 a 4 h. Depende da P187 e da P184.

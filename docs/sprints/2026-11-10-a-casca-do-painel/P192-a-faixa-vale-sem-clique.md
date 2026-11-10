# P192 — a faixa vale sem clique (10/11/2026)

Foto `fotos/2-faixas-auto.png` (Definir › Forma). Texto: «todo slider desse jeito deixa ele ativo, sem precisar
clicar pra ativar.»

## O que se mediu

1. `controleFaixa()` (`app.js:538-560`): chave vazia pinta `data-vazio` (trilho pontilhado, «Auto») até o
   primeiro `input`. O controle parece desligado.
2. O valor que vale com a chave vazia já é conhecido: `valendo_agora`, `vazio_vale` ou `padrao`.
3. «Distância da borda» aparece apagada de verdade (depende de «Solta da borda»); isso é outro estado, fica.

## A cura na origem

- Sem `data-vazio`: a faixa sempre desenhada como ativa, na posição do valor que vale, com o número real na
  saída. «Automático» some da faixa; voltar ao de fábrica é o ↶ que já existe ao lado.
- Decisão 34 diz que o vazio chama «Automático»: conferir se vale só para seleção; se valer para faixa, reescrever
  com este pedido no mesmo commit.

## Como se prova

- Gate do navegador: nenhuma `.faixa[data-vazio]`; a saída mostra número em todas.
- Arrastar e soltar grava; ↶ volta a chave vazia e a faixa segue ativa no valor de fábrica.

Tamanho: 1 h.

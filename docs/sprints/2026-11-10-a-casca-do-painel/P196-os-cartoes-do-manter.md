# P196 — os cartões do Manter, repensados (10/11/2026)

Foto `fotos/3-cartoes-do-manter.png`: «Outro computador», «Atualizar», «Instalar de novo». Texto: «essa seção
inteira tá feia. Precisa ser repensada.»

## O que se mediu

1. `LUGAR_CUIDAR.cartoes` (`lugares.js:248-261`): três cartões de altura igual com conteúdo desigual. Um tem dois
   botões empilhados, outro três em fila, outro um só; sobra vão em cada cartão; a dica de «Atualizar» cobre o
   cartão de baixo.
2. Nomes que não se explicam: «Ver», «Limpar», «Instalar de novo».

## A cura na origem

- Skill `hallmark` primeiro (audit da seção). Proposta com duas opções de arranjo, mostradas a quem usa antes de
  codar (maquete HTML em `maquete/`).
- Nomes do glossário (P184), cada botão dizendo o que faz.

## Como se prova

- Maquete aprovada por quem usa.
- Captura antes e depois, larguras 1500 e 900 px.

Tamanho: meio dia, com a ida e volta da maquete.

## A escolha (11/11)

Sim de quem usa: «B: ladrilhos» (`maquete/manter-b.html`). Blocos clicáveis em duas colunas (uma no estreito),
separados por um fio com o nome do grupo; o bloco inteiro é o gesto, com ícone e nome; sem coluna de botões.
Os verbos «Atualizar», «Ver», «Limpar» somem: o nome da ação é o gesto. A dica no hover é a frase real da ação.

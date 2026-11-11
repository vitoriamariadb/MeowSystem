# P202 — o ↶ da faixa volta ao de fábrica do COSMIC (11/11/2026)

Sim de quem usa, 11/11: «Volta ao de fábrica do COSMIC (Recomendado)» e «Mostra o de fábrica do COSMIC (Recomendado)».

## O que se mediu (conferente do bloco C+D)

- Faixa com padrão vazio (ex.: «Canto arredondado da barra», `FORMA_RAIO_PAINEL`): o ↶ esvazia a chave, mas o
  `forma.sh` não mexe no valor do COSMIC. A faixa fica no número que está na máquina e o ↶ parece não fazer nada.
- Sem valor lido na máquina, a faixa mostra o mínimo da escala.

## A cura na origem

- Cada chave de faixa com padrão vazio conhece o valor de fábrica do COSMIC (medido no COSMIC, não inventado).
- O ↶ esvazia a chave E faz o script escrever o valor de fábrica do COSMIC na máquina; a faixa pula para ele.
- Sem valor lido, a faixa mostra o valor de fábrica do COSMIC, nunca o mínimo da escala.

## Como se prova

- Gate do navegador: arrastar, ↶, a faixa mostra o número de fábrica e o arquivo do COSMIC no HOME temporário
  tem esse número.
- Com o arquivo do COSMIC ausente, a faixa abre no número de fábrica.
- Segunda passada do script não escreve nada.

Tamanho: 2 h.

# P110 — a prévia manda: fixa, maior, fiel; nada vaza da tela

Leia `00-leva.md`. Itens: `relatorios/qa-2.md` Q2-01, Q2-02, Q2-03, Q2-08, Q2-09, Q2-10, Q2-11, Q2-12,
Q2-19, Q2-20; `relatorios/qa-3.md` Q3-01, Q3-03; `relatorios/qa-1.md` Q1-10.

## O que quem usa pediu
A zona da prévia ganha destaque e fica fixa no layout junto com o menu de cima e o menu da seção. A
tela fica mais larga e os itens do menu lateral viram uma barra horizontal ACIMA da prévia. A dock da
prévia tem que refletir os controles. Nenhum modal, cartão ou linha estoura a largura.

## Ordem
1. Q2-09 é o desenho: siga o ASCII de 1920 e de 1280 do relatório. Cabeçalho, abas da seção e prévia
   ficam `sticky` (Q2-08: o `sticky` hoje está no `ul` dentro de um `nav` do tamanho dele); os
   controles rolam por baixo. Em 1280 e em meia tela (~1500x900) nada some (Q2-11: a busca e o «/»).
2. Q2-01, Q2-02, Q2-03: cada controle de Painel e dock muda a prévia de verdade (pastilha, solta da
   borda, distância, cantos, espaço, vidro, tamanhos); Papel de parede, Dia e noite e Mascote também.
   Faça uma tabela controle → efeito na prévia e um teste Playwright que percorre a tabela.
3. Q2-12: Programas fica sem prévia, grade larga (decisão em ANDAMENTO.md).
4. Q2-10, Q2-19, Q2-20: linhas de duas colunas cabem no cartão em 1280 e 1550; um ↶ por coluna com a
   dica certa.
5. Q3-01: modal do «Instalar tudo» com `minmax(0,1fr)` e `pre` com quebra; botões sempre visíveis.
6. Q3-03: cartões de Manter (Outro computador, Atualizar, Instalar de novo) com o desenho à esquerda
   e título e botões ao lado.
7. Q1-10: ficha de ícone e oficina do Personalizar sem caixas aninhadas; um «Usar» só.

## Prova
Playwright headless em 1920x1080, 1550x860, 1280x800 e 1500x900: nenhum elemento com largura maior
que o pai (`scrollWidth > clientWidth`) em toda página; cabeçalho, abas e prévia visíveis depois de
rolar até o fim; a tabela controle → prévia passa. Guarde capturas em
`docs/sprints/2026-10-26-qa-final/capturas/p110/` (fora do git) e cite-as na Execução.

## Fora desta sprint
O que cada controle grava (P109), textos e renomes (P111).

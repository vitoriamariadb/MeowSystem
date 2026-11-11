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

## Execução

Causa medida: os cartões de Sistema e Biblioteca (`gradeDoAcervo`) eram `div` sem clique, e o `/api/criar` só sabia levar
desenho de outro pack (`de` + `nome`), nunca um arquivo de quem usa. O destino existe: `icones/sistema/<nome>.svg` e
`icones/biblioteca/<nome>.svg` do pack em edição.

Cura: cada cartão é um botão (`trocar:desenho`) que abre o seletor de SVG e grava pelo `levar_icone`; o cartão passa a
mostrar o desenho novo (no tema novo, o do pack, com «Trocado»). Sem tema guardado o botão fica desabilitado com o motivo.
Leitura minha: «alterar» é trocar por um SVG da pessoa; escolher entre os desenhos do acervo para um ícone de sistema não
foi feito.

Prova: `tests/personalizar-pagina.py` (as duas abas; o arquivo do pack muda e o cartão mostra o novo).

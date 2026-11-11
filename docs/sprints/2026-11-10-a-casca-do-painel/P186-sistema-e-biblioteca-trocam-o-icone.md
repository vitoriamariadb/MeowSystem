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
desenho de outro pack (`de` + `nome`), nunca um arquivo de quem usa nem outro desenho do acervo. Mais: o Sistema não guarda
o desenho pelo nome do ícone; o `sistema.map` aponta o nome para um desenho (no Dracula, 177 dos 301 nomes apontam para um
arquivo de outro nome; no meowsystem, quase todos), e os 123 tipos de arquivo do Dracula moram no meowsystem (herança).

Cura: cada cartão é um botão (`trocar:desenho`) que abre uma ficha como a dos apps: escolher um desenho do acervo do tema
(`trocar:opcao`, depois «Usar») ou «Trazer .svg». No Personalizar, o Sistema grava o desenho que o mapa usa
(`desenho_de_sistema`); o ícone cujo desenho mora em outro tema fica desabilitado, com o dono na dica
(`trava_de_sistema`). A prévia de arquivo leva a data do desenho na URL, para o cartão mostrar o novo. Sem tema guardado o
cartão fica desabilitado com o motivo. O tema instalado se refaz pelo `meow-derivados` (decisão 15).

Prova: `tests/personalizar-pagina.py` (Sistema: «Conexão segura» recebe o desenho do «Modo avião» no
`channel-secure-symbolic.svg`; Biblioteca; «Trazer .svg» nos dois; tipo de arquivo herdado desabilitado).

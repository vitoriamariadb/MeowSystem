# P203 — o acervo em três abas, com uma rolagem só (11/11/2026)

Texto de quem usa, 11/11 (foto da ficha do OBS Studio): «muito curto os icones da biblioteca e tem muita barra de
rolagem ali. não consigo escolher da biblioteca os icones do sistema que eu quero alterar»; e sobre os grupos
«Dracula · biblioteca», «Dracula · biblioteca (PNG)», «Dracula · autorais · alucard», «Dracula · autorais · dracula»:
«deveriam ser só 3 [...] na verdade nenhum deveria aparecer pq já existe as abas de apps sistema e biblioteca».

## O que se mediu
- Três rolagens aninhadas na ficha: o corpo da ficha, a `.tira-glifos` (360 px) e cada `.grade-glifos` (420 px).
- A ficha de um ícone do Sistema só oferecia desenhos do próprio Sistema; o servidor só achava a origem na pasta do alvo.
- O seletor do app agrupava por pasta de disco com o nome do acervo; o Sistema do tema nem aparecia nele.
- A pasta aberta fechava sozinha às vezes: o estado era gravado no evento `toggle`, que chega depois de um redesenho.

## A cura
- Uma rolagem só: dentro da ficha, lista e grade crescem; quem rola é o corpo da ficha.
- O seletor do app mostra Sugeridos e as três pastas do tema como abas (Apps, Sistema, Biblioteca), sem nome de acervo;
  o servidor diz a aba de cada grupo e o Sistema entra no acervo da ficha (`PASTAS_DA_FICHA`).
- A ficha do Sistema e da Biblioteca tem as abas Sistema e Biblioteca; um desenho da Biblioteca vira ícone do Sistema
  (`origem_pasta` no `/api/criar`).
- O estado da pasta grava no clique do `summary`, síncrono.

## Como se prova
`tests/personalizar-pagina.py`: três abas no seletor do app, nenhuma pasta com nome de acervo, a aba Sistema com os
ícones do sistema; a ficha do Sistema sem rolagem aninhada, com a aba Biblioteca, e um desenho dela gravado como ícone
do Sistema; a aba marcada sobrevive à escolha.

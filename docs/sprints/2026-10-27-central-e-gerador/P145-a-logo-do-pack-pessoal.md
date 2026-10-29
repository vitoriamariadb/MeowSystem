# P145 — o pack pessoal escolhe a própria logo

Anotada em 29/10, com captura dela do Tema: «no meu tema eu não consigo alterar o icone do meowsystem e nem definir
ou escolher qual eu quero».

## O que se mediu
- O cartão «Meu Meow-Portátil» no Tema mostra um «M» (a `logo.svg` gerada em
  `~/.local/share/meowsystem/packs/meu-meow-portatil/logo.svg`). Não há tela para trocar a logo de um pack pessoal.
- Com o pack pessoal no ar, a logo do programa (`_logo_do_painel`, `app/servidor.py`) segue esse «M».
- O `LOGO_PROGRAMA` (P138) existe em Personalizar › «No programa», mas só aceita nomes de pack com logo, longe do
  cartão onde ela procurou.

## Cura na origem
- A logo do cartão de um pack pessoal é clicável: abre uma grade com as logos dos packs instalados e os desenhos do
  mascote do acervo (o mesmo seletor visual do mascote), e «Abrir um arquivo» (SVG ou PNG). A escolha grava a
  `logo.svg` do pack pessoal (pack é dado; o pessoal mora no HOME), e a logo do programa acompanha quando o pack
  pessoal está no ar e `LOGO_PROGRAMA` está vazio.
- Pack que vem com o MeowSystem (`packs/`) não ganha o botão: a arte dele mora no pack.
- O `LOGO_PROGRAMA` aceita também a do pack pessoal e mostra as logos como grade, não como texto.
- Interface mostra, não explica: sem frase de ajuda; a grade e o realce do escolhido bastam.

## Prova
- Teste do servidor: gravar a logo do pack pessoal a partir de uma logo de pack, de um mascote e de um arquivo;
  arquivo que não é SVG/PNG ou grande demais recusa; `/logo.svg` segue a nova; segunda gravação igual não escreve.
- Teste de navegador headless (HOME temporário): clicar a logo do cartão pessoal, escolher o gato, e o cartão e o
  cabeçalho mostram o gato; os cartões Dracula e MeowSystem não têm o botão.

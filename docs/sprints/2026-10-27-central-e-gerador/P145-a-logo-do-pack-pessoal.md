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

## Execução

Três commits na `bloco/logo-p145`: `5d193470` (servidor), `69cf7740` (painel) e `a681253b` (testes).

- Servidor: o pack pessoal lista as opções (a gerada, a logo de cada pack e os desenhos do mascote, com prévia nas
  cores dele) e grava a escolhida em `logo.svg`. Pack que vem com o programa recusa (400). O arquivo aberto é SVG
  sem `script`, `on*` nem href externo, ou PNG (vira SVG vetorial, porque a capa da vitrine só aceita SVG); acima de
  512 KB recusa (413); SVG que não é quadrado fica centrado numa área quadrada. A escrita é atômica e a segunda
  gravação igual não escreve. Com `LOGO_PROGRAMA` vazio e o pack pessoal no ar, `/logo.svg` segue a logo dele.
- Painel: a logo do cartão do pack pessoal abre a grade (`.escolha`, o mesmo seletor do mascote) com a atual
  marcada, «Abrir um arquivo» e o erro na própria janela. Dracula e MeowSystem não ganham o botão.
- `LOGO_PROGRAMA` já oferecia as logos como grade (`previa: "logo"`, P138) e lista todo pack do disco; o teste
  confere que o pack pessoal entra na oferta e é servido.

Prova: `tests/logo-do-pack-pessoal.sh` (49 conferências) e `tests/logo-do-pack-pessoal-pagina.py` (27 conferências,
sem erro de JavaScript e sem pedido à internet), os dois entrando em `tests/todos.sh`. `tests/todos.sh` inteiro:
120 verdes e dois vermelhos, nenhum da P145.

- `readme.sh` (README velho e badge de versão fora de v2.2.0) falha igual na `dev` limpa (`3d86c17c`).
- `restaurar.sh` (`pack_usar` e `desinstalar`) é o vermelho aceito que a P146 cura.

### Conferência

O validador do `pack.py` já recusava `script`, `on*` em qualquer caixa, href e `javascript:` de fora, `foreignObject`,
`image`, entidades, `url()` e `@import` (até escapados) e `xml-stylesheet`. A rota pede token, host e origem, como as
vizinhas. Achados e correções:

- `9b86dc2e`: o `RE_ESTILO_PAPEIS` era quadrático numa corrida de espaços. Um SVG de 500 KB de espaços passava no
  validador, e depois cada `/logo.svg` levava minutos. Agora a busca só começa no início da corrida, com o mesmo resultado.
- `32d39a30`: a raiz do SVG agora se acha com `find`, porque o `<svg ` repetido sem `>` custava segundos. O PNG vai
  até 1024 de lado: um de 4096 cabia em 70 KB e levava 9 s e 140 MB. O parcial tem nome único (`mkstemp`): o nome fixo
  seguia um link plantado e escrevia fora do pack. A queixa leva a frase inteira, não a linha cortada.
- `99fc1581`: em Definir, a opção do pack pessoal no `LOGO_PROGRAMA` seguia com a logo velha, porque a URL não mudava
  e o Chromium reaproveitava a imagem. A versão da troca agora entra na URL.
- `719492e8`: provas do que está acima, mais pack em link, nome com `../`, `logo.svg` em link, validador e
  `vitrine.capa` depois da troca, o lançador seguindo a logo nova, 390 e 1280 px e a rota sem token, host ou origem.
  A busca do parcial que sobra agora usa `ls -A`.

`tests/todos.sh` inteiro deu 120 verdes, 0 pulados e 2 vermelhos, os dois aceitos: `readme.sh` e `restaurar.sh`.

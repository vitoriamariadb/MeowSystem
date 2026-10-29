# P143 — painel: a corrida do lote, o traço no Latte e os rótulos

Anotada em 28/10 (conferências da P130 e da P131), escrita em 29/10.

## O que se mediu
- `app/pagina/app.js`, `enviarLote`: um lote velho que volta depois de um novo apaga a `MUDANCAS` mais nova e a
  tela volta ao valor velho (`relatorios/conferencia-modificacoes.md:84`). É a causa do `tests/app-layout.py`
  instável com a máquina carregada.
- Com um flavor claro (Catppuccin Latte) no rascunho, as abas Sistema e Biblioteca pintam o traço dos ícones com o
  texto do Latte (`#4c4f69`) num cartão que continua escuro: contraste 2,1:1, 186 itens do Sistema abaixo de 3:1
  (`relatorios/conferencia-icones-sistema.md:82`).
- Nos cartões da aba Sistema, o rótulo corta antes do que distingue as baterias («Bateria 0%, carg…» e
  «Bateria 0%, carr…»).
- Os rótulos dos tipos de arquivo na aba Sistema estão em inglês («Zip», «Image», …).

## Cura na origem
- `enviarLote`: cada lote leva um número; a resposta de um lote mais velho que o último enviado não toca a
  `MUDANCAS` nem a tela.
- O cartão da prévia acompanha o flavor do rascunho (fundo claro com flavor claro), ou o traço usa a cor do
  pack que passa 3:1 no cartão; a escolha segue a maquete da leva anterior.
- Rótulo de bateria: a parte que distingue (nível, carregando, limite) vem primeiro, ou o rótulo quebra em duas
  linhas; nada some atrás de «…» na largura de 390 px nem na de 1280.
- Tipos de arquivo: o rótulo vem do nome em português (o `shared-mime-info` tem `comment` em pt_BR; ou um mapa do
  painel), sem inglês na tela.

## Prova
- Teste de navegador headless: dois lotes da mesma chave, o primeiro respondendo depois, e a tela fica com o valor
  do segundo; `tests/app-layout.py` verde três vezes seguidas com carga (`stress` ou laço de CPU).
- Contraste medido no navegador: com Latte, nenhum item do Sistema ou da Biblioteca abaixo de 3:1.
- Nenhum rótulo de bateria com reticências em 390 e 1280; nenhum rótulo em inglês na aba Sistema.

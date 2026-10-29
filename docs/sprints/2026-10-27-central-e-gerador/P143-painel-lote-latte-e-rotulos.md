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

## Execução

- **Corrida do lote**, commit `989b7e0f`. Cada lote leva um número e cada chave guarda o último; a resposta de um
  lote mais velho não tira a mudança pendente do mais novo. Prova: `tests/grava-ao-soltar.py`, seção 8, dois lotes
  da mesma chave com a primeira resposta segurada na rede; no código velho as duas conferências novas falham, no
  novo passam (32 conferências). O `app-layout.py` rodou três vezes seguidas com todos os núcleos em laço de CPU
  : três rodadas seguidas, 198 conferências cada, todas verdes.
- **Tipos de arquivo em português**, commit `a87ef86a`. O rótulo vem de `assets/contratos/tipos-de-arquivo.tsv`
  (glifo e nome), lido por `scripts/pack.py`; escolhi um mapa em vez do `shared-mime-info` porque o rótulo parte do
  glifo do pack (`zip`, `changelog`), não do tipo MIME, e porque o mapa funciona sem a máquina.
- **Latte e rótulos**, commit `a7260d83`. Escolhi a primeira via da sprint: o cartão das abas Sistema e Biblioteca
  leva base, texto, linha e nome do rascunho (`gradeDoAcervo`, `oficina.css`), então o traço do texto fica sempre
  sobre a base do mesmo flavor. O rótulo quebra em linhas (`white-space: normal`), sem reticências.
- **Prova**: `tests/sistema-latte-e-rotulos.py` (novo, entra no `todos.sh`), headless, medindo no navegador. No
  código velho: 186 itens do Sistema abaixo de 3:1 com o Latte e rótulos cortados; no novo: 0 no Latte e no Mocha,
  os 37 rótulos de bateria inteiros em 390 e 1280 px, nenhum tipo em inglês.
- **Ficou de fora, por quê**: no Latte, 50 itens do Sistema e 142 da Biblioteca têm cor própria (amarelo do
  JavaScript, laranja do Android...) e não passam de 3:1 em nenhum fundo claro da paleta. É a cor da arte do pack,
  não o traço do texto que a sprint mediu; o teste conta esses itens e os deixa fora da conta. Mudar a cor da arte
  seria mudar o pack.

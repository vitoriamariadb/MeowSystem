# P115: o gerador de ícones fecha a moldura e a barra mostra o valor

Itens 7, 8 e 9 do `ANDAMENTO.md` (fotos 4 e 5). Relatório: `relatorios/levantamento-painel.md` §3.

## O que se mediu
- **A régua.** Playwright headless, numa casa de teste com o app «Leitor de Brinquedo» aberto em Gerar. Nas quatro réguas (`#r-detalhe`, `#r-suavidade`, `#r-fracas`, `#r-minimo`) o `style --p` sai vazio. Com Detalhe em 6 e depois em 2, o preenchimento fica parado no meio. Captura: `capturas/painel/gerador-regua.png`, onde Detalhe 2 e Linhas fracas 0 aparecem com o lilás até a metade.
- **A moldura.** Medido no ícone do Cherry Studio (`com.cherry_ai.CherryStudio.png`, 512 px). A primeira coluna e a primeira linha têm alfa médio de 0,566, ou seja, o quadrado arredondado encosta na borda da imagem. A conversão de hoje dá 6 traços, só 3 deles retos, e os quatro cantos ficam soltos.
- **A folga.** Rasterizando com 6 px de borda transparente, a mesma conversão fecha o retângulo. Captura: `capturas/painel/moldura-hoje-e-com-folga.png`, hoje à esquerda e com folga à direita.
- **O alcance.** 7 dos 19 ícones de 256 px instalados nesta máquina encostam na borda de cima.
- **O caso extremo.** O ícone de brinquedo da casa de teste é um quadrado laranja que ocupa a imagem inteira. Os cinco cartões de traço (Fiel, Limpo, Silhueta, Detalhe, Área cheia) saem vazios, e a lupa também, porque o contorno inteiro está na borda (`capturas/painel/gerador-regua.png`). O conversor direto, num PNG 256 px opaco, dá `0 traços` e um `<g>` vazio.

## Causa
- **Régua:** `app/pagina/oficina.js:oficinaDeDesenho()`.
  - A `regua()` de dentro cria o `<input type=range>` e nunca grava `--p`.
  - O mesmo vale para o `r-glifo` do `pintarAjuste()`, no gerador circle.
  - O trilho (`app/pagina/estilo.css:183-188`) pinta `var(--p, 50%)`, por isso o preenchimento fica sempre no meio.
  - Só o `controleFaixa()` de `app/pagina/app.js` grava o `--p`.
- **Moldura:** `scripts/converter_icone.py:segmentos()`. A `moldura(a, b)` de dentro descarta todo segmento de fronteira que fica na primeira ou na última linha ou coluna. Um ladrilho que encosta na borda perde os lados retos, e só os arcos dos cantos sobrevivem.

## Cura na origem
1. Um só lugar que liga o preenchimento ao valor:
   - tirar de `controleFaixa()` a função que grava `--p` (`pct(valor, min, max)`);
   - usar essa mesma função em `regua()` e no `r-glifo`, ao criar e a cada `input`.
2. Fazer `rasterizar()` pôr uma margem transparente fixa na imagem, para o contorno de um ladrilho que encosta na borda ficar fechado.
   - As coordenadas voltam ao viewBox de 48 já descontando a margem, para o desenho não encolher.
   - A `moldura()` sai: com a margem, a borda da imagem nunca mais é borda de forma.
   - Um quadrado opaco de ponta a ponta vira um contorno quadrado, e não mais um desenho vazio.
3. Os dois primeiros consertos de uso do gerador, na ordem do relatório §3.2:
   - o histórico de «Desfazer edição» sobrevive à troca de traço; hoje `escolherCartao()` faz `OFICINA.historico = []` (`oficina.js:440`);
   - «Desfazer edição» ganha o par «Refazer», porque hoje não há pilha de refazer.

## Prova
- `tests/conversor.sh`, caso novo: um SVG de quadrado arredondado `rx=10` que encosta nas quatro bordas tem de sair como um contorno fechado.
  - Conferir que o `path` termina em `Z` ou que o primeiro e o último ponto coincidem.
  - Conferir que não há arco solto.
  - Um PNG opaco de ponta a ponta sai com 1 contorno, e não vazio.
  - Os casos de hoje (terminal com retas ≥ 1, btop com cantos ≥ 8) continuam verdes.
- Conferir com a mão o ícone do Cherry Studio: deve dar 1 contorno externo fechado.
- `tests/app-completo.py --aba criar/icones`, Playwright headless, numa ficha em Gerar: para cada régua, `getPropertyValue('--p')` tem de ser igual a `(valor-min)/(max-min)`. Medir ao abrir e depois de 4 `ArrowLeft`.
- Desfazer: desfazer, trocar o traço e voltar, e desfazer de novo restaura o passo anterior.

## Arquivos
`scripts/converter_icone.py`, `app/pagina/oficina.js`, `app/pagina/app.js`, `tests/conversor.sh`,
`tests/app-completo.py`.

## Fora desta sprint
- Zoom com grade e keyline, controle de espessura do traço, consistência em lote entre apps, exportar o SVG, e as mesmas réguas no gerador circle: ver «Anotado para depois» no relatório.
- Vocabulário (P118).

## Execução
- **Moldura** (`aa02c0f8`). `rasterizar()` ganhou `margem` e `toca_borda()`: só a imagem que tem alfa ≥ 128 na borda é rasterizada de novo com 6 px transparentes, e `emitir()` desconta a margem para o contorno cair no viewBox de 48 sem encolher. A imagem que já respira não muda um byte (a prova `--polilinha` do GIMP e a `--peso-fronteira 0` seguem verdes). `segmentos()` perdeu a `moldura()` fixa: ela só roda para a classe de fundo (`aparar_borda`), porque a classe de fundo é a única que ainda encosta na borda da imagem depois da margem.
  - Prova: `tests/conversor.sh`, 3 casos novos (quadrado `rx=10` de borda a borda sai com 1 `path` fechado, `Z`, de 0 a 48, 4 retas; PNG opaco de 256 px sai com 1 contorno fechado, e não mais vazio). Os 3 ficam vermelhos no conversor antigo. Casos antigos (terminal, btop, GIMP, trava) verdes.
  - À mão: o Cherry Studio (512 px) saía com 6 traços, 3 retos, cantos soltos; agora sai com 3 traços, o primeiro é o contorno externo fechado.
  - Decisão do coordenador: moldura sempre fechada, sem botão com/sem.
- **Régua** (`b024236c`). `pctDaFaixa()` e `ligarPreenchimento()` em `app.js` são o único lugar que grava `--p`; `controleFaixa()`, as quatro `regua()` e o `r-glifo` do gerador circle usam. Prova: `tests/app-completo.py --aba criar/icones` (`h_gerador_da_ficha`) mede `--p` contra `(valor-min)/(max-min)` ao abrir, depois de 4 setas e depois da oficina se redesenhar; contra o código antigo o teste dá 20 achados. O `r-glifo` do Dracula entrou em `tests/icones-por-pack.py`.
- **Desfazer e Refazer** (`b024236c`). `novoPasso()` empilha o SVG atual (sem repetir o topo, teto de 60) e zera a pilha de refazer; `escolherCartao()`, `reguar()` e `regerar()` deixaram de zerar o histórico. Botão «Refazer» (`oficina:refazer`) ao lado de «Desfazer edição». Prova: no mesmo `h_gerador_da_ficha`, três traços diferentes: desfazer volta ao traço de antes, desfazer de novo volta ao anterior, refazer devolve, desfazer-trocar-desfazer restaura, e um passo novo zera o Refazer.
- Fora: nada do que a sprint listou como «fora». As ferramentas de borda (zoom com grade, espessura, lote, exportar) seguem anotadas no relatório.

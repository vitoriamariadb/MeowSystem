# P268 — o fastfetch avisa em toda passada e diz uma frase que não vale mais (23/11/2026)

## O que se mediu (nitro-5, 23/11)
- Etapa 51 do install, única linha `!!` das 416 da saída: `altura aparada: 12 linhas sairiam 68% fora da proporção
  da célula (esticado)`, seguida de «usei 37 linhas para 95 colunas» e «guardei o seu 12». A etapa fecha `ok` e
  conta como «confere»; o doctor diz `logo ANSI conforme (95 x 37 células, quad)`.
- O `meow.conf` daqui tem `FASTFETCH_LOGO_LINHAS="12"` e `FASTFETCH_LOGO_COLUNAS="95"`. O aviso sai igual em toda
  passada.
- Na mesma etapa: «o MeowSystem não lê nem escreve arquivo de shell — essa linha é sua»
  (`scripts/fastfetch_logo.sh:782`). A etapa 52 escreve o bloco marcado no `.zshrc` (decisão 20).

## A causa
`scripts/fastfetch_logo.sh:767` avisa sempre que a altura pedida difere da usada, mesmo quando o logo já está
gerado na altura aparada e nada vai mudar. A frase da linha 782 é de antes da decisão 20.

## A cura na origem
- O aviso sai só na passada que apara e reescreve o logo. Com o logo já gerado nessa altura, a linha é `ok` e diz
  as duas alturas. Sim de quem usa, 23/11/2026 (silenciar o aviso repetido).
- A frase da linha 782 passa a dizer o que vale hoje: quem chama o `meow-fetch` é o bloco do terminal.

## Como se prova
- Teste do `fastfetch_logo.sh`: primeira passada com altura fora da proporção avisa e escreve; a segunda não avisa
  nem escreve; trocar as colunas volta a avisar uma vez.
- `tests/nada-manda-digitar.sh` e `tests/frases-velhas.sh` seguem verdes.
- No nitro-5: `./install.sh` sem nenhuma linha `!!`.

## Nos três PCs
Aparece onde o conf pede altura fora da proporção; a medir no desktop e no portátil.

## Feito (23/11, bloco `install-ruido`)
- O aviso só sai na passada que reescreve o logo; na seguinte vira uma linha `ok` com as duas alturas. Não há estado
  novo: o próprio logo em disco é o estado. Prova: `tests/fastfetch-altura.sh` (primeira passada avisa e escreve, a
  segunda não faz nenhum dos dois, trocar as colunas avisa de novo uma vez).
- Falta medir no desktop e no portátil, no install da P284.

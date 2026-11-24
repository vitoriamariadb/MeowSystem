# P270 — etapa que imprime «--» conta como verde, e três textos tortos (23/11/2026)

## O que se mediu (nitro-5, 23/11, saída do `./install.sh`)
- `escala`, `jogos` e `jogos_heroic` imprimem `--` («ESCALA_TELA vazia», «Steam não instalada — nada a fazer») e
  entram em «confere». `vigia_steam` e `vigia_heroic`, com a mesma causa, entram em «pulado». `leitura`, que é
  escolha de quem usa («Agendar: desligado»), entra em «pulado».
- `tipos de arquivo já com o Dracula dracula` (`scripts/icones_mimetypes.sh:96` e `:135`: nome do acervo e flavor
  colados).
- `carrossel já configurado (4 de 20 imagens (grupo de dia), a cada 5m, aleatoria)`: parêntese dentro de parêntese.
- O qBittorrent sai em duas linhas `ok` seguidas com o mesmo conteúdo.

## A causa
O código de saída de cada script decide a coluna, e os scripts não seguem uma regra só para «não há o que fazer
aqui». Os textos são de três scripts diferentes, cada um com a sua montagem de frase.

## A cura na origem
- Uma regra: app ausente e chave vazia devolvem 3 (pulado); escolha de quem usa que o script respeita devolve 0
  (confere) e imprime `ok`. Aplicar a `escala`, `jogos`, `jogos_heroic` e `leitura`, e conferir as outras etapas
  contra a regra.
- Os três textos corrigidos no lugar.

## Como se prova
- Teste que roda cada etapa com o app ausente e cobra `--` com código 3, e `ok` com código 0.
- `tests/numeros.sh` e os testes do README seguem verdes (o README conta etapas e conferências).
- No nitro-5: no «Resultado» do install, toda etapa que imprimiu `--` está em «pulado».

## Nos três PCs
Vale nos três.

## Feito (23/11, bloco `install-ruido`)
- App ausente e chave vazia devolvem 3 (pulado); escolha respeitada e estado já certo devolvem 0 com `ok`. Mudaram
  de 0 para 3 o `escala.sh`, o `jogos_steam.sh` e o `jogos_heroic.sh`; os quatro `vigia_*` só trocaram `--` por `ok`.
- Quem chama e o que faz com o 3, conferido um a um: as unidades `meow-steam` e `meow-heroic` já tinham
  `SuccessExitStatus=1 3`; o install conta como pulado; o doctor mostra `--` sem subir o veredito. O painel pintava
  de vermelho um conferir pulado (`app/pagina/app.js`): passou a neutro, com teste no `tests/app.sh`.
- Os três textos tortos e a linha `ok` repetida do qBittorrent. Prova: `tests/etapa-sem-pulo-verde.sh` (12 falhas
  antes), e cada defeito plantado numa cópia reprovou.
- Falta medir no install do nitro-5: nenhum `--` contado como verde no fecho.

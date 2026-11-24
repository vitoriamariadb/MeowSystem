# P291 — um nome só por papel de parede (24/11/2026)

## O que se mediu (24/11, na conferência do bloco `papeis-origem`)
Cada uma das 13 imagens do acervo do Dracula tem quatro nomes:

| quem | nome | exemplo |
| --- | --- | --- |
| a semente do repositório | `<tema>-<nome>.png` | `catedral-agulhas.png` |
| o `BANIDOS.txt.padrao` | o nome do desenho solto | `folios.png` |
| o `BANIDOS.txt` de quem usa, hoje | `tulip-<tema>-<nome>.png` | `tulip-catedral-agulhas.png` |
| a tradução da migração (`pack.py papeis-de-antes`) | o nome solto | `agulhas.png` |

- Um `meow wallpaper semear` explícito devolve as 13 que quem usa baniu no nitro-5.
- Em casa nova com rede, os cinco banidos de fábrica entram.
- Depois da migração a mesma arte pode ficar com dois nomes na pasta do pack.
- O install não dispara o defeito, porque só chama o `semear-se-faltar`, que para no primeiro arquivo já semeado.

## A causa
A P285 passou o nome do disco para «sem prefixo», traduzindo pelo nome do desenho solto do repositório. Em seguida
a origem do Dracula passou a ser o repositório dos PNG, que grava outro nome. Cada bloco passou nos próprios testes.

## A cura na origem
Um nome por imagem na pasta do pack: o que a origem de hoje grava. A tradução da migração (arquivo, `BANIDOS.txt`,
`lado.tsv`, vistas, luz e fixação), o `BANIDOS.txt.padrao` e o `lado.tsv.padrao` se alinham a ele. Os seis pares
não mudam de nome.

## Como se prova
- Base antiga com os 13 `tulip-<tema>-<nome>.png`, alguns banidos: migra; `semear` explícito com a rede falsa;
  nenhum banido volta, nenhuma imagem aparece com dois nomes, a contagem bate.
- Casa nova com rede: os cinco banidos de fábrica não entram. Segunda passada não escreve.
- Decisão 27 («o apagado fica apagado») segue com prova em `tests/apagar-papel.sh`.

## Feito (24/11/2026)
Na branch `bloco/papeis-origem`, integrado em `803b9a49` (`c1e2b285`, `8b64264a`, `61feca02`).
- No pack que declara `repo`, a tabela dos caminhos de antes só vale para os papéis do `papeis.tsv`; o resto perde
  só o prefixo, que é o nome que a semente grava. O `BANIDOS.txt.padrao` recusa pelos cinco nomes da semente.
- Provado contra a árvore real do pino: base antiga com os 19, quatro só no banido; depois de migrar e semear, 15
  arquivos, 15 conteúdos distintos, nenhum banido de volta. Casa nova: 14, sem os cinco de fábrica.
- Com o `papeis.tsv` ausente ou torto, a migração para antes de mover qualquer coisa. Os temporários da migração
  nascem por `mktemp`.
- Antes do install, em cada PC, a conferência só de leitura do `relato-conf-nomes.md`.

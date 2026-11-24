# P276 — o comentário em arquivo de dado e o conf de fábrica (23/11/2026)

## O que se mediu (catálogo de 23/11)
- 16 arquivos de dado têm mais de metade das linhas em comentário: 4133 linhas de 4598.
- `meow.conf.exemplo`: 2202 linhas, 134 chaves, 1936 de comentário (121 dos 125 KB).
- Três mapas do pack `meowsystem` têm zero linha de dado e seguem lidos: `apps.map` (161 linhas, lido em
  `icones_apps_arcticons.sh:17`), `apps-hicolor.map` (99, `completar_icones.sh:50`) e `bandeja.map` (322,
  `derivados.sh:49`). As etapas 33 e 34 do install nunca aplicam nada em pack nenhum.
- `assets/apps/appid.map` 137 de 145; `apps-arcticons.map` 410 de 434; `pastas.map` 289 de 303.
- Os dois `pack.json` levam 71 notas `_*`: 29 KB, 77% do arquivo do Dracula. O `pack.py` só lê chave sem `_`
  (inferência, por `pack.py:1197-1207`).
- `scripts/comentarios.py:41-58` trata `.map`, `.tsv`, `.conf` e `.exemplo` como «inteiro» e não corta nada.
- `scripts/migrar_conf.py:285` leva o bloco de comentário junto quando põe chave nova no conf de quem usa, e o
  `app/servidor.py` lê o `meow.conf.exemplo` para valor de fábrica e esquema (`:185-198`, `:517`, `:1368`).

## A causa
A regra «zero comentário» foi aplicada ao código pelo gancho, e o gancho pula arquivo de dado. O porquê de cada linha
de mapa ficou no próprio mapa em vez de no commit e no teste.

## A cura na origem
1. Medir primeiro o que do `meow.conf.exemplo` é lido de dentro do comentário (as opções `# sim | nao`, a dica do
   painel). O que for dado vira coluna de contrato; o que for explicação já mora na dica do painel
   (`app/pagina/lugares.js`).
2. O `meow.conf.exemplo` fica com as chaves e o valor de fábrica. O `migrar_conf.py` deixa de levar comentário; o
   conf de quem usa não é reescrito por isso.
3. O `comentarios.py` passa a cobrir arquivo de dado; os mapas ficam só com dado.
4. Mapa sem dado nenhum sai, com o leitor dele. As etapas `icones_bandeja` e `icones_tray_steam` saem se nenhum pack
   declara bandeja; o README e o `tests/numeros.sh` acompanham a contagem de etapas.
5. As notas `_*` dos `pack.json` saem; o que explica campo de pack mora no `docs/PACKS.md`.

## Como se prova
- Teste novo: nenhum arquivo de dado versionado tem linha de comentário, fora shebang e licença.
- `tests/chaves-aposentadas.sh`, `tests/flavor-padrao.sh`, `tests/app.sh` e os que leem o conf de fábrica verdes.
- No palco: o painel mostra as mesmas dicas e as mesmas opções de antes em cada ajuste.
- `./install.sh` numa casa com conf antigo: nenhuma chave some e nenhuma linha de quem usa é reescrita.

## Nos três PCs
O conf de cada PC fica como está. Só o de fábrica encolhe.

## Feito (23/11, bloco `comentarios-e-tabela`, integrado em `bdd5232a`)
- As notas `_*` dos dois `pack.json` saíram (71 chaves; nenhum código lia alguma), e o `docs/PACKS.md` ficou com o
  que os blocos de apps e o mascote diziam.
- O `scripts/comentarios.py` passou a cobrir arquivo de dado. 20 arquivos (`.map`, `.tsv`, `.conf`) ficaram só com
  dado: as linhas de dado são idênticas e na mesma ordem antes e depois. Ficam os três comentários que são dado
  (`#!cor-por-categoria`, `#!meow:usuario` e o `# app:` antes da linha do `apps-convertidos.map`) e o `#` depois
  do dado. Prova: `tests/dado-sem-comentario.sh`.
- O `apps.map` e o `apps-hicolor.map` do pack `meowsystem` saíram, sem uma linha de dado; a saída dos três scripts
  de ícone é byte a byte a de antes.
- Parado, à espera de decisão de quem usa: o comentário do `meow.conf.exemplo`. Ele é o esquema do painel (131
  títulos `# @`, 131 frases `# >`, 17 seções, as opções e o texto de ajuda). A medida de 1936 linhas de «peso
  morto» desta tarefa estava errada.
- Anotado: `assets/apps/jogos-fora.map` só fica com os 77 comentários porque não tem dado; a primeira linha que o
  painel escrever nele deixa `dado-sem-comentario.sh` vermelho.

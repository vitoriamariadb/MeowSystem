# P168 — a faxina dos papéis de parede (06/11/2026)

Achados de 04/11, no fecho da P157. Produto: vale para todo PC com papel banido.

## O que se mediu

- Uma banida sobrou: `Cyberpunk Neon Cat Wallpaper …`, com dois emojis no nome. O `limpar_banidos` e o `banir` pulam nomes fora do ASCII.
- Num checkout, o lixo põe no `BANIDOS.txt.padrao` até foto de quem usa, que o `semear` nunca baixa.
- Cópias em `banidos/` fora do `BANIDOS.txt` nunca saem.
- O `BANIDOS.txt.padrao` tem lixo (`.meow.XXXXXX`, linha vazia), e o `FONTES.tsv` lista nomes já banidos.

## A cura

1. `limpar_banidos` e `banir` tratam o nome como bytes: emoji, acento e espaço casam.
2. O padrão só recebe nome que está no `FONTES.tsv`.
3. O que está em `banidos/` e não está no `BANIDOS.txt` sai.
4. Limpar o `BANIDOS.txt.padrao` e tirar do `FONTES.tsv` o que está banido.

## Como se prova

Teste em HOME temporário com nome com emoji; a segunda passada não escreve nada.

## Execução

Commits `9330d0a3` e `c8846793` (do conferente). Escolhas onde a sprint calava:

- Item 1: a causa estava na etapa das banidas, não no `grep`. O `reconciliar_banidos_pasta` pulava por regex o nome com emoji, e o `limpar_banidos` só apaga o que está no `BANIDOS.txt`; tirei a regex. Todas as leituras do `BANIDOS.txt` passam a `LC_ALL=C grep -qxF` (nome como bytes).
- Item 2: o `cmd_banir` calcula `na_fonte` (o nome é linha do `FONTES.tsv`) antes do ensaio. Só então tira a linha e põe o nome no `BANIDOS.txt.padrao`; o ensaio e a mensagem dizem o mesmo. O cabeçalho do `.padrao` que justificava «só ASCII» foi reescrito no lugar.
- Item 3: as cópias em `banidos/` fora da lista entram na lista e saem na mesma passada, link inclusive. A que também está em `ativos/` é a devolvida: a cópia sai e ela segue em `ativos/`, sem entrar na lista (decisão 27). O teste 3 dizia o contrário e foi reescrito: era o resto do item 3 que nunca saía.
- Item 4: `.padrao` sem as 12 linhas vazias ou `.meow.XXXXXX`; `FONTES.tsv` sem as 37 fontes banidas (47 para 10 linhas). Na origem do lixo: o `reconciliar_sumicos` contava o temporário `.meow.XXXXXX` de `ativos/` como imagem que sumiu e o bania; ele agora não entra na conta, nem quando já estava na `wallpaper-vistas.txt` da máquina.
- Decisão 51 reescrita no lugar (só o nome do `FONTES.tsv` vai ao padrão; nome é bytes), com a base «P168 de 06/11»; prova nova em `tests/decisoes.sh`.

Provas (HOME temporário, falsos no PATH):

- `tests/apagar-papel.sh` com o código velho: `FALHOU: a etapa das banidas deixou cópia em banidos/ (rc=1)`, `FALHOU: a foto dela entrou no BANIDOS.txt.padrao ou não saiu do disco`, `FALHOU: o arquivo temporário virou banida`, `apagar-papel: 3 falha(s)`.
- Conferente, com os casos novos no teste e o `wallpaper.sh` de `9330d0a3`: `apagar-papel: 5 falha(s)` (cópia da devolvida em `banidos/`, link que fica, `.meow.Velho1` da vistas antiga virando banida).
- Com o código novo: `apagar-papel: tudo ok`, rc=0, incluindo 3b a 3e: nome com emoji (bytes `\xf0\x9f\x90\xb1`), acento e espaço apaga e entra na lista, `a segunda passada não escreve nada (ensaio rc=0, de verdade rc=0)`, e `o padrão não tem linha vazia, temporário nem repetida, e nenhuma fonte dele está banida`.
- Rodados também, verdes: `wallpaper-base.sh`, `fotos-do-pack.sh`, `git-limpo.sh`, `pack-dracula-completo.sh`, `criar-tema-leva.sh`, `achados-tecnicos.sh`, `app.sh` e `galeria-do-papel.py` (`ok: 8 conferências da galeria do papel de parede`).

Falta da mão de quem usa: nada além do install do coordenador. Com o HOME real, o `Cyberpunk Neon Cat Wallpaper …` (dois emojis) sai na primeira passada do doctor; confira que `banidos/` sumiu.

# P292 — o que lê o histórico antes de ele ser reescrito (24/11/2026)

## O que se mediu (24/11, integração `e2046e4e`)
A P284 reescreve o histórico e todos os hashes mudam. Procurei no tronco, fora de `docs/sprints/`, todo código,
teste e documento que lê ou cita commit do próprio repositório.

| quem | o que lê | o que a reescrita faz |
| --- | --- | --- |
| `tests/chaves-aposentadas.sh` (casos 6 e 7) | `git show a43d7538^:meow.conf.exemplo` e `git show 47a097b3:meow.conf.exemplo` | o teste fica vermelho |
| decisão 24 e `tests/decisoes.sh` | «o histórico do git guarda» as folhas e as pesquisas; a cobrança exige que toda citação de `docs/pesquisas/` venha por `git show <commit>^:` | com raiz nova de um commit só, o texto da decisão deixa de ser verdade |
| `dados/patches/LEIA-ME.txt:303`, `dados/patches/cosmic-comp-modo-leitura.patch:48,117`, `scripts/oraculo_tema.py:16` | `git show 1b15ccb1^:docs/pesquisas/…` | a citação aponta para commit que não existe |
| `scripts/deb.sh` (`versao_do_git`) e `tests/readme.sh` | a tag `v*` mais recente alcançável (`v2.3.1`) | as 12 tags apontam para commit que deixa de existir; sem tag, o `deb.sh` pede a versão por argumento e o `readme.sh` não compara o badge |

`scripts/atualiza.sh` só compara o clone com o tronco, e a P284 já diz o que acontece com ele.

## A causa
A decisão 24 tirou as pesquisas do tronco contando com o histórico, e dois casos de teste foram buscar no
histórico o conf de antes em vez de guardar a amostra.

## A cura na origem
1. O teste guarda a amostra. Feito em 24/11 (`9784d5f7` e os dois seguintes, integrados em `2e658838`): os dois confs
   de antes moram em `tests/auxiliares/conf-de-antes/`, byte a byte iguais aos do histórico (`cmp`), com `byte-exact`
   no `.gitattributes` para o gancho de commit não trocar palavra neles, fora da regra do comentário pelo nome (como
   o `meow.conf.exemplo`) e fora da busca dos agentes pelo `.ignore`.
2. A decisão 24 e as quatro citações dependem do jeito da reescrita, que é escolha de quem usa na hora (P284,
   item 4):
   - mantendo os commits (tira do histórico só os caminhos aposentados e os objetos grandes): as pesquisas seguem
     alcançáveis; as quatro citações e a mensagem do `decisoes.sh` trocam o hash pelo novo, pela tabela que a
     ferramenta de reescrita grava. O texto da decisão 24 não muda.
   - raiz nova, com um commit só: as pesquisas ficam só na cópia de segurança. O texto da decisão 24 passa a dizer
     isso, com o sim dela citado, e as quatro citações passam a apontar para a cópia.
3. Uma tag de versão na ponta nova, assinada, para o `deb.sh` e o `readme.sh` voltarem a ter de onde ler. O número
   é de quem usa.

## Como se prova
- `tests/chaves-aposentadas.sh` verde num clone raso (`git clone --depth 1`), que não tem os commits antigos.
- `tests/decisoes.sh` e `tests/readme.sh` verdes na ponta reescrita; `scripts/deb.sh` sem argumento monta o pacote.
- `git grep -nE '\b[0-9a-f]{7,40}\b'` no tronco, fora de `docs/sprints/` e de `packs/`: nenhum resultado que seja
  commit do repositório de antes.

## Com a resposta de 24/11 («Raiz nova, um commit só»)
- Decisão 24: o texto passa a dizer que quem guarda é a cópia de segurança de antes da raiz nova, com o sim citado.
- As quatro citações `git show 1b15ccb1^:docs/pesquisas/…` ficam como estão: o commit existe dentro do bundle, e a
  decisão 24 diz onde o bundle mora. O item «nenhum hash de antes no tronco» da prova deixa de valer para elas.
- A tag `v2.4.0` na ponta nova, e o badge dos dois README com ela.

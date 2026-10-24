# P100 — O patch v2 da Vitória e o rebase da P85 viram um só

**Status: REGISTRADA em 24/10, no fecho da leva H. Não executar sem a palavra de quem usa.**

## O que se mediu (24/10)
- O `origin/master` da Vitória ganhou o `8906456` (28/09): menu e modo de leitura **v2**, portados para o
  cosmic-comp `0fbd457`, todos os patches `req`, encaixes reancorados no começo das listas, e o uniform
  `leitura_temp` (neutro 1.0) vira `leitura_atenuacao` (neutro 0.0) — o zero do GL deixa de ser tela preta.
- O dev rebaseou os mesmos dois patches para o `4d14528` na P85 (itens 2 e 4, 15/10), ainda com a semântica v1:
  `leitura_temp` aparece 28 vezes no `cosmic-comp-modo-leitura.patch`; o menu já tem o `last_tablet_idx`.
- `git merge origin/master` no dev: conflito em `patches/cosmic-comp-menu-clique-curto.patch` e
  `patches/cosmic-comp-modo-leitura.patch`. O `LEIA-ME.txt` junta sem conflito. Merge abortado: portar patch
  de compositor não é mecânico.

## A cura
1. Portar a v2 (atenuação, reancoragem) para o fonte do `4d14528` que a série do dev declara.
2. O applet do modo de leitura e o `meow` passam a escrever `leitura_atenuacao`.
3. `series`: tudo `req`, como a decisão dela de 28/09.
4. Merge do `origin/master` no dev com os dois arquivos resolvidos para a versão portada.

## Como se prova
- `aurora-cosmic-comp-ws.sh --status` (ou o equivalente do MeowSystem) com todos os marcadores `-2`;
- build aplica a série inteira no `4d14528`; login com o modo de leitura desligado não escurece a tela;
- `git merge origin/master` sem conflito; a PR para a Vitória sem conflito.

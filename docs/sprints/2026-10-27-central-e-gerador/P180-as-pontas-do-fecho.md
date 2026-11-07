# P180 — as pontas do fecho (07/11/2026)

Achados da conferência da P177 e da P178.

## O que se mediu

- `scripts/graficos.sh` chama `meow_precisa_de_gente` e `meow_precisa_de_gente_resolvida` (linhas 349-350, 429, 597, 646-647, 696, 700), que a P175 apagou de `lib/comum.sh`. `tests/graficos.sh` sai com 2 «FALHA pede gente, sem receita». É colisão de dois blocos: o erro em tempo de execução é real.
- `bin/meow`, `chk_tema` e `chk_temas` (linhas 163 e 173), imprimem «'meow doctor --consertar' regenera» no status: mandam digitar, e o teste só pega «os escreve».
- `tests/garantir-builds.sh:462` ainda filtra `recusado: sudo -n -l`, que saiu do doctor; o filtro afrouxa o teste.
- `scripts/oraculo_tema.py:51-53` lê a captura em `Builder/v2`; medido com captura v3: `ValueError a captura não tem a receita Dark.Builder/v2`. A função `da.receita_da_captura` já existe.
- `scripts/aplicar_tema.sh:35`, `receita_diverge`, percorre só `v1 v2`.
- `GSD.md:29` e a prova em `tests/decisoes.sh:402` citam o `NOPASSWD: ALL`, que sai das máquinas depois do install desta rodada.

## A cura

- `scripts/graficos.sh` segue a P175 e a decisão 55: pendência acionável na forma nova que a `lib/comum.sh` tem, ou registro no log e `meow doctor`, sem tela nova e sem receita. Medir o que os outros builds fazem hoje e usar o mesmo.
- As frases não mandam digitar, e o teste passa a pegá-las.
- O filtro sai do teste.
- `oraculo_tema.py` usa `da.receita_da_captura`; `receita_diverge` segue a versão do sistema.
- A armadilha do GSD passa a valer sem a regra: `sudo` pode escrever no sistema real, sempre, e teste nunca o chama.

Fica de fora, sem COSMIC v3 para medir: a pasta produto `CosmicTheme.<Árvore>/v2`.

## Como se prova

`tests/graficos.sh`, `tests/garantir-builds.sh`, `tests/nada-manda-digitar.sh`, `tests/decisoes.sh` e `tests/oraculo-tema.sh` verdes, com caso novo vermelho antes da cura.

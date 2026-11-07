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

## Execução

Bloco `bloco/fecho`, 8 commits sobre `9bf03bd4`, os três últimos da conferência.

- **`scripts/graficos.sh`.** Seguiu o que o compositor faz hoje (`_cp_marcar_caiu`): `meow_registrar` no log e a frase na saída do doctor, sem pendência e sem receita. A queda do portal registra em `_gr_marcar_caiu`; a recusa do patch registra em `_gr_gravar_falha`, a porta única: `cmd_compilar`, `cmd_validar` e o patch que passa no dry-run e não entra na hora. A primeira versão registrava só no retorno 4 do `cmd_compilar`, e os outros dois caminhos ficavam mudos (2 FALHA, medido na conferência). A repetição em `cmd_aplicar` e as seis chamadas de «resolvida» saíram, junto com a prova do `tests/graficos.sh` que olhava o `precisa-de-gente.tsv` (que não podia mais falhar). Casos novos: o log tem a frase uma vez só, o arquivo e a pendência não existem, a saída do aplicar e do cuidar não tem `command not found`, e a primeira linha do conferir, a que o doctor mostra, diz que o patch não entra. Com o `scripts/graficos.sh` da base e estes testes, 8 FALHA.
- **Frases do status e filtro do `garantir-builds`.** Já estavam curados na base: `73fdb3e6` (P178) trocou as duas frases do `bin/meow` por «o conserto regenera» e «o conserto deriva e aplica» e fez o teste pegar `'meow doctor --consertar'`; `0ca641b8` (P178) tirou o filtro `recusado: sudo -n -l`. A medida da sprint foi feita sobre uma árvore sem esses dois commits. Nada a mudar; `nada-manda-digitar.sh` e `garantir-builds.sh` verdes confirmam.
- **`scripts/oraculo_tema.py`.** Lê a receita por `da.receita_da_captura`. Caso novo em `tests/oraculo-tema.sh`: a captura com `Builder/v3`, Dark e Light. Antes: `rc 2: erro: a captura não tem a receita Dark.Builder/v2`.
- **`receita_diverge` (`scripts/aplicar_tema.sh`).** Compara `v1` e, para a receita, a versão da captura (`receita_da_captura`) contra a do sistema (`versao_do_builder`). Caso novo em `tests/acento.sh` (captura v3 com sistema v3, captura v2 com sistema v3, sem pasta do sistema, e o sistema v3 sem receita v3). Antes: `FALHOU: receita_diverge não segue a versão do sistema (v3/v3=1 v3/v2cap=1 v2=0 v3 sem receita v3=0)`. A guarda «nenhum escritor crava Builder/v2» passou a olhar também o `oraculo_tema.py`. A prova é da função e do `--conferir` em fixture: com captura v2 e sistema v3 o produto é cedido à GUI, mas o `aplicar_tema.sh` inteiro ainda não fecha, porque a sobra leva a `Builder/v3` (em «Falta»).
- **GSD.md.** A armadilha do sudo: «`sudo` pode escrever no sistema real, sempre. Teste nunca chama `sudo` de verdade.» Sim de quem usa em 06/11: «Tirar a regra e o aviso» (decisão 43). `tests/decisoes.sh` exige a frase nova e falha se `NOPASSWD` voltar ao GSD. A prova de que o teste não chama sudo segue: os falsos no PATH do próprio `decisoes.sh`.

### Provas

Refeitas na conferência sobre `HOME` temporário e `sudo`, `pkexec` e `su` falsos, sem nenhuma chamada a eles. `tests/decisoes.sh` pede `SUITE_CASA_REAL` para conferir o askpass, como o `tests/todos.sh` passa. `tests/todos.sh` não rodou: é do coordenador.

- `bash tests/graficos.sh`: sem FALHA, última linha `ok: o portal e a policy entram idempotentes, o shim existe sempre e a série recusa quando não entra`.
- `bash tests/garantir-builds.sh`: `garantir-builds: tudo certo`.
- `bash tests/nada-manda-digitar.sh`: `passou: nada manda digitar`.
- `bash tests/decisoes.sh`: `decisoes: tudo certo`, com `ok    a armadilha do sudo vale sem a regra NOPASSWD`.
- `bash tests/oraculo-tema.sh`: `oraculo-tema: tudo certo`, com `ok    captura em v3, Dark: a receita é lida onde está` (e Light).
- `bash tests/acento.sh`: `acento: tudo certo`. `bash tests/vidro-do-cosmic.sh` (usa `receita_diverge`): `vidro-do-cosmic: tudo certo`.
- `bash tests/precisa-de-gente.sh`, `tests/compositor-shim.sh`, `tests/sentinela.sh`, `tests/estilo.sh`, `tests/notas-de-funcao.sh` e `python3 tests/manter-sem-pendencias.py`: verdes.
- Vermelho antes da cura, medido com a árvore da base e os testes novos: `acento.sh` 2, `oraculo-tema.sh` 2, `graficos.sh` 8 e `decisoes.sh` 2 falhas da sprint.

### Falta, da mão de quem usa

- Tirar o `NOPASSWD: ALL` do sudoers depois do install, com `visudo -c` e a prova do `sudo -A` antes (do coordenador, como na P178).
- A pasta produto `CosmicTheme.<Árvore>/v2` segue de fora: sem COSMIC v3 para medir. Vai junto a sobra medida em fixture: captura v2 com sistema v3 faz o `aplicar_tema.sh` apagar os 43 arquivos da `Builder/v3`, com backup, tanto na base quanto aqui.
- Um build de portal que caiu agora só aparece no log e na saída do `meow doctor`; se quem usa quiser um cartão no painel, é decisão nova.

# P277 — a tabela dos caminhos de antes (23/11/2026)

## O que se mediu (catálogo de 23/11)
- `packs/CAMINHOS-DE-ANTES.tsv`: 5662 linhas, 473 KB. Liga o caminho de antes das levas de 23/10 e de 16/11 ao de
  hoje.
- Quem lê: `scripts/pack.py:534-566` (traduz caminho antigo), `tests/decisoes.sh:50,61`, `tests/pack.sh:2174`,
  `tests/tres-pastas.sh:144`; o `.gitattributes:11` a marca byte-exact.
- Medido nos três PCs em 23/11, só lendo (os mapas de `~/.config/meow`, os packs pessoais e o estado, contra a
  tabela e o `caminho_de_hoje` do `pack.py`):

  | PC | arquivos de quem usa com caminho antigo | pack pessoal |
  | --- | --- | --- |
  | nitro-5 | `~/.config/meow/icones-escolhidos.map`: 11 das 13 escolhas apontam para `packs/dracula/icones/biblioteca/<x>.svg`, que hoje é `packs/dracula/icones/apps/<x>.svg`; uma linha do `manifesto.tsv` do estado e uma cópia de restauro | nenhum |
  | desktop | nenhum | `meu-tema` |
  | portátil | nenhum | `meu-meow-portatil` |

  As 11 escolhas do nitro-5 só valem hoje porque o `pack.py` as traduz na leitura.

## A causa
A tabela existe para o que é de quem usa (mapas de escolha, retoques, pack pessoal) seguir valendo depois da mudança
de pastas. Ela ficou no repositório para sempre, dentro de `packs/`, sem ser dado de pack.

## A cura na origem
1. Medir nos três PCs se algum arquivo de quem usa ainda cita caminho antigo: os mapas de `~/.config/meow/` e os
   packs de `~/.local/share/meowsystem/packs/`.
2. Se houver, o install traduz uma vez, com cópia de antes, e grava o caminho novo.
3. Com os três PCs sem caminho antigo, saem a tabela, o tradutor do `pack.py` e as linhas dos três testes.

## Como se prova
- Teste com uma casa de mentira que cita caminho antigo: uma passada traduz e a segunda não escreve.
- `git grep CAMINHOS-DE-ANTES` vazio.
- Nos três PCs: seletor de ícone e oficina abrindo as escolhas de antes.

## Ressalva
Pack pessoal exportado antes de 23/10 e importado depois desta tarefa não é traduzido. Fica dito no `docs/PACKS.md`.

## Feito (23/11, bloco `comentarios-e-tabela`, integrado em `bdd5232a`)
- `scripts/pack.py migrar-caminhos`, chamado pela etapa da configuração do install: traduz uma vez os caminhos de
  antes nos mapas de ícone de quem usa, com a cópia `.antes-caminhos` ao lado. A segunda passada não escreve.
- Quem conferiu achou e corrigiu (`0762d7ae`): com a pasta só-leitura a migração dava traceback e o install
  mostrava o traceback como «ok». Agora avisa, sai 1 e não mexe. Prova: `tests/migrar-caminhos.sh` (13 casos).
- A tabela `packs/CAMINHOS-DE-ANTES.tsv` fica neste release: 11 das escolhas do nitro-5 trocam de nome (por exemplo
  `biblioteca/book.svg` para `apps/org.onlyoffice.desktopeditors.svg`), e só a tabela sabe traduzir.
- Falta, no passo 10: no nitro-5, `python3 scripts/pack.py migrar-caminhos --conferir` (espera 11 linhas), o install,
  e só então a tarefa de tirar a tabela.

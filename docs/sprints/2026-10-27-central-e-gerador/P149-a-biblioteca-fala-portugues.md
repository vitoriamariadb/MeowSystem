# P149 — a Biblioteca do pack MeowSystem fala português

Anotada em 29/10 pelo conferente da P143: a aba Biblioteca do painel mostra «File», «Folder», «Folder open»,
«Root». Medindo, não são quatro: o pack MeowSystem não tem `catalog.json` na Biblioteca, então os 622 rótulos
saem do nome do arquivo.

## O que se mediu
- `packs/meowsystem/icones/biblioteca/`: 622 SVG, sem `catalog.json`. O Dracula tem o dele (479 entradas,
  campo `descricao` em português).
- `scripts/pack.py` `_rotulos_da_biblioteca()` lê `catalog.json` → `descricao`; sem ele, `_rotulo_do_nome()` faz
  «folder_admin_open» → «Folder admin open», «_file» → «File», «books» → «Books», «calculator» → «Calculator».

## Cura na origem (pack é dado)
- `packs/meowsystem/icones/biblioteca/catalog.json`, no formato do Dracula, com `descricao` em português para os
  622: `folder_X` → «pasta X», `folder_X_open` → «pasta X aberta»; `_file`/`_folder`/`_folder_open`/`_root`/
  `_root_open` → «arquivo», «pasta», «pasta aberta», «raiz», «raiz aberta»; palavra comum traduzida
  («books» → «livros», «calculator» → «calculadora»); marca, linguagem e nome próprio ficam como se escrevem
  («Adobe XD», «Rust», «Svelte», «VLC»), com a grafia da marca.
- O gerador do catálogo é script (mecânico), não mão: um dicionário revisado de palavra comum, o resto regra.
- Nada muda no `pack.py` se o catálogo basta; se o validador de pack ou o `biblioteca-origem.sha256` reclamar do
  arquivo novo, a cura vai lá.

## Prova
- Teste que falha hoje: todo SVG da Biblioteca dos dois packs tem `descricao` no catálogo, e nenhum rótulo da
  Biblioteca servido pelo painel é uma palavra da lista de inglês comum (`file`, `folder`, `open`, `root`, ...).
- `tests/todos.sh` sem vermelho novo; captura headless da aba Biblioteca em 1280.

# P275 — os moldes de tema que moram no código (23/11/2026)

## O que se mediu (catálogo de 23/11)
- `scripts/temas-de-apps/` guarda 11 arquivos `*.modelo.*` (cerca de 1147 linhas): discord, firefox, gnome-terminal,
  kitty, krita, libadwaita (2), obs, onlyoffice, telegram e zapzap. Nenhum tem cor: só marcadores `{{papel}}`.
- `scripts/pack.py:1207` cai nesses arquivos quando o pack não declara `arquivo`. Ou seja, o pack depende de uma
  pasta de código para achar o molde.
- `packs/CAMINHOS-DE-ANTES.tsv:3894-3899`: cinco deles saíram de `packs/dracula/apps/` no commit `b544d210` (23/10).
- `heroic/manifesto.sh:5` e `btop-bat/manifesto.sh:17` leem `packs/meowsystem/` por caminho fixo, sem passar pelo
  `pack.json`.
- `assets/temas/capturados/original/` (123 arquivos): a captura que serve de molde do tema v1
  (`gerar_tema_v1.py:16`) e de alvo do `meow desfazer` (`bin/meow:2760`). O `docs/PACKS.md:333` a registra como
  exceção.

Pergunta de quem usa, 23/11: «Temas de apps deveriam estar dentro do packs não?»

## A causa
A decisão 14 diz que o acervo do motor é o pack-base `meowsystem`, que todo pack herda. Para ícone isso vale; para
molde de tema de app e para a captura original, o acervo do motor ficou em `scripts/` e em `assets/`.

## A resposta de quem usa (AskUserQuestion, 23/11/2026)
À pergunta «para onde vão os 11 moldes e a captura original?»: «Tem o pack base mas são temas de cores os arquivos
cada pack deveria ter os mesmos arquivos porém ajustados pela paleta de cores dela».

Leitura do coordenador: todo pack traz, dentro dele, o mesmo conjunto de arquivos de tema de app, nas cores dele.
Nenhum arquivo de tema mora em pasta de código, e o código não tem reserva própria para quando o pack não traz.

## Como o arquivo fica no pack
Os moldes não têm cor: são preenchidos no install com o flavor e o acento que quem usa escolheu. Sim de quem usa,
23/11/2026 (AskUserQuestion): «Molde no pack, cor no install». Cada pack traz os 11 arquivos dentro dele, com os
marcadores; o install preenche com a paleta do pack no ar.

## A cura na origem
1. Os arquivos de tema saem de `scripts/temas-de-apps/` e entram em `packs/<id>/temas-de-apps/<app>/`, nos dois
   packs do repositório. `meow pack novo` e o Personalizar semeiam os 11 no pack que nasce.
2. O `scripts/pack.py:1207` deixa de procurar molde em pasta de código.
3. Os dois manifestos de caminho fixo passam a perguntar ao pack.
4. A captura `original` vai para `packs/meowsystem/temas/capturados/original/` (leitura do coordenador: é tema, e
   `dados/` fica sem tema nenhum); o `pack.py` (`CAPTURA_DO_MOTOR`), o `gerar_tema_v1.py` e o `meow desfazer` a
   leem de lá.
5. `scripts/temas-de-apps/` fica só com código.

## Como se prova
- `tests/temas-de-apps.sh`, `tests/apps-em-todo-pack.sh`, `tests/pack-pessoal-tem-tema.sh` e `tests/acento.sh`
  verdes; os dois packs do repositório trazem os mesmos 11 arquivos, e um pack pessoal criado depois também.
- O tema de cada app, aplicado no palco nos dois packs, é byte a byte o de antes da mudança.
- `tests/arvore.sh`: nenhum `*.modelo.*` fora de `packs/`.
- `./install.sh` em 1 passagem nos dois packs; `meow desfazer` no palco devolve o tema da captura.

## Feito (24/11/2026)
No mesmo bloco da P274 (`803b9a49`).
- Os 11 moldes são idênticos nos dois packs (`cmp`), e nenhum `*.modelo.*` sobrou em `scripts/temas-de-apps/`. O
  `pack.py` não tem mais reserva em pasta de código. O `heroic` e o `btop-bat` não têm caminho fixo de pack.
- `pack.py semear-moldes` dá os 11 ao pack pessoal sem trocar arquivo que existe; a segunda passada não escreve. Em
  pack só-leitura ele avisa e segue.
- A captura `original` mora em `packs/meowsystem/temas/capturados/original/` (123 arquivos) e é sempre a do
  repositório.
- Tema gerado, byte a byte, entre `6b5286e1` e a ponta: 54 de 66 iguais. Os 12 restantes (libadwaita e zapzap, nos
  6 flavors) diferem em uma linha de comentário do cabeçalho, a do `7c3485b4`. O install reescreve esses dois uma
  vez em cada PC.

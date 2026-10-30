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

## Execução
- **Catálogo** (`b3ce7ddf`). `packs/meowsystem/icones/biblioteca/catalog.json`, no formato do Dracula (`nome`, `descricao`, `tags`, `tamanho_bytes`, e `cores_dominantes` quando o SVG tem cor), 622 entradas, uma por SVG. O gerador foi um script descartável do scratchpad: dicionário revisado à mão para as palavras comuns e as marcas, regra para `folder_X` e `folder_X_open` (com o dicionário dos nomes de pasta) e para `_file`, `_folder`, `_root`. A lista inteira foi relida depois de gerada.
  - `cores_dominantes`: os SVG usam `var(--vscode-ctp-*)`, então a cor é a da paleta do flavor padrão (mocha) mais os `#hex` literais, as cinco mais frequentes. Os 41 de traço `currentColor` (Arcticons) ficam sem o campo, como 37 do Dracula. Nada no `pack.py` nem no painel lê `cores_dominantes`; `tags` só entra na busca do painel.
  - `tags`: uma categoria (`pastas`, `linguagens`, `frameworks`, `configuracao`, `aplicativos`, `servicos`, `sistema`, `ferramentas`) e, onde há família, a família (`java`, `angular`, `nest`, `lua`, `luau`, `adobe`...).
  - O validador de pack aceita o arquivo (`pack.py validar meowsystem` verde; o `catalog.json` já era exceção da forma da pasta). Nada mudou em `pack.py`, e o `biblioteca-origem.sha256` é só do Dracula.
- **Dracula** (`253653b0`). A prova achou «Camera · feito à mão» no catálogo do Dracula; virou «Câmera · feito à mão».
- **Prova** (`45278ce6`). `tests/biblioteca-em-portugues.sh` (portátil, em `todos.sh`): para `meowsystem` e `dracula`, todo SVG da Biblioteca tem `descricao` e nenhum rótulo oferecido por `acervo_para_levar` (o que a aba serve) contém palavra da lista de inglês comum. Sem o catálogo o teste falha (622 sem descrição, 292 rótulos em inglês); com ele passa.
- **Captura**: o painel com HOME temporário, aba Biblioteca em 1280 px, mostra «Modelo 3D», «Arquivo», «Pasta», «Pasta aberta», «Raiz», «Microsoft Access», «Adobe After Effects».
- Fora: o painel põe a primeira letra em maiúscula (`desc[:1].upper()`), então marcas de grafia minúscula aparecem como «Esbuild», «Pnpm», «Npm», «Commitlint». Pedir outra regra é mexer no `pack.py` e no `servidor.py`; ficou como anotação. Duas frases iguais: `rust-config` e `rust-alt-config` («configuração do Rust»).
- **Suíte**: `./tests/todos.sh` com 122 testes, 120 verdes, 0 pulados, 2 vermelhos: `readme.sh` (badge v2.2.0, aceito) e `restaurar.sh` (`pack_usar` e `desinstalar`, os mesmos dois que `00-leva.md` lista como aceitos por causa dos arquivos do VS Code da máquina; não reexecutado no `dev` limpo). O teste novo passa.
- **Conferência** (30/10).
  - Catálogo relido inteiro, os 622, com cada dúvida olhada no desenho (catppuccin-vsc-icons 1.26 e as Arcticons). Ficam como estavam: `tile` (o logo TILE, o app), `writer`, `zap` (extensão `.zap` no catppuccin), `amber` (a linguagem, `.ab`), `vital` (o sintetizador, `.vital`), `blink` (`.blink`), `mantle` (`mantle.yml`), `hacking` (`HACKING.md`), `vapi` (`.vapi` do Vala), `moon` (desenho de lua crescente) e `rust-alt-config`.
  - Corrigido no catálogo (`9db4f960`): `alex`, `darklua`, `nodemon`, `gulp`, `fastlane` (e as duas pastas), `just`, `pixi` (e a trava) e `vanilla-extract` na grafia da marca; «ONLYOFFICE Documents», que é o nome do app e não se traduz; `rust-config` desenha o Ferris e vira «configuração do Rust (Ferris)», e as duas frases iguais acabam.
  - `access` (`81ef6b2c`) desenha uma chave, não o logo do Microsoft Access: vira «acesso», tag `sistema`.
  - Maiúsculas (`402cf035`): a ficha do catálogo ganha `"caixa_da_marca": true` quando a `descricao` já vem na grafia final. `rotulo_da_ficha()` no `pack.py` devolve a descrição tal como está nesse caso, e sobe a primeira letra nos outros. O `servidor.py` (rótulo da busca da ficha) usa a mesma função, em vez de uma cópia da regra. São 27 fichas no MeowSystem (npm, pnpm, esbuild, macOS, mdBook, uv, webpack, xmake, package.json…) e 2 no Dracula (`dbt`, `i-score`); as outras 477 do Dracula não mudam. O `docs/PACKS.md` diz a regra.
  - O teste novo cresce: a grafia de npm, pnpm, esbuild, macOS, webpack, uv, mdBook, dbt, «Pasta» e «Poção» no rótulo da aba, e a busca do painel com o mesmo rótulo da aba nos dois packs. Ele falha com o `pack.py` e o `servidor.py` de `76c7fe39` («Npm», «MacOS», «Dbt, …»). Sem o catálogo também falha: 622 sem descrição e 283 rótulos em inglês (não 292). Com tudo, passa. O teste está no grupo `PORTATIL`, que é o certo: não usa COSMIC, e o `acervo-da-ficha.sh`, que também importa o `servidor.py`, está no mesmo grupo.
  - `tags` e `cores_dominantes` têm a forma do Dracula. `tags` só entra na busca da ficha (`_textos_da_busca`, sem acento, então `configuracao` acha «configuração»). Ninguém lê `cores_dominantes`. Ficam sem cor 41 fichas no MeowSystem e 43 no Dracula (não 37).
  - Suíte: 122 testes, 120 verdes, 0 pulados, 2 vermelhos, os dois aceitos: `readme.sh` (badge v2.2.0) e `restaurar.sh` (`pack_usar` e `desinstalar`).
  - Captura: a aba Biblioteca em 1280, painel em HOME temporário, mostra «alex», «npm», «pnpm», «esbuild», «macOS», «webpack», «nodemon», «pesde», «package.json», «ONLYOFFICE Documents», e nenhum «Npm» nem «MacOS».
  - Fica para depois: «games», no Dracula (`gaming.svg`), é inglês. «SliDesk» pode ser a grafia da marca de `slidesk`. Os desenhos `network`, `player` e `star` são logos de app (um telefone com «i», as palavras «player» e «STAR»), e a tradução literal ficou.

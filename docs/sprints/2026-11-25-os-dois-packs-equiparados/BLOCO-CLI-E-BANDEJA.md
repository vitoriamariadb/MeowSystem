# Bloco · o verbo dos ganchos e a bandeja no Dracula (25/11/2026)

Duas tarefas independentes, cada uma nos seus commits (elas entram no `master` em momentos diferentes).

## Tarefa 1 · `meow ganchos instalar` (P288)

### O que se mediu
`scripts/ganchos.sh` instala, confere e remove o `pre-push` e o `post-merge` (`tests/ganchos.sh`), e nenhum verbo do
`meow` nem etapa do `install.sh` o chama: quem instala é a mão
(`docs/sprints/2026-11-23-a-casa-em-ordem/P288-o-gancho-de-push-e-a-ponta-assinada.md`). Em 25/11 ela decidiu:
«Faz como proposto».

### A cura na origem
A CLI ganha `meow ganchos instalar`, `meow ganchos conferir` e `meow ganchos remover`, que chamam o
`scripts/ganchos.sh`. É gesto de quem desenvolve: o `install.sh` continua sem instalar gancho, e o `meow doctor`
não o cobra. A ajuda do `meow` e a completion ganham o verbo; o manual (`docs/MANUTENCAO.md` ou onde o gancho já é
citado) diz como.

### Como se prova
`tests/ganchos.sh` (ou o teste da CLI que já cobre verbos) com os três subverbos num clone de mentira: vermelho
antes, verde depois. O teste que cobra verbo na ajuda e na completion, verde.

## Tarefa 2 · o Dracula declara a bandeja

### O que se mediu (25/11)
Só o `meowsystem` declara `icones.bandeja` no `pack.json`. Com o Dracula no ar, `scripts/icones_bandeja.sh`,
`scripts/icones_tray_steam.sh` e `scripts/icones_tray_zapzap.sh` dizem «o pack no ar não declara icones.bandeja» e
pulam: o ícone de bandeja da Steam e o do ZapZap ficam de fábrica. Ao vivo, no nitro-5, o ZapZap publica um item sem
`IconName` (manda a imagem); a Steam publica `steam_tray_mono` com `IconThemePath` próprio (comentário do
`packs/meowsystem/icones/bandeja.map`). Em 25/11 ela decidiu: «O Dracula passa a declarar a bandeja», e o dono do
nitro-5 vê a folha antes de valer no PC dele.

### A cura na origem
`packs/dracula/pack.json` declara `icones.bandeja`, com o mapa do pack e os glifos DELE (o estilo do Dracula é forma
cheia, `gerador: circle`, `pintar: text`; veja como o `sistema.map` e `icones/sistema/` do Dracula desenham, e use
os desenhos que o pack já tem para Steam e WhatsApp/ZapZap em `packs/dracula/icones/`). Os três scripts passam a
funcionar com qualquer pack que declare a bandeja, sem `if` por nome de pack. Se um script crava hoje o traço do
`meowsystem` (largura de linha, cor), o estilo passa a vir do pack.

Nada disso muda o `meowsystem`: a saída dos três scripts com `meowsystem`/mocha é idêntica antes e depois.

Entregue também a folha: um PNG em `docs/sprints/2026-11-25-os-dois-packs-equiparados/` NÃO; gere em
`/tmp` ou na pasta que quem coordena indicar e diga o caminho no relato (imagem de bandeja de fábrica ao lado da do
pack, Steam e ZapZap, nos dois flavors do Dracula). Imagem não se versiona neste bloco.

### Como se prova
Teste novo, vermelho antes e verde depois: com `dracula`/dracula e `dracula`/alucard, os três scripts em HOME
temporário põem o glifo do pack (Steam e ZapZap de mentira, como os testes de hoje fazem para o `meowsystem`), a
segunda passada não escreve, e o remover devolve o de fábrica. Com `meowsystem`/mocha a saída não muda (compare).
`scripts/meow pack validar dracula` sem aviso novo; `tests/pack-dracula-completo.sh` e `tests/apps-em-todo-pack.sh`
verdes.

## As regras da casa que valem aqui
`AGENTS.md` e `GSD.md` inteiros. Zero comentário no código. Pack é dado. Sem `sudo`; sem `install.sh`,
`meow compositor`, `meow doctor --consertar` nem `meow apps aplicar` com o HOME real; sem janela; não abrir Steam
nem ZapZap. Teste pelo `./tests/todos.sh --so=…`, e `./tests/todos.sh --portatil` no fim. Commit por caminho, em
português, sem marca de ferramenta, antes de rodar a suíte. Sem push. O que se achar fora do escopo vira
`ACHADO-<nome>.md` nesta pasta.

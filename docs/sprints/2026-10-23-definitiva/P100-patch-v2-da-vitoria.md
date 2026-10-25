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

## Execução
Veredito da conferência (25/10): **APROVADO_COM_RESSALVAS**. O porte bate com a v2 dela. A conferência achou
um buraco que impedia a v2 de chegar ao binário nesta máquina e o fechou, com teste.

1. `528b831` os dois `.patch`, sem o cabeçalho e sem os números das `@@`, são o `8906456` linha por linha
   (o `diff` só acusa os `diff --git`/`index` e as notas novas do cabeçalho). Conferido hunk a hunk no fonte
   patchado: `leitura_atenuacao` (`_3f`, `1 − tint`, `color.rgb *= vec3(1.0) - leitura_atenuacao`) com 0 de
   neutro, nos três lugares que passam uniform ao `offscreen.frag` e no `init_shaders`. Nenhum outro lugar passa
   uniform a esse shader. Os campos e os defaults (0 e 0.0) abrem a struct e o `Default`. `nascimento` é o
   primeiro campo do `MenuGrab` e do inicializador. O braço `leitura_*` é o primeiro do `config_changed`, e o
   uniform é o primeiro da lista. Marcadores `-2`. O `last_tablet_idx` da P85 está inteiro no fonte (struct,
   inicializador e os seis usos do tablet): a v2 não encosta nele. Engolir o release depois do `any_entered`
   (v2), e não antes (v1), dá o mesmo resultado, porque a contagem não tem efeito.
2. `9b21305` a `series` é toda `req`. O `tests/decisoes.sh` cobra a série sem `opt` e o uniform novo.
3. `0a728e9` o merge do `origin/master`: `git merge-tree HEAD origin/master` sai sem conflito, e o
   `origin/master` já é ancestral (a PR para ela é avanço rápido). Ninguém escreve `leitura_temp`: o applet e o
   `meow` escrevem as chaves `leitura_temperatura` e `leitura_textura`, que não mudaram. O uniform só aparece
   no patch, e ali só em comentário de história.
4. **Achado da conferência**, `aa02537` + `adcc263`: a v2 nunca entraria no binário. O build do `8cb1802`
   (o instalado, de 23/10) tem `MENU-PATCH-1` e `READING-MODE-1`. O `garantir_builds.sh` aceitava qualquer
   build com um `req` presente. O `compilar` olhava só a base do marcador, tomava a árvore do cache (patchada
   com a v1) por «já aplicado» e recompilava a v1. Pior: sobre a árvore v1, a v2 do menu entra com `-F1`, e
   entraria duas vezes. Agora manda o marcador com versão que o `.patch` declara. O build cujo `estado` grava
   outra versão presente se refaz, e o de agora segue na sessão até o novo ficar pronto. O `compilar`
   reextrai o fonte guardado quando a árvore tem a versão anterior. O `aplicar` recusa essa árvore. O
   `ausente` e o `.patch` sem string declarada seguem como antes. Prova: `tests/patch-que-sobe.sh`, vermelho
   (6 falhas) com a cura desfeita. O `estado` real do `8cb1802`, copiado para o scratchpad, dá «compilaria»
   no `garantir_builds.sh --seco`. Antes da cura dava «têm build».

**Apply e build**, do zero e no scratchpad (nada instalado, nada em `/usr/bin`, sem sudo):
- `4d14528` (o `versao`): o `compositor_patches.sh aplicar` aplica os cinco com `-F0`, todos `req`. Em
  sequência, o menu e o modo de leitura entram sem deslocamento, e cada um passa sozinho no dry-run do fonte
  puro. `cargo build --release --frozen --offline` rc 0 (11m26s, 0 warning). O binário tem `WS-3.67`,
  `RADIUS-2`, `MENU-PATCH-2`, `READING-MODE-2` e `BLUR-CACHE-1`.
- `8cb1802` (o instalado; o fonte puro saiu da árvore do cache com a série v1 revertida, `-R -F0`): a série v2
  entra com `-F0` e compila (rc 0, 6m52s) com os mesmos cinco marcadores.

**Suíte**, duas vezes seguidas na ponta `adcc263`:
`== todos os 80 · 80 verde(s), 0 pulado(s), 0 vermelho(s) ==` nas duas, com rc 0. Os falsos recusaram 6
chamadas de sudo (4 `sudo -n true` e 2 `estado` da ponte) e pararam 13 escritas. A primeira forma da cura
deixou o `pos-apt.sh` e o `garantir-builds.sh` vermelhos: o build se refazia sem fim com os estados de brinquedo
deles. Foi corrigida em `adcc263`.

**O que quem usa confere no próximo login** (depois de integrar no dev):
1. No primeiro login, o `meow-builds-login` recompila o `8cb1802` com a v2: Nice 19, ~5 min, sem rede (o fonte
   está guardado em `~/.local/share/meowsystem/fontes/cosmic-comp`). Essa sessão ainda é a v1.
2. No login seguinte, o `estado` de `~/.local/libexec/meow/cosmic-comp/0.1~1792508925~24.04~8cb1802/` mostra
   `AURORA-COSMIC-MENU-PATCH-2` e `AURORA-READING-MODE-2` presentes.
3. Com o modo de leitura desligado, a tela e a de login não ficam escuras. Ligado, a cor esquenta como antes.
4. O botão direito no título da janela abre o menu, e o menu não fecha sozinho no release.
5. A sessão sobe. Se o build novo cair duas vezes, o shim o põe de lado e volta ao de fábrica: o
   arquivo `ruim` aparece na mesma pasta.

**O que ficou** (anotado aqui, fora deste bloco):
- A linha `patches` do doctor (`cmd_conferir`) olha só a base do marcador e fica verde com o build v1 até o novo
  ficar pronto.
- A seção 0 do `LEIA-ME` diz que o `meow compositor` recusa versão fora de `versao`. Desde a escada isso não é
  verdade: o `8cb1802` compila pela matriz. E a seção 7 (dela) fala do script da Aurora.
- `tests/todos.sh` vai conflitar com a `sprint/p104` e a `sprint/p107` no merge. O conflito vem das P102 e
  P103 já integradas, não deste bloco.

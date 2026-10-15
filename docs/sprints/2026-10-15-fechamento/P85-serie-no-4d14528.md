# P85 — A série do compositor volta a entrar no cosmic-comp 4d14528

**Branch:** `sprint/p85` · **Medido em 15/10, 20:30** (`meow compositor` real, log em
`~/.local/state/meowsystem/compositor-15-10.log`):
- `cosmic-comp-sem-workspace-vazio.patch` (OBRIGATÓRIO) não entra nem com -F1 → nada compilado,
  o shim segue no de fábrica (contrato da série, certo);
- raio, menu e blur aplicam limpo mas o upstream mexeu no que tocam (degrau 2); modo de leitura só
  com -F1.
Fonte da versão instalada (só leitura; copie para o scratchpad antes de mexer):
`~/.cache/meowsystem/cosmic-comp/cosmic-comp-0.1~1791491785~24.04~4d14528` (o tarball guardado em
`~/.local/share/meowsystem/fontes/cosmic-comp`).

## Tarefas
1. Rebasear o patch obrigatório para o 4d14528 entendendo a mudança do upstream (não forçar contexto):
   mesmo comportamento (nenhum workspace vazio sobrando), mesmo marcador `AURORA-COSMIC-WS-PATCH-*`.
2. Os quatro opcionais: refazer para aplicarem com -F0 e conferir que o upstream não mudou o sentido
   do que eles tocam (ler o diff do upstream entre 0fbd457 e 4d14528 nas funções tocadas).
3. Compilar numa cópia (scratchpad, `make VENDOR=1` ou `cargo build --release --offline` como o
   `compositor_patches.sh` faz) e conferir os 5 marcadores no binário. NÃO instalar nada: o build real
   é feito pelo coordenador depois do merge, com `meow compositor`.
4. A série continua aplicando no 0fbd457 se o `patches/` guarda variantes por versão; senão,
   documentar na `matriz.tsv`/`patches/versao` que a série nova vale do 4d14528 em diante.

## Prova
- `patch -p1 --dry-run -F0` dos 5 no fonte 4d14528 limpo: todos entram.
- binário compilado na cópia com os 5 marcadores (`grep -ao 'AURORA-[A-Z-]*-[0-9.]*'`).
- `tests/` da série (os que existirem para patches) verdes.

## Conferência (15/10/2026, conferente)
Refeito do zero, sem aproveitar nada da árvore de quem implementou: o `.tar.xz` do 4d14528 extraído
limpo numa pasta nova do scratchpad.
- **Cada patch sozinho, `patch -p1 --forward -F0 --dry-run`:** os cinco rc=0, nenhum fuzz. Só raio
  (3, 3 e 9 linhas) e menu (2 e 3) entram com deslocamento.
- **A série como o script a aplica:** o `compositor_patches.sh aplicar` real, com a `patches/series`
  da branch e `CP_MATRIZ`/`CP_ALVOS` no scratchpad. Os cinco entram em ordem, rc=0, sem `.rej` nem
  `.orig`. Os cinco caem no degrau 2 só porque o scratchpad não tem `alvos/` para comparar. Uma
  segunda cópia limpa, aplicada à mão em sequência e sem `--silent`, deu árvore idêntica
  (`diff -rq` vazio).
- **O sentido de cada hunk, conferido no código novo:**
  1. `ensure_last_empty`: só cria workspace quando a lista está vazia, e a poda dos vazios logo abaixo
     não mudou. O diff do upstream em `shell/mod.rs` e `workspace.rs` é o diálogo modal, a pilha de
     foco e os minimizados; nada cria ou remove workspace.
  2. As oito durações estão nos valores da série. Os usos de `ANIMATION_DURATION` são os mesmos do
     0fbd457 mais os quatro do tremor, que usa a constante própria e `as_secs_f32`. A mola do slide
     já existia no 0fbd457, e nenhuma divisão inteira de `as_millis()` sobrou.
  3. **Modo de leitura:** os campos e defaults estão dentro do `struct` e do `impl Default`. A cópia
     `leitura_*` no `Config::load` fica depois da migração do `cursor_hide`. O braço do
     `config_changed` convive com o braço novo `cursor_hide`.
  4. **Menu:** `skip(keep_root)` fica no `motion`, e o patch age no `button`. **Raio e blur:**
     arquivos byte a byte iguais aos do 0fbd457.
- **Build:** `nice -n 19 just build-vendored` (extrai o `vendor.tar` e roda
  `cargo build --release --frozen --offline`), rc=0 em 6m53s, sem nenhum warning. O binário sai em
  `target/release/cosmic-comp`, e `grep -ao 'AURORA-[A-Z-]*-[0-9.]*'` acha os cinco marcadores:
  `AURORA-COSMIC-WS-PATCH-3.67`, `AURORA-COSMIC-RADIUS-PATCH-2`, `AURORA-COSMIC-MENU-PATCH-1`,
  `AURORA-READING-MODE-1` e `AURORA-BLUR-CACHE-1`. Nada foi instalado.
- **Testes:** `compositor-shim`, `volta-do-cosmic`, `cosmic-prever`, `doctor-veredito`,
  `portabilidade`, `acento` e `frases-velhas` passam, rodados com `sudo` falso e casa de brinquedo.

**Veredito:** a série está certa no 4d14528, e não precisei de commit de correção.

**O que trava o build real (fora da P85):** o 4d14528 não tem `Makefile`. Os `debian/rules` agora
chamam `just build-vendored`, e `make VENDOR=1` nessa árvore sai com rc=2: *No targets specified and
no makefile found*. O `cmd_compilar` do `compositor_patches.sh` chama `make VENDOR=1` e confere que o
`make` existe. Então `meow compositor` aplica a série e depois falha na compilação, sem instalar nada
(a guarda já está no script). O conserto são duas linhas nesse arquivo, que é da P81:
- `nice -n 19 make VENDOR=1` passa a ser `nice -n 19 just build-vendored`;
- no `for i in patch make cargo`, o `make` passa a ser `just`.

O arquivo é da P81 e por isso não foi tocado aqui. Fica anotado para a integração.

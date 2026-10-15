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

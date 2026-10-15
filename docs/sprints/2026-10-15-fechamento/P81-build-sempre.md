# P81 — O compositor e o cosmic-files se recompilam sozinhos, sempre, e o doctor conserta

**Branch:** `sprint/p81` · **Pedido de quem usa (15/10):** «não deveríamos buildar sempre através
de um daemon?»; «um sistema idempotente que resista a `sudo apt update -y && sudo apt full-upgrade -y
&& topgrade -y && sudo apt autoremove -y && cargo update && sudo apt autoclean -y && limpar_cache -y`».

## Medido em 15/10
- O `apt full-upgrade` das 20:14 trouxe o COSMIC 1.10; o `meow-pos-apt.path` acordou às 20:15 e
  recompilou o `cosmic-files`, mas PULOU o compositor: «o shim do compositor está desligado — sem build».
- O `meow doctor` lista `meow compositor …` para a pessoa digitar (contra «o doctor corrige»).
- Unidade de usuário não vê o carimbo do apt se o apt rodou com a pessoa deslogada ou por TTY.
- O `limpar_cache` dela roda `apt full-upgrade` e `apt clean` de novo; o `cargo update` fora de um
  projeto sai 101 e corta a cadeia (não é do MeowSystem; só registrar no doc de manutenção).

## Tarefas
1. **Uma função só**: `garantir_builds` — para o `cosmic-comp` e o `cosmic-files` instalados, compila
   se não há build válido daquela versão (marcadores conferidos); senão não faz nada (idempotente).
   Trava (`flock`) contra dois builds juntos; `Nice=19`/`IOSchedulingClass=idle`; patch opcional que
   falha sai só ele; obrigatório que falha não troca nada e o shim segue no de fábrica.
2. **Três gatilhos, a mesma função**: o `meow-pos-apt.path` (compila SEMPRE, shim ligado ou não);
   um `meow-builds-login.service` que roda uma vez no login e compara versões (pega apt feito com a
   pessoa deslogada); e o doctor das 5h (`--consertar`) chamando a mesma função.
3. **Doctor sem receita**: `patches`, `leiturabin`, `files_menu` e afins deixam de listar comandos;
   o `--consertar` compila/aplica; a linha só diz o estado (`build pronto, vale no próximo login`).
4. **Sobrevive à cadeia inteira**: teste `tests/cadeia-de-atualizacao.sh` que simula (dpkg falso,
   apt falso, troca de versão, `apt clean`, `autoremove`, limpeza de `~/.cache`) a cadeia acima e
   prova: build refeito para a versão nova, fontes guardados não somem, 2ª passada não escreve nada.
5. **Doc de manutenção**: `docs/MANUTENCAO.md` curto — o que acontece sozinho depois de cada passo
   da cadeia, o que só vale no próximo login, como voltar (`meow compositor desativar`), e a nota do
   `cargo update` fora de projeto.

## Prova
- teste novo vermelho antes e verde depois; `tests/todos.sh` inteiro verde.
- na máquina real, SÓ LEITURA: `MEOW_SHIM_SO_DIZER=1 ~/.local/bin/cosmic-comp` aponta o build da
  versão instalada depois que o build de 15/10 terminar.

## Medido às 20:29 de 15/10 (o pós-apt real terminou)
- O `meow-pos-apt.service` terminou com `ExecMainStatus=1` mesmo com o `cosmic-files` 1.10 compilado
  e vestido (o único `--` foi o compositor pulado por shim desligado). Sucesso tem que sair 0; pular
  por regra não é falha. Corrigir junto com a tarefa 2.
- A última linha do log ainda manda digitar: «ou agora, com: meow painel reciclar». Vira estado
  («vale nas janelas novas; a área de trabalho no próximo login») ou o pós-apt faz o reler único da P80.

## Medido pela P85 (15/10, 21:00): o build do cosmic-comp mudou de ferramenta

O 4d14528 não tem mais `Makefile`: virou `justfile`/`cargo.just` (o `debian/rules` do pacote usa
`just build-vendored`), e o `.cargo/` só existe dentro do `vendor.tar`. Em
`scripts/compositor_patches.sh` (`cmd_compilar`) o `nice -n 19 make VENDOR=1` sai rc=2 («No targets
specified and no makefile found»). Cura VIVA, não troca de uma ferramenta pela outra: detectar o que o
fonte traz — `justfile` com receita `build-vendored` → `just build-vendored`; `Makefile` → `make
VENDOR=1`; nenhum dos dois → `tar pxf vendor.tar && cargo build --release --frozen --offline` — e a
checagem de dependências (`for i in patch make cargo`) pede o que o caminho escolhido usa. Teste com
os três tipos de fonte falso. A P85 provou o caminho `just build-vendored` no 4d14528 (6m53s, 5
marcadores).

- O `just` (e o `cargo`/`rustc`) desta máquina estão em `~/.cargo/bin`; as unidades `meow-pos-apt`, `meow-doctor` e a nova de login precisam ter esse caminho no PATH (achado da P76: `meow-doctor.service` sem `~/.cargo/bin`). Teste: a unidade, com o ambiente que o systemd dá, acha `just` e `cargo`.

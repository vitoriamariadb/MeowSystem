# Conferência do bloco forks: P122

Branch `bloco/forks`, os 4 commits do implementador (`6924d837`, `f002b960`, `454b3a17`, `a13f4c3d`) e os 2 desta
conferência, contra `integracao/central-e-gerador`. Os quatro repositórios `vitoriamariadb/meowsystem-*`, no `main`.

## O que conferi
- Em cada repo:
  - clone novo pela URL do pino, checkout no commit do pino, `CARGO_TARGET_DIR` vazio;
  - `cargo build --release --locked` e `cargo test --release --locked`, um depois do outro;
  - o binário nasce com o nome do `BIN` do pino.
- O `Cargo.toml`, o `Cargo.lock` (a libcosmic do `LIBCOSMIC`), o metainfo (`<id>`, `<binary>`), o `.desktop` e o
  ícone pelo app id.
- O `LICENSE` sem diff contra o upstream. O README e o `Cargo.toml` com o autor do upstream e os dois da casa.
- Os ids antigos que sobraram (docs, créditos, `developer id` do metainfo, código de migração, `src/meh` morto da
  Bateria): nenhum entra no `.desktop`, no `APP_ID` ou no `X-CosmicApplet`. A troca na Dock não esbarra neles.
- O tema, de ponta a ponta:
  - o `extensoes_tema.sh` da integração escreve, num HOME de brinquedo, os quatro `tema.conf` com as sete chaves
    (a Bateria com `tinta` no acento);
  - um teste novo em cada repo cria esse mesmo texto em `$HOME/.config/meowsystem/extensoes/<app id>/tema.conf`;
  - o `Tema::load(APP_ID)` lê esse arquivo, sem chave ignorada, e o `cosmic(true)` devolve tema.
- Os pinos com o `_pino_valido` e o `--estado` da integração, numa mescla de ensaio de `bloco/forks` sobre
  `integracao/central-e-gerador`, que entrou limpa e foi desfeita.

## Achados e correções
| # | achado | correção | commit | prova |
|---|---|---|---|---|
| 1 | Clipboard: o `git clone` do build parava no checkout nesta máquina. A captura do README estava no git-lfs, o `~/.gitconfig` tem `filter.lfs.required=true` e não há `git-lfs`. O `extensoes_build.sh` diria «sem rede?» a cada ciclo e o Clipboard nunca instalaria. | a captura entra como arquivo comum, com o mesmo sha256 do `oid` do LFS do upstream, e o `.gitattributes`, que só tinha as linhas do LFS, sai | `meowsystem-clipboard` `41592eec` | clone novo de `41592eec`: checkout limpo, build e testes verdes. Com `d7ca54e6`: `git-lfs filter-process: git-lfs: not found`, rc=128. |
| 2 | Clipboard: o banco novo ia para `~/.cache/clipboard/`. O `ProjectDirs::from(QUALIFIER, ORG, "clipboard")` usa o nome em minúsculas como pasta, e a pasta genérica não diz de quem é. | pasta `meowsystem-clipboard`, constante `PASTA` no `app.rs`, `INTEGRACAO.md` com o caminho | `meowsystem-clipboard` `4cbed6e9` | teste `o_banco_novo_mora_na_pasta_do_binario` |
| 3 | Os quatro: nenhum teste provava que o applet lê o `tema.conf` no lugar onde o MeowSystem o escreve. Os testes do `tema.rs` usavam caminho direto ou `MEOWSYSTEM_TEMA`. | teste `le_o_tema_conf_que_o_meowsystem_escreve_no_home`, com o texto que o `extensoes_tema.sh` gera, só com o HOME apontado. Uma trava serializa os testes que mexem no ambiente. | `41492b12`, `d7ca54e6`, `e41bad1b`, `ec8bc6e9` | `cargo test --locked` nos quatro: 8, 20 (+1 ignorado), 8 e 8 verdes |
| 4 | Três pinos tinham `MIGRA_ESTADO` com o id antigo. O `_migrar_estado` copia `~/.local/state/cosmic/<id>/v1`, e nenhum dos quatro applets guarda estado lá, só config. A informação estava errada, e o teste a exigia. | `MIGRA_ESTADO=""` nos quatro; o teste confere os quatro vazios | `7045eace` | `tests/extensoes.sh` verde, na worktree e na mescla de ensaio |
| 5 | Os pinos apontavam os commits de antes destas correções | `COMMIT` novo nos quatro; o `LIBCOSMIC` confere com o `Cargo.lock` de cada um | `7045eace` | `git ls-remote origin main` igual ao `COMMIT` do pino, nos quatro |
| 6 | P122 `## Execução`: o hash `6924d937` não existe (é `6924d837`), a tabela trazia os SHAs velhos e o texto sobre o `MIGRA_ESTADO` estava errado | corrigido no lugar | o commit deste relatório | — |

## O que ficou como estava, de propósito
- O Clipboard não compila com a libcosmic do painel (`scroller_width`). O build cai no `--locked` do pino, como o
  script prevê.
- O `.desktop` do Drives mantém o `NotShowIn=COSMIC` e o `MimeType=inode/directory` do upstream: o pedido não muda
  o comportamento além do tema e dos nomes.
- O nome da Bateria no `.desktop` segue só em inglês, como no upstream.
- A config em `~/.config/cosmic/<id antigo>/` não migra. Nesta máquina a do Eyedropper e a do Drives estão vazias,
  a do Clipboard só tem `private_mode=false` (o padrão) e a da Bateria é a de fábrica.
- Nenhum applet foi instalado na máquina, e nenhum popup foi aberto: isso é a rodada 4.

## Placar
- `./tests/todos.sh` na worktree, a partir de `a13f4c3d` (as correções entraram durante a rodada): 102 testes, 99 verdes,
  0 pulados, 3 vermelhos. Nenhum é deste bloco:
  - `decisoes.sh`: aceito (GPU do compositor fora da RTX e shim desligado; é o estado da máquina);
  - `restaurar.sh`: aceito (`pack_usar`, `desinstalar`, `sistema_limpar`, os mesmos de antes do bloco);
  - `git-limpo.sh`: o `git status` mudou porque eu editava a worktree durante a rodada. Sozinho, em `7045eace`, verde.
- Depois das correções, com os falsos do `todos.sh`:
  - na worktree: `extensoes.sh`, `extensoes-pagina.py` (headless) e `applet-pino.sh` verdes;
  - na mescla de ensaio sobre `integracao/central-e-gerador`: `extensoes.sh`, `extensoes-pagina.py`,
    `applet-pino.sh` e `extensoes-gesto.sh` verdes. O `--estado` dos quatro dá rc=0, `casa=1` e `tipo=applet`.
- Builds do zero, clone novo e `--locked`:

  | fork | commit | build | testes | segundos |
  |---|---|---|---|---|
  | Eyedropper | `41492b12` | `meowsystem-eyedropper` | 8 | 166 |
  | Clipboard | `41592eec` | `meowsystem-clipboard` | 20, 1 ignorado | 204 |
  | Drives | `e41bad1b` | `meowsystem-drives` | 8 | 141 |
  | Bateria em ASCII | `ec8bc6e9` | `meowsystem-ascii-battery` | 8 | 153 |

- `git log integracao/central-e-gerador..bloco/forks`: só os commits deste bloco.

## Para ela conferir com a mão
1. Na rodada 4, instalar o Clipboard pela página Extensões: o clone e o build passam sem `git-lfs`.
2. O popup de cada um com as cores do pack, e trocar o sabor muda as cores na próxima abertura.
3. O Clipboard mostra o histórico do applet antigo na primeira abertura, e o banco novo fica em
   `~/.cache/meowsystem-clipboard/`.
4. A troca na Dock: o id antigo sai, o novo entra, e a ordem dos applets continua a dela.

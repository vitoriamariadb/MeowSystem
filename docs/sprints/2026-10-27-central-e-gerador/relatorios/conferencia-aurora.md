# Conferência do bloco aurora: P124 e P125

Branch `bloco/aurora`, os 37 commits do implementador contra `integracao/central-e-gerador`, mais os 2
desta conferência.

## O que conferi
- As provas das duas `## Execução`, rodadas de novo com os falsos do `todos.sh`: `vizinhos.sh`,
  `painel-fantasma.sh`, `vidro-do-cosmic.sh`, `sentinela.sh`, `contrato-cosmic.sh`, `garantir-builds.sh`,
  `ponte-cosmic-comp.sh`, `segunda-passada-sem-rede.sh` e `etapa-compositor.sh`. As nove ficaram verdes.
- P124:
  - `scripts/vizinhos.sh`: o tipo `unidade`, o `--prontos` e o `--desativar-prontos`. Um item devolvido à mão
    não volta a sair, e o `build:` do `requer` pergunta ao shim qual binário ele usaria.
  - `chk_vizinhos`/`fix_vizinhos` no doctor, com a chave `VIZINHOS_DESATIVAR`.
  - O fim novo do `spellbook-terminal-fzf` (`^export FZF_DEFAULT_OPTS=`), conferido contra o `env.zsh` dela.
  - O link do fastfetch que sobrou da briga: só sai o link de dentro de `~/.config/fastfetch` que vai ao
    ZDOTDIR.
- P125:
  - os quatro sinais do painel fantasma em `lib/painel.sh`, comparados com o `aurora-painel-fantasma.sh` dela,
    com a janela de 300 s e a carência de 600 s;
  - o `meow-vidro.path` com os seis `PathChanged`;
  - o `cmd_vigias` da sentinela: rede fora dá rc 3 sem escrever;
  - `chk_areas`/`fix_areas`, que refazem o alfinete caído;
  - o verbo `cosmic-comp-de-fabrica` da ponte;
  - o `--fundo` do `garantir_builds.sh` por `systemd-run`, o `_falha_repetiria` do `extensoes_build.sh` e as
    gravações sem mudança no `wallpaper.sh` e no `atualizar_sistema.sh`.
- A tela: Manter › Sozinho em Playwright headless, com o HOME de brinquedo do `app-completo.py`, em 1829 px e
  em 390 px. «Cortar o repetido» entra como linha de baixo de «Conferir todo dia», no mesmo desenho das outras
  linhas de baixo da maquete (`maquete/a/manter.html`). Não há rolagem para o lado nem erro na página.

## Achados e correções
| # | achado | correção | commit | prova |
|---|---|---|---|---|
| 1 | O `scripts/vizinhos.sh` cortava no ZDOTDIR herdado, mesmo quando ele mora fora do HOME. A suíte deste bloco não tirava o ZDOTDIR. Por isso uma rodada de teste com HOME de brinquedo, por volta das 15h58, cortou o `~/.config/zsh` de verdade dela. O registro do corte ficou no HOME de brinquedo e sumiu com ele. | o `_zdotdir` só aceita um ZDOTDIR que, resolvido, mora dentro do HOME; senão lê o `.zshenv` da casa. É a mesma cura do `65d53c56` no `terminal_bloco.sh`. | bce27b9c | `tests/vizinhos.sh`, bloco 15: com o ZDOTDIR de fora, o `--desativar-prontos`, o `--desativar` e o `fix_vizinhos` do doctor deixam o `install.sh` de lá com o mesmo md5; o ZDOTDIR do `.zshenv` da casa continua sendo cortado. Com o `vizinhos.sh` antigo, 2 falhas. |
| 2 | O `tests/todos.sh` do bloco não tirava o ZDOTDIR herdado | traz o `8c946886` da integração, que já tira | f9989f71 | o retrato do `~/.config/zsh` tirado antes da conferência é igual ao de depois do `todos.sh` final |

## O que ficou como estava, de propósito
- A casa dela não foi mexida. O corte do achado 1 continua lá, e o conserto é do coordenador (está em
  Pendências).
- Os itens `spellbook-terminal-*` só pedem que exista o `terminal_bloco.sh` no MeowSystem instalado. Eles não
  olham se o bloco está mesmo no `.zshrc`. Isso já era assim antes do bloco e vai como anotação.

## Pendências
- **O corte na casa dela.** O `~/.config/zsh` e o `/usr/local/sbin/ritual-aurora-self-heal.sh` estão cortados
  em 21 itens. Os da P125 (vidro, painel fantasma, alfinetes, leitura) saíram antes de o MeowSystem dela ter as
  trocas: o `meow-vidro.path` não está instalado, e o `dev` instalado não tem `chk_areas`. Por enquanto ninguém
  refaz os alfinetes. As unidades da Aurora não saíram e seguem rodando. O commit `73ec71d` (16:05) do
  `~/.config/zsh` tem o corte, e o pai dele, `b72fadf`, tem o original. Há dois caminhos:
  - item por item, com o HOME dela: `scripts/vizinhos.sh --restaurar <item>`. Funciona sem o registro, pela
    marca;
  - de uma vez, pelo git do `~/.config/zsh`, voltando os arquivos cortados ao `b72fadf`.
- Os pendentes do implementador continuam: o cosmic-comp não é o de fábrica (md5 `85f5b0dd`, e o pacote diz
  `1907a3d0`), ninguém chama o verbo novo sozinho, e o `CLAUDE.md` dela ainda cita o
  `aurora-cosmic-workspaces.py`.
- O `AREAS_FOLGA` traz o espaço largo (U+2007), e o disco dela tem «OS» sem ele.

## Incidente desta conferência
Um `python3 app/servidor.py --help`, rodado para ler a ajuda, subiu o painel com o HOME dela. Ele foi parado
sem nenhuma página aberta. Nada do `~/.local/state/meowsystem` mudou depois das 18:25.

A conferência da tela deixou um painel de brinquedo de pé (HOME em `/tmp/meow-completo-*`). Ele foi parado e a
pasta apagada.

## Placar
Último `./tests/todos.sh`, em `f9989f71`: 106 testes, 104 verdes, 0 pulados, 2 vermelhos. Nenhum é deste bloco:
- `decisoes.sh`: aceito (a GPU do compositor fora da RTX; é o estado da máquina);
- `restaurar.sh`: aceito (`pack_usar` e `desinstalar`).

Nenhum teste chamou `sudo` para escrever: as 6 chamadas paradas são `sudo -n true` e `ponte_root.sh estado`. O
`~/.config/zsh` dela tem os mesmos 7299 arquivos, com o mesmo tamanho e o mesmo mtime de antes da conferência.

## Final
Conferência final do bloco, em `82b31b3a`, com o `ZDOTDIR` tirado de cada rodada.

### O que rodou
- `./tests/todos.sh` em `f5942649`: 106 testes, 104 verdes, 0 pulados, 2 vermelhos, os dois aceitos
  (`decisoes.sh` D6 e `restaurar.sh` `pack_usar`/`desinstalar`). O `app-completo.py`, o `app-uso-real.py` e o
  `extensoes-pagina.py` estão entre os verdes. Nenhum `sudo` de escrita: só `sudo -n true` e `ponte_root.sh estado`.
- Depois do conserto abaixo: `doctor-veredito`, `fzf-da-paleta`, `app`, `pack`, `pack-dracula-completo`,
  `nada-manda-digitar`, `instalacao` e `convergencia`, com os falsos da suíte, todos verdes.
- Install e três passadas do `doctor --consertar` numa casa de brinquedo sem rede e sem barramento, com o
  `VERIFICAVEIS` inteiro. A segunda e a terceira passadas não escrevem nada na casa. A única mudança é o
  `~/.cache/dconf/user`, que o cliente do dconf regrava quando falta o barramento; o MeowSystem não grava nele.
- As cinco portas (Tema, Personalizar, Definir, Manter, Extensões, com as 16 rotas) no Playwright headless,
  com os dois packs (`PACK`/`FLAVOR` meowsystem/mocha e dracula/dracula), em 1829 px e em 390 px. Não houve erro
  na página, erro no console, resposta 4xx/5xx, imagem quebrada nem rolagem para o lado. «Cortar o repetido»
  aparece embaixo de «Conferir todo dia» nos dois packs.
- Retrato do `~/.config/zsh`, do `~/.local/state/meowsystem`, das unidades, do `~/.config/cosmic` e do self-heal,
  tirado antes e depois de tudo. Só mudaram o perfil do navegador do painel dela (que estava aberto), o
  `meow.log` (o `fastfetch_logo.sh aplicar` do terminal), o `wallpaper.log` do timer dela e o `painel.log` (ela
  fechou o painel). Nenhum vazamento.

### Achado e correção
| # | achado | correção | commit | prova |
|---|---|---|---|---|
| 3 | Numa casa sem rede o install não fechava: o `curl` falhava, o `sh` do pipe lia a entrada vazia e saía 0, e a etapa dizia «starship instalado» e contava como mudança. Em cada passagem acontecia a mesma coisa, até o install parar com «as mesmas etapas escreveram em duas passagens seguidas: prompt». Isso já estava assim no `dev`. | o `cmd_instalar_starship` só conta a instalação quando o starship ficou | 82b31b3a | `tests/doctor-veredito.sh` seção 9: sem rede dá rc 2, sem binário e sem «instalado». Sem o conserto fica vermelho. O install da casa de brinquedo sem rede fecha na passagem 3, com o prompt em «falhou». |

### Anotado, fora do bloco
- As palavras «Vestir» e «Vestir agora» ainda aparecem no Tema, em Personalizar › Disponibilizar e em
  Definir › Programas. São da P118 (bloco Textos) e entram no merge.
- Sem rede, o `cursor.sh` imprime a receita com `curl`/`unzip` para fazer à mão. O `nada-manda-digitar.sh` não
  pega isso. Já era assim antes do bloco.
- Quando ela abre o terminal, o `fastfetch_logo.sh aplicar` grava no `meow.log` real. Não é teste, é o gancho
  do terminal.
- Sobrou uma `/tmp/meow-completo-*` das 20:08, sem processo vivo, que um dos testes de navegador da suíte deixou.
  Ela foi apagada. Outras três, de outras rodadas (10:31 e 17:05), ficaram como estavam.
- O `pinned_workspaces` dela tem duas áreas com nome, « Meow » (com a folga) e «OS». O `III` não está
  alfinetado no disco e não está no `AREAS_NOMES`, então o `fix_areas` não o refaz. Com o conf de hoje, o
  `areas.sh alfinetes` (só leitura) diz «de pé (Meow, OS)».

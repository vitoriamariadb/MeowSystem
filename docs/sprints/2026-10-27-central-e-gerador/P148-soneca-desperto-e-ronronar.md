# P148 — Soneca: o applet do modo Desperto e do modo Ronronar

Anotada em 29/10. Ela fechou a tampa achando que o PC não ia suspender, e a sessão caiu com cinco agentes no meio:
«Tampa do notebook, inclusive vamos criar uma extensão no padrão do meowsystem pra permitir o modo desperto e Modo
Ronronar. Algum trocadilho com gatos. [...] abra uma pasta nova [...] ele irá integrar o projeto na parte das
extensões sendo um programa próprio em si.» Nome decidido pelo coordenador: **Soneca** (a soneca de gato).

## O que se mediu
- `HandleLidSwitch` de fábrica no `logind` (suspende ao fechar a tampa). A sessão COSMIC só segura
  `handle-power-key`. Nada do MeowSystem segura tampa nem ocioso.
- `systemd-inhibit --what=handle-lid-switch:sleep:idle --mode=block` como usuário da sessão ativa funciona sem
  senha (o coordenador segura assim desde 29/10, unidade de usuário `meow-desperto-coordenador.service`).

## O programa (repositório novo `vitoriamariadb/meowsystem-soneca`, pasta `~/Desenvolvimento/meowsystem-soneca`)
- Applet COSMIC em Rust/libcosmic no molde do `meowsystem-performance` (programa da casa, sem upstream): mesmo
  `LIBCOSMIC` e `Cargo.lock` de base, `data/<app id>.desktop.in`, `INTEGRACAO.md`, `README.md`, `LICENSE` (a mesma do
  performance). App id `io.github.meowsystem.Soneca`, binário `meowsystem-soneca`.
- Dois modos:
  - **Desperto**: o applet segura a trava do logind (`org.freedesktop.login1.Manager.Inhibit`,
    `handle-lid-switch:sleep:idle`, `block`) enquanto o modo está ligado. Tampa fechada e ocioso não suspendem.
  - **Ronronar**: sem trava; o PC dorme como o sistema manda.
- O modo escolhido persiste (estado em `~/.local/state/cosmic/io.github.meowsystem.Soneca/` ou cosmic-config) e
  volta no login seguinte.
- Bateria: no Desperto, na bateria e abaixo de 10% sem carregar, a trava solta e o modo vira Ronronar (notificação
  curta); o limiar é constante no código, testado.
- Ícone do painel: gato de olhos abertos (Desperto) e gato enrolado de olhos fechados (Ronronar), SVG simbólicos
  próprios do applet. Clique abre o popup com os dois modos; o marcado usa o acento do pack (`tema.conf`, como os
  outros, chaves `acento`, `fundo`, `borda`, `texto`, `destaque`).
- Linha de comando: `--estado` (imprime `desperto` ou `ronronar` e sai), `--desperto`, `--ronronar` (grava o modo;
  o applet no ar acompanha a mudança).
- Textos em português do Brasil. Interface mostra, não explica.

## No MeowSystem (worktree `~/Desenvolvimento/MeowSystem-soneca-p148`, branch `bloco/soneca-p148`)
- `assets/extensoes/soneca.pino` (ORDEM=10, TIPO applet, PADRAO sim, ATIVA painel, NOME «Soneca», DESCRICAO curta,
  URL, COMMIT, VERSAO, LIBCOSMIC, APP_ID, BIN, DESKTOP, ICONES, TEMA, TEMA_CHAVES), no molde do `performance.pino`.
- O que mais a página Extensões e o `extensoes_build.sh` pedirem para um applet novo (inventário, testes que contam
  os pinos, `docs/`).

## Prova
- No fork: testes de unidade (troca de modo, persistência, limiar da bateria, leitura do `tema.conf`) e um teste de
  integração da trava contra um logind falso (zbus em barramento de teste, ou a camada de trava atrás de um trait);
  `cargo build --release --locked`, `cargo test --release --locked`; commit e push na `main`.
- No MeowSystem: `tests/extensoes.sh` e `tests/todos.sh` sem vermelho novo.
- Na máquina, depois do install: Desperto ligado, `systemd-inhibit --list` mostra a trava do Soneca; Ronronar, some.

## Execução

Fork: <https://github.com/vitoriamariadb/meowsystem-soneca>, pasta `~/Desenvolvimento/meowsystem-soneca`, branch `main`,
sete commits de `1581fd4` a `15d0a37` (o pino fixa `15d0a375416739c9f26a879010d27da60b377e3d`).

| item | onde | prova |
|---|---|---|
| os dois modos, o estado em disco, o limiar da bateria | `src/modelo.rs`, `src/estado.rs`, `src/bateria.rs` | testes de unidade: troca de modo, persistência (volta na leitura seguinte, arquivo ilegível vale o padrão), limiar 10% (9 solta, 10 não; na tomada nunca), bateria de periférico não conta |
| a trava do logind | `src/trava.rs` | trait `Logind`; o teste de integração sobe um logind falso em zbus `p2p` (par de sockets, sem barramento) e confere os quatro argumentos do `Inhibit`, a trava de pé enquanto o applet a segura e o descritor fechado ao largar |
| aviso da bateria | `src/aviso.rs` | `Notify` no barramento da sessão; o texto cita o limiar do código |
| tema do pack | `src/tema.rs` | o mesmo contrato do performance (`acento`, `destaque`, `fundo`, `borda`, `texto`, `bloco`); testes de leitura do `tema.conf` |
| applet, ícones, linha de comando | `src/main.rs`, `data/` | `--estado`, `--desperto`, `--ronronar` rodados com `XDG_STATE_HOME` de brinquedo (grava, lê, falha com rc 1 sem permissão) |
| instalação | `install.sh` | instalado e removido num prefixo temporário; a suíte compara o que ele põe com o que o pino põe: 3 arquivos iguais |
| MeowSystem | `assets/extensoes/soneca.pino` (ORDEM=10), `assets/extensoes/icones/soneca.svg`, `tests/extensoes.sh`, `tests/extensoes-install.sh`, `docs/CREDITOS.md`, `docs/FRONTEIRA.md` | `extensoes.sh` e `extensoes-install.sh` verdes (dez pinos com URL) |

- `cargo build --release --locked`: verde, sem aviso. `cargo test --release --locked`: 30 testes verdes.
- `./tests/todos.sh`: 120 testes, 118 verdes, 0 pulados, 2 vermelhos, os dois aceitos: `readme.sh` (badge v2.2.0) e
  `restaurar.sh` (`pack_usar` e `desinstalar`). `decisoes.sh` passou desta vez.
- Fora do que a máquina prova hoje: Desperto ligado mostrar a trava em `systemd-inhibit --list` depois do install (pede o
  applet no painel, instalado pelo coordenador).

### Decisões fora da sprint
- O modo padrão, sem arquivo nenhum, é Ronronar: o applet novo nunca segura trava sem ela ter escolhido.
- O estado é um arquivo de texto de uma linha (`desperto` ou `ronronar`) em `~/.local/state/cosmic/<app id>/v1/modo`, não
  RON do cosmic-config: a linha de comando e o `cat` leem sem biblioteca. O applet relê a cada 2 s e é assim que
  `--desperto` e `--ronronar` valem com ele no ar.
- Quando a bateria força o Ronronar, o modo é gravado em disco: o Desperto não volta sozinho no login seguinte.
- `--estado` diz o modo gravado, não consulta o logind: com o applet fora do ar o modo gravado pode ser Desperto sem trava.
- O pino declara `ICONES` com o ícone simbólico em `hicolor/scalable/apps` e o `.desktop` usa `Icon=…Soneca-symbolic`; o
  performance usa um ícone de tema do sistema. O `install.sh` do fork instala o mesmo arquivo.
- `tests/extensoes-install.sh` passou a procurar a árvore de cada fork também em `~/Desenvolvimento/<repo>`
  (`EXTENSOES_DESENVOLVIMENTO`): sem isso, o Soneca, que ainda não tem clone em `~/.local/state/meowsystem/extensoes`,
  faria o teste inteiro sair «pulado». O `Cargo.lock` ganhou uma aresta (`zbus` para `getrandom 0.4.3`, do recurso `p2p` de
  dev-dependency); nenhuma crate nova.
- Anotado, não feito: o texto de `EXTENSOES` em `meow.conf.exemplo` (linha 1496) lista cinco ids e já estava velho antes do
  Soneca; `meow.conf.exemplo` fica para quem arrumar a lista toda.

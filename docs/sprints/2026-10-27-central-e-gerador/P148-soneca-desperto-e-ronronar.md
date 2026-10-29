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

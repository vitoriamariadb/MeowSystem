# P76 — Sobreviver às atualizações do COSMIC (o sistema vivo)

**Branch:** `sprint/p76` · **Fonte:** `docs/pesquisas/2026-10-09-cosmic-vivo.md` (tarefas 1–9).

## Pedido de quem usa
«Ele tem que sobreviver independente do upgrade do COSMIC: eles atualizam e isso não quebra nada,
e evolui com o sistema operacional. Ele tem que ser vivo.» «definitivo, modular, independente,
idempotente».

## Tarefas (ordem de risco)
1. Rebasear o patch do menu de papel de parede do `cosmic-files` para o 1.10 (`src/menu.rs`).
2. Compositor no escopo do usuário: build em `~/.local/libexec/meow/cosmic-comp/<versão>`, shim
   `~/.local/bin/cosmic-comp` que usa o build só se a versão bate com o dpkg e não houve queda; senão
   o de fábrica. `/usr/bin` volta de fábrica. **NÃO ativar nesta máquina**: entregar desligado,
   com o comando de ativação e o de volta, porque a prova exige um login.
3. `meow cosmic prever`: pré-voo do candidato antes do `full-upgrade` (esquema/chaves dos .deb
   novos, série de patches no fonte novo, rust-version, revisão do libcosmic, guarda do fonte).
4. Gatilho pós-apt + unit `.path` do usuário que reconstrói de forma idempotente o que mudou de
   versão; `patches/versao` vira tabela gravada pela máquina; patch opcional que falha sai só ele.
5. Rust e volta: não apagar o único `.deb` de fábrica; fonte guardado fora de `~/.cache`.
6. Contrato de esquema: `contratos/cosmic.tsv` + `meow_cosmic_v` no lugar do `v1` fixo; furo de
   `lib/preflight.sh:71`; `.path` do raio vigiando o namespace.
7. Oráculo do tema: derivação real do libcosmic na revisão do `cosmic-settings` instalado.
8. Applets próprios seguem a revisão do libcosmic do painel; `leiturabin`/`midiabin` saem de
   `SEM_CONSERTO`.
9. Miúdos: `escala.sh` com `cosmic-randr list --kdl`, regex do backoff, `CosmicViewer` sem arte,
   comentário do `appid_dock.sh`.

## Prova
- patch do cosmic-files aplica com `-F0` no fonte 1.10 (já baixado no scratchpad da auditoria).
- `meow cosmic prever` contra o 1.10 → relatório verde/vermelho por item.
- simulação de troca de versão (dpkg falso) → shim cai na fábrica; gatilho reconstrói; idempotente
  (2ª passada não escreve nada).

## Estado da execução (09/10/2026, sprint/p76)

Tudo medido nesta máquina; nada aplicado no HOME de verdade, nada com sudo.

| # | Estado | Commit | Prova rodada |
|---|---|---|---|
| 1 | feito | 1140ed0 | `patch -p1 -F0 --dry-run` do patch novo no `cosmic-files` 1.10 (ac5cef7) puro: rc=0; o do 1.9 no mesmo fonte: rc=1. Build do `cosmic-files-applet` 1.10 patchado: 3 min 43 s, `grep -a -c MEOW-FILES-WALLPAPER-PATCH-1` = 1. O do 1.9 ficou como `cosmic-files-wallpaper-menu-1.9.patch`; o `files_menu.sh build` tenta os dois com `-F0`, do mais novo ao mais velho |
| 2 | feito, **desligado** | fe37d6f | `tests/compositor-shim.sh`: 24 ok (versão igual/diferente, `ruim`, sem build, estado sem `req`, duas quedas -> `ruim`, sessão longa zera, verbos). Ligar: `meow compositor` (compila em `~/.local/libexec/meow/cosmic-comp/<versão>`) e `meow compositor ativar`; voltar: `meow compositor desativar`. O `/usr/bin` volta de fábrica no próximo apt do `cosmic-comp` (ou reinstalando o pacote, decisão dela). Falta a prova do login, à mão |
| 3 | feito | 59d062d | `cosmic_prever.sh --debs <1.10> --fontes <1.10>`: esquema igual nos 4 pacotes; todas as chaves presentes, `leitura_temperatura` ausente no de fábrica (esperado); série: 4 com `-F0`, modo de leitura só com `-F1`; menu do cosmic-files verde (é o rebase do item 1); toolchain 1.93 contra 1.93.1/1.93.0 "no limite"; `theme.rs` mudou entre c003a58 e 5a8bd94. `tests/cosmic-prever.sh`: o bom sai rc 0, o quebrado rc 1 |
| 4 | feito | 9d9dc3c | `tests/pos-apt.sh`: um build por versão nova, zero na segunda passagem (o arquivo de versões nem é reescrito), passo que falha não grava. Escada contra o 41497b4, com os alvos puros do 0fbd457: **2 no degrau 1** (raio, blur) **e 3 no degrau 2** (workspace-vazio e menu-clique-curto: `-F0` limpo, mas o upstream mexeu em `tiling/mod.rs`, `shell/mod.rs`, `workspace.rs`, `grabs/menu/mod.rs`; modo de leitura: `-F1`). A pesquisa esperava "4 no 1 e o modo de leitura no 2"; o critério dela mesma (`diff -q` dos arquivos tocados) dá o que está aqui |
| 5 | feito | 13c79e8, e16a83f | `atualizar_sistema.sh limpar` em seco: "guardaria cosmic-comp_0.1~1790118748~24.04~0fbd457_amd64.deb". `tests/volta-do-cosmic.sh`: 15 ok. O pós-apt roda `rustup update` quando o pré-voo acusa toolchain vermelho (`tests/pos-apt.sh`) |
| 6 | feito | a5e9afb | `tests/contrato-cosmic.sh`: janelas, relógio, terminal, vidro e forma gravam no `v2` de um `/usr/share/cosmic` falso, sem nascer `v1`; o pré-voo dá aviso para `v1 v2 v3` e `v2 v3`. Na máquina: as 15 chaves do contrato presentes nos binários instalados, `meow_cosmic_v` = v1 (comp, painel), v2 (tema) |
| 7 | parcial | 5277441 | Oráculo (`src/oraculo-tema`) compilado contra d77e99f (o libcosmic do cosmic-settings 1.9 instalado) e 5a8bd94 (o do 1.10), 38 s e 32 s. Contra o Python, no dracula-mauve (254 campos): d77e99f igual nas duas árvores; 5a8bd94 igual na Dark e diferente **só** em `background.component.pressed` na Light (#E9EAF5E1 -> #B6B7C2E1) — e o mesmo campo nas Light das três capturas do Catppuccin. A hipótese do §2.4 se confirma para o Dracula escuro. `tests/oraculo-tema.sh`: 5 ok. **Não feito**: o oráculo refazendo o produto na montagem do tema (é o `aplicar_tema.sh`, território da P74) |
| 8 | feito, menos o coredump | 9fc905f | `tests/applet-pino.sh`: 16 ok (o build só quando o painel anda depois da base; volta ao pino quando falha; `--conferir` não escreve). `leiturabin` e `midiabin` saíram do `SEM_CONSERTO`, com `fix_` que recompila. Na máquina: painel 1.9 pina 23f5d63, os applets 1f6dc99; a regra adota a base sem recompilar, e o applet anda no próximo apt. **Não feito**: o coredump retirando a sombra |
| 9 | feito | 67f5ecd, c1969d7, 872b913, e96ec04 | `escala.sh` pelo `--kdl`: saída igual byte a byte à do awk antigo nesta máquina; `tests/escala-kdl.sh`. Backoff sem medida vira `nao-medida` e o `reciclar` recusa: `tests/backoff-do-supervisor.sh`. `meow cosmic icones`: "sem desenho: com.system76.CosmicViewer"; no 1.10 nenhum `.desktop` entra ou sai. `meow cosmic prever` acusa "cosmic-applets instalado é o 82e7cd8; scripts/appid_dock.sh foi medido no 40248fb" |

Testes (HOME temporário, `sudo` falso no PATH): `tests/todos.sh --portatil` — 36 de 38
verdes depois dos ajustes (d1d62a0). Os dois vermelhos existem também no dev (f24868c),
com o mesmo ambiente: `portabilidade.sh` (o `/home/<nome>` na linha 198 da pesquisa) e
`doctor-so-le.sh` (a conferência "com o HOME da sessão" não acha o painel com HOME de
brinquedo). Os da máquina (Playwright) não rodaram.

### O que se confere com a mão (depois de ligar o shim e do primeiro `full-upgrade`)

- `meow compositor` e `meow compositor ativar`; no login seguinte,
  `readlink /proc/$(pgrep -x cosmic-comp)/exe` em `~/.local/libexec/meow/cosmic-comp/…`;
- a tela de login abrindo normal (ela não vê o shim);
- o modo de leitura mudando a tela; o menu de papel de parede no desktop;
- o hook novo do apt chega em `/etc` pelo `etapa_lancador_apt` (ponte), e o
  `meow-pos-apt.path` pelo `etapa_vigia_apt`, na próxima passagem do instalador.

## Achados para a próxima leva

- O gatilho do pós-apt mora no `99-meow-lancador`, que só se instala com
  `LANCADOR_SISTEMA="sim"`. Um hook próprio desacopla, mas pede um verbo novo na ponte root.
- O doctor não confere as unidades `meow-pos-apt.*` (é da P75); e o pré-voo não roda no
  doctor quando `apt list --upgradable` mostra `cosmic-*` (§4.2), nem o `lib/preflight.sh`
  saiu da instalação para o doctor (§4.4).
- A chave ausente no binário ainda não impede o escritor de gravar (§4.4, princípio D).
- O `completar_icones.sh` não lê a lista do `meow cosmic icones` (território de ícones, P73/P74).
- `v1` cravado fora da lista da spec: `lib/noite.sh`, `logo.sh`, `instalar_fontes.sh`,
  `construir_icones.sh`, `completar_icones.sh`, `auditar_icones.sh`, `leitura_build.sh`
  (ASA/MEIO), `janelas.sh:348` (`Dark/v1/gaps`) e os de estado do `wallpaper.sh`.
- A ponte faz `update` e `full-upgrade` num verbo só: o pré-voo lê a fila do último
  `apt update` do sistema, não a que o upgrade vai instalar.
- Decisões abertas da pesquisa (§6) que o código assumiu e são dela: a escada aceita o
  degrau 2 sozinha (sob a guarda de queda); o GitHub é a única fonte da revisão do
  libcosmic (o fonte do apt como reserva não foi feito).
- Com o shim ligado e o primeiro apt, o `/var/lib/meowsystem/cosmic-comp/patches.estado` e
  o `.pacote` antigos ficam sem uso (o `conferir` os ignora no modo shim); apagá-los é sudo.
- A doutrina "nunca `apt upgrade`" (`docs/COSMIC-THEMING.md` §6) não foi tocada: é a
  tarefa 10 da pesquisa, decisão de gente depois do login com o shim.

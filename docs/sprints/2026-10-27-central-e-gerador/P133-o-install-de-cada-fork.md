# P133 — o install de cada fork e o nosso

Anotada em 28/10 (ela: «se nossas extensões, cada repositório nosso forkado, já no nosso install tá chamando o
install de cada um deles»).

## O que se mediu
- Os 9 forks (`assets/extensoes/*.pino` com `URL`): ascii-battery, clipboard, drives, eyedropper, leitura,
  now-playing, performance, quick-settings e status-hub. Os 9 estão instalados, e o `COMMIT` de cada pino é o
  `HEAD` da `main` do fork (`git ls-remote`, 28/10).
- O `install.sh` não chama o install de nenhum deles. O `etapa_extensoes` roda `scripts/extensoes_build.sh --todas
  --aplicar`, que clona no `COMMIT`, fixa a `libcosmic` do pino, roda `cargo build --release --locked` e copia só o
  binário, o `.desktop` (a sombra) e os `ICONES` do pino (`_instalar_arquivos`).
- O que o install de cada fork faz e o nosso não faz:
  - o metainfo (`install-user` do just em ascii-battery, clipboard, drives, eyedropper, now-playing e status-hub;
    `install.sh` do quick-settings): nenhum `meowsystem` em `~/.local/share/metainfo/`;
  - o `install-schema` do clipboard (`res/config_schema.json`);
  - o ícone colorido do status-hub ao lado do simbólico;
  - o `deps.sh` do quick-settings (confere `wpctl`, `pw-dump`, `pactl` e o rustc 1.93, e chama `sudo apt-get`).
- Os installs dos forks não seguem um contrato: seis usam `just install-user`, três usam `install.sh <prefixo>`, e
  um deles chama `sudo` sozinho.

## Cura na origem (proposta do coordenador)
- O build continua nosso (ele segura a `libcosmic` fixada, a sombra, o carimbo, o reverter e o doctor). Chamar o
  install de cada fork traria `just` como dependência, um segundo `cargo build` fora do nosso alvo e um `sudo` no meio.
- O pino passa a declarar o que o install do fork põe e o nosso não põe (um campo `METAINFO`, e o par de ícones do
  status-hub em `ICONES`), e o `_instalar_arquivos` copia e o reverter tira.
- Um teste compara, em cada fork, o que o `install-user`/`install.sh` instala com o que o pino declara, para que um
  arquivo novo no install do fork acenda vermelho aqui em vez de faltar em silêncio.

## Prova
- O teste novo verde para os 9 forks; `./tests/todos.sh` verde; depois do install, em `~/.local/share/metainfo/`, o
  metainfo dos sete que têm um (leitura e performance não trazem metainfo).

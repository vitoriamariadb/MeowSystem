# P152 — máquina nova sem atrito

Anotada em 30/10. Ela vai instalar o MeowSystem numa máquina nova, Pop!_OS 24.04 com COSMIC, e perguntou: «vai tá
fácil lá né? se eu rodar o install e tal?». Depois, o escopo cresceu por pedido dela: «o nosso ./install.sh não
deveria fazer isso já? Por default e sem flag? [...] Tanto baixar como instalar dessa forma. Tudo?». O
`./install.sh` sem flag baixa e instala tudo; o `.deb` (P150) é um caminho a mais.

## O que se mediu (30/10, `dev` em 2a0ce9f2)
- Rust. O `meow_garantir_cargo` (`lib/comum.sh`) baixa o `https://sh.rustup.rs` sem versão nem sha e roda com
  `sh`; só o `extensoes_build.sh` o chama, uma vez por applet. O `compositor_patches.sh compilar` e o
  `files_menu.sh build` só conferem o `cargo` no PATH e desistem («o cargo é o do rustup de quem compila; o do apt
  costuma ser velho demais»). Os builds em segundo plano rodam pelo `systemd-run --user`, cujo PATH não tem o
  `~/.cargo/bin` quando o rustup foi instalado com `--no-modify-path`. Numa máquina sem rustup, as dez extensões,
  o compositor e o Menu do Arquivos ficam de fora.
- O mínimo do Rust. Os pinos `leitura`, `now-playing`, `performance`, `soneca` e `status-hub` pedem
  `rust-version = "1.93"`, o `clipboard` 1.88; todo `libcosmic` dos pinos (sete revisões) pede 1.93; o
  cosmic-comp `0.1~1792508925` pede 1.93 e traz `rust-toolchain.toml` com `channel = "1.93"` e `rust-src`, que o
  rustup baixa sozinho na primeira compilação. O mínimo é 1.93.
- O `rustup-init` oficial: `https://static.rust-lang.org/rustup/archive/1.29.2/<alvo>/rustup-init`, 21 MB; sha256
  do x86_64 `5be191e8…ec24f4` (o `.sha256` publicado, o arquivo baixado e o `~/.cargo/bin/rustup` desta máquina
  batem), do aarch64 `a9c168db…d797e697` (publicado e baixado batem).
- Pacotes. A `etapa_pacotes` instala só a base e, com `MIDIA` ou `LEITURA_APPLET` ligados, o
  `MEOW_DEPS_DOS_APPLETS` (build-essential, pkg-config, xkbcommon, wayland, dbus). O que o compositor e o
  cosmic-files pedem para compilar só existe no `Recommends` do `.deb`: quem roda o `./install.sh` não recebe.
  O `drives` liga `libudev-sys`, que pede o `libudev-dev`, fora da lista dos applets.
- `Build-Depends` (pelo `.dsc` guardado e pelo `apt-cache showsrc`): cosmic-comp — `cargo`, `cmake`,
  `debhelper-compat`, `just`, `libegl1-mesa-dev`, `libfontconfig-dev`, `libgbm-dev`, `libinput-dev`,
  `libpixman-1-dev`, `libseat-dev`, `libsystemd-dev`, `libudev-dev`, `libwayland-dev`, `libxcb1-dev`,
  `libxkbcommon-dev`, `libdisplay-info-dev`, `rustc`; cosmic-files `1.11.0~1792510858` — `debhelper-compat`,
  `git`, `just`, `libclang-dev`, `libglib2.0-dev`, `libxkbcommon-dev`, `pkg-config`, `rust-all`. O `cargo`, o
  `rustc` e o `rust-all` ficam fora (o Rust vem pelo rustup) e o `debhelper-compat` também (ninguém roda
  `dpkg-buildpackage`); o `patch` e o `dpkg-dev` (`dpkg-source -x`) são do nosso caminho. O `libclang-dev` também
  fica: o `Cargo.lock` do cosmic-files no pino `3cc4b80` não tem `bindgen` nem `clang-sys`, e o Menu do Arquivos
  compilou aqui sem ele; o `just` também, porque o nosso build chama o `cargo` direto.
- O `deb-src` vem ligado no Pop!_OS (`/etc/apt/sources.list.d/system.sources`, `Types: deb deb-src`). Desligado, o
  `compositor_patches.sh` dizia «o deb-src está habilitado nas fontes do apt?» e o `files_menu.sh` «o deb-src está
  habilitado?»: pergunta, não o fato.
- Senha. A `etapa_ponte_root` pede o sudo uma vez (`sudo -v`) e instala a ponte, que tem o verbo `pacotes` com uma
  lista literal. A `etapa_pacotes` não usa a ponte: chama `sudo apt-get install`, que só não pergunta de novo
  porque o carimbo do `sudo -v` ainda vale; o doctor já usa a ponte (`fix_pacotes`). Sem sudo, ela imprimia
  «instale à mão:» e «apt install …»; depois de uma falha, «sudo apt-get install …»: as duas mandam digitar.
- O fim do install. A etapa do compositor diz «construindo em segundo plano: … — vale no próximo login» no meio
  da saída; o «Pronto.» do fim não diz nada.
- Baixar. O README mostra `git clone` e `./install.sh --wizard`. O fecho de dependências do `pop-desktop`
  (`apt-cache depends --recurse --important`) traz `tar` e `python3`; o `git` e o `curl` vêm pelos `Recommends`
  (`pop-desktop` → `pop-server` → `pop-container-interactive`), que o apt instala por padrão. O install não lê
  versão nenhuma: o único `git` dele é o driver de merge, que se pula fora de um clone.

## Causa
- O Rust e as bibliotecas de compilar entravam como pré-requisito de quem compila, não como parte do que o
  MeowSystem traz. A lista de build morava em dois lugares (`MEOW_DEPS_DOS_APPLETS` e o `control`), e o do
  compositor e do Arquivos só em um.

## Cura
- `assets/pacotes/compilar.tsv`: grupo e pacote, os três grupos (`applets`, `compositor`, `menu-arquivos`). É a lista
  única: a `etapa_pacotes` e o `chk_pacotes` do doctor pedem os grupos das etapas ligadas (`applets` se há
  extensão querida, `compositor` com `COMPOSITOR` ligado e o cosmic-comp instalado, `menu-arquivos` com
  `FILES_MENU` ligado e o cosmic-files instalado), e o `scripts/deb.sh` escreve o `Recommends` dela. A ponte
  guarda a própria lista literal (a regra dela), e um teste prova que as duas batem. Sai o `MEOW_DEPS_DOS_APPLETS`.
- `assets/rust/rustup.pino`: versão, URL e sha256 por alvo, e o `RUST_MINIMO`. `scripts/rust.sh
  conferir|aplicar|remover`: quando falta o `cargo`, ou o `rustc` é mais velho que o mínimo, baixa o
  `rustup-init` (BAIXA DA INTERNET), confere o sha, e roda `-y --no-modify-path --profile minimal
  --default-toolchain stable`. Com sha errado não roda nada. Com um rustup que já existia e um `stable` velho,
  atualiza o `stable` dele. O que o MeowSystem trouxe fica anotado em `~/.local/state/meowsystem/rust/trouxe` e no
  registro do Restaurar (`meow_guardar_pasta`, pasta nova); o `remover` e o desinstalar tiram só isso.
- `meow_rust_no_path` põe o `~/.cargo/bin` na frente do PATH; o `meow_garantir_cargo` vira o `rust.sh aplicar`; o
  `compositor_patches.sh compilar` e o `files_menu.sh build` passam por ele.
- `etapa_rust` logo depois da `etapa_pacotes` (antes do Menu do Arquivos e das extensões); `rust` no
  `VERIFICAVEIS` do doctor, com conserto.
- A `etapa_pacotes` instala pela ponte quando ela responde, pelo `sudo -n` quando o carimbo vale, e só pede a senha
  num terminal sem ponte (`PONTE_ROOT="nao"`). Sem sudo ou depois de uma falha, diz o fato, deixa a pendência, e o
  doctor tenta de novo.
- `deb-src` desligado: o fato («as fontes do apt desta máquina não servem código-fonte (sem deb-src)»), e o de
  fábrica segue.
- O fim do install diz, numa frase, quando um build corre em segundo plano e vale no próximo login.
- README: o caminho de uma linha (`git clone … && cd MeowSystem && ./install.sh`) e, sem `git`, o do arquivo do
  GitHub com `curl` e `tar`.

## Prova
- `tests/maquina-nova.sh` (portátil), HOME temporário, sem rede, sem `cargo` no PATH: um `curl` falso serve um
  `rustup-init` falso de sha conhecido. Confere: a etapa baixa, confere o sha e roda o `rustup-init` com
  `--no-modify-path`; com sha errado não roda nada; a segunda passada não escreve; com `cargo` novo no PATH nada
  acontece; com `rustc` velho ela traz o Rust; o Restaurar e o `remover` tiram só o que trouxe, e um rustup que já
  existia fica. Pacotes, com `apt-get` e `dpkg-query` falsos: um `./install.sh` sem flag pede os de build do
  compositor, do cosmic-files e dos applets, e o rustup; com `COMPOSITOR=nao`, não pede os do compositor; a
  segunda passada não pede nada. O `Recommends` do `.deb` gerado é a lista; a ponte aceita toda a lista. O
  `deb-src` desligado dá o fato. O install roda de um `git archive` (sem `.git`).
- `tests/todos.sh` inteiro sem vermelho; `.deb` regerado e `lintian`.

## Execução (30/10)
- `2aecec09` lista única de compilar (`assets/pacotes/compilar.tsv`, 20 pacotes em três grupos), a ponte aceita
  todos, `decisoes.sh` e `doctor-veredito.sh` leem a lista. `554d81c1` `scripts/rust.sh` e o pino; `etapa_rust`
  depois da `etapa_pacotes`; `rust` no doctor (82 conferências, 72 etapas); `etapa_pacotes` pela ponte, pelo
  `sudo -n`, e só num terminal sem ponte pelo `sudo`; o fim do install diz quando um build corre em segundo plano;
  o desinstalar chama o `rust.sh remover`. Com `MEOW_SEM_REDE=1` o rustup não baixa. `5c6349bb` o fato do
  `deb-src` e do cargo no compositor e no Menu do Arquivos. `5c0f7d58` README nas duas línguas. `f71c0a80` o
  `Recommends` do `.deb` sai da lista (`@COMPILAR@`), e o `tests/deb.sh` confere cada pacote dela no `.deb` gerado.
  `dd9d6529` `tests/maquina-nova.sh` (portátil, 40 conferências).
- A ordem da senha na máquina nova: o preflight faz o `sudo -v` (a única senha), a `etapa_ponte_root` instala a
  ponte dentro desse carimbo, e daí em diante os pacotes descem pela ponte; o rustup, os applets e os builds não
  pedem root.
- `COMPOSITOR="nao"` vale pelo `meow.conf`: o install lê o arquivo depois do ambiente, e o teste escreve lá.
- `.deb` regerado (`meowsystem_2.2.0+126_all.deb`): o `Recommends` traz os 20 da lista; `lintian` 2.117 sem erro, só
  os avisos aceitos na P150 (`script-not-executable` ×26, `uses-dpkg-database-directly`, `no-manual-page`).
- `app-completo.py`: o `spicetify_instalar` (P151) entrou no `LUGAR_MODIFICACOES.cartao`, e o botão só existe no ⋮
  fechado do cartão do Spotify; o inventário esperava vê-lo na página. Não era tempo: vermelho determinístico,
  um achado. `8f6c2027` só espera a ação do cartão com o ⋮ aberto; verde três vezes seguidas de uma árvore fixa.
- `./tests/todos.sh` inteiro: 132 de 132 verdes, 0 pulado, 0 vermelho (`maquina-nova.sh` 5 s, `deb.sh` 199 s,
  `app-completo.py` 960 s).

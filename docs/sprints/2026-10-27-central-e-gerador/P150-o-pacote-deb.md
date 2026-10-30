# P150 — o pacote `.deb`

Anotada em 30/10 (o `ANDAMENTO.md` pedia um `.deb`; o Flatpak não serve, a sandbox não alcança o COSMIC). Ela vai
instalar o MeowSystem inteiro numa outra máquina com Pop!_OS 24.04 e COSMIC.

## O que se mediu (30/10, `dev` em a222dd18)
- A raiz: `bin/meow` resolve `MEOW_RAIZ`, depois a pasta de cima do próprio arquivo (com `readlink -f`), depois o
  ponteiro `~/.local/state/meowsystem/raiz`. O `install.sh` copia o `bin/meow` para `~/.local/bin/meow` e grava o
  ponteiro; o `app/servidor.py` e o `lib/comum.sh` acham a raiz do mesmo jeito. As unidades de `systemd/` leem o
  ponteiro (`R=$(cat %h/.local/state/meowsystem/raiz)`) ou chamam `%h/.local/bin/meow`. Nada supõe um clone em
  lugar fixo: `/usr/share/meowsystem` serve.
- Escrita na árvore: cópia do `git ls-files` em `chmod -R a-w`, HOME temporário, falsos no PATH (`sudo`, `apt`,
  `cargo`, `systemctl`, `flatpak`, `curl`...), `MEOW_SEM_REDE=1`, e `strace` de toda chamada que cria, abre para
  escrever, renomeia ou apaga. O `install.sh` de verdade (não o seco) e o `meow doctor --consertar`: a única
  tentativa na árvore é o `__pycache__` do Python, que ele mesmo dispensa. Builds (`.target`, compositor,
  menu do Files, oráculo), cache, `ativos/`, packs da pessoa e capturas já moram no HOME.
- Um caminho escrevia na árvore: o «Trazer imagens» do papel de parede (`/api/acervo`, tipo `parede`) gravava em
  `packs/meowsystem/wallpapers/ativos/` da raiz, pasta que o carrossel nem lê mais desde que as imagens foram
  para `~/.local/share/backgrounds/meowsystem`. Os verbos de quem mantém o repositório (`pack construir`, o
  rebaixar do upstream do btop/bat, o `readme.sh`) escrevem no repositório por definição e recusam numa raiz só
  leitura.
- Dependências: o `etapa_pacotes` instala com sudo o que falta (`librsvg2-bin`, `imagemagick`, `libgtk-3-bin`,
  `python3`, `git`, `btop`, `bat`, `curl`, `xz-utils`, `unzip`, `papirus-icon-theme`, `python3-numpy`, as
  bibliotecas dos applets de `MEOW_DEPS_DOS_APPLETS`); o pré-voo cita `fontconfig`, `libglib2.0-bin`, `procps`,
  `psmisc`, `desktop-file-utils`, `libnotify-bin`, `systemd`. O rust vem pelo rustup do próprio programa
  (`meow_garantir_rust`), não pelo apt. O compositor e o menu do Files compilam do `apt-get source` e pedem o
  `Build-Depends` do `cosmic-comp` e do `cosmic-files` (`just`, `cmake`, `libinput-dev`, `libseat-dev`,
  `libgbm-dev`, `libdisplay-info-dev`, `libclang-dev`...), que nada instalava.
- Conflito com um clone: não há pacote do outro lado, então não cabe `Conflicts`. O `/usr/bin/meow` acha a raiz
  pelo próprio caminho antes do ponteiro; o `~/.local/bin/meow`, que vem antes no PATH, segue o ponteiro, e o
  `install.sh` de onde se rodou por último o regrava.
- Atualizar com o programa em uso: o dpkg troca cada arquivo por renomeação, então o script que está rodando fica
  com o arquivo velho até sair. O vigia `meow-assets.path` olha o pack da raiz e reaplica o que a atualização
  mudou; o `~/.local/bin/meow` o doctor repõe na passada seguinte.

## Desenho
- `scripts/deb.sh [versão] [--saida <dir>]`: só `dpkg-deb` e `fakeroot`. Versão da última tag `vX.Y.Z` mais
  `+<commits>` se houver; o pacote sai em `dist/meowsystem_<versão>_all.deb` (`dist/` no `.gitignore`).
- O que vai: o `git ls-files` sem `tests/`, `docs/sprints/`, `docs/capturas/`, `.github/`, `packaging/`,
  `.gitignore`, `.gitattributes` e `LICENSE`, em `/usr/share/meowsystem`, dono root. Fica 755 o que o git marca
  executável e começa com `#!` ou é ELF; o resto, 644 (cinco imagens têm o bit no git sem ser programa).
  `/usr/bin/meow` é um link relativo para `../share/meowsystem/bin/meow`. O `LICENSE` vira
  `/usr/share/doc/meowsystem/copyright`; o `changelog.gz` nasce da versão e do commit.
- Sem `postinst`: o install é por pessoa, e quem usa roda `meow configurar` (ou `meow aplicar`) depois. O
  pacote não toca `/etc`.
- `packaging/deb/control`: `Depends` com o que o `install.sh` instalaria de qualquer jeito; `Recommends` com os
  compiladores e as bibliotecas dos applets, do compositor e do menu do Files, mais `fzf`, `flatpak`,
  `pipewire-bin`, `pop-fonts`; `Suggests: fastfetch` (o install o traz do PPA).
- A cura do envio do papel de parede: grava em `~/.local/share/backgrounds/meowsystem/ativos` (o
  `WALLPAPER_BASE`), que é de onde o carrossel lê.

## Prova
- `tests/deb.sh` (portátil): gera o pacote num diretório temporário; confere o controle e a lista (`dpkg-deb -I`,
  `-c`), o link do `/usr/bin/meow` e a ausência de `tests/` e `docs/sprints/`; extrai com `dpkg-deb -x`, deixa a
  árvore em `chmod -R a-w` e roda dela, com HOME temporário: o `meow aplicar --seco` e o `meow doctor`; o
  `install.sh` de verdade sob `strace` quando houver, falhando em qualquer escrita na árvore; e o painel servido
  da árvore só leitura, com o envio de um papel de parede caindo no `ativos` da pessoa.
- `lintian` sem erro; os avisos aceitos ficam aqui.
- `tests/readme.sh` verde depois de o README ganhar o caminho do pacote.

## Execução (30/10)
- `7731e789` fix(painel): o «Trazer imagens» do papel de parede grava em `_wallpaper_base()/ativos`, não mais na raiz.
- `6cd77e03` feat(deb): `scripts/deb.sh`, `packaging/deb/control` e `copyright`, `dist/` no `.gitignore`. O
  `Maintainer` e a assinatura do `changelog` vêm do `user.name` e do `user.email` do git de quem empacota: o
  gancho de higiene redige todo endereço escrito num arquivo.
- `b0c4bcba` test(deb): `tests/deb.sh`, no grupo portátil do `tests/todos.sh`. Gera, confere `-I` e `-c` (a lista
  do pacote é igual ao `git ls-files` menos o que fica fora), extrai, `chmod -R a-w`, e da árvore só leitura roda
  `meow --help`, `meow aplicar --seco`, `meow doctor`, o `install.sh` de verdade sob `strace` e o painel com um
  envio de papel de parede; no fim a árvore sai idêntica. Sem `strace` (o CI), essa parte diz pulado.
- `e95f81a0` docs(readme): «Pelo pacote `.deb`» / «From the `.deb` package» no «Instalar». O primeiro comando é o
  `meow configurar`, não o `meow` sozinho, que só abre o menu.
- `lintian` (2.117): zero erro. O `pkg-config` virou `pkgconf` (era o único erro). Avisos aceitos:
  `script-not-executable` ×26 (os `lib/*.sh`, `scripts/meow-lancador-apt.sh` e os `manifesto.sh` têm shebang e
  são lidos com `source`), `uses-dpkg-database-directly` (o `ponte_root.sh` lê o `/var/lib/dpkg` para saber o
  que o apt mexeu), `no-manual-page` (a ajuda é o `meow --help`). As cinco imagens com o bit de execução no git
  (`steam_tray_mono.png.original` e quatro `equalizer-animated-sapphire.gif`) saem 644: o `deb.sh` só dá 755 ao
  que começa com `#!` ou é ELF.
- Provas: `tests/deb.sh` verde (3 min, com `strace`); `readme.sh`, `nada-manda-digitar.sh`, `higiene.sh`,
  `arvore.sh`, `git-limpo.sh`, `orfaos.sh`, `wallpaper-base.sh`, `numeros.sh`, `portabilidade.sh`, `estilo.sh` e
  `decisoes.sh` verdes no ambiente da suíte. O pacote de verdade sai de um clone limpo do `HEAD`, para não levar
  o que outra sessão deixou sem commit.

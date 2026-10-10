# COSMIC vivo: o Meow sobrevivendo ao upgrade (09/10/2026)

Medido no nitro-5, só leitura. Nada no repositório nem no sistema foi
alterado. Os `.deb` e os fontes do COSMIC 1.10, que já está na fila do apt, foram
baixados e abertos no scratchpad da sessão (`apt-get download`,
`apt-get source --download-only`, `dpkg-deb -x`). Nenhum deles foi instalado.

O objetivo de quem usa: *"tem que sobreviver independente do upgrade do COSMIC:
eles atualizam e isso não quebra nada, e evolui com o sistema operacional. Ele
tem que ser vivo."*

A regra de interface que vale para todo aviso proposto aqui: *"Sem texto na
interface. Máximo vira dica. Mas tem que ser bem montado pra não gerar dúvida e
ficar intuitivo."*

---

## 0. A resposta curta

1. **O próximo `apt full-upgrade` já quebra duas coisas, e agora sabemos
   quais.** A série do compositor entra em 4 de 5 patches no `cosmic-comp`
   41497b4. O do modo de leitura falha um hunk com `-F0` e entra com `-F1`. O
   patch do menu de papel de parede **não entra** no `cosmic-files` 1.10, nem com
   fuzz 2: o auto-build vai falhar 3 vezes, como em 11/09 e 21/09.
2. **O resto do 1.10 não muda contrato.** Os esquemas `v*` de
   `/usr/share/cosmic` são os mesmos e os arquivos de padrão são byte a byte
   iguais. Toda chave que o Meow escreve existe nos binários novos, o
   `PinnedWorkspace` é o mesmo, a saída do `cosmic-randr list` é idêntica e as
   units do `cosmic-session` também. Isso é medição desta versão, não garantia
   da próxima. A sonda que fez essa medição é a peça que falta.
3. **A raiz da fragilidade do compositor é morar em `/usr/bin`.** Lá o apt
   sobrescreve, e a tela de login usa o mesmo arquivo; daí vêm a recusa de
   auto-build e o `patches/versao` manual. A sessão do usuário procura
   `cosmic-comp` pelo PATH, e o PATH dela começa em `~/.local/bin`. O
   compositor patchado pode morar ali, em escopo de usuário e sem sudo. O apt
   nunca toca nesse lugar e o greeter continua de fábrica. Essa é a cura na
   origem (§4.1).
4. **O momento certo de conferir é antes do apt instalar, não depois.** O
   repositório do Pop guarda **uma** versão por pacote. O fonte do
   `cosmic-comp` instalado hoje (0fbd457) já saiu do índice
   (`apt-get source cosmic-comp=…0fbd457` falha). Só existe enquanto o
   `~/.cache/meowsystem` o guardar. O fonte e o `.deb` do candidato estão
   disponíveis agora, antes do upgrade, e é aí que a sonda roda.
5. **A doutrina "nunca rode `apt upgrade`"** (`docs/COSMIC-THEMING.md:873`) é o
   oposto do objetivo. Ela só pode cair depois que existirem 4.1 a 4.3. Antes
   disso, cair a doutrina é perder os patches de novo.

---

## 1. Conferência do mapeamento (por amostragem)

| Afirmação do mapeador | Veredito | Medida |
|---|---|---|
| `COSMIC-THEMING.md:873` diz "nunca `apt upgrade`" | **Confirmada** | linha 873 exata |
| `patches/versao` recusa versão não validada; só 0fbd457 e a557859 | **Confirmada** | `patches/versao:38,46`; `_cp_recusar_versao` em `compositor_patches.sh:315` |
| 148 pacotes na fila, 27 `cosmic-*`, `cosmic-comp` vai para 41497b4 | **Confirmada** | `apt-get -s full-upgrade` |
| Os pendentes `pop-*` são 8 | **Confirmada** | pop-container-runtime, pop-pipewire, pop-container-interactive, pop-upgrade, pop-server, pop-desktop, pop-launcher, pop-de-cosmic |
| `apt-mark showhold` devolve eog, evince **e pop-default-settings** | **Derrubada em parte** | devolve só `eog` e `evince` |
| Não há `hold` nem `dpkg-divert` para `cosmic-comp` | **Confirmada** | `dpkg-divert --list` sem cosmic |
| `dpkg -V` acusa `/usr/bin/cosmic-comp` e `CosmicFiles.desktop` | **Confirmada** | `??5??????` nos dois |
| Histórico: 11/09 instalação, 21/09 cd881a4, 24/09 0fbd457 | **Confirmada** | `history.log.1.gz`; o `history.log` de outubro tem 0 byte |
| `.estado` com os 5 marcadores presentes | **Confirmada** | `/var/lib/meowsystem/cosmic-comp/patches.estado` |
| O fonte "some do repositório em poucos dias" | **Corrigida, e é pior** | o índice do Pop só tem a versão candidata. O fonte do 0fbd457 já sumiu hoje porque o 41497b4 foi publicado em 05/10. Só sobrevive o `.tar.xz` em `~/.cache/meowsystem/cosmic-comp/` |
| Os applets estão pinados no libcosmic `1f6dc99` | **Confirmada** | `src/applets/leitura/Cargo.toml:59`; `src/applets/now-playing/PINO` |
| A derivação de tema é cópia do `c003a58` e nada compara | **Confirmada, agora com a deriva medida** | ver §2.4 |
| O pré-voo tem furo: `*" v2 "*` aceita `v1 v2 v3` | **Confirmada** | `lib/preflight.sh:71`. Também aceita `v2 v3` |
| O `meow-painel-raio.path` vigia só `/v1` | **Confirmada** | `systemd/meow-painel-raio.path` |
| O doctor roda às 05:00 e não reage a apt | **Confirmada** | `OnCalendar=*-*-* 05:00:00`; nenhum hook chama o doctor |
| O doctor guarda 400 linhas | **Confirmada** | `ExecStartPre` corta para `tail -n 400` acima de 256 KiB |
| `com.system76.CosmicViewer` não está mapeado | **Confirmada** | nenhuma ocorrência em `packs/` nem em `assets/` |
| O `CosmicPlayer` "continua mapeado em `packs/*/icones/*.map`" | **Derrubada no lugar, de pé na substância** | 0 ocorrência em `packs/*/icones/*.map`. Está em `assets/icones/apps-{nomes,convertidos,arcticons}.map`, e há arte autoral em `packs/*/icones/autorais/cosmic-player-*.svg` |
| `appid_dock.sh` documenta o `cosmic-applets` 40248fb | **Confirmada como desatualizada** | o instalado é 82e7cd8 |
| A saída do `cosmic-randr list` pode mudar no 1.10 | **De pé como risco, sem efeito nesta versão** | §2.5 |
| O backoff do `cosmic-session` pode mudar no 1.10 | **De pé como risco, sem efeito nesta versão** | §2.6 |

---

## 2. Medições novas contra o COSMIC 1.10 da fila

### 2.1 Série do compositor no `cosmic-comp` 0.1~1791227611~24.04~41497b4

Aplicação em sequência numa cópia do fonte do candidato, com `-F0`:

| Patch | Resultado |
|---|---|
| `cosmic-comp-sem-workspace-vazio` (req) | limpo |
| `cosmic-comp-raio-clampado` | limpo |
| `cosmic-comp-menu-clique-curto` | limpo |
| `cosmic-comp-modo-leitura` | **falha 1 hunk**: `cosmic-comp-config/src/lib.rs` @104 |
| `cosmic-comp-blur-cache-textura` | limpo |

- **A causa:** o upstream acrescentou `cursor_hide`, `cursor_shake_to_find`,
  `activation_policy` e `decoration_preference` ao `CosmicCompConfig`, e mudou a
  terceira linha de contexto do hunk.
- **Com `-F1` o hunk entra** (offset 1). É rebase mecânico, não semântico.
- **O `PinnedWorkspace` é idêntico** (`output`, `tiling_enabled`, `id`,
  `name`), então o motor do `areas.sh` continua valendo nesta versão.
- **O toolchain está no limite:** o `Cargo.toml` do 41497b4 pede
  `rust-version = "1.93"`, e o `rustc` instalado é 1.93.1. O próximo degrau
  derruba todo build local (§3).

### 2.2 Patch do menu de papel de parede no `cosmic-files` 1.10.0 (ac5cef7)

- **`src/app.rs` entra:** os 4 hunks passam.
- **`src/menu.rs` falha, mesmo com fuzz 2.** O upstream reescreveu o menu do
  desktop: `menu_item(...)` deixou de levar `.into()` e cada chamada virou
  bloco de várias linhas.
- **É mudança de API, não só de contexto.** Um rebase automático por âncora
  acertaria o lugar, mas o código inserido tem de perder o `.into()` para
  compilar.
- **Consequência:** o `meow-files-menu-build` vai falhar 3 vezes depois do
  próximo apt e o menu fica de fábrica, o mesmo filme de 11/09 e de 21/09.

### 2.3 Esquema e chaves

- **Os `v*` de `/usr/share/cosmic`** nos `.deb` de 1.10 (applets, comp, panel,
  settings) são os mesmos de hoje: tema em `v1 v2` e o resto em `v1`.
- **Os arquivos de padrão** desses quatro pacotes são byte a byte iguais aos
  instalados.
- **A sonda `grep -a` de nome de chave** nos binários atual e novo:
  - `cosmic-panel`: `keep_style_on_maximize`, `opacity`, `anchor_gap`,
    `border_radius`, `expand_to_edges`, `margin`, `plugins_wings` e
    `plugins_center` estão presentes nos dois.
  - `cosmic-comp`: `autotile`, `autotile_behavior`, `pinned_workspaces` e
    `tiling_enabled` estão presentes nos dois. `leitura_temperatura` dá 1 no
    atual e **0 no novo**: é o binário de fábrica, e a sonda acusou exatamente
    o que devia.
  - `cosmic-settings`: `is_dark` e `auto_switch` estão presentes nos dois.
- **A migração de esquema existe e deixa pasta morta.** Dois applets de
  terceiros nesta máquina já subiram: `io.github.cosmic_utils.camera` tem `v20`
  e `v21`, e o `clipboard-manager` tem `v2` e `v3`. As pastas velhas ficaram no
  disco. É o modo de falha "o doctor verde sobre uma pasta morta", visto em
  campo.

### 2.4 Derivação do tema: a deriva existe no 1.10

- **A trilha até a revisão:** o `Filename` do apt traz o SHA completo do
  upstream (`pool/noble/cosmic-settings/58aeb652…/`). Com ele se lê o
  `Cargo.lock` no GitHub, e o `cosmic-settings` 1.10 pina o libcosmic
  **5a8bd94** (02/10/2026).
- **Contra o `c003a58`, que os `derivar_*.py` copiam:**
  - `steps.rs`: igual.
  - `cosmic_palette.rs`: igual.
  - `model/theme.rs`: difere em 30 linhas. A maioria é lint, mas **uma muda
    cor**. O `background` agora recebe um `background_pressed_overlay` derivado
    do `bg_index`. Antes recebia o `component_pressed_overlay` reatribuído pelo
    bloco do contêiner primário.
- **Para o Dracula escuro** os dois índices provavelmente caem do mesmo lado de
  91 e a cor sai igual. Isso é hipótese: só o oráculo prova.
- **Três revisões do libcosmic leem o mesmo tema ao mesmo tempo:**
  - `cosmic-comp` 41497b4: `d922ac3`, de 01/07, sem o campo
    `frosted_maximized_apps`;
  - `cosmic-settings` 1.10: `5a8bd94`;
  - applets do Meow: `1f6dc99`.
- **O contrato do tema é a interseção do que essas revisões leem.** Copiar uma
  delas não basta.

### 2.5 `cosmic-randr`

- **A saída é a mesma:** o `list` do binário 1.10 (rodado do scratchpad, só
  consulta), já sem cor, é idêntico ao do 0.1.0.
- **Os dois têm `list --kdl`**, um formato de máquina estável (`scale 1.00`, já
  em fração, sem `%` nem cor). O `escala.sh:113-120` faz awk na saída colorida
  para humanos.

### 2.6 `cosmic-session`

- **A unit é a mesma:** `cosmic-session.target` é idêntico no 1.10.
- **O supervisor é o mesmo:** os textos do supervisor (`ms before restarting
  process`, `Restarting after error:`, `launch_pad`) e a lista de filhos
  coincidem. Só o `COSMIC_VERSION` muda.

---

## 3. Acoplamentos que o mapeamento não viu

1. **Toolchain do Rust:** é a dependência comum a todo reparo por build
   (`cosmic-comp`, `cosmic-files`, os dois applets).
   - O `rust-version` dos fontes de 1.10 é `1.93`, e o `rustc` em
     `~/.cargo/bin` é 1.93.1.
   - Nenhum script compara os dois. O build só falha, e o `.tentado` conta a
     tentativa.
2. **A única volta para trás está no cache do apt.**
   - `/var/cache/apt/archives/cosmic-comp_0.1~1790118748~24.04~0fbd457_amd64.deb`
     é o único pacote de fábrica do 0fbd457 que existe, porque o repositório
     não o serve mais.
   - O `atualizar_sistema.sh limpar` roda `apt autoclean` e `apt clean`, o que
     o apaga.
   - O `.pacote` em `/var/lib/meowsystem/cosmic-comp/` guarda só o binário
     dessa versão, sem o resto do pacote.
3. **O fonte do compositor também depende de cache.** O `.tar.xz` do 0fbd457
   em `~/.cache/meowsystem/cosmic-comp/` é a única cópia, porque o repositório
   já não o serve. Qualquer limpeza de `~/.cache` encerra a capacidade de
   recompilar a versão instalada.
4. **O compositor é escolhido pelo PATH, e isso é uma alavanca, não um risco.**
   - O `cosmic-comp` vivo é filho do `cosmic-session` (PPID 4525). Ele foi
     lançado pelo nome nu: o `cmdline` é `cosmic-comp`.
   - O `PATH` do `cosmic-session` começa em `~/.local/bin` (a casa de quem usa).
   - O greeter roda por `greetd` com outro usuário. O
     `cosmic-greeter-start` faz `exec cosmic-comp cosmic-greeter` com o PATH
     do sistema, que não inclui o `~/.local/bin` dela.
   - O `cosmic-files` do Meow já usa esse caminho.
5. **Há cópias congeladas de `.desktop` do COSMIC em
   `~/.local/share/applications`:** `com.system76.CosmicMonitor`,
   `com.system76.CosmicScreenshot` e `pop-cosmic-{applications,launcher,workspaces}`.
   - São cópias inteiras, com um comentário "Escondido do menu"
     (`aplicar_overrides.sh`, do Migração-OS, não do Meow).
   - Elas sombreiam o arquivo do pacote. Um `Exec=` ou uma chave nova do 1.10
     não chega.
   - É vizinho, não Meow: fica anotado, sem escopo aqui.
6. **Três hooks de `DPkg::Post-Invoke` rodam a cada apt** (`99-relatorio-mec`,
   `99-aurora-postinvoke`, `99-meow-lancador`). Nenhum deles dispara o doctor
   nem os rebuilds. A peça de gatilho já existe no sistema, só não aponta para
   o lugar certo.

---

## 4. A arquitetura viva

São quatro princípios, e cada item abaixo é aplicação deles:

- **A. O apt é dono de `/usr`, o Meow é dono do escopo do usuário.** Nada do
  Meow fica num arquivo que o apt sobrescreve. O que hoje é patch em `/usr/bin`
  passa a ser build em `~/.local`, escolhido por um shim que confere a versão.
  O `dpkg -V` fica limpo.
- **B. Conferir o candidato antes, consertar depois, sem gente no meio.** Antes
  do apt instalar, uma sonda lê os `.deb` e o fonte do candidato e grava um
  veredito. Depois do apt, um gatilho reconstrói em escopo de usuário. Gente só
  entra quando a sonda diz vermelho.
- **C. O contrato é medido, não lembrado.** Um arquivo de contrato diz, para
  cada acoplamento, o que se espera da versão do COSMIC: esquema, chave, struct
  ou hash de fonte. A sonda compara o contrato com o binário instalado (ou o
  candidato) e atualiza a matriz de compatibilidade sozinha quando tudo bate.
- **D. Toda falha degrada para fábrica, nunca para quebrado.** Sem build da
  versão certa, roda o binário do pacote. Sem chave no binário, a função some
  da interface. Nunca fica uma chave gravada que ninguém lê.

**Como o aviso aparece, pela regra de quem usa:**

- O Meow não ganha frase nova na interface.
- O item do app que já representa a função (o cartão do modo de leitura, o do
  menu de papel de parede, o do doctor) muda de **estado visual**:
  - normal: vivo;
  - esmaecido, com o ícone de fábrica: degradado para o padrão do COSMIC;
  - um ponto de atenção: pede gente.
- O porquê e o verbo moram só na **dica** (`title`) desse item. Exemplos:
  "o COSMIC 1.10 mudou o menu; volta no próximo rebuild", "precisa de você:
  `meow compositor validar`".
- No terminal o `meow doctor` continua falando, porque terminal não é a
  interface.
- Degradar sozinho e voltar sozinho não acende o ponto de atenção. Só o
  vermelho acende.

### 4.1 Compositor em escopo de usuário (cura de 2A)

- **O que mede:** `dpkg-query -W cosmic-comp` contra a versão gravada em
  `~/.local/libexec/meow/cosmic-comp/<versão>/estado`. Também conta as quedas
  do compositor nos primeiros N segundos de sessão, num contador do shim.
- **A cura na origem:**
  1. O build vai para `~/.local/libexec/meow/cosmic-comp/<versão-dpkg>/cosmic-comp`,
     sem sudo e sem rename em `/usr/bin`. O `/usr/bin/cosmic-comp` volta a ser
     de fábrica e fica de fábrica; um `apt install --reinstall cosmic-comp`
     limpa o `??5`.
  2. Um shim `~/.local/bin/cosmic-comp` (sh, cerca de 20 linhas) faz
     `exec <build>` só quando três condições valem ao mesmo tempo: a versão do
     build é igual à do dpkg, o `estado` traz o `req` presente e o contador de
     quedas está abaixo do limite. Fora disso, faz `exec /usr/bin/cosmic-comp`.
  3. **Guarda de queda:** o shim anota o horário de início. Se a sessão
     anterior morreu em menos de 30 s duas vezes seguidas, o build daquela
     versão é marcado `ruim` e o shim vai para fábrica até um build novo.
     Ninguém fica preso fora da sessão.
  4. **A tela de login não é tocada.** O greeter não vê `~/.local/bin`. O
     argumento central da recusa de auto-build (`compositor_patches.sh:905-912`,
     "o binário também é a tela de login") deixa de valer.
  5. **O reflexo nos verificadores:**
     - `MEOW_PAINEL_COMP_BIN` e `chk_patches` passam a olhar o build da versão
       e o `/proc/PID/exe`, não `/usr/bin`.
     - O workspace alfinetado, o raio e o modo de leitura **também perdem o
       patch na tela de login.** O raio e o modo de leitura não importam ali; o
       workspace é da sessão.
- **Como se prova:**
  - `tests/compositor-shim.sh`, com um `dpkg-query` falso e um binário falso
    que só imprime o próprio caminho, cobre os quatro casos: versão igual,
    versão diferente, `ruim` e sem build. Em cada caso o shim escolhe o binário
    certo.
  - Na máquina: `readlink /proc/$(pgrep -x cosmic-comp)/exe` aponta para
    `~/.local/libexec/…` depois do login, e `dpkg -V cosmic-comp` fica vazio.
  - **Uma hipótese só se prova no login.** Que o `cosmic-session` resolve o nome
    pelo PATH está fortemente indicado (arg0 nu e PATH começando em
    `~/.local/bin`), mas a prova é o primeiro login com o shim. Essa conferência
    é feita com a mão.

### 4.2 Pré-voo do candidato: o veredito antes do apt (cura de 2A, 2B, 3, 4 e da falta de reação a apt)

- **O que mede.** Para cada `cosmic-*` que vai mudar:
  1. Esquema: os `v*` de `usr/share/cosmic/<ns>` dentro do `.deb` candidato,
     comparados com os de hoje.
  2. Chave: `grep -a -c` de cada chave do contrato (§4.4) no binário
     candidato.
  3. Série: o `cosmic-comp` e o `cosmic-files` candidatos baixados com
     `apt-get source --download-only`. A série é aplicada numa cópia em
     `~/.cache` com `-F0`; se falhar, com `-F1`; se falhar de novo, é falha.
  4. Toolchain: o `rust-version` do `Cargo.toml` candidato contra o
     `rustc --version`.
  5. Tema: a revisão do libcosmic do `cosmic-settings` candidato (o SHA do
     `Filename` dá o `Cargo.lock` do GitHub) e o hash de `steps.rs`,
     `model/theme.rs` e `cosmic_palette.rs` nessa revisão.
- **A cura na origem.**
  - O `atualizar_sistema.sh aplicar` roda o pré-voo **antes** do
    `full-upgrade` e grava `~/.local/state/meowsystem/cosmic-candidato.tsv`.
  - O upgrade **não é bloqueado**. O veredito só decide o que o pós-apt (§4.3)
    vai fazer.
  - O fonte do candidato baixado fica guardado: ele é o fonte da versão que
    vai estar instalada. Some a janela do 404.
  - O mesmo pré-voo vira verbo, `meow cosmic prever`, e roda no doctor quando
    `apt list --upgradable` mostra `cosmic-*`.
  - **Gatilho pelo apt de qualquer origem** (loja, terminal, topgrade): um
    `DPkg::Pre-Install-Pkgs` com `Version 3` recebe a lista exata de `.deb`
    que entram. A linha root só grava essa lista em
    `/var/lib/meowsystem/apt-entrando`. Todo o trabalho é do usuário (§4.3).
- **Como se prova.**
  - Rodado hoje à mão, o pré-voo reproduz o §2: modo de leitura `-F1`, menu do
    `cosmic-files` vermelho, esquema igual, chaves presentes, `theme.rs`
    diferente, toolchain no limite.
  - `tests/cosmic-prever.sh` usa `.deb` e fonte de brinquedo, um com o hunk
    quebrado e outro com `v3`. O veredito precisa sair diferente em cada caso.

### 4.3 Pós-apt: reparo idempotente em escopo de usuário

- **O que mede:** a versão de cada `cosmic-*` contra a última vista
  (`~/.local/state/meowsystem/cosmic-versoes`).
- **A cura na origem.**
  - O `99-meow-lancador` já roda como root a cada apt. Ele ganha uma linha que
    toca `/var/lib/meowsystem/apt-mudou`.
  - Uma `meow-pos-apt.path` de usuário vigia esse arquivo e dispara
    `meow-pos-apt.service`. Essa unit:
    1. roda `rustup update stable` se o pré-voo acusou toolchain baixo
       (`~/.cargo` é do usuário, sem sudo);
    2. reconstrói o que mudou de versão: compositor (§4.1), `cosmic-files`,
       applets (§4.6) e oráculo de tema (§4.5);
    3. roda `meow doctor --consertar`.
  - Cada passo é idempotente pelo mesmo critério do `files_menu`: artefato por
    versão, que só se reconstrói se faltar.
  - **Escada de série** para cada patch, em ordem:
    1. `-F0` limpo e os arquivos tocados pelo patch sem mudança upstream desde
       a última versão boa (`diff -q` entre os dois fontes guardados): entra
       sozinho.
    2. `-F0`/`-F1` limpo, mas algum arquivo tocado mudou upstream: entra
       sozinho, protegido pela guarda de queda de §4.1, e o item fica no estado
       "em observação" por uma sessão.
    3. Falha num `opt`: o build sai sem ele, e só a função dele degrada para
       fábrica.
    4. Falha no `req`: não há build, o shim usa fábrica, e o ponto de atenção
       acende.
  - O `patches/versao` deixa de ser porteiro e vira **matriz de
    compatibilidade gravada pela máquina**. Cada linha diz versão, degrau por
    patch e data. Commit de gente passa a ser só para o degrau 4.
- **Como se prova.**
  - `touch /var/lib/meowsystem/apt-mudou`, num ambiente de teste com versões
    falsas, gera exatamente um rebuild por versão nova e zero na segunda vez.
    É a idempotência.
  - A escada se prova com a série real contra o fonte 41497b4 já baixado. O
    resultado esperado: 4 patches no degrau 1 e o modo de leitura no 2.

### 4.4 Contrato de esquema e de chave (cura de §3 do mapeador e do `v1` fixo)

- **O que mede:** para cada linha de `contratos/cosmic.tsv`
  (`namespace  chave  binário-que-lê  quem-escreve`):
  - o maior `v*` em `/usr/share/cosmic/<ns>`, que é a verdade do pacote, e em
    `~/.config/cosmic/<ns>`;
  - a chave presente no binário (`grep -a -c`), como no §2.3.
- **A cura na origem.**
  - Um helper `meow_cosmic_v <ns>` devolve o maior `v*` do pacote, com `v1`
    como fallback. Os escritores (`janelas.sh`, `areas.sh`, `vidro.sh`,
    `forma.sh`, `relogio.sh`, `wallpaper.sh`, `terminal.sh`, `aplicar_tema.sh`)
    trocam o `v1` literal por ele.
  - Quando o pacote sobe de esquema, o Meow escreve no novo e não deixa pasta
    morta.
  - Chave ausente no binário: o escritor não grava, e o item correspondente
    degrada (princípio D).
  - O `lib/preflight.sh:71` passa a comparar contra a lista exata do contrato.
    Ele também sai da instalação e entra no doctor, porque roda pela mesma
    sonda.
  - O `meow-painel-raio.path` vigia o diretório do namespace, não `/v1`.
- **Como se prova.**
  - `tests/contrato-cosmic.sh` monta um `/usr/share/cosmic` falso com `v2` e
    verifica que todo escritor grava em `v2`.
  - Com um binário falso sem a chave, o doctor sai vermelho, e não verde sobre
    pasta morta.
  - Na máquina, hoje: todas as linhas verdes e `leitura_temperatura` presente.
    Contra o `.deb` 1.10: `leitura_temperatura` ausente, que é o esperado.

### 4.5 Tema: chamar o algoritmo em vez de copiá-lo (cura de §4 do mapeador)

- **O que mede:** a revisão do libcosmic do `cosmic-settings` instalado,
  lida pelo caminho do §2.4 ou do fonte guardado pelo pré-voo. Também mede o
  hash dos três arquivos da derivação nessa revisão.
- **A cura na origem.**
  - Um oráculo Rust mínimo (`src/oraculo-tema`) chama
    `ThemeBuilder::build()` e serializa o resultado. Ele é compilado pelo pós-apt
    contra **a mesma revisão** que o `cosmic-settings` instalado usa.
  - A derivação passa a ser a do COSMIC daquela versão, não uma cópia de
    agosto.
  - Os `derivar_*.py` ficam como fallback, para máquina sem cargo ou build que
    falhou. Eles também viram teste: rodam lado a lado com o oráculo, e
    divergência vira aviso.
  - O hash do `c003a58` vai para o contrato. Se o hash da revisão nova for
    igual, nada se compila.
  - As capturas (`packs/*/temas/capturados/`) continuam sendo a verdade do
    que ela escolheu. O oráculo só refaz o derivado (`CosmicTheme.Dark/v*`) a
    partir do `Builder` capturado.
- **Como se prova.**
  - Oráculo em `5a8bd94` contra Python em `c003a58`, sobre o `dracula-mauve`:
    o diff dos campos deve ficar vazio, ou mostrar só
    `background.component.pressed`. Isso também decide a hipótese do §2.4.
  - `tests/vidro-do-cosmic.sh` já cita o oráculo e ganha o caso.

### 4.6 Applets próprios: pino que acompanha o painel (cura de 2C e 2D)

- **O que mede:** a revisão do libcosmic do `cosmic-panel` instalado (mesmo
  caminho do §2.4) contra o pino `1f6dc99`. Também mede os coredumps do
  binário do applet desde o boot (`coredumpctl list <bin>`).
- **A cura na origem.**
  - O pós-apt tenta compilar o applet com o pino trocado pela revisão do painel
    numa árvore de trabalho em `~/.cache`.
  - Se compilar, o binário novo entra e o anterior fica guardado.
  - Se não compilar, fica o binário anterior. Ele só sai se o doctor vir
    coredump dele depois do apt; então o item degrada e a sombra do
    now-playing é retirada (o conserto da sombra órfã já existe no
    `chk_midia`).
  - `leiturabin` e `midiabin` saem de `SEM_CONSERTO`. O conserto agora é
    rebuild em escopo de usuário, e a razão de estarem lá (sudo, ou o timer das
    05:00 compilando) não se aplica mais, porque o gatilho é o apt.
- **Como se prova:** `tests/applet-pino.sh` com dois `Cargo.lock` falsos (o do
  painel e o do applet); o build é chamado só quando eles divergem. Com a mão,
  depois do 1.10: o applet aparece no painel e `coredumpctl` fica vazio.

### 4.7 Itens menores, um por linha

| Acoplamento | Mede | Cura | Prova |
|---|---|---|---|
| `escala.sh` faz awk na saída colorida | — | trocar por `cosmic-randr list --kdl` (`output "eDP-1" enabled=#true`, `scale 1.00`) | teste com KDL fixo; a saída de 0.1.0 e de 1.10 é idêntica hoje |
| Backoff do `cosmic-session` (`painel.sh:13-30`) | a regex do log (`ms before restarting process`) casa as linhas do journal da sessão | a sonda verifica que a regex casou ao menos uma vez no boot; se o formato mudar, a fórmula é marcada "não medida" e o `meow-painel` passa ao modo conservador | journal de teste com as duas formas |
| `.desktop` e ícones novos ou mortos (`CosmicViewer`, `CosmicPlayer`) | `dpkg -L cosmic-*` (`applications/*.desktop`) contra os `.map` | a sonda lista o que entrou ou saiu e o `completar_icones.sh` recebe a lista; nada é apagado sozinho | o `CosmicViewer` aparece como "sem arte" hoje |
| Os 126 nomes de ícone (`icones_sistema.sh`) | `strings` dos binários candidatos no pré-voo, conjunto contra conjunto | a lista é refeita na versão nova; nome novo sem arte cai no herdado do tema, não em buraco | o diff `-symbolic` entre 1.9 e 1.10 já aparece no pré-voo (ruidoso, só informativo) |
| `appid_dock.sh` amarrado ao `freedesktop-desktop-entry` 0.8.1 | revisão do `cosmic-applets` instalado | o comentário vira linha do contrato com a revisão medida | a sonda acusa 40248fb ≠ 82e7cd8 hoje |
| Volta para trás (`.deb` no cache do apt) | presença do `.deb` da versão instalada do `cosmic-comp` | o `limpar` preserva o `.deb` da versão instalada dos `cosmic-*` ou o copia para `/var/lib/meowsystem/` antes do clean | `limpar` em seco lista o que preserva |
| Fonte do compositor só no `~/.cache` | presença do `.tar.xz` da versão instalada | mudar para `~/.local/share/meowsystem/fontes/`; cache é para o que se recria, e este não se recria mais | o doctor acusa a falta do fonte da versão instalada |

---

## 5. Tarefas, ordenadas por risco

Cada tarefa vira um arquivo de sprint antes de ter agente.

1. **[crítico, iminente] Rebasear o patch do menu do `cosmic-files` para o
   1.10 antes do próximo apt.** O `menu.rs` perdeu o `.into()` e virou blocos.
   - Prova: `patch -F0` limpo no fonte ac5cef7 e build.
   - Sem isto, o próximo apt repete 11/09 e 21/09.
2. **[crítico] Compositor em escopo de usuário** (§4.1): shim e build em
   `~/.local/libexec`, guarda de queda e `/usr/bin` de volta à fábrica.
   - Prova: o teste do shim nos quatro casos, mais um login com a mão.
   - Ela destrava 3 e 4.
3. **[crítico] Pré-voo do candidato** (§4.2): `meow cosmic prever`, chamado pelo
   `atualizar_sistema.sh` antes do `full-upgrade`, com o fonte do candidato
   guardado.
   - Prova: reproduzir o §2 sozinho, mais o teste com `.deb` de brinquedo.
4. **[alto] Gatilho pós-apt e escada de série** (§4.3): uma linha no
   `99-meow-lancador`, `meow-pos-apt.path` e `.service` de usuário, e o
   `patches/versao` virando matriz gravada pela máquina.
   - Prova: idempotência por `touch`, e a escada contra o 41497b4 dando 4 no
     degrau 1 e o modo de leitura no 2.
5. **[alto] Toolchain e volta para trás:** `rust-version` contra `rustc` no
   pré-voo com `rustup update` no pós-apt; o `limpar` preserva o `.deb` da
   versão instalada; o fonte sai do `~/.cache`.
   - Prova: o pré-voo acusa 1.93.1 contra 1.93 como "no limite", e o `limpar`
     em seco preserva o 0fbd457.
6. **[médio] Contrato de esquema e chave** (§4.4): `contratos/cosmic.tsv`,
   `meow_cosmic_v`, escritores sem `v1` literal, `preflight.sh:71` exato e o
   `.path` do raio no namespace.
   - Prova: `/usr/share/cosmic` falso com `v2`.
7. **[médio] Oráculo do tema** (§4.5).
   - Prova: oráculo `5a8bd94` contra Python `c003a58` no `dracula-mauve`, que
     também decide a hipótese do `background.pressed`.
8. **[médio] Applets acompanham o painel** (§4.6), com `leiturabin` e
   `midiabin` fora de `SEM_CONSERTO`.
   - Prova: o teste com dois `Cargo.lock` e o `coredumpctl` vazio depois do
     1.10.
9. **[baixo] Itens menores** (§4.7): `--kdl` no `escala.sh`, a regex do backoff,
   o diff de `.desktop`, ícones e `CosmicViewer`, e o contrato do
   `appid_dock`.
10. **[decisão de gente, depois de 2 a 4 verdes] Reescrever a doutrina.**
    - `COSMIC-THEMING.md` §6 ("nunca `apt upgrade`") e o cabeçalho
      ("settings 1.0.12 / applets 1.0.15").
    - A frase nova: atualizar é o caminho normal, e o Meow se refaz sozinho.

**O que se confere com a mão** depois de 2 a 4 e do primeiro `full-upgrade` real:

- o primeiro login com o shim: `/proc/PID/exe` em `~/.local/libexec`;
- a tela de login abrindo normal;
- o modo de leitura mudando a tela;
- o menu de papel de parede no desktop;
- o cartão do app degradando e voltando sem frase na interface, só com a dica.

---

## 6. O que fica para gente decidir

1. **O GitHub como fonte da revisão do libcosmic** (§2.4) é rede externa a
   cada pré-voo. A alternativa é ler o `Cargo.lock` do fonte que o
   `apt-get source` já baixa: no `cosmic-settings` são 150 MB por versão.
   Proposta: GitHub primeiro, fonte do apt como fallback.
2. **A escada da série aceita sozinha o degrau 2** (contexto mudou e o hunk
   entra). Isso troca a "decisão de gente" de hoje por guarda de queda mais
   observação. Com o greeter fora do risco, a troca parece justa, mas é
   decisão dela.
3. **O workspace alfinetado deixa de valer na tela de login** (§4.1, item 5).
   Pelo que foi lido nos patches, nada da tela de login depende dele.

---

## 7. Como refazer as medições

```sh
S=<scratch>; mkdir -p $S/debs $S/x $S/src
cd $S/debs && apt-get download cosmic-comp cosmic-panel cosmic-settings cosmic-randr cosmic-applets cosmic-session cosmic-files
for f in *.deb; do n=${f%%_*}; mkdir -p ../x/$n; dpkg-deb -x $f ../x/$n; done
# esquema: find $S/x -path '*share/cosmic/*' -type d -name 'v*'
# chave:   grep -a -c leitura_temperatura /usr/bin/cosmic-comp $S/x/cosmic-comp/usr/bin/cosmic-comp
cd $S/src && apt-get source --download-only cosmic-comp && tar -xJf cosmic-comp_*.tar.xz --exclude='*/vendor/*'
cp -a archive seq && cd seq && for p in $(awk '$1~/^(req|opt)$/{print $2}' <repo>/patches/series); do
  patch -p1 -F0 --no-backup-if-mismatch < <repo>/patches/$p || echo "FALHOU $p"; done
# revisão do libcosmic do candidato:
apt-cache show cosmic-settings | grep ^Filename   # o SHA completo está no caminho do pool
curl -sfL https://raw.githubusercontent.com/pop-os/cosmic-settings/<sha>/Cargo.lock | grep -A2 'name = "libcosmic"'
# quem lança o compositor:
tr '\0' '\n' < /proc/$(pgrep -x cosmic-session)/environ | grep ^PATH=; ps -o ppid=,args= -p $(pgrep -x cosmic-comp)
```

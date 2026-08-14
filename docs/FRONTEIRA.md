# Fronteira MeowSystem × Ritual da Aurora

Duas máquinas de manutenção rodam neste computador e as duas escrevem sozinhas. O
**Ritual da Aurora** (`~/.config/zsh`, self-heal como root de hora em hora, no boot e
depois de todo `apt`) cuida do **sistema**: pacotes, energia, hardware, atalhos,
workspaces, wrappers em `/usr/local/bin`, patches de binário. O **MeowSystem** cuida da
**aparência**: tema, ícones, papel de parede, gato do dock, vidro do painel, nome e
visibilidade de aplicativo no lançador.

A regra é uma frase: **onde os dois querem mandar no mesmo arquivo, o visual é do
MeowSystem.** Não é gosto de arquitetura — é que o self-heal roda de hora em hora e
sempre vence no tempo: qualquer coisa que ele reponha desfaz o trabalho do outro para
sempre, e o sintoma aparece dias depois, sem culpado. Quando o Aurora precisa continuar
sendo o dono (porque só ele tem root, ou porque a chave é do sistema e não da tela), o
Meow **não escreve** — ele confere e diz.

A TRAVA 1 do `lib/comum.sh` é essa regra em código: o `meow_escrever` recusa
`/usr/share/*`, `/usr/local/share/*`, `~/.config/zsh` (repo dela, com auto-commit a cada
10 min) e os atalhos de teclado. O caminho de volta é o `vizinhos.conf`.

---

## A tabela

| alvo | quem escreve hoje | dono |
|---|---|---|
| `~/.config/cosmic/com.system76.CosmicTheme.*` | Meow + COSMIC (GUI) | **Meow** |
| alpha do `base:` de `background`/`primary`/`secondary` | Aurora (`aurora-vidro-maximizado.py`) | **Aurora** — já funciona, não mexer |
| `CosmicPanel.{Panel,Dock}/v1/keep_style_on_maximize`, `/opacity` | Meow (`vidro.sh`) | **Meow** |
| `CosmicPanel.*/v1/plugins_{wings,center}` | Aurora | **Aurora** — a ordem dos applets é dela |
| `CosmicTk/v1/icon_theme` e `~/.local/share/icons/MeowSystem-Icons` | Meow | **Meow** |
| `/usr/share/icons/hicolor/.../CosmicAppLibrary.svg` | ambos | **Meow** — o Aurora restaura o `.aurora-original` |
| `~/.config/cosmic/logos/` | ambos | **Meow** — o `gato-pop.svg` do Aurora foi aposentado |
| `~/.local/share/icons/hicolor/index.theme` | Meow (`hicolor.sh`) | **Meow** |
| `~/.local/share/applications/` — conteúdo do lançador | ambos | **Meow** |
| `/usr/local/share/applications/{google-chrome,steam}.desktop` (wrappers de `Exec=`) | Aurora | **Aurora** — mudou de `~/.local/share` em 13/08/2026, ver abaixo |
| `~/.local/share/applications/{vim,qt5ct,qt6ct,debian-*xterm}.desktop` | ambos | **Meow** — `NoDisplay` preserva o handler de MIME; o `Hidden=true` do Aurora mata |
| `/usr/share/applications/*` (`NoDisplay`, nome curto) | Meow (com sudo) | **Meow** — o Aurora não escreve ali |
| `/etc/apt/apt.conf.d/99-meow-lancador` | Meow | **Meow** — o segundo hook de apt da máquina, ver abaixo |
| `/usr/local/sbin/meow-lancador-apt.sh` | Meow | **Meow** — o `sbin` distingue do `/usr/local/bin` do Aurora |
| `/etc/apt/apt.conf.d/99-ritual-aurora-self-heal` | Aurora | **Aurora** |
| `~/.config/cosmic/com.system76.CosmicBackground` | Meow (`wallpaper.sh`) | **Meow** |
| `/var/lib/cosmic-greeter/.config/cosmic` | Meow (`greeter.sh`) | **Meow** |
| `~/.config/cosmic/com.system76.CosmicSettings.Shortcuts` | Aurora | **Aurora** — é o colar dela |
| `pinned_workspaces` | Aurora | **Aurora** |
| `~/.config/autostart/` | Aurora | **Aurora** |
| `gsettings` / `dconf` (`button-layout`) | Aurora | **Aurora** |
| `/usr/local/bin/*` (wrappers de execução) | Aurora | **Aurora** |
| `/usr/local/share/zsh/site-functions/_meow` | Aurora | **Aurora instala, Meow fornece** |
| binário `cosmic-comp` (patches de workspace e night light) | Aurora | **Aurora** |
| ciclo de vida do processo `cosmic-panel` | Aurora | **Aurora** — hoje desarmado (ver abaixo) |
| tema do qBittorrent, `~/.config/fastfetch` | Aurora | **Aurora** — o `meow` chama o script de lá |

---

## Dois hooks de apt na mesma máquina, e por que isso não é briga (14/08/2026)

A `/etc/apt/apt.conf.d` passou a ter dois `DPkg::Post-Invoke`: o
`99-ritual-aurora-self-heal`, que já existia, e o `99-meow-lancador`, novo. O apt roda
os dois em ordem alfabética, um de cada vez — o Meow primeiro. **Não há corrida**, e não
há sobreposição de alvo.

**Por que o segundo precisou existir.** O `ocultar_apps.sh` marca `NoDisplay=true` em
`.desktop` que vieram do apt, e um `apt upgrade` do pacote devolve o original. Está
medido: o `google-chrome-stable` atualizou em **10/08/2026 19:27**, devolveu o
`google-chrome.desktop` sem a chave, e ela achou dois Chrome no lançador em **14/08**.
Quatro dias com a duplicata de volta e nada na máquina para reaplicar.

**Por que não pelo `meow doctor`.** `ocultar` está em `SEM_CONSERTO` porque o conserto
usa sudo e o doctor nunca usa — um prompt de senha às 5h penduraria o
`meow-doctor.service` num terminal que ninguém está olhando. Essa decisão não mudou.
O que faltava era um gatilho que **já fosse root**, e o apt é exatamente isso: ele é ao
mesmo tempo a causa do estrago e um contexto privilegiado.

**Por que isso não contraria o "nenhum hook de apt" do `meow-doctor.service`.** Aquele
cabeçalho recusa pendurar um segundo **reparador completo** no evento do Aurora — dois
programas mexendo em tema e ícone ao mesmo tempo, com dois avisos que podem se
contradizer na tela dela. O `99-meow-lancador` não é reparador: chama um script, cobre um
diretório (`/usr/share/applications`, que esta tabela já dá ao Meow), não toca em tema,
não toca em ícone, não reinicia o `cosmic-panel` e não notifica nada. O cabeçalho da
unidade foi emendado para dizer isso em vez de ficar contradizendo o repositório.

**O `/usr/local/sbin` é escolha de fronteira, não de gosto.** O `/usr/local/bin` é do
Aurora nesta tabela ("wrappers de execução"). Um `sbin` separado deixa `ls` e `dpkg -S`
dizerem de quem é cada arquivo sem ninguém precisar abrir nada — e é o diretório certo
para um binário que só root executa.

---

## Wrapper de `Exec=` mora em `/usr/local/share/applications` (13/08/2026)

A linha do `google-chrome.desktop` mudou de dono de diretório, e o motivo interessa aos
dois lados porque é a **mesma** limitação do COSMIC que o `ocultar_apps.sh` já contornava
por outro caminho.

**O que quebrou.** O launcher acelerado do Chrome estava em
`~/.local/share/applications`, correto no disco — e mesmo assim o clique no dock subia o
Chrome SEM aceleração. Medido pelo processo vivo: `/proc/PID/environ` sem
`LIBVA_DRIVER_NAME`, `/proc/PID/cmdline` sem nenhuma das flags. O COSMIC estava lendo o
arquivo de `/usr/share`.

**As duas medições que se somam.** Nenhuma é nova sozinha; juntas elas fecham o caminho:

1. O COSMIC **não honra `$XDG_DATA_HOME`** — é o `pop-os/cosmic-applets#667` que este
   repo mediu em 04/08 para esconder app. Vale para o `Exec=` do mesmo jeito.
2. O `cosmic-app-library` **não deduplica por desktop-id** — mostra as duas cópias com
   "(Local)" e "(Sistema)". Então manter o arquivo no home *e* uma cópia em outro
   diretório dá duas entradas de Chrome no lançador.

**A saída.** `XDG_DATA_DIRS` é honrado, e nele `/usr/local/share` vem **antes** de
`/usr/share`:

```
~/.local/share/flatpak/... : /var/lib/flatpak/... : /usr/local/share : /usr/share
```

Um arquivo só, em `/usr/local/share/applications`: vence o do apt, sobrevive ao update do
Chrome e não encosta em `/usr/share` — que continua sendo do Meow. O Aurora recolhe a
cópia antiga do home, com guarda por `cmp` para não apagar edição dela.

**O que isso muda para o `ocultar_apps.sh`:** nada no mecanismo. Ele segue marcando
`NoDisplay=true` no arquivo de `/usr/share`, que segue sendo a única coisa que esconde
app. O que muda é a legenda de `OCULTAR_DUPLICATA`: a cópia boa não está mais "no home",
está em `/usr/local/share`.

---

## As três decisões que mudaram a tabela (10/08/2026)

**O ícone do botão "iniciar" voltou a ser do tema.** O Aurora plantava um gato Drácula em
`/usr/share/icons/hicolor/scalable/apps/com.system76.CosmicAppLibrary.svg` porque a v3.45
concluiu que "o `cosmic-panel-button` não enxerga `~/.local/share/icons`". A conclusão
estava errada: o laço EXTERNO da resolução é o **nome do tema**, e o `hicolor` é o último
elo da herança (§2 do `COSMIC-THEMING.md`, medido por `strace` em Xvfb). Com
`icon_theme = "MeowSystem-Icons"`, aquele arquivo nunca era consultado — era um arquivo de
dono `root`, fora da paleta, que o `meow doctor` não audita e que a TRAVA 1 impede o Meow
de consertar. O self-heal v3.56 restaura o `.aurora-original` em vez de plantar o dele.

**O `gato-pop.svg` era peso morto.** Reinstalado a cada ciclo em `~/.config/cosmic/logos/`,
num diretório em que a chave `custom_logo_path` já apontava para `meow-coquinha.svg` — e
para um applet (`dev.cappsy.CosmicExtAppletLogoMenu`) que não está montado em barra
nenhuma. Um terceiro arquivo, de um segundo dono, para uma chave que aponta para um só.

**O vigia do painel fantasma foi desarmado.** Ele matava o `cosmic-panel` quando via no
journal a mensagem de falha ao conectar no daemon de notificações — só que essa mensagem é
de **corrida de startup** (`cosmic-panel#366`, `cosmic-epoch#1237`) e o painel que o
próprio kill fazia nascer a reproduzia, no PID novo, onde o filtro por `_PID` não protege.
O journal de 04–05/08 mostra o ciclo fechado: 9 kills, oito deles em painéis com menos de
5 minutos de vida, e 33 notificações críticas em 3h21min. **O painel sumindo de 3 em 3
minutos era a cura, não a doença.** O `aurora-painel-fantasma.timer` está desligado (e o
self-heal e o `install.sh` do Aurora agora o mantêm assim); o script continua no disco,
com carência de 600 s e aviso uma vez por boot, e serve para diagnosticar sem matar nada:

```
AURORA_DRY_RUN=1 aurora-painel-fantasma.sh
```

Ligar de volta é decisão dela: `systemctl --user enable --now aurora-painel-fantasma.timer`.

---

## Como os dois se falam

O Aurora **confere** o visual uma vez por ciclo e nunca conserta: ele roda `meow doctor`
(que é read-only) e imprime **uma linha** de resumo. O `--consertar` fica de fora de
propósito — ele pede sudo em algumas etapas e decide sobre o gosto dela, o que não cabe a
um self-heal que roda de hora em hora. Uma divergência que ela mesma escolheu (trocar o
papel de parede pela GUI) não pode virar 24 parágrafos por dia no log.

Do lado do Meow, a fronteira está em `lib/comum.sh` (TRAVA 1) e no
`meow.conf` (`vizinhos.conf`). Do lado do Aurora, no `~/.config/zsh/as instrucoes do projeto` e nos
comentários `v3.56` do `ritual-aurora-self-heal.sh`.

Quem mudar um dos lados, muda os dois — este arquivo é o que sobra quando ninguém lembra
por quê.

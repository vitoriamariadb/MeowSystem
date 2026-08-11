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
| `~/.local/share/applications/{google-chrome,steam}.desktop` (wrappers de `Exec=`) | Aurora | **Aurora** |
| `~/.local/share/applications/{vim,qt5ct,qt6ct,debian-*xterm}.desktop` | ambos | **Meow** — `NoDisplay` preserva o handler de MIME; o `Hidden=true` do Aurora mata |
| `/usr/share/applications/*` (`NoDisplay`, nome curto) | Meow (com sudo) | **Meow** — o Aurora não escreve ali |
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

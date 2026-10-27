# Fronteira: quem escreve o quê

Duas máquinas de manutenção podem rodar no mesmo computador. O **MeowSystem** cuida da
**aparência**: tema, ícones, papel de parede, mascote, vidro, painel, lançador. Um vizinho como o
**Ritual da Aurora** (`~/.config/zsh`, self-heal como root) cuida do **sistema**: pacotes, energia,
atalhos, wrappers em `/usr/local/bin`. O MeowSystem não depende de vizinho nenhum; numa máquina sem
ele, as linhas «Aurora» da tabela não têm outro dono além do COSMIC.

## A regra

- **Onde os dois querem mandar no mesmo arquivo, o visual é do MeowSystem.** Onde um hook (git ou
  apt) ou o Andromeda disputam com o MeowSystem, vence o MeowSystem.
- **Vencer é poder escrever a linha, com as quatro guardas**: uma linha e nunca o arquivo inteiro,
  backup antes (backup que falha aborta a escrita), em voz alta na saída, e uma chave no
  `meow.conf` para desligar.
- **Primeiro mede se o outro dono disputa a linha.** Sem disputa, nada muda.
- **Em código:** a TRAVA 1 do `lib/comum.sh`. O `meow_escrever` recusa `/usr/share`,
  `/usr/local/share`, `/usr/bin` e `/usr/lib`, e os caminhos que `~/.config/meow/vizinhos.conf`
  declara de outro projeto. Uma linha `!caminho` é a exceção por arquivo: o `.zshrc` do ZDOTDIR
  recebe o bloco marcado do terminal (decisão 20), e o `scripts/terminal_bloco.sh` escreve essa
  linha.
- **O vizinho confere, não conserta.** O self-heal roda `meow doctor` (só lê) e imprime uma linha
  de resumo; o `--consertar` decide sobre gosto e não cabe num self-heal de hora em hora.

A outra fronteira, de dentro do repositório, mora em [`PACKS.md`](PACKS.md#a-fronteira-assets-contra-packs):
`assets/` é o que o MeowSystem é, `packs/` é o que ele veste, `~/.local/state/meowsystem/` é o que
a máquina gerou.

## A tabela

| alvo | dono |
|---|---|
| `~/.config/cosmic/com.system76.CosmicTheme.*`, incluindo `frosted_maximized_apps` | **Meow** |
| alpha do `base:` de `background`/`primary`/`secondary` (`vidro_janela.py`), só onde falta a chave nativa | **Meow** |
| `CosmicPanel.{Panel,Dock}/v1/keep_style_on_maximize` | **Meow** (a GUI não tem controle) |
| `CosmicPanel.{Panel,Dock}/v1/opacity` | **quem usa**, pela GUI |
| escala das saídas | **quem usa**; o `install.sh` aplica `ESCALA_TELA` só quando pedido |
| `CosmicPanel.*/v1/plugins_{wings,center}` | **quem usa**; o `extensoes_build.sh` só avisa quando falta a linha |
| ciclo de vida do `cosmic-panel` e o painel vivo que não desenha (`lib/painel.sh`) | **Meow** (`meow-painel.service`) |
| `CosmicTk/v1/icon_theme`, `~/.local/share/icons/MeowSystem-Icons`, `hicolor/index.theme` | **Meow** |
| `/usr/share/icons/hicolor/.../CosmicAppLibrary.svg`, `~/.config/cosmic/logos/` | **Meow** |
| `~/.local/share/applications/` (lançador, sombras dos applets da casa, uma por extensão) | **Meow**; `NoDisplay`, nunca `Hidden=true`, para não matar o handler de MIME |
| `/usr/share/applications/*` (`NoDisplay`, nome curto) | **Meow**, pela ponte root |
| `/usr/local/share/applications/{google-chrome,steam}.desktop` (wrappers de `Exec=`) | **Aurora** |
| `~/.local/bin/meowsystem-*`, `~/.local/state/meowsystem/extensoes/` | **Meow** |
| `~/.config/cosmic/io.github.meowsystem.NowPlaying/v1/*`, `~/.config/meowsystem/extensoes/*/tema.conf` | **Meow** |
| `album-color-enabled` do applet de mídia, `ultima_{temperatura,textura}` do applet de leitura | **quem usa** |
| `CosmicComp/v1/leitura_{temperatura,textura}` | **Meow** escreve o degrau da hora; **quem usa** escreve à mão pelo applet |
| `CosmicComp/v1/leitura_{agenda,hora_inicio,hora_fim}` | **quem usa**; o Meow lê e obedece |
| `pinned_workspaces` | **Meow** (`scripts/areas.sh`) |
| `~/.config/cosmic/com.system76.CosmicBackground` | **Meow** |
| `/var/lib/cosmic-greeter/.config/cosmic` | **Meow**, pela ponte root |
| `~/.config/cosmic/com.system76.CosmicSettings.Shortcuts`, `~/.config/autostart/`, `org.gnome.desktop.wm.preferences` | **Aurora** |
| `org.gnome.desktop.interface cursor-theme`, `~/.icons/default/index.theme` | **Meow** (`cursor.sh`); o `cosmic-comp` lê o segundo |
| `/usr/local/bin/*` | **Aurora** |
| `~/.local/share/zsh/site-functions/_meow` | **Meow**; a linha do `fpath` é do shell de quem usa |
| `~/.config/fastfetch/`, `~/.config/meowsystem/fzf.sh` | **Meow**; a linha que carrega o fzf é do shell de quem usa |
| tema do qBittorrent | **Aurora**; o `meow` chama o script de lá |
| `cosmic-comp` com a série de `patches/` | **Meow, por PATH**: build em `~/.local/libexec/meow/cosmic-comp/<versão>/`, o shim `~/.local/bin/cosmic-comp` escolhe a cada sessão; `/usr/bin/cosmic-comp` é do apt e a tela de login usa só ele |
| `patches/series` e `patches/*.patch` | **Meow** |
| `cosmic-files` e `cosmic-files-applet` | **Meow, por PATH**; o build sai da frente quando o pacote sobe sem build correspondente |
| `/etc/apt/apt.conf.d/99-meow-lancador`, `/usr/local/sbin/meow-lancador-apt.sh` | **Meow** (o `sbin` separa do `/usr/local/bin` da Aurora) |
| `/etc/apt/apt.conf.d/99-ritual-aurora-self-heal` | **Aurora** |
| `/usr/local/lib/meowsystem/{ponte_root.sh,perfil}`, `/etc/sudoers.d/49-meowsystem-ponte` | **Meow**; o `sudoers.d` é compartilhado, cada projeto escreve só o seu arquivo |

## A ponte root

| arquivo | modo | o que é |
|---|---|---|
| `/usr/local/lib/meowsystem/ponte_root.sh` | `0755 root:root` | um conjunto fechado de verbos, com os destinos dentro |
| `/usr/local/lib/meowsystem/perfil` | `0644 root:root` | `raiz`, `usuaria` e `lar`, escritos por root |
| `/etc/sudoers.d/49-meowsystem-ponte` | `0440 root:root` | libera só os verbos da ponte, sem senha |

- **Nenhum verbo aceita argumento.** Nome e conteúdo entram por stdin: um curinga no sudoers seria
  `NOPASSWD: ALL` com outro nome.
- **Os verbos:** `desktop` e `desktop-banco` (só `.desktop` que já existem), `greeter-ver` e
  `greeter-aplicar`, `apt-hook-instalar` e `apt-hook-remover`, `completion-instalar` e
  `completion-remover`, `flatpak-global-limpar` (só as chaves de tema que apontam para tema
  ausente), `libreoffice-remover` e `libreoffice-devolver`, `atualizar` e `limpar` (só os
  repositórios já configurados), `pacotes` (só a lista literal de dentro da ponte; o
  `tests/doctor-veredito.sh` cobra que ela seja a do `etapa_pacotes`) e `estado`, que só lê.
- **Cada uso vai para o journal:** `journalctl -t meowsystem-ponte`.
- **A ponte não se instala nem se atualiza.** Trocá-la pede a senha, no `install.sh`; por isso
  `ponte` fica sempre em `SEM_CONSERTO`. O `visudo -c` roda antes de o arquivo entrar.
- **Para tirar:** `PONTE_ROOT="nao"` no `meow.conf`. A passagem seguinte remove a ponte e a regra,
  e o sudo volta a ser pedido no terminal.

## O conserto

Uma etapa que sabe o conserto **faz**, ou oferece **um botão que faz**. Quando o que falta é
decisão humana, a mensagem diz **a decisão**, nunca a receita.

| saída | quando | exemplo |
|---|---|---|
| faz | o conserto é nosso e não tem escolha dentro | `fastfetch_logo.sh` apara a altura do mascote |
| botão | o conserto é nosso, a hora é de quem usa | `areas.sh alfinetar-primeira`, o tema do Spotify, o build do menu |
| a decisão | nenhum conserto deste projeto alcança | o binário do `spicetify`, o `qBittorrent.conf` |

Baixar de repositório público, pinado, é «faz». Em código: `meow_pendencia_acionavel <id>
"<frase>" "<comando>"` e `meow_pendencia_resolvida <id>`, no `lib/comum.sh`, escrevem
`$MEOW_ESTADO/pendencias.tsv`; o painel lê por `/api/pendencias` e desenha na porta Cuidar. O botão
só aparece quando a linha tem comando **e** o id está em `ACAO_DA_PENDENCIA`.

## O contrato das etapas

- **Estado declarado, com um dono só.** Nenhum hex em script: a cor vem da paleta, o destino vem de
  um mapa. Duas rotinas na mesma chave é defeito.
- **Backup antes de sobrescrever.** Falhar o backup aborta a escrita. A retenção é das 10 últimas
  passagens, e a poda é de quem vê a fila inteira (o runner, o `meow desfazer`).
- **Idempotência por conteúdo.** Idêntico ao que se ia escrever não se reescreve, e quem não
  escreveu diz que não escreveu.
- **Códigos de saída:** `0` certo, `1` divergente, `2` erro, `3` falta dependência. O 3 deixa o
  auto-reparo quieto quando o app não está instalado.
- **Falha por unidade.** Cada etapa retorna código e nenhuma chama `exit`; o `install.sh` não usa
  `set -e`.
- **Uma passagem por vez:** quem escreve pega `~/.local/state/meowsystem/lock`.

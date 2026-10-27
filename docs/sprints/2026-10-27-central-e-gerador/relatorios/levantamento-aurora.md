# Levantamento — o que a Aurora faz pelo desktop, e o que passa ao MeowSystem

Medido em 27/10/2026, na branch `dev` (`58b531be`), nesta máquina. Nenhum código mudou, nenhum timer
foi desligado e nada rodou com escrita no HOME real. As fontes lidas são estas:

- a Aurora em `~/.config/zsh`: `install.sh`, com 1996 linhas, e as 160 entradas de `scripts/`, em
  especial o `ritual-aurora-self-heal.sh`, com 2830 linhas;
- `/var/log/ritual-aurora-self-heal.log`, com 78 passadas;
- o journal das unidades de usuário;
- deste repositório: `assets/contratos/vizinhos.tsv`, `scripts/vizinhos.sh`, `docs/FRONTEIRA.md`,
  `bin/meow`, `lib/painel.sh`, `scripts/{areas,vidro,fastfetch_logo,sentinela}.sh` e
  `scripts/vidro_janela.py`.

O pedido dela, em 27/10: «vamos migrar pro meowsystem e desabilitar onde mais tiver, pensando em
transformar isso numa solução que possa ser usada em outros pcs».

Sprints que saem daqui: `P124-centralizar-a-aurora.md`, com o mecanismo e as duplicatas, e
`P125-o-desktop-da-aurora-vira-nosso.md`, com as migrações.

## 0. Três achados que mudam a ordem

### 0.1 Ninguém corta nada: o `vizinhos.tsv` nunca entrou em vigor

- **Ninguém chama o `--desativar` do `scripts/vizinhos.sh`.**
  - `install.sh`, os `fix_*` do `bin/meow` e o `app/servidor.py` não o chamam.
  - O doctor só chama `--conferir`, em `bin/meow` `chk_vizinhos`, que devolve 0 ou 4.
- **Não há registro de corte.** O `~/.local/state/meowsystem/vizinhos-desativados.tsv` não existe, e
  não há marca `#vizinhos` em nenhum arquivo da Aurora.
- **O `--listar` de hoje:**
  - quatro itens decididos e nunca aplicados aparecem como «ativo»: `caches-icones-casa`,
    `spellbook-terminal-fastfetch`, `spellbook-terminal-starship` e `spellbook-terminal-fzf`
    (decisão 20);
  - todo o resto dá «não existe nesta casa».
- **O que isso pega:** o item `aurora-compositor` da P121 também fica no papel se ninguém o disparar.
  A P124 dá o gatilho: o doctor corta, item por item, o que já tem o substituto instalado.

### 0.2 O doctor já mede sete duplicatas, e nenhuma tem saída

O `scripts/vizinhos.sh --conferir` de hoje devolve rc 4, com «7 duplicata(s) nova(s) com o
MeowSystem».

| território | quem escreve | destino |
|---|---|---|
| compositor | `/usr/local/bin/aurora-night-light.py` | P121 |
| compositor | `/usr/local/sbin/aurora-cosmic-comp-ws.sh` | P121 (ver 0.3) |
| fastfetch | `ritual-aurora-self-heal.sh` | **P124**, briga viva (seção 2) |
| lançador (.desktop) | `ritual-aurora-self-heal.sh` | **P124** (resíduo dos stubs); o `google-chrome.desktop` é da Aurora pela FRONTEIRA → `--revisado` |
| painel e dock | `aurora-qbittorrent-config.sh` | D3 |
| painel e dock | `aurora-reiniciar-painel.sh` | D4 → `--revisado` |
| painel e dock | `~/.local/bin/aurora-painel-fantasma.sh` | **P125** |

### 0.3 O corte da P121 deixa o compositor da Aurora no disco

- **O que a P121 corta:** só o bloco do `--ensure` (`if [ -x /usr/local/sbin/aurora-cosmic-comp-ws.sh ]`).
- **O que continua rodando a cada passada:** as linhas 1331–1411 do self-heal. Elas reinstalam
  `aurora-cosmic-comp-ws.sh` em `/usr/local/sbin`, o `.patch` em `/usr/local/share/aurora/`, o
  `aurora-glsl-gate.c`, os `-dev` e a sincronia e poda do `patches.d`.
- **O que continua no `install.sh` da Aurora:** as linhas 1915 (`_step_cosmic_comp_ws`) e 1916
  (`_step_night_light`).
- **Efeito:** a duplicata «compositor por `/usr/local/sbin/aurora-cosmic-comp-ws.sh`» não some com a
  P121.
- **Recomendação:** a P121 ganha mais itens de vizinho para esses trechos, ou a P125 os assume.
  Isso fica como pergunta ao coordenador (seção 5).

## 1. A tabela

Classes:
- **A:** é do MeowSystem; migra e desliga na Aurora.
- **B:** o MeowSystem já faz; só desliga na Aurora.
- **C:** é desta máquina; fica na Aurora.
- **D:** dúvida, com recomendação.
- **P121:** já decidido, fica fora da contagem.

### 1.1 Desktop e COSMIC

| # | item na Aurora | o que faz (lido no código) | no MeowSystem | classe |
|---|---|---|---|---|
| 1 | `aurora-cosmic-comp-ws.sh` + `--ensure` (self-heal 2737–2740) | regrava `/usr/bin/cosmic-comp` com o build sem workspace vazio | `scripts/compositor_patches.sh`, shim | P121 |
| 2 | `aurora-night-light.py` (self-heal 1327, 2752–2766) | injeta o shader da luz noturna no binário | modo de leitura (`cosmic-comp-modo-leitura.patch`, `meowsystem-leitura`) | P121 |
| 3 | instalação do compositor (self-heal 1331–1411; `install.sh` 1915–1916) | põe o script, o `.patch` e o `glsl-gate` em `/usr/local`, puxa `libegl-dev`/`libgles-dev`, poda `patches.d` | o mesmo do item 1 | D10 |
| 4 | `aurora-cosmic-nightlight-watch.{sh,service,timer}` (self-heal 2179–2183, 2319–2323) | todo dia: `curl` na API do GitHub (pop-os/cosmic-comp#2059); `notify-send` «Peça ao Claude…» quando fecha | nenhum vigia de issue; o `scripts/sentinela.sh` (12:00) vigia o COSMIC da fila | **A** |
| 5 | `aurora-cosmic-buttons-watch.*` (2174–2178, 2314–2318) | igual ao 4, para a cosmic-epoch#640 (ordem dos botões) | nada | D5 |
| 6 | `aurora-button-layout.{service,timer}` (5 min) + self-heal 2100–2168 | força `close,maximize,minimize:` por gsettings e dconf, `gtk-decoration-layout` nos `settings.ini` 3.0/4.0 (dela e de `/root`), `flatpak override QT_WAYLAND_DECORATION=adwaita` | nada; a FRONTEIRA dá `org.gnome.desktop.wm.preferences` à Aurora | D5 |
| 7 | `configurar-atalhos-cosmic.sh` + `aurora-cosmic-shortcuts.py` (806 linhas) + reerguer o `cosmic-settings-daemon` (2552–2599) | Ctrl+Alt+T, Print, Shift+Super+S (Gradia), Super+S desligado, Alt+F2 → `aurora-reiniciar-painel.sh`, colar no terminal; poda de `Spawn` órfão | FRONTEIRA: `CosmicSettings.Shortcuts` é da Aurora | C |
| 8 | `aurora-reiniciar-painel.sh` (314 linhas, Alt+F2) | SIGTERM manual no `cosmic-panel` | `scripts/painel.sh reciclar` («porta única») | D4 |
| 9 | `aurora-painel-fantasma.{sh,service,timer}` (3 min; 2297–2299, 2326–2349; `install.sh` 1918) | mata o `cosmic-panel` vivo que não desenha, por quatro sinais, com carência de 600 s | `lib/painel.sh` `meow_painel_fantasma` no laço do `meow-painel.service`: cobre os sinais 3 e 4 (render/protocolo), faltam o 1 e o 2 (notificações) | **A** |
| 10 | `aurora-portal-orfao.*` (10 min; 2301–2303, 2356–2374) | recolhe o `xdg-desktop-portal-cosmic` cujo barramento morreu | nada; a causa (teste com `dbus-run-session` herdando o `WAYLAND_DISPLAY` real) foi curada no Hefesto em 16/10 | D6 |
| 11 | `aurora-vidro-maximizado.{py,service,path}` (2207–2212, 2489–2499; `install.sh` 1917) | copia o alpha de `transparent_X` para `X.base` (cosmic-panel#457); o `.path` reage em ~1 s quando a Aparência regrava o tema | `scripts/vidro_janela.py`, o mesmo código portado, só pelo doctor (05:00); **nenhum `.path`** | **A** |
| 12 | link do fastfetch (self-heal 1715–1718; `install.sh` 1431) | `ln -sfn ~/.config/zsh/fastfetch ~/.config/fastfetch` | FRONTEIRA: `~/.config/fastfetch/` é do Meow; `scripts/fastfetch_logo.sh` `_ffl_assumir_diretorio` | **B** |
| 13 | completion `_meow` (self-heal 1485–1493) | copia `$MEOW_RAIZ/zsh/_meow` para `/usr/local/share/zsh/site-functions` | `install.sh` `COMPLETIONS_SISTEMA` + ponte `completion-instalar`; a origem mudou para `assets/zsh/_meow`, então o bloco da Aurora já é inerte | **B** |
| 14 | `APPLIB_ICONE` (self-heal 1178–1181) | devolve `CosmicAppLibrary.svg.aurora-original` por cima do ícone | FRONTEIRA: esse SVG é do Meow; hoje inerte (não há `.aurora-original`) | **B** |
| 15 | stubs `Hidden=true` (2038–2043) | apaga `vim`/`xterm`/`uxterm`/`qt5ct`/`qt6ct.desktop` com `Hidden=true` | `scripts/ocultar_apps.sh` (`NoDisplay`); é a duplicata «lançador» do 0.2 | **B** |
| 16 | `gato-pop.svg` (2292–2296) | apaga um logo antigo em `~/.config/cosmic/logos/` | FRONTEIRA: `logos/` é do Meow | **B** |
| 17 | `spicetify-setup.sh` (via `functions/spicetify.zsh` `spicetify_instalar`, à mão) | instala o Spicetify com `ESQUEMA="Dracula"` (`config current_theme`/`color_scheme`) | `scripts/spicetify_setup.sh` `cmd_instalar` e o tema do pack | **B** |
| 18 | os quatro itens já no `vizinhos.tsv` (`caches-icones-casa`, `spellbook-terminal-{fastfetch,starship,fzf}`) | cache dos ícones em `functions/sistema.zsh`; fastfetch, starship e fzf no `env.zsh` | `scripts/hicolor.sh`, `scripts/terminal_bloco.sh` (decisão 20) | **B** (falta só o gatilho) |
| 19 | `aurora-cosmic-workspaces.py` (419 linhas; self-heal 2283–2286 a cada passada; `install.sh` 1922) | confere e refaz os alfinetes `Meow` e `OS` (o `III` saiu pela mão dela em 25/08), com merge | `scripts/areas.sh` (`conferir`/`aplicar`, `AREAS_NOMES="Meow, OS"`), **só pela CLI**, nunca pelo doctor; FRONTEIRA: `pinned_workspaces` é do Meow | D1 |
| 20 | `aurora-claude-workspace.sh` (440 linhas) + conf | estaciona as janelas de teste do assistente no workspace `OS` | nada | C |
| 21 | `claude-screenshot.sh` (55 linhas) | captura a tela para o assistente ler | nada | C |
| 22 | `aurora-clipboard.sh` (`persist`/`trim`/`doctor`), `wl-clip-persist` vendorizado, `ritual-aurora-clipboard-trim.timer` (1 h) | mantém o clipboard vivo depois que o dono fecha; poda o banco do `cosmic-ext-applet-clipboard-manager` (1000 linhas e uma cota de imagem) | o fork `meowsystem-clipboard` (P122) ainda não existe | D2 |
| 23 | `aurora-print-clipboard.sh`, `aurora-gradia-clipboard.sh`, `aurora-gradia-config.sh`, `gradia-screenshot-full.sh` (obsoleto) | o fluxo de print dela com o Gradia | nada | C |
| 24 | `MIME_PARES` + `cosmic-mimeapps.list` + poda de handler fantasma (1903–2017) | fixa image/* → eog, mailto → thunderbird, etc. | nada (o Meow não escolhe handler) | D9 |
| 25 | cauda do `aurora-qbittorrent-config.sh` | insere o `CosmicAppletStatusArea` no `plugins_wings` do painel | FRONTEIRA: `plugins_{wings,center}` são de quem usa; a página Extensões da P120 põe e troca | D3 |
| 26 | tema, conf e plugins do qBittorrent (resto do script) | tema `.qbtheme`, overrides do flatpak, WebUI | FRONTEIRA: tema do qBittorrent é da Aurora; o `meow` chama o script de lá | C |
| 27 | `aurora-limpeza-home.*` (semanal) | faxina da home por lista permitida | nada | C |
| 28 | `aurora-bleachbit-cerca.sh` | `flatpak --nofilesystem=xdg-data/applications` no BleachBit + o ini | nada | D7 |
| 29 | fontes: `_step_fonts`, paridade de formatos, `functions/fontes.zsh` | `ttf-mscorefonts`, `liberation2`, `carlito`, `caladea`, `noto-core`; `windows-compat`/`macos-compat` em `~/.local/share/fonts` + `fc-cache` (à mão) | `assets/fontes/` (as fontes do pack) | D8 |
| 30 | `functions/restaurar.zsh` (à mão) | guarda e repõe gtk-theme, ícones, cursor e papel de parede de um manifesto | `cursor.sh`, `wallpaper.sh` | C (ferramenta de backup dela, rara) |

### 1.2 Sistema e pessoal (fica na Aurora)

| # | item | por que fica |
|---|---|---|
| 31 | Nitro (`nitro-profiled`, `nitro-status`, `nvidia-settings-autostart.desktop`, `kernelstub nvidia-drm.modeset=1`) | hardware dela |
| 32 | Redragon e entrada (`60-input-remapper.rules`, `85-redragon-reinjetar.rules`, `aurora-redragon-*`, `redragon-m711-rgb.py`, `aurora-input-tecla-presa.py`, `aurora-scheduler-input.kdl`, `aurora_autoclick`, `evtest`, grupo `input`, `71-uinput.rules`) | hardware dela |
| 33 | qBittorrent e arr (`aurora-qbittorrent-{trackers,legendas}`, `aurora-torrent-vigilia`, `aurora-arr-stack.sh`, `aurora-jackett-indexadores.sh`, `aurora-cinemateca.py`, pacotes `qbt`/`libssl-dev`) | conta e acervo dela |
| 34 | rede (`openssh`/`sshfs`, `aurora-conectar-{andre,maria}`, `aurora-lan-mount-watchdog`, `/mnt/Apate` compat) | LAN dela |
| 35 | Syncthing; `andromeda-autosync` (10 min) | contas e repositório dela |
| 36 | VS Code, SEGAPE, `configurar-vscode`, git hooks, travas do Claude, cofre de segredos, askpass/sudoers, grok, `zsh-ambiente`, oh-my-zsh, `clonar_repos`, `chsh` | trabalho, contas e segredos |
| 37 | `aurora-kernel-guarda`, `topgrade`, `rustup` (aviso), `journald`, `earlyoom`, `99-meow.conf` (sysctl: `swappiness 180`, `page-cluster 0`), `50-system76-power.rules` (polkit), `chown` da home | sistema (FRONTEIRA: a Aurora cuida do sistema) |
| 38 | Chrome (política `aurora-chrome-no-ai.json`, `aurora-chrome-deflate.sh`, `/usr/local/share/applications/google-chrome.desktop`) | FRONTEIRA: o wrapper é da Aurora |
| 39 | `99-ritual-aurora-self-heal` (gancho do apt), `validar-acentuacao`, pacotes de `qol` e de sistema de arquivos | sistema |
| 40 | `hefesto-dualsense4unix-tray.desktop` (autostart) | FRONTEIRA: `~/.config/autostart/` é da Aurora; é do Hefesto |
| 41 | Sem referência, peso morto: `aurora-boot-gravador.c` (diagnóstico temporário de 21/10), `pop-system-updater-config.ron`, `compat.py`, `hidden-*.desktop` | fica para a própria Aurora limpar; não é desktop |

### 1.3 A contagem

| classe | itens | linhas |
|---|---|---|
| A | 3 | 4, 9, 11 |
| B | 7 | 12, 13, 14, 15, 16, 17, 18 |
| C | 18 | 7, 20, 21, 23, 26, 27, 30, 31–41 (com 31 a 41 agrupados por área) |
| D | 11 | 3 (D10), 5 e 6 (D5), 8 (D4), 10 (D6), 19 (D1), 22 (D2), 24 (D9), 25 (D3), 28 (D7), 29 (D8), e mais o D11 estrutural (seção 4) |
| P121 | 2 | 1, 2 |

## 2. Medido: a briga viva do fastfetch

- **O que o doctor do MeowSystem fez:** hoje às 10:28, `_ffl_assumir_diretorio` trocou o link
  `~/.config/fastfetch` por um diretório de verdade, com backup e aviso.
- **O que a Aurora faz a cada passada:**
  - a guarda dela (`readlink` diferente de `~/.config/zsh/fastfetch`) dá falso;
  - ela grava «criando symlink ~/.config/fastfetch (v3.34)», 37 vezes no log;
  - o `ln -sfn` cai **dentro** do diretório: existe hoje o lixo
    `~/.config/fastfetch/fastfetch -> ~/.config/zsh/fastfetch`.
- **Cura:**
  - os dois trechos da Aurora saem: o self-heal, linhas 1715–1718, e o `install.sh`, linha 1431;
  - o `fastfetch_logo.sh` apaga o link aninhado quando ele aponta para o ZDOTDIR.

## 3. O caminho de cada item A e B

`$UNI` é `~/.config/systemd/user`, uma expansão nova (P124). «linha» é um `bloco` com `fim` igual a
`-`, que corta só a linha de início (P124).

| item | onde mora no MeowSystem | item do vizinho (tipo · arquivo · início → fim · requer) | depende de |
|---|---|---|---|
| 12 fastfetch | `scripts/fastfetch_logo.sh` (já existe) + poda do link aninhado | `aurora-fastfetch-link` · bloco · `$ZD/scripts/ritual-aurora-self-heal.sh` · `if [ "$(readlink "$USER_HOME/.config/fastfetch" 2>/dev/null)"` → `^fi$` · `scripts/fastfetch_logo.sh:_ffl_assumir_diretorio`; `aurora-fastfetch-passo` · linha · `$ZD/install.sh` · `_run ln -sfn "$ZDOTDIR_TARGET/fastfetch" "$HOME/.config/fastfetch"` · o mesmo | P124 (gatilho e linha) |
| 13 `_meow` | `install.sh` `COMPLETIONS_SISTEMA`, a ponte | `aurora-completion-meow` · bloco · self-heal · `MEOW_RAIZ_PTR="$USER_HOME/.local/state/meowsystem/raiz"` → `^unset MEOW_RAIZ_PTR MEOW_RAIZ$` · `install.sh:COMPLETIONS_SISTEMA` | P124 |
| 14 ícone AppLibrary | o ícone vem do tema (`CosmicTk/v1/icon_theme`) | `aurora-icone-applib` · bloco · self-heal · `APPLIB_ICONE=/usr/share/icons/hicolor/scalable/apps/com.system76.CosmicAppLibrary.svg` → `^fi$` · `-` | P124 |
| 15 stubs | `scripts/ocultar_apps.sh` | `aurora-stubs-ocultar` · bloco · self-heal · `for _id in vim debian-xterm debian-uxterm qt5ct qt6ct; do` → `^unset _id _f$` · `scripts/ocultar_apps.sh:NoDisplay` | P124 |
| 16 gato-pop | `assets/gatos/` → `logos/` | `aurora-gato-pop` · bloco · self-heal · `GATO_POP="$USER_HOME/.config/cosmic/logos/gato-pop.svg"` → `^  unset GATO_POP$` · `-` | P124 |
| 17 spicetify | `scripts/spicetify_setup.sh` | `aurora-spicetify-instalar` · saida · `$ZD/scripts/spicetify-setup.sh` · `-` · `scripts/spicetify_setup.sh:cmd_instalar` (o `spicetify_reparar` dela segue, como no item `dracula-spicetify`) | P124 |
| 18 quatro itens antigos | `hicolor.sh`, `terminal_bloco.sh` | já estão no `vizinhos.tsv`; entram em vigor com o gatilho | P124 + prova manual do terminal |
| 9 painel fantasma | `lib/painel.sh` ganha os sinais 1 e 2 (notificações); o laço do `meow-painel.service` com a carência de 600 s que já tem | `aurora-painel-fantasma-instalar` · bloco · self-heal · `install_user_if_diff "$SRC/aurora-painel-fantasma.sh"` → `aurora-painel-fantasma[.]timer`; `aurora-painel-fantasma-ligar` · bloco · self-heal · `O VIGIA DO PAINEL VOLTA ARMADO` → `enable --now aurora-painel-fantasma[.]timer`; `aurora-painel-fantasma-passo` · linha · `$ZD/install.sh` · `        _step_painel_fantasma`; `aurora-painel-fantasma-unidade` · unidade · `$UNI/aurora-painel-fantasma.timer`; requer de todos: a função nova do `lib/painel.sh` | P124 (unidade) |
| 11 vidro maximizado | `systemd/meow-vidro.path` + `meow-vidro.service` novos (os mesmos seis `PathChanged` de `CosmicTheme.{Dark,Light}/v2/{background,transparent_background,frosted_windows}`) → `scripts/vidro.sh` | `aurora-vidro-instalar` · bloco · `# v3.41: vidro fosco também na janela maximizada.` → `aurora-vidro-maximizado[.]path`; `aurora-vidro-reconciliar` · bloco · `# v3.41: vigia do tema (reaplica o vidro fosco` → `aurora-vidro-maximizado[.]py falhou`; `aurora-vidro-passo` · linha · `$ZD/install.sh` · `        _step_vidro_fosco`; `aurora-vidro-unidade` · unidade · `$UNI/aurora-vidro-maximizado.path`; requer `systemd/meow-vidro.path:PathChanged` | P124 |
| 4 vigia da #2059 | `scripts/sentinela.sh` (já diário, 12:00) lê `assets/contratos/vigias.tsv`; issue fechada → `meow_pendencia_acionavel` com **a decisão**, sem comando | `aurora-leitura-vigia-instalar` · bloco · `# v3.30: vigia diário da issue cosmic-comp#2059` → `aurora-cosmic-nightlight-watch[.]timer`; `aurora-leitura-vigia-unidade` · unidade · `$UNI/aurora-cosmic-nightlight-watch.timer`; requer `scripts/sentinela.sh:vigias.tsv` | P124, P121 (luz noturna da Aurora fora) |

Todas as âncoras de início medidas acima aparecem **uma vez só** nos arquivos de hoje. A frase
`O VIGIA DO PAINEL VOLTA ARMADO` está no corpo do script, não no histórico das linhas 2–523.

**As linhas de `enable --now` de 4, 5 e 9 não têm âncora única.** Cada uma é a última linha de um
`runuser … env \` que se repete. O tipo `unidade` resolve isso de outro jeito:
- tira o `.timer` e o `.service` do `~/.config/systemd/user`;
- o `enable --now` da Aurora passa a falhar calado, porque ela já usa `|| true`.

Comentar só a linha final de um comando continuado faria o `env` rodar sem comando.

## 4. O mecanismo (D11, estrutural)

1. **Quem corta.** Um `fix_vizinhos` no doctor:
   - corta os itens prontos: ativos, com `requer` satisfeito e nunca restaurados por quem usa;
   - obedece à chave `VIZINHOS_DESATIVAR="sim"` do `meow.conf`, que é a quarta guarda da FRONTEIRA;
   - item que ela restaurou não volta a ser cortado: o registro diz «restaurado».
2. **Corte de uma linha.** O `bloco` de hoje não sabe cortar uma linha só. O fim exige uma linha
   que não tenha o início, então `_step_x` comentaria até a próxima casada. Com `fim` igual a `-`,
   ele corta só a linha de início.
3. **Âncora única.** Um início que aparece mais de uma vez recusa o corte, sem mudar nada. Hoje
   todos são únicos, mas o histórico de 520 linhas do self-heal cita trechos do próprio código e
   cresce a cada versão.
4. **Arquivo que ainda funciona.** Depois do corte, o arquivo passa por `bash -n` (`.sh`) ou
   `zsh -n` (`.zsh`). Se reprovar, a cópia volta e o item dá erro.
5. **O tipo `unidade`:**
   - `systemctl --user disable --now`, e o `.timer`/`.path` mais o `.service` de mesmo nome vão para
     a cópia datada;
   - o `--restaurar` devolve e religa;
   - **espera a Aurora ler o corte.** O self-heal que está rodando é a cópia de
     `/usr/local/sbin`, que ainda instala a unidade a partir de `$SRC` e só se reinstala no fim da
     passada (linha 2656). Desligar antes faz a unidade voltar uma vez. A `unidade` só age quando a
     marca do item de `bloco` do qual ela depende já está no arquivo instalado (coluna `fim`); até
     lá diz «esperando a Aurora ler o corte», sem divergir. O self-heal roda de hora em hora
     (`OnUnitActiveSec=1h`), então converge na passada seguinte.
6. **A árvore da Aurora.** O `vizinhos.conf` protege `~/.config/zsh` contra o `meow_escrever`, e o
   `vizinhos.sh` escreve lá com `mv` próprio. Isso é a exceção autorizada: só linhas marcadas, com
   cópia. O `andromeda-autosync` comita o corte no repositório `Meow-Portatil` em até 10 min. Isso é
   o efeito desejado: o corte sobrevive a um clone novo. A FRONTEIRA passa a dizer isso numa linha.
7. **Em outro PC.** Sem Aurora, cada item diz «não existe nesta casa» e o doctor não faz nada. A
   solução que serve a outros PCs é o que entra no MeowSystem: o `meow-vidro.path`, os sinais do
   painel, o vigia e os alfinetes pelo doctor. O `vizinhos.tsv` é só o desligamento nesta família de
   máquinas.

## 5. As dúvidas (D), com recomendação

| D | item | recomendação |
|---|---|---|
| D1 | `aurora-cosmic-workspaces.py` | **A.** `chk_areas`/`fix_areas` no doctor (`areas.sh conferir`/`aplicar`, só refaz alfinete caído, como em 04/08), e corte do bloco 2280–2286 e da linha 1922 do `install.sh` (`aurora-alfinetes`, `aurora-alfinetes-passo`). Duas rotinas na mesma chave é defeito pela FRONTEIRA, e hoje as duas concordam só por sorte. Precisa do sim do coordenador: o `~/.claude/CLAUDE.md` dela cita o script como o conserto e ainda fala em três workspaces (o `III` saiu em 25/08); aquele texto é dela, e o agente não o edita. |
| D2 | cadeia do clipboard | **A, depois da P122**: a poda e o `persist` entram no fork `meowsystem-clipboard`. Fora da P124/P125 (anotado). |
| D3 | `CosmicAppletStatusArea` no `plugins_wings` pelo script do qBittorrent | **Cortar** (bloco `WINGS="$CFG/com.system76.CosmicPanel.Panel/v1/plugins_wings"` → `^fi$`, requer o `por` da P120). A lista do painel é de quem usa, e hoje a guarda nem dispara (âncora `Drives` ausente, `StatusArea` em nenhuma barra). Pode ir na P125 se o coordenador aceitar. |
| D4 | `aurora-reiniciar-painel.sh` (Alt+F2) | **C por agora**, com `--revisado`: é gesto à mão, o atalho é da Aurora, e o `Spawn` do COSMIC não aceita argumentos. Anotado: um `~/.local/bin/meowsystem-reciclar-painel` sem argumentos como porta única, para o atalho apontar. |
| D5 | ordem dos botões (`aurora-button-layout`, `settings.ini`, override do Qt) e o vigia da #640 | **C.** É gosto dela, e a FRONTEIRA dá `org.gnome.desktop.wm.preferences` à Aurora. O vigia da #640 só faz sentido junto. |
| D6 | `aurora-portal-orfao` | **C.** Defeito de ferramenta de teste, com a origem curada; não é desktop genérico. |
| D7 | `aurora-bleachbit-cerca` | **C.** Programa dela; protege lançadores, mas não escreve neles. |
| D8 | pacotes de fontes e paridade de formato, `fontes.zsh` | **C.** São pacotes de sistema e escolha de compatibilidade dela, não a fonte do pack. |
| D9 | `MIME_PARES` e poda de handler fantasma | **C**, com defeito da Aurora anotado: `eog` e `thunderbird` não estão instalados, então o `xdg-mime` reescreve a cada passada (46 vezes `image/webp`, 49 vezes `mailto` no log). |
| D10 | instalação do compositor nas linhas 1331–1411 e `install.sh` 1915–1916 | **P121** estende os itens de vizinho (ou a P125 assume). Sem isso a duplicata «compositor por `/usr/local/sbin/aurora-cosmic-comp-ws.sh`» continua. |
| D11 | quem dispara o corte | **`fix_vizinhos` no doctor** (seção 4), na P124. Isso também faz o item `aurora-compositor` da P121 valer. |

## 6. Ordem

1. **P121**, em voo no bloco Central: o `vizinhos.tsv` ganha `aurora-compositor`.
2. **P124**, numa rodada depois da Central, porque mexe em `scripts/vizinhos.sh`, `vizinhos.tsv`,
   `tests/vizinhos.sh` e `bin/meow`, os mesmos arquivos da P121. Traz o gatilho, a linha, a âncora
   única, a checagem de sintaxe, o tipo `unidade` e os sete B. Depois da integração, a passada
   seguinte do doctor corta também o `aurora-compositor`.
3. **P125**, depois da P124, porque usa o tipo `unidade`. O vigia da #2059 espera a luz noturna da
   Aurora ter saído (P121). O vidro e o painel não dependem de mais nada.

## Anotado para depois

- O fork `meowsystem-clipboard` (P122) leva a poda e o `persist`; aí vem o item de vizinho da cadeia
  `aurora-clipboard`.
- A porta única `meowsystem-reciclar-painel` sem argumentos, para o Alt+F2 da Aurora apontar.
- Saídas da Aurora que mandam digitar, fora do território deste projeto:
  - a linha do resumo do `meow doctor` no self-heal («rode 'meow doctor --consertar'»);
  - o `notify-send` «Peça ao Claude…» dos vigias;
  - «rode o self-heal… sudo bash» nos atalhos.

  A primeira some quando o doctor passar a cortar sozinho: a frase vira «o doctor cuida às 5h».
- O `aurora-painel-fantasma` gasta 1,1 a 1,6 s de CPU a cada 3 min, cerca de 8 min por dia, para
  dizer «painel saudável».
- O `aurora-vidro-maximizado` sincronizou 12 vezes em 3 dias (alpha `7C → B5/FF`). É a prova de que
  o MeowSystem precisa do `.path`, e não só do doctor das 5h.

## Perguntas para o coordenador (ela delegou)

1. D1: os alfinetes passam ao doctor e o `aurora-cosmic-workspaces.py` sai? Se sim, avisar a ela
   que o `CLAUDE.md` global muda de texto.
2. D10: os trechos de instalação do compositor ficam na P121 ou na P125?
3. D3: o corte da bandeja no script do qBittorrent entra na P125?

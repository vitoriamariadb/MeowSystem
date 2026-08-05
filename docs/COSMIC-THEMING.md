# Como o COSMIC se veste — o que foi medido nesta máquina

Este documento guarda **fatos verificados na MeowSystem**, não o que a documentação
promete. Cada um traz a data e como foi medido, para que a próxima sessão possa
refazer o teste em vez de acreditar.

Máquina: Pop!_OS 24.04 · COSMIC (settings 1.0.12 / applets 1.0.15) · Wayland ·
DP-1 1920x1080 numa TV de 52 polegadas.

---

## 1. Não existe CLI de tema, e o daemon não deriva

**Medido em 2026-08-04.** O tema que o sistema lê (`CosmicTheme.Dark/v1` e `/v2`) é
*derivado* do que a GUI edita (`CosmicTheme.Dark.Builder/v1`). A pergunta era: quem
faz essa derivação — algum daemon, ou o app gráfico?

Escrevi o mauve do Catppuccin (`#CBA6F7`) direto em
`~/.config/cosmic/com.system76.CosmicTheme.Dark.Builder/v1/accent` e esperei.

```
mtime Builder/v1/accent : 2026-08-04 17:41:13   (escrito por mim)
mtime Dark/v1/accent    : 2026-04-12 18:49:57   (intocado)
```

O `cosmic-settings-daemon` estava vivo (PID 2825) e **não derivou nada** — nem em 4
segundos, nem depois. Quem deriva é o app `cosmic-settings`, com a janela aberta.

**Consequência de arquitetura:** um tema novo precisa ser importado pela GUI
**uma vez**. Depois disso, `scripts/capturar_tema.sh` fotografa o resultado, a foto
vai para o git, e `scripts/aplicar_tema.sh` reproduz por cópia em qualquer máquina,
sem GUI. É uma vez na vida do projeto, não uma vez por máquina.

**O que NÃO fazer:** escrever chave por chave em `Dark/v1`. As árvores derivadas já
discordam entre si nesta máquina — `Dark/v1` tem 30 chaves e `Dark/v2` tem 17, e o
`window_hint` de uma é `Some(...)` enquanto o da outra é `None`. Reproduzir isso à
mão gera um tema híbrido que *quase* funciona, e o "quase" só aparece semanas depois.

---

## 2. O nome do tema é o laço externo — `hicolor` é o fim da fila

**Medido em 2026-08-04.** A regra de resolução de ícone do COSMIC não é "sistema vence
usuário". É outra coisa, e confundir as duas custou uma conclusão errada aqui.

### A conclusão errada, e por que ela era errada

O primeiro teste plantou um triângulo vermelho em
`~/.local/share/icons/**hicolor**/.../com.system76.CosmicAppLibrary.svg` enquanto o tema
ativo era `breeze-dark`. O triângulo não apareceu, e disso se concluiu que
`/usr/share` vencia `~/.local/share`.

**A causa era outra:** `hicolor` é o **último** elo da cadeia de herança. Ele só é
consultado depois de o tema selecionado e todos os seus `Inherits` falharem — e nesse
caso não falharam. O diretório do usuário nunca esteve em desvantagem; o *tema* é que
estava no fim da fila.

### A regra real

O laço **externo** da busca é o **nome do tema**; o diretório-base é o laço **interno**.
Ordem observada por `strace` (num `Xvfb :99`, sem tocar na sessão dela), para o tema
selecionado `MeowTesteIcones`:

```
1. /usr/share/icons/MeowTesteIcones          <- tema selecionado, base de sistema
2. ~/.local/share/icons/MeowTesteIcones      <- tema selecionado, base do usuário
3. /usr/share/icons/breeze-dark              <- Inherits
4. /usr/share/icons/Cosmic
5. ~/.local/share/flatpak/exports/share/icons/hicolor
```

Disso saem duas consequências:

- **`~/.local/share/icons/<tema-selecionado>` vence `/usr/share/icons/hicolor`** com
  folga. Provado com o `google-chrome`, que só existe no `hicolor` do sistema: um SVG
  plantado apenas no tema do usuário venceu.
- `/usr/share` só vence `~/.local/share` quando **o nome do tema é o mesmo**. Se um dia
  o mesmo nome existir nos dois lugares, o de `/usr/share` ofusca o do usuário em
  silêncio.

### Confirmado na prática, no desktop dela

Montado `~/.local/share/icons/MeowSystem-Icons` com `scalable/apps/` e
`icon_theme = "MeowSystem-Icons"`: **o botão do dock virou o gato Catppuccin na hora**,
sem `sudo`, sem `/usr/share`, sem envolver o Ritual da Aurora.

**Consequência de arquitetura:** o MeowSystem entrega ícones em
`~/.local/share/icons/MeowSystem-Icons` e pronto. A regra "nada em `/usr/share`" da
especificação **está certa** — quem estava errado era o teste.

### Detalhes que economizam tempo

- **Dentro de um tema, a extensão é o laço externo:** todos os `.svg` (em todos os
  tamanhos) são tentados antes de qualquer `.png`. Basta entregar `scalable/apps/*.svg`.
- **`Directories=` é a única chave de tamanho que importa.** A crate do COSMIC
  (`cosmic-freedesktop-icons`) parseia `[Icon Theme]`, `Inherits` e `Directories`, e
  ignora `Type=`, `MinSize`, `MaxSize` e `Threshold`. Não perca tempo afinando-os.
- **`gtk-update-icon-cache` é irrelevante:** a crate não lê `icon-theme.cache` (zero
  ocorrências do literal no binário). Rodar não faz mal, mas não é o que destrava nada.
- **Reiniciar é obrigatório:** `cosmic-panel` e `cosmic-app-list` leem a config no
  início da sessão e não a vigiam. Um `pkill -x cosmic-panel` basta (o `cosmic-session`
  respawna em ~4ms).
- **O `hicolor` do usuário tem uma armadilha própria:** o `index.theme` dele declara
  só `48x48/apps,128x128/apps,256x256/apps,512x512/apps` — **`scalable/apps` não está
  lá**. SVG solto em `scalable/` daquele tema é ignorado. No nosso tema, declaramos.

---

## 2b. Claro e escuro não são dois temas — são um só, com um interruptor

**Medido em 2026-08-04**, depois dos três imports.

O COSMIC guarda duas árvores completas e independentes: `CosmicTheme.Dark` e
`CosmicTheme.Light`. Importar um `.ron` de flavor claro escreve na `Light`;
importar um escuro escreve na `Dark`. Quem decide qual está em uso é um único
arquivo: `CosmicTheme.Mode/v1/is_dark`.

A prova saiu sozinha das capturas. Depois de compor as três, `mocha-mauve` e
`latte-mauve` diferem em **exatamente um arquivo**, e é o `is_dark`:

```
mocha-mauve    189 arquivos  |  Dark: #CBA6F7  Light: #8839EF  is_dark=true
latte-mauve    189 arquivos  |  Dark: #CBA6F7  Light: #8839EF  is_dark=false
```

Consequências práticas:

- **Toda captura precisa das DUAS árvores em Catppuccin.** As duas primeiras
  saíram com a `Light` antiga (o teal `#00525A`), porque foram importadas antes
  do latte. Alternar para elas teria devolvido o tema claro de fábrica na hora em
  que o modo automático virasse o dia. Corrigido compondo a `Light` do latte nas
  três — as árvores são independentes, então compor é legítimo e é exatamente o
  estado que existiria se os dois imports tivessem sido feitos na outra ordem.
- **`MODO=auto` não precisa de tema nenhum novo.** É escrever `is_dark` conforme
  o horário. Nada de reaplicar árvore, nada de piscar interface.
- O accent do Latte é `#8839EF` — mais escuro e saturado que o mauve do Mocha
  (`#CBA6F7`), como manda um flavor claro. São a mesma cor da paleta com o mesmo
  nome, e valores diferentes de propósito.

## 3. O gato do painel não passa por tema de ícones

O applet `dev.cappsy.CosmicExtAppletLogoMenu` guarda o caminho do arquivo direto:

```
custom_logo_active = true
custom_logo_path   = "/home/vitoriamaria/.config/cosmic/logos/gato-pop.svg"
```

Trocar a logo do painel é trocar esse SVG (ou apontar a chave para outro arquivo) —
não passa por `icon_theme`, não precisa de cache, não precisa de `/usr/share`.

**Armadilha do nome:** o applet faz `.symbolic(path.contains("-symbolic.svg"))`. Um
arquivo terminado em `-symbolic.svg` é achatado numa cor só. Portanto
`assets/meow-symbolic.svg` **não serve** como logo do painel.

### A logo TROCA AO VIVO — mas só pela chave, não pelo arquivo

**Medido em 2026-08-04**, respondendo à pergunta "a logo pode girar junto com os
papéis de parede?".

| O que se muda | Efeito |
|---|---|
| o **conteúdo** do SVG apontado | **nada** — o applet cacheou a imagem no carregamento |
| a **chave** `custom_logo_path`, para outro arquivo | **troca na hora**, sem reiniciar o painel |

O applet vigia a configuração por inotify (o processo tem 6 fds de inotify), mas não
vigia o arquivo de imagem. Então reescrever `meow-mocha.svg` no lugar não faz efeito
até o próximo `pkill -x cosmic-panel`; já apontar a chave para um
`meow-mocha-pink.svg` troca o gato instantaneamente, sem piscar nada.

**Consequência:** dá para girar a logo — inclusive junto com o carrossel de papel de
parede — mantendo **um arquivo por variante** e alternando só a chave. Nunca reescrevendo
o mesmo arquivo.

---

## 4. Onde cada cor mora, e em que formato

Descoberta que já corrigiu código: **o formato difere entre schemas.**

| Caminho | Formato | Exemplo |
|---|---|---|
| `CosmicTheme.Dark/v1/background` | floats | `base: ( red: 0.19223961, ... )` |
| `CosmicTheme.Dark/v2/background` | string hex | `base: "#313250D9"` |

O `aurora-vidro-maximizado.py` só casa `base: "#RRGGBBAA"` — ou seja, atua **apenas
no `v2`**. Um normalizador escrito para o formato errado "passa" no teste sem testar
nada (aconteceu, foi corrigido).

Além disso, `CosmicTheme.Dark.Builder/v2` **não tem nenhuma chave de cor** — só
`active_hint`, `alpha_map`, `corner_radii`, `frosted*` e `window_hint`. Todas as cores
vivem em `Builder/v1`. Receitas que mandam "escrever as chaves de cor do Builder/v2"
criariam chaves que nunca existiram aqui.

---

## 4b. Som — o COSMIC toca exatamente UM, e não é por tema

**Medido em 2026-08-04.** A pergunta era "dá para vestir a MeowSystem com um tema de
som Catppuccin?". A resposta honesta é **não, e o motivo não é a falta de sons**: é
que quase não existe onde tocá-los. O alcance inteiro desta área é **um arquivo**.

### O que o COSMIC toca, e quem toca

Varrendo os 41 binários `/usr/bin/cosmic-*`:

```
strings -a /usr/bin/cosmic-<x> | grep -c canberra     -> 0 em TODOS
strings -a /usr/bin/cosmic-<x> | grep -c pw-play      -> 1 em cosmic-osd
                                                          1 em cosmic-settings-daemon
                                                          0 nos outros 39
```

O COSMIC **não usa libcanberra**. Ele faz `fork` de `pw-play --media-role Notification`.
(Os 3 acertos de "canberra" no `cosmic-initial-setup` são a **cidade** Canberra, da
lista de fusos horários — é fácil contá-los como código de som e concluir errado.)

Dos dois binários com `pw-play`, só um produz som audível nesta máquina:

| binário | o que toca | vale aqui? |
|---|---|---|
| `cosmic-osd` | `freedesktop/stereo/audio-volume-change.oga` | **sim** — é o único |
| `cosmic-settings-daemon` | `power-plug`, `power-unplug`, `power-unplug-battery-low` | **nunca** — é PC de mesa |

**Não confunda o gatilho com o tocador.** O `cosmic-settings-daemon` **não** toca o
som de volume: o binário dele tem **zero** ocorrências de `audio-volume-change`, de
`stereo` e de `.oga`. Ele é o **gatilho** da tecla — o `system_actions` mapeia
`XF86AudioLowerVolume` para `busctl --user call com.system76.CosmicSettingsDaemon
... VolumeDown`. Com o daemon morto, a tecla não muda o volume, o osd não tem o que
anunciar, e nenhum som nasce. Isso já foi lido aqui como "o daemon é o tocador";
não é.

Os sons de energia estão duplamente mortos: o `/sys/class/power_supply/` desta
máquina só tem `ps-controller-battery-*` (a bateria do DualSense), e o daemon
procura os arquivos em `/usr/share/sounds/Pop/` — **caminho de sistema cravado, sem
XDG**, ou seja, nem sobrescrever daria.

### A prova, sem inferência: o argv do `pw-play`

Não é preciso deduzir pela duração do sink-input. Dá para **ler o comando**.
Disparando o mesmo `busctl` da tecla e varrendo `/proc/*/cmdline` durante a janela:

```
pw-play --media-role Notification /usr/share/sounds/freedesktop/stereo/audio-volume-change.oga
```

E depois de `scripts/som.sh aplicar`, o **mesmo** teste:

```
pw-play --media-role Notification /home/vitoriamaria/.local/share/sounds/freedesktop/stereo/audio-volume-change.oga
```

**O arquivo do usuário vence o do sistema.** O código do osd é
`xdg::BaseDirectories::with_prefix("sounds").find_data_file("freedesktop/stereo/audio-volume-change.oga")`,
e `find_data_file` consulta o `XDG_DATA_HOME` antes do `XDG_DATA_DIRS`.

Para ver isto ao vivo, com a tecla de volume na mão dela:

```
while :; do pgrep -af '(^|/)pw-play '; done     # e aperte a tecla
```

### Isto é o INVERSO da regra dos ícones

Duas consequências que custam tempo se forem invertidas:

- **O nome do tema é cravado no binário.** Um tema `MeowSystem-Sounds` nunca seria
  lido, por mais correto que fosse o `index.theme`. O jeito de trocar o som é
  sombrear o nome `freedesktop` dentro do data home dela.
- **Em som o usuário ganha; em ícone, não.** A seção 2 mostra que, com o mesmo nome
  nos dois lugares, `/usr/share/icons` **ofusca** `~/.local/share/icons`. Em som é ao
  contrário.

Por isso o `som.sh` instala **um arquivo e nenhum `index.theme`**: sem `index.theme`
no diretório do usuário, quem resolver o tema `freedesktop` pela especificação
continua lendo o `index.theme` do sistema e só encontra sobrescrito o único arquivo
que plantamos. Escrever um `index.theme` incompleto ali sequestraria o tema inteiro.

### O `gsettings` de som é decorativo nesta máquina

`org.gnome.desktop.sound theme-name` está em `freedesktop` e **ninguém o lê**: os
apps do COSMIC são iced/libcosmic, não GTK. O caminho GTK/canberra está tecnicamente
instalado e completamente dormente — nenhum processo da máquina tem `libcanberra`
mapeada (varredura de `/proc/*/maps`), `GTK_MODULES` é só `gail:atk-bridge`,
`canberra-gtk-play` não existe, e o `/etc/gtk-3.0/settings.ini` do Pop aponta
`gtk-sound-theme-name = Yaru` para um tema que **não está instalado**. Apontar o
`gsettings` para um tema nosso produziria zero som audível.

### O debounce de 125 ms manda na duração do som

No fonte do `cosmic-osd`:
`if now.duration_since(self.sink_last_playback) > Duration::from_millis(125)`.

Ou seja: segurando a tecla, nasce um `pw-play` a cada 125 ms. **Som maior que isso se
sobrepõe a si mesmo** — provado plantando um arquivo de 2 s e disparando duas
mudanças com 300 ms de intervalo: `pactl list short sink-inputs` mostrou **dois**
sink-inputs coexistindo. É por isso que o nosso tem 85 ms e não pode crescer, e é
por isso que o som do tema Pop (0,35 s) não serve, apesar da licença permitir.

### A extensão `.oga` é mentira — e isso elimina dependências

Quem lê o arquivo é a libsndfile, que detecta o formato pelo **conteúdo**. Um WAV PCM
salvo com nome `.oga` toca normalmente (`file` responde "RIFF ... WAVE audio,
Microsoft PCM, 16 bit, stereo 48000 Hz"; `pw-play` sai com 0 e o COSMIC o tocou pelo
caminho real). Logo o som pode nascer da biblioteca padrão do Python: **sem ffmpeg,
sem oggenc, sem sox** no caminho de instalação.

### Licença: por que sintetizamos em vez de copiar

O som de fábrica do `freedesktop` é **CC-BY-SA-3.0** (Lucas McCallister), e a 3.0
**não** é compatível com a GPL-3.0 deste repositório — só a CC-BY-SA **4.0** ganhou
essa compatibilidade, e de mão única. O do tema Pop é CC-BY-SA-4.0 (Mads Rosendahl),
redistribuível, mas alto e longo demais. Sintetizar sai mais barato que discutir
licença: o arquivo é obra do projeto, registrado como **CC0-1.0** em
`src/sounds/CREDITOS.md` e no `LICENCAS.txt` que o script deixa na máquina.

### O que fica INALCANÇÁVEL, e o custo de cada um

| evento | veredito |
|---|---|
| volume mudando | **alcançável** — é o único; `scripts/som.sh` |
| notificação chegando | **impossível sem daemon nosso**: `cosmic-notifications` tem **zero** linhas de áudio, embora anuncie a capacidade `sound` no `GetCapabilities`. `notify-send -h string:sound-name:message` gera zero sink-inputs. Dá para escutar o `Notify` por eavesdrop no D-Bus, mas custa um processo por sessão, quebra quando a System76 mudar o barramento e tocaria **por cima do "Não Perturbe"**, que está ligado na config dela |
| bateria / tomada | **morto por hardware** — máquina de mesa |
| plugar dispositivo, erro, alerta, captura de tela, bloqueio | **não há reprodutor** — `pw-play` e `canberra` zerados em todos os binários |

**Conclusão de arquitetura:** não existe "tema de som" a montar. Existe **um arquivo
a trocar**, e o `scripts/som.sh` faz exatamente isso — sem `sudo`, sem `/usr/share`,
sem envolver o Ritual da Aurora, e valendo já na próxima mudança de volume (o osd
faz `spawn` de um `pw-play` novo a cada reprodução: não há cache a invalidar, ao
contrário da logo do painel da seção 3).

### Achado colateral que não é sobre som

Em 04/08/2026 o `cosmic-settings-daemon` foi encontrado **morto** no meio da sessão
dela. Com ele morrem as teclas de **volume e de brilho** inteiras, não só o som:
`busctl --user call ... VolumeDown` responde `The name is not activatable`. Por isso
`som.sh estado` e `som.sh conferir` avisam quando ele não está de pé. O conserto
durável é sair e entrar na sessão; religá-lo à mão vale até o próximo boot.

---

## 5. Fronteira com o Ritual da Aurora

O Aurora roda como root a cada hora, no boot e após todo apt. Onde os dois querem
mandar no mesmo arquivo, quem cede é o MeowSystem — exceto onde marcado.

| Recurso | Dono | Como conviver |
|---|---|---|
| alpha de `background`/`primary`/`secondary` | Aurora | O `meow` grava em `transparent_*` e deixa o Aurora propagar. O `--conferir` normaliza os 2 dígitos de alpha, senão o doctor acusa divergência eterna e entra em ping-pong com a unit `.path`. |
| `~/.config/cosmic/logos/gato-pop.svg` | Aurora | O gato Catppuccin entra como asset do Andromeda; o self-heal propaga. |
| ícone do App Library em `/usr/share` | Aurora | Idem — mesma fonte, dois destinos. |
| tema do qBittorrent | Aurora | A allowlist dele ganha `catppuccin`; o `meow` chama o script em vez de escrever no `.conf`. |
| `~/.config/fastfetch` | Aurora | É symlink para o repo Andromeda, com auto-commit em 10 min. Mudança ali é deliberada, com commit. |
| atalhos de teclado | Aurora | O `meow` não escreve e exclui do restaurar. |
| `pinned_workspaces` | Aurora | Fora do restaurar: restaurar por cópia derrubaria os workspaces `Meow` e `OS`. |
| `CosmicTerm/v1` | dividido | O `meow` escreve só `color_schemes_*`. Nunca `keybindings` nem `shortcuts_custom` — é o colar dela. |
| `plugins_wings` do painel | Aurora | Entra no backup, sai do restaurar. A ordem dos applets é dela. |

---

## 6. O que nunca fazer nesta máquina

- **`apt upgrade` ou mexer em pacote `cosmic-*`.** O `/usr/bin/cosmic-comp` está
  patchado duas vezes (workspace vazio e night light). Uma versão nova mata os dois de
  uma vez e derruba os workspaces alfinetados junto.
- **`sudo` perto de `~/.config`.** Um arquivo de dono root ali faz a GUI de tema falhar
  **em silêncio**, e o sintoma aparece dias depois.
- **Escrever em `~/.config/zsh`.** É o repo Andromeda, com auto-commit a cada 10 min:
  qualquer arquivo largado lá vira commit e push no repositório privado dela.

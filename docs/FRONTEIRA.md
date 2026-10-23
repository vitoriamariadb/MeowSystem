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
`/usr/share`, `/usr/local/share`, `/usr/bin` e `/usr/lib`, sempre, e os caminhos que o
`~/.config/meow/vizinhos.conf` declara de outro projeto — nesta máquina, o
`~/.config/zsh` (repositório de quem usa, com auto-commit a cada 10 min) e os atalhos de
teclado. Numa máquina sem vizinhos o arquivo não existe, e a lista é só a do sistema.

**Este documento é sobre a máquina de origem.** O Ritual da Aurora é um projeto vizinho
que só existe nela; o MeowSystem não depende dele e não o lê em execução (P37, P39 e
P44 tiraram dele tudo o que era tema). Numa máquina sem ele, as linhas da tabela marcadas
«Aurora» simplesmente não têm dono além do COSMIC, e o resto vale igual.

## O DESEMPATE, DECIDIDO POR QUEM USA EM 09/09/2026

> *"se for algum problema envolvendo algum hook ou o andromeda o meowsystem se
> sobrepõem."*

**Onde um hook ou o Andromeda disputarem com o MeowSystem, quem vence é o
MeowSystem.** Vale para as três formas em que a disputa aparece nesta máquina: os
hooks de git de `~/.config/git/hooks`, os hooks de `apt` em `/etc/apt/apt.conf.d/`,
e o que o repositório do Andromeda repõe por conta própria.

**Por que isto muda alguma coisa.** A frase de cima — *"onde os dois querem mandar
no mesmo arquivo, o visual é do MeowSystem"* — já dizia quem ganha, mas só sobre
**aparência**; a tabela abaixo tem quinze linhas em que o dono continua sendo o
Aurora justamente porque ali a chave é do sistema. A decisão de quem usa **não** apaga
essas quinze: elas seguem como estão, porque ninguém as está disputando. O que ela
resolve é o **empate**, que até hoje se resolvia caso a caso e por conversa — e uma
regra que mora em conversa é uma regra que se perde na sessão seguinte.

**O que ela NÃO autoriza**, e continua valendo palavra por palavra: escrever em
território de vizinho segue exigindo as quatro guardas — **uma linha e nunca o
arquivo inteiro**, **backup antes** (falhar o backup aborta a escrita), **em voz
alta** na saída, e **uma chave no `meow.conf` para desligar**. Vencer o desempate é
poder escrever a linha; não é poder escrever sem as guardas. Precedente medido: a
escrita cirúrgica no `logo.source` do `fastfetch`, autorizada só depois de um
`grep fastfetch` no self-heal provar que o outro dono não disputava aquela linha.

**A ordem de trabalho que sai daí:** medir se o outro dono disputa mesmo a linha;
se disputa, o MeowSystem escreve **e** deixa o desfazer pronto; se não disputa, não
há empate para desempatar e nada muda.

---

## HÁ UMA SEGUNDA FRONTEIRA, E ELA NÃO É ESTA — 22/09/2026

Este documento trata da fronteira entre **dois programas** que escrevem na mesma
máquina: o MeowSystem e o Ritual da Aurora. Desde 22/09/2026 o projeto tem uma
segunda linha, **dentro do próprio repositório**, e confundir as duas custa
tempo de quem procura a regra:

> **`assets/` é o que o MeowSystem É; `packs/` é o que ele VESTE; e
> `~/.local/state/meowsystem/` é o que a máquina GEROU.**

**Desde 15/10/2026 (decisão 14, P88) todo desenho de ícone é `packs/`.** O
acervo que era do motor em `assets/icones/` é o pack-base `packs/meowsystem/`,
nas três pastas (`apps/`, `sistema/`, `biblioteca/`), e todo pack o herda; os
resgatados, de cor Dracula fixa, foram para `packs/dracula/`. A frase de
21/09/2026, «o mapa é do pack, o acervo pode ser do motor», está **revogada**.
Em `assets/icones/` sobrou só ferramenta: os mapas técnicos de aplicativo, a
prévia das folhas, os originais de fábrica da bandeja e a folha dos resgatados.

Ela responde "de quem é este arquivo" e não "quem escreve nesta chave". Mora em
**`docs/PACKS.md`, seções «A fronteira: `assets/` contra `packs/`» e «O acervo
de ícones do pack»**, que são o documento do formato de pack — é lá que quem
escreve um pack vai procurar. Quem a cobra é `tests/arvore.sh`, e o
`tests/tres-pastas.sh` cobra as três pastas.

As duas não se sobrepõem: nenhuma linha da tabela abaixo fala de arquivo
versionado, e nenhuma linha daquela seção fala de território de vizinho.

---

## A tabela

| alvo | quem escreve hoje | dono |
|---|---|---|
| `~/.config/cosmic/com.system76.CosmicTheme.*` | Meow + COSMIC (GUI) | **Meow** |
| `CosmicTheme.*/v*/frosted_maximized_apps` (o vidro da JANELA) | Meow (`vidro.sh`) | **Meow** — desde 19/09/2026, ver abaixo |
| alpha do `base:` de `background`/`primary`/`secondary` | Meow (`vidro_janela.py`), **só onde não há a chave nativa** | **Meow** — desde 19/09/2026; era da Aurora |
| detectar painel VIVO que não desenha | Meow (`lib/painel.sh`) | **Meow** — desde 19/09/2026; era da Aurora (`aurora-painel-fantasma.sh`) |
| `CosmicPanel.{Panel,Dock}/v1/keep_style_on_maximize` | Meow (`vidro.sh`) | **Meow** — a GUI não tem controle para ela |
| `CosmicPanel.{Panel,Dock}/v1/opacity` | COSMIC (GUI) | **quem usa** — desde 17/08/2026, ver abaixo |
| escala das saídas (`cosmic-randr`, o `outputs.ron`) | COSMIC (GUI) | **quem usa** — o `install.sh` aplica `ESCALA_TELA` quando pedido; o doctor nunca |
| `CosmicPanel.*/v1/plugins_{wings,center}` | Aurora, À MÃO | **Aurora** — a ordem dos applets é de quem usa; nem o `midia.sh` nem o `leitura_build.sh` encostam, e os dois só AVISAM quando falta a linha |
| `CosmicTk/v1/icon_theme` e `~/.local/share/icons/MeowSystem-Icons` | Meow | **Meow** |
| `/usr/share/icons/hicolor/.../CosmicAppLibrary.svg` | ambos | **Meow** — o Aurora restaura o `.aurora-original` |
| `~/.config/cosmic/logos/` | ambos | **Meow** — o `gato-pop.svg` do Aurora foi aposentado |
| `~/.local/share/icons/hicolor/index.theme` | Meow (`hicolor.sh`) | **Meow** |
| `~/.local/share/applications/` — conteúdo do lançador | ambos | **Meow** |
| `~/.local/share/applications/com.github.DiegoMMR.CosmicExtAppletNowPlaying.desktop` | Meow (`midia.sh`) | **Meow** — a "sombra" do applet de mídia, ver abaixo |
| `~/.local/bin/meow-applet-now-playing` e `~/.local/state/meowsystem/midia/` | Meow (`midia_build.sh`) | **Meow** |
| `~/.config/cosmic-ext-applet-now-playing/{panel-text-width,panel-color-style,album-art-remote}` | Meow (`midia.sh`) | **Meow** |
| `~/.config/cosmic-ext-applet-now-playing/album-color-enabled` | quem usa, pelo popup do applet | **quem usa** — o Meow só migrou o valor do sandbox uma vez |
| `~/.local/share/applications/com.meowsystem.AppletLeitura.desktop` | Meow (`leitura_build.sh`) | **Meow** — a sombra do applet do modo de leitura; sem applet de fábrica por trás |
| `~/.local/bin/meow-applet-leitura` e `~/.local/state/meowsystem/leitura/` | Meow (`leitura_build.sh`) | **Meow** |
| `~/.local/state/cosmic/com.meowsystem.AppletLeitura/v1/ultima_{temperatura,textura}` | o applet | **quem usa** — é o ponto ao qual o interruptor volta; nenhum script do Meow o lê |
| `/usr/local/share/applications/{google-chrome,steam}.desktop` (wrappers de `Exec=`) | Aurora | **Aurora** — mudou de `~/.local/share` em 13/08/2026, ver abaixo |
| `~/.local/share/applications/{vim,qt5ct,qt6ct,debian-*xterm}.desktop` | ambos | **Meow** — `NoDisplay` preserva o handler de MIME; o `Hidden=true` do Aurora mata |
| `/usr/share/applications/*` (`NoDisplay`, nome curto) | Meow (com sudo) | **Meow** — o Aurora não escreve ali |
| `/usr/local/lib/meowsystem/ponte_root.sh` e `perfil` | Meow (`install.sh`, `etapa_ponte_root`) | **Meow** — root:root; nem quem usa nem o Meow sem senha conseguem trocá-los, e é isso que os torna confiáveis |
| `/etc/sudoers.d/49-meowsystem-ponte` | Meow (`install.sh`) | **Meow** — o diretório é COMPARTILHADO (o Hefesto tem o `49-hefesto-bt-ponte`, a Aurora o `aurora-selfheal`); cada um escreve o SEU arquivo e nunca o do outro, ver abaixo |
| `/etc/apt/apt.conf.d/99-meow-lancador` | Meow | **Meow** — o segundo hook de apt da máquina, ver abaixo |
| `/usr/local/sbin/meow-lancador-apt.sh` | Meow | **Meow** — o `sbin` distingue do `/usr/local/bin` do Aurora |
| `/etc/apt/apt.conf.d/99-ritual-aurora-self-heal` | Aurora | **Aurora** |
| `~/.config/cosmic/com.system76.CosmicBackground` | Meow (`wallpaper.sh`) | **Meow** |
| `/var/lib/cosmic-greeter/.config/cosmic` | Meow (`greeter.sh`) | **Meow** |
| `~/.config/cosmic/com.system76.CosmicSettings.Shortcuts` | Aurora | **Aurora** — é o colar de quem usa |
| `pinned_workspaces` | Aurora | **Meow desde 07/09/2026** — decisão de quem usa: *"então corrige no zsh e traz a feature pra cá"*. O reparador do Ritual da Aurora fica desarmado pela sentinela `~/.config/cosmic/.aurora-workspaces-off`, que é o opt-out que ele mesmo oferece — o script vizinho não foi editado. Quem escreve é `scripts/areas.sh`; apagar a sentinela devolve o arquivo a ele. Ver abaixo |
| `CosmicComp/v1/leitura_{temperatura,textura}` | Meow (`leitura.sh`, pelo relógio) **e** o applet da topbar | **Meow escreve o horário, quem usa escreve a mão** — desde 30/08/2026, ver abaixo |
| `CosmicComp/v1/leitura_{agenda,hora_inicio,hora_fim}` | o applet da topbar (`com.meowsystem.AppletLeitura`) | **quem usa** — o Meow LÊ e obedece, e nunca escreve |
| ~~a luz quente da tela (patch binário de night light)~~ | Aurora (`aurora-night-light.py`) | **APOSENTADA** — a etapa 4 foi feita; o binário de 30/08 não tem o patch binário (medido em 31/08, ver abaixo). Quem esquenta a tela agora é o `leitura_temperatura`, e o dono é o Meow |
| `~/.config/autostart/` | Aurora | **Aurora** |
| `gsettings` / `dconf` — `org.gnome.desktop.wm.preferences` (`button-layout`) | Aurora | **Aurora** |
| `gsettings` / `dconf` — `org.gnome.desktop.interface` (`cursor-theme`) | Meow (`cursor.sh`) | **Meow** — resolvido em 25/08/2026, ver abaixo |
| `~/.icons/default/index.theme` | Meow (`cursor.sh`) | **Meow** — é o que o `cosmic-comp` obedece; o gsettings NÃO o alcança |
| `/usr/local/bin/*` (wrappers de execução) | Aurora | **Aurora** |
| ~~`/usr/local/share/zsh/site-functions/_meow`~~ | ~~Aurora~~ | **MUDOU DE LADO** em 24/09/2026 (P44) — era o self-heal do Ritual que a copiava, e fora de uma casa ninguém a instalava. Ver a linha de baixo |
| `~/.local/share/zsh/site-functions/_meow` | Meow (`install.sh`, `instalar_completion`) | **Meow** — sem root e sem ponte. A linha do `fpath` que faz o zsh procurar ali é do shell de quem usa: o instalador a DIZ, não a escreve |
| binário `cosmic-comp` (a série de `patches/`) | Meow (`garantir_builds.sh`, `compositor_patches.sh`) | **Meow, por PATH, desde 09/10/2026 (P76)** — o build da casa mora em `~/.local/libexec/meow/cosmic-comp/<versão>/`, sem sudo, e o shim `~/.local/bin/cosmic-comp` escolhe a cada sessão entre ele e o de fábrica. O `/usr/bin/cosmic-comp` é do `apt`, e a tela de login usa só ele. Refeito sozinho depois do apt, no login e no doctor (P81). Até a P39 era a Aurora; da P39 à P76, o Meow instalava em `/usr/bin` com `sudo` |
| ~~`/usr/local/share/aurora/patches.d/` (a `series` e os `.patch`; cópia canônica em `~/.config/zsh/patches/patches.d/`)~~ | ~~Aurora~~ | **MUDOU DE LADO** — desde 22/09/2026 a série é `patches/series`, deste repositório, e os cinco `.patch` moram todos aqui. Ver «O que é tema volta para casa», no fim |
| `patches/series` (a série: classe, ordem, marcador-base) | Meow | **Meow** — desde 22/09/2026; era da Aurora. É quem sabe APLICAR os patches, e isso é tema |
| ~~`/var/lib/aurora/cosmic-comp-patches.estado`~~ | ~~Aurora~~ | **MUDOU DE LADO** em 24/09/2026 (P39) — o `.estado` foi para `/var/lib/meowsystem/cosmic-comp/patches.estado`, e com o shim (P76) cada build guarda o seu, em `~/.local/libexec/meow/cosmic-comp/<versão>/estado`, lido pela linha `patches` do doctor |
| `patches/*.patch` deste repositório | Meow | **Meow** — é onde o patch nasce e é revisado. Desde 22/09/2026 é também onde ele é APLICADO (`compositor_patches.sh aplicar`), e desde 24/09/2026 (P39) compilar e instalar também: `meow compositor` |
| ciclo de vida do processo `cosmic-panel` | Aurora | **Meow desde 26/08/2026** — o `systemd/meow-painel.service` é o supervisor; o lado da Aurora segue desarmado. A tabela dizia "Aurora" até 29/08 |
| tema do qBittorrent | Aurora | **Aurora** — o `meow` chama o script de lá |
| `~/.config/fastfetch/` (o diretório inteiro) | Meow (`fastfetch_logo.sh`) | **Meow desde 24/09/2026 (P44)** — era symlink para o Spellbook, e cada chave escrita virava commit lá. Virou diretório de verdade, com o mesmo conteúdo e backup; o Spellbook parou de versioná-lo. Até a P44 a linha dizia "Aurora; Meow escreve cirurgicamente o `logo.source`" — ver abaixo |
| `~/.config/meowsystem/fzf.sh` (as cores do fzf) | Meow (`scripts/fzf.sh`) | **Meow desde 24/09/2026 (P44)** — sai da paleta do pack no ar. A linha que o carrega é do shell de quem usa |
| binário `cosmic-files` / `cosmic-files-applet` | apt | **Meow, por PATH** — `~/.local/bin/` vence `/usr/bin/`, e o nosso SAI DA FRENTE quando o pacote sobe de versão sem build correspondente; o build da versão nova é refeito sozinho (P81) |

---

## O applet de mídia entra por sombra, e `plugins_wings` continua da Aurora (24/08/2026)

O pedido foi nome da música, controles, capa e cores do álbum na dock. A causa de faltarem
capa e cor era **uma linha** do applet Now Playing: `src/media.rs` fazia
`metadata.art_url().and_then(file_url_to_path)`, que descarta toda URL que não seja
`file://` — e o Spotify publica `mpris:artUrl` como `https://i.scdn.co/image/…`, nunca um
`file://`. As duas queixas caíam juntas porque a **cor é extraída da capa**: não eram dois
defeitos, era um.

A correção é um patch nosso (`src/applets/now-playing/`), compilado nativo e instalado
por **sombra**: um `.desktop` de **mesmo basename** em `~/.local/share/applications`.
O cosmic-panel acha applet pelo basename do `.desktop`, varrendo os diretórios do XDG na
ordem padrão — e `$XDG_DATA_HOME` vem **antes** de todo `XDG_DATA_DIRS`, inclusive do
`~/.local/share/flatpak/exports/share` de onde sai o applet de hoje. O nosso `Exec=`
vence sem que ninguém encoste na ordem dos applets.

### A abstenção, e ela é a parte que importa

**`plugins_wings` e `plugins_center` continuam da Aurora, e o módulo `midia` não os toca.
Nem uma vez.** Está escrito aqui porque a tentação é real: parece natural "registrar" o
applet novo plantando um token na asa. Dois motivos medidos dizem que não:

1. **Não é preciso.** O painel casa por basename; a sombra já vence.
2. **É perigoso.** A asa direita da dock tem **DOIS** applets —
   `com.github.DiegoMMR.CosmicExtAppletNowPlaying` **e**
   `com.system76.CosmicAppletStatusArea`. Um script que assumisse "a asa é uma lista de
   um" apagaria a Status Area de quem usa.

### O buraco que o fail-safe existe para tapar

Sombra presente + binário ausente = **nenhum** applet na dock. O painel consome o slot no
primeiro acerto de basename e **nunca chega a tentar** o export do flatpak — então o
resultado não é "volta ao applet de fábrica", é um vazio. Acontece de graça: um `rm`
errado, um limpador de disco, um build interrompido. Por isso o `midia.sh --aplicar`
**remove a sombra** quando o binário some, e o `--reverter` apaga **a sombra antes do
binário**. É um `rm` de arquivo nosso, sem sudo e sem rede — o doctor das 05:00 pode
fazer, e o efeito é ela voltar sozinha ao flatpak que funciona.

### Onde ele mora, e quem o pôs lá

Em 24/08/2026, **a pedido de quem usa, e pela mão de quem usa na decisão**, o applet saiu da asa
direita da dock e foi para a asa direita da topbar, **imediatamente antes do
`com.system76.CosmicAppletAudio`** — o applet de Som, que é quem já desenha os
botões de faixa anterior, pausa e próxima faixa ali. O `plugins_wings` das duas
barras foi editado **uma vez, à mão**, com backup em
`~/.local/state/meowsystem/backups/painel-2026-08-24/`.

Isso **não** revoga a abstenção acima: o módulo `midia` continua sem escrever
uma linha em `plugins_{wings,center}`, nem no `install.sh`, nem no doctor, nem
no `--reverter`. Uma coisa é a pessoa mover o próprio applet; outra é um script
que roda às 05:00 achar que sabe a ordem certa.

Consequência registrada: com o Som ao lado, os botões de faixa anterior, pausa e
próxima faixa do próprio Now Playing viram duplicata visual. Por isso
`MIDIA_CONTROLES` nasce `"nao"`.

Os três botões estão escritos por extenso, e isso é decisão de 21/09/2026: os
glifos `U+23EE`/`U+23F8`/`U+23ED` são lidos como emoji pelo sanitizador de
commit e apagados de todo arquivo preparado — inclusive destas duas linhas, que
ninguém tinha tocado. Medido três vezes; replantá-los é perder a frase na
quarta. Nome por extenso é texto que dura.

### O que continua não sendo nosso

O flatpak `com.github.DiegoMMR.CosmicExtAppletNowPlaying` **não é desinstalado nem
mascarado**. Ele segue atualizando e reescrevendo um export que ninguém lê — e é dele que
vem o ícone `Icon=` da sombra. Um `flatpak update` neste applet é um **não-evento** para
nós: sem `mask`, sem `override`, sem unidade `.path` vigiando.

E o `cosmic-panel` **não é reiniciado** para antecipar a troca. A issue #13 do upstream
(`xdg_popup: tried to grab after being mapped`) derruba topbar e dock juntas e exige
`killall -9` — é o painel fantasma que este projeto já perseguiu uma vez. O applet novo
sobe no **próximo login**, e cinco minutos de antecipação não pagam esse risco.

---

## A opacidade do painel e a escala da tela saíram da nossa mão (17/08/2026)

Duas linhas da tabela acima trocaram de dono no mesmo dia, pelo mesmo motivo, e ele vale
como regra geral: **onde a GUI do COSMIC tem um controle, o valor é dela.**

**A opacidade.** O `vidro.sh` escrevia `CosmicPanel.{Panel,Dock}/v1/opacity` em toda
passagem, com 0.19 e 0.26. Aquele arquivo é exatamente o que o slider *Ajustes → Área de
trabalho → Painel → "Opacidade do fundo"* escreve. Com o `meow-doctor.timer` rodando
`fix_vidro` todo dia, o número escolhido na GUI voltava para o nosso sem que nada dissesse
por quê — e a GUI ainda exibia 19 e 26 como se fossem a escolha de quem usa. Era a terceira
travessia da mesma fronteira no mesmo arquivo (05/08: unificar em 0.05; 10/08: rederivar
para 0.19/0.26); as duas primeiras corrigiram o **número**, esta mudou o **dono**.

Hoje `VIDRO_OPACIDADE_PAINEL` e `VIDRO_OPACIDADE_DOCK` nascem **vazias** no `meow.conf`, e
vazio quer dizer "não toque". Preencher volta a impor — a ponte do conf até o script foi
fechada no mesmo dia, então preencher agora tem efeito de verdade (antes as chaves eram
lidas por `bin/meow` e morriam lá). O que continua nosso é `keep_style_on_maximize`, que a
GUI não tem: se ninguém a escrever, ela se perde em silêncio.

**A escala.** O pedido foi "aumentar o tamanho universal das fontes". Não existe chave de
tamanho de fonte no COSMIC — `interface_font` não tem campo de tamanho, `interface_density`
mexe só em espaçamento, o `default_text_size` da libcosmic é 14.0 constante no código e
`COSMIC_SCALE` não alcança o painel. Sobra a escala da saída, que é *Ajustes → Telas →
Escala*. O `scripts/escala.sh` a aplica pelo `cosmic-randr` (nunca editando o `outputs.ron`,
que é estado do compositor e é reescrito por cima), e **só pelo `install.sh`**: pôr isto no
doctor repetiria, com outro nome, o defeito que a opacidade acabou de custar.

---

## O alpha que o Aurora escreve NÃO chega no painel (23/08/2026)

A queixa foi "a opacidade da barra não é respeitada". A suspeita óbvia, e a que
esta tabela alimentava, era travessia de fronteira: o `aurora-vidro-maximizado.py`
escreve o alpha do `base:` de `background` (hoje `0x8A`), esse número é quase igual ao
`alpha_map[extremely_high_2]` do tema em uso (0,54), e daí para "o Aurora está atropelando
o slider" é um pulo. **A medição derrubou isso**, e vale registrar para ninguém refazer
o caminho.

**O painel descarta o alpha do tema.** O `bg_color` do `cosmic-panel` monta a cor com os
canais de cor do tema e um alpha calculado à parte:

```rust
pub fn bg_color(&self, mut alpha: f32, opaque: bool) -> [f32; 4] {
    if self.theme.cosmic().frosted_panel && self.blur_enabled {
        alpha *= self.theme.cosmic().alpha_map.blurred_alpha(self.theme.cosmic().frosted);
    }
    if opaque { alpha = 1.; }
    self.color_override.unwrap_or_else(|| {
        let c = self.theme.cosmic().bg_color();
        [c.red, c.green, c.blue, alpha]     // <- só R,G,B. O c.alpha morre aqui.
    })
}
```

O `0x8A` que o Aurora grava governa **janela**, não barra. O 0,54 que aparece na conta do
painel vem do `alpha_map[frosted]`, que é outro caminho — a coincidência dos dois números
existe porque os dois descendem do mesmo `frosted` que quem usa escolheu, não porque um alimente
o outro.

**E o Aurora não impõe número nenhum.** Ele copia o alpha de `transparent_X.base` para
`X.base` — propaga a escolha de quem usa em "Espessura do efeito fosco"/"Opacidade do vidro" em
vez de fixar um valor. O `aurora-vidro-maximizado.path` está `active`/`enabled` e reaplica
assim que o tema muda, mas o que ele reaplica é o que quem usa escolheu. **Nada a mudar
do lado do Aurora**, e a linha da tabela continua dele.

**O que realmente apaga o controle de quem usa é nosso.** Medido no pixel: com
`keep_style_on_maximize = false` e uma janela maximizada, `opacity` é ignorada —
`0.19` e `0.95` desenharam capturas pixel-idênticas, a barra chapada em `#313244`.
O upstream faz `let effective_maximized = maximized && !config.keep_style_on_maximize;`
e, quando ele vale, `config.maximize()` força `self.opacity = 1.0`. Ou seja: a chave que
esta tabela já dava ao Meow ("a GUI não tem controle para ela") é a **pré-condição** para
o slider da GUI funcionar. Perder essa chave em silêncio não estraga só o vidro ao
maximizar — mata a "Opacidade do fundo" inteira. O `vidro.sh` passou a avisar; ele
continua sem escrever `opacity`, que segue sendo de quem usa.

Detalhe das três medições, com os números: cabeçalho do `scripts/vidro.sh`, bloco de
23/08/2026.

---

## Dois hooks de apt na mesma máquina, e por que isso não é briga (14/08/2026)

A `/etc/apt/apt.conf.d` passou a ter dois `DPkg::Post-Invoke`: o
`99-ritual-aurora-self-heal`, que já existia, e o `99-meow-lancador`, novo. O apt roda
os dois em ordem alfabética, um de cada vez — o Meow primeiro. **Não há corrida**, e não
há sobreposição de alvo.

**Por que o segundo precisou existir.** O `ocultar_apps.sh` marca `NoDisplay=true` em
`.desktop` que vieram do apt, e um `apt upgrade` do pacote devolve o original. Está
medido: o `google-chrome-stable` atualizou em **10/08/2026 19:27**, devolveu o
`google-chrome.desktop` sem a chave, e apareceram dois Chrome no lançador em **14/08**.
Quatro dias com a duplicata de volta e nada na máquina para reaplicar.

**Por que não pelo `meow doctor`.** `ocultar` está em `SEM_CONSERTO` porque o conserto
usa sudo e o doctor nunca usa — um prompt de senha às 5h penduraria o
`meow-doctor.service` num terminal que ninguém está olhando. Essa decisão não mudou.
[Desde 08/09/2026, com a ponte root (ver «A ponte root», abaixo), o doctor conserta o
`ocultar` pela ponte, sem senha: ele só volta ao `SEM_CONSERTO` numa máquina em que a
ponte não está de pé.]
O que faltava era um gatilho que **já fosse root**, e o apt é exatamente isso: ele é ao
mesmo tempo a causa do estrago e um contexto privilegiado.

**Por que isso não contraria o "nenhum hook de apt" do `meow-doctor.service`.** Aquele
cabeçalho recusa pendurar um segundo **reparador completo** no evento do Aurora — dois
programas mexendo em tema e ícone ao mesmo tempo, com dois avisos que podem se
contradizer na tela de quem usa. O `99-meow-lancador` não é reparador: chama um script, cobre um
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
cópia antiga do home, com guarda por `cmp` para não apagar edição feita à mão.

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

Ligar de volta é decisão de quem usa: `systemctl --user enable --now aurora-painel-fantasma.timer`.

---

## Como os dois se falam

O Aurora **confere** o visual uma vez por ciclo e nunca conserta: ele roda `meow doctor`
(que é read-only) e imprime **uma linha** de resumo. O `--consertar` fica de fora de
propósito — ele pede sudo em algumas etapas e decide sobre o gosto de quem usa, o que não cabe a
um self-heal que roda de hora em hora. Uma divergência que quem usa escolheu (trocar o
papel de parede pela GUI) não pode virar 24 parágrafos por dia no log.

Do lado do Meow, a fronteira está em `lib/comum.sh` (TRAVA 1) e no
`meow.conf` (`vizinhos.conf`). Do lado do Aurora, nas instruções do projeto em `~/.config/zsh/` e nos
comentários `v3.56` do `ritual-aurora-self-heal.sh`.

Quem mudar um dos lados, muda os dois — este arquivo é o que sobra quando ninguém lembra
por quê.

---

## O cursor tem dois donos na tela, e nenhum deles era nós (25/08/2026)

A Sprint P abriu uma pergunta de fronteira que a tabela não respondia: a linha
`gsettings / dconf` dava tudo à Aurora, mas nomeava **`button-layout`**, não a
chave inteira. Antes de escrever, foi medido — e a resposta é limpa nos dois
sentidos.

**A Aurora não escreve `cursor-theme`.** Todo `gsettings set` vivo do
repositório do Ritual mira `org.gnome.desktop.wm.preferences`:

```
grep -rn 'gsettings set' ~/.config/zsh/scripts/
  aurora-button-layout.service:19   ...wm.preferences button-layout
  ritual-aurora-self-heal.sh:1833   ...wm.preferences button-layout
```

A única menção a `cursor-theme` no repositório do Ritual está em
`functions/restaurar.zsh:587`, dentro do comando **manual**
`sistema_restaurar <manifesto.json>` — sem timer, sem self-heal, e sem
manifesto no disco (`~/.config/andromeda/manifesto/` não existe). Mesmo rodado
à mão ele não dispara aqui: `__restaurar_capturar_tema()` tem saída antecipada
para COSMIC e grava cursor vazio, e o lado escritor é guardado por
`[[ -n "$cursor" ]]`.

A assimetria que fica: **Aurora manda em `wm.preferences`, Meow manda em
`desktop.interface`** — onde `icon-theme` e `gtk-theme` já eram nossos pela
mesma tabela.

### E o achado que muda o desenho: são DOIS cursores, não um

O `gsettings` sozinho não teria resolvido nada visível no desktop, e isso levou
uma medição para descobrir:

```
strings /usr/bin/cosmic-comp | grep -c cursor-theme   ->  0
grep -rl cursor-theme /usr/bin/                       ->  nenhum arquivo
```

O compositor **não lê o gsettings para cursor**. Ele usa a crate `xcursor` com
`XCURSOR_THEME`, que está **vazia** no `/proc/<pid>/environ` do processo vivo —
e então cai no tema `default`, que em `/usr/share/icons/default/index.theme`
declara `Inherits=Adwaita`. **O ponteiro do desktop era Adwaita, corpo
`#000000`**, enquanto o `Pop` que o `gsettings get` devolvia governava só as
janelas GTK.

Por isso o `cursor.sh` puxa duas alavancas: a chave do gsettings (GTK, vale na
hora) e `~/.icons/default/index.theme` (compositor, vale no próximo login).
`~/.icons` vem antes de `/usr/share/icons` no caminho de busca, então sombreia
o `default` do sistema sem apagá-lo — é o mesmo movimento que o `som.sh` faz
com o tema `freedesktop`, e não fere a TRAVA 1.

**O `'Pop'` nunca foi valor gravado.** `dconf read` devolve vazio; o `Pop` vem
de `50_pop-desktop.gschema.override:33`. Por isso `cursor.sh remover` faz
`gsettings reset` e **não** `set 'Pop'` — repor à mão deixaria valor onde não
havia nenhum, e isso é uma travessia de fronteira silenciosa com outro nome.

---

## O patch nasce no Meow e é aplicado pela Aurora (30/08/2026)

Três linhas novas na tabela, e as três descrevem o mesmo caminho de mão única: o
`.patch` nasce aqui, a Aurora o aplica, e o Meow volta a olhar — sem nunca
escrever de novo.

**Por que a fronteira precisou de nome.** O
`patches/cosmic-comp-raio-clampado.patch` passou **semanas** neste repositório,
com o README dizendo que estava em produção, sem nunca entrar em binário nenhum:
o `aurora-cosmic-comp-ws.sh` aplicava UM `.patch` só, por caminho literal, e nada
no mundo comparava a lista dele com a nossa. Não foi descuido de ninguém — foi
uma fronteira sem contrato. Um patch que existe de um lado e não está declarado
do outro é um patch que **não acontece**, e falha calado.

**O contrato, e é o mínimo que serve.** A Aurora grava
`/var/lib/aurora/cosmic-comp-patches.estado` (644, dono root, **legível pela conta de quem usa
sem sudo**) toda vez que alguém escreve `/usr/bin/cosmic-comp`, com uma linha por
patch: `<req|opt> <marcador> <arquivo.patch> <presente|ausente>`. A série vive em
`/usr/local/share/aurora/patches.d/series`, com `<classe> <arquivo.patch>
<marcador-base>`. O Meow lê os dois, não escreve nenhum, e a leitura da cópia em
`~/.config/zsh/patches/patches.d/` é `md5sum` e `[ -f ]` — a TRAVA 1 continua
inteira.

**O que o `meow doctor` passou a dizer** (linha `patches`,
`scripts/compositor_patches.sh`): se todo marcador declarado está no binário do
disco **e** no `/proc/<pid>/exe` da sessão viva, se a `versao=` do `.estado`
ainda casa com o `dpkg-query`, e se todo `.patch` de `patches/` está declarado na
série. A pergunta é sobre o **processo**, não sobre o arquivo — um `--build` já
feito e uma sessão que não relogou são um estado normal, e mandar recompilar por
causa dele seria cobrar 4 minutos de `cargo` por um logout.

**E ele não conserta nada, de propósito.** `patches` está em `SEM_CONSERTO`: o
conserto é recompilar o `cosmic-comp` (~4 min, `sudo install` em `/usr/bin`), e o
doctor nunca usa sudo, nunca baixa e nunca compila. O comando era de quem usa:
`aurora-cosmic-comp-ws.sh --build`. Desde 24/09/2026 (P39) o build é daqui, e o
comando que a linha `patches` manda rodar é `meow compositor`. Um build de 4 minutos disparado pelo timer
das 05:00 seria pior que o defeito que ele corrige — é a mesma decisão que já
tinha posto `cursor` (baixa da rede), `midiabin` e `leiturabin` (compilam) nessa lista.

[**Isto mudou de lado entre 09 e 16/10/2026.** «O doctor não tem que avisar nada. Tem
que corrigir» (pedido de 09/10). Com o build no escopo de quem usa (P76: sem `sudo`, num
diretório por versão, com o shim escolhendo a cada sessão), compilar deixou de ser
perigoso para a tela de login, e `patches`, `midiabin` e `leiturabin` saíram do
`SEM_CONSERTO` (P75, P76). O `--consertar` chama a mesma função que roda depois do apt
e no login, o `scripts/garantir_builds.sh`, em segundo plano e com prioridade mínima, e a
linha diz «construindo» até o build ficar pronto (P81). Ver o `docs/MANUTENCAO.md`.
Hoje ficam sem conserto só `ponte`, `convertidos` e `heroictema`, e, numa máquina sem a
ponte, os que precisam dela.]

**A lacuna que fica escrita para não ser esquecida.** O patch de night light do
`aurora-night-light.py` é patch **binário**: ele reescreve o bloco
`if (color_mode == 1.0)` do shader GLSL embutido e deixa como rastro um
comentário `// NIGHT LIGHT (Aurora)` dentro do shader — conferido no binário de
hoje, está lá —, não um marcador `AURORA-*` de fonte. Ele não está na série e
**não é conferido** por esta linha do doctor. Cobri-lo exige outro verificador,
com outro critério; fingir que este o cobre seria pior que a lacuna.

---

## As chaves `leitura_*` têm dois escritores, e isso é o desenho (30/08/2026)

Três linhas novas na tabela, e elas descrevem a primeira fronteira deste projeto que
**não é entre o Meow e a Aurora** — é entre o Meow e **quem usa**, dentro do mesmo diretório
de configuração.

**As cinco chaves, e quem toca em cada uma.** Em
`~/.config/cosmic/com.system76.CosmicComp/v1/`:

| chave | escreve | lê |
|---|---|---|
| `leitura_temperatura` (Kelvin, 0 = desligado) | `scripts/leitura.sh` **e** o applet | o `cosmic-comp` recompilado, por quadro |
| `leitura_textura` (0.0–1.0, 0 = desligado) | `scripts/leitura.sh` **e** o applet | idem |
| `leitura_agenda` (bool) | **só** o applet | `scripts/leitura.sh` |
| `leitura_hora_inicio` | **só** o applet | `scripts/leitura.sh` |
| `leitura_hora_fim` | **só** o applet | `scripts/leitura.sh` |

**Por que os dois primeiros podem ter dois escritores sem virar briga.** Porque as três
últimas existem. O applet da topbar tem um interruptor `Agendar`; enquanto ele estiver
ligado, o relógio manda e os sliders seguem o disco. Quando quem usa o desliga, o
`leitura.sh` **para de escrever inteiramente** — não escreve nem `0` — e devolve 4, que o
`meow doctor` pinta `--` ("escolha de quem usa"). É a mesma forma da `WALLPAPER_FONTES_PERMITIDAS`:
uma lista DITA pela qual a escolha de quem usa é respeitada para sempre, em vez de um
auto-reparo que a desfaz de minuto em minuto.

**O horário mudou de dono na noite de 29/08, e a etapa 2 foi escrita depois disso.** O
plano original punha `LEITURA_HORARIO_INICIO`/`_FIM` no `meow.conf`; a decisão de quem usa
("determinar a faixa horária eu mesma, pela interface") moveu a hora para o
`cosmic-config`. As duas chaves do `meow.conf` continuam existindo como **padrão
declarado** para enquanto o applet não tiver gravado hora nenhuma — e o `meow leitura
estado` diz qual das duas fontes está mandando, sempre, em vez de deixar isso implícito.

**O applet existe desde 30/08/2026, e ele NÃO cria as chaves ao ser instalado.** Ele lê o
disco no arranque e só escreve o que quem usa mexe. Então "applet ausente" e "applet instalado
e nunca tocado" são o mesmo estado para o `leitura.sh`, e nos dois vale o padrão do
`meow.conf` — o que também quer dizer que instalar o applet **não muda nada** por si só.

**E existe um terceiro estado, desde 31/08/2026: UMA PONTA SÓ.** `HoraInicio` e
`HoraFim` são dois braços separados do `update()` do applet, cada um chamando o seu
`set_`; arrastar só o slider de início grava `leitura_hora_inicio` e mais nada, enquanto o
popup continua mostrando o Default no fim — que é o mesmo número do `meow.conf`, e por
isso a divergência não aparece na tela. Até 31/08 o `leitura.sh` exigia AS DUAS chaves e,
faltando uma, jogava fora a outra: medido naquele dia com `leitura_hora_inicio="20:00"` no
disco e `leitura_hora_fim` ausente, o applet dizia "das 20:00 às 07:00" e o script
esquentava a tela às 19:00, calado. Agora **cada ponta é resolvida sozinha** — chave do
applet quando existe e é legível, padrão do `meow.conf` quando não —, o `LEITURA_FONTE`
tem três valores (`applet`, `padrao`, `misto`) em vez de dois, e o `meow leitura estado`
diz **qual ponta veio de onde**. A janela resolvida passa a ser exatamente a que o applet
desenha na tela de quem usa.

**Dois controles saíram do popup em 31/08/2026, e os dois por motivo medido.** O botão
**"Restaurar padrões"** foi removido: o braço dele era, linha por linha, o `else` do
interruptor `Modo de leitura` (`lembra_ponto()` e os dois zeros), com um nome que prometia
devolver os 3500 K e os 35% do padrão. Dois controles com o mesmo efeito e nomes
diferentes não dão duas saídas — ensinam a duvidar das duas; o interruptor é o desfazer, e
é o único. E a **linha de horário some** quando o `Agendar` está desligado, em vez de
ficar clicável sem efeito: com `leitura_agenda = false` o `leitura.sh` devolve 4 e não
escreve chave nenhuma, então mexer no horário ali não mudava nada. Este rev do libcosmic
não tem estado desabilitado para `spin_button` — sumir foi o único desenho honesto
disponível.

**As três peças do applet falham separado, e por isso o `estado` mostra as três.** O
binário (`~/.local/bin/meow-applet-leitura`), a sombra `.desktop` e a linha
`"com.meowsystem.AppletLeitura"` no `plugins_wings` da topbar. As duas primeiras são do
Meow e o `leitura_build.sh` as instala **nesta ordem** — binário antes da sombra, sempre,
porque sombra sem binário deixa um slot vazio na barra. A terceira é da Aurora, é escrita
**à mão**; nenhum script deste projeto a toca, e
quando ela falta o `leitura_build.sh --conferir` **avisa** — nunca acusa divergência, que é
o que faria uma linha amarela eterna que o `--consertar` não pode apagar.

**E `plugins_wings` NÃO é inerte — medido em 30/08/2026, e é a correção mais importante
desta página.** Este projeto vinha repetindo que a chave "só vale no próximo início de
sessão", e usando isso como razão para tratar a escrita como inofensiva. Não é: o
`cosmic-panel` mantém um watch de **inotify** no diretório
`~/.config/cosmic/com.system76.CosmicPanel.Panel/v1` (visto em `/proc/<pid>/fdinfo`, pelo
inode do diretório), e `plugins_wings` está na lista `must_recreate` do
`space_container.rs` do painel. Escrever a linha às 05:43 **recriou o espaço da topbar na
hora**: o processo do painel manteve o mesmo PID e **todos** os applets renasceram com PIDs
novos — o nosso apareceu na barra sem logout nenhum. É a mesma classe de evento que já
apagou topbar e dock juntas nesta máquina. Uma escrita à mão é barata; em rajada, dentro de
um `install.sh` ou de um timer, seria a fábrica do painel fantasma. Continua fora de todo
script, agora por um motivo medido em vez de um motivo suposto.

**A luz quente da Aurora foi aposentada, e a medição é de 31/08/2026.** Este parágrafo
dizia que quem esquentava a tela era um patch **binário** no shader do `cosmic-comp`,
e que aposentá-lo era a etapa 4 do plano. A etapa foi feita. Medido:

```
strings -a /usr/bin/cosmic-comp | grep -o 'AURORA-[A-Z0-9.-]*' | sort -u
    AURORA-COSMIC-RADIUS-PATCH-1
    AURORA-COSMIC-WS-PATCH-3.67
    AURORA-READING-MODE-1
md5sum /usr/bin/cosmic-comp /var/lib/aurora/cosmic-comp-…-5c93094.aurora-ws
    244a901d72ae8af1edf495b7bc31f7f4  (idêntico nos dois)
```

Três patches de FONTE e nenhum de night light — e o binário instalado é byte a byte o que
saiu do build de 30/08 04:59, ou seja, **nada foi re-patchado por cima dele depois**, que é
como o patch binário entrava. `/var/lib/aurora/night-light-temp` continua no disco com
`3500`, mas é um arquivo de 14/07 que ninguém mais lê para pintar; não há unidade de night
light ativa. O `leitura.sh` ainda imprime aquele número no `estado` com a frase antiga
("patch BINÁRIO, outro dono") — o comando não mente sobre o arquivo, mas a frase envelheceu
com esta seção.

**A pergunta que o `estado` responde e que ninguém mais responde.** Ele separa o binário
do **disco** (`grep AURORA-READING-MODE /usr/bin/cosmic-comp`) do binário da **sessão
viva** (`/proc/<pid>/exe`). São coisas diferentes, e a diferença é a explicação inteira de
"escrevi a chave e não aconteceu nada": um `--build` já feito e um logout ainda não dado.
**Desde 30/08/2026 as duas respostas são "sim"** — medido em 31/08, com a sessão de quem usa de
pé, `1` nos dois `grep -c`. Escrever a chave deixou de ser inofensivo-e-inerte e passou a
valer na tela na hora. O dia em que um `apt upgrade` trocar o compositor as respostas
voltam a divergir, e é para esse dia que as duas linhas existem.

---

---

## O `logo.source` do fastfetch: a única linha que o Meow escreve num arquivo da Aurora

> **Esta seção é história desde 24/09/2026 (P44).** O `~/.config/fastfetch`
> deixou de ser symlink: é um diretório do MeowSystem, com o mesmo conteúdo, e o
> Spellbook parou de versioná-lo. As quatro guardas abaixo protegiam um arquivo
> de outro repositório; o arquivo agora é nosso, e ficam como o registro de por
> que a escrita foi, por três semanas, cirúrgica. Ver «O doctor só lê, e o que
> era tema termina de sair do Spellbook», mais abaixo.

`~/.config/fastfetch` é symlink para `~/.config/zsh/fastfetch/`, e `~/.config/zsh`
está no `vizinhos.conf` — a TRAVA 1 do `lib/comum.sh` recusa escrever ali, e a
recusa acontece **depois** do `readlink -m`, então o symlink não a contorna.

**Até 31/08/2026** o `scripts/fastfetch_logo.sh` só LIA aquele arquivo: gerava o
`.ansi` em território nosso, conferia se o `logo.source` apontava para ele, e
saía **4** imprimindo o patch para quem usa colar à mão.

**Mudou em 01/09/2026**, e por três razões, nesta ordem:

1. O pedido foi que tudo fosse *"idempotente e autoajustável de forma que sobreviva
   sempre"* — e depois, explicitamente: *"pode alterar tudo a nível de sistema,
   incluindo no aurora"*.
2. O gato do fastfetch passou a seguir o relógio. Sem a troca da linha, o
   terminal ficaria com a Coquinha das 18h às 7h **todo dia, para sempre**, e o
   script diria "gerei o Mimir" enquanto a tela mostra a Coquinha. Aviso que se
   repete todo dia é aviso que se aprende a ignorar.
3. A direção já estava autorizada desde 05/08/2026: *"o Andromeda pode ser
   corrigido pelo MeowSystem"*.

**As quatro guardas**, que são o que separa isto de furar a TRAVA 1:

1. **Uma linha, nunca o arquivo.** A escrita é cirúrgica — troca `logo.source`
   (e `logo.type`, se estiver errado) e mais nada. Não reserializa o JSON: um
   `json.dump` mataria os comentários (é JSONC), a ordem das chaves e a
   indentação de quem usa, e o arquivo vive num repositório com auto-commit a cada
   10 min — o diff seria o arquivo inteiro reescrito por causa de um enfeite.
   O `_ffl_ler_conf` conta os módulos com `key` própria (os 19 em português)
   justamente para acusar o dia em que alguém colar por cima do arquivo todo.
2. **Backup antes, sempre**, em `~/.local/state/meowsystem/backups/<carimbo>-vizinho/`.
   Falhar o backup **aborta** a escrita.
3. **Em voz alta.** Nenhuma escrita acontece sem uma linha na tela dizendo qual
   arquivo de qual vizinho foi tocado, e onde ficou o backup.
4. **`FASTFETCH_LOGO_CONF="nao"`** volta ao comportamento antigo (só imprime o
   patch e sai 4), sem editar script nenhum.

**E o self-heal não disputa esta linha** — medido em 01/09/2026:
`grep -n fastfetch /usr/local/sbin/ritual-aurora-self-heal.sh` devolve três
linhas, todas sobre o **symlink** `~/.config/fastfetch -> ~/.config/zsh/fastfetch`
(self-heal:1585-1587). O **conteúdo** do `config.jsonc` não é escrito por ele em
ponto nenhum. Sem essa medição isto seria ping-pong de hora em hora — os dois
donos da mesma linha, que é o defeito que este projeto mais persegue.

## As áreas de trabalho passaram para o Meow — 07/09/2026

A tabela dava o `pinned_workspaces` ao Ritual da Aurora, e por uma razão boa: o
`aurora-cosmic-workspaces.py` roda a cada ciclo do self-heal (1 h) e **força** o
`name` dos alfinetes da lista dele. Enquanto os dois escreviam o mesmo arquivo,
uma renomeação feita daqui voltava atrás sozinha em até uma hora — **depois** de
ter funcionado por um login, que é o pior sintoma que um ajuste pode ter.

O pedido foi a seção no painel ("não temos a seção pra setar os dois ambientes de
trabalho tipo o Meow e o OS"), eu mostrei o custo de respeitar a fronteira — a
seção existiria só para olhar — e a decisão foi mover a fronteira.

**O script vizinho não foi editado.** Ele já previa a cessão e dizia onde:

> OPT-OUT: se `~/.config/cosmic/.aurora-workspaces-off` existir, sai sem tocar em
> nada. Sentinela em arquivo separado, porque o COSMIC reserializa o
> `pinned_workspaces` sozinho e apagaria qualquer marcador que morasse dentro dele.

Usar a porta que o vizinho deixou aberta é melhor que arrombar a parede: o script
dele continua intacto e atualizável, e a cessão é reversível apagando um arquivo.
A sentinela leva a data e o porquê por dentro, para que quem a encontre daqui a
seis meses saiba que ela é decisão, e não sujeira.

**Medido depois de assumir:** `python3 aurora-cosmic-workspaces.py` responde
`OK opt-out presente — nada a fazer`, rc 0, e o `pinned_workspaces` fica byte a
byte como estava.

**O que continua NÃO sendo nosso:** o `tiling_enabled` tem um segundo dono dentro
deste projeto — o `scripts/janelas.sh`, que grava o campo em todas as entradas de
uma vez a partir de `JANELAS_TILING`, e que o `meow doctor` chama todo dia. Por
isso `AREAS_ENCAIXE` nasce vazio e o `areas.sh` recusa (rc 4) quando as duas
chaves discordam, dizendo qual esvaziar. Gravar aqui e ver achatar amanhã seria o
mesmo defeito, com o vizinho de dentro de casa.


---

## A ponte root, e por que ela não é `NOPASSWD: ALL` (08/09/2026)

Pedido de quem usa: *"não conseguimos de alguma forma usar sudo só na instalar e criar um
perfil naquele conf.d ... aquele que só preciso uma vez e fica lá registrado pra
sempre?"* O incômodo era medível: `meow doctor --consertar` recusava **três** itens com
a mesma frase — "o conserto usa sudo, e o doctor não usa" — e os botões de senha do
painel não tinham como pedir senha nenhuma, porque o painel roda **sem terminal**.

### O que existe agora

| arquivo | modo | o que é |
|---|---|---|
| `/usr/local/lib/meowsystem/ponte_root.sh` | `0755 root:root` | o braço root: um conjunto **fechado** de verbos, com os destinos cravados dentro |
| `/usr/local/lib/meowsystem/perfil` | `0644 root:root` | `raiz`, `usuaria` e `lar` — escrito **por root**, para o chamador não escolher a origem |
| `/etc/sudoers.d/49-meowsystem-ponte` | `0440 root:root` | libera **só** os verbos da ponte, sem senha |

### A regra não tem um único curinga, e isso é o desenho

Não existe regra estreita para `install`: `NOPASSWD: /usr/bin/install -m 644 * *` é
`NOPASSWD: ALL` com outro nome, porque o segundo `*` é qualquer destino e escrever
qualquer arquivo como root **é** ser root.

Então **nenhum verbo da ponte aceita argumento**. O nome do arquivo e o conteúdo entram
por **stdin** — a mesma disciplina que a ponte de Bluetooth do Hefesto documenta ao lado
(*"o nome novo do adaptador entra pelo STDIN, não por argv, justamente para que não sobre
argumento livre a casar"*). Medido em 08/09/2026, com o cache do sudo apagado:

```
sudo -n true                          -> "uma senha é necessária"
sudo -n .../ponte_root.sh estado      -> passa
sudo -n .../ponte_root.sh rm          -> "uma senha é necessária"   (verbo fora da regra)
sudo -n .../ponte_root.sh desktop x   -> "uma senha é necessária"   (a regra não tem curinga)
```

### Os doze verbos, e o que cada um alcança

`desktop` e `desktop-banco` (marcar `.desktop` em `/usr/share/applications`, e só os que
**já existem** — ela edita, não cria) · `greeter-ver` e `greeter-aplicar` (a tela de
login) · `apt-hook-instalar` e `apt-hook-remover` · `completion-instalar` e
`completion-remover` (a completion do `meow` para o zsh, lida uma vez para um temporário
e conferida antes de instalar) · `flatpak-global-limpar` (tira do override global do Flatpak só as chaves `ICON_THEME`,
`XCURSOR_THEME` e `GTK_THEME` que apontam para tema que não existe; o dado entra por stdin e
o resto do arquivo fica) · `atualizar` e `limpar` (`full-upgrade` dos repositórios
**já configurados**; a ponte não acrescenta fonte e não roda `.deb`) · `pacotes` (desde
09/10/2026, P75: instala os pacotes de que o projeto depende, pelo nome que entra por
stdin, e só os da lista **literal** que mora dentro da ponte instalada — `librsvg2-bin`,
`imagemagick`, `libgtk-3-bin`, `python3`, `git`, `btop`, `bat`, `papirus-icon-theme`,
`python3-numpy`, `curl`, `xz-utils`, `unzip` e `pop-fonts`; um nome fora dela derruba o
verbo inteiro antes de qualquer `apt`). A regra do sudo libera ainda o `estado`, que só lê.

Até 09/10/2026 eram oito; a P75 e a P82 trouxeram o `pacotes` e os quatro pacotes que o
`instalar_fontes.sh` pedia sem ter a quem pedir. O `tests/doctor-veredito.sh` cobra que a
lista da ponte e a do `etapa_pacotes` do `install.sh` sejam a mesma.

Cada uso privilegiado vai para o journal (`journalctl -t meowsystem-ponte`).

### O que ela custa, dito sem enfeite

Quem puder rodar comando com a conta de quem usa a máquina passa a poder, **sem senha**,
fazer essas coisas: marcar `.desktop` que já existem, vestir a tela de login, pôr ou tirar
o hook do apt e a completion, atualizar pelos repositórios já configurados e instalar um
dos treze pacotes da lista. É muito menos que root, por uma margem larga, e não é nada. `PONTE_ROOT="nao"`
no `meow.conf` faz a etapa **remover** a ponte e a regra na passagem seguinte — testado
nos dois sentidos em 08/09/2026, e o sudo volta a ser pedido no terminal.

### O que a ponte NÃO faz, de propósito

Ela **não se instala nem se atualiza**. Trocar o arquivo em `/usr/local/lib` e a regra em
`/etc/sudoers.d` continua pedindo a senha, no `install.sh` — uma ponte que pudesse regravar
a si mesma seria uma ponte que qualquer coisa rodando como ela reescreve para fazer outra
coisa. Por isso `ponte` é o único item que fica **sempre** em `SEM_CONSERTO` no doctor: o
auto-reparo por relógio não escreve em `/etc/sudoers.d`.

`visudo -c` roda **antes** de o arquivo entrar em `/etc/sudoers.d`, e isso não é zelo: um
arquivo inválido ali derruba o `sudo` da máquina inteira, para todo mundo, e o conserto
pede um root que já não se consegue.


## O vidro da janela e o painel fantasma passaram para o Meow — 19/09/2026

Duas peças que moravam na Aurora vieram para cá, e as duas pelo mesmo motivo: o
**dono da queixa** é o Meow. Quem liga `VIDRO_AO_MAXIMIZAR` está pedindo vidro ao
maximizar — não "vidro na barra ao maximizar", com a janela ficando opaca ao
lado. E quem diz "a barra sumiu" está falando de painel, que é nosso desde
sempre.

### O vidro da janela

A Aurora resolvia com `aurora-vidro-maximizado.py`: copiar o alpha de
`transparent_X.base` para `X.base`, em cada par que o tema tivesse. A linha da
tabela dizia *"já funciona, não mexer"* — e estava certa em 01/09.

**O que mudou, e não fomos nós:** o COSMIC ganhou a chave nativa
`frosted_maximized_apps` (cosmic-panel#457). Descobrimos porque o script da
Aurora tem um `avisar_se_nativo()` que existe exatamente para isso, e ele
disparou na primeira execução aqui:

```
!!   o COSMIC criou frosted_maximized_apps
     a opção nativa (cosmic-panel#457) parece ter chegado —
     esta correção pode ser aposentada em favor da de fábrica
```

Um script que sabe anunciar a própria aposentadoria vale mais que um que só
funciona. Sem esse aviso teríamos aplicado o remendo por cima de uma chave de
fábrica, e os dois estariam mexendo no mesmo pixel por caminhos diferentes.

Então a peça que entrou **não é o remendo**: é a decisão entre os dois. Onde a
chave nativa existe, é ela que o `vidro.sh` escreve — suportada, sobrevive a
upgrade, e o assunto acaba aí. Onde não existe (COSMIC mais antigo), cai no
`scripts/vidro_janela.py`, que é o código da Aurora adaptado. A nativa não é
"preferida": ela **exclui** o remendo.

O `.Builder` entra junto na escrita, porque ele é a receita de onde o COSMIC
deriva o tema aplicado. Escrever só no derivado deixa a GUI desfazer no próximo
toque em Aparência.

### O painel fantasma

"A barra sumiu" tem dois modos de falha, e o `painel.sh` só cobria um:

| | causa | cura |
|---|---|---|
| coberto | o painel **morre** e o `cosmic-session` desiste (backoff `2^restarts` sem teto) | o `laco()` repõe |
| faltava | o painel fica **vivo e não desenha** | SIGTERM — a mesma que o `reciclar` já fazia |

O `laco()` passava direto pelo segundo, e de duas maneiras: no ramo que cede a
vez ao painel do supervisor e no que vigia um painel já existente, ele pergunta
"existe painel?", vê que sim e dorme. **Um fantasma responde "sim" para
sempre**, e ceder a vez a um painel que não desenha é ficar sem barra.

A detecção (`meow_painel_fantasma`, em `lib/painel.sh`) é filtrada pelo `_PID`
do painel em execução, e é isso que a torna confiável: uma mensagem do painel
anterior, ou de outro cliente Wayland qualquer, não conta. A versão da Aurora
media janela de tempo e errou os dois episódios que teve — num não detectou
nada (1h52 sem barra) e no outro acertou por coincidência, autorizada por um
erro de **outro** cliente 16m55s antes.

Detalhe que fecha uma fronteira invertida: o `lib/painel.sh` já escrevia a
carência de um vigia externo (`aurora-painel-fantasma/tentativas.ts`) que não
existe neste projeto — cooperávamos com um programa ausente. Agora a detecção é
daqui, e a linha continua sendo escrita para quando o vigia da Aurora existir na
máquina: os dois não podem reciclar o mesmo painel ao mesmo tempo.

### O que NÃO veio junto, e por quê

`aurora-cosmic-nightlight-watch.sh` e `aurora-cosmic-buttons-watch.sh` vigiam
issues do GitHub e notificam quando a System76 entregar. São ferramenta de
acompanhamento de quem mantém o projeto, não produto: ninguém que instale o
MeowSystem quer notificação diária sobre a issue #640. O mesmo vale para o que
é automação pessoal — qBittorrent, Steam, torrent, hefesto.

---

## A fronteira do conserto: nenhuma etapa termina em "faça você mesmo" — 22/09/2026

Esta seção não separa o Meow da Aurora. Separa **o que este projeto conserta**
do **que ele apenas relata** — e existe porque a linha entre os dois estava
sendo cruzada para o lado errado, calada, em seis lugares.

Quem usa, em 21/09/2026: *"nenhuma feature do MeowSystem pode ter esse tipo de
problema, temos que corrigir essa falha de produto na origem."*

### O que foi medido

Seis mensagens, colhidas no log da máquina de origem. Todas com a mesma
forma: **diagnóstico certo, conserto conhecido, nenhum botão.**

| onde | o que dizia |
|---|---|
| `scripts/areas.sh:1001` | *"alfinete uma área pelo COSMIC (visão geral, botão direito) e rode de novo"* |
| `assets/temas-de-apps/spotify/manifesto.sh` | um `curl \| sh` e um `git clone` dentro de dois `meow_info` |
| `scripts/prompt.sh` (o bloco do starship) | *"instalar é decisão sua. Sem sudo, em ~/.local/bin: …"* |
| `assets/temas-de-apps/qbittorrent/manifesto.sh` | *"sem `~/.config/zsh/scripts/aurora-qbittorrent-config.sh` não há quem escreva o qBittorrent.conf"* |
| `scripts/fastfetch_logo.sh` | *"o gato vai sair 68% fora da proporção … use 37 linhas para 95 colunas"* — a conta já feita, o conserto por fazer |
| `install.sh:2930` | *"Rode mais uma vez, até a tela dizer «nenhuma etapa precisou escrever nada»"* (é a P1, e ela já foi) |

Um engenheiro lê isso como cortesia. Um designer leigo lê como **"o programa
desistiu"**.

**CORREÇÃO DE 22/09/2026, medida na revisão.** No qBittorrent a sprint anotou a
frase curta, e a curta não era a pior: ao lado dela vivia um tutorial de vinte
linhas (`_meow_qbt_receita`) que imprimia o caminho do script do outro projeto,
o número da linha resolvido ao vivo e as duas edições para copiar e colar. Era
a mais crua das seis. As duas saíram da tela; a receita virou comentário no
arquivo, onde quem abre o código a lê e quem só usa o programa não tropeça
nela.

### A regra, e ela vale para toda feature futura

> Uma etapa que sabe o conserto ou **faz**, ou oferece **um botão que faz**.
> Quando nem o botão é possível — porque o que falta é decisão humana genuína —,
> a mensagem diz **a decisão**, não a receita.

As três saídas, e o projeto usa as três hoje:

| saída | quando | onde ela está |
|---|---|---|
| **faz** | o conserto é inteiramente nosso e não tem escolha dentro | `fastfetch_logo.sh` apara a altura à proporção da célula e diz o que aparou |
| **botão** | o conserto é nosso, mas a hora é de quem usa | `areas.sh alfinetar-primeira`, `prompt.sh instalar-starship`, o tema do Spotify (`_spot_tema_baixar`) e a reconstrução do menu de contexto — pendência com comando, e um «Resolver» na Home |
| **a decisão** | não há conserto que este projeto alcance | o BINÁRIO do `spicetify` (o instalador oficial mexe na configuração do terminal de quem usa) e o `qBittorrent.conf` (o app é configurado por outro projeto, com lista de temas fechada) — pendência **sem** comando, e a Home desenha a linha sem botão |

**BAIXAR DE REPOSITÓRIO PÚBLICO É "FAZER", NÃO "DEPENDER" — 22/09/2026.** A
diferença entre o tema do Spotify (botão) e o binário do spicetify (decisão) não
é o tamanho: é de quem é o arquivo. O tema é um repositório público que qualquer
clone deste projeto alcança, pinado por commit, baixado por uma função daqui —
a mesma disciplina do `scripts/cursor.sh`. O binário só se instala rodando o
instalador de terceiro, que escreve no `~/.config/zsh` de quem usa.

**O ESTADO PODE MUDAR O BOTÃO DA MESMA PENDÊNCIA.** O `files-menu-build` nasce
`construindo` (sem comando: não há o que clicar enquanto a unit compila), vira
`pronto` (a linha some) ou `falhou` (com comando: tentar de novo). Por isso o
painel decide o botão pelas DUAS pontas — a linha precisa ter comando **e** o id
precisa estar em `ACAO_DA_PENDENCIA`. Ler só a tabela poria um «Resolver» que
dispara um segundo build sobre o primeiro.

### Onde a regra mora no código

`lib/comum.sh` ganhou `meow_pendencia_acionavel <id> "<frase>" "<comando>"`, e a
irmã `meow_pendencia_resolvida <id>`. O verbo escreve a linha no log **e**
registra a pendência em `$MEOW_ESTADO/pendencias.tsv` (`id`, `etapa`, `frase`,
`comando`, `iso8601`); o painel a lê por `/api/pendencias` e a desenha na Home,
acima do "Nada esperando".

**O comando do TSV não é executado pelo painel.** O «Resolver» dispara uma ação
da tabela `ACOES`, casada pelo `id` em `ACAO_DA_PENDENCIA` (`app/servidor.py`).
Rodar a string do arquivo seria abrir uma porta de shell no painel para ganhar
exatamente nada — o arquivo é escrito por scripts nossos, não pela pessoa.

**A pendência que se resolve sai da lista.** Quem registra chama a irmã no
caminho feliz. Uma lista que só cresce vira a caixa de entrada que ninguém lê —
o mesmo defeito do doctor que nunca fica verde, que a P22 acabou de consertar do
outro lado da casa.

### O que a regra NÃO autoriza

- **Abrir a ponte root para caber um botão.** Oito mensagens deste projeto
  dizem `sudo apt install <pacote>` (cinco com `apt`, três com `apt-get` — e
  estas três só apareceram em 22/09/2026, quando o cobrador passou a casar as
  duas grafias; antes disso estavam verdes por omissão do detector, que é pior
  que estarem vermelhas). Instalar pacote arbitrário não é um dos oito verbos
  da ponte (ver "A ponte root, e por que ela não é `NOPASSWD: ALL`"), e trocar
  aquele desenho por um botão seria trocar um incômodo por um buraco.
  Elas ficam, isentas e com o motivo escrito, em `tests/sem-receita-no-log.sh`.
- **Apontar o botão para script de outro projeto.** O `spicetify-setup.sh`
  existe e resolve — em `~/.config/zsh/scripts/`, que é da Aurora. Um botão que
  depende dele quebra na máquina de quem clonou este repositório, que é o
  defeito que a P22 passou uma sprint inteira tirando daqui.
- **Prometer o que a rede decide.** O `aurora-qbittorrent-config.sh` está
  alcançável pelo espelho `sshfs` da outra máquina — quando ela está de pé. Um
  botão que funciona metade das vezes é pior que nenhum.

### O cobrador

`tests/sem-receita-no-log.sh` varre `scripts/`, `lib/` e `assets/temas-de-apps/`
atrás de `meow_info`/`meow_aviso` com `curl | sh`, `git clone` ou
`apt[-get] install`
dentro. As isenções casam pelo **conteúdo** da linha, nunca pelo número — mesma
disciplina do `tests/portabilidade.sh`, e pelo mesmo motivo: isenção presa a
número apodrece no primeiro rebase.

---

## O que é tema volta para casa — 22/09/2026

> *"O Spellbook é do meu PC, exclusivo para ele. Tudo que for relacionado a tema
> é para ser do MeowSystem, tá bom? Temos que trazer tudo para cá."* — quem usa,
> 21/09/2026

Esta é a frase que encerra a pergunta que a P28 deixou aberta. **Não há upstream
externo para sincronizar: a origem passa a ser aqui.** E é também a primeira vez
que a fronteira anda para o nosso lado em vez de ser só descrita.

### A regra, em uma linha

**Tema é do MeowSystem; máquina é do Spellbook.**

O Spellbook tem 5.213 arquivos e a esmagadora maioria é daquele computador —
thermal, GPU, wifi, `acer_wmi`, watchdogs, um `venv/` com 4.712 arquivos. Nada
disso é tema e nada disso se move. O que se move é o que responde *"com que cara
o sistema está"*.

### O que atravessou, e o que ficou

| item | para onde | por que é tema |
|---|---|---|
| `patches/patches.d/series` | `patches/series` | é **quem sabe aplicar** os patches: classe `req`/`opt`, ordem, marcador-base, análise de colisão |
| `cosmic-comp-sem-workspace-vazio.patch` | `patches/` | o único `req` da série, e o único que este repositório não tinha |
| `scripts/spicetify-setup.sh` | `scripts/spicetify_setup.sh` | é a pendência do Spotify (P2 e P3) — o botão que faltava |
| `fastfetch/config.jsonc` | duas linhas, para `assets/fastfetch/` | `wmtheme` e `font`: as duas perguntas de tema que faltavam aqui |

Ficaram lá, e é a metade que importa: `battery`, `host`, o `nvidia-smi`, o
status do Spellbook, o `sshfs` do Andromeda, as dez extensões de Spotify, o
`TEMA="Sleek"`. São daquele PC.

### Os patches já estavam nos dois lugares, e eram idênticos

Quatro dos cinco `.patch` viviam nas duas árvores. Conferido por `md5sum` em
22/09/2026: **byte a byte iguais, os quatro**. Não havia duas verdades — havia
uma verdade em dois lugares, que é pior, porque ninguém sabe qual editar.

O quinto, `cosmic-comp-sem-workspace-vazio.patch`, vivia só do lado do Ritual. Era
o `req` da série. **O MeowSystem tinha quatro dos cinco desenhos e não tinha a
planta** — e é exatamente por isso que o `compositor_patches.sh` só conferia e
nunca consertava.

### O que o `scripts/compositor_patches.sh` deixou de fazer

Saiu o bloco inteiro que comparava `patches/` contra
`~/.config/zsh/patches/patches.d/` por `md5sum`, e com ele as duas linhas que o
doctor repetia todo dia:

```
patches/ está em dia com ~/.config/zsh/patches/patches.d (4 arquivo, md5 igual)
só do lado da Aurora (este repo não carrega): cosmic-comp-sem-workspace-vazio.patch
```

Saíram também `CP_COPIA` e `CP_COPIA_ALT`, e o conselho que mandava rodar
`aurora-cosmic-comp-ws.sh --build` — um script que a P22 mediu **não existir
nesta máquina nem neste repositório**. O doctor mandava, todo dia, rodar um
comando inexistente.

**O bloco sai inteiro em vez de virar "compara se existir"**, e isso é decisão:
enquanto o código souber olhar para a árvore do Ritual, alguém volta a sincronizar as
duas cópias, e as duas verdades renascem.

### O que ele passou a fazer, e onde a linha cai

`compositor_patches.sh aplicar <dir-do-fonte>` põe a série numa árvore de fonte
do `cosmic-comp`. Ele **não** baixa o fonte, **não** roda `cargo`, **não** usa
sudo e **não** escreve em `/usr/bin`.

A linha cai aí de propósito. O `install.sh` roda todo módulo em sequência, de
hora em hora e no timer das 05:00; um `aplicar` que compilasse e instalasse
poria uma troca de `/usr/bin/cosmic-comp` dentro de uma passagem automática — e
**este binário é também a tela de login**. A própria `series` avisa: é por isso
que o modo de leitura e o blur são `opt` e vêm por último. Trazer a série para
cá mudou o dono do risco; não mudou o risco.

Duas garantias foram medidas em 22/09/2026, antes de o verbo ir ao ar:

1. **Dry-run de tudo antes de escrever um byte.** Um `req` que não aplica aborta
   com a árvore intacta — conferido por `md5sum` antes e depois: idênticos, e
   zero `.rej`/`.orig` deixados para trás.
2. **Fuzz zero.** O `patch` do GNU aceita por padrão até duas linhas de contexto
   erradas. Numa árvore de teste onde o hunk pedia `println!("oi")` e o arquivo
   tinha `println!("outra coisa")`, o dry-run devolveu **rc=0** e a aplicação
   enfiou o marcador no lugar errado, em silêncio. Para quase todo projeto isso
   é conveniência; para o binário que é a tela de login, é um compositor que
   compila e sobe quebrado — pior que não aplicar, porque não aplicar deixa o
   binário do pacote de pé. Daí `-F0` e `--no-backup-if-mismatch`.

E `compositor_patches.sh reverter` é o `--uninstall` que o item de risco da
sprint pedia: ele **sabe** voltar ao binário do pacote
(`apt install --reinstall cosmic-comp`) e **não roda o comando**, porque trocar
`/usr/bin` pede root e a ponte root deste projeto tem oito verbos, nenhum deles
"reinstalar pacote".

### A dependência fantasma do qBittorrent

`assets/temas-de-apps/qbittorrent/manifesto.sh` exigia
`~/.config/zsh/scripts/aurora-qbittorrent-config.sh`. A P29 foi buscá-lo para
trazê-lo e mediu, em 22/09/2026, que **ele não existe lá**: um
`find ~/.config/zsh -name '*qbittorrent*'` devolve zero linha. Não era "está no
outro projeto" — era dependência de um arquivo que não existe em lugar nenhum.
A P2 mandava tirar; esta sprint confirma que não há de onde trazer.

A linha virou `${MEOW_QBT_AURORA_FONTE:-}`, com padrão **vazio**. O
comportamento não muda — sem escritor do `qBittorrent.conf` o módulo já devolvia
`MEOW_SEM_DEPENDENCIA` (3) e registrava a pendência sem botão, porque o arquivo
já não existia. O que muda é a honestidade do código: ele deixa de afirmar que
sabe onde está um escritor que ninguém tem. **Não se inventou um segundo dono
para o `qBittorrent.conf`** — dois donos no mesmo arquivo é o começo de toda
guerra de idempotência, como o cabeçalho daquele módulo diz desde 25/08/2026.

### O Spotify ganhou o botão que faltava

O manifesto do Spotify dizia, desde a P2, por que aquela pendência nascia sem
conserto: *"o script que resolveria direito — `spicetify-setup.sh`, 277 linhas —
mora naquele outro repositório, que quem clonar ESTE não terá."* Agora tem.

Do script de lá vieram **duas** das oito coisas que ele faz: instalar o binário
e apontar o `prefs_path` do Spotify flatpak. As outras seis não vieram, e cada
recusa tem medição — a mais importante é `spicetify restore` + `clear` +
`backup apply`, que **fotografa o que está no disco**: rodado com o Catppuccin
já aplicado, congela o tema do Meow como se fosse o "vanilla" de fábrica, e aí
`spicetify restore` nunca mais devolve o original.

E o nosso instalador **não é o `curl | sh` oficial**: baixa o tarball do release
pinado por versão e não escreve em arquivo de shell nenhum. Os dois motivos que
a P2 usou para recusar o botão caíram junto — o oficial honra `ZDOTDIR` e
escreveria no `~/.config/zsh/.zshrc` de quem usa, e pergunta pelo Marketplace lendo de
`/dev/tty`, instalando-o sem ninguém ter pedido quando não há terminal.

### A regra fica escrita, e o teste a cobra

`tests/portabilidade.sh` já recusava `$HOME/.config/zsh` sem variável de escape.
O que mudou é que ele **deixou de isentar nominalmente a linha que esta sprint
extingue**. A isenção do `MEOW_QBT_AURORA_FONTE` saiu no mesmo commit que o
conserto — e tinha de sair, porque enquanto ela estivesse lá o teste passaria
verde sobre o defeito que veio pegar, e passaria verde igual depois de
consertado. **Uma isenção que sobrevive ao seu motivo é pior que nenhuma
isenção.**

Conferido: reintroduzindo a linha antiga, o teste falha
(`manifesto.sh:138 caminho do zsh cravado sem variável de escape`); com ela
consertada, passa.

### O que esta sprint NÃO fez, e é preciso dizer

Três itens do plano ficaram de fora, e nenhum por esquecimento:

1. **As quatro cópias não saíram do Spellbook.** Apagá-las é escrever em
   `~/.config/zsh`, que é o repositório de quem usa — com auto-commit a cada 10 minutos
   e a TRAVA 1 do `lib/comum.sh` recusando escrita ali. O mesmo vale para a
   linha no `README` de lá e para o `fastfetch/config.jsonc` de quem usa virar um
   `include`. **Este repositório não escreve no do vizinho**, que é a própria
   regra que a sprint veio reforçar. Fazê-lo agora contradiria o item 7 no
   mesmo commit que o cria. Quem tiver a árvore do Ritual aberta: sobra apagar
   `~/.config/zsh/patches/patches.d/` inteiro, que agora é cópia morta.
2. **`rebuild_dracula_theme()` não virou `meow pack construir dracula`.** O
   verbo existe e escreve só dentro do pack — mas aquela função não constrói o
   conteúdo de um pack: ela entra num **terceiro** repositório,
   `~/Desenvolvimento/Dracula_OS-Theme`, e roda o `build.sh`, o `install.sh
   --user` e o `extrair_mapeamento.py` dele. Medido em 22/09/2026: 1.379 linhas
   de pipeline e 32.370 arquivos em `src/`. Aquilo não cabe no `pack.py` nem no
   `bin/meow`, que são os dois arquivos que esta sprint autoriza tocar.
3. **O doctor não ficou verde no compositor, e não é por falta de código.** O
   `.estado` desta máquina declara os cinco patches `presente` na versão
   `0.1~1788962084~24.04~a557859`; o `dpkg-query` responde
   `0.1~1789989464~24.04~cd881a4`; e o binário em `/usr/bin/cosmic-comp` não tem
   **um** marcador `AURORA-*`. Um `apt` trocou o compositor e levou os cinco
   patches junto, calado — que é exatamente o sintoma que este arquivo existe
   para pegar. O vermelho está certo. O que a P29 mudou é que ele deixou de
   apontar para um script que não existe: agora nomeia `aplicar`, que é daqui.

---

## O doctor só lê, e o que era tema termina de sair do Spellbook — 24/09/2026 (P44)

**Um sinal nunca sai da casa de quem pediu.** O `painel.sh reciclar` derrubava
o painel por `pkill -x cosmic-panel` — a máquina inteira. Medido: um
`HOME=$(mktemp -d) meow doctor` gravava 13 arquivos na casa de brinquedo e
mandava SIGTERM no painel da sessão de verdade. Agora todo sinal do painel mira
só o processo do MESMO usuário e do MESMO `$HOME` de quem chamou
(`meow_painel_desta_casa`, `lib/painel.sh`), e o doctor sem `--consertar` não
escreve: o `chk_logo` e o `chk_apps` passaram a rodar em seco, como as irmãs.
O `tests/doctor-so-le.sh` cobra as duas coisas.

**O que era tema no Spellbook, e ainda morava lá:**

| item | para onde | o que ficou do lado de lá |
|---|---|---|
| as cores do fzf (`FZF_DEFAULT_OPTS` em Catppuccin, `fzf-tab` em Dracula — duas paletas cravadas na mesma máquina) | `scripts/fzf.sh` escreve `~/.config/meowsystem/fzf.sh` a partir da paleta do pack no ar | a linha que carrega o arquivo, e o `use-fzf-default-opts` do fzf-tab: são do shell de quem usa |
| `~/.config/fastfetch` (symlink para `fastfetch/` do Spellbook) | diretório de verdade, do MeowSystem; o `fastfetch_logo.sh` o assume sozinho, com backup | nada: o Spellbook parou de versionar `fastfetch/` |

O resto do `env.zsh` — aliases, PATH, `FZF_DEFAULT_COMMAND`, atalhos — ficou
intocado: é máquina, não tema (o limite de 24/09).

## O contrato numerado, que era citado em dezenas de linhas e não existia — 21/09/2026

As palavras **"regra N"** e **"o contrato do projeto"** aparecem em dezenas de
linhas de código, apontando para as regras **1, 4, 5, 7, 8 e 10**. A lista
numerada **não existia** — nem em `docs/`, nem em `lib/`, nem em lugar nenhum.
Cada leitor inventava a sua, e todos aqueles comentários apontavam para o vazio.

**O número de hoje se conta, não se lembra.** Nenhum teste cobra um número
escrito nesta seção, e número sem cobrador apodrece — é o mesmo motivo pelo qual
o `lib/comum.sh:103` deixou de dizer "54 etapas, 46 ações" nesta mesma leva:

```sh
grep -rnE 'regra [0-9]|o contrato do projeto' --include='*.sh' --include='*.py' . | wc -l
```

Medido em 21/09/2026: **49 linhas** — 27 dizem "regra N" e 22 dizem "o contrato
do projeto". A sprint que mandou escrever esta seção anotou **50**, e 50 nunca
foi o número: a primeira versão deste parágrafo copiou o 50 da sprint e nasceu
errada no mesmo dia. É por isso que a frase de cima não carrega mais um número.

**Esta lista não inventa regra.** Cada linha abaixo é o que as próprias citações
afirmam, com os arquivos que as afirmam ao lado. Onde nenhuma citação existe, a
linha fica **vaga** — escrever uma regra que ninguém cita seria fundar contrato
por decreto, e o primeiro código a contradizê-la já estaria escrito.

### 1. Estado desejado é declarado, não imperativo — e cada estado tem um dono só

Nenhum hex vive dentro de script: toda cor vem de `assets/paleta/`, e o destino
de cada cor vem de um mapa. Trocar de flavor é trocar uma linha do `meow.conf`,
nunca editar um tema à mão. A outra metade da mesma regra é a propriedade: duas
rotinas mandando na mesma chave é defeito, e estoura em vez de passar.

> `scripts/gerar_temas.py:5` · `scripts/appid_dock.sh:208`

### 2. — vaga

### 3. — vaga

### 4. Antes de sobrescrever, guardar o original — sempre

Falhar o backup aborta a escrita; não existe "escreveu e o backup não deu". A
retenção falada é das **10 últimas** passagens, e a poda é de quem enxerga a
fila inteira (o runner, o `meow desfazer`) — nunca do módulo, que só enxerga a
própria pasta e apagaria o histórico dos vizinhos.

> `assets/temas-de-apps/toolkits-gtk-qt/manifesto.sh:295,568` ·
> `assets/temas-de-apps/vscode/manifesto.sh:481,514` ·
> `assets/temas-de-apps/zapzap/manifesto.sh:243`

### 5. Idempotência por CONTEÚDO, não por existência

O arquivo já estar lá não é resposta: o que decide é ele já ser **igual ao que
se ia escrever**. Idêntico não se reescreve, e quem não escreveu diz que não
escreveu. É a regra mais citada do repositório, e é dela que sai a promessa do
README de que rodar de novo numa máquina pronta não escreve um byte.

> `lib/comum.sh:296` · `install.sh:1011,1172` · `scripts/aplicar_tema.sh:11` ·
> `scripts/greeter.sh:219` · `scripts/som.sh:285` · `scripts/ocultar_apps.sh:147` ·
> `scripts/fastfetch_logo.sh:729` · `scripts/importar_icones.sh:166` ·
> `scripts/construir_icones.sh:114` · `scripts/ponte_root.sh:130` ·
> `assets/temas-de-apps/obsidian/manifesto.sh:174` ·
> `assets/temas-de-apps/heroic/manifesto.sh:448,505`

### 6. — vaga

### 7. Códigos de saída honestos

`0` = certo · `1` = divergente · `2` = erro de execução · `3` = falta
dependência. A diferença entre **1** e **3** é o que permite ao auto-reparo
ficar quieto quando o app simplesmente não está instalado, e gritar quando algo
de fato quebrou. É a regra mais repetida em cabeçalho: medido em 21/09/2026,
**21 scripts** abrem com a frase *"CÓDIGOS DE SAÍDA (o contrato do projeto)"* —
22 arquivos, contando este documento, que não é script:

```sh
grep -rl 'CÓDIGOS DE SAÍDA (o contrato do projeto)' --include='*.sh' --include='*.py' . | wc -l
```

> `lib/comum.sh:12`, e o mesmo cabeçalho em `scripts/icones_orfaos.py`,
> `scripts/icones_pastas.sh`, `scripts/leitura_build.sh`, `scripts/appid_dock.sh`,
> `scripts/vigia_heroic.sh`, `scripts/icones_tray_steam.sh`, `scripts/midia.sh`,
> `scripts/vigia_assets.sh`, `scripts/icones_tray_zapzap.sh`,
> `scripts/icones_apps_arcticons.sh`, `scripts/icones_bandeja.sh`,
> `scripts/icones_absolutos.sh`, `scripts/construir_convertidos.sh`,
> `scripts/vigia_flatpak.sh`, `scripts/escala.sh`, `scripts/apos_flatpak.sh`,
> `scripts/vigia_steam.sh`, `scripts/icones_sistema.sh`, `scripts/midia_build.sh`,
> `scripts/icones_mimetypes.sh`, `scripts/nomes_apps.sh`

### 8. Falha por unidade, nunca global

Cada etapa é uma função que **retorna** código; nenhuma chama `exit`. Um app
ausente vira "pulado" e o resto continua. É por isso que o `install.sh` **não**
usa `set -e`: com ele, uma etapa que devolvesse != 0 abortaria tudo e deixaria a
máquina em estado parcial — pior do que não ter começado.

> `install.sh:30` · `scripts/aplicar_apps.sh:4`

### 9. — vaga

### 10. Uma passagem por vez: o lock

O timer pode disparar enquanto ela roda na mão, e dois cliques rápidos no painel
são a mesma corrida com outra roupa. Quem escreve pega
`~/.local/state/meowsystem/lock` antes.

> `lib/comum.sh:463` · `app/servidor.py:91`

### As quatro vagas, e por que ficam vazias

**2, 3, 6 e 9 não têm uma única citação em código.** Ou nunca existiram, ou
existiram e morreram sem deixar rastro no comentário de ninguém. Preenchê-las
hoje seria escrever contrato de trás para frente: a regra nasceria da lista, e
não do defeito que a exigiu. Quem precisar da regra 2 escreve a regra 2 — e
escreve junto o código que a cita, que é o que prova que ela existe.

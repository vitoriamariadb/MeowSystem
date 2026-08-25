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
| alpha do `base:` de `background`/`primary`/`secondary` | Aurora (`aurora-vidro-maximizado.py`) | **Aurora** — já funciona, não mexer; **não alcança painel nem dock**, ver 23/08 |
| `CosmicPanel.{Panel,Dock}/v1/keep_style_on_maximize` | Meow (`vidro.sh`) | **Meow** — a GUI não tem controle para ela |
| `CosmicPanel.{Panel,Dock}/v1/opacity` | COSMIC (GUI) | **ELA** — desde 17/08/2026, ver abaixo |
| escala das saídas (`cosmic-randr`, o `outputs.ron`) | COSMIC (GUI) | **ELA** — o `install.sh` aplica `ESCALA_TELA` quando ela pede; o doctor nunca |
| `CosmicPanel.*/v1/plugins_{wings,center}` | Aurora | **Aurora** — a ordem dos applets é dela |
| `CosmicTk/v1/icon_theme` e `~/.local/share/icons/MeowSystem-Icons` | Meow | **Meow** |
| `/usr/share/icons/hicolor/.../CosmicAppLibrary.svg` | ambos | **Meow** — o Aurora restaura o `.aurora-original` |
| `~/.config/cosmic/logos/` | ambos | **Meow** — o `gato-pop.svg` do Aurora foi aposentado |
| `~/.local/share/icons/hicolor/index.theme` | Meow (`hicolor.sh`) | **Meow** |
| `~/.local/share/applications/` — conteúdo do lançador | ambos | **Meow** |
| `~/.local/share/applications/com.github.DiegoMMR.CosmicExtAppletNowPlaying.desktop` | Meow (`midia.sh`) | **Meow** — a "sombra" do applet de mídia, ver abaixo |
| `~/.local/bin/meow-applet-now-playing` e `~/.local/state/meowsystem/midia/` | Meow (`midia_build.sh`) | **Meow** |
| `~/.config/cosmic-ext-applet-now-playing/{panel-text-width,panel-color-style,album-art-remote}` | Meow (`midia.sh`) | **Meow** |
| `~/.config/cosmic-ext-applet-now-playing/album-color-enabled` | ela, pelo popup do applet | **ELA** — o Meow só migrou o valor do sandbox uma vez |
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
| `gsettings` / `dconf` — `org.gnome.desktop.wm.preferences` (`button-layout`) | Aurora | **Aurora** |
| `gsettings` / `dconf` — `org.gnome.desktop.interface` (`cursor-theme`) | Meow (`cursor.sh`) | **Meow** — resolvido em 25/08/2026, ver abaixo |
| `~/.icons/default/index.theme` | Meow (`cursor.sh`) | **Meow** — é o que o `cosmic-comp` obedece; o gsettings NÃO o alcança |
| `/usr/local/bin/*` (wrappers de execução) | Aurora | **Aurora** |
| `/usr/local/share/zsh/site-functions/_meow` | Aurora | **Aurora instala, Meow fornece** |
| binário `cosmic-comp` (patches de workspace e night light) | Aurora | **Aurora** |
| ciclo de vida do processo `cosmic-panel` | Aurora | **Aurora** — hoje desarmado (ver abaixo) |
| tema do qBittorrent, `~/.config/fastfetch` | Aurora | **Aurora** — o `meow` chama o script de lá |

---

## O applet de mídia entra por sombra, e `plugins_wings` continua da Aurora (24/08/2026)

Ela pediu nome da música, controles, capa e cores do álbum na dock. A causa de faltarem
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
   um" apagaria a Status Area dela.

### O buraco que o fail-safe existe para tapar

Sombra presente + binário ausente = **nenhum** applet na dock. O painel consome o slot no
primeiro acerto de basename e **nunca chega a tentar** o export do flatpak — então o
resultado não é "volta ao applet de fábrica", é um vazio. Acontece de graça: um `rm`
errado, um limpador de disco, um build interrompido. Por isso o `midia.sh --aplicar`
**remove a sombra** quando o binário some, e o `--reverter` apaga **a sombra antes do
binário**. É um `rm` de arquivo nosso, sem sudo e sem rede — o doctor das 05:00 pode
fazer, e o efeito é ela voltar sozinha ao flatpak que funciona.

### Onde ele mora, e quem o pôs lá

Em 24/08/2026, **a pedido dela e pela mão dela na decisão**, o applet saiu da asa
direita da dock e foi para a asa direita da topbar, **imediatamente antes do
`com.system76.CosmicAppletAudio`** — o applet de Som, que é quem já desenha os
⏮⏸⏭ ali. O `plugins_wings` das duas barras foi editado **uma vez, à mão**, com
backup em `~/.local/state/meowsystem/backups/painel-2026-08-24/`.

Isso **não** revoga a abstenção acima: o módulo `midia` continua sem escrever
uma linha em `plugins_{wings,center}`, nem no `install.sh`, nem no doctor, nem
no `--reverter`. Uma coisa é a pessoa mover o próprio applet; outra é um script
que roda às 05:00 achar que sabe a ordem certa.

Consequência registrada: com o Som ao lado, os ⏮⏸⏭ do próprio Now Playing viram
duplicata visual. Por isso `MIDIA_CONTROLES` nasce `"nao"`.

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
`fix_vidro` todo dia, o número que ela escolhia voltava para o nosso sem que nada dissesse
por quê — e a GUI ainda exibia 19 e 26 como se fossem a escolha dela. Era a terceira
travessia da mesma fronteira no mesmo arquivo (05/08: unificar em 0.05; 10/08: rederivar
para 0.19/0.26); as duas primeiras corrigiram o **número**, esta mudou o **dono**.

Hoje `VIDRO_OPACIDADE_PAINEL` e `VIDRO_OPACIDADE_DOCK` nascem **vazias** no `meow.conf`, e
vazio quer dizer "não toque". Preencher volta a impor — a ponte do conf até o script foi
fechada no mesmo dia, então preencher agora tem efeito de verdade (antes as chaves eram
lidas por `bin/meow` e morriam lá). O que continua nosso é `keep_style_on_maximize`, que a
GUI não tem: se ninguém a escrever, ela se perde em silêncio.

**A escala.** Ela pediu "aumentar o tamanho universal das fontes". Não existe chave de
tamanho de fonte no COSMIC — `interface_font` não tem campo de tamanho, `interface_density`
mexe só em espaçamento, o `default_text_size` da libcosmic é 14.0 constante no código e
`COSMIC_SCALE` não alcança o painel. Sobra a escala da saída, que é *Ajustes → Telas →
Escala*. O `scripts/escala.sh` a aplica pelo `cosmic-randr` (nunca editando o `outputs.ron`,
que é estado do compositor e é reescrito por cima), e **só pelo `install.sh`**: pôr isto no
doctor repetiria, com outro nome, o defeito que a opacidade acabou de custar.

---

## O alpha que o Aurora escreve NÃO chega no painel (23/08/2026)

Ela reclamou que "a opacidade da barra não é respeitada". A suspeita óbvia, e a que
esta tabela alimentava, era travessia de fronteira: o `aurora-vidro-maximizado.py`
escreve o alpha do `base:` de `background` (hoje `0x8A`), esse número é quase igual ao
`alpha_map[extremely_high_2]` do tema dela (0,54), e daí para "o Aurora está atropelando
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
existe porque os dois descendem do mesmo `frosted` que ela escolheu, não porque um alimente
o outro.

**E o Aurora não impõe número nenhum.** Ele copia o alpha de `transparent_X.base` para
`X.base` — propaga a escolha dela em "Espessura do efeito fosco"/"Opacidade do vidro" em
vez de fixar um valor. O `aurora-vidro-maximizado.path` está `active`/`enabled` e reaplica
assim que o tema muda, mas o que ele reaplica é o que ela mesma escolheu. **Nada a mudar
do lado do Aurora**, e a linha da tabela continua dele.

**O que realmente apaga o controle dela é nosso.** Medido no pixel: com
`keep_style_on_maximize = false` e uma janela maximizada, `opacity` é ignorada —
`0.19` e `0.95` desenharam capturas pixel-idênticas, a barra chapada em `#313244`.
O upstream faz `let effective_maximized = maximized && !config.keep_style_on_maximize;`
e, quando ele vale, `config.maximize()` força `self.opacity = 1.0`. Ou seja: a chave que
esta tabela já dava ao Meow ("a GUI não tem controle para ela") é a **pré-condição** para
o slider dela funcionar. Perder essa chave em silêncio não estraga só o vidro ao
maximizar — mata a "Opacidade do fundo" inteira. O `vidro.sh` passou a avisar; ele
continua sem escrever `opacity`, que segue sendo dela.

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

---

## O cursor tem dois donos na tela, e nenhum deles era nós (25/08/2026)

A Sprint P abriu uma pergunta de fronteira que a tabela não respondia: a linha
`gsettings / dconf` dava tudo à Aurora, mas nomeava **`button-layout`**, não a
chave inteira. Antes de escrever, foi medido — e a resposta é limpa nos dois
sentidos.

**A Aurora não escreve `cursor-theme`.** Todo `gsettings set` vivo do
repositório dela mira `org.gnome.desktop.wm.preferences`:

```
grep -rn 'gsettings set' ~/.config/zsh/scripts/
  aurora-button-layout.service:19   ...wm.preferences button-layout
  ritual-aurora-self-heal.sh:1833   ...wm.preferences button-layout
```

A única menção a `cursor-theme` no repositório dela está em
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
declara `Inherits=Adwaita`. **O cursor do desktop dela era Adwaita, corpo
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

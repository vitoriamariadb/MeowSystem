# Como o COSMIC se veste — o que foi medido nesta máquina

Fatos medidos na máquina de origem, não o que a documentação promete, com o jeito de medir
para refazer o teste em vez de acreditar. Pop!_OS 24.04, COSMIC 1.0.12 nas medições datadas;
o instalado hoje é o 1.10 (`cosmic-comp` 4d14528), e seção que não diz que foi medida no 1.10
não foi.

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
vai para o git, e `scripts/aplicar_tema.sh` reproduz por cópia — sem GUI, sem
clique. É uma vez na vida do projeto, e vale de novo se esta máquina for
reformatada: o custo do import não volta.

**O que NÃO fazer:** escrever chave por chave em `Dark/v1`. As árvores derivadas já
discordam entre si nesta máquina — `Dark/v1` tem 30 chaves e `Dark/v2` tem 17, e o
`window_hint` de uma é `Some(...)` enquanto o da outra é `None`. Reproduzir isso à
mão gera um tema híbrido que *quase* funciona, e o "quase" só aparece semanas depois.

> Depois dos imports pela GUI, `Dark/v2` passa de 17 para **38** chaves (a captura `original`
> guarda as 17 de antes). E a conclusão
> "não mexer na v1" precisava de uma saída, porque a v1 **não está morta**: três
> applets flatpak leem dela. A saída não é escrever à mão — é **gerar**, por
> substituição numérica dentro do arquivo que o próprio COSMIC escreveu. Ver §4h.

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
Ordem observada por `strace` (num `Xvfb :99`, sem tocar na sessão de quem usa), para o tema
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

### Confirmado na prática, no desktop de quem usa

Montado `~/.local/share/icons/MeowSystem-Icons` com `scalable/apps/` e
`icon_theme = "MeowSystem-Icons"`: **o botão do dock virou o mascote Catppuccin na hora**,
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

## 3. O mascote do painel não passa por tema de ícones

> **Leia isto antes da seção.**
> O applet descrito abaixo **não está montado em barra nenhuma** nesta máquina:
> `LogoMenu` não aparece em `plugins_wings` nem em `plugins_center` do
> `CosmicPanel.Panel` nem do `CosmicPanel.Dock`. Tudo o que esta seção descreve
> sobre `custom_logo_path` está certo e continua funcionando — só que **ninguém
> desenha o resultado**. O mascote que se vê de fato é outro caminho: o
> `com.system76.CosmicPanelAppButton`, que vem do TEMA DE ÍCONES e é lido uma
> vez, no login.
>
> Consequência prática, e é a que explica a queixa de 08/08 ("voltamos a ter o
> ícone antigo do lançador"): **o mascote só pode mudar de aparência no login**. Foi
> por isso que a rotação deixou de ser um relógio e passou a acontecer no
> encerramento da sessão — ver `dados/systemd/meow-logo.service`.

O applet `dev.cappsy.CosmicExtAppletLogoMenu` guarda o caminho do arquivo direto:

```
custom_logo_active = true
custom_logo_path   = "/home/<usuário>/.config/cosmic/logos/gato-pop.svg"
```

Trocar a logo do painel é trocar esse SVG (ou apontar a chave para outro arquivo) —
não passa por `icon_theme`, não precisa de cache, não precisa de `/usr/share`.

**Armadilha do nome:** o applet faz `.symbolic(path.contains("-symbolic.svg"))`. Um
arquivo terminado em `-symbolic.svg` é achatado numa cor só. Portanto
um arquivo chamado `logo-symbolic.svg` **não serve** como logo do painel.

### A logo TROCA AO VIVO — mas só pela chave, não pelo arquivo

**Medido em 2026-08-04**, respondendo à pergunta "a logo pode girar junto com os
papéis de parede?".

| O que se muda | Efeito |
|---|---|
| o **conteúdo** do SVG apontado | **nada** — o applet cacheou a imagem no carregamento |
| a **chave** `custom_logo_path`, para outro arquivo | **troca na hora**, sem reiniciar o painel |

> **O botão do dock é outra pergunta.** A tabela acima é sobre a chave do applet Logo Menu.
> A outra é sobre o
> **botão do dock** (`com.system76.CosmicPanelAppButton`), que vem do TEMA DE
> ÍCONES — e a resposta que este documento dava por implicação ("trocar ícone de
> tema exige reiniciar o painel") estava **meio certa**:
>
> | o que se faz | o que acontece |
> |---|---|
> | reescrever o SVG do botão no tema de ícones | **zero pixel muda** — o `cosmic-panel-button` resolve o ícone no arranque e guarda |
> | `kill <pid do cosmic-panel-button>` | **buraco no dock** — o `cosmic-panel` NÃO ressuscita applet morto |
> | `meow painel reciclar` (SIGTERM no painel, pela porta única) | **botão de volta em ~6 s, com o mascote NOVO** |
>
> Provado com captura de tela antes e depois, nas três linhas. É isso que faz o
> mascote do dock seguir o relógio — duas trocas por dia, não uma a cada meia hora,
> e é a mudança de FREQUÊNCIA que tornou o pisca aceitável, não uma medição nova
> que contradiga a de 04/08.
>
> O `cosmic-files-applet` (quem desenha a área de trabalho) é outro caso: é filho
> do `cosmic-session`, não do painel, então reciclar o painel não o toca — mas
> matá-lo funciona, e ele volta em segundos resolvendo pelo PATH.

O applet vigia a configuração por inotify (o processo tem 6 fds de inotify), mas não
vigia o arquivo de imagem. Então reescrever `meow-mocha.svg` no lugar não faz efeito
até o próximo `pkill -x cosmic-panel`; já apontar a chave para um
`meow-mocha-pink.svg` troca o mascote instantaneamente, sem piscar nada.

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

## 4h. As DUAS árvores estão vivas — e a prova sai do `/proc`, sem reiniciar nada

**Medido.** A pergunta era: a `v1` foi aposentada?
**Não.** As duas árvores derivadas estão em uso ao mesmo tempo, por duas gerações
de `libcosmic`, e cada uma tem o seu leitor.

### Como se mede sem tocar na sessão de quem usa

Todo cliente de `cosmic-config` põe uma **watch de inotify** no diretório que lê.
As watches de um processo vivo estão em `/proc/<pid>/fdinfo/*`, com o inode do
alvo. Comparar com o inode dos diretórios de tema responde "quem lê o quê" sem
abrir janela, sem `strace` e sem reiniciar nada:

```
for f in /proc/<pid>/fdinfo/*; do grep -H ^inotify "$f"; done   # ino: em HEX
stat -c '%i %n' ~/.config/cosmic/com.system76.CosmicTheme.*/v*  # inode em DECIMAL
```

Resultado nesta máquina:

| processo | vigia | inode |
|---|---|---|
| `cosmic-panel` | `Dark/v2`, `Light/v2`, `Mode/v1` | 3935095, 4195309 |
| `cosmic-ext-applet-drives` (flatpak) | **`Dark/v1`**, `Mode/v1` | 3932173 |
| `cosmic-ext-applet-clipboard-manager` (flatpak) | **`Dark/v1`**, `Mode/v1` | 3932173 |
| `cosmic-ext-applet-eyedropper` (flatpak) | nenhuma árvore de tema | — |

O bind-mount do flatpak preserva o inode, então a comparação vale de dentro do
sandbox. E o `sdev:800014` do `fdinfo` é o mesmo `8:20` do `stat -c %D`.

### Por que os applets flatpak ficam numa árvore e o painel na outra

O esquema mudou entre as versões, e os binários carregam a prova. O blob de
desserialização de cada applet declara **26 campos**, com `is_frosted` e **sem**
`alpha_map`, `transparent_*`, `list_button`, `name`, `gaps`, `is_high_contrast` —
que é exatamente o conjunto de arquivos da `v1`. O `cosmic-settings` é o inverso:
tem `alpha_map` e `transparent_*` e **não tem** `is_frosted`.

Daí sai a prova de que **a GUI não deriva mais a v1**: `is_frosted` só existe no
esquema v1, e **nenhum dos 41 binários `/usr/bin/cosmic-*` contém essa string**.
Um derivador que escrevesse a v1 teria de escrever essa chave. Confirma o que os
mtimes já diziam (`Dark/v1/accent` parado em 2026-04-12, atravessando três
imports) e o experimento de §1 (escrever no `Builder/v1` não derivou nada).

### O sintoma que isso explicava

Os dois applets saíam `#CACACA` no painel contra `#FFFFFF` dos nativos. O campo é
**`Dark/v1/background.on`** — `0.79136145 × 255 = 201,8 → 202 = 0xCA`. (Uma nota
anterior atribuía isso a `background.component.on`; aquele é `0.8945329 → 0xE4`.)

### Os floats da v1 são sRGB direto, sem gama

Confirmado em campos que são exatamente `n/255`, o que só acontece sem conversão:
`palette.bright_red` = `1.0 / 0.627451 / 0.5647059` → `#FFA090` (160/255 e
144/255, exatos); `gray_1` = `0.105882354` → `#1B1B1B` (27/255); `gray_2` →
`#262626`. Se fosse linear, `0xE2` daria `0.760`, não `0.886`.

### A v1 está FORA do alcance do Ritual da Aurora

Não por acordo, por estrutura: a função `temas()` do `aurora-vidro-maximizado.py`
só aceita um diretório que **tenha `transparent_*`** dentro. A `v1` não tem
nenhum (são chaves só do esquema v2). Zero ping-pong, nada a normalizar ali.

### Como a v1 é vestida: gerada, nunca escrita à mão

`scripts/gerar_tema_v1.py`. Ele **não** reimplementa a derivação de contraste do
COSMIC — isso seria o híbrido que §1 proíbe. Ele pega o texto do arquivo v1 do
**fóssil** (`packs/meowsystem/temas/capturados/original/…/v1`, escrito pelo próprio COSMIC e versionado)
e substitui **só os literais numéricos de R, G e B** pelo valor do mesmo caminho
no arquivo `v2` da captura — que é o produto que o COSMIC derivou do `.ron` que o
`gerar_temas.py` gerou da paleta. A cor continua saindo de
`packs/meowsystem/paleta.json`; o caminho é transitivo. A estrutura RON é, por
construção, a de um arquivo que o COSMIC escreveu.

**O alpha não entra: é de quem usa.** Na v2 o alpha já vem multiplicado pelos dois
slideres de Vidro fosco (`background.base` = `#313244B3`). Copiá-lo para a v1
seria impor o valor *fotografado* de um controle contínuo — o defeito corrigido em
05/08 — e pior, a captura é congelada, então o valor imposto seria sempre o
velho. Consequência assumida: os popups desses dois applets ficam **opacos**
enquanto os nativos ficam translúcidos.

---

## 4g. Ícone `symbolic` no COSMIC: a cor do arquivo é JOGADA FORA

Os symbolic são recoloridos pelo toolkit em tempo de desenho, e medido o efeito é forte: o
toolkit não ajusta a cor — ele **descarta o arquivo inteiro e repinta com uma cor só**,
preservando apenas o alpha.

**A prova, sem inferência.** O `cosmic-applet-bluetooth-disabled-symbolic` tem
**dois tons** gravados no disco:

```bash
$ grep -oE '(fill|stroke)="[^"]*"' \
    /usr/share/icons/hicolor/scalable/status/cosmic-applet-bluetooth-disabled-symbolic.svg \
  | sort | uniq -c
      2 fill="#232323"
      1 fill="#808080"
      1 fill="none"
```

E na tela, no painel, sai **um tom só**:

```bash
$ convert Screenshot.png -crop 26x26+1755+12 +repage -depth 8 txt: \
  | grep -oE '#[0-9A-F]{6}' | sort | uniq -c | sort -rn | head -2
    125 #FFFFFF          <- o icone
     43 #2C2D3F          <- o fundo do painel
```

`#232323` e `#808080` viraram `#FFFFFF`. Dois tons viraram um.

**Consequência dura.** Ícone pastel colorido é
**impossível** nas páginas das Configurações e nos applets da barra. Não importa
a cor que se pinte no arquivo: o toolkit apaga. O único eixo de mudança que
sobrevive ali é o **desenho** — a forma do traço. A cor continua vindo do
`CosmicTheme`, que o MeowSystem já controla.

Isso também significa que **recolorir Arcticons via `?color=` do Iconify é
desperdício** para estes 126 ícones. Continua valendo para os ícones de aplicativo, que não passam por este caminho.

### Nem o FORMATO do arquivo escapa (medido em 27/08/2026)

O pedido foi uma **borda roxa** no botão de desligar do dock. A hipótese que valia a
pena testar era a do §3: o applet decide `symbolic` por `path.contains("-symbolic
.svg")`, uma checagem de STRING no caminho — então um arquivo `.png` teria o
sufixo errado e escaparia do achatamento.

Testado nas duas formas, com o anel gravado em `#CBA6F7` (o mauve do mocha) e o
glifo em `currentColor`, respawnando os applets pelo `spacing` do dock:

| arquivo plantado | o que saiu no recorte da tela |
|---|---|
| `scalable/status/system-shutdown-symbolic.svg` | 94 px `#FFFFFF`, **zero** `#CBA6F7` |
| `20x20/status/system-shutdown-symbolic.png` (40×40) | 94 px `#FFFFFF`, zero `#CBA6F7` — e serrilhado, porque é raster esticado |

O achatamento **não é do rasterizador de SVG**: é o toolkit repintando o buffer
final. Raster passa pelo mesmo caminho. Portanto **não existe ícone colorido na
barra do COSMIC**, em nenhum formato — a única cor ali é a cor de texto do tema,
e ela vale para todos os applets ao mesmo tempo.

O que sobrevive continua sendo o DESENHO: o anel externo daquele ícone É a borda
que foi pedido, e o botão passou de 75% para 95% da caixa. Só a cor não pôde vir.

### De onde vêm os 126 ícones que o COSMIC pede

Os nomes não saem limpos do binário: as strings do Rust ficam **coladas** umas nas
outras, sem NUL entre elas, então `strings | grep -x` devolve lixo do tipo
`folderfolder-symbolicuser-home...`. O jeito que funciona é casar por dicionário
contra os nomes que existem em disco, com o mais longo ganhando:

```bash
find -L /usr/share/icons ~/.local/share/icons -name '*-symbolic.svg' \
  | xargs -n1 basename | sed -E 's/\.svg$//' | sort -u > /tmp/nomes-reais.txt
# depois: re.finditer com alternation dos nomes ordenados por tamanho decrescente
# sobre `strings -a` de cosmic-settings, cosmic-applets, cosmic-osd, cosmic-notifications
```

Resolvidos no resolvedor real (`Gtk.IconTheme` com `MeowSystem-Icons`), a 22 e 24 px:

| origem | quantos |
|---|---|
| Papirus-Dark | 96 |
| Cosmic | 24 |
| hicolor | 5 |
| Pop | 1 (lixo: a string `-symbolic` solta, que é o `ends_with` do libcosmic) |

Os **24 do tema Cosmic são exatamente as páginas das Configurações** que quem usa
fotografou (`preferences-*`).

O `Directories=` do `MeowSystem-Icons` declara também `22x22/status` e `scalable/status`, com
**28 `*-symbolic.svg` em cada um**: os 56 que o `meow doctor` conta.

### O traço do Arcticons some a 22 px, e o conserto é um atributo

Os SVG do Arcticons vêm com `stroke="currentColor"` num `viewBox="0 0 48 48"` e
**sem `stroke-width` declarado**. O padrão SVG é `1` — que a 22 px de tela vira
**0,46 px** e desaparece. Dobrar o `stroke-width` resolve e é um atributo só.

Cuidado ao inserir: um elemento com `stroke-width` **duplicado** é XML inválido e
o Chrome recusa o SVG inteiro, calado, mostrando ícone quebrado.

---

## 5. Fronteira com vizinhos

Quem escreve cada chave está em [`FRONTEIRA.md`](FRONTEIRA.md).

---

## 6. O que nunca fazer, e o que pode

- **`apt full-upgrade` com COSMIC novo pode.** O compositor patchado é build da casa, em
  `~/.local/libexec/meow/cosmic-comp/<versão>/`, e o shim `~/.local/bin/cosmic-comp` escolhe a cada
  sessão entre ele e o de fábrica; o apt não toca no shim e a tela de login usa só o binário do
  pacote. O build se refaz sozinho (pós-apt, login, doctor), e um patch obrigatório que não entra
  deixa a sessão no compositor de fábrica. O passo a passo está em [`MANUTENCAO.md`](MANUTENCAO.md);
  `meow cosmic prever` diz antes do upgrade se a série e o esquema de chaves entram.
- **`sudo` perto de `~/.config` não.** Um arquivo de dono root ali faz a GUI de tema falhar em
  silêncio.
- **Escrever em `~/.config/zsh` não**, na máquina que o declara em `~/.config/meow/vizinhos.conf`:
  é o repositório de shell de quem usa, com auto-commit. A TRAVA 1 do `scripts/lib/comum.sh` recusa.

# MeowSystem-Theme — Catppuccin para COSMIC

Relatório técnico + plano de execução para transformar o rice manual do
`vitoriamaria@MeowSystem` num repositório instalável, idempotente e reversível —
no mesmo espírito do `Dracula_OS-Theme`, mas nativo de COSMIC.

| | |
|---|---|
| Alvo | Pop!_OS 24.04 LTS · COSMIC 1.0.0 · cosmic-comp (Wayland) · 1920×1080 @60Hz |
| Paleta | Catppuccin Mocha (accent Mauve) — 4 flavors gerados |
| Repositório proposto | `[REDACTED]/MeowSystem-Theme` (GPL-3.0) |
| Integra com | `Andromeda-OS` (zsh) e `Spellbook-OS` |
| Data | 4 de agosto de 2026 |

---

## 0. Como usar este documento

**Passo 1 — me dê o estado real da máquina.** Tem 8 coisas que só o seu PC
responde (§8). Rode:

```bash
bash scripts/coleta-meowsystem.sh
```

Ele é 100% somente-leitura: não instala, não altera nada, gera um `.md` com todo
o inventário (configs do COSMIC arquivo por arquivo, temas de ícone, `.desktop`,
fontes, flatpaks, timers, wallpapers, GPU). Anexe o arquivo gerado na conversa.

Só a lista de apps:

```bash
bash scripts/listar-apps.sh            # tabela: id | nome | ícone | origem
bash scripts/listar-apps.sh --csv      # pra planilha
```

**Passo 2 — teste o tema hoje mesmo.** Já tem três `.ron` prontos em `assets/temas/`
(§2.5). Importe e veja se a direção agrada antes de escrever uma linha de código.

**Passo 3 — siga a `ESPECIFICACAO-DE-PARTIDA.md`.** Ela foi escrita pra ser
lida inteira, com sprints e critérios de aceite.

Legenda de confiança usada em todo o documento:
**[sim] verificado** nesta pesquisa · **[confira] validar** (existe, mas confirme nome/versão/estado) ·
**[nao] não existe** (com plano B).

---

## 1. Sua estética atual, decodificada

O `Estilo escuro.ron` que você exportou mostra que você **já tem um sistema** —
não é um tema aleatório. Vale preservar a estrutura e trocar só a paleta:

| Decisão sua | Valor | O que significa | No MeowSystem |
|---|---|---|---|
| `corner_radii` | tudo `8.0`, `xs: 2.0` | arredondado contido, sem cara de bolha | **preservado** |
| `gaps` | `(0, 5)` | sem borda externa, 5px entre janelas lado a lado | **preservado** |
| `active_hint` | `4` | contorno grosso na janela ativa — você quer saber onde está o foco | **preservado** |
| `frosted` | `VeryLow2` (α≈0.851) | vidro discreto, não translúcido demais | **preservado** |
| `frosted_windows/system_interface/panel/applets` | todos `true` | blur em tudo, coerente | **preservado** |
| `bg_color` | `#313250D9` | fundo **lilás-azulado** e translúcido (85%) | → `#313244D9` (Mocha `surface0`) |
| `accent` | `#E272F8` | magenta-orquídea saturado | → `#CBA6F7` (Mauve) ou `#F5C2E7` (Pink) |
| `primary_container_bg` | `#212A3F` | container azul-marinho profundo | → `#1E1E2E` (Mocha `base`) |
| `text_tint` | `#FCFCFC` | texto branco puro | → `#CDD6F4` (Mocha `text`) |
| `palette.name` | `cosmic-dark` | você manteve a paleta de fábrica e sobrescreveu o topo | → paleta Catppuccin completa |

**Achado bonito:** seu `bg_color` `#313250` é praticamente o `surface0` do
Catppuccin Mocha (`#313244`). Você já estava chegando lá no olhômetro. A troca de
paleta não vai mudar a *sensação* do seu desktop — vai só resolver a coerência
com todos os apps.

**Uma coisa a repensar:** `text_tint: #FCFCFC` (branco puro) sobre fundo escuro
dá contraste ~15:1, acima do que o Catppuccin desenha. `#CDD6F4` é mais macio nos
olhos em sessão longa. Se achar apagado, o meio-termo é `#DCE0F0`.

---

## 2. Paleta

### 2.1 Catppuccin Mocha — as 26 cores

| Papel | Nome | Hex | Onde aparece |
|---|---|---|---|
| Fundos | `crust` | `#11111B` | borda mais escura, moldura, disco da logo |
| | `mantle` | `#181825` | fundo do painel/dock, barras |
| | `base` | `#1E1E2E` | fundo da janela |
| | `surface0` | `#313244` | cartões, campos, seu `bg_color` |
| | `surface1` | `#45475A` | divisórias, botões inativos |
| | `surface2` | `#585B70` | bordas de foco fraco |
| Texto | `overlay0/1/2` | `#6C7086` `#7F849C` `#9399B2` | texto desabilitado → placeholders |
| | `subtext0/1` | `#A6ADC8` `#BAC2DE` | legendas, texto secundário |
| | `text` | `#CDD6F4` | texto principal |
| Acentos | `rosewater` | `#F5E0DC` | destaque quente sutil |
| | `flamingo` | `#F2CDCD` | idem, mais rosado |
| | `pink` | `#F5C2E7` | **candidato a accent** |
| | `mauve` | `#CBA6F7` | **accent recomendado** |
| | `red` | `#F38BA8` | erro / destrutivo |
| | `maroon` | `#EBA0AC` | erro secundário |
| | `peach` | `#FAB387` | aviso quente, laranja |
| | `yellow` | `#F9E2AF` | aviso |
| | `green` | `#A6E3A1` | sucesso |
| | `teal` | `#94E2D5` | info fria |
| | `sky` | `#89DCEB` | **olhos da logo** |
| | `sapphire` | `#74C7EC` | links |
| | `blue` | `#89B4FA` | seleção |
| | `lavender` | `#B4BEFE` | indigo / foco |

### 2.2 Mapa exato Catppuccin → slots do COSMIC

Isto é a tabela que o gerador do repositório precisa. Vale pra qualquer flavor
(troque os hex, mantenha os papéis):

| Slot COSMIC | Catppuccin | Mocha |
|---|---|---|
| `neutral_0` … `neutral_10` | crust, mantle, base, surface0, surface1, surface2, overlay0, overlay1, overlay2, subtext1, text | `#11111B` → `#CDD6F4` |
| `gray_1` / `gray_2` | mantle / base | `#181825` / `#1E1E2E` |
| `accent_blue` / `accent_indigo` | blue / lavender | `#89B4FA` / `#B4BEFE` |
| `accent_purple` / `accent_pink` | mauve / pink | `#CBA6F7` / `#F5C2E7` |
| `accent_red` / `bright_red` | red / maroon | `#F38BA8` / `#EBA0AC` |
| `accent_orange` / `bright_orange` | peach / peach | `#FAB387` |
| `accent_yellow` | yellow | `#F9E2AF` |
| `accent_green` / `bright_green` | green / teal | `#A6E3A1` / `#94E2D5` |
| `accent_warm_grey` / `ext_warm_grey` | flamingo / rosewater | `#F2CDCD` / `#F5E0DC` |
| `ext_blue` / `ext_indigo` | sapphire / blue | `#74C7EC` / `#89B4FA` |
| `ext_purple` / `ext_pink` | mauve / pink | `#CBA6F7` / `#F5C2E7` |
| `neutral_tint` | overlay0 | `#6C7086` |
| `bg_color` | surface0 **+ alpha `D9`** | `#313244D9` |
| `primary_container_bg` | base | `#1E1E2EFF` |
| `text_tint` | text | `#CDD6F4FF` |
| `accent` | mauve *(ou pink)* | `#CBA6F7FF` |
| `success` / `warning` / `destructive` | green / yellow / red | `#A6E3A1` / `#F9E2AF` / `#F38BA8` |

### 2.3 Os outros flavors (mesmo mapa, outros hex)

| | crust | base | surface0 | text | mauve | pink |
|---|---|---|---|---|---|---|
| **Mocha** (mais escuro) | `#11111B` | `#1E1E2E` | `#313244` | `#CDD6F4` | `#CBA6F7` | `#F5C2E7` |
| **Macchiato** | `#181926` | `#24273A` | `#363A4F` | `#CAD3F5` | `#C6A0F6` | `#F5BDE6` |
| **Frappé** (mais suave) | `#232634` | `#303446` | `#414559` | `#C6D0F5` | `#CA9EE6` | `#F4B8E4` |
| **Latte** (claro) | `#DCE0E8` | `#EFF1F5` | `#CCD0DA` | `#4C4F69` | `#8839EF` | `#EA76CB` |

Recomendação: **Mocha como padrão** (você já roda escuro e translúcido),
**Latte** só como tema de modo-claro automático por horário — o COSMIC alterna
sozinho (`CosmicTheme.Mode` → `auto_switch`).

### 2.4 Mauve ou Pink?

Seu accent atual (`#E272F8`) fica exatamente entre os dois. Mauve `#CBA6F7` é o
vizinho direto em matiz e é o accent canônico do Catppuccin; Pink `#F5C2E7` é
mais pastel e conversa melhor com o wallpaper do gato rosa. Entreguei os dois
prontos — importe, olhe 10 minutos em cada, decide com os olhos.

### 2.5 Arquivos já prontos neste projeto

| Arquivo | O que é |
|---|---|
| `assets/temas/meowsystem-mocha-mauve.ron` | **recomendado** — sua estrutura + Mocha + accent Mauve |
| `assets/temas/meowsystem-mocha-pink.ron` | igual, accent Pink e `window_hint` Mauve |
| `assets/temas/meowsystem-macchiato-mauve.ron` | base um tom mais claro, se Mocha ficar pesado |

Importar: **Configurações → Área de trabalho → Aparência → Importar**.

**Correção importante (verificada no seu PC):** o `cosmic-settings` **não tem**
subcomando de aplicar tema — o `--help` só lista páginas de configuração
(`appearance`, `dock`, `panel`…). A automação não passa por CLI. O caminho real
está na §8.4.

---

## 3. O que já existe de Catppuccin (auditoria)

### 3.1 Núcleo

| Repo | Para quê | Status |
|---|---|---|
| `catppuccin/cosmic-desktop` | temas `.ron` do COSMIC + esquemas do cosmic-term, 4 flavors × todos os accents | [sim] existe, MIT, ~260 |
| `catppuccin/whiskers` | gerador (templates Tera) usado por eles | [sim] |
| `catppuccin/palette` | as cores canônicas em formato de máquina | [confira] validar nome do arquivo/API |
| `catppuccin/papirus-folders` | pastas do Papirus recoloridas, `cat-<flavor>-<cor>` | [sim] verificado |
| `catppuccin/cursors` | tema de cursor | [confira] validar release |
| `cosmic-themes.org` | galeria da comunidade (tem Catppuccin publicado) | [sim] |

O `catppuccin/cosmic-desktop` aceita overrides na geração — e são exatamente os
eixos que você já configurou à mão:

```bash
whiskers templates/cosmic-settings.tera \
  --flavor mocha \
  --overrides='{"accent":"mauve","roundness":"slightlyround","bg_alpha":0.85,"frosted":true,"outer_gap_size":0,"inner_gap_size":5,"active_hint_size":4}'
```

Opções disponíveis: `accent`, `roundness` (`round`/`slightlyround`/`square`),
`window_hint_color`, `bg_alpha` (0.0–1.0), `frosted` (bool), `outer_gap_size`,
`inner_gap_size`, `active_hint_size`. Flavors: `latte`, `frappe`, `macchiato`, `mocha`.

**Decisão de arquitetura:** o repositório deve usar o `whiskers` como gerador
oficial (upstream cuida de mudanças de schema do COSMIC) **e** manter os `.ron`
gerados versionados em `assets/temas/`, pra instalação funcionar sem toolchain Rust.

### 3.2 Por app — os que você usa

> **Corrigido pelo inventário:** você **não tem** kitty (usa o cosmic-term) —
> ignore esse port. Spotify, Discord e Telegram você vai instalar: ficam no
> catálogo como **pendentes** e são tematizados sozinhos quando aparecerem.
> A lista real dos seus 183 apps está na §8.7.

| App (no seu launcher / no Dracula_OS) | Caminho Catppuccin | Status |
|---|---|---|
| COSMIC (painel, dock, applets, Configurações, Files, Edit) | `catppuccin/cosmic-desktop` → `.ron` | [sim] |
| cosmic-term | `assets/temas/cosmic-term/*.ron` do mesmo repo |  |
| GTK3 / GTK4 / Flatpak | **não precisa de tema GTK**: o COSMIC gera o CSS a partir do tema quando "aplicar tema global" está ligado ([sim] documentado pela System76) | [sim] |
| Qt / KDE (você usa `breeze-dark`) | Catppuccin Kvantum / qt5ct | [confira] validar |
| Firefox | o tema global do COSMIC já alcança o Firefox ([sim] System76); reforço opcional com userChrome | [sim] / [confira] |
| Chrome / Chromium | via extensão de userstyles | [confira] |
| kitty | `catppuccin/kitty` | [confira] validar |
| Spotify (Spicetify) | `catppuccin/spicetify` | [confira] validar |
| Obsidian | `catppuccin/obsidian` | [confira] validar |
| Telegram Desktop | port oficial (`.tdesktop-theme`) | [confira] validar |
| Discord / Vesktop | `catppuccin/discord` | [confira] validar |
| qBittorrent | port oficial | [confira] validar se cobre app Qt ou só WebUI |
| VS Code / Zed | ports oficiais | [sim] (Zed verificado) |
| OnlyOffice | sem port conhecido | [nao] → tema escuro nativo + recolor manual |
| Foliate, Apostrophe, BleachBit, Flatseal, GParted, Gradia, File Roller, Calculadora | apps GTK → herdam do tema global | [sim] automático |
| Boxy SVG (Electron) | sem port | [nao] → tema escuro nativo |
| zsh (`Andromeda-OS`) | trocar paleta Dracula do `functions/_helpers.zsh`; `catppuccin/zsh-syntax-highlighting` | [confira] |
| bat, btop, fzf, delta, starship, lazygit | ports oficiais | [confira] validar um a um |
| fastfetch | sem port; logo ASCII + cores da paleta (§4.9) | [nao] → fazemos |
| Sons do sistema | Catppuccin não tem tema de som | [nao] → reaproveitar os 25 `.oga` CC0 do `Dracula_OS-Theme` |

**Instrução importante para quem construir:** não confiar nesta tabela como verdade
final. O primeiro passo do build é **gerar** o catálogo consultando a lista
oficial de ports do `catppuccin/catppuccin` e cruzando com a saída de
`listar-apps.sh`. Assim o `catalog.json` do repo nasce verificado, e um port novo
aparece sozinho na próxima execução.

### 3.3 Ícones — o buraco real

**Não existe tema de ícones Catppuccin oficial completo.** Isso é o principal
trabalho artesanal do projeto. Quatro caminhos, em ordem de custo/benefício:

1. **Papirus + `catppuccin/papirus-folders`** ([sim] verificado, mais barato).
   Cobre pastas com precisão Catppuccin e ~4000 ícones de app do Papirus.
   ```bash
   sudo apt install papirus-icon-theme
   git clone https://github.com/catppuccin/papirus-folders
   sudo cp -r papirus-folders/src/* /usr/share/icons/Papirus
   papirus-folders -C cat-mocha-mauve --theme Papirus-Dark
   ```
   Melhor prática pro repo: **não** editar `/usr/share`; copiar o Papirus pra
   `~/.local/share/icons/MeowSystem-Icons/` e aplicar as pastas lá, deixando o
   sistema intocado (idempotente, reversível).
2. **`Cosmictron`** (comunidade, `SethStormR/Cosmictron`) — feito *para* o
   COSMIC, 8 cores, acompanha `.ron` e wallpapers. [confira] Tem o detalhe conhecido de
   precisar remover `Places/16` pra pastas renderizarem.
3. **Fork recolorido do `pop-os/cosmic-icons`** (CC-SA-4.0): pegar os SVGs
   nativos do COSMIC e trocar as cores pela paleta — via mapa de cores exato
   (`sed` em `fill=`) ou remapeamento perceptual com `lutgen`. Vantagem:
   cobertura 1:1 com o que o COSMIC realmente pede, licença compatível.
4. **Ícones autorais** (como sua logo do gato) para os apps que você mais usa —
   20 a 30 ícones, não 4000.

Recomendação: **1 como base + 3 para os ícones de sistema + 4 para os seus
favoritos**, com herança em cascata (§4.5). Igual à estratégia
`Inherits=` do `Dracula_OS-Theme`, que funcionou.

### 3.4 Wallpapers

- `zhichaoh/catppuccin-wallpapers` — coleção da comunidade, wallpapers já dentro
  da paleta, organizados em pastas [confira] (não é repo oficial do Catppuccin, então o
  instalador deve pinar um commit e não seguir `main` cegamente). É a fonte mais
  prática pra encher a pasta de rotação no primeiro dia.
- `pop-os/cosmic-wallpapers` — os oficiais do COSMIC
- **O melhor caminho pro seu caso:** recolorir *suas* imagens pra paleta.
  `lutgen` (CLI, [confira] validar nome do pacote) aplica um LUT Catppuccin em qualquer
  foto. Seu gato rosa continua sendo seu gato — só passa a ser Catppuccin de fato,
  em vez de rosa-vizinho. Um único comando por imagem, resultado reprodutível,
  e o repo guarda o script, não as fotos (peso).

Estratégia da pasta de rotação: `~/.local/share/backgrounds/meowsystem/` com três
origens misturadas — os da coleção da comunidade (pinada), os oficiais do COSMIC
e os **seus** recoloridos. `rotation_frequency` nativo cuida do resto (§4.4).

---

## 4. Como o COSMIC se veste (especificação)

Esta seção é o que substitui a "papelada do COSMIC": não existe uma referência
única publicada de theming; o que existe é o schema RON (que seu export
revelou), a estrutura de configuração e o comportamento observável.

### 4.1 Anatomia de `~/.config/cosmic`

Cada componente tem um diretório `com.system76.<Componente>/v1/` e **cada
chave é um arquivo separado** contendo um valor RON. Padrões do sistema em
`/usr/share/cosmic/<mesma estrutura>` ([sim] confirmado no empacotamento do `cosmic-bg`).

```
~/.config/cosmic/
├── com.system76.CosmicTheme.Mode/v1/        is_dark, auto_switch
├── com.system76.CosmicTheme.Dark/v1/        tema ativo escuro (o schema do seu .ron)
├── com.system76.CosmicTheme.Light/v1/       idem, claro
├── com.system76.CosmicTheme.Dark.Builder/   estado do editor de tema
├── com.system76.CosmicTk/v1/                icon_theme, apply_theme_global, fontes
├── com.system76.CosmicComp/v1/              tiling, gaps, foco, atalhos do compositor
├── com.system76.CosmicPanel/v1/entries      quais painéis existem
├── com.system76.CosmicPanel.Panel/v1/       painel de cima
├── com.system76.CosmicPanel.Dock/v1/        dock de baixo
├── com.system76.CosmicBackground/v1/        all, backgrounds, same-on-all, output.*
├── com.system76.CosmicAppList/v1/favorites  favoritos do dock
├── com.system76.CosmicSettings/v1/          atalhos personalizados
├── com.system76.CosmicTerm/v1/              fonte, color_scheme_dark/light
├── com.system76.CosmicFiles/v1/ · CosmicEdit · CosmicIdle · CosmicWorkspaces · portal/
```

Consequências práticas pro instalador:
- **Editar chave = escrever um arquivo pequeno.** Fácil de versionar, fácil de
  fazer backup, fácil de reverter. Nada de `dconf dump`.
- **Um `git diff` de `~/.config/cosmic` é o diff do seu rice.** O repo deve ter
  um comando `capturar` que copia essa árvore pra `state/` (é o equivalente do
  seu `capturar` do Andromeda-OS, mas pro visual).
- Alterações são lidas a quente por watcher; **quase nada exige logout**. O que
  exige, o instalador avisa.

### 4.2 O schema do tema

Confirmado pelo seu export (COSMIC 1.0.x): `palette: Dark((...))` com 32 slots,
`spacing` (10 degraus), `corner_radii` (6 degraus × 4 cantos), `neutral_tint`,
`bg_color`, `primary_container_bg`, `secondary_container_bg`, `text_tint`,
`accent`, `success`, `warning`, `destructive`, `frosted` (enum de nível),
`gaps: (externo, interno)`, `active_hint`, `window_hint`, quatro flags
`frosted_*` e o `alpha_map` de 14 níveis.

Regras que valem ouro na hora de gerar:
- cores são `#RRGGBBAA` — **o alpha faz parte da string** (é assim que você tem
  fundo translúcido: `#313244D9`);
- `Some(...)` / `None` distinguem "eu escolhi" de "derive da paleta";
- `frosted` é enum (`VeryLow2`, etc.), não booleano nem número;
- `alpha_map` tem 14 chaves com float — copiar do export existente, nunca inventar;
- ordem dos campos não importa pro parser, mas manter a ordem do export facilita `diff`.

### 4.3 Painel, dock e applets

`CosmicPanel.Panel` / `CosmicPanel.Dock` guardam ancoragem, tamanho, opacidade,
autohide, expansão até as bordas e, principalmente, **as listas de plugins**
(`plugins_center`, `plugins_wings`) — que são IDs de applet. Um applet é um
`.desktop` marcado como applet do COSMIC + um binário. É por isso que:

- adicionar/remover applet = editar uma lista;
- o ícone do applet vem do `Icon=` do `.desktop` dele, resolvido pelo tema de
  ícones. **É esse o gancho que você já usou pro gato** — e é ele que o repo vai
  automatizar (§4.5);
- existem applets da comunidade (`cosmic-ext-applet-*`) instaláveis;
- **animação de verdade no painel só existe dentro de um applet próprio** (§4.8).

### 4.4 Wallpaper e rotação

`com.system76.CosmicBackground/v1/` tem `all` (config aplicada a todas as saídas),
`backgrounds`, `same-on-all` e `output.<NOME>` por monitor. Cada entrada é um RON
com a fonte (`Path(...)`), modo de escala, filtro e **`rotation_frequency` em
segundos** — ou seja, **variação de wallpaper é nativa**: apontar para uma pasta
e definir a frequência. Editar o arquivo direto é o caminho confiável (a UI já
teve bug conhecido de não aceitar imagens novas).

Pra ir além do estático existe `cosmic-ext-bg` (comunidade, drop-in do
`cosmic-bg`): wallpaper em **vídeo**, GIF animado, shader WGSL e slideshow por
CLI (`cosmic-ext-bg-ctl set ~/Wallpapers/ -r 300`). É o substituto natural do
`--video-wallpaper` (xwinwrap+mpv) do `Dracula_OS-Theme`, que **não funciona no
Wayland**. [confira] Trocar um serviço de sessão do COSMIC por um fork é a decisão mais
arriscada do projeto: entra como flag opcional (`--wallpaper-animado`), nunca no
`--all`, e com rollback documentado.

### 4.5 Ícones: como o COSMIC encontra o seu gato

Vale a especificação XDG de temas de ícone:

```
~/.local/share/icons/MeowSystem-Icons/
├── index.theme                 # Name=, Inherits=Papirus-Dark,Cosmic,Adwaita,hicolor
├── scalable/apps/*.svg         # ícones coloridos de app
├── symbolic/apps/*-symbolic.svg# ícones monocromáticos de status/ação
├── {16,22,24,32,48,64,128,256}x{...}/apps/*.png
└── ...
```

Confirmado pelo empacotamento oficial: o COSMIC instala seus próprios ícones em
`hicolor/scalable/apps/com.system76.X.svg` e
`hicolor/symbolic/apps/com.system76.X-symbolic.svg`. Logo, **os nomes que o
COSMIC pede são reverse-DNS pros apps dele** e nomes freedesktop padrão pros
ícones de sistema.

Os ícones de sistema que você citou (wifi e cia.) seguem a nomenclatura
freedesktop — a lista que o tema precisa cobrir:

```
network-wireless-signal-{none,weak,ok,good,excellent}-symbolic
network-wireless-{offline,acquiring,hotspot}-symbolic  network-wired-symbolic
network-vpn-symbolic  airplane-mode-symbolic
bluetooth-{active,disabled,acquiring}-symbolic
battery-level-{0..100}[-charging]-symbolic  battery-{full-charged,missing}-symbolic
audio-volume-{muted,low,medium,high}-symbolic  audio-input-microphone-symbolic
display-brightness-symbolic  preferences-system-symbolic  system-shutdown-symbolic
window-{close,minimize,maximize}-symbolic  view-more-symbolic  go-{next,previous}-symbolic
folder-symbolic  user-trash-symbolic  edit-{find,copy,paste,delete}-symbolic
```

**Detalhe que muda o plano:** ícones `-symbolic` são desenhados pelo toolkit com
a cor do tema (é por isso que os ícones do seu painel já acompanham o accent).
Ou seja: **não é preciso recolorir os ícones de wifi** — o `.ron` já resolve a
cor. Um tema de ícones serve pra mudar **forma**, não cor, nos symbolic. Isso
precisa de confirmação empírica na sua máquina (está no roteiro do sprint 1:
trocar um symbolic por um SVG vermelho puro e ver se aparece vermelho ou accent).

Para a logo do gato, o alvo é o `Icon=` do applet da biblioteca de aplicativos
(algo como `com.system76.CosmicAppLibrary`): coloca-se um
`scalable/apps/<esse-nome>.svg` no seu tema e ele sobrescreve o de fábrica sem
tocar em `/usr/share`. O inventário vai me dar o nome exato.

Arquivos entregues aqui (prontos):

| Arquivo | Uso |
|---|---|
| `assets/meow-<flavor>.svg` | gato **cinza** (`surface2`) com olhos amarelos — variante padrão |
| `assets/meow-<flavor>-preto.svg` | gato **preto** (`crust`) com olhos amarelos, sobre disco `surface0` pra ele aparecer |
| `assets/meow-symbolic.svg` | monocromática 16px (`currentColor`, olhos vazados) pro painel |

Ambas as pelagens existem nos 4 flavors. No Latte o disco é verde (`#A6E3A1`) em
vez de cinza. No `meow.conf`, `LOGO="mocha"` ou `LOGO="mocha-preto"`.

Depois de instalar qualquer ícone: `gtk-update-icon-cache -f ~/.local/share/icons/MeowSystem-Icons`.

### 4.6 GTK, Flatpak e Qt

- **GTK3/GTK4**: com "aplicar tema global" ligado (`CosmicTk` → `apply_theme_global`),
  o COSMIC **gera** o CSS a partir do seu tema e aplica em GTK3, GTK4 e apps
  Flatpak ([sim] documentado pela System76). Isso apaga metade do trabalho do
  `Dracula_OS-Theme`: não há tema GTK a manter, nem `dark.css` de extensão pra
  substituir.
- **Flatpak**: além disso, pode precisar de acesso aos temas/ícones do usuário:
  `flatpak override --user --filesystem=xdg-data/icons:ro`.
- **Qt** (você tem `breeze-dark`): fora do alcance do tema COSMIC. Caminho é
  `qt5ct`/`qt6ct` + Kvantum com um tema Catppuccin, ou aceitar o breeze-dark.

### 4.7 Atalhos, login e sons

- Atalhos personalizados ficam em `CosmicSettings` (você já tem
  `configurar-atalhos-cosmic.sh` no Andromeda-OS — o repo de tema **não deve**
  duplicar isso, só referenciar).
- Tela de login: `cosmic-greeter` usa o tema do sistema; wallpaper próprio é
  configuração separada ([confira] validar caminho no inventário).
- Sons: Catppuccin não tem tema de som [nao]. Plano B: reaproveitar os 25 `.oga`
  CC0 (Kenney) que o `Dracula_OS-Theme` já empacotou.

### 4.8 Limites honestos

| Você pediu | Realidade | O que dá pra fazer |
|---|---|---|
| Ícones animados no dock/painel | [nao] Não existe. Ícone XDG é SVG estático; o renderizador não executa animação SMIL/CSS. | (a) **applet próprio** em Rust/libcosmic que redesenha o ícone num timer — animação real, é a única via legítima no painel; (b) cursor animado (XCursor é multi-frame por spec); (c) wallpaper animado (§4.4) |
| Substituir CSS do shell (como `pop-shell-dark.css`) | [nao] COSMIC não tem CSS. É Rust + RON tipado. | Tudo pelo `.ron` + configs de painel. Menos poder de gambiarra, muito mais estabilidade |
| Blur / vidro | [sim] Existe (`frosted*`) e você já usa | Manter; custo de GPU é irrelevante na sua 4060 |
| Tema em app proprietário (OnlyOffice, Boxy SVG) | [nao] Sem port | Tema escuro nativo do app; não prometer coerência total |

Dizer isso agora evita a decepção de descobrir no meio do caminho. O rice fica
excelente sem ícone animado — e se você quiser mesmo o gato piscando no painel,
é um applet, e é um projeto à parte (sprint 8, opcional).

### 4.9 Extras que fecham o conjunto

- **fastfetch**: `~/.config/fastfetch/config.jsonc` aceita logo customizada
  (`"logo": {"source": "~/.config/fastfetch/meow.txt", "type": "file-raw"}`) —
  é ali que entra um gato em ASCII com as cores Catppuccin, no lugar do
  logotipo do Pop!_OS que aparece hoje no seu terminal.
- **assets/zsh/Andromeda-OS**: o `functions/_helpers.zsh` tem "Paleta Dracula" —
  virar Catppuccin ali propaga pra todos os 27 módulos de uma vez.
- **Documentos e apps do dia a dia** (`bat`, `btop`, `fzf`, `delta`) fecham a
  sensação de "tudo combina" com muito pouco esforço.

---

## 5. Arquitetura do repositório

Herdando o que já funciona no `Dracula_OS-Theme` (build reprodutível,
install/uninstall reversível, backups automáticos, hook pós-upgrade) e cortando
o que não existe no COSMIC (tema GTK, CSS de shell, extensões GNOME):

```
MeowSystem-Theme/
├── README.md · CHANGELOG.md · LICENSE (GPL-3.0)
├── install.sh              # --user --all --dry-run --update --bootstrap ...
├── uninstall.sh            # seletivo, restaura backups
├── build.sh                # gera dist/ (temas + ícones + PNGs multi-tamanho)
├── catalog.json            # GERADO: apps × port Catppuccin × status
├── mapping.json            # app_id -> ícone (curado; regeneração preserva edições)
├── assets/paleta/
│   ├── catppuccin.json     # 4 flavors × 26 cores (fonte única de verdade)
│   └── cosmic-map.json     # o mapa da §2.2
├── assets/temas/
│   ├── cosmic/*.ron        # flavor × accent (gerados, versionados)
│   └── cosmic-term/*.ron
├── src/
│   ├── assets/icones/
│   │   ├── autorais/       # sua logo do gato + ícones que você desenhar
│   │   ├── overrides/      # symbolic de sistema com forma customizada
│   │   └── upstream/       # (git-ignored) Papirus/cosmic-icons baixados
│   ├── assets/papeis-de-parede/         # scripts de recolorização (não as fotos)
│   ├── sounds/             # .oga CC0 herdados do Dracula_OS
│   └── fastfetch/          # meow.txt (ASCII art) + config.jsonc
├── assets/temas-de-apps/             # kitty, spicetify, obsidian, discord, telegram, bat, btop...
├── state/                  # snapshot de ~/.config/cosmic (capturar/restaurar)
├── scripts/
│   ├── coleta.sh           # o inventário read-only (já existe aqui)
│   ├── listar-apps.sh      # (já existe aqui)
│   ├── gerar_temas.py      # palette + cosmic-map -> .ron (todos os combos)
│   ├── gerar_catalogo.py   # ports oficiais × apps instalados -> catalog.json
│   ├── construir_icones.sh # herança + recolorização + PNGs + cache
│   ├── aplicar_tema.sh     # importa .ron (CLI do cosmic-settings, fallback: escrever config)
│   ├── wallpaper.sh        # pasta + rotation_frequency; recolorir com lutgen
│   ├── diagnostico.sh      # detecta regressões (exit 1 = tem coisa errada)
│   ├── reaplicar.sh        # conserta só o que regrediu (idempotente)
│   └── instalar_hooks.sh   # hook APT + timer systemd --user
└── docs/
    ├── COSMIC-THEMING.md   # esta §4, mantida como referência viva
    └── sprints/
```

### 5.1 Flags do `install.sh` (proposta)

```
--dry-run            mostra o que faria, não escreve nada
--user               instala em ~/.local/share e ~/.config (padrão, sem sudo)
--tema               aplica o .ron (flavor/accent de config.local)
--icones             constrói e ativa MeowSystem-Icons
--logo               instala a logo do gato como ícone do menu/dock
--wallpapers         copia + configura rotação nativa
--wallpaper-animado  cosmic-ext-bg (OPT-IN, risco documentado)
--app-themes         kitty, spicetify, obsidian, discord, bat, btop, fzf...
--fastfetch          logo ASCII do gato + cores
--sons               tema de som CC0
--auto-reparo        hook APT + timer systemd que reaplica após upgrade
--all                tudo acima menos --wallpaper-animado
--bootstrap          PC formatado: checa dependências, baixa upstreams, build, install --all
--update             preserva config.local e escolhas curadas
```

### 5.2 "Que ele sempre arrume meu PC"

Três camadas, todas idempotentes:

1. **`diagnostico.sh`** — verifica: tema ativo é o nosso? `icon_theme` é o nosso?
   `apply_theme_global` ligado? logo no lugar? rotação de wallpaper configurada?
   app-themes intactos? Saída legível + código de saída.
2. **`reaplicar.sh`** — conserta **só** o que o diagnóstico apontou.
3. **Gatilhos** — hook APT (após todo `apt`), `flatpak` (pós-update, via timer)
   e um `systemd --user` timer diário. Log em `~/.local/state/meowsystem/`.

Regra de ouro: **todo passo faz backup antes** (com manifesto sha256, retendo as
N últimas versões, como o `--gimp` do Dracula_OS já faz) e todo passo é
re-executável sem duplicar efeito.

### 5.3 Integração com o que você já tem

- `Andromeda-OS`: função `rebuild_meow_theme` (build + install + diagnóstico),
  paleta do `_helpers.zsh` virando Catppuccin, e o `capturar`/`restaurar` do
  manifesto passando a incluir `~/.config/cosmic`.
- `Spellbook-OS`: reaproveitar o setup de Spicetify em vez de reimplementar.
- Nomenclatura: scripts em português, como nos seus dois repos.

---

## 6. Sprints

| # | Entrega | Depende de |
|---|---|---|
| 0 | Inventário (`coleta.sh`) + esqueleto do repo + `assets/paleta/` | você rodar o script |
| 1 | `gerar_temas.py` → todos os `.ron`; `aplicar_tema.sh`; confirmar CLI do cosmic-settings; **teste do symbolic** (§4.5) | 0 |
| 2 | Logo do gato instalada como ícone do menu/dock/greeter + PNGs multi-tamanho | 1 |
| 3 | `MeowSystem-Icons`: herança Papirus + pastas Catppuccin + `mapping.json` gerado dos seus `.desktop` | 0, 2 |
| 4 | Wallpapers: pasta + rotação nativa + recolorização das suas fotos | 0 |
| 5 | App-themes tier 1 (cosmic-term, kitty, bat, btop, fzf, fastfetch, zsh) | 1 |
| 6 | App-themes tier 2 (Spicetify, Obsidian, Discord, Telegram, qBittorrent) | 5 |
| 7 | Auto-reparo: diagnóstico + reaplicar + hook APT + timer | 1–6 |
| 8 | *Opcional:* wallpaper animado; applet animado do gato; tema de som; Latte automático por horário | 7 |

---

## 7. A especificação de partida

Está em **`ESPECIFICACAO-DE-PARTIDA.md`**. Ela inclui: contexto da
máquina, princípios não-negociáveis, a estrutura exigida, os sprints com
critérios de aceite, os comandos de descoberta que se **deve** rodar antes
de escrever código, e a regra anti-invenção (nunca chutar caminho, chave ou nome
de repositório — verificar primeiro).

---

## 8. Respostas do inventário — 04/08/2026, 12:52

As 8 perguntas foram respondidas. O que mudou no plano:

### 8.1 Você não está no 1.0.0

O fastfetch mostra "COSMIC 1.0.0", mas os pacotes são de junho/2026:
`cosmic-settings 1.0.12`, `cosmic-applets 1.0.15`, `cosmic-files 1.5.0`,
`cosmic-launcher 1.0.12`. Está atualizada. Aquele "1.0.0" é rótulo genérico da
sessão. **Cai o pré-requisito de atualizar o sistema.**

### 8.2 A logo é trivial — e não passa por tema de ícones

O gato do painel é o applet **`dev.cappsy.CosmicExtAppletLogoMenu`** (Flatpak,
remote `cosmic`, v0.8.0), e ele já tem as chaves prontas:

```ron
~/.config/cosmic/dev.cappsy.CosmicExtAppletLogoMenu/v1/custom_logo_active  → true
~/.config/cosmic/dev.cappsy.CosmicExtAppletLogoMenu/v1/custom_logo_path    → "/home/vitoriamaria/.config/cosmic/logos/gato-pop.svg"
~/.config/cosmic/dev.cappsy.CosmicExtAppletLogoMenu/v1/logo                → "SteamDeck (Blue)"
```

Trocar o gato é **copiar um SVG e apontar uma string**. Dá pra fazer agora:

```bash
cp assets/meow-mocha.svg ~/.config/cosmic/logos/meow-mocha.svg
printf '"%s"' "$HOME/.config/cosmic/logos/meow-mocha.svg" \
  > ~/.config/cosmic/dev.cappsy.CosmicExtAppletLogoMenu/v1/custom_logo_path
```

O segundo gato (canto inferior esquerdo) é outro caminho: o
**`com.system76.CosmicPanelAppButton`** no dock, que pega o ícone pelo nome
`com.system76.CosmicPanelAppButton` no tema de ícones. Esse sim precisa do
`MeowSystem-Icons` (ou de um arquivo em `~/.local/share/icons/hicolor/scalable/apps/`).

### 8.3 Não existe CLI de tema

`cosmic-settings --help` lista só páginas (`appearance`, `panel`, `dock`, …).
Nenhum `apply`/`import`.

### 8.4 Como aplicar tema sem GUI (o caminho real)

O tema vive espalhado em arquivos-chave, e existem **duas versões de schema
convivendo** na sua máquina:

```
com.system76.CosmicTheme.Dark/v1/*          e  .../v2/*     (tema calculado: 30+ chaves)
com.system76.CosmicTheme.Dark.Builder/v1/*  e  .../v2/*     (o que a GUI edita: 17 chaves)
com.system76.CosmicTheme.Light[.Builder]/v1|v2/*
com.system76.CosmicTheme.Mode/v1/{is_dark,auto_switch}
```

Escrever isso à mão é frágil (o `Dark/v1/*` é **derivado** do Builder pela
lógica do cosmic-settings, não é cópia). Então o `install.sh` usa
**importar-uma-vez → capturar → restaurar**:

1. você importa o `.ron` pela GUI (uma vez, 10 segundos);
2. `scripts/capturar_tema.sh` copia as 4 árvores + `Mode` para `assets/temas/capturados/<nome>/`;
3. daí em diante `aplicar_tema.sh` **restaura por cópia de arquivo** — 100%
   automático, idempotente, e reversível.

Isso também resolve o Latte: importa uma vez, captura, e a alternância por
horário passa a ser trocar `Mode/v1/is_dark`.

### 8.5 Ícones: você está no `breeze-dark`

`CosmicTk/v1/icon_theme` → `"breeze-dark"`. `apply_theme_global` → `true`
(por isso o GTK acompanha). `header_size` e `interface_density` → `Compact`.
Instalados: breeze, adwaita, humanity, pop, ubuntu-mono, hicolor. **Papirus não
está instalado** — o sprint 3 começa com `sudo apt install papirus-icon-theme`.
Locais só existem `hicolor` e `steam-jogos` (do patcher de jogos).

### 8.6 Tema global do GTK: confirmado na prática

```css
/* ~/.config/gtk-3.0/gtk.css e gtk-4.0/gtk.css */
/* GENERATED BY COSMIC */
@define-color window_bg_color rgba(49, 50, 80, 0.85);
```

É o seu `bg_color` `#313250D9` traduzido. Confirma a §4.6: **não há tema GTK a
manter**. Qt fica de fora (você usa `QT_QPA_PLATFORMTHEME=qt5ct`) → Kvantum
Catppuccin entra como item próprio.

### 8.7 Seus 183 apps — o que muda no catálogo

Tem `.desktop` e importa pro tema:

| Grupo | Apps |
|---|---|
| COSMIC (herdam o `.ron`) | Term, Files, Edit, Store, Player, Monitor, Screenshot, Settings, Workspaces |
| GTK/Flatpak (herdam o global) | Foliate, Apostrophe, Gradia, Calculator, Snapshot, File Roller, Warehouse, Upscaler, BleachBit, Flatseal, Evince, Baobab, Disks, Fonts, Seahorse |
| Qt (via qt5ct/Kvantum) | Krita, qBittorrent, VLC, ProtonUp-Qt, GParted |
| Com port Catppuccin próprio | VS Code, Obsidian, qBittorrent, Firefox, Chrome, OBS, GIMP, Steam |
| A instalar (já previstos, marcados `pendente`) | — instalados em 04/08: Thunderbird (apt), Brave, Discord, Telegram e Spotify (Flatpak) |
| Sem port (tema escuro nativo) | OnlyOffice, Boxy SVG, LibreOffice, Popsicle, Repoman |
| **Seus** | `Hefesto - Dualsense4Unix`, `FogStripper` — merecem ícone autoral no `MeowSystem-Icons` |

Applets instalados além dos oficiais: LogoMenu, Drives, Clipboard Manager,
External Monitor Brightness, Connected, YapCap, CosmicTweaks.

### 8.8 Painel e dock — a sua planta (preservar exatamente)

```
Panel:  anchor Top · size XS · opacity 0.1 · background ThemeDefault · autohide OnOverlap
  wings esq:  LogoMenu, Battery, external-monitor-brightness, Workspaces
  centro:     Notifications, Time
  wings dir:  StatusArea, Drives, clipboard-manager, Bluetooth, Tiling, Audio, Network, Power
Dock:   size M · centro: CosmicAppList · wing esq: CosmicPanelAppButton
```

O instalador **não toca** nessas listas. Backup antes, diff depois.

### 8.9 Wallpaper: a rotação está ligada e não roda

```ron
rotation_frequency: 300,
source: Path(".../Cyberpunk Neon Cat Wallpaper _ Synthwave Vibe .jpeg"),
backgrounds: []
```

Frequência de 5 min configurada, mas a fonte é **um arquivo só** — por isso nunca
troca. Basta apontar `source` para uma pasta. Você tem `same-on-all: true` e
ainda assim arquivos `output.DP-1` e `output.HDMI-A-1` (esse último de um monitor
que não está conectado agora — só DP-1 aparece no `cosmic-randr`).

### 8.10 Ferramentas: o que falta instalar

Tem: `rsvg-convert`, `convert` (ImageMagick 6), `gtk-update-icon-cache`, `fzf`,
`fastfetch`, `zsh`. Faltam: `papirus-icon-theme`, `lutgen` (recolorir wallpaper),
`whiskers` (opcional), `bat`, `btop`. Seu fastfetch está com
`"logo": {"type": "builtin", "source": "pop"}` — é ali que o gato ASCII entra
(arquivos prontos em `assets/fastfetch/`).

### 8.11 cosmic-term é o seu terminal — e ainda está no padrão

```ron
com.system76.CosmicTerm/v1/  →  font_size: 14 · opacity: 96 · use_bright_bold: true
                                focus_follow_mouse: true · shortcuts_custom: {…}
```

Não existe chave de esquema de cores ainda — ela só nasce quando você importa um
esquema pela primeira vez (**Ver → Esquemas de cores… → Importar**, com
`assets/temas/cosmic-term/*.ron` do `catppuccin/cosmic-desktop`). Por isso o sprint 5
usa a mesma técnica do tema: importa uma vez, diffa o `~/.config` pra descobrir
onde foi parar, e automatiza por cópia. Suas preferências (fonte 14, opacidade
96, negrito brilhante) são preservadas.

---

## 9. Riscos

| Risco | Mitigação |
|---|---|
| Trocar `cosmic-bg` por fork da comunidade | flag opt-in, fora do `--all`, rollback documentado |
| Upgrade do COSMIC mudar o schema do `.ron` | gerar via `whiskers` (upstream acompanha) + `diagnostico.sh` detecta e avisa |
| Perder seu tema atual | `state/` guarda o `Estilo escuro.ron` original; `uninstall.sh` restaura |
| Editar `/usr/share` (Papirus) e quebrar no `apt upgrade` | copiar pro `~/.local/share/icons/`; nunca escrever em `/usr/share` |
| Ports Catppuccin fora do ar / renomeados | `catalog.json` gerado + falha graciosa por app |
| Você estar no COSMIC 1.0.0 e a doc/CLI ser 1.0.13 | atualizar o sistema é o passo zero do sprint 1 |

---

## 10. Créditos e licenças

- **Catppuccin** — MIT · `catppuccin/cosmic-desktop`, `papirus-folders`, `whiskers`
- **COSMIC / cosmic-icons / cosmic-wallpapers** — System76 · GPL-3.0 / CC-SA-4.0
- **Papirus Icon Theme** — GPL-3.0
- **Cosmictron** — SethStormR (comunidade)
- **cosmic-ext-bg** — olafkfreund (comunidade)
- **Dracula_OS-Theme** — AndreBFarias, GPL-3.0 (arquitetura de referência e sons CC0)
- Logo do gato: original, feita para este projeto, sobre a paleta Catppuccin.

# MeowSystem-Theme

Catppuccin Mocha para o COSMIC da MeowSystem — tema, ícones, papéis de parede e
aplicativos, num instalador só, sem flag nenhuma.

```bash
./install.sh          # a primeira vez
meow ativar           # todas as outras
```

Roda quantas vezes quiser: numa máquina já instalada, a segunda execução não
escreve um byte — e **diz isso**, em vez de listar as etapas como se as tivesse
refeito:

```
  ok   confere: conf cli pacotes gerar tema modo greeter vidro ...

  Pronto. Nenhuma etapa precisou escrever nada — já estava tudo no lugar.
```

Quando alguma coisa de fato mudou, ela aparece separada, em `mexeu:`.
Para auditar antes: `MEOW_DRY_RUN=1 ./install.sh`.

**Numa máquina recém-formatada são três rodadas até o silêncio, não duas**, e
isso é deliberado. O `index.theme` do tema de ícones descreve os diretórios que
EXISTEM — e na primeira rodada as pastas coloridas ainda não existem, porque quem
as instala é a etapa seguinte. A alternativa seria gravar a lista fixa, que foi o
que se fazia antes: dois scripts donos da mesma linha, cada um desfazendo o
outro, os dois relatando "consertei" em toda rodada, para sempre. O detalhe está
em `scripts/construir_icones.sh` §1.

---

## Receitas de uma linha

| O que você quer | O comando |
|---|---|
| **Aplicar tudo** (o mesmo que `./install.sh`) | `meow ativar` |
| Ver o que está fora do lugar | `meow doctor` |
| **Topbar e dock sumiram** | não faz nada: o `meow-painel.service` repõe em ~2s |
| Diagnóstico da barra | `meow painel estado` |
| Por que o raio de canto foi cortado | `meow painel teto` |
| Fazer o painel reler a config | `meow painel reciclar` |
| Consertar só o que estiver fora | `meow doctor --consertar` |
| Trocar o accent para rosa | `./scripts/aplicar_tema.sh mocha-pink` |
| Ir para o tema claro | `./scripts/aplicar_tema.sh latte-mauve` |
| **Desfazer tudo** | `./scripts/aplicar_tema.sh original` |
| **Os dois gatos estão sempre na tela** | nada: de dia Mimir no dock e Coquinha no terminal; de noite, trocados |
| Ver quem está no ar, e por quê | `meow logo listar` |
| Trocar quem é o gato de dia/de noite | `LOGO_DIA=` / `LOGO_NOITE=` no `meow.conf` — o terminal segue invertido sozinho |
| **Pôr um gato novo no acervo** | solte o `.svg` em `assets/gatos/` |
| **Adicionar papel de parede** | arraste a imagem para `assets/papeis-de-parede/ativos/` |
| Idem, com verificações | `./scripts/wallpaper.sh adicionar <arquivo\|pasta>` |
| **Tirar um papel de parede da rotação** | apague o arquivo de `assets/papeis-de-parede/ativos/` — em ~4 s ele entra no `BANIDOS.txt` sozinho |
| Idem, sem apagar (vai para `banidos/`) | `meow wallpaper banir <arquivo>` |
| Ver o estado do carrossel | `meow wallpaper estado` |
| **Avançar / voltar o papel de parede** | botão direito na área de trabalho — ou `meow wallpaper proximo` \| `anterior` |
| Devolver o carrossel agora (sem esperar os 30 min) | `meow wallpaper carrossel` |
| **Manter um papel de parede que não é do carrossel** | `meow wallpaper permitir <caminho>` |
| **Mudar qualquer coisa, sem editar arquivo** | `meow abrir` — ou o ícone **MeowSystem** no lançador |
| Mudar qualquer coisa | edite `~/.config/meow/meow.conf` e rode `./install.sh` |

Tudo que o projeto **decide** vive em um arquivo: `~/.config/meow/meow.conf`.
Flavor, accent, modo, logo, intervalo do carrossel, lista de aplicativos.

Tudo que o projeto **desenha** vive numa pasta, e a pasta é a configuração:
soltou o arquivo, entrou; apagou, saiu. Não há lista em script nenhum para
editar.

| o quê | onde | quando aparece |
|---|---|---|
| gatos da logo | `assets/gatos/` | **no acervo, na hora** — o `meow-assets.path` vigia a pasta. Qual gato fica *no ar* é decidido **ao encerrar a sessão** (no máximo 1×/dia), e ele aparece no login seguinte; `meow logo girar` passa ao próximo agora |
| papéis de parede | `assets/papeis-de-parede/ativos/` | na hora — o `cosmic-bg` lê a pasta. **Apagar de lá é definitivo**: o `meow-ativos.path` nota o sumiço em ~4 s e grava o nome no `BANIDOS.txt`, para o `semear` não repor |

Os papéis de parede ficam fora do git de propósito — imagem grande em git é
dívida que não se paga, e o Andromeda já ficou 18 h com o auto-sync mudo por um
arquivo de mais de 100 MB.

**E, desde 01/09/2026, eles não moram no repositório nem fora do git.** Havia
145 MB de imagem em `assets/papeis-de-parede/` (e uma segunda pasta,
`src/wallpapers/`, que era FANTASMA — só existia no `.gitignore`). As 51 eram
cópia byte a byte do acervo vivo, **nenhum script as lia**, e apagar ali não
fazia nada — foi ela quem topou nisso. Saíram. O que ficou naquela pasta é o
que o código de fato lê: as receitas.

**Desde 01/09/2026 o acervo vivo mora no próprio repositório**, em
`assets/papeis-de-parede/ativos/` — decisão dela: uma pasta só, visível onde ela
trabalha, em vez de escondida dentro do `.local`. O caminho antigo
(`~/.local/share/backgrounds/meowsystem`) continua valendo: virou symlink para
cá. Quem manda é a chave `WALLPAPER_BASE`. Mover a base INTEIRA (e não só
`ativos/`) é o que preserva os links duros das pastas de dia e de noite — elas
precisam do mesmo sistema de arquivos que `ativos/`. Quem o
reproduz é `scripts/wallpaper.sh semear`, lendo **três receitas**: o
commit pinado da coleção Catppuccin, o `assets/papeis-de-parede/FONTES.tsv` (a URL de cada
imagem escolhida a mão) e o `assets/papeis-de-parede/BANIDOS.txt` (os nomes recusados, que o
semear não repõe). O acervo tem **54 imagens**: das 242 do upstream, 11
sobreviveram à curadoria visual de 24/08/2026, e 43 foram buscadas naquele dia.

---

## O painel: configurar sem editar arquivo

```bash
meow abrir        # ou o ícone "MeowSystem" no lançador
```

Uma página local com **as 95 chaves do `meow.conf`** — cada uma mostrando o valor
que você escolheu, o que vinha de fábrica e a explicação que está no
`meow.conf.exemplo` — e **30 ações** (instalar, `doctor`, consertar, desinstalar,
trocar tema/flavor/accent, girar o gato, papel de parede, modo de leitura,
reciclar a barra), com a saída aparecendo **ao vivo** enquanto rodam.

O interruptor **Modo seco** no topo põe `MEOW_DRY_RUN=1` em tudo que aceita, que
é a promessa deste projeto — dá para ver o que aconteceria antes de deixar
acontecer.

**Não há uma lista de chaves dentro dele.** O catálogo é lido do
`meow.conf.exemplo`, com as mesmas regras que o `meow configurar` usa: chave nova
no exemplo aparece na página sozinha, chave que sair de lá some sozinha.
`tests/app.sh` compara as duas leituras e falha se elas divergirem. E quem
escreve no `meow.conf` é o `meow_conf_definir` de `lib/comum.sh`, o mesmo de
sempre — nunca um `sed` improvisado: gravar uma chave e voltar deixa o arquivo
idêntico byte a byte, com o comentário da linha e os espaços que o alinham.

**Gravar não é aplicar, e a página não finge que é.** Escrever a chave e o tema
mudar na tela são coisas diferentes aqui desde sempre. Ela conta quantas chaves
esperam, com o botão que as aplica ao lado.

O backend é `python3` da biblioteca padrão, **sem dependência nova**. Escuta em
`127.0.0.1`, em porta que o kernel escolhe, com um token de sessão sorteado a
cada execução; confere `Host` e `Origin`; e **nenhum comando vem da página como
texto** — ela manda um `id` de uma lista fechada, e o argumento é conferido
contra o que existe no disco. Fechar a janela derruba tudo.

O porquê de cada decisão está em [`app/LEIA-ME.md`](app/LEIA-ME.md) — inclusive o
que foi medido sobre o `sudo` desta máquina, que não é o que parecia.

---

## As folhas visuais

`docs/folhas/` guarda as **18 páginas HTML que decidiram partes deste tema**: os
ícones lado a lado no tamanho real, as pastas par a par, os cinco pesos de traço,
os cursores medidos em pixel, os 54 papéis separados por luminância. É onde se
vê *por que* o tema é assim, em vez de ler a prosa que descreve a escolha.

Elas moravam soltas na home, fora de qualquer controle de versão, desde agosto de
2026; entraram em 01/09/2026 **por cópia** — os originais continuam lá. São 5,9 MB
e isso é deliberado: não são acervo reproduzível como os papéis de parede (que
saíram por 145 MB no mesmo dia), são o registro de uma decisão dela, e o
`meow.conf.exemplo` já cita duas delas por caminho.

O índice, com o que cada uma mostra e a decisão que produziu, está em
[`docs/folhas/LEIA-ME.md`](docs/folhas/LEIA-ME.md).

---

## O que ele veste

- **O tema do COSMIC** — as quatro árvores (`Dark`, `Light` e os dois `.Builder`),
  aplicadas por cópia de arquivo.
- **A tela de login** — o `cosmic-greeter` tem configuração própria, em
  `/var/lib`, e vinha vazia: era a única superfície ainda de fábrica.
- **O vidro ao maximizar** — painel e dock mantêm o fosco quando uma janela
  maximiza (`keep_style_on_maximize`, duas chaves, valem na hora).
- **Os dois gatos, sempre os dois** — o do dock e o do terminal nunca são o
  mesmo. De dia o **Mimir** no dock e a **Coquinha** no `fastfetch`; às 18:00
  eles trocam de lugar. Quem manda no dock é `LOGO_DIA`/`LOGO_NOITE`; o terminal
  não tem par de chaves próprio — ele usa a REGRA "o gato que o dock não está
  mostrando" (`FASTFETCH_LOGO_MODO="espelho"`), lida do arquivo do tema de
  ícones, que é o que ela de fato vê.

  Fixar quatro valores em vez da regra funcionaria hoje e envelheceria no
  primeiro dia em que ela trocasse o gato do dock: seriam dois pares a manter
  opostos à mão, e nada avisaria se deixassem de ser. Um dia os dois mostrariam
  o mesmo gato e o "sempre os dois" viraria mentira em silêncio.

- **O gato do dock** — o botão do lançador, vindo do acervo `assets/gatos/`.
  Aqui há **um** gato na tela, não dois: o applet "Logo Menu" (`dev.cappsy`), que
  desenharia o gato do painel, **não está montado em barra nenhuma** nesta
  máquina — medido em 05/08/2026 em `plugins_wings` e `plugins_center` das duas
  barras. O `meow logo girar` troca a chave dele corretamente, e o `logo.sh` diz
  isso em voz alta em vez de fingir efeito. Para ver o segundo gato:
  Ajustes → Área de trabalho → Painel → Applets.
- **Os ícones** — Papirus como base, num tema derivado que não toca no pacote do
  apt, com **quatro acervos em uso** por cima e um alvo diferente para cada um:

  | acervo | veste | quantos |
  |---|---|---|
  | `catppuccin/vscode-icons` (MIT) | os **tipos de arquivo** — o que o Gestor de Arquivos desenha | 123 |
  | Arcticons (CC BY-SA 4.0) | as **páginas das Configurações**, os ícones de sistema e os **aplicativos do lançador**, em traço | 30 + **14** |
  | convertidos do Papirus (GPL-3.0) | os aplicativos que o Arcticons não cobria — chapado levado ao traço pelo `converter_icone.py` | **27** (2 são desenho `mao`: CosmicPlayer e CosmicEdit) |
  | desenho autoral | os apps do próprio COSMIC, o FogStripper e o Hefesto | 10 |

  **O acervo pastel saiu de cena, e a tabela acima é de 25/08/2026.** Até 10/08 os
  aplicativos do lançador vinham do `Daveedmee/catppuccin-icons`, em PNG pastel —
  o `assets/icones/apps.map` que os aplicava está **vazio desde então**, e o próprio
  arquivo diz isso no cabeçalho. Quem os substituiu foi a decisão dela de 11/08:
  **"o nosso tema é o traço, não o chapado"** (Sprint I). O Daveedmee continua no
  disco, sem uso, e sem licença declarada — uso local, nunca redistribuir.

  Confundi-los custa caro: o `vscode-icons` tem 656 glifos e **nenhum** deles casa
  com um aplicativo instalado aqui além do `vscode` — ele é de linguagem e formato
  de arquivo. E o Arcticons **deixou de ser apoio**: em 11/08 ele passou de
  "preencher lacuna" a vestir o lançador inteiro junto com os convertidos. Onde
  não há match honesto, o ícone continua no Papirus. A **barra**
  continua no Papirus de propósito — os applets são famílias de estado
  (`audio-volume-*` em 5, `network-wireless-*` em 7) e o Arcticons tem **zero**
  sufixos `-off`/`-mute`/`-low`; vestir um estado só faria o ícone mudar de
  estilo conforme o volume. As pastas continuam em `cat-mocha-mauve`, do
  `papirus-folders`. O que fica de fora dos quatro segue no Papirus, por herança.

  **Três ícones voltaram para o Papirus de propósito, em 08/08/2026**, depois de
  ela apontá-los na tela. O Telegram e o qBittorrent do acervo pastel eram um
  avião **sem o círculo da marca** (croma 0,067, contraste interno 1,12) e um
  disco cinza com o "qb" quase invisível (croma 0,040): medidos a 48 px sobre os
  quatro fundos reais — Mocha, Latte e os **dois estados do vidro da dock** —, o
  Papirus ganha em todos os eixos. E o btop era o **pior ícone da dock inteira**,
  com uma placa opaca em 62% da caixa e separação 1,61, o piso dos 48; virou
  Arcticons `osmonitor` em maroon, 5,25. Cobertura não é fidelidade: um ícone que
  não parece a marca é pior que um que não é Catppuccin.
- **O lançador** — sem as duplicatas ("(Local)"/"(Sistema)") e sem os aplicativos
  que são dependência de pacote, não programa que se abre.
- **Os papéis de parede** — carrossel na rotação nativa do COSMIC.
- **Os aplicativos** — VS Code, Obsidian, qBittorrent, bat, btop e o ZapZap (que
  além do tema ganha o nome "WhatsApp" e o ícone da bandeja). GTK e Qt vêm de
  graça: com `apply_theme_global` ligado, o COSMIC já os pinta a partir do tema.

---

## As três coisas que você precisa saber

### 1. O tema custou três cliques, uma vez na vida

O COSMIC **não tem CLI de tema**, e a derivação (transformar a receita em tema
aplicado) mora dentro do app gráfico. Foram testados quatro caminhos para evitar
isso — o daemon não deriva, escrever no `Builder` não deriva, abrir o
`cosmic-settings` não deriva. Só o import explícito deriva.

Então o projeto importou os três temas **uma vez**, fotografou o resultado em
`assets/temas/capturados/` e versionou no git. A partir daí aplicar é copiar arquivo — sem GUI,
sem flag, e **numa máquina recém-formatada, com zero clique**.

### 2. Claro e escuro são o mesmo tema

As capturas `mocha-mauve` e `latte-mauve` diferem em **exatamente um arquivo**: o
`CosmicTheme.Mode/v1/is_dark`. O COSMIC guarda as duas árvores completas e
independentes; esse arquivo só escolhe qual está em uso. Por isso `MODO=auto`
custa três linhas e não pisca a interface.

### 3. Ele convive com o Ritual da Aurora

O [Andromeda-OS](https://github.com/[REDACTED]/Andromeda-OS) roda como root a
cada hora e é dono de vários dos mesmos arquivos. Onde os dois se cruzam, o
MeowSystem cede — e a regra mais importante: para o vidro fosco, o `meow` grava em
`transparent_*` e deixa a Aurora propagar, de modo que o self-heal converge sem
escrever nada. Sem isso, os dois entrariam em cabo de guerra a cada hora.

O contrato completo está em [`docs/COSMIC-THEMING.md`](docs/COSMIC-THEMING.md) §5.

**E onde o conflito é direto, o Meow resolve do lado dele.** O
`aurora-painel-fantasma.sh` mata o painel apostando que "o cosmic-session
respawna em ~4ms" — verdade no começo da sessão, falsa depois. Nenhuma linha dele
foi tocada: o `meow-painel.service` passa a ser quem ressuscita, restaurando a
premissa que o vigia já assume, e a trégua é carimbada no `tentativas.ts` que ele
mesmo já lê. Contrato por arquivo de estado, não por edição alheia.

---

## A barra que sumia

O sintoma era esse: topbar e dock sumiam juntas, do nada, e não voltavam — só
`Alt+F2` trazia de volta, cada vez com mais frequência. São **três** problemas
empilhados, e o repositório trata os três.

**1. O raio de canto derruba a barra.** O `cosmic-comp` valida o raio num
pre-commit hook que compara o valor NOVO contra a caixa do frame **ANTERIOR**
(`corner_radius.rs:658` e `:685`). Erro de protocolo Wayland é fatal: o painel
fica vivo e para de desenhar — e como painel e dock são o mesmo processo, os dois
somem juntos. Em 26/08/2026 o COSMIC Tweaks gravou `border_radius` 41 num painel
de 44 de altura, e a barra passou a tarde inteira sumida.

- `patches/cosmic-comp-raio-clampado.patch` troca o `post_error` por um **clamp**:
  o canto é reduzido ao que cabe em vez de o cliente ser derrubado. **Ele está no
  binário, e está em execução** — entrou no build da série de 30/08/2026, às 04:59.
  Este parágrafo dizia o contrário e mandava você rodar um build de ~4 min que já
  tinha rodado; ficou assim de 30/08 até 31/08/2026. Medido em 31/08/2026, com o
  mesmo comando de antes —
  `grep -a -o 'AURORA-[A-Z-]*-PATCH-[0-9][0-9.]*' /usr/bin/cosmic-comp | sort -u` —,
  que agora devolve **dois** marcadores: `AURORA-COSMIC-RADIUS-PATCH-1` e
  `AURORA-COSMIC-WS-PATCH-3.67`. Os dois estão também no `/proc/<pid>/exe` do
  `cosmic-comp` que desenha a tela agora, e o
  `/var/lib/aurora/cosmic-comp-patches.estado` da Aurora declara os dois
  `presente`.
- **E agora isso tem quem vigie.** A linha `patches` do `meow doctor` compara os
  marcadores que a Aurora declara em `/var/lib/aurora/cosmic-comp-patches.estado`
  contra o binário do disco **e** contra `/proc/<pid>/exe` — a pergunta é sobre o
  processo, não sobre o arquivo — e confere se todo `.patch` de `patches/` está
  declarado na série. Foi essa segunda conferência que faltava: um patch fora da
  série não entra em binário nenhum. E é por isso que a linha do `doctor` vale
  mais do que o parágrafo acima — ele já mentiu nas **duas** direções (dizendo que
  o clamp estava no binário quando não estava, até 29/08; e que não estava quando
  já estava, de 30/08 a 31/08). O `doctor` mede toda vez que roda; o parágrafo só
  guarda o dia em que alguém mediu.
- Com o clamp **em execução**, o teto deixa de valer: o canto das barras é seu, sem
  limite, e o `meow painel conferir` não mexe em nada. Se um dia o compositor voltar
  a ser o de fábrica — um `apt upgrade` de `cosmic-*` basta —, o clamp do lado de cá
  volta a agir e guarda o número que você pediu em
  `~/.local/state/meowsystem/painel/raio_desejado.*`, que retorna sozinho no dia em
  que couber.

**2. O supervisor do COSMIC desiste, e não avisa.** O backoff do `cosmic-session`
é `2^restarts × sorteio(0..9)` ms — **sem teto**, e o contador **nunca zera por
sucesso**. Nesta máquina ele chegou a 58720256 ms: 16h18min. Depois de ~20 mortes
na mesma sessão, ele simplesmente não socorre mais.

- `meow-painel.service` é o supervisor do Meow. O painel vira **filho** da unidade,
  o laço dorme em `wait -n` (CPU zero) e acorda no instante da morte. Medido:
  **1,97 s** entre o `pkill` e a barra de volta, com os 12 applets.
- Ele cede a vez ao painel do `cosmic-session` assim que este voltar a ter um —
  porque só o painel do supervisor recebe o socketpair das notificações e, com
  ele, o sino.

**3. O que a GUI oferece é dela.** `margin`, `border_radius`, `spacing` e
`padding` têm slider no COSMIC Tweaks, e o `forma.sh` os reescrevia toda passagem
— com o `meow doctor --consertar` rodando sozinho às 05:00. Agora vale a mesma
convenção do `vidro.sh`: **vazio no `meow.conf` significa não toca**. Quem quiser
impor preenche a chave. `anchor_gap` e `expand_to_edges` seguem sendo do projeto:
a GUI não os expõe, e o que ela não oferece se perde em silêncio.

O `meow painel teto` mostra a conta inteira — altura real da barra, teto derivado
e se o compositor em execução clampa:

```
Panel  size=S   padding=2  altura=44  teto=22  raio=16
Dock   size=M   padding=4  altura=72  teto=36  raio=24
compositor: CLAMPA (o teto acima não se aplica — o raio é seu)
```

(Saída real desta máquina em 31/08/2026. A terceira linha é a que responde
"o teto ainda vale?" — e hoje ela diz que não.)

---

## Uma máquina só, e isso é uma decisão

Em **05/08/2026** ficou decidido: este repositório **não vai ser publicado**. Ele
existe para deixar o COSMIC de uma pessoa funcional e bonito, e acoplar-se a essa
máquina é permitido — `apt`, caminhos absolutos, o uid do `cosmic-greeter`, os
`.desktop` dos jogos dela.

Some junto o trabalho que só existia por causa da publicação: abstração de
gerenciador de pacotes, detecção de schema do COSMIC para outras versões, camada
única de detecção do Aurora. **Nenhum dos três chegou a existir como código** —
eram planos, e a poda foi de promessa, não de linha: nenhum gerenciador além do
`apt` aparece em `bin`, `scripts`, `lib` ou `install.sh`. (`lib/` tinha **um**
arquivo quando isto foi escrito; hoje tem três — `comum.sh`, `desinstalar.sh` e
`preflight.sh`, os dois últimos de 11/08/2026 —, mas nenhum deles é camada de
abstração: são código que roda.)

Duas coisas **não** eram sobre publicar, e continuam valendo inteiras:

**Nada é apagado sem backup.** O único ponto do projeto capaz de remover arquivo
de tema — `aplicar_tema.sh` — guarda as árvores inteiras em
`~/.local/state/meowsystem/backups/<ISO>/` antes, com `manifesto.sha256` e um
`COMO-RESTAURAR.txt` ao lado. Isso protege o tema **dela**.

> **Se o compositor não subir e você estiver sem tela de login**, o procedimento é
> o cartão de recuperação por TTY em
> `docs/pesquisas/2026-08-29-modo-leitura-e-botoes.md` — a primeira seção do
> arquivo, de propósito. Dois avisos que valem a leitura ANTES de compilar
> qualquer coisa: o `--restore` dos dois scripts da Aurora está armadilhado (o
> `.pkg-orig` não bate com o md5 do dpkg), e `/usr/bin/cosmic-greeter-start` é
> literalmente `exec cosmic-comp cosmic-greeter` — o greeter é o mesmo binário.

**Cada módulo pula o que não encontra.** App ausente, `cosmic-greeter` ausente,
applet de terceiro ausente — tudo é "pulado", com a razão dita em voz alta, e
nunca aborta o resto. Não é portabilidade: é o que faz o instalador não explodir
quando um programa não está instalado.

**Uma consequência de licença.** `assets/icones/catppuccin-apps/` vem de um acervo **sem
licença declarada**. Uso local, sem redistribuir — os PNG ficam fora do git pela
regra de imagem, o que já garante isso sozinho. Se algum dia esta decisão mudar,
essa pasta e o `assets/icones/apps.map` saem juntos.

---

## Estrutura

Nove diretórios no topo, e a regra que separa dois deles: **`assets/` é o que o
projeto DESENHA, `src/` é o que ele COMPILA.** Até 01/09/2026 não era assim — os
ícones estavam em `icons/` E em `src/icons/`, as fontes e os sons moravam dentro
de `src/` ao lado do código Rust, e havia sete diretórios de topo a mais
(`palette/`, `themes/`, `state/`, `app-themes/`, `wallpapers/`, `zsh/`, `icons/`).
Um acervo em dois lugares é um acervo que diverge.

```
assets/                     TUDO que é arte e dado de entrada (nada aqui compila)
  gatos/                    os gatos — solte um .svg e ele entra no acervo
  icones/                   os acervos (Arcticons, Catppuccin, convertidos, autorais)
                            e os `.map` que dizem qual arte veste qual app
  paleta/                   a fonte única de verdade de cor (4 flavors x 26 cores)
  temas/                    os .ron gerados — o que se importa na GUI
  temas/capturados/         as capturas: é isto que o instalador aplica
  temas-de-apps/            um módulo por aplicativo (detectar/conferir/aplicar)
  papeis-de-parede/         o acervo curado (fora do git; FONTES.tsv o reproduz)
  fontes/ cursores/ sons/   o resto do que se veste
  fastfetch/ prompt/ zsh/   os arquivos que vão para fora do repositório
src/applets/                o que COMPILA: os applets em Rust
app/                        o que ele SERVE: o painel de configuração visual
                            (página local + backend em python3 da stdlib)
scripts/                    os geradores e aplicadores (um assunto por arquivo)
lib/comum.sh                log, códigos de saída, escrita atômica e as travas
lib/noite.sh                "é noite agora?" — uma vez só, para a máquina inteira
lib/painel.sh               a altura das barras, o teto do raio, as sondas do compositor
patches/                    o que precisa ser corrigido no cosmic-comp e no
                            cosmic-files, com o porquê medido
systemd/                    as unidades: os relógios e os vigias
bin/meow                    a CLI
docs/                       o que foi MEDIDO nesta máquina, com data e método
docs/folhas/                as 18 folhas visuais que decidiram este tema
tests/                      os testes que rodam contra a máquina de verdade
```

**Nenhum hex vive dentro de script.** Toda cor sai de `assets/paleta/catppuccin.json`, e
o destino de cada cor sai de `assets/paleta/cosmic-map.json`. Foi assim que se descobriu
que o gato do Latte estava fora da paleta: ele misturava verde do Latte, verde do
**Mocha** e dois valores que não são Catppuccin nenhum.

---

## Segurança

O instalador **recusa por caminho** — não por boa intenção — escrever em
`/usr/share`, no repositório de dotfiles ou nos atalhos de teclado. E nunca roda
`apt upgrade` nem toca em pacote `cosmic-*`: o `cosmic-comp` desta máquina está
patchado **três** vezes, e uma versão nova mataria os três de uma vez. Medido em
31/08/2026 com
`grep -a -o 'AURORA-[A-Z-]*-[0-9][0-9.]*' /usr/bin/cosmic-comp | sort -u`:

```
AURORA-COSMIC-RADIUS-PATCH-1
AURORA-COSMIC-WS-PATCH-3.67
AURORA-READING-MODE-1
```

O que se perde em cada um, para você saber pelo que olhar:

| patch | o que some da tela |
|---|---|
| `AURORA-COSMIC-WS-PATCH` | os workspaces alfinetados — volta o workspace vazio a mais no fim, e o painel mostra um número seco |
| `AURORA-COSMIC-RADIUS-PATCH` | o clamp do raio — um canto grande volta a derrubar a barra inteira |
| `AURORA-READING-MODE` | **o modo de leitura**, que é o patch que PINTA a tela. Sem ele a tela para de esquentar à noite: os dois números continuam sendo gravados no disco, mas não sobra ninguém para lê-los. Nada na tela acusa — quem acusa é o `meow leitura` (linha `cosmic-comp no disco`) e a linha `patches` do `meow doctor` |

**Por que a contagem muda conforme o comando.** O grep da seção do raio, lá em
cima, filtra por `-PATCH-` e devolve **dois**; este filtra só por `AURORA-` e
devolve **três**. Nenhum dos dois números está errado: o marcador do modo de
leitura é `AURORA-READING-MODE-1`, e não tem a palavra `PATCH` no meio.

**Quem apaga, guarda antes.** O `aplicar_tema.sh` é o único ponto do projeto que
**remove** arquivo que não é dele, e faz backup da árvore inteira em
`~/.local/state/meowsystem/backups/<ISO>/`. Quem **sobrescreve** arquivo de
terceiro também guarda antes: o `hicolor.sh`, o `greeter.sh` e os **seis**
módulos de `assets/temas-de-apps/`. Uma passagem inteira do instalador usa **uma** pasta
de backup — o carimbo nasce em `lib/comum.sh` e é exportado, porque enquanto
cada módulo calculava o próprio `date` uma execução que cruzasse a virada do
segundo rachava os backups em duas pastas (há prova disso no disco, em 04/08).

Dois pontos escrevem fora de casa e **não** fazem backup, e é decisão declarada:
o `ocultar_apps.sh` marca `NoDisplay=true` nos `.desktop` de `/usr/share`
(território do apt, que devolve o original a cada upgrade — o apt é o backup), e
o `wallpaper.sh` remove do estado do `cosmic-bg` as entradas cujo arquivo não
existe mais.

Os demais **não** fazem backup, e isso é a regra, não um esquecimento: eles
escrevem em diretórios que o projeto criou e dos quais é dono único — o tema
`MeowSystem-Icons`, os gatos `meow-*.svg`, o som, os `.desktop` sombreados em
`~/.local/share/applications/`. Ali o conteúdo anterior é a saída da rodada
anterior deles mesmos, e guardá-lo seria encher o disco de cópias idênticas.
A regra é **backup do que é de outro**, não backup de tudo.

---

## Créditos

- [Catppuccin](https://github.com/catppuccin/catppuccin) — a paleta (MIT)
- [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) — a base
  de ícones (GPL-3.0)
- [catppuccin/papirus-folders](https://github.com/catppuccin/papirus-folders) — as
  pastas coloridas, pinado em `f83671d1`

Licença: GPL-3.0.

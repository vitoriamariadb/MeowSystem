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
| Consertar só o que estiver fora | `meow doctor --consertar` |
| Trocar o accent para rosa | `./scripts/aplicar_tema.sh mocha-pink` |
| Ir para o tema claro | `./scripts/aplicar_tema.sh latte-mauve` |
| **Desfazer tudo** | `./scripts/aplicar_tema.sh original` |
| Fixar um gato do acervo | `meow logo coquinha` (ou edite `LOGO=` no `meow.conf`) |
| **Pôr um gato novo na rotação** | solte o `.svg` em `assets/gatos/` |
| Ver o acervo de gatos e quem está no ar | `meow logo listar` |
| Passar para o próximo gato agora | `meow logo girar` |
| **Adicionar papel de parede** | arraste a imagem para `~/.local/share/backgrounds/meowsystem/ativos/` |
| Idem, com verificações | `./scripts/wallpaper.sh adicionar <arquivo\|pasta>` |
| Tirar um papel de parede da rotação | `./scripts/wallpaper.sh banir <arquivo>` |
| Ver o estado do carrossel | `./scripts/wallpaper.sh estado` |
| **Manter um papel de parede que não é do carrossel** | `meow wallpaper permitir <caminho>` |
| Mudar qualquer coisa | edite `~/.config/meow/meow.conf` e rode `./install.sh` |

Tudo que o projeto **decide** vive em um arquivo: `~/.config/meow/meow.conf`.
Flavor, accent, modo, logo, intervalo do carrossel, lista de aplicativos.

Tudo que o projeto **desenha** vive numa pasta, e a pasta é a configuração:
soltou o arquivo, entrou; apagou, saiu. Não há lista em script nenhum para
editar.

| o quê | onde | quando aparece |
|---|---|---|
| gatos da logo | `assets/gatos/` | **no acervo, na hora** — o `meow-assets.path` vigia a pasta. Qual gato fica *no ar* é decidido **ao encerrar a sessão** (no máximo 1×/dia), e ele aparece no login seguinte; `meow logo girar` passa ao próximo agora |
| papéis de parede | `~/.local/share/backgrounds/meowsystem/ativos/` | na hora — o `cosmic-bg` lê a pasta |

Os papéis de parede ficam fora do git de propósito — imagem grande em git é
dívida que não se paga, e o Andromeda já ficou 18 h com o auto-sync mudo por um
arquivo de mais de 100 MB. Eles moram em `wallpapers/`, dentro do repositório, e
o que os reproduz é `scripts/wallpaper.sh semear`, lendo **três receitas**: o
commit pinado da coleção Catppuccin, o `wallpapers/FONTES.tsv` (a URL de cada
imagem escolhida a mão) e o `wallpapers/BANIDOS.txt` (os nomes recusados, que o
semear não repõe). O acervo tem **54 imagens**: das 242 do upstream, 11
sobreviveram à curadoria visual de 24/08/2026, e 43 foram buscadas naquele dia.

---

## O que ele veste

- **O tema do COSMIC** — as quatro árvores (`Dark`, `Light` e os dois `.Builder`),
  aplicadas por cópia de arquivo.
- **A tela de login** — o `cosmic-greeter` tem configuração própria, em
  `/var/lib`, e vinha vazia: era a única superfície ainda de fábrica.
- **O vidro ao maximizar** — painel e dock mantêm o fosco quando uma janela
  maximiza (`keep_style_on_maximize`, duas chaves, valem na hora).
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
  | Arcticons (CC BY-SA 4.0) | as **páginas das Configurações**, os ícones de sistema e os **aplicativos do lançador**, em traço | 30 + 16 |
  | convertidos do Papirus (GPL-3.0) | os aplicativos que o Arcticons não cobria — chapado levado ao traço pelo `converter_icone.py` | 25 |
  | desenho autoral | os apps do próprio COSMIC, o FogStripper e o Hefesto | 10 |

  **O acervo pastel saiu de cena, e a tabela acima é de 25/08/2026.** Até 10/08 os
  aplicativos do lançador vinham do `Daveedmee/catppuccin-icons`, em PNG pastel —
  o `icons/apps.map` que os aplicava está **vazio desde então**, e o próprio
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
`state/tema/` e versionou no git. A partir daí aplicar é copiar arquivo — sem GUI,
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

**Cada módulo pula o que não encontra.** App ausente, `cosmic-greeter` ausente,
applet de terceiro ausente — tudo é "pulado", com a razão dita em voz alta, e
nunca aborta o resto. Não é portabilidade: é o que faz o instalador não explodir
quando um programa não está instalado.

**Uma consequência de licença.** `icons/catppuccin-apps/` vem de um acervo **sem
licença declarada**. Uso local, sem redistribuir — os PNG ficam fora do git pela
regra de imagem, o que já garante isso sozinho. Se algum dia esta decisão mudar,
essa pasta e o `icons/apps.map` saem juntos.

---

## Estrutura

```
assets/gatos/     os gatos da rotação — solte um .svg e ele entra
icons/            os acervos Catppuccin de terceiro + os mapas que os aplicam
wallpapers/       o acervo curado (fora do git; FONTES.tsv + BANIDOS.txt o reproduzem)
docs/SPRINTS.md   o que falta fazer, escrito para ser lido sem contexto nenhum
docs/pesquisas/   o material bruto das investigações multi-frente
docs/historico/   de onde o projeto veio (não é lido por script nenhum)
palette/          a fonte única de verdade de cor (4 flavors x 26 cores)
themes/           os .ron gerados — o que se importa na GUI
state/tema/       as capturas: é isto que o instalador aplica
scripts/          os geradores e aplicadores
app-themes/       um módulo por aplicativo (detectar/conferir/aplicar)
lib/comum.sh      log, códigos de saída, escrita atômica e as travas
docs/             o que foi MEDIDO nesta máquina, com data e método
```

**Nenhum hex vive dentro de script.** Toda cor sai de `palette/catppuccin.json`, e
o destino de cada cor sai de `palette/cosmic-map.json`. Foi assim que se descobriu
que o gato do Latte estava fora da paleta: ele misturava verde do Latte, verde do
**Mocha** e dois valores que não são Catppuccin nenhum.

---

## Segurança

O instalador **recusa por caminho** — não por boa intenção — escrever em
`/usr/share`, no repositório de dotfiles ou nos atalhos de teclado. E nunca roda
`apt upgrade` nem toca em pacote `cosmic-*`: o `cosmic-comp` desta máquina está
patchado duas vezes, e uma versão nova mataria os dois patches junto com os
workspaces alfinetados.

**Quem apaga, guarda antes.** O `aplicar_tema.sh` é o único ponto do projeto que
**remove** arquivo que não é dele, e faz backup da árvore inteira em
`~/.local/state/meowsystem/backups/<ISO>/`. Quem **sobrescreve** arquivo de
terceiro também guarda antes: o `hicolor.sh`, o `greeter.sh` e os **seis**
módulos de `app-themes/`. Uma passagem inteira do instalador usa **uma** pasta
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

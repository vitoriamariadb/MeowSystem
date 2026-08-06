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
| Trocar a logo do gato | edite `LOGO=` no `meow.conf` e rode `./install.sh` |
| **Pôr um gato novo na rotação** | solte o `.svg` em `assets/gatos/` |
| Ver o acervo de gatos e quem está no ar | `meow logo listar` |
| Passar para o próximo gato agora | `meow logo girar` |
| **Adicionar papel de parede** | arraste a imagem para `~/.local/share/backgrounds/meowsystem/ativos/` |
| Idem, com verificações | `./scripts/wallpaper.sh adicionar <arquivo\|pasta>` |
| Tirar um papel de parede da rotação | `./scripts/wallpaper.sh banir <arquivo>` |
| Ver o estado do carrossel | `./scripts/wallpaper.sh estado` |
| Mudar qualquer coisa | edite `~/.config/meow/meow.conf` e rode `./install.sh` |

Tudo que o projeto **decide** vive em um arquivo: `~/.config/meow/meow.conf`.
Flavor, accent, modo, logo, intervalo do carrossel, lista de aplicativos.

Tudo que o projeto **desenha** vive numa pasta, e a pasta é a configuração:
soltou o arquivo, entrou; apagou, saiu. Não há lista em script nenhum para
editar.

| o quê | onde | quando aparece |
|---|---|---|
| gatos da logo | `assets/gatos/` | **no acervo, na hora** — o `meow-assets.path` vigia a pasta. Qual gato está *no ar* é o relógio que decide (1×/dia), ou `meow logo girar` |
| papéis de parede | `~/.local/share/backgrounds/meowsystem/ativos/` | na hora — o `cosmic-bg` lê a pasta |

Os papéis de parede ficam fora do git de propósito — imagem grande em git é
dívida que não se paga, e o Andromeda já ficou 18 h com o auto-sync mudo por um
arquivo de mais de 100 MB. Eles moram em `wallpapers/`, dentro do repositório, e
o que os reproduz é `scripts/wallpaper.sh semear`, com o commit pinado.

---

## O que ele veste

- **O tema do COSMIC** — as quatro árvores (`Dark`, `Light` e os dois `.Builder`),
  aplicadas por cópia de arquivo.
- **A tela de login** — o `cosmic-greeter` tem configuração própria, em
  `/var/lib`, e vinha vazia: era a única superfície ainda de fábrica.
- **O vidro ao maximizar** — painel e dock mantêm o fosco quando uma janela
  maximiza (`keep_style_on_maximize`, duas chaves, valem na hora).
- **Os dois gatos** — a logo do painel e o botão do dock, em mauve.
- **Os ícones** — Papirus como base, num tema derivado que não toca no pacote do
  apt, com **três acervos** por cima e um alvo diferente para cada um:

  | acervo | veste | quantos |
  |---|---|---|
  | `catppuccin/vscode-icons` (MIT) | os **tipos de arquivo** — o que o Gestor de Arquivos desenha | 123 |
  | `Daveedmee/catppuccin-icons` | os **aplicativos** do lançador, em pastel | 16 |
  | desenho autoral | os apps do próprio COSMIC, o FogStripper e o Hefesto | 10 |

  Confundi-los custa caro: o primeiro tem 656 glifos e **nenhum** deles casa com
  um aplicativo instalado aqui além do `vscode` — ele é de linguagem e formato de
  arquivo. As pastas continuam em `cat-mocha-mauve`, do `papirus-folders`.
  O que fica de fora dos três segue no Papirus, por herança.
- **O lançador** — sem as duplicatas ("(Local)"/"(Sistema)") e sem os aplicativos
  que são dependência de pacote, não programa que se abre.
- **Os papéis de parede** — carrossel na rotação nativa do COSMIC.
- **Os aplicativos** — VS Code, Obsidian, qBittorrent, bat, btop. GTK e Qt vêm de
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
eram planos, e a poda foi de promessa, não de linha: `lib/` tem um arquivo só
(`comum.sh`), e nenhum gerenciador além do `apt` aparece em `bin`, `scripts`,
`lib` ou `install.sh`.

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
wallpapers/       os 242 papéis de parede (fora do git; o semear os reproduz)
docs/SPRINTS.md   o que falta fazer, escrito para ser lido sem contexto nenhum
docs/pesquisas/   o material bruto das investigações multi-frente
docs/historico/   de onde o projeto veio (não é lido por script nenhum)
palette/          a fonte única de verdade de cor (4 flavors x 26 cores)
themes/           os .ron gerados — o que se importa na GUI
state/tema/       as capturas: é isto que o instalador aplica
assets/           os gatos, gerados a partir da paleta
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
remove arquivo que não é dele, e faz backup da árvore inteira em
`~/.local/state/meowsystem/backups/<ISO>/`. O `hicolor.sh` e os cinco módulos de
`app-themes/` fazem o mesmo com o arquivo de terceiro que sobrescrevem.

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

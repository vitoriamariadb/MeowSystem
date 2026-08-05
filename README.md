# MeowSystem-Theme

Catppuccin Mocha para o COSMIC da MeowSystem — tema, ícones, papéis de parede e
aplicativos, num instalador só, sem flag nenhuma.

```bash
./install.sh          # a primeira vez
meow ativar           # todas as outras
```

Roda quantas vezes quiser: a segunda execução não escreve um byte — e **diz
isso**, em vez de listar as etapas como se as tivesse refeito:

```
  ok   confere: conf cli pacotes gerar tema modo greeter vidro ...

  Pronto. Nenhuma etapa precisou escrever nada — já estava tudo no lugar.
```

Quando alguma coisa de fato mudou, ela aparece separada, em `mexeu:`.
Para auditar antes: `MEOW_DRY_RUN=1 ./install.sh`.

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
| Adicionar papel de parede | `./scripts/wallpaper.sh adicionar <arquivo\|pasta>` |
| Tirar um papel de parede da rotação | `./scripts/wallpaper.sh banir <arquivo>` |
| Ver o estado do carrossel | `./scripts/wallpaper.sh estado` |
| Mudar qualquer coisa | edite `~/.config/meow/meow.conf` e rode `./install.sh` |

Tudo que o projeto decide vive em **um arquivo**: `~/.config/meow/meow.conf`.
Flavor, accent, modo, logo, intervalo do carrossel, lista de aplicativos.

---

## O que ele veste

- **O tema do COSMIC** — as quatro árvores (`Dark`, `Light` e os dois `.Builder`),
  aplicadas por cópia de arquivo.
- **A tela de login** — o `cosmic-greeter` tem configuração própria, em
  `/var/lib`, e vinha vazia: era a única superfície ainda de fábrica.
- **O vidro ao maximizar** — painel e dock mantêm o fosco quando uma janela
  maximiza (`keep_style_on_maximize`, duas chaves, valem na hora).
- **Os dois gatos** — a logo do painel e o botão do dock, em mauve.
- **Os ícones** — Papirus como base, com as pastas em `cat-mocha-mauve`, num tema
  derivado que não toca no pacote do apt. Inclui desenho autoral para os oito
  aplicativos do próprio COSMIC, que vinham em teal do Pop!_OS.
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

## Estrutura

```
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

Todo passo faz backup antes de sobrescrever, em
`~/.local/state/meowsystem/backups/<ISO>/`.

---

## Créditos

- [Catppuccin](https://github.com/catppuccin/catppuccin) — a paleta (MIT)
- [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) — a base
  de ícones (GPL-3.0)
- [catppuccin/papirus-folders](https://github.com/catppuccin/papirus-folders) — as
  pastas coloridas, pinado em `f83671d1`

Licença: GPL-3.0.

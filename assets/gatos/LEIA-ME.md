# Os gatos do painel

**Solte um `.svg` aqui e ele entra na rotação.** Apague, e ele sai. Não há lista
em script nenhum para editar — esta pasta *é* a configuração.

Quem já mora aqui:

| arquivo | quem é |
|---|---|
| `coquinha.svg` | a Coquinha, gata da Vitória |
| `mimir.svg` | o Mimir, gato da Vitória |

O gato gerado do flavor ativo (`assets/meow-<flavor>-painel.svg`, desenhado a
partir da paleta por `scripts/gerar_gato.py`) entra na rotação junto, sem
precisar estar aqui.

## Quando o gato novo aparece

**Entrar no acervo é imediato.** Um vigia do systemd (`meow-assets.path`) olha
esta pasta: o arquivo que você solta aqui vai para o disco em menos de um
segundo, e o que você apaga sai junto. Não há comando a rodar, e o MeowSystem
avisa por notificação quando isso acontece. Medido em 05/08/2026: um disparo por
arquivo, nunca em laço.

**Entrar não é aparecer.** O vigia *não gira* o gato — acrescentar um arquivo não
muda qual está no ar. Quem gira é o relógio, `meow-logo.timer`, uma vez por dia
(`LOGO_INTERVALO` no `meow.conf`). E o gato do canto do dock só troca no **login
seguinte**, porque o `cosmic-panel` carrega os ícones uma vez e não os relê.

Para não esperar:

```bash
meow logo girar     # passa para o próximo agora
meow logo listar    # mostra o acervo e quem está no ar
```

A troca da chave vale **na hora**, sem reiniciar o painel e sem piscar a tela.

Para desligar o vigia: `ASSETS_VIGIA="nao"` no `meow.conf`. Aí o gato novo volta
a entrar só na volta do relógio.

> **Hoje ela não muda pixel nenhum, e o motivo não é bug.** O gato do painel é
> desenhado pelo applet **Logo Menu** (`dev.cappsy`), que **não está montado em
> barra nenhuma** nesta máquina. O `meow logo girar` troca a chave corretamente e
> diz que trocou — porque trocou —, mas não há quem desenhe. Para ver o gato:
> **Ajustes → Área de trabalho → Painel → Applets**, e acrescente "Logo Menu".
> A ordem dos applets é dela; nenhum script do projeto mexe nisso.

## Dois cuidados que economizam confusão

- **Nada de `-symbolic.svg` no nome.** O applet do painel achata em uma cor só
  qualquer arquivo cujo caminho contenha isso — o gato viraria uma silhueta
  chapada. O código pula esses arquivos de propósito.
- **Desenhe pensando em ~24 px, sobre fundo que muda.** A barra é translúcida e
  o papel de parede gira: o mesmo gato aparece sobre lilás claro e sobre quase
  preto. Um traço escuro de contorno, ou um disco de fundo (é o que a Coquinha e
  o Mimir têm), resolve os dois casos de uma vez. Foi essa a lição do commit
  `29fa004`, quando oito ícones sumiram sobre um papel de parede claro.

## Onde ficam as outras pastas

| o quê | onde | como entra |
|---|---|---|
| papéis de parede | `~/.local/share/backgrounds/meowsystem/ativos/` | soltou o arquivo, já entrou — o `cosmic-bg` lê a pasta |
| ícones de aplicativo | `src/icons/` | `meow icones reconstruir` |
| logos do painel | **aqui** | soltou o arquivo, já entrou — o `meow-assets.path` vigia a pasta |

Os papéis de parede **moram** no repositório, em `wallpapers/` — 54 imagens,
depois da curadoria visual de 24/08/2026. Dessas, 11 sobreviveram às 242 de
`zhichaoh/catppuccin-wallpapers` (baixadas em 05/08/2026) e 43 foram buscadas na
internet naquele dia, no estilo que ela escolheu: ilustração, gato, noite,
janela, pixel art. Nada de fotografia, e nada abaixo de 1920x1080 — a tela dela
tem 2560x1440, e o que é menor chega borrado. O que não vai para o **git** são os arquivos de imagem,
barrados pela regra de `*.png`/`*.jpg` do `.gitignore`: imagem grande em git é
dívida que não se paga, e o Andromeda já ficou 18 h com o auto-sync mudo por um
arquivo de mais de 100 MB.

Quem reproduz a pasta é `scripts/wallpaper.sh semear`, lendo três receitas — o
commit pinado da coleção, o `wallpapers/FONTES.tsv` (a URL de cada uma das 54) e
o `wallpapers/BANIDOS.txt` (os 246 nomes recusados, que ele não repõe — mais
um, com emoji no nome, que só a pasta `banidos/` protege). As três
são texto, e é por isso que a escolha dela sobrevive a uma máquina reformatada.

A pasta de `~/.local/share/backgrounds/` acima é o que o `cosmic-bg` lê de fato —
`meow wallpaper adicionar <arquivo>` copia para lá com as verificações, mas
arrastar o arquivo na mão funciona igual.

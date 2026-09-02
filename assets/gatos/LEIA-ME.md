# Os gatos do painel

> **ATUALIZADO EM 01/09/2026 — O GATO DEIXOU DE GIRAR E PASSOU A SEGUIR O RELÓGIO.**
>
> O padrão agora é `LOGO_MODO="hora"`: **Coquinha de dia, Mimir de noite**, no
> botão do dock E no logo do fastfetch. A janela de noite é a da máquina inteira
> (`lib/noite.sh`), e `meow logo listar` diz qual fase está valendo e de onde a
> janela veio.
>
> A ROTAÇÃO CONTINUA INTEIRA, em `LOGO_MODO="rotacao"` — e quem já tinha
> `LOGO_ROTACAO="sim"` no conf continua nela, sem mudar nada. O que o texto
> abaixo descreve é esse modo. No modo `hora`, `meow logo girar` é **recusado
> em voz alta** em vez de fingir efeito: um giro seria desfeito pelo relógio no
> tique seguinte, no máximo cinco minutos depois.
>
> E a frase "o applet não está em barra nenhuma" continua verdadeira — mas
> deixou de importar: o gato que ela VÊ é o do dock, e desde 01/09 ele troca ao
> vivo, com `meow painel reciclar` (medido; o `logo.sh` traz a medição).

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
(`LOGO_INTERVALO` no `meow.conf`).

> **A frase "o gato do dock só troca no login seguinte" ENVELHECEU.** Ela valia
> quando ninguém reciclava o painel; desde 01/09/2026 o `logo.sh` recicla (um
> pisca de ~2 s) e chacoalha o menu de lançamento sempre que o arquivo do dock
> muda de verdade. Editar um gato que já está no ar aparece na tela em segundos,
> nas três telas. `LOGO_RECICLAR="nao"` no `meow.conf` desliga isso e devolve o
> comportamento antigo.

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

## O que o repositório conserta sozinho no seu desenho

**Desde 01/09/2026 você salva no Boxy e pronto.** Ao soltar (ou reeditar) um
`.svg` aqui, o `scripts/normalizar_svg.py` passa por ele antes de qualquer
coisa e reescreve o que os renderizadores da máquina não sabem ler.

O caso que deu origem a isto, no dia em que a Coquinha e o Mimir ganharam
dentes: o Boxy posiciona forma nova com `transform-box: fill-box` e
`transform-origin`, duas propriedades do SVG 2 que **nem o librsvg** (o
`rsvg-convert`, o GTK, o gato do terminal) **nem o resvg** (o que o COSMIC usa
para desenhar ícone de tema) implementam. Os dois leem a matriz e a aplicam a
partir do canto do arquivo: o dente do Mimir, que devia ficar embaixo da boca,
ia parar 700 px acima do desenho — fora da tela, invisível, **sem erro nenhum
em lugar nenhum**. Tudo dizia que tinha funcionado.

O conserto é aritmética (`E = T(o)·M·T(-o)`) e **não mexe no seu desenho**: o
`d=` do path e o `bx:shape=` do Boxy ficam intactos, então você reabre o
arquivo no editor e continua arrastando a peça como antes.

E o que ele **não** sabe consertar, ele **aponta**: qualquer peça que caia
inteira fora do `viewBox` vira aviso com o nome do arquivo, e uma notificação
na tela. É a diferença entre um bug de dez minutos e um de duas semanas.

Para conferir na mão, sem escrever nada:

```bash
./scripts/normalizar_svg.py --conferir assets/gatos
meow doctor            # a linha `svg` diz a mesma coisa, junto do resto
```

## As três telas, e o cache de cada uma

O mesmo arquivo aparece em três lugares, e cada um tem um cache diferente —
por isso "instalei e não apareceu" quase nunca é defeito de instalação:

| onde | quem desenha | quando relê |
|---|---|---|
| dock / painel | `cosmic-panel` | no arranque — o `logo.sh` recicla o painel quando o gato muda |
| terminal | `fastfetch` | a cada execução; o `.ansi` se refaz quando o SVG fica mais novo |
| menu de lançamento | `cosmic-app-library` | no arranque — o `logo.sh` chacoalha os dois processos |

Os três são automáticos desde 01/09/2026. Nenhum deles pede login novo.

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
| ícones de aplicativo | `assets/icones/` | `meow icones reconstruir` |
| logos do painel | **aqui** | soltou o arquivo, já entrou — o `meow-assets.path` vigia a pasta |

Os papéis de parede **moram** no repositório, em `assets/papeis-de-parede/` — 54 imagens,
depois da curadoria visual de 24/08/2026. Dessas, 11 sobreviveram às 242 de
`zhichaoh/catppuccin-wallpapers` (baixadas em 05/08/2026) e 43 foram buscadas na
internet naquele dia, no estilo que ela escolheu: ilustração, gato, noite,
janela, pixel art. Nada de fotografia, e nada abaixo de 1920x1080 — a tela dela
tem 2560x1440, e o que é menor chega borrado. O que não vai para o **git** são os arquivos de imagem,
barrados pela regra de `*.png`/`*.jpg` do `.gitignore`: imagem grande em git é
dívida que não se paga, e o Andromeda já ficou 18 h com o auto-sync mudo por um
arquivo de mais de 100 MB.

Quem reproduz a pasta é `scripts/wallpaper.sh semear`, lendo três receitas — o
commit pinado da coleção, o `assets/papeis-de-parede/FONTES.tsv` (a URL de cada uma das 54) e
o `assets/papeis-de-parede/BANIDOS.txt` (os 246 nomes recusados, que ele não repõe — mais
um, com emoji no nome, que só a pasta `banidos/` protege). As três
são texto, e é por isso que a escolha dela sobrevive a uma máquina reformatada.

A pasta de `~/.local/share/backgrounds/` acima é o que o `cosmic-bg` lê de fato —
`meow wallpaper adicionar <arquivo>` copia para lá com as verificações, mas
arrastar o arquivo na mão funciona igual.

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

Sozinho, na próxima volta do relógio — `meow-logo.timer`, a cada 30 minutos por
padrão. Se a pressa for grande:

```bash
meow logo girar     # passa para o próximo agora
meow logo listar    # mostra o acervo e quem está no ar
```

A troca vale **na hora**, sem reiniciar o painel e sem piscar a tela.

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
| logos do painel | **aqui** | soltou o arquivo, entra na próxima volta |

Os papéis de parede **moram** no repositório, em `wallpapers/` — são 242 imagens
e 193 MB, baixadas de `zhichaoh/catppuccin-wallpapers` em 05/08/2026. O que não
vai para o **git** são os arquivos de imagem, barrados pela regra de `*.png`/
`*.jpg` do `.gitignore`: imagem grande em git é dívida que não se paga, e o
Andromeda já ficou 18 h com o auto-sync mudo por um arquivo de mais de 100 MB.
Quem reproduz a pasta é `scripts/wallpaper.sh semear`, com o commit pinado.

A pasta de `~/.local/share/backgrounds/` acima é o que o `cosmic-bg` lê de fato —
`meow wallpaper adicionar <arquivo>` copia para lá com as verificações, mas
arrastar o arquivo na mão funciona igual.

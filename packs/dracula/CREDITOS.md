# Créditos do pack Dracula

O `pack.json` promete este arquivo em `"creditos": "CREDITOS.md"` desde que
nasceu, em 17/09/2026. Ele não existia, e `meow pack validar dracula` saía 0
assim mesmo — o validador aprovava um pack que prometia um arquivo que não
entregava. Os dois consertos são da P20, em 21/09/2026: o arquivo passa a
existir, e o validador passa a cobrar.

A procedência completa dos ícones deste repositório está em
[`assets/icones/PROCEDENCIA.md`](../../assets/icones/PROCEDENCIA.md), e ela
manda. O que está aqui é o recorte do que é **deste pack**.

## A paleta

| | |
|---|---|
| arquivo | `paleta.json` — 26 slots, dois flavors |
| fonte | <https://draculatheme.com/contribute> |
| conferida em | 17/09/2026 |

O flavor `dracula` traz as cores do draculatheme.com **onde ele as nomeia**, e
derivados declarados onde não. O flavor claro `alucard` — o nome que o próprio
projeto Dracula dá à variante clara — foi **derivado** em 19/09/2026, e o método
está em [`docs/PACKS.md`](../../docs/PACKS.md): matiz do Dracula, saturação e
luminância do Catppuccin Latte. O `_comentario` da `paleta.json` conta o resto.

Até 21/09/2026 estes mesmos 26 slots também moravam dentro de
`assets/paleta/catppuccin.json`, como se `dracula` fosse um flavor do
Catppuccin. Não era: era uma cópia enfiada no arquivo do outro pack, e era só
por causa dela que este pack "funcionava". A cópia saiu na P20.

## Os 18 desenhos de aplicativo — `icones/apps/`

Dezessete dos dezoito são cópia literal do `Dracula_OS-Theme`, que é repositório
do dono deste projeto; o décimo oitavo já morava aqui. O casamento aplicativo →
desenho não foi refeito: vem da SPRINT 32 daquele projeto.

| de onde veio | quantos |
|---|---|
| `src/icons/new-sessao-atual/` | 8 |
| `src/icons/current/scalable/apps/` | 5 |
| `src/icons/upstream/dracula-icons-circle/` | 2 |
| `src/icons/projects/` | 1 (`nyx.svg`, arte própria) |
| `assets/icones/resgatados/` — já daqui | 1 (`guvcview.svg`, a Câmera) |

O upstream é `dracula-icons-circle` / `dracula-icons-main`, do Dracula theme.
**Nada aqui é recolorido:** cada desenho traz de 6 a 10 cores próprias, todas já
da paleta Dracula — é arte acabada, não glifo de traço. Por isso
`icones.apps.recolorir` é `false` no `pack.json`.

## Os 7 desenhos de pasta — `icones/pastas/`

Desenho próprio deste projeto, um por pasta XDG, feitos sobre a silhueta da
pasta base em 16/09/2026. Existem porque o `catppuccin/vscode-icons` cobre os
quatro sabores do Catppuccin e nada além: não existe um `catppuccin/dracula`.

## O que este pack NÃO traz, e de quem herda

O `pack.json` diz na cara: este pack é uma paleta e dois acervos de ícone.
`meow pack info dracula` imprime a herança linha a linha.

| categoria | de quem |
|---|---|
| mimetypes | `catppuccin`, flavor `macchiato` — não existe acervo de mimetype Dracula |
| cursores | `catppuccin`, tema `catppuccin-mocha-light` — não há pack de agente Dracula com release fixável por tag |
| papéis de parede | um repositório nomeado pelas chaves `WALLPAPER_DRACULA_REPO` e `WALLPAPER_DRACULA_COMMIT` do `meow.conf` — nomear a conta de uma pessoa num arquivo versionado é o que se evita aqui |
| agente, fontes, sons de sistema, prompt, fastfetch, gatos | o pack embutido |

## Licença

O `pack.json` declara `GPL-3.0-or-later` para o pack. Os desenhos de aplicativo
são obra de terceiros ou cópia literal, e a licença de cada acervo de origem é a
que vale sobre eles — a tabela de `assets/icones/PROCEDENCIA.md` é a fonte dessa
resposta, coluna por coluna.

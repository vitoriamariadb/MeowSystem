# Créditos do pack Dracula

O `pack.json` promete este arquivo em `"creditos": "CREDITOS.md"` desde que
nasceu, em 17/09/2026. Ele não existia, e `meow pack validar dracula` saía 0
assim mesmo — o validador aprovava um pack que prometia um arquivo que não
entregava. Os dois consertos são da P20, em 21/09/2026: o arquivo passa a
existir, e o validador passa a cobrar.

A procedência completa dos ícones deste repositório está em
[`packs/meowsystem/PROCEDENCIA.md`](../meowsystem/PROCEDENCIA.md), e ela
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

## Os desenhos de aplicativo — `icones/apps/` e `icones/biblioteca/`

**A tabela desta seção é a do nascimento do pack, 17/09/2026, com os 18
desenhos de então.** Ela ficou velha em 23/09, quando a P36 trouxe a
biblioteca, e não foi refeita: a conta de 24/09/2026 é de 72 desenhos em
`icones/apps/` e 295 em `icones/biblioteca/`, e cada um tem a sua linha — de
onde veio, licença, data e `sha256` — no [`PROCEDENCIA.md`](PROCEDENCIA.md)
deste pack.

Dezessete dos dezoito são cópia literal do `Dracula_OS-Theme`, que é repositório
do dono deste projeto; o décimo oitavo já morava aqui. O casamento aplicativo →
desenho não foi refeito: vem da SPRINT 32 daquele projeto.

| de onde veio | quantos |
|---|---|
| `src/icons/new-sessao-atual/` | 8 |
| `src/icons/current/scalable/apps/` | 5 |
| `src/icons/upstream/dracula-icons-circle/` | 2 |
| `src/icons/projects/` | 1 (`nyx.svg`, arte própria — saiu do pack em 24/09/2026, com a P43: era projeto pessoal, e projeto pessoal não entra num pack exportável) |
| `assets/icones/resgatados/` — já daqui | 1 (`guvcview.svg`, a Câmera) |

O upstream é `dracula-icons-circle` / `dracula-icons-main`, do Dracula theme.
**Nada aqui é recolorido:** cada desenho traz de 6 a 10 cores próprias, todas já
da paleta Dracula — é arte acabada, não glifo de traço. Por isso
`icones.apps.recolorir` é `false` no `pack.json`.

## Os 7 desenhos de pasta — `icones/sistema/pastas/`

Desenho próprio deste projeto, um por pasta XDG, feitos sobre a silhueta da
pasta base em 16/09/2026. Existem porque o `catppuccin/vscode-icons` cobre os
quatro sabores do Catppuccin e nada além: não existe um `catppuccin/dracula`.

## O que este pack NÃO traz, e de quem herda

Até 24/09/2026 este parágrafo dizia que o pack era "uma paleta e dois acervos
de ícone", e a tabela punha o ponteiro no `catppuccin` por falta de um release
Dracula fixável por tag. As duas frases envelheceram com a P41, que achou o
release e pinou dois pacotes que quem instala baixa e confere pelo `sha256`: a
base de ícones (`m4thewz/dracula-icons`, ramo `circle`, commit `00a230a2`,
GPL-3.0) e o ponteiro (`Dracula-cursors.tar.xz`, release v4.0.0 do
`dracula/gtk`, GPL-3.0). Depois dela a P42 trouxe cinco temas de aplicativo, e
o sino (o bloco `som`) já era do pack. Recontado pelo `meow pack info dracula`,
que imprime a herança linha a linha, o que o pack não traz é isto:

| categoria | de quem |
|---|---|
| mimetypes | `catppuccin`, flavor `macchiato` — não existe acervo de mimetype Dracula |
| mapa do COSMIC | `catppuccin` — `cosmic.mapa` é `null`: vale o molde inteiro, e só o nome da paleta muda |
| tema do qBittorrent | `catppuccin` — o `dracula.qbtheme` não tem procedência, e o `_nota_qbittorrent` do `pack.json` conta por que não entrou |
| fontes | a herança manda buscar no `catppuccin`, que não traz nenhuma: vale a Nerd Font do motor |
| papéis de parede | um repositório nomeado pelas chaves `WALLPAPER_DRACULA_REPO` e `WALLPAPER_DRACULA_COMMIT` do `meow.conf` — nomear a conta de uma pessoa num arquivo versionado é o que se evita aqui |
| prompt, fastfetch, gatos | o motor (`assets/`), igual para todo pack — o formato ainda não tem campo para eles |

## Licença

O `pack.json` declara `GPL-3.0-or-later` para o pack. Os desenhos de aplicativo
são obra de terceiros ou cópia literal, e a licença de cada acervo de origem é a
que vale sobre eles — a tabela de `packs/meowsystem/PROCEDENCIA.md` é a fonte dessa
resposta, coluna por coluna.

# Créditos do pack Catppuccin

Este é o pack **padrão** do MeowSystem: o que acompanha o projeto e o que todo
pack herda quando não declara uma categoria. Até 22/09/2026 ele não era um pack
— era a constante `PACK_EMBUTIDO` no `scripts/pack.py` e um JSON dentro de
`assets/`. A P13 o transformou num pack como os outros, sem privilégio nenhum.

A procedência completa dos ícones deste repositório está em
[`assets/icones/PROCEDENCIA.md`](../../assets/icones/PROCEDENCIA.md), e ela
manda. O que está aqui é o recorte do que é **deste pack**.

## A paleta

| | |
|---|---|
| arquivo | `paleta.json` — 26 slots, quatro flavors |
| fonte | <https://github.com/catppuccin/catppuccin> |

**Os 26 nomes são do Catppuccin, e o projeto inteiro fala por eles.** Eles não
são "as cores do Catppuccin": são o **vocabulário** com que todo pack declara
cor — o `cosmic-map.json` mapeia cada slot do tema do COSMIC para um desses
nomes e nunca cita um hex, e o Dracula preenche os mesmos 26. Ver
[`docs/PACKS.md`](../../docs/PACKS.md), seção "As 26 cores".

Até 21/09/2026 este arquivo também carregava um flavor `dracula`, que não era
do Catppuccin: era uma cópia enfiada no arquivo do pack errado, e era só por
causa dela que o Dracula "funcionava". A cópia saiu na P20. O arquivo ficou com
os quatro sabores que são de fato do Catppuccin — `latte`, `frappe`,
`macchiato` e `mocha`.

## Os glifos — `icones/mimetypes/`

| | |
|---|---|
| upstream | [`catppuccin/vscode-icons`](https://github.com/catppuccin/vscode-icons) |
| licença | MIT — o texto está em `icones/mimetypes/LICENSE` |
| pode modificar | sim |
| pode redistribuir | sim, com o aviso de copyright |
| quantos | 656 por sabor, em quatro sabores, mais o `css-variables` que o upstream publica junto |

**Um acervo só veste duas categorias**, e é por isso que `icones.mimetypes` e
`icones.pastas` apontam para o mesmo diretório no `pack.json`: o upstream
publica os 230 glifos de pasta (`folder-*.svg`) junto com os de tipo de
arquivo. A forma é a mesma — `fill="none"` + `stroke`, `viewBox="0 0 16 16"`,
traço de árvore de arquivos do VS Code. Separá-los aqui seria inventar uma
divisão que a origem não tem.

Quem consome: `scripts/icones_mimetypes.sh` (os tipos de arquivo) e
`scripts/icones_pastas.sh` (as pastas XDG).

## O que NÃO é deste pack, e mora em `assets/`

A fronteira é de dono, não de assunto. O `assets/paleta/cosmic-map.json` é
**motor** — é o molde do tema do COSMIC, e não tem um hex dentro. Ele ficou
onde estava quando a paleta se mudou, e os dois eram irmãos no mesmo diretório.

O mesmo vale para `assets/icones/autorais/` (o traço deste projeto),
`assets/icones/arcticons*/`, `convertidos-apps/` e `resgatados/`: são acervos
do motor, e vestem qualquer pack.

## Licença

Os glifos são MIT, do `catppuccin/vscode-icons`, com o texto ao lado deles. A
paleta é a especificação de cor do Catppuccin, publicada pelo próprio projeto.
O que este repositório escreve em cima disso — o `pack.json`, este arquivo — é
GPL-3.0-or-later, como o resto do MeowSystem.

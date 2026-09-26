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

## O tema do COSMIC: a Light da `mocha-pink` é derivada — 25/09/2026, sprint P68

`temas/capturados/` não é arte de terceiro: cada pasta é o `~/.config/cosmic`
desta máquina com o tema aplicado, fotografado pelo `scripts/capturar_tema.sh`
(a hora e a casa estão no `captura.txt` dela). O que o COSMIC escreveu vai
byte a byte, e o `manifesto.sha256` dá o sha256 de cada arquivo.

**Uma árvore deixou de ser foto: a Light da `mocha-pink`.** A foto de
04/08/2026 trouxe no claro o Latte com o acento **mauve** (`#8839EF`), porque
era o que a GUI tinha no modo claro naquele dia; com FLAVOR=mocha, ACCENT=pink
e MODO=claro o COSMIC vestia `catppuccin-latte` com `Some("#8839EFFF")`, e a
página e a prévia prometiam o pink do latte, `#EA76CB`. Desde a P68 as duas
árvores Light da foto (`Light/` e `Light.Builder/`) são as do Latte no pink,
**derivadas, não copiadas**:

- **Por onde.** O `derivar_arvore` do `scripts/derivar_acento.py` — o mesmo
  que a P48 dá ao acento sem fotografia e a P66 ao lado do par das derivadas —,
  na Light da própria foto, com o `pink` do latte da `paleta.json`. A guarda
  passa (a Light da foto se reproduz com o mauve que declara), e mudam 34
  arquivos: 19 da `Light/v2`, 14 da `Light/v1` (refeita pela mesma função do
  `scripts/gerar_tema_v1.py`) e o `accent` da receita. O que não é acento —
  a neutra, o fundo, o vidro, os cantos — continua o da foto, byte a byte.
- **O comando**, rodado da raiz do repositório:

  ```
  MEOW_PACK_DIR=$PWD/packs/catppuccin python3 - <<'PY'
  import json, sys; from pathlib import Path
  sys.path.insert(0, "scripts")
  import derivar_acento as da, gerar_tema_v1 as v1
  cap = Path("packs/catppuccin/temas/capturados/mocha-pink")
  rosa = json.load(open("packs/catppuccin/paleta.json"))["flavors"]["latte"]["pink"]
  for rel, txt in da.derivar_arvore(cap, "Light", rosa).items():
      (cap / rel).write_text(txt)
  ficha = cap / "captura.txt"
  ficha.write_text(ficha.read_text() + f"claro: o da foto, no pink do latte, "
                   f"{rosa.upper()} (scripts/derivar_acento.py)\n")
  v1.refazer_manifesto(cap)
  PY
  ```

  O `captura.txt` ganhou a linha `claro: o da foto, no pink do latte, #EA76CB
  (scripts/derivar_acento.py)`, e o manifesto foi refeito pelo mesmo comando
  do `capturar_tema.sh` (35 linhas mudam: os 34 e o `captura.txt`). A Dark, a
  Dark.Builder e o Mode não mudam um byte.
- **A trava.** O `tests/notas-de-funcao.sh` aplica a foto pelas etapas do
  instalador e confere o pink na receita e em todo foco da Light, e confere
  que o `derivar_arvore` não muda um byte da Light da foto do repositório —
  uma Light copiada à mão, ou uma porta do `build()` que mudou, derruba o
  teste. O caso saiu do `CONHECIDOS` dele, onde a P66 o deixou.
- **As derivadas.** As capturas de acento do mocha saem desta foto; a Light
  delas é a mesma de antes, byte a byte, menos no `mocha-red` e no
  `mocha-blue`, em que o `on` branco da `Light/v1/accent_button` passa a ser
  escrito `1.0`, e não `0.99999994` — o mesmo `#FFFFFF` em 8 bits. Elas nascem
  na máquina e se refazem sozinhas na etapa `gerar` do instalador.

Este é o arquivo da procedência deste pack (o `LEIA-ME.md` diz). Um
`PROCEDENCIA.md` na raiz do pack, como o do Dracula, não serve aqui: o `meow
pack sincronizar catppuccin` lê a tabela de arte copiada dele e recusa um
`PROCEDENCIA.md` sem ela.

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

# Cursores do MeowSystem — origem e licença

Regra do projeto: **nenhum acervo de terceiro entra sem licença registrada aqui.**
Este arquivo é o registro no repositório; o `scripts/cursor.sh` não precisa
escrever uma cópia à parte porque o pacote **já traz o seu próprio `LICENSE` e
`AUTHORS` dentro do diretório do tema**, e a instalação move o diretório inteiro
— então a auditoria na máquina dela é `ls ~/.local/share/icons/<tema>-cursors/`.

Este diretório **não guarda cursores**, e isso é de propósito: são 120 arquivos
XCursor binários (~11 MB descompactados) por flavor, baixados de um release
versionado em tempo de instalação. Binário grande em git é exatamente o que a
regra de `*.png`/`*.jpg` do `assets/papeis-de-parede/FONTES.tsv` já evita — aqui vale o mesmo
princípio: **a receita vai para o git, o acervo não.**

## O que é instalado

| destino | origem | licença |
|---|---|---|
| `~/.local/share/icons/catppuccin-<flavor>-<accent>-cursors/` | [catppuccin/cursors](https://github.com/catppuccin/cursors) `v2.0.0`, recoloração do [volantes-cursors](https://github.com/varlesh/volantes-cursors) | **GPL-2.0** |
| `~/.icons/default/index.theme` | escrito por `scripts/cursor.sh` (obra do projeto) | — (arquivo de 4 linhas, é ponteiro, não acervo) |

**A licença é GPL-2.0 e foi conferida no arquivo, não na página do projeto:** o
`LICENSE` dentro do zip abre com `GNU GENERAL PUBLIC LICENSE / Version 2, June
1991`. Compatível com a GPL-3.0 deste repositório na direção em que precisamos
(redistribuir/derivar sob GPL-3.0), e de qualquer forma **nós não derivamos nem
redistribuímos**: o script baixa do release oficial na máquina dela, sem
reempacotar. É o mesmo modelo do `assets/papeis-de-parede/FONTES.tsv`.

### Autoria, como o `AUTHORS` do pacote declara

- **Cursores:** Alexey Varfolomeev (`varlesh`) — volantes-cursors; Kylie
  (`covkie`) — conversão para o template whiskers.
- **Cores:** `elkrien` — recoloração com a paleta Catppuccin.
- **Script de build:** Sergei Eremenko, Keefer Rourke, Goudham Suresh, Jeffrey
  Geer, e os autores do script de cursores do Breeze/KDE.

## A receita (o que reproduz o acervo)

| flavor instalável | URL do release |
|---|---|
| `catppuccin-<flavor>-<accent>` | `https://github.com/catppuccin/cursors/releases/download/v2.0.0/catppuccin-<flavor>-<accent>-cursors.zip` |

O release `v2.0.0` publica **64 zips**: 4 flavors (latte, frappe, macchiato,
mocha) × 16 variantes (14 accents + `dark` + `light`). A versão é fixada em
`CURSOR_VERSAO` no `scripts/cursor.sh` para que o acervo não mude debaixo dela
sem ninguém decidir.

## O que foi MEDIDO sobre o corpo do cursor, e por que está aqui

Registrado neste arquivo porque é a informação que faz escolher um flavor, e ela
**contradiz o que se supõe pelo nome**. Contagem de pixel opaco no `default` de
cada tema, cor dominante = corpo, segunda cor = contorno:

| tema | corpo | contorno | luminância do corpo |
|---|---|---|---|
| `catppuccin-latte-mauve` | `#8839ef` | `#eff1f5` | **86,9**/255 |
| `catppuccin-frappe-mauve` | `#ca9ee6` | `#303446` | 172,6/255 |
| `catppuccin-mocha-mauve` | `#cba6f7` | `#1e1e2e` | **179,7**/255 |
| `Pop` (fábrica) | `#ffffff` | `#313131` | 255,0/255 |
| `Adwaita` (fábrica) | `#000000` | `#ffffff` | 0,0/255 |

Nos flavors com nome de **accent** (`-mauve`), o corpo recebe a cor do accent e o
contorno recebe a cor **Base** do flavor. Ou seja, é o **inverso** da intuição:
o Latte-mauve é o de corpo mais **escuro** dos três, e o Mocha-mauve é o mais
**claro**. A regra "só o Latte tem corpo claro" vale para as variantes
`-light`/`-dark` do mesmo release, **não** para as de accent.

## O que NÃO foi usado, e por quê

| candidato | por que ficou de fora |
|---|---|
| `/usr/share/icons/Pop/cursors` (fábrica) | É a marca do Pop!_OS ocupando o lugar da identidade dela — o mesmo motivo da Sprint Q. E não é sequer o cursor que aparece no desktop dela hoje (ver abaixo). |
| `/usr/share/icons/Adwaita/cursors` | Corpo **preto** (`#000000`). É o que o `/usr/share/icons/default/index.theme` herda hoje, e é o pior caso possível sobre o papel de parede escuro da Sprint S. |
| instalar em `/usr/share/icons` | Território travado pela **TRAVA 1** do `lib/comum.sh`, e um `apt upgrade` sobrescreveria. |
| `catppuccin-*-dark-cursors` / `-light-cursors` | Não têm o accent dela. Ficam registrados como saída caso ela queira corpo claro **sem** lilás. |

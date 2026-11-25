# Os dois packs equiparados (25/11/2026)

Pedido: «concluir os dois temas, equiparar eles de fato». Parte da folha
`../2026-11-25-os-tres-pcs-em-dia/O-QUE-FALTA-NOS-DOIS-PACKS.md`.

## O que a medida mudou na folha
- Ponteiro e ícones-base do `meowsystem` não são falta: o Catppuccin resolve os dois pelo `meow.conf` (`CURSOR`, com
  variante por flavor e acento, e o Papirus com as pastas pintadas), o Dracula pelo `pack.json`. Dois caminhos, o
  mesmo resultado; declarar no pack tiraria a escolha de variante dela.
- VLC não precisa de módulo: é Qt e segue o `qt5ct`/`qt6ct` que o `toolkits-gtk-qt` já escreve.
- Das seis «cores cravadas», três eram texto de ajuda; o ramo do btop nunca rodava (saiu na P299); a reserva do
  `_tinta_do_traco` só vale com paleta sem `text`. Sobra o `gerador_circulo.py`, que crava a paleta do Dracula.
- Ninguém usa VS Code no nitro-5: o tema de ícones de arquivo do Dracula não aparece em tela nenhuma hoje.

## Os blocos
| bloco | o quê | estado |
|---|---|---|
| 1 · código | P299, o btop sem o mauve do Mocha cravado | feito, commit `b02bd98` |
| 2 · desenhos do Catppuccin | 10 apps sem desenho; folha em `~/.cache/meow-leva/folha-desenhos-2026-11-25.png` | espera a escolha dela |
| 3 · módulos de app | Godot, GIMP, ghostwriter (`BLOCO-APPS-SEM-MODULO.md`) | voando na worktree `.worktrees/meow-apps-2511`, branch `bloco/apps-sem-modulo` |
| 4 · desenhos do Dracula | Dédalo, FogStripper, Pipeline EducaDados no nitro-5 | na fila do André (`b6b2791a`) |

## O bloco 3
Dois agentes, um de cada vez: `implementa-apps` (agente, alto), depois o conferente (agente, alto), que confere e
corrige. A prova na tela é de quem coordena: os módulos só entram no `master` depois de ela ver a captura de cada
app aberto.

## Fica com quem usa
- Os códigos da folha de desenhos (e a cor de cada um).
- Os cinco campos do Dracula sem leitor: estão no formato do manual (`docs/PACKS.md`, exemplo e aviso); ganhar leitor
  ou sair do formato muda o manual, não a tela.
- Papéis de parede do Catppuccin (3 pares contra 19 desenhos do Dracula) e as capturas da vitrine: arte.
- GitHub Desktop, Foundry VTT e cliente da Steam: sem tema possível sem cliente modificado.

## Próximo passo
1. Chegando o relato do `implementa-apps`: medir de novo o que ele afirma, lançar o conferente.
2. Chegando os códigos da folha: escrever as linhas nos mapas (`apps-arcticons.map`, `apps-convertidos.map`), com
   teste; construir e instalar só com o sim dela.
3. Suíte inteira uma vez, integração no `master`, instalador nos três PCs.

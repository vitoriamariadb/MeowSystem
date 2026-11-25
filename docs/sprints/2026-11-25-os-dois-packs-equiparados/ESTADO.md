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
| 2 · desenhos do Catppuccin | oito escolhidos e instalados: os seis do Arcticons (decisão 69), o COSMIC Viewer 1G (decisão 70) e o FogStripper 8G, desenho à mão, no estado de quem usa do MeowSystem (não há FogStripper no portátil) | feito; A Forja e o Pipeline esperam o atalho |
| 3 · módulos de app | Godot, GIMP, ghostwriter (`BLOCO-APPS-SEM-MODULO.md`) | voando na worktree `.worktrees/meow-apps-2511`, branch `bloco/apps-sem-modulo` |
| 4 · desenhos do Dracula | Dédalo, FogStripper, Pipeline EducaDados no nitro-5 | na fila do André (`b6b2791a`) |

## O que falta do bloco 2
- FogStripper: ela pediu o logo repensado como «a pata de um gato tocando um espelho quebrado» e aprovou o 8G («é
  incrível»): SVG escrito à mão, pata na diagonal com dedos recortados e almofada, cinco trincas. Entrou pelo mesmo
  caminho da oficina do painel (`_api_app_desenho`, ação `salvar`): linha `fogstripper:mao:sky` em
  `~/.config/meow/icones-convertidos.map`, retoque em `~/.local/share/meowsystem/retoques/`, e `fogstripper` em
  `icones-destravados.list`. Cópia do SVG em `~/.cache/meow-leva/fogstripper-8G.svg`.
- A Forja (9A, mauve), Pipeline EducaDados (10A, green) e o FogStripper são projetos dela: `tests/pack-dracula-completo.sh`
  recusa arte pessoal em `packs/`. Vão no mapa de quem usa (`~/.config/meow/icones-convertidos.map`), por PC. A Forja
  e o Pipeline têm `Icon=` de caminho absoluto no atalho (`forja.desktop`, `pipelines-educadados.desktop`), que
  nenhum tema alcança: o atalho muda no projeto de cada um. O FogStripper é intocável até entrar em
  `~/.config/meow/icones-destravados.list`.
- O Godot da Steam (`steam_icon_404790`) também é intocável por regra: foi destravado no MeowSystem, pela escolha
  dela. No portátil não há atalho do Godot.

## O bloco 3
Os três módulos fechados na worktree pelo `implementa-apps`: godot `29f8bad`, gimp `feb29d5`, ghostwriter `9054fbc`.
Medido por quem coordena no nitro-5: o ghostwriter flatpak guarda mesmo em `config/kde.org/ghostwriter.conf` (seção
`[Style]`; existe também uma `[style]` minúscula, a conferir) e `data/ghostwriter/themes`. Falta o conferente e a
passada na tela.

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

# P107 — Todo app tem tema em todo pack, ligado de fábrica

**Status: FEITA em 24/10, na branch `sprint/p107`.** Quem usa (24/10): «Cada theme ter seu conjunto de features pré-configuradas em
default. Tipo ZapZap, Telegram, Spotify e afins. Hoje é tudo Dracula, mas o meowsystem em si fica sem nada.
Bota dois Claudes pra ir fazendo esse port e criando a versão do meowsystem do que falta. Pra todos os apps.»

## O que se mediu (24/10, contagem rápida; refaça a medida antes de mexer)
- Os módulos estão em `scripts/temas-de-apps/`: btop-bat, discord, gnome-terminal, heroic, kitty, obsidian,
  onlyoffice, qbittorrent, spotify, telegram, toolkits-gtk-qt, vscode e zapzap.
- O bloco de temas de app de cada `pack.json` é assimétrico:
  - O Dracula declara qbittorrent e 5 modelos da P42, que o `modelo.py` preenche pela paleta.
  - O meowsystem declara spotify, qbittorrent, obsidian (vendorado), vscode e heroic (acervo catppuccin/heroic).
  - Arquivos de tema dentro do pack: `packs/dracula/temas-de-apps/{btop-bat,qbittorrent}` e
    `packs/meowsystem/temas-de-apps/{btop-bat,heroic,obsidian,qbittorrent}`.
- A frase de quem usa e o desenho se contradizem em parte. Há app em que só o meowsystem tem tema (heroic,
  obsidian) e app em que só o Dracula tem. O que vale é a matriz medida, não a frase.

## Matriz

Medida em 24/10 numa casa de brinquedo, sem rede, `PACK=<pack>` e o flavor padrão (o claro entre
parênteses quando difere): o `aplicar` de cada módulo, e o hex do `base` de cada pack procurado no que
ele escreveu. «modelo» é o modelo do motor com a paleta do pack; «pinado» desce da origem pinada.

| app | meowsystem antes | meowsystem depois | dracula antes | dracula depois |
|---|---|---|---|---|
| kitty | nada (não declarado) | modelo, cor do pack | modelo | modelo |
| gnome-terminal | nada (não declarado) | modelo, cor do pack | modelo | modelo |
| telegram | nada (não declarado) | modelo, cor do pack | modelo | modelo |
| discord | nada (não declarado) | modelo, cor do pack | modelo | modelo |
| onlyoffice | nada (não declarado) | modelo, cor do pack | modelo | modelo |
| spotify | catppuccin pinado | igual | Sleek sem origem: nada numa máquina sem o tema | Sleek vendorado no pack, sai sem rede |
| qbittorrent | catppuccin-mocha.qbtheme | igual | dracula.qbtheme oficial | igual |
| obsidian | Catppuccin vendorado | igual | Dracula Official pinado (baixa) | igual |
| vscode | extensão Catppuccin | igual | extensão Dracula pinada (baixa); ícones: nenhum | igual |
| heroic | catppuccin vendorado | igual | o `dracula` do próprio Heroic | igual |
| btop-bat | catppuccin vendorado (pelo flavor) | igual | dracula vendorado; alucard: nada | igual |
| toolkits-gtk-qt | segue o COSMIC | igual | segue o COSMIC | igual |
| zapzap | fora deste bloco (P106) | | | |

Nenhum tema de um pack apareceu no outro, antes ou depois (hex do `base` do outro pack: zero arquivos).
A prova é o `tests/apps-em-todo-pack.sh`.

## A cura
1. **A matriz:** para cada app × pack, meça com `PACK=<pack>` num HOME temporário: o módulo aplica um tema com as
   cores DESSE pack? Ou cai no do outro pack, em nada, ou num tema cravado? Escreva a matriz numa seção
   «## Matriz» nesta tarefa, antes e depois.
2. **Fechar os buracos nos dois sentidos:** todo app ganha tema nos dois packs, declarado no `pack.json` de cada
   um. Tema por modelo (`{{papel}}` + `modelo.py`) quando o app aceita; tema vendorado de origem pinada (com
   procedência e licença no `PROCEDENCIA.md`) quando existe um tema oficial do Catppuccin ou do Dracula para o
   app. Nenhum app com tema cravado de um pack no outro.
3. **Ligado de fábrica:** o conjunto de apps que cada pack veste vem ligado no padrão (o `meow.conf.exemplo` e o
   que o install aplica). Um app não instalado fica pendente em silêncio, como hoje. A regra de «tema de
   terceiro» (`lib/comum.sh`: perguntar, não escrever por cima) continua.
4. **Fora deste bloco:** o ZapZap (a P106 está fazendo o CSS dele, pela paleta, para os dois packs). Não toque em
   `scripts/temas-de-apps/zapzap/`.

## Cuidados
- Pack é dado, nunca código. O `pack.py validar` tem de aceitar cada bloco novo e recusar o malformado.
- Licença: tema de terceiro só entra com licença que permita redistribuir, citada no `PROCEDENCIA.md`.
- Teste e QA só com HOME temporário. Nada de `meow apps aplicar` no HOME real.

## Como se prova
- `tests/temas-de-apps.sh` (ou o certo) ganha a matriz como teste: para cada app × pack, o tema aplicado tem as
  cores do pack (procure o hex da paleta no arquivo gerado) e não as do outro.
- Ida e volta de pack: os temas trocam juntos. A segunda passada fica quieta. `tests/todos.sh` duas vezes verde.

## 5. Achado de segurança (quem coordena, 24/10; vale para TODO módulo tocado neste bloco)
- `scripts/temas-de-apps/spotify/manifesto.sh`: o `_SPOT_TEMA_NOME` vem do pack (`$MEOW_APP_TEMA`) e monta
  `$_SPOT_CONFIG_DIR/Themes/$_SPOT_TEMA_NOME`, que leva `rm -rf`. Um pack importado com nome `..` ou com `/`
  apaga fora da pasta de temas. Já era assim no dev; o `5a3244b7` mexeu ao lado.
- Cura: o nome do tema só passa se casar com `^[A-Za-z0-9_][A-Za-z0-9._-]*$` (sem `.`, `..` ou `/`). O
  `pack.py validar` recusa esse campo fora da forma. Antes de todo `rm -rf`, `readlink -m` do alvo tem de ser
  filho direto de `readlink -m "$_SPOT_CONFIG_DIR/Themes"`. Confira o mesmo padrão (nome do pack → caminho →
  `rm`/`mv`) em todo módulo que este bloco tocou.
- Prova: `tests/pack-malicioso.sh` com `..` e com `a/b` no nome do tema do Spotify: recusado e nada apagado.

## Fecho (24/10)

- O meowsystem declara kitty, gnome-terminal, telegram, discord e onlyoffice (`{}`: o modelo do motor
  com a paleta dele). O Dracula traz o Sleek do spicetify no pack (`temas-de-apps/spotify/Sleek/`,
  MIT, pinado no commit `c4320124` do spicetify/spicetify-themes), e o módulo o entrega sem rede.
- O `meow.conf.exemplo` já ligava todos os módulos no `APPS_ATIVOS`; agora o teste cobra.
- `tests/todos.sh` duas vezes: 78, 77 verdes, 1 pulado (o `pack.sh` sem o `Dracula_OS-Theme`, que
  saiu da máquina), 0 vermelhos.

### O que fica
- btop-bat: o tema sai da família do flavor (P49), não do `pack.json`; os dois packs vestem, o
  `alucard` não tem tema de btop nem de bat.
- O Dracula no claro (`alucard`): Heroic, Spotify, Obsidian e VS Code vestem o Dracula escuro, que é o
  único tema oficial que existe para eles.
- VS Code no Dracula sem tema de ícones (o pack não declara; o Catppuccin herdado é recusado).
- toolkits-gtk-qt segue o COSMIC, sem bloco no pack. ZapZap é da P106.
- `tests/temas-de-apps.sh` falhou uma vez em três («nenhum backup guarda o appearance.json
  tematizado do A», Obsidian): o backup é por segundo, e o aplicar e o desfazer caem no mesmo.

# P107 — Todo app tem tema em todo pack, ligado de fábrica

**Status: EM VOO em 24/10.** Quem usa (24/10): «Cada theme ter seu conjunto de features pré-configuradas em
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

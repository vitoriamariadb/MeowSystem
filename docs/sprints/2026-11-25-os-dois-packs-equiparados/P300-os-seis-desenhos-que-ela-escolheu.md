# P300 · Os seis desenhos que ela escolheu (decisão 69)

## O que se mediu
Dez apps instalados caem no ícone de fábrica com o `meowsystem` no ar. Na página dos desenhos, em 25/11, ela escolheu
seis glifos do Arcticons: Câmera `opencamera` (teal), VLC `vlc` (peach), Steam Link `steamlink` (sapphire), Azahar
`lime3ds` (yellow), Super ZSNES `snes9x` (red) e o Godot que vem pela Steam `godot` (blue).

## A cura
- Seis linhas em `packs/meowsystem/icones/apps-arcticons.map`.
- Cinco glifos novos em `packs/meowsystem/icones/apps/` e na `arcticons.lista`; o do VLC já estava na `biblioteca/`,
  idêntico, e é de lá que o motor o tira.
- Decisão 69 em `docs/DECISOES.md`, guardada por `tests/decisoes.sh`.

Isto é o gerador. Pôr os seis ícones na tela é rodar o instalador, com o sim dela.

## O que ficou de fora
- COSMIC Viewer e FogStripper: ela pediu o original melhorado; as opções novas estão na página.
- A Forja, Pipeline EducaDados e FogStripper são projetos de quem usa: `tests/pack-dracula-completo.sh` recusa arte
  pessoal dentro de `packs/`. O desenho deles vai no mapa de quem usa (`~/.config/meow/icones-convertidos.map`), em
  cada PC. A Forja e o Pipeline têm ainda o `Icon=` de caminho absoluto no atalho, que nenhum tema alcança.

## A prova
`tests/pack-dracula-completo.sh` ganhou «os seis desenhos escolhidos em 25/11»: vermelho antes das linhas, verde
depois. Verdes pelo `todos.sh`: `pack-dracula-completo.sh`, `decisoes.sh`, `estilo.sh`, `acervo-da-ficha.sh`,
`git-limpo.sh`, `destrava.sh`, `afinador.sh`, `cosmic-prever.sh`, `seletor-do-pack.sh`.

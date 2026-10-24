# P96 — O repositório arrumado para a versão definitiva

**Pedido de quem usa (23/10):** «o repo tá um caos e tá vergonhoso assim, sem contar que tá difícil de se
localizar e fazer algo aqui». Vai instalar o MeowSystem num PC recém-formatado (**Pop!_OS 24.04 COSMIC**),
e do jeito atual não funciona nem o MeowSystem, nem o Dracula, nem as demais features.

## A forma pedida
1. `packs/` tem **dois** packs: `meowsystem` (o padrão, que é o meow + o Catppuccin: o `catppuccin` atual
   entra nele) e `dracula`.
2. Dentro de cada pack mora **tudo** do tema: ícones, sons, temas, temas de apps, wallpapers e afins.
   Qualquer pasta do repositório que seja de tema migra para o pack, com os scripts e caminhos que a leem.
3. `icones/` de cada pack tem **só três pastas, sem subpastas**: `biblioteca` (tudo), `apps` (os ícones
   escolhidos para os apps) e `sistema` (o que o PC precisa para funcionar: pastas, mimetypes, etc.).
4. `assets/` é só o que o MeowSystem **como programa** precisa. O resto vai para o pack certo.
5. `.trabalho-icones/`, `contratos/` e afins: ou saem, ou vão para o canto certo.
6. Pasta vazia sai. Ícone repetido sai.
7. Branches locais: ficam só `dev` e `master` (depois de tudo integrado no dev).

## Decisões de quem usa (23/10)
- Os 47 SVG de `~/Desktop/manuais-final/` são a arte do Dracula feita à mão. Os ícones de
  pasta (`folder-*`, `user-home`, `user-desktop`) vão para `packs/dracula/icones/sistema`; o resto vai para
  `packs/dracula/icones/apps`. Eles corrigem tudo o que tiver o mesmo ícone.
- **Projetos pessoais entram no Dracula** (Beholder, Elden Ring Tracker, Protocolo Ouroboros, Luna, Mnemo,
  ArcaneTab, Crononauta): a regra de 23/09 / P90 item 8 é revogada para ícones, com o sim de 23/10.
- **Uma versão por ícone**: a do `manuais-final` quando existir; as versões antigas saem (o git guarda).

## Como se prova
- `tests/todos.sh` inteiro verde duas vezes sobre o resultado; `tests/decisoes.sh` com as linhas trocadas;
- instalação limpa numa casa de brinquedo (o `tests/convergencia.sh` e o `install.sh` com HOME temporário)
  com o pack `meowsystem` e com o `dracula`;
- `find . -type d -empty` vazio; nenhuma pasta de ícone com subpasta; nenhum caminho velho no código.

## Regra de quem usa (23/10): o SVG do pack é a fonte única
«Se eu editar um dos SVGs do theme pack, o resto do projeto se adapta e usa o novo SVG alterado.»
Nenhuma cópia de arte fora do pack. Tudo o que deriva dela (o tema de ícones instalado, os mimetypes
pintados a partir do molde, os PNG, as prévias do painel, o mascote do dock e do fastfetch) se refaz a partir
do arquivo do pack quando ele muda, sozinho, pelo vigia que já existe, sem comando e sem reinstalar.
**Prova:** numa casa de brinquedo, editar um SVG em `packs/<id>/icones/apps/` faz o derivado mudar, e a
segunda passada não escreve nada.

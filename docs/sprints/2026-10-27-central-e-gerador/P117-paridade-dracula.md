# P117: o Dracula no nível do MeowSystem, pasta por pasta

Item 3 do `ANDAMENTO.md`. A tabela inteira está em `relatorios/levantamento-painel.md` §2. Esta
sprint fecha só os buracos medidos; o que já é igual de propósito fica como está.

## O que se mediu
- `packs/meowsystem/icones/` traz `sistema/` (688 SVG: tipos de arquivo e pastas), `sistema.map` (191 linhas) e `bandeja.map` (322 linhas).
- `packs/dracula/icones/` traz `sistema/` só com as 10 pastas, e nenhum `sistema.map` ou `bandeja.map`.
- Os quatro scripts de ícone de status leem caminhos fixos do outro pack:
  - `scripts/icones_sistema.sh:8-9` lê `ORIGEM=$RAIZ/packs/meowsystem/icones/sistema` e `MAPA=…/sistema.map`;
  - `scripts/icones_bandeja.sh:8-9` lê `…/packs/meowsystem/icones/{sistema,bandeja.map}`;
  - `scripts/icones_tray_steam.sh:118` e `scripts/icones_tray_zapzap.sh` leem o glifo em `packs/meowsystem/icones`.
- Nenhum dos quatro lê o pack no ar (`grep -n "meow_pack\|PACK" scripts/icones_sistema.sh scripts/icones_bandeja.sh` não acha nada). A lista `VERIFICAVEIS` (`bin/meow:1376`) os roda em todo pack.
- Com o Dracula no ar, então, a bandeja e os ícones de status são os Arcticons do MeowSystem. Isso quebra a decisão 3 de `docs/DECISOES.md`.
- `packs/dracula/pack.json` declara `origens.cursores.tema: "catppuccin-mocha-light"`. O campo só aparece na lista de conhecidos (`scripts/pack.py:252`) e ninguém o lê. O valor é do outro pack.
- **Não medido:** se a camada-base pinada do Dracula (`icones.base`, `m4thewz/dracula-icons@00a230a2`) traz os ícones de status que o `sistema.map` nomeia. O tarball não está no cache desta máquina.

## Causa
- `scripts/icones_sistema.sh`, `scripts/icones_bandeja.sh`, `scripts/icones_tray_steam.sh` e `scripts/icones_tray_zapzap.sh` têm o acervo de status como constante do motor, e não como dado do pack.
- Essa é a mesma armadilha que a P96 curou para os tipos de arquivo (`icones.mimetypes`).

## Cura na origem
1. `packs/meowsystem/pack.json` ganha `icones.sistema: {desenhos, mapa}` e `icones.bandeja: {mapa}`, apontando para o que já está lá. O `scripts/pack.py` aprende os campos (lista de conhecidos e validação).
2. Os quatro scripts leem o acervo e o mapa do pack no ar pelo `pack.py campo`.
   - Pack sem os campos: o passo pula e tira o que ele mesmo escreveu antes, pelo manifesto. A camada-base do pack aparece.
3. O Dracula fica conforme a resposta da pergunta 2 do relatório:
   - sem herança, se a base tem os ícones de status;
   - `icones.sistema.herda: "meowsystem"`, pintado com a paleta dele como os tipos de arquivo, se não tem.
4. Tirar `origens.cursores.tema` do `packs/dracula/pack.json` e da lista de campos do `scripts/pack.py`.

## Prova
- `tests/pack-dracula-completo.sh`, caso novo, com o HOME temporário, `PACK=dracula` e `meow doctor --conferir`:
  - nenhum arquivo em `~/.local/share/icons/MeowSystem-Icons/*/status/` tem o sha de um SVG de `packs/meowsystem/icones/sistema/`;
  - a segunda passada não escreve nada.
- O mesmo caso com `PACK=meowsystem`: a bandeja confere igual a hoje (`tests/todos.sh` verde).
- `tests/pack.sh`: um pack de terceiro sem `icones.bandeja` faz o `icones_bandeja.sh --conferir` sair `pulado`, e não ler `packs/meowsystem`.

## Arquivos
`scripts/icones_sistema.sh`, `scripts/icones_bandeja.sh`, `scripts/icones_tray_steam.sh`,
`scripts/icones_tray_zapzap.sh`, `scripts/pack.py`, `packs/meowsystem/pack.json`,
`packs/dracula/pack.json`, `tests/pack-dracula-completo.sh`, `tests/pack.sh`.

## Fora desta sprint
- O que já difere de propósito:
  - Dracula sem `vscode-icones` (`_nota_vscode_icones`);
  - Heroic com o tema embutido;
  - fontes herdadas;
  - papéis de parede locais contra baixados.
- O `_HEROIC_ORIGEM` fixo em `packs/meowsystem` (`scripts/temas-de-apps/heroic/manifesto.sh:5`), que só pesa num pack de terceiro: «Anotado para depois».

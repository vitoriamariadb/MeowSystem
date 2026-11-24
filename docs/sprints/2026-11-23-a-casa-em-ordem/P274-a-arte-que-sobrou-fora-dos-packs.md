# P274 — a arte que sobrou fora dos packs entra nos packs (23/11/2026)

## O que se mediu (catálogo de 23/11)
| onde | o que é | quem lê |
| --- | --- | --- |
| `assets/extensoes/icones/` (13 SVG) | ícone de cada applet na Central; 10 com `#cdd6f4` cravado | `app/servidor.py:2984,3215` |
| `assets/prompt/starship.toml` e `LEIAME.md` | prompt com a paleta `catppuccin_mocha`, 26 cores | `scripts/prompt.sh:9` |
| `assets/fontes/locais/LEIA-ME.txt` | a pasta onde quem usa solta fonte; o pack já tem `fontes/` | `scripts/instalar_fontes.sh:55` |
| `app/pagina/mesa.js:4` | oito desenhos de app embutidos no código | o painel |
| `docs/pack-minimo/` (10 arquivos) | pack de exemplo fora de `packs/` | `tests/fotos-do-pack.sh`, `tests/tres-pastas.sh` |

`tests/arvore.sh:120` procura o flavor no nome do arquivo e não olha o conteúdo: a cor cravada passou por ele.

Pedido de quem usa, 23/11: «Todos os icones, imagem de papel de parede e afins devem estar dentro de suas respectivas
pastas de packs. Não devem estar em nenhuma outra pasta seja assets src.»

## A causa
A fronteira foi escrita como «o motor, menos a arte de ícone» (`docs/PACKS.md:300`), e o que tinha cor mas não era
ícone de app ficou do lado do motor.

## A cura na origem
1. Os 13 ícones de applet vão para `packs/meowsystem/icones/sistema/`, sem cor cravada (`currentColor`), com o nome
   que o contrato `nomes-das-extensoes.tsv` já usa; o Dracula herda ou traz o dele. O painel os pede ao pack.
2. O prompt vira vaga do pack: campo no `pack.json` e leitor no `prompt.sh`, os dois juntos
   (`docs/PACKS.md:1868-1880`); o `starship.toml` com a paleta vai para `packs/meowsystem/`.
3. `fontes/locais/` vai para `packs/meowsystem/fontes/locais/`, com a linha do `.gitignore`.
4. O `mesa.js` lê os oito desenhos do pack no ar, pela rota que o painel já usa para logo e mascote.
5. `docs/pack-minimo/`: o teste monta o pack de exemplo sozinho e o `docs/PACKS.md` mostra a árvore em texto. Se
   quem usa preferir o exemplo como pack de verdade, ele vai para `packs/`.
6. `tests/arvore.sh` passa a reprovar cor (hex e nome de paleta) em qualquer arquivo fora de `packs/` que não seja do
   painel nem do README.

## Como se prova
- `tests/arvore.sh` vermelho antes (com os cinco itens da tabela) e verde depois.
- No palco (`scripts/palco.sh`): a Central com os ícones de applet nos dois packs; o prompt nos dois packs.
- `./install.sh` em 1 passagem, e o doctor sem divergência nova.

## O `theme.js` do Spotify
`packs/meowsystem/temas-de-apps/spotify/catppuccin/theme.js` é código dentro de pack e roda no Spotify
(`spotify/manifesto.sh:580`, `inject_theme_js 1`). Sim de quem usa, 23/11/2026 (AskUserQuestion): «Exceção escrita».
- Linha nova em `docs/DECISOES.md`, no molde da decisão 9: só pack do repositório tem o `theme.js` injetado; pack
  importado nunca.
- Medir primeiro se o `spotify/manifesto.sh` já recusa o `theme.js` de pack importado; se não recusa, a recusa entra.
- `docs/PACKS.md:2103` passa a dizer a exceção.
- Prova: caso novo no `tests/pack-malicioso.sh` (pack importado com `theme.js` não o injeta) e a linha em
  `tests/decisoes.sh`.

## Feito (24/11/2026)
Bloco `arte-no-pack`, integrado em `803b9a49` (ponta do bloco `a710dccb`: 22 commits de quem implementou, 10 de quem
conferiu).
- Os 13 ícones de applet e os 8 desenhos da mesa moram em `packs/meowsystem/icones/sistema/`, sem cor cravada. O
  prompt é vaga do pack. `fontes/locais/` mora no pack-base, e a fonte que ficou na pasta de antes vai com `mv -n`.
  `docs/pack-minimo/` saiu; os testes montam o pack.
- `tests/arvore.sh` cobra a fronteira por uma lista de extensões de arte e três isenções nomeadas. Vermelho em
  `6b5286e1` (107 linhas de cor), verde na ponta.
- Decisão 67, com o sim de 23/11: executável e configuração que roda comando só vêm de pack do repositório. Vale
  para o `theme.js` e os `assets/` do Spotify, para o `starship.toml` e para os moldes de tema.
- A revisão de segurança e quem conferiu acharam nove furos da mesma família (o código passou a confiar no que um
  pack qualquer diz). Todos fechados, com caso em `tests/pack-malicioso.sh`, `tests/temas-de-apps.sh` ou
  `tests/pack-pessoal-tem-tema.sh`: o prompt com `[custom]`, o prompt herdado de pack de fora, a sombra do pack-base,
  os `assets/` do Spotify, a porta do Spotify pelo `id` escrito, o remover e o aplicar do Heroic, a captura
  `original` de pack de fora e o molde de pack de fora (só vale byte a byte igual ao do pack-base; sem equivalente no
  pack-base, não é lido).
- Cruzamento na integração: `cruzamento-arte.log`.
- Só o install de verdade prova: os comandos estão em `~/.cache/meow-leva/suite-2026-11-23/relato-conf-arte.md`,
  seção 8.
- Para a próxima leva: cor de tema cravada em código e os achados do `PARA-A-PROXIMA-LEVA.md`.

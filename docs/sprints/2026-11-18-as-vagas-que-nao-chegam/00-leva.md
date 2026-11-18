# Leva de 18/11/2026 — as vagas que não chegam à barra, e o que a leva de 17/11 deixou sem prova

Texto de quem usa, 18/11 (duas fotos da barra e da dock do nitro-5, no Dracula): «levanta as próximas sprints outros
problemas e bugs que não notamos. alguns ícones não mudaram. os 3 pcs estão conectados. Veja se as sprints vão
resolver o problema nos 3 pcs. os svgs de papel de parede são nossos ou foram baixados de algum lugar?»

## O que se mediu nos três PCs (coordenador, 18/11, só leitura)

| | nitro-5 | MeowSystem (desktop) | Meow-portatil |
| --- | --- | --- | --- |
| checkout | `9ed03775` (master) | `c374a050` (falta 1 commit de docs) | `23e2a859`, de 16/11: sem a leva de 17/11 |
| pack no ar | `dracula` | `meu-tema` (pessoal, herda `meowsystem`) | `meu-meow-portatil` (pessoal, herda `meowsystem`) |
| `*-symbolic.svg` no `MeowSystem-Icons` | 346 | **0** | **0** |
| linha `sistema` do doctor | confere | «o pack no ar não declara icones.sistema — nada a aplicar» | a mesma |
| sessão | de 18/11 10:23, já com a leva | de 16/11 14:22, anterior à leva | de 18/11 14:19, com o checkout antigo |
| bateria | sim | não | sim |

Os três têm os mesmos applets na barra e na dock: `NowPlaying`, `Performance`, `AjustesRapidos`, `Soneca`, `Leitura`,
`Eyedropper`, `Clipboard`, `Bandeja` e o `CosmicAppletPower` de fábrica.

## Por que cada ícone da foto não mudou (nitro-5, Dracula)

| ícone da foto | applet | o que ele pede | por que não é a arte do pack | sprint |
| --- | --- | --- | --- | --- |
| velocímetro | Performance | SVG embutido no binário (`include_bytes!`) | nunca passa pelo tema de ícones | P243 |
| sino | Ajustes rápidos | `notification-symbolic` | o pack só liga o desenho a `cosmic-applet-notification-symbolic` | P242 |
| corrente | Ajustes rápidos | `network-wired-symbolic` | mudou: é a corrente aprovada no P232 | — |
| bateria 100% | Ajustes rápidos | `battery-full-charged-symbolic` (nome do UPower) | a ampulheta só está em `cosmic-applet-battery-level-*` | P242 |
| conta-gotas | Eyedropper | `color-select-symbolic` | fora dos dois contratos de nomes | P242 |
| prancheta | Clipboard | `io.github.meowsystem.Clipboard-symbolic`, do `hicolor` | é o desenho do applet, não do pack | P243 |
| três pontos | Bandeja | `view-more-horizontal-symbolic` | está no pack: o desenho do Dracula é o glifo do dracula-icons | P243 (arte) |
| desligar | CosmicAppletPower | `system-shutdown-symbolic` | está no pack: o desenho do Dracula é o glifo do dracula-icons | P243 (arte) |

## As sprints

| bloco | tarefas | o que toca | agentes |
| --- | --- | --- | --- |
| A vagas | P241, P242, P246 | `scripts/pack.py`, `scripts/icones_sistema.sh`, `assets/contratos/nomes-das-extensoes.tsv`, os `sistema.map` dos dois packs, o criador no `app/servidor.py` | implementa → confere e corrige |
| B applets e arte | P243, P247 | os repositórios dos applets (pinos em `assets/extensoes/`), `packs/*/icones/sistema/`, quadro de arte para aprovar | implementa → confere e corrige |
| C CI | P244 | `tests/`, `.github/workflows/testes.yml`, o que a `bloco/ci2` já traz | implementa → confere e corrige |
| D doctor e documentos | P245, P248, P249 | `bin/meow`, `scripts/logo.sh`, `scripts/janelas.sh`, `README`, `app/LEIA-ME.md`, `docs/ESTADO-FINAL.md`, `assets/contratos/vizinhos.tsv` | implementa → confere e corrige |

A e B não rodam juntos: os dois mexem no `nomes-das-extensoes.tsv` e nos `sistema.map`. A com C, ou A com D, têm
arquivos disjuntos.

## Isso resolve nos três PCs?

| sprint | nitro-5 | desktop | portátil |
| --- | --- | --- | --- |
| P241 (pack pessoal sem ícone de sistema) | não precisa | resolve, **se** vier o sim | resolve, **se** vier o sim |
| P242 (nomes que os applets pedem) | resolve | só depois do P241 | só depois do P241 |
| P243 (arte dos applets como vaga do pack) | resolve | só depois do P241 | só depois do P241 |
| bateria (parte do P242) | resolve | não tem bateria | resolve, depois do P241 |

Sem o P241, nenhuma sprint de ícone muda a barra dos dois PCs da Vitória: lá o tema instalado não recebe nenhum
desenho de sistema, nem os botões da janela da decisão 59.

## Os papéis de parede em SVG: de quem são

- **12 SVG em `packs/*/wallpapers/pares/`** (seis cenas, dia e noite): nossos, desenhados no P234 em 17/11/2026,
  GPL-3.0-or-later, sem bitmap embutido e sem metadado de editor.
- **13 SVG do Dracula** (`catedral/`, `cemiterio/`, `noite/`, `ornamento/`): nossos também. Vêm do
  `tulip-orchid-wallpapers` do coautor (commit `98770f8a`), desenho em código, MIT, `Copyright (c) 2026 Andre Farias`
  no `wallpapers/LICENSE`. Cada um tem linha e sha256 no `PROCEDENCIA.md`.
- **Baixadas são só as fotos do MeowSystem**: as 9 linhas do `packs/meowsystem/wallpapers/FONTES.tsv` (wallhaven e
  outros), que não entram no git; o repositório guarda só a URL.

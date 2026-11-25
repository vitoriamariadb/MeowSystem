# P295: a revisão da dock no contrato

## O que se mediu (25/11, nos três PCs)
`meow cosmic prever` dizia, em amarelo: «cosmic-applets instalado é o cb3ea91; scripts/appid_dock.sh foi medido no
40248fb (freedesktop-desktop-entry 0.8.1) — meça de novo». A linha `revisao` do `dados/contratos/cosmic.tsv` parou no
`40248fb`.

| revisão do cosmic-applets | `freedesktop-desktop-entry` no `Cargo.lock` |
|---|---|
| `40248fb` (a do contrato) | 0.8.1 |
| `779f920` (notebooks, antes do apt de hoje) | 0.8.4 |
| `cb3ea91` (os três PCs, hoje) | 0.8.4 |

## A causa
A biblioteca subiu três versões e ninguém refez a medida; o `tests/dock-fonte-real.sh` já conferia a 0.8.4, só a linha
do contrato ficou.

## A remedida
As duas versões baixadas do `static.crates.io` e comparadas arquivo a arquivo. O que mudou: a quebra do `Exec` com
aspas (`exec.rs`), dois caminhos do Nix e o locale sem a codificação (`lib.rs`). A função que casa a janela com o
`.desktop`, `find_app_by_id`, tem o mesmo sha256 nas duas
(`fd39cf7d87d17b7845782cd3565974831daac00b1d27bb6eda65110c7c619821`). O `scripts/appid_dock.sh` segue valendo.

## A cura
A linha `revisao` passa a `cb3ea91` e `freedesktop-desktop-entry 0.8.4`.

## Como se prova
- `meow cosmic prever`: «cosmic-applets instalado é o cb3ea91, o mesmo que scripts/appid_dock.sh mediu».
- `./tests/todos.sh --so=contrato-cosmic.sh,cosmic-prever.sh,sentinela.sh`.

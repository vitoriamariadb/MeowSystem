# P182 — a suíte portátil verde no GitHub (07/11/2026)

O job `testes` nunca tinha terminado: era cancelado aos 15 minutos. Com 45 minutos, ele termina e fica vermelho, nos mesmos 12 testes em f59d3c14 e em d4538c91, enquanto a suíte local dá 146 de 146.

## O que se mediu

`git-limpo`, `convergencia` (sem `convert`), `chaves-aposentadas`, `doctor-veredito`, `gerador-dracula` (`converter_icone.py` falha; `KeyError: 'svg'`), `trava-herdada`, `garantir-builds`, `contrato-cosmic` (`CosmicComp/v2/pinned_workspaces` não existe), `achados-tecnicos`, `tres-pastas`, `maquina-nova`, `deb`. Log com `gh run view <id> --log-failed`, último run do workflow `testes`.

## A causa

A medir, teste a teste. Separar: dependência que falta no runner, teste que depende desta máquina e deveria ser hermético, teste que só vale em máquina COSMIC e está na lista errada, e defeito real de portabilidade. O runner tem `sudo` sem senha de verdade: o falso precisa valer ali.

## A cura

Dependências em `.github/workflows/testes.yml`; teste hermético; lista portátil de `tests/todos.sh` com o que cabe nela. Sem afrouxar asserção e sem pular para ficar verde.

## Como se prova

Run do workflow `testes` verde no `master`.

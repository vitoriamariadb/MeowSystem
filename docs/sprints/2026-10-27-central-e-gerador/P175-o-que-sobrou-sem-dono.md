# P175 — o que sobrou sem dono (06/11/2026)

Achados da P161, da P164 e da P165.

## O que se mediu

- `/api/precisa-de-gente` não tem leitor em `app/pagina`; a sentinela segue escrevendo em `precisa-de-gente.tsv`, e as linhas antigas `compositor-caiu` e `patch-obrigatorio` ficam nele sem efeito (decisão 55).
- `NA_MAQUINA`, em `app/servidor.py`, crava `v1` no caminho do `CosmicComp`; `scripts/areas.sh` resolve a versão por `meow_cosmic_v`. Se o esquema subir, o painel lê a pasta velha.
- O doctor no modo só leitura chama `sudo -n -l` e `ponte_root.sh estado` (`bin/meow`). Os falsos recusam na suíte, mas a chamada existe.

## A cura

- Sem leitor, a rota e o arquivo saem, ou a tela volta a mostrá-los: vale o que a decisão 55 pede, e a rota morta sai. As linhas antigas somem do arquivo na próxima passada do doctor.
- `NA_MAQUINA` resolve a versão como o `areas.sh`.
- No modo só leitura, o doctor não chama `sudo`.

## Como se prova

`tests/doctor-so-le.sh` sem nenhuma chamada a `sudo` registrada; teste com esquema `v2` no HOME temporário; `tests/precisa-de-gente.sh` ajustado.

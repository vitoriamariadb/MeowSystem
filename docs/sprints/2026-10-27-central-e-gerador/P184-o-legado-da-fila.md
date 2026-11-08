# P184 — o legado da fila (07/11/2026)

Pedido de quem usa, depois da P183: «Corrige isso e qualquer outro problema legado e pusha». O levantamento, o doctor e o CI deram a lista.

## O que se mediu

1. **A margem 20 que nunca converge.** O `meow.conf` pede `FORMA_MARGEM_PAINEL="20"` e `FORMA_MARGEM_DOCK="20"`, da época em que a faixa ia até 24. Desde 04/11 (`318efaf6`) o `forma.sh` corta em 8, o teto em que o `cosmic-panel` 1.11 não cai. A tela fica em 8, a conf segue em 20, e o doctor acusa em toda passada, dizendo ainda «forma já conforme… margem 20» com 8 na tela.
2. **A fila do apt.** 25 pacotes fora do COSMIC esperavam (kernel, `apt`, `code`, `sqlite3`, `system76-scheduler`…).
3. **O CI nunca verde.** O job `testes` (`./tests/todos.sh --portatil` num Ubuntu 24.04 limpo) sai vermelho em todo push: 12 testes marcados como portáteis dependem de algo que só a máquina dela tem. `git-limpo`, `convergencia` (sem `convert`), `chaves-aposentadas`, `doctor-veredito`, `gerador-dracula`, `trava-herdada`, `garantir-builds`, `contrato-cosmic`, `achados-tecnicos`, `tres-pastas`, `maquina-nova`, `deb`.

## A cura na origem

- 1: quando a margem cortada veio da própria conf, o `forma.sh` grava o teto nela (pelo `meow_conf_definir`, que o conferir do doctor só anuncia) e diz a margem que ficou na tela.
- 2: `apt full-upgrade`. O kernel novo vale no próximo boot.
- 3: cada teste vermelho no Ubuntu limpo ganha a causa dele, medida num contêiner que imita o runner. O que é dependência do runner entra no workflow; o que é teste preso à máquina vira falso ou passa para MAQUINA, com o porquê.

## Como se prova

- `tests/margem-no-teto.sh`: a conf com 20 passa a dizer 8, o conferir não a toca, e a passada seguinte sai 0 sem aviso.
- `apt list --upgradable` vazio.
- A suíte portátil verde no contêiner e no CI do GitHub depois do push.

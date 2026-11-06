# P171 — a lista das áreas fica no monitor interno (06/11/2026)

Achado da conferência da P161. Produto: vale para todo notebook com monitor externo em `AREAS_MODO="juntas"`.

## O que se mediu

- Em Juntas a lista fica presa ao monitor da primeira entrada do `pinned_workspaces`, hoje o `HDMI-A-1`.
- Religar o HDMI leva as áreas fixadas para ele (`prefers_output`) e deixa a tela do note com números.

## A causa

`_areas_motor` escolhe a saída pela ordem do arquivo; nada diz qual saída é a de casa.

## A cura

Em Juntas, a lista grava o monitor interno (`eDP-*`, `LVDS-*`, `DSI-*`) quando ele existe; sem monitor interno, segue a ordem do arquivo, como no desktop. Idempotente, sem mexer em área que quem usa marcou à mão na outra tela.

## Como se prova

`tests/areas-em-cada-tela.sh` com cópia do arquivo real: HDMI na primeira entrada e `eDP-1` ligado, a lista passa ao `eDP-1`; a segunda passada não escreve; desktop sem saída interna não muda.

## Execução

Feito em `scripts/areas.sh` (motor) e `tests/areas-em-cada-tela.sh`.

- Em Juntas, `tela_de_casa` acha a primeira saída ligada `eDP-*`, `LVDS-*` ou `DSI-*` (a lista do cosmic-randr que `_areas_ler` já exporta). Sem saída interna, nada muda: segue a ordem do arquivo.
- `tela_da_lista` escolhe essa tela para a lista, desde que ela não tenha área com nome fora da lista: área marcada à mão fica onde está e o doctor não cobra o que não consegue consertar.
- `rehomar` reescreve só o bloco `output:` das entradas da lista quando a tela de casa não tem entrada nenhuma; ids, nomes e encaixe seguem. Com cópias já na tela de casa (vindas de Independentes), as repetidas do monitor de fora saem pelo caminho antigo.
- O doctor ganhou o verbo `lista-fora-de-casa`: `alfinetes`, `conferir` e `refazer-alfinetes` acusam e consertam («lista das áreas fora da tela de casa: HDMI-A-1»). `aplicar` conserta sozinho. Independentes não muda.
- As asserções de Juntas que esperavam a lista no HDMI passam a esperar o `eDP-1`, que é a cura pedida.

Provas literais:

- `bash tests/areas-em-cada-tela.sh` com o `areas.sh` novo: `areas-em-cada-tela: tudo verde`.
- Mesmo teste com o `areas.sh` de antes (HEAD~1): 11 `FALHA`.
- Novas asserções: doctor acusa a lista presa ao HDMI; o ensaio não grava; a lista passa ao `eDP-1` com os mesmos ids; `alfinetes` e `conferir` ficam verdes; a segunda passada não troca nem o inode; sem saída interna `aplicar` e `refazer` não mudam um byte; `LVDS-1` e `DSI-1` recebem a lista.
- Vizinhos verdes: `doctor-so-le`, `nada-manda-digitar`, `sem-receita-no-log`, `estilo`, `seco`, `notas-de-funcao`, `orfaos`, `achados-tecnicos`, `cosmic-prever`.
- `tests/decisoes.sh`: 1 falha, `o registro pulou ou repetiu número`. Já vermelha antes desta mudança (`git stash` confirmou): `docs/DECISOES.md` vai de 53 a 55 sem o 54.

Falta da mão de quem usa (sessão real, depois do install e do reboot):

- Com o HDMI ligado e o `pinned_workspaces` real com o `HDMI-A-1` na primeira entrada: `meow doctor` acusa a lista fora da tela de casa, o conserto passa a lista ao `eDP-1`, e no login seguinte a tela do note mostra as áreas com nome em vez de números, mesmo depois de religar o HDMI.
- O compositor só lê o arquivo no próximo início de sessão; não foi testado com o `cosmic-comp` de verdade.

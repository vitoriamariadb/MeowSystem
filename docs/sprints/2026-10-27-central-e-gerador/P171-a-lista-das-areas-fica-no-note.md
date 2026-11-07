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

- Em Juntas, `tela_de_casa` acha a saída ligada `eDP-*`, `LVDS-*` ou `DSI-*` (a lista do cosmic-randr que `_areas_ler` já exporta), e prefere o interno que já tem entrada no arquivo: com dois internos a lista não troca de um para o outro. Sem saída interna, nada muda: segue a ordem do arquivo.
- `tela_da_lista` escolhe a tela de casa quando os nomes dela cabem nos da primeira tela do arquivo, ou quando ela tem mais nomes do `AREAS_NOMES` que a primeira. Nos demais casos fica a primeira: área marcada à mão no monitor interno fica onde está e o doctor não cobra o que não consegue consertar.
- `rehomar` reescreve o bloco `output:` das entradas da primeira tela e tira as cópias da tela de casa: a lista muda de tela inteira, com ids, nomes, ordem e encaixe. Área marcada à mão em outra tela não entra.
- O doctor ganhou o verbo `lista-fora-de-casa`: `alfinetes`, `conferir` e `refazer-alfinetes` acusam e consertam («lista das áreas fora da tela de casa: HDMI-A-1»). `aplicar` conserta sozinho. Independentes não muda.
- As asserções de Juntas que esperavam a lista no HDMI passam a esperar o `eDP-1`, que é a cura pedida.

Provas literais:

- `bash tests/areas-em-cada-tela.sh` com o `areas.sh` novo: `areas-em-cada-tela: tudo verde`.
- Mesmo teste com o `areas.sh` anterior à P171: 11 `FALHA` na primeira rodada da implementação.
- Novas asserções: doctor acusa a lista presa ao HDMI; o ensaio não grava; a lista passa ao `eDP-1` com os mesmos ids; `alfinetes` e `conferir` ficam verdes; a segunda passada não troca nem o inode; sem saída interna `aplicar` e `refazer` não mudam um byte; `LVDS-1` e `DSI-1` recebem a lista.
- Vizinhos verdes: `doctor-so-le`, `nada-manda-digitar`, `sem-receita-no-log`, `estilo`, `seco`, `notas-de-funcao`, `orfaos`, `achados-tecnicos`, `cosmic-prever`, `contrato-cosmic`.
- `tests/decisoes.sh`: 1 falha, `o registro pulou ou repetiu número`. Já vermelha antes desta mudança (`git stash` confirmou): `docs/DECISOES.md` vai de 53 a 55 sem o 54.

Conferência, o que quebrava e foi corrigido:

- Área marcada à mão no monitor de fora com o arquivo começando por ela (`HDMI-A-1: Estudo`, `eDP-1: Pop, OS`). O `persist` do compositor grava por `sets`, então a ordem é a da criação das saídas, e esse arquivo nasce de um alfinete feito no HDMI depois da cura. Antes: `aplicar` renomeava `Estudo` para `Pop` e a apagava como repetida; `alfinetes` dizia «caiu» para sempre. Agora o doctor fica quieto, nenhuma passada muda um byte e renomear vale na lista de casa.
- Cópia menor em casa (`HDMI-A-1: Pop, OS, Som`, `eDP-1: Pop, OS`). Antes a lista partia: `Som` ficava no HDMI com id novo e sem encaixe, e o doctor seguia vermelho. Agora uma passada leva a lista inteira, com id e encaixe.
- Dois internos (`eDP-1` antes de `eDP-2` no cosmic-randr, lista no `eDP-2`). Antes o doctor acusava e a lista trocava de interno. Agora fica.
- Cópia do `pinned_workspaces` real, em HOME temporário: quatro entradas, duas por tela; a primeira passada deixa `eDP-1: Pop, OS` com os ids `0bccce` e `f7b12d`, o doctor fica verde e a passada seguinte não muda um byte.
- O EDID que `bloco_da_saida` lê de `/sys` para o `eDP-1` é igual ao que o compositor gravou (`BOE 2818`, série `None`, semana 1, 2022). O `output_matches` compara o EDID inteiro, então essa igualdade é a condição para o `prefers_output` acertar.
- `tests/areas-em-cada-tela.sh`, com o teste novo e o motor anterior à conferência: 9 `FALHA`. Com o motor corrigido: `tudo verde`.

O que continua de fora:

- `AREAS_NOMES` vazio: a lista não muda de tela. O `meow.conf.exemplo` promete que sem nomes o arquivo não é tocado, e `tests/areas-em-cada-tela.sh` cobra isso.
- `HDMI-A-1: Pop, OS` com `eDP-1: Pop, OS, Estudo`: a lista fica no HDMI e sai a cópia do interno. Levar a lista ao interno daria três áreas para dois nomes, e isso o `montar` recusa.
- `alfinetar-primeira` grava na saída em uso. Num note com o HDMI como principal, a primeira área nasce nele e passa ao interno na escrita seguinte.

Falta da mão de quem usa (sessão real, depois do install e do reboot):

- Com o HDMI ligado e o `pinned_workspaces` real com o `HDMI-A-1` na primeira entrada: `meow doctor` acusa a lista fora da tela de casa, o conserto passa a lista ao `eDP-1`, e no login seguinte a tela do note mostra as áreas com nome em vez de números, mesmo depois de religar o HDMI.
- O compositor só lê o arquivo no próximo início de sessão; não foi testado com o `cosmic-comp` de verdade.

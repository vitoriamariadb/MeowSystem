# Os três PCs em dia (25/11/2026)

Pedido: auditar o projeto e corrigir, instalar nos três PCs, curar no nitro-5 a bateria que passa de 80% e levantar o
que falta de personalização nos packs `meowsystem` e `dracula`.

## Os três PCs

| PC | commit antes | apt do COSMIC | `./install.sh` |
|---|---|---|---|
| MeowSystem | `b808ee2` | fila vazia | em dia, levantamento sem achado |
| Meow-portatil | 5 atrás | 7 pacotes subidos | saída 0, 77 etapas, 2 passagens |
| nitro-5 | 2 atrás | 5 pacotes subidos | saída 0, 77 etapas, 2 passagens |

Os três ficaram com `cosmic-comp 0681eaf`, `cosmic-files 84a32e1` e `cosmic-applets cb3ea91`. Só os pacotes do
COSMIC subiram; o resto da fila do apt (44 no portátil, 30 no nitro-5: systemd, Chrome, sqlite) ficou para o gesto
de atualizar de cada dono. Nos notebooks o compositor e o menu do Arquivos recompilam em segundo plano e valem no
próximo login.

## O que a auditoria achou e curou

| tarefa | o defeito | commit |
|---|---|---|
| P295 | a linha `revisao` do contrato parada no cosmic-applets `40248fb` | `c3e5f57` |
| P296 | `meow apps` dizia Spotify «pendente» com a conferência em 0 (nos três PCs) | `81ddadd` |
| P297 | `meow cosmic icones` contava desenho de qualquer pack como do pack no ar | `4ebdbeb` |
| P298 | o menu do `meow` com a cor do Mocha cravada, também no Dracula | `2170b84` |

## A bateria do nitro-5
A carga para no ponto certo e a régua do medidor está errada: `health_mode=1`, medidor em 100% «Full», `charge_full`
2092 mAh de 3733, 16,48 V em repouso. O portátil tem o mesmo pack, sem limite, e cheio repousa em 17,09 V. O painel
deveria marcar 80% e marca 100%.

A cura escolhida por quem usa: a calibração da Acer, armada para 26/11 às 03:00 (`bateria-calibra.timer`, de sistema,
uma vez; roteiro em `~/.cache/meow-leva/bateria-calibrar.sh`, registro em `bateria-calibra.log`). Só começa na
tomada; saia como sair, desliga a calibração e religa o limite. Um reboot antes das 03:00 desarma. Segue o registro
de 72 h em `bateria-medida.csv`. Dois itens na fila da casa para o André (`5ea25d24`, `c94d45ec`).

A ler em 26/11: `charge_full` depois do ciclo e onde o painel para na recarga seguinte. Se voltar a 100%, o firmware
limita por tensão e a calibração não cura.

O portátil não tem limite de carga nenhum; a interface WMI `79772EC5` existe nele.

## Os dois packs
`O-QUE-FALTA-NOS-DOIS-PACKS.md`, nesta pasta.

## A prova (MeowSystem, 25/11)
| rodada | verdes | pulados | vermelhos |
|---|---|---|---|
| de base, antes das curas | 180 | 2 (`dock-fonte-real.sh`, `graficos-fonte-real.sh`) | `app-completo.py` |
| final, sobre as quatro curas | 181 | 0 | `app-navegador.py`, `app-completo.py` |
| os dois vermelhos, sozinhos | 2 | 0 | 0 |

Os dois testes de fonte real pulavam por falta dos clones em `~/.local/src`; os commits que eles pedem foram postos
lá (`cosmic-applets`, `xdg-desktop-portal-cosmic`, `cosmic-protocols`, 2 MB) e os dois passam.

Os vermelhos do painel são o teto de 240 s da gravação do tema: a máquina estava com carga 20 em 16 núcleos (outra
leva e um jogo). Sozinhos, com carga 12 a 16, passaram em 278 s e 1161 s. O teto continua justo demais para a
bancada em uso, como já dizia o `PARA-A-PROXIMA-LEVA.md` de 23/11.

## Próximo passo
1. Em 26/11: ler `~/.cache/meow-leva/bateria-calibra.log` no nitro-5.
2. Decisões de quem usa: o limite de carga no portátil; os desenhos da folha dos dois packs.
3. Próximo bloco, da lista de 23/11: as cores cravadas que sobraram (P298), o teto de 240 s do `app-completo.py` e os
   defeitos medidos do `2026-11-23-a-casa-em-ordem/PARA-A-PROXIMA-LEVA.md`.

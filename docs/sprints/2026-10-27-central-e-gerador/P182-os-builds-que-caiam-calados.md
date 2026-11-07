# P182 — os builds que caíam calados (07/11/2026)

Achados ao rodar o install com o HOME real e todos os builds, depois do pull de 07/11. O install saía 2: `extensoes` falhava e `graficos` escrevia em toda passagem.

## O que se mediu

1. **O portal de rebuild local.** O portal instalado é `1.11.0~1792525517~24.04~f448ddf+0~hefesto1`, o rebuild do Hefesto. O `graficos.sh` pedia ao `apt-get source` essa versão, que repositório nenhum serve. O `meow-builds-login.service` saía 2 em todo login, e o install via o `graficos` mudar em todas as passagens. Curado em `d2e876f6`: o fonte vem da versão sem o sufixo `+N~nomeN`, e o build fica na casa da versão instalada.
2. **O menu do Arquivos no `/tmp`.** O `/tmp` desta máquina é tmpfs de 4 GB. O `files_menu.sh` compilava em `${TMPDIR:-/tmp}`, o único dos builds fora do `~/.cache`, e mandava a saída do cargo para `/dev/null`: o cargo caía sem espaço, e a mensagem era só «o cargo falhou». Curado em `c89db034`: a árvore mora em `$MEOW_CACHE/cosmic-files`, com o `compilar-<versão>.log` ao lado e dono no `espaco.tsv`. Varredura dos outros `mktemp -d`: nenhum outro compila no `/tmp`.
3. **Os applets presos sem rede.** Em 04/11, às 5h, sem DNS (`Could not resolve host: static.crates.io`), o cargo do Modo performance e da Soneca caiu. O `extensoes_build.sh` gravou `falhou` com o mesmo pino, e toda passada do install e do doctor recusou tentar de novo até o pino mudar: três dias sem os dois applets. O clone já trata a falta de rede como passageira; o download das crates não.
4. **«sem rede?» quando a versão saiu do repositório.** O `cosmic-files` instalado (`3cc4b80`) já não estava no repositório do Pop, que só servia a `e03001c`. O `apt-get source` respondia «Não é possível encontrar a versão», e o `files_menu.sh` e o `graficos.sh` diziam «sem rede?».
5. **O teste do compositor depende do disco da máquina.** `tests/espaco.sh` 7b2 roda o `compositor_patches.sh compilar` de verdade, que mede o espaço livre antes de compilar (~3,4 GB). O teste mora no `/tmp`; com 3,0 GB livres, o build se recusa, e três conferências caem. O teste do portal já passa `GR_ESPACO_KB=1`.

## A cura na origem

- 3: o cargo que cai por rede não grava `falhou`. O `meow_motivo_do_cargo` reconhece a rede, e o applet diz que tenta de novo na próxima passada.
- 4: o `apt-get source` que não acha a versão diz que o repositório já não a serve e que o próximo apt traz a nova, nos dois scripts.
- 5: o 7b2 passa `CP_ESPACO_KB=1`, como o teste do portal.

## Como se prova

- `tests/extensoes-*.sh`: cargo falso que imprime o erro de DNS e sai 101 não deixa `falhou`; a passada seguinte compila.
- `tests/graficos.sh` e o teste do menu: o `apt-get` falso que responde «Unable to find a source package» e «Não é possível encontrar a versão» produz a mensagem nova, sem «sem rede».
- `tests/espaco.sh` sem nenhuma FALHA, com o `/tmp` da máquina como estiver.
- Install com o HOME real: `rc=0`, e a segunda passagem não escreve nada.

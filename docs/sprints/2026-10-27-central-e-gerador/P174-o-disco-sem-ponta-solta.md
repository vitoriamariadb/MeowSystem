# P174 — o disco sem ponta solta (06/11/2026)

Achados da P165.

## O que se mediu

- O fim do build do compositor e do menu do Arquivos não chama a limpeza; só o doctor e o fim de build de applet.
- O Liberar confere a trava e depois apaga, sem segurar `builds.lock`: um build que comece nesse intervalo cai.
- `oraculo-builds` cresce um binário por revisão do libcosmic, sem teto.
- `~/.cache/meowsystem/cosmic-prever` guarda debs e fontes sem poda própria; só o corte de 7 dias parado o alcança.
- `scripts/temas-de-apps/spotify/RECUPERACAO.md` cita `backups/spotify-xpui-fabrica`, que nenhum script escreve.

## A cura

O fim de cada build chama a limpeza; o Liberar segura a trava do início ao fim; `oraculo-builds` guarda o em uso e um anterior; `cosmic-prever` entra no inventário com teto; o documento do Spotify diz o que existe de verdade.

## Como se prova

`tests/espaco.sh` com os casos novos, a trava provada com um build falso em andamento, e a segunda passada sem escrever nada.

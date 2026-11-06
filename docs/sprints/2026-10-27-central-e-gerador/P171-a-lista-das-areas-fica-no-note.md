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

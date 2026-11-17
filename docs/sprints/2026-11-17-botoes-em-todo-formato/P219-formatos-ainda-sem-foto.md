# P219 — os formatos que ficaram sem foto na leva de 17/11 (17/11/2026)

## O que se mediu
- Spotify flatpak (CEF): com a cópia da config o cliente morre antes da janela (`ptrace: Operation not permitted`
  do crashpad e nada mais no log). Sem foto.
- OnlyOffice flatpak (Qt + CEF) e Clapper (GTK4 flatpak, saiu sem janela): sem foto.
- Snap: este PC não tem `snapd`. AppImage: nenhum em `~/Applications`, `/opt` ou nas pastas de dados.
- `partitionmanager` (Qt do sistema) não foi aberto: pede privilégio. Cai no mesmo caso do P215.

## A causa
Medição que não fechou, não defeito provado.

## A cura na origem
Medir cada um como o P213 e o P214 mandam (cópia da config numa pasta dentro de `~/.var/app/<app>/`, que o
sandbox enxerga) e, se a barra for genérica, curar no manifesto do app; snap e AppImage só quando houver um.

## Como se prova
Foto da barra de cada um; o que divergir vira tarefa própria.

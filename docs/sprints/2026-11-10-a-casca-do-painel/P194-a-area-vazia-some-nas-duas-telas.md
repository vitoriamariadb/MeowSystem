# P194 — a área vazia some nas duas telas (10/11/2026)

Foto 1, barra de cima: «Pop», «OS», «3». Texto: «os dois monitores tão mostrando o 3 ali em cima. Deveriam sair.»

## O que se mediu

1. `meow.conf`: `AREAS_NOMES="Pop, OS"`, `AREAS_MODO="juntas"`. A chave `workspaces` está em
   `workspace_mode: Global`.
2. O compositor no ar é o build da casa (`~/.local/libexec/meow/cosmic-comp/0.1~1793802426~24.04~ec674cd`), então o
   `cosmic-comp-sem-workspace-vazio.patch` deveria estar valendo, inclusive a linha do ramo Global (P161).
3. Mesmo assim aparece a terceira área, vazia, nas duas telas. Só a sessão real mede.

## A cura na origem

- Na sessão real, com os dois monitores: listar as áreas pelo protocolo (`cosmic-workspaces` ou o applet) e achar
  quem cria a terceira: o ramo Global ainda chama `add_empty_workspace` em algum caminho (troca de tela, religar),
  ou o build no ar não leva o hunk (conferir o marcador no binário).
- Cura no patch, com teste de compilação que prova o hunk aplicado.

## Como se prova

- Teste do compositor: o marcador do hunk presente no build.
- Sessão real: dois monitores, `Pop` e `OS`, nenhuma «3»; tirar e religar o monitor não traz a «3».

Tamanho: 2 a 4 h, só quem coordena, depois do install (sessão real).

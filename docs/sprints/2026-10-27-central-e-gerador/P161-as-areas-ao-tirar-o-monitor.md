# P161 — as áreas ao tirar o monitor (06/11/2026)

Relato de 06/11/2026: ao desconectar o segundo monitor, a barra da tela do note passou de 2 áreas para 5
(«Pop OS Pop OS 5»), e ninguém sabia o que era o «5».

## O que se mediu

- HDMI-A-1 desconectado; só o eDP-1 ativo.
- `pinned_workspaces` com 4 entradas, sem alteração desde 04/11 23:27: Pop e OS do HDMI-A-1, Pop e OS do eDP-1.
  Cópia em `~/.local/state/aurora/pinned_workspaces.2026-11-06`.
- `cosmic-comp` em execução: `/usr/bin/cosmic-comp (deleted)`, de fábrica, com 0 marcadores `AURORA-*`.

## As causas

**As duas áreas a mais são o comportamento do compositor, não falha do MeowSystem.** `remove_output`
(`src/shell/mod.rs:976`) empurra toda área fixada do monitor que saiu para o que ficou (`new_set.workspaces.push`).
O arquivo não é corrompido: `to_pinned` grava `explicit_output`, e `prefers_output` as devolve quando o HDMI volta.
Pela leitura do código, nada disso foi testado com o monitor reconectado.

**O «5» é a área vazia que o `ensure_last_empty` de fábrica cria atrás da última fixada.** O
`cosmic-comp-sem-workspace-vazio.patch` existe para tirá-la, mas esta sessão roda sem patch. O número é o índice dela.

## Previsão para o boot com o HDMI fora

Pela leitura de `add_output` (`mod.rs:934`): o primeiro monitor recebe todas as fixadas, então a barra deve mostrar
«Pop OS Pop OS», sem o «5». Religar o HDMI deve devolver as duas dele. Conferir de verdade.

## A cura a decidir

O «5» se resolve com o compositor patchado. A duplicação pede decisão de produto, porque as áreas do HDMI podem ter
janelas:

1. Patch em `remove_output`: juntar a área do monitor que saiu com a de mesmo nome no que ficou. Precisa devolver
   cada janela ao seu monitor quando ele voltar, e é a parte difícil.
2. Patch só de exibição: não listar a área vazia cujo monitor preferido está ausente. Mais simples, mas área com
   janela continua aparecendo.

Qualquer um entra em `patches/` como `req`, e esse binário também é a tela de login. Medir antes o que acontece com
janelas abertas no HDMI ao desconectar e ao reconectar.

## Como se prova

1. Sem HDMI, a barra mostra só Pop e OS.
2. Com janelas nas duas telas, desconectar e reconectar: nenhuma janela some, e cada uma volta ao seu monitor.
3. `pinned_workspaces` continua com as 4 entradas.

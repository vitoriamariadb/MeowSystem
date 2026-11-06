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

## A decisão

Decisão de 06/11/2026: «no meowsystem a ideia é termos duas áreas. mas a solução aplicada foi duplicar no outro
monitor também. só que duplicou lá porém o 5 não foi pinado pra evitar o bo dele aparecer. aí ou a solução é mesmas
duas áreas pros dois monitores ou manter agora mas impedir o 5 e que as duplicatas apareçam. isso vira correção e
chave de feature».

Vira correção e chave de feature. Os dois caminhos aceitos:

1. **As mesmas duas áreas nos dois monitores**: Pop e OS valem como um par só, em vez de 4 entradas por monitor.
2. **Manter as 4 entradas e impedir o «5» e as duplicatas**: nenhuma área vazia sobra, e as do monitor que saiu não
   aparecem como áreas a mais no que ficou.

A sprint começa escolhendo o caminho pelo que o compositor permite, e a chave do MeowSystem liga ou desliga o
resultado. O ponto a medir antes: o que acontece com as janelas abertas no HDMI ao desconectar e ao reconectar.
Qualquer patch entra em `patches/` como `req`, e esse binário também é a tela de login.

## Como se prova

1. Sem HDMI, a barra mostra só Pop e OS.
2. Com janelas nas duas telas, desconectar e reconectar: nenhuma janela some, e cada uma volta ao seu monitor.
3. `pinned_workspaces` continua com as 4 entradas.

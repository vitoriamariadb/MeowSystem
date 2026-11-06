# P161 — as áreas ao tirar o monitor (06/11/2026)

Relato de 06/11/2026: ao desconectar o segundo monitor, a barra da tela do note passou de 2 áreas para 5
(«Pop OS Pop OS 5»), e ninguém sabia o que era o «5».

## O que se mediu

- HDMI-A-1 desconectado; só o eDP-1 ativo.
- `pinned_workspaces` com 4 entradas, sem alteração desde 04/11 23:27: Pop e OS do HDMI-A-1, Pop e OS do eDP-1.
  Cópia em `~/.local/state/aurora/pinned_workspaces.2026-11-06`.
- `cosmic-comp` em execução: `/usr/bin/cosmic-comp (deleted)`, de fábrica, com 0 marcadores `AURORA-*`.

## Alcance

Produto, não máquina: vale para todo PC com dois monitores. Os nomes vêm de `AREAS_NOMES`, nada é fixo em «Pop» e «OS».

## As causas

**As duas áreas a mais nascem da decisão 53 somada ao compositor.** A decisão manda repor as mesmas áreas em cada tela
ligada, e o `scripts/areas.sh` grava 2 entradas por tela. Quando o HDMI sai, `remove_output`
(`src/shell/mod.rs:976`) empurra as áreas fixadas dele para a tela que ficou. O arquivo não é corrompido: `to_pinned`
grava `explicit_output`, e `prefers_output` as devolve quando o HDMI volta. Isso é leitura do código, sem teste com o
monitor reconectado.

**O «5» é a área vazia que o `ensure_last_empty` de fábrica cria atrás da última fixada.** O
`cosmic-comp-sem-workspace-vazio.patch` existe para tirá-la. O número é o índice dela.

**A sessão rodava sem patch porque o trilho do compositor falhou calado para quem usa.** O build 8cb1802 foi marcado `ruim`
em 05/11 depois de quedas por abort em `libgallium`, fora do código dos patches. O build ec674cd ficou `retido` em 06/11
no degrau 2, esperando o «Instalar» da página Extensões. Enquanto isso o login foi para a fábrica, sem o Modo de Leitura.

## Previsão para o boot com o HDMI fora

Pela leitura de `add_output` (`mod.rs:934`): o primeiro monitor recebe todas as fixadas, então a barra deve mostrar
«Pop OS Pop OS», sem o «5». Religar o HDMI deve devolver as duas dele. Conferir de verdade.

## A decisão

Decisão de 06/11/2026: «no meowsystem a ideia é termos duas áreas. mas a solução aplicada foi duplicar no outro
monitor também. só que duplicou lá porém o 5 não foi pinado pra evitar o bo dele aparecer. aí ou a solução é mesmas
duas áreas pros dois monitores ou manter agora mas impedir o 5 e que as duplicatas apareçam. isso vira correção e
chave de feature».

Vira correção e chave de feature. Decisão de 06/11/2026: **juntas por padrão**. Sim explícito para trocar o padrão da decisão
53, que precisa ser reescrita no mesmo commit do código.

- **Juntas:** `workspace_mode: Global` na chave `workspaces` do `CosmicComp`, nativo do COSMIC, sem patch. Trocar de área troca
  as duas telas juntas, e tirar o monitor não duplica nada.
- **Independentes:** continua disponível na chave, com o comportamento da decisão 53. Decisão de 06/11: sem patch; as áreas
  do monitor que saiu continuam vindo para a outra tela, e quem não quer isso usa Juntas.

Falta medir como `pinned_workspaces` se comporta em Global: `areas.sh` hoje grava uma lista por tela, e `AREAS_SAIDAS` só faz
sentido no modo independente. Medir também as janelas abertas no HDMI ao desconectar e ao reconectar.

## Como se prova

1. Em Juntas, com um ou dois monitores, a barra mostra só as áreas de `AREAS_NOMES`.
2. Com janelas nas duas telas, desconectar e reconectar: nenhuma janela some, e cada uma volta ao seu monitor.
3. Em Independentes, `pinned_workspaces` continua com as 4 entradas; em Juntas, com a quantidade medida para o Global, sem duplicata.
4. O commit do código reescreve a decisão 53 e registra a chave, citando o sim de 06/11.

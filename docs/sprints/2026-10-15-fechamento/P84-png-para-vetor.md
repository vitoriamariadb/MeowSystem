# P84 — Os PNG feitos à mão viram vetor (decisão 2 de 09/10)

**Branch:** `sprint/p84` · **Pasta:** `packs/dracula/icones/feitos-a-mao/` (39 arquivos; um deles,
`obsidian.png`, já é SVG com nome de PNG).

## Decisão 2
«Entram já como PNG (nada some), e cada um vira vetor num lote desenhado pelo agente e validado por
RMSE contra o PNG; o PNG sai só quando o vetor passa.» Base: «se precisarmos de SVGs novos, pedimos
pro agente criar e validamos».

## Tarefas
1. Para cada PNG: um SVG desenhado à mão (formas, não `<image>` embutido, não traçado automático
   cru), na paleta Dracula do `paleta.json`, viewBox 0 0 128 128, mesmo enquadramento.
2. Validação: renderizar o SVG (rsvg-convert) no tamanho do PNG e medir RMSE contra o PNG (régua do
   BRIEFING de ícones, `feedback-medir-antes-de-afirmar-qual-arte-e-a-boa`); folha de contato
   lado a lado em `.playwright-mcp/ux-p84/`.
3. Passou → SVG entra no lugar, PNG sai, linha no `PROCEDENCIA.md` (origem = o PNG, sha256);
   não passou → PNG fica, e o motivo vai para a tabela da spec.
4. O seletor (P73/P80) passa a oferecer os novos vetores sem a trava de raster.

## Prova
- tabela PNG × SVG × RMSE × veredito; `tests/acervo-da-ficha.sh` e `tests/pack.sh` verdes.

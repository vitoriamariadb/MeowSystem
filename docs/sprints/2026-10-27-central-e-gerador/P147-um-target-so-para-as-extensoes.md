# P147 — um `target/` só para as nove extensões

Anotada em 29/10 (o `ANDAMENTO.md` citava 15 GB). Medido em 29/10:
- `~/.local/state/meowsystem/extensoes/<id>/target`: nove pastas de 1,5 a 1,8 GB (14,6 GB). O
  `scripts/extensoes_build.sh` põe `ALVO="$ESTADO/target"` por extensão, e cada uma recompila a libcosmic inteira.
- Os clones de trabalho `~/Desenvolvimento/meowsystem-*/target` somam ~44 GB (cache de desenvolvimento, não do
  programa: fica com o coordenador, fora desta sprint).

## Cura na origem
- `extensoes_build.sh` compila as nove num `CARGO_TARGET_DIR` só (ex.: `$BASE/target`), com a trava que já serializa
  os builds; o binário de cada uma sai pelo nome dela (`P_BIN`), como hoje.
- A passada seguinte do doctor migra: apaga as `target/` velhas por extensão (cache, refaz-se sozinho), uma vez,
  e a segunda passada não escreve.
- O que o `meow` mostra de espaço (se mostra) passa a contar a pasta única.

## Prova
- Teste com `cargo` falso que registra o `CARGO_TARGET_DIR` recebido: as nove recebem o mesmo; as `target/`
  antigas saem na primeira passada; a segunda não escreve; um build que falha não apaga o binário que está no ar.
- `tests/extensoes.sh` verde.

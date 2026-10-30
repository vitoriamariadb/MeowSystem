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

## Execução
- `scripts/extensoes_build.sh`, commit `f699db54`: as nove extensões compilam num `CARGO_TARGET_DIR` só
  (`$BASE/.target`, que não colide com nenhuma extensão), sob a trava que já serializa os builds; o binário sai pelo
  nome de cada uma. A primeira passada (`--aplicar`) apaga a `target/` velha de cada extensão e devolve rc 1; o
  `--conferir` e o seco só avisam e divergem sem apagar; a segunda passada não escreve. O `--todas --reverter` leva a
  pasta única. Uma extensão já instalada também migra.
- Prova: `tests/extensoes.sh` verde, com `cargo` falso que registra o `CARGO_TARGET_DIR`: as nove recebem o mesmo, as
  `target/` antigas saem na primeira passada, a segunda passada deixa o HOME idêntico por sha256, e um build que
  falha (rc 2) não mexe no binário que está no ar. Uma asserção que lia `ls` da pasta de estado virou a conferência
  de que `.target/release` existe, porque media a coisa errada.
- Fora: os clones `meowsystem-*/target` (~44 GB) ficam com o coordenador; o que o `meow` mostra de espaço não
  foi alterado, porque não achei onde ele conta as `target/` por extensão.

### Conferência
- A serialização é a trava do cargo na pasta de build (o doctor ainda tem a `meow_travar`; o gesto do painel não
  tem trava própria, como antes da sprint). Os `BIN` dos pinos são todos diferentes, então o `release/` comum não
  mistura binários.
- Build que falha volta antes de `_instalar_binario`; a migração só apaga `extensoes/<id>/target` (o id passa por
  `^[a-z0-9][a-z0-9-]*$`, então `.target` não colide); `--todas --reverter` leva a pasta única; segunda passada
  idêntica por sha256.
- Corrigido: a `target/` velha que o `rm` não tira agora avisa e diverge, em vez de anunciar «saiu» a cada passada.
  O teste ganhou: o `src/` e o carimbo ficam nas nove, a migração sem poder compilar fecha na passada seguinte (rc 0,
  sem laço e sem build), e a `target/` presa avisa sem dizer que saiu. Commit `b37a1b67`.
- Suíte depois das correções: 119 de 120; o único vermelho é `readme.sh` (badge v2.2.0). `decisoes.sh`, `restaurar.sh`,
  `extensoes.sh`, `temas-de-apps.sh` e `compositor-shim.sh` verdes.

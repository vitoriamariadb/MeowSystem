# P83 — A documentação fecha o projeto

**Branch:** `sprint/p83` (depois de P81, P82 e P84 integradas) · **Pedido:** «atualiza a documentação
como um todo» (P71) e «SPRINTS.md como índice de P1 a P72» (P72), nunca feitos (S3 de
`2026-10-09-uso-real/01-regressoes.md`); «fecharmos o projeto em definitivo» (15/10).

## Tarefas
1. `docs/SPRINTS.md`: índice de P1 até a última sprint, uma linha cada (data, o quê, branch, merge).
2. `README.md` e `README.en.md`: o produto como está hoje (packs, seletor, doctor que conserta,
   COSMIC vivo, segurança de pack, interface), números conferidos pelo `tests/numeros.sh`.
3. `docs/PACKS.md`, `docs/FRONTEIRA.md`, `docs/COSMIC-THEMING.md` (§6 «nunca apt upgrade» reescrita:
   agora pode, com o pós-apt), `docs/MANUTENCAO.md` (da P81).
4. `docs/ESTADO-FINAL.md`: o que o projeto entrega, o que é decisão de quem usa e onde mora, o que
   ficou fora de propósito, e como manter (comandos que rodam sozinhos e quando).
5. Nada de «ela/dela» nem caminho de uma máquina só (`/mnt/Apate`, `/home/<conta>`).

## Prova
- `tests/numeros.sh`, `tests/portabilidade.sh`, `tests/frases-velhas.sh` verdes.

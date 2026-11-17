# Estado da leva de 16/11 (coordenador)

| tarefa | árvore / branch | situação |
| --- | --- | --- |
| P204 interface soberana | `.meow-wt-soberana` / `bloco/soberana` | conferido 17/11 03:04: 158/158 no branch (`99664169`…`2be1e0b3`) |
| P210 clique destrava | `.meow-wt-soberana` / `bloco/soberana` | pedido ao conferente A em 17/11; ainda sem arquivo nem linha de decisão |
| P205 áreas (patch meio aplicado) | `.meow-wt-areas` / `bloco/areas` | feito: `9f7afd39`, teste vermelho→verde |
| P206–P208 arte do Dracula | `.meow-wt-arte` / `bloco/arte-dracula` | integrado; PROCEDENCIA corrigido em `4cc91256` |
| P209 verde e queda | `.meow-wt-areas` / `bloco/areas` | patch `3e1314a1` (compõe na RTX), cargo check ok, testes verdes |

## Próximo passo
1. Quando o P210 voltar: merge de `bloco/soberana` em `integracao/2026-11-16` (áreas e arte já entraram).
2. Suíte inteira na integração; merge no `master`; push.
3. Coordenador: apagar a árvore em cache `~/.cache/meowsystem/cosmic-comp/cosmic-comp-0.1~1793802426~24.04~ec674cd`
   não é preciso (a P205 a reextrai sozinha); rodar `meow compositor` a partir do `master` integrado.
4. Quem usa: sair e entrar na sessão. Conferir: só Pop e OS na barra; `sudo -A journalctl -b -t cosmic-comp | grep -c
   "import for wrong devices"` = 0 depois de horas com as duas telas.

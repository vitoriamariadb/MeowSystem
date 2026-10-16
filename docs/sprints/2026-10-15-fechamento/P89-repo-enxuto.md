# P89 — O repositório enxuto, fácil de ler para pessoa e para IA, e um hook que o mantém assim

**Branch:** `sprint/p89` (a ÚLTIMA antes da integração final: toca o repositório inteiro) ·
**Pedido (15/10):** «deixar o repo com pouco consumo de tokens e IA-friendly, mesmo que tenhamos a regra
original de anti-evidência de IA; resumimos o agente e colocamos um hook pra automaticamente remover
qualquer meta comentário do repo, simplificação de falas na documentação e substituição de infos
erradas; mandamos a PR pro repo original da Vitória».

## Medido
- `app/pagina/app.js` ~10 mil linhas e `app/servidor.py` ~11,6 mil: boa parte é comentário narrativo
  (datas, «sprint P73», «a conferência de 09/10», «quem usa disse…», histórico do que foi tentado).
- `CLAUDE.md` da raiz (122 linhas, NÃO versionado) é a cópia do guia pessoal, não do projeto.
- Os ganchos do git são globais (`core.hooksPath=~/.config/git/hooks`: sanitizador anti-IA); um gancho
  do repositório só roda se a cadeia global o chamar.

## Tarefas
1. **Comentário vira porquê, curto**: em todo código (`bin/`, `lib/`, `scripts/`, `app/`, `tests/`,
   `src/`, `patches/` cabeçalhos), o comentário narrativo/meta (data, id de sprint, quem pediu, história,
   «medido em…», nome de sessão/ferramenta) vira no máximo o PORQUÊ técnico em uma a três linhas. A
   história mora no git e em `docs/sprints/`. Nenhuma mudança de comportamento: suíte inteira verde antes
   e depois, e diff sem linha de código não-comentário (prova por script que compara o código sem comentários).
2. **Documentação curta**: `README.md`, `README.en.md`, `docs/*.md` (não `docs/sprints/` nem
   `docs/pesquisas/`, que são registro) reescritos em frases curtas e diretas, sem «ela/dela», números
   conferidos pelo `tests/numeros.sh`.
3. **Guia de projeto para agentes, enxuto e versionado**: um `AGENTS.md` na raiz (≤ 80 linhas): o que é
   o projeto, mapa de pastas, como rodar a suíte com HOME temporário e falsos, as regras invioláveis
   (apontando para `GSD.md` da P86 e `docs/sprints/2026-10-09-uso-real/02-decisoes.md`), e onde NÃO ler
   por padrão (`docs/sprints/`, `docs/pesquisas/`, `.playwright-mcp/`). O `CLAUDE.md` local vira um
   ponteiro de uma linha para o `AGENTS.md` (continua fora do git).
4. **O gancho de higiene**: `scripts/higiene.sh` (versionado, determinístico, sem rede, sem IA):
   - no que está staged: acusa e remove comentário meta por padrão (id de sprint `P[0-9]+`, data
     `dd/mm/aaaa` em comentário, «conferência», «sessão», nomes de ferramenta de IA), deixando o porquê;
   - roda as checagens de informação errada que já existem (`tests/numeros.sh`, `tests/portabilidade.sh`,
     `tests/frases-velhas.sh`, `tests/acento.sh`) e CORRIGE o que for mecânico (número que o próprio
     teste sabe o certo), barrando o resto;
   - ligado à cadeia global: o `pre-commit` global já existente chama o gancho do repositório se houver
     (encadear sem quebrar o sanitizador anti-IA; o gancho global fica com backup datado).
   - Teste: commit com comentário «P99 — 15/10/2026: …» sai com o comentário reduzido; número errado
     no README é corrigido; frase velha é barrada.
5. **PR para o repositório original**: branch limpa a partir do dev final, empurrada para o fork
   `[REDACTED]/MeowSystem`, PR para `vitoriamariadb/MeowSystem` (base: a branch padrão de lá), título e
   corpo curtos em português, sem linha de atribuição. (Feito pelo coordenador depois da integração.)

## Prova
- `wc -l` e contagem de tokens aproximada (bytes/4) do repositório antes e depois, por pasta.
- código sem comentários idêntico antes e depois (script); `tests/todos.sh` verde 2x.

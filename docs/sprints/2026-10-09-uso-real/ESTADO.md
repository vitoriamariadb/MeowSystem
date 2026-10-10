# Estado do bloco «uso real» — 09/10/2026

Aguenta desligar o PC: o que está em voo e o próximo passo.

## Em voo (workflows de auditoria, só leitura)

| workflow | agentes | entrega |
|---|---|---|
| gpu-regressao-compositor  | 2 | `Migração-OS/levas/leva-08-gpu-regressao.md` + `Migração-OS/scripts/gpu-2026-10-09/` (scripts NÃO aplicados) |
| paridade-icones-e-exportacao | 4 | `docs/pesquisas/2026-10-09-paridade-de-icones.md` |
| caca-regressoes-pedidos  (214 pedidos, 37 fora, 4 regressões) | 6 | `docs/sprints/2026-10-09-uso-real/01-regressoes.md` (258 pedidos antigos conferidos) |
| cosmic-upgrade-resiliencia | 2 | `docs/pesquisas/2026-10-09-cosmic-vivo.md` |

Feito por mim, como usuário no navegador: `00-achados-como-usuario.md` (30 achados, prints em `.playwright-mcp/ux/`).

## Onda 1 de correção — EM VOO (workflow leva-g-onda-1, run wf_d130cb4a-0b9)

Todas as auditorias voltaram ( acima, e paridade/COSMIC vivo também).
Worktrees em `~/Desenvolvimento/.wt-meow/`: p73 (seletor e acervo), p74 (pack Dracula
completo), p75 (doctor corrige), p76 (COSMIC vivo), integracao (branch `integracao/leva-g`).
Por bloco: implementador → conferente que corrige → QA (P73 no navegador, P74 casa limpa).
Depois: merge p75, p74, p73, p76 na integração e suíte inteira. 13 agentes agente.

Se a sessão cair: `Workflow({scriptPath: ".../leva-g-onda-1-wf_d130cb4a-0b9.js", resumeFromRunId: "wf_d130cb4a-0b9"})`
reaproveita os agentes concluídos.

## Próximo passo

1. Ler `03-integracao-onda-1.md` na worktree de integração.
2. Varredura de segurança dedicada (pack como dado não confiável) sobre a integração: 4 alertas automáticos em P73/P74 (pack.py ×2, icones_apps_dracula.sh, som.sh, servidor.py servindo SVG) e um quinto em `bin/meow` (caminho de busca não confiável / execução de código; candidatos: P74 24e2b3b/71c95ea/c0b89b0, P75 0ea5fad/18c1d88/2733c4b, P76 — conferir todos os `source`, `python3` e `bash` sobre caminho de pack, cwd, PATH ou HOME). Pergunta de fundo: um pack importado pode trazer `manifesto.sh` executável? Se sim, importar pack = rodar código de terceiro; nada entra no dev antes.
3. Lançar a onda 2: P77 interface (hallmark + QA de uso real) a partir da integração.
4. Uso real final como usuário no navegador, sobre a integração; só então dev recebe tudo.
5. Pendentes de quem usa: senha em arquivo (decisão 5), aplicar a GPU (decisão 6), a frase cortada.

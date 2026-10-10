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

## Onda 1 — CONCLUÍDA e integrada (`integracao/leva-g`)

P73, P74, P75, P76 entraram; relatório `03-integracao-onda-1.md` (na integração). Suíte: 47 verdes,
2 pulados, 3 vermelhos (gate pela decisão 7, dois de ambiente). O dev foi limpo (ghostwriter foi
para `~/.config/meow/icones-escolhidos.map`, `apps.map` revertido, `.gitignore` em commit).

## Onda 2 — EM VOO (workflow leva-g-onda-2, run wf_e7977159-726)

P77 interface (hallmark → 4 grupos de páginas → conferente → QA de uso real) em `.wt-meow/p77`;
P78 segurança + gate (decisões 7 e 8) em `.wt-meow/p78`; depois integração. 10 agentes.
Retomar: `Workflow({scriptPath: ".../leva-g-onda-2-wf_e7977159-726.js", resumeFromRunId: "wf_e7977159-726"})`.

## Próximo passo

1. Ler `04-integracao-onda-2.md` na integração.
2. Uso real final como usuário, no navegador, sobre a integração (HOME temporário).
3. Merge da integração no dev; `./install.sh` uma vez (ponte nova da P75, `meow-pos-apt` da P76);
   `meow doctor` real.
4. Pendentes de quem usa: senha em arquivo (decisão 5), aplicar a GPU (decisão 6), ativar o shim do
   compositor (P76, exige login), a frase cortada de 09/10.

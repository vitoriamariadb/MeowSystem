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

## Onda 2 — CONCLUÍDA e integrada

P77 (interface sem texto: 33.383 → 8.928 caracteres visíveis, 0 comando cru), P78 (pack é dado,
nunca código; CSP; decisões 7 e 8) e P79 (casa real, decisões 9 a 11) entraram em
`integracao/leva-g`. Uso real final meu: `.playwright-mcp/ux-final/`.

## P80 — EM VOO (workflow leva-g-p80, run wf_582491cd-ad0)

Acabamento do meu uso real (nomes amigáveis na ficha, paleta só para traço, Dia e noite uniforme,
cabeçalho de página) + abertos da P79 (corrida do `vivo()`, reciclo triplo do painel — gatilho da
faixa verde —, nada manda digitar, falsos que recusam). Implementa → confere → QA → integra (suíte 2x).
Retomar: `Workflow({scriptPath: ".../leva-g-p80-wf_582491cd-ad0.js", resumeFromRunId: "wf_582491cd-ad0"})`.

## Próximo passo

1. Ler `05-integracao-p80.md` na integração.
2. Merge da integração no dev (as specs P73/P74 conflitam só em documento: ficam os dois lados).
3. `./install.sh` uma vez (ponte nova, `meow-pos-apt`); `meow doctor` real; conferir a tela.
4. Pendentes de quem usa: senha em arquivo (decisão 5), aplicar a GPU (decisão 6, reboot), ativar o
   shim do compositor (P76, exige login), a frase cortada de 09/10.

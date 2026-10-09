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

## Próximo passo

Quando as quatro auditorias voltarem: escrever um arquivo de tarefa por achado
(medido, causa, cura na origem, prova) e lançar o bloco de correção por área:

1. Ícones — seletor com a biblioteca inteira, em pastas por acervo; SVG que sumiram; pack Dracula completo; exportar tema completo
2. Doctor — corrige em vez de avisar; sem contradição; veredito honesto
3. Interface — sem texto, show don't tell (skill hallmark), consolidações por página
4. COSMIC vivo — sobreviver a atualização
5. GPU — só depois do aval de quem usa (scripts prontos, não aplicados)

## Pendente de quem usa

- A mensagem de 09/10 terminou em «Outra coisa que preciso é» — cortada.

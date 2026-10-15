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

## P80 — CONCLUÍDA; leva G inteira no dev (cd34d87) e instalada

Suíte 2x seguidas: 62 testes, 60 verdes, 2 pulados por ambiente, 0 vermelhos. `./install.sh` rodou
na máquina real em 10/10 (rc=0; o log em /tmp sumiu no reboot).

## 15/10 — o primeiro teste de verdade do «COSMIC vivo»

`apt full-upgrade` às 20:14 trouxe o COSMIC 1.10 (cosmic-comp 4d14528, cosmic-files 1.10.0). Às
20:15 o `meow-pos-apt.path` disparou sozinho o `cosmic_pos_apt.sh`, que recompila o menu do
cosmic-files e a série do compositor em escopo de usuário. Log: `~/.local/state/meowsystem/pos-apt.log`.

## Próximo passo

1. Ver o fim do pos-apt (o menu do cosmic-files 1.10 e a série do cosmic-comp 4d14528 aplicam?).
2. `meow doctor` real depois dele; o que sobrar, `meow doctor --consertar`.
3. Pendentes de quem usa: senha em arquivo (decisão 5), aplicar a GPU (decisão 6, reboot), ativar o
   shim do compositor (`meow compositor ativar`, vale no próximo login), a frase cortada de 09/10.

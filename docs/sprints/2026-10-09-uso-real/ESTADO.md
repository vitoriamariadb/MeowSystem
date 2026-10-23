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

## Leva H — CONCLUÍDA (integracao/leva-h, suíte 2x: 63 verdes, 1 pulado, 0 vermelhos)

P81 build sempre, P82 abertos (decisões 13–49), P83 documentação, P84 vetores, P85 série no 4d14528.

## Leva I — CONCLUÍDA (integracao/leva-h `ae2fc7c`, suíte 2x: 69 verdes, 1 pulado, 0 vermelhos)

P88 três pastas, P86 regra da vida (GSD.md, sentinela, tests/decisoes.sh), P87 tudo pro pack,
P89 repo enxuto + AGENTS.md + gancho. Dracula: apps/ 123, biblioteca/ 670.

## P90 — EM VOO (workflow p90-acoes-e-divisorias, run wf_7856b717-3cd)

Pedido de 16/10 pelos prints: só Executar/Restaurar, janela de resultado (OK/Guardar/Restaurar),
«Ver sem mudar», jogos refeitos, divisórias em todas as telas; mais as pendências da leva I (projetos
pessoais fora, porquê de volta, terminal sem «rode:», versão do folder-download guardada em
`~/.local/state/meowsystem/guardado-16-10/`). 2 Opus.

## 17/10 — levas G, H e I no dev (8d71a1d) e instaladas; P90 em voo

Quem usa (17/10): «integra e roda o install agora, com tudo antes da P90; depois rodamos o install com
ela de novo, integramos e pushamos pra dev». Sequência depois da P90:
1. merge da P90 (integracao/leva-h) no dev; `./install.sh`; `meow doctor --consertar`; `meow doctor`.
2. ANTES do push: reescrever a história local para tirar a senha do askpass do commit 63ed2ca
   (`git filter-repo --replace-text` com a senha -> ***, em todas as branches), conferir
   `git log --all -S<senha>` vazio, e só então `git push fork dev`.
3. PR para `vitoriamariadb/MeowSystem` a partir do dev reescrito.

## 23/10 — as sprints que faltavam: P92, P93, P94 e o fim de 17/10

Quem usa (23/10): «faz as sprints que estão faltando». Respostas dela/dele no mesmo dia:
- P93: os 11 apps que só o Dracula escondia ENTRAM no `LANCADOR_OCULTAR` (inclusive os dois pessoais).
- P94: tudo, inclusive o `install.sh --activate` do Dracula (commit só do bloco, sem tocar na frente de fontes).
- Fim: merge no dev, `./install.sh`, `meow doctor`, `git filter-repo` (senha → ***), `git log --all -S` vazio,
  `git push fork dev`, PR para vitoriamariadb/MeowSystem. NÃO desligar.

Sequência:
1. P90 e P91 integradas na `integracao/leva-h` (23/10; a spec da P90 é a de 50 linhas + o apêndice 8–12).
2. Bloco A (MeowSystem, worktree `.wt-meow/p92`, branch `sprint/p92`): P92 + P93 + o tipo `bloco` do
   `vizinhos.sh` para a P94 item 2. Workflow de 2 Opus (implementa; confere e corrige).
3. Integração, suíte, merge no dev (as mudanças soltas do dev de 18/10 e 21/10 — `scripts/painel.sh` e
   ícones de pasta — ficam guardadas em `.wt-meow/dev-solto-23-10.patch` e voltam soltas depois), install.
4. Bloco B (fora: Spellbook, Dracula_OS-Theme, NitroKit; desativações pós-install). Workflow de 2.
5. filter-repo, push, PR.
6. [P95](../2026-10-15-fechamento/P95-vizinhos-saem-da-casa.md) — corrigir os vizinhos que se metem e
   apagar localmente o Dracula_OS-Theme e o Migração-OS. REGISTRADA em 23/10; quem usa disse «aguarda»:
   não executar até a palavra dela/dele.

Em voo (23/10):
- bloco A (P92+P93), workflow `wf_efb436e1-89c`, worktree `.wt-meow/p92`, 2 Opus;
- P96 reorganização (`docs/sprints/2026-10-23-definitiva/`), worktree `.wt-meow/p96`: 2 Opus, fase 1 = perguntas
  para quem usa; fase 2 = o script, aplicado DEPOIS do bloco A entrar no dev;
- P97 interface, workflow `wf_17e7371f-4d3`, worktree `.wt-meow/p97`, 3 Opus: mockups em `docs/design/2026-10-23/`.

## Registrada para depois (NÃO executar sem quem usa mandar)

- P91 vizinhos e duplicatas — EXECUTADA em 17/10 na `sprint/p91`, espera o merge. Desativados nesta
  máquina: cinco scripts do `Dracula_OS-Theme` (commit `f41ee47a` lá). Depois do merge e do install:
  `scripts/vizinhos.sh --desativar caches-icones-casa` e um commit só disso no Spellbook. Para desfazer
  tudo: `scripts/vizinhos.sh --restaurar todos`. Relatório: `docs/pesquisas/2026-10-17-vizinhos.md`.
- P92 doutor do menu, P93 `ocultar` alcança tudo, P94 vizinhos de fora — registradas pela P91, NÃO
  executar sem quem usa mandar.

## Fim combinado com quem usa (15/10, antes de dormir)

1. merge da integracao/leva-h no dev; `./install.sh`; `meow compositor` (4d14528, com `just`);
   applet de leitura depois do compositor (decisão 20 da P82); `meow doctor`.
2. PR para `vitoriamariadb/MeowSystem` a partir de uma branch com HISTÓRICO NOVO (squash): o commit
   63ed2ca do dev local tem a senha do askpass num documento (já removida do tip; o fork não tem o dev).
3. `~/LEIA-AO-LIGAR.md`: o que foi feito, o que conferir, como voltar (shim e GPU).
4. NÃO desligar nem reiniciar (quem usa mudou em 16/10: «não desliga o PC ao final»). Se algo falhar, não faz merge do quebrado e escreve onde parou no LEIA-AO-LIGAR.

# Estado do bloco «uso real» — 09/10/2026

Aguenta desligar o PC: o que está em voo e o próximo passo.

## 25/10 — v2.0.0 e v2.1.0 PUBLICADAS (o mais novo)

- v2.1.0 = P100, P104, P105, P106, P107 e P108 sobre a v2.0.0. Público: `dev` e `master` do fork em `666c63a2`.
  Privado: `main` em `f9b4a848` (o `main` da v2.0.0 + merge da integração, sem force push; a árvore é igual à
  conferida), tag e release v2.1.0 em `AndreBFarias/MeowSystem-privado`.
- Provas: suíte 86/86 (0 pulados) na integração e no privado; conferente final APROVADO_COM_RESSALVAS (container
  virgem com systemd: 1 senha, 17 fotos sem rede, 44 fontes, doctor rc 0; ponte reposta sem senha, clone
  adulterado não chega a root, polkit só aceita o `start` do reparo).
- Máquina real (25/10): `./install.sh` rc 0 (2 passagens, 68 etapas); `meow doctor` rc 0; reserva, unidade do
  reparo e regra do polkit no disco. O compositor v2 vale no próximo login (o 1º refaz em segundo plano, ~5 min).

Próximo bloco (anotado, nada roda sem quem usa):
1. A foto levada pela P105 entra duas vezes na rotação (semear do `wallpaper.sh` confere conteúdo).
2. `perfis/andre/meow.conf` (só privado): coquinha com `PACK="dracula"`; `APPS_ATIVOS` sem kitty e gnome-terminal.
3. `scripts/ocultar_apps.sh:238` ainda diz «precisam de sudo» (mesma classe da P104 §6).
4. Ubuntu sem systemd/polkit: a etapa da ponte falha (no Pop!_OS não pega). «Mesmo horário» perde os minutos.
5. Escritório sem flatpak sempre em pendência de root, com a data regravada em toda passada.

## 24/10, noite — v2.0.0 e v2.1.0 em voo

Quem usa (24/10): roda tudo sem pedir nada a ela/ele (20% da cota semanal; ~2 milhões de tokens aprovados).
Nada aqui precisa de senha: sudo NOPASSWD, chave SSH e `gh` autenticados. A senha não vai para arquivo nenhum.

Integração: branch `integracao/v2`, worktree `.wt-meow/integracao-v2`. Cada bloco entra nela quando o conferente
volta. O `dev` só recebe no fim, de uma vez, com a suíte verde. Dois blocos ao mesmo tempo, no máximo.

| espaço | agora | depois | por último |
|---|---|---|---|
| A | P102 PC virgem (`.wt-meow/p102`) | P100 compositor | — |
| B | ~~P103~~ integrada (`f9a3dea0`, 77/77, 0 pulados) | P104 ponte sem senha (`.wt-meow/p104`, em voo) | P105 papéis/sons no pack, mockup |
| C (ordem de quem usa) | P106 tema CSS do ZapZap (`.wt-meow/p106`) | aplicar na máquina real e tirar print | — |
| D (ordem de quem usa) | P107 todo app em todo pack (`.wt-meow/p107`) | — | — |

- P101 instalada na máquina real em 24/10 (2 passagens, 68 etapas, `meow doctor` rc=0). O `meow-whatsapp` é
  idêntico ao `whatsapp-linux-app.svg` do pack, e a `dracula-copia-com.rtosta.zapzap` foi desativada (guardada
  em `~/.local/state/meowsystem/vizinhos/`). Suíte limpa (`.wt-meow/verif-dev`): 76 verdes, 1 pulado (`pack.sh`, P103 item 4).
- Quem usa (24/10): qBittorrent e OnlyOffice «deveria ser o nosso atual instalado». Troca feita com a
  resposta «Trocar» do painel (`MEOW_TEMA_DE_TERCEIRO=trocar meow apps aplicar <app>`). A segunda passada não
  mexe em nada e o doctor dá rc=0. Os temas antigos ficam guardados em `~/.local/state/meowsystem/backup-temas-terceiros-20261024/`.
- P101 está no dev (`3680c8f4`). A suíte no checkout principal deu 5 vermelhos por causa do
  `assets/icones/upstream/papirus-folders/` solto (um repositório aninhado que o copiador do teste não sabe
  copiar), não por código. A prova é a suíte limpa em `.wt-meow/verif-dev`.
- P102 tem dois branches: `sprint/p102` (público) e `sprint/p102-privado` (mais fotos, fontes e
  `perfis/andre/`). A falha de segurança do `fotos` declarado no pack é o item 6 da tarefa; confira antes do merge.
- **v2.0.0** (P101 a P103): conferente final Opus na `integracao/v2` (suíte 2x, container do repositório
  privado) → `./install.sh` real → desativar `dracula-copia-com.rtosta.zapzap` → `dev` vai para o fork
  público → `master` = `dev` + commits privados → `privado` (`AndreBFarias/MeowSystem-privado`, criado vazio)
  → release v2.0.0 no repositório privado.
- **v2.1.0** (P100, P104, P105): o mesmo caminho.
- De manhã, quem usa: `passwd`, sair e entrar na sessão, olhar o painel.

## 24/10 — leva H FECHADA (o mais novo; o resto abaixo é histórico)

1. `integracao/leva-h` no dev (`c089ee8`): P92 a P99, a reorganização em dois packs, o painel novo.
   Conferência final: APROVADO_COM_RESSALVAS, 77/77 duas vezes, container com 1 senha por pack.
2. `./install.sh` real: 3 passagens, 68 etapas; a linha dos 11 apps no `LANCADOR_OCULTAR`; `meow doctor` rc=0.
3. Vizinhos desativados (Spellbook terminal, caches, Aurora menu, NitroKit, cópias do Dracula), menos a do
   ZapZap (o `meow-whatsapp` instalado é a arte de 25/09, não a escolhida).
4. P95 concluída: Relatório MEC foi para o Spellbook; Dracula_OS-Theme e Migração-OS apagados.
5. `git filter-repo` (senha → ***), `git log --all -S` vazio; só `dev` e `master`; push para o
   `master` e o `dev` do fork; PR https://github.com/vitoriamariadb/MeowSystem/pull/2.

Próximo bloco (sem pedido, nada roda):
- P100: o patch v2 da Vitória (`8906456`) contra o rebase da P85 — é o conflito da PR.
- Ressalvas da conferência final (seção «## Execução» do `03-integracao-final.md`): FLAVOR que não
  acompanha o pack no install, `LOGO_*` que não troca com o pack, 3 sudo fora da ponte quando ela não
  responde, procedência com `/home/<usuário>`, nome «catppuccin» no `app-uso-real.py`.
- O `meow-whatsapp` velho no tema instalado; depois dele, desativar a `dracula-copia-com.rtosta.zapzap`.
- Seguimentos da P98: o reparo da ponte pelo «Conferir», papéis e sons no «Criar tema».
- Spellbook: `relatorio-mec/pdf_lavar_watch` guarda o lock em `/tmp` (veio assim do Dracula_OS-Theme).

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
   preparação feita em 23/10 (push do Dracula, pacotes em ~/Backups); apaga DEPOIS do install.

Em voo (23/10):
- P94 CONCLUÍDA e integrada (Alt+F2 pela porta única com plano B; medir-compositor no Spellbook aurora/;
  NitroKit: nada desativado ainda, vira a P99). Commits no Spellbook: acfd59e, bdf1236, cfd568b (sem push).
- P99 Flatpak veste o tema, workflow `wf_eb745c26-c60`, worktree `.wt-meow/p99`, Sonnet + Opus. Depois do
  install: desativar unificador e ritual do NitroKit pelo vizinhos.sh.
- bloco A (P92+P93), workflow `wf_efb436e1-89c`, worktree `.wt-meow/p92`, 2 Opus;
- P96 reorganização (`docs/sprints/2026-10-23-definitiva/`), worktree `.wt-meow/p96`: 2 Opus, fase 1 = perguntas
  para quem usa; fase 2 = o script, aplicado DEPOIS do bloco A entrar no dev;
- P97 interface: CONCLUÍDA (`sprint/p97`, commit do mockup final, 1,1 MB; prints e mockups A/B fora do repo em
  `.wt-meow/p97-design-fora-do-repo/`). Decisões: clicar no tema já veste; «Mais ajustes» recolhido; 4 portas.
  P98 (painel novo com tudo do antigo) EM VOO desde 23/10: workflow `wf_7e107a34-1e0`, worktree `.wt-meow/p98`,
  2 Opus; mexe só no front, a P96 mexe nos caminhos; integra depois da P96.
- Escolha dos ícones: 78 grupos respondidos por quem usa (`.wt-meow/p96-duvidas/escolhas-resolvidas.tsv`);
  o Citrix veste o do manuais-final (sim de 23/10, desfaz a decisão 16).

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

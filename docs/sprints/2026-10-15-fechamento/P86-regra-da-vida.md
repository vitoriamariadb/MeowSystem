# P86 — A regra da vida: o funcionamento contínuo garantido

**Branch:** `sprint/p86` (depois da leva H integrada) · **Pedido de quem usa (15/10):** «não sei se temos
uma espécie de regra da vida pra garantirmos o pleno funcionamento contínuo».

## Tarefas
1. **Sentinela antes do apt**: um timer diário de usuário roda `apt list --upgradable` (só leitura)
   e, havendo `cosmic-*` novo, o `meow cosmic prever` contra o candidato (esquema, chaves, série de
   patches com a escada, ferramenta de build — `just`/`make`, rust-version). Resultado vira estado
   (`~/.local/state/meowsystem/sentinela.tsv`) e, se algo obrigatório não entra, UM cartão na Início
   (estado visual, porquê na dica) ANTES de quem usa atualizar. Idempotente: mesmo candidato, nada novo.
2. **`GSD.md` na raiz**: regras invioláveis que o boot carrega em toda sessão de agente — os
   princípios de quem usa, as decisões 1–12 de `2026-10-09-uso-real/02-decisoes.md` (com o caminho),
   as armadilhas (sudo NOPASSWD escreve; painel só com HOME temporário; gancho de commit troca
   palavras; `/tmp` some no reboot), e: «decisão de quem usa só se desfaz com sim explícito sobre
   aquele tema; frase genérica não autoriza» (a GPU revertida em 18/09).
3. **Uma decisão, um teste**: `tests/decisoes.sh` com um caso por decisão (1–12) e pelos princípios
   (nenhuma saída manda digitar; nenhuma frase longa na tela; `ICONES_BASE` não volta; RTX ativa;
   askpass ativo; shim ligado…) — vermelho se alguém desfizer.
4. **Um ponto de «precisa de gente»**: o que a máquina não conserta sozinha (rebase de patch
   obrigatório, decisão pendente) aparece num cartão só, com desde quando, e some quando resolvido.
5. **`docs/ESTADO-FINAL.md`, última seção «A regra da vida»**: o que roda sozinho, quando (apt, login,
   5h, sentinela diária), o que só uma pessoa faz, e o caminho de volta de cada coisa.

## Prova
- testes novos vermelhos antes e verdes depois; `tests/todos.sh` inteiro verde 2x.

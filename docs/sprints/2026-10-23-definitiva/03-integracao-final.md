# Integração final de 23/10 — P92+P93, P96, P98, P99 numa árvore só

Árvore: `integracao/leva-h` (worktree `.wt-meow/integracao-h`). Já tem P90, P91, P94.

## 1. Integrar (agente 1)
1. Merge, nesta ordem: `sprint/p92` (P92+P93), `sprint/p99`, `sprint/p98`, `sprint/p96` (só traz os dois
   scripts e a spec).
2. Aplicar `docs/sprints/2026-10-23-definitiva/reorganizar-1-raiz.sh` e depois `reorganizar-2-packs.sh`
   (ensaio antes; um commit por script). Eles foram provados sobre a ponta da `sprint/p92`: o código novo da
   P98 e da P99 pode citar caminho velho (`assets/gatos`, `contratos/`, `packs/catppuccin`, subpastas de
   `icones/`, `assets/temas-de-apps`, «gato» na tela). Achar com `git grep` e consertar, commit à parte.
3. O conserto solto de 18/10 no `scripts/painel.sh` do checkout principal (os applets saem antes do painel):
   `.wt-meow/painel-sh-18-10.patch`, commit próprio.
4. `tests/todos.sh` inteiro.

## 2. O que falta (agente 2)
- **Ponte root, segurança (revisão automática de 23/10):** `libreoffice-devolver` não recebe nomes de quem
  chama: lê só a lista que o `libreoffice-remover` gravou como root em `/var/lib/meowsystem/`; a simulação
  confere `Remv` e `Purg` e recusa se faltar a remoção esperada ou se o plano tirar algo fora do LibreOffice e
  da ponte UNO. Teste para cada recusa.
- **Decisões de quem usa (23/10):**
  - terminal: o `vizinhos.conf` ganha exceção por arquivo e o MeowSystem escreve o bloco marcado dentro do
    `~/.config/zsh/.zshrc` (ZDOTDIR do Spellbook); no PC sem Spellbook, no `.zshrc`/`.bashrc` de sempre;
  - papéis de parede **separados por pack**: só a coleção do pack no ar gira; trocar de pack troca a coleção;
  - o **starship entra no install** (coberto pela senha única), como o fastfetch.
- **Defeitos achados:** instalar com `PACK=dracula` já no conf deixa o ponteiro do Catppuccin (decisão 12:
  o pack leva o ponteiro); o doctor manda «acrescente à mão» na linha do applet de leitura (nenhuma saída manda
  digitar); textos do servidor que a P98 não pôde mexer (`onde_na_tela`, `ABA_INICIO`, `DESCRICAO_SECAO` com
  as abas velhas; nomes de pendência e botões com mais de três palavras; maiúscula no começo);
  `docs/PACKS.md`, `docs/FRONTEIRA.md` (#667) e afins com as subpastas e a regra velha.
- `tests/todos.sh` inteiro duas vezes.

## 3. Conferência final (agente 3)
Regressão no todo: suíte duas vezes; instalação limpa num container `ubuntu:24.04` com os dois packs (a senha
uma vez só; depois, zero `sudo` fora da ponte); o painel novo em 1829x1029 nos dois packs; corrige o que achar.

## Depois (eu, com quem usa)
Merge no dev, `./install.sh` real, a linha dos 11 apps no `meow.conf`, as desativações nos vizinhos (Spellbook,
Dracula, Aurora, NitroKit), a P95, o histórico sem a senha, push do master do fork e a PR.

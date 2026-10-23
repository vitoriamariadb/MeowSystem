# Bloco P92 + P93 — o lançador inteiro é do MeowSystem (23/10)

Worktree `.wt-meow/p92`, branch `sprint/p92`, nascida da `integracao/leva-h` com P90 e P91 integradas.

## O que entra
1. [P92](P92-doutor-do-menu.md) — F1 (um mapa só para casar janela e lançador, lido por passo do
   MeowSystem com `chk_`/`fix_` no doctor e etapa no `install.sh`; o `appid_dock.sh` órfão deixa de ser
   órfão ou sai) e F2 (lançador órfão vai para quarentena com volta; `mimeinfo.cache` se refaz quando um
   `.desktop` do home é mais novo). `mimeapps.list` e editor padrão ficam do PC.
2. [P93](P93-ocultar-alcanca-tudo.md) — sombra de mesmo basename em `~/.local/share/applications` para o
   que não está em `/usr/share/applications` (mesmo mecanismo da sombra do applet de mídia), refeita
   quando o original muda; `--reverter` devolve.
3. **Decisão de quem usa (23/10):** os 11 apps que só o Dracula escondia ENTRAM no `LANCADOR_OCULTAR`
   (KeePassXC, gThumb e o importador dele, File Roller, COSMIC Monitor e Screenshot, Contas Online, Mozc,
   Ubuntu e os dois projetos pessoais). Os nomes exatos dos `.desktop` estão no relatório
   `docs/pesquisas/2026-10-17-vizinhos.md` e nas cópias em `~/.local/share/applications` (só ler).
4. `scripts/vizinhos.sh`: um tipo novo de item que MOVE um arquivo para a cópia datada e o devolve no
   `--restaurar`; itens novos no `contratos/vizinhos.tsv` para: as 25 cópias do `aplicar_overrides.sh`
   (requer o MeowSystem instalado com a sombra da P93), o `aplicar_overrides.sh`, o
   `aurora-menu-doctor.py` e o `aurora-desktop-guards-apply.sh` (requer a P92 instalada), e o bloco do
   `--activate` do `install.sh` do Dracula_OS-Theme (tipo `bloco`, P94 item 2). Só o catálogo e o
   mecanismo: NADA é desativado nesta sprint — isso é do bloco seguinte, depois do install.

## Como se prova
- testes novos em casa de brinquedo (janela com `StartupWMClass` errado, lançador órfão, cache velha,
  flatpak e app do home de brinquedo, o tipo novo do vizinhos): o doctor vê, o `--consertar` cura, a
  segunda passada não escreve, o `--reverter`/`--restaurar` devolve; entram no `tests/todos.sh`;
- `tests/todos.sh` inteiro duas vezes seguidas, sem vermelho novo; `tests/decisoes.sh` verde;
- os números (`tests/numeros.sh`: contagem de conferências do doctor, README) acompanham.

# P95 — Os vizinhos que se metem saem da casa

**Status: CONCLUÍDA em 24/10, depois do install do MeowSystem novo.**

## Pedido de quem usa (23/10)
«Corrigir os outros repos que se metem aqui localmente. Apagar localmente o Dracula OS Theme e o
Migração OS.»

## O que se mediu (23/10)
- `~/Desenvolvimento/Dracula_OS-Theme`: 704 MB, git, `main` **2 commits à frente** do `origin`
  (um é o `f41ee47a` da P91), **5 arquivos sem commit** (a frente das fontes de design).
- `~/Desenvolvimento/Migração-OS`: 24 MB, **sem git** — apagar é perder para sempre. Tem as levas, os
  scripts da GPU (`scripts/gpu-2026-10-09/`) e o `medir-compositor.sh` (P94 item 4).
- O Spellbook (`~/.config/zsh`) cita os dois em pelo menos 10 arquivos, entre eles `install.sh`,
  `functions/sistema.zsh`, `functions/aurora-self-heal.zsh`, `aurora/aurora-menu-doctor.py` e um patch
  do compositor. Apagar sem mexer nele deixa caminho quebrado no terminal.

## A cura
1. **Corrigir os que se metem** (os que ficam): a P94 inteira (Spellbook, NitroKit) e as desativações
   do `scripts/vizinhos.sh` depois do install (P92/P93). O critério é o `vizinhos.sh --conferir`:
   nenhuma responsabilidade com dois donos ativos.
2. **Antes de apagar o Dracula_OS-Theme**: o que é dele e ainda vale fica no GitHub (push dos 2
   commits; a frente das fontes vira commit ou patch guardado — escolha de quem usa). A P94 item 2
   (bloco do `--activate`) perde o sentido com o repositório apagado e sai da lista.
3. **Antes de apagar o Migração-OS**: o `medir-compositor.sh` vai para o Spellbook `aurora/` (P94
   item 4); o resto é registro e vai num `.tar.zst` datado fora de `~/Desenvolvimento` (onde, quem
   usa decide), porque não há git para voltar.
4. **O Spellbook deixa de citar os dois**: cada referência vira o caminho do MeowSystem instalado ou
   sai; commit só disso lá.
5. **Apagar** as duas pastas; `contratos/vizinhos.tsv` e o inventário passam a dizer «não existe nesta
   casa» para eles, sem vermelho.

## Como se prova
- `scripts/vizinhos.sh --inventario` sem escritor vindo dos dois; `--conferir` limpo;
- `grep -r` no Spellbook sem `Dracula_OS-Theme` nem `Migração-OS` (fora de histórico e changelog);
- terminal novo abre sem erro; `meow doctor` igual ao de antes (nada a consertar);
- `git -C` no GitHub do Dracula mostra os 2 commits; o `.tar.zst` do Migração-OS abre.

## Decisões de quem usa (23/10)
- Executar: prepara agora, **apaga só depois do install do MeowSystem novo dar certo**.
- Dracula_OS-Theme: commit + push de tudo antes de apagar.
- Migração-OS: pacote em `~/Backups/`.

## Feito em 23/10 (preparação)
- Dracula_OS-Theme: o commit `75d7d2d7` (fontes de design com Zrnic) e o `f41ee47a` estão no `origin/main`.
  O `.otf` da Zrnic (sem arquivo de licença, e o repositório é público) e o `reverso-dns` (só linhas «1»,
  saída solta) não foram ao GitHub: estão em `~/Backups/Dracula_OS-Theme-soltos-2026-10-23.tar.zst`.
- Migração-OS: `~/Backups/Migracao-OS-2026-10-23.tar.zst` (582 entradas, as mesmas da pasta).

## Falta (depois do install)
1. P94 entrega o `medir-compositor.sh` no Spellbook `aurora/`.
2. O Spellbook deixa de citar os dois (caminho do MeowSystem instalado, ou sai), commit só disso. Esperar a
   P94 terminar, porque ela também commita no Spellbook.
3. Apagar as duas pastas; terminal novo abre limpo; `meow doctor` igual.

## Feito em 24/10
- O pipeline do Relatório MEC (`relatorio check`/`instalar`) tinha a fonte no Dracula_OS-Theme
  (`src/relatorio-mec` e `scripts/instalar_relatorio_mec.sh`): foi para o Spellbook, `relatorio-mec/`
  (commit `e1f28bb` lá, sem push). `relatorio check` roda de lá com tudo «já em dia».
- `/etc/apt/apt.conf.d/99-relatorio-mec` aponta para `~/.config/zsh/relatorio-mec/instalar.sh` (cópia de antes
  em `/root/99-relatorio-mec.antes-p95-20261024`).
- `rebuild_dracula_theme` já estava desativada desde 23/09 (só avisa); o resto das citações no Spellbook é
  comentário ou histórico.
- As duas pastas foram apagadas. Depois: `vizinhos.sh --conferir` limpo, terminal novo sem erro,
  `meow doctor` rc=0.
- Ficam ativos no `--listar` os dois itens do Dracula_OS-Theme (o arquivo não existe mais) e a
  `dracula-copia-com.rtosta.zapzap`: o `meow-whatsapp` instalado é a arte de 25/09, não a escolhida
  (`whatsapp-linux-app.svg`); tirar a cópia agora regride o ícone do ZapZap.

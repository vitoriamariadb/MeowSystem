# P94 — Os vizinhos de fora que ainda disputam com o MeowSystem

**Status: REGISTRADA em 17/10 pela P91 — NÃO executar sem quem usa mandar.** Cada item mora no
repositório dele; aqui fica só o registro. Origem:
[`docs/pesquisas/2026-10-17-vizinhos.md`](../../pesquisas/2026-10-17-vizinhos.md), linhas 7, 15, 16 e 20.

## 1. O Alt+F2 recicla o painel por fora da porta única (Spellbook)
`aurora-reiniciar-casca.sh` chama `/usr/local/bin/aurora-reiniciar-painel.sh`, que faz
`pkill -x cosmic-panel` direto. O cabeçalho da casca diz que esse script é «portado da meowsystem
(hash de3416ca…)»; nenhum arquivo versionado do MeowSystem de hoje tem esse hash. A porta única é
`meow painel reciclar`: ela arma o `meow-painel.service` antes de reciclar e se recusa quando o
cosmic-session dormiria por causa do backoff.
**Cura:** a casca pede `meow painel reciclar` quando o `meow` existe, e cai no script de hoje só sem
ele; o `aurora-cosmic-apply.sh` reinstala a casca no `/usr/local/bin` no próximo apt. Commit só disso
no Spellbook. **Prova:** Alt+F2 recicla o painel e o `journalctl --user -u meow-painel` registra o
pedido; `scripts/vizinhos.sh --inventario` deixa de mostrar o `aurora-reiniciar-painel.sh` como
escritor do painel.

## 2. O `install.sh --activate` do Dracula grava cursor e ícone no gsettings (Dracula_OS-Theme)
`gsettings set … icon-theme 'Dracula-Icones'`, `gtk-theme` e `cursor-theme` por cima do MeowSystem
(`cursor.sh` é o dono do `cursor-theme`). O arquivo tem mudança de outra frente sem commit (fontes de
design), então não foi tocado na P91. **Cura:** depois do commit daquela frente, o bloco do
`--activate` sai comentado pelo `vizinhos.sh` (item `bloco` novo no contrato) e um commit só disso.

## 3. O NitroKit do tempo do GNOME (NitroKit)
`src/unificador_temas_dracula.sh`, `src/ritual_de_harmonia.sh` e `src/reparo_completo_sistema.sh`
gravam tema de ícones, GTK, cursor e lançadores; rodam à mão. **Cura:** conferir um a um o que o
MeowSystem já cumpre (as linhas do doctor) e desativar pelo `vizinhos.sh`, com commit só disso.

## 4. O `medir-compositor.sh` sai do Migração-OS (nota de quem usa: «nada deveria estar no Migração-OS»)
É a medida do compositor por GPU, do PC. **Cura:** vai para o Spellbook, em `aurora/`, ao lado da
guarda da GPU (sem mexer nela); o Migração-OS não é repositório git, então a cópia lá só sai com a
palavra de quem usa.

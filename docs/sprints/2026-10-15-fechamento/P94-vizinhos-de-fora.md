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

## Execução (23/10)

Quem usa mandou executar em 23/10 («tudo, inclusive o Dracula»). Esta rodada fez os itens 1, 3 e 4.
O item 2 (`install.sh --activate` do Dracula_OS-Theme) **não foi feito**: o Dracula_OS-Theme vai ser
apagado desta máquina pela P95, então não se mexe nele. Nada foi empurrado (`push`).

| item | repositório | commit | situação |
|---|---|---|---|
| 1 | Spellbook (`~/.config/zsh`) | `acfd59e` | feito |
| 3 | NitroKit | — | **nenhum commit**: nenhum dos três scripts é coberto por inteiro |
| 4 | Spellbook (`~/.config/zsh`) | `bdf1236` | feito |

### Item 1 — a casca do Alt+F2 pede a porta única (`acfd59e`)
`aurora/aurora-reiniciar-casca.sh`: acha o `meow` no PATH (ou em `~/.local/bin/meow`, porque o
Spawn do COSMIC pode não ter esse PATH) e roda `meow painel reciclar` com
`MEOW_QUEM_RECICLA="Alt+F2 (aurora-reiniciar-casca)"`, para o `meow.log` dizer quem pediu. Só sem
o `meow` cai no `aurora-reiniciar-painel.sh`. Se a porta única recusar (cosmic-session dormiria), a
casca não faz `pkill` por fora: a recusa aparece na saída e os extras seguem a verificação de sempre.
**Prova:** `bash -n` limpo; num HOME descartável, com `pgrep`/`pkill`/`notify-send` falsos e o
script de painel trocado por um falso, rodou a casca em três casos: meow falso no PATH imprimiu
`FALSO meow painel reciclar | quem=Alt+F2 (aurora-reiniciar-casca)`; sem meow imprimiu
`FALSO script de hoje`; meow só em `~/.local/bin` voltou a usar o meow. Os três saíram 0. O reciclar
de verdade não foi rodado. **Falta:** a cópia em `/usr/local/bin` só troca quando o
`aurora-cosmic-apply.sh` reinstalar a casca (próximo apt); o `vizinhos.sh --inventario` só deixa de
mostrar o `aurora-reiniciar-painel.sh` depois disso.

### Item 4 — `medir-compositor.sh` no Spellbook (`bdf1236`)
Copiado (modo preservado) de `Migração-OS/scripts/` para `aurora/medir-compositor.sh`, ao lado da
guarda da GPU, que não foi tocada. Só o texto de uso mudou (caminho novo); o código é idêntico
(`diff` mostra só o bloco COMO USAR). **Prova:** `bash -n` limpo e rodou aqui (só lê `/proc`, `/sys`
e o journal): cosmic-comp pid lido, `COSMIC_RENDER_DEVICE=0x10de:0x25a2`, 2 fds no `renderD129`
(nvidia), VRAM e PSI impressos. A cópia no Migração-OS ficou (não é git; nada apagado).

### Item 3 — NitroKit: nada desativado, e por quê
Regra desta rodada: só desativa o que o MeowSystem cumpre **por inteiro**. Conferido linha a linha
contra o código do MeowSystem e contra o `meow doctor` (só leitura, sem `--consertar`): nenhum dos
três passa. Por isso não há linha nova em `contratos/vizinhos.tsv` e não há commit no NitroKit.

**`src/unificador_temas_dracula.sh`**
| o que grava | o MeowSystem cobre? |
|---|---|
| `sudo cp` de `~/.icons/Dracula-cursors`, `DraculaCustom`, `~/.themes/Dracula-standard-buttons` para `/usr/share` | não: o MeowSystem é por usuário (`~/.local/share/icons`). Aqui é no-op: nenhuma dessas pastas existe |
| `gsettings` `cursor-theme` | sim: `cursor.sh` (dono), doctor `cursor ok` (`Dracula-Cursor-cursors`) |
| `gsettings` `icon-theme` | sim, pelo caminho do COSMIC: `CosmicTk/icon_theme` = `MeowSystem-Icons` (`completar_icones.sh`; doctor `icones`, `completar`, `indice`) |
| `gsettings` `gtk-theme` | sim, pelo caminho do COSMIC: `apply_theme_global=true` e os `gtk.css` (doctor `apps`, «toolkits-gtk-qt») |
| `flatpak override` `--filesystem=/usr/share/icons` e `/usr/share/themes` | **não**: nada no MeowSystem faz `flatpak override` (só a coleta lê) |
| `flatpak override` `--env=XCURSOR_THEME`, `ICON_THEME`, `GTK_THEME` | **não**, e pior: o override do sistema de hoje é `Dracula-Cursor`/`Dracula-Icones`/`Dracula` e o script o trocaria por `Dracula-cursors`/`DraculaCustom`/`Dracula-standard-buttons`, nomes que não existem nesta máquina |
| `NoDisplay=true` no `libreoffice-startcenter.desktop` do home | **não**: o MeowSystem não cita o LibreOffice (o arquivo de hoje, com `NoDisplay=true`, veio de outra mão) |

**`src/ritual_de_harmonia.sh`**: temas `Lavanda-Dark`/`Numix-Roxo`/`Bibata-Modern-Ice` (não são do
pack), `org.gnome.shell.extensions.user-theme` e `org.gnome.mutter overlay-key` (atalho do
Ulauncher no GNOME), mais os mesmos overrides do Flatpak e a cópia para `/usr/share`. Nada disso é
do MeowSystem; só o `cursor-theme`/`icon-theme` têm dono, com outros nomes.

**`src/reparo_completo_sistema.sh`**: reparo de apt/dpkg (`dpkg --configure -a`, `autoremove --purge`,
`rm /var/lib/apt/lists/*`, `dist-upgrade`), PPA System76 e reinstalação de `system76-*` e
`nvidia-settings`, reinstalação de `ubuntu-desktop`/`gnome-shell`/`gdm3`, `rm` de todo `.desktop`
cujo `Exec=` não existe (varre o `locate` inteiro, inclusive `/usr/share`), `gsettings
reset-recursively` e `gtk-update-icon-cache` em `/usr/share/icons/*`. O MeowSystem não cuida de
apt, driver nem pacote-base; só a cache de ícones tem dono (por tema, não no `/usr/share` inteiro).

**Decisão que fica com quem usa** (nenhuma foi tomada por esta rodada): (a) mandar desativar mesmo
assim os dois primeiros, porque são do tempo do GNOME e rodam à mão (a volta é o `--restaurar`);
(b) passar a parte do Flatpak (permissão de `/usr/share/icons`/`themes` e as três variáveis) e o
`NoDisplay` do LibreOffice para o MeowSystem, e então desativar o unificador por inteiro. O
`reparo_completo_sistema.sh` é perigoso nesta máquina (COSMIC, sem GNOME) e fica por ser o único que
repara pacote; vale tirá-lo da mão, mas isso é do NitroKit, não do MeowSystem.

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

## Execução (23/10)

Branch `sprint/p92`, oito commits (`a9464bc` a este). Nada foi escrito no HOME real nem no Dracula ou
no Spellbook: o real só foi lido (`--conferir` com `MEOW_DRY_RUN=1`, `--listar`, `cmp`).

### O que entrou
1. **P92 F1, um mapa só.** O `assets/icones/wmclass.map` saiu; o valor dele (`boxy-svg-boxy-svg`) virou
   linha `:alias` do `appid.map`, ao lado do `boxy-svg-boxy-svg-linux` medido pela sonda. As duas pontes
   ficam porque o Boxy não estava aberto para medir de novo (o real hoje: 3 pontes a criar, Boxy ×2 e
   Hefesto). O `appid_dock.sh` deixou de ser órfão: `chk_janeladock`/`fix_janeladock` no doctor,
   `etapa_janela_dock` no `install.sh`, `--reverter` no desinstalador; saiu da dívida do `tests/orfaos.sh`.
   A cópia do Boxy no home (`StartupWMClass=boxy-svg-boxy-svg;Boxy SVG;`) nunca casou: o casamento é a
   string inteira.
2. **P92 F2.** `scripts/lancador.sh` + `scripts/lancador_orfaos.py` (a régua de wrapper, namespace,
   `sh -c` e flatpak do `aurora-menu-doctor.py`; o que leva `X-MeowSystem` ou roda `~/.local/bin/meow*`
   é julgado pelo passo dono). Órfão vai para `~/.local/state/meowsystem/lancador-quarentena/` com
   registro e `--reverter`; o `mimeinfo.cache` do home se refaz quando um `.desktop` é mais novo.
   `chk_lancador`/`fix_lancador`, `etapa_lancador` (depois de toda etapa que escreve no home). No real
   hoje: nenhum órfão, cache em dia — o mesmo que o `aurora-menu-doctor.py --json` diz.
3. **P93.** `scripts/ocultar_casa.sh`: para o que a lista do `ocultar` nomeia e não está em
   `/usr/share/applications`, sombra de mesmo basename no home (só `Type Name Exec TryExec Icon
   StartupWMClass MimeType`, `NoDisplay=true`, `X-MeowSystem=ocultar` e a origem), refeita quando o
   original muda e tirada quando o app sai; o `.desktop` que só existe no home é marcado no lugar
   (`X-MeowSystem=ocultar-no-lugar`, desfeito linha a linha). Mesma chave (`LANCADOR_SISTEMA`), mesma
   lista (`ocultar_apps.sh --lista`). Medido no fonte instalado (cosmic-app-library `3651caf`, libcosmic
   `430f3d4`, `desktop_entries_with_precedence`): o lançador deduplica pelo id antes de filtrar o
   NoDisplay, com o home primeiro — a sombra esconde. O `docs/FRONTEIRA.md` (#667, «não deduplica») está
   velho nesse ponto e não foi mexido.
4. **Item 3 (os 11 no `LANCADOR_OCULTAR`)**: não entrou no código — a lista é a do `meow.conf` dela, no
   HOME real. A linha pronta está em «O que ficou de fora».
5. **Vizinhos.** Tipo `mover` (cópia datada, `--restaurar` devolve; se o arquivo voltou a existir, avisa e
   não sobrescreve) e o prefixo `$APPS/`. Itens novos no contrato: `dracula-aplicar-overrides` (saída),
   23 `dracula-copia-*` (mover; requerem a sombra da P93 instalada, o do Boxy a `etapa_janela_dock`, o do
   ZapZap nada), `aurora-menu-orfaos` e `aurora-menu-cache` (bloco no `aurora-menu-doctor.py`, requerem
   o `lancador.sh` instalado) e `dracula-ativar-gsettings` (bloco no `install.sh` do Dracula). Nada
   desativado. Provado numa cópia dos arquivos reais: os três blocos aplicam, o Python compila, o bash
   lê, o `--check` do doctor da Aurora roda, e o `--restaurar todos` volta byte a byte.
6. Toda escrita das três etapas guarda o estado de antes (`meow_guardar_antes`): o `restaurar.sh
   pack_usar` acusou a cache refeita sem cópia e passou a voltar byte a byte.

### Números
66 etapas (+3), 69 conferências (+3), 74 testes (+1: `tests/lancador-do-meow.sh`, 34 afirmações);
`tests/vizinhos.sh` com 50 (+8). README, README.en e SPRINTS acompanham (`tests/numeros.sh` verde).

### Provas rodadas
- `tests/lancador-do-meow.sh`: a ponte, o órfão, a cache e o ocultar (flatpak, /usr/local, home) — o
  conferir vê sem escrever, o aplicar cura, a segunda passada não escreve, o reverter devolve.
- O `bin/meow doctor` numa casa de brinquedo: as três linhas em `~~`; depois dos três consertos, em `ok`.
- `tests/todos.sh` inteiro duas vezes seguidas, mesma resposta:
  `== todos os 74 · 72 verde(s), 1 pulado(s), 1 vermelho(s) ==`. O pulado é o `conversor.sh` (pula
  sem o Papirus de referência, como na base). O vermelho é o `app-completo.py`: a reprovação fixa é
  `[Lançadores e jogos › jogo · abrir] Locator.click: Timeout`, e ela acontece igual na base `5ec4a4c`
  (rodada à parte numa cópia da árvore); as outras reprovações de tempo mudam de rodada para rodada,
  com outro `app-completo.py` rodando ao mesmo tempo na worktree p98.
  `decisoes.sh`, `doctor-so-le.sh`, `seco.sh`, `convergencia.sh`, `restaurar.sh` e `orfaos.sh` verdes.

### O que ficou de fora
- **A linha do `meow.conf` dela** (item 3), no fecho, com o HOME real:
  `LANCADOR_OCULTAR` ganha `org.keepassxc.KeePassXC,org.gnome.gThumb,org.gnome.gThumb.Import,org.gnome.FileRoller,com.system76.CosmicMonitor,com.system76.CosmicScreenshot,gnome-online-accounts-gtk,setup-mozc,Ubuntu,mnemo,elden-ring-tracker`.
  Medido com o `--conferir`: 9 deles moram em `/usr/share` (o `ocultar_apps.sh` marca), Ubuntu e mnemo
  só no home e já escondidos.
- **mnemo e Ubuntu fora do `mover`**: a cópia é o único lançador do app; tirá-la apagaria o programa.
- **`aurora-desktop-guards-apply.sh` sem item**: o que sobra nele é do PC (o Exec do PhotoGIMP, a
  máscara do tracker e a chamada do doctor da Aurora, que segue cuidando do `mimeapps.list`).
- A desativação de tudo isso é do bloco seguinte, depois do merge e do install.

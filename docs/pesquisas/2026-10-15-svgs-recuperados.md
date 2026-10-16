# SVGs recuperados: o que voltou da lixeira, do disco e das transcrições

Data: 15/10/2026. Pesquisa sem commit. Junta as duas frentes de recuperação (fontes baratas e arquivos excluídos), tira as duplicatas e compara tudo com o MeowSystem.

## Resposta curta

1. **Nada do que foi recuperado é desenho nosso perdido de vez e ausente de qualquer versão do pack**, com duas exceções pequenas: os rascunhos antigos (morcego-dia, morcego-noite, mozc, folder-templates, uad-ng, Ubuntu) e os 9 candidatos do Syncthing feitos em 16/09. Esses estão na classe (a), e só sobreviveram nas transcrições do agente.
2. **A falta visível tem outra causa: está no branch `sprint/p84`, não no `dev`.** São 53 das 90 versões editadas (classe b), de 27 desenhos feitos à mão da P84. O photorec achou 44 rascunhos de hoje desses desenhos, e o desenho final de cada um está em `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/`.
3. **Os 263 PNG do photorec não são perda.** 254 deles são renders ou exportações de ícones que já estão no pack (RMSE ≤ 0,03 a 64 px). Os outros 7 são renders das pastas de 16/09 e de um rascunho da claquete, e quase todos ainda estão em `.trabalho-icones/render/`.

## Como foi medido

- **Achados:** `/var/tmp/meow-recup/{lixeira,apate,transcricoes,photorec,vscode,ext4magic}.tsv`. São 458 linhas e **432 arquivos únicos por sha256**. 14 rascunhos aparecem tanto no photorec quanto nas transcrições, e a lixeira tem 12 duplicatas (zips repetidos).
- **Referência do MeowSystem:** `packs/**`, `assets/icones/**` e `../.wt-meow/p84/packs/dracula/icones/feitos-a-mao`, ao todo 27.356 arquivos (26.169 sha distintos). A comparação usa o sha256, o texto do SVG sem espaços e a semelhança visual.
- **Contexto (a outra varredura):** `svgs/{disco,historico,temas-instalados,uso}.tsv` pelo sha256. Para a comparação visual entram também os 72.956 arquivos distintos de `disco.tsv` (menos `~/Android`) e os blobs do histórico do git.
- **Semelhança visual:** cada arquivo é renderizado a 64 px com `rsvg-convert` e composto sobre cinza 50%. A medida é o RMSE dos canais, de 0 a 1, com pré-filtro a 16 px. Na calibração com versões conhecidas, edição do mesmo desenho deu de 0,005 a 0,10, render PNG de um SVG deu de 0,007 a 0,028, e desenhos diferentes deram acima de 0,16.
- **Regras de classe:**
  - Sha igual, texto igual ou RMSE ≤ 0,004 conta como «já no MeowSystem».
  - PNG com RMSE ≤ 0,03 contra o pack é render ou exportação.
  - RMSE ≤ 0,10, ou ≤ 0,15 com o mesmo nome de arquivo, é (b).
  - SVG do photorec é casado com a P84 pelo comentário descritivo, que é o mesmo da versão final.
  - Transcrição de `.trabalho-icones`, da P84 ou de scratchpad de sessão sem par visual é (a).
- O resultado por arquivo está em `/var/tmp/meow-recup/consolidado.tsv`, uma linha por sha, com classe, par, RMSE, onde mais existe e prova. Os scripts estão em `/tmp/claude-1000/-home-andrefarias-Desenvolvimento-MeowSystem/dc213a2a-e0f4-450b-a4ae-66168a57aa5f/scratchpad/recup2/`.

## Números por fonte e classe (arquivos únicos)

| fonte | linhas | já no MeowSystem | (a) nosso | (b) editado | (c) terceiros | (d) pessoal | (e) lixo |
|---|---|---|---|---|---|---|---|
| transcrições do agente | 125 | 24 | 39 | 53 | 1 | 0 | 8 |
| photorec (espaço livre do /home) | 307 | 254 | 0 | 51 | 2 | 0 | 0 |
| lixeira | 24 (12 únicos) | 0 | 0 | 0 | 4 | 8 | 0 |
| disco Apate (NTFS) | 2 | 0 | 0 | 0 | 2 | 0 | 0 |
| VS Code / Inkscape / `*.svg~` | 0 | | | | | | |
| ext4magic | 0 | | | | | | |
| **total único** | **432** | **278** | **39** | **90** | **9** | **8** | **8** |

14 rascunhos da P84 estão nas transcrições e também no photorec. Na tabela entram nas duas linhas e no total só uma vez.

**Onde fica o par das 90 versões da classe (b):**
- 53 versões (27 desenhos) têm o final **só em `sprint/p84`**.
- 27 versões (10 desenhos) têm o final no pack Dracula do `dev`, quase todas pastas de 16/09.
- 10 versões (8 desenhos) têm o final no acervo do motor (`assets/icones/resgatados`), fora do pack.

## Folhas de contato

Em `.playwright-mcp/ux-svg/`. Cada uma foi conferida a olho.
- `recuperados-a-nosso.png`: 39 itens. Morcego-dia em 10 versões, morcego-noite em 4, mozc em 4, folder-templates em 8, uad-ng em 2, Ubuntu e Ubuntu-selfservice, e os candidatos do Syncthing (candA a candC, v1, v2, v4, v5, glyph, `$1`).
- `recuperados-b-editado.png`: 90 pares. À esquerda está o recuperado e à direita o par no MeowSystem ou na P84, com o RMSE.
- `recuperados-c-terceiros.png`: 9 itens. BeautyFolders (alacritty, thunar), ativos do Grok (plus, glass-share, glass-puzzle, logo), Obsidian do Papirus e 2 PNG do logo do Discord sem par exato.
- `recuperados-d-pessoal.png`: 8 itens. Os logos Ouroboros (6) e o workspace Grok «construindo visão» (2).
- `recuperados-e-lixo.png`: 8 itens. As fixtures de teste `pack/a` a `d`, `folder`, `user-home` e `user-desktop`, e o `xss.svg` do teste de pack malicioso.
- `recuperados-ja-no-meow.png`: 278 pares, para conferir que nada ali falta.

## (a) Nosso, com prova: só existe recuperado ou fora do pack

A prova de cada linha é a transcrição do agente que escreveu o arquivo, com a sessão e o caminho original.
- Os rascunhos de `.trabalho-icones` são da sessão `55ef96a5`, de 16/09.
- Os candidatos do Syncthing foram feitos no scratchpad dessa mesma sessão, aberta no projeto Migração-OS.
- Nenhum deles tem par visual no MeowSystem (RMSE de 0,108 a 0,283).

| nome | sha256 | arquivo recuperado (em `/var/tmp/meow-recup/`) | escrito em | data | ainda existe em outro lugar? |
|---|---|---|---|---|---|
| $1.svg | `0178c4e0` | `transcricoes/tmp__claude-1000__-home-andrefarias-Desenvolvimento-Migra--o-OS__55ef96a5-bdea-42fb-b76f-0f3fd384396e__scratchpad__$1.svg` | `scratchpad da sessão 55ef96a5/$1.svg` | 2026-09-16 | não, só o recuperado |
| candA.svg | `dc389483` | `transcricoes/tmp__claude-1000__-home-andrefarias-Desenvolvimento-Migra--o-OS__55ef96a5-bdea-42fb-b76f-0f3fd384396e__scratchpad__candA.svg` | `scratchpad da sessão 55ef96a5/candA.svg` | 2026-09-16 | não, só o recuperado |
| candB.svg | `41a3a234` | `transcricoes/tmp__claude-1000__-home-andrefarias-Desenvolvimento-Migra--o-OS__55ef96a5-bdea-42fb-b76f-0f3fd384396e__scratchpad__candB.svg` | `scratchpad da sessão 55ef96a5/candB.svg` | 2026-09-16 | não, só o recuperado |
| candC.svg | `66e81199` | `transcricoes/tmp__claude-1000__-home-andrefarias-Desenvolvimento-Migra--o-OS__55ef96a5-bdea-42fb-b76f-0f3fd384396e__scratchpad__candC.svg` | `scratchpad da sessão 55ef96a5/candC.svg` | 2026-09-16 | não, só o recuperado |
| folder-templates.svg | `86ebe3b9` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-templates.svg` | `MeowSystem/.trabalho-icones/pastas/folder-templates.svg` | 2026-09-16 | não, só o recuperado |
| folder-templates.svg | `12981606` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-templates.v1.svg` | `MeowSystem/.trabalho-icones/pastas/folder-templates.svg` | 2026-09-16 | não, só o recuperado |
| folder-templates.svg | `4a5ed53a` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-templates.v2.svg` | `MeowSystem/.trabalho-icones/pastas/folder-templates.svg` | 2026-09-16 | não, só o recuperado |
| folder-templates.svg | `2b0570e6` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-templates.v3.svg` | `MeowSystem/.trabalho-icones/pastas/folder-templates.svg` | 2026-09-16 | não, só o recuperado |
| folder-templates.svg | `ddabd2b5` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-templates.v4.svg` | `MeowSystem/.trabalho-icones/pastas/folder-templates.svg` | 2026-09-16 | não, só o recuperado |
| folder-templates.svg | `471b7f59` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-templates.v5.svg` | `MeowSystem/.trabalho-icones/pastas/folder-templates.svg` | 2026-09-16 | não, só o recuperado |
| folder-templates.svg | `eaef5d72` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-templates.v6.svg` | `MeowSystem/.trabalho-icones/pastas/folder-templates.svg` | 2026-09-16 | não, só o recuperado |
| folder-templates.svg | `195e7a61` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-templates.v7.svg` | `MeowSystem/.trabalho-icones/pastas/folder-templates.svg` | 2026-09-16 | não, só o recuperado |
| glyph.svg | `67faf90f` | `transcricoes/tmp__claude-1000__-home-andrefarias-Desenvolvimento-Migra--o-OS__55ef96a5-bdea-42fb-b76f-0f3fd384396e__scratchpad__glyph.svg` | `scratchpad da sessão 55ef96a5/glyph.svg` | 2026-09-16 | não, só o recuperado |
| morcego-dia.svg | `4089a4ac` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego-dia.svg` | `MeowSystem/.trabalho-icones/svg/morcego-dia.svg` | 2026-09-16 | sim, `.trabalho-icones` e `assets/gatos` (git) |
| morcego-dia.svg | `41c355f1` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego-dia.v1.svg` | `MeowSystem/.trabalho-icones/svg/morcego-dia.svg` | 2026-09-16 | não, só o recuperado |
| morcego-dia.svg | `a4283880` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego-dia.v2.svg` | `MeowSystem/.trabalho-icones/svg/morcego-dia.svg` | 2026-09-16 | não, só o recuperado |
| morcego-dia.svg | `b47353cb` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego-dia.v3.svg` | `MeowSystem/.trabalho-icones/svg/morcego-dia.svg` | 2026-09-16 | não, só o recuperado |
| morcego-dia.svg | `ec89ff74` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego-dia.v4.svg` | `MeowSystem/.trabalho-icones/svg/morcego-dia.svg` | 2026-09-16 | não, só o recuperado |
| morcego-dia.svg | `1907e565` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego-dia.v5.svg` | `MeowSystem/.trabalho-icones/svg/morcego-dia.svg` | 2026-09-16 | não, só o recuperado |
| morcego-dia.svg | `52a4be5b` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego-dia.v6.svg` | `MeowSystem/.trabalho-icones/svg/morcego-dia.svg` | 2026-09-16 | não, só o recuperado |
| morcego-dia.svg | `2e6dcd33` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego-dia.v7.svg` | `MeowSystem/.trabalho-icones/svg/morcego-dia.svg` | 2026-09-16 | não, só o recuperado |
| morcego-dia.svg | `754256ac` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego-dia.v8.svg` | `MeowSystem/.trabalho-icones/svg/morcego-dia.svg` | 2026-09-16 | não, só o recuperado |
| morcego-dia.svg | `9db7f510` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego-dia.v9.svg` | `MeowSystem/.trabalho-icones/svg/morcego-dia.svg` | 2026-09-16 | sim, `.trabalho-icones` e `assets/gatos` (git) |
| morcego-noite.svg | `e49d7bf3` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego-noite.svg` | `MeowSystem/.trabalho-icones/svg/morcego-noite.svg` | 2026-09-16 | sim, `.trabalho-icones` e `assets/gatos` (git) |
| morcego-noite.svg | `79b55d26` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego-noite.v1.svg` | `MeowSystem/.trabalho-icones/svg/morcego-noite.svg` | 2026-09-16 | não, só o recuperado |
| morcego-noite.svg | `a51c9cc5` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego-noite.v2.svg` | `MeowSystem/.trabalho-icones/svg/morcego-noite.svg` | 2026-09-16 | não, só o recuperado |
| morcego-noite.svg | `7fa48899` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego-noite.v3.svg` | `MeowSystem/.trabalho-icones/svg/morcego-noite.svg` | 2026-09-16 | não, só o recuperado |
| mozc.svg | `d37faf1a` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__mozc.v2.svg` | `MeowSystem/.trabalho-icones/svg/mozc.svg` | 2026-09-16 | não, só o recuperado |
| mozc.svg | `f45b2989` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__mozc.v3.svg` | `MeowSystem/.trabalho-icones/svg/mozc.svg` | 2026-09-16 | não, só o recuperado |
| mozc.svg | `f10a8e1c` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__mozc.v4.svg` | `MeowSystem/.trabalho-icones/svg/mozc.svg` | 2026-09-16 | não, só o recuperado |
| mozc.svg | `56952c2b` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__mozc.v5.svg` | `MeowSystem/.trabalho-icones/svg/mozc.svg` | 2026-09-16 | não, só o recuperado |
| uad-ng.svg | `41122802` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__uad-ng.v1.svg` | `MeowSystem/.trabalho-icones/svg/uad-ng.svg` | 2026-09-16 | só no histórico do git |
| uad-ng.svg | `97a1c6ba` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__uad-ng.v2.svg` | `MeowSystem/.trabalho-icones/svg/uad-ng.svg` | 2026-09-16 | não, só o recuperado |
| Ubuntu-selfservice.svg | `d64a7137` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__Ubuntu-selfservice.v2.svg` | `MeowSystem/.trabalho-icones/svg/Ubuntu-selfservice.svg` | 2026-09-16 | não, só o recuperado |
| Ubuntu.svg | `604bac97` | `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__Ubuntu.v1.svg` | `MeowSystem/.trabalho-icones/svg/Ubuntu.svg` | 2026-09-16 | só no histórico do git |
| v1.svg | `f60afccd` | `transcricoes/tmp__claude-1000__-home-andrefarias-Desenvolvimento-Migra--o-OS__55ef96a5-bdea-42fb-b76f-0f3fd384396e__scratchpad__v1.svg` | `scratchpad da sessão 55ef96a5/v1.svg` | 2026-09-16 | não, só o recuperado |
| v2.svg | `e6078ad5` | `transcricoes/tmp__claude-1000__-home-andrefarias-Desenvolvimento-Migra--o-OS__55ef96a5-bdea-42fb-b76f-0f3fd384396e__scratchpad__v2.svg` | `scratchpad da sessão 55ef96a5/v2.svg` | 2026-09-16 | não, só o recuperado |
| v4.svg | `97d7a84e` | `transcricoes/tmp__claude-1000__-home-andrefarias-Desenvolvimento-Migra--o-OS__55ef96a5-bdea-42fb-b76f-0f3fd384396e__scratchpad__v4.svg` | `scratchpad da sessão 55ef96a5/v4.svg` | 2026-09-16 | não, só o recuperado |
| v5.svg | `da2d2b7c` | `transcricoes/tmp__claude-1000__-home-andrefarias-Desenvolvimento-Migra--o-OS__55ef96a5-bdea-42fb-b76f-0f3fd384396e__scratchpad__v5.svg` | `scratchpad da sessão 55ef96a5/v5.svg` | 2026-09-16 | não, só o recuperado |

**Leitura:**
- Morcego-dia, morcego-noite e mozc têm a versão final no disco (`.trabalho-icones/svg/`, `assets/gatos/` e `assets/icones/resgatados/mozc.svg`). Só os rascunhos intermediários dependem da recuperação.
- Os 8 folder-templates são uma linha de desenho (pasta com folhas e esquadro) diferente da pasta que está no pack.
- Os candidatos do Syncthing foram descartados na época: o pack usa `apps/syncthing.svg`, e `v6` é a versão que ficou (está em (b), com RMSE 0,055).

## (b) Versão editada de algo do MeowSystem

| par no MeowSystem | situação do par | versões recuperadas: sha256 → arquivo (RMSE a 64 px) |
|---|---|---|
| `MeowSystem/assets/icones/resgatados/guvcview.svg` | acervo do motor (`assets/icones`), fora do pack | `e0b673dd` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__guvcview.v1.svg` (0.098) |
| `MeowSystem/assets/icones/resgatados/io.github.cosmic_utils.camera.svg` | acervo do motor (`assets/icones`), fora do pack | `b2476fd7` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__guvcview.v3.svg` (0.005)<br>`d532327e` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__guvcview.v2.svg` (0.021) |
| `MeowSystem/assets/icones/resgatados/md.obsidian.Obsidian.svg` | acervo do motor (`assets/icones`), fora do pack | `9241b079` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__md.obsidian.Obsidian.v1.svg` (0.105) |
| `MeowSystem/assets/icones/resgatados/org.telegram.desktop.svg` | acervo do motor (`assets/icones`), fora do pack | `01355a3c` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__org.telegram.desktop.v2.svg` (0.013)<br>`d3bf4309` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__org.telegram.desktop.v1.svg` (0.045) |
| `MeowSystem/assets/icones/resgatados/setup-mozc.svg` | acervo do motor (`assets/icones`), fora do pack | `0aed9251` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__mozc.v1.svg` (0.061) |
| `MeowSystem/assets/icones/resgatados/uad-ng.svg` | acervo do motor (`assets/icones`), fora do pack | `6044a71c` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__uad-ng.v3.svg` (0.015) |
| `MeowSystem/assets/icones/resgatados/Ubuntu-selfservice.svg` | acervo do motor (`assets/icones`), fora do pack | `8e330d76` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__Ubuntu-selfservice.v3.svg` (0.054) |
| `MeowSystem/assets/icones/resgatados/Ubuntu.svg` | acervo do motor (`assets/icones`), fora do pack | `29290ae6` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__Ubuntu.v2.svg` (0.030) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/Antigravity.svg` | final só em `sprint/p84` | `2e5e1765` → `photorec-filtrado/2e5e1765fd85c744.svg` (0.005)<br>`c58e0450` → `photorec-filtrado/c58e0450c1abb975.svg` (0.040)<br>`bd0f8d4a` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__Antigravity.svg` (0.053)<br>`4ce30f04` → `photorec-filtrado/4ce30f048918ab76.svg` (0.053) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/box-buddy.svg` | final só em `sprint/p84` | `1cff9afc` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__box-buddy.svg` (0.059) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/calculadora.svg` | final só em `sprint/p84` | `9511bd3a` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__calculadora.svg` (0.046) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/calendario.svg` | final só em `sprint/p84` | `4a3b8629` → `photorec-filtrado/4a3b862997a6ea55.svg` (0.006)<br>`3f076cdb` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__calendario.svg` (0.016) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/camera.svg` | final só em `sprint/p84` | `a3d2b0e8` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__camera.svg` (0.081) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/cheese.svg` | final só em `sprint/p84` | `3d94b2aa` → `photorec-filtrado/3d94b2aa1c76777a.svg` (0.071) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/citrix.svg` | final só em `sprint/p84` | `fc2f6b3e` → `photorec-filtrado/fc2f6b3e7901f53a.svg` (0.009)<br>`b97baf04` → `photorec-filtrado/b97baf048668e529.svg` (0.018)<br>`20f9a3b6` → `photorec-filtrado/20f9a3b6f4832624.svg` (0.035)<br>`027f8d61` → `photorec-filtrado/027f8d61ccf88e47.svg` (0.042)<br>`8177d560` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__citrix.svg` (0.074) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/clapper.svg` | final só em `sprint/p84` | `6865c2a1` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__clapper.svg` (0.071)<br>`dceddbba` → `photorec-filtrado/dceddbbaf9304797.png` (0.084)<br>`38cdb6ef` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__clapper.v1.svg` (0.121) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/Clapper.svg` | final só em `sprint/p84` | `3c742902` → `photorec-filtrado/3c742902f381a61b.svg` (0.023) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/Easy-Effects.svg` | final só em `sprint/p84` | `65d1c98b` → `photorec-filtrado/65d1c98be3d7ef8a.svg` (0.094)<br>`3f11f955` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__Easy-Effects.svg` (0.098) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/edge.svg` | final só em `sprint/p84` | `95f4c1ae` → `photorec-filtrado/95f4c1ae503827d0.svg` (0.120)<br>`40d9da03` → `photorec-filtrado/40d9da03919ce51c.svg` (0.126)<br>`97dd6102` → `photorec-filtrado/97dd610285838cf7.svg` (0.127)<br>`f8983a4b` → `photorec-filtrado/f8983a4bc7c1b01d.svg` (0.130) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/firefox.svg` | final só em `sprint/p84` | `26774464` → `transcricoes/Desenvolvimento__MeowSystem__firefox.svg` (0.032)<br>`5d7b0507` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__firefox.svg` (0.134)<br>`a4f7b7f3` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__firefox.v1.svg` (0.160) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/flatseal.svg` | final só em `sprint/p84` | `0eb4e8c0` → `photorec-filtrado/0eb4e8c024abf820.svg` (0.060) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/gerenciador-de-extensoes.svg` | final só em `sprint/p84` | `bb2108a4` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__gerenciador-de-extensoes.svg` (0.038) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/gerenciador-de-menu.svg` | final só em `sprint/p84` | `3e33139a` → `photorec-filtrado/3e33139a27b3a4f1.svg` (0.055)<br>`709d72cc` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__gerenciador-de-menu.svg` (0.056) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/gimp-48.svg` | final só em `sprint/p84` | `c39b4a81` → `photorec-filtrado/c39b4a812c3a0be6.svg` (0.103)<br>`f808f7eb` → `photorec-filtrado/f808f7ebed4f206f.svg` (0.136)<br>`dc239cd9` → `photorec-filtrado/dc239cd9e0157836.svg` (0.137) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/gnome-folder.svg` | final só em `sprint/p84` | `ef14a266` → `photorec-filtrado/ef14a266178337f8.svg` (0.047)<br>`661ade63` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__gnome-folder.svg` (0.047) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/gparted.svg` | final só em `sprint/p84` | `003eb1cb` → `photorec-filtrado/003eb1cbf2e625f0.svg` (0.111) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/Heroic-Games-Launcher.svg` | final só em `sprint/p84` | `bd08927b` → `photorec-filtrado/bd08927b84df581b.svg` (0.079)<br>`d0d9f8fb` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__Heroic-Games-Launcher.svg` (0.116)<br>`a0a64679` → `photorec-filtrado/a0a64679cd9ea103.svg` (0.150) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/linux-toys.svg` | final só em `sprint/p84` | `bb42457c` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__linux-toys.svg` (0.071)<br>`1220ea87` → `photorec-filtrado/1220ea878541632e.svg` (0.076) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/opera.svg` | final só em `sprint/p84` | `5168676f` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__opera.svg` (0.109) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/spotify.svg` | final só em `sprint/p84` | `969803d4` → `photorec-filtrado/969803d476c00b4a.svg` (0.038) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/visalizador-de-imagens.svg` | final só em `sprint/p84` | `af8d75ec` → `photorec-filtrado/af8d75ecb9f4ff48.svg` (0.064)<br>`c1283da0` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__visalizador-de-imagens.svg` (0.064) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/vscode.svg` | final só em `sprint/p84` | `c7cb1a82` → `photorec-filtrado/c7cb1a82cbdaad87.svg` (0.026) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/warehouse.svg` | final só em `sprint/p84` | `da76a8f4` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__warehouse.svg` (0.005) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/weylus.svg` | final só em `sprint/p84` | `f9c3d4ef` → `transcricoes/Desenvolvimento__MeowSystem__weylus.svg` (0.033)<br>`3f546552` → `photorec-filtrado/3f546552e35f3248.svg` (0.078)<br>`dc947d0a` → `transcricoes/Desenvolvimento__.wt-meow__p84__packs__dracula__icones__feitos-a-mao__weylus.svg` (0.079) |
| `.wt-meow/p84/packs/dracula/icones/feitos-a-mao/whatsapp.svg` | final só em `sprint/p84` | `59d453f9` → `photorec-filtrado/59d453f921a81f95.svg` (0.044) |
| `MeowSystem/packs/dracula/icones/biblioteca/bat.svg` | no pack Dracula (dev) | `39f3b787` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__morcego.svg` (0.016) |
| `MeowSystem/packs/dracula/icones/feitos-a-mao/citrix.png` | no pack Dracula (dev) | `3f47eb73` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__Ubuntu-selfservice.v1.svg` (0.030) |
| `MeowSystem/packs/dracula/icones/pastas/folder-documents.svg` | no pack Dracula (dev) | `28d9edb1` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-documents.v2.svg` (0.030)<br>`26695ad1` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-documents.svg` (0.030)<br>`970e8556` → `photorec-filtrado/970e8556dff2bc0b.png` (0.035)<br>`fc464e56` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-documents.v1.svg` (0.072) |
| `MeowSystem/packs/dracula/icones/pastas/folder-music.svg` | no pack Dracula (dev) | `52dd06f7` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-music.v3.svg` (0.031)<br>`cdaa6037` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-music.svg` (0.031)<br>`6a171719` → `photorec-filtrado/6a171719cf28c973.png` (0.034)<br>`52d9f314` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-music.v2.svg` (0.038)<br>`7a12b0c4` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-music.v1.svg` (0.063) |
| `MeowSystem/packs/dracula/icones/pastas/folder-pictures.svg` | no pack Dracula (dev) | `9f2d6183` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-pictures.v2.svg` (0.031)<br>`f5c06c29` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-pictures.svg` (0.031)<br>`45d486e2` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-pictures.v1.svg` (0.062) |
| `MeowSystem/packs/dracula/icones/pastas/folder-publicshare.svg` | no pack Dracula (dev) | `bfb22ec6` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-publicshare.svg` (0.030)<br>`64481353` → `photorec-filtrado/64481353fbf9c869.png` (0.035)<br>`45ba9830` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-publicshare.v1.svg` (0.067) |
| `MeowSystem/packs/dracula/icones/pastas/folder-templates.svg` | no pack Dracula (dev) | `2e768d2f` → `photorec-filtrado/2e768d2f319631e3.png` (0.034) |
| `MeowSystem/packs/dracula/icones/pastas/folder-videos.svg` | no pack Dracula (dev) | `ba14a88b` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-videos.svg` (0.031)<br>`f9b319c9` → `photorec-filtrado/f9b319c9e5b99e01.png` (0.035) |
| `MeowSystem/packs/dracula/icones/feitos-a-mao/gnome-folder.png` | no pack Dracula (dev) | `d596f397` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__org.gnome.Nautilus.svg` (0.012)<br>`d2d688a8` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-download.v1.svg` (0.089)<br>`efcc83e5` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-download.v2.svg` (0.090)<br>`77121548` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__pastas__folder-download.svg` (0.090)<br>`87fbee11` → `photorec-filtrado/87fbee118a349257.png` (0.091) |
| `MeowSystem/packs/dracula/icones/apps/syncthing.svg` | no pack Dracula (dev) | `d1b5ada1` → `transcricoes/Desenvolvimento__MeowSystem__.trabalho-icones__svg__syncthing.v1.svg` (0.050)<br>`3998772d` → `transcricoes/tmp__claude-1000__-home-andrefarias-Desenvolvimento-Migra--o-OS__55ef96a5-bdea-42fb-b76f-0f3fd384396e__scratchpad__v6.svg` (0.055) |

**Leitura:**
- Nas linhas com a situação «final só em `sprint/p84`», a versão boa não está perdida. Ela está no worktree `.wt-meow/p84`, mas não chegou ao `dev`.
- Os rascunhos recuperados são etapas anteriores do mesmo desenho, feitas hoje. Servem só para comparar.
- As pastas (documents, download, music, pictures, publicshare, videos e o render dos templates) são as versões de 16/09 que o commit `542b1e1` (P61) trocou no pack.

## O que não deu para recuperar

1. **Nomes e datas dos 307 arquivos do photorec.** O photorec não guarda metadados. A identificação veio do conteúdo: o comentário do SVG e a semelhança com o pack.
2. **Arquivos apagados há mais tempo, com nome.** O ext4magic termina com falha de memória neste ext4 com `metadata_csum`. Além disso, o diário só cobria a partir das 19h25 de hoje.
3. **Espaço livre da partição `/`, onde ficam `/tmp` e `/var/tmp`.** Os scratchpads das sessões antigas (como o de 16/09 do Migração-OS, de onde saíram os candidatos do Syncthing) ficavam em `/tmp`, que é ext4 em `/dev/nvme1n1p2`. Essa partição não passou pelo photorec. A saída da própria recuperação (cerca de 806 MB em `/var/tmp/meow-recup/photorec/`) foi gravada nela, o que já reduziu a chance. Para tentar, a saída teria de ir para um terceiro disco.
4. **SVGs gerados por scripts Python dentro de comandos Bash** (57 scripts, 32 deles de hoje). Para reconstruir, seria preciso executá-los.
5. **Leituras parciais de SVG nas transcrições** (feitas com offset ou limit) ficaram de fora.
6. **`~/Remotos/Andromeda-OS`**, o PC da Vitória via sshfs, recusou a leitura com «Operação não permitida». A lixeira e as transcrições de lá não foram vistas.

## Estado dos discos

- Nada foi montado nesta etapa. O Apate (`/dev/nvme0n1p3`) não está montado, e `findmnt /mnt/Apate` volta vazio.
- No `/home`, esta etapa escreveu só as folhas de contato pedidas (6 PNG em `.playwright-mcp/ux-svg/`) e este arquivo.

## Próximo passo

Decidir se os 39 SVG da P84 (`sprint/p84`) e as pastas de 16/09 voltam para o `dev`. Esse é o conteúdo que falta no pack.

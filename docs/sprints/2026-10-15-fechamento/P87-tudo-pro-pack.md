# P87 — Tudo o que foi achado e recuperado entra no pack Dracula

**Branch:** `sprint/p87` (DEPOIS da P88: já no formato de três pastas) · **Pedido (15/10):** «tô sentindo falta de vários SVGs que fizemos no PC ou
editamos»; «pode estar na lixeira, pode ter sido excluído, tente recuperar»; «Joga tudo pro pack».
**Fontes:** `docs/pesquisas/2026-10-15-svgs-faltando.md`, `docs/pesquisas/2026-10-15-svgs-recuperados.md`,
os `.tsv` da varredura e da recuperação (`/var/tmp/meow-recup/`, scratchpad `svgs/`), decisão 13.

## Tarefas
1. Classes a (nossos) e b (versões editadas — TODAS as versões) e c (terceiros com licença conhecida)
   entram em `packs/dracula/icones/` numa das três pastas da decisão 14: `apps/` se vestem um programa
   (com a linha no `apps.map`), `sistema/` se são pasta/mimetype/status, `biblioteca/` para todo o resto
   (versões antigas e recuperados inclusive — a origem fica no PROCEDENCIA, não numa pasta nova),
   nomes sem colisão, SVG limpo (sem metadado de editor, sem `<script>`, sem referência externa —
   regra de pack da P78), sha256 e origem (caminho, data, fonte: lixeira/Apate/VS Code/transcrição/
   ext4magic/photorec) no `PROCEDENCIA.md`.
2. Fora: lixo/rascunho quebrado e projeto pessoal (decisão 13). Listar no fim da spec com o motivo.
3. Os que hoje vestem um app e foram perdidos voltam ao `apps.map` (ligação recuperada da transcrição
   ou do tema instalado antigo), sem tirar a escolha atual de quem usa sem prova de que era a dela.
4. O seletor (P73/P80) mostra a pasta nova com contagem; `tests/acervo-da-ficha.sh` cobre a pasta.

## Prova
- conta por sha256: achados (a+b+c) − no pack = 0; `tests/pack-malicioso.sh`, `tests/pack.sh`,
  `tests/acervo-da-ficha.sh`, `tests/fonte-unica.sh` verdes; folha de contato do que entrou.

## Entra também (varredura geral de 15/10, decisão 16)
Fonte: `docs/pesquisas/2026-10-15-svgs-faltando.md` e `consolidado-ab.tsv`.
1. Os 19 desenhos Dracula do motor (uad-ng, Ubuntu, Citrix, câmera do COSMIC, mozc, setup-mozc,
   Obsidian, Telegram, Thunderbird, scrcpy, morcego-noite, morcego-dia, Clapper, Edge, Nautilus, WhatsApp,
   PhotoGIMP, Waterfox, hplj1020 em 256 px) → `packs/dracula/icones/` (apps/ se ligados, biblioteca/ se não).
2. Projetos dela fora da lista (Hefesto, Sigilo, Luna, PDForge…) e `aurora-iniciar` → `biblioteca/`.
3. Versões: todas na `biblioteca/`; a ligada segue o item (3)–(5) da decisão 16.
4. As 33 ligações perdidas na P37 voltam ao `apps.map`; as 7 trocadas voltam ao desenho original.
5. A recuperação (`2026-10-15-svgs-recuperados.md`): os 39 «nossos» e as 90 versões entram na
   `biblioteca/`; os 9 de terceiros só com licença conferida (Papirus GPL sim; marcas registradas como
   ativos do Grok: fora, com o motivo).

## Resultado (16/10/2026)
**Entraram 185 arquivos em `packs/dracula/icones/`**, todos com linha no `packs/dracula/PROCEDENCIA.md` (origem, fonte,
licença, sha256) e passados pela regra de pack da P78 (15 mudaram: 13 PNG sem `tEXt`/`tIME`, 2 SVG sem comentário de
gerador e sem atributos `bx:`; nenhum recusado):

| pasta | arquivos | classe |
|---|---|---|
| `apps/` | 1 | b: o vetor de 12/09 do Citrix (veste os 11 nomes) |
| `biblioteca/` | 5 | a ×3 (morcego-noite, morcego-dia, aurora-iniciar), b ×1 (morcego), c ×1 (Obsidian do Papirus, GPL-3.0) |
| `biblioteca/versoes/` | 144 (132 SVG, 12 PNG) | a ×44, b ×100: `<desenho>-<sha8>`, e o rótulo mora no `catalog.json` |
| `biblioteca/projetos/` | 35 (18 SVG, 17 PNG) | d: Hefesto, FogStripper, PDForge, Sigilo, Detector de Doppelgänger, ArcaneTab, Mnemo, Neurosonancy, Luna, Crononauta, Êxtase |

Os 19 desenhos do motor: 16 já estavam em `apps/resgatados/` (P88), e os 3 morcegos entram agora em `biblioteca/`
(o motor continua com os dele em `assets/gatos/`, que é o logo do COSMIC).

**Ligações (`apps.map`, +42 linhas):** os 5 nomes `?` (uad-ng, Citrix, Clapper, Edge, WhatsApp); os 5 resgatados que o
tema já vestia (Ubuntu, Thunderbird ESR, scrcpy, PhotoGIMP, Nautilus); as 33 perdidas na P37 (Discord, Spotify, Opera ×2,
Gradia ×2, Citrix ×11, Extensões ×3, shell ×6, markdown ×5, `.desktop` ×2); e as duas trocas desfeitas
(`io.elementary.appcenter`, `org.gnome.gThumb`). Dos «7» que o relatório contou, só estes dois mudavam de desenho de fato:
os outros cinco (`menu-editor`, `menulibre`, `onlyoffice` ×2, `stacer`) apontam para o mesmo desenho (bytes iguais ou a
mesma `fonte` do `mapping.json`).

**Ficou fora, com o motivo:**
1. 2 PNG do logo do Discord (photorec): marca registrada, sem licença conferida.
2. 4 ativos do Grok (plus, glass-share, glass-puzzle, logo): marca e arte de plataforma, sem licença.
3. 2 desenhos do BeautyFolders (alacritty-simple, thunar): tema de terceiro numa partição que não está montada, licença não conferida.
4. 8 de projeto pessoal da lista de exclusão (Ouroboros ×6, workspace Grok «construindo visão» ×2): decisão 13.
5. 8 lixo (fixtures de teste, o `xss.svg` do `pack-malicioso`, renders vazios): decisão 13.
6. Da varredura: 26.740 de terceiros (os que já estão no motor ou no sistema, SDK do Android, apps web, marcas sem prova)
   e 4.622 de rascunho, render, tamanho menor ou versão antiga já dentro do MeowSystem: nenhum é desenho que se perdeu.
7. Dos projetos dela: as telas (SVG de 0,3 a 1,4 MB), as dezenas de glifos de interface e os desenhos de controle do Hefesto, os
   favicons de site e os tamanhos de 16 a 96 px do mesmo ícone. Entrou o desenho de cada projeto, não o material dele.
8. `calcdeirao`: Caldeirão, lista de exclusão (decisão 4).

**Para quem usa decidir (não mexi):**
1. **Beholder, Elden Ring Tracker e Ouroboros já estão em `apps/resgatados/`** (desde antes da P88) e saem no `meow pack
   exportar`. A decisão 13 os manda para fora do pack; tirá-los muda o tema desta casa (o `.desktop` cairia no ícone do
   próprio app), então a P87 não os tocou.
2. **Hefesto e FogStripper**: a decisão 16 (P82) os tirou dos *autorais* dos packs; a 16 (item 2) desta leva põe o desenho
   achado em `biblioteca/projetos/`. Valeu a mais nova, e é um `git rm` se for o contrário.
3. **Citrix**: segui a decisão 16 (item 3, «Citrix de 12/09») e o `Ubuntu-selfservice` passou do monitor de 15/09 para o
   vetor de 12/09 (0,030 contra o PNG, 0,227 do monitor). O monitor continua em `apps/resgatados/` e é uma linha do mapa.
4. **Os tipos de arquivo (13) entraram no `apps.map`** e caem em `scalable/apps/`, antes de `scalable/mimetypes/` na
   ordem de busca (`construir_icones.sh`). A ordem está escrita no código, mas não foi provada no COSMIC.
5. **Ainda sem ligação**: os 10 tipos de vídeo (o tema antigo vestia o Clapper) e os 24 `org.kde.krita.*` (decisão 35).

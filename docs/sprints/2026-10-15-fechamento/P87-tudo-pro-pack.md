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

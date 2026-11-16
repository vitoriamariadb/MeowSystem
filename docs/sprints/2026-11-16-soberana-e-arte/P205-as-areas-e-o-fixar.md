# P205 — só as áreas fixadas: o pedaço do patch que não entrou no build (16/11/2026)

Texto de quem usa: «pq eu tenho 4 workspaces? pq não consigo clicar em fixar?» e «o fixar é pra evitarmos criar
infinitas areas de trabalho. era pra ser duas que eu deixasse lá. Mas agora temos o pop os 3 e o 4 sendo que deveriam
ser so as duas primeiras.»

## O que se mediu (16/11, nitro-5)
- Barra: Pop · OS · 3 · 4; `pinned_workspaces` só tem Pop e OS; `AREAS_MODO="juntas"` (Global), duas telas.
- O binário em uso (`~/.local/libexec/meow/cosmic-comp/0.1~1793802426~24.04~ec674cd`, build de 07/11) tem o marcador
  `AURORA-COSMIC-WS-PATCH-3.67`, mas a árvore que o gerou (`~/.cache/meowsystem/cosmic-comp/cosmic-comp-<ver>`) ficou sem
  o hunk 4 do `cosmic-comp-sem-workspace-vazio.patch`: o `refresh` do modo Global ainda tem o upstream
  `.any(|w| !w.is_empty() || w.pinned)`, que acrescenta uma área vazia depois da última fixada. Com janela nela, nasce
  outra. `patch -R --dry-run` na árvore: «Hunk #4 FAILED».
- Do fonte puro (`dpkg-source -x` do .dsc em `~/.local/share/meowsystem/fontes/cosmic-comp/`), a série inteira aplica e o
  `refresh` sai certo. O defeito é da árvore em cache, não do patch.
- `scripts/compositor_patches.sh` `_cp_ja_aplicado` decide «já está na árvore» (`ja`) só pelo marcador; por isso o build
  de 07/11 seguiu com o hunk faltando, calado.
- «Fixar a primeira área» desligado com dica: é do tipo `feito` (já há área fixada) — tratado na P204.

## A cura na origem
- `_cp_ja_aplicado`: «já aplicado» só quando o `patch -R --dry-run` passa (todos os hunks presentes). Marcador presente
  com hunk faltando = árvore velha: refaz a árvore do fonte puro antes de aplicar a série.
- Rebuild do compositor (`meow compositor`, pelo coordenador) e conferência: o `refresh` da árvore nova tem
  `any(|set| set.workspaces.is_empty())`. Vale no próximo login.

## Como se prova
- Teste novo em `tests/` (padrão do `tests/patch-que-sobe.sh`): árvore falsa com o marcador e um hunk faltando → o
  estado não é `ja`; árvore com todos os hunks → `ja`.
- Depois do próximo login: a barra mostra só Pop e OS.

# P123 — a pasta local enxuta: cada sobra no seu destino

Item 12 do pedido. Leia `relatorios/levantamento-extensoes.md`, seção 5 (a tabela é a lista
fechada). Trabalho mecânico: um script de uma vez, rodado com o sim dela, mais um agente que
confere.

## O que se mediu
- `git status --porcelain --ignored`: 139 linhas; 44 entradas não rastreadas.
- Os grandes: `src/applets/` 1,5 GB (só `leitura/target`), `assets/papeis-de-parede/` 321 MB,
  `assets/icones/catppuccin-apps/` 205 MB, `assets/icones/upstream/` 95 MB, `.playwright-mcp/`
  92 MB, `.trabalho-icones/` 24 MB, `MeowSystem-master.zip` 12 MB.
- O fundo de tela vivo dela lê `assets/papeis-de-parede/ativos-dia` (as três configs de
  `~/.config/cosmic/com.system76.CosmicBackground/v1/`), e o `meow.conf` tem `WALLPAPER_BASE` no
  repo. 339 das 340 imagens não têm cópia fora dele.
- Fora do repo: `~/.local/state/meowsystem/midia` 1,6 GB e `leitura` 1,5 GB (árvores de build da
  era antiga), `~/Desenvolvimento/cosmic-comp-patch` 3,3 GB (build da Aurora).

## Causa
Sobras de levas antigas (applets no repo, ícones gerados no repo, acervo de papel de parede antes
do pack) que nenhuma etapa limpou, e um caminho do fundo de tela gravado para dentro do repo.

## Cura na origem
1. Papéis de parede: o doctor ganha o conserto «a base do papel de parede mora dentro do repo» →
   move a pasta para `~/.local/share/backgrounds/meowsystem` (o padrão do `scripts/wallpaper.sh`),
   reescreve `WALLPAPER_BASE` e o `source` das configs do CosmicBackground. Nenhuma imagem é
   apagada.
2. Um script de uma vez (`scripts/enxugar.sh`, roda e sai do repo no mesmo commit, ou fica em
   `docs/sprints/` como roteiro) que aplica a tabela: apagar o que é cache ou sobra, levar para a
   branch `arquivo` o que é registro (`docs/folhas`, `docs/pesquisas`, os mapas e ícones antigos que
   não estão em `packs/meowsystem/icones/`), mover para o pack o que é arte do pack. Antes de apagar,
   lista e tamanho no terminal; nada roda sem o sim dela.
3. `tests/arvore.sh` ganha a regra: nada em `src/applets/`, nada em `assets/papeis-de-parede/`,
   nenhum `*.zip` na raiz, e o doctor diverge se `WALLPAPER_BASE` estiver dentro do repo.
4. `~/.local/state/meowsystem/{midia,leitura}`: o conserto do doctor que já limpa estado antigo
   passa a apagá-los. `cosmic-comp-patch` só sai depois da P121.

## Prova
- `tests/arvore.sh` verde com as regras novas.
- Teste do conserto do papel de parede num HOME de brinquedo: base dentro do repo → movida, config
  reescrita, contagem de imagens igual antes e depois, segunda passada não escreve.
- `du -sh` do repo antes e depois, no fecho do bloco.

## Arquivos
`scripts/wallpaper.sh` (só o conserto da base), `bin/meow` (o check/fix novo), `tests/arvore.sh`,
um teste novo `tests/wallpaper-base.sh`, `.gitignore`. Os caminhos não rastreados da tabela.

## Fora desta sprint
Redesenhar a curadoria dos papéis de parede, `assets/apps/jogos-fora.map` (decisão dela), o gerador
de ícone, qualquer coisa em `packs/`.

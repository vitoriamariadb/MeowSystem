# Conferência do bloco pasta (P123), 27/10/2026

Conferido `integracao/central-e-gerador..bloco/pasta` (659507f5 a 6398e1fa) na árvore `MeowSystem-pasta`. O checkout
principal só foi lido: o ensaio do `enxugar.sh` sem `--aplicar` rodou nele duas vezes, com `find -newer` e as refs
antes e depois iguais (zero arquivo escrito). Nenhuma tela do painel foi tocada pelo bloco (nada em `app/`), então
não houve tela a comparar com as fotos ou a maquete.

## Achados e correções

| # | achado | correção | commit | prova |
|---|---|---|---|---|
| 1 | O `enxugar.sh` mandava apagar imagens dela: `Imagem colada.png` (print da tela dela, 26/10), `aba7.png`, `docs/capturas/spotify.jpg` (print do Spotify dela) e `.trabalho-icones`, cujo `origem/` guarda 25 PNG que ela desenhou à mão (o `BRIEFING.md` diz que os SVG originais se perderam); nenhum dos 25 tem cópia rastreada no repo. Fere a decisão «o que é dela (imagens) só se move». | As quatro linhas passam de `apagar` para `arquivar`. | ba773264 | `tests/enxugar.sh` seção 0: nenhuma imagem solta, nada de `packs/` nem o `jogos-fora.map` em `apagar`, `.trabalho-icones` em `arquivar`; com a tabela antiga a seção falha e cita os quatro caminhos. |
| 2 | A «conferência arquivo a arquivo» só contava arquivos (`find` contra `diff --cached`); um arquivo que chegasse diferente à branch passava e a origem era apagada. | Cada arquivo é comparado pelo blob (`hash-object --no-filters` contra `ls-files -s` do índice da branch) antes de qualquer apagar. | ba773264 | `tests/enxugar.sh` 4b: um filtro de limpeza muda o conteúdo no caminho; o script recusa (rc 1), nada de registro sai e a branch não ganha commit. |
| 3 | Numa segunda leva (uma sobra que volta, ou um apagar que falhou depois do commit) o `git add -- levas/...` registrava como removido tudo o que a primeira leva guardou, porque a worktree é `--no-checkout`: a ponta da branch perdia o registro, e o `LEIA-ME.md` era reescrito só com os caminhos novos. A repetição igual também quebrava (commit vazio, rc 1, nada apagado para sempre). | `git add --ignore-removal`; o `LEIA-ME.md` é lido da branch e só ganha linha; sem nada novo no índice, não há commit e a sobra sai. | ba773264 | `tests/enxugar.sh` 4c: repetido igual sai sem commit (rc 0); a leva nova faz um commit, o `LEIA-ME` guarda os caminhos das duas levas e a imagem da primeira continua na ponta. Sem `--ignore-removal` a seção falha (2 commits). |
| 4 | O caso dela no `basefundo` (o `WALLPAPER_BASE`, o atalho `~/.local/share/backgrounds/meowsystem` e as três configs do CosmicBackground citam o repo por `/mnt/Apate/Desenvolvimento`, que é atalho para `~/Desenvolvimento`) não tinha teste; o código já cobria. | Teste novo. | c13cc28d | `tests/wallpaper-base.sh` seção 8: tudo volta para a pasta padrão, com as 13 imagens, as três configs reescritas sem o caminho do atalho, e a segunda conferência passa. |

## O que se conferiu e ficou como estava

- `basefundo`: cura na origem (o caminho do fundo sai do repo; nenhuma imagem é apagada); conflito no destino recusa
  com a origem intacta; o doctor reconfere tudo depois do conserto (`rodar_checks`), para `wallpaper` e `fundo` já
  verem a base nova. Na máquina dela `~/Desenvolvimento` e `~/.local/share` estão no mesmo disco: o `mv` é renomear.
- `estadovelho`: `midia/` e `leitura/` do estado só guardam `carimbo`, `compilar.log`, `src` e `target`; nenhum código
  de hoje os lê (o `lib/desinstalar.sh` já os apaga sem backup). `leitura.log` fica.
- `tests/arvore.sh`: a regra `sobras` e a do doctor dentro/fora passam no ensaio e acusam o clone cheio.
- `enxugar.sh` contra a pasta dela hoje (só leitura): cada linha tem destino (apagar, arquivo, doctor, fica); 1,8 GB a
  apagar, 79,8 MB para a branch `arquivo`, 319,4 MB de papéis de parede para o doctor. Todo `??` do `git status` dela
  está na tabela, menos `assets/apps/jogos-fora.map` (dela). Nada de `packs/` é apagado. Ignorados que ficam: a fonte
  `assets/fontes/locais/zrnic rg.otf`, os `.ron` gerados, as capturas e fotos desta leva, `.claude/`.
- Ensaio do `--aplicar` com dados de verdade: clone do `dev` em pasta temporária, com as sobras dela copiadas (menos
  `src/applets`, o acervo e o `catppuccin-apps`), com a configuração global real do git (ganchos em
  `~/.config/git/hooks`, filtro LFS): rc 0, um commit na branch `arquivo`, 1550 arquivos todos iguais byte a byte ao
  original (sha256), `dev` intacto, nenhuma worktree sobrando, `git status --ignored` limpo.

## Suíte

Ver o fim deste relatório.

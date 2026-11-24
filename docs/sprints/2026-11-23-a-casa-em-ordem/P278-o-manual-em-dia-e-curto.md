# P278 — o manual em dia e curto (23/11/2026)

## O que se mediu (catálogo de 23/11)
- `docs/PACKS.md` (2499 linhas, 124 KB) está errado em quatro pontos: `:327-331` diz que `scripts/temas-de-apps/`
  guarda temas baixados (estão em `packs/*/temas-de-apps/*/upstream`); `:1250` usa um caminho `apps/` que não existe;
  `:302` põe `packs/meowsystem/mascote/` na coluna de `assets/`; `:2103` diz que nenhum executável é lido de um pack.
- `docs/COSMIC-THEMING.md` (851 linhas) cita `assets/icones/sistema-retoques/LEIA-ME.txt`,
  `assets/paleta/catppuccin.json` e `assets/meow-symbolic.svg`, que não existem. O único leitor é uma mensagem do
  `gerar_tema_v1.py:317`.
- `meow.conf.exemplo` cita `assets/paleta/catppuccin.json` quatro vezes; `packs/meowsystem/PROCEDENCIA.md:380` dá a
  folha num caminho que não existe; `kitty.modelo.conf:4` cita `packs/<pack>/apps/`.
- `packs/dracula/PROCEDENCIA.md` tem 1506 linhas e 302 KB, em tabela.
- Não há lista do que uma ferramenta de leitura deve pular; o `AGENTS.md` só cita `docs/sprints/`, os ícones e as
  capturas.

## A causa
Documento escrito junto com a mudança e não revisto quando a mudança seguinte moveu o caminho.

## A cura na origem
1. Corrigir no lugar os pontos de cima, depois de a P274 e a P275 fecharem (eles mudam o que o manual diz).
2. `docs/COSMIC-THEMING.md`: fica o que o código ainda usa como referência; o relato de medição antigo sai.
3. A lista do que não ler do `AGENTS.md` anda antes, na P287. Aqui o `AGENTS.md` só ganha o mapa da árvore final.
4. Um teste cobra que todo caminho do repositório citado em `docs/*.md`, no `README` e no `AGENTS.md` exista.

## Como se prova
- O teste novo vermelho antes (com os caminhos de cima) e verde depois.
- `tests/numeros.sh`, `tests/readme.sh` e `tests/arvore.sh` verdes.

## Feito em parte (23/11, bloco `manual`, integrado em `959f41e1`)
- `tests/caminhos-do-manual.sh`: todo caminho entre crases em `docs/*.md`, nos `README`, no `AGENTS.md` e no
  `GSD.md` existe na árvore. As raízes vêm do `git ls-files`. Nasceu vermelho com 7 mortos em 241, todos corrigidos.
- `docs/COSMIC-THEMING.md` de 851 para 438 linhas: saíram seis seções de medição que nada cita (som, os seis
  diretórios do painel, o `hicolor` do usuário, a tela de login, notificações caladas, o modo de leitura de 31/08).
- A linha da decisão 24 trocou os três caminhos mortos por texto, sem mudar o que decide.
- Falta: os pontos do `docs/PACKS.md` que o passo 6 muda, o mapa da árvore final no `AGENTS.md`, e o
  `packs/dracula/PROCEDENCIA.md` (310 KB; 89% é a tabela que o `pack.py` lê: tirar pede mudar o leitor).

## O resto, feito em 24/11 (no bloco da árvore final, `1cf0d430`)
- `AGENTS.md` tem o mapa da árvore final: uma linha por pasta, com o que mora e o que não mora nela.
- `docs/PACKS.md`: o exemplo do `meow pack info` conta 19 desenhos no Dracula, e a origem dos papéis diz as duas
  formas (`repo` e `commit` escritos no `pack.json`, ou `repo_do_conf`).
- As frases em que o roteiro trocou o caminho e entortou o sentido voltaram ao texto de antes.
- Segue aberto: `packs/dracula/PROCEDENCIA.md` (310 KB) e o esquema do `meow.conf.exemplo`, que pedem decisão de
  quem usa.

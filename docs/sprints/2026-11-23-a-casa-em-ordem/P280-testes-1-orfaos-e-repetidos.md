# P280 — testes, etapa 1: órfãos e repetidos (23/11/2026)

Quem mexe nos testes é o coordenador, por ordem de quem usa (23/11). As quatro etapas são a P280 até a P283.

## O que se mediu (catálogo de 23/11)
Nenhum arquivo de teste é órfão inteiro. O que está morto são pedaços:

| teste:linha | o que está morto |
| --- | --- |
| `sem-receita-no-log.sh:17` | isenção de uma mensagem que não existe mais |
| `portabilidade.sh:15,16,19` | três isenções que só o próprio teste cita |
| `portabilidade.sh:27` | exclusão de `docs/historico/*` e `docs/SPRINTS.md`, que não existem |
| `frases-velhas.sh:17` | exclusão de cinco caminhos que não existem |
| `app-texto-visivel.py` | medidor: nunca reprova pelo conteúdo |

Nove grupos provam a mesma coisa:

| grupo | fica |
| --- | --- |
| `arvore.sh:66-77` e `wallpaper-base.sh` §1 | `wallpaper-base.sh` |
| `precisa-de-gente.sh` §3-4 e `manter-sem-pendencias.py` | `manter-sem-pendencias.py` |
| `sem-receita-no-log.sh` e `nada-manda-digitar.sh` §1 | `nada-manda-digitar.sh`, com os três padrões que faltam |
| `app-texto-visivel.py` e `app-uso-real.py` | `app-uso-real.py` |
| `sons-do-pack.sh` §2 e `p113-navegador.py` (sons) | `sons-do-pack.sh` |
| `jogos-heroic.sh` e `um-cartao-por-jogo.sh` | um arquivo, dois casos |
| `pack-traz-o-que-usa.sh` §2 e `apps-em-todo-pack.sh:166-195` | `apps-em-todo-pack.sh` |
| `acento`, `claro-do-pack`, `notas-de-funcao`, `variante`, `pack-pessoal-tem-tema`, `icone-e-fonte-no-tema` | um arnês só; as asserções são diferentes e ficam |
| `area-os`, `nomes-nas-duas-telas`, `janela-sem-app-id` | um laço por patch |

## A cura
Um commit por linha das duas tabelas. O teste que sai deixa a asserção que só ele fazia no que fica. O `todos.sh` e
o `tests/decisoes.sh` acompanham no mesmo commit (ele exige 32 testes pelo nome).

## Como se prova
- Antes de apagar, o teste que fica roda vermelho com o defeito que o apagado pegava (um defeito posto à mão na
  árvore de trabalho e desfeito).
- `tests/decisoes.sh` verde depois de cada commit.
- A suíte inteira no fim da etapa, com o número de testes e o tempo anotados no `ESTADO.md`.

## Trava
A decisão 47 pede três testes extraindo `_dracula_pares_do_mapa`; são exatamente três (`fonte-unica`,
`sem-dracula-os-theme`, `pack.sh`). Nenhum dos três entra nesta etapa.

## Feito (23/11, pelo coordenador, branch `bloco/testes-1-2`)
Seis commits, 195 linhas a menos, dois arquivos de teste a menos.

| o quê | o que se fez | o vermelho de prova |
| --- | --- | --- |
| `sem-receita-no-log.sh` | saiu; os três padrões (`curl \| sh`, `git clone`, `apt install`) entraram no `nada-manda-digitar.sh` | cada receita plantada num script reprovou |
| `portabilidade.sh` e `frases-velhas.sh` | saíram as três isenções e as seis exclusões de caminho que ninguém cita | um caminho pessoal plantado reprovou |
| `app-texto-visivel.py` | saiu: era medidor | não se aplica |
| `arvore.sh` | saiu a conferência da base dos papéis, que o `wallpaper-base.sh` prova | a frase trocada no `wallpaper.sh` reprovou |
| `precisa-de-gente.sh` §3 e §4 | saíram; fica o `manter-sem-pendencias.py`, que olha a tela | um título «Pendências» plantado no Manter reprovou |
| `pack-traz-o-que-usa.sh` §2 | saiu; o `apps-em-todo-pack.sh` ganhou a prova de que o Spotify do pack não tem origem de rede | — |

Não era repetição, e ficou:
- `sons-do-pack.sh` §2 prova o script; o `p113-navegador.py` prova o caminho pela tela (barra, botão, arquivo,
  recarregar). São camadas diferentes.
- `jogos-heroic.sh` e `um-cartao-por-jogo.sh` provam dois scripts diferentes (Heroic e Steam).

Fica para a P283, por ser só troca de arquivo: os dois dos jogos num arquivo, o arnês único dos seis testes de tema
e o laço por patch dos três do compositor.

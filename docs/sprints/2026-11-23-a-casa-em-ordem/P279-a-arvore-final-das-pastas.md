# P279 — a árvore final das pastas (23/11/2026)

## O que se mediu (catálogo de 23/11)
A raiz tem doze pastas. Três delas quase não têm conteúdo: `bin/` (1 arquivo), `src/` (2) e `packaging/` (2).
Depois da P272 à P277, `assets/` fica com 36 arquivos, todos dado do motor.

| mudança | referências a trocar | o nó |
| --- | --- | --- |
| `lib/` para `scripts/lib/` | 422 linhas em 186 arquivos | `lib/comum.sh:4` acha a raiz subindo um nível; três validadores exigem `<raiz>/lib/comum.sh` |
| `bin/meow` para `scripts/meow` | 250 linhas em 98 arquivos | cópia em `~/.local/bin/meow` comparada byte a byte pelo doctor; o `.deb` faz link para `bin/meow` |
| `src/oraculo-tema` para `scripts/oraculo-tema` | 4 linhas | nenhum |
| `app/` para `scripts/app/` | 52 arquivos de teste, o atalho, a CLI | `app/run.sh:4` e `servidor.py:28` acham a raiz subindo um nível |
| `assets/` para `dados/` | 470 em 163 arquivos (117 somem com a P273) | 13 caminhos montados em Python |
| `systemd/` para `dados/systemd/` | 80 em 22 arquivos | 16 pontos montam `$RAIZ/systemd/$u` |
| `patches/` para `dados/patches/` | 118 em 41 arquivos | — |
| `packaging/deb/` para `dados/deb/` | `scripts/deb.sh` e 2 testes | — |

Os contratos `cosmic.tsv` e `vizinhos.tsv` citam 38 scripts como `scripts/x.sh:função`. Se os scripts não mudam de
pasta, só as linhas de `lib/painel.sh` e de `bin/meow` mudam.

## A árvore decidida
Sim de quem usa, 23/11/2026 (AskUserQuestion, com o catálogo na mão): «Cinco pastas».
```
MeowSystem/
├─ install.sh   meow.conf.exemplo   README.md   AGENTS.md   GSD.md
├─ scripts/     todo o código
│  ├─ meow            (era bin/meow)
│  ├─ lib/            (era lib/)
│  ├─ app/            (era app/)
│  ├─ oraculo-tema/   (era src/oraculo-tema)
│  ├─ temas-de-apps/  (só código)
│  └─ uma etapa por arquivo
├─ dados/       o que o código lê e não é arte
│  ├─ contratos/  extensoes/  apps/  pacotes/  ponte/
│  ├─ systemd/        (era systemd/)
│  ├─ patches/        (era patches/)
│  └─ deb/            (era packaging/deb)
├─ packs/       toda a arte e todo dado de tema
├─ tests/
└─ docs/
```
Cinco pastas na raiz no lugar de doze: código, dados, packs, testes e manual.

## A cura
1. Mecânico por script: um roteiro temporário, fora do repositório, faz os `git mv` e troca os caminhos literais por
   padrão fixo, uma pasta por commit.
2. A raiz passa a ser válida com `install.sh` e `scripts/lib/comum.sh`; `lib/comum.sh`, `app/run.sh` e
   `app/servidor.py` sobem dois níveis.
3. O install regrava a pegada instalada (ponteiro, cópia da CLI, unidades, atalho, completion, o braço root).
4. `AGENTS.md`, `docs/FRONTEIRA.md`, `docs/PACKS.md` e a decisão 56 (que cita `assets/contratos/espaco.tsv`) com os
   caminhos novos.

## Como se prova
- A suíte inteira verde antes e depois de cada pasta mudar, na árvore de integração.
- `./install.sh` a partir de uma instalação feita com a árvore antiga: 2 passagens no máximo, e o `meow doctor`
  seguinte sem divergência nova.
- `systemctl --user list-units 'meow*'` sem unidade falhando depois do install.
- Um PC com a árvore antiga instalada e o clone novo: o `./install.sh` direto conserta tudo sem gesto à mão.

## Nos três PCs
A árvore em que o produto é usado só recebe no fim, de uma vez, junto com a P284. O `meow` antigo recusa a raiz
nova: o primeiro comando em cada PC é `./install.sh`, direto.

## O roteiro em rascunho (23/11)
`~/.cache/meow-leva/roteiro-arvore/mudar.py`, provado na árvore `../.meow-wt-rascunho-arvore` a partir de
`54c408a7`: oito commits, 527 arquivos, 1240 linhas trocadas, saída 0 sem resíduo; a segunda rodada não faz nada.
Suíte inteira na árvore de cinco pastas: 171 de 172 verdes; o vermelho é o `autostart.sh`, intermitente também na
árvore antiga (3 em 40 sob carga, antes e depois). O relato inteiro, com as edições nomeadas, as exceções e o que
o roteiro não garante, está em `~/.cache/meow-leva/roteiro-arvore/relato-autor-roteiro.md`. Ele roda de novo
sobre a integração final, depois do passo 6.

Ensaio de 24/11 (`mudar.py --medir`) sobre a integração `06c6f9be`, já com o passo 4, o manual, o passo 9 inteiro e
os papéis por pack: saída 0, nenhum caminho antigo sobrou, nenhum ambíguo, nenhuma âncora sumida. Falta entrar o
bloco da arte para rodar de verdade.

Ensaio de 24/11, 2h55, sobre a integração `fe105c7b` (com a origem dos papéis): `mudar.py --medir` rc 0, «nenhum caminho
antigo sobrou». Log em `~/.cache/meow-leva/roteiro-arvore/medir-integracao-fe105c7b.log`. Falta ensaiar de novo depois da
arte e da P291.

Em 24/11, 3h17, o roteiro rodou de verdade sobre a integração com o passo 6 (`bb853120`), na branch
`bloco/arvore-final`: oito commits, um por pasta, ponta `7580c064`, e «nenhum caminho antigo sobrou». Dois ajustes no
roteiro por causa da arte: saiu a edição do acervo de fontes em `tests/app.sh` (o caminho já é do pack) e entrou a
da raiz de mentira das fontes em `tests/pack-traz-o-que-usa.sh`. Falta: a suíte inteira, quem confere (a pegada
instalada a partir da árvore antiga é o ponto central) e o merge na integração.

## Feito (24/11/2026)
Integrado em `1cf0d430` (fast-forward da `bloco/arvore-final-conf`).
- A raiz versionada tem cinco pastas: `scripts/`, `dados/`, `packs/`, `tests/`, `docs/`. O movimento foi `git mv`
  (`git log --follow` de `scripts/meow` mostra 212 commits).
- A suíte inteira na árvore nova, em paralelo: 182 testes, 179 verdes, 1469 s (`suite-arvore-final.log`). Os três
  vermelhos: dois eram do roteiro (`migrar-caminhos.sh`, `valores-de-antes.sh`) e um vinha do passo 6
  (`extensoes-pagina.py`, que ficou fora do cruzamento da arte). Os três consertados e verdes.
- Quem conferiu achou o que a suíte não via: `tests/arvore.sh` varria 37 arquivos e passou a varrer zero (teste verde
  sem olhar nada); a linha `dados-do-programa` do `espaco.tsv` apontava para pasta que não é da casa de quem usa;
  frases em que o `assets/` trocado era a pasta do tema do Spotify (decisão 67), não a do repositório.
- A pegada instalada, medida em casa de mentira: install da árvore antiga, troca para a nova, install. Nada na casa
  aponta para caminho antigo; a terceira passada não escreve; clone novo em outra pasta conserta sozinho.
- O `.deb` leva as cinco pastas (3451 arquivos, o mesmo conjunto de antes); `/usr/bin/meow` aponta para
  `scripts/meow`.
- Em voo, para fechar a tarefa: a linha da decisão «cinco pastas» com guarda em `tests/arvore.sh`, e o install limpar
  o estado de falha da unidade nossa antes de armá-la.
- Só o install de verdade prova: os comandos estão em `~/.cache/meow-leva/suite-2026-11-23/relato-conf-arvore.md`.

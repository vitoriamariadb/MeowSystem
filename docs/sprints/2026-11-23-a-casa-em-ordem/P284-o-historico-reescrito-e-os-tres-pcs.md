# P284 — o histórico reescrito e os três PCs de volta ao tronco (23/11/2026)

## O que se mediu (nitro-5, 23/11)
- `.git`: 162 MB, 2411 commits, 12 tags. Os maiores objetos são de arquivos que já saíram da árvore:
  `packs/meowsystem/wallpapers/meow-atmosfera-calma-1ky673.png` (16,2 MB),
  `…/cat-landscapes-Cloudsnight.jpg` (7,8 MB), `packs/dracula/icones/feitos-a-mao/clapper.png` (7,5 MB).
- A árvore versionada de hoje soma cerca de 19 MB (12,3 MB de texto e 6,5 MB de SVG).
- `scripts/atualiza.sh` só avança com `merge --ff-only` e para quando o clone tem commit que o GitHub não tem.

Resposta de quem usa, 23/11 (AskUserQuestion), à pergunta «o histórico antigo do git fica ou é reescrito?»:
«Reescrever».

## O que a reescrita faz
- Todos os hashes mudam, as assinaturas dos commits antigos se perdem e as 12 tags apontam para commit que deixa de
  existir.
- Todo clone antigo passa a ter commits que o GitHub não tem: a atualização sozinha para nos três PCs até o clone
  ser trocado.
- Não tem volta no GitHub. A volta é a cópia de segurança.

## A cura, em ordem
1. Só começa com tudo desta leva integrado e a suíte inteira verde na árvore de integração.
2. Cópia de segurança em dois lugares, conferida: `git bundle create … --all` e um clone espelho, com
   `git bundle verify`. As levas antigas de `docs/sprints/` ficam só aí.
3. `ATUALIZA="nao"` nos três PCs, com a etapa `atualiza` rodada.
4. Reescrita, numa cópia do repositório. Dois jeitos, a escolher na hora com os números:
   - tirar do histórico os caminhos aposentados e os objetos grandes, mantendo os commits;
   - uma raiz nova, com um commit só, a árvore final.
5. Ponta assinada pela chave da lista `assinantes`; `git verify-commit` na ponta.
6. Medir o `.git` antes e depois.
7. Com o sim de quem usa nesse ponto, com os números na tela: `push --force-with-lease` no `master`, tags e branches
   velhas apagadas no GitHub.
8. Em cada PC: clone limpo conferido, `git fetch`, a árvore posta na ponta nova, `./install.sh` direto (o `meow`
   antigo recusa a raiz nova, P279), `meow doctor`.
9. `ATUALIZA="sim"` de volta e uma volta do `meow atualizar` sem novidade, com a linha no `atualiza.log` (P265).

## Como se prova
- O run `testes` da ponta nova fecha verde no GitHub.
- Um clone novo do GitHub: tamanho medido, `git verify-commit HEAD` com a lista de `assinantes`, `./install.sh --dry-run`
  sem erro.
- Nos três PCs: `git status` limpo no `master`, install em até 2 passagens, doctor sem divergência nova.

## Ressalvas
- O GitHub guarda os objetos antigos por um tempo, alcançáveis por hash, até a coleta dele.
- Todo teste ou documento que cita hash antigo quebra; a P283 e a P278 fecham antes.
- A decisão 22 (o tronco é o `master` de `vitoriamariadb/MeowSystem`) não muda.

## Achados de 24/11 que entram no roteiro deste passo
- Antes de trocar de clone em cada PC: `git -C <clone velho> status --short --ignored` e copiar para o clone novo o
  que for de quem usa. Medido: o install do clone novo DESINSTALA as fontes que ficaram em
  `packs/meowsystem/fontes/locais/` (ou em `assets/fontes/locais/`) do clone velho; no checkout principal do nitro-5
  há capturas ignoradas em `packs/dracula/temas/capturados/alucard-mauve/` e `dracula-pink/`.
- O install roda com `SUDO_ASKPASS=/usr/local/lib/aurora/askpass` no ambiente: sem TTY a ponte fica de fora e a
  completion do sistema (`/usr/local/share/zsh/site-functions/_meow`) continua validando `lib/comum.sh`.
- Depois do install: `systemctl --user list-units 'meow*' --state=failed --no-legend` vazio.
- Em cada PC, antes do install, só lendo: `python3 scripts/pack.py migrar-caminhos --conferir` e cada destino existe
  no disco. No nitro-5 são 11 linhas e os 11 destinos existem (conferido em 24/11). A tabela tem 588 destinos que
  não existem (`packs/meowsystem/icones/sistema/<nome>` vindos de `mimetypes/css-variables/` e `arcticons/`); só
  importam se o mapa do PC citar um deles.
- Os comandos de conferência por bloco estão nos relatos: `relato-conf-arte.md` (seção 8), `relato-conf-arvore.md`,
  `relato-conf-origem.md`, `relato-nomes-dos-papeis.md` e `relato-conf-nomes.md`.

## As respostas de quem usa (AskUserQuestion, 24/11/2026, 4h25)
| pergunta | resposta |
| --- | --- |
| como reescrever o histórico | «Raiz nova, um commit só» |
| a tag de versão da ponta nova | «v2.4.0» |
| o push forçado | «Pode enviar direto»: com a suíte inteira verde, o bundle e o espelho conferidos e a ponta assinada, sem perguntar de novo, e segue o install nos três PCs |

Consequências, já ditas na pergunta: todo o histórico, as pesquisas e as sprints antigas ficam só na cópia de
segurança, e a decisão 24 passa a dizer isso, citando este sim.

O commit único nasce por `git commit-tree` sobre a árvore da ponta da integração, sem passar pelo gancho de commit:
a árvore publicada é byte a byte a que a suíte provou.

## Feito (24/11/2026)
| passo | medida |
| --- | --- |
| suíte inteira na árvore final | 183 de 183, 1628 s, na integração `b5904f5e` |
| cópia de segurança | `~/Backups/meowsystem/` no nitro-5 e no desktop: bundle de 142 MB (`git bundle verify` ok nos dois, 3819 commits, 13 tags) e o espelho |
| raiz nova | `11ed66b8`, por `git commit-tree -S` sobre a árvore de `b5904f5e`; `git diff` vazio; assinatura boa pela lista `assinantes` |
| tag | `v2.4.0`, assinada |
| tamanho do repositório | 195 MB antes, 14 MB num clone novo |
| push | 5h21: `master` em `11ed66b8` com `--force-with-lease` sobre `9110e7d7`; as 10 tags velhas e a branch `docs/p159-p161-portal-e-areas` apagadas do GitHub |
| run `testes` do GitHub na ponta nova | verde, 50 min 31 s |
| nitro-5 | checkout em `11ed66b8`; install em 3 passagens e a segunda rodada «nada mais a escrever»; `meow doctor` rc 0; nenhuma unidade em falha; `.git` local de 188 MB para 17 MB depois de apagar as branches e tags de antes |
| desktop | checkout em `11ed66b8`; install em 3 passagens, sem erro; a fonte dela foi para `packs/meowsystem/fontes/locais/` e segue instalada; a completion do sistema e o atalho do painel no caminho novo |
| a atualização sozinha | `ATUALIZA="sim"` de volta nos dois; `meow atualizar`: «nada novo no master (11ed66b8)» |

O que as conferências dos blocos deram no nitro-5: as chaves `WALLPAPER_DRACULA_*` saíram do conf; os papéis estão em
`dracula/` (os 6 pares), `meowsystem/` e `Minhas/`; o `BANIDOS.txt` tem os 13 do Dracula com o nome novo e nenhum
`tulip-`; o mapa de ícones tem as 11 linhas migradas para `packs/dracula/icones/apps/`; o prompt ficou igual.

## Aberto depois do passo 10
- Desktop, de antes desta leva: o `meow doctor --consertar` sai com erro por causa do `patches` («o build do
  cosmic-comp 0.1~1795167359~24.04~6968c5d caiu na sessão e foi posto de lado»), e por isso a `meow-doctor.service`
  fica em falha todo dia (já estava às 5h13, antes da árvore nova). A sessão de lá roda o compositor de fábrica.
  Pede gente: medir por que o build cai naquela máquina.
- Desktop: as pontes de app_id (`janela_dock`) mudaram entre o install e o conserto do doctor (2 a remover, depois 2
  a criar, depois conformes). É a P269: medir com o Hefesto aberto.
- Desktop: a segunda rodada do install ainda escreveu o papel de parede uma vez; a terceira, as pontes de janela.
- O install recusa com «outro meow está rodando» quando roda logo depois do `git reset`: o vigia do pack
  (`meow-assets.service`) acorda com a troca dos arquivos e segura a trava. Rodar de novo resolve; o install podia
  esperar o vigia.
- O `.git` do desktop segue com os objetos de antes (197 MB) até o `git gc` de lá.
- O GitHub guarda `refs/pull/1` e `refs/pull/2`, que não se apagam por push.

## Os três PCs e a limpeza (24/11/2026, 10h)
Pedido de quem usa, em 24/11/2026: «Instala e limpa nos três PCs as pastas de desenvolvimento e voo. Deixa só a
nossa última versão instalada localmente. Uma pasta só pro nosso repo nos três PCs.» E, sobre enviar os commits de
documentação ao `master`: «Sim pra sua dúvida.»

| PC | install | repositório | o que saiu da pasta |
| --- | --- | --- | --- |
| nitro-5 | 2 rodadas, a segunda sem escrever; `meow doctor` rc 0 | só `master` e `v2.4.0`; `.git` de 188 MB para 17 MB | 14 árvores de trabalho, 19 branches, 10 tags, as fotos de duas levas antigas |
| desktop | 3 rodadas até não escrever; `meow doctor` com o `patches` de antes | só `master` e `v2.4.0`; `.git` de 197 MB para 15 MB | 2 branches, 1 stash, `assets/` (292 ícones), `aba7.png`, o bundle de 01/11 que morava ao lado do clone |
| portátil | 2 rodadas, a segunda sem escrever; `meow doctor` rc 0, nenhuma unidade em falha | só `master` e `v2.4.0`; `.git` de 239 MB para 16 MB | 17 branches, `assets/` (5 temas), `dist/`, `app/`, as fotos de uma leva antiga |

Nada foi apagado sem cópia. Em `~/Backups/meowsystem/` de cada PC ficaram:
- o clone inteiro de antes: `clone-portatil-antes-da-raiz-nova.bundle` e `clone-desktop-antes-da-limpeza.bundle` (com
  as branches e o stash de lá); no nitro-5, o `meowsystem-antes-da-raiz-nova.bundle` e o espelho;
- `sobras-<pc>/`: o que estava na pasta do clone e não é da árvore nova;
- o `meow.conf`, a lista dos papéis, o `BANIDOS.txt`, o mapa de ícones e o `starship.toml` de antes.

Ficou como estava, de propósito:
- os dez clones `~/Desenvolvimento/meowsystem-*` (nitro-5 e portátil): são os repositórios dos applets, cada um com
  dois arquivos sem commit, e o `scripts/vizinhos.sh` os procura nessa pasta;
- `~/Desenvolvimento/Meow-Portatil`: é um link para a montagem remota, não é clone;
- `~/.cache/meow-leva/` no nitro-5 (2,8 MB): os relatos que as tarefas desta leva citam;
- os temas capturados e a fonte dela dentro de `packs/`, que o produto usa.

No portátil, `~/.local/share/backgrounds/meowsystem/` ainda tem `BANIDOS.txt`, `FONTES.tsv`, `lado.tsv` e `LICENSE`
soltos na raiz, de um desenho anterior; o doctor não acusa. Fica para a próxima leva.

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

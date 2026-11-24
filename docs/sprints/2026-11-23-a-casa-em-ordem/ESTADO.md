# Estado da leva de 23/11 (coordenador)

Árvore desta leva: `../.meow-wt-leva-23`, branch `docs/leva-2026-11-23`, a partir do `master` `9110e7d7`. O `master`
e o GitHub seguem intocados: tudo vive em branches locais.

## O pedido (23/11)
1. Rodar o install completo, ler cada linha e propor a solução do que aparecer. Feito: 1 passagem, 77 etapas, 71
   conferem, 6 puladas, 0 falhas; o `meow doctor` logo depois sai 1. Os achados são a P264 até a P270.
2. «Vamos começar pela limpeza da casa»: toda arte só nos packs, pastas legadas fora do repositório (local e
   online), pastas mescladas, testes antigos apagados, o repositório barato de ler. São a P271 até a P287.
3. «Manda ver» sobre os dez passos, com os agentes de cada um. Quem mexe nos testes é o coordenador.

## Feito
- Catálogo do repositório por quatro agentes de leitura, sem escrita no repositório: `CATALOGO.md`. Os quatro
  relatórios inteiros e as saídas do install e do doctor estão em `~/.cache/meow-leva/catalogo-2026-11-23/`.
- 24 tarefas escritas (P264 a P287). A ordem, os agentes de cada passo, a regra da suíte e o encaixe das herdadas
  estão no `00-leva.md`.
- As respostas de quem usa (três rodadas de AskUserQuestion) estão no `00-leva.md`, seção «As decisões tomadas».

- «Manda ver» de quem usa, 23/11, sobre a ordem dos dez passos com os agentes de cada um.
- Passo 1 (P271) feito no nitro-5; o que saiu e o que ficou está no fim da P271.

## As árvores (24/11, 4h20)
| árvore | branch | para quê | estado |
| --- | --- | --- | --- |
| `../.meow-wt-leva-23` | `docs/leva-2026-11-23` | os documentos desta leva | viva |
| `../.meow-wt-integracao-23` | `integracao/2026-11-23` | onde cada bloco entra depois do conferente | passos 2, 3, 4, 5, o passo 9 inteiro (P264 a P270 e as herdadas P288 a P290) e a parte do manual (P278), os papéis por pack (P285, com a origem do Dracula no `pack.json`), o texto da decisão 56 e o `patches/versao` do compositor de 19/11 |
| `../.meow-wt-barato`, `-testes`, `-suite`, `-ruido`, `-sessao`, `-comentarios`, `-manual`, `-herdadas`, `-papeis` | os blocos já integrados | — | saem no fim |
| `../.meow-wt-arte` | `bloco/arte-no-pack` | passo 6: P274, P275 | integrado (`a710dccb`); a remover no fim |
| `~/Desenvolvimento/.hefesto-wt-app-id` | `fix/app-id-antes-do-gtk`, no repositório do Hefesto | P269 | feito (`246085a90`), sem merge: a entrada é de quem cuida do Hefesto |
| `../.meow-wt-origem` | `bloco/papeis-origem` | P285 (origem), decisão 56 e P291 | integrado (`61feca02`); a remover no fim |
| `../.meow-wt-rascunho-arvore` | `bloco/sem-ler-o-historico` (antes `bloco/arvore-final` e `bloco/decisoes-46-47`) | passo 7, as decisões 46 e 47 e o item 1 da P292 | tudo integrado; a remover no fim |
| `../.meow-wt-conf-arvore` | `bloco/arvore-final-conf` | o conferente do passo 7 e o resto da P278 | integrado (`dfeb2313`); a remover no fim |

O passo 6 foi adiantado a pedido de quem usa (23/11, «Não dá pra soltar o passo 6 agora não?») e, às 22h50,
«Paralelo»: herdadas, manual e Hefesto saíram juntos. O coordenador adianta a P282 por script
(`~/.cache/meow-leva/cobertura/`).

Agente que trava: comando composto com sintaxe do zsh (`${(s:,:)L}`) para num pedido de permissão que ninguém vê.
O brief manda comando simples, um por chamada, e teste em segundo plano com saída em arquivo.

Agente que termina nem sempre acorda o coordenador (dois voltaram calados nesta leva): um vigia em segundo plano
olha os relatos e a hora do transcript de cada agente.

Quem usa pediu em 23/11, depois do passo 2: «quanto mais paralelizarmos e progredirmos o mais rapido melhor». Por
isso o passo 9 foi adiantado e anda junto do passo 4.

Os relatos dos agentes (`relato-impl-*.md`, `relato-conf-*.md`) e os registros da suíte estão em
`~/.cache/meow-leva/suite-2026-11-23/`.

## Próximo passo
O passo 10 (P284) está em curso desde 24/11, 5h15. O que já aconteceu, em ordem:
1. Suíte inteira verde na árvore final: 183 de 183, 1628 s (`suite-integracao-final-2.log`), na integração `b5904f5e`.
2. Cópia de segurança conferida em dois PCs, em `~/Backups/meowsystem/`: o `meowsystem-antes-da-raiz-nova.bundle`
   (142 MB, sha256 `3ff0c8c1…`, `git bundle verify` ok, 3819 commits e 13 tags) e o `espelho-antes-da-raiz-nova.git`.
   Lá também ficaram o `meow.conf` de antes de cada PC e, do nitro-5, a lista dos papéis, o `BANIDOS.txt`, o mapa de
   ícones e o `starship.toml` de antes.
3. `ATUALIZA="nao"` no nitro-5 e no desktop, com a etapa `atualiza` rodada. O portátil não respondeu (o nome não
   resolve na rede).
4. A raiz nova: `11ed66b8`, um commit feito por `git commit-tree -S` sobre a árvore de `b5904f5e` (árvore idêntica,
   `git diff` vazio), assinatura boa pela lista `assinantes`. Tag `v2.4.0` assinada nele. O repositório novo tem
   14 MB; o de antes, 195 MB. Num clone só com a raiz nova, 22 de 22 testes que tocam git, versão e histórico verdes.
5. Push em 24/11, 5h21: `master` do GitHub em `11ed66b8` (`--force-with-lease` sobre `9110e7d7`), tag `v2.4.0`
   enviada, as 10 tags velhas e a branch `docs/p159-p161-portal-e-areas` apagadas de lá.
6. O checkout principal do nitro-5 está em `11ed66b8`. O install da árvore nova roda nele desde as 5h22
   (`~/Backups/meowsystem/install-1.nitro-5.log`).

O que falta, em ordem:
1. Ler o install do nitro-5, rodar a segunda passada (tem de dizer «nada mudou»), `meow doctor`, e as conferências dos
   relatos (`relato-conf-arte.md` seção 8, `relato-conf-arvore.md`, `relato-conf-nomes.md`).
2. Desktop, por `ssh maria`: `git status` limpo (conferido às 5h15, com a fonte dela em `assets/fontes/locais/`, que
   o install leva para o pack), `git fetch`, `git reset --hard origin/master`, `SUDO_ASKPASS=… ./install.sh` duas
   vezes, `meow doctor`. P269: medir lá o app_id do Hefesto.
3. O run `testes` do GitHub na ponta nova (cerca de uma hora) tem de fechar verde.
4. `ATUALIZA="sim"` de volta nos dois PCs e uma volta do `meow atualizar` sem novidade.
5. Portátil: quando ligar, os mesmos passos do desktop. Até lá o clone de lá não se atualiza sozinho.
6. Limpeza local do nitro-5: remover as worktrees `.meow-wt-*`, apagar as branches e as tags de antes (o bundle as
   guarda) e `git gc`, para o `.git` cair de 195 MB.
7. O índice de código (P287, item 3). A P283 e o `PARA-A-PROXIMA-LEVA.md` são a leva seguinte.

O trabalho novo nasce do `master` novo. A branch desta nota é a `docs/fecho-da-leva`, na `../.meow-wt-leva-23`.

## Abertos que não podem se perder
O que ficou para depois desta leva está no `PARA-A-PROXIMA-LEVA.md`. Desta leva, seguem abertos:
- P269: a linha do Hefesto no `appid.map` espera a medida no desktop, com o Hefesto aberto.
- P267: a linha `revisao cosmic-applets` do contrato espera o clone do fonte e a conferência pelo palco.
- P277: a tabela `packs/CAMINHOS-DE-ANTES.tsv` só sai depois de o install rodar no nitro-5.

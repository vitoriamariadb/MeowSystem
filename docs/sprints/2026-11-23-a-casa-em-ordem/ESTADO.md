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
Os passos 1 a 9 estão na integração (`2e658838`, 24/11, 4h17). Nenhum agente em voo. Falta só o passo 10 (P284).
1. A suíte inteira roda na integração desde as 4h17: `~/.cache/meow-leva/suite-2026-11-23/suite-integracao-final.log`
   (183 testes, cerca de 25 min). Vermelho se conserta antes de qualquer outro gesto.
2. Cópia de segurança, local: `git bundle create … --all` com `git bundle verify`, e um clone espelho.
3. PARA AQUI e pergunta a quem usa, com os números na tela: o jeito da reescrita (mantendo os commits, ou raiz nova
   de um commit só; a P292 diz o que cada um faz com a decisão 24), o número da tag de versão da ponta nova, e o sim
   para o `push --force-with-lease`. Sem o sim dela, nada de reescrita, de push nem de `ATUALIZA="nao"` nos outros PCs.
4. Depois do sim: o roteiro da P284 (itens 3 a 9), com os achados de 24/11 do fim dela, e a P292, itens 2 e 3.
5. No fim: o índice de código (P287, item 3), remover as worktrees integradas, e a P283 como leva seguinte.

A frase para abrir sessão nova: «Leia `docs/sprints/2026-11-23-a-casa-em-ordem/ESTADO.md`, a `P284` e a `P292` na
árvore `../.meow-wt-leva-23`, confira com `git worktree list` e `git log -1 integracao/2026-11-23` onde parou, e siga
do item que estiver aberto no Próximo passo.»

## Abertos que não podem se perder
O que ficou para depois desta leva está no `PARA-A-PROXIMA-LEVA.md`. Desta leva, seguem abertos:
- P269: a linha do Hefesto no `appid.map` espera a medida no desktop, com o Hefesto aberto.
- P267: a linha `revisao cosmic-applets` do contrato espera o clone do fonte e a conferência pelo palco.
- P277: a tabela `packs/CAMINHOS-DE-ANTES.tsv` só sai depois de o install rodar no nitro-5.

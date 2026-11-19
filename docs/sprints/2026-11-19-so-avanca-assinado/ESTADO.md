# Estado da leva de 19/11, noite (coordenador, sem agentes)

Árvores: `../.meow-wt-cache-tema` (`bloco/cache-tema`), `../.meow-wt-dock-junta` (`bloco/dock-junta`),
`../.meow-wt-assinatura` (`bloco/assinatura`), `../.meow-wt-integracao-20` (`integracao/2026-11-20`) e
`../.meow-wt-leva-19` (`docs/leva-2026-11-19`, estes documentos).

| bloco | tarefa | situação |
| --- | --- | --- |
| cache do tema | P263 | `f993320b`; `tests/logo.sh` vermelho antes da cura (11 falhas), verde depois; cruzamento do bloco 8 de 8 |
| dock | P262 | `5ab110ae`; caso 14 do `tests/dock.sh` vermelho antes (7 falhas), verde depois; cruzamento do bloco 15 de 15 |
| assinatura | P257 | `07a1dfb4`; casos novos do `tests/atualiza.sh` vermelhos antes (13 falhas), verdes depois; cruzamento do bloco 13 de 13; decisão 65 com a assinatura |

Integrados em `integracao/2026-11-20` (`047b8f10`, três merges assinados). Cruzamento na integração, 19/11 19h00: 27 pedidos,
27 verdes, 0 pulados (`scratchpad/integra-20.log`).

## O que mudou neste PC fora do repositório
- Config local do git do MeowSystem no nitro-5: `gpg.format=ssh`, `user.signingkey=~/.ssh/id_ed25519_personal`,
  `commit.gpgsign=true`. Todo commit e todo merge feito aqui sai assinado. Desfazer: `git config --local --unset`
  nas três chaves.
- Fila da casa: item `d4ed6ca2` para a Vitória (ligar a assinatura de commit nos PCs dela e mandar a chave pública).

## Ressalvas
1. Sem conferente separado: o coordenador escreveu teste e cura. O que segura é o vermelho antes, o verde depois e
   o cruzamento.
2. A mesma chave empurra para o GitHub e assina. A P257 fecha a conta do GitHub tomada (senha, token, edição pela
   página); não fecha o roubo do arquivo da chave no nitro-5.
3. A P262 não alcança o `apt` que troca o `/usr/bin/cosmic-app-list` com a dock do pacote viva.
4. A P262 e a P263 ainda não foram vistas numa sessão de verdade (duas telas no portátil; troca de fase no nitro-5).

## 19/11, 19h25: push 13 e install nos três PCs
- `master` = `origin/master` = `f542073c` (ponta assinada). Run `testes` 44625122458, em curso às 19h25.
- nitro-5, desktop e portátil: `git pull` para `f542073c` e `./install.sh` limpo na primeira tentativa («Pronto. 2
  passagens, 77 etapas, nada mais a escrever»). Nos três: `~/.config/meow/assinantes` semeada com a chave do
  nitro-5, `atualiza.sh conferir` sai 0 e a dock `estado=ok` no `…779f920`.
- Portátil: dois `cosmic-app-list` vivos, os dois no mesmo build (`…779f920`). Desktop: um.
- O install foi feito sem esperar o CI, por ordem de quem usa; o cruzamento de 27 estava verde.
- nitro-5 desligado pelo coordenador depois do push 14, por ordem de quem usa.

## Próximo passo
Ordem de quem usa, 19/11 19h05: «Da Merge na master dispara o ci. Instala nos três PCs e desliga o notebook».
1. Ler o run `testes` do push 13 (a ponta com os três blocos) e o do push 14 (o fecho destes documentos).
2. 20/11 depois das 13h08: conferir no desktop e no portátil se a atualização sozinha puxou o push 14, que é o
   primeiro commit que ela só aceita pela assinatura (`~/.local/state/meowsystem/atualiza.log`).
3. Quem usa: sair e entrar na sessão nos três PCs; no portátil, com as duas telas, ver um build só da dock e dizer o
   que o mouse faz de errado.
4. A suíte inteira não rodou com os três blocos juntos: rodar na árvore de integração antes da leva seguinte.
5. Com o ok de quem usa: tirar as cinco árvores `.meow-wt-*` desta leva, já no `master`.

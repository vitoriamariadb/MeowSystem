# P288 — o gancho de push e a ponta assinada (23/11/2026)

Herdada da leva de 19/11.

## O que se mediu (integração, 23/11)
- `scripts/ganchos.sh` instala `gancho-pre-push.sh` e `gancho-post-merge.sh` (`tests/ganchos.sh` cobre instalar,
  conferir e remover).
- Nenhuma etapa do `install.sh` nem verbo do `meow` chama `scripts/ganchos.sh`: quem instala é a mão.
- A atualização sozinha só aceita ponta do `master` verde e assinada (decisão 65). Um push de ponta sem assinatura
  passa pelo gancho e só é recusado depois, em cada PC, pela volta do `atualiza.sh`.

## A causa
O gancho nasceu antes da regra da assinatura, e a instalação dele nunca entrou num caminho que alguém percorre.

## A cura na origem
1. O `gancho-pre-push.sh` recusa push para o `master` cuja ponta não tem assinatura que o `git verify-commit`
   aprove, com a frase que diz o que falta. Outras branches passam.
2. Medir quem deve instalar os ganchos (só clone de quem desenvolve, nunca o de quem só usa) e ligar a instalação a
   um caminho que já existe. Se a medida não fechar um caminho claro, fica proposta no relato, sem código.

## Como se prova
- `tests/ganchos.sh`: push de ponta sem assinatura para o `master` recusado; com assinatura (gpg de mentira que lê a
  entrada, como o de `tests/atualiza.sh`) aceito; outra branch aceita. Vermelho antes, verde depois.

## Feito (24/11, bloco `install-herdadas`, integrado em `eae6f987`)
- O `pre-push` de `scripts/ganchos.sh` recusa push para `refs/heads/master` cuja ponta o `git verify-commit` não
  aprova. Só a ponta é conferida; apagar branch, tag e outras branches passam. Sem `gpg.ssh.allowedSignersFile` no
  git, usa `~/.config/meow/assinantes` por `git -c`, sem escrever configuração no clone.
- Provado com a função real, sem instalar gancho: ponta assinada empurrada sobre o `master` como num push forçado
  passa; ponta sem assinatura é recusada.
- Item 2 sem código: nenhum caminho que existe é só de quem desenvolve. Proposta para quem usa decidir: um verbo
  `meow ganchos instalar`.

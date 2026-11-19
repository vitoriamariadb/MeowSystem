# P257 — a atualização ao ligar só avança para commit assinado (19/11/2026)

## O que se mediu
- `scripts/atualiza.sh` (P255, decisão 65) busca o `master` do GitHub, confere o run `testes` verde pela API pública,
  avança com `merge --ff-only` e roda `./install.sh` com o `SUDO_ASKPASS` lido do `/etc/sudo.conf`, sem ninguém na
  frente da tela.
- O run verde prova que os testes passam; não prova quem escreveu o commit. Quem consegue dar push no `master`
  (conta do GitHub ou chave SSH roubada) executa comando como root nos três PCs em até um dia.
- Achado da revisão automática de segurança do push 8, em 19/11.

## A causa
A confiança da atualização está inteira na conta do GitHub. Antes da P255 havia uma pessoa entre o `git pull` e o
`./install.sh`; a P255 tirou essa pessoa e não pôs outra prova no lugar.

## A cura na origem
- O `cmd_rodar` só avança para um commit cuja assinatura confere (`git verify-commit`, assinatura SSH) contra uma
  lista de chaves que mora fora do repositório (`~/.config/meow/assinantes`), para que o mesmo push não troque a lista.
- Basta a assinatura do commit de destino: quem assina a ponta responde pela árvore inteira.
- Commit sem assinatura ou de chave fora da lista: o clone fica, e avisa uma vez, como no vermelho do CI.
- A lista é semeada pelo install feito à mão, com a senha (decisão «senha só no install»), nunca pela atualização.
- Cada PC que dá push precisa de assinatura de commit configurada. No nitro-5 é do André; nos PCs da Vitória a
  configuração do git é dela: vai para a fila (`irmaos fila add --para vitoria`).

## Como se prova
- `tests/atualiza.sh`: commit verde sem assinatura não avança; assinado por chave fora da lista não avança; assinado
  por chave da lista avança e instala uma vez; a lista dentro do repositório não é lida.
- `tests/decisoes.sh`: a linha da decisão 65 ganha a assinatura, com o sim de 19/11.

## A resposta de quem usa
AskUserQuestion de 19/11, 13h20: «Assinatura na próxima leva (Recomendado)». A atualização ao ligar segue ligada até
lá, como foi pedida.

## Nos três PCs
Vale nos três.

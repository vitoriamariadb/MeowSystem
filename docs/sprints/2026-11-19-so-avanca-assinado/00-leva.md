# Leva de 19/11/2026 (noite) — só avança assinado, a dock inteira e a cache em dia

Pedido de quem usa, 19/11 18h25: a frase de retomada da leva de 18/11 («conferir se a atualização ao ligar puxou o
master nos PCs da Vitória e abrir a leva com a P257, a P262 e a P263») e «faz isso sem agentes». O coordenador
implementou as três, sozinho, com o teste vermelho antes de cada cura.

## O que se mediu antes (19/11 18h30, só leitura, por SSH)

| | desktop | portátil |
| --- | --- | --- |
| checkout | `fbde5363` (push 9) | `fbde5363` (push 9) |
| `meow-atualiza.timer` | armado; última volta 19/11 13h08, saiu 0; próxima 20/11 13h08 | o mesmo, 13h08 |
| `~/.local/state/meowsystem/atualiza.log` | não existe: a volta de 13h08 não tinha o que puxar | o mesmo |

A atualização ao ligar ainda não teve chance: os pushes 10, 11 e 12 saíram depois da volta das 13h08 e nenhum dos
dois PCs foi religado. Não é defeito medido; é medida que não deu para tirar.

## As tarefas

Os arquivos seguem em `../2026-11-18-as-vagas-que-nao-chegam/`, com a causa provada e a cura como ficou.

| bloco | tarefa | o que toca | commit |
| --- | --- | --- | --- |
| cache do tema | P263 | `scripts/logo.sh`, `tests/logo.sh` (novo) | `f993320b` |
| dock | P262 | `scripts/dock_shim.sh`, `scripts/dock.sh`, `tests/dock.sh` | `5ab110ae` |
| assinatura | P257 | `scripts/atualiza.sh`, `assets/assinantes` (novo), `tests/atualiza.sh`, decisão 65 | `07a1dfb4` |

Arquivos disjuntos entre os três blocos.

## Isso resolve nos três PCs?

| tarefa | nitro-5 | desktop | portátil |
| --- | --- | --- | --- |
| P263 | resolve (é onde o tema tem cache) | nada a resolver: o tema de lá não tem cache | o mesmo |
| P262 | resolve; aparece com duas telas | resolve | resolve; é onde foi visto |
| P257 | resolve, com a lista semeada no install | resolve depois do install do coordenador | o mesmo |

## Fica para a leva seguinte (a escrever, uma tarefa por arquivo)
- `P261`: botões à esquerda em todo app do COSMIC (patch na libcosmic e build por app).
- Os clones de fonte que `graficos-fonte-real.sh` e `dock-fonte-real.sh` pedem e nada no produto cria.
- `app-completo.py` instável na aba Tema com a máquina carregada.
- O vigia de 5 min do zsh da Vitória que não repõe o lado dos botões.
- Os oito achados dos relatórios de 19/11 15h30 (no `ESTADO.md` da leva de 18/11).
- Um gancho de push que recuse ponta do `master` sem assinatura: hoje quem garante é a config local do repositório.

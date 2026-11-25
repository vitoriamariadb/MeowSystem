# Achado · o `chave-etapa.sh` que falhou uma vez e passou na seguinte (25/11/2026)

## O que se viu
Quem implementou o bloco dos apps sem módulo rodou `./tests/todos.sh --portatil`: na primeira vez o
`chave-etapa.sh` falhou, e na seguinte passou sem mudança nenhuma. A saída da falha não foi guardada.

## O que se mediu depois
Tudo na worktree do bloco, com os commits até `fc2c769`:
- `./tests/todos.sh --so=chave-etapa.sh`, cinco vezes seguidas: cinco verdes, 2 s cada.
- `./tests/todos.sh --portatil` inteiro, uma vez: 146 verdes, `chave-etapa.sh` verde.
- Ele junto com seis testes pesados (`temas-por-app`, `temas-de-apps`, `miudos-do-install`,
  `etapa-compositor`, `pack-pessoal-tem-tema`, `apps-em-todo-pack`), duas vezes: verde nas duas.
- O ensaio que o teste roda (`install.sh --dry-run --etapa forma`, num HOME temporário) termina em
  «Pronto. 1 passagem, 1 etapas», e o cadeado fica dentro desse HOME: não há cadeado dividido com
  outro teste.

## O que se sabe da causa
Ela não vem do bloco. O bloco só mudou o VALOR de `APPS_ATIVOS` no `meow.conf.exemplo`, e o teste
compara NOMES de chave com `dados/contratos/chave-etapa.tsv`. O teste lê da árvore só o
`meow.conf.exemplo`, o `install.sh`, a tabela e o `scripts/app/servidor.py`. Explicação possível,
que não foi provada: a suíte rodou enquanto um desses arquivos estava sendo editado na mesma
worktree.

## O que falta
Reproduzir a falha. Quem vir o teste falhar de novo guarda a saída inteira do `todos.sh`: ela diz
qual das cinco provas do teste caiu, e a causa sai dela.

# P146 — os vermelhos aceitos do `restaurar.sh` saem

Anotada em 29/10. Desde a leva anterior a suíte convive com vermelhos «aceitos» no `tests/restaurar.sh`
(`pack_usar` e `desinstalar`, por arquivos do VS Code; `sistema_limpar`, pelo `.deb` do cosmic-comp). Pulado não é
verde, e vermelho aceito esconde vermelho novo.

## O que se mediu
- Rodar `tests/restaurar.sh` dentro do arranjo do `tests/todos.sh` e anotar cada caso vermelho com o diff que ele
  mostra (o que muda sem «Restaurar» devolver).
- `sistema_limpar`: o `scripts/atualizar_sistema.sh limpar` copia o `.deb` real do cosmic-comp para
  `~/.local/share/meowsystem/debs` da casa de brinquedo (conferência do Painel e do Flatpak, 27/10).
- `pack_usar` e `desinstalar`: arquivos do VS Code que mudam e o restaurar não devolve.

## Cura na origem
- Cada caso: ou o restaurar devolve o que o comando escreveu (o arquivo entra no registro de restauração), ou o
  comando deixa de escrever o que não é dele. A cura é no programa, não no teste; o teste só muda se ele estiver
  medindo algo errado, e a `## Execução` diz por quê.
- O `atualizar_sistema.sh limpar` na casa de brinquedo não lê o sistema real (o `.deb` vem de um caminho que o
  teste controla, ou o passo se registra para o restaurar).

## Prova
- `tests/restaurar.sh` verde inteiro, três vezes; `tests/todos.sh` sem vermelho aceito nele. Atualizar `00-leva.md`
  (a lista de vermelhos aceitos) no mesmo commit.

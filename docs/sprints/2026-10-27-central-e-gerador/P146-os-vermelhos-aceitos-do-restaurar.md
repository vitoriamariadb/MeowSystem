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

## Execução
- Medido: `pack_usar` deixava de devolver 3334 arquivos, todos novos (nenhum existente mudou); `desinstalar` o mesmo
  pelo VS Code. `sistema_limpar` não deu vermelho nas três rodadas desta sprint (o `.deb` só aparece onde o apt do
  sistema guarda o cosmic-comp), então não houve o que curar nele.
- Causas: `code --install-extension` escreve `~/.vscode/extensions`, `~/.config/Code` (logs, `machineid`, caches de
  VSIX) e `~/.dotnet/corefx` (CRLs da verificação de assinatura), sem registro; `instalar_fontes.sh` gravava as
  faces em `~/.local/share/fonts/MeowSystem` sem `meow_guardar_antes`; `compositor_patches.sh ativar|desativar`
  gravava e removia o shim `~/.local/bin/cosmic-comp` sem registro.
- Cura no programa, commit `21c1eb1b`: `meow_vigiar_inicio` e `meow_vigiar_fim` em `lib/restauro.sh` (lista o que
  existe antes e registra como `novo`/`pasta-nova` o que um comando externo criou; no seco não faz nada), usados em
  volta do `--install-extension` do `vscode/manifesto.sh`; `meow_guardar_antes` antes de cada gravação e remoção de
  fonte e do shim. O teste não mudou.
- Prova: `tests/restaurar.sh` verde inteiro três vezes (duas avulsas e a de dentro do `todos.sh`, 50 ações, «voltou
  byte a byte»). `./tests/todos.sh`: 119 de 120 verdes; o único vermelho é `readme.sh` (badge v2.2.0 e README velho,
  o coordenador regera na integração). `decisoes.sh` ficou verde. `00-leva.md` sem `restaurar.sh` nos aceitos.
- Fora: um usuário com VS Code em uso, ao restaurar, perde também os arquivos novos que o editor criou em
  `~/.config/Code` durante a janela do `--install-extension` (cache e log); o que já existia não é tocado.

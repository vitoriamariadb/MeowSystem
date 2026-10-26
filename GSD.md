# GSD — as regras invioláveis

Todo agente lê este arquivo antes de tocar no repositório. Cada regra abaixo tem prova em
`tests/decisoes.sh`: se alguém desfaz uma, a suíte fica vermelha.

## 1. Quem decide

- Decisão de quem usa só se desfaz com sim explícito sobre aquele tema.
- Frase genérica não autoriza. A GPU foi revertida em 18/09 por uma sessão sem sim; o pedido de 17/09 («tudo NVIDIA») valia.
- Sem resposta de quem usa, a decisão anterior continua valendo.
- Para desfazer: troque a linha do registro e o código que a lê, no mesmo commit, com o sim citado.

## 2. Princípios

- O doctor corrige. Nenhuma saída manda digitar.
- Interface sem texto: show, don't tell. Na tela, só nome curto, ícone, controle e prévia; o porquê vira dica ao passar o mouse e ao focar.
- Definitivo, modular, independente, idempotente: a segunda passada não escreve nada.
- Pack é dado, nunca código. Extensão de pack importado só se instala por gesto.
- A arte mora no pack. O mapa de ícone é do pack. Chave `ICONES_BASE` não volta.
- Pulado não é verde. Prova rodada para toda afirmação.
- Zero comentário; o porquê mora no nome, no teste e no commit; informação errada se sobrescreve no lugar, nunca se acrescenta.

## 3. As decisões

O registro é [`docs/DECISOES.md`](docs/DECISOES.md): uma linha por decisão que vale hoje.

## 4. Armadilhas

- `sudo` é `NOPASSWD: ALL` e escreve no sistema real. Teste que chama `sudo` não falha: escreve.
- Teste e QA usam HOME temporário, falsos no PATH que recusam escrita (`sudo`, `pkexec`, `su`, `apt`, `cargo`, `just`, `make`, `systemctl` de escrita, `pkill`) e nenhum barramento da sessão.
- Painel só com HOME temporário, PID próprio, nunca `--parar`.
- Não rode `install.sh`, `meow compositor` nem `meow doctor --consertar` com o HOME real.
- O gancho de commit troca palavras, às vezes dentro do código. Confira o diff de cada commit.
- `/tmp` some no reboot. O estado de um bloco mora num arquivo do projeto.
- Trabalhe na worktree e na branch do bloco, nunca no checkout principal.
- Senha nunca vai para arquivo, commit ou documento.
- Adicione por caminho. Nunca `git add -A` nem `git add .`.

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

O registro é [`docs/sprints/2026-10-09-uso-real/02-decisoes.md`](docs/sprints/2026-10-09-uso-real/02-decisoes.md),
decisões 1 a 17. As decisões 13 a 49 da leva H estão em
[`docs/sprints/2026-10-15-fechamento/P82-abertos.md`](docs/sprints/2026-10-15-fechamento/P82-abertos.md)
(a numeração colide com a de cima; cite o arquivo junto com o número).

| # | vale |
|---|---|
| 1 | base de ícones do Dracula: `circle` na frente, `main` atrás |
| 2 | PNG feito à mão vira vetor, medido por RMSE; o PNG sai só quando o vetor passa |
| 3 | o seletor mostra o acervo de todos os packs, o pack no ar primeiro |
| 4 | `calcdeirao` fica fora do pack; `jogos`, `rede` e `clima2` entram |
| 5 | askpass ativo; a senha nunca é escrita em arquivo, commit ou documento |
| 6 | GPU do compositor na RTX (`COSMIC_RENDER_DEVICE` no `/etc/environment`) |
| 7 | «Consertar» do doctor baixa com o selo de rede, sem caixa de pergunta |
| 8 | QA do painel só com HOME temporário |
| 9 | só pack do repositório instala extensão do VS Code; pack importado pede o gesto |
| 10 | «Restaurar ao padrão» grava o valor de fábrica e só aparece quando o valor difere |
| 11 | a interface nunca pede senha: a senha é só do install, e o root passa pela ponte (revoga a caixa do sudo de uma linha, sim de 23/10). Ampliada em 24/10: o reparo da ponte também não pede, pela reserva de root e um oneshot que o polkit libera («Não quero recolocar senha direto») |
| 12 | trocar de pack leva o ponteiro do pack |
| 13 a 17 | tudo para o pack, três pastas por pack, derivados que se atualizam, achados da varredura, repositório enxuto: guardados no registro; o código entra com a P87, a P88 e a P89 |

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

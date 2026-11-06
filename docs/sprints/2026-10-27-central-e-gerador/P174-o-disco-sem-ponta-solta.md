# P174 — o disco sem ponta solta (06/11/2026)

Achados da P165.

## O que se mediu

- O fim do build do compositor e do menu do Arquivos não chama a limpeza; só o doctor e o fim de build de applet.
- O Liberar confere a trava e depois apaga, sem segurar `builds.lock`: um build que comece nesse intervalo cai.
- `oraculo-builds` cresce um binário por revisão do libcosmic, sem teto.
- `~/.cache/meowsystem/cosmic-prever` guarda debs e fontes sem poda própria; só o corte de 7 dias parado o alcança.
- `scripts/temas-de-apps/spotify/RECUPERACAO.md` cita `backups/spotify-xpui-fabrica`, que nenhum script escreve.

## A cura

O fim de cada build chama a limpeza; o Liberar segura a trava do início ao fim; `oraculo-builds` guarda o em uso e um anterior; `cosmic-prever` entra no inventário com teto; o documento do Spotify diz o que existe de verdade.

## Como se prova

`tests/espaco.sh` com os casos novos, a trava provada com um build falso em andamento, e a segunda passada sem escrever nada.

## Execução

Feito, em 06/11/2026, na worktree `bloco/disco2`:

- `espaco.py` pega o `builds.lock` (flock sem espera) antes de cortar e o segura até o último corte, replanejando sob a trava. Trava presa por outro processo: o item fica para depois, com o aviso de sempre. Backups (rotação) não dependem dela.
- `ESPACO_TRAVA_FD`: o build que já segura a trava no fd 9 entrega esse fd, e o fim do build pode limpar sem se bloquear a si mesmo. O fd só vale se for o mesmo arquivo do `builds.lock`.
- `meow_limpar_fim_de_build` (lib/comum.sh) roda `espaco.py continua` no fim do build do compositor (`compositor_patches.sh compilar`) e do menu do Arquivos (`files_menu.sh build`).
- `oraculo-builds` ganhou o corte `recentes:2`: ficam a revisão de uso mais recente e uma anterior; pasta sem binário (build em andamento) não conta nem sai; o Liberar não toca.
- `previa-cache` ganhou teto de 1024 MB além do corte por ociosidade: acima dele sai primeiro a unidade de segundo nível mais antiga (`debs/*`, `x/*`, `src/*`), nunca a mexida há menos de 10 minutos; apertado, o teto cai à metade.
- `RECUPERACAO.md` do Spotify: some a linha de `backups/spotify-xpui-fabrica`, que nenhum script escreve; ficam os três lugares que existem.

Provas literais:

- `bash tests/espaco.sh` termina em `espaco: tudo certo`, com as seções novas 7 a 7d:
  - `a cada corte do Liberar o builds.lock está preso (2 presa)`
  - `com um build falso em andamento o Liberar não corta nada` e `e diz que fica para depois`
  - `segurando a trava do próprio build o fim do build corta`, `a segunda passada não diz nada` e `e não escreve nada` (hash de `find -printf` da casa antes e depois)
  - `ficam a mais nova e a anterior`, `a pasta de um build em andamento, sem binário, não conta nem sai`, `o Liberar não toca no oráculo em uso`
  - `saíram os três mais antigos, fontes e deb`, `o que sobra é só o mais novo, dentro do teto de 1 MB`, `o que acabou de ser mexido não sai, mesmo acima do teto`
- `etapa-compositor.sh`, `compositor-shim.sh`, `garantir-builds.sh`, `orfaos.sh`, `portabilidade.sh`, `higiene.sh`, `seco.sh`, `arvore.sh`, `acento.sh`, `estilo.sh` e `sem-receita-no-log.sh` terminam verdes.
- `decisoes.sh` tem 1 falha, `o registro pulou ou repetiu número`, igual com e sem este diff: o registro pula a 54.

Falta da mão de quem usa:

- Depois do install e do reboot, abrir Ajustes > Disco e conferir que o Liberar corta o que se reconstrói e que, com um build do compositor correndo, diz que fica para depois.
- Conferir em `~/.local/libexec/meow/oraculo-tema` que sobram só a revisão em uso e uma anterior depois do primeiro `meow doctor`.
- Conferir que `~/.cache/meowsystem/cosmic-prever` não passa de 1 GB.
- O teto de 1024 MB do `cosmic-prever` é palpite sem medida da máquina real; ajuste se o tamanho real pedir.

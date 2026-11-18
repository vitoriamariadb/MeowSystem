# Estado da leva de 18/11 (coordenador)

Árvore desta leva: `../.meow-wt-leva-18`, branch `docs/leva-2026-11-18`.

Resposta de quem usa, 18/11, às sprints: «o tema nativo no note dela deveria ser o meowsystem igual no meu deveria
ser o dracula. default do install. Mas enfim. Pode disparar os agentes pra termos o produto final concluido?» Depois,
à pergunta do P241 (AskUserQuestion, 18/11): «As duas coisas»: o código passa a herdar e os dois PCs dela voltam ao
pack `meowsystem`.

| bloco | tarefas | situação |
| --- | --- | --- |
| A vagas | P242, P246, P241 | implementado em `7aa71d8c` (`../.meow-wt-vagas`, `bloco/vagas`): 15 afetados verdes; o conferente (agente, high) confere e corrige desde 16h10, com a suíte inteira |
| B applets e arte | P243, P247 | escritas; pedem quadro de arte aprovado antes de qualquer agente |
| C CI | P244 | implementado em `9b4f4f42` (`../.meow-wt-ci3`, `bloco/ci3`): os 6 vermelhos verdes num `ubuntu:26.04` limpo, suíte portátil 128 verdes, 2 pulados, 0 vermelhos em 56m15s, limite do workflow em 80 min; conferido pelo coordenador (8 afetados verdes na máquina de casa, mais `e803ca21`: o doctor procura o Papirus na mesma raiz que o install) e **integrado** em `be2cedfe` |
| D doctor e documentos | P245, P248, P249, P250 | árvore `../.meow-wt-doctor-docs`, `bloco/doctor-docs`, no ar desde 18/11 18h20; implementa (agente, high) → confere e corrige (agente, high) |
| E portal | P251 | escrita; achado do install de 18/11 |

Quatro agentes nesta primeira rodada (dois por bloco, em sequência dentro do bloco; A e C ao mesmo tempo, com
arquivos disjuntos). Tudo o que está nos arquivos das sprints foi medido pelo coordenador, só com leitura.

## Feito pelo coordenador em 18/11 (15h20 a 15h35), por SSH
- Desktop: `git pull` (`9ed03775`), `meow pack usar meowsystem` (flavor `mocha`): 2 passagens, 75 etapas, nada mais a
  escrever. O tema passou de 0 para 340 `*-symbolic.svg`. O doctor só acusa «patches: build pronto, vale no próximo
  login».
- Portátil: `git pull` (`9ed03775`), `PACK="meowsystem"` e `FLAVOR="mocha"` gravados pelo `meow pack usar`, que saiu
  na trava de outro `meow`; depois `./install.sh`: 3 passagens, 75 etapas, nada mais a escrever. 340 `*-symbolic.svg`.
  O compositor com a série nova compila em segundo plano. Doctor sem divergência.
- Nos dois, o `meow.conf` de antes ficou em `~/.config/meow/meow.conf.antes-do-pack-de-fabrica-2026-11-18`, e o pack
  pessoal continua em `~/.local/share/meowsystem/packs/`. Voltar: `meow pack usar meu-tema` (desktop) ou
  `meow pack usar meu-meow-portatil` (portátil).

## Gestos que faltam
1. Desktop e portátil: sair e entrar na sessão, para o compositor novo e os ícones da barra.
2. nitro-5: fechar Chrome e Edge e rodar `./install.sh --etapa apps` (o `chromium` ficou pendente).
3. Com o ok de quem usa: tirar as 19 árvores `.meow-wt-*` da leva de 17/11, já integradas.

## O que foi rodado nas máquinas dela nesta medição
Só leitura: `meow doctor` (sem `--consertar`), `find` no tema de ícones, leitura do `meow.conf`, do `pack.json` e do
log. Uma chamada direta a `scripts/icones_sistema.sh --conferir` em cada PC da Vitória, sem o `meow.conf` carregado: o
resultado dela («340 a instalar») não vale como medida, porque sem o conf o script adota o pack `meowsystem`; a
contagem de simbólicos depois dela continuou 0 nos dois.

## O que o bloco C achou (18/11)
- O `ubuntu-latest` do GitHub já é o Ubuntu 26.04 (coreutils do uutils), não o 24.04.
- Causas: checkout raso sem os commits antigos e sem as tags (`chaves-aposentadas`, `deb`); o `sleep` do uutils
  copiado com outro nome sai na hora (`trava-herdada`); o teste lia a fonte, o `cosmic-comp` e o Papirus da máquina
  (`doctor-veredito`, `garantir-builds`, `maquina-nova`).
- Imagem de contêiner para repetir: `localhost/meow-ci3-base` (podman, com `--init` e a pasta `/run/user/1001/systemd`).
- Fora do escopo, para uma sprint futura: `tests/seco.sh` depende de `systemd --user`; o `tests/temas-de-apps.sh`
  depende de o PID 1 colher processo morto; `estilo.sh` e `extensoes-install.sh` seguem pulados no runner.

## Próximo passo
1. A árvore de integração é `../.meow-wt-integracao-18` (`integracao/2026-11-18`), já com os documentos da leva.
2. Bloco C: integrado. A prova no runner de verdade é o run do push final.
3. Bloco A: entra quando o conferente voltar com a suíte inteira e a folha dos ícones.
4. Bloco D em voo; depois o E (P251). Bloco B só depois do quadro de arte aprovado.
5. No fim: suíte inteira na integração, `master`, push, run verde no GitHub (número aqui), install nos três PCs pelo
   coordenador.

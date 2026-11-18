# Estado da leva de 18/11 (coordenador)

Árvore desta leva: `../.meow-wt-leva-18`, branch `docs/leva-2026-11-18`.

Resposta de quem usa, 18/11, às sprints: «o tema nativo no note dela deveria ser o meowsystem igual no meu deveria
ser o dracula. default do install. Mas enfim. Pode disparar os agentes pra termos o produto final concluido?» Depois,
à pergunta do P241 (AskUserQuestion, 18/11): «As duas coisas»: o código passa a herdar e os dois PCs dela voltam ao
pack `meowsystem`.

| bloco | tarefas | situação |
| --- | --- | --- |
| A vagas | P242, P246, P241 | implementado em `7aa71d8c` (`../.meow-wt-vagas`, `bloco/vagas`): 15 afetados verdes; o conferente (agente, high) confere e corrige desde 16h10, com a suíte inteira (começou 18h15; log em `scratchpad/conf/vagas-suite.log`); 3 correções dele por cima (`626ab324`, `55e4f7ee`, `00b2b10f`); a folha dos ícones foi vista pelo coordenador e está boa |
| B applets e arte | P243, P247 | `../.meow-wt-arte-vagas`, `bloco/arte-vagas` (nasce do `bloco/vagas`): um agente desenha as vagas e monta a folha desde 18/11 19h; nada entra no `master` sem a folha aprovada por quem usa; os applets (código e publicação) só depois |
| C CI | P244 | implementado em `9b4f4f42` (`../.meow-wt-ci3`, `bloco/ci3`): os 6 vermelhos verdes num `ubuntu:26.04` limpo, suíte portátil 128 verdes, 2 pulados, 0 vermelhos em 56m15s, limite do workflow em 80 min; conferido pelo coordenador (8 afetados verdes na máquina de casa, mais `e803ca21`: o doctor procura o Papirus na mesma raiz que o install) e **integrado** em `be2cedfe` |
| D doctor e documentos | P245, P248, P249, P250 | conferido (18 afetados e da área verdes; o conferente tirou duas linhas da P249 em `6f68ebe0`) e **integrado** em `6626b957`; decisão 45 com a exceção do pull, sim de 18/11 (`f146793f`) |
| E portal | P251 | escrita; achado do install de 18/11 |
| F painel | P252 | pedido de quem usa em 18/11 19h20 («Vira Sprint e dispara agora»): `../.meow-wt-painel-teto`, `bloco/painel-teto`; implementa (agente, high) → confere e corrige (agente, high) |

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

## O que o bloco D achou (18/11)
- P245: no conserto das 5h, o `janeladock` escreveu duas pontes depois de o `lancador` já ter conferido `ok`, e o
  laço só consertava o que estava fora no começo.
- P250: a captura da porta Modificações muda 3,29% de uma máquina para outra (apps instalados); a cura escolhida é o
  gancho pós-merge não regerar quando o `master` só alcança o `origin/master`. O coordenador leu a decisão 45 e
  entende que a cura cabe nela (o pull traz o que quem empurrou já regerou); a linha não foi trocada.
- P249: três linhas `saida` novas (atalhos da Steam, painel fantasma do Spellbook, libadwaita do Flatpak). O doctor
  das 5h as aplica sozinho, com cópia de antes.
- Itens de fila para a Vitória, ainda por lançar com `irmaos fila add --para vitoria`: o Alt+F2 do
  `aurora-reiniciar-painel.sh`; o trecho do lançador do Chrome no `ritual-aurora-self-heal.sh` (marcar revisado); o
  `aurora-greeter-watchdog.sh` (marcar revisado); no portátil, os quatro itens que voltaram em 27/10 20:23:45.
- Fora do escopo, para sprint futura: `atalho.sh`, `icones_resgatados.sh` e as sombras não refazem o
  `mimeinfo.cache` fora do doctor e do install; a captura de Modificações depende dos apps da máquina; a árvore de
  arquivos do `app/LEIA-ME.md` não lista `modificacoes.js`; o `_refs` do `vizinhos.sh` não exclui `install_if_diff`.

## Próximo passo
1. A árvore de integração é `../.meow-wt-integracao-18` (`integracao/2026-11-18`), já com os documentos da leva.
2. Bloco C: integrado. A prova no runner de verdade é o run do push final.
3. Bloco A: entra quando o conferente voltar com a suíte inteira e a folha dos ícones.
4. Bloco D: integrar quando o conferente voltar. Quando o A fechar, lançar o agente do quadro de arte do bloco B
   (folha para quem usa aprovar); quando o D fechar, o E (P251).
5. No fim: suíte inteira na integração, `master`, push, run verde no GitHub (número aqui), install nos três PCs pelo
   coordenador.

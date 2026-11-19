# Estado da leva de 18/11 (coordenador)

Árvore desta leva: `../.meow-wt-leva-18`, branch `docs/leva-2026-11-18`.

Resposta de quem usa, 18/11, às sprints: «o tema nativo no note dela deveria ser o meowsystem igual no meu deveria
ser o dracula. default do install. Mas enfim. Pode disparar os agentes pra termos o produto final concluido?» Depois,
à pergunta do P241 (AskUserQuestion, 18/11): «As duas coisas»: o código passa a herdar e os dois PCs dela voltam ao
pack `meowsystem`.

| bloco | tarefas | situação |
| --- | --- | --- |
| A vagas | P242, P246, P241 | conferido e **integrado** em `2594c5f8` (`bloco/vagas` até `d4f2eca6`). Suíte inteira do conferente: 166 verdes, 1 pulado, 3 vermelhos; dois corrigidos no bloco (`104daa84` galeria com a semente da decisão 63; `d4f2eca6` a licença do papel vira dica); o `app-layout.py` segue vermelho com a máquina carregada e virou a P254 |
| B applets e arte | P243, P247, P253 | arte aprovada por quem usa («tudo aprovado», 18/11) em `bloco/arte-vagas` (`../.meow-wt-arte-vagas`, até `97bd769e`); o punhal e as luas do Dracula no mapa; quatro propostas do MeowSystem para o desligar e os três pontos no quadro <https://claude.ai/artifact/XecxYq2wNqphzvJ7dBdRzj#meowsystem> (sem escolha, fica o de hoje). Em voo desde 21h50: o implementador dos applets (agente, high), em `../meowsystem-performance-p243` e `../meowsystem-leitura-p243`, commit sem push. Faltam: o conferente do bloco, a publicação pelo desktop da Vitória, os pinos e a foto no palco |
| C CI | P244 | implementado em `9b4f4f42` (`../.meow-wt-ci3`, `bloco/ci3`): os 6 vermelhos verdes num `ubuntu:26.04` limpo, suíte portátil 128 verdes, 2 pulados, 0 vermelhos em 56m15s, limite do workflow em 80 min; conferido pelo coordenador (8 afetados verdes na máquina de casa, mais `e803ca21`: o doctor procura o Papirus na mesma raiz que o install) e **integrado** em `be2cedfe` |
| D doctor e documentos | P245, P248, P249, P250 | conferido (18 afetados e da área verdes; o conferente tirou duas linhas da P249 em `6f68ebe0`) e **integrado** em `6626b957`; decisão 45 com a exceção do pull, sim de 18/11 (`f146793f`) |
| E portal | P251 | escrita; achado do install de 18/11; sem agente ainda |
| G suíte | P254 | escrita; achado do conferente do bloco A; sem agente ainda |
| F painel | P252 | conferido (`caef6e31`, 18 afetados verdes) e **integrado** em `dc22d796`; no `master` no push 3 |

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

## Ordem de quem usa, 18/11 23h10
«mergeia e pusha assim que cada workflow concluir»: cada bloco vai ao `master` e ao GitHub assim que o conferente
dele volta, sem esperar a suíte inteira do fim. Antes de cada push, os testes de cruzamento rodam na integração.

- Push 1, 18/11 23h34: blocos A, C e D e os documentos, `9ed03775..35e3dc98`. Cruzamento na integração: 12 verdes
  (`decisoes`, `higiene`, `acento`, `git-limpo`, `numeros`, `readme`, `ganchos`, `vizinhos`, `pacotes-numa-lista`,
  `icones-do-sistema`, `pack-pessoal-veste-o-pai`, `nada-manda-digitar`). Run `testes` do GitHub 44445246406, em
  57 min: 128 verdes, 2 pulados (`estilo.sh`, `extensoes-install.sh`), 1 vermelho (`chaves-aposentadas.sh`). Antes
  da P244 eram 6 vermelhos.
- Causa do vermelho: o teste lia o bloco antigo do `meow.conf.exemplo` em `18c1d88^`, commit que só existe nas tags
  `v2.0.0` e `v2.1.0` desta máquina (o GitHub não tem essas duas tags; o tronco de lá tem o mesmo commit como
  `a43d7538`). O contêiner da P244 foi montado a partir do repositório local e por isso não acusou.
- Push 2, 19/11 00h50: `8adaae50`, o teste lê `a43d7538^`; verde num clone limpo do GitHub. Run `testes` 44452282392, em
  50 min: **129 verdes, 2 pulados, 0 vermelhos**. A P244 está provada no runner de verdade.

- Push 3, 19/11 madrugada: bloco F (`bloco/painel-teto` até `caef6e31`, integrado em `dc22d796`). A cota de
  reciclagens e a marca do aviso só voltam depois de 10 minutos seguidos de barra desenhando. Na integração, com a
  máquina livre: 23 verdes de 24 (os 18 afetados do bloco, `git-limpo`, `app-uso-real`, `galeria-do-papel`,
  `app-navegador`, `extensoes-pagina`); `app-layout.py` segue vermelho na linha 272 mesmo sem carga: a P254 é
  defeito de verdade, não só carga. O conferente do F não mandou relatório; a linha do `docs/DECISOES.md` da P252
  segue por escrever.
- Bloco E (P251) em voo desde 19/11 01h55: implementador (agente, high) em `../.meow-wt-portal`, `bloco/portal`.

## Próximo passo
1. A árvore de integração é `../.meow-wt-integracao-18` (`integracao/2026-11-18`, `2594c5f8`): documentos, C, D e A.
2. Bloco F: integrar `bloco/painel-teto` quando o conferente voltar; decidir a linha do `docs/DECISOES.md` da P252.
3. Bloco B: quando o implementador dos applets voltar, lançar o conferente (arte, mapa, procedência, contrato,
   applets); depois o coordenador publica os applets pelo desktop da Vitória (`ssh maria`, como no P231), troca os
   pinos e tira a foto da barra no palco. Ler a coleção `escolhas` do quadro antes de fechar.
4. Blocos E (P251) e G (P254): lançar quando houver vaga (no máximo dois blocos ao mesmo tempo). A P254 pede a
   máquina livre: `uptime` abaixo de 4 antes de medir.
5. Cada bloco que fecha: integração, cruzamento, `master`, push, run do GitHub anotado aqui.
6. No fim: suíte inteira no `master` com a máquina livre e install nos três PCs pelo coordenador.

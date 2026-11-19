# Estado da leva de 18/11 (coordenador)

Árvore desta leva: `../.meow-wt-leva-18`, branch `docs/leva-2026-11-18`.

Resposta de quem usa, 18/11, às sprints: «o tema nativo no note dela deveria ser o meowsystem igual no meu deveria
ser o dracula. default do install. Mas enfim. Pode disparar os agentes pra termos o produto final concluido?» Depois,
à pergunta do P241 (AskUserQuestion, 18/11): «As duas coisas»: o código passa a herdar e os dois PCs dela voltam ao
pack `meowsystem`.

| bloco | tarefas | situação |
| --- | --- | --- |
| A vagas | P242, P246, P241 | conferido e **integrado** em `2594c5f8` (`bloco/vagas` até `d4f2eca6`). Suíte inteira do conferente: 166 verdes, 1 pulado, 3 vermelhos; dois corrigidos no bloco (`104daa84` galeria com a semente da decisão 63; `d4f2eca6` a licença do papel vira dica); o `app-layout.py` segue vermelho com a máquina carregada e virou a P254 |
| B applets e arte (no `master`, push 4) | P243, P247, P253 | arte aprovada por quem usa («tudo aprovado», 18/11) em `bloco/arte-vagas` (`../.meow-wt-arte-vagas`, até `97bd769e`); o punhal e as luas do Dracula no mapa; quatro propostas do MeowSystem para o desligar e os três pontos no quadro <https://claude.ai/artifact/XecxYq2wNqphzvJ7dBdRzj#meowsystem> (sem escolha, fica o de hoje). Em voo desde 21h50: o implementador dos applets (agente, high), em `../meowsystem-performance-p243` e `../meowsystem-leitura-p243`, commit sem push. Faltam: o conferente do bloco, a publicação pelo desktop da Vitória, os pinos e a foto no palco |
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

- Bloco B, 19/11 madrugada: os quatro applets publicados pelo desktop da Vitória com a identidade dela, mesma árvore
  conferida (o Performance leva a mais o commit da captura que já estava no GitHub): Performance `422bd52` (0.2.1),
  Leitura `c7e0323` (0.2.2), conta-gotas `534c5d6` (0.6.5), Bandeja `cae8c63` (1.7.3). O gancho de push de lá só
  aceita o remoto `git@github.com-personal:…`; com ele o push passou. Pinos em `d23f2f75`, integrado em `f6aa2d8a`.
  O conferente do bloco parou de responder às 23h59 com os pinos por fechar; o coordenador fechou. Testes dos applets
  (`~/.cache/arte-confere/final.rc`): 24, 12, 11 e 299 verdes.
- Bloco G (P254) em voo desde 19/11: implementador (agente, high) em `../.meow-wt-layout`, `bloco/layout`.
- Push 3: run `testes` 44462676122, vermelho só pela medida com o home escrito (ver o push 4).

- Push 4, 19/11 madrugada: bloco B, `ae0ba2bb..686d43c3`. Na integração: 24 verdes na primeira rodada e 14 na
  segunda, depois de três vermelhos curados: `extensoes-install.sh` e `nomes-dos-applets.sh` não achavam nesta
  máquina os commits publicados (rodados com `EXTENSOES_FORKS=~/Desenvolvimento` e uma pasta de fontes temporária;
  depois do install real acham sozinhos); `higiene.sh` acusava o home de pessoa na medida do portal (erro do
  coordenador, curado em `e7cae85b`; o run 44462676122 do push 3 deve sair vermelho por isso); `icones-por-pack.py`
  mostrou que a prévia da aba Sistema engrossava todo traço para 2,5 fixo, curado em `47cda2b6` (a prévia usa o
  traço que o pack declara, como o install). Run `testes` do push 4, 44466429907: **129 verdes, 2 pulados, 0 vermelhos**. O do push 3 (44462676122) fechou com 2 vermelhos, `portabilidade.sh` e `higiene.sh`, só pelo home escrito na medida.

## Ordem de quem usa, 19/11 03h45
«Ao finalizar o push desliga o pc»: fechado o último push da leva (blocos E e G), o coordenador desliga o nitro-5.
O install do nitro-5 e a suíte inteira ficam para a sessão seguinte. Desktop da Vitória: `git pull` para `686d43c3` e
`./install.sh` começado às 03h52 por SSH, solto da sessão (log em `~/.cache/meow-leva/install-2026-11-19.log` de lá).

## Push 5, 19/11 04h15: blocos E e G
- E (P251, `bloco/portal`, `944faf43` e `b8872714`), integrado em `80c4ff9a`: o `patches/graficos.versao` aceita
  «fim <versão> <patch>»; do portal `6e68360` em diante o remendo do toolkit sai da série, porque o `Cargo.lock`
  de lá já fixa a correção oficial; o remendo do portal entra limpo em `f448ddf`, `6e68360` e `7b0864c`; compilou
  no fonte do `7b0864c` em 3 min 51 s. O «sem rede?» do desktop era de antes do `a0f08935` (07/11); o teste passa a
  cobrir a resposta do apt em português. Na integração: 12 verdes e 1 pulado (`graficos-fonte-real.sh`, sem o fonte
  no lugar que o teste procura). O relatório do implementador não chegou; o item 3 da tarefa (o build posto de
  lado no desktop sem queda registrada) fica sem resposta e segue aberto.
- G (P254, `bloco/layout`), integrado em `34678a36`: `51bafefd` dois cliques no Desfazer não desfazem a mesma
  mudança duas vezes; `a6909dd9` gravar uma chave leva 0,05 s e não 2,6 s (o `meow_conf_texto_definir` copiava o
  texto inteiro a cada uma das 2184 linhas); `f58ef98f` o trabalho pedido logo depois de gravar espera a aplicação.
  `app-layout.py` verde na integração (183 s); `app-completo.py` do implementador em 945 s (eram 1797 s).
- Cruzamento na integração: 15 verdes de 15.

## 19/11 de manhã: o que ficou devendo na madrugada e as respostas de quem usa
- O coordenador ficou parado das 05h14 às 10h57: a espera pela segunda prova do `app-completo.py` procurava o
  processo pelo nome e o próprio comando de espera continha o nome. O nitro-5 não foi desligado. Às 10h58 quem usa
  disse «Não desliga não».
- `fe4742b4` (bloco G): o `app-completo.py` lia a torrada «Salvo; falta permissão de sistema» do gesto anterior
  como resposta do acervo de cursor; o teste passa a contar só as torradas que nasceram do envio dele. Primeira prova
  do implementador verde (925 s); o log da segunda sumiu com a limpeza do cache dele.
- Push 5: run `testes` 44477612054, **129 verdes, 2 pulados, 0 vermelhos**, com os sete blocos.
- Desktop da Vitória, install de 19/11 03h52: «Pronto. 3 passagens, 75 etapas, nada mais a escrever.» O doctor de lá
  acusa o compositor compilando (vale no próximo login) e `files_menu removeria ~/.local/bin/cosmic-files`, que o
  conserto das 5h acerta.
- Respostas (AskUserQuestion, 19/11): install no nitro-5 «Instala e fecha antes» (o coordenador fecha Chrome e Edge
  e instala); a regra do painel «Sim, registra» (decisão 64, `7f1720b6`); o desligar do MeowSystem «Orelhas»
  (`132998b7`); os três pontos do MeowSystem «O de hoje».

## Ressalvas da leva (para não se perderem)
1. Os blocos E (P251) e G (P254) não tiveram conferente separado: o coordenador leu os commits e rodou os afetados
   e o cruzamento. Fica devendo um conferente (agente, high) para `944faf43`, `b8872714`, `51bafefd`, `a6909dd9`,
   `f58ef98f` e `fe4742b4`.
2. Quatro agentes não entregaram o relatório final ao coordenador, mesmo pedido de novo: o conferente do F
   (`painel-confere`), o conferente do B (`arte-confere`, parou às 23h59 de 18/11 com os pinos por fechar), o
   implementador do E (`portal-implementa`) e o implementador do G (`layout-implementa`). O que se sabe deles vem dos
   commits e dos logs.
3. P251, item 3: por que o build do portal foi posto de lado no desktop sem queda registrada segue sem resposta; e
   o `graficos_estado` do desktop depois do install de 19/11 não foi lido.
4. `graficos-fonte-real.sh` ficou pulado na integração (sem o fonte onde o teste procura); o implementador diz no
   commit que o rodou nas três versões pelo fonte do git.
5. A suíte inteira não rodou com os sete blocos juntos; rodaram os afetados de cada bloco, os cruzamentos e o CI
   portátil do GitHub.
6. `extensoes-install.sh` e `nomes-dos-applets.sh` só acham os commits novos dos applets nesta máquina depois do
   install real; antes disso foram rodados com `EXTENSOES_FORKS` e uma pasta de fontes temporária.
7. O portátil estava fora da rede em 19/11: pull, install e doctor de lá ficam devendo.
8. O coordenador mandou ao `master`, no push 3, uma medida com o home de pessoa escrito; o CI acusou e o push 4
   corrigiu.

## Próximo passo
1. `app-completo.py` verde na integração com o `fe4742b4`; juntar o `132998b7` e o `7f1720b6`; push 6; run do
   GitHub anotado aqui.
2. nitro-5: fechar Chrome e Edge e rodar `./install.sh` (ordem de quem usa, 19/11); foto da barra e da dock nos
   dois packs.
3. Conferente dos blocos E e G (ressalva 1) e a resposta do item 3 da P251 (ressalva 3).
4. Suíte inteira no `master` com a máquina livre.
5. Portátil, quando voltar à rede: `git pull`, `./install.sh`, `meow doctor`.
6. Gestos de quem usa: sair e entrar na sessão no desktop, no portátil e, depois do install, no nitro-5.
7. Com o ok de quem usa: tirar as árvores `.meow-wt-*` das levas de 17/11 e de 18/11, já integradas.

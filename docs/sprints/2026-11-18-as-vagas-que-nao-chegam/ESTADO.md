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

## 19/11, 11h20: pushes 6 e 7, dois blocos novos e o install do nitro-5
- Push 6 (`eb90e6b9..db158182`): as ressalvas e o `fe4742b4`; run `testes` 44540348774 (resultado a anotar).
- Na integração, com o `fe4742b4`: `app-completo.py` (936 s), `app-layout.py`, `grava-ao-soltar.py`, `higiene.sh` e
  `git-limpo.sh` verdes. Cruzamento antes do push 7: 13 de 13.
- Push 7 (`db158182..b70e584e`): «Orelhas» no desligar do MeowSystem e a decisão 64.
- Pedidos de quem usa em 19/11, viraram sprint e bloco: P255 (o PC se atualiza sozinho ao ligar; resposta «Só com
  o CI verde»), implementador (agente, high) em `../.meow-wt-atualiza`, `bloco/atualiza`; P256 (os botões de janela
  do MeowSystem; resposta «Outra metáfora de gato, mais simples», e a prova «numa janela real», no palco), o
  desenhista em `../.meow-wt-botoes`, `bloco/botoes`, primeiro commit `dff78128`.
- Quadro de arte, versão 3: as escolhas de 19/11 e o grupo dos botões de janela (só os de hoje, por enquanto).
- nitro-5: o conserto das 5h de 19/11 já tinha compilado a Bandeja, o Leitura e o Performance novos (05h18); o
  conta-gotas ficou no meio. Às 11h20 o coordenador fechou o Chrome (pedido de saída normal; não havia Edge) e
  começou o `./install.sh` completo (log em `~/.cache/meow-leva/install-nitro5-2026-11-19.log`).

## 19/11, 12h55: o que entrou depois do almoço
- CI dos pushes 6 e 7 verde (44540348774 e 44543622594).
- nitro-5: install de 11h20 limpo (2 passagens, 75 etapas), os quatro applets no pino novo. Portátil: voltou à rede,
  `git pull` para `b70e584e` e install limpo (3 passagens, 75 etapas).
- P255 (`bloco/atualiza`: `7740fe3c`, `b9c3d239`, e do coordenador o `32fc4723`): revisão do coordenador achou que o
  install saía recusado quando outro `meow` pegava a trava logo depois do pull (a corrida medida à mão no desktop);
  agora espera a vez, com teste vermelho sem a cura. Decisão 65 no registro. O implementador não mandou relatório.
- P256 (`bloco/botoes`): dois conjuntos (A, orelhas; B, rabo), em área preenchida porque o GTK do Firefox e do
  Chrome só pinta preenchimento, com foto de janela real no palco (`scratchpad/botoes/barras-lado-a-lado.png`) e no
  quadro (versão 4). Resposta de quem usa: «A, orelhas», e depois «Usa o conjunto A. E o windows close usa o x
  atual»: no mapa, minimizar, maximizar e restaurar são as orelhas e o fechar segue no X de antes (`fec598f0`).
- Limpeza pedida por quem usa («deletar o que foi mergeado e pushado»): 23 árvores e branches do MeowSystem que já
  estavam no `origin/master` e as 5 árvores dos applets publicados saíram. Ficaram `.meow-wt-ci2` (3 commits fora
  do `master`), `.meow-wt-soberana` e `.meow-wt-arte` (rascunhos sem commit).
- Ordem para o fim (19/11): «no terminal roda o comando atualizar com o askpass e veja se quebrou algo do
  meowsystem e se a build vai funcionar certinho. Faz isso só ao final.» O `atualizar` é a função do zsh
  (`~/.config/zsh/functions/sistema.zsh`).

## 19/11, 13h05: push 8
- `master` = `origin/master` = `a5976f57`: P255 (`7740fe3c`, `b9c3d239`, `32fc4723` e o prefixo `AT_` no
  `tests/app.sh`), P256 (minimizar, maximizar e restaurar nas orelhas; o fechar no X de antes) e os documentos que só
  existiam em árvores antigas (P182, P204 da suíte, P206, P207, P208).
- Cruzamento na integração: 27 pedidos, 26 verdes e o `app.sh` vermelho (prefixo `AT_` fora das internas); curado,
  rodada de confirmação de 14, toda verde.
- Run `testes` do push 8: 44562290665 (em curso às 13h05).
- Suíte inteira no `a5976f57`, na árvore de integração, desde 13h04 (`scratchpad/suite-inteira-a5976f57.log`).
- Desktop e portátil: `git pull` para `a5976f57` e install lançado às 13h07
  (`~/.cache/meow-leva/install-push8-2026-11-19.log` em cada um). O do nitro-5 espera a suíte inteira.
- Árvores: saíram também `.meow-wt-ci2`, `.meow-wt-soberana`, `.meow-wt-arte` e a branch `bloco/ci` (o código já
  estava no `master` em versão mais nova). Restam `atualiza`, `botoes`, `integracao-18` e `leva-18`.

## 19/11, 13h20: a P257 aberta
- A revisão automática de segurança do push 8 apontou que a atualização ao ligar roda o install com root sem prova
  de quem escreveu o commit. Resposta de quem usa (AskUserQuestion): «Assinatura na próxima leva». A P255 segue
  ligada; a cura é a `P257-a-atualizacao-so-avanca-para-commit-assinado.md`, bloco da próxima leva.
- Quadro de arte na versão 5, com a escolha dos botões de janela.

## 19/11, 13h55: dois blocos novos em voo, por ordem de quem usa
- Desktop e portátil: install do push 8 limpo (2 passagens, 76 etapas), `meow-atualiza.timer` armado nos dois
  (próxima volta 20/11 13h08); a primeira volta, disparada ao armar, saiu 0 sem tocar em nada.
- P258 (`bloco/papeis-gatos`, árvore `.meow-wt-papeis-gatos`, agente `papeis-gatos`): papéis de parede em camadas
  certas e os gatos como a Coquinha e o Mimir. Fotos em `scratchpad/papeis-p258/`.
- P259 (`bloco/lateral`, árvore `.meow-wt-lateral`, agente `lateral-arquivos`): os ícones da lateral do Arquivos nos
  dois packs. Fotos em `scratchpad/lateral-p259/`.
- Arquivos disjuntos: `packs/*/wallpapers` e `packs/*/icones`. Sem conferente separado: o coordenador confere pelas
  folhas e pelos testes, e quem usa aprova a arte no quadro.

## 19/11, 13h35: três blocos em voo
- P258 (`papeis-gatos`) ganhou o castelo sem chão e os efeitos fora do corte; P259 (`lateral-arquivos`) ganhou o
  minimizar do MeowSystem (não se lê em 16 px; tem que ocupar a caixa como o morcego do Dracula) e a lupa.
- P260 (`bloco/lado`, árvore `.meow-wt-lado`, agente `lado-botoes`): chave `BOTOES_LADO`, padrão `direita`. Resposta
  de quem usa: «Direita já, esquerda medida depois». Fica para o coordenador: tirar o `aurora-button-layout` do zsh
  da Vitória pelo espelho e desarmar a unidade nos dois PCs dela.
- P261 (próxima leva, a escrever): medir o custo da esquerda em todo app do COSMIC (patch na libcosmic e build por app).
- Às 13h34: run 44562290665 em curso; suíte inteira com 58 testes rodados e nenhum vermelho.

## 19/11, 14h35: push 8 verde, suíte inteira lida, quatro pulados curados
- Run 44562290665 (push 8) verde: 130 verdes, 2 pulados (`estilo.sh`, `extensoes-install.sh`), 0 vermelhos, 67 min.
- Suíte inteira no `a5976f57`: 171 testes, 168 verdes, 1 vermelho (`resultado-na-linha.py`: a conferência `atualiza`
  sem nome curto no `NOME_DA_CONFERENCIA`; curado no `014ffa86`, e a `botoeslado` da P260 no `d7cdb72d`) e 2 pulados
  (`graficos-fonte-real.sh`, `dock-fonte-real.sh`).
- Ordem de quem usa: «Problema legado já resolve na hora também». Os dois do CI: `bloco/ci4` `79177ed3` (o runner
  ganha `papirus-icon-theme`, `just` e os clones dos dez forks; pulado na suíte portátil vira vermelho). Os dois
  locais: faltavam em `~/.local/src` os commits `6e68360` e `7b0864c` do portal e o clone do `cosmic-applets`
  (`6f89bfa`); buscados à mão no nitro-5, os dois testes rodam verdes sem pular. Fica aberto: nada no produto cria
  esses clones, então máquina nova volta a pular (sprint da próxima leva).
- Com isso a série do portal está provada no fonte real das três versões (`f448ddf`, `6e68360`, `7b0864c`): fecha a
  ressalva do `graficos-fonte-real.sh` pulado.
- P258, P259 e P260 prontas (agentes parados, sem relatório; conferidas pelos commits, testes e folhas). P258 aprovada
  por quem usa. Integradas com `bloco/atualiza` e `bloco/ci4` em `integracao/2026-11-18` (`8d3907d5`); cruzamento de
  35 testes em curso (`scratchpad/integra-9.log`).

## 19/11, 15h10: push 9 e install nos três PCs
- `master` = `origin/master` = `fbde5363`: P258 (papéis em camadas certas, Mimir de dia e Coquinha de noite), P259
  (lateral e barra do Arquivos, minimizar, maximizar e restaurar maiores, lupa com orelhas no MeowSystem e com o
  morcego dentro da lente no Dracula, `e0a66de2`), P260 (`BOTOES_LADO`, decisão 66), `79177ed3` (CI sem pulado) e os
  nomes curtos das conferências `atualiza` e `botoeslado`.
- Aprovação de quem usa, 15h00: «APROVADO. EM TODOS ELES. ESSES SVGS NOVOS. INSTALA NOS 3 PCS.»
- Cruzamento na integração: 35 de 35 verdes; confirmação com a lupa: 10 de 10. Run `testes` do push 9: 44584677965.
- Zsh da Vitória pelo espelho, `ba12eaf`: `BTN_TARGET` do ritual e `TARGET` do `aurora-button-layout.service` em
  `:minimize,maximize,close`. Às 15h10 ainda pendente de entrega pelo `irmaos`. A cópia instalada da unidade em
  `~/.config/systemd/user` só troca quando o ritual dela roda: conferir, senão ela devolve a esquerda em 5 min.
- Install do push 9 lançado às 15h09 nos três (`~/.cache/meow-leva/install-push9-2026-11-19.log` nos PCs da
  Vitória, `install-push9-nitro5-2026-11-19.log` no nitro-5).

## 19/11, 15h20: push 9 instalado nos três PCs
- nitro-5: install limpo (2 passagens, 77 etapas); papéis do Dracula semeados de novo às 15h09, ícones novos no tema
  às 15h08, a lupa instalada é a do morcego; doctor só com os avisos de antes.
- Desktop e portátil: a 1ª tentativa saiu recusada («outro meow está rodando (flock bash sleep)»): o
  `meow-derivados.service`, disparado pelo `git pull`, pega a trava segundos DEPOIS da espera do coordenador.
  Relançado com insistência: limpo nos dois (2 passagens, 77 etapas). `button-layout` e `gtk-decoration-layout` em
  `:minimize,maximize,close`; papéis do MeowSystem semeados às 15h09; 5 ícones novos conferidos no tema.
- A mesma corrida pegaria a atualização ao ligar. Cura: `bloco/atualiza` `05854074` (o install recusado por «outro
  meow está rodando» é tentado até três vezes), com teste vermelho sem a cura. Ainda fora do `master`: push 10.
- Zsh da Vitória: o porte `ba12eaf` chegou ao desktop; ao portátil chega pelo autosync dela. A cópia instalada do
  `aurora-button-layout.service` foi acertada à mão nos dois (`sed` no alvo, `daemon-reload`). O ritual root
  instalado (`/usr/local/sbin`) ainda tem a esquerda e se troca sozinho na próxima volta de hora em hora; até lá
  pode devolver a esquerda uma vez (desktop 15h46; portátil até o zsh de lá receber o porte).

## 19/11, 15h30: os relatórios dos agentes chegaram de uma vez
Chegaram juntos os relatórios de `painel-confere`, `portal-implementa`, `layout-implementa`, `arte-desenha`,
`atualiza-implementa`, `lado-botoes`, `lateral-arquivos` e `arte-confere`. O `arte-confere` explica o atraso dele:
mandou o relatório como texto, não por mensagem. A ressalva «agentes sem relatório» fica respondida.
- Incidente do `arte-confere`: com a árvore dele já removida, um `sed` caiu no checkout principal e trocou o
  `COMMIT=` de quatro pinos; ele restaurou. Conferido pelo coordenador às 15h30: checkout limpo no `ff3c93e1`, os
  quatro pinos nos commits publicados, e os commits publicados dos applets levam o teste e o `build: versão`.
- P251, do `portal-implementa`, o que falta em cada PC: portátil, `apt-get install --only-upgrade
  xdg-desktop-portal-cosmic` (o `6e68360` já não tem fonte servido) e depois `garantir_builds.sh rodar`; desktop,
  subir para o `7b0864c` troca o portal do Hefesto pelo do Pop e pede o sim dela; antes, a leitura do item 3 (o
  comando está no relatório: `ruim`, `perdoado`, journal da unidade do portal dos últimos 10 dias).
- Achados para sprint, dos relatórios:
  1. O shim do portal conta como queda qualquer fim antes de 30 s (restart, saída da sessão); o cuidar deveria ler
     o resultado no systemd.
  2. O GTK pinta só o preenchimento dos simbólicos: todo ícone de contorno do MeowSystem sai errado em app GTK; a
     cura na origem é o `icones_sistema.sh` converter traço em área.
  3. A carência do painel fantasma fica em memória; os nomes `*_do_boot` já não dizem o que a cota faz.
  4. O fechar em X do MeowSystem (54% da caixa) ficou pequeno ao lado dos três novos (88%).
  5. Arte para `network-wireless-disabled` nos dois packs; o desligar antigo do Dracula sem o sufixo `-alt`; as
     quatro propostas do MeowSystem em `sistema/` e não em `biblioteca/`; a contagem «137 glifos» da procedência.
  6. A completion `assets/zsh/_meow` sem o verbo `atualizar`; o desinstalar não devolve o `button-layout` nem o
     `cursor-theme` do gsettings.
  7. O teste do Eyedropper não pega se o botão voltar a pedir `color-select`.
  8. `app-completo.py --aba criar/sons` sozinho fica vermelho em «mexer em sino:evento muda a tela».

## 19/11, 15h45: o portal nos PCs da Vitória, o push 11 e o portátil com a dock mista
- Ordem de quem usa («faça»): desktop, o portal do Hefesto (`…f448ddf+0~hefesto1`, o backport do
  `hefesto-dualsense4unix` com a mesma correção que o `7b0864c` já traz de fábrica) trocado pelo do Pop!_OS com
  `apt-get install --only-upgrade`; `graficos_estado=ok` no `7b0864c`. Portátil: o pacote já era o `7b0864c`;
  `graficos_estado=ok`, e compositor, menu e dock `ok`. Fecha a P251 nos três PCs; o item 3 (queda sem registro) fica
  sem resposta, e o build posto de lado já não existe.
- Erro do coordenador: a lupa do Dracula foi trocada sem o sha256 na `PROCEDENCIA.md`; o `pack.sh` ficou vermelho na
  suíte inteira do `ff3c93e1` (e ficará nos runs dos pushes 9 e 10). Cura `b02e32b6`, push 11 (`7e39b78c`); a suíte
  inteira recomeçou no `7e39b78c` (`scratchpad/suite-inteira-7e39b78c.log`).
- Portátil: dock com um build em cada tela e o mouse «com pau» (`P262`). Na hora, o que cura é sair e entrar na sessão.

## 19/11, 16h10: o run do push 9 e os dois erros do coordenador no CI
- Run 44584677965 (push 9, `fbde5363`): 133 portáteis, 131 verdes, 0 pulados, 2 vermelhos (`pack.sh`, o sha da lupa,
  já curado no push 11; `tres-pastas.sh`, novo) e, mesmo assim, conclusão «success».
- Erro 1 do coordenador (`79177ed3`): o passo virou `todos.sh | tee`, e o `run:` do GitHub roda `bash -e` sem
  `pipefail`: o `tee` engolia o vermelho. Um run vermelho saía verde, e a atualização ao ligar confia nessa
  conclusão. Cura `5ae2fb80`: `shell: bash`, `set -eo pipefail` e o pulado conferido com `if`. Provado à mão: um
  comando que sai 1 antes do `tee` derruba o passo.
- Erro 2 (`79177ed3`): com o Papirus no runner, o `construir_convertidos.sh --conferir` passa a converter de verdade,
  e a versão das ferramentas de lá dá «desatualizados»; o `tres-pastas.sh` exigia «em dia». O que ele prova é que
  não há resto a remover: passa a aceitar «0 a remover». Mesma cura `5ae2fb80`.
- Push 12: `master` = `origin/master` = `073eac83` (integrado na árvore `.meow-wt-integracao-19`, porque a suíte
  inteira roda na `integracao-18`). Os runs dos pushes 9, 10 e 11 dizem «success» sem valer; o do push 12 é o
  primeiro em que a conclusão vale.
- Suíte inteira em curso no `7e39b78c` (difere do `073eac83` só no fluxo do CI e no `tres-pastas.sh`).

## Próximo passo
1. Ler a suíte inteira do `7e39b78c` e o run do push 12 (`073eac83`), o primeiro cuja conclusão vale.
2. Portátil: depois de sair e entrar na sessão, conferir um build só da dock e perguntar pelo mouse.
3. Conferir depois das 16h40 o lado dos botões no desktop e no portátil.
4. Só no fim: `atualizar` no terminal do nitro-5 com o askpass; depois `meow doctor` e
   `scripts/garantir_builds.sh estado`.
5. Apagar as árvores que restam (`atualiza`, `botoes`, `papeis-gatos`, `lateral`, `lado`, `ci4`, e no fim
   `integracao-18`, `integracao-19` e `leva-18`), agora conferindo antes que nenhum agente está vivo nelas.
6. Próxima leva: P257 (commit assinado), P261 (esquerda em todo app do COSMIC), P262 (dock mista), os clones de
   fonte dos testes e os oito achados dos relatórios.

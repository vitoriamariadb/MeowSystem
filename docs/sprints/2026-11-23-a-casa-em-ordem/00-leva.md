# Leva de 23/11/2026 — a casa em ordem

Pedido de quem usa, 23/11: «Todos os icones, imagem de papel de parede e afins devem estar dentro de suas respectivas
pastas de packs», «procure por pastas legadas que deveriam ser excluidas do repo», «Temos que unificar o projeto.
deixar ele fácil. limpar os tokens organizar ele», «Apagar testes antigos», «A começar pela catalogação de tudo» e
«Vamos começar pela limpeza da casa». Sem agente de execução por enquanto; quem mexe nos testes é o coordenador.

O que se mediu está no `CATALOGO.md`. O que está em voo e o próximo passo, no `ESTADO.md`.

## A ordem
Tudo acontece numa árvore de integração (`integracao/2026-11-23`). O `master` e os três PCs só recebem no fim, de
uma vez, na P284.

Sim de quem usa, 23/11/2026 (AskUserQuestion): «Produtividade primeiro». O que deixa a leitura barata e a suíte
curta vem antes de tudo o que mexe em código.

| passo | bloco | tarefas | agentes | por que nesta posição |
| --- | --- | --- | --- | --- |
| 1 | disco | P271 | nenhum | não toca no git; libera as árvores velhas |
| 2 | barato de ler | P273, P272, P287 | 2: um implementa, outro confere e corrige | corta 2,3 MB de texto e o ruído das buscas antes de qualquer agente trabalhar |
| 3 | suíte em paralelo | P286 | nenhum (coordenador) | o tempo de teste cai para todos os passos seguintes |
| 4 | comentários e tabela | P276, P277 | 2: um implementa, outro confere e corrige | 4133 linhas de comentário e 473 KB de tabela a menos |
| 5 | testes, etapas 1 e 2 | P280, P281 | nenhum (coordenador) | menos teste para consertar quando as pastas mudarem |
| 6 | arte no pack | P274 e P275; P285 | 4: dois blocos de arquivos disjuntos, cada um com quem implementa e quem confere | fecha a fronteira antes de dar nome às pastas |
| 7 | árvore final e o manual | P279, P278 | 2: o roteiro é do coordenador; um confere, outro escreve o manual | move o que sobrou, uma pasta por commit |
| 8 | testes, etapa 3 | P282 | nenhum (coordenador) | o corte se faz sobre a árvore de cinco pastas |
| 9 | install | P264 a P266; P267 a P270 | 4: dois blocos disjuntos, cada um com quem implementa e quem confere | escritos uma vez só, na árvore final |
| 10 | histórico e os três PCs | P284 | nenhum (coordenador, com o sim de quem usa) | uma interrupção só nos três PCs |

O plano era de 14 voos de agente, dois blocos por vez. Em 23/11 quem usa pediu mais paralelo («quanto mais
paralelizarmos e progredirmos o mais rapido melhor»; «Paralelo»), e chegaram a voar sete agentes em blocos de
arquivos disjuntos; os passos 6, 7 e 9 andaram juntos. O que está em voo mora no `ESTADO.md`.

Tarefas que nasceram no caminho e entraram nesta leva, pela regra de 06/11 (achado vira tarefa da mesma rodada):
P288, P289 e P290 (herdadas do install, passo 9), P291 (um nome só por papel de parede, passo 6) P292 (o que lê
o histórico antes da reescrita, passo 10) e P293 (o pipe que termina em `grep -q`, a causa do `autostart.sh`
intermitente). O que ficou para depois está no `PARA-A-PROXIMA-LEVA.md`.

Em 24/11, 4h20, os passos 1 a 9 estavam na integração; do passo 8 só a P282 entrou (a P283 ficou para depois do
push, por resposta de quem usa).

## A suíte e a integração
Sim de quem usa, 23/11/2026 (AskUserQuestion): «Inteira só antes do push».
- Cada bloco roda os testes que ele toca. Quando o conferente volta, o bloco entra na árvore de integração e roda o
  cruzamento (`decisoes`, `higiene`, `git-limpo`, `numeros`, `arvore` e os da área).
- A suíte inteira roda uma vez, antes da P284, na árvore de integração.
- Fora dessa regra, só as duas rodadas da P286 (em série e em paralelo), que medem a própria suíte.
- O CI do GitHub (de 56 a 67 minutos) só entra no passo 10: a atualização sozinha só aceita ponta com o run verde.

## As decisões tomadas (AskUserQuestion, 23/11/2026)
| decisão | resposta de quem usa |
| --- | --- |
| a árvore final das pastas | «Cinco pastas»: `scripts/`, `dados/`, `packs/`, `tests/`, `docs/` (P279) |
| o `theme.js` do Spotify dentro do pack | «Exceção escrita», no molde da decisão 9 (P274) |
| as correções do install: antes ou depois do push final | «Tudo junto no fim» (a ordem de cima) |
| os moldes de tema e a captura original | «cada pack deveria ter os mesmos arquivos porém ajustados pela paleta de cores dela»; «Molde no pack, cor no install» (P275) |
| os papéis de parede unificados por pack | «Nos dois»: no repositório e no disco (P285) |
| o histórico online | «Reescrever» (P284) |
| os testes | quatro etapas, feitas pelo coordenador (P280 a P283) |
| a etapa 4 dos testes (P283), antes ou depois de publicar | 24/11: «Depois do push»: vira a leva seguinte, sobre a árvore publicada |
| o texto das decisões 46 e 47, que citam teste pelo nome | 24/11: «Sim, pode juntar»: as linhas passam a dizer o que é vigiado, sem nome de arquivo (P282) |
| o `valores-PRIMEIRO` no texto da decisão 56 e na frase da página Espaço | 24/11: «Sim, acrescentar» (P289) |
| a origem dos papéis do Dracula | 24/11: «Exceção no gancho». Medido: a exceção já existe desde 06/11 (este repositório está na lista de nome público do gancho, que aqui só redige o e-mail), e o acervo é público. A origem vai para o `pack.json` (P285, item 2) |

## As decisões que faltam
| decisão | onde pesa | quando precisa |
| --- | --- | --- |
| o jeito da reescrita (tirar caminhos ou raiz nova) e o sim do push forçado | P284 | no passo 10, com os números |
| quem instala os ganchos de push (proposta: um verbo de quem desenvolve) | P288 | depois desta leva |
| o comentário do `meow.conf.exemplo`, que é o esquema do painel | P276, item D | depois desta leva |

Decidido pelo coordenador, por ser o padrão da tarefa: `docs/pack-minimo/` saiu e o teste monta o pack de exemplo
(P274).

## As herdadas das levas antigas
| de onde | o quê | onde entra |
| --- | --- | --- |
| leva de 19/11 | `app-completo.py` instável na aba Tema | P283 |
| leva de 19/11 | os clones de fonte que dois testes pedem e nada cria | P283 |
| leva de 18/11 | `seco.sh` depende de `systemd --user`; `temas-de-apps.sh` depende do PID 1 | P283 |
| relatórios de 19/11, 7 e 8 | o teste do conta-gotas; `app-completo.py --aba criar/sons` | P283 |
| leva de 19/11 | gancho de push que recuse ponta do `master` sem assinatura; o `ganchos.sh` que ninguém instala | passo 9, tarefa a escrever junto da P265 |
| relatórios de 19/11, 6 | a completion sem o verbo `atualizar`; o desinstalar que não devolve `button-layout` nem `cursor-theme` | passo 9, tarefa a escrever |
| leva de 18/11 | `atalho.sh`, `icones_resgatados.sh` e as sombras não refazem o `mimeinfo.cache` fora do doctor | passo 9, tarefa a escrever |
| relatórios de 19/11, 1 | o shim do portal conta como queda qualquer fim antes de 30 s | depois desta leva |
| relatórios de 19/11, 2; leva de 17/11 | o GTK só pinta preenchimento; o `icones_sistema.sh` engorda o traço de qualquer pack | depois desta leva (arte) |
| relatórios de 19/11, 3 | a carência do painel fantasma em memória; os nomes `*_do_boot` | depois desta leva |
| relatórios de 19/11, 4 e 5 | o fechar em X pequeno; `network-wireless-disabled`; o desligar antigo do Dracula | depois desta leva (arte) |
| leva de 19/11 | P261, botões à esquerda em todo app do COSMIC | depois desta leva |
| leva de 18/11 | a captura da porta Modificações depende dos apps da máquina; `app/LEIA-ME.md` sem `modificacoes.js`; o `_refs` do `vizinhos.sh` | P278 (o LEIA-ME) e depois desta leva |
| leva de 19/11 | o vigia de 5 minutos do zsh da Vitória | não é deste repositório: fila da casa |
| leva de 19/11, gesto de quem usa | sair e entrar na sessão nos três PCs; o mouse do portátil com duas telas | segue valendo |

As tarefas «a escrever» ganham arquivo próprio, com medida, quando o passo delas abrir.

## O que não entra
Nada de arte nova, nada de função nova. Achado no meio do caminho vira arquivo nesta pasta, para o passo dele ou
para a leva seguinte.

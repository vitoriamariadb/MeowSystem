# P250 e P251 — o que o install de 18/11 nos PCs da Vitória mostrou (18/11/2026)

## P250 — o `git pull` cria um commit local com a captura do README
- **O que se mediu (portátil, 18/11 15:26):** o `git pull --ff-only` do `23e2a859` para o `9ed03775` terminou com
  «readme: regerado no commit a36f51e1». O commit, feito pelo gancho pós-merge com a identidade da máquina, só troca
  `docs/capturas/readme/modificacoes.png` (98320 → 98014 bytes) e deixou o `master` de lá 1 à frente do
  `origin/master`. O coordenador o desfez com `git reset --keep origin/master` (o commit segue no reflog de lá). No
  desktop, o pull de 1 commit de documentos não criou commit.
- **A causa (a provar):** a captura do painel sai com bytes diferentes em cada máquina, e o gancho pós-merge
  (`scripts/gancho-post-merge.sh`, decisão 45) roda em todo checkout que tem os ganchos, não só no de quem integra.
  Um checkout com commit local não aceita o próximo `git pull --ff-only`.
- **A cura na origem:** o gancho só faz commit quando o que mudou é texto que vem do código; a captura só entra se a
  diferença de imagem passa de um limiar medido, ou só na árvore de integração. Decidir qual das duas com a medida.
- **Como se prova:** teste em `tests/ganchos.sh`: merge que não muda o que o README lê não cria commit; captura com os
  mesmos pixels e bytes diferentes não cria commit.
- **Nos três PCs:** resolve nos três; hoje todo pull pode deixar o checkout à frente do tronco.

## P251 — o portal de captura não tem build nos PCs da Vitória
- **O que se mediu (18/11):** desktop: «o build do portal 1.11.0~1792525517~24.04~f448ddf+0~hefesto1 está de lado
  (caiu) — o portal do pacote segue valendo». Portátil: `graficos_estado=nao-encaixa` para o
  `xdg-desktop-portal-cosmic` `1.11.0~1794346005~24.04~6e68360`. nitro-5: sem queixa no doctor.
- **A causa (a provar):** no portátil, a série `patches/graficos.series` não entra na versão nova do portal; no
  desktop, o build entrou e caiu repetido ao subir, e o shim o pôs de lado. A versão do desktop traz `+0~hefesto1`:
  não é o pacote do Pop!_OS.
- **A cura na origem:** rebase da série para a versão do portátil (ou `fim <versão>` no `patches/graficos.versao`, se
  ela já traz a correção oficial dos #286 e #384); no desktop, ler o registro da queda antes de decidir.
- **Como se prova:** `tests/graficos.sh`, `tests/graficos-fonte-real.sh` e `tests/patch-que-sobe.sh` verdes;
  `scripts/garantir_builds.sh estado` com `graficos_estado=ok` nos três; compartilhar tela no palco.
- **Nos três PCs:** desktop e portátil. nitro-5 já tem o build.

- **Medida de 18/11 21h55 (`scripts/garantir_builds.sh estado`, só leitura):** nitro-5 `graficos_estado=ok` com o
  pacote `…1792525517~24.04~f448ddf`, a versão do `patches/graficos.versao`; desktop `graficos_estado=falhou` com
  `…f448ddf+0~hefesto1`; portátil `graficos_estado=nao-encaixa` com `…1794346005~24.04~6e68360`.

- **Medida de 19/11 01h55, desktop, só leitura** (`medidas/P251-desktop-portal-2026-11-19.txt`): o pacote
  instalado é `…f448ddf+0~hefesto1` (22 pacotes `hefesto` na máquina), e o candidato do Pop!_OS já é
  `1.11.0~1795035856~24.04~7b0864c`. O `builds.log` mostra quatro tentativas com «o apt-get source do portal
  …+0~hefesto1 falhou (sem rede?)»: essa versão não existe no repositório do Pop!_OS. Depois o build ficou pronto,
  voltou à sessão («passou no teste de fumaça, e o registro não tem queda dele») e foi posto de lado de novo («voltou
  a ser posto de lado depois de devolvido uma vez»). O journal do portal e o `coredumpctl` dos últimos 7 dias não
  têm linha dele. O portátil estava fora da rede nesta medida.
- **Três versões em jogo:** `f448ddf` (nitro-5, a do `patches/graficos.versao`), `6e68360` (portátil em 18/11) e
  `7b0864c` (candidato de hoje).

- **Fecho de 19/11:** a série encaixa nas três versões (push 9). Desktop: com o sim de quem usa («faça»), o portal
  `+0~hefesto1` foi trocado pelo do Pop!_OS (`7b0864c`, que já traz a correção que o backport do Hefesto carregava);
  `graficos_estado=ok`. Portátil: `graficos_estado=ok` no `7b0864c`. nitro-5: depois do `atualizar`, `ok` no
  `7b0864c`. O item 3 (queda sem registro) fica sem resposta: o build posto de lado não existe mais.

### Tarefa do bloco E
1. Série: fazer `patches/graficos.series` encaixar em `6e68360` e em `7b0864c` sem perder `f448ddf` (ou `fim <versão>`
   se a versão nova já traz a correção oficial), com a prova que `tests/graficos*.sh` e `tests/patch-que-sobe.sh` pedem.
2. Versão com sufixo local (`+0~hefesto1`): o `apt-get source` não acha. Medir no código de onde o fonte dessa
   versão veio no fim, e fazer a busca do fonte cair na versão de origem (`…f448ddf`) quando o sufixo não é do
   Pop!_OS, com teste.
3. Queda sem registro: o build «de lado» com `ruim` e sem linha no journal. Ler `scripts/graficos.sh` (`_gr_quedas_do`,
   `_gr_marcar_caiu`, linhas 423 a 454) e dizer, com o `builds.log` medido, qual ramo pôs o build de lado e se foi
   queda de verdade; curar o que estiver errado e provar em `tests/graficos.sh`.
4. O coordenador roda nos PCs da Vitória o que o agente pedir, com o comando exato.

## Para o conferente do bloco A
O `packs/meowsystem/icones/sistema.map` liga `soneca-desperto-symbolic` e `soneca-ronronar-symbolic` a `soneca-desperto`
e `soneca-ronronar`, e `packs/meowsystem/icones/sistema/` não tem esses dois arquivos: nos PCs da Vitória a Soneca usa
o SVG do applet, no `hicolor`. Conferir se é a intenção da decisão 59 ou linha de mapa sem desenho.

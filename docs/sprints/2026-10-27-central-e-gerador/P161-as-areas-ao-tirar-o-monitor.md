# P161 — as áreas ao tirar o monitor (06/11/2026)

Relato de 06/11/2026: ao desconectar o segundo monitor, a barra da tela do note passou de 2 áreas para 5
(«Pop OS Pop OS 5»), e ninguém sabia o que era o «5».

## O que se mediu

- HDMI-A-1 desconectado; só o eDP-1 ativo.
- `pinned_workspaces` com 4 entradas, sem alteração desde 04/11 23:27: Pop e OS do HDMI-A-1, Pop e OS do eDP-1.
  Cópia em `~/.local/state/aurora/pinned_workspaces.2026-11-06`.
- `cosmic-comp` em execução: `/usr/bin/cosmic-comp (deleted)`, de fábrica, com 0 marcadores `AURORA-*`.

## Alcance

Produto, não máquina: vale para todo PC com dois monitores. Os nomes vêm de `AREAS_NOMES`, nada é fixo em «Pop» e «OS».

## As causas

**As duas áreas a mais nascem da decisão 53 somada ao compositor.** A decisão manda repor as mesmas áreas em cada tela
ligada, e o `scripts/areas.sh` grava 2 entradas por tela. Quando o HDMI sai, `remove_output`
(`src/shell/mod.rs:976`) empurra as áreas fixadas dele para a tela que ficou. O arquivo não é corrompido: `to_pinned`
grava `explicit_output`, e `prefers_output` as devolve quando o HDMI volta. Isso é leitura do código, sem teste com o
monitor reconectado.

**O «5» é a área vazia que o `ensure_last_empty` de fábrica cria atrás da última fixada.** O
`cosmic-comp-sem-workspace-vazio.patch` existe para tirá-la. O número é o índice dela.

**A sessão rodava sem patch porque o trilho do compositor falhou calado para quem usa.** O build 8cb1802 foi marcado `ruim`
em 05/11 depois de quedas por abort em `libgallium`, fora do código dos patches. O build ec674cd ficou `retido` em 06/11
no degrau 2, esperando o «Instalar» da página Extensões. Enquanto isso o login foi para a fábrica, sem o Modo de Leitura.

## Previsão para o boot com o HDMI fora

Pela leitura de `add_output` (`mod.rs:934`): o primeiro monitor recebe todas as fixadas, então a barra deve mostrar
«Pop OS Pop OS», sem o «5». Religar o HDMI deve devolver as duas dele. Conferir de verdade.

## A decisão

Decisão de 06/11/2026: «no meowsystem a ideia é termos duas áreas. mas a solução aplicada foi duplicar no outro
monitor também. só que duplicou lá porém o 5 não foi pinado pra evitar o bo dele aparecer. aí ou a solução é mesmas
duas áreas pros dois monitores ou manter agora mas impedir o 5 e que as duplicatas apareçam. isso vira correção e
chave de feature».

Vira correção e chave de feature. Decisão de 06/11/2026: **juntas por padrão**. Sim explícito para trocar o padrão da decisão
53, que precisa ser reescrita no mesmo commit do código.

- **Juntas:** `workspace_mode: Global` na chave `workspaces` do `CosmicComp`, nativo do COSMIC, sem patch. Trocar de área troca
  as duas telas juntas, e tirar o monitor não duplica nada.
- **Independentes:** continua disponível na chave, com o comportamento da decisão 53. Decisão de 06/11: sem patch; as áreas
  do monitor que saiu continuam vindo para a outra tela, e quem não quer isso usa Juntas.

Falta medir como `pinned_workspaces` se comporta em Global: `areas.sh` hoje grava uma lista por tela, e `AREAS_SAIDAS` só faz
sentido no modo independente. Medir também as janelas abertas no HDMI ao desconectar e ao reconectar.

## Como se prova

1. Em Juntas, com um ou dois monitores, a barra mostra só as áreas de `AREAS_NOMES`.
2. Com janelas nas duas telas, desconectar e reconectar: nenhuma janela some, e cada uma volta ao seu monitor.
3. Em Independentes, `pinned_workspaces` continua com as 4 entradas; em Juntas, com a quantidade medida para o Global, sem duplicata.
4. O commit do código reescreve a decisão 53 e registra a chave, citando o sim de 06/11.

## Execução

### O que foi feito

- `AREAS_MODO` (`juntas` | `independentes`, padrão `juntas`) em `meow.conf.exemplo`, `assets/contratos/chave-etapa.tsv`
  (etapa `janelas`) e `assets/contratos/cosmic.tsv` (a chave `workspaces` do `CosmicComp`).
- `scripts/areas.sh`: o modo grava só o token `workspace_mode` da chave `workspaces` (layout, digitação e volta ficam; sem
  arquivo, nasce com os padrões do COSMIC; `OutputBound` sem arquivo não cria arquivo). Em `juntas` o motor deixa no
  `pinned_workspaces` só a lista da primeira tela; em `independentes` repõe a lista em cada tela ligada, como na decisão 53 de
  antes. `aplicar` (install), `alfinetes` (a conferência do doctor) e `refazer-alfinetes` (o conserto do doctor) tratam o modo
  e a lista; `conferir` e `estado` também. O doctor corrige, nenhuma saída manda digitar.
- Só se toca no modo com `AREAS_NOMES` (ou `AREAS_ENCAIXE`) preenchido: sem nomes, as áreas são do COSMIC, e o modo também.
  Escolha minha, pela razão de 21/09 (a primeira passada do instalador não pode mexer em área de quem não pediu).
- Painel: o controle «Nas telas» no bloco «Áreas de trabalho» da página «Janelas e tela» (`lugares.js`); duas palavras, o valor
  em vigor lido do disco (`servidor.py`, `_modo_das_areas`), a frase vem do `# >` do exemplo.
- Decisão 53 reescrita no mesmo commit do código, citando o sim de 06/11. `docs/FRONTEIRA.md` ganhou a linha da chave
  `workspaces`. A contagem de chaves (130 para 131) entrou no `app/LEIA-ME.md`; o `README.md` e o `README.en.md` ficam para o
  `readme.sh`, que regera o que vem do código no merge (decisão 45): o gancho de commit redige o nome de quem criou o README
  quando esses dois entram num commit, então não os toquei.
- `tests/areas-em-cada-tela.sh` é a prova da decisão e acompanha: independentes como antes, e juntas (padrão, ensaio sem escrita,
  segunda passada sem escrever, renomear, acrescentar e tirar na lista única, modo que preserva o resto da chave, ida e volta,
  `AREAS_NOMES` vazio quieto, modo inválido recusado, o painel lendo o disco).

### O que se mediu no fonte (`~/.cache/meowsystem/cosmic-comp/cosmic-comp-0.1~1793802426~24.04~ec674cd`, só leitura)

- `Workspaces::add_output` (`src/shell/mod.rs:906`): a PRIMEIRA saída adicionada recebe TODAS as entradas de
  `pinned_workspaces`, qualquer que seja o `output` de cada uma (`mem::take` de `persisted_workspaces`); as outras saídas só
  recebem as que `prefers_output` as nomeia.
- `remove_output` (`:976`): as áreas que não são `can_auto_remove` (fixadas ou com janela) vão TODAS para a tela que ficou, nos
  dois modos; as vazias e sem alfinete são destruídas. Por isso o «Pop OS Pop OS 5»: quatro entradas viram quatro áreas numa tela
  só. O modo Global não muda isso. O que evita a duplicata é a lista ter UMA entrada por área, e é isso que `juntas` grava.
- `to_pinned` (`workspace.rs:455`): grava `explicit_output` (a frente do `output_stack`), então a área que veio do HDMI continua
  escrita como do HDMI; `prefers_output` a devolve quando ele volta. Com janela dentro, ela é a mesma área e a janela vai junto.
  `persist` só roda quando alguém fixa ou desafixa uma área (`handlers/workspace.rs:70,73`).
- `workspace_mode` (`cosmic-comp-config/src/workspace.rs`): `workspace_mode` é o único campo da chave `workspaces` sem
  `serde(default)`, por isso o escritor nunca grava a chave sem ele. `Workspaces::update_config` (`:1211`) relê a chave ao vivo e
  junta os conjuntos (preenche o que falta com área vazia); o modo, ao contrário da lista, não espera o próximo login.
- Em Global, `Workspaces::refresh` (`:1297`, ramo `Global`, `// add empty at the end, if necessary`, `:1318`) acrescenta uma área
  vazia no fim sempre que a última de qualquer tela é fixada ou tem janela. O `cosmic-comp-sem-workspace-vazio.patch` só mexe no
  `ensure_last_empty`, que é o ramo `OutputBound`. Sem patch (a decisão de 06/11), `juntas` mostra as áreas de `AREAS_NOMES`
  mais UMA vazia, com o número dela. É o achado abaixo.
- Em Global, as áreas que a segunda tela completa para igualar a primeira nascem sem nome (`workspace_set_idx` usa o número);
  o nome só existe na tela que tem a entrada fixada. Os nomes vão para a tela da primeira entrada do arquivo.

### Provas

Rodadas com o molde da suíte (HOME temporário, falsos recusando `sudo`, `pkexec`, `su`, `apt`, `pkill`, `systemctl`; sem
barramento da sessão), cada teste sozinho:

```
tests/areas-em-cada-tela.sh   -> areas-em-cada-tela: tudo verde  (rc=0)
tests/contrato-cosmic.sh      -> contrato-cosmic: tudo certo  (rc=0)
tests/cosmic-prever.sh        -> cosmic-prever: tudo certo  (rc=0)
tests/chave-etapa.sh          -> ok: toda chave do exemplo tem etapa na tabela, as etapas existem, --etapa roda só o pedido
tests/numeros.sh              -> FALHOU: README.md diz 130 ajustes; são 131 / FALHOU: README.en.md diz 130 settings; são 131
                                 (rc=1: só esses dois, até o readme.sh regerar no merge; com os dois ajustados à mão deu
                                 «todos os números escritos batem com os contados.»)
tests/app.sh, restaurar.sh (50 ações), vizinhos.sh, doctor-so-le.sh, doctor-veredito.sh, seco.sh, convergencia.sh,
reversao.sh, chaves-aposentadas.sh, nada-manda-digitar.sh, estilo.sh, higiene.sh, orfaos.sh, readme.sh, modificacoes.sh,
restos-do-painel.sh, apagar-papel.sh, arvore.sh, pack.sh  -> rc=0
tests/grava-ao-soltar.py, tests/app-texto-visivel.py        -> rc=0
```

Com a cópia do arquivo real de 06/11 (`~/.local/state/aurora/pinned_workspaces.2026-11-06`, 4 entradas) num HOME temporário,
`cosmic-randr` falso só com o eDP-1: `alfinetes` rc=1 («workspace_mode está OutputBound e o conf pede Global», «áreas repetidas
na tela: eDP-1»); `refazer-alfinetes` deixa 2 entradas (« Pop », « OS ») e a chave `workspaces` com `workspace_mode: Global`;
a segunda `alfinetes` rc=0.

Vermelhos que já eram da árvore antes do bloco: `decisoes.sh` (askpass 600 e um comentário no `.gitignore`; igual com o bloco
guardado por `git stash`) e `ganchos.sh` («o pre-push não encadeou»: o teste procura a branch `dev`, e o tronco é o `master`;
lido no teste, não medido sem o bloco). O `app-completo.py` marca `XX [tema] a gravação passou do teto de 240s` com a
máquina a carga 10 (outros blocos rodando), um teto de tempo que não é desta sprint.

### O que falta, e por quê

- A prova 2 (janelas nas duas telas, desconectar e reconectar) e a leitura de «a barra mostra só as áreas» só existem com dois
  monitores e o compositor vivo: está em «da mão de quem usa».
- A área vazia do fim em `juntas` (medida acima) contradiz a prova 1 se for lida ao pé da letra. Não corrigi: a decisão de
  06/11 diz «sem patch» para as duas pontas, e a decisão só se desfaz com sim. Um hunk de uma linha no ramo Global do
  `refresh` resolveria, mas é patch novo no compositor, que está `retido` à espera do «Instalar».
- Em `juntas`, os nomes aparecem numa tela só (a da primeira entrada do arquivo); na outra, as áreas têm o número. Sem patch não
  há como dar o nome nas duas sem voltar à duplicata.

### Da mão de quem usa (depois do install e do reboot)

1. Com os dois monitores: a barra de cada tela mostra as áreas de `AREAS_NOMES`; trocar de área numa tela troca a outra.
2. Anotar se aparece UMA área vazia com número depois de «Pop OS» (a previsão do fonte, acima).
3. Abrir uma janela em cada tela, desconectar o HDMI e reconectar: nenhuma janela some e cada uma volta ao seu monitor. A ordem
   das áreas por índice pode embaralhar (o Global liga por posição, e as áreas movidas voltam para o HDMI).
4. Tirar o HDMI no boot: a barra do note mostra só «Pop OS», sem repetida.
5. Painel, «Janelas e tela», «Áreas de trabalho», «Nas telas»: trocar para Independentes e olhar a barra no login seguinte.

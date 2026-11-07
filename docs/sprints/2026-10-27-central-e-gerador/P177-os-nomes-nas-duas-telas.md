# P177 — os nomes das áreas nas duas telas (06/11/2026)

Pedido de quem usa em 06/11. Produto: vale para todo PC com mais de um monitor em `AREAS_MODO="juntas"`.

## O que se mediu

- Em Global, `add_output` dá todas as entradas fixadas à primeira saída; as outras saídas completam a lista com `add_empty_workspace`, e `workspace_set_idx` escreve o número no lugar do nome (`src/shell/mod.rs`, fonte de ec674cd).
- `Workspace.name` só existe na saída que recebeu o alfinete. Repetir a lista por saída volta à duplicata, porque tudo cai na primeira.
- Quem usa, diante de «nomes numa tela e números na outra»: «Ué mas aí volta ao errado. Assim não.» E confirmou: Pop e OS nas duas telas, sem números e sem duplicata.

## A cura

Patch `req` novo, com marcador próprio: no ramo Global do `refresh`, depois de completar as saídas, cada área recebe o nome da área de mesmo índice que tem nome, em `Workspace.name` e no protocolo (`set_workspace_name`). A cópia não vira alfinete: `to_pinned` e o `persist` não podem gravar a área copiada, e o arquivo segue com a lista numa tela só.

Conferir no fonte, antes de escrever, tudo que lê `name`: `to_pinned`, `remove_output`, `add_output`, troca de área e renomear pelo painel. Tirar o monitor não pode criar área a mais nem nome repetido, com janela ou sem janela na área copiada. Renomear numa tela vale nas duas.

A P171 fica: a lista mora no monitor interno, e a cópia cobre o outro.

## Como se prova

Patch passa no dry-run `-F0` sobre o fonte real de ec674cd com a série inteira; `cargo check` rc=0; função pura do patch testada; marcador conferido pelo doctor e nos testes do compositor; `tests/decisoes.sh` e a decisão 53 reescrita com o sim de 06/11. A tela real é da mão de quem usa.

## Execução

### O que foi feito

- `patches/cosmic-comp-nomes-nas-duas-telas.patch`, `req`, marcador `AURORA-AREAS-NOMES-1`, último da `patches/series`.
- `Workspace.nome_copiado` separa a cópia do dono. No fim do ramo Global do `refresh`, `copiar_nomes` dá a cada área sem nome próprio o nome do dono de mesmo índice, em `Workspace.name` e no protocolo. Sem dono no índice, a cópia volta ao número.
- `to_pinned` recusa a cópia, mesmo fixada à mão; o `persist` não mudou e herda isso. Quem fixa a cópia fica com o alfinete só na sessão.
- `remove_output`, só em Global: a cópia que sai funde as janelas na irmã de mesmo índice e some do protocolo (`fundir_area`, com janela normal, em tela cheia e minimizada). Se quem sai é o dono, ele toma o lugar da cópia e recebe as janelas dela. Área sem cópia segue como na fábrica.
- A pilha de foco da área que some vai para baixo da pilha da tela que fica (`FocusStacks::por_baixo`). Sem isso, `focus_target_is_valid` não acha a janela no topo da pilha e o teclado salta de janela ao fechar a tampa.
- Passar de Global a independentes solta as cópias (`update_config`).
- Decisão 53 reescrita no mesmo commit, com o sim de 06/11: «Sim, nomes nas duas telas». `meow.conf.exemplo` deixou de dizer que a outra tela tem número.

Conferido no fonte, tudo que lê `name`: `create_workspace_from_pinned`, `add_empty_workspace`, `update_workspace_idxs`, `to_pinned`, e a troca de área não lê. `add_output` só move área por `prefers_output`, e a cópia só prefere a própria saída.

Renomear: `Request::Rename` cai no `_ => {}` do handler em ec674cd, e nenhuma área anuncia a capacidade. O nome muda por `AREAS_NOMES` e pelo arquivo, no próximo início de sessão; a cópia segue o dono a cada `refresh`.

`tests/compositor-shim.sh` e `tests/garantir-builds.sh` não mudaram: usam série própria de brinquedo e não contam os marcadores reais. O marcador real é conferido em `tests/nomes-nas-duas-telas.sh`, novo e no runner, e `tests/decisoes.sh` cobra o teste na decisão 53.

### Provas literais

- Fonte limpo de ec674cd com a série inteira: `dry-run` `-F0` rc=0 nos 7 patches, um a um, sem `FAILED` nem `fuzz`.
- O patch sozinho sobre o fonte limpo: `checking file src/shell/mod.rs`, `checking file src/shell/workspace.rs`, sem `offset`: a numeração do `@@` é a do fonte limpo.
- `nice -n 19 cargo check --frozen --offline`: `Finished dev profile`, rc=0, 0 `warning`.
- `bash tests/nomes-nas-duas-telas.sh`: `test result: ok. 10 passed; 0 failed`, `nomes-nas-duas-telas: tudo certo`. O doctor acusa `FALTA AURORA-AREAS-NOMES-1` no binário sem marcador, aceita o binário com ele e acha o patch declarado na série.
- Mutação em cópia do repositório, uma por vez, todas mortas pelo teste: `to_pinned` sem a recusa dá `FALHA to_pinned grava a cópia`; sem `copiar_nomes` no `refresh` dá `FALHA a cópia saiu do fim do ramo Global`; sem o `swap` da pilha dá `FALHA fechar a tampa tira o foco de quem está na tela de fora`; sem `soltar_nomes_copiados` dá `FALHA as cópias ficam presas ao sair de Global`; cópia dona de nome, cópia que não funde, dono que não substitui, independentes que funde e pilha invertida dão `FALHA as funções não passaram`.
- `tudo certo` ou `tudo verde`, rc=0: `decisoes`, `compositor-shim`, `garantir-builds`, `janela-sem-app-id`, `areas-em-cada-tela`, `notas-de-funcao`, `patch-que-sobe`. Também rc=0: `estilo`, `orfaos`, `seco`, `frases-velhas`, `nada-manda-digitar`, `achados-tecnicos`.

### Custo aceito

- As janelas fundidas voltam ao monitor quando ele reconecta: é a P179, com o sim de 07/11 («Devolver ao religar»).
- Fechar a tampa com a lista no monitor interno leva o dono à tela de fora e funde as janelas nele. Abrir a tampa devolve o dono ao interno, e a P179 devolve à tela de fora as janelas que eram dela.
- Janela solta que entra em área com ladrilho vira ladrilho, como no `move_element`, e volta solta ao religar.
- Monitor que some ao dormir conta como tirar o monitor: as janelas dele ficam na irmã até ele voltar.
- Quem digita na tela que sai recebe o foco na janela do topo da tela que fica.

### Achados, por leitura do fonte

- Fábrica: ao religar o HDMI com a área ativa fora da primeira, `add_output` marca `Active` no índice 0 e o `refresh` iguala `set.active` sem refazer o estado. A barra da tela religada marca a primeira área até a próxima troca.
- Fábrica: em `remove_output` no modo Global, `remove_group_output` usa o grupo da saída que ficou, e o grupo da saída removida fica vazio no protocolo.
- `Request::Rename` não tem capacidade anunciada em `create_workspace` nem em `create_workspace_from_pinned`, nem caso no `commit_requests`: rename pelo protocolo não existe hoje. Se vier a existir, renomear na cópia será sobrescrito pelo nome do dono.

### O que falta da mão de quem usa

Nada disso rodou no `cosmic-comp` de verdade. Depois do install e do login, com `AREAS_MODO="juntas"`:

1. As duas telas mostram os nomes, sem número e sem duplicata, e `pinned_workspaces` segue com a lista numa tela só.
2. Tirar o HDMI com a área copiada vazia e depois com janela: a barra segue com as mesmas áreas, e nenhuma janela some.
3. Religar o HDMI: os nomes voltam às duas telas, sem área a mais, e as janelas voltam a ele (P179).
4. Fechar e abrir a tampa com janelas nas duas telas: nada some e os nomes não repetem.
5. Janela em tela cheia e janela minimizada na tela que sai continuam restauráveis depois da fusão.

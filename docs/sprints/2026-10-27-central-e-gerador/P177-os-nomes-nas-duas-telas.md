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

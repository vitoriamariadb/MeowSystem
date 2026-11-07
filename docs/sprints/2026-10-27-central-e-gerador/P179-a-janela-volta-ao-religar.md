# P179 — a janela volta ao religar o monitor (07/11/2026)

Decisão de quem usa, depois da P177: «Devolver ao religar».

## O que se mediu

- Com a P177, tirar o monitor funde as janelas da área copiada na área de mesmo índice da tela que fica (`fundir_area`), sem área a mais.
- Ao religar, nada as devolve: quem guardava a volta era a área a mais. Monitor que some ao dormir conta como tirar, então isso pode acontecer em toda suspensão. Só leitura do fonte.

## A cura

No mesmo patch `cosmic-comp-nomes-nas-duas-telas.patch`: cada janela fundida lembra a saída de origem e o índice da área. Quando aquela saída volta, em `add_output`, a janela volta para a área de mesmo índice dela, tiling e flutuante, sem área a mais e sem roubar o foco. Mover a janela de tela à mão nesse meio-tempo apaga a lembrança. Fechar a janela também. Saída identificada como no resto do compositor, por EDID e conector, para o mesmo monitor em outra porta contar. A lembrança vive só na sessão, em memória.

Conferir o caso da tampa: a lista mora no note, então fechar a tampa leva o dono para a tela de fora, e abrir a devolve (`prefers_output`). A volta das janelas não pode brigar com isso, nem duplicar, nem perder janela em tela cheia ou minimizada.

## Como se prova

Dry-run `-F0` e `cargo check` com a série inteira sobre o fonte de ec674cd; funções puras testadas em `tests/nomes-nas-duas-telas.sh`, com mutação; a prova 2 da P161 volta a valer. A tela real é da mão de quem usa.

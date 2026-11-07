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

## Execução

### O que foi feito

- Tudo no `patches/cosmic-comp-nomes-nas-duas-telas.patch`, marcador `AURORA-AREAS-NOMES-2`, para o doctor cobrar o binário novo.
- `fundir_area` passa a tirar e pôr cada janela por `tirar_janela` e `por_janela`, a mesma rota da volta: ladrilho, solta, tela cheia e minimizada. A janela só existe num lugar por vez, porque `por_janela` recebe o que `tirar_janela` entregou.
- `Workspaces.fundidas`, só em memória, guarda por janela a saída (EDID e conector, `OutputMatch`), o índice da área, a posição se era solta, e a tela e a área em que ela está agora.
- `add_output` chama `devolver_janelas` depois de mover os donos. A saída vale por porta e EDID em qualquer tela presente; só EDID vale apenas para a saída que acabou de entrar, para o monitor em outra porta contar sem mandar a janela ao gêmeo que já estava ligado.
- A volta completa as telas só até o tamanho da lista, como o `refresh` faria, e leva a janela à área de mesmo índice, ou à última, se a área sumiu. Não toca em `set_active_output`, em `activate` nem no estado `Active`; a janela entra por baixo da pilha de foco da área (`FocusStacks::separar` e `por_baixo`).
- Janela solta volta solta e na posição dela (`position_relative`), mesmo tendo virado ladrilho na fusão.
- `conferir_fundidas`, no início do `refresh`: janela morta sai; janela noutra área e noutra tela foi levada à mão e sai; o dono que muda de tela leva a janela e não conta, porque a área é a mesma; trocar de área na mesma tela guarda a lembrança. Vale para todo caminho de mover (atalho, arraste, troca de ladrilhos, protocolo) sem gancho em cada um. Janela fora das áreas, no meio de um arraste, fica lembrada.
- Passar a independentes apaga as lembranças.
- Decisão 53 reescrita no mesmo commit, com o sim de 07/11: «Devolver ao religar». A prova 2 da P161 volta a valer, e o que a P177 dizia como custo foi sobrescrito.

### A tampa

- Fechar: o dono substitui a cópia, e as janelas da cópia estão na tela de fora. Elas entram no dono lembrando a própria tela de fora (`output_match_for_output(&new_output)`).
- Abrir: `add_output` leva o dono ao interno com tudo, por `prefers_output`, sem briga, porque a volta roda depois. A janela da tela de fora acha a saída dela presente e volta para lá; a do interno já está em casa.
- Janela em casa não se move e segue lembrada: ao acordar com o HDMI primeiro, ela está no dono na própria tela, e só precisa voltar quando o interno leva o dono embora.
- Segunda fusão atualiza tela e área e guarda a saída da primeira.

### Provas literais

- Fonte limpo de ec674cd, série inteira, um a um: `dry-run rc=0 FAILED/fuzz=0` nos 7 patches, `patches=7`.
- O patch sozinho sobre o fonte limpo: `checking file src/shell/mod.rs`, `checking file src/shell/workspace.rs`, sem `offset`.
- `nice -n 19 cargo check --frozen --offline` na árvore da série (`cmp` igual ao fonte limpo com os 7): `Finished dev profile`, `cargo rc=0 warnings=0`.
- `rustfmt --check`: 0 diferenças em `src/shell/mod.rs`.
- `bash tests/nomes-nas-duas-telas.sh`: `test result: ok. 22 passed; 0 failed`, `nomes-nas-duas-telas: tudo certo`.
- Mutação em cópia do repositório, uma por vez, 22 de 22 mortas pelo teste: `add_output` sem devolver, saída errada na fusão e no dono, `lembranca_segue` nas 3 formas, `indice_da_volta` nas 2, gêmeo, sem casamento exato, outra porta, `alive` desligado, solta virando ladrilho, foco por cima, área ativada, `separar` nas 2, devolvida ainda lembrada, independentes com lembrança, área a mais, segunda fusão trocando a saída e marcador velho.
- `rc=0`: `decisoes`, `compositor-shim`, `garantir-builds`, `janela-sem-app-id`, `areas-em-cada-tela`, `notas-de-funcao`, `patch-que-sobe`, `estilo`, `orfaos`, `seco`, `frases-velhas`, `nada-manda-digitar`, `achados-tecnicos`, `higiene`.

### Custo aceito

- Janela maximizada ao fundir volta sem maximizar, e a árvore de ladrilhos não volta: as janelas entram na ordem, como no `move_element`.
- Janela de fora empilhada à mão numa pilha fundida vai junto com a pilha.

### Achados, por leitura do fonte

- Fábrica: ao abrir a tampa com a área ativa fora da primeira, `post_remove_workspace` põe a ativa no fim da tela de fora, que ficou vazia, e o `refresh` iguala todas por `sets[0]`. A área ativa pula para a primeira, e a janela devolvida a outro índice fica escondida até trocar de área.
- Fábrica: janela grudada (`sticky_layer`) e minimizada dela vão para a tela que fica em `remove_output` e não têm volta. A lembrança cobre só as áreas.

### O que falta da mão de quem usa

Nada disso rodou no `cosmic-comp` de verdade. Depois do install e do login, com `AREAS_MODO="juntas"`:

1. Janela na tela de fora, em cada área: tirar o HDMI e religar. Cada uma volta à mesma área da mesma tela, sem área a mais.
2. Janela solta, em tela cheia e minimizada na tela que sai: as três voltam assim, e a minimizada restaura.
3. Fechar e abrir a tampa com janelas nas duas telas: cada uma volta à sua tela, sem duplicar.
4. Digitando na tela que fica ao religar: o foco não sai da janela em uso.
5. Com o HDMI fora: fechar uma janela fundida e religar, nada acontece; suspender e acordar com o HDMI ligado, as janelas voltam.

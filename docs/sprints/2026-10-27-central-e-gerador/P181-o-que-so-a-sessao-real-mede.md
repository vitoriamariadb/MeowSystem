# P181 — o que só a sessão real mede (07/11/2026)

Achados da conferência da P179 e da P180. Ficam fora desta rodada porque corrigir sem medir em sessão com dois monitores, ou sem um COSMIC v3, seria patch às cegas. Junto com a P163 e a P167, esperam o reboot.

## O que se leu, sem rodar

- Abrir a tampa com a área ativa fora da primeira: `sets[0]` é a tela de fora, `post_remove_workspace` zera a ativa e o `refresh` iguala todas. A área ativa pula para a primeira, e a janela devolvida a outro índice fica escondida até trocar de área.
- `remove_output`: a `sticky_layer` e os `minimized_windows` do set vão para a tela que fica, sem volta. Janela grudada não volta ao monitor.
- Janela aberta na tela de fora com a tampa fechada entra no dono sem lembrança, e abrir a tampa a leva ao interno.
- Janela solta maximizada, com telas de tamanhos diferentes: ao sair do maximizado depois da volta, `position_relative` a desloca.
- Ao religar o HDMI com a área ativa fora da primeira, a barra da tela religada marca a primeira até a próxima troca.

## O que se mediu em fixture

- `aplicar_tema.sh --respeitar-gui` num COSMIC v3 com captura v2: «43 removidos», e a pasta `Builder/v3` fica vazia, com backup feito. Não há COSMIC v3 hoje. A pasta produto `CosmicTheme.<Árvore>/v2` também segue cravada.

## Como se decide

Depois do reboot, quem usa diz o que viu. O que aparecer vira cura com prova; o que não aparecer sai desta lista.

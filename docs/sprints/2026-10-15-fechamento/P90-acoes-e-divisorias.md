# P90 — Ação é Executar e Restaurar; o resultado abre em janela; as telas alinhadas

**Branch:** `sprint/p90` (DEPOIS da leva I integrada: a P89 mexe em todo arquivo) · **Prints de quem usa
(16/10, 18:28–18:32):** `.playwright-mcp/ux-pedido-16-10/3.png` a `7.png`.

## Pedido de quem usa (16/10)
- «Essa tela de log deveria aparecer como uma espécie de pop-up escurecendo o fundo e mostrando botão de
  OK, Guardar (log) e Restaurar, que desfaz o que foi feito pro estado anterior. E arrumamos essa parte
  do espaço do log na tela.» (print 3: a gaveta de baixo cortada, «Conferir a máquina»)
- «Nossa tela não pode ter um botão de ver comando, só um de Executar e Restaurar.»
- «Remover botão Conferir. Dividir melhor os elementos da tela. A parte dos jogos instalados tá zuada,
  não faz sentido.» (prints 4 e 6)
- «Olha essas divisórias» (print 5: barras laterais laranja em uns cartões e não em outros, fios que
  param no meio, colunas desalinhadas); «falta divisória, todas as telas estão quebradas» (print 7).
- «Ver o que faria muda para Ver sem mudar.»
- «Temos que arrumar o install nosso.» (a página Instalação e o fluxo do `./install.sh` pelo painel)

## Tarefas
1. **Janela de resultado (modal)**: toda ação abre uma janela sobre o fundo escurecido, com o progresso
   ao vivo e três botões: **OK** (fecha), **Guardar** (salva o log em `~/.local/state/meowsystem/logs/`
   com data e nome da ação; mostra onde num selo) e **Restaurar** (desfaz a ação, voltando ao estado
   anterior). A gaveta de baixo sai. Esc e clique fora não perdem o log em andamento.
2. **Restaurar de verdade**: toda ação que escreve guarda antes o estado que vai mudar (o motor já faz
   backup por escrita: `MEOW_BACKUPS`); o Restaurar repõe exatamente esse estado e reaplica o que precisar
   (painel, tema). Ação que só lê não tem Restaurar (o botão some, não fica cinza). Teste por ação.
3. **Só Executar e Restaurar**: o «ver comando» sai de toda tela; o comando cru não aparece em lugar
   nenhum (no máximo no log guardado). O Restaurar do cartão desfaz a ÚLTIMA execução daquela ação.
4. **«Ver o que faria» → «Ver sem mudar»** em todo lugar (barra de cima, dicas, testes).
5. **Lançadores e jogos**: sai o «Conferir»; «Os jogos instalados» é refeito: uma grade das capas dos
   jogos instalados (Steam e Heroic), cada um com um interruptor «no lançador» e o ícone escolhido;
   nada de filtro solto, «0» sem sentido nem «Decisões já executadas» como lista técnica (vira o
   interruptor desligado do jogo removido). As ações do Heroic e da Steam viram um par Executar/Restaurar.
6. **Divisórias e grade, em TODAS as telas**: uma regra só de cartão (sem barra lateral colorida
   aleatória: a cor lateral só marca «mudado por você», igual em todo cartão), fio de seção de ponta a
   ponta, colunas da grade alinhadas (mesma largura e altura de linha), espaçamento vertical uniforme
   entre seções. Medir com o gate: nenhum fio que termina no meio, nenhuma coluna desalinhada a 1440 e a
   1920 px.
7. **Instalação**: a página fica com Instalar tudo, Conferir e consertar (um botão só: o doctor corrige),
   Desinstalar e Voltar ao tema de antes — todos com Executar/Restaurar e a janela de resultado; o
   `./install.sh` chamado pelo painel termina sem pedir nada e o resultado aparece na janela.

## Prova
- prints antes/depois de cada tela em `.playwright-mcp/ux-p90/` a 1440 e 1920 px; o gate de uso real
  ganha os casos: «ver comando» ausente, modal com 3 botões, Restaurar volta o arquivo ao sha256 anterior,
  fios e colunas alinhados.
- `tests/todos.sh` inteiro verde 2x.

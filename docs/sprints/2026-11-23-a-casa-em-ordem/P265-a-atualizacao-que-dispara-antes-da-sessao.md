# P265 — a atualização ao ligar dispara antes de a sessão existir (23/11/2026)

## O que se mediu (nitro-5, 23/11)
- `meow-atualiza.timer` tem `OnBootSec=3min`. Rodou às 16h04m33; a sessão do COSMIC abriu às 16h18m03.
- A volta começou e terminou no mesmo segundo e não deixou linha: `~/.local/state/meowsystem/atualiza.log` não
  existe. O `fetch` que ela faz, repetido à mão, leva 0,54 s e sai 0; o `master` daqui era o do GitHub. Ou seja: não
  havia o que puxar, mas nada no disco diz isso.
- `scripts/atualiza.sh`, `cmd_rodar`: toda saída sem novidade ou por falha (trava ocupada, `fetch` que falhou, clone
  fora do `master`) devolve 0 sem registrar.
- `lib/preflight.sh:22`: sem `XDG_CURRENT_DESKTOP`, o pré-voo aceita seguir se `pgrep -x cosmic-comp` acha
  processo, de qualquer usuário.

## A causa
O relógio conta do boot, não da sessão. Com linger o disparo cai antes do login; sem linger cai no instante do
login, que é a corrida que o pedido de 19/11 queria evitar («uns 3 minutos após dar boot no Pc pra evitar Race
condition»). Com commit novo, o install rodaria sem sessão gráfica. Isto é leitura do código: em 23/11 não havia
commit novo, e a queda não foi vista.

## A cura na origem
- O timer nasce com a sessão: `PartOf=` e `WantedBy=` em `graphical-session.target`, e `OnActiveSec=3min` no lugar
  de `OnBootSec=3min`. O serviço ganha `ConditionEnvironment=WAYLAND_DISPLAY`.
- Cada volta deixa uma linha no `atualiza.log` com o desfecho (nada novo, trava ocupada, sem rede, clone fora do
  tronco).
- O pré-voo procura o `cosmic-comp` só da própria conta (`pgrep -u`).
- Decisão 65: «3 minutos depois de ligar» vira «3 minutos depois de entrar na sessão». Sim de quem usa, 23/11/2026:
  «sobre seu levantamento dou sim nos 3 pontos».

## Como se prova
- `tests/atualiza.sh`: casos novos para o vínculo da unidade, para a linha de cada desfecho e para a segunda volta
  sem novidade.
- Teste do pré-voo com um `pgrep` falso que só acha processo de outra conta: o install recusa.
- No nitro-5: reiniciar, esperar na tela de login, entrar; o journal mostra a volta 3 minutos depois do
  `cosmic-session`, e o `atualiza.log` tem a linha dela.

## Nos três PCs
Vale nos três. A reescrita do histórico (última tarefa desta leva) para a atualização sozinha em todo clone antigo:
ver a tarefa dela antes de religar o timer.

## Feito (23/11, bloco `install-sessao`, integrado em `3a2fd5a5`)
- `meow-atualiza.timer` com `OnActiveSec=3min`, preso à sessão gráfica; o serviço com
  `ConditionEnvironment=WAYLAND_DISPLAY`; o pré-voo só vê o `cosmic-comp` da própria conta.
- A decisão 65 foi reescrita no lugar, com o sim de 23/11/2026, e `tests/decisoes.sh` cobra `OnActiveSec=3min`.
- Toda volta deixa uma linha de desfecho no `atualiza.log`. Quem conferiu achou voltas com duas linhas (aviso novo
  mais desfecho) e duas saídas sem linha (a trava que não abre e o `mktemp`), e corrigiu (`148ba339`).
- Prova: `tests/atualiza.sh` (uma linha exata por volta em cada desfecho) e `tests/preflight-so-da-conta.sh`.
- Falta, no passo 10: o disparo real 3 min depois de entrar na sessão, nos três PCs.

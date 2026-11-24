# P264 — o doctor das 5h é pulado no PC que liga depois das 5h (23/11/2026)

## O que se mediu (nitro-5, 23/11)
- Boot às 16h01; o `systemd --user` subiu às 16h02 sem sessão gráfica (`loginctl show-user`: `Linger=yes`); a sessão
  do COSMIC abriu às 16h18.
- 16h03m03: `meow-doctor.service … was skipped because of an unmet condition check
  (ConditionEnvironment=WAYLAND_DISPLAY)`. O `meow-doctor.timer` (`OnCalendar=05:00`, `Persistent=true`) gastou ali
  o disparo do dia; a próxima volta é 24/11 05h18.
- `meow.log`: o último `doctor --consertar` vindo do timer é de 17/11 05h16. De 19/11 em diante, nenhum.
- Efeito no mesmo dia: `./install.sh` fecha «Pronto. 1 passagem, 77 etapas, nada mais a escrever» e o `meow doctor`
  logo depois sai 1 com `disco … tem 225 MB para cortar`, que só o conserto corta.

## A causa
O timer está em `timers.target`, que sobe com o `systemd --user`. Com linger, isso é no boot, antes do login. A
condição do serviço não se cumpre, o serviço é pulado e o timer conta a volta como dada. PC que fica desligado às 5h
e tem linger nunca roda o auto-reparo.

## A cura na origem
O timer passa a nascer com a sessão gráfica, como o `meow-builds-login.service` já nasce: `PartOf=` e `WantedBy=` em
`graphical-session.target`. O `Persistent=true` dá a volta perdida quando o timer sobe, já com `WAYLAND_DISPLAY`. A
etapa `autoreparo` do install tira o vínculo antigo de `timers.target.wants`. A condição do serviço fica.

## Como se prova
- Teste novo, com `systemctl` falso: a unidade instalada não fica em `timers.target.wants`; a segunda passada não
  escreve; o vínculo antigo some.
- No nitro-5: reiniciar, esperar mais de 3 minutos na tela de login, entrar. O journal mostra o
  `meow-doctor.service` começando depois do `cosmic-session`, sem «skipped», e o `meow.log` ganha a linha
  `doctor --consertar`.

## Nos três PCs
Medido no nitro-5. A medir no desktop e no portátil antes da cura: `loginctl show-user` e a data do último
`doctor --consertar` no `meow.log`. Sem linger o defeito não aparece, e a cura não muda nada lá.

## Feito (23/11, bloco `install-sessao`, integrado em `3a2fd5a5`)
- `systemd/meow-doctor.timer` com `PartOf=` e `WantedBy=graphical-session.target`. O install e o doctor soltam o
  vínculo antigo de `timers.target.wants`; em seco, apontam sem tirar; a segunda passada não escreve.
- Quem conferiu achou uma regressão e corrigiu (`b85e6e8b`): por ssh, sem ninguém na tela, a sessão gráfica está
  parada e o timer fica inativo de propósito. O doctor dizia «não está armado» e o conserto dava partida no timer
  fora da sessão. Agora unidade que nasce com a sessão conta como armada se está habilitada, e fora da sessão o
  conserto habilita sem dar partida (`meow_unidade_armada`, `meow_armar_unidade` em `lib/comum.sh`).
- Prova: `tests/autoreparo-na-sessao.sh` (9 FALHOU com o conserto desfeito; verde depois).
- Falta, com sessão gráfica real, no passo 10: os dois timers fora de `timers.target.wants` e dentro de
  `graphical-session.target.wants`; reiniciar, esperar 3 min na tela de login, entrar e ler o journal; o
  `meow doctor` por ssh com o PC na tela de login. Os comandos estão no `relato-conf-sessao.md`, seção 5.

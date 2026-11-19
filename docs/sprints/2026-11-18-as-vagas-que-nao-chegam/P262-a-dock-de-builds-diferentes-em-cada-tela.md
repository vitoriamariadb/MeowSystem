# P262 — a dock com um build em cada tela depois do install (19/11/2026)

## Texto de quem usa
«no notebook rolou umas duas coisas estranhas. primeiro em uma tela ele tem o icone do svg desenhado em outra o mesmo
icone do desktop da dock não é identificado. o mouse por algum motivo deu pau.»

## O que se mediu (portátil, 19/11 15h30)
- Dois `cosmic-app-list` vivos: o do boot (PID de 2h58), rodando o build `1.11.0~1794060008~24.04~ef6c9e6`, cuja
  pasta já nem existe em `~/.local/libexec/meow/dock/`, e um de 15h11m58, rodando o `…1794872298~24.04~779f920`, o
  único build que está na pasta (de 15h12).
- Às 15h11m46 e 15h11m48 o journal registra USB entrando; às 15h11m57 o compositor troca de modo: uma tela foi ligada
  no meio do install. O painel da tela nova nasceu com o build novo; o da tela antiga segue no velho.
- O compositor que roda é o do boot (`0.1~1794310577~24.04~66524a0`); o build pronto é o `…0a67a6c`.
- Cursor: `catppuccin-mocha-mauve-cursors`, tamanho 24, igual no gsettings e no COSMIC; nada no journal sobre ponteiro.
  O que é o «deu pau» do mouse ainda não se sabe.

## A causa
O `dock.sh compilar` guardava o build novo e apagava todos os outros, com a sessão viva; o shim escolhe o build pela
versão do pacote na hora em que sobe. Quem já rodava ficava no velho (já apagado do disco) e quem nascia depois
(tela nova, painel reposto) pegava o novo. Com duas telas, cada dock casava janela e ícone por um binário diferente.

## A cura na origem
- Escolhido: nenhuma troca até o próximo início de sessão. O shim olha o binário que a dock viva da pessoa já roda
  (`/proc/<pid>/exe`) e sobe o mesmo, seja build da casa, seja o do pacote; sem dock viva, escolhe como antes. Repor
  o applet nas duas telas ficou de fora: reciclar o painel no meio da sessão é o que a P252 teve de conter.
- O build anterior não é apagado enquanto um processo o usa; o `dock.sh aplicar` (install e doctor) poda o que
  ninguém mais roda.
- O que a cura não alcança: o `apt` que troca o `/usr/bin/cosmic-app-list` com a dock do pacote viva. A tela nova
  sobe o do pacote novo, que é o único que existe no disco.

## Como se prova
- `tests/dock.sh`, caso 14 (`5ab110ae`): com um `cosmic-app-list` vivo no build velho, o shim diz o velho, o
  compilar e o aplicar não o apagam, e depois que ele morre o shim diz o novo e o aplicar poda o velho.
- No portátil, com as duas telas: `ps` mostra um build só depois do install.

## Nos três PCs
Vale nos três; aparece em quem usa duas telas.

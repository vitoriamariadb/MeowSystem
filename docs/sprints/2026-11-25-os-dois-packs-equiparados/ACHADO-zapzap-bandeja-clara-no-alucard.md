# ACHADO · o módulo do ZapZap manda a bandeja clara em qualquer flavor (25/11/2026)

Achado no bloco `cli-e-bandeja`; sem conserto aqui (módulo de app, outro bloco).

## O que se mediu
- `scripts/temas-de-apps/zapzap/manifesto.sh` (`_ZZ_TRAY_DESEJADO="${ZAPZAP_TRAY:-symbolic_light}"`) põe o ZapZap em
  `symbolic_light`, e o `_SYMBOLIC` do app pinta o `{color}` de `#ffffff` nesse modo (`symbolic_dark` pinta `#241f31`).
- No flavor `alucard` do Dracula o painel é claro (`surface0` `#cecfdc`): branco sobre ele quase some, tanto no ícone de
  fábrica quanto no do pack. A folha de comparação do bloco mostra os dois (24 px e ampliado).
- Nenhuma chave do `meow.conf.exemplo` nem leitor no código escolhe `ZAPZAP_TRAY` por flavor.

## A causa
O degrau claro/escuro da bandeja do ZapZap é fixo no módulo; o flavor não entra.

## A cura na origem (proposta)
O módulo escolhe `symbolic_dark` quando o flavor no ar é claro (a paleta do pack já diz quais flavors são claros:
`claros` em `paleta.json`), e `symbolic_light` nos escuros; `ZAPZAP_TRAY` continua mandando quando posto à mão.

## Como se prova
`tests/` do módulo do ZapZap: com `dracula`/`alucard` o `ZapZap.conf` fica com `tray_theme=symbolic_dark`; com
`dracula`/`dracula` e `meowsystem`/`mocha`, `symbolic_light`. A segunda passada não escreve.

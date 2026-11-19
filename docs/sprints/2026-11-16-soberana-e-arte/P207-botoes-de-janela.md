# P207 — botões de janela na arte da casa (16/11/2026)

Texto de quem usa: «cria novos botões de minimizar + maximizar e fechar? esse é nosso estilo de arte» (fotos: os
ícones do lançador — círculos cheios, chapados, sem traço fino, roxo/laranja/verde Dracula, tema de Halloween).

## O que se mediu
- `packs/dracula/icones/sistema/window-{close,maximize,minimize,restore,pop-out}-symbolic.svg`: glifos Adwaita de 16 px.
- libcosmic `src/widget/header_bar.rs:449`: os botões usam `icon::from_name("window-*-symbolic")`; `named.rs:51` marca
  todo nome `-symbolic` como simbólico, e o simbólico é PINTADO de uma cor só pelo tema (16 px). GTK/libadwaita faz o
  mesmo. Logo, arte colorida vira silhueta de uma cor nos botões.

## A cura na origem
- Desenhar os cinco (minimizar, maximizar, restaurar, fechar, destacar) como SILHUETAS de uma cor (`fill="currentColor"`,
  sem traço fino), grossas e arredondadas como o lançador, com um detalhe da casa que se lê a 16 px (ex.: fechar = X de
  ossos/estacas cruzadas; maximizar = moldura de lápide/caixão; minimizar = asa de morcego baixa; restaurar = duas
  lápides). Legíveis a 16 px: conferir renderizando em 16, 24 e 32 px sobre o fundo claro e o escuro do pack.
- Usar a skill `hallmark` antes de desenhar (regra do CLAUDE.md para trabalho visual).
- Só dentro de `packs/dracula/icones/sistema/`; o `sistema.map` já liga os nomes.

## Como se prova
Os testes de ícone de sistema (`tests/icones-do-sistema.sh`, `tests/contrato-cosmic.sh`) verdes; PNG de prova em
16/24/32 px nas duas cores, anexado ao relatório (caminho no scratchpad do agente).

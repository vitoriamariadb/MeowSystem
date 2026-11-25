# P298: o menu que crava a cor do Catppuccin

## O que se mediu (25/11)
O menu do `meow` chamava o fzf com `--color="bg+:#313244,fg+:#cdd6f4,hl:#cba6f7,…"`: o Mocha fixo, também com o
Dracula no ar (nitro-5). O `scripts/fzf.sh` já gera essas mesmas nove cores a partir da paleta do pack no ar, em
`~/.config/meowsystem/fzf.sh`, e o `--color` da linha de comando vence o `FZF_DEFAULT_OPTS`.

O item estava na lista de «cor de tema cravada em código» do `PARA-A-PROXIMA-LEVA.md` de 23/11 (`bin/meow` no fzf).

## A cura
O menu carrega o arquivo gerado e não passa cor nenhuma.

## Como se prova
`tests/fzf-da-paleta.sh`: «scripts/meow não passa cor cravada ao fzf» e «o menu abre o fzf com as cores do pack no ar
(Dracula), lidas do arquivo gerado». Vermelho antes, verde depois.

## O que sobra da mesma lista
`scripts/gerador_circulo.py`, `btop-bat/manifesto.sh`, `spotify/acento.py`, `scripts/vidro.sh`,
`scripts/afinar_conversor.py` e a reserva do `_tinta_do_traco` em `app/servidor.py`.

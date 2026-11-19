# P206 — os 13 ícones escolhidos viram o padrão do Dracula (16/11/2026)

Texto de quem usa: «pega os svgs que escolhi pra setarmos o default do tema dracula. e pusharmos». Fotos: o lançador
com os escolhidos (Arquivos, Terminal, Câmera, Configurações, COSMIC Viewer, Editor de Texto, Gradia, Calculator,
Gerenciador de partições, OBS Studio, btop++, Loja, ghostwriter).

## O que se mediu
`~/.config/meow/icones-escolhidos.map` (13/11) tem 13 linhas `<id> : packs/dracula/icones/<pasta>/<arquivo>.svg`; os 13
arquivos existem no repo. No `packs/dracula/icones/apps.map`: só Câmera, Calculator e Gradia têm linha (com outro
desenho); as Cosmic* estão comentadas como «já têm arte autoral no MeowSystem (não entram)»; OBS em «sem desenho ainda».

## A cura na origem
- Cada id do mapa escolhido ganha, no `apps.map` do Dracula, a linha que aponta para o desenho escolhido (seguindo o
  padrão P96: `<id> : apps/<arquivo>.svg   # Nome — o desenho escolhido por quem usa em 16/11 (P206)`). Se a regra
  «três pastas planas» exigir que o desenho de app more em `apps/`, copie de `biblioteca/` para `apps/` (decisão 13: uma
  versão por ícone — o desenho anterior daquele id sai se nada mais o usa).
- As linhas comentadas que o escolhido substitui saem (Cosmic* «não entram», OBS «sem desenho»).
- O mapa do usuário NÃO é tocado (é config pessoal); depois do pack, ele fica redundante e inofensivo.
- Sim explícito de 16/11 cobre a troca da decisão 13 para esses 13 ids.

## Como se prova
Testes de ícone afetados (`tests/apps-em-todo-pack.sh`, `tests/fonte-unica.sh`, `tests/desenho-no-pack.sh`,
`tests/icones-por-pack.py` e os que o grep de `apps.map` achar) verdes; com HOME temporário e o mapa escolhido vazio, o
tema gerado do Dracula resolve cada um dos 13 ids para um arquivo idêntico (sha256) ao escolhido.

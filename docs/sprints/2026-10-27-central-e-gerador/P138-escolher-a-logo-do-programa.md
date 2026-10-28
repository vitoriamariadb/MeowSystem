# P138 — escolher a logo do próprio MeowSystem

Anotada em 28/10 (ela: «a logo do meowsystem muda quando eu personalizo meu tema, mas não dá pra escolher qual logo
eu quero usar pro próprio programa»).

## O que se mediu
- O painel serve `/logo.svg` por `_logo_do_painel` (`app/servidor.py:5208`), que segue o pack no ar: com o pack
  pessoal `meu-meow-portatil`, a logo do programa vira a `logo.svg` dele. Não há chave nem tela para escolher outra.

## Cura na origem
- Chave nova no `meow.conf` (ex.: `LOGO_PROGRAMA`, vazio = a do pack no ar, como hoje) com as logos dos packs
  instalados como valores. A escolha vale para tudo que mostra a logo do programa: o cabeçalho e o ícone da aba do
  painel, o ícone do lançador do MeowSystem e o que mais `_logo_do_painel` alimentar.
- Na tela, em Definir ou em Personalizar (onde as outras escolhas de identidade já moram): uma grade das logos
  disponíveis, igual ao seletor que já existe para o mascote, sem texto explicando.

## Prova
- Teste do servidor: com a chave vazia, `/logo.svg` é a do pack no ar; com a logo do `dracula`, é a do dracula,
  mesmo com outro pack no ar; o lançador acompanha.
- Teste de navegador (HOME temporário): escolher uma logo troca o cabeçalho.

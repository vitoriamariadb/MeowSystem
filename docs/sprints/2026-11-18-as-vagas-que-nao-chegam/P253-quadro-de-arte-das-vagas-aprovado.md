# P253 — o quadro de arte das vagas aprovado: o que sai dele (18/11/2026)

Quadro: <https://claude.ai/artifact/XecxYq2wNqphzvJ7dBdRzj> (coleção `escolhas`, vazia: nenhuma marca de refazer).
Texto de quem usa, 18/11, com o quadro aberto: «tudo aprovado».

## Como «tudo aprovado» vira desenho (regra do coordenador)
- Os 66 desenhos de `bloco/arte-vagas` (`ad2f131f`, `6a58b3ef`, `f8ff8388`, `14cc23a0`) entram como estão, inclusive os
  que o desenhista marcou como fracos em 16 px.
- Desligar e três pontos do Dracula: a pergunta do quadro era «proposta nova ou glifo de hoje». O pedido que abriu a
  leva foi «alguns ícones não mudaram», com a foto desses dois; «tudo aprovado» é lido como a proposta nova (punhal no
  anel, três fases da lua). O glifo de hoje fica no pack com o sufixo `-alt`, fora do mapa, para a troca de volta ser
  uma linha.

## O que falta para chegar à barra
1. **No pack (`bloco/arte-vagas`):** as duas propostas do Dracula entram no `sistema.map`; o conferente confere os
   quatro commits de arte (procedência, mapa, contrato) e cura o `view-reveal` do MeowSystem, que ainda aponta para o
   olho riscado.
2. **Nos applets (P243, itens 1 e 4):** Performance (seis desenhos embutidos) e Leitura (quatro) passam a pedir o
   desenho ao tema por nome e caem no embutido sem ele, como a Soneca; a Bandeja, se o botão dela não pede o nome ao
   tema. O Clipboard já pede o nome dele; o botão do Eyedropper pede `color-select-symbolic`, já ligado. Commits nos
   repositórios dos applets sem push; a publicação é do coordenador, pelo desktop da Vitória com a identidade dela, e
   o pino novo em `assets/extensoes/` aponta para o commit publicado.
3. **Prova:** em cada applet, com o nome no tema usa o do tema, sem ele o embutido; `tests/applet-pino.sh`,
   `tests/extensoes.sh`, `tests/vagas-novas.sh`, `tests/nomes-dos-applets.sh`; foto da barra e da dock no palco, nos
   dois packs.

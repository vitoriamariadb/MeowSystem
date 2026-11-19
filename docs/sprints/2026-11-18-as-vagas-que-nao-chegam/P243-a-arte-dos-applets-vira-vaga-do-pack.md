# P243 — o desenho próprio de cada applet não troca com o pack (18/11/2026)

Pedido de quem usa, 18/11: «alguns ícones não mudaram», com o velocímetro, a prancheta, os três pontos e o desligar.

## O que se mediu (coordenador, nitro-5, 18/11)
- Performance: seis SVG embutidos no binário (`include_bytes!` em `src/main.rs:36` a `:41`); o botão da barra sai de
  `icon::from_svg_bytes` (`src/main.rs:420`). `ICONES=""` no pino. Nunca consulta o tema de ícones.
- Leitura: quatro SVG embutidos, `ICONES=""` no pino.
- Clipboard: o botão é `io.github.meowsystem.Clipboard-symbolic`, instalado pelo pino em `hicolor/scalable/apps`.
- Eyedropper e Bandeja: o mesmo desenho próprio em `hicolor` (`…Eyedropper-symbolic`, `…Bandeja-symbolic`).
- Soneca: já resolvido pela decisão 59. Pede `soneca-desperto-symbolic` e `soneca-ronronar-symbolic` ao tema e cai no
  embutido sem pack.
- Os três pontos da Bandeja (`view-more-horizontal-symbolic`) e o desligar (`system-shutdown-symbolic`) estão no pack
  Dracula e instalados: o desenho deles é o glifo do dracula-icons, igual ao genérico a olho.

## A causa
Só a Soneca ganhou vaga de pack. Os outros applets embutem a arte ou a instalam fora do tema que o pack escreve.

## A cura na origem
1. Cada applet pede o desenho ao tema de ícones por nome e cai no embutido quando o tema não o tem, como a Soneca
   (`performance-{desempenho,equilibrado,economia,gpu,grafico,reiniciar}-symbolic`, os quatro do Leitura, o botão do
   Clipboard, do Eyedropper e da Bandeja).
2. Os nomes entram no `nomes-das-extensoes.tsv` e viram vaga no criador.
3. Quadro de arte para aprovar, por pack: os desenhos novos do Dracula e do MeowSystem para essas vagas, e a
   pergunta se o desligar e os três pontos do Dracula ganham desenho próprio ou ficam no glifo do dracula-icons.
4. Publicação dos applets pelo desktop da Vitória, com a identidade dela (a conta do coautor só lê os repositórios,
   como na Soneca do P231), e o pino novo em `assets/extensoes/`.

## Como se prova
Em cada applet, o teste da Soneca repetido: com o nome no tema o applet usa o do tema; sem, o embutido. No MeowSystem:
`tests/applet-pino.sh`, `tests/extensoes.sh`, `tests/vagas-novas.sh`. Foto da barra e da dock no palco, nos dois packs.

## Nos três PCs
nitro-5: resolve o velocímetro, a prancheta, o conta-gotas e a Bandeja. Desktop e portátil: só depois do P241. Depende
de arte aprovada e do build de cinco applets em cada máquina.

## Tarefa do implementador dos applets (18/11, depois do quadro aprovado)
- A arte e as 13 linhas do contrato já estão em `bloco/arte-vagas` (`6a58b3ef`). O Clipboard, o Eyedropper e a Bandeja
  pedem o nome `io.github.meowsystem.<X>-symbolic`: se pedem ao tema de ícones, o desenho do pack já vence o do
  `hicolor` sem mexer no applet. Conferir no fonte e provar; só muda código o que não pede ao tema.
- Performance (`~/Desenvolvimento/meowsystem-performance`, seis desenhos) e Leitura (`~/Desenvolvimento/meowsystem-leitura`,
  quatro): pedir ao tema por nome e cair no embutido, igual ao `67741ed` da Soneca (`../meowsystem-soneca-p231`:
  `src/tema.rs`, `src/main.rs`, `install.sh`, `data/icones/*-symbolic.svg`). Nomes: os do `nomes-das-extensoes.tsv`.
- Cada applet numa árvore própria (`../meowsystem-<applet>-p243`, branch `p243`), commit sem push. A publicação pelo
  desktop da Vitória e o pino novo são do coordenador, como no P231.
- Prova: o teste da Soneca repetido em cada applet (com o nome no tema, o do tema; sem, o embutido), `cargo test` e
  `cargo build --release` de cada um.

# P234 — papéis de parede em SVG, em par dia e noite (17/11/2026)

Ver `P230`. Só `packs/*/wallpapers/` e os `CREDITOS.md`/`PROCEDENCIA.md` dos packs. O mecanismo do par é do P231.

## O que se mediu
O Dracula tem 13 SVG (`catedral/`, `cemiterio/`, `noite/`, `ornamento/`), sem par dia e noite. O MeowSystem só tem
fotos baixadas (`FONTES.tsv`), nenhuma desenhada.

## A cura na origem
Seis cenas, cada uma em dois SVG (dia e noite) com a mesma composição, 3840×2160 de viewBox, peso leve (sem
bitmap embutido), nas cores da paleta do pack (`paleta.json`; MeowSystem: Latte de dia, Mocha de noite):
1. Dracula, catedral: vitral iluminado de dia, velas na nave de noite (partindo de `catedral/vitral` e `rosacea`).
2. Dracula, castelo na colina com a ponte e a grade levadiça: céu nublado lilás de dia, lua cheia e morcegos de
   noite.
3. Dracula, campo-santo: névoa clara e corvo pousado de dia, névoa roxa e portão aberto de noite.
4. MeowSystem, telhados: gato no telhado, sol e varal de dia, lua e janelas acesas de noite.
5. MeowSystem, janela: gato de costas no parapeito, vaso e céu de dia, estrelas e reflexo de noite.
6. MeowSystem, padrão de patinhas e novelos.
Desenho original (inspiração gótica e felina, nada copiado). Ficha de cada um no `CREDITOS.md` e no
`PROCEDENCIA.md` do pack (autor, licença do pack, data, sha256), no formato que o P231 lê para a página de créditos.

## Como se prova
Render de cada SVG em 1920 px e em miniatura, olhado antes de dar por bom (o par lido como a mesma cena); folha
com os pares lado a lado; testes de pack e de procedência verdes.

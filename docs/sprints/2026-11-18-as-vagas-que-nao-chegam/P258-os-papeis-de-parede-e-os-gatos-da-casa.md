# P258 — os papéis de parede em camadas certas, com a Coquinha e o Mimir (19/11/2026)

## Texto de quem usa
«Os svgs dos wallpaper a tão ou quebrados ou sai do com as layera erradas no produto final nos dois temas. Os gatos
deveriam ser mais parecidos com a coquinha e o mimir»

Acréscimo de 19/11 14h05: «Parte dos svgs o castelo tá voando. Camadas de efeito fora da tela de corte»

## O que se mediu (nitro-5, 19/11 13h40)
- O install rasteriza cada SVG com `rsvg-convert -w 3840 -h 2160` (`scripts/wallpaper.sh`, `_semear_papeis_do_pack`).
  O PNG instalado do `castelo-noite` é idêntico ao render de agora (RMSE 0): a rasterização não estraga o arquivo; o
  que se vê na tela é o que o SVG manda desenhar.
- Olhando os 12 pares em 960x540: na `catedral-dia` as manchas de luz do vitral passam por cima dos bancos e dos
  castiçais; nos `telhados` a roupa do varal fica por cima do telhado vizinho; na `janela` o rabo do gato passa na
  frente do parapeito; no `camposanto-noite` o pé da árvore some na névoa como se fosse transparente. É suspeita de
  ordem de camada, a conferir uma a uma.
- Os gatos dos três pares do `meowsystem` são silhuetas genéricas de costas. Os mascotes
  (`packs/meowsystem/mascote/coquinha.svg`, `mimir.svg`): cabeça larga e redonda, orelhas afastadas, olhos fechados
  em arco, presa, gravata-borboleta; a Coquinha é preta com gravata vermelha, o Mimir é cinza com gravata verde.
- Não se mediu ainda o mesmo SVG no navegador (a prévia do painel) nem em tela que não é 16:9.

## A causa (a provar)
Ordem dos elementos no SVG errada em algumas cenas, e gatos desenhados sem partir dos mascotes.

## A cura na origem
- Cada cena dos dois packs (`packs/*/wallpapers/**/*.svg`, 33 arquivos com as cenas soltas do Dracula): render em
  3840x2160 pelo `rsvg-convert` e pelo navegador; lista do que está fora de ordem ou quebrado, com recorte; corrigir
  no SVG, sem trocar a cena.
- Nos pares do `meowsystem`, os gatos passam a ser a Coquinha e o Mimir: a forma da cabeça e das orelhas, a cor e a
  gravata dos mascotes, de dia o Mimir e de noite a Coquinha (como `mascote.dia` e `mascote.noite` do `pack.json`),
  ou os dois juntos onde a cena comporta.
- Conferir o corte em 16:10 e em 21:9 (`WALLPAPER_AJUSTE="preencher"`): o gato e o astro não podem sair do quadro.

## Como se prova
- Folha de antes e depois de cada cena, em tamanho de tela, para quem usa aprovar no quadro.
- `tests/semente-dos-papeis.sh`, `tests/pack.sh`, `tests/desenho-no-pack.sh`, `tests/higiene.sh`, `tests/acento.sh`
  verdes; o `papeis.tsv` e a `PROCEDENCIA.md` de cada pack com a data nova.
- O PNG semeado só troca quando o SVG é mais novo: provar que o install regera os que mudaram.

## Nos três PCs
Vale nos três (Dracula no nitro-5, MeowSystem nos PCs da Vitória).

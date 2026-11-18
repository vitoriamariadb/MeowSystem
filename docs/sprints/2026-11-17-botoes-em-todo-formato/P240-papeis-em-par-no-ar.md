# P240 — os seis pares de papel do P234 entram no ar pelo `papeis.tsv` do P231 (18/11/2026)

Pedido de quem usa, 17/11: «Papéis de paredes que se enquadrem no meowsystem e dracula tanto de dia quanto de noite.
feitos em svg. Pra adicionarmos os créditos na página de créditos».

## O que se mediu (coordenador, na integração de 18/11)
- O P234 deixou seis cenas em `packs/{dracula,meowsystem}/wallpapers/pares/<cena>-{dia,noite}.svg`.
- O P231 criou o formato `packs/<p>/wallpapers/papeis.tsv` (cena, dia, noite, licença, data), a troca pelo par na
  janela de noite do mascote, o `scripts/creditos_dos_papeis.py` e o bloco «Autoria» do painel. Nenhum pack tem o
  `papeis.tsv` ainda, então nada disso aparece.
- Achado do conferente do P231: o pack meowsystem não tem `origens.wallpapers.desenhos`. Os SVG em
  `packs/meowsystem/wallpapers/` não seriam semeados, e pôr desenhos ali pode trocar a semente que hoje vem do
  repositório do Catppuccin.

## A cura na origem
1. O `papeis.tsv` dos dois packs com as seis cenas (nome da cena em português, licença do pack, data 2026-11-17).
2. Os pares chegam à pasta de papéis de quem usa pela semente do pack, SOMANDO à semente atual (o Catppuccin do
   meowsystem continua; os pares entram junto), sem duplicar na segunda passada.
3. `scripts/creditos_dos_papeis.py` roda e os `CREDITOS.md` ficam em dia, com miniatura e o par lado a lado.
4. O bloco «Autoria» do painel mostra as seis cenas.

## Como se prova
`tests/papel-em-par.sh`, `tests/creditos-dos-papeis.sh`, os testes de semente de papel (`wallpaper-base`,
`apagar-papel`, `fotos-do-pack`) e um teste novo: com HOME temporário e o pack no ar, a semente põe os 12 SVG, a
segunda passada não escreve nada, e o papel de noite troca pelo de dia com o relógio falso. Foto do bloco Autoria
no painel (HOME temporário, PID próprio, nunca `--parar`).

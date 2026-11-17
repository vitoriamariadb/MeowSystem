# P220 — a arte nova dos botões do Dracula (17/11/2026)

Texto de quem usa, 17/11 (foto dos botões do Dracula num app COSMIC): «pro fechar um ícone de ossos cruzados de
pirata. pro + virarmos o atual do fechar pra ele se parecer com a cruz de malta. Se o minimizar virar um morcego é uma
boa. Mas o atual tá estranho.» Maximizar (AskUserQuestion, 17/11): «castlevania poderia ser uma boa fonte de
inspiração pra isso […] temos algo quadrado lá?» → escolha: «Grade levadiça».

## O que se mediu
`packs/dracula/icones/sistema/` tem o desenho do P207 (16/11): fechar = dois ossos cruzados, maximizar = moldura de
caixão, minimizar = morcego pousado, restaurar = duas lápides. O `+` (`list-add-symbolic`, o da nova aba do
terminal) usa o glifo herdado.

## A cura na origem
Só em `packs/dracula/` (a arte mora no pack), silhueta cheia em `currentColor`, legível em 16 px, no mesmo traço do P207:
1. `window-close-symbolic`: ossos cruzados de pirata (as duas tíbias em X com as pontas de nó dobradas, sem caveira).
2. `list-add-symbolic`: o desenho ATUAL do fechar, girado 45° e ajustado para ler como cruz de Malta (braços que se
   alargam para fora). Vale para todo `+` do sistema.
3. `window-minimize-symbolic`: morcego redesenhado, de asas abertas, pousado na base; o atual foi achado estranho.
4. `window-maximize-symbolic`: grade levadiça de castelo (inspiração Castlevania, desenho nosso, nada copiado):
   quadrado com barras verticais e horizontais e as pontas embaixo.
5. `window-restore-symbolic`: fica como está (duas lápides), salvo se o desenho novo pedir coerência; nesse caso
   propor ao coordenador, não trocar.
6. `PROCEDENCIA.md` reescrito no lugar para os quatro arquivos (desenho, data, sha256).

## Como se prova
- Os testes de ícone do pack verdes (`tests/icones-do-sistema.sh`, `tests/desenho-no-pack.sh` e os de procedência).
- Foto em 16, 24 e 32 px de cada um, claro e escuro, lado a lado com o antigo, para quem usa aprovar antes do merge.

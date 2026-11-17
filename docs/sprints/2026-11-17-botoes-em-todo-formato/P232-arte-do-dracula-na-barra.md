# P232 — a arte do Dracula na barra: Soneca, notificação, rede e bateria (17/11/2026)

Ver `P230`. Só `packs/dracula/` (SVG, `icones/sistema.map` se precisar de nome novo, `PROCEDENCIA.md`). Começa
depois do P220, no traço dele: silhueta cheia em `currentColor`, 16×16, legível em 16 px.

## O que se mediu
Bateria, Wi-Fi, cabo e notificação do Dracula são glifos herdados do `m4thewz/dracula-icons` (pilha, leque, RJ45,
sino). O mascote do terminal tem `mascote/morcego-noite.svg` (voando, olhos acesos) e `morcego-dia.svg` (pendurado,
dormindo), coloridos e num círculo.

## A cura na origem
1. Soneca: `soneca-desperto-symbolic` = o morcego da noite, `soneca-ronronar-symbolic` = o morcego do dia, tirados
   do círculo, em contorno no mesmo traço e peso dos `soneca-*.svg` do MeowSystem (observação dela: «fora do
   círculo e com a mesma borda do meowsystem»).
2. Notificação: normal = sino de campanário com um morcego pequeno pendurado; nova = corvo de asas abertas
   chegando; não perturbe = o sino coberto de teia.
3. Wi-Fi: ecolocalização (morcego na base, arcos acendendo por nível: excelente, bom, ok se houver, fraco,
   nenhum; e os estados de desligado e sem rede que o mapa tiver).
4. Cabo: corrente (recomendada) e teia: as duas, ligado e desconectado.
5. Bateria: vela (recomendada), frasco de sangue e ampulheta: as três famílias completas (todos os níveis e estados
   que o `sistema.map` liga: carregando, limitado, cheia), cada uma numa pasta de variante; a recomendada no lugar.
Nenhum desenho copiado de jogo ou de outro tema.

## Como se prova
`tests/icones-do-sistema.sh`, `tests/desenho-no-pack.sh`, testes de procedência; folha de comparação (antigo ×
novo × variantes) em 16, 24 e 32 px, claro e escuro, que o coordenador mostra a quem usa antes do merge.

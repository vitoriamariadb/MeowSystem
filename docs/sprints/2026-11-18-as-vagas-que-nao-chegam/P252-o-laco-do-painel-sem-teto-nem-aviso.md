# P252 — o laço do painel recicla sem teto e sem aviso (18/11/2026)

Pedido de quem usa, 18/11 (AskUserQuestion, sobre o vigia do painel fantasma do nitro-5): «Vira Sprint e dispara
agora.» A opção recomendada era: o laço do MeowSystem ganha o teto e o aviso, e depois disso o script do Spellbook
sai pelo contrato.

## O que se mediu (conferente do bloco D e coordenador, 18/11, nitro-5, só leitura)
- `scripts/painel.sh`, função `laco` (linhas 206 a 240): quando `meow_painel_fantasma` diz que o painel está vivo e
  não desenha, o laço o recicla e só espera 600 s para reciclar de novo. Não há teto por boot nem aviso a quem usa.
- `~/.config/zsh/aurora/aurora-painel-fantasma.sh` (Spellbook, 348 linhas): `MAX_TENTATIVAS=2` por boot, com o
  contador no `XDG_RUNTIME_DIR`; na desistência, registra e avisa uma vez (`notify-send` crítica). O cabeçalho dele
  traz a medida: «Failed to render» sozinho aparece em boot saudável; o sinal que acerta a causa é o `xdg_popup …
  error 0` do applet de notificações (o «sinal 4»).
- Os dois rodam no nitro-5 ao mesmo tempo: o doctor lista o script como duplicata nova (`vizinhos`).
- Nos PCs da Vitória o mesmo vigia saiu pelo contrato em 27/10 (`6227d932`, linhas `aurora-painel-fantasma-*` do
  `assets/contratos/vizinhos.tsv`). No portátil, esses itens constam «restaurado» em 27/10 20:23:45.
- O bloco D tentou desligar o script do Spellbook pelo contrato (`35e50020`) e o conferente tirou a linha
  (`6f68ebe0`), porque o MeowSystem não faz o teto nem o aviso.

## A causa
O laço do MeowSystem herdou do vigia só a reciclagem e a carência de 10 minutos. O teto por boot e o aviso, que a
Aurora mediu como o que impede o ciclo infinito, ficaram de fora. Falta medir se o sinal que o `meow_painel_fantasma`
usa dispara em boot saudável.

## A cura na origem
1. O laço para de reciclar depois de duas reciclagens por boot (contador no `XDG_RUNTIME_DIR`, que zera no boot) e
   avisa uma vez, pela notificação da casa, que o painel não desenha e que ele desistiu.
2. O sinal do `meow_painel_fantasma` é conferido contra a medida do Spellbook: se ele dispara com «Failed to render»
   sozinho, passa a exigir o sinal que acerta a causa.
3. `meow painel` (estado) diz quantas reciclagens houve neste boot e se o laço desistiu; o doctor mostra o mesmo.
4. Com 1 a 3 feitos, a linha `spellbook-painel-fantasma` volta ao `vizinhos.tsv` e o doctor desliga o script do
   Spellbook, com cópia de antes.

## Como se prova
`tests/painel-fantasma.sh` com o painel de mentira: a terceira detecção no mesmo boot não recicla e avisa uma vez só;
um boot novo (pasta de runtime nova) zera o contador; boot saudável com «Failed to render» não recicla.
`tests/vizinhos.sh` com a linha de volta. `tests/painel-sobrevive-ao-lancador.sh` e `tests/painel-janela-propria.sh`
verdes.

## Nos três PCs
Os três ganham o teto e o aviso. No nitro-5 o vigia do Spellbook sai; nos da Vitória ele já saiu.

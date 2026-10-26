# P109 — cada controle grava ao soltar; o instalador para de escrever à toa

Leia `00-leva.md`. Itens do relatório: `relatorios/qa-2.md` Q2-04, Q2-05, Q2-06, Q2-07, Q2-21;
`relatorios/qa-3.md` Q3-02, Q3-07; `relatorios/qa-1.md` Q1-14.

## O que quem usa pediu
Mexer num controle aplica aquela coisa na hora, sem «Aplicar» e sem rodar o instalador inteiro. A barra
de mudanças continua, só para desfazer. «Instalar tudo» deixa de sair 2.

## Decisões que valem (ANDAMENTO.md)
- Grava ao soltar; a barra lista o que mudou e desfaz (últimas 20, enquanto a aba está aberta).
- Aplicar por etapa (uma etapa por chave) está aceito, contra a regra antiga do cabeçalho do
  `install.sh` de não escolher etapa: sobrescreva essa regra no lugar.
- Chave sem aplicador próprio: grava e roda o instalador em segundo plano, sem janela; o resultado
  vira pendência se falhar.
- Decisões 10 e 18 de `docs/DECISOES.md`: o «Aplicar» e o «Ver sem mudar» saem dos ajustes; «Restaurar ao padrão» grava na hora;
  para AÇÕES (botões de Manter e Extensões) a janela de resultado continua. Troque as linhas e os
  testes no mesmo commit, citando o sim de 26/10.

## Ordem
1. Q3-02 primeiro (pequeno, destrava o resto): `jogos_steam.sh` e `jogos_heroic.sh` renderizam e
   comparam fora do hicolor (`$TMPDIR`) e só movem para lá quando o conteúdo muda. Não troque o
   `hicolor.sh` para olhar só arquivo. Ponha um jogo da Steam falso em `tests/convergencia.sh` para a
   suíte pegar a regressão. Prova: duas passadas seguidas, a segunda não escreve nada.
2. Mapa chave → etapa (Q2-07, Q3-07): uma tabela de dado (não `case` espalhado) que diz qual etapa
   aplica cada chave do `meow.conf`; o servidor chama só aquela etapa, com a guarda de ponte que o
   «Aplicar» de hoje pula (Q3-07).
3. Front-end: o controle chama o `/api/definir` existente ao soltar (slider no `change`, não no
   `input`), mostra que aplicou, entra na barra para desfazer. A barra perde «Aplicar» e «Ver sem
   mudar»; fica «N mudanças · Desfazer».
4. Q1-14: os controles do Personalizar seguem a mesma regra quando o tema em edição é o que está no ar.
5. Q2-05, Q2-06, Q2-21 caem junto; confirme cada um com a prova do relatório.

## Fora desta sprint
Layout da barra e da prévia (P110), textos e renomes (P111).

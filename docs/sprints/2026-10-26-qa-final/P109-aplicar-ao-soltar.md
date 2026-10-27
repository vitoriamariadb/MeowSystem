# P109 — cada controle grava ao soltar; o instalador para de escrever à toa

Leia `00-leva.md`. Itens do relatório: `relatorios/qa-2.md` Q2-04, Q2-05, Q2-06, Q2-07, Q2-21;
`relatorios/qa-3.md` Q3-02, Q3-07; `relatorios/qa-1.md` Q1-14.

## Maquete
`maquete/a/`: a barra «N mudanças · Desfazer» e o indicador de gravando da moldura (`demo.js` mostra o comportamento esperado).

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

## Execução

| item | commit | prova |
|---|---|---|
| Q3-02 | b118da61 | 2ª rodada da convergência mexe 0 pastas do hicolor (eram 9); `jogos-heroic.sh`, `um-cartao-por-jogo.sh`, `convergencia.sh` |
| Q2-04 | 363430bb | tabela `assets/contratos/chave-etapa.tsv` (122 chaves) + `install.sh --etapa`; mexer só em `forma` roda 1 etapa; `chave-etapa.sh`, `grava-ao-soltar.py` |
| Q2-05 | 7b9e11f8 | o botão Aplicar saiu; `/api/salvar` vazio não dispara trabalho; `grava-ao-soltar.py` |
| Q2-06 | 7b9e11f8 | «Ver sem mudar» saiu da barra e do lote; fica só no diálogo das ações; `app-completo.py` |
| Q2-07 | 7b9e11f8, 84d37d8d | cada controle grava ao soltar; a barra lista as 20 últimas e `desfazer-uma` devolve o `antes` (inclusive o padrão da chave); `grava-ao-soltar.py`, `app.sh` |
| Q2-21 | 7b9e11f8 | rótulos «(barra de cima)» e «(dock)» nas chaves gêmeas; `grava-ao-soltar.py` |
| Q3-07 | 363430bb | chave que pede root sem ponte vira a pendência `aplicar-ajuste`; `grava-ao-soltar.py` |
| Q1-14 | 7b9e11f8 | as linhas `c:` do Personalizar passam por `escolher` e gravam ao soltar; `grava-ao-soltar.py` |

Decisões 10 e 18 trocadas com o sim de 26/10 no mesmo commit do código (05a00640). Testes e LEIA-ME acompanham (05a00640, 6b17257b, 757642d3, b501d74e, b5e5a86e).

Achados da suíte, curados na origem:
- ação clicada enquanto o aplicador roda recebia 409 ou esbarrava no lock do meow: agora espera o aplicador acabar (9b8138f3, 84d37d8d);
- o Desfazer de uma chave cujo padrão é `$FLAVOR` era recusado pelo `validar_valor`: o padrão da chave passa a ser aceito (84d37d8d);
- ponta da noite sem par em ajuste isolado era recusada: o par ganha 18:00 ou 07:00 (84d37d8d).

`./tests/todos.sh`: 87 verdes, 0 pulados, 3 vermelhos. `decisoes.sh` (só GPU fora da RTX e shim do compositor) e `restaurar.sh` (`pack_usar`, `desinstalar`) são os aceitos. `readme.sh` só reclama do badge `v2.1.0`: a tag não é alcançável pelo `dev`, e o mesmo vermelho existe no `dev` sem esta sprint.

Capturas lado a lado com a maquete, nas quatro larguras (1920, 1550, 1280, 1500): `capturas/p109/` (PNG fora do git).

Fora, e por quê:
- layout e posição da barra e da prévia: P110;
- textos novos e renomes: P111;
- Q1-14: tratado pela mesma regra do `escolher`; o rascunho do tema em edição continua à parte;
- «Ver sem mudar» continua nas ações (só saiu da barra).

Anotado para depois (fora do pedido): Tema (FLAVOR, ACCENT, MODO) agora grava em silêncio, com o indicador `gravando` no lugar da janela de resultado; enquanto um «Aplicar ajuste» corre, uma ação clicada espera ele acabar antes de abrir o seu trabalho.

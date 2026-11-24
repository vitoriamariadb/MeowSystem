# P286 — a suíte em paralelo (23/11/2026)

Pergunta de quem usa, 23/11: «e sobre a integração e suite de testes? nosso gap temporal fica nisso tambem.»

## O que se mediu (catálogo de 23/11)
- `tests/todos.sh` roda os 173 testes num laço, um por vez: cerca de 80 minutos na máquina, de 56 a 67 no CI.
- Os mais longos, pelos registros das levas: `app-completo.py` 13 a 20 minutos, `convergencia.sh` 12 (roda o install
  três vezes), `app-navegador.py` 6, `app-layout.py` 2 a 5, `deb.sh` 3 a 5.
- O `todos.sh` monta uma casa de mentira só (`SUITE_TMP/casa`) para todos os testes, com os falsos no PATH.
- Os 24 testes de navegador sobem o painel; os de palco usam `PALCO_DIR`.

## A causa
A suíte nasceu pequena e em sequência, e cada teste novo entrou no fim do laço. Nada nela impede o paralelo, mas
todos dividem a mesma casa.

## A cura na origem
1. Cada teste roda com a casa dele (`HOME`, estado, cache e `PALCO_DIR` próprios), montada pelo `todos.sh`.
2. O `todos.sh` ganha um número de trabalhadores (padrão: metade dos núcleos); os testes que rodam o install de
   verdade e os de navegador entram numa fila que não divide a máquina com outro igual.
3. O painel de cada teste de navegador sobe em porta própria.
4. A saída de cada teste vai para arquivo e o resumo sai no fim, na ordem das listas, com o tempo de cada um.
5. `--em-serie` mantém o laço de hoje, para comparar.

## Como se prova
- Uma rodada em série e uma em paralelo no mesmo commit, sem carga na máquina: o veredito de cada um dos 173 testes
  é o mesmo nas duas. São as duas únicas rodadas inteiras antes do push final, e medem a própria suíte.
- Três rodadas em paralelo seguidas com o mesmo veredito (não oscila).
- O tempo das duas anotado no `ESTADO.md`. O teto do paralelo é o teste mais longo.
- `tests/decisoes.sh` verde: ele lê o formato das listas do `todos.sh`, que não muda.

## Fica para a P283
Encurtar os testes longos e trocar os 173 arquivos por um por área. Esta tarefa só muda o jeito de rodar.

## Medido (23/11)
- Em série, na ponta `26e784ab`: 173 verdes, 0 pulados, 0 vermelhos, 4979 s (83 minutos).
- Soma por fila, em série: painel 1135 s (25 testes), `app-completo.py` 895 s, install 403 s (5), palco 26 s (2),
  soltos 2520 s (140). Os soltos mais longos: `restaurar.sh` 576 s e `deb.sh` 283 s.
- Ensaio com 9 testes leves: os 9 vereditos iguais nos dois modos.
- As quatro rodadas inteiras em paralelo estão em `~/.cache/meow-leva/suite-2026-11-23/paralelo-{1,2,3,4}.log`.

## As rodadas inteiras em paralelo (23/11)
| rodada | resultado | tempo |
| --- | --- | --- |
| 1 | 173 verdes, vereditos iguais à série | 1394 s |
| 2 | 173 verdes, vereditos iguais à série | 1650 s |
| 3 | 172 verdes e o `atualiza.sh` vermelho | 1565 s |
| 4 | 173 verdes, vereditos iguais à série | 1412 s |

As rodadas 2, 3 e 4 dividiram a máquina com agentes testando (carga 14 em 12 threads na 2 e na 3). Sem carga ainda
não se mediu.

O vermelho da rodada 3 é uma corrida do próprio teste, que já existia em série: o gpg de mentira respondia ao
`--verify` e saía sem ler a entrada; quando saía antes de o git escrever, o git levava erro de pipe e reprovava a
assinatura. O falso passou a ler a entrada (`804b136d`). Oito cópias do teste ao mesmo tempo: oito verdes.

`restaurar.sh` (576 s em série, 685 s sob carga), `deb.sh` e dois de pack passaram a largar primeiro (`f1cb50a3`).
A quarta rodada já roda com as duas mudanças.

## Integrada (23/11)
`bloco/suite-em-paralelo` entrou na integração em `410756f1`. O cruzamento de 13 testes, já no modo paralelo, deu
13 verdes em 82 s de parede. Daqui em diante todo bloco nasce com o `todos.sh` paralelo.

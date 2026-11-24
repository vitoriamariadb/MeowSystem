# P289 — a completion sem `atualizar` e o desinstalar que não devolve tudo (23/11/2026)

Herdada dos relatórios de 19/11 (item 6).

## O que se mediu (integração, 23/11)
- `bin/meow:3577` tem o verbo `atualizar`; a completion instalada não o oferece. Falta medir a lista inteira: todo
  verbo do `case` principal do `bin/meow` contra o que a completion oferece.
- `scripts/botoes_lado.sh` escreve `button-layout` e `scripts/cursor.sh` escreve `cursor-theme` pelo gsettings.
  `lib/desinstalar.sh` não cita nenhuma das duas chaves: quem desinstala fica com o valor do MeowSystem.

## A causa
A completion é uma lista escrita à mão, e o desinstalar foi escrito antes dessas duas etapas existirem.

## A cura na origem
1. A completion passa a sair da mesma fonte que o `case` dos verbos (ou um teste cobra que as duas listas batem).
2. As duas etapas guardam o valor de antes na primeira escrita, no molde das outras cópias `-PRIMEIRO` do estado
   (decisão 56), e o desinstalar o devolve.

## Como se prova
- Teste da completion: todo verbo público do `meow` é oferecido. Vermelho antes (falta `atualizar`), verde depois.
- Casa de mentira, gsettings falso: instalar, desinstalar, e `button-layout` e `cursor-theme` voltam ao valor de
  antes; segunda passada do install não regrava a cópia.

## Feito (24/11, bloco `install-herdadas`, integrado em `eae6f987`)
- Faltavam 12 verbos na completion, não um: `cursor`, `areas`, `fontes`, `graficos`, `dock`, `painel`, `pack`,
  `leitura`, `atualizar`, `cosmic`, `abrir`, `restaurar`. `tests/completion-dos-verbos.sh` cobra os dois sentidos.
- `button-layout` e `cursor-theme` guardam o valor de antes em `backups/<data>-valores-PRIMEIRO-pre-instalacao/`, uma
  vez, e o desinstalar o devolve. Em máquina que já rodava o MeowSystem a cópia nasce vazia e o desinstalar devolve
  o padrão do sistema: é o caso dos três PCs da casa. Prova: `tests/valores-de-antes.sh`.
- A rotação do `scripts/espaco.py` passou a proteger todo `-PRIMEIRO-`.
- Pede o sim de quem usa: o texto da decisão 56 e o da categoria `backups` em `assets/contratos/espaco.tsv` listam
  só `tema-PRIMEIRO`, `-sistema` e `meow.conf-antes-da-instalacao`; o código guarda também o `valores-PRIMEIRO`.
- No primeiro install de cada PC a reserva da ponte root é reinstalada, porque o `_meow` mudou.
- Anotado: máquina nova em que os botões já estão do lado pedido guarda cópia vazia, e o desinstalar troca um valor
  que o MeowSystem não tocou; a completion não tem os subverbos; o desinstalar não chama `cursor.sh remover`.

Em 24/11 a decisão 56 e a frase da categoria `backups` passaram a citar o `valores-PRIMEIRO`, com o sim de quem
usa («Sim, acrescentar»). Commit `dc596def`, integrado em `eb76985d`.

# P173 — a cor do desenho que mora em style (06/11/2026)

Achado da conferência da P169. Produto: vale para todo pack, e pesa no claro Alucard.

## O que se mediu

- `_cores_do_traco`, em `app/servidor.py`, só lê `fill="#..."` e `stroke="#..."`.
- 247 dos 477 desenhos da biblioteca do Dracula têm a cor só em `style`, e escapam da troca de fundo. A medida do `tests/sistema-latte-e-rotulos.py` usa o mesmo regex e não os enxerga.
- O corte em 16 cores atinge 23 arquivos.

## A cura

`_cores_do_traco` lê também `style="...fill:#...;stroke:#..."` e a cor curta `#abc`, e a medida do teste passa a usar a mesma função, para não haver dois regex.

## Como se prova

Teste com SVG de cor só em `style` e com `#abc`; os cartões do Alucard saem legíveis pela medida de contraste; a contagem de desenhos sem cor lida cai de 247 para 0, ou para os que não têm cor nenhuma.

## Execução

Commit `7f3ca965`.

- `_cores_do_traco` lê `fill`, `stroke` e `stop-color` em atributo, em `style` e em bloco `<style>`, a cor curta `#abc` e `rgb(...)`, e devolve sempre `#rrggbb`. O `stop-color` e o `rgb()` foram além da letra: sem eles, 1 desenho de degradê do pack Dracula e 2 em `rgb()` da biblioteca seguiriam sem cor lida.
- O corte em 16 cores saiu: era por ordem de hexa, então guardava as escuras e jogava fora as claras. A biblioteca do Dracula soma 4.264 cores, cerca de 47 kB de JSON na ficha.
- `tests/sistema-latte-e-rotulos.py` mede com `i.cores`, o que o servidor entrega, e não tem mais regex próprio. O Alucard entrou na medida. A guarda do teste passou de `total > 20` para `lidos > 20`, porque no Alucard só 15 desenhos da biblioteca têm o traço na cor do texto: o resto tem cor própria e é medido do mesmo jeito.
- Nenhuma arte de pack mudou.

Provas:

- Medida na biblioteca do Dracula, 477 desenhos: 249 sem cor pelo regex antigo (a sprint mediu 247), 15 com a leitura de `style` e `#abc`, 13 com o `rgb()`, e esses 13 só têm `currentColor`.
- `tests/acervo-da-ficha.sh`: `ok: _cores_do_traco lê a cor só em style`, `ok: _cores_do_traco lê a cor curta, em style e em atributo`, `ok: o desenho de 40 cores chega inteiro`, `ok: todo desenho da biblioteca do Dracula tem a cor lida, ou só o currentColor`.
- `tests/sistema-latte-e-rotulos.py`: `ok: Alucard, biblioteca: nenhum desenho no traço do texto abaixo de 3:1 no cartão (477 lidos, 0 sem cor lida, 15 no traço, ruins: 0: []; 0 de cor própria fora da conta)` e `ok: Alucard, biblioteca: todo desenho de cor própria fica no melhor fundo que o painel tem (0 seguem abaixo de 3:1 em todo fundo; perdidos: [])`.

Da mão de quem usa: abrir a Biblioteca no Alucard e ver os cartões legíveis no olho.

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

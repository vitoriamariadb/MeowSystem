# P211 — o ícone derivado perde o fim de linha do SVG (16/11/2026)

Achado do bloco B (P206), fora do escopo dele.

## O que se mediu
`meow_icones_derivar` em `lib/icones.sh` grava o desenho com `"$(cat …)"`; a substituição de comando corta o `\n` final.
Todo SVG do pack que termina em `\n` sai do tema instalado com um byte a menos: o tema nunca fica byte a byte igual ao
pack, e uma prova por sha256 entre pack e tema falha sem o desenho ter mudado.

## A cura na origem
Copiar o conteúdo sem passar por substituição de comando (`cp`, ou `cat arquivo > destino` quando há transformação em
fluxo), mantendo a idempotência (a segunda passada não escreve).

## Como se prova
Teste com HOME temporário: SVG do pack terminado em `\n` → sha256 do tema igual ao do pack; segunda passada sem escrita.
